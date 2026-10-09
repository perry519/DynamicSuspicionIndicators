-- Unit ID → unit lookup cache, used by client to resolve sync wire IDs

if not DynamicSuspicionIndicatorsManager then
	return
end
local DI = DynamicSuspicionIndicatorsManager
DI.UnitIndex = DI.UnitIndex or {}
local UI = DI.UnitIndex
local G = DI.Game
local alive = G.alive

UI.TTL = 0.25
UI._cache = UI._cache or {}
UI._cache_t = UI._cache_t or -999
UI._world_scanned = UI._world_scanned or false

local WORLD_SLOTS = { 1, 8, 11, 12, 14, 16, 18, 21, 22, 24, 25, 26, 33, 34, 35 }

local function _add(lookup, unit)
	if not (alive(unit) and unit.id) then
		return
	end
	local ok, uid = pcall(function()
		return unit:id()
	end)
	if ok and uid and uid ~= -1 then
		lookup[uid] = unit
	end
end

local function _rebuild()
	local lookup = {}

	local session = G.session()
	if session then
		local local_peer = session.local_peer and session:local_peer()
		if local_peer and local_peer.unit then
			_add(lookup, local_peer:unit())
		end
		if session.peers then
			for _, peer in pairs(session:peers() or {}) do
				if peer.unit then
					_add(lookup, peer:unit())
				end
			end
		end
	end

	for _, e in pairs(G.enemies() or {}) do
		_add(lookup, e.unit)
	end
	for _, e in pairs(G.civilians() or {}) do
		_add(lookup, e.unit)
	end

	for _, unit in pairs(G.security_cameras()) do
		_add(lookup, unit)
	end
	for _, unit in pairs(G.interactive_units()) do
		_add(lookup, unit)
	end

	return lookup
end

local function _add_world(lookup)
	if _G.World then
		local ok, err = pcall(function()
			local mask = G.make_slot_mask(unpack(WORLD_SLOTS))
			for _, unit in pairs(G.find_units("all", mask) or {}) do
				_add(lookup, unit)
			end
		end)
		if not ok then
			DI.Logger.once("debug", "unit-index:world-sweep-failed", "unit index world sweep failed: " .. tostring(err))
		end
	end
end

function UI.lookup(now_t, requested_id)
	local t = now_t or 0
	if t - (UI._cache_t or -999) >= UI.TTL then
		UI._cache = _rebuild()
		UI._cache_t = t
		UI._world_scanned = false
	end
	if (requested_id == nil or not alive(UI._cache[requested_id])) and not UI._world_scanned then
		_add_world(UI._cache)
		UI._world_scanned = true
	end
	return UI._cache
end

function UI.invalidate()
	UI._cache = {}
	UI._cache_t = -999
	UI._world_scanned = false
end
