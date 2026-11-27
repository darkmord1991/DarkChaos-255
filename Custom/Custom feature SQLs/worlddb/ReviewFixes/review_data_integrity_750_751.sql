-- ============================================================================
-- DB REVIEW: Data-integrity errors for downported maps 750 (Mount Hyjal) and
-- 751 (Plaguelands). Target: acore_world. Clones use entry = original + 3,600,000.
-- Read-only review output; APPLY MANUALLY after verification.
-- ============================================================================
--
-- SUMMARY OF WHAT WAS CHECKED (all on acore_world):
--   * Orphan creature/GO spawns (no template) ............ 0  (CLEAN)
--   * Clone templates missing creature_template_model .... 0  (CLEAN, all 690 OK)
--   * Clone templates / GO with displayId 0 .............. 0  (CLEAN)
--   * gossip_menu_id -> missing gossip_menu .............. 0  (CLEAN)
--   * creature/GO queststarter/ender -> missing quest .... 0  (CLEAN)
--   * smart_scripts broken links / missing summon refs ... 0  (CLEAN)
--   * Double apply_all (spawn doubling) .................. NONE
--         (Hyjal zone616: cata=4928 == acore map750=4928; stacked spawns are
--          source-faithful, e.g. Charred Invader 30==30 at one point.)
--
-- REAL FINDINGS THAT PRODUCE WORLDSERVER ERRORS / BROKEN BEHAVIOR:
--   [A] 61 creatures with MovementType=2 (WAYPOINT) but NO path assigned
--       (no creature_addon.path_id, no creature_movement_override).  map750=48, map751=13.
--       -> worldserver logs "has wrong waypoint id / no path" and they stand still.
--   [B]  2 creatures with MovementType=3 (invalid for AzerothCore spawns; valid 0/1/2).
--       -> logs "wrong spawn movement type", clamped to IDLE.
--   [C]  2 GO templates AIName='SmartGameObjectAI' with no source_type=1 smart_scripts
--       (3775432 '', 3775925 'Outhouse') -> "GO has SmartGameObjectAI but no scripts" warn.
--   [D]  3 creature templates AIName='SmartAI' with no scripts
--       (3623033 Invisible Stalker, 3635845/3638821 Dave's bunny) -> benign load warn.
--       NOTE: stock entry 23033 is ALSO SmartAI/no-script, so this is source-faithful, low sev.
--   [E]  5 smart_scripts target_type=11 (CREATURE_GUID) on clone entries whose target_param1
--       (38915, 40229, 38915, 40229) are cata creature ENTRIES, not acore spawn GUIDs ->
--       the action (ATTACK_START) silently finds no target. Soft failure, needs manual remap.
--
-- ROOT CAUSE of [A]: cata waypoint paths are keyed by GUID (creature_addon.waypointPathId
-- + waypoint_data). The clone got FRESH acore GUIDs, so the per-GUID path mapping was lost
-- and creature_addon rows were never generated (0 addon rows exist for maps 750/751).
-- A proper fix re-ports cata waypoint_data under new path ids + writes creature_addon.path_id
-- (downport tooling job). The SQL below is a SAFE STOP-GAP that silences the errors and gives
-- the NPCs motion until paths are ported.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- FIX [A]+[B] (STOP-GAP): demote pathless WAYPOINT (2) and invalid (3) movers to
-- RANDOM (1). Removes the "no path / wrong movement type" error spam and lets them
-- wander instead of standing still. Re-run waypoint port later to restore patrols.
-- Guarded so it only touches spawns that truly lack a path.
-- ----------------------------------------------------------------------------
UPDATE acore_world.creature c
SET c.MovementType = 1,
    c.wander_distance = IF(c.wander_distance > 0, c.wander_distance, 5)
WHERE c.map IN (750,751)
  AND c.MovementType IN (2,3)
  AND NOT EXISTS (SELECT 1 FROM acore_world.creature_addon a
                  WHERE a.guid = c.guid AND a.path_id > 0)
  AND NOT EXISTS (SELECT 1 FROM acore_world.creature_movement_override mo
                  WHERE mo.SpawnId = c.guid);
-- Expected affected rows: 63 (48 map750 wp + 13 map751 wp + 2 map750 mt=3).


-- ----------------------------------------------------------------------------
-- FIX [C]: 2 GO templates flagged SmartGameObjectAI but carrying no script.
-- Neither does anything; clear the AIName to stop the load warning. (Both are
-- passive props: an unnamed GO and an 'Outhouse'.)
-- ----------------------------------------------------------------------------
UPDATE acore_world.gameobject_template gt
SET gt.AIName = ''
WHERE gt.entry IN (3775432, 3775925)
  AND gt.AIName = 'SmartGameObjectAI'
  AND NOT EXISTS (SELECT 1 FROM acore_world.smart_scripts s
                  WHERE s.entryorguid = gt.entry AND s.source_type = 1);
-- Expected affected rows: 2.


-- ----------------------------------------------------------------------------
-- FIX [D] (OPTIONAL, low severity): clone creatures flagged SmartAI with no script.
-- Faithful to stock for 23033; harmless warning. Only clear if the warning bothers you.
-- 3635845 / 3638821 are Cata-new bunnies with no behavior either.
-- ----------------------------------------------------------------------------
-- UPDATE acore_world.creature_template
-- SET AIName = ''
-- WHERE entry IN (3623033, 3635845, 3638821)
--   AND AIName = 'SmartAI'
--   AND NOT EXISTS (SELECT 1 FROM acore_world.smart_scripts s
--                   WHERE s.entryorguid = entry AND s.source_type = 0);


-- ----------------------------------------------------------------------------
-- FINDING [E]: NEEDS MANUAL DECISION - do NOT auto-apply.
-- 5 smart_scripts rows below use target_type=11 (SMART_TARGET_CREATURE_GUID) but
-- target_param1 holds a cata ENTRY (38915, 40229), not an acore spawn GUID, so the
-- ATTACK_START action no-ops. Correct fix = repoint to the cloned entry's nearest-spawn
-- (target_type=19 closest_creature with target_param1 = entry+3600000), or to the real
-- new GUID. Listed for manual review:
--   entryorguid 3638913 id1  target_param1 38915  -> intended creature 38915 (clone 3638915)
--   entryorguid 3638915 id1  target_param1 40229  -> intended creature 40229 (clone 3640229)
--   entryorguid 3638926 id4  target_param1 38915  -> intended creature 38915 (clone 3638915)
--   entryorguid 3643427 id3  target_param1 40229  -> intended creature 40229 (clone 3640229)
-- (5th row shares one of the above.) Suggested rewrite per row (example, verify each):
--   UPDATE acore_world.smart_scripts SET target_type=19, target_param1=3638915, target_param2=40
--   WHERE entryorguid=3638913 AND source_type=0 AND id=1;
-- ============================================================================
