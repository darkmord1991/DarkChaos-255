--[[
	DC-Welcome PrestigeTalents.lua
	Prestige talent window, laid out after WoW Forever's Legacy window
	(Blizzard_LegacySystem): three side tabs - Reward Track, Challenges, Tree.

	Server side: src/server/scripts/DC/Progression/Prestige/dc_prestige_talents.cpp,
	addon module PRES:
	  CMSG 0x03 GET_TALENTS, 0x05 RESET_TALENTS, 0x06 GET_CHALLENGES, 0x07 GET_REWARDS,
	       0x08 CLAIM_REWARD {threshold}, 0x09 APPLY_TALENTS {ranks = {{id, rank}, ...}}
	  SMSG 0x13 TALENTS, 0x14 TALENT_RESULT, 0x15 CHALLENGES, 0x16 REWARDS, 0x17 CHALLENGE_EARNED

	- Points are earned account-wide: one per prestige level on any character, plus
	  the points of every completed challenge (achievement). Each character spends
	  the pool on its own, up to the server's spend cap.
	- The account total also unlocks the reward track, claimed once per account.
	- Tree changes are staged locally (left click adds, right click removes a staged
	  point) and committed with Apply; Undo drops them, Reset refunds everything.
	- Trees, talents, challenges and rewards come from the server; nothing is
	  hard-coded here.

	Open with /ptalents (or /prestigetalents), or from the Prestige tab of the
	Challenge Mode Manager window.

	WoW client: 3.3.5 (Interface 30300)
]]

DCWelcome = DCWelcome or {}

local PT = {}
DCWelcome.PrestigeTalents = PT

-- =============================================================================
-- Constants
-- =============================================================================

local MODULE = "PRES"
local CMSG_GET_TALENTS = 0x03
local CMSG_RESET_TALENTS = 0x05
local CMSG_GET_CHALLENGES = 0x06
local CMSG_GET_REWARDS = 0x07
local CMSG_CLAIM_REWARD = 0x08
local CMSG_APPLY_TALENTS = 0x09
local SMSG_TALENTS = 0x13
local SMSG_TALENT_RESULT = 0x14
local SMSG_CHALLENGES = 0x15
local SMSG_REWARDS = 0x16
local SMSG_CHALLENGE_EARNED = 0x17

local PAGE_REWARDS = 1
local PAGE_CHALLENGES = 2
local PAGE_TREE = 3

local FRAME_WIDTH = 800
local FRAME_HEIGHT = 540
local CONTENT_LEFT = 20
local CONTENT_TOP = -52
local CONTENT_WIDTH = FRAME_WIDTH - 40
local CONTENT_HEIGHT = 440

local TREE_CARD_WIDTH = 170
local TREE_CARD_HEIGHT = 70
local TREE_PANEL_WIDTH = CONTENT_WIDTH - TREE_CARD_WIDTH - 20
local TREE_PANEL_HEIGHT = 380
local NODE_SIZE = 42
local NODE_ROW_SPACING = 110
local NODE_TOP = -40

local ICON_PATH = "Interface\\Icons\\"
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local BADGE_TEXTURE = "Interface\\GossipFrame\\AvailableQuestIcon"
local CHECK_TEXTURE = "Interface\\RAIDFRAME\\ReadyCheck-Ready"

local TAB_INFO = {
	[PAGE_REWARDS] = { icon = "Interface\\Icons\\INV_Misc_Coin_17", tooltip = "Reward Track" },
	[PAGE_CHALLENGES] = { icon = "Interface\\Icons\\Achievement_Quests_Completed_08", tooltip = "Challenges" },
	[PAGE_TREE] = { icon = "Interface\\Icons\\Achievement_Level_80", tooltip = "Prestige Talents" },
}

local PAGE_TITLES = {
	[PAGE_REWARDS] = "Prestige Reward Track",
	[PAGE_CHALLENGES] = "Prestige Challenges",
	[PAGE_TREE] = "Prestige Talents",
}

-- =============================================================================
-- State
-- =============================================================================

PT.state = {
	loaded = false,
	enabled = true,
	prestigePoints = 0,
	challengePoints = 0,
	accountPoints = 0,
	spendCap = 0,
	spent = 0,
	resetCost = 0,
	trees = {},
	talents = {},
	byId = {},
	staged = {},        -- talent id -> staged rank (only entries above the committed rank)
}

PT.challenges = {
	loaded = false,
	list = {},
	categories = {},    -- ordered { name, items = {...} }
}

PT.rewards = {
	loaded = false,
	accountPoints = 0,
	list = {},
}

PT.currentPage = PAGE_TREE
PT.selectedTree = 0
PT.selectedCategory = nil

-- =============================================================================
-- Helpers
-- =============================================================================

local function GetProtocol()
	return rawget(_G, "DCAddonProtocol")
end

local function Request(opcode, payload)
	local DC = GetProtocol()
	if DC and DC.Request then
		DC:Request(MODULE, opcode, payload or {})
	end
end

-- 3.3.5 has neither Region:SetShown nor Button:SetEnabled.
local function ShowIf(region, shown)
	if shown then
		region:Show()
	else
		region:Hide()
	end
end

local function EnableIf(button, enabled)
	if enabled then
		button:Enable()
	else
		button:Disable()
	end
end

local function FormatValue(value)
	if math.floor(value) == value then
		return tostring(value)
	end
	return string.format("%.1f", value)
end

local function FormatDescription(talent, rank)
	local value = (talent.value or 0) * math.max(rank, 1)
	return (string.gsub(talent.desc or "", "{v}", FormatValue(value)))
end

