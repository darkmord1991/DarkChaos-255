-- =====================================================================
-- Deepholm Downport  --  35  Missing creature_loot_template rows
-- ---------------------------------------------------------------------
-- Two creature_template entries reference loot tables that were not
-- imported by 08_loot.sql (both were absent from or filtered out of
-- the cata_world source at import time):
--
--   42188  Ozruk   (Stonecore boss; template used on map 646 too)
--          5 items in GroupId=1 (boss random-pick: one item drops per
--          kill from the group).  Items: 55802-55804, 55810-55811.
--
--   50060  Terborus  (Deepholm rare elite; spawned by 20/30)
--          1 item: 67238 Terborus's Bladed Spine, 100% drop.
--
-- All item_template rows confirmed present.  Loot schema unchanged from
-- stock AC (Entry/Item/Reference/Chance/QuestRequired/LootMode/GroupId/
-- MinCount/MaxCount/Comment).
-- =====================================================================

DELETE FROM `creature_loot_template` WHERE `Entry` IN (42188, 50060);

INSERT INTO `creature_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
VALUES
-- Ozruk (Stonecore): boss table — one random item from group 1 per kill
(42188, 55802, 0, 0, 0, 1, 1, 1, 1, 'Ozruk - Gloves of the Painless Midnight'),
(42188, 55803, 0, 0, 0, 1, 1, 1, 1, 'Ozruk - Petrified Fungal Heart'),
(42188, 55804, 0, 0, 0, 1, 1, 1, 1, 'Ozruk - Spaulders of the Ruined City'),
(42188, 55810, 0, 0, 0, 1, 1, 1, 1, 'Ozruk - Crossfire Carbine'),
(42188, 55811, 0, 0, 0, 1, 1, 1, 1, 'Ozruk - Alpha Bracers'),
-- Terborus (Deepholm rare elite): guaranteed drop
(50060, 67238, 0, 100, 0, 1, 0, 1, 1, 'Terborus - Terborus''s Bladed Spine');
