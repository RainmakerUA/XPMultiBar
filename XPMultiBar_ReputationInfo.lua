--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_ReputationInfo.lua - module
		Reputation info module for XPMultiBar addon
--]=====]

local addonName = ...
local Utils = LibStub("rmUtils-1.1")
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName)
local RI = XPMultiBar:NewModule("ReputationInfo")

local wowClassic = Utils.IsWoWClassic
local emptyFun = Utils.EmptyFn

local ipairs = ipairs
local math_floor = math.floor
local setmetatable = setmetatable
local tonumber = tonumber
local tinsert = table.insert
local unpack = unpack

local RC = XPMultiBar:GetModule("ReputationCompat")

local CreateColor = CreateColor
local GetFactionInfo = GetFactionInfo or RC.GetFactionInfo
local GetFactionInfoByID = GetFactionInfoByID or RC.GetFactionInfoByID
local GetGuildInfo = GetGuildInfo
local GetNumFactions = GetNumFactions or RC.GetNumFactions
local GetText = GetText
local GetWatchedFactionInfo = GetWatchedFactionInfo or RC.GetWatchedFactionInfo
local SetWatchedFactionIndex = SetWatchedFactionIndex or RC.SetWatchedFactionIndex
local UnitSex = UnitSex

local BLUE_FONT_COLOR = BLUE_FONT_COLOR
local FACTION_ALLIANCE = FACTION_ALLIANCE
local FACTION_BAR_COLORS = FACTION_BAR_COLORS
local FACTION_HORDE = FACTION_HORDE
local GUILD = GUILD
local MAX_REPUTATION_REACTION = MAX_REPUTATION_REACTION or 8
local RENOWN_LEVEL_LABEL = RENOWN_LEVEL_LABEL
local REPUTATION_PROGRESS_FORMAT = REPUTATION_PROGRESS_FORMAT

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

local function UnpackIndices(table, ...)
	local tableToUnpack = {}
	local indices = {...}

	for _, index in ipairs(indices) do
		tinsert(tableToUnpack, table[index])
	end

	return unpack(tableToUnpack)
end

local function GetColorRGBA(color)
	return color.r or 0, color.g or 0, color.b or 0, color.a or 1
end

local function CreateColorMixin(color)
	return CreateColor(GetColorRGBA(color))
end

local reputationColors

-- Reputation colors are automatically generated and cached when first looked up
do
	reputationColors = setmetatable({}, {
		__index = function(t, k)
			local fbc = FACTION_BAR_COLORS[k]

			-- Wrap in mixin to use ColorMixin:WrapTextInColorCode(text)
			local colorMixin = CreateColorMixin(fbc)
			t[k] = colorMixin

			return colorMixin
		end,
	})
end

local renownColor = BLUE_FONT_COLOR
local friendColor = reputationColors[5]

-- Cache FACTION_STANDING_LABEL
-- When a lookup is first attempted on this cable, we go and lookup the real value and cache it
local factionStandingLabel

do
	factionStandingLabel = setmetatable({}, {
		__index = function(t, k)
			local fsl = GetText("FACTION_STANDING_LABEL" .. k, UnitSex("player"))
			t[k] = fsl
			return fsl
		end,
	})
end

