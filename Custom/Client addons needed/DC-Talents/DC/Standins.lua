--[[
	DC-Talents - stand-ins for retail systems the port does not carry.

	The vendored retail talent files reference systems that are either retail-only engine features or
	whole addons we do not port. Each stand-in keeps the retail API surface the vendored code calls:

	  Menu / MenuUtil / DropdownButton   retail 11.x menus, rendered with the stock UIDropDownMenu
	  WowStyle1DropdownTemplate          the dropdown button the loadout selector uses
	  ScrollBox (list, linear view)      only what the search preview list needs
	  Hero talents, PvP talents, War Mode, model scenes, spellbook, minimize button
	                                     inert frames (WotLK has none of these)
	  GlowEmitterFactory, HelpTip, OverlayPlayerCastingBarFrame, AssistedCombatManager, action bar
	  highlight helpers                  small or no-op implementations
	  DialogBorderDarkTemplate, InputScrollFrameTemplate, UIPanelButtonNoTooltipTemplate,
	  MagicButtonTemplate                3.3.5 look-alikes
]]

local _, ns = ...
setfenv(1, ns.env)

local G = ns.realG
local XML = ns.XML

local function Nop() end

-- Registers a stand-in template written in the same table form xml2lua.py produces.
local function Template(tag, name, attr, children)
	attr = attr or {}
	attr.name = name
	attr.virtual = "true"
	XML.RegisterTemplate(name, { tag = tag, attr = attr, children = children }, "DC stand-in")
end

local function Anchor(point, x, y, relativeKey, relativePoint)
	return { tag = "Anchor", attr = { point = point, x = x and tostring(x) or nil, y = y and tostring(y) or nil, relativeKey = relativeKey, relativePoint = relativePoint } }
end

local function Size(x, y)
	return { tag = "Size", attr = { x = x and tostring(x) or nil, y = y and tostring(y) or nil } }
end

