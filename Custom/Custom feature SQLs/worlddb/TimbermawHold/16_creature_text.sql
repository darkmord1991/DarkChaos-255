-- =====================================================================================
-- Timbermaw Hold (map 819) -- creature_text
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

DELETE FROM `creature_text` WHERE `CreatureID` BETWEEN 4010001 AND 4010199;

INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`,
     `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES

    (4010001, 0, 0, 'The Hold is sealed. None pass while I still draw breath!', 14, 0, 100, 0, 0, 0, 0, 0, '4010001 aggro'),
    (4010001, 1, 0, 'Back! Back into the dark where you belong!', 14, 0, 100, 0, 0, 0, 0, 0, '4010001 special'),
    (4010001, 2, 0, 'The Hold takes what it is owed.', 14, 0, 100, 0, 0, 0, 0, 0, '4010001 slay'),
    (4010001, 3, 0, 'The gate... stands open... forgive me...', 14, 0, 100, 0, 0, 0, 0, 0, '4010001 death'),
    (4010002, 0, 0, 'My tribe sleeps, and dreams of teeth. You will join them.', 14, 0, 100, 0, 0, 0, 0, 0, '4010002 aggro'),
    (4010002, 1, 0, 'Ursoc! Hear your chieftain roar!', 14, 0, 100, 0, 0, 0, 0, 0, '4010002 special'),
    (4010002, 2, 0, 'Sleep. It is kinder than waking.', 14, 0, 100, 0, 0, 0, 0, 0, '4010002 slay'),
    (4010002, 3, 0, 'The dream... breaks...', 14, 0, 100, 0, 0, 0, 0, 0, '4010002 death'),
    (4010003, 0, 0, 'You will not touch my cubs!', 14, 0, 100, 0, 0, 0, 0, 0, '4010003 aggro'),
    (4010003, 1, 0, 'To me, little ones! Feed!', 14, 0, 100, 0, 0, 0, 0, 0, '4010003 special'),
    (4010003, 2, 0, 'Hush now. Hush.', 14, 0, 100, 0, 0, 0, 0, 0, '4010003 slay'),
    (4010003, 3, 0, 'My cubs... run...', 14, 0, 100, 0, 0, 0, 0, 0, '4010003 death'),
    (4010004, 0, 0, 'The furbolg dream so very loudly. I merely... listen.', 14, 0, 100, 0, 0, 0, 0, 0, '4010004 aggro'),
    (4010004, 1, 0, 'Drown in it!', 14, 0, 100, 0, 0, 0, 0, 0, '4010004 special'),
    (4010004, 2, 0, 'Another mind, opened.', 14, 0, 100, 0, 0, 0, 0, 0, '4010004 slay'),
    (4010004, 3, 0, 'You cannot wake... what is already... dreaming...', 14, 0, 100, 0, 0, 0, 0, 0, '4010004 death'),
    (4010005, 0, 0, '%s unfurls, and the walls of the den begin to breathe.', 16, 0, 100, 0, 0, 0, 0, 0, '4010005 aggro'),
    (4010005, 1, 0, '%s drives its roots deep through the stone beneath you.', 16, 0, 100, 0, 0, 0, 0, 0, '4010005 special'),
    (4010005, 2, 0, '%s drags the corpse down into the soil.', 16, 0, 100, 0, 0, 0, 0, 0, '4010005 slay'),
    (4010005, 3, 0, '%s collapses into a heap of dead, black vine.', 16, 0, 100, 0, 0, 0, 0, 0, '4010005 death'),
    (4010006, 0, 0, 'I dreamed of you. I dreamed that you did not come.', 14, 0, 100, 0, 0, 0, 0, 0, '4010006 aggro'),
    (4010006, 1, 0, 'Sleep. SLEEP!', 14, 0, 100, 0, 0, 0, 0, 0, '4010006 special'),
    (4010006, 2, 0, 'You are dreaming now. It will not hurt for long.', 14, 0, 100, 0, 0, 0, 0, 0, '4010006 slay'),
    (4010006, 3, 0, 'Thank you... let me... wake...', 14, 0, 100, 0, 0, 0, 0, 0, '4010006 death'),
    (4010007, 0, 0, 'RAAAAGH! FLESH! WARM FLESH!', 14, 0, 100, 0, 0, 0, 0, 0, '4010007 aggro'),
    (4010007, 1, 0, 'TEAR! REND! DEVOUR!', 14, 0, 100, 0, 0, 0, 0, 0, '4010007 special'),
    (4010007, 2, 0, 'MORE!', 14, 0, 100, 0, 0, 0, 0, 0, '4010007 slay'),
    (4010007, 3, 0, 'Brother... I am... quiet... at last...', 14, 0, 100, 0, 0, 0, 0, 0, '4010007 death'),
    (4010151, 0, 0, 'Stone remembers. Stone does not forgive.', 12, 0, 100, 0, 0, 0, 0, 0, '4010151 aggro'),
    (4010152, 0, 0, 'Hollow... I am so hollow...', 12, 0, 100, 0, 0, 0, 0, 0, '4010152 aggro'),
    (4010153, 0, 0, '%s stirs, shedding a century of dust.', 16, 0, 100, 0, 0, 0, 0, 0, '4010153 aggro');

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'creature_text rows (want 31)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_text` WHERE `CreatureID` BETWEEN 4010001 AND 4010199
UNION ALL SELECT 'creatures with lines (want 10)', CAST(COUNT(DISTINCT `CreatureID`) AS CHAR)
    FROM `creature_text` WHERE `CreatureID` BETWEEN 4010001 AND 4010199
UNION ALL SELECT 'rows referencing a sound (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_text` WHERE `CreatureID` BETWEEN 4010001 AND 4010199 AND `Sound` <> 0
UNION ALL SELECT 'text on a creature that does not exist (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_text` t LEFT JOIN `creature_template` c ON c.`entry` = t.`CreatureID`
    WHERE t.`CreatureID` BETWEEN 4010001 AND 4010199 AND c.`entry` IS NULL
UNION ALL SELECT 'SmartAI TALK with no matching text (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` s
    LEFT JOIN `creature_text` t
      ON t.`CreatureID` = s.`entryorguid` AND t.`GroupID` = s.`action_param1`
    WHERE s.`source_type` = 0 AND s.`action_type` = 1
      AND s.`entryorguid` BETWEEN 4010001 AND 4010199 AND t.`CreatureID` IS NULL;
