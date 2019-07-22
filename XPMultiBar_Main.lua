--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar.lua - module
		Main module for XPMultiBar addon
--]=====]

local addonName = ...
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Main = XPMultiBar:NewModule("Main", "AceEvent-3.0")

local M = Main

-- Libs
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local LSM3 = LibStub("LibSharedMedia-3.0")

-- Lua
local select = select
local tostring = tostring
local type = type

-- Math
local math_ceil = math.ceil
local math_min = math.min

-- WoW globals
local ChatEdit_GetActiveWindow = ChatEdit_GetActiveWindow
local ChatEdit_GetLastActiveWindow = ChatEdit_GetLastActiveWindow
local CollapseFactionHeader = CollapseFactionHeader
local CreateFrame = CreateFrame
local ExpandFactionHeader = ExpandFactionHeader
local GameFontNormal = GameFontNormal
local GetContainerItemInfo = GetContainerItemInfo
local GetCurrentCombatTextEventInfo = GetCurrentCombatTextEventInfo
local GetCursorPosition = GetCursorPosition
local GetFactionInfo = GetFactionInfo
local GetFactionInfoByID = GetFactionInfoByID
local GetFriendshipReputation = GetFriendshipReputation
local GetGuildInfo = GetGuildInfo
local GetInventoryItemID = GetInventoryItemID
local GetItemInfo = GetItemInfo
local GetMouseButtonClicked = GetMouseButtonClicked
local GetNumFactions = GetNumFactions
local GetWatchedFactionInfo = GetWatchedFactionInfo
local GetXPExhaustion = GetXPExhaustion
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsPlayerAtEffectiveMaxLevel = IsPlayerAtEffectiveMaxLevel
local IsResting = IsResting
local IsShiftKeyDown = IsShiftKeyDown
local IsXPUserDisabled = IsXPUserDisabled
local SetWatchedFactionIndex = SetWatchedFactionIndex
local StatusTrackingBarManager = StatusTrackingBarManager
local UIParent = UIParent
local UnitLevel = UnitLevel
local UnitXP = UnitXP
local UnitXPMax = UnitXPMax
local FindActiveAzeriteItem = C_AzeriteItem.FindActiveAzeriteItem
local GetAzeriteItemXPInfo = C_AzeriteItem.GetAzeriteItemXPInfo
local GetAzeritePowerLevel = C_AzeriteItem.GetPowerLevel
local HasActiveAzeriteItem = C_AzeriteItem.HasActiveAzeriteItem
local IsAzeriteItemAtMaxLevel = C_AzeriteItem.IsAzeriteItemAtMaxLevel
local GetFactionParagonInfo = C_Reputation.GetFactionParagonInfo
local IsFactionParagon = C_Reputation.IsFactionParagon

local FACTION_ALLIANCE = FACTION_ALLIANCE
local FACTION_BAR_COLORS = FACTION_BAR_COLORS
local FACTION_HORDE = FACTION_HORDE
local GUILD = GUILD

-- Modules late init
local Bars
local Config
local Data
local Utils

local function commify(num)
	local db = Config.GetDB()
	return db.general.commify and Utils.Commify(num) or tostring(num)
end

local function getPlayerXP()
	if GameLimitedMode_IsActive() then
		local rLevel = GetRestrictedAccountData();
		if UnitLevel("player") >= rLevel then
			return UnitTrialXP("player");
		end
	end

	return UnitXP("player")
end

