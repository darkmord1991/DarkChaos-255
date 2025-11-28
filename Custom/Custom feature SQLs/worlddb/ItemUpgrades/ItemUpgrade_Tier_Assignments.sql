-- ═══════════════════════════════════════════════════════════════════════════════
-- DarkChaos Item Upgrade System - TIER ASSIGNMENTS FOR ITEMS
-- Database: acore_world
-- Purpose: Assign items to upgrade tiers
-- Tier 1: Common items - Max level 6
-- Tier 2: Uncommon+ items - Max level 15
-- ═══════════════════════════════════════════════════════════════════════════════

USE `acore_world`;

-- ───────────────────────────────────────────────────────────────────────────────
-- ENSURE TABLE STRUCTURE IS CORRECT
-- ───────────────────────────────────────────────────────────────────────────────

-- First, verify table exists with correct columns
ALTER TABLE `dc_item_templates_upgrade` 
ADD COLUMN `tier_id` TINYINT UNSIGNED DEFAULT 1 AFTER `item_id`,
ADD COLUMN `is_active` TINYINT(1) DEFAULT 1 AFTER `tier_id`;

-- ───────────────────────────────────────────────────────────────────────────────
-- CLEAR EXISTING DATA
-- ───────────────────────────────────────────────────────────────────────────────

DELETE FROM `dc_item_templates_upgrade`;

-- ───────────────────────────────────────────────────────────────────────────────
-- TIER 1 ITEMS - Common Quality Items (Max upgrade level: 6)
-- Include all common/quest items
-- ───────────────────────────────────────────────────────────────────────────────

