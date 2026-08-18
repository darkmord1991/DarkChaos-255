-- 2026_08_18_01_dc_mount_catalog_fixes.sql
--
-- Two bad rows in the DC-Collection mount catalog, found 2026-08-18 while wiring up the
-- stock-mount previews. Both showed up as catalog entries with no real mount behind them.
--
-- ---------------------------------------------------------------------------------------
-- 1. DELETE the duplicate "Horn of the Timber Wolf" keyed on spell 55884.
--
--    Spell 55884 is not a mount at all: it is the generic Effect 36 (SPELL_EFFECT_LEARN_SPELL)
--    "Learning" spell that EVERY mount item carries as spellid_1, with the actual mount on
--    spellid_2. Something scraped spellid_1 instead of spellid_2 and produced this row.
--
--    Every field of it is wrong, and each one is copied from a DIFFERENT real row:
--      name          "Horn of the Timber Wolf" -> already exists as spell 580 (display 247)
--      source.boss   "Attumen the Huntsman"    -> belongs to spell 36702, Fiery Warhorses Reins
--      creature_entry 10184 = Onyxia           -> belongs to spell 69395, Reins of the Onyxian Drake
--    All three of those real rows are present and correct, so nothing is lost by deleting it.
--
-- 2. INSERT the missing "Acherus Deathcharger" (spell 48778).
--
--    A real WotLK mount (SPELL_AURA_MOUNTED -> creature 28302 -> display 25280) that was
--    never in dc_mount_definitions. It only appeared in the client catalog because
--    generate_dc_collection_cdbc.py globs worlddb/CollectionSystem/*.sql, which includes the
--    seed file dc_collection_sample_data.sql -- so a sample row with no live-DB row behind it
--    still reaches DCCollectionSource.cdbc. That sample row has been removed; this is the
--    real one. mount_type corrected 3 -> 0 (ground), class_mask left 0 like every other row
--    in the table (the column is unused: all 1493 rows are 0).
--
-- Apply to acore_world. Afterwards regenerate DCCollectionSource.cdbc
-- (python tools/generate_dc_collection_cdbc.py --only DCCollectionSource) and refresh
-- collectionextracts/extracts.sql, which is loaded LAST and would otherwise re-stale these.
-- ---------------------------------------------------------------------------------------

-- Both mounts are registered in TWO tables: dc_mount_definitions holds the data, and
-- dc_collection_definitions (collection_type 1 = MOUNT) is the enable index. 55884 is in both;
-- 48778 was in neither.

DELETE FROM `dc_mount_definitions` WHERE `spell_id` = 55884;
DELETE FROM `dc_collection_definitions` WHERE `collection_type` = 1 AND `entry_id` = 55884;

DELETE FROM `dc_mount_definitions` WHERE `spell_id` = 48778;
INSERT INTO `dc_mount_definitions`
    (`spell_id`, `name`, `mount_type`, `source`, `faction`, `class_mask`, `display_id`, `icon`,
     `rarity`, `speed`, `expansion`, `is_tradeable`, `profession_required`, `skill_required`, `flags`)
VALUES
    (48778, 'Acherus Deathcharger', 0,
     '{"type": "quest", "quest": "The Light of Dawn", "class": "Death Knight"}',
     0, 0, 25280, '', 3, 100, 2, 0, NULL, NULL, 0);

DELETE FROM `dc_collection_definitions` WHERE `collection_type` = 1 AND `entry_id` = 48778;
INSERT INTO `dc_collection_definitions` (`collection_type`, `entry_id`, `enabled`) VALUES
    (1, 48778, 1);

-- Verification:
--   SELECT spell_id, name, display_id FROM dc_mount_definitions WHERE spell_id IN (55884, 48778);
--   -- expect exactly one row back: 48778 / Acherus Deathcharger / 25280
--   SELECT name, COUNT(*) FROM dc_mount_definitions GROUP BY name HAVING COUNT(*) > 1;
--   -- "Horn of the Timber Wolf" must no longer appear (the remaining duplicate names are
--   --  legitimate Alliance/Horde pairs and stock-vs-downport pairs)
