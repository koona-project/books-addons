import { createPrivateKey, createPublicKey, sign, verify } from "node:crypto";
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import {
  catalogEntryFromPacked,
  KIND_LABELS,
  packAddonDir,
  plainEnglishPermissionsFromCodes,
  sha256Hex,
  type CatalogAddon,
  type CatalogFile,
  type IndexListing,
  type PackedAddon,
} from "./pack.ts";
import {
  loadValidationContext,
  validateRegistryEntry,
  validateRegistryFile,
  type RegistryEntry,
} from "./validate.ts";

export const DEFAULT_BASE_URL = "https://addons.koona.app/books/v1/";
export const DEFAULT_PREFIX = "books/v1/";
export const PACKAGE_CACHE_CONTROL = "public, max-age=31536000, immutable, no-transform";
export const INDEX_CACHE_CONTROL = "no-cache, no-transform";

const ED25519_SPKI_PREFIX = Buffer.from("302a300506032b6570032100", "hex");

export interface IndexVersionEntry {
  version: string;
  api: number;
  min_app: string;
  file: string;
  size: number;
  sha256: string;
  permissions: string;
  changes?: Record<string, string>;
  may?: string[];
  tells?: string[];
  author?: string;
  license?: string;
  match_by?: string;
}

export interface IndexAddonEntry {
  id: string;
  listing?: IndexListing;
  versions: IndexVersionEntry[];
}

export interface WithdrawnEntry {
  id: string;
  versions: string;
  reason: string;
}

export interface IndexFile {
  format: 1;
  serial: number;
  issued: string;
  addons: IndexAddonEntry[];
  withdrawn: WithdrawnEntry[];
}

export interface KeysFile {
  url?: string;
  keys: string[];
}

export interface R2Client {
  list(opts: {
    prefix?: string;
    maxKeys?: number;
    continuationToken?: string;
  }): Promise<{
    contents?: Array<{ key?: string; size?: number }>;
    isTruncated?: boolean;
    nextContinuationToken?: string;
  }>;
  write(
    key: string,
    data: Uint8Array | string,
    opts?: { type?: string; cacheControl?: string },
  ): Promise<number>;
}

export type FetchLike = (
  input: string | URL,
  init?: RequestInit & { decompress?: boolean },
) => Promise<Response>;

export interface PublishOptions {
  repoRoot: string;
  baseUrl?: string;
  prefix?: string;
  dryRun?: boolean;
  force?: boolean;
  outDir?: string;
  signingKeyPem?: string;
  keysFilePath?: string;
  now?: Date;
  s3?: R2Client;
  fetchFn?: FetchLike;
  cloneFn?: (repo: string, commit: string) => string;
  log?: (msg: string) => void;
}

export interface PublishResult {
  changed: boolean;
  uploadedPackages: string[];
  skippedPackages: string[];
  serial: number;
  indexJson: string;
  signature: string;
  catalogJson: string;
}

export function formatUtcTimestamp(date: Date = new Date()): string {
  return date.toISOString().replace(/\.\d{3}Z$/, "Z");
}

function compareSemver(a: string, b: string): number {
  const parse = (v: string) => {
    const [core, pre] = v.split("-", 2);
    const [maj, min, pat] = core.split(".").map(Number);
    return { maj, min, pat, pre: pre ?? null };
  };
  const pa = parse(a);
  const pb = parse(b);
  if (pa.maj !== pb.maj) return pa.maj - pb.maj;
  if (pa.min !== pb.min) return pa.min - pb.min;
  if (pa.pat !== pb.pat) return pa.pat - pb.pat;
  if (pa.pre === pb.pre) return 0;
  if (pa.pre === null) return 1;
  if (pb.pre === null) return -1;
  return pa.pre < pb.pre ? -1 : 1;
}

/**
 * Signs exact `index.json` bytes with an Ed25519 PKCS#8 PEM private key.
 * Returns `<base64>\n` matching Rust `crates/addons/src/update/index.rs::signatures`.
 */
export function signIndexBytes(indexBytes: Uint8Array, privateKeyPem: string): string {
  const key = createPrivateKey(privateKeyPem);
  const sig = sign(null, indexBytes, key);
  if (sig.length !== 64) {
    throw new Error(`Unexpected Ed25519 signature length: ${sig.length}`);
  }
  return `${sig.toString("base64")}\n`;
}

