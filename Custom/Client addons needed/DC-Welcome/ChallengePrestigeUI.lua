--[[
	DC-Welcome ChallengePrestigeUI.lua
	Lightweight UI wrapper for the server-side Challenge Mode Manager gossip.

	Goals (per DarkChaos-255 spec):
	- Two tabs: Challenge Modes + Prestige
	- Shows information like the gossip-based Challenge Mode Manager
	- Allows selecting/confirming challenge modes and prestige directly from the UI
	- Automatically opens when interacting with the Challenge Mode Manager gameobject

	Implementation notes:
	- This does NOT re-implement server logic. It mirrors the current gossip state and
	  drives it by calling SelectGossipOption(index).
	- Detection is based on the manager's unique title line:
	  "=== Challenge Mode Manager ===".

	WoW client: 3.3.5 (Interface 30300)
]]

local addonName = "DC-Welcome"
DCWelcome = DCWelcome or {}

local UI = {}
DCWelcome.ChallengePrestigeUI = UI

-- =============================================================================
-- Constants
-- =============================================================================

local FRAME_WIDTH = 860
local FRAME_HEIGHT = 560
local TAB_HEIGHT = 26
local TAB_WIDTH = 150

local LEFT_WIDTH = 255
local RIGHT_WIDTH = 545
local CONTENT_HEIGHT = 430
local MODE_BUTTON_WIDTH = 108

local MODE_VISUAL_STATE = {
	active = {
		label = "|cff54ff9aACTIVE|r",
		bg = { 0.05, 0.20, 0.11, 0.45 },
		accent = { 0.36, 0.95, 0.56, 0.95 },
		edge = { 0.28, 0.78, 0.46, 0.95 },
		buttonText = { 0.80, 1.00, 0.86 },
	},
	available = {
		label = "|cff7ad5ffAVAILABLE|r",
		bg = { 0.06, 0.12, 0.22, 0.42 },
		accent = { 0.42, 0.76, 1.00, 0.95 },
		edge = { 0.32, 0.62, 0.92, 0.95 },
		buttonText = { 0.82, 0.92, 1.00 },
	},
	conditional = {
		label = "|cffffcb71CONDITIONAL|r",
		bg = { 0.21, 0.15, 0.05, 0.38 },
		accent = { 0.95, 0.75, 0.30, 0.92 },
		edge = { 0.82, 0.64, 0.26, 0.92 },
		buttonText = { 1.00, 0.88, 0.62 },
	},
	locked = {
		label = "|cffff8787LOCKED|r",
		bg = { 0.16, 0.07, 0.07, 0.32 },
		accent = { 0.86, 0.44, 0.44, 0.90 },
		edge = { 0.72, 0.34, 0.34, 0.90 },
		buttonText = { 0.95, 0.72, 0.72 },
	},
}

local MANAGER_DETECT_TEXT = "=== Challenge Mode Manager ==="
local MANAGER_SIGNATURES = {
	MANAGER_DETECT_TEXT,
	"Return to mode selection",
	"I want to activate this mode",
	"CHALLENGE ACTIVATED",
	"FINAL CONFIRMATION",
	"RANDOM CHALLENGE MODE",
	"Prestige Overview",
	"Prestige Warning",
	"Begin your next prestige",
	"Prestige Reset",
}

-- =============================================================================
-- State
-- =============================================================================

UI.frame = nil
UI.currentTab = "challenge" -- "overview" | "challenge" | "prestige"
UI._gossipHidden = false
UI._pendingUpdate = false
UI.confirmationStep = 0 -- 0: none, 1: confirming
UI.confirmationText = ""

-- =============================================================================
-- Helpers
-- =============================================================================

local function SafeLower(s)
	if type(s) ~= "string" then
		return ""
	end
	return string.lower(s)
end

local function StripColorCodes(s)
	if type(s) ~= "string" then
		return ""
	end

	-- Remove WoW color escape sequences.
	s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
	s = string.gsub(s, "|r", "")
	return s
end

local function IsDecorativeOption(text)
	local plain = SafeLower(StripColorCodes(text))

	if plain == "" then
		return true
	end

	if string.find(plain, "===", 1, true) then
		return true
	end

	if string.find(plain, "---", 1, true) then
		return true
	end

	if string.find(plain, "select a mode to view details", 1, true) then
		return true
	end

	return false
end

local function IsUnclickableStatus(text)
	local plain = SafeLower(StripColorCodes(text))

	-- The server adds informational/no-op lines that look clickable.
	if string.find(plain, "(active)", 1, true) then
		return true
	end
	if string.find(plain, "unavailable", 1, true) then
		return true
	end
	if string.find(plain, "included in iron man", 1, true) then
		return true
	end
	if string.find(plain, "another xp mode is active", 1, true) then
		return true
	end
	if string.find(plain, "conflicts with active", 1, true) then
		return true
	end
	if string.find(plain, "cannot be enabled", 1, true) then
		return true
	end

	return false
end

local function IsModeOptionActionable(text)
	if type(text) ~= "string" then
		return false
	end

	if not (string.find(text, "[", 1, true) and string.find(text, "]", 1, true)) then
		return false
	end

	if IsDecorativeOption(text) or IsUnclickableStatus(text) then
		return false
	end

	return true
end

local function BuildModeActionLabel(optionText, isActive)
	local plain = SafeLower(StripColorCodes(optionText or ""))

	if string.find(plain, "disable", 1, true) then
		return "Disable"
	end
	if string.find(plain, "enable", 1, true) then
		return "Enable"
	end
	if string.find(plain, "activate", 1, true) then
		return "Activate"
	end

	if isActive then
		return "Active"
	end

	return "Select"
end

local function GetModeVisualState(isActive, actionAllowed, hasOption)
	if isActive then
		return MODE_VISUAL_STATE.active
	end
	if actionAllowed then
		return MODE_VISUAL_STATE.available
	end
	if hasOption then
		return MODE_VISUAL_STATE.conditional
	end
	return MODE_VISUAL_STATE.locked
end

