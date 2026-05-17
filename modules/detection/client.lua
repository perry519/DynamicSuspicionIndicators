-- Client detection orchestrator.

if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.Detection = DI.Detection or {}
local D = DI.Detection
local G = DI.Game
local alive = G.alive
local U = DI.Units
local TP = DI.TargetPolicy
local SO = D.SyncOverlay
local Fallback = D.Fallback

D._client_peer_susp   = D._client_peer_susp   or {}
D._client_obs_status  = D._client_obs_status  or {}
D._client_handlers_in = D._client_handlers_in or false
D._client_dump_t      = D._client_dump_t      or 0

local function _cam_is_alert(status)
	return status == 2 or status == 3 or status == 4 or status == 5
end

local function _install_handlers()
	if DI.Sync and DI.Sync.install then DI.Sync.install() end

	if D._client_handlers_in then return end
	if not G.has_unit_network_handler() then
		DI.Logger.once("debug", "client:no-unit-network-handler", "client net handlers not ready: UnitNetworkHandler unavailable")
		return
	end

	G.patch_unit_network_handler("suspicion", "_dsi_susp_orig", function(self, orig, suspect_peer_id, susp_value, sender)
		if type(suspect_peer_id) == "number" and type(susp_value) == "number" then
			D._client_peer_susp[suspect_peer_id] = math.clamp(susp_value / 254, 0, 1)
		end
		return orig(self, suspect_peer_id, susp_value, sender)
	end)

	G.patch_unit_network_handler("suspicion_hud", "_dsi_susp_hud_orig", function(self, orig, observer_unit, status, sender)
		if alive(observer_unit) and type(status) == "number" then
			D._client_obs_status[observer_unit:key()] = status
		end
		return orig(self, observer_unit, status, sender)
	end)

	Fallback.install_camera_event_patch()

	D._client_handlers_in = true
	DI.Logger.info("client net handlers installed")
end

local function _emit_alert(R, observer, kind, now_t, pu, target_allowed)
	local p, phase = 1.0, DI.Phase.ALERTED
	R.note_observer_alerted(observer, now_t)
	R.put(observer, p, kind, phase)
	if kind ~= "cam" then return end
	local m = observer.movement and observer:movement()
	local att = m and m.attention and m:attention()
	local target = att and att.unit
	if alive(target) and target ~= observer and target ~= pu and target_allowed(target) then
		R.put(target, p, "obj", phase, observer)
	end
end

function D.collect_client(cfg, t)
	if G.is_server() then return end
	local R = DI.Records
	R.clear()
	_install_handlers()

	local g = G.groupai()
	local susp = g and g._suspicion_hud_data
	if type(susp) ~= "table" then
		DI.Logger.once("debug", "client:no-suspicion-hud-data", "client suspicion HUD data unavailable")
		return
	end

	local now_t = t or G.now()

	if DI.Logger.is_debug() and now_t - (D._client_dump_t or 0) >= 2.0 then
		D._client_dump_t = now_t
		local n = 0; for _ in pairs(susp) do n = n + 1 end
		DI.Logger.dbg(string.format("client tick: observers=%d", n))
	end

	local pu = G.player_unit()
	local sync_active = SO.has_data(cfg)

	if D._client_sync_active ~= nil and D._client_sync_active ~= sync_active then
		R._smooth, R._alert_flash, R._prev = {}, {}, {}
		DI.Logger.dbg("client sync overlay " .. (sync_active and "active" or "inactive; using vanilla fallback"))
		if not sync_active then
			Fallback.on_mode_switch_to_fallback()
			D._client_peer_susp = {}
		end
	end
	D._client_sync_active = sync_active

	local target_allowed = TP.make_allowed(cfg, {
		player_unit = pu,
		include_enemy_lookup = true,
		include_civilian_lookup = true,
		groupai_state = G.groupai(),
	})

	local fctx
	if not sync_active then
		fctx = Fallback.prepare(cfg, pu, D._client_peer_susp, now_t)
		Fallback.emit_player_records(R, cfg, pu, fctx, target_allowed)
	end

	for _, sd in pairs(susp) do
		local u = sd.u_observer
		if alive(u) and not U.is_camera(u) then
			local status = D._client_obs_status[u:key()]
			if _cam_is_alert(status) then
				_emit_alert(R, u, "npc", now_t, pu, target_allowed)
			elseif not sync_active then
				Fallback.tick_npc(R, u, cfg, fctx)
			end
		end
	end

	local cameras = G.security_cameras()
	if next(cameras) then
		local single_cam_only = false
		if not sync_active then
			local curious_cams = Fallback.count_curious_cams(cameras, D._client_obs_status, _cam_is_alert)
			local npc_curious = 0
			for _, rec in pairs(R.records) do
				if rec.kind == "npc" and rec.phase ~= DI.Phase.ALERTED then
					npc_curious = npc_curious + 1
				end
			end
			single_cam_only = curious_cams == 1 and npc_curious == 0
		end

		for _, camu in pairs(cameras) do
			if alive(camu) and camu.base and camu:base() then
				local cam_key = camu:key()
				local status = D._client_obs_status[cam_key]
				if _cam_is_alert(status) then
					_emit_alert(R, camu, "cam", now_t, pu, target_allowed)
				elseif not sync_active then
					Fallback.tick_cam(R, camu, cam_key, cfg, fctx, target_allowed, single_cam_only, pu)
				end
			end
		end
	end

	-- Sync overlay: apply host snapshot progress on top of alert records.
	if sync_active then
		local sync_target_allowed = TP.make_allowed(cfg, {
			player_unit = pu,
			include_enemy_lookup = true,
			include_civilian_lookup = true,
			groupai_state = G.groupai(),
			require_npc_targetable = false,
		})
		SO.apply(R, cfg, now_t, pu, sync_target_allowed)
	end
end