local function GetXPText(cXP, nXP, remXP, restedXP, level, maxLevel)
	local nextLevel = level == maxLevel and level or (level + 1)
	local ktl = Data.GetKTL()
	local db = Config.GetDB()

	return Utils.MultiReplace(
		db.bars.xpstring,
		{
			["%[curXP%]"] = commify(cXP),
			["%[maxXP%]"] = commify(nXP),
			["%[restXP%]"] = commify(restedXP),
			["%[restPC%]"] = Utils.FormatPercents(restedXP, nXP),
			["%[curPC%]"] = Utils.FormatPercents(cXP, nXP),
			["%[needPC%]"] = Utils.FormatRemainingPercents(cXP, nXP),
			["%[pLVL%]"] = level,
			["%[nLVL%]"] = nextLevel,
			["%[mLVL%]"] = maxLevel,
			["%[needXP%]"] = commify(remXP),
			["%[KTL%]"] = ktl > 0 and commify(ktl) or "?",
			["%[BTL%]"] = ("%d"):format(math_ceil(20 - ((cXP / nXP * 100) / 5)))
		}
	)
end

local function GetAzerText(name, currAP, maxAP, level)
	local db = Config.GetDB()
	return Utils.MultiReplace(
		db.bars.azerstr,
		{
			["%[name%]"] = name,
			["%[curXP%]"] = commify(currAP),
			["%[maxXP%]"] = commify(maxAP),
			["%[curPC%]"] = Utils.FormatPercents(currAP, maxAP),
			["%[needPC%]"] = Utils.FormatRemainingPercents(currAP, maxAP),
			["%[pLVL%]"] = level,
			["%[nLVL%]"] = level + 1,
			["%[needXP%]"] = commify(maxAP - currAP)
		}
	)
end

local function GetAzeriteItemName(item)
	local name = nil
	if item then
		local itemID
		if item:IsBagAndSlot() then
			itemID = select(10, GetContainerItemInfo(item:GetBagAndSlot()))
		else
			itemID = GetInventoryItemID("player", item:GetEquipmentSlot())
		end
		-- HACK: When first entering world, script gets itemID = nil|0
		-- Just hardcode Heart of Azeroth ID in this case
		if not itemID or itemID == 0 then
			itemID = 158075 --Heart of Azeroth ID = 158075
		end
		-- Also name is not retrieved in this case
		name = GetItemInfo(itemID)
	end
	return name or L["Heart of Azeroth"]
end

local function SetWatchedFactionByName(faction)
	for i = 1, GetNumFactions() do
		-- name, description, standingID, barMin, barMax, barValue, atWarWith,
		-- canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild,
		-- factionID, hasBonusRepGain, canBeLFGBonus = GetFactionInfo(factionIndex);
		local fi = { GetFactionInfo(i) }
		local name, isHeader, isWatched = fi[1], fi[9], fi[12]

		if name == faction then
			-- If it is not watched and it is not a header watch it.
			if not isWatched then
				SetWatchedFactionIndex(i)
			end
			return
		end
	end
end

local function GetReputationText(repInfo)
	local repName, repStanding, repMin, repMax, repValue, friendID, friendTextLevel,
			hasBonusRep, canBeLFGBonus, isFactionParagon = unpack(repInfo)
	local standingText
	if friendID then
		standingText = friendTextLevel
	else
		standingText = Config.GetFactionStandingLabel(repStanding)
	end

	local db = Config.GetDB()

	return Utils.MultiReplace(
		db.bars.repstring,
		{
			["%[faction%]"] = repName,
			["%[standing%]"] = standingText,
			["%[curRep%]"] = commify(repValue),
			["%[maxRep%]"] = commify(repMax),
			["%[repPC%]"] = Utils.FormatPercents(repValue, repMax),
			["%[needRep%]"] = commify(repMax - repValue),
			["%[needPC%]"] = Utils.FormatRemainingPercents(repValue, repMax),
		}
	)
end

