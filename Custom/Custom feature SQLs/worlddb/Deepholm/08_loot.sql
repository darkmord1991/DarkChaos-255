-- =====================================================================
-- Deepholm Downport  --  08  Loot tables  (Cata map 646)
-- ---------------------------------------------------------------------
-- Source: cata_world (TrinityCore 4.3.4).  Target: acore_world.
-- REQUIRES cata_world present on the same server at import time (read-only).
-- Run AFTER 01 (creature templates) -- loot ids are taken from the imported
-- creature_template.lootid / skinloot / pickpocketloot and GO chest Data1.
--
-- Mapping notes:
--   * Cata `IsCurrency` column dropped; rows with IsCurrency=1 are SKIPPED
--     (3.3.5 has no currency loot -- those "items" are currency ids, invalid here).
--   * reference_loot_template uses INSERT IGNORE + "not already present" so SHARED
--     stock references are never overwritten (avoids cross-zone loot bleed). Only
--     Deepholm-new reference entries are added. Nested references (a reference that
--     points to another reference) are resolved one level deep; re-run if a 2nd
--     level is reported missing.
--   * loot ids derive from the 307 non-shared Deepholm templates (the 6 shared
--     infra creatures keep their stock loot).
-- =====================================================================

-- ---------------------------------------------------------------------
-- creature_loot_template   (Entry = creature_template.lootid)
-- ---------------------------------------------------------------------
DELETE FROM `creature_loot_template` WHERE `Entry` IN (
  SELECT `lootid` FROM `cata_world`.`creature_template`
  WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646)
    AND `entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332) AND `lootid` > 0);

INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`
FROM `cata_world`.`creature_loot_template`
WHERE `IsCurrency` = 0 AND `Entry` IN (
  SELECT `lootid` FROM `cata_world`.`creature_template`
  WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646)
    AND `entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332) AND `lootid` > 0);

-- ---------------------------------------------------------------------
-- skinning_loot_template   (Entry = creature_template.skinloot)
-- ---------------------------------------------------------------------
DELETE FROM `skinning_loot_template` WHERE `Entry` IN (
  SELECT `skinloot` FROM `cata_world`.`creature_template`
  WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646)
    AND `entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332) AND `skinloot` > 0);

INSERT INTO `skinning_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`
FROM `cata_world`.`skinning_loot_template`
WHERE `IsCurrency` = 0 AND `Entry` IN (
  SELECT `skinloot` FROM `cata_world`.`creature_template`
  WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646)
    AND `entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332) AND `skinloot` > 0);

-- ---------------------------------------------------------------------
-- pickpocketing_loot_template   (Entry = creature_template.pickpocketloot)
-- ---------------------------------------------------------------------
DELETE FROM `pickpocketing_loot_template` WHERE `Entry` IN (
  SELECT `pickpocketloot` FROM `cata_world`.`creature_template`
  WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646)
    AND `entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332) AND `pickpocketloot` > 0);

INSERT INTO `pickpocketing_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`
FROM `cata_world`.`pickpocketing_loot_template`
WHERE `IsCurrency` = 0 AND `Entry` IN (
  SELECT `pickpocketloot` FROM `cata_world`.`creature_template`
  WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646)
    AND `entry` NOT IN (6491, 23837, 24110, 24288, 25670, 28332) AND `pickpocketloot` > 0);

-- ---------------------------------------------------------------------
-- gameobject_loot_template   (Entry = chest GO Data1; non-shared GOs)
-- ---------------------------------------------------------------------
DELETE FROM `gameobject_loot_template` WHERE `Entry` IN (
  SELECT `Data1` FROM `cata_world`.`gameobject_template`
  WHERE `type` = 3 AND `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`gameobject` WHERE `map` = 646)
    AND `entry` NOT IN (191707, 204968) AND `Data1` > 0);

INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`
FROM `cata_world`.`gameobject_loot_template`
WHERE `IsCurrency` = 0 AND `Entry` IN (
  SELECT `Data1` FROM `cata_world`.`gameobject_template`
  WHERE `type` = 3 AND `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`gameobject` WHERE `map` = 646)
    AND `entry` NOT IN (191707, 204968) AND `Data1` > 0);

-- ---------------------------------------------------------------------
-- reference_loot_template   (only refs pulled by the above, not already stock)
-- INSERT IGNORE + NOT-IN-existing => never clobber shared stock references.
-- ---------------------------------------------------------------------
INSERT IGNORE INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT r.`Entry`, r.`Item`, r.`Reference`, r.`Chance`, r.`QuestRequired`, r.`LootMode`, r.`GroupId`, r.`MinCount`, r.`MaxCount`, r.`Comment`
FROM `cata_world`.`reference_loot_template` r
WHERE r.`IsCurrency` = 0
  AND r.`Entry` NOT IN (SELECT `Entry` FROM (SELECT DISTINCT `Entry` FROM `reference_loot_template`) ex)
  AND r.`Entry` IN (
    SELECT `Reference` FROM `cata_world`.`creature_loot_template` WHERE `Reference` > 0 AND `Entry` IN (
      SELECT `lootid` FROM `cata_world`.`creature_template` WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND `entry` NOT IN (6491,23837,24110,24288,25670,28332) AND `lootid` > 0)
    UNION
    SELECT `Reference` FROM `cata_world`.`skinning_loot_template` WHERE `Reference` > 0 AND `Entry` IN (
      SELECT `skinloot` FROM `cata_world`.`creature_template` WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND `entry` NOT IN (6491,23837,24110,24288,25670,28332) AND `skinloot` > 0)
    UNION
    SELECT `Reference` FROM `cata_world`.`gameobject_loot_template` WHERE `Reference` > 0 AND `Entry` IN (
      SELECT `Data1` FROM `cata_world`.`gameobject_template` WHERE `type` = 3 AND `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`gameobject` WHERE `map` = 646) AND `entry` NOT IN (191707,204968) AND `Data1` > 0)
  );
