-- =====================================================================
-- Mount Hyjal (750) + Molten Front (861) -- 101  Level/difficulty tuning
-- ---------------------------------------------------------------------
-- Design note: the zone is framed 80-130, but its authentic Cata quests are
-- level 81-85 and its mobs match. A blanket re-level to 130 would make those
-- quests uncompletable (kill-targets out of range) and there is no sub-area
-- geography on map 750 (single area 4923) to band by. So the 80-130 span is
-- carried primarily by the EXISTING mechanisms -- the hotspot XP layer (spell
-- 800001 on zone 4923) + the custom XP curve + the reward grind (token gear,
-- endgame catalogs) -- NOT by re-leveling every mob.
--
-- This file makes only the SAFE, non-quest-breaking adjustments:
--   * a modest "Cata+" difficulty bump on ELITES/RARES/BOSSES (rank>=1) so the
--     zone feels tougher than stock (health/damage/armor modifiers), leaving
--     normal quest trash (rank 0) authentic;
--   * raises the named RARES (rank 4) to a small high-end band (level 88->90)
--     as slightly-higher targets for the post-85 grind.
-- All scoped to the +3,600,000 clone range so nothing outside the zone changes.
-- TUNABLE: adjust the multipliers / level caps to taste. Idempotent.
-- =====================================================================

-- Cata+ difficulty on elites/rares/bosses (rank 1=elite, 2/3, 4=rare) in the
-- Hyjal + Plaguelands + MF clone band, only where not already boosted.
UPDATE acore_world.creature_template
SET HealthModifier = GREATEST(HealthModifier, 1.0) * 1.35,
    DamageModifier = GREATEST(DamageModifier, 1.0) * 1.20,
    ArmorModifier  = GREATEST(ArmorModifier,  1.0) * 1.15
WHERE `rank` >= 1
  AND entry BETWEEN 3600000 AND 3700000
  AND entry IN (SELECT DISTINCT id FROM acore_world.creature WHERE map IN (750,861))
  AND HealthModifier < 1.34;   -- guard: skip rows already scaled (re-run safe)

-- lift the named rares to a small high-end band for post-85 hunting
UPDATE acore_world.creature_template
SET minlevel = GREATEST(minlevel, 88), maxlevel = GREATEST(maxlevel, 90)
WHERE `rank` = 4
  AND entry BETWEEN 3600000 AND 3700000
  AND entry IN (SELECT DISTINCT id FROM acore_world.creature WHERE map IN (750,861));

-- ---------------------------------------------------------------------
-- Deliberately NOT done here (design decisions needing playtest):
--   * blanket 80-130 mob re-level (breaks the 81-85 quest kill-targets);
--   * gear RequiredLevel spread (99_ kept authentic 80-85; if the zone gets a
--     true level stretch later, spread item RequiredLevel in lockstep with the
--     mob that drops it, in this file).
-- ---------------------------------------------------------------------
