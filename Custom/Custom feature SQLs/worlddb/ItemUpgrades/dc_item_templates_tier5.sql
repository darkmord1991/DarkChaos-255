-- =========================================================================
-- DarkChaos Item Upgrade System - Phase 2: Tier 5 Chaos Artifacts
-- World Database - Item Template Mappings
-- =========================================================================
-- 
-- Tier 5 (Artifacts - Chaos) Items: 110 total
--   Plate:   20 items (90000-90019)
--   Mail:    27 items (90020-90046)
--   Leather: 27 items (90047-90073)
--   Cloth:   36 items (90074-90109)
--
-- Source: Chaos Artifact Encounters (Elite Hidden Bosses)
-- iLvL Range: 359-399
-- Cosmetic Variants: 0-2 per item
-- Rarity: LEGENDARY (5) - Prestige tier items
--
-- =========================================================================

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

-- =========================================================================
-- TIER 5: CHAOS ARTIFACTS (110 items)
-- Source: Chaos Artifact Encounters (Elite Hidden Bosses)
-- iLvL Range: 359-399
-- Cosmetic Variants: 0-2 per item
-- Rarity: LEGENDARY (5) - Prestige tier
-- =========================================================================

-- Plate Armor - Tier 5 Chaos Artifacts (20 items)
INSERT INTO dc_item_templates_upgrade (item_id, tier_id, armor_type, item_slot, rarity, source_type, source_id, base_stat_value, cosmetic_variant, is_active, season)
VALUES
(90000, 5, 'plate', 1, 5, 'artifact', 500, 128, 0, 1, 1), (90001, 5, 'plate', 1, 5, 'artifact', 501, 128, 1, 1, 1), (90002, 5, 'plate', 1, 5, 'artifact', 502, 128, 2, 1, 1),
(90003, 5, 'plate', 4, 5, 'artifact', 503, 168, 0, 1, 1), (90004, 5, 'plate', 4, 5, 'artifact', 504, 168, 1, 1, 1), (90005, 5, 'plate', 4, 5, 'artifact', 505, 168, 2, 1, 1),
(90006, 5, 'plate', 6, 5, 'artifact', 506, 158, 0, 1, 1), (90007, 5, 'plate', 6, 5, 'artifact', 507, 158, 1, 1, 1), (90008, 5, 'plate', 6, 5, 'artifact', 508, 158, 2, 1, 1),
(90009, 5, 'plate', 16, 5, 'artifact', 509, 168, 0, 1, 1), (90010, 5, 'plate', 16, 5, 'artifact', 510, 168, 1, 1, 1), (90011, 5, 'plate', 16, 5, 'artifact', 511, 168, 2, 1, 1),
(90012, 5, 'plate', 17, 5, 'artifact', 512, 158, 0, 1, 1), (90013, 5, 'plate', 17, 5, 'artifact', 513, 158, 1, 1, 1), (90014, 5, 'plate', 17, 5, 'artifact', 514, 158, 2, 1, 1),
(90015, 5, 'plate', 12, 5, 'artifact', 515, 138, 0, 1, 1), (90016, 5, 'plate', 12, 5, 'artifact', 516, 138, 1, 1, 1), (90017, 5, 'plate', 12, 5, 'artifact', 517, 138, 2, 1, 1),
(90018, 5, 'plate', 3, 5, 'artifact', 518, 148, 0, 1, 1), (90019, 5, 'plate', 3, 5, 'artifact', 519, 148, 2, 1, 1);

