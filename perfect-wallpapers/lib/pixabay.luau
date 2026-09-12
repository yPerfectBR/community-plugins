local util = require("./util.luau")
local config = require("./config.luau")
local session_cache = require("./session_cache.luau")

local pixabay = {}

pixabay.IMAGE_API = "https://pixabay.com/api/"
pixabay.VIDEO_API = "https://pixabay.com/api/videos/"

pixabay.CATEGORIES = {
  "",
  "backgrounds",
  "nature",
  "places",
  "travel",
  "buildings",
  "animals",
  "computer",
  "science",
  "feelings",
  "music",
}

pixabay.CATEGORY_LABELS = {
  "Any",
  "Backgrounds",
  "Nature",
  "Places",
  "Travel",
  "Buildings",
  "Animals",
  "Computer",
  "Science",
  "Feelings",
  "Music",
}

pixabay.ORDER_VALUES = { "popular", "latest" }

local function boolParam(v)
  return if v then "true" else "false"
end

function pixabay.buildImageUrl(opts)
  local key = config.pixabayApiKey()
  if key == "" then
    return nil, "missing_api_key"
  end

  local parts = {
    "key=" .. key,
    "safesearch=" .. boolParam(config.pixabaySafesearch()),
    "image_type=" .. noctalia.string.urlEncode(opts.imageType or config.pixabayImageType()),
    "orientation=" .. noctalia.string.urlEncode(opts.orientation or config.pixabayOrientation()),
    "order=" .. noctalia.string.urlEncode(opts.order or "popular"),
    "page=" .. tostring(opts.page or 1),
    "per_page=" .. tostring(opts.perPage or 20),
  }

  local q = util.trim(opts.query or "")
  if q ~= "" then
    table.insert(parts, "q=" .. noctalia.string.urlEncode(q))
  end

  local category = util.trim(opts.category or "")
  if category ~= "" then
    table.insert(parts, "category=" .. noctalia.string.urlEncode(category))
  end

  local minW = opts.minWidth
  if minW == nil then
    minW = config.pixabayMinWidth()
  end
  local minH = opts.minHeight
  if minH == nil then
    minH = config.pixabayMinHeight()
  end
  if minW > 0 then
    table.insert(parts, "min_width=" .. tostring(minW))
  end
  if minH > 0 then
    table.insert(parts, "min_height=" .. tostring(minH))
  end

  if opts.editorsChoice then
    table.insert(parts, "editors_choice=true")
  end

  return pixabay.IMAGE_API .. "?" .. util.joinParams(parts)
end

function pixabay.buildVideoUrl(opts)
  local key = config.pixabayApiKey()
  if key == "" then
    return nil, "missing_api_key"
  end

  local parts = {
    "key=" .. key,
    "safesearch=" .. boolParam(config.pixabaySafesearch()),
    "video_type=" .. noctalia.string.urlEncode(opts.videoType or "all"),
    "order=" .. noctalia.string.urlEncode(opts.order or "popular"),
    "page=" .. tostring(opts.page or 1),
    "per_page=" .. tostring(opts.perPage or 20),
  }

  local q = util.trim(opts.query or "")
  if q ~= "" then
    table.insert(parts, "q=" .. noctalia.string.urlEncode(q))
  end

  local category = util.trim(opts.category or "")
  if category ~= "" then
    table.insert(parts, "category=" .. noctalia.string.urlEncode(category))
  end

  local minW = opts.minWidth
  if minW == nil then
    minW = config.pixabayMinWidth()
  end
  local minH = opts.minHeight
  if minH == nil then
    minH = config.pixabayMinHeight()
  end
  if minW > 0 then
    table.insert(parts, "min_width=" .. tostring(minW))
  end
  if minH > 0 then
    table.insert(parts, "min_height=" .. tostring(minH))
  end

  if opts.editorsChoice then
    table.insert(parts, "editors_choice=true")
  end

  return pixabay.VIDEO_API .. "?" .. util.joinParams(parts)
end

local function pickImageUrl(hit)
  return hit.largeImageURL or hit.webformatURL or hit.previewURL
end

local function pickThumbUrl(hit)
  return hit.previewURL or hit.webformatURL
end

function pixabay.normalizeImageHit(hit)
  local id = tostring(hit.id or "")
  local w = tonumber(hit.imageWidth) or tonumber(hit.webformatWidth) or 0
  local h = tonumber(hit.imageHeight) or tonumber(hit.webformatHeight) or 0
  return {
    kind = "image",
    source = "pixabay",
    id = id,
    tags = hit.tags or "",
    user = hit.user or "",
    pageURL = hit.pageURL or "",
    previewURL = pickThumbUrl(hit),
    downloadURL = pickImageUrl(hit),
    width = w,
    height = h,
    resolution = if w > 0 and h > 0 then `{w}×{h}` else id,
  }
end

function pixabay.pickVideoStream(hit, quality)
  local videos = hit.videos
  if type(videos) ~= "table" then
    return nil
  end
  local order = { quality, "medium", "large", "small", "tiny" }
  local seen = {}
  for _, key in ipairs(order) do
    if not seen[key] then
      seen[key] = true
      local stream = videos[key]
      if type(stream) == "table" and type(stream.url) == "string" and stream.url ~= "" and (tonumber(stream.size) or 0) > 0 then
        return stream, key
      end
    end
  end
  return nil
