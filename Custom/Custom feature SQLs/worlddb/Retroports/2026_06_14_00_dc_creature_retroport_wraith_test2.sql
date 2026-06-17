-- Creature model retroport - Wraith Engine render test, batch 2 (7 modern models)
-- Companion to 2026_06_13_01_dc_creature_retroport_wraith_test.sql (first 4).
--
-- Source folders: Custom/wraithtest/creature/<folder>/ - pack the WHOLE
-- Custom/wraithtest/ tree into the client patch MPQ root (creature\ serves as
-- Creature\; the shared dungeons\, world\, item\ trees must ship too). All 11
-- wraithtest models now live under creature/, so every ModelName is Creature\.
--
-- TXID FIX APPLIED: every .m2 under Custom/wraithtest/ was run through
-- M2Mod.exe --txid-remove (retroport_tools), which drops the modern TXID chunk
-- and writes the texture filenames inline (Wraith de-chunks MD21 and rebuilds
-- materials but never resolves TXID->filename, so without this the bodies draw
-- untextured). The models stay MD21/modern, so Wraith still renders them.
-- Originals backed up at retroport_tools/_wraithtest_m2_backup/.
--
-- Client DBC requirements (regenerate .dbc from the CSV sources, deploy to BOTH
-- the client patch and the worldserver data/dbc/):
--   CreatureModelData.csv:    500330-500336
--   CreatureDisplayInfo.csv:  500337-500343
--
-- MONSTER_x texture-variation slots (read from each M2 header, blp resolved from
-- the model's manifest.json) are supplied via CreatureDisplayInfo TextureVariation:
--   waterelemental     MON1 = waterelementalgreenskin
--   berserker          MON1 = berserker_orange_skin
--   grovemanfemale     MON1 = grovemanfemale_skin_green, MON2 = grovemanfemale_clothes_green
--   snowman2           MON1 = snowman2_black
--   voidwraithraidboss MON1 = voidwraithraidboss_glow, MON2 = voidwraithraidboss_fx, MON3 = voidwraithraidboss_7377612
--   dhmaledps / lyssabeldawnpetal - no MONSTER slots (all textures hardcoded/inlined).

DELETE FROM `creature_template_model`
WHERE `CreatureID` BETWEEN 3461279 AND 3461285;

DELETE FROM `creature_template`
WHERE `entry` BETWEEN 3461279 AND 3461285;

DELETE FROM `creature_model_info`
WHERE `DisplayID` BETWEEN 500337 AND 500343;

INSERT INTO `creature_model_info`
(`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
VALUES
(500337,1.50,3.00,2,0,0),
(500338,1.50,3.00,2,0,0),
(500339,2.00,4.00,2,0,0),
(500340,2.00,4.00,2,0,0),
(500341,1.50,3.00,2,0,0),
(500342,0.50,1.50,2,0,0),
(500343,3.00,6.00,2,0,0);

INSERT INTO `creature_template`
(`entry`,`name`,`subname`,`minlevel`,`maxlevel`,`faction`,`speed_walk`,`speed_run`,
 `unit_class`,`type`,`AIName`,`MovementType`,`RegenHealth`,`VerifiedBuild`)
VALUES
(3461279,'Water Elemental','Wraith Engine Test',83,83,35,1,1.14286,1,4,'',0,1,0),
(3461280,'Berserker','Wraith Engine Test',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461281,'Void Demon Hunter','Wraith Engine Test',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461282,'Grove Warden','Wraith Engine Test',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461283,'Lyssabel Dawnpetal','Wraith Engine Test',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461284,'Snowman','Wraith Engine Test',83,83,35,1,1.14286,1,8,'',0,1,0),
(3461285,'Void Wraith','Wraith Engine Test',83,83,35,1,1.14286,1,6,'',0,1,0);

INSERT INTO `creature_template_model`
(`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
(3461279,0,500337,1.00,1,0),
(3461280,0,500338,1.00,1,0),
(3461281,0,500339,1.00,1,0),
(3461282,0,500340,1.00,1,0),
(3461283,0,500341,1.00,1,0),
(3461284,0,500342,1.00,1,0),
(3461285,0,500343,1.00,1,0);
