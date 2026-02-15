--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMB_Master.lua - module
		Master (developer-only) module for XPMultiBar addon
--]=====]

local addonName = ...
local Utils = LibStub("rmUtils-1.0")
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName, true)
local Master = XPMultiBar:NewModule("Master")

local pairs = pairs
local print = print
local tconcat = table.concat
local tostring = tostring
local type = type

-- Remove all known globals after this point
-- luacheck: std none

function Master:OnInitialize()
end
