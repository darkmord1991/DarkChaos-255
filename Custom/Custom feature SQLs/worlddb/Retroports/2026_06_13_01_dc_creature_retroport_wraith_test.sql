-- Creature model retroport - Wraith Engine render test (4 modern MD21 models)
-- These are NOT downported; they are shipped as-is and rendered by the Wraith
-- Engine (Wraith.dll) modern-M2 backport on the 3.3.5a client.
--
-- Source folders: Custom/retroport/creature/<folder>/ - pack the WHOLE
-- Custom/retroport/ tree into the client patch MPQ root (folder names are
-- case-insensitive in MPQ, so creature\ serves as Creature\). The shared
-- texture trees (dungeons\, world\, item\) MUST ship too: troll_canoe and
-- waterelementalmercury reference textures outside their own folder via the
-- manifest's relative ..\ paths.
--
-- Client DBC requirements (regenerate .dbc from the CSV sources, then deploy to
-- BOTH the client patch and the worldserver data/dbc/ directory):
--   CreatureModelData.csv:    500322-500325
--   CreatureDisplayInfo.csv:  500326-500329
--
-- Texture variation slots were read from each M2 header:
--   chimerabeast / troll_canoe_02_creature / waterelementalmercury - all
--     textures are type 0 (hardcoded/embedded via fileDataID); no DBC
--     TextureVariation slots (the modern skin carries its own texture refs).
--   warpstalker_low - tex[0] is type 11 (MONSTER_1); TextureVariation_1 =
--     warpstalkerskinwhite (the only .blp in the folder).

DELETE FROM `creature_template_model`
WHERE `CreatureID` BETWEEN 3461275 AND 3461278;

DELETE FROM `creature_template`
WHERE `entry` BETWEEN 3461275 AND 3461278;

DELETE FROM `creature_model_info`
WHERE `DisplayID` BETWEEN 500326 AND 500329;

INSERT INTO `creature_model_info`
(`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
VALUES
(500326,2.00,4.00,2,0,0),
(500327,3.00,6.00,2,0,0),
(500328,2.00,4.00,2,0,0),
(500329,2.00,4.00,2,0,0);

INSERT INTO `creature_template`
(`entry`,`name`,`subname`,`minlevel`,`maxlevel`,`faction`,`speed_walk`,`speed_run`,
 `unit_class`,`type`,`AIName`,`MovementType`,`RegenHealth`,`VerifiedBuild`)
VALUES
(3461275,'Chimaera Beast','Wraith Engine Test',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461276,'Troll War Canoe','Wraith Engine Test',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461277,'Warp Stalker','Wraith Engine Test',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461278,'Mercury Water Elemental','Wraith Engine Test',83,83,35,1,1.14286,1,4,'',0,1,0);

INSERT INTO `creature_template_model`
(`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
(3461275,0,500326,1.00,1,0),
(3461276,0,500327,1.00,1,0),
(3461277,0,500328,1.00,1,0),
(3461278,0,500329,1.00,1,0);
