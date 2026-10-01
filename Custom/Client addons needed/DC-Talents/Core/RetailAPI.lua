--[[
	DC-Talents - engine-level retail API for the vendored retail code.

	Everything here goes into ns.compat, which sits between our private environment and _G, so the
	vendored retail files see retail semantics while other addons keep seeing the stock 3.3.5 API.
	Only what the ported files actually call is provided. Talents / specializations / loadouts
	(C_Traits, C_ClassTalents, C_SpecializationInfo) live in DC/Traits.lua.
]]

local _, ns = ...
setfenv(1, ns.env)

local compat = ns.compat
local G = ns.realG

local function Nop() end

-- ----------------------------------------------------------------------------
-- Engine intrinsics
-- ----------------------------------------------------------------------------

function compat.Mixin(object, ...)
	for i = 1, select("#", ...) do
		local mixin = select(i, ...)
		if mixin then
			for key, value in pairs(mixin) do
				object[key] = value
			end
		end
	end
	return object
end

function compat.CreateFromMixins(...)
	return compat.Mixin({}, ...)
end

function compat.GetCurrentEnvironment()
	return ns.env
end

-- Addon code is always insecure on 3.3.5; the secure helpers just call through.
compat.issecure = function() return false end
compat.issecurevariable = function() return false end
compat.securecallfunction = function(func, ...) return func(...) end
compat.securecall = function(func, ...)
	if type(func) == "string" then
		func = ns.env[func]
	end
	return func(...)
end
compat.secureexecuterange = function(tbl, func, ...)
	for key, value in pairs(tbl) do
		func(key, value, ...)
	end
end
compat.forceinsecure = Nop
compat.nop = Nop

local reportedAsserts = {}
function compat.assertsafe(condition, message, ...)
	if condition then
		return condition
	end
	if type(message) == "function" then
		message = message(...)
	end
	message = tostring(message or "assertion failed")
	if not reportedAsserts[message] then
		reportedAsserts[message] = true
		local handler = G.geterrorhandler and G.geterrorhandler()
		if handler then
			handler("DC-Talents: " .. message)
		end
	end
	return condition
end

compat.CreateFrame = function(frameType, name, parent, template, id)
	return ns.XML.CreateFrame(frameType, name, parent, template, id)
end
compat.CreateForbiddenFrame = compat.CreateFrame

compat.GetMouseFoci = function()
	local focus = G.GetMouseFocus()
	return { focus }
end

compat.GetScaledCursorPosition = function()
	local x, y = G.GetCursorPosition()
	local scale = G.UIParent:GetEffectiveScale()
	return x / scale, y / scale
end

if not G.IsMouseButtonDown then
	compat.IsMouseButtonDown = function()
		return false
	end
end

compat.strcmputf8i = function(a, b)
	a = a and a:lower() or ""
	b = b and b:lower() or ""
	if a == b then
		return 0
	end
	return a < b and -1 or 1
end

compat.StripHyperlinks = function(text)
	if not text then
		return text
	end
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	text = text:gsub("|H.-|h(.-)|h", "%1")
	text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
	return text
end

compat.CopyToClipboard = function(text)
	if ns.UI and ns.UI.ShowCopyDialog then
		ns.UI.ShowCopyDialog(text)
	end
end

compat.GetTimePreciseSec = function()
	return G.GetTime()
end

compat.debugprofilestop = G.debugprofilestop or function()
	return G.GetTime() * 1000
end

compat.Round = function(value)
	if value < 0 then
		return math.ceil(value - 0.5)
	end
	return math.floor(value + 0.5)
end

-- 3.3.5 PlaySound takes sound names; retail passes SOUNDKIT ids.
local SoundKitToName = {}
compat.RegisterSoundKitName = function(soundKitID, soundName)
	SoundKitToName[soundKitID] = soundName
end
compat.PlaySound = function(sound, channel, ...)
	if type(sound) == "number" then
		sound = SoundKitToName[sound]
		if not sound then
			return
		end
	end
	if sound then
		return G.PlaySound(sound)
	end
end

-- ----------------------------------------------------------------------------
-- CVars (retail C_CVar over the 3.3.5 globals; bitfields are kept in our saved variables)
-- ----------------------------------------------------------------------------

local function CVarBits(name)
	local db = ns.GetDB and ns.GetDB()
	if not db then
		return {}
	end
	db.cvarBits = db.cvarBits or {}
	db.cvarBits[name] = db.cvarBits[name] or {}
	return db.cvarBits[name]
