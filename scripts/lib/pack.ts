import { createHash } from "node:crypto";
import { lstatSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { zipFiles, type ZipEntry } from "./zip.ts";

export const PACKAGE_EXTENSION = ".kbooksaddon";
export const MAX_PACKAGE = 2 * 1024 * 1024;
export const MAX_FILES = 64;
export const MAX_SOURCE = 256 * 1024;
export const MAX_FILE = 1024 * 1024;
export const MAX_UNPACKED = 4 * 1024 * 1024;
export const MAX_FILE_PARTS = 3;
export const MAX_LANGUAGES = 40;

export interface ManifestAuthor {
  name: string;
  url?: string;
}

export interface ManifestWorksWith {
  devices: string[];
  needs?: string;
}

export interface ManifestSignIn {
  kind: string;
  issuer: string;
  authorize: string;
  token: string;
  revoke?: string;
  client_id: string;
  scopes: string[];
}

export interface ManifestPermissions {
  network?: {
    hosts?: string[];
    local_device?: { ports: number[] };
    named_server?: boolean;
    pace?: { per_minute: number; burst: number };
  };
  secrets?: boolean;
  reading_state?: boolean;
  input_file?: string[];
  book_query?: boolean;
  book_details?: boolean;
  links?: { hosts: string[] };
  sign_in?: ManifestSignIn;
}

export interface ManifestPrivacy {
  sends: string[];
  collects: string[];
}

export interface ManifestProvides {
  type: string;
  id: string;
  entry?: string;
  data?: string;
  directions?: string[];
  carries?: string[];
  match_by?: string;
  finds_by?: string[];
  gives?: string;
  host?: string;
  readers?: string[];
  [key: string]: unknown;
}

export interface Manifest {
  schema: number;
  id: string;
  version: string;
  api: number;
  min_app: string;
  name: Record<string, string>;
  summary: Record<string, string>;
  glyph?: string;
  category: string;
  author: ManifestAuthor;
  homepage?: string;
  source?: string;
  support?: string;
  license: string;
  works_with?: ManifestWorksWith;
  tested?: { on: string; date: string };
  permissions?: ManifestPermissions;
  privacy: ManifestPrivacy;
  settings?: Array<{ key: string; type: string; [key: string]: unknown }>;
  provides: ManifestProvides[];
}

export interface IndexListing {
  name: Record<string, string>;
  summary: Record<string, string>;
  author: { name: string; url?: string };
  license: string;
  category: string;
  glyph?: string;
  homepage?: string;
  source?: string;
  support?: string;
  works_with?: { devices: string[]; needs?: string };
  provides: string[];
  languages: string[];
  match_by?: string;
}

export interface PackedAddon {
  id: string;
  version: string;
  api: number;
  min_app: string;
  file: string;
  bytes: Uint8Array;
  size: number;
  sha256: string;
  permissions: string;
  changes: Record<string, string>;
  may: string[];
  tells: string[];
  listing: IndexListing;
  matchBy?: string;
  manifest: Manifest;
  files: Map<string, Uint8Array>;
}

export interface CatalogAddon {
  group: "included" | "checked";
  id: string;
  name: string;
  summary: string;
  category: string;
  kinds: string[];
  permissions: string[];
  worksWith: string[];
  license: string;
  author: string;
  version: string;
  minApp: string;
  source: string;
  updated: string;
}

export interface CatalogFile {
  format: 1;
  updated: string;
  addons: CatalogAddon[];
}

const WINDOWS_DEVICE_RE = /^(con|prn|aux|nul|com[1-9]|lpt[1-9])$/i;
const PART_RE = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;
const utf8Decoder = new TextDecoder("utf-8", { fatal: true });

export function sha256Hex(data: Uint8Array | string): string {
  return createHash("sha256").update(data).digest("hex");
}

function compareCodepoints(a: string, b: string): number {
  return a < b ? -1 : a > b ? 1 : 0;
}

export function sortAndDedup(items: readonly string[]): string[] {
  const sorted = [...items].sort(compareCodepoints);
  const out: string[] = [];
  for (const item of sorted) {
    if (out.length === 0 || out[out.length - 1] !== item) {
      out.push(item);
    }
  }
  return out;
}

export function normalizeUrl(url: string): string {
  return new URL(url).href;
}

export function packageFileName(id: string, version: string): string {
  return `${id}-${version}${PACKAGE_EXTENSION}`;
}

export function fileExtensionKind(name: string): "lua" | "json" | "md" | null {
  const last = name.slice(name.lastIndexOf("/") + 1);
  const dot = last.lastIndexOf(".");
  if (dot <= 0) return null;
  const ext = last.slice(dot + 1);
  if (ext === "lua" || ext === "json" || ext === "md") return ext;
  return null;
}

export function validateRelativePath(name: string): void {
  if (!name || name.length > 100) {
    throw new Error(`Invalid file path length: "${name}"`);
  }
  if (name.includes("\0") || name.includes("\\") || name.startsWith("/") || /^[A-Za-z]:/.test(name)) {
    throw new Error(`Path leaves package root: "${name}"`);
  }
  const parts = name.split("/");
  if (parts.length > MAX_FILE_PARTS) {
    throw new Error(`Path too deep (max ${MAX_FILE_PARTS} parts): "${name}"`);
  }
  for (const part of parts) {
    if (!part || part === "." || part === ".." || part.startsWith(".") || part.startsWith("-") || !PART_RE.test(part)) {
      throw new Error(`Invalid path segment "${part}" in "${name}"`);
    }
    const base = part.includes(".") ? part.slice(0, part.indexOf(".")) : part;
    if (WINDOWS_DEVICE_RE.test(base)) {
      throw new Error(`Reserved Windows device name in "${name}"`);
    }
  }
  const first = parts[0];
  if (first !== "locales" && first.toLowerCase() === "locales") {
    throw new Error(`Invalid locales folder casing: "${name}"`);
  }
}

export function collectPackageFiles(dir: string): Map<string, Uint8Array> {
  const files = new Map<string, Uint8Array>();
  const folded = new Set<string>();
  let totalUnpacked = 0;

  function walk(current: string, prefix: string): void {
    const entries = readdirSync(current).sort(compareCodepoints);
    for (const part of entries) {
      const fullPath = join(current, part);
      const stat = lstatSync(fullPath);

      // Skip git's own folder/file at the repository root (matching crates/addons/src/package.rs)
      if (!prefix && part === ".git" && !stat.isSymbolicLink() && (stat.isDirectory() || stat.isFile())) {
        continue;
      }

      const rel = prefix ? `${prefix}/${part}` : part;
      if (stat.isSymbolicLink()) {
        throw new Error(`Symlinks are not allowed in an add-on package: "${rel}"`);
      }

      if (stat.isDirectory()) {
        validateRelativePath(rel);
        if (rel.split("/").length >= MAX_FILE_PARTS) {
          throw new Error(`Folder too deep: "${rel}"`);
        }
        walk(fullPath, rel);
      } else if (stat.isFile()) {
        validateRelativePath(rel);
        const kind = fileExtensionKind(rel);
        if (!kind) {
          throw new Error(`Disallowed file extension (only .lua, .json, .md allowed): "${rel}"`);
        }
        if (files.size >= MAX_FILES) {
          throw new Error(`Too many files in package (max ${MAX_FILES})`);
        }
        const lower = rel.toLowerCase();
        if (folded.has(lower)) {
          throw new Error(`Duplicate file path (case-insensitive): "${rel}"`);
        }
        folded.add(lower);

        const cap = kind === "lua" ? MAX_SOURCE : MAX_FILE;
        if (stat.size > cap) {
          throw new Error(`File too large (${stat.size} > ${cap}): "${rel}"`);
        }
        const data = new Uint8Array(readFileSync(fullPath));
        if (data.length > cap) {
          throw new Error(`File too large (${data.length} > ${cap}): "${rel}"`);
        }
        totalUnpacked += data.length;
        if (totalUnpacked > MAX_UNPACKED) {
          throw new Error(`Unpacked package exceeds ${MAX_UNPACKED} bytes`);
        }
        // Check UTF-8, no BOM, no NUL
        if (data.length >= 3 && data[0] === 0xef && data[1] === 0xbb && data[2] === 0xbf) {
          throw new Error(`UTF-8 BOM is not allowed: "${rel}"`);
        }
        if (data.includes(0)) {
          throw new Error(`NUL byte is not allowed in text file: "${rel}"`);
        }
        try {
          utf8Decoder.decode(data);
        } catch {
          throw new Error(`File is not valid UTF-8: "${rel}"`);
        }

        files.set(rel, data);
      } else {
        throw new Error(`Unsupported file type: "${rel}"`);
      }
    }
  }

  walk(dir, "");

  // Ensure no file shares a name with a folder prefix
  for (const name of files.keys()) {
    let idx = name.indexOf("/");
    while (idx !== -1) {
      const folder = name.slice(0, idx).toLowerCase();
      if (folded.has(folder)) {
        throw new Error(`File/folder name collision: "${name.slice(0, idx)}"`);
      }
      idx = name.indexOf("/", idx + 1);
    }
  }

  return files;
}

/**
 * Exact equivalent of Rust `crates/addons/src/installed.rs::permission_codes`.
 */
export function permissionCodes(permissions: ManifestPermissions | undefined): string[] {
  if (!permissions) return [];
  const codes: string[] = [];

  const network = permissions.network;
  if (network) {
    for (const host of network.hosts ?? []) {
      codes.push(`network.host:${host}`);
    }
    if (network.local_device?.ports) {
      const ports = [...network.local_device.ports].sort((a, b) => a - b);
      for (const port of ports) {
        codes.push(`network.local_device:${port}`);
      }
    }
    if (network.named_server) {
      codes.push("network.named_server");
    }
  }

  if (permissions.secrets) {
    codes.push("secrets");
  }
  if (permissions.reading_state) {
    codes.push("reading_state");
  }
  for (const ext of permissions.input_file ?? []) {
    codes.push(`input_file:${ext}`);
  }
  if (permissions.book_query) {
    codes.push("book_query");
  }
  if (permissions.book_details) {
    codes.push("book_details");
  }
  for (const host of permissions.links?.hosts ?? []) {
    codes.push(`links:${host}`);
  }
  if (permissions.sign_in) {
    const s = permissions.sign_in;
    const authorizeUrl = new URL(s.authorize);
    const tokenUrl = new URL(s.token);
    codes.push(`sign_in:${authorizeUrl.hostname}`);
    for (const scope of s.scopes ?? []) {
      codes.push(`sign_in.scope:${scope}`);
    }
    codes.push(`sign_in.authorize:${authorizeUrl.href}`);
    const issuerHost = s.issuer.startsWith("https://") ? s.issuer.slice("https://".length) : s.issuer;
    codes.push(`sign_in.issuer:${issuerHost}`);
    codes.push(`sign_in.client:${s.client_id}`);
    codes.push(`sign_in.token:${tokenUrl.href}`);
    if (s.revoke) {
      codes.push(`sign_in.revoke:${new URL(s.revoke).href}`);
    }
  }

  return sortAndDedup(codes);
}

/**
 * Exact equivalent of Rust `crates/addons/src/installed.rs::provides_codes`.
 */
export function providesCodes(manifest: Manifest): string[] {
  const codes: string[] = [];
  for (const entry of manifest.provides ?? []) {
    const head = `provides.${entry.type}:${entry.id}`;
    switch (entry.type) {
      case "reading_sync":
        for (const d of entry.directions ?? []) {
          codes.push(`${head}.direction:${d}`);
        }
        for (const c of entry.carries ?? []) {
          codes.push(`${head}.carries:${c}`);
        }
        if (entry.match_by) {
          codes.push(`${head}.match_by:${entry.match_by}`);
        }
        break;
      case "list_import":
        for (const c of entry.carries ?? []) {
          codes.push(`${head}.carries:${c}`);
        }
        break;
      case "book_info":
        for (const b of entry.finds_by ?? []) {
          codes.push(`${head}.finds_by:${b}`);
        }
        break;
      case "book_action":
        if (entry.gives) {
          codes.push(`${head}.gives:${entry.gives}`);
        }
        break;
      case "device_profiles":
        for (const r of entry.readers ?? []) {
          codes.push(`${head}.reader:${r}`);
        }
        break;
      default:
        break;
    }
    codes.push(head);
  }
  return sortAndDedup(codes);
}

/**
 * Exact equivalent of Rust `crates/addons/src/installed.rs::may_codes`.
 */
export function mayCodes(manifest: Manifest): string[] {
  return sortAndDedup([...permissionCodes(manifest.permissions), ...providesCodes(manifest)]);
}

/**
 * Exact equivalent of Rust `crates/addons/src/installed.rs::privacy_codes`.
 */
export function privacyCodes(privacy: ManifestPrivacy | undefined): string[] {
  if (!privacy) return [];
  const codes: string[] = [];
  for (const s of privacy.sends ?? []) {
    codes.push(`sends.${s}`);
  }
  for (const c of privacy.collects ?? []) {
    codes.push(`collects.${c}`);
  }
  return sortAndDedup(codes);
}

/**
 * Exact equivalent of Rust `crates/addons/src/update/index.rs::permissions_digest`.
 */
export function permissionsDigest(manifest: Manifest): string {
  const all = sortAndDedup([...mayCodes(manifest), ...privacyCodes(manifest.privacy)]);
  return sha256Hex(all.join("\n"));
}

/**
 * Computes the `listing` object matching Rust `crates/addons/src/update/index.rs::Listing::of`
 * and `Listing::to_json`.
 */
export function buildListing(manifest: Manifest, fileNames: readonly string[]): IndexListing {
  const provides: string[] = [];
  for (const entry of manifest.provides ?? []) {
    if (!provides.includes(entry.type)) {
      provides.push(entry.type);
    }
  }

  const languages = [...fileNames]
    .sort(compareCodepoints)
    .filter((n) => n.startsWith("locales/") && n.endsWith(".json"))
    .map((n) => n.slice("locales/".length, -".json".length));

  const author: { name: string; url?: string } = { name: manifest.author.name };
  if (manifest.author.url) {
    author.url = normalizeUrl(manifest.author.url);
  }

  const listing: IndexListing = {
    name: { ...manifest.name },
    summary: { ...manifest.summary },
    author,
    license: manifest.license,
    category: manifest.category,
    provides,
    languages,
  };

  if (manifest.glyph) listing.glyph = manifest.glyph;
  if (manifest.homepage) listing.homepage = normalizeUrl(manifest.homepage);
  if (manifest.source) listing.source = normalizeUrl(manifest.source);
  if (manifest.support) listing.support = normalizeUrl(manifest.support);
  if (manifest.works_with) {
    listing.works_with = {
      devices: [...manifest.works_with.devices],
      ...(manifest.works_with.needs ? { needs: manifest.works_with.needs } : {}),
    };
  }
  const syncEntry = manifest.provides.find((p) => p.type === "reading_sync");
  if (syncEntry?.match_by) {
    listing.match_by = syncEntry.match_by;
  }

  return listing;
}

/**
 * Extracts `changes` from `locales/<tag>.json` files, matching Rust `pack.rs::facts`.
 */
export function extractChanges(files: Map<string, Uint8Array>): Record<string, string> {
  const changes: Record<string, string> = {};
  const names = [...files.keys()].sort(compareCodepoints);
  for (const name of names) {
    if (!name.startsWith("locales/") || !name.endsWith(".json")) continue;
    const tag = name.slice("locales/".length, -".json".length);
    const bytes = files.get(name)!;
    const parsed = JSON.parse(utf8Decoder.decode(bytes)) as Record<string, unknown>;
    if (typeof parsed.changes === "string") {
      changes[tag] = parsed.changes;
    }
  }
  if (Object.keys(changes).length > MAX_LANGUAGES) {
    throw new Error(`Too many change languages (max ${MAX_LANGUAGES})`);
  }
  return changes;
}

/**
 * Packs an add-on folder into a deterministic `.kbooksaddon` archive and computes all index facts.
 */
export function packAddonDir(dir: string): PackedAddon {
  const files = collectPackageFiles(dir);
  const manifestBytes = files.get("addon.json");
  if (!manifestBytes) {
    throw new Error(`Missing addon.json in ${dir}`);
  }
  const manifest = JSON.parse(utf8Decoder.decode(manifestBytes)) as Manifest;
  if (!manifest.id || !manifest.version || !manifest.api || !manifest.min_app) {
    throw new Error(`Invalid manifest in ${dir}: missing required fields`);
  }

  // Verify referenced entry/data files exist
  for (const p of manifest.provides ?? []) {
    const ref = p.entry ?? p.data;
    if (ref && !files.has(ref)) {
      throw new Error(`Manifest references missing file "${ref}" in ${dir}`);
    }
  }

  // If any locale file exists, locales/en.json must exist
  const localeFiles = [...files.keys()].filter((n) => n.startsWith("locales/"));
  if (localeFiles.length > 0 && !files.has("locales/en.json")) {
    throw new Error(`Missing locales/en.json in ${dir}`);
  }

  const entries: ZipEntry[] = [...files.entries()].map(([name, data]) => ({ name, data }));
  const bytes = zipFiles(entries);
  if (bytes.length > MAX_PACKAGE) {
    throw new Error(`Packed archive exceeds ${MAX_PACKAGE} bytes (${bytes.length})`);
  }

  const file = packageFileName(manifest.id, manifest.version);
  const may = mayCodes(manifest);
  const tells = privacyCodes(manifest.privacy);
  const permissions = permissionsDigest(manifest);
  const changes = extractChanges(files);
  const listing = buildListing(manifest, [...files.keys()]);
  const syncEntry = manifest.provides.find((p) => p.type === "reading_sync");

  return {
    id: manifest.id,
    version: manifest.version,
    api: manifest.api,
    min_app: manifest.min_app,
    file,
    bytes,
    size: bytes.length,
    sha256: sha256Hex(bytes),
    permissions,
    changes,
    may,
    tells,
    listing,
    matchBy: syncEntry?.match_by,
    manifest,
    files,
  };
}

// ---- Plain-English catalog helpers (matching addme.dev/books/lib/words.mjs) ---------------------

export const KIND_LABELS: Record<string, string> = {
  send_target: "Send target",
  device_profiles: "Reader profiles",
  import_source: "Import source",
  reading_sync: "Reading sync",
  book_info: "Book information",
  book_action: "Book action",
  list_export: "List exporter",
  list_import: "List importer",
};

export function plainEnglishKinds(manifest: Manifest): string[] {
  const seen: string[] = [];
  for (const entry of manifest.provides ?? []) {
    const label = KIND_LABELS[entry.type] ?? entry.type;
    if (!seen.includes(label)) seen.push(label);
  }
  return seen;
}

function hostOf(address: string): string {
  try {
    return new URL(address).host;
  } catch {
    return address;
  }
}

export function plainEnglishPermissions(manifest: Manifest): string[] {
  const asked = manifest.permissions ?? {};
  const tools = manifest.category === "tools";
  const lines: string[] = [];

  for (const [key, value] of Object.entries(asked)) {
    if (value === false || value === null || value === undefined) continue;
    if (key === "network") {
      const net = value as NonNullable<ManifestPermissions["network"]>;
      const hosts = (net.hosts ?? []).map((host) =>
        host.startsWith("*.") ? `any site whose name ends in ${host.slice(1)}` : host,
      );
      if (hosts.length > 0) lines.push(`Reaches ${hosts.join(", ")} on the internet`);
      if (net.local_device) lines.push("Reaches one device on your network, at the address you give");
      if (net.named_server) lines.push("Reaches one server whose address you type");
    } else if (key === "secrets") {
      lines.push("Reads the password you type into its form");
    } else if (key === "sign_in") {
      const signIn = value as ManifestSignIn;
      lines.push(
        `Signs you in at ${hostOf(signIn.authorize ?? signIn.issuer ?? "its service")}, in your browser, and then acts in your account there`,
      );
    } else if (key === "reading_state") {
      if (tools) {
        lines.push(
          asked.input_file
            ? "Changes the reading status of your books from a file you pick, after you confirm"
            : "Sees the reading status and dates of the books you choose",
        );
      } else {
        lines.push("Sees the reading state of the books you sync");
      }
    } else if (key === "input_file") {
      lines.push(`Reads one file you pick (${([] as string[]).concat(value as string[]).join(", ")})`);
    } else if (key === "book_query") {
      lines.push("Sees the title, authors and ISBN of the books you look up");
    } else if (key === "book_details") {
      lines.push("Sees the details of the books you choose");
    } else if (key === "links") {
      const links = value as { hosts?: string[] };
      lines.push(
        `Opens pages at ${(links.hosts ?? []).join(", ")} with the title, author and ISBN of the book you choose`,
      );
    } else {
      lines.push(key);
    }
  }

  if (!asked.network) {
    lines.push("Does not use the network");
  }
  return lines;
}

/**
 * Generates plain-English permission lines from index codes (`may`) when a live checked add-on
 * wasn't re-cloned during an incremental publish run.
 */
export function plainEnglishPermissionsFromCodes(may: readonly string[], category: string): string[] {
  const hosts: string[] = [];
  let localDevice = false;
  let namedServer = false;
  let secrets = false;
  let readingState = false;
  const inputFiles: string[] = [];
  let bookQuery = false;
  let bookDetails = false;
  const links: string[] = [];
  let signInHost: string | null = null;

  for (const code of may) {
    if (code.startsWith("provides.")) continue;
    if (code.startsWith("network.host:")) {
      const h = code.slice("network.host:".length);
      hosts.push(h.startsWith("*.") ? `any site whose name ends in ${h.slice(1)}` : h);
    } else if (code.startsWith("network.local_device:")) {
      localDevice = true;
    } else if (code === "network.named_server") {
      namedServer = true;
    } else if (code === "secrets") {
      secrets = true;
    } else if (code === "reading_state") {
      readingState = true;
    } else if (code.startsWith("input_file:")) {
      inputFiles.push(code.slice("input_file:".length));
    } else if (code === "book_query") {
      bookQuery = true;
    } else if (code === "book_details") {
      bookDetails = true;
    } else if (code.startsWith("links:")) {
      links.push(code.slice("links:".length));
    } else if (code.startsWith("sign_in:")) {
      signInHost = code.slice("sign_in:".length);
    }
  }

  const lines: string[] = [];
  if (hosts.length > 0) lines.push(`Reaches ${hosts.join(", ")} on the internet`);
  if (localDevice) lines.push("Reaches one device on your network, at the address you give");
  if (namedServer) lines.push("Reaches one server whose address you type");
  if (secrets) lines.push("Reads the password you type into its form");
  if (signInHost) {
    lines.push(`Signs you in at ${signInHost}, in your browser, and then acts in your account there`);
  }
  if (readingState) {
    if (category === "tools") {
      lines.push(
        inputFiles.length > 0
          ? "Changes the reading status of your books from a file you pick, after you confirm"
          : "Sees the reading status and dates of the books you choose",
      );
    } else {
      lines.push("Sees the reading state of the books you sync");
    }
  }
  if (inputFiles.length > 0) {
    lines.push(`Reads one file you pick (${inputFiles.join(", ")})`);
  }
  if (bookQuery) lines.push("Sees the title, authors and ISBN of the books you look up");
  if (bookDetails) lines.push("Sees the details of the books you choose");
  if (links.length > 0) {
    lines.push(`Opens pages at ${links.join(", ")} with the title, author and ISBN of the book you choose`);
  }
  if (hosts.length === 0 && !localDevice && !namedServer) {
    lines.push("Does not use the network");
  }
  return lines;
}

export function catalogEntryFromPacked(
  packed: PackedAddon,
  opts: { group: "included" | "checked"; source: string; updated: string },
): CatalogAddon {
  const m = packed.manifest;
  return {
    group: opts.group,
    id: m.id,
    name: m.name.en ?? m.id,
    summary: m.summary.en ?? "",
    category: m.category,
    kinds: plainEnglishKinds(m),
    permissions: plainEnglishPermissions(m),
    worksWith: m.works_with?.devices ? [...m.works_with.devices] : [],
    license: m.license,
    author: m.author.name,
    version: m.version,
    minApp: m.min_app,
    source: opts.source,
    updated: opts.updated,
  };
}
