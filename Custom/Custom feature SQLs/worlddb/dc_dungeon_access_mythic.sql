-- ========================================================================
-- DarkChaos Mythic+ System - Dungeon Access Helpers
-- ========================================================================
-- Purpose: Ensure dungeon_access_template advertises Mythic (difficulty 2)
--          for every Wrath 5-player dungeon so portals remain visible.
-- ========================================================================

USE acore_world;

INSERT INTO `dungeon_access_template`
    (`id`, `map_id`, `difficulty`, `min_level`, `max_level`, `min_avg_item_level`, `comment`)
VALUES
    (122, 574, 2, 80, NULL, 0, 'Utgarde Keep - Mythic'),
    (123, 575, 2, 80, NULL, 0, 'Utgarde Pinnacle - Mythic'),
    (124, 576, 2, 80, NULL, 0, 'The Nexus - Mythic'),
    (125, 578, 2, 80, NULL, 0, 'The Oculus - Mythic'),
    (126, 595, 2, 80, NULL, 0, 'The Culling of Stratholme - Mythic'),
    (127, 599, 2, 80, NULL, 0, 'Halls of Stone - Mythic'),
    (128, 600, 2, 80, NULL, 0, 'Drak''Tharon Keep - Mythic'),
    (129, 601, 2, 80, NULL, 0, 'Azjol-Nerub - Mythic'),
    (130, 602, 2, 80, NULL, 0, 'Halls of Lightning - Mythic'),
    (131, 604, 2, 80, NULL, 0, 'Gundrak - Mythic'),
    (132, 608, 2, 80, NULL, 0, 'Violet Hold - Mythic'),
    (133, 619, 2, 80, NULL, 0, 'Ahn''kahet: The Old Kingdom - Mythic'),
    (134, 632, 2, 80, NULL, 0, 'The Forge of Souls - Mythic'),
    (135, 650, 2, 80, NULL, 0, 'Trial of the Champion - Mythic'),
    (136, 658, 2, 80, NULL, 0, 'Pit of Saron - Mythic'),
    (137, 668, 2, 80, NULL, 0, 'Halls of Reflection - Mythic')
ON DUPLICATE KEY UPDATE
    `min_level` = VALUES(`min_level`),
    `comment` = VALUES(`comment`);

-- ========================================================================
-- End of file
-- ========================================================================
