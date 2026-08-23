-- =====================================================================================
-- DC Teleporter: Naxxramas 40 (SoD) + Shadowfang Keep (Cataclysm), a new "Custom Raids"
-- category, and level labels across the whole dungeon/raid menu.
--
-- Table shape (read by src/server/scripts/DC/Teleporters/dc_teleporter.cpp:117):
--     id, parent, type, faction, security_level, icon, name, map, x, y, z, o
--
--   * parent 0 + type 1          = a category (map/x/y/z/o stay NULL)
--   * parent <category> + type 2 = a destination
--   * faction -1                 = both factions
--   * security_level             = compared per row against the player's GM level
--                                  (`GetSecurity() < option.SecurityLevel` -> hidden)
--   * icon 2                     = the icon every other teleport row uses
--
-- This file does three things:
--   1. adds the two missing destinations (Naxx 40 map 2921, SFK Cata map 825);
--   2. splits the raids out of "Custom Dungeons" (800) into a new "Custom Raids" (850);
--   3. appends "(N+)" to every dungeon and raid destination name, N being the level
--      that actually gates entry.
--
-- Apply with `.dc teleporter reload` in game (GM only, see dc_teleporter.cpp:270) or a
-- worldserver restart -- the options are cached in memory at startup.
--
-- -------------------------------------------------------------------------------------
-- WHERE THE LEVEL NUMBERS COME FROM
-- -------------------------------------------------------------------------------------
-- Every "(N+)" is `MIN(min_level)` from `dungeon_access_template` for that instance's
-- map -- i.e. the number the server itself enforces at the door, not a wiki value and
-- not a guess from mob levels. `max_level` is 0 on every row in the live table, so there
-- is no upper bound to print; "(N+)" is the honest shape, "N - M" would be invented.
--
-- Four of the labels cover an entrance that serves more than one instance, and take the
-- lowest gate of the set, because that is the first one the player can walk into:
--   * Hellfirecitadell    -> Ramparts 543 / Blood Furnace 542 / Shattered Halls 540, all 55
--   * Coilfang Reservoir  -> Slave Pens 547 / Underbog 546 / Steamvault 545, all 55
--   * Caverns of Time     -> Old Hillsbrad 560 (64) and Black Morass 269 (66) -> 64
--   * Frozen Halls        -> Forge of Souls 632 (75), Pit of Saron 658 (78),
--                            Halls of Reflection 668 (78) -> 75
--
-- Row 165 "Trial of the crusader" sits in the *dungeon* menu and its arrival point is the
-- shared Argent Coliseum entrance, so it is labelled from Trial of the Champion (650, 75),
-- the 5-man half. If you meant the raid (649, 80) it belongs under "Raids WOTLK" instead;
-- that is a content decision, not something this file should move for you.
--
-- The DC content numbers are the ones already deployed by each instance's own
-- registration file, not new tuning:
--   819 Timbermaw Hold 128 | 820 Blackfathom (Ashenvale) 90 | 823 Crescent Grove 88
--   824 Emerald Sanctum 128 | 825 SFK Cataclysm 80 | 669 Blackwing Descent 85
--   2296 Castle Nathria 80 | 2921 Naxxramas 40 60
--
-- NOTE on map 825: its `dungeon_access_template` gates (80 Normal / 85 Heroic+Mythic)
-- are flagged as PLACEHOLDER TUNING in ShadowfangKeepCata/02_map825_registration.sql,
-- and the map's spawns are still a mix of the Cata level-18-21 normal set (~190 spawns)
-- and the level-85 heroic set (~203 spawns). "(80+)" therefore describes the *door*
-- correctly and the *content* only loosely. When you re-level 825, re-run the UPDATE in
-- section 4 rather than editing the name by hand.
--
-- -------------------------------------------------------------------------------------
-- VISIBILITY -- READ THIS BEFORE YOU EXPECT PLAYERS TO SEE ANY OF IT
-- -------------------------------------------------------------------------------------
-- Category 800 "Custom Dungeons" carries security_level = 1, so the whole menu is GM-only
-- today. The new "Custom Raids" category is created with the SAME gating deliberately, so
-- this file does not silently publish Blackwing Descent, Castle Nathria, Naxx 40 and the
-- rest to the playerbase as a side effect of a re-organisation. To open either menu:
--
--     UPDATE `dc_teleporter` SET `security_level` = 0 WHERE `id` IN (800, 850);
--
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. New category: Custom Raids (850)
--
-- id 850 is free: the live parent-0 ids are 1-5, 80, 100, 150, 200, 250, 300, 400, 500,
-- 550, 600, 700, 705, 800 and 1000. 850 sorts between "Custom Dungeons" and "Guild House",
-- which is where it reads best -- the gossip menu is built in id order
-- (BuildTeleporterIndex sorts each parent's children, dc_teleporter.cpp:104).
-- -------------------------------------------------------------------------------------
DELETE FROM `dc_teleporter` WHERE `id` = 850 OR (`parent` = 0 AND `name` = 'Custom Raids');
INSERT INTO `dc_teleporter`
    (`id`, `parent`, `type`, `faction`, `security_level`, `icon`, `name`, `map`, `x`, `y`, `z`, `o`, `comment`) VALUES
    (850, 0, 1, -1, 1, 2, 'Custom Raids', NULL, NULL, NULL, NULL, NULL, 'DC custom/downported raids. security_level 1 mirrors category 800.');

-- -------------------------------------------------------------------------------------
-- 2. The two new destinations
--
-- Ids 807/808 continue the 800 band (live MAX under it was 806). The new raid is parented
-- to 850, the new dungeon stays under 800.
--
-- Naxxramas 40 (map 2921): the arrival point is game_tele 10650 'n40'
-- (3005.51, -3434.64, 304.195, 6.2831) -- the same point both entrance scripts use, so
-- this drops you where the Plaguewood runestone and the Stratholme trigger do, not
-- somewhere new.
--
-- Shadowfang Keep Cataclysm (map 825): the arrival point is areatrigger_teleport 6960's
-- target (-229.135, 2109.18, 76.8898, 1.267), i.e. the walk-in door's own destination,
-- inherited verbatim from stock trigger 145. Orientation 1.267 is used rather than
-- game_tele 10667's rounded 1.5 so the teleporter and the door agree exactly.
--
-- Both maps were verified to have an instance_template row (2921 -> instance_naxxramas_40,
-- 825 -> instance_sfk_cata); without one the player lands on a map with no instance script.
--
-- The DELETE covers the NAMES as well as the ids: the loader rejects duplicate labels
-- under the same parent (dc_teleporter.cpp:87), so a re-run under a different id would
-- leave a stale twin behind and log a duplicate-label warning at startup.
-- -------------------------------------------------------------------------------------
DELETE FROM `dc_teleporter`
    WHERE `id` IN (807, 808)
       OR (`parent` IN (800, 850) AND `name` IN ('Naxxramas 40 (SoD) (60+)', 'Naxxramas 40 (SoD)',
                                                 'Shadowfang Keep (Cataclysm) (80+)', 'Shadowfang Keep (Cataclysm)'));

INSERT INTO `dc_teleporter`
    (`id`, `parent`, `type`, `faction`, `security_level`, `icon`, `name`, `map`, `x`, `y`, `z`, `o`, `comment`) VALUES
    (807, 850, 2, -1, 0, 2, 'Naxxramas 40 (SoD) (60+)',          2921, 3005.510, -3434.640, 304.195, 6.283, 'game_tele 10650 n40 -- shared entrance arrival'),
    (808, 800, 2, -1, 0, 2, 'Shadowfang Keep (Cataclysm) (80+)',  825, -229.135,  2109.180,  76.890, 1.267, 'areatrigger_teleport 6960 target -- the walk-in door');

-- -------------------------------------------------------------------------------------
-- 3. Move the existing raids out of "Custom Dungeons" into "Custom Raids"
--
-- Re-parent only -- the ids stay put, so nothing that references them breaks and the
-- coordinates are untouched. Which of the six is a raid is not a judgement call here:
-- it is Map.dbc field 2 (InstanceType) as the LIVE server has it --
--   819 = 2 (raid), 824 = 2 (raid), 2921 = 2 (raid), 820 = 1 (dungeon), 823 = 1 (dungeon)
-- -- plus dungeon_access_template's own 10man/25man rows for 669 and 2296.
--
-- Staying behind under 800: 803 Blackfathom Deeps (820), 805 Crescent Grove (823),
-- 808 Shadowfang Keep Cataclysm (825).
-- -------------------------------------------------------------------------------------
UPDATE `dc_teleporter` SET `parent` = 850 WHERE `id` IN (801, 802, 804, 806);

-- -------------------------------------------------------------------------------------
-- 4. Level labels
--
-- Scoped by id, one statement per row, so a name that has since been edited by hand is
-- still overwritten predictably and a re-run is a no-op.
-- -------------------------------------------------------------------------------------

-- Dungeons Classic (80)
UPDATE `dc_teleporter` SET `name` = 'Stratholme (45+)'            WHERE `id` = 82;
UPDATE `dc_teleporter` SET `name` = 'Wailing Caverns (10+)'       WHERE `id` = 83;
UPDATE `dc_teleporter` SET `name` = 'Deathmines (10+)'            WHERE `id` = 84;
UPDATE `dc_teleporter` SET `name` = 'Shadowfang Keep (14+)'       WHERE `id` = 85;
UPDATE `dc_teleporter` SET `name` = 'Blackrockdepths (40+)'       WHERE `id` = 86;
UPDATE `dc_teleporter` SET `name` = 'Razorfen Kraul (17+)'        WHERE `id` = 87;
UPDATE `dc_teleporter` SET `name` = 'Razorfen Depths (25+)'       WHERE `id` = 88;
UPDATE `dc_teleporter` SET `name` = 'Scarlet Monastery (20+)'     WHERE `id` = 89;
UPDATE `dc_teleporter` SET `name` = 'Uldaman (30+)'               WHERE `id` = 90;
UPDATE `dc_teleporter` SET `name` = 'Mauradon (30+)'              WHERE `id` = 92;
UPDATE `dc_teleporter` SET `name` = 'Sunken Temple (35+)'         WHERE `id` = 93;
UPDATE `dc_teleporter` SET `name` = 'Duesterbruch (45+)'          WHERE `id` = 94;
UPDATE `dc_teleporter` SET `name` = 'Scholomance (45+)'           WHERE `id` = 95;
UPDATE `dc_teleporter` SET `name` = 'Zul`Farrak (35+)'            WHERE `id` = 96;

-- Dungeons TBC (100)
UPDATE `dc_teleporter` SET `name` = 'Magisters Terrace (65+)'     WHERE `id` = 101;
UPDATE `dc_teleporter` SET `name` = 'Hellfirecitadell (55+)'      WHERE `id` = 102;
UPDATE `dc_teleporter` SET `name` = 'Coilfang Reservoir (55+)'    WHERE `id` = 103;
UPDATE `dc_teleporter` SET `name` = 'Caverns of Time (64+)'       WHERE `id` = 104;
UPDATE `dc_teleporter` SET `name` = 'Auchenai Crypts (55+)'       WHERE `id` = 105;
UPDATE `dc_teleporter` SET `name` = 'Mana Tombs (55+)'            WHERE `id` = 106;
UPDATE `dc_teleporter` SET `name` = 'Sethekk Halls (55+)'         WHERE `id` = 107;
UPDATE `dc_teleporter` SET `name` = 'Shadow Labyrinth (65+)'      WHERE `id` = 108;

-- Dungeons WOTLK (150)
UPDATE `dc_teleporter` SET `name` = 'Halls of Lightning (75+)'    WHERE `id` = 151;
UPDATE `dc_teleporter` SET `name` = 'Utgarde Tower (75+)'         WHERE `id` = 152;
UPDATE `dc_teleporter` SET `name` = 'Halls of Stone (72+)'        WHERE `id` = 153;
UPDATE `dc_teleporter` SET `name` = 'Violet Citadel (70+)'        WHERE `id` = 155;
UPDATE `dc_teleporter` SET `name` = 'AhnKahet (68+)'              WHERE `id` = 157;
UPDATE `dc_teleporter` SET `name` = 'Azjol Nerub (67+)'           WHERE `id` = 158;
UPDATE `dc_teleporter` SET `name` = 'Utgarde Keep (65+)'          WHERE `id` = 160;
UPDATE `dc_teleporter` SET `name` = 'Drak Tharon (69+)'           WHERE `id` = 162;
UPDATE `dc_teleporter` SET `name` = 'Culling of Stratholme (75+)' WHERE `id` = 163;
UPDATE `dc_teleporter` SET `name` = 'Frozen Halls (75+)'          WHERE `id` = 164;
UPDATE `dc_teleporter` SET `name` = 'Trial of the crusader (75+)' WHERE `id` = 165;
UPDATE `dc_teleporter` SET `name` = 'The Nexus (66+)'             WHERE `id` = 166;
UPDATE `dc_teleporter` SET `name` = 'The Oculus (75+)'            WHERE `id` = 167;
UPDATE `dc_teleporter` SET `name` = 'Gundrak (71+)'               WHERE `id` = 168;
UPDATE `dc_teleporter` SET `name` = 'DrakTharon (69+)'            WHERE `id` = 169;

-- Raids Classic (200)
UPDATE `dc_teleporter` SET `name` = 'Onyxia (80+)'                WHERE `id` = 201;
UPDATE `dc_teleporter` SET `name` = 'Molten Core (50+)'           WHERE `id` = 202;
UPDATE `dc_teleporter` SET `name` = 'Blackwing Lair (60+)'        WHERE `id` = 203;
UPDATE `dc_teleporter` SET `name` = 'RuinsAhn Qiraj (50+)'        WHERE `id` = 204;
UPDATE `dc_teleporter` SET `name` = 'Temple of Ahn Qiraj (50+)'   WHERE `id` = 205;
UPDATE `dc_teleporter` SET `name` = 'Zul Gurub (50+)'             WHERE `id` = 206;

-- Raids TBC (250)
UPDATE `dc_teleporter` SET `name` = 'Karazhan (68+)'              WHERE `id` = 251;
UPDATE `dc_teleporter` SET `name` = 'Gruul (70+)'                 WHERE `id` = 252;
UPDATE `dc_teleporter` SET `name` = 'The Eye (70+)'               WHERE `id` = 253;
UPDATE `dc_teleporter` SET `name` = 'Black Temple (70+)'          WHERE `id` = 255;
UPDATE `dc_teleporter` SET `name` = 'Sun Well (70+)'              WHERE `id` = 256;
UPDATE `dc_teleporter` SET `name` = 'Eye of Eternity (80+)'       WHERE `id` = 257;
UPDATE `dc_teleporter` SET `name` = 'Zul Aman (70+)'              WHERE `id` = 258;

-- Raids WOTLK (300)
UPDATE `dc_teleporter` SET `name` = 'Naxxramas (80+)'             WHERE `id` = 301;
UPDATE `dc_teleporter` SET `name` = 'Obsidian Sanctum (80+)'      WHERE `id` = 302;
UPDATE `dc_teleporter` SET `name` = 'Archavons Vault (80+)'       WHERE `id` = 303;
UPDATE `dc_teleporter` SET `name` = 'Ulduar (80+)'                WHERE `id` = 304;
UPDATE `dc_teleporter` SET `name` = 'ICC (80+)'                   WHERE `id` = 305;

-- Custom Dungeons (800)
UPDATE `dc_teleporter` SET `name` = 'Blackfathom Deeps (Ashenvale) (90+)' WHERE `id` = 803;
UPDATE `dc_teleporter` SET `name` = 'Crescent Grove (88+)'                WHERE `id` = 805;

-- Custom Raids (850)
UPDATE `dc_teleporter` SET `name` = 'Blackwing Descent (85+)'     WHERE `id` = 801;
UPDATE `dc_teleporter` SET `name` = 'Castle Nathria (80+)'        WHERE `id` = 802;
UPDATE `dc_teleporter` SET `name` = 'Timbermaw Hold (128+)'       WHERE `id` = 804;
UPDATE `dc_teleporter` SET `name` = 'Emerald Sanctum (128+)'      WHERE `id` = 806;

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'new category 850 exists (want 1)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `dc_teleporter` WHERE `id` = 850 AND `parent` = 0 AND `type` = 1
UNION ALL SELECT 'new destinations 807/808 (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `dc_teleporter` WHERE `id` IN (807, 808)
UNION ALL SELECT 'raids now under 850 (want 5)', CAST(COUNT(*) AS CHAR)
    FROM `dc_teleporter` WHERE `parent` = 850
UNION ALL SELECT 'dungeons left under 800 (want 3)', CAST(COUNT(*) AS CHAR)
    FROM `dc_teleporter` WHERE `parent` = 800
UNION ALL SELECT 'destinations pointing at a map with no instance_template (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_teleporter` t LEFT JOIN `instance_template` i ON i.`map` = t.`map`
    WHERE t.`id` IN (807, 808) AND i.`map` IS NULL
UNION ALL SELECT 'duplicate labels under any parent (want 0)', CAST(COUNT(*) AS CHAR)
    FROM (SELECT `parent`, `faction`, `security_level`, `name` FROM `dc_teleporter`
          GROUP BY `parent`, `faction`, `security_level`, `name` HAVING COUNT(*) > 1) d
UNION ALL SELECT 'orphan parent links (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_teleporter` c LEFT JOIN `dc_teleporter` p ON p.`id` = c.`parent`
    WHERE c.`parent` <> 0 AND p.`id` IS NULL
UNION ALL SELECT 'empty categories (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_teleporter` m LEFT JOIN `dc_teleporter` c ON c.`parent` = m.`id`
    WHERE m.`type` = 1 AND c.`id` IS NULL
UNION ALL SELECT 'dungeon/raid rows still missing a level label (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `dc_teleporter` WHERE `parent` IN (80, 100, 150, 200, 250, 300, 800, 850)
      AND `name` NOT LIKE '%+)'
UNION ALL SELECT 'menus 800/850 visible to non-GMs (0 = GM only)', CAST(SUM(IF(`security_level` = 0, 1, 0)) AS CHAR)
    FROM `dc_teleporter` WHERE `id` IN (800, 850);
