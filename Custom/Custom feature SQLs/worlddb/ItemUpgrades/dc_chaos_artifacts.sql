-- =========================================================================
-- DarkChaos Item Upgrade System - Phase 2b: Chaos Artifact Definitions
-- World Database - Artifact Cosmetic/Location Mappings
-- =========================================================================
-- 
-- Chaos Artifacts: 110 total unique artifact definitions
-- These represent cosmetic/location variations of the Tier 5 Chaos system
--
-- LOCATION TYPES:
--   zone (7 per zone × 8 zones = 56 artifacts)
--     - Hellfire Peninsula, Zangarmarsh, Terokkar Forest, Shadowmoon Valley
--     - Isle of Quel'Danas, Wintergrasp, Tol Barad, Twilight Highlands
--   
--   dungeon (20 artifacts - instance drops)
--     - Various dungeons and raids (Karazhan, Black Temple, Hyjal, etc)
--
--   cosmetic (34 artifacts - color/effect/gender variants)
--     - Blue Theme (8), Red Theme (8), Purple Theme (8), Gold Theme (10)
--
-- =========================================================================

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

-- =========================================================================
-- ZONE ARTIFACTS (56 items)
-- 7 per zone × 8 zones (Hellfire, Zangar, Terokkar, Shadowmoon, Quel'Danas, WG, Tol Barad, Twilight)
-- =========================================================================

INSERT INTO dc_chaos_artifact_items (artifact_id, artifact_name, item_id, cosmetic_variant, location_type, location_name, essence_cost, is_active, season)
VALUES
-- Hellfire Peninsula Artifacts (7)
(1001, 'Hellfire Helm', 90000, 0, 'zone', 'Hellfire Peninsula', 250, 1, 1),
(1002, 'Hellfire Shoulder Guard', 90003, 0, 'zone', 'Hellfire Peninsula', 250, 1, 1),
(1003, 'Hellfire Gauntlets', 90006, 0, 'zone', 'Hellfire Peninsula', 250, 1, 1),
(1004, 'Hellfire Legguards', 90009, 0, 'zone', 'Hellfire Peninsula', 250, 1, 1),
(1005, 'Hellfire Boots', 90012, 0, 'zone', 'Hellfire Peninsula', 250, 1, 1),
(1006, 'Hellfire Chestplate', 90015, 0, 'zone', 'Hellfire Peninsula', 250, 1, 1),
(1007, 'Hellfire Crown', 90018, 0, 'zone', 'Hellfire Peninsula', 250, 1, 1),

-- Zangarmarsh Artifacts (7)
(1008, 'Zangar Helm', 90001, 0, 'zone', 'Zangarmarsh', 250, 1, 1),
(1009, 'Zangar Shoulder Guard', 90004, 0, 'zone', 'Zangarmarsh', 250, 1, 1),
(1010, 'Zangar Gauntlets', 90007, 0, 'zone', 'Zangarmarsh', 250, 1, 1),
(1011, 'Zangar Legguards', 90010, 0, 'zone', 'Zangarmarsh', 250, 1, 1),
(1012, 'Zangar Boots', 90013, 0, 'zone', 'Zangarmarsh', 250, 1, 1),
(1013, 'Zangar Chestplate', 90016, 0, 'zone', 'Zangarmarsh', 250, 1, 1),
(1014, 'Zangar Crown', 90020, 0, 'zone', 'Zangarmarsh', 250, 1, 1),

-- Terokkar Forest Artifacts (7)
(1015, 'Terokkar Helm', 90002, 0, 'zone', 'Terokkar Forest', 250, 1, 1),
(1016, 'Terokkar Shoulder Guard', 90005, 0, 'zone', 'Terokkar Forest', 250, 1, 1),
(1017, 'Terokkar Gauntlets', 90008, 0, 'zone', 'Terokkar Forest', 250, 1, 1),
(1018, 'Terokkar Legguards', 90011, 0, 'zone', 'Terokkar Forest', 250, 1, 1),
(1019, 'Terokkar Boots', 90014, 0, 'zone', 'Terokkar Forest', 250, 1, 1),
(1020, 'Terokkar Chestplate', 90017, 0, 'zone', 'Terokkar Forest', 250, 1, 1),
(1021, 'Terokkar Crown', 90021, 0, 'zone', 'Terokkar Forest', 250, 1, 1),

-- Shadowmoon Valley Artifacts (7)
(1022, 'Shadowmoon Helm', 90019, 0, 'zone', 'Shadowmoon Valley', 250, 1, 1),
(1023, 'Shadowmoon Shoulder Guard', 90023, 0, 'zone', 'Shadowmoon Valley', 250, 1, 1),
(1024, 'Shadowmoon Gauntlets', 90026, 0, 'zone', 'Shadowmoon Valley', 250, 1, 1),
(1025, 'Shadowmoon Legguards', 90029, 0, 'zone', 'Shadowmoon Valley', 250, 1, 1),
(1026, 'Shadowmoon Boots', 90032, 0, 'zone', 'Shadowmoon Valley', 250, 1, 1),
(1027, 'Shadowmoon Chestplate', 90035, 0, 'zone', 'Shadowmoon Valley', 250, 1, 1),
(1028, 'Shadowmoon Crown', 90038, 0, 'zone', 'Shadowmoon Valley', 250, 1, 1),

-- Isle of Quel'Danas Artifacts (7)
(1029, 'Quel''Danas Helm', 90022, 0, 'zone', 'Isle of Quel''Danas', 250, 1, 1),
(1030, 'Quel''Danas Shoulder Guard', 90024, 0, 'zone', 'Isle of Quel''Danas', 250, 1, 1),
(1031, 'Quel''Danas Gauntlets', 90027, 0, 'zone', 'Isle of Quel''Danas', 250, 1, 1),
(1032, 'Quel''Danas Legguards', 90030, 0, 'zone', 'Isle of Quel''Danas', 250, 1, 1),
(1033, 'Quel''Danas Boots', 90033, 0, 'zone', 'Isle of Quel''Danas', 250, 1, 1),
(1034, 'Quel''Danas Chestplate', 90036, 0, 'zone', 'Isle of Quel''Danas', 250, 1, 1),
(1035, 'Quel''Danas Crown', 90039, 0, 'zone', 'Isle of Quel''Danas', 250, 1, 1),

-- Wintergrasp Artifacts (7)
(1036, 'Wintergrasp Helm', 90025, 0, 'zone', 'Wintergrasp', 250, 1, 1),
(1037, 'Wintergrasp Shoulder Guard', 90028, 0, 'zone', 'Wintergrasp', 250, 1, 1),
(1038, 'Wintergrasp Gauntlets', 90031, 0, 'zone', 'Wintergrasp', 250, 1, 1),
(1039, 'Wintergrasp Legguards', 90034, 0, 'zone', 'Wintergrasp', 250, 1, 1),
(1040, 'Wintergrasp Boots', 90037, 0, 'zone', 'Wintergrasp', 250, 1, 1),
(1041, 'Wintergrasp Chestplate', 90040, 0, 'zone', 'Wintergrasp', 250, 1, 1),
(1042, 'Wintergrasp Crown', 90041, 0, 'zone', 'Wintergrasp', 250, 1, 1),

-- Tol Barad Artifacts (7)
(1043, 'Tol Barad Helm', 90043, 0, 'zone', 'Tol Barad', 250, 1, 1),
(1044, 'Tol Barad Shoulder Guard', 90044, 0, 'zone', 'Tol Barad', 250, 1, 1),
(1045, 'Tol Barad Gauntlets', 90047, 0, 'zone', 'Tol Barad', 250, 1, 1),
(1046, 'Tol Barad Legguards', 90050, 0, 'zone', 'Tol Barad', 250, 1, 1),
(1047, 'Tol Barad Boots', 90053, 0, 'zone', 'Tol Barad', 250, 1, 1),
(1048, 'Tol Barad Chestplate', 90056, 0, 'zone', 'Tol Barad', 250, 1, 1),
(1049, 'Tol Barad Crown', 90059, 0, 'zone', 'Tol Barad', 250, 1, 1),

-- Twilight Highlands Artifacts (7)
(1050, 'Twilight Helm', 90042, 0, 'zone', 'Twilight Highlands', 250, 1, 1),
(1051, 'Twilight Shoulder Guard', 90045, 0, 'zone', 'Twilight Highlands', 250, 1, 1),
(1052, 'Twilight Gauntlets', 90046, 0, 'zone', 'Twilight Highlands', 250, 1, 1),
(1053, 'Twilight Legguards', 90048, 0, 'zone', 'Twilight Highlands', 250, 1, 1),
(1054, 'Twilight Boots', 90051, 0, 'zone', 'Twilight Highlands', 250, 1, 1),
(1055, 'Twilight Chestplate', 90052, 0, 'zone', 'Twilight Highlands', 250, 1, 1),
(1056, 'Twilight Crown', 90054, 0, 'zone', 'Twilight Highlands', 250, 1, 1);

-- =========================================================================
-- DUNGEON ARTIFACTS (20 items)
-- Instance drops and hidden boss encounters
-- =========================================================================

INSERT INTO dc_chaos_artifact_items (artifact_id, artifact_name, item_id, cosmetic_variant, location_type, location_name, essence_cost, is_active, season)
VALUES
-- Karazhan
(2001, 'Karazhan Spellbinder', 90055, 0, 'dungeon', 'Karazhan', 250, 1, 1),
(2002, 'Karazhan Guardian', 90057, 0, 'dungeon', 'Karazhan', 250, 1, 1),

-- Black Temple
(2003, 'Black Temple Dreadnought', 90058, 0, 'dungeon', 'Black Temple', 250, 1, 1),
(2004, 'Black Temple Warlord', 90060, 0, 'dungeon', 'Black Temple', 250, 1, 1),

-- Hyjal Summit
(2005, 'Mount Hyjal Champion', 90061, 0, 'dungeon', 'Mount Hyjal', 250, 1, 1),
(2006, 'Mount Hyjal Sentinel', 90062, 0, 'dungeon', 'Mount Hyjal', 250, 1, 1),

-- The Sunwell Plateau
(2007, 'Sunwell Eternal', 90063, 0, 'dungeon', 'The Sunwell Plateau', 250, 1, 1),
(2008, 'Sunwell Radiant', 90064, 0, 'dungeon', 'The Sunwell Plateau', 250, 1, 1),

-- Icecrown Citadel
(2009, 'Icecrown Avenging', 90065, 0, 'dungeon', 'Icecrown Citadel', 250, 1, 1),
(2010, 'Icecrown Deathbringer', 90066, 0, 'dungeon', 'Icecrown Citadel', 250, 1, 1),

-- Ruby Sanctum
(2011, 'Ruby Sanctum Dragonslayer', 90067, 0, 'dungeon', 'Ruby Sanctum', 250, 1, 1),
(2012, 'Ruby Sanctum Twilight', 90068, 0, 'dungeon', 'Ruby Sanctum', 250, 1, 1),

-- Firelands
(2013, 'Firelands Emberclaw', 90069, 0, 'dungeon', 'Firelands', 250, 1, 1),
(2014, 'Firelands Scorched', 90070, 0, 'dungeon', 'Firelands', 250, 1, 1),

-- Dragon Soul
(2015, 'Dragon Soul Worldbreaker', 90071, 0, 'dungeon', 'Dragon Soul', 250, 1, 1),
(2016, 'Dragon Soul Corrupted', 90072, 0, 'dungeon', 'Dragon Soul', 250, 1, 1),

-- Additional Secret Dungeons
(2017, 'Ancient Vault Guardian', 90073, 0, 'dungeon', 'Ancient Vault', 250, 1, 1),
(2018, 'Shadow Nexus Keeper', 90074, 0, 'dungeon', 'Shadow Nexus', 250, 1, 1),
(2019, 'Void Dragon Slayer', 90075, 0, 'dungeon', 'Void Sanctum', 250, 1, 1),
(2020, 'Chaos Warden', 90076, 0, 'dungeon', 'Chaos Chamber', 250, 1, 1);

-- =========================================================================
-- COSMETIC ARTIFACTS (34 items)
-- Color themes and gender/style variants
-- =========================================================================

INSERT INTO dc_chaos_artifact_items (artifact_id, artifact_name, item_id, cosmetic_variant, location_type, location_name, essence_cost, is_active, season)
VALUES
-- Blue Theme (8 - Water/Frost magic)
(3001, 'Sapphire Regalia', 90077, 0, 'cosmetic', 'Blue Theme', 250, 1, 1),
(3002, 'Azure Guardian', 90080, 0, 'cosmetic', 'Blue Theme', 250, 1, 1),
(3003, 'Glacial Warden', 90083, 0, 'cosmetic', 'Blue Theme', 250, 1, 1),
(3004, 'Frostborn Elite', 90086, 0, 'cosmetic', 'Blue Theme', 250, 1, 1),
(3005, 'Sapphire Feminine', 90089, 0, 'cosmetic', 'Blue Theme - Female', 250, 1, 1),
(3006, 'Azure Maidens', 90092, 0, 'cosmetic', 'Blue Theme - Female', 250, 1, 1),
(3007, 'Glacial Princess', 90095, 0, 'cosmetic', 'Blue Theme - Female', 250, 1, 1),
(3008, 'Frostborn Queen', 90098, 0, 'cosmetic', 'Blue Theme - Female', 250, 1, 1),

-- Red Theme (8 - Fire/Blood magic)
(3009, 'Crimson Dreadplate', 90078, 0, 'cosmetic', 'Red Theme', 250, 1, 1),
(3010, 'Hellfire Champion', 90081, 0, 'cosmetic', 'Red Theme', 250, 1, 1),
(3011, 'Infernal Tyrant', 90084, 0, 'cosmetic', 'Red Theme', 250, 1, 1),
(3012, 'Bloodforged Warlord', 90087, 0, 'cosmetic', 'Red Theme', 250, 1, 1),
(3013, 'Crimson Maiden', 90090, 0, 'cosmetic', 'Red Theme - Female', 250, 1, 1),
(3014, 'Hellfire Lady', 90093, 0, 'cosmetic', 'Red Theme - Female', 250, 1, 1),
(3015, 'Infernal Empress', 90096, 0, 'cosmetic', 'Red Theme - Female', 250, 1, 1),
(3016, 'Bloodforged Sorceress', 90099, 0, 'cosmetic', 'Red Theme - Female', 250, 1, 1),

-- Purple Theme (8 - Shadow/Void magic)
(3017, 'Shadowborn Vestige', 90079, 0, 'cosmetic', 'Purple Theme', 250, 1, 1),
(3018, 'Void Warden', 90082, 0, 'cosmetic', 'Purple Theme', 250, 1, 1),
(3019, 'Netherwind Deathbringer', 90085, 0, 'cosmetic', 'Purple Theme', 250, 1, 1),
(3020, 'Shadow Legion Veteran', 90088, 0, 'cosmetic', 'Purple Theme', 250, 1, 1),
(3021, 'Shadowborn Maiden', 90091, 0, 'cosmetic', 'Purple Theme - Female', 250, 1, 1),
(3022, 'Void Enchantress', 90094, 0, 'cosmetic', 'Purple Theme - Female', 250, 1, 1),
(3023, 'Netherwind Mistress', 90097, 0, 'cosmetic', 'Purple Theme - Female', 250, 1, 1),
(3024, 'Shadow Legion Priestess', 90100, 0, 'cosmetic', 'Purple Theme - Female', 250, 1, 1),

-- Gold Theme (10 - Light/Divine magic)
(3025, 'Divine Ascendant', 90101, 0, 'cosmetic', 'Gold Theme', 250, 1, 1),
(3026, 'Celestial Guardian', 90102, 0, 'cosmetic', 'Gold Theme', 250, 1, 1),
(3027, 'Holy Valiant', 90103, 0, 'cosmetic', 'Gold Theme', 250, 1, 1),
(3028, 'Radiant Champion', 90104, 0, 'cosmetic', 'Gold Theme', 250, 1, 1),
(3029, 'Prismatic Sage', 90105, 0, 'cosmetic', 'Gold Theme', 250, 1, 1),
(3030, 'Divine Radiance', 90106, 0, 'cosmetic', 'Gold Theme - Female', 250, 1, 1),
(3031, 'Celestial Maiden', 90107, 0, 'cosmetic', 'Gold Theme - Female', 250, 1, 1),
(3032, 'Holy Priestess', 90108, 0, 'cosmetic', 'Gold Theme - Female', 250, 1, 1),
(3033, 'Radiant Seer', 90109, 0, 'cosmetic', 'Gold Theme - Female', 250, 1, 1),
(3034, 'Prismatic Oracle', 90101, 1, 'cosmetic', 'Gold Theme - Special', 250, 1, 1);

/*!40101 SET TIME_ZONE=@OLD_TIME_ZONE */;
/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET SQL_NOTES=@OLD_SQL_NOTES */;
