--!nonstrict
-- Desktop Widget for Perfect Wallpapers
-- Displays today's Daily Wallpaper title, credit, explanation and date on the desktop.

local function tr(key, args)
  return noctalia.tr(key, args)
end

local WRAP = 280

local function render()
  local daily = noctalia.state.get("daily_info")
  local status = noctalia.state.get("status")

  local rows = {}

  -- Header
  local subsource = (type(daily) == "table" and daily.subsource == "nasa") and "NASA APOD" or "Bing Daily"
  local badgeColor = (type(daily) == "table" and daily.subsource == "nasa") and "primary" or "secondary"

  table.insert(
    rows,
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "photo", size = 16, color = badgeColor }),
      ui.label({
        text = subsource,
        fontSize = 11,
        fontWeight = "bold",
        color = "on_surface_variant",
      }),
      (type(daily) == "table" and daily.date and daily.date ~= "") and ui.label({
        text = daily.date,
        fontSize = 10,
        opacity = 0.6,
        color = "on_surface_variant",
      }) or nil,
    })
  )

  if type(daily) == "table" and type(daily.title) == "string" and daily.title ~= "" then
    -- Title
    table.insert(
      rows,
      ui.label({
        text = daily.title,
        fontSize = 13,
        fontWeight = "bold",
        maxWidth = WRAP,
        maxLines = 2,
      })
    )

    -- Credit / Copyright
    if daily.copyright and daily.copyright ~= "" then
      table.insert(
        rows,
        ui.label({
          text = "© " .. daily.copyright,
          fontSize = 10,
          opacity = 0.75,
          maxWidth = WRAP,
          maxLines = 1,
        })
      )
    end

    -- Explanation / Summary if present
    if daily.explanation and daily.explanation ~= "" then
      table.insert(
        rows,
        ui.label({
          text = daily.explanation,
          fontSize = 10,
          opacity = 0.65,
          maxWidth = WRAP,
          maxLines = 3,
        })
      )
    end
  else
    -- Fallback when active wallpaper is not daily, show current active wallpaper info or prompt
    local activeTitle = (type(status) == "table" and (status.title or status.id or status.path)) or ""
    if activeTitle ~= "" then
      table.insert(
        rows,
        ui.label({
          text = tr("widget.active_prefix") .. ": " .. tostring(activeTitle),
          fontSize = 11,
          opacity = 0.8,
          maxWidth = WRAP,
          maxLines = 2,
        })
      )
    else
      table.insert(
        rows,
        ui.label({
          text = tr("widget.no_active"),
          fontSize = 11,
          opacity = 0.6,
          maxWidth = WRAP,
        })
      )
    end
  end

  desktopWidget.render(ui.column({
    gap = 4,
    padding = 10,
  }, rows))
end

noctalia.state.watch("daily_info", render)
noctalia.state.watch("status", render)
render()
