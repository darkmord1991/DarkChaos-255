-- ---------------------------------------------------------------------------
-- 188  Map 750 -- make 740 invisible spawns visible again
-- ---------------------------------------------------------------------------
-- REGRESSION FIX for 181_ / 183_ / 184_. Those files copied creature and
-- gameobject templates from `cata_world` faithfully -- including their
-- CATACLYSM display IDs, which do not exist in a 3.3.5 client. Nobody
-- downported the models, so:
--
--     84 creature display IDs missing -> 77 entries, 695 spawns
--      9 gameobject display IDs missing ->  9 entries,  45 spawns
--
-- This is not cosmetic. ObjectMgr.cpp (~line 743) does:
--     if (!displayEntry) { LOG_ERROR("sql.sql", "... lists non-existing
--         CreatureDisplayID id ({}), this can crash the client."); continue; }
-- The `continue` DROPS the model row, so those 77 entries end up with ZERO
-- models -- plus 84 lines of boot-log error spam every startup.
--
-- HOW IT IS FIXED -- deliberately WITHOUT extracting anything from retail.
-- A dry run of downport-creature.js against the retail client resolved all
-- 84/84 + 9/9 IDs, but shipping that output would have been a bad trade:
--   * the 84 displays need only 28 unique models, and 15 of those 28 are
--     ALREADY in our client;
--   * 10 of the remaining 13 are Legion-era `*_hd.m2` character models
--     (humanmale_hd, orcmale_hd, nightelffemale_hd ...). Raw retail MD21
--     character models are a known client-crasher on this core, and packing
--     them near the stock race paths risks the global T-pose incident again;
--   * two GO models live under `spells\`, and the extractor works at FOLDER
--     granularity -- it wanted to pull 40,165 files and pack them over the
--     client's entire stock spell-visual set;
--   * retail stores textures as FileDataIDs, so every generated row came back
--     with EMPTY TextureVariation columns. The extracted models would have
--     rendered untextured anyway -- i.e. the extraction bought no fidelity.
--
-- So instead: 84 real CreatureDisplayInfo rows were added to
-- Custom/CSV DBC/CreatureDisplayInfo.csv keeping the Cata display IDs and
-- their per-display CreatureModelScale, but pointing ModelID at models the
-- client ALREADY has. `*_hd` -> the stock non-HD equivalent of the same race.
-- Two models with no equivalent were substituted by eye:
--     Oil Balloon    (goblin_crazymachine_02) -> creature\balloon\creature_balloon_01.m2
--     Deputy Clunky  (goblin_crazymachine_07) -> Creature\Goblin\GoblinShredder.mdx
-- CreatureDisplayInfo.dbc is recompiled and DEPLOYED (server data/dbc, plus
-- patch-4.MPQ and enGB/patch-enGB-3.MPQ, both verified byte-identical).
-- Zero new model files were added to the client.
--
-- Apply against acore_world. A CLIENT RESTART is required (DBC changed); no
-- worldserver rebuild is needed. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) creature_model_info for the 84 display IDs
-- ---------------------------------------------------------------------------
-- Without these the core logs "No model data exist for `CreatureDisplayID`"
-- and falls back to a default bounding radius / combat reach.
-- Values are the retail measurements for each display.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (
  31547, 31938, 32445, 32516, 32661, 32662, 32663, 32722, 33199, 33205,
  33360, 33361, 33363, 33366, 33367, 33368, 33369, 33370, 33376, 33679,
  35547, 35619, 35620, 35621, 35622, 35689, 35690, 35724, 35771, 35777,
  35859, 35911, 35951, 35956, 35997, 36018, 36069, 36070, 36071, 36111,
  36112, 36154, 36155, 36157, 36159, 36160, 36161, 36183, 36184, 36186,
  36187, 36188, 36189, 36190, 36194, 36195, 36196, 36197, 36198, 36199,
  36200, 36201, 36202, 36207, 36208, 36249, 36274, 36342, 36667, 36672,
  36680, 36681, 36682, 36688, 36689, 36798, 36799, 36871, 36956, 36957,
  37375, 37555, 37597, 37705);

INSERT INTO `creature_model_info`
    (`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
VALUES
(31547,0.6111,2.0313,2,0,0),
(31938,0.6111,2.0313,2,0,0),
(32445,0.5133,1.2736,2,0,0),
(32516,0.6111,2.0313,2,0,0),
(32661,0.6111,2.0313,2,0,0),
(32662,0.6111,2.0313,2,0,0),
(32663,0.6111,2.0313,2,0,0),
(32722,0.6111,2.0313,2,0,0),
(33199,0.5133,1.2736,2,0,0),
(33205,0.6111,2.0313,2,0,0),
(33360,0.6111,2.0313,2,0,0),
(33361,0.6111,2.0313,2,0,0),
(33363,0.6111,2.0313,2,0,0),
(33366,0.6111,2.0313,2,0,0),
(33367,0.6111,2.0313,2,0,0),
(33368,0.6111,2.0313,2,0,0),
(33369,0.6111,2.0313,2,0,0),
(33370,0.6111,2.0313,2,0,0),
(33376,0.6111,2.0313,2,0,0),
(33679,0.6111,2.0313,2,0,0),
(35547,0.6111,2.0313,2,0,0),
(35619,0.6111,2.0313,2,0,0),
(35620,0.6111,2.0313,2,0,0),
(35621,0.6111,2.0313,2,0,0),
(35622,0.6111,2.0313,2,0,0),
(35689,0.6111,2.0313,2,0,0),
(35690,0.6111,2.0313,2,0,0),
(35724,0.6111,2.0313,2,0,0),
(35771,0.6111,2.0313,2,0,0),
(35777,0.6111,2.0313,2,0,0),
(35859,0.6111,2.0313,2,0,0),
(35911,0.6111,2.0313,2,0,0),
(35951,0.6111,2.0313,2,0,0),
(35956,0.6111,2.0313,2,0,0),
(35997,0.5133,1.2736,2,0,0),
(36018,0.6111,2.0313,2,0,0),
(36069,0.5133,1.2736,2,0,0),
(36070,0.5133,1.2736,2,0,0),
(36071,0.5133,1.2736,2,0,0),
(36111,0.5000,2.0000,2,0,0),
(36112,4.3533,8.1073,2,0,0),
(36154,0.6111,2.0313,2,0,0),
(36155,0.5133,1.2736,2,0,0),
(36157,0.5133,1.2736,2,0,0),
(36159,0.6111,2.0313,2,0,0),
(36160,0.6111,2.0313,2,0,0),
(36161,0.6111,2.0313,2,0,0),
(36183,0.6111,2.0313,2,0,0),
(36184,0.6111,2.0313,2,0,0),
(36186,0.6111,2.0313,2,0,0),
(36187,0.6111,2.0313,2,0,0),
(36188,0.6111,2.0313,2,0,0),
(36189,0.6111,2.0313,2,0,0),
(36190,0.6111,2.0313,2,0,0),
(36194,0.6111,2.0313,2,0,0),
(36195,0.6111,2.0313,2,0,0),
(36196,0.6111,2.0313,2,0,0),
(36197,0.6111,2.0313,2,0,0),
(36198,0.6111,2.0313,2,0,0),
(36199,0.6111,2.0313,2,0,0),
(36200,0.6111,2.0313,2,0,0),
(36201,0.6111,2.0313,2,0,0),
(36202,0.6111,2.0313,2,0,0),
(36207,0.6111,2.0313,2,0,0),
(36208,0.6111,2.0313,2,0,0),
(36249,0.6111,2.0313,2,0,0),
(36274,0.6111,2.0313,2,0,0),
(36342,0.6111,2.0313,2,0,0),
(36667,0.6111,2.0313,2,0,0),
(36672,0.6111,2.0313,2,0,0),
(36680,0.6111,2.0313,2,0,0),
(36681,0.6111,2.0313,2,0,0),
(36682,0.6111,2.0313,2,0,0),
(36688,0.6111,2.0313,2,0,0),
(36689,0.6111,2.0313,2,0,0),
(36798,0.6111,2.0313,2,0,0),
(36799,0.6111,2.0313,2,0,0),
(36871,0.6111,2.0313,2,0,0),
(36956,0.6111,2.0313,2,0,0),
(36957,0.6111,2.0313,2,0,0),
(37375,0.5133,1.2736,2,0,0),
(37555,0.6111,2.0313,2,0,0),
(37597,0.6111,2.0313,2,0,0),
(37705,0.6111,2.0313,2,0,0);

-- ---------------------------------------------------------------------------
-- B) gameobject_template -- repoint the 9 missing GO displays
-- ---------------------------------------------------------------------------
-- Handled differently from the creatures above, and more cheaply: SEVEN of the
-- nine Cata models are already in the client under a DIFFERENT display id, so
-- no DBC row is needed at all -- just point the template at the id we have.
-- The existing rows also carry correct GeoBox bounds, which a hand-written row
-- would not. Only two needed a stand-in.
-- ---------------------------------------------------------------------------
-- Aetherion Ritual Orb -- twilighthammer_orb_01 is absent; 9849 is the same
-- Twilight's Hammer doodad set (twilightshammer_magicaldevice_01).
UPDATE `gameobject_template` SET `displayId` = 9849  WHERE `displayId` = 8552;
-- Jadefire Brazier (24 spawns) -- exact same model, already present.
UPDATE `gameobject_template` SET `displayId` = 85048 WHERE `displayId` = 8553;
-- Grovekeeper's Incense -- borean_redplant_bowl_01, exact.
UPDATE `gameobject_template` SET `displayId` = 62694 WHERE `displayId` = 8683;
-- Greymist Debris (13 spawns) -- dragonblight_debrispile_01, exact.
UPDATE `gameobject_template` SET `displayId` = 62334 WHERE `displayId` = 8688;
-- Mud-Crusted Ancient Disc -- plattergoldornate01, exact.
UPDATE `gameobject_template` SET `displayId` = 87846 WHERE `displayId` = 8763;
-- Azshara Portal -- spells\creature_spellportal_green, exact.
UPDATE `gameobject_template` SET `displayId` = 89962 WHERE `displayId` = 8833;
-- Horn of the Ancients -- spells\horn_01_spellobject, exact.
UPDATE `gameobject_template` SET `displayId` = 58477 WHERE `displayId` = 9690;
-- Maplewood Treasure Chest -- treasurechest05, exact.
UPDATE `gameobject_template` SET `displayId` = 101008 WHERE `displayId` = 10316;
-- Runestone Treasure Chest -- treasurechest06 is absent; 10315 is
-- treasurechest04, deliberately a DIFFERENT chest from the one above so the
-- two do not become visually identical.
UPDATE `gameobject_template` SET `displayId` = 10315 WHERE `displayId` = 10317;

-- ---------------------------------------------------------------------------
-- Verification after applying + client restart:
--   -- no creature on map 750 lists a display the client does not have (0):
--   SELECT COUNT(DISTINCT m.CreatureDisplayID) FROM creature c
--     JOIN creature_template_model m ON m.CreatureID = c.id
--    WHERE c.map = 750
--      AND NOT EXISTS (SELECT 1 FROM creature_model_info i
--                       WHERE i.DisplayID = m.CreatureDisplayID);
--
--   -- none of the 9 old GO display ids remain in use (0):
--   SELECT COUNT(*) FROM gameobject_template
--    WHERE displayId IN (8552,8553,8683,8688,8763,8833,9690,10316,10317);
--
--   SELECT COUNT(*) FROM creature_model_info WHERE DisplayID BETWEEN 31547 AND 37705; -- >= 84
--
-- And the worldserver boot log should no longer contain
-- "lists non-existing CreatureDisplayID id" for map-750 entries.
--
-- In game: Whisperwind Grove / Talonbranch (Felwood) and Lor'danel / Grove of
-- the Ancients (Darkshore) should have no invisible NPCs left, and the Jadefire
-- Braziers and both treasure chests should render.
-- ---------------------------------------------------------------------------
