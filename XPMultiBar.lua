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
local GetLocale = GetLocale

local GetAddOnMetadata = GetAddOnMetadata or C_AddOns.GetAddOnMetadata

-- Remove all known globals after this point
-- luacheck: std none

local version
local isRuLocale

do
	version = GetAddOnMetadata(addonName, "Version") or ""

	local _, _, vernum, vertype = version:find("^(%d+%.%d+%.%d+)-(%w+)$")
	local metadata = {
		title = GetAddOnMetadata(addonName, "Title"),
		notes = GetAddOnMetadata(addonName, "Notes"),
		author = GetAddOnMetadata(addonName, "Author"),
		version = version,
		date = GetAddOnMetadata(addonName, "X-ReleaseDate"),
	}

	XPMultiBar.Metadata = metadata
	XPMultiBar.Version = {
		Number = vernum or "test",
		Type = vertype,
	}

	isRuLocale = GetLocale() == "ruRU"
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
end

function XPMultiBar:OnEnable()
	local config = XPMultiBar:GetModule("Config")
	local savedVars = config.db.sv

	if isRuLocale or savedVars.showStartupMessage then
		ShowStartupMessage()
	end
end
