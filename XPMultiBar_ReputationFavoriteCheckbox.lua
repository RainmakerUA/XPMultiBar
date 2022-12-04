--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_ReputationFavoriteCheckbox.lua - module
		Reputation info module for XPMultiBar addon
--]=====]

local addonName = ...
local Utils = LibStub("rmUtils-1.1")
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName)
local FavCB = XPMultiBar:NewModule("ReputationFavoriteCheckbox")

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local Config

local wowClassic = Utils.IsWoWClassic

local select = select
local math_abs = math.abs

local hooksecurefunc = hooksecurefunc
local GetFactionInfo = GetFactionInfo
local GetSelectedFaction = GetSelectedFaction
local PlaySound = PlaySound

local _G = _G
local GameTooltip = GameTooltip
local SOUNDKIT = SOUNDKIT

local ReputationBarMixin = ReputationBarMixin

-- Remove all known globals after this point
-- luacheck: std none

-- luacheck: push globals ReputationDetailFrame
local repDetailFrame = ReputationDetailFrame
-- luacheck: pop
-- luacheck: push globals ReputationDetailMainScreenCheckBox ReputationDetailLFGBonusReputationCheckBox ReputationDetailViewRenownButton
local watchedCheckbox = ReputationDetailMainScreenCheckBox
-->local lfgBonusRepCheckbox = ReputationDetailLFGBonusReputationCheckBox absent in all versions
local viewRenownButton = ReputationDetailViewRenownButton
-- luacheck: pop

-- luacheck: push globals ReputationTooltipStatusBarMixin ReputationDetailFavoriteFactionCheckBoxMixin
ReputationDetailFavoriteFactionCheckBoxMixin = {}

local fav = ReputationDetailFavoriteFactionCheckBoxMixin
-- luacheck: pop

local favCheckbox

local function GetReputationDetailFrameHeight()
    local hasRenownButton = viewRenownButton and viewRenownButton:IsShown()
    return hasRenownButton and 247 or 225
end

local function UpdateFavoriteCheckbox(checkbox)
	local config = Config.GetDB().reputation
	local factionID = select(14, GetFactionInfo(GetSelectedFaction()))
	if config.showFavorites and repDetailFrame:IsShown() then
		local height = GetReputationDetailFrameHeight()
		local relCheckbox = watchedCheckbox
		repDetailFrame:SetHeight(height)
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

function FavCB:OnInitialize()
    Config = XPMultiBar:GetModule("Config")

	if wowClassic then
		-- Secure hook ReputationFrame_Update
		hooksecurefunc("ReputationFrame_Update", function()
			UpdateFavoriteCheckbox(favCheckbox)
		end)
	else
		repDetailFrame:HookScript("OnSizeChanged", function(frame, --[[width]]_, height)
			local neededHeight = GetReputationDetailFrameHeight()
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

function FavCB.GetFavoriteCheckbox()
    return favCheckbox
end

--[[ Favorite Checkbox methods ]]

function fav:OnLoad()
	_G[self:GetName() .. "Text"]:SetText(L["Favorite faction"])
	self:Hide()

    favCheckbox = self
end

function fav:OnClick()
	local checked = self:GetChecked()
	PlaySound(checked
				and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
				or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
			)
	Config:SetFactionFavorite(self.factionID, checked)
end

function fav:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetText(L["Choose faction to show in favorites list"], nil, nil, nil, nil, true);
end
