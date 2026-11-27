-- Hyjal Frontier - mob gold, loot tables and Doomlord unique drops
--
-- Covers every hostile creature template active in the zone.
-- Approach:
--   lootid = entry (self-referential, one row per creature entry in the loot table)
--   Gold scales with the tier bracket.
--   Green drops reference the existing zone quest-reward pools (14110-14112)
--   with tier-appropriate rare gear from the leveling catalog (400011-400040).
--   Doomlord (830072) gets two guaranteed epic items plus a chance at T4 weapons.
--
-- Item IDs used as loot:
--   400011-400040  zone quest-reward rings/pendants/cloaks by tier (already in DB)
--   400041-400070  leveling armor rings (Foothills/Scorched tiers, already in DB)
--   400453         Doombane Pauldrons   (created below, shoulders epic)
--   400454         Doomlord's Eye of Chaos (created below, trinket epic)

-- =============================================================================
-- Doomlord unique items  (entries 400453-400454)
-- =============================================================================
DELETE FROM `item_template` WHERE `entry` IN (400453, 400454);

INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,`displayid`,
     `Quality`,`Flags`,`FlagsExtra`,`BuyCount`,`BuyPrice`,`SellPrice`,
     `InventoryType`,`AllowableClass`,`AllowableRace`,`ItemLevel`,`RequiredLevel`,
     `maxcount`,`stackable`,`bonding`,
     `stat_type1`,`stat_value1`,`stat_type2`,`stat_value2`,
     `stat_type3`,`stat_value3`,`stat_type4`,`stat_value4`,
     `stat_type5`,`stat_value5`,
     `armor`,`description`,`VerifiedBuild`)
VALUES
-- Plate shoulders, physical focus (all classes, ilvl 412)
(400453, 4, 4, -1, 'Doombane Pauldrons', 65000,
    4, 0, 0, 1, 0, 280000, 3, -1, -1, 412, 130,
    1, 1, 1,
    4, 510, 7, 560, 32, 310, 37, 260, 38, 410,
    850, 'The plate of the Doomlord, reforged by Nordrassil''s druids. Guaranteed drop.', 0),
-- Trinket, spell power / intellect focus (all classes, ilvl 412)
(400454, 4, 0, -1, 'Doomlord''s Eye of Chaos', 54562,
    4, 0, 0, 1, 0, 260000, 12, -1, -1, 412, 130,
    1, 1, 1,
    45, 680, 7, 560, 5, 430, 36, 310, 0, 0,
    0, 'The warped gaze of the Hyjal Doomlord. Guaranteed drop.', 0);

UPDATE `item_template` SET `material`=6  WHERE `entry`=400453;
UPDATE `item_template` SET `material`=-1 WHERE `entry`=400454;

-- =============================================================================
-- Set lootid and gold on every hostile creature template
-- =============================================================================
-- Foothills (level 80-90):  gold 5-14 silver
UPDATE `creature_template` SET `lootid`=830040, `mingold`=500,  `maxgold`=1400 WHERE `entry`=830040;
UPDATE `creature_template` SET `lootid`=830041, `mingold`=600,  `maxgold`=1500 WHERE `entry`=830041;
UPDATE `creature_template` SET `lootid`=830042, `mingold`=700,  `maxgold`=1700 WHERE `entry`=830042;
UPDATE `creature_template` SET `lootid`=830091, `mingold`=700,  `maxgold`=1600 WHERE `entry`=830091;
UPDATE `creature_template` SET `lootid`=830092, `mingold`=800,  `maxgold`=1800 WHERE `entry`=830092;

-- Scorched Groves (95-105): gold 15-35 silver
UPDATE `creature_template` SET `lootid`=830050, `mingold`=1500, `maxgold`=2800 WHERE `entry`=830050;
UPDATE `creature_template` SET `lootid`=830051, `mingold`=1800, `maxgold`=3200 WHERE `entry`=830051;
UPDATE `creature_template` SET `lootid`=830052, `mingold`=2000, `maxgold`=3600 WHERE `entry`=830052;
UPDATE `creature_template` SET `lootid`=830093, `mingold`=1900, `maxgold`=3400 WHERE `entry`=830093;
UPDATE `creature_template` SET `lootid`=830094, `mingold`=2100, `maxgold`=3700 WHERE `entry`=830094;

