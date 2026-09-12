local util = require("../util.luau")
local config = require("../config.luau")

local mutex = {}

local FOREIGN = {
  { name = "mpvpaper", pattern = "(^|/)mpvpaper " },
  { name = "linux-wallpaperengine", pattern = "(^|/)linux-wallpaperengine( |$)" },
  { name = "swww-daemon", pattern = "(^|/)swww-daemon( |$)" },
  { name = "awww-daemon", pattern = "(^|/)awww-daemon( |$)" },
}

function mutex.stopPattern(pattern)
  local escaped = util.shellQuote(pattern)
  noctalia.runAsync("pkill -TERM -f " .. escaped .. " 2>/dev/null; sleep 0.1; pkill -9 -f " .. escaped .. " 2>/dev/null; true")
end

function mutex.stopForeign()
  if not config.stopForeignBackends() then
    return
  end
  for _, backend in ipairs(FOREIGN) do
    mutex.stopPattern(backend.pattern)
  end
end

function mutex.stopMpvpaper()
  mutex.stopPattern("(^|/)mpvpaper ")
end

function mutex.stopWallpaperEngine()
  mutex.stopPattern("(^|/)linux-wallpaperengine( |$)")
end

function mutex.enableNoctaliaWallpaper(enabled)
  for _, output in ipairs(noctalia.outputs()) do
    noctalia.setWallpaperEnabled(output.name, enabled)
  end
end

return mutex
