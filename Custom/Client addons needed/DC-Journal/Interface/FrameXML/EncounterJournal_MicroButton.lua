local function LoadMicroButtonTextures(self, name)
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local prefix = "Interface\\Buttons\\UI-MicroButton-"
	self:SetNormalTexture(prefix .. name .. "-Up")
	self:SetPushedTexture(prefix .. name .. "-Down")
	self:SetDisabledTexture(prefix .. name .. "-Disabled")
	self:SetHighlightTexture("Interface\\Buttons\\UI-MicroButton-Hilight")
end

function EncounterJournal_SetupMicroButton()
	if EncounterJournalMicroButton or not QuestLogMicroButton then
		return
	end

	local parent = MainMenuBarArtFrame or MainMenuBar
	if not parent then
		return
	end

	local btn = CreateFrame("Button", "EncounterJournalMicroButton", parent, "MainMenuBarMicroButton")
	LoadMicroButtonTextures(btn, "EJ")
	btn:SetPoint("BOTTOMLEFT", QuestLogMicroButton, "BOTTOMRIGHT", -3, 0)

	if SocialsMicroButton then
		SocialsMicroButton:ClearAllPoints()
		SocialsMicroButton:SetPoint("BOTTOMLEFT", btn, "BOTTOMRIGHT", -3, 0)
	end

	local title = ADVENTURE or "Adventure Guide"
	btn.tooltipText = MicroButtonTooltipText(title, "TOGGLEENCOUNTERJOURNAL") or title
	btn.newbieText = MAINMENUBAR_EJ_NEWBIE_TOOLTIP or title
	btn:SetScript("OnClick", ToggleEncounterJournalFrame)

	if not EncounterJournalMicroButtonHooked and UpdateMicroButtons then
		EncounterJournalMicroButtonHooked = true
		local orig = UpdateMicroButtons
		UpdateMicroButtons = function()
			orig()
			if EncounterJournal and EncounterJournal:IsShown() then
				btn:SetButtonState("PUSHED", 1)
			else
				btn:SetButtonState("NORMAL")
			end
		end
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", EncounterJournal_SetupMicroButton)
