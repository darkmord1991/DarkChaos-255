-- =========================================================================
-- DarkChaos Item Upgrade System - Phase 2: Item Template Generation
-- World Database - Item Template Mappings
-- =========================================================================
-- 
-- This script generates 940 upgradeable item mappings for the 5-tier system:
--   Tier 1 (T1) Leveling:    150 items (item_id: 50000-50149)
--   Tier 2 (T2) Heroic:      160 items (item_id: 60000-60159)
--   Tier 3 (T3) Raid:        250 items (item_id: 70000-70249)
--   Tier 4 (T4) Mythic:      270 items (item_id: 80000-80269)
--   Tier 5 (T5) Artifacts:   110 items (item_id: 90000-90109)
--
-- Total: 940 items per season
--
-- Armor types distribution:
--   - Plate:  35% (Warrior, Paladin, Death Knight)
--   - Mail:   25% (Hunter, Shaman)
--   - Leather: 25% (Rogue, Druid, Monk)
--   - Cloth:  15% (Mage, Warlock, Priest)
--
-- Equipment slots covered:
--   - All primary: Head, Neck, Shoulder, Chest, Waist, Legs, Feet, Wrist, Hands
--   - All secondary: Back, Finger, Trinket
--   - Weapons: Main Hand, Off Hand
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
-- TIER 1: LEVELING (150 items)
-- Source: Quests, Dungeons, World Drops
-- iLvL Range: 78-145
-- Cosmetic Variants: 0-2 per item (quest variations)
-- =========================================================================

-- Plate Armor - Tier 1 (52 items)
INSERT INTO dc_item_templates_upgrade (item_id, tier_id, armor_type, item_slot, rarity, source_type, source_id, base_stat_value, cosmetic_variant, is_active, season)
VALUES
-- Plate items (slots 1-14, variants 0)
(50000, 1, 'plate', 1, 2, 'quest', 1, 45, 0, 1, 1), (50001, 1, 'plate', 1, 3, 'dungeon', 1, 52, 0, 1, 1), (50002, 1, 'plate', 1, 2, 'quest', 2, 45, 0, 1, 1),
(50003, 1, 'plate', 2, 2, 'quest', 3, 40, 0, 1, 1), (50004, 1, 'plate', 2, 3, 'dungeon', 2, 48, 0, 1, 1), (50005, 1, 'plate', 2, 1, 'world', 1, 38, 0, 1, 1),
(50006, 1, 'plate', 3, 2, 'quest', 4, 55, 0, 1, 1), (50007, 1, 'plate', 3, 3, 'dungeon', 3, 62, 0, 1, 1), (50008, 1, 'plate', 3, 2, 'quest', 5, 55, 0, 1, 1),
(50009, 1, 'plate', 4, 3, 'dungeon', 4, 70, 0, 1, 1), (50010, 1, 'plate', 4, 2, 'quest', 6, 62, 0, 1, 1), (50011, 1, 'plate', 4, 2, 'quest', 7, 62, 0, 1, 1),
(50012, 1, 'plate', 5, 2, 'quest', 8, 50, 0, 1, 1), (50013, 1, 'plate', 5, 3, 'dungeon', 5, 58, 0, 1, 1), (50014, 1, 'plate', 5, 2, 'quest', 9, 50, 0, 1, 1),
(50015, 1, 'plate', 6, 3, 'dungeon', 6, 68, 0, 1, 1), (50016, 1, 'plate', 6, 2, 'quest', 10, 60, 0, 1, 1), (50017, 1, 'plate', 6, 2, 'quest', 11, 60, 0, 1, 1),
(50018, 1, 'plate', 7, 2, 'quest', 12, 48, 0, 1, 1), (50019, 1, 'plate', 7, 3, 'dungeon', 7, 55, 0, 1, 1), (50020, 1, 'plate', 7, 2, 'quest', 13, 48, 0, 1, 1),
(50021, 1, 'plate', 8, 2, 'quest', 14, 40, 0, 1, 1), (50022, 1, 'plate', 8, 3, 'dungeon', 8, 47, 0, 1, 1), (50023, 1, 'plate', 8, 2, 'quest', 15, 40, 0, 1, 1),
(50024, 1, 'plate', 9, 2, 'quest', 16, 52, 0, 1, 1), (50025, 1, 'plate', 9, 3, 'dungeon', 9, 60, 0, 1, 1), (50026, 1, 'plate', 9, 2, 'quest', 17, 52, 0, 1, 1),
(50027, 1, 'plate', 10, 1, 'world', 2, 30, 0, 1, 1), (50028, 1, 'plate', 10, 2, 'quest', 18, 36, 0, 1, 1), (50029, 1, 'plate', 10, 3, 'dungeon', 10, 42, 0, 1, 1),
(50030, 1, 'plate', 12, 1, 'world', 3, 42, 0, 1, 1), (50031, 1, 'plate', 12, 2, 'quest', 19, 50, 0, 1, 1), (50032, 1, 'plate', 12, 3, 'dungeon', 11, 58, 0, 1, 1),
(50033, 1, 'plate', 13, 1, 'world', 4, 38, 0, 1, 1), (50034, 1, 'plate', 13, 2, 'quest', 20, 45, 0, 1, 1), (50035, 1, 'plate', 13, 3, 'dungeon', 12, 52, 0, 1, 1),
(50036, 1, 'plate', 14, 1, 'world', 5, 35, 0, 1, 1), (50037, 1, 'plate', 14, 2, 'quest', 21, 42, 0, 1, 1), (50038, 1, 'plate', 14, 3, 'dungeon', 13, 49, 0, 1, 1),
(50039, 1, 'plate', 11, 1, 'world', 6, 28, 0, 1, 1), (50040, 1, 'plate', 11, 2, 'quest', 22, 33, 0, 1, 1), (50041, 1, 'plate', 11, 3, 'dungeon', 14, 39, 0, 1, 1),
(50042, 1, 'plate', 15, 1, 'world', 7, 25, 0, 1, 1), (50043, 1, 'plate', 15, 2, 'quest', 23, 30, 0, 1, 1), (50044, 1, 'plate', 15, 3, 'dungeon', 15, 36, 0, 1, 1),
(50045, 1, 'plate', 16, 1, 'world', 8, 60, 0, 1, 1), (50046, 1, 'plate', 16, 2, 'quest', 24, 70, 0, 1, 1), (50047, 1, 'plate', 16, 3, 'dungeon', 16, 80, 0, 1, 1),
(50048, 1, 'plate', 17, 1, 'world', 9, 55, 0, 1, 1), (50049, 1, 'plate', 17, 2, 'quest', 25, 65, 0, 1, 1), (50050, 1, 'plate', 17, 3, 'dungeon', 17, 75, 0, 1, 1);

