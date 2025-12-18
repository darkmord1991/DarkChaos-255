-- DC-Welcome: NPC tooltip extension (Entry + Spawn ID)
-- Adds two lines to unit tooltips for creatures/vehicles.

local DC = _G.DCAddonProtocol
local npcInfoCache = {}
local pendingRequests = {}
local UpdateTargetInfo -- Forward declaration

function DCWelcome.GetNPCInfo(guid)
    -- Re-check global if nil (in case of load order issues)
    if not DC then DC = _G.DCAddonProtocol end
    
    if not DC then 
        -- print("DCWelcome: DC lib missing")
        return 
    end
    if pendingRequests[guid] then return end
    if npcInfoCache[guid] then return end
    
    pendingRequests[guid] = true
    
    -- Send request
    if DCWelcome.Module and DCWelcome.Opcode and DCWelcome.Opcode.CMSG_GET_NPC_INFO then
        -- print("DCWelcome: Requesting info for " .. guid)
        if DC.Request then
            DC:Request(DCWelcome.Module, DCWelcome.Opcode.CMSG_GET_NPC_INFO, { guid = guid })
        else
            DC:Send(DCWelcome.Module, DCWelcome.Opcode.CMSG_GET_NPC_INFO, { guid = guid })
        end
    else
        -- print("DCWelcome: Module/Opcode missing")
    end
end

function DCWelcome.OnNPCInfoReceived(data)
    local guid = data.guid
    if not guid then return end
    
    -- Normalize GUID to match UnitGUID format (0x prefix)
    -- The server strips the 0x prefix, so we must add it back to match the cache key.
    if string.sub(guid, 1, 2) ~= "0x" then
        guid = "0x" .. guid
    end
    
    -- print("DCWelcome: Received info for " .. guid .. " SpawnID: " .. tostring(data.spawnId))

    pendingRequests[guid] = nil
    npcInfoCache[guid] = {
        spawnId = data.spawnId,
        entry = data.entry
    }
    
    -- Refresh tooltip if it's showing this unit
    if GameTooltip:IsShown() then
        local _, unit = GameTooltip:GetUnit()
        if unit then
            local currentGuid = UnitGUID(unit)
            -- Case-insensitive comparison just in case
            if currentGuid and string.lower(currentGuid) == string.lower(guid) then
                local dbGuid = data.spawnId
                if dbGuid then
                    local rightText = tostring(dbGuid)
                    -- Hex removed as requested
                    
                    -- Try to find existing "Fetching..." line to update
                    local updated = false
                    local numLines = GameTooltip:NumLines()
                    for i = 1, numLines do
                        local left = _G["GameTooltipTextLeft"..i]
                        local right = _G["GameTooltipTextRight"..i]
                        if left and left:GetText() == "DB GUID:" then
                            right:SetText(rightText)
                            right:SetTextColor(1, 1, 1) -- Reset color to white
                            updated = true
                            break
                        end
                    end
                    
                    if not updated then
                        GameTooltip:AddDoubleLine("DB GUID:", rightText, 0.7, 0.7, 0.7, 1, 1, 1)
                    end
                    
                    GameTooltip:Show() -- Force resize
                end
            end
        end
    end
    
    -- Refresh target info
    -- if UnitExists("target") then
    --     local targetGuid = UnitGUID("target")
    --     if targetGuid and string.lower(targetGuid) == string.lower(guid) then
    --         if UpdateTargetInfo then
    --             UpdateTargetInfo()
    --         end
    --     end
    -- end
end