end

compat.C_CVar = {
	GetCVar = function(name)
		local ok, value = pcall(G.GetCVar, name)
		return ok and value or nil
	end,
	SetCVar = function(name, value)
		local ok = pcall(G.SetCVar, name, value)
		return ok
	end,
	GetCVarBool = function(name)
		local ok, value = pcall(G.GetCVar, name)
		return ok and value == "1"
	end,
	GetCVarDefault = function(name)
		if G.GetCVarDefault then
			local ok, value = pcall(G.GetCVarDefault, name)
			return ok and value or nil
		end
	end,
	RegisterCVar = function(name, value)
		if G.RegisterCVar then
			pcall(G.RegisterCVar, name, value)
		end
	end,
	GetCVarBitfield = function(name, index)
		return CVarBits(name)[index] == true
	end,
	SetCVarBitfield = function(name, index, value)
		CVarBits(name)[index] = value and true or nil
		return true
	end,
	ResetTestCVars = Nop,
	GetCVarInfo = function(name)
		local ok, value = pcall(G.GetCVar, name)
		return ok and value or nil
	end,
}

-- ----------------------------------------------------------------------------
-- Colours / classes / units
-- ----------------------------------------------------------------------------

compat.C_UIColor = {
	GetColors = function()
		local colors = {}
		for _, definition in ipairs(ns.RetailColorDefinitions or {}) do
			colors[#colors + 1] = {
				baseTag = definition[1],
				color = { r = definition[3], g = definition[4], b = definition[5], a = definition[6] or 1 },
			}
		end
		return colors
	end,
}

local ClassFileByID = {
	[1] = "WARRIOR", [2] = "PALADIN", [3] = "HUNTER", [4] = "ROGUE", [5] = "PRIEST",
	[6] = "DEATHKNIGHT", [7] = "SHAMAN", [8] = "MAGE", [9] = "WARLOCK", [11] = "DRUID",
}
local ClassIDByFile = {}
for id, file in pairs(ClassFileByID) do
	ClassIDByFile[file] = id
end
ns.ClassFileByID = ClassFileByID
ns.ClassIDByFile = ClassIDByFile

compat.UnitClass = function(unit)
	local name, file = G.UnitClass(unit)
	return name, file, file and ClassIDByFile[file]
end

compat.UnitClassBase = function(unit)
	local _, file = G.UnitClass(unit)
	return file, file and ClassIDByFile[file]
end

compat.GetClassInfo = function(classID)
	local file = ClassFileByID[classID]
	if not file then
		return nil
	end
	local names = G.LOCALIZED_CLASS_NAMES_MALE
	return names and names[file] or file, file, classID
end

compat.GetNumClasses = function()
	return 11
end

compat.C_CreatureInfo = {
	GetClassInfo = function(classID)
		local className, classFile = compat.GetClassInfo(classID)
		if not classFile then
			return nil
		end
		return { className = className, classFile = classFile, classID = classID }
	end,
}

compat.GetClassColor = function(classFile)
	local color = G.RAID_CLASS_COLORS and G.RAID_CLASS_COLORS[classFile]
	if color then
		return color.r, color.g, color.b, ("ff%02x%02x%02x"):format(color.r * 255, color.g * 255, color.b * 255)
	end
	return 1, 1, 1, "ffffffff"
end

compat.C_ClassColor = {
	GetClassColor = function(classFile)
		local r, g, b = compat.GetClassColor(classFile)
		return ns.env.CreateColor(r, g, b, 1)
	end,
}

compat.C_UnitAuras = {
	WantsAlteredForm = function()
		return false
	end,
}

compat.C_PlayerInfo = {
	IsPlayerInRPE = function()
		return false
	end,
	CanPlayerUseTalentUI = function()
		return true
	end,
}

compat.C_QuestLog = {
	GetTitleForQuestID = function()
		return nil
	end,
}

compat.C_AddOns = {
	IsAddOnLoaded = function(name)
		return G.IsAddOnLoaded(name)
	end,
	LoadAddOn = function(name)
		return G.LoadAddOn(name)
	end,
	GetAddOnMetadata = function(name, field)
		return G.GetAddOnMetadata(name, field)
	end,
}

compat.C_EventUtils = {
	IsEventValid = function()
		return true
	end,
}

