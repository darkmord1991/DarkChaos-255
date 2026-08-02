-- ============================================================================
-- 208_map750_cata_herbs_and_chest_loot.sql
--
-- Map 750 (Hyjal Frontier) - restore loot on Cata-imported gatherable/chest
-- gameobjects that were imported with Data1 (lootId) zeroed.
--
-- Background
--   The Cata import offset is +3,600,000 (cata_world 202748 -> 3802748).
--   Locks (Data0) were copied correctly, but 22 type=3 objects landed with
--   Data1 = 0, so they open and yield nothing. Cinderbloom (3802747) was the
--   only Cata herb that kept its loot id (28521) and it works today - this
--   file follows exactly that pattern.
--
--   NOTE: the Solid Chests (3902850 / 4053451 / 4053454) are NOT affected.
--   They already carry lock 57 and loot 3902281 / 3909931 / 3909933 with
--   712 / 726 / 489 rows and zero dangling item ids.
--
-- Source of every value below: cata_world.gameobject_template and
-- cata_world.gameobject_loot_template, read verbatim.
--
-- APPLY 210 AFTER THIS FILE. The herb stats and the two placeholder displayids
-- below were modelled on the existing Cinderbloom row before the Cata client
-- was available; 210 replaces them with the real values and icons.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Missing Cataclysm herb items
--
-- Modelled on the two Cata herbs already present and working on this server:
--   52983 Cinderbloom  (display 75397, 8127/2031)
--   52986 Heartblossom (display 75401, 8872/2218)
-- Every stat below is copied from one of those two verified rows; nothing is
-- invented except BagFamily (see note) and the two placeholder displayids.
--
-- displayid provenance:
--   52984 Stormvine        -> 8458176  VERIFIED present in Custom/CSV DBC/ItemDisplayInfo.csv
--                                      (icon inv_misc_herb_stormvine)
--   52987 Twilight Jasmine -> 8458235  VERIFIED present in the same CSV
--                                      (icon inv_misc_herb_twilightjasmine)
--   52985 Azshara's Veil   -> 18089    PLACEHOLDER (Stranglekelp). The real icon
--                                      inv_misc_herb_azsharasveil.blp has not been
--                                      extracted yet - see notes at end of file.
--   52988 Whiptail         -> 37394    PLACEHOLDER (Nightmare Vine). Same reason.
--
-- BagFamily is set to 32 (Herbs) so these route into herb bags. Cinderbloom and
-- Heartblossom currently have BagFamily 0, which is a downport bug on those two
-- rows; it is deliberately NOT touched here.
-- ----------------------------------------------------------------------------

DELETE FROM `item_template` WHERE `entry` IN (52984, 52985, 52987, 52988);
INSERT INTO `item_template`
    (`entry`, `class`, `subclass`, `SoundOverrideSubclass`, `name`, `displayid`, `Quality`,
     `Flags`, `FlagsExtra`, `BuyCount`, `BuyPrice`, `SellPrice`, `InventoryType`,
     `AllowableClass`, `AllowableRace`, `ItemLevel`, `RequiredLevel`, `RequiredSkill`,
     `RequiredSkillRank`, `maxcount`, `stackable`, `bonding`, `Material`, `sheath`,
     `BagFamily`, `VerifiedBuild`)
VALUES
    (52984, 7, 9, -1, 'Stormvine',        8458176, 1, 0, 0, 1, 8127, 2031, 0, -1, -1, 25, 0, 0, 0, 0, 1000, 0, 7, 0, 32, 0),
    (52985, 7, 9, -1, 'Azshara\'s Veil',    18089, 1, 0, 0, 1, 8872, 2218, 0, -1, -1, 25, 0, 0, 0, 0, 1000, 0, 7, 0, 32, 0),
    (52987, 7, 9, -1, 'Twilight Jasmine', 8458235, 1, 0, 0, 1, 8872, 2218, 0, -1, -1, 25, 0, 0, 0, 0, 1000, 0, 7, 0, 32, 0),
    (52988, 7, 9, -1, 'Whiptail',           37394, 1, 0, 0, 1, 8872, 2218, 0, -1, -1, 25, 0, 0, 0, 0, 1000, 0, 7, 0, 32, 0);

-- ----------------------------------------------------------------------------
-- 2. Loot templates
--
-- 2a. Real herbalism nodes (QuestRequired = 0) - these become gatherable the
--     moment this file is applied. 57 spawns on map 750.
-- ----------------------------------------------------------------------------