/**
 * Verifies `index.json.sig` against any raw 32-byte base64 public key in `publicKeysBase64`.
 */
export function verifyIndexSignature(
  indexBytes: Uint8Array,
  signatureText: string,
  publicKeysBase64: readonly string[],
): boolean {
  const lines = signatureText
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  if (lines.length === 0 || lines.length > 4) return false;

  const sigBuffers = lines.map((line) => Buffer.from(line, "base64"));
  if (sigBuffers.some((b) => b.length !== 64)) return false;

  for (const keyB64 of publicKeysBase64) {
    const raw = Buffer.from(keyB64, "base64");
    if (raw.length !== 32) continue;
    const spki = Buffer.concat([ED25519_SPKI_PREFIX, raw]);
    const pubKey = createPublicKey({ key: spki, format: "der", type: "spki" });
    for (const sig of sigBuffers) {
      if (verify(null, indexBytes, pubKey, sig)) {
        return true;
      }
    }
  }
  return false;
}

/**
 * Exact equivalent of `ko-books/scripts/lib/r2.ts::storedSize`.
 */
export async function storedSize(s3: Pick<R2Client, "list">, key: string): Promise<number | null> {
  let continuationToken: string | undefined;
  do {
    const listed = await s3.list({
      prefix: key,
      maxKeys: 1000,
      ...(continuationToken ? { continuationToken } : {}),
    });
    const obj = listed.contents?.find((o) => o.key === key);
    if (obj) return obj.size ?? 0;
    continuationToken = listed.isTruncated ? listed.nextContinuationToken : undefined;
  } while (continuationToken);
  return null;
}

export type UploadAction =
  | { do: "upload" }
  | { do: "leave" }
  | { do: "refuse"; why: string };

/**
 * Exact equivalent of `ko-books/scripts/lib/r2.ts::uploadAction`.
 */
export function uploadAction(there: number | null, size: number, overwrite: boolean): UploadAction {
  if (size === 0) return { do: "refuse", why: "the local file is empty: nothing empty is published" };
  if (there === null || overwrite) return { do: "upload" };
  if (there === size) return { do: "leave" };
  return {
    do: "refuse",
    why: `it is already there with another size (${there} bytes): what is published is never written over`,
  };
}

export async function fetchLiveJson<T>(
  url: string,
  fetchFn: FetchLike,
): Promise<T | null> {
  const res = await fetchFn(url, {
    headers: { "User-Agent": "KoonaBooks", "Accept-Encoding": "identity" },
    decompress: false,
  });
  if (res.status === 404) return null;
  if (!res.ok) {
    throw new Error(`Failed to fetch ${url}: HTTP ${res.status}`);
  }
  return (await res.json()) as T;
}

export async function verifyRemoteBytes(
  url: string,
  expectedBytes: Uint8Array,
  fetchFn: FetchLike,
): Promise<void> {
  const res = await fetchFn(url, {
    headers: { "User-Agent": "KoonaBooks", "Accept-Encoding": "identity" },
    decompress: false,
  });
  if (!res.ok) {
    throw new Error(`HTTPS verification failed for ${url}: HTTP ${res.status}`);
  }
  const actual = new Uint8Array(await res.arrayBuffer());
  const expectedHash = sha256Hex(expectedBytes);
  const actualHash = sha256Hex(actual);
  if (actual.length !== expectedBytes.length || actualHash !== expectedHash) {
    throw new Error(
      `HTTPS verification mismatch for ${url}: expected ${expectedBytes.length} bytes (${expectedHash.slice(0, 12)}), got ${actual.length} bytes (${actualHash.slice(0, 12)})`,
    );
  }
}

function buildVersionEntry(packed: PackedAddon, isChecked: boolean): IndexVersionEntry {
  const entry: IndexVersionEntry = {
    version: packed.version,
    api: packed.api,
    min_app: packed.min_app,
    file: packed.file,
    size: packed.size,
    sha256: packed.sha256,
    permissions: packed.permissions,
  };
  if (Object.keys(packed.changes).length > 0) {
    entry.changes = packed.changes;
  }
  if (isChecked) {
    entry.may = packed.may;
    entry.tells = packed.tells;
    entry.author = packed.manifest.author.name;
    entry.license = packed.manifest.license;
    if (packed.matchBy) {
      entry.match_by = packed.matchBy;
    }
  }
  return entry;
}

