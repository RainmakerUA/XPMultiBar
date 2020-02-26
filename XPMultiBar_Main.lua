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
local pairs = pairs
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

local SetTimeout = emptyFun
local FindActiveAzeriteItem = emptyFun
local GetAzeriteItemXPInfo = emptyFun
local GetAzeritePowerLevel = emptyFun
local HasActiveAzeriteItem = emptyFun
local IsAzeriteItemAtMaxLevel = emptyFun

if not wowClassic then
	SetTimeout = C_Timer.After
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

local function GetAzerText(name, currAP, maxAP, level)
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
end

local GetHeartOfAzerothInfo

do
	local heartOfAzerothItemID = 158075
	local itemName

	-- Since GetItemInfo function can be async, callback can be provided
	GetHeartOfAzerothInfo = function(callback)
		local name = nil
		local item = FindActiveAzeriteItem()

		if not item then
			return nil
		end

		if itemName then
			name = itemName
		else
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
							callback()
						end
					end)
				end
			end
		end

		local currXP, maxXP = GetAzeriteItemXPInfo(item)
		return name or "???", GetAzeritePowerLevel(item), currXP, maxXP
	end
end

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
--[[
local CreateAnimationSequence, AnimateBar

do
	local queue = {}
	local AnimationStep

	function CreateAnimationSequence(min, max, start, finish,
											color, text, onstart, onfinish)
		return {
			min = min,
			max = max,
			start = start or 0,
			finish = finish,
			diff = (finish - (start or 0)) / (max - min),
			color = color,
			text = text,
			onstart = onstart,
			onfinish = onfinish
		}
	end

	function AnimateBar()
	end

	function AnimationStep()
	end
end
]]
local barDataHandlers, barHandlers, barData

--[[ db, showText, data, prevData, restData, prevRestData ]]
local function UpdateXPBar(updateData)
	local db, showText, data, prevData, restData, prevRestData
			= updateData.db, updateData.showText, updateData.data, updateData.prevData,
				updateData.restData, updateData.prevRestData

	-- GetXPExhaustion() returns nil when no bonus present and 0 on max level
	local restedXP = restData and restData.curr or 0
	local maxLevel, reason = Config.GetPlayerMaxLevel()
	local level = data.level
	local isXPStopped = reason == Config.XPLockedReasons.LOCKED_XP
	local currXP, maxXP = data.curr, data.max
	local barColor

	if prevRestData then
		-- animate Rest bar
	end

	if restedXP == 0 or isXPStopped then
		barColor = db.bars.normal
		UI:SetRemainingBarVisible(false)
	else
		UI:SetRemainingBarValues(math_min(0, currXP), maxXP, currXP + restedXP)
		UI:SetRemainingBarColor(db.bars.remaining)

		if db.bars.indicaterest and IsResting() then
			barColor = db.bars.resting
		else
			barColor = db.bars.rested
		end

		UI:SetRemainingBarVisible(db.bars.showremaining)
	end

	local isLevelCap = reason == Config.XPLockedReasons.MAX_TRIAL_LEVEL
	local isMaxLevel = IsPlayerAtEffectiveMaxLevel() and reason == Config.XPLockedReasons.MAX_EXPANSION_LEVEL
	local txtcol = showText and db.bars.xptext or nil
	local xpText = showText and GetXPText(data.curr, data.max, data.rem, restedXP, level, maxLevel, data.ktl) or nil

	UI:SetXPInfo(db.bars.xpicons and showText and { isMaxLevel, isXPStopped, isLevelCap } or nil)

	UI:SetMainBarValues(math_min(0, currXP), maxXP, currXP)
	UI:SetMainBarColor(barColor, DoSetBorderColor(db.general))

	UI:SetBarText(xpText)
	UI:SetBarTextColor(txtcol)
end

