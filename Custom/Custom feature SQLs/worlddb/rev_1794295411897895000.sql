--
-- DC command security: the `command` rows below were LOWER than the level the C++ command
-- table registers. ChatCommand.cpp LoadCommandMap let a row override the code level in both
-- directions, so these GM/admin handlers ran at the row's level. Players could run
-- `.dcquests reward/achievement/title` (grant tokens, any achievement, any title to anyone)
-- and `.upgrade token info <name>` (another player's balances). LoadCommandMap now refuses to
-- lower a SEC-registered command; these rows are aligned with the code so it logs nothing.
--
-- Not changed here: `dc` stays 0 (the player namespace: mod-dungeon-clear and `.dc difficulty`;
-- the cs_dc_addons GM/admin tools moved to their own root, `.dca`) and
-- `hlbg get/history/results/status` stay 0 (they are SEC_PLAYER in C++ now).
--

-- SEC_ADMINISTRATOR in cs_dc_dungeonquests.cpp
UPDATE `command` SET `security` = 3 WHERE `name` IN (
    'dcquests achievement', 'dcquests reward', 'dcquests title', 'dcquests progress',
    'dcquests list', 'dcquests info', 'dcquests help', 'dcquests debug',
    'dcquests give-token', 'dcquests reset');

-- SEC_ADMINISTRATOR in cs_dc_seasonal_rewards.cpp
UPDATE `command` SET `security` = 3 WHERE `name` = 'season reset';

-- SEC_GAMEMASTER in cs_dc_seasonal_rewards.cpp, cs_dc_item_upgrade.cpp, cs_dc_hotspot.cpp,
-- cs_dc_hinterland_bg.cpp
UPDATE `command` SET `security` = 2 WHERE `name` IN (
    'season info', 'upgrade token info',
    'hotspot list', 'hotspot tp', 'hotspots list', 'hotspots tp',
    'hlbg affix', 'hlbg statsmanual', 'hlbg warmup');
