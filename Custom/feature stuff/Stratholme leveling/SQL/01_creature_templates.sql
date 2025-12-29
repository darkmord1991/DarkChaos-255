-- Stratholme Leveling Zone 130-160 - Creature Templates
-- Entry Range: 410000 - 419999

-- DELETE existing entries to allow reloading
DELETE FROM `creature_template` WHERE `entry` BETWEEN 410000 AND 410999;
DELETE FROM `creature_template_addon` WHERE `entry` BETWEEN 410000 AND 410999;
DELETE FROM `creature_model_info` WHERE `DisplayID` BETWEEN 90000 AND 90100; -- Custom models if needed (not used here yet)

-- =========================================================================
-- TIER 1: The Outskirts (Level 130-137)
-- =========================================================================

-- 410100: Shambling Regret (Undead)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `class_mask`, `race_mask`, `minigame_types`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(410100, 10478, 'Shambling Regret', 'The Outskirts', 130, 132, 2, 7, 0, 1, 1.14286, 1, 0, 0, 2000, 2000, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '');

-- 410101: Plagued Merchant (Undead)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `class_mask`, `race_mask`, `minigame_types`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(410101, 1530, 'Plagued Merchant', 'The Outskirts', 130, 133, 2, 7, 0, 1, 1.14286, 1, 0, 0, 2000, 2000, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '');

-- 410102: Rusted Defender (Undead - Warrior)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `class_mask`, `race_mask`, `minigame_types`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(410102, 10434, 'Rusted Defender', 'The Outskirts', 131, 134, 2, 7, 0, 1, 1.14286, 1, 0, 0, 2000, 2000, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, '');

-- 410103: Gutter Hound (Beast)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `class_mask`, `race_mask`, `minigame_types`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(410103, 1553, 'Gutter Hound', '', 130, 132, 2, 7, 0, 1, 1.14286, 0.9, 0, 0, 1500, 2000, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '');

-- 410104: Oozing Spreader (Undead - Ghoul)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `class_mask`, `race_mask`, `minigame_types`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(410104, 10487, 'Oozing Spreader', 'The Outskirts', 132, 135, 2, 7, 0, 1, 1.14286, 1.1, 0, 3, 2000, 2000, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '');

-- 410105: Blind Watchman (Undead)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `class_mask`, `race_mask`, `minigame_types`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(410105, 10481, 'Blind Watchman', 'The Outskirts', 132, 135, 2, 7, 0, 1, 1.14286, 1, 0, 0, 2000, 2000, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '');

-- 410106: Volatile Citizen (Undead - Explodes)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `class_mask`, `race_mask`, `minigame_types`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(410106, 10479, 'Volatile Citizen', 'The Outskirts', 131, 134, 2, 7, 0, 1, 1.14286, 1, 0, 2, 2000, 2000, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '');

-- 410107: Cultist Initiate (Humanoid - Caster) (Equip: Staff)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `class_mask`, `race_mask`, `minigame_types`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(410107, 10414, 'Cultist Initiate', 'Cult of the Damned', 133, 136, 2, 7, 0, 1, 1.14286, 1, 0, 0, 2000, 2000, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '');
-- Equipment: 410107 (Defined in equip sql)

-- =========================================================================
-- TIER 2: Scarlet Bastion (Level 138-145)
-- =========================================================================

-- 410120: Ash-Bound Spirit (Undead)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `class_mask`, `race_mask`, `minigame_types`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(410120, 27151, 'Ash-Bound Spirit', 'Scarlet Bastion', 138, 141, 3, 7, 0, 1, 1.14286, 1, 0, 2, 2000, 2000, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '');

-- 410121: Inquisitor Ghost (Undead - Priest)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `class_mask`, `race_mask`, `minigame_types`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(410121, 7966, 'Inquisitor Ghost', 'Scarlet Bastion', 139, 142, 3, 7, 0, 1, 1.14286, 1, 0, 2, 2000, 2000, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '');

-- 410123: Fallen Crusader (Undead) (Equip: Scarlet Sword/Shield)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `class_mask`, `race_mask`, `minigame_types`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(410123, 10372, 'Fallen Crusader', 'Scarlet Bastion', 140, 143, 3, 7, 0, 1, 1.14286, 1.05, 0, 0, 2000, 2000, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, '');
-- Equipment: 410123

-- 410124: Weeping Banshee (Undead)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `class_mask`, `race_mask`, `minigame_types`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(410124, 10464, 'Weeping Banshee', 'Scarlet Bastion', 141, 144, 3, 7, 0, 1, 1.14286, 1, 0, 5, 2000, 2000, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '');

-- =========================================================================
-- TIER 3: Scourge Heart (Level 146-160)
-- =========================================================================

-- 410140: Headless Lord (Undead - Elite)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `class_mask`, `race_mask`, `minigame_types`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(410140, 10433, 'Headless Lord', 'Scourge Heart', 146, 149, 3, 7, 0, 1, 1.14286, 1.2, 1, 0, 1800, 2000, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, '');

-- 410144: Elite Black Guard (Undead)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `class_mask`, `race_mask`, `minigame_types`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(410144, 10394, 'Elite Black Guard', 'Scourge Heart', 149, 152, 3, 7, 0, 1, 1.14286, 1.1, 1, 0, 1800, 2000, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, '');

-- 410167: Plagued Behemoth (Undead - Giant)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `class_mask`, `race_mask`, `minigame_types`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(410167, 10485, 'Plagued Behemoth', 'Scourge Heart', 158, 160, 3, 7, 0, 1, 1.14286, 2.5, 3, 0, 2500, 2000, 1, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, '');

-- =========================================================================
-- NAXXRAMAS EVENT (Level 160+)
-- =========================================================================

-- 410600: Crypt Swarmer (Spider Wing)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `class_mask`, `race_mask`, `minigame_types`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(410600, 15978, 'Crypt Swarmer', 'Spider Wing', 160, 160, 3, 7, 0, 1, 1.14286, 0.7, 0, 0, 1000, 2000, 1, 0, 0, 35, 0, 0, 0, 0, 0, 0, 0, '');

-- 410700: Patchwork Horror (Construct Wing)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `class_mask`, `race_mask`, `minigame_types`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(410700, 16019, 'Patchwork Horror', 'Construct Wing', 162, 162, 3, 7, 0, 1, 1.14286, 1.3, 2, 0, 2000, 2000, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, '');

-- 410800: Deathlord Trainee (Military Wing) (Equip: Runeblade)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `class_mask`, `race_mask`, `minigame_types`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(410800, 16531, 'Deathlord Trainee', 'Military Wing', 161, 161, 3, 7, 0, 1, 1.14286, 1, 1, 0, 1500, 2000, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, '');
-- Equipment: 410800

-- 410902: Fungal Giant (Plague Wing)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `class_mask`, `race_mask`, `minigame_types`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(410902, 16577, 'Fungal Giant', 'Plague Wing', 162, 162, 3, 7, 0, 1, 1.14286, 1.5, 2, 3, 2200, 2000, 1, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, '');

-- 410990: Kel'Thuzad's Shadow (BOSS)
INSERT INTO `creature_template` (`entry`, `modelid1`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `class_mask`, `race_mask`, `minigame_types`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(410990, 15990, 'Kel\'Thuzad\'s Shadow', 'The Descended Necropolis', 165, 165, 3, 7, 0, 1, 1.14286, 2, 3, 4, 2000, 2000, 8, 2, 0, 0, 0, 0, 0, 0, 0, 14, 0, 'npc_stratholme_kt_shadow');

