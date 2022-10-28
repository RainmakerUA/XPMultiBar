--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_Reputation.lua - module
		Reputation module for XPMultiBar addon
--]=====]

local addonName = ...
local Utils = LibStub("rmUtils-1.1")
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Reputation = XPMultiBar:NewModule("Reputation")

local LibQT = LibStub("LibQTip-1.0")

local wowClassic = Utils.IsWoWClassic
local R = Reputation

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local Config
local UI

local emptyFun = Utils.EmptyFn

local ipairs = ipairs
local next = next
local pairs = pairs
local select = select
local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring
local type = type
local unpack = unpack
local math_abs = math.abs
local math_floor = math.floor
local tinsert = table.insert

local _G = _G
local FACTION_ALLIANCE = FACTION_ALLIANCE
local FACTION_BAR_COLORS = FACTION_BAR_COLORS
local FACTION_HORDE = FACTION_HORDE
local GUILD = GUILD
local RED_FONT_COLOR = RED_FONT_COLOR
local SOUNDKIT = SOUNDKIT
local GameTooltip = GameTooltip
local GameTooltipTextSmall = GameTooltipTextSmall
local UIParent = UIParent
local WorldFrame = WorldFrame

local hooksecurefunc = hooksecurefunc
local CollapseFactionHeader = CollapseFactionHeader
local CreateColor = CreateColor
local CreateFramePool = CreateFramePool
local ExpandFactionHeader = ExpandFactionHeader
local GameTooltip_AddColoredLine = GameTooltip_AddColoredLine
local GameTooltip_AddErrorLine = GameTooltip_AddErrorLine
local GameTooltip_AddInstructionLine = GameTooltip_AddInstructionLine
local GameTooltip_AddNormalLine = GameTooltip_AddNormalLine
local GameTooltip_InsertFrame = GameTooltip_InsertFrame
local GameTooltip_SetDefaultAnchor = GameTooltip_SetDefaultAnchor
local GameTooltip_SetTitle = GameTooltip_SetTitle
local GetCursorPosition = GetCursorPosition
local GetFactionInfo = GetFactionInfo
local GetFactionInfoByID = GetFactionInfoByID
local GetGuildInfo = GetGuildInfo
local GetNumFactions = GetNumFactions
local GetSelectedFaction = GetSelectedFaction
local GetWatchedFactionInfo = GetWatchedFactionInfo
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local PlaySound = PlaySound
local SetWatchedFactionIndex = SetWatchedFactionIndex

local GetFactionParagonInfo = emptyFun
local IsFactionParagon = emptyFun
local GetFriendshipReputation = GetFriendshipReputation or emptyFun

local ReputationBarMixin = ReputationBarMixin

if not wowClassic then
	GetFactionParagonInfo = C_Reputation.GetFactionParagonInfo
	IsFactionParagon = C_Reputation.IsFactionParagon
end

-- Remove all known globals after this point
-- luacheck: std none

-- luacheck: push globals ReputationTooltipStatusBarMixin ReputationDetailFavoriteFactionCheckBoxMixin ReputationTooltipStatusBarBorderMixin
ReputationTooltipStatusBarMixin = {}
ReputationDetailFavoriteFactionCheckBoxMixin = {}
ReputationTooltipStatusBarBorderMixin = {}

local rb = ReputationTooltipStatusBarMixin
local fav = ReputationDetailFavoriteFactionCheckBoxMixin
local bx = ReputationTooltipStatusBarBorderMixin
-- luacheck: pop

-- luacheck: push globals ReputationDetailFrame
local repDetailFrame = ReputationDetailFrame
-- luacheck: pop
-- luacheck: push globals ReputationDetailMainScreenCheckBox ReputationDetailLFGBonusReputationCheckBox
local watchedCheckbox = ReputationDetailMainScreenCheckBox
local lfgBonusRepCheckbox = ReputationDetailLFGBonusReputationCheckBox
-- luacheck: pop

--[[ Common local functions ]]

if type(GameTooltip_AddErrorLine) ~= "function" then
	-- Function is absent in Classic
	GameTooltip_AddErrorLine = function(tooltip, text, wrap)
		return GameTooltip_AddColoredLine(tooltip, text, RED_FONT_COLOR, wrap)
	end
