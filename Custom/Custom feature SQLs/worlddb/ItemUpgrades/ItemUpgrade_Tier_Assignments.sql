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
(81000, 1, 1, 1), -- Sanctified Scourgelord Pauldrons
(81001, 1, 1, 1), -- Sanctified Scourgelord Legguards
(81002, 1, 1, 1), -- Sanctified Scourgelord Faceguard
(81003, 1, 1, 1), -- Sanctified Scourgelord Handguards
(81004, 1, 1, 1), -- Sanctified Scourgelord Chestguard
(81005, 1, 1, 1), -- Sanctified Scourgelord Battleplate
(81006, 1, 1, 1), -- Sanctified Scourgelord Gauntlets
(81007, 1, 1, 1), -- Sanctified Scourgelord Helmet
(81009, 1, 1, 1), -- Sanctified Scourgelord Shoulderplates
(81010, 1, 1, 1), -- Sanctified Lasherweave Robes
(81011, 1, 1, 1), -- Sanctified Lasherweave Gauntlets
(81012, 1, 1, 1), -- Sanctified Lasherweave Helmet
(81013, 1, 1, 1), -- Sanctified Lasherweave Legplates
(81014, 1, 1, 1), -- Sanctified Lasherweave Pauldrons
(81015, 1, 1, 1), -- Sanctified Lasherweave Shoulderpads
(81016, 1, 1, 1), -- Sanctified Lasherweave Legguards
(81017, 1, 1, 1), -- Sanctified Lasherweave Headguard
(81018, 1, 1, 1), -- Sanctified Lasherweave Handgrips
(81019, 1, 1, 1), -- Sanctified Lasherweave Raiment
(81020, 1, 1, 1), -- Sanctified Lasherweave Mantle
(81021, 1, 1, 1), -- Sanctified Lasherweave Trousers
(81022, 1, 1, 1), -- Sanctified Lasherweave Cover
(81023, 1, 1, 1), -- Sanctified Lasherweave Gloves
(81024, 1, 1, 1), -- Sanctified Lasherweave Vestment
(81025, 1, 1, 1), -- Sanctified Ahn'Kahar Blood Hunter's Handguards
(81026, 1, 1, 1), -- Sanctified Ahn'Kahar Blood Hunter's Headpiece
(81027, 1, 1, 1), -- Sanctified Ahn'Kahar Blood Hunter's Legguards
(81028, 1, 1, 1), -- Sanctified Ahn'Kahar Blood Hunter's Spaulders
(81029, 1, 1, 1), -- Sanctified Ahn'Kahar Blood Hunter's Tunic
(81030, 1, 1, 1), -- Sanctified Bloodmage Gloves
(81031, 1, 1, 1), -- Sanctified Bloodmage Hood
(81032, 1, 1, 1), -- Sanctified Bloodmage Leggings
(81033, 1, 1, 1), -- Sanctified Bloodmage Robe
(81034, 1, 1, 1), -- Sanctified Bloodmage Shoulderpads
(81035, 1, 1, 1), -- Sanctified Lightsworn Shoulderplates
(81036, 1, 1, 1), -- Sanctified Lightsworn Legplates
(81037, 1, 1, 1), -- Sanctified Lightsworn Helmet
(81038, 1, 1, 1), -- Sanctified Lightsworn Gauntlets
(81039, 1, 1, 1), -- Sanctified Lightsworn Battleplate
(81040, 1, 1, 1), -- Sanctified Lightsworn Shoulderguards
(81041, 1, 1, 1), -- Sanctified Lightsworn Legguards
(81042, 1, 1, 1), -- Sanctified Lightsworn Handguards
(81043, 1, 1, 1), -- Sanctified Lightsworn Faceguard
(81044, 1, 1, 1), -- Sanctified Lightsworn Chestguard
(81045, 1, 1, 1), -- Sanctified Lightsworn Spaulders
(81046, 1, 1, 1), -- Sanctified Lightsworn Tunic
(81047, 1, 1, 1), -- Sanctified Lightsworn Headpiece
(81048, 1, 1, 1), -- Sanctified Lightsworn Greaves
(81049, 1, 1, 1), -- Sanctified Lightsworn Gloves
(81050, 1, 1, 1), -- Sanctified Crimson Acolyte Pants
(81051, 1, 1, 1), -- Sanctified Crimson Acolyte Raiments
(81052, 1, 1, 1), -- Sanctified Crimson Acolyte Mantle
(81053, 1, 1, 1), -- Sanctified Crimson Acolyte Handwraps
(81054, 1, 1, 1), -- Sanctified Crimson Acolyte Cowl
(81055, 1, 1, 1), -- Sanctified Crimson Acolyte Gloves
(81056, 1, 1, 1), -- Sanctified Crimson Acolyte Hood
(81057, 1, 1, 1), -- Sanctified Crimson Acolyte Leggings
(81058, 1, 1, 1), -- Sanctified Crimson Acolyte Robe
(81059, 1, 1, 1), -- Sanctified Crimson Acolyte Shoulderpads
(81060, 1, 1, 1), -- Sanctified Shadowblade Breastplate
(81061, 1, 1, 1), -- Sanctified Shadowblade Gauntlets
(81062, 1, 1, 1), -- Sanctified Shadowblade Helmet
(81063, 1, 1, 1), -- Sanctified Shadowblade Legplates
(81064, 1, 1, 1), -- Sanctified Shadowblade Pauldrons
(81065, 1, 1, 1), -- Sanctified Frost Witch's Shoulderguards
(81066, 1, 1, 1), -- Sanctified Frost Witch's War-Kilt
(81067, 1, 1, 1), -- Sanctified Frost Witch's Faceguard
(81068, 1, 1, 1), -- Sanctified Frost Witch's Grips
(81069, 1, 1, 1), -- Sanctified Frost Witch's Chestguard
(81070, 1, 1, 1), -- Sanctified Frost Witch's Spaulders
(81071, 1, 1, 1), -- Sanctified Frost Witch's Legguards
(81072, 1, 1, 1), -- Sanctified Frost Witch's Headpiece
(81073, 1, 1, 1), -- Sanctified Frost Witch's Handguards
(81074, 1, 1, 1), -- Sanctified Frost Witch's Tunic
(81075, 1, 1, 1), -- Sanctified Frost Witch's Shoulderpads
(81076, 1, 1, 1), -- Sanctified Frost Witch's Kilt
(81077, 1, 1, 1), -- Sanctified Frost Witch's Helm
(81078, 1, 1, 1), -- Sanctified Frost Witch's Gloves
(81079, 1, 1, 1), -- Sanctified Frost Witch's Hauberk
(81080, 1, 1, 1), -- Sanctified Dark Coven Gloves
(81081, 1, 1, 1), -- Sanctified Dark Coven Hood
(81082, 1, 1, 1), -- Sanctified Dark Coven Leggings
(81083, 1, 1, 1), -- Sanctified Dark Coven Robe
(81084, 1, 1, 1), -- Sanctified Dark Coven Shoulderpads
(81085, 1, 1, 1), -- Sanctified Ymirjar Lord's Battleplate
(81086, 1, 1, 1), -- Sanctified Ymirjar Lord's Gauntlets
(81087, 1, 1, 1), -- Sanctified Ymirjar Lord's Helmet
(81088, 1, 1, 1), -- Sanctified Ymirjar Lord's Legplates
(81089, 1, 1, 1), -- Sanctified Ymirjar Lord's Shoulderplates
(81090, 1, 1, 1), -- Sanctified Ymirjar Lord's Breastplate
(81091, 1, 1, 1), -- Sanctified Ymirjar Lord's Greathelm
(81092, 1, 1, 1), -- Sanctified Ymirjar Lord's Handguards
(81093, 1, 1, 1), -- Sanctified Ymirjar Lord's Legguards
(81094, 1, 1, 1), -- Sanctified Ymirjar Lord's Pauldrons
(91000, 1, 1, 1), -- Cryptmaker
(91001, 1, 1, 1), -- Frozen Bonespike
(91002, 1, 1, 1), -- Lungbreaker
(91003, 1, 1, 1), -- Nightmare Ender
(91004, 1, 1, 1), -- Zod's Repeating Longbow
(91005, 1, 1, 1), -- Heartpierce
(91006, 1, 1, 1), -- Nibelung
(91007, 1, 1, 1), -- Scourgeborne Waraxe
(91008, 1, 1, 1), -- Bloodvenom Blade
(91009, 1, 1, 1), -- Rib Spreader
(91010, 1, 1, 1), -- Corpse-Impaling Spike
(91011, 1, 1, 1), -- Trauma
(91012, 1, 1, 1), -- Black Bruise
(91013, 1, 1, 1), -- Distant Land
(91014, 1, 1, 1), -- Rigormortis
(91015, 2, 1, 1), -- Last Word (500 ilevel version - T2)
(91016, 1, 1, 1), -- Bryntroll, the Bone Arbiter
(91017, 1, 1, 1), -- Keleseth's Seducer
(91018, 1, 1, 1), -- Dying Light
(91019, 1, 1, 1), -- Bloodfall
(91020, 1, 1, 1), -- Wrathful Gladiator's Sunderer
(91021, 1, 1, 1), -- Wrathful Gladiator's Crusher
(91022, 1, 1, 1), -- Wrathful Gladiator's Claymore
(91023, 1, 1, 1), -- Wrathful Gladiator's Recurve
(91024, 1, 1, 1), -- Wrathful Gladiator's Blade of Celerity
(91025, 1, 1, 1), -- Wrathful Gladiator's Mageblade
(91026, 1, 1, 1), -- Wrathful Gladiator's Combat Staff
(91027, 1, 1, 1), -- Wrathful Gladiator's Acute Staff
(91028, 1, 1, 1), -- Wrathful Gladiator's Skirmish Staff
(91029, 1, 1, 1), -- Wrathful Gladiator's Repeater
(91030, 1, 1, 1), -- Wrathful Gladiator's Greatstaff
(91031, 1, 1, 1), -- Wrathful Gladiator's Dicer
(91032, 1, 1, 1), -- Wrathful Gladiator's Dirk
(91033, 1, 1, 1), -- Wrathful Gladiator's Left Razor
(91034, 1, 1, 1), -- Wrathful Gladiator's Punisher
(91035, 1, 1, 1), -- Wrathful Gladiator's Swiftblade
(91036, 1, 1, 1), -- Wrathful Gladiator's Shotgun
(91037, 1, 1, 1), -- Wrathful Gladiator's Salvation
(91038, 1, 1, 1), -- Wrathful Gladiator's Light Staff
(91039, 1, 1, 1), -- Wrathful Gladiator's Halberd
(91040, 1, 1, 1), -- Wrathful Gladiator's Handaxe
(91041, 1, 1, 1), -- Wrathful Gladiator's Spike
(91042, 1, 1, 1), -- Wrathful Gladiator's Truncheon
(91043, 1, 1, 1), -- Wrathful Gladiator's Longblade
(91044, 1, 1, 1), -- Wrathful Gladiator's Grasp
(91045, 1, 1, 1), -- Wrathful Gladiator's Splitter
(91046, 1, 1, 1), -- Wrathful Gladiator's Eviscerator
(91047, 1, 1, 1), -- Wrathful Gladiator's Left Claw
(91048, 1, 1, 1), -- Shadowmourne
(91049, 1, 1, 1), -- Glorenzelg, High-Blade of the Silver Hand
(91050, 1, 1, 1), -- Archus, Greatstaff of Antonidas
(91051, 1, 1, 1), -- Bloodsurge, Kel'Thuzad's Blade of Agony
(91052, 1, 1, 1), -- Fal'inrush, Defender of Quel'thalas
(91053, 1, 1, 1), -- Royal Scepter of Terenas II
(91054, 1, 1, 1), -- Oathbinder, Charge of the Ranger-General
(91055, 1, 1, 1), -- Heaven's Fall, Kryss of a Thousand Lies
(91056, 1, 1, 1), -- Havoc's Call, Blade of Lordaeron Kings
(91057, 1, 1, 1); -- Mithrios, Bronzebeard's Legacy

