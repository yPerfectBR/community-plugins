local ui_chips = {}

function ui_chips.chip(label, active, onClick, key, enabled)
  return ui.button({
    key = key,
    text = label,
    variant = if active then "primary" else "outline",
    onClick = onClick,
    enabled = if enabled == nil then true else enabled,
  })
end

function ui_chips.group(title, content)
  return ui.row({ gap = 6, align = "center" }, {
    ui.label({
      text = title,
      fontSize = 12,
      color = "on_surface_variant",
    }),
    content,
  })
end

return ui_chips
