-- Client sync-on detection: overlays host snapshot progress onto local observers.

if not DynamicSuspicionIndicatorsManager then
	return
end
local DI = DynamicSuspicionIndicatorsManager
DI.Detection = DI.Detection or {}
local SO = DI.Detection.SyncOverlay or {}
DI.Detection.SyncOverlay = SO

local G = DI.Game
local alive = G.alive
local U = DI.Units
local C = DI.ClientStealth

function SO.has_data(cfg)
	return cfg.enable_detection_sync ~= false and DI.Sync and DI.Sync.has_data and DI.Sync.has_data()
end

function SO.apply(R, cfg, now_t, pu, target_allowed)
	local D = DI.Detection
	-- One collection cannot change NPC state; refresh these checks next frame.
	local observers, allowed_targets, cameras = {}, {}, {}
	for _, camera in pairs(G.security_cameras()) do
		cameras[camera] = true
	end
	local lookup
	local function resolve(id)
		if not lookup or not alive(lookup[id]) then
			lookup = DI.UnitIndex.lookup(now_t, id)
		end
		return lookup[id]
	end
	DI.Sync.iter_progress(function(obs_id, target_id, p, sync_phase)
		if type(p) ~= "number" or p <= 0.01 then
			return
		end
		local observer = resolve(obs_id)
		if not alive(observer) then
			return
		end
		local key = observers[observer]
		if key == nil then
			key = not U.pacified(observer) and observer:key() or false
			observers[observer] = key
		end
		if not key then
			return
		end
		local target = resolve(target_id)
		if C.excludes_owned_world and C.excludes_owned_world(target) then
			return
		end
		if C.has_pair(observer, target, target_id) then
			return
		end
		local kind = cameras[observer] and "cam" or "npc"
		local phase = sync_phase or DI.Phase.UNCOVER
		if C.excludes_synced(key, target_id, phase) then
			return
		end
		local observer_cleared = D._client_obs_status[key] == 0 and phase ~= DI.Phase.SUSPICION
		if phase == DI.Phase.SUSPICION then
			if not cfg.show_early_unmasked_suspicion then
				return
			end
			if kind == "npc" and U.npc_kind(observer) == "civilian" then
				return
			end
		end
		if not observer_cleared then
			R.put(observer, p, kind, phase, nil, target)
		end
		if alive(target) and target ~= observer and target ~= pu then
			local allowed = allowed_targets[target]
			if allowed == nil then
				allowed = not not target_allowed(target)
				allowed_targets[target] = allowed
			end
			if allowed then
				R.put(target, p, "obj", phase, observer)
			end
		end
	end)
end
