-- Hyjal Frontier - zone population + quest chains (80-130)
--
-- This file adds:
--   1) Quest givers and ambient life NPCs for Alliance and Horde hubs.
--   2) Hostile creatures in level bands from 80 to 130.
--   3) Creature spawns on map 1410 across Foothills/Scorched/Summit/Nordrassil.
--   4) Two faction-specific quest chains:
--        Alliance: 81200-81204
--        Horde:    81210-81214
--   5) Additional region-fitting ambient and combat variants sourced from
--      map 534 model families to improve world density and visual cohesion.
--   6) Optional side-quest bands across the full range (81205-81223), with
--      higher-level quests requiring more kills to match XP pacing.
--
-- Model references were sampled from live Hyjal Summit themed creatures
-- (e.g. Ghoul/Banshee/Fel Stalker/Gargoyle/Crypt Fiend/Abomination/Frost Wyrm)
-- and major lore NPC displays (Jaina, Thrall, Tyrande, Malfurion), plus
-- Druid/Ancient/Infernal variants present on map 534.

-- -----------------------------------------------------------------------------
-- Cleanup
-- -----------------------------------------------------------------------------
DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 81200 AND 81223;
DELETE FROM `creature_questender`   WHERE `quest` BETWEEN 81200 AND 81223;
DELETE FROM `quest_request_items`   WHERE `ID`    BETWEEN 81200 AND 81223;
DELETE FROM `quest_offer_reward`    WHERE `ID`    BETWEEN 81200 AND 81223;
DELETE FROM `quest_template_addon`  WHERE `ID`    BETWEEN 81200 AND 81223;
DELETE FROM `quest_template`        WHERE `ID`    BETWEEN 81200 AND 81223;

DELETE FROM `creature`
WHERE (`map` = 1410 AND `id1` BETWEEN 830030 AND 830090)
   OR (`guid` BETWEEN 9010000 AND 9010199);

DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 830030 AND 830110;
DELETE FROM `creature_template`       WHERE `entry`      BETWEEN 830030 AND 830110;

