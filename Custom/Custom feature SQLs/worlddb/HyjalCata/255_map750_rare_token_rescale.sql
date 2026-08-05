-- ---------------------------------------------------------------------------
-- 255  Map 750 -- make rare/boss Upgrade Token drops worth the kill
-- ---------------------------------------------------------------------------
-- 244_ already put tokens on every rare and boss (rank >= 2), so coverage was
-- never the gap -- audited 2026-08-04 and all 42 rank-2/3/4 templates on the
-- map have a loot table, none are skipped by the `lootid = entry` invariant.
--
-- The gap is the AMOUNT. 244_ predates the quest economy: it gives a named
-- rare 1-3 tokens and a rare-elite a 35% shot at ONE, while 253_ now pays
-- 20-75 tokens for a single quest turn-in. Killing a rare you may see once an
-- hour should not be worth a twentieth of handing in a kill-ten-boars quest.
--
-- This supersedes 244_'s section 2 (identical DELETE scope, runs after it) and
-- re-prices rares against the same per-zone band scale the quests use, so a
-- rare is worth roughly one to two quests and a boss two to three:
--
--     zone / band              base   rank 2 (rare elite)  rank 3 (boss)  rank 4 (named rare)
--     4929 Darkshore  80-90      20        10-20              40-60           20-40
--     4930 Azshara    80-90      20        10-20              40-60           20-40
--     4931 Ashenvale  88-98      30        15-30              60-90           30-60
--     4927 Felwood    96-106     40        20-40              80-120          40-80
--     4928 Moonglade  --         40        20-40              80-120          40-80
--     4926 Winterspr. 104-115    55        27-55             110-165          55-110
--     4923 Hyjal      113-130    75        37-75             150-225          75-150
--
-- Live template counts by zone (rank2/rank3/rank4): Hyjal 1/0/5,
-- Winterspring 3/0/3, Felwood 2/0/5, Darkshore 0/0/8, Azshara 1/0/6,
-- Ashenvale 0/1/7, Moonglade none -- 42 in total, so this is a small curated
-- set, not a firehose.
--
-- Chance is 100% at every rank, deliberately: 244_'s 35% roll on a mob with a
-- long respawn and a shared pool means most players who find one still walk
-- away with nothing. Rarity is already enforced by the spawn, not the roll.
--
-- ELITES (rank 1) ARE DELIBERATELY EXCLUDED, as in 244_ -- there are hundreds
-- of them and they respawn freely, so tokens there would be farmable and drown
-- the whole economy. Quests + rares + the ladder drops are the intended taps.
--
-- CAP: `MinCount`/`MaxCount` are `tinyint unsigned` -- 255 is the ceiling.
-- The largest value here is 225 (Hyjal rank 3), so retuning upward has very
-- little headroom; scale the band bases down rather than past 255.
--
-- Run AFTER 232_ (lootid = entry invariant), 231_ (dc_map750_entryzone) and
-- 244_. Idempotent. Restart or `.reload creature_loot_template`.
-- ---------------------------------------------------------------------------

DELETE FROM `creature_loot_template`
WHERE `Item` = 300311 AND `Reference` = 0
  AND `Entry` BETWEEN 3600000 AND 3799999;

INSERT INTO `creature_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT r.`lootid`, 300311, 0, 100, 0, 1, 0,
       CASE r.`rank` WHEN 2 THEN GREATEST(1, FLOOR(r.`base` / 2))
                     WHEN 3 THEN r.`base` * 2
                     ELSE r.`base` END,
       CASE r.`rank` WHEN 2 THEN r.`base`
                     WHEN 3 THEN r.`base` * 3
                     ELSE r.`base` * 2 END,
       'DC750 Upgrade Token - rare/boss'
FROM (
    SELECT DISTINCT ct.`lootid`, ct.`rank`,
           CASE ez.`zone` WHEN 4929 THEN 20 WHEN 4930 THEN 20 WHEN 4931 THEN 30
                          WHEN 4927 THEN 40 WHEN 4928 THEN 40 WHEN 4926 THEN 55
                          WHEN 4923 THEN 75 ELSE 20 END AS `base`
    FROM `creature_template` ct
    JOIN `dc_map750_entryzone` ez ON ez.`entry` = ct.`entry`
    WHERE ct.`entry` BETWEEN 3600000 AND 3799999
      AND ct.`lootid` = ct.`entry`
      AND ct.`rank` >= 2
      AND ct.`type` NOT IN (8, 10)
      AND ct.`npcflag` = 0
) r;

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- payout per zone and rank (expect the table in the header, 42 rows total):
-- SELECT ez.zone, ct.`rank`, COUNT(*) mobs, MIN(clt.MinCount) mn, MAX(clt.MaxCount) mx
-- FROM creature_loot_template clt
-- JOIN creature_template ct ON ct.lootid = clt.Entry
-- JOIN dc_map750_entryzone ez ON ez.entry = ct.entry
-- WHERE clt.Item = 300311 AND clt.Reference = 0
-- GROUP BY ez.zone, ct.`rank` ORDER BY ez.zone, ct.`rank`;
-- nothing overflowed the tinyint (expect 0):
-- SELECT COUNT(*) FROM creature_loot_template
-- WHERE Item = 300311 AND (MinCount > 255 OR MaxCount > 255 OR MinCount > MaxCount);
-- no elite (rank 1) picked up a token by accident (expect 0):
-- SELECT COUNT(*) FROM creature_loot_template clt
-- JOIN creature_template ct ON ct.lootid = clt.Entry
-- WHERE clt.Item = 300311 AND ct.`rank` < 2;
-- In-game: kill a Hyjal named rare (e.g. Cindermaul 3640844) -- 75-150 tokens
-- in the loot window, and they land in Character -> Currency, not the bags.
