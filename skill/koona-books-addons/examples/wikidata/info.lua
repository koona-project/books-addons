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

-- What an item must be an instance of (P31) to be a book: a work of writing, or one edition
-- of one. The Action API cannot follow subclasses, so these are the classes book items use.
-- Checked against Wikidata on 2026-11-24: "literary work", "written work" and "version,
-- edition or translation" hold nearly all books; novel, short story, novella, poem and play
-- now go in P7937 (form of creative work) and stay here for the items that still use them.
-- A film, a TV series, an opera, a song, a character, a person or a scholarly article is
-- none of these, whatever title it has.
local BOOK_CLASSES = {
  -- A work.
  Q7725634 = true, -- literary work
  Q47461344 = true, -- written work
  Q571 = true, -- book
  Q8261 = true, -- novel
  Q149537 = true, -- novella
  Q49084 = true, -- short story
  Q1279564 = true, -- short story collection
  Q12106333 = true, -- poetry collection
  Q5185279 = true, -- poem
  Q25379 = true, -- play
  Q116476516 = true, -- dramatic work
  Q35760 = true, -- essay
  Q20540385 = true, -- non-fiction literary work
  Q193495 = true, -- monograph
  Q1711593 = true, -- edited volume
  Q1238720 = true, -- volume
  Q36279 = true, -- biography
  Q8275050 = true, -- children's book
  Q699 = true, -- fairy tale
  Q24723 = true, -- literary fairy tale
  Q1347298 = true, -- serialized fiction
  Q1760610 = true, -- comic book
  Q2831984 = true, -- comic book album
  Q725377 = true, -- graphic novel
  Q8274 = true, -- manga
  Q13136 = true, -- reference work
  Q23622 = true, -- dictionary
  -- One edition of a work.
  Q3331189 = true, -- version, edition or translation
  Q57933693 = true, -- book edition
  Q21112633 = true, -- edition of a translation
  Q125309905 = true, -- translated work
  Q59466300 = true, -- print edition
  Q10898227 = true, -- first edition
  Q1224889 = true, -- digital edition
}

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

-- Whether the item is an instance of a book's class: a work of writing or an edition.
local function of_book_class(entity)
  for _, ref in ipairs(claim_qids(entity, "P31")) do
    if BOOK_CLASSES[ref.qid] then return true end
  end
  return false
end

-- Whether the item is a book: of a book's class itself, or an edition of (P629) a work
-- that is, among the works fetched.
local function is_book(entity, works_map)
  if of_book_class(entity) then return true end
  for _, ref in ipairs(claim_qids(entity, "P629")) do
    if of_book_class(works_map[ref.qid]) then return true end
  end
  return false
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

-- ---- Names ---------------------------------------------------------------------------------
--
-- A person's name is compared two ways. As the app compares it: the same words in any order,
-- case and ё aside ("Скотт, Вальтер" is "Вальтер Скотт"). And loosely, to see past the
-- script: each word written in Latin letters with no marks and cut to its consonants
-- ("Вальтер Скотт" and "Walter Scott" are both "altr skt"), the words of one name all among
-- the words of the other. Initials are not compared loosely.

-- A Latin letter with marks, in lower case, as the letters without them.
local LATIN_PLAIN = {}
for plain, marked in pairs({
  a = "àáâãäåāăą", c = "çćĉċč", d = "ďđð", e = "èéêëēĕėęě", g = "ĝğġģ", h = "ĥħ",
  i = "ìíîïĩīĭįı", j = "ĵ", k = "ķ", l = "ĺļľŀł", n = "ñńņňŋ", o = "òóôõöøōŏő",
  r = "ŕŗř", s = "śŝşšșſ", t = "ţťŧț", u = "ùúûüũūŭůűų", w = "ŵ", y = "ýÿŷ", z = "źżž",
  ae = "æ", oe = "œ", ss = "ß", th = "þ", ij = "ĳ",
}) do
  for _, cp in utf8.codes(marked) do LATIN_PLAIN[cp] = plain end
end

