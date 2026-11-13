-- Hardcover: keeps what you are reading and what you have read in step with your shelf on
-- hardcover.app, through its GraphQL API.
--
-- Written from Hardcover's own pages (docs.hardcover.app, read 2026-11-11; the API is in beta):
--   POST https://api.hardcover.app/v1/graphql, the person's sign-in as a bearer token.
--   Koona Books adds the token itself: this script never sees it.
--   me { id username }                                   who is signed in
--   user_books(where: {user_id}) { ... }                 the whole shelf; a read is user_book_reads
--   editions(where: {isbn_13: {_in: [...]}})             a book by ISBN
--   update_user_book(id, object: {status_id})            2 reading starts a read, 3 read finishes it
--   update_user_book_read(id, object: {progress_pages})  how far, in pages of the edition
--   insert_user_book(object: {book_id, edition_id, status_id})
-- Statuses: 1 want to read, 2 reading, 3 read, 4 paused, 5 did not finish, 6 ignored.
-- Progress there is pages of an edition; here it is a share of the book.
--
-- A reading sync answers with a table: rows, results (a change made has no `error`), or
-- `{ error = "<code>" }`. No title and
-- no author of the person's library is sent: books are found by ISBN or by Hardcover's own id.

local h = {}

local API = "https://api.hardcover.app/v1/graphql"
-- Entries asked for at a time. The whole shelf is read, books meant to be read included, so a
-- page is large: a long shelf takes few requests. The authors asked for are capped below, so
-- a page stays well inside what one answer may hold.
local PAGE = 250
-- The largest GraphQL `Int` (32 bits, signed): no id or offset sent is larger.
local MAX_INT = 2147483647

-- One GraphQL request. Returns the `data` table, or nil and a code.
local function ask(query, variables)
  local asked = { query = query }
  -- A query with no variables names none: an empty table is written as a JSON list, and a
  -- GraphQL server takes variables only as an object (it refuses `"variables": []`).
  if type(variables) == "table" and next(variables) ~= nil then asked.variables = variables end
  local r = koona.http.request{
    method = "POST", url = API, timeout = 30,
    headers = { ["content-type"] = "application/json", ["accept"] = "application/json" },
    body = koona.json.encode(asked),
  }
  if r.status == 0 then return nil, type(r.error) == "string" and r.error or "unreachable" end
  if r.status == 401 then return nil, "signed_out" end
  if r.status == 429 then return nil, "limited" end
  if r.status == 403 then
    local ok, said = pcall(koona.json.decode, r.body or "")
    if ok and type(said) == "table" and said.error == "insufficient_scope" then return nil, "scope" end
    return nil, "refused"
  end
  if r.status == 408 or r.status >= 500 then return nil, "unreachable" end
  local ok, value = pcall(koona.json.decode, type(r.body) == "string" and r.body or "")
  if not ok or type(value) ~= "table" then value = nil end
  -- A query the service did not take: its own words are for the log (the terminal of a
  -- development run), never for the person. They say which field or argument it refused.
  local function said()
    if not value then return "no answer to read" end
    local first = type(value.errors) == "table" and value.errors[1] or nil
    if type(first) == "table" and type(first.message) == "string" then return first.message end
    if type(first) == "string" then return first end
    if type(value.error_description) == "string" then return value.error_description end
    if type(value.error) == "string" then return value.error end
    return "no reason given"
  end
  if r.status ~= 200 or not value or value.errors ~= nil or type(value.data) ~= "table" then
    koona.log("warn", "hardcover refused a query (" .. tostring(r.status) .. "): " .. said():sub(1, 300))
    return nil, "refused"
  end
  return value.data
end

local function me()
  local data, why = ask("query { me { id username } }")
  if not data then return nil, why end
  local user = type(data.me) == "table" and (data.me[1] or data.me) or nil
  if type(user) ~= "table" or type(user.id) ~= "number" then return nil, "refused" end
  if user.id < 0 or user.id > MAX_INT or math.floor(user.id) ~= user.id then return nil, "refused" end
  return user
end

function h.check(ctx)
  local user, why = me()
  if not user then return { error = why } end
  return { name = type(user.username) == "string" and user.username or "" }
end

local SHELF = [[
query ($user: Int!, $limit: Int!, $offset: Int!) {
  user_books(where: {user_id: {_eq: $user}},
             order_by: {id: asc}, limit: $limit, offset: $offset) {
    id book_id edition_id status_id updated_at last_read_date
    book { title pages contributions(limit: 3) { author { name } } }
    edition { id pages isbn_13 isbn_10 }
    user_book_reads(order_by: {id: desc}, limit: 1) {
      id started_at finished_at progress_pages edition { pages }
    }
  }
}]]

