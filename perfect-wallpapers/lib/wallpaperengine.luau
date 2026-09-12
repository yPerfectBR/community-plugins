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
    if type(entries) == "table" then
      table.insert(valid, r)
    end
  end
  return valid
end

function wallpaperengine.invalidateCache()
  cachedItems = nil
  cachedRoots = nil
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

function wallpaperengine.loadAll()
  if cachedItems ~= nil then
    return cachedItems
  end

  local roots = wallpaperengine.candidateRoots()
  cachedRoots = roots
  local items = {}
  local seenIds = {}

  for _, root in ipairs(roots) do
    local entries = noctalia.listDir(root)
    if type(entries) == "table" then
      for _, entry in ipairs(entries) do
        local id = tostring(entry)
        if tonumber(id) and not seenIds[id] then
          local itemDir = root .. "/" .. id
          local projPath = itemDir .. "/project.json"
          local content = noctalia.readFile(projPath)
          if content then
            local decoded = noctalia.json.decode(content)
            if type(decoded) == "table" then
              seenIds[id] = true
              local previewFile = decoded.preview or "preview.jpg"
              local previewPath = itemDir .. "/" .. previewFile
              local t = decoded.type or "scene"
              local title = decoded.title or id
              local tags = formatTags(decoded.tags)

              table.insert(items, {
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
              })
            end
          end
        end
      end
    end
  end

  table.sort(items, function(a, b)
    return string.lower(a.title) < string.lower(b.title)
  end)

  cachedItems = items
  return items
end

function wallpaperengine.search(opts, cb)
  opts = opts or {}
  local query = string.lower(util.trim(opts.query or ""))
  local typeFilter = string.lower(opts.typeFilter or "all")
  local page = tonumber(opts.page) or 1
  local perPage = tonumber(opts.perPage) or 20

  local all = wallpaperengine.loadAll()
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

return wallpaperengine
