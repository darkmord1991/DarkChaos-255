-- ============================================================================
-- GIANT ISLES - PRIMAL FISHING
-- ============================================================================
-- Map: 1405  Zone: 5006 (Isles of Giants)  Area: 5017 (Nice's Nice Beach)
-- Items  : 900100-900102 (fish), 900110 (rod)
-- GOs    : 900200-900201 (fishing holes)
-- Loot   : fishing_loot_template 5017 (open water), 900200/900201 (holes)
-- ============================================================================

-- ============================================================================
-- FISH ITEMS
-- class=7 (Trade Goods), subclass=8 (Meat & Fish), FoodType=2 (Fish)
-- stackable=200 so players can carry a decent haul
-- SellPrice in copper (10000 = 1g, 18750 = 1g87s50c)
-- ============================================================================

DELETE FROM item_template WHERE entry IN (900100, 900101, 900102);

-- Titan-Scale Lungfish (common, Uncommon quality)
-- A massive prehistoric lungfish still found in the shallow coastal reefs.
INSERT INTO item_template SET
    entry=900100, class=7, subclass=8, SoundOverrideSubclass=-1,
    name='Titan-Scale Lungfish', displayid=24719,
    Quality=2, Flags=0, FlagsExtra=0,
    BuyCount=1, BuyPrice=40000, SellPrice=10000,
    InventoryType=0, AllowableClass=-1, AllowableRace=-1,
    ItemLevel=80, RequiredLevel=0,
    maxcount=0, stackable=200,
    bonding=0, Material=-1,
    description='An enormous prehistoric fish, still abundant in the ancient shallows of the Giant Isles.',
    FoodType=2, VerifiedBuild=12340;

-- Primordial Thunderfin (uncommon, Rare quality)
-- Crackles with electrical energy built up over aeons.
INSERT INTO item_template SET
    entry=900101, class=7, subclass=8, SoundOverrideSubclass=-1,
    name='Primordial Thunderfin', displayid=24716,
    Quality=3, Flags=0, FlagsExtra=0,
    BuyCount=1, BuyPrice=75000, SellPrice=18750,
    InventoryType=0, AllowableClass=-1, AllowableRace=-1,
    ItemLevel=80, RequiredLevel=0,
    maxcount=0, stackable=100,
    bonding=0, Material=-1,
    description='Crackling with electrical energy that has built up over aeons. Handle with care.',
    FoodType=2, VerifiedBuild=12340;

-- Epoch Eel (uncommon, Uncommon quality)
-- A serpentine eel whose lineage predates the Sundering.
INSERT INTO item_template SET
    entry=900102, class=7, subclass=8, SoundOverrideSubclass=-1,
    name='Epoch Eel', displayid=24713,
    Quality=2, Flags=0, FlagsExtra=0,
    BuyCount=1, BuyPrice=50000, SellPrice=12500,
    InventoryType=0, AllowableClass=-1, AllowableRace=-1,
    ItemLevel=80, RequiredLevel=0,
    maxcount=0, stackable=200,
    bonding=0, Material=-1,
    description='A serpentine eel whose lineage predates the Sundering. It has outlasted three ages of the world.',
    FoodType=2, VerifiedBuild=12340;

-- ============================================================================
-- FISHING ROD: SPINE OF THE FIRST AGE (Epic fishing pole)
-- class=2 (Weapon), subclass=20 (Fishing Pole), InventoryType=17 (Two-Hand)
-- spellid_1=59731, spelltrigger_1=1 = equip bonus (+fishing skill, same as Kalu'ak pole)
-- stat_type1=7 (Stamina), stat_value1=100 for flavor
-- RequiredSkill=356 (Fishing), RequiredSkillRank=375
-- bonding=1 (Bind on Pickup) — must be found in the world
-- ============================================================================

DELETE FROM item_template WHERE entry=900110;
INSERT INTO item_template SET
    entry=900110, class=2, subclass=20, SoundOverrideSubclass=-1,
    name='Spine of the First Age', displayid=58715,
    Quality=4, Flags=0, FlagsExtra=0,
    BuyCount=1, BuyPrice=0, SellPrice=500000,
    InventoryType=17, AllowableClass=-1, AllowableRace=-1,
    ItemLevel=200, RequiredLevel=80,
    RequiredSkill=356, RequiredSkillRank=375,
    maxcount=1, stackable=1,
    stat_type1=7, stat_value1=100,
    delay=2000,
    spellid_1=59731, spelltrigger_1=1, spellcooldown_1=-1, spellcategorycooldown_1=-1,
    bonding=1, Material=1, sheath=1,
    description='Carved from the spinal column of a titan-sized creature that swam these seas before the world took its current shape.',
    RequiredDisenchantSkill=-1, VerifiedBuild=12340;

-- ============================================================================
-- SKILL REQUIREMENT
-- entry = zone or area ID; server checks area first, then zone fallback
-- skill 375 = attainable at high end with any good WotLK pole
-- ============================================================================

DELETE FROM skill_fishing_base_level WHERE entry IN (5006, 5017);
INSERT INTO skill_fishing_base_level (entry, skill) VALUES
    (5017, 375),   -- Nice's Nice Beach (area)
    (5006, 350);   -- Isles of Giants (zone fallback for other areas)

-- ============================================================================
-- OPEN-WATER LOOT (area 5017)
-- GroupId=1 items are mutually exclusive; server picks one per cast weighted by Chance.
-- GroupId=0 items each roll independently on top of the primary catch.
-- Chances within GroupId=1 should sum ~100.
-- ============================================================================

DELETE FROM fishing_loot_template WHERE Entry IN (5006, 5017);
INSERT INTO fishing_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment) VALUES
-- Primary catch group (pick one per cast)
(5017, 900100, 0, 55.0, 0, 1, 1, 1, 3, 'Titan-Scale Lungfish'),
(5017, 900102, 0, 35.0, 0, 1, 1, 1, 2, 'Epoch Eel'),
(5017, 900101, 0, 10.0, 0, 1, 1, 1, 1, 'Primordial Thunderfin'),
-- Bonus items (independent rolls each cast)
(5017, 900110,  0, 0.1,  0, 1, 0, 1, 1, 'Spine of the First Age -- rare pole discovery'),
(5017, 37705,   0, 5.0,  0, 1, 0, 1, 2, 'Crystallized Water -- primal remnant'),
(5017, 6265,    0, 20.0, 0, 1, 0, 1, 2, 'Firefin Snapper -- bonus fire-school fish'),
-- Zone fallback (5006) mirrors the area loot for other beaches
(5006, 900100, 0, 60.0, 0, 1, 1, 1, 2, 'Titan-Scale Lungfish'),
(5006, 900102, 0, 30.0, 0, 1, 1, 1, 1, 'Epoch Eel'),
(5006, 900101, 0, 10.0, 0, 1, 1, 1, 1, 'Primordial Thunderfin');

-- ============================================================================
-- FISHING HOLE TEMPLATES (type 25)
-- data0=radius, data1=fishing_loot_template entry, data2=min catches,
-- data3=max catches, data4=lock ID (1628 = fishing)
-- ============================================================================

DELETE FROM gameobject_template WHERE entry IN (900200, 900201);
INSERT INTO gameobject_template
    (entry, type, displayId, name, IconName, castBarCaption, unk1,
     data0, data1, data2, data3, data4, data5, data6, data7, data8, data9,
     data10, data11, data12, data13, data14, data15, data16, data17,
     data18, data19, data20, data21, data22, data23, AIName, ScriptName, VerifiedBuild)
VALUES
-- Primordial Lungfish Shoal (mostly Lungfish, chance at Thunderfin)
(900200, 25, 6291, 'Primordial Lungfish Shoal', '', 'Fishing', '',
    4, 900200, 3, 8, 1628, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, '', '', 12340),
-- Epoch Eel Swarm (eel-focused, rare Thunderfin, rare rod)
(900201, 25, 6742, 'Epoch Eel Swarm', '', 'Fishing', '',
    4, 900201, 3, 6, 1628, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, '', '', 12340);

-- ============================================================================
-- FISHING HOLE LOOT
-- GO type=25: data1 points to gameobject_loot_template, NOT fishing_loot_template.
-- fishing_loot_template is only for area/zone IDs (open-water casts).
-- ============================================================================

DELETE FROM gameobject_loot_template WHERE Entry IN (900200, 900201);
INSERT INTO gameobject_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment) VALUES
-- Primordial Lungfish Shoal loot
(900200, 900100, 0, 70.0, 0, 1, 1, 2, 5, 'Titan-Scale Lungfish'),
(900200, 900101, 0, 25.0, 0, 1, 1, 1, 2, 'Primordial Thunderfin'),
(900200, 900110, 0, 0.2,  0, 1, 0, 1, 1, 'Spine of the First Age'),
(900200, 37705,  0, 10.0, 0, 1, 0, 1, 2, 'Crystallized Water'),
-- Epoch Eel Swarm loot
(900201, 900102, 0, 80.0, 0, 1, 1, 2, 4, 'Epoch Eel'),
(900201, 900100, 0, 15.0, 0, 1, 1, 1, 2, 'Titan-Scale Lungfish'),
(900201, 900101, 0, 5.0,  0, 1, 1, 1, 1, 'Primordial Thunderfin'),
(900201, 900110, 0, 0.2,  0, 1, 0, 1, 1, 'Spine of the First Age'),
(900201, 37705,  0, 8.0,  0, 1, 0, 1, 2, 'Crystallized Water');