-- -----------------------------------------------------------------------------
-- Creature templates
-- -----------------------------------------------------------------------------
INSERT INTO `creature_template`
    (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`,
     `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`,
     `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `unit_class`,
     `unit_flags`, `dynamicflags`, `family`, `type`, `type_flags`,
     `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`,
     `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
VALUES
-- Alliance quest line
(830030, 'Commander Elowen',       'Jaina''s Encampment', 80, 80, 1,
    12, 2, 1, 1.14286, 1, 3, 2000, 2000, 1,
    0, 0, 0, 7, 2, 20, 2, 2, 1,
    1, 2, '', 0),
(830031, 'Sentinel Aelaris',       'Foothills Watch', 88, 88, 1,
    12, 2, 1, 1.14286, 1, 4, 2000, 2000, 1,
    0, 0, 0, 7, 2, 24, 2, 2, 1,
    1, 2, '', 0),
(830032, 'Keeper Elunor',          'Scorched Grove Ward', 97, 97, 1,
    12, 2, 1, 1.14286, 1, 5, 2000, 2000, 2,
    0, 0, 0, 7, 2, 28, 8, 2, 1,
    1, 2, '', 0),
(830033, 'Warden Starfall',        'The Summit Vanguard', 112, 112, 1,
    12, 2, 1, 1.14286, 1, 7, 2000, 2000, 1,
    0, 0, 0, 7, 2, 34, 4, 2, 1,
    1, 2, '', 0),
(830034, 'Archdruid Rhydel',       'Nordrassil Defender', 127, 127, 1,
    12, 2, 1, 1.14286, 1, 9, 2000, 2000, 2,
    0, 0, 0, 7, 2, 42, 12, 2, 1,
    1, 2, '', 0),

-- Horde quest line
(830035, 'Warmaster Kargra',       'Thrall''s Encampment', 80, 80, 1,
    29, 2, 1, 1.14286, 1, 3, 2000, 2000, 1,
    0, 0, 0, 7, 2, 20, 2, 2, 1,
    1, 2, '', 0),
(830036, 'Scout Mavak',            'Forward Vanguard', 88, 88, 1,
    29, 2, 1, 1.14286, 1, 4, 2000, 2000, 1,
    0, 0, 0, 7, 2, 24, 2, 2, 1,
    1, 2, '', 0),
(830037, 'Spiritcaller Zorok',     'Flamebound Circle', 97, 97, 1,
    29, 2, 1, 1.14286, 1, 5, 2000, 2000, 2,
    0, 0, 0, 7, 2, 28, 8, 2, 1,
    1, 2, '', 0),
(830038, 'Battlelord Gromtar',     'Summit Warband', 112, 112, 1,
    29, 2, 1, 1.14286, 1, 7, 2000, 2000, 1,
    0, 0, 0, 7, 2, 34, 4, 2, 1,
    1, 2, '', 0),
(830039, 'Earthwarden Toran',      'Roots Protector', 127, 127, 1,
    29, 2, 1, 1.14286, 1, 9, 2000, 2000, 2,
    0, 0, 0, 7, 2, 42, 12, 2, 1,
    1, 2, '', 0),

-- Hostile progression bands
(830040, 'Charred Ghoul',          'Foothills Scourge', 80, 82, 1,
    14, 0, 1, 1.14286, 0, 3.6, 2000, 2000, 1,
    0, 0, 0, 6, 0, 9, 1, 1, 1,
    1, 0, '', 0),
(830041, 'Ashen Banshee',          'Foothills Scourge', 82, 84, 1,
    14, 0, 1, 1.14286, 0, 4.2, 2000, 2000, 8,
    0, 0, 0, 6, 0, 10, 8, 1, 1,
    1, 0, '', 0),
(830042, 'Blightbone Necromancer', 'Foothills Scourge', 84, 86, 1,
    14, 0, 1, 1.14286, 0, 4.8, 2000, 2000, 2,
    0, 0, 0, 6, 0, 11, 8, 1, 1,
    1, 0, '', 0),
(830050, 'Felfire Stalker',        'Scorched Groves', 95, 97, 1,
    14, 0, 1, 1.14286, 0, 6.0, 2000, 2000, 1,
    0, 0, 0, 3, 0, 16, 1, 1, 1,
    1, 0, '', 0),
(830051, 'Searing Doomguard',      'Scorched Groves', 97, 99, 1,
    14, 0, 1, 1.14286, 0, 6.8, 2000, 2000, 1,
    0, 0, 0, 3, 0, 18, 2, 1, 1,
    1, 0, '', 0),
(830052, 'Infernal Siegebreaker',  'Scorched Groves', 99, 101, 1,
    14, 0, 1, 1.14286, 1, 7.2, 2000, 2000, 1,
    0, 0, 0, 3, 0, 19, 2, 1, 1,
    1, 0, '', 0),
(830060, 'Summit Gargoyle',        'The Summit', 110, 112, 1,
    14, 0, 1, 1.14286, 0, 8.4, 2000, 2000, 1,
    0, 0, 0, 6, 0, 24, 1, 1, 1,
    1, 0, '', 0),
(830061, 'Shadow Crypt Fiend',     'The Summit', 112, 114, 1,
    14, 0, 1, 1.14286, 0, 9.1, 2000, 2000, 8,
    0, 0, 0, 6, 0, 26, 5, 1, 1,
    1, 0, '', 0),
(830062, 'Frostgrave Lich',        'The Summit', 114, 116, 1,
    14, 0, 1, 1.14286, 0, 9.8, 2000, 2000, 2,
    0, 0, 0, 6, 0, 27, 8, 1, 1,
    1, 0, '', 0),
(830070, 'Rotmaw Abomination',     'Nordrassil Roots', 125, 127, 1,
    14, 0, 1, 1.14286, 1, 11.8, 2000, 2000, 1,
    0, 0, 0, 6, 0, 34, 1, 2, 1,
    1, 0, '', 0),
(830071, 'Frostbone Wyrm',         'Nordrassil Roots', 127, 129, 1,
    14, 0, 1, 1.14286, 1, 12.8, 2000, 2000, 2,
    0, 0, 0, 6, 0, 36, 3, 2, 1,
    1, 0, '', 0),
(830073, 'Rootfire Infernal',      'Nordrassil Roots', 129, 130, 1,
    14, 0, 1, 1.14286, 1, 13.5, 2000, 2000, 1,
    0, 0, 0, 3, 0, 38, 2, 2, 1,
    1, 0, '', 0),
(830072, 'Hyjal Doomlord',         'Corruptor of the Roots', 130, 130, 1,
    14, 0, 1, 1.14286, 2, 18, 1800, 2000, 1,
    0, 0, 0, 3, 0, 72, 8, 3, 1,
    1, 0, '', 0),

-- Ambient life NPCs
(830080, 'Encampment Refugee',     'Alliance Survivor', 80, 82, 1,
    35, 0, 1, 1.14286, 0, 1, 2000, 2000, 1,
    0, 0, 0, 7, 2, 8, 1, 1, 1,
    1, 2, '', 0),
(830081, 'Vanguard Refugee',       'Horde Survivor', 80, 82, 1,
    36, 0, 1, 1.14286, 0, 1, 2000, 2000, 1,
    0, 0, 0, 7, 2, 8, 1, 1, 1,
    1, 2, '', 0),
(830082, 'Nordrassil Dryad',       'Warden of the Glades', 110, 112, 1,
    35, 0, 1, 1.14286, 0, 2, 2000, 2000, 2,
    0, 0, 0, 7, 2, 16, 8, 1, 1,
    1, 2, '', 0),
(830083, 'Kaldorei Ranger',        'Foothills Patrol', 82, 84, 1,
    35, 0, 1, 1.14286, 0, 2, 2000, 2000, 1,
    0, 0, 0, 7, 2, 14, 1, 1, 1,
    1, 2, '', 0),
(830084, 'Flamebound Shaman',      'Vanguard Support', 82, 84, 1,
    36, 0, 1, 1.14286, 0, 2, 2000, 2000, 2,
    0, 0, 0, 7, 2, 14, 6, 1, 1,
    1, 2, '', 0),
(830085, 'Talon Druid Scout',      'Foothills Recon', 88, 90, 1,
    35, 0, 1, 1.14286, 0, 2, 2000, 2000, 2,
    0, 0, 0, 7, 2, 18, 8, 1, 1,
    1, 2, '', 0),
(830086, 'Claw Druid Guardian',    'Summit Defender', 112, 114, 1,
    35, 0, 1, 1.14286, 0, 3, 2000, 2000, 1,
    0, 0, 0, 7, 2, 24, 2, 1, 1,
    1, 2, '', 0),
(830087, 'Ancient of War Sentinel', 'Nordrassil Bulwark', 120, 122, 1,
    35, 0, 1, 1.14286, 1, 4, 2000, 2000, 1,
    0, 0, 0, 5, 2, 40, 1, 2, 1,
    1, 2, '', 0),
(830088, 'Ancient of Lore Keeper', 'Nordrassil Lorekeeper', 120, 122, 1,
    35, 0, 1, 1.14286, 1, 3.5, 2000, 2000, 2,
    0, 0, 0, 5, 2, 36, 8, 2, 1,
    1, 2, '', 0),
(830089, 'Alliance Field Priest',  'Jaina''s Encampment', 80, 82, 1,
    35, 0, 1, 1.14286, 0, 2.2, 2000, 2000, 2,
    0, 0, 0, 7, 2, 16, 8, 1, 1,
    1, 2, '', 0),
(830090, 'Vanguard Witch Doctor',  'Thrall''s Encampment', 80, 82, 1,
    36, 0, 1, 1.14286, 0, 2.2, 2000, 2000, 2,
    0, 0, 0, 7, 2, 16, 8, 1, 1,
    1, 2, '', 0),

-- Additional full-range variants (manual spawn placement expected)
(830091, 'Foothills Bone Reaver',  'Foothills Scourge', 86, 88, 1,
    14, 0, 1, 1.14286, 0, 5.0, 2000, 2000, 1,
    0, 0, 0, 6, 0, 12, 1, 1, 1,
    1, 0, '', 0),
(830092, 'Foothills Deathcaller',  'Foothills Scourge', 88, 90, 1,
    14, 0, 1, 1.14286, 0, 5.6, 2000, 2000, 2,
    0, 0, 0, 6, 0, 13, 8, 1, 1,
    1, 0, '', 0),
(830093, 'Scorched Felmaw',        'Scorched Groves', 100, 102, 1,
    14, 0, 1, 1.14286, 0, 7.6, 2000, 2000, 1,
    0, 0, 0, 3, 0, 21, 1, 1, 1,
    1, 0, '', 0),
(830094, 'Scorched Doomflayer',    'Scorched Groves', 103, 105, 1,
    14, 0, 1, 1.14286, 0, 8.3, 2000, 2000, 1,
    0, 0, 0, 3, 0, 23, 2, 1, 1,
    1, 0, '', 0),
(830095, 'Summit Boneweaver',      'The Summit', 116, 118, 1,
    14, 0, 1, 1.14286, 0, 10.1, 2000, 2000, 2,
    0, 0, 0, 6, 0, 29, 8, 1, 1,
    1, 0, '', 0),
(830096, 'Summit Gravewing',       'The Summit', 118, 120, 1,
    14, 0, 1, 1.14286, 0, 10.7, 2000, 2000, 1,
    0, 0, 0, 6, 0, 31, 2, 1, 1,
    1, 0, '', 0),
(830097, 'Rootbound Colossus',     'Nordrassil Roots', 122, 124, 1,
    14, 0, 1, 1.14286, 1, 12.4, 2000, 2000, 1,
    0, 0, 0, 6, 0, 35, 1, 2, 1,
    1, 0, '', 0),
(830098, 'Rootflame Devastator',   'Nordrassil Roots', 126, 128, 1,
    14, 0, 1, 1.14286, 1, 13.3, 2000, 2000, 1,
    0, 0, 0, 3, 0, 39, 2, 2, 1,
    1, 0, '', 0),
(830099, 'Talon Veteran',          'Nordrassil Vanguard', 104, 106, 1,
    35, 0, 1, 1.14286, 0, 2.6, 2000, 2000, 1,
    0, 0, 0, 7, 2, 20, 2, 1, 1,
    1, 2, '', 0),
(830100, 'Vanguard Battlemender',  'Roots Support', 118, 120, 1,
    36, 0, 1, 1.14286, 0, 2.9, 2000, 2000, 2,
    0, 0, 0, 7, 2, 24, 8, 1, 1,
    1, 2, '', 0);

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
VALUES
(830030, 0, 30864, 1, 1, 0),
(830031, 0, 17322, 1, 1, 0),
(830032, 0, 17342, 1, 1, 0),
(830033, 0, 17873, 1, 1, 0),
(830034, 0, 15399, 1, 1, 0),
(830035, 0, 17370, 1, 1, 0),
(830036, 0, 17331, 1, 1, 0),
(830037, 0, 17336, 1, 1, 0),
(830038, 0, 17332, 1, 1, 0),
(830039, 0, 1460,  1, 1, 0),
(830040, 0, 571,   1, 1, 0),
(830041, 0, 8783,  1, 1, 0),
(830042, 0, 17537, 1, 1, 0),
(830050, 0, 17321, 1, 1, 0),
(830051, 0, 20930, 1, 1, 0),
(830052, 0, 15880, 1, 1, 0),
(830060, 0, 17311, 1, 1, 0),
(830061, 0, 17308, 1, 1, 0),
(830062, 0, 17537, 1, 1, 0),
(830070, 0, 12818, 1, 1, 0),
(830071, 0, 16919, 1, 1, 0),
(830072, 0, 1912,  1, 1, 0),
(830073, 0, 15880, 1, 1, 0),
(830080, 0, 17325, 1, 1, 0),
(830081, 0, 17338, 1, 1, 0),
(830082, 0, 17340, 1, 1, 0),
(830083, 0, 17339, 1, 1, 0),
(830084, 0, 17337, 1, 1, 0),
(830085, 0, 17343, 1, 1, 0),
(830086, 0, 17342, 1, 1, 0),
(830087, 0, 1461,  1, 1, 0),
(830088, 0, 1460,  1, 1, 0),
(830089, 0, 17329, 1, 1, 0),
(830090, 0, 17336, 1, 1, 0),
(830091, 0, 571,   1, 1, 0),
(830092, 0, 17537, 1, 1, 0),
(830093, 0, 17321, 1, 1, 0),
(830094, 0, 20930, 1, 1, 0),
(830095, 0, 17308, 1, 1, 0),
(830096, 0, 17311, 1, 1, 0),
(830097, 0, 12818, 1, 1, 0),
(830098, 0, 15880, 1, 1, 0),
(830099, 0, 17343, 1, 1, 0),
(830100, 0, 17336, 1, 1, 0);

-- -----------------------------------------------------------------------------
-- Spawns (map 1410)
-- -----------------------------------------------------------------------------
INSERT INTO `creature`
    (`guid`, `id1`, `id2`, `id3`, `map`, `zoneId`, `areaId`, `spawnMask`,
     `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`,
     `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`,
     `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`,
     `dynamicflags`, `ScriptName`, `VerifiedBuild`)
VALUES
-- Alliance base (6105)
(9010000, 830020, 0, 0, 1410, 6100, 6105, 1, 1, 1, 4602.5, -3758.2, 946.4, 1.57, 300, 0, 0, 250000, 0, 0, 0, 0, 0, '', 0),
(9010001, 830023, 0, 0, 1410, 6100, 6105, 1, 1, 1, 4606.1, -3754.4, 946.8, 2.33, 300, 0, 0, 220000, 0, 0, 0, 0, 0, '', 0),
(9010002, 830024, 0, 0, 1410, 6100, 6105, 1, 1, 1, 4608.4, -3761.0, 946.0, 1.30, 300, 0, 0, 250000, 0, 0, 0, 0, 0, '', 0),
(9010003, 830030, 0, 0, 1410, 6100, 6105, 1, 1, 1, 4598.9, -3760.3, 947.2, 1.88, 300, 0, 0, 260000, 35000, 0, 0, 0, 0, '', 0),
(9010004, 830021, 0, 0, 1410, 6100, 6105, 1, 1, 1, 4596.8, -3754.8, 947.1, 1.51, 300, 0, 0, 240000, 0, 0, 0, 0, 0, '', 0),
(9010005, 830021, 0, 0, 1410, 6100, 6105, 1, 1, 1, 4615.0, -3765.8, 945.4, 4.55, 300, 0, 0, 240000, 0, 0, 0, 0, 0, '', 0),
(9010006, 830080, 0, 0, 1410, 6100, 6105, 1, 1, 0, 4604.6, -3770.2, 946.1, 5.11, 300, 0, 0, 150000, 0, 0, 0, 0, 0, '', 0),
(9010007, 830083, 0, 0, 1410, 6100, 6105, 1, 1, 0, 4612.3, -3752.0, 947.0, 2.84, 300, 0, 0, 170000, 0, 0, 0, 0, 0, '', 0),
(9010008, 830014, 0, 0, 1410, 6100, 6105, 1, 1, 1, 4590.8, -3768.2, 947.2, 0.99, 300, 0, 0, 180000, 0, 0, 0, 0, 0, '', 0),
(9010009, 830016, 0, 0, 1410, 6100, 6105, 1, 1, 1, 4594.4, -3772.8, 946.9, 0.80, 300, 0, 0, 170000, 50000, 0, 0, 0, 0, '', 0),

-- Horde encampment (6106)
(9010010, 830035, 0, 0, 1410, 6100, 6106, 1, 1, 1, 5048.1, -2803.3, 1473.2, 2.93, 300, 0, 0, 260000, 35000, 0, 0, 0, 0, '', 0),
(9010011, 830036, 0, 0, 1410, 6100, 6106, 1, 1, 1, 5054.6, -2795.8, 1473.6, 2.11, 300, 0, 0, 220000, 0, 0, 0, 0, 0, '', 0),
(9010012, 830022, 0, 0, 1410, 6100, 6106, 1, 1, 1, 5038.9, -2805.0, 1472.8, 2.44, 300, 0, 0, 240000, 0, 0, 0, 0, 0, '', 0),
(9010013, 830022, 0, 0, 1410, 6100, 6106, 1, 1, 1, 5066.8, -2799.2, 1473.9, 2.62, 300, 0, 0, 240000, 0, 0, 0, 0, 0, '', 0),
(9010014, 830081, 0, 0, 1410, 6100, 6106, 1, 1, 0, 5041.6, -2812.5, 1472.1, 1.12, 300, 0, 0, 150000, 0, 0, 0, 0, 0, '', 0),
(9010015, 830084, 0, 0, 1410, 6100, 6106, 1, 1, 0, 5059.2, -2810.8, 1473.4, 5.58, 300, 0, 0, 175000, 45000, 0, 0, 0, 0, '', 0),
(9010016, 830008, 0, 0, 1410, 6100, 6106, 1, 1, 1, 5070.4, -2817.0, 1475.2, 4.88, 300, 0, 0, 185000, 0, 0, 0, 0, 0, '', 0),
(9010017, 830010, 0, 0, 1410, 6100, 6106, 1, 1, 1, 5034.0, -2794.6, 1472.5, 0.34, 300, 0, 0, 185000, 0, 0, 0, 0, 0, '', 0),
(9010018, 830089, 0, 0, 1410, 6100, 6105, 1, 1, 0, 4609.5, -3748.6, 947.4, 2.71, 300, 0, 0, 175000, 52000, 0, 0, 0, 0, '', 0),
(9010019, 830090, 0, 0, 1410, 6100, 6106, 1, 1, 0, 5062.8, -2791.4, 1474.1, 2.04, 300, 0, 0, 175000, 52000, 0, 0, 0, 0, '', 0),

-- Progression quest hubs
(9010020, 830031, 0, 0, 1410, 6100, 6101, 1, 1, 1, 4632.0, -3835.1, 945.2, 0.97, 300, 0, 0, 220000, 0, 0, 0, 0, 0, '', 0),
(9010021, 830032, 0, 0, 1410, 6100, 6102, 1, 1, 1, 5091.4, -2868.9, 1471.4, 0.75, 300, 0, 0, 230000, 55000, 0, 0, 0, 0, '', 0),
(9010022, 830033, 0, 0, 1410, 6100, 6103, 1, 1, 1, 5164.7, -3433.1, 1629.8, 2.40, 300, 0, 0, 240000, 60000, 0, 0, 0, 0, '', 0),
(9010023, 830034, 0, 0, 1410, 6100, 6104, 1, 1, 1, 5372.3, -3377.4, 1659.5, 2.95, 300, 0, 0, 260000, 70000, 0, 0, 0, 0, '', 0),
(9010024, 830037, 0, 0, 1410, 6100, 6102, 1, 1, 1, 5118.8, -2894.2, 1472.0, 4.17, 300, 0, 0, 230000, 52000, 0, 0, 0, 0, '', 0),
(9010025, 830038, 0, 0, 1410, 6100, 6103, 1, 1, 1, 5201.2, -3389.0, 1630.3, 3.78, 300, 0, 0, 245000, 0, 0, 0, 0, 0, '', 0),
(9010026, 830039, 0, 0, 1410, 6100, 6104, 1, 1, 1, 5346.4, -3361.5, 1655.4, 1.80, 300, 0, 0, 255000, 65000, 0, 0, 0, 0, '', 0),
(9010027, 830082, 0, 0, 1410, 6100, 6103, 1, 1, 0, 5175.0, -3424.5, 1631.0, 5.91, 300, 0, 0, 180000, 40000, 0, 0, 0, 0, '', 0),
(9010028, 830085, 0, 0, 1410, 6100, 6101, 1, 1, 0, 4627.4, -3826.9, 944.7, 0.43, 300, 8, 0, 185000, 60000, 1, 0, 0, 0, '', 0),
(9010029, 830086, 0, 0, 1410, 6100, 6103, 1, 1, 0, 5182.6, -3438.8, 1632.8, 2.08, 300, 8, 0, 210000, 0, 1, 0, 0, 0, '', 0),
(9010030, 830087, 0, 0, 1410, 6100, 6104, 1, 1, 0, 5359.6, -3368.3, 1657.8, 1.54, 300, 5, 0, 320000, 0, 1, 0, 0, 0, '', 0),
(9010031, 830088, 0, 0, 1410, 6100, 6104, 1, 1, 0, 5338.4, -3374.9, 1654.2, 3.62, 300, 5, 0, 300000, 75000, 1, 0, 0, 0, '', 0),

-- Foothills enemies (6101)
(9010040, 830040, 0, 0, 1410, 6100, 6101, 1, 1, 0, 4618.0, -3854.0, 944.3, 1.11, 300, 12, 0, 55000, 0, 1, 0, 0, 0, '', 0),
(9010041, 830040, 0, 0, 1410, 6100, 6101, 1, 1, 0, 4625.4, -3860.7, 945.1, 2.35, 300, 12, 0, 55000, 0, 1, 0, 0, 0, '', 0),
(9010042, 830040, 0, 0, 1410, 6100, 6101, 1, 1, 0, 4631.8, -3865.2, 947.0, 4.88, 300, 12, 0, 55000, 0, 1, 0, 0, 0, '', 0),
(9010043, 830040, 0, 0, 1410, 6100, 6101, 1, 1, 0, 4609.7, -3847.5, 944.4, 5.64, 300, 12, 0, 55000, 0, 1, 0, 0, 0, '', 0),
(9010044, 830040, 0, 0, 1410, 6100, 6101, 1, 1, 0, 4598.4, -3856.9, 945.0, 3.94, 300, 12, 0, 55000, 0, 1, 0, 0, 0, '', 0),
(9010045, 830040, 0, 0, 1410, 6100, 6101, 1, 1, 0, 4638.6, -3849.4, 946.4, 2.79, 300, 12, 0, 55000, 0, 1, 0, 0, 0, '', 0),
(9010046, 830040, 0, 0, 1410, 6100, 6101, 1, 1, 0, 4612.9, -3839.8, 944.2, 0.87, 300, 12, 0, 55000, 0, 1, 0, 0, 0, '', 0),
(9010047, 830040, 0, 0, 1410, 6100, 6101, 1, 1, 0, 4622.0, -3835.2, 944.1, 6.11, 300, 12, 0, 55000, 0, 1, 0, 0, 0, '', 0),
(9010050, 830041, 0, 0, 1410, 6100, 6101, 1, 1, 0, 4640.8, -3868.4, 949.0, 1.95, 300, 10, 0, 48000, 32000, 1, 0, 0, 0, '', 0),
(9010051, 830041, 0, 0, 1410, 6100, 6101, 1, 1, 0, 4589.2, -3848.4, 947.2, 4.02, 300, 10, 0, 48000, 32000, 1, 0, 0, 0, '', 0),
(9010052, 830041, 0, 0, 1410, 6100, 6101, 1, 1, 0, 4629.7, -3872.2, 949.4, 3.16, 300, 10, 0, 48000, 32000, 1, 0, 0, 0, '', 0),
(9010053, 830041, 0, 0, 1410, 6100, 6101, 1, 1, 0, 4637.8, -3829.7, 949.1, 5.22, 300, 10, 0, 48000, 32000, 1, 0, 0, 0, '', 0),

-- Horde-side starter pressure (6106)
(9010054, 830040, 0, 0, 1410, 6100, 6106, 1, 1, 0, 5039.7, -2828.8, 1471.1, 1.00, 300, 12, 0, 55000, 0, 1, 0, 0, 0, '', 0),
(9010055, 830040, 0, 0, 1410, 6100, 6106, 1, 1, 0, 5050.1, -2834.9, 1472.0, 2.10, 300, 12, 0, 55000, 0, 1, 0, 0, 0, '', 0),
(9010056, 830040, 0, 0, 1410, 6100, 6106, 1, 1, 0, 5060.6, -2829.5, 1473.3, 3.10, 300, 12, 0, 55000, 0, 1, 0, 0, 0, '', 0),
(9010057, 830040, 0, 0, 1410, 6100, 6106, 1, 1, 0, 5046.2, -2842.1, 1471.6, 4.20, 300, 12, 0, 55000, 0, 1, 0, 0, 0, '', 0),
(9010058, 830041, 0, 0, 1410, 6100, 6106, 1, 1, 0, 5065.3, -2838.4, 1475.1, 2.48, 300, 10, 0, 48000, 32000, 1, 0, 0, 0, '', 0),
(9010059, 830041, 0, 0, 1410, 6100, 6106, 1, 1, 0, 5032.8, -2835.9, 1474.0, 5.66, 300, 10, 0, 48000, 32000, 1, 0, 0, 0, '', 0),

-- Scorched Groves enemies (6102)
(9010060, 830050, 0, 0, 1410, 6100, 6102, 1, 1, 0, 5084.1, -2862.1, 1471.3, 1.55, 300, 14, 0, 90000, 0, 1, 0, 0, 0, '', 0),
(9010061, 830050, 0, 0, 1410, 6100, 6102, 1, 1, 0, 5091.9, -2854.7, 1472.0, 2.35, 300, 14, 0, 90000, 0, 1, 0, 0, 0, '', 0),
(9010062, 830050, 0, 0, 1410, 6100, 6102, 1, 1, 0, 5101.6, -2868.4, 1471.0, 4.88, 300, 14, 0, 90000, 0, 1, 0, 0, 0, '', 0),
(9010063, 830050, 0, 0, 1410, 6100, 6102, 1, 1, 0, 5076.8, -2873.3, 1470.8, 3.44, 300, 14, 0, 90000, 0, 1, 0, 0, 0, '', 0),
(9010064, 830050, 0, 0, 1410, 6100, 6102, 1, 1, 0, 5068.5, -2858.9, 1471.4, 5.12, 300, 14, 0, 90000, 0, 1, 0, 0, 0, '', 0),
(9010065, 830050, 0, 0, 1410, 6100, 6102, 1, 1, 0, 5112.0, -2849.1, 1473.0, 0.92, 300, 14, 0, 90000, 0, 1, 0, 0, 0, '', 0),
(9010066, 830050, 0, 0, 1410, 6100, 6102, 1, 1, 0, 5098.7, -2839.3, 1472.8, 2.79, 300, 14, 0, 90000, 0, 1, 0, 0, 0, '', 0),
(9010067, 830050, 0, 0, 1410, 6100, 6102, 1, 1, 0, 5079.2, -2844.4, 1471.6, 1.21, 300, 14, 0, 90000, 0, 1, 0, 0, 0, '', 0),
(9010070, 830051, 0, 0, 1410, 6100, 6102, 1, 1, 0, 5115.3, -2860.6, 1474.2, 1.71, 300, 12, 0, 105000, 0, 1, 0, 0, 0, '', 0),
(9010071, 830051, 0, 0, 1410, 6100, 6102, 1, 1, 0, 5120.7, -2848.5, 1475.1, 2.84, 300, 12, 0, 105000, 0, 1, 0, 0, 0, '', 0),
(9010072, 830051, 0, 0, 1410, 6100, 6102, 1, 1, 0, 5064.3, -2874.2, 1471.2, 4.01, 300, 12, 0, 105000, 0, 1, 0, 0, 0, '', 0),
(9010073, 830051, 0, 0, 1410, 6100, 6102, 1, 1, 0, 5059.1, -2852.2, 1471.1, 5.48, 300, 12, 0, 105000, 0, 1, 0, 0, 0, '', 0),
(9010074, 830051, 0, 0, 1410, 6100, 6102, 1, 1, 0, 5108.8, -2878.5, 1472.6, 0.45, 300, 12, 0, 105000, 0, 1, 0, 0, 0, '', 0),

-- Summit enemies (6103)
(9010080, 830060, 0, 0, 1410, 6100, 6103, 1, 1, 0, 5154.4, -3440.6, 1627.9, 1.24, 300, 14, 0, 145000, 0, 1, 0, 0, 0, '', 0),
(9010081, 830060, 0, 0, 1410, 6100, 6103, 1, 1, 0, 5161.5, -3451.2, 1628.7, 2.20, 300, 14, 0, 145000, 0, 1, 0, 0, 0, '', 0),
(9010082, 830060, 0, 0, 1410, 6100, 6103, 1, 1, 0, 5172.0, -3444.5, 1630.0, 3.42, 300, 14, 0, 145000, 0, 1, 0, 0, 0, '', 0),
(9010083, 830060, 0, 0, 1410, 6100, 6103, 1, 1, 0, 5148.9, -3428.6, 1628.3, 4.77, 300, 14, 0, 145000, 0, 1, 0, 0, 0, '', 0),
(9010084, 830060, 0, 0, 1410, 6100, 6103, 1, 1, 0, 5179.4, -3435.1, 1631.4, 6.08, 300, 14, 0, 145000, 0, 1, 0, 0, 0, '', 0),
(9010085, 830060, 0, 0, 1410, 6100, 6103, 1, 1, 0, 5186.0, -3422.3, 1633.3, 5.62, 300, 14, 0, 145000, 0, 1, 0, 0, 0, '', 0),
(9010086, 830060, 0, 0, 1410, 6100, 6103, 1, 1, 0, 5139.3, -3433.8, 1627.6, 0.66, 300, 14, 0, 145000, 0, 1, 0, 0, 0, '', 0),
(9010090, 830061, 0, 0, 1410, 6100, 6103, 1, 1, 0, 5168.8, -3418.6, 1631.6, 1.47, 300, 12, 0, 138000, 54000, 1, 0, 0, 0, '', 0),
(9010091, 830061, 0, 0, 1410, 6100, 6103, 1, 1, 0, 5178.3, -3409.0, 1633.8, 2.97, 300, 12, 0, 138000, 54000, 1, 0, 0, 0, '', 0),
(9010092, 830061, 0, 0, 1410, 6100, 6103, 1, 1, 0, 5147.5, -3412.9, 1629.5, 4.38, 300, 12, 0, 138000, 54000, 1, 0, 0, 0, '', 0),
(9010093, 830061, 0, 0, 1410, 6100, 6103, 1, 1, 0, 5138.1, -3421.5, 1628.0, 5.13, 300, 12, 0, 138000, 54000, 1, 0, 0, 0, '', 0),
(9010094, 830061, 0, 0, 1410, 6100, 6103, 1, 1, 0, 5188.2, -3416.4, 1634.4, 0.52, 300, 12, 0, 138000, 54000, 1, 0, 0, 0, '', 0),

-- Nordrassil enemies (6104)
(9010100, 830070, 0, 0, 1410, 6100, 6104, 1, 1, 0, 5360.2, -3384.9, 1657.6, 1.39, 300, 14, 0, 230000, 0, 1, 0, 0, 0, '', 0),
(9010101, 830070, 0, 0, 1410, 6100, 6104, 1, 1, 0, 5368.9, -3395.4, 1658.1, 2.19, 300, 14, 0, 230000, 0, 1, 0, 0, 0, '', 0),
(9010102, 830070, 0, 0, 1410, 6100, 6104, 1, 1, 0, 5378.3, -3401.2, 1660.3, 3.40, 300, 14, 0, 230000, 0, 1, 0, 0, 0, '', 0),
(9010103, 830070, 0, 0, 1410, 6100, 6104, 1, 1, 0, 5386.4, -3389.1, 1661.7, 4.52, 300, 14, 0, 230000, 0, 1, 0, 0, 0, '', 0),
(9010104, 830070, 0, 0, 1410, 6100, 6104, 1, 1, 0, 5352.7, -3374.8, 1656.4, 5.90, 300, 14, 0, 230000, 0, 1, 0, 0, 0, '', 0),
(9010110, 830071, 0, 0, 1410, 6100, 6104, 1, 1, 0, 5389.5, -3371.3, 1662.5, 2.62, 300, 16, 0, 240000, 38000, 1, 0, 0, 0, '', 0),
(9010111, 830071, 0, 0, 1410, 6100, 6104, 1, 1, 0, 5395.7, -3383.8, 1663.4, 3.87, 300, 16, 0, 240000, 38000, 1, 0, 0, 0, '', 0),
(9010112, 830071, 0, 0, 1410, 6100, 6104, 1, 1, 0, 5347.2, -3390.0, 1655.3, 0.66, 300, 16, 0, 240000, 38000, 1, 0, 0, 0, '', 0),
(9010120, 830072, 0, 0, 1410, 6100, 6104, 1, 1, 0, 5378.0, -3388.0, 1662.1, 4.11, 300, 8, 0, 400000, 120000, 1, 0, 0, 0, '', 0);

-- -----------------------------------------------------------------------------
-- Balance pass: smooth HP and mana curves for 80-130 pacing
-- -----------------------------------------------------------------------------
UPDATE `creature`
SET `curhealth` = CASE `id1`
        WHEN 830040 THEN 46000
        WHEN 830041 THEN 43000
        WHEN 830042 THEN 52000
        WHEN 830050 THEN 78000
        WHEN 830051 THEN 92000
        WHEN 830052 THEN 112000
        WHEN 830060 THEN 118000
        WHEN 830061 THEN 128000
        WHEN 830062 THEN 145000
        WHEN 830070 THEN 180000
        WHEN 830071 THEN 205000
        WHEN 830073 THEN 255000
        WHEN 830072 THEN 320000
        ELSE `curhealth`
END
WHERE `map` = 1410
    AND `id1` IN (830040, 830041, 830042, 830050, 830051, 830052,
                                830060, 830061, 830062, 830070, 830071, 830073, 830072);

UPDATE `creature`
SET `curmana` = CASE `id1`
        WHEN 830041 THEN 36000
        WHEN 830042 THEN 42000
        WHEN 830061 THEN 62000
        WHEN 830062 THEN 68000
        WHEN 830072 THEN 150000
        ELSE `curmana`
END
WHERE `map` = 1410
    AND `id1` IN (830041, 830042, 830061, 830062, 830072);

-- -----------------------------------------------------------------------------
-- Quest templates
-- -----------------------------------------------------------------------------
-- Side quests 81205-81223 intentionally do not include spawn rows for
-- 830042/830052/830062/830073/830091-830100; those placements are expected to be added
-- manually.
INSERT INTO `quest_template`
    (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`,
     `QuestInfoID`, `RewardXPDifficulty`, `RewardMoney`, `AllowableRaces`,
     `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`,
     `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`,
     `RequiredNpcOrGo2`, `RequiredNpcOrGoCount2`,
     `ObjectiveText1`, `ObjectiveText2`, `VerifiedBuild`)
