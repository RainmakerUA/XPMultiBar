--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar.lua - module
		Initialization module for XPMultiBar addon
--]=====]

local addonName = ...
local XPMultiBar = LibStub("AceAddon-3.0"):NewAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local _G = _G
local pairs = pairs
local print = print

if WOW_PROJECT_ID and WOW_PROJECT_CLASSIC then
	XPMultiBar.IsWoWClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
else
	XPMultiBar.IsWoWClassic = select(4, GetBuildInfo()) < 20000
end

-- Remove all known globals after this point
-- luacheck: std none

function XPMultiBar:OnInitialize()
	--@debug@
	_G["XPMultiBar"] = XPMultiBar

	for k, v in pairs(XPMultiBar.modules) do
		XPMultiBar[k] = v
	end
	--@end-debug@
end

function XPMultiBar:OnEnable()
	if self.IsWoWClassic then
		print(L["ERROR.RETAIL_ON_CLASSIC"])
	else
		print(L["MESSAGE.WELCOME"])
	end
end
