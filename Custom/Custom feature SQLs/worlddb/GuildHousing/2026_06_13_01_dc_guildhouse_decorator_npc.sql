-- Dark Chaos Guild Housing - Decorator NPC
-- Gossip catalog browser for the player-facing decoration system
-- (GuildHousing/dc_guildhouse_decorations.cpp, script npc_guildhouse_decorator).
-- Uses the post-drift creature_template schema (no scale/immune-mask columns).

DELETE FROM `creature_template` WHERE `entry` = 95105;
INSERT INTO `creature_template`
    (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`,
     `npcflag`, `unit_class`, `unit_flags`, `type`, `ScriptName`,
     `VerifiedBuild`)
VALUES
    (95105, 'Guild House Decorator', 'Furnishings & Decor', 80, 80, 35,
     1, 1, 768, 7, 'npc_guildhouse_decorator', 12340);

DELETE FROM `creature_template_model` WHERE `CreatureID` = 95105;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`,
     `VerifiedBuild`)
VALUES
    (95105, 0, 26305, 1, 1, 0);

-- Default spawn position inside the guild house plot (GM Island layout,
-- next to the Butler) so the existing spawn system can place it.
DELETE FROM `dc_guild_house_spawns` WHERE `entry` = 95105;
INSERT INTO `dc_guild_house_spawns` (`entry`, `posX`, `posY`, `posZ`, `orientation`)
VALUES
    (95105, 16227.422, 16283.675, 13.175704, 3.036652);
