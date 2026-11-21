-- Google Books: a source of book details and covers for Koona Books.
--
-- Queries the keyless public Google Books Volumes API (www.googleapis.com/books/v1/volumes)
-- by ISBN or by title and author, returning candidates and validated cover links.
-- It never fetches images; Koona Books fetches and checks covers under its own rules.

local API = "https://www.googleapis.com/books/v1/volumes"
local MAX_DESCRIPTION = 80000

-- Strip characters that Google Books search interprets as query operators.
local SIGNS = '[%+%-&|!%(%)%{%}%[%]%^"~%*%?:\\/]'

local function words(value)
  value = value:gsub(SIGNS, " ")
  return (value:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

local function text(value)
  if type(value) == "string" and value ~= "" then return value end
  return nil
end

local function get(url)
  local r = koona.http.request{ url = url, timeout = 20 }
  if r.status == 200 then return r.body end
  if r.status == 0 then return nil, r.error or "unreachable" end
  if r.status == 404 then return nil, "not_found" end
  if r.status == 429 or r.status == 503 then return nil, "limited" end
  if r.status == 403 then
    local body = type(r.body) == "string" and r.body:lower() or ""
    if body:find("ratelimit", 1, true) or body:find("quota", 1, true) then
      return nil, "limited"
    end
  end
  return nil, "refused"
end

local function decode(body)
  local parsed, value = pcall(koona.json.decode, body)
  if parsed and type(value) == "table" then return value end
  return nil
end

local function ask(q, lang)
  local url = API .. "?maxResults=10&printType=books&q=" .. koona.url.encode(q)
  if lang then url = url .. "&langRestrict=" .. koona.url.encode(lang) end
  local body, err = get(url)
  if not body then return nil, err end
  local answer = decode(body)
  if not answer then return nil, "not_understood" end
  if answer.items == nil then return {} end
  if type(answer.items) ~= "table" then return nil, "not_understood" end
  return answer.items
end

local function valid_id(value)
  local s = text(value)
  if s and #s <= 64 and s:match("^[%w_%-]+$") then return s end
  return nil
end

local function date(value)
  local s = text(value)
  if not s then return nil end
  if s:match("^%d%d%d%d$") or s:match("^%d%d%d%d%-%d%d$") or s:match("^%d%d%d%d%-%d%d%-%d%d$") then
    return s
  end
  return s:match("%f[%d](%d%d%d%d)%f[%D]")
end

local function isbn_digits(value)
  local s = text(value)
  if not s then return nil end
  local clean = s:gsub("[%-%s]", ""):upper()
  if clean:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d$") or clean:match("^%d%d%d%d%d%d%d%d%d[%dX]$") then
    return clean
  end
  return nil
end

local function pick_isbn(list, asked)
  if type(list) ~= "table" then return nil end
  local isbn13, any
  for _, entry in ipairs(list) do
    if type(entry) == "table" then
      local kind = text(entry.type)
      local val = isbn_digits(entry.identifier)
      if val and (kind == "ISBN_13" or kind == "ISBN_10" or not kind) then
        if val == asked then return val end
        if #val == 13 then isbn13 = isbn13 or val end
        any = any or val
      end
    end
  end
  return isbn13 or any
end

-- Strip simple HTML tags and common entities from Google Books descriptions.
local function plain_html(s)
  if #s > MAX_DESCRIPTION then
    local at = MAX_DESCRIPTION
    while at > 0 and s:byte(at + 1) >= 128 and s:byte(at + 1) < 192 do at = at - 1 end
    s = s:sub(1, at)
  end
  s = s:gsub("<%s*[bB][rR]%s*/?%s*>", "\n")
  s = s:gsub("</%s*[pP]%s*>", "\n\n")
  s = s:gsub("<%s*[pP][^>]*>", "")
  s = s:gsub("<[^>]+>", "")
  s = s:gsub("&nbsp;", " ")
  s = s:gsub("&quot;", '"')
  s = s:gsub("&#39;", "'")
  s = s:gsub("&apos;", "'")
  s = s:gsub("&lt;", "<")
  s = s:gsub("&gt;", ">")
  s = s:gsub("&amp;", "&")
  return s
end

local function normalize_cover_url(raw, prefer_large)
  local s = text(raw)
  if not s then return nil end
  if s:sub(1, 24) == "http://books.google.com/" then
    s = "https://books.google.com/" .. s:sub(25)
  elseif s:sub(1, 35) == "http://books.googleusercontent.com/" then
    s = "https://books.googleusercontent.com/" .. s:sub(36)
  end
  if s:sub(1, 25) ~= "https://books.google.com/" and s:sub(1, 36) ~= "https://books.googleusercontent.com/" then
    return nil
  end
  s = s:gsub("&edge=curl", ""):gsub("%?edge=curl&", "?"):gsub("%?edge=curl$", "")
  if prefer_large and s:find("books.google.com/books/content", 1, true) then
    s = s:gsub("([?&])zoom=%d+", "%1zoom=0")
  end
  return s
end

local COVER_KEYS = { "extraLarge", "large", "medium", "small", "thumbnail", "smallThumbnail" }

local function best_cover(links)
  if type(links) ~= "table" then return nil end
  for _, k in ipairs(COVER_KEYS) do
    local prefer_large = (k == "thumbnail" or k == "smallThumbnail")
    local url = normalize_cover_url(links[k], prefer_large)
    if url then return { url = url } end
  end
  return nil
end

local function normalize_page_url(v)
  local raw = text(v.canonicalVolumeLink) or text(v.infoLink)
  if not raw then return nil end
  if raw:sub(1, 24) == "http://books.google.com/" then
    raw = "https://books.google.com/" .. raw:sub(25)
  end
  if raw:sub(1, 25) == "https://books.google.com/" then return raw end
  return nil
end

local function tags_of(list)
  if type(list) ~= "table" then return nil end
  local out, seen = {}, {}
  for _, raw in ipairs(list) do
    if type(raw) == "string" then
      for part in raw:gmatch("[^/]+") do
        local clean = (part:gsub("^%s+", ""):gsub("%s+$", ""))
        if clean ~= "" and not seen[clean] then
          seen[clean] = true
          out[#out + 1] = clean
        end
      end
    end
  end
  if #out > 0 then return out end
  return nil
end

local function candidate(item, asked)
  if type(item) ~= "table" then return nil end
  local v = item.volumeInfo
  if type(v) ~= "table" then return nil end
  local title = text(v.title)
  if not title then return nil end

  local authors = {}
  if type(v.authors) == "table" then
    for _, name in ipairs(v.authors) do
      if text(name) then
        authors[#authors + 1] = { name = name, role = "author" }
      end
    end
  end

  local identifiers = {}
  local found_isbn = pick_isbn(v.industryIdentifiers, asked)
  if found_isbn then identifiers.isbn = { found_isbn } end
  local vol_id = valid_id(item.id)
  if vol_id then identifiers.google = { vol_id } end

  local desc = text(v.description)
  return {
    title = title,
    subtitle = text(v.subtitle),
    language = text(v.language) and koona.lang.tag(v.language) or nil,
    authors = authors,
    description = desc and plain_html(desc) or nil,
    publisher = text(v.publisher),
    published = date(v.publishedDate),
    tags = tags_of(v.categories),
    identifiers = identifiers,
    cover = best_cover(v.imageLinks),
    page = normalize_page_url(v),
    note = vol_id,
  }
end

local function term(prefix, raw)
  local clean = words(raw)
  if clean == "" then return nil end
  if clean:find(" ", 1, true) then
    return prefix .. '"' .. clean .. '"'
  end
  return prefix .. clean
end

local function found(query)
  local asked = query.identifiers.isbn and query.identifiers.isbn[1]
  local want = query.want[1] and query.want[1]:match("^%a%a") or nil
  local items, err
  if asked then
    items, err = ask("isbn:" .. asked, nil)
    if not items then return nil, err end
  end
  if (not items or #items == 0) and query.title ~= "" then
    local parts = {}
    local t = term("intitle:", query.title)
    if t then parts[#parts + 1] = t end
    local a = query.authors[1] and term("inauthor:", query.authors[1]) or nil
    if a then parts[#parts + 1] = a end
    local q = table.concat(parts, " ")
    if q ~= "" then
      if want then
        items, err = ask(q, want)
        if not items then return nil, err end
      end
      if not items or #items == 0 then
        items, err = ask(q, nil)
        if not items then return nil, err end
      end
    end
  end
  return items or {}, asked
end

local gb = {}

function gb.search(ctx, query)
  local items, asked = found(query)
  if not items then return { error = asked } end
  local out = {}
  for _, item in ipairs(items) do
    local c = candidate(item, asked)
    if c then
      out[#out + 1] = c
      if #out == 10 then break end
    end
  end
  return { rows = out }
end

function gb.details(ctx, found_one)
  local out = {}
  for k, v in pairs(found_one) do out[k] = v end
  local vol_id = valid_id(found_one.note)
  if not vol_id then return out end
  local body, err = get(API .. "/" .. koona.url.encode(vol_id))
  if not body then return { error = err } end
  local item = decode(body)
  if not item or type(item.volumeInfo) ~= "table" then return { error = "not_understood" } end
  local v = item.volumeInfo
  local desc = text(v.description)
  if desc then out.description = plain_html(desc) end
  local c = best_cover(v.imageLinks)
  if c then out.cover = c end
  if not text(out.subtitle) and text(v.subtitle) then out.subtitle = v.subtitle end
  if not text(out.publisher) and text(v.publisher) then out.publisher = v.publisher end
  if not text(out.published) then out.published = date(v.publishedDate) end
  local tags = tags_of(v.categories)
  if tags then out.tags = tags end
  return out
end

function gb.covers(ctx, query)
  local items, asked = found(query)
  if not items then return { error = asked } end
  local out, seen = {}, {}
  local function add(url)
    if url and not seen[url] and #out < 20 then
      seen[url] = true
      out[#out + 1] = { url = url }
    end
  end
  for _, item in ipairs(items) do
    if type(item) == "table" and type(item.volumeInfo) == "table" then
      local links = item.volumeInfo.imageLinks
      if type(links) == "table" then
        for _, k in ipairs(COVER_KEYS) do
          if links[k] then
            if k == "thumbnail" or k == "smallThumbnail" then
              add(normalize_cover_url(links[k], true))
            end
            add(normalize_cover_url(links[k], false))
          end
        end
      end
    end
  end
  return { rows = out }
end

return gb
