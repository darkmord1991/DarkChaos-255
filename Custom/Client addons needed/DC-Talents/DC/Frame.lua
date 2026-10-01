--[[
	DC-Talents - the window and how it is opened.

	PlayerSpellsFrame and the loadout dialogs are built the first time the window opens (DC/Early.lua
	defers them), the way retail loads Blizzard_PlayerSpells on demand. This file also

	  * fits the 1618 x 883 retail frame to the 3.3.5 screen (the retail layout is never squeezed,
	    the whole window is scaled),
	  * takes the talent key binding and the micro button (Shift, or the setting, opens the stock frame),
	  * closes the window with Escape,
	  * provides the Glyphs tab (the stock glyph frame, hosted in the retail window),
	  * wires start-up: saved variables, the server handshake and the one-time DC-QOS migration.
]]

local addonName, ns = ...
setfenv(1, ns.env)

local G = ns.realG
local XML = ns.XML
local L = ns.L
local UI = ns.UI

local FRAME_WIDTH, FRAME_HEIGHT = 1618, 883
-- The tab strip hangs under the frame.
local TAB_STRIP_HEIGHT = 34
local SCREEN_MARGIN_X = 40
-- Kept clear at the top (DC-InfoBar) and at least at the bottom; a little air between bands.
local TOP_RESERVE = 26
local MIN_BOTTOM_RESERVE = 60
local BAND_MARGIN = 8
-- The window's share of the free band when no /talents scale is set.
local DEFAULT_SIZE = 0.9
-- Stock bars along the bottom edge; the window stays above the highest one that is shown.
local BOTTOM_BARS = { "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "ShapeshiftBarFrame",
	"PetActionBarFrame", "PossessBarFrame", "VehicleMenuBar" }
local SHOW_TALENT_LEVEL = G.SHOW_TALENT_LEVEL or 10
local GLYPH_LEVEL = 15

-- Dialogs first: the talents tab looks them up while it loads.
local DEFERRED = {
	"ClassTalentLoadoutImportDialog",
	"ClassTalentLoadoutEditDialog",
	"ClassTalentLoadoutCreateDialog",
	"PlayerSpellsFrame",
}

local function Settings()
	local db = ns.GetDB()
	return db and db.settings or {}
end
UI.Settings = Settings

local function Print(message)
	if G.DEFAULT_CHAT_FRAME then
		G.DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00DC-Talents|r: " .. tostring(message))
	end
end
UI.Print = Print

-- ----------------------------------------------------------------------------
-- Creation and placement
-- ----------------------------------------------------------------------------

function UI.GetFrame()
	if XML.IsDeferredPending("PlayerSpellsFrame") then
		return nil
	end
	return PlayerSpellsFrame
end

local creationFailed = false

function UI.EnsureFrame()
	if not XML.IsDeferredPending("PlayerSpellsFrame") then
		return PlayerSpellsFrame
	end
	if creationFailed then
		return nil
	end
	-- Above the action bars (MEDIUM, like the stock panels) so they cannot draw over the window;
	-- the loadout dialogs keep their DIALOG strata, tooltips and menus stay on top.
	XML.SetDeferredAttribute("PlayerSpellsFrame", "frameStrata", "HIGH")
	for _, name in ipairs(DEFERRED) do
		local ok, err = pcall(XML.CreateDeferred, name)
		if not ok then
			creationFailed = true
			G.geterrorhandler()(("DC-Talents: building %s failed: %s"):format(name, tostring(err)))
			return nil
		end
	end

	local frame = PlayerSpellsFrame
	if not frame then
		creationFailed = true
		return nil
	end
	frame:SetClampedToScreen(true)
	G.tinsert(G.UISpecialFrames, "PlayerSpellsFrame")
	for _, name in ipairs({ "ClassTalentLoadoutImportDialog", "ClassTalentLoadoutEditDialog", "ClassTalentLoadoutCreateDialog" }) do
		local dialog = ns.env[name]
		if dialog then
			dialog:SetScale(frame:GetScale())
		end
	end
	return frame
