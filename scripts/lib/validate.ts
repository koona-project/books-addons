import { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, join, resolve } from "node:path";
import { packAddonDir, type Manifest, type PackedAddon } from "./pack.ts";
import { validateJsonSchema } from "./schema.ts";

export interface RegistryEntry {
  id: string;
  version: string;
  repository: string;
  folder: string;
  commit: string;
  license: string;
}

export interface ReviewRules {
  license_file: {
    name: string;
    more_than_bytes: number;
    placeholders: string[];
    apache_placeholders: string[];
    apache_terms: string;
    todo: string;
    missing_code: string;
    stub_code: string;
  };
  placeholder_author: { code: string; name: string };
  placeholder_host: { code: string; domains: string[] };
  placeholder_id: { code: string; prefixes: string[] };
}

export interface ValidationContext {
  schema: Record<string, unknown>;
  checkedLicenses: string[];
  reviewRules: ReviewRules;
  includedIds: Set<string>;
  includedNames: Set<string>;
}

export interface ValidationResult {
  ok: boolean;
  entry: RegistryEntry;
  errors: string[];
  packed?: PackedAddon;
}

const REGISTRY_KEYS = new Set(["id", "version", "repository", "folder", "commit", "license"]);
const ID_RE = /^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?){1,5}$/;
const SEMVER_RE = /^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$/;
const COMMIT_RE = /^[0-9a-f]{40}$/;
const GITHUB_REPO_RE = /^https:\/\/github\.com\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;

/**
 * Simple folded name key for detecting obvious collisions with Koona or included add-ons.
 */
export function foldNameKey(text: string): string {
  return text
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[аА]/g, "a")
    .replace(/[еЕ]/g, "e")
    .replace(/[оО]/g, "o")
    .replace(/[рР]/g, "p")
    .replace(/[сС]/g, "c")
    .replace(/[уУ]/g, "y")
    .replace(/[хХ]/g, "x")
    .replace(/[кК]/g, "k")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "");
}

export function saysKoona(text: string): boolean {
  return foldNameKey(text).includes("koona");
}

export function loadValidationContext(repoRoot: string): ValidationContext {
  const schemaDir = join(repoRoot, "schema");
  const schema = JSON.parse(readFileSync(join(schemaDir, "addon.schema.json"), "utf8")) as Record<string, unknown>;
  const checkedLicenses = JSON.parse(readFileSync(join(schemaDir, "checked-licenses.json"), "utf8")) as string[];
  const reviewRules = JSON.parse(readFileSync(join(schemaDir, "review-rules.json"), "utf8")) as ReviewRules;

  const includedIds = new Set<string>();
  const includedNames = new Set<string>();
  const examplesDir = join(repoRoot, "examples");
  if (existsSync(examplesDir)) {
    for (const name of readdirSync(examplesDir)) {
      const manifestPath = join(examplesDir, name, "addon.json");
      if (!existsSync(manifestPath)) continue;
      const m = JSON.parse(readFileSync(manifestPath, "utf8")) as Manifest;
      if (m.id) includedIds.add(m.id);
      if (m.name && typeof m.name === "object") {
        for (const label of Object.values(m.name)) {
          if (typeof label === "string") includedNames.add(foldNameKey(label));
        }
      }
    }
  }

  return { schema, checkedLicenses, reviewRules, includedIds, includedNames };
}

/**
 * Validates the shape and fields of a `registry/<id>.json` file.
 */