local MODE_SUMMARIES = {
	{ key = "Hardcore Mode", label = "Hardcore", category = "Survival", impact = "Extreme", lines = {
		"Death is permanent for the character.",
		"Strong planning and defensive play are required.",
	}, tip = "Best for players who want the highest stakes." },
	{ key = "Semi-Hardcore Mode", label = "Semi-Hardcore", category = "Survival", impact = "High", lines = {
		"Death applies a severe penalty instead of full run loss.",
		"Good stepping stone before full Hardcore.",
	}, tip = "Safer than Hardcore, still punishing mistakes." },
	{ key = "Self-Crafted Mode", label = "Self-Crafted", category = "Economy", impact = "Medium", lines = {
		"Only self-crafted equipment should be used.",
		"Pushes profession planning and material farming.",
	}, tip = "Pairs well with Slow XP for long-term progression." },
	{ key = "Item Quality Restriction", label = "Item Quality", category = "Gear", impact = "High", lines = {
		"Use poor/common (gray/white) quality gear only.",
		"Many quest and dungeon rewards become unusable.",
	}, tip = "Inventory management becomes part of the challenge." },
	{ key = "Slow XP Gain", label = "Slow XP", category = "Progression", impact = "Medium", lines = {
		"XP gains are reduced to 50%.",
		"Mutually exclusive with other XP-rate challenge modes.",
	}, tip = "Great for extended leveling routes." },
	{ key = "Very Slow XP Gain", label = "Very Slow XP", category = "Progression", impact = "High", lines = {
		"XP gains are reduced to 25%.",
		"Intended for long, methodical progression runs.",
	}, tip = "Usually chosen instead of Slow XP, not with it." },
	{ key = "Quest XP Only", label = "Quest XP Only", category = "Progression", impact = "High", lines = {
		"No kill XP; quests are your primary progression source.",
		"Route quality and quest chaining matter much more.",
	}, tip = "Works well for lore/zone-completion playstyles." },
	{ key = "Iron Man Mode", label = "Iron Man", lines = {
		"No deaths, white/gray only, no talents/glyphs.",
		"No professions (except First Aid), no grouping/dungeons/raids, no PvP/heirlooms.",
	}, category = "Composite", impact = "Extreme", tip = "A full ruleset challenge with strict limitations." },
	{ key = "Iron Man+ Mode", label = "Iron Man+", lines = {
		"No talents, no glyphs, no grouping/party play.",
		"No dungeons/raids, no professions (no exceptions).",
	}, category = "Composite", impact = "Extreme", tip = "Most restrictive variant for veteran challenge runs." },
}

local function GetOptionForMode(options, modeKey)
	local tokenLower = SafeLower(modeKey)
	for _, opt in ipairs(options) do
		local plain = SafeLower(StripColorCodes(opt.text))
		if string.find(plain, tokenLower, 1, true) then
			return opt
		end
	end
	return nil
end

local function GossipHasToken(options, token)
	return GetOptionForMode(options, token) ~= nil
end

local CHALLENGE_AURA_NAMES = {
	["Challenge: Hardcore Mode"] = "Hardcore",
	["Challenge: Semi-Hardcore"] = "Semi-Hardcore",
	["Challenge: Self-Crafted"] = "Self-Crafted",
	["Challenge: Item Quality"] = "Item Quality",
	["Challenge: Slow XP Gain"] = "Slow XP",
	["Challenge: Very Slow XP"] = "Very Slow XP",
	["Challenge: Quest XP Only"] = "Quest XP Only",
	["Challenge: Iron Man"] = "Iron Man",
	["Challenge: Iron Man+"] = "Iron Man+",
	["Challenge: Multiple Active"] = "Multiple Active",
}

local function GetActiveChallengeModesFromAuras()
	local active = {}

	for i = 1, 40 do
		local name = UnitAura("player", i)
		if not name then
			break
		end

		local pretty = CHALLENGE_AURA_NAMES[name]
		if pretty then
			table.insert(active, pretty)
		end
	end

	return active
end

local function FormatAgeSeconds(age)
	if not age or age < 0 then
		return "?"
	end

	if age < 60 then
		return string.format("%ds", age)
	end

	local minutes = math.floor(age / 60)
	local seconds = math.floor(age % 60)
	return string.format("%dm %ds", minutes, seconds)
end

local function GetGossipOptionsList()
	local options = {}
	local args = { GetGossipOptions() }

	-- WotLK returns pairs: name1, type1, name2, type2, ...
	local index = 1
	for i = 1, #args, 2 do
		local name = args[i]
		local optType = args[i + 1]
		if name then
			table.insert(options, {
				index = index,
				text = name,
				optType = optType,
			})
			index = index + 1
		end
	end
	return options
end

local function GossipLooksLikeChallengeManager(options)
	for _, opt in ipairs(options) do
		if type(opt.text) == "string" then
			for _, sig in ipairs(MANAGER_SIGNATURES) do
				if string.find(opt.text, sig, 1, true) then
					return true
				end
			end
		end
	end
	return false
end

local function IsNavAction(text)
	if type(text) ~= "string" then
		return false
	end

	return (string.find(text, "[<< Back]", 1, true) ~= nil)
		or (string.find(text, "[Close]", 1, true) ~= nil)
		or (string.find(text, "[Continue]", 1, true) ~= nil)
		or (string.find(text, "[CONFIRM]", 1, true) ~= nil)
		or (string.find(text, "[Confirm Prestige]", 1, true) ~= nil)
end

local function IsActionCandidate(text)
	if type(text) ~= "string" then
		return false
	end

	-- Most actionable lines are bracketed.
	if string.find(text, "[", 1, true) and string.find(text, "]", 1, true) then
		return true
	end

	return false
end

local function IsPrestigeRelated(text)
	return string.find(SafeLower(text), "prestige", 1, true) ~= nil
end

local function ShouldShowInTab(tabId, option)
	local text = option.text

	-- Navigation actions always visible
	if IsNavAction(text) then
		return true
	end

	local isPrestige = IsPrestigeRelated(text)

	if tabId == "overview" then
		-- Overview tab is for status; keep navigation actions only.
		return false
	end

	if tabId == "prestige" then
		return isPrestige
	end

	-- challenge tab
	return not isPrestige
end

