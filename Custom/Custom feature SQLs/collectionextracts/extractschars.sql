/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

CREATE TABLE IF NOT EXISTS `dc_collection_shop` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `collection_type` tinyint unsigned NOT NULL COMMENT '1..6 (see dc_collection_items.collection_type)',
  `entry_id` int unsigned NOT NULL,
  `price_tokens` int unsigned NOT NULL DEFAULT '0',
  `price_emblems` int unsigned NOT NULL DEFAULT '0',
  `discount_percent` tinyint unsigned NOT NULL DEFAULT '0',
  `available_from` datetime DEFAULT NULL,
  `available_until` datetime DEFAULT NULL,
  `stock_remaining` int DEFAULT NULL COMMENT 'NULL or <0 for unlimited',
  `featured` tinyint(1) NOT NULL DEFAULT '0',
  `enabled` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  KEY `idx_enabled_time` (`enabled`,`available_from`,`available_until`),
  KEY `idx_type` (`collection_type`)
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Collection shop (generic)';

INSERT INTO `dc_collection_shop` (`id`, `collection_type`, `entry_id`, `price_tokens`, `price_emblems`, `discount_percent`, `available_from`, `available_until`, `stock_remaining`, `featured`, `enabled`) VALUES
	(1, 1, 300700, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(2, 1, 300701, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(3, 1, 300702, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(4, 1, 300703, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(5, 1, 300704, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(6, 1, 300705, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(7, 1, 300706, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(8, 1, 300707, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(9, 1, 300720, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(10, 1, 300721, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(11, 1, 300722, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(12, 1, 300723, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(13, 1, 300724, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(14, 1, 300725, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(15, 1, 300726, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(16, 1, 300727, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(17, 1, 300728, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(18, 1, 300729, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(19, 1, 300730, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(20, 1, 300731, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(21, 1, 300732, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(22, 1, 300733, 500, 500, 0, NULL, NULL, NULL, 0, 1),
	(23, 1, 300734, 500, 500, 0, NULL, NULL, NULL, 0, 1);

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
