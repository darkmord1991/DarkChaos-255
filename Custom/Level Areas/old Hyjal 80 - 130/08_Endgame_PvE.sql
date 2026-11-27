-- Hyjal Frontier - endgame PvE gear
--
-- Consolidated PvE endgame catalog. The tier-set and raid-drop sections
-- sit at the live heroic ICC upgrade ceiling (ilvl 412); the signature
-- trinkets are an intentionally lower entry tier (ilvl 338). Three sections:
--   1. 30 class-restricted signature trinkets for every talent tree
--      (400200-400229, ilvl 338).
--   2. 95 Ascendant ICC tier-set analogues covering the full non-clone
--      Sanctified roster across all ten class sets (400230-400324).
--   3. 123 ICC raid-drop analogues: highest-source deduped raid catalog,
--      the Ashen Verdict Endless rings, and the Lich King endpoint
--      weapons plus Shadowmourne (400325-400447).

-- =============================================================================
-- Section 1 - level-130 signature items (400200-400229)
-- =============================================================================
INSERT INTO `item_template`
    (`entry`, `class`, `subclass`, `SoundOverrideSubclass`, `name`,
     `displayid`, `Quality`, `Flags`, `FlagsExtra`, `BuyCount`, `BuyPrice`,
     `SellPrice`, `InventoryType`, `AllowableClass`, `AllowableRace`,
     `ItemLevel`, `RequiredLevel`, `maxcount`, `stackable`, `ContainerSlots`,
     `stat_type1`, `stat_value1`, `stat_type2`, `stat_value2`,
     `stat_type3`, `stat_value3`, `stat_type4`, `stat_value4`,
     `stat_type5`, `stat_value5`, `armor`, `bonding`, `description`,
     `VerifiedBuild`)
VALUES
(400200, 4, 0, -1, 'Glorenzelg War Sigil',
    68109, 4, 0, 0, 1, 0,
    260000, 12, 1, -1,
    338, 130, 0, 1, 0,
    4, 206, 7, 192,
    37, 122, 36, 112,
    0, 0, 0, 1,
    'Level 130 Arms Warrior signature item.', 0),
(400201, 4, 0, -1, 'Havocblood War Seal',
    64711, 4, 0, 0, 1, 0,
    260000, 12, 1, -1,
    338, 130, 0, 1, 0,
    4, 206, 7, 192,
    44, 122, 32, 112,
    0, 0, 0, 1,
    'Level 130 Fury Warrior signature item.', 0),
(400202, 4, 0, -1, 'Fang of Unbroken Valor',
    64256, 4, 0, 0, 1, 0,
    260000, 12, 1, -1,
    338, 130, 0, 1, 0,
    4, 160, 7, 260,
    12, 122, 13, 112,
    14, 112, 0, 1,
    'Level 130 Protection Warrior signature item.', 0),
(400203, 4, 0, -1, 'Solace of the Lightbound',
    59319, 4, 0, 0, 1, 0,
    260000, 12, 2, -1,
    338, 130, 0, 1, 0,
    45, 215, 7, 182,
    5, 118, 32, 122,
    6, 112, 0, 1,
    'Level 130 Holy Paladin signature item.', 0),
(400204, 4, 0, -1, 'Lightsworn Aegis Scale',
    64256, 4, 0, 0, 1, 0,
    260000, 12, 2, -1,
    338, 130, 0, 1, 0,
    4, 160, 7, 260,
    12, 122, 13, 112,
    14, 112, 0, 1,
    'Level 130 Protection Paladin signature item.', 0),
(400205, 4, 0, -1, 'Crusader Mourne Fragment',
    68106, 4, 0, 0, 1, 0,
    260000, 12, 2, -1,
    338, 130, 0, 1, 0,
    4, 206, 7, 192,
    32, 122, 36, 112,
    44, 102, 0, 1,
    'Level 130 Retribution Paladin signature item.', 0),
(400206, 4, 0, -1, 'Ranger-General Pack Sigil',
    68109, 4, 0, 0, 1, 0,
    260000, 12, 4, -1,
    338, 130, 0, 1, 0,
    3, 176, 7, 182,
    38, 215, 36, 112,
    0, 0, 0, 1,
    'Level 130 Beast Mastery Hunter signature item.', 0),
