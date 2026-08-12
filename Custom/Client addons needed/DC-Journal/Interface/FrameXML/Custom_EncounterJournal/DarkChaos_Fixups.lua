-- =====================================================================
--  DarkChaos_Fixups.lua
--  Two runtime repairs that only show up once custom content is in the
--  journal. Loaded LAST so both wrappers sit on top of everything else.
--
--  1. BOSS PORTRAITS
--     Texture:SetPortrait(displayID) (SharedExtendedMethods.lua) is just
--     SetTexture("Interface\PORTRAITS\Portrait_model_<id>"). Blizzard only
--     ships that .blp for a curated set of display ids, and NO custom DC
--     display id has one -- so the call silently fails and the texture keeps
--     whatever it was showing before. Because the boss buttons are global
--     frames recycled between instances, that meant Crescent Grove rendered
--     Blackfathom Deeps' boss art, and the first instance opened in a session
--     rendered the template's red "?".
--
--     Fixed by resetting to a known-good texture BEFORE attempting the
--     portrait (so a miss can never inherit stale art), and then, when the
--     portrait genuinely did not load, putting a live 3D model of the creature
--     in the medallion instead. Bosses that do have hand-made UI-EJ-BOSS-*
--     art never reach this path and are untouched.
--
--  2. LOOT THAT ARRIVES LATE
--     EJ_BuildLootData drops any item whose GetItemInfo() is still nil, and
--     custom items are not in the 3.3.5 client's item DB -- the client has to
--     ask the server for them, which does not finish before the loot list is
--     built. Nothing ever rebuilt the list afterwards, so a fresh session
--     showed an empty Loot tab for every custom instance.
--
--     Fixed by priming every loot id of the instance being opened, filling the
--     journal's own row cache the moment each answer lands, and forcing the
--     loot list to rebuild.
-- =====================================================================

DCJournal = DCJournal or {}

local FALLBACK_ICON  = "Interface\\EncounterJournal\\UI-EJ-BOSS-Default"
local PORTRAIT_PATH  = "Interface\\PORTRAITS\\Portrait_model_"

-- Model framing knobs, kept together so they are easy to retune in-game.
-- SetCamera(0) is the head close-up on this client (see the note in
-- DC-Collection/UI/PetJournalFrame.lua, which avoids it for exactly that
-- reason) -- which is what a medallion portrait wants.
local MODEL_CAMERA     = 0

-- UI-EJ-BOSS-*.blp are 128x64 banners; Interface\PORTRAITS\Portrait_model_*.blp
-- are 64x64 squares. Anything wider than this ratio is a banner.
local MODEL_WIDE_RATIO = 1.5

-- The banner art is mostly transparent: the creature only occupies the torn
-- medallion at its left, roughly 82x48 of the 128x64. These insets put the model
-- in that medallion instead of stretching it across the whole strip.
local BANNER_INSET = { left = 4, right = 42, top = 8, bottom = 8 }

-- ---------------------------------------------------------------------
--  1. Boss portraits
-- ---------------------------------------------------------------------

local models = setmetatable({}, { __mode = "k" })

local function IsWideBanner(texture)
    local w, h = texture:GetWidth() or 0, texture:GetHeight() or 0
    return w > 0 and h > 0 and (w / h) > MODEL_WIDE_RATIO
end

local function HideModel(texture)
    local model = models[texture]
    if model then model:Hide() end
end

