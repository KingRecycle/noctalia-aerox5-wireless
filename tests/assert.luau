local M = {}

local function show(v: any): string
	if type(v) == "table" then
		local parts = {}
		for k, x in v do
			table.insert(parts, tostring(k) .. "=" .. show(x))
		end
		table.sort(parts)
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

local function deepEq(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not deepEq(v, b[k]) then
			return false
		end
	end
	for k, v in b do
		if a[k] == nil and v ~= nil then
			return false
		end
	end
	return true
end

function M.eq(actual: any, expected: any, msg: string?)
	if not deepEq(actual, expected) then
		error((msg or "not equal") .. ": expected " .. show(expected) .. ", got " .. show(actual), 2)
	end
end

function M.truthy(v: any, msg: string?)
	if not v then
		error((msg or "expected truthy") .. ", got " .. show(v), 2)
	end
end

return M
