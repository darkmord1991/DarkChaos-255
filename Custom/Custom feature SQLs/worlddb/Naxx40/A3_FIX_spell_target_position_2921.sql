-- =====================================================================
-- FIX: spell_target_position rows still pointing at map 533
-- =====================================================================
-- Symptom in the log:
--   Spell::EffectTeleportUnits - spellId 29231 attempted to teleport
--   creature to a different map.
--
-- `spell_target_position` stores an ABSOLUTE map id and there is exactly one
-- row per (ID, EffectIndex). Naxx-40 now runs on 2921 while these rows still
-- say 533. SpellEffects.cpp:1225-1242 then splits two ways:
--
--   creature target -> logged error, NOTHING happens (boss never moves)
--   PLAYER  target -> `ToPlayer()->TeleportTo(mapid, ...)` actually fires,
--                     so the player is thrown OUT of the 40-man and into
--                     stock WotLK Naxxramas on map 533.
--
-- This file fixes only the two rows that are safe to repoint. The other five
-- are shared with core's Naxxramas scripts and need a code-side fix - see the
-- bottom of this file.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Spell 29273 - Heigan "teleport players"   [THE URGENT ONE]
--    Verified unused by core: grep over src/server/scripts and
--    src/server/game finds it ONLY in DC/Naxx40/boss_heigan_40.cpp.
--    boss_heigan_40.cpp:273 does target->CastSpell(target, 29273) on a
--    PLAYER, so while this row says 533 it EJECTS raiders into stock Naxx.
--    Coordinates are the ones the module intended (its own UPDATE was
--    disabled by the stock-533 guard, which was over-cautious here because
--    the spell is not shared).
-- ---------------------------------------------------------------------
DELETE FROM `spell_target_position` WHERE `ID` = 29273;
INSERT INTO `spell_target_position`
  (`ID`, `EffectIndex`, `MapID`, `PositionX`, `PositionY`, `PositionZ`, `Orientation`, `VerifiedBuild`)
VALUES
  (29273, 0, 2921, 2917.43, -3769.18, 273.62, 3.1415, 0);

-- ---------------------------------------------------------------------
-- 2. Spell 90003 - Sewage Slime summon, a module-owned spell (90001-90008)
--    `05_naxx40_spells.sql` inserts it with MapID 533 because upstream targets
--    map 533. Nothing else uses it, so repoint outright.
-- ---------------------------------------------------------------------
DELETE FROM `spell_target_position` WHERE `ID` = 90003;
INSERT INTO `spell_target_position`
  (`ID`, `EffectIndex`, `MapID`, `PositionX`, `PositionY`, `PositionZ`, `Orientation`, `VerifiedBuild`)
VALUES
  (90003, 0, 2921, 3128.96, -3312.96, 293.25, 0.0, 0);

-- ---------------------------------------------------------------------
-- 3. Verification
-- ---------------------------------------------------------------------
-- SELECT ID, MapID, PositionX, PositionY, PositionZ FROM spell_target_position
--   WHERE ID IN (29273, 90003);            -- both must read MapID 2921

-- =====================================================================
-- STILL BROKEN - needs a code change, NOT SQL
-- =====================================================================
-- These five are cast by BOTH core's Naxxramas scripts (map 533) and the _40
-- copies (map 2921). One row cannot serve both maps, so repointing them here
-- would break stock Naxxramas instead:
--
--   29216  Noth   - teleport up to balcony      (core boss_noth.cpp)
--   29231  Noth   - teleport back down          (core boss_noth.cpp)   <- your log line
--   28025  Gothik - teleport to dead side       (core boss_gothik.cpp)
--   28026  Gothik - teleport to live side       (core boss_gothik.cpp)
--   30211  Heigan - teleport self               (core boss_heigan.cpp)
--
-- All five are `me->CastSpell(me, X, true)` self-teleports, so on 2921 they
-- log the error and the boss simply does not move: Noth never returns from the
-- balcony and Gothik never switches sides. Both encounters stall.
--
-- Recommended fix (small, no new DBC data): in the _40 scripts ONLY, replace
-- the self-cast with `me->NearTeleportTo(x, y, z, o)` using the SAME
-- coordinates the row already holds - maps 533 and 2921 share one coordinate
-- space (identical WMO origin), so only the map id was ever wrong:
--
--   29216 -> 2631.03, -3529.61, 274.16
--   29231 -> 2684.80, -3502.52, 261.31
--   28025 -> 2693.00, -3321.00, 268.00
--   28026 -> 2706.00, -3412.00, 268.00
--   30211 -> 2794.00, -3707.00, 277.00
--
-- The alternative - cloning all five into the module's spell_dbc band with
-- 2921 target rows - keeps the spell visuals but costs 5 spell_dbc rows,
-- 5 spell_target_position rows, C++ constant changes in three files and a
-- rebuild. Decide which before editing.
--
-- NOTE: 29237 (Noth, Summon Plagued Warriors) also has a map-533 row but is a
-- SUMMON, not a teleport - it does not go through EffectTeleportUnits and its
-- position resolves on the caster's own map, so it is NOT affected.
