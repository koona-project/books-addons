# Permissions, privacy and trust

An add-on is untrusted, like a book file. Three things hold it:

1. **The manifest is the only source of what it may do.** A script can do nothing that `addon.json` does
   not ask for ([manifest.md](manifest.md)).
2. **The person sees what the manifest says before the add-on is added**, in the app's own words. An
   add-on never describes its own permissions.
3. **The sandbox enforces it.** A script that reaches for something it has no permission for is stopped:
   the call ends with the app's own code `denied`, which a script cannot catch.

## What a script can never do

Whatever its manifest says, a script cannot:

- read or write a file, open a window, start a program, or read the clipboard;
- see a book's file, its path, its cover or the person's notes (a send target is handed a handle it can
  only pass to `koona.http.upload`);
- see a sign-in token, or a password it was not given as its own `secret` setting;
- reach this computer itself (loopback), Koona's own site, or the app's license service;
- reach an address on the person's home network, except the one reader or server they typed in;
- run code it did not ship: there is no `require`, no `loadstring`, no bytecode;
- keep anything between two calls: every call starts fresh.

[limits.md](limits.md) lists what a script does and does not have.

## Who may ask for what

A permission that nothing in the add-on would use is refused when the manifest is read. This table is
made by asking the app's own reader about the smallest add-on of each kind: every permission not in a
row is refused for that add-on.

<!-- generated:permission-matrix -->
| An add-on that adds only | May ask for |
| --- | --- |
| A send target | `network.local_device`, `settings` |
| Reader profiles alone | nothing |
| An import source | `network.hosts`, `network.named_server`, `network.pace`, `secrets`, `settings` |
| A reading sync | `network.hosts`, `network.named_server`, `network.pace`, `secrets`, `sign_in`, `reading_state`, `settings` |
| Book information | `network.hosts`, `network.pace`, `book_query` |
| A book action that gives text | `book_details` |
| A book action that gives a link | `book_details`, `links` |
| A list exporter | `reading_state`, `book_details` |
| A list importer | `reading_state`, `input_file` |
<!-- /generated -->

What each kind needs before it is accepted at all:

| Kind | Needs |
| --- | --- |
| A send target | `network.local_device` and a `host` setting. No other network permission |
| Reader profiles alone | Nothing |
| An import source | `network.hosts` or `network.named_server` (with a `server` setting), or both |
| A reading sync | `reading_state` |
| Book information | `book_query` and `network.hosts` |
| A book action | `book_details`; one that gives a link also `links.hosts` |
| A list exporter | `book_details` |
| A list importer | `reading_state` and its extensions in `input_file` |

An add-on with several entries may ask for what any of its entries may ask for, except that a send
target beside reader profiles still reaches only its one reader.

## What the person agrees to: the codes

The app turns a manifest into a list of **codes**, and a yes covers exactly those codes. The app keeps
them with the add-on. A newer version whose codes are all in that list takes the old one's place
quietly; a version with a code that is not in it waits for a new yes.

| In the manifest | Code |
| --- | --- |
| each of `network.hosts` | `network.host:<name>` or `network.host:*.<name>` |
| each port of `network.local_device` | `network.local_device:<port>` |
| `network.named_server` | `network.named_server` |
| `secrets` | `secrets` |
| `reading_state` | `reading_state` |
| each of `input_file` | `input_file:<extension>` |
| `book_query` | `book_query` |
| `book_details` | `book_details` |
| each of `links.hosts` | `links:<host>` |
| `sign_in` | `sign_in:<the host of the page>`, `sign_in.scope:<scope>` for each scope, `sign_in.authorize:<address>`, `sign_in.issuer:<host>`, `sign_in.client:<client_id>`, `sign_in.token:<address>`, `sign_in.revoke:<address>` |
| each entry of `provides` | `provides.<type>:<id>` |
| a reading sync | also `provides.reading_sync:<id>.direction:<from or to>`, `.carries:<code>` for each, `.match_by:<code>` |
| a list importer | also `provides.list_import:<id>.carries:<code>` for each |
| book information | also `provides.book_info:<id>.finds_by:<isbn or title_author>` for each |
| a book action | also `provides.book_action:<id>.gives:<link or text>` |
| reader profiles | also `provides.device_profiles:<id>.reader:<profile id>` for each reader |
| each of `privacy.sends` | `sends.<code>` |
| each of `privacy.collects` | `collects.<code>` |

