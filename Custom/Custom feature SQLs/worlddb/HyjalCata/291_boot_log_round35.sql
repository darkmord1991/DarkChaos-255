-- ---------------------------------------------------------------------------
-- 291  Boot log round 35 -- and it finishes a job 290_ could not finish itself
-- ---------------------------------------------------------------------------
-- 🔴 SECTION 1 EXISTS BECAUSE 290_ HAD AN ORDERING BUG. Read this before
-- assuming 290_ misbehaved: it did not delete anything it should not have. Its
-- section 4 refused to act, which is exactly what it was built to do.
--
-- 290_ section 3 deletes the ilvl-<60 vanilla gear rows from the LIVE forked
-- loot tables. 290_ section 4 then deletes orphan loot tables only if every
-- (Item, Reference) pair they hold also appears in the live +3.7M clone table.
-- Section 3 had just removed rows from those live tables -- so 104 of the 107
-- orphans stopped being strict subsets and section 4 correctly declined them,
-- deleting only the 3 that still qualified (27 rows).
--
-- The two sections had to run in the other order. Nothing was lost, and the
-- guard proved its worth: a blind `DELETE ... WHERE orphan` would have removed
-- all 107 regardless, which is the 266_ mistake.
--
-- The corrected test, measured over the 104 that remain: a row is redundant if
-- it is in the live clone table **OR** it is one of the ilvl-<60 gear rows 290_
-- deliberately removed (because that gear has no place on these creatures at
-- all -- that was section 3's whole point). Under it: **104 of 104 redundant,
-- 0 unproven, 3,975 rows.**
--
-- Sections:
--   1  finish 290_ section 4 -- 104 orphan loot tables, 3,975 rows
--   2  4 creatures with a skinloot pointing at a table that does not exist
--   3  areatrigger 5876 -- the Hyjal Barrow Dens trigger has never fired
--   4  quest 13569 SpecialFlags
--   5  quests 25251 / 25265 -- QuestSortID names a zone that does not exist
--   6  SmartAI actionlist 5391201 -- WP_START points one id off its own path
--
-- Apply against acore_world, then restart worldserver. Idempotent.

-- ---------------------------------------------------------------------------
-- 1) The 104 orphan loot tables 290_ declined
-- ---------------------------------------------------------------------------
-- Same backup-then-delete-the-backup shape as 290_, with the corrected test.
-- The backup is separate from `dc_orphan_loot_backup` (which holds 290_'s 3) so
-- the two rounds stay independently revertible.
DROP TABLE IF EXISTS acore_world.`dc_orphan_loot_backup2`;
CREATE TABLE acore_world.`dc_orphan_loot_backup2` LIKE acore_world.`creature_loot_template`;

INSERT INTO acore_world.`dc_orphan_loot_backup2`
SELECT l.* FROM acore_world.`creature_loot_template` l
WHERE l.`Entry` IN (
  SELECT z.`Entry` FROM (
    SELECT DISTINCT d.`Entry` FROM acore_world.`creature_loot_template` d
     WHERE NOT EXISTS (SELECT 1 FROM acore_world.`creature_template` t WHERE t.`lootid` = d.`Entry`)
       AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_loot_template` r WHERE r.`Reference` = d.`Entry`)
       AND NOT EXISTS (SELECT 1 FROM acore_world.`reference_loot_template` r2 WHERE r2.`Reference` = d.`Entry`)
       -- the clone must exist and be spawned: this is what makes the orphan
       -- provably redundant rather than merely unreferenced
       AND EXISTS (SELECT 1 FROM acore_world.`creature` c WHERE c.`id` = d.`Entry` + 3700000)
       AND NOT EXISTS (
             SELECT 1 FROM acore_world.`creature_loot_template` a
              WHERE a.`Entry` = d.`Entry`
                -- either the same row is still on the live clone table...
                AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_loot_template` b
                                 WHERE b.`Entry` = d.`Entry` + 3700000
                                   AND b.`Item` = a.`Item` AND b.`Reference` = a.`Reference`)
                -- ...or it is ilvl-<60 vanilla gear, which 290_ section 3 removed
                -- from the live table on purpose and which must not come back
                AND NOT EXISTS (SELECT 1 FROM acore_world.`item_template` i
                                 WHERE i.`entry` = a.`Item` AND a.`Reference` = 0
                                   AND i.`class` IN (2,4) AND i.`ItemLevel` < 60))
  ) z);

DELETE l FROM acore_world.`creature_loot_template` l
JOIN acore_world.`dc_orphan_loot_backup2` b
  ON b.`Entry` = l.`Entry` AND b.`Item` = l.`Item`
 AND b.`Reference` = l.`Reference` AND b.`GroupId` = l.`GroupId`;

