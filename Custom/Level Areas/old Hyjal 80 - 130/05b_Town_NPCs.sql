-- Hyjal Frontier - town service NPCs for both faction hubs
--
-- Fills out Jaina's Encampment (Alliance, area 6105) and Thrall's Vanguard
-- (Horde, area 6106) with the standard "town" roster. The Alliance hub
-- already has its flight master (830020), guard (830021), innkeeper
-- (830023) and Emberwood quartermaster (830024) from 05_Start_NPCs.sql, so
-- only vendors are added on that side. The Horde hub only had its grunt
-- guard (830022), so it gets its own flight master, innkeeper and
-- quartermaster here in addition to the vendor roster.
--
-- Entry block 830135-830157 (creature 830135-830999 was free). Display IDs
-- are real retail vendor models pulled per faction (human/dwarf for
-- Alliance, orc/troll for Horde). All entries are civilian, non-combat,
-- level 130 to match the existing service NPCs.
--
-- Faction: 12 (Stormwind) = strict Alliance, 29 (Orgrimmar) = strict Horde,
-- so each camp's NPCs are usable only by their own faction and hostile to
-- the other (the shared quest givers in 10 keep the neutral 35/36 factions).
-- NPC flags: 1 gossip, 128 vendor, 512 food vendor, 2048 reagent vendor,
--   4096 repair, 8192 flightmaster, 65536 innkeeper, 131072 banker,
--   524288 tabard designer, 2097152 auctioneer, 4194304 stable master.

DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 830135 AND 830157;
DELETE FROM `creature_template`       WHERE `entry`      BETWEEN 830135 AND 830157;