So these changes in an update **ask the person again**: a new host, port, scope or permission; any
change to the sign-in; a new entry, or an entry whose `id` was changed; a new direction, a new thing a
sync or an importer carries, another way a sync knows books; asking book information by title and
author where only ISBN was asked; a text action that becomes a link action; a new reader in a profiles
file; a new privacy code.

These are **not** codes, and may change quietly: the pace; a send target's `formats`, `converts`,
`max_file_mb` and `can_list`; the `languages` of book information and whether it finds details or
covers; a book action's `max_books`; an exporter's `extension` and `file_name`; a setting and its role;
a reader's own details in a profiles file (its name, formats, folders, markers); every word in
`locales/`; the script itself.

Choose ids you can keep. Renaming an entry is, to the app, one entry gone and a new one asking.

The codes for one of the starters, as the app would record them:

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

## What the person is shown

Before an add-on from a file is added, the app shows a sheet. It says first, in the app's words, that
Koona has not checked the add-on, and who its file says made it. Of the add-on's own words it shows
only the name and the one-line summary, set apart as a quotation. Then it lists every permission and
every privacy line, none folded away. These are the lines:

<!-- generated:ts:sheet-words -->
| Code | When | The line on the sheet |
| --- | --- | --- |
| `network.host:api.example.org` |  | Reach api.example.org on the internet |
| `network.host:*.example.org` |  | Reach any site whose name ends in .example.org |
| `network.local_device:80`, `network.local_device:8080` | One line for all its ports | Reach one device on your network, at the address you give |
| `network.named_server` |  | Reach one server whose address you type. Koona Books shows where it leads before the first use |
| `secrets` |  | Read the password you type into its form. It can send it to any place it may reach |
| `sign_in:example.org` with `sign_in.scope:read` | One line for the whole sign-in, its scopes after it | Sign you in at example.org, in your browser. The page there names the app you approve: it is this add-on’s, not Koona Books. The add-on then acts in your account there: `read` |
| `reading_state` | A reading sync that matches books by identifiers | See the reading state and ISBNs of the books you sync |
| `reading_state` | A reading sync that matches books by their file | See how far you are in the books you sync, each known by a fingerprint of its file |
| `reading_state` | Tools that read a file | Changes the reading status of your books from that file, after you confirm |
| `reading_state` | Tools that read no file | Sees the reading status and dates of the books you choose |
| `input_file:csv` | Tools: one line for all its kinds of file | Reads one file you pick `csv` `tsv` |
| `input_file:csv` | Any other add-on | Read one file you pick |
| `book_query` | Book information | Sees the title, authors and ISBN of the books you look up |
| `book_query` | Any other add-on | See the title, authors and ISBN of the books you look up |
| `book_details` |  | Sees the details of the books you choose |
| `links:example.org`, `links:example.com` | One line for all its sites | Opens pages at example.org, example.com with the title, author and ISBN of the book you choose |
| A code the app has no words for |  | Shown as the code itself |
|  | Last, after the lines above, for an import source | Offer books to add from the places above. Koona Books downloads them itself and checks what each file is |
|  | Last, after the lines above, for book information | Offers covers from the places above. Koona Books fetches each picture itself and checks it |
| `sends.book_files_to_your_device` |  | The books you send go to your reader |
| `sends.reading_state_to_service` | Matched by identifiers | Reading status, progress and finished dates of the books you sync go to the places above, with their ISBNs |
| `sends.reading_state_to_service` | Matched by the file | A fingerprint of each book’s file and how far you are in it go to the places above |
| `sends.book_details_to_service` | With `network.host:api.example.org` | The details of the books you look up go to api.example.org |
| `sends.book_details_to_service` | With no site named | The details of the books you look up go to the service |
| `sends.searches_to_service` | With `network.host:api.example.org` | What you search for goes to api.example.org |
| `sends.searches_to_service` | With no site named | What you search for goes to the catalog you search |
| `sends.book_details_in_links` |  | When you open one of its links, that site gets the book’s title, author and ISBN |
| `collects.account` | With `sign_in:example.org` or `network.host:api.example.org` | It uses your account at example.org |
| `collects.account` | With no site named | It keeps an account with the service |
| No `collects` |  | It says it collects nothing |
|  | Last line of what it may do | Nothing else: no other site, no other device |
|  | Last line of what it may do, tools | Does not use the network |
|  | What it can never do | Read your books or any other file, open a window of its own, or reach this computer, your license or Koona’s servers |
|  | What it can never do, tools | Reach the internet, read your books or any file but the one you pick, open a window of its own, or reach this computer, your license or Koona’s servers |
<!-- /generated -->

