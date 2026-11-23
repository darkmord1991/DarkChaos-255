-- DC client lab probe relay (src/server/scripts/DC/LabTools/dc_lab_probe.cpp): help text for `.dca probe`.
-- Security matches the C++ level (SEC_ADMINISTRATOR); the feature itself stays off until DC.LabProbe.Enable = 1.
DELETE FROM `command` WHERE `name` IN ('dca probe send', 'dca probe result', 'dca probe list');
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('dca probe send', 3, 'Syntax: .dca probe send $character $requestJson\nSends a read-only probe to the DC-LabProbe addon of an online character whose account is listed in DC.LabProbe.Accounts and prints the request id. Example: .dca probe send Labby {"cmd":"frame","names":["PlayerFrame"]}. Commands: ping, state, frame, tooltip, auras, target, cvars, addons, errors.'),
('dca probe result', 3, 'Syntax: .dca probe result $id\nPrints unknown, pending <received>/<total>, abandoned, or complete with the answer (base64 JSON on the console and over SOAP, the JSON itself in game).'),
('dca probe list', 3, 'Syntax: .dca probe list\nLists the probe requests the worldserver still keeps, newest first.');
