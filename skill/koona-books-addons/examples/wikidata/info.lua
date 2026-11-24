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
-- Hits asked of each search. Films, people and characters of the same title take many of
-- them and are left out, so a search asks for twice the candidates the app keeps; their
-- claims still come in batches of MAX_CLAIM_BATCH, each well under the answer's 1 MiB.
local MAX_HITS = 20
-- Candidates the app keeps of one search.
local MAX_BOOKS = 10

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
  Q747381 = true, -- light novel (checked 2026-11-24)
  Q83790 = true, -- textbook (checked 2026-11-24)
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
    { "srlimit", tostring(MAX_HITS) },
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
    { "limit", tostring(MAX_HITS) },
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
-- that is, among the works fetched (any edition, when the works could not be fetched); or,
-- with no class at all, an item with an ISBN, an edition nobody has typed yet.
local function is_book(entity, works_map, works_failed)
  if of_book_class(entity) then return true end
  local works = claim_qids(entity, "P629")
  for _, ref in ipairs(works) do
    if of_book_class(works_map[ref.qid]) then return true end
  end
  if #works > 0 and works_failed then return true end
  return #claim_qids(entity, "P31") == 0
    and (#claim_strings(entity, "P212") > 0 or #claim_strings(entity, "P957") > 0)
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
-- the words of the other, an initial standing for a word that starts with it. A name in
-- Chinese, Japanese or Korean is also compared with its spaces left out ("村上 春樹" is
-- "村上春樹").

-- The most other names of one person the app keeps.
local MAX_ALSO = 10

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

-- A mark that belongs to the letter before it, as decomposed text (NFD, as macOS file names
-- have it) writes one.
local function is_mark(cp)
  return (cp >= 0x300 and cp <= 0x36F) or (cp >= 0x1AB0 and cp <= 0x1AFF)
    or (cp >= 0x1DC0 and cp <= 0x1DFF) or (cp >= 0x20D0 and cp <= 0x20FF)
    or (cp >= 0xFE20 and cp <= 0xFE2F) or cp == 0x3099 or cp == 0x309A
end

-- Kana whose voiced form is not the next code point.
local KANA_VOICED = {
  [0x3046] = 0x3094, [0x30A6] = 0x30F4, [0x30EF] = 0x30F7, [0x30F0] = 0x30F8,
  [0x30F1] = 0x30F9, [0x30F2] = 0x30FA, [0x309D] = 0x309E, [0x30FD] = 0x30FE,
}

-- The letter `prev` and the decomposed piece `cp` after it as one composed letter, where
-- composing changes what is compared: й and ї, a voiced kana, a Hangul syllable. Nil when
-- they stay apart (an accent on a Latin letter is dropped: the loose comparison drops it too).
local function composed(prev, cp)
  if not prev then return nil end
  if cp == 0x306 and prev == 0x438 then return 0x439 end
  if cp == 0x308 and prev == 0x456 then return 0x457 end
  local kana = prev >= 0x3041 and prev <= 0x30FE
  if cp == 0x3099 and kana then return KANA_VOICED[prev] or prev + 1 end
  if cp == 0x309A and kana then return prev + 2 end
  if prev >= 0x1100 and prev <= 0x1112 and cp >= 0x1161 and cp <= 0x1175 then
    return 0xAC00 + ((prev - 0x1100) * 21 + (cp - 0x1161)) * 28
  end
  if prev >= 0xAC00 and prev <= 0xD7A3 and (prev - 0xAC00) % 28 == 0 and cp >= 0x11A8 and cp <= 0x11C2 then
    return prev + (cp - 0x11A7)
  end
  return nil
end

-- Whether a code point is written by Chinese, Japanese or Korean, whose names run their words
-- together as often as not.
local function is_cjk(cp)
  return (cp >= 0x1100 and cp <= 0x11FF) or (cp >= 0x3040 and cp <= 0x30FF)
    or (cp >= 0x3130 and cp <= 0x318F) or (cp >= 0x31F0 and cp <= 0x31FF)
    or (cp >= 0x3400 and cp <= 0x4DBF) or (cp >= 0x4E00 and cp <= 0x9FFF)
    or (cp >= 0xAC00 and cp <= 0xD7AF) or (cp >= 0xF900 and cp <= 0xFAFF)
    or (cp >= 0x20000 and cp <= 0x3FFFF)
end

-- Whether a code point, in lower case, is part of a word: a letter or a digit, as near as
-- the blocks of punctuation can say.
local function in_word(cp)
  if cp < 0x80 then return (cp >= 0x30 and cp <= 0x39) or (cp >= 0x61 and cp <= 0x7A) end
  if cp <= 0xBF or cp == 0xD7 or cp == 0xF7 then return false end
  if cp >= 0x2000 and cp <= 0x2BFF then return false end
  if cp >= 0x2E00 and cp <= 0x2E7F then return false end
  if (cp >= 0x3000 and cp <= 0x303F) or cp == 0x30FB then return false end
  if cp >= 0xFF00 and cp <= 0xFF20 then return false end
  return true
end

-- The words of a name, folded: lower case, ё as е, composed, anything but letters and digits
-- between words; and whether it is written in Chinese, Japanese or Korean.
local function name_words(name)
  local words, word, cjk = {}, {}, false
  local function flush()
    if #word > 0 then
      local chars = {}
      for i, cp in ipairs(word) do chars[i] = utf8.char(cp) end
      words[#words + 1] = table.concat(chars)
      word = {}
    end
  end
  for _, cp in utf8.codes(name) do
    cp = lower(cp)
    local joins = is_mark(cp) or (cp >= 0x1161 and cp <= 0x11C2)
    local joined = joins and composed(word[#word], cp) or nil
    if joined then
      word[#word] = joined
    elseif is_mark(cp) then
      -- An accent with no letter to join: left out.
    elseif in_word(cp) then
      cjk = cjk or is_cjk(cp)
      word[#word + 1] = cp
    else
      flush()
    end
  end
  flush()
  return words, cjk
end

-- A word in Latin letters with no marks, or nil when it is in another script.
local function latin(word)
  local out = {}
  for _, cp in utf8.codes(word) do
    out[#out + 1] = LATIN_PLAIN[cp] or CYRILLIC_LATIN[cp] or utf8.char(cp)
  end
  local s = table.concat(out)
  if s:find("[^%l%d]") then return nil end
  return s
end

-- A word, in Latin letters, as its consonants: the letters scripts render each their own way
-- left out (the vowels after the first letter, h, j, v, w) and a doubled letter made one.
-- "Скотт" and "Scott" are both "skt".
local function consonants(s)
  s = s:gsub("ph", "f"):gsub("[cq]", "k"):gsub("x", "ks"):gsub("[vw]", "")
  s = s:sub(1, 1) .. s:sub(2):gsub("[aeiouyhj]", "")
  local n
  repeat
    s, n = s:gsub("(%l)%1", "%1")
  until n == 0
  return s
end

-- The sound a word in Latin letters starts with, as an initial stands for it in any script:
-- "J." for "Джон", "W." for "Вальтер".
local function initial(s)
  local head = s:match("^dzh") and "j" or s:match("^zh") and "j" or s:match("^kh") and "h"
    or s:match("^ph") and "f" or s:sub(1, 1)
  if head:match("[ijy]") then return "i" end
  if head:match("[gh]") then return "g" end
  if head:match("[vw]") then return "v" end
  if head:match("[ckq]") then return "k" end
  return head
end

-- A name made ready to compare: its words in a fixed order, as the app reads a name; its
-- words of two letters or more as consonants, and the initials its one-letter words stand
-- for; and, for a name in Chinese, Japanese or Korean, its words run together.
local function prepared(name)
  local words, cjk = name_words(name)
  local sorted, loose, count, initials, parts = {}, {}, 0, {}, {}
  for i, w in ipairs(words) do
    sorted[i] = w
    local l = latin(w)
    if utf8.len(w) >= 2 then
      local c = l and consonants(l) or w
      if c ~= "" then
        if not loose[c] then count = count + 1 end
        loose[c] = true
        parts[#parts + 1] = { key = c, first = l and initial(l) or nil }
      end
    elseif l then
      initials[#initials + 1] = initial(l)
      parts[#parts + 1] = { first = initial(l) }
    end
  end
  table.sort(sorted)
  return {
    key = table.concat(sorted, " "),
    compact = cjk and table.concat(words) or nil,
    loose = loose,
    count = count,
    initials = initials,
    parts = parts,
  }
end

-- Whether every word of `a` is a word of `b`, and each initial of `a` starts another word of
-- `b`; `a` has to have a word.
local function within(a, b)
  if a.count == 0 then return false end
  for word in pairs(a.loose) do
    if not b.loose[word] then return false end
  end
  for _, i in ipairs(a.initials) do
    local found = false
    for _, part in ipairs(b.parts) do
      if part.first == i and not (part.key and a.loose[part.key]) then
        found = true
        break
      end
    end
    if not found then return false end
  end
  return true
end

-- Whether the library's name (`asked`) and a name Wikidata has (`spelling`) are one person's.
-- The library's may be a part of Wikidata's ("Скотт" of "Вальтер Скотт"); Wikidata's may be
-- a part of the library's only when it is more than one word ("Скотт В." is, "Скотт" is not).
local function same_name(asked, spelling)
  if asked.key ~= "" and asked.key == spelling.key then return true end
  if asked.compact and asked.compact == spelling.compact then return true end
  if within(asked, spelling) then return true end
  return spelling.count + #spelling.initials >= 2 and within(spelling, asked)
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
      loose = loose or same_name(a, sp.name)
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

-- A person's other names by language: `first` (a language and a name) before the labels in
-- OTHER_LANGS, none that is `own`, at most MAX_ALSO.
local function also_of(target, own, first_lang, first_name)
  local labels = type(target) == "table" and type(target.labels) == "table" and target.labels or {}
  local out, count = {}, 0
  local function add(lang, value)
    if count < MAX_ALSO and lang and out[lang] == nil and text(value) and value ~= own then
      out[lang] = value
      count = count + 1
    end
  end
  add(first_lang, first_name)
  for _, lang in ipairs(OTHER_LANGS) do
    local entry = labels[lang]
    if type(entry) == "table" then add(lang, entry.value) end
  end
  if count > 0 then return out end
  return nil
end

-- An author, as the library writes them when one of their names is exactly an asked name:
-- the app then sees its own author in the candidate, and the label it would have been
-- shown under is one of the other names.
local function as_asked(target, name, name_lang, asked)
  local own = prepared(name).key
  for _, a in ipairs(asked) do
    if a.key == own then return name, also_of(target, name) end
  end
  local _, same = person_agrees(target, asked)
  if not same then return name, also_of(target, name) end
  return same.text, also_of(target, same.text, name_lang, name)
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

-- The searches for the query, in order, each tried only while none before it found a book:
-- the title and author in full text, then the title among items' names in the language
-- wanted first, then in English.
local function searches(query, want_list)
  local out = {}
  if query.title == "" then return out end
  local author = query.authors[1] or ""
  if author ~= "" then
    out[#out + 1] = function() return search_query(query.title .. " " .. author) end
  end
  local first = want_list[1] or "en"
  out[#out + 1] = function() return search_entities(query.title, first) end
  if first ~= "en" then
    out[#out + 1] = function() return search_entities(query.title, "en") end
  end
  return out
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
          also = also_of(target, name)
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

-- The books among `qids` (not yet fetched), in order, each { qid, ent, work }: their claims
-- fetched by `props`, and the works they are editions of (P629) with them. An item that is
-- not a book (a film of the same name, its poster, a person) is left out.
local function books_among(qids, fetched, props, langs)
  local entities, err = fetch_entities(qids, props, langs, MAX_CLAIM_BATCH)
  if not entities then return nil, err end
  local added = {}
  for k, v in pairs(entities) do
    if not fetched[k] then added[#added + 1] = k end
    fetched[k] = v
  end

  local work_qids, work_seen = {}, {}
  for _, qid in ipairs(qids) do
    for _, ref in ipairs(claim_qids(entities[qid], "P629")) do
      if not work_seen[ref.qid] and #work_qids < MAX_CLAIM_BATCH then
        work_seen[ref.qid] = true
        work_qids[#work_qids + 1] = ref.qid
      end
    end
  end
  -- Works with their claims, so editions inherit the original title, author, series and
  -- cover, and say whether an edition with no class of its own is a book's. A work already
  -- fetched is not asked for again.
  local to_fetch, works_failed = {}, false
  for _, qid in ipairs(work_qids) do
    if not fetched[qid] then to_fetch[#to_fetch + 1] = qid end
  end
  if #to_fetch > 0 then
    local works, work_err = fetch_entities(to_fetch, props, langs, MAX_CLAIM_BATCH)
    if works then
      for k, v in pairs(works) do
        if not fetched[k] then added[#added + 1] = k end
        fetched[k] = v
      end
    else
      works_failed = true
      koona.log("warn", "wikidata work lookup failed: " .. tostring(work_err))
    end
  end

  local books, keep = {}, {}
  for _, qid in ipairs(qids) do
    local ent = entities[qid]
    if type(ent) == "table" and is_book(ent, fetched, works_failed) then
      local work_ref = claim_qids(ent, "P629")[1]
      books[#books + 1] = { qid = qid, ent = ent, work = work_ref and fetched[work_ref.qid] or nil }
      keep[qid] = true
      for _, ref in ipairs(claim_qids(ent, "P629")) do keep[ref.qid] = true end
    end
  end
  -- What is no book, and no book's work, is not kept: a call has 32 MiB, and the claims of
  -- a few dozen items are a good part of it.
  for _, k in ipairs(added) do
    if not keep[k] then fetched[k] = nil end
  end
  return books
end

-- The books found for the query, in the catalog's order, each { qid, ent, work }, with the
-- items their claims name (`ref_props`) fetched by labels and aliases. The searches are tried
-- in turn until one finds a book. When the query names an author, a book whose authors are
-- known and are others is left out, and so is a book whose authors are not known when
-- another's are the ones asked for.
local function find_books(query, props, ref_props)
  local want_list = want_langs(query)
  local langs = languages_param(want_list)
  local found = {
    books = {},
    labels = {},
    want = want_list,
    isbn = query.identifiers.isbn and query.identifiers.isbn[1],
    asked = asked_names(query),
  }

  local books, fetched, tried = {}, {}, {}
  for _, run in ipairs(searches(query, want_list)) do
    local qids, err = run()
    if not qids then return nil, err end
    local fresh = {}
    for _, qid in ipairs(qids) do
      if not tried[qid] then
        tried[qid] = true
        fresh[#fresh + 1] = qid
      end
    end
    if #fresh > 0 then
      local more, more_err = books_among(fresh, fetched, props, langs)
      if not more then return nil, more_err end
      for _, b in ipairs(more) do books[#books + 1] = b end
    end
    if #books > 0 then break end
  end
  found.fetched = fetched
  if #books == 0 then return found end

  -- The people, publishers, series and genres named, by labels and aliases only (never
  -- claims), to stay small.
  local with_claims = {}
  for i = 1, math.min(#books, MAX_HITS) do
    with_claims[#with_claims + 1] = books[i].ent
    if books[i].work then with_claims[#with_claims + 1] = books[i].work end
  end
  local ref_qids = collect_label_refs(with_claims, ref_props)
  if #ref_qids > 0 then
    local labels, ref_err = fetch_entities(ref_qids, "labels|aliases", langs, MAX_LABEL_BATCH)
    if labels then
      found.labels = labels
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
  for i = 1, math.min(#books, MAX_BOOKS) do found.books[i] = books[i] end
  found.fetched = fetched
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
  -- Then the covers of every work each book is an edition of.
  for _, book in ipairs(found.books) do
    for _, ref in ipairs(claim_qids(book.ent, "P629")) do
      for _, name in ipairs(claim_strings(found.fetched[ref.qid], "P18")) do
        add(commons_cover(name))
      end
    end
  end
  return { rows = out }
end

return wd
