-- Send starter: sends books to an "Example Reader", a made-up reader that takes books over
-- HTTP on the person's own network while its Book transfer screen is open. Change the pages
-- and the answers below to the ones your reader really has.
--
-- The reader's pages, as this starter imagines them (port 8080, no password):
--   GET  /api/info                  -> 200 { "model": "Mini", "firmware": "2.1" }
--   GET  /api/files?folder=/Books   -> 200 [ { "name": "a.epub", "size": 734003, "folder": false }, ... ]
--                                      404 when there is no such folder yet
--   POST /api/upload?folder=/Books  -> the book as the field "book" of a form; 201 when it is
--                                      stored, 409 when a file of that name is there, 507 when
--                                      the card is full, 400 for a name the reader refuses.
--                                      With &replace=1 it takes the place of a file of that name.
--
-- Koona Books calls three functions of the table this file returns: check, list and send.
-- Each answers a table: what it found or did, or { error = "<code>" } when it could not. The
-- app keeps the rest: which books go, converting them, their names on the reader, the queue,
-- and the records of what was sent.

local t = {}

-- Every request goes to ctx.base: "http://", the address the person typed, and the first port
-- of addon.json when it is not 80 ("http://192.168.1.30:8080"). That address on those ports is
-- the one place this add-on may reach.
local function get(ctx, path)
  return koona.http.request{ url = ctx.base .. path, timeout = 8 }
end

-- A request that got no answer has status 0 and the app's code in `error` ("unreachable",
-- "timeout", "file"...). Passed on as it is: the app has words for those codes.
local function no_answer(r)
  return { error = type(r.error) == "string" and r.error or "unreachable" }
end

-- The answer's body as JSON, or nil. Something that answers, but not in JSON, is not the
-- reader: json.decode raises on bad JSON, so it is called through pcall.
local function json(r)
  if r.status ~= 200 or type(r.body) ~= "string" then return nil end
  local ok, value = pcall(koona.json.decode, r.body)
  if ok and type(value) == "table" then return value end
  return nil
end

-- "Test connection" in the reader's form. `name` is required: the reader keeps it as its name
-- in Devices. `detail` is shown beside it.
function t.check(ctx)
  local r = get(ctx, "/api/info")
  if r.status == 0 then return no_answer(r) end
  local info = json(r)
  -- Something answers at this address (a router, a printer), but not as the reader does.
  if not info or type(info.firmware) ~= "string" then
    return { error = "not_a_reader" }
  end
  local model = type(info.model) == "string" and info.model or ""
  return {
    name = model ~= "" and ("Example Reader " .. model) or "Example Reader",
    detail = "Firmware " .. info.firmware,
  }
end

-- The files of one folder on the reader, without its folders. `folder` is the reader's folder
-- setting as the app checked it ("/Books", or "/" for the top). The app lists before a send,
-- to pick a name no other file has, and after it, to see that the book is there whole.
function t.list(ctx, folder)
  local r = get(ctx, "/api/files?folder=" .. koona.url.encode(folder))
  if r.status == 0 then return no_answer(r) end
  -- No such folder yet (nothing was sent there before): an empty list, not an error. The app
  -- lists before the first send too, and the reader makes the folder when a book arrives.
  if r.status == 404 then return { rows = {} } end
  local files = json(r)
  if not files then return { error = "refused" } end
  local rows = {}
  for _, f in ipairs(files) do
    if type(f) == "table" and f.folder ~= true
        and type(f.name) == "string" and type(f.size) == "number" then
      rows[#rows + 1] = { name = f.name, size = f.size }
    end
  end
  -- A list is never the answer itself: it goes inside it, as `rows`.
  return { rows = rows }
end

-- One book. `item.file` is a handle, not a path: koona.http.upload is the one thing that takes
-- it, and the script never sees the book's bytes. `item.name` is the file's name on the
-- reader, made by the app. `item.replace` is true only when the file of that name is Koona
-- Books' own earlier copy of this book: without it, a file of that name stays as it is.
function t.send(ctx, item)
  -- The folder: the setting with "role": "folder" in addon.json, already checked by the app.
  local folder = ctx.settings.folder or "/"
  local query = "?folder=" .. koona.url.encode(folder)
  if item.replace then query = query .. "&replace=1" end

  -- The app opens the file and streams it as one part of a form: the field "book", under the
  -- name item.name. The wait for it is the upload's own, not the script's seconds.
  local r = koona.http.upload{
    url = ctx.base .. "/api/upload" .. query,
    file = item.file,
    field = "book",
    filename = item.name,
  }
  if r.status == 200 or r.status == 201 then
    -- Where the book is now, from the reader's top.
    return { path = (folder == "/" and "" or folder) .. "/" .. item.name }
  end
  if r.status == 0 then return no_answer(r) end
  -- The reader's own answers, as codes the app has words for.
  if r.status == 409 then return { error = "exists" } end
  if r.status == 507 then return { error = "full" } end
  if r.status == 400 then return { error = "name" } end
  return { error = "refused" }
end

return t
