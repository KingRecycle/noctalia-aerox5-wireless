-- Runs every test module listed below. Usage: luau tests/run.luau
local modules = {
	{ "battery", require("./test_battery") },
	{ "mouse", require("./test_mouse") },
}

local passed, failed = 0, 0
for _, entry in modules do
	local name, tests = entry[1], entry[2]
	local names = {}
	for testName in tests do
		table.insert(names, testName)
	end
	table.sort(names)
	for _, testName in names do
		local ok, err = pcall(tests[testName])
		if ok then
			passed += 1
		else
			failed += 1
			print("FAIL " .. name .. "." .. testName .. ": " .. tostring(err))
		end
	end
end

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error("test failures", 0)
end
