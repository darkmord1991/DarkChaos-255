-- ---------------------------------------------------------------------------
-- 210  Map 750 -- clean up what the 205_-209_ restart revealed
-- ---------------------------------------------------------------------------
-- Errors.log went from 103 KB to 76.6 KB after 205_-209_ and the entire
-- `SmartScript::ProcessAction ... Link Event ... not found` runtime stream is
-- gone, as is the whole skinning_loot_template block for the 3.70M band. The
-- load-time `SmartAIMgr:` list dropped from 50 lines to 5, of which 3 are stock
-- content unrelated to this map (creatures 16256, 17238, 5391201).
--
-- What is left splits into three kinds, and it is worth being explicit about
-- which is which:
--
--   * CASCADED -- rows that could not fail before because they were being
--     rejected earlier in validation. Fixing the first error exposed the
--     second. Sections A and D.
--   * MY OWN MISTAKE -- 209_ pointed 11 creatures at the right loot but the
--     wrong copy of it. Section D.
--   * SCOPE MISSES -- my audits filtered on "spawned on map 750", but the core
--     validates every template whether it is spawned or not. Sections F and H.
--
-- NOT CAUSED BY 206_ -- checked, because it looked like it might be. The log
-- has `pool_gameobject has a non existing gameobject spawn (GUID: 15050337)`.
-- That guid is NOT in dc_map750_dupe_backup_go, and joining the whole 452-row
-- backup against pool_gameobject returns 0. There are 115 orphaned pool rows
-- database-wide and they pre-date all of this. 206_ removed nothing pooled.
--
-- Apply against acore_world, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) creature_text -- 2 cascaded TALK actions
-- ---------------------------------------------------------------------------
-- 205_ imported text for 15 creatures. These two were not in that list because
-- at the time their TALK rows were being rejected for carrying event params on
-- a LINK event -- the text error was masked behind the param error. With the
-- params zeroed the rows load, and now want text that is not here:
--     Twilight Fanatic  (3732888) group 1   -- cata has 2 rows
--     Forsaken Looter   (3734046) group 0   -- cata has 1 row
-- The full text set for both is imported, not just the group named in the log.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` IN (3732888, 3734046);

INSERT INTO `creature_text`
    (`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,
     `BroadcastTextId`,`TextRange`,`comment`)
SELECT t.`CreatureID` + 3700000, t.`GroupID`, t.`ID`, t.`Text`, t.`Type`, t.`Language`,
       t.`Probability`, t.`Emote`, t.`Duration`, t.`Sound`, t.`BroadcastTextId`,
       t.`TextRange`, t.`comment`
FROM `cata_world`.`creature_text` t
WHERE t.`CreatureID` IN (32888, 34046);

-- ---------------------------------------------------------------------------
-- B) smart_scripts for Great Bear Spirit -- introduced by 208_
-- ---------------------------------------------------------------------------
-- 208_ cloned the template with AIName = 'SmartAI' but not the script rows, so
-- the core reports "has SmartAI enabled but no SmartAI entries". The raw entry
-- 11956 has both rows in OUR OWN database and they are gossip quest-credit
-- actions for 5929/5930 (Dire Bear Form) -- they carry quest ids, not creature
-- ids, so nothing needs re-offsetting and the clone is exact.
-- ---------------------------------------------------------------------------
DELETE FROM `smart_scripts` WHERE `entryorguid` = 3711956 AND `source_type` = 0;

DROP TEMPORARY TABLE IF EXISTS `tmp_210_ss`;
CREATE TEMPORARY TABLE `tmp_210_ss` LIKE `smart_scripts`;
INSERT INTO `tmp_210_ss` SELECT * FROM `smart_scripts` WHERE `entryorguid` = 11956 AND `source_type` = 0;
UPDATE `tmp_210_ss` SET `entryorguid` = `entryorguid` + 3700000;
INSERT INTO `smart_scripts` SELECT * FROM `tmp_210_ss`;
DROP TEMPORARY TABLE `tmp_210_ss`;

-- ---------------------------------------------------------------------------
-- C) reference_loot_template 24104 and 24107 -- my filter was too strict
-- ---------------------------------------------------------------------------
-- 209_ imported these two but every one of their rows was dropped, so they
-- ended up as empty templates and the core reported them as not existing.
-- Cause: 209_ only accepted a reference row if the target was in that file's
-- own 11-id import list. All 6 rows here point at 24060/24062/24064/24066/
-- 24077/24078, which are NOT in that list because they already exist here --
-- 63 to 89 rows each. The filter should have accepted references that already
-- resolve, which is what this version does.
-- ---------------------------------------------------------------------------
DELETE FROM `reference_loot_template` WHERE `Entry` IN (24104, 24107);

