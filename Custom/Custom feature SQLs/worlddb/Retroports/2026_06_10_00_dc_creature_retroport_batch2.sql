-- Creature model retroport batch 2 (43 models, 44 displays)
-- Source folders: Custom/creature/<folder>/ - pack each folder into the client
-- patch MPQ at path Creature\<folder>\ (m2 + .skin + .anim + all .blp).
--
-- Client DBC requirements (regenerate from CSV sources, deploy to client patch
-- AND worldserver data/dbc/):
--   CreatureModelData.csv:   500235-500277
--   CreatureDisplayInfo.csv: 500278-500321
--
-- Texture variation slots were extracted from each M2 header (MONSTER_1/2/3);
-- models without variation slots use only hardcoded/embedded textures.
--
-- NOTE: bloodtick (entry 3461237, display 500284, model 500240) is EXCLUDED:
-- its M2 has 0 bones (skeleton still in the modern .skel file) and crashes the
-- 3.3.5 client on view. Do not pack the bloodtick folder. Re-add after the
-- model is re-exported with the skeleton inlined (reuse the same IDs).

DELETE FROM `creature_template_model`
WHERE `CreatureID` BETWEEN 3461231 AND 3461274;

DELETE FROM `creature_template`
WHERE `entry` BETWEEN 3461231 AND 3461274;

DELETE FROM `creature_model_info`
WHERE `DisplayID` BETWEEN 500278 AND 500321;

