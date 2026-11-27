--!nonstrict
-- Aerox 5 Wireless bar widget. Shows the battery level, colored by band.
-- Left click toggles the panel. No tooltip.

local battery = require("./lib/battery.luau")

local GLYPHS = {
  high = "mouse",
  mid = "mouse",
  low = "mouse",
  charging = "battery-charging",
  asleep = "moon",
  unknown = "mouse-off",
}

-- Noctalia's theme has no green or yellow role, so the bands use roles that
-- exist in every palette: plain when full, tertiary when getting low, error
-- when it needs charging.
local COLORS = {
  high = "on_surface",
  mid = "tertiary",
  low = "error",
  charging = "primary",
  asleep = "on_surface_variant",
  unknown = "on_surface_variant",
}

local reading = noctalia.state.get("aerox5.battery")

local function render()
  local b = reading or { state = "error", charging = false }
  local band = battery.band(b)
  local color = COLORS[band]
  local glyph = ui.glyph({ name = GLYPHS[band], color = color })
  if barWidget.isVertical() then
    barWidget.render(glyph)
    return
  end
  local text = "?"
  if band ~= "unknown" and b.level ~= nil then
    text = `{b.level}%`
  end
  barWidget.render(ui.row({ gap = 4, align = "center" }, {
    glyph,
    ui.label({ text = text, color = color, maxLines = 1 }),
  }))
end

noctalia.state.watch("aerox5.battery", function(value)
  reading = value
  render()
end)

function update()
  render()
end

function onClick()
  noctalia.togglePanel("kingrecycle/aerox5-wireless:panel")
end

render()
