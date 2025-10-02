-- HLBG Affixes lookup table (CharDB)
-- Create in your character database (CharDB). Provides mapping from affix names to numeric codes, with optional season scoping.

CREATE TABLE IF NOT EXISTS `hlbg_affixes` (
  `id` INT NOT NULL,
  `name` VARCHAR(64) NOT NULL,
  `season_id` INT NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_hlbg_affixes_name` (`name`),
  KEY `idx_hlbg_affixes_season` (`season_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Optional examples:
-- INSERT INTO hlbg_affixes (id, name, season_id) VALUES
-- (1, 'Storms', 1),
-- (2, 'Volcanic', 1),
-- (3, 'Haste', 1),
-- (4, 'Fortified', 2);

-- Notes:
-- - `id` should match the numeric affix code used in hlbg_winner_history.affix.
-- - `season_id` is optional; when provided by the client/server, name resolution prefers rows with matching season_id.
