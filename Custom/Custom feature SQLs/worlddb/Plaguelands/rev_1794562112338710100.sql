-- DarkChaos: Tyr's Hand on map 751 becomes a normal-mob quest hub, as in Cata (owner's decision 2026-11-13)
--
-- Every objective of the Cata Tyr's Hand quests (27460, 27613-27616, 27619, 27620; MinLevel 150) sits inside the
-- Scarlet garrison, which came over from the classic elite area: 162 level-160 ELITE spawns of six types (8x
-- health), plus High General Abbendis (rare elite, 5 yd from the 27620 target), a second Crusader Lord Valdelmar
-- and two Scarlet Inquisitors. In Cata the six types are normal mobs of level 41-43, and the three named ones are
-- not spawned at all. On 11-13 bots took these quests 20-40 times each and finished none; solo players at 150-158
-- could not do them either.
--
-- The six types become normal mobs at 153-155 (Cata 41-43 on 751's 40-48 -> 152-158 band). Abbendis becomes a rare
-- (her Cata rank) at 155, Valdelmar and the Inquisitors normal at 155. Health and damage follow 751's 332_ model, the
-- same as the quest targets already standing there: a same-level player's health (13134 + (L-80)*515) times 2.5
-- (rare 5), and 4.5% of it per average swing (rare 6%), exp 2. Their map-751 gear drop moves from the level-156
-- band at the elite chance (752218, 6%; Abbendis 35%) to the level-152 band at the normal one (752216, 1.2%;
-- rare 20%).
-- All nine entries spawn only on map 751; the UPDATEs re-check that.
--
-- Apply after rev_1794561649674195800.sql (KillCredit for 27460). Re-running gives the same result. Apply to
-- acore_world, then restart the worldserver.
-- Revert values (before this file): minlevel = maxlevel = 160; rank 1 for all but Abbendis (2);
--   HealthModifier/DamageModifier:
--   3609447 17.1263/0.7845; 3609448 17.1263/0.7845; 3609449 17.1263/0.7845;
--   3609450 17.1263/0.7845; 3609451 15.5578/0.7858; 3609452 15.5578/0.7858;
--   3610828 9.11528/1.91761; 3611898 5/1.30746; 3615162 2.91689/1.33356.

-- Scarlet Warder
UPDATE `creature_template` SET `minlevel` = 153, `maxlevel` = 154, `rank` = 0, `exp` = 2, `HealthModifier` = 0.9106,
    `DamageModifier` = 0.778 WHERE `entry` = 3609447
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Scarlet Praetorian
UPDATE `creature_template` SET `minlevel` = 154, `maxlevel` = 155, `rank` = 0, `exp` = 2, `HealthModifier` = 0.9107,
    `DamageModifier` = 0.779 WHERE `entry` = 3609448
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Scarlet Cleric
UPDATE `creature_template` SET `minlevel` = 153, `maxlevel` = 154, `rank` = 0, `exp` = 2, `HealthModifier` = 0.9106,
    `DamageModifier` = 0.778 WHERE `entry` = 3609449
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Scarlet Curate
UPDATE `creature_template` SET `minlevel` = 154, `maxlevel` = 155, `rank` = 0, `exp` = 2, `HealthModifier` = 0.9107,
    `DamageModifier` = 0.779 WHERE `entry` = 3609450
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Scarlet Archmage
UPDATE `creature_template` SET `minlevel` = 154, `maxlevel` = 155, `rank` = 0, `exp` = 2, `HealthModifier` = 1.1367,
    `DamageModifier` = 0.7818 WHERE `entry` = 3609451
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Scarlet Enchanter
UPDATE `creature_template` SET `minlevel` = 153, `maxlevel` = 154, `rank` = 0, `exp` = 2, `HealthModifier` = 1.1365,
    `DamageModifier` = 0.7811 WHERE `entry` = 3609452
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- High General Abbendis
UPDATE `creature_template` SET `minlevel` = 155, `maxlevel` = 155, `rank` = 4, `exp` = 2, `HealthModifier` = 1.8217,
    `DamageModifier` = 1.0399 WHERE `entry` = 3610828
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Crusader Lord Valdelmar
UPDATE `creature_template` SET `minlevel` = 155, `maxlevel` = 155, `rank` = 0, `exp` = 2, `HealthModifier` = 0.9109,
    `DamageModifier` = 0.7799 WHERE `entry` = 3611898
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);
-- Scarlet Inquisitor
UPDATE `creature_template` SET `minlevel` = 155, `maxlevel` = 155, `rank` = 0, `exp` = 2, `HealthModifier` = 0.9109,
    `DamageModifier` = 0.7951 WHERE `entry` = 3615162
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751);

-- gear drops: the level-152 band at the rank's chance
UPDATE `creature_loot_template` SET `Reference` = 752216, `Chance` = 1.2
WHERE `Entry` IN (3609447, 3609448, 3609449, 3609450, 3609451, 3609452, 3611898, 3615162) AND `Reference` = 752218;
UPDATE `creature_loot_template` SET `Reference` = 752216, `Chance` = 20
WHERE `Entry` = 3610828 AND `Reference` = 752218;
