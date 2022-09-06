--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_Config.lua - module
		Configuration and initialization for XPMultiBar addon
--]=====]

local addonName = ...
local Utils = LibStub("rmUtils-1.1")
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Config = XPMultiBar:NewModule("Config", "AceConsole-3.0")

local wowClassic = true

local C = Config

local AceDB = LibStub("AceDB-3.0")
local ACRegistry = LibStub("AceConfigRegistry-3.0")
local ACDialog = LibStub("AceConfigDialog-3.0")
local ACCmd = LibStub("AceConfigCmd-3.0")
local ADBO = LibStub("AceDBOptions-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local ALT_KEY = ALT_KEY
local CTRL_KEY = CTRL_KEY
local SHIFT_KEY = SHIFT_KEY
local BACKGROUND = BACKGROUND
local REPUTATION = REPUTATION
local ITEM_QUALITY_COLORS = ITEM_QUALITY_COLORS
local MAX_PLAYER_LEVEL = MAX_PLAYER_LEVEL
local OFF = OFF
local KEY_BUTTON1 = KEY_BUTTON1
local KEY_BUTTON2 = KEY_BUTTON2
local KEY_BUTTON3 = KEY_BUTTON3
local TRACKER_SORT_MANUAL = TRACKER_SORT_MANUAL

local _G = _G
local ipairs = ipairs
local next = next
local pairs = pairs
local print = print
local tconcat = table.concat
local tonumber = tonumber
local tostring = tostring
local type = type
local unpack = unpack

local GameLimitedMode_IsActive = GameLimitedMode_IsActive
local GetAddOnMetadata = GetAddOnMetadata
local GetLocale = GetLocale
local GetRestrictedAccountData = GetRestrictedAccountData
local InterfaceOptionsFrame_OpenToCategory = InterfaceOptionsFrame_OpenToCategory
local IsXPUserDisabled = IsXPUserDisabled or Utils.EmptyFn
local UnitLevel = UnitLevel

local ARTIFACT_QUALITY_TYPE = Enum.ItemQuality.Artifact;

local AceGUIWidgetLSMlists = AceGUIWidgetLSMlists

-- Remove all known globals after this point
-- luacheck: std none

local DB_VERSION_NUM = 10
local DB_VERSION = "V" .. tostring(DB_VERSION_NUM)

--@debug@
L = Utils.DebugL(L)
--@end-debug@

local md = {
	title = GetAddOnMetadata(addonName, "Title"),
	notes = GetAddOnMetadata(addonName, "Notes"),
	author = GetAddOnMetadata(addonName, "Author"),
	version = GetAddOnMetadata(addonName, "Version"),
	date = GetAddOnMetadata(addonName, "X-ReleaseDate"),
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
	local color = ITEM_QUALITY_COLORS[ARTIFACT_QUALITY_TYPE]
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

local slashCmd = "xpbar"

local empty = "-"

local appNames = {
	main = { addonName, nil },
	general = { addonName .. "-General", L["General"] },
	bars = { addonName .. "-Bars", L["Bars"] },
	reputation = { addonName .. "-Reputation", REPUTATION },
	help = { addonName .. "-Help", L["Help"] },
	profiles = { addonName .. "-Profiles", L["Profiles"] },
}

-- Bar codes
local X, A, R = 1, 2, 3

-- Mouse button codes
local LMB, RMB, MMB = "L", "R", "M"

local buttons = {
	[LMB] = "LeftButton",
	[RMB] = "RightButton",
	[MMB] = "MiddleButton"
}

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
			anchorRelative = empty,
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
			borderColor = { r = 0.5, g = 0.5, b = 0.5, a = 1 },
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
			-- Reputation bar
			repstring = "Rep: [faction] ([standing]) [curRep]/[maxRep] :: [repPC]",
			repicons = true,
			-- Bar colors
			normal = { r = 0.8, g = 0, b = 1, a = 1 },
			rested = { r = 0, g = 0.4, b = 1, a = 1 },
			resting = { r = 1.0, g = 0.82, b = 0.25, a = 1 },
			remaining = { r = 0.82, g = 0, b = 0, a = 1 },
			background = { r = 0.5, g = 0.5, b = 0.5, a = 0.5 },
			exalted = { r = 0, g = 0.77, b = 0.63, a = 1 },
			xptext = { r = 1, g = 1, b = 1, a = 1 },
			reptext = { r = 1, g = 1, b = 1, a = 1 },
			-- Bar priority
			priority = wowClassic
						and {
							X, R, 0,
							0, 0, 0,
							R, X, 0,
							0, 0, 0,
						}
						or {
							X, R, 0,
							X, R, A,
							A, R, X,
							R, A, X,
							R, X, 0
						},
		},
		reputation = {
			autowatchrep = false,
			autotrackguild = false,
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
		mouse = {
			{
				key = { shift = true, button = LMB },
				action = "actions:linktext",
				locked = true,
			},
			{
				key = { shift = true, button = RMB },
				action = "actions:settings",
				locked = true,
			},
			{
				key = { ctrl = true, button = RMB },
				action = "actions:repmenu",
				locked = true,
			},
		}
	}
}

