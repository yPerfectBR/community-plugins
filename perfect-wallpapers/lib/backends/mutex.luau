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

function mutex.stopWallpaperEngine()
  local pattern = "(^|/)linux-wallpaperengine($| )"
  local escaped = util.shellQuote(pattern)
  noctalia.runAsync(
    "pkill -TERM -f " .. escaped .. " 2>/dev/null; systemctl --user stop linux-wallpaperengine 2>/dev/null; sleep 0.1; pkill -9 -f " .. escaped .. " 2>/dev/null; true"
  )
end

function mutex.stopMpvpaper()
  local pattern = "(^|/)mpvpaper($| )"
  local escaped = util.shellQuote(pattern)
  noctalia.runAsync("pkill -TERM -f " .. escaped .. " 2>/dev/null; sleep 0.1; pkill -9 -f " .. escaped .. " 2>/dev/null; true")
end

function mutex.stopDynamicBackends()
  -- Always stop managed dynamic engines (linux-wallpaperengine, mpvpaper)
  -- so that changing providers (e.g. Wallpaper Engine -> Wallhaven / Pixabay / Local)
  -- immediately terminates background processes to guarantee maximum efficiency
  -- and prevent redundant CPU/GPU consumption.
  mutex.stopWallpaperEngine()
  mutex.stopMpvpaper()
end

function mutex.stopForeign()
  -- 1. Always stop plugin dynamic engines unconditionally
  mutex.stopDynamicBackends()

  -- 2. Optionally stop unmanaged third-party daemons if enabled in user configuration
  if not config.stopForeignBackends() then
    return
  end
  for _, backend in ipairs(FOREIGN) do
    mutex.stopPattern(backend.pattern)
  end
end

function mutex.enableNoctaliaWallpaper(enabled)
  for _, output in ipairs(noctalia.outputs()) do
    noctalia.setWallpaperEnabled(output.name, enabled)
  end
end

return mutex
