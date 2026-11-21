# Add-ons for Koona Books

[Koona Books](https://koona.app) is an e-book library for Windows and Mac. An add-on teaches it one more thing: send books to a reader over Wi-Fi, bring books in from a catalog, keep reading progress in step with a service, look up a cover. An add-on is a folder of text files (a manifest, Luau scripts, translations) that the app runs in a sandbox.

This repository holds the examples, starters, agent skill, and the pull-request registry for Koona's checked list:

| You want to | Go to |
| --- | --- |
| Have a coding agent write an add-on for you | [Install the skill](#install-the-skill), below |
| Write one yourself | [The pages for authors](https://addme.dev/books/docs/) and a folder from [`starters/`](starters) |
| See how a real one is made | [`examples/`](examples): the ten add-ons that come with the app |
| Offer yours for Koona's checked list | [Submit guide](https://addme.dev/books/submit) and [`registry/`](registry) |
| See which add-ons there are | [The list](https://addme.dev/books/) |

## Install the skill

The skill teaches a coding agent to write, fix or review an add-on for Koona Books. It carries the authors' reference, the examples, the starters and the manifest's schema, so the agent works from what the app really does.

**Claude Code**, one command in a terminal:

```sh
claude plugin install koona-books-addons --marketplace koona-project/books-addons
```

On a Claude Code older than 2.1.292, two commands do the same:

```sh
claude plugin marketplace add koona-project/books-addons
claude plugin install koona-books-addons@koona-books
```

**Codex, Cursor, Gemini CLI and other agents**, one command, with Node.js on the computer:

```sh
npx skills add koona-project/books-addons --skill koona-books-addons -g -y
```

**By hand**, with nothing installed: download [the zip](https://addme.dev/books/docs/download/koona-books-addons-skill.zip) and unpack it where your agent keeps its skills. For Claude Code that is `~/.claude/skills/` for every project, or `.claude/skills/` inside one project. An agent without a skills folder can be told to read [`skill/koona-books-addons/SKILL.md`](skill/koona-books-addons/SKILL.md) first.

Then ask for what you want in plain words:

> Write a Koona Books add-on that sends books to my reader over Wi-Fi

The agent picks the skill up by itself and writes the add-on's folder. It cannot run an add-on: only Koona Books can. [Trying an add-on](https://addme.dev/books/docs/) in the app is described in the pages for authors.

## What is here

| Folder | What |
| --- | --- |
| [`examples/`](examples) | The ten add-ons that come with Koona Books (`book-links`, `book-list-csv`, `citations`, `crosspoint-wifi`, `hardcover`, `koreader-sync`, `opds`, `openlibrary`, `wikidata`, `xteink-card`). Read them as models; do not copy one: its `id`, `name` and `author` are Koona's, and an add-on that keeps them is refused |
| [`starters/`](starters) | One small working add-on for each category (`send`, `import`, `sync`, `info`, `tools`). Copy a folder, rename it, and make it yours |
| [`skill/koona-books-addons/`](skill/koona-books-addons) | The agent skill, whole: its instructions, the authors' pages, the examples, the starters and the schema, in one folder that works on its own |
| [`registry/`](registry) | One JSON file per third-party add-on on Koona's checked list (`registry/<id>.json`), submitted via pull request |
| [`schema/`](schema) | Koona Books' manifest schema (`addon.schema.json`), review rules (`review-rules.json`), allowed licenses (`checked-licenses.json`), and index signing public keys (`addons-keys.json`) |
| [`scripts/`](scripts) | Pure-Bun build, validation, signing, and Cloudflare R2 publishing pipeline run by GitHub Actions |

`examples/`, `starters/`, `skill/`, `schema/`, and `withdrawn.json` are synced from Koona Books ([SOURCE.md](SOURCE.md)) and are not edited directly here. To report a fault in them, open an issue using "Report a fault".

## Offer an add-on for the checked list

1. **Prepare your repository.** Host your add-on in a public GitHub repository with `addon.json`, your `.lua` scripts, `locales/`, and a filled-in `LICENSE.md` matching one of the allowed licenses (`MIT`, `MIT-0`, `Apache-2.0`, `BSD-2-Clause`, `BSD-3-Clause`, `ISC`, `0BSD`). See [what the checked list asks](https://addme.dev/books/docs/checking).
2. **Open a pull request.** Add one file at `registry/<your-addon-id>.json` pointing to your repository and the exact 40-character commit SHA to review (see [`registry/README.md`](registry/README.md) or <https://addme.dev/books/submit> for the template).
3. **Automated checks run.** GitHub Actions runs `bun run validate-pr` on your pull request to check the schema, placeholders, `LICENSE.md`, allowed file extensions, and test-packs the add-on.
4. **Confirm the author's agreement & review.** Complete the pull request template (including the [author's agreement](https://addme.dev/books/docs/checking#what-you-agree-to)). A person at Koona reads every line of your add-on at that commit.
5. **Merge & publish.** Once merged to `main`, GitHub Actions packs, signs, and publishes the new version to `https://addons.koona.app/books/v1/`. It then appears in Koona Books under Find add-ons and in the catalog at <https://addme.dev/books/>.

To publish a new version later, open a new pull request updating `version` and `commit` in `registry/<your-addon-id>.json`.

## What does not belong here

- Your add-on's source code inside this repository. Keep it in your own repository; `registry/<id>.json` points to it.
- Edits to `examples/`, `starters/`, `skill/`, or `schema/` in a pull request — those are synced from Koona Books.
- Secrets of any kind. Pull requests and issues are public.

## Publishing (maintainers)

Pushing to `main` (touching `examples/**`, `registry/**`, or `withdrawn.json`) runs `.github/workflows/publish.yml` in the protected `publish` environment.

For the initial pre-DNS cutover into a fresh Cloudflare R2 bucket (reading the current `serial` and published hashes from the existing `addons.koona.app` server while verifying uploaded objects against R2's public URL), run `publish.yml` via **Run workflow** with `verify_url` set to the R2 bucket's public URL (e.g. `https://pub-<id>.r2.dev/books/v1/`), or run locally:

```sh
bun scripts/publish.ts \
  --live-url https://addons.koona.app/books/v1/ \
  --verify-url https://pub-<id>.r2.dev/books/v1/
```

Once DNS for `addons.koona.app` points to R2, no URL flags are needed.

## License

The add-ons in `examples/` and `starters/`, and the copies of them in the skill's folder, are under the MIT license: [LICENSE](LICENSE). Each add-on's `addon.json` names it too.
