if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.Color = DI.Color or {}
local C = DI.Color

local DEFAULT = {
	early_sus = { 1, 1, 1 },
	curious   = { 0, 0.65, 1 },
	midway    = { 1, 1, 0 },
	critical  = { 1, 0.2, 0 },
	alerted   = { 1, 0.2, 0 },
}

local function _settings()
	return _G.DP and _G.DP.settings or {}
end

function C.from_settings(key, overrides)
	if overrides and overrides[key] then return overrides[key] end
	local st = _settings()
	local d = DEFAULT[key] or { 0, 0, 0 }
	return Color(
		st["color_" .. key .. "_r"] or d[1],
		st["color_" .. key .. "_g"] or d[2],
		st["color_" .. key .. "_b"] or d[3]
	)
end

function C.lerp_color(a, b, t)
	return Color(math.lerp(a.r, b.r, t), math.lerp(a.g, b.g, t), math.lerp(a.b, b.b, t))
end

function C.fill_for_key(key, progress, overrides)
	progress = math.clamp(progress or 0, 0, 1)
	if key == "early_sus" then
		return C.lerp_color(
			C.from_settings("early_sus", overrides),
			C.from_settings("curious", overrides),
			progress
		)
	elseif key == "alerted" then
		return C.from_settings("alerted", overrides)
	end

	local curious = C.from_settings("curious", overrides)
	local midway = C.from_settings("midway", overrides)
	local critical = C.from_settings("critical", overrides)
	if progress < 0.5 then
		return C.lerp_color(curious, midway, progress * 2)
	end
	return C.lerp_color(midway, critical, (progress - 0.5) * 2)
end

function C.refresh_from_settings()
	local st = _settings()
	C.EARLY_SUS = C.from_settings("early_sus")
	C.CURIOUS   = C.from_settings("curious")
	C.MIDWAY    = C.from_settings("midway")
	C.CRITICAL  = C.from_settings("critical")
	C.ALERTED   = C.from_settings("alerted")
	if not st.separate_alerted_color then C.ALERTED = Color(C.CRITICAL.r, C.CRITICAL.g, C.CRITICAL.b) end
end
C.UNKNOWN  = Color(0.6,  0.6,  0.6)
C.refresh_from_settings()

function C.lerp_suspicion(p)
	p = math.clamp(p, 0, 1)
	local a, b = C.EARLY_SUS, C.CURIOUS
	return C.lerp_color(a, b, p)
end

function C.lerp(p)
	p = math.clamp(p, 0, 1)
	local a, b, t
	if p < 0.5 then
		a, b, t = C.CURIOUS, C.MIDWAY, p * 2
	else
		a, b, t = C.MIDWAY, C.CRITICAL, (p - 0.5) * 2
	end
	return C.lerp_color(a, b, t)
end