-- The Summit (110-120): gold 35-70 silver
UPDATE `creature_template` SET `lootid`=830060, `mingold`=3500, `maxgold`=5500 WHERE `entry`=830060;
UPDATE `creature_template` SET `lootid`=830061, `mingold`=4000, `maxgold`=6200 WHERE `entry`=830061;
UPDATE `creature_template` SET `lootid`=830062, `mingold`=4500, `maxgold`=7000 WHERE `entry`=830062;
UPDATE `creature_template` SET `lootid`=830095, `mingold`=4200, `maxgold`=6500 WHERE `entry`=830095;
UPDATE `creature_template` SET `lootid`=830096, `mingold`=4800, `maxgold`=7200 WHERE `entry`=830096;

-- Nordrassil Roots (125-130): gold 70-130 silver
UPDATE `creature_template` SET `lootid`=830070, `mingold`=7000, `maxgold`=10000 WHERE `entry`=830070;
UPDATE `creature_template` SET `lootid`=830071, `mingold`=8000, `maxgold`=12000 WHERE `entry`=830071;
UPDATE `creature_template` SET `lootid`=830073, `mingold`=9000, `maxgold`=13000 WHERE `entry`=830073;
UPDATE `creature_template` SET `lootid`=830097, `mingold`=8000, `maxgold`=11000 WHERE `entry`=830097;
UPDATE `creature_template` SET `lootid`=830098, `mingold`=9000, `maxgold`=13000 WHERE `entry`=830098;

-- Doomlord: 5-8 gold  (world boss equivalent)
UPDATE `creature_template` SET `lootid`=830072, `mingold`=50000, `maxgold`=80000 WHERE `entry`=830072;

-- =============================================================================
-- creature_loot_template
-- Columns: Entry, Item, Reference, Chance, QuestRequired, LootMode,
--          GroupId, MinCount, MaxCount, Comment
--
-- GroupId > 0: pick exactly one item at random from the group (equal weight).
-- GroupId = 0: each item rolls independently.
-- =============================================================================
DELETE FROM `creature_loot_template`
WHERE `Entry` IN (
    830040,830041,830042,830050,830051,830052,
    830060,830061,830062,830070,830071,830072,830073,
    830091,830092,830093,830094,830095,830096,830097,830098
);

INSERT INTO `creature_loot_template`
    (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,
     `GroupId`,`MinCount`,`MaxCount`,`Comment`)
VALUES

-- ── Foothills (80-90) ─────────────────────────────────────────────────────────
-- Charred Ghoul: 8% chance at a Foothills ring (group of 5 → pick 1)
(830040, 400011, 0, 8, 0, 1, 1, 1, 1, 'Emberwood Sage Ring - group pick'),
(830040, 400012, 0, 8, 0, 1, 1, 1, 1, 'Emberwood Mender Ring'),
(830040, 400013, 0, 8, 0, 1, 1, 1, 1, 'Emberwood Stalker Ring'),
(830040, 400014, 0, 8, 0, 1, 1, 1, 1, 'Emberwood Warcaller Band'),
(830040, 400015, 0, 8, 0, 1, 1, 1, 1, 'Emberwood Bulwark Ring'),

-- Ashen Banshee: 8% rare ring + 5% chance at rare cloak via reference pool 14110
(830041, 400011, 0, 5, 0, 1, 1, 1, 1, 'ring group'),
(830041, 400012, 0, 5, 0, 1, 1, 1, 1, 'ring group'),
(830041, 400013, 0, 5, 0, 1, 1, 1, 1, 'ring group'),
(830041, 400014, 0, 5, 0, 1, 1, 1, 1, 'ring group'),
(830041, 400015, 0, 5, 0, 1, 1, 1, 1, 'ring group'),
(830041, 14110, 14110, 4, 0, 1, 0, 1, 1, 'Foothills rare cloak pool'),

-- Blightbone Necromancer (elite-class side-quest mob): better drop chance
(830042, 400016, 0, 12, 0, 1, 1, 1, 1, 'Emberwood Spellweave Cloak group'),
(830042, 400017, 0, 12, 0, 1, 1, 1, 1, 'Emberwood Lifeguard Cloak'),
(830042, 400018, 0, 12, 0, 1, 1, 1, 1, 'Emberwood Skyrunner Cloak'),
(830042, 400019, 0, 12, 0, 1, 1, 1, 1, 'Emberwood Warmarch Cloak'),
(830042, 400020, 0, 12, 0, 1, 1, 1, 1, 'Emberwood Bastion Cloak'),
(830042, 14110, 14110, 8, 0, 1, 0, 1, 1, 'Foothills rare pool'),