end

local function GetColorRGBA(color)
	return color.r or 0, color.g or 0, color.b or 0, color.a or 1
end

local function CreateColorMixin(color)
	return CreateColor(GetColorRGBA(color))
end

local function GetErrorText(text)
	return RED_FONT_COLOR:WrapTextInColorCode(text)
end

local function unpackIndices(table, ...)
	local tableToUnpack = {}
	local indices = {...}

	for _, index in ipairs(indices) do
		tinsert(tableToUnpack, table[index])
	end

	return unpack(tableToUnpack)
end

--[[ Border methods ]]

function bx:OnLoad()
	self:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 10,
		insets = { left = 5, right = 5, top = 5, bottom = 5 },
	})
end

--[[ Favorite Checkbox methods ]]

function fav:OnLoad()
	_G[self:GetName() .. "Text"]:SetText(L["Favorite faction"])
	self:Hide()
	R.favoriteCheckbox = self
end

function fav:OnClick()
	local checked = self:GetChecked()
	PlaySound(checked
				and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
				or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
			)
	self:SetFactionFavorite(self.factionID, checked)
end

function fav:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetText(L["Choose faction to show in favorites list"], nil, nil, nil, nil, true);
end

function fav:SetFactionFavorite(factionID, isFavorite)
	local favorites = Config.GetDB().reputation.favorites
	favorites[factionID] = isFavorite and true or nil
end

--[[ Rep StatusBar methods ]]

function rb:OnLoad()
	self.status = self.statusFrame.status
	self.border = self.statusFrame.border
	self.leftText = self.statusFrame.border.leftText
	self.rightText = self.statusFrame.border.rightText
end

function rb:AfterInsert(tooltip, reservedHeight)
	local _, relative = self:GetPoint(1)
	self:SetPoint("TOPLEFT", relative, "TOPLEFT", 0, 0)
	self:SetPoint("RIGHT", tooltip, "RIGHT", -10, 0)
	self:Show()
end

function rb:SetHeader(text)
	self.header:SetText(text)
end

function rb:SetStatusBarValues(min, max, current)
	self.status:SetMinMaxValues(min, max)
	self.status:SetValue(current)
end

function rb:SetStatusBarColor(color)
	local r, g, b, a = GetColorRGBA(color)
	self.status:SetStatusBarColor(r, g, b, a)
	self.border:SetBackdropBorderColor(r, g, b, a)
end

function rb:SetStatusBarTexts(leftText, rightText)
	self.leftText:SetText(leftText)
	self.rightText:SetText(rightText)
end

function rb:SetError(text)
	self:SetHeader(GetErrorText(text))
	self:SetStatusBarValues(0, 1, 1)
	self:SetStatusBarColor(RED_FONT_COLOR)
	self:SetStatusBarTexts("", "")
end

--[[ Module methods ]]

local function UpdateFavoriteCheckbox(checkbox)
	local config = Config.GetDB().reputation
	local factionID = select(14, GetFactionInfo(GetSelectedFaction()))
	if config.showFavorites and repDetailFrame:IsShown() then
		local hasLfgCheckbox = lfgBonusRepCheckbox and lfgBonusRepCheckbox:IsShown()
		local relCheckbox = hasLfgCheckbox and lfgBonusRepCheckbox or watchedCheckbox
		repDetailFrame:SetHeight(hasLfgCheckbox and 247 or 225)
		checkbox.factionID = factionID
		if wowClassic then
			checkbox:SetPoint("BOTTOMLEFT", repDetailFrame, "BOTTOMLEFT", 14, 56)
		else
			checkbox:SetPoint("TOPLEFT", relCheckbox, "BOTTOMLEFT", 0, 3)
		end
		checkbox:SetChecked(config.favorites[factionID] or false)
		checkbox:Show()
	else
		checkbox:ClearAllPoints()
		checkbox:Hide()
	end
end

