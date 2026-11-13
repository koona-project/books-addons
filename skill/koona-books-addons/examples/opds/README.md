# OPDS catalogues

Opens a book catalogue from Add books, so you can browse it, search it and add its books to your
library. A catalogue is a server you name: your own Calibre, Calibre-Web, Kavita, Komga or COPS at
home, or a public one such as Project Gutenberg.

## Adding a catalogue

1. Add books, From a catalogue.
2. Type the catalogue address as its server shows it, with the part after the slash
   (192.168.1.10:8080/opds). An address on the internet is reached by https only.
3. If the catalogue asks for them, type your user name and password. Test connection tells you
   whether the catalogue answers and takes them.

## What it does

- Reads the catalogue pages and shows their sections and books.
- Asks the catalogue for what you search.
- Tells Koona Books where a book file is. Koona Books downloads it, looks at what it really is and
  adds it through the usual import.

## What it may do

It may reach the one address you name for a catalogue, and nothing else. What you search for and
which pages you open go to that catalogue. Your user name and password for it are kept in the
keychain of your computer and are sent only to it. It never sees a book file, your library or
anything else on your computer.

## What it does not do

- Buy or borrow. A book that has no free file is listed, with a link to its page at the catalogue.
- Fetch from another site. When a catalogue keeps a file elsewhere, the book is listed with a link
  to open in your browser.
- OPDS 2 (the JSON kind) and sign-in by Digest. A Calibre content server that asks for a password
  over plain http uses Digest unless it is set to Basic.

## Not checked yet

Written from the OPDS 1.2 and OpenSearch 1.1 specifications. It has not met a real catalogue.