end

-- Height (UIParent units) taken by the bars along the bottom edge.
local function BottomReserve()
	local uiScale = G.UIParent:GetEffectiveScale()
	local reserve = MIN_BOTTOM_RESERVE
	for _, name in ipairs(BOTTOM_BARS) do
		local bar = G[name]
		if bar and bar:IsVisible() then
			local top = bar:GetTop()
			if top then
				reserve = math.max(reserve, top * bar:GetEffectiveScale() / uiScale)
			end
		end
	end
	return reserve
end

-- The retail window is laid out for a 1618 x 883 area; scale the whole window instead of the layout.
-- It fits the band between the top info bar and the action bars (tab strip included), takes
-- DEFAULT_SIZE of it unless /talents scale says otherwise, and is centred in it.
function UI.FitToScreen(frame)
	frame = frame or UI.GetFrame()
	if not frame then
		return
	end
	local uiWidth, uiHeight = G.UIParent:GetWidth(), G.UIParent:GetHeight()
	local band = uiHeight - TOP_RESERVE - BottomReserve() - 2 * BAND_MARGIN
	local fit = math.min(1, band / (FRAME_HEIGHT + TAB_STRIP_HEIGHT), (uiWidth - SCREEN_MARGIN_X) / FRAME_WIDTH)
	local userScale = tonumber(Settings().scale) or DEFAULT_SIZE
	local scale = math.max(0.3, fit * userScale)
	frame:SetScale(scale)

	local used = (FRAME_HEIGHT + TAB_STRIP_HEIGHT) * scale
	local topGap = TOP_RESERVE + BAND_MARGIN + math.max(0, (band - used) / 2)
	frame:ClearAllPoints()
	frame:SetPoint("TOP", G.UIParent, "TOP", 0, -topGap / scale)

	-- The loadout dialogs are UIParent children: give them the window's scale so they match it.
	for _, name in ipairs({ "ClassTalentLoadoutImportDialog", "ClassTalentLoadoutEditDialog", "ClassTalentLoadoutCreateDialog" }) do
		local dialog = ns.env[name]
		if dialog and dialog.SetScale then
			dialog:SetScale(scale)
		end
	end
end

-- ----------------------------------------------------------------------------
-- Opening
-- ----------------------------------------------------------------------------

function UI.OpenStockFrame()
	if G.TalentFrame_LoadUI then
		G.TalentFrame_LoadUI()
	end
	if G.PlayerTalentFrame_Toggle then
		G.PlayerTalentFrame_Toggle(false, G.GetActiveTalentGroup())
	end
end

function UI.Open(frameTab)
	if G.UnitLevel("player") < SHOW_TALENT_LEVEL then
		return false
	end
	local frame = UI.EnsureFrame()
	if not frame then
		UI.OpenStockFrame()
		return false
	end
	UI.FitToScreen(frame)
	if not frame:IsShown() then
		ShowUIPanel(frame)
	end
	if frameTab then
		frame:TrySetTab(frameTab)
	end
	return true
end

function UI.Close()
	local frame = UI.GetFrame()
	if frame and frame:IsShown() then
		HideUIPanel(frame)
	end
end

-- Toggles the window on the given tab (or the talents tab); switching tabs keeps it open.
function UI.Toggle(frameTab)
	frameTab = frameTab or PlayerSpellsUtil.FrameTabs.ClassTalents
	local frame = UI.GetFrame()
	if frame and frame:IsShown() and frame:IsFrameTabActive(frameTab) then
		UI.Close()
		return
	end
	UI.Open(frameTab)
end

