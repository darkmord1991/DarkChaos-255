--[[
	talents_sim.lua - a strict WoW 3.3.5a (12340) client for DC-Talents' headless tests.

	Unlike wowsim.lua (a loose stub for small modules), this one is built to catch what breaks a retail
	port on the real client:

	  * widget types are generated from wow335_api.lua (the WoW Programming 3.x reference + the real
	    3.3.5a FrameXML): a method, script handler, native template or font the 3.3.5 client lacks is
	    missing here too, and calling it fails the same way;
	  * frames and regions resolve their anchors into real rectangles (GetLeft/GetCenter/GetWidth...),
	    reject self-anchoring and anchor cycles, and fire OnShow/OnHide on visibility changes;
	  * script and event handler errors go to the error handler (SIM.errors), never to the caller;
	  * FontStrings without a font refuse SetText ("Font not set"), PlaySound only takes names,
	    GetChecked returns 1/nil, UnitClass returns two values - 3.3.5 behaviour, not retail's;
	  * the talent API (tabs, ranks, prerequisites, tier gates, preview points, dual spec, glyphs) runs
	    on the real Talent.dbc data DC-Talents ships (Data/TalentData.lua).

	Lua 5.4 runs the 5.1 addon code: setfenv(1, env) is emulated per file, and format/tostring/bit/
	unpack/strsplit behave like the client's.
]]

local SIM = {}
_G.SIM = SIM

local DIR = SIM_DIR or ""
-- SIM_ADDONS_DIR (Lua global or environment) points the tests at another addon tree, e.g. the client's
-- Interface/AddOns, to test exactly what is deployed.
SIM.ADDONS_DIR = SIM_ADDONS_DIR or os.getenv("SIM_ADDONS_DIR") or "../"

local API = dofile(DIR .. "wow335_api.lua")
SIM.API = API

SIM.errors = {}
SIM.warnings = {}
SIM.chat = {}
SIM.uiErrors = {}
SIM.sounds = {}
SIM.addonMessages = {}
SIM.frames = {}
SIM.now = 1000
SIM.SCREEN_W = SIM_SCREEN_W or 1365.3333
SIM.SCREEN_H = SIM_SCREEN_H or 768
SIM.keys = { shift = false, ctrl = false, alt = false }
SIM.warnedOnce = {}

