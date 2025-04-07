--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_ReputationApi.lua - module
		Legacy Reputation API façade module for XPMultiBar addon
--]=====]

local addonName = ...
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName)
local RepC = XPMultiBar:NewModule("ReputationCompat")

local GetFactionInfo = GetFactionInfo
local GetFactionInfoByID = GetFactionInfoByID
local GetWatchedFactionInfo = GetWatchedFactionInfo

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

--[[
	Backported functions (C_Reputation.xxx):
	- CollapseFactionHeader
	- ExpandFactionHeader
	- GetNumFactions
	- GetSelectedFaction
	- SetWatchedFactionByIndex
	- GetFactionDataByIndex
	- GetFactionDataByID
	- GetWatchedFactionData
]]

RepC.CollapseFactionHeader = CollapseFactionHeader
RepC.ExpandFactionHeader = ExpandFactionHeader
RepC.GetNumFactions = GetNumFactions
RepC.GetSelectedFaction = GetSelectedFaction
RepC.SetWatchedFactionByIndex = SetWatchedFactionIndex

function RepC.GetFactionDataByIndex(index)
	local name, description, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar,
		isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain = GetFactionInfo(index)
	if not name then return nil end
	return {
		factionID = factionID,
		name = name,
		description = description,
		reaction = standingID,
		currentReactionThreshold = barMin,
		nextReactionThreshold = barMax,
		currentStanding = barValue,
		atWarWith = atWarWith,
		canToggleAtWar = canToggleAtWar,
		isChild = isChild,
		isHeader = isHeader,
		isHeaderWithRep = hasRep,
		isCollapsed = isCollapsed,
		isWatched = isWatched,
		hasBonusRepGain = hasBonusRepGain,
		canSetInactive = false,
		isAccountWide = false,
	}
end

function RepC.GetFactionDataByID(id)
	local name, description, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar,
		isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain = GetFactionInfoByID(id)
	if not name then return nil end
	return {
		factionID = factionID,
		name = name,
		description = description,
		reaction = standingID,
		currentReactionThreshold = barMin,
		nextReactionThreshold = barMax,
		currentStanding = barValue,
		atWarWith = atWarWith,
		canToggleAtWar = canToggleAtWar,
		isChild = isChild,
		isHeader = isHeader,
		isHeaderWithRep = hasRep,
		isCollapsed = isCollapsed,
		isWatched = isWatched,
		hasBonusRepGain = hasBonusRepGain,
		canSetInactive = false,
		isAccountWide = false,
	}
end

function RepC.GetWatchedFactionData()
	local factionID = select(6, GetWatchedFactionInfo())
	if not factionID then return nil end
	return RepC.GetFactionDataByID(factionID)
end
