# Wikidata

Multilingual book information and covers for Koona Books from Wikidata (`www.wikidata.org`, CC0 1.0 Public Domain Dedication) and Wikimedia Commons (`commons.wikimedia.org`).

## What it does

- Looks a book up by title and author (`action=query&list=search`) with fallback to entity search (`action=wbsearchentities`) in the book's preferred language and English.
- Fetches bounded entity batches with `languages=` filtering (`props=labels|claims` for matched items and `P629` parent works; `props=labels|aliases` only for referenced authors, translators, publishers, series, and genres).
- Keeps books only: an item whose `P31` is a work of writing or an edition (literary work, written work, version/edition/translation, book, novel and the other classes in `BOOK_CLASSES`), or an edition (`P629`) of such a work. Films, series, operas and characters of the same title are left out.
- When the query names an author, leaves out candidates whose authors (`P50` of the item or of its work) are known and are others, comparing every label and alias fetched in any word order and, across scripts, by consonants in Latin letters.
- Resolves works and editions (`P629`), multilingual titles (`P1476`), subtitles (`P1680`), original titles and languages (`P364`), authors (`P50`) with alternative spellings, translators (`P655`), editors (`P98`), illustrators (`P110`), publishers (`P123`), publication dates (`P577`), series and ordinal numbers (`P179` / `P1545`), genres (`P136`), ISBNs (`P212` / `P957`), and Wikimedia Commons cover links (`P18`).
- Paced at 30 requests per minute (burst 2), off by default until turned on in Add-ons.
