# CrossPoint over Wi-Fi

Sends books from Koona Books to an Xteink X4 or X3 running CrossPoint, over your own Wi-Fi, without a
cable.

## Before you send

1. On the reader, open File Transfer and join your Wi-Fi.
2. The reader's screen shows its address, for example `http://192.168.1.20`. Type it as it is shown,
   or the numbers alone.
3. In Koona Books: Devices, +, CrossPoint over Wi-Fi. Test connection tells you whether the reader
   answers.

## What it does

- Sends EPUB and TXT files as they are. A book that has only an FB2 file is converted to EPUB by Koona
  Books first; a book in any other format is not sent to this reader, and the plan says why.
- Puts books into the folder you name (`/Books` unless you change it) and makes the folder when it is
  not there.
- Never writes over another book on the reader: when a book of the same name is there, yours goes
  beside it (`Dune (2).epub`). Only Koona Books' own earlier copy of the same book is replaced.

## What it may do

It may reach one device on your network, at the address you give, on port 80. It has no access to the
internet, to other devices, or to any file on your computer: Koona Books hands the reader each book
itself.

## Needs

CrossPoint 1.3 or newer.
