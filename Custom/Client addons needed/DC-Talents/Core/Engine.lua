--[[
	DC-Talents - retail widget API on 3.3.5 objects.

	Every frame and region created for the retail port passes through PrepareFrame / PrepareRegion.
	They add, per object, the retail methods the 3.3.5 client lacks (SetShown, SetAtlas,
	SetColorTexture, CreateLine, RegisterUnitEvent, ...). A method is only installed when the object
	does not already have one, so whatever the real client (or the WotLK-Extensions DLL) provides
	wins, and nothing is ever added to the shared widget metatables other addons use.
]]

local _, ns = ...
setfenv(1, ns.env)

local Engine = {}
ns.Engine = Engine

local realG = ns.realG

-- ----------------------------------------------------------------------------
-- Custom events: retail events our emulation fires (C_Traits, specs, loadouts). Frames that
-- register them are tracked here; everything else is registered natively.
-- ----------------------------------------------------------------------------

local Events = {}
ns.Events = Events

local customEvents = {}
local customRegistry = {}

function Events.DeclareCustom(...)
	for i = 1, select("#", ...) do
		customEvents[select(i, ...)] = true
	end
end

function Events.IsCustom(event)
	return customEvents[event] == true
end

function Events.Register(frame, event)
	local frames = customRegistry[event]
	if not frames then
		frames = {}
		customRegistry[event] = frames
	end
	frames[frame] = true
end

function Events.Unregister(frame, event)
	local frames = customRegistry[event]
	if frames then
		frames[frame] = nil
	end
end

function Events.IsRegistered(frame, event)
	local frames = customRegistry[event]
	return frames ~= nil and frames[frame] == true
end

