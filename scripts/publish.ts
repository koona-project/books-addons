import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { checkLiveBucket, runPublish, type R2Client } from "./lib/publish.ts";

function parseArgs(argv: string[]) {
  let dryRun = false;
  let check = false;
  let force = false;
  let outDir: string | undefined;
  let liveUrl: string | undefined;
  let verifyUrl: string | undefined;
  let baseUrl: string | undefined;
  let signingKeyPath: string | undefined;
  let keysFilePath: string | undefined;

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--dry-run") dryRun = true;
    else if (arg === "--check") check = true;
    else if (arg === "--force") force = true;
    else if (arg === "--out") outDir = resolve(process.cwd(), argv[++i]);
    else if (arg === "--live-url") liveUrl = argv[++i];
    else if (arg === "--verify-url") verifyUrl = argv[++i];
    else if (arg === "--base-url") baseUrl = argv[++i];
    else if (arg === "--signing-key") signingKeyPath = resolve(process.cwd(), argv[++i]);
    else if (arg === "--keys") keysFilePath = resolve(process.cwd(), argv[++i]);
    else {
      console.error(`Unknown argument: ${arg}`);
      process.exit(2);
    }
  }
  return { dryRun, check, force, outDir, liveUrl, verifyUrl, baseUrl, signingKeyPath, keysFilePath };
}

const repoRoot = resolve(import.meta.dir, "..");
const args = parseArgs(process.argv.slice(2));

if (args.check) {
  await checkLiveBucket({
    repoRoot,
    baseUrl: args.verifyUrl ?? args.liveUrl ?? args.baseUrl,
    keysFilePath: args.keysFilePath,
  });
  process.exit(0);
}

const signingKeyPem = args.signingKeyPath
  ? readFileSync(args.signingKeyPath, "utf8")
  : process.env.ADDONS_SIGNING_KEY;

let s3: R2Client | undefined;
if (!args.dryRun && !args.outDir) {
  const accessKeyId = process.env.R2_ACCESS_KEY_ID?.trim();
  const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY?.trim();
  const endpoint = process.env.R2_ENDPOINT_URL?.trim();
  const bucket = process.env.R2_BUCKET?.trim();
  if (!accessKeyId || !secretAccessKey || !endpoint || !bucket) {
    console.error(
      "Missing R2 credentials: set R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_ENDPOINT_URL, and R2_BUCKET",
    );
    process.exit(1);
  }
  s3 = new Bun.S3Client({
    accessKeyId,
    secretAccessKey,
    endpoint,
    bucket,
    region: "auto",
  }) as unknown as R2Client;
}

await runPublish({
  repoRoot,
  liveUrl: args.liveUrl,
  verifyUrl: args.verifyUrl,
  baseUrl: args.baseUrl,
  dryRun: args.dryRun,
  force: args.force,
  outDir: args.outDir,
  signingKeyPem,
  keysFilePath: args.keysFilePath,
  s3,
});
