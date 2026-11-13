# Info starter

A small add-on of the category `info` to copy and rename. It is a source for Find information and
Find cover: it asks the Example catalog at `api.example.org`, a made-up service that answers JSON,
about one book.

- **Search**: by the book's ISBN when it has one, else by its title and first author.
- **Details**: the record's description, tags and series, when you look at a candidate.
- **Covers**: links to the covers of what the search found. Koona Books fetches the pictures.

## Files

- `addon.json`: the manifest. Change `id`, `name`, `summary` and `author` first, and put your
  service's host in `permissions.network.hosts` and its request limit in `pace`.
- `info.lua`: the source: `search`, `details` and `covers`.
- `locales/en.json`: what the add-on does, in its own words.
- `LICENSE.md`: the MIT license. Put the year and your name in place of `[year]` and `[fullname]`;
  an add-on whose license still holds them is not taken on Koona's checked list.

## The service it expects

```text
GET /v1/books?isbn=<isbn>&lang=<eng>
GET /v1/books?title=<title>&author=<name>&lang=<eng>
  { "books": [ { "id": "B12", "title": "...", "subtitle": "...", "language": "eng",
                 "authors": [ { "name": "...", "role": "author" } ], "publisher": "...",
                 "year": 2019, "isbn": "9780441013593",
                 "cover": { "url": "/covers/B12.jpg", "width": 600, "height": 900 } } ] }
GET /v1/books/B12
  { "description": "...", "tags": [ "..." ], "series": { "name": "...", "number": 1 } }
```

## What it may do

It may reach `api.example.org` and nothing else, no faster than its pace. For each book you look
up, its ISBN, or its title and first author, and the language to answer in go there. Koona Books fetches
the covers itself, and only from `api.example.org`. The add-on never sees a book file, your library
or anything else on your computer, and has no settings and no passwords.