INSERT INTO `dc_item_templates_upgrade` (item_id, tier_id, is_active, season) VALUES
-- Tier 1 items from T1.txt (500 ilevel versions)
(300007, 1, 1, 1), -- Sanctified Scourgelord Pauldrons
(300008, 1, 1, 1), -- Sanctified Scourgelord Legguards
(300009, 1, 1, 1), -- Sanctified Scourgelord Faceguard
(300010, 1, 1, 1), -- Sanctified Scourgelord Handguards
(300011, 1, 1, 1), -- Sanctified Scourgelord Chestguard
(300012, 1, 1, 1), -- Sanctified Scourgelord Battleplate
(300013, 1, 1, 1), -- Sanctified Scourgelord Gauntlets
(300014, 1, 1, 1), -- Sanctified Scourgelord Helmet
(300015, 1, 1, 1), -- Sanctified Scourgelord Shoulderplates
(300016, 1, 1, 1), -- Sanctified Lasherweave Robes
(300017, 1, 1, 1), -- Sanctified Lasherweave Gauntlets
(300018, 1, 1, 1), -- Sanctified Lasherweave Helmet
(300019, 1, 1, 1), -- Sanctified Lasherweave Legplates
(300020, 1, 1, 1), -- Sanctified Lasherweave Pauldrons
(300021, 1, 1, 1), -- Sanctified Lasherweave Shoulderpads
(300022, 1, 1, 1), -- Sanctified Lasherweave Legguards
(300023, 1, 1, 1), -- Sanctified Lasherweave Headguard
(300024, 1, 1, 1), -- Sanctified Lasherweave Handgrips
(300025, 1, 1, 1), -- Sanctified Lasherweave Raiment
(300026, 1, 1, 1), -- Sanctified Lasherweave Mantle
(300027, 1, 1, 1), -- Sanctified Lasherweave Trousers
(300028, 1, 1, 1), -- Sanctified Lasherweave Cover
(300029, 1, 1, 1), -- Sanctified Lasherweave Gloves
(300030, 1, 1, 1), -- Sanctified Lasherweave Vestment
(300031, 1, 1, 1), -- Sanctified Ahn'Kahar Blood Hunter's Handguards
(300032, 1, 1, 1), -- Sanctified Ahn'Kahar Blood Hunter's Headpiece
(300033, 1, 1, 1), -- Sanctified Ahn'Kahar Blood Hunter's Legguards
(300034, 1, 1, 1), -- Sanctified Ahn'Kahar Blood Hunter's Spaulders
(300035, 1, 1, 1), -- Sanctified Ahn'Kahar Blood Hunter's Tunic
(300036, 1, 1, 1), -- Sanctified Bloodmage Gloves
(300037, 1, 1, 1), -- Sanctified Bloodmage Hood
(300038, 1, 1, 1), -- Sanctified Bloodmage Leggings
(300039, 1, 1, 1), -- Sanctified Bloodmage Robe
(300040, 1, 1, 1), -- Sanctified Bloodmage Shoulderpads
(300041, 1, 1, 1), -- Sanctified Lightsworn Shoulderplates
(300042, 1, 1, 1), -- Sanctified Lightsworn Legplates
(300043, 1, 1, 1), -- Sanctified Lightsworn Helmet
(300044, 1, 1, 1), -- Sanctified Lightsworn Gauntlets
(300045, 1, 1, 1), -- Sanctified Lightsworn Battleplate
(300046, 1, 1, 1), -- Sanctified Lightsworn Shoulderguards
(300047, 1, 1, 1), -- Sanctified Lightsworn Legguards
(300048, 1, 1, 1), -- Sanctified Lightsworn Handguards
(300049, 1, 1, 1), -- Sanctified Lightsworn Faceguard
(300050, 1, 1, 1), -- Sanctified Lightsworn Chestguard
(300051, 1, 1, 1), -- Sanctified Lightsworn Spaulders
(300052, 1, 1, 1), -- Sanctified Lightsworn Tunic
(300053, 1, 1, 1), -- Sanctified Lightsworn Headpiece
(300054, 1, 1, 1), -- Sanctified Lightsworn Greaves
(300055, 1, 1, 1), -- Sanctified Lightsworn Gloves
(300056, 1, 1, 1), -- Sanctified Crimson Acolyte Pants
(300057, 1, 1, 1), -- Sanctified Crimson Acolyte Raiments
(300058, 1, 1, 1), -- Sanctified Crimson Acolyte Mantle
(300059, 1, 1, 1), -- Sanctified Crimson Acolyte Handwraps
(300060, 1, 1, 1), -- Sanctified Crimson Acolyte Cowl
(300061, 1, 1, 1), -- Sanctified Crimson Acolyte Gloves
(300062, 1, 1, 1), -- Sanctified Crimson Acolyte Hood
(300063, 1, 1, 1), -- Sanctified Crimson Acolyte Leggings
(300064, 1, 1, 1), -- Sanctified Crimson Acolyte Robe
(300065, 1, 1, 1), -- Sanctified Crimson Acolyte Shoulderpads
(300066, 1, 1, 1), -- Sanctified Shadowblade Breastplate
(300067, 1, 1, 1), -- Sanctified Shadowblade Gauntlets
(300068, 1, 1, 1), -- Sanctified Shadowblade Helmet
(300069, 1, 1, 1), -- Sanctified Shadowblade Legplates
(300070, 1, 1, 1), -- Sanctified Shadowblade Pauldrons
(300071, 1, 1, 1), -- Sanctified Frost Witch's Shoulderguards
(300072, 1, 1, 1), -- Sanctified Frost Witch's War-Kilt
(300073, 1, 1, 1), -- Sanctified Frost Witch's Faceguard
(300074, 1, 1, 1), -- Sanctified Frost Witch's Grips
(300075, 1, 1, 1), -- Sanctified Frost Witch's Chestguard
(300076, 1, 1, 1), -- Sanctified Frost Witch's Spaulders
(300077, 1, 1, 1), -- Sanctified Frost Witch's Legguards
(300078, 1, 1, 1), -- Sanctified Frost Witch's Headpiece
(300079, 1, 1, 1), -- Sanctified Frost Witch's Handguards
(300080, 1, 1, 1), -- Sanctified Frost Witch's Tunic
(300081, 1, 1, 1), -- Sanctified Frost Witch's Shoulderpads
(300082, 1, 1, 1), -- Sanctified Frost Witch's Kilt
(300083, 1, 1, 1), -- Sanctified Frost Witch's Helm
(300084, 1, 1, 1), -- Sanctified Frost Witch's Gloves
(300085, 1, 1, 1), -- Sanctified Frost Witch's Hauberk
(300086, 1, 1, 1), -- Sanctified Dark Coven Gloves
(300087, 1, 1, 1), -- Sanctified Dark Coven Hood
(300088, 1, 1, 1), -- Sanctified Dark Coven Leggings
(300089, 1, 1, 1), -- Sanctified Dark Coven Robe
(300090, 1, 1, 1), -- Sanctified Dark Coven Shoulderpads
(300091, 1, 1, 1), -- Sanctified Ymirjar Lord's Battleplate
(300092, 1, 1, 1), -- Sanctified Ymirjar Lord's Gauntlets
(300093, 1, 1, 1), -- Sanctified Ymirjar Lord's Helmet
(300094, 1, 1, 1), -- Sanctified Ymirjar Lord's Legplates
(300095, 1, 1, 1), -- Sanctified Ymirjar Lord's Shoulderplates
(300096, 1, 1, 1), -- Sanctified Ymirjar Lord's Breastplate
(300097, 1, 1, 1), -- Sanctified Ymirjar Lord's Greathelm
(300098, 1, 1, 1), -- Sanctified Ymirjar Lord's Handguards
(300099, 1, 1, 1), -- Sanctified Ymirjar Lord's Legguards
(300100, 1, 1, 1), -- Sanctified Ymirjar Lord's Pauldrons
(300195, 1, 1, 1), -- Cryptmaker
(300196, 1, 1, 1), -- Frozen Bonespike
(300197, 1, 1, 1), -- Lungbreaker
(300198, 1, 1, 1), -- Nightmare Ender
(300199, 1, 1, 1), -- Zod's Repeating Longbow
(300200, 1, 1, 1), -- Heartpierce
(300201, 1, 1, 1), -- Nibelung
(300202, 1, 1, 1), -- Scourgeborne Waraxe
(300203, 1, 1, 1), -- Bloodvenom Blade
(300204, 1, 1, 1), -- Rib Spreader
(300205, 1, 1, 1), -- Corpse-Impaling Spike
(300206, 1, 1, 1), -- Trauma
(300207, 1, 1, 1), -- Black Bruise
(300208, 1, 1, 1), -- Distant Land
(300209, 1, 1, 1), -- Rigormortis
(300210, 2, 1, 1), -- Last Word (500 ilevel version - T2)
(300211, 1, 1, 1), -- Bryntroll, the Bone Arbiter
(300212, 1, 1, 1), -- Keleseth's Seducer
(300213, 1, 1, 1), -- Dying Light
(300214, 1, 1, 1), -- Bloodfall
(300215, 1, 1, 1), -- Wrathful Gladiator's Sunderer
(300216, 1, 1, 1), -- Wrathful Gladiator's Crusher
(300217, 1, 1, 1), -- Wrathful Gladiator's Claymore
(300218, 1, 1, 1), -- Wrathful Gladiator's Recurve
(300219, 1, 1, 1), -- Wrathful Gladiator's Blade of Celerity
(300220, 1, 1, 1), -- Wrathful Gladiator's Mageblade
(300221, 1, 1, 1), -- Wrathful Gladiator's Combat Staff
(300222, 1, 1, 1), -- Wrathful Gladiator's Acute Staff
(300223, 1, 1, 1), -- Wrathful Gladiator's Skirmish Staff
(300224, 1, 1, 1), -- Wrathful Gladiator's Repeater
(300225, 1, 1, 1), -- Wrathful Gladiator's Greatstaff
(300226, 1, 1, 1), -- Wrathful Gladiator's Dicer
(300227, 1, 1, 1), -- Wrathful Gladiator's Dirk
(300228, 1, 1, 1), -- Wrathful Gladiator's Left Razor
(300229, 1, 1, 1), -- Wrathful Gladiator's Punisher
(300230, 1, 1, 1), -- Wrathful Gladiator's Swiftblade
(300231, 1, 1, 1), -- Wrathful Gladiator's Shotgun
(300232, 1, 1, 1), -- Wrathful Gladiator's Salvation
(300233, 1, 1, 1), -- Wrathful Gladiator's Light Staff
(300234, 1, 1, 1), -- Wrathful Gladiator's Halberd
(300235, 1, 1, 1), -- Wrathful Gladiator's Handaxe
(300236, 1, 1, 1), -- Wrathful Gladiator's Spike
(300237, 1, 1, 1), -- Wrathful Gladiator's Truncheon
(300238, 1, 1, 1), -- Wrathful Gladiator's Longblade
(300239, 1, 1, 1), -- Wrathful Gladiator's Grasp
(300240, 1, 1, 1), -- Wrathful Gladiator's Splitter
(300241, 1, 1, 1), -- Wrathful Gladiator's Eviscerator
(300242, 1, 1, 1), -- Wrathful Gladiator's Left Claw
(300243, 1, 1, 1), -- Shadowmourne
(300244, 1, 1, 1), -- Glorenzelg, High-Blade of the Silver Hand
(300245, 1, 1, 1), -- Archus, Greatstaff of Antonidas
(300246, 1, 1, 1), -- Bloodsurge, Kel'Thuzad's Blade of Agony
(300247, 1, 1, 1), -- Fal'inrush, Defender of Quel'thalas
(300248, 1, 1, 1), -- Royal Scepter of Terenas II
(300249, 1, 1, 1), -- Oathbinder, Charge of the Ranger-General
(300250, 1, 1, 1), -- Heaven's Fall, Kryss of a Thousand Lies
(300251, 1, 1, 1), -- Havoc's Call, Blade of Lordaeron Kings
(300252, 1, 1, 1); -- Mithrios, Bronzebeard's Legacy