function R:OnInitialize()
	Config = XPMultiBar:GetModule("Config")
	UI = XPMultiBar:GetModule("UI")

	-- Patch LibQTip
	local labelProto = LibQT.LabelPrototype
	local oldMethod = labelProto.InitializeCell

	labelProto.InitializeCell = function(proto, ...)
		local result = oldMethod(proto, ...)
		proto.fontString:SetWordWrap(false)
		return result
	end

	local favCheckbox = self.favoriteCheckbox

	if wowClassic then
		-- Secure hook ReputationFrame_Update
		hooksecurefunc("ReputationFrame_Update", function()
			UpdateFavoriteCheckbox(favCheckbox)
		end)
	else
		repDetailFrame:HookScript("OnSizeChanged", function(frame, width, height)
			local neededHeight = lfgBonusRepCheckbox and lfgBonusRepCheckbox:IsShown() and 247 or 225
			if math_abs(height - neededHeight) > 0.1 then
				frame:SetHeight(neededHeight)
			end
		end)

		local oldOnClick = ReputationBarMixin.OnClick
		ReputationBarMixin.OnClick = function(...)
			local result = oldOnClick(...)
			UpdateFavoriteCheckbox(favCheckbox)
			return result
		end
	end
end

function R:OnEnable()
end

function R:OnDisable()
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

local repMenuTooltipKey = addonName .. "RepMenuTT"
local repMenu

local tags = {
	minus = [[|TInterface\Buttons\UI-MinusButton-Up:16:16:1:-1|t]],
	plus = [[|TInterface\Buttons\UI-PlusButton-Up:16:16:1:-1|t]],
	lfgBonus = [[|TInterface\Common\ReputationStar:12:12:0:0:32:32:0:15:0:15|t]],
	repBonus = [[|TInterface\Common\ReputationStar:12:12:0:0:32:32:16:31:16:31|t]],
	atWar = [[|TInterface\WorldStateFrame\CombatSwords:16:16:0:0:32:32:0:15:0:15|t]],
	paragon = [[|A:ParagonReputation_Bag:12:10:0:0|a]],
	paragonReward = [[|A:ParagonReputation_Bag:12:10:0:0|a|A:ParagonReputation_Checkmark:10:10:-10:0|a]],
}

local instructions = {
	collapse = L["Right Button click to collapse %1$s factions"],
	expand = L["Right Button click to expand %1$s factions"],
	watch = L["Click to watch %1$s reputation"],
	unwatch = L["Click to stop watching %1$s reputation"],
	favorite = L["Ctrl+Click to add %1$s to favorite factions"],
	unfavorite = L["Ctrl+Click to remove %1$s from favorite factions"],
}

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

local function ClearFrame(pool, frame)
	frame:Hide()
	frame:ClearAllPoints()
	frame:SetParent(nil)
end

local function IsFactionMenuShown()
	return LibQT:IsAcquired(repMenuTooltipKey)
end

local function AcquireRepMenuTooltip(frame, repConfig)
	repMenu = LibQT:Acquire(repMenuTooltipKey, 5)
	repMenu:SetClampedToScreen(true)
	repMenu:SetScale(repConfig.menuScale)
	repMenu:ClearAllPoints()

	repMenu:SetAutoHideDelay(repConfig.menuAutoHideDelay, frame)
	repMenu:EnableMouse()

	return repMenu
end

local function GetFactionIcons(hasBonusRep, isLFGBonus, isFactionParagon, hasParagonReward, isAtWar)
	local icons = ""

	if isAtWar then
		icons = icons .. tags.atWar
	end
	if isLFGBonus then
		icons = icons .. tags.lfgBonus
	end
	if hasBonusRep then
		icons = icons .. tags.repBonus
	end
	if isFactionParagon then
		icons = icons .. (hasParagonReward and tags.paragonReward or tags.paragon)
	end

	return icons
end

local function GetReputationFrame(faction, showHeader, commifyNumbers)
	local frameHeights = { 20, 36 }

	if not R.framePool then
		R.framePool = CreateFramePool("FRAME", nil, "ReputationTooltipStatusBar", ClearFrame)
	end

	if type(faction) == "number" then
		faction = { GetFactionReputationData(faction) }
	end

	local _, name, _, standingName, color, min, max, current,
			hasBonusRep, isLFGBonus, isFactionParagon, hasParagonReward, isAtWar = unpack(faction)
	local frame = R.framePool:Acquire()
	local commify = commifyNumbers and Utils.Commify or tostring

	frame:Hide()

	if name then
		if showHeader == 2 then
			name = name .. "\32" .. GetFactionIcons(hasBonusRep, isLFGBonus, isFactionParagon, hasParagonReward, isAtWar)
		end

		frame:SetHeader(name)
		frame:SetStatusBarValues(min, max, current)
		frame:SetStatusBarColor(color)
		frame:SetStatusBarTexts(standingName, ("%s/%s"):format(commify(current or 0), commify(max or 0)))
	else
		frame:SetError(L["Faction error!"])
	end

	if showHeader > 0 then
		frame.header:Show()
		frame:SetHeight(frameHeights[2])
	else
		frame.header:Hide()
		frame:SetHeight(frameHeights[1])
	end

	return frame