-- Foothills Bone Reaver / Deathcaller variants
(830091, 400011, 0, 6, 0, 1, 1, 1, 1, 'ring group'), (830091, 400012, 0, 6, 0, 1, 1, 1, 1, 'ring group'),
(830091, 400013, 0, 6, 0, 1, 1, 1, 1, 'ring group'), (830091, 400014, 0, 6, 0, 1, 1, 1, 1, 'ring group'),
(830092, 400016, 0, 6, 0, 1, 1, 1, 1, 'cloak group'),(830092, 400017, 0, 6, 0, 1, 1, 1, 1, 'cloak group'),
(830092, 400018, 0, 6, 0, 1, 1, 1, 1, 'cloak group'),(830092, 400019, 0, 6, 0, 1, 1, 1, 1, 'cloak group'),

-- ── Scorched Groves (95-105) ──────────────────────────────────────────────────
-- Felfire Stalker: 8% chance at Scorched pendant group
(830050, 400021, 0, 8, 0, 1, 1, 1, 1, 'Skyfire Rune Pendant group'),
(830050, 400022, 0, 8, 0, 1, 1, 1, 1, 'Skyfire Renewal Pendant'),
(830050, 400023, 0, 8, 0, 1, 1, 1, 1, 'Skyfire Talon Pendant'),
(830050, 400024, 0, 8, 0, 1, 1, 1, 1, 'Skyfire Warbrand Pendant'),
(830050, 400025, 0, 8, 0, 1, 1, 1, 1, 'Skyfire Stoneguard Pendant'),

-- Searing Doomguard: pendant + rare ring pool 14111
(830051, 400021, 0, 6, 0, 1, 1, 1, 1, 'pendant group'),
(830051, 400022, 0, 6, 0, 1, 1, 1, 1, 'pendant group'),
(830051, 400023, 0, 6, 0, 1, 1, 1, 1, 'pendant group'),
(830051, 400024, 0, 6, 0, 1, 1, 1, 1, 'pendant group'),
(830051, 400025, 0, 6, 0, 1, 1, 1, 1, 'pendant group'),
(830051, 14111, 14111, 5, 0, 1, 0, 1, 1, 'Scorched rare ring pool'),

-- Infernal Siegebreaker (side-quest elite): rare ring + pendant
(830052, 400026, 0, 14, 0, 1, 1, 1, 1, 'Skyfire Spellseal group'),
(830052, 400027, 0, 14, 0, 1, 1, 1, 1, 'Skyfire Grace Loop'),
(830052, 400028, 0, 14, 0, 1, 1, 1, 1, 'Skyfire Predator Ring'),
(830052, 400029, 0, 14, 0, 1, 1, 1, 1, 'Skyfire Reaver Band'),
(830052, 400030, 0, 14, 0, 1, 1, 1, 1, 'Skyfire Ward Band'),
(830052, 14111, 14111, 9, 0, 1, 0, 1, 1, 'Scorched rare pool'),

-- Scorched Felmaw / Doomflayer variants
(830093, 400021, 0, 7, 0, 1, 1, 1, 1, 'pendant group'), (830093, 400022, 0, 7, 0, 1, 1, 1, 1, 'pendant group'),
(830093, 400023, 0, 7, 0, 1, 1, 1, 1, 'pendant group'), (830093, 400024, 0, 7, 0, 1, 1, 1, 1, 'pendant group'),
(830094, 400026, 0, 7, 0, 1, 1, 1, 1, 'rare ring group'),(830094, 400027, 0, 7, 0, 1, 1, 1, 1, 'rare ring group'),
(830094, 400028, 0, 7, 0, 1, 1, 1, 1, 'rare ring group'),(830094, 400029, 0, 7, 0, 1, 1, 1, 1, 'rare ring group'),

-- ── The Summit (110-120) ──────────────────────────────────────────────────────
-- Summit Gargoyle: 8% Summit cloak group
(830060, 400031, 0, 8, 0, 1, 1, 1, 1, 'Nordrassil Spellguard Cloak group'),
(830060, 400032, 0, 8, 0, 1, 1, 1, 1, 'Nordrassil Mercy Cloak'),
(830060, 400033, 0, 8, 0, 1, 1, 1, 1, 'Nordrassil Huntcloak'),
(830060, 400034, 0, 8, 0, 1, 1, 1, 1, 'Nordrassil Warcloak'),
(830060, 400035, 0, 8, 0, 1, 1, 1, 1, 'Nordrassil Barkcloak'),