-- ───────────────────────────────────────────────────────────────────────────────
-- TIER 2 ITEMS - Uncommon+ Quality Items (Max upgrade level: 15)
-- Include all rare, epic, and legendary items
-- ───────────────────────────────────────────────────────────────────────────────

INSERT INTO `dc_item_templates_upgrade` (item_id, tier_id, is_active, season) VALUES
-- Additional Last Word items (all should be tier 2)
(50179, 2, 1, 1), -- Last Word (264 ilevel version)
(50708, 2, 1, 1), -- Last Word (277 ilevel version)
-- Tier 2 items from T2.txt (510 ilevel versions)
(81100, 2, 1, 1), -- Sanctified Scourgelord Pauldrons
(81101, 2, 1, 1), -- Sanctified Scourgelord Legguards
(81102, 2, 1, 1), -- Sanctified Scourgelord Faceguard
(81103, 2, 1, 1), -- Sanctified Scourgelord Handguards
(81104, 2, 1, 1), -- Sanctified Scourgelord Chestguard
(81105, 2, 1, 1), -- Sanctified Scourgelord Battleplate
(81106, 2, 1, 1), -- Sanctified Scourgelord Gauntlets
(81107, 2, 1, 1), -- Sanctified Scourgelord Helmet
(81108, 2, 1, 1), -- Sanctified Scourgelord Legplates
(81110, 2, 1, 1), -- Sanctified Lasherweave Robes
(81111, 2, 1, 1), -- Sanctified Lasherweave Gauntlets
(81112, 2, 1, 1), -- Sanctified Lasherweave Helmet
(81113, 2, 1, 1), -- Sanctified Lasherweave Legplates
(81114, 2, 1, 1), -- Sanctified Lasherweave Pauldrons
(81115, 2, 1, 1), -- Sanctified Lasherweave Shoulderpads
(81116, 2, 1, 1), -- Sanctified Lasherweave Legguards
(81117, 2, 1, 1), -- Sanctified Lasherweave Headguard
(81118, 2, 1, 1), -- Sanctified Lasherweave Handgrips
(81119, 2, 1, 1), -- Sanctified Lasherweave Raiment
(81120, 2, 1, 1), -- Sanctified Lasherweave Mantle
(81121, 2, 1, 1), -- Sanctified Lasherweave Trousers
(81122, 2, 1, 1), -- Sanctified Lasherweave Cover
(81123, 2, 1, 1), -- Sanctified Lasherweave Gloves
(81124, 2, 1, 1), -- Sanctified Lasherweave Vestment
(81125, 2, 1, 1), -- Sanctified Ahn'Kahar Blood Hunter's Handguards
(81126, 2, 1, 1), -- Sanctified Ahn'Kahar Blood Hunter's Headpiece
(81127, 2, 1, 1), -- Sanctified Ahn'Kahar Blood Hunter's Legguards
(81128, 2, 1, 1), -- Sanctified Ahn'Kahar Blood Hunter's Spaulders
(81129, 2, 1, 1), -- Sanctified Ahn'Kahar Blood Hunter's Tunic
(81130, 2, 1, 1), -- Sanctified Bloodmage Gloves
(81131, 2, 1, 1), -- Sanctified Bloodmage Hood
(81132, 2, 1, 1), -- Sanctified Bloodmage Leggings
(81133, 2, 1, 1), -- Sanctified Bloodmage Robe
(81134, 2, 1, 1), -- Sanctified Bloodmage Shoulderpads
(81135, 2, 1, 1), -- Sanctified Lightsworn Shoulderplates
(81136, 2, 1, 1), -- Sanctified Lightsworn Legplates
(81137, 2, 1, 1), -- Sanctified Lightsworn Helmet
(81138, 2, 1, 1), -- Sanctified Lightsworn Gauntlets
(81139, 2, 1, 1), -- Sanctified Lightsworn Battleplate
(81140, 2, 1, 1), -- Sanctified Lightsworn Shoulderguards
(81141, 2, 1, 1), -- Sanctified Lightsworn Legguards
(81142, 2, 1, 1), -- Sanctified Lightsworn Handguards
(81143, 2, 1, 1), -- Sanctified Lightsworn Faceguard
(81144, 2, 1, 1), -- Sanctified Lightsworn Chestguard
(81145, 2, 1, 1), -- Sanctified Lightsworn Spaulders
(81146, 2, 1, 1), -- Sanctified Lightsworn Tunic
(81147, 2, 1, 1), -- Sanctified Lightsworn Headpiece
(81148, 2, 1, 1), -- Sanctified Lightsworn Greaves
(81149, 2, 1, 1), -- Sanctified Lightsworn Gloves
(81150, 2, 1, 1), -- Sanctified Crimson Acolyte Pants
(81151, 2, 1, 1), -- Sanctified Crimson Acolyte Raiments
(81152, 2, 1, 1), -- Sanctified Crimson Acolyte Mantle
(81153, 2, 1, 1), -- Sanctified Crimson Acolyte Handwraps
(81154, 2, 1, 1), -- Sanctified Crimson Acolyte Cowl
(81155, 2, 1, 1), -- Sanctified Crimson Acolyte Gloves
(81156, 2, 1, 1), -- Sanctified Crimson Acolyte Hood
(81157, 2, 1, 1), -- Sanctified Crimson Acolyte Leggings
(81158, 2, 1, 1), -- Sanctified Crimson Acolyte Robe
(81159, 2, 1, 1), -- Sanctified Crimson Acolyte Shoulderpads
(81160, 2, 1, 1), -- Sanctified Shadowblade Breastplate
(81161, 2, 1, 1), -- Sanctified Shadowblade Gauntlets
(81162, 2, 1, 1), -- Sanctified Shadowblade Helmet
(81163, 2, 1, 1), -- Sanctified Shadowblade Legplates
(81164, 2, 1, 1), -- Sanctified Shadowblade Pauldrons
(81165, 2, 1, 1), -- Sanctified Frost Witch's Shoulderguards
(81166, 2, 1, 1), -- Sanctified Frost Witch's War-Kilt
(81167, 2, 1, 1), -- Sanctified Frost Witch's Faceguard
(81168, 2, 1, 1), -- Sanctified Frost Witch's Grips
(81169, 2, 1, 1), -- Sanctified Frost Witch's Chestguard
(81170, 2, 1, 1), -- Sanctified Frost Witch's Spaulders
(81171, 2, 1, 1), -- Sanctified Frost Witch's Legguards
(81172, 2, 1, 1), -- Sanctified Frost Witch's Headpiece
(81173, 2, 1, 1), -- Sanctified Frost Witch's Handguards
(81174, 2, 1, 1), -- Sanctified Frost Witch's Tunic
(81175, 2, 1, 1), -- Sanctified Frost Witch's Shoulderpads
(81176, 2, 1, 1), -- Sanctified Frost Witch's Kilt
(81177, 2, 1, 1), -- Sanctified Frost Witch's Helm
(81178, 2, 1, 1), -- Sanctified Frost Witch's Gloves
(81179, 2, 1, 1), -- Sanctified Frost Witch's Hauberk
(81180, 2, 1, 1), -- Sanctified Dark Coven Gloves
(81181, 2, 1, 1), -- Sanctified Dark Coven Hood
(81182, 2, 1, 1), -- Sanctified Dark Coven Leggings
(81183, 2, 1, 1), -- Sanctified Dark Coven Robe
(81184, 2, 1, 1), -- Sanctified Dark Coven Shoulderpads
(81185, 2, 1, 1), -- Sanctified Ymirjar Lord's Battleplate
(81186, 2, 1, 1), -- Sanctified Ymirjar Lord's Gauntlets
(81187, 2, 1, 1), -- Sanctified Ymirjar Lord's Helmet
(81188, 2, 1, 1), -- Sanctified Ymirjar Lord's Legplates
(81189, 2, 1, 1), -- Sanctified Ymirjar Lord's Shoulderplates
(81190, 2, 1, 1), -- Sanctified Ymirjar Lord's Breastplate
(81191, 2, 1, 1), -- Sanctified Ymirjar Lord's Greathelm
(81192, 2, 1, 1), -- Sanctified Ymirjar Lord's Handguards
(81193, 2, 1, 1), -- Sanctified Ymirjar Lord's Legguards
(81194, 2, 1, 1), -- Sanctified Ymirjar Lord's Pauldrons
(91100, 2, 1, 1), -- Cryptmaker
(91101, 2, 1, 1), -- Frozen Bonespike
(91102, 2, 1, 1), -- Lungbreaker
(91103, 2, 1, 1), -- Nightmare Ender
(91104, 2, 1, 1), -- Zod's Repeating Longbow
(91105, 2, 1, 1), -- Heartpierce
(91106, 2, 1, 1), -- Nibelung
(91107, 2, 1, 1), -- Scourgeborne Waraxe
(91108, 2, 1, 1), -- Bloodvenom Blade
(91109, 2, 1, 1), -- Rib Spreader
(91110, 2, 1, 1), -- Corpse-Impaling Spike
(91111, 2, 1, 1), -- Trauma
(91112, 2, 1, 1), -- Black Bruise
(91113, 2, 1, 1), -- Distant Land
(91114, 2, 1, 1), -- Rigormortis
(91115, 2, 1, 1), -- Last Word (510 ilevel version - T2)
(91116, 2, 1, 1), -- Bryntroll, the Bone Arbiter
(91117, 2, 1, 1), -- Keleseth's Seducer
(91118, 2, 1, 1), -- Dying Light
(91119, 2, 1, 1), -- Bloodfall
(91120, 2, 1, 1), -- Wrathful Gladiator's Sunderer
(91121, 2, 1, 1), -- Wrathful Gladiator's Crusher
(91122, 2, 1, 1), -- Wrathful Gladiator's Claymore
(91123, 2, 1, 1), -- Wrathful Gladiator's Recurve
(91124, 2, 1, 1), -- Wrathful Gladiator's Blade of Celerity
(91125, 2, 1, 1), -- Wrathful Gladiator's Mageblade
(91126, 2, 1, 1), -- Wrathful Gladiator's Combat Staff
(91127, 2, 1, 1), -- Wrathful Gladiator's Acute Staff
(91128, 2, 1, 1), -- Wrathful Gladiator's Skirmish Staff
(91129, 2, 1, 1), -- Wrathful Gladiator's Repeater
(91130, 2, 1, 1), -- Wrathful Gladiator's Greatstaff
(91131, 2, 1, 1), -- Wrathful Gladiator's Dicer
(91132, 2, 1, 1), -- Wrathful Gladiator's Dirk
(91133, 2, 1, 1), -- Wrathful Gladiator's Left Razor
(91134, 2, 1, 1), -- Wrathful Gladiator's Punisher
(91135, 2, 1, 1), -- Wrathful Gladiator's Swiftblade
(91136, 2, 1, 1), -- Wrathful Gladiator's Shotgun
(91137, 2, 1, 1), -- Wrathful Gladiator's Salvation
(91138, 2, 1, 1), -- Wrathful Gladiator's Light Staff
(91139, 2, 1, 1), -- Wrathful Gladiator's Halberd
(91140, 2, 1, 1), -- Wrathful Gladiator's Handaxe
(91141, 2, 1, 1), -- Wrathful Gladiator's Spike
(91142, 2, 1, 1), -- Wrathful Gladiator's Truncheon
(91143, 2, 1, 1), -- Wrathful Gladiator's Longblade
(91144, 2, 1, 1), -- Wrathful Gladiator's Grasp
(91145, 2, 1, 1), -- Wrathful Gladiator's Splitter
(91146, 2, 1, 1), -- Wrathful Gladiator's Eviscerator
(91147, 2, 1, 1), -- Wrathful Gladiator's Left Claw
(91148, 2, 1, 1), -- Shadowmourne
(91149, 2, 1, 1), -- Glorenzelg, High-Blade of the Silver Hand
(91150, 2, 1, 1), -- Archus, Greatstaff of Antonidas
(91151, 2, 1, 1), -- Bloodsurge, Kel'Thuzad's Blade of Agony
(91152, 2, 1, 1), -- Fal'inrush, Defender of Quel'thalas
(91153, 2, 1, 1), -- Royal Scepter of Terenas II
(91154, 2, 1, 1), -- Oathbinder, Charge of the Ranger-General
(91155, 2, 1, 1), -- Heaven's Fall, Kryss of a Thousand Lies
(91156, 2, 1, 1), -- Havoc's Call, Blade of Lordaeron Kings
(91157, 2, 1, 1); -- Mithrios, Bronzebeard's Legacy

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
WHERE item_id IN (50179, 50708, 91015, 91115)
ORDER BY item_id;

Expected all to have tier_id = 2 (T2)
50179: Last Word (264 ilevel) - Tier 2
50708: Last Word (277 ilevel) - Tier 2
91015: Last Word (500 ilevel) - Tier 2
91115: Last Word (510 ilevel) - Tier 2
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
