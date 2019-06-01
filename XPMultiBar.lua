--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar.lua - module
		Main module (UI) for XPMultiBar addon
--]=====]

--[[
	StatusTrackingBarManager:IsVisible() -- !!!
	StatusTrackingBarManager:Hide()
	StatusTrackingBarManager:Show()
]]

local addonName = ...
local XPMultiBar = LibStub("AceAddon-3.0"):NewAddon(addonName)
local UI = XPMultiBar:NewModule("UI", "AceEvent-3.0")

local self = UI

-- Libs
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local LSM3 = LibStub("LibSharedMedia-3.0")
local LQT = LibStub("LibQTip-1.0")

-- Lua
local select = select
local tostring = tostring
local type = type

-- Math
local math_ceil = math.ceil
local math_floor = math.floor
local math_min = math.min

-- WoW globals
local ChatEdit_GetActiveWindow = ChatEdit_GetActiveWindow
local ChatEdit_GetLastActiveWindow = ChatEdit_GetLastActiveWindow
local CollapseFactionHeader = CollapseFactionHeader
local ExpandFactionHeader = ExpandFactionHeader
local GameFontNormal = GameFontNormal
local GameTooltip = GameTooltip
local GameTooltip_SetDefaultAnchor = GameTooltip_SetDefaultAnchor
local GameTooltipTextSmall = GameTooltipTextSmall
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
local IsResting = IsResting
local IsShiftKeyDown = IsShiftKeyDown
local SetWatchedFactionIndex = SetWatchedFactionIndex
local IsXPUserDisabled = IsXPUserDisabled
local UIParent = UIParent
local UnitLevel = UnitLevel
local UnitXP = UnitXP
local UnitXPMax = UnitXPMax
local WorldFrame = WorldFrame
local HasActiveAzeriteItem = C_AzeriteItem.HasActiveAzeriteItem
local FindActiveAzeriteItem = C_AzeriteItem.FindActiveAzeriteItem
local GetAzeriteItemXPInfo = C_AzeriteItem.GetAzeriteItemXPInfo
local GetAzeritePowerLevel = C_AzeriteItem.GetPowerLevel
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

-- Reputation menu tooltip
local repTooltip

local function commify(num)
	local db = Config.GetDB()
	return Utils.Commify(num, db.general.commify)
end

local function isPlayerMaxLevel(level)
	if not level then
		level = UnitLevel("player")
	end
	return level == Config.MAX_PLAYER_LEVEL
end

local function GetXPText(cXP, nXP, remXP, restedXP)
	local restXPText, restPCText
	local level = UnitLevel("player")
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
			["%[nLVL%]"] = level + 1,
			["%[mLVL%]"] = Config.MAX_PLAYER_LEVEL,
			["%[needXP%]"] = commify(remXP),
			["%[isLocked%]"] = IsXPUserDisabled() and "*" or "",
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
		local itemID --Heart of Azeroth ID = 158075
		if item:IsBagAndSlot() then
			itemID = select(10, GetContainerItemInfo(item:GetBagAndSlot()))
		else
			itemID = GetInventoryItemID("player", item:GetEquipmentSlot())
		end
		-- HACK: When first entering world, script gets itemID = nil|0
		-- Just hardcode Heart of Azeroth ID in this case
		if itemID and itemID > 0 then
			-- Also name is not retrieved in this case
			name = GetItemInfo(itemID)
		end
	end
	return name or "???"
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
		-- Add a + next to the standing for bonus or paragon reputation.
		if hasBonusRep or isFactionParagon then
			standingText = ("%s+"):format(Config.GetFactionStandingLabel(repStanding))
		else
			standingText = Config.GetFactionStandingLabel(repStanding)
		end
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
			["%[needPC%]"] = Utils.FormatRemainingPercents(repValue, repMax)
		}
	)
end

local function GetReputationTooltipText(standingText, bottom, top, earned)
	local maxRep = top - bottom
	local curRep = earned - bottom
	local repPercent = curRep / maxRep * 100

	return (L["Standing: %s\nRep: %s/%s [%.1f%%]"]):format(
		standingText,
		commify(curRep),
		commify(maxRep),
		repPercent
	)
