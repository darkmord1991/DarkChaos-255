-- Darkshore (map 750) quest 13918 The Titans' Terminal could not be done (BFA-HavenCore #737, 2026-11-25).
--
-- The quest: use the Buried Artifact Detector (46388, spell 65300 Ping for Artifact) on the beach, dig up 5 Ancient
-- Device Fragments (46702) and combine them into the Ancient Slotted Device (46387). Three pieces were missing:
--  1. 65300 picks units by entry around the caster, but no condition named the entry, and the 90 Buried Treasure
--     Bunnies (3734356) had no script: the ping hit nothing.
--  2. The dig spot, Buried Debris (Cata GO 195055), was never imported: here 3695055 (+3.6M GO band of map 750), a
--     chest of quest 13918 that gives one fragment, data and loot from the Cata world (nelt_world).
--  3. The fragment had no use spell: 65435 Rebuild Artifact (5 fragments -> 46387) is downported below and added
--     to Custom/DBCs/Spell.dbc + Custom/CSV DBC/Spell.csv; the client needs that Spell.dbc to use the fragment.
-- Cata despawns the bunny after the dig spot appears. Here the bunny owns the summoned chest (SUMMON_GO always uses
-- the owned summon type in this core), so a despawn would take the chest with it: the spell-hit event has a 60 s
-- cooldown instead, and the chest stays 35 s as in Cata. HavenCore's spell-focus objects 195085 are not needed: our
-- 65300 has no spell-focus requirement.

-- 1. The ping finds the bunnies; a hit raises a dig spot
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 13 AND `SourceEntry` = 65300;
INSERT INTO `conditions` (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES
(13, 1, 65300, 0, 0, 31, 0, 3, 3734356, 0, 0, 0, 0, '', 'Ping for Artifact - target Buried Treasure Bunny');

UPDATE `creature_template` SET `AIName` = 'SmartAI' WHERE `entry` = 3734356;
DELETE FROM `smart_scripts` WHERE `entryorguid` = 3734356 AND `source_type` = 0;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(3734356, 0, 0, 0, 8, 0, 100, 0, 65300, 0, 60000, 60000, 0, 0, 50, 3695055, 35, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Buried Treasure Bunny - On Spellhit Ping for Artifact (60 s cooldown) - Summon Buried Debris for 35 s');

-- 2. Buried Debris: chest of quest 13918, lock 43, one Ancient Device Fragment
REPLACE INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`) VALUES
(3695055, 3, 49, 'Buried Debris', '', 'Collecting', '', 1, 43, 3695055, 0, 1, 0, 0, 0, 0, 13918, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 0);

DELETE FROM `gameobject_loot_template` WHERE `Entry` = 3695055;
INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(3695055, 46702, 0, 100, 1, 1, 0, 1, 1, 'Buried Debris - Ancient Device Fragment (quest 13918)');

-- 3. Rebuild Artifact 65435 (server copy; tools/gen_darkshore_havencore_r58.py) and the fragment's use spell
DELETE FROM `spell_dbc` WHERE `ID` = 65435;
INSERT INTO `spell_dbc` VALUES ('65435','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','5','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','1','0','0','0','0','0','46702','0','0','0','0','0','0','0','5','0','0','0','0','0','0','0','-1','0','0','24','0','0','0','0','0','0','0','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','46387','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','1168','0','1','0','0','Rebuild Artifact','','','','','','','','','','','','','','','','16712190','','','','','','','','','','','','','','','','','0','Combine 5 Artifact fragments into an Ancient Slotted Artifact.','','','','','','','','','','','','','','','','16712190','','','','','','','','','','','','','','','','','0','0','0','0','0','0','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0');

UPDATE `item_template` SET `spellid_1` = 65435, `spellcharges_1` = -1, `bonding` = 4 WHERE `entry` = 46702;
