-- ---------------------------------------------------------------------------
-- 334  Finish the token -> sap swap on map 750
-- ---------------------------------------------------------------------------
-- 326_ was described as swapping map-750 rewards to Emberwood Sap. It did not
-- swap anything -- it ADDED a sap reward and left the DC Item Upgrade Token
-- reward in place. Measured on the live DB:
--
--   quests giving BOTH sap and token .......... 545
--   quests giving ONLY the token .............. 8
--   quests giving ONLY sap .................... 0
--
--   total Upgrade Tokens payable from map-750 quests .... 25,110
--   total Emberwood Sap payable from the same quests .... 2,891
--
-- 🔴 25,110 tokens is not a rounding error. The level-80 quartermaster charges
-- 11-15 tokens per item, so map-750 questing alone funds roughly 1,800 pieces of
-- level-80 gear -- in a currency that is supposed to come from the weekly Great
-- Vault. The whole Mythic+ loop is bypassed by levelling through Hyjal.
--
-- The drops are worse: 42 map-750 rares and world bosses drop the token at
-- **100% chance, 10-150 per kill** (Thartuk, Blazewing, Terrorpene, Ankha and
-- Ban'thalos are 75-150 each). At 15 tokens per item that is ~10 level-80 items
-- from a single rare kill.
--
-- ---------------------------------------------------------------------------
-- 🔴 THE TRAP THAT MAKES THIS NOT A ONE-LINE UPDATE
-- ---------------------------------------------------------------------------
-- `creature_loot_template` is keyed on (Entry, Item), and **all 42** of those
-- creatures ALREADY carry a sap row. So the obvious
--
--     UPDATE creature_loot_template SET Item = 400000 WHERE Item = 300311
--
-- fails with a duplicate-key error on every single row. The token row has to be
-- merged into the sap row and then deleted, in that order.
--
-- And the merge cannot just delete the token row either, because the sap row
-- those rares carry is the GENERIC ZONE TRASH one 326_ gave every mob:
--
--     Ban'thalos  (level 129 rare)   token 75-150 @100%   sap 1-2 @15%
--     Garr        (level 130 rare elite) token 37-75 @100%   sap 1-2 @15%
--     Rak'shiri   (level 116 rare)   token 55-110 @100%   sap 1-1 @12%
--
-- Deleting the token row alone would leave a level-129 rare dropping 1-2 sap at
-- 15% -- i.e. usually nothing. 326_ never gave the rares a rare-sized sap
-- reward; it only ever gave them the trash one.
--
-- ---------------------------------------------------------------------------
-- CONVERSION RATE: HALF THE TOKEN COUNT, AT 100%
-- ---------------------------------------------------------------------------
-- Not 1:1. The two currencies buy different things: 15 tokens buys a level-80
-- item, but the level-130 quartermaster charges 120 (ilvl 412) / 250 (ilvl 450).
-- Carrying the token numbers across 1:1 would import their overtuning -- 150
-- tokens is TEN level-80 items from one kill.
--
-- Half the token count, guaranteed, puts a level-129 rare at 37-75 sap, so about
-- four rare kills buy one 450 piece. Across all 42 that is ~1,260 sap per full
-- clear, plus 326_'s 2,891 from quests -- roughly one 16-slot 450 set (4,000
-- sap) for clearing the continent. That is the intended shape.
--
-- Quest sap amounts are LEFT AS 326_ SET THEM (2-10, tiered by zone). Those were
-- tuned for the sap economy and approved; the token line beside them is simply
-- the leftover that should have been removed.
--
-- ---------------------------------------------------------------------------
-- 🔴 THIS FILE IS INCOMPLETE ON ITS OWN -- YOU MUST ALSO APPLY 338_
-- ---------------------------------------------------------------------------
-- Step 3 below clears the token by zeroing whichever reward slot it occupied.
-- That leaves a HOLE, and the reward slots must be CONTIGUOUS: LoadQuests walks
-- RewardItem1..4 and stops at the first empty one, so a quest with slot 1 empty
-- and slot 2 filled has its reward DROPPED, not shifted up:
--
--     Quest 108798 has no `RewardItemId1` but has `RewardItem2`.
--     Reward item will not be loaded.          ... x545
--
-- The sap this file exists to preserve was therefore being discarded at load on
-- all 545 quests. The DB looked correct the whole time.
--
-- 338_ compacts the slots and repairs it. Apply 334_ then 338_, always.
--
-- 🔴 Also note step 1's snapshot is deliberately UNSCOPED -- it captures all 724
-- quests in the DB that pay an Upgrade Token, not just map 750's. That is fine
-- for a backup, but do NOT use `dc_map750_token_swap_backup` as "the set 334_
-- changed": 171 of those rows are level-80 Mythic+ quests this file never
-- touched and which correctly still pay tokens.
--
-- ---------------------------------------------------------------------------
-- Apply against acore_world, after 326_ and 331_, and BEFORE 338_. Idempotent.
-- Needs a worldserver restart.
-- ---------------------------------------------------------------------------

