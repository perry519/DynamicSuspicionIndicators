-- Client sync-on detection: overlays host snapshot progress onto local observers.

if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.Detection = DI.Detection or {}
local SO = {}
DI.Detection.SyncOverlay = SO

local G = DI.Game
local alive = G.alive
local U = DI.Units

function SO.has_data(cfg)
	return cfg.enable_detection_sync ~= false
		and DI.Sync and DI.Sync.has_data and DI.Sync.has_data()
end

function SO.apply(R, cfg, now_t, pu, target_allowed)
	local D = DI.Detection
	local lookup = DI.UnitIndex.lookup(now_t)
	DI.Sync.iter_progress(function(obs_id, target_id, p, sync_phase)
		if type(p) ~= "number" or p <= 0.01 then return end
		local observer = lookup[obs_id]
		if not alive(observer) then return end
		if U.pacified(observer) then return end
		local kind = U.is_camera(observer) and "cam" or "npc"
		local phase = sync_phase or DI.Phase.UNCOVER
		local observer_cleared = D._client_obs_status[observer:key()] == 0 and phase ~= DI.Phase.SUSPICION
		if phase == DI.Phase.SUSPICION then
			if not cfg.show_early_unmasked_suspicion then return end
			if kind == "npc" and U.npc_kind(observer) == "civilian" then return end
		end
		if not observer_cleared then
			R.put(observer, p, kind, phase)
		end
		local target = lookup[target_id]
		if alive(target) and target ~= observer and target ~= pu and target_allowed(target) then
			R.put(target, p, "obj", phase, observer)
		end
	end)
end