-- ============================================================================
-- BUFF FOOD ITEMS (produced by Grak'zar the cook)
-- class=0 (consumable), subclass=5 (food), FoodType=2 (fish)
-- spelltrigger_1=0 = on-use cast;  spellcharges_1=-1 = item consumed on use
-- Buff spells reuse existing WotLK Well Fed IDs (vanilla values; raise via
-- Spell.dbc edit if the server scales stat requirements beyond 450).
-- ============================================================================

DELETE FROM item_template WHERE entry IN (900120, 900121, 900122, 900123);

-- 900120: Primal Fish Stew  (5 Lungfish -> 1)
-- Eating: spell 900120 (channel) -> triggers Well Fed 910120 (+200 Agility, +200 Stamina)
INSERT INTO item_template SET
    entry=900120, class=0, subclass=5, SoundOverrideSubclass=-1,
    name='Primal Fish Stew', displayid=54531,
    Quality=2, Flags=0, FlagsExtra=0,
    BuyCount=1, BuyPrice=0, SellPrice=5000,
    InventoryType=0, AllowableClass=-1, AllowableRace=-1,
    ItemLevel=80, RequiredLevel=80,
    maxcount=0, stackable=20, bonding=0, Material=4,
    spellid_1=900120, spelltrigger_1=0, spellcharges_1=-1, spellcooldown_1=-1, spellcategorycooldown_1=-1,
    description='A rich stew brewed from fish that have swum these seas since before the Sundering. Fills you with ancient vigour.',
    FoodType=2, VerifiedBuild=12340;

-- 900121: Thunderfin Fillet  (2 Thunderfin -> 1)
-- Eating: spell 900121 (channel) -> triggers Well Fed 910121 (+300 Strength, +200 Stamina)
INSERT INTO item_template SET
    entry=900121, class=0, subclass=5, SoundOverrideSubclass=-1,
    name='Thunderfin Fillet', displayid=39117,
    Quality=3, Flags=0, FlagsExtra=0,
    BuyCount=1, BuyPrice=0, SellPrice=10000,
    InventoryType=0, AllowableClass=-1, AllowableRace=-1,
    ItemLevel=80, RequiredLevel=80,
    maxcount=0, stackable=20, bonding=0, Material=4,
    spellid_1=900121, spelltrigger_1=0, spellcharges_1=-1, spellcooldown_1=-1, spellcategorycooldown_1=-1,
    description='The residual electrical charge in the flesh makes this fillet crackle on your tongue. Your strikes feel sharper already.',
    FoodType=2, VerifiedBuild=12340;

-- 900122: Epoch Eel Broth  (3 Epoch Eel -> 1)
-- Eating: spell 900122 (channel) -> triggers Well Fed 910122 (+200 Spell Power, +200 Haste)
INSERT INTO item_template SET
    entry=900122, class=0, subclass=5, SoundOverrideSubclass=-1,
    name='Epoch Eel Broth', displayid=54494,
    Quality=2, Flags=0, FlagsExtra=0,
    BuyCount=1, BuyPrice=0, SellPrice=6000,
    InventoryType=0, AllowableClass=-1, AllowableRace=-1,
    ItemLevel=80, RequiredLevel=80,
    maxcount=0, stackable=20, bonding=0, Material=4,
    spellid_1=900122, spelltrigger_1=0, spellcharges_1=-1, spellcooldown_1=-1, spellcategorycooldown_1=-1,
    description='Memories of three world-ages swirl in this broth. Drinking it sharpens the mind to a razor edge.',
    FoodType=2, VerifiedBuild=12340;

-- 900123: First Age Fish Feast  (2 Lungfish + 1 Thunderfin + 2 Eel -> 1)
-- Eating: spell 900123 (channel) -> triggers Well Fed 910123 (+300 Agility, +250 SP, +250 Stamina)
INSERT INTO item_template SET
    entry=900123, class=0, subclass=5, SoundOverrideSubclass=-1,
    name='First Age Fish Feast', displayid=53864,
    Quality=4, Flags=0, FlagsExtra=0,
    BuyCount=1, BuyPrice=0, SellPrice=25000,
    InventoryType=0, AllowableClass=-1, AllowableRace=-1,
    ItemLevel=80, RequiredLevel=80,
    maxcount=0, stackable=5, bonding=0, Material=4,
    spellid_1=900123, spelltrigger_1=0, spellcharges_1=-1, spellcooldown_1=-1, spellcategorycooldown_1=-1,
    description='A legendary spread prepared by an ancient hand. Only those willing to fish the primordial depths deserve its blessing.',
    FoodType=2, VerifiedBuild=12340;

-- ============================================================================
-- COOK NPC: Grak'zar "Ancient Cook"  (entry 401119)
-- Stationed next to Angler Rolo on Nice's Nice Beach.
-- npcflag=1 = gossip only (exchange is handled by script, not vendor window)
-- ScriptName must match the RegisterCreatureAI / new() call: npc_giant_isles_primal_cook
-- ============================================================================

DELETE FROM creature_template WHERE entry = 401119;
INSERT INTO creature_template (entry, name, subname, gossip_menu_id, minlevel, maxlevel,
    faction, npcflag, speed_walk, speed_run, `rank`, unit_class,
    unit_flags, RegenHealth, ScriptName, VerifiedBuild)
VALUES (401119, 'Grak''zar', 'Ancient Cook', 400119, 80, 80,
    35, 1, 1.0, 1.14286, 0, 1,
    0, 1, 'npc_giant_isles_primal_cook', 12340);

DELETE FROM creature_template_model WHERE CreatureID = 401119;
INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability)
VALUES (401119, 0, 4259, 1.0, 1.0);

