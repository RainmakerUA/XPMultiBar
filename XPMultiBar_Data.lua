--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_Data.lua - module
		Volatile data storage for XPMultiBar addon
--]=====]

local addonName = ...
local Utils = LibStub("rmUtils-1.0")
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Data = XPMultiBar:NewModule("Data")

local D = Data

local ipairs = ipairs
local type = type
local math_ceil = math.ceil

-- Remove all known globals after this point
-- luacheck: std none

local dataPrototype = {}

-- Table stores KTL data
dataPrototype.lastXPValues = {}
dataPrototype.sessionKills = 0

dataPrototype.data = {
	name = "", -- current name (artifact name / reputation faction)
	level = 0, -- current level (rep. standing)
	curr = 0, -- current XP on level
	max = 0, -- max XP on level
	rem = 0, -- remaining XP
	diff = 0, -- last XP increment
	extra = nil, -- extra data
}

function D:OnInitialize()
end

function dataPrototype:Get()
	return Utils.Clone(self.data)
end

function dataPrototype:GetKTL()
	if not self.tracking or #self.lastXPValues == 0 then
		return 0
	end

	local lastXP = 0

	for _, v in ipairs(self.lastXPValues) do
		lastXP = lastXP + v
	end

	if lastXP == 0 then
		return 0
	end

	local avgxp = lastXP / #self.lastXPValues

	return math_ceil(self.data.rem / avgxp)
end

function dataPrototype:Update(name, level, current, maximum, extra)
	if type(name) == "number" then
		name, level, current, maximum, extra = nil, name, level, current, maximum
	end

	local prevXP = self.data.curr or 0
	local prevName = self.data.name
	self.data.name = name
	self.data.level = level
	self.data.curr = current
	self.data.max = maximum
	self.data.rem = maximum - current
	self.data.diff = self.tracking and (not name or name == prevName) and (current - prevXP) or 0
	self.data.extra = extra

	if self.tracking and self.data.diff > 0 and prevXP > 0 then
		self.lastXPValues[(self.sessionKills % 10) + 1] = self.data.diff
		self.sessionKills = self.sessionKills + 1
	end
end

function D:New(name, tracking)
	local result = Utils.Clone(dataPrototype)
	if type(name) == "string" then
		result.data.name = name
		result.tracking = tracking and true or false
	else
		result.tracking = name and true or false
	end

	return result
end