-- A Cyrillic letter in lower case (Russian, Ukrainian, Belarusian, Serbian) in Latin letters.
local CYRILLIC_LATIN = {}
for cyrillic, latin in pairs({
  ["а"] = "a", ["б"] = "b", ["в"] = "v", ["г"] = "g", ["д"] = "d", ["е"] = "e", ["ж"] = "zh",
  ["з"] = "z", ["и"] = "i", ["й"] = "j", ["к"] = "k", ["л"] = "l", ["м"] = "m", ["н"] = "n",
  ["о"] = "o", ["п"] = "p", ["р"] = "r", ["с"] = "s", ["т"] = "t", ["у"] = "u", ["ф"] = "f",
  ["х"] = "kh", ["ц"] = "ts", ["ч"] = "ch", ["ш"] = "sh", ["щ"] = "shch", ["ъ"] = "",
  ["ы"] = "y", ["ь"] = "", ["э"] = "e", ["ю"] = "yu", ["я"] = "ya", ["і"] = "i", ["ї"] = "yi",
  ["є"] = "ye", ["ґ"] = "g", ["ў"] = "u", ["ђ"] = "dj", ["ј"] = "j", ["љ"] = "lj",
  ["њ"] = "nj", ["ћ"] = "c", ["џ"] = "dz",
}) do
  CYRILLIC_LATIN[utf8.codepoint(cyrillic)] = latin
end

-- A code point in lower case (Latin, Greek, Cyrillic), with ё as е.
local function lower(cp)
  if (cp >= 0x41 and cp <= 0x5A) or (cp >= 0xC0 and cp <= 0xDE and cp ~= 0xD7)
    or (cp >= 0x391 and cp <= 0x3AB and cp ~= 0x3A2) or (cp >= 0x410 and cp <= 0x42F) then
    cp = cp + 0x20
  elseif cp >= 0x400 and cp <= 0x40F then
    cp = cp + 0x50
  elseif cp == 0x130 then
    cp = 0x69
  elseif cp == 0x178 then
    cp = 0xFF
  elseif (cp >= 0x100 and cp <= 0x137) or (cp >= 0x14A and cp <= 0x177) then
    if cp % 2 == 0 then cp = cp + 1 end
  elseif (cp >= 0x139 and cp <= 0x148) or (cp >= 0x179 and cp <= 0x17E) then
    if cp % 2 == 1 then cp = cp + 1 end
  end
  if cp == 0x451 then cp = 0x435 end
  return cp
end

-- Whether a code point, in lower case, is part of a word: a letter or a digit, as near as
-- the blocks of punctuation and marks can say.
local function in_word(cp)
  if cp < 0x80 then return (cp >= 0x30 and cp <= 0x39) or (cp >= 0x61 and cp <= 0x7A) end
  if cp <= 0xBF or cp == 0xD7 or cp == 0xF7 then return false end
  if cp >= 0x300 and cp <= 0x36F then return false end
  if cp >= 0x2000 and cp <= 0x2BFF then return false end
  if cp >= 0x2E00 and cp <= 0x2E7F then return false end
  if (cp >= 0x3000 and cp <= 0x303F) or cp == 0x30FB then return false end
  if cp >= 0xFF00 and cp <= 0xFF20 then return false end
  return true
end

