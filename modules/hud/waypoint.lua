-- Waypoint overlay: state management and vanilla hook integration.

if not DynamicSuspicionIndicatorsManager then return end
local DI    = DynamicSuspicionIndicatorsManager
DI.WaypointOverlay = DI.WaypointOverlay or {}
local WO    = DI.WaypointOverlay
local alive = DI.Game.alive
local U     = DI.Units
local A     = DI.Assets
local Glyph = DI.HudGlyph
local View  = DI.HudView
local Render = WO.Render
local VR = WO.VR

WO.icon_size         = 22
WO.arrow_size        = 15
WO.percent_font_size = 14
WO._overlays         = WO._overlays    or {}
WO._calling_obs      = WO._calling_obs or {}

local function _waypoint_panel(wp_data)
	if not wp_data then return nil end
	local panel = wp_data.waypoint_panel or wp_data.panel
	if not (panel and alive(panel)) and alive(wp_data.bitmap) then
		local ok, p = pcall(function() return wp_data.bitmap:parent() end)
		if ok and alive(p) then panel = p end
	end
	return panel
end

local function _destroy_overlay(ov)
	if not ov then return end
	if ov.vr then
		if VR and VR.destroy then
			VR.destroy(ov.vr)
		else
			_destroy_overlay(ov.vr)
		end
		ov.vr = nil
	end
	local all = { ov.hollow, ov.clip, ov.filled, ov.vanilla_hollow, ov.vanilla_clip, ov.vanilla_eye, ov.pct_text, ov.pct_shadow }
	for _, el in ipairs(all) do
		if alive(el) then pcall(function() el:set_visible(false); el:set_alpha(0) end) end
	end
	local panel = ov.panel
	if not alive(panel) then return end
	for _, el in ipairs(all) do
		if alive(el) then pcall(function() panel:remove(el) end) end
	end
end
WO._destroy_overlay = _destroy_overlay

local _set_kind = Glyph.set_kind_fill

local function _set_xy(el, x, y)
	if alive(el) then
		el:set_x(x)
		el:set_y(y)
	end
end

local function _sync_overlay_geometry(ov)
	if not alive(ov.vanilla_bitmap) then return false end

	if ov.resize_vanilla_arrow and alive(ov.vanilla_arrow) then
		local ax, ay = ov.vanilla_arrow:center()
		local w, h = WO.arrow_size, WO.arrow_size
		local ok, tw, th = pcall(function()
			return ov.vanilla_arrow:texture_width(), ov.vanilla_arrow:texture_height()
		end)
		if ok and type(tw) == "number" and type(th) == "number" and tw > 0 then
			h = th / tw * w
		end
		ov.vanilla_arrow:set_size(w, h)
		ov.vanilla_arrow:set_center(ax, ay)
	end

	local cx, cy = ov.vanilla_bitmap:center()
	local base_x = cx - ov.size * 0.5
	local base_y = cy - ov.size * 0.5
	if ov.base_x ~= base_x or ov.base_y ~= base_y then
		ov.base_x = base_x
		ov.base_y = base_y
		_set_xy(ov.hollow, base_x, base_y)
		_set_xy(ov.clip, base_x, base_y)
	end

	local van_size = ov.vanilla_size or ov.vanilla_size_orig
	local van_x = cx - van_size * 0.5
	local van_y = cy - van_size * 0.5
	ov.vanilla_base_x_orig = cx - ov.vanilla_size_orig * 0.5
	ov.vanilla_base_y_orig = cy - ov.vanilla_size_orig * 0.5
	ov.vanilla_base_y = van_y
	_set_xy(ov.vanilla_hollow, van_x, van_y)
	_set_xy(ov.vanilla_clip, van_x, van_y)

	return true
end

local function _tick_lifecycle(ov, sd, npc_kind, kind_textures)
	if not (alive(ov.hollow) and alive(ov.clip) and alive(ov.filled)) then return false end
	local unit = ov.observer_unit
	if not alive(unit) and sd and alive(sd.u_observer) then
		unit = sd.u_observer
		ov.observer_unit = unit
	end
	if alive(unit) and (not ov.kind_set or ov._kind_textures ~= kind_textures) and npc_kind then
		_set_kind(ov, npc_kind(unit), kind_textures)
	end
	return true
end

local function _is_calling(sd)
	return type(sd) == "table" and (sd.status == "calling" or sd.status == "called")
end