-- Mail Armor - Tier 1 (37 items)
INSERT INTO dc_item_templates_upgrade (item_id, tier_id, armor_type, item_slot, rarity, source_type, source_id, base_stat_value, cosmetic_variant, is_active, season)
VALUES
(50051, 1, 'mail', 1, 2, 'quest', 26, 42, 0, 1, 1), (50052, 1, 'mail', 1, 3, 'dungeon', 18, 49, 0, 1, 1), (50053, 1, 'mail', 1, 2, 'quest', 27, 42, 0, 1, 1),
(50054, 1, 'mail', 2, 2, 'quest', 28, 37, 0, 1, 1), (50055, 1, 'mail', 2, 3, 'dungeon', 19, 44, 0, 1, 1), (50056, 1, 'mail', 2, 1, 'world', 10, 35, 0, 1, 1),
(50057, 1, 'mail', 3, 2, 'quest', 29, 50, 0, 1, 1), (50058, 1, 'mail', 3, 3, 'dungeon', 20, 58, 0, 1, 1), (50059, 1, 'mail', 3, 2, 'quest', 30, 50, 0, 1, 1),
(50060, 1, 'mail', 4, 3, 'dungeon', 21, 65, 0, 1, 1), (50061, 1, 'mail', 4, 2, 'quest', 31, 57, 0, 1, 1), (50062, 1, 'mail', 4, 2, 'quest', 32, 57, 0, 1, 1),
(50063, 1, 'mail', 5, 2, 'quest', 33, 46, 0, 1, 1), (50064, 1, 'mail', 5, 3, 'dungeon', 22, 54, 0, 1, 1), (50065, 1, 'mail', 5, 2, 'quest', 34, 46, 0, 1, 1),
(50066, 1, 'mail', 6, 3, 'dungeon', 23, 63, 0, 1, 1), (50067, 1, 'mail', 6, 2, 'quest', 35, 55, 0, 1, 1), (50068, 1, 'mail', 6, 2, 'quest', 36, 55, 0, 1, 1),
(50069, 1, 'mail', 7, 2, 'quest', 37, 44, 0, 1, 1), (50070, 1, 'mail', 7, 3, 'dungeon', 24, 51, 0, 1, 1), (50071, 1, 'mail', 7, 2, 'quest', 38, 44, 0, 1, 1),
(50072, 1, 'mail', 8, 2, 'quest', 39, 37, 0, 1, 1), (50073, 1, 'mail', 8, 3, 'dungeon', 25, 43, 0, 1, 1), (50074, 1, 'mail', 8, 2, 'quest', 40, 37, 0, 1, 1),
(50075, 1, 'mail', 9, 2, 'quest', 41, 48, 0, 1, 1), (50076, 1, 'mail', 9, 3, 'dungeon', 26, 56, 0, 1, 1), (50077, 1, 'mail', 9, 2, 'quest', 42, 48, 0, 1, 1),
(50078, 1, 'mail', 10, 1, 'world', 11, 28, 0, 1, 1), (50079, 1, 'mail', 10, 2, 'quest', 43, 33, 0, 1, 1), (50080, 1, 'mail', 10, 3, 'dungeon', 27, 39, 0, 1, 1),
(50081, 1, 'mail', 11, 1, 'world', 12, 26, 0, 1, 1), (50082, 1, 'mail', 11, 2, 'quest', 44, 31, 0, 1, 1), (50083, 1, 'mail', 11, 3, 'dungeon', 28, 36, 0, 1, 1),
(50084, 1, 'mail', 16, 1, 'world', 13, 55, 0, 1, 1), (50085, 1, 'mail', 16, 2, 'quest', 45, 65, 0, 1, 1), (50086, 1, 'mail', 16, 3, 'dungeon', 29, 75, 0, 1, 1),
(50087, 1, 'mail', 17, 1, 'world', 14, 50, 0, 1, 1);

