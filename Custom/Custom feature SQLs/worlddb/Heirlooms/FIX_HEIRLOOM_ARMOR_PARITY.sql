-- ===========================================================================
-- Heirloom armor parity - 5 new lines x 8 slots = 40 items
-- ===========================================================================
--
-- Completes the armor-class matrix the cache names always promised. Before
-- this the set had 3 lines (leather tank, leather physical, cloth caster), so
-- plate and mail wearers had no set of their own and no caster had one outside
-- cloth. After this every class has a line in its own armor type:
--
--   EXISTING  leather tank (STA)          300341..300362 odd slots
--   EXISTING  leather physical (STR+AGI)  rogue, feral
--   EXISTING  cloth caster (INT)          mage, priest, warlock
--   NEW  303100-303107  plate physical  (STR+STA)  warrior, ret, DK
--   NEW  303108-303115  plate caster    (INT+STA)  holy paladin
--   NEW  303116-303123  mail physical   (AGI+STA)  hunter, enh shaman
--   NEW  303124-303131  mail caster     (INT+STA)  ele/resto shaman
--   NEW  303132-303139  leather caster  (INT+STA)  balance/resto druid
--
-- !! APPLY THE DBC FIRST !! ScalingStatDistribution.dbc rows 549 (STR+STA),
-- 550 (INT+STA) and 551 (AGI+STA) are new. They are already built and written
-- into client patch-4.MPQ and enGB/patch-enGB-3.MPQ; the server copy still
-- needs pushing plus a worldserver restart. If this SQL lands first the items
-- exist but apply NO stats until the DBC catches up.
--
-- Rows are cloned from the matching-slot existing heirloom with
-- INSERT ... SELECT through a staging table, so all ~130 columns come across
-- correctly and no column list is hand-written (column order in item_template
-- does not match any dump). Only the differing columns are then overridden.
--
-- Static `armor` is scaled off the leather source (mail x2.2, plate x4.0) for
-- tidiness only - ScalingStatValue is non-zero so the curve replaces it at
-- runtime. Wrist and waist carry no armor bit, same as the existing set.
--
-- displayid reuses the existing per-slot art (physical variants take the
-- physical model, casters the caster model). No new ItemDisplayInfo rows, so
-- no extra client work - the plate and mail lines look like their leather
-- counterparts until someone makes dedicated art.
--
-- DC-ItemUpgrade needs NO change: DC.HEIRLOOM_ITEMS registers only the shirt
-- and 300412 for the stat-package path; the other 47 heirlooms (and these 40)
-- use the regular upgrade path.
--
-- Caches: gameobject_template 1991049-1991088 and loot rows on the same ids.
-- go_heirloom_cache.cpp resolves its item from the GO lootId at runtime, so no
-- C++ change and no rebuild.
--
-- NO WORLD SPAWNS ARE CREATED BY THIS FILE, by request. The caches exist as
-- templates with working loot but are not placed anywhere yet, so none of
-- these 40 items is obtainable until you spawn them - in game with
-- `.gobject add <entry>` while standing where you want it, or in Noggit.
-- Entry list for placement is at the bottom of this file.
-- ===========================================================================

USE acore_world;

-- --- staging table (real, not TEMPORARY, so it survives a client that uses
-- --- more than one connection) --------------------------------------------
DROP TABLE IF EXISTS `dc_hl_stage`;
CREATE TABLE `dc_hl_stage` LIKE `item_template`;

DELETE FROM `item_template` WHERE `entry` BETWEEN 303100 AND 303139;