INSERT INTO `reference_loot_template`
    (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT r.`Entry`, r.`Item`, r.`Reference`, r.`Chance`, r.`QuestRequired`,
       r.`LootMode`, r.`GroupId`, r.`MinCount`, r.`MaxCount`, r.`Comment`
FROM `cata_world`.`reference_loot_template` r
WHERE r.`Entry` IN (24104, 24107)
  AND (   (r.`Reference` = 0 AND EXISTS (SELECT 1 FROM `item_template` i WHERE i.`entry` = r.`Item`))
       OR (r.`Reference` > 0 AND EXISTS (SELECT 1 FROM `reference_loot_template` x WHERE x.`Entry` = r.`Reference`)));

-- ---------------------------------------------------------------------------
-- D) lootid -- point the 11 at map 750's OWN copy, not the stock one
-- ---------------------------------------------------------------------------
-- This one is my mistake in 209_, and the log named it precisely:
--     "Table 'creature_loot_template' Entry 3702071 isn't creature entry and
--      not referenced from loot, and thus useless."
-- ...for all 11 of them. When 209_ found these mobs at lootid = 0 it saw the
-- raw template (2071) and pointed there. But a map-750 copy already existed at
-- the OFFSET id (3702071) with byte-identical row counts -- 9/9, 11/11, 13/13,
-- 12/12, 14/14, 9/9, 11/11, 14/14, 10/10, 11/11, 4/4 -- and pointing past it
-- left it orphaned.
--
-- Either target yields the same loot, so nothing was broken in game. The offset
-- copy is the better one: it silences the 11 warnings and matches the dominant
-- convention here (164 of 243 map-750 creatures use lootid = entry).
-- ---------------------------------------------------------------------------
UPDATE `creature_template`
   SET `lootid` = `entry`
 WHERE `entry` IN (3702071, 3702165, 3702206, 3702207, 3702233, 3702237, 3702321,
                   3703717, 3703812, 3703814, 3703816)
   AND `lootid` = CAST(`entry` AS SIGNED) - 3700000;

-- ---------------------------------------------------------------------------
-- E) pickpocketloot -- same pattern, never wired at all
-- ---------------------------------------------------------------------------
-- Greymist Hunter, Greymist Oracle and Wrathtail Sorceress have a
-- pickpocketing_loot_template at their offset entry (1, 4 and 5 rows) while
-- creature_template.pickpocketloot is 0, so rogues get nothing and the core
-- calls the templates useless. These are humanoids and are meant to be
-- pickpocketable.
--
-- The fourth name in that log block, 3709460, is a genuinely orphaned template
-- -- no creature_template row exists for it at all -- and is left alone rather
-- than guessed at.
-- ---------------------------------------------------------------------------
UPDATE `creature_template`
   SET `pickpocketloot` = `entry`
 WHERE `entry` IN (3702206, 3702207, 3703717) AND `pickpocketloot` = 0;

-- ---------------------------------------------------------------------------
-- F) skinning -- the 4 my audit missed
-- ---------------------------------------------------------------------------
-- 209_'s audit only looked at creatures SPAWNED on map 750. The core validates
-- every template, so these four surfaced afterwards. None of them has a single
-- spawn anywhere, which is why they were invisible to a spawn-scoped query.
--
--   3702174 Coastal Frenzy -> skinloot 3702174. Raw 2174 exists here, so this
--           one is a straight clone like the other 47 in 209_.
--   3702070 Moonstalker Runt -> skinloot 3800002
--   3706789 Thistle Cub      -> skinloot 3800002
--   3703809 Ashenvale Bear   -> skinloot 3800005
--           3800002 and 3800005 look like intended DC shared beast-skinning
--           templates that were never authored -- they exist in no database,
--           and the stock counterparts (2070, 3809, 6789) have no skinning rows
--           either. There is nothing to import, so the pointer is cleared
--           rather than left dangling. No gameplay effect: these three have no
--           spawns. If those shared templates are ever written, restore with
--           UPDATE creature_template SET skinloot = 3800002 WHERE entry IN
--           (3702070, 3706789);  -- and 3800005 for 3703809.
--
-- The remaining log line, Creature 173798, is not a map-750 entry and is left
-- alone.
-- ---------------------------------------------------------------------------
DELETE FROM `skinning_loot_template` WHERE `Entry` = 3702174;

INSERT INTO `skinning_loot_template`
    (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT s.`Entry` + 3700000, s.`Item`, s.`Reference`, s.`Chance`, s.`QuestRequired`,
       s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, s.`Comment`
FROM `skinning_loot_template` s
WHERE s.`Entry` = 2174;

UPDATE `creature_template` SET `skinloot` = 0
 WHERE `entry` IN (3702070, 3703809, 3706789) AND `skinloot` IN (3800002, 3800005);

-- ---------------------------------------------------------------------------
-- G) gameobject_loot_template 39335 -- 272 rows that can never drop
-- ---------------------------------------------------------------------------
-- LootMode = 0 means no loot mode matches, so the item is unreachable. The core
-- prints one line per row and silently corrects it to 1 in memory, so the
-- chests do work -- but that is 272 lines of Errors.log every single startup.
-- Writing the correction to disk is exactly what the core already does at load,
-- so this changes no behaviour at all.
--
-- This is map-750 content: loot 39335 backs Maplewood Treasure Chest (3907521,
-- 2 spawns) and Runestone Treasure Chest (3907533, 1 spawn). It is also the
-- ONLY loot table in the database with LootMode = 0 -- creature, reference and
-- skinning tables all have zero such rows -- so this cannot spill anywhere else.
-- ---------------------------------------------------------------------------
UPDATE `gameobject_loot_template` SET `LootMode` = 1 WHERE `Entry` = 39335 AND `LootMode` = 0;

