-- ---------------------------------------------------------------------------
-- creature_template.KillCredit1 offset fix  (DC Plaguelands, map 751)
-- ---------------------------------------------------------------------------
-- Noxious Assassin (3645692) still had the raw pre-offset Cata KillCredit1
-- value (45691) instead of the local +3,600,000 clone (Skullmage, 3645691)
-- -- see HyjalCata/70_killcredit_offset_fix.sql for the sibling bug on map
-- 750, same root cause (offset-cloning pipeline missed this field).
-- ---------------------------------------------------------------------------
UPDATE `creature_template` SET `KillCredit1` = `KillCredit1` + 3600000 WHERE `entry` = 3645692 AND `KillCredit1` = 45691;
