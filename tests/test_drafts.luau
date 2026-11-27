local A = require("./assert")
local drafts = require("../lib/drafts")

local T = {}

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

function T.test_reset_bumps_all()
	local d = drafts.new()
	d:set("top_color", "red")
	local g = d:generation("bottom_color")
	d:reset()
	A.eq(d:get("top_color"), nil)
	A.truthy(d:generation("bottom_color") > g, "generation bumped")
end

return T
