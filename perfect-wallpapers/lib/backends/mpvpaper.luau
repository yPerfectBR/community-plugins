local util = require("../util.luau")
local config = require("../config.luau")
local mutex = require("./mutex.luau")

local mpvpaper = {}

function mpvpaper.available()
  return noctalia.commandExists("mpvpaper")
end

local function mpvOpts()
  local scale = config.videoScale()
  local parts = { "loop-file=inf", "stop-screensaver=no" }

  if scale == "fit" then
    table.insert(parts, "panscan=0.0")
  elseif scale == "stretch" then
    table.insert(parts, "keepaspect=no")
  else
    table.insert(parts, "panscan=1.0")
  end

  if config.muteVideo() then
    table.insert(parts, "mute=yes")
  end
  if config.hardwareDecode() then
    table.insert(parts, "hwdec=auto")
  end
  local fps = config.videoFps()
  if fps > 0 then
    table.insert(parts, "vf=fps=" .. tostring(fps))
  end
  return table.concat(parts, " ")
end

local function stopShell(connector)
  local mpvPattern
  local wePattern
  if connector and connector ~= "*" and connector ~= "all" then
    mpvPattern = "mpvpaper.*" .. connector
    wePattern = "linux-wallpaperengine.*" .. connector
  else
    mpvPattern = "(^|/)mpvpaper($| )"
    wePattern = "(^|/)linux-wallpaperengine($| )"
  end

  local parts = {
    "pkill -TERM -f " .. util.shellQuote(mpvPattern) .. " 2>/dev/null",
    "pkill -TERM -f " .. util.shellQuote(wePattern) .. " 2>/dev/null",
    "systemctl --user stop linux-wallpaperengine 2>/dev/null",
    "sleep 0.2",
    "pkill -9 -f " .. util.shellQuote(mpvPattern) .. " 2>/dev/null",
    "pkill -9 -f " .. util.shellQuote(wePattern) .. " 2>/dev/null",
  }

  if config.stopForeignBackends() and (not connector or connector == "*" or connector == "all") then
    table.insert(parts, "pkill -TERM -f " .. util.shellQuote("(^|/)swww-daemon($| )") .. " 2>/dev/null")
    table.insert(parts, "pkill -TERM -f " .. util.shellQuote("(^|/)awww-daemon($| )") .. " 2>/dev/null")
    table.insert(parts, "sleep 0.05")
    table.insert(parts, "pkill -9 -f " .. util.shellQuote("(^|/)swww-daemon($| )") .. " 2>/dev/null")
    table.insert(parts, "pkill -9 -f " .. util.shellQuote("(^|/)awww-daemon($| )") .. " 2>/dev/null")
  end

  table.insert(parts, "true")
  return table.concat(parts, "; ")
end

function mpvpaper.stop(connector)
  mutex.stopMpvpaper(connector)
  mutex.enableNoctaliaWallpaper(true, connector)
end

function mpvpaper.start(path, connector)
  local target = connector
  if type(target) ~= "string" or target == "" then
    target = "*"
  end

  -- Disable Noctalia's static layer so mpvpaper owns the background.
  mutex.enableNoctaliaWallpaper(false, target)

  -- CRITICAL: stop + start must be one shell chain. A separate async pkill
  -- (with sleep + SIGKILL) was racing and killing the freshly spawned mpvpaper,
  -- leaving a black screen with wallpaper managed by "external source".
  local startCmd = table.concat({
    "setsid -f mpvpaper",
    "-o",
    util.shellQuote(mpvOpts()),
    util.shellQuote(target),
    util.shellQuote(path),
  }, " ")

  return noctalia.runAsync(stopShell(target) .. "; " .. startCmd)
end

return mpvpaper
