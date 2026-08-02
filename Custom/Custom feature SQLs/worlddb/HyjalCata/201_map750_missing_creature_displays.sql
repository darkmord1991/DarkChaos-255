-- ---------------------------------------------------------------------------
-- 201  Map 750 -- 71 more missing creature display IDs (28xxx-30xxx)
-- ---------------------------------------------------------------------------
-- The live Errors.log after the restart is full of
--     "Creature (Entry: 3733071) has no model defined in table
--      `creature_template_model`, can't load."
-- That message is the DOWNSTREAM symptom of a missing CreatureDisplayInfo row:
-- ObjectMgr drops the model row when the display id does not resolve, leaving
-- the template with zero models, and the spawn then refuses to load entirely.
--
-- WHY 188_ DID NOT CATCH THESE -- my own oversight. That audit filtered
-- `CreatureDisplayID > 31000` on the assumption that anything lower was stock
-- WotLK. These are 28321-30812, i.e. below the threshold, so they were never
-- looked at. They are Cataclysm additions that happen to sit in a low id range.
-- 195_ added their `creature_model_info` rows, but that is a DIFFERENT table
-- (server-side bounding data); the display rows were still absent.
--
-- Verified against the LIVE server with read_server_dbc, not just the CSV.
--
-- SOURCE -- K:\UntouchedClients\Cata, Data\enUS\locale-enUS.MPQ.
--   * CreatureDisplayInfo.dbc -- Cata has 17 fields / 68 bytes vs our 16 / 64.
--     Calibrated against 800 ids present in both: our columns 0-13 map 1:1 onto
--     cata 0-13 (100% agreement; column 4 is a float, which is why an integer
--     comparison mis-reports it). Cata's extra field sits after 13, and our
--     last two (CreatureGeosetData, ObjectEffectPackageID) are 0 for every one
--     of these 71 rows, so they are written as 0.
--   * CreatureDisplayInfoExtra.dbc -- both are 21 fields / 84 bytes and the
--     columns map 1:1 all the way: 0-7 appearance, 8-18 NPCItemDisplay1..11,
--     19 Flags, 20 BakeName. NOTE the SQL overlay spells the item columns
--     NPCItemDisplay1 (no underscore) unlike the DBC CSV -- getting that wrong
--     is what made the first attempt fail with 'Unknown column'.
--
-- THE PART THAT MATTERS MOST: 64 of the 71 displays reference an
-- ExtendedDisplayInfoID, and only ONE of those 64 exists here. These are
-- humanoid NPCs (Shatterspear trolls on troll bodies 185/186, night elf
-- sentinels, Forsaken). Zeroing ExtendedDisplayInfoID would have been the easy
-- fix and the WRONG one -- a character-race model with no Extra row renders
-- untextured/white, which is a known failure mode on this client. Section B
-- therefore imports the Extra rows too, so race/sex/skin/face/hair all come
-- across intact.
--
-- Only 19 distinct CreatureModelData ids are needed and 18 already exist in our
-- client, so almost no new art is involved. The one exception, model 3182, is
-- substituted with 186 (a troll body already present).
--
-- KNOWN COSMETIC LIMITATION: the Extra rows carry NPCItemDisplay item-display
-- ids from Cataclysm. Any of those our ItemDisplayInfo lacks will simply not
-- render that weapon or shoulder piece. The NPC itself, its skin and its face
-- are correct -- this only affects held/worn equipment.
--
-- Apply against acore_world, then rebuild+deploy CreatureDisplayInfo.dbc and
-- CreatureDisplayInfoExtra.dbc for the CLIENT as well (server-side overlays
-- alone make the spawns load; the client needs the DBC rows to draw them).
-- Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) creaturedisplayinfo_dbc -- the 71 display rows
-- ---------------------------------------------------------------------------
DELETE FROM `creaturedisplayinfo_dbc` WHERE `ID` IN (
28321, 28322, 28323, 28325, 28326, 28327, 28328, 28333, 28334, 28335, 28336, 28337, 28338, 28339, 28340, 28341, 28342, 28343, 28347, 28348, 28367, 28373, 28394, 28414, 28415, 28416, 28422, 28423, 28424, 28425, 28427, 28436, 28451, 28452, 28453, 28454, 28455, 28472, 28473, 28515, 28576, 29061, 29063, 29067, 29068, 29084, 29134, 29135, 29136, 29137, 29141, 29142, 29143, 29144, 29172, 29177, 29180, 29186, 29188, 29206, 29214, 29215, 29219, 29221, 29222, 29239, 29327, 30159, 30160, 30568, 30812);

