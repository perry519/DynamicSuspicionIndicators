-- Sync wire transport

if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.Sync = DI.Sync or {}
local Transport = {}
DI.Sync.Transport = Transport

Transport.MSG_ID            = "DSI_susp_v1"
Transport.MAX_PAYLOAD_BYTES = 180

local _send_seq    = 0
local _recv_chunks = {}

local function _log_once(level, key, msg)
	DI.Logger.once(level, "sync:" .. tostring(key), msg)
end

function Transport.send(send_fn, payload)
	payload = payload or ""
	if #payload <= Transport.MAX_PAYLOAD_BYTES then
		send_fn(Transport.MSG_ID, payload)
		return
	end
	_send_seq = (_send_seq % 999999) + 1
	local total = math.ceil(#payload / Transport.MAX_PAYLOAD_BYTES)
	_log_once("debug", "chunked-send",
		string.format("sync payload chunked: %d bytes across %d chunks", #payload, total))
	for i = 1, total do
		local from = ((i - 1) * Transport.MAX_PAYLOAD_BYTES) + 1
		local chunk = payload:sub(from, from + Transport.MAX_PAYLOAD_BYTES - 1)
		send_fn(Transport.MSG_ID, string.format("C:%d:%d:%d:%s", _send_seq, i, total, chunk))
	end
end

function Transport.decode(sender, data)
	if type(data) ~= "string" then
		_log_once("warn", "non-string-payload", "ignored non-string sync payload")
		return nil
	end
	local seq, idx, total, chunk = data:match("^C:(%d+):(%d+):(%d+):(.*)$")
	if not seq then return data end
	idx = tonumber(idx)
	total = tonumber(total)
	if not (idx and total and total > 0 and idx >= 1 and idx <= total) then
		_log_once("warn", "invalid-chunk",
			string.format("ignored invalid sync chunk metadata from %s", tostring(sender)))
		return nil
	end
	local key = tostring(sender or "unknown") .. ":" .. seq
	local acc = _recv_chunks[key]
	if not acc then
		acc = { total = total, count = 0, parts = {} }
		_recv_chunks[key] = acc
	end
	if acc.total ~= total then
		_recv_chunks[key] = nil
		_log_once("warn", "chunk-total-mismatch",
			string.format("discarded sync chunk sequence with mismatched total from %s", tostring(sender)))
		return nil
	end
	if acc.parts[idx] == nil then
		acc.count = acc.count + 1
	end
	acc.parts[idx] = chunk or ""
	if acc.count < total then return nil end
	local parts = {}
	for i = 1, total do
		parts[#parts + 1] = acc.parts[i] or ""
	end
	_recv_chunks[key] = nil
	return table.concat(parts)
end

function Transport.reset()
	_recv_chunks = {}
end
