--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_Frame.lua - module
		Frame module (UI) for XPMultiBar addon
--]=====]

local addonName = ...
local AceAddon = LibStub("AceAddon-3.0")
local XPMultiBar = AceAddon:GetAddon(addonName)
local UI = XPMultiBar:NewModule("UI", "AceEvent-3.0")

local geterrorhandler = geterrorhandler
local type = type
local xpcall = xpcall
local math_floor = math.floor

local GameFontNormal = GameFontNormal
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local StatusTrackingBarManager = StatusTrackingBarManager
local MainMenuExpBar = MainMenuExpBar
local ReputationWatchBar = ReputationWatchBar

local Event
local Utils

local bar
local barEvent

local function onBarEvent(...)
	return barEvent and barEvent(...)
end

local previousStatusTrackingBarVisibility

XPMultiBarFrameMixin = {}
XPMultiBarButtonMixin = {}

local fx = XPMultiBarFrameMixin
local bx = XPMultiBarButtonMixin

-- [[ Local functions ]]

local function tappend(...)
	local result, num, tbl = {}, 1, {...}
	for i = 1, #tbl do
		local t = tbl[i]
		if t then
			for i = 1, #t do
				result[num], num = t[i], num + 1
			end
		end
	end
	return result
end

--[[ Frame object mixin methods ]]

function fx:OnLoad()
	bar = self

	self:Hide()

	-- Set frame levels
	self:SetFrameLevel(0)
	local level = self:GetFrameLevel()
	local children = { self.background, self.remaining, self.xpbar, self.bubbles, self.button }

	for i, v in ipairs(children) do
		v:SetFrameLevel(level + i)
	end

	-- Set bubbles texture not tiling
	self.bubbles.tex:SetHorizTile(false)

	self.button:RegisterForDrag("LeftButton")
	self.button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
end

function fx:SetBarValues(barKey, min, max, value)
	local bar = self[barKey]
	bar:SetMinMaxValues(min, max)
	bar:SetValue(value)
end

function fx:SetBarColor(barKey, color)
	local bar = self[barKey]
	bar:SetStatusBarColor(color.r, color.g, color.b, color.a)
end

function fx:SetBarVisible(barKey, visible)
	self[barKey]:SetShown(visible)
end

--[[ Button object mixin methods ]]

function bx:OnLoad()
	self.xpIcons = { self.expMaxIcon, self.expStopIcon, self.expCapIcon }
	self.azerIcons = { self.azerMaxIcon }
	self.repIcons = { self.piGlow, self.piIcon, self.piCheck, self.lfgBonusIcon, self.repBonusIcon }
	self.icons = tappend(self.xpIcons, self.azerIcons, self.repIcons)
	self:HideAllIcons()
end

function bx:OnClick(button, down)
	onBarEvent("button-click", button, IsControlKeyDown(), IsAltKeyDown(), IsShiftKeyDown())
end

function bx:OnEnter(motion)
	onBarEvent("button-over", true, IsControlKeyDown(), IsAltKeyDown(), IsShiftKeyDown())
end

function bx:OnLeave(motion)
	onBarEvent("button-over", false, IsControlKeyDown(), IsAltKeyDown(), IsShiftKeyDown())
end

function bx:OnDragStart()
	local bar = self:GetParent()
	if bar:IsMovable() then
		bar:StartMoving()
	end
end

function bx:OnDragStop()
	local bar = self:GetParent()
	if bar:IsMovable() then
		bar:StopMovingOrSizing()
		onBarEvent("save-position", UI:GetPosition())
	end
end

function bx:OnUpdate()
	if self.piGlow:IsShown() then
		local alpha
		local time = GetTime()
		local value = time - math_floor(time)
		local direction = math_floor(time) % 2;

		if direction == 0 then
			alpha = value
		else
			alpha = 1 - value
		end

		self.piGlow:SetAlpha(alpha)
	end
end

function bx:GetVisibleIconWidth()
	for _, icon in ipairs(self.icons) do
		if icon ~= self.piGlow and icon ~= self.piCheck and icon:IsVisible() then
			return icon == self.piIcon and 20 or icon:GetWidth()
		end
	end
	return 0
end

