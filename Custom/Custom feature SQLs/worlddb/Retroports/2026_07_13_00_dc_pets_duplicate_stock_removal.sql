-- ============================================================
-- Remove 11 custom pet items that duplicate pre-existing STOCK
-- WotLK companion pets. The dc_pet_gen_batch.py downport pipeline
-- re-discovered these real retail companion names via retail
-- Item.csv (class=15/subclass=2) and generated brand-new custom
-- items/creatures for them without checking they already exist as
-- stock content under a different (lower, real) entry. Verified
-- 2026-07-13: no other table (loot/quest/mail/gameobject) references
-- any of these 11 item or creature entries, and no player owns one
-- (item_instance in acore_characters: 0 rows). Corresponding summon
-- spell rows must also be removed from Custom/CSV DBC/Spell.csv
-- (client-side, not a SQL table) before the next patch-4 deploy.
--
-- Duplicate pairs (custom item/creature -> stock original):
--   300439 Phoenix Hatchling Cage      / 3461257 -> 35504  Phoenix Hatchling
--   301382 Cage of the Mojo           / 3462208 -> 33993  Mojo
--   301881 Cage of the Mana Wyrmling  / 3462707 -> 29363  Mana Wyrmling
--   301882 Cage of the Shimmering Wyrmling / 3462708 -> 46820/46821 Shimmering Wyrmling
--   301884 Cage of the Mechanical Chicken  / 3462710 -> 10398  Mechanical Chicken
--   302160 Cage of the Ancona Chicken      / 3462986 -> 11023  Ancona Chicken
--   302177 Cage of the Tickbird Hatchling  / 3463003 -> 39896  Tickbird Hatchling
--   302515 Cage of the Baby Shark          / 3463341 -> 21168  Baby Shark
--   302516 Cage of the Elwynn Lamb         / 3463342 -> 44974  Elwynn Lamb
--   302538 Cage of the Sen'jin Fetish      / 3463364 -> 45606  Sen'jin Fetish
--   302553 Cage of the Tranquil Mechanical Yeti / 3463379 -> 21277 Tranquil Mechanical Yeti
-- ============================================================

DELETE FROM `npc_vendor` WHERE `entry` = 3461229 AND `item` IN (300439,301382,301881,301882,301884,302160,302177,302515,302516,302538,302553);

-- dc_collection_definitions' primary key is (collection_type, entry_id) -- the
-- CDBC generator's DELETE parser (load_collection_definition_index) requires an
-- explicit `collection_type = N` predicate in the WHERE clause to know which
-- type's in-memory dict to remove from; a bare `entry_id IN (...)` is silently
-- ignored (verified: regenerating the CDBC after such a DELETE left all 11
-- duplicates in place). Split per collection_type to match the real composite key.
DELETE FROM `dc_collection_definitions` WHERE `collection_type` = 2 AND `entry_id` IN (300439,301382,301881,301882,301884,302160,302177,302515,302516,302538,302553);
DELETE FROM `dc_collection_definitions` WHERE `collection_type` = 1 AND `entry_id` IN (301382,301881,301882,301884);

-- Only pet_entry 300439/301382 have a live-DB row today, but
-- 2026_07_11_01_dc_pets_final_batch.sql ALSO INSERTs dc_pet_definitions rows
-- for the other 9 (never applied to the live DB, but still read by the CDBC
-- generator, which sources from these files, not the live DB) -- delete all
-- 11 so both the live DB (no-op for the 9 that don't exist there) and the
-- generator's file-based view end up consistent.
DELETE FROM `dc_pet_definitions` WHERE `pet_entry` IN (300439,301382,301881,301882,301884,302160,302177,302515,302516,302538,302553);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (3461257,3462208,3462707,3462708,3462710,3462986,3463003,3463341,3463342,3463364,3463379);

DELETE FROM `creature_template` WHERE `entry` IN (3461257,3462208,3462707,3462708,3462710,3462986,3463003,3463341,3463342,3463364,3463379);

DELETE FROM `item_template` WHERE `entry` IN (300439,301382,301881,301882,301884,302160,302177,302515,302516,302538,302553);