local function FormatMoney(copper)
	if not copper or copper <= 0 then
		return "free"
	end
	local gold = math.floor(copper / 10000)
	local silver = math.floor((copper % 10000) / 100)
	local cop = copper % 100
	local parts = {}
	if gold > 0 then table.insert(parts, gold .. "g") end
	if silver > 0 then table.insert(parts, silver .. "s") end
	if cop > 0 then table.insert(parts, cop .. "c") end
	return table.concat(parts, " ")
end

local function CreateBackdropFrame(parent, bgAlpha)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0, 0, 0, bgAlpha or 0.55)
	frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.9)
	return frame
end

-- Challenges are account-wide, and so is DCWelcomeDB (SavedVariables).
local function GetChallengeDB()
	DCWelcomeDB = DCWelcomeDB or {}
	DCWelcomeDB.prestigeChallenges = DCWelcomeDB.prestigeChallenges or {}
	local db = DCWelcomeDB.prestigeChallenges
	db.unviewed = db.unviewed or {}
	return db
end

-- =============================================================================
-- Tree staging
-- =============================================================================

function PT:GetRank(talent)
	return self.state.staged[talent.id] or talent.rank
end

function PT:StagedSpent()
	local spent = 0
	for _, talent in ipairs(self.state.talents) do
		spent = spent + self:GetRank(talent)
	end
	return spent
end

function PT:StagedTreeSpent(tree)
	local spent = 0
	for _, talent in ipairs(self.state.talents) do
		if talent.tree == tree then
			spent = spent + self:GetRank(talent)
		end
	end
	return spent
end

function PT:Unspent()
	return math.max(0, self.state.spendCap - self:StagedSpent())
end

function PT:HasChanges()
	return next(self.state.staged) ~= nil
end

-- A node unlocks when it has no prerequisites or ANY prerequisite is maxed.
function PT:IsUnlocked(talent)
	if #talent.prereqs == 0 then
		return true
	end
	for _, prereqId in ipairs(talent.prereqs) do
		local prereq = self.state.byId[prereqId]
		if prereq and self:GetRank(prereq) >= prereq.maxRank then
			return true
		end
	end
	return false
end

function PT:CanIncrease(talent)
	local s = self.state
	return s.loaded and s.enabled
		and self:GetRank(talent) < talent.maxRank
		and self:Unspent() > 0
		and self:IsUnlocked(talent)
end

function PT:CanDecrease(talent)
	local staged = self.state.staged[talent.id]
	if not staged or staged <= talent.rank then
		return false
	end

	-- Removing the point must not strand a node that depends on this one.
	self.state.staged[talent.id] = staged - 1
	local ok = true
	for _, other in ipairs(self.state.talents) do
		if self:GetRank(other) > 0 and not self:IsUnlocked(other) then
			ok = false
			break
		end
	end
	self.state.staged[talent.id] = staged
	return ok
end

function PT:Stage(talent, delta)
	local newRank = self:GetRank(talent) + delta
	if newRank <= talent.rank then
		self.state.staged[talent.id] = nil
	else
		self.state.staged[talent.id] = newRank
	end
	self:SetStatus("")
	self:RenderTree()
end

function PT:ApplyStaged()
	if not self:HasChanges() then
		return
	end

	local ranks = {}
	for id, rank in pairs(self.state.staged) do
		table.insert(ranks, { id = id, rank = rank })
	end
	self.awaitingApply = true
	Request(CMSG_APPLY_TALENTS, { ranks = ranks })
end

function PT:UndoStaged()
	wipe(self.state.staged)
	self:SetStatus("")
	self:RenderTree()
end

-- =============================================================================
-- Unviewed challenges (badge)
-- =============================================================================

function PT:HasUnviewed(category)
	local db = GetChallengeDB()
	for id in pairs(db.unviewed) do
		if not category then
			return true
		end
		for _, item in ipairs(category.items) do
			if item.id == id then
				return true
			end
		end
	end
	return false
end

function PT:MarkCategoryViewed(category)
	local db = GetChallengeDB()
	local changed = false
	for _, item in ipairs(category.items) do
		if db.unviewed[item.id] then
			db.unviewed[item.id] = nil
			changed = true
		end
	end
	if changed then
		self:UpdateBadges()
	end
end

function PT:UpdateBadges()
	local f = self.frame
	if not f then
		return
	end
	ShowIf(f.tabs[PAGE_CHALLENGES].badge, self:HasUnviewed(nil))
	if f.categoryButtons then
		for _, button in ipairs(f.categoryButtons) do
			if button.category then
				ShowIf(button.badge, self:HasUnviewed(button.category))
			end
		end
	end
end

-- =============================================================================
-- Tooltips
-- =============================================================================

local function ShowTalentTooltip(button)
	local talent = button.talent
	if not talent then
		return
	end

	local rank = PT:GetRank(talent)
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:AddLine(talent.name, 1, 1, 1)
	GameTooltip:AddLine(string.format("Rank %d/%d", rank, talent.maxRank), 1, 1, 1)

	if rank > 0 then
		GameTooltip:AddLine(FormatDescription(talent, rank), 1, 0.82, 0, true)
	end

	if rank < talent.maxRank then
		if rank > 0 then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Next rank:", 1, 1, 1)
		end
		GameTooltip:AddLine(FormatDescription(talent, rank + 1), 1, 0.82, 0, true)

		if not PT:IsUnlocked(talent) then
			local names = {}
			for _, prereqId in ipairs(talent.prereqs) do
				local prereq = PT.state.byId[prereqId]
				if prereq then
					table.insert(names, prereq.name)
				end
			end
			GameTooltip:AddLine("Requires " .. table.concat(names, " or ") .. " at max rank", 1, 0.1, 0.1, true)
		elseif PT:Unspent() > 0 then
			GameTooltip:AddLine("Left-click to add a point", 0, 1, 0)
		end
	end

	if PT.state.staged[talent.id] then
		GameTooltip:AddLine("Right-click to remove a staged point", 0.6, 0.6, 0.6)
	end

	GameTooltip:Show()
