import { describe, expect, test } from "bun:test";
import { generateKeyPairSync } from "node:crypto";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import {
  INDEX_CACHE_CONTROL,
  PACKAGE_CACHE_CONTROL,
  runPublish,
  verifyIndexSignature,
  type FetchLike,
  type R2Client,
} from "./publish.ts";

const repoRoot = resolve(import.meta.dir, "../..");

function makeTestKeyPair() {
  const { privateKey, publicKey } = generateKeyPairSync("ed25519");
  const privatePem = privateKey.export({ format: "pem", type: "pkcs8" }).toString();
  const spki = publicKey.export({ format: "der", type: "spki" }) as Buffer;
  // Last 32 bytes of Ed25519 SPKI DER are the raw public key
  const rawPubB64 = spki.subarray(spki.length - 32).toString("base64");
  return { privatePem, rawPubB64 };
}

function createMockR2() {
  const store = new Map<string, { data: Uint8Array; type?: string; cacheControl?: string }>();
  const writes: Array<{ key: string; cacheControl?: string }> = [];

  const s3: R2Client = {
    async list({ prefix = "" }) {
      const contents = [...store.entries()]
        .filter(([k]) => k.startsWith(prefix))
        .map(([key, v]) => ({ key, size: v.data.length }));
      return { contents, isTruncated: false };
    },
    async write(key, data, opts) {
      const bytes = typeof data === "string" ? new TextEncoder().encode(data) : new Uint8Array(data);
      store.set(key, { data: bytes, type: opts?.type, cacheControl: opts?.cacheControl });
      writes.push({ key, cacheControl: opts?.cacheControl });
      return bytes.length;
    },
  };

  const seenHeaders: Array<{ url: string; ua: string | null; ae: string | null; decompress?: boolean }> = [];
  const fetchFn: FetchLike = async (input, init) => {
    const url = String(input);
    const headers = new Headers(init?.headers);
    seenHeaders.push({
      url,
      ua: headers.get("User-Agent"),
      ae: headers.get("Accept-Encoding"),
      decompress: init?.decompress,
    });
    const rel = url.replace("https://addons.test/books/v1/", "books/v1/");
    const item = store.get(rel);
    if (!item) return new Response("Not Found", { status: 404 });
    return new Response(item.data, { status: 200 });
  };

  return { store, writes, seenHeaders, s3, fetchFn };
}

