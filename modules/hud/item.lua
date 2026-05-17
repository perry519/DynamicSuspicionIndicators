-- Numeric % indicators above heads (and over targeted bodies/objects).

if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.HudItem = DI.HudItem or {}
local H  = DI.HudItem
local WO = DI.WaypointOverlay
local A  = DI.Assets
local alive = DI.Game.alive
local U = DI.Units
local Glyph = DI.HudGlyph

H._items = H._items or {}
H._panel = H._panel or nil
H._ws    = H._ws    or nil

function H.init_panel(panel, ws)
	H._panel = panel
	H._ws    = ws
end

function H.destroy(key)
	local item = H._items[key]
	if item and H._panel and alive(H._panel) and alive(item.panel) then
		H._panel:remove(item.panel)
	end
	H._items[key] = nil
end

function H.destroy_all()
	if not (H._panel and alive(H._panel)) then H._items = {}; return end
	for _, item in pairs(H._items) do
		if alive(item.panel) then H._panel:remove(item.panel) end
	end
	H._items = {}
end

local function _numeric_text_allowed(rec, cfg)
	if not (cfg and cfg.show_numeric_values) then return false end
	if rec.kind == "obj" then return cfg.show_numeric_targets end
	return cfg.show_numeric_observers and cfg.show_numeric_observer_units
end

local function _decide_paint(rec, layout, kind_icon_visible, cfg, hide_for_wo)
	if rec._target_alert then
		return {
			show_text = cfg.show_targets and not hide_for_wo,
			show_kind_icon = false,
			fill_eye = false,
		}
	end
	local fully_alerted = type(rec.progress) == "number" and rec.progress >= 0.999
	local is_suspicion  = layout == "suspicion"
	local text_allowed  = _numeric_text_allowed(rec, cfg)
	local vanilla_suspicion = is_suspicion and not A.uses_icons_mode(cfg.icon_style)
	return {
		show_text      = text_allowed and (is_suspicion or not fully_alerted) and not hide_for_wo,
		show_kind_icon = kind_icon_visible and not vanilla_suspicion,
		fill_eye       = rec.kind == "obj" or vanilla_suspicion,
	}
end

local function _adjust_sy(base_sy, rec_kind, role, sy_offset_hint, off, m_edge, pnl_h)
	local sy = base_sy
	if rec_kind ~= "obj" and not off then sy = sy + 26 end
	if role and role.target and role.observer and not off then
		sy = sy + ((rec_kind == "obj") and 28 or -18)
		sy = math.clamp(sy, m_edge, pnl_h - m_edge)
	end
	if sy_offset_hint ~= 0 and not off then
		sy = sy + sy_offset_hint
		sy = math.clamp(sy, m_edge, pnl_h - m_edge)
	end
	return sy
end

local function _alpha_for_distance(dist)
	return math.clamp(1 - (dist - 800) / 4000, 0.25, 1)
end

local function _should_show(off, layout, has_wo_overlay)
	if off then return false end
	if layout == "suspicion" and has_wo_overlay then return false end
	return true
end

local function _hide_for_waypoint_overlay(rec, layout, has_wo, cfg)
	return rec.kind ~= "obj" and layout ~= "suspicion" and has_wo
end

local function _paint_kind_icon(item, rec, fill_color, kind_textures)
	if not (item.kind_icon and alive(item.kind_icon)) then return end
	if not (DI.WaypointOverlay and alive(rec.unit)) then
		item.kind_icon:set_visible(false)
		return
	end
	local kt = kind_textures or A.kind_textures
	Glyph.paint_kind_bitmap(item.kind_icon, item, U.npc_kind(rec.unit), kt, fill_color)
end

local _build_question_text = Glyph.build_question_text
local _build_question_fill = Glyph.build_question_fill

