-- Client sync-off detection fallback.

if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.Detection = DI.Detection or {}
local Fallback = {}
DI.Detection.Fallback = Fallback

local D = DI.Detection
local G = DI.Game
local alive = G.alive
local U = DI.Units

-- Fallback-only state. Shared D namespace so Core._reset_client_state can clear.
D._los_cache         = D._los_cache         or {}
D._camera_susp_seq   = D._camera_susp_seq   or 0
D._camera_susp_seen  = D._camera_susp_seen  or {}
D._camera_fb_min_seq = D._camera_fb_min_seq or 0
D._cam_lvl_prev      = D._cam_lvl_prev      or {}

local LOS_TTL       = 0.2
local MAX_RADIUS_SQ = 3000 * 3000

------------------------------------------------------------
-- Install
------------------------------------------------------------

function Fallback.install_camera_event_patch()
	G.patch_security_camera_sync_net_event("_dsi_sne_orig", function(self, event_id, orig, ...)
		local base = _G.SecurityCamera and SecurityCamera._NET_EVENTS and SecurityCamera._NET_EVENTS.suspicion_1
		if base and event_id >= base and event_id <= base + 5 then
			D._camera_susp_seq = (D._camera_susp_seq or 0) + 1
			if self._unit and self._unit.key then
				D._camera_susp_seen[self._unit:key()] = D._camera_susp_seq
			end
		end
		return orig(self, event_id, ...)
	end)
end

-- Called when sync transitions active → inactive. Prevents stale susp_seen counts
-- from this cam being treated as fresh detection events.
function Fallback.on_mode_switch_to_fallback()
	D._camera_fb_min_seq = D._camera_susp_seq or 0
end

------------------------------------------------------------
-- Player suspicion aggregation
------------------------------------------------------------

local function _build_player_susp_data(pu, peer_susp_by_pid)
	local data = {}
	local sess = G.session()
	if not sess then return data end
	local any_detected = false
	for _, sv in pairs(peer_susp_by_pid) do
		if sv > 0.01 then any_detected = true; break end
	end
	if not any_detected then return data end
	local function _add(p_unit, pid)
		if not (alive(p_unit) and pid) then return end
		local sv = peer_susp_by_pid[pid] or 0
		if sv <= 0.01 then return end
		local mov = p_unit.movement and p_unit:movement()
		local pos = (mov and mov.m_pos and mov:m_pos()) or p_unit:position()
		if not pos then return end
		data[pid] = { unit = p_unit, px = pos.x, py = pos.y, pz = pos.z, susp = sv }
	end
	for _, peer in pairs(sess:peers()) do
		_add(peer.unit and peer:unit(), peer.id and peer:id())
	end
	local lp = sess.local_peer and sess:local_peer()
	_add(pu, lp and lp.id and lp:id())
	return data
end

-- Build closure: obs_susp(unit) → nearest-player suspicion value, LOS-attributed.
local function _make_obs_susp(cfg, player_susp_data, now_t)
	return function(obs_unit)
		if not cfg.client_aggregate_fallback then return nil end
		if not alive(obs_unit) or not next(player_susp_data) then return nil end
		local mov     = obs_unit.movement and obs_unit:movement()
		local obs_pos = (mov and mov:m_pos()) or obs_unit:position()
		local ox, oy, oz = obs_pos.x, obs_pos.y, obs_pos.z

		local best_sq, best_sv, count = math.huge, nil, 0
		for _, pd in pairs(player_susp_data) do
			local dx = pd.px - ox
			local dy = pd.py - oy
			local dz = pd.pz - oz
			local dsq = dx*dx + dy*dy + dz*dz
			count = count + 1
			if dsq < best_sq then best_sq = dsq; best_sv = pd.susp end
		end
		if count == 1 then return best_sv end

		local obs_key = obs_unit:key()
		local oc = D._los_cache[obs_key]
		if not oc then oc = {}; D._los_cache[obs_key] = oc end
		local los_sq, los_sv = math.huge, nil
		for pid, pd in pairs(player_susp_data) do
			local dx = pd.px - ox
			local dy = pd.py - oy
			local dz = pd.pz - oz
			local dsq = dx*dx + dy*dy + dz*dz
			if dsq <= MAX_RADIUS_SQ then
				local c = oc[pid]
				local has_los
				if c and (now_t - c.t) < LOS_TTL then
					has_los = c.v
				else
					has_los = not G.raycast("ray", obs_pos, Vector3(pd.px, pd.py, pd.pz + 100))
					oc[pid] = { v = has_los, t = now_t }
				end
				if has_los and dsq < los_sq then los_sq = dsq; los_sv = pd.susp end
			end
		end

		return los_sv or best_sv
	end