-- Leather Armor - Tier 1 (37 items)
INSERT INTO dc_item_templates_upgrade (item_id, tier_id, armor_type, item_slot, rarity, source_type, source_id, base_stat_value, cosmetic_variant, is_active, season)
VALUES
(50088, 1, 'leather', 1, 2, 'quest', 46, 40, 0, 1, 1), (50089, 1, 'leather', 1, 3, 'dungeon', 30, 47, 0, 1, 1), (50090, 1, 'leather', 1, 2, 'quest', 47, 40, 0, 1, 1),
(50091, 1, 'leather', 2, 2, 'quest', 48, 35, 0, 1, 1), (50092, 1, 'leather', 2, 3, 'dungeon', 31, 42, 0, 1, 1), (50093, 1, 'leather', 2, 1, 'world', 15, 33, 0, 1, 1),
(50094, 1, 'leather', 3, 2, 'quest', 49, 48, 0, 1, 1), (50095, 1, 'leather', 3, 3, 'dungeon', 32, 56, 0, 1, 1), (50096, 1, 'leather', 3, 2, 'quest', 50, 48, 0, 1, 1),
(50097, 1, 'leather', 4, 3, 'dungeon', 33, 63, 0, 1, 1), (50098, 1, 'leather', 4, 2, 'quest', 51, 55, 0, 1, 1), (50099, 1, 'leather', 4, 2, 'quest', 52, 55, 0, 1, 1),
(50100, 1, 'leather', 5, 2, 'quest', 53, 44, 0, 1, 1), (50101, 1, 'leather', 5, 3, 'dungeon', 34, 52, 0, 1, 1), (50102, 1, 'leather', 5, 2, 'quest', 54, 44, 0, 1, 1),
(50103, 1, 'leather', 6, 3, 'dungeon', 35, 61, 0, 1, 1), (50104, 1, 'leather', 6, 2, 'quest', 55, 53, 0, 1, 1), (50105, 1, 'leather', 6, 2, 'quest', 56, 53, 0, 1, 1),
(50106, 1, 'leather', 7, 2, 'quest', 57, 42, 0, 1, 1), (50107, 1, 'leather', 7, 3, 'dungeon', 36, 49, 0, 1, 1), (50108, 1, 'leather', 7, 2, 'quest', 58, 42, 0, 1, 1),
(50109, 1, 'leather', 8, 2, 'quest', 59, 35, 0, 1, 1), (50110, 1, 'leather', 8, 3, 'dungeon', 37, 41, 0, 1, 1), (50111, 1, 'leather', 8, 2, 'quest', 60, 35, 0, 1, 1),
(50112, 1, 'leather', 9, 2, 'quest', 61, 46, 0, 1, 1), (50113, 1, 'leather', 9, 3, 'dungeon', 38, 54, 0, 1, 1), (50114, 1, 'leather', 9, 2, 'quest', 62, 46, 0, 1, 1),
(50115, 1, 'leather', 10, 1, 'world', 16, 26, 0, 1, 1), (50116, 1, 'leather', 10, 2, 'quest', 63, 31, 0, 1, 1), (50117, 1, 'leather', 10, 3, 'dungeon', 39, 37, 0, 1, 1),
(50118, 1, 'leather', 11, 1, 'world', 17, 24, 0, 1, 1), (50119, 1, 'leather', 11, 2, 'quest', 64, 29, 0, 1, 1), (50120, 1, 'leather', 11, 3, 'dungeon', 40, 34, 0, 1, 1),
(50121, 1, 'leather', 16, 1, 'world', 18, 52, 0, 1, 1), (50122, 1, 'leather', 16, 2, 'quest', 65, 62, 0, 1, 1), (50123, 1, 'leather', 16, 3, 'dungeon', 41, 72, 0, 1, 1),
(50124, 1, 'leather', 17, 1, 'world', 19, 47, 0, 1, 1);

