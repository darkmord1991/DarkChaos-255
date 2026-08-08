-- ---------------------------------------------------------------------------
-- 270  Map 750 gameobjects -- 269 that never load, 13 bad rotations, 7 bad states
-- ---------------------------------------------------------------------------
-- Three classes from the "Loading Gameobjects" block, and the first is the one
-- that matters:
--
--     Gameobject (GUID: 16329010 Entry 3794997 GoType: 3) has an invalid
--     displayId (8720), not loaded.
--
-- **"not loaded" is literal** -- those objects do not exist in the world at all.
-- 36 display ids are absent from the deployed GameObjectDisplayInfo.dbc (46,805
-- records) and between them they take out **269 spawns across 76 templates, all
-- on map 750**.
--
-- 🔴 This silently undid part of 260_. Thorned Bloodcup (3794997, display 8720)
-- is 59 of those spawns -- the single biggest container 260_ gave loot tables
-- to. Ancient Debris Pile x17, Serviceable Arrow x13, Keystone Shard and the
-- three Owlbeast totems are all in the same set. 260_'s loot was correct and
-- completely inert, because the containers were never spawned to loot. Worth
-- remembering: a GO fix is not done until its display is checked.
--
-- SOURCE. All 36 resolve in the Cata 4.3.4 GameObjectDisplayInfo. Its table is
-- 21 fields to our 19 and fields 0..18 map 1:1 -- verified against ids present
-- on both sides (id 1 Chest02: Sound_2 = 1277 and all six GeoBox floats match
-- exactly), with the two 4.x additions dropped.
--
-- MODELS. 35 of the 36 already ship with this client: mostly stock doodads
-- (Dragonblight debris, Sholazar flower, Uldaman pot, Barrens wagon, the
-- Owlbeast totems) in common/common-2/expansion/lichking/patch, and
-- treasurechest05/06 in **patch-9**. Only ONE is genuinely absent --
-- `spells\creature_spellportal_blue_clickable.m2` behind display 9383 -- and it
-- is handled by substitution in section 2 rather than an asset extraction for a
-- single spawn.
--
-- The 36 rows are ALREADY COMPILED AND DEPLOYED (patch-4 + enGB/patch-enGB-3,
-- 46,805 -> 46,841, 0 ids lost). This is the server half.

-- ---- 1. the 36 GameObjectDisplayInfo rows ----------------------------------
DELETE FROM acore_world.`gameobjectdisplayinfo_dbc` WHERE `ID` IN (8572,8645,8646,8688,8689,8720,8845,8936,8938,8940,9018,9034,9055,9058,9091,9128,9130,9135,9182,9185,9383,9606,9677,9688,9691,9693,9695,10140,10161,10202,10287,10288,10289,10290,10316,10317);

