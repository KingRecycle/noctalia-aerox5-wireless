--!nonstrict
-- Aerox 5 Wireless panel. Battery readout, then every mouse control.
-- Controls send aerox5.cmd to the service, which applies them with rivalcfg.
-- Selects apply at once. Sliders and color fields apply about 1 s after the
-- last change (colors also on Enter). Controls are off unless the mouse
-- answered the last battery check.

local battery = require("./lib/battery.luau")
local mouse = require("./lib/mouse.luau")
local draftsLib = require("./lib/drafts.luau")

local PANEL_ID = "kingrecycle/aerox5-wireless:panel"
local SLIDER_DELAY_MS = 1000
local LABEL_WIDTH = 120

local closeButton = true
local reading = noctalia.state.get("aerox5.battery")
local settings = noctalia.state.get("aerox5.settings") or mouse.defaults()
local busy = noctalia.state.get("aerox5.busy") == true
-- Values shown while a change waits for the service, per setting.
local drafts = draftsLib.new()

local BAND_FILL = {
  high = "primary",
  mid = "tertiary",
  low = "error",
  charging = "primary",
  asleep = "on_surface_variant",
  unknown = "on_surface_variant",
}

local function tr(key, subst)
  return noctalia.tr(key, subst)
end

local function send(key, value, delayMs)
  noctalia.state.set("aerox5.cmd", { op = "set", key = key, value = value, delay_ms = delayMs })
end

local function ready()
  return reading ~= nil and reading.state == "ok"
end

local function current(key)
  local d = drafts:get(key)
  if d ~= nil then
    return d
  end
  return settings[key]
end

local function ageText()
  if reading == nil or reading.checked_at == nil then
    return nil
  end
  local s = math.max(0, math.floor((noctalia.nowMs() - reading.checked_at) / 1000))
  if s < 60 then
    return tr("panel.status.age_seconds", { n = tostring(s) })
  end
  return tr("panel.status.age_minutes", { n = tostring(math.floor(s / 60)) })
end

local function statusText()
  if reading == nil then
    return tr("panel.status.checking")
  end
  local text
  if reading.state == "ok" then
    text = reading.charging and tr("panel.status.charging") or tr("panel.status.discharging")
  elseif reading.state == "asleep" then
    text = reading.level and tr("panel.status.asleep", { level = tostring(reading.level) })
      or tr("panel.status.asleep_unknown")
  elseif reading.state == "no_dongle" then
    text = tr("panel.status.no_dongle")
  else
    text = tr("panel.status.error")
  end
  local age = ageText()
  return age and `{text} · {age}` or text
end

local function disabledText()
  if reading == nil or reading.state == "ok" then
    return nil
  end
  return tr("panel.disabled." .. reading.state)
end

-- A nil in the middle of an array literal would cut the siblings after it.
local function compact(list)
  local out = {}
  for i = 1, table.maxn(list) do
    if list[i] then
      table.insert(out, list[i])
    end
  end
  return out
end

local function field(label, control)
  return ui.row({ gap = 8, align = "center" }, {
    -- Labels ignore width, so a fixed-width row keeps the controls aligned.
    ui.row({ width = LABEL_WIDTH, align = "center" }, {
      ui.label({ text = label, color = "on_surface_variant" }),
    }),
    control,
  })
end

local function sectionTitle(text)
  return ui.label({ text = text, fontWeight = "bold", fontSize = 13, color = "primary" })
end

local function selectField(key, label, options, values, extra)
  local index = table.find(values, current(key)) or 1
  local props = {
    key = key,
    options = options,
    selectedIndex = index - 1,
    controlSize = "sm",
    flexGrow = 1,
    enabled = ready(),
    onChange = function(value)
      local picked = values[(tonumber(value) or 0) + 1]
      if picked ~= nil and picked ~= current(key) then
        drafts:set(key, picked)
        send(key, picked, 0)
        render()
      end
    end,
  }
  for k, v in extra or {} do
    props[k] = v
  end
  return field(label, ui.select(props))
end

local function sliderField(key, label, max, step, format)
  local value = current(key)
  local valueText = value == 0 and tr("panel.off") or format(value)
  return field(label, ui.row({ gap = 8, align = "center", flexGrow = 1 }, {
    ui.slider({
      min = 0,
      max = max,
      step = step,
      value = value,
      controlSize = "sm",
      flexGrow = 1,
      enabled = ready(),
      onChange = function(v)
        local n = math.floor((tonumber(v) or 0) + 0.5)
        if n ~= current(key) then
          drafts:set(key, n)
          send(key, n, SLIDER_DELAY_MS)
          render()
        end
      end,
    }),
    ui.row({ width = 56, justify = "end" }, { ui.label({ text = valueText }) }),
  }))
