-- Tools starter: the two book actions of addon.json, "Copy as Markdown links" and "Find on
-- example.org".
--
-- One file serves both entries: each entry in addon.json names this file, and ctx.id says
-- which one the person picked. Koona Books calls run(ctx, books) and reads one key of the
-- answer, the entry's "gives" word: `text` for the copy, `link` for the search. A tools
-- add-on reaches nothing: no network, no file, no secret. The app copies the text, or opens
-- the link in the person's browser.

-- The search page of example.org. The words to find go at the end, encoded.
local SEARCH = "https://example.org/search?q="

-- The most characters of search words a link carries. Koona Books opens no link over its
-- length limit, and a few words find a book as well as many.
local MOST = 200

-- The first `most` characters of `text`, whole characters only (a letter may be several bytes).
local function cut(text, most)
  if utf8.len(text) <= most then
    return text
  end
  return string.sub(text, 1, utf8.offset(text, most + 1) - 1)
end

-- The names of the people who wrote the book. `authors` is always a list, maybe empty, and
-- holds translators, editors and illustrators too: each person's `role` says which.
local function authors(book)
  local names = {}
  for _, person in ipairs(book.authors) do
    if person.role == "author" then
      names[#names + 1] = person.name
    end
  end
  return names
end

-- What to search for: the book's first ISBN when it has one (it finds that very edition),
-- otherwise the title and the first author, otherwise nothing.
-- `identifiers` is always a table, and every kind in it is a list, also for one value.
-- `title` is always there, but may be empty.
local function words(book)
  local isbn = book.identifiers.isbn
  if isbn and isbn[1] then
    return isbn[1]
  end
  if book.title == "" then
    return nil
  end
  -- The first author, not a translator who may come first in the list.
  local first = authors(book)[1]
  if first then
    return book.title .. " " .. first
  end
  return book.title
end

-- The search link for a book, or nil when the book gives nothing to search by.
local function search_link(book)
  local find = words(book)
  if not find then
    return nil
  end
  return SEARCH .. koona.url.encode(cut(find, MOST))
end

-- Markdown reads these characters as its own: a backslash in front prints them as they are.
local function escaped(text)
  return (text:gsub("[\\%[%]%*_`]", "\\%0"))
end

-- One line of Markdown for a book: a link to its search page, then its authors.
--   - [War and Peace](https://example.org/search?q=9780140447934) by Leo Tolstoy
-- A book with nothing to search by gets its title alone.
local function line(book)
  local title = book.title ~= "" and escaped(book.title) or "Untitled"
  local link = search_link(book)
  local out = link and ("- [" .. title .. "](" .. link .. ")") or ("- " .. title)
  local names = authors(book)
  if #names > 0 then
    out = out .. " by " .. escaped(table.concat(names, ", "))
  end
  return out
end

local actions = {}

function actions.run(ctx, books)
  -- `books` is always a list, also for one book.
  if ctx.id == "search" then
    -- A link action is always handed exactly one book: the person clicked for that book.
    local link = search_link(books[1])
    if not link then
      -- A code, not a sentence: the app has words for `missing`, and the add-on may have its
      -- own (`error.missing` in its locale files).
      return { error = "missing" }
    end
    return { link = link }
  end
  -- "markdown_links": up to `max_books` books (addon.json), one line each.
  local lines = {}
  for _, book in ipairs(books) do
    lines[#lines + 1] = line(book)
  end
  return { text = table.concat(lines, "\n") }
end

return actions
