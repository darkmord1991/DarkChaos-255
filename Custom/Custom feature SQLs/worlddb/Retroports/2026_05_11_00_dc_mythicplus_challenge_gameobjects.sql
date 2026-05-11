-- Mythic+ challenge start retroport gameobjects
-- Client asset root: world\dungeon\challenge
-- Source manifests: Custom/challenge/*.manifest.json
--
-- This migration keeps the retroported countdown/start objects together with
-- their server-side gameobject_template definitions.
--
-- Client requirements:
--   - Custom/CSV DBC/GameObjectDisplayInfo.csv IDs 100001-100003
--   - MPQ/client assets for:
--       world\dungeon\challenge\challengemode_pedestal_1.m2
--       world\dungeon\challenge\challengemode_wall_dome.m2
--       world\dungeon\challenge\challengemode_wall_flat.m2

-- -----------------------------------------------------------------------------
-- ID map
-- -----------------------------------------------------------------------------
-- GameObject entries: 700002-700004
-- Display IDs:        100001-100003
-- FileData IDs:       603228, 603387, 603389
--
-- 700002 -> 100001 -> 603228 -> challengemode_pedestal_1.m2
-- 700003 -> 100002 -> 603387 -> challengemode_wall_dome.m2
-- 700004 -> 100003 -> 603389 -> challengemode_wall_flat.m2

DELETE FROM `gameobject_template`
WHERE `entry` IN (700002, 700003, 700004);

INSERT INTO `gameobject_template`
(`entry`,`type`,`displayId`,`name`,`IconName`,`castBarCaption`,`unk1`,`size`,
 `Data0`,`Data1`,`Data2`,`Data3`,`Data4`,`Data5`,`Data6`,`Data7`,`Data8`,`Data9`,
 `Data10`,`Data11`,`Data12`,`Data13`,`Data14`,`Data15`,`Data16`,`Data17`,`Data18`,
 `Data19`,`Data20`,`Data21`,`Data22`,`Data23`,`AIName`,`ScriptName`,`VerifiedBuild`)
VALUES
(700002,5,100001,'challengemode_pedestal_1.m2 [PATCH]','','','',1,0,-1,0,0,0,0,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,'','',0),
(700003,5,100002,'challengemode_wall_dome.m2 [PATCH WALL]','','','',1,0,-1,0,0,0,0,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,'','',0),
(700004,5,100003,'challengemode_wall_flat.m2 [PATCH WALL]','','','',1,0,-1,0,0,0,0,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,'','',0);

-- Suggested spawn helpers:
--   .gobject add 700002 <x> <y> <z> [map]
--   .gobject add 700003 <x> <y> <z> [map]
--   .gobject add 700004 <x> <y> <z> [map]
--
-- Intended usage:
--   700002 = countdown/start pedestal visual
--   700003 = dome-style countdown barrier
--   700004 = flat barrier panel