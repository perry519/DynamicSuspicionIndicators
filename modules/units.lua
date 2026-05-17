-- Unit classification, filtering, and NPC state predicates.

if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.Units = DI.Units or {}
local U = DI.Units
local G = DI.Game
local alive = G.alive

-- Classification

function U.is_camera(unit)
	if not alive(unit) then return false end
	for _, cu in pairs(G.security_cameras()) do
		if cu == unit then return true end
	end
	return false
end

local _LEVEL_FACTION_KINDS = {
	murkywater = "murky",
}

local _MURKY_LEVEL_IDS = {
	kosugi = true, -- Shadow Raid
	dark = true,   -- Murky Station
	vit = true,    -- The White House
}

local _tweak_kind_cache = {}

local function _is_murky_level()
	local level_id = G.level_id()
	return level_id ~= nil and _MURKY_LEVEL_IDS[level_id] == true
end

local _KIND_PREFIXES = {
	{ "security",  "security" },
	{ "gensec",    "security" },
	{ "cop",       "security" },
	{ "city_swat", function() return _is_murky_level() and "murky" or "security" end },
}

local function _level_faction_kind()
	if not _is_murky_level() then return nil end
	local level = G.tweak_level(G.level_id())
	if not (level and level.ai_group_type) then return nil end
	return _LEVEL_FACTION_KINDS[tostring(level.ai_group_type)]
end