(400207, 4, 0, -1, 'Oathbinder Sightstone',
    68109, 4, 0, 0, 1, 0,
    260000, 12, 4, -1,
    338, 130, 0, 1, 0,
    3, 176, 7, 182,
    31, 122, 36, 112,
    44, 102, 0, 1,
    'Level 130 Marksmanship Hunter signature item.', 0),
(400208, 4, 0, -1, 'Sharpened Twilight Scale of Survival',
    68109, 4, 0, 0, 1, 0,
    260000, 12, 4, -1,
    338, 130, 0, 1, 0,
    3, 176, 7, 182,
    32, 122, 44, 112,
    0, 0, 0, 1,
    'Level 130 Survival Hunter signature item.', 0),
(400209, 4, 0, -1, 'Tiny Abomination Venom Jar',
    64711, 4, 0, 0, 1, 0,
    260000, 12, 8, -1,
    338, 130, 0, 1, 0,
    3, 176, 7, 182,
    37, 122, 32, 112,
    0, 0, 0, 1,
    'Level 130 Assassination Rogue signature item.', 0),
(400210, 4, 0, -1, 'Deathbringer Edge Charm',
    64711, 4, 0, 0, 1, 0,
    260000, 12, 8, -1,
    338, 130, 0, 1, 0,
    3, 176, 7, 182,
    44, 122, 36, 112,
    0, 0, 0, 1,
    'Level 130 Combat Rogue signature item.', 0),
(400211, 4, 0, -1, 'Shadowblade Blood Signet',
    68106, 4, 0, 0, 1, 0,
    260000, 12, 8, -1,
    338, 130, 0, 1, 0,
    3, 176, 7, 182,
    32, 122, 36, 112,
    0, 0, 0, 1,
    'Level 130 Subtlety Rogue signature item.', 0),
(400212, 4, 0, -1, 'Solace of the Disciplined',
    59319, 4, 0, 0, 1, 0,
    260000, 12, 16, -1,
    338, 130, 0, 1, 0,
    45, 215, 7, 182,
    5, 118, 32, 122,
    6, 112, 0, 1,
    'Level 130 Discipline Priest signature item.', 0),
(400213, 4, 0, -1, 'Trauma Living Prayer',
    59319, 4, 0, 0, 1, 0,
    260000, 12, 16, -1,
    338, 130, 0, 1, 0,
    45, 215, 7, 182,
    5, 118, 6, 122,
    36, 112, 0, 1,
    'Level 130 Holy Priest signature item.', 0),
(400214, 4, 0, -1, 'Phylactery of Endless Whispers',
    64247, 4, 0, 0, 1, 0,
    260000, 12, 16, -1,
    338, 130, 0, 1, 0,
    45, 215, 7, 168,
    5, 118, 32, 122,
    31, 112, 0, 1,
    'Level 130 Shadow Priest signature item.', 0),
(400215, 4, 0, -1, 'Crimson Organ of the Fallen King',
    64256, 4, 0, 0, 1, 0,
    260000, 12, 32, -1,
    338, 130, 0, 1, 0,
    4, 168, 7, 270,
    12, 122, 13, 112,
    14, 112, 0, 1,
    'Level 130 Blood Death Knight signature item.', 0),
(400216, 4, 0, -1, 'Frozen Mourne Splinter',
    68109, 4, 0, 0, 1, 0,
    260000, 12, 32, -1,
    338, 130, 0, 1, 0,
    4, 206, 7, 192,
    36, 122, 32, 112,
    0, 0, 0, 1,
    'Level 130 Frost Death Knight signature item.', 0),
(400217, 4, 0, -1, 'Abomination Rotting Core',
    64711, 4, 0, 0, 1, 0,
    260000, 12, 32, -1,
    338, 130, 0, 1, 0,
    4, 206, 7, 192,
    44, 122, 32, 112,
    0, 0, 0, 1,
    'Level 130 Unholy Death Knight signature item.', 0),
(400218, 4, 0, -1, 'Dislodged Storm Focus',
    64245, 4, 0, 0, 1, 0,
    260000, 12, 64, -1,
    338, 130, 0, 1, 0,
    45, 215, 7, 176,
    5, 118, 36, 112,
    32, 122, 0, 1,
    'Level 130 Elemental Shaman signature item.', 0),
(400219, 4, 0, -1, 'Thundercall Twilight Scale',
    68109, 4, 0, 0, 1, 0,
    260000, 12, 64, -1,
    338, 130, 0, 1, 0,
    3, 176, 7, 182,
    38, 215, 32, 122,
    44, 102, 0, 1,
    'Level 130 Enhancement Shaman signature item.', 0),