end

-- Palette roles offered in the color dropdowns. Picking one sends the
-- palette's current hex once; the mouse doesn't follow later theme changes.
local THEME_ROLES = { "primary", "secondary", "tertiary", "error" }
-- Set when Custom is picked, so the dropdown shows it until a value is typed.
local customPicked = {}

local function themeHexes()
  local out = {}
  for _, role in THEME_ROLES do
    table.insert(out, mouse.normalizeColor(noctalia.getColor(role) or "", false) or "")
  end
  return out
end

-- A dropdown of presets, palette colors and Custom, next to a text field for
-- any name or hex. Both send the same setting.
local function colorField(key, label, allowOff, lockedOff)
  local value = current(key) or ""
  local hexes = themeHexes()

  -- Dropdown entries, each with the value it sends (nil for Custom).
  local labels, values = {}, {}
  if allowOff then
    table.insert(labels, tr("panel.color.off"))
    table.insert(values, "off")
  end
  for _, p in mouse.COLOR_PRESETS do
    table.insert(labels, tr("panel.color." .. p.id))
    table.insert(values, p.hex)
  end
  for i, role in THEME_ROLES do
    table.insert(labels, tr("panel.color.theme", { role = tr("panel.color.role." .. role) }))
    table.insert(values, hexes[i])
  end
  table.insert(labels, tr("panel.color.custom"))
  local customIndex = #labels

  local offset = allowOff and 1 or 0
  local selected = customIndex
  if not customPicked[key] then
    local kind, i = mouse.colorChoice(value, allowOff, hexes)
    if kind == "off" then
      selected = 1
    elseif kind == "preset" then
      selected = offset + i
    elseif kind == "theme" then
      selected = offset + #mouse.COLOR_PRESETS + i
    end
  end

  local function sendColor(v, delayMs)
    local text = noctalia.string.trim(v or "")
    drafts:set(key, v)
    -- An empty field means "not chosen yet", so there's nothing to send.
    if text ~= "" then
      send(key, text, delayMs)
    end
  end

  return field(label, ui.row({ gap = 6, align = "center", flexGrow = 1 }, {
    ui.select({
      key = key .. "-choice",
      options = labels,
      selectedIndex = selected - 1,
      controlSize = "sm",
      flexGrow = 1,
      enabled = ready() and not lockedOff,
      onChange = function(index)
        local i = (tonumber(index) or 0) + 1
        if i == customIndex then
          customPicked[key] = true
          render()
          return
        end
        local picked = values[i]
        customPicked[key] = nil
        if picked ~= nil and picked ~= mouse.normalizeColor(current(key) or "", allowOff) then
          sendColor(picked, 0)
          drafts:remount(key)
          render()
        end
      end,
    }),
    ui.input({
      key = `{key}-{drafts:generation(key)}`,
      value = value,
      placeholder = tr("panel.color.placeholder"),
      controlSize = "sm",
      width = 96,
      enabled = ready() and not lockedOff,
      onChange = function(v)
        customPicked[key] = nil
        sendColor(v, SLIDER_DELAY_MS)
      end,
      onSubmit = function()
        local v = drafts:get(key)
        if v ~= nil then
          sendColor(v, 0)
        end
      end,
    }),
  }))
end

local function header()
  return ui.row({ gap = 8, align = "center" }, compact({
    ui.glyph({ name = "mouse", size = 20, color = "primary" }),
    ui.label({ text = tr("title"), fontSize = 16, fontWeight = "bold", flexGrow = 1 }),
    busy and ui.label({ text = tr("panel.applying"), fontSize = 11, color = "on_surface_variant" }) or false,
    ui.button({
      glyph = "refresh",
      variant = "ghost",
      controlSize = "sm",
      tooltip = tr("panel.refresh"),
      onClick = function()
        noctalia.state.set("aerox5.cmd", { op = "refresh" })
      end,
    }),
    ui.button({
      glyph = "settings",
      variant = "ghost",
      controlSize = "sm",
      tooltip = tr("panel.settings"),
      onClick = function()
        noctalia.openSettings()
      end,
    }),
    closeButton and ui.button({
      glyph = "close",
      variant = "ghost",
      controlSize = "sm",
      onClick = function()
        panel.close()
      end,
    }) or false,
  }))
