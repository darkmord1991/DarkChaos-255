-- =====================================================================================
-- Crescent Grove -- bind the encounter scripts to their creature templates
--
-- `ScriptName` and `AIName` are MUTUALLY EXCLUSIVE: if both are set the ScriptName wins and
-- the SmartAI rows become dead weight nobody notices. 05_templates.sql deliberately left
-- AIName empty on every boss for exactly this moment, but the UPDATE below clears it again so
-- the file is safe to run after any hand edit.
--
-- Requires a worldserver rebuild -- these names only resolve once the C++ is compiled in.
-- Until then the creatures load with no AI and simply melee.
-- =====================================================================================


UPDATE `creature_template` SET `ScriptName` = 'boss_keeper_ranathos', `AIName` = '' WHERE `entry` = 4020001;
UPDATE `creature_template` SET `ScriptName` = 'boss_grovetender_engryss', `AIName` = '' WHERE `entry` = 4020002;
UPDATE `creature_template` SET `ScriptName` = 'npc_crescent_grove_elder', `AIName` = '' WHERE `entry` = 4020003;
UPDATE `creature_template` SET `ScriptName` = 'npc_crescent_grove_elder', `AIName` = '' WHERE `entry` = 4020004;
UPDATE `creature_template` SET `ScriptName` = 'boss_high_priestess_alathea', `AIName` = '' WHERE `entry` = 4020005;
UPDATE `creature_template` SET `ScriptName` = 'boss_fenektis_the_deceiver', `AIName` = '' WHERE `entry` = 4020006;
UPDATE `creature_template` SET `ScriptName` = 'boss_master_raxxieth', `AIName` = '' WHERE `entry` = 4020007;

SELECT 'scripted creatures (want 7)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template` WHERE `entry` IN (4020001, 4020002, 4020003, 4020004, 4020005, 4020006, 4020007) AND `ScriptName` <> ''
UNION ALL SELECT 'rows with BOTH AIName and ScriptName (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` IN (4020001, 4020002, 4020003, 4020004, 4020005, 4020006, 4020007) AND `ScriptName` <> '' AND `AIName` <> '';
