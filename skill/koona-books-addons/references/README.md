# Writing add-ons for Koona Books

Koona Books is an e-book library for Windows and macOS that keeps a person's books on their own
computer. An add-on teaches it one more thing: a reader to send books to, a catalog to add books from, a
service to keep reading in step with, a place to look up a book's details, or something to do with a
list of books.

An add-on is a folder of plain text files: a manifest (`addon.json`), one or more scripts in
[Luau](https://luau.org) (a Lua 5.1 dialect made for running untrusted scripts), and its words in
`locales/`. There is nothing to compile and nothing to install to write one.

These pages, the examples and the starters have their public home at https://addons.koona.app/books/docs/.
Add-ons that other people made are listed at https://addme.dev/books/, and that is where one is submitted for Koona's
checked list ([checking.md](checking.md)).

## What an add-on can add

Every add-on has one `category`, and adds one or more things of that category.

| Category | What it adds (`provides[].type`) | Page |
| --- | --- | --- |
| `send` | A way to send books to one reader on the person's network (`send_target`) | [send-target.md](send-target.md) |
| `send` | Readers that Koona Books recognizes as a drive, as data with no script (`device_profiles`) | [reader-profiles.md](reader-profiles.md) |
| `import` | A catalog to browse, search and add books from (`import_source`) | [import-source.md](import-source.md) |
| `sync` | Reading state kept in step with a service or a server (`reading_sync`) | [reading-sync.md](reading-sync.md) |
| `info` | A book's details and covers from a catalog (`book_info`) | [book-info.md](book-info.md) |
| `tools` | A menu action on books that gives a link or a text (`book_action`) | [tools.md](tools.md) |
| `tools` | A list of books saved as a file (`list_export`) | [tools.md](tools.md) |
| `tools` | Reading state read from a file the person picks (`list_import`) | [tools.md](tools.md) |

## What an add-on cannot do

Know this before you plan one. An add-on does the small foreign half of a job: it speaks a device's or
a service's language. The app keeps the half that can lose data.

- **It has no window.** The app draws every screen: the settings form from your manifest, the sheets,
  the previews. Your words appear in them through locale keys.
- **It never touches a book's file.** It cannot read, write, convert or open one. A send target is handed
  a handle that it can only pass on to an upload. A catalog gives links, and the app downloads.
- **It never writes to the library.** A reading sync and a list importer give rows; the app decides
  which book each row is, shows a preview, and the person applies it. Book information gives candidates;
  the person picks what to keep.
- **It reaches only what its manifest names**: the hosts it lists, or the one reader or server the person
  typed in. A tools add-on reaches nothing at all.
- **It has no clock, no files, no timers, and no memory between calls.** Each call runs in a fresh
  sandbox under limits of time and memory ([limits.md](limits.md)).
- **One script file cannot load another.** There is no `require`. Each entry file is whole by itself.
- **It cannot add a new kind of thing.** The eight kinds above are all there are: no new file formats, no
  conversion, no changes to the reader view, no background jobs.

## What does not work yet

Read this before you plan an add-on. Each of these is how the app is today, and each link says more.

- **A send target cannot keep a password or a PIN.** It may have no secret; a `text` setting is shown
  and kept in clear, nothing asks at send time, and a PIN that changes each session cannot work
  ([send-target.md](send-target.md#a-reader-that-needs-a-password-or-a-pin)).
- **`setting.<key>.hint` is shown only under a `server` setting**, in the form of a reading sync and of
  a catalog the person names; nowhere else ([words.md](words.md#every-key-the-app-reads)).
- **A reading sync with only a key in a `secret` setting**, no `server` and no sign-in, cannot be set
  up ([reading-sync.md](reading-sync.md#how-a-person-sets-a-sync-up)).
- **A reading sync by identifiers pairs books only by ISBN** (and Hardcover's own ids). Another
  service's own ids pair nothing; a row with one is kept and may be offered as "Looks the same"
  ([reading-sync.md](reading-sync.md#two-ways-of-knowing-a-book)).
- **A catalog at listed hosts has no form**: its settings and secrets are never asked, and it is shown
  under the add-on's name ([import-source.md](import-source.md#what-a-catalog-cannot-do)).
- **A catalog whose file links need a token, a header or a cookie cannot work**: the app downloads, and
  signs in only with Basic, only to the server the person named
  ([import-source.md](import-source.md#what-a-catalog-cannot-do)).
- **A catalog at a server the person names cannot be tried from a folder** while the OPDS catalogs
  add-on that comes with the app is offered ([testing.md](testing.md#where-each-kind-shows-up)).
- **Only English and Russian are shown.** Other languages of an add-on are carried and not shown yet
  ([words.md](words.md#how-a-text-is-chosen)).
- **`koona.progress` is shown only during a reading sync** ([host-api.md](host-api.md#koonaprogress)).
- **`koona.json.encode` cannot write a `null` inside a map from a table**: a `nil` field is absent
  ([host-api.md](host-api.md#koonajsonencode)).
- **`koona.csv.decode` has no lenient mode**: a stray quote, or a row longer than the header, refuses
  the whole file ([host-api.md](host-api.md#koonacsvdecode)).
- **A list importer reads JSON or XML of one text at most** (`koona.json.decode` and `koona.xml.parse`
  take one text), while CSV may be as long as a picked file ([limits.md](limits.md#values)).
- **What changed in a version (`changes`) is not shown** for an add-on from a folder or a file
  ([words.md](words.md#changes-what-changed-in-this-version)).

## The files

```text
my-addon/
  addon.json          the manifest: who, what it adds, what it may do
  send.lua            a script, named by the manifest (any name ending in .lua)
  locales/en.json     the add-on's words, English required
  locales/de.json     more languages, if you have them
  README.md           for people who read the source
  CHANGELOG.md
  LICENSE.md          the text of your license (needed for Koona's checked list)
```

A package holds only `.lua`, `.json` and `.md` files, as UTF-8 text with no byte-order mark. Any other
file in the folder (a picture, a `.gitignore`, a hidden file) makes the app refuse it, so keep the add-on
in a folder of its own.

A script file returns a table of functions. The app calls the function its kind names (`check`, `send`,
`pull`, `run`...) with a `ctx` table and the call's own arguments, and reads the table the function
returns. Everything a script may use is in the `koona` table ([host-api.md](host-api.md)). This is
the end of the `tools` starter's script (the helpers above it are left out here). One file serves two book actions, one that gives a link and one that copies text:

<!-- generated:file ../templates/tools/actions.lua | local actions = {} | return actions -->
```lua
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

## From nothing to a working add-on

1. **Copy a starter.** `../templates/` holds one small working add-on for each category: `send`,
   `import`, `sync`, `info`, `tools`. Copy the folder and rename it.
2. **Make it yours** in `addon.json`: a new `id` under a domain you control, your name, the hosts your
   service really uses ([manifest.md](manifest.md)).
3. **Write the script** from the page of the thing you are adding, and its words in `locales/en.json`
   ([words.md](words.md)).
4. **Load the folder in Koona Books** (Add-ons, "Add-ons from a file", "Load a folder"), run the thing
   you added, and read its log. Edit, load the folder again, repeat ([testing.md](testing.md)).
5. **Share it.** Zip the files, with `addon.json` at the top of the zip and not inside a folder, and
   name the zip `<something>.kbooksaddon`. Anyone can add that file in their own Koona Books. Or ask
   Koona to check it and list it for everyone ([checking.md](checking.md)).

## The pages

| Page | What is in it |
| --- | --- |
| [manifest.md](manifest.md) | `addon.json`, field by field, and every rule across fields |
| [host-api.md](host-api.md) | Every function of `koona`: arguments, results, errors |
| [permissions.md](permissions.md) | Who may ask for what, what the person is shown, what an update may change quietly |
| [limits.md](limits.md) | Every limit, and what a script does not have |
| [words.md](words.md) | Locale keys, failure codes and whose words show, icon names |
| [send-target.md](send-target.md), [reader-profiles.md](reader-profiles.md), [import-source.md](import-source.md), [reading-sync.md](reading-sync.md), [book-info.md](book-info.md), [tools.md](tools.md) | The contract of each kind |
| [testing.md](testing.md) | The developer's folder, the log, what a refusal says |
| [checking.md](checking.md) | What Koona's check asks of an add-on, and how to send one |
| [examples.md](examples.md) | The nine add-ons that come with the app, in the order to read them |
| [from-calibre.md](from-calibre.md) | For people who have written Calibre plugins |

## Rules that hold everywhere

These are stated once here and assumed by every other page.

- **A point** is one place where the app calls a script: a send target, an import source, a reading
  sync, book information, a book action, a list exporter or a list importer (one kind of `provides`
  entry, with its own page). Reader profiles are data and no point. Each point has its own functions,
  its own caps and its own words, and the rules below hold at every one of them.
- **Every function answers a table.** One that could not do its job answers `{ error = "<code>" }`,
  where a code is lower-case letters, digits and `_`, starting with a letter, 32 characters at most.
  Anything else is success. There is no `ok` key.
- **A list is never the answer itself.** It is `rows` or `results` inside the answer.
- **A code is not a sentence.** The person never sees a code. They see your words for it (the locale
  key `error.<code>`), or the app's words when it has some, or one general sentence
  ([words.md](words.md)).
- **Some codes are the app's own** and a script may not answer them; one that does is treated as broken:

<!-- generated:reserved-codes -->
`denied`, `cancelled`, `limits`, `broken`, `not_on_your_network`, `server_moved`, `elsewhere`, `no_answer`
<!-- /generated -->

- **`ctx` is always there.** `ctx.id` is the `id` of the manifest entry that was picked, and
  `ctx.settings` holds the add-on's settings by key, except secrets.
- **A book's identifiers are always lists**: `identifiers = { isbn = { "9780140447934" } }`, a list of
  texts for each kind, also for one value.
- **Ignore what you do not know.** A table the app hands over may gain fields in a later version. The
  app ignores keys it does not know in what you return.
- **Nothing a script says is taken as it is.** Text is cleaned of invisible characters and cut to a
  length; addresses are checked against your permissions; numbers must be numbers.