function M:OnInitialize()
	Bars = XPMultiBar:GetModule("Bars")
	Config = XPMultiBar:GetModule("Config")
	Data = XPMultiBar:GetModule("Data")
	Utils = XPMultiBar:GetModule("Utils")
	UI = XPMultiBar:GetModule("UI")

	UI:Disable()

	Utils.ForEach(
		{
			["BantoBar"] = "Interface\\AddOns\\XPMultiBar\\Textures\\bantobar",
			["Charcoal"] = "Interface\\AddOns\\XPMultiBar\\Textures\\charcoal",
			["Glaze"] = "Interface\\AddOns\\XPMultiBar\\Textures\\glaze",
			["LiteStep"] = "Interface\\AddOns\\XPMultiBar\\Textures\\litestep",
			["Marble"] = "Interface\\AddOns\\XPMultiBar\\Textures\\marble",
			["Otravi"] = "Interface\\AddOns\\XPMultiBar\\Textures\\otravi",
			["Perl"] = "Interface\\AddOns\\XPMultiBar\\Textures\\perl",
			["Smooth"] = "Interface\\AddOns\\XPMultiBar\\Textures\\smooth",
			["Smooth v2"] = "Interface\\AddOns\\XPMultiBar\\Textures\\smoothv2",
			["Striped"] = "Interface\\AddOns\\XPMultiBar\\Textures\\striped",
			["Waves"] = "Interface\\AddOns\\XPMultiBar\\Textures\\waves"
		},
		function(path, name)
			LSM3:Register("statusbar", name, path)
		end
	)

	local uiHandler = function(methodName, updateBar)
		return { UI[methodName], updateBar, ["self"] = UI }
	end

	local setFontOptions = function(main)
		return main:SetFontOptions()
	end

	local onBarSettingsUpdated = {
		function(localSelf, value)
			localSelf:UpdateBarSettings()
			localSelf:SetBars(false)
		end,
		true
	}

	local onDisplayIconsUpdated = uiHandler("HideIcons", true)

	local eventMap = {
		_self = self,
		locked = uiHandler("SetLocked"),
		clamptoscreen = uiHandler("SetClamp"),
		strata = uiHandler("SetStrata"),
		bgColor = uiHandler("SetBackgroundColor", true),
		width = uiHandler("SetWidth", true),
		height = uiHandler("SetHeight", true),
		scale = uiHandler("SetScale"),
		font = setFontOptions,
		fontsize = setFontOptions,
		fontoutline = setFontOptions,
		texture = self.SetTexture,
		horizTile = self.SetTexture,
		bubbles = uiHandler("ShowBubbles"),
		border = uiHandler("ShowBorder"),
		hidestatus = uiHandler("SetStatusTrackingBarHidden"),
		autowatchrep = function(localSelf, value)
			if value then
				localSelf:RegisterEvent("COMBAT_TEXT_UPDATE")
			else
				localSelf:UnregisterEvent("COMBAT_TEXT_UPDATE")
			end
		end,
		xpicons = onDisplayIconsUpdated,
		azicons = onDisplayIconsUpdated,
		repicons = onDisplayIconsUpdated,
		showmaxlevel = onBarSettingsUpdated,
		showrepbar = onBarSettingsUpdated,
		showmaxazerite = onBarSettingsUpdated,
	}

	Config.RegisterConfigChanged(
		function(key, value)
			local handler = eventMap[key]
			local receiver = eventMap._self
			local updateBar = false
			if handler then
				if type(handler) == "table" then
					updateBar = handler[2] or handler["update"]
					receiver = handler["self"] or handler["receiver"] or receiver
					handler = handler[1]
				end
				if type(handler) ~= "function" then
					handler = eventMap._self[handler]
				end
				handler(receiver, value)
			else
				updateBar = true
			end
			if updateBar then
				eventMap._self:UpdateXPBar()
			end
		end
	)

	Config.RegisterProfileChanged(self.OnProfileChanged, self)

	UI:RegisterBarEventHandler(self.OnBarEvent, self)
end

