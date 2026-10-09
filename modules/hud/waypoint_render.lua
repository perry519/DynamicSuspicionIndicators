-- Waypoint overlay rendering modes.

if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.WaypointOverlay = DI.WaypointOverlay or {}
local WO = DI.WaypointOverlay
WO.Render = WO.Render or {}
local R = WO.Render
local VR = WO.VR

local alive = DI.Game.alive
local A = DI.Assets
local Glyph = DI.HudGlyph

local _paint_text_pair = Glyph.paint_text_pair
local _kind_texture = Glyph.kind_texture
local _set_bitmap_image = Glyph.set_bitmap_image
local _set_alert = Glyph.set_kind_alert
local _set_kind = Glyph.set_kind_fill
local _set_visible = Glyph.set_visible
local _set_alpha = Glyph.set_alpha
local _set_color = Glyph.set_color
local _render_clipped_fill = Glyph.render_clipped_fill

local function _show_overlay(ov, visible)
	_set_visible(ov.hollow, visible)
	_set_visible(ov.clip, visible)
end

local function _show_vanilla_fill(ov, visible)
	_set_visible(ov.vanilla_hollow, visible)
	_set_visible(ov.vanilla_clip, visible)
end

local function _resize_vanilla_overlay(ov, sz, bx, by)
	if alive(ov.vanilla_hollow) then
		ov.vanilla_hollow:set_w(sz) ov.vanilla_hollow:set_h(sz)
		ov.vanilla_hollow:set_x(bx) ov.vanilla_hollow:set_y(by)
	end
	if alive(ov.vanilla_clip) then
		ov.vanilla_clip:set_w(sz) ov.vanilla_clip:set_h(sz)
		ov.vanilla_clip:set_x(bx) ov.vanilla_clip:set_y(by)
	end
	if alive(ov.vanilla_eye) then
		ov.vanilla_eye:set_w(sz) ov.vanilla_eye:set_h(sz)
	end
	ov.vanilla_size   = sz
	ov.vanilla_base_y = by
end

local function _render_fill(ov, p, color)
	if ov.is_vr and VR and VR.render_cropped_fill then
		VR.render_cropped_fill(ov.clip, ov.filled, ov.size, ov.base_y, p, color)
	else
		_render_clipped_fill(ov.clip, ov.filled, ov.size, ov.base_y, p, color)
	end
end

local function _render_vanilla_fill(ov, fp, p_icon, fill_color)
	if ov.is_vr and VR and VR.render_cropped_fill then
		VR.render_cropped_fill(ov.vanilla_clip, ov.vanilla_eye, ov.vanilla_size, ov.vanilla_base_y, fp, fill_color)
	else
		_render_clipped_fill(ov.vanilla_clip, ov.vanilla_eye, ov.vanilla_size, ov.vanilla_base_y, fp, fill_color)
	end
	if alive(ov.vanilla_hollow) then
		_set_color(ov.vanilla_hollow, (p_icon == nil) and DI.Color.UNKNOWN or DI.Color.CURIOUS)
		_set_alpha(ov.vanilla_hollow, 0.85)
	end
end

local function _draw_arrow_percent(ov, pct, arrow_color, is_alerted, cfg)
	local arrow_active = alive(ov.vanilla_arrow) and ov.vanilla_arrow:visible()
	local numeric_gate = arrow_active and cfg.show_numeric_observer_waypoints
	                  or (not arrow_active) and cfg.show_numeric_observer_units
	local want = cfg and cfg.show_numeric_values and cfg.show_numeric_observers
		and numeric_gate and not is_alerted
		and (ov._active_frames or 0) >= 2
	if alive(ov.vanilla_arrow) then
		if arrow_active and want then
			ov.vanilla_arrow:set_alpha(0)
		else
			ov.vanilla_arrow:set_alpha(1)
			ov.vanilla_arrow:set_color(arrow_color)
		end
	end
	local cx = ov.base_x + ov.size * 0.5
	local cy = ov.base_y + ov.size * 1.15 + 2
	_paint_text_pair(ov.pct_text, ov.pct_shadow, want, pct, arrow_color, cx, cy)
end

local function _apply_calling_mode(ov)
	if alive(ov.vanilla_bitmap) then
		ov.vanilla_bitmap:set_alpha(1)
		ov.vanilla_bitmap:set_visible(true)
	end
	_show_overlay(ov, false)
	_show_vanilla_fill(ov, false)
	_set_visible(ov.pct_text, false)
	_set_visible(ov.pct_shadow, false)
	if alive(ov.vanilla_arrow) then ov.vanilla_arrow:set_alpha(1)    end
end

