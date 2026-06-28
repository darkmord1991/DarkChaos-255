-- ==============================================================================
-- Legion Dalaran (map 1413) ambiance: Minigob Manabonk prank NPC
-- Dedicated entry 800050 driven by the map-based DC script 'npc_dc_manabonk'
-- (stock 32838 keeps its zone-based AI for Northrend Dalaran). Display 28315 = stock Minigob.
-- ==============================================================================

DELETE FROM `creature_template_model` WHERE `CreatureID` = 800050;
DELETE FROM `creature_template` WHERE `entry` = 800050;
INSERT INTO `creature_template`
  (`entry`,`name`,`subname`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`unit_class`,
   `unit_flags`,`type`,`AIName`,`MovementType`,`RegenHealth`,`ScriptName`,`VerifiedBuild`)
VALUES
  (800050,'Minigob Manabonk','',80,80,2,35,0,1,770,7,'',0,1,'npc_dc_manabonk',0);

INSERT INTO `creature_template_model`
  (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
  (800050,0,28315,1,1,0);

-- one spawn on 1413 near the central fountain (it teleports around the instance on its own)
DELETE FROM `creature` WHERE `guid` = 9502000;
INSERT INTO `creature`
  (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,
   `position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,
   `currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`dynamicflags`,
   `ScriptName`,`VerifiedBuild`,`CreateObject`,`Comment`)
VALUES
  (9502000,800050,1413,0,0,1,1,0,1100.78,1079.39,531.86,0,300,0,0,1,0,0,0,0,0,'',0,0,'Legion Dalaran Manabonk');
