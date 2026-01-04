--[[
    DC-Collection UI/Wardrobe/WardrobeOutfits.lua
    ============================================

    Outfits tab: custom 3x2 grid with large previews.
]]

local DC = DCCollection
if not DC then return end

DC.Wardrobe = DC.Wardrobe or {}
local Wardrobe = DC.Wardrobe

local function SerializeSlotsToJsonString(slots)
    if type(slots) ~= "table" then
        return nil
    end

    local keys = {}
    for k in pairs(slots) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

    local parts = {}
    for _, k in ipairs(keys) do
        local v = tonumber(slots[k])
        if v and v > 0 then
            parts[#parts + 1] = string.format('%q:%d', tostring(k), v)
        end
    end

    return "{" .. table.concat(parts, ",") .. "}"
end

local function NextLCG(seed)
    -- Simple LCG (mod 2^31-1) for environments with clobbered math.random.
    seed = tonumber(seed) or 1
    seed = (seed * 1103515245 + 12345) % 2147483647
    if seed <= 0 then
        seed = seed + 2147483646
    end
    return seed
end

local function ChooseIndex(seed, count)
    if not count or count < 1 then
        return seed, nil
    end
    seed = NextLCG(seed)
    local idx = (seed % count) + 1
    return seed, idx
end

-- ============================================================================
-- OUTFIT SYSTEM
-- ============================================================================

function Wardrobe:ShowOutfitsContent()
    if self.frame then
        if self.frame.modelTitle then self.frame.modelTitle:SetText("Saved Outfits") end
        if self.frame.communityHost then self.frame.communityHost:Hide() end
        if self.frame.communityGridContainer then self.frame.communityGridContainer:Hide() end
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
        OnCancel = function()
            Wardrobe._afterSaveAction = nil
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

    -- Sanitize icon path (replace backslashes with forward slashes)
    if outfit.icon then
        outfit.icon = string.gsub(outfit.icon, "\\", "/")
    end

    -- Duplicate Check
    if DC.db.outfits then
        for _, saved in ipairs(DC.db.outfits) do
            -- Parse saved slots if string
            local savedSlots = saved.slots
            if type(savedSlots) == "string" then
                local parsed = {}
                for k, v in savedSlots:gmatch('"?([^":,{}]+)"?%s*:%s*(%d+)') do
                    parsed[k] = tonumber(v)
                end
                savedSlots = parsed
            end
            
            -- Compare with current outfit.slots
            local match = true
            local countCurrent = 0
            for k, v in pairs(outfit.slots) do
                if savedSlots[k] ~= v then
                    match = false
                    break
                end
                countCurrent = countCurrent + 1
            end
            
            if match then
                local countSaved = 0
                for _ in pairs(savedSlots) do countSaved = countSaved + 1 end
                if countSaved ~= countCurrent then
                    match = false
                end
            end
            
            if match then
                DC:Print("Error: An outfit with these exact items already exists: " .. (saved.name or "Unknown"))
                return
            end
        end
    end

    -- Send to server
    if DC.Protocol and DC.Protocol.SaveOutfit then
        DC.Protocol:SaveOutfit(id, outfit.name, outfit.icon, outfit.slots)
        -- Also add locally for instant feedback (will be overwritten by sync)
        table.insert(DC.db.outfits, outfit)
        DC:Print("Outfit '" .. name .. "' saved to server!")

        if type(self.ClearUnsavedChanges) == "function" then
            self:ClearUnsavedChanges()
        end

        if self._afterSaveAction then
            local action = self._afterSaveAction
            self._afterSaveAction = nil
            pcall(action)
        end
    else
        DC:Print("Error: Protocol not ready.")
    end

    -- Refresh UI immediately
    if self.currentTab == "outfits" then
        self:RefreshOutfitsGrid()
    end
end

function Wardrobe:PublishOutfitToCommunity(outfit)
    if not outfit or not DC or type(DC.RequestCommunityPublish) ~= "function" then
        return
    end

    local name = outfit.name or "Outfit"
    local slots = outfit.slots or outfit.items
    local itemsString

    if type(slots) == "string" then
        -- Already a JSON string from server/DB
        itemsString = slots
    elseif type(slots) == "table" then
        -- Convert table to JSON string
        itemsString = SerializeSlotsToJsonString(slots)
    end

    if not itemsString or itemsString == "" or itemsString == "{}" then
        if DC and DC.Print then
            DC:Print("Error: Outfit has no items to publish.")
        end
        return
    end

    DC:RequestCommunityPublish(name, itemsString, "")
end

function Wardrobe:ShowOutfitContextMenu(outfit, anchor)
    if not outfit then
        return
    end

    local menu = {
        { text = outfit.name or "Outfit", isTitle = true, notCheckable = true },
        {
            text = "Share to Community",
            notCheckable = true,
            func = function()
                Wardrobe:PublishOutfitToCommunity(outfit)
            end,
        },
        {
            text = "Delete",
            notCheckable = true,
            func = function()
                StaticPopupDialogs["DC_CONFIRM_DELETE_OUTFIT"] = {
                    text = "Are you sure you want to delete outfit '%s'?",
                    button1 = "Yes",
                    button2 = "No",
                    OnAccept = function()
                        if DC.Protocol and DC.Protocol.DeleteOutfit then
                             DC.Protocol:DeleteOutfit(outfit.id)
                             -- Update local DB immediately
                             if DC.db and DC.db.outfits then
                                 for k, v in ipairs(DC.db.outfits) do
                                     if v.id == outfit.id then
                                         table.remove(DC.db.outfits, k)
                                         break
                                     end
                                 end
                             end
                             if Wardrobe then Wardrobe:RefreshOutfitsGrid() end
                        end
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                }
                StaticPopup_Show("DC_CONFIRM_DELETE_OUTFIT", outfit.name or "Outfit")
            end,
        },
        { text = (DC.L and DC.L["CANCEL"]) or "Cancel", notCheckable = true },
    }

    local dropdown = CreateFrame("Frame", "DCWardrobeOutfitContextMenu", UIParent, "UIDropDownMenuTemplate")
    EasyMenu(menu, dropdown, anchor or "cursor", 0, 0, "MENU")
end

function Wardrobe:LoadOutfit(outfit)
    if not outfit then return end

    local slots = outfit.slots or outfit.items
    if type(slots) == "string" then
        local parsed = {}
        for k, v in slots:gmatch('"?([^":,{}]+)"?%s*:%s*(%d+)') do
            parsed[k] = tonumber(v)
        end
        slots = parsed
    end

    if type(slots) ~= "table" then
        return
    end

    for slotKey, appearanceId in pairs(slots) do
        local invSlotId = GetInventorySlotInfo(slotKey)

        -- Only apply if the player has an item equipped in that slot.
        if invSlotId and GetInventoryItemID("player", invSlotId) then
            -- Server expects 0-based equipment slot index + appearanceId (displayId).
            if DC and DC.RequestSetTransmogByEquipmentSlot then
                DC:RequestSetTransmogByEquipmentSlot(invSlotId - 1, tonumber(appearanceId) or appearanceId)
            elseif DC and DC.RequestSetTransmog then
                -- Fallback: RequestSetTransmog expects 1-based inventory slot.
                DC:RequestSetTransmog(invSlotId, tonumber(appearanceId) or appearanceId)
            end
        end
    end

    if DC and DC.Print then
        DC:Print("Outfit '" .. (outfit.name or "") .. "' applied!")
    end
end

function Wardrobe:RandomizeOutfit()
    if not self.BuildAppearanceList then return end

    -- Robust pseudo-random seed with high entropy
    local seed = 1
    if type(time) == "function" then
        seed = seed + ((time() or 0) * 1000)
    end
    if type(GetTime) == "function" then
        seed = seed + math.floor((GetTime() or 0) * 10000) -- Higher precision
    end
    -- Add sub-millisecond precision if available
    if type(debugprofilestop) == "function" then
        seed = seed + math.floor((debugprofilestop() or 0))
    end
    -- Add player position for extra entropy
    local px, py = GetPlayerMapPosition("player")
    if px and py then
        seed = seed + math.floor((px * 100000) + (py * 10000))
    end
    -- Counter to ensure different results on rapid clicks
    self._randomizeCounter = (self._randomizeCounter or 0) + 1
    seed = seed + (self._randomizeCounter * 7919)  -- Use a prime number
    
    -- Cache current tab/slot to restore later
    local originalTab = self.currentTab
    local originalSlot = self.selectedSlot
    local originalFilter = self.selectedSlotFilter
    local originalQuality = self.selectedQualityFilter
    
    if DC and DC.Print then DC:Print("Randomizing outfit...") end

    local collectedBySlot = {}
    
    -- Iterate all slots to find collected items
    -- We use Wardrobe:BuildAppearanceList() if available
    
    if DC and DC.Print then DC:Print("[RANDOMIZE] Starting to collect appearances by slot...") end
    
    -- Use cached collected list if available to improve performance
    self.collectedCache = self.collectedCache or {}
    
    if DC and DC.Print then DC:Print("[RANDOMIZE] Starting to collect appearances by slot...") end
    
    for _, slotDef in ipairs(self.SLOT_FILTERS or {}) do
        local collected = nil
        
        -- Check cache first
        if self.collectedCache[slotDef.label] then
            collected = self.collectedCache[slotDef.label]
        else
            -- Mock selection to build list
            self.selectedSlotFilter = slotDef
            local list = self:BuildAppearanceList()
            
            -- Filter only collected items
            collected = {}
            for _, item in ipairs(list) do
                if item.collected then
                    -- Prefer displayId (server expects appearanceId), but fall back to itemId if unavailable
                    local appearanceId = item.displayId or item.appearanceId or item.appearance_id
                    if type(appearanceId) == "string" then
                        appearanceId = tonumber(appearanceId)
                    end
                    
                    -- Fallback: if no displayId, use itemId
                    if not appearanceId or appearanceId == 0 then
                        appearanceId = item.itemId
                    end
                    
                    if appearanceId then
                        table.insert(collected, appearanceId)
                    end
                end
            end
            
            -- Cache result
            self.collectedCache[slotDef.label] = collected
        end
        
        collectedBySlot[slotDef.label] = collected
    end
    
    if DC and DC.Print then DC:Print("[RANDOMIZE] Finished collecting (cached). Summary:") end
    for slotLabel, ids in pairs(collectedBySlot) do
        -- if DC and DC.Print then
        --    DC:Print("[RANDOMIZE]   " .. slotLabel .. ": " .. #ids .. " appearances")
        -- end
    end
    
    -- Restore state
    self.selectedSlotFilter = originalFilter
    self.selectedQualityFilter = originalQuality
    self.currentTab = originalTab
    self.selectedSlot = originalSlot
    
    local function BuildPicks(localSeed)
        local picks = {}
        local appliedCount = 0

        for _, slotDef in ipairs(self.EQUIPMENT_SLOTS or {}) do
            local invSlotId = GetInventorySlotInfo(slotDef.key)
            if invSlotId then
                local slotCandidates = {}
                local seen = {}

                for _, filter in ipairs(self.SLOT_FILTERS or {}) do
                    if filter.invTypes and filter.invTypes[slotDef.invType] then
                        local items = collectedBySlot[filter.label]
                        if items then
                            for _, id in ipairs(items) do
                                local n = tonumber(id)
                                if n and not seen[n] then
                                    seen[n] = true
                                    slotCandidates[#slotCandidates + 1] = n
                                end
                            end
                        end
                    end
                end

                if #slotCandidates > 0 then
                    local idx
                    localSeed, idx = ChooseIndex(localSeed, #slotCandidates)
                    local pick = idx and slotCandidates[idx]
                    if pick then
                        picks[slotDef.key] = { inv = invSlotId, id = pick }
                        appliedCount = appliedCount + 1
                    end
                end
            end
        end

        return localSeed, picks, appliedCount
    end

    local function PicksSignature(picks)
        local parts = {}
        for _, slotDef in ipairs(self.EQUIPMENT_SLOTS or {}) do
            local p = picks[slotDef.key]
            parts[#parts + 1] = slotDef.key .. ":" .. tostring(p and p.id or 0)
        end
        return table.concat(parts, "|")
    end

    local appliedCount = 0
    local picks

    for _ = 1, 5 do
        seed, picks, appliedCount = BuildPicks(seed)
        local sig = PicksSignature(picks)
        if sig ~= (self._lastRandomOutfitSig or "") then
            self._lastRandomOutfitSig = sig
            break
        end
        seed = NextLCG(seed)
    end

    if DC and DC.Print then 
        DC:Print("[RANDOMIZE] Applying picks to character...")
        local pickCount = 0
        if picks then for _ in pairs(picks) do pickCount = pickCount + 1 end end
        DC:Print("[RANDOMIZE] Total picks generated: " .. pickCount)
    end
    
    local actualApplied = 0
    for _, slotDef in ipairs(self.EQUIPMENT_SLOTS or {}) do
        local p = picks and picks[slotDef.key]
        if p then

            if DC and (DC.RequestSetTransmogByEquipmentSlot or DC.RequestSetTransmog) then
                if DC.RequestSetTransmogByEquipmentSlot then
                    DC:RequestSetTransmogByEquipmentSlot((p.inv or 0) - 1, p.id)
                else
                    DC:RequestSetTransmog(p.inv, p.id)
                end
                actualApplied = actualApplied + 1
            end
        else
            if DC and DC.Print then
                DC:Print("[RANDOMIZE] Slot " .. slotDef.key .. ": no pick available")
            end
        end
    end

    if type(self.MarkUnsavedChanges) == "function" and actualApplied > 0 then
        self:MarkUnsavedChanges()
    end

    if DC and DC.Print then 
        DC:Print("[RANDOMIZE] Random outfit applied to " .. actualApplied .. " slots!")
        if actualApplied == 0 then
            DC:Print("[RANDOMIZE] ERROR: No slots were randomized! Check collected appearances above.")
        end
    end
end

function Wardrobe:RefreshOutfitsGrid()
    local buttons = self.frame and self.frame.outfitButtons
    if not buttons and _G["DCCollectionWardrobeFrame"] then
        buttons = _G["DCCollectionWardrobeFrame"].outfitButtons
    end
    
    if not buttons then return end

    local outfits = DC.db and DC.db.outfits or {}
    local outfits = DC.db and DC.db.outfits or {}
    local ITEMS_PER_PAGE = 6 -- 3x2 grid
    
    local totalOutfits = #outfits
    self.currentPage = self.currentPage or 1
    self.totalPages = math.max(1, math.ceil(totalOutfits / ITEMS_PER_PAGE))
    
    if DC and DC.Print then
        -- DC:Print("Debug: Refreshing outfits grid. Total outfits: " .. totalOutfits)
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
                 if type(outfit.slots) == "table" then
                     for _, itemId in pairs(outfit.slots) do
                         local itemLink = "item:" .. itemId .. ":0:0:0:0:0:0:0"
                         btn.model:TryOn(itemLink)
                     end
                 elseif type(outfit.slots) == "string" then
                     -- Parse JSON string for display
                     for slot, val in outfit.slots:gmatch('"?([^":,{}]+)"?%s*:%s*(%d+)') do
                         local itemLink = "item:" .. val .. ":0:0:0:0:0:0:0"
                         btn.model:TryOn(itemLink)
                     end
                 end
            end
            
            -- Hook Interaction
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            btn:SetScript("OnClick", function(selfBtn, button)
                if IsModifiedClick("CHATLINK") then
                    local link = "[Outfit: " .. (selfBtn.outfit.name or "Link") .. "]" -- Simplified link for now
                    if ChatEdit_InsertLink then
                         ChatEdit_InsertLink(link)
                    end
                    return
                end

                if button == "RightButton" then
                    Wardrobe:ShowOutfitContextMenu(selfBtn.outfit, selfBtn)
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
        if type(self.frame.prevBtn.SetEnabled) == "function" then
            self.frame.prevBtn:SetEnabled(self.currentPage > 1)
        elseif self.currentPage > 1 then
            if type(self.frame.prevBtn.Enable) == "function" then
                self.frame.prevBtn:Enable()
            end
        else
            if type(self.frame.prevBtn.Disable) == "function" then
                self.frame.prevBtn:Disable()
            end
        end
    end
    if self.frame.nextBtn then
        if type(self.frame.nextBtn.SetEnabled) == "function" then
            self.frame.nextBtn:SetEnabled(self.currentPage < self.totalPages)
        elseif self.currentPage < self.totalPages then
            if type(self.frame.nextBtn.Enable) == "function" then
                self.frame.nextBtn:Enable()
            end
        else
            if type(self.frame.nextBtn.Disable) == "function" then
                self.frame.nextBtn:Disable()
            end
        end
    end
end
