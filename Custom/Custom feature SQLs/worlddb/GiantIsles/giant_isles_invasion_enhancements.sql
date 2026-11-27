-- ============================================================================
-- GIANT ISLES - Invasion enhancements (consolidated, idempotent)
-- ----------------------------------------------------------------------------
-- Single-file apply for everything the invasion enhancement work added/changed:
--   * War-beasts          400361 / 400362 / 400363
--   * Loa Effigy          400364   (wave-3 ritual objective)
--   * War Quartermaster   400365   (+ item 400456 + npc_text + spawn 9000301)
--   * War Standard        400366   (lane objective)
--   * Honor Guard model   400337 -> display 15210 (distinct gold elite)
--   * Invader weapon rework (creature_equip_template 400326-400337)
-- Safe to re-run: every INSERT is preceded by a matching DELETE.
-- Base invasion NPCs (400325-400360) live in giant_isles_creatures.sql.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- New creature templates (war-beasts, Loa effigy, quartermaster, war standard)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` IN (400361, 400362, 400363, 400364, 400365, 400366);
INSERT INTO `creature_template`
(`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(400361, 0, 0, 0, 400339, 0, 'Zandalari War-Direhorn', 'Primal Charger', '', 0, 81, 81, 2, 16, 0, 1.4, 1.6, 1, 1, 20, 1, 0, 6, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 1, 0, 0, 0, 0, 0, 0, 400, 700, '', 0, 1, 30, 1, 3, 4, 0, 0, 1, 0, 0, 'npc_invasion_mob', 12340),
(400362, 0, 0, 0, 400339, 0, 'Zandalari Pterrordax Bomber', 'Skyborne Terror', '', 0, 80, 80, 2, 16, 0, 1.4, 1.5, 1, 1, 20, 0, 0, 5, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 1, 0, 0, 0, 0, 0, 0, 300, 600, '', 0, 1, 12, 1, 1, 4, 0, 0, 1, 0, 0, 'npc_invasion_mob', 12340),
(400363, 0, 0, 0, 400339, 0, 'Primal Devilsaur', 'Zandalari Siege-Beast', '', 0, 82, 82, 2, 16, 0, 1.6, 1.7, 1, 1, 25, 2, 0, 10, 2000, 2000, 1, 1, 1, 0, 2048, 8, 0, 1, 0, 0, 0, 0, 0, 0, 1500, 2500, '', 0, 1, 80, 1, 4, 12, 0, 0, 1, 0, 0, 'npc_invasion_mob', 12340),
(400364, 0, 0, 0, 0, 0, 'Loa Effigy', 'Zandalari Ritual', '', 0, 82, 82, 2, 16, 0, 1, 1, 1, 1, 5, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 80, 1, 2, 1, 0, 0, 0, 0, 0, '', 12340),
(400365, 0, 0, 0, 0, 0, 'War Quartermaster', 'Seeping Shores Defense', '', 0, 80, 80, 2, 35, 1, 1, 1, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 20, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_giant_isles_war_quartermaster', 12340),
(400366, 0, 0, 0, 0, 0, 'Zandalari War Standard', 'Longboat Mooring', '', 0, 81, 81, 2, 16, 0, 1, 1, 1, 1, 5, 0, 0, 1, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 35, 1, 2, 1, 0, 0, 0, 0, 0, '', 12340);

-- ---------------------------------------------------------------------------
-- Models for the new creatures + the reworked Honor Guard (400337 -> 15210)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (400361, 400362, 400363, 400364, 400365, 400366, 400337);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(400361, 0, 5305, 1.2, 1, 12340),   -- War-Direhorn
(400362, 0, 8412, 1.0, 1, 12340),   -- Pterrordax Bomber
(400363, 0, 5240, 1.3, 1, 12340),   -- Primal Devilsaur
(400364, 0, 16997, 1.8, 1, 12340),  -- Loa Effigy (carved totem pole)
(400365, 0, 23072, 1.0, 1, 12340),  -- War Quartermaster (Northrend officer)
(400366, 0, 14542, 1.0, 1, 12340),  -- War Standard (battle banner)
(400337, 0, 15210, 1.2, 1, 12340);  -- Honor Guard (Zandalarian Emissary, gold elite)

-- ---------------------------------------------------------------------------
-- Invader weapon rework - tribal "Monster -" loadout, no 2H+shield conflicts
-- ---------------------------------------------------------------------------
DELETE FROM `creature_equip_template` WHERE `CreatureID` IN (400326, 400327, 400328, 400329, 400330, 400331, 400332, 400333, 400334, 400336, 400337) AND `ID` = 1;
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(400326, 1, 14877, 1985, 0, 12340),   -- Invader - spiked axe + large wooden shield
(400327, 1, 11763, 0, 2506, 12340),   -- Scout - hatchet + bow
(400328, 1, 6680, 0, 0, 12340),       -- Spearman - tribal spear (polearm)
(400329, 1, 18419, 0, 0, 12340),      -- Warrior - 2H Horde war axe
(400330, 1, 5598, 5598, 0, 12340),    -- Berserker - dual troll glaives
(400331, 1, 5598, 0, 2506, 12340),    -- Shadow Hunter - glaive + bow
(400332, 1, 14877, 11589, 0, 12340),  -- Blood Guard - spiked axe + skull shield
(400333, 1, 13720, 0, 0, 12340),      -- Witch Doctor - feathered voodoo staff
(400334, 1, 14877, 0, 2506, 12340),   -- Beast Tamer - axe + bow
(400336, 1, 14870, 0, 0, 12340),      -- Warlord Zul'mar - massive spiked 2H war axe
(400337, 1, 14876, 23356, 0, 12340);  -- Honor Guard - crystal-blade axe + skullflame shield

-- ---------------------------------------------------------------------------
-- War economy: currency item, quartermaster gossip text, quartermaster spawn
-- ---------------------------------------------------------------------------
DELETE FROM `item_template` WHERE `entry` IN (400456);
INSERT INTO `item_template`
(`entry`, `class`, `subclass`, `name`, `displayid`, `Quality`, `Flags`, `BuyCount`, `BuyPrice`, `SellPrice`, `bonding`, `MaxCount`, `stackable`, `Material`, `description`) VALUES
(400456, 10, 0, 'Zandalari War-Token', 55045, 3, 0, 1, 0, 0, 1, 0, 2147483647, -1, 'Awarded for defending Seeping Shores against the Zandalari invasion. Spend it with the War Quartermaster.');

DELETE FROM `npc_text` WHERE `ID` IN (400365);
INSERT INTO `npc_text` (`ID`, `text0_0`, `Probability0`) VALUES
(400365, 'Stand fast, soldier. The Zandalari will break upon this shore. Bring me the War-Tokens you earn defending the beach and I will see you well supplied.', 1);

DELETE FROM `creature` WHERE `guid` IN (9000301);
INSERT INTO `creature` (`guid`, `id1`, `id2`, `id3`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
(9000301, 400365, 0, 0, 1405, 0, 0, 1, 1, 0, 5768.0, 1296.0, 12.4, 4.9, 300, 0, 0, 100, 0, 0, 0, 0, 0, '', NULL, 0, 'Giant Isles - War Quartermaster');
