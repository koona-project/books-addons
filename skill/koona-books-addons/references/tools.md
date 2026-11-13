# Tools: book actions and book lists

An add-on of the category `tools` adds small things to Koona Books. It has three kinds of entry:

| Kind (`type`) | What the person sees | The function called | What it answers |
| --- | --- | --- | --- |
| `book_action` | An entry in the book's menu | `run(ctx, books)` | `{ link = "..." }` or `{ text = "..." }` |
| `list_export` | A format in Save book list | `write(ctx, books)` | `{ text = "..." }` |
| `list_import` | Choose file, on the add-on's page | `read(ctx, file)` | `{ rows = { ... } }` |

A script is handed books (or the text of one file the person picked) and gives back one thing. The app
does everything else: it opens the link, copies the text, saves the file, reads the picked file, finds
the books a row names, and shows the person every change before it is made.

The starter [`../templates/tools/`](../templates/tools/addon.json) has two book actions and a list
exporter. For a list importer, read the included Book list as CSV
([`../examples/book-list-csv/list.lua`](../examples/book-list-csv/list.lua)).

## A tools add-on reaches nothing

A tools script has no network, no secret and no account, whatever its manifest says, and the manifest
may not ask for them. The app refuses a `tools` manifest that asks for any of these:

- `permissions.network`, in any form: no host, no device, no server, no pace.
- `permissions.secrets`.
- `permissions.sign_in`.
- `settings`: nothing draws a form for a tools add-on, and `ctx.settings` is always an empty table.
- `permissions.book_query`: there is no network to ask about a book through.
- `permissions.reading_state` without a list exporter or a list importer: a book action never gets the
  reading state.
- `permissions.input_file` without a list importer: a file is picked only for an importer.

The script also never sees a path, a file of the library, or any file but the one the person picked
for an importer. The only thing that leaves the computer is a link the person opens with their own
click.

A manifest that asks for the network is refused at that field:

<!-- sample:manifest-refused tools permissions.network -->
```json
{
  "permissions": {
    "book_details": true,
    "links": { "hosts": ["example.org"] },
    "network": { "hosts": ["api.example.org"] }
  }
}
```

So is one with a setting:

<!-- sample:manifest-refused tools settings -->
```json
{
  "settings": [ { "key": "style", "type": "text" } ]
}
```

And one that asks for the reading state with no list to use it:

<!-- sample:manifest-refused tools permissions.reading_state -->
```json
{
  "permissions": {
    "book_details": true,
    "reading_state": true,
    "links": { "hosts": ["example.org"] }
  },
  "provides": [
    { "type": "book_action", "id": "markdown_links", "entry": "actions.lua", "gives": "text",
      "max_books": 100 },
    { "type": "book_action", "id": "search", "entry": "actions.lua", "gives": "link",
      "host": "example.org" }
  ]
}
```

## The starter's manifest

<!-- generated:file ../templates/tools/addon.json -->
```json
{
  "schema": 1,
  "id": "org.example.tools-starter",
  "version": "0.1.0",
  "api": 1,
  "min_app": "0.1.0",
  "name": { "en": "Tools starter" },
  "summary": { "en": "Copy books as Markdown links, find a book on example.org, save a list as Markdown" },
  "glyph": "link",
  "category": "tools",
  "author": { "name": "Your Name" },
  "license": "MIT",
  "permissions": {
    "book_details": true,
    "links": { "hosts": ["example.org"] }
  },
  "privacy": { "sends": ["book_details_in_links"], "collects": [] },
  "provides": [
    { "type": "book_action", "id": "markdown_links", "entry": "actions.lua", "gives": "text",
      "max_books": 100 },
    { "type": "book_action", "id": "search", "entry": "actions.lua", "gives": "link",
      "host": "example.org" },
    { "type": "list_export", "id": "markdown", "entry": "list.lua", "extension": "md",
      "file_name": "reading-list" }
  ]
}
```
<!-- /generated -->

What the person agrees to when they add it, as codes (the words the app shows for each are in
[permissions.md](permissions.md)):

<!-- generated:codes tools -->
```text
book_details
links:example.org
provides.book_action:markdown_links
provides.book_action:markdown_links.gives:text
provides.book_action:search
provides.book_action:search.gives:link
provides.list_export:markdown
sends.book_details_in_links
```
<!-- /generated -->

## `ctx` and the entry file

An entry file returns a table of functions. The kind of the entry fixes which one is called: `run` for
a book action, `write` for a list exporter, `read` for a list importer. A function the kind calls that
is missing is the add-on's failure (`broken`).

```text
ctx = { id = "<the entry's id in the manifest>", settings = {} }
```

