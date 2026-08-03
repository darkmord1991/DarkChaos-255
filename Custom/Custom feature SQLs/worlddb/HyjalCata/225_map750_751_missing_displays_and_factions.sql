-- ---------------------------------------------------------------------------
-- 225  Map 750/751 -- 40 missing creature displays + 3 missing faction templates
-- ---------------------------------------------------------------------------
-- SYMPTOM, and the message names the wrong table:
--     Creature (Entry: 3606196) has no model defined in table
--     `creature_template_model`, can't load.        (x hundreds per boot)
-- Every one of those entries DOES have creature_template_model rows, and
-- creature_model_info rows too. The real cause is one layer up: the display id
-- is absent from CreatureDisplayInfo.dbc, so ObjectMgr `continue`s past the
-- model at load, the template ends up with ZERO models, and the spawn is
-- refused. Rule of thumb from the earlier round: id ABSENT from the message ->
-- creature_template_model / the DBC; id PRESENT -> creature_model_info.
--
-- SCOPE, measured rather than sampled: of 2,074 distinct display ids used by
-- spawned clone-band entries, 975 are above the stock range and exactly 40 of
-- those are missing from the live server DBC. They are the only models 32
-- entries have, so 277 spawns never load.
--
-- NOT a regression of the 2026-08-01 fix. That round's 84 displays are all
-- still present in both the CSV and the live DBC (spot-checked 8). This is a
-- fresh set that arrived with the later terrain-spawn imports.
--
-- METHOD -- identical to that round, and re-verified against its own rows:
--   * keep the Cata display id and its CreatureModelScale
--   * repoint ModelID at a CreatureModelData row the client ALREADY has
--   * keep ExtendedDisplayInfoID and downport the Extra row verbatim
--   * keep Cata's TextureVariation strings
-- 34 of the 40 resolved to a model already in our client. NOTHING new ships as
-- a file, which is the whole point -- extracting the real Cata models buys no
-- fidelity (retail stores textures as FileDataIDs, so they arrive untextured)
-- and raw character models are a known client-crasher here.
--
-- TEXTURES WERE PROBED, NOT ASSUMED. Every TextureVariation name below was
-- looked up in the client archives: Hobgoblin1Green/Grey/Purple, all four
-- Chimera skins and SirenSkinAqua are present. The ONE that was not is Cata's
-- NagaMale_Silver (renamed since 3.3.5), so display 31533 uses our proven
-- NagaMaleSkinSilver + NagaMaleSkinSilverFins pair instead.
--
-- THE 6 WITH NO EQUIVALENT MODEL, substituted by eye:
--   30309 Bilgewater Mortar   goblin mortar doodad -> Creature/Object/Cannon
--   31533 Spitelash Myrmidon  cata NAGAMALE_LOW01 (a LOD variant) -> full NagaMale
--   36114 Drink Tray          -> G_ThanksgivingPlate_01
--   36115/36116/36117 Goblin Cocktail -> jug01
--
-- 11 of the 45 NPCItemDisplay ids the Extra rows reference are Cata armour we
-- do not have; those slots simply render nothing. Goblin (race 9) CharSections
-- are present (1,364 rows), so the bakes themselves work.
--
-- FACTIONS: 2161, 2201, 2327 were the last 3 Cata faction templates missing
-- (Palace Mook x12, Bilgewater Bruiser, Grounded Wind Rider, Alexstrasza).
-- Cata's FactionTemplate.dbc layout is identical to 3.3.5, so they copy
-- verbatim, and all three parent Faction ids (50, 66, 1133) already exist here
-- -- no Faction.dbc change needed.
--
-- THIS FILE IS NOT WHAT FIXES IT. The `*_dbc` tables are an overlay the server
-- does NOT read at runtime -- proven 2026-08-02, when 62 overlay rows changed
-- nothing until the binary was rebuilt. They are kept in sync because they are
-- the source the DBC is rebuilt FROM. The binaries are already compiled and
-- verified (0 rows lost, +40/+26/+3 gained) and deployed into the client
-- archives; what is still outstanding is copying them to the SERVER's
-- data/dbc, which is what actually lets these spawns load:
--     Custom/DBCs/CreatureDisplayInfo.dbc        28510 -> 28550
--     Custom/DBCs/CreatureDisplayInfoExtra.dbc   16493 -> 16519
--     Custom/DBCs/FactionTemplate.dbc              894 ->   897
-- ---------------------------------------------------------------------------

