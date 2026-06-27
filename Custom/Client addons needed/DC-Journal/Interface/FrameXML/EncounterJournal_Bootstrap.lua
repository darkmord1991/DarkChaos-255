-- Instances listed here are hidden from the journal without deleting their data.
-- (The custom Sirus instances were removed from the data outright instead.)
local EJ_UI_HIDDEN_INSTANCES = {
}

local function EJ_ApplyContentTabVisibility()
	local instanceSelect = EncounterJournal and EncounterJournal.instanceSelect
	if not instanceSelect then
		return
	end

	if instanceSelect.suggestTab then
		instanceSelect.suggestTab:Hide()
	end
	if instanceSelect.LootJournalTab then
		instanceSelect.LootJournalTab:Hide()
	end
	if instanceSelect.dungeonsTab then
		instanceSelect.dungeonsTab:ClearAllPoints()
		instanceSelect.dungeonsTab:SetPoint("BOTTOMLEFT", instanceSelect, "TOPLEFT", 25, -45)
	end
end

local function EJ_EnsureFrameTabs(frame)
	if not frame then
		return
	end
	frame.tab1 = frame.tab1 or _G.EncounterJournalTab1
	frame.tab2 = frame.tab2 or _G.EncounterJournalTab2
end

if EncounterJournal_InitTab and not EncounterJournal_InitTabHooked then
	local origInitTab = EncounterJournal_InitTab
	EncounterJournal_InitTabHooked = true
	function EncounterJournal_InitTab(self, ...)
		EJ_EnsureFrameTabs(self)
		if origInitTab then
			origInitTab(self, ...)
		end
		if not self.numTabs or self.numTabs < 1 then
			PanelTemplates_SetNumTabs(self, 1)
			PanelTemplates_SetTab(self, 1)
		end
	end
end

if EncounterJournal_OnShow and not EncounterJournal_OnShowHooked then
	local origOnShow = EncounterJournal_OnShow
	EncounterJournal_OnShowHooked = true
	function EncounterJournal_OnShow(self, ...)
		EJ_EnsureFrameTabs(self)
		if EncounterJournal_InitTab and (not self.numTabs or self.numTabs < 1) then
			EncounterJournal_InitTab(self)
		end
		return origOnShow(self, ...)
	end
end

if EncounterJournal_OnLoad and not EncounterJournal_OnLoadHooked then
	local origOnLoad = EncounterJournal_OnLoad
	EncounterJournal_OnLoadHooked = true
	function EncounterJournal_OnLoad(self, ...)
		if EJ_WireFrameReferences then
			EJ_WireFrameReferences()
		end
		EJ_EnsureFrameTabs(self)
		origOnLoad(self, ...)
		EJ_ApplyContentTabVisibility()
	end
end

if EJ_ContentTab_Select and not EJ_ContentTab_SelectHooked then
	local origContentTabSelect = EJ_ContentTab_Select
	EJ_ContentTab_SelectHooked = true
	function EJ_ContentTab_Select(id)
		local instanceSelect = EncounterJournal and EncounterJournal.instanceSelect
		if instanceSelect then
			if instanceSelect.suggestTab and id == instanceSelect.suggestTab:GetID() then
				id = instanceSelect.dungeonsTab:GetID()
			elseif instanceSelect.LootJournalTab and id == instanceSelect.LootJournalTab:GetID() then
				id = instanceSelect.dungeonsTab:GetID()
			end
		end
		return origContentTabSelect(id)
	end
end

if EJ_GetInstanceByIndex and not EJ_GetInstanceByIndexHiddenHooked then
	local origGetInstanceByIndex = EJ_GetInstanceByIndex
	EJ_GetInstanceByIndexHiddenHooked = true
	function EJ_GetInstanceByIndex(index, isRaid)
		local visibleIndex = 0
		local scanIndex = 1
		while true do
			local instanceID, name, description, bgImage, buttonImage, loreImage, mapID, areaID, hyperlink = origGetInstanceByIndex(scanIndex, isRaid)
			if not instanceID then
				return nil
			end
			if not EJ_UI_HIDDEN_INSTANCES[instanceID] then
				visibleIndex = visibleIndex + 1
				if visibleIndex == index then
					return instanceID, name, description, bgImage, buttonImage, loreImage, mapID, areaID, hyperlink
				end
			end
			scanIndex = scanIndex + 1
		end
	end
end
