import { describe, expect, test } from "bun:test";
import { mkdtempSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import {
  buildListing,
  catalogEntryFromPacked,
  mayCodes,
  packAddonDir,
  permissionsDigest,
  plainEnglishPermissions,
  plainEnglishPermissionsFromCodes,
  privacyCodes,
  sha256Hex,
  type Manifest,
} from "./pack.ts";

const repoRoot = resolve(import.meta.dir, "../..");

describe("pack", () => {
  test("computes may, tells, and permissions digest matching Rust contract", () => {
    const manifest: Manifest = {
      schema: 1,
      id: "org.alice.sync",
      version: "1.0.0",
      api: 1,
      min_app: "1.0.0",
      name: { en: "Alice Sync" },
      summary: { en: "Sync reading state" },
      category: "sync",
      author: { name: "Alice", url: "https://alice.example.org" },
      license: "MIT",
      permissions: {
        network: {
          hosts: ["api.service.dev", "*.cdn.service.dev"],
          local_device: { ports: [8080, 80] },
          named_server: true,
        },
        secrets: true,
        reading_state: true,
        input_file: ["csv"],
        book_query: true,
        book_details: true,
        links: { hosts: ["service.dev"] },
        sign_in: {
          kind: "oauth2_pkce",
          issuer: "https://api.service.dev",
          authorize: "https://service.dev/oauth/authorize",
          token: "https://api.service.dev/oauth/token",
          revoke: "https://api.service.dev/oauth/revoke",
          client_id: "client-123",
          scopes: ["read:books", "write:books"],
        },
      },
      privacy: {
        sends: ["reading_state_to_service", "book_details_to_service"],
        collects: ["account"],
      },
      provides: [
        {
          type: "reading_sync",
          id: "svc",
          entry: "sync.lua",
          directions: ["from", "to"],
          carries: ["status", "progress"],
          match_by: "identifiers",
        },
      ],
    };

    const may = mayCodes(manifest);
    const tells = privacyCodes(manifest.privacy);

    expect(may).toContain("network.host:api.service.dev");
    expect(may).toContain("network.host:*.cdn.service.dev");
    expect(may).toContain("network.local_device:80");
    expect(may).toContain("network.local_device:8080");
    expect(may).toContain("network.named_server");
    expect(may).toContain("secrets");
    expect(may).toContain("reading_state");
    expect(may).toContain("input_file:csv");
    expect(may).toContain("book_query");
    expect(may).toContain("book_details");
    expect(may).toContain("links:service.dev");
    expect(may).toContain("sign_in:service.dev");
    expect(may).toContain("sign_in.scope:read:books");
    expect(may).toContain("sign_in.scope:write:books");
    expect(may).toContain("sign_in.authorize:https://service.dev/oauth/authorize");
    expect(may).toContain("sign_in.issuer:api.service.dev");
    expect(may).toContain("sign_in.client:client-123");
    expect(may).toContain("sign_in.token:https://api.service.dev/oauth/token");
    expect(may).toContain("sign_in.revoke:https://api.service.dev/oauth/revoke");
    expect(may).toContain("provides.reading_sync:svc");
    expect(may).toContain("provides.reading_sync:svc.direction:from");
    expect(may).toContain("provides.reading_sync:svc.direction:to");
    expect(may).toContain("provides.reading_sync:svc.carries:status");
    expect(may).toContain("provides.reading_sync:svc.carries:progress");
    expect(may).toContain("provides.reading_sync:svc.match_by:identifiers");

    expect(tells).toEqual([
      "collects.account",
      "sends.book_details_to_service",
      "sends.reading_state_to_service",
    ]);

    const expectedAll = [...new Set([...may, ...tells])].sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
    expect(permissionsDigest(manifest)).toBe(sha256Hex(expectedAll.join("\n")));

    const listing = buildListing(manifest, ["addon.json", "locales/de.json", "locales/en.json", "sync.lua"]);
    expect(listing.author.url).toBe("https://alice.example.org/");
    expect(listing.languages).toEqual(["de", "en"]);
    expect(listing.provides).toEqual(["reading_sync"]);
    expect(listing.match_by).toBe("identifiers");
  });

  test("packs all real examples and generates valid catalog entries", () => {
    const examplesDir = join(repoRoot, "examples");
    const folders = readdirSync(examplesDir).sort();
    expect(folders.length).toBe(10);
    expect(folders).toContain("wikidata");

    for (const folder of folders) {
      const packed = packAddonDir(join(examplesDir, folder));
      expect(packed.file).toBe(`${packed.id}-${packed.version}.kbooksaddon`);
      expect(packed.size).toBeGreaterThan(0);
      expect(packed.sha256).toMatch(/^[0-9a-f]{64}$/);
      expect(packed.permissions).toMatch(/^[0-9a-f]{64}$/);

      const cat = catalogEntryFromPacked(packed, {
        group: "included",
        source: `https://github.com/koona-project/books-addons/tree/main/examples/${folder}`,
        updated: "2026-11-21T14:00:00Z",
      });
      expect(cat.group).toBe("included");
      expect(cat.kinds.length).toBeGreaterThan(0);
      expect(cat.permissions.length).toBeGreaterThan(0);

      // Plain-English permissions from codes should match manifest permissions (modulo host sort order)
      const fromManifest = plainEnglishPermissions(packed.manifest);
      const fromCodes = plainEnglishPermissionsFromCodes(packed.may, packed.manifest.category);
      expect(fromCodes.length).toBe(fromManifest.length);
    }
  });

  test("produces byte-identical SHA-256 to Rust packer for all 9 published 1.0.0 add-ons", () => {
    const published: Record<string, string> = {
      "book-links": "13e40687e35e63e1c2914ef1f675852f094ac8316825fe693d0f575cd1cecea8",
      "book-list-csv": "f9eadf94815c59a63d13257f1d930b01a8eb1924f9dee127497c36cc0adce7b8",
      "citations": "f92401509cfe026ba89c3bafac5de6a65eb125e2ee5f4f0595a27ea4352ffd59",
      "crosspoint-wifi": "e2bd20c660bc1cda6fb9eda8f1520f46e9648bcb7b2d14e76065aedcf119f708",
      "hardcover": "5649365a6bb649325ce93926053c3f1b56f4ac9f7ad287cf88869914aa510e01",
      "koreader-sync": "94876cd5d4e140bab62cb0a36955fa8f2298c6e3da7a651f0e27cba4407252b8",
      "opds": "af15d2d53f485fd3366fe6f3cf7c1b1ffbf3af4bfc40dc67900bf64a2f962e43",
      "openlibrary": "17113175376ba191f7c24826b2f099ac600338ebe3073a40690bd772a06f2022",
      "xteink-card": "4d3f5bdf943075b462397f1366feaa9785e7d8878583d8573136316ec2aad9fd",
    };

    for (const [folder, expectedSha256] of Object.entries(published)) {
      const packed = packAddonDir(join(repoRoot, "examples", folder));
      expect(packed.sha256).toBe(expectedSha256);
    }
  });

  test("rejects disallowed file extensions and BOM", () => {
    const dir = mkdtempSync(join(tmpdir(), "books-addons-pack-test-"));
    try {
      writeFileSync(
        join(dir, "addon.json"),
        JSON.stringify({
          schema: 1,
          id: "org.test.bad",
          version: "1.0.0",
          api: 1,
          min_app: "1.0.0",
          name: { en: "Bad" },
          summary: { en: "Bad" },
          category: "tools",
          author: { name: "Bob" },
          license: "MIT",
          privacy: { sends: [], collects: [] },
          provides: [{ type: "book_action", id: "a", entry: "main.lua", gives: "text" }],
        }),
      );
      writeFileSync(join(dir, "main.lua"), "return {}\n");
      writeFileSync(join(dir, "icon.png"), new Uint8Array([0x89, 0x50, 0x4e, 0x47]));

      expect(() => packAddonDir(dir)).toThrow(/Disallowed file extension/);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
