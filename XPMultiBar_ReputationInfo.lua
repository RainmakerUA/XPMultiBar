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

local math_floor = math.floor
local setmetatable = setmetatable
local tonumber = tonumber

local CreateColor = CreateColor
local GetFactionInfo = GetFactionInfo
local GetFactionInfoByID = GetFactionInfoByID
local GetGuildInfo = GetGuildInfo
local GetNumFactions = GetNumFactions
local GetWatchedFactionInfo = GetWatchedFactionInfo
local SetWatchedFactionIndex = SetWatchedFactionIndex

local _G = _G
local FACTION_ALLIANCE = FACTION_ALLIANCE
local FACTION_BAR_COLORS = FACTION_BAR_COLORS
local FACTION_HORDE = FACTION_HORDE
local GUILD = GUILD

local GetFactionParagonInfo = emptyFun
local IsFactionParagon = emptyFun
local GetFriendshipReputation = GetFriendshipReputation or emptyFun

if not wowClassic then
	GetFactionParagonInfo = C_Reputation.GetFactionParagonInfo
	IsFactionParagon = C_Reputation.IsFactionParagon
end

-- Remove all known globals after this point
-- luacheck: std none

local function GetColorRGBA(color)
	return color.r or 0, color.g or 0, color.b or 0, color.a or 1
end

local function CreateColorMixin(color)
	return CreateColor(GetColorRGBA(color))
end

-- Reputation colors
local STANDING_EXALTED = 8
local reputationColors

-- Reputation colors are automatically generated and cached when first looked up
do
	reputationColors = setmetatable({}, {
		__index = function(t, k)
			local fbc

			if k == STANDING_EXALTED then
				-- Exalted color is set separately
				-- Return default value if it is not set
				fbc = { r = 0, g = 0.77, b = 0.63 }
			else
				fbc = FACTION_BAR_COLORS[k]
			end

			-- Wrap in mixin to use ColorMixin:WrapTextInColorCode(text)
			local colorMixin = CreateColorMixin(fbc)
			t[k] = colorMixin

			return colorMixin
		end,
	})
end

-- Cache FACTION_STANDING_LABEL
-- When a lookup is first attempted on this cable, we go and lookup the real value and cache it
local factionStandingLabel

do
	factionStandingLabel = setmetatable({}, {
		__index = function(t, k)
			local fsl = _G["FACTION_STANDING_LABEL"..k]
			t[k] = fsl
			return fsl
		end,
	})
end

local function GetFactionReputationData(factionID)
	local repName, repDesc, repStanding, repMin, repMax, repValue,
			atWarWith, _--[[canToggleAtWar]], isHeader,
			isCollapsed, hasRep, isWatched, isChild,
			_--[[factionID]], hasBonusRep, canBeLFGBonus = GetFactionInfoByID(factionID)
	local isFactionParagon, hasParagonReward, paragonCount = false, false, 0
	local repStandingText, repStandingColor, isLFGBonus, paragonRewardQuestID

	if not repName then
		-- Return nil for non-existent factions
		return nil
	end

	local friendID, friendRep, friendMaxRep, _--[[friendName]], _, _,
				friendTextLevel, friendThresh, nextFriendThresh = GetFriendshipReputation(factionID)

	if friendID then
		if nextFriendThresh then
			-- Not yet "Exalted" with friend, use provided max for current level.
			repMax = nextFriendThresh
			repValue = friendRep - friendThresh
		else
			-- "Exalted". Fake the maxRep.
			repMax = friendMaxRep + 1
			repValue = 1
		end
		repMax = repMax - friendThresh
		repStandingText = friendTextLevel
	else
		repStandingText = repStanding and factionStandingLabel[repStanding]
		isFactionParagon = IsFactionParagon(factionID)
		-- Check faction with Exalted standing to have paragon reputation.
		-- If so, adjust values to show bar to next paragon bonus.
		if repStanding == STANDING_EXALTED and isFactionParagon then
			local parValue, parThresh, paragonQuestID, hasReward, tooLowLevelForParagon = GetFactionParagonInfo(factionID)
			paragonRewardQuestID = paragonQuestID
			hasParagonReward = not tooLowLevelForParagon and hasReward
			-- parValue is cumulative. We need to get modulo by the current threshold.
			repMax = parThresh
			paragonCount = math_floor(parValue / parThresh)
			repValue = parValue % parThresh
			-- if we have reward pending, show overflow
			if hasParagonReward then
				repValue = repValue + parThresh
			end
		else
			repMax = repMax - repMin
			repValue = repValue - repMin
		end
	end

	repMin = 0
	repStandingColor = repStanding and reputationColors[repStanding]
	isLFGBonus = false

	return factionID, repName, repStanding, repStandingText, repStandingColor,
			repMin, repMax, repValue, hasBonusRep, isLFGBonus,
			isFactionParagon, hasParagonReward, atWarWith,
			isHeader, hasRep, isCollapsed, isChild, isWatched, repDesc,
			paragonRewardQuestID, paragonCount
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

function RI:GetWatchedFactionData()
	local watchedFactionInfo = { GetWatchedFactionInfo() }
	if not watchedFactionInfo[1] then
		-- watched faction name == nil - watched faction not set
		return nil
	else
		return GetFactionReputationData(watchedFactionInfo[6])
	end
end

function RI:GetFactionData(factionID)
	if factionID then
		return GetFactionReputationData(factionID)
	end
	return nil
end

function RI:SetExaltedColor(color)
	color.a = 1
	reputationColors[STANDING_EXALTED] = CreateColorMixin(color)
end

function RI:SetWatchedFaction(factionName, amount, autotrackGuild)
	return SetWatchedFactionByName(factionName, amount, autotrackGuild)
end
