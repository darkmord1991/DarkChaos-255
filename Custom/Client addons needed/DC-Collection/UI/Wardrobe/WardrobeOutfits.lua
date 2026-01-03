--[[
    DC-Collection UI/Wardrobe/WardrobeOutfits.lua
    ============================================

    Outfits tab: custom 3x2 grid with large previews.
]]

local DC = DCCollection
if not DC then return end

DC.Wardrobe = DC.Wardrobe or {}
local Wardrobe = DC.Wardrobe

-- ============================================================================
-- OUTFIT SYSTEM
-- ============================================================================

function Wardrobe:ShowOutfitsContent()
    if self.frame then
        if self.frame.modelTitle then self.frame.modelTitle:SetText("Saved Outfits") end
        if self.frame.communityHost then self.frame.communityHost:Hide() end
        if DC and DC.CommunityUI and DC.CommunityUI.frame then
            DC.CommunityUI.frame:Hide()
        end

        -- Hide items/sets specific controls
        if self.frame.orderBtn then self.frame.orderBtn:Hide() end
        if self.frame.filterBtn then self.frame.filterBtn:Hide() end
        if self.frame.qualityDropdown then self.frame.qualityDropdown:Hide() end
        if self.frame.searchBox then self.frame.searchBox:Hide() end
        
        -- Hide slot filters
        for _, btn in ipairs(self.frame.slotFilterButtons or {}) do
            btn:Hide()
        end
        
        -- Hide standard grid container
        if self.frame.gridContainer then self.frame.gridContainer:Hide() end
        if self.frame.gridFrame then self.frame.gridFrame:Hide() end
        
        -- Show outfit grid container
        if self.frame.outfitGridContainer then self.frame.outfitGridContainer:Show() end

        -- Hide collected bar (Outfits are not "collected" in the same sense)
        if self.frame.collectedFrame then self.frame.collectedFrame:Hide() end
        if self.frame.showUncollectedCheck then self.frame.showUncollectedCheck:Hide() end
        
        if self.frame.modelPanel then self.frame.modelPanel:Show() end

        -- Preview Mode Frame handled globally in WardrobeUI
        if self.frame.previewModeFrame then
             self.frame.previewModeFrame:Show()
        end

        -- Show Outfit Controls
        if self.frame.newOutfitBtn then self.frame.newOutfitBtn:Show() end
        if self.frame.randomOutfitBtn then self.frame.randomOutfitBtn:Show() end

        -- Request latest from server
        if DC.Protocol and DC.Protocol.RequestSavedOutfits then
            DC.Protocol:RequestSavedOutfits()
        end
    end
    
    -- Reset pagination when switching to this tab
    self.currentPage = 1
    self.totalPages = 1
    
    self:RefreshOutfitsGrid()
end