-- NPC greeting text shown in the gossip pane
DELETE FROM npc_text WHERE ID = 400119;
INSERT INTO npc_text (ID, text0_0, Probability0) VALUES
(400119,
 'Grak''zar grins, showing rows of sharp teeth.$B$B"Da fish ya pull from dese ancient waters carry da power of da First Age, mon. Bring dem to Grak''zar and I cook ya somethin\' worthy of a titan."$B$B"What fish ya bringin'' today?"',
 1.0);

-- gossip_menu ties the menu ID (used in creature_template) to the npc_text
DELETE FROM gossip_menu WHERE MenuID = 400119;
INSERT INTO gossip_menu (MenuID, TextID) VALUES (400119, 400119);

-- ============================================================================
-- FISHING AREA NPCS (entries 401120-401123)
-- All faction 35, map 1405, zone 5006, area 5017 (Nice's Nice Beach)
-- Run AFTER giant_isles_creatures.sql (which does the broad 401000-401999 cleanup).
-- ============================================================================

-- creature_template
DELETE FROM creature_template WHERE entry IN (401120, 401121, 401122, 401123);
INSERT INTO creature_template (entry, name, subname, gossip_menu_id, minlevel, maxlevel,
    faction, npcflag, speed_walk, speed_run, `rank`, unit_class,
    unit_flags, RegenHealth, ScriptName, VerifiedBuild)
VALUES
-- npcflag 17 = gossip(1) + trainer(16)
(401120, 'Angler Tideborn',  'Fishing Trainer',        400130, 80, 80, 35,  17, 1.0, 1.14286, 0, 1, 0, 1, '', 12340),
-- npcflag  3 = gossip(1) + questgiver(2)
(401121, 'Tide-Watcher Mazu','Fishing Daily Quests',   400131, 80, 80, 35,   3, 1.0, 1.14286, 0, 1, 0, 1, '', 12340),
-- npcflag 129 = gossip(1) + vendor(128)
(401122, 'Bait Keeper Ruk''lo','Fishing Supplies',     400132, 80, 80, 35, 129, 1.0, 1.14286, 0, 1, 0, 1, '', 12340),
-- ambient angler — non-interactive
(401123, 'Primal Fisher',    NULL,                           0, 80, 80, 35,   0, 1.0, 1.14286, 0, 1, 0, 1, '', 12340);

-- creature_template_model
DELETE FROM creature_template_model WHERE CreatureID IN (401120, 401121, 401122, 401123);
INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability)
VALUES
(401120, 0, 2095, 1.0,  1.0),  -- Angler Tideborn   (Human Male)
(401121, 0, 5444, 1.0,  1.0),  -- Tide-Watcher Mazu (Human Female)
(401122, 0, 4259, 1.0,  1.0),  -- Bait Keeper Ruk'lo (Troll Male, like Grak'zar)
(401123, 0, 2095, 1.0,  1.0);  -- Primal Fisher     (Human Male)

