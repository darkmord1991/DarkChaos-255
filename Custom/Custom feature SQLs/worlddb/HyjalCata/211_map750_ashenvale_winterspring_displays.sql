-- ---------------------------------------------------------------------------
-- 211  Map 750 -- the 62 creature displays Ashenvale and Winterspring need
-- ---------------------------------------------------------------------------
-- PREREQUISITE for 212_. Apply and deploy this FIRST, or the spawns 212_ adds
-- will not load at all: when a CreatureDisplayID does not resolve, ObjectMgr
-- drops the `creature_template_model` row, the template ends up with zero
-- models, and every spawn of it is refused with
--     "Creature (Entry: N) has no model defined in table
--      `creature_template_model`, can't load."
-- That is the same failure 188_/201_ chased; this file front-runs it.
--
-- WHY THESE 62 AND NOT MORE. The two zones need 109 new creature templates
-- between them, referencing 165 distinct display ids. 103 of those already
-- exist in our client and are left alone. Only 62 are genuinely absent --
-- 32 for Ashenvale, 30 for Winterspring -- and each was checked
-- against the LIVE server DBC with read_server_dbc, not against the SQL overlay,
-- because a display counts as present if it is in EITHER and the overlay alone
-- reports false gaps.
--
-- SOURCE -- K:\UntouchedClients\Cata, Data\enUS\locale-enUS.MPQ.
-- Same extraction and column mapping as 201_: Cata CreatureDisplayInfo is 17
-- fields / 68 bytes against our 16 / 64, columns 0-13 map 1:1 (calibrated on
-- 800 ids present in both), Cata's extra field sits after 13, and our last two
-- (CreatureGeosetData, ObjectEffectPackageID) are 0 for every one of these.
-- CreatureDisplayInfoExtra is 21 fields on both sides and maps 1:1 -- note the
-- SQL overlay spells the item columns NPCItemDisplay1 with NO underscore.
--
-- 38 of the 62 carry an ExtendedDisplayInfoID, so their Extra rows come
-- across too. Skipping those would leave the humanoids rendering untextured
-- white, which is the known failure mode on this client.
--
-- CreatureModelData ids referenced: 50, 51, 52, 55, 56, 59, 83, 110, 124, 187, 373, 831, 832, 911, 2208, 2259, 2588, 3078, 3256, 500793, 500907, 501055, 502133
-- Seven Cata model ids were absent from our client and are remapped: 3193->501055, 3466->500793, 3513->500907, 3543->3078, 3592->110, 3747->3256, 3849->502133
-- FOUR of those are EXACT swaps, not substitutions -- earlier downport work
-- already brought the identical .m2 in under a DC custom id (MISTFOX 501055,
-- GREATERSLIME 500793, MECHANICALRABBIT 500907, SABRECUB 502133), so those NPCs
-- look exactly right. The other three fall back to the nearest stock model of
-- the same family: the Cataclysm tentacle to the Yogg-Saron tentacle, the
-- unbound water elemental to the stock water elemental, and the generic ice
-- block to Sindragosa's. Left unmapped they would render as the blue ErrorCube.
--
-- THE SQL ALONE IS NOT ENOUGH -- this is the step that bit us. Inserting into
-- `creaturedisplayinfo_dbc` does NOT make the running server see the rows:
-- verified after a restart with all 62 present in the overlay, the server's own
-- CreatureDisplayInfo.dbc still had 28,207 records and every spawn using them
-- failed with "has no model 36388 defined in table `creature_template_model`".
-- The SERVER's binary DBC is authoritative at runtime; the overlay table is the
-- source the DBC is rebuilt FROM, not a runtime merge.
--
-- Full sequence:
--   1. apply this file to acore_world
--   2. rebuild both DBCs from Custom/CSV DBC (already done -- CreatureDisplayInfo
--      28,207 -> 28,269 and CreatureDisplayInfoExtra 16,252 -> 16,290, ID-set
--      diffed against the previous .dbc: 0 lost)
--   3. deploy Custom/DBCs/CreatureDisplayInfo.dbc and
--      CreatureDisplayInfoExtra.dbc to the SERVER at
--      /home/wowcore/azeroth-server/data/dbc   <-- gates whether spawns load
--   4. deploy the same two into the CLIENT patches (patch-4 and
--      enGB/patch-enGB-3, per the usual layering)  <-- gates whether they render
--   5. restart worldserver, then apply 212_
-- Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) creaturedisplayinfo_dbc
-- ---------------------------------------------------------------------------
DELETE FROM `creaturedisplayinfo_dbc` WHERE `ID` IN (
28474, 28500, 28540, 28541, 28542, 28543, 28544, 28566, 28567, 28568, 28569, 28590, 28591, 28593, 28594, 28596, 28601, 28602, 28603, 28604, 28627, 29095, 29173, 33085, 33446, 33447, 33448, 33449, 33559, 33568, 33569, 33571, 33572, 34202, 36097, 36106, 36212, 36257, 36264, 36265, 36276, 36354, 36388, 36390, 36424, 36741, 36744, 36748, 36749, 36750, 36764, 36765, 36766, 36768, 37415, 37540, 37567, 37712, 37949, 37950, 38055, 38279);

