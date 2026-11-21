import { deflateRawSync, inflateRawSync } from "node:zlib";

export interface ZipEntry {
  name: string;
  data: Uint8Array;
}

const DEFLATE_LEVEL = 6;
// Fixed DOS timestamp: 1980-01-01 00:00:00
const DOS_TIME = 0x0000;
const DOS_DATE = 0x0021; // ((1980 - 1980) << 9) | (1 << 5) | 1
// Unix regular file (S_IFREG 0o100000) | 0o644 in upper 16 bits
const UNIX_FILE_ATTRS = ((0o100644 << 16) >>> 0);
// Version made by: Unix (3) + ZIP 2.0 (20)
const VERSION_MADE_BY = (3 << 8) | 20;
const VERSION_NEEDED = 20;
// UTF-8 filename flag (set only for non-ASCII names, matching Rust's `zip` crate)
const FLAG_UTF8 = 0x0800;
const METHOD_STORED = 0;
const METHOD_DEFLATE = 8;

function isAscii(text: string): boolean {
  for (let i = 0; i < text.length; i++) {
    if (text.charCodeAt(i) > 0x7f) return false;
  }
  return true;
}

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) {
      c = (c & 1) !== 0 ? (0xedb88320 ^ (c >>> 1)) >>> 0 : c >>> 1;
    }
    table[i] = c;
  }
  return table;
})();

export function crc32(data: Uint8Array): number {
  let crc = 0xffffffff;
  for (let i = 0; i < data.length; i++) {
    crc = (CRC_TABLE[(crc ^ data[i]) & 0xff] ^ (crc >>> 8)) >>> 0;
  }
  return (crc ^ 0xffffffff) >>> 0;
}

const encoder = new TextEncoder();
const decoder = new TextDecoder("utf-8", { fatal: true });

function compareNames(a: string, b: string): number {
  return a < b ? -1 : a > b ? 1 : 0;
}

/**
 * Deterministically packs entries into a ZIP archive matching Koona Books' Rust packer:
 * sorted relative paths, Deflate level 6, fixed 1980-01-01 00:00:00 timestamp, Unix mode 0644.
 */
export function zipFiles(entries: readonly ZipEntry[]): Uint8Array {
  const sorted = [...entries].sort((a, b) => compareNames(a.name, b.name));

  interface Prepared {
    nameBytes: Uint8Array;
    flags: number;
    compressed: Uint8Array;
    crc: number;
    uncompressedSize: number;
    offset: number;
  }

  const prepared: Prepared[] = [];
  let localTotal = 0;
  let centralTotal = 0;

  for (const entry of sorted) {
    const nameBytes = encoder.encode(entry.name);
    const flags = isAscii(entry.name) ? 0 : FLAG_UTF8;
    const compressed = new Uint8Array(
      deflateRawSync(entry.data, { level: DEFLATE_LEVEL }),
    );
    const crc = crc32(entry.data);
    prepared.push({
      nameBytes,
      flags,
      compressed,
      crc,
      uncompressedSize: entry.data.length,
      offset: localTotal,
    });
    localTotal += 30 + nameBytes.length + compressed.length;
    centralTotal += 46 + nameBytes.length;
  }

  const out = new Uint8Array(localTotal + centralTotal + 22);
  const view = new DataView(out.buffer, out.byteOffset, out.byteLength);
  let pos = 0;

  // Local file headers + data
  for (const p of prepared) {
    view.setUint32(pos, 0x04034b50, true);
    view.setUint16(pos + 4, VERSION_NEEDED, true);
    view.setUint16(pos + 6, p.flags, true);
    view.setUint16(pos + 8, METHOD_DEFLATE, true);
    view.setUint16(pos + 10, DOS_TIME, true);
    view.setUint16(pos + 12, DOS_DATE, true);
    view.setUint32(pos + 14, p.crc, true);
    view.setUint32(pos + 18, p.compressed.length, true);
    view.setUint32(pos + 22, p.uncompressedSize, true);
    view.setUint16(pos + 26, p.nameBytes.length, true);
    view.setUint16(pos + 28, 0, true);
    pos += 30;
    out.set(p.nameBytes, pos);
    pos += p.nameBytes.length;
    out.set(p.compressed, pos);
    pos += p.compressed.length;
  }

  // Central directory headers
  const centralOffset = pos;
  for (const p of prepared) {
    view.setUint32(pos, 0x02014b50, true);
    view.setUint16(pos + 4, VERSION_MADE_BY, true);
    view.setUint16(pos + 6, VERSION_NEEDED, true);
    view.setUint16(pos + 8, p.flags, true);
    view.setUint16(pos + 10, METHOD_DEFLATE, true);
    view.setUint16(pos + 12, DOS_TIME, true);
    view.setUint16(pos + 14, DOS_DATE, true);
    view.setUint32(pos + 16, p.crc, true);
    view.setUint32(pos + 20, p.compressed.length, true);
    view.setUint32(pos + 24, p.uncompressedSize, true);
    view.setUint16(pos + 28, p.nameBytes.length, true);
    view.setUint16(pos + 30, 0, true); // extra length
    view.setUint16(pos + 32, 0, true); // comment length
    view.setUint16(pos + 34, 0, true); // disk number start
    view.setUint16(pos + 36, 0, true); // internal attrs
    view.setUint32(pos + 38, UNIX_FILE_ATTRS, true);
    view.setUint32(pos + 42, p.offset, true);
    pos += 46;
    out.set(p.nameBytes, pos);
    pos += p.nameBytes.length;
  }

  // End of central directory record
  view.setUint32(pos, 0x06054b50, true);
  view.setUint16(pos + 4, 0, true);
  view.setUint16(pos + 6, 0, true);
  view.setUint16(pos + 8, prepared.length, true);
  view.setUint16(pos + 10, prepared.length, true);
  view.setUint32(pos + 12, centralTotal, true);
  view.setUint32(pos + 16, centralOffset, true);
  view.setUint16(pos + 20, 0, true);

  return out;
}

