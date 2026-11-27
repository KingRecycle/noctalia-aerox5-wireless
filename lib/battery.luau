--!strict
-- Parses the output of bin/aerox5-battery and decides how the bar shows it.
-- No dependencies, so the luau CLI can test it.

export type Battery = {
	state: "ok" | "asleep" | "no_dongle" | "error",
	level: number?,
	charging: boolean,
}

local M = {}

-- Re-poll this often while the mouse isn't answering, so it comes back fast.
local RETRY_POLL_MS = 10000

-- Exit codes from bin/aerox5-battery: 0 ok, 1 mouse unreachable, 2 no dongle.
-- The reader reports an unreachable mouse on stdout. Exit 1 with stderr is an
-- uncaught Python exception (a missing udev rule, say), not a sleeping mouse.
function M.parse(exitCode: number, stdout: string, previous: Battery?, stderr: string?): Battery
	if exitCode == 1 and stderr ~= nil and string.match(stderr, "%S") then
		return { state = "error", level = nil, charging = false }
	elseif exitCode == 1 then
		return { state = "asleep", level = previous and previous.level, charging = false }
	elseif exitCode == 2 then
		return { state = "no_dongle", level = nil, charging = false }
	elseif exitCode ~= 0 then
		return { state = "error", level = nil, charging = false }
	end

	local status, digits = string.match(stdout, "^(%a+)%s+%[.-%]%s+(%d+)%s*%%")
	local level = tonumber(digits)
	if not status or not level or level < 0 or level > 100 then
		return { state = "error", level = nil, charging = false }
	end
	return { state = "ok", level = level, charging = status == "Charging" }
end

function M.band(b: Battery): "high" | "mid" | "low" | "charging" | "asleep" | "unknown"
	if b.state == "asleep" then
		return "asleep"
	elseif b.state ~= "ok" or b.level == nil then
		return "unknown"
	elseif b.charging then
		return "charging"
	elseif b.level > 50 then
		return "high"
	elseif b.level > 20 then
		return "mid"
	end
	return "low"
end

function M.nextPollMs(b: Battery, intervalS: number): number
	if b.state ~= "ok" then
		return RETRY_POLL_MS
	end
	return intervalS * 1000
end

return M
