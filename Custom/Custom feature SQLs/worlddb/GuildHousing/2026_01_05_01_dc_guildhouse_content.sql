-- Dark Chaos Guild Housing - Phase 3 Content
-- Currency & NPCs

-- 1. Guild Construction Token (REMOVED - Use Standard Seasonal Token 300006)

-- 2. New Guild House Vendors
-- IDs: 95100-95104
DELETE FROM `creature_template` WHERE `entry` BETWEEN 95100 AND 95104;
DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 95100 AND 95104;

INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
-- Seasonal Rotating Trader
(95100, 0, 0, 0, 0, 0, 'Seasonal Trader', 'Limited Time Goods', NULL, 0, 80, 80, 0, 35, 128, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 'GuildHouseSeasonalTrader', 1656),
-- Holiday Ambassador
(95101, 0, 0, 0, 0, 0, 'Holiday Ambassador', 'Festive Decorations', NULL, 0, 80, 80, 0, 35, 128, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 'GuildHouseHolidayAmbassador', 1656),
-- Omni-Crafter (Trade Goods)
(95102, 0, 0, 0, 0, 0, 'Omni-Crafter', 'Trade Supplies', NULL, 0, 80, 80, 0, 35, 128, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, '', 1656),
-- Guild House Manager (Buy/Move/Reset/Delete)
(95103, 0, 0, 0, 0, 0, 'Guild House Manager', 'Guild Housing', NULL, 0, 80, 80, 0, 35, 1, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 'GuildHouseSeller', 1656),
-- Guild House Butler (spawner)
(95104, 0, 0, 0, 0, 0, 'Guild House Butler', 'Upgrades & Services', NULL, 0, 80, 80, 0, 35, 1, 1, 1.14286, 1, 1, 20, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 768, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 'GuildHouseSpawner', 1656);

-- Models
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(95100, 0, 15693, 1, 1, 0), -- Seasonal Trader
(95101, 0, 15693, 1, 1, 0), -- Holiday Ambassador
(95102, 0, 28693, 1, 1, 0), -- Omni-Crafter
(95103, 0, 26305, 1, 1, 0), -- Guild House Manager
(95104, 0, 26305, 1, 1, 0); -- Guild House Butler

-- 3. Spawn Coordinates (GM Island Defaults)
DELETE FROM `dc_guild_house_spawns` WHERE `entry` BETWEEN 95100 AND 95104;
DELETE FROM `dc_guild_house_spawns` WHERE `entry` = 55002;
INSERT INTO `dc_guild_house_spawns` (`entry`, `posX`, `posY`, `posZ`, `orientation`) VALUES
(95100, 16216.0, 16260.0, 21.0, 1.5), -- Seasonal Trader
(95101, 16218.0, 16260.0, 21.0, 1.5), -- Holiday Ambassador
(95102, 16220.0, 16260.0, 21.0, 1.5), -- Omni-Crafter
(95103, 16222.0, 16260.0, 21.0, 1.5), -- Guild House Manager
(95104, 16229.422, 16283.675, 13.175704, 3.036652), -- Guild House Butler
(55002, 16222.0, 16260.0, 21.0, 1.5); -- Services NPC
