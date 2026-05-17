if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.HudView = DI.HudView or {}
local V = DI.HudView
local P = DI.Phase

function V.fill_color(phase, p)
	local C = DI.Color
	if phase == P.SUSPICION then return C.lerp_suspicion(p) end
	if phase == P.ALERTED then return C.ALERTED end
	return C.lerp(p)
end

function V.pct_str(phase, p)
	local pn = math.clamp(p, 0, 1)
	if phase == P.SUSPICION then
		return string.format("%d%%", math.floor((pn - 1) * 100 + 0.5))
	end
	return string.format("%d%%", math.floor(pn * 100 + 0.5))
end
