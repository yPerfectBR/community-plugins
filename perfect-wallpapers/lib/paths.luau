local util = require("./util.luau")

local paths = {}

local function xdg(envName, fallbackRel)
  local root = noctalia.getenv(envName)
  if type(root) == "string" and root ~= "" then
    return root
  end
  local home = noctalia.getenv("HOME") or ""
  return home .. fallbackRel
end

function paths.stateDir()
  return xdg("XDG_STATE_HOME", "/.local/state") .. "/noctalia/perfect-wallpapers"
end

-- Session-only hidden cache. Lives under XDG_RUNTIME_DIR (or /tmp) so a reboot
-- drops it, and the service also wipes it on start without opening the hub.
function paths.sessionRoot()
  local runtime = noctalia.getenv("XDG_RUNTIME_DIR")
  if type(runtime) == "string" and runtime ~= "" then
    return runtime .. "/.pw-session"
  end
  local uid = noctalia.getenv("UID") or "0"
  return "/tmp/.pw-session-" .. tostring(uid)
end

function paths.cacheDir()
  return paths.sessionRoot()
end

function paths.pageCacheDir(provider)
  local suffix = if provider and provider ~= "" then "/" .. provider else ""
  return paths.sessionRoot() .. "/pages" .. suffix
end

function paths.thumbDir(source)
  local suffix = if source and source ~= "" then "/" .. source else ""
  return paths.sessionRoot() .. "/thumbs" .. suffix
end

-- Old persistent location from earlier builds; wiped on service start.
function paths.legacyCacheDir()
  return xdg("XDG_CACHE_HOME", "/.cache") .. "/noctalia/perfect-wallpapers"
end

local function resolveDir(preferred, shared)
  if type(preferred) == "string" and preferred ~= "" then
    return noctalia.expandPath(preferred)
  end
  if type(shared) == "string" and shared ~= "" then
    return noctalia.expandPath(shared)
  end
  local wallpaperDir = noctalia.wallpaperDirectory()
  if type(wallpaperDir) == "string" and wallpaperDir ~= "" then
    return noctalia.expandPath(wallpaperDir)
  end
  return noctalia.expandPath("~/Pictures/Wallpapers/perfect-wallpapers")
end

function paths.downloadDir(source)
  local shared = util.cfg("download_dir", "")
  if source == "wallhaven" then
    return resolveDir(util.cfg("wallhaven_download_dir", ""), shared)
  end
  if source == "pixabay" then
    return resolveDir(util.cfg("pixabay_download_dir", ""), shared)
  end
  return resolveDir("", shared)
end

function paths.ensure(dir, done)
  noctalia.runAsync("mkdir -p " .. util.shellQuote(dir), done)
end

function paths.wipeDir(dir, done)
  if type(dir) ~= "string" or dir == "" then
    if done then
      done()
    end
    return
  end
  noctalia.runAsync("rm -rf " .. util.shellQuote(dir), done)
end

return paths
