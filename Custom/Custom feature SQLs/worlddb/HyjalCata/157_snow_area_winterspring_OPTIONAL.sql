-- ---------------------------------------------------------------------------
-- 157  The empty snow area -- what it is, and the source for it
-- ---------------------------------------------------------------------------
-- ***** OPT-IN. NOT registered in apply_all.sql. Read the tradeoff first. *****
--
-- QUESTION: the snow region of map 750 has no spawns at all -- is there a
-- source for it?
--
-- ANSWER: yes, and it is not a Cata source -- it is your own stock data.
--
-- WHAT THE AREA ACTUALLY IS
--   Map 750 was carved out of Kalimdor with a rectangular footprint
--   (x 3399..5771, y -4980..-1279), and that rectangle is bigger than Hyjal.
--   It swallowed the edges of the neighbouring vanilla zones.  Binning spawns
--   into 250-yard cells and diffing DC against the source shows three empty
--   corners, and stock `acore_world.creature` on map 1 still has 406 spawns
--   sitting under them:
--
--     SE corner  (x>5100, y<-4600)      46 spawns  <-- THE SNOW AREA
--        Frostmaul Giant, Frostmaul Preserver, Chillwind Ravager,
--        Winterspring Screecher, Elder Shardtooth, Berserk/Crazed/Moontouched
--        Owlbeast, Kashoch the Reaver, Ranshalla  =  WINTERSPRING
--     NW corner  (x<4100, y>-2000)      77 spawns
--        Felpaw Wolf, Angerclaw Bear, Withered/Crazed Ancient, Timbermaw NPCs
--        = Felwood / Moonglade
--     SW corner  (x<4100, y<-4200)      83 spawns
--        Timbermaw, Spitelash, Archmage Xylem = Felwood / Azshara
--     remainder of the footprint       200 spawns
--        Frostmaul Giant, Hederine line, Lorax, Antilos, Winterspring Screecher
--        = more Winterspring
--
--   So the snow is Winterspring's terrain, ported with the tiles but never
--   populated, because the spawn port filtered to Hyjal-zone creatures only.
--
-- THE TRADEOFF -- why this file is opt-in rather than part of the round
--   1. LEVEL MISMATCH.  These are vanilla level ~55-60 creatures; map 750 is
--      advertised as "Hyjal Frontier (80-130)".  The project already has a
--      rescaling mechanism (101_zone_level_bands.sql) that would need to cover
--      them, otherwise the snow area is grey trash inside an endgame zone.
--   2. DUPLICATION.  Winterspring still exists on map 1.  Importing these makes
--      a second copy of part of it, with its own Ranshalla and Kashoch the
--      Reaver -- both tied to real quests on the live continent.
--   3. It may simply be intended as scenic border terrain the player never
--      walks into, in which case the correct fix is a boundary, not spawns.
--
--   Deciding between "populate it", "rescale then populate", and "wall it off"
--   is a content-design call, so it is left to the project.
--
-- IF YOU WANT IT POPULATED, run this file.  It copies the stock map-1 spawns in
-- the footprint onto map 750 keeping the RAW entry ids (these are stock
-- creatures that already exist -- no +3,600,000 clone is needed or wanted).
-- Guids use 15,600,000+, clear of the 15,500,000 block 155_ uses.
--
-- Restrict to the snow corner only by leaving the SE filter in place; delete
-- that AND clause to bring in all four bands.
-- ---------------------------------------------------------------------------

DELETE FROM `creature` WHERE `guid` BETWEEN 15600000 AND 15699999;

INSERT INTO `creature`
  (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,
   `position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,
   `wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,
   `npcflag`,`unit_flags`,`dynamicflags`,`VerifiedBuild`)
SELECT 15600000 + ROW_NUMBER() OVER (ORDER BY c.guid),
       c.id, 750, 0, 0, 1, 1, c.equipment_id,
       c.position_x, c.position_y, c.position_z, c.orientation,
       GREATEST(c.spawntimesecs, 30),
       c.wander_distance, 0, c.curhealth, c.curmana, c.MovementType,
       0, 0, 0, 0
FROM `creature` c
WHERE c.map = 1
  AND c.position_x BETWEEN 3399 AND 5771
  AND c.position_y BETWEEN -4980 AND -1279
  AND c.position_x > 5100 AND c.position_y < -4600     -- <== snow corner only
  AND c.guid NOT BETWEEN 15600000 AND 15699999;

UPDATE `creature` SET `MovementType` = 0
WHERE `guid` BETWEEN 15600000 AND 15699999
  AND `MovementType` = 1 AND `wander_distance` = 0;
