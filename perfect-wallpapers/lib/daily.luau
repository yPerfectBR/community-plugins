--!nonstrict
local util = require("./util.luau")
local paths = require("./paths.luau")
local config = require("./config.luau")

local daily = {}

local CACHE_VALIDITY_SECONDS = 3 * 3600 -- 3 hours in RAM cache

local function cacheFilePath(subSource)
  return paths.sessionRoot() .. `/daily_{subSource}.json`
end

local function decodeHtml(value)
  if type(value) ~= "string" then
    return ""
  end
  local decoded = value:gsub("&amp;", "&")
  decoded = decoded:gsub("&quot;", '"')
  decoded = decoded:gsub("&apos;", "'")
  decoded = decoded:gsub("&#39;", "'")
  decoded = decoded:gsub("&lt;", "<")
  decoded = decoded:gsub("&gt;", ">")
  decoded = decoded:gsub("&#(%d+);", function(n)
    local code = tonumber(n)
    return (code and code < 256) and string.char(code) or ""
  end)
  return decoded
end

local function splitCopyright(copyright)
  local body, credit = copyright:match("^(.-)%s*%(([^()]*)%)%s*$")
  if body and credit then
    return decodeHtml(body), decodeHtml(credit)
  end
  return decodeHtml(copyright), ""
end

local function readCache(subSource)
  local path = cacheFilePath(subSource)
  if not noctalia.fileExists(path) then
    return nil
  end
  local info = noctalia.fileInfo(path)
  if type(info) == "table" and type(info.mtime) == "number" then
    local now = tonumber(noctalia.formatTime("%s")) or os.time()
    if now - info.mtime > CACHE_VALIDITY_SECONDS then
      return nil
    end
  end
  local content = noctalia.readFile(path)
  if type(content) ~= "string" or content == "" then
    return nil
  end
  local parsed = noctalia.json.decode(content)
  if type(parsed) == "table" and #parsed > 0 then
    return parsed
  end
  return nil
end

local function writeCache(subSource, items)
  paths.ensure(paths.sessionRoot(), function()
    local encoded = noctalia.json.encode(items)
    if type(encoded) == "string" and encoded ~= "" then
      noctalia.writeFile(cacheFilePath(subSource), encoded)
    end
  end)
end

function daily.fetchBing(locale, cb)
  locale = locale or config.dailyLocale()
  if locale == "" then
    locale = "en-US"
  end

  local cached = readCache("bing")
  if cached ~= nil then
    cb(cached, nil)
    return
  end

  local url = `https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=8&mkt={noctalia.string.urlEncode(locale)}`
  local started = noctalia.http({ url = url }, function(res)
    if not res.ok or res.status < 200 or res.status >= 300 then
      cb(nil, `http:{res.status}`)
      return
    end

    local parsed, err = noctalia.json.decode(res.body)
    if type(parsed) ~= "table" or type(parsed.images) ~= "table" then
      cb(nil, err or "invalid_json")
      return
    end

    local items = {}
    for _, img in ipairs(parsed.images) do
      local urlBase = img.urlbase
      if type(urlBase) == "string" and urlBase ~= "" then
        local rawTitle = (type(img.title) == "string" and img.title ~= "") and img.title or ""
        local rawCopyright = img.copyright or ""
        local title, credit = splitCopyright(rawCopyright)
        if rawTitle ~= "" then
          title = decodeHtml(rawTitle)
        end

        local uhdUrl = `https://www.bing.com{urlBase}_UHD.jpg`
        local fhdUrl = `https://www.bing.com{urlBase}_1920x1080.jpg`
        local thumbUrl = `https://www.bing.com{urlBase}_800x480.jpg`
        local link = (type(img.copyrightlink) == "string" and img.copyrightlink ~= "") and img.copyrightlink or ""
        local startDate = img.startdate or os.date("%Y%m%d")

        table.insert(items, {
          id = `bing_{startDate}`,
          source = "daily",
          subSource = "bing",
          title = title,
          user = credit,
          date = startDate,
          description = decodeHtml(img.headline or title),
          previewURL = thumbUrl,
          downloadURL = uhdUrl,
          fallbackURL = fhdUrl,
          pageURL = link,
          fileType = "image/jpeg",
          kind = "image",
          width = 3840,
          height = 2160,
        })
      end
    end

    if #items == 0 then
      cb(nil, "no_results")
      return
    end

    writeCache("bing", items)
    cb(items, nil)
  end)

  if not started then
    cb(nil, "http_busy")
  end
