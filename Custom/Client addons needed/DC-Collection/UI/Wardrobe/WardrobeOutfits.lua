--[[
    DC-Collection UI/Wardrobe/WardrobeOutfits.lua
    ============================================

    Outfits tab: custom 3x2 grid with large previews.
]]

local DC = DCCollection
if not DC then return end

DC.Wardrobe = DC.Wardrobe or {}
local Wardrobe = DC.Wardrobe

Wardrobe.SerializeSlotsToJsonString = Wardrobe.SerializeSlotsToJsonString or function(slots)
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

function Wardrobe:InvalidateRandomizerCache()
    self.collectedCache = nil
    self._lastRandomOutfitSig = nil
end

function Wardrobe:_EnsurePendingApplyVerifier()
    if self._pendingApplyVerifierFrame then
        return
    end

    local f = CreateFrame("Frame")
    f:Hide()
    f.elapsed = 0
    f:SetScript("OnUpdate", function(frame, dt)
        frame.elapsed = (frame.elapsed or 0) + (dt or 0)
        if frame.elapsed < 0.05 then
            return
        end
        frame.elapsed = 0

        local pending = Wardrobe._pendingApplyOutfit
        if not pending then
            frame:Hide()
            return
        end

        local now = (GetTime and GetTime()) or 0
        local last = pending.lastUpdateAt or pending.startedAt or now
        if now - last < 0.35 then
            return
        end

        frame:Hide()
        Wardrobe:_VerifyPendingOutfitApply()
    end)

    self._pendingApplyVerifierFrame = f
end

function Wardrobe:OnTransmogStateReceived(state)
    if not self._pendingApplyOutfit then
        return
    end

    local now = (GetTime and GetTime()) or 0
    self._pendingApplyOutfit.lastUpdateAt = now
    self:_EnsurePendingApplyVerifier()
    if self._pendingApplyVerifierFrame then
        self._pendingApplyVerifierFrame:Show()
    end
end

