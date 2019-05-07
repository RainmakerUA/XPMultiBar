local addonName, addonTable = ...

XPMultiBar = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceConsole-3.0")
local self, XPMultiBar, utils, metadata = XPMultiBar, XPMultiBar, addonTable.utils, addonTable.metadata

-- Libs
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local LSM3 = LibStub("LibSharedMedia-3.0")
local LQT = LibStub("LibQTip-1.0")

-- Lua
local _G = _G
local ipairs = ipairs
local select = select
local tonumber = tonumber
local tostring = tostring
local type = type

-- Math
local math_ceil = math.ceil
local math_floor = math.floor
local math_min = math.min

-- WoW globals
local BreakUpLargeNumbers = BreakUpLargeNumbers
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
local InterfaceOptionsFrame_OpenToCategory = InterfaceOptionsFrame_OpenToCategory
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

local BACKGROUND = BACKGROUND
local FACTION_ALLIANCE = FACTION_ALLIANCE
local FACTION_BAR_COLORS = FACTION_BAR_COLORS
local FACTION_HORDE = FACTION_HORDE
local GUILD = GUILD

utils.forEach(
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
		LSM3:Register("statusbar", path, name)
	end
)

-- SavedVariables stored here
local db

-- Table stores KTL data
local lastXPValues = {}
local sessionKills = 0

-- Used to fix some weird bar switching issue :)
local mouseOverWithShift

-- Reputation menu tooltip
local repTooltip

-- Azerite bar show
local showAzerBar = false

local maxPlayerLevel = MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()]

-- Artifact item title color
local artColor

do
	local color = ITEM_QUALITY_COLORS[6]
	artColor = {
		r = color.r,
		g = color.g,
		b = color.b,
		a = color.a
	}
end

-- Reputation colors
local STANDING_EXALTED = 8
local repHexColor

-- repHex colors are automatically generated and cached when first looked up.
do
	repHexColor = setmetatable({}, {
		__index = function(t, k)
			local FBC
			if k == STANDING_EXALTED then
				FBC = db.bars.exalted
			else
				FBC = FACTION_BAR_COLORS[k]
			end

			local hex = ("%02x%02x%02x"):format(FBC.r * 255, FBC.g * 255, FBC.b * 255)
			t[k] = hex

			return hex
		end,
	})
end

-- Cache FACTION_STANDING_LABEL
-- When a lookup is first attempted on this cable, we go and lookup the real
-- value and cache it.
local factionStandingLabel
do
	local _G = _G
	factionStandingLabel = setmetatable({}, {
		__index = function(t, k)
			local FSL = _G["FACTION_STANDING_LABEL"..k]
			t[k] = FSL
			return FSL
		end,
	})
end

-- Default settings
local defaults = {
	profile = {
		-- General
		general = {
			border = false,
			texture = "Smooth",
			width = 1028,
			height = 20,
			fontsize = 14,
			fontoutline = false,
			posx = nil,
			posy = nil,
			scale = 1,
			strata = "HIGH",
			hidetext = false,
			dynamicbars = false,
			mouseover = false,
			locked = false,
			bubbles = false,
			clamptoscreen = true,
			commify = false,
			textposition = 50,
		},
		bars = {
			-- XP bar
			xpstring = "Exp: [curXP]/[maxXP] ([restPC]) :: [curPC] through level [pLVL] :: [needXP] XP left :: [KTL] kills to level",
			indicaterest = true,
			showremaining = true,
			showzerorest = true,
			-- Reputation bar
			repstring = "Rep: [faction] ([standing]) [curRep]/[maxRep] :: [repPC]",
			autowatchrep = true,
			showrepbar = false,
			autotrackguild = false,
			-- Azerite bar
			azerstr = "[name]: [curXP]/[maxXP] :: [curPC] through level [pLVL] :: [needXP] AP left",
			showazerbar = true,
		-- Bar colors
			normal = { r = 0.8, g = 0, b = 1, a = 1 },
			rested = { r = 0, g = 0.4, b = 1, a = 1 },
			resting = { r = 1.0, g = 0.82, b = 0.25, a = 1 },
			remaining = { r = 0.82, g = 0, b = 0, a = 1 },
			background = { r = 0.5, g = 0.5, b = 0.5, a = 0.5 },
			exalted = { r = 0, g = 0.77, b = 0.63, a = 1 },
			azerite = artColor, -- azerite bar default color is a color of artifact item title
			xptext = { r = 1, g = 1, b = 1, a = 1 },
			reptext = { r = 1, g = 1, b = 1, a = 1 },
			azertext = { r = 1, g = 1, b = 1, a = 1 },
		},
		-- Reputation menu options
		repmenu = {
			scale = 1,
			autohidedelay = 1,
		},
	}
}