export function validateRegistryEntry(
  raw: unknown,
  fileName: string,
  checkedLicenses: readonly string[],
): { entry?: RegistryEntry; errors: string[] } {
  const errors: string[] = [];
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    return { errors: [`${fileName}: must be a JSON object`] };
  }
  const obj = raw as Record<string, unknown>;
  for (const key of Object.keys(obj)) {
    if (!REGISTRY_KEYS.has(key)) {
      errors.push(`${fileName}: unknown field "${key}"`);
    }
  }
  for (const key of REGISTRY_KEYS) {
    if (typeof obj[key] !== "string") {
      errors.push(`${fileName}: "${key}" must be a string`);
    }
  }
  if (errors.length > 0) return { errors };

  const entry: RegistryEntry = {
    id: obj.id as string,
    version: obj.version as string,
    repository: obj.repository as string,
    folder: obj.folder as string,
    commit: obj.commit as string,
    license: obj.license as string,
  };

  const expectedId = basename(fileName, ".json");
  if (entry.id !== expectedId) {
    errors.push(`${fileName}: "id" ("${entry.id}") must match filename ("${expectedId}")`);
  }
  if (!ID_RE.test(entry.id) || entry.id.length > 100) {
    errors.push(`${fileName}: invalid add-on id "${entry.id}"`);
  }
  if (entry.id === "app.koona" || entry.id.startsWith("app.koona.")) {
    errors.push(`${fileName}: id "${entry.id}" is reserved for Koona`);
  }
  if (!SEMVER_RE.test(entry.version) || entry.version.length > 32) {
    errors.push(`${fileName}: invalid semver version "${entry.version}"`);
  }
  if (!GITHUB_REPO_RE.test(entry.repository) || entry.repository.endsWith(".git")) {
    errors.push(
      `${fileName}: "repository" must be a public https://github.com/<owner>/<repo> URL (without .git)`,
    );
  }
  if (
    entry.folder !== "" &&
    (entry.folder.startsWith("/") ||
      entry.folder.endsWith("/") ||
      entry.folder.includes("\\") ||
      entry.folder.split("/").some((p) => p === "" || p === "." || p === ".."))
  ) {
    errors.push(`${fileName}: invalid "folder" path "${entry.folder}"`);
  }
  if (!COMMIT_RE.test(entry.commit)) {
    errors.push(`${fileName}: "commit" must be a full 40-character lowercase hex SHA`);
  }
  if (!checkedLicenses.includes(entry.license)) {
    errors.push(
      `${fileName}: "license" ("${entry.license}") is not allowed (must be one of: ${checkedLicenses.join(", ")})`,
    );
  }

  return { entry: errors.length === 0 ? entry : undefined, errors };
}

/**
 * Checks a license file's bytes against `schema/review-rules.json` (matching Rust `pack.rs::licence_text_problem`).
 */
export function checkLicenseText(bytes: Uint8Array | undefined, rules: ReviewRules["license_file"]): string | null {
  if (!bytes) return `${rules.name} is missing (${rules.missing_code})`;
  let text: string;
  try {
    text = new TextDecoder("utf-8", { fatal: true }).decode(bytes).trim();
  } catch {
    return `${rules.name} is not valid UTF-8 (${rules.missing_code})`;
  }
  if (!text) return `${rules.name} is blank (${rules.missing_code})`;

  const byteLen = new TextEncoder().encode(text).length;
  if (byteLen <= rules.more_than_bytes) {
    return `${rules.name} is too short (${byteLen} <= ${rules.more_than_bytes} bytes, ${rules.stub_code})`;
  }

  const lower = text.toLowerCase();
  const hasApacheTerms = lower.includes(rules.apache_terms.toLowerCase());
  const placeholders = hasApacheTerms
    ? rules.placeholders
    : [...rules.placeholders, ...rules.apache_placeholders];

  for (const p of placeholders) {
    if (lower.includes(p.toLowerCase())) {
      return `${rules.name} contains unfilled template placeholder "${p}" (${rules.stub_code})`;
    }
  }

  const todoRe = new RegExp(`(?<![A-Za-z0-9_])${rules.todo}(?![A-Za-z0-9_])`);
  if (todoRe.test(text)) {
    return `${rules.name} contains "${rules.todo}" (${rules.stub_code})`;
  }

  return null;
}

/**
 * Checks starter placeholders against `schema/review-rules.json` (matching Rust `pack.rs::placeholders`).
 */