local function _hide_subdued_text(ov)
	_set_visible(ov.pct_text, false)
	_set_visible(ov.pct_shadow, false)
end

local function _apply_subdued_alert_mode(ov, kind_textures)
	if alive(ov.vanilla_bitmap) then ov.vanilla_bitmap:set_alpha(0) end
	if alive(ov.vanilla_arrow)  then ov.vanilla_arrow:set_alpha(0)  end
	_show_vanilla_fill(ov, false)
	local image_ok = true
	if alive(ov.hollow) then
		if ov._subdued_mode ~= "alert" then
			image_ok = _set_bitmap_image(ov.hollow, _kind_texture(kind_textures, ov.kind or "civilian", "alerted"))
		end
		_set_visible(ov.hollow, true)
		_set_color(ov.hollow, DI.Color.ALERTED)
		_set_alpha(ov.hollow, 1)
	end
	_set_visible(ov.clip, false)
	_set_visible(ov.filled, false)
	_hide_subdued_text(ov)
	ov.kind_set = false
	ov._subdued_mode = image_ok and "alert" or nil
end

local function _apply_subdued_vhp_mode(ov)
	if alive(ov.vanilla_bitmap) then ov.vanilla_bitmap:set_alpha(0) end
	if alive(ov.vanilla_arrow)  then ov.vanilla_arrow:set_alpha(0)  end
	_show_vanilla_fill(ov, false)
	local image_ok = true
	if alive(ov.hollow) then
		_set_visible(ov.hollow, true)
		if ov._subdued_mode ~= "check" then
			image_ok = pcall(function() ov.hollow:set_image(A.menu_singletick) end)
		end
		_set_color(ov.hollow, DI.Color.CURIOUS)
		_set_alpha(ov.hollow, 1)
	end
	_set_visible(ov.clip, false)
	_hide_subdued_text(ov)
	ov.kind_set = false
	ov._subdued_mode = image_ok and "check" or nil
end

local function _apply_icons_mode(ov, alerted, p_icon, fill_color, kind_textures)
	if alive(ov.vanilla_bitmap) then ov.vanilla_bitmap:set_alpha(0) end
	_show_overlay(ov, true)
	_set_visible(ov.filled, true)
	_show_vanilla_fill(ov, false)
	_set_alert(ov, alerted, kind_textures)
	_render_fill(ov, (type(p_icon) == "number") and p_icon or 0, fill_color)
	if alive(ov.hollow) then
		_set_color(ov.hollow, p_icon == nil and DI.Color.UNKNOWN or DI.Color.CURIOUS)
		_set_alpha(ov.hollow, alerted and 0 or 0.85)
	end
end

local function _apply_vanilla_mode(ov, alerted, p_icon, fill_color, cfg)
	local icon_style = cfg.icon_style or 1
	_show_overlay(ov, false)
	if ov._van_mode ~= icon_style then
		_resize_vanilla_overlay(ov, ov.vanilla_size_orig, ov.vanilla_base_x_orig, ov.vanilla_base_y_orig)
		ov._van_mode = icon_style
	end
	if alerted then
		if alive(ov.vanilla_bitmap) then
			pcall(function() ov.vanilla_bitmap:set_image(A.vanilla_alert) end)
			ov.vanilla_bitmap:set_color(fill_color)
			ov.vanilla_bitmap:set_alpha(1)
		end
		_show_vanilla_fill(ov, false)
	else
		if alive(ov.vanilla_bitmap) then ov.vanilla_bitmap:set_alpha(0) end
		_show_vanilla_fill(ov, true)
		_render_vanilla_fill(ov, (type(p_icon) == "number") and p_icon or 0, p_icon, fill_color)
	end
end

function R.apply(ov, state, cfg, kind_textures)
	if state.kind == "subdued" and ov.kind_set and ov._subdued_mode then
		ov._subdued_mode = nil
	end
	if state.kind ~= "subdued" and ov._subdued_mode then
		ov._subdued_mode = nil
		_set_kind(ov, ov.kind or "civilian", kind_textures)
	end
	if state.kind == "calling" then
		_apply_calling_mode(ov)
		return
	end
	if state.kind == "subdued" then
		if cfg.subdued_check_icon then
			_apply_subdued_vhp_mode(ov)
		else
			_apply_subdued_alert_mode(ov, kind_textures)
		end
		return
	end

	if state.icons_on then
		_apply_icons_mode(ov, state.alerted, state.p_icon, state.fill_color, kind_textures)
	else
		_apply_vanilla_mode(ov, state.alerted, state.p_icon, state.fill_color, cfg)
	end
	_draw_arrow_percent(ov, state.pct, state.arrow_color, state.alerted, cfg)
end
