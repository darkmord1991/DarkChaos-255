-- ============================================================
-- DC-QoS: Tooltips Module - Units / NPCs
-- Split out of Tooltips.lua; state is shared via DCQOS.TooltipsNS
-- ============================================================

local addon = DCQOS
local TT = addon.TooltipsNS
local Tooltips = TT.module

-- ============================================================
-- NPC ID in Tooltips (with DB GUID from server)
-- ============================================================
local npcInfoCache = {}       -- Cache server-provided NPC info
local pendingNpcRequests = {} -- Track pending requests
local NPC_INFO_CACHE_DURATION = 300
local NPC_INFO_PENDING_TIMEOUT = 5.0
local npcKillCountsByEntry = nil
local npcKillCountsByName = nil
TT.killTrackerFrame = nil

-- Parse NPC IDs from GUID (3.3.5a format)
function TT.ParseNpcFromGuid(guid)
    if not guid or type(guid) ~= "string" then
        return nil, nil
    end
    
    -- Handle 3.3.5a Hex GUIDs (e.g., 0xF130001234005678)
    if guid:find("^0x") then
        local hex = guid:sub(3)
        if #hex >= 12 then
            -- 3.3.5a Layout: High(variable) - Entry(24 bits) - Low(24 bits)
            -- Last 6 chars = Low GUID (Spawn ID)
            -- Previous 6 chars = Entry ID
            local spawnHex = hex:sub(-6)
            local entryHex = hex:sub(-12, -7)
            local highHex = hex:sub(1, -13)
            
            -- Check for Creature (F130), Vehicle (F150), or Pet (F140)
            if highHex:find("^F1") then
                local entry = tonumber(entryHex, 16)
                local spawnId = tonumber(spawnHex, 16)
                return entry, spawnId
            end
        end
    end
    
    -- Fallback: string-based parsing (Creature-0-0000-0-0000-Entry-SpawnId)
    local parts = {}
    for token in string.gmatch(guid, "[^%-]+") do
        parts[#parts + 1] = token
    end
    
    local unitType = parts[1]
    if unitType ~= "Creature" and unitType ~= "Vehicle" and unitType ~= "Pet" then
        return nil, nil
    end
    
    local entry = tonumber(parts[#parts - 1])
    local spawnHex = parts[#parts]
    local spawnId = tonumber(spawnHex, 16) or tonumber(spawnHex)
    
    return entry, spawnId
end

local function NormalizeNpcName(name)
    name = tostring(name or "")
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    name = name:gsub("|T.-|t", "")
    return string.lower(name)
end

local function GetKillStores()
    if addon and addon.db and addon.db.npcKillStats then
        local stats = addon.db.npcKillStats
        local account = stats.account
        local charKey = addon.GetCharacterKey and addon:GetCharacterKey() or (UnitName("player") or "Unknown") .. "-" .. (GetRealmName() or "Unknown")
        local character = stats.characters and stats.characters[charKey]
        if not account then
            account = { byEntry = {}, byName = {}, nameByEntry = {} }
            stats.account = account
        end
        if not stats.characters then
            stats.characters = {}
        end
        if not character then
            character = { byEntry = {}, byName = {}, nameByEntry = {} }
            stats.characters[charKey] = character
        end
        return account, character
    end
    return nil, nil
end

local function CacheNpcNameByEntry(entry, name)
    if not entry or not name or name == "" then return end
    local account, character = GetKillStores()
    if not account or not character then return end
    account.nameByEntry[entry] = name
    character.nameByEntry[entry] = name
end

local function IncrementNpcKill(entry, name)
    local account, character = GetKillStores()
    if not account or not character then
        return
    end

    if entry then
        account.byEntry[entry] = (account.byEntry[entry] or 0) + 1
        character.byEntry[entry] = (character.byEntry[entry] or 0) + 1
        if name and name ~= "" then
            account.nameByEntry[entry] = name
            character.nameByEntry[entry] = name
        end
    end

    if name and name ~= "" then
        local key = NormalizeNpcName(name)
        if key ~= "" then
            account.byName[key] = (account.byName[key] or 0) + 1
            character.byName[key] = (character.byName[key] or 0) + 1
        end
    end
end

local function GetNpcKillCounts(entry, name)
    local account, character = GetKillStores()
    if not account or not character then
        return 0, 0
    end

    local key = (name and name ~= "") and NormalizeNpcName(name) or nil

    local charCount = 0
    local acctCount = 0

    if entry then
        charCount = character.byEntry[entry] or 0
        acctCount = account.byEntry[entry] or 0
    elseif key and key ~= "" then
        charCount = character.byName[key] or 0
        acctCount = account.byName[key] or 0
    end

    return charCount, acctCount
end

function TT.HandleCombatLogEvent(...)
    if not addon.settings.tooltips.showNpcKillCount then
        return
    end

    local subevent = select(2, ...)
    if subevent ~= "PARTY_KILL" then
        return
    end

    local sourceGUID, sourceName, sourceFlags
    local destGUID, destName, destFlags

    -- 3.3.5a layout: timestamp, subevent, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags
    -- Modern layout: timestamp, subevent, hideCaster, srcGUID, srcName, srcFlags, srcRaidFlags, dstGUID, dstName, dstFlags, dstRaidFlags
    if type(select(3, ...)) == "boolean" then
        sourceGUID = select(4, ...)
        sourceName = select(5, ...)
        sourceFlags = select(6, ...)
        destGUID = select(8, ...)
        destName = select(9, ...)
        destFlags = select(10, ...)
    else
        sourceGUID = select(3, ...)
        sourceName = select(4, ...)
        sourceFlags = select(5, ...)
        destGUID = select(6, ...)
        destName = select(7, ...)
        destFlags = select(8, ...)
    end

    if not destGUID then return end

    local playerGUID = UnitGUID("player")
    local petGUID = UnitGUID("pet")
    local vehicleGUID = UnitGUID("vehicle")

    local isMine = (sourceGUID and (sourceGUID == playerGUID or sourceGUID == petGUID or sourceGUID == vehicleGUID))
    if not isMine and sourceFlags and COMBATLOG_OBJECT_AFFILIATION_MINE and bit and bit.band then
        isMine = (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0)
    end
    if not isMine and sourceName then
        local playerName = UnitName("player")
        local petName = UnitName("pet")
        local vehicleName = UnitName("vehicle")
        if (playerName and sourceName == playerName)
            or (petName and sourceName == petName)
            or (vehicleName and sourceName == vehicleName) then
            isMine = true
        end
    end
    if not isMine then return end

    local entry = TT.ParseNpcFromGuid(destGUID)
    IncrementNpcKill(entry, destName)
end

-- Request NPC info from server
local function RequestNpcInfo(guid)
    if not guid then return end
    guid = TT.NormalizeTooltipGuid(guid)
    if not guid then return end
    local now = GetTime()

    local pendingAt = tonumber(pendingNpcRequests[guid]) or 0
    if pendingAt > 0 and (now - pendingAt) < NPC_INFO_PENDING_TIMEOUT then
        return
    end
    if pendingAt > 0 and (now - pendingAt) >= NPC_INFO_PENDING_TIMEOUT then
        pendingNpcRequests[guid] = nil
        TT.TelemetryInc("npc", "pendingTimeoutRecoveries")
    end

    local cached = npcInfoCache[guid]
    local cacheTtl = (cached and cached.spawnMissing) and 15 or NPC_INFO_CACHE_DURATION
    if cached and (now - (tonumber(cached.timestamp) or 0)) < cacheTtl then
        return
    end
    if cached then
        npcInfoCache[guid] = nil
    end
    
    pendingNpcRequests[guid] = now
    TT.TelemetryInc("npc", "requestsSent")

    if addon.protocol and addon.protocol.connected then
        if TT.ShouldUseNativeNpcTooltipBridge() then
            local ok, nativeDispatched = pcall(RequestNativeNpcTooltipInfo,
                guid)
            if ok and nativeDispatched ~= false then
                TT.TelemetryInc("npc", "nativeRequestsSent")
                return
            end

            TT.TelemetryInc("npc", "nativeFallbacks")
            if not ok then
                TT.TelemetryInc("npc", "nativeErrors")
                addon:Debug("Native NPC tooltip request failed: "
                    .. tostring(nativeDispatched))
            else
                addon:Debug("Native NPC tooltip request not dispatched; falling back to addon protocol")
            end
        end

        addon.protocol:RequestNpcInfo(guid)
    end
end

local function TryConsumeNativeNpcInfo(guid)
    guid = TT.NormalizeTooltipGuid(guid)
    if not guid or not pendingNpcRequests[guid]
        or type(GetNativeNpcTooltipInfo) ~= "function" then
        return false
    end

    local ok, entry, spawnId, dbGuid, errorMessage =
        pcall(GetNativeNpcTooltipInfo, guid)
    if not ok then
        TT.TelemetryInc("npc", "nativeErrors")
        addon:Debug("Native NPC tooltip poll failed: " .. tostring(entry))
        return false
    end

    if entry == nil then
        return false
    end

    TT.TelemetryInc("npc", "nativeResponsesReady")
    addon:FireEvent("NPC_INFO_RECEIVED", {
        guid = guid,
        entry = tonumber(entry) or 0,
        spawnId = tonumber(spawnId) or 0,
        dbGuid = tonumber(dbGuid) or 0,
        error = type(errorMessage) == "string" and errorMessage ~= ""
            and errorMessage or nil,
    })
    return true
end

-- Handle NPC info received from server
local function OnNpcInfoReceived(npcData)
    if not npcData or not npcData.guid then return end
    TT.TelemetryInc("npc", "responsesReceived")
    
    local guid = npcData.guid
    -- Normalize GUID to match UnitGUID format (0x prefix)
    if string.sub(guid, 1, 2) ~= "0x" then
        guid = "0x" .. guid
    end
    
    pendingNpcRequests[guid] = nil

    if npcData.error then
        npcInfoCache[guid] = nil
        return
    end

    local spawnIdNum = tonumber(npcData.spawnId) or 0
    local dbGuidNum  = tonumber(npcData.dbGuid)  or tonumber(npcData.spawnGuid) or 0
    npcInfoCache[guid] = {
        timestamp    = GetTime(),
        spawnId      = npcData.spawnId,
        entry        = npcData.entry,
        dbGuid       = npcData.dbGuid or npcData.spawnGuid,
        spawnMissing = spawnIdNum == 0 and dbGuidNum == 0,
    }
    
    -- Don't force refresh to avoid lag
    -- Data will appear on next natural tooltip update
end

-- Register for NPC info events
addon:RegisterEvent("NPC_INFO_RECEIVED", OnNpcInfoReceived)

local function AddNpcId(tooltip, unit, guidOverride)
    if not addon.settings.tooltips.showNpcId then return end
    if not unit and not guidOverride then return end
    if unit and UnitIsPlayer(unit) then return end
    
    local guid = guidOverride or UnitGUID(unit)
    guid = TT.NormalizeTooltipGuid(guid)
    if not guid then return end
    
    -- Avoid duplicate lines
    if tooltip._dcqosNpcGuid == guid then return end
    tooltip._dcqosNpcGuid = guid
    
    -- Parse local NPC info
    local entry, localSpawnId = TT.ParseNpcFromGuid(guid)
    local unitName = unit and UnitName(unit) or nil
    if entry and unitName then
        CacheNpcNameByEntry(entry, unitName)
    end
    
    -- Check server cache for more accurate info
    if TT.ShouldUseNativeNpcTooltipBridge() then
        TryConsumeNativeNpcInfo(guid)
    end

    local cachedInfo = npcInfoCache[guid]
    local dbGuid = nil
    
    if cachedInfo then
        local cachedEntry   = tonumber(cachedInfo.entry)   or 0
        local cachedSpawnId = tonumber(cachedInfo.spawnId) or 0
        local cachedDbGuid  = tonumber(cachedInfo.dbGuid)  or 0
        if cachedEntry   ~= 0 then entry        = cachedEntry   end
        if cachedSpawnId ~= 0 then localSpawnId = cachedSpawnId end
        dbGuid = (cachedDbGuid ~= 0 and cachedDbGuid)
            or  (cachedSpawnId ~= 0 and cachedSpawnId)
            or  nil
    else
        -- Request from server
        RequestNpcInfo(guid)
    end

    -- Add separator
    tooltip:AddLine(" ")

    -- Show Entry ID
    if entry then
        tooltip:AddDoubleLine("Entry:", "|cffffffff" .. entry .. "|r", 0.5, 0.5, 0.5)
    end

    -- Show Spawn (from server or parsed)
    if dbGuid then
        tooltip:AddDoubleLine("Spawn:", "|cffffffff" .. dbGuid .. "|r", 0.5, 0.5, 0.5)
    elseif cachedInfo == nil or (cachedInfo and cachedInfo.spawnMissing) then
        -- No response yet, or server returned 0 (freshly spawned NPC without DB entry yet)
        tooltip:AddDoubleLine("Spawn:", "|cff888888Fetching...|r", 0.5, 0.5, 0.5)
    elseif localSpawnId then
        tooltip:AddDoubleLine("Spawn:", "|cffffff88~" .. localSpawnId .. "|r", 0.5, 0.5, 0.5)
    end
    
    -- Show raw GUID if debug mode
    if addon.settings.communication and addon.settings.communication.debugMode then
        tooltip:AddDoubleLine("GUID:", "|cff666666" .. guid .. "|r", 0.3, 0.3, 0.3)
    end
end

local function AddNpcKillCount(tooltip, unit)
    if not addon.settings.tooltips.showNpcKillCount then return end
    if not unit then return end
    if UnitIsPlayer(unit) then return end

    local canAttack = UnitCanAttack("player", unit)
    local reaction = UnitReaction(unit, "player")
    if not canAttack and (reaction == nil or reaction >= 5) then
        return
    end

    local guid = UnitGUID(unit)
    if not guid then return end

    local entry = TT.ParseNpcFromGuid(guid)
    local name = UnitName(unit)
    local charCount, acctCount = GetNpcKillCounts(entry, name)

    local key = entry or name or guid
    if tooltip._dcqosNpcKillShown == key then return end
    tooltip._dcqosNpcKillShown = key

    tooltip:AddDoubleLine("Kills (Char):", "|cffffffff" .. tostring(charCount or 0) .. "|r", 0.5, 0.5, 0.5)
    tooltip:AddDoubleLine("Kills (Account):", "|cffffffff" .. tostring(acctCount or 0) .. "|r", 0.5, 0.5, 0.5)
end

local nativeTooltipPollFrame = nil
local nativeTooltipPollElapsed = 0
local NATIVE_TOOLTIP_POLL_INTERVAL = 0.05

local function RefreshTrackedTooltip(tooltip)
    if not tooltip or tooltip ~= GameTooltip or not tooltip.IsShown or not tooltip:IsShown() then
        return false
    end

    local refreshKind = tooltip._dcqosRefreshKind
    if refreshKind == "bag" and tooltip.SetBagItem then
        local bag = tonumber(tooltip._dcqosRefreshBag)
        local slot = tonumber(tooltip._dcqosRefreshSlot)
        if bag ~= nil and slot ~= nil then
            tooltip:SetBagItem(bag, slot)
            return true
        end
    elseif refreshKind == "inventory" and tooltip.SetInventoryItem then
        local unit = tooltip._dcqosRefreshUnit
        local slot = tonumber(tooltip._dcqosRefreshSlot)
        if unit and slot ~= nil and UnitExists(unit) then
            tooltip:SetInventoryItem(unit, slot)
            return true
        end
    elseif refreshKind == "unit" and tooltip.SetUnit then
        local unit = tooltip._dcqosRefreshUnit
        if unit and UnitExists(unit) then
            tooltip:SetUnit(unit)
            return true
        end
    end

    return false
end

local function PollActiveNativeTooltipData(tooltip)
    if not tooltip or tooltip ~= GameTooltip or not tooltip.IsShown or not tooltip:IsShown() then
        return false
    end

    local refreshed = false
    local refreshKind = tooltip._dcqosRefreshKind

    if refreshKind == "bag" and TT.ShouldUseNativeItemUpgradeBridge() then
        local bag = tonumber(tooltip._dcqosRefreshBag)
        local slot = tonumber(tooltip._dcqosRefreshSlot)
        if bag ~= nil and slot ~= nil then
            local serverBag = TT.GetServerBagFromClient(bag)
            local serverSlot = TT.GetServerSlotFromClient(bag, slot)
            if TT.TryConsumeNativeUpgradeInfo(serverBag, serverSlot) then
                refreshed = RefreshTrackedTooltip(tooltip) or refreshed
            end
        end
    elseif refreshKind == "inventory" and TT.ShouldUseNativeItemUpgradeBridge() then
        local unit = tooltip._dcqosRefreshUnit
        local slot = tonumber(tooltip._dcqosRefreshSlot)
        if unit == "player" and slot ~= nil then
            local serverBag = TT.GetServerBagFromClient(-2)
            local serverSlot = TT.GetServerSlotFromClient(-2, slot)
            if TT.TryConsumeNativeUpgradeInfo(serverBag, serverSlot) then
                refreshed = RefreshTrackedTooltip(tooltip) or refreshed
            end
        end
    elseif refreshKind == "unit" and TT.ShouldUseNativeNpcTooltipBridge() then
        local unit = tooltip._dcqosRefreshUnit
        local guid = unit and UnitExists(unit) and UnitGUID(unit) or nil
        if guid and TryConsumeNativeNpcInfo(guid) then
            refreshed = RefreshTrackedTooltip(tooltip) or refreshed
        end
    end

    if TT.ShouldUseNativeSpellTooltipAddonBridge() then
        local key = tooltip._dcqosActiveSpellKey
        local spellId, contextHash = nil, nil
        if type(key) == "string" then
            spellId, contextHash = string.match(key, "^(%d+):(%d+)$")
        end
        if spellId and contextHash and TT.pendingSpellEnrichment[key]
            and TT.TryConsumeNativeSpellTooltipEnrichment(tonumber(spellId), tonumber(contextHash)) then
            refreshed = true
        end
    end

    return refreshed
end

function TT.EnsureNativeTooltipPollFrame()
    if nativeTooltipPollFrame then
        return
    end

    nativeTooltipPollFrame = CreateFrame("Frame")
    nativeTooltipPollFrame:SetScript("OnUpdate", function(_, elapsed)
        nativeTooltipPollElapsed = nativeTooltipPollElapsed + (tonumber(elapsed) or 0)
        if nativeTooltipPollElapsed < NATIVE_TOOLTIP_POLL_INTERVAL then
            return
        end

        nativeTooltipPollElapsed = 0
        PollActiveNativeTooltipData(GameTooltip)
    end)
end

-- ============================================================
-- Unit Tooltip Enhancement
-- ============================================================
local function EnhanceUnitTooltip(tooltip, unit)
    local settings = addon.settings.tooltips
    if not settings.enabled then return end
    
    -- Hide in combat if enabled
    if settings.hideInCombat and UnitAffectingCombat("player") then
        if not settings.showWithShift or not IsShiftKeyDown() then
            tooltip:Hide()
            return
        end
    end
    
    local name, realm = UnitName(unit)
    local isPlayer = UnitIsPlayer(unit)
    local level = UnitLevel(unit)
    local reaction = UnitReaction(unit, "player")
    
    -- Show NPC ID for non-players
    if not isPlayer then
        AddNpcId(tooltip, unit)
        AddNpcKillCount(tooltip, unit)
    end
    
    -- Show target if enabled
    if settings.showTarget then
        local target = unit .. "target"
        if UnitExists(target) then
            local targetName = UnitName(target)
            local targetReaction = UnitReaction(target, "player")
            
            local targetColor = "|cffffffff"
            if UnitIsUnit(target, "player") then
                targetColor = "|cffff0000"
                targetName = ">> YOU <<"
            elseif targetReaction then
                if targetReaction >= 5 then
                    targetColor = "|cff00ff00"  -- Friendly
                elseif targetReaction <= 2 then
                    targetColor = "|cffff0000"  -- Hostile
                else
                    targetColor = "|cffffff00"  -- Neutral
                end
            end
            
            tooltip:AddLine(" ")
            tooltip:AddDoubleLine("Target:", targetColor .. (targetName or "Unknown") .. "|r", 0.5, 0.5, 0.5)
        end
    end
    
    -- Show guild rank for players
    if isPlayer and settings.showGuildRank then
        local guildName, guildRank = GetGuildInfo(unit)
        if guildName and guildRank then
            local isMyGuild = UnitIsInMyGuild(unit)
            if isMyGuild or settings.showGuildRank then
                -- Guild rank is already shown by default tooltip, 
                -- but we ensure it's colored appropriately
            end
        end
    end
    
    tooltip:Show()
end

-- ============================================================
-- Unit Tooltip Hooks
-- ============================================================
function TT.HookUnitTooltips()
    if GameTooltip._dcqosHookedOnTooltipSetUnit and GameTooltip._dcqosHookedOnTooltipCleared then
        return
    end

    local function ResetTooltipTransientState(self)
        self._dcqosNpcGuid = nil
        self._dcqosUpgradeShown = nil
        self._dcqosRefreshKind = nil
        self._dcqosRefreshBag = nil
        self._dcqosRefreshSlot = nil
        self._dcqosRefreshUnit = nil
        self._dcqosRefreshNpcGuid = nil
        self._dcqosResolvedSpellId = nil
        self._dcqosSpellSource = nil
        self._dcqosSpellSourceAt = nil
        self._dcqosSpellIdShown = nil
        self._dcqosLastEnhancedSpellId = nil
        self._dcqosLastEnhancedSpellAt = nil
        self._dcqosActiveSpellKey = nil
        self._dcqosClientDescriptionShownKey = nil
        self._dcqosSpellEnrichmentShownKey = nil
        self._dcqosNativeDescriptionStrippedKey = nil
        self._dcqosPendingSpellIdForBottom = nil
        self._dcqosNpcKillShown = nil
    end

    -- Hook OnTooltipSetUnit
    if not GameTooltip._dcqosHookedOnTooltipSetUnit then
        GameTooltip._dcqosHookedOnTooltipSetUnit = true
        GameTooltip:HookScript("OnTooltipSetUnit", function(self)
            local _, unit = self:GetUnit()
            
            -- Fallback: mouseover when GetUnit returns nil
            if not unit or not UnitExists(unit) then
                if UnitExists("mouseover") then
                    unit = "mouseover"
                end
            end
            
            -- Fallback: mouse focus attribute
            if not unit or not UnitExists(unit) then
                local focus = GetMouseFocus and GetMouseFocus()
                if focus and focus.GetAttribute then
                    local u = focus:GetAttribute("unit")
                    if u and UnitExists(u) then
                        unit = u
                    end
                end
            end
            
            if unit then
                self._dcqosRefreshKind = "unit"
                self._dcqosRefreshUnit = unit
                self._dcqosRefreshBag = nil
                self._dcqosRefreshSlot = nil
                self._dcqosRefreshNpcGuid = nil
                EnhanceUnitTooltip(self, unit)
            else
                local guid = TT.GetNativeMouseoverTooltipGuid()
                if guid then
                    self._dcqosRefreshKind = nil
                    self._dcqosRefreshUnit = nil
                    self._dcqosRefreshBag = nil
                    self._dcqosRefreshSlot = nil
                    self._dcqosRefreshNpcGuid = guid
                    AddNpcId(self, nil, guid)
                end
            end
        end)
    end
    
    -- Reset NPC GUID flag and upgrade flag when tooltip is cleared
    if not GameTooltip._dcqosHookedOnTooltipCleared then
        GameTooltip._dcqosHookedOnTooltipCleared = true
        GameTooltip:HookScript("OnTooltipCleared", function(self)
            ResetTooltipTransientState(self)
        end)
    end

    if not GameTooltip._dcqosHookedOnHide then
        GameTooltip._dcqosHookedOnHide = true
        GameTooltip:HookScript("OnHide", function(self)
            ResetTooltipTransientState(self)
        end)
    end
    
    addon:Debug("Unit tooltip hooks installed")
end

-- ============================================================
-- Health Bar Hiding
-- ============================================================
function TT.SetupHealthBarHiding()
    if addon.settings.tooltips.hideHealthBar then
        local tipHide = GameTooltip.Hide
        GameTooltipStatusBar:HookScript("OnShow", function()
            GameTooltipStatusBar:Hide()
        end)
        GameTooltipStatusBar:Hide()
    end
end
