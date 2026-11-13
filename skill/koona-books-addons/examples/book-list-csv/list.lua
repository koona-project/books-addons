-- Book list as CSV: writes the library's books as a CSV file, and reads such a file back to
-- mark books as read in the library.
--
-- One file for the export and the import of addon.json: write() is called for the one,
-- read() for the other. Koona Books hands over the books, saves the text where the person
-- says, and reads the file the person picks. Nothing here reaches the network.

local COLUMNS = {
  "Title", "Authors", "Series", "Series index", "Language", "Publisher", "Published",
  "ISBN", "Tags", "Status", "Progress", "Finished", "Added", "Favorite",
}

-- The app's words for a reading state, and the ones written in the file.
local STATUS_WORDS = {
  unread = "Unread", reading = "Reading", finished = "Finished", set_aside = "Set aside",
}

-- The ways a spreadsheet writes the day a book was finished, ISO first. A date with slashes
-- is not read: 01/02/2026 is the 2nd of January in the United States and the 1st of February
-- in Britain, and a wrong day is worse than none. Such a row keeps its status and gets no date.
local DATES = { "yyyy-MM-dd", "yyyy-MM", "yyyy", "d.M.yyyy" }

local list = {}

-- ---- Writing -------------------------------------------------------------------------------

-- Names or words joined with "; ": a comma is already the file's own separator.
local function joined(items, field)
  local out = {}
  for _, item in ipairs(items) do
    out[#out + 1] = field and item[field] or item
  end
  return table.concat(out, "; ")
end

function list.write(ctx, books)
  local rows = {}
  for _, book in ipairs(books) do
    local series = book.series or {}
    rows[#rows + 1] = {
      Title = book.title,
      Authors = joined(book.authors, "name"),
      Series = series.name,
      ["Series index"] = series.index and tostring(series.index),
      Language = book.language,
      Publisher = book.publisher,
      Published = book.published,
      -- Every ISBN the library has for the book, joined as the authors are.
      ISBN = book.identifiers.isbn and joined(book.identifiers.isbn),
      Tags = joined(book.tags),
      -- The reading fields are there only when the person's reading goes with the list.
      Status = book.status and STATUS_WORDS[book.status],
      Progress = book.progress and (math.floor(book.progress * 100 + 0.5) .. "%"),
      Finished = book.finished_at,
      Added = book.added_at,
      Favorite = book.favorite and "Yes" or nil,
    }
  end
  -- The writer leaves an empty cell for a missing field, quotes a cell that holds a
  -- separator, and guards a cell that a spreadsheet would run as a formula.
  return { text = koona.csv.encode(rows, { header = COLUMNS }) }
end

-- ---- Reading -------------------------------------------------------------------------------

-- A cell as it was before the writer guarded it: one leading apostrophe before = + - @ goes.
local function unguarded(cell)
  if cell and cell:match("^'[=+%-@\t\r]") then
    return cell:sub(2)
  end
  return cell
end

-- The file's rows, and where each column is in a row, by its name in lower case ("ISBN",
-- "isbn"). The reader learns the names from the first line and picks the separator itself:
-- Excel in many countries writes ";" between cells.
local function columns(text)
  local ok, rows, names = pcall(koona.csv.decode, text)
  if not ok and tostring(rows):find("too_large") then
    return nil, "too_large"
  end
  -- The reader is strict about a header: every column has a name. Spreadsheets are not (a
  -- stray separator ends the first line, a column was left without a name). Such a file is
  -- read again as plain rows, and the first row is taken as the names.
  local plain = not ok
  if plain then
    ok, rows = pcall(koona.csv.decode, text, { header = false })
    if not ok then
      return nil, tostring(rows):find("too_large") and "too_large" or "not_a_list"
    end
    names = table.remove(rows, 1) or {}
  end
  local at = {}
  for i, name in ipairs(names) do
    -- A column with no name is skipped. One named twice could mean either: such a file is
    -- no list of ours.
    if name ~= "" then
      if at[name:lower()] then
        return nil, "not_a_list"
      end
      -- A row read with its header is keyed by name, a plain row by position.
      at[name:lower()] = plain and i or name
    end
  end
  if not (at.title or at.isbn) then
    return nil, "not_a_list"
  end
  return rows, at
end

local function status_of(word)
  word = (word or ""):lower():gsub("_", " ")
  for code, shown in pairs(STATUS_WORDS) do
    if word == shown:lower() then
      return code
    end
  end
  return nil
end

local function date_of(text)
  for _, pattern in ipairs(DATES) do
    local day = text and koona.date.parse(text, pattern)
    if day then
      return day
    end
  end
  return nil
end

function list.read(ctx, file)
  local rows, at = columns(file.text)
  if not rows then
    return { error = at }
  end
  local function cell(row, name)
    local text = unguarded(at[name] and row[at[name]])
    if text == "" then
      return nil
    end
    return text
  end
  local out = {}
  for _, row in ipairs(rows) do
    local title = cell(row, "title")
    -- The ISBNs of a cell, split by ";" as the authors are: a list, also for one.
    local isbns = {}
    for value in (cell(row, "isbn") or ""):gmatch("[^;]+") do
      local isbn = value:match("^%s*(.-)%s*$")
      if isbn ~= "" then isbns[#isbns + 1] = isbn end
    end
    -- A row the library could not find a book by is left out.
    if title or #isbns > 0 then
      local authors = {}
      for name in (cell(row, "authors") or ""):gmatch("[^;]+") do
        authors[#authors + 1] = name:match("^%s*(.-)%s*$")
      end
      out[#out + 1] = {
        match = { identifiers = { isbn = #isbns > 0 and isbns or nil }, title = title, authors = authors },
        set = { status = status_of(cell(row, "status")), finished_at = date_of(cell(row, "finished")) },
      }
    end
  end
  return { rows = out }
end

return list
