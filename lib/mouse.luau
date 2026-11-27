--!strict
-- Aerox 5 settings as the plugin stores them, and the rivalcfg arguments for
-- changing one of them. No dependencies, so the luau CLI can test it.

export type Settings = {
	presets: string,
	fixed_dpi: string,
	polling_rate: string,
	sleep_timer: number,
	dim_timer: number,
	top_color: string,
	middle_color: string,
	bottom_color: string,
	reactive_color: string,
	lighting: string,
	reactive: boolean,
}

local M = {}

-- rivalcfg's default list comes first.
M.PRESETS = {
	"400, 800, 1200, 2400, 3200",
	"400, 800, 1600",
	"800, 1600, 3200",
	"1600, 3200, 6400",
	"800, 1200, 1600, 2400, 3200",
}
-- "" means fixed DPI is off and the preset list is in use.
M.FIXED_DPI = { "", "400", "800", "1200", "1600", "2400", "3200", "6400" }
M.POLLING = { "125", "250", "500", "1000" }
-- Lighting modes: LEDs dark, dark with a flash on each click, the three zone
-- colors, or the rainbow cycle. In zones and rainbow, whether clicks flash
-- is a separate on/off.
M.LIGHTING = { "off", "reactive", "zones", "rainbow" }

-- Preset LED colors for the panel's dropdowns. Sent as hex, so they don't
-- depend on rivalcfg's list of color names. aliases are names that show as
-- the same preset when typed or stored.
M.COLOR_PRESETS = {
	{ id = "red", hex = "#ff0000", aliases = { "red" } },
	{ id = "green", hex = "#00ff00", aliases = { "lime" } },
	{ id = "blue", hex = "#0000ff", aliases = { "blue" } },
	{ id = "white", hex = "#ffffff", aliases = { "white" } },
	{ id = "yellow", hex = "#ffff00", aliases = { "yellow" } },
	{ id = "cyan", hex = "#00ffff", aliases = { "cyan", "aqua" } },
	{ id = "magenta", hex = "#ff00ff", aliases = { "magenta", "fuchsia" } },
	{ id = "orange", hex = "#ff8000", aliases = {} },
}

M.SLEEP_MAX = 20 -- minutes
M.DIM_MAX = 1200 -- seconds

-- rivalcfg's zone colors, sent when rainbow turns off and a zone was never set.
local ZONE_DEFAULTS: { [string]: string } = { top_color = "red", middle_color = "lime", bottom_color = "blue" }
local ZONE_FLAGS: { [string]: string } = { top_color = "--top-color", middle_color = "--middle-color", bottom_color = "--bottom-color" }
local ZONES = { "top_color", "middle_color", "bottom_color" }

function M.defaults(): Settings
	return {
		presets = M.PRESETS[1],
		fixed_dpi = "",
		polling_rate = "1000",
		sleep_timer = 5,
		dim_timer = 30,
		top_color = "",
		middle_color = "",
		bottom_color = "",
		reactive_color = "",
		lighting = "rainbow",
		reactive = false,
	}
end

local function oneOf(list: { string }, v: any): boolean
	return type(v) == "string" and table.find(list, v) ~= nil
end

local function intIn(v: any, lo: number, hi: number): boolean
	return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi
end

