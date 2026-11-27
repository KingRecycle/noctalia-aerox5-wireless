--!strict
-- Values the panel shows while a change waits for the service. One entry and
-- one generation per setting, so an apply for one field never resets another.
-- The generation goes into an input's key: bumping it remounts that input
-- with the stored value.

export type Drafts = {
	set: (self: Drafts, key: string, value: any) -> (),
	get: (self: Drafts, key: string) -> any,
	generation: (self: Drafts, key: string) -> number,
	applied: (self: Drafts, key: string, value: any, ok: boolean) -> (),
	reset: (self: Drafts) -> (),
}

local M = {}

function M.new(): Drafts
	local values: { [string]: any } = {}
	local gens: { [string]: number } = {}
	local base = 0
	local d = {}

	function d.set(_, key: string, value: any)
		values[key] = value
	end

	function d.get(_, key: string): any
		return values[key]
	end

	function d.generation(_, key: string): number
		return base + (gens[key] or 0)
	end

	-- The service finished a change. On failure the field reverts. On success
	-- the draft goes only if nothing newer was entered since.
	function d.applied(_, key: string, value: any, ok: boolean)
		if not ok then
			values[key] = nil
			gens[key] = (gens[key] or 0) + 1
		elseif values[key] == value then
			values[key] = nil
		end
	end

	function d.reset(_)
		table.clear(values)
		base += 1
	end

	return (d :: any) :: Drafts
end

return M