-- ---------------------------------------------------------------------------
-- 2) 4 creatures whose skinloot points at nothing
-- ---------------------------------------------------------------------------
--     Table 'skinning_loot_template' Entry 3702070 does not exist but it is
--     used by Creature 3702070
--
-- 3702070 Moonstalker Runt, 3706375 Thunderhead Hippogryph, 3706377
-- Thunderhead Stagwing, 3712123 Reef Shark. All have `skinloot = entry` and an
-- EMPTY table -- the state 239_'s own header says it guards against ("a
-- dangling skinloot logs errors and yields nothing"), so its empty-table revert
-- has a hole.
--
-- Same root cause as 290_ section 2: 239_ sourced the +3.7M band from
-- cata_world. 290_ fixed the `skinloot = 0` case; these four already had
-- skinloot SET, so its guard skipped them. This is the other half.
--
-- nelt has real tables for all four (2 / 4 / 4 / 3 rows) and every item exists
-- here, so none of them ends up empty again.
--
-- None of the four is spawned anywhere, so this is log-only today -- but it
-- costs two statements and it makes 290_'s own "no dangling skinloot" check
-- true, which is worth more than the four lines.
DELETE FROM acore_world.`skinning_loot_template` WHERE `Entry` IN (3702070,3706375,3706377,3712123);

INSERT INTO acore_world.`skinning_loot_template`
  (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT ct.`entry`, sl.`item`, 0, sl.`ChanceOrQuestChance`, 0, 1, sl.`groupid`,
       sl.`mincountOrRef`, sl.`maxcount`,
       CONCAT('DC750 skin from nelt ', src.`entry`, ' (291 -- 239_ left these dangling)')
FROM acore_world.`creature_template` ct
JOIN `nelt_world`.`creature_template` src ON src.`entry` = CAST(ct.`entry` AS SIGNED) - 3700000
JOIN `nelt_world`.`skinning_loot_template` sl ON sl.`entry` = src.`skinloot`
WHERE ct.`entry` IN (3702070,3706375,3706377,3712123)
  AND src.`skinloot` <> 0
  AND EXISTS (SELECT 1 FROM acore_world.`item_template` i WHERE i.`entry` = sl.`item`)
  AND sl.`ChanceOrQuestChance` > 0
  AND sl.`mincountOrRef` > 0;

-- ---------------------------------------------------------------------------
-- 3) Area trigger 5876 -- and the message lies about which source is missing
-- ---------------------------------------------------------------------------
--     Area trigger (ID:5876) does not exist in `AreaTrigger.dbc`.
--
-- 🔴 I GOT THIS WRONG IN 287_ AND SAID IT WOULD CLEAR ON THE NEXT RESTART.
-- It did not, and the reason is that the message names the wrong source.
-- `ObjectMgr::LoadAreaTriggers` (ObjectMgr.cpp:7255) fills `_areaTriggerStore`
-- from the **`areatrigger` DATABASE TABLE**, not from AreaTrigger.dbc, and
-- `GetAreaTrigger()` reads that store. So "does not exist in AreaTrigger.dbc"
-- actually means "no row in `areatrigger`". Checking the DBC (where 5876 is
-- present and valid) proved nothing at all.
--
-- The table has 1,268 rows, 13 of them on map 750, and no 5876. Meanwhile
-- `areatrigger_scripts` has the row -- so `at_mh_hyjal_barrow_dens` is
-- registered, compiled and has never once fired. It is the only orphan of its
-- kind (0 orphans in areatrigger_teleport and areatrigger_involvedrelation).
--
-- The geometry below is read straight out of the deployed AreaTrigger.dbc row
-- 5876 (map 750, box 35.42 x 11.81 x 13.45, no radius), so the trigger volume
-- matches exactly what the client already thinks is there -- which is what you
-- want, or the server fires at a different place than the client shows.
DELETE FROM acore_world.`areatrigger` WHERE `entry` = 5876;
INSERT INTO acore_world.`areatrigger`
  (`entry`,`map`,`x`,`y`,`z`,`radius`,`length`,`width`,`height`,`orientation`) VALUES
(5876, 750, 5707.540039, -3160.320068, 1596.900024, 0, 35.419998, 11.81, 13.45, 0);

