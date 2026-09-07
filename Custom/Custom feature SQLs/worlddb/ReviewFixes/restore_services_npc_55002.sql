-- Restore creature_template 55002 "Services NPC". Target: acore_world.
--
-- THE PROBLEM
-- -----------
-- The template row was deleted at some point; everything that referenced it was left behind. The
-- worldserver reports this at every startup (Errors.log):
--
--     Creature template (Entry: 55002) does not exist but has a record in `creature_template_model`
--     Table `creature` has creature (SpawnId: 3111684) with non existing creature entry 55002 ... skipped.
--     ... x26
--
-- so 26 spawns silently do not exist in the world:
--
--     map   37 Azshara Crater (onboarding hub) .. 11   <-- incl. the level 50+ flight camp
--     map 1411 HLBG ............................  3
--     map  745 Jade Forest .....................  3
--     map 1412 HLBG ............................  3
--     map 1405 / 1409 / 1413 / 750 / 0 / 1 ......  1 each
--
-- It is also offered by the guild house butler, which spawns it on request and charges for it:
--   src/server/scripts/DC/GuildHousing/dc_guildhouse_butler.cpp:689 / :795
--   dc_guild_house_spawns id 84 ("Services NPC")
--
-- THE ROW
-- -------
-- Recovered verbatim from acore_backup.creature_template, which still has it. Not reconstructed --
-- creature_template is schema-identical between acore_backup and acore_world (55/55 columns, 0
-- differences), so this is the original definition.
--
-- Its ScriptName is `mod_npc_services`, registered by modules/mod-npc-services
-- (src/npc_services.h:15) and confirmed present in the deployed worldserver.exe, so the NPC comes
-- back fully functional rather than as a mute gossip stub.
--
-- creature_template_model (CreatureID 55002, DisplayID 31833) is still in place and becomes valid
-- again as soon as the template exists -- nothing to re-insert there.

DELETE FROM `creature_template` WHERE `entry` = 55002;
INSERT INTO `creature_template`
(`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`,
 `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`,
 `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`,
 `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`,
 `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`,
 `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`,
 `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`,
 `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
VALUES
(55002, 0, 0, 0, 0, 0,
 'Services NPC', 'AzerothCore', NULL, 0, 80, 80, 2, 35, 1,
 1, 1.14286, 1, 1, 20, 1, 0,
 1, 2000, 2000, 1, 1, 2,
 0, 2048, 0, 0, 7, 0, 0, 0,
 0, 0, 0, 0, 0, '', 0, 1,
 50, 50, 1, 1, 0, 0,
 1, 0, 0, 'mod_npc_services', NULL);

-- ---------------------------------------------------------------------------
-- VERIFY after restart -- the "does not exist" and "skipped" lines above should be gone from
-- Errors.log, and this should return 26:
--   SELECT COUNT(*) FROM `creature` c JOIN `creature_template` ct ON ct.entry = c.id WHERE c.id = 55002;
-- ---------------------------------------------------------------------------
