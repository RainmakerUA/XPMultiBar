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

local AceDB = LibStub("AceDB-3.0")
local ACRegistry = LibStub("AceConfigRegistry-3.0")
local ACDialog = LibStub("AceConfigDialog-3.0")
local ADBO = LibStub("AceDBOptions-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local Utils

local ALT_KEY = ALT_KEY
local CTRL_KEY = CTRL_KEY
local SHIFT_KEY = SHIFT_KEY
local BACKGROUND = BACKGROUND
local REPUTATION = REPUTATION
local ITEM_QUALITY_COLORS = ITEM_QUALITY_COLORS
local LE_ITEM_QUALITY_ARTIFACT = LE_ITEM_QUALITY_ARTIFACT
local MAX_PLAYER_LEVEL_TABLE = MAX_PLAYER_LEVEL_TABLE

local _G = _G
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local type = type
local unpack = unpack

local GameLimitedMode_IsActive = GameLimitedMode_IsActive
local GetAddOnMetadata = GetAddOnMetadata
local GetExpansionLevel = GetExpansionLevel
local GetRestrictedAccountData = GetRestrictedAccountData
local InterfaceOptionsFrame_OpenToCategory = InterfaceOptionsFrame_OpenToCategory
local IsXPUserDisabled = IsXPUserDisabled
local UnitLevel = UnitLevel

local AceGUIWidgetLSMlists = AceGUIWidgetLSMlists

-- Remove all known globals after this point
-- luacheck: std none

local DB_VERSION_NUM = 822
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

local FilterBorderTextures

do
	local excludedBorders = {
		["1 Pixel"] = true,
		["Blizzard Chat Bubble"] = true,
		["Blizzard Party"] = true,
		["Details BarBorder 1"] = true,
		["Details BarBorder 2"] = true,
		["None"] = true,
		["Square Full White"] = true,
	}

	FilterBorderTextures = function(textures)
		local result = {}
		for k, v in pairs(textures) do
			if not excludedBorders[k] then
				result[k] = v
			end
		end
		return result
	end
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
			borderTexture = "Blizzard Dialog",
			borderDynamicColor = true,
			borderColor = { r = 0.5, g  = 0.5, b = 0.5, a = 1 },
			bubbles = false,
			commify = true,
			hidestatus = true,
		},
		bars = {
			-- XP bar
			xpstring = "Exp: [curXP]/[maxXP] ([restPC]) :: [curPC] through [pLVL] lvl :: [needXP] XP left :: [KTL] kills to lvl",
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
		reputation = {
			showRepMenu = true,
			menuScale = 1,
			menuAutoHideDelay = 2,
			watchedFactionLineColor = { r = 0.3, g = 1, b = 1, a = 0.5 },
			favoriteFactionLineColor = { r = 1, g = 0.3, b = 1, a = 0.5 },
			showFavorites = false,
			showFavInCombat = false,
			showFavoritesModCtrl = false,
			showFavoritesModAlt = false,
			showFavoritesModShift = false,
			favorites = {},
		},
	}
}