-- The N key and the micro button both call the global ToggleTalentFrame. DC-QOS (loaded first,
-- see OptionalDeps) wraps it too; ours is the outer wrapper, and Shift falls through to the one
-- underneath, which ends at the stock frame.
local previousToggleTalentFrame = G.ToggleTalentFrame
G.ToggleTalentFrame = function(...)
	if Settings().replaceStockFrame == false or G.IsShiftKeyDown() then
		if previousToggleTalentFrame then
			return previousToggleTalentFrame(...)
		end
		return UI.OpenStockFrame()
	end
	UI.Toggle(PlayerSpellsUtil.FrameTabs.ClassTalents)
end

-- Keep the micro button pressed while our window is open (the stock code only knows PlayerTalentFrame).
if G.UpdateMicroButtons then
	G.hooksecurefunc("UpdateMicroButtons", function()
		local frame = UI.GetFrame()
		if frame and frame:IsShown() and G.TalentMicroButton then
			G.TalentMicroButton:SetButtonState("PUSHED", 1)
		end
	end)
end

-- ----------------------------------------------------------------------------
-- Copy dialog (retail CopyToClipboard: 3.3.5 addons cannot write the clipboard)
-- ----------------------------------------------------------------------------

local COPY_POPUP = "DC_TALENTS_COPY"
local copyText = ""

G.StaticPopupDialogs[COPY_POPUP] = {
	text = L.COPY_DIALOG_TITLE,
	button1 = G.OKAY or G.CLOSE,
	hasEditBox = 1,
	hasWideEditBox = 1,
	maxLetters = 0,
	maxBytes = 0,
	OnShow = function(self)
		local editBox = self.wideEditBox or G[self:GetName() .. "WideEditBox"]
		if editBox then
			editBox:SetText(copyText)
			editBox:SetFocus()
			editBox:HighlightText()
		end
	end,
	OnHide = function(self)
		local editBox = self.wideEditBox or G[self:GetName() .. "WideEditBox"]
		if editBox then
			editBox:SetText("")
		end
		if G.ChatEdit_FocusActiveWindow then
			G.ChatEdit_FocusActiveWindow()
		end
	end,
	EditBoxOnEnterPressed = function(self)
		self:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end,
	EditBoxOnTextChanged = function(self)
		-- Read-only: typing restores the string.
		if self:GetText() ~= copyText then
			self:SetText(copyText)
			self:HighlightText()
		end
	end,
	timeout = 0,
	exclusive = 1,
	whileDead = 1,
	hideOnEscape = 1,
}

function UI.ShowCopyDialog(text)
	copyText = text or ""
	G.StaticPopup_Show(COPY_POPUP)
end

-- ----------------------------------------------------------------------------
-- Glyphs tab: the stock glyph frame, borrowed while the tab is shown
-- ----------------------------------------------------------------------------

local GLYPH_SCALE = 1.45

local function RestoreGlyphFrame(glyphFrame)
	glyphFrame:Hide()
	glyphFrame:ClearAllPoints()
	glyphFrame:SetFrameStrata(glyphFrame.__dcStrata or "MEDIUM")
	if G.PlayerTalentFrame then
		-- Where Blizzard_GlyphUI puts it once Blizzard_TalentUI is loaded.
		glyphFrame:SetParent(G.PlayerTalentFrame)
		glyphFrame:SetAllPoints()
		glyphFrame:SetScale(1)
		glyphFrame:SetFrameLevel(G.PlayerTalentFrame:GetFrameLevel() + 4)
	else
		glyphFrame:SetParent(G.UIParent)
		glyphFrame:SetPoint("TOPLEFT")
		glyphFrame:SetScale(1)
	end
end

