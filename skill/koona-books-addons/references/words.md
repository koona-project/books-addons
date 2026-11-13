# An add-on's words

An add-on draws nothing. The app draws every screen, in its own words, and puts yours in where they
belong: your name and summary from `addon.json`, and the rest from the files in `locales/`. Your words
are always shown as your text, set apart from the app's, never as the app's own. This page says which
texts the app reads, where each one shows, how a language is chosen, how a failure is worded, and the
names of the icons a manifest may pick.

## `name` and `summary`

The manifest gives both as an object by language tag, and English is required:

<!-- sample:manifest-part send -->
```json
{
  "name": { "en": "Example Reader over Wi-Fi", "de": "Example Reader über WLAN" },
  "summary": {
    "en": "Send books to an Example Reader on your own network, without a cable",
    "de": "Bücher ohne Kabel an einen Example Reader in Ihrem Netzwerk senden"
  }
}
```

The name is the add-on's name everywhere: the list, its page, the sheet, a menu. The summary is the
line under the name on its page, and the quotation under **In its own words** on the sheet. Their rules
and caps are in [manifest.md](manifest.md). A language tag must match the app's exactly: `ru`, not
`ru-RU`.

## Locale files

Every other text is in `locales/<tag>.json`, one file a language:

<!-- sample:locale -->
```json
{
  "does": "Sends books to a Shelf reader on your Wi-Fi. The reader must have File Transfer open.",
  "works": "Shelf readers with firmware 2.0 or newer",
  "changes": "Books with a long title keep their name on the reader",
  "target.shelf.add": "Add a Shelf reader",
  "target.shelf.how": "Open File Transfer on the reader and type the address it shows.",
  "target.shelf.device": "Shelf reader",
  "error.no_card": "There is no memory card in the reader",
  "error.unreachable": "Nothing answers at {address}. Is File Transfer open on the reader?"
}
```

The rules of a locale file:

- **Its name** is `locales/` and a language tag, then `.json`: `en`, `de`, `pt-BR`, `zh-Hant-TW`. The
  tag is two or three lower-case letters, then up to three parts of two to eight letters or digits,
  each after a `-`. Any other file in `locales/` (a `README.md`, a file in a folder under it) is refused.
- **It is flat**: one JSON object of key to text. No nesting, no number, no list, no `null`, no key twice.
- **A key** is lower-case letters, digits, `_` and `.`, starts with a letter, and is at most 64
  characters: `[a-z][a-z0-9_.]{0,63}`.
- **A text** is not empty, has no space at either end, holds at least one letter or digit, and holds no
  character nobody sees: no control character (not even a tab or a line end), no direction override, no
  zero-width character outside the words of a script that is spelled with one.
- **The caps**: how many keys one file may hold and how long one text may be are in
  [limits.md](limits.md), "The package". A label has a shorter cap of its own, in every language (the
  row "A label" in [manifest.md](manifest.md)).
- **English is required**: `locales/en.json` must be there when there is any locale file, and when the
  add-on needs a label (below).

The app reads only the keys in the table below. Another key of the right shape is accepted and never
read, so a key spelled wrong shows nothing and no error tells you. A file that breaks a rule is refused
as `words`, with the file and the key in the dialog ([testing.md](testing.md)).

## How a text is chosen

For each key on its own, the app takes the text in the language of its interface, else the English one,
else none. So a key missing from `de.json` shows its English text. Where you give no text at all, the
app shows its own words or your add-on's name, as the table says.

The app's interface is in English and in Russian (`ru`) today. A person who picks Russian sees your `ru`
texts; any other language of yours is never shown yet. Write `en` first. Other languages are read as soon as the app speaks them.

## Every key the app reads

`<id>` is the `id` of an entry of `provides`; `<key>` is the `key` of a setting; `<code>` is a failure
code.

**An `id` with a hyphen can never be worded.** The manifest takes a `provides` id with a `-`
(`my-reader`), but a locale key may not hold one, so a file with `target.my-reader.add` in it is
refused. For a book action, a list exporter and a list importer, whose label is required, the package
is then refused either way. For a send target, an import source and a reading sync, whose keys are
optional, the app's words and the add-on's name always show in their place. Write ids with lower-case
letters, digits and `_` only.

