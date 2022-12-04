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

local R = Reputation

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local Config
local FavCB
local RepInfo
local UI

local ipairs = ipairs
local next = next
local pairs = pairs
local tostring = tostring
local type = type
local unpack = unpack
local tinsert = table.insert

local RED_FONT_COLOR = RED_FONT_COLOR
local GameTooltip = GameTooltip
local GameTooltipTextSmall = GameTooltipTextSmall
local UIParent = UIParent
local WorldFrame = WorldFrame

local CollapseFactionHeader = CollapseFactionHeader
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
local GetNumFactions = GetNumFactions
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local SetWatchedFactionIndex = SetWatchedFactionIndex

-- Remove all known globals after this point
-- luacheck: std none

-- luacheck: push globals ReputationTooltipStatusBarMixin ReputationTooltipStatusBarBorderMixin
ReputationTooltipStatusBarMixin = {}
ReputationTooltipStatusBarBorderMixin = {}

local rb = ReputationTooltipStatusBarMixin
local bx = ReputationTooltipStatusBarBorderMixin
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

function R:OnInitialize()
	Config = XPMultiBar:GetModule("Config")
	FavCB = XPMultiBar:GetModule("ReputationFavoriteCheckbox")
	RepInfo = XPMultiBar:GetModule("ReputationInfo")
	UI = XPMultiBar:GetModule("UI")

	-- Patch LibQTip
	local labelProto = LibQT.LabelPrototype
	local oldMethod = labelProto.InitializeCell

	labelProto.InitializeCell = function(proto, ...)
		local result = oldMethod(proto, ...)
		proto.fontString:SetWordWrap(false)
		return result
	end
end

function R:OnEnable()
end

function R:OnDisable()
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
		faction = { RepInfo:GetFactionData(faction) }
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
			FavCB:SetFactionFavorite(factionID, not isFavorite)
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
			factionInfo = { RepInfo:GetFactionData(factionID) }
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
