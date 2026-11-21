# Third-Party Add-on Registry

Each third-party add-on on Koona's checked list has one JSON file here, named `<id>.json`, where `<id>` matches the `id` in its `addon.json`.

Keeping one file per add-on ensures pull requests from different authors do not conflict.

## File format

Create `registry/<your-addon-id>.json` with these exact fields (no extra keys):

```json
{
  "id": "org.example.my-addon",
  "version": "1.0.0",
  "repository": "https://github.com/you/your-addon",
  "folder": "",
  "commit": "0123456789abcdef0123456789abcdef01234567",
  "license": "MIT"
}
```

| Field | Requirement |
| --- | --- |
| `id` | Reverse-domain add-on id from `addon.json`. Must match the filename (`<id>.json`). Cannot be `app.koona.*` or `org.example.*` / `com.example.*` / `net.example.*`. |
| `version` | Semver version from `addon.json` (no build metadata). To publish a new version, raise `version` and update `commit`. |
| `repository` | Public GitHub repository URL (`https://github.com/<owner>/<repo>`, without `.git`). |
| `folder` | Relative path to the folder holding `addon.json` inside the repository (`""` if `addon.json` is at the repository root). |
| `commit` | Full 40-character lowercase hex commit SHA to review and pack. |
| `license` | Exact SPDX identifier from `addon.json`. Must be one of `MIT`, `MIT-0`, `Apache-2.0`, `BSD-2-Clause`, `BSD-3-Clause`, `ISC`, `0BSD`. |

## Automated checks

When you open a pull request, GitHub Actions runs `bun run validate-pr` to verify:

- the JSON format and filename match,
- the repository is public and the exact `commit` exists,
- `addon.json` passes `schema/addon.schema.json` and contains no starter placeholders,
- `LICENSE.md` is present at the add-on's root and filled in,
- only `.lua`, `.json`, and `.md` files are present, and the add-on packs cleanly into a `.kbooksaddon`.

See <https://addme.dev/books/submit> and <https://addme.dev/books/docs/checking> for full instructions.
