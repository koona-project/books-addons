-- OPDS catalogues: an import source for Koona Books.
--
-- It reads a catalogue's feeds (OPDS 1.x, Atom) and says what is in them: sections to open
-- and books with links to their files. It never fetches a book or a cover; the app does,
-- from the links, under its own rules.

local ATOM = "http://www.w3.org/2005/Atom"
local OPENSEARCH = "http://a9.com/-/spec/opensearch/1.1/"
local DC = { ["http://purl.org/dc/terms/"] = true, ["http://purl.org/dc/elements/1.1/"] = true }
local THREAD_COUNT = "{http://purl.org/syndication/thread/1.0}count"
local ACQUISITION = "http://opds-spec.org/acquisition"

-- A link's type as the format the app reads. Anything else is not a book to take.
local FORMATS = {
  ["application/epub+zip"] = "epub",
  ["application/x-fictionbook+xml"] = "fb2",
  ["application/x-fictionbook"] = "fb2",
  ["application/fb2+xml"] = "fb2",
  ["text/fb2+xml"] = "fb2",
  ["application/fb2+zip"] = "fbz",
  ["application/fb2"] = "fb2",
  ["application/x-zip-compressed-fb2"] = "fbz",
  ["application/x-mobipocket-ebook"] = "mobi",
  ["application/x-mobi8-ebook"] = "azw3",
  ["application/vnd.amazon.mobi8-ebook"] = "azw3",
  ["application/pdf"] = "pdf",
}

-- What a link that is not a free file is for.
local OTHER = { ["/buy"] = "buy", ["/borrow"] = "borrow", ["/subscribe"] = "subscribe", ["/sample"] = "sample" }

local COVERS = {
  ["http://opds-spec.org/image/thumbnail"] = 1,
  ["http://opds-spec.org/thumbnail"] = 1,
  ["x-stanza-cover-image-thumbnail"] = 1,
  ["http://opds-spec.org/image"] = 2,
  ["http://opds-spec.org/cover"] = 2,
  ["x-stanza-cover-image"] = 2,
}

local OPDS = "http://opds-spec.org/2010/catalog"

local MAX_ROWS = 500
-- All the addresses of one page together: the answer stays well inside what the app takes.
local MAX_ADDRESSES = 1500000

-- A size or a count as a catalogue wrote it: a whole number that is one, or nothing.
local function amount(text)
  local n = tonumber(text)
  if n and n == n and n >= 0 and n < 1e15 then return math.floor(n) end
  return nil
end

-- Whether a link carries a price: it is to buy, whatever its relation says.
local function priced(link)
  for _, part in ipairs(link) do
    if part.name == "price" and part.ns == OPDS then return true end
  end
  return false
end

-- How much of the page's budget for addresses a row takes.
local function cost(row)
  local n = #(row.url or "") + #(row.cover or "") + #(row.page or "")
  for _, file in ipairs(row.files or {}) do n = n + #file.url end
  for _, other in ipairs(row.other or {}) do n = n + #other.url end
  return n
end

local function trim(text)
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- "application/atom+xml;profile=opds-catalog;kind=navigation" -> "application/atom+xml"
local function kind_of(type)
  if not type then return "" end
  return trim((type:match("^[^;]*") or "")):lower()
end

local function headers(ctx)
  local h = { accept = "application/atom+xml, application/xml;q=0.9, */*;q=0.5" }
  local user = ctx.settings and ctx.settings.user
  if user and user ~= "" then
    local password = koona.secret.get("password") or ""
    h.authorization = "Basic " .. koona.base64.encode(user .. ":" .. password)
  end
  return h
end

-- A document from the catalogue, parsed; or nil and the code of what went wrong.
local function fetch(ctx, url)
  local r = koona.http.request{ url = url, headers = headers(ctx), timeout = 30 }
  if r.status == 0 then return nil, r.error or "unreachable" end
  if r.status == 401 or r.status == 403 then return nil, "sign_in" end
  if r.status == 404 or r.status == 410 then return nil, "not_found" end
  -- A redirect comes back only when it leads to another site.
  if r.status >= 300 and r.status < 400 then return nil, "moved" end
  if r.status ~= 200 then return nil, "refused" end
  if not r.body then return nil, "not_a_catalogue" end
  local ok, root = pcall(koona.xml.parse, r.body)
  if not ok then return nil, "not_a_catalogue" end
  return root
