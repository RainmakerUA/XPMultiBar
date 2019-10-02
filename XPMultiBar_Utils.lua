--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_Utils.lua - module
		Utility functions for XPMultiBar addon
--]=====]

local addonName = ...
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Utils = XPMultiBar:NewModule("Utils")

local U = Utils

local pairs = pairs
local print = print
local rawget = rawget
local strrep = string.rep
local setmetatable = setmetatable
local tinsert = table.insert
local tostring = tostring
local type = type
local math_floor = math.floor

local BreakUpLargeNumbers = BreakUpLargeNumbers
local GetLocale = GetLocale
local LARGE_NUMBER_SEPERATOR = LARGE_NUMBER_SEPERATOR
local BLACK_FONT_COLOR = BLACK_FONT_COLOR
local RED_FONT_COLOR = RED_FONT_COLOR
local ORANGE_FONT_COLOR = ORANGE_FONT_COLOR
local LIGHTBLUE_FONT_COLOR = LIGHTBLUE_FONT_COLOR
local GREEN_FONT_COLOR = GREEN_FONT_COLOR
local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR

-- Remove all known globals after this point
-- luacheck: std none

do
	U.DebugL = function(L)
		return setmetatable(
						{},
						{
							__index = function(self, key)
										return L and rawget(L, key) or key
									end
						}
					)
	end
end

