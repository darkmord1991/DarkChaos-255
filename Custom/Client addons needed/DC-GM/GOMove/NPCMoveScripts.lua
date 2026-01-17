-- NPCMove UI helpers and overrides
-- Loaded after GOMoveScripts.lua

if (not GOMove) then return end

function GOMove:GetMoverNoun()
    return (self.Mode == "NPC") and "creature" or "object"
end

function GOMove:GetMoverLabel()
    return (self.Mode == "NPC") and "NPC" or "GameObject"
end

function GOMove:GetMoverUiLabel()
    return (self.Mode == "NPC") and "NPCMove" or "GOMove"
end

function GOMove:NPCMoveApplyLabels()
    if self.SelInfoTitle then
        self.SelInfoTitle:SetText((self.Mode == "NPC") and "Selected NPC" or "Selected GameObject")
    end
    if self.SpawnSpellButton and self.SpawnSpellButton.SetText then
        if (self.Mode == "NPC") then
            self.SpawnSpellButton:SetText("Spawn+")
        else
            self.SpawnSpellButton:SetText("Send")
        end
    end

    if self.FavFrame and self.FavFrame.NameFrame and self.FavFrame.NameFrame.text then
        self.FavFrame.NameFrame.text:SetText((self.Mode == "NPC") and "NPC Favourites" or "GO Favourites")
    end

    if self.SelFrame and self.SelFrame.NameFrame and self.SelFrame.NameFrame.text then
        self.SelFrame.NameFrame.text:SetText((self.Mode == "NPC") and "NPC Selection" or "GO Selection")
    end

    if self.EntryLabel and self.UpdateEntryLabel then
        self.UpdateEntryLabel()
    end

    if self.NPCMoveApplySelectionButtons then
        self:NPCMoveApplySelectionButtons()
    end
end

function GOMove:NPCMoveApplySelectionButtons()
    if not self.SelFrame or not self.SelFrame.Buttons then
        return
    end

    local noun = (self.Mode == "NPC") and "NPC" or "Object"
    for _, button in ipairs(self.SelFrame.Buttons) do
        if button and button.MiscButton then
            local baseName = button:GetName()
            local favButton = baseName and _G[baseName .. "_Favourite"]
            local deleteButton = baseName and _G[baseName .. "_Delete"]
            local respawnButton = baseName and _G[baseName .. "_Spawn"]
            local useEntryButton = baseName and _G[baseName .. "_Use"]
            local focusButton = baseName and _G[baseName .. "_Focus"]

            -- Buttons are created without named globals; adjust tooltips via scripts if they exist
            if favButton and favButton.SetScript then
                favButton:SetScript("OnEnter", function(selfBtn)
                    GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                    GameTooltip:AddLine("Add to favourites", 1, 1, 1)
                    GameTooltip:AddLine("Saves this " .. noun:lower() .. " so you can quickly spawn it again.", 0.8, 0.8, 0.8, true)
                    GameTooltip:Show()
                end)
                favButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end

            if deleteButton and deleteButton.SetScript then
                deleteButton:SetScript("OnEnter", function(selfBtn)
                    GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                    GameTooltip:AddLine("Delete " .. noun:lower(), 1, 1, 1)
                    GameTooltip:AddLine("Deletes this " .. noun:lower() .. " from the world.", 0.8, 0.8, 0.8, true)
                    GameTooltip:Show()
                end)
                deleteButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end

            if respawnButton and respawnButton.SetScript then
                respawnButton:SetScript("OnEnter", function(selfBtn)
                    GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                    GameTooltip:AddLine("Respawn " .. noun:lower(), 1, 1, 1)
                    GameTooltip:AddLine("Respawns this " .. noun:lower() .. " (useful if it was deleted/hidden).", 0.8, 0.8, 0.8, true)
                    GameTooltip:Show()
                end)
                respawnButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end

            if useEntryButton and useEntryButton.SetScript then
                useEntryButton:SetScript("OnEnter", function(selfBtn)
                    GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                    GameTooltip:AddLine("Use entry", 1, 1, 1)
                    GameTooltip:AddLine("Sets the ENTRY value to this " .. noun:lower() .. " entry so you can spawn it repeatedly.", 0.8, 0.8, 0.8, true)
                    GameTooltip:Show()
                end)
                useEntryButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end

            if focusButton and focusButton.SetScript then
                focusButton:SetScript("OnEnter", function(selfBtn)
                    GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                    GameTooltip:AddLine("Select for modify", 1, 1, 1)
                    GameTooltip:AddLine("Selects only this spawn GUID and fills ENTRY in the " .. (self.Mode == "NPC" and "NPCMove" or "GOMove") .. " UI.", 0.8, 0.8, 0.8, true)
                    GameTooltip:Show()
                end)
                focusButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
        end
    end
end
