-- DarkChaos-255 Prestige Talents: per-character allocation of the account-wide prestige talent pool.
-- Talent definitions live in src/server/scripts/DC/Progression/Prestige/dc_prestige_talents.cpp.
CREATE TABLE IF NOT EXISTS `dc_character_prestige_talents` (
  `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
  `talent_id` SMALLINT UNSIGNED NOT NULL COMMENT 'PrestigeTalentDef::id',
  `rank` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`guid`, `talent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Prestige talent ranks per character';
