local addonName, addonTable = ...

local pairs = pairs
local print = print
local tinsert = tinsert
local type = type

local GetAddOnMetadata = GetAddOnMetadata

local u
u = {
	forEach = function(t, forEachFunc)
		for k, v in pairs(t) do
			forEachFunc(v, k, t)
		end
	end,

	filter = function(t, filterFunc)
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
	end,

	map = function(t, mapFunc)
		local res = {}
		for k, v in pairs(t) do
			res[k] = mapFunc(v, k, t)
		end
		return res
	end,

	multiReplace = function(text, replacements)
		if not text or text == "" then
			return ""
		end

		local result = text
		u.forEach(
			replacements,
			function(value, pattern)
				result = result:gsub(pattern, value)
			end
		)
		return result
	end,

	printThru = function(label, text)
		--@debug@
		if not text then
			label, text = nil, label
		end
		print(label and label..": "..text or text)
		--@end-debug@
		return text
	end,

	printTable = function(t, name, maxLevel)
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
}

local md = {
	title = GetAddOnMetadata(addonName, "Title"),
	notes = GetAddOnMetadata(addonName, "Notes")
}

addonTable.utils = u
addonTable.metadata = md

