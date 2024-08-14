--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar.lua - module
		Initialization module for XPMultiBar addon
--]=====]

local addonName, addonTable = ...
local XPMultiBar = LibStub("AceAddon-3.0"):NewAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local _G = _G
local pairs = pairs
local print = print
local GetLocale = GetLocale

local GetAddOnMetadata = GetAddOnMetadata or C_AddOns.GetAddOnMetadata

-- Remove all known globals after this point
-- luacheck: std none

local isRuLocale

if addonTable.master then
	addonTable.master(XPMultiBar)
end

local function ShowStartupMessage()
	print(L["MESSAGE.WELCOME"])
end

function XPMultiBar:OnInitialize()
	--@debug@
	_G["XPMultiBar"] = XPMultiBar

	for k, v in pairs(XPMultiBar.modules) do
		XPMultiBar[k] = v
	end
	--@end-debug@

    local version = GetAddOnMetadata(addonName, "Version") or ""
	local _, _, vernum, vertype = version:find("^(%d+%.%d+%.%d+)-(%w+)$")

    XPMultiBar.Version = {
		Number = vernum or "test",
		Type = vertype,
	}

    isRuLocale = GetLocale() == "ruRU"
end

function XPMultiBar:OnEnable()
	local config = XPMultiBar:GetModule("Config")
    local savedVars = config.db.sv

	if isRuLocale or savedVars.showStartupMessage then
		ShowStartupMessage()
	end
end