local function ShowModel(texture, displayID)
    local model = models[texture]
    if not model then
        local parent = texture:GetParent()
        if not parent then return end

        local ok, created = pcall(CreateFrame, "PlayerModel", nil, parent)
        if not ok or not created then return end
        model = created

        -- Above the medallion art, which stays as the frame behind the model.
        if parent.GetFrameLevel then
            model:SetFrameLevel(parent:GetFrameLevel() + 5)
        end

        if IsWideBanner(texture) then
            model:SetPoint("TOPLEFT", texture, "TOPLEFT", BANNER_INSET.left, -BANNER_INSET.top)
            model:SetPoint("BOTTOMRIGHT", texture, "BOTTOMRIGHT", -BANNER_INSET.right, BANNER_INSET.bottom)
        else
            model:SetAllPoints(texture)
        end

        -- A model frame loses its content when it is hidden and shown again
        -- (the boss buttons are hidden wholesale by EncounterJournal_ClearDetails),
        -- so re-apply on show rather than relying on the next SetPortrait call.
        model:SetScript("OnShow", function(self)
            if self.dcDisplayID then
                pcall(self.SetCreature, self, self.dcDisplayID)
                if self.SetCamera then pcall(self.SetCamera, self, MODEL_CAMERA) end
            end
        end)

        models[texture] = model
    end

    model.dcDisplayID = displayID

    if model.ClearModel then pcall(model.ClearModel, model) end
    if model.SetCreature then
        local ok = pcall(model.SetCreature, model, displayID)
        if not ok then
            model:Hide()
            return
        end
    end
    if model.SetCamera then pcall(model.SetCamera, model, MODEL_CAMERA) end
    if model.SetPosition then pcall(model.SetPosition, model, 0, 0, 0) end
    if model.SetFacing then pcall(model.SetFacing, model, 0) end

    model:Show()
end

-- Whether Portrait_model_<id>.blp actually loaded. SetTexture's return value is
-- checked first, and GetTexture() second: a failed load leaves the previously
-- set path in place, which is exactly the stale-art symptom this file exists
-- for, so the path not having changed is itself the "did not load" signal.
local function PortraitLoaded(texture, displayID)
    local path = PORTRAIT_PATH .. displayID
    local returned = texture:SetTexture(path)
    if returned then return true end

    local current = texture:GetTexture()
    if type(current) ~= "string" then return false end
    return string.find(string.lower(current), string.lower("Portrait_model_" .. displayID), 1, true) ~= nil
end

local function DCSetPortrait(texture, displayID)
    displayID = tonumber(displayID) or 0

    -- Reset first: without this a missing portrait keeps the previous boss.
    texture:SetTexture(FALLBACK_ICON)

    if displayID <= 0 then
        HideModel(texture)
        return
    end

    if IsWideBanner(texture) then
        -- A boss-button banner. Even when Portrait_model_<id>.blp exists it is a
        -- 64x64 square, so dropping it in here stretches it to twice its width --
        -- which is what made Old Serra'kis render as a smeared green blur. Always
        -- render the creature instead, over the default medallion frame.
        ShowModel(texture, displayID)
        return
    end

    if PortraitLoaded(texture, displayID) then
        HideModel(texture)
    else
        -- No portrait art for this display id. Restore the medallion frame and
        -- render the creature itself over it.
        texture:SetTexture(FALLBACK_ICON)
        ShowModel(texture, displayID)
    end
end

if not DCJournal_PortraitHooked then
    -- SetPortrait is installed on the Texture metatable, so replacing it there
    -- covers every call site at once: boss buttons, the Model tab's creature
    -- list, ability header portraits and search results.
    local probe = UIParent:CreateTexture(nil, "ARTWORK")
    local mt = getmetatable(probe)
    if mt and mt.__index and mt.__index.SetPortrait then
        DCJournal_PortraitHooked = true
        mt.__index.SetPortrait = DCSetPortrait
    end
end

-- ---------------------------------------------------------------------
--  2. Loot that arrives late
-- ---------------------------------------------------------------------

-- Mirrors the field order EncounterJournal_OnLoad writes onto a loot row.
-- Filling these here matters beyond making the item show up at all:
-- EJ_BuildLootData only stores `equipLoc` when it resolves an item lazily,
-- while everything downstream reads `equipSlot`, so a lazily-resolved item
-- would list with no slot label and sort to the bottom.
local function FillLootRow(row)
    if row.name then return true end

    local name, link, quality, iLevel, reqLevel, armorType, subclass, maxStack, equipSlot, icon, vendorPrice
        = EJ_GetItemInfo(row[1])
    if not name then return false end

    row.name, row.link, row.quality, row.iLevel, row.reqLevel = name, link, quality, iLevel, reqLevel
    row.armorType, row.subclass, row.maxStack = armorType, subclass, maxStack
    row.equipSlot, row.equipLoc, row.icon, row.vendorPrice = equipSlot, equipSlot, icon, vendorPrice
    return true
end