-- ---------------------------------------------------------------------------
-- 4) Quest 13569 "The Ritual Bond"
-- ---------------------------------------------------------------------------
--     Spell (id: 62803) have SPELL_EFFECT_QUEST_COMPLETE for quest 13569, but
--     quest not have specialflag QUEST_SPECIAL_FLAGS_EXPLORATION_OR_EVENT.
--     Quest flags must be fixed, quest modified to enable objective.
--
-- The core already forces the flag on at load ("quest modified to enable
-- objective"), so this is the DB catching up with what the server does anyway --
-- zero behaviour change. 2 = QUEST_SPECIAL_FLAGS_EXPLORATION_OR_EVENT.
UPDATE acore_world.`quest_template_addon` SET `SpecialFlags` = `SpecialFlags` | 2
 WHERE `ID` = 13569 AND (`SpecialFlags` & 2) = 0;

-- ---------------------------------------------------------------------------
-- 5) Quests 25251 / 25265 -- sorted into a zone that does not exist
-- ---------------------------------------------------------------------------
--     Quest 25251 has `ZoneOrSort` = 4720 (zone case) but zone with this id
--     does not exist.
--
-- 4720 is Gilneas City, a Cataclysm zone. It is absent from this build's
-- AreaTable (checked: 0 rows in `areatable_dbc`) and Gilneas was never
-- downported, so there is no zone for these to sort into. Exactly 2 quests use
-- it; their neighbours in the 25240-25280 range sort under 14/16/616/1519/
-- 1637/4812.
--
-- Set to 0 rather than borrowing a neighbour's zone. Both quests ("Final
-- Confrontation", "Victory!") have **no questgiver of any kind**, so nobody can
-- take them and a wrong zone would just misfile them in a log nobody sees;
-- 0 is the honest "unsorted". Adding a real AreaTable row for a zone whose
-- content does not exist would be worse -- it would show an empty Gilneas in
-- the client's zone lists.
UPDATE acore_world.`quest_template` SET `QuestSortID` = 0
 WHERE `ID` IN (25251,25265) AND `QuestSortID` = 4720;

-- ---------------------------------------------------------------------------
-- 6) SmartAI actionlist 5391201 -- off by one id
-- ---------------------------------------------------------------------------
--     SmartAIMgr: Creature 5391201 Event 1 Action 53 uses non-existent
--     WaypointPath id 5391200, skipped.
--
-- "Creature 5391201" in the message is misleading: source_type is 9, so 5391201
-- is a TIMED_ACTIONLIST id, not a creature. Under this project's convention
-- (actionlist = entry * 100) it belongs to creature 53912 -> our clone 3653912,
-- a Molten Front NPC. Its two actions are: cast 88467, then WP_START.
--
-- `SmartScriptMgr.cpp:1798` validates the path through `sSmartWaypointMgr`,
-- which reads the `waypoints` table. That table holds path **5391201** with 11
-- points (1-11). It does NOT hold 5391200. So the action asks for a path one id
-- below the one that was actually authored, and the whole action is skipped.
-- In this fork WP_START takes the path in **param2**
-- ([[map750-smartai-and-waypoint-restore]]).
--
-- NOTE this does not make the sequence run yet: nothing calls actionlist
-- 5391201 (0 rows anywhere with action_type 80 -> 5391201), so the "MF deep
-- layer" scene is still unwired. That is a content question for the Molten
-- Front pass, not a log fix -- but the path reference should be right either
-- way, and fixing it now means the scene works the moment a caller is added.
UPDATE acore_world.`smart_scripts` SET `action_param2` = 5391201
 WHERE `entryorguid` = 5391201 AND `source_type` = 9 AND `id` = 1
   AND `action_type` = 53 AND `action_param2` = 5391200;