-- creature_equip_template
DELETE FROM creature_equip_template WHERE CreatureID IN (401120, 401121, 401122, 401123);
INSERT INTO creature_equip_template (CreatureID, ID, ItemID1, ItemID2, ItemID3, VerifiedBuild)
VALUES
(401120, 1,  6256, 0, 0, 12340),  -- Angler Tideborn   - Fishing Pole
(401121, 1, 12584, 0, 0, 12340),  -- Tide-Watcher Mazu - Staff
(401122, 1,     0, 0, 0, 12340),  -- Bait Keeper Ruk'lo - No weapon
(401123, 1,  6256, 0, 0, 12340);  -- Primal Fisher     - Fishing Pole

-- Gossip text
-- (gossip_menu 400130-400133 are also cleared by the BETWEEN 400000-400199
--  DELETE in giant_isles_creatures.sql, so this block is safe to re-run alone.)
DELETE FROM npc_text WHERE ID IN (400130, 400131, 400132, 400133);
INSERT INTO npc_text (ID, text0_0, Probability0) VALUES
(400130,
 'Angler Tideborn gestures toward the shimmering water.$B$B"Dese ancient waters teem with life unchanged since before da Sundering, mon. I can teach ya to read da tides and pull da finest fish from da deep.$B$BWant to learn da ways of First Age fishing?"',
 1.0),
