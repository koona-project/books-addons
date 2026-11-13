# The manifest: `addon.json`

Every add-on has one `addon.json` at its top. It says who made the add-on, what it adds to Koona Books,
and everything it may do. The app shows the person what this file says before they agree to the add-on,
and the sandbox lets a script do nothing the file does not ask for.

The file is read strictly:

- It is JSON, UTF-8, with one object at the top and no key named twice in any object.
- **A key the app does not know is refused**, at every level. Nothing is ignored.
- A value of the wrong type, an empty text, a text with a space at either end, or a text that holds a
  control character or an invisible one is refused.
- A field that asks for something no part of the add-on would use is refused. A permission is never
  "just in case".

When a manifest is refused, the app names the field and the reason (see [testing.md](testing.md)).

## A whole manifest

This is a complete manifest of a send target. The starters in `../templates/` hold one for each category.

```json
{
  "schema": 1,
  "id": "org.example.reader-wifi",
  "version": "1.0.0",
  "api": 1,
  "min_app": "0.1.0",
  "name": { "en": "Example Reader over Wi-Fi", "de": "Example Reader über WLAN" },
  "summary": { "en": "Send books to an Example Reader without a cable" },
  "glyph": "wifi",
  "category": "send",
  "author": { "name": "Your Name", "url": "https://example.org" },
  "homepage": "https://example.org/reader-wifi",
  "source": "https://example.org/reader-wifi/source",
  "support": "https://example.org/reader-wifi/issues",
  "license": "MIT",
  "works_with": { "devices": ["Example Reader 2"], "needs": "Firmware 1.3 or newer" },
  "tested": { "on": "Example Reader 2, firmware 1.3.0", "date": "2026-11-10" },
  "permissions": {
    "network": { "local_device": { "ports": [80] } }
  },
  "privacy": { "sends": ["book_files_to_your_device"], "collects": [] },
  "settings": [
    { "key": "address", "type": "host" },
    { "key": "folder", "type": "text", "default": "/Books", "role": "folder" }
  ],
  "provides": [
    { "type": "send_target", "id": "reader", "entry": "send.lua",
      "formats": ["epub", "txt"], "converts": ["epub"], "max_file_mb": 200, "can_list": true }
  ]
}
```

## Every object and its keys

This table is printed from the app's own list of keys. A key that is not in it is refused.

<!-- generated:manifest-keys -->
| Object | Keys |
| --- | --- |
| `the top` | `schema`, `id`, `version`, `api`, `min_app`, `name`, `summary`, `glyph`, `category`, `author`, `homepage`, `source`, `support`, `license`, `works_with`, `tested`, `permissions`, `privacy`, `settings`, `provides` |
| `author` | `name`, `url` |
| `works_with` | `devices`, `needs` |
| `tested` | `on`, `date` |
| `permissions` | `network`, `secrets`, `reading_state`, `input_file`, `book_query`, `sign_in`, `book_details`, `links` |
| `permissions.network` | `hosts`, `local_device`, `named_server`, `pace` |
| `permissions.network.local_device` | `ports` |
| `permissions.network.pace` | `per_minute`, `burst` |
| `permissions.sign_in` | `kind`, `issuer`, `authorize`, `token`, `revoke`, `client_id`, `scopes` |
| `permissions.links` | `hosts` |
| `privacy` | `sends`, `collects` |
| `settings[]` | `key`, `type`, `default`, `role` |
| `provides[] send_target` | `type`, `id`, `entry`, `formats`, `converts`, `max_file_mb`, `can_list` |
| `provides[] import_source` | `type`, `id`, `entry` |
| `provides[] reading_sync` | `type`, `id`, `entry`, `directions`, `carries`, `match_by` |
| `provides[] book_info` | `type`, `id`, `entry`, `languages`, `finds_by`, `finds` |
| `provides[] device_profiles` | `type`, `id`, `data`, `readers` |
| `provides[] book_action` | `type`, `id`, `entry`, `gives`, `max_books`, `host` |
| `provides[] list_export` | `type`, `id`, `entry`, `extension`, `file_name` |
| `provides[] list_import` | `type`, `id`, `entry`, `extensions`, `carries` |
<!-- /generated -->

## The top

<!-- object:top -->

