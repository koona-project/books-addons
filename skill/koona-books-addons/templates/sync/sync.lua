-- Example Shelf: keeps reading in step with a shelf on a server the person names. The service
-- is made up; its API is the smallest one a reading sync needs:
--   GET  /api/v1/me                    -> { name }, or 401
--   GET  /api/v1/shelf?after=<cursor>  -> { books = { entry, ... }, next = "<cursor>" or null }
--   PUT  /api/v1/shelf/<id>            { state, percent, finished_on } -> { id }
--   POST /api/v1/shelf                 { isbn, state, percent, finished_on } -> { id }, or 404
-- An entry: { id, isbn, title, authors, state = "want" | "reading" | "finished" | "dropped",
--             percent = 0-100, updated_at = "<RFC 3339>", finished_on = "YYYY-MM-DD" }.
--
-- Koona Books keeps the hard half: which book is which, the merge, the preview, Undo. This
-- script only speaks to the server.

local s = {}

-- The sign-in header, or nil and a code. The user is a setting (`ctx.settings`); the password
-- is a secret, which never is: it is asked for here and goes out only in this header.
local function auth(ctx)
  local user = ctx.settings.user
  local password = koona.secret.get("password")
  if not user or not password or password == "" then return nil, "not_set_up" end
  return { ["authorization"] = "Basic " .. koona.base64.encode(user .. ":" .. password),
           ["accept"] = "application/json" }
end

-- One request to the server. Returns the decoded answer, or nil and a code.
local function call(ctx, method, path, body)
  local headers, why = auth(ctx)
  if not headers then return nil, why end
  if body then headers["content-type"] = "application/json" end
  local r = koona.http.request{
    method = method, url = ctx.base .. path, headers = headers, timeout = 20,
    body = body and koona.json.encode(body) or nil,
  }
  -- Status 0: no answer came. The host says why (`unreachable`, `timeout`, `limited`...):
  -- pass its code on as it is, and the app has words for it.
  if r.status == 0 then return nil, r.error or "unreachable" end
  if r.status == 401 then return nil, "bad_login" end
  if r.status == 429 then return nil, "limited" end
  if r.status == 404 then return nil, "not_found" end
  if r.status >= 500 then return nil, "unreachable" end
  if r.status >= 300 then return nil, "not_a_server" end
  -- A write that is done with nothing to say (a 204, or a 200 with no body) is an empty
  -- answer, not a failure. A read with nothing in it is no answer of this service's.
  if method ~= "GET" and (r.body or "") == "" then return {} end
  local ok, value = pcall(koona.json.decode, r.body)
  if not ok or type(value) ~= "table" then return nil, "not_a_server" end
  return value
end

-- "Test" in the server's form: who the account is. The name is shown to the person.
function s.check(ctx)
  local me, why = call(ctx, "GET", "/api/v1/me")
  -- No such page: the address leads somewhere, but not to this service.
  if not me then return { error = why == "not_found" and "not_a_server" or why } end
  -- An answer with no name in it came from something else at this address.
  if type(me.name) ~= "string" then return { error = "not_a_server" } end
  return { name = me.name }
end

-- The service's words for where a book stands, as the app's.
local STATUS = { want = "unread", reading = "reading", finished = "finished", dropped = "set_aside" }

-- One entry of the shelf as a row. By identifiers the app asks about no book of its own:
-- a row names the book by what the service knows of it, and the app pairs it.
local function row(e)
  local status = STATUS[e.state]
  if not status or type(e.id) ~= "number" then return nil end
  local says = status == "reading" or status == "finished"
  -- The app pairs a row with a book by its ISBN only. The shelf's own id pairs nothing, but a
  -- row with no identifier at all is left out: with it, an entry that has no ISBN is still
  -- kept, and may be offered to the person as "Looks the same" by its title and authors.
  local identifiers = { example_shelf = { tostring(e.id) } }
  if type(e.isbn) == "string" then identifiers.isbn = { e.isbn } end
  return {
    identifiers = identifiers,
    -- For the person to compare, when no ISBN pairs the row with a book.
    title = type(e.title) == "string" and e.title or nil,
    authors = type(e.authors) == "table" and e.authors or nil,
    status = status,
    progress = status == "reading" and type(e.percent) == "number" and e.percent / 100 or nil,
    -- A time only when the row says something of the reading.
    read_at = says and e.updated_at or nil,
    finished_at = status == "finished" and e.finished_on or nil,
    -- The script's own note: handed back with a change of this book.
    remote = { id = e.id },
  }
end

-- The whole shelf, a page at a time: the app calls again with `next` as `ask.cursor`.
function s.pull(ctx, ask)
  local path = "/api/v1/shelf"
  if ask.cursor then path = path .. "?after=" .. koona.url.encode(ask.cursor) end
  local page, why = call(ctx, "GET", path)
  -- `not_found` is the word for one book the service does not know. No shelf at this address
  -- is another thing: this is not the server.
  if not page then return { error = why == "not_found" and "not_a_server" or why } end
  local rows = {}
  for _, e in ipairs(type(page.books) == "table" and page.books or {}) do
    rows[#rows + 1] = type(e) == "table" and row(e) or nil
  end
  return { rows = rows, next = type(page.next) == "string" and page.next or nil }
end

-- The app's words for where a book stands, as the service's: the same table, the other way.
local STATE = {}
for theirs, ours in pairs(STATUS) do STATE[ours] = theirs end

-- A change as the server writes it.
local function body_of(change)
  return {
    state = STATE[change.status],
    percent = change.progress and math.floor(change.progress * 100 + 0.5) or nil,
    finished_on = change.finished_at and change.finished_at:sub(1, 10) or nil,
  }
end

-- Sends changes, one request each. Every change gets a result with its `key`.
function s.push(ctx, changes)
  local results = {}
  for i, change in ipairs(changes) do
    local body, done, why = body_of(change), nil, nil
    local id = type(change.remote) == "table" and change.remote.id
    if id then
      done, why = call(ctx, "PUT", "/api/v1/shelf/" .. tostring(id), body)
    else
      -- Not on the shelf yet: added by its ISBN, the one thing the app hands over for it.
      local isbns = type(change.identifiers) == "table" and change.identifiers.isbn
      body.isbn = type(isbns) == "table" and isbns[1] or nil
      if body.isbn then
        done, why = call(ctx, "POST", "/api/v1/shelf", body)
      else
        why = "not_found"
      end
    end
    if done then
      -- The note for this book: its id on the shelf. An add that answered with no id leaves
      -- no note; the next pull brings the entry with its id, paired by the ISBN.
      local now = type(done.id) == "number" and done.id or id
      results[#results + 1] = { key = change.key, remote = now and { id = now } or nil }
    elseif why == "limited" or why == "bad_login" or why == "unreachable" or why == "timeout" then
      -- The server stops taking changes: what was sent stands, the rest waits for later.
      results[#results + 1] = { key = change.key, error = why }
      return { results = results, stopped = why }
    else
      results[#results + 1] = { key = change.key, error = why }
    end
    koona.progress(i, #changes)
  end
  return { results = results }
end

return s