local function isHex(s: string): boolean
	local digits = string.match(s, "^#?(%x+)$")
	return digits ~= nil and (#digits == 3 or #digits == 6)
end

-- Trims and lowercases. Accepts #rgb, #rrggbb, rgb, rrggbb, or a color name
-- (rivalcfg checks names itself). "off" only when allowOff is set.
function M.normalizeColor(s: string, allowOff: boolean): string?
	if type(s) ~= "string" then
		return nil
	end
	local c = string.lower((string.gsub(s, "^%s*(.-)%s*$", "%1")))
	if c == "off" then
		return if allowOff then c else nil
	end
	if isHex(c) or string.match(c, "^%a+$") then
		return c
	end
	return nil
end

local function copy(s: Settings): Settings
	local c = table.clone(s)
	return c
end

-- Appends the three zone colors, using rivalcfg's defaults for any never set,
-- and stores the values sent.
local function appendZones(s: Settings, new: Settings, args: { string })
	for _, zone in ZONES do
		local c = (s :: any)[zone]
		if c == "" then
			c = ZONE_DEFAULTS[zone]
		end
		(new :: any)[zone] = c
		table.insert(args, ZONE_FLAGS[zone])
		table.insert(args, c)
	end
end

local DARK = "#000000"
-- Click flash color when the reactive switch goes on before a color was picked.
local REACTIVE_DEFAULT = "#ffffff"

-- rivalcfg's startup lighting for a mode. -d only takes effect at the next
-- power-on, so lightingArgs also sends what the LEDs should show now.
local function startup(s: Settings): string
	-- Startup "off" still flashes the reactive color on clicks (seen on the
	-- Aerox 5), which is exactly reactive-only.
	if s.lighting == "off" or s.lighting == "reactive" then
		return "off"
	elseif s.lighting == "rainbow" then
		return if s.reactive then "reactive-rainbow" else "rainbow"
	end
	return "reactive"
end

local function flash(s: Settings): string
	local wanted = s.lighting == "reactive" or (s.lighting ~= "off" and s.reactive)
	if wanted and s.reactive_color ~= "" then
		return s.reactive_color
	end
	return "off"
end

-- Everything the mouse needs to show s's lighting now and after a restart.
-- Zone colors that were never set get rivalcfg's defaults, stored in new.
local function lightingArgs(s: Settings, new: Settings): { string }
	local args = { "-d", startup(s), "-a", flash(s) }
	if s.lighting == "off" or s.lighting == "reactive" then
		for _, zone in ZONES do
			table.insert(args, ZONE_FLAGS[zone])
			table.insert(args, DARK)
		end
	elseif s.lighting == "rainbow" then
		table.insert(args, "-e")
	else
		appendZones(s, new, args)
	end
	return args
end

-- rivalcfg says setting a color turns the rainbow off and doesn't say which
-- colors count. In rainbow mode, re-send -e with any reactive change. rivalcfg
-- applies -e after -a whatever the argument order.
local function keepRainbow(s: Settings, args: { string }): { string }
	if s.lighting == "rainbow" then
		table.insert(args, "-e")
	end
	return args
end

-- Why a setting can't change in the current lighting, or nil if it can.
local function lightingLock(s: Settings, key: string): string?
	local isZone = ZONE_FLAGS[key] ~= nil
	if s.lighting == "off" and (isZone or key == "reactive" or key == "reactive_color") then
		return "lighting_off"
	elseif isZone and s.lighting ~= "zones" then
		return "zones_only"
	elseif key == "reactive" and s.lighting == "reactive" then
		return "reactive_mode"
	elseif key == "reactive_color" and not s.reactive and s.lighting ~= "reactive" then
		return "reactive_off"
	end
	return nil
end

local function fixedArg(dpi: string): string
	return table.concat({ dpi, dpi, dpi, dpi, dpi }, ", ")
end

-- Maps the old fields (rivalcfg's startup lighting, the rainbow effect flag
-- and a reactive color that could be "off") to a mode and the reactive
-- on/off. The rainbow flag held what the LEDs showed, so it wins.
-- zonesSet: a zone color was ever applied. Without one, the mouse still runs
-- rivalcfg's factory rainbow unless startup lighting was off or reactive.
-- legacy: the QML plugin sent "-d off" with the reactive color, which flashes
-- on clicks. The interim Luau build sent "-a off" with off.
local function fromOldLighting(
	defaultLighting: any,
	rainbow: any,
	reactiveColor: any,
	zonesSet: boolean,
	legacy: boolean
): (string?, boolean, string)
	local c = M.normalizeColor(reactiveColor, true)
	local hasFlash = c ~= nil and c ~= "off"
	local lighting: string? = nil
	if defaultLighting == "off" then
		lighting = if legacy and hasFlash then "reactive" else "off"
	elseif rainbow == true then
		lighting = "rainbow"
	elseif not zonesSet and (defaultLighting == "rainbow" or defaultLighting == "reactive-rainbow") then
		lighting = "rainbow"
	elseif defaultLighting ~= nil or rainbow ~= nil then
		lighting = "zones"
	end
	if not hasFlash then
		return lighting, false, ""
	end
	return lighting, true, c :: string
end

local function anyZoneSet(s: Settings): boolean
	return s.top_color ~= "" or s.middle_color ~= "" or s.bottom_color ~= ""
end

-- Reads the QML plugin's settings.json table. Values that don't validate fall
-- back to defaults. Returns the settings and the plugin-level values to carry.
function M.fromLegacy(t: { [string]: any }): (Settings, { poll_interval: number?, rivalcfg_path: string? })
	local s = M.defaults()
	if oneOf(M.PRESETS, t.sensitivity) then
		s.presets = t.sensitivity
	end
	if oneOf(M.FIXED_DPI, t.fixedDpi) then
		s.fixed_dpi = t.fixedDpi
	end
	if oneOf(M.POLLING, t.pollingRate) then
		s.polling_rate = t.pollingRate
	end
	if intIn(t.sleepTimer, 0, M.SLEEP_MAX) then
		s.sleep_timer = t.sleepTimer
	end
	if intIn(t.dimTimer, 0, M.DIM_MAX) then
		s.dim_timer = t.dimTimer
	end
	for _, zone in ZONES do
		local legacyKey = string.gsub(zone, "_color", "Color")
		local c = M.normalizeColor(t[legacyKey], false)
		if c then
			(s :: any)[zone] = c
		end
	end
	local lighting, reactive, reactiveColor = fromOldLighting(t.defaultLighting, t.rainbowEffect, t.reactiveColor, anyZoneSet(s), true)
	s.lighting, s.reactive, s.reactive_color = lighting or s.lighting, reactive, reactiveColor

	local extras: { poll_interval: number?, rivalcfg_path: string? } = {}
	if intIn(t.pollInterval, 30, 300) then
		extras.poll_interval = t.pollInterval
	end
	if type(t.rivalcfgPath) == "string" and t.rivalcfgPath ~= "" then
		extras.rivalcfg_path = t.rivalcfgPath
	end
	return s, extras
end

-- Which dropdown entry a color value matches: "off", a preset index, an
-- index into themeHexes (the palette colors, lowercase #rrggbb), or "custom".
-- Presets win over an equal theme color.
function M.colorChoice(value: string, allowOff: boolean, themeHexes: { string }): (string, number?)
	local c = M.normalizeColor(value, allowOff)
	if c == nil then
		return "custom", nil
	elseif c == "off" then
		return "off", nil
	end
	for i, p in M.COLOR_PRESETS do
		if c == p.hex or table.find(p.aliases, c) then
			return "preset", i
		end
	end
	local i = table.find(themeHexes, c)
	if i then
		return "theme", i
	end
	return "custom", nil
end

-- Reads mouse.json as the service wrote it. Each field that doesn't validate
-- falls back to its default, so one bad value doesn't lose the rest.
function M.fromStored(t: { [string]: any }): Settings
	local s = M.defaults()
	if oneOf(M.PRESETS, t.presets) then
		s.presets = t.presets
	end
	if oneOf(M.FIXED_DPI, t.fixed_dpi) then
		s.fixed_dpi = t.fixed_dpi
	end
	if oneOf(M.POLLING, t.polling_rate) then
		s.polling_rate = t.polling_rate
	end
	if intIn(t.sleep_timer, 0, M.SLEEP_MAX) then
		s.sleep_timer = t.sleep_timer
	end
	if intIn(t.dim_timer, 0, M.DIM_MAX) then
		s.dim_timer = t.dim_timer
	end
	for _, zone in ZONES do
		local c = M.normalizeColor(t[zone], false)
		if c then
			(s :: any)[zone] = c
		end
	end
	if oneOf(M.LIGHTING, t.lighting) then
		s.lighting = t.lighting
		s.reactive = t.reactive == true
		s.reactive_color = M.normalizeColor(t.reactive_color, false) or ""
	else
		local lighting, reactive, reactiveColor = fromOldLighting(t.default_lighting, t.rainbow, t.reactive_color, anyZoneSet(s), false)
		s.lighting, s.reactive, s.reactive_color = lighting or s.lighting, reactive, reactiveColor
	end
	return s
end

-- Applies one change. On success returns the new settings (s is not changed)
-- and the rivalcfg arguments, without the binary. On failure returns nil and
-- "invalid" or "presets_locked".
function M.change(s: Settings, key: string, value: any): (Settings?, { string } | string)
	local lock = lightingLock(s, key)
	if lock then
		return nil, lock
	end
	local new = copy(s)
	if key == "presets" then
		if not oneOf(M.PRESETS, value) then
			return nil, "invalid"
		end
		if s.fixed_dpi ~= "" then
			return nil, "presets_locked"
		end
		new.presets = value
		return new, { "-s", value }
	elseif key == "fixed_dpi" then
		if not oneOf(M.FIXED_DPI, value) then
			return nil, "invalid"
		end
		new.fixed_dpi = value
		return new, { "-s", if value == "" then s.presets else fixedArg(value) }
	elseif key == "polling_rate" then
		if not oneOf(M.POLLING, value) then
			return nil, "invalid"
		end
		new.polling_rate = value
		return new, { "-p", value }
	elseif key == "sleep_timer" then
		if not intIn(value, 0, M.SLEEP_MAX) then
			return nil, "invalid"
		end
		new.sleep_timer = value
		return new, { "-t", tostring(value) }
	elseif key == "dim_timer" then
		if not intIn(value, 0, M.DIM_MAX) then
			return nil, "invalid"
		end
		new.dim_timer = value
		return new, { "-T", tostring(value) }
	elseif ZONE_FLAGS[key] then
		local c = M.normalizeColor(value, false)
		if not c then
			return nil, "invalid"
		end
		(new :: any)[key] = c
		return new, { ZONE_FLAGS[key], c }
	elseif key == "reactive_color" then
		local c = M.normalizeColor(value, false)
		if not c then
			return nil, "invalid"
		end
		new.reactive_color = c
		return new, keepRainbow(new, { "-a", c })
	elseif key == "lighting" then
		if not oneOf(M.LIGHTING, value) then
			return nil, "invalid"
		end
		new.lighting = value
		if value == "reactive" and new.reactive_color == "" then
			new.reactive_color = REACTIVE_DEFAULT
		end
		return new, lightingArgs(new, new)
	elseif key == "reactive" then
		if type(value) ~= "boolean" then
			return nil, "invalid"
		end
		new.reactive = value
		if value and new.reactive_color == "" then
			new.reactive_color = REACTIVE_DEFAULT
		end
		return new, keepRainbow(new, { "-d", startup(new), "-a", flash(new) })
	end
	return nil, "invalid"
end

return M