VALUES
-- Alliance chain
(81200, 2, 80, 80, 6100, 0, 4, 0, 1101,
 'Alliance: Into the Foothills',
 'Report to Sentinel Aelaris in the Foothills.',
 'Commander Elowen sends you to reinforce the Foothills line. Find Sentinel Aelaris and await orders.',
 'Foothills, west of the alliance base.',
 'Aelaris is ready to brief you.',
 830031, 1, 0, 0,
 'Speak with Sentinel Aelaris', '', 0),

(81201, 2, 82, 80, 6100, 0, 5, 0, 1101,
 'Alliance: Cinders in the Brush',
 'Cull Charred Ghouls and Ashen Banshees in the Foothills.',
 'The Scourge remnants are pushing into Foothills paths. Break their vanguard before it reaches camp.',
 'Foothills skirmish line.',
 'The Foothills line is stable again.',
 830040, 8, 830041, 4,
 'Charred Ghouls slain', 'Ashen Banshees slain', 0),

(81202, 2, 95, 90, 6100, 0, 6, 0, 1101,
 'Alliance: Through the Scorched Pass',
 'Report to Keeper Elunor in the Scorched Groves.',
 'Your next objective lies deeper in Hyjal. Keeper Elunor is coordinating the grove defenses.',
 'Scorched Groves field post.',
 'Elunor takes command of your next push.',
 830032, 1, 0, 0,
 'Speak with Keeper Elunor', '', 0),

