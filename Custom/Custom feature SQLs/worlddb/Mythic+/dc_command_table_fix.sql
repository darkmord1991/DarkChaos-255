-- DB update to add missing DC command table entries
-- This fixes the command table permission mismatches and missing help text warnings

-- First, delete any existing DC commands that might have wrong permissions
DELETE FROM `command` WHERE `name` LIKE 'aoeloot%';
DELETE FROM `command` WHERE `name` LIKE 'hotspot%';
DELETE FROM `command` WHERE `name` LIKE 'hotspots%';
DELETE FROM `command` WHERE `name` LIKE 'challenge%';
DELETE FROM `command` WHERE `name` LIKE 'dc%';
DELETE FROM `command` WHERE `name` LIKE 'dcquest%';
DELETE FROM `command` WHERE `name` LIKE 'dcquests%';
DELETE FROM `command` WHERE `name` LIKE 'faq%';
DELETE FROM `command` WHERE `name` LIKE 'hlbg%';
DELETE FROM `command` WHERE `name` LIKE 'prestige%';
DELETE FROM `command` WHERE `name` LIKE 'season%';
DELETE FROM `command` WHERE `name` LIKE 'upgrade%';
DELETE FROM `command` WHERE `name` LIKE 'upgradeprog%';
DELETE FROM `command` WHERE `name` LIKE 'upgradeadv%';
DELETE FROM `command` WHERE `name` LIKE 'checkachievements%';
DELETE FROM `command` WHERE `name` LIKE 'aio%';
DELETE FROM `command` WHERE `name` LIKE 'ahbotoptions%';
DELETE FROM `command` WHERE `name` LIKE 'flighthelper%';
DELETE FROM `command` WHERE `name` LIKE 'gpstest%';
DELETE FROM `command` WHERE `name` LIKE 'instance%';
DELETE FROM `command` WHERE `name` LIKE 'list%';
DELETE FROM `command` WHERE `name` LIKE 'mythic%';
DELETE FROM `command` WHERE `name` LIKE 'reload%';
DELETE FROM `command` WHERE `name` LIKE 'worldstate%';

-- Now insert all DC commands with proper help text and security levels
INSERT INTO `command` (`name`, `security`, `help`) VALUES

-- AoE Loot Commands
('aoeloot', 0, 'Syntax: .aoeloot $subcommand\nType .aoeloot to see the list of possible subcommands or .help aoeloot $subcommand to see info on subcommands'),
('aoeloot info', 0, 'Syntax: .aoeloot info\nDisplays AoE Loot system information and current configuration.'),
('aoeloot reload', 3, 'Syntax: .aoeloot reload\nReloads AoE Loot configuration from the config file.'),
('aoeloot stats', 1, 'Syntax: .aoeloot stats [$player]\nShows AoE Loot statistics for the selected player or yourself.'),
('aoeloot top', 0, 'Syntax: .aoeloot top\nShows the top 10 players by accumulated AoE Loot gold.'),
('aoeloot force', 1, 'Syntax: .aoeloot force [$guid]\nForces AoE Loot merge on the selected creature or specified GUID.'),

-- Hotspot Commands (both hotspot and hotspots variants)
('hotspot', 0, 'Syntax: .hotspot $subcommand\nType .hotspot to see the list of possible subcommands or .help hotspot $subcommand to see info on subcommands'),
('hotspot list', 1, 'Syntax: .hotspot list\nLists all active hotspots in the world.'),
('hotspot spawn', 3, 'Syntax: .hotspot spawn $map $x $y $z\nSpawns a hotspot at the specified coordinates.'),
('hotspot spawnhere', 3, 'Syntax: .hotspot spawnhere\nSpawns a hotspot at your current location.'),
('hotspot spawnworld', 3, 'Syntax: .hotspot spawnworld\nSpawns hotspots in optimal locations across the world.'),
('hotspot testmsg', 1, 'Syntax: .hotspot testmsg\nTests hotspot message broadcasting.'),
('hotspot testpayload', 1, 'Syntax: .hotspot testpayload\nTests hotspot addon payload sending.'),
('hotspot testxp', 1, 'Syntax: .hotspot testxp\nTests XP bonus calculation for hotspots.'),
('hotspot setbonus', 3, 'Syntax: .hotspot setbonus $bonus\nSets the XP bonus multiplier for hotspots.'),
('hotspot bonus', 0, 'Syntax: .hotspot bonus\nShows your current hotspot XP bonus.'),
('hotspot addonpackets', 3, 'Syntax: .hotspot addonpackets $enable\nEnables/disables hotspot addon packet sending.'),
('hotspot dump', 3, 'Syntax: .hotspot dump\nDumps all hotspot data for debugging.'),
('hotspot clear', 3, 'Syntax: .hotspot clear\nClears all active hotspots.'),
('hotspot reload', 3, 'Syntax: .hotspot reload\nReloads hotspot configuration.'),
('hotspot tp', 1, 'Syntax: .hotspot tp $id\nTeleports to the specified hotspot.'),
('hotspot forcebuff', 3, 'Syntax: .hotspot forcebuff\nForces buff application to all players in hotspots.'),
('hotspot status', 0, 'Syntax: .hotspot status\nShows hotspot system status and your current bonuses.'),