-- Shadow Crypt Fiend: cloak + rare pendant pool 14112
(830061, 400031, 0, 6, 0, 1, 1, 1, 1, 'cloak group'),
(830061, 400032, 0, 6, 0, 1, 1, 1, 1, 'cloak group'),
(830061, 400033, 0, 6, 0, 1, 1, 1, 1, 'cloak group'),
(830061, 400034, 0, 6, 0, 1, 1, 1, 1, 'cloak group'),
(830061, 400035, 0, 6, 0, 1, 1, 1, 1, 'cloak group'),
(830061, 14112, 14112, 5, 0, 1, 0, 1, 1, 'Nordrassil rare pendant pool'),

-- Frostgrave Lich (side-quest caster elite): full rare pendant + T3 cloak
(830062, 400036, 0, 14, 0, 1, 1, 1, 1, 'Nordrassil Starfire Pendant group'),
(830062, 400037, 0, 14, 0, 1, 1, 1, 1, 'Nordrassil Dreamwell Pendant'),
(830062, 400038, 0, 14, 0, 1, 1, 1, 1, 'Nordrassil Razorleaf Pendant'),
(830062, 400039, 0, 14, 0, 1, 1, 1, 1, 'Nordrassil Worldbreaker Pendant'),
(830062, 400040, 0, 14, 0, 1, 1, 1, 1, 'Nordrassil Timewarden Pendant'),
(830062, 14112, 14112, 9, 0, 1, 0, 1, 1, 'Nordrassil rare pool'),

-- Summit Boneweaver / Gravewing
(830095, 400031, 0, 7, 0, 1, 1, 1, 1, 'cloak group'), (830095, 400032, 0, 7, 0, 1, 1, 1, 1, 'cloak group'),
(830095, 400033, 0, 7, 0, 1, 1, 1, 1, 'cloak group'), (830095, 400034, 0, 7, 0, 1, 1, 1, 1, 'cloak group'),
(830096, 400036, 0, 7, 0, 1, 1, 1, 1, 'pendant group'),(830096, 400037, 0, 7, 0, 1, 1, 1, 1, 'pendant group'),
(830096, 400038, 0, 7, 0, 1, 1, 1, 1, 'pendant group'),(830096, 400039, 0, 7, 0, 1, 1, 1, 1, 'pendant group'),

-- ── Nordrassil Roots (125-130) ────────────────────────────────────────────────
-- Rotmaw Abomination: 10% T4 rare pendant group
(830070, 400036, 0, 10, 0, 1, 1, 1, 1, 'Nordrassil Starfire Pendant group'),
(830070, 400037, 0, 10, 0, 1, 1, 1, 1, 'Nordrassil Dreamwell Pendant'),
(830070, 400038, 0, 10, 0, 1, 1, 1, 1, 'Nordrassil Razorleaf Pendant'),
(830070, 400039, 0, 10, 0, 1, 1, 1, 1, 'Nordrassil Worldbreaker Pendant'),
(830070, 400040, 0, 10, 0, 1, 1, 1, 1, 'Nordrassil Timewarden Pendant'),

-- Frostbone Wyrm: pendant + T4 trinket chance (400902-400907)
(830071, 400036, 0, 8, 0, 1, 1, 1, 1, 'pendant group'),
(830071, 400037, 0, 8, 0, 1, 1, 1, 1, 'pendant group'),
(830071, 400038, 0, 8, 0, 1, 1, 1, 1, 'pendant group'),
(830071, 400039, 0, 8, 0, 1, 1, 1, 1, 'pendant group'),
(830071, 400902, 0, 5, 0, 1, 0, 1, 1, 'Nordrassil Prism trinket rare'),
(830071, 400903, 0, 5, 0, 1, 0, 1, 1, 'Nordrassil Warstone trinket rare'),

-- Rootfire Infernal (side-quest elite): T4 rare pendant + weapon chance
(830073, 400036, 0, 15, 0, 1, 1, 1, 1, 'pendant group'),
(830073, 400037, 0, 15, 0, 1, 1, 1, 1, 'pendant group'),
(830073, 400038, 0, 15, 0, 1, 1, 1, 1, 'pendant group'),
(830073, 400039, 0, 15, 0, 1, 1, 1, 1, 'pendant group'),
(830073, 400040, 0, 15, 0, 1, 1, 1, 1, 'pendant group'),
(830073, 400869, 0,  5, 0, 1, 0, 1, 1, 'Nordrassil Waraxe T4 rare'),
(830073, 400875, 0,  5, 0, 1, 0, 1, 1, 'Nordrassil Greataxe T4 rare'),
(830073, 400876, 0,  5, 0, 1, 0, 1, 1, 'Nordrassil Staff T4 rare'),