local function HideGossipFrameInput()
	if GossipFrame then
		GossipFrame:SetAlpha(0)
		GossipFrame:EnableMouse(false)
		UI._gossipHidden = true
	end
end

local function RestoreGossipFrameInput()
	if UI._gossipHidden and GossipFrame then
		GossipFrame:SetAlpha(1)
		GossipFrame:EnableMouse(true)
	end
	UI._gossipHidden = false
end

-- Simple timer helper for WoW 3.3.5 (no C_Timer).
local _timerFrame = CreateFrame("Frame")
local _timers = {}
_timerFrame:Hide()
_timerFrame:SetScript("OnUpdate", function(self, elapsed)
	for i = #_timers, 1, -1 do
		local t = _timers[i]
		t.timeLeft = t.timeLeft - elapsed
		if t.timeLeft <= 0 then
			table.remove(_timers, i)
			if type(t.func) == "function" then
				pcall(t.func)
			end
		end
	end

	if #_timers == 0 then
		self:Hide()
	end
end)

local function After(delaySeconds, func)
	table.insert(_timers, { timeLeft = delaySeconds or 0, func = func })
	_timerFrame:Show()
end

-- =============================================================================
-- UI Construction
-- =============================================================================

local function CreateTabButton(parent, id, label, x)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(TAB_WIDTH, TAB_HEIGHT)
	btn:SetPoint("TOPLEFT", x, -40)
	btn.id = id

	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(0.15, 0.15, 0.15, 1)
	btn.bg = bg

	local accent = btn:CreateTexture(nil, "ARTWORK")
	accent:SetHeight(3)
	accent:SetPoint("BOTTOMLEFT", 0, 0)
	accent:SetPoint("BOTTOMRIGHT", 0, 0)
	accent:SetTexture(1, 0.8, 0, 1)
	accent:Hide()
	btn.accent = accent

	local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	txt:SetPoint("CENTER", 0, 0)
	txt:SetText(label)
	txt:SetTextColor(0.7, 0.7, 0.7)
	btn.text = txt

	btn:SetScript("OnEnter", function(self)
		if UI.currentTab ~= self.id then
			self.bg:SetTexture(0.25, 0.25, 0.25, 1)
			self.text:SetTextColor(1, 1, 1)
		end
	end)

	btn:SetScript("OnLeave", function(self)
		if UI.currentTab ~= self.id then
			self.bg:SetTexture(0.15, 0.15, 0.15, 1)
			self.text:SetTextColor(0.7, 0.7, 0.7)
		end
	end)

	btn:SetScript("OnClick", function(self)
		UI:SelectTab(self.id)
	end)

	return btn
end

local function CreateScrollArea(parent, width, height, id)
	local container = CreateFrame("Frame", nil, parent)
	container:SetSize(width, height)

	-- IMPORTANT (WoW 3.3.5): UIPanelScrollFrameTemplate assumes a global name.
	-- If the ScrollFrame has no name, ScrollFrame_OnLoad concatenates nil and errors.
	local scrollName = "DCWelcome_CPUI_Scroll_" .. tostring(id)
	local scroll = CreateFrame("ScrollFrame", scrollName, container, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", -26, 0)

	local child = CreateFrame("Frame", scrollName .. "Child", scroll)
	child:SetSize(width - 26, 1)
	scroll:SetScrollChild(child)

	container.scroll = scroll
	container.child = child

	-- Simple pooling to avoid unbounded frame creation during Refresh.
	container._buttonPool = {}
	container._fsPool = {}
	container._texPool = {}
	container._buttonUsed = 0
	container._fsUsed = 0
	container._texUsed = 0

	return container
end

function UI:EnsureFrame()
	if self.frame then
		return
	end

	local f = CreateFrame("Frame", "DCWelcome_ChallengePrestigeFrame", UIParent)
	f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
	f:SetPoint("CENTER", 0, 0)
	local BG_FELLEATHER = "Interface\\AddOns\\DC-Welcome\\Textures\\Backgrounds\\FelLeather_512.tga"
	local BG_TINT_ALPHA = 0.60
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 }
	})
	f:SetBackdropColor(0, 0, 0, 0)

	f.bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	f.bg:SetAllPoints()
	f.bg:SetTexture(BG_FELLEATHER)

	f.bgTint = f:CreateTexture(nil, "BACKGROUND", nil, -7)
	f.bgTint:SetAllPoints(f.bg)
	f.bgTint:SetTexture(0, 0, 0, BG_TINT_ALPHA)
	f:Hide()

	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) self:StartMoving() end)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -16)
	title:SetText("Challenge Modes & Prestige")
	title:SetTextColor(1, 0.82, 0)
	f.title = title

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -6, -6)
	close:SetScript("OnClick", function()
		CloseGossip()
	end)

	-- Tabs
	local tabStartX = 20
	local tabGap = 6
	f.tabOverview = CreateTabButton(f, "overview", "Overview", tabStartX)
	f.tabChallenge = CreateTabButton(f, "challenge", "Challenge Modes", tabStartX + TAB_WIDTH + tabGap)
	f.tabPrestige = CreateTabButton(f, "prestige", "Prestige", tabStartX + (TAB_WIDTH + tabGap) * 2)

	-- Left: Status + Actions
	local leftTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	leftTitle:SetPoint("TOPLEFT", 24, -76)
	leftTitle:SetText("Status & Actions")
	leftTitle:SetTextColor(1, 0.82, 0)

	local left = CreateScrollArea(f, LEFT_WIDTH, CONTENT_HEIGHT, "Actions")
	left:SetPoint("TOPLEFT", 20, -96)
	f.left = left

	-- Right: Details
	local rightTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	rightTitle:SetPoint("TOPLEFT", 20 + LEFT_WIDTH + 28, -76)
	rightTitle:SetText("Details")
	rightTitle:SetTextColor(1, 0.82, 0)

	local right = CreateScrollArea(f, RIGHT_WIDTH, CONTENT_HEIGHT, "Details")
	right:SetPoint("TOPLEFT", 20 + LEFT_WIDTH + 24, -96)
	f.right = right

	-- Footer hint
	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("BOTTOMLEFT", 20, 16)
	hint:SetText("Tip: actions are server-driven. Use [<< Back] to navigate between manager pages.")
	hint:SetTextColor(0.75, 0.75, 0.75)

	self.frame = f

	self:SelectTab("overview")
