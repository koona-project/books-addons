# Reader profiles

A reader profile tells Koona Books what a reader is when the person connects it as a drive: by USB
cable, or by putting its memory card into the computer. With it, Koona Books knows the reader by
itself, sends it the formats it reads, converts the others, puts books where the reader looks for them,
and never writes into the reader's own folders.

Reader profiles are data, not a script. An add-on names a `.json` file of profiles; Koona Books reads
it when the add-on is installed and each time its readers are gathered. Nothing of it runs, so it
reaches nothing: no network, no file on the computer, no secret.

The included add-on Xteink memory card is reader profiles alone:

<!-- generated:file ../examples/xteink-card/profiles.json -->
```json
{
  "schema": 1,
  "profiles": [
    { "id": "x4", "name": "Xteink X4",
      "markers": [[".crosspoint"]],
      "formats": ["epub", "txt"], "converts": ["epub"],
      "pattern": "{author}",
      "protected": [".crosspoint"] }
  ]
}
```
<!-- /generated -->

To send to a reader over the person's network instead, you need a script: see
[send-target.md](send-target.md).

## The manifest

Reader profiles are a provides entry of the type `device_profiles` in an add-on of the category `send`:

```text
{ "type": "device_profiles", "id": "example", "data": "profiles.json", "readers": ["mini", "max"] }
```

| Field | What it is |
| --- | --- |
| `id` | The entry's id, as every entry has one ([manifest.md](manifest.md)) |
| `data` | The file of profiles in the package: a `.json` file, not under `locales/` |
| `readers` | The ids of the profiles the file holds: every one, each once, and no other |

An add-on has at most one `device_profiles` entry. The package is refused when `readers` and the ids in
the file differ (`provides[0].readers`). Each reader is a code the person agrees to
(`provides.device_profiles:example.reader:mini`), so an update that adds a reader asks the person again,
and one that changes only what a reader is (its name, formats, folders, markers) does not
([permissions.md](permissions.md)).

Reader profiles alone ask for nothing. Their add-on has no network permission, no secrets and no
settings: nothing would use them. This manifest is accepted:

```json
{
  "schema": 1,
  "id": "org.example.reader-card",
  "version": "0.1.0",
  "api": 1,
  "min_app": "0.1.0",
  "name": { "en": "Example Reader card" },
  "summary": { "en": "Knows the memory card of an Example Reader" },
  "category": "send",
  "author": { "name": "Your Name" },
  "license": "MIT",
  "permissions": {},
  "privacy": { "sends": [], "collects": [] },
  "provides": [
    { "type": "device_profiles", "id": "example", "data": "profiles.json", "readers": ["mini", "max"] }
  ]
}
```

The same profiles with the network permission of a send target, and no send target, are refused:

<!-- sample:manifest-refused send permissions.network -->
```json
{
  "provides": [
    { "type": "device_profiles", "id": "example", "data": "profiles.json", "readers": ["mini"] }
  ]
}
```

Beside a send target, in the same add-on, they are fine. The add-on then asks for what the send target
needs and nothing more (see [send-target.md](send-target.md)):

<!-- sample:manifest-part send -->
```json
{
  "provides": [
    { "type": "send_target", "id": "reader", "entry": "send.lua",
      "formats": ["epub", "pdf"], "converts": ["epub"], "max_file_mb": 100, "can_list": true },
    { "type": "device_profiles", "id": "example", "data": "profiles.json", "readers": ["mini"] }
  ]
}
```

The words of an add-on of reader profiles are `does`, `works` and `changes` ([words.md](words.md)). A
reader's name comes from the file and is the same in every language.

## The file

```text
{ "schema": 1,                       required, 1
  "profiles": [ { ... }, ... ],      required, one profile at least
  "comment": ... }                   optional, any value, not read
```

The file is read strictly: a key it does not know, a key named twice, a value of the wrong type, or any
one rule below broken refuses the whole file, and nothing in it is repaired. Its text is checked as
every text file of a package is (UTF-8, nothing invisible); its size is in [limits.md](limits.md).

This file is taken (with the add-on id `org.example.reader-card`, the readers are
`org.example.reader-card/mini` and `org.example.reader-card/max` in Koona Books):

<!-- sample:profiles -->
```json
{
  "schema": 1,
  "comment": "The Example Reader keeps its settings in .example-reader; the Max also has Notes.",
  "profiles": [
    { "id": "mini", "name": "Example Reader Mini",
      "markers": [[".example-reader"]],
      "formats": ["epub", "pdf", "txt"], "converts": ["epub"],
      "folder": "Books", "pattern": "Books/{author}",
      "protected": [".example-reader", "System"],
      "max_path": 200 },
    { "id": "max", "name": "Example Reader Max",
      "markers": [[".example-reader", "Notes"]],
      "formats": ["epub", "pdf"] }
  ]
}
```

