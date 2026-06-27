-- =====================================================================
-- Deepholm Downport  --  10  Conditions  (Cata map 646)
-- ---------------------------------------------------------------------
-- Source: cata_world (TrinityCore 4.3.4).  Target: acore_world.
-- REQUIRES cata_world present on the same server at import time (read-only).
-- Run AFTER 08 (loot) + 09 (gossip) -- conditions gate those rows.
--
-- The `conditions` schema is IDENTICAL Cata<->this fork, so this is a straight
-- copy. The ONLY trick is scoping: conditions must be matched by the EXACT keys
-- of the content we imported, NOT by a blanket SourceEntry match (a naive match
-- catches unrelated spell/item conditions whose SourceEntry id coincides with a
-- Deepholm creature id). Verified: Deepholm has no spellclick/vehicle conditions,
-- so only LOOT conditions (keyed by loot id) and GOSSIP conditions (keyed by menu)
-- apply:
--   type 1  creature loot      SourceGroup = creature lootid
--   type 4  gameobject loot     SourceGroup = GO chest loot id
--   type 8  pickpocketing       SourceGroup = pickpocketloot id
--   type 10 reference loot      SourceGroup = reference id (the ones 08 imports)
--   type 11 skinning            SourceGroup = skinloot id
--   type 14/15 gossip menu/opt  SourceGroup = Deepholm menu (excl. stock 83/9821)
-- =====================================================================

-- Reusable scope as a single predicate (used by DELETE and INSERT identically).
DELETE FROM `conditions` WHERE
 (`SourceTypeOrReferenceId` = 1  AND `SourceGroup` IN (SELECT `lootid` FROM `cata_world`.`creature_template` WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map`=646) AND `entry` NOT IN (6491,23837,24110,24288,25670,28332) AND `lootid`>0))
 OR (`SourceTypeOrReferenceId` = 11 AND `SourceGroup` IN (SELECT `skinloot` FROM `cata_world`.`creature_template` WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map`=646) AND `entry` NOT IN (6491,23837,24110,24288,25670,28332) AND `skinloot`>0))
 OR (`SourceTypeOrReferenceId` = 8  AND `SourceGroup` IN (SELECT `pickpocketloot` FROM `cata_world`.`creature_template` WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map`=646) AND `entry` NOT IN (6491,23837,24110,24288,25670,28332) AND `pickpocketloot`>0))
 OR (`SourceTypeOrReferenceId` = 4  AND `SourceGroup` IN (SELECT `Data1` FROM `cata_world`.`gameobject_template` WHERE `type`=3 AND `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`gameobject` WHERE `map`=646) AND `entry` NOT IN (191707,204968) AND `Data1`>0))
 OR (`SourceTypeOrReferenceId` = 10 AND `SourceGroup` IN (
        SELECT `Reference` FROM `cata_world`.`creature_loot_template` WHERE `Reference`>0 AND `Entry` IN (SELECT `lootid` FROM `cata_world`.`creature_template` WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map`=646) AND `entry` NOT IN (6491,23837,24110,24288,25670,28332) AND `lootid`>0)
        UNION SELECT `Reference` FROM `cata_world`.`gameobject_loot_template` WHERE `Reference`>0 AND `Entry` IN (SELECT `Data1` FROM `cata_world`.`gameobject_template` WHERE `type`=3 AND `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`gameobject` WHERE `map`=646) AND `entry` NOT IN (191707,204968) AND `Data1`>0)))
 OR (`SourceTypeOrReferenceId` IN (14,15) AND `SourceGroup` IN (SELECT DISTINCT `gossip_menu_id` FROM `cata_world`.`creature_template` WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map`=646) AND `gossip_menu_id`>0) AND `SourceGroup` NOT IN (83,9821));

INSERT INTO `conditions`
(`SourceTypeOrReferenceId`,`SourceGroup`,`SourceEntry`,`SourceId`,`ElseGroup`,`ConditionTypeOrReference`,`ConditionTarget`,`ConditionValue1`,`ConditionValue2`,`ConditionValue3`,`NegativeCondition`,`ErrorType`,`ErrorTextId`,`ScriptName`,`Comment`)
SELECT c.`SourceTypeOrReferenceId`,c.`SourceGroup`,c.`SourceEntry`,c.`SourceId`,c.`ElseGroup`,c.`ConditionTypeOrReference`,c.`ConditionTarget`,c.`ConditionValue1`,c.`ConditionValue2`,c.`ConditionValue3`,c.`NegativeCondition`,c.`ErrorType`,c.`ErrorTextId`,c.`ScriptName`,c.`Comment`
FROM `cata_world`.`conditions` c
WHERE
 (c.`SourceTypeOrReferenceId` = 1  AND c.`SourceGroup` IN (SELECT `lootid` FROM `cata_world`.`creature_template` WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map`=646) AND `entry` NOT IN (6491,23837,24110,24288,25670,28332) AND `lootid`>0))
 OR (c.`SourceTypeOrReferenceId` = 11 AND c.`SourceGroup` IN (SELECT `skinloot` FROM `cata_world`.`creature_template` WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map`=646) AND `entry` NOT IN (6491,23837,24110,24288,25670,28332) AND `skinloot`>0))
 OR (c.`SourceTypeOrReferenceId` = 8  AND c.`SourceGroup` IN (SELECT `pickpocketloot` FROM `cata_world`.`creature_template` WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map`=646) AND `entry` NOT IN (6491,23837,24110,24288,25670,28332) AND `pickpocketloot`>0))
 OR (c.`SourceTypeOrReferenceId` = 4  AND c.`SourceGroup` IN (SELECT `Data1` FROM `cata_world`.`gameobject_template` WHERE `type`=3 AND `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`gameobject` WHERE `map`=646) AND `entry` NOT IN (191707,204968) AND `Data1`>0))
 OR (c.`SourceTypeOrReferenceId` = 10 AND c.`SourceGroup` IN (
        SELECT `Reference` FROM `cata_world`.`creature_loot_template` WHERE `Reference`>0 AND `Entry` IN (SELECT `lootid` FROM `cata_world`.`creature_template` WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map`=646) AND `entry` NOT IN (6491,23837,24110,24288,25670,28332) AND `lootid`>0)
        UNION SELECT `Reference` FROM `cata_world`.`gameobject_loot_template` WHERE `Reference`>0 AND `Entry` IN (SELECT `Data1` FROM `cata_world`.`gameobject_template` WHERE `type`=3 AND `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`gameobject` WHERE `map`=646) AND `entry` NOT IN (191707,204968) AND `Data1`>0)))
 OR (c.`SourceTypeOrReferenceId` IN (14,15) AND c.`SourceGroup` IN (SELECT DISTINCT `gossip_menu_id` FROM `cata_world`.`creature_template` WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map`=646) AND `gossip_menu_id`>0) AND c.`SourceGroup` NOT IN (83,9821));