end

local function ReleaseFrames()
	if R.framePool then
		R.framePool:ReleaseAll()
	end
end

local function ClickMenuItem(_, faction, button)
	local factionIndex, factionID, isCollapsed, isHeader, hasRep
			= faction.index, faction.id, faction.isCollapsed, faction.isHeader, faction.hasRep
	local isWatched, isFavorite = faction.isWatched, faction.isFavorite
	local menu = faction.menu
	local isAlt, isCtrl, isShift = IsAltKeyDown(), IsControlKeyDown(), IsShiftKeyDown()

	if button == "RightButton" and isHeader then
		local func = isCollapsed and ExpandFactionHeader or CollapseFactionHeader
		func(factionIndex)
		menu:UpdateScrolling()
	elseif not isHeader or hasRep then
		if button == "MiddleButton" or button == "LeftButton" and isCtrl then
			fav:SetFactionFavorite(factionID, not isFavorite)
			R:ShowFactionMenu(true)
			if R.favoriteCheckbox and R.favoriteCheckbox.factionID == factionID then
				R.favoriteCheckbox:SetChecked(not isFavorite)
			end
		elseif button == "LeftButton" then
			SetWatchedFactionIndex(isWatched and 0 or factionIndex)
		end
	end
end

local function ShowMenuItemTooltip(line, tip)
	GameTooltip:SetMinimumWidth(250, true)
	GameTooltip_SetDefaultAnchor(GameTooltip, WorldFrame)
	GameTooltip_SetTitle(GameTooltip, tip.name)

	if tip.desc then
		GameTooltip_AddNormalLine(GameTooltip, tip.desc)
	end

	local isHeader, hasRep = unpack(tip.faction, 14, 15)

	if not isHeader or hasRep then
		local commify = Config.GetDB().general.commify
		local repStatus = GetReputationFrame(tip.faction, 0, commify)
		local height = GameTooltip_InsertFrame(GameTooltip, repStatus)
		repStatus:AfterInsert(GameTooltip, height)
	end

	if tip.instruction then
		GameTooltip_AddInstructionLine(GameTooltip, tip.instruction)
	end

	GameTooltip:Show()
end

local function HideMenuItemTooltip()
	GameTooltip:Hide()
	GameTooltip:SetMinimumWidth(0, false)
	ReleaseFrames()
end