--[[
	Position: lock, screen clamp, frame strata
	Size: width, height, scale
	Font: font face, font size, outline
	?: texture, bubbles, show border
	?: text position, dynamic bars, mouseover
	OFF: Text: hide text, separate thousands, show zero rest xp
--]]

local function GetOptions(uiTypes, uiName, appName)
	local function getColor(info)
		local col = db.bars[info[#info]]
		return col.r, col.g, col.b, col.a or 1
	end
	local function setColor(info, r, g, b, a)
			local col = db.bars[info[#info]]
			col.r, col.g, col.b, col.a = r, g, b, a
			repHexColor[STANDING_EXALTED] = nil
			local bgc = db.bars.background
			XPMultiBar.frame.background:SetStatusBarColor(bgc.r, bgc.g, bgc.b, bgc.a)
		XPMultiBar:UpdateXPBar()
	end

	if appName == "XPMultiBar-General" then
		local options = {
			type = "group",
			name = metadata.title,
			get = function(info) return db.general[info[#info]] end,
			set = function(info, value)
				db.general[info[#info]] = value
				self:UpdateXPBar()
			end,
			args = {
				-- Position
				posGroup = {
					type = "group",
					order = 10,
					name = L["Position"],
					guiInline = true,
					width = "full",
					args = {
						locked = {
							type = "toggle",
							order = 100,
							name = L["Lock"],
							desc = L["Toggle the locking."],
						},
						clamptoscreen = {
							type = "toggle",
							order = 200,
							name = L["Screen Clamp"],
							desc = L["Toggle screen clamping."],
						},
						strata = {
							type = "select",
							order = 300,
							name = L["Frame Strata"],
							desc = L["Set the frame strata."],
							style = "dropdown",
							values = {
								HIGH = "High",
								MEDIUM = "Medium",
								LOW = "Low",
								BACKGROUND = "Background",
							},
						},
					},
				},
				-- Size
				sizeGroup = {
					type = "group",
					order = 20,
					name = L["Size"],
					guiInline = true,
					width = "full",
					args = {
						width = {
							type = "range",
							order = 100,
							name = L["Width"],
							desc = L["Set the bar width."],
							min = 100,
							max = 5000,
							step = 1,
							bigStep = 50,
							set = function(info, value)
								db.general.width = value
								self:SetWidth(value)
							end,
						},
						height = {
							type = "range",
							order = 200,
							name = L["Height"],
							desc = L["Set the bar height."],
							min = 10,
							max = 100,
							step = 1,
							bigStep = 5,
							set = function(info, value)
								db.general.height = value
								self:SetHeight(value)
							end
						},
						scale = {
							type = "range",
							order = 300,
							name = L["Scale"],
							desc = L["Set the bar scale."],
							min = 0.5,
							max = 2,
							set = function(info, value)
								self:SavePosition()
								self.frame:SetScale(value)
								db.general.scale = value
								self:RestorePosition()
							end,
						},
					},
				},
				-- Font
				fontGroup = {
					type = "group",
					order = 30,
					name = L["Font"],
					guiInline = true,
					width = "full",
					args = {
						font = {
							type = "select",
							order = 100,
							name = L["Font Face"],
							desc = L["Set the font face."],
							style = "dropdown",
							dialogControl = "LSM30_Font",
							values = AceGUIWidgetLSMlists.font,
							set = function(info, value)
								db.general.font = value
								self:SetFontOptions()
								self:UpdateXPBar()
							end,
						},
						fontsize = {
							type = "range",
							order = 200,
							name = L["Font Size"],
							desc = L["Change the size of the text."],
							min = 5,
							max = 30,
							step = 1,
							set = function(info, value)
								db.general.fontsize = value
								self:SetFontOptions()
							end,
						},
						fontoutline = {
							type = "toggle",
							order = 300,
							name = L["Font Outline"],
							desc = L["Toggles the font outline."],
							set = function(info, value)
								db.general.fontoutline = value
								self:SetFontOptions()
							end,
						},
					},
				},
				-- Visuals
				visGroup = {
					type = "group",
					order = 40,
					name = L["Visuals"],
					guiInline = true,
					width = "full",
					args = {
						texture = {
							type = "select",
							order = 100,
							name = L["Texture"],
							desc = L["Set the bar texture."],
							style = "dropdown",
							dialogControl = "LSM30_Statusbar",
							values = AceGUIWidgetLSMlists.statusbar,
							set = function(info, value)
								db.general.texture = value
								self:SetTexture(value)
								self:UpdateXPBar()
							end,
						},
						bubbles = {
							type = "toggle",
							order = 200,
							name = L["Bubbles"],
							desc = L["Toggle bubbles on the XP bar."],
							set = function(info, value)
								db.general.bubbles = value
								self:ToggleBubbles()
							end,
						},
						border = {
							type = "toggle",
							order = 300,
							name = L["Border"],
							desc = L["Toggle the border."],
							set = function(info, value)
								db.general.border = value
								self:ToggleBorder()
							end,
						},
					},
				},
				-- Text
				textGroup = {
					type = "group",
					order = 50,
					name = L["Text Display"],
					guiInline = true,
					width = "full",
					args = {
						textposition = {
							type = "range",
							order = 100,
							name = L["Text Position"],
							desc = L["Select the position of the text on XP MultiBar."],
							min = 0,
							max = 100,
							step = 1,
							bigStep = 5,
							set = function(info, value)
								db.general.textposition = value
								self:SetTextPosition(value)
							end,
						},
						commify = {
							type = "toggle",
							order = 200,
							name = L["Commify"],
							desc = L["Insert thousands separators into long numbers."],
						},
						showzerorep = {
							type = "toggle",
							order = 300,
							name = L["Show Zero"],
							desc = L["Show zero values in the various Need tags, instead of an empty string"],
						},
					},
				},
			},
		}
		return options
	end
	if appName == "XPMultiBar-Bars" then
		return {
			type = "group",
			name = L["Bars"],
			get = function(info) return db.bars[info[#info]] end,
			set = function(info, value)
				db.bars[info[#info]] = value
				self:UpdateXPBar()
			end,
			args = {
				bardesc = {
					type = "description",
					order = 0,
					name = L["Options for XP / reputation / azerite power bars."],
				},
				xpgroup = {
					type = "group",
					order = 10,
					name = L["Experience"],
					guiInline = true,
					width = "full",
					args = {
						xpdesc = {
							type = "description",
							order = 0,
							name = L["Experience Bar related options"],
						},
						xpstring = {
							type = "input",
							order = 10,
							name = L["Customise Text"],
							desc = L["Customise the XP text string."],
							width = "full",
						},
						showremaining = {
							type = "toggle",
							order = 20,
							name = L["Remaining Rested XP"],
							desc = L["Toggle the display of remaining rested XP."],
						},
						indicaterest = {
							type = "toggle",
							order = 30,
							name = L["Rest Indication"],
							desc = L["Toggle the rest indication."],
						},
						xpcolorgroup = {
							type = "group",
							order = 40,
							name = "",
							guiInline = true,
							width = "full",
							get = getColor,
							set = setColor,
							args = {
								xptext = {
									type = "color",
									order = 10,
									name = L["XP Text"],
									desc = L["Set the color of the XP text."],
									hasAlpha = true,
								},
								background = {
									type = "color",
									order = 20,
									name = BACKGROUND,
									desc = L["Set the color of the background bar."],
									hasAlpha = true,
								},
								normal = {
									type = "color",
									order = 30,
									name = L["Normal"],
									desc = L["Set the color of the normal bar."],
									hasAlpha = true,
								},
								rested = {
									type = "color",
									order = 40,
									name = L["Rested"],
									desc = L["Set the color of the rested bar."],
									hasAlpha = true,
								},
								resting = {
									type = "color",
									order = 50,
									name = L["Resting"],
									desc = L["Set the color of the resting bar."],
									hasAlpha = true,
								},
								remaining = {
									type = "color",
									order = 60,
									name = L["Remaining"],
									desc = L["Set the color of the remaining bar."],
									hasAlpha = true,
								},
							},
						},
					},
				},
				repgroup = {
					type = "group",
					order = 20,
					name = L["Reputation Bar"],
					guiInline = true,
					width = "full",
					args = {
						repdesc = {
							type = "description",
							order = 0,
							name = L["Reputation Bar related options"],
						},
						repstring = {
							type = "input",
							order = 10,
							name = L["Customise Text"],
							desc = L["Customise the Reputation text string."],
							width = "full",
						},
						autowatchrep = {
							type = "toggle",
							order = 20,
							name = L["Auto Watch Reputation"],
							desc = L["Automatically watch the factions you gain reputation with."],
							set = function()
								db.bars.autowatchrep = not db.bars.autowatchrep
								XPMultiBar:ToggleAutoWatch()
							end,
						},
						autotrackguild = {
							type = "toggle",
							order = 30,
							name = L["Auto Track Guild Reputation"],
							desc = L["Automatically track your guild reputation increases."],
						},
						showrepbar = {
							type = "toggle",
							order = 40,
							name = L["Show Reputation"],
							desc = L["Show the reputation bar instead of the XP bar."],
							set = function()
								XPMultiBar:ToggleShowReputation()
							end,
						},
						repcolorgroup = {
							type = "group",
							order = 50,
							name = "",
							guiInline = true,
							width = "full",
							get = getColor,
							set = setColor,
							args = {
								reptext = {
									type = "color",
									order = 10,
									name = L["Reputation Text"],
									desc = L["Set the color of the Reputation text."],
									hasAlpha = true,
								},
								exalted = {
									type = "color",
									order = 20,
									name = _G.FACTION_STANDING_LABEL8,
									desc = L["Set the color of the Exalted reputation bar."],
									hasAlpha = true,
								},
							},
						},
					},
				},
				azergroup = {
					type = "group",
					order = 30,
					name = L["Azerite Bar"],
					guiInline = true,
					width = "full",
					args = {
						azerdesc = {
							type = "description",
							order = 0,
							name = L["Azerite Bar related options"],
						},
						azerstr = {
							name = L["Customise Text"],
							desc = L["Customise the Azerite text string."],
							type = "input",
							order = 10,
							width = "full",
						},
						showazerbar = {
							type = "toggle",
							order = 20,
							name = L["Show Azerite"],
							desc = L["Show the azerite bar instead of the XP bar when on max level."],
						},
						azercolorgroup = {
							type = "group",
							order = 30,
							name = "",
							guiInline = true,
							width = "full",
							get = getColor,
							set = setColor,
							args = {
								azertext = {
									type = "color",
									order = 10,
									name = L["Azerite Text"],
									desc = L["Set the color of the Azerite text."],
									hasAlpha = true,
								},
								azerite = {
									type = "color",
									order = 20,
									name = L["Azerite Bar"],
									desc = L["Set the color of the Azerite Power bar."],
									hasAlpha = true,
								},
							},
						},
					},
				},
			},
		}
	end
	if appName == "XPMultiBar-Colors" then
		local options = {
			type = "group",
			name = L["Bar Colors"],
			get = function(info)
				local col = db.bars[info[#info]]
				return col.r, col.g, col.b, col.a or 1
			end,
			set = function(info, r, g, b, a)
					local col = db.bars[info[#info]]
					col.r, col.g, col.b, col.a = r, g, b, a
					repHexColor[STANDING_EXALTED] = nil
					local bgc = db.bars.background
					self.frame.background:SetStatusBarColor(
					bgc.r,
					bgc.g,
					bgc.b,
					bgc.a
				)
				self:UpdateXPBar()
			end,
			args = {
				colorsdesc = {
					type = "description",
					order = 0,
					name = L["Set the colors for various XP MultiBar bars."],
				},
				xptext = {
					name = L["XP Text"],
					desc = L["Set the color of the XP text."],
					type = "color",
					order = 600,
					hasAlpha = true,
				},
				background = {
					name = BACKGROUND,
					desc = L["Set the color of the background bar."],
					type = "color",
					order = 800,
					hasAlpha = true,
				},
				normal = {
					name = L["Normal"],
					desc = L["Set the color of the normal bar."],
					type = "color",
					order = 100,
					hasAlpha = true,
				},
				rested = {
					name = L["Rested"],
					desc = L["Set the color of the rested bar."],
					type = "color",
					order = 200,
					hasAlpha = true,
				},
				resting = {
					name = L["Resting"],
					desc = L["Set the color of the resting bar."],
					type = "color",
					order = 300,
					hasAlpha = true,
				},
				remaining = {
					name = L["Remaining"],
					desc = L["Set the color of the remaining bar."],
					type = "color",
					order = 400,
					hasAlpha = true,
				},
				reptext = {
					name = L["Reputation Text"],
					desc = L["Set the color of the Reputation text."],
					type = "color",
					order = 700,
					hasAlpha = true,
				},
				exalted = {
					name = _G.FACTION_STANDING_LABEL8,
					desc = L["Set the color of the Exalted reputation bar."],
					type = "color",
					order = 500,
					hasAlpha = true,
				},
				azerite = {
					name = L["Azerite Bar"],
					desc = L["Set the color of the Azerite Power bar."],
					type = "color",
					order = 550,
					hasAlpha = true,
				},
			},
		}
		return options
	end
	if appName == "XPMultiBar-RepMenu" then
		local options = {
			type = "group",
			name = L["Reputation Menu"],
			get = function(info) return db.repmenu[info[#info]] end,
			set = function(info, value) db.repmenu[info[#info]] = value end,
			args = {
				repmenudesc = {
					type = "description",
					order = 0,
					name = L["Configure the reputation menu."],
				},
				scale = {
					name = L["Scale"],
					desc = L["Set the scale of the reputation menu."],
					type = "range",
					order = 100,
					min = 0.5,
					max = 2,
					step = 0.5,
				},
				autohidedelay = {
					name = L["Auto Hide Delay"],
					desc = L["Set the length of time (in seconds) it takes for the menu to disappear once you move the mouse away."],
					type = "range",
					order = 200,
					min = 0,
					max = 5,
				},
			}
		}
		return options
	end
end

local function commify(num)
	if not db.general.commify or type(num) ~= "number" or tostring(num):len() <= 3 then
		return num
	end
	return BreakUpLargeNumbers(num)
end

local function formatPercents(dividend, divisor)
	return ("%.1f%%%%"):format(dividend / divisor * 100)
end

function formatRemainingPercents(dividend, divisor)
	return ("%.1f%%%%"):format(100 - (dividend / divisor * 100))
end

local function GetKTL() --> number
	if #lastXPValues == 0 then
		return 0
	end

	local xp = 0

	for _, v in ipairs(lastXPValues) do
		xp = xp + v
	end

	if xp == 0 then
		return 0
	end

	local remXP = XPMultiBar.remXP
	local avgxp = xp / #lastXPValues
	local ktl = remXP / avgxp

	return math_ceil(remXP / avgxp)
end

local function GetXPText(cXP, nXP, remXP, restedXP)
	local restXPText, restPCText
	local level = UnitLevel("player")
	local ktl = GetKTL()

	if restedXP then
		restXPText = commify(restedXP)
		restPCText = formatPercents(restedXP, nXP)
	else
		restXPText = db.bars.showzerorest and "0" or ""
		restPCText = db.bars.showzerorest and "0%%" or ""
	end

	return utils.multiReplace(
		db.bars.xpstring,
		{
			["%[curXP%]"] = commify(cXP),
			["%[maxXP%]"] = commify(nXP),
			["%[restXP%]"] = restXPText,
			["%[restPC%]"] = restPCText,
			["%[curPC%]"] = formatPercents(cXP, nXP),
			["%[needPC%]"] = formatRemainingPercents(cXP, nXP),
			["%[pLVL%]"] = level,
			["%[nLVL%]"] = level + 1,
			["%[mLVL%]"] = maxPlayerLevel,
			["%[needXP%]"] = commify(remXP),
			["%[isLocked%]"] = IsXPUserDisabled() and "*" or "",
			["%[KTL%]"] = ktl > 0 and commify(ktl) or "?",
			["%[BTL%]"] = ("%d"):format(math_ceil(20 - ((cXP / nXP * 100) / 5)))
		}
	)
end

local function GetAzerText(name, currAP, maxAP, level)
	return utils.multiReplace(
		db.bars.azerstr,
		{
			["%[name%]"] = name,
			["%[curXP%]"] = commify(currAP),
			["%[maxXP%]"] = commify(maxAP),
			["%[curPC%]"] = formatPercents(currAP, maxAP),
			["%[needPC%]"] = formatRemainingPercents(currAP, maxAP),
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
		--local name,_,_,_,_,_,_,_,isHeader,_,_,isWatched,_,_,_,_ = GetFactionInfo(i)

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
			standingText = ("%s+"):format(factionStandingLabel[repStanding])
		else
			standingText = factionStandingLabel[repStanding]
		end
	end

	return utils.multiReplace(
		db.bars.repstring,
		{
			["%[faction%]"] = repName,
			["%[standing%]"] = standingText,
			["%[curRep%]"] = commify(repValue),
			["%[maxRep%]"] = commify(repMax),
			["%[repPC%]"] = formatPercents(repValue, repMax),
			["%[needRep%]"] = commify(repMax - repValue),
			["%[needPC%]"] = formatRemainingPercents(repValue, repMax)
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

function XPMultiBar:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("XPMultiBarDB", defaults, true)
	db = self.db.profile

	local myName = metadata.title
	local ACRegistry = LibStub("AceConfigRegistry-3.0")
	local ACDialog = LibStub("AceConfigDialog-3.0")
	ACRegistry:RegisterOptionsTable("XPMultiBar-General", GetOptions)
	ACRegistry:RegisterOptionsTable("XPMultiBar-Bars", GetOptions)
	ACRegistry:RegisterOptionsTable("XPMultiBar-RepMenu", GetOptions)

	ACDialog:AddToBlizOptions("XPMultiBar-General", myName)
	ACDialog:AddToBlizOptions("XPMultiBar-Bars", L["Bars"], myName)
	ACDialog:AddToBlizOptions("XPMultiBar-RepMenu", L["Reputation Menu"], myName)

	self:RegisterChatCommand("xpbar", function() InterfaceOptionsFrame_OpenToCategory(myName) end)

	local popts = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	ACRegistry:RegisterOptionsTable("XPMultiBar-Profiles", popts)
	ACDialog:AddToBlizOptions("XPMultiBar-Profiles", L["Profiles"], myName)

	self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
end

function XPMultiBar:OnEnable()
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

	-- Check for dynamic bars.
	if db.general.dynamicbars then
		self:UpdateDynamicBars()
	end

	-- Show the bar.
	self:UpdateXPData()
	self.frame:Show()
end

function XPMultiBar:OnDisable()
	self.frame:Hide()
	LSM3.UnregisterAllCallbacks(self)
end

function XPMultiBar:SetFontOptions()
	local font, size, flags
	if db.general.font then
		font = LSM3:Fetch("font", db.general.font)
	end
	-- Use regular font if we could not restore the saved one.
	if not font then
		font, size, flags = GameFontNormal:GetFont()
	end
	if db.general.fontoutline then
		flags = "OUTLINE"
	end
	self.frame.bartext:SetFont(font, db.general.fontsize, flags)
end

function XPMultiBar:SetTextPosition(percent)
	local width = db.general.width
	local posx = math_floor(((width / 100) * percent) - (width / 2))
	self.frame.bartext:ClearAllPoints()
	self.frame.bartext:SetPoint("CENTER", self.frame, "CENTER", posx or 0, 0)
end

function XPMultiBar:SetTexture(texture)
	local texturePath = LSM3:Fetch("statusbar", texture)
	utils.forEach(
		{self.frame.background, self.frame.remaining, self.frame.xpbar},
		function(bar)
			bar:SetStatusBarTexture(texturePath)
			bar:GetStatusBarTexture():SetHorizTile(false)
		end
	)
	local bgColor = db.bars.background
	self.frame.background:SetStatusBarColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
end

function XPMultiBar:SetWidth(width)
	self.frame:SetWidth(width)
	utils.forEach(
		{
			self.frame.button, self.frame.background, self.frame.remaining,
			self.frame.xpbar, self.frame.bubbles
		},
		function(frame)
			frame:SetWidth(width - 4)
		end
	)
	self:UpdateXPBar()
end

function XPMultiBar:SetHeight(height)
	self.frame:SetHeight(height)
	utils.forEach(
		{
			self.frame.background, self.frame.remaining,
			self.frame.xpbar, self.frame.bubbles
		},
		function(frame)
			frame:SetHeight(height - 8)
		end
	)
	self:UpdateXPBar()
end

function XPMultiBar:ToggleBorder()
	if db.general.border then
		self.frame:SetBackdropBorderColor(1, 1, 1, 1)
	else
		self.frame:SetBackdropBorderColor(0, 0, 0, 0)
	end
end

function XPMultiBar:ToggleBubbles()
	if db.general.bubbles then
		self.frame.bubbles:Show()
	else
		self.frame.bubbles:Hide()
	end
end

function XPMultiBar:ToggleClamp()
	self.frame:SetClampedToScreen(db.general.clamptoscreen and true or false)
end

function XPMultiBar:ToggleShowAzerite()
	showAzerBar = not showAzerBar
	self:UpdateXPBar()
end

function XPMultiBar:ToggleShowReputation()
	db.bars.showrepbar = not db.bars.showrepbar
	self:UpdateXPBar()
end

function XPMultiBar:ToggleAutoWatch()
	if db.bars.autowatchrep then
		self:RegisterEvent("COMBAT_TEXT_UPDATE")
	else
		self:UnregisterEvent("COMBAT_TEXT_UPDATE")
	end
end

function XPMultiBar:RefreshConfig(event, database, newProfileKey)
	db = database.profile
	self.frame:SetFrameStrata(db.general.strata)
	self.frame:SetScale(db.general.scale)
	self:SetWidth(db.general.width)
	self:SetHeight(db.general.height)
	self:ToggleBorder()
	self:SetFontOptions()
	self:SetTextPosition(db.general.textposition)
	self:SetTexture(db.general.texture)
	self:ToggleBubbles()
	self:ToggleClamp()
	-- Nil out the exalted color in repHexColor so it can be regenerated
	repHexColor[STANDING_EXALTED] = nil
	self:RestorePosition()
	self:UpdateXPBar()
end

-- Tooltips for the reputation menu
function XPMultiBar:SetTooltip(tip)
	GameTooltip_SetDefaultAnchor(GameTooltip, WorldFrame)
	GameTooltip:SetText(tip[1], 1, 1, 1)
	GameTooltip:AddLine(tip[2])
	GameTooltip:Show()
end

function XPMultiBar:HideTooltip()
	GameTooltip:FadeOut()
end

function XPMultiBar:ToggleCollapse(args)
	--local tooltip, factionIndex, name, hasRep, isCollapsed = args[1], args[2], args[3], args[4], args[5]
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

function XPMultiBar:SetWatchedFactionIndex(faction)
	SetWatchedFactionIndex(faction)
end

-- XPBar creation
function XPMultiBar:CreateXPBar()
	-- Check if the bar already exists before proceeding.
	if self.frame then
		return
	end

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
			local name = metadata.title
			InterfaceOptionsFrame_OpenToCategory(name)
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
		if db.general.mouseover then
			if not IsAltKeyDown() and not IsShiftKeyDown() and not IsControlKeyDown() then
				self:ToggleShowReputation()
			elseif IsAltKeyDown() then
				showAzerBar = true
				self:UpdateXPBar()
			else
				mouseOverWithShift = true
			end
		end
	end)

	-- On mouse leaving the frame
	self.frame.button:SetScript("OnLeave", function()
		if db.general.mouseover and not mouseOverWithShift and not showAzerBar then
			self:ToggleShowReputation()
		elseif showAzerBar then
			showAzerBar = false
			self:UpdateXPBar()
		else
			mouseOverWithShift = nil
		end
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

	-- XXX: Blizz tiling breakage.zz3#
	self.frame.bubbles:GetStatusBarTexture():SetHorizTile(false)

	-- XP Bar Text
	self.frame.bartext = self.frame.button:CreateFontString("XPMultiBarText", "OVERLAY")
	self:SetFontOptions()
	self.frame.bartext:SetShadowOffset(1, -1)
	self:SetTextPosition(db.general.textposition)
	self.frame.bartext:SetTextColor(1, 1, 1, 1)

	-- Set frame levels.
	self.frame:SetFrameLevel(0)
	self.frame.background:SetFrameLevel(self.frame:GetFrameLevel() + 1)
	self.frame.remaining:SetFrameLevel(self.frame:GetFrameLevel() + 2)
	self.frame.xpbar:SetFrameLevel(self.frame:GetFrameLevel() + 3)
	self.frame.bubbles:SetFrameLevel(self.frame:GetFrameLevel() + 4)
	self.frame.button:SetFrameLevel(self.frame:GetFrameLevel() + 5)

	self:SetTexture(db.general.texture)
	self:ToggleBubbles()
	self:ToggleClamp()
	self:ToggleBorder()
	self:RestorePosition()

	-- Kill function after the bar is made.
	XPMultiBar.CreateXPBar = nil
end

-- LSM3 Updates.
function XPMultiBar:MediaUpdate()

end

-- Check for faction updates for the automatic reputation watching
function XPMultiBar:COMBAT_TEXT_UPDATE(event, msgtype)
	-- Abort if it is not a FACTION update
	if msgtype ~= "FACTION" then
		return
	end

	local faction, amount = GetCurrentCombatTextEventInfo()

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
function XPMultiBar:PET_BATTLE_OPENING_START()
	self.frame:Hide()
end

function XPMultiBar:PET_BATTLE_CLOSE()
	self.frame:Show()
end

-- Update XP bar data
function XPMultiBar:UpdateXPData()
	local prevXP = self.cXP or 0
	self.cXP = UnitXP("player")
	self.nXP = UnitXPMax("player")
	self.remXP = self.nXP - self.cXP
	self.diffXP = self.cXP - prevXP

	if self.diffXP > 0 then
		lastXPValues[(sessionKills % 10) + 1] = self.diffXP
		sessionKills = sessionKills + 1
	end

	self:UpdateXPBar()
end

function XPMultiBar:UpdateReputationData()
	if not db.bars.showrepbar then
		return
	end

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
		if repStanding == STANDING_EXALTED then
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
	if repStanding == STANDING_EXALTED then
		repColor = db.bars.exalted
	else
		repColor = FACTION_BAR_COLORS[repStanding]
	end

	self.frame.xpbar:SetStatusBarColor(repColor.r, repColor.g, repColor.b, repColor.a)

	if not db.general.hidetext then
		self.frame.bartext:SetText(
			GetReputationText( {
				repName, repStanding, repMin, repMax,
				repValue, friendID, friendTextLevel,
				hasBonusRep, canBeLFGBonus, isFactionParagon
			} )
		)
	else
		self.frame.bartext:SetText("")
	end
end

function XPMultiBar:UpdateXPBar()
	-- If the menu is open and we are in here, refresh the menu.
	if LQT:IsAcquired("XPMultiBarTT") then
		self:DrawReputationMenu()
	end

	if db.bars.showrepbar then
		self:UpdateReputationData()
		return
	else
		if not self.frame.xpbar:IsVisible() then
			self.frame.xpbar:Show()
		end
	end

	local restedXP, xpText, currXP, maxXP, barColor

	if (showAzerBar or db.bars.showazerbar and UnitLevel("player") == maxPlayerLevel)
			and HasActiveAzeriteItem() then
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
	else
		restedXP = GetXPExhaustion()
		if restedXP == nil then
			if self.frame.remaining:IsVisible() then
				self.frame.remaining:Hide()
			end
			barColor = db.bars.normal
		else
			self.frame.remaining:SetMinMaxValues(math_min(0, self.cXP), self.nXP)
			self.frame.remaining:SetValue(self.cXP + restedXP)

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

		currXP, maxXP, xpText = self.cXP, self.nXP, GetXPText(self.cXP, self.nXP, self.remXP, restedXP)
	end

	self.frame.xpbar:SetMinMaxValues(math_min(0, currXP), maxXP)
	self.frame.xpbar:SetValue(currXP)
	self.frame.xpbar:SetStatusBarColor(barColor.r, barColor.g, barColor.b, barColor.a)

	-- Set the color of the bar text
	local txtcol = db.bars.xptext
	self.frame.bartext:SetTextColor(txtcol.r, txtcol.g, txtcol.b, txtcol.a)

	-- Hide the text or not?
	if not db.general.hidetext then
		self.frame.bartext:SetText(xpText)
	else
		self.frame.bartext:SetText("")
	end
end

-- When max level is hit, show only the rep bar.
function XPMultiBar:LevelUp(event, level)
	if not db.bars.showazerbar and level == maxPlayerLevel then
		db.bars.showrepbar = true
		db.general.mouseover = false
	end

	self:UpdateXPBar()
end

-- Dynamic bars, switch between rep/level when using a single profile for all char.s
function XPMultiBar:UpdateDynamicBars()
	if not db.bars.showazerbar and UnitLevel("player") == maxPlayerLevel then
		db.bars.showrepbar = true
		db.general.mouseover = false
	else
		db.bars.showrepbar = false
		db.general.mouseover = true
	end
end

function XPMultiBar:MakeReputationTooltip()
	if not LQT:IsAcquired("XPMultiBarTT") then
		repTooltip = LQT:Acquire("XPMultiBarTT", 2, "CENTER", "LEFT")
	end

	repTooltip:SetClampedToScreen(true)
	repTooltip:SetScale(db.repmenu.scale)

	-- Anchor to the cursor position along the bar.
	repTooltip:ClearAllPoints()
	repTooltip:SetPoint(GetTipAnchor(self.frame.button, repTooltip))
	repTooltip:SetAutoHideDelay(db.repmenu.autohidedelay, self.frame.button)
	repTooltip:EnableMouse()

	self:DrawReputationMenu()
end

function XPMultiBar:DrawReputationMenu()
	local linenum = nil
	local checkIcon = "|TInterface\\Buttons\\UI-CheckBox-Check:16:16:1:-1|t"
	local normalFont = repTooltip:GetFont()

	repTooltip:Hide()
	repTooltip:Clear()

	for faction = 1, GetNumFactions() do
		local name, _, standing, bottom, top, earned, atWar, _, isHeader, isCollapsed,
				hasRep, isWatched, isChild, repID, hasBonusRep, canBeLFGBonus = GetFactionInfo(faction)

		-- Set these to previous max values for exalted. Legion changed how exalted works.
		if standing == STANDING_EXALTED then
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
					standingText = ("%s+"):format(factionStandingLabel[standing])
				else
					standingText = factionStandingLabel[standing]
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
				repTooltip:SetCell(linenum, 2, ("|cff%s%s (%s)|r"):format(repHexColor[standing], name, standingText), GameTooltipTextSmall)
				repTooltip:SetLineScript(linenum, "OnMouseUp", XPMultiBar.SetWatchedFactionIndex, faction)
				repTooltip:SetLineScript(linenum, "OnEnter", XPMultiBar.SetTooltip, {name,tipText})
				repTooltip:SetLineScript(linenum, "OnLeave", XPMultiBar.HideTooltip)
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
					standingText = ("%s+"):format(factionStandingLabel[standing])
				else
					standingText = factionStandingLabel[standing]
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
			repTooltip:SetLineScript(linenum, "OnMouseUp", XPMultiBar.ToggleCollapse, {repTooltip,faction,name,hasRep,isCollapsed})
			repTooltip:SetLineScript(linenum, "OnEnter", XPMultiBar.SetTooltip, {name,tipText})
			repTooltip:SetLineScript(linenum, "OnLeave", XPMultiBar.HideTooltip)
		end
	end

	repTooltip:UpdateScrolling()
	repTooltip:Show()
end

-- Bar positioning.
function XPMultiBar:SavePosition()
	local x, y = self.frame:GetLeft(), self.frame:GetTop()
	local s = self.frame:GetEffectiveScale()

	x, y = x*s, y*s

	db.general.posx = x
	db.general.posy = y
end

function XPMultiBar:RestorePosition()
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
