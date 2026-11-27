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
	remount: (self: Drafts, key: string) -> (),
	reset: (self: Drafts) -> (),
	type: (self: Drafts, key: string, text: string) -> (),
	submit: (self: Drafts, key: string) -> string?,
	settingsChanged: (self: Drafts, old: { [string]: any }?, new: { [string]: any }, keys: { string }) -> (),
}

local M = {}

function M.new(): Drafts
	local values: { [string]: any } = {}
	local gens: { [string]: number } = {}
	-- Text typed into a field but not submitted. It isn't a draft: the panel
	-- doesn't show it anywhere else, and nothing is sent until Enter.
	local typed: { [string]: string } = {}
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

	-- Makes the input for key show its current value again.
	function d.remount(_, key: string)
		gens[key] = (gens[key] or 0) + 1
	end

	function d.type(_, key: string, text: string)
		typed[key] = text
	end

	function d.submit(_, key: string): string?
		local text = typed[key]
		typed[key] = nil
		return text
	end

	-- The service published new settings. A field with no draft in flight
	-- remounts when its value changed, so a value the service filled in shows.
	function d.settingsChanged(self: Drafts, old: { [string]: any }?, new: { [string]: any }, keys: { string })
		if old == nil then
			return
		end
		for _, key in keys do
			if old[key] ~= new[key] and values[key] == nil then
				self:remount(key)
			end
		end
	end

	function d.reset(_)
		table.clear(values)
		table.clear(typed)
		base += 1
	end

	return (d :: any) :: Drafts
end

return M
