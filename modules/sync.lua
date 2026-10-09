-- Sync orchestrator: host snapshot building + flush/receive lifecycle.
-- Wire codec in sync/codec.lua; transport in sync/transport.lua.

if not DynamicSuspicionIndicatorsManager then
	return
end
local DI = DynamicSuspicionIndicatorsManager
DI.Sync = DI.Sync or {}
local S = DI.Sync
local G = DI.Game
local alive = G.alive
local C = DI.ClientStealth
local Codec = S.Codec
local Transport = S.Transport

local FLUSH_INTERVAL = 0.05
local HEARTBEAT_INTERVAL = 0.5
local KEYFRAME_INTERVAL = 3
local CHUNK_RATE = 12
local CHUNK_BURST = 24
local RECV_STALE_SEC = 1.25

S._last_flush_t = 0
S._last_send_t = 0
S._last_keyframe_t = 0
S._tokens = CHUNK_BURST
S._ver = 0
S._peers_sig = nil
S._last_sent = {}
S._client_progress = {}
S._client_ver = nil
S._handlers_installed = false
S._was_enabled = false
S._last_recv_t = 0

local function _log_once(level, key, msg)
	DI.Logger.once(level, "sync:" .. tostring(key), msg)
end

local function _enabled()
	return _G.DP and _G.DP.settings and _G.DP.settings.enable_detection_sync == true
end

local function _clear_client_progress()
	S._client_progress = {}
	S._client_ver = nil
end

local function _reset_host_state()
	S._last_sent = {}
	S._last_flush_t = 0
	S._last_send_t = 0
	S._last_keyframe_t = 0
	S._tokens = CHUNK_BURST
	S._peers_sig = nil
end

