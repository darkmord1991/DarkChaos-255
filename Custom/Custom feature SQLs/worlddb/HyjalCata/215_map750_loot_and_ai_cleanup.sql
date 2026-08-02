-- ---------------------------------------------------------------------------
-- 215  Map 750 -- three leftovers from 209_/210_/212_
-- ---------------------------------------------------------------------------
-- Post-restart state is good: the three-layer display problem is fully closed
-- (0 map-750 spawns missing creature_model_info, 0 missing creature_template_model,
-- 0 dangling gender partners) and map 750 now carries 12,885 creatures and
-- 4,780 gameobjects, up from 10,106 / 3,967 before Ashenvale and Winterspring.
--
-- What is left that is mine:
--
-- 1) reference_loot_template -- 209_ emptied FIVE of them, not the two 210_ saw.
--    209_ only accepted a reference row whose target was inside its own 11-id
--    import list, so any row pointing at a reference that ALREADY existed here
--    was dropped. Where every row of a template was such a row, the template
--    imported as empty and the core reports it as not existing. 210_ fixed
--    24104 and 24107 because those were the two the log named at the time --
--    fixing only what the log names is what let this run on. The real state:
--
--      24102  0 rows (cata has 3)  <- actively dangling, 3 uses
--      24103  0 rows (cata has 3)
--      24150  0 rows (cata has 2)
--      24731  0 rows (cata has 3)  <- actively dangling, 4 uses
--      24737  0 rows (cata has 3)
--      45001  5 of 11 rows         <- silently truncated
--      45004  8 of 10 rows         <- silently truncated
--      45008  6 of 10 rows         <- silently truncated
--      45009  8 of 12 rows         <- silently truncated
--      24104, 24107 are correct (210_)
--
--    All 11 are now fully importable -- checked, importable_now == cata_rows
--    for every one -- because the nested references they need exist by now.
--    Only 24102 and 24731 produce log lines; the four truncated ones were
--    dropping loot silently, which is worse.
--
-- 2) Four holiday questgiver templates 210_ cloned carry AIName = 'SmartAI'
--    with no smart_scripts rows, which is the error class 205_/210_ set out to
--    remove. 210_ cloned the templates verbatim and did not clear it.
--
-- 3) 212_ imported skinning data at six raw ids that nothing points at. Those
--    creatures already have a working skinloot aimed elsewhere (verified: zero
--    map-750 creatures have a dangling skinloot), so the rows are redundant.
--
-- NOT MINE, and deliberately left alone: `skinning_loot_template entry 7448 /
-- 10807 group 1 has total chance > 100%`. I assumed 212_ had mixed cata rows
-- into a stock entry and checked before writing a fix -- every item in both
-- entries already existed in cata, so the INSERT IGNORE added nothing. The
-- 81.05 + 38.59 + 10.46 + 8.49 is pre-existing stock data. It only started
-- being reported because 209_/212_ made Chillwind Chimaera and Ursius
-- reachable. Fixing it means re-balancing stock loot, which is a separate call.
--
-- Apply against acore_world, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) reference_loot_template -- restore all 11 completely
-- ---------------------------------------------------------------------------
-- The filter this time accepts a reference row if its target resolves ANYWHERE
-- (already here, or inside this same import), which is what 209_ should have
-- done. Re-stating all 11 rather than only the broken 5 also repairs the four
-- that were silently short.
-- ---------------------------------------------------------------------------
DELETE FROM `reference_loot_template` WHERE `Entry` IN (
  24102, 24103, 24104, 24107, 24150, 24731, 24737, 45001, 45004, 45008, 45009);