### A profile, field by field

| Field | Required | Default | What it is |
| --- | --- | --- | --- |
| `id` | yes | | `[a-z][a-z0-9_-]`: a lower-case letter first, then lower-case letters, digits, `_` and `-`. Unique in the file |
| `name` | yes | | The reader's name, as the person sees it |
| `formats` | yes | | The formats the reader reads, the one it reads best first. One at least, each once |
| `converts` | no | none | The formats Koona Books may convert a book to for this reader. Each once |
| `usb_vendors` | no | none | USB vendor ids that are this reader: four hex digits each (`"2237"`) |
| `markers` | no | none | Sets of names at the drive's top that are this reader |
| `folder` | no | `""`, the top | The folder below the drive's top that books go in |
| `pattern` | no | the app's | The folder pattern a send starts with, from the drive's top |
| `max_path` | no | see the block below | The longest path below the drive's top the reader takes, in characters |
| `protected` | no | none | Names at the drive's top that Koona Books never writes into |
| `models` | no | none | Model numbers and their names |
| `comment` | no | | Any value; not read |

The caps of each field (how many, how long) are in the block at the end of this page.

### The rules each field is held to

**`name`.** Text a person reads: not empty, no space at either end, no control, direction, zero-width
or other invisible character, and at least one letter or digit. It may not read as the name of a reader
Koona Books knows by itself (`Kobo`, `Kindle`, `PocketBook`, `Tolino`, `Android`), in any letters: a
look-alike spelled with a Cyrillic `о` is that name too. It may not hold "Koona".

**`formats`.** Each one of the formats Koona Books knows, written as the block at the end of this page
writes it (`fb2.zip` has its dot).

**`converts`.** Each a format Koona Books makes (`epub`, `kepub`, `azw3`), and one that is also in
`formats`: a conversion to a format the reader does not read is refused. Koona Books makes EPUB from
FB2, and KEPUB and AZW3 from EPUB or FB2.

For each book, Koona Books goes down `formats` in order and stops at the first format it can give: the
book's own file in that format, a copy converted earlier, or, when the format is in `converts`, a
conversion now.

**`usb_vendors`.** Four hex digits, in either case (kept in lower case), each once, and no two profiles
of the file with the same one. The ids of common card readers and USB storage chips are refused
(`reserved`): a memory card in a card reader shows the chip maker's id, never the reader's, so a profile
claiming one would take every such drive. Those ids are Realtek's, Genesys Logic's, SanDisk's, Alcor
Micro's, Super Top's, Silicon Motion's, Phison's, Kingston's, JMicron's, ASMedia's, Gembird's and
Transcend's commonest.

**`markers`.** A list of sets; each set is a list of names. A drive is this reader when every name of
one set is at its top, as a folder or a file. The rules:

