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
local RepInfo
local UI

local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local table = table
local type = type

local RED_FONT_COLOR = RED_FONT_COLOR
local REPUTATION_PROGRESS_FORMAT = REPUTATION_PROGRESS_FORMAT
local GameTooltip = GameTooltip
local GameTooltipTextSmall = GameTooltipTextSmall
local UIParent = UIParent
local WorldFrame = WorldFrame

local RC = XPMultiBar:GetModule("ReputationCompat")

local CreateFramePool = CreateFramePool
local GameTooltip_AddColoredLine = GameTooltip_AddColoredLine
local GameTooltip_AddErrorLine = GameTooltip_AddErrorLine
local GameTooltip_AddHighlightLine = GameTooltip_AddHighlightLine
local GameTooltip_AddInstructionLine = GameTooltip_AddInstructionLine
local GameTooltip_AddNormalLine = GameTooltip_AddNormalLine
local GameTooltip_InsertFrame = GameTooltip_InsertFrame
local GameTooltip_SetDefaultAnchor = GameTooltip_SetDefaultAnchor
local GameTooltip_SetTitle = GameTooltip_SetTitle
local GetCursorPosition = GetCursorPosition
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown

local CollapseFactionHeader = C_Reputation.CollapseFactionHeader or RC.CollapseFactionHeader
local ExpandFactionHeader = C_Reputation.ExpandFactionHeader or RC.ExpandFactionHeader
local GetNumFactions = C_Reputation.GetNumFactions or RC.GetNumFactions
local SetWatchedFactionByIndex = C_Reputation.SetWatchedFactionByIndex or RC.SetWatchedFactionByIndex

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

local function SortFavoritesDesc(favTable)
	local ids = {}
	if favTable then
		for k, v in pairs(favTable) do
			if v and type(k) == "number" then
				table.insert(ids, k)
			end
		end
		table.sort(ids, function(a, b) return b < a end)
	end
	return ids
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

local repMenuLineHeight = 16

