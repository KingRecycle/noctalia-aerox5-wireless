local A = require("./assert")
local battery = require("../lib/battery")

local T = {}

function T.test_discharging()
	A.eq(battery.parse(0, "Discharging [========  ] 85 %"), { state = "ok", level = 85, charging = false })
end

function T.test_charging()
	A.eq(battery.parse(0, "Charging [====      ] 40 %"), { state = "ok", level = 40, charging = true })
end

function T.test_out_of_range_is_error()
	local b = battery.parse(0, "Charging [==] 630 %")
	A.eq(b.state, "error")
	A.eq(b.level, nil)
end

function T.test_garbage_is_error()
	A.eq(battery.parse(0, "hello").state, "error")
end

function T.test_asleep_keeps_level()
	A.eq(battery.parse(1, "", { state = "ok", level = 85, charging = false }), { state = "asleep", level = 85, charging = false })
end

function T.test_asleep_without_previous()
	A.eq(battery.parse(1, "").level, nil)
end

function T.test_no_dongle()
	local b = battery.parse(2, "")
	A.eq(b.state, "no_dongle")
	A.eq(b.level, nil)
end

function T.test_unknown_exit()
	A.eq(battery.parse(3, "").state, "error")
end

function T.test_bands()
	local function ok(level: number, charging: boolean?)
		return { state = "ok", level = level, charging = charging == true }
	end
	A.eq(battery.band(ok(51)), "high")
	A.eq(battery.band(ok(50)), "mid")
	A.eq(battery.band(ok(21)), "mid")
	A.eq(battery.band(ok(20)), "low")
	A.eq(battery.band(ok(0)), "low")
	A.eq(battery.band(ok(60, true)), "charging")
	A.eq(battery.band({ state = "asleep", level = 85, charging = false }), "asleep")
	A.eq(battery.band({ state = "error", charging = false }), "unknown")
	A.eq(battery.band({ state = "no_dongle", charging = false }), "unknown")
end

function T.test_next_poll()
	A.eq(battery.nextPollMs({ state = "ok", level = 85, charging = false }, 120), 120000)
end

function T.test_crash_is_error()
	-- An uncaught Python exception exits 1 with a traceback on stderr.
	local b = battery.parse(1, "", { state = "ok", level = 85, charging = false }, "Traceback (most recent call last):\nPermissionError")
	A.eq(b.state, "error")
	A.eq(b.level, nil)
end

function T.test_asleep_with_empty_stderr()
	A.eq(battery.parse(1, "Unable to get the battery level. Is the mouse turned on?", nil, "").state, "asleep")
end

function T.test_next_poll_not_ok()
	A.eq(battery.nextPollMs({ state = "no_dongle", charging = false }, 120), 10000)
	A.eq(battery.nextPollMs({ state = "error", charging = false }, 120), 10000)
end

function T.test_next_poll_asleep()
	A.eq(battery.nextPollMs({ state = "asleep", level = 85, charging = false }, 120), 10000)
end

return T
