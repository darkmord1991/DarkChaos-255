-- ==============================================================================
-- Legion Dalaran (map 1413) portal room: functional capital portals.
-- Stock "Portal to X" gameobjects are type 22 (SPELLCASTER) with the teleport spell in Data0,
-- so they teleport on click with no script. Placed in a row in the verified portal alcove
-- (~x952..984, y1041, z524.71). Generic entries chosen (NOT the 191009-191014 set the flavor
-- cleanup removes), so re-running cleanup never deletes these.
-- ==============================================================================

DELETE FROM `gameobject` WHERE `guid` BETWEEN 9602001 AND 9602009;
INSERT INTO `gameobject`
  (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,
   `position_x`,`position_y`,`position_z`,`orientation`,`rotation0`,`rotation1`,`rotation2`,`rotation3`,
   `spawntimesecs`,`animprogress`,`state`,`ScriptName`,`VerifiedBuild`,`Comment`)
VALUES
  (9602001,176296,1413,0,0,1,1, 952,1041,524.71,1.9, 0,0,0.81342,0.58175, 300,100,1,'',0,'Legion Dalaran Portal'), -- Stormwind
  (9602002,176497,1413,0,0,1,1, 956,1041,524.71,1.9, 0,0,0.81342,0.58175, 300,100,1,'',0,'Legion Dalaran Portal'), -- Ironforge
  (9602003,176498,1413,0,0,1,1, 960,1041,524.71,1.9, 0,0,0.81342,0.58175, 300,100,1,'',0,'Legion Dalaran Portal'), -- Darnassus
  (9602004,182351,1413,0,0,1,1, 964,1041,524.71,1.9, 0,0,0.81342,0.58175, 300,100,1,'',0,'Legion Dalaran Portal'), -- Exodar
  (9602005,183384,1413,0,0,1,1, 968,1041,524.71,1.9, 0,0,0.81342,0.58175, 300,100,1,'',0,'Legion Dalaran Portal'), -- Shattrath
  (9602006,176499,1413,0,0,1,1, 972,1041,524.71,1.9, 0,0,0.81342,0.58175, 300,100,1,'',0,'Legion Dalaran Portal'), -- Orgrimmar
  (9602007,176500,1413,0,0,1,1, 976,1041,524.71,1.9, 0,0,0.81342,0.58175, 300,100,1,'',0,'Legion Dalaran Portal'), -- Thunder Bluff
  (9602008,176501,1413,0,0,1,1, 980,1041,524.71,1.9, 0,0,0.81342,0.58175, 300,100,1,'',0,'Legion Dalaran Portal'), -- Undercity
  (9602009,182352,1413,0,0,1,1, 984,1041,524.71,1.9, 0,0,0.81342,0.58175, 300,100,1,'',0,'Legion Dalaran Portal'); -- Silvermoon
