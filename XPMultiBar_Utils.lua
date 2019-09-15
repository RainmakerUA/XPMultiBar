--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_Utils.lua - module
		Utility functions for XPMultiBar addon
--]=====]

local addonName = ...
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Utils = XPMultiBar:NewModule("Utils")

local U = Utils

local ipairs = ipairs
local pairs = pairs
local print = print
local tinsert = table.insert
local tostring = tostring
local type = type
local math_floor = math.floor

local BreakUpLargeNumbers = BreakUpLargeNumbers
local GetLocale = GetLocale

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

	local LARGE_NUMBER_SEPERATOR = LARGE_NUMBER_SEPERATOR

	if not LARGE_NUMBER_SEPERATOR or LARGE_NUMBER_SEPERATOR:len() == 0 then
		LARGE_NUMBER_SEPERATOR = thousandSeparator[GetLocale()] or ","
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

			local separator = LARGE_NUMBER_SEPERATOR
			local fullBreaks = math_floor(#whole / breakCount)
			local remain = #whole % breakCount
			local broken = ""

			for i = 0, fullBreaks - 1 do
				if #broken > 0 then
					broken = separator .. broken
				end
				local ind1, ind2 = - (i * 3 + 3), - (i * 3 + 1)
				broken = whole:sub(ind1, ind2) .. broken
			end

			if remain > 0 then
				broken = whole:sub(1, remain) .. separator .. broken
			end

			return minus .. broken .. dot .. fraction
		end
	end
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
			for i = 1, #t do
				result[n], n = t[i], n + 1
			end
		end
	end
	return result
end

function U.Values(t)
	local res = {}
	for k, v in pairs(t) do
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
		print("value (" .. type(v) .. "):", tbl)
	end
end

function U.PrintTable(t, name, maxLevel)
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

	printTableImpl(t, name or "<unnamed>", 0, maxLevel or 16)
	--@end-debug@
end

function U.Commify(num, doCommify)
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
