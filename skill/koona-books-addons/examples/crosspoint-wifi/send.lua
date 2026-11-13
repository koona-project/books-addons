-- CrossPoint over Wi-Fi: sends books to an Xteink reader through the pages CrossPoint serves
-- while File Transfer is open on it (port 80, no password).
--
-- Written from CrossPoint's own description of those pages (docs/webserver-endpoints.md):
--   GET  /api/status                      -> { version, device, ... }
--   GET  /api/files?path=                 -> [ { name, size, isDirectory }, ... ]
--   POST /mkdir   (form: name, path)      -> 200, or 400 "Folder already exists"
--   POST /upload?path=&overwrite=1        -> 200, or 400 with the reason as text
--
-- A send target answers with a table: what it found or did, or `{ error = "<code>" }`. The
-- codes are worded by the app, or by this add-on's `error.<code>`; the reader's own text is
-- never shown as anyone's words. The folder books go into is the setting with the folder's
-- role in addon.json, here `ctx.settings.folder`.

local t = {}

local function get(ctx, path)
  return koona.http.request{ url = ctx.base .. path, timeout = 8 }
end

-- JSON from an answer, or nil: a page that is not JSON is not an error to stop for.
local function json(r)
  if r.status ~= 200 or type(r.body) ~= "string" then return nil end
  local ok, value = pcall(koona.json.decode, r.body)
  if ok and type(value) == "table" then return value end
  return nil
end

-- Why nothing came back: the host's own code ("unreachable", "timeout", ...).
local function trouble(r)
  return { error = type(r.error) == "string" and r.error or "unreachable" }
end

function t.check(ctx)
  local r = get(ctx, "/api/status")
  if r.status == 0 then return trouble(r) end
  local s = json(r)
  -- Something answers on port 80 (a router, a printer), but not as CrossPoint does.
  if not s or type(s.version) ~= "string" then return { error = "not_a_reader" } end
  local model = type(s.device) == "string" and s.device or ""
  return {
    name = model ~= "" and ("Xteink " .. model) or "Xteink",
    detail = "CrossPoint " .. s.version,
  }
end

function t.list(ctx, folder)
  local r = get(ctx, "/api/files?path=" .. koona.url.encode(folder))
  if r.status == 0 then return trouble(r) end
  local files = json(r)
  if not files then return { error = "refused" } end
  local out = {}
  for _, f in ipairs(files) do
    if type(f) == "table" and f.isDirectory ~= true
        and type(f.name) == "string" and type(f.size) == "number" then
      out[#out + 1] = { name = f.name, size = f.size }
    end
  end
  return { rows = out }
end

-- CrossPoint is asked for each folder of the path first: "already exists" is the usual
-- answer, and whatever else it says, the upload after it tells whether the book can land.
local function make_folders(ctx, folder)
  local at = "/"
  for name in folder:gmatch("[^/]+") do
    local r = koona.http.request{
      method = "POST", url = ctx.base .. "/mkdir", timeout = 8,
      headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
      body = "name=" .. koona.url.encode(name) .. "&path=" .. koona.url.encode(at),
    }
    if r.status == 0 then return r end
    at = (at == "/" and "" or at) .. "/" .. name
  end
  return nil
end

function t.send(ctx, item)
  local folder = ctx.settings.folder
  if type(folder) ~= "string" or folder == "" then folder = "/" end

  local gone = make_folders(ctx, folder)
  if gone then return trouble(gone) end

  local query = "?path=" .. koona.url.encode(folder)
  -- With `overwrite` CrossPoint writes `<name>.part` and swaps it in when it is whole.
  if item.replace then query = query .. "&overwrite=1" end
  local r = koona.http.upload{
    url = ctx.base .. "/upload" .. query,
    file = item.file, field = "file", filename = item.name,
  }
  if r.status == 200 then
    return { path = (folder == "/" and "" or folder) .. "/" .. item.name }
  end
  if r.status == 0 then return trouble(r) end

  local said = type(r.body) == "string" and r.body or ""
  if said:find("already exists", 1, true) then return { error = "exists" } end
  if said:find("disk may be full", 1, true) then return { error = "full" } end
  if said:find("Invalid file name", 1, true) then return { error = "name" } end
  return { error = "refused" }
end

return t
