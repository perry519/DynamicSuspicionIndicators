-- Menu callbacks and visibility predicates. Adapter over DI.Settings lifecycle.

local DI = DynamicSuspicionIndicatorsManager
local G = DI and DI.Game
local Settings = DI and DI.Settings
local COLOR_KEYS = { "early_sus", "curious", "midway", "critical", "alerted" }

local function _toggle_setting(key)
	return function(_, item)
		Settings.set(key, item:value() == "on")
	end
end

local function _refresh_colors()
	DP._colors_dirty = true
	if DI.Color and DI.Color.refresh_from_settings then
		DI.Color.refresh_from_settings()
	end
	if DP.RefreshColorPreviewRows then DP:RefreshColorPreviewRows() end
end

local function _is_color_key(key)
	return type(key) == "string"
		and (key:sub(1, 6) == "color_" or key == "separate_alerted_color")
end

Settings.subscribe("DP_color_refresh", function(key, _)
	if _is_color_key(key) then _refresh_colors() end
end)

G.on_event("MenuManagerInitialize", "DP_MenuInit", function(menu_manager)
	local color_preview = DP.Menu and DP.Menu.ColorPreview
	if MenuNodeGui and color_preview and not DP._color_preview_row_hooked then
		DP._color_preview_row_hooked = true
		G.post_hook(MenuNodeGui, "_create_menu_item", "DP_CreateColorPreviewRow", function(gui, row_or_item)
			color_preview.attach_from_arg(gui, row_or_item)
		end)
		G.post_hook(MenuNodeGui, "reload_item", "DP_ReloadColorPreviewRow", function(gui, row_or_item)
			color_preview.attach_from_arg(gui, row_or_item)
		end)
	end

	MenuCallbackHandler.dp_icon_style = function(_, item)
		Settings.set("icon_style", item:value())
	end
	MenuCallbackHandler.dp_preview_noop = function() end
	MenuCallbackHandler.dp_toggle_subdued_check_icon = _toggle_setting("subdued_check_icon")
	MenuCallbackHandler.dp_toggle_show_early_unmasked_suspicion = _toggle_setting("show_early_unmasked_suspicion")
	MenuCallbackHandler.dp_toggle_enable_detection_sync = _toggle_setting("enable_detection_sync")
	MenuCallbackHandler.dp_toggle_client_aggregate_fallback = _toggle_setting("client_aggregate_fallback")
	MenuCallbackHandler.dp_toggle_numeric_values = _toggle_setting("show_numeric_values")
	MenuCallbackHandler.dp_toggle_numeric_observers = _toggle_setting("show_numeric_observers")
	MenuCallbackHandler.dp_toggle_numeric_observer_waypoints = _toggle_setting("show_numeric_observer_waypoints")
	MenuCallbackHandler.dp_toggle_numeric_observer_units = _toggle_setting("show_numeric_observer_units")
	MenuCallbackHandler.dp_toggle_numeric_targets = _toggle_setting("show_numeric_targets")
	MenuCallbackHandler.dp_toggle_targets = _toggle_setting("show_targets")
	MenuCallbackHandler.dp_toggle_target_other_players = _toggle_setting("target_other_players")
	MenuCallbackHandler.dp_toggle_target_subdued_npcs = _toggle_setting("target_subdued_npcs")
	MenuCallbackHandler.dp_toggle_target_bags = _toggle_setting("target_bags")
	MenuCallbackHandler.dp_toggle_target_suspicious_objects = _toggle_setting("target_suspicious_objects")
	MenuCallbackHandler.dp_toggle_separate_alerted_color = _toggle_setting("separate_alerted_color")

	MenuCallbackHandler.dp_open_colors = function()
		G.menu_open_node("dp_colors")
	end

	MenuCallbackHandler.dp_visible_numeric = function()
		return DP.settings.show_numeric_values == true
	end
	MenuCallbackHandler.dp_visible_numeric_targets = function()
		return DP.settings.show_numeric_values == true and DP.settings.show_targets == true
	end
	MenuCallbackHandler.dp_visible_observer_numeric = function()
		return DP.settings.show_numeric_values == true and DP.settings.show_numeric_observers == true
	end
	MenuCallbackHandler.dp_visible_targets = function()
		return DP.settings.show_targets == true
	end
	MenuCallbackHandler.dp_visible_early_sus_color = function()
		return DP.settings.show_early_unmasked_suspicion == true
	end
	MenuCallbackHandler.dp_visible_alerted_color = function()
		return DP.settings.separate_alerted_color == true
	end

	local function _slider_callback(key, channel)
		return function(_, item)
			local v = math.clamp((tonumber(item:value()) or 0) / 255, 0, 1)
			Settings.set("color_" .. key .. "_" .. channel, v)
		end
	end

	local function _set_slider_value(menu, key, channel, value)
		if not menu or not menu.item then return end
		local item = menu:item("dp_color_" .. key .. "_" .. channel)
		if item and item.set_value then
			item:set_value(math.floor((value or 0) * 255 + 0.5))
		end
	end

	for _, key in ipairs(COLOR_KEYS) do
		MenuCallbackHandler["dp_pick_color_" .. key] = function()
			if not _G.ColorPicker then return end
			local picker = ColorPicker:new("dp_color_" .. key, {
				color = Settings.get_color(key),
				done_callback = function(color, _, accepted)
					if accepted then
						Settings.set_color(key, color)
					else
						DP:RefreshColorPreviewRows()
					end
				end,
				changed_callback = function(color)
					DP:RefreshColorPreviewRows({ [key] = color })
				end,
			})
			picker:Show()
			DP:RefreshColorPreviewRows()
		end
		for _, ch in ipairs({ "r", "g", "b" }) do
			MenuCallbackHandler["dp_color_" .. key .. "_" .. ch] = _slider_callback(key, ch)
		end
	end

	MenuCallbackHandler.dp_colors_reset = function()
		local D = DynamicSuspicionIndicatorsSettingsSchema.DEFAULTS
		local menu = MenuHelper:GetMenu("dp_colors")
		local updates = {}
		for _, key in ipairs(COLOR_KEYS) do
			for _, ch in ipairs({ "r", "g", "b" }) do
				local k = "color_" .. key .. "_" .. ch
				updates[k] = D[k]
				_set_slider_value(menu, key, ch, D[k])
			end
		end
		Settings.update(updates)
	end

	MenuCallbackHandler.dp_colors_focus_changed = function(_, focused)
		if focused then
			DP:RefreshColorPreviewRowsDeferred()
		else
			DP:ClearColorPreviewRows()
		end
	end

	MenuCallbackHandler.dp_colors_close = function()
		DP:ClearColorPreviewRows()
	end

	MenuCallbackHandler.dp_update_visibility = function(_, item)
		local gui_node = item and item.parameters and item:parameters().gui_node
		if gui_node then
			gui_node:refresh_gui(gui_node.node)
			gui_node:highlight_item(item, true)
		end
	end
end)