local function _build_item(panel, kind, want_obj_fill, suspicion_layout, suspicion_question, target_alert, CURIOUS)
	local size      = 14
	local icon_size = WO.icon_size
	local with_eye  = kind == "obj" and not target_alert
	local with_icon = (not with_eye) and suspicion_layout and not suspicion_question
	local pnl_w, pnl_h, txt_x, txt_y, txt_align, txt_w
	if with_eye then
		pnl_w, pnl_h = size + 36, size + 4
		txt_x, txt_y, txt_align = size + 2, 2, "left"
		txt_w = pnl_w - txt_x
	elseif with_icon or suspicion_question then
		pnl_w, pnl_h = 36, icon_size + 2 + size + 4
		txt_x, txt_y, txt_align = 0, icon_size + 2, "center"
		txt_w = pnl_w
	elseif target_alert then
		pnl_w, pnl_h = 22, size + 6
		txt_x, txt_y, txt_align = 0, 1, "center"
		txt_w = pnl_w
	else
		pnl_w, pnl_h = 36, size + 4
		txt_x, txt_y, txt_align = 0, 2, "center"
		txt_w = pnl_w
	end
	local pnl = panel:panel({ w = pnl_w, h = pnl_h })
	local eye, hollow, clip, kind_icon
	if suspicion_question then
		local icon_x = (pnl_w - icon_size) * 0.5
		hollow, clip, eye = _build_question_fill(pnl, {
			hollow_name = "dp_susp_hollow", clip_name = "dp_susp_clip", filled_name = "dp_susp_filled",
			texture = A.vanilla_curious,
			size = icon_size, extra_h = 0, x = icon_x, y = 0,
			hollow_color = CURIOUS:with_alpha(0.7),
		})
	elseif with_eye then
		if want_obj_fill then
			hollow, clip, eye = _build_question_fill(pnl, {
				hollow_name = "dp_obj_hollow", clip_name = "dp_obj_clip", filled_name = "dp_obj_filled",
				size = size, extra_h = 4, x = 0, y = 0, font_size = size + 4,
				hollow_color = CURIOUS:with_alpha(0.7),
			})
		else
			eye = _build_question_text(pnl, "dp_obj_symbol", 2, size, size + 4, 0, 0, Color.white)
		end
	elseif with_icon then
		kind_icon = pnl:bitmap({
			name = "dp_obs_kind_icon",
			w = icon_size, h = icon_size, x = (pnl_w - icon_size) * 0.5, y = 0,
			layer = 2, color = Color.white, visible = false,
		})
	end
	local shadow = pnl:text({
		text = "0%", font = A.font_hud, font_size = size,
		color = Color.black:with_alpha(0.7),
		x = txt_x + 1, y = txt_y + 1, layer = 1,
		w = txt_w, align = txt_align,
	})
	local txt = pnl:text({
		text = "0%", font = A.font_hud, font_size = size,
		color = Color.white,
		x = txt_x, y = txt_y, layer = 3,
		w = txt_w, align = txt_align,
	})
	return {
		panel = pnl, eye = eye, hollow = hollow, clip = clip, kind_icon = kind_icon,
		txt = txt, shadow = shadow, kind = kind,
		size = suspicion_question and icon_size or size,
		_text_size = size,
		_with_obj_fill = want_obj_fill,
		_suspicion_layout = suspicion_layout and true or false,
		_suspicion_question = suspicion_question and true or false,
		_target_alert = target_alert and true or false,
		_kind_tex_for = nil,
	}
end

local function _request(key, kind, layout, cfg, CURIOUS)
	local want_alert = (kind == "obj") and layout == "target_alert"
	local want_obj_fill = (kind == "obj") and cfg.show_target_fill and not want_alert or false
	local want_suspicion = (kind ~= "obj") and (layout == "suspicion") or false
	local want_question = want_suspicion and not A.uses_icons_mode(cfg.icon_style)
	local item = H._items[key]
	if item and alive(item.panel) then
		if item._with_obj_fill ~= want_obj_fill
			or item._suspicion_layout ~= want_suspicion
			or item._suspicion_question ~= want_question
			or item._target_alert ~= want_alert then
			H.destroy(key)
		else
			return item
		end
	end
	item = _build_item(H._panel, kind, want_obj_fill, want_suspicion, want_question, want_alert, CURIOUS)
	H._items[key] = item
	return item
end

local function _wo_has_overlay_for(unit)
	return WO and WO.has_overlay_for_unit and WO:has_overlay_for_unit(unit) or false
end

local function _project_anchor(anchor, view)
	local dir = anchor - view.cam_pos
	mvector3.normalize(dir)
	local sx, sy, off
	if mvector3.dot(view.fwd, dir) > 0 then
		local sp = view.ws:world_to_screen(view.cam, anchor)
		sx = sp.x * view.scale_x
		sy = sp.y * view.scale_y
		off = (sx < view.m_edge or sx > view.pnl_w - view.m_edge
			or sy < view.m_edge or sy > view.pnl_h - view.m_edge)
	else
		off = true
		local dx = mvector3.dot(dir, view.right)
		local dy = mvector3.dot(dir, view.up)
		sx = (dx >= 0) and (view.pnl_w - view.m_edge) or view.m_edge
		sy = view.pnl_h * 0.5 - dy * view.pnl_h * 0.4
	end
	sx = math.clamp(sx, view.m_edge, view.pnl_w - view.m_edge)
	sy = math.clamp(sy, view.m_edge, view.pnl_h - view.m_edge)
	return sx, sy, off
end

