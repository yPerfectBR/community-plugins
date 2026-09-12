local util = require("./util.luau")

local config = {}

function config.defaultProvider()
  local v = util.cfg("default_provider", "pixabay")
  if v == "wallhaven" or v == "local" or v == "wallpaperengine" or v == "daily" then
    return v
  end
  return "pixabay"
end

function config.wallpaperEngineDirectory()
  local dir = util.cfg("wallpaperengine_dir", "")
  if type(dir) == "string" and dir ~= "" then
    return noctalia.expandPath(util.trim(dir))
  end
  return ""
end

function config.localDirectories()
  local raw = util.cfg("local_directories", {})
  local dirs = {}
  if type(raw) == "table" then
    for _, entry in ipairs(raw) do
      if type(entry) == "string" then
        local trimmed = util.trim(entry)
        if trimmed ~= "" then
          table.insert(dirs, noctalia.expandPath(trimmed))
        end
      end
    end
  end
  return dirs
end

function config.hasLocalDirectories()
  return #config.localDirectories() > 0
end

function config.sharedDownloadDir()
  return util.trim(util.cfg("download_dir", ""))
end

function config.pixabayApiKey()
  return util.trim(util.cfg("pixabay_api_key", ""))
end

function config.hasPixabayKey()
  return config.pixabayApiKey() ~= ""
end

function config.pixabayDownloadDir()
  return util.trim(util.cfg("pixabay_download_dir", ""))
end

function config.pixabaySafesearch()
  return util.truthy(util.cfg("pixabay_safesearch", true))
end

function config.pixabayDefaultMedia()
  local v = util.cfg("pixabay_default_media", "image")
  if v == "video" then
    return "video"
  end
  return "image"
end

function config.pixabayImageType()
  return util.cfg("pixabay_image_type", "photo")
end

function config.pixabayOrientation()
  return util.cfg("pixabay_orientation", "horizontal")
end

function config.pixabayMinWidth()
  return tonumber(util.cfg("pixabay_min_width", 1920)) or 1920
end

function config.pixabayMinHeight()
  return tonumber(util.cfg("pixabay_min_height", 1080)) or 1080
end

function config.pixabayVideoQuality()
  local q = util.cfg("pixabay_video_quality", "medium")
  if q == "large" or q == "small" or q == "tiny" then
    return q
  end
  return "medium"
end

function config.wallhavenApiKey()
  return util.trim(util.cfg("wallhaven_api_key", ""))
end

function config.hasWallhavenKey()
  return config.wallhavenApiKey() ~= ""
end

function config.wallhavenDownloadDir()
  return util.trim(util.cfg("wallhaven_download_dir", ""))
end

function config.wallhavenSorting()
  return util.cfg("wallhaven_sorting", "date_added")
end

function config.wallhavenOrder()
  local v = util.cfg("wallhaven_order", "desc")
  if v == "asc" then
    return "asc"
  end
  return "desc"
end

function config.wallhavenCategoryGeneral()
  return util.truthy(util.cfg("wallhaven_categories_general", true))
end

function config.wallhavenCategoryAnime()
  return util.truthy(util.cfg("wallhaven_categories_anime", true))
end

function config.wallhavenCategoryPeople()
  return util.truthy(util.cfg("wallhaven_categories_people", true))
end

function config.wallhavenPuritySfw()
  return util.truthy(util.cfg("wallhaven_purity_sfw", true))
end

function config.wallhavenPuritySketchy()
  return util.truthy(util.cfg("wallhaven_purity_sketchy", false))
end

function config.wallhavenPurityNsfw()
  return util.truthy(util.cfg("wallhaven_purity_nsfw", false))
end

function config.wallhavenRatio()
  local v = util.cfg("wallhaven_ratio", "any") or "any"
  if v == "any" or v == "" then
    return ""
  end
  return v
end

function config.wallhavenResolutionMode()
  local v = util.cfg("wallhaven_resolution_mode", "atleast")
  if v == "exact" then
    return "exact"
  end
  return "atleast"
end

function config.wallhavenMinWidth()
  return tonumber(util.cfg("wallhaven_min_width", 1920)) or 1920
end

function config.wallhavenMinHeight()
  return tonumber(util.cfg("wallhaven_min_height", 1080)) or 1080
end

function config.videoFps()
  return tonumber(util.cfg("video_fps", 30)) or 30
end

function config.videoScale()
  local s = util.cfg("video_scale", "panscan")
  if s == "fit" or s == "stretch" then
    return s
  end
  return "panscan"
end

function config.hardwareDecode()
  return util.truthy(util.cfg("hardware_decode", true))
end

function config.muteVideo()
  return util.truthy(util.cfg("mute_video", true))
end

function config.pauseOnBattery()
  return util.truthy(util.cfg("pause_on_battery", true))
end

function config.copyToWallpaperDir()
  return util.truthy(util.cfg("copy_to_wallpaper_dir", false))
end

-- ── Daily Wallpaper (Bing & NASA APOD) ──────────────────────────────────────

function config.dailySubsource()
  local s = util.cfg("daily_subsource", "bing")
  if s == "nasa" then
    return "nasa"
  end
  return "bing"
end

function config.dailyAutoRotate()
  return util.truthy(util.cfg("daily_auto_rotate", false))
end

function config.dailyLocale()
  return util.trim(util.cfg("daily_locale", ""))
end

function config.stopForeignBackends()
  return util.truthy(util.cfg("stop_foreign_backends", true))
end

function config.apiKey()
  return config.pixabayApiKey()
end

function config.hasApiKey()
  return config.hasPixabayKey()
end

function config.safesearch()
  return config.pixabaySafesearch()
end

function config.defaultMedia()
  return config.pixabayDefaultMedia()
end

function config.imageType()
  return config.pixabayImageType()
end

function config.orientation()
  return config.pixabayOrientation()
end

function config.minWidth()
  return config.pixabayMinWidth()
end

function config.minHeight()
  return config.pixabayMinHeight()
end

function config.videoQuality()
  return config.pixabayVideoQuality()
end

return config
