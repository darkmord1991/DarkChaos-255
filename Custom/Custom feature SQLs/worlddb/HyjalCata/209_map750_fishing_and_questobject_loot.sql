-- ============================================================================
-- 209_map750_fishing_and_questobject_loot.sql
--
-- Map 750 (Hyjal Frontier) - second pass over the Cata import (+3,600,000).
-- Companion to 208_map750_cata_herbs_and_chest_loot.sql.
--
-- Found by diffing every map-750 clone's Data0..Data7 against its
-- cata_world.gameobject_template source. 22 entries differ; this file covers
-- the 10 that are genuine zeroed-loot regressions.
--
-- Correction to 208's closing notes: the quest objectives listed there as
-- "no loot in cata_world either" DO have loot ids in cata_world. That earlier
-- check queried a fixed id list that did not include them. They are wired below.
--
-- All 9 loot template ids used here were confirmed free in acore_world.
--
-- APPLY 210 AFTER THIS FILE. It replaces Mountain Trout's placeholder icon with
-- the real one and unblocks the three objects listed at the bottom of this file.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Missing fish item for the Mountain Trout School pools.
--
-- Modelled on the existing WotLK fish rows (41808 Bonescale Snapper,
-- 41801 Moonglow Cuttlefish): class 7 / subclass 8, quality 1, Material -1,
-- FoodType 2. stackable is set to 20 to match every other fish on this server
-- rather than the Cata value.
--
-- displayid 51803 is a PLACEHOLDER (Bonescale Snapper). There is no Mountain
-- Trout row in Custom/CSV DBC/ItemDisplayInfo.csv and no trout icon in the
-- retail extracts - see notes at end of file.
-- ----------------------------------------------------------------------------

DELETE FROM `item_template` WHERE `entry` = 53063;
INSERT INTO `item_template`
    (`entry`, `class`, `subclass`, `SoundOverrideSubclass`, `name`, `displayid`, `Quality`,
     `Flags`, `FlagsExtra`, `BuyCount`, `BuyPrice`, `SellPrice`, `InventoryType`,
     `AllowableClass`, `AllowableRace`, `ItemLevel`, `RequiredLevel`, `RequiredSkill`,
     `RequiredSkillRank`, `maxcount`, `stackable`, `bonding`, `Material`, `sheath`,
     `BagFamily`, `FoodType`, `VerifiedBuild`)
VALUES
    (53063, 7, 8, -1, 'Mountain Trout', 51803, 1, 0, 0, 1, 160, 8, 0, -1, -1, 70, 0, 0, 0, 0, 20, 0, -1, 0, 0, 2, 0);

-- ----------------------------------------------------------------------------
-- 2a. Fishing pools (type 25). QuestRequired = 0 - these go live immediately.
--     48 spawns on map 750 that currently yield nothing when fished.
-- ----------------------------------------------------------------------------

DELETE FROM `gameobject_loot_template` WHERE `Entry` IN (28553, 38652);
INSERT INTO `gameobject_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
VALUES
    (28553, 53063, 0, 90.00, 0, 1, 1, 1, 1, 'Mountain Trout'),
    (28553, 52326, 0,  9.98, 0, 1, 1, 1, 1, 'Volatile Water'),
    (28553, 22739, 0,  0.01, 0, 1, 1, 1, 1, 'Tome of Polymorph: Turtle'),
    (28553, 46109, 0,  0.01, 0, 1, 1, 1, 1, 'Sea Turtle'),
    (38652, 52325, 0,   100, 0, 1, 0, 1, 1, 'Volatile Fire');

-- ----------------------------------------------------------------------------
-- 2b. Quest objectives (QuestRequired = 1). Inert until the Cata quest layer
--     for map 750 is downported, correct from that moment on.
--     Every item id below was confirmed to exist in item_template.
-- ----------------------------------------------------------------------------

DELETE FROM `gameobject_loot_template` WHERE `Entry` IN (28627, 29639, 28603, 29549, 29580, 28489, 28444);
INSERT INTO `gameobject_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
VALUES
    (28627, 54574, 0, 100, 1, 1, 0, 1, 1, 'Hyjal Seedling'),
    (29639, 56176, 0, 100, 1, 1, 0, 1, 1, 'Warden\'s Arrow'),
    (28603, 54461, 0, 100, 1, 1, 0, 1, 1, 'Charred Staff Fragment'),
    (29549, 55189, 0, 100, 1, 1, 0, 1, 1, 'Hyjal Egg'),
    (29580, 55809, 0, 100, 1, 1, 0, 1, 1, 'Twilight Armor Plate'),
    (28489, 52834, 0, 100, 1, 1, 0, 1, 1, 'Charged Condenser Jar'),
    (28444, 52728, 0, 100, 1, 1, 0, 1, 1, 'Darkflame Ember');