| Key | Required | What it is |
| --- | --- | --- |
| `schema` | yes | The layout of this file: the whole number `1`. A higher number is answered "needs a newer Koona Books". Anything else is refused |
| `id` | yes | The add-on's identity, for good: settings, passwords, records and updates are kept under it. Reverse-DNS, lower case: two to six labels of `a-z`, `0-9` and `-`, joined by dots, no label starting or ending with `-` (`org.example.reader-wifi`). Use a domain you control. An id under `app.koona.` is Koona's own and is refused for anyone else |
| `version` | yes | Semantic version (`1.0.0`, `1.1.0-beta.1`). No build metadata (`+…`), and no upper-case letter in a pre-release part |
| `api` | yes | The level of the host API your scripts were written for, a whole number from 1. The app builds the `koona` table for that level ([host-api.md](host-api.md)). A level above the app's is answered "needs a newer Koona Books" |
| `min_app` | yes | The oldest version of Koona Books the add-on runs on, as a semantic version. An older app answers "needs a newer Koona Books" |
| `name` | yes | The add-on's name by language: an object of language tag to text. `en` is required. It may not say "Koona" in any spelling unless the add-on is Koona's |
| `summary` | yes | One line under the name, by language, `en` required |
| `glyph` | no | One of the app's own icon names ([words.md](words.md) lists them), `a-z`, `0-9` and `-`. A name the app does not have shows the app's default icon. An add-on carries no picture of its own |
| `category` | yes | `send`, `import`, `sync`, `info` or `tools`. Every entry of `provides` must be of this category (the table under [What it adds](#what-it-adds-provides)) |
| `author` | yes | Who made it: see below |
| `homepage` | no | An `https` address, with no user name or password in it |
| `source` | no | Where the source is, an `https` address |
| `support` | no | Where to report a problem, an `https` address |
| `license` | yes | The license as an SPDX name (`MIT`). The app shows it. Koona's checked list takes only a short list of licenses ([checking.md](checking.md)). The key is spelled `license`; `licence` is refused as an unknown key |
| `works_with` | no | What it is for: see below |
| `tested` | no | What you tried it on, and when: see below |
| `permissions` | yes | Everything the add-on may do. An empty object `{}` asks for nothing. See [Permissions](#permissions) |
| `privacy` | yes | What leaves the computer, and what is kept of the person. See [Privacy](#privacy) |
| `settings` | no | The form the app draws for the add-on. See [Settings](#settings) |
| `provides` | yes | What the add-on adds: one entry at least. See [What it adds](#what-it-adds-provides) |

The current level of the host API is:

<!-- generated:api-level -->
`"api": 1`
<!-- /generated -->

### `author`

<!-- object:author -->

| Key | Required | What it is |
| --- | --- | --- |
| `name` | yes | Your name, or your project's. It may not say "Koona" |
| `url` | no | An `https` address |

### `works_with`

<!-- object:works_with -->

| Key | Required | What it is |
| --- | --- | --- |
| `devices` | yes | A list of names a person looks for, each once: devices for a send target, services or formats for the others (`"Example Reader 2"`, `"BibTeX"`) |
| `needs` | no | One line on what must be true for it to work (`"Firmware 1.3 or newer"`) |

### `tested`

<!-- object:tested -->

| Key | Required | What it is |
| --- | --- | --- |
| `on` | yes | What you tried it on, in words |
| `date` | yes | The day, as `YYYY-MM-DD`, a day that exists |

## Permissions

`permissions` is the only source of what an add-on may do. [permissions.md](permissions.md) says what
the person is shown for each and which add-ons may ask for which.

<!-- object:permissions -->

| Key | Value | What it grants |
| --- | --- | --- |
| `network` | an object, see below | Requests with `koona.http` |
| `secrets` | `true` | The add-on has settings of the type `secret`, kept in the system keychain, and its scripts may read them with `koona.secret.get`. For a reading sync or an import source only |
| `reading_state` | `true` | What the person has read crosses into the scripts: for a reading sync, and for a list exporter or importer |
| `input_file` | a list of extensions | A list importer may be handed one file the person picks, with one of these extensions. Each is `a-z`, `0-9`, one to eight characters, no dot (`["csv"]`). For an add-on with a list importer only |
| `book_query` | `true` | The app asks the scripts about a book (its title, authors, ISBN, languages). For book information only |
| `sign_in` | an object, see below | The app signs the person in to a service for the add-on. For a reading sync only |
| `book_details` | `true` | What a book is (title, authors, series, identifiers, tags) is handed to book actions and list exporters |
| `links` | `{ "hosts": [...] }` | Where a link that a book action gives may lead |

**A flag is `true` or `false`, and `false` is the same as leaving it out.** This holds for every key
whose value is a boolean: `secrets`, `reading_state`, `book_query`, `book_details`, `named_server`,
and a send target's `can_list`. Only `true` asks for something, and only `true` is held to the rules
of who may ask (so `"secrets": true` is refused for a send target, while `"secrets": false` there asks
for nothing and is accepted, as in
[`../examples/crosspoint-wifi/addon.json`](../examples/crosspoint-wifi/addon.json)). Leave a flag out
rather than write `false`.

### `permissions.network`

A `network` object must ask for something: `{}` is refused.

<!-- object:permissions.network -->

| Key | Value | What it grants |
| --- | --- | --- |
| `hosts` | a list of host patterns | Requests to these hosts on the internet, and to no other |
| `local_device` | `{ "ports": [...] }` | Requests to one reader on the person's own network, at the address they typed into the add-on's `host` setting. For a send target only, and a send target may have no other network permission |
| `named_server` | `true` | Requests to one server whose address the person types into the add-on's `server` setting. For a reading sync or an import source only |
| `pace` | an object | How fast the requests may go. For a reading sync, an import source or book information, and only beside `hosts` or `named_server` |

A **host pattern** is a name (`api.example.org`) or every name under one (`*.example.org`, which does
not include `example.org` itself). It is lower case, has two labels at least, and is never an address,
never `*` alone, never every name under a public suffix (`*.co.uk`), never a name that only means
something on a home network (`.local`, `.lan`, `.internal`, `.home.arpa`, `localhost`), and never
`koona.app` or a name under it. List where your requests **lead**, not only where they start: a redirect
is followed only to a host in the list, and a link the app fetches for the add-on (a cover, a book's
file) is fetched only from a host in the list.

<!-- object:permissions.network.local_device -->

| Key | Value | What it is |
| --- | --- | --- |
| `ports` | a list of port numbers, 1 to 65535, each once | The ports of the reader the add-on may reach. The first is the port of `ctx.base` |

<!-- object:permissions.network.pace -->

| Key | Value | What it is |
| --- | --- | --- |
| `per_minute` | 1 to 600 | Requests a minute, from the limit the service's own pages state |
| `burst` | 1 to 100 | How many may go at once before the pace applies |

The pace is a bucket of `burst` turns that refills at `per_minute` turns a minute, one at a time. Each
request takes a turn; with none left it waits for the next. So up to `burst` requests go at once, and
up to `burst + per_minute` in the first minute; after that, `per_minute` a minute. To stay under a
service's limit of N requests in any minute, give a `per_minute` and a `burst` that add up to N at
most (for a limit of 30: `25` and `5`). A script cannot
wait. The app waits between requests for it, so state the service's limit here and write the script
as if there were none. How long the pace lasts depends on the kind (see the pace under
[`koona.http.request`](host-api.md#koonahttprequest)): a reading sync and book information keep one
pace for the add-on across all its calls while the app runs, while an import source starts each call
with a full bucket.

### `permissions.sign_in`

The app runs the sign-in (OAuth 2 with PKCE, approved in the person's browser), keeps the tokens, and
adds the token to the add-on's requests to the issuer's host. A script never sees a token.
[reading-sync.md](reading-sync.md) describes the flow.

<!-- object:permissions.sign_in -->

| Key | Required | What it is |
| --- | --- | --- |
| `kind` | yes | `oauth2_pkce`, the one kind there is |
| `issuer` | yes | Who gives the tokens: `https://` and a host, exactly so, with no path and no `/` at the end (`https://example.org`). The token is sent to this host and to no other. The host must be one that `network.hosts` matches |
| `authorize` | yes | The page opened in the person's browser: an `https` address with no query, no fragment and no port |
| `token` | yes | Where a code and a refresh token are traded. It must be under the issuer (`https://example.org/oauth/token`) |
| `revoke` | no | Where a sign-in is ended. Under the issuer |
| `client_id` | yes | Your app's public id at the service: letters, digits and `-._~`. It is not a secret. Register your own: an id that an add-on of Koona's uses is refused |
| `scopes` | yes | What is asked of the service, one at least, each of letters, digits and `:-._`, 64 characters at most. Ask for the fewest that do the work |

A manifest with `sign_in` must declare `"collects": ["account"]` under `privacy`.

### `permissions.links`

<!-- object:permissions.links -->

| Key | Value | What it is |
| --- | --- | --- |
| `hosts` | a list of host patterns, one at least | Where a link action's links may lead. Nothing goes there but the person's browser, on their click |

## Privacy

`privacy` is a closed list of codes. The app words each one itself, so an add-on cannot describe what it
sends in its own words.

<!-- object:privacy -->

| Key | Value | What it is |
| --- | --- | --- |
| `sends` | a list of codes, each once | What leaves the computer, and to whom |
| `collects` | a list of codes | What is kept of the person at a service. The one code is `account` |

| `sends` code | Required when | Allowed when |
| --- | --- | --- |
| `book_files_to_your_device` | not required | the add-on has `network.local_device` |
| `reading_state_to_service` | the add-on has `reading_state` and reaches the internet or a named server | the same |
| `book_details_to_service` | the add-on has `book_query` and reaches the internet or a named server | the same |
| `searches_to_service` | the add-on has an import source and reaches the internet or a named server | the same |
| `book_details_in_links` | the add-on has a book action that gives a link | the same |

`book_files_to_your_device` is allowed in a send target and not required there: the books go only to
the person's own reader. With it, the sheet the person agrees to has the line "The books you send go
to your reader"; without it, the sheet says nothing of what is sent. Write it: the person should be
told.

A code that is required and missing is refused, and so is a code the add-on's permissions do not back.
`collects` must hold `account` when the add-on has `sign_in`. Without `sign_in` it may still hold it,
when the service keeps an account for the person.

## Settings

`settings` is a list of the fields the app asks the person for. The app draws the form. A setting has no
label in the manifest: its words are the locale keys `setting.<key>` (required, in English) and
`setting.<key>.hint` ([words.md](words.md)).

<!-- object:settings[] -->

| Key | Required | What it is |
| --- | --- | --- |
| `key` | yes | The setting's name in `ctx.settings`: `a-z`, `0-9` and `_`, starting with a letter, 32 characters at most, each once |
| `type` | yes | `text`, `secret`, `host` or `server`: see below |
| `default` | no | What the field holds when the person leaves it empty. A `secret` has none |
| `role` | no | What the setting means to the app itself: `folder`, `user` or `password`. Each at most once |

| `type` | What it is | Rules |
| --- | --- | --- |
| `text` | A line of text | Its `default` is any clean text |
| `secret` | A password or a key, kept in the system keychain. Never in `ctx.settings`: a script asks for it with `koona.secret.get(key)` | Needs `permissions.secrets`. No `default` |
| `host` | The address of a reader on the person's network | Needs `network.local_device`, which in turn needs exactly one `host` setting. Its `default` is a name (`reader.local`) or an IPv4 or IPv6 address |
| `server` | The address of a server the person names | Needs `network.named_server`, which in turn needs exactly one `server` setting. Its `default` is a bare internet name (`sync.example.org`), with no scheme and no port |

| `role` | On a setting of type | For | What the app does with it |
| --- | --- | --- | --- |
| `folder` | `text` | a send target | Where on the reader books go. The app checks it as a path and plans with it. Its `default` must be a path on a reader (`/Books`) |
| `user` | `text` | an import source or a reading sync | The person's user name. For an import source the app signs in what it fetches itself with it |
| `password` | `secret` | an import source or a reading sync | The password that goes with the user. A `password` needs a `user` |

Nothing means anything by its key or by its place in the list. A setting with no role is the script's
own. An add-on of category `tools`, one of category `info`, and one that holds only reader profiles
have no settings: `settings` is refused there, and `ctx.settings` is an empty table.

## What it adds: `provides`

Each entry has a `type` and an `id`. The `id` is `a-z`, `0-9`, `_` and `-`, starting with a letter, 32
characters at most, and unique among the entries of its type.

**Do not put a `-` in an `id`.** The manifest takes it, but the locale keys made from the id
(`target.<id>.add`, `source.<id>.how`, `sync.<id>.setup`, `action.<id>.label`, `export.<id>.label`,
`import.<id>.label`) may not hold one, so such an entry can never be worded. For a book action, a list
exporter and a list importer, whose label is required, the package is then refused whatever you do;
for a send target, an import source and a reading sync, the app's own words always show instead of
yours ([words.md](words.md)). Every entry but reader profiles names its
script as `entry`; reader profiles name a data file as `data`.

<!-- generated:kinds -->
| `type` | `category` |
| --- | --- |
| `send_target` | `send` |
| `import_source` | `import` |
| `reading_sync` | `sync` |
| `book_info` | `info` |
| `device_profiles` | `send` |
| `book_action` | `tools` |
| `list_export` | `tools` |
| `list_import` | `tools` |
<!-- /generated -->

A file the manifest names (`entry`, `data`) is a path inside the package, of parts made of letters,
digits, `.`, `_` and `-`, joined by `/`. `entry` ends in `.lua`, `data` in `.json`. Several entries may
name the same script: the script is told which entry was picked by `ctx.id`.

<!-- object:provides[] send_target -->

**A send target** ([send-target.md](send-target.md)). Needs `network.local_device`.

| Key | Required | What it is |
| --- | --- | --- |
| `type` | yes | `send_target` |
| `id` | yes | The target's id |
| `entry` | yes | The script |
| `formats` | yes | The formats the reader takes, one at least (`["epub", "txt"]`) |
| `converts` | no | The formats the app should convert other books into before sending |
| `max_file_mb` | no | The largest file the reader takes, in MiB (1,048,576 bytes each). A reader said to take "300 MB" takes 286 MiB |
| `can_list` | no | `true` when the script has a `list` function |

<!-- object:provides[] device_profiles -->

**Reader profiles** ([reader-profiles.md](reader-profiles.md)). Data only, nothing runs. One such entry
an add-on.

| Key | Required | What it is |
| --- | --- | --- |
| `type` | yes | `device_profiles` |
| `id` | yes | The entry's id |
| `data` | yes | The file of profiles, a `.json` in the package, not under `locales/` |
| `readers` | yes | The ids of the profiles the file holds: every one and no other |

<!-- object:provides[] import_source -->

**An import source** ([import-source.md](import-source.md)). Needs `network.hosts` or
`network.named_server`.

| Key | Required | What it is |
| --- | --- | --- |
| `type` | yes | `import_source` |
| `id` | yes | The source's id |
| `entry` | yes | The script |

<!-- object:provides[] reading_sync -->

**A reading sync** ([reading-sync.md](reading-sync.md)). Needs `reading_state`.

| Key | Required | What it is |
| --- | --- | --- |
| `type` | yes | `reading_sync` |
| `id` | yes | The sync's id |
| `entry` | yes | The script |
| `directions` | yes | `from` (the service tells the library), `to` (the library tells the service), or both |
| `carries` | yes | What it keeps in step, one at least of `status`, `progress`, `finished_at` |
| `match_by` | no | What the service knows a book by: `identifiers` (the default) or `document` |

<!-- object:provides[] book_info -->

**Book information** ([book-info.md](book-info.md)). Needs `book_query` and `network.hosts`.

| Key | Required | What it is |
| --- | --- | --- |
| `type` | yes | `book_info` |
| `id` | yes | The source's id |
| `entry` | yes | The script |
| `languages` | yes | The languages the source knows books in, as language tags, or `["*"]` alone for any |
| `finds_by` | yes | What it can be asked by: `isbn`, `title_author`, or both |
| `finds` | yes | What it finds: `info`, `covers`, or both |

<!-- object:provides[] book_action -->

**A book action** ([tools.md](tools.md)). Needs `book_details`; one that gives a link also needs
`links`.

| Key | Required | What it is |
| --- | --- | --- |
| `type` | yes | `book_action` |
| `id` | yes | The action's id |
| `entry` | yes | The script |
| `gives` | yes | `link` or `text` |
| `max_books` | no | How many books it takes at once. 1 when left out, and always 1 for a link |
| `host` | for a link | The one host its links lead to, a name that `links.hosts` matches. Refused for a text action |

<!-- object:provides[] list_export -->

**A list exporter** ([tools.md](tools.md)). Needs `book_details`.

| Key | Required | What it is |
| --- | --- | --- |
| `type` | yes | `list_export` |
| `id` | yes | The exporter's id |
| `entry` | yes | The script |
| `extension` | yes | The extension of the file it writes, one of the list below |
| `file_name` | no | The name the save dialog suggests, without the extension: letters, digits, spaces, `_` and `-`. `books` when left out |

The extensions a list exporter may write:

<!-- generated:export-extensions -->
`csv`, `tsv`, `txt`, `bib`, `ris`, `json`, `xml`, `md`
<!-- /generated -->

<!-- object:provides[] list_import -->

**A list importer** ([tools.md](tools.md)). Needs `reading_state`, and each of its extensions in
`input_file`.

| Key | Required | What it is |
| --- | --- | --- |
| `type` | yes | `list_import` |
| `id` | yes | The importer's id |
| `entry` | yes | The script |
| `extensions` | yes | The extensions of the files it reads, one at least |
| `carries` | yes | What a row may change, one at least of `status`, `progress`, `finished_at` |

## What is refused together

The rules across fields, as the app holds them. Each refusal names the field in the left column.

| Field | Refused when |
| --- | --- |
| `provides[n].type` | The entry is not of the manifest's `category` |
| `permissions.network`, `permissions.secrets`, `permissions.sign_in`, `settings` | The category is `tools` |
| `permissions.network`, `permissions.secrets`, `settings` | The add-on holds only reader profiles |
| `permissions.network.hosts`, `.named_server`, `.pace`, `permissions.secrets`, `permissions.sign_in` | The add-on has a send target |
| `permissions.network.local_device` | The add-on has no send target, or no `host` setting |
| `permissions.network.named_server` | The add-on has neither a reading sync nor an import source, or no `server` setting |
| `permissions.network.pace` | The add-on has none of a reading sync, book information, an import source; or it has neither `hosts` nor `named_server` |
| `permissions.sign_in` | The add-on has no reading sync |
| `permissions.sign_in.issuer` | No pattern of `network.hosts` matches the issuer's host |
| `permissions.reading_state` | The add-on has none of a reading sync, a list exporter, a list importer |
| `permissions.input_file` | The add-on has no list importer |
| `permissions.book_query` | The add-on has no book information |
| `permissions.book_details` | The add-on has neither a book action nor a list exporter |
| `permissions.links` | The add-on has no book action that gives a link |
| `permissions.secrets`, `settings` | The add-on has book information |
| `settings[n].type` | A `secret` without `permissions.secrets`; a `host` without `local_device`; a `server` without `named_server`; a second `host` or `server` |
| `settings[n].role` | A role on the wrong type or in the wrong kind of add-on; a role used twice; a `password` with no `user` |
| `privacy.sends[n]` | A code the permissions do not back |
| `privacy.sends` | A required code is missing |
| `privacy.collects` | `sign_in` without `account` |
| `provides[n]` | The entry lacks the permission its kind needs; or it is a second `device_profiles` entry |
| `provides[n].host` | No pattern of `links.hosts` matches a link action's host |
| `provides[n].extensions[m]` | A list importer's extension is not in `input_file` |
| `provides[n].readers` | The list is not the ids of the profiles in the data file |

Two samples of the rules at work. A tools add-on may not reach the network:

<!-- sample:manifest-refused tools permissions.network -->
```json
{
  "permissions": { "book_details": true, "network": { "hosts": ["api.example.org"] } }
}
```

A reading sync that reaches a service must say that reading state goes there:

<!-- sample:manifest-refused sync privacy.sends -->
```json
{
  "permissions": { "reading_state": true, "network": { "hosts": ["api.example.org"] } },
  "privacy": { "sends": [], "collects": [] },
  "settings": [],
  "provides": [
    { "type": "reading_sync", "id": "example", "entry": "sync.lua",
      "directions": ["from", "to"], "carries": ["status"] }
  ]
}
```

## Limits

<!-- generated:manifest-limits -->
| Limit | Value |
| --- | --- |
| `addon.json` | 64 KiB |
| `id` | 100 characters, two to six labels |
| `version`, `min_app` | 32 characters |
| `name`, in each language | 60 characters |
| `summary`, in each language | 140 characters |
| Languages of `name` and of `summary` | 40 |
| `author.name`, `works_with.needs`, `tested.on`, one of `works_with.devices` | 100 characters |
| `works_with.devices` | 16 names |
| An address (`homepage`, `source`, `support`, `author.url`, the sign-in's) | 300 characters |
| `license` | 64 characters |
| `permissions.network.hosts`, `permissions.links.hosts` | 16 each |
| `permissions.network.local_device.ports` | 8 |
| `permissions.input_file`, a list importer's `extensions` | 8 |
| `permissions.sign_in.scopes` | 16 |
| `permissions.sign_in.client_id` | 200 characters |
| `settings` | 16 |
| A text setting's `default` | 200 characters |
| `provides` | 8 entries |
| A file the manifest names (`entry`, `data`) | 100 characters, 3 parts at most (`a/b/c.lua`) |
| A send target's `formats`, `converts` | 16 each |
| A send target's `max_file_mb` | 1 to 4,096 |
| A book action's `max_books` | 1 to 100 |
| A list exporter's `file_name` | 40 characters |
| Readers of a `device_profiles` entry | 1 to 8 |
| A label (`action.<id>.label`, `export.<id>.label`, `import.<id>.label`, `setting.<key>`) | 60 characters |
<!-- /generated -->

Text a person reads (a name, a summary, an author, a device) must hold a letter or a digit. Lengths
are counted in characters.

## The schema

The rules of this page are also given as data, written from the app's own check:

- [`../schema/addon.schema.json`](../schema/addon.schema.json): a JSON Schema (draft 2020-12) of
  `addon.json` at the current API level. It is published with these pages, in the folder `schema`
  beside them; the `$id` inside it is the name a validator knows it by.
- [`../schema/checked-licenses.json`](../schema/checked-licenses.json): the licenses Koona's checked list
  takes ([checking.md](checking.md)), as a list of SPDX names.

They are for tools. An editor that knows the schema marks a mistyped key or a wrong value while you
write. The form an add-on is submitted through (https://addme.dev/books/) checks the manifest with it before the
form can be sent.

Tell your editor about the schema in the editor's own settings (in VS Code, the setting `json.schemas`,
with `addon.json` as the file it applies to). Give it a copy of the file saved on your computer, or the
file's address where you are reading these pages. Do not put a `$schema` key into `addon.json`: it is a key
the app does not know, and the file is refused.

A schema says the shape of the file: the keys, the types, the lengths, the ranges, the codes. It cannot
say every rule. The rules across fields ([What is refused together](#what-is-refused-together)) and a
few others (a day that exists, an invisible character in a name, a name that says "Koona") are listed in
words in the schema itself, under `x-koona-rules`, for a tool to show beside its result. The schema is
for one API level (its `x-koona-api`): a manifest written for a later level is refused by it, though
the app's own answer to such a manifest is "needs a newer Koona Books", not "wrong".

**The app's own check is the final word.** A manifest that passes the schema can still be refused when
the folder is loaded, and the app then names the field and the reason ([testing.md](testing.md)). The
other way round should not happen: the schema is written to refuse nothing the app takes, and it is
tried against the app's own check on many thousands of manifests. If it ever refuses a manifest that
the app loads, the schema is at fault, not your manifest: report it in the repository
`koona-project/books-addons`.

## What can change later

- Nothing is ever removed from this layout. A field can be added only together with a higher `api`, so
  an older app answers "needs a newer Koona Books" and never "unknown field".
- The level your manifest names is the level your scripts get, also in a newer app: a function added at
  a later level is not there for a script that asked for an earlier one.
- A newer version of your add-on that asks for more than the version the person agreed to (a new host, a
  new permission, a new entry, a new privacy code) waits for their yes. One that asks for nothing new
  takes the old one's place quietly. [permissions.md](permissions.md) lists exactly what counts as more.