local function _resolve_kind(base)
	if not base then return "guard" end
	local tweak = base._tweak_table
	if tweak then
		local cached = _tweak_kind_cache[tweak]
		if cached == nil then
			cached = false
			for _, pair in ipairs(_KIND_PREFIXES) do
				if tweak == pair[1] or tweak:sub(1, #pair[1] + 1) == pair[1] .. "_" then
					if type(pair[2]) == "function" then
						return pair[2]()
					end
					cached = pair[2] or false
					break
				end
			end
			_tweak_kind_cache[tweak] = cached
		end
		if cached then return cached end
	end
	return _level_faction_kind() or "guard"
end

function U.npc_kind(unit, fallback)
	if not alive(unit) then return fallback or "object" end
	if U.is_camera(unit) then return "camera" end
	if G.is_civilian(unit) then return "civilian" end
	if unit.character_damage and unit:character_damage() then
		return _resolve_kind(unit:base())
	end
	return fallback or "object"
end

-- NPC state

function U.is_dead(u)
	if not (u and u.character_damage) then return false end
	local cd = u:character_damage()
	if not cd then return false end
	if cd.dead and cd:dead() then return true end
	if cd._dead then return true end
	if cd._health and cd._health <= 0 then return true end
	return false
end

local SUBDUED_ANIM_FLAGS = { "drop", "surrender", "tied", "hands_back", "hands_tied", "bleedout", "fatal" }

local function _has_subdued_anim(u)
	if not (alive(u) and u.anim_data) then return false end
	local a = u:anim_data()
	if not a then return false end
	for _, k in ipairs(SUBDUED_ANIM_FLAGS) do
		if a[k] then return true end
	end
	return false
end

local function _is_groupai_hostage(u, groupai_state)
	if not (alive(u) and groupai_state and groupai_state.all_hostages) then return false end
	local hostages = groupai_state:all_hostages()
	if type(hostages) ~= "table" then return false end
	local u_key = u:key()
	for k, v in pairs(hostages) do
		if k == u_key or v == u_key or tostring(k) == tostring(u_key) or tostring(v) == tostring(u_key) then
			return true
		end
	end
	return false
end

function U.pacified(u)
	if U.is_dead(u) then return true end
	if _has_subdued_anim(u) then return true end
	if _is_groupai_hostage(u, G.groupai()) then return true end
	local b = u.brain and u:brain()
	if b and b._logic_data then
		local name = b._logic_data.name
		if name == "intimidated" or name == "surrender" or name == "tied" or name == "inactive" or name == "escort"
			or name == "phalanx_minion" then
			return true
		end
	end
	return false
end

function U.alerted(u)
	if not alive(u) then return false end
	local b = u.brain and u:brain()
	if b and b._logic_data then
		local name = b._logic_data.name
		return name == "attack" or name == "arrest"
	end
	return false
end

function U.disabled(u)
	return U.pacified(u) or U.alerted(u)
end

function U.is_subdued(unit, sd)
	if sd and sd._subdued_civ then return true end
	return _has_subdued_anim(unit)
end

function U.targetable(u, groupai_state)
	if U.is_dead(u) then return true end
	if _has_subdued_anim(u) then return true end
	if _is_groupai_hostage(u, groupai_state) then return true end
	local b = u.brain and u:brain()
	if b and b._logic_data then
		local name = b._logic_data.name
		return name == "intimidated" or name == "surrender" or name == "tied" or name == "escort"
	end
	return false
end

-- Target filtering

local function _safe_base(u)
	if not (u and u.base) then return nil end
	local ok, base = pcall(function() return u:base() end)
	return ok and base or nil
end

local function _safe_method_bool(obj, method_name)
	if not obj then return false end
	local method = obj[method_name]
	if type(method) == "function" then
		local ok, value = pcall(function() return method(obj) end)
		return ok and value == true
	end
	return method == true
end

local function _unit_tokens(u)
	local tokens = {}
	local function add(v)
		if v ~= nil then table.insert(tokens, tostring(v):lower()) end
	end
	local base = _safe_base(u)
	if base then
		add(base._tweak_table)
		add(base._unit_name)
		add(base._name_id)
	end
	if u and u.name then
		local ok, name = pcall(function() return u:name() end)
		if ok then add(name) end
	end
	if u and u.interaction then
		local ok, interaction = pcall(function() return u:interaction() end)
		if ok and interaction then add(interaction._tweak_data) end
	end
	return table.concat(tokens, " ")
end

local function _tokens_match(tokens, terms)
	for _, term in ipairs(terms) do
		if tokens:find(term, 1, true) then return true end
	end
	return false
end

local BAG_TERMS = {
	"bag", "loot", "drill", "money", "gold", "coke", "meth",
	"diamonds", "weapon", "artifact", "server",
}

local BODY_TERMS = {
	"body", "corpse", "dead", "hostage", "civilian", "civ_female", "civ_male",
	"cop", "fbi", "swat", "security", "guard", "gangster", "gensec", "spooc",
	"shield", "taser", "medic", "sniper", "tank", "ene_",
}

function U.is_other_player(u, player_unit)
	if not alive(u) or u == player_unit then return false end
	local base = _safe_base(u)
	if not base then return false end
	if _safe_method_bool(base, "is_husk_player") or _safe_method_bool(base, "is_local_player") then
		return true
	end
	local tokens = _unit_tokens(u)
	return tokens:find("husk_player", 1, true) ~= nil or tokens:find("local_player", 1, true) ~= nil
end

function U.is_player(u, player_unit)
	if not alive(u) then return false end
	if player_unit and u == player_unit then return true end
	return U.is_other_player(u, player_unit)
end

local function _movement_state_name(u)
	if not (alive(u) and u.movement) then return nil end
	local ok, movement = pcall(function() return u:movement() end)
	if not (ok and movement) then return nil end
	if type(movement.current_state_name) == "function" then
		local state_ok, state_name = pcall(function() return movement:current_state_name() end)
		if state_ok and type(state_name) == "string" then return state_name end
	end
	if type(movement._current_state_name) == "string" then return movement._current_state_name end
	if type(movement._state) == "string" then return movement._state end
	return nil
end

function U.is_player_mask_off(u, player_unit)
	if not U.is_player(u, player_unit) then return false end
	if player_unit and u == player_unit then
		local state_name = G.current_state()
		if type(state_name) == "string" then return state_name == "mask_off" end
	end
	return _movement_state_name(u) == "mask_off"
end

function U.is_bag_or_deployable(u)
	if not alive(u) then return false end
	if u.carry_data then
		local ok, carry = pcall(function() return u:carry_data() end)
		if ok and carry then return true end
	end
	return _tokens_match(_unit_tokens(u), BAG_TERMS)
end

function U.is_body_like(u)
	if not alive(u) then return false end
	return _tokens_match(_unit_tokens(u), BODY_TERMS)
end