local function ParseNPCIdsFromGuid(guid)
    if not guid or type(guid) ~= "string" then
        return nil
    end

    -- Handle 3.3.5a Hex GUIDs (e.g., 0xF130001234005678)
    if guid:find("^0x") then
        local hex = guid:sub(3)
        if #hex > 12 then
            -- 3.3.5a Layout: High(16) - Entry(24) - Low(24)
            -- Last 6 chars = Low GUID (Spawn ID)
            -- Previous 6 chars = Entry ID
            local spawnHex = hex:sub(-6)
            local entryHex = hex:sub(-12, -7)
            local highHex = hex:sub(1, -13)

            -- Check for Creature (F130) or Vehicle (F150) or Pet (F140)
            -- We check if it starts with F1 to cover these cases.
            if highHex:find("^F1") then
                local entry = tonumber(entryHex, 16)
                local spawnId = tonumber(spawnHex, 16)
                return entry, spawnId, spawnHex
            end
        end
        return nil
    end

    local parts
    if type(strsplit) == "function" then
        parts = { strsplit("-", guid) }
    else
        parts = {}
        for token in string.gmatch(guid, "[^%-]+") do
            parts[#parts + 1] = token
        end
    end

    -- WoW 3.3.5a GUID formats vary slightly; to be resilient, take:
    -- - unitType = first token
    -- - entry = second-to-last token
    -- - spawnUID = last token
    local unitType = parts[1]
    local entryStr = parts[#parts - 1]
    local spawnHex = parts[#parts]

    if unitType ~= "Creature" and unitType ~= "Vehicle" and unitType ~= "Pet" then
        return nil
    end

    local entry = tonumber(entryStr)
    local spawnId = nil

    if spawnHex and spawnHex ~= "" then
        -- spawnUID is hex in most 3.3.5a GUID strings
        spawnId = tonumber(spawnHex, 16) or tonumber(spawnHex)
    end

    if not entry and not spawnId then
        return nil
    end

    return entry, spawnId, spawnHex
end

local function ShouldShowNpcTooltip()
    if type(DCWelcomeDB) == "table" and DCWelcomeDB.showTooltips == false then
        return false
    end
    return true
end

local function AddNpcLines(tooltip, unit)
    if not tooltip or not unit or not UnitExists(unit) then
        return
    end
    if not ShouldShowNpcTooltip() then
        return
    end

    local guid = UnitGUID(unit)
    if not guid then
        return
    end

    -- Avoid duplicating lines when tooltip updates.
    if tooltip._dcwelcomeNpcGuid == guid then
        return
    end

    local entry, _, _ = ParseNPCIdsFromGuid(guid)
    local dbGuid = nil
    local dbGuidHex = nil
    
    -- Check cache for server-provided info (overrides local parse)
    if npcInfoCache[guid] then
        if npcInfoCache[guid].spawnId and npcInfoCache[guid].spawnId > 0 then
            dbGuid = npcInfoCache[guid].spawnId
            dbGuidHex = string.format("%x", dbGuid)
        end
        if npcInfoCache[guid].entry and npcInfoCache[guid].entry > 0 then
            entry = npcInfoCache[guid].entry
        end
    else
        -- Request info if not cached
        DCWelcome.GetNPCInfo(guid)
    end
    
    if not entry and not dbGuid then
        return
    end

    tooltip._dcwelcomeNpcGuid = guid

    tooltip:AddLine(" ")
    if entry then
        tooltip:AddDoubleLine("Entry:", tostring(entry), 0.7, 0.7, 0.7, 1, 1, 1)
    end
    if dbGuid then
        local right = tostring(dbGuid)
        -- Hex removed as requested
        tooltip:AddDoubleLine("DB GUID:", right, 0.7, 0.7, 0.7, 1, 1, 1)
    else
        tooltip:AddDoubleLine("DB GUID:", "Fetching...", 0.7, 0.7, 0.7, 0.5, 0.5, 0.5)
    end
    tooltip:Show()
end

-- --- Target Frame Integration ---
-- Removed as requested
-- local targetInfoFrame = CreateFrame("Frame", "DCWelcomeTargetInfo", TargetFrame)
-- targetInfoFrame:SetSize(150, 40)
-- -- Positioned below the TargetFrame to be visible when targeting
-- targetInfoFrame:SetPoint("TOPLEFT", TargetFrame, "BOTTOMLEFT", 5, 5)

-- local targetInfoText = targetInfoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
-- targetInfoText:SetPoint("TOPLEFT", targetInfoFrame, "TOPLEFT", 0, 0)
-- targetInfoText:SetJustifyH("LEFT")
-- targetInfoText:SetTextColor(0.8, 0.8, 0.8)

UpdateTargetInfo = function()
    -- if not UnitExists("target") then
    --     targetInfoText:SetText("")
    --     return
    -- end

    -- if not ShouldShowNpcTooltip() then
    --     targetInfoText:SetText("")
    --     return
    -- end

    -- local guid = UnitGUID("target")
    -- local entry, _, _ = ParseNPCIdsFromGuid(guid)
    -- local dbGuid = nil
    -- local dbGuidHex = nil
    
    -- -- Check cache for server-provided info
    -- if npcInfoCache[guid] then
    --     if npcInfoCache[guid].spawnId and npcInfoCache[guid].spawnId > 0 then
    --         dbGuid = npcInfoCache[guid].spawnId
    --         dbGuidHex = string.format("%x", dbGuid)
    --     end
    --     if npcInfoCache[guid].entry and npcInfoCache[guid].entry > 0 then
    --         entry = npcInfoCache[guid].entry
    --     end
    -- else
    --     -- Request info if not cached
    --     DCWelcome.GetNPCInfo(guid)
    -- end

    -- if entry or dbGuid then
    --     local text = ""
    --     if entry then
    --         text = text .. "Entry: |cffffffff" .. entry .. "|r"
    --     end
    --     if dbGuid then
    --         if text ~= "" then text = text .. "\n" end
    --         text = text .. "DB GUID: |cffffffff" .. dbGuid .. "|r"
    --         -- Hex removed as requested
    --     end
        
    --     targetInfoText:SetText(text)
    -- else
    --     targetInfoText:SetText("")
    -- end
end

local function HookTooltip()
    if not GameTooltip or not GameTooltip.HookScript then
        return
    end

    -- Secondary hook path: some tooltips call SetUnit but may not fire OnTooltipSetUnit.
    -- Wrap in pcall because some 3.3.5 clients have different hooksecurefunc behavior.
    if type(hooksecurefunc) == "function" and type(GameTooltip.SetUnit) == "function" then
        pcall(function()
            hooksecurefunc(GameTooltip, "SetUnit", function(self, unit)
                if unit and UnitExists(unit) then
                    AddNpcLines(self, unit)
                end
            end)
        end)
    end

    GameTooltip:HookScript("OnTooltipSetUnit", function(self)
        local _, unit = self:GetUnit()

        if (not unit) or (not UnitExists(unit)) then
            -- Fallback #1: mouseover is often valid even when GetUnit() is nil
            if UnitExists("mouseover") then
                unit = "mouseover"
            end
        end

        if (not unit) or (not UnitExists(unit)) then
            -- Fallback #2: mouse focus unit attribute (some frames)
            local focus = GetMouseFocus and GetMouseFocus()
            if focus and focus.GetAttribute then
                local u = focus:GetAttribute("unit")
                if u and UnitExists(u) then
                    unit = u
                end
            end
        end

        if unit and UnitExists(unit) then
            AddNpcLines(self, unit)
        end
    end)

    -- Reset flag when tooltip is cleared to ensure fresh updates on next show
    GameTooltip:HookScript("OnTooltipCleared", function(self)
        self._dcwelcomeNpcGuid = nil
    end)

    -- Fallback: ensure we still try when tooltip is shown but unit isn't reported.
    GameTooltip:HookScript("OnShow", function(self)
        local _, unit = self:GetUnit()
        if (not unit) or (not UnitExists(unit)) then
            if UnitExists("mouseover") then
                unit = "mouseover"
            elseif UnitExists("target") then
                unit = "target"
            end
        end
        if unit and UnitExists(unit) then
            AddNpcLines(self, unit)
        end
    end)
end

-- Defer hook until PLAYER_LOGIN so globals (GameTooltip, UnitGUID, etc.) are ready.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        HookTooltip()
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- UpdateTargetInfo()
    end
end)
