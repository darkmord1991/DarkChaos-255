-- Additional Creature retroports from MPQ Creature/* assets
-- Client model paths:
--   creature\azsharanaga\azsharanaga.m2
--   creature\mountaingiantcrystal\mountaingiantcrystal_boss.m2
--   creature\mountaingiantnorthrend\mountaingiant_howling.m2
--
-- Texture dependencies for MountainGiant_Howling are expected in:
--   creature\elementalearth\watermist.blp
--   creature\mountaingiantoutland\tumblingrock.blp

DELETE FROM `creature_template_model`
WHERE `CreatureID` IN (3461178,3461179,3461180);

DELETE FROM `creature_template`
WHERE `entry` IN (3461178,3461179,3461180);

DELETE FROM `creature_model_info`
WHERE `DisplayID` IN (500178,500179,500180);

INSERT INTO `creature_model_info`
(`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
VALUES
(500178,1.00,1.50,2,0,0),
(500179,0.75,5.00,2,0,0),
(500180,0.495,4.125,0,0,0);

INSERT INTO `creature_template`
(`entry`,`name`,`subname`,`minlevel`,`maxlevel`,`faction`,`speed_walk`,`speed_run`,
 `unit_class`,`type`,`AIName`,`MovementType`,`RegenHealth`,`VerifiedBuild`)
VALUES
(3461178,'Azshara Naga','Custom Creature Model',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461179,'Mountain Giant Crystal Boss','Custom Creature Model',83,83,35,1,1.14286,1,5,'',0,1,0),
(3461180,'Mountain Giant Howling','Custom Creature Model',83,83,35,1,1.14286,1,5,'',0,1,0);

INSERT INTO `creature_template_model`
(`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
(3461178,0,500178,1,1,0),
(3461179,0,500179,1,1,0),
(3461180,0,500180,1,1,0);