function normalizeForDiff(index: Pick<IndexFile, "addons" | "withdrawn">): string {
  return JSON.stringify({ addons: index.addons, withdrawn: index.withdrawn });
}

function normalizeCatalogForDiff(addons: readonly CatalogAddon[]): string {
  return JSON.stringify(addons.map(({ updated: _u, ...rest }) => rest));
}

function catalogEntryFromLiveChecked(
  addon: IndexAddonEntry,
  registryEntry: RegistryEntry,
  prevCatalogEntry: CatalogAddon | undefined,
  updated: string,
): CatalogAddon {
  const listing = addon.listing!;
  const sorted = [...addon.versions].sort((a, b) => compareSemver(a.version, b.version));
  const newest = sorted[sorted.length - 1];
  const kinds = listing.provides.map((k) => KIND_LABELS[k] ?? k);
  const permissions = plainEnglishPermissionsFromCodes(newest.may ?? [], listing.category);
  const source = listing.source ?? registryEntry.repository ?? listing.homepage ?? "";

  return {
    group: "checked",
    id: addon.id,
    name: listing.name.en ?? addon.id,
    summary: listing.summary.en ?? "",
    category: listing.category,
    kinds,
    permissions,
    worksWith: listing.works_with?.devices ? [...listing.works_with.devices] : [],
    license: listing.license,
    author: listing.author.name,
    version: newest.version,
    minApp: newest.min_app,
    source,
    updated: prevCatalogEntry?.version === newest.version ? prevCatalogEntry.updated : updated,
  };
}

