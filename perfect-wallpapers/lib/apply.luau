local util = require("./util.luau")
local paths = require("./paths.luau")
local config = require("./config.luau")
local mutex = require("./backends/mutex.luau")
local mpvpaper = require("./backends/mpvpaper.luau")
local we_backend = require("./backends/wallpaperengine.luau")

local apply = {}

local function updateStatus(mode, path, meta, connector)
  local now = noctalia.nowMs and noctalia.nowMs() or os.time() * 1000
  local current = noctalia.state.get("status")
  local outputs = (type(current) == "table" and type(current.outputs) == "table") and current.outputs or {}

  local conn = connector or "*"
  if conn == "*" or conn == "all" then
    local allOuts = (type(noctalia.outputs) == "function" and noctalia.outputs()) or {}
    for _, out in ipairs(allOuts) do
      local name = (type(out) == "table" and out.name) or tostring(out)
      if name ~= "" then
        outputs[name] = {
          mode = mode,
          path = path,
          source = meta and meta.source or "local",
          id = meta and meta.id or "",
          title = meta and (meta.title or meta.name) or "",
          user = meta and meta.user or "",
          at = now,
        }
      end
    end
  else
    outputs[conn] = {
      mode = mode,
      path = path,
      source = meta and meta.source or "local",
      id = meta and meta.id or "",
      title = meta and (meta.title or meta.name) or "",
      user = meta and meta.user or "",
      at = now,
    }
  end

  local status = {
    mode = mode,
    path = path,
    source = meta and meta.source or "local",
    id = meta and meta.id or "",
    title = meta and (meta.title or meta.name) or "",
    user = meta and meta.user or "",
    pageURL = meta and meta.pageURL or "",
    connector = conn,
    at = now,
    outputs = outputs,
  }

  noctalia.state.set("status", status)

  -- Se for Daily Wallpaper, publica metadados ricos para o Desktop Widget
  if meta and meta.source == "daily" then
    noctalia.state.set("daily_info", {
      title = meta.title or "",
      copyright = meta.copyright or meta.user or "",
      explanation = meta.explanation or "",
      date = meta.date or "",
      subsource = meta.subsource or "bing",
      url = meta.pageURL or "",
      imagePath = path,
      connector = conn,
      at = now,
    })
  end

  return status
end

function apply.currentStatus()
  return noctalia.state.get("status")
end

function apply.setStatic(path, meta, connector)
  local conn = connector or "*"
  if conn == "*" or conn == "all" then
    mutex.stopForeign()
    mutex.enableNoctaliaWallpaper(true)
    noctalia.setWallpaper(path)
  else
    mutex.stopDynamicBackends(conn)
    mutex.enableNoctaliaWallpaper(true, conn)
    noctalia.setWallpaper(conn, path)
  end

  return updateStatus("image", path, meta, conn)
end

function apply.setVideo(path, meta, connector)
  if not mpvpaper.available() then
    return nil, "mpvpaper_missing"
  end
  local conn = connector or "*"
  local ok = mpvpaper.start(path, conn)
  if not ok then
    return nil, "mpvpaper_failed"
  end
  local status = updateStatus("video", path, meta, conn)
  return status
end

function apply.setWallpaperEngine(item, connector)
  if not we_backend.available() then
    return nil, "wallpaperengine_missing"
  end
  local conn = connector or "*"
  local idOrPath = item.id or item.path
  local ok = we_backend.start(idOrPath, { previewPath = item.previewPath }, conn)
  if not ok then
    return nil, "wallpaperengine_failed"
  end
  local status = updateStatus("wallpaperengine", item.previewPath or item.path or "", {
    source = "wallpaperengine",
    id = item.id or "",
    title = item.title or item.name or item.id or "",
    user = item.user or "Wallpaper Engine",
    pageURL = item.pageURL or "",
  }, conn)
  return status
end

function apply.stop(connector)
  local conn = connector or "*"
  if conn == "*" or conn == "all" then
    mpvpaper.stop()
    we_backend.stop()
    mutex.stopForeign()
    mutex.enableNoctaliaWallpaper(true)
  else
    mpvpaper.stop(conn)
    we_backend.stop(conn)
    mutex.enableNoctaliaWallpaper(true, conn)
  end

  return updateStatus("none", "", { source = "" }, conn)
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

local function maybeCopyToLocalDir(sourcePath, filename)
  if not config.copyToWallpaperDir() then
    return
  end
  local localDirs = config.localDirectories()
  local targetDir = #localDirs > 0 and localDirs[1] or (paths.home() .. "/Pictures/Wallpapers")
  paths.ensure(targetDir, function(res)
    if res and res.exitCode == 0 then
      local destFile = targetDir .. "/" .. filename
      noctalia.runAsync("cp -n " .. util.shellQuote(sourcePath) .. " " .. util.shellQuote(destFile) .. " 2>/dev/null; true")
    end
  end)
end

function apply.downloadAndApply(item, connectorOrCb, maybeCb)
  local connector = "*"
  local cb

  if type(connectorOrCb) == "function" then
    cb = connectorOrCb
  else
    connector = connectorOrCb or "*"
    cb = maybeCb
  end

  if type(cb) ~= "function" then
    cb = function() end
  end

  if type(item) ~= "table" then
    cb(nil, "missing_url")
    return
  end

  local source = item.source or "pixabay"
  local meta = {
    source = source,
    id = item.id,
    title = item.title or item.name,
    user = item.user,
    pageURL = item.pageURL,
    copyright = item.copyright,
    explanation = item.explanation,
    date = item.date,
    subsource = item.subsource,
  }

  if source == "wallpaperengine" then
    local status, err = apply.setWallpaperEngine(item, connector)
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
      local status, err = apply.setVideo(path, meta, connector)
      cb(status, err)
    else
      cb(apply.setStatic(path, meta, connector), nil)
    end
    return
  end

  if type(item.downloadURL) ~= "string" or item.downloadURL == "" then
    cb(nil, "missing_url")
    return
  end

  -- Para "daily", salvamos em cache rápido ou pasta de downloads dedicada
  local destDir = (source == "daily") and (paths.cacheDir() .. "/daily") or paths.downloadDir(source)
  local filename = `{filePrefix(item)}-{item.id}{fileExt(item)}`
  local dest = `{destDir}/{filename}`

  paths.ensure(destDir, function(mkdirRes)
    if mkdirRes ~= nil and mkdirRes.exitCode ~= 0 then
      cb(nil, "mkdir_failed")
      return
    end

    -- Se o arquivo já existir no cache/disco, aplica imediatamente sem novo download
    if noctalia.fileExists(dest) then
      maybeCopyToLocalDir(dest, filename)
      if item.kind == "video" then
        local status, err = apply.setVideo(dest, meta, connector)
        cb(status, err)
      else
        local status = apply.setStatic(dest, meta, connector)
        cb(status, nil)
      end
      return
    end

    local started = noctalia.download(item.downloadURL, dest, function(ok)
      if not ok then
        cb(nil, "download_failed")
        return
      end

      maybeCopyToLocalDir(dest, filename)

      if item.kind == "video" then
        local status, err = apply.setVideo(dest, meta, connector)
        cb(status, err)
      else
        local status = apply.setStatic(dest, meta, connector)
        cb(status, nil)
      end
    end)

    if not started then
      cb(nil, "download_failed")
    end
  end)
end

return apply