-- ----------------------------------------------------------------------------
-- 3. Point the map-750 clones at their loot templates.
--    For type 25 (fishing hole) and type 3 (chest) alike, Data1 is the lootId.
-- ----------------------------------------------------------------------------

UPDATE `gameobject_template` SET `Data1` = 28553 WHERE `entry` = 3802776;  -- Mountain Trout School (45 spawns)
UPDATE `gameobject_template` SET `Data1` = 38652 WHERE `entry` = 3807734;  -- Pool of Fire (3 spawns)
UPDATE `gameobject_template` SET `Data1` = 28627 WHERE `entry` = 3802884;  -- Scorched Soil (69 spawns)
UPDATE `gameobject_template` SET `Data1` = 29639 WHERE `entry` = 3803310;  -- Warden's Arrow (47 spawns)
UPDATE `gameobject_template` SET `Data1` = 28603 WHERE `entry` = 3802846;  -- Charred Staff Fragment (30 spawns)
UPDATE `gameobject_template` SET `Data1` = 29549 WHERE `entry` = 3803143;  -- Stolen Hyjal Egg (30 spawns)
UPDATE `gameobject_template` SET `Data1` = 29580 WHERE `entry` = 3803197;  -- Twilight Armor Plate (15 spawns)
UPDATE `gameobject_template` SET `Data1` = 29580 WHERE `entry` = 3803198;  -- Twilight Armor Plate (10 spawns)
UPDATE `gameobject_template` SET `Data1` = 28489 WHERE `entry` = 3802731;  -- Lightning Channel (8 spawns)
UPDATE `gameobject_template` SET `Data1` = 28444 WHERE `entry` = 3802705;  -- Darkflame Ember (3 spawns)

-- ============================================================================
-- STILL BLOCKED - quest item does not exist in item_template
--
--   3804580  Gar'gol's Personal Treasure Chest  -> 52789
--   3802968  Crate of Scrolls                   -> 52724
--   3802969  Hyjal Battleplans                  -> 52725
--
--   These three need their items created before the loot can be wired.
--   cata_world has no item_template, so the stats would have to come from the
--   Cata client (K:\UntouchedClients\Cata, Item.db2 + ItemSparse) rather than
--   being cloned from an existing row like the herbs and fish above.
--
-- INTENTIONAL DIFFS - flagged by the sweep, correct as-is, NOT changed
--
--   3803187  Harpy Signal Fire   Data3 3803189 vs cata 203189. Ours is the
--                                correctly re-offset pointer to the map-750
--                                clone. Leaving it would be the bug.
--   3809080  Portal to Stormwind Data0 300600 vs cata 84505
--   3809081  Portal to Orgrimmar Data0 300601 vs cata 84506
--                                Custom DC teleport spells; the Cata spell ids
--                                do not exist on this core.
--   3792489  Anvil               Data0 1  vs cata 599
--   3792490  Forge               Data0 3  vs cata 599
--                                SpellFocusObject ids remapped to WotLK values.
--
--   3780523 Apple Bob, 3776588 Icecap, 3601622 Bruiseweed, 3602043 Khadgar's
--   Whisker differ only in lockId and are almost certainly false positives:
--   these entries did not come from cata_world, so the -3,600,000 join lands
--   on an unrelated object that happens to share the name. Our lock values are
--   the WotLK-correct ones. Not touched.
--
-- OFFSET CORRECTION
--
--   +3,600,000 is the cata_world offset but it is NOT the only one in use on
--   map 750. Of 365 map-750 templates in the 3.6M-3.99M band, only 172 resolve
--   against cata_world at -3,600,000; the other 193 came from other sources
--   and passes (nelt_world and stock WotLK are visible at other offsets).
--   Any future sweep has to resolve the offset per source, not assume one.
--
-- CLIENT-SIDE FOLLOW-UP
--
--   Mountain Trout (53063) ships with a placeholder icon. Its real icon has no
--   ItemDisplayInfo.csv row and is not in K:\Dark-Chaos\retailextracts; it needs
--   the same extract -> CSV row -> csv2wdbc.py -> mpq_stormlib_patch.py (patch-4)
--   path as Azshara's Veil and Whiptail in 208, then a displayid update here.
-- ============================================================================
