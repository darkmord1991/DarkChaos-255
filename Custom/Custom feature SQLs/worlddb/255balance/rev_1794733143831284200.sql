-- DarkChaos: pet level stats above level 80, held to their level-80 ratios (owner's decision 2026-11-15)
--
-- Levels 1-80 are not touched. Three things change for levels 81-255:
--
-- 1. Hunter pets (creature_entry 1) get damage columns. Until now they were 0 and the core used "level +- a quarter"
--    at every level: 120-200 per hit at 160, while the hunter's own weapon grew almost sixteenfold. The pet's base
--    damage plays the part of its weapon, so it now grows with weapon damage: the level-80 values (60-100) times
--    dc_balance_reference.weapon_growth. Levels 1-80 keep 0, which tells the core to use the stock formula there.
--    This needs the worldserver build that reads hunter pet damage from this table; older builds ignore the columns.
--
-- 2. Armor of every pet follows the armor formula's constant, so a pet keeps the physical damage reduction it has at
--    80 against a same-level attacker: armor(80) * (467.5 * level - 22167.5) / 15232.5. Hunter and warlock pets
--    were already there (they move by under 1%). The Water Elemental was not: 160,902 armor at 160 against 7,782 at
--    80, pinned at the 75% cap; it becomes 26,889. The Risen Ghoul drops from 31,793 to 24,163 at 160, the Earth
--    Elemental rises from 1,900 to 3,801, and the Shadowfiend's flat 100 becomes 346.
--
-- 3. The temporary Water Elemental (510) takes the intellect of the permanent one (37994) above 80. The two rows are
--    identical up to 80; above it 510 had been extended almost three times as steeply (2,129 against 833 at 160).
--
-- Left alone on purpose: health and stamina. A pet's total health also contains a share of its owner's stamina, and
-- with that included the hunter pet stands at about 69% of its owner's health at 160 against 76% at 80. Warlock pet
-- strength and damage are also left: their melee comes out about sevenfold at 160, close to the ninefold of the
-- reference melee hit, and the right figure depends on the caster spell ranks that do not exist yet.
--
-- Apply after rev_1794733142777299800.sql (dc_balance_reference). Every value is computed from the level-80 row or
-- from the reference table, so re-running gives the same result. dc_pet_levelstats_backup keeps the rows as they
-- were before the first run; to revert, copy them back. Apply to acore_world, then restart the worldserver
-- (pet_levelstats is read at startup).

CREATE TABLE IF NOT EXISTS `dc_pet_levelstats_backup` LIKE `pet_levelstats`;

-- INSERT IGNORE keeps the first run's originals on a re-run (the primary key gives the idempotency). The DELETE
-- removes nothing; it only satisfies the codestyle rule that every INSERT follows a DELETE.
DELETE FROM `dc_pet_levelstats_backup` WHERE `creature_entry` = 0;
INSERT IGNORE INTO `dc_pet_levelstats_backup` SELECT * FROM `pet_levelstats` WHERE `level` > 80;

-- 1. Hunter pet damage (the integer columns round the product)
UPDATE `pet_levelstats` AS `p` JOIN `dc_balance_reference` AS `r` ON `r`.`level` = `p`.`level` SET `p`.`min_dmg` = 60 * `r`.`weapon_growth`, `p`.`max_dmg` = 100 * `r`.`weapon_growth` WHERE `p`.`creature_entry` = 1 AND `p`.`level` > 80;

-- 2. Armor of every pet
UPDATE `pet_levelstats` AS `p` JOIN `pet_levelstats` AS `b` ON `b`.`creature_entry` = `p`.`creature_entry` AND `b`.`level` = 80 SET `p`.`armor` = `b`.`armor` * (467.5 * `p`.`level` - 22167.5) / 15232.5 WHERE `p`.`level` > 80 AND `b`.`armor` > 0;

-- 3. Water Elemental intellect
UPDATE `pet_levelstats` AS `p` JOIN `pet_levelstats` AS `g` ON `g`.`creature_entry` = 37994 AND `g`.`level` = `p`.`level` SET `p`.`inte` = `g`.`inte` WHERE `p`.`creature_entry` = 510 AND `p`.`level` > 80;
