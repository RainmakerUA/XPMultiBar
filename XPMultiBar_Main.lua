--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_Main.lua - module
		Main module for XPMultiBar addon
--]=====]

local addonName = ...
local Utils = LibStub("rmUtils-1.0")
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Main = XPMultiBar:NewModule("Main", "AceEvent-3.0")

local M = Main

-- Libs
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local LSM3 = LibStub("LibSharedMedia-3.0")

-- Lua
local print = print
local select = select
local tostring = tostring
local type = type
local unpack = unpack

-- Math
local math_ceil = math.ceil
local math_min = math.min

local wowClassic = Utils.IsWoWClassic
local emptyFun = Utils.EmptyFn

-- WoW globals
local ChatEdit_GetActiveWindow = ChatEdit_GetActiveWindow
local ChatEdit_GetLastActiveWindow = ChatEdit_GetLastActiveWindow
local GameLimitedMode_IsActive = GameLimitedMode_IsActive
local GetContainerItemInfo = GetContainerItemInfo
local GetCurrentCombatTextEventInfo = GetCurrentCombatTextEventInfo
local GetInventoryItemID = GetInventoryItemID
local GetItemInfo = GetItemInfo
local GetRestrictedAccountData = GetRestrictedAccountData
local GetXPExhaustion = GetXPExhaustion
local InCombatLockdown = InCombatLockdown
local IsPlayerAtEffectiveMaxLevel = IsPlayerAtEffectiveMaxLevel
local IsResting = IsResting
local Item = Item
local ToggleCharacter = ToggleCharacter
local UnitLevel = UnitLevel
local UnitTrialXP = UnitTrialXP
local UnitXP = UnitXP
local UnitXPMax = UnitXPMax

local FindActiveAzeriteItem = emptyFun
local GetAzeriteItemXPInfo = emptyFun
local GetAzeritePowerLevel = emptyFun
local HasActiveAzeriteItem = emptyFun
local IsAzeriteItemAtMaxLevel = emptyFun

if not wowClassic then
	FindActiveAzeriteItem = C_AzeriteItem.FindActiveAzeriteItem
	GetAzeriteItemXPInfo = C_AzeriteItem.GetAzeriteItemXPInfo
	GetAzeritePowerLevel = C_AzeriteItem.GetPowerLevel
	HasActiveAzeriteItem = C_AzeriteItem.HasActiveAzeriteItem
	IsAzeriteItemAtMaxLevel = C_AzeriteItem.IsAzeriteItemAtMaxLevel
end

-- Remove all known globals after this point
-- luacheck: std none

-- Modules late init
local Bars
local Config
local Data
local Reputation
local UI

local function Commify(num)
	local db = Config.GetDB()
	return db.general.commify and Utils.Commify(num) or tostring(num)
end

local function GetPlayerXP()
	if GameLimitedMode_IsActive() then
		local rLevel = GetRestrictedAccountData();
		if UnitLevel("player") >= rLevel then
			return UnitTrialXP("player");
		end
	end

	return UnitXP("player")
end

local function GetXPText(cXP, nXP, remXP, restedXP, level, maxLevel, ktl)
	local nextLevel = level == maxLevel and level or (level + 1)
	local db = Config.GetDB()

	return Utils.MultiReplace(
		db.bars.xpstring,
		{
			["%[curXP%]"] = Commify(cXP),
			["%[maxXP%]"] = Commify(nXP),
			["%[restXP%]"] = Commify(restedXP),
			["%[restPC%]"] = Utils.FormatPercents(restedXP, nXP),
			["%[curPC%]"] = Utils.FormatPercents(cXP, nXP),
			["%[needPC%]"] = Utils.FormatRemainingPercents(cXP, nXP),
			["%[pLVL%]"] = level,
			["%[nLVL%]"] = nextLevel,
			["%[mLVL%]"] = maxLevel,
			["%[needXP%]"] = Commify(remXP),
			["%[KTL%]"] = ktl > 0 and Commify(ktl) or "?",
			["%[BTL%]"] = ("%d"):format(math_ceil(20 - ((cXP / nXP * 100) / 5)))
		}
	)
end

