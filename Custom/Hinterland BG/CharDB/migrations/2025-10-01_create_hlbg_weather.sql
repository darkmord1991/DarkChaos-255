-- Migration: Create hlbg_weather table to describe weather codes
-- Characters DB

CREATE TABLE IF NOT EXISTS `hlbg_weather` (
  `weather` TINYINT UNSIGNED NOT NULL,
  `name` VARCHAR(32) NOT NULL,
  `description` VARCHAR(255) NULL,
  PRIMARY KEY (`weather`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed common codes
INSERT INTO `hlbg_weather` (`weather`, `name`, `description`) VALUES
(0, 'Fine', 'Clear weather'),
(1, 'Rain', 'Light to heavy rain'),
(2, 'Snow', 'Snowfall'),
(3, 'Storm', 'Thunderstorm with heavy winds')
ON DUPLICATE KEY UPDATE name=VALUES(name), description=VALUES(description);
