-- ---------------------------------------------------------------------------
-- 191  Hyjal round-45 -- creature equipment + chest loot the imports missed
-- ---------------------------------------------------------------------------
-- Two gaps the post-restart Errors.log surfaced, both from the same cause: the
-- spawn imports carried the SPAWN-side fields (equipment_id, the chest's lootId)
-- but never cloned the tables those fields point INTO.
--
-- 1. EQUIPMENT -- 832 spawns across 116 entries carry equipment_id > 0 with no
--    matching creature_equip_template row, so the core logs
--      "creature (Entry: N) with equipment_id 1 not found ... set to no equipment"
--    and the NPC stands there unarmed.  Guards, sentinels and questgivers all
--    lose their weapons.  112 of the 116 have the row in cata_world.
--
--    Schemas verified IDENTICAL on both sides (CreatureID, ID, ItemID1..3,
--    VerifiedBuild), so this is a straight column-named copy -- but each ItemID
--    is still checked against our item_template and zeroed if absent, because a
--    dangling weapon reference renders an empty hand rather than nothing at all.
--
-- 2. CHEST LOOT -- 37 chest gameobjects on map 750 name a lootId with no rows
--    behind it, i.e. they open empty.  cata_world has 82 rows for them; 66
--    survive the item filter and 16 are dropped for items we do not have.
--
-- Both scoped strictly to entries actually spawned on map 750.
-- ---------------------------------------------------------------------------

-- --- 1. equipment ----------------------------------------------------------
DELETE FROM `creature_equip_template` WHERE `CreatureID` IN (
  SELECT e FROM (SELECT DISTINCT c.`id` AS e FROM `creature` c
                 WHERE c.`map` = 750 AND c.`equipment_id` > 0) x);

INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`)
SELECT DISTINCT t.`entry`, ce.`ID`,
       IF(ce.`ItemID1` > 0 AND ce.`ItemID1` NOT IN (SELECT `entry` FROM acore_world.item_template), 0, ce.`ItemID1`),
       IF(ce.`ItemID2` > 0 AND ce.`ItemID2` NOT IN (SELECT `entry` FROM acore_world.item_template), 0, ce.`ItemID2`),
       IF(ce.`ItemID3` > 0 AND ce.`ItemID3` NOT IN (SELECT `entry` FROM acore_world.item_template), 0, ce.`ItemID3`),
       0
FROM cata_world.creature_equip_template ce
JOIN acore_world.creature_template t
  ON ce.`CreatureID` IN (CAST(t.`entry` AS SIGNED) - 3600000, CAST(t.`entry` AS SIGNED) - 3700000)
JOIN acore_world.creature c ON c.`id` = t.`entry` AND c.`map` = 750 AND c.`equipment_id` > 0;

-- --- 2. chest loot ---------------------------------------------------------
DELETE FROM `gameobject_loot_template` WHERE `Entry` IN (
  SELECT d FROM (SELECT DISTINCT t.`Data1` AS d FROM `gameobject` g
                 JOIN `gameobject_template` t ON t.`entry` = g.`id`
                 WHERE g.`map` = 750 AND t.`type` = 3 AND t.`Data1` > 0) x
  WHERE d IN (SELECT `Entry` FROM cata_world.gameobject_loot_template));

INSERT INTO `gameobject_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT cl.`Entry`, cl.`Item`, cl.`Reference`, cl.`Chance`, cl.`QuestRequired`,
       cl.`LootMode`, cl.`GroupId`, cl.`MinCount`, cl.`MaxCount`, NULL
FROM cata_world.gameobject_loot_template cl
WHERE cl.`Entry` IN (SELECT DISTINCT t.`Data1` FROM acore_world.gameobject g
                     JOIN acore_world.gameobject_template t ON t.`entry` = g.`id`
                     WHERE g.`map` = 750 AND t.`type` = 3 AND t.`Data1` > 0)
  AND cl.`Item` IN (SELECT `entry` FROM acore_world.item_template);

-- Verify -- both should read 0:
--   SELECT COUNT(*) FROM `creature` c WHERE c.map = 750 AND c.equipment_id > 0
--     AND NOT EXISTS (SELECT 1 FROM `creature_equip_template` e
--                     WHERE e.CreatureID = c.id AND e.ID = c.equipment_id);
--   SELECT COUNT(DISTINCT t.entry) FROM `gameobject` g
--     JOIN `gameobject_template` t ON t.entry = g.id
--    WHERE g.map = 750 AND t.type = 3 AND t.Data1 > 0
--      AND NOT EXISTS (SELECT 1 FROM `gameobject_loot_template` l WHERE l.Entry = t.Data1);