(81203, 2, 97, 95, 6100, 0, 7, 0, 1101,
 'Alliance: Break the Felfire Pack',
 'Defeat Felfire Stalkers and Searing Doomguards in Scorched Groves.',
 'Demons are using the burns as staging grounds. Shatter their line and force a retreat.',
 'Scorched Groves combat zone.',
 'The felfire patrols are broken.',
 830050, 9, 830051, 5,
 'Felfire Stalkers slain', 'Searing Doomguards slain', 0),

(81204, 2, 127, 120, 6100, 0, 9, 0, 1101,
 'Alliance: Root-Rot Extermination',
 'Destroy Rotmaw Abominations and slay the Hyjal Doomlord.',
 'The corruption has reached Nordrassil''s roots. Remove the abominations and kill their doom commander.',
 'Nordrassil Roots final assault.',
 'Nordrassil breathes easier thanks to your strike.',
 830070, 4, 830072, 1,
 'Rotmaw Abominations slain', 'Hyjal Doomlord slain', 0),

-- Optional side quests using custom variants
(81205, 2, 86, 82, 6100, 0, 5, 0, 0,
 'Optional: Blightbone Rituals',
 'Hunt Blightbone Necromancers in the Foothills.',
 'A fresh necromancer cabal is raising new corpses in the foothills. Break their rite circles before they spread further.',
 'Foothills side objective.',
 'The ritual circles are in ashes.',
 830042, 6, 0, 0,
 'Blightbone Necromancers slain', '', 0),

