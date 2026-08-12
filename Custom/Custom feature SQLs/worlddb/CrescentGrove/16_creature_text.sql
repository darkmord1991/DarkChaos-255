-- =====================================================================================
-- Crescent Grove (map 823) -- creature_text
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

DELETE FROM `creature_text` WHERE `CreatureID` BETWEEN 4020001 AND 4020199;

INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`,
     `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES

    (4020001, 0, 0, 'The grove chose me. It will unmake you.', 14, 0, 100, 0, 0, 0, 0, 0, '4020001 aggro'),
    (4020001, 1, 0, 'Roots! Hold them fast!', 14, 0, 100, 0, 0, 0, 0, 0, '4020001 special'),
    (4020001, 2, 0, 'Compost. Nothing more.', 14, 0, 100, 0, 0, 0, 0, 0, '4020001 slay'),
    (4020001, 3, 0, 'The Scar spreads... I only... fed it...', 14, 0, 100, 0, 0, 0, 0, 0, '4020001 death'),
    (4020002, 0, 0, 'Elders! To me! The grove is ours to tend!', 14, 0, 100, 0, 0, 0, 0, 0, '4020002 aggro'),
    (4020002, 1, 0, 'Blackmaw! One Eye! Bring them down!', 14, 0, 100, 0, 0, 0, 0, 0, '4020002 special'),
    (4020002, 2, 0, 'Tended.', 14, 0, 100, 0, 0, 0, 0, 0, '4020002 slay'),
    (4020002, 3, 0, 'Elders... finish what I...', 14, 0, 100, 0, 0, 0, 0, 0, '4020002 death'),
    (4020003, 0, 0, 'One eye. Still sees you.', 12, 0, 100, 0, 0, 0, 0, 0, '4020003 aggro'),
    (4020003, 2, 0, 'Seen. Ended.', 12, 0, 100, 0, 0, 0, 0, 0, '4020003 slay'),
    (4020003, 3, 0, 'One Eye... closes...', 12, 0, 100, 0, 0, 0, 0, 0, '4020003 death'),
    (4020004, 0, 0, 'Blackmaw hungers.', 12, 0, 100, 0, 0, 0, 0, 0, '4020004 aggro'),
    (4020004, 2, 0, 'Chewed.', 12, 0, 100, 0, 0, 0, 0, 0, '4020004 slay'),
    (4020004, 3, 0, 'Blackmaw... sleeps...', 12, 0, 100, 0, 0, 0, 0, 0, '4020004 death'),
    (4020005, 0, 0, 'Elune has turned her face from this grove. I have found another light.', 14, 0, 100, 0, 0, 0, 0, 0, '4020005 aggro'),
    (4020005, 1, 0, 'Mend me, moonwell! MEND ME!', 14, 0, 100, 0, 0, 0, 0, 0, '4020005 special'),
    (4020005, 2, 0, 'The moon does not mourn you.', 14, 0, 100, 0, 0, 0, 0, 0, '4020005 slay'),
    (4020005, 3, 0, 'The water... runs black...', 14, 0, 100, 0, 0, 0, 0, 0, '4020005 death'),
    (4020006, 0, 0, 'I opened the wound. Would you like to see inside?', 14, 0, 100, 0, 0, 0, 0, 0, '4020006 aggro'),
    (4020006, 1, 0, 'Shhh. Listen to the vilethorn. It is saying your name.', 14, 0, 100, 0, 0, 0, 0, 0, '4020006 special'),
    (4020006, 2, 0, 'Deceived, to the very last.', 14, 0, 100, 0, 0, 0, 0, 0, '4020006 slay'),
    (4020006, 3, 0, 'You have only... widened it...', 14, 0, 100, 0, 0, 0, 0, 0, '4020006 death'),
    (4020007, 0, 0, 'A grove. How quaint. The Legion will make ash of it.', 14, 0, 100, 0, 0, 0, 0, 0, '4020007 aggro'),
    (4020007, 1, 0, 'BURN.', 14, 0, 100, 0, 0, 0, 0, 0, '4020007 special'),
    (4020007, 2, 0, 'Insect.', 14, 0, 100, 0, 0, 0, 0, 0, '4020007 slay'),
    (4020007, 3, 0, 'This world... was already... lost...', 14, 0, 100, 0, 0, 0, 0, 0, '4020007 death'),
    (4020151, 0, 0, 'Thornmaw wakes. Thornmaw feeds.', 12, 0, 100, 0, 0, 0, 0, 0, '4020151 aggro'),
    (4020152, 0, 0, 'Bloom with me. It only hurts at the beginning.', 12, 0, 100, 0, 0, 0, 0, 0, '4020152 aggro'),
    (4020153, 0, 0, 'Whisper back. I dare you.', 12, 0, 100, 0, 0, 0, 0, 0, '4020153 aggro');

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'creature_text rows (want 29)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_text` WHERE `CreatureID` BETWEEN 4020001 AND 4020199
UNION ALL SELECT 'creatures with lines (want 10)', CAST(COUNT(DISTINCT `CreatureID`) AS CHAR)
    FROM `creature_text` WHERE `CreatureID` BETWEEN 4020001 AND 4020199
UNION ALL SELECT 'rows referencing a sound (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_text` WHERE `CreatureID` BETWEEN 4020001 AND 4020199 AND `Sound` <> 0
UNION ALL SELECT 'text on a creature that does not exist (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_text` t LEFT JOIN `creature_template` c ON c.`entry` = t.`CreatureID`
    WHERE t.`CreatureID` BETWEEN 4020001 AND 4020199 AND c.`entry` IS NULL
UNION ALL SELECT 'SmartAI TALK with no matching text (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` s
    LEFT JOIN `creature_text` t
      ON t.`CreatureID` = s.`entryorguid` AND t.`GroupID` = s.`action_param1`
    WHERE s.`source_type` = 0 AND s.`action_type` = 1
      AND s.`entryorguid` BETWEEN 4020001 AND 4020199 AND t.`CreatureID` IS NULL;