export function checkPlaceholders(manifest: Manifest, rules: ReviewRules): string[] {
  const errors: string[] = [];

  for (const prefix of rules.placeholder_id.prefixes) {
    const bare = prefix.endsWith(".") ? prefix.slice(0, -1) : prefix;
    if (manifest.id.startsWith(prefix) || manifest.id === bare) {
      errors.push(`id "${manifest.id}" uses reserved example prefix (${rules.placeholder_id.code})`);
      break;
    }
  }

  if (manifest.author?.name?.trim().toLowerCase() === rules.placeholder_author.name.toLowerCase()) {
    errors.push(`author.name cannot be "${rules.placeholder_author.name}" (${rules.placeholder_author.code})`);
  }

  const hosts: string[] = [];
  const addHost = (h?: string) => {
    if (!h) return;
    hosts.push(h.startsWith("*.") ? h.slice(2) : h);
  };
  const addUrlHost = (u?: string) => {
    if (!u) return;
    try {
      hosts.push(new URL(u).hostname);
    } catch {
      // Schema validation reports invalid URLs
    }
  };

  for (const h of manifest.permissions?.network?.hosts ?? []) addHost(h);
  for (const h of manifest.permissions?.links?.hosts ?? []) addHost(h);
  for (const p of manifest.provides ?? []) {
    if (p.type === "book_action" && typeof p.host === "string") addHost(p.host);
  }
  if (manifest.permissions?.sign_in) {
    const s = manifest.permissions.sign_in;
    addUrlHost(s.issuer);
    addUrlHost(s.authorize);
    addUrlHost(s.token);
    addUrlHost(s.revoke);
  }
  addUrlHost(manifest.homepage);
  addUrlHost(manifest.source);
  addUrlHost(manifest.support);
  addUrlHost(manifest.author?.url);

  const seen = new Set<string>();
  for (const rawHost of hosts) {
    const host = rawHost.toLowerCase();
    if (seen.has(host)) continue;
    const reserved = rules.placeholder_host.domains.some((d) => host === d || host.endsWith(`.${d}`));
    if (reserved) {
      seen.add(host);
      errors.push(`host "${host}" is a reserved example/local domain (${rules.placeholder_host.code})`);
    }
  }

  return errors;
}

/**
 * Clones a git repository at an exact 40-char commit SHA into a fresh temp directory.
 */
export function cloneAtCommit(repository: string, commit: string): string {
  const dir = mkdtempSync(join(tmpdir(), "books-addons-clone-"));
  try {
    const run = (args: string[]) =>
      Bun.spawnSync(["git", ...args], {
        cwd: dir,
        stdout: "pipe",
        stderr: "pipe",
        env: { ...process.env, GIT_TERMINAL_PROMPT: "0" },
      });

    let res = run(["init", "-q"]);
    if (res.exitCode !== 0) throw new Error(`git init failed: ${res.stderr.toString().trim()}`);

    res = run(["remote", "add", "origin", repository]);
    if (res.exitCode !== 0) throw new Error(`git remote add failed: ${res.stderr.toString().trim()}`);

    // Try shallow fetch of exact commit first; fall back to unshallow fetch if host rejects uploadpack.allowReachableSHA1InWant
    res = run(["fetch", "--depth", "1", "origin", commit]);
    if (res.exitCode !== 0) {
      res = run(["fetch", "origin"]);
      if (res.exitCode !== 0) {
        throw new Error(`git fetch ${repository} failed: ${res.stderr.toString().trim()}`);
      }
    }

    res = run(["checkout", "--detach", commit]);
    if (res.exitCode !== 0) {
      throw new Error(`git checkout ${commit} failed: ${res.stderr.toString().trim()}`);
    }

    const head = run(["rev-parse", "HEAD"]);
    const actual = head.stdout.toString().trim();
    if (actual !== commit) {
      throw new Error(`Checked out commit ${actual} does not match expected ${commit}`);
    }
    return dir;
  } catch (err) {
    rmSync(dir, { recursive: true, force: true });
    throw err;
  }
}

/**
 * Validates an unpacked add-on directory against a registry entry and all checked-list rules.
 */
