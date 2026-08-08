-- ---------------------------------------------------------------------------
-- 273  The creature_addon layer maps 750/751/861 never got -- 5,461 spawns
-- ---------------------------------------------------------------------------
-- Found while checking why Deathwing 3639867 (guid 9845265) sits in a ground
-- pose on map 750.  His `creature_addon` row was never imported -- cata_world
-- guid 389367 has one and we had nothing.  He is not a one-off.
--
-- 🔴 THE ZONE IMPORTERS ONLY EVER WROTE `creature_addon` FOR WAYPOINT path_id.
-- Grep the folder: 159_, 172_, 176_, 202_, 230_, 257_, 30_ all touch the table
-- and every one of them writes `(guid, path_id)`.  The rest of the row -- auras,
-- stand/anim tier, sheath, emote, mount, visibility distance -- was never ported
-- at all.  Nothing warns about it at boot: an absent addon row is not an error,
-- it is just a creature with no addon.  Exactly the same shape as the
-- `spell_area` gap r23 found, and it stayed hidden for the same reason.
--
-- MEASURED: 5,461 spawns across 824 entries have a source addon row we never
-- imported -- 3,421 matched in cata_world, 2,040 only in nelt_world.
--   1,063 carry auras          834 a non-default bytes1 (stand/anim/vis)
--     517 a visibility distance  494 an emote        41 a mount
-- Only 18 of the 5,461 are all-default, and those are skipped.
--
-- HOW SPAWNS ARE MATCHED TO THEIR SOURCE.  Our importers allocated fresh guids
-- and kept no mapping, so the join is (source entry + offset, rounded x, y).
-- That is safe here because clone coordinates transfer 1:1 -- 263_ measured the
-- residual at 0.000 yd against a 1,224 yd control.  Where two source spawns of
-- one entry sit at the same rounded position, ROW_NUMBER picks deterministically
-- (cata before nelt, then lowest source guid) instead of multiplying the row.
--
-- FIELD MAPPING.  cata_world splits AC's packed `bytes1`/`bytes2` into named
-- columns, so they are re-packed here to match what `ObjectMgr::LoadCreatureAddons`
-- reads back out (Creature.cpp:2770-2774):
--     bytes1 = StandState | (VisFlags << 16) | (AnimTier << 24)
--     bytes2 = SheathState | (PvPFlags << 8)
-- nelt_world already stores AC-format bytes1/bytes2, so those pass through.
-- 🔴 nelt's `distance_visibility` is NOT `visibilityDistanceType` -- it is a raw
-- yard value, not the 0-5 enum -- so nelt rows import vdt as 0 rather than
-- feeding a yard count into an enum that only accepts 0-5.
--
-- EVERY VALUE IS PRE-VALIDATED against what the loader will accept:
--   AnimTier   0 / 2 (HOVER) / 3 (FLY)  -- all legal UNIT_BYTE1_FLAG values
--   vdt        0 / 3 / 4 / 5            -- all < VisibilityDistanceType::Max
--   emote      29 distinct              -- all 29 present in Emotes.dbc
--   mount      8 distinct               -- 7 present; 38018 handled in section 2
--   auras      125 distinct spells      -- 74 present, 51 added by 272_,
--                                          17 deliberately stripped (below)
--
-- ---- 1. the import ---------------------------------------------------------
-- 🔴 INVISIBILITY, STEALTH AND PHASE AURAS ARE STRIPPED.  17 of the 125 apply
-- SPELL_AURA_MOD_INVISIBILITY (18), MOD_STEALTH (16) or SPELL_AURA_PHASE (261):
--
--   invisibility  49414 49415 60921 65050 65316 80797 82358 83305 89303 89304
--   stealth       20540
--   phase         70696 74093 74094 74095 74096 74097
--
-- Importing them verbatim would MAKE SPAWNS DISAPPEAR.  In Cata these NPCs are
-- revealed by a detection aura granted per quest step, and by a phase system DC
-- deliberately never ported -- every map-750/751/861 spawn is forced to
-- phaseMask 1 and r23 grants the type-7/8 detectors ungated zone-wide for area
-- 4923 precisely so the questgivers stay visible.  A PHASE aura on a creature
-- calls SetPhaseMask (74096 -> 33554432), moving it out of phase 1 entirely;
-- an invisibility aura with no detector on maps 751/861 hides it outright.
--
-- So this would have been a self-inflicted repeat of the r23 bug, in reverse:
-- r23 spent a round finding nine NPCs that were invisible to everyone, and
-- importing these blind would have created hundreds more.  Stripping costs
-- nothing measurable -- those spawns are visible today (no addon = no aura), and
-- for the type-7 ones r23's blanket detector already sees through them anyway.
-- 156 rows lose their entire aura string this way; the other 907 keep real
-- cosmetic auras.
--
-- The strip is a regex over word boundaries, not a string replace, so it cannot
-- clip a substring out of a longer id and it handles runs of adjacent hazardous
-- ids ("74096 74095 74094 74093 70696" is one real value here) that a
-- space-delimited REPLACE would only half-consume.
--
-- Re-derived at apply time rather than shipped as 5,461 literals, so it stays
-- correct if spawns move.
--
-- 🔴 THERE IS DELIBERATELY NO `DELETE` BEFORE THIS INSERT, against the usual
-- house rule.  The rule exists to make a file idempotent; here the `NOT EXISTS`
-- guard on every branch already does that -- a re-run inserts zero rows -- and a
-- DELETE would be actively destructive.  `creature_addon` is a SHARED table with
-- two other kinds of owner on these maps:
--   * 187 rows carrying a waypoint `path_id` (159_, 172_, 176_, 202_, 230_,
--     257_, 30_).  Deleting one silently un-assigns a patrol route -- precisely
--     how Deepholm/41_ deleted two real routes and manufactured the errors it
--     was written to fix.
--   * 2,734 rows on map 751 with path_id = 0 that the PLAGUELANDS importer
--     wrote, 508 of them with auras.  They are already excluded by NOT EXISTS;
--     a "delete our own path_id = 0 rows first" DELETE cannot tell them apart
--     from ours and would replace another importer's decisions with mine.
-- So: insert-only, guarded, and never touching a row this file did not create.
-- To re-derive after changing the rules, delete by hand from the verify query
-- at the bottom -- do not add a blanket DELETE here.
INSERT INTO acore_world.`creature_addon`
(`guid`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`)
SELECT w.`guid`, 0, w.`mount`, w.`bytes1`, w.`bytes2`, w.`emote`, w.`vdt`,
       TRIM(REGEXP_REPLACE(REGEXP_REPLACE(COALESCE(w.`auras`,''),
            '\\b(20540|49414|49415|60921|65050|65316|70696|74093|74094|74095|74096|74097|80797|82358|83305|89303|89304)\\b', ''),
            '[[:space:]]+', ' '))
FROM (
  SELECT s.*, ROW_NUMBER() OVER (PARTITION BY s.`guid` ORDER BY s.`pri`, s.`sguid`) rn
  FROM (
    SELECT c.`guid`, 1 pri, sc.`guid` sguid, sa.`mount`,
           (sa.`AnimTier` << 24) | (sa.`VisFlags` << 16) | sa.`StandState` bytes1,
           (sa.`PvPFlags` << 8) | sa.`SheathState` bytes2,
           sa.`emote`, sa.`visibilityDistanceType` vdt, sa.`auras`
      FROM acore_world.`creature` c
      JOIN cata_world.`creature` sc ON sc.`id` = c.`id` - 3600000
       AND ROUND(sc.`position_x`,1) = ROUND(c.`position_x`,1)
       AND ROUND(sc.`position_y`,1) = ROUND(c.`position_y`,1)
      JOIN cata_world.`creature_addon` sa ON sa.`guid` = sc.`guid`
     WHERE c.`map` IN (750,751,861) AND c.`id` BETWEEN 3600000 AND 3699999
       AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_addon` a WHERE a.`guid` = c.`guid`)
    UNION ALL
    SELECT c.`guid`, 1, sc.`guid`, sa.`mount`,
           (sa.`AnimTier` << 24) | (sa.`VisFlags` << 16) | sa.`StandState`,
           (sa.`PvPFlags` << 8) | sa.`SheathState`,
           sa.`emote`, sa.`visibilityDistanceType`, sa.`auras`
      FROM acore_world.`creature` c
      JOIN cata_world.`creature` sc ON sc.`id` = c.`id` - 3700000
       AND ROUND(sc.`position_x`,1) = ROUND(c.`position_x`,1)
       AND ROUND(sc.`position_y`,1) = ROUND(c.`position_y`,1)
      JOIN cata_world.`creature_addon` sa ON sa.`guid` = sc.`guid`
     WHERE c.`map` IN (750,751,861) AND c.`id` BETWEEN 3700000 AND 3799999
       AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_addon` a WHERE a.`guid` = c.`guid`)
    UNION ALL
    SELECT c.`guid`, 2, sc.`guid`, sa.`mount`, sa.`bytes1`, sa.`bytes2`, sa.`emote`, 0, sa.`auras`
      FROM acore_world.`creature` c
      JOIN nelt_world.`creature` sc ON sc.`id` = c.`id` - 3600000
       AND ROUND(sc.`position_x`,1) = ROUND(c.`position_x`,1)
       AND ROUND(sc.`position_y`,1) = ROUND(c.`position_y`,1)
      JOIN nelt_world.`creature_addon` sa ON sa.`guid` = sc.`guid`
     WHERE c.`map` IN (750,751,861) AND c.`id` BETWEEN 3600000 AND 3699999
       AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_addon` a WHERE a.`guid` = c.`guid`)
    UNION ALL
    SELECT c.`guid`, 2, sc.`guid`, sa.`mount`, sa.`bytes1`, sa.`bytes2`, sa.`emote`, 0, sa.`auras`
      FROM acore_world.`creature` c
      JOIN nelt_world.`creature` sc ON sc.`id` = c.`id` - 3700000
       AND ROUND(sc.`position_x`,1) = ROUND(c.`position_x`,1)
       AND ROUND(sc.`position_y`,1) = ROUND(c.`position_y`,1)
      JOIN nelt_world.`creature_addon` sa ON sa.`guid` = sc.`guid`
     WHERE c.`map` IN (750,751,861) AND c.`id` BETWEEN 3700000 AND 3799999
       AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_addon` a WHERE a.`guid` = c.`guid`)
  ) s
) w
WHERE w.rn = 1
  AND NOT (w.`bytes1` = 0 AND w.`bytes2` = 0 AND w.`emote` = 0 AND w.`vdt` = 0
           AND w.`mount` = 0 AND (w.`auras` = '' OR w.`auras` IS NULL));

-- ---- 2. mount 38018 -- the one model we do not have ------------------------
-- Two Firelands vendors at the Sanctuary of Malorne, Naresir Stormfury
-- (3654401) and Lurah Wrathvine (3654402), sit on Cata mount display 38018 ->
-- model 3876 `CREATURE\PYROGRYPH\PYROGRYPH.M2`, which is in no archive of this
-- client (checked every patch-*.MPQ under the Data dir).  The loader would log
-- "has invalid displayInfoId (38018) for mount" and zero it anyway.
--
-- Repointed to 17693 (`Creature\Gryphon\Gryphon_Mount.mdx`), the generic
-- rideable gryphon, which is present in the deployed CreatureDisplayInfo.dbc.
-- Substituted rather than baked: a Cata M2 needs the v264 downport pass and the
-- payoff is a fire tint on two stationary vendors.  Same call as GO display
-- 9383 -> 9030 in 270_ and 38153 -> 38152 in MoltenFront/20_.
UPDATE acore_world.`creature_addon` SET `mount` = 17693 WHERE `mount` = 38018;

-- ---- 3. Deathwing 3639867 --------------------------------------------------
-- The spawn that started this round (guid 9845265, map 750, the Sulfuron Spire
-- overlook).  Section 1 already covers him -- cata_world guid 389367 sits at the
-- identical (3919.5, -3138.9, 1042.5) -- so this is documentation, not a second
-- write.  What he gains: AnimTier 3 (FLY) + VisFlags 1 -> bytes1 50397184, his
-- hover pose instead of a ground stance, and visibilityDistanceType 4
-- (Gigantic) so he renders as the far-off landmark he is meant to be rather
-- than popping in at normal draw distance.  His aura 49414 is stripped by the
-- rule in section 1.
--
-- NOT changed, all verified faithful to cata_world rather than broken:
--   * MovementType 0 / no AIName / no ScriptName / no smart_scripts -- he is a
--     scene prop; the looming flyby is script-driven in retail and DC has no
--     script for it.
--   * VehicleId 0 -- he is NOT a vehicle.  The vehicle-like interact cursor is
--     npcflag 16777216 (SPELLCLICK) plus the `npc_spellclick_spells` row 81_
--     backfilled, and it reaches ~100 yd because display 35268's CombatReach is
--     100 (BoundingRadius 10) -- byte-identical in nelt_world, and the only
--     reach-100 model in the DB.  Harmless in combat terms: unit_flags 256 is
--     IMMUNE_TO_PC and `Creature::CanStartAttack` (Creature.cpp:1911) returns
--     false for players against an IsImmuneToPC creature, so he never engages.

-- Verify after apply:
--   SELECT COUNT(*) FROM creature c JOIN creature_addon a ON a.guid=c.guid
--    WHERE c.map IN (750,751,861);                        -> +5,443 (5,461 - 18)
--   SELECT COUNT(*) FROM creature_addon WHERE mount = 38018;               -> 0
--   SELECT guid, bytes1, visibilityDistanceType, auras
--     FROM creature_addon WHERE guid = 9845265;
--        -> 9845265 | 50397184 | 4 | ''      (Deathwing hovering, long-range)
--   SELECT COUNT(*) FROM creature_addon
--    WHERE auras REGEXP '\\b(20540|49414|49415|60921|65050|65316|70696|74093|74094|74095|74096|74097|80797|82358|83305|89303|89304)\\b';
--        -> 0   (nothing imported can hide or phase a spawn)
--   boot log: no "has wrong spell", no "invalid displayInfoId ... for mount",
--   no "invalid emote", no "invalid visibilityDistanceType".
