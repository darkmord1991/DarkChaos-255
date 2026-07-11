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
-- `icon` (where a hand-made .blp exists in the client patch) is set explicitly
-- because the fallback path -- Texture:SetPortrait(displayID), which just loads
-- a static "Interface\PORTRAITS\Portrait_model_<id>.blp" -- only has art for a
-- curated set of ids; it silently shows blank/mismatched art for the custom
-- creature ids used here (see boss-list icon investigation, 2026-07-11).
local giantIslesBosses = {
    { enc = 900110, sec = 900210, display = 500234, entry = 400100, name = "Oondasta", icon = "Oondasta",
      lore = "The colossal devilsaur Oondasta, King of Dinosaurs, rampages across the Giant Isles, devouring all in its path. The Zandalari revere the beast as a living god and rally their warbands beneath its shadow." },
    { enc = 900111, sec = 900211, display = 5291, entry = 400101, name = "Thok the Bloodthirsty", icon = "Thok the Bloodthirsty",
      lore = "Thok the Bloodthirsty hunts without end, an immense primal devilsaur whose insatiable hunger leaves rivers of blood across the isles. Nothing that draws breath is safe from its jaws." },
    { enc = 900112, sec = 900212, display = 8412, entry = 400102, name = "Nalak the Storm Lord", icon = "Nalak",
      lore = "Nalak, the Storm Lord, an ancient thunder lizard wreathed in crackling lightning, soars above the Giant Isles. The Zandalari worship it as an avatar of the tempest itself." },
    { enc = 900113, sec = 900213, display = 29487, entry = 400350, name = "Ancient Terror",
      lore = "Roused from the black depths beneath the Giant Isles, the Ancient Terror is a primordial horror older than memory. It rises to crush any who would claim the island's primal power." },
    { enc = 900114, sec = 900214, display = 500008, entry = 400360, name = "Vorath the Drowned",
      lore = "Long thought lost beneath the waves, the ancient hydra Vorath the Drowned surges from the surrounding seas, lashing the shoreline with venom and tidal fury to defend its domain." },
    { enc = 900115, sec = 900215, display = 21899, entry = 400338, name = "General Rak'zor",
      lore = "General Rak'zor commands the Zandalari invasion of the Giant Isles -- a ruthless warlord who drives legions of trolls and war-beasts to conquer the islands in the name of his empire." },
    { enc = 900116, sec = 900216, display = 8053, entry = 400522, name = "Reawakened Avatar of Hakkar", icon = "Avatar of Hakkar",
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
        icon              = b.icon and ("Interface\\EncounterJournal\\UI-EJ-BOSS-" .. b.icon) or nil,
    })
end

-- Only the Reawakened Avatar of Hakkar has a configured loot table on DC.
DCJournal.AddLoot(900116, 402021)  -- Hakkar's Eternal Seal (epic)
DCJournal.AddLoot(900116, 402016)  -- Talisman of the Blood God (rare)

-- ---------------------------------------------------------------------
--  Blackwing Descent -- Cataclysm raid downport (map 669). Listed under
--  its own "Dark Chaos" raid tier (id 80) since it isn't Blizzard's
--  Classic/BC/WotLK content. Bosses, abilities, and loot below are taken
--  from the live ported C++ AI (src/server/scripts/DC/BlackwingDescent/)
--  and the applied world DB (creature_template / reference_loot_template),
--  not generic retail trivia.
-- ---------------------------------------------------------------------
DCJournal.SetTier(80, "Dark Chaos")

local BLACKWING_DESCENT = 900300

DCJournal.AddInstance({
    id             = BLACKWING_DESCENT,
    tier           = 80,
    isRaid         = true,
    name           = "Blackwing Descent",
    lore           = "Deep beneath Blackrock Mountain, Nefarian -- eldest son of Deathwing -- has returned to carry on the twisted work of his father's ally, the Twilight's Hammer cult. In the ruins of his old lair he forges an army of aberrations and reanimated dragonflesh, guarded by golem constructs and the elemental horror Magmaw, while his sister Onyxia stands ready at his side.",
    buttonIcon     = "Interface\\EncounterJournal\\UI-EJ-DUNGEONBUTTON-BlackwingDescent",
    smallIcon      = "Interface\\LFGFRAME\\LFGICON-BlackwingDescentRaid",
    background     = "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-BlackwingDescent",
    loreBackground = "Interface\\EncounterJournal\\UI-EJ-LOREBG-BlackwingDescent",
    mapID          = 669,
    areaID         = 5788,
    worldMapAreaID = 1220,
    order          = 1,
})

