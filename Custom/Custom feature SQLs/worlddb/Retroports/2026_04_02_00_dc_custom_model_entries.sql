-- DarkChaos custom retroport model registration
-- Source assets: Custom/models/*
--
-- This migration wires custom models and infernalmount variants into
-- server-side stores using:
--   - creaturemodeldata_dbc
--   - creaturedisplayinfo_dbc
--   - creature_model_info
--   - creature_template + creature_template_model
--
-- NOTE: Client DBCs still need matching entries in CreatureModelData.dbc
-- and CreatureDisplayInfo.dbc for rendering.

-- -----------------------------------------------------------------------------
-- ID map
-- -----------------------------------------------------------------------------
-- ModelData ID range:              500001-500008
-- Display ID range:                500001-500018
-- Creature entry range:            3461001-3461018
--
-- 500001 / 3461001 -> dreamowl_firemount
-- 500002 / 3461002 -> emeralddreamstag
-- 500003 / 3461003 -> flyingsprite
-- 500004 / 3461004 -> infernalmount (Felblaze)
-- 500009 / 3461009 -> infernalmount (Coldflame)
-- 500010 / 3461010 -> infernalmount (Flarecore)
-- 500011 / 3461011 -> infernalmount (Frostshard)
-- 500012 / 3461012 -> infernalmount (Hellfire)
-- 500005 / 3461005 -> netherwingmount
-- 500006 / 3461006 -> phoenix2darkwell
-- 500007 / 3461007 -> skeletalwarhorse2 (Black)
-- 500013 / 3461013 -> skeletalwarhorse2 (Brown)
-- 500014 / 3461014 -> skeletalwarhorse2 (Green)
-- 500015 / 3461015 -> skeletalwarhorse2 (Midnight)
-- 500016 / 3461016 -> skeletalwarhorse2 (Purple)
-- 500017 / 3461017 -> skeletalwarhorse2 (Red)
-- 500018 / 3461018 -> skeletalwarhorse2 (White)
-- 500008 / 3461008 -> thunderhydra

DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 3461001 AND 3461018;
DELETE FROM `creature_template` WHERE `entry` BETWEEN 3461001 AND 3461018;
DELETE FROM `creature_model_info` WHERE `DisplayID` BETWEEN 500001 AND 500018;

INSERT INTO `creature_model_info`
(`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
VALUES
(500001,1.20,2.20,2,0,0),
(500002,1.10,2.00,2,0,0),
(500003,0.70,1.50,2,0,0),
(500004,1.40,2.40,2,0,0),
(500009,1.40,2.40,2,0,0),
(500010,1.40,2.40,2,0,0),
(500011,1.40,2.40,2,0,0),
(500012,1.40,2.40,2,0,0),
(500005,1.50,2.60,2,0,0),
(500006,1.20,2.20,2,0,0),
(500007,1.10,2.10,2,0,0),
(500013,1.10,2.10,2,0,0),
(500014,1.10,2.10,2,0,0),
(500015,1.10,2.10,2,0,0),
(500016,1.10,2.10,2,0,0),
(500017,1.10,2.10,2,0,0),
(500018,1.10,2.10,2,0,0),
(500008,2.00,3.50,2,0,0);

INSERT INTO `creature_template`
(`entry`,`name`,`subname`,`minlevel`,`maxlevel`,`faction`,`speed_walk`,`speed_run`,
 `unit_class`,`type`,`AIName`,`MovementType`,`RegenHealth`,`VerifiedBuild`)
VALUES
(3461001,'Dreamowl Firemount','Custom Retroport Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461002,'Emerald Dream Stag','Custom Retroport Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461003,'Flying Sprite','Custom Retroport Model',80,80,35,1,1.14286,1,8,'',0,1,0),
(3461004,'Felblaze Infernal','Custom Retroport Model',80,80,35,1,1.14286,1,3,'',0,1,0),
(3461009,'Coldflame Infernal','Custom Retroport Model',80,80,35,1,1.14286,1,3,'',0,1,0),
(3461010,'Flarecore Infernal','Custom Retroport Model',80,80,35,1,1.14286,1,3,'',0,1,0),
(3461011,'Frostshard Infernal','Custom Retroport Model',80,80,35,1,1.14286,1,3,'',0,1,0),
(3461012,'Hellfire Infernal','Custom Retroport Model',80,80,35,1,1.14286,1,3,'',0,1,0),
(3461005,'Netherwing Mount','Custom Retroport Model',80,80,35,1,1.14286,1,2,'',0,1,0),
(3461006,'Phoenix of Darkwell','Custom Retroport Model',80,80,35,1,1.14286,1,4,'',0,1,0),
(3461007,'Black Skeletal Warhorse II','Custom Retroport Model',80,80,35,1,1.14286,1,6,'',0,1,0),
(3461013,'Brown Skeletal Warhorse II','Custom Retroport Model',80,80,35,1,1.14286,1,6,'',0,1,0),
(3461014,'Green Skeletal Warhorse II','Custom Retroport Model',80,80,35,1,1.14286,1,6,'',0,1,0),
(3461015,'Midnight Skeletal Warhorse II','Custom Retroport Model',80,80,35,1,1.14286,1,6,'',0,1,0),
(3461016,'Purple Skeletal Warhorse II','Custom Retroport Model',80,80,35,1,1.14286,1,6,'',0,1,0),
(3461017,'Red Skeletal Warhorse II','Custom Retroport Model',80,80,35,1,1.14286,1,6,'',0,1,0),
(3461018,'White Skeletal Warhorse II','Custom Retroport Model',80,80,35,1,1.14286,1,6,'',0,1,0),
(3461008,'Thunder Hydra','Custom Retroport Model',80,80,35,1,1.14286,1,1,'',0,1,0);

INSERT INTO `creature_template_model`
(`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
(3461001,0,500001,1,1,0),
(3461002,0,500002,1,1,0),
(3461003,0,500003,1,1,0),
(3461004,0,500004,1,1,0),
(3461009,0,500009,1,1,0),
(3461010,0,500010,1,1,0),
(3461011,0,500011,1,1,0),
(3461012,0,500012,1,1,0),
(3461005,0,500005,1,1,0),
(3461006,0,500006,1,1,0),
(3461007,0,500007,1,1,0),
(3461013,0,500013,1,1,0),
(3461014,0,500014,1,1,0),
(3461015,0,500015,1,1,0),
(3461016,0,500016,1,1,0),
(3461017,0,500017,1,1,0),
(3461018,0,500018,1,1,0),
(3461008,0,500008,1,1,0);
