# Import sources: books from a catalog

An add-on of the category `import` lets a person add books from a catalog: a public library, a shop's
free shelf, or their own server at home. The person opens it from Add books (From a catalog), browses
its sections, searches it, ticks books and adds them.

Your script does one small part of that. It reads the catalog and says what is in it: sections to
open, and books with **links** to their files. Koona Books does everything else: the dialog, the
download under its own caps, looking at what each downloaded file really is, and the usual import
that copies it into the library. **A book's bytes never enter a script.** Your script cannot fetch a
book for the app, and it never learns which books the person took.

The starter [`../templates/import/`](../templates/import/addon.json) is a catalog at one listed host
that answers JSON. The included OPDS catalogs add-on
([`../examples/opds/opds.lua`](../examples/opds/opds.lua)) reads OPDS feeds at a server the person
names, with a user name and a password.

## Two kinds of catalog

Where the catalog is decides almost everything else.

| | A catalog at listed hosts | A catalog at a server the person names |
| --- | --- | --- |
| The manifest asks for | `permissions.network.hosts` | `permissions.network.named_server` and one `server` setting |
| How many | One: the add-on is the catalog | As many as the person adds, each with its own address |
| How the person adds it | They turn the add-on on; the catalog is listed while it is on | A form: the address, a user name and a password when the source has them; Test connection |
| `ctx.base`, `ctx.start` | Not there: the script knows its own address | The server and where the catalog starts on it |
| `ctx.settings` | Only the defaults your manifest gives: nothing is typed | What the person typed in the form |
| Secrets | None: `koona.secret.get` answers `nil` | What the person typed, from the keychain |
| `check` | Not called | Called by Test connection and when the catalog is saved |
| The app's sign-in to its own fetches | None | Basic, to that server only, when a user name is set |

A manifest may ask for both: a server the person names whose files sit on a host the manifest lists.
Then every catalog is one the person names, and the listed hosts are only more places the script and
the app may reach.

A catalog at listed hosts is shown in From a catalog under the add-on's `name` from the manifest:
there is no `check` to name it, and no locale key for it.

### What a catalog cannot do

- **A catalog at listed hosts has no form.** Its settings are never typed and its secrets never
  asked: `ctx.settings` holds only defaults, and `koona.secret.get` answers `nil`. A service that
  needs the person's key or account cannot be a catalog at listed hosts; make it one at a server the
  person names.
- **A file link that needs a token or a header cannot be downloaded.** The app downloads every file
  and cover itself, and it signs in only with `Authorization: Basic` from the user and the password,
  and only to the server the person named. A file is `{ url, format, size }`: there is no way to hand
  the app a header, a cookie or a token for it.
- **A catalog at a server the person names cannot be tried from a developer's folder** while the
  OPDS catalogs add-on that comes with Koona Books is offered: the form for a new catalog opens for the
  first add-on that offers one, which is that one. It is offered while it is on, and also while it
  has never been turned on; turn it on and then off on its page while you try yours
  ([testing.md](testing.md)).

## The manifest

<!-- generated:file ../templates/import/addon.json -->
```json
{
  "schema": 1,
  "id": "org.example.import-starter",
  "version": "0.1.0",
  "api": 1,
  "min_app": "0.1.0",
  "name": { "en": "Import starter" },
  "summary": { "en": "Browse the Example catalog, search it and add its books" },
  "glyph": "catalogue",
  "category": "import",
  "author": { "name": "Your Name" },
  "license": "MIT",
  "permissions": {
    "network": { "hosts": ["api.example.org"] }
  },
  "privacy": { "sends": ["searches_to_service"], "collects": [] },
  "provides": [
    { "type": "import_source", "id": "example", "entry": "catalog.lua" }
  ]
}
```
<!-- /generated -->

What the person agrees to when they add it, as codes (the words the app shows for each are in
[permissions.md](permissions.md)):

<!-- generated:codes import -->
```text
network.host:api.example.org
provides.import_source:example
sends.searches_to_service
```
<!-- /generated -->

- **`category`** is `import`, and every entry is an `import_source`. An entry has only `type`, `id`
  and `entry`.
- **`permissions.network`** names where the catalog is: `hosts`, or `named_server`, or both. A
  catalog is somewhere on the internet or on the person's network; a reader on their network
  (`local_device`) is not a place books come from, and is refused for an import source.