local function _send(payload, t)
	Transport.send(G.send, payload)
	S._tokens = S._tokens - math.max(1, math.ceil(#payload / Transport.MAX_PAYLOAD_BYTES))
	S._last_send_t = t
end

local function _next_ver()
	return S._ver % Codec.MAX_VERSION + 1
end

local function _peers_sig(peers)
	local ids = {}
	for id in pairs(peers) do
		ids[#ids + 1] = tostring(id)
	end
	table.sort(ids)
	return table.concat(ids, ",")
end

local function _phase_for_entry_target(entry, target)
	local p = entry.uncover_progress
	if type(p) == "number" then
		return DI.Phase.UNCOVER, p
	end
	if entry.pause_expire_t then
		return DI.Phase.UNCOVER, nil
	end
	p = entry.notice_progress or entry.suspicion_progress
	if type(p) == "number" then
		if DI.Units.is_player_mask_off(target, G.player_unit()) then
			return DI.Phase.SUSPICION, p
		end
		return DI.Phase.UNCOVER, p
	end
	return DI.Phase.UNCOVER, nil
end

local function _observer_only_target(ctx, target)
	local only = ctx.observer_only[target]
	if only == nil then
		only = (G.is_enemy(target) or G.is_civilian(target)) and not DI.Units.targetable(target, ctx.groupai)
		ctx.observer_only[target] = not not only
	end
	return only
end

local function _add_observer(ctx, observer, attention_objs, fallback_progress, check_disabled)
	if not (alive(observer) and observer.id) then
		return
	end
	local oid = observer:id()
	if not oid or oid == -1 then
		return
	end
	if type(attention_objs) ~= "table" then
		return
	end
	local snap, best, best_key = ctx.snap, nil, nil
	for _, e in pairs(attention_objs) do
		local target = e.unit
		local phase, p = _phase_for_entry_target(e, target)
		if type(p) ~= "number" and type(fallback_progress) == "number" then
			p = fallback_progress
		end
		if type(p) == "number" and p >= Codec.PROGRESS_FLOOR and DI.Phase.is_suspicious(e) then
			if check_disabled then
				if DI.Units.disabled(observer) then
					return
				end
				check_disabled = false
			end
			if alive(target) and target.id then
				local tid = target:id()
				if tid and tid ~= -1 and not (phase == DI.Phase.SUSPICION and G.is_civilian(observer)) then
					local key = oid .. ":" .. tid
					local rec = { q = math.clamp(math.floor(p * 254 + 0.5), 0, 254), phase = phase }
					if not _observer_only_target(ctx, target) then
						snap[key] = rec
					elseif
						not best
						or rec.q > best.q
						or (rec.q == best.q and S._last_sent[key] and not S._last_sent[best_key])
					then
						best, best_key = rec, key
					end
				end
			end
		end
	end
	if best then
		snap[best_key] = best
	end
end

local function _build_snapshot()
	local ctx = { snap = {}, observer_only = {}, groupai = G.groupai() }
	local function probe_npc(u)
		if not alive(u) then
			return
		end
		local b = u.brain and u:brain()
		local ld = b and b._logic_data
		local entries = ld and ld.detected_attention_objects
		if type(entries) ~= "table" or next(entries) == nil then
			return
		end
		_add_observer(ctx, u, entries, nil, true)
	end
	for _, e in pairs(G.enemies() or {}) do
		probe_npc(e.unit)
	end
	for _, e in pairs(G.civilians() or {}) do
		probe_npc(e.unit)
	end
	for _, cu in pairs(G.security_cameras()) do
		if alive(cu) and cu.base and cu:base() then
			local b = cu:base()
			local d = C.camera_detection_entries(b)
			if type(d) == "table" then
				_add_observer(ctx, cu, d, b._suspicion)
			end
		end
	end

	C.each_world_pair(function(observer, target, phase, value)
		local oid, tid = observer:id(), target:id()
		if oid ~= -1 and tid ~= -1 then
			ctx.snap[oid .. ":" .. tid] = phase == DI.Phase.UNCOVER
					and value
					and value >= Codec.PROGRESS_FLOOR
					and { q = math.clamp(math.floor(value * 254 + 0.5), 0, 254), phase = phase }
				or nil
		end
	end)
	return ctx.snap
end

function S.host_flush(t)
	local enabled = _enabled()
	local is_server = G.is_server()
	local session = G.session()
	local has_session = session ~= nil
	local has_net = G.has_network()

	if S._was_enabled and not enabled and is_server and has_session and has_net then
		S._ver = _next_ver()
		Transport.send(G.send, Codec.full({}, S._ver))
		_reset_host_state()
		S._was_enabled = false
		return
	end
	S._was_enabled = enabled

	if not enabled then
		_reset_host_state()
		return
	end
	if is_server and has_session and not has_net then
		_log_once("warn", "missing-luanetworking", "detection sync enabled but LuaNetworking is unavailable")
	end
	if not (is_server and has_session and has_net) then
		return
	end
	local peers = session:peers()
	if next(peers) == nil then
		_reset_host_state()
		return
	end
	if t < S._last_flush_t then
		_reset_host_state()
	elseif t - S._last_flush_t < FLUSH_INTERVAL then
		return
	else
		S._tokens = math.min(CHUNK_BURST, S._tokens + (t - S._last_flush_t) * CHUNK_RATE)
	end
	S._last_flush_t = t

	if S._tokens < 0 then
		if next(S._last_sent) ~= nil and t - S._last_send_t >= HEARTBEAT_INTERVAL then
			_send(Codec.keepalive(S._ver), t)
		end
		return
	end

	local snap = _build_snapshot()
	local ver = _next_ver()
	local sig = _peers_sig(peers)
	local payload, next_sent
	local keyframe_due = t - S._last_keyframe_t >= KEYFRAME_INTERVAL and (next(snap) or next(S._last_sent))
	if sig ~= S._peers_sig or S._last_keyframe_t == 0 or keyframe_due then
		payload, next_sent = Codec.full(snap, ver), snap
		S._peers_sig = sig
		S._last_keyframe_t = t
	else
		payload, next_sent = Codec.diff(snap, S._last_sent, S._ver, ver)
	end
	if payload then
		_send(payload, t)
		S._ver = ver
		S._last_sent = next_sent
	elseif next(S._last_sent) ~= nil and t - S._last_send_t >= HEARTBEAT_INTERVAL then
		_send(Codec.keepalive(S._ver), t)
	end
end

function S.iter_progress(cb)
	if not _enabled() then
		_clear_client_progress()
		return
	end
	for k, entry in pairs(S._client_progress) do
		local obs_str, tgt_str = k:match("(%-?%d+):(%-?%d+)")
		if obs_str and tgt_str then
			local p = type(entry) == "table" and entry.p or entry
			local phase = type(entry) == "table" and entry.phase or DI.Phase.UNCOVER
			cb(tonumber(obs_str), tonumber(tgt_str), p, phase)
		end
	end
end

function S.has_data()
	if not _enabled() then
		_clear_client_progress()
		return false
	end
	if next(S._client_progress) ~= nil and S._last_recv_t > 0 and (os.clock() - S._last_recv_t) > RECV_STALE_SEC then
		_clear_client_progress()
		return false
	end
	return next(S._client_progress) ~= nil
end

local function _on_received(sender, message_type, data)
	if message_type ~= Transport.MSG_ID then
		return
	end
	if not _enabled() then
		_clear_client_progress()
		return
	end
	local payload = Transport.decode(sender, data)
	if payload == nil then
		return
	end
	local stats = {}
	local state, ver = Codec.apply(S._client_progress, S._client_ver, payload, stats)
	if state then
		S._client_progress, S._client_ver = state, ver
		S._last_recv_t = os.clock()
	else
		S._client_ver = nil
	end
	if (stats.invalid or 0) > 0 then
		_log_once("warn", "invalid-entry", string.format("ignored %d invalid sync payload entries", stats.invalid))
	end
	if (stats.clamped or 0) > 0 then
		_log_once("warn", "clamped-entry", string.format("clamped %d out-of-range sync payload entries", stats.clamped))
	end
end

local function _reset_session_state()
	_clear_client_progress()
	Transport.reset()
	_reset_host_state()
end

function S.install()
	if S._handlers_installed then
		return
	end
	if not _G.Hooks then
		_log_once("warn", "missing-hooks", "sync handlers not installed: Hooks unavailable")
		return
	end
	G.on_event("NetworkReceivedData", "DSI_NetworkReceivedData", _on_received)
	G.on_event("BaseNetworkSessionOnPeerRemoved", "DSI_OnPeerRemoved", _reset_session_state)
	G.on_event("BaseNetworkSessionOnLoadComplete", "DSI_OnLoadComplete", _reset_session_state)
	S._handlers_installed = true
	if DI._log then
		DI._log("sync handlers installed")
	end
end
