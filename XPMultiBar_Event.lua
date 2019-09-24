--[=====[
		## XP MultiBar ver. @@release-version@@
		## XPMultiBar_Event.lua - module
		Eventing module for XPMultiBar addon
--]=====]

local addonName = ...
local XPMultiBar = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Event = XPMultiBar:NewModule("Event")

local tinsert = table.insert
local type = type

local mod = Event

local function addHandler(event, handler, receiver)
	if not event.handlers then
		event.handlers = {}
	end
	if not receiver and type(handler) == "table" then
		receiver, handler = handler, handler[event.name]
	elseif type(handler) == "string" then
		handler, receiver = receiver[handler], receiver
	elseif type(handler) ~= "function" then
		error("'func' must be either string or function", 2)
	end
	tinsert(event.handlers, { func = handler, receiver = receiver })
end

local function removeAllHandlers(event)
	event.handlers = {}
end

local function raise(event, ...)
	for _, v in ipairs(event.handlers or {}) do
		if type(v.receiver) == "table" then
			v.func(v.receiver, ...)
		else
			v.func(...)
		end
	end
end

function mod:New(name)
	return setmetatable({
		name = name,
		AddHandler = addHandler,
		RemoveAllHandlers = removeAllHandlers,
		Raise = raise
	}, { __call = raise })
end
