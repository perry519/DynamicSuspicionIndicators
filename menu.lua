_G.DP = _G.DP or {}
_G.DynamicSuspicionIndicatorsManager = _G.DynamicSuspicionIndicatorsManager or {}

dofile("mods/DynamicSuspicionIndicators/modules/infra/logger.lua")
dofile("mods/DynamicSuspicionIndicators/modules/settings/schema.lua")
dofile("mods/DynamicSuspicionIndicators/modules/infra/assets.lua")
dofile("mods/DynamicSuspicionIndicators/modules/infra/game.lua")

DP.DEFAULT_SETTINGS = DynamicSuspicionIndicatorsSettingsSchema.DEFAULTS
DP.Menu = DP.Menu or {}

dofile("mods/DynamicSuspicionIndicators/modules/settings/lifecycle.lua")
DynamicSuspicionIndicatorsManager.Settings.load()
dofile("mods/DynamicSuspicionIndicators/modules/infra/color.lua")
dofile("mods/DynamicSuspicionIndicators/menu/color_preview/paint.lua")
dofile("mods/DynamicSuspicionIndicators/menu/color_preview/row.lua")
dofile("mods/DynamicSuspicionIndicators/menu/color_preview.lua")
dofile("mods/DynamicSuspicionIndicators/menu/localization.lua")
dofile("mods/DynamicSuspicionIndicators/menu/callbacks.lua")
dofile("mods/DynamicSuspicionIndicators/menu/builder.lua")
