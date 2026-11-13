# Send targets

A send target sends books from Koona Books to one reader on the person's own network: a reader that
takes files over HTTP, usually over Wi-Fi, while a transfer screen is open on it. The person adds the
reader once (its address and, if you want one, a folder), and then sends books to it from Send like to
any other device.

A send target reaches that one reader and nothing else. It cannot reach the internet, another device
on the network, this computer, or a file on the computer. If you want Koona Books to know a reader that
the person connects with a cable or whose memory card they put into the computer, you need no script:
see [reader-profiles.md](reader-profiles.md).

The included add-on CrossPoint over Wi-Fi is a send target. Its script is
[send.lua](../examples/crosspoint-wifi/send.lua). The starter at the end of this page is a smaller one
for a made-up reader.

## Who does what

Koona Books does the part of a send that touches the library and the person's files:

- which books go, and in which format; converting a book when the reader does not read any of its
  formats;
- leaving out a book larger than the reader takes;
- the book's file name on the reader, and a second name when another book has that one;
- the queue, Stop and Resume, the progress the person sees, and the records of what was sent;
- reading the book's file from disk and streaming it to the reader.

Your script does the part that is the reader's own, in three functions:

| Function | When it runs | What it does |
| --- | --- | --- |
| `check(ctx)` | The person presses Test connection in the reader's form | Asks the reader what it is |
| `list(ctx, folder)` | Before and after a send, when the entry says `can_list` | Lists the files of a folder on the reader |
| `send(ctx, item)` | For each book of a send | Uploads one book |

The script never gets the book's path or its bytes. It gets a handle that only `koona.http.upload`
takes.

## The manifest

An add-on with a send target has `"category": "send"`. This is the starter's manifest:

<!-- generated:file ../templates/send/addon.json -->
```json
{
  "schema": 1,
  "id": "org.example.send-starter",
  "version": "0.1.0",
  "api": 1,
  "min_app": "0.1.0",
  "name": { "en": "Example Reader over Wi-Fi" },
  "summary": { "en": "Send books to an Example Reader on your own network, without a cable" },
  "glyph": "wifi",
  "category": "send",
  "author": { "name": "Your Name" },
  "license": "MIT",
  "works_with": { "devices": ["Example Reader"], "needs": "Book transfer open on the reader" },
  "permissions": {
    "network": { "local_device": { "ports": [8080] } }
  },
  "privacy": { "sends": ["book_files_to_your_device"], "collects": [] },
  "settings": [
    { "key": "address", "type": "host" },
    { "key": "folder", "type": "text", "default": "/Books", "role": "folder" }
  ],
  "provides": [
    { "type": "send_target", "id": "reader", "entry": "send.lua",
      "formats": ["epub", "pdf"], "converts": ["epub"], "max_file_mb": 100, "can_list": true }
  ]
}
```
<!-- /generated -->

What a send target needs:

- `permissions.network.local_device` with the `ports` the reader listens on. The first port is the one
  `ctx.base` names (see below); a request may go to any of them.
- A setting of the type `host`: the reader's address, which the person types. Exactly one; the manifest
  is refused without it, and with two.
- A provides entry of the type `send_target`.
- `privacy.sends` with `book_files_to_your_device`: what the person is told goes to the reader. Koona
  Books does not refuse a send target whose manifest leaves it out, but every send target sends book
  files to the person's device, so say it.

What a send target may have:

- One `text` setting with `"role": "folder"`: the folder on the reader books go into. Without one, books
  go to the reader's top.
- Other `text` settings, for the script's own use. They show in the reader's form below the address and
  the folder.
- Reader profiles beside it, in the same add-on (see [reader-profiles.md](reader-profiles.md)).

What an add-on with a send target may not ask for, because a send target reaches one reader on the
person's network and nothing else: `permissions.network.hosts`, `permissions.network.named_server`,
`permissions.network.pace`, `permissions.secrets` and `permissions.sign_in`. The other permissions
(`book_details`, `reading_state`, `book_query`, `links`, `input_file`) are refused too, since nothing
of a send uses them, and so is a setting of the type `secret` or `server`. The manifest is refused at
the first of them it holds:

<!-- sample:manifest-refused send permissions.network.hosts -->
```json
{
  "permissions": {
    "network": { "local_device": { "ports": [8080] }, "hosts": ["api.example.org"] }
  }
}
```

<!-- sample:manifest-refused send permissions.secrets -->
```json
{
  "permissions": {
    "network": { "local_device": { "ports": [8080] } },
    "secrets": true
  }
}
```

The folder setting's `default`, when it has one, must be a folder by the rule the app checks a typed one
with (see "The folder" below):

<!-- sample:manifest-refused send settings[1].default -->
```json
{
  "settings": [
    { "key": "address", "type": "host" },
    { "key": "folder", "type": "text", "default": "../Books", "role": "folder" }
  ]
}
```

A reader that listens on more than one port lists them all. The first is the one `ctx.base` names:

<!-- sample:manifest-part send -->
```json
{
  "permissions": {
    "network": { "local_device": { "ports": [8080, 80] } }
  }
}
```

A `host` setting may have a `default` (a name such as `reader.local`, or an address), but leave it
out unless every such reader has the same name: the person types what the reader's screen shows.

Every field is in [manifest.md](manifest.md); what the person is shown and agrees to is in
[permissions.md](permissions.md). For the starter it is:

<!-- generated:codes send -->
```text
network.local_device:8080
provides.send_target:reader
sends.book_files_to_your_device
```
<!-- /generated -->

### The entry

```text
{ "type": "send_target", "id": "reader", "entry": "send.lua",
  "formats": ["epub", "pdf"], "converts": ["epub"], "max_file_mb": 100, "can_list": true }
```

| Field | Required | What the app does with it |
| --- | --- | --- |
| `id` | yes | Names the target in its locale keys (`target.<id>.add`...) and in `ctx.id` |
| `entry` | yes | The script, a `.lua` file of the package |
| `formats` | yes | The formats the reader reads, the one it reads best first |
| `converts` | no | The formats of `formats` the app may convert a book to for this reader |
| `max_file_mb` | no | The largest file the reader takes, in MiB (1,048,576 bytes). A larger book is left out of the plan, and a converted one that comes out larger fails with the app's `too_large`. Without it, no size is too large |
| `can_list` | no, `false` | Whether `list` works. With it the app lists the folder to find a free name and, after each book, to see that the book is there |

For each book the app goes down `formats` in order and stops at the first format it can give: the
book's own file in that format, a copy converted earlier, or, when the format is in `converts`, a
conversion now. A format is lower-case letters and digits: `epub`, `pdf`, `txt`. Koona Books makes
`epub` (from FB2), and `kepub` and `azw3` (from EPUB or FB2), and converts only to a format that is also
in `formats`: any other format in `converts` is taken by the manifest and then left unused. With
`"formats": ["epub", "pdf"], "converts": ["epub"]`, a book with an EPUB goes as that EPUB; a book with an
FB2 and a PDF is converted to EPUB; a book with only a PDF goes as that PDF. The caps of `formats`,
`converts` and `max_file_mb` are in [limits.md](limits.md).

An add-on may have more than one send target. All of them share the add-on's settings.

## The reader's settings

The person opens the form of a new reader in Devices, with **+** (Add a device) and then the add-on's
name, or, while the add-on has no reader yet, on its page in Add-ons, **Your readers**, **Add a
reader**. They fill in its address, its folder and your other `text` settings. The
form's title, its first line and its labels are your words (see "Words" below); Test connection and
what the add-on may do are the app's.

The app finds the address by its type (`host`) and the folder by its role (`folder`), never by their
keys. Call them what you like; the starter calls them `address` and `folder`.

The settings belong to one reader. A person with two readers adds two, each with its own settings.
They are kept with the reader in Devices, not with the add-on, and are not secret. One address is one
reader: adding a reader of the same target at an address a reader already has uses that reader again
(back in Devices, if the person had taken it off), and changing a reader's address to another reader's
is refused (`address_in_use`).

### A reader that needs a password or a PIN

A send target cannot keep a secret, and the app has no other way to one:

- `permissions.secrets` and a setting of the type `secret` are refused for a send target.
- A `text` setting is the only place for a PIN or a password. It is shown in clear in the reader's
  form as it is typed, and kept in clear with the reader in the app's records of devices, not in the
  system keychain.