-- Mail Armor - Tier 5 Chaos Artifacts (27 items)
INSERT INTO dc_item_templates_upgrade (item_id, tier_id, armor_type, item_slot, rarity, source_type, source_id, base_stat_value, cosmetic_variant, is_active, season)
VALUES
(90020, 5, 'mail', 1, 5, 'artifact', 520, 125, 0, 1, 1), (90021, 5, 'mail', 1, 5, 'artifact', 521, 125, 1, 1, 1), (90022, 5, 'mail', 1, 5, 'artifact', 522, 125, 2, 1, 1),
(90023, 5, 'mail', 2, 5, 'artifact', 523, 115, 0, 1, 1), (90024, 5, 'mail', 2, 5, 'artifact', 524, 115, 1, 1, 1), (90025, 5, 'mail', 2, 5, 'artifact', 525, 115, 2, 1, 1),
(90026, 5, 'mail', 3, 5, 'artifact', 526, 145, 0, 1, 1), (90027, 5, 'mail', 3, 5, 'artifact', 527, 145, 1, 1, 1), (90028, 5, 'mail', 3, 5, 'artifact', 528, 145, 2, 1, 1),
(90029, 5, 'mail', 4, 5, 'artifact', 529, 165, 0, 1, 1), (90030, 5, 'mail', 4, 5, 'artifact', 530, 165, 1, 1, 1), (90031, 5, 'mail', 4, 5, 'artifact', 531, 165, 2, 1, 1),
(90032, 5, 'mail', 16, 5, 'artifact', 532, 165, 0, 1, 1), (90033, 5, 'mail', 16, 5, 'artifact', 533, 165, 1, 1, 1), (90034, 5, 'mail', 16, 5, 'artifact', 534, 165, 2, 1, 1),
(90035, 5, 'mail', 17, 5, 'artifact', 535, 155, 0, 1, 1), (90036, 5, 'mail', 17, 5, 'artifact', 536, 155, 1, 1, 1), (90037, 5, 'mail', 17, 5, 'artifact', 537, 155, 2, 1, 1),
(90038, 5, 'mail', 6, 5, 'artifact', 538, 155, 0, 1, 1), (90039, 5, 'mail', 6, 5, 'artifact', 539, 155, 1, 1, 1), (90040, 5, 'mail', 6, 5, 'artifact', 540, 155, 2, 1, 1),
(90041, 5, 'mail', 12, 5, 'artifact', 541, 135, 0, 1, 1), (90042, 5, 'mail', 12, 5, 'artifact', 542, 135, 1, 1, 1), (90043, 5, 'mail', 12, 5, 'artifact', 543, 135, 2, 1, 1),
(90044, 5, 'mail', 9, 5, 'artifact', 544, 145, 0, 1, 1), (90045, 5, 'mail', 9, 5, 'artifact', 545, 145, 1, 1, 1), (90046, 5, 'mail', 9, 5, 'artifact', 546, 145, 2, 1, 1);

-- Leather Armor - Tier 5 Chaos Artifacts (27 items)
INSERT INTO dc_item_templates_upgrade (item_id, tier_id, armor_type, item_slot, rarity, source_type, source_id, base_stat_value, cosmetic_variant, is_active, season)
VALUES
(90047, 5, 'leather', 1, 5, 'artifact', 547, 122, 0, 1, 1), (90048, 5, 'leather', 1, 5, 'artifact', 548, 122, 1, 1, 1), (90049, 5, 'leather', 1, 5, 'artifact', 549, 122, 2, 1, 1),
(90050, 5, 'leather', 2, 5, 'artifact', 550, 112, 0, 1, 1), (90051, 5, 'leather', 2, 5, 'artifact', 551, 112, 1, 1, 1), (90052, 5, 'leather', 2, 5, 'artifact', 552, 112, 2, 1, 1),
(90053, 5, 'leather', 3, 5, 'artifact', 553, 142, 0, 1, 1), (90054, 5, 'leather', 3, 5, 'artifact', 554, 142, 1, 1, 1), (90055, 5, 'leather', 3, 5, 'artifact', 555, 142, 2, 1, 1),
(90056, 5, 'leather', 4, 5, 'artifact', 556, 162, 0, 1, 1), (90057, 5, 'leather', 4, 5, 'artifact', 557, 162, 1, 1, 1), (90058, 5, 'leather', 4, 5, 'artifact', 558, 162, 2, 1, 1),
(90059, 5, 'leather', 16, 5, 'artifact', 559, 162, 0, 1, 1), (90060, 5, 'leather', 16, 5, 'artifact', 560, 162, 1, 1, 1), (90061, 5, 'leather', 16, 5, 'artifact', 561, 162, 2, 1, 1),
(90062, 5, 'leather', 17, 5, 'artifact', 562, 152, 0, 1, 1), (90063, 5, 'leather', 17, 5, 'artifact', 563, 152, 1, 1, 1), (90064, 5, 'leather', 17, 5, 'artifact', 564, 152, 2, 1, 1),
(90065, 5, 'leather', 6, 5, 'artifact', 565, 152, 0, 1, 1), (90066, 5, 'leather', 6, 5, 'artifact', 566, 152, 1, 1, 1), (90067, 5, 'leather', 6, 5, 'artifact', 567, 152, 2, 1, 1),
(90068, 5, 'leather', 12, 5, 'artifact', 568, 132, 0, 1, 1), (90069, 5, 'leather', 12, 5, 'artifact', 569, 132, 1, 1, 1), (90070, 5, 'leather', 12, 5, 'artifact', 570, 132, 2, 1, 1),
(90071, 5, 'leather', 9, 5, 'artifact', 571, 142, 0, 1, 1), (90072, 5, 'leather', 9, 5, 'artifact', 572, 142, 1, 1, 1), (90073, 5, 'leather', 9, 5, 'artifact', 573, 142, 2, 1, 1);

