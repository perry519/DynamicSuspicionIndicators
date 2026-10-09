-- Waypoint overlay: state management and vanilla hook integration.

if not DynamicSuspicionIndicatorsManager then
	return
end
local DI = DynamicSuspicionIndicatorsManager
DI.WaypointOverlay = DI.WaypointOverlay or {}
local WO = DI.WaypointOverlay
local alive = DI.Game.alive
local U = DI.Units
local A = DI.Assets
local Glyph = DI.HudGlyph
local View = DI.HudView
local Render = WO.Render
local VR = WO.VR
local STATIC_CHECK_INTERVAL = 0.1

WO.icon_size = 22
WO.arrow_size = 15
WO.percent_font_size = 14
WO._overlays = WO._overlays or {}
WO._calling_obs = WO._calling_obs or {}

local function _waypoint_panel(wp_data)
	if not wp_data then
		return nil
	end
	local panel = wp_data.waypoint_panel or wp_data.panel
	if not (panel and alive(panel)) and alive(wp_data.bitmap) then
		local ok, p = pcall(function()
			return wp_data.bitmap:parent()
		end)
		if ok and alive(p) then
			panel = p
		end
	end
	return panel
end

local function _destroy_overlay(ov)
	if not ov then
		return
	end
	if ov.vr then
		if VR and VR.destroy then
			VR.destroy(ov.vr)
		else
			_destroy_overlay(ov.vr)
		end
		ov.vr = nil
	end
	local all = {
		ov.hollow,
		ov.clip,
		ov.filled,
		ov.vanilla_hollow,
		ov.vanilla_clip,
		ov.vanilla_eye,
		ov.pct_text,
		ov.pct_shadow,
	}
	for _, el in ipairs(all) do
		if alive(el) then
			pcall(function()
				el:set_visible(false)
				el:set_alpha(0)
			end)
		end
	end
	local panel = ov.panel
	if not alive(panel) then
		return
	end
	for _, el in ipairs(all) do
		if alive(el) then
			pcall(function()
				panel:remove(el)
			end)
		end
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

local function _texture_name(bitmap)
	return bitmap:texture_name()
end

local function _texture_size(bitmap)
	return bitmap:texture_width(), bitmap:texture_height()
end

local function _arrow_height(ov, arrow, width)
	local name_ok, texture_name = pcall(_texture_name, arrow)
	local cacheable = name_ok and texture_name ~= nil
	if not cacheable or ov._arrow_size_source ~= arrow or ov._arrow_size_texture ~= texture_name then
		local size_ok, texture_width, texture_height = pcall(_texture_size, arrow)
		if
			size_ok
			and type(texture_width) == "number"
			and type(texture_height) == "number"
			and texture_width > 0
			and texture_height > 0
		then
			local aspect = texture_height / texture_width
			if cacheable then
				ov._arrow_size_source = arrow
				ov._arrow_size_texture = texture_name
				ov._arrow_size_aspect = aspect
			end
			return aspect * width
		end
		ov._arrow_size_source = nil
		ov._arrow_size_texture = nil
		ov._arrow_size_aspect = nil
		return width
	end
	return (ov._arrow_size_aspect or 1) * width
end

local function _sync_overlay_geometry(ov)
	if not alive(ov.vanilla_bitmap) then
		return false
	end

	if ov.resize_vanilla_arrow and alive(ov.vanilla_arrow) then
		local w = WO.arrow_size
		local h = _arrow_height(ov, ov.vanilla_arrow, w)
		if ov.vanilla_arrow:w() ~= w or ov.vanilla_arrow:h() ~= h then
			local ax, ay = ov.vanilla_arrow:center()
			ov.vanilla_arrow:set_size(w, h)
			ov.vanilla_arrow:set_center(ax, ay)
		end
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
	if ov.vanilla_base_x ~= van_x or ov.vanilla_base_y ~= van_y then
		ov.vanilla_base_x = van_x
		ov.vanilla_base_y = van_y
		_set_xy(ov.vanilla_hollow, van_x, van_y)
		_set_xy(ov.vanilla_clip, van_x, van_y)
	end

	return true
end

local function _tick_lifecycle(ov, sd, npc_kind, kind_textures)
	local unit = ov.observer_unit
	local unit_changed = false
	if not alive(unit) and sd and alive(sd.u_observer) then
		unit = sd.u_observer
		ov.observer_unit = unit
		unit_changed = true
	end
	if
		alive(unit)
		and npc_kind
		and (unit_changed or ov._kind_textures ~= kind_textures or (not ov.kind_set and not ov._subdued_mode))
	then
		local kind = npc_kind(unit)
		local changed = ov.kind ~= kind or ov._kind_textures ~= kind_textures
		if changed or (not ov.kind_set and not ov._subdued_mode) then
			_set_kind(ov, kind, kind_textures)
			if changed then
				ov._subdued_mode = nil
			end
		end
	end
