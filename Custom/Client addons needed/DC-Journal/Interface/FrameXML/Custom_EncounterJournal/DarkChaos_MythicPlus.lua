-- =====================================================================
--  DarkChaos_MythicPlus.lua
--  Adds two top-level CONTENT TABS to the Adventure Guide (next to
--  Instance / Raids):
--    * "Open World" -- world-boss instances registered via
--                      DCJournal.AddInstance({ openWorld = true }) (Giant Isles).
--    * "Mythic+"    -- the current seasonal Mythic+ dungeons, resolved live from
--                      the GetDCMythicPlusDungeons native.
--
--  Both reuse the existing dungeon grid; selecting an entry opens its normal
--  journal page (bosses / loot / model). The tab buttons themselves are defined
--  in Custom_EncounterJournal.xml. This file (loaded AFTER the bootstrap) wraps
--  the final EJ_ContentTab_Select / EJ_GetInstanceByIndex / ListInstances.
--  No new textures required.
-- =====================================================================

local OPENWORLD_TAB_ID  = 5
local MYTHICPLUS_TAB_ID = 6

-- JOURNALINSTANCE field indices (mirror Custom_EncounterJournal.lua)
local F_NAME, F_DESC, F_BUTTON, F_BG, F_LOREBG, F_MAPID, F_AREAID, F_ID = 1, 2, 3, 5, 6, 7, 8, 11

local function norm(s)
    if type(s) ~= "string" then return nil end
    return string.lower((s:gsub("%s+", "")))
end

-- Open World: instances registered with openWorld=true, in registration order.
local function BuildOpenWorldList()
    local list = {}
    local ids = DCJournal and DCJournal.openWorldInstances
    if not ids or not JOURNALINSTANCE then return list end
    for _, id in ipairs(ids) do
        local data = JOURNALINSTANCE[id]
        if data then list[#list + 1] = data end
    end
    return list
end

-- Mythic+: current seasonal dungeons from the DC native (mapId, then name).
local function BuildMythicInstanceList()
    local list = {}
    if type(GetDCMythicPlusDungeons) ~= "function" or not JOURNALINSTANCE then return list end
    local ok, rows = pcall(GetDCMythicPlusDungeons)
    if not ok or type(rows) ~= "table" then return list end

    local byMap, byName = {}, {}
    for _, data in pairs(JOURNALINSTANCE) do
        if data[F_MAPID] then byMap[data[F_MAPID]] = data end
        local n = norm(data[F_NAME])
        if n then byName[n] = data end
    end

    local seen = {}
    for _, row in ipairs(rows) do
        if type(row) == "table" then
            local mapId = tonumber(row.mapId or row.map_id or row.id)
            local data = (mapId and byMap[mapId])
                or byName[norm(row.name or row.dungeonName or row.dungeon_name)]
            if data and not seen[data] then
                seen[data] = true
                list[#list + 1] = data
            end
        end
    end
    return list
end

local cache  -- per-refresh cache of the active custom list

local function ActiveCustomList()
    local mode = EncounterJournal and EncounterJournal.dcActiveTab
    if mode == OPENWORLD_TAB_ID then
        cache = cache or BuildOpenWorldList()
        return cache
    elseif mode == MYTHICPLUS_TAB_ID then
        cache = cache or BuildMythicInstanceList()
        return cache
    end
    return nil
end

-- Serve our custom instance lists when one of our tabs is active.
if EJ_GetInstanceByIndex and not EncounterJournal_DCTabsHooked then
    EncounterJournal_DCTabsHooked = true
    local origGetInstanceByIndex = EJ_GetInstanceByIndex
    function EJ_GetInstanceByIndex(index, isRaid)
        local list = ActiveCustomList()
        if list then
            local data = list[index]
            if not data then return nil end
            return data[F_ID], data[F_NAME], data[F_DESC], data[F_BG],
                data[F_BUTTON], data[F_LOREBG], data[F_MAPID], data[F_AREAID], nil
        end
        return origGetInstanceByIndex(index, isRaid)
    end
end

-- Skip loot for dungeons opened via the Mythic+ tab. M+ loot scales / differs from
-- the dungeon's static normal-mode loot, so showing it would be misleading. The
-- normal Dungeon view (and the Open World tab) still show loot as usual.
if EJ_GetNumLoot and not EncounterJournal_DCLootHooked then
    EncounterJournal_DCLootHooked = true
    local origGetNumLoot = EJ_GetNumLoot
    local origGetLootInfoByIndex = EJ_GetLootInfoByIndex
    function EJ_GetNumLoot()
        if EncounterJournal and EncounterJournal.dcActiveTab == MYTHICPLUS_TAB_ID then
            return 0
        end
        return origGetNumLoot()
    end
    function EJ_GetLootInfoByIndex(index)
        if EncounterJournal and EncounterJournal.dcActiveTab == MYTHICPLUS_TAB_ID then
            return nil
        end
        return origGetLootInfoByIndex(index)
    end
end

-- Route clicks on our custom tabs (the others fall through to the original).
if EJ_ContentTab_Select and not EncounterJournal_DCTabSelectHooked then
    EncounterJournal_DCTabSelectHooked = true
    local origContentTabSelect = EJ_ContentTab_Select
    function EJ_ContentTab_Select(id)
        if id == OPENWORLD_TAB_ID or id == MYTHICPLUS_TAB_ID then
            EncounterJournal.dcActiveTab = id
            cache = nil
            origContentTabSelect(id)            -- highlights our tab (no listing for our id)
            EJ_HideNonInstancePanels()
            EncounterJournal.instanceSelect.scroll:Show()
            EncounterJournal_ListInstances()
            EncounterJournal_DisableTierDropDown(true)  -- expansion tier is irrelevant here
        else
            EncounterJournal.dcActiveTab = nil
            origContentTabSelect(id)
        end
    end
end

-- Clear the per-refresh cache so the custom lists rebuild on every refresh.
if EncounterJournal_ListInstances and not EncounterJournal_DCListHooked then
    EncounterJournal_DCListHooked = true
    local origListInstances = EncounterJournal_ListInstances
    function EncounterJournal_ListInstances()
        cache = nil
        origListInstances()
    end
end
