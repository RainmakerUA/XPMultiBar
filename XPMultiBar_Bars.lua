--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_Bars.lua - module
		Bar displaying logic for XPMultiBar addon
--]=====]

local addonName = ...
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Bars = XPMultiBar:NewModule("Bars")

local B = Bars

local Utils

local unpack = unpack

-- Bar indices
B.XP = 1
B.REP = 2
B.AZ = 3

local bars = {
	X = B.XP,
	R = B.REP,
	A = B.AZ,
}

local all_x = "XXXX"
local all_r = "RRRR"
local xrxr = "XRXR"
local xxaa = "XXAA"
local xrxa = "XRXA"

local function makeStates(out, over, altover)
	return {
		out = out,
		over = over,
		altover = altover
	}
end

local barVisibiilty = {}

-- show XP @ max level
-- -- false
barVisibiilty[1] = {
	-- Show rep prio
	{ -- false
		-- show azerite
		-- false
		makeStates(xrxr, all_r, xrxr),
		-- true
		makeStates(xrxa, all_r, "XRAA")
	},
	{ -- true
		-- show azerite
		-- false
		makeStates(all_r, xrxr, all_r),
		-- true
		makeStates(all_r, xrxa, "RRAA")
	}
}
-- -- true
barVisibiilty[2] = {
	-- Show rep prio
	{ -- false
		-- show azerite
		-- false
		makeStates(all_x, all_r, all_x),
		-- true
		makeStates(all_x, all_r, xxaa)
	},
	{ -- true
		-- show azerite
		-- false
		makeStates(all_r, all_x, all_r),
		-- true
		makeStates(all_r, all_x, xxaa)
	}
}

local function boolToIndex(bool)
	return bool and 2 or 1
end

local function boolToZeroIndex(bool)
	return bool and 1 or 0
end

local function strind(str, index)
	return str:sub(index, index)
end

local currentBars = nil
local currentStateBar = nil

local currentState = nil

local visibleBar = nil
local mouseOverWithShift = nil

function B:OnInitialize()
	Utils = XPMultiBar:GetModule("Utils")
end

function B.UpdateBarSettings(showAtMaxLevel, showRepPrio, showAzerite)
	currentBars = barVisibiilty[boolToIndex(showAtMaxLevel)][boolToIndex(showRepPrio)][boolToIndex(showAzerite)]
	currentState = nil
end

function B.UpdateBarState(hasAzerite, isMaxLevel, isOver, isAlt, isShift)
	local isNewState

	if currentState then
		local oldHasAzerite, oldIsMaxLevel = unpack(currentState)
		isNewState = oldHasAzerite ~= hasAzerite or oldIsMaxLevel ~= isMaxLevel
	else
		isNewState = true
	end

	if isNewState or not currentStateBar then
		local index = boolToZeroIndex(hasAzerite) * 2 + boolToZeroIndex(isMaxLevel) + 1
		currentState = { hasAzerite, isMaxLevel }
		currentStateBar = Utils.Map(currentBars, function(v, k)
			return bars[strind(v, index)]
		end)
	end

	mouseOverWithShift = isOver and isShift

	if not isOver or mouseOverWithShift then
		visibleBar = currentStateBar.out
	elseif isAlt then
		visibleBar = currentStateBar.altover
	else
		visibleBar = currentStateBar.over
	end
end

function B.GetVisibleBar()
	return visibleBar
end
