-- Color preview lifecycle, state, and animation loop.

local G = DynamicSuspicionIndicatorsManager and DynamicSuspicionIndicatorsManager.Game
local Menu = DP.Menu or {}
DP.Menu = Menu
local ColorPreview = {}
Menu.ColorPreview = ColorPreview
local Paint = Menu.ColorPreviewPaint
local Row = Menu.ColorPreviewRow

DP._color_preview_rows = {}
DP._color_preview_overrides = nil

local COLOR_PREVIEW_PROGRESS = {
	early_sus = 0,
	curious = 0,
	midway = 0.5,
	critical = 0.99,
	alerted = 1,
}
local ANIM_SPEED = 0.3
local COLOR_PREVIEW_ANIM = {
	early_sus = { 0, 1, home = 0 },
	curious   = { 0, 1, home = 0 },
}
local COLOR_PREVIEW_VISIBLE = {
	early_sus = function() return DP.settings.show_early_unmasked_suspicion == true end,
	alerted = function() return DP.settings.separate_alerted_color == true end,
}
local COLOR_PREVIEW_ROW_OFFSET = 1.25

function ColorPreview.attach_from_arg(gui, row_or_item)
	local row_item, item_name = Row.from_arg(gui, row_or_item)
	if type(item_name) ~= "string" or not row_item then return end
	local key = item_name:match("^dp_pick_color_([%w_]+)$")
	if key then
		DP:_AttachColorPreviewRow(gui, row_item, key, COLOR_PREVIEW_ROW_OFFSET)
		return
	end
	key = item_name:match("^dp_color_([%w_]+)_b$")
	if key then
		local existing = DP._color_preview_rows[key]
		if not (existing and existing == row_item and alive(existing.dp_color_preview_panel)) then
			DP:_AttachColorPreviewRow(gui, row_item, key, COLOR_PREVIEW_ROW_OFFSET)
		end
	end
end

function DP:_AttachColorPreviewRow(menu_gui, row_item, key, row_offset, no_defer)
	local progress = COLOR_PREVIEW_PROGRESS[key]
	local parent, row_local = Row.parent(row_item, menu_gui)
	if not progress or not alive(parent) then return end

	local had_preview = self._color_preview_rows[key] ~= nil
	local old = self._color_preview_rows[key]
	if old and old ~= row_item and alive(old.dp_color_preview_panel) then
		old.dp_color_preview_panel:parent():remove(old.dp_color_preview_panel)
		old.dp_color_preview_panel = nil
	end

	local size = 30
	local gap = 6
	local texture_sets = Paint.texture_sets()
	local sample_w = (#texture_sets * size) + (math.max(0, #texture_sets - 1) * gap)
	local row_y, row_h = Row.y(row_item)
	local x = Row.preview_x(parent, row_item, sample_w)
	local y = math.max(0, math.floor(((row_h or size) - size) * 0.5))
	if not row_local then
		y = math.floor(row_y + y + ((row_h or size) * (row_offset or 0)))
	end

	local sample = row_item.dp_color_preview_panel
	if not alive(sample) then
		sample = parent:panel({
			name = "dp_color_preview_" .. key,
			x = x, y = y, w = sample_w, h = size,
			layer = G.menu_layer() + 1,
		})
		row_item.dp_color_preview_panel = sample
	else
		sample:set_x(x)
		sample:set_y(y)
		sample:set_w(sample_w)
	end

	row_item.dp_color_preview_key = key
	row_item.dp_color_preview_progress = progress
	row_item.dp_color_preview_menu_gui = menu_gui
	row_item.dp_color_preview_row_offset = row_offset or 0
	self._color_preview_rows[key] = row_item
	local vis_fn = COLOR_PREVIEW_VISIBLE[key]
	local vis = not vis_fn or vis_fn()
	if had_preview then
		sample:set_visible(vis)
	else
		sample:set_visible(vis and no_defer == true)
	end
	Paint.paint_sample(sample, key, progress, self._color_preview_overrides)

	local defer_frames = (not no_defer and not had_preview and not row_item.dp_color_preview_deferred) and 2 or 0
	if defer_frames > 0 then row_item.dp_color_preview_deferred = true end

	if defer_frames > 0 then
		sample:animate(function()
			coroutine.yield()
			coroutine.yield()
			row_item.dp_color_preview_deferred = nil
			local vfn = COLOR_PREVIEW_VISIBLE[key]
			sample:set_visible(not vfn or vfn())
		end)
	end
end

function DP:RefreshColorPreviewRows(overrides)
	self._color_preview_overrides = overrides
	for key, row_item in pairs(self._color_preview_rows or {}) do
		local sample = row_item and row_item.dp_color_preview_panel
		if alive(sample) then
			local vis_fn = COLOR_PREVIEW_VISIBLE[key]
			sample:set_visible(not vis_fn or vis_fn())
			Paint.paint_sample(sample, key, row_item.dp_color_preview_progress or 0, overrides)
		end
	end
end

function DP:RefreshColorPreviewRowsDeferred(overrides)
	self:RefreshColorPreviewRows(overrides)
end

function DP:ClearColorPreviewRows()
	self._color_preview_rows = {}
	self._color_preview_overrides = nil
end

function ColorPreview.add_menu_item(key, priority)
	return MenuHelper:AddDivider({
		id       = "dp_preview_" .. key,
		size     = 40,
		no_text  = true,
		menu_id  = "dp_colors",
		priority = priority,
	})
end

local _anim_frame = 0
G.post_hook(MenuNodeGui, "update", "DP_ColorPreviewUpdate", function(self, t, dt)
	if not DP or not DP._color_preview_rows then return end
	_anim_frame = _anim_frame + 1
	for key, row_item in pairs(DP._color_preview_rows) do
		local sample = row_item and row_item.dp_color_preview_panel
		if alive(sample) and sample:visible() then
			local ro = row_item.dp_color_preview_row_offset or 0
			local ry, rh = Row.y(row_item)
			local sy = math.max(0, math.floor(((rh or sample:h()) - sample:h()) * 0.5))
			sample:set_y(math.floor(ry + sy + (rh * ro)))
			local anim = COLOR_PREVIEW_ANIM[key]
			if anim then
				local tick = math.max(0, math.sin(_anim_frame * ANIM_SPEED * 0.65))
				local p = anim[1] + (anim[2] - anim[1]) * tick
				Paint.paint_sample(sample, key, p, DP._color_preview_overrides)
			end
		end
	end
end)