end

local function GetTipAnchor(frame, tooltip)
	local uiScale = UIParent:GetEffectiveScale()
	local uiWidth = UIParent:GetWidth()
	local ttWidth = tooltip:GetWidth()
	local x, y = GetCursorPosition()

	if not x or not y then
		return "TOPLEFT", "BOTTOMLEFT"
	end

	-- Always use the LEFT of the bar as the anchor
	local hhalf = "LEFT"
	local vhalf = ((y / uiScale) > UIParent:GetHeight() / 2) and "TOP" or "BOTTOM"
	local fX, fY = (x / uiScale) - (ttWidth / 2), y / uiScale

	-- OK, since :SetClampedToScreen is stupid, we will check if the tooltip goes off the screen manually.
	-- OK, if it is less than 0, it is gone off the left edge.
	if fX < 0 then
		fX = 0
	end

	-- If it is greater than the size of the screen, it is off to the right
	-- Move it back in by a few pixels.
	if (x / uiScale) + (ttWidth / 2) > uiWidth then
		fX = fX - ((x / uiScale) + (ttWidth / 2) - uiWidth)
	end

	return vhalf..hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP")..hhalf, fX, 0
end

function UI:OnInitialize()
	Bars = XPMultiBar:GetModule("Bars")
	Config = XPMultiBar:GetModule("Config")
	Data = XPMultiBar:GetModule("Data")
	Utils = XPMultiBar:GetModule("Utils")

	--@debug@
	_G["XPMultiBar"] = XPMultiBar
	XPMultiBar.Bars = Bars
	XPMultiBar.Config = Config
	XPMultiBar.Data = Data
	XPMultiBar.Utils = Utils
	XPMultiBar.UI = self
	--@end-debug@

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

	Config.RegisterDefaultReceiver(self)

	local onBarSettingsUpdated = {
		function(self, value)
			self:UpdateBarSettings()
			self:SetBars(false)
		end,
		true
	}

	local eventMap = {
		_self = self,
		bgColor = { self.SetBackgroundColor, true },
		width = { self.SetWidth, true },
		height = { self.SetHeight, true },
		scale = self.SetScale,
		font = self.SetFontOptions,
		fontsize = self.SetFontOptions,
		fontoutline = self.SetFontOptions,
		texture = self.SetTexture,
		bubbles = self.ShowBubbles,
		border = self.ShowBorder,
		textposition = self.SetTextPosition,
		autowatchrep = function(self, value)
			if value then
				self:RegisterEvent("COMBAT_TEXT_UPDATE")
			else
				self:UnregisterEvent("COMBAT_TEXT_UPDATE")
			end
		end,
		showmaxlevel = onBarSettingsUpdated,
		showrepbar = onBarSettingsUpdated,
		showazerbar = onBarSettingsUpdated,
	}

	Config.RegisterEvent(
		Config.EVENT_CONFIG_UPDATED,
		function(key, value)
			local handler = eventMap[key]
			local updateBar = false
			if handler then
				if type(handler) == "table" then
					updateBar = handler[2] or handler["update"]
					handler = handler[1]
				end
				if type(handler) ~= "function" then
					handler = eventMap._self[handler]
				end
				handler(eventMap._self, value)
			else
				updateBar = true
			end
			if updateBar then
				eventMap._self.UpdateXPBar(eventMap._self)
			end
		end
	)
end

