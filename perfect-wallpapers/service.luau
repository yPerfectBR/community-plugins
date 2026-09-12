--!nonstrict
local apply = require("./lib/apply.luau")
local mpvpaper = require("./lib/backends/mpvpaper.luau")
local we_backend = require("./lib/backends/wallpaperengine.luau")
local config = require("./lib/config.luau")
local session_cache = require("./lib/session_cache.luau")

noctalia.setUpdateInterval(5000)

local function publishMeta()
  noctalia.state.set("meta", {
    mpvpaper = mpvpaper.available(),
    wallpaperEngine = we_backend.available(),
    hasPixabayKey = config.hasPixabayKey(),
    hasWallhavenKey = config.hasWallhavenKey(),
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

function update()
  publishMeta()
end

function onIpc(event, payload)
  if event == "status" then
    local status = current()
    noctalia.notify("Perfect Wallpapers", status.mode or "none")
  elseif event == "stop" then
    publishStatus(apply.stop())
    noctalia.notify("Perfect Wallpapers", "Stopped")
  elseif event == "clear-cache" then
    session_cache.wipeAll(function()
      noctalia.notify("Perfect Wallpapers", "Cache cleared")
    end)
  elseif event == "open" or event == "toggle" then
    noctalia.togglePanel("perfect/perfect-wallpapers:hub")
  elseif event == "apply-image" and type(payload) == "string" and payload ~= "" then
    publishStatus(apply.setStatic(noctalia.expandPath(payload), { source = "cli" }))
    noctalia.notify("Perfect Wallpapers", "Image applied")
  elseif event == "apply-video" and type(payload) == "string" and payload ~= "" then
    local status, err = apply.setVideo(noctalia.expandPath(payload), { source = "cli" }, "*")
    if status == nil then
      noctalia.notifyError("Perfect Wallpapers", err or "failed")
    else
      publishStatus(status)
      noctalia.notify("Perfect Wallpapers", "Video applied")
    end
  elseif (event == "apply-we" or event == "apply-wallpaperengine") and type(payload) == "string" and payload ~= "" then
    local status, err = apply.setWallpaperEngine({ id = payload }, "*")
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
    publishStatus(apply.stop())
  elseif cmd.action == "clear-cache" then
    session_cache.wipeAll()
  elseif cmd.action == "apply-image" and type(cmd.path) == "string" then
    publishStatus(apply.setStatic(cmd.path, cmd.meta))
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