describe("publish", () => {
  test("fresh bucket publishes all 11 examples, skips unchanged on second run, refuses mutation", async () => {
    const tmp = mkdtempSync(join(tmpdir(), "books-addons-pub-test-"));
    try {
      const { privatePem, rawPubB64 } = makeTestKeyPair();
      const keysPath = join(tmp, "addons-keys.json");
      writeFileSync(keysPath, JSON.stringify({ keys: [rawPubB64] }));

      const mock = createMockR2();
      const logs: string[] = [];

      // 1. First publish to fresh bucket
      const res1 = await runPublish({
        repoRoot,
        baseUrl: "https://addons.test/books/v1/",
        signingKeyPem: privatePem,
        keysFilePath: keysPath,
        s3: mock.s3,
        fetchFn: mock.fetchFn,
        now: new Date("2026-11-21T14:00:00Z"),
        log: (m) => logs.push(m),
      });

      expect(res1.changed).toBe(true);
      expect(res1.serial).toBe(1);
      expect(res1.uploadedPackages.length).toBe(11);
      expect(res1.skippedPackages.length).toBe(0);

      // Verify Cache-Control headers
      const pkgWrites = mock.writes.filter((w) => w.key.endsWith(".kbooksaddon"));
      expect(pkgWrites.length).toBe(11);
      for (const w of pkgWrites) {
        expect(w.cacheControl).toBe(PACKAGE_CACHE_CONTROL);
      }
      const metaWrites = mock.writes.filter((w) => !w.key.endsWith(".kbooksaddon"));
      expect(metaWrites.map((w) => w.key)).toEqual([
        "books/v1/index.json.sig",
        "books/v1/index.json",
        "books/v1/catalog.json",
      ]);
      for (const w of metaWrites) {
        expect(w.cacheControl).toBe(INDEX_CACHE_CONTROL);
      }

      // Verify HTTPS verification used KoonaBooks headers + decompress: false
      expect(mock.seenHeaders.every((h) => h.ua === "KoonaBooks" && h.ae === "identity" && h.decompress === false)).toBe(
        true,
      );

      // Verify signature
      expect(verifyIndexSignature(new TextEncoder().encode(res1.indexJson), res1.signature, [rawPubB64])).toBe(true);

      // 2. Second publish with no changes -> skips everything, 0 writes!
      const writesBefore = mock.writes.length;
      const logs2: string[] = [];
      const res2 = await runPublish({
        repoRoot,
        baseUrl: "https://addons.test/books/v1/",
        signingKeyPem: privatePem,
        keysFilePath: keysPath,
        s3: mock.s3,
        fetchFn: mock.fetchFn,
        now: new Date("2026-11-21T15:00:00Z"),
        log: (m) => logs2.push(m),
      });

      expect(res2.changed).toBe(false);
      expect(res2.uploadedPackages).toEqual([]);
      expect(res2.skippedPackages.length).toBe(11);
      expect(mock.writes.length).toBe(writesBefore);
      expect(logs2.some((l) => l.includes("Already up to date"))).toBe(true);

      // 3. Immutability check: tamper with live index SHA-256 for one version -> must throw!
      const liveIdx = JSON.parse(new TextDecoder().decode(mock.store.get("books/v1/index.json")!.data));
      liveIdx.addons[0].versions[0].sha256 = "0".repeat(64);
      mock.store.set("books/v1/index.json", {
        data: new TextEncoder().encode(JSON.stringify(liveIdx)),
      });

      await expect(
        runPublish({
          repoRoot,
          baseUrl: "https://addons.test/books/v1/",
          signingKeyPem: privatePem,
          keysFilePath: keysPath,
          s3: mock.s3,
          fetchFn: mock.fetchFn,
          log: () => {},
        }),
      ).rejects.toThrow(/Immutability violation/);
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  test("aborts before uploading anything when signing key does not match addons-keys.json", async () => {
    const tmp = mkdtempSync(join(tmpdir(), "books-addons-badkey-"));
    try {
      const k1 = makeTestKeyPair();
      const k2 = makeTestKeyPair();
      const keysPath = join(tmp, "addons-keys.json");
      writeFileSync(keysPath, JSON.stringify({ keys: [k2.rawPubB64] }));

      const mock = createMockR2();
      await expect(
        runPublish({
          repoRoot,
          baseUrl: "https://addons.test/books/v1/",
          signingKeyPem: k1.privatePem,
          keysFilePath: keysPath,
          s3: mock.s3,
          fetchFn: mock.fetchFn,
          log: () => {},
        }),
      ).rejects.toThrow(/Signature self-verification FAILED/);
      expect(mock.writes.length).toBe(0);
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  test("supports --dry-run and --out local folder mode", async () => {
    const tmp = mkdtempSync(join(tmpdir(), "books-addons-out-"));
    try {
      const { privatePem, rawPubB64 } = makeTestKeyPair();
      const keysPath = join(tmp, "addons-keys.json");
      writeFileSync(keysPath, JSON.stringify({ keys: [rawPubB64] }));

      const outDir = join(tmp, "dist");
      const res = await runPublish({
        repoRoot,
        outDir,
        signingKeyPem: privatePem,
        keysFilePath: keysPath,
        log: () => {},
      });

      expect(res.uploadedPackages.length).toBe(11);
      expect(existsSync(join(outDir, "index.json"))).toBe(true);
      expect(existsSync(join(outDir, "index.json.sig"))).toBe(true);
      expect(existsSync(join(outDir, "catalog.json"))).toBe(true);

      const cat = JSON.parse(readFileSync(join(outDir, "catalog.json"), "utf8"));
      expect(cat.format).toBe(1);
      expect(cat.addons.length).toBe(11);

      // Dry-run touches nothing
      const mock = createMockR2();
      const dryRes = await runPublish({
        repoRoot,
        baseUrl: "https://addons.test/books/v1/",
        dryRun: true,
        signingKeyPem: privatePem,
        keysFilePath: keysPath,
        s3: mock.s3,
        fetchFn: mock.fetchFn,
        log: () => {},
      });
      expect(dryRes.changed).toBe(true);
      expect(mock.writes.length).toBe(0);
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  test("publishes third-party registry entry with listing & codes and skips re-cloning when unchanged", async () => {
    const tmp = mkdtempSync(join(tmpdir(), "books-addons-reg-pub-"));
    try {
      // Minimal fake repo with schema + registry + 1 third-party add-on
      const fakeRepo = join(tmp, "repo");
      mkdirSync(join(fakeRepo, "registry"), { recursive: true });
      mkdirSync(join(fakeRepo, "schema"), { recursive: true });
      mkdirSync(join(fakeRepo, "examples"), { recursive: true });
      for (const f of ["addon.schema.json", "checked-licenses.json", "review-rules.json"]) {
        writeFileSync(join(fakeRepo, "schema", f), readFileSync(join(repoRoot, "schema", f)));
      }
      writeFileSync(join(fakeRepo, "withdrawn.json"), "[]\n");

      const { privatePem, rawPubB64 } = makeTestKeyPair();
      const keysPath = join(fakeRepo, "schema", "addons-keys.json");
      writeFileSync(keysPath, JSON.stringify({ keys: [rawPubB64] }));

      // Third-party add-on directory (returned by mock cloneFn)
      const addonSrc = join(tmp, "author-repo");
      mkdirSync(join(addonSrc, "locales"), { recursive: true });
      writeFileSync(
        join(addonSrc, "addon.json"),
        JSON.stringify({
          schema: 1,
          id: "dev.janedoe.notes",
          version: "1.0.0",
          api: 1,
          min_app: "1.0.0",
          name: { en: "Shelf Notes" },
          summary: { en: "Copy book citations as Markdown" },
          category: "tools",
          author: { name: "Jane Doe", url: "https://janedoe.dev" },
          license: "MIT",
          permissions: { book_details: true },
          privacy: { sends: [], collects: [] },
          provides: [{ type: "book_action", id: "copy_note", entry: "notes.lua", gives: "text" }],
        }),
      );
      writeFileSync(join(addonSrc, "notes.lua"), "return {}\n");
      writeFileSync(join(addonSrc, "locales", "en.json"), JSON.stringify({ "action.copy_note.label": "Copy note" }));
      writeFileSync(
        join(addonSrc, "LICENSE.md"),
        `MIT License\n\nCopyright (c) 2026 Jane Doe\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files.\n`,
      );

      writeFileSync(
        join(fakeRepo, "registry", "dev.janedoe.notes.json"),
        JSON.stringify({
          id: "dev.janedoe.notes",
          version: "1.0.0",
          repository: "https://github.com/janedoe/notes",
          folder: "",
          commit: "0123456789abcdef0123456789abcdef01234567",
          license: "MIT",
        }),
      );

      let cloneCalls = 0;
      const cloneFn = () => {
        cloneCalls++;
        return addonSrc;
      };

      const mock = createMockR2();
      const res1 = await runPublish({
        repoRoot: fakeRepo,
        baseUrl: "https://addons.test/books/v1/",
        signingKeyPem: privatePem,
        keysFilePath: keysPath,
        s3: mock.s3,
        fetchFn: mock.fetchFn,
        cloneFn,
        log: () => {},
      });

      expect(cloneCalls).toBe(1);
      expect(res1.uploadedPackages).toEqual(["dev.janedoe.notes-1.0.0.kbooksaddon"]);
      const idx = JSON.parse(res1.indexJson);
      expect(idx.addons[0].listing.name.en).toBe("Shelf Notes");
      expect(idx.addons[0].versions[0].may).toContain("book_details");
      expect(idx.addons[0].versions[0].author).toBe("Jane Doe");
      const cat = JSON.parse(res1.catalogJson);
      expect(cat.addons[0].group).toBe("checked");

      // Second run: unchanged -> MUST NOT re-clone!
      const res2 = await runPublish({
        repoRoot: fakeRepo,
        baseUrl: "https://addons.test/books/v1/",
        signingKeyPem: privatePem,
        keysFilePath: keysPath,
        s3: mock.s3,
        fetchFn: mock.fetchFn,
        cloneFn,
        log: () => {},
      });
      expect(res2.changed).toBe(false);
      expect(cloneCalls).toBe(1);
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });
});
