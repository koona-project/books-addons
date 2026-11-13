# The nine examples

Nine add-ons come with Koona Books. They are in `../examples/`, exactly as the app ships them, and each
is run by the app's own tests. Between them they use every kind of thing an add-on can add.

They are written by Koona, so their `id` starts with `app.koona.` and their author is Koona. **Do not
copy one to start your own**: the app refuses that id and that name from anyone else. Copy a starter from
`../templates/` and read these for how a real one is written.

Read them in this order. Each one adds a single new idea to the one before.

| # | Add-on | Folder | Kind | What it shows |
| --- | --- | --- | --- | --- |
| 1 | Xteink memory card | `../examples/xteink-card/` | reader profiles | An add-on with no code at all |
| 2 | Book links | `../examples/book-links/` | two link actions | The smallest script; one file serving two entries by `ctx.id` |
| 3 | Citations | `../examples/citations/` | a text action, a list exporter | Books in, text out; many books at once |
| 4 | Book list as CSV | `../examples/book-list-csv/` | a list exporter, a list importer | `koona.csv`, `koona.date`, reading state, rows read from a file |
| 5 | CrossPoint over Wi-Fi | `../examples/crosspoint-wifi/` | a send target | The network: a reader on the person's own network, an upload |
| 6 | KOReader sync | `../examples/koreader-sync/` | a reading sync | A server the person names, a user and a password, books known by their file |
| 7 | Open Library | `../examples/openlibrary/` | book information | A public API on listed hosts, a pace, candidates and covers |
| 8 | OPDS catalogs | `../examples/opds/` | an import source | XML, pages and links, signing in to the person's own server |
| 9 | Hardcover | `../examples/hardcover/` | a reading sync | A sign-in the app runs, books known by identifiers, paging with a cursor |

Every folder has the same files: `addon.json`, the script, `locales/en.json` with `es.json` and
`de.json` beside it, `README.md` and `CHANGELOG.md`.

## 1. Xteink memory card: no code

The whole add-on is a manifest and this data file. It teaches the app that a memory card with a
`.crosspoint` folder on it is an Xteink X4, which formats it takes, and where books go.

<!-- generated:file ../examples/xteink-card/profiles.json -->
```json
{
  "schema": 1,
  "profiles": [
    { "id": "x4", "name": "Xteink X4",
      "markers": [[".crosspoint"]],
      "formats": ["epub", "txt"], "converts": ["epub"],
      "pattern": "{author}",
      "protected": [".crosspoint"] }
  ]
}
```
<!-- /generated -->

Its manifest asks for nothing: `"permissions": {}`. The entry names the file and the readers in it, and
each reader is something the person agrees to. See [reader-profiles.md](reader-profiles.md).

## 2. Book links: the smallest script

Two entries in the manifest, "Find on Hardcover" and "Find on Open Library", both name `links.lua`. The
script tells them apart by `ctx.id`:

<!-- generated:file ../examples/book-links/links.lua | local links = {} | return links -->
```lua
local links = {}

-- A link action is always given one book.
function links.run(ctx, books)
  local find = words(books[1])
  if not find then
    return { error = "missing" }
  end
  return { link = SEARCH[ctx.id] .. koona.url.encode(cut(find, MOST)) }
end

return links
```
<!-- /generated -->

Notice:

- A tools add-on reaches no network. The link is opened by the person's browser, on their click, and
  only when it leads to the host that the entry names in the manifest.
- `books` is a list even for one book.
- A book with nothing to search by answers `{ error = "missing" }`, a code the app has words for.
- The search words are cut to a length, by whole characters, before they are escaped: a link has a
  length limit.

See [tools.md](tools.md).

## 3. Citations: books in, text out

"Copy citation" takes up to 100 books and gives one text; the same file also saves a list as BibTeX.
Every field of a book except its title may be missing, so every helper asks before it uses one:

<!-- generated:file ../examples/citations/cite.lua | -- The book's first ISBN | =end -->
```lua
-- The book's first ISBN, or nil. Every kind of identifier is a list of values, also for one.
local function isbn(book)
  local all = book.identifiers.isbn
  return all and all[1]
end
```
<!-- /generated -->

Notice how the script escapes the characters that BibTeX reads as its own, and makes each entry's key
unique within the file. What an exporter writes is the person's file: write it carefully.

## 4. Book list as CSV: a file out, and back in

The exporter writes with `koona.csv.encode`. The importer reads the file the person picked with
`koona.csv.decode`, and turns each line into a row: what to find the book by, and what to set. The app
does the matching and shows a preview; nothing changes until the person applies it.

It is strict about dates on purpose:

<!-- generated:file ../examples/book-list-csv/list.lua | -- The ways a spreadsheet writes | local DATES -->
```lua
-- The ways a spreadsheet writes the day a book was finished, ISO first. A date with slashes
-- is not read: 01/02/2026 is the 2nd of January in the United States and the 1st of February
-- in Britain, and a wrong day is worse than none. Such a row keeps its status and gets no date.
local DATES = { "yyyy-MM-dd", "yyyy-MM", "yyyy", "d.M.yyyy" }
```
<!-- /generated -->

Its manifest asks for `reading_state` (the reading fields of a book, and the right to change them through
the preview) and `input_file` for `csv`. See [tools.md](tools.md).

## 5. CrossPoint over Wi-Fi: the first request

