--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_Data.lua - module
		Volatile data storage for XPMultiBar addon
--]=====]

local addonName = ...
local Utils = LibStub("rmUtils-1.1")
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
	level = nil, -- current level (rep. standing)
	curr = nil, -- current XP on level
	max = nil, -- max XP on level
	rem = nil, -- remaining XP
	diff = nil, -- last XP increment
	extra = nil, -- extra data
}

function D:OnInitialize()
end

function dataPrototype:Get()
	local data = {}
	if self.tracking then
		data.ktl = self:GetKTL()
	end
	return Utils.Merge(data, self.data)
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

	return self.data.rem and math_ceil(self.data.rem / avgxp) or 0
end

function dataPrototype:ClearKTL()
	self.lastXPValues = {}
	self.sessionKills = 0
end

function dataPrototype:Update(name, level, current, maximum, extra)
	if type(name) == "number" then
		name, level, current, maximum, extra = nil, name, level, current, maximum
	end

	local data = self.data

	local prevName = data.name
	local prevLevel = data.level
	local prevXP = data.curr
	local prevMax = data.max
	data.name = name
	data.level = level
	data.curr = current
	data.max = maximum
	data.rem = maximum and maximum - current or nil
	data.extra = extra

	if not prevName or prevName == name then
		local diff = prevXP and (current - prevXP) or nil
		if diff then
			-- if level up occured
			if level and level > prevLevel then
				diff = diff + prevMax
			end
			data.diff = diff
			if self.tracking and diff > 0 then
				self.sessionKills = self.sessionKills % 10 + 1
				self.lastXPValues[self.sessionKills] = diff
			end
		end
	else
		data.diff = nil
		if self.tracking then
			self:ClearKTL()
		end
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
