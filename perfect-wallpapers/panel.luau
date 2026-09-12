--!nonstrict
local config = require("./lib/config.luau")
local paths = require("./lib/paths.luau")
local session_cache = require("./lib/session_cache.luau")
local pixabay = require("./lib/pixabay.luau")
local wallhaven = require("./lib/wallhaven.luau")
local local_library = require("./lib/local_library.luau")
local we = require("./lib/wallpaperengine.luau")
local thumbs = require("./lib/thumbs.luau")
local apply = require("./lib/apply.luau")
local chips = require("./ui/chips.luau")
local grid = require("./ui/grid.luau")

local PLUGIN_ID = "perfect/perfect-wallpapers"

local provider = config.defaultProvider()
local media = config.pixabayDefaultMedia()
local query = ""
local page = 1
local perPage = 20
local totalPagesCount = 1
local items = {}
local allLocalItems = {}
local loading = false
local applying = false
local errorMessage = ""
local selectedId = ""
local currentRequestId = 0
local status = apply.currentStatus() or { mode = "none" }
local isOpen = false

-- Wallpaper Engine filter state
local weTypeIndex = 0
local weTotalInstalled = 0

-- Pixabay filter state
local pbCategoryIndex = 0
local pbOrderIndex = 0
local pbEditorsChoice = false

-- Wallhaven filter state (seeded from settings on open)
local whGeneral = true
local whAnime = true
local whPeople = true
local whSfw = true
local whSketchy = false
local whNsfw = false
local whSortIndex = 2
local whOrder = "desc"
local whRatioIndex = 0
local whResolutionMode = "atleast"
local whMinWidth = ""
local whMinHeight = ""
local whClearCounter = 0

local render
local fetch

local function tr(key)
  return noctalia.tr(key)
end

local function findItem(id)
  for _, item in ipairs(items) do
    if item.id == id then
      return item
    end
  end
  return nil
end

local function mapError(err)
  if err == "missing_api_key" then
    return tr("errors.missing_pixabay_key")
  end
  if err == "invalid_api_key" then
    return tr("errors.invalid_api_key")
  end
  if err == "no_local_dirs" then
    return tr("errors.no_local_dirs")
  end
  if err == "rate_limited" then
    return tr("errors.rate_limited")
  end
  if err == "http_busy" then
    return tr("errors.http_busy")
  end
  if err == "mpvpaper_missing" then
    return tr("errors.mpvpaper_missing")
  end
  if err == "wallpaperengine_missing" then
    return tr("errors.wallpaperengine_missing")
  end
  if err == "no_we_wallpapers" then
    return tr("errors.no_we_wallpapers")
  end
  if err == "wallpaperengine_failed" then
    return tr("errors.apply_failed")
  end
  if err == "download_failed" or err == "mkdir_failed" then
    return tr("errors.download_failed")
  end
  if err == "mpvpaper_failed" then
    return tr("errors.apply_failed")
  end
  if type(err) == "string" and string.sub(err, 1, 5) == "http:" then
    return string.format(tr("errors.http_status"), string.sub(err, 6))
  end
  return tr("errors.request_failed")
end

local function resetResults()
  page = 1
  selectedId = ""
  items = {}
  allLocalItems = {}
  totalPagesCount = 1
  errorMessage = ""
  thumbs.setSource(provider)
end

local function seedWallhavenFilters()
  whGeneral = config.wallhavenCategoryGeneral()
  whAnime = config.wallhavenCategoryAnime()
  whPeople = config.wallhavenCategoryPeople()
  whSfw = config.wallhavenPuritySfw()
  whSketchy = config.wallhavenPuritySketchy()
  whNsfw = config.wallhavenPurityNsfw() and config.hasWallhavenKey()
  whSortIndex = wallhaven.sortIndexFor(config.wallhavenSorting())
  whOrder = config.wallhavenOrder()
  whRatioIndex = wallhaven.ratioIndexFor(config.wallhavenRatio())
  whResolutionMode = config.wallhavenResolutionMode()
  local minW = config.wallhavenMinWidth()
  local minH = config.wallhavenMinHeight()
  whMinWidth = if minW > 0 then tostring(minW) else ""
  whMinHeight = if minH > 0 then tostring(minH) else ""