-- Rootbound Colossus / Rootflame Devastator variants
(830097, 400036, 0, 9, 0, 1, 1, 1, 1, 'pendant group'), (830097, 400037, 0, 9, 0, 1, 1, 1, 1, 'pendant group'),
(830097, 400038, 0, 9, 0, 1, 1, 1, 1, 'pendant group'), (830097, 400039, 0, 9, 0, 1, 1, 1, 1, 'pendant group'),
(830097, 400904, 0, 5, 0, 1, 0, 1, 1, 'Nordrassil trinket rare'),
(830098, 400036, 0, 9, 0, 1, 1, 1, 1, 'pendant group'), (830098, 400037, 0, 9, 0, 1, 1, 1, 1, 'pendant group'),
(830098, 400869, 0, 6, 0, 1, 0, 1, 1, 'T4 weapon rare'),(830098, 400870, 0, 6, 0, 1, 0, 1, 1, 'T4 weapon rare'),

-- ── Hyjal Doomlord (830072) ──────────────────────────────────────────────────
-- 100% unique drops, 30% chance at each T4 weapon type (grouped → pick 1)
(830072, 400453, 0, 100, 0, 1, 0, 1, 1, 'Doombane Pauldrons - guaranteed'),
(830072, 400454, 0, 100, 0, 1, 0, 1, 1, 'Doomlord Eye of Chaos - guaranteed'),
-- T4 weapon group (11% each, 9 items → 99% total, pick 1 from group 1)
(830072, 400869, 0, 11, 0, 1, 1, 1, 1, 'Nordrassil Waraxe 1H'),
(830072, 400872, 0, 11, 0, 1, 1, 1, 1, 'Nordrassil Healermace'),
(830072, 400873, 0, 11, 0, 1, 1, 1, 1, 'Nordrassil Blade 1H'),
(830072, 400875, 0, 11, 0, 1, 1, 1, 1, 'Nordrassil Greataxe 2H'),
(830072, 400876, 0, 11, 0, 1, 1, 1, 1, 'Nordrassil Staff 2H'),
(830072, 400877, 0, 11, 0, 1, 1, 1, 1, 'Nordrassil Greatsword 2H'),
(830072, 400878, 0, 11, 0, 1, 1, 1, 1, 'Nordrassil Warbow'),
(830072, 400879, 0, 11, 0, 1, 1, 1, 1, 'Nordrassil Wand'),
(830072, 400880, 0, 11, 0, 1, 1, 1, 1, 'Nordrassil Aegis shield'),
-- T4 trinkets (16% each, 6 items → 96% total, pick 1 from group 2)
(830072, 400902, 0, 16, 0, 1, 2, 1, 1, 'Nordrassil Prism caster trinket'),
(830072, 400903, 0, 16, 0, 1, 2, 1, 1, 'Nordrassil Warstone STR trinket'),
(830072, 400904, 0, 16, 0, 1, 2, 1, 1, 'Nordrassil Razorstone AGI trinket'),
(830072, 400905, 0, 16, 0, 1, 2, 1, 1, 'Nordrassil Lifestone healer trinket'),
(830072, 400906, 0, 16, 0, 1, 2, 1, 1, 'Nordrassil Aegis tank trinket'),
(830072, 400907, 0, 16, 0, 1, 2, 1, 1, 'Nordrassil Clarity utility trinket');

-- =============================================================================
-- Weapon access via Emberwood Quartermaster (T1/T2 only; T3/T4 via quests/drops)
-- Extended costs: 14102 = 30 × Emberwood Sap, 14103 = 50 × Emberwood Sap
-- =============================================================================
DELETE FROM `itemextendedcost_dbc` WHERE `ID` IN (14102, 14103);
INSERT INTO `itemextendedcost_dbc`
    (`ID`,`HonorPoints`,`ArenaPoints`,`ArenaBracket`,
     `ItemID_1`,`ItemID_2`,`ItemID_3`,`ItemID_4`,`ItemID_5`,
     `ItemCount_1`,`ItemCount_2`,`ItemCount_3`,`ItemCount_4`,`ItemCount_5`,
     `RequiredArenaRating`,`ItemPurchaseGroup`)
