# Wikidata

Multilingual book information and covers for Koona Books from Wikidata (`www.wikidata.org`, CC0 1.0 Public Domain Dedication) and Wikimedia Commons (`commons.wikimedia.org`).

## What it does

- Looks a book up by title and author (`action=query&list=search`) with fallback to entity search (`action=wbsearchentities`) in the book's preferred language and English.
- Fetches bounded entity batches with `languages=` filtering (`props=labels|claims` for matched items and `P629` parent works; `props=labels` only for referenced authors, translators, publishers, series, and genres).
- Resolves works and editions (`P629`), multilingual titles (`P1476`), subtitles (`P1680`), original titles and languages (`P364`), authors (`P50`) with alternative spellings, translators (`P655`), editors (`P98`), illustrators (`P110`), publishers (`P123`), publication dates (`P577`), series and ordinal numbers (`P179` / `P1545`), genres (`P136`), ISBNs (`P212` / `P957`), and Wikimedia Commons cover links (`P18`).
- Paced at 30 requests per minute (burst 2), off by default until turned on in Add-ons.
