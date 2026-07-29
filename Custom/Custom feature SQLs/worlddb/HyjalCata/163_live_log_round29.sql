-- ---------------------------------------------------------------------------
-- 163  Hyjal round-29 -- second pass against the live log
-- ---------------------------------------------------------------------------
-- 162_ took the live Errors.log from 382 lines / 42 KB to 233 lines / 22 KB.
-- Confirmed cleared after the restart: the ~150-line equipment_id block, the 8
-- orphaned creature_addon rows, both wander_distance contradictions, the
-- unbound spell_inferno_tick, Seething Pyrelord's KillCredit1, the map-745
-- orphan spawn, and 54343's dead loot item.  This round takes the two remaining
-- items that are genuinely Hyjal's.
--
-- ---------------------------------------------------------------------------
-- (1) The raw Nordrassil portals still cast spells that do not exist
-- ---------------------------------------------------------------------------
--     Gameobject (Entry: 205272 GoType: 22) have data0=84505 but Spell
--     (Entry 84505) not exist.
--     Gameobject (Entry: 205273 GoType: 22) have data0=84506 but Spell
--     (Entry 84506) not exist.
--
-- 121_ found that 84505/84506 are absent from Blizzard's own 3.3.5 data and
-- authored DC teleports 300600/300601 to replace them -- but it only repointed
-- the CLONES (3809080/3809081, which correctly carry 300600/300601 today).  The
-- raw Cata entries were left behind and are still spawned, so the same two
-- broken portals exist twice.
--
-- Both DC spells are present in spell_dbc, and 205272/205273 are the same
-- "Portal to Stormwind"/"...to Orgrimmar" pair, so the clone's fix applies
-- verbatim.  Guarded on the replacement spells existing so this cannot make
-- things worse if 121_ has not been applied.
UPDATE `gameobject_template` gt
JOIN `spell_dbc` s ON s.`ID` = 300600
SET gt.`data0` = 300600
WHERE gt.`entry` = 205272 AND gt.`data0` = 84505;

UPDATE `gameobject_template` gt
JOIN `spell_dbc` s ON s.`ID` = 300601
SET gt.`data0` = 300601
WHERE gt.`entry` = 205273 AND gt.`data0` = 84506;

-- ---------------------------------------------------------------------------
-- (2) Two SmartAI escorts walking a path that exists in no source DB
-- ---------------------------------------------------------------------------
--     SmartAIMgr: Creature 16256 Event 2 Action 53 uses non-existent
--     WaypointPath id 16256, skipped.        (Jessica Chambers)
--     SmartAIMgr: Creature 17238 Event 1 Action 53 ... id 17238, skipped.
--                                            (Anchorite Truuen)
--     ... and the same two again as 3616256 / 3617238.
--
-- This pair has been deferred since round 22 and the reason is now settled:
-- the paths exist in NEITHER `waypoints` NOR `waypoint_data` here, and neither
-- cata_world nor nelt_world has them either (all four counts are 0).  There is
-- nothing to import -- these are stock AzerothCore escorts whose path data this
-- fork has never carried.
--
-- Only the CLONE side is touched.  3616256 / 3617238 are Jessica Chambers and
-- Anchorite Truuen -- Stormwind and Draenei starting-zone NPCs that the
-- +3,600,000 sweep pulled in as collateral and that have nothing to do with
-- Hyjal.  Their two spawns and two SmartAI rows are pure clone-block noise, so
-- the WP_START rows go; without a path the action was being skipped anyway, so
-- this removes log lines rather than behaviour.
--
-- The RAW 16256 / 17238 rows are deliberately LEFT ALONE: they are stock AC
-- content, the escorts are presumably meant to work, and silencing them here
-- would hide a real gap in the base data rather than fix it.  Sourcing those
-- two paths belongs to a stock-data pass, not the Hyjal port.
DELETE FROM `smart_scripts`
WHERE `source_type` = 0
  AND `entryorguid` IN (3616256, 3617238)
  AND `action_type` = 53;

-- ---------------------------------------------------------------------------
-- WHAT IS LEFT, AND WHY IT IS NOT SQL
-- ---------------------------------------------------------------------------
--   * STILL THE DBC PUSH.  Ten lines remain that no SQL can touch:
--       No model data exist for CreatureDisplayID 38002 / 38051 / 38546 / 38547
--       Creature 3653107 lists non-existing CreatureDisplayID 30512 (crash risk)
--       Creature 3653112 lists non-existing CreatureDisplayID 38152 (crash risk)
--       Creature 3653107 / 3653112 have no existing display in creature_template_model
--       Area trigger 9861 / 9862 / 607000 / 607001 does not exist
--     Every one of those ids IS present in the local staging copies under
--     Server/data/dbc -- 30512 and 38152 were added there in round 28 and both
--     client archives already have them.  The running server is reading an older
--     dbc directory.  Push Server/data/dbc to
--     /home/wowcore/azeroth-server/data/dbc and restart; that clears all ten,
--     including the two "this can crash the client" lines, which is the highest
--     severity item still open anywhere in this port.
--
--   * NOT HYJAL, left for their own passes: AreaTrigger 6194 (Deepholm) and
--     6581 (BWD); the 4100xxx gameobject spell/lock block (retail-range GOs);
--     the item stat_type 49 block; the 173xxx/174xxx loot rows; Firelands GO
--     3802952 "Darkwhisper Lodestone" (lock 25509 sits in data1, not data0 --
--     worth a closer look before touching, since the core's message labels it
--     data0 and the two disagree).
-- ---------------------------------------------------------------------------
