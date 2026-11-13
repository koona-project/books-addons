-- Tools starter: the list exporter of addon.json, a book list saved as Markdown.
--
-- Koona Books calls write(ctx, books) with the books the person chose in Save book list, and
-- saves the text it answers where the person's save dialog says, with the extension addon.json
-- names ("md"). The script never names the file or the folder. Nothing here reaches the network.
--
-- A file runs on its own (there is no `require`): what list.lua needs, it defines.

-- Markdown reads these characters as its own: a backslash in front prints them as they are.
local function escaped(text)
  return (text:gsub("[\\%[%]%*_`]", "\\%0"))
end

-- The authors' names joined with ", " (not the translators or the editors).
local function authors(book)
  local names = {}
  for _, person in ipairs(book.authors) do
    if person.role == "author" then
      names[#names + 1] = person.name
    end
  end
  return table.concat(names, ", ")
end

-- One line a book:
--   - **War and Peace** by Leo Tolstoy (2007)
--   - **Мастер и Маргарита**: Роман by Михаил Булгаков (2014), Азбука-классика 12
-- A field the book does not have is absent (nil), so each part is added only when it is there.
local function line(book)
  local out = "- **" .. (book.title ~= "" and escaped(book.title) or "Untitled") .. "**"
  if book.subtitle then
    out = out .. ": " .. escaped(book.subtitle)
  end
  local names = authors(book)
  if names ~= "" then
    out = out .. " by " .. escaped(names)
  end
  -- `published` is "1869", "1869-03" or "1869-03-01": the year is its first four characters.
  if book.published then
    out = out .. " (" .. book.published:sub(1, 4) .. ")"
  end
  -- A series has a name, and an index only when the library has one.
  if book.series then
    out = out .. ", " .. escaped(book.series.name)
    if book.series.index then
      out = out .. " " .. tostring(book.series.index)
    end
  end
  return out
end

local list = {}

function list.write(ctx, books)
  local lines = { "# Reading list", "" }
  for _, book in ipairs(books) do
    lines[#lines + 1] = line(book)
  end
  -- The text is all the app reads from the answer: a `name` or a `path` beside it is ignored.
  return { text = table.concat(lines, "\n") .. "\n" }
end

return list
