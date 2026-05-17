if _G.DynamicSuspicionIndicators_Inited then return end
_G.DynamicSuspicionIndicators_Inited = true

DynamicSuspicionIndicatorsManager = DynamicSuspicionIndicatorsManager or {}
local DI = DynamicSuspicionIndicatorsManager

DI.smooth_speed = 5
DI.mod_path     = "mods/DynamicSuspicionIndicators/"
DI.demo_mode    = false

DI._log = function(msg) DI.Logger.dbg(msg) end

-- Load modules. Order matters: leaves first, dependants last.
dofile(DI.mod_path .. "modules/infra/logger.lua")
dofile(DI.mod_path .. "modules/settings/schema.lua")
dofile(DI.mod_path .. "modules/infra/color.lua")
dofile(DI.mod_path .. "modules/infra/assets.lua")
DI.Assets:register_textures(DI.mod_path)
dofile(DI.mod_path .. "modules/infra/game.lua")
dofile(DI.mod_path .. "modules/units.lua")
dofile(DI.mod_path .. "modules/suspicion/phase.lua")
dofile(DI.mod_path .. "modules/policy/target.lua")
dofile(DI.mod_path .. "modules/suspicion/records.lua")
dofile(DI.mod_path .. "modules/units/index.lua")
dofile(DI.mod_path .. "modules/sync/codec.lua")
dofile(DI.mod_path .. "modules/sync/transport.lua")
dofile(DI.mod_path .. "modules/sync.lua")
dofile(DI.mod_path .. "modules/detection/host.lua")
dofile(DI.mod_path .. "modules/detection/client/sync_overlay.lua")
dofile(DI.mod_path .. "modules/detection/client/fallback.lua")
dofile(DI.mod_path .. "modules/detection/client.lua")
dofile(DI.mod_path .. "modules/hud/view.lua")
dofile(DI.mod_path .. "modules/hud/glyph.lua")
dofile(DI.mod_path .. "modules/hud/waypoint_render.lua")
dofile(DI.mod_path .. "modules/hud/waypoint.lua")
dofile(DI.mod_path .. "modules/hud/item.lua")
dofile(DI.mod_path .. "modules/hud/demo.lua")

local function _settings()
	return DI.SettingsSchema.normalized((_G.DP and _G.DP.settings) or {}, DI.smooth_speed)
end

function DI:_ensure_panel()
	if self._inited then return true end
	local G = DI.Game
	local hud_id = G.player_hud_id()
	if not (hud_id and setup) then return false end
	local hud = G.hud_script(hud_id)
	if not (hud and hud.panel) then return false end
	local panel = hud.panel:panel({ name = "detection_percent", layer = 1000 })
	local ws    = G.gui_fullscreen_workspace()
	if not ws then return false end
	DI.HudItem.init_panel(panel, ws)
	if not setup._dp_update_orig then
		setup._dp_update_orig = setup.update
		setup.update = function(s, t, dt)
			setup._dp_update_orig(s, t, dt)
			DI:_update(t, dt)
		end
	end
	DI.Assets:register_textures(self.mod_path)
	DI.WaypointOverlay:install_hooks()
	if DI.Sync and DI.Sync.install then DI.Sync.install() end
	self._inited = true
	DI.Logger.info(string.format("loaded (hud %dx%d)", hud.panel:w(), hud.panel:h()))
	return true
end

function DI:_update(t, dt)
	if not self:_ensure_panel() then return end

	local G   = DI.Game
	local R   = DI.Records
	local cfg = _settings()
	local wo_deps = { npc_kind = DI.Units.npc_kind, records = R.records, cfg = cfg }

	if DI.demo_mode then
		DI.HudItem.destroy_all()
		DI.HudItem.place_demo(cfg)
		DI.WaypointOverlay:update({ npc_kind = DI.Units.npc_kind, records = {}, cfg = cfg })
		return
	end

	if not G.whisper_mode() then
		DI.HudItem.destroy_all()
		DI.HudItem.destroy_demo()
		R.clear()
		wo_deps.records = R.records
		DI.WaypointOverlay:update(wo_deps)
		return
	end

	if G.is_client() then
		DI.Detection.collect_client(cfg, t)
	else
		DI.Detection.collect(cfg)
		if DI.Sync and DI.Sync.host_flush then DI.Sync.host_flush(t) end
	end

	local cam = G.camera()
	if not cam then return end

	local roles, allowed = R.tick(t, dt, cfg)
	wo_deps.records = R.records
	DI.HudItem.place_records(R.records, roles, allowed, cfg, cam)
	DI.HudItem.destroy_demo()
	DI.WaypointOverlay:update(wo_deps)
end

local function _reset_client_state()
	local D = DI.Detection
	if D then
		D._client_peer_susp    = {}
		D._client_obs_status   = {}
		D._los_cache           = {}
		D._client_sync_active  = nil
		D._camera_susp_seq     = 0
		D._camera_susp_seen    = {}
		D._camera_fb_min_seq   = 0
		D._cam_lvl_prev        = {}
	end
	DI.Records._alert_flash = {}
	DI.Records._target_alerts = {}
	DI.Records._target_peaks = {}
	DI.Records._observer_alerts = {}
	DI.Records._prev        = {}
	DI.Records._smooth      = {}
	DI.Records._smooth_phase = {}
	if DI.UnitIndex and DI.UnitIndex.invalidate then DI.UnitIndex.invalidate() end
	DI.WaypointOverlay:destroy_all()
end

DI.Game.on_event("GameSetupNewGame",                "DI_ResetClientState",     _reset_client_state)
DI.Game.on_event("LocalPlayerMovedToGameStateBase", "DI_ResetClientStateJoin", _reset_client_state)

DI:_ensure_panel()
DI.Logger.info("loaded")