`ctx.id` is the entry's `id`, so one file may serve several entries. The starter's `actions.lua` is
named by both of its book actions and tells them apart by `ctx.id`; the included Book list as CSV
serves its exporter and its importer from one file, with `write` and `read`. An id is unique within
its kind: an exporter and an importer may both be `csv`. `ctx.settings` is always an empty table.

A file runs on its own: there is no `require`, so what a file needs, it defines.

### Ids and labels

Each entry has a label in the add-on's locale files, which the menu and the add-on's page show:

| Kind | Label key |
| --- | --- |
| `book_action` | `action.<id>.label` |
| `list_export` | `export.<id>.label` |
| `list_import` | `import.<id>.label` |

English (`locales/en.json`) must have every label; another language may leave one out, and English is
shown. A label is a short name: its cap is in [limits.md](limits.md) ("A label").

**Write an id with lower-case letters, digits and `_` only.** The manifest takes an id with a hyphen
(`my-cite`), but a locale key may not hold one, so the label key `action.my-cite.label` is refused
in the locale file, and without it the label is missing: a package with such an entry is refused either
way.

## The book handed over

`books` is always a list, also for one book. Each book is a table:

```text
book = { title, subtitle,
         authors = { { name = "Leo Tolstoy", sort = "Tolstoy, Leo", role = "author" }, ... },
         series = { name = "...", index = 12 },
         language = "ru", publisher = "...",
         published = "1869" or "1869-03" or "1869-03-01",
         identifiers = { isbn = { "9780140447934", "0140447938" }, hardcover = { "123" } },
         tags = { "classics", ... },
         -- only for a list exporter of an add-on with reading_state:
         status = "unread" | "reading" | "finished", progress = 0.62,
         finished_at = "2026-11-07", added_at = "2026-01-15", favorite = true }
```

| Field | What it holds |
| --- | --- |
| `title` | Always there. It may be an empty text. |
| `subtitle` | Absent when the book has none. |
| `authors` | Always a list, in the book's order, maybe empty. Each person has a `name`, a `sort` (the library's sort form of the name, or the name when the library has none) and a `role`: `author`, `translator`, `editor` or `illustrator`. A list of a book's authors is the people whose `role` is `author`. |
| `series` | The book's first series, absent when it has none: a `name`, and an `index` (a number) only when the library has one. |
| `language` | The book's first language as a language tag (`en`, `ru`, `pt-BR`), absent when it has none. |
| `publisher` | Absent when the book has none. |
| `published` | `yyyy`, `yyyy-MM` or `yyyy-MM-dd`, as much as the library knows; absent when it knows nothing. |
| `identifiers` | Always a table. Each kind (`isbn`, `hardcover`, ...) holds a list of texts, also for one value: every value the library has for that kind, each once, as the library holds it (an ISBN may have hyphens). An empty table when the book has none. |
| `tags` | Always a list, each tag once, maybe empty. |

