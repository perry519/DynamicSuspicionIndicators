if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.Logger = DI.Logger or {}
local L = DI.Logger

L.LEVEL = L.LEVEL or {
	off   = 0,
	error = 1,
	warn  = 2,
	info  = 3,
	debug = 4,
	trace = 5,
}
L._once = L._once or {}

-- Release default: log only problems users may need for support.
L.level = L.level or L.LEVEL.warn
L.debug = L.level >= L.LEVEL.debug

local LABEL_BY_LEVEL = {
	[L.LEVEL.error] = "ERROR",
	[L.LEVEL.warn] = "WARN",
	[L.LEVEL.info] = "INFO",
	[L.LEVEL.debug] = "DEBUG",
	[L.LEVEL.trace] = "TRACE",
}

local PREFIX = "[DynamicSuspicionIndicators] "

local function _set_debug_flags()
	L.debug = L.level >= L.LEVEL.debug
	L.trace_enabled = L.level >= L.LEVEL.trace
end

local function _level_value(level)
	if type(level) == "string" then
		level = L.LEVEL[level]
	end
	return tonumber(level) or L.LEVEL.warn
end

function L.set_level(level)
	level = _level_value(level)
	L.level = tonumber(level) or L.LEVEL.warn
	_set_debug_flags()
end

local function _enabled(level)
	return L.level >= level
end

local function _emit(level, label, msg, console)
	if not _enabled(level) then return end
	local m = PREFIX .. (label and (label .. ": ") or "") .. tostring(msg)
	log(m)
	if console and _G.Console then Console:Log(m) end
end

function L.error(msg)
	_emit(L.LEVEL.error, "ERROR", msg)
end

function L.warn(msg)
	_emit(L.LEVEL.warn, "WARN", msg)
end

function L.info(msg)
	_emit(L.LEVEL.info, nil, msg)
end

function L.dbg(msg)
	_emit(L.LEVEL.debug, "DEBUG", msg, true)
end

function L.trace(msg)
	_emit(L.LEVEL.trace, "TRACE", msg, true)
end

function L.once(level, key, msg)
	level = _level_value(level)
	key = tostring(key or msg)
	if L._once[key] or not _enabled(level) then return end
	L._once[key] = true
	_emit(level, LABEL_BY_LEVEL[level], msg, level >= L.LEVEL.debug)
end

function L.is_debug()
	return _enabled(L.LEVEL.debug)
end

function L.is_trace()
	return _enabled(L.LEVEL.trace)
end

_set_debug_flags()
