-- 87_data_table_gaps.sql -- map 751 Lordaeron extension, DB step 26.
--
-- Five defect classes from the post-restart error log, none of them SmartAI.
-- Section 1 alone accounts for roughly HALF of every line in Errors.log.
--
-- ===========================================================================
-- 1. `creature_equip_template` was never imported  (984 of 2000 log lines)
--
--    "Table `creature` have creature (Entry: 4145280) with equipment_id 1 not
--     found in table `creature_equip_template`, set to no equipment."
--
--    2,499 spawns across 547 distinct creature entries, ALL on map 751 -- map
--    750's import did include this table, which is why only the Lordaeron band
--    is affected. Same root cause as `waypoints` (86_), `creature_text` (82_)
--    and `npc_spellclick_spells` (80_): the import copied `creature` and
--    `creature_template` but not a table they reference.
--
--    Visible effect, not just log noise: 547 NPC types are standing around
--    empty-handed. Guards with no swords, hunters with no bows, the whole band.
--
--    Verified before writing this:
--      * all 547 have a matching row in cata_world.creature_equip_template
--      * the two schemas are IDENTICAL (CreatureID, ID, ItemID1..3, VerifiedBuild),
--        so no column drops or shifts are needed -- unlike waypoints/creature_text
--      * of the 230 distinct item ids referenced, ZERO are missing from our
--        item_template, so this import trades no error class for another
--      * no CreatureID in 4100000-4199999 is currently occupied
--
--    The join is on (CreatureID+4,100,000, ID) matching a real spawn's
--    equipment_id, so only rows something actually uses are brought over.
-- ===========================================================================
DELETE FROM `creature_equip_template` WHERE `CreatureID` BETWEEN 4100000 AND 4199999;

INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`)
SELECT ce.`CreatureID` + 4100000, ce.`ID`, ce.`ItemID1`, ce.`ItemID2`, ce.`ItemID3`, ce.`VerifiedBuild`
FROM `cata_world`.`creature_equip_template` ce
WHERE EXISTS (SELECT 1 FROM `creature` c
              WHERE c.`map` = 751 AND c.`id` = ce.`CreatureID` + 4100000
                AND c.`equipment_id` = ce.`ID`);

-- ===========================================================================
-- 2. Undercity elevators: `state` 24 is not a WotLK GOState
--
--    "Table `gameobject` has gameobject (GUID: 16400277 Entry: 4620651) with
--     invalid `state` (24) value, skip"
--
--    9 spawns -- three Undercity lifts, each an "Undervator" (GO type 11,
--    transport) plus its upperLdoor and lowerLdoor. `skip` means they are NOT
--    SPAWNED AT ALL, so these lifts are simply missing in the world.
--
--    No guessing was needed: the SAME NINE GO ENTRIES exist in stock WotLK on
--    map 0, and stock uses state 1 / animprogress 100 where Cata uses 24 / 255.
--    Cata widened GOState and the import copied its value verbatim. The values
--    written below are stock's, not invented ones.
--
--    Scoped by guid so only the map-751 clones move; stock Undercity is untouched.
-- ===========================================================================
UPDATE `gameobject`
SET `state` = 1, `animprogress` = 100
WHERE `guid` BETWEEN 16400277 AND 16400285
  AND `map` = 751 AND `state` = 24;

-- ===========================================================================
-- 3. Battlemasters with the flag but no `battlemaster_entry` row
--
--    "CreatureTemplate (Entry: 4119905) has UNIT_NPC_FLAG_BATTLEMASTER but no
--     data in `battlemaster_entry` table. Removing flag!"
--
--    8 NPCs. All 8 have a mapping in cata_world.battlemaster_entry, and
--    BattlegroundMgr::LoadBattleMastersEntry (BattlegroundMgr.cpp:840-845) only
--    requires the bg id to exist in BattlemasterList.dbc.
--
--    SIX are mapped to battlegrounds this 3.3.5 core actually runs, so they get
--    real rows and start working as battlemasters:
--       4119905 The Black Bride        -> 3  Arathi Basin
--       4119906 Usha Eyegouge          -> 1  Alterac Valley
--       4119907 Grumbol Grimhammer     -> 1  Alterac Valley
--       4130231 Radulf Leder           -> 3  Arathi Basin
--       4134983 Deathstalker Fane      -> 32 Random Battleground
--       4134985 Misery                 -> 32 Random Battleground
--
--    TWO map to bg 120, Cata's Rated Battleground. The id is present in
--    BattlemasterList.dbc so a row WOULD load, but this core has no
--    implementation to queue into, which is worse than being inert -- the NPC
--    would offer a battleground that can never start. Their flag is cleared in
--    creature_template instead, which is what the core does at runtime anyway;
--    doing it in data just stops the warning.
--       4144004 Gilnean Envoy          -> 120 Rated BG (no WotLK equivalent)
--       4150676 Hans Crump             -> 120 Rated BG (no WotLK equivalent)
--
--    NOTE THIS SECTION CHANGES BEHAVIOUR, not just logging: six NPCs that are
--    currently inert become functional battlemasters. That is what Blizzard's
--    data says they are, but if you would rather they stayed inert, drop the
--    INSERT and clear the flag on all 8 instead.
-- ===========================================================================
DELETE FROM `battlemaster_entry` WHERE `entry` IN (4119905, 4119906, 4119907, 4130231, 4134983, 4134985);

INSERT INTO `battlemaster_entry` (`entry`, `bg_template`) VALUES
(4119905,  3),
(4119906,  1),
(4119907,  1),
(4130231,  3),
(4134983, 32),
(4134985, 32);

-- the two Cata-only ones: clear UNIT_NPC_FLAG_BATTLEMASTER (0x00100000 = 1048576)
UPDATE `creature_template`
SET `npcflag` = `npcflag` & ~1048576
WHERE `entry` IN (4144004, 4150676) AND (`npcflag` & 1048576);

-- ===========================================================================
-- 4. "Table 'creature_loot_template' entry 4101531 group 1 has total chance
--     > 100% (137.5)"
--
--    4101531 is Lost Soul. Its group 1 holds item 3322 Wispy Cloak at chance
--    100, then five REFERENCE rows at 30/5/1/1/0.5.
--
--    Checked against both sources before touching it:
--       stock AC entry 1531, group 1 : 3322 @ 100          -> sums to exactly 100
--       cata     entry 1531, group 1 : 3322 @ 100 + the 5  -> sums to 137.5
--
--    So the 100% cloak is stock AzerothCore's own data and is NOT something this
--    import introduced. The only change is Cata's five extra reference rows --
--    and behind a 100% entry, LootTemplate::LootGroup::Roll can never reach
--    them. They are unreachable rows that exist purely to trigger this warning.
--
--    Deleting them restores the entry to stock's exact shape and changes zero
--    actual drops. The alternative -- rescaling 3322 down to 62.5 so the group
--    sums to 100 -- would invent a number and start dropping four Outland-level
--    greens off a level-10 mob, so it is not done here.
-- ===========================================================================
DELETE FROM `creature_loot_template`
WHERE `Entry` = 4101531 AND `GroupId` = 1 AND `Reference` > 0
  AND `Item` IN (24073, 24100, 24720, 24730, 44007);

-- ===========================================================================
-- 5. Orphaned spawn pool 130008297
--
--    "`pool_creature` has a non existing creature spawn (GUID: 15000002)
--     defined for pool id (130008297), skipped."   x10, then
--    "Pool Id 130008297 is empty ... The pool will not be spawned."
--
--    A map-750 (Hyjal) leftover, described as "Hyjal-Nel pool 8297 (4 members)"
--    but holding 10 rows, none of whose spawns were ever created. Verified fully
--    orphaned: no pool_pool parent or child, no pool_gameobject, no pool_quest,
--    no game_event_pool, and none of the 10 guids exist in `creature`. The core
--    already refuses to spawn it, so removing it loses nothing and drops 11 log
--    lines.
-- ===========================================================================
DELETE FROM `pool_creature` WHERE `pool_entry` = 130008297;
DELETE FROM `pool_template` WHERE `entry` = 130008297;

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'equip templates imported (want 547)' AS what, COUNT(*) AS n
FROM `creature_equip_template` WHERE `CreatureID` BETWEEN 4100000 AND 4199999
UNION ALL SELECT 'map-751 spawns still missing equipment (want 0)', COUNT(*)
FROM `creature` c WHERE c.`map` = 751 AND c.`equipment_id` > 0
  AND NOT EXISTS (SELECT 1 FROM `creature_equip_template` e
                  WHERE e.`CreatureID` = c.`id` AND e.`ID` = c.`equipment_id`)
UNION ALL SELECT 'imported equip rows naming a missing item (want 0)', COUNT(*)
FROM `creature_equip_template` e WHERE e.`CreatureID` BETWEEN 4100000 AND 4199999
  AND ((e.`ItemID1` > 0 AND NOT EXISTS (SELECT 1 FROM `item_template` i WHERE i.`entry` = e.`ItemID1`))
    OR (e.`ItemID2` > 0 AND NOT EXISTS (SELECT 1 FROM `item_template` i WHERE i.`entry` = e.`ItemID2`))
    OR (e.`ItemID3` > 0 AND NOT EXISTS (SELECT 1 FROM `item_template` i WHERE i.`entry` = e.`ItemID3`)))
UNION ALL SELECT 'gameobjects with an invalid state left (want 0)', COUNT(*)
FROM `gameobject` WHERE `state` NOT BETWEEN 0 AND 2
UNION ALL SELECT 'the 9 elevators now spawnable (want 9)', COUNT(*)
FROM `gameobject` WHERE `guid` BETWEEN 16400277 AND 16400285 AND `state` = 1
UNION ALL SELECT 'battlemasters with flag but no row (want 0)', COUNT(*)
FROM `creature_template` t WHERE (t.`npcflag` & 1048576)
  AND t.`entry` BETWEEN 4100000 AND 4199999
  AND NOT EXISTS (SELECT 1 FROM `battlemaster_entry` b WHERE b.`entry` = t.`entry`)
UNION ALL SELECT 'battlemaster rows added (want 6)', COUNT(*)
FROM `battlemaster_entry` WHERE `entry` BETWEEN 4100000 AND 4199999
UNION ALL SELECT 'loot 4101531 group 1 total chance (want 100)', CAST(SUM(`Chance`) AS SIGNED)
FROM `creature_loot_template` WHERE `Entry` = 4101531 AND `GroupId` = 1
UNION ALL SELECT 'pool 130008297 rows left (want 0)', (SELECT COUNT(*) FROM `pool_creature` WHERE `pool_entry` = 130008297)
                                                    + (SELECT COUNT(*) FROM `pool_template` WHERE `entry` = 130008297);

-- must be empty: a battlemaster_entry row whose creature lost the flag, which
-- the core reports as "listed in `battlemaster_entry` is not a battlemaster"
SELECT 'PROBLEM: battlemaster row without the flag' AS problem, b.`entry`, t.`name`
FROM `battlemaster_entry` b JOIN `creature_template` t ON t.`entry` = b.`entry`
WHERE b.`entry` BETWEEN 4100000 AND 4199999 AND (t.`npcflag` & 1048576) = 0;

-- must be empty: any loot group anywhere in the band still over 100%
SELECT 'PROBLEM: loot group over 100%' AS problem, `Entry`, `GroupId`, SUM(`Chance`) AS total
FROM `creature_loot_template` WHERE `Entry` BETWEEN 4100000 AND 4199999 AND `GroupId` > 0
GROUP BY `Entry`, `GroupId` HAVING SUM(`Chance`) > 100;
