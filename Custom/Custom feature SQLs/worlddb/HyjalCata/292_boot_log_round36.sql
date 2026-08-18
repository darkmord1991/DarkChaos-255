-- ---------------------------------------------------------------------------
-- 292  Boot log round 36 -- closing the loot class properly, and 2 live scripts
-- ---------------------------------------------------------------------------
-- Errors.log is down to 87 lines / 8,843 bytes (from 745 / 92,435 at the start
-- of this project, 286 / 31,266 ten rounds ago).
--
--   1  the LAST 11 "useless creature_loot_template" lines -- a different shape
--      from the 211 already removed, and the reason my own check said 0
--   2  spell 82848 Massacre -> spell_chimaeron_massacre
--   3  spell 61244 -> spell_q13413_wyrmrest_skytalon_ride_periodic, an UPSTREAM
--      row that something deleted after the updater applied it
--
-- Apply against acore_world, then restart worldserver. Idempotent.

-- ---------------------------------------------------------------------------
-- 1) The same id living in TWO loot stores
-- ---------------------------------------------------------------------------
--     Table 'creature_loot_template' Entry 34046 isn't creature entry and not
--     referenced from loot, and thus useless.
--
-- 🔴 MY POST-APPLY CHECK FOR 291_ SAID "0 ORPHANS REMAINING" AND 11 LINES
-- SURVIVED. The check was wrong, not the fix, and the reason is worth keeping:
--
-- my query treated `creature_loot_template.Reference = X` as "X is referenced".
-- It is not. A `Reference` value resolves against the **reference_loot_template
-- store**, never against the creature store. So an id can be referenced 11
-- times and still have a completely unused creature-store table of the same
-- number -- two different stores that happen to share an integer.
--
-- Measured for all 11 (creature-store rows / reference-store rows / times
-- referenced / used as a lootid):
--   34046  54 / 2   / 11 / 0        34302  12 / 6   / 1 / 0
--   34103   2 / 10  /  1 / 0        34304  25 / 18  / 1 / 0
--   34204  21 / 79  /  1 / 0        34326  13 / 18  / 5 / 0
--   34208  17 / 115 /  1 / 0        34350   6 / 1   / 6 / 0
--   34248  42 / 15  /  1 / 0        34351   4 / 10  / 1 / 0
--   34294  19 / 12  /  1 / 0
--
-- Every one has a populated reference-store entry, so every reference resolves
-- and the loot works today. And every one has `used_as_lootid = 0`, so the
-- creature-store copy is unreachable code -- an importer wrote the same data
-- into both stores. Deleting the creature-store copy cannot change a drop,
-- whatever it contains, because nothing can ever reach it.
--
-- 215 rows. The reference-store copies are NOT touched -- they are the ones
-- that actually resolve.
DROP TABLE IF EXISTS acore_world.`dc_dualstore_loot_backup`;
CREATE TABLE acore_world.`dc_dualstore_loot_backup` LIKE acore_world.`creature_loot_template`;

INSERT INTO acore_world.`dc_dualstore_loot_backup`
SELECT l.* FROM acore_world.`creature_loot_template` l
WHERE l.`Entry` IN (34046,34103,34204,34208,34248,34294,34302,34304,34326,34350,34351)
  -- re-assert both preconditions at apply time rather than trusting the list:
  -- nothing may use it as a lootid, and the reference store must carry it
  AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_template` t WHERE t.`lootid` = l.`Entry`)
  AND EXISTS (SELECT 1 FROM acore_world.`reference_loot_template` r WHERE r.`Entry` = l.`Entry`);

DELETE l FROM acore_world.`creature_loot_template` l
JOIN acore_world.`dc_dualstore_loot_backup` b
  ON b.`Entry` = l.`Entry` AND b.`Item` = l.`Item`
 AND b.`Reference` = l.`Reference` AND b.`GroupId` = l.`GroupId`;

-- ---------------------------------------------------------------------------
-- 2) spell_chimaeron_massacre -- the only unassigned script of its family
-- ---------------------------------------------------------------------------
--     Script named 'spell_chimaeron_massacre' is not assigned in the database.
--
-- Chimaeron's Massacre is spell **82848** (present in spell_dbc, named
-- "Massacre"). The script is compiled and registered
-- (boss_chimaeron.cpp:688/719) and Chimaeron 43296 exists.
--
-- The identification is not a guess: NINE sibling scripts from the same file
-- are already assigned -- 82705 finkles_mixture, 82871/82935/88915/88916/88917
-- caustic_slime, 88826 double_attack, 88861 reroute_power, 88872 feud, 91304
-- shadow_whip. This is the one that was missed, and 82848 is the only Massacre
-- spell in the store (330042 "Command: Massacre" is a DC command spell).
DELETE FROM acore_world.`spell_script_names` WHERE `spell_id` = 82848 AND `ScriptName` = 'spell_chimaeron_massacre';
INSERT INTO acore_world.`spell_script_names` (`spell_id`,`ScriptName`) VALUES
(82848, 'spell_chimaeron_massacre');

-- ---------------------------------------------------------------------------
-- 3) An UPSTREAM row that went missing after its update ran
-- ---------------------------------------------------------------------------
--     Script named 'spell_q13413_wyrmrest_skytalon_ride_periodic' is not
--     assigned in the database.
--
-- This one is not ours at all. `data/sql/updates/db_world/2026_06_30_01.sql`
-- line 27 contains exactly:
--     INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`)
--       VALUES (61244, 'spell_q13413_wyrmrest_skytalon_ride_periodic');
-- and that update **is marked applied** in `acore_world.updates`. The row is
-- nevertheless absent, so something removed it afterwards -- most likely a
-- custom file doing a broad DELETE on `spell_script_names`. Worth knowing that
-- this can happen: an applied-updates entry is not proof its rows are still
-- there.
--
-- Restored verbatim, same spell id and script name as upstream. Its two
-- siblings (56070 summon_red_dragon_buddy, 56072 ride_red_dragon_buddy_trigger)
-- are present, which is what makes 61244 the odd one out rather than a guess.
DELETE FROM acore_world.`spell_script_names` WHERE `spell_id` = 61244 AND `ScriptName` = 'spell_q13413_wyrmrest_skytalon_ride_periodic';
INSERT INTO acore_world.`spell_script_names` (`spell_id`,`ScriptName`) VALUES
(61244, 'spell_q13413_wyrmrest_skytalon_ride_periodic');

