-- ---------------------------------------------------------------------------
-- 172  Hyjal round-39 -- the skinning block that keeps not running, + 2 strays
-- ---------------------------------------------------------------------------
--
-- ---------------------------------------------------------------------------
-- (1) 48 cloned creatures with a dangling skinloot -- 221 rows, third attempt
-- ---------------------------------------------------------------------------
--     Table 'skinning_loot_template' Entry 3706375 does not exist but it is
--     used by Creature 3706375        ... x48
--
-- The statement inside 166_ is CORRECT: run right now, its SELECT half yields
-- exactly the 221 rows it should insert, and the identical pattern filled
-- creature_loot_template (2,726 rows) and pickpocketing_loot_template (312) in
-- the same file.  Yet after two applications of 166_ the skinning band still
-- holds 0 rows -- the block is somehow being skipped at application time, and
-- from here that is not diagnosable.  So it moves into its own file, keyed off
-- the LIVE clone templates rather than 166_'s scratch tables, where it can be
-- run and verified in isolation.
--
-- CAST before subtracting: skinloot is UNSIGNED and the bare subtraction
-- aborts with "BIGINT UNSIGNED value is out of range" on any row the >= guard
-- has not filtered yet (same footgun as 171_).
--
-- Idempotent: NOT EXISTS keys each raw loot row to its clone id.
INSERT INTO `skinning_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry` + 3700000, s.`Item`, s.`Reference`, s.`Chance`, s.`QuestRequired`,
       s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, s.`Comment`
FROM `skinning_loot_template` s
WHERE s.`Entry` IN (SELECT DISTINCT CAST(t.`skinloot` AS SIGNED) - 3700000
                    FROM `creature_template` t
                    WHERE t.`entry` BETWEEN 3700000 AND 3799999 AND t.`skinloot` >= 3700000)
  AND NOT EXISTS (SELECT 1 FROM `skinning_loot_template` d
                  WHERE d.`Entry` = s.`Entry` + 3700000 AND d.`Item` = s.`Item`);

-- ---------------------------------------------------------------------------
-- (2) Frostmaul Preserver clone walks a waypoint path that was never cloned
-- ---------------------------------------------------------------------------
--     WaypointMovementGenerator::DoInitialize: creature Frostmaul Preserver
--     (Entry: 3707429) doesn't have waypoint path id: 0
--
-- Stock spawns carry their waypoint path per-GUID: creature_addon.path_id ->
-- waypoint_data, with path ids following the guid*10 convention.  The border
-- import copied the spawn row (keeping MovementType 2) but creature_addon is a
-- different table keyed by the OLD guid, so the path stayed behind.  Exactly
-- one spawn on the whole map is affected: raw guid 40864 (path 408640, 14
-- points, the Frostmaul Ravine patroller); its clone is guid 15600018.
--
-- The path is CLONED to 156000180 -- guid*10 for the new guid, keeping the
-- convention -- rather than shared, so editing the map-750 patrol never moves
-- the real Winterspring one.  Explicit column list: this fork's waypoint_data
-- adds `velocity` and `smoothTransition` over stock.
DELETE FROM `waypoint_data` WHERE `id` = 156000180;
INSERT INTO `waypoint_data`
  (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`,
   `velocity`, `delay`, `smoothTransition`, `move_type`, `action`, `action_chance`, `wpguid`)
SELECT 156000180, `point`, `position_x`, `position_y`, `position_z`, `orientation`,
       `velocity`, `delay`, `smoothTransition`, `move_type`, `action`, `action_chance`, 0
FROM `waypoint_data` WHERE `id` = 408640;

-- The clone has no addon row at all (verified), so this is a plain insert;
-- the raw addon carries nothing but the path (mount/bytes/emote/auras all 0).
DELETE FROM `creature_addon` WHERE `guid` = 15600018;
INSERT INTO `creature_addon`
  (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
VALUES (15600018, 156000180, 0, 0, 0, 0, 0, NULL);

-- ---------------------------------------------------------------------------
-- (3) Two vendor rows selling an item that does not exist
-- ---------------------------------------------------------------------------
--     Table `(game_event_)npc_vendor` for Vendor (Entry: 401101) have in item
--     list non-existed item (2332), ignore            ... also 401106
--
-- Item 2332 has no item_template row on this fork.  The guard keeps this from
-- ever deleting a legitimate row if the item is later restored.
DELETE FROM `npc_vendor`
WHERE `item` = 2332 AND `entry` IN (401101, 401106)
  AND NOT EXISTS (SELECT 1 FROM `item_template` i WHERE i.`entry` = 2332);

-- ---------------------------------------------------------------------------
-- (4) Cloned quests stole (or lost) their mail rewards -- 167_ regression
-- ---------------------------------------------------------------------------
--     Quest 108672 has `RewardMailTemplateId` = 130 but mail template  130
--     already used for quest 8672, quest will not have a mail reward.
--     Quest 5128 has `RewardMailTemplateId` = 98 but mail template  98
--     already used for quest 105128 ...
--     Quest 108726 has `RewardMailTemplateId` = 159 ... quest 8726 ...
--
-- 167_ copied the mail template verbatim, but the core enforces ONE quest per
-- mail template, first registration wins.  For 8672/8726 the original won and
-- the clone lost its mail -- cosmetic.  For 5128 the CLONE won, which silently
-- stripped the mail reward from the stock Everlook quest.  Zeroing the clones'
-- template ids gives all three originals their mail back; the clones simply
-- reward without the follow-up letter, which beats breaking stock.
--
-- The field lives in `quest_template_addon` on this fork -- NOT quest_template
-- -- and the column is `RewardMailTemplateID`, capital ID.  The worldserver log
-- prints its internal name "RewardMailTemplateId", which an earlier revision of
-- this file copied verbatim and died on with error 1054.  Log messages name
-- FIELDS, not columns; only information_schema names columns.
UPDATE `quest_template_addon` SET `RewardMailTemplateID` = 0, `RewardMailDelay` = 0
WHERE `ID` IN (105128, 108672, 108726) AND `RewardMailTemplateID` <> 0;

-- Verify -- expect 221 / 14 / 1 / 0:
--   SELECT COUNT(*) FROM `skinning_loot_template` WHERE `Entry` BETWEEN 3700000 AND 3799999;
--   SELECT COUNT(*) FROM `waypoint_data` WHERE `id` = 156000180;
--   SELECT COUNT(*) FROM `creature_addon` WHERE `guid` = 15600018;
--   SELECT COUNT(*) FROM `npc_vendor` WHERE `item` = 2332;