- A name is one plain folder name, a leading dot allowed (`.example-reader`, `Notes`): no `/` or `\`,
  no drive, not `..`, nothing Windows or macOS would refuse or change, no Windows device name.
- No name twice in a set, without case.
- A set of one name must be a dot name. One plain folder (`Books`, `documents`) is on many drives, so a
  set without a dot name has two names at least.
- No set twice, in the profile or in the file: two sets with the same names, in any order and any case,
  are the same set.

**`folder`.** `""` (the top) or up to the levels in the block below, joined by `/`: no `/` at the start
or the end, no empty part, each part a plain folder name with no leading dot, no `~` followed by a digit
anywhere, and no part that the profile protects (see `protected`). It must leave room below it for a
file's name within `max_path`.

**`pattern`.** The folders a send puts each book in, as the person writes them in Send: the whole path
from the drive's top, with the tokens `{author}`, `{series}` and `{language}`, written exactly so.

- Parts joined by `/`, at most the levels and the characters in the block below. No `\`, no `:`, no
  empty part, so no `/` at the start or the end.
- The text around the tokens follows the rules of a folder name: no leading dot, no `..`, no `~`
  followed by a digit, nothing Windows or macOS would change.
- A first part without a token may not be a name the profile protects.
- With a `folder`, the pattern lies in it: it starts with the folder and a `/` (`"folder": "Books"`,
  `"pattern": "Books/{author}"`). Otherwise it is refused (`not_allowed`).
- Koona Books fills it with hostile names (`../../.kobo`, `/etc`, `C:\x`) when it reads the file: the
  path must still stay inside the drive and outside every protected folder.

A send starts with the pattern the person used last for this reader; else this pattern; else
`<folder>/{author}`. The person can change it in Send.

**`max_path`.** A whole number in the range of the block below. Koona Books shortens a book's file
name so that its path below the drive's top fits.

**`protected`.** Names at the drive's top, each one plain folder name with a leading dot allowed, each
once without case. Koona Books never writes into them. These are always protected, for every reader:
any name that starts with a dot, any name shaped like a Windows short name (`CROSSP~1`, which is
`.crosspoint` on a memory card), `.crosspoint`, `System Volume Information`, `$RECYCLE.BIN` and
`LOST.DIR`. A profile adds to them; it cannot take one away.

**`models`.** An object of model numbers to model names, each text a person reads: not empty, no space
at either end, nothing invisible, at least one letter or digit.
Koona Books reads a model number only from a Kobo's own files, so for an add-on's reader `models` is
checked and changes nothing.

### What a profile cannot set

A profile says nothing of these, and has the safe value of each:

- How the reader is reached: always as a drive (a USB drive or a memory card), never over MTP. A reader
  that shows itself to Windows as a phone does is not recognized by a profile.
- The reader's own record of what was read on it: never read.
- Reading each file back after a send: off.
- "Tested": an add-on's reader is never marked tested by Koona Books.
- Formats the person ticks: the profile's `formats` are used as they are.
- A key outside the table above: the file is refused.

## How a reader is recognized

When a drive appears, Koona Books asks the profiles in this order and takes the first that answers:

1. The readers Koona Books knows by itself, by USB vendor id, then by markers.
2. The add-ons' readers, by USB vendor id.
3. The add-ons' readers, by markers: of all the profiles with a set whose names are all on the drive,
   the one whose set has the most names; of two as large, the one whose add-on was turned on first.

So a profile is recognized by `usb_vendors`, by `markers`, or by both. With the sample above, a card with
`.example-reader` at its top is the Mini, and one with `.example-reader` and `Notes` is the Max.

A profile with neither is never recognized by itself. It is offered by name: when the person sets up a
drive that no profile knows ("Use as e-reader"), the add-ons' readers are among the readers to pick
from.

When the add-ons' readers change (an add-on turned on, off, added, removed or updated), Koona Books
looks at the connected drives again.

## Claims and clashes

A USB id, a marker set and a name are claims: two readers may not hold the same one. When an add-on is
offered (from a file, a folder or Koona's checked list), before the person says yes, its file is read
and its claims are checked against the readers Koona Books knows by itself and those of the add-ons
that are on. It is refused when one of its profiles has:

- a USB vendor id any of those readers has;
- a marker set that holds every name of a set of a reader Koona Books knows by itself (a set
  `[".kobo", "Books"]` is a Kobo's, since a Kobo is asked first and is known by `.kobo` alone);
- a marker set the same as one of another add-on's readers (a larger set is no clash: the reader whose
  set has the most names is the one recognized);
- the name of another add-on's reader, in any letters.

The person sees which claim and whose reader holds it. The add-on's own earlier version is not counted:
an update may keep its readers' claims.

The add-ons' readers are gathered in the order their add-ons were turned on, and of two that claim the
same thing the earlier keeps it. An add-on whose readers clash with an earlier one's, or whose file is
refused, after it got in some other way (by an update) is not refused: its readers are simply not used,
and its page says why.

## What the person sees

- The reader in Devices, under the drive's own label, or the profile's name when the drive has none.
  On its page: "From the add-on" and the add-on's name.
- Sends to it as to any e-reader: the plan, the conversions, the folder, the queue.
- When an update adds a reader, the person is asked again and sees that reader's name.
- A reader set up under a profile whose add-on is then turned off, removed, refused, or no longer has
  that profile, is treated as another reader (a plain drive), and its page says why. Its records, its
  books and its folder are kept, and it is that reader again when the add-on is back.
- A file Koona Books does not read is refused with the field and the reason
  (`profiles[1].markers[0][2]`, `bad_format`).

## Limits

The size of the file is in [limits.md](limits.md) ("A file of reader profiles"). The rest:

<!-- generated:limits-profiles -->
| Limit | Value |
| --- | --- |
| Profiles in one file | 1 to 8 |
| A profile's `id` | 32 characters |
| A profile's `name` | 60 characters |
| `formats` | 11, each one of: `kepub`, `epub`, `fb2`, `fb2.zip`, `pdf`, `mobi`, `azw3`, `txt`, `xtc`, `bmp`, `fbz` |
| `converts` | each one of: `epub`, `kepub`, `azw3` |
| `usb_vendors` | 8 |
| `markers` | 4 sets of 4 names |
| `protected` | 16 |
| `models` | 64 |
| A model's code | 32 characters |
| A model's name | 60 characters |
| `max_path` | 100 to 400; 240 when left out |
| Levels of `folder` and of `pattern` | 4 |
| `pattern` | 200 characters |
| One part of a path (a marker, a protected folder, a part of `folder`) | 60 characters |
<!-- /generated -->
