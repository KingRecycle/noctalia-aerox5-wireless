local A = require("./assert")
local mouse = require("../lib/mouse")

local T = {}

local function copy(t: { [any]: any }): { [any]: any }
	local c = {}
	for k, v in t do
		c[k] = v
	end
	return c
end

local function with(overrides: { [string]: any })
	local s = mouse.defaults()
	for k, v in overrides do
		s[k] = v
	end
	return s
end

function T.test_legacy_empty()
	local s, extras = mouse.fromLegacy({})
	A.eq(s, mouse.defaults())
	A.eq(extras, {})
end

function T.test_color_choice_off()
	A.eq({ mouse.colorChoice("off", true, {}) }, { "off" })
end

function T.test_color_choice_preset_hex()
	A.eq({ mouse.colorChoice("#ff0000", false, {}) }, { "preset", 1 })
end

function T.test_color_choice_preset_name()
	A.eq({ mouse.colorChoice("red", false, {}) }, { "preset", 1 })
	A.eq({ mouse.colorChoice("lime", false, {}) }, { "preset", 2 })
	A.eq({ mouse.colorChoice(" Blue ", false, {}) }, { "preset", 3 })
end

function T.test_color_choice_theme()
	A.eq({ mouse.colorChoice("#e0bbdd", false, { "#b0c6ff", "#c0c6dc", "#e0bbdd" }) }, { "theme", 3 })
end

function T.test_color_choice_preset_before_theme()
	A.eq({ mouse.colorChoice("#ffffff", false, { "#ffffff" }) }, { "preset", 4 })
end

function T.test_color_choice_custom()
	A.eq({ mouse.colorChoice("#123456", false, { "#b0c6ff" }) }, { "custom" })
	A.eq({ mouse.colorChoice("", false, {}) }, { "custom" })
	A.eq({ mouse.colorChoice("off", false, {}) }, { "custom" })
end

function T.test_color_presets_valid()
	for _, p in mouse.COLOR_PRESETS do
		A.eq(mouse.normalizeColor(p.hex, false), p.hex, p.id)
	end
end

function T.test_fixed_dpi_args()
	local new, args = mouse.change(mouse.defaults(), "fixed_dpi", "2400")
	A.eq(args, { "-s", "2400, 2400, 2400, 2400, 2400" })
	A.eq(new and new.fixed_dpi, "2400")
end

function T.test_fixed_off_resends_presets()
	local _, args = mouse.change(with({ presets = "800, 1600, 3200", fixed_dpi = "2400" }), "fixed_dpi", "")
	A.eq(args, { "-s", "800, 1600, 3200" })
end

function T.test_presets_locked()
	local new, err = mouse.change(with({ fixed_dpi = "2400" }), "presets", mouse.PRESETS[2])
	A.eq(new, nil)
	A.eq(err, "presets_locked")
end

function T.test_presets_args()
	local _, args = mouse.change(mouse.defaults(), "presets", "400, 800, 1600")
	A.eq(args, { "-s", "400, 800, 1600" })
end

function T.test_polling()
	local _, args = mouse.change(mouse.defaults(), "polling_rate", "500")
	A.eq(args, { "-p", "500" })
	local new, err = mouse.change(mouse.defaults(), "polling_rate", "7")
	A.eq(new, nil)
	A.eq(err, "invalid")
end

function T.test_timers()
	local s = mouse.defaults()
	A.eq(select(2, mouse.change(s, "sleep_timer", 20)), { "-t", "20" })
	A.eq(select(2, mouse.change(s, "sleep_timer", 21)), "invalid")
	A.eq(select(2, mouse.change(s, "dim_timer", 1200)), { "-T", "1200" })
	A.eq(select(2, mouse.change(s, "dim_timer", -1)), "invalid")
	A.eq((mouse.change(s, "dim_timer", -1)), nil)
end

function T.test_rejects_bad_colors()
	local s = with({ lighting = "zones" })
	for _, bad in { "#12345", "blue!", "" } do
		local new, err = mouse.change(s, "top_color", bad)
		A.eq(new, nil, bad)
		A.eq(err, "invalid", bad)
	end
end

function T.test_colors_accepted()
	A.eq(mouse.normalizeColor("#F00", false), "#f00")
	A.eq(mouse.normalizeColor("ff0000", false), "ff0000")
	A.eq(mouse.normalizeColor(" Red ", false), "red")
	A.eq(mouse.normalizeColor("off", true), "off")
	A.eq(mouse.normalizeColor("off", false), nil)
end

function T.test_unknown_key()
	local new, err = mouse.change(mouse.defaults(), "dpi", 1)
	A.eq(new, nil)
	A.eq(err, "invalid")
end

