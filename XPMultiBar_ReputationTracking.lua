--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_ReputationTracking.lua - module
		Reputation tracking module for XPMultiBar addon
--]=====]

local addonName = ...
local Utils = LibStub("rmUtils-1.1")
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Mod = XPMultiBar:NewModule("ReputationTracking")

local RC = XPMultiBar:GetModule("ReputationCompat")

local pairs = pairs
local math_floor = math.floor

local wowClassic = Utils.IsWoWClassic
local emptyFun = Utils.EmptyFn

local MAX_REPUTATION_REACTION = MAX_REPUTATION_REACTION or 8

local GetFactionDataByID = C_Reputation.GetFactionDataByID or RC.GetFactionDataByID
local IsFactionParagon = emptyFun
local GetFactionParagonInfo = emptyFun
local GetFriendshipReputation = emptyFun
local GetFriendshipReputationRanks = emptyFun
local IsMajorFaction = emptyFun
local GetMajorFactionData = emptyFun
local HasMaximumRenown = emptyFun

if not wowClassic then
	IsFactionParagon = C_Reputation.IsFactionParagon
	GetFactionParagonInfo = C_Reputation.GetFactionParagonInfo
	GetFriendshipReputation = C_GossipInfo.GetFriendshipReputation
	GetFriendshipReputationRanks = C_GossipInfo.GetFriendshipReputationRanks
	IsMajorFaction = C_Reputation.IsMajorFaction
	GetMajorFactionData = C_MajorFactions.GetMajorFactionData
	HasMaximumRenown = C_MajorFactions.HasMaximumRenown
end

-- Remove all known globals after this point
-- luacheck: std none

local factionData = {}

local function getParagonRep(id)
	if IsFactionParagon(id) then
		local parValue, parThresh = GetFactionParagonInfo(id)
		local level = math_floor(parValue / parThresh)
		local value = parValue % parThresh
		return { id = id, level = level, value = value }
	end
	return nil
end

local function getFactionInfo(id)
	local data = id and GetFactionDataByID(id) or nil
	if not data or data.isHeader and not data.isHeaderWithRep then
		return nil
	end

	local name = data.name or "Unknown"
	local frienshipInfo = GetFriendshipReputation(id)

	if frienshipInfo and frienshipInfo.friendshipFactionID > 0 then
		local ranks = GetFriendshipReputationRanks(id)
		local level, maxLevel = ranks.currentLevel, ranks.maxLevel
		if level == maxLevel then
			local paragonData = getParagonRep(id)
			if paragonData then
				return Utils.Merge({ name = name }, paragonData)
			end
		end
		return { id = id, name = name, level = level, value = frienshipInfo.standing - frienshipInfo.reactionThreshold }
	end

	if IsMajorFaction(id) then
		local renown = GetMajorFactionData(id)
		if renown then
			local level = renown.renownLevel
			local isCapped = HasMaximumRenown(id)
			if isCapped then
				local paragonData = getParagonRep(id)
				if paragonData then
					return Utils.Merge({ name = name }, paragonData)
				end
			end
			return { id = id, name = name, level = level, value = renown.renownReputationEarned or 0 }
		end
	end

	if not wowClassic and data.reaction == MAX_REPUTATION_REACTION then
		local paragonData = getParagonRep(id)
		if paragonData then
			return Utils.Merge({ name = name }, paragonData)
		end
	end

	return {
		id = id,
		name = name,
		level = data.reaction,
		value = data.currentStanding - data.currentReactionThreshold,
	}
end

function Mod:GetChangedFactionData()
	for id, rep in pairs(factionData) do
		local newRep = getFactionInfo(id)
		if newRep and (newRep.level > rep.level or newRep.value > rep.value) then
			factionData[id] = newRep
			return newRep
		end
	end
	return nil
end

function Mod:GetFactionIDByName(name)
	for id, rep in pairs(factionData) do
		if rep.name == name then
			return id
		end
	end
	return nil
end

function Mod:OnInitialize()
	--@debug@
	local startTime = debugprofilestop()
	--@end-debug@
	local count = 0

	for i = 1, 5000, 1 do
		local info = getFactionInfo(i)
		if info then
			count = count + 1
			factionData[i] = info
		end
	end

	--@debug@
	local elapsed = debugprofilestop() - startTime
	print(("ReputationTracking: Loaded %d factions' data in %.2f ms."):format(count, elapsed))
	_G.XPMB_FD = factionData
	--@end-debug@
end
