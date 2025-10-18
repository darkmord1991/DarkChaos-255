-- Custom SQL: Persist AoE Loot accumulated credited gold per character
-- Place this file into your characters DB import path or run it manually against acore_characters

DROP TABLE IF EXISTS `dc_aoeloot_credits`;
CREATE TABLE IF NOT EXISTS `dc_aoeloot_credits` (
  `guid` INT UNSIGNED NOT NULL,
  `accumulated` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
