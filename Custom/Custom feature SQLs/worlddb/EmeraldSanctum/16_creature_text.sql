-- =====================================================================================
-- Emerald Sanctum (map 824) -- creature_text
--
-- EVERY `Sound` IS 0, DELIBERATELY. The design notes for these dungeons claimed the source
-- packs ship "free boss voice-over already in the client" and listed sound ids (Crescent Grove
-- 882671-882722 + 30258, Timbermaw 913106-913164). THAT WAS WRONG. All 24 were checked against
-- the LIVE server SoundEntries.dbc before this file was written and every one is missing
-- (13,509 records, `present: []`) -- they are Turtle's own SoundEntries rows, and neither the
-- DBC rows nor the audio were ever downported.
--
-- Using them anyway is a mistake this server has already paid for once: BlackwingDescent needed
-- 35_creature_text_sound_silence.sql to null 12 bosses' worth of ids after the boot log filled
-- with "CreatureTextMgr: Entry N, Group G in table `creature_texts` has Sound S but sound does
-- not exist." The engine silently falls back to no sound and the text still fires, so it is
-- cosmetic -- but it is noise that buries real errors. If the VO is ever downported, these rows
-- need only an UPDATE of the Sound column.
--
-- GroupID IS the argument to Talk(): 0 aggro, 1 signature ability, 2 slay, 3 death.
--   Type 14 = yell (bosses), 12 = say (adds and rares), 16 = boss emote (the wordless ones).
--
-- WHAT FIRES WITHOUT A REBUILD: the rare elites, because their lines are triggered by SmartAI
-- (action 1 TALK) from 14_trash_smartai.sql. The BOSS lines need the pending worldserver build,
-- because Talk() has to be called from the C++ encounter scripts.
-- Re-runnable.
-- =====================================================================================

DELETE FROM `creature_text` WHERE `CreatureID` BETWEEN 4030001 AND 4030199;

INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`,
     `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES

    (4030001, 0, 0, 'The Sanctum sleeps. You will not wake it.', 14, 0, 100, 0, 0, 0, 0, 0, '4030001 aggro'),
    (4030001, 1, 0, 'Back to your waking world!', 14, 0, 100, 0, 0, 0, 0, 0, '4030001 special'),
    (4030001, 2, 0, 'Rest now. You have earned it.', 14, 0, 100, 0, 0, 0, 0, 0, '4030001 slay'),
    (4030001, 3, 0, 'The Wakener... is beyond me...', 14, 0, 100, 0, 0, 0, 0, 0, '4030001 death'),
    (4030002, 0, 0, 'Ysera has slept too long. I will wake her -- with fire, if I must.', 14, 0, 100, 0, 0, 0, 0, 0, '4030002 aggro'),
    (4030002, 1, 0, 'Rise, dreamers! RISE!', 14, 0, 100, 0, 0, 0, 0, 0, '4030002 special'),
    (4030002, 2, 0, 'One less dreamer.', 14, 0, 100, 0, 0, 0, 0, 0, '4030002 slay'),
    (4030002, 3, 0, 'Let her sleep, then... let us all...', 14, 0, 100, 0, 0, 0, 0, 0, '4030002 death'),
    (4030003, 0, 0, 'Your shadow is not yours. Give it up.', 14, 0, 100, 0, 0, 0, 0, 0, '4030003 aggro'),
    (4030003, 1, 0, 'Come, spirit. Step out of the flesh.', 14, 0, 100, 0, 0, 0, 0, 0, '4030003 special'),
    (4030003, 2, 0, 'Shadow and all.', 14, 0, 100, 0, 0, 0, 0, 0, '4030003 slay'),
    (4030003, 3, 0, 'Darkness... takes back... its own...', 14, 0, 100, 0, 0, 0, 0, 0, '4030003 death'),
    (4030004, 0, 0, 'Look upon the Nightmare, and DESPAIR.', 14, 0, 100, 0, 0, 0, 0, 0, '4030004 aggro'),
    (4030004, 1, 0, 'The earth itself is rotting. Can you not smell it?', 14, 0, 100, 0, 0, 0, 0, 0, '4030004 special'),
    (4030004, 2, 0, 'Rot, like all the rest.', 14, 0, 100, 0, 0, 0, 0, 0, '4030004 slay'),
    (4030004, 3, 0, 'The blight... outlives me...', 14, 0, 100, 0, 0, 0, 0, 0, '4030004 death'),
    (4030005, 0, 0, 'I am three. I am many. I am the Nightmare itself.', 14, 0, 100, 0, 0, 0, 0, 0, '4030005 aggro'),
    (4030005, 1, 0, 'Which of me will you strike?', 14, 0, 100, 0, 0, 0, 0, 0, '4030005 special'),
    (4030005, 2, 0, 'You struck the wrong one.', 14, 0, 100, 0, 0, 0, 0, 0, '4030005 slay'),
    (4030005, 3, 0, 'We... scatter...', 14, 0, 100, 0, 0, 0, 0, 0, '4030005 death'),
    (4030151, 0, 0, 'I will not wake. Neither will you.', 12, 0, 100, 0, 0, 0, 0, 0, '4030151 aggro'),
    (4030152, 0, 0, 'The Dream rots from the root. I am the root.', 12, 0, 100, 0, 0, 0, 0, 0, '4030152 aggro');

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'creature_text rows (want 22)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_text` WHERE `CreatureID` BETWEEN 4030001 AND 4030199
UNION ALL SELECT 'creatures with lines (want 7)', CAST(COUNT(DISTINCT `CreatureID`) AS CHAR)
    FROM `creature_text` WHERE `CreatureID` BETWEEN 4030001 AND 4030199
UNION ALL SELECT 'rows referencing a sound (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_text` WHERE `CreatureID` BETWEEN 4030001 AND 4030199 AND `Sound` <> 0
UNION ALL SELECT 'text on a creature that does not exist (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_text` t LEFT JOIN `creature_template` c ON c.`entry` = t.`CreatureID`
    WHERE t.`CreatureID` BETWEEN 4030001 AND 4030199 AND c.`entry` IS NULL
UNION ALL SELECT 'SmartAI TALK with no matching text (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` s
    LEFT JOIN `creature_text` t
      ON t.`CreatureID` = s.`entryorguid` AND t.`GroupID` = s.`action_param1`
    WHERE s.`source_type` = 0 AND s.`action_type` = 1
      AND s.`entryorguid` BETWEEN 4030001 AND 4030199 AND t.`CreatureID` IS NULL;
