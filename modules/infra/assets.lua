if not DynamicSuspicionIndicatorsManager then return end
local DI = DynamicSuspicionIndicatorsManager
DI.Assets = DI.Assets or {}
local A = DI.Assets

A.font_hud = "fonts/font_medium_mf"

A.menu_singletick = "guis/textures/menu_singletick"
A.hud_icons       = "guis/textures/hud_icons"

local _MOD_TEXTURE_DIR = "assets/guis/textures/dp/"
local _MOD_TEXTURES = {
	"vanilla_curious",
	"vanilla_alert",
	"vhp_civilian_curious",
	"vhp_civilian_alerted",
	"vhp_guard_curious",
	"vhp_guard_alerted",
	"vhp_camera_curious",
	"vhp_camera_alerted",
	"extra_civilian_curious",
	"extra_civilian_alerted",
	"extra_guard_curious",
	"extra_guard_alerted",
	"extra_security_curious",
	"extra_security_alerted",
	"extra_murky_curious",
	"extra_murky_alerted",
	"extra_camera_curious",
	"extra_camera_alerted",
}

for _, name in ipairs(_MOD_TEXTURES) do
	A[name] = _MOD_TEXTURE_DIR .. name
end

local function _build_kind_textures(kind_fields, pair)
	return {
		civilian = pair(kind_fields.civilian),
		guard    = pair(kind_fields.guard),
		security = pair(kind_fields.security),
		murky    = pair(kind_fields.murky),
		camera   = pair(kind_fields.camera),
	}
end

local function _bundled_kind_textures(prefix, kind_fields)
	return _build_kind_textures(kind_fields, function(field)
		return {
			curious = A[prefix .. "_" .. field .. "_curious"],
			alerted = A[prefix .. "_" .. field .. "_alerted"],
		}
	end)
end

A.kind_textures = _bundled_kind_textures("vhp", {
	civilian = "civilian",
	guard    = "guard",
	security = "guard",
	murky    = "guard",
	camera   = "camera",
})

A.extra_kind_textures = _bundled_kind_textures("extra", {
	civilian = "civilian",
	guard    = "guard",
	security = "security",
	murky    = "murky",
	camera   = "camera",
})

function A:register_textures(mod_path)
	if self._textures_registered then return end
	if not (DB and DB.create_entry and Idstring) then
		DI.Logger.once("warn", "assets:texture-db-unavailable", "texture registration skipped: DB or Idstring unavailable")
		return
	end
	local ok, err = pcall(function()
		for _, name in ipairs(_MOD_TEXTURES) do
			local virt = _MOD_TEXTURE_DIR .. name
			local disk = mod_path .. _MOD_TEXTURE_DIR .. name .. ".texture"
			DB:create_entry(Idstring("texture"), Idstring(virt), disk)
		end
	end)
	if not ok then DI.Logger.warn("texture register failed: " .. tostring(err)) end
	self._textures_registered = true
end

A.vanilla_alert_rect = {
	texture = A.hud_icons,
	rect    = { 479, 433, 32, 32 },
}

local S = DI.SettingsSchema or DynamicSuspicionIndicatorsSettingsSchema

local _LIVE_TEXTURE_DIR = "assets/guis/textures/"
local _VHP_LIVE_TEXTURES = _build_kind_textures({
	civilian = "civilian",
	guard    = "guard",
	security = "guard",
	murky    = "guard",
	camera   = "camera",
}, function(kind)
	return {
		curious = _LIVE_TEXTURE_DIR .. kind .. "_curious",
		alerted = _LIVE_TEXTURE_DIR .. kind .. "_alerted",
	}
end)

local _KIND_TEXTURES_BY_STYLE = {
	[S.ICON_STYLES.EXTRA] = A.extra_kind_textures,
}

function A.kind_textures_for(icon_style)
	if icon_style == S.ICON_STYLES.VHP then
		-- prefer live VHP textures; fall back to DSI's bundled copies
		return (_G.VHUDPlus and _VHP_LIVE_TEXTURES) or A.kind_textures
	end
	return _KIND_TEXTURES_BY_STYLE[icon_style] or A.kind_textures
end

function A.uses_icons_mode(icon_style)
	return icon_style == S.ICON_STYLES.VHP or icon_style == S.ICON_STYLES.EXTRA
end

function A.preview_indicator_textures(icon_style, kind)
	if not A.uses_icons_mode(icon_style) then
		return {
			mode = "vanilla",
			curious = A.vanilla_curious,
			alerted = A.vanilla_alert,
		}
	end
	local kind_textures = A.kind_textures_for(icon_style)
	return (kind_textures and (kind_textures[kind or "guard"] or kind_textures.guard or kind_textures.civilian)) or A.kind_textures.guard
end