end

function pixabay.normalizeVideoHit(hit, quality)
  local stream, qualityUsed = pixabay.pickVideoStream(hit, quality or config.pixabayVideoQuality())
  if stream == nil then
    return nil
  end
  local id = tostring(hit.id or "")
  local w = tonumber(stream.width) or 0
  local h = tonumber(stream.height) or 0
  return {
    kind = "video",
    source = "pixabay",
    id = id,
    tags = hit.tags or "",
    user = hit.user or "",
    pageURL = hit.pageURL or "",
    previewURL = stream.thumbnail or "",
    downloadURL = stream.url,
    width = w,
    height = h,
    duration = tonumber(hit.duration) or 0,
    quality = qualityUsed,
    resolution = if w > 0 and h > 0 then `{w}×{h}` else id,
  }
end

function pixabay.parseResponse(body, kind, quality)
  if type(body) ~= "string" or body == "" then
    return nil, "bad_payload"
  end

  local decoded = noctalia.json.decode(body)
  if type(decoded) ~= "table" then
    return nil, "bad_json"
  end

  if type(decoded.hits) ~= "table" then
    local err = decoded.error or decoded.message
    if type(err) == "string" and err ~= "" then
      return nil, err
    end
    return nil, "bad_payload"
  end

  local items = {}
  for _, hit in ipairs(decoded.hits) do
    local item = if kind == "video"
      then pixabay.normalizeVideoHit(hit, quality)
      else pixabay.normalizeImageHit(hit)
    if item ~= nil then
      table.insert(items, item)
    end
  end

  local totalHits = tonumber(decoded.totalHits) or #items
  return {
    items = items,
    total = tonumber(decoded.total) or totalHits,
    totalHits = totalHits,
  }
end

local inFlight = {}

function pixabay.cancelInFlight()
  inFlight = {}
end

function pixabay.search(opts, cb)
  local kind = opts.kind or "image"
  local cacheKey = session_cache.hashKey({
    "pixabay",
    kind,
    util.trim(opts.query or ""),
    opts.page or 1,
    opts.perPage or 20,
    opts.category or "",
    opts.order or "popular",
    opts.imageType or config.pixabayImageType(),
    opts.orientation or config.pixabayOrientation(),
    opts.videoType or "all",
    opts.minWidth or config.pixabayMinWidth(),
    opts.minHeight or config.pixabayMinHeight(),
    opts.editorsChoice == true,
    opts.quality or config.pixabayVideoQuality(),
    config.pixabaySafesearch(),
  })

  local cached = session_cache.getPage("pixabay", cacheKey)
  if cached ~= nil then
    cb(cached, nil)
    return true
  end

  if inFlight[cacheKey] ~= nil then
    table.insert(inFlight[cacheKey], cb)
    return true
  end

  local url, err
  if kind == "video" then
    url, err = pixabay.buildVideoUrl(opts)
  else
    url, err = pixabay.buildImageUrl(opts)
  end
  if url == nil then
    cb(nil, err or "missing_api_key")
    return false
  end

  inFlight[cacheKey] = { cb }

  local function dispatch(result, notifyErr)
    local waiters = inFlight[cacheKey]
    inFlight[cacheKey] = nil
    if waiters == nil or #waiters == 0 then
      return
    end
    for _, waiter in ipairs(waiters) do
      waiter(result, notifyErr)
    end
  end

  local started = noctalia.http({
    url = url,
    headers = {
      "Accept: application/json",
      "User-Agent: PerfectWallpapers/0.3 (Noctalia plugin)",
    },
  }, function(res)
    if inFlight[cacheKey] == nil then
      return
    end
    if type(res) ~= "table" then
      noctalia.log("pixabay: empty http response")
      dispatch(nil, "http_error")
      return
    end

    local status = tonumber(res.status) or 0
    if not res.ok or status >= 400 then
      local body = ""
      if type(res.body) == "string" then
        body = string.sub(res.body, 1, 180)
      end
      noctalia.log(`pixabay: http status={status} body={body}`)
      if status == 429 then
        dispatch(nil, "rate_limited")
      elseif status == 400 or status == 401 or status == 403 then
        dispatch(nil, "invalid_api_key")
      else
        dispatch(nil, "http:" .. tostring(status))
      end
      return
    end

    local parsed, parseErr = pixabay.parseResponse(res.body, kind, opts.quality)
    if parsed == nil then
      noctalia.log(`pixabay: parse error={parseErr}`)
      dispatch(nil, parseErr or "bad_payload")
      return
    end
    if inFlight[cacheKey] ~= nil then
      session_cache.setPage("pixabay", cacheKey, parsed)
    end
    dispatch(parsed, nil)
  end)

  if not started then
    inFlight[cacheKey] = nil
    noctalia.log("pixabay: http request was not accepted")
    cb(nil, "http_busy")
    return false
  end
  return true
end

return pixabay