- **`pace`** may be added under `network` when the service states a request limit. The requests of
  one call to your script (one page, one search) wait for their turn at that pace. An import source's
  pace is kept only inside one call: each call starts with the pace's whole `burst`, and nothing of
  it carries to the next page (see the pace under
  [`koona.http.request`](host-api.md#koonahttprequest)). The app's own downloads of files and covers
  do not wait on it.
- **`secrets`** is needed for a setting of `"type": "secret"`, such as a password.
- **`privacy.sends`** must hold `searches_to_service`: the words a person searches for, and the pages
  they open, go to the catalog. A manifest of an import source without it is refused.

A source at a server the person names, with a user name and a password:

<!-- sample:manifest-part import -->
```json
{
  "permissions": {
    "network": { "named_server": true },
    "secrets": true
  },
  "privacy": { "sends": ["searches_to_service"], "collects": ["account"] },
  "settings": [
    { "key": "server", "type": "server" },
    { "key": "user", "type": "text", "role": "user" },
    { "key": "password", "type": "secret", "role": "password" }
  ]
}
```

`collects: ["account"]` says that the add-on keeps a user name of the person's. The manifest does not
require it for an import source; declare it when your form has a user name.

`named_server` with no `server` setting is refused at `named_server`:

<!-- sample:manifest-refused import permissions.network.named_server -->
```json
{
  "permissions": { "network": { "named_server": true } }
}
```

A manifest that does not say that searches leave the computer is refused at `privacy.sends`:

<!-- sample:manifest-refused import privacy.sends -->
```json
{
  "privacy": { "sends": [], "collects": [] }
}
```

A reader on the person's network is not a catalog:

<!-- sample:manifest-refused import permissions.network.local_device -->
```json
{
  "permissions": { "network": { "local_device": { "ports": [8080] } } }
}
```

### The user and the password

Two settings mean something to the app, found by their `role`, never by their `key`:

- the `text` setting with `"role": "user"` is the person's user name at the catalog;
- the `secret` setting with `"role": "password"` is its password.

Each role may stand once. A password is signed in with a user, so `"role": "password"` without a
`"role": "user"` is refused:

<!-- sample:manifest-refused import settings[0].role -->
```json
{
  "permissions": { "network": { "hosts": ["api.example.org"] }, "secrets": true },
  "settings": [ { "key": "password", "type": "secret", "role": "password" } ]
}
```

Your script reads them as it reads any setting: the user name in `ctx.settings`, the password with
`koona.secret.get(key)`, and it signs its own requests in as the catalog wants (OPDS catalogs take
`Authorization: Basic`; see `headers` in [`../examples/opds/opds.lua`](../examples/opds/opds.lua)).

**The app signs in what it fetches itself**, a book's file and a cover: `Authorization: Basic` made of
the user and the password, only when a user name is set, and only to the catalog's own server, the one
the person named (the same scheme, host and port). Never to a host the manifest lists, and never on a
redirect to anywhere else. A catalog at listed hosts has no server, so the app signs in nothing for
it. A source with no such roles gets its files asked for with no sign-in. Every other setting is the
script's own.

A user name with a colon in it is refused by the form (`bad_user`): it would move the line between
the user and the password.

### Settings in the form

The form for a catalog the person names is drawn by the app from your settings:

- the setting of `"type": "server"` is the address field;
- the user and the password, by their roles, are the two fields under it;
- any other setting (`text` or `secret`) is a field of its own below them.

Every setting needs its label, `setting.<key>`, in `locales/en.json` (the package is refused without
it). A catalog at listed hosts has no form, so its settings are never typed: `ctx.settings` holds only
their defaults.

## `ctx` and the three functions

The entry file returns a table of up to three functions. The app looks for a function only when it
calls it, and a function it calls that is missing is the add-on's failure (`broken`):

- `browse` is called for every catalog: write it always.
- `search` is called only from a page whose answer has a `search` note. A catalog whose pages never
  give one needs no `search`.
- `check` is called only for a catalog at a server the person names (Test connection, and saving the
  form). A catalog at listed hosts needs no `check`.

```text
check(ctx)          -> { name = "Example Library" }        name optional
browse(ctx, ask)    -> page            ask = { url = "..." }, or {} for the catalog's start
search(ctx, ask)    -> page            ask = { query = "dune", note = "<a page's search>" }
each, when it could not: { error = "<code>" }

ctx = { id = "<the source's id>", settings = { user = "..." },   -- no secret is ever here
        base = "http://192.168.1.10:8080", start = "/opds" }     -- a server the person named only
```

- **`ctx.id`** is the entry's `id`.
- **`ctx.settings`** holds every setting that is not a secret, as text. One the person left empty
  takes its `default`, or is not there.
- **`ctx.base`** is the server's scheme, host and port, with no path (an IPv6 address in brackets, the
  port only when it is not the scheme's usual one). **`ctx.start`** is the part of the catalog's
  address after its host, `/` at least: the person typed `192.168.1.10:8080/opds`, so `base` is
  `http://192.168.1.10:8080` and `start` is `/opds`. A source whose manifest lists its hosts has
  neither.

The rules every point shares (an answer is a table; `{ error = "<code>" }` is a failure; the app's own
codes are never a script's) are in [words.md](words.md).

### `check(ctx)`

Asks the catalog whether it is there and what it calls itself. The app calls it from the form of a
catalog the person names: Test connection runs it with what was typed (kept nowhere), and saving the
form (Add catalog, or Save for a catalog being changed) runs it again to name the catalog it keeps. `name` is shown as the catalog's title; a catalog saved with no
name is shown by its address. A failed check does not stop the person from saving.

A catalog at listed hosts has no form, so `check` is not called for it. The starter keeps one anyway,
for a source that grows into one the person names.

<!-- sample:reply {"title":"Example Library"} -->
<!-- sample:returns {"name":"Example Library"} -->
```lua
local r = koona.http.request{ url = "https://api.example.org/v1/shelves/root" }
if r.status == 0 then return { error = r.error or "unreachable" } end
if r.status ~= 200 then return { error = "refused" } end
-- A body that is not JSON raises: caught, it is a code, not the add-on's failure.
local ok, answer = pcall(koona.json.decode, r.body or "")
if not ok or type(answer) ~= "table" then return { error = "not_a_catalogue" } end
return { name = type(answer.title) == "string" and answer.title or nil }
```

### `browse(ctx, ask)`

One page of the catalog. `ask` is `{}` for the catalog's start, or `{ url = "..." }` for an address an
earlier page gave: a section's `url`, or a page's `next`. The app checks that address before your
script runs: one this add-on may not reach ends the call as the app's own `elsewhere`, and the script
is not asked.

### `search(ctx, ask)`

What the catalog finds for the person's words. `ask.query` is what they typed, cleaned and cut (the
cap is "The person's search words" below); the app never asks with no words. `ask.note` is the
`search` of the page they searched from.

The app offers the search field only on a page whose answer has a `search`. That note is yours: where
this catalog's search is, or how to ask it. The app does not read it; it hands it back to `search`
with the words. On the page of results the field searches again with the note of the page the search
began from. The OPDS add-on writes `"t <template>"` or `"d <description address>"` there; a catalog
with one search may write any text, as the starter writes `"all"`.

## The page

```text
page = { title = "Newest", rows = { row, ... }, next = "<url>" or nil, search = "<note>" or nil }
row  = { kind = "folder", title, summary, url, count }
     | { kind = "book", title, authors = { "...", ... }, summary, language, cover = "<url>",
         page = "<url>", files = { { url, format, size }, ... },
         other = { { kind = "buy" | "borrow" | "subscribe" | "sample", url }, ... } }
```

**Nothing a script says is taken as it is.** Every text is cleaned as a book's metadata is (no control
or invisible character, spaces run together, never a space at either end) and cut to its cap. A field
of the wrong type is left out. The caps are in the table at the end of this page.

- **`title`**: the page's title. **`rows`**: its rows, in order. A page with no `rows` is an empty
  page. Only the first rows up to the cap are read; one of them that is not a row is left out.
- **`next`**: the page after this one, an address the app hands back to `browse`. The app asks for it
  when the person wants more. A `next` this add-on may not reach is left out, and so is a `next` that
  is the address of the page itself. After a long run of `next` pages followed one after another, the
  app stops offering more.
- **`search`**: the note described above. Not cleaned: it is kept as you wrote it when it is not
  empty and not over its cap, and left out otherwise.

### A folder

A section to open: `title`, `summary`, `url` (required, an address this add-on may reach, or the row
is left out) and `count`, how many books the catalog says it holds (a whole number of 0 or more; a
fraction is cut off). A folder with no title still opens: the app has a word for it.

### A book

- **`title`**, **`summary`**, **`authors`** (a list of names; one that is empty after cleaning is left
  out).
- **`language`**: a short code of letters, digits and hyphens, kept as you wrote it after cleaning,
  anything else left out. It is not turned into a tag: when your catalog writes `eng`, give
  `koona.lang.tag(code)` (`en`), as the starter does ([host-api.md](host-api.md)).
- **`cover`**: a picture of the cover, kept only when this add-on may reach it.
- **`page`**: the book's page at the catalog's site, for the person's browser.
- **`files`**: the files the app may download, each `{ url, format, size }`.
- **`other`**: links that are not a free file, each `{ kind, url }`: `buy`, `borrow`, `subscribe` or
  `sample`. Any other `kind` is left out.

**A book with no file and no `other` link is left out**: there is nothing to do with it.

### `files` and `format`

`format` is one of the formats the app takes from a catalog:

<!-- generated:import-formats -->
`epub`, `fb2`, `fbz`, `azw3`, `mobi`, `pdf`
<!-- /generated -->

(`fbz` is FB2 in a zip.) A file of any other format is left out of the row. The format only says what
to offer: when the person picks one, the app downloads it and decides from its bytes what it really
is. A file that is no book the app reads is not added (`not_a_book`); one that is a book of another
of these formats is added as what it is. When a book has several files, the app offers the person one
of each format, EPUB first.

`size` is the size the catalog states, in bytes: a number of 1 or more (a fraction is cut off), or
nothing. The app shows it beside the format the person picks from, and holds the download to its own
cap whatever the size says.

## Where every address may lead

Every address in an answer must be `http` or `https`, with no user name or password in it, and no
longer than an address may be ([limits.md](limits.md)); anything else is not an address and is left
out. Past that, each field has its own rule. "May reach" means what the manifest grants: a host it
lists, or the server the person named.

| Field | What the app does with it |
| --- | --- |
| `ask.url` handed to `browse` | Checked before the script runs; one this add-on may not reach is `elsewhere` |
| A folder's `url` | Kept only when this add-on may reach it; else the row is left out |
| `next` | Kept only when this add-on may reach it; else left out |
| `cover` | Kept only when this add-on may reach it. The app fetches it, small, under its own caps, signed in only at the catalog's own server |
| A file's `url` | At a place this add-on may reach: offered, downloaded by the app. Anywhere else: shown with its host's name ("on another site"), never fetched; the person may open it in their browser |
| `page`, an `other` link's `url` | Any web address. Never fetched by the app; opened in the person's browser only when they click it, through the app's own link check |

So a manifest lists every place a link it gives should be fetched from. A catalog whose covers or
files sit on another host lists that host too:

<!-- sample:manifest-part import -->
```json
{
  "permissions": { "network": { "hosts": ["api.example.org", "files.example.org"] } }
}
```

The app's fetch follows a redirect only inside the rule it started in: a file at a listed host that
redirects to a host the manifest does not list is not fetched, and fails as `moved`. The person sees
that the file is elsewhere. A request your script makes follows the same rule; a redirect out of it
comes back to the script as the redirect's own status ([host-api.md](host-api.md)).

## What the app does with a book the person adds

The person ticks books (a cap on how many at once), and the app downloads them one after another: each
file only from a place this add-on may reach, signed in as above, streamed to the cache under a cap on
its size, then looked at and handed to the usual import with the others. The script is not asked
anything during a download. Every failure of a download is the app's own and has the app's words:
`elsewhere`, `moved`, `not_a_book`, `too_large`, `unreachable`, `timeout`, `tls`, `sign_in`,
`not_found`, `refused`, `server_moved`, `disk`, `cancelled`, `not_added`.

Only one browse or search of a catalog runs at a time: a new one stops the one under way, which ends
as `cancelled`.

## Failures and their words

A function that could not do its job answers `{ error = "<code>" }`. Pass on the code `koona.http`
gave (`unreachable`, `timeout`, `tls`, `too_large`, ...) as it is, and use your own codes for the
rest. Which words the person sees follows the one rule in [words.md](words.md): the app's own codes
have the app's words; a code your script said has your `error.<code>` first, then the app's words for
that code when it has some here, then the app's one sentence for anything else. A code is never shown
as it is.

The app's own codes at this point are `elsewhere`, `server_moved`, `denied`, `cancelled`, `limits` and
`broken`; a script never answers one of them (the full list is in [words.md](words.md)).

Where the failure shows changes what the app does with your code:

| Where | A code your script said |
| --- | --- |
| The form: Test connection, saving it | Your `error.<code>`; else the app's words for `unreachable`, `timeout`, `sign_in` and `not_a_catalogue`; else the app's sentence |
| A page or a search that failed | `unreachable` and `timeout`: always the app's "does not answer" state, with Try again. `sign_in`: always the app's sign-in state, which offers to change the catalog's user name and password. Any other: your `error.<code>`, else the app's sentence |

So say `sign_in` when the catalog refuses the user name and password (a `401` or `403`), and
`not_a_catalogue` when something answers at the address that is not your kind of catalog: both have
the app's words in the form, and `sign_in` opens the way to fix it.

`{address}` in your words stands for the catalog's address as the person sees it
(`192.168.1.10:8080/opds`). A catalog at listed hosts has no address: words of yours that hold
`{address}` are not used for it, and the app's words are shown instead.

A failure of `check` (in Test connection or while saving) is the person trying an address, and never
counts against the add-on.
Elsewhere, `broken`, `limits` and `denied` are the add-on's own failures ([testing.md](testing.md)).

## Words

Beside the general keys (`does`, `works`, `changes`; see [words.md](words.md)), an import source reads
these from its locale files:

| Key | Where it shows |
| --- | --- |
| `source.<id>.add` | The title of the form for a new catalog the person names |
| `source.<id>.how` | The paragraph under that title |
| `source.<id>.place` | This catalog's name where the app lists what a new version of your add-on asks for |
| `setting.<key>` | The label of a setting's field in the form (required for every setting) |
| `setting.<key>.hint` | For the `server` setting only: the line under the address field before a test |
| `error.<code>` | Your words for a code your script says |

`source.<id>.add` and `.how` are used only by a source that has a form, one at a server the person
names. Without them the form takes the app's own words.

<!-- sample:locale -->
```json
{
  "does": "Opens a catalog you name, so you can browse it, search it and add its books.",
  "source.shelf.add": "Add a catalog",
  "source.shelf.how": "Type the address your server shows for its catalog.",
  "source.shelf.place": "the catalog",
  "setting.server": "Address",
  "setting.server.hint": "Such as 192.168.1.10:8080/opds",
  "setting.user": "User name",
  "setting.password": "Password",
  "error.sign_in": "The catalog does not take this user name and password",
  "error.not_a_catalogue": "Something answers at {address}, but it is not a catalog"
}
```

## The starter's script

<!-- generated:file ../templates/import/catalog.lua -->
```lua
-- Import starter: an import source for Koona Books, made to be copied and renamed.
--
-- The Example catalog at api.example.org answers JSON. This script reads it and says what is
-- in it: shelves to open, and books with links to their files. It never downloads a book or a
-- cover. Koona Books does that itself, from the links, and decides from the bytes what a
-- downloaded file really is.

local API = "https://api.example.org"
-- Where the catalog starts. A catalog at a host the manifest lists gets no `ctx.base`: the
-- script knows its own address.
local START = API .. "/v1/shelves/root"

-- The file types this catalog names, as the formats Koona Books takes from a catalog. A file
-- of any other type is left out here; the app would drop it anyway.
local FORMATS = { epub = "epub", fb2 = "fb2", mobi = "mobi", azw3 = "azw3", pdf = "pdf" }

-- A list from the catalog's JSON, or an empty one: `ipairs` of something that is not a table
-- would end the call as an error.
local function list(value)
  if type(value) == "table" then return value end
  return {}
end

-- The items of a list that are tables. The catalog's answer is not to be trusted: an item that
-- is a number or a text has no fields, and reading one of a number ends the call as an error.
local function tables(value)
  local out = {}
  for _, item in ipairs(list(value)) do
    if type(item) == "table" then out[#out + 1] = item end
  end
  return out
end

-- One request, decoded. On failure: nil and a code. The app has its own words for
-- `unreachable` and `timeout`; `not_found`, `refused` and `not_understood` are worded in
-- locales/en.json.
local function get(url)
  local r = koona.http.request{ url = url, headers = { accept = "application/json" }, timeout = 20 }
  if r.status == 0 then return nil, r.error or "unreachable" end
  if r.status == 404 then return nil, "not_found" end
  if r.status ~= 200 then return nil, "refused" end
  local ok, value = pcall(koona.json.decode, r.body)
  if not ok or type(value) ~= "table" then return nil, "not_understood" end
  return value
end

-- An address the catalog wrote, made whole. The catalog writes paths ("/files/7.epub").
-- `koona.url.join` raises on something that is not an address, so it is caught.
local function link(path)
  if type(path) ~= "string" or path == "" then return nil end
  local ok, url = pcall(koona.url.join, API, path)
  if ok then return url end
  return nil
end

local function book_row(b)
  local files = {}
  for _, f in ipairs(tables(b.files)) do
    local format = FORMATS[f.type]
    local url = link(f.path)
    if format and url then
      -- `size` is what the catalog says, in bytes. The app shows it and still holds the
      -- download to its own cap.
      files[#files + 1] = { url = url, format = format, size = f.bytes }
    end
  end
  return {
    kind = "book",
    title = b.title,
    authors = list(b.authors),
    summary = b.summary,
    -- The catalog writes three-letter codes ("eng"); the app shows a tag ("en").
    language = type(b.language) == "string" and koona.lang.tag(b.language) or nil,
    -- Fetched by the app only because api.example.org is a host the manifest lists.
    cover = link(b.cover),
    -- The book's page on the catalog's site, for the person's browser.
    page = link(b.web),
    -- A book with no file the app may take is not shown.
    files = files,
  }
end

-- One page of the catalog, as the app reads it.
local function page_of(answer)
  local rows = {}
  for _, s in ipairs(tables(answer.shelves)) do
    local url = link(s.path)
    if url then
      rows[#rows + 1] = { kind = "folder", title = s.title, summary = s.summary, url = url, count = s.count }
    end
  end
  for _, b in ipairs(tables(answer.books)) do
    rows[#rows + 1] = book_row(b)
  end
  return {
    title = answer.title,
    rows = rows,
    -- The page after this one. The app asks for it when the person wants more.
    next = link(answer.next),
    -- Any text here tells the app that the person may search from this page. It is handed
    -- back to `search` as `ask.note`. This catalog has one search, so the note says nothing.
    search = "all",
  }
end

local catalog = {}

-- Koona Books calls `check` from the form where a person names a catalog's server (Test
-- connection). This catalog is at a listed host and has no such form, so the app does not
-- call it here. It is kept for a catalog you turn into one the person names.
function catalog.check(ctx)
  local answer, why = get(START)
  if not answer then return { error = why } end
  return { name = answer.title }
end

-- `ask.url` is an address an earlier page gave (a shelf's `url`, a `next`); with none, the
-- start. The app has already checked it is an address this add-on may reach.
function catalog.browse(ctx, ask)
  local answer, why = get(ask.url or START)
  if not answer then return { error = why } end
  return page_of(answer)
end

-- `ask.query` is the person's words, cleaned and cut by the app; `ask.note` is the `search`
-- of the page they searched from.
function catalog.search(ctx, ask)
  local answer, why = get(API .. "/v1/search?q=" .. koona.url.encode(ask.query))
  if not answer then return { error = why } end
  return page_of(answer)
end

return catalog
```
<!-- /generated -->

## Limits

A call into an import source has its own time, in [limits.md](limits.md) ("A call into an import
source"). What one answer may hold:

<!-- generated:limits-import -->
| Limit | Value |
| --- | --- |
| Rows of one page | 500 |
| A title, an author, a page's title | 200 characters |
| A `summary` | 600 characters |
| A book's `authors` | 8 |
| A book's `files` | 12 |
| A book's `other` links | 6 |
| The person's search words | 200 characters |
| `search`, the script's note | 2,008 bytes |
<!-- /generated -->
