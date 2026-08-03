-- ---------------------------------------------------------------------------
-- 232  Map 750 -- fork shared loot tables (lootid == entry invariant)
-- ---------------------------------------------------------------------------
-- Two lootid conventions coexist in the clone bands today:
--   * 170 templates own a fresh table at lootid = entry (the +3.6M id);
--   * 389 templates still point at the ORIGINAL pre-offset lootid (e.g. entry
--     3734248 -> lootid 34248), and 133 of those loot ids are SHARED with a
--     stock creature_template below 3.6M. Any loot edit through such an id
--     leaks onto unrelated stock/retail-clone mobs elsewhere in the world.
--
-- 235-239 mass-edit map-750 loot, so this file first makes
--     lootid == entry   (and skinloot == entry, pickpocketloot == entry)
-- an INVARIANT for every template in the clone bands: copy the source table's
-- rows under the entry's own id, then repoint the template. Stock tables are
-- left byte-identical -- only the map-750 clones stop referencing them.
--
-- Idempotent: after the first run the `lootid <> entry AND lootid < 3600000`
-- predicate matches nothing. The DELETE guards clear only rows this file
-- itself would (re)create. Apply against acore_world BEFORE 235-239.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) kill loot -> creature_loot_template
-- ---------------------------------------------------------------------------
DELETE clt FROM `creature_loot_template` clt
JOIN `creature_template` ct ON ct.`entry` = clt.`Entry`
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`lootid` <> 0 AND ct.`lootid` <> ct.`entry` AND ct.`lootid` < 3600000;

INSERT INTO `creature_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT ct.`entry`, src.`Item`, src.`Reference`, src.`Chance`, src.`QuestRequired`,
       src.`LootMode`, src.`GroupId`, src.`MinCount`, src.`MaxCount`,
       CONCAT('DC750 fork of loot ', ct.`lootid`)
FROM `creature_template` ct
JOIN `creature_loot_template` src ON src.`Entry` = ct.`lootid`
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`lootid` <> 0 AND ct.`lootid` <> ct.`entry` AND ct.`lootid` < 3600000;

UPDATE `creature_template`
SET `lootid` = `entry`
WHERE `entry` BETWEEN 3600000 AND 3799999
  AND `lootid` <> 0 AND `lootid` <> `entry` AND `lootid` < 3600000;

-- ---------------------------------------------------------------------------
-- B) skinning loot -> skinning_loot_template
-- ---------------------------------------------------------------------------
DELETE slt FROM `skinning_loot_template` slt
JOIN `creature_template` ct ON ct.`entry` = slt.`Entry`
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`skinloot` <> 0 AND ct.`skinloot` <> ct.`entry` AND ct.`skinloot` < 3600000;

INSERT INTO `skinning_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT ct.`entry`, src.`Item`, src.`Reference`, src.`Chance`, src.`QuestRequired`,
       src.`LootMode`, src.`GroupId`, src.`MinCount`, src.`MaxCount`,
       CONCAT('DC750 fork of skinloot ', ct.`skinloot`)
FROM `creature_template` ct
JOIN `skinning_loot_template` src ON src.`Entry` = ct.`skinloot`
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`skinloot` <> 0 AND ct.`skinloot` <> ct.`entry` AND ct.`skinloot` < 3600000;

UPDATE `creature_template`
SET `skinloot` = `entry`
WHERE `entry` BETWEEN 3600000 AND 3799999
  AND `skinloot` <> 0 AND `skinloot` <> `entry` AND `skinloot` < 3600000;

-- ---------------------------------------------------------------------------
-- C) pickpocket loot -> pickpocketing_loot_template
-- ---------------------------------------------------------------------------
DELETE plt FROM `pickpocketing_loot_template` plt
JOIN `creature_template` ct ON ct.`entry` = plt.`Entry`
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`pickpocketloot` <> 0 AND ct.`pickpocketloot` <> ct.`entry` AND ct.`pickpocketloot` < 3600000;

INSERT INTO `pickpocketing_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT ct.`entry`, src.`Item`, src.`Reference`, src.`Chance`, src.`QuestRequired`,
       src.`LootMode`, src.`GroupId`, src.`MinCount`, src.`MaxCount`,
       CONCAT('DC750 fork of pickpocketloot ', ct.`pickpocketloot`)
FROM `creature_template` ct
JOIN `pickpocketing_loot_template` src ON src.`Entry` = ct.`pickpocketloot`
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`pickpocketloot` <> 0 AND ct.`pickpocketloot` <> ct.`entry` AND ct.`pickpocketloot` < 3600000;

UPDATE `creature_template`
SET `pickpocketloot` = `entry`
WHERE `entry` BETWEEN 3600000 AND 3799999
  AND `pickpocketloot` <> 0 AND `pickpocketloot` <> `entry` AND `pickpocketloot` < 3600000;

-- ---------------------------------------------------------------------------
-- Trailer -- verification (all three counts must be 0 after apply; stock
-- tables must be unchanged -- spot-check one previously shared id, e.g. 34248)
-- ---------------------------------------------------------------------------
-- SELECT COUNT(*) FROM creature_template WHERE entry BETWEEN 3600000 AND 3799999
--   AND lootid <> 0 AND lootid <> entry AND lootid < 3600000;
-- SELECT COUNT(*) FROM creature_template WHERE entry BETWEEN 3600000 AND 3799999
--   AND skinloot <> 0 AND skinloot <> entry AND skinloot < 3600000;
-- SELECT COUNT(*) FROM creature_template WHERE entry BETWEEN 3600000 AND 3799999
--   AND pickpocketloot <> 0 AND pickpocketloot <> entry AND pickpocketloot < 3600000;
-- SELECT COUNT(*) FROM creature_loot_template WHERE Entry = 34248;   -- unchanged
