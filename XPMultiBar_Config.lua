--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_Config.lua - module
		Configuration and initialization for XPMultiBar addon
--]=====]

local addonName = ...
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Config = XPMultiBar:NewModule("Config", "AceConsole-3.0")

local C = Config

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local tinsert = tinsert
local error = error

local BACKGROUND = BACKGROUND

local md = {
	title = GetAddOnMetadata(addonName, "Title"),
	notes = GetAddOnMetadata(addonName, "Notes")
}

-- Event handlers
local events = {}

local function onEvent(name, ...)
	local handlers = events[name]
	if handlers then
		for _, v in ipairs(handlers) do
			local recv, method = v.self, v.method
			if not recv then
				if type(method) == "function" then
					method(...)
				else
					error("Cannot invoke method by name when receiver is absent.", 2)
				end
			else
				if type(method) == "function" then
					method(recv, ...)
				else
					recv[method](recv, ...)
				end
			end
		end
	elseif events[0] then
		local method = events[0][name]
		if type(method) == "function" then
			method(events[0], ...)
		end
	end
end

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
local repHexColor

-- repHex colors are automatically generated and cached when first looked up.
do
	repHexColor = setmetatable({}, {
		__index = function(t, k)
			local fbc

			if k == STANDING_EXALTED then
				fbc = db.bars.exalted
			else
				fbc = FACTION_BAR_COLORS[k]
			end

			local hex = ("%02x%02x%02x"):format(fbc.r * 255, fbc.g * 255, fbc.b * 255)
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
			local fsl = _G["FACTION_STANDING_LABEL"..k]
			t[k] = fsl
			return fsl
		end,
	})
end