end

-- =============================================================================
-- Frame + tabs
-- =============================================================================

function PT:CreateFrame()
	if self.frame then
		return self.frame
	end

	local f = CreateFrame("Frame", "DCPrestigeTalentsFrame", UIParent)
	f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()
	tinsert(UISpecialFrames, "DCPrestigeTalentsFrame")

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -6, -6)

	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	f.title:SetPoint("TOP", 0, -20)

	-- Side tabs on the right edge, like Forever's Legacy window (and the spellbook).
	f.tabs = {}
	for page = 1, 3 do
		local info = TAB_INFO[page]
		local tab = CreateFrame("CheckButton", "DCPrestigeTalentsTab" .. page, f, "SpellBookSkillLineTabTemplate")
		tab:SetPoint("TOPLEFT", f, "TOPRIGHT", -4, -48 - (page - 1) * 50)
		tab:SetNormalTexture(info.icon)
		tab.tooltip = info.tooltip
		tab:SetScript("OnClick", function()
			PT:SelectPage(page)
		end)
		tab:Show()

		tab.badge = tab:CreateTexture(nil, "OVERLAY")
		tab.badge:SetTexture(BADGE_TEXTURE)
		tab.badge:SetSize(16, 16)
		tab.badge:SetPoint("TOPRIGHT", 4, 4)
		tab.badge:Hide()

		f.tabs[page] = tab
	end

	f.pages = {}
	for page = 1, 3 do
		local content = CreateFrame("Frame", nil, f)
		content:SetSize(CONTENT_WIDTH, CONTENT_HEIGHT + 30)
		content:SetPoint("TOPLEFT", CONTENT_LEFT, CONTENT_TOP)
		content:Hide()
		f.pages[page] = content
	end

	f.statusText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.statusText:SetPoint("BOTTOM", 0, 44)
	f.statusText:SetTextColor(1, 0.3, 0.3)

	f:SetScript("OnShow", function()
		Request(CMSG_GET_TALENTS)
		Request(CMSG_GET_CHALLENGES)
		Request(CMSG_GET_REWARDS)
	end)

	self.frame = f
	self:CreateRewardsPage(f.pages[PAGE_REWARDS])
	self:CreateChallengesPage(f.pages[PAGE_CHALLENGES])
	self:CreateTreePage(f.pages[PAGE_TREE])
	return f
end

function PT:SetStatus(text)
	if self.frame then
		self.frame.statusText:SetText(text or "")
	end
end

function PT:SelectPage(page)
	self.currentPage = page
	local f = self:CreateFrame()
	f.title:SetText(PAGE_TITLES[page])
	for i = 1, 3 do
		ShowIf(f.pages[i], i == page)
		f.tabs[i]:SetChecked(i == page)
	end
	self:SetStatus("")
	self:Render()
end

function PT:Render()
	if not self.frame or not self.frame:IsShown() then
		return
	end
	if self.currentPage == PAGE_REWARDS then
		self:RenderRewards()
	elseif self.currentPage == PAGE_CHALLENGES then
		self:RenderChallenges()
	else
		self:RenderTree()
	end
	self:UpdateBadges()
end

-- =============================================================================
-- Page: Tree
-- =============================================================================