export function validateAddonFolder(
  addonDir: string,
  entry: RegistryEntry,
  ctx: ValidationContext,
): ValidationResult {
  const errors: string[] = [];

  if (!existsSync(addonDir) || !statSync(addonDir).isDirectory()) {
    return { ok: false, entry, errors: [`Add-on folder "${entry.folder || "."}" does not exist in repository`] };
  }

  const manifestPath = join(addonDir, "addon.json");
  if (!existsSync(manifestPath)) {
    return { ok: false, entry, errors: ["Missing addon.json in add-on folder"] };
  }

  let manifest: Manifest;
  try {
    manifest = JSON.parse(readFileSync(manifestPath, "utf8")) as Manifest;
  } catch (err) {
    return { ok: false, entry, errors: [`Invalid JSON in addon.json: ${(err as Error).message}`] };
  }

  // 1. JSON Schema validation
  for (const p of validateJsonSchema(ctx.schema, manifest)) {
    errors.push(`addon.json ${p.path}: ${p.message}`);
  }

  // 2. Registry <-> manifest consistency
  if (manifest.id !== entry.id) {
    errors.push(`addon.json id ("${manifest.id}") does not match registry id ("${entry.id}")`);
  }
  if (manifest.version !== entry.version) {
    errors.push(`addon.json version ("${manifest.version}") does not match registry version ("${entry.version}")`);
  }
  if (manifest.license !== entry.license) {
    errors.push(`addon.json license ("${manifest.license}") does not match registry license ("${entry.license}")`);
  }

  // 3. Reserved IDs and Koona names
  if (manifest.id === "app.koona" || manifest.id.startsWith("app.koona.") || ctx.includedIds.has(manifest.id)) {
    errors.push(`id "${manifest.id}" is reserved (reserved_id)`);
  }
  if (manifest.author?.name && saysKoona(manifest.author.name)) {
    errors.push(`author.name "${manifest.author.name}" cannot contain "Koona" (reserved_name)`);
  }
  if (manifest.name && typeof manifest.name === "object") {
    for (const [lang, label] of Object.entries(manifest.name)) {
      if (typeof label !== "string") continue;
      if (saysKoona(label)) {
        errors.push(`name.${lang} "${label}" cannot contain "Koona" (reserved_name)`);
      }
      if (ctx.includedNames.has(foldNameKey(label))) {
        errors.push(`name.${lang} "${label}" conflicts with an included add-on name (name_taken)`);
      }
    }
  }

  // 4. Checked license allowlist
  if (!ctx.checkedLicenses.includes(manifest.license)) {
    errors.push(`license "${manifest.license}" is not allowed (licence_not_allowed)`);
  }

  // 5. Placeholders (review-rules.json)
  errors.push(...checkPlaceholders(manifest, ctx.reviewRules));

  // 6. Test pack (enforces allowed extensions, file limits, UTF-8, no symlinks, manifest files)
  let packed: PackedAddon | undefined;
  try {
    packed = packAddonDir(addonDir);
  } catch (err) {
    errors.push(`Package check failed: ${(err as Error).message}`);
  }

  // 7. LICENSE.md check (from packed files if available, else directly from folder)
  const licenseName = ctx.reviewRules.license_file.name;
  let licenseBytes: Uint8Array | undefined;
  if (packed) {
    licenseBytes = packed.files.get(licenseName);
  } else {
    const licensePath = join(addonDir, licenseName);
    if (existsSync(licensePath) && statSync(licensePath).isFile()) {
      licenseBytes = new Uint8Array(readFileSync(licensePath));
    }
  }
  const licenseProblem = checkLicenseText(licenseBytes, ctx.reviewRules.license_file);
  if (licenseProblem) {
    errors.push(licenseProblem);
  }

  return { ok: errors.length === 0, entry, errors, packed };
}

/**
 * Full end-to-end validation of a `registry/<id>.json` file (including cloning at the exact commit).
 */
export function validateRegistryFile(
  filePath: string,
  ctx: ValidationContext,
  opts: { clone?: (repo: string, commit: string) => string } = {},
): ValidationResult {
  const fileName = basename(filePath);
  let raw: unknown;
  try {
    raw = JSON.parse(readFileSync(filePath, "utf8"));
  } catch (err) {
    return {
      ok: false,
      entry: { id: basename(fileName, ".json"), version: "", repository: "", folder: "", commit: "", license: "" },
      errors: [`${fileName}: invalid JSON (${(err as Error).message})`],
    };
  }

  const parsed = validateRegistryEntry(raw, fileName, ctx.checkedLicenses);
  if (!parsed.entry || parsed.errors.length > 0) {
    return {
      ok: false,
      entry: parsed.entry ?? {
        id: basename(fileName, ".json"),
        version: "",
        repository: "",
        folder: "",
        commit: "",
        license: "",
      },
      errors: parsed.errors,
    };
  }

  const entry = parsed.entry;
  const cloneFn = opts.clone ?? cloneAtCommit;
  let clonedDir: string;
  try {
    clonedDir = cloneFn(entry.repository, entry.commit);
  } catch (err) {
    return {
      ok: false,
      entry,
      errors: [`Failed to clone ${entry.repository} @ ${entry.commit}: ${(err as Error).message}`],
    };
  }

  try {
    const addonDir = entry.folder ? resolve(clonedDir, entry.folder) : clonedDir;
    const rootResolved = resolve(clonedDir);
    if (addonDir !== rootResolved && !addonDir.startsWith(`${rootResolved}/`)) {
      return { ok: false, entry, errors: [`Folder "${entry.folder}" escapes repository root`] };
    }
    return validateAddonFolder(addonDir, entry, ctx);
  } finally {
    if (!opts.clone) {
      rmSync(clonedDir, { recursive: true, force: true });
    }
  }
}
