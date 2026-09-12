--!nonstrict

local function render()
  local status = noctalia.state.get("status")
  local isActive = type(status) == "table" and status.mode ~= nil and status.mode ~= "none"

  shortcut.setLabel(noctalia.tr("title"))
  shortcut.setIcon("photo")
  shortcut.setActive(isActive)
  shortcut.setEnabled(true)
end

function onClick()
  noctalia.togglePanel("perfect/perfect-wallpapers:hub")
end

noctalia.state.watch("status", function(_val)
  render()
end)

render()