-- XP Bar creation
function UI:CreateXPBar()
	-- Check if the bar already exists before proceeding.
	if self.frame then
		return
	end

	local db = Config.GetDB()

	-- Main Frame
	self.frame = CreateFrame("Frame", "XPMultiBarFrame", UIParent)
	self.frame:SetFrameStrata(db.general.strata)
	self.frame:SetMovable(true)
	self.frame:Hide()

	if db.general.scale then
		self.frame:SetScale(db.general.scale)
	end

	self.frame:ClearAllPoints()

	if not db.general.posx then
		self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	else
		self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.general.posx, db.general.posy)
	end

	self.frame:SetWidth(db.general.width)
	self.frame:SetHeight(db.general.height)

	self.frame:SetBackdrop({
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		edgeSize = 12,
		insets = { left = 5, right = 5, top = 5, bottom = 5, },
	})

	-- Button
	self.frame.button = CreateFrame("Button", "XPMultiBarButton", self.frame)
	self.frame.button:SetAllPoints(self.frame)
	self.frame.button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	self.frame.button:RegisterForDrag("LeftButton")
	self.frame.button:SetScript("OnClick", function(clickself, button, down)
		-- Paste currently displayed text to edit box on Shift-LeftClick
		if IsShiftKeyDown() and button == "LeftButton" then
			local activeWin = ChatEdit_GetActiveWindow()
			if not activeWin then
				activeWin = ChatEdit_GetLastActiveWindow()
				activeWin:Show()
			end
			activeWin:SetFocus()
			activeWin:Insert(self.frame.bartext:GetText())
		end

		-- Display options on Shift-RightClick
		if IsShiftKeyDown() and button == "RightButton" then
			Config.OpenSettings()
		end

		-- Display Reputation menu on Ctrl-RightClick
		if IsControlKeyDown() and button == "RightButton" then
			self:MakeReputationTooltip()
		end
	end)

	-- Movement starting
	self.frame.button:SetScript("OnDragStart", function()
		if not db.general.locked then
			self.frame:StartMoving()
		end
	end)

	-- Movement stopped
	self.frame.button:SetScript("OnDragStop", function()
		self.frame:StopMovingOrSizing()
		self:SavePosition()
	end)

	-- On mouse entering the frame.
	self.frame.button:SetScript("OnEnter", function()
		self:SetBars(true)
		self:UpdateXPBar()
	end)

	-- On mouse leaving the frame
	self.frame.button:SetScript("OnLeave", function()
		self:SetBars(false)
		self:UpdateXPBar()
	end)

	-- Background
	self.frame.background = CreateFrame("StatusBar", "XPMultiBarBackground", self.frame)
	self.frame.background:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
	self.frame.background:SetWidth(self.frame:GetWidth() - 4)
	self.frame.background:SetHeight(self.frame:GetHeight() - 8)

	-- XP Bar
	self.frame.xpbar = CreateFrame("StatusBar", "XPMultiBarXPBar", self.frame)
	self.frame.xpbar:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
	self.frame.xpbar:SetWidth(self.frame:GetWidth() - 4)
	self.frame.xpbar:SetHeight(self.frame:GetHeight() - 8)

	-- Some Elv and Tuk UI compatibility. Never used them myself.
	-- These were suggested by users.
	if IsAddOnLoaded("ElvUI") or IsAddOnLoaded("TukUI") then
		self.frame.xpbar:CreateBackdrop()
	end

	-- Remaining + Rested XP Bar
	self.frame.remaining = CreateFrame("StatusBar", "XPMultiBarRemaining", self.frame)
	self.frame.remaining:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
	self.frame.remaining:SetWidth(self.frame:GetWidth() - 4)
	self.frame.remaining:SetHeight(self.frame:GetHeight() - 8)

	-- Bubbles
	self.frame.bubbles = CreateFrame("StatusBar", "XPMultiBarBubbles", self.frame)
	self.frame.bubbles:SetStatusBarTexture("Interface\\AddOns\\XPMultiBar\\Textures\\bubbles")
	self.frame.bubbles:SetStatusBarColor(0, 0, 0, 0.5) -- Semitransparent ticks - smoother look
	self.frame.bubbles:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
	self.frame.bubbles:SetWidth(self.frame:GetWidth() - 4)
	self.frame.bubbles:SetHeight(self.frame:GetHeight() - 8)

	-- XXX: Blizz tiling breakage
	self.frame.bubbles:GetStatusBarTexture():SetHorizTile(false)

	-- XP Bar Text
	self.frame.bartext = self.frame.button:CreateFontString("XPMultiBarText", "OVERLAY")
	self:SetFontOptions(db.general)
	self.frame.bartext:SetShadowOffset(1, -1)
	self:SetTextPosition(db.general.textposition)
	self.frame.bartext:SetTextColor(1, 1, 1, 1)

	-- Set frame levels.
	self.frame:SetFrameLevel(0)
	local level = self.frame:GetFrameLevel()
	self.frame.background:SetFrameLevel(level + 1)
	self.frame.remaining:SetFrameLevel(level + 2)
	self.frame.xpbar:SetFrameLevel(level + 3)
	self.frame.bubbles:SetFrameLevel(level + 4)
	self.frame.button:SetFrameLevel(level + 5)

	self:SetTexture(db.general.texture)
	self:ShowBubbles(db.general.bubbles)
	self:SetClamp(db.general.clamptoscreen)
	self:ShowBorder(db.general.border)
	self:RestorePosition()

	-- Kill function after the bar is made.
	self.CreateXPBar = nil