(400220, 4, 0, -1, 'Trauma Tidal Memory',
    59319, 4, 0, 0, 1, 0,
    260000, 12, 64, -1,
    338, 130, 0, 1, 0,
    45, 215, 7, 188,
    5, 118, 6, 122,
    32, 112, 0, 1,
    'Level 130 Restoration Shaman signature item.', 0),
(400221, 4, 0, -1, 'Kirin Tor Phylactery',
    64247, 4, 0, 0, 1, 0,
    260000, 12, 128, -1,
    338, 130, 0, 1, 0,
    45, 215, 7, 168,
    5, 118, 31, 122,
    32, 112, 0, 1,
    'Level 130 Arcane Mage signature item.', 0),
(400222, 4, 0, -1, 'Cinderborn Foreign Object',
    64245, 4, 0, 0, 1, 0,
    260000, 12, 128, -1,
    338, 130, 0, 1, 0,
    45, 215, 7, 168,
    5, 118, 36, 122,
    32, 112, 0, 1,
    'Level 130 Fire Mage signature item.', 0),
(400223, 4, 0, -1, 'Nevermelting Star Crystal',
    64256, 4, 0, 0, 1, 0,
    260000, 12, 128, -1,
    338, 130, 0, 1, 0,
    45, 215, 7, 176,
    5, 118, 36, 122,
    31, 112, 0, 1,
    'Level 130 Frost Mage signature item.', 0),
(400224, 4, 0, -1, 'Phylactery of Endless Night',
    64247, 4, 0, 0, 1, 0,
    260000, 12, 256, -1,
    338, 130, 0, 1, 0,
    45, 215, 7, 168,
    5, 118, 32, 122,
    31, 112, 0, 1,
    'Level 130 Affliction Warlock signature item.', 0),
(400225, 4, 0, -1, 'Demonforge Foreign Object',
    64245, 4, 0, 0, 1, 0,
    260000, 12, 256, -1,
    338, 130, 0, 1, 0,
    45, 215, 7, 176,
    5, 118, 36, 122,
    32, 112, 0, 1,
    'Level 130 Demonology Warlock signature item.', 0),
(400226, 4, 0, -1, 'Charred Twilight Ember',
    68106, 4, 0, 0, 1, 0,
    260000, 12, 256, -1,
    338, 130, 0, 1, 0,
    45, 215, 7, 168,
    5, 118, 36, 122,
    31, 112, 0, 1,
    'Level 130 Destruction Warlock signature item.', 0),
(400227, 4, 0, -1, 'Lunar Dreamscale Focus',
    59316, 4, 0, 0, 1, 0,
    260000, 12, 1024, -1,
    338, 130, 0, 1, 0,
    45, 215, 7, 182,
    5, 118, 32, 122,
    36, 112, 0, 1,
    'Level 130 Balance Druid signature item.', 0),
(400228, 4, 0, -1, 'Wildfang Abomination Fang',
    64711, 4, 0, 0, 1, 0,
    260000, 12, 1024, -1,
    338, 130, 0, 1, 0,
    3, 184, 7, 194,
    38, 215, 13, 112,
    32, 102, 0, 1,
    'Level 130 Feral Druid signature item.', 0),
(400229, 4, 0, -1, 'Dreamwell Lifebloom Seed',
    59319, 4, 0, 0, 1, 0,
    260000, 12, 1024, -1,
    338, 130, 0, 1, 0,
    45, 215, 7, 188,
    5, 118, 6, 122,
    32, 112, 0, 1,
    'Level 130 Restoration Druid signature item.', 0);

-- Promote the signature block to the same 412 ceiling currently reached by
-- active heroic ICC upgrade chains in the live item-upgrade system.
UPDATE `item_template`
SET `ItemLevel` = 412,
    `SellPrice` = ROUND(`SellPrice` * 1.22),
    `stat_value1` = ROUND(`stat_value1` * 1.22),
    `stat_value2` = ROUND(`stat_value2` * 1.22),
    `stat_value3` = ROUND(`stat_value3` * 1.22),
    `stat_value4` = ROUND(`stat_value4` * 1.22),
    `stat_value5` = ROUND(`stat_value5` * 1.22)
WHERE `entry` BETWEEN 400200 AND 400229;