end

local function _is_calling(sd)
	return type(sd) == "table" and (sd.status == "calling" or sd.status == "called")
end

local function _obs_is_calling(obs_key, sd)
	return WO._calling_obs[obs_key] or _is_calling(sd)
end

------------------------------------------------------------

function WO:has_overlay_for_unit(unit)
	if not (self._overlays and alive(unit)) then
		return false
	end
	local ukey = unit:key()
	for _, ov in pairs(self._overlays) do
		if alive(ov.observer_unit) and ov.observer_unit:key() == ukey then
			return true
		end
	end
	return false
end

function WO:install_hooks()
	if not DI.Game.has_hud_manager() then
		return
	end
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

function WO:attach(id, wp_data, preview_observer)
	if not (id and wp_data) then
		return
	end
	local alert_preview = preview_observer ~= nil
	if alert_preview then
		if type(id) ~= "string" or id == "" or not alive(preview_observer) then
			return
		end
	elseif not (type(id) == "string" and id:lower():find("^susp1")) then
		return
	end
	if not alive(wp_data.bitmap) then
		return
	end
	if self._overlays[id] then
		return
	end

	local panel = _waypoint_panel(wp_data)
	if not (panel and alive(panel)) then
		return
	end

	local resize_vanilla_arrow = not alive(wp_data.panel)
	local base_arrow_color = alive(wp_data.arrow) and wp_data.arrow:color() or DI.Color.CURIOUS
	local size = self.icon_size
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
		name = "dp_hollow",
		texture = A.kind_textures.civilian.curious,
		w = size,
		h = size,
		x = base_x,
		y = base_y,
		layer = 1,
		blend_mode = "normal",
		color = Color.white:with_alpha(0.7),
	})
	local clip = panel:panel({
		name = "dp_clip",
		w = size,
		h = size,
		x = base_x,
		y = base_y,
		layer = 2,
	})
	local filled = clip:bitmap({
		name = "dp_filled",
		texture = A.kind_textures.civilian.curious,
		w = size,
		h = size,
		x = 0,
		y = 0,
		layer = 1,
		blend_mode = "normal",
		color = Color.white,
	})
	local susp_tex = A.vanilla_curious
	local vanilla_hollow = panel:bitmap({
		name = "dp_v_hollow",
		texture = susp_tex,
		w = v_w,
		h = v_h,
		x = v_base_x,
		y = v_base_y,
		layer = 1,
		blend_mode = "normal",
		color = Color.white:with_alpha(0.3),
		visible = false,
	})
	local vanilla_clip = panel:panel({
		name = "dp_v_clip",
		w = v_w,
		h = v_h,
		x = v_base_x,
		y = v_base_y,
		layer = 2,
		visible = false,
	})
	local vanilla_eye = vanilla_clip:bitmap({
		name = "dp_v_eye",
		texture = susp_tex,
		w = v_w,
		h = v_h,
		x = 0,
		y = 0,
		layer = 1,
		blend_mode = "normal",
		color = Color.white,
	})
	local pct_shadow = panel:text({
		name = "dp_pct_shadow",
		text = "",
		font = A.font_hud,
		font_size = fsize,
		color = Color.black:with_alpha(0.8),
		layer = 4,
		visible = false,
		w = 80,
		h = 22,
		align = "center",
		vertical = "center",
	})
	local pct_text = panel:text({
		name = "dp_pct",
		text = "",
		font = A.font_hud,
		font_size = fsize,
		color = Color.white,
		layer = 5,
		visible = false,
		w = 80,
		h = 22,
		align = "center",
		vertical = "center",
	})

	local ov = {
		panel = panel,
		hollow = hollow,
		clip = clip,
		filled = filled,
		pct_text = pct_text,
		pct_shadow = pct_shadow,
		vanilla_bitmap = wp_data.bitmap,
		vanilla_arrow = wp_data.arrow,
		vanilla_hollow = vanilla_hollow,
		vanilla_clip = vanilla_clip,
		vanilla_eye = vanilla_eye,
		vanilla_base_y = v_base_y,
		vanilla_size = v_h,
		vanilla_size_orig = v_h,
		vanilla_base_x_orig = v_base_x,
		vanilla_base_y_orig = v_base_y,
		resize_vanilla_arrow = resize_vanilla_arrow,
		base_arrow_color = base_arrow_color,
		size = size,
		base_x = base_x,
		base_y = base_y,
		kind = "civilian",
		kind_set = false,
		observer_unit = preview_observer,
		alert_preview = alert_preview,
		_observer_key_text = not alert_preview and id:sub(6) or nil,
		_van_mode = nil,
	}
	if VR and VR.create_overlay and alive(wp_data.bitmap_world) then
		ov.vr = VR.create_overlay(wp_data.bitmap_world, size, fsize, base_arrow_color)
	end

	self._overlays[id] = ov
	return ov
