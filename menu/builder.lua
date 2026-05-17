-- BLT menu construction.

local G = DynamicSuspicionIndicatorsManager and DynamicSuspicionIndicatorsManager.Game
local COLOR_KEYS = { "early_sus", "curious", "midway", "critical", "alerted" }
local COLOR_VISIBLE = { early_sus = "dp_visible_early_sus_color", alerted = "dp_visible_alerted_color" }

local function _add_toggle(data, visible_callback)
	local item = MenuHelper:AddToggle(data)
	if item and visible_callback then
		item._visible_callback_name_list = { visible_callback }
	end
	return item
end

local function _add_color_preview_menu_item(key, priority)
	local color_preview = DP.Menu and DP.Menu.ColorPreview
	if color_preview and color_preview.add_menu_item then
		return color_preview.add_menu_item(key, priority)
	end
end

G.on_event("MenuManagerSetupCustomMenus", "DP_SetupMenus", function(_, nodes)
	MenuHelper:NewMenu("dp_options")
	MenuHelper:NewMenu("dp_colors")
end)

G.on_event("MenuManagerPopulateCustomMenus", "DP_PopulateMenus", function(menu_manager, nodes)
	-- Group 1: Icon customization
	MenuHelper:AddMultipleChoice({
		id       = "dp_icon_style",
		title    = "dp_icon_style",
		desc     = "dp_icon_style_desc",
		callback = "dp_icon_style",
		items    = { "dp_is_vanilla", "dp_is_vhp", "dp_is_extra" },
		value    = DP.settings.icon_style or 1,
		menu_id  = "dp_options",
		priority = 130,
	})
	_add_toggle({
		id       = "dp_subdued_check_icon",
		title    = "dp_subdued_check_icon",
		desc     = "dp_subdued_check_icon_desc",
		callback = "dp_toggle_subdued_check_icon",
		value    = DP.settings.subdued_check_icon,
		menu_id  = "dp_options",
		priority = 129,
	})

	MenuHelper:AddDivider({
		id       = "dp_divider_icons_sync",
		size     = 8,
		no_text  = true,
		menu_id  = "dp_options",
		priority = 127,
	})

	-- Group 2: Detection sync (multiplayer)
	_add_toggle({
		id       = "dp_enable_detection_sync",
		title    = "dp_enable_detection_sync",
		desc     = "dp_enable_detection_sync_desc",
		callback = "dp_toggle_enable_detection_sync",
		value    = DP.settings.enable_detection_sync,
		menu_id  = "dp_options",
		priority = 125,
	})
	_add_toggle({
		id       = "dp_client_aggregate_fallback",
		title    = "dp_client_aggregate_fallback",
		desc     = "dp_client_aggregate_fallback_desc",
		callback = "dp_toggle_client_aggregate_fallback",
		value    = DP.settings.client_aggregate_fallback,
		menu_id  = "dp_options",
		priority = 124,
	})

	MenuHelper:AddDivider({
		id       = "dp_divider_sync_early",
		size     = 8,
		no_text  = true,
		menu_id  = "dp_options",
		priority = 122,
	})

	-- Group 3: Show early unmasked suspicion
	_add_toggle({
		id       = "dp_show_early_unmasked_suspicion",
		title    = "dp_show_early_unmasked_suspicion",
		desc     = "dp_show_early_unmasked_suspicion_desc",
		callback = "dp_toggle_show_early_unmasked_suspicion",
		value    = DP.settings.show_early_unmasked_suspicion,
		menu_id  = "dp_options",
		priority = 120,
	})

	MenuHelper:AddDivider({
		id       = "dp_divider_early_numeric",
		size     = 8,
		no_text  = true,
		menu_id  = "dp_options",
		priority = 118,
	})

	-- Group 4: Numeric values
	_add_toggle({
		id       = "dp_show_numeric_values",
		title    = "dp_show_numeric_values",
		desc     = "dp_show_numeric_values_desc",
		callback = "dp_toggle_numeric_values dp_update_visibility",
		value    = DP.settings.show_numeric_values,
		menu_id  = "dp_options",
		priority = 115,
	})
	_add_toggle({
		id       = "dp_show_numeric_observers",
		title    = "dp_show_numeric_observers",
		desc     = "dp_show_numeric_observers_desc",
		callback = "dp_toggle_numeric_observers dp_update_visibility",
		value    = DP.settings.show_numeric_observers,
		menu_id  = "dp_options",
		priority = 114,
	}, "dp_visible_numeric")
	_add_toggle({
		id       = "dp_numeric_observer_waypoints",
		title    = "dp_numeric_observer_waypoints",
		desc     = "dp_numeric_observer_waypoints_desc",
		callback = "dp_toggle_numeric_observer_waypoints",
		value    = DP.settings.show_numeric_observer_waypoints,
		menu_id  = "dp_options",
		priority = 113,
	}, "dp_visible_observer_numeric")
	_add_toggle({
		id       = "dp_numeric_observer_units",
		title    = "dp_numeric_observer_units",
		desc     = "dp_numeric_observer_units_desc",
		callback = "dp_toggle_numeric_observer_units",
		value    = DP.settings.show_numeric_observer_units,
		menu_id  = "dp_options",
		priority = 112,
	}, "dp_visible_observer_numeric")
	_add_toggle({
		id       = "dp_show_numeric_targets",
		title    = "dp_show_numeric_targets",
		desc     = "dp_show_numeric_targets_desc",
		callback = "dp_toggle_numeric_targets",
		value    = DP.settings.show_numeric_targets,
		menu_id  = "dp_options",
		priority = 111,
	}, "dp_visible_numeric_targets")

	MenuHelper:AddDivider({
		id       = "dp_divider_numeric_targets",
		size     = 8,
		no_text  = true,
		menu_id  = "dp_options",
		priority = 108,
	})

	-- Group 5: Target indicators
	_add_toggle({
		id       = "dp_show_targets",
		title    = "dp_show_targets",
		desc     = "dp_show_targets_desc",
		callback = "dp_toggle_targets dp_update_visibility",
		value    = DP.settings.show_targets,
		menu_id  = "dp_options",
		priority = 105,
	})
	_add_toggle({
		id       = "dp_target_other_players",
		title    = "dp_target_other_players",
		desc     = "dp_target_other_players_desc",
		callback = "dp_toggle_target_other_players",
		value    = DP.settings.target_other_players,
		menu_id  = "dp_options",
		priority = 104,
	}, "dp_visible_targets")
	_add_toggle({
		id       = "dp_target_subdued_npcs",
		title    = "dp_target_subdued_npcs",
		desc     = "dp_target_subdued_npcs_desc",
		callback = "dp_toggle_target_subdued_npcs",
		value    = DP.settings.target_subdued_npcs,
		menu_id  = "dp_options",
		priority = 103,
	}, "dp_visible_targets")
	_add_toggle({
		id       = "dp_target_bags",
		title    = "dp_target_bags",
		desc     = "dp_target_bags_desc",
		callback = "dp_toggle_target_bags",
		value    = DP.settings.target_bags,
		menu_id  = "dp_options",
		priority = 102,
	}, "dp_visible_targets")
	_add_toggle({
		id       = "dp_target_suspicious_objects",
		title    = "dp_target_suspicious_objects",
		desc     = "dp_target_suspicious_objects_desc",
		callback = "dp_toggle_target_suspicious_objects",
		value    = DP.settings.target_suspicious_objects,
		menu_id  = "dp_options",
		priority = 101,
	}, "dp_visible_targets")

	-- Colors submenu link (in dp_options, priority 128 = between subdued_check_icon and divider)
	MenuHelper:AddButton({
		id       = "dp_open_colors",
		title    = "dp_colors_menu_title",
		desc     = "dp_colors_menu_desc",
		callback = "dp_open_colors",
		menu_id  = "dp_options",
		priority = 128,
	})

	-- Colors submenu population
	local function _set_vis(item, key)
		local vis = COLOR_VISIBLE[key]
		if item and vis then item._visible_callback_name_list = { vis } end
	end

	local function _add_separate_alerted_toggle(prio)
		_add_toggle({
			id       = "dp_separate_alerted_color",
			title    = "dp_separate_alerted_color",
			desc     = "dp_separate_alerted_color_desc",
			callback = "dp_toggle_separate_alerted_color dp_update_visibility",
			value    = DP.settings.separate_alerted_color,
			menu_id  = "dp_colors",
			priority = prio,
		})
		return prio - 1
	end

	if _G.ColorPicker then
		local prio = 130
		for _, key in ipairs(COLOR_KEYS) do
			_set_vis(MenuHelper:AddButton({
				id       = "dp_pick_color_" .. key,
				title    = "dp_color_" .. key,
				desc     = "dp_color_" .. key .. "_desc",
				callback = "dp_pick_color_" .. key,
				menu_id  = "dp_colors",
				priority = prio,
			}), key)
			prio = prio - 1
			_set_vis(_add_color_preview_menu_item(key, prio), key)
			prio = prio - 1
			if key == "critical" then prio = _add_separate_alerted_toggle(prio) end
		end
	else
		local prio = 130
		for _, key in ipairs(COLOR_KEYS) do
			for _, ch in ipairs({ "r", "g", "b" }) do
				local v = DP.settings["color_" .. key .. "_" .. ch] or 0
				_set_vis(MenuHelper:AddSlider({
					id       = "dp_color_" .. key .. "_" .. ch,
					title    = "dp_color_" .. key .. "_" .. ch,
					desc     = "dp_color_" .. ch .. "_desc",
					callback = "dp_color_" .. key .. "_" .. ch,
					value    = math.floor(v * 255 + 0.5),
					min      = 0,
					max      = 255,
					step     = 1,
					show_value = true,
					display_precision = 0,
					menu_id  = "dp_colors",
					priority = prio,
				}), key)
				prio = prio - 1
			end
			_set_vis(_add_color_preview_menu_item(key, prio), key)
			prio = prio - 1
			_set_vis(MenuHelper:AddDivider({
				id       = "dp_divider_color_" .. key,
				size     = 8,
				no_text  = true,
				menu_id  = "dp_colors",
				priority = prio,
			}), key)
			prio = prio - 1
			if key == "critical" then prio = _add_separate_alerted_toggle(prio) end
		end
	end
	MenuHelper:AddDivider({
		id       = "dp_divider_colors_reset",
		size     = 8,
		no_text  = true,
		menu_id  = "dp_colors",
		priority = 10,
	})
	MenuHelper:AddButton({
		id       = "dp_colors_reset",
		title    = "dp_colors_reset",
		desc     = "dp_colors_reset_desc",
		callback = "dp_colors_reset",
		menu_id  = "dp_colors",
		priority = 9,
	})
end)

G.on_event("MenuManagerBuildCustomMenus", "DP_BuildMenus", function(_, nodes)
	nodes["dp_colors"] = MenuHelper:BuildMenu("dp_colors", {
		back_callback = "dp_colors_close",
		focus_changed_callback = "dp_colors_focus_changed",
	})
	nodes["dp_options"] = MenuHelper:BuildMenu("dp_options")

	MenuHelper:AddMenuItem(
		nodes["blt_options"],
		"dp_options",
		"dp_options_title",
		"dp_options_desc"
	)
end)