-- =============================================================================
-- Section 2 - Ascendant ICC tier-set analogues (400230-400324)
-- =============================================================================
DELETE FROM `item_template`
WHERE `entry` BETWEEN 400230 AND 400324;

INSERT INTO `item_template`
    (`entry`, `class`, `subclass`, `SoundOverrideSubclass`, `name`,
     `displayid`, `Quality`, `Flags`, `FlagsExtra`, `BuyCount`, `BuyPrice`,
     `SellPrice`, `InventoryType`, `AllowableClass`, `AllowableRace`,
     `ItemLevel`, `RequiredLevel`, `maxcount`, `stackable`, `ContainerSlots`,
     `stat_type1`, `stat_value1`, `stat_type2`, `stat_value2`,
     `stat_type3`, `stat_value3`, `stat_type4`, `stat_value4`,
    `stat_type5`, `stat_value5`, `armor`, `bonding`, `itemset`,
    `socketColor_1`, `socketColor_2`, `socketColor_3`, `socketBonus`,
    `description`, `VerifiedBuild`)
SELECT
    map.`new_entry`,
    src.`class`,
    src.`subclass`,
    src.`SoundOverrideSubclass`,
    REPLACE(src.`name`, 'Sanctified ', 'Ascendant '),
    src.`displayid`,
    4,
    src.`Flags`,
    src.`FlagsExtra`,
    src.`BuyCount`,
    0,
    320000,
    src.`InventoryType`,
    src.`AllowableClass`,
    src.`AllowableRace`,
    412,
    130,
    src.`maxcount`,
    src.`stackable`,
    src.`ContainerSlots`,
    src.`stat_type1`, ROUND(src.`stat_value1` * 1.45),
    src.`stat_type2`, ROUND(src.`stat_value2` * 1.45),
    src.`stat_type3`, ROUND(src.`stat_value3` * 1.45),
    src.`stat_type4`, ROUND(src.`stat_value4` * 1.45),
    src.`stat_type5`, ROUND(src.`stat_value5` * 1.45),
    ROUND(src.`armor` * 1.45),
    src.`bonding`,
    src.`itemset`,
    src.`socketColor_1`,
    src.`socketColor_2`,
    src.`socketColor_3`,
    src.`socketBonus`,
    CONCAT('Level 130 Ascendant tier analogue of ', src.`name`, '.'),
    0