end

function UI:OnEnable()
	if self.CreateXPBar then
		self:CreateXPBar()
	end

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateXPBar")

	self:RegisterEvent("PLAYER_XP_UPDATE", "UpdateXPData")
	self:RegisterEvent("PLAYER_LEVEL_UP", "LevelUp")
	self:RegisterEvent("PLAYER_UPDATE_RESTING", "UpdateXPData")
	self:RegisterEvent("UPDATE_EXHAUSTION", "UpdateXPBar")

	self:RegisterEvent("UPDATE_FACTION", "UpdateXPBar")

	self:RegisterEvent("AZERITE_ITEM_EXPERIENCE_CHANGED", "UpdateXPBar")

	local db = Config.GetDB()

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

	-- Update bars.
	self:UpdateBarSettings(db.bars)
	self:SetBars(false)

	-- Show the bar.
	self:UpdateXPData()
	self.frame:Show()
end

function UI:OnDisable()
	self.frame:Hide()
	LSM3.UnregisterAllCallbacks(self)
end

function UI:RefreshConfig(db)
	-- Receives value of new profile data
	self.frame:SetFrameStrata(db.general.strata)
	self.frame:SetScale(db.general.scale)
	self:SetWidth(db.general.width)
	self:SetHeight(db.general.height)
	self:ShowBorder(db.general.border)
	self:SetFontOptions(db.general)
	self:SetTextPosition(db.general.textposition)
	self:SetTexture(db.general.texture)
	self:ShowBubbles(db.general.bubbles)
	self:SetClamp(db.general.clamptoscreen)
	self:RestorePosition()
	self:UpdateBarSettings(db.bars)
	self:SetBars(false)
	self:UpdateXPBar()
end

function UI:SetFontOptions(general)
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

	self.frame.bartext:SetFont(font, general.fontsize, flags)
end

function UI:UpdateBarSettings(bars)
	if type(bars) ~= "table" then
		bars = Config.GetDB().bars
	end
	Bars.UpdateBarSettings(bars.showmaxlevel, bars.showrepbar, bars.showazerbar)
end

function UI:SetBars(isMouseOver, playerLevel)
	Bars.UpdateBarState(
		HasActiveAzeriteItem(),
		isPlayerMaxLevel(playerLevel),
		isMouseOver,
		IsAltKeyDown(),
		IsShiftKeyDown() or IsControlKeyDown()
	)
end

function UI:SetTextPosition(percent)
	local db = Config.GetDB()
	local width = db.general.width
	local posx = math_floor(((width / 100) * percent) - (width / 2))

	self.frame.bartext:ClearAllPoints()
	self.frame.bartext:SetPoint("CENTER", self.frame, "CENTER", posx or 0, 0)
end

function UI:SetTexture(texture)
	local texturePath = LSM3:Fetch("statusbar", texture)
	Utils.ForEach(
		{self.frame.background, self.frame.remaining, self.frame.xpbar},
		function(bar)
			bar:SetStatusBarTexture(texturePath)
			bar:GetStatusBarTexture():SetHorizTile(false)
		end
	)
	local db = Config.GetDB()
	local bgColor = db.bars.background
	self.frame.background:SetStatusBarColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
end

function UI:SetBackgroundColor(color)
	self.frame.background:SetStatusBarColor(color.r, color.g, color.b, color.a)
end

function UI:SetWidth(width)
	self.frame:SetWidth(width)
	Utils.ForEach(
		{
			self.frame.button, self.frame.background, self.frame.remaining,
			self.frame.xpbar, self.frame.bubbles
		},
		function(frame)
			frame:SetWidth(width - 4)
		end
	)