export async function runPublish(opts: PublishOptions): Promise<PublishResult> {
  const log = opts.log ?? ((msg: string) => console.log(msg));
  const fetchFn: FetchLike = opts.fetchFn ?? (fetch as FetchLike);
  const baseUrl = (opts.baseUrl ?? DEFAULT_BASE_URL).replace(/\/?$/, "/");
  const prefix = (opts.prefix ?? DEFAULT_PREFIX).replace(/^\/+/, "").replace(/\/?$/, "/");
  const nowStr = formatUtcTimestamp(opts.now);

  // 1. Load live index.json + catalog.json (single source of truth)
  let liveIndex: IndexFile | null = null;
  let liveCatalog: CatalogFile | null = null;
  if (opts.outDir && !opts.baseUrl) {
    // Local --out mode without explicit --base-url: read local <outDir>/index.json if present
    const localIdx = join(opts.outDir, "index.json");
    if (existsSync(localIdx)) {
      liveIndex = JSON.parse(readFileSync(localIdx, "utf8")) as IndexFile;
    }
    const localCat = join(opts.outDir, "catalog.json");
    if (existsSync(localCat)) {
      liveCatalog = JSON.parse(readFileSync(localCat, "utf8")) as CatalogFile;
    }
  } else {
    liveIndex = await fetchLiveJson<IndexFile>(`${baseUrl}index.json`, fetchFn);
    liveCatalog = await fetchLiveJson<CatalogFile>(`${baseUrl}catalog.json`, fetchFn);
  }

  const liveAddonsById = new Map<string, IndexAddonEntry>();
  for (const a of liveIndex?.addons ?? []) {
    liveAddonsById.set(a.id, structuredClone(a));
  }
  const liveCatalogById = new Map<string, CatalogAddon>();
  for (const c of liveCatalog?.addons ?? []) {
    liveCatalogById.set(c.id, c);
  }

  const packagesToUpload = new Map<string, Uint8Array>();
  const skippedPackages: string[] = [];
  const nextAddonsById = new Map<string, IndexAddonEntry>();
  const catalogAddons: CatalogAddon[] = [];

  // 2. Pack included add-ons from examples/
  const examplesDir = join(opts.repoRoot, "examples");
  if (existsSync(examplesDir)) {
    const folderNames = readdirSync(examplesDir).sort();
    for (const folderName of folderNames) {
      const dir = join(examplesDir, folderName);
      if (!existsSync(join(dir, "addon.json"))) continue;

      const packed = packAddonDir(dir);
      const existingAddon = liveAddonsById.get(packed.id);
      const existingVersion = existingAddon?.versions.find((v) => v.version === packed.version);

      if (existingVersion) {
        if (existingVersion.sha256 !== packed.sha256) {
          throw new Error(
            `Immutability violation: ${packed.id}@${packed.version} is already published with sha256=${existingVersion.sha256}, but local build has sha256=${packed.sha256}. Bump the version instead.`,
          );
        }
        skippedPackages.push(packed.file);
      } else {
        packagesToUpload.set(packed.file, packed.bytes);
      }

      const versions: IndexVersionEntry[] = existingAddon
        ? existingAddon.versions.map((v) => ({ ...v }))
        : [];
      if (!existingVersion) {
        versions.push(buildVersionEntry(packed, false));
      }
      versions.sort((a, b) => compareSemver(a.version, b.version));

      nextAddonsById.set(packed.id, {
        id: packed.id,
        versions,
      });

      const prevCat = liveCatalogById.get(packed.id);
      const entryUpdated = prevCat?.version === packed.version ? prevCat.updated : nowStr;
      catalogAddons.push(
        catalogEntryFromPacked(packed, {
          group: "included",
          source: `https://github.com/koona-project/books-addons/tree/main/examples/${folderName}`,
          updated: entryUpdated,
        }),
      );
    }
  }

  // 3. Process third-party add-ons from registry/*.json
  const registryDir = join(opts.repoRoot, "registry");
  if (existsSync(registryDir)) {
    const regFiles = readdirSync(registryDir)
      .filter((f) => f.endsWith(".json"))
      .sort();

    if (regFiles.length > 0) {
      const ctx = loadValidationContext(opts.repoRoot);
      for (const fileName of regFiles) {
        const filePath = join(registryDir, fileName);
        const raw = JSON.parse(readFileSync(filePath, "utf8"));
        const parsed = validateRegistryEntry(raw, fileName, ctx.checkedLicenses);
        if (!parsed.entry || parsed.errors.length > 0) {
          throw new Error(`Invalid registry file ${fileName}:\n${parsed.errors.join("\n")}`);
        }
        const entry = parsed.entry;
        const existingAddon = liveAddonsById.get(entry.id);
        const existingVersion = existingAddon?.versions.find((v) => v.version === entry.version);

        if (existingAddon && existingVersion && existingAddon.listing) {
          // Unchanged id@version: skip cloning and skip re-uploading!
          skippedPackages.push(existingVersion.file);
          nextAddonsById.set(entry.id, existingAddon);
          catalogAddons.push(
            catalogEntryFromLiveChecked(existingAddon, entry, liveCatalogById.get(entry.id), nowStr),
          );
          continue;
        }

        // New id or new version: clone, validate, and pack
        const validated = validateRegistryFile(filePath, ctx, { clone: opts.cloneFn });
        if (!validated.ok || !validated.packed) {
          throw new Error(
            `Registry entry ${entry.id}@${entry.version} failed validation:\n${validated.errors.join("\n")}`,
          );
        }
        const packed = validated.packed;
        if (existingVersion && existingVersion.sha256 !== packed.sha256) {
          throw new Error(
            `Immutability violation: ${packed.id}@${packed.version} is already published with different SHA-256.`,
          );
        }

        packagesToUpload.set(packed.file, packed.bytes);

        const versions: IndexVersionEntry[] = existingAddon
          ? existingAddon.versions.map((v) => ({ ...v }))
          : [];
        if (!existingVersion) {
          versions.push(buildVersionEntry(packed, true));
        }
        versions.sort((a, b) => compareSemver(a.version, b.version));

        const newest = versions[versions.length - 1];
        const listing =
          newest.version === packed.version || !existingAddon?.listing
            ? packed.listing
            : existingAddon.listing;

        nextAddonsById.set(packed.id, {
          id: packed.id,
          listing,
          versions,
        });

        const sourceUrl = packed.manifest.source ?? entry.repository ?? packed.manifest.homepage ?? "";
        catalogAddons.push(
          catalogEntryFromPacked(packed, {
            group: "checked",
            source: sourceUrl,
            updated: nowStr,
          }),
        );
      }
    }
  }

  // 4. Load withdrawn.json
  const withdrawnPath = join(opts.repoRoot, "withdrawn.json");
  const withdrawn: WithdrawnEntry[] = existsSync(withdrawnPath)
    ? (JSON.parse(readFileSync(withdrawnPath, "utf8")) as WithdrawnEntry[])
    : [];

  // Sort addons deterministically by id; catalog by group (checked first? or name)
  const addons = [...nextAddonsById.values()].sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  catalogAddons.sort((a, b) => a.name.localeCompare(b.name) || (a.id < b.id ? -1 : 1));

  // 5. Check whether anything actually changed
  const indexUnchanged =
    liveIndex !== null &&
    normalizeForDiff({ addons, withdrawn }) ===
      normalizeForDiff({ addons: liveIndex.addons, withdrawn: liveIndex.withdrawn });
  const catalogUnchanged =
    liveCatalog !== null &&
    normalizeCatalogForDiff(catalogAddons) === normalizeCatalogForDiff(liveCatalog.addons);

  if (packagesToUpload.size === 0 && indexUnchanged && catalogUnchanged && !opts.force) {
    log("Already up to date — nothing uploaded");
    return {
      changed: false,
      uploadedPackages: [],
      skippedPackages,
      serial: liveIndex!.serial,
      indexJson: `${JSON.stringify(liveIndex, null, 2)}\n`,
      signature: "",
      catalogJson: `${JSON.stringify(liveCatalog, null, 2)}\n`,
    };
  }

  const nextSerial = (liveIndex?.serial ?? 0) + 1;
  const nextIndex: IndexFile = {
    format: 1,
    serial: nextSerial,
    issued: nowStr,
    addons,
    withdrawn,
  };
  const nextCatalog: CatalogFile = {
    format: 1,
    updated: nowStr,
    addons: catalogAddons,
  };

  const indexJson = `${JSON.stringify(nextIndex, null, 2)}\n`;
  const catalogJson = `${JSON.stringify(nextCatalog, null, 2)}\n`;
  const indexBytes = new TextEncoder().encode(indexJson);
  const catalogBytes = new TextEncoder().encode(catalogJson);

  // 6. Sign index.json & verify signature against schema/addons-keys.json BEFORE uploading anything
  const signingKeyPem = opts.signingKeyPem ?? process.env.ADDONS_SIGNING_KEY;
  let signature = "";

  if (signingKeyPem) {
    signature = signIndexBytes(indexBytes, signingKeyPem);
    const keysPath = opts.keysFilePath ?? join(opts.repoRoot, "schema", "addons-keys.json");
    if (!existsSync(keysPath)) {
      throw new Error(`Missing public keys file: ${keysPath}`);
    }
    const keysFile = JSON.parse(readFileSync(keysPath, "utf8")) as KeysFile;
    if (!Array.isArray(keysFile.keys) || keysFile.keys.length === 0) {
      throw new Error(`No public keys found in ${keysPath}`);
    }
    if (!verifyIndexSignature(indexBytes, signature, keysFile.keys)) {
      throw new Error(
        `Signature self-verification FAILED against ${keysPath}! Aborting before uploading anything.`,
      );
    }
  } else if (!opts.dryRun) {
    throw new Error("Missing ADDONS_SIGNING_KEY environment variable (required to sign index.json)");
  }

  const sigBytes = new TextEncoder().encode(signature);
  const uploadedPackages = [...packagesToUpload.keys()].sort();

  // 7. Local --out mode
  if (opts.outDir) {
    mkdirSync(opts.outDir, { recursive: true });
    for (const [fileName, bytes] of packagesToUpload) {
      writeFileSync(join(opts.outDir, fileName), bytes);
    }
    writeFileSync(join(opts.outDir, "index.json"), indexBytes);
    if (signature) {
      writeFileSync(join(opts.outDir, "index.json.sig"), sigBytes);
    }
    writeFileSync(join(opts.outDir, "catalog.json"), catalogBytes);
    log(
      `Wrote ${uploadedPackages.length} package(s), index.json (serial ${nextSerial}), index.json.sig, catalog.json to ${opts.outDir}`,
    );
    return {
      changed: true,
      uploadedPackages,
      skippedPackages,
      serial: nextSerial,
      indexJson,
      signature,
      catalogJson,
    };
  }

  // 8. Dry-run mode
  if (opts.dryRun) {
    log(
      `[dry-run] Would upload ${uploadedPackages.length} new package(s) (skipping ${skippedPackages.length} unchanged), index.json (serial ${nextSerial}), index.json.sig, catalog.json`,
    );
    for (const f of uploadedPackages) {
      log(`  + ${f} (${packagesToUpload.get(f)!.length} bytes)`);
    }
    return {
      changed: true,
      uploadedPackages,
      skippedPackages,
      serial: nextSerial,
      indexJson,
      signature,
      catalogJson,
    };
  }

  // 9. Upload to Cloudflare R2 + HTTPS verification
  if (!opts.s3) {
    throw new Error("R2 S3Client is required for live publish");
  }

  // 9a. Upload ONLY missing .kbooksaddon packages (overwrite: false)
  for (const fileName of uploadedPackages) {
    const bytes = packagesToUpload.get(fileName)!;
    const key = `${prefix}${fileName}`;
    const there = await storedSize(opts.s3, key);
    const action = uploadAction(there, bytes.length, false);
    if (action.do === "refuse") {
      throw new Error(`Refused to upload ${key}: ${action.why}`);
    }
    if (action.do === "upload") {
      await opts.s3.write(key, bytes, {
        type: "application/octet-stream",
        cacheControl: PACKAGE_CACHE_CONTROL,
      });
      log(`Uploaded ${key} (${bytes.length} bytes)`);
    } else {
      log(`Already present in R2: ${key} (${bytes.length} bytes)`);
    }
    await verifyRemoteBytes(`${baseUrl}${fileName}`, bytes, fetchFn);
  }

  // 9b. Upload index.json.sig, index.json, catalog.json and verify all three over HTTPS
  const metadataFiles: Array<{ name: string; bytes: Uint8Array; type: string }> = [
    { name: "index.json.sig", bytes: sigBytes, type: "text/plain; charset=utf-8" },
    { name: "index.json", bytes: indexBytes, type: "application/json; charset=utf-8" },
    { name: "catalog.json", bytes: catalogBytes, type: "application/json; charset=utf-8" },
  ];

  for (const f of metadataFiles) {
    const key = `${prefix}${f.name}`;
    await opts.s3.write(key, f.bytes, {
      type: f.type,
      cacheControl: INDEX_CACHE_CONTROL,
    });
    log(`Uploaded ${key} (${f.bytes.length} bytes)`);
  }

  for (const f of metadataFiles) {
    await verifyRemoteBytes(`${baseUrl}${f.name}`, f.bytes, fetchFn);
  }

  log(
    `Published serial ${nextSerial}: ${uploadedPackages.length} new package(s), ${skippedPackages.length} unchanged, verified over HTTPS.`,
  );

  return {
    changed: true,
    uploadedPackages,
    skippedPackages,
    serial: nextSerial,
    indexJson,
    signature,
    catalogJson,
  };
}

