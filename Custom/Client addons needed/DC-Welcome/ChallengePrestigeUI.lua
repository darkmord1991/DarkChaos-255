--[[
	DC-Welcome ChallengePrestigeUI.lua
	Lightweight UI wrapper for the server-side Challenge Mode Manager gossip.

	Goals (per DarkChaos-255 spec):
	- Header band with player status (absorbs the old Overview tab)
	- Two tabs: Challenge Modes (card grid) + Prestige (progress view)
	- Shows information like the gossip-based Challenge Mode Manager
	- Allows selecting/confirming challenge modes and prestige directly from the UI
	- Automatically opens when interacting with the Challenge Mode Manager gameobject

	Implementation notes:
	- This does NOT re-implement server logic. It mirrors the current gossip state and
	  drives it by calling SelectGossipOption(index).
	- Detection is based on the manager's unique title line:
	  "=== Challenge Mode Manager ===".
	- Server sub-pages (mode details, confirmations) are rendered as a centered
	  dialog; full mode rules live in hover tooltips instead of inline text.

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
local TAB_WIDTH = 170

local CONTENT_WIDTH = 816
local CONTENT_HEIGHT = 382
local CHILD_WIDTH = CONTENT_WIDTH - 26

local CARD_WIDTH = 388
local CARD_HEIGHT = 60
local CARD_GAP = 8

local MODE_VISUAL_STATE = {
	active = {
		label = "|cff54ff9aACTIVE|r",
		bg = { 0.05, 0.20, 0.11, 0.50 },
		hover = { 0.08, 0.28, 0.16, 0.60 },
		accent = { 0.36, 0.95, 0.56, 0.95 },
		nameColor = { 0.80, 1.00, 0.86 },
	},
	available = {
		label = "|cff7ad5ffAVAILABLE|r",
		bg = { 0.06, 0.12, 0.22, 0.50 },
		hover = { 0.10, 0.20, 0.36, 0.62 },
		accent = { 0.42, 0.76, 1.00, 0.95 },
		nameColor = { 0.96, 0.96, 0.96 },
	},
	conditional = {
		label = "|cffffcb71BLOCKED|r",
		bg = { 0.21, 0.15, 0.05, 0.40 },
		hover = { 0.28, 0.20, 0.08, 0.50 },
		accent = { 0.95, 0.75, 0.30, 0.92 },
		nameColor = { 0.85, 0.80, 0.70 },
	},
	locked = {
		label = "|cff9d9d9dNOT OFFERED|r",
		bg = { 0.10, 0.10, 0.10, 0.35 },
		hover = { 0.14, 0.14, 0.14, 0.40 },
		accent = { 0.45, 0.45, 0.45, 0.85 },
		nameColor = { 0.62, 0.62, 0.62 },
	},
}

local IMPACT_COLORS = {
	Extreme = "ff6b6b",
	High = "ffb347",
	Medium = "ffe066",
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
UI.currentTab = "challenge" -- "challenge" | "prestige"
UI._gossipHidden = false
UI._pendingUpdate = false
UI.confirmationStep = 0 -- 0: none, 1: typed prestige confirmation
UI._confirmIndex = nil

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
	{ key = "Hardcore Mode", label = "Hardcore", category = "Survival", impact = "Extreme",
		summary = "One life only - death is permanent.",
		lines = {
			"Death is permanent for the character.",
			"Strong planning and defensive play are required.",
		}, tip = "Best for players who want the highest stakes." },
	{ key = "Semi-Hardcore Mode", label = "Semi-Hardcore", category = "Survival", impact = "High",
		summary = "Death brings a severe penalty, not a full loss.",
		lines = {
			"Death applies a severe penalty instead of full run loss.",
			"Good stepping stone before full Hardcore.",
		}, tip = "Safer than Hardcore, still punishing mistakes." },
	{ key = "Self-Crafted Mode", label = "Self-Crafted", category = "Economy", impact = "Medium",
		summary = "Wear only gear you crafted yourself.",
		lines = {
			"Only self-crafted equipment should be used.",
			"Pushes profession planning and material farming.",
		}, tip = "Pairs well with Slow XP for long-term progression." },
	{ key = "Item Quality Restriction", label = "Item Quality", category = "Gear", impact = "High",
		summary = "Poor and common (gray/white) gear only.",
		lines = {
			"Use poor/common (gray/white) quality gear only.",
			"Many quest and dungeon rewards become unusable.",
		}, tip = "Inventory management becomes part of the challenge." },
	{ key = "Slow XP Gain", label = "Slow XP", category = "Progression", impact = "Medium",
		summary = "XP gains are reduced to 50%.",
		lines = {
			"XP gains are reduced to 50%.",
			"Mutually exclusive with other XP-rate challenge modes.",
		}, tip = "Great for extended leveling routes." },
	{ key = "Very Slow XP Gain", label = "Very Slow XP", category = "Progression", impact = "High",
		summary = "XP gains are reduced to 25%.",
		lines = {
			"XP gains are reduced to 25%.",
			"Intended for long, methodical progression runs.",
		}, tip = "Usually chosen instead of Slow XP, not with it." },
	{ key = "Quest XP Only", label = "Quest XP Only", category = "Progression", impact = "High",
		summary = "No kill XP - level through quests.",
		lines = {
			"No kill XP; quests are your primary progression source.",
			"Route quality and quest chaining matter much more.",
		}, tip = "Works well for lore/zone-completion playstyles." },
	{ key = "Iron Man Mode", label = "Iron Man", category = "Composite", impact = "Extreme",
		summary = "One life, basic gear, no talents - the classic gauntlet.",
		lines = {
			"No deaths, white/gray only, no talents/glyphs.",
			"No professions (except First Aid), no grouping/dungeons/raids, no PvP/heirlooms.",
		}, tip = "A full ruleset challenge with strict limitations." },
	{ key = "Iron Man+ Mode", label = "Iron Man+", category = "Composite", impact = "Extreme",
		summary = "Iron Man with zero exceptions allowed.",
		lines = {
			"No talents, no glyphs, no grouping/party play.",
			"No dungeons/raids, no professions (no exceptions).",
		}, tip = "Most restrictive variant for veteran challenge runs." },
}

local RANDOM_SUMMARY = {
	key = "Random Challenge Mode", label = "Random Mode", category = "Gamble", impact = "Extreme",
	summary = "Let fate pick one eligible mode - permanently.",
	lines = {
		"Randomly activates ONE of the currently eligible modes.",
		"Only available while no other challenge mode is active.",
	}, tip = "The roll is permanent - confirm twice before it lands.",
}

local function GetOptionForMode(options, modeKey)
	local tokenLower = SafeLower(modeKey)

	-- Prefer the exact bracketed form: "hardcore mode" is a substring of
	-- "semi-hardcore mode", so a plain find can hit the wrong row.
	local bracketed = "[" .. tokenLower .. "]"
	for _, opt in ipairs(options) do
		local plain = SafeLower(StripColorCodes(opt.text))
		if string.find(plain, bracketed, 1, true) then
			return opt
		end
	end

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

-- Bottom-bar navigation: only Back/Close. [Continue]/[CONFIRM]/etc. are
-- rendered as dialog buttons inside the sub-page body.
local function IsNavAction(text)
	if type(text) ~= "string" then
		return false
	end

	return (string.find(text, "[<< Back]", 1, true) ~= nil)
		or (string.find(text, "[Close]", 1, true) ~= nil)
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

-- Extract structured prestige info from the gossip status lines.
local function ParsePrestigeStatus(options)
	local info = { statusLines = {} }

	for _, opt in ipairs(options) do
		local plain = StripColorCodes(opt.text or "")

		local lvl, maxLvl, bonus = string.match(plain, "Prestige Level:%s*(%d+)%s*/%s*(%d+)%s*%((%d+)%% bonus%)")
		if lvl then
			info.level = tonumber(lvl)
			info.maxLevel = tonumber(maxLvl)
			info.bonusPercent = tonumber(bonus)
		else
			local req, cur = string.match(plain, "Reach level (%d+) to prestige %(current: (%d+)%)")
			if req then
				info.requiredLevel = tonumber(req)
				info.currentLevel = tonumber(cur)
			elseif string.find(plain, "meet all requirements to prestige", 1, true) then
				info.canPrestige = true
				table.insert(info.statusLines, opt.text)
			elseif string.find(plain, "maximum prestige level", 1, true) then
				info.atMax = true
				table.insert(info.statusLines, opt.text)
			elseif string.find(plain, "Prestige system currently disabled", 1, true) then
				info.disabled = true
				table.insert(info.statusLines, opt.text)
			elseif string.find(plain, "Prestige requirements not yet met", 1, true) then
				table.insert(info.statusLines, opt.text)
			end
		end
	end

	return info
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
	btn:SetPoint("TOPLEFT", x, -98)
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

local function CreateStatChip(parent, width, labelText)
	local chip = CreateFrame("Frame", nil, parent)
	chip:SetSize(width, 38)

	local bg = chip:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(0, 0, 0, 0.40)

	local edge = chip:CreateTexture(nil, "BORDER")
	edge:SetPoint("BOTTOMLEFT", 0, 0)
	edge:SetPoint("BOTTOMRIGHT", 0, 0)
	edge:SetHeight(2)
	edge:SetTexture(1, 0.82, 0, 0.45)
	chip.edge = edge

	local label = chip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", 9, -5)
	label:SetText(labelText)
	label:SetTextColor(0.62, 0.62, 0.62)
	chip.label = label

	local value = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	value:SetPoint("BOTTOMLEFT", 9, 5)
	value:SetText("-")
	chip.value = value

	return chip
end

local function CreateFlatButton(parent, width, height, label)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(width, height)

	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(0.16, 0.16, 0.16, 0.95)
	btn.bg = bg

	local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	txt:SetPoint("CENTER", 0, 0)
	txt:SetText(label or "")
	txt:SetTextColor(0.92, 0.92, 0.92)
	btn.text = txt

	btn:SetScript("OnEnter", function(self)
		self.bg:SetTexture(0.26, 0.26, 0.26, 0.95)
		self.text:SetTextColor(1, 1, 1)
	end)
	btn:SetScript("OnLeave", function(self)
		self.bg:SetTexture(0.16, 0.16, 0.16, 0.95)
		self.text:SetTextColor(0.92, 0.92, 0.92)
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
	-- Buttons are pooled per kind so cards and dialog buttons never share widgets.
	container._buttonPools = {}
	container._fsPool = {}
	container._texPool = {}
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

	-- Header band: player status (replaces the old Overview tab)
	local playerLine = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	playerLine:SetPoint("TOPLEFT", 26, -46)
	f.playerLine = playerLine

	local playerSub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	playerSub:SetPoint("TOPLEFT", 26, -65)
	playerSub:SetWidth(380)
	playerSub:SetJustifyH("LEFT")
	playerSub:SetTextColor(0.72, 0.72, 0.72)
	f.playerSub = playerSub

	f.chipAlt = CreateStatChip(f, 128, "ALT XP BONUS")
	f.chipAlt:SetPoint("TOPRIGHT", -26, -42)
	f.chipPrestige = CreateStatChip(f, 128, "PRESTIGE")
	f.chipPrestige:SetPoint("RIGHT", f.chipAlt, "LEFT", -8, 0)
	f.chipModes = CreateStatChip(f, 128, "ACTIVE MODES")
	f.chipModes:SetPoint("RIGHT", f.chipPrestige, "LEFT", -8, 0)

	local headerRule = f:CreateTexture(nil, "ARTWORK")
	headerRule:SetPoint("TOPLEFT", 22, -90)
	headerRule:SetPoint("TOPRIGHT", -22, -90)
	headerRule:SetHeight(1)
	headerRule:SetTexture(1, 0.82, 0, 0.30)

	-- Tabs
	local tabStartX = 24
	local tabGap = 6
	f.tabChallenge = CreateTabButton(f, "challenge", "Challenge Modes", tabStartX)
	f.tabPrestige = CreateTabButton(f, "prestige", "Prestige", tabStartX + TAB_WIDTH + tabGap)

	-- Content (full width, scrollable)
	local content = CreateScrollArea(f, CONTENT_WIDTH, CONTENT_HEIGHT, "Content")
	content:SetPoint("TOPLEFT", 22, -132)
	f.content = content

	-- Bottom bar
	local bottomRule = f:CreateTexture(nil, "ARTWORK")
	bottomRule:SetPoint("BOTTOMLEFT", 22, 46)
	bottomRule:SetPoint("BOTTOMRIGHT", -22, 46)
	bottomRule:SetHeight(1)
	bottomRule:SetTexture(1, 0.82, 0, 0.30)

	f.closeBtn = CreateFlatButton(f, 110, 26, "Close")
	f.closeBtn:SetPoint("BOTTOMRIGHT", -22, 12)
	f.closeBtn:SetScript("OnClick", function()
		CloseGossip()
	end)

	f.backBtn = CreateFlatButton(f, 110, 26, "<< Back")
	f.backBtn:SetPoint("RIGHT", f.closeBtn, "LEFT", -8, 0)
	f.backBtn:Hide()

	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("BOTTOMLEFT", 26, 18)
	hint:SetText("Hover a mode for its full rules. Challenge modes are permanent once confirmed.")
	hint:SetTextColor(0.62, 0.62, 0.62)
	f.hint = hint

	self.frame = f

	self:SelectTab("challenge")
end

function UI:ApplyTabVisuals()
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

	ApplyTab(f.tabChallenge, self.currentTab == "challenge")
	ApplyTab(f.tabPrestige, self.currentTab == "prestige")
end

function UI:SelectTab(tabId)
	self.currentTab = tabId
	self:ApplyTabVisuals()
	self:Refresh()
end

-- =============================================================================
-- Widget pools
-- =============================================================================

function UI:ClearScrollChild(child)
	if not child then
		return
	end

	local container = child:GetParent() -- ScrollFrame
	container = container and container:GetParent() -- our container frame

	if container and container._buttonPools then
		for _, pool in pairs(container._buttonPools) do
			for i = 1, (pool.used or 0) do
				local b = pool.list[i]
				if b then
					b:Hide()
				end
			end
			pool.used = 0
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

		container._fsUsed = 0
		container._texUsed = 0
	end
end

local function AcquireButton(container, parent, kind)
	kind = kind or "generic"
	local pool = container._buttonPools[kind]
	if not pool then
		pool = { list = {}, used = 0 }
		container._buttonPools[kind] = pool
	end

	pool.used = pool.used + 1
	local b = pool.list[pool.used]
	if not b then
		b = CreateFrame("Button", nil, parent)
		pool.list[pool.used] = b
	end

	b:SetParent(parent)
	b:ClearAllPoints()
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
	fs:ClearAllPoints()
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

local function GetContainer(parent)
	local container = parent:GetParent() -- ScrollFrame
	return container and container:GetParent()
end

function UI:AddText(parent, y, text, opts)
	opts = opts or {}
	local fs = AcquireFontString(GetContainer(parent), parent)
	fs:SetFontObject(opts.font or GameFontHighlightSmall)
	fs:SetPoint("TOPLEFT", opts.x or 6, y)
	fs:SetWidth(opts.width or (CHILD_WIDTH - 12))
	fs:SetJustifyH(opts.justify or "LEFT")
	fs:SetText(text)
	fs:SetTextColor(opts.r or 1, opts.g or 1, opts.b or 1)
	return fs
end

function UI:AddRule(parent, y, width, xOffset, r, g, b, a, thickness, layer, subLevel)
	local tex = AcquireTexture(GetContainer(parent), parent, layer or "ARTWORK", subLevel or 1)
	tex:ClearAllPoints()
	tex:SetTexture(r or 1, g or 1, b or 1, a or 1)
	tex:SetPoint("TOPLEFT", xOffset or 6, y)
	tex:SetSize(width or (CHILD_WIDTH - 12), thickness or 1)
	return tex
end

-- =============================================================================
-- Mode cards
-- =============================================================================

local function EnsureCardWidgets(btn)
	if btn._isCard then
		return
	end
	btn._isCard = true

	btn.bg = btn:CreateTexture(nil, "BACKGROUND")
	btn.bg:SetAllPoints()

	btn.accent = btn:CreateTexture(nil, "BORDER")
	btn.accent:SetPoint("TOPLEFT", 0, 0)
	btn.accent:SetPoint("BOTTOMLEFT", 0, 0)
	btn.accent:SetWidth(3)

	btn.nameFS = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	btn.nameFS:SetPoint("TOPLEFT", 11, -8)
	btn.nameFS:SetWidth(CARD_WIDTH - 120)
	btn.nameFS:SetJustifyH("LEFT")

	btn.badgeFS = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	btn.badgeFS:SetPoint("TOPRIGHT", -9, -10)

	btn.summaryFS = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	btn.summaryFS:SetPoint("TOPLEFT", 11, -27)
	btn.summaryFS:SetWidth(CARD_WIDTH - 22)
	btn.summaryFS:SetJustifyH("LEFT")
	btn.summaryFS:SetTextColor(0.82, 0.82, 0.82)

	btn.metaFS = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	btn.metaFS:SetPoint("BOTTOMLEFT", 11, 7)
	btn.metaFS:SetJustifyH("LEFT")

	btn:SetScript("OnClick", function(self)
		if self._gossipIndex then
			SelectGossipOption(self._gossipIndex)
			UI:QueueRefresh()
		end
	end)

	btn:SetScript("OnEnter", function(self)
		if self._hoverBg then
			self.bg:SetTexture(self._hoverBg[1], self._hoverBg[2], self._hoverBg[3], self._hoverBg[4])
		end
		UI:ShowModeTooltip(self)
	end)

	btn:SetScript("OnLeave", function(self)
		if self._normalBg then
			self.bg:SetTexture(self._normalBg[1], self._normalBg[2], self._normalBg[3], self._normalBg[4])
		end
		GameTooltip:Hide()
	end)
end

function UI:ShowModeTooltip(card)
	local m = card._mode
	if not m then
		return
	end

	GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(m.label, 1, 0.82, 0)

	local impactColor = IMPACT_COLORS[m.impact] or "cccccc"
	GameTooltip:AddLine(
		string.format("%s  -  Impact: |cff%s%s|r", m.category or "Challenge", impactColor, m.impact or "Mixed"),
		0.75, 0.75, 0.75
	)
	GameTooltip:AddLine(" ")

	for _, line in ipairs(m.lines or {}) do
		GameTooltip:AddLine("- " .. line, 1, 1, 1, true)
	end

	if m.tip then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Tip: " .. m.tip, 0.48, 0.70, 1, true)
	end

	GameTooltip:AddLine(" ")
	if card._stateKind == "active" then
		GameTooltip:AddLine("This mode is active on this character.", 0.33, 1, 0.60)
	elseif card._stateKind == "available" then
		GameTooltip:AddLine("Click to review and activate.", 0.48, 0.84, 1)
	elseif card._stateKind == "conditional" then
		GameTooltip:AddLine(card._lockReason or "Currently blocked by an active mode.", 1, 0.80, 0.44, true)
	else
		GameTooltip:AddLine("Not offered by the manager right now.", 0.62, 0.62, 0.62, true)
	end

	GameTooltip:Show()
end

function UI:AddModeCard(parent, x, y, m, opt, isActive)
	local container = GetContainer(parent)
	local btn = AcquireButton(container, parent, "card")
	EnsureCardWidgets(btn)

	btn:SetSize(CARD_WIDTH, CARD_HEIGHT)
	btn:SetPoint("TOPLEFT", x, y)

	local actionAllowed = opt and IsModeOptionActionable(opt.text) and not isActive
	local visual = GetModeVisualState(isActive, actionAllowed, opt ~= nil)

	local stateKind = "locked"
	if isActive then
		stateKind = "active"
	elseif actionAllowed then
		stateKind = "available"
	elseif opt then
		stateKind = "conditional"
	end

	btn._mode = m
	btn._stateKind = stateKind
	btn._gossipIndex = actionAllowed and opt.index or nil
	btn._normalBg = visual.bg
	btn._hoverBg = visual.hover
	btn._lockReason = nil

	if stateKind == "conditional" and opt then
		local plain = StripColorCodes(opt.text)
		local reason = string.match(plain, "%]%s*%-%s*(.+)$")
		if reason then
			btn._lockReason = reason .. "."
		end
	end

	btn.bg:SetTexture(visual.bg[1], visual.bg[2], visual.bg[3], visual.bg[4])
	btn.accent:SetTexture(visual.accent[1], visual.accent[2], visual.accent[3], visual.accent[4])
	btn.nameFS:SetText(m.label)
	btn.nameFS:SetTextColor(visual.nameColor[1], visual.nameColor[2], visual.nameColor[3])
	btn.badgeFS:SetText(visual.label)
	btn.summaryFS:SetText(m.summary or "")

	local impactColor = IMPACT_COLORS[m.impact] or "cccccc"
	btn.metaFS:SetText(string.format(
		"|cff8a8a8a%s|r  |cff5a5a5a-|r  |cff%s%s|r",
		m.category or "Challenge",
		impactColor,
		m.impact or "Mixed"
	))

	btn:EnableMouse(true)
	return btn
end

-- =============================================================================
-- Dialog/action buttons (sub-pages, prestige actions)
-- =============================================================================

local function EnsureDialogButtonWidgets(btn)
	if btn._isDialog then
		return
	end
	btn._isDialog = true

	btn.bg = btn:CreateTexture(nil, "BACKGROUND")
	btn.bg:SetAllPoints()

	btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	btn.text:SetPoint("CENTER", 0, 0)
	btn.text:SetWidth(0)

	btn:SetScript("OnEnter", function(self)
		self.bg:SetTexture(0.28, 0.28, 0.28, 0.95)
	end)
	btn:SetScript("OnLeave", function(self)
		self.bg:SetTexture(0.17, 0.17, 0.17, 0.95)
	end)
end

function UI:AddDialogButton(parent, y, text, onClick, width, xOffset)
	local container = GetContainer(parent)
	local btn = AcquireButton(container, parent, "dialog")
	EnsureDialogButtonWidgets(btn)

	width = width or 420
	btn:SetSize(width, 26)
	btn:SetPoint("TOPLEFT", xOffset or ((CHILD_WIDTH - width) / 2), y)
	btn.bg:SetTexture(0.17, 0.17, 0.17, 0.95)
	btn.text:SetText(text)
	btn:EnableMouse(true)
	btn:SetScript("OnClick", onClick)
	return btn
end

-- =============================================================================
-- Rendering: header band
-- =============================================================================

function UI:UpdateHeader(progress, activeModes)
	local f = self.frame
	if not f then
		return
	end

	local playerName = UnitName("player") or "?"
	local playerLevel = UnitLevel("player") or 0
	local _, classFile = UnitClass("player")
	local classColor = (classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]) or { r = 1, g = 1, b = 1 }
	f.playerLine:SetText(string.format("%s  |cffaaaaaa-  Level %d|r", playerName, playerLevel))
	f.playerLine:SetTextColor(classColor.r or 1, classColor.g or 1, classColor.b or 1)

	if #activeModes > 0 then
		f.playerSub:SetText("Running: |cffffd700" .. table.concat(activeModes, ", ") .. "|r")
	else
		f.playerSub:SetText("No challenge modes active on this character.")
	end

	f.chipModes.value:SetText(tostring(#activeModes))
	if #activeModes > 0 then
		f.chipModes.value:SetTextColor(0.33, 1, 0.60)
	else
		f.chipModes.value:SetTextColor(1, 1, 1)
	end

	local prestigeText = "-"
	if progress.prestigeLevel then
		prestigeText = tostring(progress.prestigeLevel)
		if progress.prestigeXP and progress.prestigeXPMax then
			prestigeText = prestigeText .. string.format(" |cff888888(%s/%s)|r", tostring(progress.prestigeXP), tostring(progress.prestigeXPMax))
		end
	end
	f.chipPrestige.value:SetText(prestigeText)

	if progress.altBonusPercent then
		local altText = "+" .. tostring(progress.altBonusPercent) .. "%"
		if progress.altBonusLevel then
			altText = altText .. string.format(" |cff888888(T%s)|r", tostring(progress.altBonusLevel))
		end
		f.chipAlt.value:SetText(altText)
	else
		f.chipAlt.value:SetText("-")
	end

	local hintText = "Hover a mode for its full rules. Challenge modes are permanent once confirmed."
	if progress._lastUpdate and progress._lastUpdate > 0 then
		local age = time() - (progress._lastUpdate or 0)
		hintText = hintText .. "  |cff555555(data " .. FormatAgeSeconds(age) .. " old)|r"
	end
	f.hint:SetText(hintText)
end

-- =============================================================================
-- Rendering: bottom bar
-- =============================================================================

function UI:UpdateBottomBar(options)
	local f = self.frame
	if not f then
		return
	end

	local backOpt = nil
	for _, opt in ipairs(options) do
		if type(opt.text) == "string" and string.find(opt.text, "[<< Back]", 1, true) then
			backOpt = opt
			break
		end
	end

	if backOpt then
		f.backBtn:Show()
		f.backBtn:SetScript("OnClick", function()
			SelectGossipOption(backOpt.index)
			UI:QueueRefresh()
		end)
	else
		f.backBtn:Hide()
	end
end

-- =============================================================================
-- Rendering: challenge mode grid
-- =============================================================================

function UI:RenderChallengeTab(child, options, activeSet)
	local y = -2

	local availableCount = 0
	for _, m in ipairs(MODE_SUMMARIES) do
		local opt = GetOptionForMode(options, m.key)
		if opt and IsModeOptionActionable(opt.text) then
			availableCount = availableCount + 1
		end
	end

	local intro = self:AddText(
		child,
		y,
		string.format(
			"|cffbfbfbfPick your permanent challenge - hover a card for the full ruleset.|r  |cff7a7a7a%d of %d selectable|r",
			availableCount,
			#MODE_SUMMARIES
		)
	)
	y = y - (intro:GetStringHeight() + 8)

	local gridTop = y
	local cardIndex = 0

	local function PlaceCard(m, opt, isActive)
		local col = cardIndex % 2
		local row = math.floor(cardIndex / 2)
		local x = col * (CARD_WIDTH + CARD_GAP)
		local cardY = gridTop - row * (CARD_HEIGHT + CARD_GAP)
		self:AddModeCard(child, x, cardY, m, opt, isActive)
		cardIndex = cardIndex + 1
		return cardY - CARD_HEIGHT
	end

	local lowestY = gridTop
	for _, m in ipairs(MODE_SUMMARIES) do
		local opt = GetOptionForMode(options, m.key)
		local bottom = PlaceCard(m, opt, activeSet[m.label])
		if bottom < lowestY then
			lowestY = bottom
		end
	end

	local randomOpt = GetOptionForMode(options, "Random Challenge Mode")
	local bottom = PlaceCard(RANDOM_SUMMARY, randomOpt, false)
	if bottom < lowestY then
		lowestY = bottom
	end

	y = lowestY - 10

	-- Catch-all: render any actionable, non-navigation option the grid didn't
	-- claim (future server additions stay reachable).
	local claimed = {}
	for _, m in ipairs(MODE_SUMMARIES) do
		local opt = GetOptionForMode(options, m.key)
		if opt then
			claimed[opt.index] = true
		end
	end
	if randomOpt then
		claimed[randomOpt.index] = true
	end

	for _, opt in ipairs(options) do
		if IsActionCandidate(opt.text)
			and not claimed[opt.index]
			and not IsNavAction(opt.text)
			and not IsPrestigeRelated(opt.text)
			and not IsDecorativeOption(opt.text)
			and not IsUnclickableStatus(opt.text) then
			self:AddDialogButton(child, y, opt.text, function()
				SelectGossipOption(opt.index)
				UI:QueueRefresh()
			end)
			y = y - 32
		end
	end

	return y
end

-- =============================================================================
-- Rendering: prestige tab
-- =============================================================================

function UI:RenderPrestigeTab(child, options, progress)
	local y = -4
	local info = ParsePrestigeStatus(options)

	local level = info.level or progress.prestigeLevel or 0
	local maxLevel = info.maxLevel

	local levelText
	if maxLevel then
		levelText = string.format("Prestige %d |cff8a8a8a/ %d|r", level, maxLevel)
	else
		levelText = string.format("Prestige %d", level)
	end
	local lvlFS = self:AddText(child, y, levelText, { font = GameFontNormalLarge, r = 1, g = 0.82, b = 0 })
	y = y - (lvlFS:GetStringHeight() + 4)

	if info.bonusPercent then
		local bonusFS = self:AddText(
			child,
			y,
			string.format("Permanent bonus: |cff54ff9a+%d%%|r to all stats", info.bonusPercent),
			{ r = 0.85, g = 0.85, b = 0.85 }
		)
		y = y - (bonusFS:GetStringHeight() + 12)
	else
		y = y - 8
	end

	-- Progress bar toward the next prestige (level requirement).
	local barWidth = 480
	local barHeight = 16

	local barLabelText = "Progress to next prestige"
	if info.atMax then
		barLabelText = "Maximum prestige reached"
	elseif info.disabled then
		barLabelText = "Prestige system disabled"
	end
	local barLabel = self:AddText(child, y, barLabelText, { r = 0.72, g = 0.72, b = 0.72 })
	y = y - (barLabel:GetStringHeight() + 4)

	local pct = 0
	local barText = ""
	local playerLevel = UnitLevel("player") or 0
	if info.atMax then
		pct = 1
		barText = "Complete"
	elseif info.disabled then
		pct = 0
		barText = "Disabled"
	elseif info.canPrestige then
		pct = 1
		barText = "Ready to prestige!"
	elseif info.requiredLevel and info.requiredLevel > 0 then
		local cur = info.currentLevel or playerLevel
		pct = math.min(1, cur / info.requiredLevel)
		barText = string.format("Level %d / %d", cur, info.requiredLevel)
	else
		barText = string.format("Level %d", playerLevel)
	end

	local barBg = self:AddRule(child, y, barWidth, 6, 0.05, 0.05, 0.05, 0.90, barHeight, "BACKGROUND", 1)
	if pct > 0 then
		local fillR, fillG, fillB = 0.80, 0.62, 0.10
		if pct >= 1 then
			fillR, fillG, fillB = 0.24, 0.70, 0.36
		end
		self:AddRule(child, y - 1, math.max(2, (barWidth - 2) * pct), 7, fillR, fillG, fillB, 0.95, barHeight - 2, "BORDER", 1)
	end
	local barFS = self:AddText(child, y - 2, barText, { x = 6, width = barWidth, justify = "CENTER", font = GameFontNormalSmall })
	y = y - (barHeight + 12)

	-- Server status lines (anything informative we did not fold into the bar).
	for _, line in ipairs(info.statusLines) do
		local fs = self:AddText(child, y, line)
		y = y - (fs:GetStringHeight() + 4)
	end
	if #info.statusLines > 0 then
		y = y - 6
	end

	-- Actions offered by the manager ([Prestige Overview], [Prestige Reset], ...).
	local hasActions = false
	for _, opt in ipairs(options) do
		if IsPrestigeRelated(opt.text)
			and IsActionCandidate(opt.text)
			and not IsNavAction(opt.text)
			and not IsDecorativeOption(opt.text)
			and not IsUnclickableStatus(opt.text) then
			self:AddDialogButton(child, y, opt.text, function()
				SelectGossipOption(opt.index)
				UI:QueueRefresh()
			end, 420, 6)
			y = y - 32
			hasActions = true
		end
	end
	if hasActions then
		y = y - 6
	end

	local rule = self:AddRule(child, y, CHILD_WIDTH - 12, 6, 0.42, 0.42, 0.42, 0.70, 1)
	y = y - 12

	local howHdr = self:AddText(child, y, "How Prestige Works", { font = GameFontNormal, r = 1, g = 0.82, b = 0 })
	y = y - (howHdr:GetStringHeight() + 6)

	local howLines = {
		"Reach the level cap to unlock prestige, then reset back to level 1.",
		"Every prestige grants a permanent bonus to all stats - forever.",
		"Max-level characters also grant an account-wide alt XP bonus for your other characters.",
	}
	for _, line in ipairs(howLines) do
		local fs = self:AddText(child, y, "- " .. line, { r = 0.72, g = 0.72, b = 0.72 })
		y = y - (fs:GetStringHeight() + 3)
	end

	return y
end

-- =============================================================================
-- Rendering: server sub-pages (mode details, confirmations, random flow)
-- =============================================================================

function UI:RenderSubPage(child, options)
	local y = -10
	local textWidth = 620
	local textX = (CHILD_WIDTH - textWidth) / 2

	for _, opt in ipairs(options) do
		local text = opt.text or ""
		local plain = StripColorCodes(text)

		if IsNavAction(text) then
			-- Back/Close live in the bottom bar.
		elseif IsActionCandidate(text) and not IsDecorativeOption(text) and not IsUnclickableStatus(text) then
			y = y - 6
			local lowerPlain = SafeLower(plain)
			local onClick
			if string.find(lowerPlain, "confirm prestige", 1, true) then
				-- Extra safety: prestige reset requires typing PRESTIGE.
				local idx = opt.index
				onClick = function()
					UI._confirmIndex = idx
					UI.confirmationStep = 1
					UI:Refresh()
				end
			else
				local idx = opt.index
				onClick = function()
					SelectGossipOption(idx)
					UI:QueueRefresh()
				end
			end
			self:AddDialogButton(child, y, text, onClick)
			y = y - 32
		elseif plain == "" or string.match(plain, "^%s*$") then
			y = y - 8
		elseif string.find(plain, "---", 1, true) then
			self:AddRule(child, y - 2, textWidth, textX, 0.42, 0.42, 0.42, 0.60, 1)
			y = y - 12
		elseif string.find(plain, "===", 1, true) then
			local headerText = string.gsub(plain, "=", "")
			headerText = string.gsub(headerText, "^%s*(.-)%s*$", "%1")
			local fs = self:AddText(child, y, headerText, {
				font = GameFontNormalLarge,
				x = textX,
				width = textWidth,
				justify = "CENTER",
				r = 1, g = 0.82, b = 0,
			})
			y = y - (fs:GetStringHeight() + 10)
		else
			local fs = self:AddText(child, y, text, {
				x = textX,
				width = textWidth,
				justify = "CENTER",
				font = GameFontHighlight,
			})
			y = y - (fs:GetStringHeight() + 5)
		end
	end

	return y
end

-- =============================================================================
-- Rendering: typed prestige confirmation
-- =============================================================================

function UI:RenderPrestigeConfirm(child)
	local y = -16
	local textWidth = 620
	local textX = (CHILD_WIDTH - textWidth) / 2

	local function CenterText(text, opts)
		opts = opts or {}
		opts.x = textX
		opts.width = textWidth
		opts.justify = "CENTER"
		local fs = self:AddText(child, y, text, opts)
		y = y - (fs:GetStringHeight() + (opts.gap or 6))
		return fs
	end

	CenterText("WARNING: PERMANENT ACTION", { font = GameFontNormalLarge, r = 1, g = 0.25, b = 0.25, gap = 12 })
	CenterText("You are about to Prestige. This will reset your level to 1.", { font = GameFontHighlight })
	CenterText("Gear, Gold, and Skills may be lost depending on server settings.", { font = GameFontHighlight, gap = 16 })
	CenterText("Type |cffffd700PRESTIGE|r to confirm:", { font = GameFontHighlight, gap = 10 })

	if not self.confirmInput then
		local eb = CreateFrame("EditBox", nil, child)
		eb:SetFontObject(GameFontHighlight)
		eb:SetSize(160, 24)
		eb:SetAutoFocus(false)
		eb:SetMaxLetters(12)
		eb:SetJustifyH("CENTER")
		eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
		eb:SetScript("OnEnterPressed", function(self)
			if self:GetText() == "PRESTIGE" and UI._confirmIndex then
				local idx = UI._confirmIndex
				UI._confirmIndex = nil
				UI.confirmationStep = 0
				SelectGossipOption(idx)
				UI:QueueRefresh()
			end
		end)

		local bg = eb:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetTexture(0.08, 0.08, 0.08, 1)

		self.confirmInput = eb
	end

	self.confirmInput:SetParent(child)
	self.confirmInput:ClearAllPoints()
	self.confirmInput:SetPoint("TOPLEFT", (CHILD_WIDTH - 160) / 2, y)
	self.confirmInput:SetText("")
	self.confirmInput:Show()
	self.confirmInput:SetFocus()
	y = y - 34

	self:AddDialogButton(child, y, "|cffff8787Cancel|r", function()
		UI.confirmationStep = 0
		UI._confirmIndex = nil
		UI:Refresh()
	end, 160)
	y = y - 32

	return y
end

-- =============================================================================
-- Refresh
-- =============================================================================

function UI:Refresh()
	if not self.frame or not self.frame:IsShown() then
		return
	end

	local child = self.frame.content.child
	self:ClearScrollChild(child)

	if self.confirmInput and self.confirmationStep ~= 1 then
		self.confirmInput:Hide()
	end

	local options = GetGossipOptionsList()

	-- If gossip no longer matches the manager, close.
	if not GossipLooksLikeChallengeManager(options) then
		self:Close()
		return
	end

	local progress = (DCWelcome and DCWelcome.GetProgress and DCWelcome:GetProgress()) or (DCWelcome and DCWelcome.Progress) or {}
	local activeModes = GetActiveChallengeModesFromAuras()
	local activeSet = {}
	for _, modeName in ipairs(activeModes) do
		activeSet[modeName] = true
	end

	self:UpdateHeader(progress, activeModes)
	self:UpdateBottomBar(options)

	-- Sub-pages (mode details, confirmations) replace the tab content; follow
	-- the gossip state and highlight the matching tab.
	local onMainMenu = GossipHasToken(options, MANAGER_DETECT_TEXT)
	if not onMainMenu and self.confirmationStep ~= 1 then
		local prestigeSub = false
		for _, opt in ipairs(options) do
			if IsPrestigeRelated(opt.text) then
				prestigeSub = true
				break
			end
		end
		self.currentTab = prestigeSub and "prestige" or "challenge"
		self:ApplyTabVisuals()
	end

	local y
	if self.confirmationStep == 1 then
		y = self:RenderPrestigeConfirm(child)
	elseif not onMainMenu then
		y = self:RenderSubPage(child, options)
	elseif self.currentTab == "prestige" then
		y = self:RenderPrestigeTab(child, options, progress)
	else
		y = self:RenderChallengeTab(child, options, activeSet)
	end

	child:SetHeight(math.max(1, math.abs(y or 0) + 4))
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
	self.confirmationStep = 0
	self._confirmIndex = nil
	if self.confirmInput then
		self.confirmInput:Hide()
	end
	GameTooltip:Hide()
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