end

local function setProvider(nextProvider)
  if provider == nextProvider then
    return
  end
  provider = nextProvider
  query = ""
  if provider == "pixabay" then
    media = config.pixabayDefaultMedia()
  elseif provider == "local" then
    media = "image"
  elseif provider == "wallpaperengine" then
    weTypeIndex = 0
  end
  resetResults()
  fetch()
end

local function setMedia(nextMedia)
  if media == nextMedia then
    return
  end
  media = nextMedia
  resetResults()
  fetch()
end

local function whSortLabels()
  return {
    tr("wallhaven.sort.relevance"),
    tr("wallhaven.sort.random"),
    tr("wallhaven.sort.date_added"),
    tr("wallhaven.sort.views"),
    tr("wallhaven.sort.favorites"),
    tr("wallhaven.sort.toplist"),
    tr("wallhaven.sort.hot"),
  }
end

local function whRatioLabels()
  return {
    tr("wallhaven.ratio.any"),
    tr("wallhaven.ratio.wide"),
    tr("wallhaven.ratio.portrait"),
    "16:9",
    "16:10",
    "21:9",
    "32:9",
    "9:16",
    "10:16",
    "1:1",
    "3:2",
    "4:3",
    "5:4",
  }
end

fetch = function()
  currentRequestId += 1
  local thisRequestId = currentRequestId

  if provider == "pixabay" and not config.hasPixabayKey() then
    loading = false
    items = {}
    totalPagesCount = 1
    errorMessage = tr("errors.missing_pixabay_key")
    render()
    return
  end

  if provider == "local" and not config.hasLocalDirectories() then
    loading = false
    items = {}
    allLocalItems = {}
    totalPagesCount = 1
    errorMessage = tr("errors.no_local_dirs")
    render()
    return
  end

  loading = true
  errorMessage = ""
  render()

  if provider == "local" then
    local result, err = local_library.scan({
      kind = media,
      query = query,
    })
    if thisRequestId ~= currentRequestId then
      return
    end
    loading = false
    if result == nil then
      items = {}
      allLocalItems = {}
      totalPagesCount = 1
      errorMessage = mapError(err)
      render()
      return
    end
    allLocalItems = result.items
    items, totalPagesCount, page = local_library.pageSlice(allLocalItems, page, perPage)
    render()
    thumbs.enqueue(items)
    return
  end

  if provider == "wallpaperengine" then
    local types = { "all", "scene", "video", "web" }
    local typeFilter = types[weTypeIndex + 1] or "all"
    we.search({
      query = query,
      typeFilter = typeFilter,
      page = page,
      perPage = perPage,
    }, function(result, err)
      if thisRequestId ~= currentRequestId then
        return
      end
      loading = false
      if result == nil then
        items = {}
        totalPagesCount = 1
        errorMessage = mapError(err)
        render()
        return
      end
      items = result.items
      totalPagesCount = result.totalPages or 1
      weTotalInstalled = result.totalInstalled or 0
      page = result.page or page
      if #items == 0 and query == "" and weTotalInstalled == 0 then
        errorMessage = tr("errors.no_we_wallpapers")
      end
      render()
      thumbs.enqueue(items)
    end)
    return
  end

  if provider == "wallhaven" then
    local minW = tonumber(whMinWidth) or 0
    local minH = tonumber(whMinHeight) or 0
    wallhaven.search({
      query = query,
      page = page,
      general = whGeneral,
      anime = whAnime,
      people = whPeople,
      sfw = whSfw,
      sketchy = whSketchy,
      nsfw = whNsfw,
      sorting = wallhaven.SORT_VALUES[whSortIndex + 1] or "date_added",
      order = whOrder,
      ratio = wallhaven.RATIO_VALUES[whRatioIndex + 1] or "",
      resolutionMode = whResolutionMode,
      minWidth = minW,
      minHeight = minH,
    }, function(result, err)
      if thisRequestId ~= currentRequestId then
        -- O usuário trocou de aba/filtro antes da API terminar.
        -- O resultado já está salvo no cache pelo wallhaven.search; não atualiza a UI antiga.
        return
      end
      loading = false
      if result == nil then
        items = {}
        totalPagesCount = 1
        errorMessage = mapError(err)
        render()
        return
      end
      items = result.items
      totalPagesCount = result.totalPages or 1
      if page > totalPagesCount then
        page = totalPagesCount
      end
      render()
      thumbs.enqueue(items)
    end)
    return
  end

  pixabay.search({
    kind = media,
    query = query,
    page = page,
    perPage = perPage,
    category = pixabay.CATEGORIES[pbCategoryIndex + 1] or "",
    order = pixabay.ORDER_VALUES[pbOrderIndex + 1] or "popular",
    editorsChoice = pbEditorsChoice,
    quality = config.pixabayVideoQuality(),
  }, function(result, err)
    if thisRequestId ~= currentRequestId then
      -- O usuário trocou de aba/filtro antes da API terminar.
      -- O resultado já está salvo no cache pelo pixabay.search; não atualiza a UI antiga.
      return
    end
    loading = false
    if result == nil then
      items = {}
      totalPagesCount = 1
      errorMessage = mapError(err)
      render()
      return
    end

    items = result.items
    local totalHits = result.totalHits or #items
    totalPagesCount = math.max(1, math.ceil(totalHits / perPage))
    if page > totalPagesCount then
      page = totalPagesCount
    end
    render()
    thumbs.enqueue(items)
  end)
