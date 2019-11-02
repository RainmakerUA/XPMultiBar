--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMB_Master.lua - module
		Master (developer-only) module for XPMultiBar addon
--]=====]

local addonName, addonTable = ...
local Utils = LibStub("rmUtils-1.0")
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName, true)

local pairs = pairs
local print = print
local tconcat = table.concat
local tostring = tostring
local type = type

-- Remove all known globals after this point
-- luacheck: std none

local Master = {}

if XPMultiBar then
	Master = XPMultiBar:NewModule("Master")
else
	function addonTable.master(xpmb)
		local master = Utils.Merge(xpmb:NewModule("Master"), Master)
		XPMultiBar = xpmb
		Master = master
	end
end

function Master:OnInitialize()
end
