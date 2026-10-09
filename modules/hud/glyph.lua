-- Shared HUD glyph primitives: texture swaps, text pairs, and clipped fills

if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.HudGlyph = DI.HudGlyph or {}
local G = DI.HudGlyph
local alive = DI.Game.alive
local A = DI.Assets
local gui_state = setmetatable({}, { __mode = "k" })

local function _state(element)
	local state = gui_state[element]
	if not state then
		state = {}
		gui_state[element] = state
	end
	return state
end

function G.set_visible(element, visible)
	if alive(element) and element:visible() ~= visible then element:set_visible(visible) end
end

function G.set_alpha(element, alpha)
	if alive(element) and element:alpha() ~= alpha then element:set_alpha(alpha) end
end

function G.set_color(element, color)
	if not (alive(element) and color) then return end
	local state = _state(element)
	local r, g, b, a = color.r, color.g, color.b, color.a
	local has_components = r ~= nil or g ~= nil or b ~= nil or a ~= nil
	local unchanged = has_components and state.color_components
		and state.color_r == r and state.color_g == g and state.color_b == b and state.color_a == a
		or not has_components and state.color_ref == color
	if unchanged then return end
	element:set_color(color)
	state.color_ref = color
	state.color_components = has_components
	state.color_r, state.color_g, state.color_b, state.color_a = r, g, b, a
end

function G.set_text(element, value)
	if not alive(element) then return end
	local state = _state(element)
	if state.text == value then return end
	element:set_text(value)
	state.text = value
end

function G.set_center(element, x, y)
	if not alive(element) then return end
	local state = _state(element)
	if state.center_x == x and state.center_y == y then return end
	element:set_center(x, y)
	state.center_x, state.center_y = x, y
end

function G.kind_texture(kind_textures, kind, variant)
	local set = kind_textures and (kind_textures[kind] or kind_textures.civilian)
	return set and set[variant or "curious"]
end

function G.set_bitmap_image(bitmap, texture)
	if alive(bitmap) and texture then
		return pcall(function() bitmap:set_image(texture) end)
	end
	return false
end

function G.paint_text_pair(text, shadow, visible, value, color, cx, cy)
	local t = visible and (value or "") or ""
	if alive(text) then
		G.set_text(text, t)
		G.set_visible(text, visible)
		if visible then
			G.set_color(text, color)
			if cx and cy then G.set_center(text, cx, cy) end
		end
	end
	if alive(shadow) then
		G.set_text(shadow, t)
		G.set_visible(shadow, visible)
		if visible and cx and cy then G.set_center(shadow, cx + 1, cy + 1) end
	end
end

function G.render_clipped_fill(clip, filled, size, base_y, progress, color)
	local fp = math.clamp(progress or 0, 0, 1)
	if alive(clip) then
		local h = math.max(0, size * fp)
		local y = (base_y or 0) + size * (1 - fp)
		if clip:h() ~= h then clip:set_h(h) end
		if clip:y() ~= y then clip:set_y(y) end
	end
	if alive(filled) then
		local y = -size * (1 - fp)
		if filled:y() ~= y then filled:set_y(y) end
		G.set_color(filled, color)
	end
end

function G.set_kind_fill(glyph, kind, kind_textures)
	if glyph.kind_set and glyph.kind == kind and glyph._kind_textures == kind_textures then return end
	G.set_bitmap_image(glyph.hollow, G.kind_texture(kind_textures, kind, "curious"))
	G.set_bitmap_image(glyph.filled, G.kind_texture(kind_textures, kind, "curious"))
	glyph.kind, glyph.kind_set, glyph._alerted_swap = kind, true, false
	glyph._kind_textures = kind_textures
end

function G.set_kind_alert(glyph, alerted, kind_textures)
	if not (alive(glyph.filled) and glyph.kind) then return end
	if glyph._alerted_swap == alerted and glyph._kind_textures == kind_textures then return end
	G.set_bitmap_image(glyph.filled, G.kind_texture(kind_textures, glyph.kind, alerted and "alerted" or "curious"))
	glyph._alerted_swap = alerted
end

function G.paint_kind_bitmap(bitmap, state, kind, kind_textures, color)
	if not alive(bitmap) then return false end
	if not state._kind_tex_for or state._kind_textures ~= kind_textures then
		if G.set_bitmap_image(bitmap, G.kind_texture(kind_textures, kind, "curious")) then
			state._kind_tex_for = kind
			state._kind_textures = kind_textures
		end
	end
	G.set_visible(bitmap, state._kind_tex_for ~= nil)
	G.set_color(bitmap, color)
	return state._kind_tex_for ~= nil
end

function G.build_question_text(parent, name, layer, size, font_size, x, y, color)
	return parent:text({
		name = name, text = "?",
		font = A.font_hud, font_size = font_size,
		w = size, h = size + 4, x = x, y = y,
		color = color, layer = layer, align = "center", vertical = "center",
	})
end

function G.build_question_bitmap(parent, name, texture, layer, size, x, y, color)
	return parent:bitmap({
		name = name, texture = texture,
		w = size, h = size, x = x, y = y,
		color = color, layer = layer, blend_mode = "normal",
	})
end

function G.build_question_fill(panel, opts)
	local extra_h = opts.extra_h or 0
	local clip = panel:panel({
		name = opts.clip_name, w = opts.size, h = opts.size + extra_h,
		x = opts.x, y = opts.y, layer = 2,
	})
	local hollow, filled
	if opts.texture then
		hollow = G.build_question_bitmap(panel, opts.hollow_name, opts.texture, 1, opts.size, opts.x, opts.y, opts.hollow_color)
		filled = G.build_question_bitmap(clip, opts.filled_name, opts.texture, 1, opts.size, 0, 0, Color.white)
	else
		hollow = G.build_question_text(panel, opts.hollow_name, 1, opts.size, opts.font_size, opts.x, opts.y, opts.hollow_color)
		filled = G.build_question_text(clip, opts.filled_name, 1, opts.size, opts.font_size, 0, 0, Color.white)
	end
	return hollow, clip, filled
end
