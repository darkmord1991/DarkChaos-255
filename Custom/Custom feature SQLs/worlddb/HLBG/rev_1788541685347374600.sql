-- Hinterland BG: add a Kor'kron orc contingent to the Horde side.
--
-- WHY
-- The Alliance fields two visually distinct peoples - humans (810001 and King
-- Varian) and Wildhammer dwarves (810009-810011, 810013, 810015, 810017,
-- 810021-810023). The Horde fields Revantusk trolls and nothing else; Thrall is
-- the only orc on the map, and he is the boss. This adds orcs as the Horde's
-- second type so both sides read as a coalition rather than one tribe.
--
-- It also narrows a real imbalance. Per map the Alliance spawns 35 guards to
-- the Horde's 19, and because killing an enemy NPC drains the *owner's*
-- resources, the Horde had to chew through more than twice the health pool to
-- apply the same pressure. Twelve Kor'kron per map takes the Horde to 31.
--
-- Stats follow the role bands set in the companion rescale file (exp 2,
-- ArmorModifier 2, basehp2 12,600):
--   Overseer     elite     x10 = 126,000
--   Shieldguard  elite     x10 = 126,000
--   Grunt        standard  x5  =  63,000
--   Axethrower   standard  x5  =  63,000
--
-- Display ids are the stock four-variant orc sets, matching how every existing
-- battleground NPC here carries four models for visual variety:
--   Orgrimmar Grunt   4259, 4260, 4601, 4602
--   Kor'kron Defender 20113, 20114, 20115, 20116
--   Warsong Grunt     11861, 11862, 11863, 11864
--   Kor'kron Elite    14360, 14361, 14362, 14363
--
-- faction 1495 matches the Revantusk, which is the faction the battleground's
-- NPC classification already treats as Horde. AIName is left empty (plain melee
-- AI) to match 810000, the closest existing analogue - deliberately NOT the
-- Stormwind emote SmartAI that 810001 still carries.
--
-- NOTE: these entries must also be registered in the C++ Horde NPC lists
-- (hlbg_constants.h) and in HinterlandBG.ResourcesLoss.NPCNormalEntriesHorde /
-- HinterlandBG.Reward.NPCEntriesHorde, or killing them drains nothing.

