-- mod-dungeon-clear: help text for its `.dc` subcommands.
-- The module ships no SQL, so every handler logged "missing help text" at startup.
-- `security` overrides the core level (ChatCommand.cpp), so it mirrors the module:
-- run controls are SEC_PLAYER (0), the test / lab / queue-fill tools SEC_GAMEMASTER (2).
-- The `dc` root row and `.dc teleporter` are DC's own and are left alone.
DELETE FROM `command` WHERE `name` IN ('dc on', 'dc off', 'dc skip', 'dc pause', 'dc pull', 'dc status');
DELETE FROM `command` WHERE `name` IN ('dc bosses', 'dc go', 'dc wing', 'dc config', 'dc spectate');
DELETE FROM `command` WHERE `name` = 'dc test' OR `name` LIKE 'dc test %';
DELETE FROM `command` WHERE `name` = 'dc lab' OR `name` LIKE 'dc lab %';
DELETE FROM `command` WHERE `name` = 'dc dungeonqueuefill' OR `name` LIKE 'dc dungeonqueuefill %';
DELETE FROM `command` WHERE `name` = 'dc bgqueuefill' OR `name` LIKE 'dc bgqueuefill %';
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('dc on', 0, 'Syntax: .dc on [wing]\nStart a dungeon clear: the tank bot in your group leads the party boss to boss. The optional wing (lbrs, ubrs, brd-db, brd-uc) picks the half of Blackrock Spire/Depths to run.'),
('dc off', 0, 'Syntax: .dc off\nStop the dungeon clear and return the bots to you.'),
('dc skip', 0, 'Syntax: .dc skip\nSkip the current objective when the tank bot is stalled.'),
('dc pause', 0, 'Syntax: .dc pause\nPause the dungeon clear in place. Use the command again to resume.'),
('dc pull', 0, 'Syntax: .dc pull [off|on|dynamic]\nSet the advanced-pull mode, or cycle off -> on -> dynamic without an argument. Can be set before .dc on.'),
('dc status', 0, 'Syntax: .dc status\nShow the current dungeon clear status.'),
('dc bosses', 0, 'Syntax: .dc bosses\nList the dungeon''s bosses and which are dead.'),
('dc go', 0, 'Syntax: .dc go $boss\nRoute the tank bot directly to the named boss.'),
('dc wing', 0, 'Syntax: .dc wing [wing]\nShow or change the wing (lbrs, ubrs, brd-db, brd-uc) without toggling the run.'),
('dc config', 0, 'Syntax: .dc config\nShow the effective DungeonClear.* settings for the current run, marking addon overrides and heroic defaults.'),
('dc spectate', 0, 'Syntax: .dc spectate [follow [$name]]\nToggle the free-fly spectator camera, or ride along with a bot.'),
('dc test', 2, 'Syntax: .dc test $subcommand\nGM-only automated dungeon clear test harness. Type .dc test to see the list of possible subcommands.'),
('dc test start', 2, 'Syntax: .dc test start $args\nRoll a bot party and start a test run.'),
('dc test status', 2, 'Syntax: .dc test status\nShow the running test runs.'),
('dc test stop', 2, 'Syntax: .dc test stop [$selector]\nStop a test run.'),
('dc test list', 2, 'Syntax: .dc test list\nList the dungeons the test harness can run.'),
('dc test gear', 2, 'Syntax: .dc test gear $args\nShow or set the gear tier used for test parties.'),
('dc test watch', 2, 'Syntax: .dc test watch [$selector]\nAttach the spectator camera to a test run.'),
('dc test plan', 2, 'Syntax: .dc test plan $subcommand\nRun the same dungeon repeatedly to measure a success rate. Type .dc test plan to see the list of possible subcommands.'),
('dc test plan start', 2, 'Syntax: .dc test plan start $args\nStart a test plan.'),
('dc test plan status', 2, 'Syntax: .dc test plan status\nShow the running test plans.'),
('dc test plan stop', 2, 'Syntax: .dc test plan stop [$selector]\nStop a test plan.'),
('dc test plan edit', 2, 'Syntax: .dc test plan edit $args\nChange a running test plan.'),
('dc test plan pause', 2, 'Syntax: .dc test plan pause [$selector]\nPause a test plan.'),
('dc test plan resume', 2, 'Syntax: .dc test plan resume [$selector]\nResume a paused test plan.'),
('dc lab', 2, 'Syntax: .dc lab $subcommand\nGM-only Pull Lab: scripted pull scenarios scored by oracles. Type .dc lab to see the list of possible subcommands.'),
('dc lab list', 2, 'Syntax: .dc lab list [$glob]\nList the Pull Lab scenarios.'),
('dc lab show', 2, 'Syntax: .dc lab show $id\nShow one Pull Lab scenario.'),
('dc lab run', 2, 'Syntax: .dc lab run $args\nRun a Pull Lab scenario.'),
('dc lab batch', 2, 'Syntax: .dc lab batch $args\nRun a batch of Pull Lab scenarios.'),
('dc lab status', 2, 'Syntax: .dc lab status\nShow the running Pull Lab jobs.'),
('dc lab stop', 2, 'Syntax: .dc lab stop\nStop the running Pull Lab jobs.'),
('dc dungeonqueuefill', 2, 'Syntax: .dc dungeonqueuefill $subcommand\nDungeon Finder instant bot fill (DungeonClear.DungeonQueueFill.Enable). Type .dc dungeonqueuefill to see the list of possible subcommands.'),
('dc dungeonqueuefill status', 2, 'Syntax: .dc dungeonqueuefill status\nShow the active Dungeon Finder fills.'),
('dc dungeonqueuefill cancel', 2, 'Syntax: .dc dungeonqueuefill cancel [$player]\nCancel a Dungeon Finder fill.'),
('dc dungeonqueuefill test', 2, 'Syntax: .dc dungeonqueuefill test [$player]\nStart a Dungeon Finder fill for a player.'),
('dc bgqueuefill', 2, 'Syntax: .dc bgqueuefill $subcommand\nBattleground instant bot fill (DungeonClear.BgQueueFill.Enable). Type .dc bgqueuefill to see the list of possible subcommands.'),
('dc bgqueuefill status', 2, 'Syntax: .dc bgqueuefill status\nShow the active battleground fills.'),
('dc bgqueuefill cancel', 2, 'Syntax: .dc bgqueuefill cancel [$player]\nCancel a battleground fill.'),
('dc bgqueuefill test', 2, 'Syntax: .dc bgqueuefill test [$player]\nStart a battleground fill for a player.');
