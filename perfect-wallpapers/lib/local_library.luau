local util = require("./util.luau")
local config = require("./config.luau")

local local_library = {}

local IMAGE_EXT = {
  jpg = true,
  jpeg = true,
  png = true,
  webp = true,
  bmp = true,
  gif = true, -- still treated as image for Noctalia static set; mpvpaper can also play gif as video
  avif = true,
  jxl = true,
}

local VIDEO_EXT = {
  mp4 = true,
  webm = true,
  mkv = true,
  mov = true,
  m4v = true,
  avi = true,
}

local function extensionOf(name)
  local ext = string.lower(tostring(name):match("%.([%w]+)$") or "")
  return ext
end

local function classify(name)
  local ext = extensionOf(name)
  if VIDEO_EXT[ext] then
    return "video", ext
  end
  if IMAGE_EXT[ext] then
    -- Animated gif can be used either way; keep under images for static apply.
    return "image", ext
  end
  return nil, ext
end

local function basename(path)
  return tostring(path):match("([^/]+)$") or path
end

local function dirnameLabel(path)
  local parent = tostring(path):match("(.+)/[^/]+$") or ""
  return basename(parent)
end

function local_library.directories()
  return config.localDirectories()
end

function local_library.scan(opts)
  opts = opts or {}
  local kind = opts.kind or "image"
  local query = string.lower(util.trim(opts.query or ""))
  local dirs = config.localDirectories()

  if #dirs == 0 then
    return nil, "no_local_dirs"
  end

  local items = {}
  local seen = {}

  for _, dir in ipairs(dirs) do
    local entries = noctalia.listDir(dir)
    if type(entries) == "table" then
      for _, name in ipairs(entries) do
        local mediaKind, ext = classify(name)
        if mediaKind == kind then
          local path = dir .. "/" .. name
          if not seen[path] then
            local hay = string.lower(name .. " " .. dir)
            if query == "" or hay:find(query, 1, true) then
              seen[path] = true
              table.insert(items, {
                kind = mediaKind,
                source = "local",
                id = path,
                path = path,
                name = name,
                tags = name,
                user = dirnameLabel(path),
                pageURL = "",
                previewURL = if mediaKind == "image" then path else "",
                downloadURL = path,
                width = 0,
                height = 0,
                resolution = name,
                ext = ext,
              })
            end
          end
        end
      end
    end
  end

  table.sort(items, function(a, b)
    return string.lower(a.name) < string.lower(b.name)
  end)

  return {
    items = items,
    totalHits = #items,
    directories = dirs,
  }
end

function local_library.pageSlice(allItems, page, perPage)
  local total = #allItems
  local pages = math.max(1, math.ceil(total / perPage))
  page = util.clamp(page, 1, pages)
  local startIndex = (page - 1) * perPage + 1
  local slice = {}
  for i = startIndex, math.min(total, startIndex + perPage - 1) do
    table.insert(slice, allItems[i])
  end
  return slice, pages, page
end

return local_library
