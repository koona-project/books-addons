-- Book links: "Find on Hardcover" and "Find on Open Library" for Koona Books.
--
-- One file serves both entries of addon.json; ctx.id says which one the person picked. Each
-- gives a link to the site's own search, and Koona Books opens it in the person's browser.
-- Each entry names its site in addon.json ("host"): a link to any other host is not opened.
-- Nothing is sent from here: a tools add-on reaches no network.

-- The search page of each site, by the entry's id. The words to find go at the end.
local SEARCH = {
  hardcover = "https://hardcover.app/search?q=",
  openlibrary = "https://openlibrary.org/search?q=",
}

-- The most characters of search words a link carries. A link has a length limit (Koona Books
-- opens none over 2,000 bytes), and a few words find a book as well as many.
local MOST = 200

-- The first `most` characters of `text` (whole characters: a letter may be several bytes).
local function cut(text, most)
  if utf8.len(text) <= most then
    return text
  end
  return string.sub(text, 1, utf8.offset(text, most + 1) - 1)
end

-- What to search for: the book's first ISBN when it has one, because it finds that very
-- edition; otherwise the title and the first author. Nothing when the book has neither.
-- Every kind of identifier is a list of values, also for one.
local function words(book)
  local isbn = book.identifiers.isbn
  if isbn and isbn[1] then
    return isbn[1]
  end
  if book.title == "" then
    return nil
  end
  local first = book.authors[1]
  if first then
    return book.title .. " " .. first.name
  end
  return book.title
end

local links = {}

-- A link action is always given one book.
function links.run(ctx, books)
  local find = words(books[1])
  if not find then
    return { error = "missing" }
  end
  return { link = SEARCH[ctx.id] .. koona.url.encode(cut(find, MOST)) }
end

return links
