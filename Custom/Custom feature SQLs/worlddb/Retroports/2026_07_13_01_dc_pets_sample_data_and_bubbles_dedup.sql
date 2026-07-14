-- ============================================================
-- Fix 2: two more pet-duplicate bug classes found after the
-- 2026_07_13_00 cleanup, via a comprehensive name-collision sweep
-- across the whole DCCollectionSource CDBC output (not just the
-- "Cage of the X" wrapper pattern used for the first cleanup).
--
-- (A) worlddb/CollectionSystem/dc_collection_sample_data.sql is
-- stale early-development SAMPLE/PLACEHOLDER data (its own header
-- literally says "Sample... Description: Sample mount, pet, title,
-- and heirloom definitions"). Its 15 dc_pet_definitions rows use
-- essentially made-up pet_entry numbers that mostly do NOT match
-- the real WotLK item for that pet name -- verified against
-- item_template: entry 4055 ("Baby Blizzard Bear" per the sample)
-- is actually "Insignia Boots"; 7544 ("Sprite Darter Hatchling") is
-- "Champion's Cape"; 34724 ("Toxic Wasteling") is "NPC Equip 34724";
-- 36871 ("Kirin Tor Familiar") is "Fury of the Encroaching Storm";
-- 41936 ("Lil' Ragnaros") is "NPC Equip 41936"; 39656 ("Core Hound
-- Pup") is "Tyrael's Hilt"; 39709 ("Pebble") is "Verdant Tundra
-- Boots"; 33199 ("Little Fawn") is "NPC Equip 33199"; 34364 ("Mr.
-- Chilly") is "Sunfire Robe"; 15186 ("Tiny Snowman") is "Praetorian
-- Leggings"; 8494 ("Tiny Crimson Whelpling") is "Parrot Cage
-- (Hyacinth Macaw)"; 10673 ("Pet Bombling") doesn't exist as an item
-- at all. These 12 wrong keys are pure dc_pet_definitions/
-- dc_collection_definitions bugs -- the real items above are
-- legitimate, unrelated stock content (confirmed still referenced
-- by real creature/gameobject loot tables) and are NOT touched here.
--
-- 3 of the sample file's 15 pet_entry keys are DELIBERATELY EXCLUDED
-- from this cleanup because they COLLIDE with a real pet_entry
-- already used by legitimate stock or coincidentally-correct data
-- under the SAME primary key -- deleting them would remove the
-- real pet, not just the sample's stale contribution:
--   10398 - real stock pet is "Mechanical Chicken" (sample wrongly
--           claimed this key as "Mechanical Squirrel")
--   23713 - "Hippogryph Hatchling" (sample's claim happens to be
--           correct/redundant with real stock data, harmless)
--   32617 - "Sleepy Willy" (same as above, coincidentally correct)
--
-- (B) A GENUINE custom-pipeline self-duplicate, unrelated to (A):
-- "Bubbles" was downported TWICE in different batch runs, producing
-- TWO separate custom items/creatures with the IDENTICAL real
-- teaching-item icon (FileDataID 8134336, confirming same real
-- retail pet) but different models: item 301411 -> creature 3462237
-- -> Creature\hermitcrab\hermitcrab.m2, and item 302348 -> creature
-- 3463174 -> Creature\bubble_creature\bubble_creature.m2. Both are
-- valid MD20 files; kept 302348 ("bubble_creature" -- the model
-- folder name that actually matches the pet's real identity) and
-- removed 301411 ("hermitcrab" -- an unrelated-sounding model name,
-- most likely a mismatched source pick from the earlier batch run).
-- Verified 301411: no loot/mail reference, no player owns it.
-- ============================================================

-- (A) sample_data.sql stale pet rows -- 12 safe keys only, see notes above
DELETE FROM `dc_pet_definitions` WHERE `pet_entry` IN (4055,7544,8494,10673,15186,33199,34364,34724,36871,39656,39709,41936);
DELETE FROM `dc_collection_definitions` WHERE `collection_type` = 2 AND `entry_id` IN (4055,7544,8494,10673,15186,33199,34364,34724,36871,39656,39709,41936);

-- (B) Bubbles self-duplicate -- remove 301411 (hermitcrab), keep 302348 (bubble_creature)
DELETE FROM `npc_vendor` WHERE `entry` = 3461229 AND `item` = 301411;
DELETE FROM `dc_collection_definitions` WHERE `entry_id` = 301411;
DELETE FROM `dc_pet_definitions` WHERE `pet_entry` = 301411;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 3462237;
DELETE FROM `creature_template` WHERE `entry` = 3462237;
DELETE FROM `item_template` WHERE `entry` = 301411;
