--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_Init.lua - module
		Initialization module for XPMultiBar addon
--]=====]

local addonName = ...
local XPMultiBar = LibStub("AceAddon-3.0"):NewAddon(addonName)

function XPMultiBar:OnInitialize()
	--@debug@
	_G["XPMultiBar"] = XPMultiBar

	for k, v in pairs(XPMultiBar.modules) do
		XPMultiBar[k] = v
	end
	--@end-debug@
end