(81206, 2, 100, 95, 6100, 0, 6, 0, 0,
 'Optional: Infernal Breach',
 'Destroy Infernal Siegebreakers in the Scorched Groves.',
 'Fel commanders are dropping siegebreaker infernals into the grove front. Smash them before they reinforce the main line.',
 'Scorched Groves side objective.',
 'The infernal breach has collapsed.',
 830052, 5, 0, 0,
 'Infernal Siegebreakers slain', '', 0),

(81207, 2, 115, 110, 6100, 0, 7, 0, 0,
 'Optional: Lichfire on the Summit',
 'Slay Frostgrave Liches on the summit ridge.',
 'Frostgrave liches are binding undead winds across the summit. Silence their channels and clear the ridge.',
 'Summit side objective.',
 'The lichfire has faded from the summit.',
 830062, 5, 0, 0,
 'Frostgrave Liches slain', '', 0),

(81208, 2, 129, 125, 6100, 0, 8, 0, 0,
 'Optional: Rootfire Suppression',
 'Cull Rootfire Infernals in Nordrassil Roots.',
 'Rootfire infernals are spreading flame beneath the boughs. Cut down their numbers before the roots are lost.',
 'Nordrassil side objective.',
 'The rootfire advance has been checked.',
 830073, 4, 0, 0,
 'Rootfire Infernals slain', '', 0),

