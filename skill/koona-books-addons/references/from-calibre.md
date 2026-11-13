# Coming from a Calibre plugin

If you have written plugins for Calibre, this page says what carries over to Koona Books and what does
not. Read [README.md](README.md) first.

## The short version

A Calibre plugin is Python code that runs inside Calibre with everything Calibre can do: the library's
database, the file system, the network, and its own windows. A Koona Books add-on is a small Luau script
in a sandbox that does one declared job and is handed only what that job needs. Most of what a plugin
does by itself, the app does here: the screens, the settings form, the download, the conversion, the
changes to the library.

So an add-on is much shorter than the plugin it replaces, and there are plugins that no add-on can
replace.

## What maps to what

| In Calibre | In Koona Books |
| --- | --- |
| A metadata source plugin (identify, covers) | Book information: [book-info.md](book-info.md). The script returns candidates and cover links; the app ranks them, shows the comparison, and the person chooses what to keep |
| A device driver for a reader that shows up as a drive | Reader profiles, as data with no code: [reader-profiles.md](reader-profiles.md) |
| A device driver, or a "send to" plugin, for a reader reached over Wi-Fi | A send target: [send-target.md](send-target.md). One reader on the person's own network |
| A reading-progress or shelf sync with a service (Goodreads-style, KOReader sync) | A reading sync: [reading-sync.md](reading-sync.md) |
| An OPDS or store-search plugin | An import source: [import-source.md](import-source.md). The script lists books and links; the app downloads and imports |
| An interface action that opens a web page for the selected book | A book action that gives a link: [tools.md](tools.md) |
| An interface action that copies something about the selected books | A book action that gives text: [tools.md](tools.md) |
| A catalog or list export | A list exporter: [tools.md](tools.md) |
| Importing read dates or status from a file | A list importer: [tools.md](tools.md) |

## What has no counterpart

There is no way to write these as an add-on, and no partial way:

- **File type plugins and conversion plugins** (input and output formats, pipelines that change a book
  on import or before sending). A script never sees a book's bytes.
- **Metadata readers and writers for a format.** The app reads and writes files itself.
- **Anything about DRM.**
- **Plugins with their own windows, dialogs, toolbar buttons or preferences pages.** An add-on has
  settings of four kinds that the app draws, and menu entries for book actions and lists. Nothing else.
- **Edit-book tools, viewer plugins, library-maintenance jobs, scheduled or background jobs.**
- **News recipes** (web pages made into books).
- **Direct access to the library's database**, custom columns, or writing arbitrary fields of a book. A
  reading sync and a list importer change reading state only, through a preview the person applies.
  Book information offers details the person accepts.
- **Other people's Python libraries.** A script has Luau's `string`, `table`, `math`, `utf8` and `bit32`,
  and the `koona` table ([host-api.md](host-api.md)). Parsing HTML pages is not there: an add-on talks to
  an API that answers JSON, XML or CSV.

## What works differently

| In a Calibre plugin | In an add-on |
| --- | --- |
| Python | Luau: Lua 5.1 syntax with some additions. No classes; tables and functions |
| `import` anything | No `require`. Each entry file is whole by itself |
| Open any URL | Only the hosts the manifest lists, or the one reader or server the person typed in. A redirect to another host is refused |
| Threads, `time.sleep`, retries with a wait | One call, one thread, no waiting. State the service's request limit in the manifest (`network.pace`) and the app waits between requests |
| Store state in a file or a JSON preference | Nothing is kept between calls. A reading sync may hand the app a small note per book (`remote`) and a cursor, and gets them back |
| Ask for a password in your own dialog and store it | Declare a `secret` setting. The app asks, keeps it in the system keychain, and hands it over through `koona.secret.get` |
| OAuth in your own code | Declare `sign_in`. The app runs the sign-in, keeps the tokens and adds them to your requests. A script never sees a token |
| Raise an exception with a message | Return `{ error = "<code>" }` and word the code in your locale file ([words.md](words.md)) |
| Translations through gettext | `locales/<language>.json`, keys the app reads |
| Log with `print` | `koona.log(level, text)`, read in the developer's view ([testing.md](testing.md)) |
| Users install a zip from anywhere | The same, behind a switch and a sheet that lists what the add-on may do; or Koona's checked list ([checking.md](checking.md)) |

## Code under the GPL

Calibre is under the GPL version 3, and so are most of its plugins. Koona Books is not, and holds no
GPL code.

- **Do not copy code from a Calibre plugin into an add-on**, and do not translate one into Lua line by
  line. A port made by reading GPL code is not taken on Koona's checked list, whatever license you then
  put on it: you are asked to state that your add-on is not one ([checking.md](checking.md)).
- **Write from the service's own documentation**: its API pages, its protocol description, what its
  server answers to your own requests. That is also the better source: a plugin shows what worked for
  its author some years ago, and the API's pages show what the service promises.
- This holds for your own plugin too, if it contains code that others contributed under the GPL.
- The checked list takes only the permissive licenses listed in [checking.md](checking.md). An add-on
  under the GPL can still be shared as a file; the app adds it like any other.

This is the rule of Koona's list, not legal advice.

## A way to start

1. Write down, in one sentence, the job your plugin does for a person. Find it in the first table. If
   it is in the second list, stop here.
2. Read the page of that kind, and the starter for its category in `../templates/`.
3. Find what your plugin sends to the service and what it gets back, from the service's documentation.
   That exchange is your script. Everything around it (settings, storing, matching books, asking the
   person) is already in the app.
