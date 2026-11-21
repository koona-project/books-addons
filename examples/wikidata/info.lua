-- Wikidata: a multilingual source of book details and covers for Koona Books.
--
-- Queries the public CC0 Wikidata Action API (www.wikidata.org/w/api.php) by title
-- and author, resolving works, editions, authors, translators, series, original titles,
-- publishers, and Wikimedia Commons cover links.
-- It never fetches images; Koona Books fetches and checks covers under its own rules.

local API = "https://www.wikidata.org/w/api.php"
local WIKI = "https://www.wikidata.org/wiki/"
local COMMONS = "https://commons.wikimedia.org/wiki/Special:FilePath/"

local MAX_CLAIM_BATCH = 10
local MAX_LABEL_BATCH = 20

-- Common Wikidata language item QIDs mapped to BCP 47 primary tags.
local LANG_QID = {
  Q7737 = "ru",
  Q1860 = "en",
  Q188 = "de",
  Q150 = "fr",
  Q1321 = "es",
  Q652 = "it",
  Q809 = "pl",
  Q8798 = "uk",
  Q5146 = "pt",
  Q5287 = "ja",
  Q7850 = "zh",
  Q9056 = "cs",
  Q7411 = "nl",
  Q9027 = "sv",
  Q1412 = "fi",
  Q9035 = "da",
  Q9043 = "no",
  Q9067 = "hu",
  Q7913 = "ro",
  Q7918 = "bg",
  Q9091 = "be",
  Q13955 = "ar",
  Q9288 = "he",
  Q256 = "tr",
  Q9176 = "ko",
  Q397 = "la",
  Q9129 = "el",
}

local OTHER_LANGS = { "en", "ru", "de", "fr", "es", "it", "pl", "uk", "pt", "ja", "zh" }

local function text(value)
  if type(value) == "string" and value ~= "" then return value end
  return nil
end

local function valid_qid(value)
  local s = text(value)
  if s and s:match("^Q%d+$") then return s end
  return nil
end

local function get(url)
  local r = koona.http.request{ url = url, timeout = 20 }
  if r.status == 200 then return r.body end
  if r.status == 0 then return nil, r.error or "unreachable" end
  if r.status == 404 then return nil, "not_found" end
  if r.status == 429 or r.status == 503 then return nil, "limited" end
  return nil, "refused"
end

local function decode(body)
  local parsed, value = pcall(koona.json.decode, body)
  if parsed and type(value) == "table" then return value end
  return nil
end

