--[[
	DC-Talents - the hunter pet tab.

	Retail's generic tree renderer (TalentFrameBaseTemplate) bound to the pet config (C_Traits config 50,
	see DC/Traits.lua): the pet's single WotLK tree, centred, with the class-talent button art, its own
	points line and Apply / Undo buttons. Commits go through C_Traits like the class tree: the DC server
	module applies a whole pet build at once; without it, additions use the stock preview path.
]]

local _, ns = ...
setfenv(1, ns.env)

local G = ns.realG
local L = ns.L
local UI = ns.UI

local CONFIG_PET = ns.Traits.CONFIG_PET

ns.XML.RegisterTemplate("DCTalentsPetFrameTemplate", {
	tag = "Frame",
	attr = { name = "DCTalentsPetFrameTemplate", inherits = "TalentFrameBaseTemplate", mixin = "DCPetTalentsFrameMixin", virtual = "true" },
	children = {
		{ tag = "KeyValues", children = {
			{ tag = "KeyValue", attr = { key = "getTemplateType", value = "ClassTalentUtil.GetTemplateForTalentType", type = "global" } },
			{ tag = "KeyValue", attr = { key = "getSpecializedMixin", value = "ClassTalentUtil.GetSpecializedMixin", type = "global" } },
			{ tag = "KeyValue", attr = { key = "getSpecializedChoiceMixin", value = "ClassTalentUtil.GetSpecializedChoiceMixin", type = "global" } },
			{ tag = "KeyValue", attr = { key = "getEdgeTemplateType", value = "ClassTalentUtil.GetEdgeTemplateType", type = "global" } },
			{ tag = "KeyValue", attr = { key = "bottomPadding", value = "82", type = "number" } },
			{ tag = "KeyValue", attr = { key = "basePanOffsetX", value = "49", type = "number" } },
			{ tag = "KeyValue", attr = { key = "basePanOffsetY", value = "-30", type = "number" } },
			{ tag = "KeyValue", attr = { key = "enableZoomAndPan", value = "false", type = "boolean" } },
			{ tag = "KeyValue", attr = { key = "maximumCommitTime", value = "10", type = "number" } },
			{ tag = "KeyValue", attr = { key = "disabledOverlayAlpha", value = ".3", type = "number" } },
			{ tag = "KeyValue", attr = { key = "commitSound", value = "SOUNDKIT.UI_CLASS_TALENT_APPLY_CHANGES", type = "global" } },
		} },
	},
}, "DC/PetTalents.lua")

DCPetTalentsFrameMixin = {}

function DCPetTalentsFrameMixin:OnLoad()
	TalentFrameBaseMixin.OnLoad(self)

	self.Background = self:CreateTexture(nil, "BACKGROUND")
	self.Background:SetAllPoints()
	self.Background:SetColorTexture(0.035, 0.035, 0.045, 1)

	self.TreeName = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge2")
	self.TreeName:SetPoint("TOP", self, "TOP", 0, -24)
	self.TreePoints = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge2")
	self.TreePoints:SetPoint("TOP", self.TreeName, "BOTTOM", 0, -4)

	self.PointsText = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	self.PointsText:SetPoint("BOTTOM", self, "BOTTOM", 0, 50)

	self.Message = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	self.Message:SetPoint("CENTER", self, "CENTER", 0, 40)
	self.Message:SetText(L.PET_NO_PET)
	self.Message:Hide()

	self.ApplyButton = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
	self.ApplyButton:SetSize(160, 26)
	self.ApplyButton:SetPoint("BOTTOMRIGHT", self, "BOTTOM", -6, 14)
	self.ApplyButton:SetText(L.PET_APPLY)
	self.ApplyButton:SetScript("OnClick", function()
		self:ApplyConfig()
	end)

	self.UndoButton = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
	self.UndoButton:SetSize(160, 26)
	self.UndoButton:SetPoint("BOTTOMLEFT", self, "BOTTOM", 6, 14)
	self.UndoButton:SetText(L.PET_UNDO)
	self.UndoButton:SetScript("OnClick", function()
		self:RollbackConfig()
	end)
end

-- The pet can change while the window is closed: rebuild the tree whenever the tab shows.
function DCPetTalentsFrameMixin:OnShow()
	self:Reload()
	TalentFrameBaseMixin.OnShow(self)
	self:UpdateDCState()