- When the person changes a reader, the form is filled in again with the address and the folder only.
  Another `text` setting opens empty (or with its `default`), and saving the form keeps what it then
  holds: a PIN not typed again is lost.
- Nothing asks the person at send time: there is no prompt for a code.
- Nothing is kept between calls: `check`, `list` and each `send` start afresh, so each one that needs
  the password signs in again.
- A reader whose PIN changes with each session cannot work: the PIN in the setting is the old one by
  the next send.

When the reader refuses the credentials during a send, what happens to the queue follows the code
your script answers (see [Failures and their words](#failures-and-their-words)): `unreachable`,
`timeout` and `full` stop the send; any other code (`bad_pin`, `refused`) fails that book only, and
the next book is tried, and fails in turn. Say `refused` with words of your own (`error.refused`) when
the reader turns the PIN down, so the person sees why each book failed.

### The address

The person types the address as the reader's screen shows it: `http://192.168.1.30`, `192.168.1.30`,
`http://192.168.1.30/`, `Reader.local`. The app takes off `http://` and one `/` at the end, and keeps
the rest in lower case. It refuses, in the form, before anything is sent:

- anything else around the address: `https://`, a port (`192.168.1.30:8080`), a path, a user name;
- this computer: `localhost`, `127.0.0.1`, `::1`;
- an address on the internet;
- an address that leads nowhere: `0.0.0.0`, multicast, the documentation ranges;
- a link-local IPv6 address (`fe80::...`), which means something only with the network interface it is
  on;
- Koona Books' own site.

The port is never typed: it comes from the manifest. A reader whose screen shows
`http://192.168.1.30:8080` is typed `192.168.1.30`.

An address is on the person's network when it is private (`10.x.x.x`, `172.16.x.x` to `172.31.x.x`,
`192.168.x.x`), link-local (`169.254.x.x`), in the carrier range `100.64.x.x` to `100.127.x.x`, or an
IPv6 unique local address (`fc00::/7`).

A name (`reader.local`, `ereader`) is looked up at each request. Only the addresses it answers with on
the person's network are used; the others are left out, never connected to. A name that answers with
this computer among its addresses, or with none on the person's network, gets nothing sent: the call
ends with the app's `not_on_your_network`.

### The folder

The folder setting is a path from the reader's top: `/Books`, `/Books/Fiction`, `/`. The app adds a
missing `/` at the start and drops one at the end, so `Books/` is `/Books`. It refuses a folder with
`..` or `.` as a part, a backslash, a control character, a space at either end of a part, or longer
than the `path` in "Limits" below (counted in bytes). An empty field takes the manifest's `default`, or
`/` when there is none.

Your script finds the folder in `ctx.settings.<key>`, already in this shape. The app plans with it and
records each book under it.

## The calls

Each function gets `ctx` first:

```text
ctx = { id = "reader",                                   -- the target's id
        settings = { address = "192.168.1.30",           -- every setting, as the person left it
                     folder = "/Books" },                --   for this reader, or its default
        base = "http://192.168.1.30:8080" }              -- the reader
```

- `ctx.base` is `http://`, the reader's address, and the manifest's first port, which is left out
  when it is 80. An IPv6 address is in brackets: `http://[fd00::30]:8080`. Build every address from it.
- `ctx.settings` holds every setting of the add-on: what the person typed (trimmed, and the address
  and folder as the app took them), or the manifest's `default` when they left it empty. A setting
  with neither is not there.

To reach another port of the manifest, build the address from `ctx.base`, not from the address
setting: an IPv6 address in the setting has no brackets (`fd00::30`), and `"http://fd00::30:81"` is no
address. Take the port off the end of `ctx.base`, when it has one, and put yours there:

<!-- sample:returns ["http://192.168.1.30:81", "http://[fd00::30]:81", "http://reader.local:81"] -->
```lua
-- `ctx.base` ends with ":<port>" only when the first port is not 80. An IPv6 address ends
-- with "]", so its own colons are never taken for a port.
local function at_port(base, port)
  return (base:gsub(":%d+$", "")) .. ":" .. port
end
return {
  at_port("http://192.168.1.30:8080", 81),
  at_port("http://[fd00::30]:8080", 81),
  at_port("http://reader.local", 81),
}
```

A port the manifest does not list, another address on the network, or anything on the internet ends
the call with the app's `denied`, whether or not the script catches the error.

Each answer is a table. One that could not do its job answers `{ error = "<code>" }`, a code being
lower-case letters, digits and `_`, starting with a letter. An answer that is not a table, a bare list,
a missing function, an error the script raises, or one of the app's own codes is the add-on's failure,
`broken`. Each call has the time and memory of one call in [limits.md](limits.md); an upload's wait is
apart from that time (see below).

### `check(ctx)`

Runs when the person presses Test connection. It asks the reader what it is.

```text
check(ctx) -> { name = "Example Reader Mini", detail = "Firmware 2.1" }
```

- `name` is required and must not be empty: without it the answer is `broken`. The person sees it
  under the address, and a reader added after a check keeps it as its name in Devices.
- `detail` is optional: a version, a model.

Answer `{ error = "not_a_reader" }` when something answers at the address but not as your reader does
(a router's page), and pass on the code of a request that got no answer (`unreachable`, `timeout`).

The person may add a reader without testing it: then it is named by `target.<id>.device` (the add-on's
name without it), and `check` does not run.

### `list(ctx, folder)`

Lists the files of `folder` on the reader, without its folders. The app asks only for the reader's
folder setting.

```text
list(ctx, "/Books") -> { rows = { { name = "a.epub", size = 734003 }, ... } }
```

- The rows go inside the answer as `rows`, never as the answer itself.
- Each row needs `name` (text) and `size` (bytes, a number of 0 or more). A row whose name could not be
  a file's (empty, with `/` or `\`, `.` or `..`, a control character, too long) or whose size is not a
  number is left out. So is a row that is not a table.
- List every file: the app looks for the book it just sent among all of them.
- A folder that is not there is an empty list, not an error.

The app calls it only when the entry says `can_list`:

- Before a book that is not to replace anything: the app takes the first of the book's names
  (`Dune - Frank Herbert.epub`, then `Dune - Frank Herbert (2).epub`...) that no file in the folder
  has. Names are compared as a memory card compares them, without case. If none of the names is free,
  the book fails with the app's `exists`. If the listing fails, the book goes under its first name.
  One listing serves the books after it.
- After each book: the folder must hold a file of the book's name and of its size in bytes. If it does
  not, the book fails with the app's `check`. If the listing itself fails after the upload said yes,
  the book counts as sent.

### `send(ctx, item)`

Sends one book.

```text
item = { file = "book",                      -- a handle for koona.http.upload
         name = "Dune - Frank Herbert.epub", -- the file's name on the reader
         size = 734003,                      -- its size in bytes
         replace = false }

send(ctx, item) -> { path = "/Books/Dune - Frank Herbert.epub" }
```

- `item.file` is a handle, not a path: a short text the app makes for this one call (it may well be
  `"book"`), which names the book's file only inside the call it was handed to. Pass it to
  `koona.http.upload` as `file`, as it is, and never write a handle yourself. In a call that was handed
  no book (`check`, `list`, the sample below) the same text names nothing, and the upload raises
  `bad_file`. Nothing
  else in `koona` turns it into a path or bytes.
- `item.name` is the name the app made: one part of a path, no `/` or `\`, never `.` or `..`, no
  control character. Use it as the name on the reader; do not change it, since the app records the book
  under it and looks for it under it.
- `item.size` is the file's size in bytes.
- `path`, where the reader put the book, is optional, and the app does not use it: it records the book
  in the folder setting under `item.name`, and looks for it there.

#### `exists` and `replace`

When a file of `item.name` is already in the folder and `item.replace` is false, leave that file as it
is and answer `{ error = "exists" }`. When `item.replace` is true, the book takes its place.

The app sets `replace` only when the file there is Koona Books' own: an earlier copy of the same book
it recorded under that name, or an earlier send of that name that did not finish. It never asks to
replace a file the person put on the reader.

#### Uploading with `koona.http.upload`

```text
koona.http.upload{ url = ctx.base .. "/api/upload?folder=%2FBooks",
                   file = item.file,           -- the handle (required)
                   filename = item.name,       -- the file's name in the form (required)
                   field = "book",             -- the form field (default "file")
                   fields = { note = "one" },  -- other text fields (optional)
                   headers = { ... } }         -- optional
  -> { status = 201, headers = { ... }, body = "..." }
  or { status = 0, error = "unreachable" }
```

The app opens the file for reading only and sends a `POST` with a `multipart/form-data` body: first
each of `fields` as a text part, in the order of their names, then the file as the part `field`, under
the name `filename`, with the type `application/octet-stream`. The body has a `Content-Length` and is
never chunked, since small readers do not read chunks. The boundary is the app's own and the script
never sees it.

- `filename` may not be empty, hold `/` or `\`, be `.` or `..`, or hold a control character; `field`
  and the names of `fields` may not be empty or hold a control character. A quote in any of them is
  sent as `%22`, as browsers send it. `fields` holds text values only.
- `headers` may not set `Content-Type`, which holds the boundary, nor the headers the app sets for
  every request (`Content-Length` among them; see [host-api.md](host-api.md)).
- The address follows the rules of every request: the reader, on a port the manifest lists. No redirect
  is followed: the book's bytes are sent once, to the address asked for, and the script gets the
  redirect itself.
- Each upload counts as one of the call's requests.
- The file is read to exactly the size it had when it was opened. A file that is gone, is not a file, or
  is cut while it is sent answers `{ status = 0, error = "file" }`.

An upload has a time of its own, apart from the script's seconds: a fixed spare time to start and end,
and time for the file's size at the slowest pace still worth waiting for, up to a cap. That time is
counted once for the call's book and shared by all of the call's uploads, so a second try of a fast
upload fits in it and a script that uploads for ever does not. An upload with no byte moving either way for the time in
"An upload with no byte moving" in [limits.md](limits.md) ends with `timeout`. When the upload is over,
the script goes on with the time it had left.

An answer is read like the answer to `koona.http.request` ([host-api.md](host-api.md)): `status`,
`headers` with lower-case names, and `body` as text.

A handle the call was not given, or a field the host does not take, raises an error the script may
catch with `pcall`. This sample is no send call, so it was handed no book, and `"book"` names nothing
here:

<!-- sample:returns [false, true] -->
```lua
local ok, why = pcall(koona.http.upload, {
  url = "http://192.168.1.30:8080/api/upload",
  file = "book",
  filename = "a.epub",
})
return { ok, string.find(tostring(why), "koona.http.upload: bad_file", 1, true) ~= nil }
```

#### Progress

The app shows how much of the book has gone, from the upload itself, and nothing else of a send's
progress. A send target need not call `koona.progress`; the app does not show what it reports during a
send or a check.

## Failures and their words

Every failure has a code. The person never sees the bare code: they see words for it, by one rule.

- A code the app itself said has the app's words, always.
- A code the script said has the add-on's own words for it first, `error.<code>` in its locale files;
  else the app's words for that code, when it has some; else the app's one sentence for a failure at
  that place.

The codes the app has words for, when the script says them:

| At | Codes |
| --- | --- |
| A check | `unreachable`, `timeout`, `not_a_reader` |
| A send | `unreachable`, `timeout`, `full`, `exists`, `name`, `refused`, `file`, `too_large` |

Use them as they mean: `full` for a reader with no room, `name` for a file name the reader does not
take, `refused` for any other no. The codes of `koona.http`, which a request answers with beside
`status = 0`, are passed on as they are.

At a send, `unreachable`, `timeout` and `full` are the reader's trouble: the send stops there, and
Resume sends this book again. Any other code fails this book only, and the books after it go on.

The app's own codes, which a script can never say (one that answers one of them is `broken`):

<!-- generated:reserved-codes -->
`denied`, `cancelled`, `limits`, `broken`, `not_on_your_network`, `server_moved`, `elsewhere`, `no_answer`
<!-- /generated -->

Of those, at a send target:

| Code | When |
| --- | --- |
| `not_on_your_network` | The reader's name answered with an address off the person's network, or with this computer. At a send, it stops the send |
| `denied` | The script reached for something its permissions do not give |
| `limits` | The call ran out of time or memory |
| `broken` | The script failed or answered outside the contract |
| `cancelled` | The person stopped it |

`denied`, `limits` and `broken` are the script's own failures: they are noted on the add-on's page and
count toward turning off an add-on the person added. A send also has failures of the app that are not
codes of a script: a book larger than `max_file_mb`, no free name, and a book not found in the folder
after it was sent. At the reader's form, the app says when the address is not one, not on the person's
network, already another reader's, or the folder is not a folder.

## Words

A send target's words are in its locale files ([words.md](words.md)):

| Key | Where it shows |
| --- | --- |
| `target.<id>.add` | The title of the form for a new reader ("Add an Example Reader"); without it, the add-on's name |
| `target.<id>.how` | The first line of the form: what to do on the reader so that it can be reached |
| `target.<id>.device` | What a reader is called until it says its own name; also what the app names when an update adds this target |
| `setting.<key>` | The label of the setting's field in the form. Required in `locales/en.json` for every setting: the package is refused without it |
| `error.<code>` | Your words for a code your script says, at a check and at a send |

In `error.<code>`, `{address}` stands for the reader's address as the app took it. Where the address is
not known, words that hold `{address}` are not used, and the app's words follow.

A `setting.<key>.hint` is allowed in the locale files, but the reader's form does not show it: under
the address it always shows the app's own line.

<!-- sample:locale -->
```json
{
  "target.reader.add": "Add an Example Reader",
  "target.reader.how": "On the reader, open Book transfer. Its screen shows the address to type here.",
  "target.reader.device": "Example Reader",
  "error.not_a_reader": "Something answers at {address}, but it is not an Example Reader"
}
```

## Limits

What a reader says of itself is cleaned before the person sees it, like a book's details: control and
invisible characters taken out, runs of spaces made one, and cut to these lengths.

<!-- generated:limits-send -->
| Limit | Value |
| --- | --- |
| A reader's `name`, `detail`, a `path` | 200 characters |
| A file's name in `list` | 255 bytes |
<!-- /generated -->

The time and memory of a call, the requests it may make and the time an upload may stand still are in
[limits.md](limits.md).

## The starter

[The starter](../templates/send/addon.json) is one send target for a made-up "Example Reader" that takes
books over HTTP on port 8080. Copy its folder, rename it, and change the pages and answers in `send.lua`
to the ones your reader has. Its files: `addon.json` (above), `send.lua` (below), `locales/en.json`,
`README.md`, `CHANGELOG.md` and `LICENSE.md` (the MIT license with `[year]` and `[fullname]` for you to
fill in).

<!-- generated:file ../templates/send/send.lua -->
```lua
-- Send starter: sends books to an "Example Reader", a made-up reader that takes books over
-- HTTP on the person's own network while its Book transfer screen is open. Change the pages
-- and the answers below to the ones your reader really has.
--
-- The reader's pages, as this starter imagines them (port 8080, no password):
--   GET  /api/info                  -> 200 { "model": "Mini", "firmware": "2.1" }
--   GET  /api/files?folder=/Books   -> 200 [ { "name": "a.epub", "size": 734003, "folder": false }, ... ]
--                                      404 when there is no such folder yet
--   POST /api/upload?folder=/Books  -> the book as the field "book" of a form; 201 when it is
--                                      stored, 409 when a file of that name is there, 507 when
--                                      the card is full, 400 for a name the reader refuses.
--                                      With &replace=1 it takes the place of a file of that name.
--
-- Koona Books calls three functions of the table this file returns: check, list and send.
-- Each answers a table: what it found or did, or { error = "<code>" } when it could not. The
-- app keeps the rest: which books go, converting them, their names on the reader, the queue,
-- and the records of what was sent.

local t = {}

-- Every request goes to ctx.base: "http://", the address the person typed, and the first port
-- of addon.json when it is not 80 ("http://192.168.1.30:8080"). That address on those ports is
-- the one place this add-on may reach.
local function get(ctx, path)
  return koona.http.request{ url = ctx.base .. path, timeout = 8 }
end

-- A request that got no answer has status 0 and the app's code in `error` ("unreachable",
-- "timeout", "file"...). Passed on as it is: the app has words for those codes.
local function no_answer(r)
  return { error = type(r.error) == "string" and r.error or "unreachable" }
end

-- The answer's body as JSON, or nil. Something that answers, but not in JSON, is not the
-- reader: json.decode raises on bad JSON, so it is called through pcall.
local function json(r)
  if r.status ~= 200 or type(r.body) ~= "string" then return nil end
  local ok, value = pcall(koona.json.decode, r.body)
  if ok and type(value) == "table" then return value end
  return nil
end

-- "Test connection" in the reader's form. `name` is required: the reader keeps it as its name
-- in Devices. `detail` is shown beside it.
function t.check(ctx)
  local r = get(ctx, "/api/info")
  if r.status == 0 then return no_answer(r) end
  local info = json(r)
  -- Something answers at this address (a router, a printer), but not as the reader does.
  if not info or type(info.firmware) ~= "string" then
    return { error = "not_a_reader" }
  end
  local model = type(info.model) == "string" and info.model or ""
  return {
    name = model ~= "" and ("Example Reader " .. model) or "Example Reader",
    detail = "Firmware " .. info.firmware,
  }
end

-- The files of one folder on the reader, without its folders. `folder` is the reader's folder
-- setting as the app checked it ("/Books", or "/" for the top). The app lists before a send,
-- to pick a name no other file has, and after it, to see that the book is there whole.
function t.list(ctx, folder)
  local r = get(ctx, "/api/files?folder=" .. koona.url.encode(folder))
  if r.status == 0 then return no_answer(r) end
  -- No such folder yet (nothing was sent there before): an empty list, not an error. The app
  -- lists before the first send too, and the reader makes the folder when a book arrives.
  if r.status == 404 then return { rows = {} } end
  local files = json(r)
  if not files then return { error = "refused" } end
  local rows = {}
  for _, f in ipairs(files) do
    if type(f) == "table" and f.folder ~= true
        and type(f.name) == "string" and type(f.size) == "number" then
      rows[#rows + 1] = { name = f.name, size = f.size }
    end
  end
  -- A list is never the answer itself: it goes inside it, as `rows`.
  return { rows = rows }
end

-- One book. `item.file` is a handle, not a path: koona.http.upload is the one thing that takes
-- it, and the script never sees the book's bytes. `item.name` is the file's name on the
-- reader, made by the app. `item.replace` is true only when the file of that name is Koona
-- Books' own earlier copy of this book: without it, a file of that name stays as it is.
function t.send(ctx, item)
  -- The folder: the setting with "role": "folder" in addon.json, already checked by the app.
  local folder = ctx.settings.folder or "/"
  local query = "?folder=" .. koona.url.encode(folder)
  if item.replace then query = query .. "&replace=1" end

  -- The app opens the file and streams it as one part of a form: the field "book", under the
  -- name item.name. The wait for it is the upload's own, not the script's seconds.
  local r = koona.http.upload{
    url = ctx.base .. "/api/upload" .. query,
    file = item.file,
    field = "book",
    filename = item.name,
  }
  if r.status == 200 or r.status == 201 then
    -- Where the book is now, from the reader's top.
    return { path = (folder == "/" and "" or folder) .. "/" .. item.name }
  end
  if r.status == 0 then return no_answer(r) end
  -- The reader's own answers, as codes the app has words for.
  if r.status == 409 then return { error = "exists" } end
  if r.status == 507 then return { error = "full" } end
  if r.status == 400 then return { error = "name" } end
  return { error = "refused" }
end

return t
```
<!-- /generated -->

<!-- generated:file ../templates/send/locales/en.json -->
```json
{
  "does": "Sends books to an Example Reader over your Wi-Fi. Book transfer must be open on the reader.",
  "works": "Example Reader · Book transfer open on it",
  "changes": "First version",
  "target.reader.add": "Add an Example Reader",
  "target.reader.how": "On the reader, open Book transfer and join your Wi-Fi. Its screen shows the address to type here.",
  "target.reader.device": "Example Reader",
  "setting.address": "Address",
  "setting.folder": "Folder on the reader",
  "error.unreachable": "Nothing answers at {address}. Is Book transfer open on the reader, and is it on this Wi-Fi?",
  "error.not_a_reader": "Something answers at {address}, but it is not an Example Reader"
}
```
<!-- /generated -->

To try it, load its folder as described in [testing.md](testing.md).