end

local function applyItem(id)
  if applying then
    return
  end
  local item = findItem(id)
  if item == nil then
    return
  end

  selectedId = id
  applying = true
  render()

  apply.downloadAndApply(item, function(nextStatus, err)
    applying = false
    if nextStatus == nil then
      noctalia.notifyError(tr("title"), mapError(err))
      render()
      return
    end
    status = nextStatus
    noctalia.notify(tr("title"), tr("applied"))
    render()
  end)
end

local function attributionLine()
  if provider == "local" then
    if selectedId == "" then
      return tr("attribution.local_default")
    end
    local item = findItem(selectedId)
    local name = item and item.name or selectedId
    return string.format(tr("attribution.local_item"), name)
  end

  if provider == "wallhaven" then
    if selectedId == "" then
      return tr("attribution.wallhaven_default")
    end
    return string.format(tr("attribution.wallhaven_item"), selectedId)
  end

  if provider == "wallpaperengine" then
    if selectedId == "" then
      return tr("attribution.wallpaperengine_default")
    end
    local item = findItem(selectedId)
    local name = item and (item.title or item.name) or selectedId
    return string.format(tr("attribution.wallpaperengine_item"), name)
  end

  if selectedId == "" then
    return tr("attribution.pixabay_default")
  end
  local item = findItem(selectedId)
  local user = item and item.user or ""
  if user == "" then
    user = "Pixabay"
  end
  return string.format(tr("attribution.pixabay_item"), user)
end

local function statusLine()
  local mode = status and status.mode or "none"
  local source = status and status.source or ""
  if mode == "image" then
    if source ~= "" then
      return string.format(tr("status.image_from"), source)
    end
    return tr("status.image")
  end
  if mode == "video" then
    if source ~= "" then
      return string.format(tr("status.video_from"), source)
    end
    return tr("status.video")
  end
  if mode == "wallpaperengine" then
    local name = status and (status.name or status.id) or ""
    if name ~= "" then
      return string.format(tr("status.wallpaperengine_from"), name)
    end
    return tr("status.wallpaperengine")
  end
  return tr("status.none")
