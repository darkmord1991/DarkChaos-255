-- Persisted death markers (world-map pins for Hardcore / Iron Prestige deaths).
-- Mirrors the in-memory DeathMarker struct in dc_addon_death_markers.cpp so markers
-- survive a worldserver restart; rows are cleaned up opportunistically once expired.
CREATE TABLE IF NOT EXISTS `dc_death_markers` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `mode_id` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `mode_label` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `victim_guid` int unsigned NOT NULL DEFAULT 0,
  `victim_name` varchar(24) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `victim_level` tinyint unsigned NOT NULL DEFAULT 0,
  `victim_class` tinyint unsigned NOT NULL DEFAULT 0,
  `killer_type` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'unknown',
  `killer_entry` int unsigned NOT NULL DEFAULT 0,
  `killer_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `environment_type` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `killing_blow_damage` int unsigned NOT NULL DEFAULT 0,
  `failure_reason` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Died.',
  `map_id` int unsigned NOT NULL DEFAULT 0,
  `pos_x` float NOT NULL DEFAULT 0,
  `pos_y` float NOT NULL DEFAULT 0,
  `died_at` int unsigned NOT NULL DEFAULT 0,
  `expires_at` int unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_expires_at` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Persisted death markers for the world-map death-marker feature';
