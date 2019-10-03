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

-- Remove all known globals after this point
-- luacheck: std none

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
