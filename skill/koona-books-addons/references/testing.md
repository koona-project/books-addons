# Trying your add-on

You try an add-on in Koona Books itself: you load its folder, agree to its sheet, use what it adds,
and read what its script wrote to the log. There is no command-line tool for authors today, and no way
to run an add-on outside the app. This page says what the app checks when it reads your folder, what
it says when it refuses one, and where each kind of add-on shows up once it is loaded.

## Turn on "Add-ons from a file"

Open **Add-ons** (the row at the foot of the sidebar). The last row of the list, under a fold, is
**Add-ons from a file**. Its page has one switch, **Allow add-ons from a file**, which is off until the
person turns it on. With it on, the page has two more rows:

- **Install**, with **Install from a file**: the system's file window, for a `.kbooksaddon` file.
- **For developers**, with **Load a folder**: the system's folder window, for an add-on you are
  writing.

The switch gates choosing a file or a folder, **Read again**, the yes on the sheet, and the log.
Listing your add-ons and removing them work whatever it says, and an add-on already added keeps running
when it is turned off. Nothing is ever typed or dropped onto the page: the app opens the picker itself.

## Load a folder

The app reads the folder you pick whole, into memory, under the same rules as a `.kbooksaddon` file.
It never writes to your folder, and what runs afterwards is the app's own copy of what it read. Edit
the folder as you like; the add-on changes only when you read it again.

Every file in the folder, at any depth, must be one the app allows. **A file it does not allow is
refused, not skipped**, so the add-on must sit in a folder of its own. In a repository, keep it in a
subfolder (`addon/`, say) and pick that one, not the repository's root: the root's `.git` folder,
`.gitignore` or any other dotfile makes the app refuse the whole folder.

What a file needs to be allowed:

- **Its name ends in `.lua`, `.json` or `.md`.** Nothing else: no pictures, no `LICENSE` without an
  extension, no `.txt`. `README.md`, `CHANGELOG.md` and `LICENSE.md` are allowed; the app does nothing
  with them but check them as text.
- **Each part of its path** is made of the letters `A`–`Z` and `a`–`z`, digits, `.`, `_` and `-`, and
  does not start or end with a dot. So a hidden file or folder (`.git`, `.DS_Store`) is refused. A part
  may not be a Windows device name (`con`, `prn`, `aux`, `nul`, `com1` to `com9`, `lpt1` to `lpt9`),
  with or without an extension.
- **A path is not too long and not too deep.** The same caps as a file the manifest names hold for every
  file: see the row "A file the manifest names" in [manifest.md](manifest.md).
- **No two names differ only by case**, and the folder of words is spelled `locales`, never `Locales`.
- **It is a plain file or folder.** A link, a shortcut that leads elsewhere or a Windows junction is
  refused, never followed. A folder you pick that is itself a link is refused as well.
- **It is text**: UTF-8 with no byte-order mark, no NUL byte, and no character nobody sees (a control
  character other than a tab or a line end, a direction override, a zero-width character outside the
  words of a script that is spelled with one). This holds for `README.md` too.
- **Within the caps** of a package: the number of files, the size of each, all of them together
  ([limits.md](limits.md), "The package").

Then the folder must hold `addon.json`, every file the manifest names, and `locales/en.json` when it
has any locale file or needs a label ([words.md](words.md)). The manifest is read as
[manifest.md](manifest.md) says.

Loading a folder holds an add-on to the rules for a stranger's add-on below, and to nothing of Koona's
checked list: the license is read only as a short text in `license`, and no `LICENSE.md` is asked for.
Those rules are checked only when Koona reviews an add-on ([checking.md](checking.md)), and nothing in
the app checks them for you beforehand.

### What a folder may not have

The rules for an add-on that is not Koona's, from a folder or a file:

- an `id` that is `app.koona`, or under `app.koona.`, or the id of an add-on that comes with the app
  (`reserved_id`);
- "Koona" in its `name` in any language, or in `author.name` (`reserved_name`). The app reads it in a
  word, spelled out a letter at a time ("K.O.O.N.A"), cut in two ("Koo-na"), and in letters that look
  like Latin ones; words that only run into it ("Gecko on a shelf") are fine. `summary` is not read
  for it;