(400131,
 'Mazu scans the horizon, watching the patterns of the shoals.$B$B"Da fish move different here than anywhere else in da world. Come back each day and I''ll show ya where da big ones are runnin''. Da Thunderfin don''t wait for anyone."',
 1.0),
(400132,
 'Ruk''lo eyes your fishing pole and clicks his teeth approvingly.$B$B"Good pole, mon, but da fish here laugh at common bait. Ruk''lo has somethin'' special — lures infused with ancient deep-water scent. Da Epoch Eel can''t resist."',
 1.0),
(400133,
 'The guard watches the beach with unwavering calm.$B$B"There will be no fighting here. This shore is open to all who come in peace. Take your quarrels elsewhere — or answer to me."',
 1.0);

DELETE FROM gossip_menu WHERE MenuID IN (400130, 400131, 400132, 400133);
INSERT INTO gossip_menu (MenuID, TextID) VALUES
(400130, 400130),
(400131, 400131),
(400132, 400132),
(400133, 400133);

-- Vendor inventory for Bait Keeper Ruk'lo (401122)
DELETE FROM npc_vendor WHERE entry = 401122;
INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost, VerifiedBuild) VALUES
(401122, 1,  6529, 0, 0, 0, 12340),  -- Shiny Bauble
(401122, 2,  6530, 0, 0, 0, 12340),  -- Nightcrawlers
(401122, 3,  6532, 0, 0, 0, 12340),  -- Bright Baubles
(401122, 4,  6533, 0, 0, 0, 12340),  -- Aquadynamic Fish Attractor
(401122, 5,  6811, 0, 0, 0, 12340),  -- Aquadynamic Fish Lens
(401122, 6, 33820, 0, 0, 0, 12340),  -- Sharpened Fish Hook
(401122, 7, 34861, 0, 0, 0, 12340);  -- Glass Fishing Bobber

-- ============================================================================
-- FISHING TRAINER: Angler Tideborn (entry 401120)
-- AzerothCore trainer system: trainer → trainer_spell → creature_default_trainer
-- TrainerId 401120 matches NPC entry for uniqueness.
-- Teaches all fishing ranks through Grand Master (skill 356).
-- ============================================================================

