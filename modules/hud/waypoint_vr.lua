-- VR waypoint overlay helpers.

if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.WaypointOverlay = DI.WaypointOverlay or {}
local WO = DI.WaypointOverlay
WO.VR = WO.VR or {}
local VR = WO.VR

local alive = DI.Game.alive
local A = DI.Assets

local function _elements(ov)
	return { ov.hollow, ov.clip, ov.filled, ov.vanilla_hollow, ov.vanilla_clip, ov.vanilla_eye, ov.pct_text, ov.pct_shadow }
end

local function _element_parent(el)
	if not alive(el) then return nil end
	local ok, p = pcall(function() return el:parent() end)
	if ok and alive(p) then return p end
	return nil
end

local function _gui_opts(opts)
	opts.render_template = "OverlayText"
	opts.depth_mode = "disabled"
	opts.rotation = 360
	return opts
end

local function _texture_size(bitmap, fallback)
	local ok, tw, th = pcall(function()
		return bitmap:texture_width(), bitmap:texture_height()
	end)
	if not ok then return fallback, fallback end
	return (type(tw) == "number" and tw > 0 and tw or fallback),
		(type(th) == "number" and th > 0 and th or fallback)
end

function VR.hide(ov)
	if not ov then return end
	for _, el in ipairs(_elements(ov)) do
		if alive(el) then el:set_visible(false) end
	end
end

function VR.destroy(ov)
	if not ov then return end
	for _, el in ipairs(_elements(ov)) do
		if alive(el) then pcall(function() el:set_visible(false); el:set_alpha(0) end) end
	end
	local panel = ov.panel
	if not alive(panel) then return end
	for _, el in ipairs(_elements(ov)) do
		if alive(el) then pcall(function() panel:remove(el) end) end
	end
end

function VR.source_visible(ov)
	if not (ov and alive(ov.vanilla_bitmap)) then return false end
	local ok, visible = pcall(function() return ov.vanilla_bitmap:visible() end)
	return (not ok) or visible ~= false
end

function VR.should_hide_screen_overlay(parent_ov)
	return parent_ov and parent_ov.vr and VR.source_visible(parent_ov.vr) or false
end

function VR.hide_screen_overlay(parent_ov)
	VR.hide(parent_ov)
end

function VR.create_overlay(vanilla_bitmap, size, fsize, base_arrow_color)
	local panel = _element_parent(vanilla_bitmap)
	if not alive(panel) then return nil end

	local cx, cy = vanilla_bitmap:center()
	local base_x = cx - size * 0.5
	local base_y = cy - size * 0.5

	vanilla_bitmap:set_alpha(0)

	local v_w = vanilla_bitmap:w()
	local v_h = vanilla_bitmap:h()
	local v_base_x = cx - v_w * 0.5
	local v_base_y = cy - v_h * 0.5

	local hollow = panel:bitmap(_gui_opts({
		name = "dp_hollow_vr", texture = A.kind_textures.civilian.curious,
		w = size, h = size, x = base_x, y = base_y,
		layer = 1, blend_mode = "normal", color = Color.white:with_alpha(0.7),
	}))
	local clip = panel:panel({
		name = "dp_clip_vr", w = size, h = size, x = base_x, y = base_y, layer = 2,
	})
	local filled = clip:bitmap(_gui_opts({
		name = "dp_filled_vr", texture = A.kind_textures.civilian.curious,
		w = size, h = size, x = 0, y = 0,
		layer = 1, blend_mode = "normal", color = Color.white,
	}))
	local susp_tex = A.vanilla_curious
	local vanilla_hollow = panel:bitmap(_gui_opts({
		name = "dp_v_hollow_vr", texture = susp_tex,
		w = v_w, h = v_h, x = v_base_x, y = v_base_y,
		layer = 1, blend_mode = "normal", color = Color.white:with_alpha(0.3), visible = false,
	}))
	local vanilla_clip = panel:panel({
		name = "dp_v_clip_vr", w = v_w, h = v_h, x = v_base_x, y = v_base_y,
		layer = 2, visible = false,
	})
	local vanilla_eye = vanilla_clip:bitmap(_gui_opts({
		name = "dp_v_eye_vr", texture = susp_tex,
		w = v_w, h = v_h, x = 0, y = 0,
		layer = 1, blend_mode = "normal", color = Color.white,
	}))
	local pct_shadow = panel:text(_gui_opts({
		name = "dp_pct_shadow_vr", text = "", font = A.font_hud, font_size = fsize,
		color = Color.black:with_alpha(0.8), layer = 4, visible = false,
		w = 80, h = 22, align = "center", vertical = "center",
	}))
	local pct_text = panel:text(_gui_opts({
		name = "dp_pct_vr", text = "", font = A.font_hud, font_size = fsize,
		color = Color.white, layer = 5, visible = false,
		w = 80, h = 22, align = "center", vertical = "center",
	}))

	local ov = {
		panel = panel, hollow = hollow, clip = clip, filled = filled,
		pct_text = pct_text, pct_shadow = pct_shadow,
		vanilla_bitmap = vanilla_bitmap,
		vanilla_hollow = vanilla_hollow, vanilla_clip = vanilla_clip, vanilla_eye = vanilla_eye,
		vanilla_base_y = v_base_y, vanilla_size = v_h,
		vanilla_size_orig = v_h, vanilla_base_x_orig = v_base_x, vanilla_base_y_orig = v_base_y,
		resize_vanilla_arrow = false,
		base_arrow_color = base_arrow_color,
		size = size, base_x = base_x, base_y = base_y,
		kind = "civilian", kind_set = false, observer_unit = nil, _van_mode = nil,
		is_vr = true,
	}
	VR.hide(ov)
	return ov
end

function VR.update(parent_ov, state, cfg, kind_textures, sync_geometry, render_apply, set_kind)
	local ov = parent_ov and parent_ov.vr
	if not ov then return end
	if ov.kind ~= parent_ov.kind or ov._kind_textures ~= kind_textures then
		set_kind(ov, parent_ov.kind, kind_textures)
	end
	ov._active_frames = parent_ov._active_frames
	if sync_geometry(ov) and VR.source_visible(ov) then
		render_apply(ov, state, cfg, kind_textures)
	else
		VR.hide(ov)
	end
end

function VR.render_cropped_fill(clip, filled, size, base_y, progress, color)
	local fp = math.clamp(progress or 0, 0, 1)
	local fill_h = math.max(0, size * fp)
	if alive(clip) then
		clip:set_h(fill_h)
		clip:set_y((base_y or 0) + size - fill_h)
	end
	if alive(filled) then
		filled:set_w(size)
		filled:set_h(fill_h)
		filled:set_y(0)
		filled:set_visible(fp > 0)
		filled:set_color(color)
		if fp > 0 then
			local tw, th = _texture_size(filled, size)
			local src_h = math.max(1, math.floor(th * fp + 0.5))
			pcall(function() filled:set_texture_rect(0, th - src_h, tw, src_h) end)
		end
	end
end
