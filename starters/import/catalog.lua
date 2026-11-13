-- Import starter: an import source for Koona Books, made to be copied and renamed.
--
-- The Example catalog at api.example.org answers JSON. This script reads it and says what is
-- in it: shelves to open, and books with links to their files. It never downloads a book or a
-- cover. Koona Books does that itself, from the links, and decides from the bytes what a
-- downloaded file really is.

local API = "https://api.example.org"
-- Where the catalog starts. A catalog at a host the manifest lists gets no `ctx.base`: the
-- script knows its own address.
local START = API .. "/v1/shelves/root"

-- The file types this catalog names, as the formats Koona Books takes from a catalog. A file
-- of any other type is left out here; the app would drop it anyway.
local FORMATS = { epub = "epub", fb2 = "fb2", mobi = "mobi", azw3 = "azw3", pdf = "pdf" }

-- A list from the catalog's JSON, or an empty one: `ipairs` of something that is not a table
-- would end the call as an error.
local function list(value)
  if type(value) == "table" then return value end
  return {}
end

-- The items of a list that are tables. The catalog's answer is not to be trusted: an item that
-- is a number or a text has no fields, and reading one of a number ends the call as an error.
local function tables(value)
  local out = {}
  for _, item in ipairs(list(value)) do
    if type(item) == "table" then out[#out + 1] = item end
  end
  return out
end

-- One request, decoded. On failure: nil and a code. The app has its own words for
-- `unreachable` and `timeout`; `not_found`, `refused` and `not_understood` are worded in
-- locales/en.json.
local function get(url)
  local r = koona.http.request{ url = url, headers = { accept = "application/json" }, timeout = 20 }
  if r.status == 0 then return nil, r.error or "unreachable" end
  if r.status == 404 then return nil, "not_found" end
  if r.status ~= 200 then return nil, "refused" end
  local ok, value = pcall(koona.json.decode, r.body)
  if not ok or type(value) ~= "table" then return nil, "not_understood" end
  return value
end

-- An address the catalog wrote, made whole. The catalog writes paths ("/files/7.epub").
-- `koona.url.join` raises on something that is not an address, so it is caught.
local function link(path)
  if type(path) ~= "string" or path == "" then return nil end
  local ok, url = pcall(koona.url.join, API, path)
  if ok then return url end
  return nil
end

local function book_row(b)
  local files = {}
  for _, f in ipairs(tables(b.files)) do
    local format = FORMATS[f.type]
    local url = link(f.path)
    if format and url then
      -- `size` is what the catalog says, in bytes. The app shows it and still holds the
      -- download to its own cap.
      files[#files + 1] = { url = url, format = format, size = f.bytes }
    end
  end
  return {
    kind = "book",
    title = b.title,
    authors = list(b.authors),
    summary = b.summary,
    -- The catalog writes three-letter codes ("eng"); the app shows a tag ("en").
    language = type(b.language) == "string" and koona.lang.tag(b.language) or nil,
    -- Fetched by the app only because api.example.org is a host the manifest lists.
    cover = link(b.cover),
    -- The book's page on the catalog's site, for the person's browser.
    page = link(b.web),
    -- A book with no file the app may take is not shown.
    files = files,
  }
end

-- One page of the catalog, as the app reads it.
local function page_of(answer)
  local rows = {}
  for _, s in ipairs(tables(answer.shelves)) do
    local url = link(s.path)
    if url then
      rows[#rows + 1] = { kind = "folder", title = s.title, summary = s.summary, url = url, count = s.count }
    end
  end
  for _, b in ipairs(tables(answer.books)) do
    rows[#rows + 1] = book_row(b)
  end
  return {
    title = answer.title,
    rows = rows,
    -- The page after this one. The app asks for it when the person wants more.
    next = link(answer.next),
    -- Any text here tells the app that the person may search from this page. It is handed
    -- back to `search` as `ask.note`. This catalog has one search, so the note says nothing.
    search = "all",
  }
end

local catalog = {}

-- Koona Books calls `check` from the form where a person names a catalog's server (Test
-- connection). This catalog is at a listed host and has no such form, so the app does not
-- call it here. It is kept for a catalog you turn into one the person names.
function catalog.check(ctx)
  local answer, why = get(START)
  if not answer then return { error = why } end
  return { name = answer.title }
end

-- `ask.url` is an address an earlier page gave (a shelf's `url`, a `next`); with none, the
-- start. The app has already checked it is an address this add-on may reach.
function catalog.browse(ctx, ask)
  local answer, why = get(ask.url or START)
  if not answer then return { error = why } end
  return page_of(answer)
end

-- `ask.query` is the person's words, cleaned and cut by the app; `ask.note` is the `search`
-- of the page they searched from.
function catalog.search(ctx, ask)
  local answer, why = get(API .. "/v1/search?q=" .. koona.url.encode(ask.query))
  if not answer then return { error = why } end
  return page_of(answer)
end

return catalog
