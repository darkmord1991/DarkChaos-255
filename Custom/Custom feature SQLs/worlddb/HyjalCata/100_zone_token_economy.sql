-- =====================================================================
-- Mount Hyjal (750) + Molten Front (861) -- 100  Emberwood Sap token economy
-- ---------------------------------------------------------------------
-- The zone's long-term "earn" hook: killing zone mobs drops Emberwood Sap
-- (item 400000, already live), spent at the sap vendor via itemextendedcost
-- 14100-14103 (already live). This adds the DROP side onto the authentic Cata
-- mobs (weighted by rank), and stocks the Hyjal Frontier Tabard (400908) on a
-- 750 vendor.
--
-- Drop chance by rank: normal 8% x1, elite 22% x1-2, rare 60% x1-3, boss 100% x2-4.
-- Self-deriving: every map-750 / map-861 creature that already has a loot table
-- (lootid>0) gets the token line. GroupId 0 = independent roll (does not compete
-- with gear drops). Idempotent (deletes the 400000 line first).
-- =====================================================================

-- token drop onto every lootful Hyjal/MF creature, chance/count scaled by rank
DELETE lt FROM acore_world.creature_loot_template lt
JOIN acore_world.creature_template ct ON ct.lootid=lt.Entry
WHERE lt.Item=400000 AND ct.entry IN (
  SELECT DISTINCT id FROM acore_world.creature WHERE map IN (750,861));

INSERT IGNORE INTO acore_world.creature_loot_template (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT DISTINCT ct.lootid, 400000, 0,
  CASE ct.rank WHEN 1 THEN 22 WHEN 2 THEN 60 WHEN 3 THEN 100 WHEN 4 THEN 60 ELSE 8 END,
  0, 1, 0, 1,
  CASE ct.rank WHEN 1 THEN 2 WHEN 2 THEN 3 WHEN 3 THEN 4 WHEN 4 THEN 3 ELSE 1 END
FROM acore_world.creature_template ct
WHERE ct.lootid>0
  AND ct.entry IN (SELECT DISTINCT id FROM acore_world.creature WHERE map IN (750,861))
  -- only real hostile fightables: skip friendly/critter families via type (7=critter)
  AND ct.type <> 7;

-- ---------------------------------------------------------------------
-- Tabard: stock the Hyjal Frontier Tabard (400908, created by the Hyjal set's
-- 07b) on the authentic Tabard/quartermaster vendor. Provisioner Whitecloud
-- 3650314 (Guardians of Hyjal Quartermaster) is the natural home.
-- ---------------------------------------------------------------------
DELETE FROM acore_world.npc_vendor WHERE entry=3650314 AND item=400908;
INSERT IGNORE INTO acore_world.npc_vendor (`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
SELECT 3650314, 0, 400908, 0, 0, 0, 0
WHERE EXISTS (SELECT 1 FROM acore_world.item_template WHERE entry=400908)
  AND EXISTS (SELECT 1 FROM acore_world.creature_template WHERE entry=3650314);

-- ---------------------------------------------------------------------
-- SPEND side (already live, no-op reminder): item 400000 + itemextendedcost
-- 14100-14103 exist. The sap "gear page" (items 400001-400010 from the Hyjal
-- set's 07) can be stocked on the same quartermaster 3650314 with ExtendedCost
-- 14100/14101 once those items are confirmed present -- add here if desired.
-- ---------------------------------------------------------------------
