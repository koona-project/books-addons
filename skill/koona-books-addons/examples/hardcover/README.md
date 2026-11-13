# Hardcover

Keeps what you are reading and what you have read in step between Koona Books and your shelf on
hardcover.app, both ways.

## Before you sync

1. In Koona Books: Add-ons, Hardcover, Connect. Hardcover opens in your browser.
2. Approve Koona Books there. Koona Books never asks for your Hardcover password and never sees it.
3. Back in Koona Books: Sync now shows what would change, here and on Hardcover, before anything does.

## What it does

- Reads your shelf: the books you are reading and the books you have read, how far you are and the
  day you finished.
- Sends the same for the books in your library, when the reading here is the newer one.
- Finds a book by its ISBN, or by Hardcover's own id if your library holds one. A book with neither
  is not sent. A book on your shelf that only looks like one of yours is shown for you to confirm.
- Leaves alone what you set aside on Hardcover (did not finish, ignored) and never adds a book to
  "want to read".

Hardcover counts progress in pages of an edition; Koona Books keeps a share of the book. The share
becomes a page of the edition on your shelf and back, so the two can differ by a page.

## What it may do

It may reach api.hardcover.app, signed in as you. It sends the reading status, the progress and the
finished day of the books you sync, with their ISBNs. Titles and the files themselves stay on your
computer. Your shelf on Hardcover is shown to others as your settings there say.

## Disconnecting

Disconnect in Add-ons signs Koona Books out at Hardcover. You can also remove it on Hardcover, under
Authorized apps.

Hardcover's API is in beta and may change.
