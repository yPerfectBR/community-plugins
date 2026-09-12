local util = require("../util.luau")
local config = require("../config.luau")

local mutex = {}

-- Unmanaged third-party daemons that may conflict on Wayland
local FOREIGN = {
  { name = "swww-daemon", pattern = "(^|/)swww-daemon($| )" },
  { name = "awww-daemon", pattern = "(^|/)awww-daemon($| )" },
}

function mutex.stopPattern(pattern)
  local escaped = util.shellQuote(pattern)
  noctalia.runAsync("pkill -TERM -f " .. escaped .. " 2>/dev/null; sleep 0.1; pkill -9 -f " .. escaped .. " 2>/dev/null; true")
end

function mutex.stopWallpaperEngine(connector)
  local pattern
  if connector and connector ~= "*" and connector ~= "all" then
    pattern = "linux-wallpaperengine.*" .. connector
  else
    pattern = "(^|/)linux-wallpaperengine($| )"
  end
  local escaped = util.shellQuote(pattern)
  noctalia.runAsync(
    "pkill -TERM -f " .. escaped .. " 2>/dev/null; systemctl --user stop linux-wallpaperengine 2>/dev/null; sleep 0.1; pkill -9 -f " .. escaped .. " 2>/dev/null; true"
  )
end

function mutex.stopMpvpaper(connector)
  local pattern
  if connector and connector ~= "*" and connector ~= "all" then
    pattern = "mpvpaper.*" .. connector
  else
    pattern = "(^|/)mpvpaper($| )"
  end
  local escaped = util.shellQuote(pattern)
  noctalia.runAsync("pkill -TERM -f " .. escaped .. " 2>/dev/null; sleep 0.1; pkill -9 -f " .. escaped .. " 2>/dev/null; true")
end

function mutex.stopDynamicBackends(connector)
  -- Always stop managed dynamic engines (linux-wallpaperengine, mpvpaper)
  -- for the specified connector (or all connectors if nil/'*')
  -- so that changing providers (e.g. Wallpaper Engine -> Wallhaven / Pixabay / Local / Daily)
  -- immediately terminates background processes to guarantee maximum efficiency
  -- and prevent redundant CPU/GPU consumption.
  mutex.stopWallpaperEngine(connector)
  mutex.stopMpvpaper(connector)
end

function mutex.stopForeign(connector)
  -- 1. Always stop plugin dynamic engines unconditionally
  mutex.stopDynamicBackends(connector)

  -- 2. Optionally stop unmanaged third-party daemons if enabled in user configuration
  if not config.stopForeignBackends() then
    return
  end
  if not connector or connector == "*" or connector == "all" then
    for _, backend in ipairs(FOREIGN) do
      mutex.stopPattern(backend.pattern)
    end
  end
end

function mutex.enableNoctaliaWallpaper(enabled, connector)
  if connector and connector ~= "*" and connector ~= "all" then
    noctalia.setWallpaperEnabled(connector, enabled)
    return
  end
  for _, output in ipairs(noctalia.outputs()) do
    noctalia.setWallpaperEnabled(output.name, enabled)
  end
end

return mutex
