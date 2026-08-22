-- -----------------------------------------------------------------------
-- item_set_names for the 45 Cataclysm sets added in files 11-18
-- -----------------------------------------------------------------------
-- Companion to 08_cata_itemset_names.sql, which covered only the 45 sets from
-- file 01. Files 11-18 added 45 more sets and their 225 parts were never given
-- name rows, so every boot still logs:
--
--   Item set part (Entry: 60248) does not have entry in `item_set_names`,
--   adding data from `item_template`.
--
-- Nothing is broken without this. ObjectMgr::LoadItemSetNames falls back to the
-- item_template name and InventoryType at runtime, but the fallback is never
-- persisted, so it re-logs on every start. These rows make it quiet.
--
-- Scope, measured against the live DB 2026-08-22: the sets in `itemset_dbc`
-- reference 473 distinct parts; 248 already had rows (file 08) and these 225
-- did not. All 225 exist in `item_template`, so every one has a real name and
-- slot to copy -- none falls into the worse branch of the loader, the one that
-- logs "set will not display properly" and inserts nothing.
--
-- Two traps this respects:
--   * The loader builds its checklist from ItemSet.dbc ItemID arrays, NOT from
--     item_template.itemset, and reads only the first MAX_ITEM_SET_ITEMS (10)
--     slots. A row for an entry outside those slots is rejected with "Item set
--     name (Entry: N) not found in ItemSet.dbc, data useless" -- trading one
--     warning for another. Verified: all 473 parts sit in slots 1-10, none
--     beyond, so the full set is covered and nothing extra is inserted.
--   * Only entries that currently HAVE NO ROW are touched. Restating all 473
--     would overwrite any curated stock name with the plain item_template one.
--
-- Values come from item_template by SELECT rather than being restated, so they
-- cannot drift from the item name and slot, and no name escaping is needed.
--
-- Apply AFTER 11-18 (which create the sets) and after 05 (where these items get
-- their final data). Idempotent. No core rebuild.
-- -----------------------------------------------------------------------

DELETE FROM `item_set_names` WHERE `entry` IN (
  60248, 60249, 60250, 60251, 60252, 60253, 60254, 60255, 60256, 60257, 60258, 60259,
  60261, 60262, 60275, 60281, 60282, 60283, 60284, 60285, 60323, 60324, 60325, 60326,
  60327, 60339, 60340, 60341, 60342, 60343, 60344, 60345, 60346, 60347, 60348, 60354,
  60355, 60356, 60357, 60358, 60359, 60360, 60361, 60362, 60363, 64923, 64924, 64925,
  64926, 64927, 64953, 64954, 64955, 64956, 64957, 64978, 64979, 64980, 64981, 64982,
  65152, 65153, 65154, 65155, 65156, 70941, 70942, 70943, 70944, 70945, 70946, 70947,
  70948, 70949, 70950, 70951, 70952, 70953, 70954, 70955, 71045, 71046, 71047, 71048,
  71049, 71058, 71059, 71060, 71061, 71062, 71063, 71064, 71065, 71066, 71067, 71091,
  71092, 71093, 71094, 71095, 71097, 71098, 71099, 71100, 71101, 71102, 71103, 71104,
  71105, 71106, 71107, 71108, 71109, 71110, 71111, 71276, 71277, 71278, 71279, 71280,
  71286, 71287, 71288, 71289, 71290, 71291, 71292, 71293, 71294, 71295, 71296, 71297,
  71298, 71299, 71300, 76212, 76213, 76214, 76215, 76216, 76339, 76340, 76341, 76342,
  76343, 76344, 76345, 76346, 76347, 76348, 76357, 76358, 76359, 76360, 76361, 76749,
  76750, 76751, 76752, 76753, 76756, 76757, 76758, 76759, 76760, 76765, 76766, 76767,
  76768, 76769, 76974, 76975, 76976, 76977, 76978, 76983, 76984, 76985, 76986, 76987,
  76988, 76989, 76990, 76991, 76992, 77003, 77004, 77005, 77006, 77007, 77008, 77009,
  77010, 77011, 77012, 77013, 77014, 77015, 77016, 77017, 77018, 77019, 77020, 77021,
  77022, 77023, 77024, 77025, 77026, 77027, 77028, 77029, 77030, 77031, 77032, 77035,
  77036, 77037, 77038, 77039, 77040, 77041, 77042, 77043, 77044
);

INSERT INTO `item_set_names` (`entry`, `name`, `InventoryType`)
SELECT it.`entry`, it.`name`, it.`InventoryType`
FROM `item_template` it
WHERE it.`entry` IN (
  60248, 60249, 60250, 60251, 60252, 60253, 60254, 60255, 60256, 60257, 60258, 60259,
  60261, 60262, 60275, 60281, 60282, 60283, 60284, 60285, 60323, 60324, 60325, 60326,
  60327, 60339, 60340, 60341, 60342, 60343, 60344, 60345, 60346, 60347, 60348, 60354,
  60355, 60356, 60357, 60358, 60359, 60360, 60361, 60362, 60363, 64923, 64924, 64925,
  64926, 64927, 64953, 64954, 64955, 64956, 64957, 64978, 64979, 64980, 64981, 64982,
  65152, 65153, 65154, 65155, 65156, 70941, 70942, 70943, 70944, 70945, 70946, 70947,
  70948, 70949, 70950, 70951, 70952, 70953, 70954, 70955, 71045, 71046, 71047, 71048,
  71049, 71058, 71059, 71060, 71061, 71062, 71063, 71064, 71065, 71066, 71067, 71091,
  71092, 71093, 71094, 71095, 71097, 71098, 71099, 71100, 71101, 71102, 71103, 71104,
  71105, 71106, 71107, 71108, 71109, 71110, 71111, 71276, 71277, 71278, 71279, 71280,
  71286, 71287, 71288, 71289, 71290, 71291, 71292, 71293, 71294, 71295, 71296, 71297,
  71298, 71299, 71300, 76212, 76213, 76214, 76215, 76216, 76339, 76340, 76341, 76342,
  76343, 76344, 76345, 76346, 76347, 76348, 76357, 76358, 76359, 76360, 76361, 76749,
  76750, 76751, 76752, 76753, 76756, 76757, 76758, 76759, 76760, 76765, 76766, 76767,
  76768, 76769, 76974, 76975, 76976, 76977, 76978, 76983, 76984, 76985, 76986, 76987,
  76988, 76989, 76990, 76991, 76992, 77003, 77004, 77005, 77006, 77007, 77008, 77009,
  77010, 77011, 77012, 77013, 77014, 77015, 77016, 77017, 77018, 77019, 77020, 77021,
  77022, 77023, 77024, 77025, 77026, 77027, 77028, 77029, 77030, 77031, 77032, 77035,
  77036, 77037, 77038, 77039, 77040, 77041, 77042, 77043, 77044
);