-- ---------------------------------------------------------------------------
-- H) 10 holiday questgiver templates
-- ---------------------------------------------------------------------------
-- 24 rows in creature_queststarter/creature_questender point at map-750
-- creatures that do not exist. All ten are seasonal event NPCs whose raw
-- templates are already here:
--     Lunar Festival  -- Elder Stonespire, Elder Brightspear,
--                        Valadar Starsong, Fariel Starsong
--     Midsummer       -- Winterspring Flame Warden, Winterspring Flame Keeper,
--                        Fire Eater, Flame Eater, Summer Scorchling,
--                        Festival Scorchling
--
-- The quest relations were ported with the +3,700,000 offset but the templates
-- were not -- the same class of gap as everything else in this pass. Cloning
-- the templates is preferred over deleting the relations: it costs 10 rows,
-- makes all 24 relations valid, and means the questgivers already exist if the
-- event layer is ever ported. They get no spawns, which is correct for event
-- content -- 208_ deliberately left the Lunar Festival spawns out.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (
  3715574, 3715606, 3715864, 3715909, 3725917, 3725922, 3725962, 3725994, 3726401, 3726520);
DELETE FROM `creature_template` WHERE `entry` IN (
  3715574, 3715606, 3715864, 3715909, 3725917, 3725922, 3725962, 3725994, 3726401, 3726520);

DROP TEMPORARY TABLE IF EXISTS `tmp_210_ct`;
CREATE TEMPORARY TABLE `tmp_210_ct` LIKE `creature_template`;
INSERT INTO `tmp_210_ct` SELECT * FROM `creature_template`
 WHERE `entry` IN (15574, 15606, 15864, 15909, 25917, 25922, 25962, 25994, 26401, 26520);
UPDATE `tmp_210_ct` SET `entry` = `entry` + 3700000;
INSERT INTO `creature_template` SELECT * FROM `tmp_210_ct`;
DROP TEMPORARY TABLE `tmp_210_ct`;

DROP TEMPORARY TABLE IF EXISTS `tmp_210_ctm`;
CREATE TEMPORARY TABLE `tmp_210_ctm` LIKE `creature_template_model`;
INSERT INTO `tmp_210_ctm` SELECT * FROM `creature_template_model`
 WHERE `CreatureID` IN (15574, 15606, 15864, 15909, 25917, 25922, 25962, 25994, 26401, 26520);
UPDATE `tmp_210_ctm` SET `CreatureID` = `CreatureID` + 3700000;
INSERT INTO `creature_template_model` SELECT * FROM `tmp_210_ctm`;
DROP TEMPORARY TABLE `tmp_210_ctm`;

-- ---------------------------------------------------------------------------
-- Verification after applying + restart (all expect 0 unless noted):
--   SELECT COUNT(*) FROM creature_text WHERE CreatureID IN (3732888,3734046);  -- 3
--   SELECT COUNT(*) FROM smart_scripts WHERE entryorguid=3711956;              -- 2
--   SELECT COUNT(*) FROM reference_loot_template WHERE Entry IN (24104,24107); -- 6
--   SELECT COUNT(*) FROM creature_template WHERE entry IN
--     (3715574,3715606,3715864,3715909,3725917,3725922,3725962,3725994,3726401,3726520); -- 10
--   SELECT COUNT(*) FROM gameobject_loot_template WHERE LootMode=0;
--   SELECT COUNT(*) FROM creature_template ct WHERE ct.skinloot>0 AND ct.entry>3000000
--     AND NOT EXISTS (SELECT 1 FROM skinning_loot_template l WHERE l.Entry=ct.skinloot);
--   SELECT COUNT(*) FROM creature_questender q WHERE q.id>3000000
--     AND NOT EXISTS (SELECT 1 FROM creature_template ct WHERE ct.entry=q.id);
--
-- KNOWN AND DELIBERATELY LEFT -- all pre-existing and none map-750 specific:
--   * 115 orphaned pool_gameobject rows (database-wide, predates this work).
--   * gameobject_loot_template 357751 / 28559 missing -- 24 spawns, none on 750.
--   * reference_loot_template 24161 group 1 chance sum 110%.
--   * 13 orphaned creature_loot_template entries (3702172, 3702184, 3707015 ...)
--     whose creature_template row does not exist at all.
--   * skinning_loot_template 173798, pickpocketing_loot_template 3709460.
--   * 5 unassigned ScriptNames and 4 Spell/script effect-mismatch warnings.
--   * Quest condition for non-existing quest 13250.
-- ---------------------------------------------------------------------------