local function number(v) return type(v) == "number" and v or nil end
local function text(v) return type(v) == "string" and v ~= "" and v or nil end

-- One entry of the shelf as a row.
local function row(ub)
  local book = type(ub.book) == "table" and ub.book or {}
  local edition = type(ub.edition) == "table" and ub.edition or {}
  local read = type(ub.user_book_reads) == "table" and ub.user_book_reads[1] or nil
  if type(read) ~= "table" then read = nil end
  local pages = read and type(read.edition) == "table" and number(read.edition.pages)
      or number(edition.pages) or number(book.pages)
  if pages and pages <= 0 then pages = nil end

  -- Every entry of the shelf is a row: the app must know a book is there, also when it says
  -- nothing of the reading. 1 want to read is "unread"; 5 did not finish and 6 ignored are
  -- "set_aside", the person's own word, which a sync never changes.
  local STATUS = { [1] = "unread", [2] = "reading", [3] = "finished", [4] = "reading", [5] = "set_aside", [6] = "set_aside" }
  local status = STATUS[ub.status_id]
  local finished = ub.status_id == 3
  local says = status == "reading" or status == "finished"
  local progress = nil
  if status == "reading" and read and number(read.progress_pages) and pages then
    progress = math.min(1, math.max(0, read.progress_pages / pages))
  end

  local authors = {}
  for _, c in ipairs(type(book.contributions) == "table" and book.contributions or {}) do
    local name = type(c) == "table" and type(c.author) == "table" and text(c.author.name)
    if name and #authors < 3 then authors[#authors + 1] = name end
  end
  local isbn = {}
  if text(edition.isbn_13) then isbn[#isbn + 1] = edition.isbn_13 end
  if text(edition.isbn_10) then isbn[#isbn + 1] = edition.isbn_10 end
  -- The shelf entry is one book of the library (an edition); the work may be on the shelf as
  -- more than one entry. Every kind is a list of texts, also for one value.
  local identifiers = { ["hardcover-entry"] = { tostring(ub.id) }, hardcover = { tostring(ub.book_id) } }
  if #isbn > 0 then identifiers.isbn = isbn end
  if number(ub.edition_id) then identifiers["hardcover-edition"] = { tostring(ub.edition_id) } end

  return {
    identifiers = identifiers,
    title = text(book.title) or "",
    authors = authors,
    status = status,
    progress = progress,
    read_at = says and text(ub.updated_at) or nil,
    finished_at = finished and (read and text(read.finished_at) or text(ub.last_read_date)) or nil,
    -- What a change needs later: the shelf entry, its read, its page count, where it stands
    -- and the page the read is at there.
    remote = {
      ub = ub.id, read = read and read.id or nil, pages = pages, status = ub.status_id,
      at = read and number(read.progress_pages) or nil,
    },
  }
end

-- A cursor this script wrote: "<user id>:<offset>", both whole numbers a GraphQL `Int` holds.
local function cursor_of(text)
  if type(text) ~= "string" or #text > 32 then return nil end
  local u, o = text:match("^(%d+):(%d+)$")
  local user, offset = tonumber(u), tonumber(o)
  if not user or not offset or user > MAX_INT or offset > MAX_INT - PAGE then return nil end
  return user, offset
end

-- The shelf, a page at a time. The cursor is "<user id>:<offset>". No cursor is the first
-- page; one this script did not write (damaged, numbers too large) is refused, never guessed.
function h.pull(ctx, ask_for)
  local user, offset
  if ask_for.cursor ~= nil then
    user, offset = cursor_of(ask_for.cursor)
    if not user then return { error = "refused" } end
  else
    local who, why = me()
    if not who then return { error = why } end
    user, offset = who.id, 0
  end
  local data, why = ask(SHELF, { user = user, limit = PAGE, offset = offset })
  if not data then return { error = why } end
  local shelf = type(data.user_books) == "table" and data.user_books or {}
  local rows = {}
  for _, ub in ipairs(shelf) do
    -- An entry without its ids, or whose status is not a number, is left out: what it is is
    -- not guessed.
    if type(ub) == "table" and number(ub.id) and number(ub.book_id) and number(ub.status_id) then
      rows[#rows + 1] = row(ub)
    end
  end
  local next = nil
  if #shelf >= PAGE then next = string.format("%d:%d", user, offset + PAGE) end
  return { rows = rows, next = next }
end

local BY_ISBN = [[
query ($isbns: [String!]!) {
  editions(where: {isbn_13: {_in: $isbns}}, limit: 500) { id book_id pages isbn_13 }
}]]

local SET_STATUS = [[
mutation ($id: Int!, $status: Int!) {
  update_user_book(id: $id, object: {status_id: $status}) {
    error
    user_book { id status_id user_book_reads(order_by: {id: desc}, limit: 1) { id } }
  }
}]]

local SET_PAGES = [[
mutation ($id: Int!, $pages: Int!) {
  update_user_book_read(id: $id, object: {progress_pages: $pages}) {
    error
    user_book_read { id progress_pages finished_at }
  }
}]]

local SET_FINISHED = [[
mutation ($id: Int!, $day: date!) {
  update_user_book_read(id: $id, object: {finished_at: $day}) {
    error
    user_book_read { id finished_at }
  }
}]]

local ADD = [[
mutation ($book: Int!, $edition: Int, $status: Int!) {
  insert_user_book(object: {book_id: $book, edition_id: $edition, status_id: $status}) {
    error
    user_book { id status_id user_book_reads(order_by: {id: desc}, limit: 1) { id } }
  }
}]]

-- The first read of what a mutation gave back.
local function read_of(user_book)
  local reads = type(user_book) == "table" and user_book.user_book_reads or nil
  local read = type(reads) == "table" and reads[1] or nil
  return type(read) == "table" and number(read.id) or nil
end

-- A share of the book as a page of the edition, or nil for a share under one page (nothing
-- read there yet is not "page 1"). Never the last page while the book is being read:
-- Hardcover finishes a read by itself when progress reaches the edition's end.
local function page_of(share, pages)
  local page = math.floor(share * pages + 0.5)
  if page < 1 then return nil end
  if page > pages - 1 then page = pages - 1 end
  if page < 1 then return nil end
  return page
end

-- Sends one book's state. `remote` is what pull kept of it, or what was just found for it.
-- Returns the new remote, or nil and a code.
local function send(change, remote)
  local ub, read, pages, status = number(remote.ub), number(remote.read), number(remote.pages), number(remote.status)
  local at = number(remote.at)
  -- Where it stood there before this push: a book read there already keeps its own day.
  local was = status

  if not ub then
    if not number(remote.book) then return nil, "not_found" end
    local data, why = ask(ADD, {
      book = remote.book, edition = number(remote.edition),
      status = change.status == "finished" and 3 or 2,
    })
    if not data then return nil, why, true end
    local done = type(data.insert_user_book) == "table" and data.insert_user_book or {}
    if text(done.error) or type(done.user_book) ~= "table" then return nil, "refused" end
    ub, status, read = number(done.user_book.id), number(done.user_book.status_id), read_of(done.user_book)
    if not ub then return nil, "refused" end
  end

  local want = change.status == "finished" and 3 or 2
  -- A book set aside there (did not finish, ignored) is the person's own word: left alone.
  if status == 5 or status == 6 then return nil, "set_aside" end
  -- Read there, being read here: it would start a second read. Only the person does that.
  if status == 3 and want == 2 then return nil, "already_read" end
  -- Read on both sides: nothing to send, and the day it was finished there stays as it is.
  if was == 3 and want == 3 then return { ub = ub, read = read, pages = pages, status = status, at = at } end
  local page = want == 2 and pages and pages > 1 and number(change.progress)
      and page_of(change.progress, pages) or nil
  -- Paused there: the person's own word, kept unless the book was read on here, past the
  -- page it is paused at. The same place, or an earlier one, leaves it paused.
  if status == 4 and want == 2 and not (page and page > (at or 0)) then
    return { ub = ub, read = read, pages = pages, status = status, at = at }
  end
  -- Paused there and read on here: it is being read again.
  if status ~= want and not (status == 2 and want == 2) then
    local data, why = ask(SET_STATUS, { id = ub, status = want })
    if not data then return nil, why, true end
    local done = type(data.update_user_book) == "table" and data.update_user_book or {}
    if text(done.error) then return nil, "refused" end
    status = want
    read = read_of(done.user_book) or read
  end

  if want == 2 and read and page then
    local data, why = ask(SET_PAGES, { id = read, pages = page })
    if not data then return nil, why, true end
    local done = type(data.update_user_book_read) == "table" and data.update_user_book_read or {}
    if text(done.error) then return nil, "refused" end
    at = page
  end
  -- The day it was finished here, when it is not the day Hardcover just wrote (today).
  if want == 3 and read and text(change.finished_at) then
    local day = change.finished_at:sub(1, 10)
    if day:match("^%d%d%d%d%-%d%d%-%d%d$") then
      local data, why = ask(SET_FINISHED, { id = read, day = day })
      if not data then return nil, why, true end
      -- A day it did not take (the read is gone, the date refused): Hardcover does not have
      -- it, so the change is not sent.
      local done = type(data.update_user_book_read) == "table" and data.update_user_book_read or {}
      if text(done.error) or type(done.user_book_read) ~= "table" then return nil, "refused" end
    end
  end
  return { ub = ub, read = read, pages = pages, status = status, at = at }
end

-- An ISBN as the 13 digits Hardcover's editions are found by: an ISBN-13 as it is, an
-- ISBN-10 (its check digit may be X) as its ISBN-13 (978, its first nine digits, a new
-- check digit). Nil for anything else, or an ISBN-10 whose own check digit is wrong.
local function isbn13(isbn)
  local plain = tostring(isbn):upper():gsub("[^%dX]", "")
  if #plain == 13 and plain:match("^%d+$") then return plain end
  if #plain ~= 10 or not plain:match("^%d%d%d%d%d%d%d%d%d[%dX]$") then return nil end
  local sum = 0
  for i = 1, 10 do
    local c = plain:sub(i, i)
    local d = c == "X" and 10 or tonumber(c)
    sum = sum + (11 - i) * d
  end
  if sum % 11 ~= 0 then return nil end
  local body = "978" .. plain:sub(1, 9)
  local total = 0
  for i = 1, 12 do
    total = total + tonumber(body:sub(i, i)) * (i % 2 == 1 and 1 or 3)
  end
  return body .. tostring((10 - total % 10) % 10)
end

function h.push(ctx, changes)
  -- Books that are not on the shelf yet are looked up by ISBN, all in one request.
  local wanted, isbns = {}, {}
  for _, change in ipairs(changes) do
    if type(change.remote) ~= "table" then
      local known = type(change.identifiers) == "table" and change.identifiers or {}
      for _, isbn in ipairs(type(known.isbn) == "table" and known.isbn or {}) do
        local digits = isbn13(isbn)
        if digits and not wanted[digits] then
          wanted[digits] = true
          isbns[#isbns + 1] = digits
        end
      end
    end
  end
  local found = {}
  if #isbns > 0 then
    local data, why = ask(BY_ISBN, { isbns = isbns })
    if not data then return { error = why } end
    for _, e in ipairs(type(data.editions) == "table" and data.editions or {}) do
      if type(e) == "table" and text(e.isbn_13) and number(e.id) and number(e.book_id) and not found[e.isbn_13] then
        found[e.isbn_13] = { book = e.book_id, edition = e.id, pages = number(e.pages) }
      end
    end
  end

  local results = {}
  for i, change in ipairs(changes) do
    local remote = type(change.remote) == "table" and change.remote or nil
    if not remote then
      local known = type(change.identifiers) == "table" and change.identifiers or {}
      for _, isbn in ipairs(type(known.isbn) == "table" and known.isbn or {}) do
        local digits = isbn13(isbn)
        if digits and found[digits] then remote = found[digits] break end
      end
      -- No ISBN of it is known there, but the book's own id on Hardcover is.
      if not remote and type(known.hardcover) == "table" and tonumber(known.hardcover[1]) then
        remote = { book = tonumber(known.hardcover[1]) }
      end
    end
    if not remote then
      results[#results + 1] = { key = change.key, error = "not_found" }
    else
      local new, why, whole = send(change, remote)
      if new then
        -- What the book is now known by there: the entry written or added, and its work and
        -- edition when this push found them.
        local identifiers = { ["hardcover-entry"] = { tostring(new.ub) } }
        if number(remote.book) then identifiers.hardcover = { tostring(remote.book) } end
        if number(remote.edition) then identifiers["hardcover-edition"] = { tostring(remote.edition) } end
        results[#results + 1] = { key = change.key, remote = new, identifiers = identifiers }
      elseif whole and (why == "signed_out" or why == "limited" or why == "unreachable" or why == "timeout" or why == "scope") then
        -- The service is gone or asks to wait: what was sent so far stands, the rest is not tried.
        results[#results + 1] = { key = change.key, error = why }
        return { results = results, stopped = why }
      else
        results[#results + 1] = { key = change.key, error = why or "refused" }
      end
    end
    koona.progress(i, #changes)
  end
  return { results = results }
end

return h
