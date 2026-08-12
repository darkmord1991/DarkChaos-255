-- =====================================================================================
-- Emerald Sanctum -- bind the encounter scripts to their creature templates
--
-- `ScriptName` and `AIName` are MUTUALLY EXCLUSIVE: if both are set the ScriptName wins and
-- the SmartAI rows become dead weight nobody notices. 05_templates.sql deliberately left
-- AIName empty on every boss for exactly this moment, but the UPDATE below clears it again so
-- the file is safe to run after any hand edit.
--
-- Requires a worldserver rebuild -- these names only resolve once the C++ is compiled in.
-- Until then the creatures load with no AI and simply melee.
-- =====================================================================================


UPDATE `creature_template` SET `ScriptName` = 'boss_erennius', `AIName` = '' WHERE `entry` = 4030001;
UPDATE `creature_template` SET `ScriptName` = 'boss_wakener_ysondre', `AIName` = '' WHERE `entry` = 4030002;
UPDATE `creature_template` SET `ScriptName` = 'boss_wakener_lethon', `AIName` = '' WHERE `entry` = 4030003;
UPDATE `creature_template` SET `ScriptName` = 'boss_wakener_emeriss', `AIName` = '' WHERE `entry` = 4030004;
UPDATE `creature_template` SET `ScriptName` = 'boss_wakener_taerar', `AIName` = '' WHERE `entry` = 4030005;

SELECT 'scripted creatures (want 5)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template` WHERE `entry` IN (4030001, 4030002, 4030003, 4030004, 4030005) AND `ScriptName` <> ''
UNION ALL SELECT 'rows with BOTH AIName and ScriptName (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` IN (4030001, 4030002, 4030003, 4030004, 4030005) AND `ScriptName` <> '' AND `AIName` <> '';
