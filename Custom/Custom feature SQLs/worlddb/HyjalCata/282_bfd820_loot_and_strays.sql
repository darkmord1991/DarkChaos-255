-- ---------------------------------------------------------------------------
-- 282  Blackfathom Deeps clone (map 820) pickpocket + skinning, and 3 strays
-- ---------------------------------------------------------------------------
-- Maps 750/861 are clean on the boot log after 280_/281_, so this round takes
-- the blocks previously ruled out of scope. The big one is the **map-820
-- Blackfathom Deeps clone**, whose entries are stock BFD ids + 3,900,000
-- (3904798 -> 4798), and it splits into two DIFFERENT bugs that the log
-- reports with the same wording.
--
-- Convention established before touching anything: the map-820 build
-- **offset-clones** its per-creature loot -- 31 of 31 clones have
-- `lootid = entry` and none points at a raw id -- and it CUSTOMISES some
-- (Lady Sarevess's clone has 12 rows where raw 4831 has 10). So per-creature
-- tables get cloned at the offset here, matching that.

-- ---- 1. 18 pickpocket tables never cloned (155 spawns) ----------------------
--     Table 'pickpocketing_loot_template' Entry 3904798 does not exist but it
--     is used by Creature 3904798
--
-- The importer set `pickpocketloot = entry` on all 18 but never copied the
-- tables, so pickpocketing every humanoid in the instance has silently done
-- nothing. The raw stock tables all exist (64 rows across 18), and the clone
-- targets are empty (0 rows), so this is a clean copy.
--
-- Validated before writing: 0 of the 64 rows reference a missing item and 0
-- reference a missing `reference_loot_template` -- with the Reference = 0
-- condition on the item check, which `LootStoreItem::IsValid` also applies.
DELETE FROM acore_world.`pickpocketing_loot_template`
WHERE `Entry` IN (3904798,3904799,3904805,3904807,3904809,3904810,3904811,3904812,3904813,3904814,3904815,3904818,3904819,3904820,3904831,3904832,3906243,3912902);

INSERT INTO acore_world.`pickpocketing_loot_template`
(`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT p.`Entry` + 3900000, p.`Item`, p.`Reference`, p.`Chance`, p.`QuestRequired`,
       p.`LootMode`, p.`GroupId`, p.`MinCount`, p.`MaxCount`, p.`Comment`
FROM acore_world.`pickpocketing_loot_template` p
WHERE p.`Entry` IN (4798,4799,4805,4807,4809,4810,4811,4812,4813,4814,4815,4818,4819,4820,4831,4832,6243,12902);

-- ---- 2. skinloot: the offset was applied to SHARED tables -------------------
--     Table 'skinning_loot_template' Entry 4000007 does not exist but it is
--     used by Creature 3904824
--
-- 🔴 A DIFFERENT BUG WEARING THE SAME MESSAGE. These five do not want a cloned
-- table at all. The raw BFD creatures use skinloot **100007** and **100012** --
-- stock SHARED skinning tables (100007 has 12 users, 100012 has 5) -- and the
-- importer's blanket +3,900,000 turned them into 4000007 / 4000012, which have
-- never existed. Cloning a shared table per map would be wrong; the offset just
-- has to come off. Exactly the class 271_ hit with KillCredit: **the blanket
-- offset is wrong whenever the target is a shared or raw id.**
UPDATE acore_world.`creature_template` SET `skinloot` = 100007
WHERE `entry` IN (3904824,3904827,3904887) AND `skinloot` = 4000007;

UPDATE acore_world.`creature_template` SET `skinloot` = 100012
WHERE `entry` IN (3904825,3904829) AND `skinloot` = 4000012;

-- Old Serra'kis is the opposite case: a genuine PER-CREATURE table (raw 4830,
-- 2 rows) that simply was not cloned. Cloned at the offset, per the convention.
DELETE FROM acore_world.`skinning_loot_template` WHERE `Entry` = 3904830;
INSERT INTO acore_world.`skinning_loot_template`
(`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT s.`Entry` + 3900000, s.`Item`, s.`Reference`, s.`Chance`, s.`QuestRequired`,
       s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, s.`Comment`
FROM acore_world.`skinning_loot_template` s WHERE s.`Entry` = 4830;

-- ---- 3. Deepholm's Albino Cavefish School (24 spawns) ----------------------
--     Table 'gameobject_loot_template' Entry 28559 does not exist but it is
--     used by Gameobject 202778
--
-- The only broken fishing hole of the 64 type-25 GOs in the DB, and it has
-- **24 spawns on map 646** -- fishing them has been yielding nothing. Resolves
-- in cata_world (4 rows). Note cata's loot tables carry an extra `IsCurrency`
-- column, so the copy names columns explicitly on both sides.
DELETE FROM acore_world.`gameobject_loot_template` WHERE `Entry` = 28559;
INSERT INTO acore_world.`gameobject_loot_template`
(`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT g.`Entry`, g.`Item`, g.`Reference`, g.`Chance`, g.`QuestRequired`,
       g.`LootMode`, g.`GroupId`, g.`MinCount`, g.`MaxCount`, g.`Comment`
FROM cata_world.`gameobject_loot_template` g WHERE g.`Entry` = 28559;

-- ---- 4. three strays with no source anywhere -------------------------------
-- Cleared rather than invented, each after checking both source DBs.
--
--   173798 "Rat of Unusual Size" (map 2296, 4 spawns) -- the ONLY map-2296
--     creature with a skinloot at all, and its table exists in no source. Same
--     call CastleNathria/27_ made for 64 dead lootids: clear the field rather
--     than fabricate loot. A skinnable rat was doubtful anyway.
--   357751 "Spoils of Sin" -- chest whose lootid is its own entry, no source,
--     and **0 spawns**, so nothing is lost.
UPDATE acore_world.`creature_template` SET `skinloot` = 0
WHERE `entry` = 173798 AND `skinloot` = 173798;

UPDATE acore_world.`gameobject_template` SET `data1` = 0
WHERE `entry` = 357751 AND `type` = 3 AND `data1` = 357751;

-- Legion Dalaran gossip: OptionBroadcastTextID 123314 / 123321 exist in neither
-- acore nor cata (Legion-era ids). The core already ignores them and falls back
-- to `OptionText`, which is populated on both rows ("The Underbelly",
-- "Chamber of the Guardian") -- so this is cosmetic only and the options keep
-- working exactly as they do today.
UPDATE acore_world.`gossip_menu_option` SET `OptionBroadcastTextID` = 0
WHERE `OptionBroadcastTextID` IN (123314,123321);

-- Verify after apply:
--   SELECT COUNT(*) FROM pickpocketing_loot_template WHERE Entry BETWEEN
--     3900000 AND 3999999;                                              -> 64
--   SELECT COUNT(*) FROM creature_template WHERE skinloot IN (4000007,4000012);
--                                                                       -> 0
--   SELECT COUNT(*) FROM skinning_loot_template WHERE Entry=3904830;    -> 2
--   SELECT COUNT(*) FROM gameobject_loot_template WHERE Entry=28559;    -> 4
--   -- and the whole-DB sweep both classes came from:
--   SELECT COUNT(*) FROM creature_template ct WHERE
--     (ct.pickpocketloot>0 AND NOT EXISTS (SELECT 1 FROM pickpocketing_loot_template p
--        WHERE p.Entry=ct.pickpocketloot))
--     OR (ct.skinloot>0 AND NOT EXISTS (SELECT 1 FROM skinning_loot_template s
--        WHERE s.Entry=ct.skinloot));                                   -> 0
-- In game: BFD-820's humanoids can be pickpocketed (155 spawns), its beasts
-- skinned, and Deepholm's 24 cavefish schools finally yield fish.