-- The words of a name, folded: lower case, ё as е, anything but letters and digits between
-- words.
local function name_words(name)
  local words, word = {}, {}
  local function flush()
    if #word > 0 then
      words[#words + 1] = table.concat(word)
      word = {}
    end
  end
  for _, cp in utf8.codes(name) do
    cp = lower(cp)
    if in_word(cp) then word[#word + 1] = utf8.char(cp) else flush() end
  end
  flush()
  return words
end

-- A word as its consonants in Latin letters: marks dropped, Cyrillic written in Latin, then
-- the letters scripts render each their own way left out (the vowels after the first
-- letter, h, j, v, w) and a doubled letter made one. "Скотт" and "Scott" are both "skt".
-- A word of another script is kept as it is.
local function consonants(word)
  local out = {}
  for _, cp in utf8.codes(word) do
    out[#out + 1] = LATIN_PLAIN[cp] or CYRILLIC_LATIN[cp] or utf8.char(cp)
  end
  local s = table.concat(out)
  if s:find("[^%l%d]") then return s end
  s = s:gsub("ph", "f"):gsub("[cq]", "k"):gsub("x", "ks"):gsub("[vw]", "")
  s = s:sub(1, 1) .. s:sub(2):gsub("[aeiouyhj]", "")
  local n
  repeat
    s, n = s:gsub("(%l)%1", "%1")
  until n == 0
  return s
end

-- A name made ready to compare: its words in a fixed order, as the app reads a name, and
-- its words of two letters or more as consonants.
local function prepared(name)
  local words = name_words(name)
  local sorted, loose = {}, {}
  for i, w in ipairs(words) do
    sorted[i] = w
    if utf8.len(w) >= 2 then
      local c = consonants(w)
      if c ~= "" then loose[c] = true end
    end
  end
  table.sort(sorted)
  return { key = table.concat(sorted, " "), loose = loose }
end

-- Whether every word of `a` is a word of `b`, and `a` has one.
local function within(a, b)
  local any = false
  for word in pairs(a) do
    if not b[word] then return false end
    any = true
  end
  return any
end

local function same_name(a, b)
  if a.key ~= "" and a.key == b.key then return true end
  return within(a.loose, b.loose) or within(b.loose, a.loose)
end

-- The names an item goes by among the languages fetched, labels first, each language in
-- a fixed order: { text, name } with `name` made ready to compare.
local function spellings(entity)
  local out = {}
  if type(entity) ~= "table" then return out end
  for _, field in ipairs({ "labels", "aliases" }) do
    local by_lang = type(entity[field]) == "table" and entity[field] or {}
    local langs = {}
    for lang in pairs(by_lang) do
      if type(lang) == "string" then langs[#langs + 1] = lang end
    end
    table.sort(langs)
    for _, lang in ipairs(langs) do
      local list = by_lang[lang]
      if field == "labels" then list = { list } end
      if type(list) == "table" then
        for _, entry in ipairs(list) do
          if type(entry) == "table" and text(entry.value) then
            out[#out + 1] = { text = entry.value, name = prepared(entry.value) }
          end
        end
      end
    end
  end
  return out
end

-- How an item's names stand to the names asked for: nil when none of its names was fetched,
-- else whether one is the same person's, and the one of its names that is an asked name as
-- the app compares them (written just as asked, when one is).
local function person_agrees(entity, asked)
  local all = spellings(entity)
  if #all == 0 then return nil end
  local loose, exact = false, nil
  for _, sp in ipairs(all) do
    for _, a in ipairs(asked) do
      if sp.name.key ~= "" and sp.name.key == a.key then
        if sp.text == a.text then return true, sp end
        exact = exact or sp
      end
      loose = loose or same_name(sp.name, a)
    end
  end
  if exact then return true, exact end
  return loose, nil
end

-- The authors of the query, made ready to compare.
local function asked_names(query)
  local out = {}
  for _, name in ipairs(query.authors) do
    if text(name) then
      local p = prepared(name)
      p.text = name
      if p.key ~= "" then out[#out + 1] = p end
    end
  end
  return out
end

-- How a candidate's authors (P50), its own and its work's, stand to the authors asked for:
-- "same" when one of them is one, "other" when they are known and none is, nil when none
-- of their names was fetched.
local function authors_stand(ent, work, labels_map, asked)
  local known = false
  for _, source in ipairs({ ent, work or {} }) do
    for _, ref in ipairs(claim_qids(source, "P50")) do
      local agrees = person_agrees(labels_map[ref.qid], asked)
      if agrees then return "same" end
      if agrees == false then known = true end
    end
  end
  if known then return "other" end
  return nil
end

-- An author, as the library writes them when one of their names is exactly an asked name:
-- the app then sees its own author in the candidate, and the label it would have been
-- shown under is one of the other names.
local function as_asked(target, name, name_lang, asked)
  local also = other_labels(target, name)
  local own = prepared(name).key
  for _, a in ipairs(asked) do
    if a.key == own then return name, also end
  end
  local _, same = person_agrees(target, asked)
  if not same then return name, also end
  also = other_labels(target, same.text) or {}
  if name_lang then also[name_lang] = name end
  return same.text, also
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

-- The items named by these entities' claims, authors first so that a long list cuts
-- genres before people: at most 40.
local function collect_label_refs(entities_list, props)
  local qids, seen = {}, {}
  for _, prop in ipairs(props) do
    for _, ent in ipairs(entities_list) do
      for _, ref in ipairs(claim_qids(ent, prop)) do
        if not seen[ref.qid] and #qids < 40 then
          seen[ref.qid] = true
          qids[#qids + 1] = ref.qid
        end
      end
    end
  end
  return qids
end

local function build_people(ent, work, labels_map, want_list, asked)
  local people, seen = {}, {}
  local function add_role(source_ent, prop, role)
    if not source_ent then return end
    for _, ref in ipairs(claim_qids(source_ent, prop)) do
      local target = labels_map[ref.qid]
      local name, name_lang = label_for(target, want_list)
      if name then
        local also
        if role == "author" then
          name, also = as_asked(target, name, name_lang, asked)
        else
          also = other_labels(target, name)
        end
        local key = role .. "\0" .. name
        if not seen[key] then
          seen[key] = true
          people[#people + 1] = { name = name, role = role, also = also }
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

local function candidate(book, found)
  local qid, ent, work = book.qid, book.ent, book.work
  local labels_map, want_list = found.labels, found.want

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

  local people = build_people(ent, work, labels_map, want_list, found.asked)

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
  local found_isbn = pick_isbn(ent, found.isbn)
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

-- The books found for the query, in the catalog's order, each { qid, ent, work }, with the
-- items their claims name (`ref_props`) fetched by labels and aliases. An item that is not a
-- book (a film of the same name, its poster, a person) is left out. When the query names an
-- author, a book whose authors are known and are others is left out, and so is a book
-- whose authors are not known when another's are the ones asked for.
local function find_books(query, props, ref_props)
  local want_list = want_langs(query)
  local langs = languages_param(want_list)
  local qids, isbn = find_qids(query, want_list)
  if not qids then return nil, isbn end
  local found = { books = {}, labels = {}, want = want_list, isbn = isbn, asked = asked_names(query) }
  if #qids == 0 then return found end

  local entities, err = fetch_entities(qids, props, langs, MAX_CLAIM_BATCH)
  if not entities then return nil, err end

  -- An item of a book's class is a book. Another that is an edition of (P629) a work may be
  -- one: the works are fetched once, for both, and say so.
  local items, work_qids, work_seen = {}, {}, {}
  for _, qid in ipairs(qids) do
    local ent = entities[qid]
    local works = claim_qids(ent, "P629")
    if of_book_class(ent) or #works > 0 then
      items[#items + 1] = { qid = qid, ent = ent, work_ref = works[1] }
      for _, ref in ipairs(works) do
        if not work_seen[ref.qid] and #work_qids < MAX_CLAIM_BATCH then
          work_seen[ref.qid] = true
          work_qids[#work_qids + 1] = ref.qid
        end
      end
    end
  end

  -- Works with their claims, so editions inherit the original title, author, series and
  -- cover. A work the search found too is not asked for again.
  local works_map, to_fetch = {}, {}
  for _, qid in ipairs(work_qids) do
    if entities[qid] then works_map[qid] = entities[qid] else to_fetch[#to_fetch + 1] = qid end
  end
  if #to_fetch > 0 then
    local fetched, work_err = fetch_entities(to_fetch, props, langs, MAX_CLAIM_BATCH)
    if fetched then
      for k, v in pairs(fetched) do works_map[k] = v end
    elseif work_err then
      koona.log("warn", "wikidata work lookup failed: " .. work_err)
    end
  end

  local books, with_claims = {}, {}
  for _, item in ipairs(items) do
    if #books < 10 and is_book(item.ent, works_map) then
      item.work = item.work_ref and works_map[item.work_ref.qid] or nil
      books[#books + 1] = item
      with_claims[#with_claims + 1] = item.ent
      if item.work then with_claims[#with_claims + 1] = item.work end
    end
  end
  if #books == 0 then return found end

  -- The people, publishers, series and genres named, by labels and aliases only (never
  -- claims), to stay small.
  local ref_qids = collect_label_refs(with_claims, ref_props)
  if #ref_qids > 0 then
    local fetched, ref_err = fetch_entities(ref_qids, "labels|aliases", langs, MAX_LABEL_BATCH)
    if fetched then
      found.labels = fetched
    elseif ref_err then
      koona.log("warn", "wikidata label lookup failed: " .. ref_err)
    end
  end

  if #found.asked > 0 then
    local same, unknown = {}, {}
    for _, b in ipairs(books) do
      local stand = authors_stand(b.ent, b.work, found.labels, found.asked)
      if stand == "same" then
        same[#same + 1] = b
      elseif stand == nil then
        unknown[#unknown + 1] = b
      end
    end
    books = #same > 0 and same or unknown
  end
  found.books = books
  return found
end

local wd = {}

function wd.search(ctx, query)
  local found, err = find_books(query, "labels|claims", { "P50", "P655", "P98", "P110", "P123", "P179", "P136" })
  if not found then return { error = err } end
  local out = {}
  for _, book in ipairs(found.books) do
    local c = candidate(book, found)
    if c then out[#out + 1] = c end
  end
  return { rows = out }
end

function wd.covers(ctx, query)
  local found, err = find_books(query, "claims", { "P50" })
  if not found then return { error = err } end

  local out, seen = {}, {}
  local function add(c)
    if c and not seen[c.url] and #out < 20 then
      seen[c.url] = true
      out[#out + 1] = c
    end
  end
  for _, book in ipairs(found.books) do
    for _, name in ipairs(claim_strings(book.ent, "P18")) do
      add(commons_cover(name))
    end
  end
  for _, book in ipairs(found.books) do
    for _, name in ipairs(claim_strings(book.work, "P18")) do
      add(commons_cover(name))
    end
  end
  return { rows = out }
end

return wd