FROM (
    SELECT 400230 AS `new_entry`, 51225 AS `source_entry` UNION ALL
    SELECT 400231, 51220 UNION ALL
    SELECT 400232, 51226 UNION ALL
    SELECT 400233, 51221 UNION ALL
    SELECT 400234, 51222 UNION ALL
    SELECT 400235, 51227 UNION ALL
    SELECT 400236, 51223 UNION ALL
    SELECT 400237, 51228 UNION ALL
    SELECT 400238, 51224 UNION ALL
    SELECT 400239, 51229 UNION ALL
    SELECT 400240, 51275 UNION ALL
    SELECT 400241, 51265 UNION ALL
    SELECT 400242, 51266 UNION ALL
    SELECT 400243, 51276 UNION ALL
    SELECT 400244, 51270 UNION ALL
    SELECT 400245, 51271 UNION ALL
    SELECT 400246, 51267 UNION ALL
    SELECT 400247, 51272 UNION ALL
    SELECT 400248, 51277 UNION ALL
    SELECT 400249, 51268 UNION ALL
    SELECT 400250, 51278 UNION ALL
    SELECT 400251, 51269 UNION ALL
    SELECT 400252, 51279 UNION ALL
    SELECT 400253, 51273 UNION ALL
    SELECT 400254, 51274 UNION ALL
    SELECT 400255, 51285 UNION ALL
    SELECT 400256, 51286 UNION ALL
    SELECT 400257, 51287 UNION ALL
    SELECT 400258, 51288 UNION ALL
    SELECT 400259, 51289 UNION ALL
    SELECT 400260, 51250 UNION ALL
    SELECT 400261, 51251 UNION ALL
    SELECT 400262, 51252 UNION ALL
    SELECT 400263, 51253 UNION ALL
    SELECT 400264, 51254 UNION ALL
    SELECT 400265, 51255 UNION ALL
    SELECT 400266, 51260 UNION ALL
    SELECT 400267, 51256 UNION ALL
    SELECT 400268, 51261 UNION ALL
    SELECT 400269, 51262 UNION ALL
    SELECT 400270, 51257 UNION ALL
    SELECT 400271, 51258 UNION ALL
    SELECT 400272, 51259 UNION ALL
    SELECT 400273, 51263 UNION ALL
    SELECT 400274, 51264 UNION ALL
    SELECT 400275, 51310 UNION ALL
    SELECT 400276, 51305 UNION ALL
    SELECT 400277, 51306 UNION ALL
    SELECT 400278, 51311 UNION ALL
    SELECT 400279, 51307 UNION ALL
    SELECT 400280, 51312 UNION ALL
    SELECT 400281, 51308 UNION ALL
    SELECT 400282, 51313 UNION ALL
    SELECT 400283, 51309 UNION ALL
    SELECT 400284, 51314 UNION ALL
    SELECT 400285, 51244 UNION ALL
    SELECT 400286, 51242 UNION ALL
    SELECT 400287, 51238 UNION ALL
    SELECT 400288, 51243 UNION ALL
    SELECT 400289, 51248 UNION ALL
    SELECT 400290, 51239 UNION ALL
    SELECT 400291, 51247 UNION ALL
    SELECT 400292, 51237 UNION ALL
    SELECT 400293, 51236 UNION ALL
    SELECT 400294, 51246 UNION ALL
    SELECT 400295, 51240 UNION ALL
    SELECT 400296, 51235 UNION ALL
    SELECT 400297, 51245 UNION ALL
    SELECT 400298, 51249 UNION ALL
    SELECT 400299, 51241 UNION ALL
    SELECT 400300, 51280 UNION ALL
    SELECT 400301, 51281 UNION ALL
    SELECT 400302, 51282 UNION ALL
    SELECT 400303, 51283 UNION ALL
    SELECT 400304, 51284 UNION ALL
    SELECT 400305, 51230 UNION ALL
    SELECT 400306, 51231 UNION ALL
    SELECT 400307, 51232 UNION ALL
    SELECT 400308, 51233 UNION ALL
    SELECT 400309, 51234 UNION ALL
    SELECT 400310, 51290 UNION ALL
    SELECT 400311, 51301 UNION ALL
    SELECT 400312, 51291 UNION ALL
    SELECT 400313, 51295 UNION ALL
    SELECT 400314, 51296 UNION ALL
    SELECT 400315, 51302 UNION ALL
    SELECT 400316, 51297 UNION ALL
    SELECT 400317, 51303 UNION ALL
    SELECT 400318, 51292 UNION ALL
    SELECT 400319, 51304 UNION ALL
    SELECT 400320, 51298 UNION ALL
    SELECT 400321, 51300 UNION ALL
    SELECT 400322, 51299 UNION ALL
    SELECT 400323, 51293 UNION ALL
    SELECT 400324, 51294
) AS map
JOIN `item_template` AS src
    ON src.`entry` = map.`source_entry`
ORDER BY map.`new_entry`;

-- =============================================================================
-- Section 3 - ICC raid-drop analogues (400325-400447)
-- =============================================================================
DELETE FROM `item_template`
WHERE `entry` BETWEEN 400325 AND 400447;

SET @dc_hyjal_icc_target_ilvl := 412;
SET @dc_hyjal_icc_old_group_concat_max_len := @@SESSION.group_concat_max_len;
SET SESSION group_concat_max_len = 131072;

DROP TEMPORARY TABLE IF EXISTS `dc_hyjal_icc_source_map`;
CREATE TEMPORARY TABLE `dc_hyjal_icc_source_map`
(
    `new_entry` INT UNSIGNED NOT NULL,
    `source_entry` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`new_entry`),
    UNIQUE KEY `ux_source_entry` (`source_entry`)
);

SET @dc_hyjal_icc_entry := 400324;

INSERT INTO `dc_hyjal_icc_source_map` (`new_entry`, `source_entry`)
SELECT (@dc_hyjal_icc_entry := @dc_hyjal_icc_entry + 1) AS `new_entry`,
       ranked.`entry` AS `source_entry`