-- ───────────────────────────────────────────────────────────────────────────────
-- TIER 2 ITEMS - Uncommon+ Quality Items (Max upgrade level: 15)
-- Include all rare, epic, and legendary items
-- ───────────────────────────────────────────────────────────────────────────────

INSERT INTO `dc_item_templates_upgrade` (item_id, tier_id, is_active, season) VALUES
-- Additional Last Word items (all should be tier 2)
(50179, 2, 1, 1), -- Last Word (264 ilevel version)
(50708, 2, 1, 1), -- Last Word (277 ilevel version)
-- Tier 2 items from T2.txt (510 ilevel versions)
(300101, 2, 1, 1), -- Sanctified Scourgelord Pauldrons
(300102, 2, 1, 1), -- Sanctified Scourgelord Legguards
(300103, 2, 1, 1), -- Sanctified Scourgelord Faceguard
(300104, 2, 1, 1), -- Sanctified Scourgelord Handguards
(300105, 2, 1, 1), -- Sanctified Scourgelord Chestguard
(300106, 2, 1, 1), -- Sanctified Scourgelord Battleplate
(300107, 2, 1, 1), -- Sanctified Scourgelord Gauntlets
(300108, 2, 1, 1), -- Sanctified Scourgelord Helmet
(300109, 2, 1, 1), -- Sanctified Scourgelord Legplates
(300110, 2, 1, 1), -- Sanctified Lasherweave Robes
(300111, 2, 1, 1), -- Sanctified Lasherweave Gauntlets
(300112, 2, 1, 1), -- Sanctified Lasherweave Helmet
(300113, 2, 1, 1), -- Sanctified Lasherweave Legplates
(300114, 2, 1, 1), -- Sanctified Lasherweave Pauldrons
(300115, 2, 1, 1), -- Sanctified Lasherweave Shoulderpads
(300116, 2, 1, 1), -- Sanctified Lasherweave Legguards
(300117, 2, 1, 1), -- Sanctified Lasherweave Headguard
(300118, 2, 1, 1), -- Sanctified Lasherweave Handgrips
(300119, 2, 1, 1), -- Sanctified Lasherweave Raiment
(300120, 2, 1, 1), -- Sanctified Lasherweave Mantle
(300121, 2, 1, 1), -- Sanctified Lasherweave Trousers
(300122, 2, 1, 1), -- Sanctified Lasherweave Cover
(300123, 2, 1, 1), -- Sanctified Lasherweave Gloves
(300124, 2, 1, 1), -- Sanctified Lasherweave Vestment
(300125, 2, 1, 1), -- Sanctified Ahn'Kahar Blood Hunter's Handguards
(300126, 2, 1, 1), -- Sanctified Ahn'Kahar Blood Hunter's Headpiece
(300127, 2, 1, 1), -- Sanctified Ahn'Kahar Blood Hunter's Legguards
(300128, 2, 1, 1), -- Sanctified Ahn'Kahar Blood Hunter's Spaulders
(300129, 2, 1, 1), -- Sanctified Ahn'Kahar Blood Hunter's Tunic
(300130, 2, 1, 1), -- Sanctified Bloodmage Gloves
(300131, 2, 1, 1), -- Sanctified Bloodmage Hood
(300132, 2, 1, 1), -- Sanctified Bloodmage Leggings
(300133, 2, 1, 1), -- Sanctified Bloodmage Robe
(300134, 2, 1, 1), -- Sanctified Bloodmage Shoulderpads
(300135, 2, 1, 1), -- Sanctified Lightsworn Shoulderplates
(300136, 2, 1, 1), -- Sanctified Lightsworn Legplates
(300137, 2, 1, 1), -- Sanctified Lightsworn Helmet
(300138, 2, 1, 1), -- Sanctified Lightsworn Gauntlets
(300139, 2, 1, 1), -- Sanctified Lightsworn Battleplate
(300140, 2, 1, 1), -- Sanctified Lightsworn Shoulderguards
(300141, 2, 1, 1), -- Sanctified Lightsworn Legguards
(300142, 2, 1, 1), -- Sanctified Lightsworn Handguards
(300143, 2, 1, 1), -- Sanctified Lightsworn Faceguard
(300144, 2, 1, 1), -- Sanctified Lightsworn Chestguard
(300145, 2, 1, 1), -- Sanctified Lightsworn Spaulders
(300146, 2, 1, 1), -- Sanctified Lightsworn Tunic
(300147, 2, 1, 1), -- Sanctified Lightsworn Headpiece
(300148, 2, 1, 1), -- Sanctified Lightsworn Greaves
(300149, 2, 1, 1), -- Sanctified Lightsworn Gloves
(300150, 2, 1, 1), -- Sanctified Crimson Acolyte Pants
(300151, 2, 1, 1), -- Sanctified Crimson Acolyte Raiments
(300152, 2, 1, 1), -- Sanctified Crimson Acolyte Mantle
(300153, 2, 1, 1), -- Sanctified Crimson Acolyte Handwraps
(300154, 2, 1, 1), -- Sanctified Crimson Acolyte Cowl
(300155, 2, 1, 1), -- Sanctified Crimson Acolyte Gloves
(300156, 2, 1, 1), -- Sanctified Crimson Acolyte Hood
(300157, 2, 1, 1), -- Sanctified Crimson Acolyte Leggings
(300158, 2, 1, 1), -- Sanctified Crimson Acolyte Robe
(300159, 2, 1, 1), -- Sanctified Crimson Acolyte Shoulderpads
(300160, 2, 1, 1), -- Sanctified Shadowblade Breastplate
(300161, 2, 1, 1), -- Sanctified Shadowblade Gauntlets
(300162, 2, 1, 1), -- Sanctified Shadowblade Helmet
(300163, 2, 1, 1), -- Sanctified Shadowblade Legplates
(300164, 2, 1, 1), -- Sanctified Shadowblade Pauldrons
(300165, 2, 1, 1), -- Sanctified Frost Witch's Shoulderguards
(300166, 2, 1, 1), -- Sanctified Frost Witch's War-Kilt
(300167, 2, 1, 1), -- Sanctified Frost Witch's Faceguard
(300168, 2, 1, 1), -- Sanctified Frost Witch's Grips
(300169, 2, 1, 1), -- Sanctified Frost Witch's Chestguard
(300170, 2, 1, 1), -- Sanctified Frost Witch's Spaulders
(300171, 2, 1, 1), -- Sanctified Frost Witch's Legguards
(300172, 2, 1, 1), -- Sanctified Frost Witch's Headpiece
(300173, 2, 1, 1), -- Sanctified Frost Witch's Handguards
(300174, 2, 1, 1), -- Sanctified Frost Witch's Tunic
(300175, 2, 1, 1), -- Sanctified Frost Witch's Shoulderpads
(300176, 2, 1, 1), -- Sanctified Frost Witch's Kilt
(300177, 2, 1, 1), -- Sanctified Frost Witch's Helm
(300178, 2, 1, 1), -- Sanctified Frost Witch's Gloves
(300179, 2, 1, 1), -- Sanctified Frost Witch's Hauberk
(300180, 2, 1, 1), -- Sanctified Dark Coven Gloves
(300181, 2, 1, 1), -- Sanctified Dark Coven Hood
(300182, 2, 1, 1), -- Sanctified Dark Coven Leggings
(300183, 2, 1, 1), -- Sanctified Dark Coven Robe
(300184, 2, 1, 1), -- Sanctified Dark Coven Shoulderpads
(300185, 2, 1, 1), -- Sanctified Ymirjar Lord's Battleplate
(300186, 2, 1, 1), -- Sanctified Ymirjar Lord's Gauntlets
(300187, 2, 1, 1), -- Sanctified Ymirjar Lord's Helmet
(300188, 2, 1, 1), -- Sanctified Ymirjar Lord's Legplates
(300189, 2, 1, 1), -- Sanctified Ymirjar Lord's Shoulderplates
(300190, 2, 1, 1), -- Sanctified Ymirjar Lord's Breastplate
(300191, 2, 1, 1), -- Sanctified Ymirjar Lord's Greathelm
(300192, 2, 1, 1), -- Sanctified Ymirjar Lord's Handguards
(300193, 2, 1, 1), -- Sanctified Ymirjar Lord's Legguards
(300194, 2, 1, 1), -- Sanctified Ymirjar Lord's Pauldrons
(300253, 2, 1, 1), -- Cryptmaker
(300254, 2, 1, 1), -- Frozen Bonespike
(300255, 2, 1, 1), -- Lungbreaker
(300256, 2, 1, 1), -- Nightmare Ender
(300257, 2, 1, 1), -- Zod's Repeating Longbow
(300258, 2, 1, 1), -- Heartpierce
(300259, 2, 1, 1), -- Nibelung
(300260, 2, 1, 1), -- Scourgeborne Waraxe
(300261, 2, 1, 1), -- Bloodvenom Blade
(300262, 2, 1, 1), -- Rib Spreader
(300263, 2, 1, 1), -- Corpse-Impaling Spike
(300264, 2, 1, 1), -- Trauma
(300265, 2, 1, 1), -- Black Bruise
(300266, 2, 1, 1), -- Distant Land
(300267, 2, 1, 1), -- Rigormortis
(300268, 2, 1, 1), -- Last Word (510 ilevel version - T2)
(300269, 2, 1, 1), -- Bryntroll, the Bone Arbiter
(300270, 2, 1, 1), -- Keleseth's Seducer
(300271, 2, 1, 1), -- Dying Light
(300272, 2, 1, 1), -- Bloodfall
(300273, 2, 1, 1), -- Wrathful Gladiator's Sunderer
(300274, 2, 1, 1), -- Wrathful Gladiator's Crusher
(300275, 2, 1, 1), -- Wrathful Gladiator's Claymore
(300276, 2, 1, 1), -- Wrathful Gladiator's Recurve
(300277, 2, 1, 1), -- Wrathful Gladiator's Blade of Celerity
(300278, 2, 1, 1), -- Wrathful Gladiator's Mageblade
(300279, 2, 1, 1), -- Wrathful Gladiator's Combat Staff
(300280, 2, 1, 1), -- Wrathful Gladiator's Acute Staff
(300281, 2, 1, 1), -- Wrathful Gladiator's Skirmish Staff
(300282, 2, 1, 1), -- Wrathful Gladiator's Repeater
(300283, 2, 1, 1), -- Wrathful Gladiator's Greatstaff
(300284, 2, 1, 1), -- Wrathful Gladiator's Dicer
(300285, 2, 1, 1), -- Wrathful Gladiator's Dirk
(300286, 2, 1, 1), -- Wrathful Gladiator's Left Razor
(300287, 2, 1, 1), -- Wrathful Gladiator's Punisher
(300288, 2, 1, 1), -- Wrathful Gladiator's Swiftblade
(300289, 2, 1, 1), -- Wrathful Gladiator's Shotgun
(300290, 2, 1, 1), -- Wrathful Gladiator's Salvation
(300291, 2, 1, 1), -- Wrathful Gladiator's Light Staff
(300292, 2, 1, 1), -- Wrathful Gladiator's Halberd
(300293, 2, 1, 1), -- Wrathful Gladiator's Handaxe
(300294, 2, 1, 1), -- Wrathful Gladiator's Spike
(300295, 2, 1, 1), -- Wrathful Gladiator's Truncheon
(300296, 2, 1, 1), -- Wrathful Gladiator's Longblade
(300297, 2, 1, 1), -- Wrathful Gladiator's Grasp
(300298, 2, 1, 1), -- Wrathful Gladiator's Splitter
(300299, 2, 1, 1), -- Wrathful Gladiator's Eviscerator
(300300, 2, 1, 1), -- Wrathful Gladiator's Left Claw
(300301, 2, 1, 1), -- Shadowmourne
(300302, 2, 1, 1), -- Glorenzelg, High-Blade of the Silver Hand
(300303, 2, 1, 1), -- Archus, Greatstaff of Antonidas
(300304, 2, 1, 1), -- Bloodsurge, Kel'Thuzad's Blade of Agony
(300305, 2, 1, 1), -- Fal'inrush, Defender of Quel'thalas
(300306, 2, 1, 1), -- Royal Scepter of Terenas II
(300307, 2, 1, 1), -- Oathbinder, Charge of the Ranger-General
(300308, 2, 1, 1), -- Heaven's Fall, Kryss of a Thousand Lies
(300309, 2, 1, 1), -- Havoc's Call, Blade of Lordaeron Kings
(300310, 2, 1, 1); -- Mithrios, Bronzebeard's Legacy