| Key | Where it shows | Without it |
| --- | --- | --- |
| `does` | The row **What it does** on the add-on's page | No such row |
| `works` | The row **Works with** on the add-on's page (not for a reading sync) | No such row |
| `changes` | What changed in this version, beside the version (below) | Nothing is said |
| `target.<id>.add` | The title of the form that adds a reader | The add-on's name |
| `target.<id>.how` | The line under that title | No line |
| `target.<id>.device` | What a reader is called until it says its own name, and the name the lines of an update give this target | The add-on's English name |
| `sync.<id>.setup` | The title of the server's form, for a reading sync with a server the person names | The add-on's name |
| `sync.<id>.how` | The line under that title | No line |
| `source.<id>.add` | The title of the form that adds a catalog | The app's title |
| `source.<id>.how` | The line under that title | The app's line |
| `source.<id>.place` | The name the lines of an update give this catalog | The app's general words for something new |
| `action.<id>.label` | The book action in the book's menu, and on the add-on's page | **Required** |
| `export.<id>.label` | The list exporter among the formats of **Save book list**, and on the add-on's page | **Required** |
| `import.<id>.label` | The list importer on the add-on's page, beside **Choose file** | **Required** |
| `setting.<key>` | The label of the setting's field, in the form that asks for it | **Required** for every setting |
| `setting.<key>.hint` | The line under the field of the server's address, in the server's form and the catalog form | The app's line |
| `error.<code>` | Your words for a failure code (below) | The app's words, or its one sentence |

The labels marked **Required** must be in `locales/en.json`, for every book action, list exporter, list
importer and setting the manifest names, secrets included. A package without one is refused as `words`
with `locales/en.json` and the key, or as `missing` with `locales/en.json` when there is no English file
at all.

The name a reader gets in Devices when it says none of its own is your English `target.<id>.device`;
while it has no name of its own, the add-on's page shows that word in the person's language.

### No holes, but one

A text is shown as you wrote it: the app fills in nothing, and `{name}` or `{{name}}` in it is shown as
written. The one exception is `{address}` in an `error.<code>` text, which the app replaces with the
address the failure is about:

| Where | `{address}` is |
| --- | --- |
| A send target: Test connection, a reader's page, sending a book | The reader's address |
| A reading sync | The server's address, when the person typed one |
| An import source: the catalog form, a page, a search | The catalog's address |

Where the app has no address to put in (book information, tools, the last errors on the add-on's page,
a reading sync that signs in), a text with `{address}` is not used at all, and the app's words show
instead.

## Failure codes, and whose words show