function M:OnEnable()
	local db = Config.GetDB()

	self:OnProfileChanged(db, true)

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateXPBar")
	self:RegisterEvent("PLAYER_XP_UPDATE", "UpdateXPData")
	self:RegisterEvent("PLAYER_LEVEL_UP", "LevelUp")
	self:RegisterEvent("PLAYER_UPDATE_RESTING", "UpdateXPData")
	self:RegisterEvent("UPDATE_EXHAUSTION", "UpdateXPBar")
	self:RegisterEvent("UPDATE_FACTION", "UpdateXPBar")
	self:RegisterEvent("AZERITE_ITEM_EXPERIENCE_CHANGED", "UpdateXPBar")

	if db.bars.autowatchrep then
		self:RegisterEvent("COMBAT_TEXT_UPDATE")
	end

	self:RegisterEvent("PET_BATTLE_OPENING_START")
	self:RegisterEvent("PET_BATTLE_CLOSE")

	-- Register some LSM3 callbacks
	LSM3.RegisterCallback(self, "LibSharedMedia_SetGlobal", function(callback, mtype, override)
		if mtype == "statusbar" and override ~= nil then
			self:SetTexture(override)
		end
	end)

	-- Show the bar
	UI:EnableEx(db.general.hidestatus)

	-- Update bars
	self:UpdateBarSettings(db.bars)
	self:SetBars(false)

	self:UpdateXPData()

	-- Show the bar
	UI:EnableEx(db.general.hidestatus)
end

function M:OnDisable()
	UI:Disable()
	LSM3.UnregisterAllCallbacks(self)
end

function M:OnProfileChanged(db, skipBarUpdate)
	-- Receives value of new profile data
	UI:SetLocked(db.general.locked)
	UI:SetClamp(db.general.clamptoscreen)
	UI:SetStrata(db.general.strata)
	UI:SetScale(db.general.scale)
	UI:SetSize(db.general.width, db.general.height)
	UI:SetPosition(db.general.posx, db.general.posy)
	UI:ShowBorder(db.general.border)
	UI:ShowBubbles(db.general.bubbles)
	self:SetTexture(db.general.texture)
	self:SetFontOptions(db.general)
	self:UpdateBarSettings(db.bars)
	self:SetBars(false)

	if not skipBarUpdate then
		self:UpdateXPBar()
	end
end

function M:OnBarEvent(event, ...)
	if event == "button-click" then
		self:OnButtonClick(...)
	elseif event == "button-over" then
		self:SetBars(...)
		self:UpdateXPBar()
	elseif event == "save-position" then
		self:OnSavePosition(...)
	end
end

function M:OnButtonClick(button, ctrl, alt, shift)
	-- Paste currently displayed text to edit box on Shift-LeftClick
	if shift and button == "LeftButton" then
		local activeWin = ChatEdit_GetActiveWindow()
		if not activeWin then
			activeWin = ChatEdit_GetLastActiveWindow()
			activeWin:Show()
		end
		activeWin:SetFocus()
		activeWin:Insert(UI:GetBarText())
	end

	-- Display options on Shift-RightClick
	if shift and button == "RightButton" then
		Config.OpenSettings()
	end

	-- Display Reputation menu on Ctrl-RightClick
	if ctrl and button == "RightButton" then
		-- Temporary opens Rep Window until reworked
		ToggleCharacter("ReputationFrame")
	end
end

function M:OnSavePosition(x, y)
	local db = Config.GetDB()

	db.general.posx = x
	db.general.posy = y
end

function M:SetFontOptions(general)
	local font, size, flags

	if not general then
		general = Config.GetDB().general
	end

	if general.font then
		font = LSM3:Fetch("font", general.font)
	end

	-- Use regular font if we could not restore the saved one.
	if not font then
		font, size, flags = GameFontNormal:GetFont()
	end

	if general.fontoutline then
		flags = "OUTLINE"
	end

	UI:SetFontOptions(font, general.fontsize, general.fontoutline)
end

