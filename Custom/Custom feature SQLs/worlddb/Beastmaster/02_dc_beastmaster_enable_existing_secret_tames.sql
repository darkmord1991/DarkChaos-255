-- ====================================================================================
-- BEASTMASTER ROSTER - ENABLE EXISTING "SECRET TAME" ENTRIES (no downport needed)
-- ====================================================================================
-- These famous secret/challenge hunter-pet tames already exist in this world DB
-- (creature_template + model + display) but were never added to the Beastmaster
-- catalog roster. This just enables them. Creatures whose models are NOT in 3.3.5
-- (Gara, Hati, Fenryr, feathermanes, etc.) are NOT here -- they need the downport
-- pipeline (see 03_dc_beastmaster_downport_secret_tames.sql scaffold).
--
-- BeastmasterModelPaths.lua was regenerated to include the new display ids below.
-- ====================================================================================

-- ---- Molten Front spirit beasts (Cataclysm, exotic, family 46) ----------------------
-- Custom baked models already downported; displays 38748/38634 custom, 38749 stock.
DELETE FROM `dc_beastmaster_pets` WHERE `creature_id` IN (3654318, 3654319, 3654320);
INSERT INTO `dc_beastmaster_pets`
    (`creature_id`, `category`, `rarity`, `source_text`, `sort_order`, `enabled`) VALUES
    (3654318, 'Spirit Beast', 4, 'Molten Front (Firelands)', 2004, 1),  -- Ankha
    (3654319, 'Spirit Beast', 4, 'Molten Front (Firelands)', 2005, 1),  -- Magria
    (3654320, 'Spirit Beast', 4, 'Molten Front (Firelands)', 2006, 1);  -- Ban'thalos

-- ---- Spirit of Atha (WotLK spirit serpent, stock model 25864, family 6) --------------
DELETE FROM `dc_beastmaster_pets` WHERE `creature_id` = 29033;
INSERT INTO `dc_beastmaster_pets`
    (`creature_id`, `category`, `rarity`, `source_text`, `sort_order`, `enabled`) VALUES
    (29033, 'Spirit Beast', 4, 'Grizzly Hills (spirit serpent)', 2007, 1);  -- Spirit of Atha

-- ---- Thok the Bloodthirsty (custom entry 400101, family 37, stock display 5291) ------
-- NOTE: this entry's display (5291) resolves to a Raptor model, not a devilsaur, and
-- family 37 may render a blank family name if the client CreatureFamily.dbc lacks row 37.
-- Adoptable by any hunter (not flagged exotic). Verify look/family in-client; easy to
-- disable (set enabled=0) if the raptor stand-in isn't wanted.
DELETE FROM `dc_beastmaster_pets` WHERE `creature_id` = 400101;
INSERT INTO `dc_beastmaster_pets`
    (`creature_id`, `category`, `rarity`, `source_text`, `sort_order`, `enabled`) VALUES
    (400101, 'Devilsaur', 3, 'Siege of Orgrimmar (raid tame)', 2008, 1);  -- Thok the Bloodthirsty
