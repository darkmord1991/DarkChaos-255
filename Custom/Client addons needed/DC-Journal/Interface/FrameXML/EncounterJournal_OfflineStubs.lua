S_ATLAS_STORAGE = S_ATLAS_STORAGE or {}

if not MicroButtonTooltipText then
	function MicroButtonTooltipText(text, action)
		if not text then
			return ""
		end
		if action and GetBindingKey and GetBindingKey(action) and GetBindingText then
			return text.." "..NORMAL_FONT_COLOR_CODE.."("..GetBindingText(GetBindingKey(action), "KEY_")..")"..FONT_COLOR_CODE_CLOSE
		end
		return text
	end
end

if not IsArtifactRelicItem then
	function IsArtifactRelicItem(itemIDOrLink)
		return false
	end
end

function ChatEdit_TryInsertChatLink(link)
	if link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() and ChatEdit_InsertLink then
		return ChatEdit_InsertLink(link)
	end
	return false
end

function MountJournal_UpdateScrollPos(self, visibleIndex)
	if not self then
		return
	end
	local buttons = self.buttons
	local buttonHeight = self.buttonHeight or 0
	local buttonCount = buttons and #buttons or 0
	local height = math.max(0, math.floor(buttonHeight * (visibleIndex - (buttonCount / 2))))
	if HybridScrollFrame_SetOffset then
		HybridScrollFrame_SetOffset(self, height)
	end
	if self.scrollBar then
		self.scrollBar:SetValue(height)
	end
end

C_Service = C_Service or {}
function C_Service:GetRealmID()
	return 1
end
function C_Service:IsLockRenegadeFeatures()
	return true
end
function C_Service:IsGM()
	return false
end

C_FactionManager = C_FactionManager or {}
function C_FactionManager:RegisterFactionOverrideCallback(callback, runNow)
	if runNow and callback then
		callback()
	end
end
function C_FactionManager:GetFactionOverride()
	return nil
end

C_Unit = C_Unit or {}
function C_Unit:GetFactionID(unit)
	local factionGroup = UnitFactionGroup(unit)
	if factionGroup == "Alliance" then
		return 1
	elseif factionGroup == "Horde" then
		return 0
	end
	return 1
end

C_CreatureInfo = C_CreatureInfo or {}
function C_CreatureInfo.GetFactionInfo(race)
	local factionGroup = UnitFactionGroup("player")
	return {
		groupTag = factionGroup or "Alliance",
		factionID = factionGroup == "Horde" and 0 or 1,
	}
end

local function EJ_Assign(parent, key, globalName)
	if not parent or not key then
		return
	end
	if not parent[key] then
		parent[key] = _G[globalName]
	end
end

function EJ_WireFrameReferences()
	local ej = _G.EncounterJournal
	if not ej then
		return
	end

	EJ_Assign(ej, "instanceSelect", "EncounterJournalInstanceSelect")
	EJ_Assign(ej, "encounter", "EncounterJournalEncounterFrame")
	EJ_Assign(ej, "inset", "EncounterJournalInset")
	EJ_Assign(ej, "navBar", "EncounterJournalNavBar")
	EJ_Assign(ej, "searchBox", "EncounterJournalSearchBox")
	EJ_Assign(ej, "searchResults", "EncounterJournalSearchResults")

	local instanceSelect = ej.instanceSelect
	if instanceSelect then
		EJ_Assign(instanceSelect, "bg", "EncounterJournalInstanceSelectBG")
		EJ_Assign(instanceSelect, "scroll", "EncounterJournalInstanceSelectScrollFrame")
		EJ_Assign(instanceSelect, "dungeonsTab", "EncounterJournalInstanceSelectDungeonTab")
		EJ_Assign(instanceSelect, "raidsTab", "EncounterJournalInstanceSelectRaidTab")
		EJ_Assign(instanceSelect, "suggestTab", "EncounterJournalInstanceSelectSuggestTab")
		EJ_Assign(instanceSelect, "LootJournalTab", "EncounterJournalInstanceSelectLootJournalTab")
		EJ_Assign(instanceSelect, "tierDropDown", "EncounterJournalInstanceSelectTierDropDown")
		if instanceSelect.scroll then
			EJ_Assign(instanceSelect.scroll, "child", "EncounterJournalInstanceSelectScrollFrameScrollChild")
		end
	end

	local encounter = ej.encounter
	if encounter then
		EJ_Assign(encounter, "instance", "EncounterJournalEncounterFrameInstanceFrame")
		EJ_Assign(encounter, "info", "EncounterJournalEncounterFrameInfo")
		local info = encounter.info
		if info then
			EJ_Assign(info, "model", "EncounterJournalEncounterFrameInfoModelFrame")
			EJ_Assign(info, "overviewTab", "EncounterJournalEncounterFrameInfoOverviewTab")
			EJ_Assign(info, "lootTab", "EncounterJournalEncounterFrameInfoLootTab")
			EJ_Assign(info, "bossTab", "EncounterJournalEncounterFrameInfoBossTab")
			EJ_Assign(info, "modelTab", "EncounterJournalEncounterFrameInfoModelTab")
			EJ_Assign(info, "overviewScroll", "EncounterJournalEncounterFrameInfoOverviewScrollFrame")
			EJ_Assign(info, "lootScroll", "EncounterJournalEncounterFrameInfoLootScrollFrame")
			EJ_Assign(info, "detailsScroll", "EncounterJournalEncounterFrameInfoDetailsScrollFrame")
			EJ_Assign(info, "bossesScroll", "EncounterJournalEncounterFrameInfoBossesScrollFrame")
			EJ_Assign(info, "TitleFrame", "EncounterJournalEncounterFrameInfoTitleFrame")
			EJ_Assign(info, "instanceButton", "EncounterJournalEncounterFrameInfoInstanceButton")
			EJ_Assign(info, "difficulty", "EncounterJournalEncounterFrameInfoDifficulty")
			EJ_Assign(info, "rightShadow", "EncounterJournalEncounterFrameInfoRightHeaderShadow")
			local model = info.model
			if model then
				EJ_Assign(model, "dungeonBG", "EncounterJournalEncounterFrameInfoModelFrameDungeonBG")
				EJ_Assign(model, "imageTitle", "EncounterJournalEncounterFrameInfoModelFrameImageTile")
			end
			local infoFrame = _G["EncounterJournalEncounterFrameInfo"]
			if infoFrame and infoFrame.creatureButtons and not info.creatureButtons then
				info.creatureButtons = infoFrame.creatureButtons
			end
		end
	end
end
