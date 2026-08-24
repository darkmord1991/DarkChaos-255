-- =====================================================================
--  DarkChaos_CurrentInstance.lua
--  "Show me where I am": while the player is inside a dungeon or raid,
--  the Adventure Guide opens straight onto that instance's page instead
--  of the generic instance grid -- the retail Encounter Journal behaviour.
--
--  Loaded LAST (after DarkChaos_MythicPlus.lua) so the wrappers below sit
--  on top of every other override.
--
--  HOW THE CURRENT INSTANCE IS RESOLVED
--  3.3.5a has no client API that returns the player's instance MAP ID --
--  GetInstanceInfo() gives the Map.dbc MapName, and GetCurrentMapAreaID()
--  gives a WORLD MAP index that is only correct while the world map happens
--  to be pointed at the player's own zone. So the primary key here is the
--  map NAME, matched against the journal's own instance names:
--
--    1. a numeric map id, if any client build ever starts returning one
--       (retail returns it as the 8th value of GetInstanceInfo) -> mapID index
--    2. GetInstanceInfo() name       -> name index  (the normal path)
--    3. GetRealZoneText()/GetZoneText() -> name index  (covers instances whose
--       Map.dbc name and zone name disagree)
--    4. the stock EJ_GetCurrentInstance() worldMapAreaID scan (last resort)
--
--  Name matching is normalised (case, spaces, punctuation and a leading
--  "The" are all ignored) and additionally retries on the part after a
--  colon, which is what makes "Coilfang: The Steamvault" find "The
--  Steamvault". The handful of instances whose Map.dbc name shares nothing
--  with its journal name are listed explicitly in MAP_NAME_ALIASES below.
-- =====================================================================

DCJournal = DCJournal or {}

-- JOURNALINSTANCE field indices (mirror Custom_EncounterJournal.lua)
local F_NAME, F_MAPID, F_ID = 1, 7, 11

-- Map.dbc MapName (normalised) -> journal instance id, for the instances whose
-- two names have no word in common. Everything else resolves by name on its own.
local MAP_NAME_ALIASES = {
    ["stormwindstockade"]        = 238,  -- The Stockade
    ["sunkentemple"]             = 237,  -- The Temple of Atal'Hakkar
    ["blackrockspire"]           = 229,  -- Lower Blackrock Spire
    ["ahnqirajtemple"]           = 744,  -- Temple of Ahn'Qiraj
    ["hellfirecitadelramparts"]  = 248,  -- Hellfire Ramparts
    ["tempestkeep"]              = 749,  -- The Eye
    -- All four Scarlet Monastery wings share map 189, so the name alone cannot
    -- tell them apart; open on the Graveyard and let the player pick a wing.
    ["scarletmonastery"]         = 763,
}

local function norm(s)
    if type(s) ~= "string" then return nil end
    s = string.lower(s)
    s = string.gsub(s, "[^a-z0-9]", "")
    if s == "" then return nil end
    if string.sub(s, 1, 3) == "the" then s = string.sub(s, 4) end
    return s ~= "" and s or nil
end

local byName, byMapID

-- Rebuilt on demand; call after registering journal content at runtime.
function DCJournal.RebuildInstanceIndex()
    byName, byMapID = {}, {}
    if type(JOURNALINSTANCE) ~= "table" then return end

    for _, data in pairs(JOURNALINSTANCE) do
        local id = data[F_ID]
        if id then
            local key = norm(data[F_NAME])
            -- First registration wins, so an alias below is never overwritten
            -- by a later same-named entry.
            if key and not byName[key] then byName[key] = id end

            local mapID = tonumber(data[F_MAPID])
            if mapID and mapID > 0 and not byMapID[mapID] then byMapID[mapID] = id end
        end
    end

    for key, id in pairs(MAP_NAME_ALIASES) do
        if JOURNALINSTANCE[id] then byName[key] = id end
    end
end

local function LookupName(name)
    if not byName then DCJournal.RebuildInstanceIndex() end
    if type(name) ~= "string" then return nil end

    local key = norm(name)
    if key and byName[key] then return byName[key] end

    -- "Coilfang: The Steamvault" -> "The Steamvault", "Auchindoun: Sethekk Halls"
    -- -> "Sethekk Halls". Only the tail is retried; the full name was tried above.
    local tail = string.match(name, ":%s*(.+)$")
    if tail then
        key = norm(tail)
        if key and byName[key] then return byName[key] end
    end

    return nil
end

-- The instance map id, when the client can be coaxed into giving one. Vanilla
-- 3.3.5 returns only 7 values from GetInstanceInfo, so this is nil there and the
-- name path takes over; it exists so a future native/extension is picked up for
-- free (the id is exact where a name can, in principle, be ambiguous).
local function CurrentInstanceMapID()
    local ok, mapID = pcall(function() return select(8, GetInstanceInfo()) end)
    if ok then return tonumber(mapID) end
    return nil
end

