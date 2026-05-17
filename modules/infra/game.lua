if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.Game = DI.Game or {}
local G = DI.Game

G.alive = alive

function G.now()
	local m = managers.player
	return m and m:player_timer():time() or 0
end

function G.player_unit()
	local m = managers.player
	return m and m:player_unit()
end

function G.current_state()
	local m = managers.player
	if not (m and m.current_state) then return nil end
	local ok, s = pcall(function() return m:current_state() end)
	return ok and s or nil
end

function G.groupai()
	local m = managers.groupai
	return m and m:state()
end

function G.whisper_mode()
	local g = G.groupai()
	return g and g:whisper_mode()
end

function G.enemies()
	local m = managers.enemy
	return m and m:all_enemies()
end

function G.civilians()
	local m = managers.enemy
	return m and m:all_civilians()
end

function G.is_enemy(u)
	local m = managers.enemy
	return m and m.is_enemy and m:is_enemy(u)
end

function G.is_civilian(u)
	local m = managers.enemy
	return m and m.is_civilian and m:is_civilian(u)
end

function G.is_client()
	return Network and Network:is_client()
end

function G.is_server()
	return Network and Network:is_server()
end

function G.session()
	local m = managers.network
	return m and m:session()
end

function G.camera()
	local m = managers.viewport
	return m and m:get_current_camera()
end

function G.raycast(...)
	return World:raycast(...)
end

function G.find_units(...)
	return World:find_units_quick(...)
end

function G.make_slot_mask(...)
	return World:make_slot_mask(...)
end

function G.send(id, payload)
	if _G.LuaNetworking then LuaNetworking:SendToPeers(id, payload) end
end

function G.has_network()
	return _G.LuaNetworking ~= nil
end

function G.on_event(name, id, fn)
	if _G.Hooks then Hooks:Add(name, id, fn) end
end

function G.post_hook(obj, method, id, fn)
	if _G.Hooks and obj then Hooks:PostHook(obj, method, id, fn) end
end

function G.has_unit_network_handler()
	return _G.UnitNetworkHandler ~= nil
end

function G.patch_unit_network_handler(method, patch_id, wrapper)
	local handler = _G.UnitNetworkHandler
	if not (handler and handler[method]) then return false end
	if handler[patch_id] then return false end
	handler[patch_id] = handler[method]
	handler[method] = function(self, ...)
		return wrapper(self, handler[patch_id], ...)
	end
	return true
end

function G.has_hud_manager()
	return _G.HUDManager ~= nil
end

function G.patch_hud_manager(method, patch_id, wrapper)
	local manager = _G.HUDManager
	if not (manager and manager[method]) then return false end
	if manager[patch_id] then return false end
	manager[patch_id] = manager[method]
	manager[method] = function(self, ...)
		return wrapper(self, manager[patch_id], ...)
	end
	return true
end

function G.app_time()
	return _G.Application and Application:time() or 0
end

local _EMPTY = {}

function G.security_cameras()
	if _G.SecurityCamera and SecurityCamera.cameras then return SecurityCamera.cameras end
	return _EMPTY
end

function G.interactive_units()
	local m = managers.interaction
	if m and type(m._interactive_units) == "table" then return m._interactive_units end
	return _EMPTY
end

function G.patch_security_camera_sync_net_event(patch_id, wrapper)
	if not (_G.SecurityCamera and SecurityCamera.sync_net_event) then return false end
	if SecurityCamera[patch_id] then return false end
	SecurityCamera[patch_id] = SecurityCamera.sync_net_event
	function SecurityCamera:sync_net_event(event_id, ...)
		return wrapper(self, event_id, SecurityCamera[patch_id], ...)
	end
	return true
end

function G.level_id()
	if Global and Global.level_data and Global.level_data.level_id then
		return tostring(Global.level_data.level_id)
	end
	if Global and Global.game_settings and Global.game_settings.level_id then
		return tostring(Global.game_settings.level_id)
	end
	return nil
end

function G.tweak_level(level_id)
	if not (tweak_data and tweak_data.levels and level_id) then return nil end
	return tweak_data.levels[level_id]
end

function G.tweak_interaction()
	if not tweak_data then return nil end
	local ok, t = pcall(function() return tweak_data.interaction end)
	return ok and t or nil
end

function G.menu_layer()
	if tweak_data and tweak_data.gui and tweak_data.gui.MENU_LAYER then
		return tweak_data.gui.MENU_LAYER
	end
	return 100
end

function G.menu_open_node(id)
	local m = managers.menu
	if m and m.open_node then m:open_node(id) end
end

function G.hud_script(name)
	local m = managers.hud
	return m and m:script(name)
end

function G.gui_fullscreen_workspace()
	local m = managers.gui_data
	return m and m:create_fullscreen_workspace()
end

function G.player_hud_id()
	return _G.PlayerBase and PlayerBase.PLAYER_INFO_HUD_PD2
end