end

function UI:SetHeight(height)
	self.frame:SetHeight(height)
	Utils.ForEach(
		{
			self.frame.background, self.frame.remaining,
			self.frame.xpbar, self.frame.bubbles
		},
		function(frame)
			frame:SetHeight(height - 8)
		end
	)
end

function UI:SetScale(scale)
	self:SavePosition()
	self.frame:SetScale(scale)
	self:RestorePosition()
end

function UI:ShowBorder(value)
	if value then
		self.frame:SetBackdropBorderColor(1, 1, 1, 1)
	else
		self.frame:SetBackdropBorderColor(0, 0, 0, 0)
	end
end

function UI:ShowBubbles(value)
	if value == nil then
		local db = Config.GetDB()
		value = db.general.bubbles
	end
	if value then
		self.frame.bubbles:Show()
	else
		self.frame.bubbles:Hide()
	end
end

function UI:SetClamp(value)
	self.frame:SetClampedToScreen(value)
end

-- Tooltips for the reputation menu
function UI:SetTooltip(tip)
	GameTooltip_SetDefaultAnchor(GameTooltip, WorldFrame)
	GameTooltip:SetText(tip[1], 1, 1, 1)
	GameTooltip:AddLine(tip[2])
	GameTooltip:Show()
end

function UI:HideTooltip()
	GameTooltip:FadeOut()
end

function UI:ToggleCollapse(args)
	local tooltip, factionIndex, name, hasRep, isCollapsed = unpack(args)

	if hasRep and GetMouseButtonClicked() == "RightButton" then
		SetWatchedFactionByName(name)
	else
		if isCollapsed then
			ExpandFactionHeader(factionIndex)
		else
			CollapseFactionHeader(factionIndex)
		end
	end

	tooltip:UpdateScrolling()
end

function UI:SetWatchedFactionIndex(faction)
	SetWatchedFactionIndex(faction)
end

-- LSM3 Updates.
function UI:MediaUpdate()
end

-- Check for faction updates for the automatic reputation watching
function UI:COMBAT_TEXT_UPDATE(event, msgtype)
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
function UI:PET_BATTLE_OPENING_START()
	self.frame:Hide()
end

function UI:PET_BATTLE_CLOSE()
	self.frame:Show()
end

-- Update XP bar data
function UI:UpdateXPData()
	Data.UpdateXP(UnitXP("player"), UnitXPMax("player"))
	self:UpdateXPBar()
end

function UI:UpdateReputationData()
	local db = Config.GetDB()

	local repName, repStanding, repMin, repMax, repValue, factionID = GetWatchedFactionInfo()
	local isFactionParagon = IsFactionParagon(factionID)

	local txtcol = db.bars.reptext
	self.frame.bartext:SetTextColor(txtcol.r, txtcol.g, txtcol.b, txtcol.a)

	if repName == nil then
		if self.frame.xpbar:IsVisible() then
			self.frame.xpbar:Hide()
		end
		self.frame.bartext:SetText(L["You need to select a faction to watch."])
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
		hasBonusRep,canBeLFGBonus = select(15, GetFactionInfoByID(factionID))
		-- Check faction with Exalted standing to have paragon reputation.
		-- If so, adjust values to show bar to next paragon bonus.
		if repStanding == Config.STANDING_EXALTED then
			if isFactionParagon then
				local parValue, parThresh = GetFactionParagonInfo(factionID)
				-- parValue is cumulative. We need to get modulo by the current threshold.
				repMax = parThresh
				repValue = parValue % parThresh
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

	if not self.frame.xpbar:IsVisible() then
		self.frame.xpbar:Show()
	end

	self.frame.remaining:Hide()
	self.frame.xpbar:SetMinMaxValues(math_min(0, repValue), repMax)
	self.frame.xpbar:SetValue(repValue)

	-- Use our own color for exalted.
	local repColor
	if repStanding == Config.STANDING_EXALTED then
		repColor = db.bars.exalted
	else
		repColor = FACTION_BAR_COLORS[repStanding]
	end

	self.frame.xpbar:SetStatusBarColor(repColor.r, repColor.g, repColor.b, repColor.a)

	self.frame.bartext:SetText(
		GetReputationText( {
			repName, repStanding, repMin, repMax,
			repValue, friendID, friendTextLevel,
			hasBonusRep, canBeLFGBonus, isFactionParagon
		} )
	)
