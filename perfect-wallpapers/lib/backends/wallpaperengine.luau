local util = require("../util.luau")
local config = require("../config.luau")
local mutex = require("./mutex.luau")

local wallpaperengine = {}

function wallpaperengine.available()
  return noctalia.commandExists("linux-wallpaperengine")
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

  mutex.stopForeign(target)

  -- Sincroniza a paleta de cores do Noctalia / Umbriel com o preview estático
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

  local cmd = table.concat(args, " ")
  return noctalia.runAsync(cmd)
end

return wallpaperengine
