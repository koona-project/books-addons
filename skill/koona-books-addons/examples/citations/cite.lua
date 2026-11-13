-- Citations: "Copy citation" for up to 100 books, and a list saved as BibTeX.
--
-- The citation is one plain style, one book a line:
--   Authors by their sort form, joined with "; ". Title: Subtitle. Publisher, Year. ISBN.
--   Tolstoy, Leo. War and Peace. Penguin Classics, 2007. ISBN 9780140447934.
-- A part the book does not have is left out. Nothing here reaches the network.

local cite = {}

-- The book's authors (not its translators or editors), each as the library sorts the name.
local function authors(book)
  local out = {}
  for _, person in ipairs(book.authors) do
    if person.role == "author" then
      out[#out + 1] = person.sort
    end
  end
  return out
end

local function year(book)
  return book.published and book.published:sub(1, 4)
end

-- The book's first ISBN, or nil. Every kind of identifier is a list of values, also for one.
local function isbn(book)
  local all = book.identifiers.isbn
  return all and all[1]
end

local function title(book)
  if book.subtitle then
    return book.title .. ": " .. book.subtitle
  end
  return book.title
end

-- ---- Copy citation ---------------------------------------------------------------------------

-- A part ends with a full stop, unless it already ends with one (or with ? or !).
local function sentence(text)
  if text:match("[%.%?!]$") then
    return text
  end
  return text .. "."
end

function cite.run(ctx, books)
  local lines = {}
  for _, book in ipairs(books) do
    local parts = {}
    local names = authors(book)
    if #names > 0 then parts[#parts + 1] = sentence(table.concat(names, "; ")) end
    parts[#parts + 1] = sentence(title(book))
    local where = {}
    if book.publisher then where[#where + 1] = book.publisher end
    if year(book) then where[#where + 1] = year(book) end
    if #where > 0 then parts[#parts + 1] = sentence(table.concat(where, ", ")) end
    if isbn(book) then parts[#parts + 1] = "ISBN " .. isbn(book) .. "." end
    lines[#lines + 1] = table.concat(parts, " ")
  end
  return { text = table.concat(lines, "\n") }
end

-- ---- BibTeX ------------------------------------------------------------------------------------

-- The characters BibTeX reads as its own, written so that they print as themselves.
local ESCAPED = {
  ["\\"] = "\\textbackslash{}", ["{"] = "\\{", ["}"] = "\\}", ["%"] = "\\%", ["&"] = "\\&",
  ["$"] = "\\$", ["#"] = "\\#", ["_"] = "\\_", ["^"] = "\\^{}", ["~"] = "\\~{}",
}

local function escaped(text)
  return (text:gsub("[\\{}%%&%$#_%^~]", ESCAPED))
end

-- A key is the first author's family name in plain letters, and the year: tolstoy1869. A
-- name in another alphabet, or no author, gives "book". A key already used in the file gets
-- a number: tolstoy1869-2.
local function key(book, used)
  local first = authors(book)[1] or ""
  local base = (first:match("^[^,]*"):lower():gsub("[^a-z]", "")) .. (year(book) or "")
  if not base:match("^[a-z]") then
    base = "book" .. base
  end
  local unique, n = base, 1
  while used[unique] do
    n = n + 1
    unique = base .. "-" .. n
  end
  used[unique] = true
  return unique
end

-- BibTeX splits the author field at the word "and": a name that holds it ("Simon and
-- Schuster") is written in braces of its own, so it stays one name.
local function person(name)
  if name:lower():find("%sand%s") then
    return "{" .. escaped(name) .. "}"
  end
  return escaped(name)
end

function cite.write(ctx, books)
  local entries, used = {}, {}
  for _, book in ipairs(books) do
    local fields = {}
    -- `value` is written as it is: escape it first.
    local function field(name, value)
      if value then fields[#fields + 1] = "  " .. name .. " = {" .. value .. "}," end
    end
    local names = {}
    for i, name in ipairs(authors(book)) do
      names[i] = person(name)
    end
    field("author", #names > 0 and table.concat(names, " and ") or nil)
    -- The title in a second pair of braces: a style then keeps its capitals as written.
    field("title", "{" .. escaped(title(book)) .. "}")
    field("publisher", book.publisher and escaped(book.publisher))
    field("year", year(book) and escaped(year(book)))
    field("isbn", isbn(book) and escaped(isbn(book)))
    entries[#entries + 1] = "@book{" .. key(book, used) .. ",\n" .. table.concat(fields, "\n") .. "\n}\n"
  end
  return { text = table.concat(entries, "\n") }
end

return cite