local function GetFactionReputationInfo(factionID)
	local function getParagonRep(repData)
		local val, maxVal
		if IsFactionParagon(repData.id) then
			local parValue, parThresh, paragonQuestID, hasReward, tooLowLevelForParagon = GetFactionParagonInfo(factionID)
			local level = math_floor(parValue / parThresh)

			val = parValue % parThresh
			maxVal = parThresh
			hasReward = not tooLowLevelForParagon and hasReward

			if hasReward then
				val = val + parThresh
			end

			repData.paragon = {
				level = level,
				hasReward = hasReward,
				questID = paragonQuestID
			}
		else
			val = 1
			maxVal = 1
		end
		return val, maxVal
	end

	local name, desc, standing, minValue, maxValue, value,
			atWarWith, canToggleAtWar, isHeader,
			isCollapsed, hasRep, isWatched, isChild,
			_--[[factionID]], hasBonusRep, canSetInactive = GetFactionInfoByID(factionID)
	local standingText, standingColor

	if not name then
		-- Return nil for non-existent factions
		return nil
	end

	local rep = {
		id = factionID,
		name = name,
		description = desc,
		isAtWar = atWarWith,
		canBeAtWar = canToggleAtWar,
		isHeader = isHeader,
		isCollapsed = isCollapsed,
		hasRep = hasRep,
		isChild = isChild,
		isWatched = isWatched,
		hasBonusRep = hasBonusRep,
		canSetInactive = canSetInactive
	}

	local frienshipInfo = GetFriendshipReputation(factionID)

	if frienshipInfo and frienshipInfo.friendshipFactionID > 0 then
		if frienshipInfo.nextThreshold then
			maxValue = frienshipInfo.nextThreshold - frienshipInfo.reactionThreshold
			value = frienshipInfo.standing - frienshipInfo.reactionThreshold
		else
			maxValue = 1
			value = 1
		end

		local ranks = GetFriendshipReputationRanks(factionID)
		local level, maxLevel = ranks.currentLevel, ranks.maxLevel

		if level == maxLevel then
			local val, maxVal = getParagonRep(rep)

			if rep.paragon then
				value, maxValue = val, maxVal
			end
		end

		standingText = frienshipInfo.reaction
		standingColor = friendColor

		rep.friend = {
			level = level,
			maxLevel = maxLevel,
			text = frienshipInfo.reaction,
			description = frienshipInfo.text
		}
	elseif IsMajorFaction(factionID) then
		local renown = GetMajorFactionData(factionID)
		local level = renown.renownLevel
		local isCapped = HasMaximumRenown(factionID)

		if isCapped then
			local val, maxVal = getParagonRep(rep)

			if rep.paragon then
				value, maxValue = val, maxVal
			else
				value = renown.renownLevelThreshold
				maxValue = renown.renownLevelThreshold
			end
		else
			value = renown.renownReputationEarned or 0
			maxValue = renown.renownLevelThreshold
		end

		standingText = RENOWN_LEVEL_LABEL .. level
		standingColor = renownColor

		rep.renown = {
			isUnlocked = renown.isUnlocked,
			unlockDesc = renown.unlockDescription,
			level = level
		}
	else
		standingText = standing and factionStandingLabel[standing]
		standingColor = standing and reputationColors[standing]

		if not wowClassic and standing == MAX_REPUTATION_REACTION then
			value, maxValue = getParagonRep(rep)
		else
			maxValue = maxValue - minValue
			value = value - minValue
		end
	end

	return Utils.Override(rep, {
		standing = standing,
		standingText = standingText,
		standingColor = standingColor,
		-- minValue is always 0
		value = value,
		maxValue = maxValue,
	})
end

local function SetWatchedFactionByName(factionName, amount, autotrackGuild)
	if factionName == FACTION_HORDE or factionName == FACTION_ALLIANCE then
		-- Do not track Horde / Alliance classic faction header
		return
	end

	if tonumber(amount) <= 0 then
		-- We do not want to watch factions we are losing reputation with
		return
	end

	-- Fix for auto tracking guild reputation since the COMBAT_TEXT_UPDATE does not contain
	-- the guild name, it just contains "Guild"
	if factionName == GUILD then
		if autotrackGuild then
			factionName = GetGuildInfo("player")
		else
			return
		end
	end

	-- Everything ok? Watch the faction!
	for i = 1, GetNumFactions() do
		-- name, description, standingID, barMin, barMax, barValue, atWarWith,
		-- canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild,
		-- factionID, hasBonusRepGain, canBeLFGBonus = GetFactionInfo(factionIndex);
		local fi = { GetFactionInfo(i) }
		local name, isHeader, hasRep, isWatched = fi[1], fi[9], fi[11], fi[12]

		if name == factionName then
			-- If it is not watched and it is not a header without rep, watch it.
			if not isWatched and (not isHeader or hasRep) then
				SetWatchedFactionIndex(i)
			end
			return
		end
	end
end

function RI:GetFactionInfo(factionID)
	if factionID then
		return GetFactionReputationInfo(factionID)
	end

	local name, _, _, _, _, id = GetWatchedFactionInfo()

	if name then
		return GetFactionReputationInfo(id)
	end

	return nil
end

function RI:GetFactionInfoByIndex(index)
	local factionInfo = { GetFactionInfo(index) }
	local name, isHeader, isCollapsed, isChild, factionID = UnpackIndices(factionInfo, 1, 9, 10, 13, 14)

	return factionID and GetFactionReputationInfo(factionID) or {
		name = name,
		standing = 1,
		isHeader = isHeader,
		isCollapsed = isCollapsed,
		isChild = isChild
	}
end

-- Remove if default color is fine
function RI:SetExaltedColor(color)
	color.a = 1
	reputationColors[MAX_REPUTATION_REACTION] = CreateColorMixin(color)
end

function RI:SetWatchedFaction(factionName, amount, autotrackGuild)
	return SetWatchedFactionByName(factionName, amount, autotrackGuild)
end