INSERT INTO `reference_loot_template`
    (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT r.`Entry`, r.`Item`, r.`Reference`, r.`Chance`, r.`QuestRequired`,
       r.`LootMode`, r.`GroupId`, r.`MinCount`, r.`MaxCount`, r.`Comment`
FROM `cata_world`.`reference_loot_template` r
WHERE r.`Entry` IN (24102, 24103, 24104, 24107, 24150, 24731, 24737, 45001, 45004, 45008, 45009)
  AND (   (r.`Reference` = 0 AND EXISTS (SELECT 1 FROM `item_template` i WHERE i.`entry` = r.`Item`))
       OR (r.`Reference` > 0
           AND (   r.`Reference` IN (24102, 24103, 24104, 24107, 24150, 24731,
                                     24737, 45001, 45004, 45008, 45009)
                OR EXISTS (SELECT 1 FROM `reference_loot_template` x
                           WHERE x.`Entry` = r.`Reference`))));

-- ---------------------------------------------------------------------------
-- B) Holiday questgivers -- drop the AIName 210_ carried over
-- ---------------------------------------------------------------------------
-- These have no smart_scripts and are event content with no spawns, so an empty
-- AIName (default AI) is both correct and quiet. Scoped to the ten 210_ created
-- and guarded on actually having no script rows, so it can never silence a
-- creature whose SmartAI is imported later.
-- ---------------------------------------------------------------------------
UPDATE `creature_template`
   SET `AIName` = ''
 WHERE `entry` IN (3715574, 3715606, 3715864, 3715909, 3725917,
                   3725922, 3725962, 3725994, 3726401, 3726520)
   AND `AIName` = 'SmartAI'
   AND NOT EXISTS (SELECT 1 FROM (SELECT `entryorguid` FROM `smart_scripts` WHERE `source_type` = 0) s
                   WHERE s.`entryorguid` = `creature_template`.`entry`);

-- ---------------------------------------------------------------------------
-- C) Redundant skinning entries 212_ added
-- ---------------------------------------------------------------------------
-- 212_ imported skinning keyed on cata's raw skinloot value, but the matching
-- creature_template rows already existed and were skipped by INSERT IGNORE, so
-- their skinloot still points at the DC shared templates (3800004 / 3800010)
-- they always used. Those resolve fine, so these six raw entries are duplicate
-- data nothing reads. Removing them clears the "isn't creature skinning id and
-- not referenced from loot, and thus useless" block.
--
-- Safe because no map-750 creature has a dangling skinloot -- verified 0 -- so
-- deleting these cannot make anything unskinnable.
-- ---------------------------------------------------------------------------
DELETE FROM `skinning_loot_template` WHERE `Entry` IN (3721, 3809, 3816, 3818, 3823, 10644);

-- ---------------------------------------------------------------------------
-- Verification after applying + restart:
--   -- all 11 references restored to their full cata row counts:
--   SELECT Entry, COUNT(*) FROM reference_loot_template
--    WHERE Entry IN (24102,24103,24104,24107,24150,24731,24737,45001,45004,45008,45009)
--    GROUP BY Entry;        -- 3,3,3,3,2,3,3,11,10,10,12
--
--   -- nothing references a loot template that does not exist (expect 0):
--   SELECT COUNT(*) FROM creature_loot_template l WHERE l.Reference>0
--     AND NOT EXISTS (SELECT 1 FROM reference_loot_template r WHERE r.Entry=l.Reference);
--
--   -- no holiday template still claims SmartAI without rows (expect 0):
--   SELECT COUNT(*) FROM creature_template ct
--    WHERE ct.entry IN (3715574,3715606,3715864,3715909,3725917,3725922,3725962,3725994,3726401,3726520)
--      AND ct.AIName='SmartAI';
--
--   -- no map-750 creature lost its skinning (expect 0):
--   SELECT COUNT(*) FROM creature c JOIN creature_template ct ON ct.entry=c.id
--    WHERE c.map=750 AND ct.skinloot>0
--      AND NOT EXISTS (SELECT 1 FROM skinning_loot_template s WHERE s.Entry=ct.skinloot);
--
-- Errors.log should lose the reference_loot_template 24102/24731 lines, the four
-- "3725962/3725994/3726401/3726520 has SmartAI enabled but no SmartAI entries"
-- lines, and the six skinning "useless" lines.
-- ---------------------------------------------------------------------------
