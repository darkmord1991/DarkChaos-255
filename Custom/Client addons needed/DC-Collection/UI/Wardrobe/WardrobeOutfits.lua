--[[
    DC-Collection UI/Wardrobe/WardrobeOutfits.lua
    ============================================

    Outfits tab: simple list + load/delete actions.

    Notes:
    - Outfits paging should not change tabs; paging buttons are disabled while in outfits.
]]

local DC = DCCollection
if not DC then return end

DC.Wardrobe = DC.Wardrobe or {}
local Wardrobe = DC.Wardrobe

-- ============================================================================
-- OUTFIT SYSTEM (ported from the original monolithic WardrobeFrame.lua)
-- ============================================================================

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

    local index = nil
    for i = 1, 20 do
        if not DC.db.outfits[i] then
            index = i
            break
        end
    end

    if not index then
        if DC and DC.Print then
            DC:Print("Outfit slots full!")
        end
        return
    end

    local outfit = {
        name = name,
        icon = "Interface\\Icons\\INV_Chest_Cloth_17",
        slots = {},
        date = date("%Y-%m-%d"),
        level = UnitLevel("player"),
    }

    for _, slotDef in ipairs(self.EQUIPMENT_SLOTS or {}) do
        local invSlotId = GetInventorySlotInfo(slotDef.key)
        if invSlotId then
            local itemId = GetInventoryItemID("player", invSlotId)
            if itemId then
                local transmogId = DC.transmogState and DC.transmogState[tostring(invSlotId)]
                outfit.slots[slotDef.key] = transmogId or itemId
            end
        end
    end

    DC.db.outfits[index] = outfit
    if DC and DC.Print then
        DC:Print("Outfit '" .. name .. "' saved!")
    end

    self:UpdateOutfitSlots()
end

function Wardrobe:LoadOutfit(index)
    local outfits = DC.db and DC.db.outfits or {}
    local outfit = outfits[index]

    if not outfit then
        if DC and DC.Print then
            DC:Print("No outfit saved in this slot.")
        end
        return
    end

    for slotKey, itemId in pairs(outfit.slots or {}) do
        local invSlotId = GetInventorySlotInfo(slotKey)
        if invSlotId and GetInventoryItemID("player", invSlotId) then
            if DC and DC.RequestSetTransmog then
                DC:RequestSetTransmog(invSlotId, itemId)
            end
        end
    end

    if DC and DC.Print then
        DC:Print("Outfit '" .. (outfit.name or "") .. "' applied!")
    end
end

function Wardrobe:UpdateOutfitSlots()
    if not self.frame or not self.frame.outfitSlots then return end

    local outfits = DC.db and DC.db.outfits or {}

    for i, slot in ipairs(self.frame.outfitSlots) do
        local outfit = outfits[i]
        if outfit then
            slot.icon:SetTexture(outfit.icon or "Interface\\Icons\\INV_Chest_Cloth_17")
            slot.icon:Show()
        else
            slot.icon:Hide()
        end
    end
end

function Wardrobe:RefreshOutfitsGrid()
    if not self.frame then return end

    local outfits = DC.db and DC.db.outfits or {}

    for i, btn in ipairs(self.frame.gridButtons) do
        local outfit = outfits[i]

        if outfit then
            btn:Show()
            btn.itemData = { outfit = outfit, index = i }
            btn.icon:SetTexture(outfit.icon or "Interface\\Icons\\INV_Chest_Cloth_17")
            btn.icon:SetVertexColor(1, 1, 1)
            btn.notCollected:Hide()
            
            -- Override search hit highlighting if not needed, or keep it
            
            -- Hook scripts if not already done (assuming buttons are reused)
            if not btn.dcOutfitScriptsHooked then
                btn.dcOutfitScriptsHooked = true
                
                btn:SetScript("OnClick", function(self, button)
                    if not self.itemData or not self.itemData.outfit then return end
                    
                    if IsModifiedClick("CHATLINK") then
                        local link = DC:GenerateOutfitLink(self.itemData.outfit.name, self.itemData.outfit)
                        if link then
                            if ChatEdit_InsertLink then
                                ChatEdit_InsertLink(link)
                            end
                        end
                        return
                    end
                    
                    if IsModifiedClick("DRESSUP") then
                        DC:PreviewOutfit(self.itemData.outfit.name)
                        return
                    end
                    
                    -- Normal click: apply
                    DC:ApplyOutfit(self.itemData.outfit.name)
                end)
                
                btn:SetScript("OnEnter", function(self)
                    if not self.itemData or not self.itemData.outfit then return end
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(self.itemData.outfit.name, 1, 1, 1)
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Click to apply", 0.7, 0.7, 0.7)
                    GameTooltip:AddLine("Ctrl-Click to preview", 0.7, 0.7, 0.7)
                    GameTooltip:AddLine("Shift-Click to link", 0.7, 0.7, 0.7)
                    GameTooltip:Show()
                end)
                
                btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
        else
            btn:Hide()
            btn.itemData = nil
        end
    end

    if self.frame.pageText then
        self.frame.pageText:SetText("Saved Outfits")
    end

    if self.frame.prevBtn then self.frame.prevBtn:Disable() end
    if self.frame.nextBtn then self.frame.nextBtn:Disable() end

    if self.frame.collectedFrame then
        local count = 0
        for _ in pairs(outfits) do count = count + 1 end
        self.frame.collectedFrame.text:SetText(string.format("Outfits: %d", count))
        self.frame.collectedFrame.bar:SetValue(0)
    end
end