-- EJ_BuildLootData skips its rebuild while the boss list is the same TABLE it
-- built from last time, so newly resolved items would not appear until the
-- player clicked away. Swapping in a copy is enough to invalidate it without
-- reaching into the upstream file's locals.
local function InvalidateLootBuffer()
    local list = EncounterJournal and EncounterJournal.encounterList
    if type(list) ~= "table" then return end

    local copy = {}
    for i = 1, #list do copy[i] = list[i] end
    EncounterJournal.encounterList = copy
end

-- Resolve every loot row of the given encounters; returns true while any row is
-- still unresolved (the client is still waiting on the server for it).
local function PrimeLoot(encounterIDs)
    local waiting = false
    for _, encID in ipairs(encounterIDs) do
        local rows = JOURNALENCOUNTERITEM[encID]
        if rows then
            for i = 1, #rows do
                if not FillLootRow(rows[i]) then waiting = true end
            end
        end
    end
    return waiting
end

local function EncountersOf(instanceID)
    local out = {}
    for _, e in ipairs(JOURNALENCOUNTER[instanceID] or {}) do out[#out + 1] = e[1] end
    return out
end

local refreshQueued = false
local function RefreshLoot()
    refreshQueued = false
    if not (EncounterJournal and EncounterJournal:IsShown()) then return end
    InvalidateLootBuffer()
    if EncounterJournal_LootUpdate then EncounterJournal_LootUpdate() end
end

local function QueueRefresh(delay)
    if refreshQueued then return end
    refreshQueued = true
    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0.2, RefreshLoot)
    else
        RefreshLoot()
    end
end

-- Prime, then re-check on a short ladder. GET_ITEM_INFO_RECEIVED covers the
-- normal case; the ladder is the belt-and-braces path for clients that do not
-- fire it, and stops as soon as everything has resolved.
local function PrimeAndWatch(encounterIDs, attempt)
    attempt = attempt or 1
    local waiting = PrimeLoot(encounterIDs)
    QueueRefresh(0.1)

    if waiting and attempt < 6 and C_Timer and C_Timer.After then
        C_Timer.After(attempt * 0.5, function() PrimeAndWatch(encounterIDs, attempt + 1) end)
    end
end

if EncounterJournal_DisplayInstance and not DCJournal_LootPrimeHooked then
    DCJournal_LootPrimeHooked = true

    local origDisplayInstance = EncounterJournal_DisplayInstance
    function EncounterJournal_DisplayInstance(instanceID, noButton)
        origDisplayInstance(instanceID, noButton)
        if instanceID then PrimeAndWatch(EncountersOf(instanceID)) end
    end

    local origDisplayEncounter = EncounterJournal_DisplayEncounter
    function EncounterJournal_DisplayEncounter(encounterID, noButton)
        origDisplayEncounter(encounterID, noButton)
        if encounterID and encounterID ~= -1 then PrimeAndWatch({ encounterID }) end
    end
end

-- ---------------------------------------------------------------------
--  3. The loot list defaulting to the player's own class
--
--  EJ_GetLootFilter was already patched upstream of here to default to
--  NO_CLASS_FILTER, with a comment noting that filtering by the player's class
--  made dungeons look like they were "missing loot". EJ_ResetLootFilter then
--  set it straight back to the player's class -- and it runs from
--  EncounterJournal_DisplayInstance, so every instance page re-applied the
--  filter and defeated that fix. Reset means reset; the class dropdown still
--  applies a filter on demand.
-- ---------------------------------------------------------------------

if EJ_ResetLootFilter and not DCJournal_LootFilterHooked then
    DCJournal_LootFilterHooked = true
    function EJ_ResetLootFilter()
        EJ_SetLootFilter(0)   -- NO_CLASS_FILTER
        if EncounterJournal_UpdateFilterString then
            EncounterJournal_UpdateFilterString()
        end
    end
end

local watcher = CreateFrame("Frame")
pcall(watcher.RegisterEvent, watcher, "GET_ITEM_INFO_RECEIVED")
watcher:SetScript("OnEvent", function()
    if not (EncounterJournal and EncounterJournal:IsShown()) then return end

    local ids
    if EncounterJournal.encounterID then
        ids = { EncounterJournal.encounterID }
    elseif EncounterJournal.instanceID then
        ids = EncountersOf(EncounterJournal.instanceID)
    end
    if not ids then return end

    PrimeLoot(ids)
    QueueRefresh(0.2)
end)
