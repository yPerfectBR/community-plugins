local util = require("./util.luau")
local config = require("./config.luau")
local session_cache = require("./session_cache.luau")

local wallhaven = {}

wallhaven.API_BASE = "https://wallhaven.cc/api/v1"

wallhaven.SORT_VALUES = {
  "relevance",
  "random",
  "date_added",
  "views",
  "favorites",
  "toplist",
  "hot",
}

wallhaven.RATIO_VALUES = {
  "",
  "wide",
  "portrait",
  "16x9",
  "16x10",
  "21x9",
  "32x9",
  "9x16",
  "10x16",
  "1x1",
  "3x2",
  "4x3",
  "5x4",
}

local function bit(v)
  return if v then "1" else "0"
end

function wallhaven.sortIndexFor(value)
  for i, name in ipairs(wallhaven.SORT_VALUES) do
    if name == value then
      return i - 1
    end
  end
  return 2
end

function wallhaven.ratioIndexFor(value)
  for i, name in ipairs(wallhaven.RATIO_VALUES) do
    if name == value then
      return i - 1
    end
  end
  return 0
end

function wallhaven.buildCategories(general, anime, people)
  local categories = bit(general) .. bit(anime) .. bit(people)
  if categories == "000" then
    return "100"
  end
  return categories
end

function wallhaven.buildPurity(sfw, sketchy, nsfw, allowNsfw)
  local purity = bit(sfw) .. bit(sketchy) .. bit(allowNsfw and nsfw)
  if purity == "000" then
    return "100"
  end
  return purity
end

function wallhaven.ratioParam(ratio)
  if ratio == nil or ratio == "" then
    return nil
  end
  if ratio == "wide" then
    return "landscape"
  end
  if ratio == "portrait" then
    return "portrait"
  end
  return ratio
end

function wallhaven.normalizeHit(hit)
  local id = tostring(hit.id or "")
  local resolution = hit.resolution or id
  local w, h = 0, 0
  if type(resolution) == "string" then
    local rw, rh = resolution:match("(%d+)x(%d+)")
    w = tonumber(rw) or 0
    h = tonumber(rh) or 0
  end

  local thumbs = hit.thumbs or {}
  local preview = thumbs.large or thumbs.original or thumbs.small or ""
  local download = hit.path or ""
  local pageURL = hit.url or ""
  if pageURL == "" and id ~= "" then
    pageURL = "https://wallhaven.cc/w/" .. id
  end

  return {
    kind = "image",
    source = "wallhaven",
    id = id,
    tags = "",
    user = "",
    pageURL = pageURL,
    previewURL = preview,
    downloadURL = download,
    width = w,
    height = h,
    resolution = resolution,
    purity = hit.purity or "sfw",
    fileType = hit.file_type or "",
  }
end

local function matchesRatio(item, selectedRatio)
  if selectedRatio == nil or selectedRatio == "" then
    return true
  end
  if item.width <= 0 or item.height <= 0 then
    return true
  end
  local ratio = item.width / item.height
  if selectedRatio == "wide" then
    return ratio > 1
  end
  if selectedRatio == "portrait" then
    return ratio < 1
  end
  local rw, rh = selectedRatio:match("(%d+)x(%d+)")
  if rw and rh then
    local target = tonumber(rw) / tonumber(rh)
    return math.abs(ratio - target) <= 0.05
  end
  return true
end

local inFlight = {}

function wallhaven.cancelInFlight()
  inFlight = {}
end

function wallhaven.search(opts, cb)
  local key = config.wallhavenApiKey()
  local allowNsfw = key ~= ""
  local sorting = opts.sorting or config.wallhavenSorting()
  local order = opts.order or config.wallhavenOrder()
  local page = opts.page or 1
  local query = util.trim(opts.query or "")

  local cacheKey = session_cache.hashKey({
    "wallhaven",
    query,
    page,
    sorting,
    order,
    opts.general == true,
    opts.anime == true,
    opts.people == true,
    opts.sfw == true,
    opts.sketchy == true,
    opts.nsfw == true,
    allowNsfw,
    opts.ratio or "",
    opts.resolutionMode or "atleast",
    tonumber(opts.minWidth) or 0,
    tonumber(opts.minHeight) or 0,
  })

  local cached = session_cache.getPage("wallhaven", cacheKey)
  if cached ~= nil then
    cb(cached, nil)
    return true
  end

  if inFlight[cacheKey] ~= nil then
    table.insert(inFlight[cacheKey], cb)
    return true
  end

  -- Wallhaven returns an empty first page for relevance with an empty query.
  local apiPage = page
  if sorting == "relevance" and query == "" then
    apiPage = page + 1
  end

  local params = {
    "categories=" .. wallhaven.buildCategories(opts.general, opts.anime, opts.people),
    "purity=" .. wallhaven.buildPurity(opts.sfw, opts.sketchy, opts.nsfw, allowNsfw),
    "page=" .. tostring(apiPage),
    "sorting=" .. noctalia.string.urlEncode(sorting),
    "order=" .. noctalia.string.urlEncode(order),
  }

  if query ~= "" then
    table.insert(params, "q=" .. noctalia.string.urlEncode(query))
  end

  local ratio = wallhaven.ratioParam(opts.ratio)
  if ratio ~= nil then
    table.insert(params, "ratios=" .. noctalia.string.urlEncode(ratio))
  end

  local minW = tonumber(opts.minWidth) or 0
  local minH = tonumber(opts.minHeight) or 0
  if minW > 0 and minH > 0 then
    local resolution = tostring(minW) .. "x" .. tostring(minH)
    if opts.resolutionMode == "exact" then
      table.insert(params, "resolutions=" .. resolution)
    else
      table.insert(params, "atleast=" .. resolution)
    end
  end

  local headers = { "Accept: application/json" }
  if key ~= "" then
    table.insert(headers, "X-API-Key: " .. key)
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

  local url = wallhaven.API_BASE .. "/search?" .. util.joinParams(params)
  local started = noctalia.http({ url = url, headers = headers }, function(res)
    if inFlight[cacheKey] == nil then
      return
    end
    if not res.ok then
      local msg = "http_error"
      if res.status == 429 then
        msg = "rate_limited"
      elseif type(res.body) == "string" and res.body ~= "" then
        msg = res.body
      end
      dispatch(nil, msg)
      return
    end

    local decoded = noctalia.json.decode(res.body)
    if type(decoded) ~= "table" or type(decoded.data) ~= "table" then
      local err = decoded and decoded.error or "bad_payload"
      dispatch(nil, tostring(err))
      return
    end

    local lastPage = 1
    if type(decoded.meta) == "table" and type(decoded.meta.last_page) == "number" then
      lastPage = math.max(1, math.floor(decoded.meta.last_page))
    end
    if sorting == "relevance" and query == "" then
      lastPage = math.max(1, lastPage - 1)
    end

    local items = {}
    local selectedRatio = opts.ratio or ""
    for _, hit in ipairs(decoded.data) do
      local item = wallhaven.normalizeHit(hit)
      if matchesRatio(item, selectedRatio) then
        table.insert(items, item)
      end
    end

    local payload = {
      items = items,
      totalHits = #items,
      totalPages = lastPage,
    }
    if inFlight[cacheKey] ~= nil then
      session_cache.setPage("wallhaven", cacheKey, payload)
    end
    dispatch(payload, nil)
  end)

  if not started then
    inFlight[cacheKey] = nil
    cb(nil, "http_busy")
    return false
  end
  return true
end

return wallhaven