local function BorrowGlyphFrame(page)
	if G.GlyphFrame_LoadUI then
		G.GlyphFrame_LoadUI()
	end
	local glyphFrame = G.GlyphFrame
	if not glyphFrame then
		return false
	end
	-- The stock glyph frame shows PlayerTalentFrame.talentGroup; follow the active group here.
	if G.PlayerTalentFrame and not G.PlayerTalentFrame:IsShown() then
		G.PlayerTalentFrame.talentGroup = G.GetActiveTalentGroup()
		G.PlayerTalentFrame.pet = false
	end
	glyphFrame.__dcStrata = glyphFrame.__dcStrata or glyphFrame:GetFrameStrata()
	glyphFrame:SetParent(page)
	glyphFrame:SetFrameStrata(page:GetFrameStrata())
	glyphFrame:ClearAllPoints()
	glyphFrame:SetScale(GLYPH_SCALE)
	-- Centre the parchment (its right 30 px / bottom 70 px are the old panel's shadow).
	glyphFrame:SetPoint("CENTER", page, "CENTER", 15 / GLYPH_SCALE, 10 / GLYPH_SCALE)
	glyphFrame:SetFrameLevel(page:GetFrameLevel() + 5)
	if G.GlyphFrameTitleText then
		G.GlyphFrameTitleText:SetText(G.GLYPHS or L.TAB_GLYPHS)
	end
	-- The glyph art has holes for PlayerTalentFrame's portrait and close button (Blizzard_TalentUI.xml:
	-- portrait 60 x 60 at TOPLEFT 7,-6; close button centred at TOPRIGHT -44,-25): fill both.
	page.Portrait:ClearAllPoints()
	page.Portrait:SetPoint("TOPLEFT", glyphFrame, "TOPLEFT", 7 * GLYPH_SCALE, -6 * GLYPH_SCALE)
	G.SetPortraitTexture(page.Portrait, "player")
	page.Portrait:Show()
	page.CloseButton:ClearAllPoints()
	page.CloseButton:SetPoint("CENTER", glyphFrame, "TOPRIGHT", -44, -25)
	page.CloseButton:SetFrameLevel(glyphFrame:GetFrameLevel() + 5)
	page.CloseButton:Show()
	glyphFrame:Show()
	if G.GlyphFrame_Update then
		G.GlyphFrame_Update()
	end
	page.borrowed = glyphFrame
	return true
end