do
	local bigNum = 1234567890
	local breakCount = 3

	local thousandSeparator = {
		deDE = ".",
		frFR = "\194\160", -- NBSP
		esES = ".",
		ptBR = ".",
		ruRU = "\194\160", -- NBSP
	}

	local classSeparator = LARGE_NUMBER_SEPERATOR

	if not classSeparator or classSeparator:len() == 0 then
		classSeparator = thousandSeparator[GetLocale()] or ","
	end

	if BreakUpLargeNumbers(bigNum) == tostring(bigNum) then
		-- BreakUpLargeNumbers does nothing as of 8.2.0 start
		-- due to wrong value for LARGE_NUMBER_SEPERATOR global in ruRU/frFR locale (Mainline)
		-- and foul implementation in Classic.
		-- Providing fallback function
		BreakUpLargeNumbers = function(num)
			if type(num) ~= "number" then
				return num
			end

			local strnum = tostring(num)
			local _, _, minus, whole, dot, fraction = strnum:find("^(%-?)(%d+)(%.?)(%d*)")

			if #whole <= breakCount then
				return strnum
			end

			local fullBreaks = math_floor(#whole / breakCount)
			local remain = #whole % breakCount
			local broken = ""

			for i = 0, fullBreaks - 1 do
				if #broken > 0 then
					broken = classSeparator .. broken
				end
				local ind1, ind2 = - (i * 3 + 3), - (i * 3 + 1)
				broken = whole:sub(ind1, ind2) .. broken
			end

			if remain > 0 then
				broken = whole:sub(1, remain) .. classSeparator .. broken
			end

			return minus .. broken .. dot .. fraction
		end
	end
end

do
	local function ts(icon, color)
		return { icon = icon, color = color }
	end
	local iconFormat = "|T%s:0|t\32"
	local textSettings = {
		fatal = ts([[interface\targetingframe\ui-raidtargetingicon_8]], BLACK_FONT_COLOR),
		error = ts([[interface\targetingframe\ui-raidtargetingicon_7]], RED_FONT_COLOR),
		warning = ts([[interface\targetingframe\ui-raidtargetingicon_2]], ORANGE_FONT_COLOR),
		info = ts([[interface\targetingframe\ui-raidtargetingicon_5]], LIGHTBLUE_FONT_COLOR),
		instruction = ts([[interface\targetingframe\ui-raidtargetingicon_4]], GREEN_FONT_COLOR),
		normal = ts(nil, NORMAL_FONT_COLOR),
	}
	local function getIndex(_, index)
		if type(index) == "string" then
			local key = index:match("^Get(%w+)"):lower()
			local textSetting = textSettings[key]
			if not textSetting.func then
				local icon, color = textSetting.icon, textSetting.color
				textSetting.func = function(text)
					local iconTag = icon and iconFormat:format(icon) or ""
					return iconTag .. color:WrapTextInColorCode(text)
				end
			end
			return textSetting.func
		end
	end
	U.Text = setmetatable({}, { __index = getIndex })
end

local u_merge, u_clone

function u_merge(target, source)
	if not source then
		target, source = {}, target
	elseif type(target) ~= "table" then
		target = {}
	end
	for k, v in pairs(source) do
		if type(v) == "table" then
			target[k] = u_merge(target[k], v)
		elseif target[k] == nil then
			target[k] = v
		end
	end
	return target
end

function u_clone(source)
	return u_merge(source)
end

function U.ForEach(t, forEachFunc)
	for k, v in pairs(t) do
		forEachFunc(v, k, t)
	end
end

function U.Filter(t, filterFunc)
	local res = {}
	for k, v in pairs(t) do
		if filterFunc(v, k, t) then
			if type(k) == "number" then
				tinsert(res, v)
			else
				res[k] = v
			end
		end
	end
	return res
end

function U.Map(t, mapFunc)
	local res = {}
	for k, v in pairs(t) do
		res[k] = mapFunc(v, k, t)
	end
	return res
end

function U.Append(...)
	local result, num, tbl = {}, 1, {...}
	for i = 1, #tbl do
		local t = tbl[i]
		if t then
			for j = 1, #t do
				result[num], num = t[j], num + 1
			end
		end
	end
	return result
end

function U.Values(t)
	local res = {}
	for _, v in pairs(t) do
		tinsert(res, v)
	end
	return res
end

U.Merge = u_merge

U.Clone = u_clone

function U.MultiReplace(text, replacements)
	if not text or text == "" then
		return ""
	end
	local result = text
	U.ForEach(
		replacements,
		function(value, pattern)
			result = result:gsub(pattern, value)
		end
	)
	return result
end

function U.PrintThru(value, label)
	--@debug@
	local text = tostring(value)
	if label then
		text = label .. ": " .. text
	end
	print(text)
	--@end-debug@
	return value
end

function U.PrintTypes(tbl, title)
	if title and #title > 0 then
		print(title)
	end
	if type(tbl) == "table" then
		for k, v in pairs(tbl) do
			print(k, "(" .. type(v) .. "):", v)
		end
	else
		print("value (" .. type(tbl) .. "):", tbl)
	end
end

function U.PrintTable(table, tableName, maxLevel)
	--@debug@
	local function indent(i)
		return strrep("  ", i)
	end
	local function printIndent(i, s)
		print(indent(i) .. s)
	end
	local function printTableImpl(t, name, level, max)
		if level > max then
			return
		elseif t == nil then
			-- this is possible only for top level value
			printIndent(level, name .. " = nil,")
			return
		end

		printIndent(level, name .. " = {")

		for k, v in pairs(t) do
			local vType = type(v)
			if vType == "table" then
				printTableImpl(v, k, level + 1, max)
			elseif vType == "string" then
				printIndent(level + 1, k .. " = '" .. tostring(v) .. "',")
			else
				printIndent(level + 1, k .. " = " .. tostring(v) .. ",")
			end
		end
		printIndent(level, "},")
	end

	printTableImpl(table, tableName or "<unnamed>", 0, maxLevel or 16)
	--@end-debug@
end

function U.Commify(num)
	if type(num) ~= "number" then
		return num
	end
	return BreakUpLargeNumbers(num)
end

function U.FormatPercents(dividend, divisor)
	return ("%.1f%%%%"):format(dividend / divisor * 100)
end

function U.FormatRemainingPercents(dividend, divisor)
	return ("%.1f%%%%"):format(100 - (dividend / divisor * 100))
end
