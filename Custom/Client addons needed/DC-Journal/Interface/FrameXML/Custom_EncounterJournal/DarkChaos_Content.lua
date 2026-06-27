-- =====================================================================
--  DarkChaos_Content.lua
--  Dark Chaos custom Encounter Journal content & overrides.
--
--  THIS is the place to add Dark Chaos dungeons, raids, bosses, abilities
--  and loot. It loads AFTER the (translated, Blizzard-content) base data,
--  so everything here ADDS TO or OVERRIDES the base tables without editing
--  the upstream files -- keeping re-translation / upstream merges clean.
--
--  Use the DCJournal.* helpers below; scroll to the bottom for a worked
--  example you can copy. Field layouts mirror the base data exactly.
-- =====================================================================

DCJournal = DCJournal or {}

-- Make sure the base tables exist even if load order ever changes.
JOURNALINSTANCE          = JOURNALINSTANCE          or {}
JOURNALENCOUNTER         = JOURNALENCOUNTER         or {}
JOURNALENCOUNTERCREATURE = JOURNALENCOUNTERCREATURE or {}
JOURNALENCOUNTERITEM     = JOURNALENCOUNTERITEM     or {}
JOURNALENCOUNTERSECTION  = JOURNALENCOUNTERSECTION  or {}
JOURNALTIER              = JOURNALTIER              or {}
JOURNALTIERXINSTANCE     = JOURNALTIERXINSTANCE     or {}
EJ_LOOTJOURNAL_DATA      = EJ_LOOTJOURNAL_DATA      or {}

-- Instances shown under the "Open World" content tab (world bosses, etc.),
-- in registration order. Populated by AddInstance({ openWorld = true }).
DCJournal.openWorldInstances = DCJournal.openWorldInstances or {}

local FLAG_INSTANCE_ISRAID         = 16
local FLAG_INSTANCE_HIDE_DIFFICULTY = 64

local function default(v, d)
    if v == nil then return d end
    return v
end

-- Register (or rename) a tier shown in the top-right dropdown.
-- DCJournal.SetTier(80, "Dark Chaos")
function DCJournal.SetTier(tierID, name)
    for _, t in ipairs(JOURNALTIER) do
        if t[1] == tierID then t[2] = name return end
    end
    table.insert(JOURNALTIER, { tierID, name })
end

-- Add (or replace) an instance and map it to a tier.
-- opts = {
--   id, tier, name, lore,
--   buttonIcon, smallIcon, background, loreBackground,   -- texture paths
--   mapID, areaID, worldMapAreaID, order, isRaid, hideDifficulty,
-- }
function DCJournal.AddInstance(opts)
    local flags = 0
    if opts.isRaid then flags = flags + FLAG_INSTANCE_ISRAID end
    if opts.hideDifficulty then flags = flags + FLAG_INSTANCE_HIDE_DIFFICULTY end

    JOURNALINSTANCE[opts.id] = {
        opts.name,                              -- 1  name
        opts.lore or "",                        -- 2  description
        opts.buttonIcon or "",                  -- 3  button icon
        opts.smallIcon or "",                   -- 4  small button icon
        opts.background or "",                  -- 5  background
        opts.loreBackground or "",              -- 6  lore background
        default(opts.mapID, 0),                 -- 7  map id
        default(opts.areaID, 0),                -- 8  area id
        default(opts.order, 0),                 -- 9  order index
        flags,                                  -- 10 flags
        opts.id,                                -- 11 instance id
        default(opts.worldMapAreaID, 0),        -- 12 world map area id
    }
    -- An open-world instance is reached via the "Open World" tab, not a tier,
    -- so it is intentionally NOT added to JOURNALTIERXINSTANCE (keeps it out of
    -- the normal Dungeon/Raid lists).
    if opts.openWorld then
        table.insert(DCJournal.openWorldInstances, opts.id)
    elseif opts.tier then
        JOURNALTIERXINSTANCE[opts.id] = opts.tier
    end
end

