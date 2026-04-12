-- OnyxiaUndead custom creature wiring
-- Client model path: creature\onyxiaundead\onyxiaundead.m2

DELETE FROM `creature_template_model` WHERE `CreatureID` = 3461175;
DELETE FROM `creature_template` WHERE `entry` = 3461175;
DELETE FROM `creature_model_info` WHERE `DisplayID` = 500175;

INSERT INTO `creature_model_info`
(`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
VALUES
(500175,1.80,18.00,2,0,0);

INSERT INTO `creature_template`
(`entry`,`name`,`subname`,`minlevel`,`maxlevel`,`faction`,`speed_walk`,`speed_run`,
 `unit_class`,`type`,`AIName`,`MovementType`,`RegenHealth`,`VerifiedBuild`)
VALUES
(3461175,'Onyxia Undead','Custom Creature Model',83,83,35,1,1.14286,1,2,'',0,1,0);

INSERT INTO `creature_template_model`
(`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
(3461175,0,500175,1,1,0);