compat.C_Log = {
	LogMessage = Nop,
}

compat.C_XMLUtil = {
	GetTemplateInfo = function(name)
		local template = ns.XML.GetTemplate(name)
		if not template then
			return nil
		end
		local width, height
		for _, child in ipairs(template.children or {}) do
			if child.tag == "Size" and child.attr then
				width, height = tonumber(child.attr.x), tonumber(child.attr.y)
			end
		end
		return { type = template.tag, width = width or 0, height = height or 0, inherits = template.attr and template.attr.inherits }
	end,
}

compat.C_Texture = {
	GetAtlasInfo = function(atlasName)
		return ns.Atlas.GetInfo(atlasName)
	end,
	GetAtlasExists = function(atlasName)
		return ns.Atlas.Exists(atlasName)
	end,
}

compat.GetTextureInfo = function()
	return nil
end

compat.GetUITextureKitInfo = function()
	return nil
end

compat.C_CurrencyInfo = {
	GetCurrencyInfo = function()
		return nil
	end,
}

compat.C_Item = {
	GetItemQualityColor = function(quality)
		return G.GetItemQualityColor(quality or 1)
	end,
	GetItemInfo = function(...)
		return G.GetItemInfo(...)
	end,
}

-- ----------------------------------------------------------------------------
-- Spells
-- ----------------------------------------------------------------------------

local function SpellName(spellID)
	return spellID and G.GetSpellInfo(spellID) or nil
end

compat.C_Spell = {
	GetSpellName = SpellName,
	GetSpellInfo = function(spellID)
		local name, rank, icon, powerCost, isFunnel, powerType, castTime, minRange, maxRange = G.GetSpellInfo(spellID)
		if not name then
			return nil
		end
		return {
			name = name, iconID = icon, originalIconID = icon, spellID = spellID,
			castTime = castTime, minRange = minRange, maxRange = maxRange, rank = rank,
		}
	end,
	GetSpellTexture = function(spellID)
		local icon = select(3, G.GetSpellInfo(spellID))
		return icon, icon
	end,
	GetSpellSubtext = function(spellID)
		local rank = select(2, G.GetSpellInfo(spellID))
		if rank and rank ~= "" then
			return rank
		end
		return nil
	end,
	GetSpellDescription = function()
		return ""
	end,
	GetSpellLink = function(spellID)
		return spellID and G.GetSpellLink(spellID) or nil
	end,
	GetOverrideSpell = function(spellID)
		return spellID
	end,
	DoesSpellExist = function(spellID)
		return spellID ~= nil and G.GetSpellInfo(spellID) ~= nil
	end,
	IsSpellPassive = function(spellID)
		local data = ns.TalentSpellFlags and ns.TalentSpellFlags[spellID]
		if data ~= nil then
			return not data
		end
		return false
	end,
	PickupSpell = function(spellID)
		local name = SpellName(spellID)
		if name then
			G.PickupSpell(name)
		end
	end,
	GetItemModifiedAppearancesApplied = function()
		return {}
	end,
	IsSpellDataCached = function()
		return true
	end,
	RequestLoadSpellData = Nop,
}

-- Retail Spell object (ObjectAPI). 3.3.5 spell data is always local, so loads complete at once.
local SpellObjectMixin = {}

function SpellObjectMixin:IsSpellEmpty()
	return not self.spellID or G.GetSpellInfo(self.spellID) == nil
end

function SpellObjectMixin:IsSpellDataCached()
	return true
end

function SpellObjectMixin:GetSpellID()
	return self.spellID
end

function SpellObjectMixin:GetSpellName()
	return SpellName(self.spellID) or ""
end

function SpellObjectMixin:GetSpellSubtext()
	return compat.C_Spell.GetSpellSubtext(self.spellID)
end

function SpellObjectMixin:GetSpellDescription()
	return ""
end

function SpellObjectMixin:ContinueOnSpellLoad(callback)
	callback()
end

function SpellObjectMixin:ContinueWithCancelOnSpellLoad(callback)
	callback()
	return Nop
end

compat.Spell = {
	CreateFromSpellID = function(_, spellID)
		return compat.Mixin({ spellID = spellID }, SpellObjectMixin)
	end,
}

