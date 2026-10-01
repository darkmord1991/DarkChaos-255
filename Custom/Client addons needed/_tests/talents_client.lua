--[[
	talents_client.lua - the game half of the DC-Talents test client (talents_sim.lua is the widget half).

	  * the stock 3.3.5a globals: GlobalStrings.lua and Constants.lua are loaded from the real FrameXML
	    archive, the few FrameXML functions the port touches are reimplemented with 3.3.5 semantics
	    (UI panels, UIDropDownMenu, StaticPopup, chat filters, micro buttons, talent/glyph UI loaders);
	  * a player: class, level, dual spec, combat/death state, spells, glyphs, CVars, addons;
	  * the talent API on the real Talent.dbc data with the server's learning rules (AzerothCore
	    Player::LearnTalent: points in the tab >= 5 x row, the prerequisite at its required rank, one
	    rank at a time, active talent group only), preview points and LearnPreviewTalents;
	  * the DC server module TLNT (HELLO / APPLY_BUILD / APPLY_PET_BUILD) as a scriptable fake.
]]

local SIM = _G.SIM
local S = SIM.S

SIM.FRAMEXML = SIM_FRAMEXML or "K:/Dark-Chaos/Custom/Client addons needed/Archive/3.3.5-interface-files-main/"

local CLIENT = {}
SIM.client = CLIENT

-- ============================================================================
-- Stock globals
-- ============================================================================

LOCALIZED_CLASS_NAMES_MALE = {}
LOCALIZED_CLASS_NAMES_FEMALE = {}

local CLASS_NAMES = {
	WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
	DEATHKNIGHT = "Death Knight", SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
}
local CLASS_IDS = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 }
CLIENT.CLASS_IDS = CLASS_IDS

function FillLocalizedClassList(list, female)
	for file, name in pairs(CLASS_NAMES) do
		list[file] = name
	end
	return list
end

-- C API the stock Constants.lua calls at load.
function RegisterStaticConstants(constants)
end

local function LoadStock(file)
	local chunk, err = loadfile(SIM.FRAMEXML .. file)
	if not chunk then
		error("cannot load stock " .. file .. ": " .. tostring(err))
	end
	chunk()
end

LoadStock("GlobalStrings.lua")
LoadStock("Constants.lua")

-- ============================================================================
-- Screen and stock frames
-- ============================================================================

WorldFrame = CreateFrame("Frame", "WorldFrame")
S[WorldFrame].isScreen = true
UIParent = CreateFrame("Frame", "UIParent")
S[UIParent].isScreen = true

function GetScreenWidth()
	return SIM.SCREEN_W
end

function GetScreenHeight()
	return SIM.SCREEN_H
end

function GetCursorPosition()
	return 0, 0
end

function GetMouseFocus()
	return SIM.mouseFocus
end

GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent, "GameTooltipTemplate")
GameTooltip:Hide()
ItemRefTooltip = CreateFrame("GameTooltip", "ItemRefTooltip", UIParent, "GameTooltipTemplate")
ItemRefTooltip:Hide()

-- Chat: messages pass the registered filters first (ChatFrame_AddMessageEventFilter).
local chatFilters = {}
SIM.systemMessages = {}

local function NewMessageFrame(typeName, name)
	local frame = CreateFrame(typeName, name, UIParent)
	return frame
end

DEFAULT_CHAT_FRAME = NewMessageFrame("ScrollingMessageFrame", "ChatFrame1")
ChatFrame1 = DEFAULT_CHAT_FRAME
UIErrorsFrame = NewMessageFrame("MessageFrame", "UIErrorsFrame")

