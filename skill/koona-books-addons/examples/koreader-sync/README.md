# KOReader sync

Keeps how far you are in a book in step between Koona Books and readers that use a KOReader
progress sync server: KOReader on any device, and Xteink readers running CrossPoint.

## Before you sync

1. On the reader, set up progress sync (KOReader: Progress sync. CrossPoint: KOReader Sync) and note
   the server, the user and the password.
2. In Koona Books: Add-ons, KOReader sync, Set up. Type the same server, user and password. Test
   tells you whether the server takes them.
3. Send books to the reader from Koona Books. Only a copy Koona Books sent can be synced: the server
   knows a book by a fingerprint of its file, and Koona Books keeps the fingerprint of what it sent.

## What it does

- Reads from the server how far each of those books was read, and offers to update your library.
- Sends the server how far you are here, when that is the newer reading.
- A book read to its last page counts as finished.

## What it may do

It may reach the one server you name, with the user and the password you give. It sends a
fingerprint of each book's file and how far you are in it. Titles, authors and the files themselves
stay on your computer.

## Not checked yet

The exact place in a book does not travel, only the share read. CrossPoint finds the place from the
share; what KOReader itself does with a place it cannot read is not known yet.
