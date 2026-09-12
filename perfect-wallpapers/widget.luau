--!nonstrict
local configuredGlyph = noctalia.getConfig("glyph")

local function render()
  local glyph = configuredGlyph
  if type(glyph) ~= "string" or glyph == "" then
    glyph = "photo"
  end

  local status = noctalia.state.get("status")
  local tooltip = noctalia.tr("title")

  if type(status) == "table" and status.mode and status.mode ~= "none" then
    if status.mode == "video" or status.mode == "wallpaperengine" then
      glyph = "movie"
    end
    local key = "status." .. tostring(status.mode)
    tooltip = noctalia.tr("title") .. " — " .. noctalia.tr(key)
  end

  barWidget.setGlyph(glyph)
  barWidget.setTooltip(tooltip)
end

function update()
  render()
end

function onClick()
  noctalia.togglePanel("perfect/perfect-wallpapers:hub")
end

function onIpc(event, _payload)
  if event == "open" or event == "toggle" then
    noctalia.togglePanel("perfect/perfect-wallpapers:hub")
  end
end

noctalia.state.watch("status", function(_val)
  render()
end)

render()
