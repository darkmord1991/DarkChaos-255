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

-- =====================================================================
--  Shared wiring helpers for the DC instances below.
--
--  AddDCBoss mirrors how the Blackwing Descent entries above (and the base
--  WotLK bosses like Lord Marrowgar) are wired: a type=0 root "Overview"
--  section carrying the creature model, then a flat chain of type=2 ability
--  sections beneath it.
--
--  AddDCGroupBoss is the Omnotron shape: ONE encounter fought as several
--  distinct NPCs, so the root gets one type=2 header per NPC and each header
--  owns its own ability chain.
--
--  In both, `abilities` is a list of { name, description, iconSpellID }.
-- =====================================================================

local function AddAbilityChain(encID, parentID, firstChildID, abilities)
    for i, a in ipairs(abilities) do
        DCJournal.AddAbility({
            id              = firstChildID + i - 1,
            name            = a[1],
            description     = a[2],
            iconSpellID     = a[3] or 0,
            encounterID     = encID,
            parentSectionID = parentID,
            nextSectionID   = (i < #abilities) and (firstChildID + i) or 0,
            order           = i,
            type            = 2,
        })
    end
end

-- opts = { encID, rootID, order, name, lore, overview, display, entry, icon,
--          abilities = {...}, loot = { itemID, ... } }
local function AddDCBoss(instanceID, opts)
    DCJournal.AddBoss(instanceID, {
        id             = opts.encID,
        name           = opts.name,
        lore           = opts.lore,
        firstSectionID = opts.rootID,
        order          = opts.order,
    })
    DCJournal.AddAbility({
        id                = opts.rootID,
        name              = opts.name,
        description       = opts.overview or "",
        creatureDisplayID = opts.display,
        creatureEntry     = opts.entry,
        encounterID       = opts.encID,
        -- A boss with no abilities of its own (Old Serra'kis) must NOT claim a
        -- child section: the ability tree walker follows the id blindly and a
        -- dangling subSectionID leaves it pointing at nothing.
        subSectionID      = (opts.abilities and #opts.abilities > 0) and (opts.rootID + 1) or 0,
        flags             = 1,
        order             = 1,
        type              = 0,
    })
    AddAbilityChain(opts.encID, opts.rootID, opts.rootID + 1, opts.abilities or {})
    -- Explicit order: EJ_GetCreatureInfo sorts the models by it, and the boss
    -- list button always draws model #1. Leaving them all at the default 0 makes
    -- an unstable sort decide which creature represents the encounter.
    DCJournal.AddBossModel(opts.encID, {
        name = opts.name, creatureDisplayID = opts.display, creatureEntry = opts.entry,
        icon = opts.icon, order = 1,
    })
    for _, itemID in ipairs(opts.loot or {}) do
        DCJournal.AddLoot(opts.encID, itemID)
    end
end

-- opts = { encID, rootID, order, name, lore, overview, icon,
--          members = { { headerID, name, blurb, display, entry, abilities }, ... },
--          loot = { itemID, ... } }
local function AddDCGroupBoss(instanceID, opts)
    DCJournal.AddBoss(instanceID, {
        id             = opts.encID,
        name           = opts.name,
        lore           = opts.lore,
        firstSectionID = opts.rootID,
        order          = opts.order,
    })
    DCJournal.AddAbility({
        id           = opts.rootID,
        name         = opts.name,
        description  = opts.overview or "",
        encounterID  = opts.encID,
        subSectionID = opts.members[1].headerID,
        flags        = 1,
        order        = 1,
        type         = 0,
    })

    for i, m in ipairs(opts.members) do
        local nextHeader = opts.members[i + 1] and opts.members[i + 1].headerID or 0
        DCJournal.AddAbility({
            id                = m.headerID,
            name              = m.name,
            description       = m.blurb or "",
            creatureDisplayID = m.display,
            creatureEntry     = m.entry,
            encounterID       = opts.encID,
            parentSectionID   = opts.rootID,
            subSectionID      = m.abilities and #m.abilities > 0 and (m.headerID + 1) or 0,
            nextSectionID     = nextHeader,
            order             = i,
            type              = 2,
        })
        AddAbilityChain(opts.encID, m.headerID, m.headerID + 1, m.abilities or {})
        if m.display then
            -- See AddDCBoss: model #1 is what the boss list button shows, so the
            -- order has to be explicit rather than left to an unstable sort.
            DCJournal.AddBossModel(opts.encID, {
                name = m.name, creatureDisplayID = m.display, creatureEntry = m.entry,
                icon = m.icon, order = i,
            })
        end
    end

    for _, itemID in ipairs(opts.loot or {}) do
        DCJournal.AddLoot(opts.encID, itemID)
    end
end

-- The DC Item Upgrade Token (300311) drops from every boss in every custom
-- instance below. Listing it seven times per raid would drown the actual gear,
-- so it is deliberately left off the per-boss loot lists.

-- ---------------------------------------------------------------------
--  Timbermaw Hold -- map 819, 20-player raid, Dark Chaos tier.
--  Bosses, ability kits and loot below come from the live encounter scripts
--  (src/server/scripts/DC/TimbermawHold/) and the applied world DB, not from
--  retail trivia -- this instance has no retail counterpart.
--  No hand-made art: the nightmare-corrupted woodland set from Darkheart
--  Thicket is reused (a missing .blp renders as a green/black block).
-- ---------------------------------------------------------------------
local TIMBERMAW_HOLD = 901000

DCJournal.AddInstance({
    id             = TIMBERMAW_HOLD,
    tier           = 80,
    isRaid         = true,
    name           = "Timbermaw Hold",
    lore           = "The tunnels beneath Felwood were the last ground the Timbermaw tribe held clean, and the Emerald Nightmare has taken them anyway. The gatewarden and the chieftain fight for it now rather than against it, the deep dens have been turned over to nightmare growth, and past them both of the ancient bear gods lie waiting -- Ursol dreaming, Ursoc awake and furious, and the blood of an Old God running under all of it.",
    buttonIcon     = "Interface\\EncounterJournal\\UI-EJ-DUNGEONBUTTON-DarkheartThicket",
    background     = "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-DarkheartThicket",
    loreBackground = "Interface\\EncounterJournal\\UI-EJ-LOREBG-DarkheartThicket",
    mapID          = 819,
    order          = 2,
})

AddDCBoss(TIMBERMAW_HOLD, {
    encID = 901001, rootID = 901100, order = 1,
    name = "Gatewarden Mor'thak", display = 503739, entry = 4010001,
    lore = "Mor'thak kept the hold's outer gate for longer than most of the tribe has been alive, and he keeps it still -- only now he keeps it against the living. Nothing reaches the deeper dens until he falls.",
    overview = "The hold's corrupted gatekeeper, and a straightforward tank-and-spank opener built around heavy melee pressure.",
    abilities = {
        { "Mortal Strike", "A crushing blow on his current target that halves the healing they receive, landing roughly every 14 seconds.", 32736 },
        { "Cleave", "A wide swing every 10 seconds or so that carries into anyone standing beside the tank.", 15496 },
        { "Thunderclap", "A shockwave every 20 seconds that damages and slows everyone in melee range.", 23931 },
    },
    loot = { 410015, 410018, 410024, 410043 },
})

AddDCBoss(TIMBERMAW_HOLD, {
    encID = 901002, rootID = 901120, order = 2,
    name = "The Sundered Chieftain", display = 503737, entry = 4010002,
    lore = "What is left of the tribe's chieftain no longer answers to a name. He led the defence of the hold until the corruption finished taking him, and he fights on out of the same fury that made him worth following.",
    overview = "A melee brawler who becomes markedly more dangerous once the fight is most of the way through.",
    abilities = {
        { "War Stomp", "Slams the ground every 18 seconds, stunning everyone standing near him.", 46026 },
        { "Whirlwind", "Spins through everything in melee range roughly every 22 seconds.", 33238 },
        { "Enrage", "At 30% health he goes berserk for the rest of the fight, hitting far harder than before.", 8599 },
    },
    loot = { 410004, 410026, 410049, 410050 },
})

AddDCBoss(TIMBERMAW_HOLD, {
    encID = 901003, rootID = 901140, order = 3,
    name = "Den Mother Ursara", display = 23773, entry = 4010003,
    lore = "Ursara guarded the cubs of the hold, and the nightmare did not have to work hard to turn that into something murderous. Everything that enters the den is a threat to her young, and she has stopped being able to tell the difference.",
    overview = "A bear that will not stay on the tank -- expect her to leave melee for whoever is standing furthest back.",
    abilities = {
        { "Maul", "A savage bite on her current target every 12 seconds.", 26996 },
        { "Rend", "Opens a bleeding wound on the tank that keeps ticking, reapplied every 15 seconds.", 13738 },
        { "Charge", "Roughly every 21 seconds she picks a player at range and closes on them at speed.", 22120 },
    },
    loot = { 410031, 410034, 410048, 410053 },
})

AddDCBoss(TIMBERMAW_HOLD, {
    encID = 901004, rootID = 901160, order = 4,
    name = "Xanthir the Defiler", display = 503743, entry = 4010004,
    lore = "Xanthir is the one who let the nightmare in. He worked the rituals that opened the deep dens to it and he has been rewarded for the work, which is why he is still recognisably himself where the rest of the hold is not.",
    overview = "A caster fight: the damage is spread across the raid, and his crowd control is what actually kills groups.",
    abilities = {
        { "Shadow Bolt Volley", "Fires shadow bolts at everyone in range every 12 seconds.", 27383 },
        { "Curse of Tongues", "Curses a random player every 20 seconds, slowing their casting badly until it is dispelled.", 12889 },
        { "Fear", "Every 28 seconds he panics everyone near him, scattering the raid into whatever else is in the room.", 26070 },
    },
    loot = { 410009, 410012, 410037, 410044 },
})

AddDCBoss(TIMBERMAW_HOLD, {
    encID = 901005, rootID = 901180, order = 5,
    name = "The Nightmare Given Root", display = 503770, entry = 4010005,
    lore = "The corruption stopped needing a host somewhere in the lower dens and simply grew a body for itself out of the hold. It does not hunt so much as spread, and the room fills with it while the raid works.",
    overview = "A stationary fight where the room, rather than the boss, does most of the damage.",
    abilities = {
        { "Entangling Roots", "Roots a random player in place every 13 seconds -- being pinned in a nightmare cloud is what makes this lethal.", 33844 },
        { "Thorns", "Wraps itself in thorns every 30 seconds, punishing every melee swing that lands on it.", 25777 },
        { "Nightmare Cloud", "Vents a cloud of nightmare across everyone nearby every 24 seconds.", 71939 },
    },
    loot = { 410011, 410025, 410032, 410045 },
})

AddDCBoss(TIMBERMAW_HOLD, {
    encID = 901006, rootID = 901200, order = 6,
    name = "Ursol", display = 503735, entry = 4010006,
    lore = "Ursol the sleeping twin never woke properly, and the nightmare reached him through the dream instead. He fights from inside it, and pulls the raid in after him.",
    overview = "The dream phases are the fight: control is thrown around constantly and anyone left in it stops contributing.",
    abilities = {
        { "Creature of Nightmare", "Every 25 seconds he shows a player their worst fear and sends them fleeing in terror.", 25806 },
        { "Nightmare Cloud", "A cloud of nightmare over everyone near him roughly every 18 seconds.", 71939 },
        { "Immersed in the Emerald Nightmare", "Pulls a random player under into the dream every 32 seconds. The victim can break out on their own -- they have to act rather than wait for a dispel.", 57413 },
    },
    loot = { 410023, 410029, 410030, 410051 },
})

AddDCBoss(TIMBERMAW_HOLD, {
    encID = 901007, rootID = 901220, order = 7,
    name = "Ursoc", display = 21631, entry = 4010007,
    icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-Ursoc",
    lore = "Ursoc the raging twin woke, and what woke with him was not only a bear god. Drive him low enough and the thing that has been feeding on the hold answers his call directly.",
    overview = "A hard-hitting melee fight with a damage check at the end -- the last quarter of his health is the whole encounter.",
    abilities = {
        { "Maul", "A heavy bite on his current target every 9 seconds -- the fastest tank hit in the instance.", 26996 },
        { "Charge", "Every 18 seconds he picks a player at range and slams into them.", 22120 },
        { "Enrage", "He works himself into a fury every 40 seconds, raising his damage each time.", 8599 },
        { "Blood of the Old God", "At 25% health he calls the blood of the Old God to his aid, and the last stretch of the fight becomes markedly worse.", 52560 },
    },
    loot = { 410000, 410001, 410008, 410014, 410035, 410046 },
})

-- ---------------------------------------------------------------------
--  Blackfathom Deeps (Ashenvale) -- map 820, 5-player dungeon (Normal /
--  Heroic / Mythic). A full clone of the stock temple re-tuned for the
--  map-750 Ashenvale level band, including the Cataclysm NPC layer AC never
--  imported. Cloned creature entries are the originals + 3,900,000.
--  Behaviour is the stock SmartAI kit; the spell ids below are the ones the
--  live smart_scripts rows actually cast.
-- ---------------------------------------------------------------------
local BFD_ASHENVALE = 902000

DCJournal.AddInstance({
    id             = BFD_ASHENVALE,
    tier           = 80,
    name           = "Blackfathom Deeps (Ashenvale)",
    lore           = "The sunken shrine of Elune under the Zoram Strand, as it stands after the Cataclysm: the Twilight's Hammer entrenched rather than merely present, the naga holding the flooded halls, and Aku'mai still coiled in the dark at the bottom of it all. Same temple, a far harder swim -- this is the Ashenvale-band version, tuned for level 92 and up and running Normal, Heroic and Mythic.",
    buttonIcon     = "Interface\\EncounterJournal\\UI-EJ-DUNGEONBUTTON-BlackfathomDeeps",
    smallIcon      = "Interface\\LFGFRAME\\LFGICON-BlackfathomDeeps",
    background     = "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-BlackfathomDeeps",
    loreBackground = "Interface\\EncounterJournal\\UI-EJ-LOREBG-BlackfathomDeeps",
    mapID          = 820,
    order          = 1,
})

AddDCBoss(BFD_ASHENVALE, {
    encID = 902001, rootID = 902100, order = 1,
    name = "Ghamoo-ra", display = 5027, entry = 3904887,
    icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-Ghamoo-Ra",
    lore = "The great turtle Ghamoo-ra has held the shallows of the temple for as long as anyone has been coming down here to disturb them, and it has no interest in why this group is any different.",
    overview = "A slow, heavily armoured melee opener with no mechanics beyond its own weight.",
    abilities = {
        { "Trample", "Rolls forward over everyone in front of it every few seconds.", 5568 },
    },
    loot = { 6907, 6908 },
})

AddDCBoss(BFD_ASHENVALE, {
    encID = 902002, rootID = 902120, order = 2,
    name = "Lady Sarevess", display = 4979, entry = 3904831,
    icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-Lady Sarevess",
    lore = "Sarevess commands the naga holding the flooded upper halls. She has been given the temple to keep by those working further down, and she does not intend to explain herself to intruders.",
    overview = "A ranged naga caster who locks the group down and then whittles it from a distance.",
    abilities = {
        { "Forked Lightning", "Arcs lightning through everyone in front of her every few seconds.", 8435 },
        { "Frost Nova", "Freezes everyone near her in place, then backs off to keep casting.", 865 },
        { "Slow", "Slows a player's attacks and casting badly for the rest of the fight unless it is removed.", 246 },
        { "Shoot", "Falls back on her crossbow whenever nothing else is ready.", 6660 },
    },
    loot = { 888, 3078, 11121 },
})

AddDCBoss(BFD_ASHENVALE, {
    encID = 902003, rootID = 902140, order = 3,
    name = "Gelihast", display = 1773, entry = 3906243,
    icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-Gelihast",
    lore = "Gelihast guards the approach to the fire braziers. Killing him is what unseals the way to Aku'mai's chamber -- the temple does not open until he is dealt with.",
    overview = "A murloc fight about mobility: he takes the group's movement away and keeps his own.",
    abilities = {
        { "Net", "Nets a player every few seconds, rooting them where they stand.", 6533 },
    },
    loot = { 6905, 6906 },
})

AddDCBoss(BFD_ASHENVALE, {
    encID = 902004, rootID = 902160, order = 4,
    name = "Twilight Lord Kelris", display = 4939, entry = 3904832,
    icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-Twilight Lord Kelris",
    lore = "Kelris was a priest of Elune before the voices from below got to him. He channels at the altar until the group interrupts him, and the Twilight's Hammer presence in the temple runs through him.",
    overview = "The only real crowd-control check in the dungeon: he sleeps people and burns whoever is still awake.",
    abilities = {
        { "Sleep", "Puts a player to sleep every 15 seconds or so -- they stay down until damaged.", 8399 },
        { "Mind Blast", "A hard-hitting shadow blast on his current target every few seconds.", 15587 },
        { "Blackfathom Channeling", "Out of combat he channels at the altar, drawing on whatever is answering from below.", 8734 },
    },
    loot = { 1155, 6903 },
})

AddDCBoss(BFD_ASHENVALE, {
    encID = 902005, rootID = 902180, order = 5,
    name = "Old Serra'kis", display = 1816, entry = 3904830,
    lore = "Serra'kis has been in the flooded lower pool long enough to have grown well past the size of anything else in it. It is old, it is enormous, and it is entirely uninterested in the cult's politics.",
    overview = "A straight melee fight with no abilities at all -- the danger is the water it is fought in, not the thresher.",
    abilities = {},
    loot = { 6901, 6902, 6904 },
})

AddDCBoss(BFD_ASHENVALE, {
    encID = 902006, rootID = 902200, order = 6,
    name = "Aku'mai", display = 2837, entry = 3904829,
    icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-Akumai",
    lore = "Aku'mai is the reason the Twilight's Hammer came here at all -- the servant of the Old Gods the whole temple has been feeding. It only rises once all four braziers around its chamber have been lit.",
    overview = "Light all four braziers to summon it. A sustained melee fight where its damage climbs as the fight runs long.",
    abilities = {
        { "Poison Cloud", "Fills the chamber with poison every 20 seconds or so, damaging everyone in it.", 3815 },
        { "Frenzied Rage", "Works itself into a frenzy every 15 seconds, attacking faster and hitting harder.", 3490 },
    },
    loot = { 6909, 6910, 6911 },
})

-- ---------------------------------------------------------------------
--  Crescent Grove -- map 823, 5-player dungeon. Bosses and kits from
--  src/server/scripts/DC/CrescentGrove/. Elder 'One Eye' and Elder Blackmaw
--  are not encounters of their own: they are council adds that must die
--  alongside the Grovetender for the fight to complete, which is why they
--  appear as sub-entries under her rather than as their own bosses.
-- ---------------------------------------------------------------------
local CRESCENT_GROVE = 903000

-- Every Crescent Grove boss rolls from the same Ashenvale Skirmisher table.
local CRESCENT_GROVE_LOOT = {
    400738, 400739, 400740, 400741, 400742,   -- boots
    400743, 400744, 400745, 400746, 400747,   -- shoulders
    400748, 400749, 400750, 400751, 400752,   -- legs
}

DCJournal.AddInstance({
    id             = CRESCENT_GROVE,
    tier           = 80,
    name           = "Crescent Grove",
    lore           = "A moonlit night elf grove that was never meant to be reached, walled off behind the Ashenvale treeline and left to its keepers. Something in it went wrong a long time ago: the wardens still patrol, the priestesses still keep the rites, and none of them will let anyone leave with what they are guarding.",
    buttonIcon     = "Interface\\EncounterJournal\\UI-EJ-DUNGEONBUTTON-DarkheartThicket",
    background     = "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-DarkheartThicket",
    loreBackground = "Interface\\EncounterJournal\\UI-EJ-LOREBG-DarkheartThicket",
    mapID          = 823,
    order          = 2,
})

AddDCBoss(CRESCENT_GROVE, {
    encID = 903001, rootID = 903100, order = 1,
    name = "Keeper Ranathos", display = 503751, entry = 4020001,
    lore = "Ranathos keeps the outer grove and has kept it for centuries. He would rather root intruders in place and let the grove deal with them than fight anyone himself.",
    overview = "A druid opener built on roots and ranged damage rather than melee pressure.",
    abilities = {
        { "Entangling Roots", "Roots a random player in place every 14 seconds.", 33844 },
        { "Moonfire", "Burns a random player with moonlight every 9 seconds -- his steadiest source of damage.", 21669 },
        { "Thorns", "Shields himself in thorns every 30 seconds, hurting anyone who keeps meleeing him.", 25777 },
    },
    loot = CRESCENT_GROVE_LOOT,
})

AddDCGroupBoss(CRESCENT_GROVE, {
    encID = 903002, rootID = 903120, order = 2,
    name = "Grovetender Engryss",
    lore = "The Grovetender does not fight alone. The two elder bears of the grove wake with her, and the grove does not consider the matter settled until all three are down -- killing her first only leaves the elders angrier.",
    overview = "A council fight: the encounter completes only once the Grovetender and both elders are dead.",
    members = {
        {
            headerID = 903121, name = "Grovetender Engryss", display = 503737, entry = 4020002,
            blurb = "The Grovetender herself -- a melee fighter who fights in close and calls the elders in with her.",
            abilities = {
                { "Cleave", "A wide swing every 11 seconds that carries into anyone beside the tank.", 15496 },
                { "War Stomp", "Stuns everyone in melee range every 20 seconds.", 46026 },
            },
        },
        {
            headerID = 903130, name = "Elder 'One Eye'", display = 503737, entry = 4020003,
            blurb = "One of the two elder bears. Pure melee -- kill it, or the encounter will not finish.",
            abilities = {
                { "Cleave", "Swings through everyone in front of it every 13 seconds.", 15496 },
            },
        },
        {
            headerID = 903140, name = "Elder Blackmaw", display = 2003, entry = 4020004,
            blurb = "The second elder bear, with the same kit as its packmate and the same requirement: it has to die too.",
            abilities = {
                { "Cleave", "Swings through everyone in front of it every 13 seconds.", 15496 },
            },
        },
    },
    loot = CRESCENT_GROVE_LOOT,
})

AddDCBoss(CRESCENT_GROVE, {
    encID = 903003, rootID = 903160, order = 3,
    name = "High Priestess A'lathea", display = 503753, entry = 4020005,
    lore = "A'lathea keeps the rites at the heart of the grove and has no intention of stopping for a party of intruders. She will heal through anything the group cannot pressure hard enough.",
    overview = "A healer fight -- the check is whether the group can out-damage her self-healing while rooted.",
    abilities = {
        { "Moonfire", "Burns a random player every 8 seconds.", 21669 },
        { "Healing Touch", "Heals herself every 22 seconds; interrupting it is the difference between a short fight and a long one.", 25297 },
        { "Entangling Roots", "Roots a random player every 18 seconds, usually whoever was about to interrupt her.", 33844 },
    },
    loot = CRESCENT_GROVE_LOOT,
})

AddDCBoss(CRESCENT_GROVE, {
    encID = 903004, rootID = 903180, order = 4,
    name = "Fenektis the Deceiver", display = 503747, entry = 4020006,
    lore = "Fenektis is what went wrong here. Whatever bargain he made on the grove's behalf, he is the one still holding up his end of it, and the keepers above have no idea what they have been protecting.",
    overview = "A shadow caster who breaks the group apart and then punishes it for being scattered.",
    abilities = {
        { "Shadow Bolt Volley", "Fires shadow bolts at everyone in range every 13 seconds.", 27383 },
        { "Curse of Tongues", "Curses a random player every 21 seconds, crippling their casting.", 12889 },
        { "Fear", "Panics everyone near him every 27 seconds.", 26070 },
    },
    loot = CRESCENT_GROVE_LOOT,
})

AddDCBoss(CRESCENT_GROVE, {
    encID = 903005, rootID = 903200, order = 5,
    name = "Master Raxxieth", display = 503755, entry = 4020007,
    lore = "Raxxieth is the reason the grove was sealed. He has been waiting at the end of it the whole time, and everything else in here has been a delaying action.",
    overview = "The dungeon's damage check: heavy area damage throughout, and an enrage in the final fifth of his health.",
    abilities = {
        { "Cleave", "A wide swing every 10 seconds through everyone in front of him.", 15496 },
        { "Rain of Fire", "Calls fire down on a random player every 18 seconds -- move out of it rather than heal through it.", 34435 },
        { "Fear", "Panics everyone near him every 26 seconds, scattering the group into the fire.", 26070 },
        { "Enrage", "At 20% health he goes berserk for the remainder of the fight.", 8599 },
    },
    loot = CRESCENT_GROVE_LOOT,
})

-- ---------------------------------------------------------------------
--  Emerald Sanctum -- map 824, 20-player raid. Two encounter slots only:
--  Erennius, then a single "Wakener" slot that ONE of the four green dragons
--  fills on a weekly rotation. All four share the encounter, so they are
--  listed as four sub-entries under it rather than as four bosses.
--  Kits from src/server/scripts/DC/EmeraldSanctum/.
-- ---------------------------------------------------------------------
local EMERALD_SANCTUM = 904000

DCJournal.AddInstance({
    id             = EMERALD_SANCTUM,
    tier           = 80,
    isRaid         = true,
    name           = "Emerald Sanctum",
    lore           = "A sanctum built where the waking world presses closest against the Emerald Dream, and the wrong side of that border is now pressing back. The green flight's own dragons have been pulled through it -- and only one of the four is ever waiting when the sanctum opens.",
    buttonIcon     = "Interface\\EncounterJournal\\UI-EJ-DUNGEONBUTTON-TheEmeraldNightmare",
    background     = "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-TheEmeraldNightmare",
    loreBackground = "Interface\\EncounterJournal\\UI-EJ-LOREBG-TheEmeraldNightmare",
    mapID          = 824,
    order          = 3,
})

AddDCBoss(EMERALD_SANCTUM, {
    encID = 904001, rootID = 904100, order = 1,
    name = "Erennius", display = 503765, entry = 4030001,
    lore = "Erennius was set to warden the sanctum and has held the post past the point where it still meant anything. Whatever he is guarding it from arrived a long time ago.",
    overview = "The sanctum's warden, and a shadow-caster warm-up for the dragon waiting past him.",
    abilities = {
        { "Shadow Bolt Volley", "Fires shadow bolts at everyone in range every 12 seconds.", 27383 },
        { "Curse of Tongues", "Curses a random player every 20 seconds, slowing their casting badly.", 12889 },
        { "Fear", "Panics everyone near him every 26 seconds.", 26070 },
    },
    loot = { 410119, 410120, 410126, 410132, 410153 },
})

AddDCGroupBoss(EMERALD_SANCTUM, {
    encID = 904002, rootID = 904120, order = 2,
    name = "The Wakener",
    lore = "One of the four dragons of the Nightmare holds the inner sanctum, and which one it is changes from week to week. They share the same kit -- noxious breath, a tail that clears the floor behind them, and the Mark of Nature -- and differ only in the two abilities that made each of them notorious.",
    overview = "One encounter, four possible bosses. Check which dragon is up before pulling: the shared kit is identical, the two signature abilities are not.",
    members = {
        {
            headerID = 904121, name = "Shared kit",
            blurb = "Every Wakener opens with the same three abilities regardless of which dragon the week rolled.",
            abilities = {
                { "Noxious Breath", "A breath on the current tank every 16 seconds that eats away at armour and weapon skill.", 24818 },
                { "Tail Sweep", "Clears everyone standing behind it every 14 seconds -- melee should stay off the tail.", 15847 },
                { "Mark of Nature", "Marks a random player every 24 seconds; dying while marked is what makes the mark matter.", 25040 },
            },
        },
        {
            -- First member carrying a model, so this is the art the boss list
            -- button shows for the whole encounter -- and Legion's "Dragons of
            -- Nightmare" banner already ships in the client patch, which is
            -- exactly these four dragons.
            headerID = 904130, name = "Ysondre the Wakener", display = 503757, entry = 4030002,
            icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-Dragons of Nightmare",
            blurb = "The dreamer. Her signature is chained lightning and the druid spirits she calls to fight beside her.",
            abilities = {
                { "Lightning Wave", "Chains lightning from a random player through everyone near them, every 20 seconds.", 24819 },
                { "Summon Druids", "Every 30 seconds she calls druid spirits into the fight; they have to be handled or they add up.", 24795 },
            },
        },
        {
            headerID = 904140, name = "Lethon the Wakener", display = 503759, entry = 4030003,
            blurb = "The shadow. He whirls shadow bolts out across the room and drags the spirits of the fallen back to heal himself.",
            abilities = {
                { "Shadow Bolt Whirl", "Spins shadow bolts outward across the whole room every 20 seconds.", 24834 },
                { "Draw Spirit", "Every 30 seconds he pulls spirits out of the raid and feeds on them to heal.", 24811 },
            },
        },
        {
            headerID = 904150, name = "Emeriss the Wakener", display = 503761, entry = 4030004,
            blurb = "The rot. Her signature turns players into a hazard for everyone standing near them and poisons the ground itself.",
            abilities = {
                { "Volatile Infection", "Infects a random player every 20 seconds; it bursts on whoever is close when it ends.", 24928 },
                { "Corruption of the Earth", "Every 30 seconds she corrupts the ground under the whole raid.", 24910 },
            },
        },
        {
            headerID = 904160, name = "Taerar the Wakener", display = 503763, entry = 4030005,
            blurb = "The madness. Arcane damage plus a hard sleep that takes players out of the fight entirely.",
            abilities = {
                { "Arcane Blast", "Blasts a random player every 20 seconds.", 24857 },
                { "Sleep", "Every 30 seconds he puts the raid under; sleeping players stay down until something wakes them.", 24777 },
            },
        },
    },
    loot = {
        -- Ysondre
        410121, 410124, 410139, 410143, 410144, 410150, 410152,
        -- Lethon
        410110, 410112, 410116, 410135, 410138, 410140, 410147,
        -- Emeriss
        410101, 410106, 410118, 410122, 410128, 410129, 410130,
        -- Taerar
        410102, 410105, 410109, 410114, 410117, 410125, 410133,
    },
})

-- ---------------------------------------------------------------------
--  Castle Nathria -- map 2296, 10/25-player raid, Shadowlands downport.
--  Encounter order and ability kits below are taken from the ported AI in
--  src/server/scripts/DC/CastleNathria/ and the applied loot tables.
--
--  Two caveats worth knowing while reading this entry:
--   * The Shadowlands spell ids are carried through verbatim from the port.
--     Most have no Spell.dbc row on 3.3.5 yet, so their ability icons stay
--     blank here until a downport lands -- the text is what carries the entry.
--   * Retail mythic is absent throughout; mythic-only mechanics were either
--     cut or folded onto heroic, and the descriptions follow the port, not
--     retail.
--  No Shadowlands journal art exists in the client patch, so the gothic Black
--  Rook Hold set stands in.
-- ---------------------------------------------------------------------
local CASTLE_NATHRIA = 905000

DCJournal.AddInstance({
    id             = CASTLE_NATHRIA,
    tier           = 80,
    isRaid         = true,
    name           = "Castle Nathria",
    lore           = "Sire Denathrius has ruled Revendreth from Castle Nathria for as long as the realm has existed, harvesting the anima of the sinful and answering, he claims, to no one. The claim is a lie. The castle's court has been bled dry to feed something else entirely, and the venthyr who have finally moved against their master will not get a second attempt.",
    buttonIcon     = "Interface\\EncounterJournal\\UI-EJ-DUNGEONBUTTON-BlackRookHold",
    background     = "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-BlackRookHold",
    loreBackground = "Interface\\EncounterJournal\\UI-EJ-LOREBG-BlackRookHold",
    mapID          = 2296,
    order          = 4,
})

AddDCBoss(CASTLE_NATHRIA, {
    encID = 905001, rootID = 905100, order = 1,
    name = "Shriekwing", display = 97268, entry = 164406,
    icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-Shriekwing",
    lore = "The castle's watch-beast hangs in the entry hall and hunts by sound. It is blind, and the raid's own noise is what tells it where everyone is standing.",
    overview = "Alternating phases. Shriekwing builds energy through a normal phase, then blankets the room in Blood Shroud and hunts blind -- break line of sight behind the pillars while it does.",
    abilities = {
        { "Exsanguinating Bite", "A tank hit every 20 seconds that stacks Exsanguinated ten deep; the stacks bleed off one at a time afterwards.", 328857 },
        { "Echolocation", "Marks three players every 25 seconds. Eight seconds later each of them takes Descent and leaves a pool of Sanguine Ichor where they stood.", 342077 },
        { "Blind Swipe", "Turns to a random player and swipes in a cone in front of them every 30 seconds.", 343005 },
        { "Wave of Blood", "Sent at three random players every 36 seconds.", 345397 },
        { "Blood Shroud", "Opens the blind phase: Shriekwing teleports to the middle of the hall and stops attacking, and anyone it cannot see is safe from it.", 343995 },
        { "Ear-Splitting Shriek", "Three seconds into the blind phase it shrieks across the whole room. Players still in line of sight are hit and left standing in fresh Sanguine Ichor.", 330713 },
        { "Echoing Sonar", "Pools of hazard seeded at both gates for the duration of the fight.", 329002 },
        { "Echoing Screech", "Heroic only: an extra ring of hazard laid around the boss itself.", 342865 },
    },
    loot = { 182976, 182979, 182993, 183027, 183034, 184016 },
})

AddDCGroupBoss(CASTLE_NATHRIA, {
    encID = 905002, rootID = 905140, order = 2,
    name = "Huntsman Altimor",
    lore = "Altimor keeps the castle's hounds, and he does not fight without them. Three beasts come at the raid one after another, and the huntsman is only reachable through all three.",
    overview = "Sequential pet phases. Margore, then Bargast, then Hecutis -- each dies before the next wakes, and all three share their health with Altimor himself.",
    members = {
        {
            headerID = 905141, name = "Huntsman Altimor", display = 95643, entry = 165066,
            icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-HuntsmanAltimor",
            blurb = "The huntsman fights throughout, whichever beast is currently up.",
            abilities = {
                { "Spread Shot", "He turns to a random player and cones every 20 seconds.", 334404 },
                { "Sinseeker", "Every 45 seconds three players are hit, each taking an opening blow and then a bleed that keeps ticking.", 335114 },
            },
        },
        {
            headerID = 905150, name = "Margore", display = 95539, entry = 165067,
            blurb = "The first beast: a mangler that fixates and charges.",
            abilities = {
                { "Jagged Claws", "A tank hit every 10 to 20 seconds.", 334971 },
                { "Vicious Lunge", "Marks a random player, then charges them six seconds later. The damage splits between everyone in the landing circle, so stack it.", 334939 },
                { "Vicious Wound", "Heroic only: the lunge leaves a wound behind on whoever it landed on.", 334960 },
            },
        },
        {
            headerID = 905160, name = "Bargast", display = 95538, entry = 169457,
            blurb = "The second beast: a soul-eater that keeps trying to feed Altimor back to full.",
            abilities = {
                { "Shades of Bargast", "Summons a shade every 30 seconds (two on heroic); each of them roars across the raid on its own timer.", 334757 },
                { "Rip Soul", "Every 10 to 20 seconds a player's soul is torn out and starts walking toward Altimor. If it reaches him, he devours it and heals.", 334797 },
            },
        },
        {
            headerID = 905170, name = "Hecutis", display = 95540, entry = 169458,
            blurb = "The third beast: a stone hound that grows heavier the longer it lives.",
            abilities = {
                { "Crushing Stone", "A stack that reapplies every two seconds and never stops climbing.", 334860 },
                { "Petrifying Howl", "Every 30 seconds three players are marked; eight seconds later each drops a field of stone shards where they stand.", 334852 },
            },
        },
    },
    loot = { 182988, 182995, 182996, 183018, 183040, 184017 },
})

AddDCBoss(CASTLE_NATHRIA, {
    encID = 905003, rootID = 905200, order = 3,
    name = "Hungering Destroyer", display = 98776, entry = 164261,
    icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-HungeringDestroyer",
    lore = "A creature of the Maw, brought into the castle and kept fed. It has never been anything but hungry, and Denathrius has never had any shortage of anima to keep it that way.",
    overview = "An energy fight. The Destroyer fills up over roughly a minute and a half and then dumps Consume on the whole raid -- everything else is scheduled around surviving that.",
    abilities = {
        { "Consume", "The energy dump: a raid-wide hit whenever it reaches full, roughly every 90 seconds.", 334522 },
        { "Overwhelm", "A tank hit every 20 seconds.", 329774 },
        { "Gluttonous Miasma", "Three players every 24 seconds take a debuff that damages them while healing the boss.", 329298 },
        { "Volatile Ejection", "Fired every 30 seconds.", 334266 },
        { "Desolate", "A raid-wide hit at 22 seconds, then once a minute after that.", 329455 },
        { "Expunge", "Heroic only: when the debuff expires it leaves an Obliterating Rift behind on the floor.", 329725 },
    },
    loot = { 182992, 182994, 183000, 183001, 183009, 183024, 183028, 184022, 184023 },
})

AddDCGroupBoss(CASTLE_NATHRIA, {
    encID = 905004, rootID = 905240, order = 4,
    name = "The Sun King's Salvation",
    lore = "Kael'thas Sunstrider is chained in the castle's redemption chamber, and his torturer is well into the work. The raid is not here to kill him -- it is here to keep him alive long enough to finish being redeemed.",
    overview = "Not a kill. Heal Kael'thas from 20% back to full while the castle throws waves of adds at the raid. He dies, the raid wipes.",
    members = {
        {
            headerID = 905241, name = "Kael'thas Sunstrider", display = 94482, entry = 165759,
            icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-SunKingsSalvation",
            blurb = "Friendly, and the entire objective. High Torturer Darithos drops him to 20% health on the pull; healing him back to full ends the encounter.",
            abilities = {
                { "Greater Castigation", "Darithos' opening strike, six seconds into the pull -- what puts Kael'thas at 20% in the first place.", 328885 },
            },
        },
        {
            headerID = 905250, name = "Shade of Kael'thas", display = 96807, entry = 165805,
            blurb = "Spawns when Kael'thas is healed past 45%, and again past 90%. Add waves stop while a shade is alive -- deal with it first.",
            abilities = {
                { "Fiery Strike", "Turns to a random player and strikes every 15 to 20 seconds.", 326455 },
                { "Blazing Surge", "An energy-gated hit on a random player, followed three seconds later by three missiles scattered around them.", 329518 },
                { "Ember Blast", "A single cast at a random player ten seconds in.", 325877 },
                { "Smoldering Plumage", "The two phoenixes the shade summons drop burning patches every two and a half seconds while they live.", 328659 },
            },
        },
        {
            headerID = 905260, name = "The add waves",
            blurb = "A new wave every 60 seconds: a Rockbound Vanquisher, four Bleakwing Assassins, several Vile Occultists, Pestering Fiends and Soul Infusers.",
            abilities = {
                { "Summon Essence Font", "A dying Vile Occultist leaves behind the healing font the raid needs to push Kael'thas upward.", 329565 },
                { "Fragmentation", "Heroic only: a dying Pestering Fiend bursts on whoever killed it.", 336398 },
            },
        },
    },
    loot = {},
})

AddDCBoss(CASTLE_NATHRIA, {
    encID = 905005, rootID = 905300, order = 5,
    name = "Artificer Xy'mox", display = 95375, entry = 166644,
    icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-ArtificerXymox",
    lore = "Xy'mox is not one of Denathrius' court. He is a broker, he is here for the vault, and he has had more than enough time to install his own machinery in it before anyone else arrived.",
    overview = "Three stages on health. At 70% the Root and Seed of Extinction come online; at 40% the Root goes and the Edge of Annihilation replaces it.",
    abilities = {
        { "Hyperlight Spark", "Hits every player in the room every 14 to 18 seconds, in all three stages.", 325399 },
        { "Dimensional Tear", "Every 40 seconds two players are marked; their tears detonate eight seconds later.", 328437 },
        { "Glyph of Destruction", "A tank bomb every 30 seconds that builds for several seconds before going off.", 325361 },
        { "Rift Blast", "Every 45 seconds three rifts open at random players, each firing on whoever is nearest.", 335013 },
        { "Crystal of Phantasm", "Every 50 seconds a Fleeting Spirit spawns and fixates the furthest player; letting it reach them means being possessed.", 327887 },
        { "Seed of Extinction", "Stage two, every 45 seconds: four seeds are planted. They can be disarmed by hand -- 18 seconds later they detonate.", 329834 },
        { "Edge of Annihilation", "Stage three's opener: a construct that puts an Aura of Dread over the entire room for the rest of the fight.", 328880 },
        { "Stasis Trap", "Heroic only, every 28 seconds: traps at three players' feet that stun whoever walks into them.", 326271 },
    },
    loot = { 182987, 183004, 183012, 183019, 183038, 184021 },
})

AddDCBoss(CASTLE_NATHRIA, {
    encID = 905006, rootID = 905340, order = 6,
    name = "Lady Inerva Darkvein", display = 96806, entry = 165521,
    icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-LadyInervaDarkvein",
    lore = "Inerva runs the castle's anima reserves and knows exactly what Denathrius has been doing with them. She keeps the secret because she helped build it.",
    overview = "Two repeating cycles rather than health phases: Exposed Cognition every 33 seconds and Exposed Heart every 66, each pulling its own follow-up mechanics in behind it.",
    abilities = {
        { "Expose Desires", "Every 19 seconds, damage plus a Warped Desires debuff on the tank.", 325379 },
        { "Shared Cognition", "The Cognition cycle: the tank eats the desires damage and a random player is linked to them.", 325908 },
        { "Change of Heart", "The Heart cycle: put on the tank if they are not already Warped, and detonating at their feet when it fades.", 340452 },
        { "Bottled Anima", "Every 35 seconds a pool is dropped near every player in the room.", 329620 },
        { "Lingering Anima", "The Cognition follow-up: a second pool per player on top of the bottled anima.", 325718 },
        { "Concentrated Anima", "Roots a player in place and, when it expires, leaves a Harnessed Specter standing where they were.", 332664 },
        { "Highly Concentrated Anima", "The Heart follow-up: everyone still carrying Concentrated Anima gets two mirrored arcs of shadow fragments thrown around them.", 342322 },
        { "Shared Suffering", "Every 50 seconds, three Sins of the Past join the fight. Leave them alive 45 seconds and the whole raid pays for it.", 324983 },
    },
    loot = { 182985, 183015, 183021, 183026, 183037, 184025 },
})

AddDCGroupBoss(CASTLE_NATHRIA, {
    encID = 905007, rootID = 905380, order = 7,
    name = "The Council of Blood",
    lore = "Three of Denathrius' court hold the ballroom, and they are far more interested in the ball than in the intruders. The raid will be attending whether it wants to or not.",
    overview = "Three bosses, one health pool between them in spirit only: killing one heals and empowers the survivors, and the fight ends only when all three are down. Every 60 seconds Danse Macabre stops the fight and makes the raid dance.",
    members = {
        {
            headerID = 905381, name = "Baroness Frieda", display = 96836, entry = 166969,
            icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-TheCouncilOfBlood",
            blurb = "The host. She calls the dance, and she is the one who gains the most from a co-boss dying.",
            abilities = {
                { "Oppressive Atmosphere", "A raid-wide aura reapplied to everyone every ten seconds.", 334909 },
                { "Dreadbolt Volley", "Fired at random players every 20 seconds.", 337110 },
                { "Drain Essence", "Channelled on a random player every 30 seconds, draining them while it runs.", 346654 },
                { "Prideful Eruption", "Unlocked when the first council member dies: every 35 seconds the whole raid is hit.", 346657 },
                { "Soul Spikes", "Unlocked when the second dies: a tank hit every 40 seconds.", 346681 },
                { "Danse Macabre", "Every 60 seconds the council stops fighting and the raid is made to dance for 15 seconds while Frieda calls four steps.", 0 },
                { "Dancing Fever", "Heroic only: a three-stack aura on five random players every 35 seconds.", 347350 },
            },
        },
        {
            headerID = 905390, name = "Castellan Niklaus", display = 96835, entry = 166971,
            blurb = "The duellist. He fights the tank directly and keeps summoning attendants to hide behind.",
            abilities = {
                { "Duelist's Riposte", "A tank hit every 20 seconds.", 346690 },
                { "Undying Shield", "Every 30 seconds he summons a Dutiful Attendant and shields it; the add has to come down.", 346694 },
                { "Castellan's Cadre", "Unlocked when the second council member dies.", 0 },
            },
        },
        {
            headerID = 905400, name = "Lord Stavros", display = 96837, entry = 166970,
            blurb = "The dancer. He will not stay where the raid put him.",
            abilities = {
                { "Evasive Lunge", "Every 20 seconds he teleports to the tank and strikes on arrival.", 327497 },
                { "Dark Recital", "Every 30 seconds, a cast that resolves three seconds later on every player in the room.", 331634 },
            },
        },
    },
    loot = { 182983, 182989, 183011, 183014, 183023, 183030, 183039, 184024 },
})

AddDCBoss(CASTLE_NATHRIA, {
    encID = 905008, rootID = 905440, order = 8,
    name = "Sludgefist", display = 95623, entry = 164407,
    icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-Sludgefist",
    lore = "A stone giant chained in the castle's foundations, and the only thing holding the ceiling up is the same set of pillars the raid is about to break.",
    overview = "Locked until the Council of Blood is dead. Sludgefist builds energy and then charges the tank blind -- steer him into a pillar rather than a wall, and never stand alone in front of him.",
    abilities = {
        { "Giant Fists", "A hit on the closest player every two seconds. It lands twice unless somebody else is within ten yards to share it.", 335298 },
        { "Hateful Gaze", "The energy dump: he marks the tank, then charges them six seconds later.", 331209 },
        { "Headless Charge", "Anyone the charge passes within eight yards of is hit on the way through.", 339067 },
        { "Destructive Impact", "Steering the charge into one of the four pillars destroys it -- and drops Crumbling Foundation on the whole raid.", 332969 },
        { "Collapsing Foundation", "Steering the charge into a wall instead: raid-wide damage and no pillar removed. Either way he is stunned for twelve seconds.", 332197 },
        { "Destructive Stomp", "Raid-wide damage every 20 to 25 seconds, announced before it lands.", 332318 },
        { "Falling Rumble", "Five random players every 15 to 18 seconds, each also seeding a stonequake pool underfoot.", 332552 },
        { "Gruesome Rage", "At 30% health he enrages for the rest of the fight.", 341250 },
    },
    loot = { 182981, 182984, 182999, 183005, 183006, 183016, 183022, 184026 },
})

AddDCGroupBoss(CASTLE_NATHRIA, {
    encID = 905009, rootID = 905480, order = 9,
    name = "The Stone Legion Generals",
    lore = "Kaal and Grashaal command the stone legion that has always held Revendreth's walls. They are still holding them, for a master who no longer deserves it, and Prince Renathal has come along to change their minds by force.",
    overview = "Two generals, one on the ground and one in the air, swapping roles twice. Either dropping to 50% locks into Hardened Stoneform -- only Renathal's Shattering Blast breaks it, and it is fuelled by the adds the raid kills.",
    members = {
        {
            headerID = 905481, name = "General Kaal", display = 98155, entry = 168112,
            icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-StoneLegionGenerals",
            blurb = "Starts on the ground. Goes ranged when Grashaal lands, and comes back to the front line in the final phase.",
            abilities = {
                { "Serrated Swipe", "A tank hit every 20 seconds while she is on the front line.", 334929 },
                { "Heart Rend", "Four random players every 25 seconds.", 334765 },
                { "Wicked Blade", "Raid-wide damage every 30 seconds, in every phase.", 333387 },
                { "Ricocheting Shuriken", "Her ranged-phase filler: a random player every 15 seconds.", 343086 },
            },
        },
        {
            headerID = 905490, name = "General Grashaal", display = 98156, entry = 168113,
            blurb = "Starts airborne and bombs the raid from above, then lands and takes the front line for the middle phase.",
            abilities = {
                { "Stone Spike", "Five random players every 15 to 20 seconds while he is in the air.", 170926 },
                { "Crystalize", "Every 60 seconds: a channel on a random player, then a burst on them and everyone within eight yards, then a meteor.", 339690 },
                { "Stone Fist", "His tank hit once he is on the ground.", 342425 },
                { "Seismic Upheaval", "Grounded phase: five waves a second apart across the entire raid, repeating every 30 seconds.", 337595 },
                { "Reverberating Eruption", "Every 35 seconds a mark is placed at a random player; five seconds later it erupts and leaves unstable ground behind.", 344496 },
            },
        },
        {
            headerID = 905500, name = "Prince Renathal", display = 98426, entry = 172652,
            blurb = "Not a boss -- he is the phase mechanic. Renathal is the only thing on the platform that can break a general's stoneform, and the raid has to fuel him to do it.",
            abilities = {
                { "Hardened Stoneform", "At 50% health a general locks itself down and becomes immune, summoning a Goliath and three Commandos three seconds later.", 329636 },
                { "Shattering Blast", "Killing Commandos feeds Renathal anima. At full, he shatters the stoneform -- and both generals swap roles.", 332683 },
                { "Soldier's Oath", "When the first general dies, the survivor takes their oath and fights harder for it.", 336212 },
            },
        },
    },
    loot = { 182991, 183032, 184027 },
})

AddDCBoss(CASTLE_NATHRIA, {
    encID = 905010, rootID = 905540, order = 10,
    name = "Sire Denathrius", display = 96942, entry = 167406,
    icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-Denathrius",
    lore = "The master of Revendreth, and the reason every soul in it has been bled. He fights with Remornia in hand -- a living blade, and a member of his court in her own right -- and he does not believe for a moment that this ends with him losing.",
    overview = "Three stages with an intermission. At 70% the March of the Penitent moves the raid to the Sanctum floor and Remornia joins the fight in her own body; at 40% she becomes his sword again. Energy drives a different empowered command in each stage.",
    abilities = {
        { "Burden of Sin", "On the pull every player is given four stacks, ticking damage the whole fight. Cleansing Pain is what removes them.", 326699 },
        { "Cleansing Pain", "A stage-one tank hit every 25 seconds. Each hit strips one stack of Burden of Sin and spawns an Echo of Sin.", 326707 },
        { "Feeding Time", "Stage one: three players marked, then two Echoes of Sin on each of them five seconds later. Heroic replaces this with Night Hunter.", 327039 },
        { "Blood Price", "The whole raid is immobilised, then hit and knocked back several seconds later. Runs in stages one and three.", 326994 },
        { "Command: Ravage", "Stage one's energy dump: Remornia carves a zone of Desolation into the floor at a random player. It stays for the rest of the stage.", 327227 },
        { "Command: Massacre", "Stage two's energy dump, and the fight's signature: twelve telegraphed lines sweep the Sanctum floor. Contact is lethal, not merely damaging.", 330042 },
        { "Command: Sinister Reflection", "Stage three's energy dump: a reflection of the Sire himself is summoned to be tanked.", 333979 },
        { "Wracking Pain", "A stage-two tank cleave every 20 seconds.", 329181 },
        { "Hand of Destruction", "Every 45 seconds in stages two and three: a hand is summoned and detonates six seconds later.", 333932 },
        { "Impale", "Remornia's own kit in stage two: three or four players marked every 25 seconds and impaled six seconds later. On heroic each impact leaves a zone of Rancor.", 329951 },
        { "Crimson Chorus", "The four Crimson Cabalists that spawn in stage two channel it from the moment they arrive.", 329711 },
        { "Indignation", "Opens stage three.", 326005 },
        { "Shattering Pain", "Stage three, every 25 seconds: a hit on the tank followed by a knockback three seconds later.", 332619 },
        { "Fatal Finesse", "Stage three, every 30 seconds on three or four players. Heroic adds Smoldering Ire zones behind it.", 332797 },
    },
    loot = { 183036, 184030, 184031 },
})

DCJournal.AddBossModel(905010, {
    name = "Remornia", creatureDisplayID = 96665, creatureEntry = 168156,
})

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
