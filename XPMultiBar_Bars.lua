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

local tconcat = table.concat

-- Remove all known globals after this point
-- luacheck: std none

-- Bar consts
B.XP = 1
B.AZ = 2
B.REP = 3

local function makeKey(state)
	local function b2s(bool)
		return bool and "1" or "0"
	end
	return tconcat(Utils.Map(state, b2s))
end

local function makeStates(out, over, altover)
	return {
		out = out,
		over = over,
		altover = altover
	}
end

local barVisibility

do
	local X, A, R = B.XP, B.AZ, B.REP
	local XRX = makeStates(X, R, X)
	local XRA = makeStates(X, R, A)
	local RXR = makeStates(R, X, R)
	local ARX = makeStates(A, R, X)
	local RXA = makeStates(R, X, A)
	local RAX = makeStates(R, A, X)

	barVisibility = {
		-- showMaxLevelXP, showMaxLevelAzerite, showRepPriority, isMaxLevelXP, hasAzerite, isMaxLevelAzerite
		-- out, over, alt+over
		["000000"] = XRX,	["100000"] = XRX,
		["000001"] = nil,	["100001"] = nil,
		["000010"] = XRA,	["100010"] = XRA,
		["000011"] = XRA,	["100011"] = XRA,
		["000100"] = RXR,	["100100"] = XRX,
		["000101"] = nil,	["100101"] = nil,
		["000110"] = ARX,	["100110"] = XRA,
		["000111"] = RAX,	["100111"] = XRA,
		["001000"] = RXR,	["101000"] = RXR,
		["001001"] = nil,	["101001"] = nil,
		["001010"] = RXA,	["101010"] = RXA,
		["001011"] = RXA,	["101011"] = RXA,
		["001100"] = RXR,	["101100"] = RXR,
		["001101"] = nil,	["101101"] = nil,
		["001110"] = RAX,	["101110"] = RXA,
		["001111"] = RAX,	["101111"] = RXA,
		["010000"] = XRX,	["110000"] = XRX,
		["010001"] = nil,	["110001"] = nil,
		["010010"] = XRA,	["110010"] = XRA,
		["010011"] = XRA,	["110011"] = XRA,
		["010100"] = RXR,	["110100"] = XRX,
		["010101"] = nil,	["110101"] = nil,
		["010110"] = ARX,	["110110"] = XRA,
		["010111"] = ARX,	["110111"] = XRA,
		["011000"] = RXR,	["111000"] = RXR,
		["011001"] = nil,	["111001"] = nil,
		["011010"] = RXA,	["111010"] = RXA,
		["011011"] = RXA,	["111011"] = RXA,
		["011100"] = RXR,	["111100"] = RXR,
		["011101"] = nil,	["111101"] = nil,
		["011110"] = RAX,	["111110"] = RXA,
		["011111"] = RAX,	["111111"] = RXA,
	}
end

local currentState = {
	showMaxLevelXP = false,
	showMaxLevelAzerite = false,
	showRepPriority = false,
	isMaxLevelXP = false,
	hasAzerite = false,
	isMaxLevelAzerite = false,
}

local currentBars = nil

local visibleBar = nil
local mouseOverWithShift = nil

function B:OnInitialize()
end

function B.UpdateBarSettings(barSettings)
	currentState = Utils.Merge(barSettings, currentState)
	currentBars = barVisibility[makeKey(Utils.Values(currentState))]
end

function B.UpdateBarState(isOver, isAlt, isShift)
	mouseOverWithShift = isOver and isShift

	if not isOver or mouseOverWithShift then
		visibleBar = currentBars.out
	elseif isAlt then
		visibleBar = currentBars.altover
	else
		visibleBar = currentBars.over
	end
end

function B.GetVisibleBar()
	return visibleBar
end