DELETE FROM `gameobject_loot_template` WHERE `Entry` IN (28522, 28523);
INSERT INTO `gameobject_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
VALUES
    (28522, 52984, 0, 100, 0, 1, 0, 2, 4, 'Stormvine'),
    (28522, 52329, 0,  25, 0, 1, 0, 1, 4, 'Volatile Life'),
    (28522, 63122, 0,  10, 0, 1, 0, 1, 1, 'Lifegiving Seed'),
    (28523, 52985, 0, 100, 0, 1, 0, 2, 4, 'Azshara\'s Veil'),
    (28523, 52329, 0,  25, 0, 1, 0, 1, 4, 'Volatile Life'),
    (28523, 63122, 0,  10, 0, 1, 0, 1, 1, 'Lifegiving Seed');

-- ----------------------------------------------------------------------------
-- 2b. Quest-gated objects (QuestRequired = 1).
--
--     These only drop for a player who is on the matching Cata quest. That
--     quest layer is not downported yet, so applying this changes nothing
--     visible TODAY - it makes the objects correct for when the quests land,
--     and stops them being silent dead ends in the meantime.
--
--     Every item id below was confirmed to already exist in item_template.
-- ----------------------------------------------------------------------------

DELETE FROM `gameobject_loot_template` WHERE `Entry` IN (28423, 28442, 28443, 28528, 39495, 29512, 29513, 29514, 29520);
INSERT INTO `gameobject_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
VALUES
    (28423, 52537, 0, 100, 1, 1, 0, 1, 1, 'Flame Blossom'),
    (28442, 52726, 0, 100, 1, 1, 0, 1, 1, 'Stonebloom'),
    (28443, 52727, 0, 100, 1, 1, 0, 1, 1, 'Bitterblossom'),
    (28528, 53009, 0, 100, 1, 1, 0, 1, 1, 'Juniper Berries'),
    (39495, 69236, 0, 100, 1, 1, 0, 1, 1, 'Blueroot Vine'),
    (29512, 54905, 0, 100, 1, 1, 0, 1, 1, 'Tome of Flame'),
    (29513, 54906, 0, 100, 1, 1, 0, 1, 1, 'The Burning Litanies'),
    (29514, 54907, 0, 100, 1, 1, 0, 1, 1, 'Ascendant\'s Codex'),
    (29520, 55136, 0, 100, 1, 1, 0, 1, 1, 'Tome of Openings');

-- ----------------------------------------------------------------------------
-- 3. Point the map-750 clones at their loot templates (Data1 = lootId).
--    Data0 (lockId) is already correct on every row and is not touched.
-- ----------------------------------------------------------------------------

UPDATE `gameobject_template` SET `Data1` = 28522 WHERE `entry` = 3802748;  -- Stormvine (43 spawns)
UPDATE `gameobject_template` SET `Data1` = 28523 WHERE `entry` = 3802749;  -- Azshara's Veil (14 spawns)
UPDATE `gameobject_template` SET `Data1` = 28423 WHERE `entry` = 3802619;  -- Flame Blossom (64 spawns)
UPDATE `gameobject_template` SET `Data1` = 28442 WHERE `entry` = 3802702;  -- Stonebloom (4 spawns)
UPDATE `gameobject_template` SET `Data1` = 28443 WHERE `entry` = 3802703;  -- Bitterblossom (7 spawns)
UPDATE `gameobject_template` SET `Data1` = 28528 WHERE `entry` = 3802754;  -- Juniper Berries (136 spawns)
UPDATE `gameobject_template` SET `Data1` = 39495 WHERE `entry` = 3808442;  -- Blueroot Vine (7 spawns)
UPDATE `gameobject_template` SET `Data1` = 29512 WHERE `entry` = 3803046;  -- Tome of Flame (1 spawn)
UPDATE `gameobject_template` SET `Data1` = 29513 WHERE `entry` = 3803047;  -- Burning Litanies (1 spawn)
UPDATE `gameobject_template` SET `Data1` = 29514 WHERE `entry` = 3803048;  -- Ascendant's Codex (1 spawn)
UPDATE `gameobject_template` SET `Data1` = 29520 WHERE `entry` = 3803089;  -- Battered Stone Chest (1 spawn)

-- ============================================================================
-- DELIBERATELY NOT INCLUDED
--
--   3804580  Gar'gol's Personal Treasure Chest -> needs quest item 52789, which
--            does not exist in item_template on this server.
--   3802968  Crate of Scrolls                  -> needs quest item 52724, same.
--            Wiring either one would point at a dangling item id.
--
--   3802884 Scorched Soil, 3803310 Warden's Arrow, 3803143 Stolen Hyjal Egg,
--   3802846 Charred Staff Fragment, 3803197/3803198 Twilight Armor Plate,
--   3802731 Lightning Channel, 3802705 Darkflame Ember
--            -> quest objectives. These DO have loot ids in cata_world and are
--               wired in 209_map750_fishing_and_questobject_loot.sql.
--
--   3802750 Heartblossom, 3802751 Twilight Jasmine, 3802752 Whiptail
--            -> no gameobject_template rows on this server at all, so items
--               52987 and 52988 have no node to spawn from on map 750 yet.
--               They are created here so the items exist for Deepholm/Uldum
--               content and so the set is complete, as requested.
--
-- CLIENT-SIDE FOLLOW-UP (not doable in SQL)
--
--   Azshara's Veil and Whiptail ship above with placeholder icons. The real
--   ones (inv_misc_herb_azsharasveil.blp, inv_misc_herb_whiptail.blp) are not
--   present in K:\Dark-Chaos\retailextracts - they need extracting from a
--   retail/Cata client, an ItemDisplayInfo.csv row each, then the usual
--   csv2wdbc.py -> mpq_stormlib_patch.py (patch-4) deploy. Once that is done,
--   update item_template.displayid for 52985 and 52988 to the new ids.
-- ============================================================================
