local A = require("./assert")
local queue = require("../lib/queue")

local T = {}

function T.test_take_when_due()
	local q = queue.new()
	q:push("polling_rate", "500", 0, 0)
	A.eq(q:take(0), { key = "polling_rate", value = "500" })
end

function T.test_not_before_delay()
	local q = queue.new()
	q:push("sleep_timer", 3, 0, 1000)
	A.eq(q:take(999), nil)
	A.eq(q:take(1000), { key = "sleep_timer", value = 3 })
end

function T.test_coalesces_same_key()
	local q = queue.new()
	q:push("sleep_timer", 3, 0, 1000)
	q:push("sleep_timer", 7, 500, 1000)
	q:push("sleep_timer", 20, 900, 1000)
	A.eq(q:take(1899), nil)
	A.eq(q:take(1900), { key = "sleep_timer", value = 20 })
	q:done()
	A.eq(q:isEmpty(), true)
	A.eq(q:take(5000), nil)
end

function T.test_no_take_while_busy()
	local q = queue.new()
	q:push("polling_rate", "500", 0, 0)
	q:push("dim_timer", 60, 0, 0)
	A.truthy(q:take(0), "first take")
	A.eq(q:busy(), true)
	A.eq(q:take(0), nil)
	q:done()
	A.eq(q:busy(), false)
	A.truthy(q:take(0), "second take after done")
end

function T.test_earliest_first()
	local q = queue.new()
	q:push("a", 1, 0, 100)
	q:push("b", 2, 0, 50)
	A.eq(q:take(200), { key = "b", value = 2 })
end

return T