/**
 * Verifies the live bucket (`index.json`, `index.json.sig` against `schema/addons-keys.json`, and `catalog.json`).
 */
export async function checkLiveBucket(opts: {
  repoRoot: string;
  baseUrl?: string;
  keysFilePath?: string;
  fetchFn?: FetchLike;
  log?: (msg: string) => void;
}): Promise<void> {
  const fetchFn: FetchLike = opts.fetchFn ?? (fetch as FetchLike);
  const log = opts.log ?? ((msg: string) => console.log(msg));
  const baseUrl = (opts.baseUrl ?? DEFAULT_BASE_URL).replace(/\/?$/, "/");
  const keysPath = opts.keysFilePath ?? join(opts.repoRoot, "schema", "addons-keys.json");
  const keysFile = JSON.parse(readFileSync(keysPath, "utf8")) as KeysFile;

  const headers = { "User-Agent": "KoonaBooks", "Accept-Encoding": "identity" };
  const [idxRes, sigRes, catRes] = await Promise.all([
    fetchFn(`${baseUrl}index.json`, { headers, decompress: false }),
    fetchFn(`${baseUrl}index.json.sig`, { headers, decompress: false }),
    fetchFn(`${baseUrl}catalog.json`, { headers, decompress: false }),
  ]);

  if (!idxRes.ok) throw new Error(`index.json returned HTTP ${idxRes.status}`);
  if (!sigRes.ok) throw new Error(`index.json.sig returned HTTP ${sigRes.status}`);
  if (!catRes.ok) throw new Error(`catalog.json returned HTTP ${catRes.status}`);

  const idxBytes = new Uint8Array(await idxRes.arrayBuffer());
  const sigText = await sigRes.text();
  if (!verifyIndexSignature(idxBytes, sigText, keysFile.keys)) {
    throw new Error("Live index.json.sig failed signature verification!");
  }

  const index = JSON.parse(new TextDecoder().decode(idxBytes)) as IndexFile;
  const catalog = (await catRes.json()) as CatalogFile;
  log(
    `Live check OK: serial=${index.serial}, ${index.addons.length} add-on(s) in index.json, ${catalog.addons.length} in catalog.json.`,
  );
}