local function FillReputationMenu(config)
	local normalFont = repMenu:GetFont()
	local smallFont = GameTooltipTextSmall
	local isUnderChildHeader = false
	local lineNum

	repMenu:Hide()
	repMenu:Clear()

	for factionNum = 1, GetNumFactions() do
		-- GetFactionInfo returns only 10 values for 'Other'/'Inactive' headers so factionID is nil
		-- Use original values
		-- name, description, standingID, barMin, barMax, barValue, atWarWith,
		-- canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild,
		-- factionID, hasBonusRepGain, canBeLFGBonus = GetFactionInfo(factionIndex)
		local factionID, repName, repStanding, repStandingText, repStandingColor,
				repMin, repMax, repValue, hasBonusRep, isLFGBonus,
				isFactionParagon, hasParagonReward, isAtWar,
				isHeader, hasRep, isCollapsed, isChild, isWatched, repDesc
		local factionInfo = { GetFactionInfo(factionNum) }

		repName, isHeader, isCollapsed, isChild, factionID = unpackIndices(factionInfo, 1, 9, 10, 13, 14)

		if factionID then
			factionInfo = { GetFactionReputationData(factionID) }
			factionID, repName, repStanding, repStandingText, repStandingColor,
				repMin, repMax, repValue, hasBonusRep, isLFGBonus,
				isFactionParagon, hasParagonReward, isAtWar,
				isHeader, hasRep, isCollapsed, isChild, isWatched, repDesc = unpack(factionInfo)
		else
			factionInfo = {
							nil, repName, 1, nil, nil, 0, 1, 1,
							false, false, false, false, false,
							isHeader, false, isCollapsed, false, false, nil
						}
		end

		local icons = config.showIcons
						and GetFactionIcons(hasBonusRep, isLFGBonus, isFactionParagon, hasParagonReward, isAtWar)
						or ""
		local isFavorite = factionID and config.favorites[factionID]
		local instruction
		--[[
			Menu columns:
			I	II		III		IV		V
			[-]	Header text		stand.	icons
				Fraction name	stand.	icons
				[-]		Head	stand.	icons
						Fract.	stand.	icons
		]]
		if isHeader then
			local columnForTag, columnForName, nameColumnSpan = 1, 2, 4
			local tag = isCollapsed and tags.plus or tags.minus
			instruction = isCollapsed and instructions.expand or instructions.collapse
			isUnderChildHeader = isChild

			if isChild then
				columnForTag, columnForName, nameColumnSpan = 2, 3, 3
			end

			if hasRep then
				nameColumnSpan = nameColumnSpan - 2
				if config.showFavorites then
					instruction = (isFavorite and instructions.unfavorite or instructions.favorite)
									.. "|n" .. instruction
				end
				instruction = (isWatched and instructions.unwatch or instructions.watch) .. "|n" .. instruction
			end

			lineNum = repMenu:AddLine()
			repMenu:SetCell(lineNum, columnForTag, tag, normalFont)
			repMenu:SetCell(lineNum, columnForName, repName, normalFont, nameColumnSpan, nil, nil, nil, 160)

			if hasRep then
				repMenu:SetCell(lineNum, 4, repStandingColor:WrapTextInColorCode(repStandingText), normalFont)

				if icons then
					repMenu:SetCell(lineNum, 5, icons, normalFont)
				end
			end
		else
			local columnForName, nameColumnSpan = 2, 2
			instruction = (isWatched and instructions.unwatch or instructions.watch)

			if config.showFavorites then
				instruction = instruction .. "|n"
									.. (isFavorite and instructions.unfavorite or instructions.favorite)
			end

			if isUnderChildHeader then
				columnForName, nameColumnSpan = 3, 1
			end

			lineNum = repMenu:AddLine()
			repMenu:SetCell(
						lineNum, columnForName,
						repStandingColor:WrapTextInColorCode(repName),
						smallFont, nameColumnSpan, nil, nil, nil, 160
					)
			repMenu:SetCell(lineNum, 4, repStandingColor:WrapTextInColorCode(repStandingText), smallFont)

			if icons then
				repMenu:SetCell(lineNum, 5, icons, normalFont)
			end
		end

		if isWatched then
			repMenu:SetLineColor(lineNum, GetColorRGBA(config.watchedFactionLineColor))
		elseif config.showFavorites and isFavorite then
			repMenu:SetLineColor(lineNum, GetColorRGBA(config.favoriteFactionLineColor))
		end

		local onEnterArgs = {
			faction = factionInfo,
			name = repName .. "\32" .. icons,
			desc = repDesc,
			instruction = instruction:format(repName),
		}

		repMenu:SetLineScript(
							lineNum, "OnMouseUp", ClickMenuItem,
							{
								id = factionID,
								index = factionNum,
								isCollapsed = isCollapsed,
								isHeader = isHeader,
								hasRep = hasRep,
								isFavorite = isFavorite,
								isWatched = isWatched,
								name = repName,
								menu = repMenu,
							}
						)
		repMenu:SetLineScript(lineNum, "OnEnter", ShowMenuItemTooltip, onEnterArgs)
		repMenu:SetLineScript(lineNum, "OnLeave", HideMenuItemTooltip)
	end
end

