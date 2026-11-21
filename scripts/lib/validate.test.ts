import { describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import {
  checkAgainstLiveIndex,
  checkLicenseText,
  checkPlaceholders,
  loadValidationContext,
  validateAddonFolder,
  validateRegistryEntry,
  validateRegistryFile,
  type RegistryEntry,
} from "./validate.ts";

const repoRoot = resolve(import.meta.dir, "../..");
const ctx = loadValidationContext(repoRoot);

const VALID_MIT = `MIT License

Copyright (c) 2026 Jane Doe

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software.
`;

describe("validate", () => {
  test("validates registry entry shape and filename match", () => {
    const valid: RegistryEntry = {
      id: "dev.janedoe.sample",
      version: "1.0.0",
      repository: "https://github.com/janedoe/sample-addon",
      folder: "",
      commit: "0123456789abcdef0123456789abcdef01234567",
      license: "MIT",
    };

    expect(validateRegistryEntry(valid, "dev.janedoe.sample.json", ctx.checkedLicenses).errors).toEqual([]);

    // Mismatched filename
    expect(
      validateRegistryEntry(valid, "dev.janedoe.other.json", ctx.checkedLicenses).errors.join(" "),
    ).toContain("must match filename");

    // Reserved app.koona.* id
    expect(
      validateRegistryEntry(
        { ...valid, id: "app.koona.fake" },
        "app.koona.fake.json",
        ctx.checkedLicenses,
      ).errors.join(" "),
    ).toContain("reserved");

    // Bad commit length
    expect(
      validateRegistryEntry(
        { ...valid, commit: "1234567" },
        "dev.janedoe.sample.json",
        ctx.checkedLicenses,
      ).errors.join(" "),
    ).toContain("40-character");

    // Disallowed license
    expect(
      validateRegistryEntry(
        { ...valid, license: "GPL-3.0" },
        "dev.janedoe.sample.json",
        ctx.checkedLicenses,
      ).errors.join(" "),
    ).toContain("not allowed");
  });

  test("checks LICENSE.md rules including Apache appendix exception", () => {
    const rules = ctx.reviewRules.license_file;
    const enc = (s: string) => new TextEncoder().encode(s);

    expect(checkLicenseText(enc(VALID_MIT), rules)).toBeNull();
    expect(checkLicenseText(undefined, rules)).toContain("licence_text_missing");
    expect(checkLicenseText(enc("MIT 2026 Jane"), rules)).toContain("licence_text_stub");
    expect(checkLicenseText(enc(VALID_MIT.replace("Jane Doe", "[fullname]")), rules)).toContain(
      "licence_text_stub",
    );
    expect(checkLicenseText(enc(`${VALID_MIT}\nTODO finish\n`), rules)).toContain("licence_text_stub");
    // Whole-word TODO only: "TODOS" should not trip it
    expect(checkLicenseText(enc(`${VALID_MIT}\nTODOS are done.\n`), rules)).toBeNull();

    // Short Apache notice with [yyyy] -> rejected
    const shortApache = `Copyright [yyyy] [name of copyright owner]\nLicensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.`;
    expect(checkLicenseText(enc(shortApache), rules)).toContain("licence_text_stub");

    // Full Apache text with TERMS AND CONDITIONS heading -> allowed
    const fullApache = `Apache License\nTERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION\n${shortApache}`;
    expect(checkLicenseText(enc(fullApache), rules)).toBeNull();
  });

  test("rejects starter placeholders and validates a complete third-party folder", () => {
    const dir = mkdtempSync(join(tmpdir(), "books-addons-val-test-"));
    try {
      const entry: RegistryEntry = {
        id: "dev.janedoe.notes",
        version: "1.0.0",
        repository: "https://github.com/janedoe/notes",
        folder: "",
        commit: "0123456789abcdef0123456789abcdef01234567",
        license: "MIT",
      };
      const manifest = {
        schema: 1,
        id: "dev.janedoe.notes",
        version: "1.0.0",
        api: 1,
        min_app: "1.0.0",
        name: { en: "Shelf Notes" },
        summary: { en: "Copy book citations as plain Markdown notes" },
        category: "tools",
        author: { name: "Jane Doe", url: "https://janedoe.dev" },
        license: "MIT",
        permissions: { book_details: true },
        privacy: { sends: [], collects: [] },
        provides: [{ type: "book_action", id: "copy_note", entry: "notes.lua", gives: "text" }],
      };

      writeFileSync(join(dir, "addon.json"), JSON.stringify(manifest, null, 2));
      writeFileSync(join(dir, "notes.lua"), "return {}\n");
      mkdirSync(join(dir, "locales"));
      writeFileSync(join(dir, "locales", "en.json"), JSON.stringify({ "action.copy_note.label": "Copy note" }));
      writeFileSync(join(dir, "LICENSE.md"), VALID_MIT);

      const okRes = validateAddonFolder(dir, entry, ctx);
      expect(okRes.errors).toEqual([]);
      expect(okRes.ok).toBe(true);
      expect(okRes.packed?.id).toBe("dev.janedoe.notes");

      // Placeholder checks
      const badPlaceholders = checkPlaceholders(
        {
          ...(manifest as any),
          id: "org.example.notes",
          author: { name: "Your Name", url: "https://example.org" },
        },
        ctx.reviewRules,
      );
      expect(badPlaceholders.length).toBe(3);

      // Koona name rejected
      writeFileSync(
        join(dir, "addon.json"),
        JSON.stringify({ ...manifest, name: { en: "Koona Notes" } }, null, 2),
      );
      const koonaRes = validateAddonFolder(dir, entry, ctx);
      expect(koonaRes.ok).toBe(false);
      expect(koonaRes.errors.join(" ")).toContain("reserved_name");

      // Live index immutability check
      const liveIndex = {
        addons: [{ id: "dev.janedoe.notes", versions: [{ version: "1.0.0", sha256: "a".repeat(64) }] }],
      };
      expect(checkAgainstLiveIndex(entry, okRes.packed!, liveIndex)).toContain("Immutability violation");
      expect(
        checkAgainstLiveIndex(entry, okRes.packed!, {
          addons: [{ id: "dev.janedoe.notes", versions: [{ version: "1.0.0", sha256: okRes.packed!.sha256 }] }],
        }),
      ).toBeNull();
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("rejects symlinked folder escaping cloned repository root", () => {
    const tmp = mkdtempSync(join(tmpdir(), "books-addons-symlink-test-"));
    try {
      const outside = join(tmp, "outside");
      const cloned = join(tmp, "cloned");
      mkdirSync(outside);
      mkdirSync(cloned);
      symlinkSync(outside, join(cloned, "escape"));

      const regFile = join(tmp, "dev.janedoe.escape.json");
      writeFileSync(
        regFile,
        JSON.stringify({
          id: "dev.janedoe.escape",
          version: "1.0.0",
          repository: "https://github.com/janedoe/escape",
          folder: "escape",
          commit: "0123456789abcdef0123456789abcdef01234567",
          license: "MIT",
        }),
      );

      const res = validateRegistryFile(regFile, ctx, { clone: () => cloned });
      expect(res.ok).toBe(false);
      expect(res.errors.join(" ")).toContain("escapes repository root");
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });
});
