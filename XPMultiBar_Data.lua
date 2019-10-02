--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_Data.lua - module
		Volatile data storage for XPMultiBar addon
--]=====]

local addonName = ...
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Data = XPMultiBar:NewModule("Data")

local D = Data

local ipairs = ipairs
local math_ceil = math.ceil

-- Remove all known globals after this point
-- luacheck: std none

local Utils

-- Table stores KTL data
local lastXPValues = {}
local sessionKills = 0

local xp = {
	curr = 0, -- current XP on level
	max = 0, -- max XP on level
	rem = 0, -- remaining XP
	diff = 0 -- last XP increment
}

function D:OnInitialize()
	Utils = XPMultiBar:GetModule("Utils")
end

function D.GetXP()
	return Utils.Clone(xp)
end

function D.GetKTL()
	if #lastXPValues == 0 then
		return 0
	end

	local lastXP = 0

	for _, v in ipairs(lastXPValues) do
		lastXP = lastXP + v
	end

	if lastXP == 0 then
		return 0
	end

	local avgxp = lastXP / #lastXPValues

	return math_ceil(xp.rem / avgxp)
end

function D.UpdateXP(current, maximum)
	local prevXP = xp.curr or 0
	xp.curr = current
	xp.max = maximum
	xp.rem = maximum - current
	xp.diff = current - prevXP

	if xp.diff > 0 and prevXP > 0 then
		lastXPValues[(sessionKills % 10) + 1] = xp.diff
		sessionKills = sessionKills + 1
	end
end