local GetOptions, GetHelp

do
	local GROUPS = wowClassic and 4 or 5
	local BARS_IN_GROUP = 3
	local FLAG_NOTEXT = 4
	local priorities
	do
		local N = FLAG_NOTEXT
		priorities = wowClassic
						and {
								{ X, R, 0, 0, 0, 0, R, X, 0, 0, 0, 0, },
								{},
								{ R, X, 0, 0, 0, 0, R, X, 0, 0, 0, 0, },
								-- No-Text presets
								{ X+N, X, R, 0, 0, 0, R+N, R, X, 0, 0, 0, },
								{},
								{ R+N, R, X, 0, 0, 0, R+N, R, X, 0, 0, 0, },
							}
						or {
								{ X, R, 0, X, R, A, A, R, X, R, A, X, R, X, 0, },
								{ X, R, 0, A, R, X, A, R, X, R, A, X, R, X, 0, },
								{ R, X, 0, R, X, A, R, A, X, R, A, X, R, X, 0, },
								-- No-Text presets
								{ X+N, X, R, X+N, X, R, A+N, A, R, R+N, R, X, R+N, R, X, },
								{ X+N, X, R, A+N, A, R, A+N, A, R, R+N, R, A, R+N, R, X, },
								{ R+N, R, X, R+N, R, X, R+N, R, A, R+N, R, 0, R+N, R, X, },
							}
	end
	C.FLAG_NOTEXT = FLAG_NOTEXT

	local MOUSE_ACTIONS = 16

	local modNames = Utils.Map(
		{ ctrl = CTRL_KEY, alt = ALT_KEY, shift = SHIFT_KEY },
		function(v)
			local first, rest = v:match("([A-Z])([A-Z]+)")
			if not first or not rest then
				first, rest = v:sub(1, 1), v:sub(2)
			end
			return first:upper() .. rest:lower()
		end
	)

	local mouseButtonValues = {
		[empty] = OFF,
		[LMB] = KEY_BUTTON1,
		[RMB] = KEY_BUTTON2,
		[MMB] = KEY_BUTTON3,
	}

	local mouseButtonShortNames = {
		[empty] = OFF,
		[LMB] = L["Left Button"],
		[RMB] = L["Right Button"],
		[MMB] = L["Middle Button"],
	}

	local function MakeActionName(topic, ...)
		return ("%s: %s"):format(topic, tconcat({...}, " > "))
	end

	local actionsTopic = L["Actions"]
	local settingsTopic = L["Settings"]
	local generalSub = L["General"]
	local barsSub = L["Bars"]
	local prioritySub = L["Priority"]
	local reputationSub = L["Reputation"]

	local actions = {
		[empty] = MakeActionName(settingsTopic, TRACKER_SORT_MANUAL),
		["actions:linktext"] = MakeActionName(actionsTopic, L["Copy bar text to the chat"]),
		["actions:settings"] = MakeActionName(actionsTopic, L["Open addon settings"]),
		["actions:repmenu"] = MakeActionName(actionsTopic, L["Open reputation menu"]),
		["settings:general posGroup locked"]
				= MakeActionName(settingsTopic, generalSub, L["Lock bar movement"]),
		["settings:general posGroup clamptoscreen"]
				= MakeActionName(settingsTopic, generalSub, L["Clamp bar with screen borders"]),
		["settings:general visGroup bubbles"]
				= MakeActionName(settingsTopic, generalSub, L["Show ticks on the bar"]),
		["settings:general visGroup border"]
				= MakeActionName(settingsTopic, generalSub, L["Show bar border"]),
		["settings:bars prioGroup buttongroup setDefaultPrio"]
				= MakeActionName(settingsTopic, barsSub, prioritySub, L["Set XP bar priority"]),
		["settings:bars prioGroup buttongroup setReputationPrio"]
				= MakeActionName(settingsTopic, barsSub, prioritySub, L["Set reputation bar priority"]),
		["settings:reputation autowatchrep"] = MakeActionName(settingsTopic, reputationSub, L["Auto track reputation"]),
		-- luacheck: ignore
		["settings:reputation autotrackguild"] = MakeActionName(settingsTopic, reputationSub, L["Auto track guild reputation"]),
		["settings:reputation showFavorites"] = MakeActionName(settingsTopic, reputationSub, L["Show favorite factions"]),
		["settings:reputation showRepMenu"] = MakeActionName(settingsTopic, reputationSub, L["Show reputation menu"]),
	}

	if not wowClassic then
		actions["settings:bars prioGroup buttongroup setAzeritePrio"]
				= MakeActionName(settingsTopic, barsSub, prioritySub, L["Set Azerite power bar priority"])
	end

	local icons = {
		exclamation = [[|Tinterface\gossipframe\availablelegendaryquesticon:0|t]],
		locked = [[|Tinterface\petbattles\petbattle-lockicon:17:19:-4:0|t]]
	}

	local optionsTrace

	local function FormatDate(dateMeta)
		if tonumber(dateMeta) then
			local year = tonumber(dateMeta:sub(1, 4))
			local month = tonumber(dateMeta:sub(5, 6))
			local day = tonumber(dateMeta:sub(7, 8))
			return ("%02d.%02d.%04d"):format(day, month, year)
		else
			return dateMeta
		end
	end

	local function FormatKeyColor(name)
		return Utils.Text.GetKey(name)
	end

	local function GetIndex(key)
		local s1, s2 = key:match("^pg_(%d)_[a-z]+_(%d)$")
		local i1, i2 = tonumber(s1), tonumber(s2)
		return (i1 - 1) * BARS_IN_GROUP + i2
	end

	local function PrintWrongIndex(index)
		print("|cFFFFFF00[XPMultiBar]:|r", Utils.Text.GetError(L["Priority group index is wrong: %d"]:format(index)))
	end

	local function UpdateBars(prio)
		configChangedEvent("priority", prio)
	end

	local function GetPriority(info)
		local index = GetIndex(info[#info])
		if index >= 1 and index <= BARS_IN_GROUP * GROUPS then
			return db.bars.priority[index] % FLAG_NOTEXT
		else
			PrintWrongIndex(index)
			return 0
		end
	end

	local function SetPriority(info, value)
		local index = GetIndex(info[#info])
		if index >= 1 and index <= BARS_IN_GROUP * GROUPS then
			local oldValue = db.bars.priority[index]
			db.bars.priority[index] = value > 0
										and value + (oldValue > FLAG_NOTEXT and FLAG_NOTEXT or 0)
										or 0
			UpdateBars(db.bars.priority)
		else
			PrintWrongIndex(index)
		end
	end

	local function GetShowText(info)
		local index = GetIndex(info[#info])
		if index >= 1 and index <= BARS_IN_GROUP * GROUPS then
			return db.bars.priority[index] < FLAG_NOTEXT
		else
			PrintWrongIndex(index)
			return true
		end
	end

	local function SetShowText(info, value)
		local index = GetIndex(info[#info])
		if index >= 1 and index <= BARS_IN_GROUP * GROUPS then
			local raw = db.bars.priority[index] % FLAG_NOTEXT
			db.bars.priority[index] = raw + (value and 0 or FLAG_NOTEXT)
			UpdateBars(db.bars.priority)
		else
			PrintWrongIndex(index)
		end
	end

	local function GetShowTextDisabled(info)
		return GetPriority(info) == 0
	end

	--[[
		L["PRIOGROUP_1.NAME"] -> Char. level below maximum, no artifact (HoA)
		L["PRIOGROUP_1C.NAME"] -> Char. level below maximum
		L["PRIOGROUP_2.NAME"] -> Char. level below maximum, has artifact (HoA)
		L["PRIOGROUP_3.NAME"] -> Char. level maximum, artifact power below maximum
		L["PRIOGROUP_3C.NAME"] -> Char. level maximum
		L["PRIOGROUP_4.NAME"] -> Char. level maximum, artifact power maximum
		L["PRIOGROUP_5.NAME"] -> Char. level maximum, no artifact (HoA)
	]]

	local function CreatePriorityGroups()
		local barsNoAzerite = {
			[0] = L["Off"],
			[X] = L["Experience Bar"],
			[R] = L["Reputation Bar"],
		}
		local bars = (not wowClassic) and Utils.Merge({ [A] = L["Azerite Bar"] }, barsNoAzerite) or barsNoAzerite
		local result = {}
		local textTitle = L["Show text"]
		local textDesc = L["Show text on the bar"]

		for i = 1, GROUPS do
			result["prioritygroup" .. i] = (not wowClassic or i % 2 == 1) and {
				type = "group",
				order = (i + 1) * 100,
				name = L["PRIOGROUP_" .. i .. (wowClassic and "C" or "") .. ".NAME"],
				inline = true,
				width = "full",
				get = GetPriority,
				set = SetPriority,
				args = {
					["pg_" .. i .. "_bar_1"] = {
						order = 1000,
						type = "select",
						name = L["Normal"],
						desc = L["Choose bar to be shown when mouse is not over the bar"],
						values = (i == 1 or i == 5) and barsNoAzerite or bars,
					},
					["pg_" .. i .. "_bar_2"] = {
						order = 2000,
						type = "select",
						name = L["Mouse over"],
						desc = L["Choose bar to be shown when mouse is over the bar"],
						values = (i == 1 or i == 5) and barsNoAzerite or bars,
					},
					["pg_" .. i .. "_bar_3"] = {
						order = 3000,
						type = "select",
						name = L["Mouse over with %s"]:format(FormatKeyColor(modNames.alt)),
						-- luacheck: ignore
						desc = L["Choose bar to be shown when mouse is over the bar while %s key is pressed"]:format(FormatKeyColor(modNames.alt)),
						values = (i == 1 or i == 5) and barsNoAzerite or bars,
					},
					["pg_" .. i .. "_text_1"] = {
						order = 4000,
						type = "toggle",
						name = textTitle,
						desc = textDesc,
						get = GetShowText,
						set = SetShowText,
						disabled = GetShowTextDisabled,
					},
					["pg_" .. i .. "_text_2"] = {
						order = 5000,
						type = "toggle",
						name = textTitle,
						desc = textDesc,
						get = GetShowText,
						set = SetShowText,
						disabled = GetShowTextDisabled,
					},
					["pg_" .. i .. "_text_3"] = {
						order = 6000,
						type = "toggle",
						name = textTitle,
						desc = textDesc,
						get = GetShowText,
						set = SetShowText,
						disabled = GetShowTextDisabled,
					},
				},
			} or nil
		end

		return result
	end

	local function SetPrioritiesFromIndex(index)
		return function()
			db.bars.priority = Utils.Clone(priorities[index] or priorities[1])
			UpdateBars(db.bars.priority)
		end
	end

	local function BooleanEqual(bool1, bool2)
		bool1, bool2 = bool1 and true or false, bool2 and true or false
		return bool1 == bool2
	end

	local function KeyEqual(key1, key2)
		return (key1 and key2) and key1.button ~= empty
				and key1.button == key2.button
				and BooleanEqual(key1.ctrl, key2.ctrl)
				and BooleanEqual(key1.alt, key2.alt)
				and BooleanEqual(key1.shift, key2.shift)
	end

	local function GetMouseCommandName(index, config, configs)
		local key = config.key or {}
		local button = key.button or empty
		local command = { mouseButtonShortNames[button] }
		local prefix = "\32"

		if button ~= empty then
			if key.shift then
				Utils.Unshift(command, modNames.shift)
			end
			if key.alt then
				Utils.Unshift(command, modNames.alt)
			end
			if key.ctrl then
				Utils.Unshift(command, modNames.ctrl)
			end
		end
		-- Add exclamation icon to duplicate mouse shortcuts
		for i, v in ipairs(configs) do
			if i ~= index and KeyEqual(config.key, v.key) then
				prefix = icons.exclamation
				break
			end
		end

		return ("%s%s"):format(
								config.locked and icons.locked or ("%02d."):format(index),
								prefix .. tconcat(command, "-")
							)
	end

	local function GetMouseCommandLocked(config)
		return function()
			return config.locked
		end
	end

	local function GetMouseCommandDisabled(config)
		local locked = GetMouseCommandLocked(config)
		return function()
			return locked() or not config.key
					or not config.key.button or (config.key.button == empty)
		end
	end

	local function MakeMouseCommandGet(index)
		local config = db.mouse[index] or {}
		return function(info)
			local key = info[#info]
			if key == "mouseButton" then
				return config.key and config.key.button or empty
			elseif key == "keyCtrl" then
				return config.key and config.key.ctrl and true or false
			elseif key == "keyAlt" then
				return config.key and config.key.alt and true or false
			elseif key == "keyShift" then
				return config.key and config.key.shift and true or false
			elseif key == "actionChoose" then
				return config.action or empty
			elseif key == "actionEdit" then
				return config.actionText or ""
			end
		end
	end

	local function MakeMouseCommandSet(index)
		return function(info, value)
			local key = info[#info]
			local config = db.mouse[index]
			if not config then
				config = { key = { button = empty }, action = empty }
				db.mouse[index] = config
			end
			if key == "mouseButton" then
				config.key.button = value
			elseif key == "keyCtrl" then
				config.key.ctrl = value and true or nil
			elseif key == "keyAlt" then
				config.key.alt = value and true or nil
			elseif key == "keyShift" then
				config.key.shift = value and true or nil
			elseif key == "actionChoose" then
				if value ~= empty then
					config.actionText = nil
				end
				config.action = value
			elseif key == "actionEdit" then
				config.actionText = value
			end
			-- If entry is empty (has no button and no action), we delete it
			if config.key.button == empty and config.action == empty
					and (not config.actionText or config.actionText == empty) then
				db.mouse[index] = nil
			end
		end
	end

	local function CreateMouseGroupItem(index)
		local config = db.mouse[index] or {}

		return {
			type = "group",
			order = index * 10,
			name = GetMouseCommandName(index, config, db.mouse),
			width = "full",
			get = MakeMouseCommandGet(index),
			set = MakeMouseCommandSet(index),
			args = {
				clickGroup = {
					type = "group",
					order = 10,
					name = L["Mouse Shortcut"],
					inline = true,
					width = "full",
					args = {
						mouseButton = {
							order = 10,
							type = "select",
							width = 1,
							name = L["Mouse Button"],
							desc = L["Choose mouse button"],
							disabled = GetMouseCommandLocked(config),
							values = mouseButtonValues,
						},
						modGroup = {
							type = "group",
							order = 20,
							name = "",
							inline = true,
							width = "full",
							disabled = GetMouseCommandDisabled(config),
							args = {
								keyCtrl = {
									type = "toggle",
									order = 10,
									width = 0.5,
									name = modNames.ctrl,
									desc = L["%s key"]:format(FormatKeyColor(modNames.ctrl)),
								},
								keyAlt = {
									type = "toggle",
									order = 20,
									width = 0.5,
									name = modNames.alt,
									desc = L["%s key"]:format(FormatKeyColor(modNames.alt)),
								},
								keyShift = {
									type = "toggle",
									order = 30,
									width = 0.5,
									name = modNames.shift,
									desc = L["%s key"]:format(FormatKeyColor(modNames.shift)),
								},
							},
						},
					},
				},
				actionGroup = {
					type = "group",
					order = 20,
					name = L["Action"],
					inline = true,
					width = "full",
					disabled = GetMouseCommandDisabled(config),
					args = {
						actionChoose = {
							order = 10,
							type = "select",
							width = "full",
							name = "",
							desc = L["Choose click action"],
							values = actions,
						},
						actionEdit = {
							order = 20,
							type = "input",
							width = "full",
							name = "",
							desc = L["Enter settings action text"],
							hidden = function() return config.action ~= empty end,
						},
					},
				},
			},
		}
	end

	local function CreateGroupItems(description, items)
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
			local tag = "[" .. k .. "]"
			result[k] = {
				name = vv,
				type = "group",
				order = (i + 1) * 10,
				width = "full",
				inline = true,
				args = {
					text = {
						type = "input",
						name = "",
						width = "full",
						get = function() return tag end,
						dialogControl = "InteractiveText",
					},
				}
			}
		end

		return result
	end

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

	function GetOptions(uiTypes, uiName, appName)
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
        local isRu = GetLocale() == "ruRU"

		if appName == addonName then
			return {
				type = "group",
				order = 0,
				name = md.title,
				args = {
					descr = {
						type = "description",
						order = 0,
						name = md.notes
					},
					releaseData = {
						type = "group",
						order = 10,
						name = "",
						inline = true,
						width = "full",
						args = {
							author = {
								type = "input",
								order = 10,
								name = L["Author"],
								get = function() return md.author end,
								dialogControl = "InteractiveText",
							},
							version = {
								type = "input",
								order = 20,
								name = L["Version"],
								get = function() return md.version end,
								dialogControl = "InteractiveText",
							},
							date = {
								type = "input",
								order = 30,
								name = L["Date"],
								get = function() return FormatDate(md.date) end,
								dialogControl = "InteractiveText",
							},
						},
					},
					globalGroup = {
						type = "group",
						order = 20,
						name = "",
						inline = true,
						width = "full",
						get = function(info)
							local key = info[#info]
							return C.db.sv[key]
						end,
						set = function(info, value)
							local key = info[#info]
							C.db.sv[key] = value
						end,
						args = {
							showStartupMessage = isRu and {
                                type = "description",
                                order = 0,
                                name = L["MESSAGE.WELCOME"]
                            } or {
								type = "toggle",
								order = 0,
								width = "full",
								name = L["Show message on player login"],
								desc = L["Show 'Thank you...' message on player login"],
							},
						},
					},
				},
			}
		end
		if appName == (addonName .. "-General") then
			local anchors = Utils.Clone(frameAnchors)
			local anchorValues = Utils.Map(anchors, function(val)
				return ("%s (%s)"):format(L["ANCHOR." .. val], val)
			end)
			local relAnchorValues = Utils.Merge({ [empty] = L["Same as Anchor"] }, anchorValues)
			local isBorderOptionsDisabled = function() return not db.general.border end
			local isBorderColorDisabled = function()
				return not db.general.border or db.general.borderDynamicColor
			end
			local mouseArgs = {}
			for i = 1, MOUSE_ACTIONS do
				mouseArgs["mouseAction" .. i] = CreateMouseGroupItem(i)
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
								inline = true,
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
								inline = true,
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
										step = 0.1,
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
								inline = true,
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
								inline = true,
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
					-- Mouse
					mouseGroup = {
						type = "group",
						order = 40,
						childGroups = "tree",
						name = L["Mouse actions"],
						width = "full",
						args = mouseArgs,
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
						name = L["Options for XP / reputation bars"],
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
								order = 35,
								width = 1.5,
								name = L["Display icons"],
								desc = L["Display icons for max. level, disabled XP gain and level cap due to limited account"],
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
								inline = true,
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
					azergroup = (not wowClassic) and {
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
							azercolorgroup = {
								type = "group",
								order = 40,
								name = "",
								inline = true,
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
						},
					} or nil,
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
								order = 45,
								width = 1.5,
								name = L["Display icons"],
								desc = wowClassic and L["Display icon you are at war with the faction"]
										or L["Display icons for paragon reputation and reputation bonuses"],
							},
							repcolorgroup = {
								type = "group",
								order = 50,
								name = "",
								inline = true,
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
					priogroup = {
						type = "group",
						order = 40,
						name = L["Bar Priority"],
						width = "full",
						args = Utils.Merge( {
									buttongroup = {
										type = "group",
										order = 900,
										name = L["Activate preset"],
										inline = true,
										width = "full",
										args = {
											presetsWithTextDesc = {
												type = "description",
												order = 0,
												name = L["Presets with text always visible"],
											},
											setDefaultPrio = {
												type = "execute",
												order = 1000,
												width = wowClassic and 1.5 or 1,
												name = L["XP bar priority"],
												desc = L["Activate preset with priority for XP bar display"],
												func = SetPrioritiesFromIndex(1)
											},
											setAzeritePrio = (not wowClassic) and {
												type = "execute",
												order = 2000,
												name = L["Azerite bar priority"],
												desc = L["Activate preset with priority for Azerite power bar display"],
												func = SetPrioritiesFromIndex(2)
											} or nil,
											setReputationPrio = {
												type = "execute",
												order = 3000,
												width = wowClassic and 1.5 or 1,
												name = L["Reputation bar priority"],
												desc = L["Activate preset with priority for Reputation bar display"],
												func = SetPrioritiesFromIndex(3)
											},
											presetsWithoutTextDesc = {
												type = "description",
												order = 3500,
												name = L["Presets with text show on mouseover"],
											},
											setDefaultPrioNoText = {
												type = "execute",
												order = 4000,
												width = wowClassic and 1.5 or 1,
												name = L["XP bar priority"],
												desc = L["Activate preset with priority for XP bar display"],
												func = SetPrioritiesFromIndex(4)
											},
											setAzeritePrioNoText = (not wowClassic) and {
												type = "execute",
												order = 5000,
												name = L["Azerite bar priority"],
												desc = L["Activate preset with priority for Azerite power bar display"],
												func = SetPrioritiesFromIndex(5)
											} or nil,
											setReputationPrioNoText = {
												type = "execute",
												order = 6000,
												width = wowClassic and 1.5 or 1,
												name = L["Reputation bar priority"],
												desc = L["Activate preset with priority for Reputation bar display"],
												func = SetPrioritiesFromIndex(6)
											},
										},
									},
								},
								CreatePriorityGroups()
							),
					}
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
					trackinggroup = {
						type = "group",
						order = 10,
						name = L["Tracking"],
						inline = true,
						width = "full",
						args = {
							autowatchrep = {
								type = "toggle",
								order = 100,
								width = 1.5,
								name = L["Auto track reputation"],
								desc = L["Automatically switch watched faction to one you gain reputation with"],
							},
							autotrackguild = {
								type = "toggle",
								order = 200,
								width = 1.5,
								name = L["Auto track guild reputation"],
								desc = L["Automatically track your guild reputation increases"],
							},
						},
					},
					repMenuGroup = {
						type = "group",
						order = 30,
						name = L["Reputation Menu"],
						inline = true,
						width = "full",
						args = {
							showRepMenu = {
								type = "toggle",
								order = 100,
								width = "full",
								name = L["Show reputation menu"],
								desc = L["Show reputation menu instead of standard Reputation window"],
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
						order = 40,
						name = L["Favorite Factions"],
						inline = true,
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
								name = modNames.ctrl,
								desc = L["%s must be pressed"]:format(FormatKeyColor(modNames.ctrl)),
							},
							showFavoritesModAlt = {
								type = "toggle",
								order = 500,
								disabled = not db.reputation.showFavorites,
								name = modNames.alt,
								desc = L["%s must be pressed"]:format(FormatKeyColor(modNames.alt)),
							},
							showFavoritesModShift = {
								type = "toggle",
								order = 600,
								disabled = not db.reputation.showFavorites,
								name = modNames.shift,
								desc = L["%s must be pressed"]:format(FormatKeyColor(modNames.shift)),
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
	end

	local function TraceSettings(key, table)
		local function Error(msg)
			-- print("TraceSettings error:", msg)
		end
		local function Trace(tabkey, tab, parents, output)
			if type(tabkey) ~= "string" then
				return Error("illegal tab key under " .. tconcat(parents))
			end
			if tabkey == "main" or tabkey == "mouseGroup" or tabkey:sub(1, 3) == "pg_" then
				return Error("skipped " .. tabkey .. " under " .. tconcat(parents))
			end
			if type(tab) ~= "table" or type(tab.type) ~= "string" then
				return Error("malformed option table under " .. tconcat(parents))
			end
			if tab.type == "group" then
				if type(tab.args) ~= "table" then
					return Error("malformed group element under " .. tconcat(parents))
				end
				local newParents = Utils.Clone(parents)
				if not (tab.inline or tab.guiInline) then
					Utils.Push(newParents, tabkey)
				end
				for k, v in pairs(tab.args) do
					Trace(k, v, newParents, output)
				end
			elseif tab.type == "description" or tab.type == "header" then
				return
			else
				local vals
				if tab.type == "execute" then
					vals = ""
				elseif tab.type == "input" then
					vals = "<value>"
				elseif tab.type == "toggle" then
					vals = "<none>|on|off"
				elseif tab.type == "range" then
					vals = tostring(tab.min) .. ".." .. tostring(tab.max)
				elseif tab.type == "select" then
					local values = type(tab.values) == "function" and tab.values() or tab.values
					vals = tconcat(Utils.Keys(values), "|")
				elseif tab.type == "color" then
					vals = "RRGGBBAA||r g b a"
				else
					vals = "???"
				end
				Utils.Push(output, { cmd = tconcat(parents, "\32") .. "\32" .. tabkey, desc = tab.desc, name = tab.name, vals = vals })
			end
		end
		local out = {}
		Trace(key, table, {}, out)
		return out
	end

	local function GetOptionsTrace(appNames, getOptions)
		local apps = {}
		for k, v in pairs(appNames) do
			apps[k] = TraceSettings(k, getOptions(nil, nil, v[1]))
		end
		return apps
	end

	local function GetTrace()
		if not optionsTrace then
			optionsTrace = GetOptionsTrace(appNames, GetOptions)
		end
		return optionsTrace
	end

	local function GetOptionHelpItem(index, item)
		local vals, cmd
		if item.vals:len() > 20 then
			vals, cmd = item.vals, item.cmd .. "\32<value>"
		else
			vals, cmd = nil, item.cmd .. "\32" .. item.vals
		end
		return ("opthelp_%02d"):format(index), {
			type = "group",
			order = index * 10,
			name = item.name,
			width = "full",
			inline = true,
			args = {
				cmdInput = {
					type = "input",
					dialogControl = "InteractiveText",
					order = 10,
					name = "",
					width = "full",
					get = function() return cmd end,
					set = Utils.EmptyFn,
				},
				valInput = vals and {
					type = "input",
					dialogControl = "InteractiveText",
					order = 20,
					name = "",
					width = "full",
					get = function() return vals end,
					set = Utils.EmptyFn,
				} or nil,
			},
		}
	end

	local function GetOptionHelpTab(tabIndex, key, tabItem)
		local tabArgs = {}
		for i, v in ipairs(tabItem) do
			local itemKey, item = GetOptionHelpItem(i, v)
			tabArgs[itemKey] = item
		end
		return "optHelp_" .. key, {
			type = "group",
			order = tabIndex * 10,
			name = appNames[key][2] or "!NONAME!",
			width = "full",
			args = tabArgs,
		}
	end

	function GetHelp(uiTypes, uiName, appName)
		local optArgs = {
			optHeader = {
				type = "header",
				order = 0,
				name = L["Commands for setting options values"],
			},
		}
		local tabIndex = 1
		for k, v in pairs(GetTrace()) do
			if #k > 0 and v and #v > 0 then
				local key, item = GetOptionHelpTab(tabIndex, k, v)
				optArgs[key] = item
				tabIndex = tabIndex + 1
			end
		end
		if appName == (addonName .. "-Help") then
			return {
				type = "group",
				name = L["Please select help section"],
				childGroups = "select",
				args = {
					formatHelp = {
						type = "group",
						name = L["Help on format"],
						childGroups = "tab",
						order = 10,
						args = {
							bardesc = {
								type = "header",
								order = 0,
								name = wowClassic and L["Format templates for XP and reputation bars"]
										or L["Format templates for XP / reputation / azerite power bars"],
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
									}
								),
							},
							azergroup = (not wowClassic) and {
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
									}
								),
							} or nil,
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
									}
								),
							},
						},
					},
					optionsHelp = {
						type = "group",
						name = L["Help on options"],
						order = 20,
						childGroups = "tab",
						args = optArgs,
					},
				},
			}
		end
	end
end

local function OpenSettings()
	--[[
		First opening Bars subcategory should expand addon options,
		but it does not work now. Although this is required
		for addon root category to be selected in Options dialog.
		UPD: It works when opening General after Bars.
	]]
	InterfaceOptionsFrame_OpenToCategory(L["Bars"])
	InterfaceOptionsFrame_OpenToCategory(L["General"])
end

local function HandleSettingsCommand(input)
	input = (input or ""):trim()
	if input == "" then
		OpenSettings()
	else
		local sub, command = input:match("^(%S+)%s+(.+)$")
		local tabName = sub and appNames[sub][1] or nil
		if tabName then
			ACCmd.HandleCommand(C, slashCmd, tabName, command)
		end
	end
end

local function MigrateSettings(sv)
	local function getDBVersion(svVer)
		local ver = svVer or ""
		local verText, c = ver:match("^V(%d+)(C?)$")
		return tonumber(verText) or 0, c and #c > 0
	end
	local dbVer, dbClassic = getDBVersion(sv.VER)

	if dbVer > 10 then
		sv.showStartupMessage = true

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
				if dbVer < 823 then
					-- Bar priority
					local bars = data.bars
					if bars then
						--[[ No migration ]]
						bars.showmaxlevel = nil
						bars.showmaxazerite = nil
						bars.showrepbar = nil
						-- AutoTracking settings
						local rep = data.reputation
						if rep then
							rep.autowatchrep = bars.autowatchrep
							rep.autotrackguild = bars.autotrackguild
							bars.autowatchrep = nil
							bars.autotrackguild = nil
						end
					end
				end

				data.bars.azerstr = nil
				data.bars.azicons = nil
				data.bars.azerite = nil
				data.bars.azertext = nil
				data.bars.priority = nil -- reset priority
			end
		end

		sv.VER = DB_VERSION
	end
end

C.Empty = empty

C.EVENT_CONFIG_CHANGED = "ConfigChanged"
C.EVENT_PROFILE_CHANGED = "ProfileChanged"

C.XPLockedReasons = xpLockedReasons
C.MAX_PLAYER_LEVEL = MAX_PLAYER_LEVEL

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

function C.GetActionOrProcessSettings(button, ctrl, alt, shift)
	local btnCode, action, actionText
	for k, v in pairs(buttons) do
		if v == button then
			btnCode = k
			break
		end
	end
	if not btnCode then
		return nil
	end
	for _, v in ipairs(db.mouse) do
		if v.key.button == btnCode and (not not v.key.ctrl) == ctrl
				and (not not v.key.alt) == alt and (not not v.key.shift) == shift then
			action = v.action
			actionText = v.actionText
			break
		end
	end
	if not action then
		return nil
	end
	if action ~= empty then
		local topic, command = action:match("^([a-z]+):([a-z0-9.-_\32]+)$")
		if topic == "actions" then
			return command
		elseif topic == "settings" then
			actionText = command
		end
	end
	if actionText then
		HandleSettingsCommand(actionText)
		return true
	end
	return false
end

function C.RegisterConfigChanged(...)
	configChangedEvent:AddHandler(...)
end

function C.RegisterProfileChanged(...)
	profileChangedEvent:AddHandler(...)
end

function C:OnInitialize()
	self.db = AceDB:New(addonName .. "DB", defaults, true)

	MigrateSettings(self.db.sv)

	db = self.db.profile

	local myName = md.title

	ACRegistry:RegisterOptionsTable(appNames.main[1], GetOptions)
	ACRegistry:RegisterOptionsTable(appNames.general[1], GetOptions)
	ACRegistry:RegisterOptionsTable(appNames.bars[1], GetOptions)
	ACRegistry:RegisterOptionsTable(appNames.reputation[1], GetOptions)
	ACRegistry:RegisterOptionsTable(appNames.help[1], GetHelp)

	local popts = ADBO:GetOptionsTable(self.db)
	ACRegistry:RegisterOptionsTable(appNames.profiles[1], popts)

	ACDialog:AddToBlizOptions(appNames.main[1], myName)
	ACDialog:AddToBlizOptions(appNames.general[1], appNames.general[2], myName)
	ACDialog:AddToBlizOptions(appNames.bars[1], appNames.bars[2], myName)
	ACDialog:AddToBlizOptions(appNames.reputation[1], appNames.reputation[2], myName)
	ACDialog:AddToBlizOptions(appNames.profiles[1], appNames.profiles[2], myName)
	local helpApp = ACDialog:AddToBlizOptions(appNames.help[1], appNames.help[2], myName)
	if helpApp then
		local helpAppGroupObj = helpApp:GetChildren().obj
		helpAppGroupObj:SetTitle(L["Help"])
		helpAppGroupObj.SetTitle = Utils.EmptyFn
	end

	self:RegisterChatCommand(slashCmd, HandleSettingsCommand)

	self.db.RegisterCallback(self, "OnProfileChanged", self.EVENT_PROFILE_CHANGED)
	self.db.RegisterCallback(self, "OnProfileCopied", self.EVENT_PROFILE_CHANGED)
	self.db.RegisterCallback(self, "OnProfileReset", self.EVENT_PROFILE_CHANGED)

	configChangedEvent = Utils.Event:New(C.EVENT_CONFIG_CHANGED)
	profileChangedEvent = Utils.Event:New(C.EVENT_PROFILE_CHANGED)
end

function C:ProfileChanged(event, database, newProfileKey)
	db = database.profile
	profileChangedEvent(db)
end
