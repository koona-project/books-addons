-- Info starter: a source of book information and covers for Koona Books, made to be copied.
--
-- The Example catalog at api.example.org answers JSON. This script asks it about one book and
-- says what it found: candidates, each one edition in one language, and links to covers. The
-- app does the rest: which source to ask, ranking, the comparison the person sees, what is
-- written to the library, and fetching every picture.

local API = "https://api.example.org"
local ROLES = { author = true, translator = true, editor = true, illustrator = true }

-- A text, or nil: an empty string or a number from the JSON is no text.
local function text(value)
  if type(value) == "string" and value ~= "" then return value end
  return nil
end

-- One request, decoded. The app paces every request to the manifest's pace (and never faster
-- than its own cap), so the script does not wait between them.
local function get(url)
  local r = koona.http.request{ url = url, headers = { accept = "application/json" }, timeout = 20 }
  if r.status == 0 then return nil, r.error or "unreachable" end
  if r.status == 404 then return nil, "not_found" end
  if r.status == 429 then return nil, "limited" end
  if r.status ~= 200 then return nil, "refused" end
  local ok, value = pcall(koona.json.decode, r.body)
  if not ok or type(value) ~= "table" then return nil, "not_understood" end
  return value
end

-- A cover's link, made whole. A link to a host the manifest does not list is no cover: the
-- app drops it, so it is not worth sending.
local function cover(c)
  if type(c) ~= "table" or not text(c.url) then return nil end
  local ok, url = pcall(koona.url.join, API, c.url)
  if not ok then return nil end
  return { url = url, width = c.width, height = c.height }
end

-- What the catalog found for the query: its list of books, or nil and a code.
local function find(query)
  -- The query holds an ISBN only when the book has a valid one.
  local isbn = query.identifiers.isbn and query.identifiers.isbn[1]
  local url
  if isbn then
    url = API .. "/v1/books?isbn=" .. isbn
  elseif query.title ~= "" then
    url = API .. "/v1/books?title=" .. koona.url.encode(query.title)
    if query.authors[1] then url = url .. "&author=" .. koona.url.encode(query.authors[1]) end
  else
    return {}
  end
  -- `want` is the languages to answer in, best first; this catalog takes a three-letter code.
  local lang = query.want[1] and koona.lang.code3(query.want[1])
  if lang then url = url .. "&lang=" .. lang end
  local answer, why = get(url)
  if not answer then return nil, why end
  return type(answer.books) == "table" and answer.books or {}
end

local function candidate(b)
  if type(b) ~= "table" or not text(b.title) then return nil end
  local authors = {}
  for _, a in ipairs(type(b.authors) == "table" and b.authors or {}) do
    -- The app knows four roles and drops a person with any other; none is an author. A
    -- narrator is not made into an author here.
    if type(a) == "table" and (a.role == nil or ROLES[a.role]) then
      authors[#authors + 1] = { name = a.name, role = a.role or "author" }
    end
  end
  -- Every kind of identifier is a list of texts, also for one value. The app keeps a kind
  -- other than `isbn` only when it is this source's own id in the manifest ("example").
  local identifiers = { example = { b.id } }
  if text(b.isbn) then identifiers.isbn = { b.isbn } end
  return {
    title = b.title,
    subtitle = b.subtitle,
    language = text(b.language) and koona.lang.tag(b.language),
    authors = authors,
    publisher = b.publisher,
    -- A year, a year and month, or a full date ("2019", "2019-08", "2019-08-06").
    published = type(b.year) == "number" and string.format("%d", b.year) or nil,
    identifiers = identifiers,
    cover = cover(b.cover),
    -- The record's page on the catalog's site, for the person's browser, as the catalog gives
    -- it; the app never asks for it. A catalog that gives none has none: do not make one up.
    page = text(b.web),
    -- The script's own note: which record this is. The app hands it back to `details`.
    note = text(b.id),
  }
end

local info = {}

function info.search(ctx, query)
  local books, why = find(query)
  if not books then return { error = why } end
  local rows = {}
  for _, b in ipairs(books) do
    rows[#rows + 1] = candidate(b)
  end
  return { rows = rows }
end

-- The candidate the person looks at, filled in from the record's own page. What comes back is
-- the candidate as the app took it from `search`, with the fields this adds.
function info.details(ctx, found)
  if not found.note then return found end
  local record, why = get(API .. "/v1/books/" .. koona.url.encode(found.note))
  if not record then return { error = why } end
  found.description = record.description
  found.tags = record.tags
  if type(record.series) == "table" then
    found.series = { name = record.series.name, index = record.series.number }
  end
  return found
end

function info.covers(ctx, query)
  local books, why = find(query)
  if not books then return { error = why } end
  local rows = {}
  for _, b in ipairs(books) do
    rows[#rows + 1] = type(b) == "table" and cover(b.cover) or nil
  end
  return { rows = rows }
end

return info