function M:UpdateBarSettings(bars)
	if type(bars) ~= "table" then
		bars = Config.GetDB().bars
	end

	-- showMaxLevelXP, showMaxLevelAzerite, showRepPriority, isMaxLevelXP, hasAzerite, isMaxLevelAzerite
	Bars.UpdateBarSettings({
		showMaxLevelXP = bars.showmaxlevel,
		showMaxLevelAzerite = bars.showmaxazerite,
		showRepPriority = bars.showrepbar,
		isMaxLevelXP = IsPlayerAtEffectiveMaxLevel(),
		hasAzerite = HasActiveAzeriteItem(),
		isMaxLevelAzerite = IsAzeriteItemAtMaxLevel(),
	})
end

function M:SetBars(isMouseOver, isCtrl, isAlt, isShift)
	Bars.UpdateBarState(isMouseOver, isAlt, isShift or isCtrl)
end

function M:SetTexture(texture)
	local db = Config.GetDB()
	local texturePath = LSM3:Fetch("statusbar", type(texture) == "string" and texture or db.general.texture)
	local horizTile, bgColor = db.general.horizTile, db.bars.background

	UI:SetTexture(texturePath, horizTile, bgColor)
end

-- LSM3 Updates.
function M:MediaUpdate()
end

-- Check for faction updates for the automatic reputation watching
function M:COMBAT_TEXT_UPDATE(event, msgtype)
	-- Abort if it is not a FACTION update
	if msgtype ~= "FACTION" then
		return
	end

	local faction, amount = GetCurrentCombatTextEventInfo()
	local db = Config.GetDB()

	-- If we are watching reputations automatically
	if db.bars.autowatchrep then
		-- Do not track Horde / Alliance classic faction header
		if faction == FACTION_HORDE or faction == FACTION_ALLIANCE then
			return
		end

		-- We do not want to watch factions we are losing reputation with
		if tostring(amount):match("^%-.*") then
			return
		end

		-- Fix for auto tracking guild reputation since the COMBAT_TEXT_UPDATE does not contain
		-- the guild name, it just contains "Guild"
		if faction == GUILD then
			if db.bars.autotrackguild then
				faction = GetGuildInfo("player")
			else
				return
			end
		end

		-- Everything ok? Watch the faction!
		SetWatchedFactionByName(faction)
	end
end

-- Hide and Show the XP frame when entering and leaving pet battles.
function M:PET_BATTLE_OPENING_START()
	UI:Disable()
end

function M:PET_BATTLE_CLOSE()
	UI:EnableEx(Config.GetDB().general.hidestatus)
end

-- Update XP bar data
function M:UpdateXPData()
	Data.UpdateXP(getPlayerXP(), UnitXPMax("player"))
	self:UpdateXPBar()
end

function M:UpdateReputationData()
	local db = Config.GetDB()

	local repName, repStanding, repMin, repMax, repValue, factionID = GetWatchedFactionInfo()
	local isFactionParagon = IsFactionParagon(factionID)
	local hasParagonReward = false

	local txtcol = db.bars.reptext

	UI:SetBarTextColor(txtcol)

	if repName == nil then
		UI:SetMainBarVisible(false)
		UI:SetBarText(L["You need to select a faction to watch"])
		UI:SetFactionInfo(nil, nil)
		return
	end

	local hasBonusRep, canBeLFGBonus
	local friendID, friendRep, friendMaxRep, friendName, _, _,
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
		repMin = 0
	else
		hasBonusRep, canBeLFGBonus = select(15, GetFactionInfoByID(factionID))
		-- Check faction with Exalted standing to have paragon reputation.
		-- If so, adjust values to show bar to next paragon bonus.
		if repStanding == Config.STANDING_EXALTED then
			if isFactionParagon then
				local parValue, parThresh, _, hasReward, tooLowLevelForParagon = GetFactionParagonInfo(factionID)
				hasParagonReward = not tooLowLevelForParagon and hasReward
				-- parValue is cumulative. We need to get modulo by the current threshold.
				repMax = parThresh
				repValue = parValue % parThresh
				-- if we have reward pending, show overflow
				if hasParagonReward then
					repValue = repValue + parThresh
				end
			else
				repMax = 1000
				repValue = 999
			end
		else
			repMax = repMax - repMin
			repValue = repValue - repMin
		end

		repMin = 0
	end


	UI:SetFactionInfo(
		factionID,
		db.bars.repicons and {
				hasBonusRep,
				canBeLFGBonus and factionID == GetLFGBonusFactionID(),
				isFactionParagon,
				hasParagonReward
			} or nil
	)

	UI:SetMainBarVisible(true)
	UI:SetRemainingBarVisible(false)

	UI:SetMainBarValues(math_min(0, repValue), repMax, repValue)

	-- Use our own color for exalted.
	local repColor
	if repStanding == Config.STANDING_EXALTED then
		repColor = db.bars.exalted
	else
		repColor = FACTION_BAR_COLORS[repStanding]
	end

	UI:SetMainBarColor(repColor)
	UI:SetBarText(
		GetReputationText( {
			repName, repStanding, repMin, repMax,
			repValue, friendID, friendTextLevel,
			hasBonusRep, canBeLFGBonus, isFactionParagon
		} )
	)