function Wardrobe:ShowSaveOutfitDialog()
    StaticPopupDialogs["DC_SAVE_OUTFIT"] = {
        text = "Enter outfit name:",
        button1 = "Save",
        button2 = "Cancel",
        hasEditBox = true,
        maxLetters = 32,
        OnAccept = function(selfPopup)
            local name = selfPopup.editBox:GetText()
            if name and name ~= "" then
                Wardrobe:SaveCurrentOutfit(name)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("DC_SAVE_OUTFIT")
end

function Wardrobe:SaveCurrentOutfit(name)
    if not DC.db then DC.db = {} end
    if not DC.db.outfits then DC.db.outfits = {} end

    -- Always use ID 0 for new outfits - server will auto-increment
    local id = 0
    
    local outfit = {
        id = id,
        name = name,
        icon = "Interface\\Icons\\INV_Chest_Cloth_17", 
        slots = {},
    }

    for _, slotDef in ipairs(self.EQUIPMENT_SLOTS or {}) do
        local invSlotId = GetInventorySlotInfo(slotDef.key)
        if invSlotId then
            local itemId = GetInventoryItemID("player", invSlotId)
            if itemId then
                -- Check for transmog
                local transmogId = DC.transmogState and DC.transmogState[tostring(invSlotId-1)]
                
                -- Store the actual transmog appearance ID if available, otherwise item ID
                outfit.slots[slotDef.key] = tonumber(transmogId) or itemId
                
                -- Capture icon from chest/head for main icon if not set
                if (slotDef.key == "ChestSlot" or slotDef.key == "HeadSlot") and outfit.icon == "Interface\\Icons\\INV_Chest_Cloth_17" then
                     local _, _, _, _, _, _, _, _, _, tex = GetItemInfo(itemId)
                     if tex then outfit.icon = tex end
                end
            end
        end
    end

    -- Sanitize icon path (replace backslashes with forward slashes) to prevent server/DB corruption
    if outfit.icon then
        outfit.icon = string.gsub(outfit.icon, "\\", "/")
    end

    -- Send to server
    if DC.Protocol and DC.Protocol.SaveOutfit then
        DC.Protocol:SaveOutfit(id, outfit.name, outfit.icon, outfit.slots)
        -- Also add locally for instant feedback (will be overwritten by sync)
        table.insert(DC.db.outfits, outfit)
        DC:Print("Outfit '" .. name .. "' saved to server!")
    else
        DC:Print("Error: Protocol not ready.")
    end

    -- Refresh UI immediately
    if self.currentTab == "outfits" then
        self:RefreshOutfitsGrid()
    end
end

function Wardrobe:LoadOutfit(outfit)
    if not outfit then return end

    for slotKey, itemId in pairs(outfit.slots or {}) do
        -- itemId here is the Appearance ID or Item ID we want to look like
        
        local invSlotId = GetInventorySlotInfo(slotKey)
        -- We apply to the slot if we have an item equipped there
        if invSlotId and GetInventoryItemID("player", invSlotId) then
            if DC and DC.RequestSetTransmog then
                -- Note: The server expects (slot, entryId).
                -- entryId should be the item entry of the appearance.
                DC:RequestSetTransmog(invSlotId-1, itemId) 
            end
        end
    end

    if DC and DC.Print then
        DC:Print("Outfit '" .. (outfit.name or "") .. "' applied!")
    end
end

function Wardrobe:RandomizeOutfit()
    if not self.BuildAppearanceList then return end
    
    -- Cache current tab/slot to restore later
    local originalTab = self.currentTab
    local originalSlot = self.selectedSlot
    
    if DC and DC.Print then DC:Print("Randomizing outfit...") end

    local collectedBySlot = {}
    
    -- Iterate all slots to find collected items
    -- We can reuse BuildAppearanceList but we need to temporarily trick it into thinking a specific slot filter is active.
    -- Or we can just iterate the raw definitions if available.
    -- Reusing BuildAppearanceList is safer to respect "collected" logic.
    
    for _, slotDef in ipairs(self.SLOT_FILTERS or {}) do
        -- Mock selection
        self.selectedSlotFilter = slotDef
        -- Force re-building list for this slot
        local list = self:BuildAppearanceList()
        
        -- Filter only collected items
        local collected = {}
        for _, item in ipairs(list) do
            if item.collected then
                table.insert(collected, item.itemId)
            end
        end
        collectedBySlot[slotDef.label] = collected
    end
    
    -- Restore state
    self.selectedSlotFilter = nil
    
    -- Now select random items
    for _, slotDef in ipairs(self.EQUIPMENT_SLOTS or {}) do
        -- Map EQUIPMENT_SLOTS to SLOT_FILTERS labels
        -- This mapping is a bit loose in the core file, let's try to match by invType.
        local invSlotId, _ = GetInventorySlotInfo(slotDef.key)
        if invSlotId then
            local slotCandidates = {}
            -- Find the matching filter group(s)
            for _, filter in ipairs(self.SLOT_FILTERS or {}) do
                if filter.invTypes[slotDef.invType] then
                    local items = collectedBySlot[filter.label]
                    if items then
                        for _, id in ipairs(items) do
                            table.insert(slotCandidates, id)
                        end
                    end
                end
            end
            
            if #slotCandidates > 0 then
                local randomItemId = slotCandidates[math.random(1, #slotCandidates)]
                if randomItemId then
                    -- Apply to model
                     if self.frame.model then
                         local link = "item:" .. tostring(randomItemId) .. ":0:0:0:0:0:0:0"
                         self.frame.model:TryOn(link)
                     end
                     -- Apply to actual character (Preview only? User said "random outfit option", usually implies applying it or previewing it to save)
                     -- "Randomize Outfit" usually implies changing the *current look* (Transmog) or just the preview model?
                     -- "where random appearances are choosen for every slot that are known by the player"
                     -- Let's just update the preview model first. Applying it automatically might be annoying.
                     -- The user can then click "Save" to save it as an outfit.
                     
                     -- Wait, if they want to APPLY it to their character, they'd need an "Apply" button or we just apply it?
                     -- "Random outfit option" -> usually generates a look.
                     -- I'll stick to updating the preview model for now.
                     -- To apply it, they would need to look at the model and maybe click "Apply".
                     -- But currently "Apply" logic is tied to Saved Outfits or Individual Items.
                     -- There isn't an "Apply current model look to character" button.
                     -- Maybe I should just Apply it directly? "Randomize" usually acts as an action.
                     -- Let's Apply it directly to the character (transmog).
                     
                     if DC and DC.RequestSetTransmog then
                         DC:RequestSetTransmog(invSlotId-1, randomItemId)
                     end
                end
            end
        end
    end
    
    if DC and DC.Print then DC:Print("Random outfit applied!") end
end

function Wardrobe:RefreshOutfitsGrid()
    local buttons = self.frame and self.frame.outfitButtons
    if not buttons and _G["DCCollectionWardrobeFrame"] then
        buttons = _G["DCCollectionWardrobeFrame"].outfitButtons
    end
    
    if not buttons then return end

    local outfits = DC.db and DC.db.outfits or {}
    DC:Print("DEBUG: RefreshOutfitsGrid. #outfits = " .. (outfits and #outfits or "nil"))
    local ITEMS_PER_PAGE = 6 -- 3x2 grid
    
    local totalOutfits = #outfits
    self.currentPage = self.currentPage or 1
    self.totalPages = math.max(1, math.ceil(totalOutfits / ITEMS_PER_PAGE))
    
    if DC and DC.Print then
        DC:Print("Debug: Refreshing outfits grid. Total outfits: " .. totalOutfits)
    end

    if totalOutfits == 0 then
        if not self.frame.noOutfitsText then
            self.frame.noOutfitsText = self.frame.outfitGridContainer:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
            self.frame.noOutfitsText:SetPoint("CENTER", 0, 0)
            self.frame.noOutfitsText:SetText("No outfits saved yet.\nClick '+' above to save your look!")
        end
        self.frame.noOutfitsText:Show()
    else
        if self.frame.noOutfitsText then
            self.frame.noOutfitsText:Hide()
        end
    end

    if self.frame.pageText then
        self.frame.pageText:SetText(string.format("Page %d / %d", self.currentPage, self.totalPages))
    end

    if self.currentPage > self.totalPages then self.currentPage = self.totalPages end
    
    local startIdx = (self.currentPage - 1) * ITEMS_PER_PAGE
    
    local startIdx = (self.currentPage - 1) * ITEMS_PER_PAGE
    
    for i, btn in ipairs(buttons) do
        local idx = startIdx + i
        local outfit = outfits[idx]
        
        if outfit then
            btn:Show()
            btn.outfit = outfit
            btn.name:SetText(outfit.name or "Outfit " .. idx)
            
            -- Setup Model Preview
            btn.model:Show()
            btn.model:Undress()
            btn.model:SetUnit("player")
            btn.model:SetFacing(0)
            
            -- Try on all items
            if outfit.slots then
                 for _, itemId in pairs(outfit.slots) do
                     local itemLink = "item:" .. itemId .. ":0:0:0:0:0:0:0"
                     btn.model:TryOn(itemLink)
                 end
            end
            
            -- Hook Interaction
            btn:SetScript("OnClick", function(selfBtn, button)
                if IsModifiedClick("CHATLINK") then
                    local link = "[Outfit: " .. (selfBtn.outfit.name or "Link") .. "]" -- Simplified link for now
                    if ChatEdit_InsertLink then
                         ChatEdit_InsertLink(link)
                    end
                    return
                end
                
                -- Apply outfit on click
                Wardrobe:LoadOutfit(selfBtn.outfit)
            end)
            
            btn:SetScript("OnEnter", function(selfBtn)
                 GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                 GameTooltip:SetText(selfBtn.outfit.name)
                 GameTooltip:AddLine("Click to Apply", 0, 1, 0)
                 GameTooltip:AddLine("Shift+Click to Link", 1, 1, 1)
                 GameTooltip:Show()
            end)
            
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
        else
            btn:Hide()
        end
    end
    
    -- Update Page Text
    if self.frame.pageText then
        self.frame.pageText:SetText(string.format("Page %d / %d", self.currentPage, self.totalPages))
    end
    
    -- Update Page Buttons
    if self.frame.prevBtn then
        self.frame.prevBtn:SetEnabled(self.currentPage > 1)
    end
    if self.frame.nextBtn then
        self.frame.nextBtn:SetEnabled(self.currentPage < self.totalPages)
    end
end
