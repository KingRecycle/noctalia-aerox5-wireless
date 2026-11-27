local A = require("./assert")
local drafts = require("../lib/drafts")

local T = {}

function T.test_typed_text_is_not_a_draft_until_submitted()
	local d = drafts.new()
	d:type("top_color", "#0000ff")
	A.eq(d:get("top_color"), nil)
	A.eq(d:submit("top_color"), "#0000ff")
	-- Submitting takes the text, so a second Enter sends nothing.
	A.eq(d:submit("top_color"), nil)
	d:type("top_color", "blue")
	d:reset()
	A.eq(d:submit("top_color"), nil)
end

function T.test_settings_change_remounts_fields_without_draft()
	local d = drafts.new()
	local keys = { "top_color", "middle_color", "reactive_color" }
	local gTop, gMid, gRe = d:generation("top_color"), d:generation("middle_color"), d:generation("reactive_color")
	d:set("middle_color", "green")
	d:settingsChanged({ top_color = "", middle_color = "", reactive_color = "red" }, { top_color = "red", middle_color = "lime", reactive_color = "red" }, keys)
	-- top changed with no draft: the field must show the new value.
	A.truthy(d:generation("top_color") ~= gTop)
	-- middle has a draft in flight: leave the field alone.
	A.eq(d:generation("middle_color"), gMid)
	-- reactive didn't change.
	A.eq(d:generation("reactive_color"), gRe)
	-- No previous settings (first publish): nothing to compare.
	d:settingsChanged(nil, { top_color = "blue" }, keys)
end

function T.test_set_get()
	local d = drafts.new()
	d:set("sleep_timer", 14)
	A.eq(d:get("sleep_timer"), 14)
	A.eq(d:get("dim_timer"), nil)
end

function T.test_applied_same_value_clears()
	local d = drafts.new()
	d:set("polling_rate", "500")
	local g = d:generation("polling_rate")
	d:applied("polling_rate", "500", true)
	A.eq(d:get("polling_rate"), nil)
	A.eq(d:generation("polling_rate"), g)
end

function T.test_applied_newer_draft_kept()
	local d = drafts.new()
	d:set("sleep_timer", 20)
	d:applied("sleep_timer", 15, true)
	A.eq(d:get("sleep_timer"), 20)
end

function T.test_failure_reverts()
	local d = drafts.new()
	d:set("top_color", "#12345")
	local g = d:generation("top_color")
	d:applied("top_color", "#12345", false)
	A.eq(d:get("top_color"), nil)
	A.eq(d:generation("top_color"), g + 1)
end

-- An apply for one field must not touch another field being edited.
function T.test_other_keys_untouched()
	local d = drafts.new()
	d:set("middle_color", "li")
	local g = d:generation("middle_color")
	d:applied("top_color", "red", true)
	d:applied("top_color", "red", false)
	A.eq(d:get("middle_color"), "li")
	A.eq(d:generation("middle_color"), g)
end

function T.test_remount_bumps_one()
	local d = drafts.new()
	local a, b = d:generation("top_color"), d:generation("middle_color")
	d:remount("top_color")
	A.eq(d:generation("top_color"), a + 1)
	A.eq(d:generation("middle_color"), b)
end

function T.test_reset_bumps_all()
	local d = drafts.new()
	d:set("top_color", "red")
	local g = d:generation("bottom_color")
	d:reset()
	A.eq(d:get("top_color"), nil)
	A.truthy(d:generation("bottom_color") > g, "generation bumped")
end

return T
