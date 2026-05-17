-- Color preview render: palette, textures, cell layout, sample paint.

local Menu = DP.Menu or {}
DP.Menu = Menu
local Paint = {}
Menu.ColorPreviewPaint = Paint
local C = DynamicSuspicionIndicatorsManager.Color

local PREVIEW_KIND_ORDER_VHP = { "civilian", "guard", "camera" }
local PREVIEW_KIND_ORDER_EXTRA = { "civilian", "guard", "security", "murky", "camera" }

local _cell_counts = setmetatable({}, { __mode = "k" })

local function _default_textures()
	local DI = _G.DynamicSuspicionIndicatorsManager
	local A = DI and DI.Assets
	if A and A.preview_indicator_textures then
		return A.preview_indicator_textures(DP.settings.icon_style, "guard")
	end
	return {
		mode = "icons",
		curious = "assets/guis/textures/dp/vhp_guard_curious",
		alerted = "assets/guis/textures/dp/vhp_guard_alerted",
	}
end

function Paint.texture_sets()
	local DI = _G.DynamicSuspicionIndicatorsManager
	local A = DI and DI.Assets
	local S = DynamicSuspicionIndicatorsSettingsSchema
	local icon_style = DP.settings.icon_style
	if not (A and A.uses_icons_mode and A.uses_icons_mode(icon_style)) then
		return { _default_textures() }
	end
	local kind_textures = A.kind_textures_for and A.kind_textures_for(icon_style)
	local order = (S and S.ICON_STYLES and icon_style == S.ICON_STYLES.EXTRA)
		and PREVIEW_KIND_ORDER_EXTRA or PREVIEW_KIND_ORDER_VHP
	local sets = {}
	for _, kind in ipairs(order) do
		if kind_textures and kind_textures[kind] then
			table.insert(sets, kind_textures[kind])
		end
	end
	if #sets == 0 then
		table.insert(sets, _default_textures())
	end
	return sets
end

local function _set_bitmap_texture(bitmap, texture, texture_rect)
	if not alive(bitmap) then return end
	pcall(function()
		if texture_rect then
			bitmap:set_image(texture, texture_rect[1], texture_rect[2], texture_rect[3], texture_rect[4])
		else
			bitmap:set_image(texture)
		end
	end)
end

local function _ensure_cells(sample, count, size, gap)
	if not alive(sample) then return end
	if _cell_counts[sample] == count then return end
	pcall(function() sample:clear() end)
	for i = 1, count do
		local cell = sample:panel({
			name = "cell_" .. tostring(i),
			x = (i - 1) * (size + gap),
			y = 0,
			w = size,
			h = size,
			layer = 1,
		})
		cell:bitmap({
			name = "hollow",
			w = size, h = size, x = 0, y = 0,
			layer = 1,
			blend_mode = "normal",
		})
		local clip = cell:panel({
			name = "clip",
			w = size, h = size, x = 0, y = size,
			layer = 2,
		})
		clip:bitmap({
			name = "filled",
			w = size, h = size, x = 0, y = -size,
			layer = 1,
			blend_mode = "normal",
		})
	end
	_cell_counts[sample] = count
end

function Paint.paint_sample(sample, key, progress, overrides)
	if not alive(sample) then return end
	local texture_sets = Paint.texture_sets()
	local color = C.fill_for_key(key, progress, overrides)
	local hollow_key = key == "early_sus" and "early_sus" or "curious"
	local size = sample:h()
	local gap = 6
	_ensure_cells(sample, #texture_sets, size, gap)
	for i, textures in ipairs(texture_sets) do
		local texture = key == "alerted" and textures.alerted or textures.curious
		local texture_rect = key == "alerted" and textures.alerted_rect or nil
		local cell = sample:child("cell_" .. tostring(i))
		local hollow = cell and cell:child("hollow")
		local clip = cell and cell:child("clip")
		local filled = clip and clip:child("filled")
		if alive(hollow) then
			_set_bitmap_texture(hollow, texture, texture_rect)
			hollow:set_color(C.from_settings(hollow_key, overrides))
			hollow:set_alpha(progress >= 1 and 0 or 0.85)
		end
		if alive(clip) then
			clip:set_h(math.max(0, size * progress))
			clip:set_y(size * (1 - progress))
			clip:set_visible(true)
		end
		if alive(filled) then
			_set_bitmap_texture(filled, texture, texture_rect)
			filled:set_y(-size * (1 - progress))
			filled:set_color(color)
			filled:set_visible(true)
		end
	end
end