end

function UI:UpdateXPBar()
	-- If the menu is open and we are in here, refresh the menu.
	if LQT:IsAcquired("XPMultiBarTT") then
		self:DrawReputationMenu()
	end

	local db = Config.GetDB()
	local bar = Bars.GetVisibleBar()

	if bar == Bars.REP then
		self:UpdateReputationData()
		return
	else
		if not self.frame.xpbar:IsVisible() then
			self.frame.xpbar:Show()
		end
	end

	local xpText, currXP, maxXP, barColor

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
		if self.frame.remaining:IsVisible() then
			self.frame.remaining:Hide()
		end
	else -- if bar == Bars.XP
		local xp, restedXP = Data.GetXP(), GetXPExhaustion() or 0 -- GetXPExhaustion() returns nil when no bonus present and 0 on max level
		currXP, maxXP = xp.curr, xp.max
		if restedXP == 0 then
			if self.frame.remaining:IsVisible() then
				self.frame.remaining:Hide()
			end
			barColor = db.bars.normal
		else
			self.frame.remaining:SetMinMaxValues(math_min(0, currXP), maxXP)
			self.frame.remaining:SetValue(currXP + restedXP)

			local remaining = db.bars.remaining
			self.frame.remaining:SetStatusBarColor(remaining.r, remaining.g, remaining.b, remaining.a)

			-- Do we want to indicate rest?
			if IsResting() and db.bars.indicaterest then
				barColor = db.bars.resting
			else
				barColor = db.bars.rested
			end

			if db.bars.showremaining then
				self.frame.remaining:Show()
			else
				self.frame.remaining:Hide()
			end
		end

		xpText = GetXPText(xp.curr, xp.max, xp.rem, restedXP)
	end

	self.frame.xpbar:SetMinMaxValues(math_min(0, currXP), maxXP)
	self.frame.xpbar:SetValue(currXP)
	self.frame.xpbar:SetStatusBarColor(barColor.r, barColor.g, barColor.b, barColor.a)

	-- Set the color of the bar text
	local txtcol = db.bars.xptext

	self.frame.bartext:SetTextColor(txtcol.r, txtcol.g, txtcol.b, txtcol.a)
	self.frame.bartext:SetText(xpText)
end

function UI:LevelUp(event, level)
	self:SetBars(false, level)
	self:UpdateXPBar()
end

function UI:MakeReputationTooltip()
	if not LQT:IsAcquired("XPMultiBarTT") then
		repTooltip = LQT:Acquire("XPMultiBarTT", 2, "CENTER", "LEFT")
	end

	local db = Config.GetDB()

	repTooltip:SetClampedToScreen(true)
	repTooltip:SetScale(db.repmenu.scale)

	-- Anchor to the cursor position along the bar.
	repTooltip:ClearAllPoints()
	repTooltip:SetPoint(GetTipAnchor(self.frame.button, repTooltip))
	repTooltip:SetAutoHideDelay(db.repmenu.autohidedelay, self.frame.button)
	repTooltip:EnableMouse()

	self:DrawReputationMenu()
end

