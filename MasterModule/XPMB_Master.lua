--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMB_Master.lua - module
		Master (developer-only) module for XPMultiBar addon
--]=====]

local addonName = ...
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Master = XPMultiBar:NewModule("Master")

local function TraceSettings(key, table)
	local function Error(msg)
		print("TraceSettings error:", msg)
	end
	local function Trace(tabkey, tab, parents, output)
		if type(tabkey) ~= "string" then
			return Error("illegal tab key under " .. tconcat(parents))
		end
		if type(tab) ~= "table" or type(tab.type) ~= "string" then
			return Error("malformed option table under " .. tconcat(parents))
		end
		if tabkey == "main" or tabkey == "mouseGroup" or tabkey:sub(1, 3) == "pg_" then
			return Error("skipped " .. tabkey .. " under " .. tconcat(parents))
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
		elseif tab.type == "description" then
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
				vals = tconcat(type(tab.values) == "function" and tab.values() or tab.values, "|")
			elseif tab.type == "color" then
				vals = "RRGGBBAA|r g b a"
			else
				vals = "???"
			end
			if vals and #vals > 0 then
				tabkey = tabkey .. "\32" .. vals
			end
			Utils.Push(output, ("%s %s -- (%s) %s"):format(tconcat(parents, "\32"), tabkey, tab.desc or "<?>", tab.name))
		end
	end
	local out = {}
	Trace(key, table, {}, out)
	return out
end

--[[
	local apps = ""
	for k, v in pairs(appNames) do
		if #apps > 0 then
			apps = apps .. "\10"
		end
		apps = apps .. tconcat(TraceSettings(k, GetOptions(nil, nil, v)), "\10")
	end
	--self.db.sv.apps = apps
]]