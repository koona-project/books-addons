-- KOReader sync: keeps a book's place in step with a KOReader progress-sync server, the one
-- KOReader devices and Xteink readers on CrossPoint sync with.
--
-- Written from the protocol as KOReader's and CrossPoint's sources describe it:
--   headers  Accept: application/vnd.koreader.v1+json, x-auth-user, x-auth-key = MD5 of the password
--   GET /users/auth                 -> 200, or 401
--   GET /syncs/progress/<document>  -> { percentage, progress, device, device_id, timestamp },
--                                      {} when the server has nothing (others answer 204 or 404)
--   PUT /syncs/progress             { document, progress, percentage, device, device_id }
--
-- A book is known to the server by a digest of its file. Koona Books works that out itself from
-- the copy it sent to a reader and hands it over as the book's `key`: this script never sees a
-- file, a title or an author.
--
-- A reading sync answers with a table: rows, results (a change made is its key alone), or
-- `{ error = "<code>" }`. When the
-- server stops taking requests part-way (a limit, a dropped connection, the password changed),
-- what was done before stands: `{ results = ..., stopped = "<code>" }` from push, and from a
-- pull that was asked about some books already `{ rows = ..., stopped = "limited" }`.

local s = {}

local ACCEPT = "application/vnd.koreader.v1+json"

-- A user name the server can be told in a header: printable ASCII (a space only inside it),
-- no control character, no line break. The host puts no other text into a header, so a name
-- with anything else in it (letters of another alphabet, a pasted line break) is said so.
local function user_ok(user)
  return not user:find("[^\32-\126]") and not user:find("^ ") and not user:find(" $")
end

-- The sign-in headers, or nil and a code: `not_set_up` when the person has not given a user
-- and a password, `bad_user` for a user name that cannot go into a header.
local function auth(ctx)
  local user = ctx.settings and ctx.settings.user
  local password = koona.secret.get("password")
  if type(user) ~= "string" or user == "" then return nil, "not_set_up" end
  if type(password) ~= "string" or password == "" then return nil, "not_set_up" end
  if not user_ok(user) then return nil, "bad_user" end
  return {
    ["accept"] = ACCEPT,
    ["x-auth-user"] = user,
    ["x-auth-key"] = koona.hash.md5(password),
  }
end

local function json(r)
  if type(r.body) ~= "string" then return nil end
  local ok, value = pcall(koona.json.decode, r.body)
  if ok and type(value) == "table" then return value end
  return nil
end

-- Why nothing came back: the host's own code ("unreachable", "timeout", "limited", ...).
local function trouble(r)
  return { error = type(r.error) == "string" and r.error or "unreachable" }
end

-- Why one request failed in a way that ends the call, or nil when it did not.
local function stop_code(r)
  if r.status == 0 then return trouble(r).error end
  if r.status == 401 or r.status == 403 then return "bad_login" end
  if r.status == 429 then return "limited" end
  return nil
end

function s.check(ctx)
  if type(ctx.base) ~= "string" then return { error = "not_set_up" } end
  local headers, why = auth(ctx)
  if not headers then return { error = why } end
  local r = koona.http.request{ url = ctx.base .. "/users/auth", headers = headers, timeout = 10 }
  if r.status == 0 then return trouble(r) end
  if r.status == 401 or r.status == 403 then return { error = "bad_login" } end
  -- Something answers (a website, a router's page), but not as a sync server does.
  if r.status ~= 200 or not json(r) then return { error = "not_a_server" } end
  return { name = ctx.settings.user }
end

function s.pull(ctx, ask)
  if type(ctx.base) ~= "string" then return { error = "not_set_up" } end
  local headers, why = auth(ctx)
  if not headers then return { error = why } end
  local rows = {}
  local books = ask.books or {}
  for i, book in ipairs(books) do
    local r = koona.http.request{
      url = ctx.base .. "/syncs/progress/" .. koona.url.encode(book.key),
      headers = headers, timeout = 10,
    }
    local stop = stop_code(r) or (r.status >= 500 and "unreachable" or nil)
    if stop then
      -- A limit after some books were asked about: the rows found so far stand, and the
      -- app asks about the rest later. Anything else, or a limit at the first book, ends
      -- the whole call.
      if stop == "limited" and i > 1 then return { rows = rows, stopped = stop } end
      return { error = stop }
    end
    local at = r.status == 200 and json(r) or nil
    -- Nothing kept for this book is `{}`, 204 or 404: no row.
    if at and type(at.percentage) == "number" and at.percentage >= 0 and at.percentage <= 1 then
      rows[#rows + 1] = {
        key = book.key,
        -- The server keeps how far, not whether the book is done: the last page is "finished".
        status = at.percentage >= 0.999 and "finished" or "reading",
        progress = at.percentage,
        -- Seconds since 1970, as the server wrote them. Not for a place this computer wrote
        -- there itself: that time is when it was written, not when the book was read, and by
        -- the server's clock it must not look newer than what was read here since.
        read_at = at.device_id ~= ctx.client.id and type(at.timestamp) == "number" and at.timestamp or nil,
      }
    end
    -- Books asked about so far, of all of them: the bar moves when nothing is found.
    koona.progress(i, #books)
  end
  return { rows = rows }
end

function s.push(ctx, changes)
  if type(ctx.base) ~= "string" then return { error = "not_set_up" } end
  local headers, why = auth(ctx)
  if not headers then return { error = why } end
  headers["content-type"] = "application/json"
  local results = {}
  for i, change in ipairs(changes) do
    local share = change.status == "finished" and 1 or change.progress
    if type(share) ~= "number" then
      results[#results + 1] = { key = change.key, error = "no_place" }
    else
      local r = koona.http.request{
        method = "PUT", url = ctx.base .. "/syncs/progress", headers = headers, timeout = 10,
        body = koona.json.encode{
          document = change.key,
          -- The exact place is the reader's own address in the book, which Koona Books does
          -- not have. The server refuses an empty one, so the share stands in for it;
          -- CrossPoint finds the place from `percentage`.
          progress = string.format("%.4f", share),
          percentage = share,
          device = ctx.client.name,
          device_id = ctx.client.id,
        },
      }
      local stop = stop_code(r)
      if stop then
        -- The server stopped taking changes: the ones already sent stand, this one and the
        -- rest are not sent, and the call says why.
        results[#results + 1] = { key = change.key, error = stop }
        return { results = results, stopped = stop }
      end
      if r.status == 200 or r.status == 202 then
        results[#results + 1] = { key = change.key }
      else
        results[#results + 1] = { key = change.key, error = "refused" }
      end
    end
    koona.progress(i, #changes)
  end
  return { results = results }
end

return s