('hotspots', 0, 'Syntax: .hotspots $subcommand\nType .hotspots to see the list of possible subcommands or .help hotspots $subcommand to see info on subcommands'),
('hotspots list', 1, 'Syntax: .hotspots list\nLists all active hotspots in the world.'),
('hotspots spawn', 3, 'Syntax: .hotspots spawn $map $x $y $z\nSpawns a hotspot at the specified coordinates.'),
('hotspots spawnhere', 3, 'Syntax: .hotspots spawnhere\nSpawns a hotspot at your current location.'),
('hotspots spawnworld', 3, 'Syntax: .hotspots spawnworld\nSpawns hotspots in optimal locations across the world.'),
('hotspots testmsg', 1, 'Syntax: .hotspots testmsg\nTests hotspot message broadcasting.'),
('hotspots testpayload', 1, 'Syntax: .hotspots testpayload\nTests hotspot addon payload sending.'),
('hotspots testxp', 1, 'Syntax: .hotspots testxp\nTests XP bonus calculation for hotspots.'),
('hotspots setbonus', 3, 'Syntax: .hotspots setbonus $bonus\nSets the XP bonus multiplier for hotspots.'),
('hotspots bonus', 0, 'Syntax: .hotspots bonus\nShows your current hotspot XP bonus.'),
('hotspots addonpackets', 3, 'Syntax: .hotspots addonpackets $enable\nEnables/disables hotspot addon packet sending.'),
('hotspots dump', 3, 'Syntax: .hotspots dump\nDumps all hotspot data for debugging.'),
('hotspots clear', 3, 'Syntax: .hotspots clear\nClears all active hotspots.'),
('hotspots reload', 3, 'Syntax: .hotspots reload\nReloads hotspot configuration.'),
('hotspots tp', 1, 'Syntax: .hotspots tp $id\nTeleports to the specified hotspot.'),
('hotspots forcebuff', 3, 'Syntax: .hotspots forcebuff\nForces buff application to all players in hotspots.'),
('hotspots status', 0, 'Syntax: .hotspots status\nShows hotspot system status and your current bonuses.'),

-- Challenge Mode Commands
('challenge', 0, 'Syntax: .challenge $subcommand\nType .challenge to see the list of possible subcommands or .help challenge $subcommand to see info on subcommands'),

-- DC Commands
('dc', 0, 'Syntax: .dc $subcommand\nType .dc to see the list of possible subcommands or .help dc $subcommand to see info on subcommands'),

-- DC Quest Commands
('dcquest dismiss', 0, 'Syntax: .dcquest dismiss\nDismisses your current dungeon quest follower.'),
('dcquest summon', 0, 'Syntax: .dcquest summon\nSummons your dungeon quest follower.'),

('dcquests achievement', 0, 'Syntax: .dcquests achievement\nShows dungeon quest achievements.'),
('dcquests debug', 1, 'Syntax: .dcquests debug\nShows debug information for dungeon quests.'),
('dcquests give-token', 2, 'Syntax: .dcquests give-token $player $amount\nGives dungeon quest tokens to a player.'),
('dcquests help', 0, 'Syntax: .dcquests help\nShows help for dungeon quest commands.'),
('dcquests info', 0, 'Syntax: .dcquests info\nShows information about dungeon quests.'),
('dcquests list', 0, 'Syntax: .dcquests list\nLists available dungeon quests.'),
('dcquests progress', 0, 'Syntax: .dcquests progress\nShows your dungeon quest progress.'),
('dcquests reset', 2, 'Syntax: .dcquests reset $player\nResets dungeon quests for a player.'),
('dcquests reward', 0, 'Syntax: .dcquests reward\nShows dungeon quest rewards.'),
('dcquests title', 0, 'Syntax: .dcquests title\nShows dungeon quest titles.'),