end

function UI:SelectTab(tabId)
	self.currentTab = tabId

	local f = self.frame
	if not f then
		return
	end

	local function ApplyTab(btn, active)
		if active then
			btn.bg:SetTexture(0.25, 0.25, 0.25, 1)
			btn.text:SetTextColor(1, 1, 1)
			btn.accent:Show()
		else
			btn.bg:SetTexture(0.15, 0.15, 0.15, 1)
			btn.text:SetTextColor(0.7, 0.7, 0.7)
			btn.accent:Hide()
		end
	end

	ApplyTab(f.tabChallenge, tabId == "challenge")
	ApplyTab(f.tabPrestige, tabId == "prestige")
	ApplyTab(f.tabOverview, tabId == "overview")

	self:Refresh()
end

-- =============================================================================
-- Rendering
-- =============================================================================

function UI:ClearScrollChild(child)
	if not child then
		return
	end

	-- Reset pool cursors and hide previously used elements.
	local container = child:GetParent() -- ScrollFrame
	container = container and container:GetParent() -- our container frame

	if container and container._buttonPool then
		for i = 1, (container._buttonUsed or 0) do
			local b = container._buttonPool[i]
			if b then
				b:Hide()
			end
		end
		for i = 1, (container._fsUsed or 0) do
			local fs = container._fsPool[i]
			if fs then
				fs:Hide()
				fs:SetText("")
			end
		end
		for i = 1, (container._texUsed or 0) do
			local tex = container._texPool[i]
			if tex then
				tex:Hide()
				tex:ClearAllPoints()
			end
		end

		container._buttonUsed = 0
		container._fsUsed = 0
		container._texUsed = 0
	end

	child._items = {}
end

local function AcquireButton(container, parent)
	container._buttonUsed = (container._buttonUsed or 0) + 1
	local idx = container._buttonUsed
	local b = container._buttonPool[idx]
	if not b then
		b = CreateFrame("Button", nil, parent)
		container._buttonPool[idx] = b
	end

	b:SetParent(parent)
	b:Show()
	return b
end

local function AcquireFontString(container, parent)
	container._fsUsed = (container._fsUsed or 0) + 1
	local idx = container._fsUsed
	local fs = container._fsPool[idx]
	if not fs then
		fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		container._fsPool[idx] = fs
	end

	-- FontStrings cannot have nil parent, but can be re-parented safely.
	fs:SetParent(parent)
	fs:Show()
	return fs
end

local function AcquireTexture(container, parent, layer, subLevel)
	container._texUsed = (container._texUsed or 0) + 1
	local idx = container._texUsed
	local tex = container._texPool[idx]
	if not tex then
		tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, subLevel or 0)
		container._texPool[idx] = tex
	end

	tex:SetParent(parent)
	tex:SetDrawLayer(layer or "BACKGROUND", subLevel or 0)
	tex:Show()
	return tex
end

function UI:AddActionButton(parent, y, text, gossipIndex)
	local container = parent:GetParent() -- ScrollFrame
	container = container and container:GetParent()
	local btn = AcquireButton(container, parent)
	btn:SetSize(LEFT_WIDTH - 34, 20)
	btn:SetPoint("TOPLEFT", 4, y)
	btn:EnableMouse(true)

	if not btn.bg then
		local bg = btn:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetTexture(0.14, 0.14, 0.14, 0.95)
		btn.bg = bg
	end

	if not btn._text then
		local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		fs:SetPoint("LEFT", 8, 0)
		fs:SetWidth(LEFT_WIDTH - 52)
		fs:SetJustifyH("LEFT")
		btn._text = fs
	end

	local fs = btn._text
	fs:SetText(text)
	fs:SetTextColor(0.92, 0.92, 0.92)

	btn:SetScript("OnClick", function()
		if type(gossipIndex) == "number" and gossipIndex > 0 then
			SelectGossipOption(gossipIndex)
			UI:QueueRefresh()
		end
	end)

	btn:SetScript("OnEnter", function()
		fs:SetTextColor(1, 1, 1)
		btn.bg:SetTexture(0.22, 0.22, 0.22, 0.95)
	end)

	btn:SetScript("OnLeave", function()
		fs:SetTextColor(0.92, 0.92, 0.92)
		btn.bg:SetTexture(0.14, 0.14, 0.14, 0.95)
	end)

	return btn
end

function UI:AddDetailLine(parent, y, text, width, xOffset)
	local container = parent:GetParent() -- ScrollFrame
	container = container and container:GetParent()
	local fs = AcquireFontString(container, parent)
	fs:SetPoint("TOPLEFT", xOffset or 4, y)
	fs:SetWidth(width or (RIGHT_WIDTH - 44))
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	fs:SetTextColor(1, 1, 1)
	return fs
end

function UI:AddLeftHeader(parent, y, text)
	local container = parent:GetParent() -- ScrollFrame
	container = container and container:GetParent()
	local fs = AcquireFontString(container, parent)
	fs:SetPoint("TOPLEFT", 4, y)
	fs:SetWidth(LEFT_WIDTH - 44)
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	fs:SetTextColor(1, 0.82, 0)
	return fs
end

function UI:AddLeftLine(parent, y, text, r, g, b)
	local container = parent:GetParent() -- ScrollFrame
	container = container and container:GetParent()
	local fs = AcquireFontString(container, parent)
	fs:SetPoint("TOPLEFT", 4, y)
	fs:SetWidth(LEFT_WIDTH - 44)
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	fs:SetTextColor(r or 0.85, g or 0.85, b or 0.85)
	return fs
end

function UI:AddDetailRule(parent, y, width, xOffset, r, g, b, a, thickness, layer, subLevel)
	local container = parent:GetParent() -- ScrollFrame
	container = container and container:GetParent()
	local tex = AcquireTexture(container, parent, layer or "BACKGROUND", subLevel or 0)
	tex:ClearAllPoints()
	tex:SetTexture(r or 1, g or 1, b or 1, a or 1)
	tex:SetPoint("TOPLEFT", xOffset or 4, y)
	tex:SetSize(width or (RIGHT_WIDTH - 44), thickness or 1)
	return tex