local function Scripts(handlers)
	local children = {}
	for handler, method in pairs(handlers) do
		children[#children + 1] = { tag = handler, attr = { method = method } }
	end
	return { tag = "Scripts", children = children }
end

-- ----------------------------------------------------------------------------
-- Atlas replacements for retail sheets we do not ship
-- ----------------------------------------------------------------------------

ns.Atlas.Register("common-search-magnifyingglass", "Interface\\WorldMap\\WorldMap-MagnifyingGlass", 16, 16)
ns.Atlas.Register("common-search-clearbutton", "Interface\\FriendsFrame\\ClearBroadcastIcon", 16, 16)
ns.Atlas.Register("UI-LFG-RoleIcon-Generic", "Interface\\LFGFrame\\UI-LFG-ICON-ROLES", 20, 20, 0.25, 0.5, 0, 0.25)

-- ----------------------------------------------------------------------------
-- Menus: retail element descriptions, rendered by UIDropDownMenu
-- ----------------------------------------------------------------------------

MenuResponse = MenuResponse or { Open = 1, Refresh = 2, Close = 3, CloseAll = 4 }

local DescriptionMixin = {}

local function NewDescription(kind, text, fields)
	local description = CreateFromMixins(DescriptionMixin)
	description.kind = kind
	description.text = text
	description.children = {}
	if fields then
		for key, value in pairs(fields) do
			description[key] = value
		end
	end
	return description
end

function DescriptionMixin:Insert(description)
	self.children[#self.children + 1] = description
	return description
end

function DescriptionMixin:CreateButton(text, callback, data)
	return self:Insert(NewDescription("button", text, { callback = callback, data = data }))
end

function DescriptionMixin:CreateRadio(text, isSelected, setSelected, data)
	return self:Insert(NewDescription("radio", text, { isSelected = isSelected, setSelected = setSelected, data = data }))
end

function DescriptionMixin:CreateCheckbox(text, isSelected, setSelected, data)
	return self:Insert(NewDescription("checkbox", text, { isSelected = isSelected, setSelected = setSelected, data = data }))
end

function DescriptionMixin:CreateTitle(text)
	return self:Insert(NewDescription("title", text))
end

function DescriptionMixin:CreateDivider()
	return self:Insert(NewDescription("divider", ""))
end

function DescriptionMixin:CreateSpacer()
	return self:Insert(NewDescription("divider", ""))
end

function DescriptionMixin:CreateTemplate()
	return self:Insert(NewDescription("divider", ""))
end

function DescriptionMixin:SetTag(tag)
	self.tag = tag
end

function DescriptionMixin:GetTag()
	return self.tag
end

function DescriptionMixin:SetEnabled(enabled)
	self.enabled = enabled
end

function DescriptionMixin:IsEnabled()
	local enabled = self.enabled
	if type(enabled) == "function" then
		return enabled(self) and true or false
	end
	return enabled ~= false
end

function DescriptionMixin:SetTooltip(func)
	self.tooltip = func
end

function DescriptionMixin:AddInitializer(func)
	self.initializers = self.initializers or {}
	self.initializers[#self.initializers + 1] = func
end

function DescriptionMixin:SetResponder(func)
	self.responder = func
end

function DescriptionMixin:SetResponse(response)
	self.response = response
end

function DescriptionMixin:SetData(data)
	self.data = data
end

function DescriptionMixin:GetData()
	return self.data
end

function DescriptionMixin:SetOnEnter(func)
	self.onEnter = func
end

function DescriptionMixin:SetOnLeave(func)
	self.onLeave = func
end

DescriptionMixin.SetScrollMode = Nop
DescriptionMixin.SetMinimumWidth = Nop
DescriptionMixin.SetGridMode = Nop
DescriptionMixin.SetShouldPlaySoundOnSubmenuClick = Nop
DescriptionMixin.SetCanSelect = Nop
DescriptionMixin.SetRadio = Nop
DescriptionMixin.SetIsSelected = function(self, func)
	self.isSelected = func
end
DescriptionMixin.SetSelectionIgnored = Nop
DescriptionMixin.DisableMenuListUpdate = Nop

function DescriptionMixin:HasElements()
	return #self.children > 0
end

function DescriptionMixin:EnumerateElementDescriptions()
	return ipairs(self.children)
end

function DescriptionMixin:IsSelected()
	if self.isSelected then
		return self.isSelected(self.data) and true or false
	end
	return false
end

-- Collects the lines a retail tooltip callback writes, so they can go into UIDropDownMenu tooltips.
local function CaptureTooltip(func, description)
	local title, lines = nil, {}
	local fake = {}
	function fake:SetText(text)
		title = text
	end
	function fake:AddLine(text)
		lines[#lines + 1] = text
	end
	fake.AddDoubleLine = fake.AddLine
	fake.SetOwner = Nop
	fake.Show = Nop
	ns.SafeCall(func, fake, description)
	return title, (#lines > 0) and table.concat(lines, "\n") or nil
end

local menuHost
local openRoot
local openOwner

local function Respond(description)
	local response
	if description.kind == "radio" or description.kind == "checkbox" then
		if description.setSelected then
			response = description.setSelected(description.data)
		end
	elseif description.callback then
		response = description.callback(description.data, { buttonName = "LeftButton" }, nil)
	elseif description.responder then
		response = description.responder(description.data)
	end
	response = response or description.response
	if description.kind == "checkbox" and response == nil then
		response = MenuResponse.Refresh
	end
	if response == MenuResponse.Refresh or response == MenuResponse.Open then
		return
	end
	G.CloseDropDownMenus()
end

local function InitializeMenu(self, level)
	local description = level == 1 and openRoot or G.UIDROPDOWNMENU_MENU_VALUE
	if not description or not description.children then
		return
	end

	for _, child in ipairs(description.children) do
		local info = G.UIDropDownMenu_CreateInfo()
		info.text = child.text or ""
		if child.kind == "title" then
			info.isTitle = 1
			info.notCheckable = 1
		elseif child.kind == "divider" then
			info.text = ""
			info.disabled = 1
			info.notCheckable = 1
		else
			if child.kind == "radio" or child.kind == "checkbox" then
				info.checked = child:IsSelected()
				info.keepShownOnClick = child.kind == "checkbox" and 1 or nil
			else
				info.notCheckable = 1
			end
			info.disabled = not child:IsEnabled() and 1 or nil
			if #child.children > 0 then
				info.hasArrow = 1
				info.value = child
			end
			if child.kind ~= "button" or child.callback or child.responder or #child.children == 0 then
				info.func = function()
					Respond(child)
				end
			end
			if child.tooltip then
				local title, text = CaptureTooltip(child.tooltip, child)
				info.tooltipTitle = title
				info.tooltipText = text
			end
		end
		G.UIDropDownMenu_AddButton(info, level)
	end
end

local function EnsureMenuHost()
	if not menuHost then
		menuHost = G.CreateFrame("Frame", "DCTalentsMenuHost", G.UIParent, "UIDropDownMenuTemplate")
		menuHost:Hide()
	end
	return menuHost
end

Menu = Menu or {}

function Menu.OpenDescription(root, owner, anchor)
	local host = EnsureMenuHost()
	openRoot = root
	openOwner = owner
	G.UIDropDownMenu_Initialize(host, InitializeMenu, "MENU")
	G.ToggleDropDownMenu(1, nil, host, anchor or owner or "cursor", 0, 0)
end

function Menu.IsOpenFor(owner)
	return openOwner == owner and G.DropDownList1 and G.DropDownList1:IsShown() and G.UIDROPDOWNMENU_OPEN_MENU == EnsureMenuHost()
end

function Menu.GetOpenMenu()
	return nil
end

MenuUtil = MenuUtil or {}

function MenuUtil.CreateRootMenuDescription()
	return NewDescription("root", "")
end

function MenuUtil.CreateContextMenu(owner, generator, ...)
	local root = MenuUtil.CreateRootMenuDescription()
	generator(owner, root, ...)
	Menu.OpenDescription(root, owner, "cursor")
	return root
end

function MenuUtil.HookTooltipScripts(frame, func)
	frame:HookScript("OnEnter", function(self)
		G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		func(G.GameTooltip, self)
		G.GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", function()
		G.GameTooltip:Hide()
	end)
end

MenuTemplates = MenuTemplates or {}
MenuTemplates.AttachAutoHideGearButton = function(button)
	return G.CreateFrame("Button", nil, button)
end

-- Retail DropdownButton behaviour (applied to every "DropdownButton" frame through XML.intrinsics).
DropdownButtonMixin = {}

function DropdownButtonMixin:SetupMenu(generator)
	self.menuGenerator = generator
	self:GenerateMenu()
end

function DropdownButtonMixin:GenerateMenu()
	local root = MenuUtil.CreateRootMenuDescription()
	if self.menuGenerator then
		ns.SafeCall(self.menuGenerator, self, root)
	end
	self.menuDescription = root
	self:UpdateSelectionText(root)
	return root
end

local function FindSelected(description)
	for _, child in ipairs(description.children) do
		if (child.kind == "radio" or child.kind == "checkbox") and child:IsSelected() then
			return child
		end
		local nested = FindSelected(child)
		if nested then
			return nested
		end
	end
	return nil
end

function DropdownButtonMixin:UpdateSelectionText(root)
	if not self.Text then
		return
	end
	local selected = FindSelected(root or self.menuDescription or MenuUtil.CreateRootMenuDescription())
	if selected then
		self.Text:SetText(selected.text or "")
	elseif self.defaultText then
		self.Text:SetText(self.defaultText)
	else
		self.Text:SetText("")
	end
end

function DropdownButtonMixin:Update()
	self:GenerateMenu()
end

function DropdownButtonMixin:SetDefaultText(text)
	self.defaultText = text
	self:UpdateSelectionText()
end

function DropdownButtonMixin:OverrideText(text)
	if self.Text then
		self.Text:SetText(text)
	end
end

function DropdownButtonMixin:OpenMenu()
	local root = self:GenerateMenu()
	Menu.OpenDescription(root, self, self)
end

function DropdownButtonMixin:CloseMenu()
	if Menu.IsOpenFor(self) then
		G.CloseDropDownMenus()
	end
end

function DropdownButtonMixin:IsMenuOpen()
	return Menu.IsOpenFor(self)
end

function DropdownButtonMixin:SetMenuOpen(open)
	if open then
		self:OpenMenu()
	else
		self:CloseMenu()
	end
end

function DropdownButtonMixin:HandlesGlobalMouseEvent()
	return true
end

function DropdownButtonMixin:SignalUpdate()
	self:Update()
end

DropdownButtonMixin.SetScrollMode = Nop

local function DropdownButtonOnMouseDown(self, button)
	if self.IsEnabled and not self:IsEnabled() then
		return
	end
	if self:IsMenuOpen() then
		self:CloseMenu()
	else
		self:OpenMenu()
	end
end

XML.intrinsics.dropdownbutton = {
	mixin = "DropdownButtonMixin",
	onBuilt = function(frame)
		frame:HookScript("OnMouseDown", DropdownButtonOnMouseDown)
	end,
}

-- WowStyle1DropdownTemplate: retail dark dropdown box with the text of the selected entry.
WowStyle1DropdownDCMixin = {}

function WowStyle1DropdownDCMixin:OnLoad()
	self:SetHitRectInsets(0, 0, 0, 0)
end

function WowStyle1DropdownDCMixin:SetEnabled(enabled)
	if enabled then
		self:Enable()
	else
		self:Disable()
	end
	self.Text:SetTextColor(enabled and 1 or 0.5, enabled and 1 or 0.5, enabled and 1 or 0.5)
	self.Arrow:SetDesaturated(not enabled)
end

function WowStyle1DropdownDCMixin:OnEnter()
	self.Arrow:SetAtlas("common-dropdown-a-button-hover", true)
end

function WowStyle1DropdownDCMixin:OnLeave()
	self.Arrow:SetAtlas("common-dropdown-a-button", true)
end

Template("Button", "WowStyle1DropdownTemplate", { mixin = "WowStyle1DropdownDCMixin" }, {
	Size(200, 26),
	{ tag = "Layers", children = {
		{ tag = "Layer", attr = { level = "BACKGROUND" }, children = {
			{ tag = "Texture", attr = { parentKey = "Background", atlas = "common-dropdown-textholder", setAllPoints = "true" } },
		} },
		{ tag = "Layer", attr = { level = "ARTWORK" }, children = {
			{ tag = "Texture", attr = { parentKey = "Arrow", atlas = "common-dropdown-a-button", useAtlasSize = "true" }, children = {
				{ tag = "Anchors", children = { Anchor("RIGHT", -2, -1) } },
			} },
			{ tag = "FontString", attr = { parentKey = "Text", inherits = "GameFontHighlight", justifyH = "LEFT", wordwrap = "false" }, children = {
				{ tag = "Anchors", children = { Anchor("LEFT", 10, 0), Anchor("RIGHT", -28, 0) } },
			} },
		} },
	} },
	Scripts({ OnLoad = "OnLoad", OnEnter = "OnEnter", OnLeave = "OnLeave" }),
})

-- ----------------------------------------------------------------------------
-- ScrollBox (list, linear view): only what the search preview list uses
-- ----------------------------------------------------------------------------

ScrollBoxConstants = ScrollBoxConstants or { NoScrollInterpolation = true, RetainScrollPosition = true, DiscardScrollPosition = false, UpdateQueued = false, UpdateImmediately = true }

local DataProviderMixin = {}

function CreateDataProvider(list)
	local provider = CreateFromMixins(DataProviderMixin)
	provider.collection = {}
	for _, value in ipairs(list or {}) do
		provider.collection[#provider.collection + 1] = value
	end
	return provider
end

function DataProviderMixin:Insert(...)
	for i = 1, select("#", ...) do
		self.collection[#self.collection + 1] = (select(i, ...))
	end
end

function DataProviderMixin:GetSize()
	return #self.collection
end

function DataProviderMixin:Enumerate()
	return ipairs(self.collection)
end

function DataProviderMixin:Flush()
	wipe(self.collection)
end

function DataProviderMixin:Find(index)
	return self.collection[index]
end

local LinearViewMixin = {}

function CreateScrollBoxListLinearView(top, bottom, left, right, spacing)
	local view = CreateFromMixins(LinearViewMixin)
	view.padTop, view.padBottom, view.padLeft, view.padRight = top or 0, bottom or 0, left or 0, right or 0
	view.spacing = spacing or 0
	view.extent = 0
	return view
end

function LinearViewMixin:SetElementInitializer(template, initializer)
	self.template = template
	self.initializer = initializer
end

function LinearViewMixin:SetElementExtent(extent)
	self.elementExtent = extent
end

function LinearViewMixin:GetExtent()
	return self.extent
end

WowScrollBoxListDCMixin = {}

function WowScrollBoxListDCMixin:SetView(view)
	self.view = view
	self.framePool = CreateFramePool("BUTTON", self, view.template)
end

function WowScrollBoxListDCMixin:GetView()
	return self.view
end

function WowScrollBoxListDCMixin:SetDataProvider(provider)
	self.dataProvider = provider
	self:Rebuild()
end

function WowScrollBoxListDCMixin:HasDataProvider()
	return self.dataProvider ~= nil and self.dataProvider:GetSize() > 0
end

function WowScrollBoxListDCMixin:GetDataProviderSize()
	return self.dataProvider and self.dataProvider:GetSize() or 0
end

function WowScrollBoxListDCMixin:Flush()
	self.dataProvider = nil
	if self.framePool then
		self.framePool:ReleaseAll()
	end
	self.frames = {}
	if self.view then
		self.view.extent = 0
	end
end

function WowScrollBoxListDCMixin:Rebuild()
	local view = self.view
	if not view then
		return
	end
	self.framePool:ReleaseAll()
	self.frames = {}
	local offset = view.padTop
	local previous
	for index, elementData in self.dataProvider:Enumerate() do
		local frame = self.framePool:Acquire()
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", self, "TOPLEFT", view.padLeft, -offset)
		frame:SetPoint("RIGHT", self, "RIGHT", -view.padRight, 0)
		frame:Show()
		if view.initializer then
			ns.SafeCall(view.initializer, frame, elementData)
		end
		self.frames[#self.frames + 1] = { frame = frame, data = elementData }
		offset = offset + (view.elementExtent or frame:GetHeight()) + view.spacing
		previous = frame
	end
	view.extent = offset - view.spacing + view.padBottom
end

function WowScrollBoxListDCMixin:ForEachFrame(func)
	for _, entry in ipairs(self.frames or {}) do
		if func(entry.frame, entry.data) then
			return
		end
	end
end

WowScrollBoxListDCMixin.ScrollToBegin = Nop
WowScrollBoxListDCMixin.ScrollToEnd = Nop
WowScrollBoxListDCMixin.FullUpdate = function(self)
	if self.dataProvider then
		self:Rebuild()
	end
end

Template("Frame", "WowScrollBoxList", { mixin = "WowScrollBoxListDCMixin" }, {})

-- ----------------------------------------------------------------------------
-- Systems WotLK does not have: inert frames with the retail API
-- ----------------------------------------------------------------------------

HeroTalentsContainerDCMixin = {}
function HeroTalentsContainerDCMixin:Init() end
function HeroTalentsContainerDCMixin:UpdateHeroTalentInfo() end
function HeroTalentsContainerDCMixin:UpdateHeroTalentCurrency() end
function HeroTalentsContainerDCMixin:UpdateHeroTalentButtonPosition() end
function HeroTalentsContainerDCMixin:IsHeroSpecActive() return false end
function HeroTalentsContainerDCMixin:IsPreviewingSubTree() return false end
function HeroTalentsContainerDCMixin:GetActiveSubTreeInfo() return nil end
function HeroTalentsContainerDCMixin:IsNodeInAvailableSubTree() return false end
function HeroTalentsContainerDCMixin:UpdateSearchDisplay() end
Template("Frame", "HeroTalentsContainerTemplate", { mixin = "HeroTalentsContainerDCMixin", hidden = "true" }, { Size(1, 1) })

HeroTalentsSelectionDialog = {
	IsActive = function() return false end,
	IsShown = function() return false end,
	SetCommitVisualsActive = Nop,
	SetCommitCompleteVisualsActive = Nop,
	UpdateApplyButtons = function() return false end,
	UpdateActivateButtons = Nop,
	Hide = Nop,
	DisabledOverlay = G.UIParent,
}

PvPTalentDCMixin = {}
function PvPTalentDCMixin:SetTalentFrame(talentFrame) self.talentFrame = talentFrame end
function PvPTalentDCMixin:Update() end
function PvPTalentDCMixin:UpdateTalentSlots() end
Template("Frame", "PvPTalentListTemplate", { mixin = "PvPTalentDCMixin", hidden = "true" }, { Size(1, 1) })
Template("Frame", "PvPTalentSlotTrayTemplate", { mixin = "PvPTalentDCMixin", hidden = "true" }, { Size(1, 1) })

WarmodeButtonDCMixin = {}
WarmodeButtonDCMixin.Update = Nop
Template("Button", "WarmodeButtonTemplate", { mixin = "WarmodeButtonDCMixin", hidden = "true" }, { Size(1, 1) })

ScriptAnimatedModelSceneDCMixin = {}
ScriptAnimatedModelSceneDCMixin.ClearEffects = Nop
ScriptAnimatedModelSceneDCMixin.AddEffect = function() return nil end
ScriptAnimatedModelSceneDCMixin.SetFromModelSceneID = Nop
Template("Frame", "ScriptAnimatedModelSceneTemplate", { mixin = "ScriptAnimatedModelSceneDCMixin" }, {})

MaximizeMinimizeDCMixin = {}
MaximizeMinimizeDCMixin.SetOnMaximizedCallback = Nop
MaximizeMinimizeDCMixin.SetOnMinimizedCallback = Nop
MaximizeMinimizeDCMixin.SetMinimizedCVar = Nop
MaximizeMinimizeDCMixin.SkipResetOnShow = Nop
MaximizeMinimizeDCMixin.Minimize = Nop
MaximizeMinimizeDCMixin.Maximize = Nop
Template("Frame", "MaximizeMinimizeButtonFrameTemplate", { mixin = "MaximizeMinimizeDCMixin", hidden = "true" }, { Size(1, 1) })

SpellBookFrameDCMixin = {}
SpellBookFrameDCMixin.SetMinimized = Nop
Template("Frame", "SpellBookFrameTemplate", { mixin = "SpellBookFrameDCMixin" }, {})

-- ----------------------------------------------------------------------------
-- 3.3.5 look-alikes for retail visual templates
-- ----------------------------------------------------------------------------

Template("Button", "UIPanelButtonNoTooltipTemplate", { inherits = "UIPanelButtonTemplate" }, {})
Template("Button", "MagicButtonTemplate", { inherits = "UIPanelButtonTemplate" }, { Size(80, 22) })

DialogBorderDCMixin = {}
function DialogBorderDCMixin:OnLoad()
	self:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
end
Template("Frame", "DialogBorderDarkTemplate", { mixin = "DialogBorderDCMixin", setAllPoints = "true" }, {
	Scripts({ OnLoad = "OnLoad" }),
})

-- InputScrollFrameTemplate: a scrolling multi-line edit box (retail layout: .EditBox, .CharCount).
InputScrollFrameDCMixin = {}
function InputScrollFrameDCMixin:OnLoad()
	local editBox = self.EditBox
	editBox:SetWidth(self:GetWidth() - 18)
	editBox:SetScript("OnTextChanged", function(box, userInput)
		InputScrollFrame_OnTextChanged(box)
	end)
	editBox:SetScript("OnCursorChanged", G.ScrollingEdit_OnCursorChanged)
	editBox:SetScript("OnUpdate", function(box, elapsed)
		G.ScrollingEdit_OnUpdate(box, elapsed, self)
	end)
	editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
	self:SetScript("OnMouseDown", function()
		editBox:SetFocus()
	end)
end
Template("ScrollFrame", "InputScrollFrameTemplate", { inherits = "UIPanelScrollFrameTemplate", mixin = "InputScrollFrameDCMixin" }, {
	{ tag = "ScrollChild", children = {
		{ tag = "EditBox", attr = { parentKey = "EditBox", multiLine = "true", autoFocus = "false" }, children = {
			Size(200, 60),
			{ tag = "FontString", attr = { inherits = "ChatFontNormal" } },
		} },
	} },
	{ tag = "Layers", children = {
		{ tag = "Layer", attr = { level = "OVERLAY" }, children = {
			{ tag = "FontString", attr = { parentKey = "CharCount", inherits = "GameFontDisableSmall", hidden = "true" }, children = {
				{ tag = "Anchors", children = { Anchor("BOTTOMRIGHT", -6, 0) } },
			} },
		} },
	} },
	Scripts({ OnLoad = "OnLoad" }),
})

function InputScrollFrame_OnTextChanged(editBox)
	local scrollFrame = editBox:GetParent()
	if G.ScrollingEdit_OnTextChanged then
		G.ScrollingEdit_OnTextChanged(editBox, scrollFrame)
	end
	if scrollFrame and scrollFrame.CharCount and editBox.GetMaxLetters then
		local maxLetters = editBox:GetMaxLetters()
		if maxLetters and maxLetters > 0 then
			scrollFrame.CharCount:SetText(maxLetters - editBox:GetNumLetters())
			scrollFrame.CharCount:Show()
		end
	end
end

-- Border tiles used by the search preview list: plain dark lines on 3.3.5.
for _, name in ipairs({ "!UI-Frame-LeftTile", "!UI-Frame-RightTile", "UI-Frame-BotCornerLeft", "UI-Frame-BotCornerRight", "_UI-Frame-Bot" }) do
	Template("Texture", name, {}, {
		{ tag = "Color", attr = { r = "0.12", g = "0.12", b = "0.12", a = "1" } },
	})
end

-- ----------------------------------------------------------------------------
-- Glows, tutorials, cast bar, action bar helpers
-- ----------------------------------------------------------------------------

GlowEmitterMixin = { Anims = { GreenGlow = 1, NPE_RedButton_GreenGlow = 2, FadeAnim = 3, FaintFadeAnim = 4 } }

local glowTextures = setmetatable({}, { __mode = "k" })

GlowEmitterFactory = {}

function GlowEmitterFactory:Show(frame, anim, offsetX, offsetY, width, height)
	local glow = glowTextures[frame]
	if not glow then
		glow = G.CreateFrame("Frame", nil, frame)
		glow:SetFrameLevel(frame:GetFrameLevel() + 5)
		local texture = glow:CreateTexture(nil, "OVERLAY")
		texture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Glow")
		texture:SetTexCoord(0, 0.75, 0, 0.609375)
		texture:SetBlendMode("ADD")
		texture:SetVertexColor(0.3, 1, 0.3)
		texture:SetAllPoints(glow)
		glow.texture = texture
		local group = glow:CreateAnimationGroup()
		local fade = group:CreateAnimation("Alpha")
		fade:SetChange(-0.6)
		fade:SetDuration(0.8)
		group:SetLooping("BOUNCE")
		glow.group = group
		glowTextures[frame] = glow
	end
	glow:ClearAllPoints()
	glow:SetPoint("TOPLEFT", frame, "TOPLEFT", -12, 10)
	glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 12, -10)
	glow:Show()
	if not glow.group:IsPlaying() then
		glow.group:Play()
	end
end

function GlowEmitterFactory:Hide(frame)
	local glow = glowTextures[frame]
	if glow then
		glow.group:Stop()
		glow:Hide()
	end
end

function GlowEmitterFactory:SetHeight() end

HelpTip = {
	Show = Nop,
	Hide = Nop,
	HideAll = Nop,
	HideAllSystem = Nop,
	IsShowing = function() return false end,
	Acknowledge = Nop,
	ButtonStyle = { None = 0, Close = 1, Okay = 2, GotIt = 3, Next = 4 },
	Point = { TopEdgeCenter = 1, LeftEdgeTop = 2, RightEdgeCenter = 3, BottomEdgeCenter = 4, LeftEdgeCenter = 5 },
	Alignment = { Left = 1, Center = 2, Right = 3, Top = 4, Bottom = 5 },
}

OverlayPlayerCastingBarFrame = {
	StartReplacingPlayerBarAt = Nop,
	EndReplacingPlayerBar = Nop,
	IsShown = function() return false end,
}

AssistedCombatManager = {
	AddSpellTooltipLine = Nop,
	IsAssistedHighlightActive = function() return false end,
}

ClearOnBarHighlightMarks = Nop
UpdateOnBarHighlightMarksBySpell = Nop
ActionBarController_UpdateAllSpellHighlights = Nop
GAME_TOOLTIP_BACKDROP_STYLE_CLASS_TALENT = GAME_TOOLTIP_BACKDROP_STYLE_CLASS_TALENT or {}
LIGHTBLUE_FONT_COLOR = LIGHTBLUE_FONT_COLOR or { r = 0.53, g = 0.67, b = 1, a = 1 }

ActionButtonUtil = ActionButtonUtil or {}
ActionButtonUtil.ActionBarActionStatus = ActionButtonUtil.ActionBarActionStatus or {
	NotMissing = 1,
	MissingFromAllBars = 2,
	OnInactiveBonusBar = 3,
	OnDisabledActionBar = 4,
}
function ActionButtonUtil.GetActionBarStatusForSpell(spellID)
	local status = ActionButtonUtil.ActionBarActionStatus
	if not spellID or C_Spell.IsSpellPassive(spellID) then
		return status.NotMissing
	end
	return C_ActionBar.IsOnBarOrSpecialBar(spellID) and status.NotMissing or status.MissingFromAllBars
end
function ActionButtonUtil.GetActionBarStatusForPetAction()
	return ActionButtonUtil.ActionBarActionStatus.NotMissing
end
function ActionButtonUtil.GetActionBarStatusForFlyout()
	return ActionButtonUtil.ActionBarActionStatus.NotMissing
end

-- Blizzard_SharedXML/SharedUIPanelTemplates.lua (only its XML is converted; UIButtonTemplate needs this).
ButtonControllerMixin = ButtonControllerMixin or {}

function ButtonControllerMixin:OnLoad()
	if self:GetParent().InitButton then
		self:GetParent():InitButton()
	end
end

function ButtonControllerMixin:OnShow()
	if self:GetParent().UpdateButton then
		self:GetParent():UpdateButton()
	end
end

PlayerSpellsMicroButton = {
	EvaluateAlertVisibility = Nop,
}

PlayerSpellsUtil = PlayerSpellsUtil or {}
-- Pet and Glyphs are ours (they replace the spellbook tab).
PlayerSpellsUtil.FrameTabs = PlayerSpellsUtil.FrameTabs or { ClassSpecializations = 1, ClassTalents = 2, SpellBook = 3, Glyphs = 100, Pet = 101 }

-- StaticPopup text input used by retail's generic "new entry" flow.
local INPUT_POPUP = "DC_TALENTS_GENERIC_INPUT"
local inputCallback
G.StaticPopupDialogs[INPUT_POPUP] = {
	text = "%s",
	button1 = G.ACCEPT,
	button2 = G.CANCEL,
	hasEditBox = 1,
	maxLetters = 64,
	OnAccept = function(self)
		local editBox = self.editBox or G[self:GetName() .. "EditBox"]
		local callback = inputCallback
		inputCallback = nil
		if callback and editBox then
			ns.SafeCall(callback, editBox:GetText())
		end
	end,
	EditBoxOnEnterPressed = function(editBox)
		local parent = editBox:GetParent()
		local callback = inputCallback
		inputCallback = nil
		if callback then
			ns.SafeCall(callback, editBox:GetText())
		end
		parent:Hide()
	end,
	EditBoxOnEscapePressed = function(editBox)
		editBox:GetParent():Hide()
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

function StaticPopup_ShowCustomGenericInputBox(popupInfo)
	inputCallback = popupInfo.callback
	G.StaticPopup_Show(INPUT_POPUP, popupInfo.text or "")
end
