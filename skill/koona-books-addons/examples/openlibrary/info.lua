-- Open Library: a source of book information and covers for Koona Books.
--
-- It asks openlibrary.org about one book and says what it found: editions, each in one
-- language, and links to covers. It never fetches a picture; the app does, from the links,
-- under its own rules. Checked against the live service on 2026-11-12 (README.md).

local SITE = "https://openlibrary.org"
local SEARCH = SITE .. "/search.json"
local COVERS = "https://covers.openlibrary.org/b/id/"
local FIELDS = "key,title,author_name,cover_i,language,"
  .. "editions,editions.key,editions.title,editions.subtitle,editions.language,"
  .. "editions.isbn,editions.publisher,editions.publish_date,editions.cover_i"

-- What the search reads as its own signs. A title is words, not a query.
local SIGNS = '[%+%-&|!%(%)%{%}%[%]%^"~%*%?:\\/]'

-- The search also reads these three words, in capitals, as its own.
local function words(text)
  text = text:gsub(SIGNS, " ")
  text = text:gsub("%f[%w]AND%f[%W]", "and"):gsub("%f[%w]OR%f[%W]", "or"):gsub("%f[%w]NOT%f[%W]", "not")
  return (text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

-- One request. The app paces it and says who is asking.
local function get(url)
  local r = koona.http.request{ url = url, timeout = 20 }
  if r.status == 200 then return r.body end
  if r.status == 0 then return nil, r.error or "unreachable" end
  if r.status == 404 then return nil, "not_found" end
  if r.status == 429 or r.status == 503 then return nil, "limited" end
  return nil, "refused"
end

local function decode(body)
  local ok, value = pcall(koona.json.decode, body)
  if ok and type(value) == "table" then return value end
  return nil
end

local function ask(q, want)
  local url = SEARCH .. "?limit=10&fields=" .. FIELDS .. "&q=" .. koona.url.encode(q)
  if want then url = url .. "&lang=" .. want end
  local body, err = get(url)
  if not body then return nil, err end
  local answer = decode(body)
  if not answer or type(answer.docs) ~= "table" then return nil, "not_understood" end
  return answer.docs
end

local function text(value)
  if type(value) == "string" and value ~= "" then return value end
  return nil
end

local function first(list)
  if type(list) == "table" then return text(list[1]) end
  return nil
end

-- A language only when the record names exactly one: a work lists every language it was ever
-- printed in, in no order, and the first of them says nothing about this title.
local function language(list)
  if type(list) == "table" and #list == 1 and type(list[1]) == "string" then
    return koona.lang.tag(list[1])
  end
  return nil
end

-- A year, a year and month or a full date as the app reads one; from "March 1, 2017" the year.
local function date(value)
  local s = text(value)
  if not s then return nil end
  if s:match("^%d%d%d%d$") or s:match("^%d%d%d%d%-%d%d$") or s:match("^%d%d%d%d%-%d%d%-%d%d$") then
    return s
  end
  return s:match("%f[%d](%d%d%d%d)%f[%D]")
end

local function digits(value)
  local s = text(value)
  if s and (s:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d$") or s:match("^%d%d%d%d%d%d%d%d%d[%dX]$")) then
    return s
  end
  return nil
end

-- The edition's ISBN: the one that was asked for when the edition has it, else its
-- thirteen-digit one, else any.
local function isbn(list, asked)
  if type(list) ~= "table" then return nil end
  local long, any
  for _, value in ipairs(list) do
    local s = digits(value)
    if s then
      if s == asked then return s end
      if #s == 13 then long = long or s end
      any = any or s
    end
  end
  return long or any
end

local function cover(id)
  if type(id) == "number" and id > 0 and id < 1e12 and id == math.floor(id) then
    return { url = COVERS .. string.format("%d", id) .. "-L.jpg" }
  end
  return nil
end

local function key(value, kind)
  local s = text(value)
  if s and s:match("^/" .. kind .. "/OL%d+[WM]$") then return s end
  return nil
end

local function candidate(doc, asked)
  if type(doc) ~= "table" then return nil end
  local e = type(doc.editions) == "table" and type(doc.editions.docs) == "table" and doc.editions.docs[1]
  if type(e) ~= "table" then e = {} end
  local title = text(e.title) or text(doc.title)
  if not title then return nil end
  local authors = {}
  if type(doc.author_name) == "table" then
    for _, name in ipairs(doc.author_name) do
      if text(name) then authors[#authors + 1] = { name = name, role = "author" } end
    end
  end
  local work = key(doc.key, "works")
  local edition = key(e.key, "books")
  -- Every kind of identifier is a list of texts, also for one value.
  local identifiers = {}
  local found_isbn = isbn(e.isbn, asked)
  if found_isbn then identifiers.isbn = { found_isbn } end
  if work then identifiers.openlibrary = { work:match("OL%d+W") } end
  return {
    title = title,
    subtitle = text(e.subtitle),
    -- The edition's language, or the work's when the work has only ever had one.
    language = language(e.language) or language(doc.language),
    authors = authors,
    -- Only the edition's own: a work lists every publisher it ever had.
    publisher = first(e.publisher),
    published = date(first(e.publish_date)),
    identifiers = identifiers,
    cover = cover(e.cover_i) or cover(doc.cover_i),
    page = (edition or work) and (SITE .. (edition or work)) or nil,
    note = work,
  }
end

local function found(query)
  local asked = query.identifiers.isbn and query.identifiers.isbn[1]
  local want = query.want[1] and query.want[1]:match("^%a%a") or nil
  local docs, err
  if asked then
    docs, err = ask("isbn:" .. asked, want)
    if not docs then return nil, err end
  end
  if (not docs or #docs == 0) and query.title ~= "" then
    local q = "title:" .. words(query.title)
    local author = query.authors[1] and words(query.authors[1]) or ""
    if author ~= "" then q = q .. " author:" .. author end
    docs, err = ask(q, want)
    if not docs then return nil, err end
  end
  return docs or {}, asked
end

local ol = {}

function ol.search(ctx, query)
  local docs, asked = found(query)
  if not docs then return { error = asked } end
  local out = {}
  for _, doc in ipairs(docs) do
    out[#out + 1] = candidate(doc, asked)
    if #out == 10 then break end
  end
  return { rows = out }
end

-- Open Library's descriptions use a little Markdown, and end in notes after a rule.
-- The app keeps 20,000 characters of a description: no more than this is worked on, cut
-- where a character ends. The patterns never look past the next bracket, so text made of
-- brackets costs no more than any other.
local MAX_DESCRIPTION = 80000

local function plain(s)
  if #s > MAX_DESCRIPTION then
    local at = MAX_DESCRIPTION
    while at > 0 and s:byte(at + 1) >= 128 and s:byte(at + 1) < 192 do at = at - 1 end
    s = s:sub(1, at)
  end
  local cut = s:find("\n%-%-%-%-%-", 1) or s:find("\r\n%-%-%-%-%-", 1)
  if cut then s = s:sub(1, cut - 1) end
  s = s:gsub("%[([^%[%]]*)%]%([^%(%)]*%)", "%1")
  s = s:gsub("%[([^%[%]]*)%]%[[^%[%]]*%]", "%1")
  s = s:gsub("%*+", "")
  return s
end

-- The work's description, for an edition in English only: Open Library writes them in
-- English, and a book is not described in a language that is not its own.
function ol.details(ctx, found_one)
  local out = {}
  for k, v in pairs(found_one) do out[k] = v end
  local work = key(found_one.note, "works")
  if found_one.language ~= "en" or not work then return out end
  local body, err = get(SITE .. work .. ".json")
  if not body then return { error = err } end
  local record = decode(body)
  if not record then return { error = "not_understood" } end
  local d = record.description
  if type(d) == "table" then d = d.value end
  if text(d) then out.description = plain(d) end
  return out
end

function ol.covers(ctx, query)
  local docs, asked = found(query)
  if not docs then return { error = asked } end
  local out, seen = {}, {}
  local function add(c)
    if c and not seen[c.url] and #out < 20 then
      seen[c.url] = true
      out[#out + 1] = c
    end
  end
  for _, doc in ipairs(docs) do
    if type(doc) == "table" then
      local e = type(doc.editions) == "table" and type(doc.editions.docs) == "table" and doc.editions.docs[1]
      if type(e) == "table" then add(cover(e.cover_i)) end
      add(cover(doc.cover_i))
    end
  end
  return { rows = out }
end

return ol
