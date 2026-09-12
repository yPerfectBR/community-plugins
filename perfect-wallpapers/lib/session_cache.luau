local util = require("./util.luau")
local paths = require("./paths.luau")

local session_cache = {}

-- Within one login/session keep pages for up to 24h (Pixabay guidance).
-- Storage itself is under XDG_RUNTIME_DIR and is wiped on service start / reboot.
local TTL_MS = 24 * 60 * 60 * 1000
local memory = {}

local function nowMs()
  if noctalia.nowMs then
    return noctalia.nowMs()
  end
  return os.time() * 1000
end

function session_cache.hashKey(parts)
  local chunks = {}
  for _, part in ipairs(parts) do
    local t = type(part)
    if t == "nil" then
      table.insert(chunks, "")
    elseif t == "boolean" then
      table.insert(chunks, if part then "1" else "0")
    else
      table.insert(chunks, tostring(part))
    end
  end
  local raw = table.concat(chunks, "\0")
  local hash = 5381
  for i = 1, #raw do
    hash = (hash * 33 + string.byte(raw, i)) % 4294967296
  end
  return string.format("%08x", hash) .. string.format("%04x", #raw % 65536)
end

local function pagePath(provider, key)
  return paths.pageCacheDir(provider) .. "/" .. key .. ".json"
end

local function readEnvelope(path)
  local content = noctalia.readFile(path)
  if type(content) ~= "string" or content == "" then
    return nil
  end
  local decoded = noctalia.json.decode(content)
  if type(decoded) ~= "table" or type(decoded.at) ~= "number" or type(decoded.payload) ~= "table" then
    return nil
  end
  if nowMs() - decoded.at > TTL_MS then
    return nil
  end
  return decoded.payload
end

function session_cache.getPage(provider, key)
  local memKey = provider .. ":" .. key
  local mem = memory[memKey]
  if type(mem) == "table" and type(mem.at) == "number" and type(mem.payload) == "table" then
    if nowMs() - mem.at <= TTL_MS then
      return mem.payload
    end
    memory[memKey] = nil
  end

  local payload = readEnvelope(pagePath(provider, key))
  if payload ~= nil then
    memory[memKey] = { at = nowMs(), payload = payload }
  end
  return payload
end

function session_cache.setPage(provider, key, payload)
  if type(payload) ~= "table" then
    return
  end
  local at = nowMs()
  local memKey = provider .. ":" .. key
  memory[memKey] = { at = at, payload = payload }

  local dir = paths.pageCacheDir(provider)
  paths.ensure(dir, function()
    local body = noctalia.json.encode({
      at = at,
      payload = payload,
    })
    if type(body) == "string" and body ~= "" then
      noctalia.writeFile(pagePath(provider, key), body)
    end
  end)
end

function session_cache.clearMemory()
  memory = {}
end

function session_cache.wipeAll(done)
  session_cache.clearMemory()
  local pending = 2
  local function step()
    pending -= 1
    if pending <= 0 and done then
      done()
    end
  end
  paths.wipeDir(paths.sessionRoot(), step)
  paths.wipeDir(paths.legacyCacheDir(), step)
end

return session_cache
