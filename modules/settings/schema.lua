DynamicSuspicionIndicatorsSettingsSchema = DynamicSuspicionIndicatorsSettingsSchema or {}
local S = DynamicSuspicionIndicatorsSettingsSchema

S.DEFAULTS = S.DEFAULTS or {
	icon_style                        = 1,
	show_early_unmasked_suspicion     = false,
	enable_detection_sync             = true,
	client_aggregate_fallback         = true,
	show_numeric_values               = false,
	show_numeric_observers            = false,
	show_numeric_observer_waypoints   = false,
	show_numeric_observer_units       = false,
	show_numeric_targets              = true,
	show_targets                      = false,
	target_other_players              = true,
	target_subdued_npcs               = false,
	target_bags                       = false,
	target_suspicious_objects         = false,
	subdued_check_icon                = false,
	smooth_speed                      = 5,
	separate_alerted_color            = false,
	color_early_sus_r = 1, color_early_sus_g = 1, color_early_sus_b = 1,
	color_curious_r = 0, color_curious_g = 0.65, color_curious_b = 1,
	color_midway_r = 1, color_midway_g = 1, color_midway_b = 0,
	color_critical_r = 1, color_critical_g = 0.2, color_critical_b = 0,
	color_alerted_r = 1, color_alerted_g = 0.2, color_alerted_b = 0,
}

S.ICON_STYLES = S.ICON_STYLES or {
	VANILLA = 1,
	VHP     = 2,
	EXTRA   = 3,
}

S.VALID_ICON_STYLES = S.VALID_ICON_STYLES or {
	[S.ICON_STYLES.VANILLA] = true,
	[S.ICON_STYLES.VHP]     = true,
	[S.ICON_STYLES.EXTRA]   = true,
}

local function _setting_or(settings, key, default)
	if settings[key] == nil then
		settings[key] = default
	end
end

function S.apply_defaults(settings)
	settings = settings or {}

	if settings.show_percent_text ~= nil and settings.show_numeric_values == nil then
		settings.show_numeric_values = settings.show_percent_text
	end
	if settings.show_npc ~= nil then
		if settings.show_numeric_observers == nil then settings.show_numeric_observers = settings.show_npc end
		if settings.show_numeric_observer_units == nil then settings.show_numeric_observer_units = settings.show_npc end
	end
	if settings.replace_arrow_with_percent ~= nil then
		if settings.show_numeric_observers == nil then settings.show_numeric_observers = settings.replace_arrow_with_percent end
		if settings.show_numeric_observer_waypoints == nil then settings.show_numeric_observer_waypoints = settings.replace_arrow_with_percent end
	end
	if settings.show_obj ~= nil then
		if settings.show_targets == nil then settings.show_targets = settings.show_obj end
		if settings.show_numeric_targets == nil then settings.show_numeric_targets = settings.show_obj end
	end

	if not S.VALID_ICON_STYLES[settings.icon_style] then
		settings.icon_style = S.DEFAULTS.icon_style
	end

	settings.smooth_speed = S.DEFAULTS.smooth_speed
	for k, v in pairs(S.DEFAULTS) do
		_setting_or(settings, k, v)
	end
	return settings
end

function S.normalized(settings, smooth_speed)
	settings = settings or {}
	local targets = settings.show_targets ~= false
	local icon_style = settings.icon_style or S.DEFAULTS.icon_style
	return {
		icon_style                      = icon_style,
		show_numeric_values             = settings.show_numeric_values ~= false,
		show_numeric_observers          = settings.show_numeric_observers == true,
		show_numeric_observer_units     = settings.show_numeric_observer_units == true,
		show_numeric_observer_waypoints = settings.show_numeric_observer_waypoints == true,
		show_numeric_targets            = settings.show_numeric_targets ~= false,
		show_targets                    = targets,
		show_target_fill                = targets,
		target_other_players            = settings.target_other_players ~= false,
		target_subdued_npcs             = settings.target_subdued_npcs ~= false,
		target_bags                     = settings.target_bags ~= false,
		target_suspicious_objects       = settings.target_suspicious_objects ~= false,
		show_early_unmasked_suspicion   = settings.show_early_unmasked_suspicion == true,
		client_aggregate_fallback       = settings.client_aggregate_fallback == true,
		enable_detection_sync           = settings.enable_detection_sync ~= false,
		subdued_check_icon              = settings.subdued_check_icon == true,
		smooth_speed                    = smooth_speed or S.DEFAULTS.smooth_speed,
	}
end

if DynamicSuspicionIndicatorsManager then
	DynamicSuspicionIndicatorsManager.SettingsSchema = S
end