-- ---------------------------------------------------------------------------
-- Verify after apply
-- ---------------------------------------------------------------------------
--  1  SELECT COUNT(DISTINCT Entry) FROM dc_orphan_loot_backup2;           -> 104
--     SELECT COUNT(*) FROM dc_orphan_loot_backup2;                      -> 3,975
--     SELECT COUNT(*) FROM (SELECT DISTINCT Entry FROM creature_loot_template d
--       WHERE NOT EXISTS (SELECT 1 FROM creature_template t WHERE t.lootid=d.Entry)
--         AND NOT EXISTS (SELECT 1 FROM creature_loot_template r WHERE r.Reference=d.Entry)
--         AND NOT EXISTS (SELECT 1 FROM reference_loot_template r2 WHERE r2.Reference=d.Entry)) z;
--                                                                          -> 0
--  2  SELECT COUNT(*) FROM creature_template t WHERE t.skinloot<>0
--       AND NOT EXISTS (SELECT 1 FROM skinning_loot_template s WHERE s.Entry=t.skinloot);
--                                                                          -> 0
--     SELECT Entry, COUNT(*) FROM skinning_loot_template
--      WHERE Entry IN (3702070,3706375,3706377,3712123) GROUP BY Entry;
--                                                            -> 2 / 4 / 4 / 3
--  3  SELECT COUNT(*) FROM areatrigger WHERE entry=5876;                   -> 1
--     SELECT COUNT(*) FROM areatrigger_scripts s WHERE NOT EXISTS
--       (SELECT 1 FROM areatrigger a WHERE a.entry=s.entry);               -> 0
--     -- in-game: walking into the Barrow Dens entrance on map 750 should now
--     -- run at_mh_hyjal_barrow_dens. That is the check that matters.
--  4  SELECT SpecialFlags FROM quest_template_addon WHERE ID=13569;        -> 2
--  5  SELECT COUNT(*) FROM quest_template WHERE QuestSortID=4720;          -> 0
--  6  SELECT action_param2 FROM smart_scripts WHERE entryorguid=5391201
--       AND source_type=9 AND id=1;                                  -> 5391201
--
-- ---------------------------------------------------------------------------
-- Done outside SQL this round -- the map-750 elevators
-- ---------------------------------------------------------------------------
--     StaticTransport::Create: No AnimationInfo was found for GameObject entry
--     (3796837) / (3804243) / (3807889) / (3752614) / (3804246)
--
-- These are in **Server.log**, not Errors.log, and they are a DBC gap, so there
-- is nothing for this file to do -- recorded here so the round is complete.
--
-- Seven type-11 (MO_TRANSPORT) elevators are spawned on map 750: 3752614
-- "Elevator" plus six goblin elevators. `TransportAnimation.dbc` is keyed by
-- **TransportEntry = the GameObject entry**, so a clone at +3,600,000 matches
-- nothing and `StaticTransport::Create` refuses to animate it -- the elevator
-- is a static prop you cannot ride.
--
-- Only 5 of the 7 appear in the log. 3804244 and 3804245 are NOT fixed and not
-- exempt: the message fires when the GO is instantiated into a loaded grid, so
-- those two simply sit in grids nobody has visited yet. Do not read the log
-- count as the scope of a runtime error class.
--
-- FIXED + DEPLOYED: 214 animation frames lifted from the Cata 4.3.4 client's
-- TransportAnimation.dbc (`enUS/locale-enUS.MPQ`) for source entries 152614,
-- 196837, 204243-204246 and 207889, re-emitted at +3,600,000 with fresh unique
-- ids. Layout is identical between the two clients (7 fields, 28 bytes,
-- `diifffx`), so the frames copy verbatim. **5,289 -> 5,503 records, 0 ids
-- lost, 0 TransportEntries lost, 0 duplicate ids.** Deployed to Custom/DBCs,
-- Server/data/dbc, patch-4 and patch-enGB-3 (both byte-verified after write --
-- this DBC is in the enGB chain as well, so patch-4 alone would be shadowed)
-- and the three WarcraftXL checkouts. Backups: `*.pre-r41.bak`.
-- **The live server's data/dbc copy still needs pushing.**
--
-- ---------------------------------------------------------------------------
-- Still not actionable
-- ---------------------------------------------------------------------------
-- * 36 Legion Dalaran GO lines (4100xxx type 22/8) -- retail spells and
--   SpellFocus ids with no downport source. Three of them (4100147, 4100502,
--   4101814) have data0 = 0 rather than a missing id, but they are the same
--   class: Tiffany's Carving Machine and two class-hall portals whose spell was
--   never authored here.
-- * 7 quest RewardSpell lines (89550, 89669, 89781, 94710, 95818) -- these five
--   spells exist in no client we hold, and guessing a substitute is worse than
--   no reward.
-- * 4 Shadowlands spell-script effect mismatches -- C++, needs a code change.
-- * 2 SmartAI waypoint gaps (creatures 16256, 17238) -- stock upstream ids with
--   no path in either `waypoints` or `waypoint_data`. Upstream's problem.
-- * The loot chance > 100% lines (skinning 7448 / 10807, reference 24161) --
--   pre-existing STOCK balance, unchanged position since 215_.
-- * The pickpocket / skinning / reference "useless" orphans -- they fail the
--   duplicate test that justified section 1, and the reference-side orphan
--   query is itself incomplete. Unproven is not junk.
-- * 6 "Script named X is not assigned in the database" -- npc_group_finder,
--   npc_darkshore_wisp_circling, go_ancient_primal_altar,
--   spell_chimaeron_massacre, GOMove_spell_place,
--   spell_q13413_wyrmrest_skytalon_ride_periodic. All have ZERO assignments in
--   creature_template / gameobject_template / spell_script_names. Each needs
--   its intended target identified from the C++ before a row can be written,
--   and a wrong assignment attaches behaviour to the wrong entity -- worth a
--   round of its own rather than a guess here.
-- * `command` rows and OutdoorPvP type 8 -- established as not-DB-bugs.
