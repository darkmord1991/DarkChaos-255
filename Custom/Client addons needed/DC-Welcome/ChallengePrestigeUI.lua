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

local FRAME_WIDTH = 720
local FRAME_HEIGHT = 520
local TAB_HEIGHT = 26

local LEFT_WIDTH = 290
local RIGHT_WIDTH = 380
local CONTENT_HEIGHT = 400

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

-- =============================================================================
-- Helpers
-- =============================================================================

local function SafeLower(s)
	if type(s) ~= "string" then
		return ""
	end
	return string.lower(s)
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

	if tabId == "prestige" then
		return isPrestige
	end

	-- challenge tab
	return not isPrestige
end

local function HideGossipFrameInput()
	if GossipFrame and GossipFrame:IsShown() then
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
	btn:SetSize(120, TAB_HEIGHT)
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

local function CreateScrollArea(parent, width, height)
	local container = CreateFrame("Frame", nil, parent)
	container:SetSize(width, height)

	local scroll = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", -26, 0)

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(width - 26, 1)
	scroll:SetScrollChild(child)

	container.scroll = scroll
	container.child = child

	return container
end

function UI:EnsureFrame()
	if self.frame then
		return
	end

	local f = CreateFrame("Frame", "DCWelcome_ChallengePrestigeFrame", UIParent)
	f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
	f:SetPoint("CENTER", 0, 0)
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 }
	})
	f:SetBackdropColor(0, 0, 0, 0.92)
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
		UI:Close()
	end)

	-- Tabs
	f.tabChallenge = CreateTabButton(f, "challenge", "Challenge Modes", 22)
	f.tabPrestige = CreateTabButton(f, "prestige", "Prestige", 22 + 125)

	-- Left: Actions
	local leftTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	leftTitle:SetPoint("TOPLEFT", 24, -76)
	leftTitle:SetText("Actions")
	leftTitle:SetTextColor(1, 0.82, 0)

	local left = CreateScrollArea(f, LEFT_WIDTH, CONTENT_HEIGHT)
	left:SetPoint("TOPLEFT", 20, -96)
	f.left = left

	-- Right: Details
	local rightTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	rightTitle:SetPoint("TOPLEFT", 20 + LEFT_WIDTH + 28, -76)
	rightTitle:SetText("Details")
	rightTitle:SetTextColor(1, 0.82, 0)

	local right = CreateScrollArea(f, RIGHT_WIDTH, CONTENT_HEIGHT)
	right:SetPoint("TOPLEFT", 20 + LEFT_WIDTH + 24, -96)
	f.right = right

	-- Footer hint
	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("BOTTOMLEFT", 20, 16)
	hint:SetText("Tip: this panel mirrors the server menu. Use [<< Back] to return.")
	hint:SetTextColor(0.75, 0.75, 0.75)

	self.frame = f

	self:SelectTab("challenge")
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

	self:Refresh()
end

-- =============================================================================
-- Rendering
-- =============================================================================

function UI:ClearScrollChild(child)
	if not child then
		return
	end

	if child._items then
		for _, item in ipairs(child._items) do
			item:Hide()
			item:SetParent(nil)
		end
	end

	child._items = {}
end

function UI:AddActionButton(parent, y, text, gossipIndex)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(LEFT_WIDTH - 40, 18)
	btn:SetPoint("TOPLEFT", 4, y)

	local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	fs:SetPoint("LEFT", 0, 0)
	fs:SetWidth(LEFT_WIDTH - 44)
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	fs:SetTextColor(0.9, 0.9, 0.9)

	btn:SetScript("OnClick", function()
		if type(gossipIndex) == "number" and gossipIndex > 0 then
			SelectGossipOption(gossipIndex)
			UI:QueueRefresh()
		end
	end)

	btn:SetScript("OnEnter", function()
		fs:SetTextColor(1, 1, 1)
	end)

	btn:SetScript("OnLeave", function()
		fs:SetTextColor(0.9, 0.9, 0.9)
	end)

	return btn
end

function UI:AddDetailLine(parent, y, text)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	fs:SetPoint("TOPLEFT", 4, y)
	fs:SetWidth(RIGHT_WIDTH - 44)
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	return fs
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

	-- If gossip no longer matches the manager, close.
	if not GossipLooksLikeChallengeManager(options) then
		self:Close()
		return
	end

	-- Details panel: show GetGossipText + all option lines (mirrors server output)
	local yDetail = -4
	local gossipText = GetGossipText()
	if type(gossipText) == "string" and gossipText ~= "" then
		local t = self:AddDetailLine(rightChild, yDetail, gossipText)
		table.insert(rightChild._items, t)
		yDetail = yDetail - (t:GetStringHeight() + 8)
	end

	for _, opt in ipairs(options) do
		local t = self:AddDetailLine(rightChild, yDetail, opt.text)
		table.insert(rightChild._items, t)
		yDetail = yDetail - (t:GetStringHeight() + 4)
	end

	rightChild:SetHeight(math.max(1, math.abs(yDetail) + 20))

	-- Actions panel: show actionable lines filtered by tab
	local yAction = -4
	for _, opt in ipairs(options) do
		if IsActionCandidate(opt.text) and ShouldShowInTab(self.currentTab, opt) then
			local b = self:AddActionButton(leftChild, yAction, opt.text, opt.index)
			table.insert(leftChild._items, b)
			yAction = yAction - 20
		end
	end

	if #leftChild._items == 0 then
		local none = self:AddDetailLine(leftChild, -4, "No actions available on this tab.")
		table.insert(leftChild._items, none)
		leftChild:SetHeight(40)
	else
		leftChild:SetHeight(math.max(1, math.abs(yAction) + 20))
	end
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
	self:Refresh()
end

function UI:Close()
	if self.frame then
		self.frame:Hide()
	end
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