end

function Fallback.prepare(cfg, pu, peer_susp_by_pid, now_t)
	local data = _build_player_susp_data(pu, peer_susp_by_pid)
	return {
		player_susp_data = data,
		obs_susp = _make_obs_susp(cfg, data, now_t),
	}
end

------------------------------------------------------------
-- Cam helpers
------------------------------------------------------------

local function _cam_level(base)
	local lvl = base and base._suspicion_sound_lvl
	if type(lvl) == "number" and lvl > 0 then return lvl end
	return nil
end

local function _cam_progress_from_level(level, observed_progress, single_camera_only)
	local bucket_lo = math.max(level - 1/6, 0)
	local midpoint  = math.max(level - 1/12, 1/12)
	if single_camera_only then
		if observed_progress and observed_progress >= bucket_lo then
			return math.clamp(observed_progress, 0, 1)
		end
		return midpoint
	end
	return observed_progress and math.clamp(observed_progress, bucket_lo, midpoint) or midpoint
end

function Fallback.count_curious_cams(cameras, status_by_key, is_alert_fn)
	local n = 0
	for _, camu in pairs(cameras or {}) do
		if alive(camu) and camu.base and camu:base() and _cam_level(camu:base()) then
			local status = status_by_key and status_by_key[camu:key()]
			if not is_alert_fn(status) then n = n + 1 end
		end
	end
	return n
end

------------------------------------------------------------
-- Per-observer fallback tick
------------------------------------------------------------

function Fallback.emit_player_records(R, cfg, pu, ctx, target_allowed)
	if cfg.target_other_players == false then return end
	for _, pd in pairs(ctx.player_susp_data) do
		local target = pd.unit
		local p = pd.susp
		if alive(target) and target ~= pu and p and p > 0.01 and target_allowed(target) then
			local show = true
			if U.is_player_mask_off(target, pu) then
				show = cfg.show_early_unmasked_suspicion == true
			end
			if show then
				R.put(target, p, "obj", DI.Phase.UNCOVER)
			end
		end
	end
end

function Fallback.tick_npc(R, observer_unit, cfg, ctx)
	local p = ctx.obs_susp(observer_unit)
	if not p or p <= 0.01 then return end
	R.put(observer_unit, p, "npc", DI.Phase.UNCOVER)
end

function Fallback.tick_cam(R, camu, cam_key, cfg, ctx, target_allowed, single_cam_only, pu)
	local b = camu:base()
	local lvl = _cam_level(b)

	-- Falling edge: cam was detecting, now isn't. Clear stale obs status so a
	-- later detection doesn't reuse cached alert level.
	local prev_lvl = D._cam_lvl_prev[cam_key]
	if prev_lvl and not lvl then
		D._client_obs_status[cam_key] = nil
	end
	D._cam_lvl_prev[cam_key] = lvl

	if not lvl then return end
	-- Fresh gate: only emit if this cam fired a susp net event after the last
	-- sync→fallback transition. Avoids showing pre-transition stale data.
	if (D._camera_susp_seen[cam_key] or 0) <= (D._camera_fb_min_seq or 0) then return end

	local p = _cam_progress_from_level(lvl, ctx.obs_susp(camu), single_cam_only)
	if not p or p <= 0.01 then return end
	local phase = DI.Phase.UNCOVER

	R.put(camu, p, "cam", phase)
	local m = camu.movement and camu:movement()
	local att = m and m.attention and m:attention()
	local target = att and att.unit
	if alive(target) and target ~= camu and target ~= pu and target_allowed(target) then
		if not (U.is_other_player(target, pu) and phase ~= DI.Phase.ALERTED) then
			R.put(target, p, "obj", phase, camu)
		end
	end
end
