_G.DP = _G.DP or {}
DP.settings = DP.settings or {}

DynamicSuspicionIndicatorsManager = DynamicSuspicionIndicatorsManager or {}
local DI = DynamicSuspicionIndicatorsManager
local Settings = {}
DI.Settings = Settings

local function _save_path()
	if not _G.SavePath then return nil end
	return SavePath .. "DynamicSuspicionIndicators.json"
end

local _warn = DI.Logger.warn

local function _apply_defaults()
	if DynamicSuspicionIndicatorsSettingsSchema then
		DynamicSuspicionIndicatorsSettingsSchema.apply_defaults(DP.settings)
	end
end

Settings._listeners = {}

function Settings.subscribe(id, fn)
	Settings._listeners[id] = fn
end

function Settings.unsubscribe(id)
	Settings._listeners[id] = nil
end

function Settings.notify(key, value)
	for _, fn in pairs(Settings._listeners) do
		local ok, err = pcall(fn, key, value)
		if not ok then _warn("settings listener error: " .. tostring(err)) end
	end
end

function Settings.save()
	local path = _save_path()
	if not path then return end
	local f = io.open(path, "w+")
	if not f then
		_warn("settings save failed: cannot open " .. tostring(path))
		return
	end
	local ok, encoded = pcall(json.encode, DP.settings)
	if not ok then
		f:close()
		_warn("settings save failed: " .. tostring(encoded))
		return
	end
	local write_ok, err = pcall(function() f:write(encoded) end)
	f:close()
	if not write_ok then _warn("settings write failed: " .. tostring(err)) end
end

function Settings.load()
	local path = _save_path()
	if not path then
		_apply_defaults()
		return
	end
	local f = io.open(path, "r")
	if not f then
		_apply_defaults()
		return
	end
	local txt = f:read("*all")
	f:close()
	local ok, data = pcall(json.decode, txt)
	if ok and type(data) == "table" then
		for k, v in pairs(data) do DP.settings[k] = v end
	elseif ok then
		_warn("settings load ignored non-table data in " .. tostring(path))
	else
		_warn("settings load failed: " .. tostring(data))
	end
	_apply_defaults()
end

function Settings.get(key)
	return DP.settings[key]
end

function Settings.set(key, value)
	DP.settings[key] = value
	Settings.save()
	Settings.notify(key, value)
end

function Settings.update(map)
	for k, v in pairs(map) do DP.settings[k] = v end
	Settings.save()
	for k, v in pairs(map) do Settings.notify(k, v) end
end

function Settings.set_color(key, color)
	DP.settings["color_" .. key .. "_r"] = color.r
	DP.settings["color_" .. key .. "_g"] = color.g
	DP.settings["color_" .. key .. "_b"] = color.b
	Settings.save()
	Settings.notify("color_" .. key, color)
end

function Settings.get_color(key)
	local s = DP.settings
	return Color(
		s["color_" .. key .. "_r"] or 0,
		s["color_" .. key .. "_g"] or 0,
		s["color_" .. key .. "_b"] or 0
	)
end