USE `acore_world`;

-- ---------------------------------------------------------------------------
-- 1. Snapshot what we are about to remove
-- ---------------------------------------------------------------------------
-- 🔴 INSERT IGNORE with no preceding DELETE, deliberately -- same reasoning as
-- 332_. A DELETE here would let a second run overwrite the true originals with
-- the already-converted values and destroy the only way back.
CREATE TABLE IF NOT EXISTS `dc_map750_token_swap_backup` (
  `kind`      VARCHAR(16)  NOT NULL,   -- 'quest' or 'loot'
  `id`        INT UNSIGNED NOT NULL,   -- quest ID, or creature_loot_template.Entry
  `slot`      TINYINT      NOT NULL,   -- reward slot 1-4, or 0 for loot
  `item`      INT UNSIGNED NOT NULL,
  `amount`    INT          NOT NULL,   -- RewardAmount, or MinCount for loot
  `amount_max` INT         NOT NULL DEFAULT 0,
  `chance`    FLOAT        NOT NULL DEFAULT 0,
  PRIMARY KEY (`kind`, `id`, `slot`, `item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `dc_map750_token_swap_backup` (`kind`,`id`,`slot`,`item`,`amount`)
SELECT 'quest', q.`ID`, 1, 300311, q.`RewardAmount1` FROM `quest_template` q WHERE q.`RewardItem1` = 300311
UNION ALL SELECT 'quest', q.`ID`, 2, 300311, q.`RewardAmount2` FROM `quest_template` q WHERE q.`RewardItem2` = 300311
UNION ALL SELECT 'quest', q.`ID`, 3, 300311, q.`RewardAmount3` FROM `quest_template` q WHERE q.`RewardItem3` = 300311
UNION ALL SELECT 'quest', q.`ID`, 4, 300311, q.`RewardAmount4` FROM `quest_template` q WHERE q.`RewardItem4` = 300311;

INSERT IGNORE INTO `dc_map750_token_swap_backup` (`kind`,`id`,`slot`,`item`,`amount`,`amount_max`,`chance`)
SELECT 'loot', l.`Entry`, 0, l.`Item`, l.`MinCount`, l.`MaxCount`, l.`Chance`
FROM `creature_loot_template` l
WHERE l.`Item` IN (300311, 400000)
  AND l.`Entry` IN (SELECT `lootid` FROM `creature_template` WHERE `entry` BETWEEN 3600000 AND 3799999);

-- ---------------------------------------------------------------------------
-- 2. The 8 token-ONLY quests -> sap
-- ---------------------------------------------------------------------------
-- 🔴 MUST RUN BEFORE step 3. These are DC's own zone breadcrumbs (81300-81315,
-- "The Call of Kalimdor", "Into Ashenvale", "The Sacred Mountain" ...). They have
-- no sap line at all, so step 3's blanket clear would strip their only currency
-- reward and leave them paying nothing. Converting them first means step 3 no
-- longer sees a token on them.
--
-- Banded off MinLevel to match 326_'s own zone tiering (2/2/3/4/4/6/10).
UPDATE `quest_template`
SET `RewardItem1` = 400000,
    `RewardAmount1` = CASE
        WHEN `MinLevel` <= 80  THEN 2
        WHEN `MinLevel` <= 90  THEN 3
        WHEN `MinLevel` <= 100 THEN 4
        WHEN `MinLevel` <= 108 THEN 6
        ELSE 10
    END
WHERE `RewardItem1` = 300311
  AND `RewardItem2` <> 400000 AND `RewardItem3` <> 400000 AND `RewardItem4` <> 400000
  AND `ID` IN (
      SELECT `quest` FROM `creature_queststarter` WHERE `id` BETWEEN 3600000 AND 3799999
      UNION
      SELECT `quest` FROM `creature_questender`  WHERE `id` BETWEEN 3600000 AND 3799999);

-- ---------------------------------------------------------------------------
-- 3. Clear the leftover token reward from the 545 that already pay sap
-- ---------------------------------------------------------------------------
-- One statement per slot: the token sits in a different RewardItem column
-- depending on the quest, and a reward slot is cleared by zeroing BOTH the item
-- and its amount.
--
-- Scoped to map-750 questgivers so the level-80 Mythic+ quests that are SUPPOSED
-- to pay tokens are untouched.
UPDATE `quest_template` q
SET q.`RewardItem1` = 0, q.`RewardAmount1` = 0
WHERE q.`RewardItem1` = 300311
  AND q.`ID` IN (SELECT `quest` FROM `creature_queststarter` WHERE `id` BETWEEN 3600000 AND 3799999
                 UNION SELECT `quest` FROM `creature_questender` WHERE `id` BETWEEN 3600000 AND 3799999);

UPDATE `quest_template` q
SET q.`RewardItem2` = 0, q.`RewardAmount2` = 0
WHERE q.`RewardItem2` = 300311
  AND q.`ID` IN (SELECT `quest` FROM `creature_queststarter` WHERE `id` BETWEEN 3600000 AND 3799999
                 UNION SELECT `quest` FROM `creature_questender` WHERE `id` BETWEEN 3600000 AND 3799999);

UPDATE `quest_template` q
SET q.`RewardItem3` = 0, q.`RewardAmount3` = 0
WHERE q.`RewardItem3` = 300311
  AND q.`ID` IN (SELECT `quest` FROM `creature_queststarter` WHERE `id` BETWEEN 3600000 AND 3799999
                 UNION SELECT `quest` FROM `creature_questender` WHERE `id` BETWEEN 3600000 AND 3799999);

UPDATE `quest_template` q
SET q.`RewardItem4` = 0, q.`RewardAmount4` = 0
WHERE q.`RewardItem4` = 300311
  AND q.`ID` IN (SELECT `quest` FROM `creature_queststarter` WHERE `id` BETWEEN 3600000 AND 3799999
                 UNION SELECT `quest` FROM `creature_questender` WHERE `id` BETWEEN 3600000 AND 3799999);

-- ---------------------------------------------------------------------------
-- 4. Merge the rare/boss token drop into the sap row
-- ---------------------------------------------------------------------------
-- 🔴 ORDER IS LOAD-BEARING: raise the sap row FIRST (it reads the token row's
-- counts through the self-join), then delete the token row in step 5. Delete
-- first and the amounts are gone.
--
-- A multi-table UPDATE with a self-join, not a subquery -- MySQL rejects
-- `UPDATE t ... WHERE ... (SELECT FROM t)` with error 1093.
--
-- GREATEST so a rare that already had a decent hand-authored sap row is not
-- reduced by the conversion.
UPDATE `creature_loot_template` s
JOIN `creature_loot_template` t
  ON t.`Entry` = s.`Entry` AND t.`Item` = 300311
SET s.`MinCount` = GREATEST(s.`MinCount`, CEIL(t.`MinCount` / 2)),
    s.`MaxCount` = GREATEST(s.`MaxCount`, CEIL(t.`MaxCount` / 2)),
    s.`Chance`   = 100
WHERE s.`Item` = 400000
  AND s.`Entry` IN (SELECT `lootid` FROM `creature_template` WHERE `entry` BETWEEN 3600000 AND 3799999);

-- ---------------------------------------------------------------------------
-- 5. Drop the token loot rows
-- ---------------------------------------------------------------------------
DELETE l FROM `creature_loot_template` l
WHERE l.`Item` = 300311
  AND l.`Entry` IN (SELECT `lootid` FROM `creature_template` WHERE `entry` BETWEEN 3600000 AND 3799999);

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- 🔴 THE ONE THAT MATTERS -- no map-750 quest may still pay tokens (expect 0):
-- SELECT COUNT(*) FROM quest_template q
-- WHERE 300311 IN (q.RewardItem1,q.RewardItem2,q.RewardItem3,q.RewardItem4)
--   AND q.ID IN (SELECT quest FROM creature_queststarter WHERE id BETWEEN 3600000 AND 3799999
--                UNION SELECT quest FROM creature_questender WHERE id BETWEEN 3600000 AND 3799999);
--
-- No map-750 creature may still drop tokens (expect 0):
-- SELECT COUNT(*) FROM creature_loot_template
-- WHERE Item = 300311 AND Entry IN (SELECT lootid FROM creature_template
--                                   WHERE entry BETWEEN 3600000 AND 3799999);
--
-- Every quest that used to pay a token still pays SOMETHING (expect 0 rows -- a
-- quest whose only currency reward was stripped is the failure mode of step 2
-- running after step 3):
-- SELECT b.id FROM dc_map750_token_swap_backup b
-- JOIN quest_template q ON q.ID = b.id
-- WHERE b.kind = 'quest'
--   AND 400000 NOT IN (q.RewardItem1,q.RewardItem2,q.RewardItem3,q.RewardItem4);
--
-- The rares now pay a rare-sized sap drop (expect ~37-75 @100% on the level-129s,
-- NOT 1-2 @15%):
-- SELECT ct.name, ct.minlevel, l.MinCount, l.MaxCount, l.Chance
-- FROM creature_loot_template l JOIN creature_template ct ON ct.lootid = l.Entry
-- WHERE l.Item = 400000 AND ct.entry BETWEEN 3600000 AND 3799999 AND ct.`rank` >= 2
-- ORDER BY ct.minlevel DESC LIMIT 15;
--
-- Sap income for a full continent clear:
-- SELECT (SELECT SUM(CASE WHEN RewardItem1=400000 THEN RewardAmount1 ELSE 0 END
--                  + CASE WHEN RewardItem2=400000 THEN RewardAmount2 ELSE 0 END
--                  + CASE WHEN RewardItem3=400000 THEN RewardAmount3 ELSE 0 END
--                  + CASE WHEN RewardItem4=400000 THEN RewardAmount4 ELSE 0 END)
--         FROM quest_template
--         WHERE ID IN (SELECT quest FROM creature_queststarter WHERE id BETWEEN 3600000 AND 3799999
--                      UNION SELECT quest FROM creature_questender WHERE id BETWEEN 3600000 AND 3799999)
--        ) AS sap_from_quests;
--
-- TO REVERT:
-- Quest token rewards and the original loot rows are all in
-- `dc_map750_token_swap_backup` (kind/id/slot/item/amount/amount_max/chance).
--
-- 🔴 NOT IN SCOPE, and NOT a bug: the level-80 Mythic+ quests outside the
-- 3600000-3799999 questgiver band still pay tokens. That is correct -- tokens
-- remain the Mythic+ currency; only Hyjal was supposed to move to sap.
-- ---------------------------------------------------------------------------
