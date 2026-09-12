local thumbs = require("../lib/thumbs.luau")

local grid = {}

local PANEL_WIDTH = 960
local PANEL_PADDING = 28
local COLUMNS = 4
local COLUMN_GAP = 12
local TILE_RADIUS = 12
local LABEL_FONT = 11

local function columnWidth()
  local gridWidth = PANEL_WIDTH - PANEL_PADDING
  return math.floor((gridWidth - COLUMN_GAP * (COLUMNS - 1)) / COLUMNS)
end

local function tileSize()
  local width = columnWidth()
  local height = math.floor(width * 9 / 16)
  return width, height
end

local function preview(item, selected, onPick)
  local w, h = tileSize()
  local border = if selected then "primary" else "outline"
  local borderWidth = if selected then 3 else 1
  local thumb = thumbs.get(item.id)
  local click = function()
    onPick(item.id)
  end

  if thumb ~= nil then
    return ui.image({
      width = w,
      height = h,
      path = thumb,
      fit = "cover",
      radius = TILE_RADIUS,
      border = border,
      borderWidth = borderWidth,
      onClick = click,
    })
  end

  return ui.box({
    width = w,
    height = h,
    fill = "surface_variant",
    radius = TILE_RADIUS,
    border = border,
    borderWidth = borderWidth,
    onClick = click,
  })
end

function grid.build(items, selectedId, loading, errorMessage, emptyText, loadingText, onPick)
  if loading then
    return ui.label({ text = loadingText, color = "on_surface_variant" })
  end
  if errorMessage ~= nil and errorMessage ~= "" then
    return ui.label({ text = errorMessage, color = "error" })
  end
  if #items == 0 then
    return ui.label({ text = emptyText, color = "on_surface_variant" })
  end

  local rows = {}
  local row = {}
  local w = columnWidth()

  for index, item in ipairs(items) do
    local caption = item.resolution
    if item.kind == "video" and (item.duration or 0) > 0 then
      caption = `{item.resolution} · {item.duration}s`
    end

    table.insert(row, ui.column({
      gap = 4,
      key = item.id,
      flexGrow = 1,
      align = "center",
    }, {
      preview(item, selectedId == item.id, onPick),
      ui.label({
        text = caption,
        fontSize = LABEL_FONT,
        color = "on_surface_variant",
        maxLines = 1,
        maxWidth = w,
        textAlign = "center",
      }),
    }))

    if #row == COLUMNS or index == #items then
      table.insert(rows, ui.row({ gap = COLUMN_GAP, align = "stretch" }, row))
      row = {}
    end
  end

  return ui.column({ gap = 12, align = "stretch" }, rows)
end

return grid
