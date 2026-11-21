import { describe, expect, test } from "bun:test";
import { crc32, unzipFiles, zipFiles } from "./zip.ts";

describe("zip", () => {
  test("produces deterministic bytes regardless of input order", () => {
    const a = new TextEncoder().encode('{"hello":"world"}\n');
    const b = new TextEncoder().encode("return {}\n");

    const z1 = zipFiles([
      { name: "main.lua", data: b },
      { name: "addon.json", data: a },
    ]);
    const z2 = zipFiles([
      { name: "addon.json", data: a },
      { name: "main.lua", data: b },
    ]);

    expect(z1).toEqual(z2);
  });

  test("uses fixed 1980-01-01 timestamp and Unix 0644 permissions", () => {
    const data = new TextEncoder().encode("test content");
    const archive = zipFiles([{ name: "addon.json", data }]);
    const view = new DataView(archive.buffer, archive.byteOffset, archive.byteLength);

    // Local file header: DOS time (offset 10) = 0x0000, DOS date (offset 12) = 0x0021
    expect(view.getUint32(0, true)).toBe(0x04034b50);
    expect(view.getUint16(10, true)).toBe(0x0000);
    expect(view.getUint16(12, true)).toBe(0x0021);

    // Find Central Directory Header
    let cd = -1;
    for (let i = 0; i < archive.length - 4; i++) {
      if (view.getUint32(i, true) === 0x02014b50) {
        cd = i;
        break;
      }
    }
    expect(cd).toBeGreaterThan(0);
    expect(view.getUint16(cd + 4, true)).toBe(0x0314); // Unix + 2.0
    expect(view.getUint16(cd + 12, true)).toBe(0x0000);
    expect(view.getUint16(cd + 14, true)).toBe(0x0021);
    expect(view.getUint32(cd + 38, true)).toBe((0o100644 << 16) >>> 0);
  });

  test("round-trips files and verifies CRC-32", () => {
    const entries = [
      { name: "addon.json", data: new TextEncoder().encode('{"id":"org.test.a"}') },
      { name: "locales/en.json", data: new TextEncoder().encode('{"ok":"Yes"}') },
      { name: "main.lua", data: new TextEncoder().encode("local x = 1\nreturn x\n") },
    ];
    const archive = zipFiles(entries);
    const out = unzipFiles(archive);

    expect([...out.keys()]).toEqual(["addon.json", "locales/en.json", "main.lua"]);
    for (const e of entries) {
      expect(out.get(e.name)).toEqual(e.data);
    }

    // Standard CRC-32 test vector: "123456789" -> 0xcbf43926
    expect(crc32(new TextEncoder().encode("123456789"))).toBe(0xcbf43926);
  });
});