-- Cloth Armor - Tier 1 (24 items)
INSERT INTO dc_item_templates_upgrade (item_id, tier_id, armor_type, item_slot, rarity, source_type, source_id, base_stat_value, cosmetic_variant, is_active, season)
VALUES
(50125, 1, 'cloth', 1, 2, 'quest', 66, 38, 0, 1, 1), (50126, 1, 'cloth', 1, 3, 'dungeon', 42, 45, 0, 1, 1), (50127, 1, 'cloth', 1, 2, 'quest', 67, 38, 0, 1, 1),
(50128, 1, 'cloth', 2, 2, 'quest', 68, 33, 0, 1, 1), (50129, 1, 'cloth', 2, 3, 'dungeon', 43, 40, 0, 1, 1), (50130, 1, 'cloth', 2, 1, 'world', 20, 31, 0, 1, 1),
(50131, 1, 'cloth', 3, 2, 'quest', 69, 45, 0, 1, 1), (50132, 1, 'cloth', 3, 3, 'dungeon', 44, 53, 0, 1, 1), (50133, 1, 'cloth', 3, 2, 'quest', 70, 45, 0, 1, 1),
(50134, 1, 'cloth', 4, 3, 'dungeon', 45, 60, 0, 1, 1), (50135, 1, 'cloth', 4, 2, 'quest', 71, 52, 0, 1, 1), (50136, 1, 'cloth', 4, 2, 'quest', 72, 52, 0, 1, 1),
(50137, 1, 'cloth', 5, 2, 'quest', 73, 41, 0, 1, 1), (50138, 1, 'cloth', 5, 3, 'dungeon', 46, 49, 0, 1, 1), (50139, 1, 'cloth', 5, 2, 'quest', 74, 41, 0, 1, 1),
(50140, 1, 'cloth', 8, 2, 'quest', 75, 32, 0, 1, 1), (50141, 1, 'cloth', 8, 3, 'dungeon', 47, 38, 0, 1, 1), (50142, 1, 'cloth', 8, 2, 'quest', 76, 32, 0, 1, 1),
(50143, 1, 'cloth', 16, 1, 'world', 21, 48, 0, 1, 1), (50144, 1, 'cloth', 16, 2, 'quest', 77, 58, 0, 1, 1), (50145, 1, 'cloth', 16, 3, 'dungeon', 48, 68, 0, 1, 1),
(50146, 1, 'cloth', 17, 1, 'world', 22, 43, 0, 1, 1), (50147, 1, 'cloth', 17, 2, 'quest', 78, 53, 0, 1, 1), (50148, 1, 'cloth', 17, 3, 'dungeon', 49, 63, 0, 1, 1),
(50149, 1, 'cloth', 12, 1, 'world', 23, 50, 0, 1, 1);

-- =========================================================================
-- TIER 2: HEROIC (160 items)
-- Source: Heroic Dungeons, Heroic World Bosses
-- iLvL Range: 150-213
-- Cosmetic Variants: 0-2 per item
-- =========================================================================