- a sign-in whose `client_id` an add-on that comes with the app uses (`client_taken`);
- the `id` of an add-on the person installed from Koona's checked list (`checked_id`).

### The API check

Each time the app reads a folder (Load a folder, Read again), it looks at every `.lua` file for the
names of `koona` it uses. A name the app does not have, or has only at a higher API level than the
manifest's `api`, is one warning line in the add-on's log, by the app, with the name and the file
(the table under [The log](#the-log)). The folder is offered all the same: at run time the name is
not there. The check reads names as they are written (`koona.http.request`, `local http =
koona.http`); a name built at run time (`koona["http"]`) is not seen. It is a help, not a gate. The
app makes it only for a folder, never for a `.kbooksaddon` file or an add-on from Koona's checked
list; Koona's review makes it too, and there a finding must be fixed ([checking.md](checking.md)).

## The sheet, and the yes

A folder that passes is shown on a sheet before anything of it is kept or run: **Install** and the
add-on's name as the title, the folder's name under it, and first, in the app's words, that Koona has
not checked it and who its file says made it. Your `summary` stands as a quotation under **In its own
words**. Then **What it may do**, **What leaves this computer** and **What it can never do**, with one
line for each code your manifest asks for and declares; [permissions.md](permissions.md) lists every
line. The version and the license are in the footer. **Cancel** has the focus.

On **Install**, before anything is kept, the app tries each of your scripts once in the sandbox, with
no permission at all, no settings and a short time. A script that does not compile, raises an error at
its top level, reaches for the network there or does not come back is refused as `does_not_start`. So
keep the top level of an entry file to defining functions and returning their table; do the work
inside the functions.

Once installed:

| It adds | After the yes |
| --- | --- |
| A send target, reader profiles, a book action, a list exporter or importer | On |
| A reading sync, an import source, book information | Off, until you set it up or turn it on |

## After an edit: Read again

The add-on's page has a row **Came from**: "A folder", the folder's path, **Read again** and
**Remove**. **Read again** reads the folder anew, under every rule above:

- **The same version is allowed** for an add-on that came from a folder. You do not need to raise the
  version for each edit.
- If the add-on asks for nothing new (no new code, the same author, no new place to reach), it is
  taken at once and the app says "*name* was read again from its folder". If it asks for more, the sheet
  comes back with the new lines marked **New**.
- If nothing in the folder changed, nothing is taken, and the app says the version is already
  installed.
- A lower version is allowed, and the sheet says the file is older than the one installed.
- A version that reaches somewhere new or signs in another way does not inherit the passwords and the
  sign-in given to the one before: the sheet says so, and the person connects again.
- While a send or a sync runs, Read again is refused with a notice to try again when it has ended.
- If the folder was moved or deleted, Read again is refused (`not_read`). Load the folder again
  instead.

An add-on loaded from a file cannot be read again. Over an installed `.kbooksaddon` of the same id
and version, a folder whose files differ is refused (`same_version`): raise the version, or remove the
one you installed from the file first.

## When a folder is refused

The app shows one small dialog: **This add-on was not installed**, the reason in the app's words, and
"Nothing of it was kept on this computer." Nothing of the folder is kept and nothing of it has run.

The reason comes from a code, and many codes carry a detail that the dialog shows after the reason in
the package's own spelling (cleaned of invisible characters and cut short):

- a file's path in the package, for `bad_name`, `file_kind`, `not_text`, `hidden_text`, `missing`;
- the field of `addon.json`, as a path (`name.en`, `permissions.network.hosts[0]`, `provides[1].entry`),
  for `manifest_field`. The dialog names the field, not what is wrong with it: read that field's rules
  in [manifest.md](manifest.md);
- the locale file, and the key when there is one (`locales/en.json: setting.server`), for `words`;
- the version of Koona Books the manifest asks for (`min_app`), or `schema` and its number, for
  `newer_app`.

These are every code and what the person reads. A detail stands where the words say _detail_:

<!-- generated:ts:refused-words -->
| Code | What the person reads |
| --- | --- |
| `not_a_package` | This is not an add-on file. |
| `too_large` | The file is larger than an add-on may be (2 MB). |
| `too_many_files` | It holds more files than an add-on may (64). |
| `encrypted` | It is locked with a password. |
| `bad_name` | It holds a file whose name is not allowed: _detail_ |
| `file_kind` | It holds a file of a kind an add-on may not have: _detail_ |
| `not_text` | A text file in it cannot be read: _detail_ |
| `hidden_text` | A file in it holds characters that cannot be seen: _detail_ |
| `missing` | A file it needs is not in it: _detail_ |
| `words` | Its own words are not in order: _detail_ |
| `newer_app` | It needs a newer Koona Books: _detail_ |
| `manifest` | Its description (addon.json) cannot be read. |
| `manifest_field` | Its description (addon.json) is not in order: _detail_ |
| `reserved_id` | It uses an id that belongs to the add-ons that come with Koona Books. |
| `reserved_name` | It calls itself or its author Koona. Koona’s own add-ons come with the app, never as a file. |
| `client_taken` | It would sign you in as Koona Books. An add-on from a file signs in under a name of its own. |
| `nothing_to_run` | This version of Koona Books has no use for what it adds. |
| `same_version` | This version is already installed, with other contents. A changed add-on needs a new version number. |
| `does_not_start` | Its script does not start. |
| `not_kept` | It could not be saved on this computer. |
| `not_read` | It could not be read. It may have been moved or removed. |
| `changed` | Something changed while you were reading. Choose the file again. |
| `busy` | A send or a sync is under way. Try again when it has ended. (a short notice, not the dialog) |
| `from_file_off` | Add-ons from a file are turned off. |
| `not_removed` | Its folder could not be removed. Close what has it open and try again. |
| `gone` | This add-on is no longer here. |
| `checked_id` | This add-on is installed from Koona’s list. Remove it before installing it from a file. |
| `stale` | As `changed` |
| `no_offer` | As `changed` |
| `no_data_folder` | As `not_kept` |
| `not_added` | As `gone` |
| `not_a_folder` | As `gone` |
| `already` | _name_ _ver_ is already installed (a short notice, not the dialog) |
| `device_profiles.taken`, a reader the app knows | It claims a reader Koona Books already knows: _detail_ |
| `device_profiles.taken`, a reader of another add-on | It claims a reader that _addon_ already adds: _detail_ |
| `device_profiles.<code>` | Its file of readers is not one Koona Books reads: _code_ · _field_ |
| Any other code | Koona Books could not do this. |
<!-- /generated -->

`file_kind` with no detail is a folder you picked that is a link, or not a folder. For the codes under
`device_profiles.`, see [reader-profiles.md](reader-profiles.md).

## The log

An add-on loaded from a folder or a file has a **Log** row on its page while the switch is on: the last
lines its script wrote, and **Open the log**. The log's dialog shows every line kept, the oldest first,
each with its time, then its level (`info`, `warn` or `error`) or "Koona Books" for the app's own
lines, then its text. **Copy** puts the lines on the clipboard as text, one a line, and **Clear**
empties the log.

- A script writes a line with `koona.log(level, text)` ([host-api.md](host-api.md)). The app cleans it:
  a line end, a tab or another control character becomes a space, and a character nobody sees is left
  out. Then it is cut to the cap.
- The log is **kept in memory only**, while the app runs. Nothing of it is written to disk, and it is
  gone when Koona Books quits. Removing the add-on empties it too.
- The caps are in [limits.md](limits.md) ("The log"): the lines one call may write, the length of a line,
  and how many lines and how much text are kept for one add-on. Past them the oldest lines go, and the
  dialog says how many are no longer kept.
- The log is kept by the add-on's id, so lines written while a folder was read (the API check) are
  there once it is installed.

Beside your lines stand the app's own, about each job: that it began, and how it ended. A script
cannot write one of these, so nothing in the log can read as the app's words when it is yours. This is
how the log words them:

<!-- generated:ts:log-words -->
| The line | What the log shows |
| --- | --- |
| `job.began:send` | Sending a book began |
| `job.began:check` | Testing the connection began |
| `job.began:list` | Reading the folder |
| `job.began:sync` | Syncing reading |
| `job.began:browse` | Shown as the code itself |
| `job.began:search` | Shown as the code itself |
| `job.began:info` | Shown as the code itself |
| `job.began:covers` | Shown as the code itself |
| `job.began:action` | Shown as the code itself |
| `job.began:export` | Shown as the code itself |
| `job.began:import` | Shown as the code itself |
| `job.ended:ok` | It ended: done |
| `job.ended:cancelled` | It ended: it was stopped |
| `job.ended:broken` | It ended: the script stopped with an error |
| `job.ended:denied` | It ended: the script stopped with an error |
| `job.ended:limits` | It ended: the script stopped with an error |
| `job.ended:<code>`, any other code | It ended: it did not work |
| `api_unknown:<name>:<file>` | Its script uses _name_ in _file_, which Koona Books does not have |
| `api_above_level:<name>:<file>` | Its script uses _name_ in _file_, which needs a higher API level than its manifest gives |
<!-- /generated -->

When your script answered `{ error = "<code>" }`, the log says only "it did not work"; the place
where the job ran shows your words for the code ([words.md](words.md)).

## Turned off after failing

An add-on from a folder or a file is turned off by the app after this many jobs in a row whose script
failed:

<!-- generated:strikes -->
3
<!-- /generated -->

A failure of the script is an error of its own or an answer outside the contract (`broken`), running out
of time or memory (`limits`), or reaching for something its permissions do not give (`denied`). A reader
that does not answer, a service that refuses, or the person pressing Stop never counts. A job that ends
well with nothing failing starts the count again, and one send of several books counts once.

The list then says "Off · Keeps failing", and the page has a row **Turned off** with **Turn on again**,
with the last errors below it. **Turn on again**, or reading a changed folder again, turns it on and starts
the count from nothing. An add-on that comes with the app is never turned off this way.

If the app's copy of the add-on's files is missing or no longer the one that was installed, the page says
**Not usable**: it runs nothing until you read the folder again or remove it.

## Removing

**Remove** on the **Came from** row asks first. It deletes the app's copy of the add-on, its settings,
its passwords and its sign-in, its log and its last errors, and a reader it reaches leaves Devices. What
it already brought into the library stays, and so do the books on a reader. It cannot be undone. Your
folder is not touched. Removing works with the switch off too, and is refused while a send or a sync
runs.

## Where each kind shows up

Once loaded, each kind is used where the same kind that comes with the app is used:

| It adds | Where to try it |
| --- | --- |
| A send target | In Devices, **+** (Add a device), then the add-on's name; or, while the add-on has no reader yet, on its page, **Your readers**, **Add a reader**. Both open the form with your title, your text and your fields, and **Test connection** (`check`). The reader is then in Devices, and the book's menu has **Send to** it (`send`, and `list` when the target can list). |
| Reader profiles | The readers it describes are recognized when such a reader is plugged in, and its page names them. This needs the device itself. |
| A reading sync | Its switch starts the setup: **Connect** for a sign-in in the browser, or the server's form. Then the **Reading** row on its page, with **Sync now**. |
| An import source | Turn it on with its switch. Then **Add books**, **From a catalog**. |
| Book information | Turn it on with its switch. Then the book's menu: **Find information** and **Find cover**, or **Find information** for several selected books. |
| A book action | The book's menu, in the add-on's group. |
| A list exporter | **Save book list** in the book's menu: it is one of the formats. |
| A list importer | On its page, **Reads from a file**, **Choose file**. |

What you cannot exercise from a folder today:

- **An import source whose catalog has an address the person types.** The form for a new catalog opens
  for the first import source the app offers, and the catalog add-on that comes with the app comes
  first while it is offered. It is offered while it is on, and while it has never been turned on:
  until the person turns it on and then off on its page, **Add a catalog** opens that add-on's
  form, not yours. An import source with one fixed catalog
  (no address to type) is listed under **From a catalog** once it is on.
- **Reader profiles** without the reader they describe.
- **A sign-in** without an application registered at the service under your own `client_id`.
- **What changed in this version** (`changes`): the app does not show it for an add-on from a folder
  or a file ([words.md](words.md)).
