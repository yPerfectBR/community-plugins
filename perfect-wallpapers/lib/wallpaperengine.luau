local util = require("./util.luau")
local config = require("./config.luau")

local wallpaperengine = {}

local WORKSHOP_PATHS = {
  "~/.local/share/Steam/steamapps/workshop/content/431960",
  "~/.steam/steam/steamapps/workshop/content/431960",
  "~/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/workshop/content/431960",
  "~/snap/steam/common/.local/share/Steam/steamapps/workshop/content/431960",
  "~/snap/steam/common/.local/share/steam/steamapps/workshop/content/431960",
}

local cachedItems = nil
local cachedRoots = nil
local loadInFlight = nil

-- Luau callbacks only get ~12ms CPU. Scan workshop in small batches,
-- yielding via runAsync between batches so we never trip the budget.
local BATCH_SIZE = 6

local function parseLibraryFolders(vdfContent)
  local paths = {}
  if type(vdfContent) ~= "string" or vdfContent == "" then
    return paths
  end
  for p in vdfContent:gmatch('"path"%s+"([^"]+)"') do
    local normalized = p:gsub("\\\\", "/")
    table.insert(paths, normalized .. "/steamapps/workshop/content/431960")
  end
  return paths
end

function wallpaperengine.candidateRoots()
  local roots = {}
  local seen = {}

  local function addRoot(r)
    if type(r) ~= "string" or r == "" then
      return
    end
    local exp = noctalia.expandPath(util.trim(r))
    -- Collapse common Steam symlink layouts to one physical root.
    exp = exp:gsub("/%.steam/steam/", "/.local/share/Steam/")
    exp = exp:gsub("/%.steam/root/", "/.local/share/Steam/")
    if not seen[exp] then
      seen[exp] = true
      table.insert(roots, exp)
    end
  end

  local customDir = config.wallpaperEngineDirectory()
  if customDir ~= "" then
    addRoot(customDir)
  end

  for _, p in ipairs(WORKSHOP_PATHS) do
    addRoot(p)
  end

  local vdfCandidates = {
    "~/.local/share/Steam/steamapps/libraryfolders.vdf",
    "~/.steam/steam/steamapps/libraryfolders.vdf",
    "~/.local/share/Steam/config/libraryfolders.vdf",
  }
  for _, vdf in ipairs(vdfCandidates) do
    local content = noctalia.readFile(noctalia.expandPath(vdf))
    if content then
      local parsed = parseLibraryFolders(content)
      for _, libRoot in ipairs(parsed) do
        addRoot(libRoot)
      end
    end
  end

  local valid = {}
  for _, r in ipairs(roots) do
    local entries = noctalia.listDir(r)
    if type(entries) == "table" and #entries > 0 then
      table.insert(valid, r)
    end
  end
  return valid
end

function wallpaperengine.invalidateCache()
  cachedItems = nil
  cachedRoots = nil
  loadInFlight = nil
end

local function formatTags(rawTags)
  if type(rawTags) == "table" then
    return table.concat(rawTags, ", ")
  end
  if type(rawTags) == "string" then
    return rawTags
  end
  return ""
end

local function typeLabel(t)
  if type(t) ~= "string" or t == "" then
    return "Scene"
  end
  local lower = string.lower(t)
  if lower == "scene" then
    return "Scene"
  elseif lower == "video" then
    return "Video"
  elseif lower == "web" then
    return "Web"
  elseif lower == "application" then
    return "App"
  end
  return string.upper(string.sub(t, 1, 1)) .. string.sub(t, 2)
end

local function collectIds(roots)
  local jobs = {}
  local seenIds = {}
  for _, root in ipairs(roots) do
    local entries = noctalia.listDir(root)
    if type(entries) == "table" then
      for _, entry in ipairs(entries) do
        local id = tostring(entry)
        if tonumber(id) and not seenIds[id] then
          seenIds[id] = true
          table.insert(jobs, { root = root, id = id })
        end
      end
    end
  end
  return jobs
end

