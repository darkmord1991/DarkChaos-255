-- Additional custom mount creature wiring from MPQ Creature/* assets
-- Client model paths:
--   creature\chimerafiremount\chimerafiremount.m2
--   creature\crocsunmount\crocsunmount.m2
--   creature\geargrindermount\geargrindermount.m2
--   creature\gianteagle2hexmount\gianteagle2hexmount.m2
--   creature\stormcrowmount_fel\stormcrowmount_fel.m2
--
-- chimerafiremount is exposed as 4 display variants (yellow/blue/green/red).

DELETE FROM `creature_template_model`
WHERE `CreatureID` IN (3461181,3461182,3461183,3461184,3461185,3461186,3461187,3461188);

DELETE FROM `creature_template`
WHERE `entry` IN (3461181,3461182,3461183,3461184,3461185,3461186,3461187,3461188);

DELETE FROM `creature_model_info`
WHERE `DisplayID` IN (500181,500182,500183,500184,500185,500186,500187,500188);

INSERT INTO `creature_model_info`
(`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
VALUES
(500181,1.20,2.60,2,0,0),
(500182,1.20,2.60,2,0,0),
(500183,1.20,2.60,2,0,0),
(500184,1.20,2.60,2,0,0),
(500185,1.10,2.40,2,0,0),
(500186,1.25,2.50,2,0,0),
(500187,1.30,2.70,2,0,0),
(500188,1.20,2.50,2,0,0);

INSERT INTO `creature_template`
(`entry`,`name`,`subname`,`minlevel`,`maxlevel`,`faction`,`speed_walk`,`speed_run`,
 `unit_class`,`type`,`AIName`,`MovementType`,`RegenHealth`,`VerifiedBuild`)
VALUES
(3461181,'Chimera Firemount Yellow','Custom Creature Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461182,'Chimera Firemount Blue','Custom Creature Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461183,'Chimera Firemount Green','Custom Creature Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461184,'Chimera Firemount Red','Custom Creature Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461185,'Crocsun Mount','Custom Creature Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461186,'Geargrinder Mount','Custom Creature Model',80,80,35,1,1.14286,1,9,'',0,1,0),
(3461187,'Giant Eagle Hexmount','Custom Creature Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461188,'Fel Stormcrow Mount','Custom Creature Model',80,80,35,1,1.14286,1,1,'',0,1,0);

INSERT INTO `creature_template_model`
(`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
(3461181,0,500181,1,1,0),
(3461182,0,500182,1,1,0),
(3461183,0,500183,1,1,0),
(3461184,0,500184,1,1,0),
(3461185,0,500185,1,1,0),
(3461186,0,500186,1,1,0),
(3461187,0,500187,1,1,0),
(3461188,0,500188,1,1,0);