-- Loadout glyphs. A saved set lists, per kind, the glyph of each socket of that kind in socket order
-- (0 = empty). Placing a glyph means using the glyph item, which needs a hardware event, so the
-- button applies one glyph per click (DC-QOS's rule).
function UI.GetLoadoutGlyphDiff(configID)
	local loadout = ns.Loadouts.GetByConfigID(configID)
	if not loadout or type(loadout.glyphs) ~= "table" then
		return nil
	end
	local sockets = { major = {}, minor = {} }
	for socket = 1, (G.GetNumGlyphSockets and G.GetNumGlyphSockets() or 6) do
		local enabled, glyphType, spellID = G.GetGlyphSocketInfo(socket)
		local list = (glyphType == 1) and sockets.major or sockets.minor
		list[#list + 1] = { socket = socket, enabled = enabled, spellID = spellID }
	end
	local diff = {}
	for _, kind in ipairs({ "major", "minor" }) do
		local saved = loadout.glyphs[kind] or {}
		for index, slot in ipairs(sockets[kind]) do
			local wanted = tonumber(saved[index]) or 0
			if wanted ~= 0 and slot.enabled and slot.spellID ~= wanted then
				diff[#diff + 1] = { socket = slot.socket, spellID = wanted, name = G.GetSpellInfo(wanted) }
			end
		end
	end
	return diff, loadout
end

function UI.ApplyNextLoadoutGlyph(configID)
	local diff = UI.GetLoadoutGlyphDiff(configID)
	local entry = diff and diff[1]
	if not entry then
		return false
	end
	if not entry.name then
		Print(L.GLYPH_UNKNOWN:format(entry.spellID))
		return false
	end
	for bag = 0, 4 do
		for slot = 1, (G.GetContainerNumSlots(bag) or 0) do
			local link = G.GetContainerItemLink(bag, slot)
			if link and G.GetItemInfo(link) == entry.name then
				G.UseContainerItem(bag, slot)
				if G.PlaceGlyphInSocket then
					G.PlaceGlyphInSocket(entry.socket)
				end
				return true
			end
		end
	end
	Print(L.GLYPH_MISSING:format(entry.name))
	return false
end

local function SelectedLoadoutConfigID()
	return ns.Loadouts.GetLastSelected(G.GetActiveTalentGroup())
end

local function UpdateLoadoutGlyphs(page)
	local configID = SelectedLoadoutConfigID()
	local diff, loadout = UI.GetLoadoutGlyphDiff(configID)
	if not loadout then
		page.LoadoutStatus:SetText(L.GLYPHS_NO_LOADOUT)
		page.ApplyGlyphsButton:Disable()
	elseif #diff > 0 then
		page.LoadoutStatus:SetText(L.GLYPHS_LOADOUT_STATUS:format(loadout.name, #diff))
		page.ApplyGlyphsButton:Enable()
	else
		page.LoadoutStatus:SetText(L.GLYPHS_LOADOUT_MATCH:format(loadout.name))
		page.ApplyGlyphsButton:Disable()
	end
end

-- After a loadout is loaded (DC/Traits.lua C_ClassTalents.LoadConfig): point out glyph differences.
ns.OnLoadoutLoaded = function(configID)
	local diff, loadout = UI.GetLoadoutGlyphDiff(configID)
	if loadout and diff and #diff > 0 then
		Print(L.GLYPHS_DIFFER_NOTICE:format(#diff, loadout.name))
	end
end

-- The talents tab's background for the active group's primary tree.
local function UpdateGlyphPageArt(page, playerSpellsFrame)
	local talents = playerSpellsFrame.TalentsFrame
	local specID = talents and talents:GetSpecID()
	local visuals = specID and ClassTalentUtil.GetVisualsForSpecID(specID)
	if visuals and visuals.background and ns.Atlas.Apply(page.Art, visuals.background, true) then
		page.Art:Show()
	else
		page.Art:Hide()
	end
end

function UI.CreateGlyphTab(playerSpellsFrame)
	local page = G.CreateFrame("Frame", "DCTalentsGlyphPage", playerSpellsFrame)
	page:SetSize(1612, 856)
	page:SetPoint("BOTTOM", playerSpellsFrame, "BOTTOM", 0, 4)
	page:SetFrameLevel(ns.Engine.MapFrameLevel(100))
	page:Hide()

	page.Background = page:CreateTexture(nil, "BACKGROUND")
	page.Background:SetAllPoints()
	page.Background:SetTexture(0.04, 0.04, 0.05, 1)

	-- The talents tab's look: the class art over retail's bottom bar (1612 x 774 + 1612 x 82 = the page).
	page.BottomBar = page:CreateTexture(nil, "BORDER")
	page.BottomBar:SetPoint("BOTTOM")
	ns.Atlas.Apply(page.BottomBar, "talents-background-bottombar", true)
	page.Art = page:CreateTexture(nil, "BORDER")
	page.Art:SetPoint("BOTTOM", page.BottomBar, "TOP")

	page.Portrait = page:CreateTexture(nil, "ARTWORK")
	page.Portrait:SetSize(60 * GLYPH_SCALE, 60 * GLYPH_SCALE)
	page.Portrait:Hide()

	page.CloseButton = G.CreateFrame("Button", nil, page, "UIPanelCloseButton")
	page.CloseButton:SetScale(GLYPH_SCALE)
	page.CloseButton:SetScript("OnClick", function()
		UI.Close()
	end)
	page.CloseButton:Hide()

	page.Message = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	page.Message:SetPoint("CENTER")
	page.Message:Hide()

	page.LoadoutStatus = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	page.LoadoutStatus:SetPoint("BOTTOM", page, "BOTTOM", 0, 50)

	page.ApplyGlyphsButton = G.CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	page.ApplyGlyphsButton:SetSize(200, 26)
	page.ApplyGlyphsButton:SetPoint("BOTTOM", page, "BOTTOM", 0, 14)
	page.ApplyGlyphsButton:SetText(L.GLYPHS_APPLY)
	page.ApplyGlyphsButton:SetScript("OnClick", function()
		UI.ApplyNextLoadoutGlyph(SelectedLoadoutConfigID())
		UpdateLoadoutGlyphs(page)
	end)

	for _, event in ipairs({ "GLYPH_ADDED", "GLYPH_REMOVED", "GLYPH_UPDATED" }) do
		page:RegisterEvent(event)
	end
	page:SetScript("OnEvent", function(self)
		if self:IsShown() then
			UpdateLoadoutGlyphs(self)
		end
	end)

	page:SetScript("OnShow", function(self)
		UpdateGlyphPageArt(self, playerSpellsFrame)
		if G.UnitLevel("player") >= GLYPH_LEVEL and BorrowGlyphFrame(self) then
			self.Message:Hide()
		else
			self.Message:SetText(L.GLYPHS_LOCKED:format(GLYPH_LEVEL))
			self.Message:Show()
		end
		UpdateLoadoutGlyphs(self)
	end)
	page:SetScript("OnHide", function(self)
		self.Portrait:Hide()
		self.CloseButton:Hide()
		if self.borrowed then
			RestoreGlyphFrame(self.borrowed)
			self.borrowed = nil
		end
	end)
	return page
end

-- ----------------------------------------------------------------------------
-- Diagnostics (/talents debug): what the client made of the talents tab's layering and gates
-- ----------------------------------------------------------------------------

local function DescribeRect(region)
	local left, bottom = region:GetLeft(), region:GetBottom()
	if not left or not bottom then
		return "no rect"
	end
	return ("%.0f,%.0f %.0fx%.0f"):format(left, bottom, region:GetWidth() or 0, region:GetHeight() or 0)
end

local function Flag(value)
	return value and "y" or "n"
end

function UI.PrintDiagnostics()
	local frame = UI.GetFrame()
	if not frame then
		Print("debug: the window has not been opened yet")
		return
	end
	local talents = frame.TalentsFrame
	Print(("debug: window level %d %s, talents %d (visible %s), buttons parent %d; level probe %s"):format(
		frame:GetFrameLevel(), frame:GetFrameStrata(), talents:GetFrameLevel(), Flag(talents:IsVisible()),
		talents.ButtonsParent:GetFrameLevel(), tostring(ns.Engine.MAX_FRAME_LEVEL)))

	local treeInfo = talents.talentTreeInfo
	local gates = treeInfo and treeInfo.gates or {}
	Print(("debug: tree %s, %d gates in the tree info, %d gate frames active"):format(
		tostring(talents:GetTalentTreeID()), #gates, talents.gatePool:GetNumActive()))
	-- The gate retail would show per tree: its first unmet one.
	local reported = {}
	for _, gateInfo in ipairs(gates) do
		local condInfo = talents:GetAndCacheCondInfo(gateInfo.conditionID)
		local currency = condInfo and condInfo.traitCurrencyID or 0
		if not reported[currency] and not (condInfo and condInfo.isMet) then
			reported[currency] = true
			local button = talents:GetTalentButtonByNodeID(gateInfo.topLeftNodeID)
			Print(("  condition %d: info %s, missing %s; first button %s, visible %s"):format(gateInfo.conditionID,
				Flag(condInfo), tostring(condInfo and condInfo.spentAmountRequired), Flag(button),
				Flag(button and button:IsVisible())))
		end
	end
	for gate in talents.gatePool:EnumerateActive() do
		Print(("  gate %s: shown %s visible %s level %d %s alpha %s rect %s | lock shown %s %s tex %s | text shown %s '%s' %s"):format(
			tostring(gate.condInfo and gate.condInfo.condID), Flag(gate:IsShown()), Flag(gate:IsVisible()),
			gate:GetFrameLevel(), gate:GetFrameStrata(), tostring(gate:GetEffectiveAlpha()), DescribeRect(gate),
			Flag(gate.LockIcon:IsShown()), DescribeRect(gate.LockIcon), tostring(gate.LockIcon:GetTexture()),
			Flag(gate.GateText:IsShown()), tostring(gate.GateText:GetText()), DescribeRect(gate.GateText)))
	end
	local display = talents.ClassCurrencyDisplay
	Print(("debug: points counter shown %s visible %s level %d rect %s '%s %s'"):format(Flag(display:IsShown()),
		Flag(display:IsVisible()), display:GetFrameLevel(), DescribeRect(display),
		tostring(display.CurrencyAmount:GetText()), tostring(display.CurrencyLabel:GetText())))
end

-- ----------------------------------------------------------------------------
-- Slash command
-- ----------------------------------------------------------------------------

local function SlashHandler(message)
	local command, rest = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
	command = command and command:lower() or ""
	if command == "" then
		UI.Toggle(PlayerSpellsUtil.FrameTabs.ClassTalents)
	elseif command == "spec" or command == "specs" then
		UI.Toggle(PlayerSpellsUtil.FrameTabs.ClassSpecializations)
	elseif command == "glyph" or command == "glyphs" then
		UI.Toggle(PlayerSpellsUtil.FrameTabs.Glyphs)
	elseif command == "classic" or command == "stock" then
		UI.OpenStockFrame()
	elseif command == "scale" then
		local value = tonumber(rest)
		local settings = Settings()
		-- The share of the space between the info bar and the action bars the window takes.
		if rest == "auto" or rest == "" then
			settings.scale = nil
		elseif value and value >= 0.5 and value <= 1 then
			settings.scale = value
		else
			Print("/talents scale <0.5 - 1 | auto>  (1 = all the space above the action bars)")
			return
		end
		UI.FitToScreen()
		Print(("scale: %s"):format(settings.scale and tostring(settings.scale) or ("auto (" .. DEFAULT_SIZE .. ")")))
	elseif command == "replace" then
		local settings = Settings()
		settings.replaceStockFrame = settings.replaceStockFrame == false
		Print(("%s: %s"):format(L.SETTING_REPLACE, settings.replaceStockFrame and (G.YES or "yes") or (G.NO or "no")))
	elseif command == "debug" then
		UI.PrintDiagnostics()
	elseif command == "server" then
		local hello = ns.Server.state.hello
		if hello then
			Print(("server module v%s, free respec: %s, pet builds: %s"):format(tostring(hello.v), tostring(hello.freeRespec), tostring(hello.pet)))
		else
			Print("server module: not answering (additions only)")
			ns.Server.SendHello()
		end
	else
		Print(L.SLASH_HELP)
	end
end

G.SLASH_DCTALENTS1 = "/talents"
G.SLASH_DCTALENTS2 = "/dctalents"
G.SlashCmdList.DCTALENTS = SlashHandler

-- ----------------------------------------------------------------------------
-- Start-up
-- ----------------------------------------------------------------------------

local function TryMigrate(attempt)
	if ns.Loadouts.MigrateFromDCQoS() == 0 and (G.GetNumTalentTabs(false, false) or 0) == 0 and attempt < 10 then
		-- Talent data arrives a moment after login; try again shortly.
		G.C_Timer.After(2, function()
			TryMigrate(attempt + 1)
		end)
	end
end

local startup = G.CreateFrame("Frame")
startup:RegisterEvent("ADDON_LOADED")
startup:RegisterEvent("PLAYER_ENTERING_WORLD")
startup:RegisterEvent("DISPLAY_SIZE_CHANGED")
startup:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == addonName then
			ns.Loadouts.OnVariablesLoaded()
			ns.Server.Initialize()
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		ns.Server.SendHello()
		TryMigrate(1)
	else
		-- The screen size changed while the window is open (every open re-fits too).
		local frame = UI.GetFrame()
		if frame and frame:IsShown() then
			UI.FitToScreen(frame)
		end
	end
end)
