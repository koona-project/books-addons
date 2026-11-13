# Tools starter

A small add-on of the category `tools` to copy and rename. It adds three things to Koona Books:

- **Copy as Markdown links**, in the book's menu, for up to 100 books: one line a book, a link to the
  book's search page on example.org and its authors.

  ```text
  - [War and Peace](https://example.org/search?q=9780140447934) by Leo Tolstoy
  ```

- **Find on example.org**, in the book's menu for one book: opens example.org's search for the book in
  your browser, by its ISBN, or by its title and first author (a person whose role is `author`, not
  a translator or an editor).
- **Markdown list**, a format of Save book list: one line a book, with its title, subtitle, authors,
  year and series.

## Files

- `addon.json`: the manifest. Change `id`, `name`, `summary` and `author` first.
- `actions.lua`: both book actions. One file serves both entries; `ctx.id` says which one runs.
- `list.lua`: the list exporter.
- `locales/en.json`: the labels in the menu, and the add-on's own words for the code `missing`.
- `LICENSE.md`: the MIT license. Put the year and your name in place of `[year]` and `[fullname]`;
  an add-on whose license still holds them is not taken on Koona's checked list.

## What it may do

It reaches no network and no file on your computer. Koona Books hands it the books you pick, copies the
text for you, opens a link only when you click and only if it leads to example.org, and saves a list
where you say. What is in the link (the ISBN, or the title and author) goes to example.org when your
browser opens it.