end

local function searchPlaceholder()
  if provider == "wallhaven" then
    return tr("search_placeholder_wallhaven")
  end
  if provider == "wallpaperengine" then
    return tr("search_placeholder_we")
  end
  if provider == "local" then
    return tr("search_placeholder_local")
  end
  return tr("search_placeholder_pixabay")
end

local function mediaTabs()
  return ui.row({ gap = 8, align = "center" }, {
    chips.chip(tr("tabs.images"), media == "image", "onTabImage", "tab_image"),
    chips.chip(tr("tabs.videos"), media == "video", "onTabVideo", "tab_video"),
  })
end

local function pixabayFilters()
  return ui.column({ gap = 10, align = "stretch" }, {
    mediaTabs(),
    ui.row({ gap = 10, align = "center" }, {
      chips.group(tr("filters.category"), ui.select({
        key = "pb_category",
        options = pixabay.CATEGORY_LABELS,
        selectedIndex = pbCategoryIndex,
        onChange = "onPbCategory",
        width = 160,
      })),
      chips.group(tr("filters.order"), ui.select({
        key = "pb_order",
        options = { tr("filters.order_popular"), tr("filters.order_latest") },
        selectedIndex = pbOrderIndex,
        onChange = "onPbOrder",
        width = 140,
      })),
      ui.button({
        key = "pb_editors",
        text = tr("filters.editors_choice"),
        variant = if pbEditorsChoice then "primary" else "outline",
        onClick = "onPbEditorsChoice",
      }),
    }),
  })
end