(81209, 2, 130, 127, 6100, 0, 9, 0, 0,
 'Optional: Twilight of the Variants',
 'Finish off the strongest variant leaders in Summit and Nordrassil.',
 'Your scouts identified two hardpoints still feeding the invasion. Eliminate both leaders to end their local command.',
 'Summit and Nordrassil side objective.',
 'The variant command cells have been eliminated.',
 830062, 3, 830073, 2,
 'Frostgrave Liches slain', 'Rootfire Infernals slain', 0),

(81215, 2, 88, 84, 6100, 0, 5, 0, 0,
 'Optional: Bone Reaver Rampage',
 'Cull Foothills Bone Reavers.',
 'A denser wave of bone reavers now stalks the foothills roads. Break their push before supply lines collapse.',
 'Foothills side objective.',
 'The road is safer for now.',
 830091, 7, 0, 0,
 'Foothills Bone Reavers slain', '', 0),

(81216, 2, 90, 86, 6100, 0, 5, 0, 0,
 'Optional: Deathcaller Culling',
 'Defeat Foothills Deathcallers.',
 'The deathcallers are reinforcing every skirmish with fresh undead. Stop their rituals before nightfall.',
 'Foothills side objective.',
 'Their chants have gone silent.',
 830092, 8, 0, 0,
 'Foothills Deathcallers slain', '', 0),

(81217, 2, 102, 98, 6100, 0, 6, 0, 0,
 'Optional: Felmaw Hunt',
 'Hunt Scorched Felmaws.',
 'Felmaws are running loose through the scorched lanes. Track them down before they regroup with the demon front.',
 'Scorched Groves side objective.',
 'The felmaw packs are broken.',
 830093, 9, 0, 0,
 'Scorched Felmaws slain', '', 0),

(81218, 2, 105, 101, 6100, 0, 6, 0, 0,
 'Optional: Doomflayer Break',
 'Destroy Scorched Doomflayers.',
 'Doomflayers are carving a path toward the groves. Bring down their assault unit before it reaches the wards.',
 'Scorched Groves side objective.',
 'The doomflayer push has stalled.',
 830094, 10, 0, 0,
 'Scorched Doomflayers slain', '', 0),

(81219, 2, 116, 112, 6100, 0, 7, 0, 0,
 'Optional: Boneweaver Severance',
 'Eliminate Summit Boneweavers.',
 'Boneweavers are webbing the summit paths with frost-bone traps. Tear down their network before patrols are trapped.',
 'Summit side objective.',
 'The summit lanes are open again.',
 830095, 11, 0, 0,
 'Summit Boneweavers slain', '', 0),