-- FAQ Commands
('faq', 0, 'Syntax: .faq $subcommand\nType .faq to see the list of possible subcommands or .help faq $subcommand to see info on subcommands'),
('faq buff', 0, 'Syntax: .faq buff\nShows information about buffs in the game.'),
('faq discord', 0, 'Syntax: .faq discord\nShows Discord server information.'),
('faq dungeons', 0, 'Syntax: .faq dungeons\nShows information about dungeons.'),
('faq help', 0, 'Syntax: .faq help\nShows general help and FAQ.'),
('faq hinterland', 0, 'Syntax: .faq hinterland\nShows information about Battle for Gilneas.'),
('faq leveling', 0, 'Syntax: .faq leveling\nShows leveling guides and tips.'),
('faq maxlevel', 0, 'Syntax: .faq maxlevel\nShows information about max level content.'),
('faq source', 0, 'Syntax: .faq source\nShows information about the server source.'),
('faq t11', 0, 'Syntax: .faq t11\nShows information about Tier 11 content.'),
('faq t12', 0, 'Syntax: .faq t12\nShows information about Tier 12 content.'),
('faq teleporter', 0, 'Syntax: .faq teleporter\nShows information about teleportation.'),
('faq progression', 0, 'Syntax: .faq progression\nShows progression information.'),

-- HLBG Commands
('hlbg affix', 1, 'Syntax: .hlbg affix\nShows current Battle for Gilneas affixes.'),
('hlbg get', 0, 'Syntax: .hlbg get\nShows your Battle for Gilneas statistics.'),
('hlbg history', 0, 'Syntax: .hlbg history\nShows Battle for Gilneas match history.'),
('hlbg historyui', 0, 'Syntax: .hlbg historyui\nOpens Battle for Gilneas history UI.'),
('hlbg live', 0, 'Syntax: .hlbg live\nShows live Battle for Gilneas match information.'),
('hlbg queue join', 0, 'Syntax: .hlbg queue join\nJoins the Battle for Gilneas queue.'),
('hlbg queue leave', 0, 'Syntax: .hlbg queue leave\nLeaves the Battle for Gilneas queue.'),
('hlbg queue qstatus', 0, 'Syntax: .hlbg queue qstatus\nShows your queue status.'),
('hlbg queue status', 0, 'Syntax: .hlbg queue status\nShows queue status.'),
('hlbg reset', 2, 'Syntax: .hlbg reset\nResets Battle for Gilneas data.'),
('hlbg results', 0, 'Syntax: .hlbg results\nShows last match results.'),
('hlbg set', 2, 'Syntax: .hlbg set $option $value\nSets Battle for Gilneas configuration.'),
('hlbg statsmanual', 1, 'Syntax: .hlbg statsmanual\nManually updates Battle for Gilneas statistics.'),
('hlbg statsui', 0, 'Syntax: .hlbg statsui\nOpens Battle for Gilneas statistics UI.'),
('hlbg status', 0, 'Syntax: .hlbg status\nShows Battle for Gilneas status.'),
('hlbg warmup', 1, 'Syntax: .hlbg warmup\nStarts Battle for Gilneas warmup phase.'),

-- Prestige Commands
('prestige admin', 3, 'Syntax: .prestige admin $subcommand\nAdministrative commands for prestige system.'),
('prestige confirm', 0, 'Syntax: .prestige confirm\nConfirms prestige reset.'),
('prestige disable', 3, 'Syntax: .prestige disable\nDisables prestige system.'),
('prestige info', 0, 'Syntax: .prestige info\nShows prestige information.'),
('prestige reset', 0, 'Syntax: .prestige reset\nInitiates prestige reset.'),

-- Season Commands
('season history', 0, 'Syntax: .season history\nShows season history.'),
('season info', 0, 'Syntax: .season info\nShows current season information.'),
('season leaderboard', 0, 'Syntax: .season leaderboard\nShows season leaderboard.'),
('season reset', 2, 'Syntax: .season reset\nResets season data.'),

-- Upgrade Commands
('upgrade info', 0, 'Syntax: .upgrade info\nShows item upgrade information.'),
('upgrade list', 0, 'Syntax: .upgrade list\nLists your upgraded items.'),
('upgrade status', 0, 'Syntax: .upgrade status\nShows upgrade system status.'),
('upgrade token add', 2, 'Syntax: .upgrade token add $player $amount\nAdds upgrade tokens to a player.'),
('upgrade token info', 0, 'Syntax: .upgrade token info\nShows your upgrade token information.'),
('upgrade token remove', 2, 'Syntax: .upgrade token remove $player $amount\nRemoves upgrade tokens from a player.'),
('upgrade token set', 2, 'Syntax: .upgrade token set $player $amount\nSets upgrade tokens for a player.'),