Every text is cleaned before the script sees it: control and invisible characters are removed, white
space runs together into one space (a line break in a title is a space), and each text is cut to the
caps book information has ([book-info.md](book-info.md#limits)). A value the app cannot vouch
for is left out: a language that is no tag, a date that is not a real one, a series index that is not
a number from 0 to 100,000, a kind of identifier that is not a code.

A script never gets the book's file or formats, a path, the cover, the description, the person's
notes, the book's collections, or the book's place in the library.

### The reading fields

Only a list exporter is handed the reading, and only when the add-on has `"reading_state": true`. A
book action never gets these fields, whatever the manifest says.

| Field | What it holds |
| --- | --- |
| `status` | `unread`, `reading` or `finished`. `set_aside` is a word of the contract, and a script should know it, but the library has no such state, so the app does not hand it over. |
| `progress` | A number from 0 to 1, when the library has one and the book is not unread. |
| `finished_at` | The day the book was finished (`yyyy-MM-dd`), when the library has one. |
| `added_at` | The day the book was added to the library. |
| `favorite` | Always there: `true` or `false`. |

## Book actions

A book action does something with the books the person picked in the library: it gives a **link**
that the app opens in the person's browser, or a **text** that the app copies to the clipboard.

### The manifest entry

| Field | What it says |
| --- | --- |
| `type` | `book_action`. |
| `id` | The entry's id (see [Ids and labels](#ids-and-labels)). |
| `entry` | The script, a `.lua` file of the package. |
| `gives` | `link` or `text`. It is also the key of the script's answer. |
| `max_books` | How many books the action takes at once, 1 when it is left out. A link action takes one book, always: any other `max_books` is refused. The cap for a text action is in [Limits](#limits) ("Books handed to a book action"). |
| `host` | A link action only, and required there: the one host its links lead to, a plain name (no `*`). One of `permissions.links.hosts` must match it. A text action may not have one. |

What a book action needs in `permissions`:

- `"book_details": true`, for every book action and every list exporter: it says the add-on sees the
  books it is handed.
- For a link action, `"links": { "hosts": [ ... ] }`: where its links may lead, names or `*.name`
  patterns read as `network.hosts` is read ([manifest.md](manifest.md)). `links` is refused in an add-on
  without a link action.
- For a link action, the privacy code `book_details_in_links` in `privacy.sends`: what the link holds
  of a book goes to that site when the person opens it. It is required with a link action and refused
  without one.

A link action that takes more than one book is refused at its `max_books`:

<!-- sample:manifest-refused tools provides[1].max_books -->
```json
{
  "provides": [
    { "type": "book_action", "id": "markdown_links", "entry": "actions.lua", "gives": "text",
      "max_books": 100 },
    { "type": "book_action", "id": "search", "entry": "actions.lua", "gives": "link",
      "host": "example.org", "max_books": 5 },
    { "type": "list_export", "id": "markdown", "entry": "list.lua", "extension": "md",
      "file_name": "reading-list" }
  ]
}
```

A host that `links.hosts` does not match is refused at the entry's `host`. Here `links.hosts` names
`example.org`, which is not `www.example.org`:

<!-- sample:manifest-refused tools provides[1].host -->
```json
{
  "provides": [
    { "type": "book_action", "id": "markdown_links", "entry": "actions.lua", "gives": "text",
      "max_books": 100 },
    { "type": "book_action", "id": "search", "entry": "actions.lua", "gives": "link",
      "host": "www.example.org" },
    { "type": "list_export", "id": "markdown", "entry": "list.lua", "extension": "md",
      "file_name": "reading-list" }
  ]
}
```

A link action without its privacy code is refused at `privacy.sends`:

<!-- sample:manifest-refused tools privacy.sends -->
```json
{
  "privacy": { "sends": [], "collects": [] }
}
```

### `run(ctx, books)`

The app hands the books the person picked: one for a link action, up to the action's `max_books` for a
text action. More books than that, or none, are refused before the script starts (`books`).

The answer's key is the `gives` word. A link action answers `{ link = "https://..." }`; a text action
answers `{ text = "..." }`. The other key, both keys, no key, or a value that is not text is the add-on's
failure (`broken`), never a guess. A key the contract does not name is ignored. When the action cannot
do its job, it answers `{ error = "<code>" }` (see [Failures](#failures-and-their-words)).

The starter's two actions, in one file:

<!-- generated:file ../templates/tools/actions.lua -->
```lua
-- Tools starter: the two book actions of addon.json, "Copy as Markdown links" and "Find on
-- example.org".
--
-- One file serves both entries: each entry in addon.json names this file, and ctx.id says
-- which one the person picked. Koona Books calls run(ctx, books) and reads one key of the
-- answer, the entry's "gives" word: `text` for the copy, `link` for the search. A tools
-- add-on reaches nothing: no network, no file, no secret. The app copies the text, or opens
-- the link in the person's browser.

-- The search page of example.org. The words to find go at the end, encoded.
local SEARCH = "https://example.org/search?q="

-- The most characters of search words a link carries. Koona Books opens no link over its
-- length limit, and a few words find a book as well as many.
local MOST = 200

-- The first `most` characters of `text`, whole characters only (a letter may be several bytes).
local function cut(text, most)
  if utf8.len(text) <= most then
    return text
  end
  return string.sub(text, 1, utf8.offset(text, most + 1) - 1)
end

-- The names of the people who wrote the book. `authors` is always a list, maybe empty, and
-- holds translators, editors and illustrators too: each person's `role` says which.
local function authors(book)
  local names = {}
  for _, person in ipairs(book.authors) do
    if person.role == "author" then
      names[#names + 1] = person.name
    end
  end
  return names
end

-- What to search for: the book's first ISBN when it has one (it finds that very edition),
-- otherwise the title and the first author, otherwise nothing.
-- `identifiers` is always a table, and every kind in it is a list, also for one value.
-- `title` is always there, but may be empty.
local function words(book)
  local isbn = book.identifiers.isbn
  if isbn and isbn[1] then
    return isbn[1]
  end
  if book.title == "" then
    return nil
  end
  -- The first author, not a translator who may come first in the list.
  local first = authors(book)[1]
  if first then
    return book.title .. " " .. first
  end
  return book.title
end

-- The search link for a book, or nil when the book gives nothing to search by.
local function search_link(book)
  local find = words(book)
  if not find then
    return nil
  end
  return SEARCH .. koona.url.encode(cut(find, MOST))
end

-- Markdown reads these characters as its own: a backslash in front prints them as they are.
local function escaped(text)
  return (text:gsub("[\\%[%]%*_`]", "\\%0"))
end

-- One line of Markdown for a book: a link to its search page, then its authors.
--   - [War and Peace](https://example.org/search?q=9780140447934) by Leo Tolstoy
-- A book with nothing to search by gets its title alone.
local function line(book)
  local title = book.title ~= "" and escaped(book.title) or "Untitled"
  local link = search_link(book)
  local out = link and ("- [" .. title .. "](" .. link .. ")") or ("- " .. title)
  local names = authors(book)
  if #names > 0 then
    out = out .. " by " .. escaped(table.concat(names, ", "))
  end
  return out
end

local actions = {}

function actions.run(ctx, books)
  -- `books` is always a list, also for one book.
  if ctx.id == "search" then
    -- A link action is always handed exactly one book: the person clicked for that book.
    local link = search_link(books[1])
    if not link then
      -- A code, not a sentence: the app has words for `missing`, and the add-on may have its
      -- own (`error.missing` in its locale files).
      return { error = "missing" }
    end
    return { link = link }
  end
  -- "markdown_links": up to `max_books` books (addon.json), one line each.
  local lines = {}
  for _, book in ipairs(books) do
    lines[#lines + 1] = line(book)
  end
  return { text = table.concat(lines, "\n") }
end

return actions
```
<!-- /generated -->

### What the app does with a link

The app reads the link as a browser reads it, and opens it only if every one of these holds:

- It is `https`, on the usual port, with no user name or password in it.
- Its host is exactly the action's own `host`: not another host the add-on lists, not a name under it
  (`www.example.org` is another host), not an IP address. The host is compared in lower case, and a
  name written in another script is compared in its `xn--` form, so a look-alike of the host is
  another host.
- It holds no white space, no control character and nothing invisible. Put the book's words through
  `koona.url.encode`, as the starter does.
- It is no longer than the cap in [Limits](#limits) ("A link"), as written and as the app writes it
  back.

Only the link itself is checked. Where the site sends the browser after that (a redirect, a link on
its page) is the site's doing: the app does not see it, and the add-on is not held to it.

A link that fails a rule is not opened (`bad_link`). One that passes is kept as the parser writes it
back (the host in lower case, a `:443` dropped), checked once more by the app's own rule for every link
that leaves it, and opened at once in the person's default browser. The person's click on the menu
entry is the only ask: there is no second dialog, and nothing is opened at start-up or when books are
selected. Nothing is said when the browser opens; if no browser can be opened, the person is told.

Building the words of a link:

<!-- sample:returns "https://example.org/search?q=War%20and%20Peace%3A%20a%20novel" -->
```lua
local title = "War and Peace: a novel"
return "https://example.org/search?q=" .. koona.url.encode(title)
```

### What the app does with a copied text

The text is cleaned: `\r\n` and a lone `\r` become `\n`; tabs and line ends stay; control, direction
and invisible characters are removed (a zero-width joiner or non-joiner is kept between two letters of
a script that writes with it, as in Persian). A text over the cap in [Limits](#limits) ("A text to
copy") is refused (`too_long`), not cut; text that is not UTF-8 is refused (`not_text`). An empty text
is not a failure: the clipboard gets an empty text.

The app puts the text on the clipboard and says so: "Copied · " and the add-on's name, or for several
books "Copied for 12 books · " and the name.

### Where a book action appears

In the book's menu, in its own group below the book information entries, under the add-on's name.
The menu shows the first four actions of all add-ons and puts the rest under More actions.

- A link action shows its host after the label, with an arrow (`example.org ↗`), and its tooltip says
  it opens that host in the person's browser.
- With several books selected, a text action's label reads "Copy as Markdown links for 12 books". A
  link action is not shown for more than one book. A text action whose `max_books` is under the number
  selected stays in the menu, unavailable, with its limit beside it.
- On the add-on's page, the row In the book's menu lists its actions.

## List exporters

A list exporter writes a list of books as the text of a file. The person picks the books and the format
in Save book list; the app saves the text where the person's save dialog says.

### The manifest entry

| Field | What it says |
| --- | --- |
| `type` | `list_export`. |
| `id` | The entry's id. |
| `entry` | The script. |
| `extension` | The file's extension, one of the list below. |
| `file_name` | The name the save dialog suggests, without the extension: letters, digits, spaces, `_` and `-`, no space at either end, and not a name Windows keeps for a device (`con`, `nul`, `com1`, ...). `books` when it is left out. Its cap is in [limits.md](limits.md). |

The extensions an exporter may write:

<!-- generated:export-extensions -->
`csv`, `tsv`, `txt`, `bib`, `ris`, `json`, `xml`, `md`
<!-- /generated -->

An exporter needs `"book_details": true`. With `"reading_state": true` as well, its books carry the
reading fields, and Save book list says "With reading status and dates" beside its format (otherwise
"Book details only").

### `write(ctx, books)`

The app hands the books the person chose, at most the number in [Limits](#limits) ("Books handed to
a list exporter"); more are refused before the script starts. The script answers `{ text = "..." }`.
Only `text` is read: a `name` or a `path` beside it is ignored, and the script never names the file
or its folder.

The text is refused when it holds a NUL or a control character other than a tab, `\r` and `\n`
(`not_text`), or is over the cap ("An exported text", `too_long`). It is written as it is: line ends
and all. A CSV file wants `\r\n`, which `koona.csv.encode` writes.

The starter's exporter:

<!-- generated:file ../templates/tools/list.lua -->
```lua
-- Tools starter: the list exporter of addon.json, a book list saved as Markdown.
--
-- Koona Books calls write(ctx, books) with the books the person chose in Save book list, and
-- saves the text it answers where the person's save dialog says, with the extension addon.json
-- names ("md"). The script never names the file or the folder. Nothing here reaches the network.
--
-- A file runs on its own (there is no `require`): what list.lua needs, it defines.

-- Markdown reads these characters as its own: a backslash in front prints them as they are.
local function escaped(text)
  return (text:gsub("[\\%[%]%*_`]", "\\%0"))
end

-- The authors' names joined with ", " (not the translators or the editors).
local function authors(book)
  local names = {}
  for _, person in ipairs(book.authors) do
    if person.role == "author" then
      names[#names + 1] = person.name
    end
  end
  return table.concat(names, ", ")
end

-- One line a book:
--   - **War and Peace** by Leo Tolstoy (2007)
--   - **Мастер и Маргарита**: Роман by Михаил Булгаков (2014), Азбука-классика 12
-- A field the book does not have is absent (nil), so each part is added only when it is there.
local function line(book)
  local out = "- **" .. (book.title ~= "" and escaped(book.title) or "Untitled") .. "**"
  if book.subtitle then
    out = out .. ": " .. escaped(book.subtitle)
  end
  local names = authors(book)
  if names ~= "" then
    out = out .. " by " .. escaped(names)
  end
  -- `published` is "1869", "1869-03" or "1869-03-01": the year is its first four characters.
  if book.published then
    out = out .. " (" .. book.published:sub(1, 4) .. ")"
  end
  -- A series has a name, and an index only when the library has one.
  if book.series then
    out = out .. ", " .. escaped(book.series.name)
    if book.series.index then
      out = out .. " " .. tostring(book.series.index)
    end
  end
  return out
end

local list = {}

function list.write(ctx, books)
  local lines = { "# Reading list", "" }
  for _, book in ipairs(books) do
    lines[#lines + 1] = line(book)
  end
  -- The text is all the app reads from the answer: a `name` or a `path` beside it is ignored.
  return { text = table.concat(lines, "\n") .. "\n" }
end

return list
```
<!-- /generated -->

### What the app does with an exported text

1. Save book list (in the book's menu) asks which books: the ones selected, or all the books shown in
   the current place or search, up to the cap. It lists the formats of the exporters that are on, by
   their labels. When none is on, it offers to turn one on.
2. The script runs.
3. The system's save dialog opens with `<file_name>.<extension>` as the name. The app adds the
   extension when the person's name lacks it; when that makes the name of a file already there, the
   file is not replaced and nothing is saved.
4. The text is written whole, or nothing is: a file half written is never left.
5. The app says "Saved 12 books to reading-list.md", with a button that shows the file in its folder.

On the add-on's page, the row Saves lists as names the exporter's label, "In the book's menu, under Save
book list".

## List importers

A list importer reads a file the person picked into rows. Each row says which book it is about and what
to change in that book's reading. The app finds the books, shows the person every change, and changes
nothing before they apply it.

### The manifest entry

| Field | What it says |
| --- | --- |
| `type` | `list_import`. |
| `id` | The entry's id. |
| `entry` | The script. |
| `extensions` | The extensions of the files it reads: one or more, each of lower-case letters and digits, each also listed in `permissions.input_file`. The open dialog shows only such files. |
| `carries` | What its rows may change: one or more of `status`, `progress`, `finished_at`. A row's `set` may hold only these keys. |

An importer needs `"reading_state": true` (it changes the reading of books) and `"input_file"`, the list
of extensions the person is told it reads. It needs no `book_details`: it is handed no book. An add-on
with an importer and nothing else may not ask for `book_details`.

The starter with an importer added:

<!-- sample:manifest-part tools -->
```json
{
  "permissions": {
    "book_details": true,
    "reading_state": true,
    "input_file": ["csv"],
    "links": { "hosts": ["example.org"] }
  },
  "provides": [
    { "type": "book_action", "id": "markdown_links", "entry": "actions.lua", "gives": "text",
      "max_books": 100 },
    { "type": "book_action", "id": "search", "entry": "actions.lua", "gives": "link",
      "host": "example.org" },
    { "type": "list_export", "id": "markdown", "entry": "list.lua", "extension": "md",
      "file_name": "reading-list" },
    { "type": "list_import", "id": "csv", "entry": "import.lua", "extensions": ["csv"],
      "carries": ["status", "finished_at"] }
  ]
}
```

With `reading_state`, the starter's exporter would hand over the reading fields too.

`input_file` without an importer is refused:

<!-- sample:manifest-refused tools permissions.input_file -->
```json
{
  "permissions": {
    "book_details": true,
    "input_file": ["csv"],
    "links": { "hosts": ["example.org"] }
  }
}
```

### The picked file

The app opens the system's dialog, reads the file the person picked, and hands the script its text:

```text
file = { name = "books.csv", text = "..." }
```

- The file may be no larger on disk than the cap in [Limits](#limits) ("A picked file, on disk").
- It is read as UTF-8 (a byte-order mark is dropped) or as UTF-16 with its byte-order mark. Anything
  else is not text: the app does not guess an old code page. A NUL in it is not text either. Such a
  file is refused before the script runs, and the person is told the file is not a text file.
- `name` is the file's base name only, never its folder, cleaned as a shown text is and cut to its cap.

### `read(ctx, file)` and its rows

The script answers `{ rows = { row, ... } }`, the rows in the file's order:

```text
row = { match = { identifiers = { isbn = { "9780140447934" } },
                  title = "War and Peace", authors = { "Leo Tolstoy" } },
        set   = { status = "finished", progress = 1, finished_at = "2026-11-07" } }
```

| Field | What it holds |
| --- | --- |
| `match.identifiers` | Kind to a list of texts, as a book's `identifiers`. A kind whose value is not a list of texts is left out. |
| `match.title` | The book's title. |
| `match.authors` | A list of names. |
| `set.status` | `unread`, `reading`, `finished` or `set_aside`. |
| `set.progress` | A number from 0 to 1. |
| `set.finished_at` | `yyyy-MM-dd`, `yyyy-MM` or `yyyy`, a real date. A time after the day is not one. |

The app takes nothing as it is:

- Every text is cleaned and cut, as a book's texts are.
- A status the app does not know, a `progress` outside 0 to 1, a `finished_at` that is not a date in one
  of the three shapes, and a key of `set` that `carries` does not name are dropped.
- A row with no `match`, or with neither identifiers nor a title in it, is dropped. So is a row with no
  `set`, or with nothing left in it.
- Past the cap ("Rows read from a picked file"), the rows are cut, and the preview says that only the
  first rows were read.

When no row is left, the person is told the add-on found nothing it could read in the file.

The included Book list as CSV reads a spreadsheet's file this way:

<!-- generated:file ../examples/book-list-csv/list.lua | function list.read | return { rows = out } -->
```lua
function list.read(ctx, file)
  local rows, at = columns(file.text)
  if not rows then
    return { error = at }
  end
  local function cell(row, name)
    local text = unguarded(at[name] and row[at[name]])
    if text == "" then
      return nil
    end
    return text
  end
  local out = {}
  for _, row in ipairs(rows) do
    local title = cell(row, "title")
    -- The ISBNs of a cell, split by ";" as the authors are: a list, also for one.
    local isbns = {}
    for value in (cell(row, "isbn") or ""):gmatch("[^;]+") do
      local isbn = value:match("^%s*(.-)%s*$")
      if isbn ~= "" then isbns[#isbns + 1] = isbn end
    end
    -- A row the library could not find a book by is left out.
    if title or #isbns > 0 then
      local authors = {}
      for name in (cell(row, "authors") or ""):gmatch("[^;]+") do
        authors[#authors + 1] = name:match("^%s*(.-)%s*$")
      end
      out[#out + 1] = {
        match = { identifiers = { isbn = #isbns > 0 and isbns or nil }, title = title, authors = authors },
        set = { status = status_of(cell(row, "status")), finished_at = date_of(cell(row, "finished")) },
      }
    end
  end
  return { rows = out }
```
<!-- /generated -->

### What the app does with the rows

**Matching.** For each row the app looks for one book of the library:

1. by its ISBNs (ISBN-10 or ISBN-13, hyphens or not, compared as ISBN-13 with the check digit checked);
2. else by its other identifiers, kind by kind (`hardcover` with `hardcover`);
3. else by its title and authors, the way the library finds "probably the same book".

When a step finds more than one book, the row matches none: the app never guesses. A row that matches
no book is listed under Not in your library. Nothing is ever added to the library.

**What a row changes.** The library's states are unread, reading and finished:

- `set_aside` is taken as unread.
- A row with no `status` is finished when it has a `finished_at` or a `progress` of 1, reading when its
  `progress` is over 0, and unread otherwise.
- `finished_at` becomes the book's finished date only when it is a whole day (`yyyy-MM-dd`) from 1970
  on. A month or a year alone marks the book finished with no date.

**The preview.** The person sees "Reading from books.csv", read by the add-on, and "Nothing has changed
yet", with counts ("19 will be marked read · 2 already are · 12 not in your library") and the rows in
sections: the books that will change, the books that would go back (the file has them as not read
while the library has them read: these are not ticked unless the person ticks them), and the rows that
are not in the library. Apply changes the ticked books as one step, which one Undo puts back; the file
is not changed. Reading the file and its preview need no license. Applying needs a Koona Books
license, the same one as taking a reading sync's changes ([reading-sync.md](reading-sync.md)):
without one, nothing is changed, the preview stays, and the person is told that syncing their reading
needs a license, with a button to buy one.

On the add-on's page, the row Reads from a file has the importer's label and Choose file.

## Failures and their words

When a function cannot do its job it answers `{ error = "<code>" }`, a code being
`[a-z][a-z0-9_]{0,31}`. A code of the app's own is never a script's to say: one answered is `broken`
([words.md](words.md)).

The person never sees a code. For a code the script said, the app shows the add-on's own words for it
first (`error.<code>` in its locale files), then the app's words for that code where it has some, then
its one general sentence for the point. The app has words for two codes a tools script says:

| Code | Where the app has words for it | What it means |
| --- | --- | --- |
| `missing` | A book action | The book lacks what the action needs: "found nothing to go on: the book needs an ISBN, or a title and author". |
| `not_a_list` | A list importer | The file is not a list of the kind the importer reads. |

A list exporter has no words of the app's for a code its script says: give it words of your own.

These codes are the app's, and always have the app's words:

| Code | What happened |
| --- | --- |
| `books` | More books than the entry takes, or none for an action. Nothing ran. |
| `bad_link` | The link is not one the app opens. Nothing was opened. |
| `too_long` | The text to copy or to save is over its cap, or the answer is over what a call may answer. |
| `not_text` | The text to save holds a NUL or a control character, or the answer is not UTF-8. |
| `denied` | The script reached for something it may not have. |
| `cancelled` | The person stopped it. Nothing is said. |
| `limits` | The script ran out of time or memory. |
| `broken` | The add-on did not keep the contract: no such function, an error of its own, an answer of the wrong shape. |

Besides these, the app tells the person of what is its own doing: a picked file that is not text, too
large, or could not be read; an add-on still busy with its last job; a book no longer in the library;
a list that could not be written where the person said. None of these reaches the script.

A failure of the add-on's own is counted as at every other point.

## `koona.csv` and `koona.date` in use

The whole reference of both is in [host-api.md](host-api.md). This is how an exporter and an importer
use them.

**Writing CSV.** Rows are tables keyed by the column names; `header` gives the columns and their order.
A missing field is an empty cell, a cell a spreadsheet would run as a formula gets an apostrophe in
front, and every row ends with `\r\n`:

<!-- sample:returns "Title,Authors\r\nWar and Peace,Leo Tolstoy\r\n'=1+1,\r\n" -->
```lua
local books = {
  { title = "War and Peace", authors = { { name = "Leo Tolstoy", role = "author" } } },
  { title = "=1+1", authors = {} },
}
local rows = {}
for _, book in ipairs(books) do
  local names = {}
  for _, person in ipairs(book.authors) do
    names[#names + 1] = person.name
  end
  rows[#rows + 1] = { Title = book.title, Authors = names[1] and table.concat(names, "; ") }
end
return koona.csv.encode(rows, { header = { "Title", "Authors" } })
```

**Reading CSV.** With no delimiter named, the reader picks the one the first line uses most: a file from
a spreadsheet that writes `;` reads as well as one with `,`. Each row comes keyed by the names of the
first line, and the names come back in the file's order:

<!-- sample:returns {"names":["Title","ISBN","Status"],"rows":[{"title":"War and Peace","isbn":"9780140447934","status":"Finished"},{"title":"Anna Karenina","isbn":"","status":"Reading"}]} -->
```lua
local text = "Title;ISBN;Status\r\nWar and Peace;9780140447934;Finished\r\nAnna Karenina;;Reading\r\n"
local rows, names = koona.csv.decode(text)
local out = {}
for _, row in ipairs(rows) do
  out[#out + 1] = { title = row.Title, isbn = row.ISBN, status = row.Status }
end
return { names = names, rows = out }
```

**A file that is not CSV.** `koona.csv.decode` raises an error for a text it cannot read. Catch it with
`pcall` and answer a code: `not_a_list` has the app's words.

<!-- sample:returns {"error":"not_a_list"} -->
```lua
local function read(file)
  local ok, rows = pcall(koona.csv.decode, file.text)
  if not ok then
    -- The error's text holds the code: "koona.csv.decode: bad_format", "...: too_large".
    return { error = "not_a_list" }
  end
  return { rows = {} }
end
-- A column named twice is not CSV with a header.
return read({ name = "books.csv", text = "Title,Title\r\nA,B\r\n" })
```

**Reading a day.** A row's `finished_at` is ISO text. `koona.date.parse` reads a day as a file writes
it into ISO text, or gives `nil`. Try the shapes you take, ISO first; leave out a shape that reads two
ways (`01/02/2026` is a day in January in some countries and in February in others):

<!-- sample:returns {"iso":"2026-11-07","dotted":"2026-11-07","words":"2026-11-07"} -->
```lua
local SHAPES = { "yyyy-MM-dd", "d.M.yyyy", "d MMMM yyyy" }
local function day(text)
  for _, shape in ipairs(SHAPES) do
    local iso = koona.date.parse(text, shape)
    if iso then
      return iso
    end
  end
  return nil
end
return {
  iso = day("2026-11-07"),
  dotted = day("7.11.2026"),
  words = day("7 November 2026"),
  slashes = day("11/07/2026"),
}
```

**Writing a day.** `koona.date.format` writes ISO text the way a file wants it, or gives `nil` when the
date lacks a part the pattern needs (a book's `published` may be a year alone):

<!-- sample:returns {"day":"7 November 2026","month":"November 2026"} -->
```lua
return {
  day = koona.date.format("2026-11-07", "d MMMM yyyy"),
  month = koona.date.format("2026-11", "MMMM yyyy"),
  none = koona.date.format("2026-11", "d MMMM yyyy"),
}
```

## Limits

A call into a book action has the sandbox's usual time and memory; a call into a list exporter or
importer has more (both in [limits.md](limits.md)). What a tools call is handed and may answer:

<!-- generated:limits-tools -->
| Limit | Value |
| --- | --- |
| Books handed to a book action | 100 (its own `max_books` below that) |
| Books handed to a list exporter | 5,000 |
| A link | 2,000 bytes |
| A text to copy | 64 KiB |
| An exported text | 8 MiB |
| A picked file, on disk | 8 MiB |
| A picked file's text, as UTF-8 | 12 MiB |
| Rows read from a picked file | 20,000 |
| The picked file's name | 100 characters |
<!-- /generated -->

What these caps mean for one call:

- **The books and the file are the app's to cap.** The app refuses more books than the cap before the
  script starts (`books`), and a picked file over its cap before the script starts. What it hands
  over is not counted against the caps of a value in [limits.md](limits.md#values).
- **A book action's answer** crosses under the usual caps of a value; its text is then held to the
  cap of a text to copy.
- **A list exporter's and a list importer's answer** cross under larger caps, so that a whole file
  of text, or the rows of a whole picked file, fit: they are in [limits.md](limits.md#values). An
  answer over them is `too_long`.
- **Inside the call**, `koona.csv.decode` takes a text as long as a picked file's text may be, and
  `koona.csv.encode` writes a text as long as an exported text may be (the caps of `koona.csv` and
  `koona.date` are in [limits.md](limits.md#csv-and-dates)). Every other `koona` function keeps its
  usual caps: `koona.json.decode` and `koona.xml.parse` take one text, so a JSON or XML file longer
  than one text cannot be read whole.

## Growing

The tables the app hands over may gain fields: a script ignores what it does not know. The app ignores
a key it does not know in an answer, and drops one in a row's `set`. New `gives` words and new
`carries` codes come with a later API level, and an add-on that says an earlier `api` never sees them.

## Examples

- [`../examples/book-links/links.lua`](../examples/book-links/links.lua): two link actions in one file.
- [`../examples/citations/cite.lua`](../examples/citations/cite.lua): a text action for many books and
  a BibTeX exporter.
- [`../examples/book-list-csv/list.lua`](../examples/book-list-csv/list.lua): a CSV exporter with the
  reading fields, and an importer.
