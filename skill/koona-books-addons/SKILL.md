---
name: koona-books-addons
description: Write, fix or review an add-on for Koona Books, the e-book library app (a folder with addon.json, Luau scripts and locales, packed as .kbooksaddon). Use this whenever someone wants Koona Books to do one more thing - send books to an e-reader over Wi-Fi, recognize a reader's memory card, add books from a catalog or OPDS server, sync reading progress or shelves with a service, look up book details or covers, add a menu action on books, export or import a book list - or asks why Koona Books refuses their add-on, or how to get one on Koona's checked list. Use it even when they only say "plugin" or "extension" for Koona Books, or name a service and say "sync my reading with it".
---

# Writing an add-on for Koona Books

An add-on is a folder of text files: `addon.json` (the manifest), one or more Luau scripts, and
`locales/en.json`. The app runs the scripts in a sandbox and holds them to what the manifest asks for.
Everything in `references/` is the app's own reference for authors, checked against the app's code, so
trust it over what you remember of Lua, of other apps' plugin systems, or of Calibre.

You cannot run an add-on yourself: only the app can. So the work is to write it right the first time,
from the reference, and then tell the person exactly how to load it and what to look at. The strict
rules below exist because the app refuses a whole add-on for one unknown key or one stray file, and the
person then sees a refusal instead of your work.

## 1. Decide what kind of add-on it is

Read `references/README.md` first: it lists the eight kinds, and what no add-on can do. Then match the
request:

| The person wants | Kind (`type`) | Category | Read | Start from |
| --- | --- | --- | --- | --- |
| Send books to a reader over the network | `send_target` | `send` | `references/send-target.md` | `templates/send/` |
| A reader's memory card or drive recognized | `device_profiles` | `send` | `references/reader-profiles.md` | the manifest of `templates/send/`; the data file modeled on `examples/xteink-card/` |
| Browse or search a catalog and add books | `import_source` | `import` | `references/import-source.md` | `templates/import/` |
| Reading progress, status or shelves in step with a service | `reading_sync` | `sync` | `references/reading-sync.md` | `templates/sync/` |
| Book details or covers from a site | `book_info` | `info` | `references/book-info.md` | `templates/info/` |
| A menu action that opens a page for a book, or copies text | `book_action` | `tools` | `references/tools.md` | `templates/tools/` |
| A list of books saved as a file | `list_export` | `tools` | `references/tools.md` | `templates/tools/` |
| Reading status and dates read from a file | `list_import` | `tools` | `references/tools.md` | the manifest of `templates/tools/`; the script modeled on `examples/book-list-csv/` |

Always start from a starter in `templates/`. An example in `examples/` is a model to read, never a
folder to copy: its `id`, `name` and `author` are Koona's, and an add-on that keeps them is refused.