local messageFrameImpl = {
	AddMessage = function(self, text, r, g, b)
		if self == UIErrorsFrame then
			SIM.uiErrors[#SIM.uiErrors + 1] = tostring(text)
		else
			SIM.chat[#SIM.chat + 1] = tostring(text)
		end
	end,
}
for _, frame in ipairs({ DEFAULT_CHAT_FRAME, UIErrorsFrame }) do
	local meta = getmetatable(frame).__index
	meta.AddMessage = messageFrameImpl.AddMessage
end

function ChatFrame_AddMessageEventFilter(event, filter)
	chatFilters[event] = chatFilters[event] or {}
	table.insert(chatFilters[event], filter)
end

function ChatFrame_RemoveMessageEventFilter(event, filter)
	if chatFilters[event] then
		tDeleteItem(chatFilters[event], filter)
	end
end

function ChatFrame_GetMessageEventFilters(event)
	return chatFilters[event]
end

-- A server system message as the chat frame would handle it (filters can swallow it).
function SIM.SystemMessage(text)
	for _, filter in ipairs(chatFilters.CHAT_MSG_SYSTEM or {}) do
		local ok, hide = pcall(filter, DEFAULT_CHAT_FRAME, "CHAT_MSG_SYSTEM", text, "", "", "", "", "", 0, 0, "", 0, 0)
		if not ok then
			geterrorhandler()(hide)
		elseif hide then
			SIM.filteredSystemMessages = (SIM.filteredSystemMessages or 0) + 1
			return false
		end
	end
	SIM.systemMessages[#SIM.systemMessages + 1] = text
	return true
end

function ChatEdit_InsertLink(text)
	SIM.insertedLinks = SIM.insertedLinks or {}
	if SIM.chatEditOpen then
		table.insert(SIM.insertedLinks, text)
		return true
	end
	return false
end

function ChatFrame_OpenChat(text)
	SIM.chatEditOpen = true
	SIM.openedChat = text
end

function ChatEdit_FocusActiveWindow()
end

function SetItemRef(link, text, button)
	SIM.itemRefs = SIM.itemRefs or {}
	table.insert(SIM.itemRefs, link)
end

-- ============================================================================
-- UI panels, special frames, micro buttons
-- ============================================================================

SlashCmdList = {}
hash_SlashCmdList = {}

UISpecialFrames = {}
UIPanelWindows = {}
UIMenus = {}

function GetUIPanelWindowInfo(frame, name)
	if not frame:GetAttribute("UIPanelLayout-defined") then
		local info = UIPanelWindows[frame:GetName()]
		if not info then
			return nil
		end
		frame:SetAttribute("UIPanelLayout-defined", true)
		for key, value in pairs(info) do
			frame:SetAttribute("UIPanelLayout-" .. key, value)
		end
	end
	return frame:GetAttribute("UIPanelLayout-" .. name)
end

function ShowUIPanel(frame, force)
	if not frame or frame:IsShown() then
		return
	end
	frame:Show()
end

function HideUIPanel(frame, skipSetPoint)
	if not frame or not frame:IsShown() then
		return
	end
	frame:Hide()
end

-- UIParent.lua
function HideParentPanel(self)
	HideUIPanel(self:GetParent())
end

function CloseSpecialWindows()
	local found
	for _, name in ipairs(UISpecialFrames) do
		local frame = _G[name]
		if frame and frame:IsShown() then
			frame:Hide()
			found = 1
		end
	end
	return found
end

function SetDesaturation(texture, desaturation)
	local shaderSupported = texture:SetDesaturated(desaturation)
	if not shaderSupported then
		if desaturation then
			texture:SetVertexColor(0.5, 0.5, 0.5)
		else
			texture:SetVertexColor(1.0, 1.0, 1.0)
		end
	end
end

function GameTooltip_SetDefaultAnchor(tooltip, parent)
	tooltip:SetOwner(parent, "ANCHOR_NONE")
	tooltip:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -13, 64)
end

function GameTooltip_Hide()
	GameTooltip:Hide()
end

TalentMicroButton = CreateFrame("Button", "TalentMicroButton", UIParent)
TalentMicroButton:SetScript("OnClick", function()
	ToggleTalentFrame()
end)

function UpdateMicroButtons()
	if PlayerTalentFrame and PlayerTalentFrame:IsShown() then
		TalentMicroButton:SetButtonState("PUSHED", 1)
	else
		TalentMicroButton:SetButtonState("NORMAL")
	end
end

-- UIParent.lua (3.3.5)
function ToggleTalentFrame()
	if UnitLevel("player") < SHOW_TALENT_LEVEL then
		return
	end
	TalentFrame_LoadUI()
	if PlayerTalentFrame_Toggle then
		PlayerTalentFrame_Toggle(false, GetActiveTalentGroup())
	end
end

function TalentFrame_LoadUI()
	UIParentLoadAddOn("Blizzard_TalentUI")
end

function GlyphFrame_LoadUI()
	UIParentLoadAddOn("Blizzard_GlyphUI")
end

-- ============================================================================
-- Addons
-- ============================================================================

CLIENT.addons = {}
CLIENT.loadedAddons = {}

function CLIENT.RegisterAddOn(name, loader)
	CLIENT.addons[name] = loader or function() end
end

function IsAddOnLoaded(name)
	return CLIENT.loadedAddons[name] and 1 or nil
end

function LoadAddOn(name)
	if CLIENT.loadedAddons[name] then
		return 1
	end
	local loader = CLIENT.addons[name]
	if not loader then
		return nil, "MISSING"
	end
	CLIENT.loadedAddons[name] = true
	loader()
	SIM.FireEvent("ADDON_LOADED", name)
	return 1
end

function UIParentLoadAddOn(name)
	local loaded, reason = LoadAddOn(name)
	if not loaded then
		message(("Failed to load %s: %s"):format(name, tostring(reason)))
	end
	return loaded
end

function message(text)
	SIM.messages = SIM.messages or {}
	table.insert(SIM.messages, text)
end

function GetAddOnInfo(name)
	return name, name, "", 1, CLIENT.loadedAddons[name] and 1 or nil
end

function GetAddOnMetadata(name, field)
	if field == "Version" then
		return "1.0.0"
	end
	return nil
end

function GetNumAddOns()
	return 0
end

-- Blizzard_TalentUI: just enough PlayerTalentFrame for the stock fallback paths.
CLIENT.RegisterAddOn("Blizzard_TalentUI", function()
	local frame = CreateFrame("Frame", "PlayerTalentFrame", UIParent)
	frame:SetSize(384, 512)
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
	frame:Hide()
	frame.talentGroup = GetActiveTalentGroup()
	frame.pet = false
	CreateFrame("Button", "PlayerTalentFrameCloseButton", frame, "UIPanelCloseButton")
	function PlayerTalentFrame_Toggle(pet, suggestedTalentGroup)
		if frame:IsShown() then
			HideUIPanel(frame)
		else
			ShowUIPanel(frame)
		end
		UpdateMicroButtons()
	end
	if GlyphFrame then
		GlyphFrame:ClearAllPoints()
		GlyphFrame:SetParent(frame)
		GlyphFrame:SetAllPoints()
	end
end)

-- Blizzard_GlyphUI: the frame DC-Talents borrows for its Glyphs tab.
CLIENT.RegisterAddOn("Blizzard_GlyphUI", function()
	local frame = CreateFrame("Frame", "GlyphFrame")
	frame:SetSize(384, 512)
	frame:SetPoint("TOPLEFT")
	frame:Hide()
	frame.background = frame:CreateTexture("GlyphFrameBackground", "ARTWORK")
	frame.background:SetTexture("Interface\\Spellbook\\UI-GlyphFrame")
	local title = frame:CreateFontString("GlyphFrameTitleText", "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", 0, -17)
	for i = 1, 6 do
		CreateFrame("Button", "GlyphFrameGlyph" .. i, frame)
	end
	SIM.glyphUpdates = 0
	function GlyphFrame_Update()
		SIM.glyphUpdates = SIM.glyphUpdates + 1
	end
	frame:SetScript("OnShow", function()
		GlyphFrame_Update()
	end)
	if PlayerTalentFrame then
		frame:SetParent(PlayerTalentFrame)
		frame:SetAllPoints()
	end
end)

-- ============================================================================
-- UIDropDownMenu (3.3.5 semantics, no widgets for the entries)
-- ============================================================================

UIDROPDOWNMENU_MAXLEVELS = 2
UIDROPDOWNMENU_MENU_LEVEL = 1
UIDROPDOWNMENU_MENU_VALUE = nil
UIDROPDOWNMENU_OPEN_MENU = nil
UIDROPDOWNMENU_INIT_MENU = nil

for level = 1, 3 do
	local list = CreateFrame("Button", "DropDownList" .. level, UIParent)
	list:Hide()
	list.entries = {}
end

function UIDropDownMenu_CreateInfo()
	return {}
end

function UIDropDownMenu_Initialize(frame, initFunction, displayMode, level, menuList)
	frame.initialize = initFunction
	frame.displayMode = displayMode
	frame.menuList = menuList
	UIDROPDOWNMENU_INIT_MENU = frame
end

function UIDropDownMenu_AddButton(info, level)
	level = level or 1
	local list = _G["DropDownList" .. level]
	local entry = {}
	for key, value in pairs(info) do
		entry[key] = value
	end
	table.insert(list.entries, entry)
end

function CloseDropDownMenus(level)
	for i = level or 1, 3 do
		_G["DropDownList" .. i]:Hide()
	end
end

function ToggleDropDownMenu(level, value, dropDownFrame, anchorName, xOffset, yOffset, menuList)
	level = level or 1
	local list = _G["DropDownList" .. level]
	if level == 1 and list:IsShown() and UIDROPDOWNMENU_OPEN_MENU == dropDownFrame then
		CloseDropDownMenus(1)
		return
	end
	CloseDropDownMenus(level)
	UIDROPDOWNMENU_MENU_LEVEL = level
	UIDROPDOWNMENU_MENU_VALUE = value
	UIDROPDOWNMENU_OPEN_MENU = dropDownFrame
	list.entries = {}
	list:Show()
	if dropDownFrame and dropDownFrame.initialize then
		SIM.SafeInvoke(dropDownFrame.initialize, dropDownFrame, level, menuList or dropDownFrame.menuList)
	end
end

function UIDropDownMenu_SetWidth(frame, width)
	frame:SetWidth(width)
end

function UIDropDownMenu_SetText(frame, text)
	frame.selectedText = text
end

function UIDropDownMenu_JustifyText()
end

-- Menu entries as shown: { text, checked, disabled, hasArrow, ... } of an open level.
function SIM.MenuEntries(level)
	local list = _G["DropDownList" .. (level or 1)]
	return list:IsShown() and list.entries or {}
end

function SIM.FindMenuEntry(level, text)
	for _, entry in ipairs(SIM.MenuEntries(level)) do
		if entry.text == text then
			return entry
		end
	end
	return nil
end

-- Hover an entry with an arrow: opens the next level like UIDropDownMenuButton_OnEnter.
function SIM.OpenSubmenu(level, text)
	local entry = SIM.FindMenuEntry(level, text)
	assert(entry and entry.hasArrow, "no submenu entry '" .. tostring(text) .. "'")
	ToggleDropDownMenu(level + 1, entry.value, UIDROPDOWNMENU_OPEN_MENU)
	return entry
end

-- UIDropDownMenuButton_OnClick
function SIM.ClickMenuEntry(level, text)
	local entry = SIM.FindMenuEntry(level, text)
	assert(entry, "no menu entry '" .. tostring(text) .. "' at level " .. tostring(level))
	assert(not entry.disabled, "menu entry '" .. tostring(text) .. "' is disabled")
	local checked = entry.checked
	if type(checked) == "function" then
		checked = checked(entry)
	end
	if entry.func then
		local button = { value = entry.value, arg1 = entry.arg1, arg2 = entry.arg2, checked = checked }
		SIM.SafeInvoke(entry.func, button, entry.arg1, entry.arg2, checked)
	end
	if not entry.keepShownOnClick then
		CloseDropDownMenus()
	end
end

-- ============================================================================
-- StaticPopup (3.3.5 semantics)
-- ============================================================================

StaticPopupDialogs = {}
STATICPOPUP_NUMDIALOGS = 4

for i = 1, STATICPOPUP_NUMDIALOGS do
	local name = "StaticPopup" .. i
	local dialog = CreateFrame("Frame", name, UIParent)
	dialog:Hide()
	dialog.text = dialog:CreateFontString(name .. "Text", "ARTWORK", "GameFontHighlight")
	dialog.button1 = CreateFrame("Button", name .. "Button1", dialog, "StaticPopupButtonTemplate")
	dialog.button2 = CreateFrame("Button", name .. "Button2", dialog, "StaticPopupButtonTemplate")
	dialog.editBox = CreateFrame("EditBox", name .. "EditBox", dialog)
	dialog.wideEditBox = CreateFrame("EditBox", name .. "WideEditBox", dialog)
	for _, box in ipairs({ dialog.editBox, dialog.wideEditBox }) do
		box:SetScript("OnEnterPressed", function(self)
			local info = StaticPopupDialogs[dialog.which]
			if info and info.EditBoxOnEnterPressed then
				info.EditBoxOnEnterPressed(self, dialog.data)
			end
		end)
		box:SetScript("OnEscapePressed", function(self)
			local info = StaticPopupDialogs[dialog.which]
			if info and info.EditBoxOnEscapePressed then
				info.EditBoxOnEscapePressed(self, dialog.data)
			end
		end)
		box:SetScript("OnTextChanged", function(self)
			local info = StaticPopupDialogs[dialog.which]
			if info and info.EditBoxOnTextChanged then
				info.EditBoxOnTextChanged(self, dialog.data)
			end
		end)
	end
	dialog:SetScript("OnHide", function(self)
		local info = StaticPopupDialogs[self.which]
		if info and info.OnHide then
			info.OnHide(self, self.data)
		end
	end)
end

function StaticPopup_Visible(which)
	for i = 1, STATICPOPUP_NUMDIALOGS do
		local dialog = _G["StaticPopup" .. i]
		if dialog:IsShown() and dialog.which == which then
			return "StaticPopup" .. i, dialog
		end
	end
	return nil
end

function StaticPopup_Show(which, text1, text2, data)
	local info = StaticPopupDialogs[which]
	if not info then
		return nil
	end
	local dialog
	local _, existing = StaticPopup_Visible(which)
	if existing then
		dialog = existing
		dialog:Hide()
	else
		for i = 1, STATICPOPUP_NUMDIALOGS do
			local candidate = _G["StaticPopup" .. i]
			if not candidate:IsShown() then
				dialog = candidate
				break
			end
		end
	end
	if not dialog then
		return nil
	end
	dialog.which = which
	dialog.data = data
	dialog.text:SetFormattedText(info.text or "", text1, text2)
	dialog.button1:SetText(info.button1 or "")
	dialog.button2:SetText(info.button2 or "")
	dialog.editBox:Hide()
	dialog.wideEditBox:Hide()
	if info.hasEditBox then
		local box = info.hasWideEditBox and dialog.wideEditBox or dialog.editBox
		box:Show()
		if info.maxLetters then
			box:SetMaxLetters(info.maxLetters)
		end
		box:SetText("")
	end
	dialog:Show()
	if info.OnShow then
		SIM.SafeInvoke(info.OnShow, dialog, data)
	end
	return dialog
end

function StaticPopup_Hide(which, data)
	for i = 1, STATICPOPUP_NUMDIALOGS do
		local dialog = _G["StaticPopup" .. i]
		if dialog:IsShown() and dialog.which == which and (data == nil or dialog.data == data) then
			dialog:Hide()
		end
	end
end

-- StaticPopup.lua (3.3.5), used by the retail loadout dialogs.
StaticPopup_DisplayedFrames = {}

function StaticPopup_SetUpPosition(dialog)
	if not tContains(StaticPopup_DisplayedFrames, dialog) then
		local lastFrame = StaticPopup_DisplayedFrames[#StaticPopup_DisplayedFrames]
		if lastFrame then
			dialog:SetPoint("TOP", lastFrame, "BOTTOM", 0, 0)
		else
			dialog:SetPoint("TOP", UIParent, "TOP", 0, -135)
		end
		tinsert(StaticPopup_DisplayedFrames, dialog)
	end
end

function StaticPopup_CollapseTable()
	local displayedFrames = StaticPopup_DisplayedFrames
	local index = #displayedFrames
	while index >= 1 and not displayedFrames[index]:IsShown() do
		tremove(displayedFrames, index)
		index = index - 1
	end
end

function StaticPopupSpecial_Show(frame)
	if frame.exclusive then
		StaticPopup_HideExclusive()
	end
	StaticPopup_SetUpPosition(frame)
	frame:Show()
end

function StaticPopupSpecial_Hide(frame)
	frame:Hide()
	StaticPopup_CollapseTable()
end

function StaticPopup_HideExclusive()
	for _, frame in pairs(StaticPopup_DisplayedFrames) do
		if frame:IsShown() and frame.exclusive then
			local standardDialog = StaticPopupDialogs[frame.which]
			if standardDialog then
				frame:Hide()
				if standardDialog.OnCancel then
					standardDialog.OnCancel(frame, frame.data, "override")
				end
			else
				StaticPopupSpecial_Hide(frame)
			end
			break
		end
	end
end

-- Clicks button1 (accept) or button2 (cancel) of a visible popup.
function SIM.ClickPopup(which, button)
	local _, dialog = StaticPopup_Visible(which)
	assert(dialog, "popup " .. tostring(which) .. " is not shown")
	local info = StaticPopupDialogs[which]
	local keepOpen
	if (button or 1) == 1 then
		if info.OnAccept then
			local ok, result = pcall(info.OnAccept, dialog, dialog.data, dialog.data2)
			if not ok then
				geterrorhandler()(result)
			end
			keepOpen = ok and result
		end
	elseif info.OnCancel then
		SIM.SafeInvoke(info.OnCancel, dialog, dialog.data, "clicked")
	end
	if not keepOpen then
		dialog:Hide()
	end
	return dialog
end

-- ============================================================================
-- Player, units, combat
-- ============================================================================

CLIENT.player = {
	name = "Tester",
	class = "WARRIOR",
	level = 80,
	race = "Human",
	sex = 2,
	groups = 2,
	activeGroup = 1,
	inCombat = false,
	dead = false,
	extraTalentPoints = 0,
}

CLIENT.cvars = {}

function CLIENT.ClassID()
	return CLASS_IDS[CLIENT.player.class]
end

function UnitName(unit)
	if unit == "player" then
		return CLIENT.player.name, nil
	end
	return nil
end

function UnitClass(unit)
	if unit == "player" then
		return CLASS_NAMES[CLIENT.player.class], CLIENT.player.class
	end
	return nil
end

function UnitLevel(unit)
	if unit == "player" then
		return CLIENT.player.level
	end
	return 0
end

function UnitRace(unit)
	return CLIENT.player.race, CLIENT.player.race
end

function UnitSex(unit)
	return CLIENT.player.sex
end

function UnitGUID(unit)
	return unit == "player" and "0x0000000000000001" or nil
end

function UnitExists(unit)
	if unit == "player" then
		return 1
	end
	if unit == "pet" then
		return CLIENT.pet and 1 or nil
	end
	return nil
end

function UnitIsUnit(a, b)
	return a == b and 1 or nil
end

function UnitIsPlayer(unit)
	return unit == "player" and 1 or nil
end

function UnitFactionGroup(unit)
	return "Alliance", "Alliance"
end

function UnitAffectingCombat(unit)
	return (unit == "player" and CLIENT.player.inCombat) and 1 or nil
end

function InCombatLockdown()
	return CLIENT.player.inCombat and 1 or nil
end

function UnitIsDeadOrGhost(unit)
	return (unit == "player" and CLIENT.player.dead) and 1 or nil
end

function UnitIsDead(unit)
	return UnitIsDeadOrGhost(unit)
end

function UnitStat(unit, index)
	return 100, 100, 0, 0
end

function UnitPowerType(unit)
	return 1, "RAGE"
end

function HasPetUI()
	return CLIENT.pet and 1 or nil, CLIENT.pet and 1 or nil
end

function IsShiftKeyDown()
	return SIM.keys.shift and 1 or nil
end

function IsControlKeyDown()
	return SIM.keys.ctrl and 1 or nil
end

function IsAltKeyDown()
	return SIM.keys.alt and 1 or nil
end

function IsModifiedClick(action)
	if action == "CHATLINK" or action == "SHIFT" then
		return IsShiftKeyDown()
	elseif action == "DRESSUP" then
		return IsControlKeyDown()
	end
	return nil
end

function GetModifiedClick(action)
	return "SHIFT"
end

function GetBindingKey()
	return nil
end

function GetLocale()
	return "enUS"
end

function GetBuildInfo()
	return "3.3.5", "12340", "Jun 24 2010", 30300
end

function GetRealmName()
	return "Dark Chaos"
end

function IsInInstance()
	return nil, "none"
end

function GetCVar(name)
	return CLIENT.cvars[name]
end

function SetCVar(name, value)
	CLIENT.cvars[name] = value ~= nil and tostring(value) or nil
end

function GetCVarBool(name)
	return CLIENT.cvars[name] == "1" and 1 or nil
end

function GetCVarDefault(name)
	return nil
end

function RegisterCVar(name, default)
	if CLIENT.cvars[name] == nil then
		CLIENT.cvars[name] = default ~= nil and tostring(default) or nil
	end
end

function PlaySound(sound)
	if type(sound) ~= "string" then
		error("Usage: PlaySound(\"sound\")", 2)
	end
	table.insert(SIM.sounds, sound)
end

function PlaySoundFile(path)
	table.insert(SIM.sounds, "file:" .. tostring(path))
end

function SendChatMessage(text, chatType, language, target)
	SIM.sentChat = SIM.sentChat or {}
	table.insert(SIM.sentChat, { text = text, chatType = chatType, target = target })
end

function SendAddonMessage(prefix, text, chatType, target)
	table.insert(SIM.addonMessages, { prefix = prefix, text = text, chatType = chatType, target = target })
end

function hooksecurefunc(target, name, hook)
	if type(target) == "string" then
		target, name, hook = _G, target, name
	end
	local original = target[name]
	if type(original) ~= "function" then
		error("hooksecurefunc(): " .. tostring(name) .. " is not a function", 2)
	end
	target[name] = function(...)
		local results = table.pack(original(...))
		hook(...)
		return table.unpack(results, 1, results.n)
	end
end

function securecall(func, ...)
	if type(func) == "string" then
		func = _G[func]
	end
	return func(...)
end

function issecurevariable()
	return nil
end

function issecure()
	return nil
end

function SetPortraitToTexture(texture, path)
	if type(texture) == "string" then
		texture = _G[texture]
	end
	if not texture or not S[texture] or S[texture].type ~= "Texture" then
		error("Usage: SetPortraitToTexture(texture, \"path\")", 2)
	end
	S[texture].texture = path
	S[texture].portrait = true
end

-- Renders the unit's portrait into the texture (recorded as "portrait:<unit>").
function SetPortraitTexture(texture, unit)
	if type(texture) == "string" then
		texture = _G[texture]
	end
	if not texture or not S[texture] or S[texture].type ~= "Texture" or type(unit) ~= "string" then
		error("Usage: SetPortraitTexture(texture, \"unit\")", 2)
	end
	S[texture].texture = "portrait:" .. unit:lower()
	S[texture].portrait = true
end

-- ============================================================================
-- Spells
-- ============================================================================

CLIENT.spellNames = {}

function SIM.SpellName(spellID)
	return CLIENT.spellNames[spellID] or ("Spell" .. tostring(spellID))
end

function SIM.SpellTooltipLines(spellID)
	return { "Instant", ("Spell %d does something useful."):format(spellID) }
end

local function SpellIDFromName(name)
	local id = tonumber(tostring(name):match("^Spell(%d+)$"))
	if id then
		return id
	end
	for spellID, spellName in pairs(CLIENT.spellNames) do
		if spellName == name then
			return spellID
		end
	end
	return nil
end

function GetSpellInfo(spell)
	local spellID = type(spell) == "number" and spell or SpellIDFromName(spell)
	if not spellID then
		return nil
	end
	return SIM.SpellName(spellID), "", "Interface\\Icons\\Spell_Nature_Starfall", 0, nil, 0, 0, 0, 0
end

function GetSpellLink(spell)
	local spellID = type(spell) == "number" and spell or SpellIDFromName(spell)
	if not spellID then
		return nil
	end
	return ("|cff71d5ff|Hspell:%d|h[%s]|h|r"):format(spellID, SIM.SpellName(spellID))
end

function GetSpellTexture(spell)
	return "Interface\\Icons\\Spell_Nature_Starfall"
end

function IsPassiveSpell()
	return nil
end

function IsSpellKnown(spellID)
	return CLIENT.KnowsSpell(spellID) and 1 or nil
end

function PickupSpell(spell)
	SIM.cursor = { type = "spell", spell = spell }
end

function ClearCursor()
	SIM.cursor = nil
end

function GetCursorInfo()
	if SIM.cursor then
		return SIM.cursor.type, SIM.cursor.spell
	end
end

function GetActionInfo(slot)
	return nil
end

function HasAction(slot)
	return nil
end

-- ============================================================================
-- Talents (3.3.5 API over the real Talent.dbc data)
-- ============================================================================

do
	local ns = {}
	local chunk = assert(loadfile(SIM.ADDONS_DIR .. "DC-Talents/Data/TalentData.lua"))
	chunk("DC-Talents", ns)
	SIM.TalentData = ns.TalentData
	SIM.TalentTabData = ns.TalentTabData
end

local TAB_NAMES = {
	[161] = "Arms", [164] = "Fury", [163] = "Protection",
	[382] = "Holy", [383] = "Protection", [381] = "Retribution",
	[361] = "Beast Mastery", [363] = "Marksmanship", [362] = "Survival",
	[182] = "Assassination", [181] = "Combat", [183] = "Subtlety",
	[201] = "Discipline", [202] = "Holy", [203] = "Shadow",
	[398] = "Blood", [399] = "Frost", [400] = "Unholy",
	[261] = "Elemental", [263] = "Enhancement", [262] = "Restoration",
	[81] = "Arcane", [41] = "Fire", [61] = "Frost",
	[302] = "Affliction", [303] = "Demonology", [301] = "Destruction",
	[283] = "Balance", [281] = "Feral Combat", [282] = "Restoration",
	[409] = "Tenacity", [410] = "Ferocity", [411] = "Cunning",
}
CLIENT.TAB_NAMES = TAB_NAMES

-- tabs[i] = { id, name, talents = { talentIDs sorted by tier, column } }
local tabCache = {}

local function Tabs(pet)
	local key = pet and ("pet" .. tostring(CLIENT.pet and CLIENT.pet.treeMask)) or CLIENT.player.class
	if tabCache[key] then
		return tabCache[key]
	end
	local tabs = {}
	for tabID, data in pairs(SIM.TalentTabData) do
		local match
		if pet then
			match = CLIENT.pet and (data[2] & CLIENT.pet.treeMask) ~= 0
		else
			match = (data[1] & (1 << (CLIENT.ClassID() - 1))) ~= 0
		end
		if match then
			tabs[#tabs + 1] = { id = tabID, order = data[3], name = TAB_NAMES[tabID] or ("Tab" .. tabID), talents = {} }
		end
	end
	table.sort(tabs, function(a, b) return a.order < b.order end)
	for _, tab in ipairs(tabs) do
		for talentID, data in pairs(SIM.TalentData) do
			if data[1] == tab.id then
				tab.talents[#tab.talents + 1] = talentID
			end
		end
		table.sort(tab.talents, function(a, b)
			local da, db = SIM.TalentData[a], SIM.TalentData[b]
			if da[2] ~= db[2] then
				return da[2] < db[2]
			end
			return da[3] < db[3]
		end)
	end
	tabCache[key] = tabs
	return tabs
end
CLIENT.Tabs = Tabs

function CLIENT.ResetTabCache()
	wipe(tabCache)
end

CLIENT.ranks = { {}, {} }
CLIENT.preview = { {}, {} }
CLIENT.petRanks = {}
CLIENT.petPreview = {}
CLIENT.glyphs = { {}, {} }

local function MaxRank(talentID)
	return #SIM.TalentData[talentID] - 6
end
CLIENT.MaxRank = MaxRank

local function RanksFor(pet, group)
	if pet then
		return CLIENT.petRanks
	end
	return CLIENT.ranks[group or CLIENT.player.activeGroup]
end

local function PreviewFor(pet, group)
	if pet then
		return CLIENT.petPreview
	end
	return CLIENT.preview[group or CLIENT.player.activeGroup]
end

function CLIENT.TotalPoints(pet)
	if pet then
		return CLIENT.pet and CLIENT.pet.totalPoints or 0
	end
	if CLIENT.player.totalPoints then
		return CLIENT.player.totalPoints
	end
	return math.max(0, CLIENT.player.level - 9) + (CLIENT.player.extraTalentPoints or 0)
end

function CLIENT.Spent(pet, group)
	local total = 0
	for _, rank in pairs(RanksFor(pet, group)) do
		total = total + rank
	end
	return total
end

local function TabOf(talentID, pet)
	for tabIndex, tab in ipairs(Tabs(pet)) do
		for index, id in ipairs(tab.talents) do
			if id == talentID then
				return tabIndex, index
			end
		end
	end
end
CLIENT.TabOf = TabOf

local function TabPoints(tabIndex, pet, group, ranks)
	local total = 0
	ranks = ranks or RanksFor(pet, group)
	for _, talentID in ipairs(Tabs(pet)[tabIndex].talents) do
		total = total + (ranks[talentID] or 0)
	end
	return total
end

function CLIENT.KnowsSpell(spellID)
	for talentID, rank in pairs(RanksFor(false)) do
		local data = SIM.TalentData[talentID]
		for i = 1, rank do
			if data[6 + i] == spellID then
				return true
			end
		end
	end
	return false
end

-- AzerothCore Player::LearnTalent: one rank, points in the whole tab >= 5 x row (3 for pets), the
-- prerequisite at its required rank, a free point. Returns true or an error string.
function CLIENT.CanLearn(talentID, pet, group, ranks)
	ranks = ranks or RanksFor(pet, group)
	local data = SIM.TalentData[talentID]
	if not data then
		return "no such talent"
	end
	local rank = ranks[talentID] or 0
	if rank >= MaxRank(talentID) then
		return "max rank"
	end
	local spent = 0
	for _, r in pairs(ranks) do
		spent = spent + r
	end
	if spent >= CLIENT.TotalPoints(pet) then
		return "no points"
	end
	local tabIndex = TabOf(talentID, pet)
	local perTier = pet and 3 or 5
	if data[2] > 0 and TabPoints(tabIndex, pet, group, ranks) < data[2] * perTier then
		return "tier locked"
	end
	if data[5] ~= 0 and (ranks[data[5]] or 0) < data[6] then
		return "prerequisite"
	end
	return true
end

local function TalentChanged(pet)
	SIM.Schedule(0.05, function()
		if pet then
			SIM.FireEvent("PET_TALENT_UPDATE")
		else
			SIM.FireEvent("CHARACTER_POINTS_CHANGED", -1)
			SIM.FireEvent("PLAYER_TALENT_UPDATE")
			SIM.FireEvent("SPELLS_CHANGED")
		end
	end)
end
CLIENT.TalentChanged = TalentChanged

function CLIENT.LearnRank(talentID, pet, group, quiet)
	local ranks = RanksFor(pet, group)
	local ok = CLIENT.CanLearn(talentID, pet, group, ranks)
	if ok ~= true then
		return ok
	end
	local rank = (ranks[talentID] or 0) + 1
	ranks[talentID] = rank
	if not quiet and not pet then
		SIM.SystemMessage(ERR_LEARN_SPELL_S:format(SIM.SpellName(SIM.TalentData[talentID][6 + rank])))
	end
	return true
end

function GetNumTalentTabs(inspect, pet)
	if inspect then
		return CLIENT.inspect and 3 or 0
	end
	if pet and not CLIENT.pet then
		return 0
	end
	return #Tabs(pet)
end

function GetTalentTabInfo(tabIndex, inspect, pet, group)
	local tab = Tabs(pet)[tabIndex]
	if not tab then
		return nil
	end
	local points = TabPoints(tabIndex, pet, group)
	local preview = TabPoints(tabIndex, pet, group, PreviewFor(pet, group)) + points
	return tab.name, "Interface\\Icons\\Ability_" .. tab.id, points, "Tab" .. tab.id, preview
end

function GetNumTalents(tabIndex, inspect, pet)
	local tab = Tabs(pet)[tabIndex]
	return tab and #tab.talents or 0
end

function GetTalentInfo(tabIndex, talentIndex, inspect, pet, group)
	local tab = Tabs(pet)[tabIndex]
	local talentID = tab and tab.talents[talentIndex]
	if not talentID then
		return nil
	end
	local data = SIM.TalentData[talentID]
	local rank = RanksFor(pet, group)[talentID] or 0
	local previewRank = rank + (PreviewFor(pet, group)[talentID] or 0)
	local prereqMet = data[5] == 0 or (RanksFor(pet, group)[data[5]] or 0) >= data[6]
	return "Talent" .. talentID, "Interface\\Icons\\Talent" .. talentID, data[2] + 1, data[3] + 1, rank,
		MaxRank(talentID), data[4] == 1 and 1 or nil, prereqMet and 1 or nil, previewRank, prereqMet and 1 or nil
end

function GetTalentLink(tabIndex, talentIndex, inspect, pet, group)
	local tab = Tabs(pet)[tabIndex]
	local talentID = tab and tab.talents[talentIndex]
	if not talentID then
		return nil
	end
	local rank = RanksFor(pet, group)[talentID] or 0
	return ("|cff4e96f7|Htalent:%d:%d|h[Talent%d]|h|r"):format(talentID, rank - 1, talentID)
end

function GetTalentPrereqs(tabIndex, talentIndex, inspect, pet, group)
	local tab = Tabs(pet)[tabIndex]
	local talentID = tab and tab.talents[talentIndex]
	local data = talentID and SIM.TalentData[talentID]
	if not data or data[5] == 0 then
		return nil
	end
	local prereq = SIM.TalentData[data[5]]
	local met = (RanksFor(pet, group)[data[5]] or 0) >= data[6]
	return prereq[2] + 1, prereq[3] + 1, met and 1 or nil, met and 1 or nil
end

function GetUnspentTalentPoints(inspect, pet, group)
	return CLIENT.TotalPoints(pet) - CLIENT.Spent(pet, group)
end

function GetNumTalentGroups(inspect, pet)
	if pet then
		return 1
	end
	return CLIENT.player.groups
end

function GetActiveTalentGroup(inspect, pet)
	if pet then
		return 1
	end
	return CLIENT.player.activeGroup
end

function LearnTalent(tabIndex, talentIndex, pet, group)
	local tab = Tabs(pet)[tabIndex]
	local talentID = tab and tab.talents[talentIndex]
	if not talentID then
		return
	end
	if not pet and (group or CLIENT.player.activeGroup) ~= CLIENT.player.activeGroup then
		return
	end
	if CLIENT.LearnRank(talentID, pet) == true then
		TalentChanged(pet)
	end
end

function AddPreviewTalentPoints(tabIndex, talentIndex, points, pet, group)
	local tab = Tabs(pet)[tabIndex]
	local talentID = tab and tab.talents[talentIndex]
	if not talentID then
		return
	end
	local preview = PreviewFor(pet, group)
	preview[talentID] = math.max(0, (preview[talentID] or 0) + points)
	if preview[talentID] == 0 then
		preview[talentID] = nil
	end
	SIM.FireEvent("PREVIEW_TALENT_POINTS_CHANGED", talentIndex, tabIndex, group)
end

function GetGroupPreviewTalentPointsSpent(pet, group)
	local total = 0
	for _, points in pairs(PreviewFor(pet, group)) do
		total = total + points
	end
	return total
end

function GetPreviewTalentPointsSpent(pet, group)
	return GetGroupPreviewTalentPointsSpent(pet, group)
end

function ResetGroupPreviewTalentPoints(pet, group)
	wipe(PreviewFor(pet, group))
	SIM.FireEvent("PREVIEW_TALENT_POINTS_CHANGED", 0, 0, group)
end

function ResetPreviewTalentPoints(tabIndex, pet, group)
	local preview = PreviewFor(pet, group)
	for _, talentID in ipairs(Tabs(pet)[tabIndex].talents) do
		preview[talentID] = nil
	end
	SIM.FireEvent("PREVIEW_TALENT_POINTS_CHANGED", 0, tabIndex, group)
end

-- CMSG_LEARN_PREVIEW_TALENTS: the client lists (talent, rank) by tab and index; the server learns
-- them in that order with LearnTalent's rules and stops at nothing (failures are skipped).
function LearnPreviewTalents(pet)
	local preview = PreviewFor(pet)
	local learned = 0
	CLIENT.previewFailures = {}
	for _, tab in ipairs(Tabs(pet)) do
		for _, talentID in ipairs(tab.talents) do
			for _ = 1, preview[talentID] or 0 do
				local ok = CLIENT.LearnRank(talentID, pet)
				if ok == true then
					learned = learned + 1
				else
					table.insert(CLIENT.previewFailures, { talentID, ok })
				end
			end
		end
	end
	wipe(preview)
	SIM.FireEvent("PREVIEW_TALENT_POINTS_CHANGED", 0, 0)
	if learned > 0 then
		TalentChanged(pet)
	end
end

-- Dual spec: the activation spells, then the talent group switch.
local ACTIVATE_SPELLS = { [1] = 63645, [2] = 63644 }

function SetActiveTalentGroup(group)
	if group == CLIENT.player.activeGroup or group > CLIENT.player.groups then
		return
	end
	local spellName = SIM.SpellName(ACTIVATE_SPELLS[group])
	CLIENT.player.casting = spellName
	SIM.FireEvent("UNIT_SPELLCAST_START", "player", spellName, "")
	SIM.Schedule(CLIENT.specSwitchTime or 5, function()
		if CLIENT.player.casting ~= spellName then
			return
		end
		CLIENT.player.casting = nil
		local old = CLIENT.player.activeGroup
		CLIENT.player.activeGroup = group
		SIM.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", spellName, "")
		SIM.FireEvent("ACTIVE_TALENT_GROUP_CHANGED", group, old)
		SIM.FireEvent("PLAYER_TALENT_UPDATE")
	end)
end

function SIM.InterruptCast()
	local spellName = CLIENT.player.casting
	if spellName then
		CLIENT.player.casting = nil
		SIM.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player", spellName, "")
	end
end

-- Glyphs: sockets 1, 4, 6 major; 2, 3, 5 minor (3.3.5 layout).
local GLYPH_TYPES = { 1, 2, 2, 1, 2, 1 }

function GetNumGlyphSockets()
	return 6
end

function GetGlyphSocketInfo(socket, group)
	local spellID = CLIENT.glyphs[group or CLIENT.player.activeGroup][socket]
	return 1, GLYPH_TYPES[socket], spellID, spellID and "Interface\\Spellbook\\UI-Glyph-Rune1" or nil
end

function GetGlyphLink(socket, group)
	local spellID = CLIENT.glyphs[group or CLIENT.player.activeGroup][socket]
	return spellID and ("|cff66bbff|Hglyph:%d:%d|h[Glyph]|h|r"):format(socket, spellID) or ""
end

-- Bags: CLIENT.bags[bag][slot] = { name, glyphSpell }. Using a glyph item puts the glyph on the
-- cursor; PlaceGlyphInSocket inscribes it into the active group (3.3.5 flow).
CLIENT.bags = { [0] = {} }

function CLIENT.AddItem(bag, slot, name, glyphSpell)
	CLIENT.bags[bag] = CLIENT.bags[bag] or {}
	CLIENT.bags[bag][slot] = { name = name, glyphSpell = glyphSpell, link = ("|cffffffff|Hitem:%d:0:0:0:0:0:0:0|h[%s]|h|r"):format(40000 + slot, name) }
end

function GetContainerNumSlots(bag)
	return CLIENT.bags[bag] and 16 or 0
end

function GetContainerItemLink(bag, slot)
	local item = CLIENT.bags[bag] and CLIENT.bags[bag][slot]
	return item and item.link or nil
end

function GetItemInfo(item)
	for _, slots in pairs(CLIENT.bags) do
		for _, entry in pairs(slots) do
			if entry.link == item or entry.name == item then
				return entry.name, entry.link, 1, 80, 75, "Glyph", "Glyph", 20, "", "Interface\\Icons\\INV_Glyph_MajorWarrior", 0
			end
		end
	end
	return nil
end

function UseContainerItem(bag, slot)
	local item = CLIENT.bags[bag] and CLIENT.bags[bag][slot]
	if item and item.glyphSpell then
		SIM.pendingGlyph = { spell = item.glyphSpell, bag = bag, slot = slot }
	end
end

function PlaceGlyphInSocket(socket)
	local pending = SIM.pendingGlyph
	if not pending then
		return
	end
	SIM.pendingGlyph = nil
	local group = CLIENT.player.activeGroup
	local had = CLIENT.glyphs[group][socket]
	CLIENT.glyphs[group][socket] = pending.spell
	CLIENT.bags[pending.bag][pending.slot] = nil
	SIM.Schedule(0.05, function()
		SIM.FireEvent(had and "GLYPH_UPDATED" or "GLYPH_ADDED", socket)
	end)
end

-- ============================================================================
-- DC-AddonProtocol (stub) and the TLNT server module (fake)
-- ============================================================================

DCAddonProtocol = {
	_handlers = {},
	sent = {},
}

function DCAddonProtocol:RegisterHandler(module, opcode, handler)
	local key = module .. "_" .. tostring(opcode)
	self._handlers[key] = self._handlers[key] or {}
	table.insert(self._handlers[key], handler)
end

function DCAddonProtocol:Request(module, opcode, data)
	table.insert(self.sent, { module = module, opcode = opcode, data = data })
	if SIM.server then
		SIM.server(module, opcode, data)
	end
end

function SIM.Deliver(module, opcode, data)
	for _, handler in ipairs(DCAddonProtocol._handlers[module .. "_" .. tostring(opcode)] or {}) do
		SIM.SafeInvoke(handler, data)
	end
end

-- The TLNT module: HELLO answers capabilities; APPLY_BUILD resets the group and relearns the build
-- in tier order with the server's rules, sends the talent update, then the result.
CLIENT.serverOptions = { enabled = true, freeRespec = true, pet = true, latency = 0.1 }

local function ServerApply(data, pet)
	local options = CLIENT.serverOptions
	if CLIENT.player.inCombat then
		return { req = data.req, ok = false, code = "COMBAT", msg = "You are in combat." }
	end
	if not pet and data.spec ~= CLIENT.player.activeGroup then
		return { req = data.req, ok = false, code = "SPEC", msg = "Wrong talent group." }
	end
	local wanted = {}
	for _, entry in ipairs(data.t or {}) do
		wanted[entry.id] = entry.r
	end
	local ranks = RanksFor(pet)
	local backup = CopyTable(ranks)
	wipe(ranks)
	local order = {}
	for talentID in pairs(wanted) do
		order[#order + 1] = talentID
	end
	table.sort(order, function(a, b)
		local da, db = SIM.TalentData[a], SIM.TalentData[b]
		if da[2] ~= db[2] then
			return da[2] < db[2]
		end
		return a < b
	end)
	local failed = {}
	for _, talentID in ipairs(order) do
		for _ = 1, wanted[talentID] do
			local ok = CLIENT.LearnRank(talentID, pet, nil, false)
			if ok ~= true then
				failed[#failed + 1] = talentID
				break
			end
		end
	end
	if #failed > 0 and options.atomic ~= false then
		wipe(ranks)
		for talentID, rank in pairs(backup) do
			ranks[talentID] = rank
		end
		return { req = data.req, ok = false, code = "INVALID", msg = "Invalid build.", failed = failed }
	end
	return { req = data.req, ok = true, code = "OK", spent = CLIENT.Spent(pet), failed = failed }
end

function SIM.server(module, opcode, data)
	if module ~= "TLNT" or not CLIENT.serverOptions.enabled then
		return
	end
	local latency = CLIENT.serverOptions.latency or 0.1
	if opcode == 0x01 then
		SIM.Schedule(latency, function()
			SIM.Deliver("TLNT", 0x11, { v = 1, enabled = true, freeRespec = CLIENT.serverOptions.freeRespec, pet = CLIENT.serverOptions.pet, max = 40 })
		end)
	elseif opcode == 0x02 or opcode == 0x03 then
		local pet = opcode == 0x03
		SIM.Schedule(latency, function()
			local result = ServerApply(data, pet)
			if result.ok then
				-- SMSG_TALENTS_INFO first, then the result.
				if pet then
					SIM.FireEvent("PET_TALENT_UPDATE")
				else
					SIM.FireEvent("CHARACTER_POINTS_CHANGED", 0)
					SIM.FireEvent("PLAYER_TALENT_UPDATE")
				end
			end
			SIM.Deliver("TLNT", pet and 0x13 or 0x12, result)
		end)
	end
end

-- ============================================================================
-- Loading an addon: TOC order, the per-file private environment (setfenv emulation)
-- ============================================================================

local fenvState

function setfenv(level, env)
	if level ~= 1 or not fenvState then
		error("setfenv: only setfenv(1, env) at file scope is emulated", 2)
	end
	fenvState.target = env
	return env
end

function getfenv(level)
	return fenvState and fenvState.target or _G
end

function SIM.LoadFile(path, addonName, ns)
	local file = assert(io.open(path, "rb"))
	local source = file:read("a")
	file:close()
	local state = { target = _G }
	local proxy = setmetatable({}, {
		__index = function(_, key)
			return state.target[key]
		end,
		__newindex = function(_, key, value)
			state.target[key] = value
		end,
	})
	local chunk, err = load(source, "@" .. path, "t", proxy)
	if not chunk then
		error(err, 0)
	end
	local previous = fenvState
	fenvState = state
	local ok, runErr = xpcall(chunk, Traceback or debug.traceback, addonName, ns)
	fenvState = previous
	if not ok then
		error(runErr, 0)
	end
end

function SIM.ReadToc(path)
	local files = {}
	for line in io.lines(path) do
		line = line:gsub("\r$", "")
		if line ~= "" and not line:match("^#") then
			files[#files + 1] = line:gsub("\\", "/")
		end
	end
	return files
end

function SIM.LoadAddon(name)
	local root = SIM.ADDONS_DIR .. name .. "/"
	local ns = {}
	for _, file in ipairs(SIM.ReadToc(root .. name .. ".toc")) do
		local ok, err = pcall(SIM.LoadFile, root .. file, name, ns)
		if not ok then
			geterrorhandler()(("loading %s: %s"):format(file, tostring(err)))
		end
	end
	CLIENT.loadedAddons[name] = true
	return ns
end

return CLIENT