function PT:CreateTreePage(page)
	-- Tree selection column (left), like Forever's LegacyTreeSelectionPanel.
	page.cards = {}
	for i = 1, 3 do
		local card = CreateFrame("Button", nil, page)
		card:SetSize(TREE_CARD_WIDTH, TREE_CARD_HEIGHT)
		card:SetPoint("TOPLEFT", 0, -(i - 1) * (TREE_CARD_HEIGHT + 10))
		card:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})
		card:SetBackdropColor(0, 0, 0, 0.6)

		card.icon = card:CreateTexture(nil, "ARTWORK")
		card.icon:SetSize(44, 44)
		card.icon:SetPoint("LEFT", 12, 0)

		card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 10, -4)

		card.points = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		card.points:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -6)

		card:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		card:SetScript("OnClick", function()
			PT.selectedTree = i - 1
			PlaySound("igCharacterInfoTab")
			PT:RenderTree()
		end)
		page.cards[i] = card
	end

	-- Selected tree panel (right).
	local panel = CreateBackdropFrame(page, 0.45)
	panel:SetSize(TREE_PANEL_WIDTH, TREE_PANEL_HEIGHT)
	panel:SetPoint("TOPLEFT", TREE_CARD_WIDTH + 20, 0)
	panel.header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	panel.header:SetPoint("TOPLEFT", 14, -12)
	panel.spent = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	panel.spent:SetPoint("TOPRIGHT", -14, -14)
	panel.nodes = {}
	panel.lines = {}
	page.panel = panel

	-- Point summary (bottom left), like Forever's LegacyTreePointSummary.
	local summary = CreateFrame("Frame", nil, page)
	summary:SetSize(TREE_CARD_WIDTH + 200, 36)
	summary:SetPoint("TOPLEFT", 0, -(TREE_PANEL_HEIGHT + 16))
	summary:EnableMouse(true)
	summary.text = summary:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	summary.text:SetPoint("LEFT")
	summary:SetScript("OnEnter", function(self)
		local s = PT.state
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		GameTooltip:AddLine("Prestige Talent Points", 1, 1, 1)
		GameTooltip:AddLine(string.format("Account total: %d", s.accountPoints), 1, 0.82, 0)
		GameTooltip:AddLine(string.format("  from prestige levels: %d", s.prestigePoints), 0.8, 0.8, 0.8)
		GameTooltip:AddLine(string.format("  from challenges: %d", s.challengePoints), 0.8, 0.8, 0.8)
		GameTooltip:AddLine(string.format("Each character can spend up to %d.", s.spendCap), 0.8, 0.8, 0.8, true)
		GameTooltip:AddLine("Points you cannot spend still count toward the Reward Track.", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	summary:SetScript("OnLeave", function() GameTooltip:Hide() end)
	page.summary = summary

	local apply = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	apply:SetSize(140, 24)
	apply:SetPoint("TOPRIGHT", 0, -(TREE_PANEL_HEIGHT + 20))
	apply:SetText("Apply Changes")
	apply:SetScript("OnClick", function() PT:ApplyStaged() end)
	page.apply = apply

	local undo = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	undo:SetSize(90, 24)
	undo:SetPoint("RIGHT", apply, "LEFT", -8, 0)
	undo:SetText("Undo")
	undo:SetScript("OnClick", function() PT:UndoStaged() end)
	page.undo = undo

	local reset = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	reset:SetSize(90, 24)
	reset:SetPoint("RIGHT", apply, "LEFT", -8, 0)
	reset:SetText("Reset")
	reset:SetScript("OnClick", function()
		StaticPopup_Show("DC_PRESTIGE_TALENTS_RESET", FormatMoney(PT.state.resetCost))
	end)
	page.reset = reset
end

local function GetNode(panel, index)
	local button = panel.nodes[index]
	if button then
		return button
	end

	button = CreateFrame("Button", nil, panel)
	button:SetSize(NODE_SIZE, NODE_SIZE)
	button:SetFrameLevel(panel:GetFrameLevel() + 3)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAllPoints()

	button.border = button:CreateTexture(nil, "OVERLAY")
	button.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	button.border:SetBlendMode("ADD")
	button.border:SetSize(NODE_SIZE * 1.8, NODE_SIZE * 1.8)
	button.border:SetPoint("CENTER")

	button.rankBg = button:CreateTexture(nil, "OVERLAY")
	button.rankBg:SetTexture(0, 0, 0, 0.8)
	button.rankBg:SetSize(30, 13)
	button.rankBg:SetPoint("BOTTOMRIGHT", 8, -6)

	button.rank = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	button.rank:SetPoint("CENTER", button.rankBg, "CENTER", 0, 0)

	button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.label:SetPoint("TOP", button, "BOTTOM", 0, -8)
	button.label:SetWidth(120)

	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	button:SetScript("OnEnter", ShowTalentTooltip)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	button:SetScript("OnClick", function(self, mouseButton)
		local talent = self.talent
		if not talent then
			return
		end
		if mouseButton == "RightButton" then
			if PT:CanDecrease(talent) then
				PT:Stage(talent, -1)
			end
		elseif PT:CanIncrease(talent) then
			PT:Stage(talent, 1)
		end
		ShowTalentTooltip(self)
	end)

	panel.nodes[index] = button
	return button
end

-- Axis-aligned connector segment, coordinates relative to the panel's TOPLEFT.
local function DrawSegment(panel, index, x1, y1, x2, y2, active)
	local line = panel.lines[index]
	if not line then
		line = panel:CreateTexture(nil, "ARTWORK")
		panel.lines[index] = line
	end
	if active then
		line:SetTexture(1, 0.82, 0, 0.9)
	else
		line:SetTexture(0.45, 0.45, 0.45, 0.8)
	end
	line:ClearAllPoints()
	line:SetPoint("TOPLEFT", panel, "TOPLEFT", math.min(x1, x2) - 1, math.max(y1, y2) + 1)
	line:SetSize(math.abs(x2 - x1) + 3, math.abs(y2 - y1) + 3)
	line:Show()
end

local function NodePosition(talent)
	local columnWidth = TREE_PANEL_WIDTH / 4
	local x = columnWidth * talent.col
	local y = NODE_TOP - 20 - (talent.row - 1) * NODE_ROW_SPACING
	return x, y -- centre-top of the node
end

function PT:RenderTree()
	local f = self.frame
	if not f or self.currentPage ~= PAGE_TREE then
		return
	end

	local page = f.pages[PAGE_TREE]
	local s = self.state

	for i, card in ipairs(page.cards) do
		local def = s.trees[i]
		if def then
			card.icon:SetTexture(ICON_PATH .. (def.icon or ""))
			card.name:SetText(def.name or "")
			card.points:SetText(string.format("%d points spent", self:StagedTreeSpent(def.id)))
			if def.id == self.selectedTree then
				card:SetBackdropBorderColor(1, 0.82, 0, 1)
			else
				card:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.9)
			end
			card:Show()
		else
			card:Hide()
		end
	end

	local panel = page.panel
	local treeDef = s.trees[self.selectedTree + 1]
	panel.header:SetText(treeDef and treeDef.name or "")
	panel.spent:SetText(string.format("%d points", self:StagedTreeSpent(self.selectedTree)))

	for _, node in ipairs(panel.nodes) do
		node:Hide()
	end
	for _, line in ipairs(panel.lines) do
		line:Hide()
	end

	-- Connectors first (below the nodes): parent bottom -> midpoint -> child top.
	local lineIndex = 0
	for _, talent in ipairs(s.talents) do
		if talent.tree == self.selectedTree then
			local cx, cy = NodePosition(talent)
			for _, prereqId in ipairs(talent.prereqs) do
				local prereq = s.byId[prereqId]
				if prereq and prereq.tree == talent.tree then
					local px, py = NodePosition(prereq)
					py = py - NODE_SIZE
					local midY = (py + cy) / 2
					local active = self:GetRank(prereq) >= prereq.maxRank
					lineIndex = lineIndex + 1
					DrawSegment(panel, lineIndex, px, py, px, midY, active)
					lineIndex = lineIndex + 1
					DrawSegment(panel, lineIndex, px, midY, cx, midY, active)
					lineIndex = lineIndex + 1
					DrawSegment(panel, lineIndex, cx, midY, cx, cy, active)
				end
			end
		end
	end

	local index = 0
	for _, talent in ipairs(s.talents) do
		if talent.tree == self.selectedTree then
			index = index + 1
			local node = GetNode(panel, index)
			node.talent = talent

			local x, y = NodePosition(talent)
			node:ClearAllPoints()
			node:SetPoint("TOPLEFT", panel, "TOPLEFT", x - NODE_SIZE / 2, y)

			local rank = self:GetRank(talent)
			node.icon:SetTexture(talent.icon and (ICON_PATH .. talent.icon) or FALLBACK_ICON)
			node.rank:SetText(string.format("%d/%d", rank, talent.maxRank))
			node.label:SetText(talent.name)

			local staged = s.staged[talent.id] ~= nil
			if rank >= talent.maxRank then
				node.icon:SetDesaturated(false)
				node.icon:SetVertexColor(1, 1, 1)
				node.rank:SetTextColor(1, 0.82, 0)
				node.border:SetVertexColor(1, 0.82, 0)
				node.border:Show()
			elseif self:IsUnlocked(talent) and (rank > 0 or self:Unspent() > 0) then
				node.icon:SetDesaturated(false)
				node.icon:SetVertexColor(1, 1, 1)
				node.rank:SetTextColor(0.1, 1, 0.1)
				node.border:SetVertexColor(0.1, 1, 0.1)
				node.border:Show()
			else
				node.icon:SetDesaturated(true)
				node.icon:SetVertexColor(0.6, 0.6, 0.6)
				node.rank:SetTextColor(0.5, 0.5, 0.5)
				node.border:Hide()
			end
			if staged then
				node.rank:SetTextColor(0.4, 0.8, 1)
			end
			node:Show()
		end
	end

	if not s.enabled then
		page.summary.text:SetText("Prestige talents are disabled on this realm.")
	elseif not s.loaded then
		page.summary.text:SetText("Loading...")
	else
		page.summary.text:SetText(string.format(
			"|cff54ff9a%d|r points available  |cff8a8a8a(%d / %d spent)|r",
			self:Unspent(), self:StagedSpent(), s.spendCap))
	end

	local hasChanges = self:HasChanges()
	EnableIf(page.apply, hasChanges and not self.awaitingApply)
	ShowIf(page.undo, hasChanges)
	ShowIf(page.reset, not hasChanges)
	EnableIf(page.reset, s.loaded and s.spent > 0)
end

-- =============================================================================
-- Page: Challenges
-- =============================================================================

local CATEGORY_WIDTH = 190
local CHALLENGE_ROW_HEIGHT = 46

function PT:CreateChallengesPage(page)
	local summary = CreateBackdropFrame(page, 0.5)
	summary:SetSize(CONTENT_WIDTH, 50)
	summary:SetPoint("TOPLEFT")
	summary.text = summary:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	summary.text:SetPoint("TOPLEFT", 12, -10)

	summary.bar = CreateFrame("StatusBar", nil, summary)
	summary.bar:SetSize(CONTENT_WIDTH - 24, 10)
	summary.bar:SetPoint("BOTTOMLEFT", 12, 9)
	summary.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	summary.bar:SetStatusBarColor(0.9, 0.7, 0.1)
	summary.bar.bg = summary.bar:CreateTexture(nil, "BACKGROUND")
	summary.bar.bg:SetAllPoints()
	summary.bar.bg:SetTexture(0, 0, 0, 0.6)
	page.summary = summary

	local categories = CreateBackdropFrame(page, 0.45)
	categories:SetSize(CATEGORY_WIDTH, CONTENT_HEIGHT - 60)
	categories:SetPoint("TOPLEFT", 0, -60)
	page.categories = categories
	self.frame.categoryButtons = {}

	local listFrame = CreateBackdropFrame(page, 0.45)
	listFrame:SetSize(CONTENT_WIDTH - CATEGORY_WIDTH - 10, CONTENT_HEIGHT - 60)
	listFrame:SetPoint("TOPLEFT", CATEGORY_WIDTH + 10, -60)

	local scroll = CreateFrame("ScrollFrame", "DCPrestigeChallengeScroll", listFrame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 8, -8)
	scroll:SetPoint("BOTTOMRIGHT", -28, 8)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(listFrame:GetWidth() - 40, 10)
	scroll:SetScrollChild(child)
	page.scroll = scroll
	page.scrollChild = child
	page.rows = {}
end

local function GetCategoryButton(page, index)
	local buttons = PT.frame.categoryButtons
	local button = buttons[index]
	if button then
		return button
	end

	button = CreateFrame("Button", nil, page.categories)
	button:SetSize(CATEGORY_WIDTH - 16, 26)
	button:SetPoint("TOPLEFT", 8, -8 - (index - 1) * 28)
	button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

	button.selected = button:CreateTexture(nil, "BACKGROUND")
	button.selected:SetAllPoints()
	button.selected:SetTexture(1, 0.82, 0, 0.18)

	button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	button.text:SetPoint("LEFT", 8, 0)

	button.count = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.count:SetPoint("RIGHT", -8, 0)

	button.badge = button:CreateTexture(nil, "OVERLAY")
	button.badge:SetTexture(BADGE_TEXTURE)
	button.badge:SetSize(14, 14)
	button.badge:SetPoint("RIGHT", button.count, "LEFT", -4, 0)
	button.badge:Hide()

	button:SetScript("OnClick", function(self)
		PT.selectedCategory = self.category and self.category.name
		PT:RenderChallenges()
	end)

	buttons[index] = button
	return button
end

local function GetChallengeRow(page, index)
	local row = page.rows[index]
	if row then
		return row
	end

	row = CreateFrame("Button", nil, page.scrollChild)
	row:SetSize(page.scrollChild:GetWidth(), CHALLENGE_ROW_HEIGHT - 4)
	row:SetPoint("TOPLEFT", 0, -(index - 1) * CHALLENGE_ROW_HEIGHT)
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

	row.bg = row:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints()

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(36, 36)
	row.icon:SetPoint("LEFT", 4, 0)

	row.check = row:CreateTexture(nil, "OVERLAY")
	row.check:SetTexture(CHECK_TEXTURE)
	row.check:SetSize(18, 18)
	row.check:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 4, -4)

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -2)
	row.name:SetJustifyH("LEFT")

	row.desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.desc:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
	row.desc:SetWidth(row:GetWidth() - 140)
	row.desc:SetJustifyH("LEFT")

	row.points = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	row.points:SetPoint("RIGHT", -12, 0)

	row.newBadge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.newBadge:SetPoint("RIGHT", row.points, "LEFT", -10, 0)
	row.newBadge:SetText("NEW")
	row.newBadge:SetTextColor(0.3, 1, 0.3)

	row:SetScript("OnEnter", function(self)
		if not self.challengeId then
			return
		end
		local link = GetAchievementLink(self.challengeId)
		if link then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(link)
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Shift-click to link in chat", 0.6, 0.6, 0.6)
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row:SetScript("OnClick", function(self)
		if self.challengeId and IsModifiedClick("CHATLINK") then
			local link = GetAchievementLink(self.challengeId)
			if link then
				ChatEdit_InsertLink(link)
			end
		end
	end)

	page.rows[index] = row
	return row
end

function PT:RenderChallenges()
	local f = self.frame
	if not f or self.currentPage ~= PAGE_CHALLENGES then
		return
	end

	local page = f.pages[PAGE_CHALLENGES]
	local c = self.challenges

	local earned, available = 0, 0
	for _, item in ipairs(c.list) do
		available = available + item.points
		if item.completed then
			earned = earned + item.points
		end
	end

	if not c.loaded then
		page.summary.text:SetText("Loading...")
	else
		page.summary.text:SetText(string.format(
			"Challenge points: |cff54ff9a%d|r / %d    Prestige level points: %d    |cffffd100Account total: %d|r",
			earned, available, self.state.prestigePoints, earned + self.state.prestigePoints))
	end
	page.summary.bar:SetMinMaxValues(0, math.max(available, 1))
	page.summary.bar:SetValue(earned)

	-- Category list.
	if not self.selectedCategory and c.categories[1] then
		self.selectedCategory = c.categories[1].name
	end

	local selected
	for i, category in ipairs(c.categories) do
		local button = GetCategoryButton(page, i)
		button.category = category
		local done = 0
		for _, item in ipairs(category.items) do
			if item.completed then
				done = done + 1
			end
		end
		button.text:SetText(category.name)
		button.count:SetText(string.format("%d/%d", done, #category.items))
		ShowIf(button.selected, category.name == self.selectedCategory)
		ShowIf(button.badge, self:HasUnviewed(category))
		button:Show()
		if category.name == self.selectedCategory then
			selected = category
		end
	end
	for i = #c.categories + 1, #f.categoryButtons do
		f.categoryButtons[i]:Hide()
	end

	-- Challenge rows of the selected category.
	local db = GetChallengeDB()
	local items = selected and selected.items or {}
	for i, item in ipairs(items) do
		local row = GetChallengeRow(page, i)
		row.challengeId = item.id

		local _, name, _, _, _, _, _, description, _, icon = GetAchievementInfo(item.id)
		row.icon:SetTexture(icon or FALLBACK_ICON)
		row.name:SetText(name or ("Achievement #" .. item.id))
		row.desc:SetText(description or "")
		row.points:SetText("+" .. item.points)
		ShowIf(row.check, item.completed)
		ShowIf(row.newBadge, db.unviewed[item.id] and true or false)

		if item.completed then
			row.bg:SetTexture(0.1, 0.35, 0.1, 0.35)
			row.icon:SetDesaturated(false)
			row.name:SetTextColor(1, 0.82, 0)
			row.points:SetTextColor(0.33, 1, 0.6)
		else
			row.bg:SetTexture(0.1, 0.1, 0.1, 0.35)
			row.icon:SetDesaturated(true)
			row.name:SetTextColor(0.7, 0.7, 0.7)
			row.points:SetTextColor(0.6, 0.6, 0.6)
		end
		row:Show()
	end
	for i = #items + 1, #page.rows do
		page.rows[i]:Hide()
	end
	page.scrollChild:SetHeight(math.max(#items * CHALLENGE_ROW_HEIGHT, 10))

	-- Viewing a category clears its "new" markers, after this render showed them.
	if selected then
		self:MarkCategoryViewed(selected)
	end
end

-- =============================================================================
-- Page: Reward Track
-- =============================================================================

function PT:CreateRewardsPage(page)
	page.total = page:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	page.total:SetPoint("TOP", 0, -10)

	page.subtitle = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	page.subtitle:SetPoint("TOP", page.total, "BOTTOM", 0, -6)
	page.subtitle:SetText("Account prestige talent points. Every point counts here, spent or not.")
	page.subtitle:SetTextColor(0.75, 0.75, 0.75)

	local bar = CreateFrame("StatusBar", nil, page)
	bar:SetSize(CONTENT_WIDTH - 40, 16)
	bar:SetPoint("TOP", 0, -90)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetStatusBarColor(0.95, 0.75, 0.15)
	bar:SetMinMaxValues(0, 1)
	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints()
	bar.bg:SetTexture(0, 0, 0, 0.7)
	bar.border = CreateFrame("Frame", nil, bar)
	bar.border:SetPoint("TOPLEFT", -4, 4)
	bar.border:SetPoint("BOTTOMRIGHT", 4, -4)
	bar.border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
	bar.border:SetBackdropBorderColor(0.7, 0.6, 0.3, 1)
	page.bar = bar
	page.markers = {}
	page.cards = {}
end

local function GetRewardCard(page, index)
	local card = page.cards[index]
	if card then
		return card
	end

	card = CreateBackdropFrame(page, 0.6)

	card.threshold = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	card.threshold:SetPoint("TOP", 0, -12)

	card.iconButton = CreateFrame("Button", nil, card)
	card.iconButton:SetSize(52, 52)
	card.iconButton:SetPoint("TOP", 0, -40)
	card.icon = card.iconButton:CreateTexture(nil, "ARTWORK")
	card.icon:SetAllPoints()
	card.iconButton:SetScript("OnEnter", function(self)
		if card.itemId then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink("item:" .. card.itemId)
			GameTooltip:Show()
		end
	end)
	card.iconButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
	card.iconButton:SetScript("OnClick", function()
		if card.itemId and IsModifiedClick("DRESSUP") then
			DressUpItemLink("item:" .. card.itemId)
		end
	end)

	card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	card.name:SetPoint("TOP", card.iconButton, "BOTTOM", 0, -10)
	card.name:SetJustifyH("CENTER")

	card.kind = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	card.kind:SetPoint("TOP", card.name, "BOTTOM", 0, -4)
	card.kind:SetTextColor(0.7, 0.7, 0.7)

	card.status = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	card.status:SetPoint("BOTTOM", 0, 20)

	card.claim = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
	card.claim:SetSize(100, 24)
	card.claim:SetPoint("BOTTOM", 0, 16)
	card.claim:SetText("Claim")
	card.claim:SetScript("OnClick", function()
		if card.threshold_value then
			Request(CMSG_CLAIM_REWARD, { threshold = card.threshold_value })
		end
	end)

	page.cards[index] = card
	return card
end

-- Bar fill such that each card's marker sits under the card, like Forever's track.
local function TrackFill(points, list)
	local n = #list
	if n == 0 then
		return 0
	end
	local function Pos(i) return (i - 0.5) / n end

	if points <= list[1].threshold then
		return Pos(1) * points / math.max(list[1].threshold, 1)
	end
	for i = 1, n - 1 do
		local lo, hi = list[i].threshold, list[i + 1].threshold
		if points <= hi then
			return Pos(i) + (Pos(i + 1) - Pos(i)) * (points - lo) / math.max(hi - lo, 1)
		end
	end
	local last = list[n].threshold
	local step = n > 1 and (last - list[n - 1].threshold) or last
	return math.min(1, Pos(n) + (1 - Pos(n)) * (points - last) / math.max(step, 1))
end

function PT:RenderRewards()
	local f = self.frame
	if not f or self.currentPage ~= PAGE_REWARDS then
		return
	end

	local page = f.pages[PAGE_REWARDS]
	local r = self.rewards
	local list = r.list
	local points = r.accountPoints

	page.total:SetText(r.loaded and tostring(points) or "...")
	page.bar:SetValue(TrackFill(points, list))

	local n = math.max(#list, 1)
	local barWidth = page.bar:GetWidth()
	local cardWidth = math.min(170, (CONTENT_WIDTH - 10 * (n - 1)) / n)
	local totalWidth = cardWidth * n + 10 * (n - 1)
	local startX = (CONTENT_WIDTH - totalWidth) / 2

	for i, reward in ipairs(list) do
		local marker = page.markers[i]
		if not marker then
			marker = page.bar:CreateTexture(nil, "OVERLAY")
			marker:SetSize(4, 22)
			page.markers[i] = marker
		end
		marker:ClearAllPoints()
		marker:SetPoint("CENTER", page.bar, "LEFT", barWidth * (i - 0.5) / n, 0)
		if points >= reward.threshold then
			marker:SetTexture(1, 0.9, 0.4, 1)
		else
			marker:SetTexture(0.4, 0.4, 0.4, 1)
		end
		marker:Show()

		local card = GetRewardCard(page, i)
		card:SetSize(cardWidth, 230)
		card:ClearAllPoints()
		card:SetPoint("TOPLEFT", page, "TOPLEFT", startX + (i - 1) * (cardWidth + 10), -130)

		card.itemId = reward.item
		card.threshold_value = reward.threshold
		card.threshold:SetText(reward.threshold .. " points")
		card.icon:SetTexture(GetItemIcon(reward.item) or FALLBACK_ICON)

		local color = ITEM_QUALITY_COLORS[reward.quality or 1]
		local name = reward.name ~= "" and reward.name or ("Item #" .. reward.item)
		card.name:SetWidth(cardWidth - 16)
		card.name:SetText((color and color.hex or "|cffffffff") .. name .. "|r")
		card.kind:SetText(reward.type and (reward.type:gsub("^%l", string.upper)) or "")

		local unlocked = points >= reward.threshold
		if reward.claimed then
			card.status:SetText("|cff54ff9aClaimed|r")
			card.status:Show()
			card.claim:Hide()
			card.icon:SetDesaturated(false)
			card:SetBackdropBorderColor(0.3, 0.8, 0.3, 1)
		elseif unlocked then
			card.status:Hide()
			card.claim:Show()
			card.claim:Enable()
			card.icon:SetDesaturated(false)
			card:SetBackdropBorderColor(1, 0.82, 0, 1)
		else
			card.status:SetText(string.format("|cff8a8a8a%d more points|r", reward.threshold - points))
			card.status:Show()
			card.claim:Hide()
			card.icon:SetDesaturated(true)
			card:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
		end
		card:Show()
	end

	for i = #list + 1, #page.cards do
		page.cards[i]:Hide()
	end
	for i = #list + 1, #page.markers do
		page.markers[i]:Hide()
	end
end

-- =============================================================================
-- Public API
-- =============================================================================

function PT:Toggle()
	local f = self:CreateFrame()
	if f:IsShown() then
		f:Hide()
	else
		f:Show()
		self:SelectPage(self.currentPage)
	end
end

function PT:Open(page)
	local f = self:CreateFrame()
	if not f:IsShown() then
		f:Show()
	end
	self:SelectPage(page or self.currentPage)
end

-- =============================================================================
-- Protocol handlers
-- =============================================================================

local function OnTalents(data)
	if type(data) ~= "table" then
		return
	end

	local s = PT.state
	s.enabled = data.enabled ~= false
	s.loaded = data.loaded == true
	s.prestigePoints = tonumber(data.prestigePoints) or 0
	s.challengePoints = tonumber(data.challengePoints) or 0
	s.accountPoints = tonumber(data.accountPoints) or 0
	s.spendCap = tonumber(data.spendCap) or 0
	s.spent = tonumber(data.spent) or 0
	s.resetCost = tonumber(data.resetCost) or 0
	s.trees = type(data.trees) == "table" and data.trees or {}
	s.talents = {}
	s.byId = {}

	if type(data.talents) == "table" then
		for _, t in ipairs(data.talents) do
			local prereqs = {}
			if type(t.prereqs) == "table" then
				for _, id in ipairs(t.prereqs) do
					table.insert(prereqs, tonumber(id))
				end
			end
			local talent = {
				id = tonumber(t.id) or 0,
				tree = tonumber(t.tree) or 0,
				row = tonumber(t.row) or 1,
				col = tonumber(t.col) or 1,
				maxRank = tonumber(t.maxRank) or 1,
				rank = tonumber(t.rank) or 0,
				prereqs = prereqs,
				name = t.name or "?",
				desc = t.desc or "",
				value = tonumber(t.value) or 0,
				icon = t.icon,
			}
			table.insert(s.talents, talent)
			s.byId[talent.id] = talent
		end
	end

	-- After an apply the server state is authoritative; otherwise keep staged
	-- ranks that are still above the committed ones.
	if PT.awaitingApply then
		PT.awaitingApply = false
		wipe(s.staged)
	else
		for id, rank in pairs(s.staged) do
			local talent = s.byId[id]
			if not talent or rank <= talent.rank then
				s.staged[id] = nil
			end
		end
	end

	PT:Render()
end

local function OnTalentResult(data)
	if type(data) ~= "table" then
		return
	end

	if data.ok then
		PT:SetStatus("")
		if data.action == "claim" then
			UIErrorsFrame:AddMessage("Reward claimed - check your mailbox!", 0.3, 1, 0.3)
		end
	else
		PT:SetStatus(data.error or "")
	end
end

local function OnChallenges(data)
	if type(data) ~= "table" then
		return
	end

	local c = PT.challenges
	c.loaded = data.loaded == true
	c.list = {}
	c.categories = {}
	local byName = {}

	if type(data.challenges) == "table" then
		for _, entry in ipairs(data.challenges) do
			local item = {
				id = tonumber(entry.id) or 0,
				points = tonumber(entry.points) or 0,
				category = entry.category or "General",
				completed = entry.completed == true,
			}
			table.insert(c.list, item)
			local category = byName[item.category]
			if not category then
				category = { name = item.category, items = {} }
				byName[item.category] = category
				table.insert(c.categories, category)
			end
			table.insert(category.items, item)
		end
	end

	PT:Render()
end

local function OnRewards(data)
	if type(data) ~= "table" then
		return
	end

	local r = PT.rewards
	r.loaded = data.loaded == true
	r.accountPoints = tonumber(data.accountPoints) or 0
	r.list = {}
	if type(data.rewards) == "table" then
		for _, entry in ipairs(data.rewards) do
			table.insert(r.list, {
				threshold = tonumber(entry.threshold) or 0,
				item = tonumber(entry.item) or 0,
				count = tonumber(entry.count) or 1,
				type = entry.type,
				name = entry.name or "",
				quality = tonumber(entry.quality) or 1,
				claimed = entry.claimed == true,
			})
		end
	end

	PT:Render()
end

local function OnChallengeEarned(data)
	if type(data) ~= "table" then
		return
	end

	local id = tonumber(data.id)
	if id then
		GetChallengeDB().unviewed[id] = true
	end

	local name = id and select(2, GetAchievementInfo(id)) or "Challenge"
	UIErrorsFrame:AddMessage(string.format("Prestige challenge complete: %s (+%d talent points)",
		name or "Challenge", tonumber(data.points) or 0), 1, 0.82, 0)

	if PT.frame and PT.frame:IsShown() then
		Request(CMSG_GET_TALENTS)
		Request(CMSG_GET_CHALLENGES)
		Request(CMSG_GET_REWARDS)
	end
	PT:UpdateBadges()
end

local DC = GetProtocol()
if DC and DC.RegisterHandler then
	DC:RegisterHandler(MODULE, SMSG_TALENTS, OnTalents)
	DC:RegisterHandler(MODULE, SMSG_TALENT_RESULT, OnTalentResult)
	DC:RegisterHandler(MODULE, SMSG_CHALLENGES, OnChallenges)
	DC:RegisterHandler(MODULE, SMSG_REWARDS, OnRewards)
	DC:RegisterHandler(MODULE, SMSG_CHALLENGE_EARNED, OnChallengeEarned)
end

StaticPopupDialogs["DC_PRESTIGE_TALENTS_RESET"] = {
	text = "Refund all prestige talent points on this character?\nCost: %s",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		Request(CMSG_RESET_TALENTS)
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

SLASH_DCPRESTIGETALENTS1 = "/ptalents"
SLASH_DCPRESTIGETALENTS2 = "/prestigetalents"
SlashCmdList["DCPRESTIGETALENTS"] = function()
	PT:Toggle()
end
