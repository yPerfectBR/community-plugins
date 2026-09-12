local paths = require("./paths.luau")

local thumbs = {}

local MAX_CONCURRENT = 3
local pathsById = {}
local pending = {}
local queue = {}
local active = 0
local onReady = nil
local sourceTag = "pixabay"
local dirty = false
local completedSinceRender = 0
local generation = 1

function thumbs.setOnReady(cb)
  onReady = cb
end

function thumbs.get(id)
  return pathsById[id]
end

function thumbs.clear()
  generation += 1
  pathsById = {}
  pending = {}
  queue = {}
  active = 0
  dirty = false
  completedSinceRender = 0
end

function thumbs.wipe()
  thumbs.clear()
  paths.wipeDir(paths.sessionRoot() .. "/thumbs")
end

function thumbs.setSource(source)
  sourceTag = source or "pixabay"
  thumbs.clear()
end

local function cachePath(id)
  local safe = tostring(id):gsub("[^%w%._%-]+", "_")
  if #safe > 64 then
    safe = string.sub(safe, -64)
  end
  return paths.thumbDir(sourceTag) .. "/" .. safe .. ".jpg"
end

local function flushReady(force)
  if not dirty or onReady == nil then
    return
  end
  if force or active == 0 or completedSinceRender >= 4 then
    dirty = false
    completedSinceRender = 0
    onReady()
  end
end

local pump

local function downloadOne(item)
  local id = item.id
  local url = item.previewURL
  if type(url) ~= "string" or url == "" then
    return
  end
  if pathsById[id] ~= nil or pending[id] then
    return
  end

  if (item.source == "local" and item.kind == "image") or item.source == "wallpaperengine" then
    local p = item.previewPath or item.path or url
    if p and p ~= "" then
      pathsById[id] = p
      dirty = true
      completedSinceRender += 1
      flushReady(false)
      return
    end
  end

  pending[id] = true
  active += 1
  local dest = cachePath(id)
  local currentGen = generation
  local started = noctalia.download(url, dest, function(ok)
    if currentGen ~= generation then
      return
    end
    active -= 1
    pending[id] = nil
    if ok then
      pathsById[id] = dest
      dirty = true
      completedSinceRender += 1
      flushReady(active == 0)
    end
    pump()
  end)
  if not started then
    if currentGen == generation then
      active -= 1
      pending[id] = nil
      table.insert(queue, 1, item)
    end
  end
end

pump = function()
  while active < MAX_CONCURRENT and #queue > 0 do
    local item = table.remove(queue, 1)
    if pathsById[item.id] == nil and not pending[item.id] then
      downloadOne(item)
    end
  end
  if active == 0 then
    flushReady(true)
  end
end

function thumbs.enqueue(items)
  if sourceTag == "local" or sourceTag == "wallpaperengine" then
    for _, item in ipairs(items) do
      if sourceTag == "wallpaperengine" or item.kind == "image" then
        downloadOne(item)
      end
    end
    flushReady(true)
    return
  end

  paths.ensure(paths.thumbDir(sourceTag), function()
    for _, item in ipairs(items) do
      if pathsById[item.id] == nil and not pending[item.id] then
        table.insert(queue, item)
      end
    end
    pump()
  end)
end

return thumbs