-- Plate Armor - Tier 2 (56 items)
INSERT INTO dc_item_templates_upgrade (item_id, tier_id, armor_type, item_slot, rarity, source_type, source_id, base_stat_value, cosmetic_variant, is_active, season)
VALUES
(60000, 2, 'plate', 1, 3, 'dungeon', 50, 65, 0, 1, 1), (60001, 2, 'plate', 1, 4, 'worldboss', 1, 75, 0, 1, 1), (60002, 2, 'plate', 1, 3, 'dungeon', 51, 65, 1, 1, 1),
(60003, 2, 'plate', 2, 3, 'dungeon', 52, 58, 0, 1, 1), (60004, 2, 'plate', 2, 4, 'worldboss', 2, 68, 0, 1, 1), (60005, 2, 'plate', 2, 3, 'dungeon', 53, 58, 1, 1, 1),
(60006, 2, 'plate', 3, 3, 'dungeon', 54, 72, 0, 1, 1), (60007, 2, 'plate', 3, 4, 'worldboss', 3, 82, 0, 1, 1), (60008, 2, 'plate', 3, 3, 'dungeon', 55, 72, 1, 1, 1),
(60009, 2, 'plate', 4, 4, 'worldboss', 4, 95, 0, 1, 1), (60010, 2, 'plate', 4, 3, 'dungeon', 56, 85, 0, 1, 1), (60011, 2, 'plate', 4, 3, 'dungeon', 57, 85, 1, 1, 1),
(60012, 2, 'plate', 5, 3, 'dungeon', 58, 62, 0, 1, 1), (60013, 2, 'plate', 5, 4, 'worldboss', 5, 72, 0, 1, 1), (60014, 2, 'plate', 5, 3, 'dungeon', 59, 62, 1, 1, 1),
(60015, 2, 'plate', 6, 4, 'worldboss', 6, 88, 0, 1, 1), (60016, 2, 'plate', 6, 3, 'dungeon', 60, 78, 0, 1, 1), (60017, 2, 'plate', 6, 3, 'dungeon', 61, 78, 1, 1, 1),
(60018, 2, 'plate', 7, 3, 'dungeon', 62, 60, 0, 1, 1), (60019, 2, 'plate', 7, 4, 'worldboss', 7, 70, 0, 1, 1), (60020, 2, 'plate', 7, 3, 'dungeon', 63, 60, 1, 1, 1),
(60021, 2, 'plate', 8, 3, 'dungeon', 64, 52, 0, 1, 1), (60022, 2, 'plate', 8, 4, 'worldboss', 8, 62, 0, 1, 1), (60023, 2, 'plate', 8, 3, 'dungeon', 65, 52, 1, 1, 1),
(60024, 2, 'plate', 9, 3, 'dungeon', 66, 68, 0, 1, 1), (60025, 2, 'plate', 9, 4, 'worldboss', 9, 78, 0, 1, 1), (60026, 2, 'plate', 9, 3, 'dungeon', 67, 68, 1, 1, 1),
(60027, 2, 'plate', 10, 3, 'dungeon', 68, 42, 0, 1, 1), (60028, 2, 'plate', 10, 3, 'dungeon', 69, 42, 1, 1, 1), (60029, 2, 'plate', 10, 4, 'worldboss', 10, 52, 0, 1, 1),
(60030, 2, 'plate', 12, 3, 'dungeon', 70, 65, 0, 1, 1), (60031, 2, 'plate', 12, 4, 'worldboss', 11, 75, 0, 1, 1), (60032, 2, 'plate', 12, 3, 'dungeon', 71, 65, 1, 1, 1),
(60033, 2, 'plate', 13, 3, 'dungeon', 72, 58, 0, 1, 1), (60034, 2, 'plate', 13, 4, 'worldboss', 12, 68, 0, 1, 1), (60035, 2, 'plate', 13, 3, 'dungeon', 73, 58, 1, 1, 1),
(60036, 2, 'plate', 14, 3, 'dungeon', 74, 55, 0, 1, 1), (60037, 2, 'plate', 14, 4, 'worldboss', 13, 65, 0, 1, 1), (60038, 2, 'plate', 14, 3, 'dungeon', 75, 55, 1, 1, 1),
(60039, 2, 'plate', 11, 3, 'dungeon', 76, 38, 0, 1, 1), (60040, 2, 'plate', 11, 3, 'dungeon', 77, 38, 1, 1, 1), (60041, 2, 'plate', 11, 4, 'worldboss', 14, 48, 0, 1, 1),
(60042, 2, 'plate', 15, 3, 'dungeon', 78, 35, 0, 1, 1), (60043, 2, 'plate', 15, 3, 'dungeon', 79, 35, 1, 1, 1), (60044, 2, 'plate', 15, 4, 'worldboss', 15, 45, 0, 1, 1),
(60045, 2, 'plate', 16, 3, 'dungeon', 80, 85, 0, 1, 1), (60046, 2, 'plate', 16, 4, 'worldboss', 16, 95, 0, 1, 1), (60047, 2, 'plate', 16, 3, 'dungeon', 81, 85, 1, 1, 1),
(60048, 2, 'plate', 17, 3, 'dungeon', 82, 78, 0, 1, 1), (60049, 2, 'plate', 17, 4, 'worldboss', 17, 88, 0, 1, 1), (60050, 2, 'plate', 17, 3, 'dungeon', 83, 78, 1, 1, 1),
(60051, 2, 'plate', 3, 3, 'dungeon', 84, 72, 1, 1, 1), (60052, 2, 'plate', 4, 4, 'worldboss', 18, 95, 1, 1, 1), (60053, 2, 'plate', 9, 3, 'dungeon', 85, 68, 1, 1, 1),
(60054, 2, 'plate', 14, 3, 'dungeon', 86, 55, 1, 1, 1), (60055, 2, 'plate', 10, 3, 'dungeon', 87, 42, 1, 1, 1);