INSERT INTO `creature_template`
    (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`,
     `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`,
     `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `unit_class`,
     `unit_flags`, `dynamicflags`, `family`, `type`, `type_flags`,
     `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`,
     `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
VALUES
-- ===== Alliance - Jaina's Encampment (faction 35) =====
(830135, 'Encampment Banker',        'Jaina''s Encampment', 130, 130, 1,
    12,131073,  1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0),
(830136, 'Encampment Auctioneer',    'Jaina''s Encampment', 130, 130, 1,
    12,2097153, 1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0),
(830137, 'Encampment Provisioner',   'General Goods', 130, 130, 1,
    12,129,     1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0),
(830138, 'Encampment Trader',        'Trade Supplies', 130, 130, 1,
    12,129,     1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0),
(830139, 'Encampment Cook',          'Food & Drink', 130, 130, 1,
    12,641,     1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0),
(830140, 'Encampment Alchemist',     'Reagents', 130, 130, 1,
    12,2177,    1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0),
(830141, 'Encampment Weaponsmith',   'Weaponsmith', 130, 130, 1,
    12,4225,    1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0),
(830142, 'Encampment Armorer',       'Armorer', 130, 130, 1,
    12,4225,    1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0),
(830143, 'Encampment Stable Master', 'Stable Master', 130, 130, 1,
    12,4194305, 1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0),
(830144, 'Encampment Tabard Vendor', 'Tabards', 130, 130, 1,
    12,524289,  1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0),

-- ===== Horde - Thrall's Vanguard service (faction 36) =====
(830145, 'Vanguard Flight Master',   'Thrall''s Vanguard', 130, 130, 1,
    29,8193,    1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, 'npc_hyjal_flightmaster', 0),
(830146, 'Innkeeper Garruka',        NULL, 130, 130, 1,
    29,65537,   1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0),
(830147, 'Emberwood Sap Quartermaster', 'Thrall''s Vanguard', 130, 130, 1,
    29,129,     1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, 'npc_hyjal_emberwood_vendor', 0),

-- ===== Horde - Thrall's Vanguard vendors (faction 36) =====
(830148, 'Vanguard Banker',          'Thrall''s Vanguard', 130, 130, 1,
    29,131073,  1, 1.14286, 1, 1, 1400, 2000, 1, 8256, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0),
(830149, 'Vanguard Auctioneer',      'Thrall''s Vanguard', 130, 130, 1,
    29,2097153, 1, 1.14286, 1, 1, 1400, 2000, 1, 8256, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0),
(830150, 'Vanguard Provisioner',     'General Goods', 130, 130, 1,
    29,129,     1, 1.14286, 1, 1, 1400, 2000, 1, 8256, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0),
(830151, 'Vanguard Trader',          'Trade Supplies', 130, 130, 1,
    29,129,     1, 1.14286, 1, 1, 1400, 2000, 1, 8256, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0),
(830152, 'Vanguard Cook',            'Food & Drink', 130, 130, 1,
    29,641,     1, 1.14286, 1, 1, 1400, 2000, 1, 8256, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0),
(830153, 'Vanguard Shaman Supplier', 'Reagents', 130, 130, 1,
    29,2177,    1, 1.14286, 1, 1, 1400, 2000, 1, 8256, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0),
(830154, 'Vanguard Weaponsmith',     'Weaponsmith', 130, 130, 1,
    29,4225,    1, 1.14286, 1, 1, 1400, 2000, 1, 8256, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0),
(830155, 'Vanguard Armorer',         'Armorer', 130, 130, 1,
    29,4225,    1, 1.14286, 1, 1, 1400, 2000, 1, 8256, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0),
(830156, 'Vanguard Stable Master',   'Stable Master', 130, 130, 1,
    29,4194305, 1, 1.14286, 1, 1, 1400, 2000, 1, 8256, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0),
(830157, 'Vanguard Tabard Vendor',   'Tabards', 130, 130, 1,
    29,524289,  1, 1.14286, 1, 1, 1400, 2000, 1, 8256, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, '', 0);

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
VALUES
-- Alliance (human / dwarf)
(830135, 0, 1436, 1, 1, 0),
(830136, 0, 1437, 1, 1, 0),
(830137, 0, 1434, 1, 1, 0),
(830138, 0, 1298, 1, 1, 0),
(830139, 0, 1442, 1, 1, 0),
(830140, 0, 1444, 1, 1, 0),
(830141, 0, 3353, 1, 1, 0),
(830142, 0, 3304, 1, 1, 0),
(830143, 0, 9249, 1, 1, 0),
(830144, 0, 1450, 1, 1, 0),
-- Horde (orc / troll)
(830145, 0, 4259, 1, 1, 0),
(830146, 0, 5487, 1, 1, 0),
(830147, 0, 3952, 1, 1, 0),
(830148, 0, 1310, 1, 1, 0),
(830149, 0, 1318, 1, 1, 0),
(830150, 0, 1313, 1, 1, 0),
(830151, 0, 1389, 1, 1, 0),
(830152, 0, 4293, 1, 1, 0),
(830153, 0, 3741, 1, 1, 0),
(830154, 0, 3738, 1, 1, 0),
(830155, 0, 10704, 1, 1, 0),
(830156, 0, 9250, 1, 1, 0),
(830157, 0, 1320, 1, 1, 0);

-- -----------------------------------------------------------------------------
-- Spawns (map 1410). GUID block 9010200-9010232 (inside the Hyjal 9010000+
-- allocation; verified free of foreign data).
-- -----------------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` BETWEEN 9010200 AND 9010260;

INSERT INTO `creature`
    (`guid`, `id1`, `id2`, `id3`, `map`, `zoneId`, `areaId`, `spawnMask`,
     `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`,
     `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`,
     `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`,
     `dynamicflags`, `ScriptName`, `VerifiedBuild`)
VALUES
-- Alliance - Jaina's Encampment (6105)
(9010200, 830135, 0, 0, 1410, 6100, 6105, 1, 1, 0, 4611.0, -3756.0, 946.5, 3.10, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),
(9010201, 830136, 0, 0, 1410, 6100, 6105, 1, 1, 0, 4613.5, -3759.4, 946.4, 3.30, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),
(9010202, 830137, 0, 0, 1410, 6100, 6105, 1, 1, 0, 4607.2, -3766.3, 946.2, 2.00, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),
(9010203, 830138, 0, 0, 1410, 6100, 6105, 1, 1, 0, 4603.1, -3767.6, 946.1, 1.90, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),
(9010204, 830139, 0, 0, 1410, 6100, 6105, 1, 1, 0, 4600.0, -3764.2, 946.3, 1.60, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),
(9010205, 830140, 0, 0, 1410, 6100, 6105, 1, 1, 0, 4596.3, -3762.1, 946.6, 1.20, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),
(9010206, 830141, 0, 0, 1410, 6100, 6105, 1, 1, 0, 4593.0, -3758.4, 947.0, 0.90, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),
(9010207, 830142, 0, 0, 1410, 6100, 6105, 1, 1, 0, 4591.6, -3754.0, 947.1, 0.70, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),
(9010208, 830143, 0, 0, 1410, 6100, 6105, 1, 1, 0, 4616.4, -3770.1, 945.6, 4.20, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),
(9010209, 830144, 0, 0, 1410, 6100, 6105, 1, 1, 0, 4618.2, -3762.5, 945.5, 3.90, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),

-- Horde - Thrall's Vanguard (6106)
(9010220, 830145, 0, 0, 1410, 6100, 6106, 1, 1, 1, 5044.0, -2797.2, 1473.4, 2.60, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),  -- equipment_id=1 (axe+shield)
(9010221, 830146, 0, 0, 1410, 6100, 6106, 1, 1, 1, 5052.3, -2799.0, 1473.5, 2.20, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),  -- equipment_id=1 (unarmed row, civilian)
(9010222, 830147, 0, 0, 1410, 6100, 6106, 1, 1, 1, 5056.1, -2804.4, 1473.2, 2.40, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),  -- equipment_id=1 (unarmed row, vendor)
(9010223, 830148, 0, 0, 1410, 6100, 6106, 1, 1, 0, 5060.4, -2808.1, 1473.6, 2.00, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),
(9010224, 830149, 0, 0, 1410, 6100, 6106, 1, 1, 0, 5062.7, -2805.3, 1473.7, 1.90, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),
(9010225, 830150, 0, 0, 1410, 6100, 6106, 1, 1, 0, 5046.2, -2810.5, 1472.8, 1.40, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),
(9010226, 830151, 0, 0, 1410, 6100, 6106, 1, 1, 0, 5042.0, -2807.4, 1472.9, 1.20, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),
(9010227, 830152, 0, 0, 1410, 6100, 6106, 1, 1, 0, 5039.3, -2802.1, 1472.6, 1.00, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),
(9010228, 830153, 0, 0, 1410, 6100, 6106, 1, 1, 0, 5036.1, -2798.4, 1472.7, 0.70, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),
(9010229, 830154, 0, 0, 1410, 6100, 6106, 1, 1, 0, 5066.2, -2811.0, 1474.0, 2.10, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),
(9010230, 830155, 0, 0, 1410, 6100, 6106, 1, 1, 0, 5068.4, -2807.2, 1474.1, 2.30, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),
(9010231, 830156, 0, 0, 1410, 6100, 6106, 1, 1, 0, 5034.0, -2812.3, 1472.4, 0.90, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0),
(9010232, 830157, 0, 0, 1410, 6100, 6106, 1, 1, 0, 5070.1, -2802.4, 1474.2, 2.50, 300, 0, 0, 200000, 0, 0, 0, 0, 0, '', 0);
