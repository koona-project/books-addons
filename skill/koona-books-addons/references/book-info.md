# Book information: details and covers from a catalog

An add-on of the category `info` is a source for Find information and Find cover. When the person
asks about a book, the app asks your script about it, and your script asks a catalog on the internet
and says what it found: **candidates**, each one edition in one language, and **links** to covers.

Koona Books does everything else: which sources to ask and in what order, matching and ranking the
candidates against the book, the comparison the person sees, what is written to the library when
they choose, and fetching every picture. Your script never sees the library, never writes to it, and
never fetches a cover for the app.

The starter [`../templates/info/`](../templates/info/addon.json) asks a made-up JSON service by ISBN
or by title and author. The included Open Library add-on
([`../examples/openlibrary/info.lua`](../examples/openlibrary/info.lua)) does the same against
openlibrary.org.

## The manifest

<!-- generated:file ../templates/info/addon.json -->
```json
{
  "schema": 1,
  "id": "org.example.info-starter",
  "version": "0.1.0",
  "api": 1,
  "min_app": "0.1.0",
  "name": { "en": "Info starter" },
  "summary": { "en": "Book information and covers from the Example catalog" },
  "glyph": "search",
  "category": "info",
  "author": { "name": "Your Name" },
  "license": "MIT",
  "permissions": {
    "network": {
      "hosts": ["api.example.org"],
      "pace": { "per_minute": 30, "burst": 2 }
    },
    "book_query": true
  },
  "privacy": { "sends": ["book_details_to_service"], "collects": [] },
  "provides": [
    { "type": "book_info", "id": "example", "entry": "info.lua",
      "languages": ["*"], "finds_by": ["isbn", "title_author"], "finds": ["info", "covers"] }
  ]
}
```
<!-- /generated -->

What the person agrees to when they add it, as codes (the words the app shows for each are in
[permissions.md](permissions.md)):

<!-- generated:codes info -->
```text
book_query
network.host:api.example.org
provides.book_info:example
provides.book_info:example.finds_by:isbn
provides.book_info:example.finds_by:title_author
sends.book_details_to_service
```
<!-- /generated -->

- **`category`** is `info`, and every entry is a `book_info`.
- **`permissions.network.hosts`** is required: the catalog is at hosts the manifest lists. A source of
  book information is never given a server the person names, or a reader on their network: both
  `named_server` and `local_device` are refused.
- **`permissions.book_query`** must be `true`: it is the permission to be handed a question about a
  book. It is allowed only for book information.
- **`privacy.sends`** must hold `book_details_to_service`: what the app hands over about the book goes
  to the catalog. A manifest without it is refused, and so is the code without `book_query`.
- **No settings and no secrets.** A manifest of book information may name neither: nothing draws a
  form for them, `ctx.settings` is always an empty table, and `koona.secret.get` answers `nil`. A
  catalog that needs a key of the person's cannot be a source of book information today.