-- Default settings
local defaults = {
	profile = {
		-- General
		general = {
			locked = false,
			clamptoscreen = true,
			strata = "LOW",
			width = 1028,
			height = 20,
			scale = 1,
			font = nil,
			fontsize = 14,
			fontoutline = false,
			texture = "Smooth",
			bubbles = false,
			border = false,
			textposition = 50,
			commify = true,
			hidestatus = true,
			posx = nil,
			posy = nil,
		},
		bars = {
			-- XP bar
			xpstring = "Exp: [curXP]/[maxXP] ([restPC]) :: [curPC] through level [pLVL] :: [needXP] XP left :: [KTL] kills to level",
			indicaterest = true,
			showremaining = true,
			showmaxlevel = false,
			-- Reputation bar
			repstring = "Rep: [faction] ([standing]) [curRep]/[maxRep] :: [repPC]",
			showrepbar = false,
			autowatchrep = true,
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
	OFF: ?: hide text, dynamic bars, mouseover
	Text: text position, separate thousands, show zero rest xp
--]]

local function getOptions(uiTypes, uiName, appName)
	local function onConfigChanged(key, value)
		onEvent(C.EVENT_CONFIG_UPDATED, key, value)
	end
	local function getColor(info)
		local col = db.bars[info[#info]]
		return col.r, col.g, col.b, col.a or 1
	end
	local function setColor(info, r, g, b, a)
		local col = db.bars[info[#info]]
		col.r, col.g, col.b, col.a = r, g, b, a
		repHexColor[STANDING_EXALTED] = nil
		local bgc = db.bars.background
		onConfigChanged("bgColor", bgc)
	end

	if appName == addonName then
		local options = {
			type = "group",
			name = md.title,
			get = function(info) return db.general[info[#info]] end,
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
						},
						scale = {
							type = "range",
							order = 300,
							name = L["Scale"],
							desc = L["Set the bar scale."],
							min = 0.5,
							max = 2,
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
						},
						fontsize = {
							type = "range",
							order = 200,
							name = L["Font Size"],
							desc = L["Change the size of the text."],
							min = 5,
							max = 30,
							step = 1,
						},
						fontoutline = {
							type = "toggle",
							order = 300,
							name = L["Font Outline"],
							desc = L["Toggles the font outline."],
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
						},
						bubbles = {
							type = "toggle",
							order = 200,
							name = L["Bubbles"],
							desc = L["Toggle bubbles on the XP bar."],
						},
						border = {
							type = "toggle",
							order = 300,
							name = L["Border"],
							desc = L["Toggle the border."],
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
						},
						commify = {
							type = "toggle",
							order = 200,
							name = L["Commify"],
							desc = L["Insert thousands separators into long numbers."],
						},
						--[[showzerorep = {
							type = "toggle",
							order = 300,
							name = L["Show Zero"],
							desc = L["Show zero values in the various Need tags, instead of an empty string"],
						},]]
					},
				},
				hidestatus = {
					type = "toggle",
					order = 60,
					width = "full",
					name = L["Hide WoW standard bars"],
					desc = L["Hide WoW standard bars for XP, Artifact power and reputation."],
				},
			},
		}
		return options
	end
	if appName == (addonName .. "-Bars") then
		return {
			type = "group",
			name = L["Bars"],
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
						indicaterest = {
							type = "toggle",
							order = 20,
							name = L["Rest Indication"],
							desc = L["Toggle the rest indication."],
						},
						showremaining = {
							type = "toggle",
							order = 30,
							name = L["Remaining Rested XP"],
							desc = L["Toggle the display of remaining rested XP."],
						},
						showmaxlevel = {
							type = "toggle",
							order = 35,
							name = L["Show at max. level"],
							desc = L["Show XP bar at payer maximum level"],
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
						showrepbar = {
							type = "toggle",
							order = 20,
							name = L["Rep. Priority"],
							desc = L["Show the reputation bar over the XP / Azerite bar."],
						},
						autowatchrep = {
							type = "toggle",
							order = 30,
							name = L["Auto Watch Reputation"],
							desc = L["Automatically watch the factions you gain reputation with."],
						},
						autotrackguild = {
							type = "toggle",
							order = 40,
							name = L["Auto Track Guild Reputation"],
							desc = L["Automatically track your guild reputation increases."],
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
	if appName == (addonName .. "-RepMenu") then
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

local function openSettings()
	InterfaceOptionsFrame_OpenToCategory(md.title)
end

C.EVENT_CONFIG_UPDATED = "ConfigUpdated"
C.EVENT_REFRESH_CONFIG = "RefreshConfig"

C.MAX_PLAYER_LEVEL = MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()]
C.STANDING_EXALTED = STANDING_EXALTED

C.OpenSettings = openSettings

function C.GetDB()
	return db
end

function C.GetFactionStandingLabel(standing)
	return factionStandingLabel[standing]
end

function C.GetRepHexColor(standing)
	return repHexColor[standing]
end

function C.RegisterDefaultReceiver(receiver)
	events[0] = receiver
end

function C.RegisterEvent(name, receiver, handler)
	local handlers = events[name]
	if not handlers then
		handlers = {}
		events[name] = handlers
	end
	if type(receiver) == "function" and not handler then
		receiver, handler = nil, receiver
	end
	if type(handler) == "function"
			or type(handler) == "string" and receiver then
		tinsert(handlers, {["self"] = receiver, ["method"] = handler})
	else
		error("Not supported handler type.", 2)
	end
end

function C:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New(addonName .. "DB", defaults, true)
	db = self.db.profile

	local myName = md.title
	local ACRegistry = LibStub("AceConfigRegistry-3.0")
	local ACDialog = LibStub("AceConfigDialog-3.0")

	ACRegistry:RegisterOptionsTable(addonName, getOptions)
	ACRegistry:RegisterOptionsTable(addonName .. "-Bars", getOptions)
	ACRegistry:RegisterOptionsTable(addonName .. "-RepMenu", getOptions)

	ACDialog:AddToBlizOptions(addonName, myName)
	ACDialog:AddToBlizOptions(addonName .. "-Bars", L["Bars"], myName)
	ACDialog:AddToBlizOptions(addonName .. "-RepMenu", L["Reputation Menu"], myName)

	local popts = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	ACRegistry:RegisterOptionsTable(addonName .. "-Profiles", popts)
	ACDialog:AddToBlizOptions(addonName .. "-Profiles", L["Profiles"], myName)

	self:RegisterChatCommand("xpbar", openSettings)

	self.db.RegisterCallback(self, "OnProfileChanged", self.EVENT_REFRESH_CONFIG)
	self.db.RegisterCallback(self, "OnProfileCopied", self.EVENT_REFRESH_CONFIG)
	self.db.RegisterCallback(self, "OnProfileReset", self.EVENT_REFRESH_CONFIG)
end

function C:RefreshConfig(event, database, newProfileKey)
	db = database.profile
	repHexColor[STANDING_EXALTED] = nil
	onEvent(self.EVENT_REFRESH_CONFIG, db)
end
