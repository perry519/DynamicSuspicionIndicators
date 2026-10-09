if not DynamicSuspicionIndicatorsManager then
	return
end
local DI = DynamicSuspicionIndicatorsManager
DI.ClientStealth = DI.ClientStealth or {}
local C = DI.ClientStealth
local G = DI.Game
local U = DI.Units
local alive = G.alive
local local_state, world_state

local function runtime()
	local cst = _G.ClientsideStealth
	return cst and cst.runtime and cst.runtime()
end

function C.reset()
	local_state, world_state = nil, nil
end

function C.refresh(include_local)
	local rt = runtime()
	local_state = include_local
			and rt
			and rt.local_detection_snapshot
			and rt:local_detection_snapshot(local_state, true)
		or nil
	world_state = rt and rt.world_detection_snapshot and rt:world_detection_snapshot() or nil
end

function C.camera_detection_entries(camera)
	local native = camera._detected_attention_objects or camera._attention_objects
	local cst = _G.ClientsideStealth
	local adapter = cst and cst.adapters and cst.adapters.camera
	local remote = adapter and adapter.detection_entries and adapter.detection_entries(camera)
	if not remote or next(remote) == nil then
		return native
	end
	local entries = {}
	for key, entry in pairs(native or {}) do
		entries[key] = entry
	end
	for key, entry in pairs(remote) do
		entries[key] = entry
	end
	return entries
end
local function is_suppressed(unit)
	local rt = runtime()
	return rt and rt.is_detection_suppressed and rt:is_detection_suppressed(unit) or false
end

function C.has_local_observer(key)
	return local_state ~= nil and local_state.observers[key] ~= nil
end

function C.excluded_peer(key)
	local owned = local_state and local_state.observers[key]
	return owned and not owned.notice_only and local_state.peer_id
end

function C.excludes_synced(key, target_id, phase)
	local owned = local_state and local_state.observers[key]
	return owned and target_id == local_state.player:id() and (not owned.notice_only or phase == DI.Phase.SUSPICION)
		or false
end

function C.excludes_owned_world(target)
	local rt = runtime()
	local target_record = rt and target and rt.target_for_unit and rt:target_for_unit(target)
	local core = rt and rt.core
	local local_peer_id = rt and rt.local_peer_id or core and core.local_peer_id
	if
		not rt
		or not rt.is_active
		or not rt:is_active()
		or not target_record
		or target_record.kind == "player"
		or not local_peer_id
	then
		return false
	end
	if type(rt.owns_detection) == "function" then
		local owned = rt:owns_detection(target_record.kind, target_record.id, local_peer_id)
		if owned ~= nil then
			return owned == true
		end
	end
	if not (core and core.get_owner) then
		return false
	end
	return core:get_owner(target_record.kind, target_record.id) == local_peer_id
end

function C.hides_unrecorded(key)
	local owned = (local_state and local_state.observers[key]) or (world_state and world_state[key])
	return owned ~= nil and not owned.notice_only and owned.uncover_progress ~= 0
end

function C.apply_local(R, cfg, pu, now_t)
	for _, entry in pairs(local_state and local_state.observers or {}) do
		if
			(entry.uncover_progress ~= nil or entry.notice_progress ~= nil or entry.suspicion_progress ~= nil)
			and not U.pacified(entry.unit)
		then
			local phase, p = DI.Phase.classify(entry, entry.notice_only or U.is_player_mask_off(pu, pu), false, now_t)
			if
				phase
				and (
					phase ~= DI.Phase.SUSPICION
					or cfg.show_early_unmasked_suspicion and U.npc_kind(entry.unit) ~= "civilian"
				)
			then
				R.put(entry.unit, p, entry.kind == "camera" and "cam" or "npc", phase, nil, pu)
			end
		end
	end
end

local function phase_progress(observed, target_state)
	if target_state.identified or target_state.alarmed then
		return DI.Phase.ALERTED, 1
	end
	local value = observed.kind == "camera" and (target_state.uncover_progress or target_state.suspicion_progress)
		or (target_state.uncover_progress or target_state.notice_progress)
	if value == nil and target_state.transition ~= "verified" then
		value = target_state.value
	end
	return DI.Phase.UNCOVER, value
end

function C.has_pair(observer, target, target_id)
	local snapshot = world_state
	if target and is_suppressed(target) then
		return true
	end
	if not (snapshot and observer and observer.key) then
		return false
	end
	local observed = snapshot[observer:key()]
	if not (observed and type(observed.targets) == "table") then
		return false
	end
	if target and target.key and observed.targets[target:key()] then
		return true
	end
	for _, target_state in pairs(observed.targets) do
		if target_id ~= nil and target_state.target_id == target_id then
			return true
		end
	end
	return false
end

function C.each_world_pair(fn)
	for _, observed in pairs(world_state or {}) do
		local observer = observed.unit
		if alive(observer) and not U.pacified(observer) then
			for _, target_state in pairs(observed.targets or {}) do
				local target = target_state.unit
				if alive(target) then
					local phase, value = phase_progress(observed, target_state)
					if type(value) ~= "number" or target_state.cleared or is_suppressed(target) then
						value = nil
					end
					fn(observer, target, phase, value, observed.kind)
				end
			end
		end
	end
end

function C.apply_world(records, player, target_allowed)
	C.each_world_pair(function(observer, target, phase, value, kind)
		if value and value > 0.01 then
			kind = kind == "camera" and "cam" or "npc"
			records.put(observer, value, kind, phase, nil, target)
			if target ~= player and target_allowed(target) then
				records.put(target, value, "obj", phase, observer)
			end
		end
	end)
end