end

function UI:AddLeftRule(parent, y, r, g, b, a, thickness)
	local container = parent:GetParent() -- ScrollFrame
	container = container and container:GetParent()
	local tex = AcquireTexture(container, parent, "ARTWORK", 1)
	tex:ClearAllPoints()
	tex:SetTexture(r or 1, g or 1, b or 1, a or 1)
	tex:SetPoint("TOPLEFT", 4, y)
	tex:SetSize(LEFT_WIDTH - 44, thickness or 1)
	return tex
end

function UI:AddModeRowDecor(parent, yTop, yBottom, style)
	local topY = yTop + 1
	local bottomY = yBottom + 2
	local rowHeight = math.max(14, topY - bottomY + 1)
	local width = RIGHT_WIDTH - 44

	local bg = self:AddDetailRule(
		parent,
		topY,
		width,
		4,
		style.bg[1],
		style.bg[2],
		style.bg[3],
		style.bg[4],
		rowHeight,
		"BACKGROUND",
		0
	)
	local accent = self:AddDetailRule(
		parent,
		topY,
		2,
		4,
		style.accent[1],
		style.accent[2],
		style.accent[3],
		style.accent[4],
		rowHeight,
		"ARTWORK",
		1
	)
	local topEdge = self:AddDetailRule(parent, topY, width, 4, 0.35, 0.35, 0.35, 0.75, 1, "ARTWORK", 1)
	local bottomEdge = self:AddDetailRule(
		parent,
		bottomY,
		width,
		4,
		style.edge[1],
		style.edge[2],
		style.edge[3],
		style.edge[4],
		1,
		"ARTWORK",
		1
	)

	return bg, accent, topEdge, bottomEdge
end

