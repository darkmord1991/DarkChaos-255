-- DarkChaos: two map-751 quest objects were unkillable, and Coldridge Pass had no graveyard.
--
-- Creeper Egg (4147203, 280 spawns) and Webbed Victim (4144941, the cocoons of "Lost in the Darkness", 27093) are
-- one-hit objects in Cata: level 1, HealthModifier 0.02381, flags_extra CANNOT_ENTER_COMBAT. The 751 import made
-- them level 134-138 mobs with 60-65k health. A creature that cannot enter combat regenerates as if idle (a third
-- of its health every regen tick), so ordinary damage never kills it: in meter run 3 (2026-11-15) 40 bots spent
-- 14 hours on eggs (one fight lasted 3.4 hours) and the cocoons could not be broken, by bots or by players.
--
-- Health goes back to a single point (GenerateHealth rounds up, so any modifier below 1 / base health gives 1).
-- They keep their level, so the kill now gives no experience (NO_XP), and the 751 gear-drop reference attached on
-- 2026-11-11 comes off: 280 one-hit eggs at 1.2% would be a gear farm. The cocoon's script still frees a sailor
-- or spawns a spider on death. The zone retune no longer manages them (tools/balance/gen_zone_tuning.py now skips
-- CANNOT_ENTER_COMBAT creatures), so their rows leave its backup table: "undo" must not restore 65k health.
UPDATE `creature_template` SET `HealthModifier` = 0.000001, `flags_extra` = `flags_extra` | 64, `lootid` = 0
WHERE `entry` IN (4147203, 4144941);

DELETE FROM `creature_loot_template` WHERE `Entry` IN (4147203, 4144941);

DELETE FROM `dc_balance_mob_tune_backup` WHERE `entry` IN (4147203, 4144941);

-- Coldridge Pass (zone 6006, the tunnel between Coldridge Valley and Kharanos) had no graveyard: a character who
-- died there got "graveyard_zone incomplete" and could not be sent to one. Link the two Dun Morogh graveyards at
-- either end, for both factions; the nearer one is used.
DELETE FROM `graveyard_zone` WHERE `GhostZone` = 6006 AND `ID` IN (100, 101);
INSERT INTO `graveyard_zone` (`ID`, `GhostZone`, `Faction`, `Comment`) VALUES
(100, 6006, 0, 'Dun Morogh, Anvilmar - Coldridge Pass'),
(101, 6006, 0, 'Dun Morogh, Kharanos - Coldridge Pass');
