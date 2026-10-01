--[[
	DC-Talents - the Dark Chaos layer on top of the vendored retail talent UI.

	Everything here replaces or extends retail mixin methods. It loads after the vendored files
	defined their mixins and before any retail frame is built (the frames are created on first open,
	see DC/Frame.lua), so frames pick up these versions when the mixins are copied into them.

	  * three WotLK trees: per-tree headers, one "talent points available" counter, no class pan offsets
	  * tooltips: retail layout, WotLK content (each rank's spell description via a scan tooltip)
	  * circular icons: SetPortraitToTexture instead of retail's mask textures
	  * edges: retail arrow art drawn with DC line and arrow-head textures
	  * loadout strings: class-wide, so they import on either talent group
	  * the host frame: Specialization / Talents / Glyphs tabs instead of the spellbook
]]

local _, ns = ...
setfenv(1, ns.env)

local G = ns.realG
local L = ns.L

local UI = ns.UI or {}
ns.UI = UI

-- ----------------------------------------------------------------------------
-- Edge art: retail line/arrow atlases -> DC textures that 3.3.5 can rotate
-- ----------------------------------------------------------------------------

local TEXTURES = "Interface\\AddOns\\DC-Talents\\Textures\\"

for _, state in ipairs({ "yellow", "gray", "red", "locked", "ghost" }) do
	ns.Line.atlasStyles["talents-arrow-line-" .. state] = { texture = TEXTURES .. "Line-" .. state }
	ns.Atlas.Register("talents-arrow-head-" .. state, TEXTURES .. "ArrowHead-" .. state, 14, 12, 0, 1, 0, 1, true)
end
ns.Line.DEFAULT_TEXTURE = TEXTURES .. "Line"

-- ----------------------------------------------------------------------------
-- Class visuals: retail pan offsets are tuned for retail trees, and there are no activation FX
-- ----------------------------------------------------------------------------

local RetailGetVisualsForClassID = ClassTalentUtil.GetVisualsForClassID
function ClassTalentUtil.GetVisualsForClassID(classID)
	return nil
end
UI.RetailGetVisualsForClassID = RetailGetVisualsForClassID

-- Sample abilities on the specialization cards: the tree's highest active talents.
local RetailGetSpellsDisplay = C_SpecializationInfo.GetSpellsDisplay
C_SpecializationInfo.GetSpellsDisplay = function(specID)
	local treeID = ns.Traits.GetPlayerTreeID()
	local tree = treeID and ns.Traits.GetTree(treeID)
	if not tree then
		return {}
	end
	for tab = 1, #tree.tabs do
		if ns.Layout.RetailSpecForTab(tab) == specID then
			local active = {}
			for _, node in ipairs(tree.tabs[tab].nodes) do
				if node.active and node.spells[1] then
					active[#active + 1] = node
				end
			end
			table.sort(active, function(a, b)
				return a.tier > b.tier
			end)
			local spells = {}
			spells[1] = active[2] and active[2].spells[1] or (active[1] and active[1].spells[1]) or nil
			spells[6] = active[1] and active[1].spells[1] or nil
			for i = 2, 5 do
				spells[i] = spells[i] or 0
			end
			return spells
		end
	end
	return RetailGetSpellsDisplay and RetailGetSpellsDisplay(specID) or {}
end

-- ----------------------------------------------------------------------------
-- Talent buttons: circular icons and WotLK tooltips
-- ----------------------------------------------------------------------------

local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local RetailArtOnLoad = TalentButtonArtMixin.OnLoad
function TalentButtonArtMixin:OnLoad()
	RetailArtOnLoad(self)
	-- 3.3.5 has no mask textures: circular nodes get a round dark overlay instead of a masked square.
	if self.artSet and self.artSet.iconMask and self.DisabledOverlay then
		self.DisabledOverlay:SetTexture(CIRCLE_MASK)
		self.DisabledOverlay:SetVertexColor(0, 0, 0, 1)
	end
end

local RetailUpdateIconTexture = TalentDisplayMixin.UpdateIconTexture
function TalentDisplayMixin:UpdateIconTexture()
	if not self.Icon then
		return
	end
	local texture, isAtlas = self:CalculateIconTexture()
	if not isAtlas and self.artSet and self.artSet.iconMask and type(texture) == "string" then
		-- Circle nodes: 3.3.5 renders any texture as a round portrait (a native call: it ends any atlas
		-- the icon had, so the coordinate reset below is not mapped into that atlas).
		self.Icon.__dcAtlas = nil
		self.Icon.__dcAtlasRect = nil
		G.SetPortraitToTexture(self.Icon, texture)
		self.Icon:SetTexCoord(0, 1, 0, 1)
		return
	end
	RetailUpdateIconTexture(self)
	if not isAtlas then
		-- Square icons: trim the baked-in 3.3.5 icon border like retail's square frames do.
		self.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
end

-- Border sheen: retail sweeps a glint across the nodes and clips it to each node's border with a
-- mask texture. 3.3.5 has no masks, so the whole streak would cross the tree; the sheen stays off
-- (and its animation never runs).
function ClassTalentButtonArtMixin:OnShow()
end

function ClassTalentButtonArtMixin:OnHide()
end

local RetailUpdateStateBorder = ClassTalentButtonArtMixin.UpdateStateBorder
function ClassTalentButtonArtMixin:UpdateStateBorder(visualState)
	RetailUpdateStateBorder(self, visualState)
	self.BorderSheen:Hide()
end

local scanTooltip
local function ScanTooltip()
	if not scanTooltip then
		scanTooltip = G.CreateFrame("GameTooltip", "DCTalentsScanTooltip", nil, "GameTooltipTemplate")
		scanTooltip:SetOwner(G.WorldFrame, "ANCHOR_NONE")
	end
	return scanTooltip
end

-- Copies a spell tooltip (minus its name line) into `tooltip`: cost, range, cast time, description.
function UI.AppendSpellBody(tooltip, spellID)
	if not spellID then
		return
	end
	local scan = ScanTooltip()
	scan:SetOwner(G.WorldFrame, "ANCHOR_NONE")
	scan:ClearLines()
	scan:SetHyperlink("spell:" .. spellID)
	for i = 2, scan:NumLines() do
		local left = G["DCTalentsScanTooltipTextLeft" .. i]
		local right = G["DCTalentsScanTooltipTextRight" .. i]
		local leftText = left and left:GetText()
		local rightText = right and right:IsShown() and right:GetText()
		if leftText and leftText ~= "" then
			local lr, lg, lb = left:GetTextColor()
			if rightText and rightText ~= "" then
				local rr, rg, rb = right:GetTextColor()
				tooltip:AddDoubleLine(leftText, rightText, lr, lg, lb, rr, rg, rb)
			else
				tooltip:AddLine(leftText, lr, lg, lb, true)
			end
		end
	end
end

local RetailSetTooltipInternal = TalentDisplayMixin.SetTooltipInternal
function TalentDisplayMixin:SetTooltipInternal(ignoreTooltipInfo)
	local nodeInfo = self.nodeInfo
	local node = nodeInfo and nodeInfo.dcTab and ns.Traits.FindNodeAnyTree(nodeInfo.ID)
	if not node then
		return RetailSetTooltipInternal(self, ignoreTooltipInfo)
	end

	local tooltip = self:AcquireTooltip()
	GameTooltip_SetTitle(tooltip, self:GetName())

	local rank, maxRank = nodeInfo.currentRank, nodeInfo.maxRanks
	GameTooltip_AddHighlightLine(tooltip, (TALENT_BUTTON_TOOLTIP_RANK_FORMAT or L.TOOLTIP_RANK_FORMAT):format(rank, maxRank))

	UI.AppendSpellBody(tooltip, node.spells[math.max(1, rank)])

	if rank > 0 and rank < maxRank and node.spells[rank + 1] then
		GameTooltip_AddBlankLineToTooltip(tooltip)
		GameTooltip_AddHighlightLine(tooltip, TALENT_BUTTON_TOOLTIP_NEXT_RANK or L.TOOLTIP_NEXT_RANK)
		UI.AppendSpellBody(tooltip, node.spells[rank + 1])
	end

	local committed = nodeInfo.dcCommittedRank or rank
	if committed ~= rank then
		GameTooltip_AddBlankLineToTooltip(tooltip)
		if rank < committed and rank == 0 then
			GameTooltip_AddColoredLine(tooltip, L.TOOLTIP_STAGED_REMOVED, ORANGE_FONT_COLOR or G.NORMAL_FONT_COLOR)
		else
			GameTooltip_AddColoredLine(tooltip, L.TOOLTIP_STAGED:format(rank, maxRank), G.GREEN_FONT_COLOR)
		end
	end

	-- WotLK talents have a single prerequisite; retail only words multi-edge requirements.
	if not nodeInfo.meetsEdgeRequirements and node.prereq and self:ShouldShowTooltipErrors() then
		local prereqNode = ns.Traits.FindNodeAnyTree(node.prereq)
		if prereqNode then
			GameTooltip_AddBlankLineToTooltip(tooltip)
			local format = G.TOOLTIP_TALENT_PREREQ or "Requires %d points in %s"
			GameTooltip_AddErrorLine(tooltip, format:format(node.prereqRank or prereqNode.maxRank, prereqNode.name))
		end
	end

	self:AddTooltipCost(tooltip)
	if self:ShouldShowTooltipInstructions() then
		self:AddTooltipInstructions(tooltip)
	end
	if self:ShouldShowTooltipErrors() then
		self:AddTooltipErrors(tooltip)
	end
	tooltip:Show()
end

-- Chat links: WotLK talent links instead of retail spell links.
local RetailSpendOnClick = TalentButtonSpendMixin.OnClick
function TalentButtonSpendMixin:OnClick(button)
	if button == "LeftButton" and G.IsModifiedClick("CHATLINK") and self.nodeInfo and self.nodeInfo.dcTab then
		local link = G.GetTalentLink(self.nodeInfo.dcTab, self.nodeInfo.dcIndex, false, false)
		if link then
			ChatFrameUtil.InsertLink(link)
		end
		return
	end
	return RetailSpendOnClick(self, button)
end

-- ----------------------------------------------------------------------------
-- Talents tab: three tree headers, one talent point counter
-- ----------------------------------------------------------------------------

local function CreateTreeHeader(parent)
	local header = G.CreateFrame("Frame", nil, parent)
	header:SetSize(240, 46)
	header.Name = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge2")
	header.Name:SetPoint("TOP", header, "TOP", 0, 0)
	header.Points = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge2")
	header.Points:SetPoint("TOP", header.Name, "BOTTOM", 0, -4)
	return header
end

function UI.UpdateTreeHeaders(talentsFrame)
	local headers = talentsFrame.dcTreeHeaders
	if not headers then
		return
	end
	local treeID = talentsFrame:GetTalentTreeID()
	local tree = treeID and ns.Traits.GetTree(treeID)
	local currencies = talentsFrame.treeCurrencyInfo or {}
	local numTabs = tree and #tree.tabs or 0
	for tab, header in ipairs(headers) do
		local tabInfo = tree and tree.tabs[tab]
		if tabInfo and not tree.isPet then
			local spent = 0
			for _, currency in ipairs(currencies) do
				if currency.traitCurrencyID == ns.Traits.CURRENCY_TAB_BASE + tab then
					spent = currency.spent or 0
				end
			end
			header.Name:SetText((tabInfo.name or ""):upper())
			header.Points:SetText(spent)
			header.Points:SetTextColor(spent > 0 and 1 or 0.5, spent > 0 and 0.82 or 0.5, spent > 0 and 0 or 0.5)
			local x = ns.Layout.TreeCenterX(numTabs, tab)
			header:ClearAllPoints()
			header:SetPoint("TOP", talentsFrame.ButtonsParent, "TOPLEFT", x, -14)
			header:Show()
		else
			header:Hide()
		end
	end
end

local RetailTalentsOnLoad = ClassTalentsFrameMixin.OnLoad
function ClassTalentsFrameMixin:OnLoad()
	RetailTalentsOnLoad(self)

	-- Retail waits for "Blizzard_PlayerSpells" to load its saved variables; we are that addon.
	self:LoadSavedVariables()

	self.dcTreeHeaders = {}
	for tab = 1, 3 do
		self.dcTreeHeaders[tab] = CreateTreeHeader(self)
		self.dcTreeHeaders[tab]:SetFrameLevel(self.ButtonsParent:GetFrameLevel() + 20)
	end

	-- One points counter for the three trees, on one line at the right of the bottom bar (where
	-- retail keeps War Mode and the PvP talent slots): the tree headers take the top edge.
	local display = self.ClassCurrencyDisplay
	display:ClearAllPoints()
	display:SetPoint("RIGHT", self.BottomBar, "RIGHT", -48, 3)
	display.CurrencyLabel:ClearAllPoints()
	display.CurrencyLabel:SetPoint("RIGHT", display, "RIGHT", 0, 0)
	display.CurrencyAmount:ClearAllPoints()
	display.CurrencyAmount:SetPoint("RIGHT", display.CurrencyLabel, "LEFT", -10, 0)
	self.SpecCurrencyDisplay:Hide()
	self.PvPTalentSlotTray:Hide()
	self.PvPTalentList:Hide()
	self.WarmodeButton:Hide()
	self.HeroTalentsContainer:Hide()
end

function ClassTalentsFrameMixin:RefreshCurrencyDisplay()
	local points = self.treeCurrencyInfo and self.treeCurrencyInfo[1] or nil
	self.ClassCurrencyDisplay:SetAmount(points and points.quantity or 0)
	self.ClassCurrencyDisplay:SetPointTypeText(L.TALENT_POINTS_AVAILABLE)
	self.SpecCurrencyDisplay:Hide()
	UI.UpdateTreeHeaders(self)
end

-- The primary tree can change with every commit: keep the retail background in step.
local RetailOnTraitConfigUpdated = ClassTalentsFrameMixin.OnTraitConfigUpdated
function ClassTalentsFrameMixin:OnTraitConfigUpdated(configID)
	RetailOnTraitConfigUpdated(self, configID)
	self:UpdateSpecBackground()
	local playerSpellsFrame = self:GetPlayerSpellsFrame()
	if playerSpellsFrame and playerSpellsFrame.UpdatePortrait then
		playerSpellsFrame:UpdatePortrait()
	end
end

-- ----------------------------------------------------------------------------
-- Loadout strings: class-wide spec id, accepted on either talent group
-- ----------------------------------------------------------------------------

function ClassTalentImportExportMixin:GetLoadoutExportString()
	local exportStream = ExportUtil.MakeExportDataStream()
	local configID = self:GetConfigID()
	local treeInfo = self:GetTreeInfo()
	local treeHash = C_Traits.GetTreeHash(treeInfo.ID)
	self:WriteLoadoutHeader(exportStream, C_Traits.GetLoadoutSerializationVersion(), ns.Traits.ClassSpecID(), treeHash)
	self:WriteLoadoutContent(exportStream, configID, treeInfo.ID)
	return exportStream:GetExportString()
end

local function IsSpecOfPlayerClass(specID)
	local _, _, classID = UnitClass("player")
	return ns.Traits.ClassIDForSpecID(specID) == classID
end

local RetailImportLoadout = ClassTalentImportExportMixin.ImportLoadout
function ClassTalentImportExportMixin:ImportLoadout(importText, loadoutName)
	local importStream = ExportUtil.MakeImportDataStream(importText)
	local headerValid, _, specID = self:ReadLoadoutHeader(importStream)
	if headerValid and IsSpecOfPlayerClass(specID) then
		-- Retail compares against the current spec; ours is class-wide, so make them agree.
		local currentSpecID = PlayerUtil.GetCurrentSpecID
		PlayerUtil.GetCurrentSpecID = function()
			return specID
		end
		local ok, result = pcall(RetailImportLoadout, self, importText, loadoutName)
		PlayerUtil.GetCurrentSpecID = currentSpecID
		if not ok then
			G.geterrorhandler()(result)
			return false
		end
		return result
	end
	return RetailImportLoadout(self, importText, loadoutName)
end

-- Viewing a string needs the talent data of its class, and 3.3.5 only has the player's own.
local RetailViewLoadout = ClassTalentImportExportMixin.ViewLoadout
function ClassTalentImportExportMixin:ViewLoadout(importText, level)
	local importStream = ExportUtil.MakeImportDataStream(importText)
	local headerValid, _, specID = self:ReadLoadoutHeader(importStream)
	if headerValid and not IsSpecOfPlayerClass(specID) then
		self:ShowImportError(LOADOUT_ERROR_WRONG_SPEC)
		return false
	end
	return RetailViewLoadout(self, importText, level)
end

-- ----------------------------------------------------------------------------
-- Loadout dropdown: retail's per-entry gear button becomes a submenu
-- ----------------------------------------------------------------------------

-- The 3.3.5 dropdown cannot host buttons inside entries, so each loadout gets a submenu:
-- Edit (retail's gear) plus whatever the owner adds through dcEntryMenuCallback.
local function AddEntrySubmenus(loadSystem, rootDescription)
	local possible = {}
	for _, selectionID in ipairs(loadSystem.possibleSelections or {}) do
		possible[selectionID] = true
	end
	for _, description in rootDescription:EnumerateElementDescriptions() do
		local selectionID = description.kind == "radio" and description:GetData()
		if selectionID and possible[selectionID] then
			local canEdit = loadSystem.editEntryCallback and (not loadSystem.canEditCallback or loadSystem.canEditCallback(selectionID))
			if canEdit then
				description:CreateButton(loadSystem.editEntryTooltip or L.MENU_EDIT, function()
					loadSystem.editEntryCallback(selectionID)
				end)
			end
			if loadSystem.dcEntryMenuCallback then
				loadSystem.dcEntryMenuCallback(selectionID, description)
			end
		end
	end
end

local RetailUpdateSelectionOptions = DropdownLoadSystemMixin.UpdateSelectionOptions
function DropdownLoadSystemMixin:UpdateSelectionOptions()
	RetailUpdateSelectionOptions(self)
	local dropdown = self.Dropdown
	local retailGenerator = dropdown and dropdown.menuGenerator
	if retailGenerator then
		dropdown:SetupMenu(function(owner, rootDescription)
			retailGenerator(owner, rootDescription)
			AddEntrySubmenus(self, rootDescription)
		end)
	end
end

local RetailInitializeLoadSystem = ClassTalentsFrameMixin.InitializeLoadSystem
function ClassTalentsFrameMixin:InitializeLoadSystem()
	RetailInitializeLoadSystem(self)
	local loadSystem = self.LoadSystem

	-- No "Link to Chat": 3.3.5 servers drop chat messages with unknown hyperlink types.
	for _, info in ipairs(loadSystem.sentinelInfos) do
		if info.sentinelInfos then
			for i = #info.sentinelInfos, 1, -1 do
				if info.sentinelInfos[i].text == TALENT_FRAME_DROP_DOWN_EXPORT_CHAT_LINK then
					table.remove(info.sentinelInfos, i)
				end
			end
		end
	end

	loadSystem.dcEntryMenuCallback = function(configID, description)
		if not ns.Loadouts.GetByConfigID(configID) then
			return
		end
		description:CreateButton(L.MENU_OVERWRITE, function()
			ns.Loadouts.SaveActiveInto(configID)
		end)
		description:CreateButton(L.MENU_DUPLICATE, function()
			local loadout = ns.Loadouts.GetByConfigID(configID)
			if loadout then
				ns.Loadouts.CreateFromRanks(loadout.name, CopyTable(loadout.ranks or {}), loadout.glyphs and CopyTable(loadout.glyphs), "duplicate")
			end
		end)
		description:CreateButton(L.MENU_EXPORT_STRING, function()
			UI.ShowCopyDialog(ns.Loadouts.GenerateImportString(configID))
		end)
	end
	loadSystem:UpdateSelectionOptions()
end

-- ----------------------------------------------------------------------------
-- Frame levels (see Engine.MapFrameLevel): absolute retail levels go through the mapping
-- ----------------------------------------------------------------------------

function PortraitFrameMixin:SetFrameLevelsFromBaseLevel(baseLevel)
	local map = ns.Engine.MapFrameLevel
	local offsets = { NineSlice = 500, PortraitContainer = 400, TitleContainer = 510, CloseButton = 510 }
	for key, offset in pairs(offsets) do
		local frame = self[key]
		if frame then
			frame:SetFrameLevel(map(baseLevel + offset))
		end
	end
end

local RetailGetFrameLevelForButton = ClassTalentsFrameMixin.GetFrameLevelForButton
function ClassTalentsFrameMixin:GetFrameLevelForButton(nodeInfo, visualState)
	local offset = RetailGetFrameLevelForButton(self, nodeInfo, visualState)
	if ns.Engine.FrameLevelScale() == 1 then
		return offset
	end
	return math.max(1, ns.Engine.MapFrameLevel(offset))
end

-- ----------------------------------------------------------------------------
-- Specialization tab: WotLK spell-cast events carry names, not spell ids
-- ----------------------------------------------------------------------------

local ACTIVATE_SPELLS = { 63644, 63645 }
local function IsActivateSpellName(name)
	for _, spellID in ipairs(ACTIVATE_SPELLS) do
		if name and name == G.GetSpellInfo(spellID) then
			return true
		end
	end
	return false
end

local RetailSpecOnEvent = ClassSpecFrameMixin.OnEvent
function ClassSpecFrameMixin:OnEvent(event, ...)
	if (event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED") and self:IsActivateInProgress() then
		local unit, spellName = ...
		if unit == "player" and IsActivateSpellName(spellName) then
			self:SetSpecActivateStarted(nil)
		end
		return
	end
	return RetailSpecOnEvent(self, event, ...)
end

-- ----------------------------------------------------------------------------
-- Host frame: Specialization / Talents / Glyphs, no spellbook, no minimized mode
-- ----------------------------------------------------------------------------

function PlayerSpellsFrameMixin:OnLoad()
	TabSystemOwnerMixin.OnLoad(self)
	self:SetTabSystem(self.TabSystem)
	self.specTabID = self:AddNamedTab(TALENT_FRAME_TAB_LABEL_SPEC, self.SpecFrame)
	self.talentTabID = self:AddNamedTab(TALENT_FRAME_TAB_LABEL_TALENTS, self.TalentsFrame)
	if UI.CreatePetTab then
		self.PetFrame = UI.CreatePetTab(self)
		self.petTabID = self:AddNamedTab(L.TAB_PET, self.PetFrame)
	end
	if UI.CreateGlyphTab then
		self.GlyphsFrame = UI.CreateGlyphTab(self)
		self.glyphTabID = self:AddNamedTab(L.TAB_GLYPHS, self.GlyphsFrame)
	end
	self.SpellBookFrame:Hide()

	self.frameTabsToTabID = {
		[PlayerSpellsUtil.FrameTabs.ClassSpecializations] = self.specTabID,
		[PlayerSpellsUtil.FrameTabs.ClassTalents] = self.talentTabID,
		[PlayerSpellsUtil.FrameTabs.Pet] = self.petTabID,
		[PlayerSpellsUtil.FrameTabs.Glyphs] = self.glyphTabID,
	}

	self.isMinimizingEnabled = false
	self.manualMinimizeEnabled = false
	self.minimizedOnNextShow = false
	self.MaximizeMinimizeButton:Hide()

	-- Retail lifts the close button over the metal border (SetFrameLevelsFromBaseLevel(5000)); set
	-- it just above the border's level, whatever level that ended up at on this client.
	self.CloseButton:SetFrameLevel(self.NineSlice:GetFrameLevel() + 2)

	self:UpdatePortrait()
end

function PlayerSpellsFrameMixin:UpdateTabs()
	for _, tabID in pairs({ self.specTabID, self.talentTabID, self.petTabID, self.glyphTabID }) do
		self.TabSystem:SetTabShown(tabID, self:IsTabAvailable(tabID))
	end
	local currentTab = self:GetTab()
	if not currentTab or not self:IsTabAvailable(currentTab) then
		self:SetToDefaultAvailableTab()
	end
end

function PlayerSpellsFrameMixin:SetToDefaultAvailableTab()
	if self:IsTabAvailable(self.talentTabID) then
		self:SetTab(self.talentTabID)
	elseif self:IsTabAvailable(self.specTabID) then
		self:SetTab(self.specTabID)
	end
end

local RetailIsTabAvailable = PlayerSpellsFrameMixin.IsTabAvailable
function PlayerSpellsFrameMixin:IsTabAvailable(tabID)
	if tabID == nil then
		return false
	end
	if tabID == self.glyphTabID then
		return not self:IsInspecting() and G.UnitLevel("player") >= 15
	elseif tabID == self.petTabID then
		return not self:IsInspecting() and ns.Traits.GetPetTreeID() ~= nil
	end
	return RetailIsTabAvailable(self, tabID)
end

local RetailUpdateFrameTitle = PlayerSpellsFrameMixin.UpdateFrameTitle
function PlayerSpellsFrameMixin:UpdateFrameTitle()
	if not self:IsInspecting() and self.glyphTabID and self:GetTab() == self.glyphTabID then
		self:SetTitle(G.GLYPHS or L.TAB_GLYPHS)
		return
	elseif not self:IsInspecting() and self.petTabID and self:GetTab() == self.petTabID then
		self:SetTitle(L.PET_TITLE)
		return
	end
	return RetailUpdateFrameTitle(self)
end

function PlayerSpellsFrameMixin:DoesTabSupportMinimizedMode()
	return false
end

function PlayerSpellsFrameMixin:GetDefaultMinimizableTab()
	return nil
end

function PlayerSpellsFrameMixin:SetMinimizingEnabled()
	self.isMinimizingEnabled = false
end

function PlayerSpellsFrameMixin:SetMinimized()
end