local function Warn(message)
	if not SIM.warnedOnce[message] then
		SIM.warnedOnce[message] = true
		SIM.warnings[#SIM.warnings + 1] = message
	end
end
SIM.Warn = Warn

-- ============================================================================
-- Lua 5.1 on 5.4
-- ============================================================================

unpack = unpack or table.unpack
loadstring = loadstring or load
table.getn = table.getn or function(t) return #t end
math.mod = math.fmod
math.pow = math.pow or function(a, b) return a ^ b end
string.gfind = string.gfind or string.gmatch

local rawformat = string.format
local INTEGER_SPECS = { d = true, i = true, x = true, X = true, c = true, o = true, u = true }

-- The client's format: 5.1 truncation for %d, positional %1$s arguments, integral floats print as ints.
local function Format51(fmt, ...)
	local args = table.pack(...)
	local newArgs, count, sequential = {}, 0, 0
	local newFormat = tostring(fmt):gsub("%%(%d*%$?)([-+ #0]*%d*%.?%d*)([%a%%])", function(position, flags, spec)
		if spec == "%" then
			return "%%"
		end
		local index
		if position ~= "" and position:sub(-1) == "$" then
			index = tonumber(position:sub(1, -2))
		else
			flags = position .. flags
			sequential = sequential + 1
			index = sequential
		end
		local value = args[index]
		if type(value) == "number" and math.type(value) == "float" then
			if INTEGER_SPECS[spec] then
				value = value >= 0 and math.floor(value) or math.ceil(value)
			elseif spec == "s" and value == math.floor(value) and math.abs(value) < 1e15 then
				value = rawformat("%d", value)
			end
		elseif spec == "s" and value == nil and index > args.n then
			error("bad argument #" .. (index + 1) .. " to 'format' (no value)", 3)
		end
		count = count + 1
		newArgs[count] = value
		return "%" .. flags .. spec
	end)
	return rawformat(newFormat, table.unpack(newArgs, 1, count))
end
string.format = Format51
format = Format51

local rawtostring = tostring
tostring = function(value)
	if math.type(value) == "float" and value == math.floor(value) and math.abs(value) < 1e15 then
		return rawformat("%d", value)
	end
	return rawtostring(value)
end

local function ToUInt32(value)
	value = math.floor(tonumber(value) or 0)
	return value & 0xFFFFFFFF
end

bit = {
	band = function(...)
		local result = 0xFFFFFFFF
		for i = 1, select("#", ...) do
			result = result & ToUInt32(select(i, ...))
		end
		return result
	end,
	bor = function(...)
		local result = 0
		for i = 1, select("#", ...) do
			result = result | ToUInt32(select(i, ...))
		end
		return result
	end,
	bxor = function(...)
		local result = 0
		for i = 1, select("#", ...) do
			result = result ~ ToUInt32(select(i, ...))
		end
		return result
	end,
	bnot = function(value)
		return (~ToUInt32(value)) & 0xFFFFFFFF
	end,
	lshift = function(value, shift)
		return (ToUInt32(value) << shift) & 0xFFFFFFFF
	end,
	rshift = function(value, shift)
		return ToUInt32(value) >> shift
	end,
	arshift = function(value, shift)
		local v = ToUInt32(value)
		if v >= 0x80000000 then
			v = v - 0x100000000
		end
		return (v >> shift) & 0xFFFFFFFF
	end,
	mod = function(a, b)
		return ToUInt32(a) % ToUInt32(b)
	end,
}

strsub, strlen, strlower, strupper = string.sub, string.len, string.lower, string.upper
strfind, strmatch, strrep, strbyte, strchar = string.find, string.match, string.rep, string.byte, string.char
strrev, gsub, gmatch = string.reverse, string.gsub, string.gmatch
tinsert, tremove, sort = table.insert, table.remove, table.sort
floor, ceil, abs, min, max, sqrt, exp = math.floor, math.ceil, math.abs, math.min, math.max, math.sqrt, math.exp
mod = math.fmod
log = math.log
log10 = function(x) return math.log(x, 10) end
random = math.random
PI = math.pi
sin = function(degrees) return math.sin(math.rad(degrees)) end
cos = function(degrees) return math.cos(math.rad(degrees)) end
tan = function(degrees) return math.tan(math.rad(degrees)) end
rad, deg = math.rad, math.deg
getn = table.getn

function wipe(t)
	for key in pairs(t) do
		t[key] = nil
	end
	return t
end

function strsplit(delimiter, text, pieces)
	local results = {}
	local set = "[" .. delimiter:gsub("[%^%]%-%%]", "%%%0") .. "]"
	local start = 1
	while true do
		if pieces and #results == pieces - 1 then
			results[#results + 1] = text:sub(start)
			break
		end
		local s, e = text:find(set, start)
		if not s then
			results[#results + 1] = text:sub(start)
			break
		end
		results[#results + 1] = text:sub(start, s - 1)
		start = e + 1
	end
	return table.unpack(results)
end

function strjoin(delimiter, ...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	return table.concat(parts, delimiter)
end

function strconcat(...)
	return strjoin("", ...)
end

function strtrim(text, chars)
	chars = chars and ("[" .. chars:gsub("[%^%]%-%%]", "%%%0") .. "]") or "%s"
	return (text:gsub("^" .. chars .. "+", ""):gsub(chars .. "+$", ""))
end

function tContains(t, value)
	for i = 1, #t do
		if t[i] == value then
			return 1
		end
	end
	return nil
end

function tDeleteItem(t, value)
	for i = #t, 1, -1 do
		if t[i] == value then
			table.remove(t, i)
		end
	end
end

-- 3.3.5 UIParent.lua
function CopyTable(settings)
	local copy = {}
	for k, v in pairs(settings) do
		if type(v) == "table" then
			copy[k] = CopyTable(v)
		else
			copy[k] = v
		end
	end
	return copy
end

-- ============================================================================
-- Errors and time
-- ============================================================================

local function DefaultErrorHandler(message)
	SIM.errors[#SIM.errors + 1] = tostring(message)
	if SIM.printErrors then
		io.stdout:write("  ERROR " .. tostring(message) .. "\n")
	end
end
local errorHandler = DefaultErrorHandler

function seterrorhandler(handler)
	errorHandler = handler
end

function geterrorhandler()
	return errorHandler
end

local function Traceback(err)
	return tostring(err) .. "\n" .. debug.traceback("", 2)
end

-- Script handlers and event dispatch: errors reach the handler, never the caller (like the client).
local function SafeInvoke(func, ...)
	local ok, err = xpcall(func, Traceback, ...)
	if not ok then
		errorHandler(err)
	end
	return ok
end
SIM.SafeInvoke = SafeInvoke

function GetTime()
	return SIM.now
end

function time()
	return 1790000000 + math.floor(SIM.now)
end

date = os.date

function debugprofilestop()
	return SIM.now * 1000
end

function debugstack(start, count1, count2)
	return debug.traceback("", (start or 1) + 1)
end

function GetFramerate()
	return 60
end

function print(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	SIM.chat[#SIM.chat + 1] = table.concat(parts, " ")
end

-- ============================================================================
-- Widgets
-- ============================================================================

local S = setmetatable({}, { __mode = "k" })
SIM.S = S

local Types = {}
local Impl = {}
local ImplFor = {}
local Scripts = {}

local function State(object)
	local st = S[object]
	if not st then
		error("not a widget: " .. tostring(object), 3)
	end
	return st
end
SIM.State = State

local function Chain(typeName, out, seen)
	out = out or {}
	seen = seen or {}
	if seen[typeName] then
		return out
	end
	seen[typeName] = true
	out[#out + 1] = typeName
	local def = API.widgets[typeName]
	for _, parent in ipairs(def and def.inherits or {}) do
		Chain(parent, out, seen)
	end
	return out
end

local function TypeOf(typeName)
	local t = Types[typeName]
	if t then
		return t
	end
	local def = API.widgets[typeName]
	if not def then
		error("unknown widget type " .. tostring(typeName))
	end
	t = { name = typeName, methods = {}, scripts = {}, chain = Chain(typeName) }
	t.isType = {}
	for _, name in ipairs(t.chain) do
		t.isType[name:lower()] = true
	end
	for _, script in ipairs(def.scripts) do
		t.scripts[script] = true
	end
	for _, method in ipairs(def.methods) do
		local impl = (ImplFor[typeName] and ImplFor[typeName][method])
		if not impl then
			for _, ancestor in ipairs(t.chain) do
				if ImplFor[ancestor] and ImplFor[ancestor][method] then
					impl = ImplFor[ancestor][method]
					break
				end
			end
		end
		t.methods[method] = impl or Impl[method] or function() return nil end
	end
	t.meta = { __index = t.methods }
	Types[typeName] = t
	return t
end

local function NewObject(typeName, name, parent)
	local t = TypeOf(typeName)
	local object = setmetatable({}, t.meta)
	S[object] = {
		type = typeName,
		typeInfo = t,
		name = name,
		parent = parent,
		points = {},
		width = 0,
		height = 0,
		shown = true,
		alpha = 1,
		scripts = {},
	}
	if name then
		_G[name] = object
	end
	return object
end
SIM.NewObject = NewObject

local function ExpandName(name, parent)
	if type(name) ~= "string" then
		return nil
	end
	if name:find("$parent", 1, true) or name:find("$Parent", 1, true) then
		local parentName = parent and S[parent] and S[parent].name or ""
		name = name:gsub("%$[Pp]arent", parentName)
	end
	return name
end

local function CheckNumber(value, usage, level)
	if type(value) ~= "number" then
		if type(value) == "string" and tonumber(value) then
			return tonumber(value)
		end
		error("Usage: " .. usage, (level or 2) + 1)
	end
	return value
end

-- ----------------------------------------------------------------------------
-- UIObject / ParentedObject
-- ----------------------------------------------------------------------------

function Impl.GetName(self)
	return State(self).name
end

function Impl.GetObjectType(self)
	return State(self).type
end

function Impl.IsObjectType(self, typeName)
	return State(self).typeInfo.isType[tostring(typeName):lower()] and 1 or nil
end

function Impl.GetParent(self)
	return State(self).parent
end

-- ----------------------------------------------------------------------------
-- Layout
-- ----------------------------------------------------------------------------

local PointH = { TOPLEFT = "L", LEFT = "L", BOTTOMLEFT = "L", TOP = "C", CENTER = "C", BOTTOM = "C", TOPRIGHT = "R", RIGHT = "R", BOTTOMRIGHT = "R" }
local PointV = { TOPLEFT = "T", TOP = "T", TOPRIGHT = "T", LEFT = "C", CENTER = "C", RIGHT = "C", BOTTOMLEFT = "B", BOTTOM = "B", BOTTOMRIGHT = "B" }

local function EffectiveScale(object)
	local st = S[object]
	if not st then
		return 1
	end
	local scale = st.scale or 1
	if st.parent then
		return scale * EffectiveScale(st.parent)
	end
	return scale
end
SIM.EffectiveScale = EffectiveScale

local function StringWidth(text)
	text = tostring(text or "")
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "WW"):gsub("|H.-|h(.-)|h", "%1")
	return #text * 6
end

local resolving = {}

local function Rect(object)
	if object == nil then
		return 0, 0, SIM.SCREEN_W, SIM.SCREEN_H
	end
	local st = S[object]
	if not st or resolving[object] then
		return nil
	end
	if st.isScreen then
		return 0, 0, SIM.SCREEN_W, SIM.SCREEN_H
	end
	resolving[object] = true
	local scale = EffectiveScale(object)
	local L, R, CX, T, B, CY
	for _, p in ipairs(st.points) do
		local relative = p.relTo
		local rl, rb, rr, rt
		if relative == nil then
			rl, rb, rr, rt = Rect(st.parent)
		else
			rl, rb, rr, rt = Rect(relative)
		end
		if rl then
			local x = (PointH[p.relPoint] == "L" and rl) or (PointH[p.relPoint] == "R" and rr) or (rl + rr) / 2
			local y = (PointV[p.relPoint] == "T" and rt) or (PointV[p.relPoint] == "B" and rb) or (rb + rt) / 2
			x = x + p.x * scale
			y = y + p.y * scale
			local h, v = PointH[p.point], PointV[p.point]
			if h == "L" then L = x elseif h == "R" then R = x else CX = x end
			if v == "T" then T = y elseif v == "B" then B = y else CY = y end
		end
	end
	resolving[object] = nil

	local width = (st.width or 0) * scale
	local height = (st.height or 0) * scale
	if st.type == "FontString" then
		if width <= 0 then
			width = StringWidth(st.text) * scale
		end
		if height <= 0 then
			height = (st.fontSize or 12) * scale
		end
	end

	if L and R then
	elseif L and width > 0 then R = L + width
	elseif R and width > 0 then L = R - width
	elseif CX and width > 0 then L, R = CX - width / 2, CX + width / 2
	elseif L and CX then R = 2 * CX - L
	elseif R and CX then L = 2 * CX - R
	else return nil end

	if T and B then
	elseif T and height > 0 then B = T - height
	elseif B and height > 0 then T = B + height
	elseif CY and height > 0 then B, T = CY - height / 2, CY + height / 2
	elseif T and CY then B = 2 * CY - T
	elseif B and CY then T = 2 * CY - B
	else return nil end

	return L, B, R, T
end
SIM.Rect = Rect

-- Does `object` (through its anchors, or its parent for nil-relative anchors) depend on `target`?
local function DependsOn(object, target, seen)
	if object == target then
		return true
	end
	seen = seen or {}
	if seen[object] then
		return false
	end
	seen[object] = true
	local st = S[object]
	if not st then
		return false
	end
	for _, p in ipairs(st.points) do
		local relative = p.relTo or st.parent
		if relative and DependsOn(relative, target, seen) then
			return true
		end
	end
	return false
end

function Impl.SetPoint(self, point, relativeTo, relativePoint, x, y)
	local st = State(self)
	if type(point) ~= "string" or not PointH[point:upper()] then
		error(("%s:SetPoint(): Invalid region point '%s'"):format(st.type, tostring(point)), 2)
	end
	point = point:upper()
	-- 3.3.5 short forms (the stock FrameXML uses both): (point, x, y) and (point, region, x, y).
	if type(relativeTo) == "number" then
		relativeTo, relativePoint, x, y = nil, point, relativeTo, relativePoint
	elseif type(relativePoint) == "number" then
		relativePoint, x, y = point, relativePoint, x
	end
	if type(relativeTo) == "string" then
		local name = relativeTo
		relativeTo = _G[ExpandName(name, st.parent)]
		if not relativeTo then
			error(("%s:SetPoint(): Couldn't find region named '%s'"):format(st.type, name), 2)
		end
	elseif type(relativeTo) == "number" then
		error(("Usage: %s:SetPoint(\"point\" [, region or nil] [, \"relativePoint\"] [, offsetX, offsetY])"):format(st.type), 2)
	elseif relativeTo ~= nil and not S[relativeTo] then
		error(("%s:SetPoint(): relativeTo is not a region"):format(st.type), 2)
	end
	if type(relativePoint) == "number" then
		error(("Usage: %s:SetPoint(\"point\" [, region or nil] [, \"relativePoint\"] [, offsetX, offsetY])"):format(st.type), 2)
	end
	relativePoint = relativePoint and tostring(relativePoint):upper() or point
	if not PointH[relativePoint] then
		error(("%s:SetPoint(): Invalid relative point '%s'"):format(st.type, tostring(relativePoint)), 2)
	end
	if relativeTo == self then
		error("Action[SetPoint] failed because[Cannot anchor to itself]", 2)
	end
	if relativeTo and DependsOn(relativeTo, self) then
		error(("Action[SetPoint] failed because[Cannot anchor to a region dependent on it]: %s"):format(SIM.Describe(self)), 2)
	end
	if x ~= nil and type(x) ~= "number" or y ~= nil and type(y) ~= "number" then
		error(("Usage: %s:SetPoint(\"point\" [, region or nil] [, \"relativePoint\"] [, offsetX, offsetY])"):format(st.type), 2)
	end
	local entry = { point = point, relTo = relativeTo, relPoint = relativePoint, x = x or 0, y = y or 0 }
	for index, existing in ipairs(st.points) do
		if existing.point == point then
			st.points[index] = entry
			return
		end
	end
	st.points[#st.points + 1] = entry
end

function Impl.ClearAllPoints(self)
	wipe(State(self).points)
end

function Impl.SetAllPoints(self, relativeTo)
	local st = State(self)
	if type(relativeTo) == "string" then
		relativeTo = _G[relativeTo]
	end
	relativeTo = relativeTo or st.parent
	if relativeTo == self then
		error("Action[SetAllPoints] failed because[Cannot anchor to itself]", 2)
	end
	Impl.SetPoint(self, "TOPLEFT", relativeTo, "TOPLEFT", 0, 0)
	Impl.SetPoint(self, "BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT", 0, 0)
end

function Impl.GetNumPoints(self)
	return #State(self).points
end

function Impl.GetPoint(self, index)
	local st = State(self)
	local p = st.points[index or 1]
	if p then
		return p.point, p.relTo or st.parent, p.relPoint, p.x, p.y
	end
end

function Impl.SetWidth(self, width)
	State(self).width = CheckNumber(width, State(self).type .. ":SetWidth(width)")
end

function Impl.SetHeight(self, height)
	State(self).height = CheckNumber(height, State(self).type .. ":SetHeight(height)")
end

function Impl.SetSize(self, width, height)
	local st = State(self)
	st.width = CheckNumber(width, st.type .. ":SetSize(width, height)")
	st.height = CheckNumber(height, st.type .. ":SetSize(width, height)")
end

function Impl.GetWidth(self)
	local L, _, R = Rect(self)
	if L then
		return (R - L) / EffectiveScale(self)
	end
	local st = State(self)
	if st.type == "FontString" and (st.width or 0) <= 0 then
		return StringWidth(st.text)
	end
	return st.width or 0
end

function Impl.GetHeight(self)
	local L, B, _, T = Rect(self)
	if L then
		return (T - B) / EffectiveScale(self)
	end
	local st = State(self)
	if st.type == "FontString" and (st.height or 0) <= 0 then
		return st.fontSize or 12
	end
	return st.height or 0
end

function Impl.GetSize(self)
	return Impl.GetWidth(self), Impl.GetHeight(self)
end

function Impl.GetLeft(self)
	local L = Rect(self)
	return L and L / EffectiveScale(self) or nil
end

function Impl.GetRight(self)
	local L, _, R = Rect(self)
	return L and R / EffectiveScale(self) or nil
end

function Impl.GetTop(self)
	local L, _, _, T = Rect(self)
	return L and T / EffectiveScale(self) or nil
end

function Impl.GetBottom(self)
	local L, B = Rect(self)
	return L and B / EffectiveScale(self) or nil
end

function Impl.GetCenter(self)
	local L, B, R, T = Rect(self)
	if not L then
		return nil
	end
	local scale = EffectiveScale(self)
	return (L + R) / 2 / scale, (B + T) / 2 / scale
end

function Impl.GetRect(self)
	local L, B, R, T = Rect(self)
	if not L then
		return nil
	end
	local scale = EffectiveScale(self)
	return L / scale, B / scale, (R - L) / scale, (T - B) / scale
end

function Impl.IsMouseOver(self)
	return SIM.mouseFocus == self and 1 or nil
end

function Impl.IsDragging()
	return nil
end

function Impl.IsProtected()
	return nil, nil
end

function Impl.CanChangeProtectedState()
	return 1
end

-- ----------------------------------------------------------------------------
-- Visibility
--
-- The 3.3.5 client (CSimpleFrame::ShowThis / HideThis, as reconstructed by the whoa project) keeps
-- a visible flag per frame. Showing marks the frame visible, then shows its children (whose OnShow
-- run first), then runs the frame's own OnShow; hiding mirrors that. A region is visible when it is
-- shown and its frame is.
-- ----------------------------------------------------------------------------

local function IsVisible(object)
	local st = S[object]
	if not st then
		return false
	end
	if st.children ~= nil then
		return st.visible == true
	end
	if not st.shown then
		return false
	end
	return st.parent == nil or IsVisible(st.parent)
end
SIM.IsVisible = IsVisible

local CallScript

local function Snapshot(list)
	local copy = {}
	for index, entry in ipairs(list) do
		copy[index] = entry
	end
	return copy
end

local ShowThis, HideThis

function ShowThis(object)
	local st = S[object]
	if not st.shown then
		return false
	end
	if st.parent and not S[st.parent].visible then
		return false
	end
	if st.visible then
		return true
	end
	st.visible = true
	for _, child in ipairs(Snapshot(st.children)) do
		if S[child].parent == object then
			ShowThis(child)
		end
	end
	if st.scripts.OnShow then
		CallScript(object, "OnShow")
	end
	return true
end

function HideThis(object)
	local st = S[object]
	if not st.visible then
		return
	end
	st.visible = false
	for _, child in ipairs(Snapshot(st.children)) do
		if S[child].parent == object then
			HideThis(child)
		end
	end
	if st.scripts.OnHide then
		CallScript(object, "OnHide")
	end
end

function Impl.Show(self)
	local st = State(self)
	st.shown = true
	if st.children ~= nil then
		ShowThis(self)
	end
end

function Impl.Hide(self)
	local st = State(self)
	st.shown = false
	if st.children ~= nil then
		HideThis(self)
	end
end

function Impl.IsShown(self)
	return State(self).shown and 1 or nil
end

function Impl.IsVisible(self)
	return IsVisible(self) and 1 or nil
end

function Impl.SetAlpha(self, alpha)
	State(self).alpha = CheckNumber(alpha, State(self).type .. ":SetAlpha(alpha)")
end

function Impl.GetAlpha(self)
	return State(self).alpha
end

function Impl.GetEffectiveAlpha(self)
	local alpha, object = 1, self
	while object and S[object] do
		alpha = alpha * (S[object].alpha or 1)
		object = S[object].parent
	end
	return alpha
end

-- CSimpleFrame::SetFrameLevel: a call raises the level by at most 128, and children move by the
-- same amount.
local function ApplyFrameLevel(object, level)
	local st = S[object]
	level = math.max(level, 0)
	local current = st.level or 0
	if level == current then
		return
	end
	local delta = math.min(level - current, 128)
	st.level = current + delta
	for _, child in ipairs(st.children or {}) do
		ApplyFrameLevel(child, (S[child].level or 0) + delta)
	end
end
SIM.ApplyFrameLevel = ApplyFrameLevel

-- CSimpleFrame::SetParent: a visible frame is hidden (OnHide), takes its new parent's strata and
-- level + 1, and is shown again (OnShow) if the new parent is visible.
function Impl.SetParent(self, parent)
	local st = State(self)
	if type(parent) == "string" then
		parent = _G[parent]
	end
	local old = st.parent
	if old == parent then
		return
	end
	local isFrame = st.children ~= nil
	if isFrame then
		HideThis(self)
	end
	if old and S[old] then
		local list = isFrame and S[old].children or S[old].regions
		if list then
			for index, entry in ipairs(list) do
				if entry == self then
					table.remove(list, index)
					break
				end
			end
		end
	end
	st.parent = parent
	if parent then
		local pst = State(parent)
		if isFrame then
			pst.children[#pst.children + 1] = self
			st.strata = pst.strata
			ApplyFrameLevel(self, (pst.level or 0) + 1)
		else
			pst.regions[#pst.regions + 1] = self
		end
	elseif isFrame then
		st.strata = "MEDIUM"
		ApplyFrameLevel(self, 0)
	end
	if isFrame then
		ShowThis(self)
	end
end

-- ----------------------------------------------------------------------------
-- Scripts and events
-- ----------------------------------------------------------------------------

local EVENTS = {}
for _, event in ipairs(API.events) do
	EVENTS[event] = true
end
SIM.KNOWN_EVENTS = EVENTS

function CallScript(object, handler, ...)
	local func = S[object].scripts[handler]
	if func then
		return SafeInvoke(func, object, ...)
	end
end
SIM.CallScript = CallScript

local function ValidateScript(self, handler)
	local st = State(self)
	if not st.typeInfo.scripts[handler] then
		error(("%s:SetScript(): %s doesn't have a \"%s\" script"):format(st.type, st.name or "<unnamed>", tostring(handler)), 3)
	end
end

function Impl.SetScript(self, handler, func)
	ValidateScript(self, handler)
	if func ~= nil and type(func) ~= "function" then
		error("Usage: SetScript(\"handler\", func)", 2)
	end
	State(self).scripts[handler] = func
end

function Impl.GetScript(self, handler)
	ValidateScript(self, handler)
	return State(self).scripts[handler]
end

function Impl.HookScript(self, handler, func)
	ValidateScript(self, handler)
	local st = State(self)
	local original = st.scripts[handler]
	if original then
		st.scripts[handler] = function(...)
			original(...)
			return func(...)
		end
	else
		st.scripts[handler] = func
	end
end

function Impl.HasScript(self, handler)
	return State(self).typeInfo.scripts[handler] and 1 or nil
end

local eventRegistrations = {}
local registrationOrder = 0

function Impl.RegisterEvent(self, event)
	if type(event) ~= "string" then
		error("Usage: RegisterEvent(\"event\")", 2)
	end
	if not EVENTS[event] then
		Warn("RegisterEvent: event unknown to the 3.3.5 client: " .. event)
	end
	local st = State(self)
	st.events = st.events or {}
	if not st.events[event] then
		registrationOrder = registrationOrder + 1
		st.events[event] = registrationOrder
		eventRegistrations[event] = eventRegistrations[event] or {}
		table.insert(eventRegistrations[event], self)
	end
end

function Impl.UnregisterEvent(self, event)
	local st = State(self)
	if st.events and st.events[event] then
		st.events[event] = nil
		tDeleteItem(eventRegistrations[event], self)
	end
end

function Impl.UnregisterAllEvents(self)
	local st = State(self)
	for event in pairs(st.events or {}) do
		tDeleteItem(eventRegistrations[event], self)
	end
	st.events = {}
	st.allEvents = nil
end

function Impl.RegisterAllEvents(self)
	State(self).allEvents = true
end

function Impl.IsEventRegistered(self, event)
	local st = State(self)
	return (st.events and st.events[event]) and 1 or nil
end

function SIM.FireEvent(event, ...)
	local list = {}
	for _, frame in ipairs(eventRegistrations[event] or {}) do
		list[#list + 1] = frame
	end
	for _, frame in ipairs(SIM.frames) do
		if S[frame].allEvents and not tContains(list, frame) then
			list[#list + 1] = frame
		end
	end
	for _, frame in ipairs(list) do
		local st = S[frame]
		if (st.allEvents or (st.events and st.events[event])) and st.scripts.OnEvent then
			CallScript(frame, "OnEvent", event, ...)
		end
	end
end

-- ----------------------------------------------------------------------------
-- Frame
-- ----------------------------------------------------------------------------

function Impl.SetFrameLevel(self, level)
	level = CheckNumber(level, "Frame:SetFrameLevel(level)")
	if level < 0 then
		error("Frame:SetFrameLevel(): level must be >= 0", 2)
	end
	State(self)
	ApplyFrameLevel(self, math.floor(level))
end

function Impl.GetFrameLevel(self)
	return State(self).level or 0
end

local STRATA = { PARENT = true, BACKGROUND = true, LOW = true, MEDIUM = true, HIGH = true, DIALOG = true, FULLSCREEN = true, FULLSCREEN_DIALOG = true, TOOLTIP = true }

function Impl.SetFrameStrata(self, strata)
	if not STRATA[strata] then
		Warn("SetFrameStrata: unknown strata " .. tostring(strata))
	end
	State(self).strata = strata
end

function Impl.GetFrameStrata(self)
	return State(self).strata or "MEDIUM"
end

function Impl.SetScale(self, scale)
	scale = CheckNumber(scale, "Frame:SetScale(scale)")
	if scale <= 0 then
		error("Frame:SetScale(): Scale must be > 0", 2)
	end
	State(self).scale = scale
end

function Impl.GetScale(self)
	return State(self).scale or 1
end

function Impl.GetEffectiveScale(self)
	return EffectiveScale(self)
end

function Impl.SetID(self, id)
	State(self).id = CheckNumber(id, "Frame:SetID(id)")
end

function Impl.GetID(self)
	return State(self).id or 0
end

function Impl.GetChildren(self)
	return table.unpack(State(self).children or {})
end

function Impl.GetNumChildren(self)
	return #(State(self).children or {})
end

function Impl.GetRegions(self)
	return table.unpack(State(self).regions or {})
end

function Impl.GetNumRegions(self)
	return #(State(self).regions or {})
end

function Impl.SetAttribute(self, name, value)
	local st = State(self)
	st.attributes = st.attributes or {}
	st.attributes[name] = value
	if st.scripts.OnAttributeChanged then
		CallScript(self, "OnAttributeChanged", name, value)
	end
end

function Impl.GetAttribute(self, name)
	local st = State(self)
	return st.attributes and st.attributes[name]
end

for _, pair in ipairs({
	{ "EnableMouse", "IsMouseEnabled", "mouse" },
	{ "EnableMouseWheel", "IsMouseWheelEnabled", "mouseWheel" },
	{ "EnableKeyboard", "IsKeyboardEnabled", "keyboard" },
	{ "SetMovable", "IsMovable", "movable" },
	{ "SetResizable", "IsResizable", "resizable" },
	{ "SetToplevel", "IsToplevel", "toplevel" },
	{ "SetClampedToScreen", "IsClampedToScreen", "clamped" },
	{ "SetUserPlaced", "IsUserPlaced", "userPlaced" },
}) do
	local setter, getter, field = pair[1], pair[2], pair[3]
	Impl[setter] = function(self, flag)
		State(self)[field] = flag and true or false
	end
	Impl[getter] = function(self)
		return State(self)[field] and 1 or nil
	end
end

function Impl.SetBackdrop(self, backdrop)
	if backdrop ~= nil and type(backdrop) ~= "table" then
		error("Usage: Frame:SetBackdrop(backdropTable)", 2)
	end
	State(self).backdrop = backdrop
end

function Impl.GetBackdrop(self)
	return State(self).backdrop
end

function Impl.SetBackdropColor(self, r, g, b, a)
	CheckNumber(r, "Frame:SetBackdropColor(r, g, b[, a])")
end

function Impl.SetBackdropBorderColor(self, r, g, b, a)
	CheckNumber(r, "Frame:SetBackdropBorderColor(r, g, b[, a])")
end

function Impl.SetHitRectInsets(self, left, right, top, bottom)
	State(self).hitRect = { left, right, top, bottom }
end

function Impl.GetHitRectInsets(self)
	local rect = State(self).hitRect or { 0, 0, 0, 0 }
	return rect[1], rect[2], rect[3], rect[4]
end

-- ----------------------------------------------------------------------------
-- Regions: textures and font strings
-- ----------------------------------------------------------------------------

local FONTS = {}
local NATIVE_TEMPLATES = API.templates

local DRAW_LAYERS = { BACKGROUND = true, BORDER = true, ARTWORK = true, OVERLAY = true, HIGHLIGHT = true }

local function NewRegion(typeName, name, owner, layer)
	if layer ~= nil and not DRAW_LAYERS[layer] then
		error(("CreateTexture/CreateFontString: invalid draw layer '%s'"):format(tostring(layer)), 3)
	end
	local region = NewObject(typeName, ExpandName(name, owner), owner)
	local st = S[region]
	st.layer = layer or "ARTWORK"
	local ost = State(owner)
	ost.regions[#ost.regions + 1] = region
	return region
end

local function ApplyFont(region, font)
	local st = S[region]
	local fst = font and S[font]
	st.fontObject = font
	if fst then
		st.fontFile = fst.fontFile
		st.fontSize = fst.fontSize
		st.fontFlags = fst.fontFlags
		if fst.color then
			st.color = { fst.color[1], fst.color[2], fst.color[3], fst.color[4] }
		end
	end
end

function Impl.CreateTexture(self, name, layer, inherits)
	local texture = NewRegion("Texture", name, self, layer)
	if inherits then
		for template in tostring(inherits):gmatch("[^,%s]+") do
			local tag = NATIVE_TEMPLATES[template]
			if tag ~= "Texture" then
				error(("CreateTexture(): Couldn't find inherited node \"%s\""):format(template), 2)
			end
		end
	end
	return texture
end

function Impl.CreateFontString(self, name, layer, inherits)
	local fontString = NewRegion("FontString", name, self, layer)
	if inherits then
		for template in tostring(inherits):gmatch("[^,%s]+") do
			if FONTS[template] then
				ApplyFont(fontString, FONTS[template])
			elseif NATIVE_TEMPLATES[template] == "FontString" then
				ApplyFont(fontString, FONTS.GameFontNormal)
			else
				error(("CreateFontString(): Couldn't find inherited node \"%s\""):format(template), 2)
			end
		end
	end
	return fontString
end

function Impl.SetDrawLayer(self, layer)
	if not DRAW_LAYERS[layer] then
		error(("SetDrawLayer(): invalid draw layer '%s'"):format(tostring(layer)), 2)
	end
	State(self).layer = layer
end

function Impl.GetDrawLayer(self)
	return State(self).layer
end

function Impl.SetVertexColor(self, r, g, b, a)
	local st = State(self)
	CheckNumber(r, st.type .. ":SetVertexColor(r, g, b[, a])")
	CheckNumber(g, st.type .. ":SetVertexColor(r, g, b[, a])")
	CheckNumber(b, st.type .. ":SetVertexColor(r, g, b[, a])")
	st.vertexColor = { r, g, b, a or 1 }
end

function Impl.GetVertexColor(self)
	local c = State(self).vertexColor or { 1, 1, 1, 1 }
	return c[1], c[2], c[3], c[4]
end

function Impl.SetTexture(self, texture, g, b, a)
	local st = State(self)
	st.colorTexture = nil
	if type(texture) == "number" then
		CheckNumber(g, "Texture:SetTexture(r, g, b[, a])")
		CheckNumber(b, "Texture:SetTexture(r, g, b[, a])")
		st.texture = nil
		st.colorTexture = { texture, g, b, a or 1 }
		return 1
	elseif texture ~= nil and type(texture) ~= "string" then
		error("Usage: Texture:SetTexture(\"file\" or r, g, b[, a])", 2)
	end
	st.texture = texture
	st.portrait = nil
	if texture then
		SIM.texturePaths = SIM.texturePaths or {}
		SIM.texturePaths[texture] = (SIM.texturePaths[texture] or 0) + 1
	end
	return texture and 1 or nil
end

function Impl.GetTexture(self)
	local st = State(self)
	if st.colorTexture then
		return "Color-" .. table.concat(st.colorTexture, ",")
	end
	return st.texture
end

function Impl.SetTexCoord(self, ...)
	local n = select("#", ...)
	if n ~= 4 and n ~= 8 then
		error("Usage: Texture:SetTexCoord(left, right, top, bottom) or (ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)", 2)
	end
	for i = 1, n do
		CheckNumber(select(i, ...), "Texture:SetTexCoord(...)")
	end
	State(self).texCoord = { ... }
end

function Impl.GetTexCoord(self)
	local c = State(self).texCoord or { 0, 1, 0, 1 }
	if #c == 4 then
		return c[1], c[3], c[1], c[4], c[2], c[3], c[2], c[4]
	end
	return table.unpack(c)
end

function Impl.SetDesaturated(self, flag)
	State(self).desaturated = flag and true or false
	return 1
end

function Impl.IsDesaturated(self)
	return State(self).desaturated and 1 or nil
end

function Impl.SetBlendMode(self, mode)
	State(self).blendMode = mode
end

function Impl.GetBlendMode(self)
	return State(self).blendMode or "BLEND"
end

function Impl.SetRotation(self, radians)
	State(self).rotation = CheckNumber(radians, "Texture:SetRotation(radians)")
end

function Impl.SetGradient(self, orientation, r1, g1, b1, r2, g2, b2)
	for _, value in ipairs({ r1, g1, b1, r2, g2, b2 }) do
		CheckNumber(value, "Texture:SetGradient(\"orientation\", minR, minG, minB, maxR, maxG, maxB)")
	end
end

function Impl.SetGradientAlpha(self, orientation, ...)
	for i = 1, 8 do
		CheckNumber(select(i, ...), "Texture:SetGradientAlpha(\"orientation\", minR, minG, minB, minA, maxR, maxG, maxB, maxA)")
	end
end

-- FontString / FontInstance

local function FontSet(st)
	return st.fontFile ~= nil
end

function Impl.SetText(self, text)
	local st = State(self)
	if text ~= nil and type(text) ~= "string" and type(text) ~= "number" then
		error(("Usage: %s:SetText(\"text\")"):format(st.type), 2)
	end
	if st.type == "FontString" and not FontSet(st) then
		error("FontString:SetText(): Font not set", 2)
	end
	st.text = text ~= nil and tostring(text) or nil
end

function Impl.GetText(self)
	return State(self).text
end

function Impl.SetFormattedText(self, fmt, ...)
	return self:SetText(Format51(fmt, ...))
end

function Impl.SetFont(self, path, size, flags)
	local st = State(self)
	if type(path) ~= "string" then
		error(("Usage: %s:SetFont(\"font\", size[, \"flags\"])"):format(st.type), 2)
	end
	st.fontFile = path
	st.fontSize = CheckNumber(size, st.type .. ":SetFont(\"font\", size[, \"flags\"])")
	st.fontFlags = flags
	return 1
end

function Impl.GetFont(self)
	local st = State(self)
	return st.fontFile, st.fontSize, st.fontFlags
end

function Impl.SetFontObject(self, font)
	local st = State(self)
	if type(font) == "string" then
		local name = font
		font = _G[name]
		if not font then
			error(("%s:SetFontObject(): Couldn't find font named %s"):format(st.type, name), 2)
		end
	end
	if font ~= nil and (not S[font] or (S[font].type ~= "Font" and S[font].type ~= "FontString")) then
		error(("Usage: %s:SetFontObject(fontObject)"):format(st.type), 2)
	end
	ApplyFont(self, font)
end

function Impl.GetFontObject(self)
	return State(self).fontObject
end

function Impl.SetTextColor(self, r, g, b, a)
	local st = State(self)
	CheckNumber(r, st.type .. ":SetTextColor(r, g, b[, a])")
	CheckNumber(g, st.type .. ":SetTextColor(r, g, b[, a])")
	CheckNumber(b, st.type .. ":SetTextColor(r, g, b[, a])")
	st.color = { r, g, b, a or 1 }
end

function Impl.GetTextColor(self)
	local c = State(self).color or { 1, 1, 1, 1 }
	return c[1], c[2], c[3], c[4]
end

function Impl.SetShadowColor(self, r, g, b, a)
	CheckNumber(r, "SetShadowColor(r, g, b[, a])")
	State(self).shadowColor = { r, g, b, a or 1 }
end

function Impl.GetShadowColor(self)
	local c = State(self).shadowColor or { 0, 0, 0, 0 }
	return c[1], c[2], c[3], c[4]
end

function Impl.SetShadowOffset(self, x, y)
	State(self).shadowOffset = { x or 0, y or 0 }
end

function Impl.GetShadowOffset(self)
	local o = State(self).shadowOffset or { 0, 0 }
	return o[1], o[2]
end

function Impl.SetJustifyH(self, justify)
	State(self).justifyH = justify
end

function Impl.GetJustifyH(self)
	return State(self).justifyH or "CENTER"
end

function Impl.SetJustifyV(self, justify)
	State(self).justifyV = justify
end

function Impl.GetJustifyV(self)
	return State(self).justifyV or "MIDDLE"
end

function Impl.GetStringWidth(self)
	return StringWidth(State(self).text)
end

function Impl.GetStringHeight(self)
	return State(self).fontSize or 12
end

function Impl.CopyFontObject(self, other)
	if type(other) == "string" then
		other = _G[other]
	end
	ApplyFont(self, other)
end

-- ----------------------------------------------------------------------------
-- Frame creation
-- ----------------------------------------------------------------------------

local CREATABLE = {}
for _, typeName in ipairs({ "Frame", "Button", "CheckButton", "EditBox", "ScrollFrame", "Slider", "StatusBar",
	"Cooldown", "ColorSelect", "GameTooltip", "MessageFrame", "ScrollingMessageFrame", "SimpleHTML", "Model",
	"PlayerModel", "DressUpModel", "TabardModel", "MovieFrame", "Minimap", "QuestPOIFrame" }) do
	CREATABLE[typeName:lower()] = typeName
end

local TemplateBuilders = {}
SIM.TemplateBuilders = TemplateBuilders

-- Stock templates whose parts a test looks at, as the 3.3.5a FrameXML defines them.
-- UIPanelTemplates.xml: a 32 x 32 button with no anchors of its own.
function TemplateBuilders.UIPanelCloseButton(frame)
	frame:SetWidth(32)
	frame:SetHeight(32)
	frame:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
	frame:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
	frame:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
	frame:SetScript("OnClick", function(self)
		HideParentPanel(self)
	end)
end

-- Templates whose OnLoad builds names from self:GetName() (stock FrameXML + DC-Journal's replacements):
-- on an unnamed frame the client runs that OnLoad and it fails; the error reaches the error handler
-- and CreateFrame still returns the half-initialised frame.
local NEEDS_NAME = {}
for _, template in ipairs(API.needsName or {}) do
	NEEDS_NAME[template] = true
end

function CreateFrame(frameType, name, parent, templates)
	local typeName = type(frameType) == "string" and CREATABLE[frameType:lower()]
	if not typeName then
		error(("CreateFrame: Unknown frame type '%s'"):format(tostring(frameType)), 2)
	end
	if type(parent) == "string" then
		parent = _G[parent]
	end
	if parent ~= nil and (not S[parent] or S[parent].children == nil) then
		error("CreateFrame: parent is not a frame", 2)
	end
	local frame = NewObject(typeName, ExpandName(name, parent), parent)
	local st = S[frame]
	st.children = {}
	st.regions = {}
	st.scale = 1
	st.level = parent and ((S[parent].level or 0) + 1) or 0
	st.strata = parent and S[parent].strata or "MEDIUM"
	st.events = {}
	st.enabled = true
	st.visible = parent == nil or S[parent].visible == true
	if parent then
		local pst = S[parent]
		pst.children[#pst.children + 1] = frame
	end
	SIM.frames[#SIM.frames + 1] = frame
	if templates then
		for template in tostring(templates):gmatch("[^,%s]+") do
			if not NATIVE_TEMPLATES[template] then
				error(("CreateFrame(): Couldn't find inherited node \"%s\""):format(template), 2)
			end
			local builder = TemplateBuilders[template]
			if builder then
				builder(frame)
			end
			if NEEDS_NAME[template] and not st.name then
				errorHandler(("<string>:\"*:OnLoad\":1: attempt to concatenate a nil value (%s's OnLoad builds part names from self:GetName(); the frame has no name)\n%s")
					:format(template, debug.traceback("", 2)))
			end
		end
	end
	return frame
end

-- ----------------------------------------------------------------------------
-- Button / CheckButton
-- ----------------------------------------------------------------------------

local function ButtonTexture(self, slot, layer, value)
	local st = State(self)
	local texture = st[slot]
	if value == nil then
		if texture then
			S[texture].texture = nil
		end
		return
	end
	if type(value) == "string" then
		if not texture then
			texture = Impl.CreateTexture(self, nil, layer)
			Impl.SetAllPoints(texture, self)
			st[slot] = texture
		end
		Impl.SetTexture(texture, value)
	elseif S[value] and S[value].type == "Texture" then
		st[slot] = value
		if S[value].parent ~= self then
			Impl.SetParent(value, self)
		end
		if #S[value].points == 0 then
			Impl.SetAllPoints(value, self)
		end
	else
		error("Usage: Button:Set" .. slot .. "(texture or \"file\")", 3)
	end
end

for _, slot in ipairs({ "NormalTexture", "PushedTexture", "DisabledTexture", "HighlightTexture", "CheckedTexture", "DisabledCheckedTexture" }) do
	local layer = (slot == "HighlightTexture") and "HIGHLIGHT" or (slot:find("Checked") and "OVERLAY") or "ARTWORK"
	Impl["Set" .. slot] = function(self, value)
		ButtonTexture(self, slot, layer, value)
	end
	Impl["Get" .. slot] = function(self)
		return State(self)[slot]
	end
end

for _, slot in ipairs({ "NormalFontObject", "HighlightFontObject", "DisabledFontObject", "TextFontObject" }) do
	Impl["Set" .. slot] = function(self, font)
		if type(font) == "string" then
			font = _G[font]
		end
		State(self)[slot] = font
		if slot == "NormalFontObject" or slot == "TextFontObject" then
			local fontString = State(self).fontString
			if fontString then
				ApplyFont(fontString, font)
			end
		end
	end
	Impl["Get" .. slot] = function(self)
		return State(self)[slot]
	end
end

ImplFor.Button = {}

function ImplFor.Button.SetFontString(self, fontString)
	State(self).fontString = fontString
end

function ImplFor.Button.GetFontString(self)
	return State(self).fontString
end

function ImplFor.Button.SetText(self, text)
	local st = State(self)
	if not st.fontString then
		st.fontString = Impl.CreateFontString(self, nil, "ARTWORK")
		Impl.SetPoint(st.fontString, "CENTER", self, "CENTER", 0, 0)
		ApplyFont(st.fontString, st.NormalFontObject)
	end
	local fst = S[st.fontString]
	if not FontSet(fst) then
		-- A button without a font object keeps the text (the client draws nothing).
		fst.text = text ~= nil and tostring(text) or nil
		return
	end
	Impl.SetText(st.fontString, text)
end

function ImplFor.Button.GetText(self)
	local st = State(self)
	return st.fontString and S[st.fontString].text or nil
end

function ImplFor.Button.SetFormattedText(self, fmt, ...)
	return ImplFor.Button.SetText(self, Format51(fmt, ...))
end

function ImplFor.Button.GetTextWidth(self)
	return StringWidth(ImplFor.Button.GetText(self))
end

function ImplFor.Button.GetTextHeight(self)
	return 12
end

function ImplFor.Button.Enable(self)
	local st = State(self)
	if not st.enabled then
		st.enabled = true
		if st.scripts.OnEnable then
			CallScript(self, "OnEnable")
		end
	end
end

function ImplFor.Button.Disable(self)
	local st = State(self)
	if st.enabled then
		st.enabled = false
		if st.scripts.OnDisable then
			CallScript(self, "OnDisable")
		end
	end
end

function ImplFor.Button.IsEnabled(self)
	return State(self).enabled and 1 or nil
end

function ImplFor.Button.SetButtonState(self, state, locked)
	State(self).buttonState = state
end

function ImplFor.Button.GetButtonState(self)
	return State(self).buttonState or "NORMAL"
end

function ImplFor.Button.RegisterForClicks(self, ...)
	State(self).clicks = { ... }
end

function ImplFor.Button.Click(self, button, down)
	local st = State(self)
	if not st.enabled then
		return
	end
	button = button or "LeftButton"
	if st.scripts.PreClick then
		CallScript(self, "PreClick", button, down)
	end
	if st.scripts.OnClick then
		CallScript(self, "OnClick", button, down)
	end
	if st.scripts.PostClick then
		CallScript(self, "PostClick", button, down)
	end
end

function ImplFor.Button.LockHighlight(self)
	State(self).highlightLocked = true
end

function ImplFor.Button.UnlockHighlight(self)
	State(self).highlightLocked = false
end

ImplFor.CheckButton = {}

function ImplFor.CheckButton.SetChecked(self, checked)
	State(self).checked = checked and true or false
end

function ImplFor.CheckButton.GetChecked(self)
	return State(self).checked and 1 or nil
end

-- ----------------------------------------------------------------------------
-- EditBox
-- ----------------------------------------------------------------------------

ImplFor.EditBox = {}

function ImplFor.EditBox.SetText(self, text)
	local st = State(self)
	text = text ~= nil and tostring(text) or ""
	if st.maxLetters and st.maxLetters > 0 and #text > st.maxLetters then
		text = text:sub(1, st.maxLetters)
	end
	st.text = text
	if st.scripts.OnTextChanged then
		CallScript(self, "OnTextChanged", SIM.userInput and true or false)
	end
end

function ImplFor.EditBox.GetText(self)
	return State(self).text or ""
end

function ImplFor.EditBox.Insert(self, text)
	ImplFor.EditBox.SetText(self, (State(self).text or "") .. tostring(text or ""))
end

function ImplFor.EditBox.SetMaxLetters(self, count)
	State(self).maxLetters = count
end

function ImplFor.EditBox.GetMaxLetters(self)
	return State(self).maxLetters or 0
end

function ImplFor.EditBox.GetNumLetters(self)
	return #(State(self).text or "")
end

function ImplFor.EditBox.SetFocus(self)
	if SIM.focus ~= self then
		local previous = SIM.focus
		SIM.focus = self
		if previous and S[previous].scripts.OnEditFocusLost then
			CallScript(previous, "OnEditFocusLost")
		end
		if State(self).scripts.OnEditFocusGained then
			CallScript(self, "OnEditFocusGained")
		end
	end
end

function ImplFor.EditBox.ClearFocus(self)
	if SIM.focus == self then
		SIM.focus = nil
		if State(self).scripts.OnEditFocusLost then
			CallScript(self, "OnEditFocusLost")
		end
	end
end

function ImplFor.EditBox.HasFocus(self)
	return SIM.focus == self and 1 or nil
end

function ImplFor.EditBox.HighlightText(self, first, last)
	State(self).highlight = { first or 0, last or -1 }
end

function ImplFor.EditBox.SetNumeric(self, flag)
	State(self).numeric = flag and true or false
end

function ImplFor.EditBox.IsNumeric(self)
	return State(self).numeric and 1 or nil
end

function ImplFor.EditBox.SetMultiLine(self, flag)
	State(self).multiLine = flag and true or false
end

function ImplFor.EditBox.IsMultiLine(self)
	return State(self).multiLine and 1 or nil
end

function ImplFor.EditBox.SetAutoFocus(self, flag)
	State(self).autoFocus = flag and true or false
end

function ImplFor.EditBox.IsAutoFocus(self)
	return State(self).autoFocus and 1 or nil
end

function ImplFor.EditBox.SetCursorPosition(self, position)
	State(self).cursor = position
end

function ImplFor.EditBox.GetCursorPosition(self)
	return State(self).cursor or 0
end

-- ----------------------------------------------------------------------------
-- ScrollFrame / Slider / StatusBar
-- ----------------------------------------------------------------------------

ImplFor.ScrollFrame = {}

function ImplFor.ScrollFrame.SetScrollChild(self, child)
	local st = State(self)
	if child ~= nil and (not S[child] or S[child].children == nil) then
		error("ScrollFrame:SetScrollChild(): child must be a frame", 2)
	end
	st.scrollChild = child
	if child and S[child].parent ~= self then
		Impl.SetParent(child, self)
	end
end

function ImplFor.ScrollFrame.GetScrollChild(self)
	return State(self).scrollChild
end

function ImplFor.ScrollFrame.SetVerticalScroll(self, offset)
	State(self).vScroll = CheckNumber(offset, "ScrollFrame:SetVerticalScroll(offset)")
end

function ImplFor.ScrollFrame.GetVerticalScroll(self)
	return State(self).vScroll or 0
end

function ImplFor.ScrollFrame.SetHorizontalScroll(self, offset)
	State(self).hScroll = CheckNumber(offset, "ScrollFrame:SetHorizontalScroll(offset)")
end

function ImplFor.ScrollFrame.GetHorizontalScroll(self)
	return State(self).hScroll or 0
end

function ImplFor.ScrollFrame.GetVerticalScrollRange(self)
	local child = State(self).scrollChild
	if not child then
		return 0
	end
	return math.max(0, Impl.GetHeight(child) - Impl.GetHeight(self))
end

function ImplFor.ScrollFrame.GetHorizontalScrollRange(self)
	local child = State(self).scrollChild
	if not child then
		return 0
	end
	return math.max(0, Impl.GetWidth(child) - Impl.GetWidth(self))
end

local function RangeImpl(typeName)
	local impl = {}
	function impl.SetMinMaxValues(self, low, high)
		local st = State(self)
		st.min = CheckNumber(low, typeName .. ":SetMinMaxValues(min, max)")
		st.max = CheckNumber(high, typeName .. ":SetMinMaxValues(min, max)")
		if st.scripts.OnMinMaxChanged then
			CallScript(self, "OnMinMaxChanged", low, high)
		end
		if st.value and (st.value < low or st.value > high) then
			impl.SetValue(self, st.value)
		end
	end
	function impl.GetMinMaxValues(self)
		local st = State(self)
		return st.min or 0, st.max or 0
	end
	function impl.SetValue(self, value)
		local st = State(self)
		value = CheckNumber(value, typeName .. ":SetValue(value)")
		value = math.max(st.min or 0, math.min(st.max or 0, value))
		local changed = st.value ~= value
		st.value = value
		if changed and st.scripts.OnValueChanged then
			CallScript(self, "OnValueChanged", value)
		end
	end
	function impl.GetValue(self)
		return State(self).value or 0
	end
	return impl
end

ImplFor.Slider = RangeImpl("Slider")

function ImplFor.Slider.SetThumbTexture(self, value)
	ButtonTexture(self, "ThumbTexture", "ARTWORK", value)
end

function ImplFor.Slider.GetThumbTexture(self)
	return State(self).ThumbTexture
end

ImplFor.StatusBar = RangeImpl("StatusBar")

function ImplFor.StatusBar.SetStatusBarTexture(self, value)
	ButtonTexture(self, "BarTexture", "ARTWORK", value)
end

function ImplFor.StatusBar.GetStatusBarTexture(self)
	return State(self).BarTexture
end

function ImplFor.StatusBar.SetStatusBarColor(self, r, g, b, a)
	CheckNumber(r, "StatusBar:SetStatusBarColor(r, g, b[, a])")
	State(self).barColor = { r, g, b, a or 1 }
end

-- ----------------------------------------------------------------------------
-- GameTooltip
-- ----------------------------------------------------------------------------

ImplFor.GameTooltip = {}

local function TooltipLine(self, index, side)
	local st = State(self)
	st.lineRegions = st.lineRegions or {}
	local key = side .. index
	local region = st.lineRegions[key]
	if not region then
		local name = st.name and (st.name .. "Text" .. side .. index) or nil
		region = Impl.CreateFontString(self, name, "ARTWORK", index == 1 and "GameTooltipHeaderText" or "GameTooltipText")
		st.lineRegions[key] = region
	end
	return region
end

function ImplFor.GameTooltip.SetOwner(self, owner, anchor, x, y)
	local st = State(self)
	st.owner = owner
	st.anchor = anchor
	ImplFor.GameTooltip.ClearLines(self)
end

function ImplFor.GameTooltip.GetOwner(self)
	return State(self).owner
end

function ImplFor.GameTooltip.IsOwned(self, frame)
	return State(self).owner == frame and 1 or nil
end

function ImplFor.GameTooltip.ClearLines(self)
	local st = State(self)
	st.lines = {}
	for _, region in pairs(st.lineRegions or {}) do
		S[region].text = nil
		S[region].shown = false
	end
end

function ImplFor.GameTooltip.NumLines(self)
	return #(State(self).lines or {})
end

function ImplFor.GameTooltip.AddLine(self, text, r, g, b, wrap)
	local st = State(self)
	st.lines = st.lines or {}
	local index = #st.lines + 1
	st.lines[index] = { left = text ~= nil and tostring(text) or "", color = { r, g, b } }
	local left = TooltipLine(self, index, "Left")
	S[left].text = st.lines[index].left
	S[left].shown = true
	if r then
		S[left].color = { r, g, b, 1 }
	end
end

function ImplFor.GameTooltip.AddDoubleLine(self, leftText, rightText, lr, lg, lb, rr, rg, rb)
	ImplFor.GameTooltip.AddLine(self, leftText, lr, lg, lb)
	local st = State(self)
	local index = #st.lines
	st.lines[index].right = rightText ~= nil and tostring(rightText) or ""
	local right = TooltipLine(self, index, "Right")
	S[right].text = st.lines[index].right
	S[right].shown = true
end

function ImplFor.GameTooltip.SetText(self, text, r, g, b, a, wrap)
	ImplFor.GameTooltip.ClearLines(self)
	ImplFor.GameTooltip.AddLine(self, text, r, g, b, wrap)
end

function ImplFor.GameTooltip.SetHyperlink(self, link)
	ImplFor.GameTooltip.ClearLines(self)
	local spellID = tostring(link):match("spell:(%d+)")
	if spellID then
		spellID = tonumber(spellID)
		ImplFor.GameTooltip.AddLine(self, SIM.SpellName(spellID), 1, 1, 1)
		for _, line in ipairs(SIM.SpellTooltipLines(spellID)) do
			ImplFor.GameTooltip.AddLine(self, line, 1, 0.82, 0, true)
		end
		return
	end
	local talentID = tostring(link):match("talent:(%d+)")
	if talentID then
		ImplFor.GameTooltip.AddLine(self, "Talent " .. talentID, 1, 1, 1)
		return
	end
	Warn("GameTooltip:SetHyperlink with an unsupported link: " .. tostring(link))
end

function ImplFor.GameTooltip.AddTexture(self, texture)
	State(self).lastTexture = texture
end

ImplFor.GameTooltip.Show = function(self)
	Impl.Show(self)
end

ImplFor.GameTooltip.Hide = function(self)
	Impl.Hide(self)
	State(self).owner = nil
end

function SIM.TooltipText(tooltip)
	local st = State(tooltip)
	local out = {}
	for _, line in ipairs(st.lines or {}) do
		out[#out + 1] = line.right and (line.left .. " | " .. line.right) or line.left
	end
	return table.concat(out, "\n")
end

-- ----------------------------------------------------------------------------
-- Native animation groups (Region:CreateAnimationGroup)
-- ----------------------------------------------------------------------------

local animationGroups = setmetatable({}, { __mode = "k" })

function Impl.CreateAnimationGroup(self, name, inherits)
	local group = NewObject("AnimationGroup", name, self)
	local st = S[group]
	st.animations = {}
	st.playing = false
	local ost = State(self)
	ost.animationGroups = ost.animationGroups or {}
	ost.animationGroups[#ost.animationGroups + 1] = group
	animationGroups[group] = true
	return group
end

function Impl.GetAnimationGroups(self)
	return table.unpack(State(self).animationGroups or {})
end

function Impl.StopAnimating(self)
	for _, group in ipairs(State(self).animationGroups or {}) do
		group:Stop()
	end
end

ImplFor.AnimationGroup = {}

local ANIMATION_TYPES = { Animation = true, Alpha = true, Scale = true, Translation = true, Rotation = true, Path = true }

function ImplFor.AnimationGroup.CreateAnimation(self, animationType, name, inherits)
	animationType = animationType or "Animation"
	if not ANIMATION_TYPES[animationType] then
		error(("AnimationGroup:CreateAnimation(): Unknown animation type '%s'"):format(tostring(animationType)), 2)
	end
	local animation = NewObject(animationType, name, self)
	local st = S[animation]
	st.duration = 0
	st.startDelay = 0
	st.endDelay = 0
	st.order = 1
	local gst = State(self)
	gst.animations[#gst.animations + 1] = animation
	return animation
end

function ImplFor.AnimationGroup.GetAnimations(self)
	return table.unpack(State(self).animations)
end

local function GroupDuration(group)
	local byOrder = {}
	for _, animation in ipairs(S[group].animations) do
		local ast = S[animation]
		local total = (ast.startDelay or 0) + (ast.duration or 0) + (ast.endDelay or 0)
		byOrder[ast.order or 1] = math.max(byOrder[ast.order or 1] or 0, total)
	end
	local duration = 0
	for _, value in pairs(byOrder) do
		duration = duration + value
	end
	return duration
end

function ImplFor.AnimationGroup.Play(self)
	local st = State(self)
	st.playing = true
	st.paused = false
	st.elapsed = 0
	if st.scripts.OnPlay then
		CallScript(self, "OnPlay")
	end
end

function ImplFor.AnimationGroup.Stop(self)
	local st = State(self)
	if st.playing then
		st.playing = false
		if st.scripts.OnStop then
			CallScript(self, "OnStop", true)
		end
	end
end

function ImplFor.AnimationGroup.Finish(self)
	local st = State(self)
	if st.playing then
		st.playing = false
		if st.scripts.OnFinished then
			CallScript(self, "OnFinished", true)
		end
	end
end

function ImplFor.AnimationGroup.Pause(self)
	State(self).paused = true
end

function ImplFor.AnimationGroup.IsPlaying(self)
	return State(self).playing and 1 or nil
end

function ImplFor.AnimationGroup.IsPaused(self)
	return State(self).paused and 1 or nil
end

function ImplFor.AnimationGroup.IsDone(self)
	return (not State(self).playing) and 1 or nil
end

function ImplFor.AnimationGroup.SetLooping(self, looping)
	State(self).looping = looping
end

function ImplFor.AnimationGroup.GetLooping(self)
	return State(self).looping or "NONE"
end

function ImplFor.AnimationGroup.GetDuration(self)
	return GroupDuration(self)
end

ImplFor.Animation = {}

function ImplFor.Animation.SetDuration(self, duration)
	State(self).duration = CheckNumber(duration, "Animation:SetDuration(seconds)")
end

function ImplFor.Animation.GetDuration(self)
	return State(self).duration
end

function ImplFor.Animation.SetStartDelay(self, delay)
	State(self).startDelay = CheckNumber(delay, "Animation:SetStartDelay(seconds)")
end

function ImplFor.Animation.GetStartDelay(self)
	return State(self).startDelay
end

function ImplFor.Animation.SetEndDelay(self, delay)
	State(self).endDelay = CheckNumber(delay, "Animation:SetEndDelay(seconds)")
end

function ImplFor.Animation.GetEndDelay(self)
	return State(self).endDelay
end

function ImplFor.Animation.SetOrder(self, order)
	State(self).order = CheckNumber(order, "Animation:SetOrder(order)")
end

function ImplFor.Animation.GetOrder(self)
	return State(self).order
end

local function TickAnimations(elapsed)
	for group in pairs(animationGroups) do
		local st = S[group]
		if st and st.playing and not st.paused then
			st.elapsed = st.elapsed + elapsed
			local duration = GroupDuration(group)
			if st.elapsed >= duration then
				if st.looping == "REPEAT" or st.looping == "BOUNCE" then
					st.elapsed = 0
					if st.scripts.OnLoop then
						CallScript(group, "OnLoop", st.looping == "BOUNCE" and "REVERSE" or "FORWARD")
					end
				else
					st.playing = false
					if st.scripts.OnFinished then
						CallScript(group, "OnFinished", false)
					end
				end
			end
		end
	end
end

-- ----------------------------------------------------------------------------
-- Model frames (enough for templates that include them)
-- ----------------------------------------------------------------------------

ImplFor.Model = {}

function ImplFor.Model.SetModel(self, path)
	State(self).model = path
end

function ImplFor.Model.GetModel(self)
	return State(self).model
end

function ImplFor.Model.ClearModel(self)
	State(self).model = nil
end

-- ----------------------------------------------------------------------------
-- Build the widget types now that every implementation exists
-- ----------------------------------------------------------------------------

for typeName in pairs(API.widgets) do
	TypeOf(typeName)
end

-- ----------------------------------------------------------------------------
-- Fonts
-- ----------------------------------------------------------------------------

function CreateFont(name)
	local font = NewObject("Font", name, nil)
	local st = S[font]
	st.fontFile = nil
	FONTS[name or font] = font
	return font
end

local FONT_SIZES = { Small = 10, Large = 16, Huge = 20, Med = 13 }
for _, fontName in ipairs(API.fonts) do
	local font = CreateFont(fontName)
	local size = 12
	for key, value in pairs(FONT_SIZES) do
		if fontName:find(key, 1, true) then
			size = value
		end
	end
	Impl.SetFont(font, "Fonts\\FRIZQT__.TTF", size, "")
	if fontName:find("Normal", 1, true) then
		S[font].color = { 1, 0.82, 0, 1 }
	end
end

-- ----------------------------------------------------------------------------
-- Tick
-- ----------------------------------------------------------------------------

function SIM.Tick(elapsed)
	elapsed = elapsed or (1 / 30)
	SIM.now = SIM.now + elapsed
	local list = {}
	for index, frame in ipairs(SIM.frames) do
		list[index] = frame
	end
	for _, frame in ipairs(list) do
		local st = S[frame]
		if st and st.scripts.OnUpdate and IsVisible(frame) then
			CallScript(frame, "OnUpdate", elapsed)
		end
	end
	TickAnimations(elapsed)
	SIM.RunScheduled()
end

function SIM.Run(seconds, step)
	step = step or (1 / 30)
	local target = SIM.now + seconds
	while SIM.now < target - 1e-9 do
		SIM.Tick(step)
	end
end

local scheduled = {}
function SIM.Schedule(delay, func)
	scheduled[#scheduled + 1] = { at = SIM.now + delay, func = func }
end

function SIM.RunScheduled()
	local due = {}
	for index = #scheduled, 1, -1 do
		if scheduled[index].at <= SIM.now then
			table.insert(due, 1, scheduled[index])
			table.remove(scheduled, index)
		end
	end
	table.sort(due, function(a, b) return a.at < b.at end)
	for _, entry in ipairs(due) do
		SafeInvoke(entry.func)
	end
end

-- ----------------------------------------------------------------------------
-- Describe / find helpers for tests
-- ----------------------------------------------------------------------------

function SIM.Describe(object)
	local st = S[object]
	if not st then
		return tostring(object)
	end
	local path = {}
	local current = object
	while current and S[current] do
		local cst = S[current]
		local label = cst.name
		if not label and cst.parent then
			for key, value in pairs(cst.parent) do
				if value == current and type(key) == "string" then
					label = "." .. key
					break
				end
			end
		end
		table.insert(path, 1, label or ("<" .. cst.type .. ">"))
		if cst.name then
			break
		end
		current = cst.parent
	end
	return table.concat(path, "")
end

function SIM.Walk(root, visitor)
	local st = S[root]
	visitor(root)
	for _, region in ipairs(st.regions or {}) do
		visitor(region)
	end
	for _, child in ipairs(st.children or {}) do
		SIM.Walk(child, visitor)
	end
end

return SIM
