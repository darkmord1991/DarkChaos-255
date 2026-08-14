-- =====================================================================
--  DarkChaos_Difficulty.lua
--  Raid/party sizes outside the stock 5 / 10 / 25 layout, and Mythic.
--
--  Custom_EncounterJournal.lua carries a hardcoded LOCAL table:
--
--      EJ_DIFFICULTIES = { 5 Normal, 5 Heroic, 10 Normal, 25 Normal,
--                          10 Heroic, 25 Heroic }
--
--  Everything about difficulty is keyed off it, and it cannot express what
--  several DC instances actually are (per MapDifficulty.csv):
--
--      Timbermaw Hold  819   20-player  Normal / Heroic / Mythic
--      Emerald Sanctum 824   20-player  Normal / Heroic / Mythic
--      BFD (Ashenvale) 820    5-player  Normal / Heroic / Mythic
--      Crescent Grove  823    5-player  Normal / Heroic / Mythic
--
--  A 20-player raid therefore rendered as "(10) Normal" or "(25) Normal" --
--  the closest hardcoded lie -- and Mythic could not be selected at all,
--  because no entry in that table has a third dungeon difficulty.
--
--  The table is a local, so it cannot be extended from here. Instead the five
--  globals that read it are replaced with versions that first look for a
--  per-instance set registered via DCJournal.SetDifficulties(). Instances
--  without one (Blackwing Descent, Castle Nathria, every Blizzard instance)
--  fall through to the original untouched.
--
--  difficultyID is positional and so lines up with the client: MapDifficulty
--  Difficulty 0/1/2 is reported by GetInstanceInfo() as difficultyID 1/2/3,
--  which is exactly the index in the `modes` list.
-- =====================================================================

DCJournal = DCJournal or {}
DCJournal.difficulties = DCJournal.difficulties or {}

local function ListFor(instanceID)
    instanceID = instanceID or (EncounterJournal and EncounterJournal.instanceID)
    if not instanceID then return nil end
    return DCJournal.difficulties[instanceID]
end

local function EntryFor(list, difficultyID)
    for i = 1, #list do
        if list[i].difficultyID == difficultyID then return list[i] end
    end
    return nil
end

-- --- the five readers of EJ_DIFFICULTIES ------------------------------

if EJ_GetDifficultyInfo and not DCJournal_DifficultyHooked then
    DCJournal_DifficultyHooked = true

    local origGetDifficultyInfo = EJ_GetDifficultyInfo
    function EJ_GetDifficultyInfo(difficultyID, isRaid)
        local list = ListFor()
        if not list then return origGetDifficultyInfo(difficultyID, isRaid) end
        -- A per-instance set already belongs to one instance, so the stock
        -- "size ~= 5 means raid" proxy is neither needed nor correct here.
        return EntryFor(list, difficultyID)
    end

    local origIsValid = EJ_IsValidInstanceDifficulty
    function EJ_IsValidInstanceDifficulty(difficulty, instanceID)
        local id = instanceID or (EncounterJournal and EncounterJournal.instanceID)
        local list = ListFor(id)
        if not list then return origIsValid(difficulty, instanceID) end

        -- Every DC encounter row carries difficultyMask -1 ("all difficulties"),
        -- so a difficulty is valid exactly when the instance declares it and has
        -- at least one boss to show.
        local bosses = JOURNALENCOUNTER[id]
        if not bosses or #bosses == 0 then return false end
        return EntryFor(list, difficulty) ~= nil
    end

    local origGetValidationDifficulty = EJ_GetValidationDifficulty
    function EJ_GetValidationDifficulty(index, instanceID)
        local list = ListFor(instanceID)
        if not list then return origGetValidationDifficulty(index, instanceID) end
        if not index then return nil end

        local buffer = {}
        for i = 1, #list do
            if EJ_IsValidInstanceDifficulty(list[i].difficultyID, instanceID) then
                buffer[#buffer + 1] = list[i].difficultyID
            end
        end
        return buffer[index]
    end

    local origUpdateDifficulty = EncounterJournal_UpdateDifficulty
    function EncounterJournal_UpdateDifficulty(newDifficultyID)
        local list = ListFor()
        if not list then return origUpdateDifficulty(newDifficultyID) end

        local entry = EntryFor(list, newDifficultyID)
        if not entry or not EJ_IsValidInstanceDifficulty(entry.difficultyID) then return end

        EncounterJournal.encounter.info.difficulty:SetText(entry.label)
        EncounterJournal_Refresh()
    end

    local origDifficultyInit = EncounterJournal_DifficultyInit
    function EncounterJournal_DifficultyInit(self, level)
        local list = ListFor()
        if not list then return origDifficultyInit(self, level) end

        local current = EJ_GetDifficulty()
        local info = UIDropDownMenu_CreateInfo()
        for i = 1, #list do
            local entry = list[i]
            if EJ_IsValidInstanceDifficulty(entry.difficultyID) then
                info.func = EncounterJournal_SelectDifficulty
                info.text = entry.label
                info.arg1 = entry.difficultyID
                info.checked = current == entry.difficultyID
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end
end

-- --- keep the selected difficulty inside the instance's own set -------
--
-- Walking from a 25-Heroic raid (difficultyID 4) into Timbermaw Hold, which
-- only defines 1..3, would otherwise leave the selector showing the previous
-- instance's label: EncounterJournal_UpdateDifficulty finds no matching entry
-- and returns without touching the text.

if EncounterJournal_DisplayInstance and not DCJournal_DifficultyClampHooked then
    DCJournal_DifficultyClampHooked = true

    local clamping = false
    local origDisplayInstance = EncounterJournal_DisplayInstance
    function EncounterJournal_DisplayInstance(instanceID, noButton)
        origDisplayInstance(instanceID, noButton)

        -- EJ_SetDifficulty below refreshes, which re-enters this function once.
        if clamping then return end

        local list = ListFor(instanceID)
        if not list then return end
        if EntryFor(list, EJ_GetDifficulty()) then return end

        clamping = true
        EJ_SetDifficulty(list[1].difficultyID)
        clamping = false
    end
end
