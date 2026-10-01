--[[
	DC-Talents - retail FrameXML interpreter.

	_tools/dc-talents/xml2lua.py turns retail .xml files into Lua tables that mirror the XML tree
	(tag, attr, children, compiled inline scripts). This file instantiates those tables with retail
	semantics on the 3.3.5 client:

	  * template chains (inherits="A, B"): A's full content, then B's, then the element's own;
	    names that are not retail templates we carry are passed through to the native CreateFrame,
	  * mixin= (applied first), KeyValues (types string/number/boolean/global) before OnLoad,
	  * parentKey / parentArray, relativeKey anchors ("$parent.$parent.Foo"),
	  * textureSubLevel: 3.3.5 ignores texture sublevels and draws later-created textures on top,
	    so regions are created sorted by sublevel (stable within a sublevel),
	  * Scripts with method= / function= / inline bodies and inherit="prepend" / "append",
	  * anchors of a whole instantiation are applied after the tree exists (forward references to
	    siblings work), then OnLoad runs children-first, as retail does.

	Retail-only region types (Line, MaskTexture) and animations are provided by Line.lua, Engine.lua
	and Animations.lua.
]]

local _, ns = ...
setfenv(1, ns.env)

local XML = {}
ns.XML = XML

local RealCreateFrame = ns.realG.CreateFrame

-- Stock 3.3.5 templates name their parts after the frame ($parentScrollBar, $parentText, ...) and some
-- OnLoad scripts look them up by name (ScrollFrame_OnLoad: _G[self:GetName() .. "ScrollBar"]). DC-Journal
-- replaces UIPanelScrollFrameTemplate globally with the same name-based OnLoad. Retail XML creates
-- frames anonymously, so a frame built from a native template always gets a generated name.
local nativeNameCount = 0

local function NativeCreateFrame(frameType, name, parent, templates)
	if templates and not name then
		nativeNameCount = nativeNameCount + 1
		name = "DCTalentsNative" .. nativeNameCount
	end
	return RealCreateFrame(frameType, name, parent, templates)