local function _paint_item(item, rec, pct, fill_color, text_color, paint, p_show, CURIOUS, kind_textures)
	local show_text = paint.show_text and (item._active_frames or 0) >= 2
	Glyph.paint_text_pair(item.txt, item.shadow, show_text, pct, text_color)

	if item.kind_icon and alive(item.kind_icon) then
		if paint.show_kind_icon then
			_paint_kind_icon(item, rec, fill_color, kind_textures)
		else
			item.kind_icon:set_visible(false)
		end
	end

	if paint.fill_eye and item.eye then
		if item._with_obj_fill and alive(item.clip) then
			local sz = item.size
			local has_progress = type(p_show) == "number"
			local fp = has_progress and math.clamp(p_show, 0, 1) or 0
			Glyph.render_clipped_fill(item.clip, item.eye, sz + 4, 0, fp, fill_color)
			if alive(item.hollow) then
				local hollow_color = has_progress and CURIOUS or DI.Color.UNKNOWN
				item.hollow:set_color(hollow_color:with_alpha(math.max(0, 1 - fp * 1.4)))
			end
		else
			item.eye:set_color(fill_color)
		end
	elseif item.eye and alive(item.eye) then
		item.eye:set_visible(false)
		if item.hollow and alive(item.hollow) then item.hollow:set_visible(false) end
		if item.clip and alive(item.clip) then item.clip:set_visible(false) end
	end
end

local function _build_view(cam, panel, ws)
	local hud_p = panel:parent()
	local ws_p  = ws:panel()
	return {
		cam     = cam,
		ws      = ws,
		fwd     = cam:rotation():y(),
		right   = cam:rotation():x(),
		up      = cam:rotation():z(),
		cam_pos = cam:position(),
		pnl_w   = hud_p:w(),
		pnl_h   = hud_p:h(),
		scale_x = hud_p:w() / math.max(1, ws_p:w()),
		scale_y = hud_p:h() / math.max(1, ws_p:h()),
		m_edge  = 30,
	}
end

local function _unit_anchor(unit)
	if not alive(unit) then return nil end
	if unit.movement then
		local ok_m, movement = pcall(function() return unit:movement() end)
		if ok_m and movement and movement.m_head_pos then
			local ok_h, head = pcall(function() return movement:m_head_pos() end)
			if ok_h and head then return head end
		end
	end
	if unit.position then
		local ok_p, pos = pcall(function() return unit:position() end)
		if ok_p then return pos end
	end
	return nil
end

function H.place_records(records, roles, allowed, cfg, cam)
	for key in pairs(H._items) do
		if not allowed[key] then H.destroy(key) end
	end
	if not (H._panel and alive(H._panel) and cam) then return end

	if _G.DP and _G.DP._colors_dirty then
		DI.Color.refresh_from_settings()
		_G.DP._colors_dirty = false
	end
	local CURIOUS = DI.Color.CURIOUS
	local view    = _build_view(cam, H._panel, H._ws)

	for key, rec in pairs(records) do
		if allowed[key] then
			local p_show = rec.display or rec.progress
			local phase  = rec.phase or DI.Phase.UNCOVER
			local p_text = rec.progress

			-- Layout
			local layout
			if rec._target_alert then
				layout = "target_alert"
			elseif rec.kind == "obj" then
				layout = "obj"
			elseif phase == DI.Phase.SUSPICION then
				layout = "suspicion"
			else
				layout = "flat"
			end

			-- View values (was Phase.view_hud_item)
			local pct, fill_color, text_color
			if rec._target_alert then
				pct        = "!"
				fill_color = DI.Color.ALERTED
				text_color = DI.Color.ALERTED
			elseif p_text == nil then
				pct        = "?%"
				fill_color = DI.Color.UNKNOWN
				text_color = DI.Color.UNKNOWN
			else
				pct        = DI.HudView.pct_str(phase, p_text)
				fill_color = DI.HudView.fill_color(phase, p_show or 0)
				text_color = DI.HudView.fill_color(phase, p_text)
			end

			local kind_icon_visible = layout == "suspicion"
			local sy_offset = layout == "suspicion" and -24 or 0

			local item = _request(key, rec.kind, layout, cfg, CURIOUS)
			local unit = rec.unit
			local head = _unit_anchor(unit)
			item._active_frames = (item._active_frames or 0) + 1
			if not head then
				item.panel:set_visible(false)
			else
				local anchor = head + Vector3(0, 0, (rec.kind == "obj") and 35 or 30)
				local sx, sy, off = _project_anchor(anchor, view)

				sy = _adjust_sy(sy, rec.kind, roles[unit:key()], sy_offset, off, view.m_edge, view.pnl_h)

				local has_wo  = _wo_has_overlay_for(unit)
				local visible = _should_show(off, layout, has_wo)
				if not visible then
					item.panel:set_visible(false)
				else
					local hide_wo = _hide_for_waypoint_overlay(rec, layout, has_wo, cfg)
					local paint   = _decide_paint(rec, layout, kind_icon_visible, cfg, hide_wo)
					local kt = A.kind_textures_for(cfg.icon_style)
					_paint_item(item, rec, pct, fill_color, text_color, paint, p_show, CURIOUS, kt)
					item.panel:set_visible(true)
					item.panel:set_center(sx, sy)
					item.panel:set_alpha(_alpha_for_distance((anchor - view.cam_pos):length()))
				end
			end
		end
	end
end
