--!nonstrict
local apply = require("./lib/apply.luau")
local mpvpaper = require("./lib/backends/mpvpaper.luau")
local we_backend = require("./lib/backends/wallpaperengine.luau")
local config = require("./lib/config.luau")
local daily = require("./lib/daily.luau")
local session_cache = require("./lib/session_cache.luau")

noctalia.setUpdateInterval(5000)

local lastDailyCheck = 0
local lastDailyAppliedDate = ""
local isRotatingDaily = false

local function publishMeta()
  noctalia.state.set("meta", {
    mpvpaper = mpvpaper.available(),
    wallpaperEngine = we_backend.available(),
    hasPixabayKey = config.hasPixabayKey(),
    hasWallhavenKey = config.hasWallhavenKey(),
    outputs = (type(noctalia.outputs) == "function" and noctalia.outputs()) or {},
  })
end

local function publishStatus(status)
  noctalia.state.set("status", status)
end

local function current()
  local status = noctalia.state.get("status")
  if type(status) ~= "table" then
    status = { mode = "none" }
    publishStatus(status)
  end
  return status
end

-- Wipe session/page/preview cache on every service start so leftovers do not
-- survive a reboot (or a session where the hub is never opened again).
session_cache.wipeAll()

local function checkDailyRotation()
  if not config.dailyAutoRotate() or isRotatingDaily then
    return
  end

  local now = os.time()
  -- Check at most once every 10 minutes
  if (now - lastDailyCheck) < 600 then
    return
  end
  lastDailyCheck = now

  local subsource = config.dailySubsource()
  local locale = config.dailyLocale()

  isRotatingDaily = true
  daily.today(subsource, locale, function(item, err)
    isRotatingDaily = false
    if item == nil or type(item.downloadURL) ~= "string" then
      return
    end

    local itemDate = item.date or os.date("%Y-%m-%d")
    if itemDate == lastDailyAppliedDate then
      return
    end

    lastDailyAppliedDate = itemDate
    apply.downloadAndApply(item, "*", function(nextStatus, applyErr)
      if nextStatus ~= nil then
        publishStatus(nextStatus)
        noctalia.notify("Perfect Wallpapers", "Daily Wallpaper: " .. (item.title or itemDate))
      end
    end)
  end)
end

function update()
  publishMeta()
  checkDailyRotation()
end

local function parsePayloadWithConnector(payload)
  if type(payload) ~= "string" or payload == "" then
    return "", "*"
  end
  local first, second = string.match(payload, "^(%S+)%s+(%S+)$")
  if first and second then
    return first, second
  end
  return payload, "*"
end

function onIpc(event, payload)
  if event == "status" then
    local status = current()
    noctalia.notify("Perfect Wallpapers", status.mode or "none")
  elseif event == "stop" then
    local conn = (type(payload) == "string" and payload ~= "") and payload or "*"
    publishStatus(apply.stop(conn))
    noctalia.notify("Perfect Wallpapers", "Stopped")
  elseif event == "clear-cache" then
    session_cache.wipeAll(function()
      daily.clearCache()
      noctalia.notify("Perfect Wallpapers", "Cache cleared")
    end)
  elseif event == "open" or event == "toggle" then
    noctalia.togglePanel("perfect/perfect-wallpapers:hub")
  elseif event == "apply-daily" or event == "rotate-daily" then
    local conn = (type(payload) == "string" and payload ~= "") and payload or "*"
    daily.today(config.dailySubsource(), config.dailyLocale(), function(item, err)
      if item == nil then
        noctalia.notifyError("Perfect Wallpapers", "Failed to fetch Daily Wallpaper")
        return
      end
      apply.downloadAndApply(item, conn, function(nextStatus, applyErr)
        if nextStatus ~= nil then
          publishStatus(nextStatus)
          noctalia.notify("Perfect Wallpapers", "Daily: " .. (item.title or "Applied"))
        else
          noctalia.notifyError("Perfect Wallpapers", applyErr or "Apply failed")
        end
      end)
    end)
  elseif event == "apply-image" and type(payload) == "string" and payload ~= "" then
    local path, conn = parsePayloadWithConnector(payload)
    publishStatus(apply.setStatic(noctalia.expandPath(path), { source = "cli" }, conn))
    noctalia.notify("Perfect Wallpapers", "Image applied")
  elseif event == "apply-video" and type(payload) == "string" and payload ~= "" then
    local path, conn = parsePayloadWithConnector(payload)
    local status, err = apply.setVideo(noctalia.expandPath(path), { source = "cli" }, conn)
    if status == nil then
      noctalia.notifyError("Perfect Wallpapers", err or "failed")
    else
      publishStatus(status)
      noctalia.notify("Perfect Wallpapers", "Video applied")
    end
  elseif (event == "apply-we" or event == "apply-wallpaperengine") and type(payload) == "string" and payload ~= "" then
    local id, conn = parsePayloadWithConnector(payload)
    local status, err = apply.setWallpaperEngine({ id = id }, conn)
    if status == nil then
      noctalia.notifyError("Perfect Wallpapers", err or "failed")
    else
      publishStatus(status)
      noctalia.notify("Perfect Wallpapers", "Wallpaper Engine applied")
    end
  end
end

noctalia.state.watch("command", function(cmd)
  if type(cmd) ~= "table" or type(cmd.action) ~= "string" then
    return
  end
  if cmd.action == "stop" then
    publishStatus(apply.stop(cmd.connector or "*"))
  elseif cmd.action == "clear-cache" then
    session_cache.wipeAll()
    daily.clearCache()
  elseif cmd.action == "apply-image" and type(cmd.path) == "string" then
    publishStatus(apply.setStatic(cmd.path, cmd.meta, cmd.connector or "*"))
  elseif cmd.action == "apply-video" and type(cmd.path) == "string" then
    local status = apply.setVideo(cmd.path, cmd.meta, cmd.connector or "*")
    if status ~= nil then
      publishStatus(status)
    end
  elseif (cmd.action == "apply-we" or cmd.action == "apply-wallpaperengine") and type(cmd.id) == "string" then
    local status = apply.setWallpaperEngine({ id = cmd.id, previewPath = cmd.previewPath }, cmd.connector or "*")
    if status ~= nil then
      publishStatus(status)
    end
  elseif cmd.action == "apply-daily" then
    daily.today(config.dailySubsource(), config.dailyLocale(), function(item)
      if item ~= nil then
        apply.downloadAndApply(item, cmd.connector or "*", function(nextStatus)
          if nextStatus ~= nil then
            publishStatus(nextStatus)
          end
        end)
      end
    end)
  end
  noctalia.state.set("command", { action = "ack" })
end)

function onExit(_signal)
  apply.stop()
end

function onStop()
  apply.stop()
end

publishMeta()
current()