-- Wires a boss's root "Overview" section (type=0 with its creature model
-- attached -- mirrors how the base WotLK bosses like Lord Marrowgar are
-- wired) plus a flat chain of ability sections. `abilities` is a list of
-- { name, description, iconSpellID }.
local function AddBWDBoss(encID, rootID, order, name, encLore, overview, display, entry, abilities)
    DCJournal.AddBoss(BLACKWING_DESCENT, {
        id             = encID,
        name           = name,
        lore           = encLore,
        firstSectionID = rootID,
        order          = order,
        worldMapAreaID = 1220,
    })
    DCJournal.AddAbility({
        id                = rootID,
        name              = name,
        description       = overview,
        creatureDisplayID = display,
        creatureEntry     = entry,
        encounterID       = encID,
        subSectionID      = rootID + 1,
        flags             = 1,
        order             = 1,
        type              = 0,
    })
    for i, a in ipairs(abilities) do
        DCJournal.AddAbility({
            id              = rootID + i,
            name            = a[1],
            description     = a[2],
            iconSpellID     = a[3] or 0,
            encounterID     = encID,
            parentSectionID = rootID,
            nextSectionID   = (i < #abilities) and (rootID + i + 1) or 0,
            order           = i,
            type            = 2,
        })
    end
    DCJournal.AddBossModel(encID, {
        name = name, creatureDisplayID = display, creatureEntry = entry,
        icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-" .. name,
    })
end

-- ---------------------------------------------------------------------
--  1. Magmaw (entry 41570) -- chained elemental worm, first line of defense
-- ---------------------------------------------------------------------
AddBWDBoss(900301, 900310, 1, "Magmaw",
    "Chained beneath the mountain by the black dragonflight, Magmaw is a colossal elemental worm driven into a permanent, mindless rage. It cannot leave its tether, but drags careless raiders into the molten rock below with its jaws, and only surfaces its vulnerable head when the raid mounts its exposed pincers and drives grappling hooks into the stone beneath it.",
    "Magmaw is a chained elemental worm and the first line of defense in Blackwing Descent.",
    32679, 41570,
    {
        { "Mangle", "Seizes a random player in its jaws and chews them for heavy repeating damage until they escape, weakening the victim's armor with Sweltering Armor.", 89773 },
        { "Massive Crash", "Moments after a Mangle, Magmaw slams onto its back, exposing its pincers so raiders can mount up and fire grappling hooks into the floor.", 88253 },
        { "Impale Self", "Once both hooks are set, Magmaw impales itself on the spikes below, exposing its head as a separate, highly vulnerable target for a short burst window.", 77907 },
        { "Magma Spit", "Spits molten rock at several random players every few seconds; if nothing is holding it in melee, it empowers itself with Molten Tantrum instead.", 78359 },
        { "Lava Spew", "A frontal breath that scorches nearby players every couple of seconds.", 77839 },
        { "Pillar of Flame", "Drops a burning pillar beneath a player standing at range, scorching the ground and heralding a fresh wave of Lava Parasites.", 77998 },
        { "Parasitic Infection", "Lava Parasites crawl from the surrounding magma to latch onto random players, inflicting an escalating wound that must be cleansed or killed off.", 77969 },
    })

DCJournal.AddLoot(900301, 59329)  -- Parasitic Bands
DCJournal.AddLoot(900301, 59328)  -- Molten Tantrum Boots
DCJournal.AddLoot(900301, 59492)  -- Akirus the Worm-Breaker
DCJournal.AddLoot(900301, 59452)  -- Crown of Burning Waters
DCJournal.AddLoot(900301, 59341)  -- Incineratus
DCJournal.AddLoot(900301, 59340)  -- Breastplate of Avenging Flame
DCJournal.AddLoot(900301, 59336)  -- Flame Pillar Leggings
DCJournal.AddLoot(900301, 59335)  -- Scorched Wormling Vest
DCJournal.AddLoot(900301, 59334)  -- Lifecycle Waistguard
DCJournal.AddLoot(900301, 59333)  -- Lava Spine
DCJournal.AddLoot(900301, 59332)  -- Symbiotic Worm
DCJournal.AddLoot(900301, 59331)  -- Leggings of Lethal Force

-- ---------------------------------------------------------------------
--  2. Omnotron Defense System -- 4 golems sharing one health pool; only
--     one is ever active while the rest recharge (entry 42186 is an
--     inert, non-combat controller and isn't fought directly)
-- ---------------------------------------------------------------------
DCJournal.AddBoss(BLACKWING_DESCENT, {
    id             = 900302,
    name           = "Omnotron Defense System",
    lore           = "Four ancient golem constructs -- Electron, Magmatron, Toxitron, and Arcanotron -- stand sentinel over the vault beneath Blackwing Descent. Only one ever wakes at a time, sharing a single reservoir of power between them, but a raid too slow to bring one down will find the rest recharging into the fight as well.",
    firstSectionID = 900330,
    order          = 2,
    worldMapAreaID = 1220,
})
DCJournal.AddAbility({
    id = 900330, name = "Omnotron Defense System",
    description = "The Omnotron Defense System is a ring of four golem constructs guarding the vault of Blackwing Descent.",
    encounterID = 900302, subSectionID = 900331, flags = 1, order = 1, type = 0,
})

local omnotronGolems = {
    { header = 900331, name = "Electron", entry = 42179, display = 32688,
      blurb = "A crackling construct that punishes players for standing too close together.",
      abilities = {
          { "Lightning Conductor", "Marks a random player with a debuff that pulses periodically, damaging them and anyone standing too close.", 79888 },
          { "Electrical Discharge", "Chain lightning that jumps between nearby players, growing stronger with each jump -- spread out to limit the chain.", 79879 },
          { "Unstable Shield", "Raises a shield that reflects Nature damage back onto anyone who keeps meleeing it -- stop attacking while it's up.", 79900 },
      } },
    { header = 900335, name = "Magmatron", entry = 42178, display = 32685,
      blurb = "A construct built around a devastating frontal flame cone and a channeled targeted blast.",
      abilities = {
          { "Acquiring Target", "Plants its feet and locks onto a random player with a channeled blast -- move away before it completes.", 79499 },
          { "Incineration Security Measure", "A recurring flame cone from its front -- stay out of its firing arc.", 79023 },
          { "Barrier", "Raises a damage-absorbing barrier; breaking it early empowers Magmatron with Backdraft, so bursting it down is a trade-off, not a free win.", 79582 },
      } },
    { header = 900339, name = "Toxitron", entry = 42180, display = 32684,
      blurb = "A construct that fixates poison bombs and lingering toxic clouds on the raid.",
      abilities = {
          { "Chemical Bomb", "Marks a random player and summons a Poison Bomb that fixates on them before bursting into a lingering poison cloud.", 80157 },
          { "Poison Protocol", "Periodically vents a self-centered poison cloud while channeling -- melee should step out at intervals.", 80053 },
          { "Poison Soaked Shell", "A shield phase that poisons anyone who keeps meleeing it, rather than reflecting damage outright.", 79835 },
      } },
    { header = 900343, name = "Arcanotron", entry = 42166, display = 32687,
      blurb = "A construct that lashes out with arcane blasts and summons power generators for the raid to destroy.",
      abilities = {
          { "Power Generator", "Regularly summons a stationary Power Generator that the raid must deal with before it overcharges.", 79624 },
          { "Arcane Annihilation", "Blasts a random player (or the whole raid at 25-plus players) with direct Arcane damage every few seconds.", 79710 },
          { "Power Conversion", "A shield phase identical in spirit to the other golems' -- melee should disengage while it's active.", 79729 },
      } },
}

for i, golem in ipairs(omnotronGolems) do
    local nextHeader = omnotronGolems[i + 1] and omnotronGolems[i + 1].header or 0
    DCJournal.AddAbility({
        id = golem.header, name = golem.name, description = golem.blurb,
        creatureDisplayID = golem.display, creatureEntry = golem.entry,
        encounterID = 900302, parentSectionID = 900330, subSectionID = golem.header + 1,
        nextSectionID = nextHeader, order = i, type = 2,
    })
    for j, a in ipairs(golem.abilities) do
        DCJournal.AddAbility({
            id = golem.header + j, name = a[1], description = a[2], iconSpellID = a[3] or 0,
            encounterID = 900302, parentSectionID = golem.header,
            nextSectionID = (j < #golem.abilities) and (golem.header + j + 1) or 0,
            order = j, type = 2,
        })
    end
    DCJournal.AddBossModel(900302, {
        name = golem.name, creatureDisplayID = golem.display, creatureEntry = golem.entry,
        icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-" .. golem.name,
    })
end

DCJournal.AddLoot(900302, 59219)  -- Power Generator Hood
DCJournal.AddLoot(900302, 63540)  -- Circuit Design Breastplate
DCJournal.AddLoot(900302, 59220)  -- Security Measure Alpha
DCJournal.AddLoot(900302, 59218)  -- Passive Resistor Spaulders
DCJournal.AddLoot(900302, 59217)  -- X-Tron Duct Tape
DCJournal.AddLoot(900302, 59216)  -- Life Force Chargers
DCJournal.AddLoot(900302, 59121)  -- Lightning Conductor Band
DCJournal.AddLoot(900302, 59120)  -- Poison Protocol Pauldrons
DCJournal.AddLoot(900302, 59117)  -- Jumbotron Power Belt
DCJournal.AddLoot(900302, 59119)  -- Voltage Source Chestguard
DCJournal.AddLoot(900302, 59118)  -- Electron Inductor Coils
DCJournal.AddLoot(900302, 59122)  -- Organic Lifeform Inverter

-- ---------------------------------------------------------------------
--  3. Maloriak (entry 41378) -- Nefarian's alchemist
-- ---------------------------------------------------------------------
AddBWDBoss(900303, 900350, 3, "Maloriak",
    "Maloriak, one of Nefarian's most devoted lieutenants, brews mutagenic elixirs in his lab to further his master's work. He drinks down Fire, Frost, and Slime concoctions in turn, wielding each one's power against the raid, before combining all three into a single volatile transformation.",
    "Maloriak is Nefarian's alchemist, mutating himself and his creations in the depths of Blackwing Descent.",
    33186, 41378,
    {
        { "Consuming Flames", "During the Fire-Imbued phase, burns a random player with a wound that grows stronger the more additional magic damage they take.", 77786 },
        { "Flash Freeze", "During the Frost-Imbued phase, encases a random player in ice, stunning them until the raid destroys the block, which shatters for damage on anyone standing close.", 77716 },
        { "Debilitating Slime", "Throws a Green Bottle into his cauldron, which erupts to knock back nearby players and coat the room in a lingering slime debuff.", 77602 },
        { "Release Aberrations", "Periodically frees caged Aberrations from the room's growth chambers to join the fight.", 77569 },
        { "Release All Minions", "At 25% health, Maloriak dumps every remaining caged creature into the fight at once before transforming.", 77991 },
        { "Magma Jets", "In his final phase, burns a spreading line of fire along his current target's facing -- the tank should keep him turned away from the raid.", 93022 },
        { "Acid Nova", "A raid-wide burst of damage roughly every 20 seconds during his final phase.", 78225 },
        { "Absolute Zero", "Chills a random player and spawns a wandering ice creature that explodes if it drifts near anyone.", 78206 },
    })

DCJournal.AddLoot(900303, 59349)  -- Belt of Arcane Storms
DCJournal.AddLoot(900303, 59354)  -- Jar of Ancient Remedies
DCJournal.AddLoot(900303, 59353)  -- Leggings of Consuming Flames
DCJournal.AddLoot(900303, 59352)  -- Flash Freeze Gauntlets
DCJournal.AddLoot(900303, 59351)  -- Legwraps of the Greatest Son
DCJournal.AddLoot(900303, 59350)  -- Treads of Flawless Creation
DCJournal.AddLoot(900303, 59348)  -- Cloak of Biting Chill
DCJournal.AddLoot(900303, 59347)  -- Mace of Acrid Death
DCJournal.AddLoot(900303, 59346)  -- Tunic of Failed Experiments
DCJournal.AddLoot(900303, 59344)  -- Dragon Bone Warhelm
DCJournal.AddLoot(900303, 59343)  -- Aberration's Leggings
DCJournal.AddLoot(900303, 59342)  -- Belt of Absolute Zero

-- ---------------------------------------------------------------------
--  4. Atramedes (entry 41442) -- blind dragon who hunts by sound
-- ---------------------------------------------------------------------
AddBWDBoss(900304, 900370, 4, "Atramedes",
    "Blinded long ago, the black dragon Atramedes now hunts entirely by sound, guarding the Athenaeum with an ever-rising cacophony of his own making. The louder the raid becomes, the more dearly it pays -- though the ancient dwarven shield statues scattered through his lair offer a dangerous chance to silence him.",
    "Atramedes is a blind black dragon who hunts the raid by sound alone.",
    34547, 41442,
    {
        { "Sonar Pulse", "A raid-wide detection pulse that raises every player's Sound level -- the higher it climbs, the more the raid suffers.", 77672 },
        { "Modulation", "Strikes all players for damage that scales with each player's own current Sound level -- staying quiet keeps this hit small.", 77612 },
        { "Noisy!", "Tags a player who has maxed their Sound level, which switches on Atramedes's raid-wide Devastation damage tick until the debuff is cleared.", 78897 },
        { "Searing Flame", "Atramedes plants himself and channels a rapid flame breath for several seconds, then accelerates his next Modulation.", 77840 },
        { "Sonic Breath", "A breath attack aimed at a random player other than the tank, who should move away from the raid before it lands.", 78075 },
        { "Resonating Clash", "Spell-clicking an Ancient Dwarven Shield slams this into Atramedes, stunning him with Vertigo and clearing the clicker's Sound -- but he lashes out with Sonic Flames the moment the stun ends.", 77611 },
        { "Roaring Flame Breath", "Roughly every 90 seconds Atramedes takes to the air and rains a chasing flame breath below, burning anyone caught in its landing zone or spawning a pursuing fire elemental if it misses.", 78221 },
    })

DCJournal.AddLoot(900304, 59312)  -- Helm of the Blind Seer
DCJournal.AddLoot(900304, 59327)  -- Kingdom's Heart
DCJournal.AddLoot(900304, 59326)  -- Bell of Enraging Resonance
DCJournal.AddLoot(900304, 59325)  -- Mantle of Roaring Flames
DCJournal.AddLoot(900304, 59324)  -- Gloves of Cacophony
DCJournal.AddLoot(900304, 59322)  -- Bracers of the Burningeye
DCJournal.AddLoot(900304, 59319)  -- Ironstar Amulet
DCJournal.AddLoot(900304, 59318)  -- Sark of the Unwatched
DCJournal.AddLoot(900304, 59317)  -- Legguards of the Unseeing
DCJournal.AddLoot(900304, 59316)  -- Battleplate of Ancient Kings
DCJournal.AddLoot(900304, 59315)  -- Boots of Vertigo
DCJournal.AddLoot(900304, 59320)  -- Themios the Darkbringer

-- ---------------------------------------------------------------------
--  5. Chimaeron (entry 43296) -- Nefarian's failed experiment
-- ---------------------------------------------------------------------
AddBWDBoss(900305, 900390, 5, "Chimaeron",
    "Chimaeron is Nefarian's grotesque, half-dead experiment, held together and sustained past its natural limits by the construct Bile-O-Tron 800. Freeing the caged Finkle Einhorn wakes them both -- and only knocking the construct offline lets the raid finish what nature never could.",
    "Chimaeron is a failed experiment of Nefarian's, kept alive by the construct Bile-O-Tron 800.",
    33308, 43296,
    {
        { "Break", "A devastating hit on Chimaeron's current target every 15 seconds or so -- the tank must be topped off before it lands.", 82881 },
        { "Double Attack", "A self-buff that lets Chimaeron's melee occasionally land a second hit; reapplied roughly every 15 seconds.", 88826 },
        { "Caustic Slime", "Seeds lingering damage pools beneath several random players every few seconds -- move off old pools and away from the tank.", 82871 },
        { "Massacre", "A raid-wide hit roughly every 30 seconds that resets his swing timer and has a rising chance to knock Bile-O-Tron 800 offline.", 82848 },
        { "Finkle's Mixture", "A shield from Bile-O-Tron 800 that keeps Chimaeron's health from dropping below a fixed floor for as long as the construct stays online.", 82705 },
        { "Feud", "While Bile-O-Tron 800 repairs itself after being knocked offline, Chimaeron is pacified for about 26 seconds -- the only window to push his health past the floor.", 88872 },
        { "Mortality", "At 20% health, Chimaeron permanently enters a harder-hitting finishing phase with Double Attack continuously active.", 82890 },
    })

DCJournal.AddLoot(900305, 59314)  -- Pip's Solution Agitator
DCJournal.AddLoot(900305, 59451)  -- Manacles of the Sleeping Beast
DCJournal.AddLoot(900305, 59355)  -- Chimaeron Armguards
DCJournal.AddLoot(900305, 59313)  -- Brackish Gloves
DCJournal.AddLoot(900305, 59311)  -- Burden of Mortality
DCJournal.AddLoot(900305, 59310)  -- Chaos Beast Bracers
DCJournal.AddLoot(900305, 59233)  -- Bile-O-Tron Nut
DCJournal.AddLoot(900305, 59225)  -- Plated Fists of Provocation
DCJournal.AddLoot(900305, 59224)  -- Heart of Rage
DCJournal.AddLoot(900305, 59223)  -- Double Attack Handguards
DCJournal.AddLoot(900305, 59221)  -- Massacre Treads
DCJournal.AddLoot(900305, 59234)  -- Quickstep Galoshes

-- ---------------------------------------------------------------------
--  6. Nefarian's End -- Onyxia (entry 41270) then Nefarian (entry 41376);
--     Lord Victor Nefarius (41379) only taunts from the sidelines and
--     never joins combat.
-- ---------------------------------------------------------------------
DCJournal.AddBoss(BLACKWING_DESCENT, {
    id             = 900306,
    name           = "Nefarian's End",
    lore           = "Lord Victor Nefarius taunts the raid from above as Nefarian, eldest son of Deathwing, is revealed at last. He wakes his sister Onyxia to test the raid before joining the fight in person, and if he survives their combined assault, lands to finish it alone.",
    firstSectionID = 900420,
    order          = 6,
    worldMapAreaID = 1220,
})
DCJournal.AddAbility({
    id = 900420, name = "Nefarian's End",
    description = "Nefarian, eldest son of Deathwing, makes his final stand alongside his sister Onyxia.",
    creatureDisplayID = 32716, creatureEntry = 41376,
    encounterID = 900306, subSectionID = 900421, flags = 1, order = 1, type = 0,
})

DCJournal.AddAbility({
    id = 900421, name = "Phase One: Onyxia",
    description = "Nefarian's sister, chained here since her defeat -- she wakes to test the raid before he lands.",
    creatureDisplayID = 32569, creatureEntry = 41270,
    encounterID = 900306, parentSectionID = 900420, subSectionID = 900422, nextSectionID = 900427, order = 1, type = 2,
})
local onyxiaAbilities = {
    { "Electrical Charge", "Onyxia builds stacking electrical charge over the course of the fight; when it caps, she unleashes it as a raid-wide burst of damage.", 78949 },
    { "Lightning Discharge", "A periodic cone breath that strikes anyone standing in front of or behind her.", 78090 },
    { "Tail Lash", "A powerful strike against anyone standing behind her.", 77827 },
    { "Shadowflame Breath", "A repeating frontal breath aimed at her current tank.", 77826 },
    { "Hail of Bones", "The instant Onyxia is engaged, Nefarian seeds the platform with bone piles that animate into skeletal warriors fighting alongside her.", 78679 },
}
for i, a in ipairs(onyxiaAbilities) do
    DCJournal.AddAbility({
        id = 900421 + i, name = a[1], description = a[2], iconSpellID = a[3] or 0,
        encounterID = 900306, parentSectionID = 900421,
        nextSectionID = (i < #onyxiaAbilities) and (900421 + i + 1) or 0,
        order = i, type = 2,
    })
end

DCJournal.AddAbility({
    id = 900427, name = "Phase Two: Nefarian",
    description = "Eldest son of Deathwing, and the true master of Blackwing Descent.",
    creatureDisplayID = 32716, creatureEntry = 41376,
    encounterID = 900306, parentSectionID = 900420, subSectionID = 900428, nextSectionID = 0, order = 2, type = 2,
})
local nefarianAbilities = {
    { "Shadowflame Barrage", "While circling overhead and untargetable, Nefarian rains repeating fire damage across the platform.", 78621 },
    { "Electrocute", "Every time Nefarian crosses a 10% health threshold, the room's Lightning Machine zaps the raid.", 81198 },
    { "Shadow of Cowardice", "Punishes any player who climbs the platform's scaffolding to avoid the fight.", 79355 },
    { "Chromatic Prototypes", "Three Chromatic Prototype constructs drop onto the platform during his aerial assault and must be destroyed while dodging the barrage.", 0 },
    { "Berserk", "If the fight runs past ten and a half minutes from Onyxia's pull, Nefarian goes berserk.", 26662 },
}
for i, a in ipairs(nefarianAbilities) do
    DCJournal.AddAbility({
        id = 900427 + i, name = a[1], description = a[2], iconSpellID = a[3] or 0,
        encounterID = 900306, parentSectionID = 900427,
        nextSectionID = (i < #nefarianAbilities) and (900427 + i + 1) or 0,
        order = i, type = 2,
    })
end

DCJournal.AddBossModel(900306, {
    name = "Onyxia", creatureDisplayID = 32569, creatureEntry = 41270,
    icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-OnyxiaBWD",
})
DCJournal.AddBossModel(900306, {
    name = "Nefarian", creatureDisplayID = 32716, creatureEntry = 41376,
    icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-NefarianBWD",
})

DCJournal.AddLoot(900306, 63682)  -- Helm of the Forlorn Vanquisher (tier token)
DCJournal.AddLoot(900306, 63683)  -- Helm of the Forlorn Conqueror (tier token)
DCJournal.AddLoot(900306, 63684)  -- Helm of the Forlorn Protector (tier token)
DCJournal.AddLoot(900306, 63679)  -- Reclaimed Ashkandi, Greatsword of the Brotherhood
DCJournal.AddLoot(900306, 59459)  -- Andoros, Fist of the Dragon King
DCJournal.AddLoot(900306, 59457)  -- Shadow of Dread
DCJournal.AddLoot(900306, 59454)  -- Shadowblaze Robes
DCJournal.AddLoot(900306, 59450)  -- Belt of the Blackhand
DCJournal.AddLoot(900306, 59444)  -- Akmin-Kurai, Dominion's Shield
DCJournal.AddLoot(900306, 59443)  -- Crul'korak, the Lightning's Arc
DCJournal.AddLoot(900306, 59442)  -- Rage of Ages
DCJournal.AddLoot(900306, 59441)  -- Prestor's Talisman of Machination
DCJournal.AddLoot(900306, 59356)  -- Pauldrons of the Apocalypse
DCJournal.AddLoot(900306, 59337)  -- Mantle of Nefarius
DCJournal.AddLoot(900306, 59321)  -- Belt of the Nightmare
DCJournal.AddLoot(900306, 59222)  -- Spaulders of the Scarred Lady

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
