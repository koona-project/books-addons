# Import starter

A small add-on of the category `import` to copy and rename. It adds one catalog to Add books (From
a catalogue, as the app labels it): the Example catalog at `api.example.org`, a made-up service that
answers JSON.

- **Browse**: the catalog's start, its shelves, and its books, a page at a time.
- **Search**: what the catalog finds for the words you type.
- **Add**: you tick books, and Koona Books downloads their files from the catalog and adds them
  through the usual import.

## Files

- `addon.json`: the manifest. Change `id`, `name`, `summary` and `author` first, and put your
  catalog's host in `permissions.network.hosts`.
- `catalog.lua`: the import source: `check`, `browse` and `search`.
- `locales/en.json`: the add-on's own words: what it does, the name of its catalog, and its
  words for the codes `not_found`, `refused` and `not_understood`.
- `LICENSE.md`: the MIT license. Put the year and your name in place of `[year]` and `[fullname]`;
  an add-on whose license still holds them is not taken on Koona's checked list.

## The catalog it expects

```text
GET /v1/shelves/root                 the start
GET /v1/search?q=<words>             a search
each answers:
{ "title": "Example Library",
  "shelves": [ { "title": "Newest", "summary": "...", "path": "/v1/shelves/new", "count": 12 } ],
  "books": [ { "title": "...", "authors": [ "..." ], "summary": "...", "language": "eng",
               "cover": "/covers/7.jpg", "web": "/books/7",
               "files": [ { "type": "epub", "path": "/files/7.epub", "bytes": 512000 } ] } ],
  "next": "/v1/shelves/root?page=2" }
```

## What it may do

It may reach `api.example.org` and nothing else. The pages you open and the words you search for go
there. Koona Books downloads a book's file and its cover itself, and only from `api.example.org`; a
file anywhere else is shown with its site's name, for you to open in your browser. The add-on never
sees a book file, your library or anything else on your computer.