local function CreateGetSetColorFunctions(section, postFunc)
	return function(info)
				local col = db[section][info[#info]]
				return col.r, col.g, col.b, col.a or 1
			end,
			function(info, r, g, b, a)
				local key = info[#info]
				local col = db[section][key]
				col.r, col.g, col.b, col.a = r, g, b, a
				if type(postFunc) == "function" then
					postFunc(key, col)
				end
			end
end

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

	local getBorderColor, setBorderColor = CreateGetSetColorFunctions("general")
	local function setBorder(info, r, g, b, a)
		local key = info[#info]
		if key == "borderColor" then
			setBorderColor(info, r, g, b, a)
		else
			db.general[key] = r
		end
		onConfigChanged("border", db.general)
	end

	local getBarColor, setBarColor = CreateGetSetColorFunctions(
															"bars",
															function(key, color)
																if key == "exalted" then
																	onConfigChanged("exaltedColor", color)
																elseif key == "background" then
																	onConfigChanged("bgColor", color)
																end
															end
														)
	local getRepColor, setRepColor = CreateGetSetColorFunctions("reputation")

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
								borderTexture = {
									type = "select",
									order = 2000,
									width = 1.5,
									disabled = isBorderOptionsDisabled,
									name = L["Border style"],
									desc = L["Set border style (texture)"],
									dialogControl = "LSM30_Border",
									values = FilterBorderTextures(AceGUIWidgetLSMlists.border),
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
							get = getBarColor,
							set = setBarColor,
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
							get = getBarColor,
							set = setBarColor,
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
						azerDisplayDesc = {
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
							get = getBarColor,
							set = setBarColor,
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
	if appName == (addonName .. "-Reputation") then
		local t = Utils.Text
		return {
			type = "group",
			name = REPUTATION,
			childGroups = "tab",
			get = function(info) return db.reputation[info[#info]] end,
			set = function(info, value) db.reputation[info[#info]] = value end,
			args = {
				bardesc = {
					type = "description",
					order = 0,
					name = L["Settings for reputation menu and favorite factions"],
				},
				repMenuGroup = {
					type = "group",
					order = 10,
					name = L["Reputation Menu"],
					guiInline = true,
					width = "full",
					args = {
						showRepMenu = {
							type = "toggle",
							order = 100,
							width = "full",
							name = L["Show reputation menu"],
							-- luacheck: ignore
							desc = L["Show reputation menu instead of standard Reputation window when |CFFFFFF20Ctrl+Right Button|r on the panel"],
						},
						menuScale = {
							type = "range",
							order = 200,
							width = 1.5,
							disabled = not db.reputation.showRepMenu,
							name = L["Scale"],
							desc = L["Set reputation menu scale"],
							min = 0.5,
							max = 2,
							step = 0.1,
						},
						menuAutoHideDelay = {
							type = "range",
							order = 300,
							width = 1.5,
							disabled = not db.reputation.showRepMenu,
							name = L["Autohide Delay"],
							desc = L["Set reputation menu autohide delay time (in seconds)"],
							min = 0,
							max = 5,
						},
						watchedFactionLineColor = {
							type = "color",
							order = 400,
							width = 1.5,
							disabled = not db.reputation.showRepMenu,
							name = L["Watched Faction Line Color"],
							desc = L["Set the color of watched faction menu line"],
							hasAlpha = true,
							get = getRepColor,
							set = setRepColor,
						},
						favoriteFactionLineColor = {
							type = "color",
							order = 500,
							width = 1.5,
							disabled = not (db.reputation.showRepMenu and db.reputation.showFavorites),
							name = L["Favorite Faction Line Color"],
							desc = L["Set the color of favorite faction menu lines"],
							hasAlpha = true,
							get = getRepColor,
							set = setRepColor,
						},
					},
				},
				favRepGroup = {
					type = "group",
					order = 20,
					name = L["Favorite Factions"],
					guiInline = true,
					width = "full",
					args = {
						showFavorites = {
							type = "toggle",
							order = 100,
							width = 1.5,
							name = L["Show favorite factions"],
							desc = L["Show favorite faction popup when mouse is over the bar"],
						},
						showFavInCombat = {
							type = "toggle",
							order = 200,
							width = 1.5,
							disabled = not db.reputation.showFavorites,
							name = L["Show in combat"],
							desc = L["Show favorite faction popup when in combat"],
						},
						showFavoritesMods = {
							type = "description",
							order = 300,
							fontSize = "medium",
							disabled = not db.reputation.showFavorites,
							name = L["Show favorite faction popup only when modifiers are pressed"],
						},
						showFavoritesModCtrl = {
							type = "toggle",
							order = 400,
							disabled = not db.reputation.showFavorites,
							name = CTRL_KEY,
							desc = L["|CFFFFFF20Ctrl|r must be pressed"],
						},
						showFavoritesModAlt = {
							type = "toggle",
							order = 500,
							disabled = not db.reputation.showFavorites,
							name = ALT_KEY,
							desc = L["|CFFFFFF20Alt|r must be pressed"],
						},
						showFavoritesModShift = {
							type = "toggle",
							order = 600,
							disabled = not db.reputation.showFavorites,
							name = SHIFT_KEY,
							desc = L["|CFFFFFF20Shift|r must be pressed"],
						},
						noFavoriteFactionsDesc = {
							type = "description",
							order = 700,
							fontSize = "medium",
							hidden = not db.reputation.showFavorites
										or next(db.reputation.favorites) ~= nil,
							name = t.GetWarning(L["WARNING.NOFAVORITEFACTIONS"]),
						},
						favoriteFactionsDesc = {
							type = "description",
							order = 800,
							fontSize = "medium",
							name = t.GetInfo(L["HELP.FAVORITEFACTIONS"]),
						},
					},
				},
			}
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
			if dbVer < 821 then
				data.general.anchor = "TOPLEFT"
				data.general.anchorRelative = "BOTTOMLEFT"
			end
			-- border texture picker
			if dbVer < 822 then
				local borderTexNames = {
									"Blizzard Dialog", "Blizzard Toast",
									"Blizzard Minimap Tooltip", "Blizzard Tooltip"
								}
				if not data.general.borderTexture then
					local style = data.general.borderStyle or 1
					local tex = borderTexNames[style]
					data.general.borderTexture = tex
					data.general.borderStyle = nil
				end
			end
		end
	end

	sv.VER = DB_VERSION
end

C.EVENT_CONFIG_CHANGED = "ConfigChanged"
C.EVENT_PROFILE_CHANGED = "ProfileChanged"

C.XPLockedReasons = xpLockedReasons
C.MAX_PLAYER_LEVEL = MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()]
C.Anchors = frameAnchors
C.NoAnchor = ""

C.OpenSettings = OpenSettings

function C.GetDB()
	return db
end

function C.GetPlayerMaxLevel()
	if IsXPUserDisabled() then
		return UnitLevel("player"), xpLockedReasons.LOCKED_XP
	elseif GameLimitedMode_IsActive() then
		local capLevel = GetRestrictedAccountData()
		return capLevel, xpLockedReasons.MAX_TRIAL_LEVEL
	else
		return C.MAX_PLAYER_LEVEL, xpLockedReasons.MAX_EXPANSION_LEVEL
	end
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

	--@debug@
	-- L = Utils.DebugL(L)
	--@end-debug@

	self.db = AceDB:New(addonName .. "DB", defaults, true)

	MigrateSettings(self.db.sv)

	db = self.db.profile

	local myName = md.title

	ACRegistry:RegisterOptionsTable(addonName, GetOptions)
	ACRegistry:RegisterOptionsTable(addonName .. "-Bars", GetOptions)
	ACRegistry:RegisterOptionsTable(addonName .. "-Reputation", GetOptions)
	ACRegistry:RegisterOptionsTable(addonName .. "-Help", GetOptions)

	local popts = ADBO:GetOptionsTable(self.db)
	ACRegistry:RegisterOptionsTable(addonName .. "-Profiles", popts)

	ACDialog:AddToBlizOptions(addonName, myName)
	ACDialog:AddToBlizOptions(addonName .. "-Bars", L["Bars"], myName)
	ACDialog:AddToBlizOptions(addonName .. "-Reputation", REPUTATION, myName)
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
	profileChangedEvent(db)
end