DELETE FROM trainer WHERE Id = 401120;
INSERT INTO trainer (Id, Type, Requirement, Greeting, VerifiedBuild) VALUES
(401120, 2, 0,
 'Angler Tideborn nods knowingly as you approach.$B$B"These ancient waters demand respect and skill. I can teach ya the ways of fishing, from the simplest cast to the secrets of Grand Master technique.$B$BWant to learn?"',
 12340);

DELETE FROM trainer_spell WHERE TrainerId = 401120;
INSERT INTO trainer_spell (TrainerId, SpellId, MoneyCost, ReqSkillLine, ReqSkillRank, ReqAbility1, ReqAbility2, ReqAbility3, ReqLevel, VerifiedBuild) VALUES
-- Apprentice Fishing  (no skill required, level 5)
(401120,  7733,     100, 0,   0, 0, 0, 0,  5, 12340),
-- Journeyman Fishing  (requires 50 skill)
(401120,  7734,     500, 356,  50, 0, 0, 0, 10, 12340),
-- Expert Fishing      (requires 125 skill)
(401120, 54083,   10000, 356, 125, 0, 0, 0, 10, 12340),
-- Artisan Fishing     (requires 200 skill)
(401120, 18249,   25000, 356, 200, 0, 0, 0, 10, 12340),
-- Master Fishing      (requires 275 skill)
(401120, 54084,  100000, 356, 275, 0, 0, 0, 10, 12340),
-- Grand Master Fishing (requires 350 skill)
(401120, 51293,  350000, 356, 350, 0, 0, 0, 10, 12340);

DELETE FROM creature_default_trainer WHERE CreatureId = 401120;
INSERT INTO creature_default_trainer (CreatureId, TrainerId) VALUES (401120, 401120);

-- ============================================================================
-- FISHING DAILY QUESTS (offered and collected by Tide-Watcher Mazu 401121)
-- Quest IDs: 83100-83102
-- Flags 4482 = QUEST_FLAGS_DAILY (0x1000) | sharable (0x80) | deliver (0x02)
-- SpecialFlags 3 = repeatable (1) + daily (2)
-- RequiredSkillID 356 (Fishing), RequiredSkillPoints 350 (Grand Master entry)
-- RewardXPDifficulty 5 = WotLK XP table tier 5 (~40k XP at level 80)
-- ============================================================================

DELETE FROM quest_template WHERE ID IN (83100, 83101, 83102);
INSERT INTO quest_template (ID, QuestType, QuestLevel, MinLevel, QuestSortID, QuestInfoID,
    Flags, AllowableRaces,
    LogTitle, LogDescription, QuestDescription, AreaDescription, QuestCompletionLog,
    RequiredItemId1, RequiredItemCount1,
    RewardXPDifficulty, RewardMoney,
    VerifiedBuild)
VALUES
-- 83100: Ancient Catch — 10x Titan-Scale Lungfish
(83100, 2, 80, 1, -101, 0,
    4482, 0,
    'Ancient Catch',
    'Tide-Watcher Mazu needs a haul of Titan-Scale Lungfish from the ancient shallows.',
    'The Titan-Scale Lungfish has swum these waters since before the world took its current shape. We study them to learn the old tides.$B$BBring me [10 Titan-Scale Lungfish] and I''ll see you are rewarded.',
    'Nice''s Nice Beach',
    'Bring 10 Titan-Scale Lungfish to Tide-Watcher Mazu at Nice''s Nice Beach.',
    900100, 10,
    5, 50000,
    12340),
-- 83101: The Thunderfin Run — 5x Primordial Thunderfin
(83101, 2, 80, 1, -101, 0,
    4482, 0,
    'The Thunderfin Run',
    'Tide-Watcher Mazu seeks rare Primordial Thunderfin from the deeper currents.',
    'The Thunderfin carries a charge of ancient lightning in its scales. We study it to understand the primal storm-magic of this isle.$B$BCatch me [5 Primordial Thunderfin] from the deeper waters. They won''t come easy.',
    'Nice''s Nice Beach',
    'Bring 5 Primordial Thunderfin to Tide-Watcher Mazu at Nice''s Nice Beach.',
    900101, 5,
    5, 100000,
    12340),