local function localFilters()
  local dirs = config.localDirectories()
  local dirLabel = if #dirs == 0
    then tr("local.no_dirs")
    else string.format(tr("local.dirs_count"), #dirs)
  return ui.column({ gap = 10, align = "stretch" }, {
    mediaTabs(),
    ui.row({ gap = 8, align = "center" }, {
      ui.label({ text = dirLabel, color = "on_surface_variant", flexGrow = 1 }),
      ui.button({
        text = tr("local.manage_dirs"),
        variant = "outline",
        onClick = "onOpenSettings",
      }),
    }),
  })
end

local function wallpaperEngineFilters()
  local typeLabels = {
    tr("wallpaperengine.type_all"),
    tr("wallpaperengine.type_scene"),
    tr("wallpaperengine.type_video"),
    tr("wallpaperengine.type_web"),
  }
  local countLabel = if weTotalInstalled > 0
    then string.format(tr("wallpaperengine.installed_count"), weTotalInstalled)
    else tr("wallpaperengine.no_installed")

  return ui.column({ gap = 10, align = "stretch" }, {
    ui.row({ gap = 12, align = "center" }, {
      chips.group(tr("wallpaperengine.type_filter"), ui.select({
        key = "we_type",
        options = typeLabels,
        selectedIndex = weTypeIndex,
        onChange = "onWeType",
        width = 140,
      })),
      ui.label({ text = countLabel, color = "on_surface_variant", flexGrow = 1 }),
      ui.button({
        text = tr("wallpaperengine.rescan"),
        variant = "outline",
        onClick = "onWeRescan",
      }),
    }),
  })
end

local function wallhavenFilters()
  local nsfwEnabled = config.hasWallhavenKey()
  return ui.column({ gap = 10, align = "stretch" }, {
    ui.row({ gap = 12, align = "center" }, {
      chips.group(tr("wallhaven.categories"), ui.row({ gap = 6, align = "center" }, {
        chips.chip(tr("wallhaven.category_general"), whGeneral, "onWhGeneral", "wh_cat_general"),
        chips.chip(tr("wallhaven.category_anime"), whAnime, "onWhAnime", "wh_cat_anime"),
        chips.chip(tr("wallhaven.category_people"), whPeople, "onWhPeople", "wh_cat_people"),
      })),
      chips.group(tr("wallhaven.purity"), ui.row({ gap = 6, align = "center" }, {
        chips.chip(tr("wallhaven.purity_sfw"), whSfw, "onWhSfw", "wh_purity_sfw"),
        chips.chip(tr("wallhaven.purity_sketchy"), whSketchy, "onWhSketchy", "wh_purity_sketchy"),
        chips.chip(tr("wallhaven.purity_nsfw"), whNsfw, "onWhNsfw", "wh_purity_nsfw", nsfwEnabled),
      })),
    }),
    ui.row({ gap = 10, align = "center" }, {
      chips.group(tr("wallhaven.sort_label"), ui.row({ gap = 4, align = "center" }, {
        ui.select({
          key = "wh_sort",
          options = whSortLabels(),
          selectedIndex = whSortIndex,
          onChange = "onWhSort",
          width = 160,
        }),
        ui.button({
          key = "wh_order",
          glyph = if whOrder == "desc" then "arrow-down" else "arrow-up",
          variant = "outline",
          tooltip = if whOrder == "desc" then tr("wallhaven.order_desc") else tr("wallhaven.order_asc"),
          onClick = "onWhToggleOrder",
        }),
      })),
      chips.group(tr("wallhaven.ratio_label"), ui.select({
        key = "wh_ratio",
        options = whRatioLabels(),
        selectedIndex = whRatioIndex,
        onChange = "onWhRatio",
        width = 140,
      })),
    }),
    ui.row({ gap = 8, align = "center" }, {
      chips.group(tr("wallhaven.resolution"), ui.row({ gap = 8, align = "center", flexGrow = 1 }, {
        ui.select({
          key = "wh_res_mode",
          options = { tr("wallhaven.resolution_atleast"), tr("wallhaven.resolution_exact") },
          selectedIndex = if whResolutionMode == "exact" then 1 else 0,
          onChange = "onWhResolutionMode",
          width = 140,
        }),
        ui.input({
          key = `wh_width_{whClearCounter}`,
          placeholder = tr("wallhaven.width"),
          value = whMinWidth,
          onChange = "onWhWidthChange",
          onSubmit = "onWhWidthSubmit",
          flexGrow = 1,
        }),
        ui.label({ text = "×", color = "on_surface_variant" }),
        ui.input({
          key = `wh_height_{whClearCounter}`,
          placeholder = tr("wallhaven.height"),
          value = whMinHeight,
          onChange = "onWhHeightChange",
          onSubmit = "onWhHeightSubmit",
          flexGrow = 1,
        }),
      })),
      ui.button({
        text = tr("wallhaven.clear_resolution"),
        variant = "destructive",
        onClick = "onWhClearResolution",
      }),
    }),
  })
end

render = function()
  local pageLabel = if applying then tr("applying") else string.format(tr("page_label"), page, totalPagesCount)

  panel.render(ui.column({ flexGrow = 1, gap = 12, align = "stretch" }, {
    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.label({ text = tr("title"), fontSize = 16, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
      ui.button({ glyph = "settings", tooltip = tr("open_settings"), onClick = "onOpenSettings" }),
      ui.button({ glyph = "close", onClick = "onClose" }),
    }),

    ui.row({ gap = 8, align = "center" }, {
      chips.chip(tr("providers.local"), provider == "local", "onProviderLocal", "provider_local"),
      chips.chip(tr("providers.pixabay"), provider == "pixabay", "onProviderPixabay", "provider_pixabay"),
      chips.chip(tr("providers.wallhaven"), provider == "wallhaven", "onProviderWallhaven", "provider_wallhaven"),
      chips.chip(tr("providers.wallpaperengine"), provider == "wallpaperengine", "onProviderWallpaperEngine", "provider_wallpaperengine"),
      ui.label({ text = statusLine(), color = "on_surface_variant", flexGrow = 1 }),
      ui.button({
        text = tr("actions.stop"),
        variant = "destructive",
        onClick = "onStop",
        enabled = status ~= nil and status.mode ~= nil and status.mode ~= "none",
      }),
    }),

    ui.row({ gap = 8, align = "center" }, {
      ui.input({
        key = `search_{provider}`,
        placeholder = searchPlaceholder(),
        value = query,
        flexGrow = 1,
        onChange = "onSearchChange",
        onSubmit = "onSearchSubmit",
      }),
      ui.button({ text = tr("search"), variant = "primary", onClick = "onSearch" }),
    }),

    if provider == "wallhaven" then
      wallhavenFilters()
    elseif provider == "local" then
      localFilters()
    elseif provider == "wallpaperengine" then
      wallpaperEngineFilters()
    else
      pixabayFilters(),

    ui.scroll({ flexGrow = 1, gap = 12 }, {
      grid.build(
        items,
        selectedId,
        loading,
        errorMessage,
        tr("empty"),
        tr("loading"),
        applyItem
      ),
    }),

    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.label({ text = attributionLine(), color = "on_surface_variant", flexGrow = 1, maxLines = 1 }),
      ui.row({ gap = 8, align = "center" }, {
        ui.button({
          glyph = "chevron-left",
          variant = "ghost",
          onClick = "onPrevPage",
          enabled = not loading and page > 1,
        }),
        ui.label({ text = pageLabel, color = "on_surface_variant" }),
        ui.button({
          glyph = "chevron-right",
          variant = "ghost",
          onClick = "onNextPage",
          enabled = not loading and page < totalPagesCount,
        }),
      }),
    }),
  }))
