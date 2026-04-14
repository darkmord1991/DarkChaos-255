-- Additional custom creature wiring from MPQ Creature/* assets
-- Client model path:
--   creature\maldraxxusskeleton\maldraxxusskeleton.m2

DELETE FROM `creature_template_model`
WHERE `CreatureID` IN (3461192);

DELETE FROM `creature_template`
WHERE `entry` IN (3461192);

DELETE FROM `creature_model_info`
WHERE `DisplayID` IN (500192);

INSERT INTO `creature_model_info`
(`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
VALUES
(500192,1.00,2.20,2,0,0);

INSERT INTO `creature_template`
(`entry`,`name`,`subname`,`minlevel`,`maxlevel`,`faction`,`speed_walk`,`speed_run`,
 `unit_class`,`type`,`AIName`,`MovementType`,`RegenHealth`,`VerifiedBuild`)
VALUES
(3461192,'Maldraxxus Skeleton','Custom Creature Model',83,83,35,1,1.14286,1,6,'',0,1,0);

INSERT INTO `creature_template_model`
(`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
(3461192,0,500192,1,1,0);
