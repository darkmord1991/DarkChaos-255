-- DC-Welcome: NPC tooltip extension (Entry + Spawn ID)
-- Adds two lines to unit tooltips for creatures/vehicles.

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

    local entry, spawnId, spawnHex = ParseNPCIdsFromGuid(guid)
    if not entry and not spawnId then
        return
    end

    tooltip._dcwelcomeNpcGuid = guid

    tooltip:AddLine(" ")
    if entry then
        tooltip:AddDoubleLine("Entry:", tostring(entry), 0.7, 0.7, 0.7, 1, 1, 1)
    end
    if spawnId then
        local right = tostring(spawnId)
        if spawnHex and spawnHex ~= "" then
            right = right .. "  (0x" .. string.upper(spawnHex) .. ")"
        end
        -- Renamed "Spawn ID" to "DB GUID" to match the database column name
        tooltip:AddDoubleLine("DB GUID:", right, 0.7, 0.7, 0.7, 1, 1, 1)
    end
    tooltip:Show()
end

-- --- Target Frame Integration ---
local targetInfoFrame = CreateFrame("Frame", "DCWelcomeTargetInfo", TargetFrame)
targetInfoFrame:SetSize(150, 40)
-- Positioned below the TargetFrame to be visible when targeting
targetInfoFrame:SetPoint("TOPLEFT", TargetFrame, "BOTTOMLEFT", 5, 5)

local targetInfoText = targetInfoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
targetInfoText:SetPoint("TOPLEFT", targetInfoFrame, "TOPLEFT", 0, 0)
targetInfoText:SetJustifyH("LEFT")
targetInfoText:SetTextColor(0.8, 0.8, 0.8)

local function UpdateTargetInfo()
    if not UnitExists("target") then
        targetInfoText:SetText("")
        return
    end

    if not ShouldShowNpcTooltip() then
        targetInfoText:SetText("")
        return
    end

    local guid = UnitGUID("target")
    local entry, spawnId, spawnHex = ParseNPCIdsFromGuid(guid)

    if entry or spawnId then
        local text = ""
        if entry then
            text = text .. "Entry: |cffffffff" .. entry .. "|r"
        end
        if spawnId then
            if text ~= "" then text = text .. "\n" end
            text = text .. "DB GUID: |cffffffff" .. spawnId .. "|r"
            if spawnHex then
                text = text .. " (|cffffffff0x" .. string.upper(spawnHex) .. "|r)"
            end
        end
        
        targetInfoText:SetText(text)
    else
        targetInfoText:SetText("")
    end
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
        UpdateTargetInfo()
    end
end)
