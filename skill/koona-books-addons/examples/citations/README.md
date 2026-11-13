# Citations

Copies a citation of the books you pick, and saves a list of books as BibTeX.

## What it does

- Copy citation: up to 100 books at once, one a line, in one plain style:

  ```text
  Tolstoy, Leo. War and Peace. Penguin Classics, 2007. ISBN 9780140447934.
  ```

  The authors as your library sorts their names, joined with `; `; then the title and its subtitle;
  the publisher and the year; the ISBN. A part the book does not have is left out. Translators and
  editors are not named.
- BibTeX: one `@book` entry a book, with its authors, title, publisher, year and ISBN. Characters that
  BibTeX reads as its own (`{ } % & $ # _ ^ ~ \`) are written so that they print as themselves. Each
  entry's key is the first author's family name and the year (`tolstoy1869`), unique in the file.
  The title is written in a second pair of braces (`title = {{War and Peace}}`), so a style keeps its
  capitals as written, and a name that holds the word "and" (`{Simon and Schuster}`) is braced, so
  it stays one name.

## What it may do

It reaches no network and no file on your computer. Koona Books hands it the books you picked, copies
the text for you, or saves the file where you say.

## How it was checked

By Koona Books' own tests on 12 November 2026, with books in English and in Russian, a book with no
author or ISBN, and titles that hold BibTeX's own characters.