--[[local function GetAzerText(name, currAP, maxAP, level)
	local db = Config.GetDB()
	return Utils.MultiReplace(
		db.bars.azerstr,
		{
			["%[name%]"] = name,
			["%[curXP%]"] = Commify(currAP),
			["%[maxXP%]"] = Commify(maxAP),
			["%[curPC%]"] = Utils.FormatPercents(currAP, maxAP),
			["%[needPC%]"] = Utils.FormatRemainingPercents(currAP, maxAP),
			["%[pLVL%]"] = level,
			["%[nLVL%]"] = level + 1,
			["%[needXP%]"] = Commify(maxAP - currAP)
		}
	)
end]]

--[==[local GetHeartOfAzerothInfo

do
	local heartOfAzerothItemID = 158075
	local itemName

	-- Since GetItemInfo function can be async, callback can be provided
	GetHeartOfAzerothInfo = function(callback, callbackReceiver)
		local name = nil
		local item = FindActiveAzeriteItem()

		if itemName then
			name = itemName
		elseif item then
			local itemID

			if item:IsBagAndSlot() then
				itemID = select(10, GetContainerItemInfo(item:GetBagAndSlot()))
			else
				itemID = GetInventoryItemID("player", item:GetEquipmentSlot())
			end

			if not itemID or itemID == 0 then
				print("|cFFFFFF00[XPMultiBar]:|r", Utils.Text.GetError("Heart of Azeroth item ID is " .. (itemID or "<nil>")))
			elseif itemID == heartOfAzerothItemID then
				name = GetItemInfo(itemID)
				if name then
					itemName = name
				else
					--[[
						If the item hasn't been encountered since the game client was last started,
							this function will initially return nil,
							but will asynchronously query the server to obtain the missing data,
							triggering GET_ITEM_INFO_RECEIVED when the information is available.
						ItemMixin:ContinueOnItemLoad() provides a convenient callback once item data has been queried
					]]
					Item:CreateFromItemID(itemID):ContinueOnItemLoad(function()
						itemName = GetItemInfo(itemID)
						if callback then
							callback(callbackReceiver)
						end
					end)
				end
			end
		end

		local currXP, maxXP = GetAzeriteItemXPInfo(item)
		return name or "???", GetAzeritePowerLevel(item), currXP, maxXP
	end
end]==]

local function GetReputationText(repFormat, repInfo)
	local repID, repName, repStanding, repStandingText, repStandingColor,
			repMin, repMax, repValue, hasBonusRep, isLFGBonus,
			isFactionParagon, hasParagonReward = unpack(repInfo)

	return Utils.MultiReplace(repFormat, {
			["%[faction%]"] = repName,
			["%[standing%]"] = repStandingText,
			["%[curRep%]"] = Commify(repValue),
			["%[maxRep%]"] = Commify(repMax),
			["%[repPC%]"] = Utils.FormatPercents(repValue, repMax),
			["%[needRep%]"] = Commify(repMax - repValue),
			["%[needPC%]"] = Utils.FormatRemainingPercents(repValue, repMax),
		})
end

local function DoSetBorderColor(db_general)
	return db_general.border and db_general.borderDynamicColor
end

