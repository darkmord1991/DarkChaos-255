-- ---------------------------------------------------------------------------
-- 306  Round 47 -- the 5 "authored menu, zero options" gossip dead-ends
-- ---------------------------------------------------------------------------
-- The 2026-07-29 audit flagged five gossip menus that exist with a greeting but
-- have no `gossip_menu_option` rows: 12799, 12833, 12895, 12899, 12970. All
-- five belong to MAP 861 (Molten Front), not 750 -- Malfurion Stormrage
-- (3652135), Thisalee Crow (3652444), Keeper Taldros (3653446), Captain
-- Irontree (3653080) and Theresa Barkskin (3652825).
--
-- MEASURED AGAINST FOUR SOURCES, not two. cata_world and nelt_world were the
-- usual pair; skyfire_world (MoP 5.4.8) and bfa_world were added because gossip
-- menu ids are stable across expansions, so a later DB is a valid witness for
-- Cata-era menus. All four agree:
--
--   12799 Malfurion     -> 4 options in cata/skyfire/bfa, 2 in nelt
--   12833 Thisalee Crow -> 1 option in all four
--   12895 / 12899 / 12970 -> ZERO options in ALL FOUR SOURCES
--
-- So three of the five are NOT a defect: Taldros, Irontree and Barkskin are
-- greeting-only NPCs in Blizzard's own data and stay that way. Only two menus
-- were genuinely missing rows -- and, exactly as in the r24 gossip round, what
-- was missing is the LINK rows, never the text: `npc_text` 18144 / 18146 /
-- 18252 / 18253 / 18276 are already in our DB with the correct Molten Front
-- wording, and all four `broadcast_text` ids (52357 / 52939 / 52940 / 52999)
-- exist and match their option text verbatim, so this adds no boot warnings.
--
-- 🔴 TWO OF MALFURION'S FOUR OPTIONS ARE DELIBERATELY NOT IMPORTED.
-- cata_world gives 12799 three options with the IDENTICAL text "How are we
-- doing in the battle?" (OptionID 0 -> menu 12902, 2 -> 12904, 3 -> no action
-- at all) and there are ZERO `conditions` rows for this menu in any source.
-- Retail gates them on Molten Front phase progression; TDB never authored that
-- gating, so importing all three would show the player the same line three
-- times, one of which does nothing when clicked. Imported instead:
--   OptionID 0 -> 12902 (npc_text 18144, the "we gave up much to attain this
--                 foothold" status text -- the early-progression variant)
--   OptionID 4 -> 13002 (npc_text 18276, "what are we building here")
-- OptionID 2's target menu 12902's sibling 12904 (npc_text 18146, the LATE
-- "through your efforts, you have brought both the Shadow Wardens and the
-- Druids of the Talon together" variant) is created here but left unwired: it
-- needs a progression condition to be worth showing, and DC has no Molten Front
-- phase model yet. Wire it with one `conditions` row when it does.
--
-- Apply against acore_world, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) gossip_menu -- the menu -> npc_text links the follow-up menus need
-- ---------------------------------------------------------------------------
-- All five texts already exist in `npc_text`; only these link rows were absent.
-- 12904 is included for completeness (see the header) -- an unreferenced
-- gossip_menu row is inert, and ObjectMgr only validates that its text exists.
-- ---------------------------------------------------------------------------
DELETE FROM `gossip_menu` WHERE `MenuID` IN (12902, 12904, 12977, 12978, 13002);

INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(12902, 18144),  -- Malfurion: battle status (early progression)
(12904, 18146),  -- Malfurion: battle status (late progression) -- unwired
(12977, 18252),  -- Thisalee Crow: how to leave the Molten Front
(12978, 18253),  -- Thisalee Crow: the follow-up about the smaller vents
(13002, 18276);  -- Malfurion: what we are building here

-- ---------------------------------------------------------------------------
-- B) gossip_menu_option -- 4 rows
-- ---------------------------------------------------------------------------
-- Source OptionIDs are kept rather than renumbered (0 and 4 on 12799, gap
-- included) so the rows stay traceable to cata_world. AC indexes options by
-- MenuID+OptionID and sends the client a sequential list, so the gap is
-- harmless -- stock data has plenty of them.
-- ---------------------------------------------------------------------------
DELETE FROM `gossip_menu_option` WHERE `MenuID` IN (12799, 12833, 12977);

INSERT INTO `gossip_menu_option`
    (`MenuID`,`OptionID`,`OptionIcon`,`OptionText`,`OptionBroadcastTextID`,`OptionType`,
     `OptionNpcFlag`,`ActionMenuID`,`ActionPoiID`,`BoxCoded`,`BoxMoney`,`BoxText`,`BoxBroadcastTextID`,`VerifiedBuild`) VALUES
(12799, 0, 0, 'How are we doing in the battle?', 52357, 0, 0, 12902, 0, 0, 0, NULL, 0, NULL),
(12799, 4, 0, 'What are we building here?',      52999, 0, 0, 13002, 0, 0, 0, NULL, 0, NULL),
(12833, 0, 0, 'How do I get out of here?',       52939, 0, 0, 12977, 0, 0, 0, NULL, 0, NULL),
(12977, 0, 0, 'I think I understand. Thank you.', 52940, 0, 0, 12978, 0, 0, 0, NULL, 0, NULL);

-- ---------------------------------------------------------------------------
-- Verify (expected: 2 / 1 / 1 options, and 5 menus resolving to real npc_text)
-- ---------------------------------------------------------------------------
--   SELECT MenuID, COUNT(*) FROM gossip_menu_option
--    WHERE MenuID IN (12799,12833,12977) GROUP BY MenuID;
--   SELECT gm.MenuID, gm.TextID, (t.ID IS NOT NULL) text_ok
--     FROM gossip_menu gm LEFT JOIN npc_text t ON t.ID = gm.TextID
--    WHERE gm.MenuID IN (12902,12904,12977,12978,13002);
-- ---------------------------------------------------------------------------
