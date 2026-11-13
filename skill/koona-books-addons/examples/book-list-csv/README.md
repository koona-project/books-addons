# Book list as CSV

Saves a list of your books as a CSV file, which any spreadsheet opens, and reads such a file back to
mark books as read.

## What it does

- Writes one row a book, with the columns Title, Authors, Series, Series index, Language, Publisher,
  Published, ISBN, Tags, Status, Progress, Finished, Added and Favorite. Several authors or tags are
  joined with `; `.
- Writes a cell that starts with `=`, `+`, `-` or `@` with an apostrophe in front, so a spreadsheet
  shows it as text and never runs it. A cell that holds a comma, a semicolon, a tab or `|` is written
  in quotes, so a spreadsheet that splits cells by another of them still reads it as one cell.
- Reads a CSV file with those columns, in any order and in any case. Other columns are left alone.
  Cells may be separated by commas, semicolons or tabs: the first line tells which.
- Takes from each row the status (Unread, Reading, Finished, Set aside) and the day the book was
  finished, written as 2026-11-07 or 7.11.2026. A day written with slashes is not read (01/02/2026 is
  a day in January in some countries and in February in others): that row keeps its status and gets
  no date. Koona Books finds each book by its ISBN or by its title and authors, and shows you every
  change before anything is made.
- A spreadsheet may rewrite a long ISBN as a number when it saves the file (`9.78014E+12`); such
  rows are then found by their title and authors.

## What it may do

It reaches no network and no file of its own choosing. Koona Books hands it the books you picked and
saves the text where you say; for the other way, it reads only the file you pick and hands over its
text.

A first line that a spreadsheet left loose (a separator at its end, a column with no name) is read all
the same; the columns with no name are skipped.

## How it was checked

By Koona Books' own tests on 12 November 2026: a list written, read back, and a file from a
spreadsheet with its columns in another order.
