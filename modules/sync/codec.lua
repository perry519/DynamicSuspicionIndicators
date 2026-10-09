-- Sync wire codec: pure encode/decode + diff.

if not DynamicSuspicionIndicatorsManager then
	return
end
local DI = DynamicSuspicionIndicatorsManager
DI.Sync = DI.Sync or {}
local Codec = {}
DI.Sync.Codec = Codec

Codec.DELTA_THRESHOLD = 1
Codec.PROGRESS_FLOOR = 0.01
Codec.MAX_VERSION = 65535

local function _phase_code(phase)
	return phase == DI.Phase.SUSPICION and ":s" or ""
end

local function _encode_entry(k, entry)
	return k .. ":" .. entry.q .. _phase_code(entry.phase)
end

function Codec.full(map, ver)
	local parts = { "F" .. ver }
	for k, entry in pairs(map) do
		parts[#parts + 1] = _encode_entry(k, entry)
	end
	return table.concat(parts, "|")
end

function Codec.diff(snap, last_sent, base, ver)
	local parts, next_sent = { "D" .. base .. ">" .. ver }, {}
	for k, entry in pairs(snap) do
		local prev = last_sent[k]
		if prev and math.abs(entry.q - prev.q) < Codec.DELTA_THRESHOLD and entry.phase == prev.phase then
			next_sent[k] = prev
		else
			next_sent[k] = entry
			parts[#parts + 1] = _encode_entry(k, entry)
		end
	end
	for k in pairs(last_sent) do
		if not snap[k] then
			parts[#parts + 1] = "x" .. k
		end
	end
	if #parts == 1 then
		return nil, last_sent
	end
	return table.concat(parts, "|"), next_sent
end

function Codec.keepalive(ver)
	return "K" .. ver
end

local function _decode_entry(out, item, stats)
	local obs, tgt, q, pc = item:match("^(%-?%d+):(%-?%d+):(%-?%d+):?(s?)$")
	local qn = tonumber(q)
	if not (obs and tgt and qn) then
		stats.invalid = (stats.invalid or 0) + 1
		return
	end
	if qn < 0 or qn > 254 then
		stats.clamped = (stats.clamped or 0) + 1
	end
	out[obs .. ":" .. tgt] = {
		p = math.clamp(qn / 254, 0, 1),
		phase = pc == "s" and DI.Phase.SUSPICION or DI.Phase.UNCOVER,
	}
end

function Codec.apply(state, ver, str, stats)
	stats = stats or {}
	if type(str) ~= "string" then
		return nil
	end
	local header, body = str:match("^([^|]*)|?(.*)$")
	local kind = header:sub(1, 1)
	if kind == "K" then
		local v = tonumber(header:match("^K(%d+)$"))
		if v and v == ver then
			return state, v
		end
		return nil
	end
	if kind == "F" then
		local v = tonumber(header:match("^F(%d+)$"))
		if not v then
			stats.invalid = (stats.invalid or 0) + 1
			return nil
		end
		local out = {}
		for item in body:gmatch("[^|]+") do
			_decode_entry(out, item, stats)
		end
		return out, v
	end
	local base, v = header:match("^D(%d+)>(%d+)$")
	base, v = tonumber(base), tonumber(v)
	if not (base and v) then
		stats.invalid = (stats.invalid or 0) + 1
		return nil
	end
	if base ~= ver then
		return nil
	end
	for item in body:gmatch("[^|]+") do
		local removed = item:match("^x(%-?%d+:%-?%d+)$")
		if removed then
			state[removed] = nil
		else
			_decode_entry(state, item, stats)
		end
	end
	return state, v
end
