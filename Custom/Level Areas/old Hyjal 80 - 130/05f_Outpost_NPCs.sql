-- Hyjal Frontier - outpost flight masters and faction soldiers
--
-- Three neutral outpost flight masters for the progression hubs (Foothills,
-- Scorched Groves, Nordrassil). No spawn rows are included -- coordinates
-- are set during the Noggit placement pass. All three share the
-- npc_hyjal_flightmaster script used by the base-camp FMs (830020/830145)
-- and carry the same ceremonial sword+shield loadout.
--
-- Two faction soldiers (one Alliance, one Horde) with 3 display ID variants
-- each. Intended as ambient perimeter infantry placed around the base camps
-- and outposts via manual Noggit pass. Soldiers use a lighter health pool
-- than the heavy guards (830021/830022) and carry a single 1H weapon without
-- a shield so they look more mobile on patrol.
--
-- Entry block: 830158-830162 (inside the free 830158-830999 reserve).
-- Equipment stored inline (creature_equip_template ID=1 per entry).
-- Faction: 12 (Stormwind) Alliance strict, 29 (Orgrimmar) Horde strict,
--          35 (neutral) for shared outpost flight masters.

DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 830158 AND 830162;
DELETE FROM `creature_template`       WHERE `entry`      BETWEEN 830158 AND 830162;

INSERT INTO `creature_template`
    (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`,
     `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`,
     `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `unit_class`,
     `unit_flags`, `dynamicflags`, `family`, `type`, `type_flags`,
     `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`,
     `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
VALUES
-- ===== Outpost flight masters (faction 35 neutral, no faction lock) =====
(830158, 'Foothills Pathfinder',       'Flight Master', 130, 130, 1,
    35, 8193, 1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 8,
    15, 1, 1, 1, 1, 2, 'npc_hyjal_flightmaster', 0),
(830159, 'Scorched Groves Pathfinder', 'Flight Master', 130, 130, 1,
    35, 8193, 1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 8,
    15, 1, 1, 1, 1, 2, 'npc_hyjal_flightmaster', 0),
(830160, 'Nordrassil Guide',           'Flight Master', 130, 130, 1,
    35, 8193, 1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 8,
    15, 1, 1, 1, 1, 2, 'npc_hyjal_flightmaster', 0),
-- ===== Faction soldiers (3 display variants each, no script) =====
(830161, 'Hyjal Frontier Soldier',     'Jaina''s Encampment', 130, 130, 1,
    12, 0, 1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 8,
    15, 1, 2, 1, 1, 2, '', 0),
(830162, 'Hyjal Vanguard Warrior',     'Thrall''s Vanguard',  130, 130, 1,
    29, 0, 1, 1.14286, 1, 1, 1400, 2000, 1,  8256, 0, 0, 7, 8,
    15, 1, 2, 1, 1, 2, '', 0);

DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 830158 AND 830162;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
VALUES
-- Outpost flight masters (single display each, Night Elf-themed for Hyjal)
(830158, 0, 11479, 1, 1, 0),   -- Night Elf male (Baritanas Skyriver model, valid in DBC)
(830159, 0, 11573, 1, 1, 0),   -- Night Elf female
(830160, 0,  7765, 1, 1, 0),   -- Night Elf male sentinel variant
-- Alliance soldier (3 variants: human / night elf / dwarf)
(830161, 0,  2705, 1, 1, 0),   -- Human male warrior (heavy plate)
(830161, 1,  3661, 1, 1, 0),   -- Night Elf female sentinel
(830161, 2,  3233, 1, 1, 0),   -- Dwarf mountaineer
-- Horde soldier (3 variants: troll / tauren / orc)
(830162, 0,  4290, 1, 1, 0),   -- Troll berserker (Darkspear)
(830162, 1,  3735, 1, 1, 0),   -- Tauren warrior
(830162, 2, 17335, 1, 1, 0);   -- Orc soldier (WotLK heavy variant)

-- Equipment: flight masters carry ceremonial sword+shield (matching 830020/830145);
-- soldiers carry a single 1H weapon without a shield to look lighter than guards.
DELETE FROM `creature_equip_template`
WHERE `CreatureID` IN (830158, 830159, 830160, 830161, 830162);

INSERT INTO `creature_equip_template`
    (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`)
VALUES
(830158, 1, 40345, 49976, 0, 0),  -- Foothills Pathfinder:       sword + shield
(830159, 1, 40345, 49976, 0, 0),  -- Scorched Groves Pathfinder: sword + shield
(830160, 1, 40345, 49976, 0, 0),  -- Nordrassil Guide:           sword + shield
(830161, 1, 40345,     0, 0, 0),  -- Alliance Soldier:           sword (no shield)
(830162, 1, 40402,     0, 0, 0);  -- Horde Soldier:              axe  (no shield)