function Events.Fire(event, ...)
	local frames = customRegistry[event]
	if frames then
		-- Copy first: handlers may (un)register while we iterate.
		local list = {}
		for frame in pairs(frames) do
			list[#list + 1] = frame
		end
		for _, frame in ipairs(list) do
			if frames[frame] then
				local handler = frame:GetScript("OnEvent")
				if handler then
					ns.SafeCall(handler, frame, event, ...)
				end
			end
		end
	end
	if EventRegistry and EventRegistry.TriggerEvent and ns.eventRegistryForwards and ns.eventRegistryForwards[event] then
		EventRegistry:TriggerEvent(event, ...)
	end
end

-- ----------------------------------------------------------------------------
-- Helpers
-- ----------------------------------------------------------------------------

local function Install(object, name, func)
	if object[name] == nil then
		object[name] = func
	end
end

local function Override(object, name, func)
	local native = object[name]
	object["__dcNative" .. name] = native
	object[name] = func
	return native
end

local function Nop() end

local function EffectiveScaleOf(region)
	if region.GetEffectiveScale then
		return region:GetEffectiveScale()
	end
	local parent = region:GetParent()
	return parent and parent:GetEffectiveScale() or 1
end
Engine.EffectiveScaleOf = EffectiveScaleOf

-- SetPoint(point, x, y) and SetPoint(point, relativeTo, x, y) are retail short forms.
local function NormalizedSetPoint(self, point, relativeTo, relativePoint, x, y)
	local native = self.__dcNativeSetPoint
	if type(relativeTo) == "number" then
		return native(self, point, self:GetParent(), point, relativeTo, relativePoint or 0)
	end
	if type(relativePoint) == "number" then
		return native(self, point, relativeTo, point, relativePoint, x or 0)
	end
	if relativeTo ~= nil and relativePoint == nil then
		return native(self, point, relativeTo, point, x or 0, y or 0)
	end
	if relativeTo == nil and relativePoint == nil then
		return native(self, point)
	end
	return native(self, point, relativeTo, relativePoint, x or 0, y or 0)
end

-- ----------------------------------------------------------------------------
-- Methods shared by frames and regions
-- ----------------------------------------------------------------------------

local RegionMethods = {}

function RegionMethods:SetShown(shown)
	if shown then
		self:Show()
	else
		self:Hide()
	end
end

function RegionMethods:IsRectValid()
	return self:GetLeft() ~= nil and self:GetBottom() ~= nil
end

function RegionMethods:GetScaledRect()
	local left, bottom, width, height = self:GetRect()
	if not left then
		return nil
	end
	local scale = EffectiveScaleOf(self)
	return left * scale, bottom * scale, width * scale, height * scale
end

function RegionMethods:IsMouseMotionFocus()
	return GetMouseFocus() == self
end

function RegionMethods:GetDebugName()
	return self:GetName() or tostring(self)
end

function RegionMethods:IsAnchoringRestricted()
	return false
end

function RegionMethods:IsForbidden()
	return false
end

function RegionMethods:ClearPointsOffset()
end

-- Textures and font strings have no scale on 3.3.5 (frames do, and keep the native methods);
-- keep the value so GetScale round-trips.
function RegionMethods:SetScale(scale)
	self.__dcScale = scale
end

function RegionMethods:GetScale()
	return self.__dcScale or 1
end

function RegionMethods:GetEffectiveScale()
	local parent = self:GetParent()
	return (parent and parent:GetEffectiveScale() or 1) * (self.__dcScale or 1)
end

RegionMethods.SetIgnoreParentAlpha = Nop
RegionMethods.SetIgnoreParentScale = Nop
RegionMethods.SetSnapToPixelGrid = Nop
RegionMethods.SetTexelSnappingBias = Nop
RegionMethods.SetCollapsesLayout = Nop

-- ----------------------------------------------------------------------------
-- Texture / FontString specifics
-- ----------------------------------------------------------------------------

local TextureMethods = {}

function TextureMethods:SetAtlas(atlasName, useAtlasSize, filterMode, resetTexCoords)
	return ns.Atlas.Apply(self, atlasName, useAtlasSize)
end

function TextureMethods:GetAtlas()
	return self.__dcAtlas
end

function TextureMethods:SetColorTexture(r, g, b, a)
	self.__dcAtlas = nil
	self.__dcAtlasRect = nil
	self:SetTexture(r, g, b, a or 1)
end

-- Retail: texture coordinates on an atlas texture are relative to the atlas region, so XML
-- <TexCoords left="1" right="0"/> mirrors the atlas (the spec cards' right-hand glows), not the whole
-- sheet. 3.3.5 has no atlases: Atlas.Apply records the region and coordinates are mapped into it.
local function MapToAtlas(rect, ...)
	local l, t = rect[1], rect[3]
	local w, h = rect[2] - rect[1], rect[4] - rect[3]
	if select("#", ...) >= 8 then
		local ULx, ULy, LLx, LLy, URx, URy, LRx, LRy = ...
		return l + ULx * w, t + ULy * h, l + LLx * w, t + LLy * h, l + URx * w, t + URy * h, l + LRx * w, t + LRy * h
	end
	local left, right, top, bottom = ...
	return l + left * w, l + right * w, t + top * h, t + bottom * h
end

local function AtlasAwareSetTexCoord(self, ...)
	if self.__dcAtlasRect then
		return self.__dcRawSetTexCoord(self, MapToAtlas(self.__dcAtlasRect, ...))
	end
	return self.__dcRawSetTexCoord(self, ...)
end

-- A new file or colour ends the atlas.
local function AtlasAwareSetTexture(self, ...)
	self.__dcAtlas = nil
	self.__dcAtlasRect = nil
	return self.__dcRawSetTexture(self, ...)
end

-- Natives the atlas wrappers call (and Atlas.Apply uses directly). Own field names: Line.lua keeps its
-- own copy of SetTexture in __dcNativeSetTexture.
local function WrapAtlasTexture(region)
	region.__dcRawSetTexture = region.SetTexture
	region.__dcRawSetTexCoord = region.SetTexCoord
	region.SetTexture = AtlasAwareSetTexture
	region.SetTexCoord = AtlasAwareSetTexCoord
end
Engine.WrapAtlasTexture = WrapAtlasTexture

function TextureMethods:SetDesaturation(desaturation)
	self.__dcDesaturation = desaturation or 0
	self:SetDesaturated((desaturation or 0) > 0)
end

function TextureMethods:GetDesaturation()
	if self.__dcDesaturation then
		return self.__dcDesaturation
	end
	return self:IsDesaturated() and 1 or 0
end

-- Other addons patch the SHARED texture metatable with their own versions of these (DC-Journal's
-- Sirus SharedXML: a SetAtlas that asserts on names missing from its atlas table; DCCompat: a
-- SetColorTexture that leaves a vertex colour behind). The port's atlases only exist in our table,
-- so these are set on every texture we prepare instead of only filling gaps.
local AuthoritativeTextureMethods = { SetAtlas = true, GetAtlas = true, SetColorTexture = true }

TextureMethods.SetMask = Nop
TextureMethods.AddMaskTexture = Nop
TextureMethods.RemoveMaskTexture = Nop
TextureMethods.SetTextureSliceMargins = Nop
TextureMethods.SetTextureSliceMode = Nop
TextureMethods.SetHorizTile = Nop
TextureMethods.SetVertTile = Nop
TextureMethods.SetBlockingLoadsRequested = Nop

-- Retail SetGradient takes two ColorMixins; 3.3.5 takes six numbers.
local function GradientWithColors(self, orientation, minColor, maxColor, ...)
	if type(minColor) == "table" and type(maxColor) == "table" then
		return self:SetGradientAlpha(orientation, minColor.r or 1, minColor.g or 1, minColor.b or 1, minColor.a or 1,
			maxColor.r or 1, maxColor.g or 1, maxColor.b or 1, maxColor.a or 1)
	end
	return self.__dcNativeSetGradient(self, orientation, minColor, maxColor, ...)
end

local FontStringMethods = {}
FontStringMethods.SetMaxLines = Nop
FontStringMethods.SetTextScale = Nop
FontStringMethods.SetWordWrap = Nop
FontStringMethods.SetNonSpaceWrap = Nop

-- Retail: set the text and size the string to it.
function FontStringMethods:SetTextToFit(text)
	self:SetText(text)
	self:SetWidth(self:GetStringWidth())
	self:SetHeight(self:GetStringHeight())
end

function FontStringMethods:GetUnboundedStringWidth()
	return self:GetStringWidth()
end

function FontStringMethods:IsTruncated()
	return self:GetStringWidth() > (self:GetWidth() + 0.5)
end

function FontStringMethods:SetFormattedText(format, ...)
	self:SetText(format:format(...))
end

-- ----------------------------------------------------------------------------
-- Region scripts: retail textures can carry OnShow / OnHide / OnEnter handlers; 3.3.5 textures
-- cannot, so Show / Hide / SetShown fire them manually.
-- ----------------------------------------------------------------------------

local function RegionFireScript(self, handler, ...)
	local scripts = self.__dcScripts
	local func = scripts and scripts[handler]
	if func then
		ns.SafeCall(func, self, ...)
	end
end

local function RegionShow(self)
	local wasShown = self:IsShown()
	self.__dcNativeShow(self)
	if not wasShown then
		RegionFireScript(self, "OnShow")
	end
end

local function RegionHide(self)
	local wasShown = self:IsShown()
	self.__dcNativeHide(self)
	if wasShown then
		RegionFireScript(self, "OnHide")
	end
end

function Engine.SetRegionScript(region, handler, func)
	if region.HasScript and region:HasScript(handler) then
		region:SetScript(handler, func)
		return
	end

	region.__dcScripts = region.__dcScripts or {}
	region.__dcScripts[handler] = func

	if (handler == "OnShow" or handler == "OnHide") and not region.__dcShowHooked then
		region.__dcShowHooked = true
		Override(region, "Show", RegionShow)
		Override(region, "Hide", RegionHide)
		region.SetShown = function(self, shown)
			if shown then
				self:Show()
			else
				self:Hide()
			end
		end
	end
end

local function RegionSetScript(self, handler, func)
	Engine.SetRegionScript(self, handler, func)
end

local function RegionGetScript(self, handler)
	return self.__dcScripts and self.__dcScripts[handler]
end

local function RegionHookScript(self, handler, func)
	local previous = RegionGetScript(self, handler)
	if previous then
		Engine.SetRegionScript(self, handler, function(...)
			previous(...)
			func(...)
		end)
	else
		Engine.SetRegionScript(self, handler, func)
	end
end

-- ----------------------------------------------------------------------------
-- Mask textures do nothing on 3.3.5: a hidden texture that refuses to show.
-- ----------------------------------------------------------------------------

local function CreateMaskTexture(self, name, layer)
	local mask = self:CreateTexture(name, layer or "ARTWORK")
	mask:Hide()
	mask.Show = Nop
	mask.SetShown = Nop
	mask.__dcIsMask = true
	return mask
end

-- ----------------------------------------------------------------------------
-- Frame specifics
-- ----------------------------------------------------------------------------

local FrameMethods = {}

FrameMethods.SetFixedFrameLevel = Nop
FrameMethods.SetForbidden = Nop
FrameMethods.SetFixedFrameStrata = Nop
FrameMethods.SetClipsChildren = Nop
FrameMethods.SetFlattensRenderLayers = Nop
FrameMethods.SetUsingParentLevel = Nop
FrameMethods.SetPropagateKeyboardInput = Nop
FrameMethods.SetPropagateMouseClicks = Nop
FrameMethods.SetPropagateMouseMotion = Nop
FrameMethods.SetPassThroughButtons = Nop
FrameMethods.SetHyperlinksEnabled = Nop
FrameMethods.SetMotionScriptsWhileDisabled = Nop
FrameMethods.SetDontSavePosition = Nop
FrameMethods.SetIsFrameBuffer = Nop

-- Retail Button:SetTextToFit: set the text and widen the button to it (UIPanelButton padding).
function FrameMethods:SetTextToFit(text)
	self:SetText(text)
	local fontString = self.GetFontString and self:GetFontString()
	if fontString then
		self:SetWidth(fontString:GetStringWidth() + 40)
	end
end

function FrameMethods:DoesClipChildren()
	return false
end

function FrameMethods:SetMouseClickEnabled(enabled)
	self:EnableMouse(enabled)
end

function FrameMethods:SetMouseMotionEnabled(enabled)
	if enabled then
		self:EnableMouse(true)
	end
end

function FrameMethods:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
	if self.SetMinResize and minWidth then
		self:SetMinResize(minWidth, minHeight or 0)
	end
	if self.SetMaxResize and maxWidth then
		self:SetMaxResize(maxWidth, maxHeight or 0)
	end
end

function FrameMethods:SetDrawLayerEnabled(layer, enabled)
	if enabled then
		self:EnableDrawLayer(layer)
	else
		self:DisableDrawLayer(layer)
	end
end

function FrameMethods:DesaturateHierarchy(desaturation)
	for _, region in ipairs({ self:GetRegions() }) do
		if region.SetDesaturated then
			region:SetDesaturated(desaturation and desaturation > 0)
		end
	end
	for _, child in ipairs({ self:GetChildren() }) do
		if child.DesaturateHierarchy then
			child:DesaturateHierarchy(desaturation)
		end
	end
end

function FrameMethods:GetRaisedFrameLevel()
	return self:GetFrameLevel()
end

function FrameMethods:SetEnabled(enabled)
	if self.Enable and self.Disable then
		if enabled then
			self:Enable()
		else
			self:Disable()
		end
	end
end

-- Events: our custom (retail-only) events go through ns.Events; unit events filter by unit.
local function FrameRegisterEvent(self, event)
	if customEvents[event] then
		Events.Register(self, event)
		return true
	end
	local ok = pcall(self.__dcNativeRegisterEvent, self, event)
	if not ok then
		-- The client does not know this retail event; nobody will fire it, keep it trackable.
		Events.Register(self, event)
	end
	return ok
end

local function FrameUnregisterEvent(self, event)
	Events.Unregister(self, event)
	if self.__dcUnitFilter then
		self.__dcUnitFilter[event] = nil
	end
	if not customEvents[event] then
		pcall(self.__dcNativeUnregisterEvent, self, event)
	end
end

local function FrameIsEventRegistered(self, event)
	if Events.IsRegistered(self, event) then
		return true
	end
	return self.__dcNativeIsEventRegistered(self, event)
end

local function FrameRegisterUnitEvent(self, event, ...)
	self:RegisterEvent(event)
	local filter = {}
	local any = false
	for i = 1, select("#", ...) do
		local unit = select(i, ...)
		if unit then
			filter[unit] = true
			any = true
		end
	end
	self.__dcUnitFilter = self.__dcUnitFilter or {}
	self.__dcUnitFilter[event] = any and filter or nil
	return true
end

local function WrapEventHandler(func)
	return function(self, event, ...)
		local filters = self.__dcUnitFilter
		local filter = filters and filters[event]
		if filter and not filter[(...)] then
			return
		end
		return func(self, event, ...)
	end
end

-- object.SetScript is FrameSetScript on prepared frames, which applies the unit-event filter.
function Engine.SetScriptSafe(object, handler, func)
	local ok = pcall(object.SetScript, object, handler, func)
	if not ok then
		-- Handler the 3.3.5 widget does not support (OnEnable on buttons, ...): keep it callable.
		object.__dcScripts = object.__dcScripts or {}
		object.__dcScripts[handler] = func
	end
end

local function FrameSetScript(self, handler, func)
	if handler == "OnEvent" and func then
		func = WrapEventHandler(func)
	end
	local ok, err = pcall(self.__dcNativeSetScript, self, handler, func)
	if not ok then
		self.__dcScripts = self.__dcScripts or {}
		self.__dcScripts[handler] = func
	end
end

local function FrameGetScript(self, handler)
	local ok, func = pcall(self.__dcNativeGetScript, self, handler)
	if ok and func then
		return func
	end
	return self.__dcScripts and self.__dcScripts[handler]
end

-- Animation groups use the Lua engine (retail fromAlpha/toAlpha, childKey targets, ...).
local function FrameCreateAnimationGroup(self, name, template)
	return ns.Anim.NewGroupFromTemplate(self, name, template)
end

local function FrameGetAnimationGroups(self)
	return ns.Anim.GetGroupsOf(self)
end

local function FrameStopAnimating(self)
	ns.Anim.StopAllOf(self)
	if self.__dcNativeStopAnimating then
		self.__dcNativeStopAnimating(self)
	end
end

-- Creation methods: regions made through a prepared frame are prepared too.
local function FrameCreateTexture(self, name, layer, template, sublevel)
	if template and ns.XML.HasTemplate(template) then
		return ns.XML.CreateRegionFromTemplate(self, "Texture", name, layer, template, sublevel)
	end
	local texture = self.__dcNativeCreateTexture(self, name, layer or "ARTWORK", template)
	Engine.PrepareRegion(texture)
	return texture
end

local function FrameCreateFontString(self, name, layer, template)
	if template and ns.XML.HasTemplate(template) then
		return ns.XML.CreateRegionFromTemplate(self, "FontString", name, layer, template)
	end
	local ok, fontString = pcall(self.__dcNativeCreateFontString, self, name, layer or "ARTWORK", template)
	if not ok then
		-- Unknown font template (a retail font we did not recreate): fall back to a stock one.
		fontString = self.__dcNativeCreateFontString(self, name, layer or "ARTWORK", "GameFontNormal")
	end
	Engine.PrepareRegion(fontString)
	return fontString
end

local function FrameCreateLine(self, name, layer, template, sublevel)
	return ns.Line.Create(self, name, layer, sublevel)
end

local function FrameCreateMaskTexture(self, name, layer, template, sublevel)
	return CreateMaskTexture(self, name, layer)
end

-- Button texture accessors return prepared regions.
local ButtonTextureSlots = { "NormalTexture", "PushedTexture", "DisabledTexture", "HighlightTexture", "CheckedTexture", "DisabledCheckedTexture" }

local function PrepareButtonAccessors(frame)
	for _, slot in ipairs(ButtonTextureSlots) do
		local getterName = "Get" .. slot
		local native = frame[getterName]
		if native then
			frame[getterName] = function(self)
				local texture = native(self)
				if texture then
					Engine.PrepareRegion(texture)
				end
				return texture
			end

			-- Always ours: the Sirus SharedXML puts Set<State>Atlas on the shared Button metatable.
			local setterName = "Set" .. slot
			local atlasSetterName = "Set" .. slot:gsub("Texture$", "") .. "Atlas"
			local nativeSetter = frame[setterName]
			if nativeSetter then
				-- The native setter changes the texture behind our back: the atlas (and its coordinate
				-- mapping) ends there, as with Texture:SetTexture.
				frame[setterName] = function(self, ...)
					local result = nativeSetter(self, ...)
					local texture = native(self)
					if texture then
						texture.__dcAtlas = nil
						texture.__dcAtlasRect = nil
					end
					return result
				end
			end
			if frame[setterName] then
				frame[atlasSetterName] = function(self, atlasName, useAtlasSize)
					local texture = self[getterName](self)
					if not texture then
						self[setterName](self, "Interface\\Buttons\\WHITE8X8")
						texture = self[getterName](self)
					end
					if texture then
						texture:SetAtlas(atlasName, useAtlasSize)
					end
				end
			end
			local clearName = "Clear" .. slot
			if frame[setterName] then
				frame[clearName] = function(self)
					local texture = self[getterName](self)
					if texture then
						texture:SetTexture(nil)
					end
				end
			end
		end
	end

	local nativeGetFontString = frame.GetFontString
	if nativeGetFontString then
		frame.GetFontString = function(self)
			local fontString = nativeGetFontString(self)
			if fontString then
				Engine.PrepareRegion(fontString)
			end
			return fontString
		end
	end
end

-- ----------------------------------------------------------------------------
-- Frame levels: retail layers its windows between 1 and ~5500 (it allows up to 10000). If this
-- client keeps fewer levels, absolute levels are scaled into the range it has, in the same order.
-- ----------------------------------------------------------------------------

local RETAIL_LEVEL_SPAN = 5600
local levelScale

local function ProbeMaxFrameLevel()
	local probe = realG.CreateFrame("Frame")
	local best = 0
	for _, level in ipairs({ 10000, RETAIL_LEVEL_SPAN + 10, 2000, 1000, 255, 128 }) do
		if pcall(probe.SetFrameLevel, probe, level) then
			local got = probe:GetFrameLevel() or 0
			if got > best then
				best = got
			end
			if got >= level then
				break
			end
		end
	end
	probe:Hide()
	return best
end

function Engine.FrameLevelScale()
	if not levelScale then
		local maxLevel = ProbeMaxFrameLevel()
		Engine.MAX_FRAME_LEVEL = maxLevel
		if maxLevel >= RETAIL_LEVEL_SPAN + 10 then
			levelScale = 1
		else
			levelScale = math.max(maxLevel - 10, 1) / RETAIL_LEVEL_SPAN
		end
	end
	return levelScale
end

-- An absolute retail frame level for this client.
function Engine.MapFrameLevel(level)
	if not level then
		return level
	end
	local scale = Engine.FrameLevelScale()
	if scale == 1 then
		return level
	end
	return math.max(level > 0 and 1 or 0, math.floor(level * scale + 0.5))
end

-- ----------------------------------------------------------------------------
-- Entry points
-- ----------------------------------------------------------------------------

function Engine.PrepareRegion(region)
	if not region or region.__dcPrepared then
		return region
	end
	region.__dcPrepared = true

	for name, func in pairs(RegionMethods) do
		Install(region, name, func)
	end

	local objectType = region.GetObjectType and region:GetObjectType()
	if objectType == "Texture" then
		for name, func in pairs(TextureMethods) do
			if AuthoritativeTextureMethods[name] then
				region[name] = func
			else
				Install(region, name, func)
			end
		end
		WrapAtlasTexture(region)
		if region.SetGradient then
			Override(region, "SetGradient", GradientWithColors)
		end
	elseif objectType == "FontString" then
		for name, func in pairs(FontStringMethods) do
			Install(region, name, func)
		end
	end

	if region.SetScript == nil then
		region.SetScript = RegionSetScript
		region.GetScript = RegionGetScript
		region.HookScript = RegionHookScript
		region.HasScript = function()
			return false
		end
	end

	Override(region, "SetPoint", NormalizedSetPoint)
	return region
end

function Engine.PrepareFrame(frame, requestedType)
	if not frame or frame.__dcPrepared then
		return frame
	end
	frame.__dcPrepared = true
	frame.__dcRequestedType = requestedType

	for name, func in pairs(RegionMethods) do
		Install(frame, name, func)
	end
	for name, func in pairs(FrameMethods) do
		Install(frame, name, func)
	end

	Override(frame, "RegisterEvent", FrameRegisterEvent)
	Override(frame, "UnregisterEvent", FrameUnregisterEvent)
	Override(frame, "IsEventRegistered", FrameIsEventRegistered)
	frame.RegisterUnitEvent = FrameRegisterUnitEvent
	Override(frame, "SetScript", FrameSetScript)
	Override(frame, "GetScript", FrameGetScript)
	Override(frame, "SetPoint", NormalizedSetPoint)

	Override(frame, "CreateTexture", FrameCreateTexture)
	Override(frame, "CreateFontString", FrameCreateFontString)
	frame.CreateLine = FrameCreateLine
	frame.CreateMaskTexture = FrameCreateMaskTexture
	Override(frame, "CreateAnimationGroup", FrameCreateAnimationGroup)
	Override(frame, "GetAnimationGroups", FrameGetAnimationGroups)
	Override(frame, "StopAnimating", FrameStopAnimating)

	if frame.GetNormalTexture then
		PrepareButtonAccessors(frame)
	end

	-- Regions created by native templates inside CreateFrame are prepared too.
	for _, region in ipairs({ frame:GetRegions() }) do
		Engine.PrepareRegion(region)
	end

	return frame
end

-- Wraps a frame someone else created (stock UI) when retail code needs retail methods on it.
function Engine.Adopt(frame)
	return Engine.PrepareFrame(frame, frame and frame.GetObjectType and frame:GetObjectType())
end

-- Custom events the port fires itself. Declared here so the list is in one place.
Events.DeclareCustom(
	"TRAIT_CONFIG_UPDATED",
	"TRAIT_CONFIG_CREATED",
	"TRAIT_CONFIG_DELETED",
	"TRAIT_CONFIG_LIST_UPDATED",
	"TRAIT_NODE_CHANGED",
	"TRAIT_NODE_CHANGED_PARTIAL",
	"TRAIT_NODE_ENTRY_UPDATED",
	"TRAIT_TREE_CHANGED",
	"TRAIT_TREE_CURRENCY_INFO_UPDATED",
	"TRAIT_SUB_TREE_CHANGED",
	"TRAIT_COND_INFO_CHANGED",
	"CONFIG_COMMIT_FAILED",
	"ACTIVE_COMBAT_CONFIG_CHANGED",
	"SELECTED_LOADOUT_CHANGED",
	"STARTER_BUILD_ACTIVATION_FAILED",
	"ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
	"PLAYER_SPECIALIZATION_CHANGED",
	"SPECIALIZATION_CHANGE_CAST_FAILED",
	"PLAYER_SPEC_ACTIVATION_FINISHED",
	"TRAIT_SYSTEM_NPC_CLOSED",
	"TRAIT_SYSTEM_INTERACTION_STARTED"
)