A function that could not do its job answers `{ error = "<code>" }`. A code is lower-case letters,
digits and `_`, starts with a letter, and is at most 32 characters: `[a-z][a-z0-9_]{0,31}`. The person
never sees a code. One rule decides what they see, the same at every point (each place where the app
calls a script, see [README.md](README.md#rules-that-hold-everywhere)):

- **A code the app said** (its own failures, an address typed wrong) has the app's words for it at that
  point, else the point's one general sentence. Your words are never used for it, even for the same code.
- **A code your script said** has your words first, the text of `error.<code>`. Else the app's words for
  that code at that point, when it has some. Else the point's one general sentence.

There are two kinds of code the app says itself, and one rule for each.

**The reserved codes.** These are the app's own, at every point. A script that answers one of them is
taken as broken, wherever it answers it: as the `error` of an answer, as the `error` of one result of a
reading sync's `push`, or as the `stopped` of a `pull` or a `push`
([reading-sync.md](reading-sync.md)):

<!-- generated:reserved-codes -->
`denied`, `cancelled`, `limits`, `broken`, `not_on_your_network`, `server_moved`, `elsewhere`, `no_answer`
<!-- /generated -->

**Codes the app also produces at a point.** Each point has failures of the app's own besides these:
`books`, `bad_link`, `too_long` and `not_text` for tools; `incomplete` for a reading sync; `moved`,
`not_a_book`, `too_large` and the other failures of a download for an import source;
`bad_address`, `address_in_use`, `bad_folder` and `withdrawn` in a send target's form. These are not
reserved: a
script may answer one of them, and the app knows who said it. When the app produced it, the person
sees the app's words, always. When your script said it, it is your code like any other: your
`error.<code>` first, else the app's words for that code where the tables below list it, else the
point's general sentence. The OPDS catalogs add-on answers `moved` this way, with words of its own.

The codes `koona.http` answers with ([host-api.md](host-api.md)) are not the app's own either: pass
them on as your `error` when that is what went wrong, and the app has words for many of them.

At each point, these are the codes the app has English words for, and its one general sentence for every
other code. A word in italics is filled in by the app. Two words used in the headings: in a reading
sync, a **look** is Sync now reading the service and showing what would change, and a **take** is the
person applying it. In the table of sending a book, the row `script` is not a code: it is what the
person sees when the add-on is `broken`, ran out of `limits` or was `denied` while it sent a book.

<!-- generated:ts:failure-words -->
**A send target: Test connection, and a reader that does not answer**

| Code | The app's words |
| --- | --- |
| `unreachable` | Nothing answers at _address_ |
| `timeout` | The reader at _address_ took too long to answer |
| `bad_address` | This is not an address. Type it as the reader shows it, such as 192.168.1.20 |
| `not_on_your_network` | This address is not on your network. A reader is reached only on your own network |
| `not_a_reader` | Something answers at _address_, but it is not this kind of reader |
| `bad_folder` | This is not a folder on the reader. Type a path such as /Books |
| `address_in_use` | Another reader in Devices is already at this address |
| `withdrawn` | Koona withdrew this version of the add-on. Update it to add a reader |
| Any other code | The add-on could not check this reader |

**A send target: sending a book**

| Code | The app's words |
| --- | --- |
| `unreachable` | The reader did not answer. Is File Transfer open on it? |
| `timeout` | The reader took too long to answer. |
| `exists` | A file of this name is already on the reader. |
| `full` | The reader is full. |
| `name` | The reader did not take this file name. |
| `refused` | The reader refused the file. |
| `file` | The book’s file couldn’t be read while it was being sent. |
| `not_on_your_network` | The reader’s address is not on your network now. |
| `too_large` | The file is too large for this reader. |
| `check` | The file was not on the reader after sending. |
| `script` | The add-on’s script stopped with an error. |
| Any other code | The add-on could not send this book. |

**A reading sync: reading the service, or sending changes**

| Code | The app's words |
| --- | --- |
| `unreachable` | _service_ does not answer. Nothing was changed. |
| `timeout` | _service_ took too long to answer. Nothing was changed. |
| `tls` | _service_ could not be reached over a safe connection. Nothing was changed. |
| `signed_out` | The sign-in has ended. Connect again to keep syncing |
| `bad_login` | The server no longer takes this user and password |
| `bad_user` | The server does not take this user name. Change it first |
| `limited` | _service_ asked to wait. Nothing was changed; you can sync again after _time_ |
| `refused` | _service_ turned the request down. Nothing was changed. |
| `scope` | _service_ no longer gives access to your shelf. Connect again |
| `not_set_up` | It is not set up yet |
| `not_a_server` | Something answers at the server’s address, but it is not a sync server |
| `server_moved` | The server is no longer at the address you saved. Change it to keep the new one |
| `denied` | _service_ does not let the add-on do this. Nothing was changed. |
| `limits` | The add-on did more than it may in one sync and was stopped. Nothing more was changed. |
| `broken` | The add-on stopped with an error. Nothing was changed. |
| `incomplete` | _service_ did not send everything: only what came is shown |
| Any other code | The add-on could not do this. Nothing was changed. |

**A reading sync: the server's form**

| Code | The app's words |
| --- | --- |
| `bad_address` | This is not a server’s address. Type it as your reader shows it, such as sync.koreader.rocks |
| `plain_http` | A server on the internet must use https |
| `loopback` | This address is this computer. Type the server your reader syncs with |
| `reserved` | Koona Books does not reach this address. Type the server your reader syncs with |
| `private_address` | This name leads to an address that is not on the internet |
| `not_on_your_network` | This address is not on your network |
| `server_moved` | The server is no longer at the address you saved. Save it again to keep the new one |
| `unreachable` | Nothing answers at _host_. Is the address right? |
| `timeout` | _host_ took too long to answer. Is the address right? |
| `tls` | _host_ answers, but not over a safe connection |
| `bad_login` | The server does not know this user and password |
| `bad_user` | The user name holds characters a sync server does not take |
| `not_a_server` | Something answers at _host_, but it is not a sync server |
| `not_set_up` | The add-on could not sign in at this server |
| `no_secret` | Type the password: none is kept yet |
| `no_user` | Type the user name |
| Any other code | The add-on could not do this |

**A reading sync: one change that was not sent**

| Code | The app's words |
| --- | --- |
| `not_found` | _service_ does not know it |
| `set_aside` | it is set aside on _service_ |
| `already_read` | it is already read there |
| `no_place` | there is no edition there to keep the place in |
| `refused` | _service_ turned it down |
| `limited` | _service_ asked to wait |
| `no_answer` | _service_ did not answer |
| Any other code | the add-on could not send it |

**An import source: the catalog's form**

| Code | The app's words |
| --- | --- |
| `bad_address` | This is not an address. Type it as the server shows it, such as 192.168.1.10:8080/opds |
| `plain_http` | A catalog on the internet must use https |
| `loopback` | Koona Books does not reach localhost. For a Calibre library on this computer, use Import from Calibre |
| `reserved` | Koona Books does not reach this address. Type the address of a catalog |
| `private_address` | This name leads to an address that is not on the internet |
| `not_on_your_network` | This address is not on your network |
| `bad_user` | A user name cannot have a colon in it |
| `unreachable` | Nothing answers at _address_. Is the server on, and is the address right? |
| `timeout` | _address_ took too long to answer. Is the server on, and is the address right? |
| `exists` | This catalog is already added, with this user name |
| `place_changed` | Where this address leads has changed since it was tested. Test it again |
| `too_many` | There are as many catalogs as Koona Books keeps. Remove one first |
| `withdrawn` | Koona withdrew this version of the add-on. Update it to add a catalog |
| `broken` | The add-on stopped with an error while it read the catalog |
| `limits` | The add-on took too long or asked for too much, and was stopped |
| `denied` | The add-on tried to do something it may not do, and was stopped |
| `sign_in` | The catalog does not take this user name and password |
| `not_a_catalogue` | Something answers at _host_, but it is not a catalog. A catalog’s address often ends in /opds |
| Any other code | The add-on could not check this catalog |

**An import source: a page or a search**

| Code | The app's words |
| --- | --- |
| `elsewhere` | The catalog sent Koona Books to another site, which it does not reach |
| `server_moved` | The catalog is no longer at the address you saved. Change it to keep the new one |
| `broken` | The add-on stopped with an error while it read this page |
| `limits` | The add-on took too long or asked for too much, and was stopped |
| `denied` | The add-on tried to do something it may not do, and was stopped |
| Any other code | Try again in a moment. If it keeps failing, the add-on’s page in Add-ons says more. |

**Book information**

| Code | The app's words |
| --- | --- |
| `unreachable` | Nothing was changed. Is this computer online? _source_ is sometimes busy: try again in a minute. |
| `timeout` | Nothing was changed. _source_ took too long to answer: try again in a minute. |
| `tls` | Nothing was changed. _source_ could not be reached over a safe connection. |
| `refused` | Nothing was changed. _source_ turned the request down. |
| `not_found` | Nothing was changed. _source_ has no page for this search. |
| `limited` | Nothing was changed. _source_ asked to wait: try again in a minute. |
| `not_understood` | Nothing was changed. _source_ answered with something the add-on did not understand. |
| `broken` | Nothing was changed. The add-on stopped with an error. |
| `limits` | Nothing was changed. The add-on took too long or asked for too much, and was stopped. |
| `denied` | Nothing was changed. The add-on tried to do something it may not do, and was stopped. |
| Any other code | Nothing was changed. Try again in a moment. If it keeps failing, the add-on’s page in Add-ons says more. |

**Tools: a book action**

| Code | The app's words |
| --- | --- |
| `bad_link` | _addon_ gave a link to a site it may not open. Nothing was opened |
| `too_long` | _addon_ gave text that cannot be copied. Nothing was copied |
| `not_text` | _addon_ gave text that cannot be copied. Nothing was copied |
| `missing` | _addon_ found nothing to go on: the book needs an ISBN, or a title and author |
| `books` | _addon_ takes _max_ books at once. _n_ are selected |
| `broken` | _addon_ could not do this: its script stopped with an error |
| `limits` | _addon_ could not do this: its script stopped with an error |
| `denied` | _addon_ could not do this: its script stopped with an error |
| Any other code | _addon_ could not do this. Nothing was done |

**Tools: a list exporter**

| Code | The app's words |
| --- | --- |
| `broken` | _addon_ could not write the list: its script stopped with an error. Nothing was saved. |
| `limits` | _addon_ could not write the list: its script stopped with an error. Nothing was saved. |
| `denied` | _addon_ could not write the list: its script stopped with an error. Nothing was saved. |
| Any other code | _addon_ could not write the list. Nothing was saved. |

**Tools: a list importer**

| Code | The app's words |
| --- | --- |
| `not_a_list` | _addon_ could not read it: it is not a list of the kind it reads. |
| `broken` | _addon_ could not read it: its script stopped with an error. |
| `limits` | _addon_ could not read it: its script stopped with an error. |
| `denied` | _addon_ could not read it: its script stopped with an error. |
| `too_long` | _addon_ could not read it: its script stopped with an error. |
| `not_text` | _addon_ could not read it: its script stopped with an error. |
| Any other code | _addon_ could not read it. |
<!-- /generated -->

So write `error.<code>` texts for the codes the app has no words for at your point, and for any code
where you can say more than the app: your words come first. An `error.` key whose code does not have the
shape above is ignored. Your text is shown cleaned (invisible characters left out, spaces run together)
and in the person's language, else English, as every other text.

On a catalog's page or in its search, `unreachable` and `timeout` are shown quietly as the catalog not
answering, and `sign_in` asks the person to sign in: no text shows for those, yours or the app's.

## `changes`: what changed in this version

`changes` is one line about this version, for the person deciding whether to take it: "Books with a
long title keep their name on the reader", not a changelog. The app shows it beside the version on the
add-on's page and with an update that waits, for an add-on that comes with the app or is on Koona's
checked list. For an add-on from a file or a folder it is not shown today.

## `README.md` and `CHANGELOG.md`

A package may hold them, and the app does nothing with them: it checks them as text (UTF-8, nothing
hidden) and counts them toward the caps of a package, and never shows them. They are for people who read
your source, and for Koona's review ([checking.md](checking.md)).

## Glyphs

`glyph` in the manifest picks the icon the app draws for the add-on: in the list of add-ons and on its
page, on its sheet, beside a reader it reaches in Devices and in the Send menu, beside its book actions
in the book's menu, and in the forms and dialogs of its readers, catalogs and syncs. It is one of these names:

<!-- generated:ts:glyphs -->
`panel`, `panel-r`, `help`, `info`, `search`, `filter`, `plus`, `minus`, `more`, `down`, `up`, `right`, `left`, `grid`, `list`, `sort`, `book`, `open`, `user`, `layers`, `tag`, `seal`, `copy`, `filex`, `file`, `trash`, `restore`, `bookmark`, `bookmark-fill`, `ribbon`, `collection`, `add-to`, `reader`, `usb`, `send`, `cable`, `ticket`, `mail`, `eject`, `check`, `lock`, `alert`, `x`, `img`, `import`, `export`, `folder`, `edit`, `pause`, `play`, `stop`, `star`, `gear`, `plug`, `addons`, `wifi`, `catalogue`, `history`, `clock`, `link`, `keyboard`, `sun`, `moon`, `toc`, `type`, `convert`, `drag`, `refresh`, `columns`, `shield`, `arrow-up`, `arrow-down`, `no-drop`, `database`, `drive`, `merge`, `ban`, `external`, `arrow-right`, `scroll`, `monitor`, `monitor-x`, `soon`
<!-- /generated -->

The manifest takes any name of the right shape ([manifest.md](manifest.md)). One that is not in this
list is not refused: the app draws its default add-on icon, `addons`, as it does when there is no
`glyph` at all.

## The rules for every text, in short

- Not empty, with no space at either end, and something to read: a letter or a digit.
- No hidden characters: nothing that cannot be seen, nothing that reorders text. In a locale text, no tab
  and no line end either; write one line.
- Within its cap: [limits.md](limits.md) for locale texts, [manifest.md](manifest.md) for the manifest's.
- UTF-8, with no byte-order mark, for the whole file.
