-- Camel custom creature wiring
-- Client model path: creature\camel\camelmount.m2

DELETE FROM `creature_template_model` WHERE `CreatureID` = 3461176;
DELETE FROM `creature_template` WHERE `entry` = 3461176;
DELETE FROM `creature_model_info` WHERE `DisplayID` = 500176;

INSERT INTO `creature_model_info`
(`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
VALUES
(500176,0.75,2.50,2,0,0);

INSERT INTO `creature_template`
(`entry`,`name`,`subname`,`minlevel`,`maxlevel`,`faction`,`speed_walk`,`speed_run`,
 `unit_class`,`type`,`AIName`,`MovementType`,`RegenHealth`,`VerifiedBuild`)
VALUES
(3461176,'Camel Mount','Custom Creature Model',80,80,35,1,1.14286,1,1,'',0,1,0);

INSERT INTO `creature_template_model`
(`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
(3461176,0,500176,1,1,0);