-- The journal instance id for the dungeon/raid the player is standing in, or nil.
function DCJournal.GetCurrentInstanceID()
    if type(IsInInstance) ~= "function" or type(GetInstanceInfo) ~= "function" then
        return nil
    end

    local inInstance = IsInInstance()
    if not inInstance then return nil end

    if not byMapID then DCJournal.RebuildInstanceIndex() end

    local mapID = CurrentInstanceMapID()
    if mapID and byMapID[mapID] then return byMapID[mapID] end

    -- Before the name path, because the name path CANNOT tell a DC clone from
    -- the instance it was cloned from: map 821 and map 329 are both called
    -- "Stratholme", 2921 and 533 are both "Naxxramas", 825 and 33 are both
    -- "Shadowfang Keep". Each clone has its own WorldMapArea row, registered by
    -- DCJournal.RegisterInstanceWorldMapArea, and that is the one thing left on
    -- 3.3.5 that still distinguishes them.
    --
    -- GetCurrentMapAreaID reports the map the WORLD MAP is showing, which is the
    -- player's own zone unless they have panned it somewhere else. No
    -- SetMapToCurrentZone call is made to force that: yanking the player's map
    -- view as a side effect of opening the journal is worse than the miss, and a
    -- miss just falls through to the name path -- i.e. to the behaviour that
    -- existed before any clone was registered.
    local uiMapArea = DCJournal.instanceByUiMapArea
    if uiMapArea and type(GetCurrentMapAreaID) == "function" then
        local ok, uiMapID = pcall(GetCurrentMapAreaID)
        if ok and uiMapID and uiMapArea[uiMapID] and JOURNALINSTANCE[uiMapArea[uiMapID]] then
            return uiMapArea[uiMapID]
        end
    end

    local id = LookupName(GetInstanceInfo())
    if id then return id end

    if type(GetRealZoneText) == "function" then
        id = LookupName(GetRealZoneText())
        if id then return id end
    end
    if type(GetZoneText) == "function" then
        id = LookupName(GetZoneText())
        if id then return id end
    end

    return nil
end

-- Point the journal's own "where am I" helper at the resolver above, keeping the
-- stock worldMapAreaID scan as the final fallback.
--
-- That scan matches on `worldMapAreaID == GetCurrentMapAreaID() - 1`, and every
-- DC instance registered through DCJournal.AddInstance leaves worldMapAreaID at
-- its default of 0 -- so whenever GetCurrentMapAreaID() happens to be 1 the scan
-- returns an arbitrary one of them. Its answer is only accepted here if the
-- instance it found actually carries a real world map area.
local F_WORLDMAPAREAID = 12

if EJ_GetCurrentInstance and not EncounterJournal_DCCurrentInstanceHooked then
    EncounterJournal_DCCurrentInstanceHooked = true
    local origGetCurrentInstance = EJ_GetCurrentInstance
    function EJ_GetCurrentInstance()
        local id = DCJournal.GetCurrentInstanceID()
        if id then return id end

        id = origGetCurrentInstance()
        local data = id and JOURNALINSTANCE[id]
        if data and (tonumber(data[F_WORLDMAPAREAID]) or 0) > 0 then
            return id
        end
        return nil
    end
end

-- Switch the expansion dropdown to whichever tier owns this instance, otherwise
-- the instance page opens but its nav bar / instance list belong to a different
-- tier -- and a Dark Chaos raid opened while "Wrath of the Lich King" is
-- selected leaves the grid showing the wrong expansion behind it.
local function SelectTierForInstance(instanceID)
    local tierID = JOURNALTIERXINSTANCE and JOURNALTIERXINSTANCE[instanceID]
    if not tierID then return end

    for index = 1, (EJ_GetNumTiers() or 0) do
        local _, _, id = EJ_GetTierInfo(index)
        if id == tierID then
            if EJ_GetCurrentTier() ~= index then
                EncounterJournal_TierDropDown_Select(EncounterJournal, index)
            end
            return
        end
    end
end

-- Stock EncounterJournal_ResetDisplay always selects the Instance tab, so a raid
-- landed on the page with the Dungeon tab lit (and, in a tier holding no
-- dungeons, tripped the empty-tier auto-correct that grays a tab out). Pick the
-- tab that actually matches the instance, and its tier with it.
if EncounterJournal_ResetDisplay and not EncounterJournal_DCResetDisplayHooked then
    EncounterJournal_DCResetDisplayHooked = true
    local origResetDisplay = EncounterJournal_ResetDisplay
    function EncounterJournal_ResetDisplay(instanceID, instanceType, difficultyID)
        if instanceType == "none" or not instanceID or not JOURNALINSTANCE[instanceID] then
            return origResetDisplay(instanceID, instanceType, difficultyID)
        end

        SelectTierForInstance(instanceID)

        local instanceSelect = EncounterJournal.instanceSelect
        local tab = EJ_IsRaid(instanceID) and instanceSelect.raidsTab or instanceSelect.dungeonsTab
        EJ_ContentTab_Select(tab:GetID())

        NavBar_Reset(EncounterJournal.navBar)
        EncounterJournal_DisplayInstance(instanceID)

        EncounterJournal.lastInstance = instanceID
        if EJ_IsValidInstanceDifficulty(difficultyID) then
            EJ_SetDifficulty(difficultyID)
        end
        EncounterJournal.lastDifficulty = difficultyID
    end
end

-- Zoning while the journal is already open should follow the player. Gated on
-- EncounterJournal_HasChangedContext so moving between subzones of the same
-- instance never yanks the page back from whatever the player was reading.
local function RefreshForCurrentInstance()
    if not EncounterJournal or not EncounterJournal:IsShown() then return end

    local instanceID = DCJournal.GetCurrentInstanceID()
    if not instanceID then
        EncounterJournal.lastInstance = nil
        EncounterJournal.lastDifficulty = nil
        return
    end

    local _, instanceType, difficultyID = GetInstanceInfo()
    if EncounterJournal_HasChangedContext(instanceID, instanceType, difficultyID) then
        EncounterJournal_ResetDisplay(instanceID, instanceType, difficultyID)
    end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
watcher:SetScript("OnEvent", function()
    -- GetInstanceInfo is not authoritative the instant the event fires on a
    -- zone-in, so let the frame settle before asking where we are.
    if C_Timer and C_Timer.After then
        C_Timer.After(1, RefreshForCurrentInstance)
    else
        RefreshForCurrentInstance()
    end
end)
