-- Migration 001: create hlbg_affixes table in CharDB
-- Place this in Custom/Hinterland BG/CharDB and apply to your characters database.

CREATE TABLE IF NOT EXISTS `hlbg_affixes` (
  `id` INT NOT NULL,
  `name` VARCHAR(64) NOT NULL,
  `effect` TEXT NULL,
  `season_id` INT NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_hlbg_affixes_name` (`name`),
  KEY `idx_hlbg_affixes_season` (`season_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Optional seed data examples:
-- INSERT INTO hlbg_affixes (id, name, effect, season_id) VALUES
-- (1, 'Storms', 'Periodic lightning storms that damage and stun', 1),
-- (2, 'Volcanic', 'Eruptions on the ground that knock back', 1),
-- (3, 'Haste', 'Combatants gain periodic movement/attack speed boosts', 1);
