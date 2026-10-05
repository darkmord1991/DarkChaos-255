-- Isles of Giants temple follow-up: clickable basement portals, shortcut portals removed, creatures at island
-- strength. Run after rev_1791031658174280700 and rev_1791034880368661900 (archived in worlddb/GiantIsles).
-- Deleting from gameobject_template is intended (custom ids only).

-- 1. Portal to the Temple Entrance: a spellcaster needs a spell before the client lets anyone click it.
--    64446 'Teleport Visual Only' is an instant self-cast dummy; the SmartAI teleport still moves the player.
UPDATE `gameobject_template` SET `Data0` = 64446 WHERE `entry` = 700017;

-- 2. The War Drum hall portal and its partner in the dungeon: the temple's own swirls (area triggers 6963/6964)
--    are the way in and out now.
DELETE FROM `gameobject` WHERE `guid` IN (9005420, 9005421) AND `id` IN (700032, 700033);
DELETE FROM `smart_scripts` WHERE `source_type` = 1 AND `entryorguid` IN (700032, 700033);
DELETE FROM `gameobject_template` WHERE `entry` IN (700032, 700033);

-- 3. Health and damage in line with the island: dungeon copy health x12 (non-elite) / x7.5 (elite), damage 5 / 10 /
--    12 (named) / 14 (bosses); island temple matched to the Zandalari trolls, raptors and rare elite Krag'zul.
UPDATE `creature_template` SET `minlevel` = 79, `maxlevel` = 80, `HealthModifier` = 30, `ManaModifier` = 1, `DamageModifier` = 10 WHERE `entry` IN (400500, 400503, 400532, 400533, 400538, 400549);
UPDATE `creature_template` SET `minlevel` = 79, `maxlevel` = 80, `HealthModifier` = 30, `ManaModifier` = 5, `DamageModifier` = 10 WHERE `entry` IN (400501, 400539);
UPDATE `creature_template` SET `minlevel` = 80, `maxlevel` = 80, `HealthModifier` = 30, `ManaModifier` = 5, `DamageModifier` = 10 WHERE `entry` IN (400502, 400535, 400537, 400551);
UPDATE `creature_template` SET `minlevel` = 80, `maxlevel` = 80, `HealthModifier` = 30, `ManaModifier` = 1, `DamageModifier` = 10 WHERE `entry` IN (400504, 400536, 400553);
UPDATE `creature_template` SET `minlevel` = 79, `maxlevel` = 79, `HealthModifier` = 12, `ManaModifier` = 1, `DamageModifier` = 5 WHERE `entry` IN (400505, 400547, 400548, 400552, 400555);
UPDATE `creature_template` SET `minlevel` = 81, `maxlevel` = 81, `HealthModifier` = 75, `ManaModifier` = 1, `DamageModifier` = 12 WHERE `entry` IN (400510, 400530, 400542, 400543, 400544, 400545);
UPDATE `creature_template` SET `minlevel` = 81, `maxlevel` = 81, `HealthModifier` = 75, `ManaModifier` = 5, `DamageModifier` = 12 WHERE `entry` IN (400511, 400512, 400541);
UPDATE `creature_template` SET `minlevel` = 81, `maxlevel` = 81, `HealthModifier` = 82.5, `ManaModifier` = 5, `DamageModifier` = 12 WHERE `entry` = 400513;
UPDATE `creature_template` SET `minlevel` = 82, `maxlevel` = 82, `HealthModifier` = 150, `ManaModifier` = 1, `DamageModifier` = 14 WHERE `entry` = 400520;
UPDATE `creature_template` SET `minlevel` = 82, `maxlevel` = 82, `HealthModifier` = 165, `ManaModifier` = 5, `DamageModifier` = 14 WHERE `entry` = 400521;
UPDATE `creature_template` SET `minlevel` = 82, `maxlevel` = 82, `HealthModifier` = 187.5, `ManaModifier` = 1, `DamageModifier` = 14 WHERE `entry` IN (400522, 400523);
UPDATE `creature_template` SET `minlevel` = 81, `maxlevel` = 81, `HealthModifier` = 90, `ManaModifier` = 1, `DamageModifier` = 12 WHERE `entry` = 400531;
UPDATE `creature_template` SET `minlevel` = 79, `maxlevel` = 79, `HealthModifier` = 12, `ManaModifier` = 5, `DamageModifier` = 5 WHERE `entry` = 400534;
UPDATE `creature_template` SET `minlevel` = 81, `maxlevel` = 81, `HealthModifier` = 60, `ManaModifier` = 1, `DamageModifier` = 10 WHERE `entry` = 400540;
UPDATE `creature_template` SET `minlevel` = 79, `maxlevel` = 79, `HealthModifier` = 6, `ManaModifier` = 1, `DamageModifier` = 5 WHERE `entry` IN (400546, 400556);
UPDATE `creature_template` SET `minlevel` = 80, `maxlevel` = 80, `HealthModifier` = 22.5, `ManaModifier` = 1, `DamageModifier` = 10 WHERE `entry` IN (400550, 400554);
UPDATE `creature_template` SET `minlevel` = 80, `maxlevel` = 80, `HealthModifier` = 1.2, `ManaModifier` = 1, `DamageModifier` = 5 WHERE `entry` = 400557;
UPDATE `creature_template` SET `minlevel` = 80, `maxlevel` = 80, `HealthModifier` = 6, `ManaModifier` = 1, `DamageModifier` = 5 WHERE `entry` = 400558;
UPDATE `creature_template` SET `minlevel` = 80, `maxlevel` = 80, `HealthModifier` = 24, `ManaModifier` = 1, `DamageModifier` = 5 WHERE `entry` = 400559;
UPDATE `creature_template` SET `minlevel` = 80, `maxlevel` = 80, `HealthModifier` = 18, `ManaModifier` = 1, `DamageModifier` = 5 WHERE `entry` = 400560;
UPDATE `creature_template` SET `minlevel` = 80, `maxlevel` = 80, `HealthModifier` = 12, `ManaModifier` = 1, `DamageModifier` = 5 WHERE `entry` = 400561;
UPDATE `creature_template` SET `minlevel` = 80, `maxlevel` = 81, `HealthModifier` = 12, `ManaModifier` = 1, `DamageModifier` = 5 WHERE `entry` IN (400562, 400563, 400564);
UPDATE `creature_template` SET `minlevel` = 80, `maxlevel` = 81, `HealthModifier` = 12, `ManaModifier` = 1, `DamageModifier` = 4 WHERE `entry` IN (400565, 400566);
UPDATE `creature_template` SET `minlevel` = 80, `maxlevel` = 81, `HealthModifier` = 14, `ManaModifier` = 1, `DamageModifier` = 4.5 WHERE `entry` = 400567;
UPDATE `creature_template` SET `minlevel` = 82, `maxlevel` = 82, `HealthModifier` = 70, `ManaModifier` = 1, `DamageModifier` = 12 WHERE `entry` IN (400568, 400569);
UPDATE `creature_template` SET `minlevel` = 81, `maxlevel` = 81, `HealthModifier` = 18, `ManaModifier` = 6, `DamageModifier` = 6 WHERE `entry` = 400570;
UPDATE `creature_template` SET `minlevel` = 80, `maxlevel` = 81, `HealthModifier` = 11, `ManaModifier` = 6, `DamageModifier` = 4.8 WHERE `entry` = 400571;

-- 4. Clients cache object templates for good: make them re-query (the portal spell changed).
UPDATE `version` SET `cache_id` = `cache_id` + 1;