local function _obs_is_calling(obs_key, sd)
	return WO._calling_obs[obs_key] or _is_calling(sd)
end

------------------------------------------------------------

function WO:has_overlay_for_unit(unit)
	if not (self._overlays and alive(unit)) then return false end
	local ukey = unit:key()
	for _, ov in pairs(self._overlays) do
		if alive(ov.observer_unit) and ov.observer_unit:key() == ukey then return true end
	end
	return false
end

function WO:install_hooks()
	if not DI.Game.has_hud_manager() then return end
	DI.Game.patch_hud_manager("add_waypoint", "_dp_aw_orig", function(self_hud, orig, id, data)
		local r = orig(self_hud, id, data)
		local ok, err = pcall(function()
			if type(id) == "string" and id:lower():find("^susp2") then
				WO._calling_obs[id:sub(6)] = true
			end
			local wp = self_hud._hud and self_hud._hud.waypoints and self_hud._hud.waypoints[id]
			WO:attach(id, wp)
		end)
		if not ok then
			DI.Logger.once("warn", "waypoint:add-hook-failed", "waypoint overlay attach failed: " .. tostring(err))
		end
		return r
	end)
	DI.Game.patch_hud_manager("remove_waypoint", "_dp_rw_orig", function(self_hud, orig, id, ...)
		_destroy_overlay(WO._overlays[id])
		WO._overlays[id] = nil
		if type(id) == "string" and id:lower():find("^susp2") then
			WO._calling_obs[id:sub(6)] = nil
		end
		return orig(self_hud, id, ...)
	end)
end

function WO:attach(id, wp_data)
	if not (id and wp_data) then return end
	if not (type(id) == "string" and id:lower():find("^susp1")) then return end
	if not alive(wp_data.bitmap) then return end
	if self._overlays[id] then return end

	local panel = _waypoint_panel(wp_data)
	if not (panel and alive(panel)) then return end

	local resize_vanilla_arrow = not alive(wp_data.panel)
	local base_arrow_color = alive(wp_data.arrow) and wp_data.arrow:color() or DI.Color.CURIOUS
	local size  = self.icon_size
	local fsize = self.percent_font_size
	local cx, cy = wp_data.bitmap:center()
	local base_x = cx - size * 0.5
	local base_y = cy - size * 0.5

	wp_data.bitmap:set_alpha(0)

	local v_w = wp_data.bitmap:w()
	local v_h = wp_data.bitmap:h()
	local v_base_x = cx - v_w * 0.5
	local v_base_y = cy - v_h * 0.5

	local hollow = panel:bitmap({
		name = "dp_hollow", texture = A.kind_textures.civilian.curious,
		w = size, h = size, x = base_x, y = base_y,
		layer = 1, blend_mode = "normal", color = Color.white:with_alpha(0.7),
	})
	local clip = panel:panel({
		name = "dp_clip", w = size, h = size, x = base_x, y = base_y, layer = 2,
	})
	local filled = clip:bitmap({
		name = "dp_filled", texture = A.kind_textures.civilian.curious,
		w = size, h = size, x = 0, y = 0,
		layer = 1, blend_mode = "normal", color = Color.white,
	})
	local susp_tex = A.vanilla_curious
	local vanilla_hollow = panel:bitmap({
		name = "dp_v_hollow", texture = susp_tex,
		w = v_w, h = v_h, x = v_base_x, y = v_base_y,
		layer = 1, blend_mode = "normal", color = Color.white:with_alpha(0.3), visible = false,
	})
	local vanilla_clip = panel:panel({
		name = "dp_v_clip", w = v_w, h = v_h, x = v_base_x, y = v_base_y,
		layer = 2, visible = false,
	})
	local vanilla_eye = vanilla_clip:bitmap({
		name = "dp_v_eye", texture = susp_tex,
		w = v_w, h = v_h, x = 0, y = 0,
		layer = 1, blend_mode = "normal", color = Color.white,
	})
	local pct_shadow = panel:text({
		name = "dp_pct_shadow", text = "", font = A.font_hud, font_size = fsize,
		color = Color.black:with_alpha(0.8), layer = 4, visible = false,
		w = 80, h = 22, align = "center", vertical = "center",
	})
	local pct_text = panel:text({
		name = "dp_pct", text = "", font = A.font_hud, font_size = fsize,
		color = Color.white, layer = 5, visible = false,
		w = 80, h = 22, align = "center", vertical = "center",
	})

	local ov = {
		panel = panel, hollow = hollow, clip = clip, filled = filled,
		pct_text = pct_text, pct_shadow = pct_shadow,
		vanilla_bitmap = wp_data.bitmap, vanilla_arrow = wp_data.arrow,
		vanilla_hollow = vanilla_hollow, vanilla_clip = vanilla_clip, vanilla_eye = vanilla_eye,
		vanilla_base_y = v_base_y, vanilla_size = v_h,
		vanilla_size_orig = v_h, vanilla_base_x_orig = v_base_x, vanilla_base_y_orig = v_base_y,
		resize_vanilla_arrow = resize_vanilla_arrow,
		base_arrow_color = base_arrow_color,
		size = size, base_x = base_x, base_y = base_y,
		kind = "civilian", kind_set = false, observer_unit = nil, _van_mode = nil,
	}
	if VR and VR.create_overlay and alive(wp_data.bitmap_world) then
		ov.vr = VR.create_overlay(wp_data.bitmap_world, size, fsize, base_arrow_color)
	end

	self._overlays[id] = ov
