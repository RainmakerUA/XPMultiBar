--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_ReputationApi.lua - module
		Reputation API façade module for XPMultiBar addon
--]=====]

local addonName = ...
local Utils = LibStub("rmUtils-1.1")
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName)
local RepC = XPMultiBar:NewModule("ReputationCompat")

local emptyFun = Utils.EmptyFn
local wowClassic = Utils.IsWoWClassic

local C_GossipInfo = C_GossipInfo
local C_MajorFactions = C_MajorFactions
local C_Reputation = C_Reputation

--[[
	-- FactionData structure
	{ Name = "factionID", Type = "number", Nilable = false },
	{ Name = "name", Type = "cstring", Nilable = false },
	{ Name = "description", Type = "cstring", Nilable = false },
	{ Name = "reaction", Type = "luaIndex", Nilable = false },
	{ Name = "currentReactionThreshold", Type = "number", Nilable = false },
	{ Name = "nextReactionThreshold", Type = "number", Nilable = false },
	{ Name = "currentStanding", Type = "number", Nilable = false },
	{ Name = "atWarWith", Type = "bool", Nilable = false },
	{ Name = "canToggleAtWar", Type = "bool", Nilable = false },
	{ Name = "isChild", Type = "bool", Nilable = false },
	{ Name = "isHeader", Type = "bool", Nilable = false },
	{ Name = "isHeaderWithRep", Type = "bool", Nilable = false },
	{ Name = "isCollapsed", Type = "bool", Nilable = false },
	{ Name = "isWatched", Type = "bool", Nilable = false },
	{ Name = "hasBonusRepGain", Type = "bool", Nilable = false },
	{ Name = "canSetInactive", Type = "bool", Nilable = false },
	{ Name = "isAccountWide", Type = "bool", Nilable = false },
]]

--[[
	name, description, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar,
	isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus 
]]

RepC.CollapseFactionHeader = C_Reputation.CollapseFactionHeader
RepC.ExpandFactionHeader = C_Reputation.ExpandFactionHeader
RepC.GetNumFactions = C_Reputation.GetNumFactions
RepC.GetSelectedFaction = C_Reputation.GetSelectedFaction
RepC.SetWatchedFactionIndex = C_Reputation.SetWatchedFactionByIndex

function RepC.GetFactionInfo(index)
	local data = C_Reputation.GetFactionDataByIndex(index)
	if not data then return nil end
	return data.name, data.description, data.reaction, data.currentReactionThreshold, data.nextReactionThreshold, data.currentStanding,
			data.atWarWith, data.canToggleAtWar, data.isHeader, data.isCollapsed, data.isHeaderWithRep, data.isWatched, data.isChild,
			data.factionID, data.hasBonusRepGain, data.canSetInactive
end

function RepC.GetFactionInfoByID(id)
	local data = C_Reputation.GetFactionDataByID(id)
	if not data then return nil end
	return data.name, data.description, data.reaction, data.currentReactionThreshold, data.nextReactionThreshold, data.currentStanding,
			data.atWarWith, data.canToggleAtWar, data.isHeader, data.isCollapsed, data.isHeaderWithRep, data.isWatched, data.isChild,
			data.factionID, data.hasBonusRepGain, data.canSetInactive
end

function RepC.GetWatchedFactionInfo()
	local data = C_Reputation.GetWatchedFactionData()
	if not data then return nil end
	return data.name, data.reaction, data.currentReactionThreshold, data.nextReactionThreshold, data.currentStanding, data.factionID
end
