local util = require("./util.luau")
local paths = require("./paths.luau")
local mutex = require("./backends/mutex.luau")
local mpvpaper = require("./backends/mpvpaper.luau")
local we_backend = require("./backends/wallpaperengine.luau")

local apply = {}

local function publish(status)
  noctalia.state.set("status", status)
end

function apply.currentStatus()
  return noctalia.state.get("status")
end

function apply.setStatic(path, meta)
  mutex.stopForeign()
  mutex.enableNoctaliaWallpaper(true)
  noctalia.setWallpaper(path)
  local status = {
    mode = "image",
    path = path,
    source = meta and meta.source or "local",
    id = meta and meta.id or "",
    user = meta and meta.user or "",
    pageURL = meta and meta.pageURL or "",
    at = noctalia.nowMs and noctalia.nowMs() or os.time() * 1000,
  }
  publish(status)
  return status
end

function apply.setVideo(path, meta, connector)
  if not mpvpaper.available() then
    return nil, "mpvpaper_missing"
  end
  local ok = mpvpaper.start(path, connector)
  if not ok then
    return nil, "mpvpaper_failed"
  end
  local status = {
    mode = "video",
    path = path,
    source = meta and meta.source or "local",
    id = meta and meta.id or "",
    user = meta and meta.user or "",
    pageURL = meta and meta.pageURL or "",
    connector = connector or "*",
    at = noctalia.nowMs and noctalia.nowMs() or os.time() * 1000,
  }
  publish(status)
  return status
end

function apply.setWallpaperEngine(item, connector)
  if not we_backend.available() then
    return nil, "wallpaperengine_missing"
  end
  local idOrPath = item.id or item.path
  local ok = we_backend.start(idOrPath, { previewPath = item.previewPath }, connector)
  if not ok then
    return nil, "wallpaperengine_failed"
  end
  local status = {
    mode = "wallpaperengine",
    path = item.previewPath or item.path or "",
    source = "wallpaperengine",
    id = item.id or "",
    name = item.title or item.name or item.id or "",
    user = item.user or "Wallpaper Engine",
    pageURL = item.pageURL or "",
    connector = connector or "*",
    at = noctalia.nowMs and noctalia.nowMs() or os.time() * 1000,
  }
  publish(status)
  return status
end

function apply.stop()
  mpvpaper.stop()
  we_backend.stop()
  mutex.enableNoctaliaWallpaper(true)
  local status = {
    mode = "none",
    path = "",
    source = "",
    id = "",
    user = "",
    pageURL = "",
    at = noctalia.nowMs and noctalia.nowMs() or os.time() * 1000,
  }
  publish(status)
  return status
end

local function filePrefix(item)
  local source = item.source or "local"
  if item.kind == "video" then
    return source .. "-video"
  end
  return source
end

local function fileExt(item)
  if item.kind == "video" then
    return util.fileExtFromUrl(item.downloadURL, ".mp4")
  end
  if item.fileType == "image/png" then
    return ".png"
  end
  return util.fileExtFromUrl(item.downloadURL, ".jpg")
end

function apply.downloadAndApply(item, cb)
  if type(item) ~= "table" then
    cb(nil, "missing_url")
    return
  end

  local source = item.source or "pixabay"
  local meta = {
    source = source,
    id = item.id,
    user = item.user,
    pageURL = item.pageURL,
  }

  if source == "wallpaperengine" then
    local status, err = apply.setWallpaperEngine(item, "*")
    cb(status, err)
    return
  end

  if source == "local" then
    local path = item.path or item.downloadURL
    if type(path) ~= "string" or path == "" then
      cb(nil, "missing_url")
      return
    end
    if item.kind == "video" then
      local status, err = apply.setVideo(path, meta, "*")
      cb(status, err)
    else
      cb(apply.setStatic(path, meta), nil)
    end
    return
  end

  if type(item.downloadURL) ~= "string" or item.downloadURL == "" then
    cb(nil, "missing_url")
    return
  end

  local destDir = paths.downloadDir(source)
  local dest = `{destDir}/{filePrefix(item)}-{item.id}{fileExt(item)}`

  paths.ensure(destDir, function(mkdirRes)
    if mkdirRes ~= nil and mkdirRes.exitCode ~= 0 then
      cb(nil, "mkdir_failed")
      return
    end

    local started = noctalia.download(item.downloadURL, dest, function(ok)
      if not ok then
        cb(nil, "download_failed")
        return
      end

      if item.kind == "video" then
        local status, err = apply.setVideo(dest, meta, "*")
        cb(status, err)
      else
        local status = apply.setStatic(dest, meta)
        cb(status, nil)
      end
    end)

    if not started then
      cb(nil, "download_failed")
    end
  end)
end

return apply