end

function WO:update(deps)
	if next(self._overlays) == nil then return end
	local npc_kind = deps.npc_kind
	local records  = deps.records or {}
	local cfg      = deps.cfg or {}

	local g = DI.Game.groupai()
	local susp_hud = g and g._suspicion_hud_data
	local susp_map
	if susp_hud then
		susp_map = {}
		for k, sd in pairs(susp_hud) do susp_map[tostring(k)] = sd end
	end

	for id, ov in pairs(self._overlays) do
		local obs_key = id:sub(6)
		local sd = susp_map and susp_map[obs_key] or nil
		local kind_textures = A.kind_textures_for(cfg.icon_style)
		if not _tick_lifecycle(ov, sd, npc_kind, kind_textures) then
			_destroy_overlay(ov)
			self._overlays[id] = nil
		elseif _sync_overlay_geometry(ov) then
			local unit = ov.observer_unit
			local rec  = alive(unit) and records[unit:key()] or nil
			if rec then
				ov._active_frames = (ov._active_frames or 0) + 1
			else
				ov._active_frames = 0
			end

			local state
			if _obs_is_calling(obs_key, sd) then
				state = { kind = "calling" }
			elseif U.is_subdued(unit, sd) then
				state = { kind = "subdued" }
			else
				local is_alerted = sd and sd.alerted or false
				local phase, p_icon, p_text

				if is_alerted then
					phase, p_icon, p_text = DI.Phase.ALERTED, 1, 1
				elseif alive(unit) then
					if rec and rec.progress == nil then
						phase = rec.phase or DI.Phase.UNCOVER
					else
						p_icon = (rec and rec.display) or (rec and rec.progress) or 0
						p_text = (rec and rec.progress) or p_icon
						phase  = (rec and rec.phase) or DI.Phase.UNCOVER
					end
				else
					phase, p_icon, p_text = DI.Phase.UNCOVER, 0, 0
				end

				phase = phase or DI.Phase.UNCOVER
				local pct, fill_color, arrow_color
				if p_text ~= nil then
					pct         = View.pct_str(phase, p_text)
					fill_color  = View.fill_color(phase, p_icon or 0)
					arrow_color = View.fill_color(phase, p_text)
				else
					pct         = "?%"
					fill_color  = DI.Color.UNKNOWN
					arrow_color = ov.base_arrow_color or DI.Color.CURIOUS
				end

				state = {
					kind = "normal",
					alerted = is_alerted,
					p_icon = p_icon,
					pct = pct,
					fill_color = fill_color,
					arrow_color = arrow_color,
					icons_on = A.uses_icons_mode(cfg.icon_style),
				}
			end
			if VR and VR.should_hide_screen_overlay and VR.should_hide_screen_overlay(ov) then
				VR.hide_screen_overlay(ov)
			else
				Render.apply(ov, state, cfg, kind_textures)
			end
			if VR and VR.update then
				VR.update(ov, state, cfg, kind_textures, _sync_overlay_geometry, Render.apply, _set_kind)
			end
		else
			_destroy_overlay(ov)
			self._overlays[id] = nil
		end
	end
end

function WO:destroy_all()
	for _, ov in pairs(self._overlays) do _destroy_overlay(ov) end
	self._overlays    = {}
	self._calling_obs = {}
end