If the request fits none of these (a new file format, conversion, anything with its own window, a
background job, changing a book's file), say so plainly and stop: `references/README.md` ("What an
add-on cannot do") and `references/from-calibre.md` list what has no counterpart. Do not bend a kind
into something it is not.

An add-on has one category. Two things of different categories are two add-ons.

## 2. Find out what the service really does

The script is the exchange with a device or a service, so you need that exchange in writing: the
addresses, what is sent, what comes back, how it signs in, its request limit. Use the service's own API
documentation, or what the person gives you. If you do not have it, ask for it; do not invent an API.

For a file format (a list exporter or importer) the exchange is the format's own specification, or a
sample file the person gives you. Do not write a format from memory; if you must, say so to the person
as something you could not verify.

Do not read or port a Calibre plugin's code: it is under the GPL, and a port made by reading it is not
taken on Koona's checked list (`references/from-calibre.md`).

Check early that the service can be reached the way an add-on may reach things
(`references/permissions.md`, `references/host-api.md`):

- Only hosts named in the manifest, over `https` (plain `http` only to a device or server on the
  person's own network). List every host a request or a redirect leads to.
- Answers must be UTF-8 text (JSON, XML, CSV). A script cannot fetch a binary file or parse an HTML page.
- Signing in is one of: a `secret` setting the script sends itself; a user and a password with roles;
  or OAuth 2 with PKCE that the app runs (`sign_in`). `references/reading-sync.md` says which forms the
  app can really set up for a sync. A send target has no secret at all (`references/send-target.md`).
- A service that signs in with a login request and a session (a cookie or a token it answers) works
  without `sign_in`: the script reads `set-cookie` or the token from the answer and sends it back
  (`Cookie`, or the service's header) in the same call. Nothing is kept between calls, so every call
  signs in again first: one request more each call, and a service that limits logins may refuse it.
  With `sign_in` the script may not send `Authorization` or `Cookie`. OAuth with a client secret
  cannot be done.

## 3. Copy the starter and make it yours

Copy the starter folder for the category. Then, in `addon.json` (`references/manifest.md` is the
field-by-field reference; every rule there is enforced):

- `id`: reverse-DNS under a domain the person controls. Never `app.koona...`, and never "Koona" in
  `name` or `author.name`: those are refused. An id under a test domain such as `org.example...` is
  accepted by the app, but the id is the add-on's for good (updates and the person's settings follow
  it), so use a real domain before handing it over.
- `version`: any valid version; the starters use `0.1.0`. Raise it with each change you hand over.
- Ask for exactly what the scripts use. A permission nothing uses is refused, and so is a privacy code
  the permissions do not back, and a missing privacy code that they require. The tables "Who may ask for
  what" in `references/permissions.md` and "What is refused together" in `references/manifest.md` settle
  every case; check your manifest against both before you finish.
- Use only keys that `references/manifest.md` lists. An unknown key refuses the whole add-on. The key is
  `license`, American spelling.
- Keep `api` at the level `references/manifest.md` states, and `min_app` as the starter has it.
- `tested` is optional. Fill it in only with a device or a service the add-on was really tried on, and
  when; never claim a test that was not made. Leave it out when you could not run it.

## 4. Write the script

Work from the page of the kind and from the starter, and look at the matching example in `examples/`
for how a real one handles the awkward cases (`references/examples.md` says which shows what).

The rules that most often break a first draft:

- The file returns a table of functions; the kind fixes their names. Every function returns a table.
  Failure is `{ error = "code" }`; there is no `ok` key. A list goes inside the answer as `rows` (or
  `results`), never as the answer itself.
- Only `string`, `table`, `math`, `utf8`, `bit32` and `koona` exist. No `require`, `os`, `io`, `print`,
  no clock, no sleeping, nothing kept between calls. One file cannot load another, so shared helpers are
  repeated in each entry file, or the entries share one file and tell themselves apart by `ctx.id`.
- A request that got no answer does not raise: it returns `status = 0` and an `error` code. Check
  `status` every time. Decoding a document does raise: wrap `koona.json.decode`, `koona.xml.parse` and
  `koona.csv.decode` in `pcall` when the text came from outside.
- Treat everything from the network as untrusted: check `type()` before you use a field. A wrong type
  must become an error code, not a Lua error, because three failed jobs in a row turn the add-on off.
- Never answer one of the app's own codes (`references/README.md` lists them); pass `koona.http`'s codes
  on as they are; make up short codes of your own for the rest and word each as `error.<code>`.
- A secret is read with `koona.secret.get(key)`, never from `ctx.settings`. Never log it or put it in
  an address.
- Stay inside the caps of the kind's page and `references/limits.md`.
- Comment the script the way the examples do: what the service's exchange is, and why each check is
  there. A reviewer reads every line.

## 5. Write the words

`references/words.md` lists every locale key the app reads. A package is refused without
`locales/en.json`, without a label for each setting (`setting.<key>`) and for each book action,
exporter and importer. Word every error code your script can answer. Texts are plain, trimmed, and
short; a label never ends in dots. Only `locales/en.json` is required; other languages are optional.

Update `README.md` (what it does, what it reaches, how it was tried), `CHANGELOG.md`, and the locale key
`changes`. The starter's `LICENSE.md` is a template: fill in the year and the person's name, or remove
the file. Never hand it over with `[year]` and `[fullname]` still in it. The app itself does not read
the file; Koona's checked list asks for it, filled in (`references/checking.md`).

## 6. Check your work against the reference, then hand it over

You cannot run it, so read it once more as the app will:

1. The folder holds only `.lua`, `.json` and `.md` files, UTF-8, no byte-order mark, nothing hidden.
2. Every key in `addon.json` is in `references/manifest.md`; every `entry` file exists; every entry is of
   the manifest's category. When you can run a JSON Schema validator, check the file against
   `schema/addon.schema.json` too, and read its `x-koona-rules` for what a schema cannot say.
3. Each permission is used, each privacy code required by "What is refused together" is there.
4. Every function the kind's page names exists and returns the shapes that page gives.
5. Every code the script can answer has `error.<code>` in `locales/en.json`, and none is the app's own.
6. Every `koona.` name you used is in `references/host-api.md`, called with the arguments it gives.

Then tell the person, briefly:

- what the add-on does and what it will ask them to agree to (the permission lines);
- how to try it: in Koona Books, Add-ons, turn on "Add-ons from a file", "Load a folder", pick the
  folder, agree to the sheet, then where the thing it adds appears (`references/testing.md` has the
  steps for each kind and how to read the log);
- what you could not verify, above all anything about the service that you took on trust;
- if they want it on Koona's checked list, what `references/checking.md` still asks of them.

When the app refuses the folder, the refusal names a code and often a field (`manifest_field:
permissions.network`). `references/testing.md` words every code; fix exactly that and have them load the
folder again.

The same pages have a public home at https://addons.koona.app/books/docs/. Give the person that address when
they want to read more; work from the copies in `references/`, which are the ones this skill was built
with. An add-on is submitted for Koona's checked list at https://addme.dev/books/ (`references/checking.md`); that
is the person's to do, not yours.

## Reference files

| File | Read it when |
| --- | --- |
| `references/README.md` | Always, first |
| `references/manifest.md` | Writing or fixing `addon.json` |
| `schema/addon.schema.json` | Checking `addon.json` with a validator; it is the same rules as data, and the app's own check is still the final word |
| `references/permissions.md` | Choosing permissions and privacy codes; explaining what the person will be asked |
| `references/host-api.md` | Before using any `koona.` function |
| `references/limits.md` | Sizes, times, and what a script does not have |
| `references/words.md` | Locale keys, error codes, icon names |
| `references/send-target.md`, `reader-profiles.md`, `import-source.md`, `reading-sync.md`, `book-info.md`, `tools.md` | The contract of the kind you are writing |
| `references/testing.md` | Telling the person how to try it; reading a refusal or a log |
| `references/checking.md` | The person wants it listed by Koona |
| `references/examples.md` | Picking which of the nine real add-ons in `examples/` to read |
| `references/from-calibre.md` | The person is porting a Calibre plugin |
