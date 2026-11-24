# Changelog

## 1.0.1 — 2026-11-24

- Finds books only. An item counts when Wikidata says it is a work of writing or an edition (P31: literary work, written work, version/edition/translation, book, novel and the other classes listed in `info.lua`), or an edition of (P629) such a work. Films, TV films and series, operas, characters and people of the same name are left out, and so are their posters among the covers.
- When the book has an author, a candidate whose authors (its own P50, or its work's) are known and are others is left out instead of being shown as "only the title matches". Names are compared in every language fetched, labels and aliases, in any word order; a spelling in another script is compared by its consonants in Latin letters. A candidate with no known author is kept only when no candidate is by the author asked for.
- The names of authors, publishers, series and genres are fetched with their aliases. An author whose name on Wikidata is exactly the library's is shown under that name, with the label among the other names.

## 1.0.0 — 2026-11-21

- First version: CC0 Wikidata Action API lookup by ISBN and title/author, multilingual titles, original titles, authors/translators/series resolution, and Wikimedia Commons cover links.
