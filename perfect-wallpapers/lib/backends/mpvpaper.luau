local util = require("../util.luau")
local config = require("../config.luau")
local mutex = require("./mutex.luau")

local mpvpaper = {}

function mpvpaper.available()
  return noctalia.commandExists("mpvpaper")
end

local function mpvOpts()
  local parts = { "loop-file=inf", "panscan=1.0" }
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
  return table.concat(parts, ",")
end

function mpvpaper.stop()
  mutex.stopMpvpaper()
  mutex.enableNoctaliaWallpaper(true)
end

function mpvpaper.start(path, connector)
  local target = connector
  if type(target) ~= "string" or target == "" then
    target = "*"
  end

  mutex.stopForeign()
  mutex.enableNoctaliaWallpaper(false)

  local cmd = table.concat({
    "setsid -f mpvpaper",
    "-o",
    util.shellQuote(mpvOpts()),
    util.shellQuote(target),
    util.shellQuote(path),
  }, " ")

  return noctalia.runAsync(cmd)
end

return mpvpaper
