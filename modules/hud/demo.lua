-- Demo / screenshot HUD preview rendering.

if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.HudDemo = DI.HudDemo or {}
local D = DI.HudDemo
local H = DI.HudItem
local A = DI.Assets
local Glyph = DI.HudGlyph
local alive = DI.Game.alive

D._vanilla = D._vanilla or {}
D._vhp     = D._vhp     or {}
D._extra   = D._extra   or {}

local _DEMO_SPECS_VANILLA = {
	{ progress = 0.23, kind = "civilian" },
	{ progress = 0.56, kind = "guard"    },
	{ progress = 0.89, kind = "camera"   },
	{ progress = 1.0,  kind = "civilian", alerted = true },
}
local _DEMO_SPECS_VHP = {
	{ progress = 0.14, kind = "civilian" },
	{ progress = 0.47, kind = "guard"    },
	{ progress = 0.81, kind = "camera"   },
	{ progress = 1.0,  kind = "civilian", alerted = true },
}
local _DEMO_SPECS_EXTRA = {
	{ progress = 0.31, kind = "civilian" },
	{ progress = 0.62, kind = "security" },
	{ progress = 0.74, kind = "camera"   },
	{ progress = 1.0,  kind = "guard",    alerted = true },
}

local _DEMO_SZ  = 26
local _DEMO_TSZ = 11

local function _demo_texts(pnl, sz)
	local shadow = pnl:text({
		text = "0%", font = A.font_hud, font_size = _DEMO_TSZ,
		color = Color.black:with_alpha(0.7),
		x = 1, y = sz + 3, w = sz, align = "center", layer = 1,
	})
	local txt = pnl:text({
		text = "0%", font = A.font_hud, font_size = _DEMO_TSZ,
		color = Color.white, x = 0, y = sz + 2, w = sz, align = "center", layer = 3,
	})
	return txt, shadow
end

local function _build_demo_vanilla()
	local sz = _DEMO_SZ
	local pnl    = H._panel:panel({ w = sz, h = sz + _DEMO_TSZ + 6 })
	local hollow = pnl:bitmap({ texture = A.vanilla_curious, w = sz, h = sz, x = 0, y = 0, color = DI.Color.CURIOUS:with_alpha(0.7), layer = 1 })
	local clip   = pnl:panel({ w = sz, h = sz, x = 0, y = 0, layer = 2 })
	local eye    = clip:bitmap({ texture = A.vanilla_curious, w = sz, h = sz, x = 0, y = 0, color = Color.white, layer = 1 })
	local txt, shadow = _demo_texts(pnl, sz)
	return { panel = pnl, hollow = hollow, clip = clip, eye = eye, txt = txt, shadow = shadow }
end

local function _build_demo_vanilla_alert()
	local sz = _DEMO_SZ
	local pnl  = H._panel:panel({ w = sz, h = sz + _DEMO_TSZ + 6 })
	local icon = pnl:bitmap({
		texture = A.vanilla_alert,
		w = sz, h = sz, x = 0, y = 0,
		color = DI.Color.ALERTED, layer = 1,
	})
	local txt, shadow = _demo_texts(pnl, sz)
	return { panel = pnl, icon = icon, txt = txt, shadow = shadow, _is_alert = true }
end

local function _build_demo_icon(kind, kind_textures, alerted)
	local kt = kind_textures and (kind_textures[kind] or kind_textures.civilian)
	local sz = _DEMO_SZ
	local pnl    = H._panel:panel({ w = sz, h = sz + _DEMO_TSZ + 6 })
	local hollow = pnl:bitmap({ texture = kt.curious, w = sz, h = sz, x = 0, y = 0, color = DI.Color.CURIOUS:with_alpha(alerted and 0 or 0.85), layer = 1 })
	local clip   = pnl:panel({ w = sz, h = sz, x = 0, y = 0, layer = 2 })
	local tex    = alerted and kt.alerted or kt.curious
	local color  = alerted and DI.Color.ALERTED or Color.white
	local filled = clip:bitmap({ texture = tex, w = sz, h = sz, x = 0, y = 0, color = color, layer = 1 })
	local txt, shadow = _demo_texts(pnl, sz)
	return { panel = pnl, hollow = hollow, clip = clip, filled = filled, txt = txt, shadow = shadow, _is_alert = alerted and true or nil }
end

local function _build_demo_vhp(kind)
	return _build_demo_icon(kind, A.kind_textures, false)
end

local function _build_demo_vhp_alert(kind)
	return _build_demo_icon(kind, A.kind_textures, true)
end

local function _build_demo_extra(kind)
	return _build_demo_icon(kind, A.extra_kind_textures, false)
