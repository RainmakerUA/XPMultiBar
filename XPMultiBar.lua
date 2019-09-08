--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar.lua - module
		Initialization module for XPMultiBar addon
--]=====]

local addonName = ...
local XPMultiBar = LibStub("AceAddon-3.0"):NewAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

if WOW_PROJECT_ID and WOW_PROJECT_CLASSIC then
	XPMultiBar.IsWoWClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
else
	XPMultiBar.IsWoWClassic = select(4, GetBuildInfo()) < 20000
end

XPMultiBar.EmptyFun = function() end

function XPMultiBar:OnInitialize()
	--@debug@
	_G["XPMultiBar"] = XPMultiBar

	for k, v in pairs(XPMultiBar.modules) do
		XPMultiBar[k] = v
	end
	--@end-debug@
end

function XPMultiBar:OnEnable()
	if not self.IsWoWClassic then
		print(L["ERROR.CLASSIC_ON_RETAIL"])
	else
		print(L["MESSAGE.WELCOME"])
	end
end
