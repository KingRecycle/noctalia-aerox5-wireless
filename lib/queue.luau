--!strict
-- Holds pending mouse changes. One entry per setting, so a slider dragged
-- through many values sends only the last one. One change runs at a time.

type Entry = { key: string, value: any, readyAt: number }

export type Queue = {
	push: (self: Queue, key: string, value: any, nowMs: number, delayMs: number) -> (),
	take: (self: Queue, nowMs: number) -> { key: string, value: any }?,
	done: (self: Queue) -> (),
	isEmpty: (self: Queue) -> boolean,
	busy: (self: Queue) -> boolean,
}

local M = {}

function M.new(): Queue
	local pending: { [string]: Entry } = {}
	local running = false
	local q = {}

	-- Replaces any pending entry for the same key and restarts its delay.
	function q.push(_, key: string, value: any, nowMs: number, delayMs: number)
		pending[key] = { key = key, value = value, readyAt = nowMs + delayMs }
	end

	-- Returns the due entry with the earliest ready time and marks the queue busy.
	function q.take(_, nowMs: number): { key: string, value: any }?
		if running then
			return nil
		end
		local best: Entry? = nil
		for _, e in pending do
			if e.readyAt <= nowMs and (best == nil or e.readyAt < best.readyAt) then
				best = e
			end
		end
		if best == nil then
			return nil
		end
		pending[best.key] = nil
		running = true
		return { key = best.key, value = best.value }
	end

	function q.done(_)
		running = false
	end

	function q.isEmpty(_): boolean
		return next(pending) == nil
	end

	function q.busy(_): boolean
		return running
	end

	return (q :: any) :: Queue
end

return M
