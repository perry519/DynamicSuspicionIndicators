-- Host/SP detection collection

if not DynamicSuspicionIndicatorsManager then
	return
end
local DI = DynamicSuspicionIndicatorsManager
DI.Detection = DI.Detection or {}
local D = DI.Detection
local G = DI.Game
local alive = G.alive
local U = DI.Units
local TP = DI.TargetPolicy
local C = DI.ClientStealth

local first_logged = false
local function _log_first_fields(entry)
	if first_logged or type(entry) ~= "table" then
		return
	end
	first_logged = true
	local keys = {}
	for k, v in pairs(entry) do
		table.insert(keys, tostring(k) .. "=" .. type(v))
	end
	DI.Logger.dbg("first attention entry fields: " .. table.concat(keys, ", "))
end

function D.collect(cfg)
	local R = DI.Records
	R.clear()
	C.reset()

	local enemies = G.enemies()
	local civilians = G.civilians()
	if not (enemies or civilians) then
		return
	end
	local pu = G.player_unit()
	if not alive(pu) then
		return
	end
	local groupai_state = G.groupai()
	C.refresh(false)

	local target_allowed = TP.make_allowed(cfg, {
		player_unit = pu,
		include_enemy_lookup = true,
		include_civilian_lookup = true,
		groupai_state = groupai_state,
	})

	local function process_entry(entry, owner, owner_kind, t, fallback_p)
		if not DI.Phase.is_suspicious(entry) then
			return
		end
		local au = entry.unit
		if C.has_pair(owner, au) then
			return
		end
		local phase, p = DI.Phase.classify(entry, true, false, t)
		if not phase and type(fallback_p) == "number" and fallback_p > 0.01 then
			phase = DI.Phase.UNCOVER
			p = math.clamp(fallback_p, 0, 1)
		end
		if not (phase and type(p) == "number") then
			return
		end
		if phase == DI.Phase.SUSPICION and not U.is_player_mask_off(au, pu) then
			phase = DI.Phase.UNCOVER
		end
		if phase == DI.Phase.SUSPICION then
			if not cfg.show_early_unmasked_suspicion then
				return
			end
			if owner_kind == "npc" and U.npc_kind(owner) == "civilian" then
				return
			end
		end
		_log_first_fields(entry)
		R.put(owner, p, owner_kind, phase, nil, au)
		if alive(au) and au ~= pu and target_allowed(au) then
			R.put(au, p, "obj", phase, owner)
		end
	end

	local function probe_npc(npc)
		if not alive(npc) or not npc.brain then
			return
		end
		local brain = npc:brain()
		if not brain or not brain._logic_data then
			return
		end
		local ld = brain._logic_data
		if type(ld.detected_attention_objects) ~= "table" or next(ld.detected_attention_objects) == nil then
			return
		end
		if U.disabled(npc) then
			return
		end
		for _, e in pairs(ld.detected_attention_objects) do
			process_entry(e, npc, "npc", ld.t)
		end
	end

	local function probe_cam(camu)
		if not (alive(camu) and camu.base and camu:base()) then
			return
		end
		local b = camu:base()
		local d = C.camera_detection_entries(b)
		if type(d) ~= "table" then
			return
		end
		for _, e in pairs(d) do
			process_entry(e, camu, "cam", 0, b._suspicion)
		end
	end

	local function gather(getter, action)
		for _, e in pairs(getter() or {}) do
			if alive(e.unit) then
				action(e.unit)
			end
		end
	end

	if enemies then
		gather(function()
			return enemies
		end, probe_npc)
	end
	if civilians then
		gather(function()
			return civilians
		end, probe_npc)
	end

	for _, camu in pairs(G.security_cameras()) do
		probe_cam(camu)
	end
	C.apply_world(R, pu, target_allowed)
end