-- --- plate_phys ------------------------------------------------
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300342;
UPDATE `dc_hl_stage` SET `entry` = 303100, `name` = 'Heirloom Plate Helm of Conquest', `subclass` = 4, `displayid` = 50002,
    `armor` = 400, `ScalingStatDistribution` = 549, `ScalingStatValue` = 264,
    `stat_type1` = 4, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Plate Helm of Conquest [STR+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300345;
UPDATE `dc_hl_stage` SET `entry` = 303101, `name` = 'Heirloom Plate Spaulders of Conquest', `subclass` = 4, `displayid` = 50005,
    `armor` = 360, `ScalingStatDistribution` = 549, `ScalingStatValue` = 257,
    `stat_type1` = 4, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Plate Spaulders of Conquest [STR+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300348;
UPDATE `dc_hl_stage` SET `entry` = 303102, `name` = 'Heirloom Plate Chestguard of Conquest', `subclass` = 4, `displayid` = 50008,
    `armor` = 600, `ScalingStatDistribution` = 549, `ScalingStatValue` = 8388616,
    `stat_type1` = 4, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Plate Chestguard of Conquest [STR+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300351;
UPDATE `dc_hl_stage` SET `entry` = 303103, `name` = 'Heirloom Plate Bracers of Conquest', `subclass` = 4, `displayid` = 50011,
    `armor` = 240, `ScalingStatDistribution` = 549, `ScalingStatValue` = 262144,
    `stat_type1` = 4, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Plate Bracers of Conquest [STR+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300354;
UPDATE `dc_hl_stage` SET `entry` = 303104, `name` = 'Heirloom Plate Gauntlets of Conquest', `subclass` = 4, `displayid` = 50014,
    `armor` = 320, `ScalingStatDistribution` = 549, `ScalingStatValue` = 257,
    `stat_type1` = 4, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Plate Gauntlets of Conquest [STR+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300357;
UPDATE `dc_hl_stage` SET `entry` = 303105, `name` = 'Heirloom Plate Girdle of Conquest', `subclass` = 4, `displayid` = 50017,
    `armor` = 300, `ScalingStatDistribution` = 549, `ScalingStatValue` = 1,
    `stat_type1` = 4, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Plate Girdle of Conquest [STR+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300360;
UPDATE `dc_hl_stage` SET `entry` = 303106, `name` = 'Heirloom Plate Legguards of Conquest', `subclass` = 4, `displayid` = 50020,
    `armor` = 480, `ScalingStatDistribution` = 549, `ScalingStatValue` = 8388616,
    `stat_type1` = 4, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Plate Legguards of Conquest [STR+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300363;
UPDATE `dc_hl_stage` SET `entry` = 303107, `name` = 'Heirloom Plate Boots of Conquest', `subclass` = 4, `displayid` = 50023,
    `armor` = 360, `ScalingStatDistribution` = 549, `ScalingStatValue` = 257,
    `stat_type1` = 4, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Plate Boots of Conquest [STR+STA]

-- --- plate_cast ------------------------------------------------
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300342;
UPDATE `dc_hl_stage` SET `entry` = 303108, `name` = 'Heirloom Plate Helm of Light', `subclass` = 4, `displayid` = 50003,
    `armor` = 400, `ScalingStatDistribution` = 550, `ScalingStatValue` = 264,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Plate Helm of Light [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300345;
UPDATE `dc_hl_stage` SET `entry` = 303109, `name` = 'Heirloom Plate Spaulders of Light', `subclass` = 4, `displayid` = 50006,
    `armor` = 360, `ScalingStatDistribution` = 550, `ScalingStatValue` = 257,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Plate Spaulders of Light [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300348;
UPDATE `dc_hl_stage` SET `entry` = 303110, `name` = 'Heirloom Plate Chestguard of Light', `subclass` = 4, `displayid` = 50009,
    `armor` = 600, `ScalingStatDistribution` = 550, `ScalingStatValue` = 8388616,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Plate Chestguard of Light [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300351;
UPDATE `dc_hl_stage` SET `entry` = 303111, `name` = 'Heirloom Plate Bracers of Light', `subclass` = 4, `displayid` = 50012,
    `armor` = 240, `ScalingStatDistribution` = 550, `ScalingStatValue` = 262144,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Plate Bracers of Light [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300354;
UPDATE `dc_hl_stage` SET `entry` = 303112, `name` = 'Heirloom Plate Gauntlets of Light', `subclass` = 4, `displayid` = 50015,
    `armor` = 320, `ScalingStatDistribution` = 550, `ScalingStatValue` = 257,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Plate Gauntlets of Light [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300357;
UPDATE `dc_hl_stage` SET `entry` = 303113, `name` = 'Heirloom Plate Girdle of Light', `subclass` = 4, `displayid` = 50018,
    `armor` = 300, `ScalingStatDistribution` = 550, `ScalingStatValue` = 1,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Plate Girdle of Light [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300360;
UPDATE `dc_hl_stage` SET `entry` = 303114, `name` = 'Heirloom Plate Legguards of Light', `subclass` = 4, `displayid` = 50021,
    `armor` = 480, `ScalingStatDistribution` = 550, `ScalingStatValue` = 8388616,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Plate Legguards of Light [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300363;
UPDATE `dc_hl_stage` SET `entry` = 303115, `name` = 'Heirloom Plate Boots of Light', `subclass` = 4, `displayid` = 50024,
    `armor` = 360, `ScalingStatDistribution` = 550, `ScalingStatValue` = 257,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Plate Boots of Light [INT+STA]

-- --- mail_phys -------------------------------------------------
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300342;
UPDATE `dc_hl_stage` SET `entry` = 303116, `name` = 'Heirloom Mail Helm of the Hunt', `subclass` = 3, `displayid` = 50002,
    `armor` = 220, `ScalingStatDistribution` = 551, `ScalingStatValue` = 136,
    `stat_type1` = 3, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Mail Helm of the Hunt [AGI+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300345;
UPDATE `dc_hl_stage` SET `entry` = 303117, `name` = 'Heirloom Mail Spaulders of the Hunt', `subclass` = 3, `displayid` = 50005,
    `armor` = 198, `ScalingStatDistribution` = 551, `ScalingStatValue` = 129,
    `stat_type1` = 3, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Mail Spaulders of the Hunt [AGI+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300348;
UPDATE `dc_hl_stage` SET `entry` = 303118, `name` = 'Heirloom Mail Chestguard of the Hunt', `subclass` = 3, `displayid` = 50008,
    `armor` = 330, `ScalingStatDistribution` = 551, `ScalingStatValue` = 4194312,
    `stat_type1` = 3, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Mail Chestguard of the Hunt [AGI+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300351;
UPDATE `dc_hl_stage` SET `entry` = 303119, `name` = 'Heirloom Mail Bracers of the Hunt', `subclass` = 3, `displayid` = 50011,
    `armor` = 132, `ScalingStatDistribution` = 551, `ScalingStatValue` = 262144,
    `stat_type1` = 3, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Mail Bracers of the Hunt [AGI+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300354;
UPDATE `dc_hl_stage` SET `entry` = 303120, `name` = 'Heirloom Mail Gauntlets of the Hunt', `subclass` = 3, `displayid` = 50014,
    `armor` = 176, `ScalingStatDistribution` = 551, `ScalingStatValue` = 129,
    `stat_type1` = 3, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Mail Gauntlets of the Hunt [AGI+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300357;
UPDATE `dc_hl_stage` SET `entry` = 303121, `name` = 'Heirloom Mail Girdle of the Hunt', `subclass` = 3, `displayid` = 50017,
    `armor` = 165, `ScalingStatDistribution` = 551, `ScalingStatValue` = 1,
    `stat_type1` = 3, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Mail Girdle of the Hunt [AGI+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300360;
UPDATE `dc_hl_stage` SET `entry` = 303122, `name` = 'Heirloom Mail Legguards of the Hunt', `subclass` = 3, `displayid` = 50020,
    `armor` = 264, `ScalingStatDistribution` = 551, `ScalingStatValue` = 4194312,
    `stat_type1` = 3, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Mail Legguards of the Hunt [AGI+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300363;
UPDATE `dc_hl_stage` SET `entry` = 303123, `name` = 'Heirloom Mail Boots of the Hunt', `subclass` = 3, `displayid` = 50023,
    `armor` = 198, `ScalingStatDistribution` = 551, `ScalingStatValue` = 129,
    `stat_type1` = 3, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Mail Boots of the Hunt [AGI+STA]

-- --- mail_cast -------------------------------------------------
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300342;
UPDATE `dc_hl_stage` SET `entry` = 303124, `name` = 'Heirloom Mail Helm of Elements', `subclass` = 3, `displayid` = 50003,
    `armor` = 220, `ScalingStatDistribution` = 550, `ScalingStatValue` = 136,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Mail Helm of Elements [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300345;
UPDATE `dc_hl_stage` SET `entry` = 303125, `name` = 'Heirloom Mail Spaulders of Elements', `subclass` = 3, `displayid` = 50006,
    `armor` = 198, `ScalingStatDistribution` = 550, `ScalingStatValue` = 129,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Mail Spaulders of Elements [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300348;
UPDATE `dc_hl_stage` SET `entry` = 303126, `name` = 'Heirloom Mail Chestguard of Elements', `subclass` = 3, `displayid` = 50009,
    `armor` = 330, `ScalingStatDistribution` = 550, `ScalingStatValue` = 4194312,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Mail Chestguard of Elements [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300351;
UPDATE `dc_hl_stage` SET `entry` = 303127, `name` = 'Heirloom Mail Bracers of Elements', `subclass` = 3, `displayid` = 50012,
    `armor` = 132, `ScalingStatDistribution` = 550, `ScalingStatValue` = 262144,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Mail Bracers of Elements [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300354;
UPDATE `dc_hl_stage` SET `entry` = 303128, `name` = 'Heirloom Mail Gauntlets of Elements', `subclass` = 3, `displayid` = 50015,
    `armor` = 176, `ScalingStatDistribution` = 550, `ScalingStatValue` = 129,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Mail Gauntlets of Elements [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300357;
UPDATE `dc_hl_stage` SET `entry` = 303129, `name` = 'Heirloom Mail Girdle of Elements', `subclass` = 3, `displayid` = 50018,
    `armor` = 165, `ScalingStatDistribution` = 550, `ScalingStatValue` = 1,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Mail Girdle of Elements [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300360;
UPDATE `dc_hl_stage` SET `entry` = 303130, `name` = 'Heirloom Mail Legguards of Elements', `subclass` = 3, `displayid` = 50021,
    `armor` = 264, `ScalingStatDistribution` = 550, `ScalingStatValue` = 4194312,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Mail Legguards of Elements [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300363;
UPDATE `dc_hl_stage` SET `entry` = 303131, `name` = 'Heirloom Mail Boots of Elements', `subclass` = 3, `displayid` = 50024,
    `armor` = 198, `ScalingStatDistribution` = 550, `ScalingStatValue` = 129,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Mail Boots of Elements [INT+STA]

-- --- leather_cast ----------------------------------------------
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300342;
UPDATE `dc_hl_stage` SET `entry` = 303132, `name` = 'Heirloom Leather Helm of the Grove', `subclass` = 2, `displayid` = 50003,
    `armor` = 100, `ScalingStatDistribution` = 550, `ScalingStatValue` = 72,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Leather Helm of the Grove [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300345;
UPDATE `dc_hl_stage` SET `entry` = 303133, `name` = 'Heirloom Leather Spaulders of the Grove', `subclass` = 2, `displayid` = 50006,
    `armor` = 90, `ScalingStatDistribution` = 550, `ScalingStatValue` = 65,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Leather Spaulders of the Grove [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300348;
UPDATE `dc_hl_stage` SET `entry` = 303134, `name` = 'Heirloom Leather Chestguard of the Grove', `subclass` = 2, `displayid` = 50009,
    `armor` = 150, `ScalingStatDistribution` = 550, `ScalingStatValue` = 2097160,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Leather Chestguard of the Grove [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300351;
UPDATE `dc_hl_stage` SET `entry` = 303135, `name` = 'Heirloom Leather Bracers of the Grove', `subclass` = 2, `displayid` = 50012,
    `armor` = 60, `ScalingStatDistribution` = 550, `ScalingStatValue` = 262144,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Leather Bracers of the Grove [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300354;
UPDATE `dc_hl_stage` SET `entry` = 303136, `name` = 'Heirloom Leather Gauntlets of the Grove', `subclass` = 2, `displayid` = 50015,
    `armor` = 80, `ScalingStatDistribution` = 550, `ScalingStatValue` = 65,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Leather Gauntlets of the Grove [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300357;
UPDATE `dc_hl_stage` SET `entry` = 303137, `name` = 'Heirloom Leather Girdle of the Grove', `subclass` = 2, `displayid` = 50018,
    `armor` = 75, `ScalingStatDistribution` = 550, `ScalingStatValue` = 1,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Leather Girdle of the Grove [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300360;
UPDATE `dc_hl_stage` SET `entry` = 303138, `name` = 'Heirloom Leather Legguards of the Grove', `subclass` = 2, `displayid` = 50021,
    `armor` = 120, `ScalingStatDistribution` = 550, `ScalingStatValue` = 2097160,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Leather Legguards of the Grove [INT+STA]
TRUNCATE `dc_hl_stage`;
INSERT INTO `dc_hl_stage` SELECT * FROM `item_template` WHERE `entry` = 300363;
UPDATE `dc_hl_stage` SET `entry` = 303139, `name` = 'Heirloom Leather Boots of the Grove', `subclass` = 2, `displayid` = 50024,
    `armor` = 90, `ScalingStatDistribution` = 550, `ScalingStatValue` = 65,
    `stat_type1` = 5, `stat_value1` = 30, `stat_type2` = 7, `stat_value2` = 30;
INSERT INTO `item_template` SELECT * FROM `dc_hl_stage`;   -- Heirloom Leather Boots of the Grove [INT+STA]

DROP TABLE `dc_hl_stage`;

-- --- cache gameobjects (cloned from 1991010 so type/display/ScriptName match) -
DROP TABLE IF EXISTS `dc_go_stage`;
CREATE TABLE `dc_go_stage` LIKE `gameobject_template`;
DELETE FROM `gameobject_template` WHERE `entry` BETWEEN 1991049 AND 1991088;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991049, `Data1` = 1991049, `name` = 'Helm Cache - Plate Helm of Conquest';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991050, `Data1` = 1991050, `name` = 'Spaulders Cache - Plate Spaulders of Conquest';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991051, `Data1` = 1991051, `name` = 'Chestguard Cache - Plate Chestguard of Conquest';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991052, `Data1` = 1991052, `name` = 'Bracers Cache - Plate Bracers of Conquest';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991053, `Data1` = 1991053, `name` = 'Gauntlets Cache - Plate Gauntlets of Conquest';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991054, `Data1` = 1991054, `name` = 'Girdle Cache - Plate Girdle of Conquest';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991055, `Data1` = 1991055, `name` = 'Legguards Cache - Plate Legguards of Conquest';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991056, `Data1` = 1991056, `name` = 'Boots Cache - Plate Boots of Conquest';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991057, `Data1` = 1991057, `name` = 'Helm Cache - Plate Helm of Light';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991058, `Data1` = 1991058, `name` = 'Spaulders Cache - Plate Spaulders of Light';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991059, `Data1` = 1991059, `name` = 'Chestguard Cache - Plate Chestguard of Light';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991060, `Data1` = 1991060, `name` = 'Bracers Cache - Plate Bracers of Light';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991061, `Data1` = 1991061, `name` = 'Gauntlets Cache - Plate Gauntlets of Light';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991062, `Data1` = 1991062, `name` = 'Girdle Cache - Plate Girdle of Light';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991063, `Data1` = 1991063, `name` = 'Legguards Cache - Plate Legguards of Light';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991064, `Data1` = 1991064, `name` = 'Boots Cache - Plate Boots of Light';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991065, `Data1` = 1991065, `name` = 'Helm Cache - Mail Helm of the Hunt';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991066, `Data1` = 1991066, `name` = 'Spaulders Cache - Mail Spaulders of the Hunt';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991067, `Data1` = 1991067, `name` = 'Chestguard Cache - Mail Chestguard of the Hunt';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991068, `Data1` = 1991068, `name` = 'Bracers Cache - Mail Bracers of the Hunt';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991069, `Data1` = 1991069, `name` = 'Gauntlets Cache - Mail Gauntlets of the Hunt';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991070, `Data1` = 1991070, `name` = 'Girdle Cache - Mail Girdle of the Hunt';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991071, `Data1` = 1991071, `name` = 'Legguards Cache - Mail Legguards of the Hunt';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991072, `Data1` = 1991072, `name` = 'Boots Cache - Mail Boots of the Hunt';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991073, `Data1` = 1991073, `name` = 'Helm Cache - Mail Helm of Elements';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991074, `Data1` = 1991074, `name` = 'Spaulders Cache - Mail Spaulders of Elements';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991075, `Data1` = 1991075, `name` = 'Chestguard Cache - Mail Chestguard of Elements';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991076, `Data1` = 1991076, `name` = 'Bracers Cache - Mail Bracers of Elements';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991077, `Data1` = 1991077, `name` = 'Gauntlets Cache - Mail Gauntlets of Elements';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991078, `Data1` = 1991078, `name` = 'Girdle Cache - Mail Girdle of Elements';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991079, `Data1` = 1991079, `name` = 'Legguards Cache - Mail Legguards of Elements';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991080, `Data1` = 1991080, `name` = 'Boots Cache - Mail Boots of Elements';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991081, `Data1` = 1991081, `name` = 'Helm Cache - Leather Helm of the Grove';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991082, `Data1` = 1991082, `name` = 'Spaulders Cache - Leather Spaulders of the Grove';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991083, `Data1` = 1991083, `name` = 'Chestguard Cache - Leather Chestguard of the Grove';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991084, `Data1` = 1991084, `name` = 'Bracers Cache - Leather Bracers of the Grove';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991085, `Data1` = 1991085, `name` = 'Gauntlets Cache - Leather Gauntlets of the Grove';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991086, `Data1` = 1991086, `name` = 'Girdle Cache - Leather Girdle of the Grove';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991087, `Data1` = 1991087, `name` = 'Legguards Cache - Leather Legguards of the Grove';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
TRUNCATE `dc_go_stage`;
INSERT INTO `dc_go_stage` SELECT * FROM `gameobject_template` WHERE `entry` = 1991010;
UPDATE `dc_go_stage` SET `entry` = 1991088, `Data1` = 1991088, `name` = 'Boots Cache - Leather Boots of the Grove';
INSERT INTO `gameobject_template` SELECT * FROM `dc_go_stage`;
DROP TABLE `dc_go_stage`;

-- --- cache loot ------------------------------------------------------------
DELETE FROM `gameobject_loot_template` WHERE `Entry` BETWEEN 1991049 AND 1991088;
INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`) VALUES
  (1991049, 303100, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Plate Helm of Conquest
  (1991050, 303101, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Plate Spaulders of Conquest
  (1991051, 303102, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Plate Chestguard of Conquest
  (1991052, 303103, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Plate Bracers of Conquest
  (1991053, 303104, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Plate Gauntlets of Conquest
  (1991054, 303105, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Plate Girdle of Conquest
  (1991055, 303106, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Plate Legguards of Conquest
  (1991056, 303107, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Plate Boots of Conquest
  (1991057, 303108, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Plate Helm of Light
  (1991058, 303109, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Plate Spaulders of Light
  (1991059, 303110, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Plate Chestguard of Light
  (1991060, 303111, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Plate Bracers of Light
  (1991061, 303112, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Plate Gauntlets of Light
  (1991062, 303113, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Plate Girdle of Light
  (1991063, 303114, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Plate Legguards of Light
  (1991064, 303115, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Plate Boots of Light
  (1991065, 303116, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Mail Helm of the Hunt
  (1991066, 303117, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Mail Spaulders of the Hunt
  (1991067, 303118, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Mail Chestguard of the Hunt
  (1991068, 303119, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Mail Bracers of the Hunt
  (1991069, 303120, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Mail Gauntlets of the Hunt
  (1991070, 303121, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Mail Girdle of the Hunt
  (1991071, 303122, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Mail Legguards of the Hunt
  (1991072, 303123, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Mail Boots of the Hunt
  (1991073, 303124, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Mail Helm of Elements
  (1991074, 303125, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Mail Spaulders of Elements
  (1991075, 303126, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Mail Chestguard of Elements
  (1991076, 303127, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Mail Bracers of Elements
  (1991077, 303128, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Mail Gauntlets of Elements
  (1991078, 303129, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Mail Girdle of Elements
  (1991079, 303130, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Mail Legguards of Elements
  (1991080, 303131, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Mail Boots of Elements
  (1991081, 303132, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Leather Helm of the Grove
  (1991082, 303133, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Leather Spaulders of the Grove
  (1991083, 303134, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Leather Chestguard of the Grove
  (1991084, 303135, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Leather Bracers of the Grove
  (1991085, 303136, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Leather Gauntlets of the Grove
  (1991086, 303137, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Leather Girdle of the Grove
  (1991087, 303138, 0, 100, 0, 1, 0, 1, 1),   -- Heirloom Leather Legguards of the Grove
  (1991088, 303139, 0, 100, 0, 1, 0, 1, 1);  -- Heirloom Leather Boots of the Grove


-- --- addon-facing definitions ----------------------------------------------
DELETE FROM `dc_heirloom_definitions` WHERE `item_id` BETWEEN 303100 AND 303139;
INSERT INTO `dc_heirloom_definitions` (`item_id`, `name`, `slot`, `armor_type`, `max_upgrade_level`, `scaling_type`, `icon`, `source`) VALUES
  (303100, 'Heirloom Plate Helm of Conquest', 1, 4, 3, 0, '', NULL),
  (303101, 'Heirloom Plate Spaulders of Conquest', 3, 4, 3, 0, '', NULL),
  (303102, 'Heirloom Plate Chestguard of Conquest', 5, 4, 3, 0, '', NULL),
  (303103, 'Heirloom Plate Bracers of Conquest', 9, 4, 3, 0, '', NULL),
  (303104, 'Heirloom Plate Gauntlets of Conquest', 10, 4, 3, 0, '', NULL),
  (303105, 'Heirloom Plate Girdle of Conquest', 6, 4, 3, 0, '', NULL),
  (303106, 'Heirloom Plate Legguards of Conquest', 7, 4, 3, 0, '', NULL),
  (303107, 'Heirloom Plate Boots of Conquest', 8, 4, 3, 0, '', NULL),
  (303108, 'Heirloom Plate Helm of Light', 1, 4, 3, 0, '', NULL),
  (303109, 'Heirloom Plate Spaulders of Light', 3, 4, 3, 0, '', NULL),
  (303110, 'Heirloom Plate Chestguard of Light', 5, 4, 3, 0, '', NULL),
  (303111, 'Heirloom Plate Bracers of Light', 9, 4, 3, 0, '', NULL),
  (303112, 'Heirloom Plate Gauntlets of Light', 10, 4, 3, 0, '', NULL),
  (303113, 'Heirloom Plate Girdle of Light', 6, 4, 3, 0, '', NULL),
  (303114, 'Heirloom Plate Legguards of Light', 7, 4, 3, 0, '', NULL),
  (303115, 'Heirloom Plate Boots of Light', 8, 4, 3, 0, '', NULL),
  (303116, 'Heirloom Mail Helm of the Hunt', 1, 3, 3, 0, '', NULL),
  (303117, 'Heirloom Mail Spaulders of the Hunt', 3, 3, 3, 0, '', NULL),
  (303118, 'Heirloom Mail Chestguard of the Hunt', 5, 3, 3, 0, '', NULL),
  (303119, 'Heirloom Mail Bracers of the Hunt', 9, 3, 3, 0, '', NULL),
  (303120, 'Heirloom Mail Gauntlets of the Hunt', 10, 3, 3, 0, '', NULL),
  (303121, 'Heirloom Mail Girdle of the Hunt', 6, 3, 3, 0, '', NULL),
  (303122, 'Heirloom Mail Legguards of the Hunt', 7, 3, 3, 0, '', NULL),
  (303123, 'Heirloom Mail Boots of the Hunt', 8, 3, 3, 0, '', NULL),
  (303124, 'Heirloom Mail Helm of Elements', 1, 3, 3, 0, '', NULL),
  (303125, 'Heirloom Mail Spaulders of Elements', 3, 3, 3, 0, '', NULL),
  (303126, 'Heirloom Mail Chestguard of Elements', 5, 3, 3, 0, '', NULL),
  (303127, 'Heirloom Mail Bracers of Elements', 9, 3, 3, 0, '', NULL),
  (303128, 'Heirloom Mail Gauntlets of Elements', 10, 3, 3, 0, '', NULL),
  (303129, 'Heirloom Mail Girdle of Elements', 6, 3, 3, 0, '', NULL),
  (303130, 'Heirloom Mail Legguards of Elements', 7, 3, 3, 0, '', NULL),
  (303131, 'Heirloom Mail Boots of Elements', 8, 3, 3, 0, '', NULL),
  (303132, 'Heirloom Leather Helm of the Grove', 1, 2, 3, 0, '', NULL),
  (303133, 'Heirloom Leather Spaulders of the Grove', 3, 2, 3, 0, '', NULL),
  (303134, 'Heirloom Leather Chestguard of the Grove', 5, 2, 3, 0, '', NULL),
  (303135, 'Heirloom Leather Bracers of the Grove', 9, 2, 3, 0, '', NULL),
  (303136, 'Heirloom Leather Gauntlets of the Grove', 10, 2, 3, 0, '', NULL),
  (303137, 'Heirloom Leather Girdle of the Grove', 6, 2, 3, 0, '', NULL),
  (303138, 'Heirloom Leather Legguards of the Grove', 7, 2, 3, 0, '', NULL),
  (303139, 'Heirloom Leather Boots of the Grove', 8, 2, 3, 0, '', NULL);

-- --- verification ---------------------------------------------------------
SELECT i.`entry`, i.`name`, i.`subclass`, i.`InventoryType`, i.`ScalingStatDistribution` AS SSD,
       i.`ScalingStatValue` AS SSV, d.`armor_type`,
       (SELECT COUNT(*) FROM `gameobject_loot_template` l WHERE l.`Item` = i.`entry`) AS loot,
       (SELECT COUNT(*) FROM `gameobject` g JOIN `gameobject_template` t ON t.`entry` = g.`id`
        WHERE t.`Data1` IN (SELECT `Entry` FROM `gameobject_loot_template` WHERE `Item` = i.`entry`)) AS spawns
FROM `item_template` i
LEFT JOIN `dc_heirloom_definitions` d ON d.`item_id` = i.`entry`
WHERE i.`entry` BETWEEN 303100 AND 303139
ORDER BY i.`entry`;
-- Expect 40 rows: subclass = armor_type, SSD in (549,550,551), loot = 1.
-- `spawns` will read 0 for every row until the caches are placed by hand.

-- --- placement reference ---------------------------------------------------
-- Stand where the cache should go and run `.gobject add <entry>`:
--   .gobject add 1991049   -- Heirloom Plate Helm of Conquest
--   .gobject add 1991050   -- Heirloom Plate Spaulders of Conquest
--   .gobject add 1991051   -- Heirloom Plate Chestguard of Conquest
--   .gobject add 1991052   -- Heirloom Plate Bracers of Conquest
--   .gobject add 1991053   -- Heirloom Plate Gauntlets of Conquest
--   .gobject add 1991054   -- Heirloom Plate Girdle of Conquest
--   .gobject add 1991055   -- Heirloom Plate Legguards of Conquest
--   .gobject add 1991056   -- Heirloom Plate Boots of Conquest
--   .gobject add 1991057   -- Heirloom Plate Helm of Light
--   .gobject add 1991058   -- Heirloom Plate Spaulders of Light
--   .gobject add 1991059   -- Heirloom Plate Chestguard of Light
--   .gobject add 1991060   -- Heirloom Plate Bracers of Light
--   .gobject add 1991061   -- Heirloom Plate Gauntlets of Light
--   .gobject add 1991062   -- Heirloom Plate Girdle of Light
--   .gobject add 1991063   -- Heirloom Plate Legguards of Light
--   .gobject add 1991064   -- Heirloom Plate Boots of Light
--   .gobject add 1991065   -- Heirloom Mail Helm of the Hunt
--   .gobject add 1991066   -- Heirloom Mail Spaulders of the Hunt
--   .gobject add 1991067   -- Heirloom Mail Chestguard of the Hunt
--   .gobject add 1991068   -- Heirloom Mail Bracers of the Hunt
--   .gobject add 1991069   -- Heirloom Mail Gauntlets of the Hunt
--   .gobject add 1991070   -- Heirloom Mail Girdle of the Hunt
--   .gobject add 1991071   -- Heirloom Mail Legguards of the Hunt
--   .gobject add 1991072   -- Heirloom Mail Boots of the Hunt
--   .gobject add 1991073   -- Heirloom Mail Helm of Elements
--   .gobject add 1991074   -- Heirloom Mail Spaulders of Elements
--   .gobject add 1991075   -- Heirloom Mail Chestguard of Elements
--   .gobject add 1991076   -- Heirloom Mail Bracers of Elements
--   .gobject add 1991077   -- Heirloom Mail Gauntlets of Elements
--   .gobject add 1991078   -- Heirloom Mail Girdle of Elements
--   .gobject add 1991079   -- Heirloom Mail Legguards of Elements
--   .gobject add 1991080   -- Heirloom Mail Boots of Elements
--   .gobject add 1991081   -- Heirloom Leather Helm of the Grove
--   .gobject add 1991082   -- Heirloom Leather Spaulders of the Grove
--   .gobject add 1991083   -- Heirloom Leather Chestguard of the Grove
--   .gobject add 1991084   -- Heirloom Leather Bracers of the Grove
--   .gobject add 1991085   -- Heirloom Leather Gauntlets of the Grove
--   .gobject add 1991086   -- Heirloom Leather Girdle of the Grove
--   .gobject add 1991087   -- Heirloom Leather Legguards of the Grove
--   .gobject add 1991088   -- Heirloom Leather Boots of the Grove