end

local function batteryBlock()
  local b = reading or { state = "error", charging = false }
  local band = battery.band(b)
  local level = b.level
  return ui.column({ gap = 6, padding = 10, radius = 10, fill = "surface_container/0.5" }, {
    ui.label({
      text = level and `{level}%` or "?",
      fontSize = 24,
      fontWeight = "bold",
      color = BAND_FILL[band],
    }),
    ui.progress({
      progress = level and math.clamp(level / 100, 0, 1) or 0,
      fill = BAND_FILL[band],
      track = "on_surface/0.12",
      height = 6,
      radius = 3,
    }),
    ui.label({ text = statusText(), fontSize = 11, color = "on_surface_variant" }),
  })
end

local function labelsFor(values, format)
  local out = {}
  for _, v in values do
    table.insert(out, format(v))
  end
  return out
end

function render()
  local locked = settings.fixed_dpi ~= ""
  -- While lighting is off the saved colors aren't on the mouse, so they wait.
  local lightingOff = current("default_lighting") == "off"
  local notice = disabledText()

  local rows = compact({
    header(),
    batteryBlock(),
    notice and ui.label({ text = notice, fontSize = 12, color = "error" }) or false,

    sectionTitle(tr("panel.section.performance")),
    selectField("presets", tr("panel.presets.label"), labelsFor(mouse.PRESETS, function(v)
      return tr("panel.presets.options." .. v)
    end), mouse.PRESETS,
      { enabled = ready() and not locked }),
    locked and ui.label({ text = tr("panel.presets.locked"), fontSize = 11, color = "on_surface_variant" }) or false,
    selectField("fixed_dpi", tr("panel.fixed_dpi.label"), labelsFor(mouse.FIXED_DPI, function(v)
      return v == "" and tr("panel.fixed_dpi.off") or `{v} DPI`
    end), mouse.FIXED_DPI),
    selectField("polling_rate", tr("panel.polling_rate.label"), labelsFor(mouse.POLLING, function(v)
      return `{v} Hz`
    end), mouse.POLLING),

    sectionTitle(tr("panel.section.power")),
    sliderField("sleep_timer", tr("panel.sleep_timer.label"), mouse.SLEEP_MAX, 1, function(v)
      return tr("panel.minutes", { n = tostring(v) })
    end),
    sliderField("dim_timer", tr("panel.dim_timer.label"), mouse.DIM_MAX, 10, function(v)
      return tr("panel.seconds", { n = tostring(v) })
    end),

    sectionTitle(tr("panel.section.lighting")),
    selectField("default_lighting", tr("panel.default_lighting.label"), labelsFor(mouse.LIGHTING, function(v)
      return tr("panel.default_lighting.options." .. v)
    end), mouse.LIGHTING),
    lightingOff and ui.label({ text = tr("panel.lighting_off"), fontSize = 11, color = "on_surface_variant" }) or false,
    selectField("rainbow", tr("panel.rainbow.label"), { tr("panel.rainbow.options.off"), tr("panel.rainbow.options.on") }, { false, true },
      { enabled = ready() and not lightingOff }),
    colorField("top_color", tr("panel.top_color.label"), false, lightingOff),
    colorField("middle_color", tr("panel.middle_color.label"), false, lightingOff),
    colorField("bottom_color", tr("panel.bottom_color.label"), false, lightingOff),
    colorField("reactive_color", tr("panel.reactive_color.label"), true, lightingOff),
  })

  panel.render(ui.scroll({ flexGrow = 1 }, {
    ui.column({ gap = 10, padding = 12 }, rows),
  }))
end

function update()
  render()
end

function onOpen(_context)
  closeButton = noctalia.getSetting("shell.show_close_buttons") ~= false
  drafts:reset()
  panel.setWantsSecondTicks(true)
  render()
end

noctalia.state.watch("aerox5.battery", function(value)
  reading = value
  render()
end)

noctalia.state.watch("aerox5.settings", function(value)
  if type(value) == "table" then
    settings = value
  end
  render()
end)

noctalia.state.watch("aerox5.applied", function(event)
  if type(event) == "table" and type(event.key) == "string" then
    drafts:applied(event.key, event.value, event.ok == true)
    render()
  end
end)

noctalia.state.watch("aerox5.busy", function(value)
  busy = value == true
  render()
end)

render()
