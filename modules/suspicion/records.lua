-- Records data model

if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.Records = DI.Records or {}
local R = DI.Records
local G = DI.Game
local alive = G.alive
local U = DI.Units

R.records      = R.records      or {}
R._smooth      = R._smooth      or {}
R._smooth_phase = R._smooth_phase or {}
R._alert_flash = R._alert_flash or {}
R._target_alerts = R._target_alerts or {}
R._target_peaks = R._target_peaks or {}
R._observer_alerts = R._observer_alerts or {}
R._prev        = R._prev        or {}

local FLASH_HOLD_SEC  = 1.0
local TARGET_ALERT_HOLD_SEC = 3.0
local TARGET_PEAK_STALE_SEC = 1.0
local OBSERVER_ALERT_STALE_SEC = 1.0
local TARGET_ALERT_PROMOTE_P = 0.90
local FLASH_PROMOTE_P = 0.6

local function _key(unit, kind)
	if kind == "obj" then return "obj:" .. tostring(unit:key()) end
	return unit:key()
end

local function _observer_can_hold_target_alert(observer)
	return alive(observer) and not U.pacified(observer)
end

local function _observer_alerted_recently(observer, now_t)
	if U.alerted(observer) then return true end
	if not (alive(observer) and observer.key) then return false end
	local t = R._observer_alerts[observer:key()]
	return type(t) == "number" and now_t - t <= OBSERVER_ALERT_STALE_SEC
end

local function _target_marker_expired(marker, now_t, max_age)
	return now_t - marker.t > max_age
		or not alive(marker.unit)
		or not _observer_can_hold_target_alert(marker.observer)
end

function R.clear()
	R.records = {}
end

function R.note_observer_alerted(observer, now_t)
	if not (alive(observer) and observer.key) then return end
	R._observer_alerts[observer:key()] = now_t or G.now()
end

local function _mark_target_alert(target, observer, now_t)
	if not (alive(target) and _observer_can_hold_target_alert(observer)) then return end
	local k = _key(target, "obj")
	R._target_alerts[k] = {
		unit = target,
		observer = observer,
		t = now_t or G.now(),
	}
end

function R.put(unit, progress, kind, phase, source_observer)
	if not unit then return end
	local k = _key(unit, kind)
	if kind == "obj" and type(progress) == "number" and progress > 0.01 then
		R._target_alerts[k] = nil
		if _observer_can_hold_target_alert(source_observer) then
			R._target_peaks[k] = {
				unit = unit,
				observer = source_observer,
				armed = progress >= TARGET_ALERT_PROMOTE_P,
				t = G.now(),
			}
		end
	end
	local cur = R.records[k]
	if cur then
		if cur.phase == DI.Phase.ALERTED and not cur._target_alert then return end
		if progress == nil then return end
		if cur.progress ~= nil and progress <= cur.progress then return end
	end
	R.records[k] = {
		unit     = unit,
		progress = (progress ~= nil) and math.clamp(progress, 0, 1) or nil,
		kind     = kind,
		phase    = phase or DI.Phase.UNCOVER,
	}
end

local function _record_allowed(rec, cfg)
	if rec.kind == "obj" then
		if rec._target_alert then return cfg.show_targets end
		return cfg.show_targets and (cfg.show_target_fill or (cfg.show_numeric_values and cfg.show_numeric_targets))
	end
	return cfg.show_numeric_values and cfg.show_numeric_observers
		and (cfg.show_numeric_observer_waypoints or cfg.show_numeric_observer_units)
end

function R.tick(now_t, dt, cfg)
	for k, f in pairs(R._target_peaks) do
		if _target_marker_expired(f, now_t, TARGET_PEAK_STALE_SEC) then
			R._target_peaks[k] = nil
		elseif not R.records[k] and (f.armed or _observer_alerted_recently(f.observer, now_t)) then
			_mark_target_alert(f.unit, f.observer, now_t)
			R._target_peaks[k] = nil
		end
	end

	for key, t in pairs(R._observer_alerts) do
		if now_t - t > OBSERVER_ALERT_STALE_SEC then R._observer_alerts[key] = nil end
	end

	for k, f in pairs(R._target_alerts) do
		if _target_marker_expired(f, now_t, TARGET_ALERT_HOLD_SEC) then
			R._target_alerts[k] = nil
		end
	end
	for k, f in pairs(R._target_alerts) do
		if not R.records[k] then
			R.records[k] = {
				unit = f.unit,
				progress = nil,
				kind = "obj",
				phase = DI.Phase.ALERTED,
				_target_alert = true,
			}
		end
	end

	for k, f in pairs(R._alert_flash) do
		if now_t - f.t > FLASH_HOLD_SEC or not alive(f.unit) then R._alert_flash[k] = nil end
	end
	for k, prev in pairs(R._prev) do
		if prev.kind ~= "obj" and not R.records[k] and prev.progress and prev.progress >= FLASH_PROMOTE_P
			and alive(prev.unit) and prev.phase == DI.Phase.ALERTED then
			R._alert_flash[k] = { unit = prev.unit, kind = prev.kind, t = now_t }
		end
	end
	for k, f in pairs(R._alert_flash) do
		if not R.records[k] then
			R.records[k] = { unit = f.unit, progress = 1.0, kind = f.kind, phase = DI.Phase.ALERTED, _flash = true }
		end
	end
	R._prev = {}
	for k, rec in pairs(R.records) do
		if not rec._flash then
			R._prev[k] = {
				unit = rec.unit,
				kind = rec.kind,
				progress = rec.progress,
				phase = rec.phase,
			}
		end
	end

	local speed = (cfg and cfg.smooth_speed) or DI.smooth_speed or 5
	local kbase = math.min(1, dt * speed)
	for key, rec in pairs(R.records) do
		if rec.progress == nil then
			R._smooth[key] = nil
			R._smooth_phase[key] = nil
			rec.display = nil
		else
			local phase = rec.phase or DI.Phase.UNCOVER
			local d = R._smooth[key]
			if R._smooth_phase[key] ~= phase then
				d = rec.progress
			else
				d = d or rec.progress
			end
			d = d + (rec.progress - d) * kbase
			R._smooth[key] = d
			R._smooth_phase[key] = phase
			rec.display = d
		end
	end
	for key in pairs(R._smooth) do
		if not R.records[key] then
			R._smooth[key] = nil
			R._smooth_phase[key] = nil
		end
	end

	local roles = {}
	for _, rec in pairs(R.records) do
		if alive(rec.unit) then
			local uk = rec.unit:key()
			local r = roles[uk] or { target = false, observer = false }
			if rec.kind == "obj" then r.target = true else r.observer = true end
			roles[uk] = r
		end
	end
	local allowed = {}
	if cfg then
		for key, rec in pairs(R.records) do
			if _record_allowed(rec, cfg) then allowed[key] = true end
		end
	end
	return roles, allowed
end