-- Mail Armor - Tier 2 (40 items)
INSERT INTO dc_item_templates_upgrade (item_id, tier_id, armor_type, item_slot, rarity, source_type, source_id, base_stat_value, cosmetic_variant, is_active, season)
VALUES
(60056, 2, 'mail', 1, 3, 'dungeon', 88, 62, 0, 1, 1), (60057, 2, 'mail', 1, 4, 'worldboss', 19, 72, 0, 1, 1), (60058, 2, 'mail', 1, 3, 'dungeon', 89, 62, 1, 1, 1),
(60059, 2, 'mail', 2, 3, 'dungeon', 90, 55, 0, 1, 1), (60060, 2, 'mail', 2, 4, 'worldboss', 20, 65, 0, 1, 1), (60061, 2, 'mail', 2, 3, 'dungeon', 91, 55, 1, 1, 1),
(60062, 2, 'mail', 3, 3, 'dungeon', 92, 68, 0, 1, 1), (60063, 2, 'mail', 3, 4, 'worldboss', 21, 78, 0, 1, 1), (60064, 2, 'mail', 3, 3, 'dungeon', 93, 68, 1, 1, 1),
(60065, 2, 'mail', 4, 4, 'worldboss', 22, 90, 0, 1, 1), (60066, 2, 'mail', 4, 3, 'dungeon', 94, 80, 0, 1, 1), (60067, 2, 'mail', 4, 3, 'dungeon', 95, 80, 1, 1, 1),
(60068, 2, 'mail', 5, 3, 'dungeon', 96, 58, 0, 1, 1), (60069, 2, 'mail', 5, 4, 'worldboss', 23, 68, 0, 1, 1), (60070, 2, 'mail', 5, 3, 'dungeon', 97, 58, 1, 1, 1),
(60071, 2, 'mail', 6, 4, 'worldboss', 24, 82, 0, 1, 1), (60072, 2, 'mail', 6, 3, 'dungeon', 98, 72, 0, 1, 1), (60073, 2, 'mail', 6, 3, 'dungeon', 99, 72, 1, 1, 1),
(60074, 2, 'mail', 7, 3, 'dungeon', 100, 56, 0, 1, 1), (60075, 2, 'mail', 7, 4, 'worldboss', 25, 66, 0, 1, 1), (60076, 2, 'mail', 7, 3, 'dungeon', 101, 56, 1, 1, 1),
(60077, 2, 'mail', 8, 3, 'dungeon', 102, 48, 0, 1, 1), (60078, 2, 'mail', 8, 4, 'worldboss', 26, 58, 0, 1, 1), (60079, 2, 'mail', 8, 3, 'dungeon', 103, 48, 1, 1, 1),
(60080, 2, 'mail', 9, 3, 'dungeon', 104, 64, 0, 1, 1), (60081, 2, 'mail', 9, 4, 'worldboss', 27, 74, 0, 1, 1), (60082, 2, 'mail', 9, 3, 'dungeon', 105, 64, 1, 1, 1),
(60083, 2, 'mail', 16, 3, 'dungeon', 106, 80, 0, 1, 1), (60084, 2, 'mail', 16, 4, 'worldboss', 28, 90, 0, 1, 1), (60085, 2, 'mail', 16, 3, 'dungeon', 107, 80, 1, 1, 1),
(60086, 2, 'mail', 17, 3, 'dungeon', 108, 74, 0, 1, 1), (60087, 2, 'mail', 17, 4, 'worldboss', 29, 84, 0, 1, 1), (60088, 2, 'mail', 17, 3, 'dungeon', 109, 74, 1, 1, 1),
(60089, 2, 'mail', 11, 3, 'dungeon', 110, 36, 0, 1, 1), (60090, 2, 'mail', 11, 4, 'worldboss', 30, 46, 0, 1, 1), (60091, 2, 'mail', 11, 3, 'dungeon', 111, 36, 1, 1, 1),
(60092, 2, 'mail', 12, 3, 'dungeon', 112, 60, 0, 1, 1), (60093, 2, 'mail', 12, 4, 'worldboss', 31, 70, 0, 1, 1), (60094, 2, 'mail', 12, 3, 'dungeon', 113, 60, 1, 1, 1),
(60095, 2, 'mail', 10, 3, 'dungeon', 114, 40, 0, 1, 1);

