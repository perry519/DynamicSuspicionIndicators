-- Shared HUD glyph primitives: texture swaps, text pairs, and clipped fills

if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.HudGlyph = DI.HudGlyph or {}
local G = DI.HudGlyph
local alive = DI.Game.alive
local A = DI.Assets

function G.kind_texture(kind_textures, kind, variant)
	local set = kind_textures and (kind_textures[kind] or kind_textures.civilian)
	return set and set[variant or "curious"]
end

function G.set_bitmap_image(bitmap, texture)
	if alive(bitmap) and texture then
		pcall(function() bitmap:set_image(texture) end)
		return true
	end
	return false
end

function G.paint_text_pair(text, shadow, visible, value, color, cx, cy)
	local t = visible and (value or "") or ""
	if alive(text) then
		text:set_text(t)
		text:set_visible(visible)
		if visible then
			if color then text:set_color(color) end
			if cx and cy then text:set_center(cx, cy) end
		end
	end
	if alive(shadow) then
		shadow:set_text(t)
		shadow:set_visible(visible)
		if visible and cx and cy then shadow:set_center(cx + 1, cy + 1) end
	end
end

function G.render_clipped_fill(clip, filled, size, base_y, progress, color)
	local fp = math.clamp(progress or 0, 0, 1)
	if alive(clip) then
		clip:set_h(math.max(0, size * fp))
		clip:set_y((base_y or 0) + size * (1 - fp))
	end
	if alive(filled) then
		filled:set_y(-size * (1 - fp))
		filled:set_color(color)
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
	bitmap:set_visible(state._kind_tex_for ~= nil)
	if color then bitmap:set_color(color) end
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