end

function WO:attach_alert_preview(id, wp_data, observer)
	if type(id) ~= "string" or id == "" or not alive(observer) then
		return nil
	end
	return self:attach(id, wp_data, observer)
end

function WO:update(deps)
	if next(self._overlays) == nil then
		return
	end
	local npc_kind = deps.npc_kind
	local records = deps.records or {}
	local cfg = deps.cfg or {}
	local kind_textures = A.kind_textures_for(cfg.icon_style)
	local now_t = DI.Game.app_time()
	local check_static = not self._next_static_check_t or now_t >= self._next_static_check_t
	if check_static then
		self._next_static_check_t = now_t + STATIC_CHECK_INTERVAL
	end

	local g = DI.Game.groupai()
	local susp_hud = g and g._suspicion_hud_data
	local susp_map

	for id, ov in pairs(self._overlays) do
		if not (alive(ov.hollow) and alive(ov.clip) and alive(ov.filled)) or not _sync_overlay_geometry(ov) then
			_destroy_overlay(ov)
			self._overlays[id] = nil
		elseif not (ov._static and not check_static and not ov.vr) then
			local obs_key, sd
			if not ov.alert_preview then
				obs_key = ov._observer_key_text or id:sub(6)
				ov._observer_key_text = obs_key
				if susp_hud then
					sd = ov._suspicion_key and susp_hud[ov._suspicion_key]
					if not sd then
						-- Resolve new/replaced sources immediately; established keys use the live table directly.
						if not susp_map then
							susp_map = {}
							for key in pairs(susp_hud) do
								susp_map[tostring(key)] = key
							end
						end
						ov._suspicion_key = susp_map[obs_key]
						sd = ov._suspicion_key and susp_hud[ov._suspicion_key]
					end
				end
			end
			-- Subdued rendering changes textures and clears kind_set; refresh both together.
			_tick_lifecycle(ov, sd, npc_kind, kind_textures)
			local unit = ov.observer_unit
			local rec = not ov.alert_preview and alive(unit) and records[unit:key()] or nil
			local hide_idle = not ov.alert_preview
				and alive(unit)
				and deps.hide_idle_observer
				and deps.hide_idle_observer(unit:key())
			if rec then
				ov._active_frames = (ov._active_frames or 0) + 1
			else
				ov._active_frames = 0
			end

			local state
			if not ov.alert_preview and _obs_is_calling(obs_key, sd) then
				state = { kind = "calling" }
			elseif ov.kind == "civilian" and not ov.alert_preview and U.is_subdued(unit, sd) then
				state = { kind = "subdued" }
			elseif not ov.alert_preview and hide_idle and not rec and not (sd and sd.alerted) then
				state = { kind = "hidden" }
			else
				local is_alerted = ov.alert_preview or (sd and sd.alerted) or false
				local phase, p_icon, p_text

				if is_alerted then
					phase, p_icon, p_text = DI.Phase.ALERTED, 1, 1
				elseif alive(unit) then
					if rec and rec.progress == nil then
						phase = rec.phase or DI.Phase.UNCOVER
					else
						p_icon = (rec and rec.display) or (rec and rec.progress) or 0
						p_text = (rec and rec.progress) or p_icon
						phase = (rec and rec.phase) or DI.Phase.UNCOVER
					end
				else
					phase, p_icon, p_text = DI.Phase.UNCOVER, 0, 0
				end

				phase = phase or DI.Phase.UNCOVER
				local pct, fill_color, arrow_color
				if p_text ~= nil then
					pct = View.pct_str(phase, p_text)
					fill_color = View.fill_color(phase, p_icon or 0)
					arrow_color = View.fill_color(phase, p_text)
				else
					pct = "?%"
					fill_color = DI.Color.UNKNOWN
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
			ov._static = state.kind == "calling" or state.kind == "subdued" or (state.alerted and state.icons_on)
			if VR and VR.should_hide_screen_overlay and VR.should_hide_screen_overlay(ov) then
				VR.hide_screen_overlay(ov)
			else
				Render.apply(ov, state, cfg, kind_textures)
			end
			if VR and VR.update then
				VR.update(ov, state, cfg, kind_textures, _sync_overlay_geometry, Render.apply, _set_kind)
			end
		end
	end
end

function WO:destroy_all()
	for _, ov in pairs(self._overlays) do
		_destroy_overlay(ov)
	end
	self._overlays = {}
	self._calling_obs = {}
	self._next_static_check_t = nil
end
