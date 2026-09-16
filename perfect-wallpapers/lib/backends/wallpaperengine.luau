local util = require("../util.luau")
local config = require("../config.luau")
local mutex = require("./mutex.luau")

local wallpaperengine = {}

function wallpaperengine.available()
  return noctalia.commandExists("linux-wallpaperengine")
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

function wallpaperengine.stop(connector)
  mutex.stopWallpaperEngine(connector)
  mutex.enableNoctaliaWallpaper(true, connector)
end

function wallpaperengine.start(idOrPath, opts, connector)
  opts = opts or {}
  local target = connector
  if type(target) ~= "string" or target == "" then
    target = "*"
  end

  -- Sync palette from static preview while Noctalia wallpaper is still enabled.
  if opts.previewPath and noctalia.fileExists(opts.previewPath) then
    if target == "*" or target == "all" then
      noctalia.setWallpaper(opts.previewPath)
    else
      noctalia.setWallpaper(target, opts.previewPath)
    end
  end

  mutex.enableNoctaliaWallpaper(false, target)

  local args = { "setsid -f linux-wallpaperengine" }

  if config.muteVideo() or opts.silent then
    table.insert(args, "--silent")
  end

  local fps = config.videoFps()
  if fps > 0 then
    table.insert(args, "--fps " .. tostring(fps))
  end

  if target == "*" then
    local outputs = (type(noctalia.outputs) == "function" and noctalia.outputs()) or {}
    if #outputs > 0 then
      for _, out in ipairs(outputs) do
        local outName = (type(out) == "table" and out.name) or tostring(out)
        if outName ~= "" then
          table.insert(args, "--screen-root " .. util.shellQuote(outName))
        end
      end
      table.insert(args, util.shellQuote(idOrPath))
    else
      table.insert(args, util.shellQuote(idOrPath))
    end
  else
    table.insert(args, "--screen-root " .. util.shellQuote(target))
    table.insert(args, "--bg " .. util.shellQuote(idOrPath))
  end

  -- Same race fix as mpvpaper: stop old engines then start in one shell chain.
  return noctalia.runAsync(stopShell(target) .. "; " .. table.concat(args, " "))
end

return wallpaperengine