end

local function join(base, href)
  local ok, url = pcall(koona.url.join, base, href)
  if ok then return url end
  return nil
end

-- Elements that end a line of text: what follows them does not run into them.
local BLOCKS = { p = true, div = true, br = true, li = true, tr = true, h1 = true, h2 = true, h3 = true, h4 = true }

-- All the text inside an element, its own and that of the elements in it.
local function text_of(node, out)
  out = out or {}
  if node.text ~= "" then out[#out + 1] = node.text end
  for _, child in ipairs(node) do
    text_of(child, out)
    if BLOCKS[child.name] then out[#out + 1] = " " end
    if child.tail then out[#out + 1] = child.tail end
  end
  return out
end

local ENTITIES = { amp = "&", lt = "<", gt = ">", quot = '"', apos = "'", nbsp = " " }

-- A summary as plain text: `content` may hold XHTML as elements, or HTML as escaped text.
local function plain(node)
  if not node then return nil end
  local type = node.attrs and node.attrs.type or "text"
  local text
  if type == "xhtml" then
    text = table.concat(text_of(node))
  else
    text = node.text
    if type == "html" or type == "text/html" then
      text = text:gsub("<[^>]*>", " "):gsub("&(%a+);", function(name) return ENTITIES[name] or " " end)
    end
  end
  text = trim(text:gsub("%s+", " "))
  if text == "" then return nil end
  return text:sub(1, 4000)
end

local function atom(node, name)
  return node.ns == ATOM and node.name == name
end

local function entry_row(entry, at)
  local row = { title = "", authors = {}, files = {}, other = {} }
  local cover, cover_rank, section, summary, content
  for _, part in ipairs(entry) do
    if atom(part, "title") then
      row.title = trim(part.text)
    elseif atom(part, "author") then
      for _, field in ipairs(part) do
        if atom(field, "name") and trim(field.text) ~= "" and #row.authors < 8 then
          row.authors[#row.authors + 1] = trim(field.text)
        end
      end
    elseif atom(part, "summary") then
      summary = part
    elseif atom(part, "content") then
      content = part
    elseif part.name == "language" and DC[part.ns or ""] then
      row.language = trim(part.text)
    elseif atom(part, "link") and part.attrs and part.attrs.href then
      local rel = part.attrs.rel or ""
      local kind = kind_of(part.attrs.type)
      local url = join(at, part.attrs.href)
      if not url then
        -- An address that is not one: the link is not there.
      elseif rel:sub(1, #ACQUISITION) == ACQUISITION then
        local what = rel:sub(#ACQUISITION + 1)
        if kind == "application/atom+xml" and (what == "" or what == "/open-access") then
          -- A partial entry: its files are in the book's own entry document. It opens like a
          -- section, and that page is the book.
          section = section or { url = url }
        elseif what == "" and priced(part) then
          if #row.other < 6 then row.other[#row.other + 1] = { kind = "buy", url = url } end
        elseif what == "" or what == "/open-access" then
          local format = FORMATS[kind]
          if format and #row.files < 12 then
            row.files[#row.files + 1] = { url = url, format = format, size = amount(part.attrs.length) }
          end
        elseif OTHER[what] and #row.other < 6 then
          row.other[#row.other + 1] = { kind = OTHER[what], url = url }
        end
      elseif COVERS[rel] then
        if not cover or COVERS[rel] < cover_rank then cover, cover_rank = url, COVERS[rel] end
      elseif rel == "alternate" and kind == "text/html" then
        row.page = url
      elseif kind == "application/atom+xml" and rel ~= "related" and rel ~= "self" and not section then
        section = { url = url, count = amount(part.attrs[THREAD_COUNT]) }
      end
    end
  end
  row.summary = plain(summary) or plain(content)
  if #row.files > 0 or #row.other > 0 then
    row.kind = "book"
    row.cover = cover
    return row
  end
  if section then
    return { kind = "folder", title = row.title, summary = row.summary, url = section.url, count = section.count }
  end
  return nil
end

-- A feed as one page of the catalogue. A book's own entry document (what a partial entry of
-- a listing leads to) is a page of that one book.
local function page(feed, at)
  if atom(feed, "entry") then
    local row = entry_row(feed, at)
    return { title = row and row.title or "", rows = { row } }
  end
  if not atom(feed, "feed") then return { error = "not_a_catalogue" } end
  local out = { title = "", rows = {} }
  local spent = 0
  local full = false
  for _, part in ipairs(feed) do
    if atom(part, "title") then
      out.title = trim(part.text)
    elseif atom(part, "link") and part.attrs and part.attrs.href then
      local rel = part.attrs.rel
      local kind = kind_of(part.attrs.type)
      local url = join(at, part.attrs.href)
      if url and rel == "next" then
        out.next = url
      elseif url and rel == "search" then
        -- The app hands this note back with what the person typed.
        if kind == "application/opensearchdescription+xml" then
          out.search = out.search or ("d " .. url)
        elseif kind == "application/atom+xml" then
          out.search = "t " .. url
        end
      end
    elseif atom(part, "entry") and not full and #out.rows < MAX_ROWS then
      local row = entry_row(part, at)
      if row then
        spent = spent + cost(row)
        -- A page whose addresses alone would be megabytes is cut here, not refused whole. The
        -- feed is still read to its end: its next page and its search may stand after the books.
        if spent > MAX_ADDRESSES then
          full = true
        else
          out.rows[#out.rows + 1] = row
        end
      end
    end
  end
  return out
end

local function start_of(ctx)
  return ctx.base .. (ctx.start or "/")
end

local function browse_at(ctx, url)
  local feed, why = fetch(ctx, url)
  if not feed then return { error = why } end
  return page(feed, url)
end

-- The address to ask for a search, from an OpenSearch template.
local function fill(template, query)
  local words = koona.url.encode(query)
  local fixed = { searchTerms = words, startPage = "1", startIndex = "1", count = "50",
                  language = "*", inputEncoding = "UTF-8", outputEncoding = "UTF-8" }
  -- A parameter this add-on has no value for is left empty, asked for or not.
  local function put(name)
    return fixed[name] or ""
  end
  -- `{` and `}` may have been escaped when the address was joined.
  template = template:gsub("%%7[Bb]", "{"):gsub("%%7[Dd]", "}"):gsub("%%3[Ff]}", "?}")
  if not template:find("{searchTerms%??}") then return nil end
  return (template:gsub("{([%w:]+)(%??)}", put))
end

-- The template a catalogue's OpenSearch description names for Atom results.
local function template_of(ctx, url)
  local doc, why = fetch(ctx, url)
  if not doc then return nil, why end
  if doc.name ~= "OpenSearchDescription" or doc.ns ~= OPENSEARCH then return nil, "no_search" end
  for _, part in ipairs(doc) do
    if part.name == "Url" and part.attrs and part.attrs.template
        and kind_of(part.attrs.type) == "application/atom+xml" then
      local template = join(url, part.attrs.template)
      if template then return template end
    end
  end
  return nil, "no_search"
end

local t = {}

function t.check(ctx)
  local feed, why = fetch(ctx, start_of(ctx))
  if not feed then return { error = why } end
  local first = page(feed, start_of(ctx))
  if first.error then return first end
  return { name = first.title }
end

function t.browse(ctx, ask)
  return browse_at(ctx, ask.url or start_of(ctx))
end

function t.search(ctx, ask)
  local how, where = (ask.note or ""):match("^(%a) (.+)$")
  local template, why
  if how == "t" then
    template = where
  elseif how == "d" then
    template, why = template_of(ctx, where)
  end
  if not template then return { error = why or "no_search" } end
  local url = fill(template, ask.query or "")
  if not url then return { error = "no_search" } end
  return browse_at(ctx, url)
end

return t
