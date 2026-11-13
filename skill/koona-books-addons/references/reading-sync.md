# Reading sync

A reading sync keeps what the person reads in step between Koona Books and a service: a server they
run or name, or an account at a website. The add-on's category is `sync`, and its manifest has one
entry of the type `reading_sync`.

The starter [../templates/sync/addon.json](../templates/sync/addon.json) is a complete reading sync
with a made-up service. Copy its folder and rename it. The included
[KOReader sync](../examples/koreader-sync/sync.lua) and [Hardcover](../examples/hardcover/sync.lua)
add-ons are two real ones.

## What the app keeps, and what your script does

The dangerous half is the app's:

- **Which book is which.** The app decides which of the person's books a row of the service is. Your
  script never pairs a row with a book, and never sees the library.
- **The merge.** The app decides what is newer and which way it goes. The newest reading wins. A state
  that takes a book forward (a further status, or further into the book) is offered ticked; one that
  would take it back is offered unticked and needs its own tick. The same place, give or take a
  percent, is no change. A book never opened there says nothing.
- **The preview.** Sync now reads the service and shows what would change, here and there. Nothing
  changes until the person says Sync.
- **The license.** Sync now and its preview need no license. Taking the changes needs a Koona Books
  license: without one, nothing is changed or sent, the preview stays, and the person is told that
  syncing their reading with a service needs a license, with a button to buy one. The same license
  applies a list importer's changes ([tools.md](tools.md)).
- **Undo.** What changes in the library is one step with its Undo. What was sent to the service stays
  there: Undo does not take it back.
- **When it runs**, how many books go into one call, and the pace of the requests.

Your script does the small foreign half: three functions that speak to the service. `check` says who
the account is, `pull` reads what the service has, `push` writes what changed here.

## How a person sets a sync up

The app draws one of two things for a reading sync, and only these two:

- **An add-on with `sign_in`** gets an **Account** row with **Connect**. The app signs the person in
  through their browser ([Signing in](#signing-in-sign_in)). The Hardcover add-on works this way.
- **Any other** gets a **Sync server** row with **Set up**, which opens a form: the server, the user,
  the password, **Test** and **Save**. The KOReader sync add-on and the starter work this way.

What that means for your manifest:

- **A server the person names, with a user and a password.** This works end to end. The form shows
  the `server` setting first (with its `setting.server.hint` under it), then the `user` and the
  `password` side by side, then every other setting as a plain field of its type, in the manifest's
  order, labeled by `setting.<key>`. **Test** runs your `check` with what was typed and shows the
  name it answers. **Save** keeps the server, the text settings and the secrets, and turns the add-on
  on; it does not run `check`. The server, the `user` and the `password` must be filled in; any other
  setting may be left empty. Left empty on a later change, the password kept is used, but only for the
  same server and the same user: for another one it must be typed again.
- **A sign-in.** This works end to end. The person's settings are not shown anywhere for such an
  add-on: there is no form. `ctx.settings` holds only the defaults of text settings, and a `secret`
  setting is never filled in, so `koona.secret.get` answers `nil` for it.
- **A service on a listed host with only a key in a `secret` setting**, no `server` and no `sign_in`,
  **cannot be set up.** The manifest is accepted, the add-on's page shows **Set up**, and nothing opens:
  the form needs a `server` setting. Such a sync is never set up and never runs. Give it a `server`
  setting, or a sign-in.
- **A sign-in beside a named server** cannot reach the server: the app never asks for the server's
  address for an add-on with `sign_in`, so `ctx.base` is not there and a request to the server is
  refused.

A few more things the form does, which an author would otherwise find out late:

- The server field starts empty for a new account. The `default` of a `server` setting is not put
  into it, and the field's placeholder is the app's own (a KOReader sync server's address).
- `setting.<key>.hint` is shown only for the `server` setting.
- A setting with no `setting.<key>` has no label at all. Give every setting one.

## The manifest

The starter's whole manifest:

<!-- generated:file ../templates/sync/addon.json -->
```json
{
  "schema": 1,
  "id": "org.example.sync-starter",
  "version": "0.1.0",
  "api": 1,
  "min_app": "0.1.0",
  "name": { "en": "Example Shelf" },
  "summary": { "en": "Your reading, in step with your shelf on an Example Shelf server" },
  "glyph": "refresh",
  "category": "sync",
  "author": { "name": "Your Name" },
  "license": "MIT",
  "permissions": {
    "network": {
      "named_server": true,
      "pace": { "per_minute": 60, "burst": 10 }
    },
    "secrets": true,
    "reading_state": true
  },
  "privacy": { "sends": ["reading_state_to_service"], "collects": ["account"] },
  "settings": [
    { "key": "server", "type": "server" },
    { "key": "user", "type": "text", "role": "user" },
    { "key": "password", "type": "secret", "role": "password" }
  ],
  "provides": [
    { "type": "reading_sync", "id": "shelf", "entry": "sync.lua",
      "directions": ["from", "to"], "carries": ["status", "progress", "finished_at"],
      "match_by": "identifiers" }
  ]
}
```
<!-- /generated -->

[manifest.md](manifest.md) holds every key and its rules. What matters for a sync:

- `permissions.reading_state` is required: a reading sync is handed what the person read.
- `privacy.sends` must hold `reading_state_to_service`, because what the person read leaves the
  computer. `privacy.collects` holds `account` when the service keeps an account for the person; with
  `sign_in` it is required.
- `permissions.secrets` is needed for a `secret` setting.

What the person agrees to before the starter runs:

<!-- generated:codes sync -->
```text
network.named_server
provides.reading_sync:shelf
provides.reading_sync:shelf.carries:finished_at
provides.reading_sync:shelf.carries:progress
provides.reading_sync:shelf.carries:status
provides.reading_sync:shelf.direction:from
provides.reading_sync:shelf.direction:to
provides.reading_sync:shelf.match_by:identifiers
reading_state
secrets
collects.account
sends.reading_state_to_service
```
<!-- /generated -->

### Three ways to reach the service

- **`network.hosts`**: a service at fixed hosts on the internet. Every request goes to a host in the
  list.
- **`network.named_server`** with exactly one setting of the type `server`: a server whose address the
  person types. The script finds it as `ctx.base`, such as `https://shelf.example.org` or
  `http://192.168.1.5:8081` (an IPv6 address in brackets), with no path and no `/` at the end. The
  person may type `host`, `host:port`, `https://...` or `http://...`. A server on the internet must
  use `https`; plain `http` is taken only for an address on the person's own network (a numeric
  address, or a name of one label or under `.local`, `.lan`, `.internal`, `.home.arpa`). The app
  checks where the name leads when the person saves it, and keeps that: a name saved as "on the
  internet" that later leads into the person's network is refused (`server_moved`).
- **Both**: the named server and the listed hosts, each by its own rule. A sync without `sign_in`
  that has both is set up through the server's form.

A request anywhere else is refused, and the whole call ends as `denied`.

### `pace`

`network.pace` states the service's request limit: so many a minute, so many at once. A script
cannot wait; the app waits between requests for it, and that wait is not counted in the script's
time. The app keeps one pace for the add-on across all its calls while it runs (what `per_minute`
and `burst` mean exactly is in [manifest.md](manifest.md#permissionsnetwork)). A `429` reaches your
script as it is; it, and a `503` that names seconds in `Retry-After`, make the next turns wait as
long as the service asked. A request whose turn would
come too late is not sent: `koona.http.request` answers it with status `0` and the error `limited`
([limits.md](limits.md) has the longest waits). Pass `limited` on; the Reading row says when the
person can sync again.

### Settings and their roles

- **`server`** (a type, not a role): the address the person names. Needs `named_server`.
- **`user`** (a role, on a `text`): the account's name. The app shows it beside the server ("server ·
  user") and requires it in the form. The app signs nothing in with it: your script does.
- **`password`** (a role, on a `secret`): the secret the form requires beside the user. Kept in the
  system keychain for that server and that user. The app signs nothing in with it either. A
  `password` needs a `user`.
- **A setting with no role** is a plain field of its type in the form, and may be left empty. A text
  one reaches the script in `ctx.settings`; a secret one through `koona.secret.get(key)`, and only
  when it was typed.

Each role at most once. The app finds a setting by its type or its role, never by its key or its
place in the list.

### The entry: `directions`, `carries`, `match_by`

```text
{ "type": "reading_sync", "id": "shelf", "entry": "sync.lua",
  "directions": ["from", "to"], "carries": ["status", "progress", "finished_at"],
  "match_by": "identifiers" }
```

- **`directions`**: `from` (the service tells the library), `to` (the library tells the service), or
  both. With `to` missing, `push` is never called; the preview still lists the books read further
  here, and ticking them sends nothing. The app calls `pull` at every Sync now whatever
  `directions` say, because it must know what the service has before it can tell it anything.
- **`carries`**: what the sync keeps in step, one or more of `status`, `progress`, `finished_at`. The
  person is shown it. The app does not narrow what it reads or sends by it: every row is read whole,
  and every change carries what the app has. Name what your service really keeps, and write only that.
- **`match_by`**: how the service knows a book, `identifiers` (the default) or `document`. The next
  section.

## Two ways of knowing a book

What a book is known by decides what crosses to your script, and what `key` is.

**By document** (`"match_by": "document"`, KOReader's sync). The service knows a book by a digest of
its file. The app knows that digest only for a copy it sent to a reader itself, and works it out
itself.

- `ask.books` holds the books to ask about, and each book's `key` is the digest. Nothing else of the
  book is handed over: no title, no author, no file name, no identifier.
- Your `pull` asks the server about each key and answers a row for each one it found, with that
  `key`. A row with a key that was not asked for, or with no key, is left out. `title`, `authors` and
  `identifiers` of a row are not read.
- A change's `key` is the digest, its `identifiers` are empty, and it carries no `remote`.
- A book read here that was never sent to a reader by Koona Books has no digest, and is not synced.

**By identifiers** (`"match_by": "identifiers"`, Hardcover's, the starter's). The service has a shelf
of the person's, and knows a book by its ISBN or by its own id.

- `ask.books` is always empty: the app asks about no book. Your `pull` answers for the person's
  **whole** shelf at the service, a page at a time.
- A row names its book by `identifiers`. **The app pairs a row with a book only by its ISBN** (either
  form; the app compares them as ISBN-13), and by Hardcover's own kinds (`hardcover`,
  `hardcover-edition`, `hardcover-entry`). The ids of any other service (`goodreads = { "123" }`, your
  service's own id) are kept with the row but pair nothing, now or at a later sync. An ISBN that more
  than one book of the library holds pairs with none of them.
- A row with no identifiers at all is left out, whatever its title says.
- A row may carry the service's `title` and `authors`. They never pair a book by themselves: a row that
  is kept, pairs with nothing, says something of the reading (`reading` or `finished`), and whose title
  and author match exactly one book, is shown as "Looks the same", and pairs only when the person ticks
  it. So a row with no ISBN but another identifier (your service's own id) is kept and may be offered
  as "Looks the same"; the same row with no identifier at all is not. Give every row the service's own
  id as an identifier, and its ISBN whenever the service has one.
- A change's `key` is the app's own handle for the book (a number as text). Its `identifiers` are what
  the service may find the book by: the book's ISBNs as ISBN-13, and its `hardcover` id when it has
  one, each only when no other book of the library has it. No title, no author and no file name is handed to the script.
- A change carries back the `remote` of the row it was paired with in this look; a book not on the
  shelf there has none.

## The script

The starter's whole script:

<!-- generated:file ../templates/sync/sync.lua -->
```lua
-- Example Shelf: keeps reading in step with a shelf on a server the person names. The service
-- is made up; its API is the smallest one a reading sync needs:
--   GET  /api/v1/me                    -> { name }, or 401
--   GET  /api/v1/shelf?after=<cursor>  -> { books = { entry, ... }, next = "<cursor>" or null }
--   PUT  /api/v1/shelf/<id>            { state, percent, finished_on } -> { id }
--   POST /api/v1/shelf                 { isbn, state, percent, finished_on } -> { id }, or 404
-- An entry: { id, isbn, title, authors, state = "want" | "reading" | "finished" | "dropped",
--             percent = 0-100, updated_at = "<RFC 3339>", finished_on = "YYYY-MM-DD" }.
--
-- Koona Books keeps the hard half: which book is which, the merge, the preview, Undo. This
-- script only speaks to the server.

local s = {}

-- The sign-in header, or nil and a code. The user is a setting (`ctx.settings`); the password
-- is a secret, which never is: it is asked for here and goes out only in this header.
local function auth(ctx)
  local user = ctx.settings.user
  local password = koona.secret.get("password")
  if not user or not password or password == "" then return nil, "not_set_up" end
  return { ["authorization"] = "Basic " .. koona.base64.encode(user .. ":" .. password),
           ["accept"] = "application/json" }
end

-- One request to the server. Returns the decoded answer, or nil and a code.
local function call(ctx, method, path, body)
  local headers, why = auth(ctx)
  if not headers then return nil, why end
  if body then headers["content-type"] = "application/json" end
  local r = koona.http.request{
    method = method, url = ctx.base .. path, headers = headers, timeout = 20,
    body = body and koona.json.encode(body) or nil,
  }
  -- Status 0: no answer came. The host says why (`unreachable`, `timeout`, `limited`...):
  -- pass its code on as it is, and the app has words for it.
  if r.status == 0 then return nil, r.error or "unreachable" end
  if r.status == 401 then return nil, "bad_login" end
  if r.status == 429 then return nil, "limited" end
  if r.status == 404 then return nil, "not_found" end
  if r.status >= 500 then return nil, "unreachable" end
  if r.status >= 300 then return nil, "not_a_server" end
  -- A write that is done with nothing to say (a 204, or a 200 with no body) is an empty
  -- answer, not a failure. A read with nothing in it is no answer of this service's.
  if method ~= "GET" and (r.body or "") == "" then return {} end
  local ok, value = pcall(koona.json.decode, r.body)
  if not ok or type(value) ~= "table" then return nil, "not_a_server" end
  return value
end

-- "Test" in the server's form: who the account is. The name is shown to the person.
function s.check(ctx)
  local me, why = call(ctx, "GET", "/api/v1/me")
  -- No such page: the address leads somewhere, but not to this service.
  if not me then return { error = why == "not_found" and "not_a_server" or why } end
  -- An answer with no name in it came from something else at this address.
  if type(me.name) ~= "string" then return { error = "not_a_server" } end
  return { name = me.name }
end

-- The service's words for where a book stands, as the app's.
local STATUS = { want = "unread", reading = "reading", finished = "finished", dropped = "set_aside" }

-- One entry of the shelf as a row. By identifiers the app asks about no book of its own:
-- a row names the book by what the service knows of it, and the app pairs it.
local function row(e)
  local status = STATUS[e.state]
  if not status or type(e.id) ~= "number" then return nil end
  local says = status == "reading" or status == "finished"
  -- The app pairs a row with a book by its ISBN only. The shelf's own id pairs nothing, but a
  -- row with no identifier at all is left out: with it, an entry that has no ISBN is still
  -- kept, and may be offered to the person as "Looks the same" by its title and authors.
  local identifiers = { example_shelf = { tostring(e.id) } }
  if type(e.isbn) == "string" then identifiers.isbn = { e.isbn } end
  return {
    identifiers = identifiers,
    -- For the person to compare, when no ISBN pairs the row with a book.
    title = type(e.title) == "string" and e.title or nil,
    authors = type(e.authors) == "table" and e.authors or nil,
    status = status,
    progress = status == "reading" and type(e.percent) == "number" and e.percent / 100 or nil,
    -- A time only when the row says something of the reading.
    read_at = says and e.updated_at or nil,
    finished_at = status == "finished" and e.finished_on or nil,
    -- The script's own note: handed back with a change of this book.
    remote = { id = e.id },
  }
end

-- The whole shelf, a page at a time: the app calls again with `next` as `ask.cursor`.
function s.pull(ctx, ask)
  local path = "/api/v1/shelf"
  if ask.cursor then path = path .. "?after=" .. koona.url.encode(ask.cursor) end
  local page, why = call(ctx, "GET", path)
  -- `not_found` is the word for one book the service does not know. No shelf at this address
  -- is another thing: this is not the server.
  if not page then return { error = why == "not_found" and "not_a_server" or why } end
  local rows = {}
  for _, e in ipairs(type(page.books) == "table" and page.books or {}) do
    rows[#rows + 1] = type(e) == "table" and row(e) or nil
  end
  return { rows = rows, next = type(page.next) == "string" and page.next or nil }
end

-- The app's words for where a book stands, as the service's: the same table, the other way.
local STATE = {}
for theirs, ours in pairs(STATUS) do STATE[ours] = theirs end

-- A change as the server writes it.
local function body_of(change)
  return {
    state = STATE[change.status],
    percent = change.progress and math.floor(change.progress * 100 + 0.5) or nil,
    finished_on = change.finished_at and change.finished_at:sub(1, 10) or nil,
  }
end

-- Sends changes, one request each. Every change gets a result with its `key`.
function s.push(ctx, changes)
  local results = {}
  for i, change in ipairs(changes) do
    local body, done, why = body_of(change), nil, nil
    local id = type(change.remote) == "table" and change.remote.id
    if id then
      done, why = call(ctx, "PUT", "/api/v1/shelf/" .. tostring(id), body)
    else
      -- Not on the shelf yet: added by its ISBN, the one thing the app hands over for it.
      local isbns = type(change.identifiers) == "table" and change.identifiers.isbn
      body.isbn = type(isbns) == "table" and isbns[1] or nil
      if body.isbn then
        done, why = call(ctx, "POST", "/api/v1/shelf", body)
      else
        why = "not_found"
      end
    end
    if done then
      -- The note for this book: its id on the shelf. An add that answered with no id leaves
      -- no note; the next pull brings the entry with its id, paired by the ISBN.
      local now = type(done.id) == "number" and done.id or id
      results[#results + 1] = { key = change.key, remote = now and { id = now } or nil }
    elseif why == "limited" or why == "bad_login" or why == "unreachable" or why == "timeout" then
      -- The server stops taking changes: what was sent stands, the rest waits for later.
      results[#results + 1] = { key = change.key, error = why }
      return { results = results, stopped = why }
    else
      results[#results + 1] = { key = change.key, error = why }
    end
    koona.progress(i, #changes)
  end
  return { results = results }
end

return s
```
<!-- /generated -->

Every function answers a table. One that could not do its job answers `{ error = "<code>" }`, the
code being `a-z`, `0-9` and `_`, starting with a letter. Anything else is success. A function that
raises an error, answers something that is not a table, or answers one of the app's own codes, is the
add-on's failure (`broken`).

### `ctx`

```text
ctx = { id = "shelf",                                   -- the entry's id
        settings = { user = "sam" },                  -- every setting but the secrets
        base = "https://shelf.example.org",             -- the server the person named, when there is one
        client = { id = "...", name = "Koona Books" } } -- this computer at the service
```

- `settings` holds each text setting as the person typed it, without spaces at either end; one left empty takes its `default`, or is
  not there. A secret is never in `ctx`: ask for it with `koona.secret.get(key)`.
- `base` is there only for an add-on with a named server, once the person saved one.
- `client.id` is an id the app made for this computer and this add-on, the same in every call. Send it
  where a service wants to know which device wrote a state, and compare a row's device with it: a
  state this computer wrote itself is not a reading (see [Times](#times)). `client.name` is the app's
  name, never the person's.

### `check(ctx)`

```text
check(ctx) -> { name = "sam" }        -- name is optional
           or { error = "<code>" }
```

Asks the service whether the account is there and who it is. The app calls it at **Test** in the
server's form (with the secrets as typed and not kept yet; one left empty is the one kept), right
after a sign-in, and, for a sign-in, at a later Sync now while the account's name is not known. The `name` is shown: "signed in as sam", "Connected as
@sam".

### `pull(ctx, ask)`

```text
pull(ctx, ask) -> { rows = { row, ... }, next = "<cursor>" or nil, stopped = "<code>" or nil }
ask = { books = { book, ... }, cursor = "<cursor>" or nil }
book = { key = "...", identifiers = { ... } }

row = { key = "...",                          -- by document: the book asked about
        identifiers = { isbn = { "978..." } }, -- by identifiers: what the service knows it by
        title = "...", authors = { "..." },    -- by identifiers: the service's words, to compare
        status = "reading",                    -- "reading" | "finished" | "unread" | "set_aside"
        progress = 0.62,                       -- 0 to 1
        read_at = "2026-11-09T18:23:11Z",      -- or seconds since 1970
        finished_at = "2026-11-07",
        remote = { ... } }                     -- your own note about the book there
```

- **`rows`** is the answer's list. A row the app cannot use is left out quietly: a `status` it does
  not know, nothing to tell which book it is, a `progress` outside 0 to 1 (just the progress). Of two
  rows for one asked book, the first is kept.
- **`next`** and the cursor: by identifiers, a shelf of more than one page answers `next`, a text of
  your own (up to the cap in [Limits](#limits)). The app calls `pull` again with it as `ask.cursor`,
  until a page answers no `next`. A cursor it was given before ends the reading, as does too many pages:
  the app reads at most 200 pages and keeps at most 50,000 rows in one look. A shelf not read to its
  end is shown as incomplete, and nothing is offered to be sent on the strength of it. By document,
  `next` is not used.
- **`stopped`**: the script stopped part-way and says why (`limited`, `unreachable`, `bad_login`).
  The rows are what it found before that. The app asks no more in this look.
- **`remote`**: your note about the book at the service (its id there, a page count), as a table. The
  app keeps it with the book and hands it back with a change. It means nothing to the app.

### `push(ctx, changes)`

```text
push(ctx, changes) -> { results = { result, ... }, stopped = "<code>" or nil }
change = { key = "...", identifiers = { isbn = { "978..." } }, remote = { ... },
           status = "reading", progress = 0.42,
           read_at = "2026-11-12T08:00:00Z", finished_at = "2026-11-11T12:00:00Z" }
result = { key = "...", remote = { ... }, identifiers = { ... } }   -- a change made
      or { key = "...", error = "<code>" }                           -- a change not made
```

- A change's `status` is `reading` or `finished`: the app never sends `unread` or `set_aside`.
  `progress` is there for a book being read, `finished_at` for a finished one. `remote` is what your
  `pull` noted of the book, when it had a row.
- **A result with a `key` and no `error`** is a change made. Its `remote` replaces the note kept for
  the book. Its `identifiers` are what the book is known by at the service now: by identifiers, write
  the entry you just added, so the next `pull` pairs it with the book and it is never added twice.
- **A result with an `error`** is a change not made, for that reason.
- **A change no result names** is not sent: `no_answer`, or, when the answer says `stopped`, that code.
  Of two results for one key, the first is kept.
- **`stopped`**: the service stopped taking changes (it asks to wait, the password changed, the
  connection went). The results before it stand; the app sends no more for now.

### Times

`read_at` and `finished_at` of a row are text as the service wrote it, or a number of seconds since
1970. The app reads text as a time when it is RFC 3339 (any offset, any fraction, a space for the `T`,
or no zone, which is UTC) or a bare day (`2026-11-07`, taken as its noon in UTC). Text of any other
shape is no time, and so is a number before 1970. A time in the future is no time either. A row with no
`read_at` is newer only than a book that has no reading time here.

`read_at` is when the book was read there. It must not be when this computer wrote it there: that
would look newer than what was read here since. By identifiers the app knows what it last told the
service of each book, and takes a row that says the same back without its time. By document it does
not: compare the device the service names with `ctx.client.id`, and leave `read_at` out for a state
this computer wrote, as the KOReader sync add-on does.

The times of a change are RFC 3339 in UTC. Take the first ten characters for a day.

### Statuses

- **`reading`** and **`finished`** say how far the book was read.
- **`unread`**: on the shelf there with nothing read (a book the person means to read). It says nothing
  of the reading, but the app now knows the book is there: it is never added a second time, and it is
  told of a reading here.
- **`set_aside`**: the person set it aside there (did not finish, ignored): their own word. It says
  nothing, and the app never tells the service anything of that book.

Neither `unread` nor `set_aside` is offered as "Looks the same".

### How many books one call gets

Every call has a cap ([Limits](#limits)), and a call makes a limited number of requests
([limits.md](limits.md)). So the app hands a call no more than it can do one request at a time: by
document, 40 books to `pull` and 40 changes to `push`; by identifiers, 25 changes to `push`. A
`pull` by identifiers is asked about no book, and pages the shelf with `next`.

## Failures and their words

Pass on the codes `koona.http.request` answers with (`unreachable`, `timeout`, `tls`, `limited`,
`signed_out`), as they are ([host-api.md](host-api.md)). Never answer one of the app's own codes: that
is `broken` ([words.md](words.md)).

The app words a code by who said it. A code the app produced has the app's words, always: here
`server_moved`, `denied`, `cancelled`, `limits`, `broken`, `incomplete` (a shelf not read to its end)
and `no_answer`. A code your script said has your own `error.<code>` first, else the app's words for
that code when it has some, else the app's one sentence ("The add-on could not do this").

The app has words for these codes of a script's, in three places:

| Where | Codes |
| --- | --- |
| A Sync now that failed, on the Reading row | `unreachable`, `timeout`, `tls`, `bad_user`, `limited`, `refused`, `scope`, `not_set_up`, `not_a_server`; `signed_out` and `bad_login` are said on the account's row instead |
| **Test** in the server's form | `unreachable`, `timeout`, `tls`, `bad_login`, `bad_user`, `not_a_server`, `not_set_up` |
| One change not sent | `not_found`, `set_aside`, `already_read`, `no_place`, `refused`, `limited` |

Two codes do more than say something:

- **`bad_login`** from any call ends the account. For a server, the row says the server no longer
  takes this user and password, and the password must be typed again.
- **`signed_out`** ends a sign-in: the row asks the person to connect again. When no new token could
  be had because the service did not answer, the app says `unreachable` instead and keeps the sign-in.

Say `bad_login` only when the service refused the user and the password, and `signed_out` only when it
refused the sign-in.

## Signing in (`sign_in`)

For a service with OAuth 2, the app signs the person in for the add-on. A script cannot listen for
the browser's way back, and a token in a script's hands could leave by a request or a log line, so
the app does all of it. The manifest's keys are in [manifest.md](manifest.md). A sign-in in place of
the starter's server:

<!-- sample:manifest-part sync -->
```json
{
  "permissions": {
    "network": { "hosts": ["api.example.org"], "pace": { "per_minute": 60, "burst": 10 } },
    "reading_state": true,
    "sign_in": {
      "kind": "oauth2_pkce",
      "issuer": "https://api.example.org",
      "authorize": "https://example.org/oauth/authorize",
      "token": "https://api.example.org/oauth/token",
      "revoke": "https://api.example.org/oauth/revoke",
      "client_id": "your-client-id",
      "scopes": ["read:shelf", "write:shelf"]
    }
  },
  "settings": []
}
```

The rules the manifest is held to:

- `kind` is `oauth2_pkce`. `issuer`, `authorize`, `token`, `client_id` and `scopes` are required;
  `revoke` is not.
- Every address is `https`, with no query, no fragment, no port, no user in it, and a host that is one
  internet name.
- `issuer` is written exactly `https://` and the host: no path, not even a `/` at the end. The browser's
  way back is compared with it as text.
- `token` and `revoke` are under the issuer (`https://api.example.org/...`). `authorize` may be on
  another host.
- The issuer's host must be one that `network.hosts` matches, so the person sees it among the places
  the add-on reaches. Otherwise:

<!-- sample:manifest-refused sync permissions.sign_in.issuer -->
```json
{
  "permissions": {
    "network": { "hosts": ["api.example.org"] },
    "reading_state": true,
    "sign_in": {
      "kind": "oauth2_pkce",
      "issuer": "https://login.example.org",
      "authorize": "https://login.example.org/authorize",
      "token": "https://login.example.org/token",
      "client_id": "your-client-id",
      "scopes": ["read:shelf"]
    }
  },
  "settings": []
}
```

- `privacy.collects` holds `account`.
- `client_id` is your own, registered at the service. An add-on whose `client_id` is one of Koona's own
  add-ons' is refused.

**What the service must do.** It must take a public client (no client secret) with PKCE (`S256`), and
send the browser back to `http://127.0.0.1:<port>/callback`, the port being one the system picks for
each sign-in: register a loopback address with any port and the path `/callback`. The way back must
carry `iss`, the issuer, as well as `code` and `state` (RFC 9207); a service that does not send `iss`
cannot sign anyone in. The token answer is JSON with `access_token` (and `token_type` `bearer`, when
it names one), and may give `expires_in` and `refresh_token`. With no refresh token, the person
connects again when the token runs out.

**What the person sees.** The Account row says "Not connected" with **Connect**. Connect opens the
`authorize` page in their browser and a dialog, "Approve in your browser", with **Copy the link** for a
browser that did not open. The app waits five minutes at most. Approved, the app trades the code for
the tokens, keeps them in the system keychain, calls your `check`, and turns the add-on on: the row
says "Connected as @sam", or "Connected" when `check` named no one. A no in the browser, or no answer
in time, is said under the row; nothing is connected. **Disconnect** ends the sign-in at the service
(at `revoke`, when there is one), forgets the tokens and turns the add-on off.

**The token.** Your script never sees one. The app adds `authorization: Bearer <token>` to every
request that goes to the issuer's host itself, by `https`, with no port in the address, and to no other
host. A script of an add-on with `sign_in` may not set an `authorization` or a `cookie` header itself,
to any host: `koona.http.request` raises an error. An answer that echoes the token has it replaced
by a mark. The app trades the refresh token for a new one shortly before the token runs out.

**A 401.** When the service answers `401` to a request that carried the token, the app trades for a
new token and sends the request again, once in one call. A later `401` in the same call reaches your
script as it is: answer `signed_out`. When the person is not signed in any more (the refresh token was
refused), a request to the issuer's host is not sent, and `koona.http.request` answers status `0` with
the error `signed_out`.

## Words

The add-on's own words are keys of its locale files ([words.md](words.md)). The keys a reading sync
has:

| Key | Where it shows |
| --- | --- |
| `sync.<id>.setup` | The title of the server's form ("Example Shelf server"). Without it, the add-on's name |
| `sync.<id>.how` | The first line of the server's form: what to type and where to find it |
| `setting.<key>` | A field's label in the server's form |
| `setting.<key>.hint` | The line under the server's field. Read for the `server` setting only |
| `error.<code>` | Your words for a code your script says, everywhere the code shows |

All of them show only in the server's form, apart from `error.<code>`: an add-on with `sign_in` has no
form, and its `sync.<id>.setup`, `sync.<id>.how` and `setting.<key>` are never shown. In an
`error.<code>`, `{address}` is replaced by the server as the person named it; words that hold
`{address}` are not used where there is none.

The starter's words:

<!-- generated:file ../templates/sync/locales/en.json -->
```json
{
  "does": "Keeps what you are reading and what you have read in step with your shelf on an Example Shelf server, both ways. Books are matched by ISBN.",
  "changes": "First version",
  "sync.shelf.setup": "Example Shelf server",
  "sync.shelf.how": "Use the server, user and password you sign in to Example Shelf with.",
  "setting.server": "Server",
  "setting.server.hint": "The address of your Example Shelf server, such as shelf.example.org",
  "setting.user": "User",
  "setting.password": "Password",
  "error.bad_login": "The server does not know this user and password",
  "error.not_a_server": "Something answers at {address}, but it is not an Example Shelf server"
}
```
<!-- /generated -->

## Limits

<!-- generated:limits-sync -->
| Limit | Value |
| --- | --- |
| Rows of one `pull`, results of one `push` | 500 |
| A book's `key` | 128 bytes |
| One identifier | 64 bytes |
| Kinds of identifier, and values of one kind | 8 each |
| `remote`, as JSON | 2,048 bytes |
| `next`, the cursor | 512 bytes |
| `read_at`, `finished_at` as text | 40 characters |
| A row's `authors` | 8 |
| A row's `title`, an author, the account's `name` | 200 characters |
<!-- /generated -->

A call into a reading sync has the time in [limits.md](limits.md), its requests one after another;
each request keeps its own time, and a wait for the pace is not counted.

What the app does with an answer over these caps:

- **Rows past the cap** of one `pull`, and results past it of one `push`, are left out without a
  word. Page a longer shelf with `next`. A change whose result was left out counts as not sent
  (`no_answer`).
- **A text that is shown** (`title`, an author, the account's `name`) is cut to its cap. Authors past
  their number are left out.
- **A value that is not shown** is dropped, not cut, and the row stays: an identifier over its cap or
  holding a space or a character outside visible ASCII, kinds or values past their number, a
  `read_at` or `finished_at` text over its cap or not ASCII (the row then has no such time), a
  `remote` over its cap as JSON (the row or the result then has no note).
- **A cursor** that is not text, or is over its cap, is the add-on's failure (`broken`): a `next` the
  app cannot hand back would end the reading half-way.
- The answer as a whole is held to the caps of a value ([limits.md](limits.md#values)); over them the
  call is `broken`.

**When to answer `stopped`.** Say `stopped` in a `pull` or a `push` with a code that means nothing more
will work now: the service asks to wait (`limited`), it cannot be reached (`unreachable`, `timeout`,
`tls`), or it no longer takes the account (`bad_login`, `signed_out`). The app then asks no more in
this look. A code that is about one book (`not_found`, `already_read`) goes in that book's result, and
the next change is tried.

## Testing it

[testing.md](testing.md) says how to load the folder in Koona Books and read the add-on's log.