function Wardrobe:_VerifyPendingOutfitApply()
    local pending = self._pendingApplyOutfit
    if not pending then
        return
    end

    self._pendingApplyOutfit = nil

    local state = (DC and DC.transmogState) or {}
    local failed = {}
    local total = 0

    for equipmentSlot, expectedVal in pairs(pending.expectedByEquipSlot or {}) do
        total = total + 1
        local key = tostring(equipmentSlot)
        local actual = tonumber(state[key]) or 0
        local expected = tonumber(expectedVal) or 0

        local ok
        if expected <= 0 then
            ok = (actual <= 0)
        else
            ok = (actual == expected)
        end

        if not ok then
            local label = (pending.slotLabelByEquipSlot and pending.slotLabelByEquipSlot[equipmentSlot]) or ("slot " .. key)
            failed[#failed + 1] = label
        end
    end

    if DC and DC.Print then
        if total == 0 then
            DC:Print("Outfit applied.")
        elseif #failed == 0 then
            DC:Print("Outfit '" .. (pending.name or "") .. "' applied (verified).")
        else
            table.sort(failed)
            DC:Print("Outfit apply incomplete. Failed slots: " .. table.concat(failed, ", ") .. ".")
            if DCCollectionDB and DCCollectionDB.debugMode and DC.Debug then
                DC:Debug("[OUTFIT APPLY] Some slots were rejected (likely not unlocked, incompatible with equipped gear, or slot empty).")
            end
        end
    end
end

function Wardrobe:_EnsureOutfitPreviewQueue()
    if self._outfitPreviewQueueFrame then
        return
    end

    self._outfitPreviewQueue = self._outfitPreviewQueue or {}

    local f = CreateFrame("Frame")
    f:Hide()
    f.elapsed = 0
    f:SetScript("OnUpdate", function(frame, dt)
        frame.elapsed = (frame.elapsed or 0) + (dt or 0)
        if frame.elapsed < 0.03 then
            return
        end
        frame.elapsed = 0

        local q = Wardrobe._outfitPreviewQueue
        if not q or #q == 0 then
            frame:Hide()
            return
        end

        local job = table.remove(q, 1)
        local btn = job and job.btn
        local outfit = job and job.outfit
        if not (btn and btn.model and outfit) then
            return
        end

        -- If the button has since been re-used for another outfit, skip.
        if btn._outfitPreviewSig ~= job.sig then
            return
        end

        local model = btn.model

        -- Fix order: SetUnit first, then undress, then TryOn.
        model:SetUnit("player")
        model:SetFacing(0)
        if model.Undress then
            model:Undress()
        end

        -- Best-effort: TryOn only items that are already cached.
        local slots = outfit.slots or outfit.items
        if type(slots) == "string" then
            for _, val in slots:gmatch('"?[^":,{}]+"?%s*:%s*(%d+)') do
                local n = tonumber(val)
                if n and n > 0 and (not GetItemInfo or GetItemInfo(n)) then
                    pcall(function()
                        model:TryOn("item:" .. n .. ":0:0:0:0:0:0:0")
                    end)
                end
            end
        elseif type(slots) == "table" then
            for _, val in pairs(slots) do
                local n = tonumber(val)
                if n and n > 0 and (not GetItemInfo or GetItemInfo(n)) then
                    pcall(function()
                        model:TryOn("item:" .. n .. ":0:0:0:0:0:0:0")
                    end)
                end
            end
        end
    end)

    self._outfitPreviewQueueFrame = f
end

function Wardrobe:_QueueOutfitPreview(btn, outfit)
    if not (btn and btn.model and outfit) then
        return
    end

    self:_EnsureOutfitPreviewQueue()

    -- Signature: if unchanged, don't rebuild the model.
    local slots = outfit.slots or outfit.items
    local sig = tostring(outfit.id or "") .. ":" .. tostring(type(slots)) .. ":" .. tostring(slots)
    if btn._outfitPreviewSig == sig then
        return
    end
    btn._outfitPreviewSig = sig

    self._outfitPreviewQueue = self._outfitPreviewQueue or {}
    table.insert(self._outfitPreviewQueue, { btn = btn, outfit = outfit, sig = sig })
    if self._outfitPreviewQueueFrame then
        self._outfitPreviewQueueFrame:Show()
    end
end

local function GetCurrentOutfitSlots()
    local slots = {}
    if not Wardrobe or type(Wardrobe.EQUIPMENT_SLOTS) ~= "table" then
        return slots
    end

    for _, slotDef in ipairs(Wardrobe.EQUIPMENT_SLOTS) do
        local invSlotId = GetInventorySlotInfo(slotDef.key)
        if invSlotId then
            local itemId = GetInventoryItemID("player", invSlotId)
            if itemId then
                local transmogId = DC and DC.transmogState and DC.transmogState[tostring(invSlotId - 1)]
                local tid = tonumber(transmogId) or 0
                if tid < 0 then tid = 0 end
                slots[slotDef.key] = tid
            end
        end
    end

    return slots
end

local function IsSameSlots(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end

    local countA = 0
    for k, v in pairs(a) do
        local av = tonumber(v) or 0
        if av > 0 then
            countA = countA + 1
            if (tonumber(b[k]) or 0) ~= av then
                return false
            end
        end
    end

    local countB = 0
    for k, v in pairs(b) do
        local bv = tonumber(v) or 0
        if bv > 0 then
            countB = countB + 1
        end
    end

    return countA == countB
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
        hasCheckButton = true,
        checkButtonText = "Update selected outfit",
        maxLetters = 32,
        OnShow = function(selfPopup)
            local selected = Wardrobe and Wardrobe.selectedOutfit
            local canUpdate = selected and selected.id and tonumber(selected.id) and tonumber(selected.id) > 0

            if selfPopup.checkButton then
                if canUpdate then
                    selfPopup.checkButton:Show()
                    selfPopup.checkButton:SetChecked(true)
                else
                    selfPopup.checkButton:Hide()
                    selfPopup.checkButton:SetChecked(false)
                end
            end

            if selfPopup.editBox and canUpdate then
                selfPopup.editBox:SetText(selected.name or "")
                if selfPopup.editBox.HighlightText then
                    selfPopup.editBox:HighlightText()
                end
            end
        end,
        OnAccept = function(selfPopup)
            local name = selfPopup.editBox:GetText()
            if name and name ~= "" then
                local selected = Wardrobe and Wardrobe.selectedOutfit
                local canUpdate = selected and selected.id and tonumber(selected.id) and tonumber(selected.id) > 0
                local wantsUpdate = selfPopup.checkButton and selfPopup.checkButton:IsShown() and selfPopup.checkButton:GetChecked()

                if canUpdate and wantsUpdate then
                    Wardrobe:SaveCurrentOutfit(name, tonumber(selected.id))
                else
                    Wardrobe:SaveCurrentOutfit(name)
                end
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

function Wardrobe:SaveCurrentOutfit(name, overwriteId)
    -- Ensure we have authoritative transmog state (displayIds) before saving.
    if not (DC and DC.transmogState) then
        self._pendingSaveOutfitName = name
        if DC and type(DC.RequestTransmogState) == "function" then
            DC:RequestTransmogState()
        end
        if DC and DC.Print then
            DC:Print("Loading transmog state, retrying save...")
        end
        return
    end

    if not DC.db then DC.db = {} end
    if not DC.db.outfits then DC.db.outfits = {} end

    local id = tonumber(overwriteId) or 0
    
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
                -- Store displayId from transmog state (server expects displayId).
                -- If no transmog is applied, store 0 so LoadOutfit can clear.
                local transmogId = DC.transmogState and DC.transmogState[tostring(invSlotId - 1)]
                local tid = tonumber(transmogId) or 0
                if tid < 0 then tid = 0 end
                outfit.slots[slotDef.key] = tid
                
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

    -- Duplicate Check (skip when overwriting)
    if id == 0 and DC.db.outfits then
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
        -- Also update locally for instant feedback (will be overwritten by sync)
        if id == 0 then
            table.insert(DC.db.outfits, outfit)
            DC:Print("Outfit '" .. name .. "' saved to server!")
        else
            local replaced
            for i = 1, #DC.db.outfits do
                if tonumber(DC.db.outfits[i] and DC.db.outfits[i].id) == id then
                    DC.db.outfits[i] = outfit
                    replaced = true
                    break
                end
            end
            if not replaced then
                table.insert(DC.db.outfits, outfit)
            end
            DC:Print("Outfit '" .. name .. "' updated on server!")
        end

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
        itemsString = Wardrobe.SerializeSlotsToJsonString(slots)
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

    local dbg = (DCCollectionDB and DCCollectionDB.debugMode) and true or false
    local dbgLines
    local dbgCount = 0

    local batchEntries
    local canBatch = DC and type(DC.ApplyTransmogBatchByEquipmentSlot) == "function"
    if canBatch then
        batchEntries = {}
    end

    self._pendingApplyOutfit = {
        name = outfit.name or "",
        expectedByEquipSlot = {},
        slotLabelByEquipSlot = {},
        startedAt = (GetTime and GetTime()) or 0,
        lastUpdateAt = (GetTime and GetTime()) or 0,
    }

    for slotKey, appearanceId in pairs(slots) do
        local invSlotId

        -- Support both string keys ("HeadSlot") and numeric keys (0-based equipment slot or 1-based inventory slot).
        if type(slotKey) == "number" or (type(slotKey) == "string" and tonumber(slotKey)) then
            local slotNum = tonumber(slotKey)
            if slotNum == 0 then
                invSlotId = 1
            elseif slotNum and slotNum > 0 and slotNum <= 19 then
                -- Treat as 1-based inventory slot.
                invSlotId = slotNum
            elseif slotNum and slotNum >= 0 and slotNum <= 18 then
                -- Fallback: treat as 0-based equipment slot.
                invSlotId = slotNum + 1
            end
        else
            invSlotId = GetInventorySlotInfo(slotKey)
        end

        -- Only apply if the player has an item equipped in that slot.
        if invSlotId and GetInventoryItemID("player", invSlotId) then
            local equipmentSlot = invSlotId - 1

            local n = tonumber(appearanceId) or 0

            -- Some payloads store itemIds instead of displayIds.
            local mapped
            if n and n > 0 and Wardrobe and type(Wardrobe.GetAppearanceDisplayIdForItemId) == "function" then
                mapped = Wardrobe:GetAppearanceDisplayIdForItemId(n)
                if mapped and mapped > 0 then
                    n = mapped
                end
            end

            if dbg and dbgCount < 6 then
                dbgLines = dbgLines or {}
                dbgCount = dbgCount + 1
                dbgLines[#dbgLines + 1] = string.format("slot=%s inv=%d equip=%d raw=%s mapped=%s send=%d", tostring(slotKey), tonumber(invSlotId) or 0, tonumber(equipmentSlot) or 0, tostring(appearanceId), tostring(mapped), tonumber(n) or 0)
            end

            if canBatch then
                if n and n <= 0 then
                    table.insert(batchEntries, { slot = equipmentSlot, clear = true })
                else
                    table.insert(batchEntries, { slot = equipmentSlot, appearanceId = n, clear = false })
                end
            else
                -- Fallback: per-slot apply (older servers)
                if DC and DC.RequestSetTransmogByEquipmentSlot then
                    if n and n <= 0 then
                        if DC.RequestClearTransmogByEquipmentSlot then
                            DC:RequestClearTransmogByEquipmentSlot(equipmentSlot)
                        end
                    else
                        DC:RequestSetTransmogByEquipmentSlot(equipmentSlot, n)
                    end
                elseif DC and DC.RequestSetTransmog then
                    if n and n <= 0 then
                        if DC.RequestClearTransmog then
                            DC:RequestClearTransmog(invSlotId)
                        end
                    else
                        DC:RequestSetTransmog(invSlotId, n)
                    end
                end
            end

            self._pendingApplyOutfit.expectedByEquipSlot[equipmentSlot] = tonumber(n) or 0
            self._pendingApplyOutfit.slotLabelByEquipSlot[equipmentSlot] = tostring(slotKey)
        end
    end

    if canBatch and batchEntries and #batchEntries > 0 then
        DC:ApplyTransmogBatchByEquipmentSlot(batchEntries)
    end

    -- Force-refresh transmog state so UI + preview can update from authoritative server state.
    if DC and type(DC.RequestTransmogState) == "function" then
        DC:RequestTransmogState()
    end

    if dbg and dbgLines and DC and type(DC.Debug) == "function" then
        for _, line in ipairs(dbgLines) do
            DC:Debug("[OUTFIT APPLY] " .. line)
        end
    end

    if DC and DC.Print then
        DC:Print("Applying outfit '" .. (outfit.name or "") .. "'...")
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
                    -- Only use displayId (server expects appearanceId=displayId).
                    local appearanceId = tonumber(item.displayId)
                    if appearanceId and appearanceId > 0 then
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
    local actualCleared = 0

    -- Clear relevant slots first so randomizer truly *replaces* existing transmogs.
    for _, slotDef in ipairs(self.EQUIPMENT_SLOTS or {}) do
        local invSlotId = slotDef and slotDef.slotName and GetInventorySlotInfo(slotDef.slotName)
        if invSlotId and GetInventoryItemID("player", invSlotId) then
            local equipSlot = invSlotId - 1
            if DC and type(DC.RequestClearTransmogByEquipmentSlot) == "function" then
                DC:RequestClearTransmogByEquipmentSlot(equipSlot)
                actualCleared = actualCleared + 1
            end
        end
    end

    for _, slotDef in ipairs(self.EQUIPMENT_SLOTS or {}) do
        local p = picks and picks[slotDef.key]
        if p then
            -- Only apply if an item is equipped in that slot.
            if p.inv and GetInventoryItemID("player", p.inv) then
                local equipSlot = (p.inv or 0) - 1
                -- Use the correct Protocol function
                if DC.Protocol and type(DC.Protocol.RequestSetTransmogByEquipmentSlot) == "function" then
                    DC.Protocol:RequestSetTransmogByEquipmentSlot(equipSlot, p.id)
                    actualApplied = actualApplied + 1
                elseif DC and type(DC.RequestSetTransmogByEquipmentSlot) == "function" then
                    DC:RequestSetTransmogByEquipmentSlot(equipSlot, p.id)
                    actualApplied = actualApplied + 1
                end
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
        DC:Print("[RANDOMIZE] Cleared " .. actualCleared .. " slots; applied " .. actualApplied .. " randomized picks")
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

    if not buttons then
        -- Data can arrive before the Outfits tab finishes building its grid.
        -- Mark as pending and retry a few times on the next frames.
        self._pendingOutfitsRefresh = true

        if not self._outfitsRefreshRetryFrame then
            local f = CreateFrame("Frame")
            f.elapsed = 0
            f.tries = 0
            f:SetScript("OnUpdate", function(this, elapsed)
                this.elapsed = (this.elapsed or 0) + (elapsed or 0)
                if this.elapsed < 0.05 then return end
                this.elapsed = 0
                this.tries = (this.tries or 0) + 1

                -- Stop after a short while to avoid running forever.
                if this.tries > 40 then
                    this:SetScript("OnUpdate", nil)
                    Wardrobe._outfitsRefreshRetryFrame = nil
                    return
                end

                if Wardrobe and Wardrobe._pendingOutfitsRefresh and type(Wardrobe.RefreshOutfitsGrid) == "function" then
                    -- If the grid is now ready, this call will clear pending below.
                    Wardrobe:RefreshOutfitsGrid()
                end
            end)
            self._outfitsRefreshRetryFrame = f
        end

        return
    end

    -- Grid is ready; stop any pending retry.
    self._pendingOutfitsRefresh = nil
    if self._outfitsRefreshRetryFrame then
        self._outfitsRefreshRetryFrame:SetScript("OnUpdate", nil)
        self._outfitsRefreshRetryFrame = nil
    end

    local outfits = DC.db and DC.db.outfits or {}
    local ITEMS_PER_PAGE = 6 -- 3x2 grid

    self.currentPage = self.currentPage or 1
    local wantOffset = (self.currentPage - 1) * ITEMS_PER_PAGE

    -- Ensure the dedicated outfits pager is visible only on this tab.
    if self.frame and self.frame.outfitsPageFrame then
        self.frame.outfitsPageFrame:Show()
    end

    -- Loading label to avoid showing placeholder tiles while waiting for server.
    if self.frame and self.frame.outfitGridContainer and not self.frame.outfitsLoadingText then
        local t = self.frame.outfitGridContainer:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
        t:SetPoint("CENTER", 0, 0)
        t:SetText("Loading outfits...")
        t:Hide()
        self.frame.outfitsLoadingText = t
    end

    -- If server paging is supported, ensure we have the correct page loaded.
    if DC.Protocol and DC.Protocol.RequestSavedOutfitsPage then
        DC.db = DC.db or {}
        DC.db.outfitsPages = DC.db.outfitsPages or {}

        local cachedPage = DC.db.outfitsPages[wantOffset]
        if cachedPage then
            outfits = cachedPage
            DC.db.outfits = cachedPage
            DC.db.outfitsOffset = wantOffset
            DC.db.outfitsLimit = ITEMS_PER_PAGE
        elseif (not DC.db or DC.db.outfitsOffset ~= wantOffset) then
            -- Hide tiles until the server responds, so we don't show placeholder names.
            for _, b in ipairs(buttons) do b:Hide() end
            if self.frame and self.frame.outfitsLoadingText then
                self.frame.outfitsLoadingText:Show()
            end
            DC.Protocol:RequestSavedOutfitsPage(wantOffset, ITEMS_PER_PAGE)
            return
        end
    end

    if self.frame and self.frame.outfitsLoadingText then
        self.frame.outfitsLoadingText:Hide()
    end

    local totalOutfits = (DC.db and tonumber(DC.db.outfitsTotal)) or #outfits
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

    if self.frame.outfitsPageText then
        self.frame.outfitsPageText:SetText(string.format("Page %d / %d", self.currentPage, self.totalPages))
    end

    if self.frame.outfitsPrevBtn and type(self.frame.outfitsPrevBtn.SetEnabled) == "function" then
        self.frame.outfitsPrevBtn:SetEnabled(self.currentPage > 1)
    elseif self.frame.outfitsPrevBtn then
        if self.currentPage > 1 and type(self.frame.outfitsPrevBtn.Enable) == "function" then
            self.frame.outfitsPrevBtn:Enable()
        elseif type(self.frame.outfitsPrevBtn.Disable) == "function" then
            self.frame.outfitsPrevBtn:Disable()
        end
    end
    if self.frame.outfitsNextBtn and type(self.frame.outfitsNextBtn.SetEnabled) == "function" then
        self.frame.outfitsNextBtn:SetEnabled(self.currentPage < self.totalPages)
    elseif self.frame.outfitsNextBtn then
        if self.currentPage < self.totalPages and type(self.frame.outfitsNextBtn.Enable) == "function" then
            self.frame.outfitsNextBtn:Enable()
        elseif type(self.frame.outfitsNextBtn.Disable) == "function" then
            self.frame.outfitsNextBtn:Disable()
        end
    end

    if self.currentPage > self.totalPages then self.currentPage = self.totalPages end
    
    -- Determine equipped outfit; for page 1 we try to pin it even if it lives on another page.
    local equippedIndex
    local equippedSlots = GetCurrentOutfitSlots()
    local equippedSig = Wardrobe.SerializeSlotsToJsonString(equippedSlots)

    local pinnedOutfit
    if wantOffset == 0 and DC.db and DC.db.outfitsBySignature and equippedSig then
        pinnedOutfit = DC.db.outfitsBySignature[equippedSig]
    end

    -- If pinning on page 1, show pinned outfit as tile 1 and fill remaining tiles from page 0.
    if wantOffset == 0 and pinnedOutfit then
        local merged = { pinnedOutfit }
        for _, o in ipairs(outfits) do
            if #merged >= ITEMS_PER_PAGE then break end
            if not (o and pinnedOutfit and o.id == pinnedOutfit.id) then
                table.insert(merged, o)
            end
        end
        outfits = merged
        DC.db.outfits = merged
        DC.db.outfitsOffset = 0
        equippedIndex = 1
    else
        -- Old behavior: pin within current page only.
        for i, o in ipairs(outfits) do
            local s = o and (o.slots or o.items)
            if type(s) == "string" then
                local parsed = {}
                for k, v in s:gmatch('"?([^":,{}]+)"?%s*:%s*(%d+)') do
                    parsed[k] = tonumber(v)
                end
                s = parsed
            end
            if type(s) == "table" and IsSameSlots(equippedSlots, s) then
                equippedIndex = i
                break
            end
        end

        if equippedIndex and equippedIndex > 1 then
            local eq = table.remove(outfits, equippedIndex)
            table.insert(outfits, 1, eq)
            equippedIndex = 1
        end
    end

    local startIdx = 0
    
    for i, btn in ipairs(buttons) do
        local idx = startIdx + i
        local outfit = outfits[idx]
        
        if outfit then
            btn:Show()
            btn.outfit = outfit

            local baseName = outfit.name
            if not baseName or baseName == "" or baseName == "Outfit Name" then
                baseName = "Outfit " .. (outfit.id or idx)
            end

            local isEquipped = (equippedIndex == idx)
            if isEquipped then
                btn.name:SetText(baseName .. " (Equipped)")
                btn.highlight:SetAlpha(0.55)
            else
                btn.name:SetText(baseName)
                btn.highlight:SetAlpha(0.3)
            end
            
            -- Setup Model Preview (throttled to avoid hitching on tab open)
            btn.model:Show()
            self:_QueueOutfitPreview(btn, outfit)
            
            -- Hook Interaction
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            btn:SetScript("OnClick", function(selfBtn, button)
                if IsModifiedClick("CHATLINK") then
                    local link

                    if DC and type(DC.GenerateOutfitLink) == "function" and selfBtn.outfit then
                        local rawSlots = selfBtn.outfit.slots or selfBtn.outfit.items
                        local slots = rawSlots

                        if type(slots) == "string" then
                            local parsed = {}
                            for k, v in slots:gmatch('"?([^":,{}]+)"?%s*:%s*(%d+)') do
                                parsed[k] = tonumber(v)
                            end
                            slots = parsed
                        end

                        if type(slots) == "table" then
                            local state = {}
                            for slotKey, appearanceId in pairs(slots) do
                                local invSlotId
                                if type(slotKey) == "number" or (type(slotKey) == "string" and tonumber(slotKey)) then
                                    local slotNum = tonumber(slotKey)
                                    if slotNum == 0 then
                                        invSlotId = 1
                                    elseif slotNum and slotNum > 0 and slotNum <= 19 then
                                        invSlotId = slotNum
                                    elseif slotNum and slotNum >= 0 and slotNum <= 18 then
                                        invSlotId = slotNum + 1
                                    end
                                else
                                    invSlotId = GetInventorySlotInfo(slotKey)
                                end

                                local n = tonumber(appearanceId) or 0
                                if invSlotId and n and n > 0 then
                                    state[tostring(invSlotId)] = n
                                end
                            end

                            link = DC:GenerateOutfitLink(selfBtn.outfit.name or "Outfit", { state = state })
                        end
                    end

                    link = link or ("[Outfit: " .. (selfBtn.outfit and selfBtn.outfit.name or "Link") .. "]")
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
                Wardrobe.selectedOutfit = selfBtn.outfit
                Wardrobe:LoadOutfit(selfBtn.outfit)
            end)
            
            btn:SetScript("OnEnter", function(selfBtn)
                 GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                 local n = selfBtn.outfit and selfBtn.outfit.name
                 if not n or n == "" or n == "Outfit Name" then
                     n = "Outfit " .. tostring(selfBtn.outfit and (selfBtn.outfit.id or "") or "")
                 end
                 GameTooltip:SetText(n)
                 if isEquipped then
                     GameTooltip:AddLine("Currently equipped", 1, 0.82, 0)
                 end
                 GameTooltip:AddLine("Click to Apply", 0, 1, 0)
                 GameTooltip:AddLine("Shift+Click to Link", 1, 1, 1)
                 GameTooltip:Show()
            end)
            
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
        else
            btn:Hide()
        end
    end
end
