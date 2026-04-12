-- ========================================================================
-- DarkChaos Mythic+ System - WotLK Dungeon Profile Seed
-- ========================================================================
-- Purpose: Re-seed Wrath of the Lich King dungeon rows in dc_dungeon_mythic_profile
-- Usage : Run against acore_world if your database is missing the Mythic profile data
-- ========================================================================

USE acore_world;

INSERT INTO `dc_dungeon_mythic_profile` (
    `map_id`, `name`, `heroic_enabled`, `mythic_enabled`,
    `base_health_mult`, `base_damage_mult`,
    `heroic_level_normal`, `heroic_level_elite`, `heroic_level_boss`,
    `mythic_level_normal`, `mythic_level_elite`, `mythic_level_boss`,
    `death_budget`, `wipe_budget`, `loot_ilvl`, `token_reward`
) VALUES
    (574, 'Utgarde Keep', 1, 1, 1.35, 1.20, 0, 0, 0, 0, 0, 0, 12, 3, 200, 300311),
    (575, 'Utgarde Pinnacle', 1, 1, 1.35, 1.20, 0, 0, 0, 0, 0, 0, 15, 3, 219, 300311),
    (576, 'The Nexus', 1, 1, 1.35, 1.20, 0, 0, 0, 0, 0, 0, 12, 3, 200, 300311),
    (578, 'The Oculus', 1, 1, 1.35, 1.20, 0, 0, 0, 0, 0, 0, 18, 4, 200, 300311),
    (595, 'The Culling of Stratholme', 1, 1, 1.35, 1.20, 0, 0, 0, 0, 0, 0, 15, 3, 200, 300311),
    (599, 'Halls of Stone', 1, 1, 1.35, 1.20, 0, 0, 0, 0, 0, 0, 15, 3, 200, 300311),
    (600, 'Drak''Tharon Keep', 1, 1, 1.35, 1.20, 0, 0, 0, 0, 0, 0, 15, 3, 200, 300311),
    (601, 'Azjol-Nerub', 1, 1, 1.35, 1.20, 0, 0, 0, 0, 0, 0, 12, 3, 200, 300311),
    (602, 'Halls of Lightning', 1, 1, 1.35, 1.20, 0, 0, 0, 0, 0, 0, 15, 3, 219, 300311),
    (604, 'Gundrak', 1, 1, 1.35, 1.20, 0, 0, 0, 0, 0, 0, 15, 3, 200, 300311),
    (608, 'Violet Hold', 1, 1, 1.35, 1.20, 0, 0, 0, 0, 0, 0, 12, 3, 200, 300311),
    (619, 'Ahn''kahet: The Old Kingdom', 1, 1, 1.35, 1.20, 0, 0, 0, 0, 0, 0, 15, 3, 200, 300311),
    (632, 'The Forge of Souls', 1, 1, 1.35, 1.20, 0, 0, 0, 0, 0, 0, 10, 3, 219, 300311),
    (650, 'Trial of the Champion', 1, 1, 1.35, 1.20, 0, 0, 0, 0, 0, 0, 12, 3, 200, 300311),
    (658, 'Pit of Saron', 1, 1, 1.35, 1.20, 0, 0, 0, 0, 0, 0, 15, 3, 219, 300311),
    (668, 'Halls of Reflection', 1, 1, 1.35, 1.20, 0, 0, 0, 0, 0, 0, 18, 4, 219, 300311)
ON DUPLICATE KEY UPDATE
    `name` = VALUES(`name`),
    `heroic_enabled` = VALUES(`heroic_enabled`),
    `mythic_enabled` = VALUES(`mythic_enabled`),
    `base_health_mult` = VALUES(`base_health_mult`),
    `base_damage_mult` = VALUES(`base_damage_mult`),
    `death_budget` = VALUES(`death_budget`),
    `wipe_budget` = VALUES(`wipe_budget`),
    `loot_ilvl` = VALUES(`loot_ilvl`),
    `token_reward` = VALUES(`token_reward`);

-- ========================================================================
-- End of file
-- ========================================================================