FROM (
    SELECT ranked.`entry`, ranked.`name`
    FROM (
        SELECT it.`entry`,
               it.`name`,
               it.`ItemLevel`,
               ROW_NUMBER() OVER (
                   PARTITION BY it.`name`
                   ORDER BY it.`ItemLevel` DESC, it.`entry` DESC
               ) AS `rn`
        FROM `item_template` AS it
        JOIN (
            SELECT DISTINCT src.`name`
            FROM (
                SELECT looted.`name`, looted.`ItemLevel`
                FROM (
                    SELECT clt.`Item` AS `item_id`
                    FROM `creature_loot_template` AS clt
                    JOIN (
                        SELECT DISTINCT ct.`lootid` AS `lootid`
                        FROM `creature` AS c
                        JOIN `creature_template` AS ct
                            ON ct.`entry` = c.`id1`
                        WHERE c.`map` = 631
                          AND ct.`lootid` > 0
                    ) AS ic
                        ON ic.`lootid` = clt.`Entry`
                    WHERE clt.`Item` > 0

                    UNION

                    SELECT r1.`Item` AS `item_id`
                    FROM `creature_loot_template` AS clt
                    JOIN (
                        SELECT DISTINCT ct.`lootid` AS `lootid`
                        FROM `creature` AS c
                        JOIN `creature_template` AS ct
                            ON ct.`entry` = c.`id1`
                        WHERE c.`map` = 631
                          AND ct.`lootid` > 0
                    ) AS ic
                        ON ic.`lootid` = clt.`Entry`
                    JOIN `reference_loot_template` AS r1
                        ON r1.`Entry` = clt.`Reference`
                    WHERE clt.`Reference` > 0
                      AND r1.`Item` > 0

                    UNION

                    SELECT r2.`Item` AS `item_id`
                    FROM `creature_loot_template` AS clt
                    JOIN (
                        SELECT DISTINCT ct.`lootid` AS `lootid`
                        FROM `creature` AS c
                        JOIN `creature_template` AS ct
                            ON ct.`entry` = c.`id1`
                        WHERE c.`map` = 631
                          AND ct.`lootid` > 0
                    ) AS ic
                        ON ic.`lootid` = clt.`Entry`
                    JOIN `reference_loot_template` AS r1
                        ON r1.`Entry` = clt.`Reference`
                    JOIN `reference_loot_template` AS r2
                        ON r2.`Entry` = r1.`Reference`
                    WHERE clt.`Reference` > 0
                      AND r1.`Reference` > 0
                      AND r2.`Item` > 0

                    UNION

                    SELECT glt.`Item` AS `item_id`
                    FROM `gameobject_loot_template` AS glt
                    JOIN (
                        SELECT DISTINCT gt.`Data1` AS `lootid`
                        FROM `gameobject` AS g
                        JOIN `gameobject_template` AS gt
                            ON gt.`entry` = g.`id`
                        WHERE g.`map` = 631
                          AND gt.`type` = 3
                          AND gt.`Data1` > 0
                    ) AS ig
                        ON ig.`lootid` = glt.`Entry`
                    WHERE glt.`Item` > 0

                    UNION

                    SELECT rlt.`Item` AS `item_id`
                    FROM `gameobject_loot_template` AS glt
                    JOIN (
                        SELECT DISTINCT gt.`Data1` AS `lootid`
                        FROM `gameobject` AS g
                        JOIN `gameobject_template` AS gt
                            ON gt.`entry` = g.`id`
                        WHERE g.`map` = 631
                          AND gt.`type` = 3
                          AND gt.`Data1` > 0
                    ) AS ig
                        ON ig.`lootid` = glt.`Entry`
                    JOIN `reference_loot_template` AS rlt
                        ON rlt.`Entry` = glt.`Reference`
                    WHERE glt.`Reference` > 0
                      AND rlt.`Item` > 0
                ) AS ai
                JOIN `item_template` AS looted
                    ON looted.`entry` = ai.`item_id`
                WHERE looted.`entry` < 200000
                  AND looted.`InventoryType` NOT IN (0, 18)
            ) AS src
            WHERE src.`ItemLevel` >= 251
              AND src.`ItemLevel` <> 258
        ) AS names
            ON names.`name` = it.`name`
        WHERE it.`entry` < 200000
          AND it.`InventoryType` NOT IN (0, 18)
          AND it.`ItemLevel` BETWEEN 251 AND 284
          AND it.`name` NOT LIKE 'Wrathful Gladiator%'
          AND it.`name` NOT LIKE 'Sanctified %'
    ) AS ranked
    WHERE ranked.`rn` = 1
    ORDER BY ranked.`name`, ranked.`entry`
) AS ranked;

INSERT INTO `dc_hyjal_icc_source_map` (`new_entry`, `source_entry`)
SELECT (@dc_hyjal_icc_entry := @dc_hyjal_icc_entry + 1) AS `new_entry`,
       src.`entry` AS `source_entry`