function UI:Refresh()
	if not self.frame or not self.frame:IsShown() then
		return
	end

	local leftChild = self.frame.left.child
	local rightChild = self.frame.right.child

	self:ClearScrollChild(leftChild)
	self:ClearScrollChild(rightChild)

	local options = GetGossipOptionsList()
	local progress = (DCWelcome and DCWelcome.GetProgress and DCWelcome:GetProgress()) or (DCWelcome and DCWelcome.Progress) or {}
	local activeModes = GetActiveChallengeModesFromAuras()
	local activeSet = {}
	for _, modeName in ipairs(activeModes) do
		activeSet[modeName] = true
	end

	local availableModeCount = 0
	for _, m in ipairs(MODE_SUMMARIES) do
		if GetOptionForMode(options, m.key) then
			availableModeCount = availableModeCount + 1
		end
	end

	local randomOpt = GetOptionForMode(options, "Random Challenge Mode")

	-- If gossip no longer matches the manager, close.
	if not GossipLooksLikeChallengeManager(options) then
		self:Close()
		return
	end

	-- Details panel: show Overview section (if selected) + current gossip state
	local yDetail = -4
	local handledIndices = {}

	-- CONFIRMATION OVERLAY
	if UI.confirmationStep == 1 then
		local warn = self:AddDetailLine(rightChild, yDetail, "|cffff0000WARNING: PERMANENT ACTION|r")
		table.insert(rightChild._items, warn)
		yDetail = yDetail - (warn:GetStringHeight() + 8)

		local desc1 = self:AddDetailLine(rightChild, yDetail, "You are about to Prestige. This will reset your level to 1.")
		table.insert(rightChild._items, desc1)
		yDetail = yDetail - (desc1:GetStringHeight() + 4)

		local desc2 = self:AddDetailLine(rightChild, yDetail, "Gear, Gold, and Skills may be lost depending on server settings.")
		table.insert(rightChild._items, desc2)
		yDetail = yDetail - (desc2:GetStringHeight() + 12)

		local desc3 = self:AddDetailLine(rightChild, yDetail, "Type |cffffd700PRESTIGE|r to confirm:")
		table.insert(rightChild._items, desc3)
		yDetail = yDetail - (desc3:GetStringHeight() + 8)

		-- Input Box
		if not self.confirmInput then
			local eb = CreateFrame("EditBox", nil, rightChild)
			eb:SetFontObject(GameFontHighlight)
			eb:SetSize(140, 24)
			eb:SetAutoFocus(false)
			eb:SetMaxLetters(12)
			eb:SetScript("OnEscapePressed", function() eb:ClearFocus() end)
			eb:SetScript("OnEnterPressed", function()
				if eb:GetText() == "PRESTIGE" then
					-- Find the "Confirm" gossip option
					for _, opt in ipairs(options) do
						if IsNavAction(opt.text) and (string.find(opt.text, "CONFIRM") or string.find(opt.text, "Confirm")) then
							SelectGossipOption(opt.index)
							UI.confirmationStep = 0
							UI:QueueRefresh()
							return
						end
					end
					-- Fallback if not found immediately (server might need a step)
					UI.confirmationStep = 0
					UI:QueueRefresh()
				end
			end)
			
			local bg = eb:CreateTexture(nil, "BACKGROUND")
			bg:SetAllPoints()
			bg:SetTexture(0.1, 0.1, 0.1, 1)
			
			self.confirmInput = eb
		end
		
		self.confirmInput:SetParent(rightChild)
		self.confirmInput:SetPoint("TOPLEFT", 10, yDetail)
		self.confirmInput:Show()
		self.confirmInput:SetText("")
		self.confirmInput:SetFocus()
		table.insert(rightChild._items, self.confirmInput)
		yDetail = yDetail - 30

		local cancelBtn = AcquireButton(rightChild:GetParent():GetParent(), rightChild)
		cancelBtn:SetSize(100, 22)
		cancelBtn:SetPoint("TOPLEFT", 10, yDetail)
		if not cancelBtn.bg then
			local bg = cancelBtn:CreateTexture(nil, "BACKGROUND")
			bg:SetAllPoints()
			cancelBtn.bg = bg
		end
		if not cancelBtn._text then
			local fs = cancelBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			fs:SetPoint("CENTER", 0, 0)
			cancelBtn._text = fs
		end
		cancelBtn.bg:SetTexture(0.25, 0.14, 0.14, 0.95)
		cancelBtn._text:SetText("Cancel")
		cancelBtn._text:SetTextColor(1, 0.86, 0.86)
		cancelBtn:EnableMouse(true)
		cancelBtn:SetScript("OnClick", function()
			UI.confirmationStep = 0
			UI:Refresh()
		end)
		cancelBtn:SetScript("OnEnter", function()
			cancelBtn.bg:SetTexture(0.35, 0.2, 0.2, 0.95)
		end)
		cancelBtn:SetScript("OnLeave", function()
			cancelBtn.bg:SetTexture(0.25, 0.14, 0.14, 0.95)
		end)
		yDetail = yDetail - 30

		return -- Don't show other tabs while confirming
	end

	if self.currentTab == "overview" then
		local title = self:AddDetailLine(rightChild, yDetail, "|cffffd700Player Overview|r")
		table.insert(rightChild._items, title)
		yDetail = yDetail - (title:GetStringHeight() + 8)

		local playerName = UnitName("player") or "?"
		local playerLevel = UnitLevel("player") or 0
		local _, classFile = UnitClass("player")
		local classColor = (classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]) or { r = 1, g = 1, b = 1 }
		local r = math.floor((classColor.r or 1) * 255 + 0.5)
		local g = math.floor((classColor.g or 1) * 255 + 0.5)
		local b = math.floor((classColor.b or 1) * 255 + 0.5)
		local nameLine = string.format("|cff%02x%02x%02x%s|r - Level %d", r, g, b, playerName, playerLevel)
		local n = self:AddDetailLine(rightChild, yDetail, nameLine)
		table.insert(rightChild._items, n)
		yDetail = yDetail - (n:GetStringHeight() + 10)

		local modesText = "None"
		if #activeModes > 0 then
			modesText = table.concat(activeModes, ", ")
		end
		local cm = self:AddDetailLine(rightChild, yDetail, "|cffffd700Challenge Modes:|r " .. modesText)
		table.insert(rightChild._items, cm)
		yDetail = yDetail - (cm:GetStringHeight() + 6)

		local prestigeLevel = progress.prestigeLevel
		local prestigeXP = progress.prestigeXP
		local prestigeXPMax = progress.prestigeXPMax
		local altBonusLevel = progress.altBonusLevel
		local altBonusPercent = progress.altBonusPercent

		if prestigeLevel then
			local pLine = "|cffffd700Prestige Level:|r " .. tostring(prestigeLevel)
			if prestigeXP and prestigeXPMax then
				pLine = pLine .. string.format("  (XP: %s/%s)", tostring(prestigeXP), tostring(prestigeXPMax))
			elseif prestigeXP then
				pLine = pLine .. string.format("  (XP: %s)", tostring(prestigeXP))
			end
			local p = self:AddDetailLine(rightChild, yDetail, pLine)
			table.insert(rightChild._items, p)
			yDetail = yDetail - (p:GetStringHeight() + 6)
		else
			local p = self:AddDetailLine(rightChild, yDetail, "|cff888888Prestige: no data yet.|r")
			table.insert(rightChild._items, p)
			yDetail = yDetail - (p:GetStringHeight() + 6)
		end

		if altBonusPercent or altBonusLevel then
			local aLine = "|cffffd700Alt Bonus:|r " .. tostring(altBonusPercent or "?") .. "%"
			if altBonusLevel then
				aLine = aLine .. "  (Tier: " .. tostring(altBonusLevel) .. ")"
			end
			local a = self:AddDetailLine(rightChild, yDetail, aLine)
			table.insert(rightChild._items, a)
			yDetail = yDetail - (a:GetStringHeight() + 10)
		end

		if progress._lastUpdate and progress._lastUpdate > 0 then
			local age = time() - (progress._lastUpdate or 0)
			local u = self:AddDetailLine(rightChild, yDetail, "|cff888888Progress cache age: " .. FormatAgeSeconds(age) .. "|r")
			table.insert(rightChild._items, u)
			yDetail = yDetail - (u:GetStringHeight() + 8)
		end

		local sep = self:AddDetailRule(rightChild, yDetail, RIGHT_WIDTH - 44, 4, 0.42, 0.42, 0.42, 0.9, 1, "ARTWORK", 1)
		table.insert(rightChild._items, sep)
		yDetail = yDetail - 8

	elseif self.currentTab == "challenge" then
		local hdr = self:AddDetailLine(rightChild, yDetail, "|cffffd700Challenge Modes Overview|r")
		table.insert(rightChild._items, hdr)
		yDetail = yDetail - (hdr:GetStringHeight() + 6)

		local summary = self:AddDetailLine(
			rightChild,
			yDetail,
			string.format(
				"|cffcfcfcfActive now: %d  |  Visible in menu: %d/%d|r",
				#activeModes,
				availableModeCount,
				#MODE_SUMMARIES
			)
		)
		table.insert(rightChild._items, summary)
		yDetail = yDetail - (summary:GetStringHeight() + 7)

		local summaryRule = self:AddDetailRule(rightChild, yDetail, RIGHT_WIDTH - 44, 4, 0.45, 0.45, 0.45, 0.9, 1, "ARTWORK", 1)
		table.insert(rightChild._items, summaryRule)
		yDetail = yDetail - 6

		for _, m in ipairs(MODE_SUMMARIES) do
			local opt = GetOptionForMode(options, m.key)
			local isActive = activeSet[m.label]
			local actionAllowed = opt and IsModeOptionActionable(opt.text)
			local blockStart = yDetail
			local visual = GetModeVisualState(isActive, actionAllowed, opt ~= nil)
			local stateText = visual.label

			local textWidth = RIGHT_WIDTH - 44
			if actionAllowed then
				textWidth = RIGHT_WIDTH - MODE_BUTTON_WIDTH - 82
				handledIndices[opt.index] = true
			end

			local nameLine = self:AddDetailLine(
				rightChild,
				yDetail,
				"|cffF7F7F7" .. m.label .. "|r  " .. stateText,
				textWidth,
				6
			)
			table.insert(rightChild._items, nameLine)
			yDetail = yDetail - (nameLine:GetStringHeight() + 1)

			local metaLine = self:AddDetailLine(
				rightChild,
				yDetail,
				string.format(
					"|cffc7c7c7Category: %s  |  Impact: %s|r",
					m.category or "Challenge",
					m.impact or "Mixed"
				),
				textWidth,
				12
			)
			table.insert(rightChild._items, metaLine)
			yDetail = yDetail - (metaLine:GetStringHeight() + 1)

			for _, desc in ipairs(m.lines or {}) do
				local d = self:AddDetailLine(rightChild, yDetail, "|cffaaaaaa- " .. desc .. "|r", textWidth, 12)
				table.insert(rightChild._items, d)
				yDetail = yDetail - (d:GetStringHeight() + 1)
			end

			if m.tip then
				local tip = self:AddDetailLine(rightChild, yDetail, "|cff80b3ffTip:|r |cff9f9f9f" .. m.tip .. "|r", textWidth, 12)
				table.insert(rightChild._items, tip)
				yDetail = yDetail - (tip:GetStringHeight() + 2)
			end

			if actionAllowed then
				local btnText = BuildModeActionLabel(opt.text, isActive)
				local container = rightChild:GetParent():GetParent()
				local b = AcquireButton(container, rightChild)
				b:SetSize(MODE_BUTTON_WIDTH, 18)
				b:SetPoint("TOPRIGHT", -20, blockStart - 1)

				if not b.bg then
					local bg = b:CreateTexture(nil, "BACKGROUND")
					bg:SetAllPoints()
					b.bg = bg
				end
				if not b._text then
					local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
					fs:SetPoint("CENTER", 0, 0)
					b._text = fs
				end

				local normalR = (visual.accent[1] * 0.36) + 0.06
				local normalG = (visual.accent[2] * 0.36) + 0.06
				local normalB = (visual.accent[3] * 0.36) + 0.06
				local hoverR = (visual.accent[1] * 0.56) + 0.10
				local hoverG = (visual.accent[2] * 0.56) + 0.10
				local hoverB = (visual.accent[3] * 0.56) + 0.10

				b.bg:SetTexture(normalR, normalG, normalB, 0.95)
				b._text:SetText(btnText)
				b._text:SetTextColor(visual.buttonText[1], visual.buttonText[2], visual.buttonText[3])
				b:EnableMouse(true)
				b:SetScript("OnClick", function()
					SelectGossipOption(opt.index)
					UI:QueueRefresh()
				end)
				b:SetScript("OnEnter", function()
					b.bg:SetTexture(hoverR, hoverG, hoverB, 0.95)
				end)
				b:SetScript("OnLeave", function()
					b.bg:SetTexture(normalR, normalG, normalB, 0.95)
				end)

				table.insert(rightChild._items, b)
			end

			local rowBg, rowAccent, rowTopEdge, rowBottomEdge = self:AddModeRowDecor(rightChild, blockStart, yDetail, visual)
			table.insert(rightChild._items, rowBg)
			table.insert(rightChild._items, rowAccent)
			table.insert(rightChild._items, rowTopEdge)
			table.insert(rightChild._items, rowBottomEdge)
			yDetail = yDetail - 4
		end

		if randomOpt and IsModeOptionActionable(randomOpt.text) then
			handledIndices[randomOpt.index] = true
			local randomVisual = MODE_VISUAL_STATE.available
			local rnd = self:AddDetailLine(rightChild, yDetail, "|cffb4b4b4Random Mode: picks one eligible challenge mode (requires no active challenge aura).|r")
			table.insert(rightChild._items, rnd)
			yDetail = yDetail - (rnd:GetStringHeight() + 4)

			local container = rightChild:GetParent():GetParent()
			local b = AcquireButton(container, rightChild)
			b:SetSize(MODE_BUTTON_WIDTH, 18)
			b:SetPoint("TOPLEFT", 20, yDetail)

			if not b._text then
				local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
				fs:SetPoint("CENTER", 0, 0)
				b._text = fs
			end
			b._text:SetText("Random")
			b._text:SetTextColor(randomVisual.buttonText[1], randomVisual.buttonText[2], randomVisual.buttonText[3])

			if not b.bg then
				local bg = b:CreateTexture(nil, "BACKGROUND")
				bg:SetAllPoints()
				b.bg = bg
			end
			b.bg:SetTexture(0.21, 0.34, 0.50, 0.95)

			b:EnableMouse(true)
			b:SetScript("OnClick", function()
				SelectGossipOption(randomOpt.index)
				UI:QueueRefresh()
			end)
			b:SetScript("OnEnter", function() b.bg:SetTexture(0.30, 0.50, 0.72, 0.95) end)
			b:SetScript("OnLeave", function() b.bg:SetTexture(0.21, 0.34, 0.50, 0.95) end)

			table.insert(rightChild._items, b)
			yDetail = yDetail - 22
			yDetail = yDetail - 4
		end

		local endRule = self:AddDetailRule(rightChild, yDetail, RIGHT_WIDTH - 44, 4, 0.45, 0.45, 0.45, 0.9, 1, "ARTWORK", 1)
		table.insert(rightChild._items, endRule)
		yDetail = yDetail - 8

	elseif self.currentTab == "prestige" then
		local hdr = self:AddDetailLine(rightChild, yDetail, "|cffffd700Prestige Information|r")
		table.insert(rightChild._items, hdr)
		yDetail = yDetail - (hdr:GetStringHeight() + 8)

		local foundAny = false
		for _, opt in ipairs(options) do
			if IsPrestigeRelated(opt.text) and not IsNavAction(opt.text) then
				local t = self:AddDetailLine(rightChild, yDetail, opt.text)
				table.insert(rightChild._items, t)
				yDetail = yDetail - (t:GetStringHeight() + 4)
				foundAny = true
			end
		end

		if not foundAny then
			local t = self:AddDetailLine(rightChild, yDetail, "|cff888888No specific prestige status found.|r")
			table.insert(rightChild._items, t)
		end
	end

	rightChild:SetHeight(math.max(1, math.abs(yDetail) + 20))

	-- Left panel: quick status + actions
	local yAction = -4
	local statusHeader = self:AddLeftHeader(leftChild, yAction, "Quick Status")
	table.insert(leftChild._items, statusHeader)
	yAction = yAction - 18
	local statusRule = self:AddLeftRule(leftChild, yAction + 2, 0.48, 0.48, 0.48, 0.9, 1)
	table.insert(leftChild._items, statusRule)

	local statusCount = self:AddLeftLine(
		leftChild,
		yAction,
		string.format("Active challenge modes: %d", #activeModes),
		0.9,
		0.9,
		0.9
	)
	table.insert(leftChild._items, statusCount)
	yAction = yAction - (statusCount:GetStringHeight() + 2)

	if #activeModes > 0 then
		for i = 1, math.min(#activeModes, 3) do
			local modeLine = self:AddLeftLine(leftChild, yAction, "- " .. tostring(activeModes[i]), 1, 0.84, 0)
			table.insert(leftChild._items, modeLine)
			yAction = yAction - (modeLine:GetStringHeight() + 1)
		end
		if #activeModes > 3 then
			local moreLine = self:AddLeftLine(leftChild, yAction, string.format("... and %d more", #activeModes - 3), 0.75, 0.75, 0.75)
			table.insert(leftChild._items, moreLine)
			yAction = yAction - (moreLine:GetStringHeight() + 1)
		end
	end

	local availabilityLine = self:AddLeftLine(
		leftChild,
		yAction,
		string.format("Modes in current menu: %d/%d", availableModeCount, #MODE_SUMMARIES),
		0.82,
		0.82,
		0.82
	)
	table.insert(leftChild._items, availabilityLine)
	yAction = yAction - (availabilityLine:GetStringHeight() + 2)

	local prestigeText = "Prestige: no data"
	if progress.prestigeLevel then
		prestigeText = "Prestige: " .. tostring(progress.prestigeLevel)
		if progress.prestigeXP and progress.prestigeXPMax then
			prestigeText = prestigeText .. string.format(" (%s/%s)", tostring(progress.prestigeXP), tostring(progress.prestigeXPMax))
		end
	end
	local prestigeLine = self:AddLeftLine(leftChild, yAction, prestigeText, 0.85, 0.85, 0.98)
	table.insert(leftChild._items, prestigeLine)
	yAction = yAction - (prestigeLine:GetStringHeight() + 2)

	local randomState = randomOpt and "available" or "not visible"
	local randomLine = self:AddLeftLine(leftChild, yAction, "Random mode: " .. randomState, 0.76, 0.86, 0.76)
	table.insert(leftChild._items, randomLine)
	yAction = yAction - (randomLine:GetStringHeight() + 8)

	local actionsHeader = self:AddLeftHeader(leftChild, yAction, "Actions")
	table.insert(leftChild._items, actionsHeader)
	yAction = yAction - 18
	local actionsRule = self:AddLeftRule(leftChild, yAction + 2, 0.48, 0.48, 0.48, 0.9, 1)
	table.insert(leftChild._items, actionsRule)

	local navOpts = {}
	local otherOpts = {}
	for _, opt in ipairs(options) do
		if IsActionCandidate(opt.text) and ShouldShowInTab(self.currentTab, opt) then
			if not handledIndices[opt.index] then
				if IsNavAction(opt.text) then
					table.insert(navOpts, opt)
				elseif not IsDecorativeOption(opt.text) and not IsUnclickableStatus(opt.text) then
					table.insert(otherOpts, opt)
				end
			end
		end
	end

	if #otherOpts > 0 then
		for _, opt in ipairs(otherOpts) do
			local b = self:AddActionButton(leftChild, yAction, opt.text, opt.index)
			table.insert(leftChild._items, b)
			yAction = yAction - 22
		end
		yAction = yAction - 6
	end

	if #navOpts > 0 then
		local navHeader = self:AddLeftHeader(leftChild, yAction, "Navigation")
		table.insert(leftChild._items, navHeader)
		yAction = yAction - 18
		local navRule = self:AddLeftRule(leftChild, yAction + 2, 0.48, 0.48, 0.48, 0.9, 1)
		table.insert(leftChild._items, navRule)
		for _, opt in ipairs(navOpts) do
			local b = self:AddActionButton(leftChild, yAction, opt.text, opt.index)
			table.insert(leftChild._items, b)
			yAction = yAction - 22
		end
	end

	if #otherOpts == 0 and #navOpts == 0 then
		local none = self:AddLeftLine(leftChild, yAction, "No actions available on this tab.", 0.75, 0.75, 0.75)
		table.insert(leftChild._items, none)
	end

	leftChild:SetHeight(math.max(1, math.abs(yAction) + 24))
end

function UI:QueueRefresh()
	if self._pendingUpdate then
		return
	end

	self._pendingUpdate = true
	-- Let the gossip menu update first.
	After(0.05, function()
		UI._pendingUpdate = false
		UI:Refresh()
	end)
end

-- =============================================================================
-- Open/Close + Gossip Integration
-- =============================================================================

function UI:Open()
	self:EnsureFrame()
	self.frame:Show()
	HideGossipFrameInput()
	if DCWelcome and DCWelcome.RequestProgressData then
		DCWelcome:RequestProgressData()
	end
	self:Refresh()
end

function UI:Close()
	if self.frame then
		self.frame:Hide()
	end
	-- Do not restore gossip frame input if we are closing the session.
	RestoreGossipFrameInput()
end

function UI:TryOpenFromGossip()
	local options = GetGossipOptionsList()
	if GossipLooksLikeChallengeManager(options) then
		self:Open()
		return true
	end
	return false
end

-- Event hook
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GOSSIP_SHOW")
eventFrame:RegisterEvent("GOSSIP_CLOSED")

eventFrame:SetScript("OnEvent", function(_, event)
	if event == "GOSSIP_SHOW" then
		UI:TryOpenFromGossip()
	elseif event == "GOSSIP_CLOSED" then
		UI:Close()
	end
end)

-- Refresh when DC-Welcome updates progress (prestige / alt bonus / etc.)
if DCWelcome and DCWelcome.EventBus and DCWelcome.EventBus.On then
	DCWelcome.EventBus:On("PROGRESS_UPDATED", function()
		if UI.frame and UI.frame:IsShown() then
			UI:Refresh()
		end
	end)
end