INSERT INTO acore_world.`gameobjectdisplayinfo_dbc`
(`ID`,`ModelName`,`Sound_1`,`Sound_2`,`Sound_3`,`Sound_4`,`Sound_5`,`Sound_6`,`Sound_7`,`Sound_8`,`Sound_9`,`Sound_10`,`GeoBoxMinX`,`GeoBoxMinY`,`GeoBoxMinZ`,`GeoBoxMaxX`,`GeoBoxMaxY`,`GeoBoxMaxZ`,`ObjectEffectPackageID`) VALUES
(8572,'World\\Generic\\Human\\Passive Doodads\\Weapons&Armor\\HumanArrow.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(8645,'world\\generic\\human\\passive doodads\\outposts\\generaloutpost08_dooranim.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(8646,'world\\generic\\passivedoodads\\mapleleaves\\maple_leaves01.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(8688,'world\\expansion02\\doodads\\dragonblight\\dragonblight_debrispile_01.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(8689,'world\\expansion02\\doodads\\dragonblight\\dragonblight_debrispile_02.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(8720,'world\\expansion02\\doodads\\scholazar\\bushes\\sholazar_flowera.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(8845,'world\\kalimdor\\barrens\\passivedoodads\\wagon\\barrensbustedwagon.mdx',0,0,0,0,0,0,0,0,0,0,-35.421356,-16.445856,-2.397343,18.099464,19.475945,17.278736,0),
(8936,'world\\kalimdor\\tanaris\\passivedoodads\\goblin\\go_large_bomb_2.mdx',0,0,0,0,0,0,0,0,0,0,-1.073633,-0.862738,-0.083061,1.025353,0.833007,1.9649,0),
(8938,'world\\generic\\gnome\\passive doodads\\parts\\gnomescrew03.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(8940,'world\\kalimdor\\desolace\\passivedoodads\\kodogravebones\\bannercentaur04.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9018,'spells\\ice_precast_uber_base.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9034,'world\\khazmodan\\uldaman\\passivedoodads\\pots\\uldamanpotbroken02.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9055,'world\\kalimdor\\tanaris\\passivedoodads\\goblin\\go_small_bomb.mdx',0,0,0,0,0,0,0,0,0,0,-0.194953,-0.188495,-0.006605,0.189328,0.194882,0.462732,0),
(9058,'world\\generic\\goblin\\passivedoodads\\lostisles\\postboxgoblin.mdx',0,0,0,0,0,0,0,0,0,0,-1.223065,-0.374973,-0.050063,0.57377,0.500259,2.365639,0),
(9091,'world\\dungeon\\cavernsoftime\\passivedoodads\\darkportal\\cot_standingstone02.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9128,'creature\\scryingorb\\scryingorb.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9130,'world\\expansion03\\doodads\\worgen\\items\\worgen_paper_06.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9135,'WORLD\\GENERIC\\GOBLIN\\PASSIVEDOODADS\\LOSTISLES\\GOBLIN_POOLELEVATOR.MDX',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9182,'spells\\rocketlauncher_precast.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9185,'creature\\questobjects\\creature_scourgecrystal.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9383,'spells\\creature_spellportal_blue_clickable.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9606,'world\\generic\\goblin\\passivedoodads\\bbq\\goblin_bbq_01.MDX',0,0,0,0,0,0,0,0,0,0,-0.926887,-1.069428,-0.031651,0.724654,1.581567,1.941793,0),
(9677,'world\\generic\\goblin\\passivedoodads\\diagrams\\goblin_diagram_01.mdx',0,0,0,0,0,0,0,0,0,0,-0.262682,-0.412907,-0.006443,0.257411,0.428276,0.081859,0),
(9688,'WORLD\\KALIMDOR\\ORGRIMMAR\\PASSIVEDOODADS\\WINTERORC\\BRAZIER\\WINTERORC_SMALL_BRAZIER_01.MDX',0,0,0,0,0,0,0,0,0,0,-0.719038,-0.730391,-0.037395,0.744384,0.733031,1.874338,0),
(9691,'WORLD\\GENERIC\\GOBLIN\\PASSIVEDOODADS\\BBQ\\GOBLIN_BBQ_03.MDX',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9693,'WORLD\\GENERIC\\GOBLIN\\PASSIVEDOODADS\\ELEVATOR\\GOBLIN_ELEVATOR.MDX',0,0,0,0,0,0,0,0,0,0,-3.538137,-5.035937,-3.550744,4.991193,4.990959,1.974864,0),
(9695,'world\\generic\\goblin\\passivedoodads\\kezan\\items\\goblin_kezan_chair_01.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10140,'world\\expansion02\\doodads\\generic\\vrykul\\quest\\vr_plants_03_q.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10161,'spells\\infernal_geo.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10202,'world\\expansion01\\doodads\\generic\\ogre\\weapons\\om_weaponrack_01.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10287,'world\\generic\\passivedoodads\\treasurepiles\\goldpilemedium01.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10288,'world\\generic\\owlbear\\owlbeartotems\\owlbeartotem01.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10289,'world\\generic\\owlbear\\rocks\\owlbearrock02.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10290,'world\\generic\\owlbear\\owlbeartotems\\owlbearscarecrow02.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10316,'world\\skillactivated\\containers\\treasurechest05.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10317,'world\\skillactivated\\containers\\treasurechest06.mdx',0,0,0,0,0,0,0,0,0,0,-0.885185,-1.420964,-0.004265,0.885181,1.420681,1.342126,0);

-- ---- 2. display 9383 -- the one model we do not have -----------------------
-- 9383 wants `spells\creature_spellportal_blue_clickable.m2`, which is in no
-- archive of this client. Its non-clickable twin IS present as display 9030
-- (`spells\creature_spellportal_blue.mdx`) and is visually the same blue
-- portal, so the two templates using 9383 are repointed at it. The row inserted
-- above keeps 9383 defined so nothing else that references it breaks; this just
-- stops the two live templates from depending on an absent model.
--
-- Extracting and re-baking the real Cata model for ONE spawn was not worth it:
-- Cata M2s need the v264 downport bake, and the visible difference is nil.
UPDATE acore_world.`gameobject_template` SET `displayId` = 9030
WHERE `displayId` = 9383;

-- ---- 3. thirteen non-unit rotation quaternions -----------------------------
--     Table `gameobject` has gameobject (GUID: 9602001 Entry: 176296) with
--     invalid rotation quaternion (non-unit), defaulting to orientation on Z
--     axis only
--
-- Every one is already a Z-axis-only rotation (rotation0 = rotation1 = 0) that
-- simply is not normalised -- norms of 1.000085, 0.999892, 0.999943, 0.999967
-- from whatever generated them, plus guid 13621868 which is all zeroes (norm 0).
-- The core's fallback is to rebuild the quaternion from `orientation`, so doing
-- that explicitly changes nothing about how they sit in the world and removes
-- the warning. rotation2 = sin(o/2), rotation3 = cos(o/2).
UPDATE acore_world.`gameobject`
SET `rotation0` = 0,
    `rotation1` = 0,
    `rotation2` = SIN(`orientation` / 2),
    `rotation3` = COS(`orientation` / 2)
WHERE `guid` IN (9602001,9602002,9602003,9602004,9602005,9602006,9602007,9602008,9602009,13621868,16000001,16000002,16000003);

-- ---- 4. seven elevators with state 24 --------------------------------------
--     Table `gameobject` has gameobject (GUID: 16328791 Entry: 3752614) with
--     invalid `state` (24) value, skip
--
-- GO state is 0 ACTIVE / 1 READY / 2 DESTROYED; 24 is not a state. The log named
-- one, but the DB has SEVEN type-11 transports carrying it -- the others sit on
-- maps that do not reach that check. The 107 type-11 GOs that work all use
-- state 1, so that is what these get, derived rather than guessed.
UPDATE acore_world.`gameobject` g
JOIN acore_world.`gameobject_template` gt ON gt.`entry` = g.`id`
SET g.`state` = 1
WHERE g.`state` = 24 AND gt.`type` = 11;

-- Verify after apply:
--   * SELECT COUNT(*) FROM gameobject g JOIN gameobject_template gt
--       ON gt.entry = g.id
--      WHERE gt.displayId IN (8572,8645,8646,8688,8689,8720,8845,8936,8938,8940,9018,9034,9055,9058,9091,9128,9130,9135,9182,9185,9383,9606,9677,9688,9691,9693,9695,10140,10161,10202,10287,10288,10289,10290,10316,10317);                     -> 269 now LOAD
--   * SELECT COUNT(*) FROM gameobject WHERE guid IN (9602001,9602002,9602003,9602004,9602005,9602006,9602007,9602008,9602009,13621868,16000001,16000002,16000003)
--       AND ABS(rotation0*rotation0 + rotation1*rotation1
--             + rotation2*rotation2 + rotation3*rotation3 - 1) > 0.00001;  -> 0
--   * SELECT COUNT(*) FROM gameobject WHERE state = 24;       -> 0
--   * no "invalid displayId ... not loaded", no "non-unit", no "invalid `state`".
--   * in-game, the real payoff: 260_'s containers are lootable at last -- 59
--     Thorned Bloodcups, 17 Ancient Debris Piles, 13 Serviceable Arrows and the
--     rest actually appear.