local function parseProject(root, id)
  local itemDir = root .. "/" .. id
  local projPath = itemDir .. "/project.json"
  local content = noctalia.readFile(projPath)
  if not content then
    return nil
  end
  local decoded = noctalia.json.decode(content)
  if type(decoded) ~= "table" then
    return nil
  end
  local previewFile = decoded.preview or "preview.jpg"
  local previewPath = itemDir .. "/" .. previewFile
  local t = decoded.type or "scene"
  local title = decoded.title or id
  local tags = formatTags(decoded.tags)

  return {
    id = id,
    title = title,
    name = title,
    type = t,
    kind = "wallpaperengine",
    source = "wallpaperengine",
    path = itemDir,
    previewPath = previewPath,
    previewURL = previewPath,
    downloadURL = itemDir,
    file = decoded.file or "",
    tags = tags,
    user = "Wallpaper Engine",
    pageURL = "https://steamcommunity.com/sharedfiles/filedetails/?id=" .. id,
    resolution = typeLabel(t),
    description = decoded.description or "",
  }
end

--- Async scan. Yields between batches so Luau CPU budget is never exceeded.
function wallpaperengine.loadAllAsync(cb)
  if type(cb) ~= "function" then
    return
  end

  if cachedItems ~= nil then
    cb(cachedItems, nil)
    return
  end

  if loadInFlight ~= nil then
    table.insert(loadInFlight, cb)
    return
  end

  loadInFlight = { cb }

  local function finish(items, err)
    local waiters = loadInFlight or {}
    loadInFlight = nil
    if items ~= nil then
      cachedItems = items
    end
    for _, waiter in ipairs(waiters) do
      waiter(items, err)
    end
  end

  local ok, rootsOrErr = pcall(wallpaperengine.candidateRoots)
  if not ok then
    finish(nil, "scan_failed")
    return
  end
  local roots = rootsOrErr
  cachedRoots = roots

  local jobs = collectIds(roots)
  if #jobs == 0 then
    finish({}, nil)
    return
  end

  local items = {}
  local index = 1

  local function step()
    local n = 0
    while index <= #jobs and n < BATCH_SIZE do
      local job = jobs[index]
      index += 1
      n += 1
      local item = parseProject(job.root, job.id)
      if item then
        table.insert(items, item)
      end
    end

    if index <= #jobs then
      -- Fresh CPU budget on the next callback tick.
      noctalia.runAsync("true", function()
        step()
      end)
      return
    end

    table.sort(items, function(a, b)
      return string.lower(a.title) < string.lower(b.title)
    end)
    finish(items, nil)
  end

  step()
end

function wallpaperengine.loadAll()
  if cachedItems ~= nil then
    return cachedItems
  end
  -- Sync fallback for callers that cannot wait — keep it tiny (cache miss
  -- should go through loadAllAsync). Returns empty rather than blocking.
  return {}
end

function wallpaperengine.search(opts, cb)
  opts = opts or {}
  local query = string.lower(util.trim(opts.query or ""))
  local typeFilter = string.lower(opts.typeFilter or "all")
  local page = tonumber(opts.page) or 1
  local perPage = tonumber(opts.perPage) or 20

  local function respond(all, err)
    if all == nil then
      if cb then
        cb(nil, err or "scan_failed")
      end
      return nil
    end

    local filtered = {}
    for _, item in ipairs(all) do
      local matchType = true
      if typeFilter ~= "all" and typeFilter ~= "" then
        matchType = (string.lower(item.type or "") == typeFilter)
      end

      local matchQuery = true
      if query ~= "" then
        local hay = string.lower(item.title .. " " .. item.id .. " " .. item.tags)
        matchQuery = hay:find(query, 1, true) ~= nil
      end

      if matchType and matchQuery then
        table.insert(filtered, item)
      end
    end

    local totalHits = #filtered
    local totalPages = math.max(1, math.ceil(totalHits / perPage))
    if page > totalPages then
      page = totalPages
    end
    if page < 1 then
      page = 1
    end

    local startIndex = (page - 1) * perPage + 1
    local endIndex = math.min(startIndex + perPage - 1, totalHits)
    local slice = {}
    for i = startIndex, endIndex do
      table.insert(slice, filtered[i])
    end

    local payload = {
      items = slice,
      totalHits = totalHits,
      totalPages = totalPages,
      page = page,
      totalInstalled = #all,
    }

    if cb then
      cb(payload, nil)
    end
    return payload
  end

  if cachedItems ~= nil then
    return respond(cachedItems, nil)
  end

  if type(cb) ~= "function" then
    return respond({}, nil)
  end

  wallpaperengine.loadAllAsync(function(all, err)
    respond(all, err)
  end)
  return nil
end

return wallpaperengine