- **`pace`** is optional. See [The pace](#the-pace) below.

A source of one language that only finds covers, and only by ISBN:

<!-- sample:manifest-part info -->
```json
{
  "provides": [
    { "type": "book_info", "id": "example", "entry": "info.lua",
      "languages": ["ru"], "finds_by": ["isbn"], "finds": ["covers"] }
  ]
}
```

A setting is refused:

<!-- sample:manifest-refused info settings -->
```json
{
  "settings": [ { "key": "api_key", "type": "text" } ]
}
```

So is a secret:

<!-- sample:manifest-refused info permissions.secrets -->
```json
{
  "permissions": {
    "network": { "hosts": ["api.example.org"] },
    "book_query": true,
    "secrets": true
  }
}
```

And a server the person names:

<!-- sample:manifest-refused info permissions.network.named_server -->
```json
{
  "permissions": {
    "network": { "hosts": ["api.example.org"], "named_server": true },
    "book_query": true
  }
}
```

A manifest that leaves out `book_query` is refused at its privacy line, which says the book's details
go to the service and so needs the permission to be handed them:

<!-- sample:manifest-refused info privacy.sends[0] -->
```json
{
  "permissions": { "network": { "hosts": ["api.example.org"] } }
}
```

And one that has `book_query` but does not say the details leave the computer is refused at
`privacy.sends`:

<!-- sample:manifest-refused info privacy.sends -->
```json
{
  "privacy": { "sends": [], "collects": [] }
}
```

### The entry

| Field | What it says |
| --- | --- |
| `languages` | The languages the catalog is good at, as tags (`en`, `ru`, `pt-BR`), or `["*"]` alone for a catalog of the world. `*` beside a tag is refused |
| `finds_by` | How it can look a book up: `isbn`, `title_author`, or both |
| `finds` | What it finds: `info`, `covers`, or both |

<!-- sample:manifest-refused info provides[0].languages -->
```json
{
  "provides": [
    { "type": "book_info", "id": "example", "entry": "info.lua",
      "languages": ["*", "en"], "finds_by": ["isbn"], "finds": ["info"] }
  ]
}
```

The app reads the entry without running anything:

- **Which sources are asked.** For Find information, every source that is on, finds `info` and can
  look the book up: by its ISBN when the book has one and `finds_by` holds `isbn`, or by its title when
  the book has one and `finds_by` holds `title_author`. For Find cover, the same with `covers`. A
  source that cannot look the book up is not asked at all.
- **In what order.** A source that names one of the book's languages first, then a catalog of the
  world (`*`), then a source that names none of them. A source of another language is still asked,
  last. When the app looks up many books at once, it stops asking more sources about a book once one
  has found a candidate it trusts.

## The pace

A source of book information is never asked faster than the app's own cap, whatever its manifest
says: the cap is in [limits.md](limits.md) ("Book information, whatever the manifest's pace"). The
manifest's `pace` holds when it is slower than that cap, and is cut to it when it is faster. A
manifest with no `pace` is asked at the cap's rate, one request at a time.

The pace is kept for the add-on across all its calls, not per call: a search, the next search, the
details and the app's own fetches of the add-on's covers all wait on the one pace. A request waits for
its turn; your script does not wait, and cannot. A `429` answer makes the pace wait for its
`Retry-After` ([host-api.md](host-api.md)).

## `ctx` and the three functions

```text
search(ctx, query)      -> { rows = { candidate, ... } }
details(ctx, candidate) -> candidate                     optional: the same one, filled in
covers(ctx, query)      -> { rows = { { url, width, height }, ... } }
each, when it could not: { error = "<code>" }

ctx = { id = "<the source's id>", settings = {} }        -- settings always empty
```

- **`search`** is required when `finds` holds `info`, and called only then. Its answer is
  `{ rows = { ... } }`; an answer with no `rows`, or a bare list, is the add-on's failure (`broken`).
  `{ rows = {} }` is "found nothing". The candidates are kept in your order, up to the cap; one with
  no title is left out.
- **`details`** is optional. When the person opens a candidate to compare it with the book, the app
  hands it back to `details`, once, and takes what comes back in its place. A script with no
  `details` leaves the candidate as `search` gave it. A `details` that fails leaves it so too, and
  the comparison is still shown.
- **`covers`** is required when `finds` holds `covers`, and called only then. Its answer is
  `{ rows = { ... } }` of links, kept in your order up to the cap, each address once.

The rules every point shares (an answer is a table; `{ error = "<code>" }` is a failure; the app's own
codes are never a script's) are in [words.md](words.md).

The app keeps your answers while it runs: the same question about the same book, to the same version
of your add-on, is answered from what your script said before, and your script is not asked again. A
failure is not kept.

## The query

The query is what the app knows of one book, cleaned and cut, and never a file. It is the same for
`search` and `covers`.

```text
query = { title = "Dune",
          authors = { "Frank Herbert" },
          identifiers = { isbn = { "9780441013593" } },
          languages = { "en" },
          want = { "en", "ru" } }
```

| Field | What it holds |
| --- | --- |
| `title` | The book's title, cleaned and cut. `""` when the book has none (it is then asked by ISBN only) |
| `authors` | The names of its authors, in the book's order: authors only, no translator or editor. May be empty |
| `identifiers` | `{ isbn = { "<isbn>" } }` with the book's first valid ISBN, digits only (a ten-digit one may end in `X`); an empty table when it has none |
| `languages` | The book's own languages, as tags. May be empty |
| `want` | The languages to answer in, best first: the book's languages, then the reading languages the person set in Settings, then the app's language when neither names one. Tags, each once |

**What the query never holds:** any identifier but the ISBN (not the library's own, not another
service's), the tags, the series, the description, a file, a path, the library's name, or anything
of the person beyond the reading languages in `want`. Each list is cut to its cap (below).

A language is a BCP 47 tag (`ru`, `pt-BR`). A catalog that speaks three-letter codes gets one from
`koona.lang.code3(tag)` (with `"b"`, the bibliographic one some library catalogs use), and gives a
tag back from what it says with `koona.lang.tag(code)`; both answer `nil` for what is no language
([host-api.md](host-api.md)):

<!-- sample:returns ["ru","de","rus","ger",true] -->
```lua
return {
  koona.lang.tag("rus"),
  koona.lang.tag("ger"),
  koona.lang.code3("ru"),
  koona.lang.code3("de", "b"),
  koona.lang.tag("und") == nil,  -- "undetermined" is no one language
}
```

## The candidate

```text
candidate = { title, subtitle, language,
              original = { title, language },
              other_titles = { en = "...", de = "..." },
              authors = { { name, role, also = { en = "..." } }, ... },
              description, publisher, published,
              series = { name, index }, tags = { ... },
              identifiers = { isbn = { "..." }, <the source's id> = { "..." } },
              cover = { url, width, height }, page = "<url>", note = "<the script's own>" }
```

**Nothing a script says is taken as it is.** Every text is cleaned (no control or invisible character,
nothing that turns a line around, spaces run together, never a space at either end) and cut to its
cap; every list is cut; a language is a tag or nothing; a number is one or nothing; a field of the
wrong type is left out. The caps are in the table at the end of this page.

| Field | How the app takes it |
| --- | --- |
| `title` | Required: a candidate with no title after cleaning is left out |
| `subtitle` | Text |
| `language` | The language of this title, description and tags. Read with the rule of `koona.lang.tag`: `eng` becomes `en`; what is no language is left out |
| `original` | `{ title, language }`: the title the book was first printed under, only when the catalog says so |
| `other_titles` | The title in other languages: `{ <language> = "<title>" }`, or a plain list of titles in no named language. A key that is no language makes that title one in no language. A title that is the candidate's own title is left out; each stands once. Shown as such, never put in place of the book's own title |
| `authors` | A list of `{ name, role, also }`. `role` is `author`, `translator`, `editor` or `illustrator`; none is `author`. **A person with any other role is left out**, never made an author. The same name in the same role stands once. `also` is the same person's name in other languages and scripts, in the shape of `other_titles` |
| `description` | Text of several lines: each line cleaned, runs of empty lines made one empty line, cut. The app then treats it as a book's own description: markup is dropped and it is cut again to what the library keeps |
| `publisher` | Text |
| `published` | A date as the app reads one in a book's file: `YYYY`, `YYYY-MM` or `YYYY-MM-DD` at the start of the text, a year before 1000 being none. Anything else (`March 1, 2017`) is no date; turn it into one with `koona.date.parse` |
| `series` | `{ name, index }`; `index` a number of 0 or more. A series with no name is left out |
| `tags` | A list of texts, each once |
| `identifiers` | `{ <kind> = { "<value>", ... } }`, a list of texts for each kind, also for one value. A kind whose value is not a list of texts is left out; `isbn` is read first. Of what is kept, the app writes an ISBN (hyphens allowed) only when its check digit is right, and **any other kind only when the kind is this source's own `id`** in the manifest (the starter's is `example`): an add-on never writes another service's identifiers |
| `cover` | `{ url, width, height }`, by the rules of a cover below |
| `page` | The record's page at the catalog, for the person's browser: any `http` or `https` address with no user name in it. The app never asks for it |
| `note` | Your own text (which record this is), handed back to `details` and read by nobody else. Kept as you wrote it, not cleaned, when it is not empty and not over its cap |

A candidate is **one edition in one language**: the title, the description and the tags of one
language, with `language` saying which. A record that holds several languages is several candidates,
or one in the language that `want` puts first.

### What `details` is handed

The candidate as the app took it from `search`, rebuilt from what it kept: every field above that has
something in it, `note` among them. Lists by language come back as `{ <language> = "..." }` when each
has a language, else as a plain list. `details` answers a whole candidate, with the same rules: give
back what you were handed with your fields added, as the starter does. A `details` answer with no
title is the add-on's failure (`broken`).

## Covers

A cover is `{ url, width, height }`: a link to a picture, and the size the catalog claims for it in
pixels (each a whole number from 1 to 100,000, or nothing; a claim is not trusted, the app measures
the picture).

**A cover's address must be one the add-on itself may reach, a host its manifest lists, or it is no
cover**: the app drops it, in a candidate's `cover` and in the rows of `covers`. A catalog whose
pictures are on another host lists that host too (Open Library lists `covers.openlibrary.org` and
`archive.org`, where its pictures redirect). The app fetches each picture itself, through the same
rule, at the add-on's pace and with its own caps; a redirect out of the listed hosts is not followed.
A picture too narrow to be a cover is refused, and the person is told why.

## Failures and their words

A function that could not do its job answers `{ error = "<code>" }`. Pass on the code `koona.http`
gave as it is, and use these where they fit, since the app has words for them at this point:

| Code | Say it when |
| --- | --- |
| `unreachable`, `timeout`, `tls` | The code `koona.http` gave (`status = 0`) |
| `not_found` | The catalog answers that there is no such record (a `404`) |
| `limited` | The catalog asks you to slow down (a `429`, a `503`) |
| `refused` | The catalog would not answer the request |
| `not_understood` | It answered with something your script does not read |

The person sees a failure only when nothing at all was found: then the first source that failed is
named, with its words. Which words follows the one rule in [words.md](words.md): the app's own codes
(`denied`, `limits`, `broken`) have the app's words; a code your
script said has your `error.<code>` first, then the app's words above, then the app's sentence for
anything else. Your words have no `{address}` to fill in here: words of yours that hold one are not
used, and the app's are shown instead.

`broken`, `limits` and `denied` are the add-on's own failures ([testing.md](testing.md)).

## Words

Book information has no locale keys of its own. Beside the general keys (`does`, `works`, `changes`)
its locale files hold only `error.<code>` for the codes it says ([words.md](words.md)). It has no
settings, so no `setting.<key>`.

## The starter's script

<!-- generated:file ../templates/info/info.lua -->
```lua
-- Info starter: a source of book information and covers for Koona Books, made to be copied.
--
-- The Example catalog at api.example.org answers JSON. This script asks it about one book and
-- says what it found: candidates, each one edition in one language, and links to covers. The
-- app does the rest: which source to ask, ranking, the comparison the person sees, what is
-- written to the library, and fetching every picture.

local API = "https://api.example.org"
local ROLES = { author = true, translator = true, editor = true, illustrator = true }

-- A text, or nil: an empty string or a number from the JSON is no text.
local function text(value)
  if type(value) == "string" and value ~= "" then return value end
  return nil
end

-- One request, decoded. The app paces every request to the manifest's pace (and never faster
-- than its own cap), so the script does not wait between them.
local function get(url)
  local r = koona.http.request{ url = url, headers = { accept = "application/json" }, timeout = 20 }
  if r.status == 0 then return nil, r.error or "unreachable" end
  if r.status == 404 then return nil, "not_found" end
  if r.status == 429 then return nil, "limited" end
  if r.status ~= 200 then return nil, "refused" end
  local ok, value = pcall(koona.json.decode, r.body)
  if not ok or type(value) ~= "table" then return nil, "not_understood" end
  return value
end

-- A cover's link, made whole. A link to a host the manifest does not list is no cover: the
-- app drops it, so it is not worth sending.
local function cover(c)
  if type(c) ~= "table" or not text(c.url) then return nil end
  local ok, url = pcall(koona.url.join, API, c.url)
  if not ok then return nil end
  return { url = url, width = c.width, height = c.height }
end

-- What the catalog found for the query: its list of books, or nil and a code.
local function find(query)
  -- The query holds an ISBN only when the book has a valid one.
  local isbn = query.identifiers.isbn and query.identifiers.isbn[1]
  local url
  if isbn then
    url = API .. "/v1/books?isbn=" .. isbn
  elseif query.title ~= "" then
    url = API .. "/v1/books?title=" .. koona.url.encode(query.title)
    if query.authors[1] then url = url .. "&author=" .. koona.url.encode(query.authors[1]) end
  else
    return {}
  end
  -- `want` is the languages to answer in, best first; this catalog takes a three-letter code.
  local lang = query.want[1] and koona.lang.code3(query.want[1])
  if lang then url = url .. "&lang=" .. lang end
  local answer, why = get(url)
  if not answer then return nil, why end
  return type(answer.books) == "table" and answer.books or {}
end

local function candidate(b)
  if type(b) ~= "table" or not text(b.title) then return nil end
  local authors = {}
  for _, a in ipairs(type(b.authors) == "table" and b.authors or {}) do
    -- The app knows four roles and drops a person with any other; none is an author. A
    -- narrator is not made into an author here.
    if type(a) == "table" and (a.role == nil or ROLES[a.role]) then
      authors[#authors + 1] = { name = a.name, role = a.role or "author" }
    end
  end
  -- Every kind of identifier is a list of texts, also for one value. The app keeps a kind
  -- other than `isbn` only when it is this source's own id in the manifest ("example").
  local identifiers = { example = { b.id } }
  if text(b.isbn) then identifiers.isbn = { b.isbn } end
  return {
    title = b.title,
    subtitle = b.subtitle,
    language = text(b.language) and koona.lang.tag(b.language),
    authors = authors,
    publisher = b.publisher,
    -- A year, a year and month, or a full date ("2019", "2019-08", "2019-08-06").
    published = type(b.year) == "number" and string.format("%d", b.year) or nil,
    identifiers = identifiers,
    cover = cover(b.cover),
    -- The record's page on the catalog's site, for the person's browser, as the catalog gives
    -- it; the app never asks for it. A catalog that gives none has none: do not make one up.
    page = text(b.web),
    -- The script's own note: which record this is. The app hands it back to `details`.
    note = text(b.id),
  }
end

local info = {}

function info.search(ctx, query)
  local books, why = find(query)
  if not books then return { error = why } end
  local rows = {}
  for _, b in ipairs(books) do
    rows[#rows + 1] = candidate(b)
  end
  return { rows = rows }
end

-- The candidate the person looks at, filled in from the record's own page. What comes back is
-- the candidate as the app took it from `search`, with the fields this adds.
function info.details(ctx, found)
  if not found.note then return found end
  local record, why = get(API .. "/v1/books/" .. koona.url.encode(found.note))
  if not record then return { error = why } end
  found.description = record.description
  found.tags = record.tags
  if type(record.series) == "table" then
    found.series = { name = record.series.name, index = record.series.number }
  end
  return found
end

function info.covers(ctx, query)
  local books, why = find(query)
  if not books then return { error = why } end
  local rows = {}
  for _, b in ipairs(books) do
    rows[#rows + 1] = type(b) == "table" and cover(b.cover) or nil
  end
  return { rows = rows }
end

return info
```
<!-- /generated -->

## Limits

A call into book information has its own time, in [limits.md](limits.md) ("A call into book
information"), and the pace above. What one answer may hold, and what a query holds at most:

<!-- generated:limits-info -->
| Limit | Value |
| --- | --- |
| Candidates of one `search` | 10 |
| Covers of one `covers` | 20 |
| A title, a subtitle | 500 characters |
| A person's name, a publisher, a series' name | 200 characters |
| A `description` | 60,000 characters |
| `tags` | 50 of 100 characters |
| `authors` | 20 |
| A person's `also`, by language | 10 |
| `other_titles`, by language | 20 |
| Identifiers of a candidate, in all | 20 |
| `published` | 32 characters |
| `note`, the script's own | 2,008 bytes |
| A query's `authors` | 8 |
| A query's `languages` | 8 |
<!-- /generated -->