(81220, 2, 120, 116, 6100, 0, 7, 0, 0,
 'Optional: Gravewing Crash',
 'Bring down Summit Gravewings.',
 'Gravewings are circling above the summit war camp. Ground them before they thin out the defenders.',
 'Summit side objective.',
 'The summit sky is clear.',
 830096, 12, 0, 0,
 'Summit Gravewings slain', '', 0),

(81221, 2, 124, 120, 6100, 0, 8, 0, 0,
 'Optional: Rootbound Sweep',
 'Cull Rootbound Colossi.',
 'Rootbound colossi are trampling through the lower roots. Thin their numbers before they crush the ward lines.',
 'Nordrassil side objective.',
 'The lower roots are holding.',
 830097, 13, 0, 0,
 'Rootbound Colossi slain', '', 0),

(81222, 2, 128, 124, 6100, 0, 8, 0, 0,
 'Optional: Rootflame Collapse',
 'Destroy Rootflame Devastators.',
 'Rootflame devastators are igniting the upper roots. Crush the heaviest siege element before the flames spread.',
 'Nordrassil side objective.',
 'The rootflame surge has been checked.',
 830098, 14, 0, 0,
 'Rootflame Devastators slain', '', 0),

(81223, 2, 130, 127, 6100, 0, 9, 0, 0,
 'Optional: End of the Breach',
 'Break both Nordrassil variant battlegroups.',
 'Two variant battlegroups remain entrenched around the roots. Wipe them out to close the final breach.',
 'Nordrassil side objective.',
 'The breach is finally sealed.',
 830097, 8, 830098, 8,
 'Rootbound Colossi slain', 'Rootflame Devastators slain', 0),

-- Horde chain
(81210, 2, 80, 80, 6100, 0, 4, 0, 690,
 'Horde: Vanguard Forward',
 'Report to Scout Mavak at the forward line.',
 'Warmaster Kargra orders you to the front edge of the encampment. Scout Mavak has the next assignment.',
 'Forward line near the horde encampment.',
 'Mavak is waiting with your orders.',
 830036, 1, 0, 0,
 'Speak with Scout Mavak', '', 0),

(81211, 2, 82, 80, 6100, 0, 5, 0, 690,
 'Horde: Burn Out the Dead',
 'Eliminate Charred Ghouls and Ashen Banshees near the encampment.',
 'Scourge packs are probing the horde perimeter. Crush them before they regroup.',
 'Encampment perimeter.',
 'The perimeter is secure.',
 830040, 8, 830041, 4,
 'Charred Ghouls slain', 'Ashen Banshees slain', 0),

(81212, 2, 95, 90, 6100, 0, 6, 0, 690,
 'Horde: Flamebound Circle',
 'Report to Spiritcaller Zorok in the Scorched Groves.',
 'The battle shifts toward the scorched groves. Find Spiritcaller Zorok and continue the offensive.',
 'Scorched Groves ritual circle.',
 'Zorok prepares the next strike.',
 830037, 1, 0, 0,
 'Speak with Spiritcaller Zorok', '', 0),

(81213, 2, 112, 108, 6100, 0, 8, 0, 690,
 'Horde: Silence the Summit',
 'Destroy Summit Gargoyles and Shadow Crypt Fiends.',
 'Undead war-wings above the summit are disrupting every patrol route. Bring them down.',
 'The Summit battlefront.',
 'The summit skies and ridges are briefly clear.',
 830060, 9, 830061, 5,
 'Summit Gargoyles slain', 'Shadow Crypt Fiends slain', 0),

(81214, 2, 127, 120, 6100, 0, 9, 0, 690,
 'Horde: Cut Off the Corruptor',
 'Slay Frostbone Wyrms and the Hyjal Doomlord in Nordrassil Roots.',
 'The root-caverns are overrun. Drop the wyrm escorts and execute the doom commander.',
 'Nordrassil Roots final assault.',
 'The corruptor command has collapsed.',
 830071, 4, 830072, 1,
 'Frostbone Wyrms slain', 'Hyjal Doomlord slain', 0);

INSERT INTO `quest_template_addon`
    (`ID`, `PrevQuestID`, `NextQuestID`, `SpecialFlags`)
VALUES
(81200, 0,     81201, 0),
(81201, 81200, 81202, 0),
(81202, 81201, 81203, 0),
(81203, 81202, 81204, 0),
(81204, 81203, 0,     0),
(81205, 0,     0,     0),
(81206, 0,     0,     0),
(81207, 0,     0,     0),
(81208, 0,     0,     0),
(81209, 0,     0,     0),
(81215, 0,     81216, 0),
(81216, 81215, 81217, 0),
(81217, 81216, 81218, 0),
(81218, 81217, 81219, 0),
(81219, 81218, 81220, 0),
(81220, 81219, 81221, 0),
(81221, 81220, 81222, 0),
(81222, 81221, 81223, 0),
(81223, 81222, 0,     0),
(81210, 0,     81211, 0),
(81211, 81210, 81212, 0),
(81212, 81211, 81213, 0),
(81213, 81212, 81214, 0),
(81214, 81213, 0,     0);

