-- BLT menu row Adapter for color preview attachment.

local Menu = DP.Menu or {}
DP.Menu = Menu
local Row = {}
Menu.ColorPreviewRow = Row

local RIGHT_OFFSET = 14

function Row.parent(row_item, menu_gui)
	return menu_gui and menu_gui.item_panel, false
end

function Row.y(row_item)
	if row_item and row_item.gui_panel and alive(row_item.gui_panel) then
		return row_item.gui_panel:y(), row_item.gui_panel:h()
	end
	if row_item and row_item.gui_text and alive(row_item.gui_text) then
		return row_item.gui_text:y(), row_item.gui_text:h()
	end
	return 0, 30
end

local function _item_name(row_item)
	if not row_item then return nil end
	if type(row_item.name) == "string" then return row_item.name end
	local item = row_item.item
	local params = item and ((item.parameters and item:parameters()) or item._parameters)
	return params and params.name
end

function Row.from_arg(menu_gui, row_or_item)
	if not row_or_item then return nil, nil end
	if row_or_item.item then
		return row_or_item, _item_name(row_or_item)
	end
	local params = (row_or_item.parameters and row_or_item:parameters()) or row_or_item._parameters
	local item_name = params and params.name
	local row_item = menu_gui and menu_gui.row_item and menu_gui:row_item(row_or_item)
	return row_item, item_name
end

function Row.preview_x(parent, row_item, size)
	if row_item and row_item.gui_panel and alive(row_item.gui_panel) then
		local panel_x = row_item.gui_panel:x()
		local panel_w = row_item.gui_panel:w()
		if panel_x and panel_w and panel_w > size then
			return math.floor(panel_x + panel_w - size - 18 + RIGHT_OFFSET)
		end
	end
	if row_item and row_item.gui_text and alive(row_item.gui_text) then
		local text_x = row_item.gui_text:x()
		local text_w = row_item.gui_text:w()
		if text_x and text_w and text_w > size then
			return math.floor(text_x + text_w - size - 18 + RIGHT_OFFSET)
		end
		if text_x and text_x > size then
			return math.floor(text_x - size - 20)
		end
	end
	return math.floor((parent:w() - size) * 0.5)
end
