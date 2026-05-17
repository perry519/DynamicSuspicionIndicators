-- Sync orchestrator: host snapshot building + flush/receive lifecycle.
-- Wire codec in sync/codec.lua; transport in sync/transport.lua.

if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.Sync = DI.Sync or {}
local S = DI.Sync
local G = DI.Game
local alive = G.alive
local Codec     = S.Codec
local Transport = S.Transport

local FLUSH_INTERVAL     = 0.05
local HEARTBEAT_INTERVAL = 0.25
local RECV_STALE_SEC     = 0.5

S._last_flush_t       = 0
S._last_heartbeat_t   = 0
S._last_sent          = {}
S._client_progress    = {}
S._handlers_installed = false
S._was_enabled        = false
S._last_recv_t        = 0

local function _log_once(level, key, msg)
	DI.Logger.once(level, "sync:" .. tostring(key), msg)
end

local function _enabled()
	return _G.DP and _G.DP.settings and _G.DP.settings.enable_detection_sync == true
end

local function _clear_client_progress()
	S._client_progress = {}
end

------------------------------------------------------------
-- Snapshot
------------------------------------------------------------

local function _phase_for_entry_target(entry, target)
	local p = entry.uncover_progress
	if type(p) == "number" then return DI.Phase.UNCOVER, p end
	if entry.pause_expire_t then return DI.Phase.UNCOVER, nil end
	p = entry.notice_progress or entry.suspicion_progress
	if type(p) == "number" then
		if DI.Units.is_player_mask_off(target, G.player_unit()) then
			return DI.Phase.SUSPICION, p
		end
		return DI.Phase.UNCOVER, p
	end
	return DI.Phase.UNCOVER, nil
end

local function _add_observer(snap, observer, attention_objs, fallback_progress)
	if not (alive(observer) and observer.id) then return end
	local oid = observer:id()
	if not oid or oid == -1 then return end
	if type(attention_objs) ~= "table" then return end
	for _, e in pairs(attention_objs) do
		local target = e.unit
		local phase, p = _phase_for_entry_target(e, target)
		if type(p) ~= "number" and type(fallback_progress) == "number" then
			p = fallback_progress
		end
		if type(p) == "number" and p >= Codec.PROGRESS_FLOOR then
			if alive(target) and target.id then
				local tid = target:id()
				if tid and tid ~= -1 then
					local q = math.clamp(math.floor(p * 254 + 0.5), 0, 254)
					snap[oid .. ":" .. tid] = { q = q, phase = phase }
				end
			end
		end
	end
end

local function _build_snapshot()
	local snap = {}
	local function probe_npc(u)
		if not alive(u) then return end
		if DI.Units.disabled(u) then return end
		local b = u.brain and u:brain()
		local ld = b and b._logic_data
		if ld and type(ld.detected_attention_objects) == "table" then
			_add_observer(snap, u, ld.detected_attention_objects)
		end
	end
	for _, e in pairs(G.enemies() or {}) do probe_npc(e.unit) end
	for _, e in pairs(G.civilians() or {}) do probe_npc(e.unit) end
	for _, cu in pairs(G.security_cameras()) do
		if alive(cu) and cu.base and cu:base() then
			local b = cu:base()
			local d = b._detected_attention_objects or b._attention_objects
			if type(d) == "table" then _add_observer(snap, cu, d, b._suspicion) end
		end
	end
	return snap
end

------------------------------------------------------------
-- Public API
------------------------------------------------------------

function S.host_flush(t)
	local enabled = _enabled()
	local is_server = G.is_server()
	local has_session = G.session() ~= nil
	local has_net = G.has_network()

	if S._was_enabled and not enabled and is_server and has_session and has_net then
		Transport.send(G.send, "")
		S._last_sent = {}
		S._last_heartbeat_t = 0
		S._was_enabled = false
		return
	end
	S._was_enabled = enabled

	if not enabled then
		if next(S._last_sent) ~= nil then S._last_sent = {} end
		S._last_heartbeat_t = 0
		return
	end
	if is_server and has_session and not has_net then
		_log_once("warn", "missing-luanetworking", "detection sync enabled but LuaNetworking is unavailable")
	end
	if not (is_server and has_session and has_net) then return end
	if (t - S._last_flush_t) < FLUSH_INTERVAL then return end

	local snap = _build_snapshot()
	if not Codec.has_significant_change(snap, S._last_sent) then
		if next(snap) ~= nil and (t - (S._last_heartbeat_t or 0)) >= HEARTBEAT_INTERVAL then
			Transport.send(G.send, Codec.serialize(snap, true))
			S._last_heartbeat_t = t
		end
		S._last_flush_t = t
		return
	end

	Transport.send(G.send, Codec.serialize(snap))
	S._last_sent       = snap
	S._last_flush_t    = t
	S._last_heartbeat_t = t
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
	if next(S._client_progress) ~= nil and S._last_recv_t > 0
		and (os.clock() - S._last_recv_t) > RECV_STALE_SEC then
		_clear_client_progress()
		return false
	end
	return next(S._client_progress) ~= nil
end

local function _on_received(sender, message_type, data)
	if message_type ~= Transport.MSG_ID then return end
	if not _enabled() then
		_clear_client_progress()
		return
	end
	local payload = Transport.decode(sender, data)
	if payload == nil then return end
	local stats = {}
	S._client_progress = Codec.merge_client_progress(S._client_progress, Codec.deserialize(payload, stats))
	S._last_recv_t = os.clock()
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
	S._last_sent = {}
end

function S.install()
	if S._handlers_installed then return end
	if not _G.Hooks then
		_log_once("warn", "missing-hooks", "sync handlers not installed: Hooks unavailable")
		return
	end
	G.on_event("NetworkReceivedData",               "DSI_NetworkReceivedData", _on_received)
	G.on_event("BaseNetworkSessionOnPeerRemoved",   "DSI_OnPeerRemoved",       _reset_session_state)
	G.on_event("BaseNetworkSessionOnLoadComplete",  "DSI_OnLoadComplete",      _reset_session_state)
	S._handlers_installed = true
	if DI._log then DI._log("sync handlers installed") end
end