end

function daily.fetchNasa(cb)
  local cached = readCache("nasa")
  if cached ~= nil then
    cb(cached, nil)
    return
  end

  local url = "https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY&count=8"
  local started = noctalia.http({ url = url }, function(res)
    if res.ok and res.status >= 200 and res.status < 300 then
      local parsed, err = noctalia.json.decode(res.body)
      if type(parsed) == "table" and #parsed > 0 then
        local items = {}
        for _, entry in ipairs(parsed) do
          local download = entry.hdurl or entry.url
          local thumb = entry.url or entry.hdurl
          if type(download) == "string" and download ~= "" then
            local kind = if entry.media_type == "video" then "video" else "image"
            local dateStr = entry.date or os.date("%Y-%m-%d")
            local cleanDate = dateStr:gsub("-", "")
            table.insert(items, {
              id = `nasa_{cleanDate}`,
              source = "daily",
              subSource = "nasa",
              title = decodeHtml(entry.title or "NASA Astronomy Picture"),
              user = decodeHtml(entry.copyright or "NASA"),
              date = dateStr,
              description = decodeHtml(entry.explanation or ""),
              previewURL = thumb,
              downloadURL = download,
              fallbackURL = entry.url or download,
              pageURL = `https://apod.nasa.gov/apod/ap{cleanDate:sub(3)}.html`,
              fileType = if kind == "video" then "video/mp4" else "image/jpeg",
              kind = kind,
              width = 1920,
              height = 1080,
            })
          end
        end

        if #items > 0 then
          writeCache("nasa", items)
          cb(items, nil)
          return
        end
      end
    end

    -- Fallback: scrape NASA Image of the Day
    local fallbackStarted = noctalia.http({ url = "https://www.nasa.gov/image-of-the-day/" }, function(fbRes)
      if not fbRes.ok or fbRes.status < 200 or fbRes.status >= 300 then
        cb(nil, `http:{fbRes.status}`)
        return
      end

      local page = fbRes.body
      local items = {}
      local pos = 1
      while true do
        local s, e = page:find('<img[^>]-src="([^"]+)"', pos)
        if not s then break end
        local src = page:match('<img[^>]-src="([^"]+)"', s)
        if src and not src:find("logo") and not src:find("icon") and (src:find(".jpg") or src:find(".png")) then
          local id = "nasa_" .. tostring(#items + 1)
          table.insert(items, {
            id = id,
            source = "daily",
            subSource = "nasa",
            title = "NASA Image of the Day",
            user = "NASA",
            date = os.date("%Y-%m-%d"),
            description = "NASA official image of the day gallery",
            previewURL = src,
            downloadURL = src,
            fallbackURL = src,
            pageURL = "https://www.nasa.gov/image-of-the-day/",
            fileType = "image/jpeg",
            kind = "image",
            width = 1920,
            height = 1080,
          })
          if #items >= 6 then break end
        end
        pos = e + 1
      end

      if #items > 0 then
        writeCache("nasa", items)
        cb(items, nil)
      else
        cb(nil, "no_results")
      end
    end)

    if not fallbackStarted then
      cb(nil, "http_busy")
    end
  end)

  if not started then
    cb(nil, "http_busy")
  end
end

function daily.fetch(subSource, cb)
  subSource = subSource or config.dailySubsource()
  if subSource == "nasa" then
    daily.fetchNasa(cb)
  else
    daily.fetchBing(nil, cb)
  end
end

function daily.today(subSource, cb)
  daily.fetch(subSource, function(items, err)
    if type(items) == "table" and #items > 0 then
      cb(items[1], nil)
    else
      cb(nil, err)
    end
  end)
end

return daily
