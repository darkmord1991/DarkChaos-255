local function LoadMicroButtonTextures(self, name)
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local prefix = "Interface\\Buttons\\UI-MicroButton-"
	self:SetNormalTexture(prefix .. name .. "-Up")
	self:SetPushedTexture(prefix .. name .. "-Down")
	self:SetDisabledTexture(prefix .. name .. "-Disabled")
	self:SetHighlightTexture("Interface\\Buttons\\UI-MicroButton-Hilight")
end

-- Stock VehicleMenuBar_MoveMicroButtons runs whenever the main bar comes back from a
-- vehicle or possess bar (and whenever a vehicle skin is applied) and re-anchors
-- SocialsMicroButton straight to QuestLogMicroButton. That lays Socials over this
-- button and shifts the rest of the bar back by one slot, so the journal "turns into"
-- Social. Re-slot the button after every such move.
local function EncounterJournal_AnchorMicroButton(skinName)
	local btn = EncounterJournalMicroButton
	if not btn or not QuestLogMicroButton then
		return
	end

	btn:SetParent(QuestLogMicroButton:GetParent())
	btn:ClearAllPoints()
	btn:SetPoint("BOTTOMLEFT", QuestLogMicroButton, "BOTTOMRIGHT", -3, 0)
	btn:Show()

	-- Vehicle skins stack Socials under Character as the start of a second row; only the
	-- flat bar chains Socials after the journal button.
	if not skinName and SocialsMicroButton then
		SocialsMicroButton:ClearAllPoints()
		SocialsMicroButton:SetPoint("BOTTOMLEFT", btn, "BOTTOMRIGHT", -3, 0)
	end
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
	EncounterJournal_AnchorMicroButton(VehicleMenuBar and VehicleMenuBar.currSkin)

	if VehicleMenuBar_MoveMicroButtons then
		hooksecurefunc("VehicleMenuBar_MoveMicroButtons", EncounterJournal_AnchorMicroButton)
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
