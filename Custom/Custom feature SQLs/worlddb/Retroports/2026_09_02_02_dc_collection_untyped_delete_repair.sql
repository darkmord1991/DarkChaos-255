-- Dark Chaos - repair the collateral of UNTYPED dc_collection_definitions deletes.
--
-- dc_collection_definitions is keyed by (collection_type, entry_id), and mount rows
-- (type 1, keyed by SPELL id) share the 30xxxx number space with pet rows (type 2, keyed
-- by ITEM id). Two July cleanups deleted pet rows WITHOUT a collection_type predicate --
--   Retroports/2026_07_13_01_dc_pets_sample_data_and_bubbles_dedup.sql
--       DELETE FROM `dc_collection_definitions` WHERE `entry_id` = 301411;
--   Retroports/2026_07_13_00_dc_pets_duplicate_stock_removal.sql (same shape, IN (...))
-- -- so every MOUNT whose summon spell id collided with a purged pet item id lost its
-- collection row too. Found 2026-09-02 while reconciling the client CDBC (an
-- expectedCount one higher than definitionCount). Live today: 5 mounts with a
-- dc_mount_definitions row, a purchasable item and a vendor slot, but no collection
-- row, i.e. invisible in the mount collection UI:
--
--   spell    mount                          display  item
--   301382   Cosmic Gladiator's Soul Eater  501823   yes
--   301411   Ancestral War Bear             501852   yes  (item 301081)
--   301881   Swift Gloomhoof                502322   yes
--   301882   Mountain Horse                 502323   yes
--   301884   Nether-Gorged Greatwyrm        502325   yes
--
-- The same untyped delete has a SECOND victim on the client side only: the CDBC
-- generator's collection index only honours a DELETE that names `collection_type`, so
-- it never dropped the PET row (2, 301411) from its view although the realm has no such
-- row. That phantom is what inflates the client's expected pet count by one. The typed
-- DELETE below is a no-op against the realm and exists for the generator.
--
-- RULE going forward: every DELETE against dc_collection_definitions must carry
-- `collection_type` -- for the realm's sake (cross-type collisions) and the generator's.

-- 1) the phantom pet row (client-side only; nothing to delete live)
DELETE FROM `dc_collection_definitions` WHERE `collection_type`=2 AND `entry_id`=301411;

-- 2) the five mounts, back into the collection
DELETE FROM `dc_collection_definitions` WHERE `collection_type`=1 AND `entry_id` IN (301382,301411,301881,301882,301884);
INSERT INTO `dc_collection_definitions` (`collection_type`,`entry_id`,`enabled`)
VALUES
(1,301382,1),
(1,301411,1),
(1,301881,1),
(1,301882,1),
(1,301884,1);
