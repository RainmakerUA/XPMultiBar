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
local tinsert = tinsert
local type = type

local BreakUpLargeNumbers = BreakUpLargeNumbers

function U.AsReadOnly(t)
	local proxy = {}
	local mt = {
		__index = t,
		__ipairs = function(tbl)
			return ipairs(t)
		end,
		__pairs = function(tbl)
			return pairs(t)
		end,
		__newindex = function (t, k, v)
			error("attempt to update a read-only table", 2)
		end,
		__metatable = {},
	}
	setmetatable(proxy, mt)
	return proxy
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
	if not doCommify or type(num) ~= "number" or tostring(num):len() <= 3 then
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
