-- =====================================================================================
-- Timbermaw Hold -- bind the encounter scripts to their creature templates
--
-- `ScriptName` and `AIName` are MUTUALLY EXCLUSIVE: if both are set the ScriptName wins and
-- the SmartAI rows become dead weight nobody notices. 05_templates.sql deliberately left
-- AIName empty on every boss for exactly this moment, but the UPDATE below clears it again so
-- the file is safe to run after any hand edit.
--
-- Requires a worldserver rebuild -- these names only resolve once the C++ is compiled in.
-- Until then the creatures load with no AI and simply melee.
-- =====================================================================================


UPDATE `creature_template` SET `ScriptName` = 'boss_gatewarden_morthak', `AIName` = '' WHERE `entry` = 4010001;
UPDATE `creature_template` SET `ScriptName` = 'boss_sundered_chieftain', `AIName` = '' WHERE `entry` = 4010002;
UPDATE `creature_template` SET `ScriptName` = 'boss_den_mother_ursara', `AIName` = '' WHERE `entry` = 4010003;
UPDATE `creature_template` SET `ScriptName` = 'boss_xanthir_the_defiler', `AIName` = '' WHERE `entry` = 4010004;
UPDATE `creature_template` SET `ScriptName` = 'boss_nightmare_given_root', `AIName` = '' WHERE `entry` = 4010005;
UPDATE `creature_template` SET `ScriptName` = 'boss_ursol', `AIName` = '' WHERE `entry` = 4010006;
UPDATE `creature_template` SET `ScriptName` = 'boss_ursoc', `AIName` = '' WHERE `entry` = 4010007;

SELECT 'scripted creatures (want 7)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template` WHERE `entry` IN (4010001, 4010002, 4010003, 4010004, 4010005, 4010006, 4010007) AND `ScriptName` <> ''
UNION ALL SELECT 'rows with BOTH AIName and ScriptName (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` IN (4010001, 4010002, 4010003, 4010004, 4010005, 4010006, 4010007) AND `ScriptName` <> '' AND `AIName` <> '';
