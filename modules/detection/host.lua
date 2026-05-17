-- Host/SP detection collection

if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.Detection = DI.Detection or {}
local D = DI.Detection
local G = DI.Game
local alive = G.alive
local U = DI.Units
local TP = DI.TargetPolicy

local first_logged = false
local function _log_first_fields(entry)
	if first_logged or type(entry) ~= "table" then return end
	first_logged = true
	local keys = {}
	for k, v in pairs(entry) do table.insert(keys, tostring(k) .. "=" .. type(v)) end
	DI.Logger.dbg("first attention entry fields: " .. table.concat(keys, ", "))
end

function D.collect(cfg)
	local R  = DI.Records
	R.clear()

	local enemies   = G.enemies()
	local civilians = G.civilians()
	if not (enemies or civilians) then return end
	local pu = G.player_unit()
	if not alive(pu) then return end
	local pkey = pu:key()
	local groupai_state = G.groupai()
	local in_casing = G.current_state() == "mask_off"

	local npc_units = {}
	local target_allowed = TP.make_allowed(cfg, {
		player_unit = pu,
		npc_units = npc_units,
		groupai_state = groupai_state,
	})

	local function process_entry(att_key, entry, owner, owner_kind, t, fallback_p)
		local au = entry.unit
		local is_player_target = (att_key == pkey) or (alive(au) and au == pu)
			or (alive(au) and U.is_other_player(au, pu))
		local target_in_casing = false
		if in_casing and is_player_target and alive(au) then
			local mov = au.movement and au:movement()
			local state = mov and (mov._current_state_name or mov._state)
			target_in_casing = state == "mask_off"
		end
		local phase, p = DI.Phase.classify(entry, target_in_casing, false, t)
		if not phase and type(fallback_p) == "number" and fallback_p > 0.01 then
			phase = DI.Phase.UNCOVER
			p = math.clamp(fallback_p, 0, 1)
		end
		if not (phase and type(p) == "number") then return end
		if phase == DI.Phase.SUSPICION then
			if not cfg.show_early_unmasked_suspicion then return end
			if owner_kind == "npc" and U.npc_kind(owner) == "civilian" then return end
		end
		_log_first_fields(entry)
		R.put(owner, p, owner_kind, phase)
		if alive(au) and au ~= pu and target_allowed(au) then
			R.put(au, p, "obj", phase, owner)
		end
	end

	local function probe_npc(npc)
		if not alive(npc) or not npc.brain then return end
		if U.alerted(npc) then R.note_observer_alerted(npc, G.now()) end
		if U.disabled(npc) then return end
		local brain = npc:brain()
		if not brain or not brain._logic_data then return end
		local ld = brain._logic_data
		if type(ld.detected_attention_objects) ~= "table" then return end
		for k, e in pairs(ld.detected_attention_objects) do
			process_entry(k, e, npc, "npc", ld.t)
		end
	end

	local function probe_cam(camu)
		if not (alive(camu) and camu.base and camu:base()) then return end
		local b = camu:base()
		local d = b._detected_attention_objects or b._attention_objects
		if type(d) ~= "table" then return end
		for k, e in pairs(d) do
			process_entry(k, e, camu, "cam", 0, b._suspicion)
		end
	end

	local function gather(getter, action)
		for _, e in pairs(getter() or {}) do
			if alive(e.unit) then action(e.unit) end
		end
	end

	local mark_npc = function(u) npc_units[u:key()] = true end
	if enemies   then gather(function() return enemies   end, mark_npc) end
	if civilians then gather(function() return civilians end, mark_npc) end
	if enemies   then gather(function() return enemies   end, probe_npc) end
	if civilians then gather(function() return civilians end, probe_npc) end

	for _, camu in pairs(G.security_cameras()) do probe_cam(camu) end
end