function M:OnInitialize()
	Bars = XPMultiBar:GetModule("Bars")
	Config = XPMultiBar:GetModule("Config")
	Data = XPMultiBar:GetModule("Data")
	UI = XPMultiBar:GetModule("UI")
	Reputation = XPMultiBar:GetModule("Reputation")

	self.xpData = Data:New("XP", true)
	self.restData = Data:New("XPRested")
	self.repData = Data:New()
	if not wowClassic then
		self.azerData = Data:New("AP")
	end

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

	LSM3:Register("border", "Blizzard Minimap Tooltip", [[interface\minimap\tooltipbackdrop]])
	LSM3:Register("border", "Blizzard Toast", [[Interface\FriendsFrame\UI-Toast-Border]])

	local uiHandler = function(methodName, updateBar)
		return { UI[methodName], updateBar, ["self"] = UI }
	end

	local onBarSettingsUpdated = {
		function(localSelf, _)
			localSelf:UpdateBarSettings()
			localSelf:SetBars(false)
		end,
		true
	}

	local onDisplayIconsUpdated = uiHandler("HideIcons", true)

	local eventMap = {
		_self = self,
		position = self.SetPosition,
		locked = uiHandler("SetLocked"),
		clamptoscreen = uiHandler("SetClamp"),
		strata = uiHandler("SetStrata"),
		bgColor = uiHandler("SetBackgroundColor", true),
		width = uiHandler("SetWidth", true),
		height = uiHandler("SetHeight", true),
		scale = uiHandler("SetScale"),
		font = self.SetFontOptions,
		fontsize = self.SetFontOptions,
		fontoutline = self.SetFontOptions,
		texture = self.SetTexture,
		horizTile = self.SetTexture,
		bubbles = uiHandler("ShowBubbles"),
		border = { self.SetBorder, true },
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
		priority = onBarSettingsUpdated,
		exaltedColor = { Reputation.SetExaltedColor, true, ["self"] = Reputation }
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

	self:RegisterEvent("PLAYER_XP_UPDATE", "UpdateXPData")
	self:RegisterEvent("PLAYER_LEVEL_UP", "LevelUp")
	self:RegisterEvent("PLAYER_UPDATE_RESTING", "UpdateXPData")
	self:RegisterEvent("UPDATE_EXHAUSTION", "UpdateXPBar")
	self:RegisterEvent("UPDATE_FACTION", "UpdateXPBar")
	if not wowClassic then
		self:RegisterEvent("AZERITE_ITEM_EXPERIENCE_CHANGED", "UpdateXPBar")
	end

	if db.reputation.autowatchrep then
		self:RegisterEvent("COMBAT_TEXT_UPDATE")
	end

	if not wowClassic then
		self:RegisterEvent("PET_BATTLE_OPENING_START")
		self:RegisterEvent("PET_BATTLE_CLOSE")
	end

	-- Register some LSM3 callbacks
	LSM3.RegisterCallback(
		self, "LibSharedMedia_SetGlobal",
		function(callback, mtype, override)
			if mtype == "statusbar" and override ~= nil then
				self:SetTexture(override)
			end
		end
	)

	-- Show the bar
	UI:EnableEx(db.general.hidestatus)

	-- Update bars
	self:UpdateBarSettings(db.bars.priority)
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
	self:SetPosition(db.general)
	UI:SetBackgroundColor(db.bars.background)
	self:SetBorder(db.general)
	UI:ShowBubbles(db.general.bubbles)
	self:SetTexture(db.general.texture)
	self:SetFontOptions(db.general)
	self:UpdateBarSettings(db.bars.priority)
	self:SetBars(false)
	Reputation:SetExaltedColor(db.bars.exalted)

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
		self:ToggleBarTooltip(...)
	elseif event == "save-position" then
		self:OnSavePosition(...)
	end
end

function M:OnButtonClick(button, ctrl, alt, shift)
	local action = Config.GetActionOrProcessSettings(button, ctrl, alt, shift)
	if action == "linktext" then
		-- Paste currently displayed text to edit box (Shift-LeftClick)
		local activeWin = ChatEdit_GetActiveWindow()
		if not activeWin then
			activeWin = ChatEdit_GetLastActiveWindow()
			activeWin:Show()
		end
		activeWin:SetFocus()
		activeWin:Insert(UI:GetBarText())
	elseif action == "settings" then
		-- Display options on Shift-RightClick
		Config.OpenSettings()
	elseif action == "repmenu" and not InCombatLockdown() then
		-- Display Reputation menu on Ctrl-RightClick
		self:ShowReputationList()
	end
end

function M:OnSavePosition(position)
	local gen = Config.GetDB().general

	gen.anchor = position.anchor
	gen.anchorRelative = (position.anchor == position.anchorRel)
							and Config.Empty
							or position.anchorRel
	gen.posx = position.x
	gen.posy = position.y
end

function M:SetPosition(general)
	if type(general) ~= "table" then
		general = Config.GetDB().general
	end

	local position = {
		anchor = general.anchor,
		anchorRel = general.anchorRelative == Config.Empty
							and general.anchor
							or general.anchorRelative,
		x = general.posx,
		y = general.posy
	}

	UI:SetPosition(position)
end

function M:SetFontOptions(general)
	local font

	if type(general) ~= "table" then
		general = Config.GetDB().general
	end

	if general.font then
		font = LSM3:Fetch("font", general.font)
	end

	UI:SetFontOptions(font, general.fontsize, general.fontoutline)
end

function M:UpdateBarSettings(prio)
	if type(prio) ~= "table" then
		prio = Config.GetDB().bars.priority
	end

	-- priority[12], isMaxLevelXP, hasAzerite, isMaxLevelAzerite
	Bars.UpdateBarSettings({
		priority = prio,
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

function M:SetBorder(general)
	local texPath = general.border and LSM3:Fetch("border", general.borderTexture) or nil
	UI:SetBorder(texPath, (not general.borderDynamicColor) and general.borderColor or nil)
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

	local factionName, amount = GetCurrentCombatTextEventInfo()
	local db = Config.GetDB()

	-- If we are watching reputations automatically
	if db.reputation.autowatchrep then
		Reputation:SetWatchedFaction(factionName, amount, db.reputation.autotrackguild)
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
	self.xpData:Update(0, GetPlayerXP(), UnitXPMax("player"))
	self:UpdateXPBar()
end

function M:UpdateReputationBar()
	local db = Config.GetDB()
	local repInfo = { Reputation:GetWatchedFactionData() }
	local repFactionID, repName, repStanding,
			repStandingText, repStandingColor,
			repMin, repMax, repValue,
			hasBonusRep, isLFGBonus,
			isFactionParagon, hasParagonReward, isAtWar = unpack(repInfo)

	UI:SetBarTextColor(db.bars.reptext)

	if repName == nil then
		UI:SetMainBarVisible(false, DoSetBorderColor(db.general))
		UI:SetRemainingBarVisible(false)
		UI:SetBarText(L["You need to select a faction to watch"])
		UI:SetFactionInfo(nil, nil)
		return
	end

	UI:SetFactionInfo(repFactionID, db.bars.repicons and {
				hasBonusRep,
				isLFGBonus,
				isFactionParagon,
				hasParagonReward,
				isAtWar,
			} or nil)

	UI:SetMainBarVisible(true)
	UI:SetRemainingBarVisible(false)

	UI:SetMainBarValues(repMin, repMax, repValue)
	UI:SetMainBarColor(repStandingColor, DoSetBorderColor(db.general))
	UI:SetBarText(GetReputationText(db.bars.repstring, repInfo))
end

function M:UpdateXPBar(event)
	local db = Config.GetDB()
	local bar = Bars.GetVisibleBar()

	if event == "UPDATE_FACTION" then
		self:ShowReputationList(true)
	end

	if bar == Bars.REP then
		return self:UpdateReputationBar()
	else
		UI:SetMainBarVisible(true)
	end

	local xpText, currXP, maxXP, barColor, txtcol

	if bar == Bars.AZ then
		--[[ocal name, azeriteLevel
		name, azeriteLevel, currXP, maxXP = GetHeartOfAzerothInfo(self.UpdateXPBar, self)
		if name then
			xpText = GetAzerText(name, currXP, maxXP, azeriteLevel)
		else
			currXP, maxXP, xpText = 0, 1, L["Azerite item not found!"]
		end

		barColor = db.bars.azerite
		UI:SetRemainingBarVisible(false)
		txtcol = db.bars.azertext

		UI:SetAzeriteInfo(db.bars.azicons and { IsAzeriteItemAtMaxLevel() } or nil)]]
	else -- if bar == Bars.XP
		-- GetXPExhaustion() returns nil when no bonus present and 0 on max level
		local xp, restedXP = self.xpData:Get(), GetXPExhaustion() or 0
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
		xpText = GetXPText(xp.curr, xp.max, xp.rem, restedXP, level, maxLevel, self.xpData:GetKTL())
	end

	UI:SetMainBarValues(math_min(0, currXP), maxXP, currXP)
	UI:SetMainBarColor(barColor, DoSetBorderColor(db.general))

	UI:SetBarText(xpText)
	UI:SetBarTextColor(txtcol)
end

function M:LevelUp(event, level)
	Bars.UpdateBarSettings({
		isMaxLevelXP = IsPlayerAtEffectiveMaxLevel(),
	})
	Bars.UpdateBarState(false)
	self:UpdateXPBar()
end

function M:ToggleBarTooltip(isMouseOver, isCtrl, isAlt, isShift)
	local db = Config.GetDB()
	local rep = db.reputation
	local needAlt, needCtrl, needShift = rep.showFavoritesModAlt, rep.showFavoritesModCtrl, rep.showFavoritesModShift
	local willShow = rep.showFavorites and (rep.showFavInCombat or not InCombatLockdown())
						and (isAlt or not needAlt)
						and (isCtrl or not needCtrl)
						and (isShift or not needShift)
	if willShow then
		Reputation:ToggleBarTooltip(isMouseOver, rep.favorites, db.general.commify)
	end
end

function M:ShowReputationList(redraw)
	local showRepMenu = Config.GetDB().reputation.showRepMenu

	if showRepMenu then
		Reputation:ShowFactionMenu(redraw)
	elseif not redraw then
		-- Just open Character Rep. Window
		ToggleCharacter("ReputationFrame")
	end
end