end

function DCPetTalentsFrameMixin:Reload()
	if ns.Traits.GetPetTreeID() then
		self:SetConfigID(CONFIG_PET, true)
	else
		self:ReleaseAllTalentButtons()
		self.talentTreeID = nil
		self.configurationInfo = nil
	end
end

function DCPetTalentsFrameMixin:ApplyConfig()
	local configID = self:GetConfigID()
	if configID and C_Traits.ConfigHasStagedChanges(configID) then
		self:CommitConfig()
	end
	self:UpdateDCState()
end

function DCPetTalentsFrameMixin:RollbackConfig(...)
	TalentFrameBaseMixin.RollbackConfig(self, ...)
	self:UpdateTreeCurrencyInfo()
end

function DCPetTalentsFrameMixin:UpdateTreeCurrencyInfo(skipButtonUpdates)
	TalentFrameBaseMixin.UpdateTreeCurrencyInfo(self, skipButtonUpdates)
	self:UpdateDCState()
end

function DCPetTalentsFrameMixin:OnTraitConfigUpdated(configID)
	TalentFrameBaseMixin.OnTraitConfigUpdated(self, configID)
	self:UpdateDCState()
end

function DCPetTalentsFrameMixin:SetCommitStarted(...)
	TalentFrameBaseMixin.SetCommitStarted(self, ...)
	self:UpdateDCState()
end

-- The class-talent buttons ask their frame these (ClassTalentsFrameMixin / ClassTalentSearchMixin).
function DCPetTalentsFrameMixin:HasAnyPendingChanges()
	local configID = self:GetConfigID()
	return self:IsCommitInProgress() or (configID ~= nil and C_Traits.ConfigHasStagedChanges(configID))
end

function DCPetTalentsFrameMixin:GetSearchMatchTypeForEntry()
	return nil
end

function DCPetTalentsFrameMixin:IsHeroSpecActive()
	return false
end

function DCPetTalentsFrameMixin:IsPreviewingSubTree()
	return false
end

function DCPetTalentsFrameMixin:IsHighlightedStarterBuildEntry()
	return false
end

function DCPetTalentsFrameMixin:TryPurchaseToNode()
end

function DCPetTalentsFrameMixin:TryRefundToNode()
end

function DCPetTalentsFrameMixin:UpdateDCState()
	if not self.PointsText then
		return
	end
	local hasTree = self:GetTalentTreeID() ~= nil
	local configID = self:GetConfigID()
	local staged = hasTree and configID and C_Traits.ConfigHasStagedChanges(configID) or false
	local busy = self:IsCommitInProgress()

	self.Message:SetShown(not hasTree)
	self.ApplyButton:SetEnabled(staged and not busy)
	self.UndoButton:SetEnabled(staged and not busy)

	local points = hasTree and self.treeCurrencyInfo and self.treeCurrencyInfo[1]
	if points then
		self.PointsText:SetText(L.PET_POINTS_FORMAT:format(points.quantity or 0))
		self.PointsText:Show()
	else
		self.PointsText:Hide()
	end

	local name = hasTree and G.GetTalentTabInfo(1, false, true)
	if name then
		self.TreeName:SetText(name:upper())
		self.TreePoints:SetText(points and points.spent or 0)
		self.TreeName:Show()
		self.TreePoints:Show()
	else
		self.TreeName:Hide()
		self.TreePoints:Hide()
	end
end

function UI.CreatePetTab(playerSpellsFrame)
	local page = CreateFrame("Frame", "DCTalentsPetPage", playerSpellsFrame, "DCTalentsPetFrameTemplate")
	page:SetSize(1612, 856)
	page:SetPoint("BOTTOM", playerSpellsFrame, "BOTTOM", 0, 4)
	page:SetFrameLevel(ns.Engine.MapFrameLevel(100))
	page:Hide()
	return page
end

-- Pet summoned, dismissed, or its talents changed (Traits invalidated the tree already).
local previousPetHook = ns.OnPetTalentsChanged
ns.OnPetTalentsChanged = function(...)
	if previousPetHook then
		previousPetHook(...)
	end
	local frame = UI.GetFrame and UI.GetFrame()
	if not frame then
		return
	end
	frame:UpdateTabs()
	local page = frame.PetFrame
	if page and page:IsShown() then
		page:Reload()
		page:UpdateDCState()
	end
end