INSERT INTO `creature_model_info`
(`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
VALUES
(500278,2.00,4.00,2,0,0),
(500279,0.50,1.50,2,0,0),
(500280,2.00,4.00,2,0,0),
(500281,1.50,3.00,2,0,0),
(500282,1.50,3.00,2,0,0),
(500283,0.50,1.50,2,0,0),
(500285,0.40,1.50,2,0,0),
(500286,0.80,2.00,2,0,0),
(500287,1.50,3.00,2,0,0),
(500288,0.80,2.00,2,0,0),
(500289,0.80,2.00,2,0,0),
(500290,1.00,2.00,2,0,0),
(500291,1.00,2.00,2,0,0),
(500292,1.00,2.50,2,0,0),
(500293,0.80,2.00,2,0,0),
(500294,1.00,2.50,2,0,0),
(500295,1.20,2.40,2,0,0),
(500296,1.00,2.00,2,0,0),
(500297,1.00,2.00,2,0,0),
(500298,0.50,1.50,2,0,0),
(500299,0.80,2.00,2,0,0),
(500300,0.50,1.50,2,0,0),
(500301,0.50,1.50,2,0,0),
(500302,2.00,4.00,2,0,0),
(500303,1.00,2.50,2,0,0),
(500304,0.75,1.80,2,0,0),
(500305,0.75,1.80,2,0,0),
(500306,0.75,1.80,2,0,0),
(500307,0.75,1.80,2,0,0),
(500308,1.20,2.40,2,0,0),
(500309,1.20,2.40,2,0,0),
(500310,0.75,1.80,2,0,0),
(500311,1.00,2.50,2,0,0),
(500312,1.00,2.00,2,0,0),
(500313,0.50,1.50,2,0,0),
(500314,0.30,1.50,2,0,0),
(500315,0.50,1.50,2,0,0),
(500316,0.50,1.50,2,0,0),
(500317,0.80,2.00,2,0,0),
(500318,0.80,1.80,2,0,0),
(500319,2.00,4.00,2,0,0),
(500320,0.35,1.50,2,0,0),
(500321,0.35,1.50,2,0,0);

INSERT INTO `creature_template`
(`entry`,`name`,`subname`,`minlevel`,`maxlevel`,`faction`,`speed_walk`,`speed_run`,
 `unit_class`,`type`,`AIName`,`MovementType`,`RegenHealth`,`VerifiedBuild`)
VALUES
(3461231,'Aggramar','Custom Creature Model',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461232,'Alleria Windrunner','Custom Creature Model',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461233,'Aman''Thul','Custom Creature Model',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461234,'Armored T-Rex','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461235,'Armored T-Rex (Red)','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461236,'Tauren Band Drummer','Custom Creature Model',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461238,'Compy','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461239,'Dark Watcher (Female)','Custom Creature Model',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461240,'Dark Watcher Gatekeeper','Custom Creature Model',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461241,'Dark Watcher (Male)','Custom Creature Model',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461242,'Eredar Overlord','Custom Creature Model',83,83,35,1,1.14286,1,3,'',0,1,0),
(3461243,'Felhound (Fire)','Custom Creature Model',83,83,35,1,1.14286,1,3,'',0,1,0),
(3461244,'Felhound (Shadow)','Custom Creature Model',83,83,35,1,1.14286,1,3,'',0,1,0),
(3461245,'Fel Lord Bounty Hunter','Custom Creature Model',83,83,35,1,1.14286,1,3,'',0,1,0),
(3461246,'Spirit Ferryman','Custom Creature Model',83,83,35,1,1.14286,1,6,'',0,1,0),
(3461247,'Giant Snake','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461248,'River Hippo','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461249,'King Rastakhan','Custom Creature Model',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461250,'Komodo Dragon','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461251,'Broken Light Mother','Custom Creature Model',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461252,'Void Revenant','Custom Creature Model',83,83,35,1,1.14286,1,6,'',0,1,0),
(3461253,'Nightborne (Female)','Custom Creature Model',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461254,'Nightborne (Male)','Custom Creature Model',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461255,'Norgannon','Custom Creature Model',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461256,'Sea Eel','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461257,'Shivan Priestess (Fel)','Custom Creature Model',83,83,35,1,1.14286,1,3,'',0,1,0),
(3461258,'Shivan Priestess (Fire)','Custom Creature Model',83,83,35,1,1.14286,1,3,'',0,1,0),
(3461259,'Shivan Priestess (Frost)','Custom Creature Model',83,83,35,1,1.14286,1,3,'',0,1,0),
(3461260,'Shivan Priestess (Shadow)','Custom Creature Model',83,83,35,1,1.14286,1,3,'',0,1,0),
(3461261,'Threshadon','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461262,'Thunder Lizard','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461263,'Tiger Loa','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461264,'Titan Keeper Troll','Custom Creature Model',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461265,'Toad Loa','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461266,'Toad Loa (Small)','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461267,'Swamp Toad','Custom Creature Model',83,83,35,1,1.14286,1,8,'',0,1,0),
(3461268,'Tortollan','Custom Creature Model',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461269,'Turalyon','Custom Creature Model',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461270,'Void-Broken Brute','Custom Creature Model',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461271,'Wind Serpent','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461272,'Winged Eredar Overlord','Custom Creature Model',83,83,35,1,1.14286,1,3,'',0,1,0),
(3461273,'Zandalari Child (Female)','Custom Creature Model',83,83,35,1,1.14286,1,7,'',0,1,0),
(3461274,'Zandalari Child (Male)','Custom Creature Model',83,83,35,1,1.14286,1,7,'',0,1,0);

INSERT INTO `creature_template_model`
(`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
(3461231,0,500278,1.00,1,0),
(3461232,0,500279,1.00,1,0),
(3461233,0,500280,1.00,1,0),
(3461234,0,500281,1.00,1,0),
(3461235,0,500282,1.00,1,0),
(3461236,0,500283,1.00,1,0),
(3461238,0,500285,1.00,1,0),
(3461239,0,500286,1.00,1,0),
(3461240,0,500287,1.00,1,0),
(3461241,0,500288,1.00,1,0),
(3461242,0,500289,1.00,1,0),
(3461243,0,500290,1.00,1,0),
(3461244,0,500291,1.00,1,0),
(3461245,0,500292,1.00,1,0),
(3461246,0,500293,1.00,1,0),
(3461247,0,500294,1.00,1,0),
(3461248,0,500295,1.00,1,0),
(3461249,0,500296,1.00,1,0),
(3461250,0,500297,1.00,1,0),
(3461251,0,500298,1.00,1,0),
(3461252,0,500299,1.00,1,0),
(3461253,0,500300,1.00,1,0),
(3461254,0,500301,1.00,1,0),
(3461255,0,500302,1.00,1,0),
(3461256,0,500303,1.00,1,0),
(3461257,0,500304,1.00,1,0),
(3461258,0,500305,1.00,1,0),
(3461259,0,500306,1.00,1,0),
(3461260,0,500307,1.00,1,0),
(3461261,0,500308,1.00,1,0),
(3461262,0,500309,1.00,1,0),
(3461263,0,500310,1.00,1,0),
(3461264,0,500311,1.00,1,0),
(3461265,0,500312,1.00,1,0),
(3461266,0,500313,1.00,1,0),
(3461267,0,500314,1.00,1,0),
(3461268,0,500315,1.00,1,0),
(3461269,0,500316,1.00,1,0),
(3461270,0,500317,1.00,1,0),
(3461271,0,500318,1.00,1,0),
(3461272,0,500319,1.00,1,0),
(3461273,0,500320,1.00,1,0),
(3461274,0,500321,1.00,1,0);
