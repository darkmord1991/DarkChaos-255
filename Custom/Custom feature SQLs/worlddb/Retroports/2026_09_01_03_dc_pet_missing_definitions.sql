-- Dark Chaos - add the three vendor-sold pets that had no dc_pet_definitions row.
--
-- Found while reconciling the client CDBC (1329 pet rows) against the realm
-- (1326 dc_pet_definitions) after 2026_09_01_02_dc_pet_turtle_egg_repair.sql. The
-- three-row gap is the MIRROR of that file's first problem: here the collection
-- metadata is missing for pets that are otherwise complete and purchasable.
--
-- All three are already fully wired as items and already on sale -- nothing about
-- obtaining them changes, they were simply invisible to the collection system:
--
--   item    name                           spell  creature  display  sold by
--   8494    Parrot Cage (Hyacinth Macaw)   10682      7391     6192  Pets (500069, 601569)
--   32617   Sleepy Willy                   40613     23231    21381  Pets (500069, 601569)
--   39656   Tyrael's Hilt                  53082     29089    25900  Blizzard Collectibles (500103, 601603)
--
-- Every item already carries spellid_1 = 55884 + spellid_2 = <summon> at trigger 6,
-- every creature exists with a creature_template_model row, and every display has a
-- creature_model_info row. Verified against the live DB.
--
-- WHY THE CLIENT ALREADY LISTED THEM: the CDBC generator picks these three up from
-- CollectionSystem/dc_collection_sample_data.sql, which carries PLACEHOLDER values --
-- it labels 8494 "Tiny Crimson Whelpling" (spell 10697) and 39656 "Core Hound Pup"
-- (spell 69452), neither of which is what those entries actually are. The values
-- below are taken from the live tables, NOT from that sample file.
--
-- NOTE on display_id 21381 for Sleepy Willy: the CDBC currently shows 16068, which is
-- the sample file's value. creature_template_model says creature 23231 renders as
-- 21381, and that is what the server actually spawns, so 21381 is used here and the
-- next CDBC regeneration will pick it up from this row.

-- 1) dc_pet_definitions
DELETE FROM `dc_pet_definitions` WHERE `pet_entry` IN (8494,32617,39656);
INSERT INTO `dc_pet_definitions` (`pet_entry`,`name`,`pet_type`,`pet_spell_id`,`source`,`faction`,`display_id`,`icon`,`rarity`,`expansion`,`flags`,`variant_group`,`variant_color`)
VALUES
(8494,'Parrot Cage (Hyacinth Macaw)','companion',10682,'{"type":"vendor","npc":"Pets","npcEntry":500069}',0,6192,'',1,0,0,NULL,NULL),
(32617,'Sleepy Willy','companion',40613,'{"type":"vendor","npc":"Pets","npcEntry":500069}',0,21381,'',2,1,0,NULL,NULL),
(39656,'Tyrael''s Hilt','companion',53082,'{"type":"vendor","npc":"Blizzard Collectibles","npcEntry":500103}',0,25900,'',3,2,0,NULL,NULL);

-- 2) dc_collection_definitions
DELETE FROM `dc_collection_definitions` WHERE `collection_type`=2 AND `entry_id` IN (8494,32617,39656);
INSERT INTO `dc_collection_definitions` (`collection_type`,`entry_id`,`enabled`)
VALUES
(2,8494,1),
(2,32617,1),
(2,39656,1);

-- After this: dc_pet_definitions = 1329 and dc_collection_definitions(type 2) = 1329,
-- matching the client CDBC exactly. Item 32617 keeps its class 15 / subclass 0 -- the
-- collection tables do not read subclass, so there is no reason to touch a stock value.