FROM `item_template` AS src
WHERE src.`entry` IN (50398, 50400, 50402, 50404, 52572)
ORDER BY src.`name`, src.`entry`;

INSERT INTO `dc_hyjal_icc_source_map` (`new_entry`, `source_entry`)
SELECT (@dc_hyjal_icc_entry := @dc_hyjal_icc_entry + 1) AS `new_entry`,
       src.`entry` AS `source_entry`
FROM `item_template` AS src
WHERE src.`entry` IN (49623, 50730, 50731, 50732, 50733,
                      50734, 50735, 50736, 50737, 50738)
ORDER BY src.`name`, src.`entry`;

SET @dc_hyjal_icc_columns := (
    SELECT GROUP_CONCAT(CONCAT('`', COLUMN_NAME, '`')
                        ORDER BY ORDINAL_POSITION SEPARATOR ', ')
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'item_template'
);

SET @dc_hyjal_icc_select := (
    SELECT GROUP_CONCAT(
        CASE
            WHEN COLUMN_NAME = 'entry' THEN 'map.`new_entry`'
            WHEN COLUMN_NAME = 'ItemLevel' THEN '@dc_hyjal_icc_target_ilvl'
            WHEN COLUMN_NAME = 'RequiredLevel' THEN '130'
            WHEN COLUMN_NAME = 'BuyPrice' THEN '0'
            WHEN COLUMN_NAME = 'SellPrice' THEN 'CASE WHEN src.`ItemLevel` > 0 THEN ROUND(src.`SellPrice` * (@dc_hyjal_icc_target_ilvl / src.`ItemLevel`)) ELSE src.`SellPrice` END'
            WHEN COLUMN_NAME REGEXP '^stat_value[0-9]+$' THEN CONCAT(
                'CASE WHEN src.`ItemLevel` > 0 THEN ROUND(src.`', COLUMN_NAME,
                '` * (@dc_hyjal_icc_target_ilvl / src.`ItemLevel`)) ELSE src.`',
                COLUMN_NAME, '` END')
            WHEN COLUMN_NAME REGEXP '^dmg_(min|max)[12]$' THEN CONCAT(
                'CASE WHEN src.`ItemLevel` > 0 THEN ROUND(src.`', COLUMN_NAME,
                '` * (@dc_hyjal_icc_target_ilvl / src.`ItemLevel`), 6) ELSE src.`',
                COLUMN_NAME, '` END')
            WHEN COLUMN_NAME = 'ArmorDamageModifier' THEN
                'CASE WHEN src.`ItemLevel` > 0 THEN ROUND(src.`ArmorDamageModifier` * (@dc_hyjal_icc_target_ilvl / src.`ItemLevel`), 6) ELSE src.`ArmorDamageModifier` END'
            WHEN COLUMN_NAME IN ('armor', 'block') THEN CONCAT(
                'CASE WHEN src.`ItemLevel` > 0 THEN ROUND(src.`', COLUMN_NAME,
                '` * (@dc_hyjal_icc_target_ilvl / src.`ItemLevel`)) ELSE src.`',
                COLUMN_NAME, '` END')
            WHEN COLUMN_NAME = 'description' THEN
                'CONCAT(''Level 130 ICC analogue of '', src.`name`, ''.'')'
            WHEN COLUMN_NAME = 'VerifiedBuild' THEN '0'
            ELSE CONCAT('src.`', COLUMN_NAME, '`')
        END
        ORDER BY ORDINAL_POSITION SEPARATOR ', ')
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'item_template'
);

SET @dc_hyjal_icc_sql := CONCAT(
    'INSERT INTO `item_template` (', @dc_hyjal_icc_columns, ') ',
    'SELECT ', @dc_hyjal_icc_select, ' ',
    'FROM `dc_hyjal_icc_source_map` AS map ',
    'JOIN `item_template` AS src ON src.`entry` = map.`source_entry` ',
    'ORDER BY map.`new_entry`'
);

PREPARE dc_hyjal_icc_stmt FROM @dc_hyjal_icc_sql;
EXECUTE dc_hyjal_icc_stmt;
DEALLOCATE PREPARE dc_hyjal_icc_stmt;

DROP TEMPORARY TABLE IF EXISTS `dc_hyjal_icc_source_map`;
SET SESSION group_concat_max_len = @dc_hyjal_icc_old_group_concat_max_len;