INSERT INTO `creaturedisplayinfo_dbc`
    (`ID`,`ModelID`,`SoundID`,`ExtendedDisplayInfoID`,`CreatureModelScale`,`CreatureModelAlpha`,
     `TextureVariation_1`,`TextureVariation_2`,`TextureVariation_3`,`PortraitTextureName`,
     `BloodLevel`,`BloodID`,`NPCSoundID`,`ParticleColorID`,`CreatureGeosetData`,`ObjectEffectPackageID`)
VALUES
  (28321, 186, 0, 18780, 1.0000, 255, '', '', '', '', 1, 0, 75, 0, 0, 0),
  (28322, 186, 0, 18781, 1.0000, 255, '', '', '', '', 1, 0, 75, 0, 0, 0),
  (28323, 186, 0, 18782, 1.0000, 255, '', '', '', '', 1, 0, 75, 0, 0, 0),
  (28325, 185, 0, 18772, 1.0000, 255, '', '', '', '', 1, 0, 78, 0, 0, 0),
  (28326, 185, 0, 18774, 1.0000, 255, '', '', '', '', 1, 0, 78, 0, 0, 0),
  (28327, 185, 0, 18775, 1.0000, 255, '', '', '', '', 1, 0, 78, 0, 0, 0),
  (28328, 185, 0, 18776, 1.0000, 255, '', '', '', '', 1, 0, 78, 0, 0, 0),
  (28333, 185, 0, 18773, 1.0000, 255, '', '', '', '', 1, 0, 78, 0, 0, 0),
  (28334, 185, 0, 18777, 1.0000, 255, '', '', '', '', 1, 0, 78, 0, 0, 0),
  (28335, 185, 0, 18779, 1.0000, 255, '', '', '', '', 1, 0, 78, 0, 0, 0),
  (28336, 185, 0, 18778, 1.0000, 255, '', '', '', '', 1, 0, 78, 0, 0, 0),
  (28337, 185, 0, 18771, 1.0000, 255, '', '', '', '', 1, 0, 78, 0, 0, 0),
  (28338, 185, 0, 18783, 1.0000, 255, '', '', '', '', 1, 0, 78, 0, 0, 0),
  (28339, 186, 0, 18784, 1.0000, 255, '', '', '', '', 1, 0, 75, 0, 0, 0),
  (28340, 186, 0, 18785, 1.0000, 255, '', '', '', '', 1, 0, 75, 0, 0, 0),
  (28341, 185, 0, 18786, 1.0000, 255, '', '', '', '', 1, 0, 78, 0, 0, 0),
  (28342, 185, 0, 18791, 1.0000, 255, '', '', '', '', 1, 0, 78, 0, 0, 0),
  (28343, 185, 0, 18792, 1.0000, 255, '', '', '', '', 1, 0, 78, 0, 0, 0),
  (28347, 185, 0, 18794, 1.0000, 255, '', '', '', '', 1, 0, 78, 0, 0, 0),
  (28348, 186, 0, 18795, 1.0000, 255, '', '', '', '', 1, 0, 75, 0, 0, 0),
  (28367, 49, 0, 18797, 1.3000, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
  (28373, 56, 0, 18798, 1.0000, 255, '', '', '', '', 0, 0, 52, 0, 0, 0),
  (28394, 56, 0, 18799, 1.0000, 255, '', '', '', '', 0, 0, 51, 0, 0, 0),
  (28414, 185, 0, 18825, 1.0000, 255, '', '', '', '', 1, 0, 78, 0, 0, 0),
  (28415, 56, 0, 18826, 1.0000, 255, '', '', '', '', 0, 0, 51, 0, 0, 0),
  (28416, 56, 0, 18827, 1.0000, 255, '', '', '', '', 0, 0, 51, 0, 0, 0),
  (28422, 56, 0, 18829, 1.0000, 255, '', '', '', '', 1, 0, 52, 0, 0, 0),
  (28423, 55, 0, 18830, 1.1000, 255, '', '', '', '', 0, 0, 54, 0, 0, 0),
  (28424, 60, 0, 9111, 1.1000, 255, '', '', '', '', 1, 0, 0, 0, 0, 0),
  (28425, 185, 0, 18832, 1.2000, 255, '', '', '', '', 1, 0, 0, 0, 0, 0),
  (28427, 51, 0, 18833, 1.2000, 255, '', '', '', '', 1, 0, 0, 0, 0, 0),
  (28436, 56, 0, 18840, 1.0000, 255, '', '', '', '', 0, 0, 52, 0, 0, 0),
  (28451, 56, 0, 18847, 1.0000, 255, '', '', '', '', 0, 0, 51, 0, 0, 0),
  (28452, 55, 0, 18848, 1.0000, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
  (28453, 55, 0, 18849, 1.0000, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
  (28454, 56, 0, 18850, 1.0000, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
  (28455, 56, 0, 18851, 1.0000, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
  (28472, 56, 0, 18874, 1.0000, 255, '', '', '', '', 0, 0, 52, 0, 0, 0),
  (28473, 56, 0, 18875, 1.0000, 255, '', '', '', '', 0, 0, 52, 0, 0, 0),
  (28515, 2354, 0, 18919, 1.0000, 255, '', '', '', '', 1, 0, 0, 0, 0, 0),
  (28576, 51, 0, 18967, 1.0000, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
  (29061, 57, 0, 19216, 1.0000, 255, '', '', '', '', 1, 0, 82, 0, 0, 0),
  (29063, 55, 0, 19215, 1.0000, 255, '', '', '', '', 1, 0, 55, 0, 0, 0),
  (29067, 57, 0, 19217, 1.0000, 255, '', '', '', '', 1, 0, 83, 0, 0, 0),
  (29068, 58, 0, 19218, 1.0000, 255, '', '', '', '', 1, 0, 80, 0, 0, 0),
  (29084, 56, 0, 19219, 1.0000, 255, '', '', '', '', 1, 0, 52, 0, 0, 0),
  (29134, 51, 0, 19239, 1.0000, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
  (29135, 51, 0, 19244, 1.0000, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
  (29136, 59, 0, 19245, 1.0000, 255, '', '', '', '', 1, 0, 0, 0, 0, 0),
  (29137, 59, 0, 19246, 1.0000, 255, '', '', '', '', 1, 0, 0, 0, 0, 0),
  (29141, 185, 0, 19240, 1.0000, 255, '', '', '', '', 1, 0, 78, 0, 0, 0),
  (29142, 185, 0, 19241, 1.0000, 255, '', '', '', '', 1, 0, 78, 0, 0, 0),
  (29143, 186, 0, 19242, 1.0000, 255, '', '', '', '', 1, 0, 75, 0, 0, 0),
  (29144, 186, 0, 19243, 1.0000, 255, '', '', '', '', 1, 0, 75, 0, 0, 0),
  (29172, 56, 0, 19253, 1.0000, 255, '', '', '', '', -1, 0, 51, 0, 0, 0),
  (29177, 225, 0, 0, 1.0000, 110, 'OwlBearSkin', 'OwlBearSkin2', '', '', -1, 0, 0, 0, 0, 0),
  (29180, 1731, 0, 0, 10.0000, 255, '', '', '', '', -1, 0, 0, 0, 0, 0),
  (29186, 53, 0, 19256, 1.0000, 255, '', '', '', '', 1, 0, 37, 0, 0, 0),
  (29188, 53, 0, 19257, 1.0000, 255, '', '', '', '', 1, 0, 37, 0, 0, 0),
  (29206, 55, 0, 19331, 1.0000, 255, '', '', '', '', 1, 0, 59, 0, 0, 0),
  (29214, 55, 0, 19335, 1.2000, 255, '', '', '', '', 0, 0, 59, 0, 0, 0),
  (29215, 56, 0, 19336, 1.0000, 255, '', '', '', '', 1, 0, 52, 0, 0, 0),
  (29219, 2555, 2457, 0, 1.0000, 255, '', '', '', '', -1, 0, 0, 0, 0, 0),
  (29221, 49, 0, 19340, 1.0000, 255, '', '', '', '', 0, 0, 0, 0, 0, 0),
  (29222, 50, 0, 19341, 1.0000, 255, '', '', '', '', 1, 0, 0, 0, 0, 0),
  (29239, 67, 0, 0, 1.0000, 255, 'AncientProtectorPurple', '', '', '', 3, 0, 94, 0, 0, 0),
  (29327, 2923, 0, 0, 1.5000, 255, 'GoblinShredderMountSkin1_01', 'GoblinShredderMountSkin1_02', '', '', 2, 0, 0, 0, 0, 0),
  (30159, 186, 3499, 0, 0.3000, 255, 'WaterElementalSkin', '', '', '', 1, 0, 0, 290, 0, 0),
  (30160, 186, 3499, 0, 0.5000, 255, 'WaterElementalSkin', '', '', '', 1, 0, 0, 290, 0, 0),
  (30568, 59, 0, 20314, 1.0000, 255, '', '', '', '', 0, 0, 69, 0, 0, 0),
  (30812, 55, 0, 20512, 1.0000, 255, '', '', '', '', 1, 0, 59, 0, 0, 0);

-- ---------------------------------------------------------------------------
-- B) creaturedisplayinfoextra_dbc -- the humanoid appearance rows
-- ---------------------------------------------------------------------------
DELETE FROM `creaturedisplayinfoextra_dbc` WHERE `ID` IN (
9111, 18771, 18772, 18773, 18774, 18775, 18776, 18777, 18778, 18779, 18780, 18781, 18782, 18783, 18784, 18785, 18786, 18791, 18792, 18794, 18795, 18797, 18798, 18799, 18825, 18826, 18827, 18829, 18830, 18832, 18833, 18840, 18847, 18848, 18849, 18850, 18851, 18874, 18875, 18919, 18967, 19215, 19216, 19217, 19218, 19219, 19239, 19240, 19241, 19242, 19243, 19244, 19245, 19246, 19253, 19256, 19257, 19331, 19335, 19336, 19340, 19341, 20314, 20512);

INSERT INTO `creaturedisplayinfoextra_dbc`
    (`ID`,`DisplayRaceID`,`DisplaySexID`,`SkinID`,`FaceID`,`HairStyleID`,`HairColorID`,`FacialHairID`,
     `NPCItemDisplay1`,`NPCItemDisplay2`,`NPCItemDisplay3`,`NPCItemDisplay4`,`NPCItemDisplay5`,
     `NPCItemDisplay6`,`NPCItemDisplay7`,`NPCItemDisplay8`,`NPCItemDisplay9`,`NPCItemDisplay10`,
     `NPCItemDisplay11`,`Flags`,`BakeName`)
VALUES
  (9111, 6, 1, 7, 1, 3, 2, 1, 0, 1058, 29432, 10961, 9211, 11019, 0, 3704, 29433, 0, 0, 0, '518d3e30f3030ea571260b2b64bcb62.blp'),
  (18771, 8, 0, 6, 0, 9, 0, 1, 0, 0, 57583, 8182, 57584, 11008, 10938, 8183, 14509, 0, 0, 0, 'CreatureDisplayExtra-18771.blp'),
  (18772, 8, 0, 8, 0, 9, 0, 6, 0, 30928, 57585, 25862, 25866, 25868, 37940, 25861, 25865, 25983, 0, 0, 'CreatureDisplayExtra-18772.blp'),
  (18773, 8, 0, 6, 0, 6, 5, 8, 0, 57587, 57588, 11107, 57589, 11495, 57590, 11492, 16047, 0, 0, 0, 'CreatureDisplayExtra-18773.blp'),
  (18774, 8, 0, 8, 0, 2, 2, 6, 0, 30928, 57585, 25862, 25866, 25868, 37940, 25861, 25865, 25983, 0, 0, 'CreatureDisplayExtra-18774.blp'),
  (18775, 8, 0, 6, 0, 5, 7, 7, 0, 30928, 57585, 25862, 25866, 25868, 37940, 25861, 25865, 25983, 0, 0, 'CreatureDisplayExtra-18775.blp'),
  (18776, 8, 0, 6, 0, 6, 7, 8, 0, 30928, 57585, 25862, 25866, 25868, 37940, 25861, 25865, 25983, 0, 0, 'CreatureDisplayExtra-18776.blp'),
  (18777, 8, 0, 6, 0, 0, 3, 9, 0, 38630, 57588, 11107, 57589, 11495, 57590, 11492, 16047, 0, 0, 0, 'CreatureDisplayExtra-18777.blp'),
  (18778, 8, 0, 6, 0, 3, 6, 10, 0, 11272, 57588, 11107, 57589, 11495, 57590, 11492, 16047, 0, 0, 0, 'CreatureDisplayExtra-18778.blp'),
  (18779, 8, 0, 6, 0, 8, 6, 8, 0, 11272, 57588, 11107, 57589, 11495, 57590, 11492, 16047, 0, 0, 0, 'CreatureDisplayExtra-18779.blp'),
  (18780, 8, 1, 7, 0, 0, 8, 4, 0, 57587, 57591, 28028, 57592, 57593, 37259, 28032, 57594, 0, 0, 0, 'CreatureDisplayExtra-18780.blp'),
  (18781, 8, 1, 7, 0, 2, 9, 1, 0, 3871, 57591, 28028, 57592, 57593, 37259, 28032, 57594, 0, 0, 0, 'CreatureDisplayExtra-18781.blp'),
  (18782, 8, 1, 7, 0, 4, 1, 1, 0, 11272, 57591, 28028, 57592, 57593, 37259, 28032, 57594, 0, 0, 0, 'CreatureDisplayExtra-18782.blp'),
  (18783, 8, 0, 6, 0, 0, 0, 4, 0, 0, 57583, 8182, 57584, 11008, 10938, 8183, 14509, 0, 0, 0, 'CreatureDisplayExtra-18783.blp'),
  (18784, 8, 1, 7, 0, 5, 1, 5, 0, 0, 57583, 8182, 57584, 11008, 10938, 8183, 14509, 0, 0, 0, 'CreatureDisplayExtra-18784.blp'),
  (18785, 8, 1, 7, 0, 7, 6, 2, 0, 0, 57583, 8182, 57584, 11008, 10938, 8183, 14509, 0, 0, 0, 'CreatureDisplayExtra-18785.blp'),
  (18786, 8, 0, 6, 0, 6, 6, 8, 0, 53760, 57601, 47182, 57602, 47184, 57603, 47194, 47186, 0, 0, 0, 'CreatureDisplayExtra-18786.blp'),
  (18791, 8, 0, 6, 0, 1, 3, 3, 0, 59522, 57583, 8182, 0, 12169, 10938, 8183, 14509, 25983, 0, 0, 'CreatureDisplayExtra-18791.blp'),
  (18792, 8, 0, 7, 0, 4, 6, 4, 0, 59522, 57583, 8182, 0, 12169, 10938, 8183, 14509, 25983, 0, 0, 'CreatureDisplayExtra-18792.blp'),
  (18794, 8, 0, 6, 0, 8, 8, 8, 0, 50475, 57606, 57607, 57608, 57609, 57610, 47194, 57611, 0, 0, 0, 'CreatureDisplayExtra-18794.blp'),
  (18795, 8, 1, 6, 0, 2, 8, 2, 0, 53760, 57601, 47182, 57602, 47184, 57603, 47194, 47186, 0, 0, 0, 'CreatureDisplayExtra-18795.blp'),
  (18797, 1, 0, 0, 4, 12, 12, 7, 57624, 0, 57577, 13448, 13389, 13390, 4014, 0, 13392, 0, 0, 0, 'CreatureDisplayExtra-18797.blp'),
  (18798, 4, 1, 3, 13, 8, 4, 0, 8380, 57626, 6029, 0, 0, 6030, 6031, 0, 8305, 0, 0, 0, 'CreatureDisplayExtra-18798.blp'),
  (18799, 4, 1, 5, 0, 11, 3, 2, 16164, 24531, 0, 24532, 0, 11739, 0, 29238, 0, 0, 0, 0, 'CreatureDisplayExtra-18799.blp'),
  (18825, 8, 0, 6, 0, 8, 8, 10, 0, 47199, 57606, 57607, 57608, 57609, 57610, 47194, 57611, 0, 0, 0, 'CreatureDisplayExtra-18825.blp'),
  (18826, 4, 1, 4, 3, 4, 4, 1, 16164, 0, 0, 57667, 0, 6252, 0, 0, 0, 0, 0, 0, 'CreatureDisplayExtra-18826.blp'),
  (18827, 4, 1, 4, 3, 8, 5, 5, 16164, 0, 0, 75009, 0, 25538, 0, 0, 0, 0, 0, 0, 'CreatureDisplayExtra-18827.blp'),
  (18829, 4, 1, 5, 5, 4, 5, 9, 0, 5678, 57673, 57674, 0, 6030, 6031, 0, 7658, 0, 0, 0, 'CreatureDisplayExtra-18829.blp'),
  (18830, 4, 0, 2, 8, 8, 4, 4, 0, 0, 57682, 29974, 57683, 29975, 0, 0, 29979, 0, 0, 0, 'CreatureDisplayExtra-18830.blp'),
  (18832, 8, 0, 5, 4, 7, 6, 7, 0, 0, 57684, 13388, 54366, 13390, 13396, 0, 13393, 0, 0, 0, 'CreatureDisplayExtra-18832.blp'),
  (18833, 2, 0, 5, 3, 4, 4, 4, 0, 0, 57684, 13388, 54366, 13390, 13396, 0, 13393, 0, 0, 0, 'CreatureDisplayExtra-18833.blp'),
  (18840, 4, 1, 5, 0, 10, 5, 9, 8380, 5678, 6029, 0, 0, 6030, 6031, 0, 8305, 0, 0, 0, 'CreatureDisplayExtra-18840.blp'),
  (18847, 4, 1, 5, 4, 7, 10, 6, 0, 0, 23978, 23978, 57761, 9686, 6909, 0, 0, 0, 0, 0, 'CreatureDisplayExtra-18847.blp'),
  (18848, 4, 0, 1, 0, 6, 3, 4, 0, 0, 57762, 57763, 57764, 4469, 4472, 0, 4470, 0, 0, 0, 'CreatureDisplayExtra-18848.blp'),
  (18849, 4, 0, 3, 2, 8, 5, 0, 0, 0, 57765, 12165, 57766, 2897, 57767, 0, 7658, 0, 0, 0, 'CreatureDisplayExtra-18849.blp'),
  (18850, 4, 1, 1, 1, 1, 0, 9, 0, 0, 57768, 57769, 57770, 11739, 0, 0, 7658, 0, 0, 0, 'CreatureDisplayExtra-18850.blp'),
  (18851, 4, 1, 2, 8, 8, 6, 2, 0, 0, 57771, 6029, 57772, 6030, 33221, 7658, 0, 0, 0, 0, 'CreatureDisplayExtra-18851.blp'),
  (18874, 4, 1, 5, 3, 6, 0, 8, 8380, 51984, 57821, 0, 0, 19680, 13462, 0, 57822, 0, 49028, 0, 'CreatureDisplayExtra-18874.blp'),
  (18875, 4, 1, 5, 3, 3, 2, 7, 8380, 50179, 6029, 0, 0, 6030, 6031, 0, 57822, 0, 0, 0, 'CreatureDisplayExtra-18875.blp'),
  (18919, 13, 1, 2, 0, 0, 0, 0, 0, 0, 57917, 35302, 57918, 0, 0, 35283, 0, 0, 0, 0, 'CreatureDisplayExtra-18919.blp'),
  (18967, 2, 0, 3, 4, 5, 7, 10, 49540, 13697, 49262, 4492, 46416, 46395, 8391, 0, 0, 47955, 0, 0, 'CreatureDisplayExtra-18967.blp'),
  (19215, 4, 0, 0, 7, 2, 2, 0, 5677, 58723, 58724, 8732, 8431, 4312, 22487, 0, 46511, 0, 0, 0, 'CreatureDisplayExtra-19215.blp'),
  (19216, 5, 0, 5, 1, 9, 7, 13, 0, 0, 58726, 23605, 22935, 3201, 23365, 6199, 27041, 0, 23103, 0, 'CreatureDisplayExtra-19216.blp'),
  (19217, 5, 0, 0, 4, 11, 0, 5, 0, 0, 58727, 6370, 8139, 3201, 3066, 0, 58728, 0, 0, 0, 'CreatureDisplayExtra-19217.blp'),
  (19218, 5, 1, 3, 9, 0, 2, 4, 0, 0, 58729, 11141, 8139, 3201, 3066, 0, 58730, 0, 0, 0, 'CreatureDisplayExtra-19218.blp'),
  (19219, 4, 1, 3, 6, 2, 7, 3, 0, 1057, 58741, 0, 3251, 3078, 3080, 2178, 2359, 0, 0, 0, 'CreatureDisplayExtra-19219.blp'),
  (19239, 2, 0, 7, 2, 3, 5, 4, 0, 25545, 57585, 25862, 25866, 25868, 37940, 25861, 25865, 25983, 0, 0, 'CreatureDisplayExtra-19239.blp'),
  (19240, 8, 0, 6, 0, 6, 5, 8, 0, 59515, 57588, 11107, 57589, 11495, 57590, 11492, 16047, 0, 0, 0, 'CreatureDisplayExtra-19240.blp'),
  (19241, 8, 0, 6, 0, 1, 4, 7, 0, 59515, 57588, 11107, 57589, 11495, 57590, 11492, 16047, 0, 0, 0, 'CreatureDisplayExtra-19241.blp'),
  (19242, 8, 1, 6, 0, 2, 3, 3, 0, 59515, 57588, 11107, 57589, 11495, 57590, 11492, 16047, 0, 0, 0, 'CreatureDisplayExtra-19242.blp'),
  (19243, 8, 1, 6, 0, 4, 5, 4, 0, 59515, 57588, 11107, 57589, 11495, 57590, 11492, 16047, 0, 0, 0, 'CreatureDisplayExtra-19243.blp'),
  (19244, 2, 0, 7, 2, 5, 6, 4, 0, 25545, 57585, 25862, 25866, 25868, 37940, 25861, 25865, 25983, 0, 0, 'CreatureDisplayExtra-19244.blp'),
  (19245, 6, 0, 6, 3, 2, 0, 2, 0, 25545, 57585, 25862, 25866, 25868, 37940, 25861, 25865, 25983, 0, 0, 'CreatureDisplayExtra-19245.blp'),
  (19246, 6, 0, 0, 2, 2, 0, 6, 0, 25545, 57585, 25862, 25866, 25868, 37940, 25861, 25865, 25983, 0, 0, 'CreatureDisplayExtra-19246.blp'),
  (19253, 4, 1, 2, 2, 0, 7, 3, 0, 13697, 59557, 59558, 13699, 18043, 59559, 18029, 59560, 0, 0, 0, 'CreatureDisplayExtra-19253.blp'),
  (19256, 3, 0, 2, 1, 0, 9, 7, 15907, 0, 5315, 1727, 0, 59653, 2166, 0, 0, 0, 0, 0, 'CreatureDisplayExtra-19256.blp'),
  (19257, 3, 0, 0, 5, 11, 0, 3, 0, 0, 10304, 5440, 6062, 4617, 14046, 0, 0, 0, 0, 0, 'CreatureDisplayExtra-19257.blp'),
  (19331, 4, 0, 0, 1, 7, 2, 4, 0, 0, 0, 59852, 12036, 7622, 4314, 0, 3999, 0, 0, 0, 'CreatureDisplayExtra-19331.blp'),
  (19335, 4, 0, 1, 0, 10, 6, 2, 0, 59863, 0, 0, 47942, 47943, 47944, 51617, 0, 0, 0, 0, 'CreatureDisplayExtra-19335.blp'),
  (19336, 4, 1, 0, 0, 9, 5, 0, 0, 59863, 59864, 59865, 59866, 49358, 49178, 49179, 59867, 0, 0, 0, 'CreatureDisplayExtra-19336.blp'),
  (19340, 1, 0, 3, 11, 0, 10, 6, 0, 45379, 57577, 13448, 13389, 13390, 4014, 0, 13392, 0, 0, 0, 'CreatureDisplayExtra-19340.blp'),
  (19341, 1, 1, 10, 0, 22, 11, 0, 59872, 0, 57577, 13448, 13389, 13390, 4014, 0, 13392, 0, 39504, 0, 'CreatureDisplayExtra-19341.blp'),
  (20314, 6, 0, 1, 2, 9, 0, 5, 0, 0, 8215, 9194, 0, 24717, 23878, 0, 63234, 0, 0, 0, 'CreatureDisplayExtra-20314.blp'),
  (20512, 4, 0, 5, 2, 1, 5, 3, 0, 53869, 53870, 53871, 53872, 57634, 53874, 53875, 53876, 0, 29720, 0, 'CreatureDisplayExtra-20512.blp');

-- ---------------------------------------------------------------------------
-- Verification after applying + DBC deploy + restart:
--   SELECT COUNT(*) FROM creaturedisplayinfo_dbc WHERE ID BETWEEN 28321 AND 30812;  -- 71
--   SELECT COUNT(*) FROM creaturedisplayinfoextra_dbc WHERE ID BETWEEN 9111 AND 19000;
--
-- Errors.log should gain no further "has no model defined in table
-- `creature_template_model`, can't load" lines for the 3.6M/3.7M entry range,
-- and the Shatterspear camp in Darkshore should be populated rather than empty.
-- ---------------------------------------------------------------------------