function T.test_legacy_import()
	local s, extras = mouse.fromLegacy({
		sensitivity = "800, 1600, 3200",
		fixedDpi = "2400",
		pollingRate = "1000",
		sleepTimer = 15,
		dimTimer = 30,
		reactiveColor = "off",
		defaultLighting = "reactive",
		rainbowEffect = false,
		pollInterval = 60,
		rivalcfgPath = "/home/x/rivalcfg",
	})
	A.eq(s.presets, "800, 1600, 3200")
	A.eq(s.fixed_dpi, "2400")
	A.eq(s.polling_rate, "1000")
	A.eq(s.sleep_timer, 15)
	A.eq(s.dim_timer, 30)
	A.eq(s.lighting, "zones")
	A.eq(s.reactive, false)
	A.eq(s.reactive_color, "")
	A.eq(extras, { poll_interval = 60, rivalcfg_path = "/home/x/rivalcfg" })
end

function T.test_legacy_lighting_modes()
	A.eq(mouse.fromLegacy({ defaultLighting = "off" }).lighting, "off")
	A.eq(mouse.fromLegacy({ rainbowEffect = true }).lighting, "rainbow")
	local s = mouse.fromLegacy({ reactiveColor = "red", defaultLighting = "reactive" })
	A.eq(s.reactive, true)
	A.eq(s.reactive_color, "red")
end

function T.test_legacy_bad_values_fall_back()
	local s = mouse.fromLegacy({ sleepTimer = 99, pollingRate = "7" })
	local d = mouse.defaults()
	A.eq(s.sleep_timer, d.sleep_timer)
	A.eq(s.polling_rate, d.polling_rate)
end

function T.test_stored_round_trip()
	local s = with({ fixed_dpi = "2400", presets = "800, 1600, 3200", top_color = "#00ff00", lighting = "zones", reactive = true, reactive_color = "#b0c6ff", sleep_timer = 15 })
	A.eq(mouse.fromStored(s), s)
end

function T.test_stored_bad_fields_fall_back()
	local d = mouse.defaults()
	local s = mouse.fromStored({ presets = "1, 2", fixed_dpi = "2400", sleep_timer = "15", top_color = "blue!", lighting = "disco", reactive = "yes" })
	A.eq(s.fixed_dpi, "2400")
	A.eq(s.presets, d.presets)
	A.eq(s.sleep_timer, d.sleep_timer)
	A.eq(s.top_color, "")
	A.eq(s.lighting, d.lighting)
	A.eq(s.reactive, d.reactive)
end

-- mouse.json written before the lighting mode existed: the live state was
-- the rainbow effect flag plus the reactive color.
function T.test_stored_old_lighting_fields()
	local s = mouse.fromStored({ default_lighting = "rainbow", rainbow = false, reactive_color = "#b0c6ff", top_color = "red" })
	A.eq(s.lighting, "zones")
	A.eq(s.reactive, true)
	A.eq(s.reactive_color, "#b0c6ff")
	A.eq(mouse.fromStored({ default_lighting = "off", reactive_color = "#b0c6ff" }).lighting, "off")
	A.eq(mouse.fromStored({ default_lighting = "reactive", rainbow = true }).lighting, "rainbow")
	A.eq(mouse.fromStored({ reactive_color = "off" }).reactive, false)
end

function T.test_stored_untouched_defaults_are_rainbow()
	-- rivalcfg's factory state: startup rainbow, no colors ever set.
	A.eq(mouse.fromStored({ default_lighting = "rainbow", rainbow = false }).lighting, "rainbow")
	A.eq(mouse.fromStored({ default_lighting = "reactive-rainbow", rainbow = false }).lighting, "rainbow")
	A.eq(mouse.fromLegacy({ defaultLighting = "rainbow", rainbowEffect = false }).lighting, "rainbow")
	-- A zone color set means the zones were showing.
	A.eq(mouse.fromStored({ default_lighting = "rainbow", rainbow = false, top_color = "red" }).lighting, "zones")
end

function T.test_legacy_off_with_reactive_is_reactive_only()
	-- The QML plugin sent "-a <color> -d off", which flashes on clicks.
	local s = mouse.fromLegacy({ defaultLighting = "off", reactiveColor = "red" })
	A.eq(s.lighting, "reactive")
	A.eq(s.reactive_color, "red")
	-- The interim plugin sent "-a off" with off, so stored off stays off.
	A.eq(mouse.fromStored({ default_lighting = "off", reactive_color = "red" }).lighting, "off")
end

local function lit(overrides: { [string]: any }?)
	local s = with({ top_color = "red", middle_color = "lime", bottom_color = "blue", reactive_color = "#b0c6ff", lighting = "zones", reactive = true })
	for k, v in overrides or {} do
		s[k] = v
	end
	return s
end

function T.test_mode_off()
	local new, args = mouse.change(lit(), "lighting", "off")
	A.eq(args, {
		"-d", "off", "-a", "off",
		"--top-color", "#000000", "--middle-color", "#000000", "--bottom-color", "#000000",
	})
	A.eq(new and new.lighting, "off")
	-- Saved colors and the reactive choice stay for when lighting comes back.
	A.eq(new and new.top_color, "red")
	A.eq(new and new.reactive, true)
end

function T.test_mode_zones_with_reactive()
	local _, args = mouse.change(lit({ lighting = "off" }), "lighting", "zones")
	A.eq(args, {
		"-d", "reactive", "-a", "#b0c6ff",
		"--top-color", "red", "--middle-color", "lime", "--bottom-color", "blue",
	})