local tags = {
	empty = ([[|TInterface\AddOns\XPMultiBar\Textures\transp-dot:%d|t]]):format(repMenuLineHeight),
	minus = [[|TInterface\Buttons\UI-MinusButton-Up:0:0:1:-1|t]],
	plus = [[|TInterface\Buttons\UI-PlusButton-Up:0:0:1:-1|t]],
	lfgBonus = [[|TInterface\Common\ReputationStar:0:0:0:0:32:32:0:15:0:15|t]],
	repBonus = [[|TInterface\Common\ReputationStar:0:0:0:0:32:32:16:31:16:31|t]],
	atWar = [[|TInterface\WorldStateFrame\CombatSwords:0:0:0:0:32:32:0:15:0:15|t]],
	paragon = [[|A:ParagonReputation_Bag:12:10:0:0|a]],
	paragonReward = [[|A:ParagonReputation_Bag:12:10:0:0|a|A:ParagonReputation_Checkmark:10:10:-10:0|a]],
	renown = [[|Tinterface\targetingframe\ui-raidtargetingicon_1:0|t]],
	warband = [[|TInterface\warbands\uiwarbandsicons:0:0:0:0:64:64:1:23:4:26|t]],
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

local function GetFactionIcons(
					hasBonusRep, isLFGBonus, isFactionParagon,
					hasParagonReward, isAtWar, isRenown, isAccountWide)
	local icons = ""

	if isAccountWide then
		icons = icons .. tags.warband
	end
	if isRenown then
		icons = icons .. tags.renown
	end
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
		faction = RepInfo:GetFactionInfo(faction)
	end

	local name, current, max, isParagon, hasParagonReward
			= faction.name, faction.value, faction.maxValue, faction.paragon, faction.paragon and faction.paragon.hasReward
	local frame = R.framePool:Acquire()
	local commify = commifyNumbers and Utils.Commify or tostring

	frame:Hide()

	if name then
		if showHeader == 2 then
			name = name .. "\32" .. GetFactionIcons(
											faction.hasBonusRep, false, isParagon, hasParagonReward,
											faction.isAtWar, faction.renown, faction.isAccountWide
										)
		end

		frame:SetHeader(name)
		frame:SetStatusBarValues(0, max, current)
		frame:SetStatusBarColor(faction.standingColor)
		frame:SetStatusBarTexts(
								faction.standingText,
								REPUTATION_PROGRESS_FORMAT:format(commify(current or 0), commify(max or 0))
							)
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
			Config:SetFactionFavorite(factionID, not isFavorite)
			R:ShowFactionMenu(true)
			if R.favoriteCheckbox and R.favoriteCheckbox.factionID == factionID then
				R.favoriteCheckbox:SetChecked(not isFavorite)
			end
		elseif button == "LeftButton" then
			SetWatchedFactionByIndex(isWatched and 0 or factionIndex)
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

	if tip.extraText then
		GameTooltip_AddHighlightLine(GameTooltip, tip.extraText)
	end

	if not tip.faction.isHeader or tip.faction.hasRep then
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
	local lineNum

	repMenu:Hide()
	repMenu:Clear()

	for factionNum = 1, GetNumFactions() do
		local info = RepInfo:GetFactionInfoByIndex(factionNum)
		local icons = config.showIcons and GetFactionIcons(
												info.hasBonusRep,
												false,
												info.paragon,
												info.paragon and info.paragon.hasReward,
												info.isAtWar,
												info.renown,
												info.isAccountWide
											) or ""
		local id, name, text, color, isHeader, isCollapsed, hasRep, isWatched, isChild
				= info.id, info.name, info.standingText, info.standingColor,
					info.isHeader, info.isCollapsed, info.hasRep,
					info.isWatched, info.isChild
		local isFavorite = id and config.favorites[id]
		local instruction
		--[[
			Menu columns:
			I	II		III		IV		V
			[-]	Header text		stand.	icons -- top-level header (no rep. by def.) (header = true, headerWithRep = false, isChild = false)
				Fraction name	stand.	icons -- top-level faction (header = false, headerWithRep = false, isChild = false)
				[-]		Head	stand.	icons -- subheader (faction/group) (header = true, headerWithRep = ?, isChild = true)
						Fract.	stand.	icons -- subfaction (header = false, headerWithRep = false, isChild = true)
		]]
		if isHeader then
			local columnForTag, columnForName, nameColumnSpan = 1, 2, 4
			local tag = isCollapsed and tags.plus or tags.minus
			instruction = isCollapsed and instructions.expand or instructions.collapse

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
			repMenu:SetCell(lineNum, columnForName, name, normalFont, nameColumnSpan, nil, nil, nil, 160)

			if hasRep then
				repMenu:SetCell(lineNum, 4, color:WrapTextInColorCode(text), normalFont)

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

			if isChild then
				columnForName, nameColumnSpan = 3, 1
			end

			lineNum = repMenu:AddLine()
			repMenu:SetCell(lineNum, 1, tags.empty, smallFont)
			repMenu:SetCell(
						lineNum, columnForName,
						color:WrapTextInColorCode(name),
						smallFont, nameColumnSpan, nil, nil, nil, 160
					)
			repMenu:SetCell(lineNum, 4, color:WrapTextInColorCode(text), smallFont)

			if icons then
				repMenu:SetCell(lineNum, 5, icons, normalFont)
			end
		end

		if isWatched then
			repMenu:SetLineColor(lineNum, GetColorRGBA(config.watchedFactionLineColor))
		elseif config.showFavorites and isFavorite then
			repMenu:SetLineColor(lineNum, GetColorRGBA(config.favoriteFactionLineColor))
		end

		local tooltipName = name
		local friend = info.friend

		if friend then
			tooltipName = name .. " (" .. REPUTATION_PROGRESS_FORMAT:format(friend.level, friend.maxLevel) .. ")"
		end

		local onEnterArgs = {
			faction = info,
			name = tooltipName .. "\32" .. icons,
			desc = info.description,
			extraText = friend and friend.description,
			instruction = instruction:format(name),
		}

		repMenu:SetLineScript(
							lineNum, "OnMouseUp", ClickMenuItem,
							{
								id = id,
								index = factionNum,
								isCollapsed = isCollapsed,
								isHeader = isHeader,
								hasRep = hasRep,
								isFavorite = isFavorite,
								isWatched = isWatched,
								name = name,
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
		local commify = db.general.commify
		local factions = SortFavoritesDesc(db.reputation.favorites)

		GameTooltip:SetMinimumWidth(250, true)
		GameTooltip:SetOwner(bar, "ANCHOR_NONE")

		GameTooltip_SetTitle(GameTooltip, L["Favorite Factions"])

		if not factions or #factions == 0 then
			GameTooltip_AddErrorLine(GameTooltip, L["No favorite factions selected"], true)
			GameTooltip_AddInstructionLine(GameTooltip, L["Add some favorite factions"], true)
		end

		for _, id in ipairs(factions) do
			local showHeader = db.bars.repicons and 2 or 1
			local repFrame = GetReputationFrame(id, showHeader, commify)
			local fullHeight = GameTooltip_InsertFrame(GameTooltip, repFrame)
			repFrame:AfterInsert(GameTooltip, fullHeight)
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
