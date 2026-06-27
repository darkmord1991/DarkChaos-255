function ToggleEncounterJournalFrame()
	if EncounterJournal and EncounterJournal:IsShown() then
		HideUIPanel(EncounterJournal)
	else
		ShowUIPanel(EncounterJournal)
	end
	if UpdateMicroButtons then
		UpdateMicroButtons()
	end
end

SLASH_ENCOUNTERJOURNAL1 = "/ej"
SLASH_ENCOUNTERJOURNAL2 = "/adventure"
SlashCmdList["ENCOUNTERJOURNAL"] = ToggleEncounterJournalFrame

BINDING_NAME_TOGGLEENCOUNTERJOURNAL = ADVENTURE_JOURNAL or "Adventure Guide"
