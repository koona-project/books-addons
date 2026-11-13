# Example Shelf (a starter for a reading sync)

Keeps what you are reading and what you have read in step between Koona Books and your shelf on an
Example Shelf server, both ways. Example Shelf is a made-up service: this folder is a starting point
for a reading sync of your own.

## Before you sync

1. In Koona Books: Add-ons, Example Shelf, Set up.
2. Type the server, your user and your password. Test tells you whether the server takes them.
3. Save. Sync now reads your shelf and shows what would change, here and there, before anything does.

## What it does

- Reads your whole shelf on the server and offers to update your library from it.
- Tells the server how far you are here, when that is the newer reading, and adds a book to your
  shelf there by its ISBN.
- A book you set aside on the server is never changed by Koona Books.

## What it may do

It may reach the one server you name, with the user and the password you give. It sends the ISBN of
a book and how far you are in it. Titles, authors and the files themselves stay on your computer.

## Making it yours

- Change `id` in `addon.json` to one of your own (a reversed domain you control), and `name`,
  `summary`, `author`.
- Fill in `[year]` and `[fullname]` in `LICENSE.md`, or replace the file with the license you
  choose.
- Replace the requests in `sync.lua` with your service's own, and the words in `locales/en.json`.
- Write what changed in `CHANGELOG.md` with every version.