function bx:AdjustTextPoint()
	local text = self.text
	local iconWidth = self:GetVisibleIconWidth()
	local offset = 5 -- default icon offset

	if self.repBonusIcon:IsVisible() and self.lfgBonusIcon:IsVisible() then
		offset = 10
	end
	local textOffset = iconWidth > 0 and (iconWidth + offset) / 2.0 or 0

	if textOffset ~= text.offset then
		text:ClearAllPoints()
		text:SetPoint("CENTER", textOffset, 0)
		text.offset = textOffset
	end
end

function bx:HideAllIcons()
	for _, icon in ipairs(self.icons) do
		icon:Hide()
	end
end

function bx:SetXPIcons(info)
	self:HideAllIcons()
	if type(info) == "table" then
		local isMaxLevel, isXPStopped, isLevelCap = unpack(info)
		if isMaxLevel then
			self.expMaxIcon:Show()
		elseif isXPStopped then
			self.expStopIcon:Show()
		elseif isLevelCap then
			self.expCapIcon:Show()
		end
	end
	self:AdjustTextPoint()
end

function bx:SetAzeriteIcons(info)
	self:HideAllIcons()
	if type(info) == "table" then
		local isHeartMaxLevel = unpack(info)
		if isHeartMaxLevel then
			self.azerMaxIcon:Show()
		end
	end
	self:AdjustTextPoint()
end

function bx:SetFactionIcons(info)
	self:HideAllIcons()
	if type(info) == "table" then
		local hasBonus, hasLfgBonus, isParagon, hasParagonReward = unpack(info)
		if hasBonus then
			self.repBonusIcon:Show()
		end
		if hasLfgBonus then
			self.lfgBonusIcon:Show()
			if hasBonus then
				self.lfgBonusIcon:ClearAllPoints()
				self.lfgBonusIcon:SetPoint("RIGHT", self.text, "LEFT", -10, 0)
			end
		end
		if not hasBonus or not hasLfgBonus then
			self.lfgBonusIcon:ClearAllPoints()
			self.lfgBonusIcon:SetPoint("RIGHT", self.text, "LEFT", -5, 0)
		end
		if isParagon then
			self.piIcon:Show()
			self.piGlow:SetShown(hasParagonReward)
			self.piCheck:SetShown(hasParagonReward)
		end
	end
	self:AdjustTextPoint()
end

--[[ Module methods ]]

function UI:OnInitialize()
	Event = XPMultiBar:GetModule("Event")
	Utils = XPMultiBar:GetModule("Utils")

	self.bar = bar

	barEvent = Event:New("OnBarEvent")
end

function UI:OnEnable(...)
	local hideStatusTrackingBar = ...
	self.bar:Show()
	self:SetStatusTrackingBarHidden(hideStatusTrackingBar)
end

function UI:OnDisable()
	self:SetStatusTrackingBarHidden(false)
	self.bar:Hide()
end

function UI:RegisterBarEventHandler(func, receiver)
	barEvent:AddHandler(func, receiver)
end

function UI:EnableEx(...)
	-- shortened impl of AceAddon's module:Enable
	-- suitable for passing arguments to module:OnEnable handler
	self:SetEnabledState(true)

	local aa = AceAddon

	if not aa.statuses[self.name] and self.enabledState then
		aa.statuses[self.name] = true

		if type(self.OnEnable) == "function" then
			xpcall(self.OnEnable, geterrorhandler(), self, ...)
		end

		return aa.statuses[self.name]
	end

	return false
end

function UI:GetBarText()
	return self.bar.button.text:GetText()
end

function UI:GetPosition()
	local x, y = self.bar:GetLeft(), self.bar:GetTop()
	local s = self.bar:GetEffectiveScale()

	return x * s, y * s
end

function UI:SetPosition(x, y)
	if not x or not y then
		return
	end

	local s = self.bar:GetEffectiveScale()

	x, y = x / s, y / s

	self.bar:ClearAllPoints()
	self.bar:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
end

function UI:SetLocked(value)
	self.bar:SetMovable(not value)
	self.bar.locked = value
end

function UI:SetClamp(value)
	self.bar:SetClampedToScreen(value)
end

function UI:SetStrata(strata)
	self.bar:SetFrameStrata(strata)
end

function UI:SetSize(width, height)
	self.bar:SetSize(width, height)
end

function UI:SetWidth(width)
	self.bar:SetWidth(width)
end

function UI:SetHeight(height)
	self.bar:SetHeight(height)
end

