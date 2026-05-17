-- Sync wire codec: pure encode/decode + diff.

if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.Sync = DI.Sync or {}
local Codec = {}
DI.Sync.Codec = Codec

Codec.DELTA_THRESHOLD = 1
Codec.PROGRESS_FLOOR  = 0.01

local function _entry_q(entry)
	return type(entry) == "table" and entry.q or entry
end

local function _entry_phase(entry)
	if type(entry) == "table" then return entry.phase or DI.Phase.UNCOVER end
	return DI.Phase.UNCOVER
end

Codec.entry_q     = _entry_q
Codec.entry_phase = _entry_phase

local function _phase_code(phase)
	return phase == DI.Phase.SUSPICION and "s" or ""
end

local function _phase_from_code(code)
	return type(code) == "string" and code:find("s", 1, true) and DI.Phase.SUSPICION or DI.Phase.UNCOVER
end

function Codec.serialize(map, keepalive)
	local parts = {}
	for k, entry in pairs(map) do
		local q = _entry_q(entry)
		if type(q) == "number" then
			local code = _phase_code(_entry_phase(entry)) .. (keepalive and "k" or "")
			parts[#parts + 1] = k .. ":" .. q .. (code ~= "" and (":" .. code) or "")
		end
	end
	return table.concat(parts, "|")
end

function Codec.deserialize(str, stats)
	local out = {}
	if type(str) ~= "string" or str == "" then return out end
	for entry in str:gmatch("[^|]+") do
		if stats then stats.entries = (stats.entries or 0) + 1 end
		local obs, tgt, q, pc = entry:match("^(%-?%d+):(%-?%d+):(%-?%d+):?([sku]*)$")
		if obs and tgt and q then
			local qn = tonumber(q)
			if stats and qn and (qn < 0 or qn > 254) then
				stats.clamped = (stats.clamped or 0) + 1
			end
			out[obs .. ":" .. tgt] = {
				p     = math.clamp(qn / 254, 0, 1),
				phase = _phase_from_code(pc),
				keepalive = type(pc) == "string" and pc:find("k", 1, true) ~= nil,
			}
		elseif stats then
			stats.invalid = (stats.invalid or 0) + 1
		end
	end
	return out
end

function Codec.merge_client_progress(prev, incoming)
	local heartbeat = false
	for _, entry in pairs(incoming) do
		if type(entry) == "table" and entry.keepalive then
			heartbeat = true
			break
		end
	end
	if not heartbeat then
		for _, entry in pairs(incoming) do
			if type(entry) == "table" then entry.keepalive = nil end
		end
		return incoming
	end

	local refreshed = {}
	for k, entry in pairs(incoming) do
		local cur = prev[k]
		if type(cur) == "table" then
			cur.phase = entry.phase or cur.phase
			refreshed[k] = cur
		elseif type(cur) == "number" then
			refreshed[k] = { p = cur, phase = entry.phase or DI.Phase.UNCOVER }
		end
	end
	return refreshed
end

function Codec.has_significant_change(snap, last_sent)
	for k, entry in pairs(snap) do
		local q = _entry_q(entry)
		local prev = last_sent[k]
		local prev_q = _entry_q(prev)
		if not prev or not prev_q or math.abs(q - prev_q) >= Codec.DELTA_THRESHOLD then return true end
		if _entry_phase(entry) ~= _entry_phase(prev) then return true end
	end
	for k in pairs(last_sent) do
		if not snap[k] then return true end
	end
	return false
end