-- --- 40 creature displays -------------------------------------------------
DELETE FROM `creaturedisplayinfo_dbc` WHERE `ID` IN (28480, 28481, 28490, 28491, 29670, 30091, 30092, 30093, 30094, 30095, 30230, 30309, 30418, 30420, 30421, 30422, 30423, 30425, 30427, 30431, 30432, 30434, 30435, 30437, 31288, 31482, 31533, 33003, 34569, 36114, 36115, 36116, 36117, 36244, 36245, 36246, 36247, 37284, 37569, 37570);
INSERT INTO `creaturedisplayinfo_dbc`
 (`ID`, `ModelID`, `SoundID`, `ExtendedDisplayInfoID`, `CreatureModelScale`, `CreatureModelAlpha`, `TextureVariation_1`, `TextureVariation_2`, `TextureVariation_3`, `PortraitTextureName`, `BloodLevel`, `BloodID`, `NPCSoundID`, `ParticleColorID`, `CreatureGeosetData`, `ObjectEffectPackageID`) VALUES
(28480, 51, 0, 18885, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(28481, 52, 0, 18887, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(28490, 58, 0, 18903, 1.05, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(28491, 57, 0, 18902, 1.1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(29670, 49, 0, 5185, 1.2, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(30091, 831, 0, 19935, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(30092, 50, 0, 19930, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(30093, 58, 0, 19934, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(30094, 57, 0, 19931, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(30095, 182, 0, 19933, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(30230, 56, 0, 20061, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(30309, 290, 0, 0, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(30418, 3194, 0, 0, 1.5, 255, 'Hobgoblin1Green', 'Hobgoblin2', '', '', 1, 1, 0, 0, 0, 0),
(30420, 831, 0, 20181, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(30421, 831, 0, 20182, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(30422, 831, 0, 20183, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(30423, 51, 0, 20185, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(30425, 51, 0, 20186, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(30427, 832, 0, 20184, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(30431, 831, 0, 20191, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(30432, 831, 0, 20190, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(30434, 831, 0, 20192, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(30435, 831, 0, 20193, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(30437, 831, 0, 20196, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(31288, 3194, 0, 0, 1.5, 255, 'Hobgoblin1Grey', 'Hobgoblin2', '', '', 1, 1, 0, 0, 0, 0),
(31482, 3194, 0, 0, 1.5, 255, 'Hobgoblin1Purple', 'Hobgoblin2', '', '', 1, 1, 0, 0, 0, 0),
(31533, 332, 0, 0, 1, 255, 'NagaMaleSkinSilver', 'NagaMaleSkinSilverFins', '', '', 1, 1, 0, 0, 0, 0),
(33003, 3194, 0, 0, 1.5, 255, 'Hobgoblin1Red', 'Hobgoblin2', '', '', 1, 1, 0, 0, 0, 0),
(34569, 831, 0, 22830, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(36114, 3040, 0, 0, 0.5, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(36115, 3038, 0, 0, 0.5, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(36116, 3038, 0, 0, 0.5, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(36117, 3038, 0, 0, 0.5, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(36244, 832, 0, 23983, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(36245, 832, 0, 23984, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(36246, 832, 0, 23985, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(36247, 832, 0, 23986, 1, 255, '', '', '', '', 1, 1, 0, 0, 0, 0),
(37284, 531, 0, 0, 1.3, 255, 'SirenSkinAqua', '', '', '', 1, 1, 0, 0, 0, 0),
(37569, 351, 0, 0, 1.45, 255, 'ChimeraSkinGreen_01', 'ChimeraSkinGreen_02', '', '', 1, 1, 0, 0, 0, 0),
(37570, 351, 0, 0, 1.15, 255, 'ChimeraSkinBeige_01', 'ChimeraSkinBeige_02', '', '', 1, 1, 0, 0, 0, 0);


-- --- 26 character bakes those displays point at ---------------------------
DELETE FROM `creaturedisplayinfoextra_dbc` WHERE `ID` IN (18885, 18887, 18902, 18903, 19930, 19931, 19933, 19934, 19935, 20061, 20181, 20182, 20183, 20184, 20185, 20186, 20190, 20191, 20192, 20193, 20196, 22830, 23983, 23984, 23985, 23986);
INSERT INTO `creaturedisplayinfoextra_dbc`
 (`ID`, `DisplayRaceID`, `DisplaySexID`, `SkinID`, `FaceID`, `HairStyleID`, `HairColorID`, `FacialHairID`, `NPCItemDisplay1`, `NPCItemDisplay2`, `NPCItemDisplay3`, `NPCItemDisplay4`, `NPCItemDisplay5`, `NPCItemDisplay6`, `NPCItemDisplay7`, `NPCItemDisplay8`, `NPCItemDisplay9`, `NPCItemDisplay10`, `NPCItemDisplay11`, `Flags`, `BakeName`) VALUES
(18885, 2, 0, 5, 5, 3, 7, 5, 0, 12525, 10962, 12920, 22816, 9195, 9196, 0, 9197, 0, 0, 0, 'CreatureDisplayExtra-18885.blp'),
(18887, 2, 1, 3, 3, 1, 5, 4, 0, 12525, 10962, 12920, 22816, 9195, 9196, 0, 9197, 0, 0, 0, 'CreatureDisplayExtra-18887.blp'),
(18903, 5, 1, 2, 4, 14, 3, 4, 0, 0, 10047, 6816, 0, 11308, 3066, 0, 8848, 0, 0, 0, 'CreatureDisplayExtra-18903.blp'),
(18902, 5, 0, 1, 4, 12, 5, 0, 0, 0, 10047, 6816, 0, 11308, 3066, 0, 8848, 0, 0, 0, 'CreatureDisplayExtra-18902.blp'),
(19935, 9, 0, 0, 0, 6, 0, 0, 23591, 12962, 10837, 11803, 11811, 11804, 5366, 0, 11812, 0, 0, 0, 'CreatureDisplayExtra-19935.blp'),
(19930, 1, 1, 0, 21, 19, 0, 0, 0, 0, 0, 36105, 0, 36107, 0, 0, 0, 0, 0, 0, 'CreatureDisplayExtra-19930.blp'),
(19934, 5, 1, 2, 7, 7, 1, 3, 61666, 11638, 49547, 10189, 42271, 42272, 49534, 0, 49545, 0, 13984, 0, 'CreatureDisplayExtra-19934.blp'),
(19931, 5, 0, 1, 2, 0, 1, 10, 15396, 11318, 11319, 0, 11172, 8963, 7583, 0, 5268, 0, 0, 0, 'CreatureDisplayExtra-19931.blp'),
(19933, 7, 0, 6, 0, 7, 4, 0, 19409, 0, 0, 35647, 34176, 35648, 8340, 0, 0, 3454, 0, 0, 'CreatureDisplayExtra-19933.blp'),
(20061, 4, 1, 5, 5, 10, 6, 2, 0, 0, 58323, 13752, 4634, 10578, 62476, 0, 0, 0, 0, 0, 'CreatureDisplayExtra-20061.blp'),
(20181, 9, 0, 6, 1, 1, 3, 0, 11976, 11691, 62937, 62938, 5327, 5619, 10659, 4144, 3771, 62939, 0, 0, 'CreatureDisplayExtra-20181.blp'),
(20182, 9, 0, 4, 3, 6, 3, 0, 62940, 11691, 62937, 62938, 5327, 5619, 10659, 4144, 3771, 62939, 0, 0, 'CreatureDisplayExtra-20182.blp'),
(20183, 9, 0, 7, 4, 2, 1, 0, 62940, 4971, 61309, 8414, 8606, 8426, 8354, 9550, 50452, 62939, 0, 0, 'CreatureDisplayExtra-20183.blp'),
(20185, 2, 0, 6, 2, 0, 2, 3, 4176, 4971, 61309, 8414, 8606, 8426, 8354, 9550, 50452, 62939, 0, 0, 'CreatureDisplayExtra-20185.blp'),
(20186, 2, 0, 3, 1, 0, 1, 9, 62942, 11691, 62937, 62938, 5327, 5619, 10659, 4144, 3771, 62939, 0, 0, 'CreatureDisplayExtra-20186.blp'),
(20184, 9, 1, 3, 1, 2, 2, 6, 62940, 11691, 62937, 62938, 5327, 5619, 10659, 4144, 62941, 62939, 0, 0, 'CreatureDisplayExtra-20184.blp'),
(20191, 9, 0, 5, 1, 6, 3, 0, 62940, 51827, 62944, 55448, 55645, 55451, 55650, 55635, 62945, 62939, 0, 0, 'CreatureDisplayExtra-20191.blp'),
(20190, 9, 0, 3, 4, 3, 3, 0, 62940, 11691, 62937, 62938, 5327, 5619, 10659, 4144, 62941, 62939, 0, 0, 'CreatureDisplayExtra-20190.blp'),
(20192, 9, 0, 4, 2, 2, 2, 0, 62940, 30829, 62946, 62947, 10880, 10881, 11085, 12117, 62948, 62939, 0, 0, 'CreatureDisplayExtra-20192.blp'),
(20193, 9, 0, 6, 3, 0, 2, 0, 62940, 30829, 62946, 62947, 10880, 10881, 11085, 12117, 62948, 62939, 0, 0, 'CreatureDisplayExtra-20193.blp'),
(20196, 9, 0, 6, 1, 1, 3, 0, 34565, 37175, 57036, 43069, 43065, 43067, 43071, 58600, 56988, 62939, 0, 0, 'CreatureDisplayExtra-20196.blp'),
(22830, 9, 0, 3, 4, 4, 5, 24, 0, 0, 11307, 11437, 0, 65453, 59835, 0, 0, 0, 0, 0, 'CreatureDisplayExtra-22830.blp'),
(23983, 9, 1, 3, 3, 3, 3, 3, 0, 0, 74747, 74748, 63429, 7520, 66467, 0, 0, 0, 0, 0, 'CreatureDisplayExtra-23983.blp'),
(23984, 9, 1, 6, 6, 6, 6, 6, 0, 0, 74747, 74748, 63429, 7520, 66467, 0, 0, 0, 0, 0, 'CreatureDisplayExtra-23984.blp'),
(23985, 9, 1, 0, 9, 9, 0, 9, 0, 0, 74747, 74748, 63429, 7520, 66467, 0, 0, 0, 0, 0, 'CreatureDisplayExtra-23985.blp'),
(23986, 9, 1, 4, 0, 12, 4, 12, 0, 0, 74747, 74748, 63429, 7520, 66467, 0, 0, 0, 0, 0, 'CreatureDisplayExtra-23986.blp');


-- --- 3 faction templates --------------------------------------------------
DELETE FROM `factiontemplate_dbc` WHERE `ID` IN (2161, 2201, 2327);
INSERT INTO `factiontemplate_dbc`
 (`ID`, `Faction`, `Flags`, `FactionGroup`, `FriendGroup`, `EnemyGroup`, `Enemies_1`, `Enemies_2`, `Enemies_3`, `Enemies_4`, `Friend_1`, `Friend_2`, `Friend_3`, `Friend_4`) VALUES
(2161, 1133, 2081, 5, 4, 10, 0, 0, 0, 0, 1133, 0, 0, 0),
(2201, 66, 32, 4, 4, 2, 0, 0, 0, 0, 0, 0, 0, 0),
(2327, 50, 1, 0, 1, 0, 0, 0, 0, 0, 50, 0, 0, 0);

-- Verify -- after the SERVER dbc deploy and a restart, all three must be true:
--   * Errors.log has no "has no model defined in table `creature_template_model`"
--     lines for entries in 3600000-3999999
--   * Errors.log has no "invalid faction (faction template id) #2161/#2201/#2327"
--   * read_server_dbc CreatureDisplayInfo -> 28550 records, and ids
--     28480,30420,31533,37570 all present
