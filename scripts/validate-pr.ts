import { existsSync, readdirSync } from "node:fs";
import { join, resolve } from "node:path";
import { packAddonDir } from "./lib/pack.ts";
import { loadValidationContext, validateRegistryFile } from "./lib/validate.ts";

const repoRoot = resolve(import.meta.dir, "..");
const ctx = loadValidationContext(repoRoot);

const args = process.argv.slice(2);
let filesToCheck: string[] = [];

if (args.length > 0) {
  filesToCheck = args.map((p) => resolve(process.cwd(), p));
} else {
  const registryDir = join(repoRoot, "registry");
  if (existsSync(registryDir)) {
    filesToCheck = readdirSync(registryDir)
      .filter((f) => f.endsWith(".json"))
      .sort()
      .map((f) => join(registryDir, f));
  }
}

let failed = false;

// Also verify all included examples pack cleanly
const examplesDir = join(repoRoot, "examples");
if (existsSync(examplesDir)) {
  const examples = readdirSync(examplesDir).sort();
  let packedCount = 0;
  for (const name of examples) {
    const dir = join(examplesDir, name);
    if (!existsSync(join(dir, "addon.json"))) continue;
    try {
      const p = packAddonDir(dir);
      packedCount++;
      console.log(`OK example: ${p.id}@${p.version} (${p.size} bytes)`);
    } catch (err) {
      failed = true;
      console.error(`FAIL example ${name}: ${(err as Error).message}`);
    }
  }
  console.log(`Checked ${packedCount} included example(s).`);
}

if (filesToCheck.length === 0) {
  console.log("No registry/*.json entries to validate.");
} else {
  for (const filePath of filesToCheck) {
    const result = validateRegistryFile(filePath, ctx);
    if (result.ok) {
      console.log(
        `OK registry: ${result.entry.id}@${result.entry.version} (${result.packed?.size ?? 0} bytes, sha256=${result.packed?.sha256.slice(0, 12)}…)`,
      );
    } else {
      failed = true;
      console.error(`FAIL registry ${filePath}:`);
      for (const err of result.errors) {
        console.error(`  - ${err}`);
      }
    }
  }
}

if (failed) {
  process.exit(1);
}