-- Action bars: is a spell on any action slot?
compat.C_ActionBar = {
	IsOnBarOrSpecialBar = function(spellID)
		if not spellID then
			return false
		end
		local name = SpellName(spellID)
		for slot = 1, 120 do
			local actionType, id = G.GetActionInfo(slot)
			if actionType == "spell" then
				if id == spellID then
					return true
				end
				local slotSpell = select(4, G.GetActionInfo(slot))
				if slotSpell == spellID then
					return true
				end
				if name and G.GetActionText and G.GetActionText(slot) == name then
					return true
				end
			end
		end
		return false
	end,
	FindSpellActionButtons = function()
		return nil
	end,
	HasAssistedCombatActionButtons = function()
		return false
	end,
}

-- ----------------------------------------------------------------------------
-- Chat / links / popups / tooltips
-- ----------------------------------------------------------------------------

compat.ChatFrameUtil = {
	InsertLink = function(link)
		if link and G.ChatEdit_InsertLink then
			return G.ChatEdit_InsertLink(link)
		end
		return false
	end,
	OpenChat = function(text, chatFrame)
		if G.ChatFrame_OpenChat then
			G.ChatFrame_OpenChat(text or "", chatFrame)
		end
	end,
}

local function AddLine(tooltip, text, color, wrap)
	color = color or G.NORMAL_FONT_COLOR
	tooltip:AddLine(text, color.r, color.g, color.b, wrap and 1 or nil)
end

compat.GameTooltip_SetTitle = function(tooltip, text, color, wrap)
	color = color or G.HIGHLIGHT_FONT_COLOR
	tooltip:SetText(text or "", color.r, color.g, color.b, 1, wrap and 1 or nil)
end

compat.GameTooltip_AddNormalLine = function(tooltip, text, wrap)
	AddLine(tooltip, text, G.NORMAL_FONT_COLOR, wrap ~= false)
end

compat.GameTooltip_AddHighlightLine = function(tooltip, text, wrap)
	AddLine(tooltip, text, G.HIGHLIGHT_FONT_COLOR, wrap ~= false)
end

compat.GameTooltip_AddInstructionLine = function(tooltip, text, wrap)
	AddLine(tooltip, text, G.GREEN_FONT_COLOR, wrap ~= false)
end

compat.GameTooltip_AddErrorLine = function(tooltip, text, wrap)
	AddLine(tooltip, text, G.RED_FONT_COLOR, wrap ~= false)
end

compat.GameTooltip_AddDisabledLine = function(tooltip, text, wrap)
	AddLine(tooltip, text, G.GRAY_FONT_COLOR, wrap ~= false)
end

compat.GameTooltip_AddColoredLine = function(tooltip, text, color, wrap)
	AddLine(tooltip, text, color, wrap ~= false)
end

compat.GameTooltip_AddBlankLineToTooltip = function(tooltip)
	tooltip:AddLine(" ")
end

compat.GameTooltip_AddBlankLinesToTooltip = function(tooltip, count)
	for _ = 1, count or 1 do
		tooltip:AddLine(" ")
	end
end

compat.SharedTooltip_SetBackdropStyle = Nop

if G.UIErrorsFrame and not G.UIErrorsFrame.AddExternalErrorMessage then
	G.UIErrorsFrame.AddExternalErrorMessage = function(self, message)
		self:AddMessage(message, 1.0, 0.1, 0.1, 1.0)
	end
end

-- Retail generic confirmation popups, built on one StaticPopupDialogs entry.
local GENERIC_POPUP = "DC_TALENTS_GENERIC_CONFIRMATION"
local currentGenericData

G.StaticPopupDialogs[GENERIC_POPUP] = {
	text = "%s",
	button1 = G.ACCEPT,
	button2 = G.CANCEL,
	OnShow = function(self)
		local data = currentGenericData
		if data then
			local button1 = self.button1 or G[self:GetName() .. "Button1"]
			local button2 = self.button2 or G[self:GetName() .. "Button2"]
			if button1 and data.acceptText then
				button1:SetText(data.acceptText)
			end
			if button2 and data.cancelText then
				button2:SetText(data.cancelText)
			end
		end
	end,
	OnAccept = function()
		local data = currentGenericData
		currentGenericData = nil
		if data and data.callback then
			ns.SafeCall(data.callback)
		end
	end,
	OnCancel = function()
		local data = currentGenericData
		currentGenericData = nil
		if data and data.cancelCallback then
			ns.SafeCall(data.cancelCallback)
		end
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	showAlert = 1,
}

