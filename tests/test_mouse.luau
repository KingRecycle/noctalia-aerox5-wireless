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
	A.eq(s.reactive_color, "off")
	A.eq(s.default_lighting, "reactive")
	A.eq(s.rainbow, false)
	A.eq(extras, { poll_interval = 60, rivalcfg_path = "/home/x/rivalcfg" })
end

function T.test_legacy_bad_values_fall_back()
	local s = mouse.fromLegacy({ sleepTimer = 99, pollingRate = "7", defaultLighting = "disco" })
	local d = mouse.defaults()
	A.eq(s.sleep_timer, d.sleep_timer)
	A.eq(s.polling_rate, d.polling_rate)
	A.eq(s.default_lighting, d.default_lighting)
end

function T.test_legacy_empty()
	local s, extras = mouse.fromLegacy({})
	A.eq(s, mouse.defaults())
	A.eq(extras, {})
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

function T.test_lighting()
	local s = mouse.defaults()
	A.eq(select(2, mouse.change(s, "default_lighting", "reactive-rainbow")), { "-d", "reactive-rainbow" })
	A.eq((mouse.change(s, "default_lighting", "disco")), nil)
	A.eq(select(2, mouse.change(s, "default_lighting", "disco")), "invalid")
end

function T.test_rejects_bad_colors()
	local s = mouse.defaults()
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

function T.test_color_clears_rainbow()
	local new, args = mouse.change(with({ rainbow = true }), "middle_color", "lime")
	A.eq(new and new.rainbow, false)
	A.eq(args, { "--middle-color", "lime" })
end

function T.test_reactive()
	A.eq(select(2, mouse.change(mouse.defaults(), "reactive_color", "off")), { "-a", "off" })
end

function T.test_rainbow_on()
	A.eq(select(2, mouse.change(mouse.defaults(), "rainbow", true)), { "-e" })
end

function T.test_rainbow_off_defaults()
	local new, args = mouse.change(with({ rainbow = true }), "rainbow", false)
	A.eq(args, { "--top-color", "red", "--middle-color", "lime", "--bottom-color", "blue" })
	A.eq(new and new.top_color, "red")
	A.eq(new and new.middle_color, "lime")
	A.eq(new and new.bottom_color, "blue")
end

function T.test_rainbow_off_keeps_colors()
	local _, args = mouse.change(with({ rainbow = true, top_color = "#00ff00" }), "rainbow", false)
	A.eq({ args[1], args[2] }, { "--top-color", "#00ff00" })
end

function T.test_unknown_key()
	local new, err = mouse.change(mouse.defaults(), "dpi", 1)
	A.eq(new, nil)
	A.eq(err, "invalid")
end

function T.test_no_mutation()
	local s = with({ rainbow = true })
	local before = copy(s)
	mouse.change(s, "fixed_dpi", "2400")
	mouse.change(s, "rainbow", false)
	mouse.change(s, "top_color", "red")
	mouse.change(s, "sleep_timer", 3)
	A.eq(s, before)
end

return T