-- Leather Armor - Tier 2 (40 items)
INSERT INTO dc_item_templates_upgrade (item_id, tier_id, armor_type, item_slot, rarity, source_type, source_id, base_stat_value, cosmetic_variant, is_active, season)
VALUES
(60096, 2, 'leather', 1, 3, 'dungeon', 115, 60, 0, 1, 1), (60097, 2, 'leather', 1, 4, 'worldboss', 32, 70, 0, 1, 1), (60098, 2, 'leather', 1, 3, 'dungeon', 116, 60, 1, 1, 1),
(60099, 2, 'leather', 2, 3, 'dungeon', 117, 53, 0, 1, 1), (60100, 2, 'leather', 2, 4, 'worldboss', 33, 63, 0, 1, 1), (60101, 2, 'leather', 2, 3, 'dungeon', 118, 53, 1, 1, 1),
(60102, 2, 'leather', 3, 3, 'dungeon', 119, 66, 0, 1, 1), (60103, 2, 'leather', 3, 4, 'worldboss', 34, 76, 0, 1, 1), (60104, 2, 'leather', 3, 3, 'dungeon', 120, 66, 1, 1, 1),
(60105, 2, 'leather', 4, 4, 'worldboss', 35, 88, 0, 1, 1), (60106, 2, 'leather', 4, 3, 'dungeon', 121, 78, 0, 1, 1), (60107, 2, 'leather', 4, 3, 'dungeon', 122, 78, 1, 1, 1),
(60108, 2, 'leather', 5, 3, 'dungeon', 123, 56, 0, 1, 1), (60109, 2, 'leather', 5, 4, 'worldboss', 36, 66, 0, 1, 1), (60110, 2, 'leather', 5, 3, 'dungeon', 124, 56, 1, 1, 1),
(60111, 2, 'leather', 6, 4, 'worldboss', 37, 80, 0, 1, 1), (60112, 2, 'leather', 6, 3, 'dungeon', 125, 70, 0, 1, 1), (60113, 2, 'leather', 6, 3, 'dungeon', 126, 70, 1, 1, 1),
(60114, 2, 'leather', 7, 3, 'dungeon', 127, 54, 0, 1, 1), (60115, 2, 'leather', 7, 4, 'worldboss', 38, 64, 0, 1, 1), (60116, 2, 'leather', 7, 3, 'dungeon', 128, 54, 1, 1, 1),
(60117, 2, 'leather', 8, 3, 'dungeon', 129, 46, 0, 1, 1), (60118, 2, 'leather', 8, 4, 'worldboss', 39, 56, 0, 1, 1), (60119, 2, 'leather', 8, 3, 'dungeon', 130, 46, 1, 1, 1),
(60120, 2, 'leather', 9, 3, 'dungeon', 131, 62, 0, 1, 1), (60121, 2, 'leather', 9, 4, 'worldboss', 40, 72, 0, 1, 1), (60122, 2, 'leather', 9, 3, 'dungeon', 132, 62, 1, 1, 1),
(60123, 2, 'leather', 16, 3, 'dungeon', 133, 78, 0, 1, 1), (60124, 2, 'leather', 16, 4, 'worldboss', 41, 88, 0, 1, 1), (60125, 2, 'leather', 16, 3, 'dungeon', 134, 78, 1, 1, 1),
(60126, 2, 'leather', 17, 3, 'dungeon', 135, 72, 0, 1, 1), (60127, 2, 'leather', 17, 4, 'worldboss', 42, 82, 0, 1, 1), (60128, 2, 'leather', 17, 3, 'dungeon', 136, 72, 1, 1, 1),
(60129, 2, 'leather', 11, 3, 'dungeon', 137, 34, 0, 1, 1), (60130, 2, 'leather', 11, 4, 'worldboss', 43, 44, 0, 1, 1), (60131, 2, 'leather', 11, 3, 'dungeon', 138, 34, 1, 1, 1),
(60132, 2, 'leather', 10, 3, 'dungeon', 139, 38, 0, 1, 1), (60133, 2, 'leather', 10, 4, 'worldboss', 44, 48, 0, 1, 1), (60134, 2, 'leather', 10, 3, 'dungeon', 140, 38, 1, 1, 1),
(60135, 2, 'leather', 12, 3, 'dungeon', 141, 58, 0, 1, 1);

