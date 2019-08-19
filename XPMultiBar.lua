--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_Init.lua - module
		Initialization module for XPMultiBar addon
--]=====]

local addonName = ...
local XPMultiBar = LibStub("AceAddon-3.0"):NewAddon(addonName)

XPMultiBar.IsWoWClassic = select(4, GetBuildInfo()) < 20000

function XPMultiBar:OnInitialize()
	if self.IsWoWClassic then
		print(L["ERROR.RETAIL_ON_CLASSIC"])
	else
		print(L["MESSAGE.WELCOME"])
	end
	--@debug@
	_G["XPMultiBar"] = XPMultiBar

	for k, v in pairs(XPMultiBar.modules) do
		XPMultiBar[k] = v
	end
	--@end-debug@
end
