-- Phase classification.

if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.Phase = DI.Phase or {}
local P = DI.Phase

P.SUSPICION = "suspicion"
P.UNCOVER   = "uncover"
P.ALERTED   = "alerted"

function P.classify(entry, allow_suspicion, alerted, data_t)
	if type(entry) ~= "table" then return nil, nil end

	if alerted then
		local p = entry.uncover_progress
			or entry.notice_progress
			or entry.suspicion_progress
			or 1
		return P.ALERTED, math.clamp(p, 0, 1)
	end

	if entry.uncover_progress then
		local p = math.clamp(entry.uncover_progress, 0, 1)
		if p > 0.01 then return P.UNCOVER, p end
		return nil, nil
	end

	if entry.pause_expire_t then return nil, nil end

	local p = entry.notice_progress or entry.suspicion_progress
	if p then
		p = math.clamp(p, 0, 1)
		if p <= 0.01 then return nil, nil end
		if allow_suspicion then return P.SUSPICION, p end
		return P.UNCOVER, p
	end

	return nil, nil
end