('upgradeadv achievements', 0, 'Syntax: .upgradeadv achievements\nShows upgrade achievements.'),
('upgradeadv guild', 0, 'Syntax: .upgradeadv guild\nShows guild upgrade statistics.'),
('upgradeadv respec', 0, 'Syntax: .upgradeadv respec\nRespecs item upgrades.'),

('upgradeprog mastery', 0, 'Syntax: .upgradeprog mastery\nShows artifact mastery information.'),
('upgradeprog testset', 1, 'Syntax: .upgradeprog testset\nGives test gear for upgrade testing.'),
('upgradeprog tiercap', 0, 'Syntax: .upgradeprog tiercap\nShows tier unlock information.'),
('upgradeprog unlocktier', 0, 'Syntax: .upgradeprog unlocktier\nUnlocks upgrade tiers.'),

('upgradeprog weekcap', 0, 'Syntax: .upgradeprog weekcap\nShows weekly spending caps.'),

-- Other Commands
('checkachievements', 1, 'Syntax: .checkachievements\nChecks achievement completion.'),

('aio ping', 0, 'Syntax: .aio ping\nShows your latency.'),

('ahbotoptions', 3, 'Syntax: .ahbotoptions\nShows auction house bot options.'),

('chat on', 0, 'Syntax: .chat on\nEnables chat.'),
('chat off', 0, 'Syntax: .chat off\nDisables chat.'),

('cheat status', 1, 'Syntax: .cheat status\nShows cheat status.'),

('debug mapdata', 1, 'Syntax: .debug mapdata\nShows map debug data.'),
('debug unitstate', 1, 'Syntax: .debug unitstate\nShows unit state debug information.'),
('debug visibilitydata', 1, 'Syntax: .debug visibilitydata\nShows visibility debug data.'),

('event info', 1, 'Syntax: .event info\nShows event information.'),

('flighthelper path', 1, 'Syntax: .flighthelper path\nShows flight path information.'),

('gm off', 1, 'Syntax: .gm off\nDisables GM mode.'),
('gm on', 1, 'Syntax: .gm on\nEnables GM mode.'),
('gm spectator', 1, 'Syntax: .gm spectator\nEnables spectator mode.'),

('gpstest', 1, 'Syntax: .gpstest\nGPS test command.'),

('instance stats', 1, 'Syntax: .instance stats\nShows instance statistics.'),

('list auras id', 1, 'Syntax: .list auras id $id\nLists auras by spell ID.'),
('list auras name', 1, 'Syntax: .list auras name $name\nLists auras by spell name.'),

('mythic info', 0, 'Syntax: .mythic info\nShows mythic dungeon information.'),
('mythic reload', 2, 'Syntax: .mythic reload\nReloads mythic dungeon data.'),
('mythic showpoints', 0, 'Syntax: .mythic showpoints\nShows mythic points.'),
('mythic tiers', 0, 'Syntax: .mythic tiers\nShows mythic tiers.'),
('mythic updatepoints', 2, 'Syntax: .mythic updatepoints\nUpdates mythic points.'),

-- Reload Commands
('reload antidos_opcode_policies', 3, 'Syntax: .reload antidos_opcode_policies\nReloads antidos opcode policies.'),
('reload areatrigger', 3, 'Syntax: .reload areatrigger\nReloads areatrigger data.'),
('reload profanity_name', 3, 'Syntax: .reload profanity_name\nReloads profanity name filters.'),
('reload quest_offer_reward_locale', 3, 'Syntax: .reload quest_offer_reward_locale\nReloads quest offer reward locales.'),
('reload quest_request_item_locale', 3, 'Syntax: .reload quest_request_item_locale\nReloads quest request item locales.'),
('reload reputation_reward_rate', 3, 'Syntax: .reload reputation_reward_rate\nReloads reputation reward rates.'),
('reload reputation_spillover_template', 3, 'Syntax: .reload reputation_spillover_template\nReloads reputation spillover templates.'),
('reload warden_action', 3, 'Syntax: .reload warden_action\nReloads warden actions.'),

-- World State Commands
('worldstate sunsreach counter', 1, 'Syntax: .worldstate sunsreach counter\nShows Sunsreach counter.'),
('worldstate sunsreach gatecounter', 1, 'Syntax: .worldstate sunsreach gatecounter\nShows Sunsreach gate counter.'),
('worldstate sunsreach status', 1, 'Syntax: .worldstate sunsreach status\nShows Sunsreach status.');

-- Fix permission mismatches for existing commands