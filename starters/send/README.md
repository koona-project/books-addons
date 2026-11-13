# Send starter

A small add-on of the category `send` to copy and rename. It sends books from Koona Books to an
"Example Reader", a made-up reader that takes books over HTTP on your own network while its Book
transfer screen is open.

## Before you send

1. On the reader, open Book transfer and join your Wi-Fi.
2. The reader's screen shows its address, for example `http://192.168.1.30`. Type it as it is shown,
   or the numbers alone, without a port.
3. In Koona Books: in Devices, **+** (Add a device), then **Example Reader over Wi-Fi** (the add-on's
   name). While the add-on has no reader yet, its page in Add-ons has the same form under **Your
   readers**, **Add a reader**. Test connection tells you whether the reader answers.

## What it does

- Sends EPUB and PDF files as they are. A book that has neither, but has an FB2, is converted to EPUB
  by Koona Books first; a book with neither and no FB2 is left out.
- Leaves out a book larger than 100 MiB.
- Puts books into the folder you name (`/Books` unless you change it).
- Never replaces a file on the reader unless it is Koona Books' own earlier copy of the same book.

## Files

- `addon.json`: the manifest. Change `id`, `name`, `summary`, `author` and the port first.
- `send.lua`: the three functions Koona Books calls, `check`, `list` and `send`. Change the pages and
  the answers to the ones your reader has.
- `locales/en.json`: the form's words (its title, what to do on the reader, the labels) and the add-on's
  own words for the codes `unreachable` and `not_a_reader`.
- `LICENSE.md`: the MIT license. Put the year and your name in place of `[year]` and `[fullname]`; an
  add-on whose license still holds them is not taken on Koona's checked list.

## What it may do

It may reach one device on your network, at the address you give, on port 8080. It has no access to the
internet, to other devices, or to any file on your computer: Koona Books hands the reader each book
itself.