local function AttachReputationMenu(bar, menu, scale)
	local x, _ = GetCursorPosition()

	if x then
		local widthExtra = 30 -- extra (scroller?) width not accounted in menu:GetWidth()
		local uiScale = UIParent:GetEffectiveScale()
		local uiWidth, uiHeight = UIParent:GetWidth(), UIParent:GetHeight()
		local barX, barY = bar:GetLeft(), bar:GetTop()
		local menuWidth = menu:GetWidth()
		local anchorX, anchorY = (x / uiScale - barX) / scale, 0 / scale
		local anchorH, anchorV = (x / uiScale + menuWidth + widthExtra > uiWidth) and "RIGHT" or "LEFT",
									(barY > uiHeight / 2) and "TOP" or "BOTTOM"
		local anchorRelH, anchorRelV = "LEFT", anchorV == "BOTTOM" and "TOP" or "BOTTOM"
		menu:SetPoint(anchorV .. anchorH, bar, anchorRelV .. anchorRelH, anchorX, anchorY)
	else
		menu:SetPoint("LEFT", UIParent, "CENTER", 0, 0)
	end
end

local function ShowFactionMenu(acquire)
	local db = Config.GetDB()
	if acquire then
		AcquireRepMenuTooltip(UI.barFrame, db.reputation)
	end
	FillReputationMenu(Utils.Merge({ showIcons = db.bars.repicons }, db.reputation))
	if acquire then
		AttachReputationMenu(UI.barFrame, repMenu, db.reputation.menuScale)
	end
	repMenu:UpdateScrolling()
	repMenu:Show()
end

function R:SetExaltedColor(color)
	color.a = 1
	reputationColors[STANDING_EXALTED] = CreateColorMixin(color)
end

function R:ToggleBarTooltip(visibility)
	if visibility and not IsFactionMenuShown() then
		local db = Config.GetDB()
		local bar = UI.barFrame
		local factions = db.reputation.favorites
		local commify = db.general.commify

		GameTooltip:SetMinimumWidth(250, true)
		GameTooltip:SetOwner(bar, "ANCHOR_NONE")

		GameTooltip_SetTitle(GameTooltip, L["Favorite Factions"])

		if not factions or next(factions) == nil then
			GameTooltip_AddErrorLine(GameTooltip, L["No favorite factions selected"], true)
			GameTooltip_AddInstructionLine(GameTooltip, L["Add some favorite factions"], true)
		end

		for k, v in pairs(factions) do
			if v then
				local showHeader = db.bars.repicons and 2 or 1
				local repFrame = GetReputationFrame(k, showHeader, commify)
				local fullHeight = GameTooltip_InsertFrame(GameTooltip, repFrame)
				repFrame:AfterInsert(GameTooltip, fullHeight)
			end
		end

		local ttWidth = GameTooltip:GetWidth()
		local uiScale = UIParent:GetEffectiveScale()
		local x, _ = GetCursorPosition()
		local left, right, halfWidth = bar:GetLeft(), bar:GetRight(), ttWidth / 2
		local side, offX = "LEFT", halfWidth
		if x / uiScale > right - halfWidth then
			side, offX = "RIGHT", -halfWidth
		elseif x / uiScale > left + halfWidth then
			offX = x / uiScale - left
		end
		GameTooltip:SetPoint("BOTTOM", bar, "TOP" .. side, offX, 5)
		GameTooltip:Show()
	elseif GameTooltip:IsShown() then
		GameTooltip:Hide()
		GameTooltip:SetMinimumWidth(0, false)
		ReleaseFrames()
	end
end

function R:GetWatchedFactionData()
	local watchedFactionInfo = { GetWatchedFactionInfo() }
	if not watchedFactionInfo[1] then
		-- watched faction name == nil - watched faction not set
		return nil
	else
		return GetFactionReputationData(watchedFactionInfo[6])
	end
end

function R:GetFactionData(factionID)
	if not factionID then
		return nil
	else
		return GetFactionReputationData(factionID)
	end
end

function R:SetWatchedFaction(factionName, amount, autotrackGuild)
	return SetWatchedFactionByName(factionName, amount, autotrackGuild)
end

function R:ShowFactionMenu(redraw)
	local isShown = IsFactionMenuShown()
	redraw = redraw and true or false
	if redraw == isShown then
		self:ToggleBarTooltip(false)
		ShowFactionMenu(not redraw)
	elseif isShown then
		LibQT:Release(repMenu)
	end
end
