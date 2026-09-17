-- Hyjal Frontier off-hand codexes: display 62936 is the icon-only display of trinket 49686
-- (Maghia's Misguided Quill) and has no model, so the held off-hand rendered as an ErrorCube.
-- Repoint to stock off-hand book displays. Item.dbc carries the same values (the DBC wins at load).
UPDATE `item_template` SET `displayid` = 36268 WHERE `entry` = 400835; -- Hyjal Codex
UPDATE `item_template` SET `displayid` = 36267 WHERE `entry` = 400850; -- Skyfire Codex
UPDATE `item_template` SET `displayid` = 42092 WHERE `entry` = 400865; -- Summit Grimoire
UPDATE `item_template` SET `displayid` = 42564 WHERE `entry` = 400880; -- Nordrassil Tome