-- Add a boss/encounter to an instance.
-- opts = { id, name, lore, firstSectionID, order, mapX, mapY,
--          floorIndex, worldMapAreaID, difficultyMask }
function DCJournal.AddBoss(instanceID, opts)
    JOURNALENCOUNTER[instanceID] = JOURNALENCOUNTER[instanceID] or {}
    table.insert(JOURNALENCOUNTER[instanceID], {
        opts.id,                                -- 1  encounter id
        opts.name,                              -- 2  name
        opts.lore or "",                        -- 3  description
        default(opts.mapX, 0),                  -- 4  map x
        default(opts.mapY, 0),                  -- 5  map y
        default(opts.floorIndex, 0),            -- 6  floor index
        default(opts.worldMapAreaID, 0),        -- 7  world map area id
        default(opts.firstSectionID, 0),        -- 8  first section id
        instanceID,                             -- 9  instance id
        default(opts.difficultyMask, -1),       -- 10 difficulty mask
        0,                                      -- 11 flags
        default(opts.order, #JOURNALENCOUNTER[instanceID] + 1), -- 12 order
    })
end

-- Add the 3D model entry shown on a boss's Model tab.
-- opts = { name, creatureDisplayID, icon, order, id, creatureEntry }
function DCJournal.AddBossModel(encounterID, opts)
    JOURNALENCOUNTERCREATURE[encounterID] = JOURNALENCOUNTERCREATURE[encounterID] or {}
    table.insert(JOURNALENCOUNTERCREATURE[encounterID], {
        opts.name,                              -- 1 name
        opts.subname or "",                     -- 2 (sub)title
        default(opts.creatureDisplayID, 0),     -- 3 creature display id
        opts.icon or "",                        -- 4 icon
        encounterID,                            -- 5 encounter id
        default(opts.order, 0),                 -- 6 order index
        default(opts.id, 0),                    -- 7 id
        default(opts.creatureEntry, 0),         -- 8 creature entry
    })
    -- The 3D model tab resolves a creature ENTRY -> display id via CreaturesCache.
    -- Custom creatures aren't in that cache, so register them here (entry -> display)
    -- or the model preview comes up empty.
    if CreaturesCache and opts.creatureEntry and opts.creatureDisplayID and opts.creatureDisplayID > 0 then
        CreaturesCache[opts.creatureEntry] = CreaturesCache[opts.creatureEntry]
            or { opts.creatureDisplayID, opts.name or "", "" }
    end
end

-- Add an ability/overview section (the entries under Abilities/Overview).
-- opts = { id, name, description, creatureDisplayID, descriptionSpellID,
--          iconSpellID, encounterID, nextSectionID, subSectionID,
--          parentSectionID, flags, iconFlags, order, type, difficultyMask,
--          creatureEntry }
function DCJournal.AddAbility(opts)
    JOURNALENCOUNTERSECTION[opts.id] = {
        opts.id,                                -- 1  section id
        opts.name,                              -- 2  name
        opts.description or "",                 -- 3  description
        default(opts.creatureDisplayID, 0),     -- 4  creature display id
        default(opts.descriptionSpellID, 0),    -- 5  description spell id
        default(opts.iconSpellID, 0),           -- 6  icon spell id
        default(opts.encounterID, 0),           -- 7  encounter id
        default(opts.nextSectionID, 0),         -- 8  next section id
        default(opts.subSectionID, 0),          -- 9  sub section id
        default(opts.parentSectionID, 0),       -- 10 parent section id
        default(opts.flags, 0),                 -- 11 flags
        default(opts.iconFlags, 0),             -- 12 icon flags
        default(opts.order, 0),                 -- 13 order index
        default(opts.type, 2),                  -- 14 type
        default(opts.difficultyMask, -1),       -- 15 difficulty mask
        default(opts.creatureEntry, 0),         -- 16 creature entry
    }
end

-- Add a single loot item dropped by an encounter (shown on the boss Loot tab).
-- opts (optional) = { difficultyMask, factionMask, flags, id, classMask }
function DCJournal.AddLoot(encounterID, itemID, opts)
    opts = opts or {}
    JOURNALENCOUNTERITEM[encounterID] = JOURNALENCOUNTERITEM[encounterID] or {}
    table.insert(JOURNALENCOUNTERITEM[encounterID], {
        itemID,                                 -- 1 item entry
        encounterID,                            -- 2 encounter id
        default(opts.difficultyMask, -1),       -- 3 difficulty mask
        default(opts.factionMask, -1),          -- 4 faction mask
        default(opts.flags, 0),                 -- 5 flags
        default(opts.id, 0),                    -- 6 id
        default(opts.classMask, -1),            -- 7 class mask
    })
end

-- Add an item set to the Loot Journal (the Item Sets browser).
-- opts = { name, itemLevel, tierLabel, source, classID, specFlags,
--          isPVP, items = {itemID, ...}, faction = LOOTJOURNAL_FACTION_* }
function DCJournal.AddLootSet(opts)
    table.insert(EJ_LOOTJOURNAL_DATA, {
        opts.name,                              -- 1 set name
        default(opts.itemLevel, 0),             -- 2 item level
        opts.tierLabel or "",                   -- 3 tier label
        opts.source or "",                      -- 4 source description
        default(opts.classID, 0),               -- 5 class id
        default(opts.specFlags, 0),             -- 6 spec flags
        opts.isPVP and 1 or 0,                  -- 7 isPVP
        opts.items or {},                       -- 8 item ids
        default(opts.faction, LOOTJOURNAL_FACTION_NEUTRAL), -- 9 faction
    })
end

-- Hide / remove an instance from the journal (e.g. an upstream one you don't run).
function DCJournal.RemoveInstance(instanceID)
    JOURNALINSTANCE[instanceID]  = nil
    JOURNALTIERXINSTANCE[instanceID] = nil
    JOURNALENCOUNTER[instanceID] = nil
end

-- =====================================================================
--  Dark Chaos content goes BELOW this line.
--  Uncomment & adapt the example. Use IDs well above Blizzard's range
--  (e.g. 900000+) so they never collide with base content.
-- =====================================================================

-- ---------------------------------------------------------------------
--  Giant Isles -- world bosses (shown under the "Open World" tab)
--  (creature entries / display ids / loot taken from the live DC world DB)
-- ---------------------------------------------------------------------
local GIANT_ISLES = 900100

DCJournal.AddInstance({
    id             = GIANT_ISLES,
    openWorld      = true,
    name           = "Giant Isles",
    lore           = "Off the coast of Northrend lie the Giant Isles, a primordial land where colossal beasts and the resurgent Zandalari empire wage endless war. Mighty world bosses roam its shores -- only the strongest dare hunt them.",
    buttonIcon     = "Interface\\EncounterJournal\\UI-EJ-DUNGEONBUTTON-ZulGurub",
    background     = "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-ZulGurub",
    loreBackground = "Interface\\EncounterJournal\\UI-EJ-LOREBG-ZulGurub",
})

-- enc/sec ids are in the 9001xx/9002xx custom range so they never collide.
local giantIslesBosses = {
    { enc = 900110, sec = 900210, display = 500234, entry = 400100, name = "Oondasta",
      lore = "The colossal devilsaur Oondasta, King of Dinosaurs, rampages across the Giant Isles, devouring all in its path. The Zandalari revere the beast as a living god and rally their warbands beneath its shadow." },
    { enc = 900111, sec = 900211, display = 5291, entry = 400101, name = "Thok the Bloodthirsty",
      lore = "Thok the Bloodthirsty hunts without end, an immense primal devilsaur whose insatiable hunger leaves rivers of blood across the isles. Nothing that draws breath is safe from its jaws." },
    { enc = 900112, sec = 900212, display = 8412, entry = 400102, name = "Nalak the Storm Lord",
      lore = "Nalak, the Storm Lord, an ancient thunder lizard wreathed in crackling lightning, soars above the Giant Isles. The Zandalari worship it as an avatar of the tempest itself." },
    { enc = 900113, sec = 900213, display = 29487, entry = 400350, name = "Ancient Terror",
      lore = "Roused from the black depths beneath the Giant Isles, the Ancient Terror is a primordial horror older than memory. It rises to crush any who would claim the island's primal power." },
    { enc = 900114, sec = 900214, display = 500008, entry = 400360, name = "Vorath the Drowned",
      lore = "Long thought lost beneath the waves, the ancient hydra Vorath the Drowned surges from the surrounding seas, lashing the shoreline with venom and tidal fury to defend its domain." },
    { enc = 900115, sec = 900215, display = 21899, entry = 400338, name = "General Rak'zor",
      lore = "General Rak'zor commands the Zandalari invasion of the Giant Isles -- a ruthless warlord who drives legions of trolls and war-beasts to conquer the islands in the name of his empire." },
    { enc = 900116, sec = 900216, display = 8053, entry = 400522, name = "Reawakened Avatar of Hakkar",
      lore = "Through blood and dark ritual the Zandalari have torn an avatar of Hakkar the Soulflayer into the world. The Blood God hungers without end, and the isles run red with sacrifice in its name." },
}

for order, b in ipairs(giantIslesBosses) do
    DCJournal.AddBoss(GIANT_ISLES, {
        id             = b.enc,
        name           = b.name,
        lore           = b.lore,
        firstSectionID = b.sec,
        order          = order,
    })
    -- a type=3 (overview) section enables the boss Overview tab; the lore itself
    -- is shown from the encounter description above.
    DCJournal.AddAbility({
        id          = b.sec,
        name        = b.name,
        description = "",
        encounterID = b.enc,
        type        = 3,
    })
    DCJournal.AddBossModel(b.enc, {
        name              = b.name,
        creatureDisplayID = b.display,
        creatureEntry     = b.entry,
    })
end

-- Only the Reawakened Avatar of Hakkar has a configured loot table on DC.
DCJournal.AddLoot(900116, 402021)  -- Hakkar's Eternal Seal (epic)
DCJournal.AddLoot(900116, 402016)  -- Talisman of the Blood God (rare)

--[[  Template for adding more (copy & adapt) ---------------------------

-- Use openWorld=true to list under the "Open World" tab (like the Giant Isles),
-- or tier=<existing tier id> to list under a normal expansion in Dungeon/Raid.
DCJournal.AddInstance({ id = 900200, openWorld = true, name = "My World Bosses", lore = "...",
    buttonIcon = "Interface\\EncounterJournal\\UI-EJ-DUNGEONBUTTON-Default",
    background = "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-Default" })
DCJournal.AddBoss(900200, { id = 900201, name = "My Boss", lore = "...", firstSectionID = 900301 })
DCJournal.AddAbility({ id = 900301, name = "Cleave", description = "Hits everyone in front.",
    encounterID = 900201, iconSpellID = 845 })
DCJournal.AddBossModel(900201, { name = "My Boss", creatureDisplayID = 14403, creatureEntry = 12345 })
DCJournal.AddLoot(900201, 19019)
DCJournal.AddLootSet({ name = "My Set", itemLevel = 200, tierLabel = "DC1", source = "Drops from My Boss.",
    classID = 1, items = { 19019 } })

------------------------------------------------------------------- ]]