-- Cloth Armor - Tier 5 Chaos Artifacts (36 items)
INSERT INTO dc_item_templates_upgrade (item_id, tier_id, armor_type, item_slot, rarity, source_type, source_id, base_stat_value, cosmetic_variant, is_active, season)
VALUES
(90074, 5, 'cloth', 1, 5, 'artifact', 574, 120, 0, 1, 1), (90075, 5, 'cloth', 1, 5, 'artifact', 575, 120, 1, 1, 1), (90076, 5, 'cloth', 1, 5, 'artifact', 576, 120, 2, 1, 1),
(90077, 5, 'cloth', 2, 5, 'artifact', 577, 110, 0, 1, 1), (90078, 5, 'cloth', 2, 5, 'artifact', 578, 110, 1, 1, 1), (90079, 5, 'cloth', 2, 5, 'artifact', 579, 110, 2, 1, 1),
(90080, 5, 'cloth', 3, 5, 'artifact', 580, 140, 0, 1, 1), (90081, 5, 'cloth', 3, 5, 'artifact', 581, 140, 1, 1, 1), (90082, 5, 'cloth', 3, 5, 'artifact', 582, 140, 2, 1, 1),
(90083, 5, 'cloth', 4, 5, 'artifact', 583, 160, 0, 1, 1), (90084, 5, 'cloth', 4, 5, 'artifact', 584, 160, 1, 1, 1), (90085, 5, 'cloth', 4, 5, 'artifact', 585, 160, 2, 1, 1),
(90086, 5, 'cloth', 5, 5, 'artifact', 586, 130, 0, 1, 1), (90087, 5, 'cloth', 5, 5, 'artifact', 587, 130, 1, 1, 1), (90088, 5, 'cloth', 5, 5, 'artifact', 588, 130, 2, 1, 1),
(90089, 5, 'cloth', 8, 5, 'artifact', 589, 105, 0, 1, 1), (90090, 5, 'cloth', 8, 5, 'artifact', 590, 105, 1, 1, 1), (90091, 5, 'cloth', 8, 5, 'artifact', 591, 105, 2, 1, 1),
(90092, 5, 'cloth', 16, 5, 'artifact', 592, 160, 0, 1, 1), (90093, 5, 'cloth', 16, 5, 'artifact', 593, 160, 1, 1, 1), (90094, 5, 'cloth', 16, 5, 'artifact', 594, 160, 2, 1, 1),
(90095, 5, 'cloth', 17, 5, 'artifact', 595, 150, 0, 1, 1), (90096, 5, 'cloth', 17, 5, 'artifact', 596, 150, 1, 1, 1), (90097, 5, 'cloth', 17, 5, 'artifact', 597, 150, 2, 1, 1),
(90098, 5, 'cloth', 12, 5, 'artifact', 598, 130, 0, 1, 1), (90099, 5, 'cloth', 12, 5, 'artifact', 599, 130, 1, 1, 1), (90100, 5, 'cloth', 12, 5, 'artifact', 600, 130, 2, 1, 1),
(90101, 5, 'cloth', 9, 5, 'artifact', 601, 140, 0, 1, 1), (90102, 5, 'cloth', 9, 5, 'artifact', 602, 140, 1, 1, 1), (90103, 5, 'cloth', 9, 5, 'artifact', 603, 140, 2, 1, 1),
(90104, 5, 'cloth', 6, 5, 'artifact', 604, 150, 0, 1, 1), (90105, 5, 'cloth', 6, 5, 'artifact', 605, 150, 1, 1, 1), (90106, 5, 'cloth', 6, 5, 'artifact', 606, 150, 2, 1, 1),
(90107, 5, 'cloth', 11, 5, 'artifact', 607, 95, 0, 1, 1), (90108, 5, 'cloth', 11, 5, 'artifact', 608, 95, 1, 1, 1), (90109, 5, 'cloth', 11, 5, 'artifact', 609, 95, 2, 1, 1);

/*!40101 SET TIME_ZONE=@OLD_TIME_ZONE */;
/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET SQL_NOTES=@OLD_SQL_NOTES */;
