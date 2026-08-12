-- =====================================================================================
-- Emerald Sanctum -- the four-week meta reward
--
-- USES `dc_collection_rewards`, NOT `achievement_reward`. The DC collection API attaches
-- mounts, pets, titles and appearances to quests and achievements as pure SQL, and everything
-- it hands out goes through DCCollection::GrantCollectible -- so the unlock, the spellbook
-- entry and the client notification stay in sync. A mailed item does none of that.
--
--   collection_type: 1 MOUNT, 2 PET, 3 TOY, 4 HEIRLOOM, 5 TITLE, 6 TRANSMOG
--   entry_id:        the mount/companion SPELL id (not the teaching item id)
--
-- The mount is an existing DC collection entry -- Sylverian Dreamer, a green Dream drake at
-- flying speed -- so the meta needed no new model, spell or item work at all.
--
-- Reload after applying with `.collection reload`; the table is cached at startup.
--
-- NOTE: `dc_collection_rewards` is live but was EMPTY before this. These are its first rows,
-- so treat the first end-to-end test as proving the mechanism, not just the content.
-- =====================================================================================

DELETE FROM `dc_collection_rewards` WHERE `source_type` = 'ACHIEVEMENT' AND `source_id` = 60056;
INSERT INTO `dc_collection_rewards`
    (`source_type`, `source_id`, `collection_type`, `entry_id`, `team`, `comment`) VALUES
    ('ACHIEVEMENT', 60056, 1, 302937, 0, 'Wakener of the Emerald Dream - Sylverian Dreamer'),
    ('ACHIEVEMENT', 60056, 5, 240, 0, 'Wakener of the Emerald Dream - the Dreamwalker');

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'reward rows (want 2)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `dc_collection_rewards` WHERE `source_id` = 60056
UNION ALL SELECT 'mount exists in dc_mount_definitions (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `dc_mount_definitions` WHERE `spell_id` = 302937
UNION ALL SELECT 'mount is a known collectible (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `dc_collection_definitions` WHERE `collection_type` = 1 AND `entry_id` = 302937;