-- ───────────────────────────────────────────────────────────────────────────────
-- VERIFICATION QUERIES
-- ───────────────────────────────────────────────────────────────────────────────

-- Count items by tier:
/*
SELECT tier_id, COUNT(*) as item_count
FROM dc_item_templates_upgrade
WHERE is_active = 1 AND season = 1
GROUP BY tier_id;

Expected:
tier_id | item_count
1       | 70
2       | 72
*/

-- Verify Last Word tier assignments:
/*
SELECT item_id, tier_id, is_active
FROM dc_item_templates_upgrade
WHERE item_id IN (50179, 50708, 300210, 300268)
ORDER BY item_id;

Expected all to have tier_id = 2 (T2)
50179: Last Word (264 ilevel) - Tier 2
50708: Last Word (277 ilevel) - Tier 2
300210: Last Word (500 ilevel) - Tier 2
300268: Last Word (510 ilevel) - Tier 2
*/

-- ───────────────────────────────────────────────────────────────────────────────
-- IMPORTANT: CUSTOMIZE THIS FILE FOR YOUR SERVER
-- ───────────────────────────────────────────────────────────────────────────────
-- 
-- Instructions:
-- 1. Get the correct item IDs from your server database:
--    SELECT entry, name, quality FROM item_template WHERE quality IN (0,1,2,3,4) LIMIT 100;
--
-- 2. Replace item IDs above with your actual item IDs
--
-- 3. Tier 1 items = Common quality (max level 6)
--    Tier 2 items = Uncommon+ quality (max level 15)
--
-- 4. Test that items show correct max levels when upgraded
--
-- 5. If items still show level 15 for Tier 1, verify:
--    - dc_item_upgrade_tiers table has correct max_level values
--    - GetTierMaxLevel() returns correct values
--    - GetItemTier() finds items in dc_item_templates_upgrade
--
-- ═══════════════════════════════════════════════════════════════════════════════