The same codes are shown on the add-on's page afterwards.

## The three ways an add-on reaches a person

| | Comes with the app | From a file | On Koona's checked list |
| --- | --- | --- | --- |
| Who wrote it | Koona | Anyone | Anyone |
| Who read it | Koona | Nobody: the app says "Not checked by Koona" | Koona read every line of that version |
| How it is added | It is listed in Add-ons and off until the person adds it | The person turns on "Add-ons from a file", picks a `.kbooksaddon` file or a folder, and agrees to the sheet | The person finds it under Find add-ons and agrees to what it asks |
| Updates | From Koona's server | None. The person adds a newer file | From Koona's server. A version that asks for more waits for a yes |
| When its script keeps failing | Never turned off for it | Turned off after the number of failed jobs in a row given below, with "Turn on again" on its page | The same |
| Can be withdrawn by Koona | Yes | Yes, by id and version, when the app next checks | Yes |

The number of jobs in a row whose script fails (an error of its own, out of time or memory, a reach
outside its permissions; never a device or a service that does not answer) before the app turns an
add-on off:

<!-- generated:strikes -->
3
<!-- /generated -->

All three run in the same sandbox with the same host API. What an add-on that is not Koona's may not
have, from a file or on the list:

- an `id` that is `app.koona`, under `app.koona.`, or the id of an add-on that comes with the app;
- "Koona" in its `name` in any language, or in `author.name`, in any spelling;
- a sign-in under a `client_id` that an add-on that comes with the app uses.

The checked list asks more of an add-on (a license from a short list, the license's text, a name that
does not read as another add-on's): [checking.md](checking.md).

## Passwords, tokens and where they go

- A `secret` setting is kept in the system keychain. A script reads it with `koona.secret.get(key)` and
  may send it anywhere the add-on may reach, so the sheet says exactly that to the person. Send it only
  to the service it is for, never in an address and never to the log. Send it over `https` wherever
  the address is on the internet, where the app takes nothing else. Plain `http` is taken only for a
  server on the person's own network (a numeric address there, or a name of one label or under
  `.local`, `.lan`, `.internal`, `.home.arpa`), and a password sent there goes in clear on that
  network, as the included KOReader sync add-on and the sync starter do. A script may refuse to send
  a secret over `http` itself (`ctx.base` starts with `http://`).
- With `sign_in`, the app keeps the tokens and adds the token itself to requests that go to the issuer's
  host over `https`. A script with a sign-in may not set an `Authorization` or a `Cookie` header of its
  own.
- When a newer file of an add-on reaches somewhere new, or signs in differently, the passwords and the
  sign-in kept for the older file are forgotten: nothing ties two files to one author.