-- 83102: The Epoch Haul — 8x Epoch Eel
(83102, 2, 80, 1, -101, 0,
    4482, 0,
    'The Epoch Haul',
    'Tide-Watcher Mazu needs a collection of Epoch Eels for research.',
    'These eels carry memories of ages long past. Their migration patterns tell us things no scroll can — if you know how to read them.$B$BFish up [8 Epoch Eels] from the eel swarms offshore and bring them back to me.',
    'Nice''s Nice Beach',
    'Bring 8 Epoch Eels to Tide-Watcher Mazu at Nice''s Nice Beach.',
    900102, 8,
    5, 70000,
    12340);

DELETE FROM quest_template_addon WHERE ID IN (83100, 83101, 83102);
INSERT INTO quest_template_addon (ID, MaxLevel, AllowableClasses, SourceSpellID, PrevQuestID, NextQuestID,
    ExclusiveGroup, BreadcrumbForQuestId, RewardMailTemplateID, RewardMailDelay,
    RequiredSkillID, RequiredSkillPoints,
    RequiredMinRepFaction, RequiredMaxRepFaction, RequiredMinRepValue, RequiredMaxRepValue,
    ProvidedItemCount, SpecialFlags)
VALUES
-- RequiredSkillID=356 (Fishing) matches ZoneOrSort=-101 (Fishing category) so
-- the server does not warn "does not have a corresponding value (356)".
-- RequiredSkillPoints=0 means no minimum skill level is enforced; the
-- fishing-loot table already gates the actual fish behind 375 skill.
(83100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 356, 0, 0, 0, 0, 0, 0, 3),
(83101, 0, 0, 0, 0, 0, 0, 0, 0, 0, 356, 0, 0, 0, 0, 0, 0, 3),
(83102, 0, 0, 0, 0, 0, 0, 0, 0, 0, 356, 0, 0, 0, 0, 0, 0, 3);

DELETE FROM quest_request_items WHERE ID IN (83100, 83101, 83102);
INSERT INTO quest_request_items (ID, EmoteOnComplete, EmoteOnIncomplete, CompletionText, VerifiedBuild) VALUES
(83100, 1, 0, 'Keep those lines in the water. The ancient Lungfish won''t catch themselves.', 12340),
(83101, 1, 0, 'The Thunderfin hides in the deep currents. Patience — and skill — will win out.', 12340),
(83102, 1, 0, 'The Epoch Eels gather at the swarm offshore. You are close — keep fishing.', 12340);

DELETE FROM quest_offer_reward WHERE ID IN (83100, 83101, 83102);
INSERT INTO quest_offer_reward (ID, Emote1, Emote2, Emote3, Emote4,
    EmoteDelay1, EmoteDelay2, EmoteDelay3, EmoteDelay4, RewardText, VerifiedBuild) VALUES
(83100, 1, 0, 0, 0, 0, 0, 0, 0,
    'Mazu examines each fish carefully, making notes.$B$B"Perfect specimens. The tides reward those who listen to them. Your gold."', 12340),
(83101, 1, 0, 0, 0, 0, 0, 0, 0,
    'Mazu''s eyes widen as she sees the catch.$B$B"Five Thunderfin! The storm in them hasn''t faded. Outstanding work. Take your reward."', 12340),
(83102, 1, 0, 0, 0, 0, 0, 0, 0,
    'Mazu counts the eels, studying their markings.$B$B"These carry echoes of the second age, maybe older. Remarkable. Well done — and well earned."', 12340);

DELETE FROM creature_queststarter WHERE id = 401121 AND quest IN (83100, 83101, 83102);
INSERT INTO creature_queststarter (id, quest) VALUES
(401121, 83100),
(401121, 83101),
(401121, 83102);

DELETE FROM creature_questender WHERE id = 401121 AND quest IN (83100, 83101, 83102);
INSERT INTO creature_questender (id, quest) VALUES
(401121, 83100),
(401121, 83101),
(401121, 83102);

-- Blue overhead daily-quest icon for Tide-Watcher Mazu
DELETE FROM dc_questgiver_status_overrides WHERE creature_entry = 401121;
INSERT INTO dc_questgiver_status_overrides (creature_entry, enabled, promote_daily, promote_weekly, promote_monthly, comment) VALUES
(401121, 1, 1, 0, 0, 'Tide-Watcher Mazu: show blue overhead icon for available daily fishing quests');

-- After applying:
--   .reload gameobject_template        (fixes fishing hole display)
--   .reload fishing_loot_template      (open-water and hole loot)
--   .reload creature_template          (NPC stats/flags)
--   .reload trainer                    (Angler Tideborn skills)
--   .reload quest_template             (daily quests)