end
local Engine -- resolved lazily (Engine.lua loads after this file's definitions are used)

local templates = {}
local templateSource = {}
local deferredDefinitions = {}
local deferNames = {}

XML.templates = templates

-- Retail "intrinsic" frame types carry behaviour of their own (a DropdownButton opens its menu on
-- mouse down). Lower-case frame type -> { mixin = "EnvName", onBuilt = function(frame) }, filled
-- by the stand-in layer.
XML.intrinsics = {}

-- Frame types the 3.3.5 engine knows, keyed by lower-case name.
local NativeFrameTypes = {}
for _, frameType in ipairs({
	"Frame", "Button", "CheckButton", "EditBox", "ScrollFrame", "Slider", "StatusBar", "Cooldown",
	"Model", "PlayerModel", "DressUpModel", "TabardModel", "GameTooltip", "MessageFrame",
	"ScrollingMessageFrame", "SimpleHTML", "ColorSelect", "MovieFrame", "Minimap", "QuestPOIFrame",
}) do
	NativeFrameTypes[frameType:lower()] = frameType
end

-- Retail frame types that do not exist on 3.3.5, mapped to the closest native type.
local FrameTypeAliases = {
	dropdownbutton = "Button",
	eventframe = "Frame",
	eventbutton = "Button",
	eventeditbox = "EditBox",
	eventscrollframe = "ScrollFrame",
	itembutton = "Button",
	containedalertframe = "Button",
	modelscene = "Frame",
	cinematicmodel = "PlayerModel",
	unitpositionframe = "Frame",
	scrollbox = "Frame",
	blob = "Frame",
	archaeologydigsiteframe = "Frame",
	arrowbutton = "Button",
}

local RegionTags = { Texture = true, FontString = true, Line = true, MaskTexture = true }

local ButtonTextureTags = {
	NormalTexture = "NormalTexture",
	PushedTexture = "PushedTexture",
	DisabledTexture = "DisabledTexture",
	HighlightTexture = "HighlightTexture",
	CheckedTexture = "CheckedTexture",
	DisabledCheckedTexture = "DisabledCheckedTexture",
}

local AnimationTags = {
	Alpha = true, Scale = true, LineScale = true, Translation = true, LineTranslation = true,
	Rotation = true, TextureCoordTranslation = true, FlipBook = true, Path = true, VertexColor = true,
	Animation = true,
}

local function IsFrameTag(tag)
	local lower = tag and tag:lower()
	return lower ~= nil and (NativeFrameTypes[lower] ~= nil or FrameTypeAliases[lower] ~= nil)
end

function XML.NativeFrameType(frameType)
	local lower = (frameType or "Frame"):lower()
	return NativeFrameTypes[lower] or FrameTypeAliases[lower] or "Frame"
end

-- ----------------------------------------------------------------------------
-- Small helpers
-- ----------------------------------------------------------------------------

local function Children(el, tag)
	local list = {}
	if el.children then
		for _, child in ipairs(el.children) do
			if not tag or child.tag == tag then
				list[#list + 1] = child
			end
		end
	end
	return list
end

local function FirstChild(el, tag)
	if el.children then
		for _, child in ipairs(el.children) do
			if child.tag == tag then
				return child
			end
		end
	end
	return nil
end

local function Attr(el, key)
	return el.attr and el.attr[key]
end

local function Bool(value)
	return value == "true" or value == "1"
end

local function Num(value, default)
	local n = tonumber(value)
	if n == nil then
		return default
	end
	return n
end

local function SplitList(value)
	local list = {}
	if value then
		for item in value:gmatch("[^,]+") do
			item = item:match("^%s*(.-)%s*$")
			if item ~= "" then
				list[#list + 1] = item
			end
		end
	end
	return list
end

-- Resolves "Foo.Bar.Baz" against our environment (falls through to _G).
function XML.ResolvePath(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end
	local current = ns.env
	for segment in path:gmatch("[^%.]+") do
		if type(current) ~= "table" then
			return nil
		end
		current = current[segment]
	end
	return current
end

-- A text= attribute holds either a global string name or literal text.
function XML.ResolveText(text)
	if text == nil then
		return nil
	end
	local value = ns.env[text]
	if type(value) == "string" then
		return value
	end
	return text
end

local function ResolveName(name, parent)
	if not name then
		return nil
	end
	if name:find("$parent", 1, true) then
		local parentName = parent and parent.GetName and parent:GetName() or ""
		name = name:gsub("%$parent", parentName)
	end
	return name
end

local function ReportError(context, err)
	local handler = geterrorhandler and geterrorhandler()
	if handler then
		handler(("DC-Talents %s: %s"):format(context, tostring(err)))
	end
end

-- ----------------------------------------------------------------------------
-- Template registry and chain resolution
-- ----------------------------------------------------------------------------

function XML.GetTemplate(name)
	return templates[name]
end

function XML.RegisterTemplate(name, element, source)
	templates[name] = element
	templateSource[name] = source
end

-- Retail semantics: inherits="A, B" applies A (with its own ancestry), then B, then the element.
-- Returns the ordered list of our template elements and the list of native template names.
local function ExpandInherits(inherits, chain, natives, seen)
	for _, templateName in ipairs(SplitList(inherits)) do
		local template = templates[templateName]
		if template then
			if not seen[template] then
				seen[template] = true
				ExpandInherits(Attr(template, "inherits"), chain, natives, seen)
				chain[#chain + 1] = template
			end
		else
			local known = false
			for _, existing in ipairs(natives) do
				if existing == templateName then
					known = true
					break
				end
			end
			if not known then
				natives[#natives + 1] = templateName
			end
		end
	end
end

function XML.ResolveChain(inherits, ownElement)
	local chain, natives, seen = {}, {}, {}
	ExpandInherits(inherits, chain, natives, seen)
	if ownElement then
		chain[#chain + 1] = ownElement
	end
	return chain, natives
end

function XML.HasTemplate(templateList)
	for _, name in ipairs(SplitList(templateList)) do
		if templates[name] then
			return true
		end
	end
	return false
end

-- ----------------------------------------------------------------------------
-- Build context: anchors and OnLoads of a whole instantiation run after the tree exists
-- ----------------------------------------------------------------------------

local function NewContext()
	return { anchors = {}, loads = {} }
end

local function FinishContext(ctx)
	for _, entry in ipairs(ctx.anchors) do
		local ok, err = pcall(entry.apply)
		if not ok then
			ReportError("anchor", err)
		end
	end

	for _, entry in ipairs(ctx.loads) do
		local ok, err = pcall(entry.func, entry.object)
		if not ok then
			ReportError(("OnLoad of %s"):format(tostring(entry.label or entry.object)), err)
		end
	end
end

-- ----------------------------------------------------------------------------
-- KeyValues, attributes, sizes, anchors
-- ----------------------------------------------------------------------------

local function ApplyKeyValues(object, element)
	for _, block in ipairs(Children(element, "KeyValues")) do
		for _, kv in ipairs(Children(block, "KeyValue")) do
			local key = Attr(kv, "key")
			local value = Attr(kv, "value")
			local valueType = Attr(kv, "type")
			if key then
				if Attr(kv, "keyType") == "number" then
					key = tonumber(key) or key
				end
				local resolved
				if valueType == "number" then
					resolved = tonumber(value)
				elseif valueType == "boolean" then
					resolved = Bool(value)
				elseif valueType == "global" then
					resolved = XML.ResolvePath(value)
				else
					resolved = value
				end
				object[key] = resolved
			end
		end
	end
end
XML.ApplyKeyValues = ApplyKeyValues

local function ReadSize(sizeElement)
	local x, y = Num(Attr(sizeElement, "x")), Num(Attr(sizeElement, "y"))
	local abs = FirstChild(sizeElement, "AbsDimension")
	if abs then
		x = x or Num(Attr(abs, "x"))
		y = y or Num(Attr(abs, "y"))
	end
	return x, y
end

local function ApplySize(object, element)
	local sizeElement = FirstChild(element, "Size")
	if not sizeElement then
		return
	end
	local x, y = ReadSize(sizeElement)
	if x and y then
		object:SetSize(x, y)
	elseif x then
		object:SetWidth(x)
	elseif y then
		object:SetHeight(y)
	end
end

local function ReadOffset(anchor)
	local x, y = Num(Attr(anchor, "x")), Num(Attr(anchor, "y"))
	local offset = FirstChild(anchor, "Offset")
	if offset then
		x = x or Num(Attr(offset, "x"))
		y = y or Num(Attr(offset, "y"))
		local abs = FirstChild(offset, "AbsDimension")
		if abs then
			x = x or Num(Attr(abs, "x"))
			y = y or Num(Attr(abs, "y"))
		end
	end
	return x or 0, y or 0
end

-- "$parent.$parent.Foo" resolved from the anchored object.
function XML.ResolveRelativeKey(object, key)
	local current = object
	for segment in key:gmatch("[^%.]+") do
		if current == nil then
			return nil
		end
		if segment == "$parent" then
			current = current.GetParent and current:GetParent() or nil
		else
			current = current[segment]
		end
	end
	return current
end

local function ResolveAnchorTarget(object, anchor)
	local relativeKey = Attr(anchor, "relativeKey")
	if relativeKey then
		return XML.ResolveRelativeKey(object, relativeKey)
	end

	local relativeTo = Attr(anchor, "relativeTo")
	if relativeTo then
		if relativeTo == "$parent" then
			return object:GetParent()
		end
		local parent = object:GetParent()
		local name = ResolveName(relativeTo, parent)
		return ns.realG[name]
	end

	return nil
end

local function QueueAnchors(ctx, object, element)
	local anchors = FirstChild(element, "Anchors")
	local setAllPoints = Attr(element, "setAllPoints")
	if not anchors and setAllPoints == nil then
		return
	end

	ctx.anchors[#ctx.anchors + 1] = {
		apply = function()
			if Bool(setAllPoints) then
				object:SetAllPoints()
			end
			if anchors then
				for _, anchor in ipairs(Children(anchors, "Anchor")) do
					local point = Attr(anchor, "point") or "CENTER"
					local relativePoint = Attr(anchor, "relativePoint") or point
					local x, y = ReadOffset(anchor)
					local target = ResolveAnchorTarget(object, anchor)
					if target ~= nil then
						object:SetPoint(point, target, relativePoint, x, y)
					else
						object:SetPoint(point, object:GetParent(), relativePoint, x, y)
					end
				end
			end
		end,
	}
end
XML.QueueAnchors = QueueAnchors

local function AssignParentKeys(owner, object, element)
	local parentKey = Attr(element, "parentKey")
	if parentKey and owner then
		owner[parentKey] = object
	end
	local parentArray = Attr(element, "parentArray")
	if parentArray and owner then
		local array = owner[parentArray]
		if type(array) ~= "table" then
			array = {}
			owner[parentArray] = array
		end
		array[#array + 1] = object
	end
end
XML.AssignParentKeys = AssignParentKeys

local function ReadColor(colorElement)
	local named = Attr(colorElement, "color")
	if named then
		local color = XML.ResolvePath(named)
		if type(color) == "table" then
			return color.r or 1, color.g or 1, color.b or 1, color.a or 1
		end
	end
	return Num(Attr(colorElement, "r"), 0), Num(Attr(colorElement, "g"), 0), Num(Attr(colorElement, "b"), 0), Num(Attr(colorElement, "a"), 1)
end
XML.ReadColor = ReadColor

-- ----------------------------------------------------------------------------
-- Scripts
-- ----------------------------------------------------------------------------

local function MakeScriptFunction(scriptElement)
	if scriptElement.func then
		return scriptElement.func
	end

	local method = Attr(scriptElement, "method")
	if method then
		return function(self, ...)
			local func = self[method]
			if func then
				return func(self, ...)
			end
		end
	end

	local functionName = Attr(scriptElement, "function")
	if functionName then
		return function(...)
			local func = XML.ResolvePath(functionName)
			if type(func) == "function" then
				return func(...)
			end
		end
	end

	return nil
end

-- Composes the Scripts blocks of a whole chain into one function per handler.
local function ComposeScripts(chain)
	local composed = {}
	for _, element in ipairs(chain) do
		for _, scripts in ipairs(Children(element, "Scripts")) do
			for _, script in ipairs(scripts.children or {}) do
				local func = MakeScriptFunction(script)
				local handler = script.tag
				if func then
					local previous = composed[handler]
					local mode = Attr(script, "inherit")
					if previous and mode == "prepend" then
						composed[handler] = function(...)
							func(...)
							return previous(...)
						end
					elseif previous and mode == "append" then
						composed[handler] = function(...)
							previous(...)
							return func(...)
						end
					else
						composed[handler] = func
					end
				elseif not script.func and not Attr(script, "method") and not Attr(script, "function") then
					-- An empty handler element clears the inherited one (retail behaviour).
					composed[handler] = false
				end
			end
		end
	end
	return composed
end
XML.ComposeScripts = ComposeScripts

local function ApplyScripts(ctx, object, chain, label)
	for handler, func in pairs(ComposeScripts(chain)) do
		if handler == "OnLoad" then
			if func then
				ctx.loads[#ctx.loads + 1] = { object = object, func = func, label = label }
			end
		elseif func then
			Engine.SetScriptSafe(object, handler, func)
		end
	end
end

-- ----------------------------------------------------------------------------
-- Regions
-- ----------------------------------------------------------------------------

local LayerNames = { BACKGROUND = true, BORDER = true, ARTWORK = true, OVERLAY = true, HIGHLIGHT = true }

local function ApplyTextureContent(texture, element)
	local attr = element.attr or {}

	if attr.file then
		texture:SetTexture(attr.file)
	end
	if attr.atlas then
		texture:SetAtlas(attr.atlas, Bool(attr.useAtlasSize))
	end
	if attr.alphaMode then
		local mode = attr.alphaMode
		-- 3.3.5 multiplies a MOD texture at full strength whatever its alpha, where retail fades the
		-- multiply with it (the active spec card's alpha 0.1 MOD wash turned the whole card olive). A
		-- faint MOD layer is closer to retail as a faint alpha-blended overlay.
		if mode == "MOD" and attr.alpha and Num(attr.alpha, 1) < 1 then
			mode = "BLEND"
		end
		texture:SetBlendMode(mode)
	end
	if attr.desaturated then
		texture:SetDesaturated(Bool(attr.desaturated))
	end
	if attr.rotation then
		texture:SetRotation(math.rad(Num(attr.rotation, 0)))
	end

	local texCoords = FirstChild(element, "TexCoords")
	if texCoords then
		local rect = FirstChild(texCoords, "Rect")
		if rect then
			texture:SetTexCoord(
				Num(Attr(rect, "ULx"), 0), Num(Attr(rect, "ULy"), 0), Num(Attr(rect, "LLx"), 0), Num(Attr(rect, "LLy"), 1),
				Num(Attr(rect, "URx"), 1), Num(Attr(rect, "URy"), 0), Num(Attr(rect, "LRx"), 1), Num(Attr(rect, "LRy"), 1))
		else
			texture:SetTexCoord(Num(Attr(texCoords, "left"), 0), Num(Attr(texCoords, "right"), 1), Num(Attr(texCoords, "top"), 0), Num(Attr(texCoords, "bottom"), 1))
		end
	end

	local color = FirstChild(element, "Color")
	if color then
		local r, g, b, a = ReadColor(color)
		if texture:GetTexture() or attr.file or attr.atlas or texture.__dcAtlas then
			texture:SetVertexColor(r, g, b, a)
		else
			texture:SetColorTexture(r, g, b, a)
		end
	end

	local gradient = FirstChild(element, "Gradient")
	if gradient then
		local minColor, maxColor = FirstChild(gradient, "MinColor"), FirstChild(gradient, "MaxColor")
		if minColor and maxColor then
			local r1, g1, b1, a1 = ReadColor(minColor)
			local r2, g2, b2, a2 = ReadColor(maxColor)
			if not texture:GetTexture() then
				texture:SetTexture(1, 1, 1, 1)
			end
			texture:SetGradientAlpha(Attr(gradient, "orientation") or "HORIZONTAL", r1, g1, b1, a1, r2, g2, b2, a2)
		end
	end
end

local function ApplyFontStringContent(fontString, element)
	local attr = element.attr or {}
	if attr.font then
		fontString:SetFont(attr.font, Num(attr.height or attr.size, 12), attr.outline)
	end
	if attr.text then
		fontString:SetText(XML.ResolveText(attr.text))
	end
	if attr.justifyH then
		fontString:SetJustifyH(attr.justifyH)
	end
	if attr.justifyV then
		fontString:SetJustifyV(attr.justifyV)
	end
	if attr.maxLines then
		fontString:SetMaxLines(Num(attr.maxLines, 0))
	end
	if attr.wordwrap then
		fontString:SetWordWrap(Bool(attr.wordwrap))
	end
	if attr.nonspacewrap then
		fontString:SetNonSpaceWrap(Bool(attr.nonspacewrap))
	end
	if attr.spacing then
		fontString:SetSpacing(Num(attr.spacing, 0))
	end

	local color = FirstChild(element, "Color")
	if color then
		fontString:SetTextColor(ReadColor(color))
	end

	local shadow = FirstChild(element, "Shadow")
	if shadow then
		local shadowColor = FirstChild(shadow, "Color")
		if shadowColor then
			fontString:SetShadowColor(ReadColor(shadowColor))
		end
		local offset = FirstChild(shadow, "Offset")
		if offset then
			fontString:SetShadowOffset(ReadOffset(shadow))
		end
	end
end

local function ApplyRegionCommon(ctx, owner, region, element)
	local attr = element.attr or {}
	ApplyKeyValues(region, element)
	ApplySize(region, element)
	if attr.alpha then
		region:SetAlpha(Num(attr.alpha, 1))
	end
	if attr.hidden ~= nil then
		if Bool(attr.hidden) then
			region:Hide()
		else
			region:Show()
		end
	end
	QueueAnchors(ctx, region, element)
end

-- Retail places a texture or font string whose definition names no anchors (setAllPoints="false"
-- opts out); the 3.3.5 loader leaves it without points, and a region without points never draws.
-- A texture fills its parent (retail's GrayOverlay dims a whole tree that way). A font string is
-- centred on it at its text size: filling a 1 x 1 layout frame would squeeze the text to nothing.
local function QueueDefaultAnchor(ctx, region, chain, isFontString)
	for _, part in ipairs(chain) do
		if FirstChild(part, "Anchors") or Attr(part, "setAllPoints") ~= nil then
			return
		end
	end
	ctx.anchors[#ctx.anchors + 1] = {
		apply = function()
			if region:GetNumPoints() > 0 then
				return
			end
			if isFontString then
				region:SetPoint("CENTER")
			else
				region:SetAllPoints()
			end
		end,
	}
end

local function BuildLine(ctx, owner, layer, sublevel, chain)
	local line = owner:CreateLine(nil, layer, nil, sublevel)
	for _, element in ipairs(chain) do
		local attr = element.attr or {}
		if attr.thickness then
			line:SetThickness(Num(attr.thickness, 1))
		end
		if attr.file then
			line:SetTexture(attr.file)
		end
		if attr.atlas then
			line:SetAtlas(attr.atlas, Bool(attr.useAtlasSize))
		end
		if attr.alphaMode then
			line:SetBlendMode(attr.alphaMode)
		end
		local color = FirstChild(element, "Color")
		if color then
			line:SetVertexColor(ReadColor(color))
		end
		ApplyKeyValues(line, element)
		if attr.alpha then
			line:SetAlpha(Num(attr.alpha, 1))
		end
		if attr.hidden ~= nil then
			if Bool(attr.hidden) then
				line:Hide()
			else
				line:Show()
			end
		end
		for _, pointTag in ipairs({ "StartAnchor", "EndAnchor" }) do
			local anchor = FirstChild(element, pointTag)
			if anchor then
				ctx.anchors[#ctx.anchors + 1] = {
					apply = function()
						local target = ResolveAnchorTarget(line, anchor) or owner
						local x, y = ReadOffset(anchor)
						if pointTag == "StartAnchor" then
							line:SetStartPoint(Attr(anchor, "relativePoint") or "CENTER", target, x, y)
						else
							line:SetEndPoint(Attr(anchor, "relativePoint") or "CENTER", target, x, y)
						end
					end,
				}
			end
		end
	end
	return line
end

-- Builds one region element (Texture / FontString / Line / MaskTexture) on `owner`.
function XML.BuildRegion(ctx, owner, layer, sublevel, element)
	local tag = element.tag
	local attr = element.attr or {}
	local chain, natives = XML.ResolveChain(attr.inherits, element)
	local name = ResolveName(attr.name, owner)
	local region

	if tag == "Texture" then
		-- A native template name we do not know may not exist on 3.3.5 either: fall back to none.
		local ok, created = pcall(owner.CreateTexture, owner, name, layer, natives[1], sublevel)
		region = ok and created or owner:CreateTexture(name, layer, nil, sublevel)
		for _, part in ipairs(chain) do
			ApplyTextureContent(region, part)
			ApplyRegionCommon(ctx, owner, region, part)
		end
		QueueDefaultAnchor(ctx, region, chain, false)
	elseif tag == "FontString" then
		region = owner:CreateFontString(name, layer, natives[1])
		for _, part in ipairs(chain) do
			ApplyFontStringContent(region, part)
			ApplyRegionCommon(ctx, owner, region, part)
		end
		QueueDefaultAnchor(ctx, region, chain, true)
	elseif tag == "Line" then
		region = BuildLine(ctx, owner, layer, sublevel, chain)
	elseif tag == "MaskTexture" then
		region = owner:CreateMaskTexture(name, layer, nil, sublevel)
		for _, part in ipairs(chain) do
			if Attr(part, "atlas") then
				region:SetAtlas(Attr(part, "atlas"), Bool(Attr(part, "useAtlasSize")))
			end
			ApplyRegionCommon(ctx, owner, region, part)
		end
	else
		return nil
	end

	AssignParentKeys(owner, region, element)

	for _, part in ipairs(chain) do
		for _, animations in ipairs(Children(part, "Animations")) do
			for _, groupElement in ipairs(Children(animations, "AnimationGroup")) do
				XML.BuildAnimationGroup(ctx, region, groupElement)
			end
		end
	end

	local scripts = ComposeScripts(chain)
	for handler, func in pairs(scripts) do
		if func then
			if handler == "OnLoad" then
				ctx.loads[#ctx.loads + 1] = { object = region, func = func, label = attr.parentKey }
			else
				Engine.SetRegionScript(region, handler, func)
			end
		end
	end

	return region
end

local function BuildLayers(ctx, frame, chain)
	local entries = {}
	local sequence = 0
	for _, element in ipairs(chain) do
		for _, layers in ipairs(Children(element, "Layers")) do
			for _, layerElement in ipairs(Children(layers, "Layer")) do
				local level = Attr(layerElement, "level") or "ARTWORK"
				if not LayerNames[level] then
					level = "ARTWORK"
				end
				local sublevel = Num(Attr(layerElement, "textureSubLevel"), 0)
				for _, regionElement in ipairs(layerElement.children or {}) do
					if RegionTags[regionElement.tag] then
						sequence = sequence + 1
						entries[#entries + 1] = { level = level, sublevel = sublevel, sequence = sequence, element = regionElement }
					end
				end
			end
		end
	end

	-- Stable sort by sublevel: later creation draws on top within a layer on 3.3.5.
	table.sort(entries, function(a, b)
		if a.sublevel ~= b.sublevel then
			return a.sublevel < b.sublevel
		end
		return a.sequence < b.sequence
	end)

	for _, entry in ipairs(entries) do
		XML.BuildRegion(ctx, frame, entry.level, entry.sublevel, entry.element)
	end
end

-- ----------------------------------------------------------------------------
-- Frame attributes and the special children of buttons, edit boxes, bars, ...
-- ----------------------------------------------------------------------------

local function ApplyFrameAttributes(ctx, frame, element)
	local attr = element.attr or {}

	if attr.alpha then
		frame:SetAlpha(Num(attr.alpha, 1))
	end
	if attr.scale then
		frame:SetScale(Num(attr.scale, 1))
	end
	if attr.frameStrata then
		frame:SetFrameStrata(attr.frameStrata)
	end
	if attr.frameLevel then
		frame:SetFrameLevel(ns.Engine.MapFrameLevel(Num(attr.frameLevel, 1)))
	end
	if attr.toplevel then
		frame:SetToplevel(Bool(attr.toplevel))
	end
	if attr.movable then
		frame:SetMovable(Bool(attr.movable))
	end
	if attr.resizable then
		frame:SetResizable(Bool(attr.resizable))
	end
	if attr.enableMouse then
		frame:EnableMouse(Bool(attr.enableMouse))
	end
	if attr.enableMouseClicks or attr.enableMouseMotion then
		frame:EnableMouse(Bool(attr.enableMouseClicks) or Bool(attr.enableMouseMotion))
	end
	if attr.enableKeyboard then
		frame:EnableKeyboard(Bool(attr.enableKeyboard))
	end
	if attr.clampedToScreen then
		frame:SetClampedToScreen(Bool(attr.clampedToScreen))
	end
	if attr.id then
		frame:SetID(Num(attr.id, 0))
	end
	if attr.text and frame.SetText then
		frame:SetText(XML.ResolveText(attr.text))
	end
	if attr.registerForClicks and frame.RegisterForClicks then
		frame:RegisterForClicks(unpack(SplitList(attr.registerForClicks)))
	end
	if attr.registerForDrag and frame.RegisterForDrag then
		frame:RegisterForDrag(unpack(SplitList(attr.registerForDrag)))
	end

	-- EditBox
	if attr.autoFocus and frame.SetAutoFocus then
		frame:SetAutoFocus(Bool(attr.autoFocus))
	end
	if attr.multiLine and frame.SetMultiLine then
		frame:SetMultiLine(Bool(attr.multiLine))
	end
	if attr.letters and frame.SetMaxLetters then
		frame:SetMaxLetters(Num(attr.letters, 0))
	end
	if attr.numeric and frame.SetNumeric then
		frame:SetNumeric(Bool(attr.numeric))
	end
	if attr.password and frame.SetPassword then
		frame:SetPassword(Bool(attr.password))
	end
	if attr.historyLines and frame.SetHistoryLines then
		frame:SetHistoryLines(Num(attr.historyLines, 0))
	end

	-- Slider / StatusBar
	if attr.orientation and frame.SetOrientation then
		frame:SetOrientation(attr.orientation)
	end
	if (attr.minValue or attr.maxValue) and frame.SetMinMaxValues then
		frame:SetMinMaxValues(Num(attr.minValue, 0), Num(attr.maxValue, 0))
	end
	if attr.valueStep and frame.SetValueStep then
		frame:SetValueStep(Num(attr.valueStep, 1))
	end
	if attr.defaultValue and frame.SetValue then
		frame:SetValue(Num(attr.defaultValue, 0))
	end

	-- CheckButton
	if attr.checked and frame.SetChecked then
		frame:SetChecked(Bool(attr.checked))
	end

	ApplySize(frame, element)

	local insets = FirstChild(element, "HitRectInsets")
	if insets then
		frame:SetHitRectInsets(Num(Attr(insets, "left"), 0), Num(Attr(insets, "right"), 0), Num(Attr(insets, "top"), 0), Num(Attr(insets, "bottom"), 0))
	end

	local resizeBounds = FirstChild(element, "ResizeBounds")
	if resizeBounds then
		local minResize, maxResize = FirstChild(resizeBounds, "minResize"), FirstChild(resizeBounds, "maxResize")
		if minResize and frame.SetMinResize then
			frame:SetMinResize(ReadSize(minResize))
		end
		if maxResize and frame.SetMaxResize then
			frame:SetMaxResize(ReadSize(maxResize))
		end
	end

	local attributes = FirstChild(element, "Attributes")
	if attributes then
		for _, attribute in ipairs(Children(attributes, "Attribute")) do
			local value = Attr(attribute, "value")
			local valueType = Attr(attribute, "type")
			if valueType == "number" then
				value = tonumber(value)
			elseif valueType == "boolean" then
				value = Bool(value)
			elseif valueType == "global" then
				value = XML.ResolvePath(value)
			end
			frame:SetAttribute(Attr(attribute, "name"), value)
		end
	end

	local textInsets = FirstChild(element, "TextInsets")
	if textInsets and frame.SetTextInsets then
		frame:SetTextInsets(Num(Attr(textInsets, "left"), 0), Num(Attr(textInsets, "right"), 0), Num(Attr(textInsets, "top"), 0), Num(Attr(textInsets, "bottom"), 0))
	end
end

local function BuildButtonTexture(ctx, frame, element)
	local slot = ButtonTextureTags[element.tag]
	local getter = frame["Get" .. slot]
	local setter = frame["Set" .. slot]
	if not getter or not setter then
		return
	end

	local texture = getter(frame)
	if not texture then
		texture = frame:CreateTexture(nil, element.tag == "HighlightTexture" and "HIGHLIGHT" or "ARTWORK")
		setter(frame, texture)
		texture = getter(frame) or texture
	end
	Engine.PrepareRegion(texture)

	ApplyTextureContent(texture, element)
	ApplyRegionCommon(ctx, frame, texture, element)
	AssignParentKeys(frame, texture, element)
end

local function BuildSpecialChildren(ctx, frame, element)
	for _, child in ipairs(element.children or {}) do
		local tag = child.tag
		if ButtonTextureTags[tag] then
			BuildButtonTexture(ctx, frame, child)
		elseif tag == "ButtonText" then
			local fontString = frame.GetFontString and frame:GetFontString()
			if not fontString then
				fontString = frame:CreateFontString(ResolveName(Attr(child, "name"), frame), "OVERLAY", Attr(child, "inherits"))
				frame:SetFontString(fontString)
			end
			Engine.PrepareRegion(fontString)
			ApplyFontStringContent(fontString, child)
			ApplyRegionCommon(ctx, frame, fontString, child)
			AssignParentKeys(frame, fontString, child)
		elseif tag == "NormalFont" or tag == "HighlightFont" or tag == "DisabledFont" then
			local style = Attr(child, "style")
			local setter = frame["Set" .. tag .. "Object"]
			if style and setter then
				local fontObject = ns.env[style] or ns.realG[style]
				if fontObject then
					setter(frame, fontObject)
				end
			end
		elseif tag == "PushedTextOffset" and frame.SetPushedTextOffset then
			frame:SetPushedTextOffset(ReadOffset(child))
		elseif tag == "FontString" and frame:GetObjectType() == "EditBox" then
			local inherits = Attr(child, "inherits")
			local fontObject = inherits and (ns.env[inherits] or ns.realG[inherits])
			if fontObject then
				frame:SetFontObject(fontObject)
			end
			local color = FirstChild(child, "Color")
			if color then
				frame:SetTextColor(ReadColor(color))
			end
		elseif tag == "HighlightColor" and frame.SetHighlightColor then
			frame:SetHighlightColor(ReadColor(child))
		elseif tag == "BarTexture" and frame.SetStatusBarTexture then
			local file = Attr(child, "file")
			local atlas = Attr(child, "atlas")
			if file then
				frame:SetStatusBarTexture(file)
			end
			local texture = frame:GetStatusBarTexture()
			if texture then
				Engine.PrepareRegion(texture)
				if atlas then
					texture:SetAtlas(atlas)
				end
				AssignParentKeys(frame, texture, child)
			end
		elseif tag == "BarColor" and frame.SetStatusBarColor then
			frame:SetStatusBarColor(ReadColor(child))
		elseif tag == "ThumbTexture" and frame.SetThumbTexture then
			local file = Attr(child, "file")
			if file then
				frame:SetThumbTexture(file)
			end
			local texture = frame:GetThumbTexture()
			if texture then
				Engine.PrepareRegion(texture)
				ApplyTextureContent(texture, child)
				ApplyRegionCommon(ctx, frame, texture, child)
				AssignParentKeys(frame, texture, child)
			end
		end
	end
end

-- ----------------------------------------------------------------------------
-- Frames
-- ----------------------------------------------------------------------------

local BuildFrame

local function BuildChildFrames(ctx, frame, element)
	for _, framesBlock in ipairs(Children(element, "Frames")) do
		for _, child in ipairs(framesBlock.children or {}) do
			if IsFrameTag(child.tag) then
				if Bool(Attr(child, "virtual")) then
					XML.RegisterTemplate(Attr(child, "name"), child, "nested")
				else
					local childChain, childNatives = XML.ResolveChain(Attr(child, "inherits"), child)
					local childName = ResolveName(Attr(child, "name"), frame)
					local childFrame = BuildFrame(ctx, child.tag, childName, frame, childChain, childNatives, nil, child)
					AssignParentKeys(frame, childFrame, child)
				end
			end
		end
	end

	local scrollChild = FirstChild(element, "ScrollChild")
	if scrollChild and frame.SetScrollChild then
		for _, child in ipairs(scrollChild.children or {}) do
			if IsFrameTag(child.tag) then
				local childChain, childNatives = XML.ResolveChain(Attr(child, "inherits"), child)
				local childFrame = BuildFrame(ctx, child.tag, ResolveName(Attr(child, "name"), frame), frame, childChain, childNatives, nil, child)
				AssignParentKeys(frame, childFrame, child)
				frame:SetScrollChild(childFrame)
			end
		end
	end
end

function BuildFrame(ctx, frameType, name, parent, chain, natives, id, ownElement)
	Engine = Engine or ns.Engine

	local nativeTemplate = (#natives > 0) and table.concat(natives, ", ") or nil
	local frame = NativeCreateFrame(XML.NativeFrameType(frameType), name, parent, nativeTemplate)
	Engine.PrepareFrame(frame, frameType)

	if id then
		frame:SetID(id)
	end

	local intrinsic = XML.intrinsics[(frameType or ""):lower()]
	if intrinsic and intrinsic.mixin then
		local mixin = XML.ResolvePath(intrinsic.mixin)
		if type(mixin) == "table" then
			Mixin(frame, mixin)
		end
	end

	for _, element in ipairs(chain) do
		for _, mixinName in ipairs(SplitList(Attr(element, "mixin"))) do
			local mixin = XML.ResolvePath(mixinName)
			if type(mixin) == "table" then
				Mixin(frame, mixin)
			else
				ReportError("mixin", ("%s not found (template %s)"):format(mixinName, tostring(Attr(element, "name"))))
			end
		end
		for _, mixinName in ipairs(SplitList(Attr(element, "secureMixin"))) do
			local mixin = XML.ResolvePath(mixinName)
			if type(mixin) == "table" then
				Mixin(frame, mixin)
			end
		end
	end

	for _, element in ipairs(chain) do
		ApplyKeyValues(frame, element)
	end

	for _, element in ipairs(chain) do
		ApplyFrameAttributes(ctx, frame, element)
	end

	BuildLayers(ctx, frame, chain)

	for _, element in ipairs(chain) do
		BuildSpecialChildren(ctx, frame, element)
	end

	for _, element in ipairs(chain) do
		BuildChildFrames(ctx, frame, element)
	end

	for _, element in ipairs(chain) do
		QueueAnchors(ctx, frame, element)
	end

	for _, element in ipairs(chain) do
		for _, animations in ipairs(Children(element, "Animations")) do
			for _, groupElement in ipairs(Children(animations, "AnimationGroup")) do
				XML.BuildAnimationGroup(ctx, frame, groupElement)
			end
		end
	end

	-- hidden= last, so earlier chain entries cannot re-show a frame a later one hid.
	for _, element in ipairs(chain) do
		local hidden = Attr(element, "hidden")
		if hidden ~= nil then
			if Bool(hidden) then
				frame:Hide()
			else
				frame:Show()
			end
		end
	end

	ApplyScripts(ctx, frame, chain, name or (ownElement and Attr(ownElement, "parentKey")) or frameType)

	if intrinsic and intrinsic.onBuilt then
		intrinsic.onBuilt(frame)
	end

	return frame
end

-- ----------------------------------------------------------------------------
-- Animation groups (the playback engine is Animations.lua)
-- ----------------------------------------------------------------------------

function XML.BuildAnimationGroup(ctx, owner, groupElement)
	local chain = XML.ResolveChain(Attr(groupElement, "inherits"), groupElement)
	local group = ns.Anim.NewGroup(owner, ResolveName(Attr(groupElement, "name"), owner))

	for _, element in ipairs(chain) do
		for _, mixinName in ipairs(SplitList(Attr(element, "mixin"))) do
			local mixin = XML.ResolvePath(mixinName)
			if type(mixin) == "table" then
				Mixin(group, mixin)
			end
		end
	end

	for _, element in ipairs(chain) do
		local attr = element.attr or {}
		ApplyKeyValues(group, element)
		if attr.looping then
			group:SetLooping(attr.looping)
		end
		if attr.setToFinalAlpha then
			group:SetToFinalAlpha(Bool(attr.setToFinalAlpha))
		end
		for _, animationElement in ipairs(element.children or {}) do
			if AnimationTags[animationElement.tag] then
				local animation = group:CreateAnimation(animationElement.tag, ResolveName(Attr(animationElement, "name"), owner))
				ns.Anim.ConfigureFromXML(animation, animationElement)
				ApplyKeyValues(animation, animationElement)
				AssignParentKeys(group, animation, animationElement)
				for handler, func in pairs(ComposeScripts({ animationElement })) do
					if func then
						animation:SetScript(handler, func)
					end
				end
			end
		end
	end

	AssignParentKeys(owner, group, groupElement)

	for handler, func in pairs(ComposeScripts(chain)) do
		if func then
			if handler == "OnLoad" then
				ctx.loads[#ctx.loads + 1] = { object = group, func = func, label = "AnimationGroup" }
			else
				group:SetScript(handler, func)
			end
		end
	end

	return group
end

-- ----------------------------------------------------------------------------
-- Fonts
-- ----------------------------------------------------------------------------

local function BuildFont(element)
	local name = Attr(element, "name")
	if not name or ns.realG[name] then
		return
	end
	local font = CreateFont(name)
	local inherits = Attr(element, "inherits")
	local parentFont = inherits and (ns.env[inherits] or ns.realG[inherits])
	if parentFont then
		font:SetFontObject(parentFont)
	end
	local fontFile = Attr(element, "font")
	local height = Num(Attr(element, "height"))
	local heightElement = FirstChild(element, "FontHeight")
	if heightElement then
		height = Num(Attr(heightElement, "val"), height)
	end
	if fontFile or height then
		local currentFile, currentHeight, currentFlags = font:GetFont()
		font:SetFont(fontFile or currentFile or "Fonts\\FRIZQT__.TTF", height or currentHeight or 12, Attr(element, "outline") and (Attr(element, "outline") == "NORMAL" and "OUTLINE" or Attr(element, "outline") == "THICK" and "THICKOUTLINE" or "") or currentFlags)
	end
	local color = FirstChild(element, "Color")
	if color then
		font:SetTextColor(ReadColor(color))
	end
	local shadow = FirstChild(element, "Shadow")
	if shadow then
		local shadowColor = FirstChild(shadow, "Color")
		if shadowColor then
			font:SetShadowColor(ReadColor(shadowColor))
		end
		font:SetShadowOffset(ReadOffset(shadow))
	end
	if Attr(element, "justifyH") then
		font:SetJustifyH(Attr(element, "justifyH"))
	end
	ns.env[name] = font
end

-- ----------------------------------------------------------------------------
-- Public entry points
-- ----------------------------------------------------------------------------

-- Top-level frames listed here are built on the first XML.CreateDeferred(name) call instead of at
-- load time (retail loads Blizzard_PlayerSpells on demand for the same reason).
function XML.Defer(name)
	deferNames[name] = true
end

function XML.CreateFromElement(element)
	local ctx = NewContext()
	local attr = element.attr or {}
	local parent = attr.parent and (ns.realG[attr.parent] or XML.ResolvePath(attr.parent)) or nil
	local chain, natives = XML.ResolveChain(attr.inherits, element)
	local frame = BuildFrame(ctx, element.tag, attr.name, parent, chain, natives, nil, element)
	FinishContext(ctx)
	if attr.name then
		ns.env[attr.name] = frame
	end
	return frame
end

function XML.CreateDeferred(name)
	local element = deferredDefinitions[name]
	if not element then
		return ns.realG[name]
	end
	deferredDefinitions[name] = nil
	return XML.CreateFromElement(element)
end

function XML.IsDeferredPending(name)
	return deferredDefinitions[name] ~= nil
end

-- Overrides an attribute of a deferred top-level frame before it is built (its strata, for one).
function XML.SetDeferredAttribute(name, key, value)
	local element = deferredDefinitions[name]
	if not element then
		return false
	end
	element.attr = element.attr or {}
	element.attr[key] = value
	return true
end

function XML.Load(source, elements)
	for _, element in ipairs(elements) do
		local attr = element.attr or {}
		if element.tag == "Font" or element.tag == "FontFamily" then
			BuildFont(element)
		elseif Bool(attr.virtual) or (attr.name and not IsFrameTag(element.tag)) then
			if attr.name then
				XML.RegisterTemplate(attr.name, element, source)
			end
		elseif IsFrameTag(element.tag) then
			if attr.name and deferNames[attr.name] then
				deferredDefinitions[attr.name] = element
			else
				local ok, err = pcall(XML.CreateFromElement, element)
				if not ok then
					ReportError(("creating %s from %s"):format(tostring(attr.name), source), err)
				end
			end
		end
	end
end

-- CreateFrame as seen by ported retail code. Retail templates we carry are instantiated here;
-- everything else goes straight to the native CreateFrame.
function XML.CreateFrame(frameType, name, parent, templateList, id)
	Engine = Engine or ns.Engine

	if templateList and XML.HasTemplate(templateList) then
		local ctx = NewContext()
		local chain, natives = XML.ResolveChain(templateList)
		local frame = BuildFrame(ctx, frameType, name, parent, chain, natives, id)
		FinishContext(ctx)
		return frame
	end

	local frame = NativeCreateFrame(XML.NativeFrameType(frameType), name, parent, templateList)
	Engine.PrepareFrame(frame, frameType)
	if id then
		frame:SetID(id)
	end
	local intrinsic = XML.intrinsics[(frameType or ""):lower()]
	if intrinsic then
		local mixin = intrinsic.mixin and XML.ResolvePath(intrinsic.mixin)
		if type(mixin) == "table" then
			Mixin(frame, mixin)
		end
		if intrinsic.onBuilt then
			intrinsic.onBuilt(frame)
		end
	end
	return frame
end

-- Region creation on frames built by us may name a retail region template.
function XML.CreateRegionFromTemplate(owner, tag, name, layer, templateList, sublevel)
	local ctx = NewContext()
	local region = XML.BuildRegion(ctx, owner, layer or "ARTWORK", sublevel or 0, {
		tag = tag,
		attr = { name = name, inherits = templateList },
	})
	FinishContext(ctx)
	return region
end