VALUES
(14102, 0, 0, 0, 400000, 0, 0, 0, 0, 30, 0, 0, 0, 0, 0, 0),
(14103, 0, 0, 0, 400000, 0, 0, 0, 0, 50, 0, 0, 0, 0, 0, 0);

-- Wire T1 weapons (400824-400838) onto both Quartermasters at cost 14102 (30 sap)
DELETE FROM `npc_vendor` WHERE `entry` IN (830024,830147) AND `item` BETWEEN 400824 AND 400853;
INSERT INTO `npc_vendor`
    (`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
VALUES
-- T1 weapons (30 sap)
(830024, 11, 400824, 0, 0, 14102, 0),(830024, 12, 400825, 0, 0, 14102, 0),
(830024, 13, 400826, 0, 0, 14102, 0),(830024, 14, 400827, 0, 0, 14102, 0),
(830024, 15, 400828, 0, 0, 14102, 0),(830024, 16, 400829, 0, 0, 14102, 0),
(830024, 17, 400830, 0, 0, 14102, 0),(830024, 18, 400831, 0, 0, 14102, 0),
(830024, 19, 400832, 0, 0, 14102, 0),(830024, 20, 400833, 0, 0, 14102, 0),
(830024, 21, 400834, 0, 0, 14102, 0),(830024, 22, 400835, 0, 0, 14102, 0),
(830024, 23, 400836, 0, 0, 14102, 0),(830024, 24, 400837, 0, 0, 14102, 0),
(830024, 25, 400838, 0, 0, 14102, 0),
-- T2 weapons (50 sap)
(830024, 26, 400839, 0, 0, 14103, 0),(830024, 27, 400840, 0, 0, 14103, 0),
(830024, 28, 400841, 0, 0, 14103, 0),(830024, 29, 400842, 0, 0, 14103, 0),
(830024, 30, 400843, 0, 0, 14103, 0),(830024, 31, 400844, 0, 0, 14103, 0),
(830024, 32, 400845, 0, 0, 14103, 0),(830024, 33, 400846, 0, 0, 14103, 0),
(830024, 34, 400847, 0, 0, 14103, 0),(830024, 35, 400848, 0, 0, 14103, 0),
(830024, 36, 400849, 0, 0, 14103, 0),(830024, 37, 400850, 0, 0, 14103, 0),
(830024, 38, 400851, 0, 0, 14103, 0),(830024, 39, 400852, 0, 0, 14103, 0),
(830024, 40, 400853, 0, 0, 14103, 0),
-- Horde mirror
(830147, 11, 400824, 0, 0, 14102, 0),(830147, 12, 400825, 0, 0, 14102, 0),
(830147, 13, 400826, 0, 0, 14102, 0),(830147, 14, 400827, 0, 0, 14102, 0),
(830147, 15, 400828, 0, 0, 14102, 0),(830147, 16, 400829, 0, 0, 14102, 0),
(830147, 17, 400830, 0, 0, 14102, 0),(830147, 18, 400831, 0, 0, 14102, 0),
(830147, 19, 400832, 0, 0, 14102, 0),(830147, 20, 400833, 0, 0, 14102, 0),
(830147, 21, 400834, 0, 0, 14102, 0),(830147, 22, 400835, 0, 0, 14102, 0),
(830147, 23, 400836, 0, 0, 14102, 0),(830147, 24, 400837, 0, 0, 14102, 0),
(830147, 25, 400838, 0, 0, 14102, 0),
(830147, 26, 400839, 0, 0, 14103, 0),(830147, 27, 400840, 0, 0, 14103, 0),
(830147, 28, 400841, 0, 0, 14103, 0),(830147, 29, 400842, 0, 0, 14103, 0),
(830147, 30, 400843, 0, 0, 14103, 0),(830147, 31, 400844, 0, 0, 14103, 0),
(830147, 32, 400845, 0, 0, 14103, 0),(830147, 33, 400846, 0, 0, 14103, 0),
(830147, 34, 400847, 0, 0, 14103, 0),(830147, 35, 400848, 0, 0, 14103, 0),
(830147, 36, 400849, 0, 0, 14103, 0),(830147, 37, 400850, 0, 0, 14103, 0),
(830147, 38, 400851, 0, 0, 14103, 0),(830147, 39, 400852, 0, 0, 14103, 0),
(830147, 40, 400853, 0, 0, 14103, 0);