DELETE FROM `creature_template` WHERE `entry` IN (810024, 810025, 810026, 810027);
INSERT INTO `creature_template`
    (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`,
     `unit_class`, `unit_flags`, `type`, `rank`, `HealthModifier`, `ManaModifier`,
     `ArmorModifier`, `DamageModifier`, `BaseAttackTime`, `RegenHealth`,
     `MovementType`, `AIName`, `ScriptName`, `flags_extra`, `VerifiedBuild`) VALUES
(810024, 'Kor''kron Grunt',       'Horde', 80, 80, 2, 1495, 0, 1, 32768, 7, 0,  5, 1, 2, 4, 2000, 1, 0, '', '', 0, 0),
(810025, 'Kor''kron Shieldguard', 'Horde', 80, 80, 2, 1495, 0, 1, 32768, 7, 0, 10, 1, 2, 5, 2000, 1, 0, '', '', 0, 0),
(810026, 'Kor''kron Axethrower',  'Horde', 80, 80, 2, 1495, 0, 1, 32768, 7, 0,  5, 1, 2, 4, 2000, 1, 0, '', '', 0, 0),
(810027, 'Kor''kron Overseer',    'Horde', 80, 80, 2, 1495, 0, 1, 32768, 7, 0, 10, 1, 2, 5, 2000, 1, 0, '', '', 0, 0);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (810024, 810025, 810026, 810027);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(810024, 0,  4259, 1, 1, 0),
(810024, 1,  4260, 1, 1, 0),
(810024, 2,  4601, 1, 1, 0),
(810024, 3,  4602, 1, 1, 0),
(810025, 0, 20113, 1, 1, 0),
(810025, 1, 20114, 1, 1, 0),
(810025, 2, 20115, 1, 1, 0),
(810025, 3, 20116, 1, 1, 0),
(810026, 0, 11861, 1, 1, 0),
(810026, 1, 11862, 1, 1, 0),
(810026, 2, 11863, 1, 1, 0),
(810026, 3, 11864, 1, 1, 0),
(810027, 0, 14360, 1, 1, 0),
(810027, 1, 14361, 1, 1, 0),
(810027, 2, 14362, 1, 1, 0),
(810027, 3, 14363, 1, 1, 0);

-- Weapons, from the same Monster-item palette as the rest of the roster.
DELETE FROM `creature_equip_template` WHERE `CreatureID` IN (810024, 810025, 810026, 810027) AND `ID` = 1;
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(810024, 1, 10611, 13318,    0, 0),  -- Grunt: Horde axe + Horde shield
(810025, 1, 10612, 13318,    0, 0),  -- Shieldguard: Horde axe + Horde shield
(810026, 1, 10611,     0, 5262, 0),  -- Axethrower: axe + bow
(810027, 1, 12786, 13318,    0, 0);  -- Overseer: Horde skull club + shield

-- Spawns. Explicit GUIDs: creature.guid is capped at 0xFFFFFF (16,777,215) and
-- the table is already at 16,751,213, so auto-increment headroom is thin and
-- must not be spent accidentally. 9002200-9002223 is a verified-free block.
--
-- Positions are small offsets from existing, known-good Horde spawns so the Z
-- values are inherited from surveyed ground rather than guessed.
DELETE FROM `creature` WHERE `guid` BETWEEN 9002200 AND 9002223;
INSERT INTO `creature`
    (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
     `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`,
     `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`,
     `npcflag`, `unit_flags`, `dynamicflags`, `VerifiedBuild`) VALUES
-- map 1411 -------------------------------------------------------------------
(9002200, 810027, 1411, 47, 6738, 1, 4294967295, 1, -620.00, -4577.00, 11.69, 5.548, 300, 0, 0, 126000, 0, 0, 0, 0, 0, 0),
(9002201, 810024, 1411, 47, 6738, 1, 4294967295, 1, -627.50, -4578.00, 11.69, 5.548, 300, 0, 0, 63000, 0, 0, 0, 0, 0, 0),
(9002202, 810024, 1411, 47, 6738, 1, 4294967295, 1, -620.50, -4585.50, 11.69, 5.548, 300, 0, 0, 63000, 0, 0, 0, 0, 0, 0),
(9002203, 810025, 1411, 47, 6738, 1, 4294967295, 1, -571.50, -4589.00, 10.59, 4.263, 300, 0, 0, 126000, 0, 0, 0, 0, 0, 0),
(9002204, 810025, 1411, 47, 6738, 1, 4294967295, 1, -564.00, -4601.00, 10.62, 2.615, 300, 0, 0, 126000, 0, 0, 0, 0, 0, 0),
(9002205, 810024, 1411, 47, 6738, 1, 4294967295, 1, -557.50, -4538.50, 11.50, 5.585, 300, 0, 0, 63000, 0, 0, 0, 0, 0, 0),
(9002206, 810024, 1411, 47, 6738, 1, 4294967295, 1, -535.50, -4556.00, 11.58, 0.804, 300, 0, 0, 63000, 0, 0, 0, 0, 0, 0),
(9002207, 810026, 1411, 47, 6738, 1, 4294967295, 1, -547.00, -4531.50, 11.56, 5.577, 300, 0, 0, 63000, 0, 0, 0, 0, 0, 0),
(9002208, 810026, 1411, 47, 6738, 1, 4294967295, 1, -511.00, -4554.50, 11.54, 0.057, 300, 0, 0, 63000, 0, 0, 0, 0, 0, 0),
(9002209, 810026, 1411, 47, 6738, 1, 4294967295, 1, -517.00, -4521.50, 11.28, 0.124, 300, 0, 0, 63000, 0, 0, 0, 0, 0, 0),
(9002210, 810024, 1411, 47, 6738, 1, 4294967295, 1, -323.00, -4506.00, 11.78, 0.728, 300, 0, 0, 63000, 0, 0, 0, 0, 0, 0),
(9002211, 810024, 1411, 47, 6738, 1, 4294967295, 1, -379.50, -4427.50, 12.67, 0.073, 300, 0, 0, 63000, 0, 0, 0, 0, 0, 0),
-- map 1412 -------------------------------------------------------------------
(9002212, 810027, 1412, 47, 6738, 1, 4294967295, 1, -620.00, -4577.00, 11.69, 5.548, 300, 0, 0, 126000, 0, 0, 0, 0, 0, 0),
(9002213, 810024, 1412, 47, 6738, 1, 4294967295, 1, -627.50, -4578.00, 11.69, 5.548, 300, 0, 0, 63000, 0, 0, 0, 0, 0, 0),
(9002214, 810024, 1412, 47, 6738, 1, 4294967295, 1, -620.50, -4585.50, 11.69, 5.548, 300, 0, 0, 63000, 0, 0, 0, 0, 0, 0),
(9002215, 810025, 1412, 47, 6738, 1, 4294967295, 1, -571.50, -4589.00, 10.59, 4.263, 300, 0, 0, 126000, 0, 0, 0, 0, 0, 0),
(9002216, 810025, 1412, 47, 6738, 1, 4294967295, 1, -564.00, -4601.00, 10.62, 2.615, 300, 0, 0, 126000, 0, 0, 0, 0, 0, 0),
(9002217, 810024, 1412, 47, 6738, 1, 4294967295, 1, -557.50, -4538.50, 11.50, 5.585, 300, 0, 0, 63000, 0, 0, 0, 0, 0, 0),
(9002218, 810024, 1412, 47, 6738, 1, 4294967295, 1, -535.50, -4556.00, 11.58, 0.804, 300, 0, 0, 63000, 0, 0, 0, 0, 0, 0),
(9002219, 810026, 1412, 47, 6738, 1, 4294967295, 1, -547.00, -4531.50, 11.56, 5.577, 300, 0, 0, 63000, 0, 0, 0, 0, 0, 0),
(9002220, 810026, 1412, 47, 6738, 1, 4294967295, 1, -511.00, -4554.50, 11.54, 0.057, 300, 0, 0, 63000, 0, 0, 0, 0, 0, 0),
(9002221, 810026, 1412, 47, 6738, 1, 4294967295, 1, -517.00, -4521.50, 11.28, 0.124, 300, 0, 0, 63000, 0, 0, 0, 0, 0, 0),
(9002222, 810024, 1412, 47, 6738, 1, 4294967295, 1, -323.00, -4506.00, 11.78, 0.728, 300, 0, 0, 63000, 0, 0, 0, 0, 0, 0),
(9002223, 810024, 1412, 47, 6738, 1, 4294967295, 1, -379.50, -4427.50, 12.67, 0.073, 300, 0, 0, 63000, 0, 0, 0, 0, 0, 0);