end

local function refetchFromPageOne()
  page = 1
  selectedId = ""
  fetch()
end

thumbs.setOnReady(function(_id, _path)
  render()
end)

noctalia.state.watch("status", function(value)
  if type(value) == "table" then
    status = value
    render()
  end
end)

function onOpen(_context)
  isOpen = true
  provider = config.defaultProvider()
  media = config.pixabayDefaultMedia()
  seedWallhavenFilters()
  thumbs.setSource(provider)
  paths.ensure(paths.cacheDir(), function()
    fetch()
  end)
end

function onProviderPixabay()
  setProvider("pixabay")
end

function onProviderWallhaven()
  setProvider("wallhaven")
end

function onProviderLocal()
  setProvider("local")
end

function onProviderWallpaperEngine()
  setProvider("wallpaperengine")
end

function onTabImage()
  setMedia("image")
end

function onTabVideo()
  setMedia("video")
end

function onSearchChange(value)
  query = value
end

function onSearchSubmit(value)
  query = value
  refetchFromPageOne()
end

function onSearch()
  refetchFromPageOne()
end

function onPbCategory(index, _text)
  pbCategoryIndex = tonumber(index) or 0
  refetchFromPageOne()
end

function onPbOrder(index, _text)
  pbOrderIndex = tonumber(index) or 0
  refetchFromPageOne()
end

function onPbEditorsChoice()
  pbEditorsChoice = not pbEditorsChoice
  refetchFromPageOne()
end

local function toggleExclusive(current, other1, other2)
  if current and not other1 and not other2 then
    return current
  end
  return not current
end

function onWhGeneral()
  local next = toggleExclusive(whGeneral, whAnime, whPeople)
  if next == whGeneral then
    return
  end
  whGeneral = next
  refetchFromPageOne()
end

function onWhAnime()
  local next = toggleExclusive(whAnime, whGeneral, whPeople)
  if next == whAnime then
    return
  end
  whAnime = next
  refetchFromPageOne()
end

function onWhPeople()
  local next = toggleExclusive(whPeople, whGeneral, whAnime)
  if next == whPeople then
    return
  end
  whPeople = next
  refetchFromPageOne()
end

function onWhSfw()
  local next = toggleExclusive(whSfw, whSketchy, whNsfw)
  if next == whSfw then
    return
  end
  whSfw = next
  refetchFromPageOne()
