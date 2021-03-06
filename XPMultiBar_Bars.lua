--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_Bars.lua - module
		Bar displaying logic for XPMultiBar addon
--]=====]

local addonName = ...
local Utils = LibStub("rmUtils-1.0")
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Bars = XPMultiBar:NewModule("Bars")

local B = Bars

-- Remove all known globals after this point
-- luacheck: std none

-- Bar consts
B.None = 0
B.XP = 1
B.AZ = 2
B.REP = 3

local currentSettings = {
	priority = {},
	isMaxLevelXP = false,
	hasAzerite = false,
	isMaxLevelAzerite = false,
}

local currentState = {
	isOver = false,
	isAlt = false,
	isShift = false,
}

local currentBars = nil
local visibleBar = nil
local mouseOverWithShift = nil

local function GetCurrentBars(state)
	--[[	1.	0 0 ?
			2.	0 1 ?
			2C.	1 0 ?
			3.	1 1 0
			4.	1 1 1
			5.  1 0 0 -- For 9.0.1 Prepatch
	]]
	local prio, maxLevelXP, hasAzerite, maxLevelAzer
			= state.priority, state.isMaxLevelXP, state.hasAzerite, state.isMaxLevelAzerite
	local index

	if not maxLevelXP and not hasAzerite then
		index = 1
	elseif not maxLevelXP then
		index = 2
	elseif not hasAzerite then
		index = 5
	elseif not maxLevelAzer then
		index = 3
	else
		index = 4
	end
	return Utils.SliceLength(prio, (index - 1) * 3 + 1, 3)
end

function B:OnInitialize()
end

function B.UpdateBarSettings(barSettings)
	Utils.Override(currentSettings, barSettings)
	currentBars = GetCurrentBars(currentSettings)
end

function B.UpdateBarState(isOver, isAlt, isShift)

	if isOver == nil then
		isOver, isAlt, isShift = currentState.isOver, currentState.isAlt, currentState.isShift
	end

	mouseOverWithShift = isOver and isShift

	Utils.Override(currentState, { isOver = false, isAlt = false, isShift = false, })

	if not isOver or mouseOverWithShift then
		visibleBar = currentBars[1]
	elseif isAlt then
		visibleBar = currentBars[3]
	else
		visibleBar = currentBars[2]
	end
end

function B.GetVisibleBar()
	return visibleBar
end
