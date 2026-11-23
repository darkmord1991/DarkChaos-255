-- DarkChaos: help text for the gameplay test harness commands (administrators only, security 3)
-- Used by: src/server/scripts/DC/GameplayTest/dc_gameplay_test.cpp
DELETE FROM `command` WHERE `name` IN ('dca test run', 'dca test validate', 'dca test status', 'dca test abort', 'dca test list');
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('dca test run', 3, 'Syntax: .dca test run $scenario.json\r\nStarts a gameplay test scenario from DC.GameplayTest.ScenarioDir with characters of the lab account (DC.GameplayTest.Account) in a private phase. One run at a time; prints the run id. Off unless DC.GameplayTest.Enable = 1.'),
('dca test validate', 3, 'Syntax: .dca test validate $scenario.json\r\nParses and validates a scenario without touching any character.'),
('dca test status', 3, 'Syntax: .dca test status [$runId]\r\nShows the active run, or the result lines and report path of a finished run (the last one without a run id).'),
('dca test abort', 3, 'Syntax: .dca test abort\r\nStops the active run. Cleanup (despawn, restore, logout) still runs and a report is written.'),
('dca test list', 3, 'Syntax: .dca test list\r\nLists the scenario files in DC.GameplayTest.ScenarioDir.');
