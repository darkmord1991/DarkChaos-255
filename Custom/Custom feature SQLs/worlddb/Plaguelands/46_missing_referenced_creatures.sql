-- =====================================================================
-- Plaguelands (DCPlaguelands, map 751)  --  46  Missing referenced creatures
-- ---------------------------------------------------------------------
-- 01_creature_templates.sql discovers what to clone by joining
-- cata_world.creature (static spawns) against zoneId IN (139,28). That
-- misses NPCs that only ever appear dynamically (raid/quest bosses
-- summoned by SmartAI, escort/event actors with no static spawn row).
-- 34 such dc_entry (=raw+3,600,000) ids are referenced by
-- smart_scripts.entryorguid but have no creature_template row at all.
--
-- Split by source, same as 01:
--   A) 28 are pre-existing stock 3.3.5 NPCs (Scarlet Crusade / Scourge
--      raid bosses, Midsummer event NPCs, etc.) -- clone straight from
--      acore_world's own stock row, same as 01's "Stock-AC templates"
--      branch. Zero model risk: same display already loaded.
--   B) 4 are Cata-new NPCs -- clone from cata_world, same as 01's
--      "Cata-new templates" branch. Display ids verified already
--      staged in Custom/CSV DBC/CreatureDisplayInfo.csv (34231-34233
--      Forsaken Trooper, 11686 Into the Flames Credit, 7846 Regurgitated
--      Bones, 24301 Julak-Doom) so no additional retroport needed.
--   Not included here (see 00_README/commit notes):
--     - 50009 "Mobus" (cata_world) -- display 37338 NOT YET staged in
--       CreatureDisplayInfo.csv, needs the retroport_tools pipeline
--       first (K:\Dark-Chaos\retroport_tools). Import once that lands.
--     - 56049 "Tony Bachk" (nelt_world) -- source row looks like
--       leftover test/junk data (mojibake subname, gossip_menu_id ==
--       entry, implausible Health_mod/Mana_mod). NOT imported. The
--       lone orphan smart_scripts row for it is removed below; drop
--       that DELETE if this was actually intended content.
-- =====================================================================

SET @OFF := 3600000;

-- A) Stock-AC templates (clone from acore_world, 3.3.5 stats)
INSERT IGNORE INTO acore_world.creature_template (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT `entry`+@OFF, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`
    FROM acore_world.creature_template
    WHERE `entry` IN (1783,1794,1850,8477,8607,10824,10825,10827,10828,10936,10940,11286,11878,11885,11898,12261,12322,15566,15592,15602,16184,16781,26401,44487,44488,44489,45239,46096);

INSERT IGNORE INTO acore_world.creature_template_model (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT `CreatureID`+@OFF, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`
    FROM acore_world.creature_template_model
    WHERE `CreatureID` IN (1783,1794,1850,8477,8607,10824,10825,10827,10828,10936,10940,11286,11878,11885,11898,12261,12322,15566,15592,15602,16184,16781,26401,44487,44488,44489,45239,46096);

INSERT IGNORE INTO acore_world.creature_template_addon (`entry`, `mount`, `emote`, `visibilityDistanceType`, `auras`)
SELECT `entry`+@OFF, `mount`, `emote`, `visibilityDistanceType`, `auras`
    FROM acore_world.creature_template_addon
    WHERE `entry` IN (1783,1794,1850,8477,8607,10824,10825,10827,10828,10936,10940,11286,11878,11885,11898,12261,12322,15566,15592,15602,16184,16781,26401,44487,44488,44489,45239,46096);

-- B) Cata-new templates (clone from cata_world, col intersection)
INSERT IGNORE INTO acore_world.creature_template (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT `entry`+@OFF, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild`
    FROM cata_world.creature_template
    WHERE `entry` IN (45085, 45738, 48718, 50089) AND `entry` NOT IN (SELECT entry FROM acore_world.creature_template WHERE entry < @OFF);

INSERT IGNORE INTO acore_world.creature_template_model (`CreatureID`, `Idx`, `CreatureDisplayID`, `Probability`, `VerifiedBuild`)
SELECT `CreatureID`+@OFF, `Idx`, `CreatureDisplayID`, `Probability`, `VerifiedBuild`
    FROM cata_world.creature_template_model
    WHERE `CreatureID` IN (45085, 45738, 48718, 50089);

INSERT IGNORE INTO acore_world.creature_template_addon (`entry`, `mount`, `emote`, `visibilityDistanceType`, `auras`)
SELECT `entry`+@OFF, `mount`, `emote`, `visibilityDistanceType`, `auras`
    FROM cata_world.creature_template_addon
    WHERE `entry` IN (45085, 45738, 48718, 50089);

-- Orphan junk row (see header) -- comment out this DELETE if 56049 was intended content
DELETE FROM acore_world.smart_scripts WHERE entryorguid = 3656049 AND source_type = 0;
