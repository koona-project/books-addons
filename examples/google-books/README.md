# Google Books

Book information and covers for Koona Books from the keyless public Google Books Volumes API (`www.googleapis.com/books/v1/volumes`).

## What it does

- Looks a book up by ISBN first (`q=isbn:<digits>`), then by title and author (`q=intitle:<title>+inauthor:<author>`) with `langRestrict` for the book's preferred language and a cross-language fallback.
- Fetches full volume details on demand (`details`) for complete descriptions and larger cover links.
- Returns validated `https://books.google.com/` and `https://books.googleusercontent.com/` cover links; Koona Books downloads and checks every picture itself.
- Paced at 30 requests per minute (burst 2), off by default until turned on in Add-ons.