local function api_get(params)
  local parts = { "format=json" }
  for _, pair in ipairs(params) do
    parts[#parts + 1] = pair[1] .. "=" .. koona.url.encode(pair[2])
  end
  local body, err = get(API .. "?" .. table.concat(parts, "&"))
  if not body then return nil, err end
  local answer = decode(body)
  if not answer then return nil, "not_understood" end
  return answer
end

local function search_query(srsearch)
  local answer, err = api_get({
    { "action", "query" },
    { "list", "search" },
    { "srsearch", srsearch },
    { "srnamespace", "0" },
    { "srlimit", "10" },
  })
  if not answer then return nil, err end
  local qids, seen = {}, {}
  local list = type(answer.query) == "table" and type(answer.query.search) == "table" and answer.query.search or {}
  for _, item in ipairs(list) do
    if type(item) == "table" then
      local qid = valid_qid(item.title)
      if qid and not seen[qid] then
        seen[qid] = true
        qids[#qids + 1] = qid
      end
    end
  end
  return qids
end

local function search_entities(term, lang)
  local answer, err = api_get({
    { "action", "wbsearchentities" },
    { "search", term },
    { "language", lang },
    { "uselang", lang },
    { "type", "item" },
    { "limit", "10" },
  })
  if not answer then return nil, err end
  local qids, seen = {}, {}
  local list = type(answer.search) == "table" and answer.search or {}
  for _, item in ipairs(list) do
    if type(item) == "table" then
      local qid = valid_qid(item.id)
      if qid and not seen[qid] then
        seen[qid] = true
        qids[#qids + 1] = qid
      end
    end
  end
  return qids
end

local function languages_param(want_list)
  local out, seen = {}, {}
  local function add(tag)
    if type(tag) == "string" and tag ~= "" and not seen[tag] then
      seen[tag] = true
      out[#out + 1] = tag
    end
  end
  for _, lang in ipairs(want_list) do add(lang) end
  for _, lang in ipairs(OTHER_LANGS) do add(lang) end
  return table.concat(out, "|")
end

-- Fetch entities in bounded chunks, always passing `languages=` to stay well under host caps.
local function fetch_entities(qids, props, langs, chunk_size)
  if #qids == 0 then return {} end
  local limit = chunk_size or MAX_CLAIM_BATCH
  local merged = {}
  local i = 1
  while i <= #qids do
    local batch = {}
    local stop = math.min(i + limit - 1, #qids)
    for j = i, stop do
      batch[#batch + 1] = qids[j]
    end
    local params = {
      { "action", "wbgetentities" },
      { "ids", table.concat(batch, "|") },
      { "props", props },
      { "languages", langs },
    }
    local answer, err = api_get(params)
    if not answer then return nil, err end
    if type(answer.entities) == "table" then
      for k, v in pairs(answer.entities) do
        merged[k] = v
      end
    end
    i = stop + 1
  end
  return merged
end

-- Extract claim datavalues of a property from an entity's claims table.
local function statements(entity, prop)
  if type(entity) ~= "table" or type(entity.claims) ~= "table" then return {} end
  local list = entity.claims[prop]
  if type(list) ~= "table" then return {} end
  local out = {}
  for _, st in ipairs(list) do
    if type(st) == "table" and st.rank ~= "deprecated" and type(st.mainsnak) == "table" then
      local dv = st.mainsnak.datavalue
      if type(dv) == "table" and dv.value ~= nil then
        out[#out + 1] = { value = dv.value, qualifiers = st.qualifiers }
      end
    end
  end
  return out
end

local function claim_qids(entity, prop)
  local out = {}
  for _, st in ipairs(statements(entity, prop)) do
    if type(st.value) == "table" then
      local qid = valid_qid(st.value.id)
      if qid then out[#out + 1] = { qid = qid, qualifiers = st.qualifiers } end
    end
  end
  return out
end

local function claim_strings(entity, prop)
  local out = {}
  for _, st in ipairs(statements(entity, prop)) do
    local s = text(st.value)
    if s then out[#out + 1] = s end
  end
  return out
end

local function claim_monolingual(entity, prop, want_list)
  local all = {}
  for _, st in ipairs(statements(entity, prop)) do
    if type(st.value) == "table" then
      local t = text(st.value.text)
      local l = text(st.value.language)
      if t then
        all[#all + 1] = { text = t, language = l and koona.lang.tag(l) or nil }
      end
    end
  end
  if #all == 0 then return nil, nil end
  for _, want in ipairs(want_list) do
    for _, item in ipairs(all) do
      if item.language == want then return item.text, item.language end
    end
  end
  return all[1].text, all[1].language
end

local function is_book_entity(entity)
  if type(entity) ~= "table" or type(entity.claims) ~= "table" then return false end
  local c = entity.claims
  return c.P50 ~= nil or c.P212 ~= nil or c.P957 ~= nil or c.P629 ~= nil
    or c.P1476 ~= nil or c.P123 ~= nil or c.P655 ~= nil or c.P179 ~= nil
end

local function label_for(entity, want_list)
  if type(entity) ~= "table" or type(entity.labels) ~= "table" then return nil, nil end
  local labels = entity.labels
  for _, lang in ipairs(want_list) do
    local entry = labels[lang]
    if type(entry) == "table" and text(entry.value) then
      return entry.value, lang
    end
  end
  for _, lang in ipairs(OTHER_LANGS) do
    local entry = labels[lang]
    if type(entry) == "table" and text(entry.value) then
      return entry.value, lang
    end
  end
  for lang, entry in pairs(labels) do
    if type(entry) == "table" and text(entry.value) then
      return entry.value, koona.lang.tag(lang)
    end
  end
  return nil, nil
end

local function other_labels(entity, own_text)
  if type(entity) ~= "table" or type(entity.labels) ~= "table" then return nil end
  local out = {}
  local count = 0
  for _, lang in ipairs(OTHER_LANGS) do
    local entry = entity.labels[lang]
    if type(entry) == "table" and text(entry.value) and entry.value ~= own_text then
      out[lang] = entry.value
      count = count + 1
    end
  end
  if count > 0 then return out end
  return nil
end

local function parse_time(entity, prop)
  for _, st in ipairs(statements(entity, prop)) do
    if type(st.value) == "table" and type(st.value.time) == "string" then
      local y, m, d = st.value.time:match("^[+]?(%d%d%d%d)%-(%d%d)%-(%d%d)T")
      if y then
        if m == "00" then return y end
        if d == "00" then return y .. "-" .. m end
        return y .. "-" .. m .. "-" .. d
      end
    end
  end
  return nil
end

local function isbn_digits(raw)
  local s = text(raw)
  if not s then return nil end
  local clean = s:gsub("[%-%s]", ""):upper()
  if clean:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d$") or clean:match("^%d%d%d%d%d%d%d%d%d[%dX]$") then
    return clean
  end
  return nil
end

local function pick_isbn(entity, asked)
  local isbn13, any
  for _, prop in ipairs({ "P212", "P957" }) do
    for _, raw in ipairs(claim_strings(entity, prop)) do
      local clean = isbn_digits(raw)
      if clean then
        if clean == asked then return clean end
        if #clean == 13 then isbn13 = isbn13 or clean end
        any = any or clean
      end
    end
  end
  return isbn13 or any
end

local function commons_cover(filename)
  local s = text(filename)
  if not s then return nil end
  if s:find("/", 1, true) or s:find("\\", 1, true) or s:find("..", 1, true) then
    return nil
  end
  local normalized = s:gsub(" ", "_")
  return { url = COMMONS .. koona.url.encode(normalized) .. "?width=1000" }
end

local function entity_cover(entity)
  for _, name in ipairs(claim_strings(entity, "P18")) do
    local c = commons_cover(name)
    if c then return c end
  end
  return nil
end

local function lang_of(entity, prop)
  for _, ref in ipairs(claim_qids(entity, prop)) do
    local tag = LANG_QID[ref.qid]
    if tag then return tag end
  end
  return nil
end

local function series_index(qualifiers)
  if type(qualifiers) ~= "table" or type(qualifiers.P1545) ~= "table" then return nil end
  for _, q in ipairs(qualifiers.P1545) do
    if type(q) == "table" and type(q.datavalue) == "table" and type(q.datavalue.value) == "string" then
      local n = tonumber(q.datavalue.value)
      if n and n >= 0 and n <= 100000 then return n end
    end
  end
  return nil
end

local function want_langs(query)
  local out, seen = {}, {}
  local function add(tag)
    local p = type(tag) == "string" and tag:match("^%a%a") or nil
    if p and not seen[p] then
      seen[p] = true
      out[#out + 1] = p
    end
  end
  if type(query.want) == "table" then
    for _, tag in ipairs(query.want) do add(tag) end
  end
  if type(query.languages) == "table" then
    for _, tag in ipairs(query.languages) do add(tag) end
  end
  add("en")
  return out
end

local function find_qids(query, want_list)
  local asked = query.identifiers.isbn and query.identifiers.isbn[1]
  if query.title == "" then return {}, asked end
  local qids, err
  local author = query.authors[1] or ""
  if author ~= "" then
    qids, err = search_query(query.title .. " " .. author)
    if not qids then return nil, err end
  end
  if not qids or #qids == 0 then
    qids, err = search_entities(query.title, want_list[1] or "en")
    if not qids then return nil, err end
  end
  if (not qids or #qids == 0) and want_list[1] ~= "en" then
    qids, err = search_entities(query.title, "en")
    if not qids then return nil, err end
  end
  return qids or {}, asked
end

local function collect_work_qids(book_entities)
  local qids, seen = {}, {}
  for _, ent in ipairs(book_entities) do
    for _, ref in ipairs(claim_qids(ent, "P629")) do
      if not seen[ref.qid] and #qids < MAX_CLAIM_BATCH then
        seen[ref.qid] = true
        qids[#qids + 1] = ref.qid
      end
    end
  end
  return qids
end

local function collect_label_refs(entities_list)
  local qids, seen = {}, {}
  local function add(qid)
    if qid and not seen[qid] and #qids < 40 then
      seen[qid] = true
      qids[#qids + 1] = qid
    end
  end
  for _, ent in ipairs(entities_list) do
    for _, prop in ipairs({ "P50", "P655", "P98", "P110", "P123", "P179", "P136" }) do
      for _, ref in ipairs(claim_qids(ent, prop)) do
        add(ref.qid)
      end
    end
  end
  return qids
end

local function build_people(ent, work, labels_map, want_list)
  local people, seen = {}, {}
  local function add_role(source_ent, prop, role)
    if not source_ent then return end
    for _, ref in ipairs(claim_qids(source_ent, prop)) do
      local target = labels_map[ref.qid]
      local name = label_for(target, want_list)
      if name then
        local key = role .. "\0" .. name
        if not seen[key] then
          seen[key] = true
          people[#people + 1] = {
            name = name,
            role = role,
            also = other_labels(target, name),
          }
        end
      end
    end
  end
  add_role(ent, "P50", "author")
  if #people == 0 and work then
    add_role(work, "P50", "author")
  end
  add_role(ent, "P655", "translator")
  add_role(ent, "P98", "editor")
  add_role(ent, "P110", "illustrator")
  return people
end

local function candidate(qid, ent, works_map, labels_map, want_list, asked)
  local work_ref = claim_qids(ent, "P629")[1]
  local work = work_ref and works_map[work_ref.qid] or nil

  local p1476_text, p1476_lang = claim_monolingual(ent, "P1476", want_list)
  local lbl_text, lbl_lang = label_for(ent, want_list)
  local title = p1476_text or lbl_text
  if not title then return nil end

  local subtitle = claim_monolingual(ent, "P1680", want_list)
  local language = lang_of(ent, "P407") or p1476_lang or lang_of(ent, "P364") or lbl_lang

  -- Original title: from parent work (P629) if this is an edition/translation, or from P1476/P364.
  local original
  if work then
    local orig_lang = lang_of(work, "P364") or lang_of(work, "P407")
    local orig_want = orig_lang and { orig_lang } or want_list
    local orig_text, orig_text_lang = claim_monolingual(work, "P1476", orig_want)
    if not orig_text then
      orig_text, orig_text_lang = label_for(work, orig_want)
    end
    if orig_text then
      original = { title = orig_text, language = orig_lang or orig_text_lang }
    end
  else
    local orig_lang = lang_of(ent, "P364")
    if orig_lang and orig_lang ~= language then
      local orig_text = claim_monolingual(ent, "P1476", { orig_lang })
      if not orig_text then
        orig_text = label_for(ent, { orig_lang })
      end
      if orig_text and orig_text ~= title then
        original = { title = orig_text, language = orig_lang }
      end
    end
  end

  local people = build_people(ent, work, labels_map, want_list)

  local publisher
  local pub_ref = claim_qids(ent, "P123")[1]
  if pub_ref then
    publisher = label_for(labels_map[pub_ref.qid], want_list)
  end

  local published = parse_time(ent, "P577") or (work and parse_time(work, "P577")) or nil

  local series
  local ser_ref = claim_qids(ent, "P179")[1] or (work and claim_qids(work, "P179")[1])
  if ser_ref then
    local ser_name = label_for(labels_map[ser_ref.qid], want_list)
    if ser_name then
      series = { name = ser_name, index = series_index(ser_ref.qualifiers) }
    end
  end

  local tags, tag_seen = {}, {}
  local function add_genres(src)
    if not src then return end
    for _, ref in ipairs(claim_qids(src, "P136")) do
      local g = label_for(labels_map[ref.qid], want_list)
      if g and not tag_seen[g] then
        tag_seen[g] = true
        tags[#tags + 1] = g
      end
    end
  end
  add_genres(ent)
  if #tags == 0 and work then add_genres(work) end

  local identifiers = {}
  local found_isbn = pick_isbn(ent, asked)
  if found_isbn then identifiers.isbn = { found_isbn } end
  identifiers.wikidata = { qid }

  return {
    title = title,
    subtitle = subtitle,
    language = language,
    original = original,
    other_titles = other_labels(ent, title),
    authors = people,
    publisher = publisher,
    published = published,
    series = series,
    tags = #tags > 0 and tags or nil,
    identifiers = identifiers,
    cover = entity_cover(ent) or (work and entity_cover(work)) or nil,
    page = WIKI .. qid,
    note = qid,
  }
end

local wd = {}

function wd.search(ctx, query)
  local want_list = want_langs(query)
  local langs = languages_param(want_list)
  local qids, asked = find_qids(query, want_list)
  if not qids then return { error = asked } end
  if #qids == 0 then return { rows = {} } end

  local entities, err = fetch_entities(qids, "labels|claims", langs, MAX_CLAIM_BATCH)
  if not entities then return { error = err } end

  local ordered, book_entities = {}, {}
  for _, qid in ipairs(qids) do
    local ent = entities[qid]
    if is_book_entity(ent) then
      ordered[#ordered + 1] = { qid = qid, ent = ent }
      book_entities[#book_entities + 1] = ent
      if #ordered == 10 then break end
    end
  end
  if #ordered == 0 then return { rows = {} } end

  -- Fetch parent works (P629) with labels|claims so editions inherit original title, author, series, cover.
  local work_qids = collect_work_qids(book_entities)
  local works_map = {}
  local all_with_claims = {}
  for _, ent in ipairs(book_entities) do all_with_claims[#all_with_claims + 1] = ent end
  if #work_qids > 0 then
    local fetched_works, work_err = fetch_entities(work_qids, "labels|claims", langs, MAX_CLAIM_BATCH)
    if fetched_works then
      works_map = fetched_works
      for _, qid in ipairs(work_qids) do
        if works_map[qid] then all_with_claims[#all_with_claims + 1] = works_map[qid] end
      end
    elseif work_err then
      koona.log("warn", "wikidata work lookup failed: " .. work_err)
    end
  end

  -- Fetch referenced people, publishers, series, genres with labels ONLY (never claims) to stay tiny.
  local ref_qids = collect_label_refs(all_with_claims)
  local labels_map = {}
  if #ref_qids > 0 then
    local fetched_labels, ref_err = fetch_entities(ref_qids, "labels", langs, MAX_LABEL_BATCH)
    if fetched_labels then
      labels_map = fetched_labels
    elseif ref_err then
      koona.log("warn", "wikidata label lookup failed: " .. ref_err)
    end
  end

  local out = {}
  for _, item in ipairs(ordered) do
    local c = candidate(item.qid, item.ent, works_map, labels_map, want_list, asked)
    if c then out[#out + 1] = c end
  end
  return { rows = out }
end

function wd.covers(ctx, query)
  local want_list = want_langs(query)
  local langs = languages_param(want_list)
  local qids, asked = find_qids(query, want_list)
  if not qids then return { error = asked } end
  if #qids == 0 then return { rows = {} } end

  local entities, err = fetch_entities(qids, "claims", langs, MAX_CLAIM_BATCH)
  if not entities then return { error = err } end

  local out, seen = {}, {}
  local function add(c)
    if c and not seen[c.url] and #out < 20 then
      seen[c.url] = true
      out[#out + 1] = c
    end
  end

  local work_qids, work_seen = {}, {}
  for _, qid in ipairs(qids) do
    local ent = entities[qid]
    if is_book_entity(ent) then
      for _, name in ipairs(claim_strings(ent, "P18")) do
        add(commons_cover(name))
      end
      for _, ref in ipairs(claim_qids(ent, "P629")) do
        if not work_seen[ref.qid] and #work_qids < MAX_CLAIM_BATCH then
          work_seen[ref.qid] = true
          work_qids[#work_qids + 1] = ref.qid
        end
      end
    end
  end

  if #work_qids > 0 and #out < 20 then
    local works = fetch_entities(work_qids, "claims", langs, MAX_CLAIM_BATCH)
    if works then
      for _, qid in ipairs(work_qids) do
        local w = works[qid]
        if type(w) == "table" then
          for _, name in ipairs(claim_strings(w, "P18")) do
            add(commons_cover(name))
          end
        end
      end
    end
  end

  return { rows = out }
end

return wd
