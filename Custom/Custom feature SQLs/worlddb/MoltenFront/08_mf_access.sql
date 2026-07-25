-- =====================================================================
-- Molten Front -- 08  Access: GM teleports + VISIBLE portal markers
-- ---------------------------------------------------------------------
-- 04_mf_portal.sql created the working walk-in teleports
--   9861: map 750 (4620,-2090,1237) -> map 861 hub (1021,394,42)
--   9862: map 861 hub               -> map 750
-- ...but an areatrigger is INVISIBLE and only 5 yd wide, so without a marker
-- nobody can find it, and there was no `game_tele` row for map 861 at all
-- (so not even `.tele` worked). This file fixes both.
--
-- Placement is good: the map-750 end sits in the live Hyjal assault hub -- 113
-- NPCs within 125 yd incl. Malfurion Stormrage, Arch Druid Hamuul Runetotem,
-- Captain Saynna Stormrunner, Skylord Omnuron, Tortolla and Leyara -- and the
-- map-861 end is the Molten Front staging camp (23 NPCs nearby).
--
-- Marker GO 3803083 "The Manipulator's Portal Spell Effect (Fire)" (type 5 =
-- visual only, display 9081 SPELLS\InstanceNewPortal_Red.mdx -- verified present
-- client-side). Type 5 needs no interaction: walking into the co-located
-- areatrigger does the teleport, the GO just shows you where.
--
-- Guid block 15,330,000+ (free, outside every other file's delete range).
-- game_tele ids 10621-10622 (live max was 10620). Idempotent.
-- =====================================================================

-- ---------------- GM / admin teleports ----------------
DELETE FROM `game_tele` WHERE `id` IN (10621,10622);
INSERT INTO `game_tele` (`id`,`position_x`,`position_y`,`position_z`,`orientation`,`map`,`name`) VALUES
(10621, 1021.0,  394.0,   42.2, 5.64, 861, 'moltenfront'),
(10622, 4620.0, -2090.0, 1237.0, 3.14, 750, 'hyjalmfportal');

-- ---------------- visible portal markers at both ends ----------------
DELETE FROM `gameobject` WHERE `guid` BETWEEN 15330000 AND 15330099;
INSERT INTO `gameobject`
(`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`position_x`,`position_y`,`position_z`,`orientation`,`rotation0`,`rotation1`,`rotation2`,`rotation3`,`spawntimesecs`,`animprogress`,`state`,`ScriptName`,`VerifiedBuild`,`Comment`)
SELECT 15330000 + ROW_NUMBER() OVER (ORDER BY x.map), 3803083, x.map, x.zone, x.zone, 1, 1,
       x.px, x.py, x.pz, x.po, 0, 0, 0, 1, -1, 0, 1, '', 0, 'MoltenFront-PortalMarker'
FROM (
  SELECT 750 AS map, 4923 AS zone, 4620.0 AS px, -2090.0 AS py, 1237.0 AS pz, 3.14 AS po  -- Hyjal -> MF
  UNION ALL
  SELECT 861, 4925, 1021.0, 394.0, 42.2, 5.64                                             -- MF -> Hyjal
) x
WHERE EXISTS (SELECT 1 FROM `gameobject_template` WHERE `entry`=3803083);

-- ---------------------------------------------------------------------
-- How to get to the Molten Front (summary):
--   1. `.tele moltenfront`                      -- GM/admin, straight to the hub
--   2. walk into the fire portal in the Hyjal assault hub (map 750, ~4620,-2090)
--   3. `.tele hyjalmfportal` puts you next to the Hyjal-side portal
-- The return portal stands in the Molten Front camp (map 861, ~1021,394).
--
-- NOTE both walk-in portals need client `AreaTrigger.dbc` rows 9861/9862 --
-- already added to Custom/CSV DBC/AreaTrigger.csv, recompiled and deployed.
-- A flightmaster / breadcrumb quest could be added later for discoverability.
-- ---------------------------------------------------------------------