INSERT INTO `quest_request_items`
    (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`)
VALUES
(81200, 6, 0, 'Commander Elowen said you were on your way.', 0),
(81201, 6, 0, 'The Foothills still burn. Keep cutting them down.', 0),
(81202, 6, 0, 'You made it through the pass. Good.', 0),
(81203, 6, 0, 'The demons are not finished yet. Stay sharp.', 0),
(81204, 6, 0, 'This is the heart of the rot. End it.', 0),
(81205, 6, 0, 'Every circle you break weakens their foothold.', 0),
(81206, 6, 0, 'Those infernals hit harder than they look. Stay ready.', 0),
(81207, 6, 0, 'Do not let the liches finish another binding.', 0),
(81208, 6, 0, 'The roots can still be saved. Keep pressing.', 0),
(81209, 6, 0, 'One last push and their local command collapses.', 0),
(81215, 6, 0, 'More reavers are moving in from the ridgeline.', 0),
(81216, 6, 0, 'Those deathcallers cannot be left unchecked.', 0),
(81217, 6, 0, 'The felmaw packs are larger than expected.', 0),
(81218, 6, 0, 'Doomflayers do not stop unless you make them.', 0),
(81219, 6, 0, 'Boneweaver channels are still active. Keep going.', 0),
(81220, 6, 0, 'More gravewings are circling in from the summit edge.', 0),
(81221, 6, 0, 'The roots shake every time a colossus passes.', 0),
(81222, 6, 0, 'The devastators are the heaviest element left.', 0),
(81223, 6, 0, 'Finish both battlegroups and close this breach.', 0),
(81210, 6, 0, 'Mavak has your assignment ready.', 0),
(81211, 6, 0, 'The dead keep coming. Do not slow down.', 0),
(81212, 6, 0, 'Zorok expected you. The rites are prepared.', 0),
(81213, 6, 0, 'The summit still echoes with undead wings.', 0),
(81214, 6, 0, 'This is the final cut. Make it count.', 0);

INSERT INTO `quest_offer_reward`
    (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`,
     `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `EmoteDelay4`,
     `RewardText`, `VerifiedBuild`)
VALUES
(81200, 0, 0, 0, 0, 0, 0, 0, 0, 'Good. The Foothills finally have reinforcement.', 0),
(81201, 0, 0, 0, 0, 0, 0, 0, 0, 'Well struck. The brush line is ours for now.', 0),
(81202, 0, 0, 0, 0, 0, 0, 0, 0, 'Welcome to the Scorched Groves, champion.', 0),
(81203, 0, 0, 0, 0, 0, 0, 0, 0, 'The felfire broke exactly where we needed.', 0),
(81204, 0, 0, 0, 0, 0, 0, 0, 0, 'Nordrassil will remember this victory.', 0),
(81205, 0, 0, 0, 0, 0, 0, 0, 0, 'Good work. The foothills ritual cells are broken.', 0),
(81206, 0, 0, 0, 0, 0, 0, 0, 0, 'Their infernal wave is blunted. We hold this line.', 0),
(81207, 0, 0, 0, 0, 0, 0, 0, 0, 'The summit winds are quieter now. Keep the advantage.', 0),
(81208, 0, 0, 0, 0, 0, 0, 0, 0, 'Nordrassil''s roots will endure a while longer.', 0),
(81209, 0, 0, 0, 0, 0, 0, 0, 0, 'Excellent. Their variant command chain is gone.', 0),
(81215, 0, 0, 0, 0, 0, 0, 0, 0, 'The reaver pressure eased across the foothills.', 0),
(81216, 0, 0, 0, 0, 0, 0, 0, 0, 'Good. Without their callers, the dead lose direction.', 0),
(81217, 0, 0, 0, 0, 0, 0, 0, 0, 'That pack line was getting out of control.', 0),
(81218, 0, 0, 0, 0, 0, 0, 0, 0, 'The doomflayer squad is gone. The grove line holds.', 0),
(81219, 0, 0, 0, 0, 0, 0, 0, 0, 'The summit trap lines have been severed.', 0),
(81220, 0, 0, 0, 0, 0, 0, 0, 0, 'Excellent flying work. Patrol routes are clear again.', 0),
(81221, 0, 0, 0, 0, 0, 0, 0, 0, 'That sweep bought the roots precious time.', 0),
(81222, 0, 0, 0, 0, 0, 0, 0, 0, 'You broke the heaviest wave cleanly.', 0),
(81223, 0, 0, 0, 0, 0, 0, 0, 0, 'The final breach has closed. Nordrassil stands.', 0),
(81210, 0, 0, 0, 0, 0, 0, 0, 0, 'You are just in time. We move now.', 0),
(81211, 0, 0, 0, 0, 0, 0, 0, 0, 'Clean work. The horde line still stands.', 0),
(81212, 0, 0, 0, 0, 0, 0, 0, 0, 'The circle is ready, and so are you.', 0),
(81213, 0, 0, 0, 0, 0, 0, 0, 0, 'The summit weakens. Push into the roots.', 0),
(81214, 0, 0, 0, 0, 0, 0, 0, 0, 'The corruptor command is shattered. Lok''tar.', 0);

INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(830030, 81200),
(830031, 81201),
(830031, 81202),
(830031, 81205),
(830032, 81206),
(830032, 81203),
(830033, 81207),
(830033, 81204),
(830034, 81208),
(830034, 81209),
(830031, 81215),
(830031, 81216),
(830032, 81217),
(830032, 81218),
(830033, 81219),
(830033, 81220),
(830034, 81221),
(830034, 81222),
(830034, 81223),
(830035, 81210),
(830036, 81211),
(830036, 81212),
(830037, 81213),
(830038, 81214),
(830036, 81205),
(830037, 81206),
(830038, 81207),
(830039, 81208),
(830039, 81209),
(830036, 81215),
(830036, 81216),
(830037, 81217),
(830037, 81218),
(830038, 81219),
(830038, 81220),
(830039, 81221),
(830039, 81222),
(830039, 81223);

INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(830031, 81200),
(830031, 81201),
(830032, 81202),
(830031, 81205),
(830032, 81206),
(830032, 81203),
(830033, 81207),
(830034, 81204),
(830034, 81208),
(830034, 81209),
(830031, 81215),
(830031, 81216),
(830032, 81217),
(830032, 81218),
(830033, 81219),
(830033, 81220),
(830034, 81221),
(830034, 81222),
(830034, 81223),
(830036, 81210),
(830036, 81211),
(830037, 81212),
(830037, 81213),
(830039, 81214),
(830036, 81205),
(830037, 81206),
(830038, 81207),
(830039, 81208),
(830039, 81209),
(830036, 81215),
(830036, 81216),
(830037, 81217),
(830037, 81218),
(830038, 81219),
(830038, 81220),
(830039, 81221),
(830039, 81222),
(830039, 81223);

-- -----------------------------------------------------------------------------
-- Equipment loadouts for quest-giver templates (defined above in this file).
-- Service NPC equip rows live in 05e_NPC_Equipment.sql; those templates are
-- created earlier. Quest-giver rows MUST come here so the templates exist.
-- -----------------------------------------------------------------------------
DELETE FROM `creature_equip_template`
WHERE `CreatureID` IN (830030,830031,830032,830033,830034,830035,830036,830037,830038,830039);

INSERT INTO `creature_equip_template`
    (`CreatureID`,`ID`,`ItemID1`,`ItemID2`,`ItemID3`,`VerifiedBuild`)
VALUES
(830030, 1,  40345, 49976,     0, 0),
(830031, 1,  40345,     0, 50178, 0),
(830032, 1,  49992,     0,     0, 0),
(830033, 1,  40345, 49976,     0, 0),
(830034, 1,  49992,     0,     0, 0),
(830035, 1,  49919,     0,     0, 0),
(830036, 1,  49982,     0,     0, 0),
(830037, 1,  50028,     0,     0, 0),
(830038, 1,  40402, 49976,     0, 0),
(830039, 1,  49992,     0,     0, 0);

-- -----------------------------------------------------------------------------
-- Restore lootid and gold on hostile creature templates.
-- These rows were re-inserted above without a lootid column (defaults to 0).
-- Duplicating the UPDATEs from 08b_Mob_Loot.sql here keeps this file
-- self-contained so re-applying it does not orphan the loot tables.
-- -----------------------------------------------------------------------------

-- Foothills (level 80-90): gold 5-17 silver
UPDATE `creature_template` SET `lootid`=830040, `mingold`=500,  `maxgold`=1400 WHERE `entry`=830040;
UPDATE `creature_template` SET `lootid`=830041, `mingold`=600,  `maxgold`=1500 WHERE `entry`=830041;
UPDATE `creature_template` SET `lootid`=830042, `mingold`=700,  `maxgold`=1700 WHERE `entry`=830042;
UPDATE `creature_template` SET `lootid`=830091, `mingold`=700,  `maxgold`=1600 WHERE `entry`=830091;
UPDATE `creature_template` SET `lootid`=830092, `mingold`=800,  `maxgold`=1800 WHERE `entry`=830092;

-- Scorched Groves (95-105): gold 15-37 silver
UPDATE `creature_template` SET `lootid`=830050, `mingold`=1500, `maxgold`=2800 WHERE `entry`=830050;
UPDATE `creature_template` SET `lootid`=830051, `mingold`=1800, `maxgold`=3200 WHERE `entry`=830051;
UPDATE `creature_template` SET `lootid`=830052, `mingold`=2000, `maxgold`=3600 WHERE `entry`=830052;
UPDATE `creature_template` SET `lootid`=830093, `mingold`=1900, `maxgold`=3400 WHERE `entry`=830093;
UPDATE `creature_template` SET `lootid`=830094, `mingold`=2100, `maxgold`=3700 WHERE `entry`=830094;

-- The Summit (110-120): gold 35-72 silver
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

-- Doomlord: 5-8 gold (world boss equivalent)
UPDATE `creature_template` SET `lootid`=830072, `mingold`=50000, `maxgold`=80000 WHERE `entry`=830072;
