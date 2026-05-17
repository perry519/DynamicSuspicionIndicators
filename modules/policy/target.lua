-- Shared target visibility policy for host/client detection paths.

if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.TargetPolicy = DI.TargetPolicy or {}
local P = DI.TargetPolicy
local G = DI.Game
local alive = G.alive
local U = DI.Units

local function _npc_target_allowed(target, cfg, ctx)
	if not cfg.target_subdued_npcs then return false end
	if ctx.require_npc_disabled == true then return U.disabled(target) or U.targetable(target, ctx.groupai_state) end
	if ctx.require_npc_targetable == false then return true end
	return U.targetable(target, ctx.groupai_state)
end

function P.allowed(target, cfg, ctx)
	ctx = ctx or {}
	if not (alive(target) and cfg.show_targets) then return false end

	local pu = ctx.player_unit
	if pu and U.is_other_player(target, pu) then return cfg.target_other_players end
	if U.is_camera(target) then return cfg.target_subdued_npcs end
	if U.is_dead(target) then return cfg.target_subdued_npcs end
	if U.alerted(target) and not U.pacified(target) then return false end

	if ctx.npc_units and target.key then
		local key = target:key()
		if ctx.npc_units[key] then return _npc_target_allowed(target, cfg, ctx) end
	end

	if ctx.include_enemy_lookup and G.is_enemy(target) then return _npc_target_allowed(target, cfg, ctx) end
	if ctx.include_civilian_lookup and G.is_civilian(target) then return _npc_target_allowed(target, cfg, ctx) end
	if target.character_damage then
		local ok, cd = pcall(function() return target:character_damage() end)
		if ok and cd then return _npc_target_allowed(target, cfg, ctx) end
	end
	if U.is_bag_or_deployable(target) then return cfg.target_bags end
	if U.is_body_like(target) then return cfg.target_subdued_npcs end
	return cfg.target_suspicious_objects
end

function P.make_allowed(cfg, ctx)
	return function(target) return P.allowed(target, cfg, ctx) end
end
