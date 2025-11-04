-- =========================================================================
-- DarkChaos Item Upgrade System - Phase 2c: Currency Items
-- World Database - Item Template Entries
-- =========================================================================
-- 
-- Currency Items: 2 total
--   1. Upgrade Token (49999) - Used for Tiers 1-4 upgrades
--   2. Artifact Essence (49998) - Used for Tier 5 (Chaos Artifacts)
--
-- These are quest items that can't be traded or sold, used for currency
-- They appear in player bags but are "currency" type with no durability
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
-- CURRENCY ITEMS
-- Used for item upgrade system economy
-- =========================================================================

-- Upgrade Token (ID: 100999)
-- Used for Tiers 1-4 item upgrades
-- Currency item, not tradeable, stackable up to 1000
INSERT INTO item_template (entry, class, subclass, name, displayid, Quality, Flags, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, maxcount, bonding, description)
VALUES
(100999, 12, 0, 'Upgrade Token', 9488, 1, 64, 0, -1, -1, 1, 1, 1000, 1, 'Currency used to upgrade items to Tier 1-4');

-- Artifact Essence (ID: 109998)
-- Used for Tier 5 (Chaos Artifacts) item upgrades
-- Currency item, not tradeable, stackable up to 500
INSERT INTO item_template (entry, class, subclass, name, displayid, Quality, Flags, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, maxcount, bonding, description)
VALUES
(109998, 12, 0, 'Artifact Essence', 20588, 3, 64, 0, -1, -1, 1, 1, 500, 1, 'Essence used to discover and upgrade Chaos Artifacts (Tier 5)');

/*!40101 SET TIME_ZONE=@OLD_TIME_ZONE */;
/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET SQL_NOTES=@OLD_SQL_NOTES */;
