-- Castle Nathria (map 2296) -- loot supplement from the all-source audit (23).
--
-- The 2026-07-21 loot sweep (SLDB base + shadowcore updates + Rem999 world09 + official TC 9.2.7
-- TDB) confirmed live coverage matches or exceeds every source EXCEPT two gaps whose items exist
-- in live item_template:
--
-- 1. 183016 "Load-Bearing Belt" -- a downported gear item that currently drops NOWHERE. In the
--    sources only the duplicate RP-Sludgefist entry (174733, the entrance story spawn) looted it,
--    alongside the same 7 gear items the real boss (164407) already drops. The RP prop deliberately
--    keeps NO loot table (it is pre-fight flavor; giving it the boss pool would double-drop the
--    raid) -- the belt is added to the REAL Sludgefist's group-1 pool instead, at the same weight
--    as its peers.
-- 2. Lady Sinsear (174161, Denathrius nightcloak court, C++-summoned; template added by
--    19_summoned_adds.sql with lootid=0): Rem999+SLDB give her 2 cloth drops whose items exist
--    live (173202 Shrouded Cloth, 173204 Lightless Silk) -- lootid pointed at her entry + rows
--    transcoded with source chances.
--
-- Not ported (documented for completeness): skinning_loot_template 173798 "Rat of Unusual Size"
-- (5 SL leather/bone trade goods, none in live item_template -- needs an item downport batch
-- first); all other source-only loot references deliberately-excluded borrowed-power/token items.
--
-- Apply against acore_world. Run AFTER 19_summoned_adds.sql (updates its 174161 row).

DELETE FROM `creature_loot_template` WHERE `Entry` = 164407 AND `Item` = 183016;
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (164407, 183016, 0, 14, 0, 1, 1, 1, 1, 'Load-Bearing Belt');

UPDATE `creature_template` SET `lootid` = 174161 WHERE `entry` = 174161;

DELETE FROM `creature_loot_template` WHERE `Entry` = 174161;
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (174161, 173202, 0, 80, 0, 1, 0, 1, 2, 'Shrouded Cloth'),
    (174161, 173204, 0, 20, 0, 1, 0, 1, 1, 'Lightless Silk');