A send target reaches one reader, at the address the person typed. `ctx.base` is that reader. This is
its "Test connection":

<!-- generated:file ../examples/crosspoint-wifi/send.lua | function t.check | =end -->
```lua
function t.check(ctx)
  local r = get(ctx, "/api/status")
  if r.status == 0 then return trouble(r) end
  local s = json(r)
  -- Something answers on port 80 (a router, a printer), but not as CrossPoint does.
  if not s or type(s.version) ~= "string" then return { error = "not_a_reader" } end
  local model = type(s.device) == "string" and s.device or ""
  return {
    name = model ~= "" and ("Xteink " .. model) or "Xteink",
    detail = "CrossPoint " .. s.version,
  }
end
```
<!-- /generated -->

Notice:

- A request that did not get an answer does not raise. It returns `status = 0` with an `error` code
  (`unreachable`, `timeout`), and the script passes that code on.
- Something may answer on port 80 that is not the reader (a router, a printer). The script checks that
  the answer has the reader's own shape and says `not_a_reader` otherwise.
- The script never shows the reader's own text. It turns what the reader said into a code, and the code
  has words in `locales/`.
- In `send`, the book is a handle passed to `koona.http.upload`. The script never sees the file.

See [send-target.md](send-target.md).

## 6. KOReader sync: a server, a user, a password

The person names their server. The manifest declares a `server` setting, a text setting with the role
`user`, and a secret with the role `password`. The script builds its own headers for every request:

<!-- generated:file ../examples/koreader-sync/sync.lua | local function auth(ctx) | =end -->
```lua
local function auth(ctx)
  local user = ctx.settings and ctx.settings.user
  local password = koona.secret.get("password")
  if type(user) ~= "string" or user == "" then return nil, "not_set_up" end
  if type(password) ~= "string" or password == "" then return nil, "not_set_up" end
  if not user_ok(user) then return nil, "bad_user" end
  return {
    ["accept"] = ACCEPT,
    ["x-auth-user"] = user,
    ["x-auth-key"] = koona.hash.md5(password),
  }
end
```
<!-- /generated -->

Notice:

- The password is never in `ctx`. `koona.secret.get` is the one way to it.
- This service knows a book by a digest of its file (`"match_by": "document"`). The app works the digest
  out and hands it over as the book's `key`; the script sees no title, no author and no file.
- When the server stops answering part-way, `pull` and `push` return what was done so far with
  `stopped = "<code>"`.

See [reading-sync.md](reading-sync.md).

## 7. Open Library: a public API

Book information asks a catalog about one book. The manifest lists every host its requests and its
cover links lead to, not only the one they start at, and a pace. Every request goes through one small
function:

<!-- generated:file ../examples/openlibrary/info.lua | local function get(url) | =end -->
```lua
local function get(url)
  local r = koona.http.request{ url = url, timeout = 20 }
  if r.status == 200 then return r.body end
  if r.status == 0 then return nil, r.error or "unreachable" end
  if r.status == 404 then return nil, "not_found" end
  if r.status == 429 or r.status == 503 then return nil, "limited" end
  return nil, "refused"
end
```
<!-- /generated -->

Notice:

- A cover is a link, never a picture. The app fetches it, and only from a host the manifest lists.
- The person's title is words, not a query: the script takes out the signs the service's search reads as
  its own before it sends them.
- Language codes differ between services. `koona.lang.tag` turns `rus` into `ru`.

See [book-info.md](book-info.md).

## 8. OPDS catalogs: pages of links

An import source reads a catalog's pages and says what is in them: sections to open and books with links
to their files. It reads XML with `koona.xml.parse`, which gives every name with its namespace.

<!-- generated:file ../examples/opds/opds.lua | function t.browse | =end -->
```lua
function t.browse(ctx, ask)
  return browse_at(ctx, ask.url or start_of(ctx))
end
```
<!-- /generated -->

Notice:

- `ask.url` is a page the script itself gave earlier as a row's `url` or as `next`. With no `url`, the
  person opened the catalog's start.
- The script fetches no book and no cover. It gives addresses, and the app checks each one against the
  add-on's permissions before it opens or fetches it.
- The user name and password have roles in the manifest, so the app can sign in the downloads it makes
  itself, and only to the person's own server.

See [import-source.md](import-source.md).

## 9. Hardcover: a sign-in the app runs

The manifest declares `sign_in`. The app opens the service's page in the person's browser, keeps the
token, and adds it to every request to the service's host. The script holds no secret at all:

<!-- generated:file ../examples/hardcover/sync.lua | function h.check | =end -->
```lua
function h.check(ctx)
  local user, why = me()
  if not user then return { error = why } end
  return { name = type(user.username) == "string" and user.username or "" }
end
```
<!-- /generated -->

Notice:

- This service knows a book by identifiers (`"match_by": "identifiers"`, the default): the app hands
  over ISBNs and the service's own id, never a title or an author of the person's library.
- `pull` reads the whole shelf in pages and hands back `next`, a cursor that the app gives to the next
  call. A script keeps nothing between calls.
- `remote` is the script's own note about a book at the service (its ids there). The app keeps it and
  hands it back with a change.
- It is the longest of the nine, about 400 lines, almost all of it turning one service's shapes into
  the contract's rows.

See [reading-sync.md](reading-sync.md).
