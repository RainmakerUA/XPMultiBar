--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_Config.lua - module
		Configuration and initialization for XPMultiBar addon
--]=====]

local addonName = ...
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Config = XPMultiBar:NewModule("Config", "AceConsole-3.0")

local Event

local C = Config
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local Utils

local tinsert = tinsert
local error = error

local BACKGROUND = BACKGROUND

local DB_VERSION_NUM = 821
local DB_VERSION = "V" .. tostring(DB_VERSION_NUM) .. (XPMultiBar.IsWoWClassic and "C" or "")

local md = {
	title = GetAddOnMetadata(addonName, "Title"),
	notes = GetAddOnMetadata(addonName, "Notes")
}

local xpLockedReasons = {
	MAX_EXPANSION_LEVEL = 0,
	MAX_TRIAL_LEVEL = 1,
	LOCKED_XP = 2,
}

-- Event handlers
local configChangedEvent
local profileChangedEvent

-- Current settings
local db

-- Artifact item title color
local artColor

do
	local color = ITEM_QUALITY_COLORS[LE_ITEM_QUALITY_ARTIFACT]
	artColor = {
		r = color.r,
		g = color.g,
		b = color.b,
		a = color.a
	}
end

-- Reputation colors
local STANDING_EXALTED = 8
local reputationColors

-- Reputation colors are automatically generated and cached when first looked up.
do
	reputationColors = setmetatable({}, {
		__index = function(t, k)
			local fbc

			if k == STANDING_EXALTED then
				fbc = db.bars.exalted
			else
				fbc = FACTION_BAR_COLORS[k]
			end

			t[k] = fbc
			return fbc
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
			local fsl = _G["FACTION_STANDING_LABEL"..k]
			t[k] = fsl
			return fsl
		end,
	})
end

local frameAnchors = {
	CENTER = "CENTER",
	LEFT = "LEFT",
	RIGHT = "RIGHT",
	TOP = "TOP",
	TOPLEFT = "TOPLEFT",
	TOPRIGHT = "TOPRIGHT",
	BOTTOM = "BOTTOM",
	BOTTOMLEFT = "BOTTOMLEFT",
	BOTTOMRIGHT = "BOTTOMRIGHT",
}

--[[
	-- Localization
	CENTER = L["ANCHOR.CENTER"],
	LEFT = L["ANCHOR.LEFT"],
	RIGHT = L["ANCHOR.RIGHT"],
	TOP = L["ANCHOR.TOP"],
	TOPLEFT = L["ANCHOR.TOPLEFT"],
	TOPRIGHT = L["ANCHOR.TOPRIGHT"],
	BOTTOM = L["ANCHOR.BOTTOM"],
	BOTTOMLEFT = L["ANCHOR.BOTTOMLEFT"],
	BOTTOMRIGHT = L["ANCHOR.BOTTOMRIGHT"],
]]