end

function T.test_mode_zones_without_reactive()
	local _, args = mouse.change(lit({ lighting = "rainbow", reactive = false }), "lighting", "zones")
	A.eq(args, {
		"-d", "reactive", "-a", "off",
		"--top-color", "red", "--middle-color", "lime", "--bottom-color", "blue",
	})
end

function T.test_mode_zones_empty_colors_use_defaults()
	local new, args = mouse.change(with({ lighting = "off" }), "lighting", "zones")
	A.eq(args, {
		"-d", "reactive", "-a", "off",
		"--top-color", "red", "--middle-color", "lime", "--bottom-color", "blue",
	})
	A.eq(new and new.middle_color, "lime")
end

function T.test_mode_rainbow()
	A.eq(select(2, mouse.change(lit(), "lighting", "rainbow")), { "-d", "reactive-rainbow", "-a", "#b0c6ff", "-e" })
	A.eq(select(2, mouse.change(lit({ reactive = false }), "lighting", "rainbow")), { "-d", "rainbow", "-a", "off", "-e" })
end

function T.test_mode_reactive_only()
	local new, args = mouse.change(lit({ reactive = false }), "lighting", "reactive")
	A.eq(args, {
		"-d", "off", "-a", "#b0c6ff",
		"--top-color", "#000000", "--middle-color", "#000000", "--bottom-color", "#000000",
	})
	A.eq(new and new.lighting, "reactive")
	A.eq(new and new.top_color, "red")
end

function T.test_mode_reactive_only_default_color()
	local new, args = mouse.change(with({ lighting = "zones" }), "lighting", "reactive")
	A.eq(args and args[4], "#ffffff")
	A.eq(new and new.reactive_color, "#ffffff")
end

function T.test_reactive_only_locks()
	local s = lit({ lighting = "reactive", reactive = false })
	A.eq(select(2, mouse.change(s, "top_color", "red")), "zones_only")
	A.eq(select(2, mouse.change(s, "reactive", true)), "reactive_mode")
	A.eq(select(2, mouse.change(s, "reactive_color", "red")), { "-a", "red" })
end

function T.test_mode_invalid()
	A.eq(select(2, mouse.change(lit(), "lighting", "disco")), "invalid")
end

function T.test_reactive_toggle()
	local new, args = mouse.change(lit(), "reactive", false)
	A.eq(args, { "-d", "reactive", "-a", "off" })
	A.eq(new and new.reactive, false)
	A.eq(select(2, mouse.change(lit({ reactive = false, lighting = "rainbow" }), "reactive", true)), { "-d", "reactive-rainbow", "-a", "#b0c6ff", "-e" })
	A.eq(select(2, mouse.change(lit(), "reactive", "yes")), "invalid")
end

function T.test_reactive_in_rainbow_keeps_rainbow()
	local s = lit({ lighting = "rainbow" })
	A.eq(select(2, mouse.change(s, "reactive", false)), { "-d", "rainbow", "-a", "off", "-e" })
	A.eq(select(2, mouse.change(s, "reactive_color", "red")), { "-a", "red", "-e" })
end

function T.test_reactive_on_without_color_uses_white()
	local new, args = mouse.change(lit({ reactive = false, reactive_color = "" }), "reactive", true)
	A.eq(args, { "-d", "reactive", "-a", "#ffffff" })
	A.eq(new and new.reactive_color, "#ffffff")
end

function T.test_reactive_color()
	A.eq(select(2, mouse.change(lit(), "reactive_color", "Red")), { "-a", "red" })
	A.eq(select(2, mouse.change(lit(), "reactive_color", "off")), "invalid")
end

function T.test_zone_color()
	local new, args = mouse.change(lit(), "middle_color", "lime")
	A.eq(args, { "--middle-color", "lime" })
	A.eq(new and new.middle_color, "lime")
end

function T.test_locks()
	local function err(s, key, value)
		return select(2, mouse.change(s, key, value))
	end
	A.eq(err(lit({ lighting = "off" }), "top_color", "red"), "lighting_off")
	A.eq(err(lit({ lighting = "off" }), "reactive", false), "lighting_off")
	A.eq(err(lit({ lighting = "off" }), "reactive_color", "red"), "lighting_off")
	A.eq(err(lit({ lighting = "rainbow" }), "top_color", "red"), "zones_only")
	A.eq(err(lit({ reactive = false }), "reactive_color", "red"), "reactive_off")
end

function T.test_no_mutation()
	local s = lit()
	local before = copy(s)
	mouse.change(s, "fixed_dpi", "2400")
	mouse.change(s, "lighting", "off")
	mouse.change(s, "lighting", "rainbow")
	mouse.change(with({ lighting = "off" }), "lighting", "zones")
	mouse.change(s, "reactive", true)
	mouse.change(s, "top_color", "red")
	mouse.change(s, "sleep_timer", 3)
	A.eq(s, before)
end

return T