INSERT INTO `creaturedisplayinfo_dbc`
    (`ID`,`ModelID`,`SoundID`,`ExtendedDisplayInfoID`,`CreatureModelScale`,`CreatureModelAlpha`,
     `TextureVariation_1`,`TextureVariation_2`,`TextureVariation_3`,`PortraitTextureName`,
     `BloodLevel`,`BloodID`,`NPCSoundID`,`ParticleColorID`,`CreatureGeosetData`,`ObjectEffectPackageID`)
VALUES
  (28474, 187, 0, 0, 3.0000, 128, 'AncientofLoreSkin', '', '', '', 4, 0, 94, 0, 0, 0),
  (28500, 187, 0, 0, 3.0000, 255, 'AncientofLoreSkin', '', '', '', 4, 0, 0, 0, 0, 0),
  (28540, 56, 0, 18932, 1.1000, 255, '', '', '', '', 0, 0, 51, 0, 0, 0),
  (28541, 56, 0, 18957, 1.0000, 255, '', '', '', '', 0, 0, 52, 0, 0, 0),
  (28542, 56, 0, 18958, 1.0000, 255, '', '', '', '', 0, 0, 52, 0, 0, 0),
  (28543, 56, 0, 18959, 1.0000, 255, '', '', '', '', 0, 0, 52, 0, 0, 0),
  (28544, 56, 0, 18960, 1.0000, 255, '', '', '', '', 0, 0, 52, 0, 0, 0),
  (28566, 51, 0, 18963, 1.0000, 255, '', '', '', '', 1, 0, 60, 0, 0, 0),
  (28567, 51, 0, 18964, 1.0000, 255, '', '', '', '', 1, 0, 62, 0, 0, 0),
  (28568, 59, 0, 18966, 1.0000, 255, '', '', '', '', 1, 0, 0, 0, 0, 0),
  (28569, 52, 0, 18965, 1.0000, 255, '', '', '', '', 1, 0, 57, 0, 0, 0),
  (28590, 56, 0, 18969, 1.0000, 255, '', '', '', '', 0, 0, 52, 0, 0, 0),
  (28591, 56, 0, 18970, 1.0000, 255, '', '', '', '', 0, 0, 52, 0, 0, 0),
  (28593, 56, 0, 18971, 1.0000, 255, '', '', '', '', 0, 0, 52, 0, 0, 0),
  (28594, 56, 0, 18972, 1.0000, 255, '', '', '', '', 0, 0, 52, 0, 0, 0),
  (28596, 55, 0, 18973, 1.0500, 255, '', '', '', '', 0, 0, 121, 0, 0, 0),
  (28601, 831, 0, 18975, 1.1000, 255, '', '', '', '', 1, 0, 362, 0, 0, 0),
  (28602, 831, 0, 18976, 1.0000, 255, '', '', '', '', 1, 0, 363, 0, 0, 0),
  (28603, 832, 0, 18977, 1.1000, 255, '', '', '', '', 1, 0, 360, 0, 0, 0),
  (28604, 832, 0, 18978, 1.0000, 255, '', '', '', '', 1, 0, 361, 0, 0, 0),
  (28627, 56, 0, 18989, 1.0000, 255, '', '', '', '', 0, 0, 53, 0, 0, 0),
  (29095, 51, 0, 19223, 1.2000, 255, '', '', '', '', 0, 0, 60, 0, 0, 0),
  (29173, 51, 0, 19254, 1.0000, 255, '', '', '', '', 0, 0, 126, 0, 0, 0),
  (33085, 831, 0, 21942, 1.0000, 255, '', '', '', '', 0, 0, 363, 0, 0, 0),
  (33446, 51, 0, 22178, 1.0000, 255, '', '', '', '', 0, 0, 60, 0, 0, 0),
  (33447, 51, 0, 22176, 1.0000, 255, '', '', '', '', 0, 0, 60, 0, 0, 0),
  (33448, 52, 0, 22177, 1.0000, 255, '', '', '', '', 0, 0, 58, 0, 0, 0),
  (33449, 52, 0, 22179, 1.0000, 255, '', '', '', '', 0, 0, 58, 0, 0, 0),
  (33559, 500907, 0, 0, 1.0000, 255, 'MechanicalRabbit', '', '', '', 0, 0, 0, 0, 0, 0),
  (33568, 52, 0, 22282, 1.0000, 255, '', '', '', '', 1, 0, 123, 0, 0, 0),
  (33569, 52, 0, 22283, 1.0000, 255, '', '', '', '', 1, 0, 57, 0, 0, 0),
  (33571, 51, 0, 22284, 1.0000, 255, '', '', '', '', 0, 0, 126, 0, 0, 0),
  (33572, 52, 0, 22285, 1.0000, 255, '', '', '', '', 1, 0, 57, 0, 0, 0),
  (34202, 3078, 0, 0, 1.0000, 255, 'YoggSaronBodySkinTentacleBlue', '', '', '', -1, 0, 0, 0, 0, 0),
  (36097, 832, 0, 23890, 1.0000, 255, '', '', '', '', -1, 0, 360, 0, 0, 0),
  (36106, 500793, 0, 0, 1.5000, 255, 'GreaterSlimeFaceGreen', 'GreaterSlimeTrailGreen', '', '', -1, 0, 0, 0, 0, 0),
  (36212, 110, 0, 0, 2.0000, 255, 'BoundWaterElemental_Blue1', 'UnboundWaterElemental_Blue2', '', '', -1, 0, 0, 588, 0, 0),
  (36257, 2208, 0, 23995, 1.0000, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
  (36264, 2208, 0, 23992, 1.0000, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
  (36265, 2208, 0, 23993, 1.0000, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
  (36276, 500793, 81, 0, 1.0000, 255, 'GreaterSlimeAqua', 'GreaterSlimeTrailAqua', '', '', -1, 0, 0, 0, 0, 0),
  (36354, 831, 0, 24041, 1.0000, 255, '', '', '', '', 0, 0, 66, 0, 0, 0),
  (36388, 501055, 0, 0, 0.5000, 255, 'MistFoxSkinArctic', '', '', '', 0, 0, 0, 0, 0, 0),
  (36390, 2259, 0, 0, 0.6000, 255, 'PolarBearCubSkin', '', '', '', 0, 0, 0, 0, 0, 0),
  (36424, 2588, 0, 0, 2.5000, 255, 'YetiSkin1', 'YetiSkin2', '', '', -1, 0, 0, 0, 0, 0),
  (36741, 110, 0, 0, 2.0000, 255, 'BoundWaterElemental_Gray1', 'UnboundWaterElemental_Gray2', '', '', -1, 0, 0, 588, 0, 0),
  (36744, 51, 0, 24231, 1.0000, 255, '', '', '', '', 1, 0, 60, 0, 0, 0),
  (36748, 83, 0, 0, 0.5000, 160, 'BearSkinWhite', '', '', '', 1, 0, 0, 0, 0, 0),
  (36749, 124, 0, 0, 0.5500, 160, 'DeerSkin', '', '', '', 1, 0, 0, 0, 0, 0),
  (36750, 373, 0, 0, 0.3000, 120, 'OwlWhite', '', '', '', -1, 0, 0, 0, 0, 0),
  (36764, 500793, 0, 0, 1.5000, 255, 'GreaterSlimeFacePurple', 'GreaterSlimeTrailPurple', '', '', -1, 0, 0, 0, 0, 0),
  (36765, 500793, 0, 0, 1.5000, 255, 'GreaterSlimeFaceBlack', 'GreaterSlimeFaceBlack', '', '', -1, 0, 0, 0, 0, 0),
  (36766, 500793, 0, 0, 1.5000, 255, 'GreaterSlimeFaceAqua', 'GreaterSlimeFaceAqua', '', '', -1, 0, 0, 0, 0, 0),
  (36768, 2208, 0, 24242, 1.0000, 255, '', '', '', '', -1, 0, 149, 0, 0, 0),
  (37415, 110, 0, 0, 6.0000, 255, 'BoundWaterElemental_Blue1', 'UnboundWaterElemental_Blue2', '', '', -1, 0, 0, 588, 0, 0),
  (37540, 911, 829, 0, 1.0000, 255, 'WormSkinPurple', '', '', '', -1, 0, 0, 0, 0, 0),
  (37567, 373, 0, 0, 2.0000, 255, 'OwlBlue', '', '', '', -1, 0, 0, 0, 0, 0),
  (37712, 502133, 3903, 0, 0.3300, 255, 'RidingTigerSkinLavender', '', '', '', 1, 0, 220, 0, 0, 0),
  (37949, 502133, 2208, 0, 0.3300, 255, 'RidingTigerSkinWhitenosaddle', '', '', '', 1, 0, 220, 0, 0, 0),
  (37950, 502133, 0, 0, 0.3300, 255, 'RidingTigerSkinNostripeWhitenosaddle', '', '', '', 1, 0, 220, 0, 0, 0),
  (38055, 50, 0, 25136, 1.0000, 255, '', '', '', '', 1, 0, 47, 0, 0, 0),
  (38279, 3256, 0, 0, 0.5000, 255, '', '', '', 'creatureportrait_creature_iceblock', 2, 0, 0, 0, 0, 0);

-- ---------------------------------------------------------------------------
-- B) creaturedisplayinfoextra_dbc
-- ---------------------------------------------------------------------------
DELETE FROM `creaturedisplayinfoextra_dbc` WHERE `ID` IN (
18932, 18957, 18958, 18959, 18960, 18963, 18964, 18965, 18966, 18969, 18970, 18971, 18972, 18973, 18975, 18976, 18977, 18978, 18989, 19223, 19254, 21942, 22176, 22177, 22178, 22179, 22282, 22283, 22284, 22285, 23890, 23992, 23993, 23995, 24041, 24231, 24242, 25136);

INSERT INTO `creaturedisplayinfoextra_dbc`
    (`ID`,`DisplayRaceID`,`DisplaySexID`,`SkinID`,`FaceID`,`HairStyleID`,`HairColorID`,`FacialHairID`,
     `NPCItemDisplay1`,`NPCItemDisplay2`,`NPCItemDisplay3`,`NPCItemDisplay4`,`NPCItemDisplay5`,
     `NPCItemDisplay6`,`NPCItemDisplay7`,`NPCItemDisplay8`,`NPCItemDisplay9`,`NPCItemDisplay10`,
     `NPCItemDisplay11`,`Flags`,`BakeName`)
VALUES
  (18932, 4, 1, 5, 5, 0, 6, 9, 0, 0, 57943, 36545, 57944, 25538, 15450, 0, 0, 0, 0, 0, 'CreatureDisplayExtra-18932.blp'),
  (18957, 4, 1, 7, 3, 1, 0, 5, 8380, 57985, 6029, 0, 0, 6030, 6031, 0, 8305, 0, 0, 0, 'CreatureDisplayExtra-18957.blp'),
  (18958, 4, 1, 8, 4, 2, 1, 6, 8380, 57985, 6029, 0, 0, 6030, 6031, 0, 8305, 0, 0, 0, 'CreatureDisplayExtra-18958.blp'),
  (18959, 4, 1, 0, 7, 3, 4, 7, 8380, 57985, 6029, 0, 0, 6030, 6031, 0, 8305, 0, 0, 0, 'CreatureDisplayExtra-18959.blp'),
  (18960, 4, 1, 1, 8, 4, 5, 8, 8380, 57985, 6029, 0, 0, 6030, 6031, 0, 8305, 0, 0, 0, 'CreatureDisplayExtra-18960.blp'),
  (18963, 2, 0, 8, 4, 6, 2, 8, 0, 12525, 10962, 12920, 22816, 9195, 9196, 0, 9197, 0, 0, 0, 'CreatureDisplayExtra-18963.blp'),
  (18964, 2, 0, 0, 1, 7, 5, 7, 0, 12525, 10962, 12920, 22816, 9195, 9196, 0, 9197, 0, 0, 0, 'CreatureDisplayExtra-18964.blp'),
  (18965, 2, 1, 3, 3, 0, 1, 5, 0, 12525, 10962, 12920, 22816, 9195, 9196, 0, 9197, 0, 0, 0, 'CreatureDisplayExtra-18965.blp'),
  (18966, 6, 0, 0, 3, 11, 0, 5, 0, 12525, 10962, 12920, 22816, 9195, 9196, 0, 9197, 0, 0, 0, 'CreatureDisplayExtra-18966.blp'),
  (18969, 4, 1, 5, 1, 11, 7, 3, 8380, 57985, 57673, 0, 0, 6030, 8947, 0, 8305, 0, 0, 0, 'CreatureDisplayExtra-18969.blp'),
  (18970, 4, 1, 6, 2, 0, 5, 4, 8380, 0, 6029, 9010, 0, 6030, 6031, 0, 8954, 0, 0, 0, 'CreatureDisplayExtra-18970.blp'),
  (18971, 4, 1, 8, 6, 1, 2, 5, 0, 57985, 58004, 58005, 0, 6030, 0, 0, 0, 0, 0, 0, 'CreatureDisplayExtra-18971.blp'),
  (18972, 4, 1, 6, 6, 2, 2, 6, 0, 57985, 57673, 57674, 0, 6030, 6031, 0, 8305, 0, 0, 0, 'CreatureDisplayExtra-18972.blp'),
  (18973, 4, 0, 1, 0, 10, 2, 2, 0, 0, 58007, 6558, 58008, 3409, 4734, 2980, 2951, 0, 0, 0, 'CreatureDisplayExtra-18973.blp'),
  (18975, 9, 0, 2, 0, 0, 0, 0, 58021, 4594, 58022, 11233, 58023, 11619, 30434, 11617, 8398, 0, 0, 0, 'CreatureDisplayExtra-18975.blp'),
  (18976, 9, 0, 5, 3, 11, 6, 14, 58021, 4594, 58022, 11233, 58023, 11619, 30434, 11617, 8398, 0, 0, 0, 'CreatureDisplayExtra-18976.blp'),
  (18977, 9, 1, 2, 0, 0, 0, 0, 0, 4594, 58022, 11233, 58023, 11619, 30434, 11617, 8398, 0, 0, 0, 'CreatureDisplayExtra-18977.blp'),
  (18978, 9, 1, 1, 0, 0, 0, 0, 0, 4594, 58022, 11233, 58023, 11619, 30434, 11617, 8398, 0, 0, 0, 'CreatureDisplayExtra-18978.blp'),
  (18989, 4, 1, 0, 0, 7, 6, 8, 0, 5678, 58060, 58061, 0, 6030, 6031, 0, 12092, 0, 0, 0, 'CreatureDisplayExtra-18989.blp'),
  (19223, 2, 0, 3, 7, 9, 6, 10, 0, 29261, 58871, 35937, 58872, 29254, 29258, 29257, 29260, 0, 47729, 0, 'CreatureDisplayExtra-19223.blp'),
  (19254, 2, 0, 1, 7, 3, 5, 3, 0, 0, 11093, 0, 10880, 8140, 9653, 0, 7731, 0, 0, 0, 'CreatureDisplayExtra-19254.blp'),
  (21942, 9, 0, 7, 4, 13, 1, 15, 11976, 0, 63072, 0, 8606, 7710, 8354, 0, 8608, 0, 0, 0, 'CreatureDisplayExtra-21942.blp'),
  (22176, 2, 0, 2, 6, 6, 5, 3, 16115, 0, 59689, 29253, 58872, 29254, 29258, 0, 0, 0, 0, 0, 'CreatureDisplayExtra-22176.blp'),
  (22177, 2, 1, 3, 4, 7, 5, 2, 16115, 0, 59689, 29253, 58872, 29254, 29258, 0, 0, 0, 0, 0, 'CreatureDisplayExtra-22177.blp'),
  (22178, 2, 0, 3, 4, 4, 5, 0, 16115, 0, 59689, 29253, 58872, 29254, 29258, 0, 0, 0, 0, 0, 'CreatureDisplayExtra-22178.blp'),
  (22179, 2, 1, 2, 1, 1, 4, 3, 16115, 0, 59689, 29253, 58872, 29254, 29258, 0, 0, 0, 0, 0, 'CreatureDisplayExtra-22179.blp'),
  (22282, 2, 1, 6, 1, 0, 6, 2, 0, 0, 11806, 0, 0, 11804, 9672, 0, 11807, 0, 0, 0, 'CreatureDisplayExtra-22282.blp'),
  (22283, 2, 1, 3, 7, 12, 0, 2, 0, 0, 12127, 0, 0, 7781, 10115, 0, 7816, 0, 0, 0, 'CreatureDisplayExtra-22283.blp'),
  (22284, 2, 0, 3, 4, 5, 1, 7, 0, 0, 11127, 0, 8151, 9266, 7750, 0, 0, 0, 0, 0, 'CreatureDisplayExtra-22284.blp'),
  (22285, 2, 1, 2, 1, 4, 5, 5, 0, 0, 0, 6298, 11279, 11063, 12113, 0, 12114, 0, 0, 0, 'CreatureDisplayExtra-22285.blp'),
  (23890, 9, 1, 8, 1, 2, 5, 10, 0, 0, 62489, 62490, 62697, 62492, 62493, 0, 62494, 0, 0, 0, 'CreatureDisplayExtra-23890.blp'),
  (23992, 10, 0, 15, 2, 8, 1, 10, 0, 0, 69854, 66665, 69855, 66663, 66661, 66664, 66662, 0, 0, 0, 'CreatureDisplayExtra-23992.blp'),
  (23993, 10, 0, 13, 2, 10, 0, 10, 0, 0, 69854, 66665, 69855, 66663, 66661, 66664, 66662, 0, 0, 0, 'CreatureDisplayExtra-23993.blp'),
  (23995, 10, 0, 13, 2, 2, 1, 14, 45954, 45953, 59939, 46718, 46065, 45957, 46067, 0, 45955, 0, 0, 0, 'CreatureDisplayExtra-23995.blp'),
  (24041, 9, 0, 5, 1, 10, 4, 4, 0, 42521, 74830, 42021, 42017, 46824, 74831, 42522, 42020, 0, 0, 0, 'CreatureDisplayExtra-24041.blp'),
  (24231, 2, 0, 6, 5, 0, 5, 6, 75172, 0, 75173, 22583, 22588, 5965, 22434, 51133, 22435, 0, 26175, 0, 'CreatureDisplayExtra-24231.blp'),
  (24242, 10, 0, 14, 2, 3, 1, 10, 0, 35764, 75200, 35276, 35765, 35766, 35838, 35275, 75201, 0, 0, 0, 'CreatureDisplayExtra-24242.blp'),
  (25136, 1, 1, 6, 6, 8, 5, 0, 0, 33679, 0, 33628, 33632, 33630, 33694, 0, 33629, 0, 23077, 0, 'CreatureDisplayExtra-25136.blp');

-- ---------------------------------------------------------------------------
-- Verification after applying + DBC deploy + restart:
--   SELECT COUNT(*) FROM creaturedisplayinfo_dbc WHERE ID IN (28474, 28500, 28540, 28541, 28542, 28543, 28544, 28566, 28567, 28568, 28569, 28590, 28591, 28593, 28594, 28596, 28601, 28602, 28603, 28604, 28627, 29095, 29173, 33085, 33446, 33447, 33448, 33449, 33559, 33568, 33569, 33571, 33572, 34202, 36097, 36106, 36212, 36257, 36264, 36265, 36276, 36354, 36388, 36390, 36424, 36741, 36744, 36748, 36749, 36750, 36764, 36765, 36766, 36768, 37415, 37540, 37567, 37712, 37949, 37950, 38055, 38279);  -- 62
--
-- Then 212_ can be applied. If you apply 212_ without deploying the client
-- DBCs, the server side still works but those NPCs render as the default
-- placeholder for anyone whose client lacks the rows.
-- ---------------------------------------------------------------------------