-- ---------------------------------------------------------------------------
-- Verify after apply
-- ---------------------------------------------------------------------------
--  1  SELECT COUNT(DISTINCT Entry) FROM dc_dualstore_loot_backup;          -> 11
--     SELECT COUNT(*) FROM dc_dualstore_loot_backup;                      -> 215
--     SELECT COUNT(*) FROM creature_loot_template
--      WHERE Entry IN (34046,34103,34204,34208,34248,34294,34302,34304,
--                      34326,34350,34351);                                 -> 0
--     -- the reference-store copies must be UNTOUCHED:
--     SELECT COUNT(*) FROM reference_loot_template
--      WHERE Entry IN (34046,34103,34204,34208,34248,34294,34302,34304,
--                      34326,34350,34351);                               -> 286
--  2  SELECT COUNT(*) FROM spell_script_names WHERE spell_id=82848;        -> 1
--  3  SELECT COUNT(*) FROM spell_script_names WHERE spell_id=61244;        -> 1
--
--  Next boot: all 11 creature_loot_template lines and 2 of the 6 "Script named
--  X is not assigned" lines gone. Errors.log should be ~74 lines.
--
-- REVERT
--   INSERT INTO creature_loot_template SELECT * FROM dc_dualstore_loot_backup;
--   DELETE FROM spell_script_names WHERE spell_id IN (82848, 61244);

-- ---------------------------------------------------------------------------
-- The other 4 unassigned scripts -- each checked, none safe to assign blind
-- ---------------------------------------------------------------------------
-- All four are compiled and registered. None is a missing-row problem, so
-- writing a row would attach behaviour to the wrong thing:
--
-- * **npc_group_finder** (dc_addon_groupfinder_npc.cpp) declares
--   `NPC_GROUP_FINDER = 600100` with the comment "Update this in SQL to match
--   your creature template" -- and **creature_template 600100 does not exist**.
--   The GroupFinder is addon-driven and NPC-free by design (the same shape as
--   the 191001/191002 upgrade stubs), so this is a vestigial NPC entry point.
--   Assigning it means first deciding whether the feature should have an NPC.
--
-- * **npc_darkshore_wisp_circling** has a real target -- 3734306 "Darkshore
--   Wisp", 29 spawns -- but it CANNOT be attached as written. That template is
--   `AIName = 'SmartAI'` with 2 smart_scripts rows, and AIName and ScriptName
--   are mutually exclusive: FactorySelector picks the ScriptName's CreatureAI
--   and SmartAI never runs. The script's own header says its drifting motion is
--   "additive" and that the sparkle "is already driven by SmartAI ... and is
--   left untouched" -- which is exactly what assigning it would break. The
--   drift wants to be a SmartAI action (or the sparkle folded into the C++),
--   not a ScriptName. A code decision, not a DB row.
--
-- * **go_ancient_primal_altar** (dc_giant_isles_zone.cpp:765) hardcodes no
--   entry, and no Giant Isles gameobject is named for it -- the zone's altars
--   are all generic model placeholders (506891 LavaAltar, 508377 Altar01,
--   512741 AltarOfStorms...). Nothing identifies which one was meant, and the
--   script drives world-boss summoning, so guessing puts a boss-summon gossip
--   on an arbitrary prop.
--
-- * **GOMove_spell_place** is undecided IN THE SOURCE: the two lines above the
--   class are literally `// possible spells:` / `// 27651, 897`. The author
--   never picked one. It is a GM tool, so nothing is broken by it staying
--   unassigned.
--
-- ---------------------------------------------------------------------------
-- What is left in Errors.log after this, and why none of it is a DB fix
-- ---------------------------------------------------------------------------
-- * 36 Legion Dalaran GO lines (4100xxx) -- retail spell/SpellFocus ids with no
--   downport source, incl. 3 with data0 = 0 where the spell was never authored.
-- * 7 quest RewardSpell lines (89550, 89669, 89781, 94710, 95818) -- exist in
--   no client we hold.
-- * 4 Shadowlands spell-script effect mismatches -- C++ change.
-- * 2 SmartAI waypoint gaps (16256, 17238) -- stock upstream ids, no path in
--   either `waypoints` or `waypoint_data`.
-- * 3 loot chance > 100% lines -- pre-existing STOCK balance (215_, 219_).
-- * 10 pickpocket / skinning / reference "useless" orphans -- they fail the
--   duplicate test that justified rounds 34-36, and the reference-side orphan
--   query is itself incomplete (a Reference can be held by mail/spell/fishing/
--   disenchant/prospecting/milling stores it never checks). Unproven is not
--   junk.
-- * 5 `command` rows and OutdoorPvP type 8 -- established as not-DB-bugs.
