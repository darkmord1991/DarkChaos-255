-- ---------------------------------------------------------------------------
-- page_text -- 3 Legion Dalaran (map 1413) readable-item entries
-- ---------------------------------------------------------------------------
-- "GameObject (Entry: N GoType: 10) have data7=M but PageText (Entry M) not
-- exist" for Research Records Levy (4100661, page 6882), Charred staff
-- (4100662, page 6896), and "Shadow Word: Pain IV" (4100667, page 6990).
--
-- page_text.ID is NOT a Blizzard client-derived id (no client DBC/DB2 backs
-- this table) -- it's assigned per-project by whoever authored the content,
-- so the Legion Dalaran downport's own ids (6882/6896/6990) don't exist in
-- any other project's page_text table under the same numbers. Checked:
--  1) LegionCore_world_2020_04_25.sql (243MB community dump) -- HAS these
--     exact 3 ids with real flavor text, but only in Russian (no
--     page_text_locale/English variant present in that dump at all).
--  2) Modern retail client (I:/World of Warcraft, build 12.0.7) -- PageText
--     isn't in the available community listfile at all, dead end.
--  3) TrinityCore master TDB (K:/Dark-Chaos/tc master, 597MB, build
--     1200.26021) -- searched by item NAME ("Research Records Levy" /
--     "Charred staff" / "Shadow Word: Pain IV"), zero matches -- TC's
--     master branch doesn't have this specific Legion Dalaran flavor text
--     implemented at all.
-- No English-original source exists in anything available. Per user
-- request, translated the real Russian content from the LegionCore dump
-- into English by hand below -- this is a TRANSLATION, not official
-- Blizzard-localized text; flagging clearly for future audit. Pure flavor
-- text (reading a book/item), zero gameplay impact either way.
-- ---------------------------------------------------------------------------
DELETE FROM `page_text` WHERE `ID` IN (6882,6896,6990);

INSERT INTO `page_text` (`ID`,`Text`,`NextPageID`,`VerifiedBuild`) VALUES
(6882,'<Levia\'s notes describe in detail which items and magical formulas are required to establish contact with a powerful demon. The last page appears to contain Levia\'s own reflections, written down before performing the ritual.>\n\nAfter all the research the Kirin Tor has conducted regarding succubi and other sayaad, the mages concluded that these demons cannot be trusted. But after meeting Agatha, I began to wonder -- what if they\'re wrong?\n\nShe has already granted me power I, as a Kirin Tor mage, could only have dreamed of, and she cares for me more than the entire Council combined.\n\nThere is only one way to find out the truth. I must go to her.',0,0),
(6896,'<The staff appears to have been used in some kind of demonic ritual. It is charred and cracked in places. Something must have gone wrong during the ritual.>',0,0),
(6990,'<The book is open to a page depicting one of the runes drawn on the ground.>\n\nThe rune "Ziur" can amplify dark rituals. It is a very powerful rune. When used properly, it can summon dark entities of tremendous power.\n\nFor unknown reasons, this rune is incompatible with arcane energy and should not be used in rituals that involve both types of magic.',0,0);