function UI:SetScale(scale)
	local x, y = self:GetPosition()
	self.bar:SetScale(scale)
	self:SetPosition(x, y)
	onBarEvent("set-position", x, y)
end

function UI:SetFontOptions(font, size, outline)
	local normalFont, normalSize, normalFlags, flags
	if not font or not size or outline == nil then
		normalFont, normalSize, normalFlags = GameFontNormal:GetFont()
	end

	-- TODO: normalFlags excluing OUTLINE?
	flags = outline and "OUTLINE" or normalFlags

	self.bar.button.text:SetFont(font or normalFont, size or normalSize, flags)
end

function UI:SetTexture(texturePath, horizTile, bgColor)
	Utils.ForEach(
		{ self.bar.background, self.bar.remaining, self.bar.xpbar },
		function(bar)
			local texture = bar:GetStatusBarTexture()
			texture:SetTexture(texturePath, horizTile and "REPEAT" or "CLAMP", "CLAMP", "TRILINEAR")
			texture:SetHorizTile(horizTile or false)
			texture:SetVertTile(false)
		end
	)
	self:SetBackgroundColor(bgColor)
end

function UI:SetBackgroundColor(color)
	if color then
		self.bar.background:SetStatusBarColor(color.r, color.g, color.b, color.a)
	end
end

function UI:ShowBorder(value)
	if value then
		self.bar:SetBackdropBorderColor(1, 1, 1, 1)
	else
		self.bar:SetBackdropBorderColor(0, 0, 0, 0)
	end
end

function UI:ShowBubbles(value)
	if value then
		self.bar.bubbles:Show()
	else
		self.bar.bubbles:Hide()
	end
end

function UI:HideBlizzFrame(frame)
	if not self.uiHider then
		self.uiHider = CreateFrame("Frame")
		self.uiHider:Hide()
	end
	if frame then
		frame._parent = frame:GetParent()
		frame:Hide()
		frame:SetParent(self.uiHider)


	end
end

function UI:UnhideBlizzFrame(frame)
	if frame then
		frame:Show()
		if frame._parent then
			frame:SetParent(frame._parent)
		end
	end
end

function UI:SetStatusTrackingBarHidden(hide)
	-- WoW Classic
	if MainMenuExpBar and ReputationWatchBar then
		if hide then
			previousStatusTrackingBarVisibility = MainMenuExpBar:IsVisible()
			self:HideBlizzFrame(MainMenuExpBar)
			self:HideBlizzFrame(ReputationWatchBar)
		elseif previousStatusTrackingBarVisibility then
			previousStatusTrackingBarVisibility = false
			self:UnhideBlizzFrame(MainMenuExpBar)
			self:UnhideBlizzFrame(ReputationWatchBar)
		end
	end
	-- WoW Retail
	if StatusTrackingBarManager then
		if hide then
			previousStatusTrackingBarVisibility = StatusTrackingBarManager:IsVisible()
			-- do not reparent, because some specific parent method is called (and reparenting is not required)
			StatusTrackingBarManager:Hide()
		elseif previousStatusTrackingBarVisibility then
			previousStatusTrackingBarVisibility = false
			StatusTrackingBarManager:Show()
		end
	end
end

function UI:SetMainBarValues(min, max, value)
	self.bar:SetBarValues("xpbar", min, max, value)
end

function UI:SetMainBarColor(color)
	self.bar:SetBarColor("xpbar", color)
end

function UI:SetMainBarVisible(visible)
	self.bar:SetBarVisible("xpbar", visible)
end

function UI:SetRemainingBarValues(min, max, value)
	self.bar:SetBarValues("remaining", min, max, value)
end

function UI:SetRemainingBarColor(color)
	self.bar:SetBarColor("remaining", color)
end

function UI:SetRemainingBarVisible(visible)
	self.bar:SetBarVisible("remaining", visible)
end

function UI:SetBarText(text)
	self.bar.button.text:SetText(text)
end

function UI:SetBarTextColor(color)
	self.bar.button.text:SetTextColor(color.r, color.g, color.b, color.a)
end

function UI:HideIcons()
	self.bar.button:HideAllIcons()
end

function UI:SetXPInfo(info)
	self.bar.button:SetXPIcons(info)
end

function UI:SetAzeriteInfo(info)
	self.bar.button:SetAzeriteIcons(info)
end

function UI:SetFactionInfo(id, factionInfo)
	self.bar.button:SetFactionIcons(factionInfo)
end