compat.StaticPopup_ShowCustomGenericConfirmation = function(customData)
	currentGenericData = customData
	G.StaticPopup_Show(GENERIC_POPUP, customData.text or "")
end

compat.StaticPopup_ShowGenericConfirmation = function(text, callback, cancelCallback)
	compat.StaticPopup_ShowCustomGenericConfirmation({ text = text, callback = callback, cancelCallback = cancelCallback })
end

compat.StaticPopup_IsCustomGenericConfirmationShown = function(referenceKey)
	return currentGenericData ~= nil and G.StaticPopup_Visible(GENERIC_POPUP) ~= nil
		and (referenceKey == nil or currentGenericData.referenceKey == referenceKey)
end

compat.StaticPopup_ShowNotification = function(systemPrefix, notificationType, text)
	if G.DEFAULT_CHAT_FRAME then
		G.DEFAULT_CHAT_FRAME:AddMessage(text or "")
	end
	if G.UIErrorsFrame then
		G.UIErrorsFrame:AddMessage(compat.StripHyperlinks(text or ""), 1.0, 0.1, 0.1, 1.0)
	end
end

if not G.StaticPopupSpecial_Show then
	compat.StaticPopupSpecial_Show = function(frame)
		frame:Show()
	end
	compat.StaticPopupSpecial_Hide = function(frame)
		frame:Hide()
	end
end

compat.SetUIPanelAttribute = function(frame, name, value)
	local attributes = G.UIPanelWindows and G.UIPanelWindows[frame:GetName()]
	if attributes then
		attributes[name] = value
	end
end

compat.UpdateUIPanelPositions = G.UpdateUIPanelPositions or Nop

-- ----------------------------------------------------------------------------
-- Retail font objects the ported templates inherit (created globally, only when missing)
-- ----------------------------------------------------------------------------

local FONT = "Fonts\\FRIZQT__.TTF"
local RetailFonts = {
	-- name, size, flags, shadow, r, g, b
	{ "SystemFont16_Shadow_ThickOutline", 16, "THICKOUTLINE", true, 1, 1, 1 },
	{ "SystemFont22_Shadow_ThickOutline", 22, "THICKOUTLINE", true, 1, 1, 1 },
	{ "SystemFont_Shadow_Large2", 18, "", true, 1, 1, 1 },
	{ "SystemFont_Shadow_Med2", 14, "", true, 1, 1, 1 },
	{ "SystemFont_Huge2", 24, "", false, 1, 1, 1 },
	{ "GameFontNormalMed2", 14, "", true, 1, 0.82, 0 },
	{ "GameFontHighlightMed2", 14, "", true, 1, 1, 1 },
	{ "GameFontNormalLarge2", 18, "", true, 1, 0.82, 0 },
	{ "GameFontHighlightLarge2", 18, "", true, 1, 1, 1 },
	{ "GameFontNormalHuge2", 24, "", true, 1, 0.82, 0 },
	{ "GameFontHighlightHuge2", 24, "", true, 1, 1, 1 },
	{ "Game22Font", 22, "", false, 1, 1, 1 },
	{ "Game27Font", 27, "", false, 1, 1, 1 },
	{ "Game30Font", 30, "", false, 1, 1, 1 },
	{ "Game32Font_Shadow2", 32, "", true, 1, 1, 1 },
	{ "GameFontNormalMed3", 15, "", true, 1, 0.82, 0 },
	{ "GameFontHighlightMed3", 15, "", true, 1, 1, 1 },
	{ "SystemFont_Shadow_Med3", 15, "", true, 1, 1, 1 },
	{ "Game15Font_Shadow", 15, "", true, 1, 1, 1 },
}

for _, definition in ipairs(RetailFonts) do
	local name, size, flags, shadow, r, g, b = unpack(definition)
	if not G[name] then
		local font = G.CreateFont(name)
		font:SetFont(FONT, size, flags)
		font:SetTextColor(r, g, b)
		if shadow then
			font:SetShadowColor(0, 0, 0, 1)
			font:SetShadowOffset(1, -1)
		end
	end
end

-- Tutorial / help-plate bit constants referenced by retail code paths we keep but never enter.
compat.LE_FRAME_TUTORIAL_HERO_TALENT_NONE_SPENT = compat.LE_FRAME_TUTORIAL_HERO_TALENT_NONE_SPENT or 1001