--[[ db, showText, data, prevData ]]
local function UpdateAzeriteBar(updateData)
	local db, showText, data, prevData
			= updateData.db, updateData.showText, updateData.data, updateData.prevData
	local name, azeriteLevel, currXP, maxXP = data.name, data.level, data.curr, data.max
	local xpText

	if name then
		xpText = showText and GetAzerText(name, currXP, maxXP, azeriteLevel) or nil
	else
		currXP, maxXP, xpText = 0, 1, L["Azerite item not found!"]
	end

	local barColor, txtcol = db.bars.azerite, showText and db.bars.azertext or nil

	UI:SetAzeriteInfo(db.bars.azicons and showText and { IsAzeriteItemAtMaxLevel() } or nil)

	UI:SetRemainingBarVisible(false)

	UI:SetMainBarValues(math_min(0, currXP), maxXP, currXP)
	UI:SetMainBarColor(barColor, DoSetBorderColor(db.general))

	UI:SetBarText(xpText)
	UI:SetBarTextColor(txtcol)
end

--[[ db, showText, data, prevData ]]
local function UpdateReputationBar(updateData)
	local db, showText, data, prevData
			= updateData.db, updateData.showText, updateData.data, updateData.prevData
	local repInfo = data.extra
	local repFactionID, repName, repStanding,
			repStandingText, repStandingColor,
			repMin, repMax, repValue,
			hasBonusRep, isLFGBonus,
			isFactionParagon, hasParagonReward, isAtWar = unpack(repInfo)

	if repName == nil then
		UI:SetMainBarVisible(false, DoSetBorderColor(db.general))
		UI:SetRemainingBarVisible(false)
		UI:SetBarText(L["You need to select a faction to watch"])
		UI:SetFactionInfo(nil, nil)
		return
	end

	--if prevData then
		-- todo: animate
	do--else
		UI:SetFactionInfo(repFactionID, db.bars.repicons and showText and {
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
		UI:SetBarText(showText and GetReputationText(db.bars.repstring, repInfo) or nil)
		UI:SetBarTextColor(showText and db.bars.reptext or nil)
	end
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

	barDataHandlers = {
		[Bars.None] = emptyFun,
		[Bars.XP] = self.UpdateXPData,
		[Bars.AZ] = (not wowClassic) and self.UpdateAzeriteData or nil,
		[Bars.REP] = self.UpdateReputationData,
		RESTDATA = self.UpdateRestData,
	}

	barHandlers = {
		[Bars.None] = emptyFun,
		[Bars.XP] = UpdateXPBar,
		[Bars.AZ] = (not wowClassic) and UpdateAzeriteBar or nil,
		[Bars.REP] = UpdateReputationBar,
	}

	barData = {
		[Bars.XP] = self.xpData,
		[Bars.AZ] = self.azerData, -- nil on Classic
		[Bars.REP] = self.repData,
		--RESTDATA = self.restData,
	}

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

	LSM3:Register("border", "Azerite Tooltip", [[interface\tooltips\ui-tooltip-border-azerite]])
	LSM3:Register("border", "Corrupted Tooltip", [[interface\tooltips\ui-tooltip-border-corrupted]])
	LSM3:Register("border", "Blizzard Minimap Tooltip", [[interface\minimap\tooltipbackdrop]])
	LSM3:Register("border", "Blizzard Toast", [[Interface\FriendsFrame\UI-Toast-Border]])

	local uiHandler = function(methodName, updateBar)
		return { UI[methodName], updateBar, ["self"] = UI }
	end

	local onBarSettingsUpdated = {
		function(localSelf)
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
				eventMap._self:UpdateActiveBar()
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
	self:RegisterEvent("PLAYER_UPDATE_RESTING", "UpdateRestData")
	self:RegisterEvent("UPDATE_EXHAUSTION", "UpdateRestData")
	self:RegisterEvent("UPDATE_FACTION", "UpdateReputationData")

	if not wowClassic then
		self:RegisterEvent("AZERITE_ITEM_EXPERIENCE_CHANGED", "UpdateAzeriteData")
		self:RegisterEvent("LFG_BONUS_FACTION_ID_UPDATED", "UpdateReputationData")
		self:RegisterEvent("QUEST_TURNED_IN", "CheckParagonRewardQuest")
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

	-- Call bar handlers to fill initial values in data
	for _, v in pairs(barDataHandlers) do
		v(self, false)
	end

	-- Show the bar
	UI:EnableEx(db.general.hidestatus)

	self:UpdateActiveBar()
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
	self:SetBars()
	Reputation:SetExaltedColor(db.bars.exalted)

	if not skipBarUpdate then
		self:UpdateActiveBar()
	end
end

function M:OnBarEvent(event, ...)
	if event == "button-click" then
		self:OnButtonClick(...)
	elseif event == "button-over" then
		self:SetBars(...)
		self:UpdateActiveBar()
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

function M:UpdateXPData(updateBar)
	local prevData = updateBar and self.xpData:Get() or nil
	self.xpData:Update(UnitLevel("player"), GetPlayerXP(), UnitXPMax("player"))

	Bars.UpdateBarSettings({
		isMaxLevelXP = IsPlayerAtEffectiveMaxLevel(),
	})
	Bars.UpdateBarState()

	if updateBar then
		self:UpdateActiveBar({ prevData = prevData })
	end
end

function M:UpdateRestData(updateBar)
	local prevData = updateBar and self.restData:Get() or nil
	self.restData:Update(0, GetXPExhaustion() or 0)

	if updateBar then
		self:UpdateActiveBar({ prevRestData = prevData })
	end
end

function M:UpdateAzeriteData(updateBar)
	local prevData = updateBar and self.azerData:Get() or nil

	Bars.UpdateBarSettings({
		hasAzerite = HasActiveAzeriteItem(),
		isMaxLevelAzerite = IsAzeriteItemAtMaxLevel(),
	})
	Bars.UpdateBarState()

	local azerCallback = Utils.Bind(
										function(main, updBar)
											main:UpdateAzeriteData(updBar)
											main:UpdateActiveBar()
										end,
										self, updateBar
									)
	local name, azeriteLevel, currXP, maxXP = GetHeartOfAzerothInfo(azerCallback)
	if name then
		self.azerData:Update(name, azeriteLevel, currXP, maxXP)
		if updateBar then
			self:UpdateActiveBar({ prevData = prevData })
		end
	end
end

function M:UpdateReputationData(updateBar)
	local prevData = updateBar and self.repData:Get() or nil
	local repInfo = { Reputation:GetWatchedFactionData() }
	local repName, repStanding, repMax, repValue = repInfo[2], repInfo[3], repInfo[7], repInfo[8]

	if prevData and not prevData.curr then
		prevData = nil
	end

	self:ShowReputationList(true)
	self.repData:Update(repName, repStanding, repValue, repMax, repInfo)

	if updateBar then
		local isParagon, paragonCount, paragonCountPrev = repInfo[11], repInfo[21], prevData and prevData.extra[21] or 0
		--print("M:UpdateReputationData paragonCount:", paragonCountPrev, "->", paragonCount)
		if isParagon and paragonCount > paragonCountPrev then
			-- paragon threshold was overcome
			-- set timeout to allow hasReward to be updated
			SetTimeout(0.5, Utils.Bind(self.UpdateActiveBar, self, { prevData = prevData }))
		else
			self:UpdateActiveBar({ prevData = prevData })
		end
	end
end

function M:CheckParagonRewardQuest(event, questID)
	if select(20, Reputation:GetWatchedFactionData()) == questID then
		-- set timeout to allow hasReward to be updated
		SetTimeout(0.5, Utils.Bind(self.UpdateReputationData, self, true))
	end
end

function M:LevelUp(event, level)
	Bars.UpdateBarSettings({
		isMaxLevelXP = IsPlayerAtEffectiveMaxLevel(),
	})
	Bars.UpdateBarState()
	self:UpdateActiveBar()
end

function M:UpdateActiveBar(updateData)
	local db = Config.GetDB()
	local bar = Bars.GetVisibleBar()
	local showText = bar < Config.FLAG_NOTEXT
	bar = bar % Config.FLAG_NOTEXT

	if not updateData then
		updateData = {}
	end

	if bar > 0 then
		updateData.db = db
		updateData.showText = showText
		updateData.data = barData[bar]:Get()
		if bar == Bars.XP then
			updateData.restData = self.restData:Get()
		end
		return barHandlers[bar](updateData)
	end

	return nil
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