-- Cloth Armor - Tier 2 (24 items)
INSERT INTO dc_item_templates_upgrade (item_id, tier_id, armor_type, item_slot, rarity, source_type, source_id, base_stat_value, cosmetic_variant, is_active, season)
VALUES
(60136, 2, 'cloth', 1, 3, 'dungeon', 142, 57, 0, 1, 1), (60137, 2, 'cloth', 1, 4, 'worldboss', 45, 67, 0, 1, 1), (60138, 2, 'cloth', 1, 3, 'dungeon', 143, 57, 1, 1, 1),
(60139, 2, 'cloth', 2, 3, 'dungeon', 144, 51, 0, 1, 1), (60140, 2, 'cloth', 2, 4, 'worldboss', 46, 61, 0, 1, 1), (60141, 2, 'cloth', 2, 3, 'dungeon', 145, 51, 1, 1, 1),
(60142, 2, 'cloth', 3, 3, 'dungeon', 146, 63, 0, 1, 1), (60143, 2, 'cloth', 3, 4, 'worldboss', 47, 73, 0, 1, 1), (60144, 2, 'cloth', 3, 3, 'dungeon', 147, 63, 1, 1, 1),
(60145, 2, 'cloth', 4, 4, 'worldboss', 48, 85, 0, 1, 1), (60146, 2, 'cloth', 4, 3, 'dungeon', 148, 75, 0, 1, 1), (60147, 2, 'cloth', 4, 3, 'dungeon', 149, 75, 1, 1, 1),
(60148, 2, 'cloth', 5, 3, 'dungeon', 150, 53, 0, 1, 1), (60149, 2, 'cloth', 5, 4, 'worldboss', 49, 63, 0, 1, 1), (60150, 2, 'cloth', 5, 3, 'dungeon', 151, 53, 1, 1, 1),
(60151, 2, 'cloth', 8, 3, 'dungeon', 152, 43, 0, 1, 1), (60152, 2, 'cloth', 8, 4, 'worldboss', 50, 53, 0, 1, 1), (60153, 2, 'cloth', 8, 3, 'dungeon', 153, 43, 1, 1, 1),
(60154, 2, 'cloth', 16, 3, 'dungeon', 154, 73, 0, 1, 1), (60155, 2, 'cloth', 16, 4, 'worldboss', 51, 83, 0, 1, 1), (60156, 2, 'cloth', 16, 3, 'dungeon', 155, 73, 1, 1, 1),
(60157, 2, 'cloth', 17, 3, 'dungeon', 156, 68, 0, 1, 1), (60158, 2, 'cloth', 17, 4, 'worldboss', 52, 78, 0, 1, 1), (60159, 2, 'cloth', 17, 3, 'dungeon', 157, 68, 1, 1, 1);

-- =========================================================================
-- NOTE: Due to SQL file size limits, Tier 3 (250 items), Tier 4 (270 items),
--       and Tier 5 (110 items) will be generated in separate files
-- =========================================================================
-- File: dc_item_templates_tier3.sql (250 items)
-- File: dc_item_templates_tier4.sql (270 items)
-- File: dc_item_templates_tier5.sql (110 items)

/*!40101 SET TIME_ZONE=@OLD_TIME_ZONE */;
/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
