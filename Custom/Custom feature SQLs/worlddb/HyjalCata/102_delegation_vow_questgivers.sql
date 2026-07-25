-- =====================================================================
-- Mount Hyjal (map 750) -- 102  Spawn the Delegation / Elemental Bonds givers
-- ---------------------------------------------------------------------
-- HyjalCata/75 imported the two Thrall/Aggra betrothal quests and 77 imported
-- the 4-line scene text, but their questgiver TEMPLATES were never spawned, so
-- a live audit found both quests unreachable (no giver on any map):
--   29234 "Delegation"                -- start + end: Kalecgos (3652995 / 3653009)
--   29331 "Elemental Bonds: The Vow"  -- end: Thrall (3654168)
--
-- Placement: this scene happens at NORDRASSIL ON HYJAL, not in the Molten Front.
-- nelt_world spawns these on its map 1 (retail Kalimdor Hyjal) at coordinates
-- that fall inside map 750's footprint (X[3399,5770] Y[-4979,-1280], terrain
-- z ~1570 there), and this downport is coordinate-preserving, so the nelt map-1
-- positions drop straight in:
--   Kalecgos  52995 -> 5544.33, -3564.99, 1570.07  o 3.793
--   Thrall    54168 -> 5351.19, -3485.84, 1569.85  o 4.817
-- The 29234 ENDER is a second Kalecgos variant (53009) whose only nelt spawn is
-- in Dalaran (map 571); it is co-located with 52995 here (+3 yd) so the quest can
-- be handed in where it was taken.
--
-- Guid block 15,320,000+ -- above every existing block and outside all other
-- files' delete ranges. Idempotent.
-- =====================================================================

DELETE FROM `creature` WHERE `guid` BETWEEN 15320000 AND 15320099;
INSERT INTO `creature`
(`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`dynamicflags`,`ScriptName`,`VerifiedBuild`,`CreateObject`,`Comment`)
SELECT 15320000 + ROW_NUMBER() OVER (ORDER BY x.id), x.id, 750, 4923, 4923, 1, 1, -1,
       x.px, x.py, x.pz, x.po, 300, 0, 0, 1, 1, 0,
       ct.npcflag, ct.unit_flags, 0, '', 0, 0, 'Hyjal-DelegationVow'
FROM (
  SELECT 3652995 AS id, 5544.33 AS px, -3564.99 AS py, 1570.07 AS pz, 3.793 AS po   -- Kalecgos (starts 29234)
  UNION ALL SELECT 3653009, 5547.10, -3562.40, 1570.07, 3.793                       -- Kalecgos variant (ends 29234)
  UNION ALL SELECT 3654168, 5351.19, -3485.84, 1569.85, 4.817                       -- Thrall (ends 29331)
) x
JOIN `creature_template` ct ON ct.`entry` = x.id;

-- 29331 has an ender (Thrall) but no STARTER anywhere: in Cata it is offered by
-- the preceding chain step, so leave the start relation to the chain rather than
-- inventing a giver. Verify in-world once 29234 is completable.
