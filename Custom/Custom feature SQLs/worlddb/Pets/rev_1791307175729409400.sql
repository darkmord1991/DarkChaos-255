-- DC-Collection Beastmaster catalog: correct pet families and add the missing Fox, Dog and Shale Spider tames.
--
-- Adopting from the catalog (dc_addon_beastmaster.cpp -> Player::CreatePet) makes a pet of the creature's
-- creature_template family, so a wrong family gives the wrong abilities and talent tree:
--   * Whirlwing, Mavarnir, Netherbeak, Lalathin (Feathermane secret tames) were Fox (50) -> Feathermane (57).
--   * Thok the Bloodthirsty (Giant Isles world boss, boss_thok) was Moth (37) -> Devilsaur (39), and exotic like
--     every Devilsaur. Family and the exotic flag only matter for taming, not for the boss fight.
--   * Spirit of Atha (stock SmartAI quest creature, no spawns) was Crocolisk (6) -> Spirit Beast (46), and exotic
--     like every Spirit Beast. Its catalog entry already said Spirit Beast.
-- No player owns a pet of any of these creatures.
--
-- New catalog rows: the tameable Fox, Dog and Shale Spider creatures that spawn in the world, one per look
-- (Blighthound shares the Bullmastiff model, Amthea the Crimson Shale Spider's). Rarity follows the stock
-- entries (common tames 1, exotic families 4) and the custom ones (non-exotic rares 3); source_text names the
-- zone as on the other custom entries. The catalog is read live (30 sec cache), the families need a restart.
--
-- cache_id is bumped because clients cache a creature's family and type flags (Cache\WDB) and never re-query;
-- with ClientCacheVersion = 0 every client clears that cache at its next login.

UPDATE `creature_template` SET `family` = 57 WHERE `entry` IN (990040, 990041, 990042, 990043);
UPDATE `creature_template` SET `family` = 39, `type_flags` = `type_flags` | 65536 WHERE `entry` = 400101;
UPDATE `creature_template` SET `family` = 46, `type_flags` = `type_flags` | 65536 WHERE `entry` = 29033;

DELETE FROM `dc_beastmaster_pets` WHERE `creature_id` IN (3644474, 3644551, 3749565, 4145335, 3644476, 4101547, 4101548, 4101549, 4110356, 4145367, 44425, 47071, 49815, 49816, 49822);
INSERT INTO `dc_beastmaster_pets` (`creature_id`, `category`, `rarity`, `source_text`, `sort_order`, `enabled`) VALUES
-- Fox
(3644474, 'Fox', 1, 'Western Plaguelands (148-153)', 3100, 1),
(3644551, 'Fox', 1, 'Western Plaguelands (148-153)', 3101, 1),
(3749565, 'Fox', 1, 'Winterspring (104-115)', 3102, 1),
(4145335, 'Fox', 1, 'Ruins of Gilneas (130-136)', 3103, 1),
-- Dog
(3644476, 'Dog', 1, 'Western Plaguelands (148-153)', 3110, 1),
(4101547, 'Dog', 1, 'Tirisfal Glades (130-136)', 3111, 1),
(4101548, 'Dog', 1, 'Tirisfal Glades (130-136)', 3112, 1),
(4101549, 'Dog', 1, 'Tirisfal Glades (130-136)', 3113, 1),
(4110356, 'Dog', 3, 'Tirisfal Glades (130-136), rare', 3114, 1),
(4145367, 'Dog', 1, 'Ruins of Gilneas (130-136)', 3115, 1),
-- Shale Spider (exotic)
(44425, 'Shale Spider', 4, 'Deepholm', 3120, 1),
(47071, 'Shale Spider', 4, 'Deepholm', 3121, 1),
(49815, 'Shale Spider', 4, 'Deepholm', 3122, 1),
(49816, 'Shale Spider', 4, 'Deepholm', 3123, 1),
(49822, 'Shale Spider', 4, 'Deepholm, rare', 3124, 1);

UPDATE `version` SET `cache_id` = `cache_id` + 1;