end

function onWhSketchy()
  local next = toggleExclusive(whSketchy, whSfw, whNsfw)
  if next == whSketchy then
    return
  end
  whSketchy = next
  refetchFromPageOne()
end

function onWhNsfw()
  if not config.hasWallhavenKey() then
    return
  end
  local next = toggleExclusive(whNsfw, whSfw, whSketchy)
  if next == whNsfw then
    return
  end
  whNsfw = next
  refetchFromPageOne()
end

function onWhSort(index, _text)
  whSortIndex = tonumber(index) or 0
  refetchFromPageOne()
end

function onWhToggleOrder()
  whOrder = if whOrder == "desc" then "asc" else "desc"
  refetchFromPageOne()
end

function onWhRatio(index, _text)
  whRatioIndex = tonumber(index) or 0
  refetchFromPageOne()
end

function onWhResolutionMode(index, _text)
  whResolutionMode = if (tonumber(index) or 0) == 1 then "exact" else "atleast"
  refetchFromPageOne()
end

function onWhWidthChange(value)
  whMinWidth = noctalia.string.trim(value)
end

function onWhHeightChange(value)
  whMinHeight = noctalia.string.trim(value)
end

function onWhWidthSubmit(value)
  whMinWidth = noctalia.string.trim(value)
  refetchFromPageOne()
end

function onWhHeightSubmit(value)
  whMinHeight = noctalia.string.trim(value)
  refetchFromPageOne()
end

function onWhClearResolution()
  if whResolutionMode == "atleast" and whMinWidth == "" and whMinHeight == "" then
    return
  end
  whResolutionMode = "atleast"
  whMinWidth = ""
  whMinHeight = ""
  whClearCounter += 1
  refetchFromPageOne()
end

function onWeType(index, _text)
  weTypeIndex = tonumber(index) or 0
  refetchFromPageOne()
end

function onWeRescan()
  we.clearCache()
  refetchFromPageOne()
end

function onPrevPage()
  if page > 1 then
    page -= 1
    if provider == "local" and #allLocalItems > 0 then
      items, totalPagesCount, page = local_library.pageSlice(allLocalItems, page, perPage)
      selectedId = ""
      render()
      thumbs.enqueue(items)
    else
      fetch()
    end
  end
end

function onNextPage()
  if page < totalPagesCount then
    page += 1
    if provider == "local" and #allLocalItems > 0 then
      items, totalPagesCount, page = local_library.pageSlice(allLocalItems, page, perPage)
      selectedId = ""
      render()
      thumbs.enqueue(items)
    else
      fetch()
    end
  end
end

function onStop()
  status = apply.stop()
  noctalia.notify(tr("title"), tr("stopped"))
  render()
end

function onOpenSettings()
  noctalia.openSettings()
end

local function discardSessionCache()
  if not isOpen then
    return
  end
  isOpen = false

  currentRequestId += 1
  items = {}
  allLocalItems = {}
  selectedId = ""
  loading = false
  errorMessage = ""
  applying = false
  weTotalInstalled = 0

  thumbs.wipe()
  session_cache.wipeAll()
  we.clearCache()
  pixabay.cancelInFlight()
  wallhaven.cancelInFlight()
end

function onClose()
  panel.close()
  discardSessionCache()
end

function onIpc(event, _payload)
  if event == "open" or event == "toggle" then
    noctalia.togglePanel(PLUGIN_ID .. ":hub")
  elseif event == "close" then
    onClose()
  elseif event == "refresh" then
    fetch()
  elseif event == "stop" then
    onStop()
  elseif event == "pixabay" then
    setProvider("pixabay")
  elseif event == "wallhaven" then
    setProvider("wallhaven")
  elseif event == "local" then
    setProvider("local")
  elseif event == "wallpaperengine" then
    setProvider("wallpaperengine")
  end
end