end

function M:UpdateXPBar()
	local db = Config.GetDB()
	local bar = Bars.GetVisibleBar()

	if bar == Bars.REP then
		return self:UpdateReputationData()
	else
		UI:SetMainBarVisible(true)
	end

	local xpText, currXP, maxXP, barColor, txtcol

	if bar == Bars.AZ then
		local item = FindActiveAzeriteItem()
		if item then
			local name = GetAzeriteItemName(item)
			currXP, maxXP = GetAzeriteItemXPInfo(item)
			xpText = GetAzerText(name, currXP, maxXP, GetAzeritePowerLevel(item))
		else
			currXP, maxXP, xpText = 0, 1, L["Azerite item not found!"]
		end
		barColor = db.bars.azerite
		UI:SetRemainingBarVisible(false)
		txtcol = db.bars.azertext

		UI:SetAzeriteInfo(db.bars.azicons and { IsAzeriteItemAtMaxLevel() } or nil)
	else -- if bar == Bars.XP
		-- GetXPExhaustion() returns nil when no bonus present and 0 on max level
		local xp, restedXP = Data.GetXP(), GetXPExhaustion() or 0
		local maxLevel, reason = Config.GetPlayerMaxLevel()
		local level = UnitLevel("player")
		local isXPStopped = reason == Config.XPLockedReasons.LOCKED_XP
		currXP, maxXP = xp.curr, xp.max
		if restedXP == 0 or isXPStopped then
			barColor = db.bars.normal
			UI:SetRemainingBarVisible(false)
		else
			UI:SetRemainingBarValues(math_min(0, currXP), maxXP, currXP + restedXP)

			local remaining = db.bars.remaining

			UI:SetRemainingBarColor(remaining)

			-- Do we want to indicate rest?
			if IsResting() and db.bars.indicaterest then
				barColor = db.bars.resting
			else
				barColor = db.bars.rested
			end

			UI:SetRemainingBarVisible(db.bars.showremaining)
		end

		local isLevelCap = reason == Config.XPLockedReasons.MAX_TRIAL_LEVEL
		local isMaxLevel = IsPlayerAtEffectiveMaxLevel() and reason == Config.XPLockedReasons.MAX_EXPANSION_LEVEL

		UI:SetXPInfo(db.bars.xpicons and { isMaxLevel, isXPStopped, isLevelCap } or nil)

		txtcol = db.bars.xptext
		xpText = GetXPText(xp.curr, xp.max, xp.rem, restedXP, level, maxLevel)
	end

	UI:SetMainBarValues(math_min(0, currXP), maxXP, currXP)
	UI:SetMainBarColor(barColor)

	UI:SetBarText(xpText)
	UI:SetBarTextColor(txtcol)
end

function M:LevelUp(event, level)
	Bars.UpdateBarSettings({
		isMaxLevelXP = IsPlayerAtEffectiveMaxLevel(),
	})
	self:UpdateXPBar()
end
