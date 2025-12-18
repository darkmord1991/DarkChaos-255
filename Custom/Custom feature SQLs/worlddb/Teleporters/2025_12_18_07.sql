RENAME TABLE `eluna_teleporter` TO `DC_teleporter`;

ALTER TABLE `DC_teleporter`
    ADD COLUMN `security_level` INT DEFAULT 0 AFTER `faction`,
    ADD COLUMN `comment` TEXT AFTER `security_level`;

UPDATE `creature_template` SET `ScriptName` = 'dc_teleporter_creature_script' WHERE `entry` IN (800002, 33274);