end

local function _build_demo_extra_alert(kind)
	return _build_demo_icon(kind, A.extra_kind_textures, true)
end

function D.destroy()
	local function _purge(tbl)
		if H._panel and alive(H._panel) then
			for _, item in ipairs(tbl) do
				if item and alive(item.panel) then H._panel:remove(item.panel) end
			end
		end
		for k in pairs(tbl) do tbl[k] = nil end
	end
	_purge(D._vanilla)
	_purge(D._vhp)
	_purge(D._extra)
end

local function _ensure_slot(tbl, i, alerted, build)
	local item = tbl[i]
	if item and alive(item.panel) and (item._is_alert ~= (alerted == true)) then
		H._panel:remove(item.panel)
		item = nil
	end
	if not (item and alive(item.panel)) then
		item = build()
		tbl[i] = item
	end
	return item
end

local function _paint_text(item, pct, color)
	Glyph.paint_text_pair(item.txt, item.shadow, true, pct, color)
end

local function _place(item, x, y)
	item.panel:set_visible(true)
	item.panel:set_center(x, y)
	item.panel:set_alpha(1)
end

local function _paint_vanilla(item, progress, pct, color, alerted)
	if not alerted then
		local fp = math.clamp(progress, 0, 1)
		Glyph.render_clipped_fill(item.clip, item.eye, _DEMO_SZ, 0, fp, color)
		item.hollow:set_color(DI.Color.CURIOUS:with_alpha(math.max(0.45, 1 - fp * 0.5)))
	end
	_paint_text(item, pct, color)
end

local function _paint_icon(item, progress, pct, color, alerted)
	Glyph.render_clipped_fill(item.clip, item.filled, _DEMO_SZ, 0, alerted and 1 or progress, color)
	if not alerted then
		item.hollow:set_color(DI.Color.CURIOUS)
		item.hollow:set_alpha(0.85)
	end
	_paint_text(item, pct, color)
end

function D.place(cfg)
	if not (H._panel and alive(H._panel)) then return end
	local hud_p   = H._panel:parent()
	local pw, ph  = hud_p:w(), hud_p:h()
	local cx, cy  = pw * 0.5, ph * 0.5
	local n       = #_DEMO_SPECS_VANILLA
	local spacing = 50
	local row_h   = _DEMO_SZ + _DEMO_TSZ + 6
	local gap     = 12
	local row1_cy = cy - (row_h + gap)
	local row2_cy = cy
	local row3_cy = cy + (row_h + gap)

	local xs = {}
	local half = (n - 1) * 0.5
	for i = 1, n do xs[i] = cx + (i - 1 - half) * spacing end

	for i = 1, n do
		local vs      = _DEMO_SPECS_VANILLA[i]
		local hs      = _DEMO_SPECS_VHP[i]
		local cs      = _DEMO_SPECS_EXTRA[i]
		local alerted = vs.alerted

		local vp      = vs.progress
		local v_color = alerted and DI.Color.ALERTED or DI.HudView.fill_color("uncover", vp)
		local v_pct   = alerted and "!" or DI.HudView.pct_str("uncover", vp)
		local vi      = _ensure_slot(D._vanilla, i, alerted, function()
			return alerted and _build_demo_vanilla_alert() or _build_demo_vanilla()
		end)
		_paint_vanilla(vi, vp, v_pct, v_color, alerted)
		_place(vi, xs[i], row1_cy)

		local hp      = hs.progress
		local h_color = alerted and DI.Color.ALERTED or DI.HudView.fill_color("uncover", hp)
		local h_pct   = alerted and "!" or DI.HudView.pct_str("uncover", hp)
		local hi      = _ensure_slot(D._vhp, i, alerted, function()
			return alerted and _build_demo_vhp_alert(hs.kind) or _build_demo_vhp(hs.kind)
		end)
		_paint_icon(hi, hp, h_pct, h_color, alerted)
		_place(hi, xs[i], row2_cy)

		local cp      = cs.progress
		local c_color = alerted and DI.Color.ALERTED or DI.HudView.fill_color("uncover", cp)
		local c_pct   = alerted and "!" or DI.HudView.pct_str("uncover", cp)
		local ci      = _ensure_slot(D._extra, i, alerted, function()
			return alerted and _build_demo_extra_alert(cs.kind) or _build_demo_extra(cs.kind)
		end)
		_paint_icon(ci, cp, c_pct, c_color, alerted)
		_place(ci, xs[i], row3_cy)
	end
end

function H.destroy_demo()
	D.destroy()
end

function H.place_demo(cfg)
	D.place(cfg)
end