-- Default settings
local defaults = {
	profile = {
		-- General
		general = {
			advPosition = false,
			locked = false,
			clamptoscreen = true,
			strata = "LOW",
			anchor = frameAnchors.BOTTOM,
			anchorRelative = "",
			posx = 0,
			posy = 0,
			width = 1028,
			height = 20,
			scale = 1,
			font = nil,
			fontsize = 14,
			fontoutline = false,
			texture = "Smooth",
			horizTile = false,
			border = false,
			borderStyle = 1,
			borderDynamicColor = true,
			borderColor = { r = 0.5, g  = 0.5, b = 0.5, a = 1 },
			bubbles = false,
			commify = true,
			hidestatus = true,
		},
		bars = {
			-- XP bar
			xpstring = "Exp: [curXP]/[maxXP] ([restPC]) :: [curPC] through level [pLVL] :: [needXP] XP left :: [KTL] kills to level",
			xpicons = true,
			indicaterest = true,
			showremaining = true,
			showmaxlevel = false,
			-- Azerite bar
			azerstr = "[name]: [curXP]/[maxXP] :: [curPC] through level [pLVL] :: [needXP] AP left",
			azicons = true,
			showmaxazerite = false,
			-- Reputation bar
			repstring = "Rep: [faction] ([standing]) [curRep]/[maxRep] :: [repPC]",
			repicons = true,
			showrepbar = false,
			autowatchrep = true,
			autotrackguild = false,
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
	}
}

local function CreateGroupItems(description, items, keyMap)
	local result = {
		text = {
			name = description,
			type = "description",
			order = 10,
			fontSize = "medium",
		},
	}

	for i, v in ipairs(items) do
		local k, vv = unpack(v)
		result[k] = {
			name = keyMap and keyMap(k, vv) or k,
			type = "group",
			order = (i + 1) * 10,
			width = "full",
			guiInline = true,
			args = {
				text = {
					name = vv,
					type = "description",
					fontSize = "medium",
				},
			}
		}
	end

	return result
end

local function GetOptions(uiTypes, uiName, appName)
	local function onConfigChanged(key, value)
		configChangedEvent(key, value)
	end
	local function getCoord(info)
		local key = info[#info]
		return tostring(db.general[key])
	end
	local function setPosition(info, value)
		local key = info[#info]
		db.general[key] = value
		onConfigChanged("position", db.general)
	end

	local function getBorderColor(info)
		local col = db.general[info[#info]]
		return col.r, col.g, col.b, col.a
	end
	local function setBorder(info, r, g, b, a)
		local key = info[#info]
		if key == "borderColor" then
			local dbCol = db.general[key]
			dbCol.r, dbCol.g, dbCol.b, dbCol.a = r, g, b, a
		else
			db.general[key] = r
		end
		onConfigChanged("border", db.general)
	end

	local function getColor(info)
		local col = db.bars[info[#info]]
		return col.r, col.g, col.b, col.a or 1
	end
	local function setColor(info, r, g, b, a)
		local col = db.bars[info[#info]]
		col.r, col.g, col.b, col.a = r, g, b, a
		reputationColors[STANDING_EXALTED] = nil
		local bgc = db.bars.background
		onConfigChanged("bgColor", bgc)
	end

	if appName == addonName then
		local anchors = Utils.Clone(frameAnchors)
		local anchorValues = Utils.Map(anchors, function(val)
			return ("%s (%s)"):format(L["ANCHOR." .. val], val)
		end)
		local relAnchorValues = Utils.Merge({ [C.NoAnchor] = L["Same as Anchor"] }, anchorValues)
		local isBorderOptionsDisabled = function() return not db.general.border end
		local isBorderColorDisabled = function()
			return not db.general.border or db.general.borderDynamicColor
		end
		local options = {
			type = "group",
			name = md.title,
			childGroups = "tab",
			get = function(info)
				local key = info[#info]
				return db.general[key]
			end,
			set = function(info, value)
				local key = info[#info]
				db.general[key] = value
				onConfigChanged(key, value)
			end,
			args = {
				-- Position
				posGroup = {
					type = "group",
					order = 10,
					name = L["Position"],
					width = "full",
					args = {
						locked = {
							type = "toggle",
							order = 100,
							width = 1.5,
							name = L["Lock movement"],
							desc = L["Lock bar movement"],
						},
						clamptoscreen = {
							type = "toggle",
							order = 200,
							width = 1.5,
							name = L["Screen clamp"],
							desc = L["Clamp bar with screen borders"],
						},
						strata = {
							type = "select",
							order = 300,
							width = 1.5,
							name = L["Frame strata"],
							desc = L["Set the frame strata (z-order position)"],
							style = "dropdown",
							values = {
								HIGH = "High",
								MEDIUM = "Medium",
								LOW = "Low",
								BACKGROUND = "Background",
							},
						},
						advPosition = {
							type = "toggle",
							order = 400,
							width = 1.5,
							name = L["Advanced positioning"],
							desc = L["Show advanced positioning options"],
						},
						advPosGroup = {
							type = "group",
							order = 500,
							name = L["Advanced positioning"],
							guiInline = true,
							width = "full",
							hidden = function() return not db.general.advPosition end,
							set = setPosition,
							args = {
								anchor = {
									order = 1000,
									type = "select",
									width = 1.5,
									name = L["Anchor"],
									desc = L["Change the current anchor point of the bar"],
									values = anchorValues,
								},
								anchorRelative = {
									order = 2000,
									type = "select",
									width = 1.5,
									name = L["Relative anchor"],
									desc = L["Change the relative anchor point on the screen"],
									values = relAnchorValues,
								},
								posx = {
									order = 3000,
									type = "input",
									width = 1.5,
									name = L["X Offset"],
									desc = L["Offset in X direction (horizontal) from the given anchor point"],
									dialogControl = "NumberEditBox",
									get = getCoord,
								},
								posy = {
									order = 4000,
									type = "input",
									width = 1.5,
									name = L["Y Offset"],
									desc = L["Offset in Y direction (vertical) from the given anchor point"],
									dialogControl = "NumberEditBox",
									get = getCoord,
								},
							},
						},
						sizeGroup = {
							type = "group",
							order = 500,
							name = L["Size"],
							guiInline = true,
							width = "full",
							args = {
								width = {
									type = "range",
									order = 1000,
									width = 1.5,
									name = L["Width"],
									desc = L["Set the bar width"],
									min = 100,
									max = 5000,
									step = 1,
									bigStep = 50,
								},
								height = {
									type = "range",
									order = 2000,
									width = 1.5,
									name = L["Height"],
									desc = L["Set the bar height"],
									min = 10,
									max = 100,
									step = 1,
									bigStep = 5,
								},
								scale = {
									type = "range",
									order = 3000,
									width = 1.5,
									name = L["Scale"],
									desc = L["Set the bar scale"],
									min = 0.5,
									max = 2,
								},
							},
						},
						hidestatus = {
							type = "toggle",
							order = 600,
							width = "full",
							name = L["Hide WoW standard bars"],
							desc = L["Hide WoW standard bars for XP, Artifact power and reputation"],
						}
					},
				},
				-- Visuals
				visGroup = {
					type = "group",
					order = 20,
					name = L["Visuals"],
					width = "full",
					args = {
						-- Texture
						texGroup = {
							type = "group",
							order = 100,
							name = L["Texture"],
							guiInline = true,
							width = "full",
							args = {
								texture = {
									type = "select",
									order = 1000,
									name = L["Choose texture"],
									desc = L["Choose bar texture"],
									style = "dropdown",
									dialogControl = "LSM30_Statusbar",
									values = AceGUIWidgetLSMlists.statusbar,
								},
								horizTile = {
									type = "toggle",
									order = 2000,
									name = L["Texture tiling"],
									desc = L["Tile texture instead of stretching"],
								},
								bubbles = {
									type = "toggle",
									order = 3000,
									name = L["Bubbles"],
									desc = L["Show ticks on the bar"],
								},
							},
						},
						borderGroup = {
							type = "group",
							order = 200,
							name = L["Bar border"],
							guiInline = true,
							width = "full",
							set = setBorder,
							args = {
								border = {
									type = "toggle",
									order = 1000,
									width = 1.5,
									name = L["Show border"],
									desc = L["Show bar border"],
								},
								borderStyle = {
									type = "select",
									order = 2000,
									width = 1.5,
									disabled = isBorderOptionsDisabled,
									name = L["Border style"],
									desc = L["Set border style (texture)"],
									values = { "1. Dialog box border", "2. Toast border", "3. Tooltip border" },
								},
								borderDynamicColor = {
									type = "toggle",
									order = 3000,
									width = 1.5,
									disabled = isBorderOptionsDisabled,
									name = L["Dynamic color"],
									desc = L["Border color is set to bar color"],
								},
								borderColor = {
									type = "color",
									order = 4000,
									width = 1.5,
									disabled = isBorderColorDisabled,
									name = L["Border color"],
									desc = L["Set bar border color"],
									hasAlpha = false,
									get = getBorderColor,
								},
							},
						},
					},
				},
				-- Text
				textGroup = {
					type = "group",
					order = 30,
					name = L["Text"],
					--guiInline = true,
					width = "full",
					args = {
						font = {
							type = "select",
							order = 100,
							width = 1.5,
							name = L["Font face"],
							desc = L["Set the font face"],
							style = "dropdown",
							dialogControl = "LSM30_Font",
							values = AceGUIWidgetLSMlists.font,
						},
						fontsize = {
							type = "range",
							order = 200,
							width = 1.5,
							name = L["Font size"],
							desc = L["Set bar text font size"],
							min = 5,
							max = 30,
							step = 1,
						},
						fontoutline = {
							type = "toggle",
							order = 300,
							width = 1.5,
							name = L["Font outline"],
							desc = L["Show font outline"],
						},
						commify = {
							type = "toggle",
							order = 400,
							width = 1.5,
							name = L["Commify"],
							desc = L["Insert thousands separators into long numbers"],
						},
					},
				},
			},
		}
		return options
	end
	if appName == (addonName .. "-Bars") then
		return {
			type = "group",
			name = L["Bars"],
			childGroups = "tab",
			get = function(info) return db.bars[info[#info]] end,
			set = function(info, value)
				local key = info[#info]
				db.bars[key] = value
				onConfigChanged(key, value)
			end,
			args = {
				bardesc = {
					type = "description",
					order = 0,
					name = L["Options for XP / reputation / azerite power bars"],
				},
				xpgroup = {
					type = "group",
					order = 10,
					name = L["Experience Bar"],
					width = "full",
					args = {
						xpdesc = {
							type = "description",
							order = 0,
							name = L["Experience bar related options"],
						},
						xpstring = {
							type = "input",
							order = 10,
							name = L["Text format"],
							desc = L["Set XP bar text format"],
							width = "full",
						},
						xpicons = {
							type = "toggle",
							order = 15,
							width = 1.5,
							name = L["Display XP bar icons"],
							desc = L["Display icons for max. level, disabled XP gain and level cap due to limited account"]
						},
						showmaxlevel = {
							type = "toggle",
							order = 20,
							width = 1.5,
							name = L["Show at max. level"],
							desc = L["Show XP bar at player maximum level"],
						},
						indicaterest = {
							type = "toggle",
							order = 25,
							width = 1.5,
							name = L["Indicate resting"],
							desc = L["Indicate character resting with XP bar color"],
						},
						showremaining = {
							type = "toggle",
							order = 30,
							width = 1.5,
							name = L["Show rested XP bonus"],
							desc = L["Toggle the display of remaining rested XP"],
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
									width = 1.5,
									name = L["XP text"],
									desc = L["Set XP text color"],
									hasAlpha = true,
								},
								normal = {
									type = "color",
									order = 20,
									width = 1.5,
									name = L["Normal"],
									desc = L["Set normal bar color"],
									hasAlpha = true,
								},
								background = {
									type = "color",
									order = 30,
									width = 1.5,
									name = BACKGROUND,
									desc = L["Set background bar color"],
									hasAlpha = true,
								},
								rested = {
									type = "color",
									order = 40,
									width = 1.5,
									name = L["Rested bonus"],
									desc = L["Set XP bar color when character has rested XP bonus"],
									hasAlpha = true,
								},
								resting = {
									type = "color",
									order = 50,
									width = 1.5,
									name = L["Resting area"],
									desc = L["Set XP bar color when character is resting"],
									hasAlpha = true,
								},
								remaining = {
									type = "color",
									order = 60,
									width = 1.5,
									name = L["Remaining rest bonus"],
									desc = L["Set remaining XP rest bonus bar color"],
									hasAlpha = true,
								},
							},
						},
					},
				},
				azergroup = {
					type = "group",
					order = 20,
					name = L["Azerite Bar"],
					width = "full",
					args = {
						azerdesc = {
							type = "description",
							order = 0,
							name = L["Azerite bar related options"],
						},
						azerstr = {
							name = L["Text format"],
							desc = L["Set Azerite bar text format"],
							type = "input",
							order = 10,
							width = "full",
						},
						azicons = {
							type = "toggle",
							order = 20,
							width = 1.5,
							name = L["Display icons"],
							desc = L["Display icons for maximum Heart level"]
						},
						showmaxazerite = {
							type = "toggle",
							order = 30,
							width = 1.5,
							name = L["Show at max. level"],
							desc = L["Show azerite bar at Heart maximum level"],
						},
						azercolorgroup = {
							type = "group",
							order = 40,
							name = "",
							guiInline = true,
							width = "full",
							get = getColor,
							set = setColor,
							args = {
								azertext = {
									type = "color",
									order = 10,
									width = 1.5,
									name = L["Azerite text"],
									desc = L["Set Azerite text color"],
									hasAlpha = true,
								},
								azerite = {
									type = "color",
									order = 20,
									width = 1.5,
									name = L["Azerite bar"],
									desc = L["Set Azerite power bar color"],
									hasAlpha = true,
								},
							},
						},
						azerdesc = {
							type = "description",
							order = 50,
							fontSize = "medium",
							name = L["HELP.AZBARDISPLAY"],
						},
					},
				},
				repgroup = {
					type = "group",
					order = 30,
					name = L["Reputation Bar"],
					width = "full",
					args = {
						repdesc = {
							type = "description",
							order = 0,
							name = L["Reputation bar related options"],
						},
						repstring = {
							type = "input",
							order = 10,
							width = "full",
							name = L["Text format"],
							desc = L["Set reputation bar text format"],
						},
						repicons = {
							type = "toggle",
							order = 15,
							width = 1.5,
							name = L["Display icons"],
							desc = L["Display icons for paragon reputation and reputation bonuses"],
						},
						showrepbar = {
							type = "toggle",
							order = 20,
							width = 1.5,
							name = L["Reputation bar priority"],
							desc = L["Show the reputation bar over the XP / Azerite bar"],
						},
						autowatchrep = {
							type = "toggle",
							order = 30,
							width = 1.5,
							name = L["Auto watch reputation"],
							desc = L["Automatically switch watched faction to one you gain reputation with"],
						},
						autotrackguild = {
							type = "toggle",
							order = 40,
							width = 1.5,
							name = L["Auto watch guild reputation"],
							desc = L["Automatically track your guild reputation increases"],
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
									width = 1.5,
									name = L["Reputation text"],
									desc = L["Set reputation text color"],
									hasAlpha = true,
								},
								exalted = {
									type = "color",
									order = 20,
									width = 1.5,
									name = _G.FACTION_STANDING_LABEL8,
									desc = L["Set exalted reputation bar color"],
									hasAlpha = true,
								},
							},
						},
					},
				},
			},
		}
	end
	if appName == (addonName .. "-Help") then
		local function makeGroupTitle(key)
			return "|cffffff00[" .. key .. "]|r"
		end
		return {
			type = "group",
			name = L["Help on format"],
			childGroups = "tab",
			args = {
				bardesc = {
					type = "description",
					order = 0,
					name = L["Format templates for XP / reputation / azerite power bars"],
				},
				xpgroup = {
					type = "group",
					order = 10,
					name = L["Experience Bar"],
					width = "full",
					args = CreateGroupItems(
						L["HELP.XPBARTEMPLATE"],
						{
							{ "curXP",	L["Current XP value on the level"] },
							{ "maxXP",	L["Maximum XP value for the current level"] },
							{ "needXP",	L["Remaining XP value till the next level"] },
							{ "restXP",	L["Rested XP bonus value"] },
							{ "curPC",	L["Current XP value in percents"] },
							{ "needPC",	L["Remaining XP value in percents"] },
							{ "restPC",	L["Rested XP bonus value in percents of maximum XP value"] },
							{ "pLVL",	L["Current level"] },
							{ "nLVL",	L["Next level"] },
							{ "mLVL",	L["Maximum character level (current level when XP gain is disabled"] },
							{ "KTL",	L["Remaining kill number till next level"] },
							{ "BTL",	L["Remaining bubble (scale tick) number till next level"] },
						},
						makeGroupTitle
					),
				},
				azergroup = {
					type = "group",
					order = 20,
					name = L["Azerite Bar"],
					width = "full",
					args = CreateGroupItems(
						L["HELP.AZBARTEMPLATE"],
						{
							{ "name",	L["Name of artifact necklace: Heart of Azeroth"] },
							{ "curXP",	L["Current azerite power value on the level"] },
							{ "maxXP",	L["Maximum azerite power value for the current level"] },
							{ "needXP",	L["Remaining azerite power value till the next level"] },
							{ "curPC",	L["Current azerite power value in percents"] },
							{ "needPC",	L["Remaining azerite power value in percents"] },
							{ "pLVL",	L["Current azerite level"] },
							{ "nLVL",	L["Next azerite level"] },
						},
						makeGroupTitle
					),
				},
				repgroup = {
					type = "group",
					order = 30,
					name = L["Reputation Bar"],
					width = "full",
					args = CreateGroupItems(
						L["HELP.REPBARTEMPLATE"],
						{
							{ "faction",	L["Watched faction / friend / guild name"] },
							{ "standing",	L["Faction reputation standing"] },
							{ "curRep",		L["Current reputation value for the current standing"] },
							{ "maxRep",		L["Maximum reputation value for the current standing"] },
							{ "needRep",	L["Remaining reputation value till the next standing"] },
							{ "repPC",		L["Current reputation value in percents"] },
							{ "needPC",		L["Remaining reputation value in percents"] },
						},
						makeGroupTitle
					),
				},
			}
		}
	end
end

local function OpenSettings()
	--[[
		First opening Bars subcategory should expand addon options,
		but it does not work now. Although this is required
		for addon main category to be selected in Options dialog.
	]]
	InterfaceOptionsFrame_OpenToCategory(L["Bars"])
	InterfaceOptionsFrame_OpenToCategory(md.title)
end

local function MigrateSettings(sv)
	local function getDBVersion(svVer)
		local ver = svVer or ""
		local verText, c = ver:match("^V(%d+)(C?)$")
		return tonumber(verText) or 0, c and #c > 0
	end
	local dbVer, dbClassic = getDBVersion(sv.VER)

	if sv.profiles then
		for name, data in pairs(sv.profiles) do
			-- new positioning mode
			if dbVer < DB_VERSION_NUM then
				data.general.anchor = "TOPLEFT"
				data.general.anchorRelative = "BOTTOMLEFT"
			end
		end
	end

	sv.VER = DB_VERSION
end

C.EVENT_CONFIG_CHANGED = "ConfigChanged"
C.EVENT_PROFILE_CHANGED = "ProfileChanged"

C.XPLockedReasons = xpLockedReasons
C.MAX_PLAYER_LEVEL = MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()]
C.STANDING_EXALTED = STANDING_EXALTED
C.Anchors = frameAnchors
C.NoAnchor = ""

C.OpenSettings = OpenSettings

function C.GetDB()
	return db
end

function C.GetPlayerMaxLevel()
	if IsXPUserDisabled() then
		return UnitLevel("player"), xpLockedReasons.LOCKED_XP
	elseif (GameLimitedMode_IsActive()) then
		local capLevel = GetRestrictedAccountData()
		return capLevel, xpLockedReasons.MAX_TRIAL_LEVEL
	else
		return C.MAX_PLAYER_LEVEL, xpLockedReasons.MAX_EXPANSION_LEVEL
	end
end

function C.GetFactionStandingLabel(standing)
	return factionStandingLabel[standing]
end

function C.GetReputationColor(standing)
	return reputationColors[standing]
end

function C.RegisterConfigChanged(...)
	configChangedEvent:AddHandler(...)
end

function C.RegisterProfileChanged(...)
	profileChangedEvent:AddHandler(...)
end

function C:OnInitialize()
	Event = XPMultiBar:GetModule("Event")
	Utils = XPMultiBar:GetModule("Utils")

	self.db = LibStub("AceDB-3.0"):New(addonName .. "DB", defaults, true)

	MigrateSettings(self.db.sv)

	db = self.db.profile

	local myName = md.title
	local ACRegistry = LibStub("AceConfigRegistry-3.0")
	local ACDialog = LibStub("AceConfigDialog-3.0")

	ACRegistry:RegisterOptionsTable(addonName, GetOptions)
	ACRegistry:RegisterOptionsTable(addonName .. "-Bars", GetOptions)
	ACRegistry:RegisterOptionsTable(addonName .. "-Help", GetOptions)

	ACDialog:AddToBlizOptions(addonName, myName)
	ACDialog:AddToBlizOptions(addonName .. "-Bars", L["Bars"], myName)

	local popts = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	ACRegistry:RegisterOptionsTable(addonName .. "-Profiles", popts)
	ACDialog:AddToBlizOptions(addonName .. "-Profiles", L["Profiles"], myName)

	ACDialog:AddToBlizOptions(addonName .. "-Help", L["Help on format"], myName)

	--[[ TODO: Help tab ]]

	self:RegisterChatCommand("xpbar", OpenSettings)

	self.db.RegisterCallback(self, "OnProfileChanged", self.EVENT_PROFILE_CHANGED)
	self.db.RegisterCallback(self, "OnProfileCopied", self.EVENT_PROFILE_CHANGED)
	self.db.RegisterCallback(self, "OnProfileReset", self.EVENT_PROFILE_CHANGED)

	configChangedEvent = Event:New(C.EVENT_CONFIG_CHANGED)
	profileChangedEvent = Event:New(C.EVENT_PROFILE_CHANGED)
end

function C:ProfileChanged(event, database, newProfileKey)
	db = database.profile
	reputationColors[STANDING_EXALTED] = nil
	profileChangedEvent(db)
end
