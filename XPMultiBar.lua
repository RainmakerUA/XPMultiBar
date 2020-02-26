--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar.lua - module
		Initialization module for XPMultiBar addon
--]=====]

local addonName, addonTable = ...
local XPMultiBar = LibStub("AceAddon-3.0"):NewAddon(addonName)
local Utils = LibStub("rmUtils-1.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local _G = _G
local pairs = pairs
local print = print

local GetAddOnMetadata = GetAddOnMetadata

-- Remove all known globals after this point
-- luacheck: std none

if addonTable.master then
	addonTable.master(XPMultiBar)
end

local function ShowStartupMessage(isClassicVersion)
	if Utils.IsWoWClassic == isClassicVersion then
		print(L["MESSAGE.WELCOME"])
	elseif isClassicVersion then
		print(L["ERROR.RETAIL_ON_CLASSIC"])
	else
		print(L["ERROR.CLASSIC_ON_RETAIL"])
	end
end

function XPMultiBar:OnInitialize()
	--@debug@
	_G["XPMultiBar"] = XPMultiBar

	for k, v in pairs(XPMultiBar.modules) do
		XPMultiBar[k] = v
	end
	--@end-debug@
	local version = GetAddOnMetadata(addonName, "Version") or ""
	local _, _, vernum, isClassic, vertype = version:find("^(%d+%.%d+%.%d+)(c?)-(%w+)$")
	XPMultiBar.Version = {
		Number = vernum or "test",
		Classic = isClassic and isClassic ~= "" or false,
		Type = vertype,
	}
end

function XPMultiBar:OnEnable()
	ShowStartupMessage(self.Version.Classic)
end