/**
 * Reads a ZIP archive back into a map of path -> raw bytes, verifying CRC-32.
 */
export function unzipFiles(bytes: Uint8Array): Map<string, Uint8Array> {
  if (bytes.length < 22) {
    throw new Error("ZIP archive too short");
  }
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);

  // Locate EOCD
  let eocd = -1;
  const minOffset = Math.max(0, bytes.length - 22 - 65535);
  for (let i = bytes.length - 22; i >= minOffset; i--) {
    if (view.getUint32(i, true) === 0x06054b50) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) {
    throw new Error("Missing ZIP end-of-central-directory record");
  }

  const entryCount = view.getUint16(eocd + 10, true);
  const centralSize = view.getUint32(eocd + 12, true);
  const centralOffset = view.getUint32(eocd + 16, true);
  if (centralOffset + centralSize > eocd) {
    throw new Error("Central directory exceeds archive bounds");
  }

  const result = new Map<string, Uint8Array>();
  let pos = centralOffset;
  for (let i = 0; i < entryCount; i++) {
    if (pos + 46 > centralOffset + centralSize || view.getUint32(pos, true) !== 0x02014b50) {
      throw new Error("Invalid central directory header");
    }
    const method = view.getUint16(pos + 10, true);
    const expectedCrc = view.getUint32(pos + 16, true);
    const compSize = view.getUint32(pos + 20, true);
    const uncompSize = view.getUint32(pos + 24, true);
    const nameLen = view.getUint16(pos + 28, true);
    const extraLen = view.getUint16(pos + 30, true);
    const commentLen = view.getUint16(pos + 32, true);
    const localOffset = view.getUint32(pos + 42, true);

    const name = decoder.decode(bytes.subarray(pos + 46, pos + 46 + nameLen));
    pos += 46 + nameLen + extraLen + commentLen;

    if (localOffset + 30 > bytes.length || view.getUint32(localOffset, true) !== 0x04034b50) {
      throw new Error(`Invalid local file header for ${name}`);
    }
    const localNameLen = view.getUint16(localOffset + 26, true);
    const localExtraLen = view.getUint16(localOffset + 28, true);
    const dataStart = localOffset + 30 + localNameLen + localExtraLen;
    const compData = bytes.subarray(dataStart, dataStart + compSize);

    let data: Uint8Array;
    if (method === METHOD_STORED) {
      data = new Uint8Array(compData);
    } else if (method === METHOD_DEFLATE) {
      data = new Uint8Array(inflateRawSync(compData));
    } else {
      throw new Error(`Unsupported compression method ${method} for ${name}`);
    }

    if (data.length !== uncompSize) {
      throw new Error(`Uncompressed size mismatch for ${name}`);
    }
    if (crc32(data) !== expectedCrc) {
      throw new Error(`CRC-32 mismatch for ${name}`);
    }
    result.set(name, data);
  }
  return result;
}
