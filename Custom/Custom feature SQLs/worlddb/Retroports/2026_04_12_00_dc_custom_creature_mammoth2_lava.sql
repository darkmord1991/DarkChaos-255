-- Mammoth2Lava custom creature wiring
-- Client model path: creature\mammoth2lava\mammoth2lava.m2

DELETE FROM `creature_template_model` WHERE `CreatureID` = 3461174;
DELETE FROM `creature_template` WHERE `entry` = 3461174;
DELETE FROM `creature_model_info` WHERE `DisplayID` = 500174;

INSERT INTO `creature_model_info`
(`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
VALUES
(500174,0.62,7.00,2,0,0);

INSERT INTO `creature_template`
(`entry`,`name`,`subname`,`minlevel`,`maxlevel`,`faction`,`speed_walk`,`speed_run`,
 `unit_class`,`type`,`AIName`,`MovementType`,`RegenHealth`,`VerifiedBuild`)
VALUES
(3461174,'Mammoth2 Lava','Custom Creature Model',80,80,35,1,1.14286,1,1,'',0,1,0);

INSERT INTO `creature_template_model`
(`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
(3461174,0,500174,1,1,0);