function UI:DrawReputationMenu()
	local linenum = nil
	local checkIcon = "|TInterface\\Buttons\\UI-CheckBox-Check:16:16:1:-1|t"
	local normalFont = repTooltip:GetFont()

	repTooltip:Hide()
	repTooltip:Clear()

	for faction = 1, GetNumFactions() do
		local name, _, standing, bottom, top, earned, atWar, _, isHeader, isCollapsed,
				hasRep, isWatched, isChild, repID, hasBonusRep, canBeLFGBonus = GetFactionInfo(faction)

		-- Set these to previous max values for exalted. Legion changed how exalted works.
		if standing == Config.STANDING_EXALTED then
			bottom = 0
			top = 1000
			earned = 999
		end

		if not isHeader then
			local friendID, friendRep, friendMaxRep, friendName, _, _, friendTextLevel, friendThresh, friendThreshNext = GetFriendshipReputation(repID)
			local isFactionParagon = IsFactionParagon(repID)

			-- Faction
			local standingText
			if friendID then
				standingText = friendTextLevel
				bottom = 0
				earned = friendRep - friendThresh

				if friendThreshNext then
					-- Not "Exalted", use provided figure for next level.
					top = friendThreshNext
				else
					-- "Exalted". Fake exalted max.
					top = friendMaxRep + 1
					earned = 1
				end

				top = top - friendThresh
			else
				if hasBonusRep or isFactionParagon then
					standingText = ("%s+"):format(Config.GetFactionStandingLabel(standing))
				else
					standingText = Config.GetFactionStandingLabel(standing)
				end
			end

			-- Paragon reputation values
			if isFactionParagon then
				local parValue, parThresh = GetFactionParagonInfo(repID)
				bottom = 0
				top = parThresh
				earned = parValue % parThresh
			end

			-- Legion introduced a bug where you can be shown a
			-- completely blank rep, so only add menu entries for
			-- things with a name.
			if name then
				local tipText = GetReputationTooltipText(standingText, bottom, top, earned)

				linenum = repTooltip:AddLine(nil)
				repTooltip:SetCell(linenum, 1, isWatched and checkIcon or " ", normalFont)
				repTooltip:SetCell(linenum, 2, ("|cff%s%s (%s)|r"):format(Config.GetRepHexColor(standing), name, standingText), GameTooltipTextSmall)
				repTooltip:SetLineScript(linenum, "OnMouseUp", UI.SetWatchedFactionIndex, faction)
				repTooltip:SetLineScript(linenum, "OnEnter", UI.SetTooltip, {name,tipText})
				repTooltip:SetLineScript(linenum, "OnLeave", UI.HideTooltip)
			end
		else
			-- Header
			local tipText, iconPath
			if isCollapsed then
				tipText = (L["Click to expand %s faction listing"]):format(name)
				iconPath = "|TInterface\\Buttons\\UI-PlusButton-Up:16:16:1:-1|t"
			else
				tipText = (L["Click to collapse %s faction listing"]):format(name)
				iconPath = "|TInterface\\Buttons\\UI-MinusButton-Up:16:16:1:-1|t"
			end

			--linenum = tooltip:AddLine(iconPath, name)
			linenum = repTooltip:AddLine(nil)
			repTooltip:SetCell(linenum, 1, iconPath, normalFont)

			-- If this header also has rep, then change the header slightly
			-- and fix the tooltip.
			if hasRep then
				local standingText
				if hasBonusRep then
					standingText = ("%s+"):format(Config.GetFactionStandingLabel(standing))
				else
					standingText = Config.GetFactionStandingLabel(standing)
				end

				repTooltip:SetCell(linenum, 2, ("%s (%s)"):format(name, standingText), normalFont)
				tipText = ("%s|n%s|n%s"):format(
					GetReputationTooltipText(standingText, bottom, top, earned),
					tipText,
					L["Right click to watch faction"]
				)
			else
				repTooltip:SetCell(linenum, 2, name, normalFont)
			end
			repTooltip:SetLineScript(linenum, "OnMouseUp", UI.ToggleCollapse, {repTooltip,faction,name,hasRep,isCollapsed})
			repTooltip:SetLineScript(linenum, "OnEnter", UI.SetTooltip, {name,tipText})
			repTooltip:SetLineScript(linenum, "OnLeave", UI.HideTooltip)
		end
	end

	repTooltip:UpdateScrolling()
	repTooltip:Show()
end

-- Bar positioning.
function UI:SavePosition()
	local x, y = self.frame:GetLeft(), self.frame:GetTop()
	local s = self.frame:GetEffectiveScale()
	local db = Config.GetDB()

	x, y = x*s, y*s

	db.general.posx = x
	db.general.posy = y
end

function UI:RestorePosition()
	local db = Config.GetDB()
	local x = db.general.posx
	local y = db.general.posy

	if not x or not y then
		return
	end

	local s = self.frame:GetEffectiveScale()

	x, y = x/s, y/s

	self.frame:ClearAllPoints()
	self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
end
