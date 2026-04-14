-- Additional custom creature wiring from MPQ Creature/* assets
-- Client model paths:
--   creature\drustmonster\drustmonster.m2
--   creature\ladyvashjshadowlands\ladyvashjshadowlands.m2
--   creature\lichlord\lichlord.m2

DELETE FROM `creature_template_model`
WHERE `CreatureID` IN (3461189,3461190,3461191);

DELETE FROM `creature_template`
WHERE `entry` IN (3461189,3461190,3461191);

DELETE FROM `creature_model_info`
WHERE `DisplayID` IN (500189,500190,500191);

INSERT INTO `creature_model_info`
(`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
VALUES
(500189,0.85,2.00,2,0,0),
(500190,0.90,2.00,2,0,0),
(500191,1.10,2.50,2,0,0);

INSERT INTO `creature_template`
(`entry`,`name`,`subname`,`minlevel`,`maxlevel`,`faction`,`speed_walk`,`speed_run`,
 `unit_class`,`type`,`AIName`,`MovementType`,`RegenHealth`,`VerifiedBuild`)
VALUES
(3461189,'Drust Monster','Custom Creature Model',83,83,35,1,1.14286,1,6,'',0,1,0),
(3461190,'Lady Vashj Shadowlands','Custom Creature Model',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461191,'Lich Lord','Custom Creature Model',83,83,35,1,1.14286,1,6,'',0,1,0);

INSERT INTO `creature_template_model`
(`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
(3461189,0,500189,1,1,0),
(3461190,0,500190,1,1,0),
(3461191,0,500191,1,1,0);
