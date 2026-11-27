-- =====================================================================
-- DB REVIEW FIX: Flying NPCs lost their InhabitType/Flight on downport
-- Maps 750 (Mount Hyjal) + 751 (Plaguelands), cloned entries (entry>=3600000)
-- =====================================================================
-- ROOT CAUSE
--   AzerothCore stores InhabitType as acore_world.creature_template_movement
--   (Ground/Swim/Flight). The clone step (dc_entry = orig+3,600,000) copied
--   creature_template but created ZERO creature_template_movement rows for any
--   entry>=3600000 (verified: COUNT=0). The cata_world (TDB 434) SOURCE has NO
--   Flight/InhabitType column at all (creature_template_movement there is only
--   CreatureId,HoverInitiallyEnabled,Random), so the downport had nothing to
--   copy. Result: every flying clone defaults to ground movement and will sink
--   to the floor when given air movement / fail aerial pathing.
--
-- GROUND TRUTH USED
--   Bucket A: the orig entry already exists in THIS acore_world with
--             creature_template_movement.Flight>0  -> copy that row verbatim.
--   Bucket B: orig has no acore stock movement row, but nelt_world (4.3.4,
--             real InhabitType column) marks it air-capable with InhabitType
--             IN (4,5,6,7) i.e. the strong "Both/Air" bit 0x4 set. (We DELIBERATELY
--             exclude bare InhabitType=2/3 which are the TrinityCore *default*
--             ~43k rows and are NOT reliable flight signals -> would falsely
--             lift ~7,600 ground spawns.)
--
-- IMPACT: ~50 flying templates / ~800 spawns fixed. Idempotent (NOT EXISTS guard).
-- Apply to acore_world. Reload: creature_template_movement (+ server restart or
--   .reload creature_template_movement) so spawns pick it up.
-- =====================================================================

-- ---------------------------------------------------------------------
-- BUCKET A: clone whose acore-stock original (entry-3600000) has Flight>0.
--           Copy Ground/Swim/Flight/Rooted/Chase/Random/InteractionPauseTimer.
--           8 templates / ~54 spawns.
-- ---------------------------------------------------------------------
INSERT INTO acore_world.creature_template_movement
    (CreatureId, Ground, Swim, Flight, Rooted, Chase, Random, InteractionPauseTimer)
SELECT DISTINCT
    cl.entry, sm.Ground, sm.Swim, sm.Flight, sm.Rooted, sm.Chase, sm.Random, sm.InteractionPauseTimer
FROM acore_world.creature c
JOIN acore_world.creature_template cl
     ON cl.entry = c.id
JOIN acore_world.creature_template_movement sm
     ON sm.CreatureId = cl.entry - 3600000
WHERE c.map IN (750,751)
  AND cl.entry >= 3600000
  AND sm.Flight > 0
  AND NOT EXISTS (
      SELECT 1 FROM acore_world.creature_template_movement cm
      WHERE cm.CreatureId = cl.entry
  );

-- ---------------------------------------------------------------------
-- BUCKET B: clone with no acore stock movement row, but nelt InhabitType
--           has the air/both bit (InhabitType IN (4,5,6,7)).
--           Derive: Ground = InhabitType & 1 ; Swim = (InhabitType>>3)&1 ;
--                   Flight = 1 (air-capable). 42 templates / ~748 spawns.
-- ---------------------------------------------------------------------
INSERT INTO acore_world.creature_template_movement
    (CreatureId, Ground, Swim, Flight, Rooted, Chase, Random, InteractionPauseTimer)
SELECT DISTINCT
    cl.entry,
    (n.InhabitType & 1)        AS Ground,
    ((n.InhabitType >> 3) & 1) AS Swim,
    1                          AS Flight,
    0 AS Rooted, 0 AS Chase, 0 AS Random, 0 AS InteractionPauseTimer
FROM acore_world.creature c
JOIN acore_world.creature_template cl
     ON cl.entry = c.id
JOIN nelt_world.creature_template n
     ON n.entry = cl.entry - 3600000
WHERE c.map IN (750,751)
  AND cl.entry >= 3600000
  AND n.InhabitType IN (4,5,6,7)
  AND NOT EXISTS (
      SELECT 1 FROM acore_world.creature_template_movement cm
      WHERE cm.CreatureId = cl.entry
  )
  AND NOT EXISTS (
      SELECT 1 FROM acore_world.creature_template_movement sm2
      WHERE sm2.CreatureId = cl.entry - 3600000
  );

-- =====================================================================
-- OPTIONAL / NEEDS-DECISION (NOT executed above):
--   InhabitType=3 (Ground+Air, the global default) clones number ~625 templates
--   /7,661 spawns. Most are NOT real flyers. If specific named flyers among them
--   are observed sinking in-game (e.g. a gryphon whose nelt row is InhabitType=3),
--   add them explicitly by entry rather than blanket-lifting InhabitType=3.
-- =====================================================================
