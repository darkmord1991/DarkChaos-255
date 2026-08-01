-- ---------------------------------------------------------------------------
-- 197  Darkshore -- data foundation for the two remaining controller scripts
-- ---------------------------------------------------------------------------
-- Prerequisite for porting npc_coaxing_the_spirits_companions (quest 13547
-- "Coaxing the Spirits") and npc_offering_to_azshara_controller (quests 13897
-- "The Battle for Darkshore" / 13900 "The Offering to Azshara"). The C++ is NOT
-- included here -- see the note at the bottom.
--
-- WHAT WAS MISSING -- five creature templates. All five are quest-only NPCs
-- with no spawn of their own in cata_world, so 184_'s spawn-driven import never
-- saw them:
--     33002 Thundris Windweaver's Spirit
--     33034 Sentinel Elissa Starbreeze's Spirit
--     33036 Taldan's Spirit
--     33038 Caylais Moonfeather's Spirit          (the four "Coaxing" spirits)
--     34376 Kathrena Winterwisp
--     34416 Queen Azshara
-- The controllers' other actors already exist: 33001 Thundris Windweaver,
-- 33913 Shatterspear Hut Fire Bunny (48 spawns), 34415 Darkscale Priestess
-- (4 spawns) and 34422 Malfurion Stormrage.
--
-- creature_text again comes from `nelt_world`, NOT cata_world -- cata_world has
-- no rows for any of these. Same finding as the escorts in 191_: the Neltharion
-- scripts were written against Neltharion's own database.
--     34376 Kathrena Winterwisp  10 rows
--     34416 Queen Azshara         3 rows
--     34422 Malfurion Stormrage   3 rows
--     34415 Darkscale Priestess   1 row
-- The four spirits have no dialogue rows in either source, which is correct --
-- the Coaxing script drives them through emotes and spell visuals, not Talk().
--
-- Apply against acore_world AFTER 196_, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) The six missing creature templates
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` IN (
  3733002, 3733034, 3733036, 3733038, 3734376, 3734416);

INSERT INTO `creature_template`
    (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,
     `name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`faction`,`npcflag`,`speed_walk`,`speed_run`,
     `rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,
     `unit_flags2`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,
     `mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,
     `DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
SELECT s.`entry` + 3700000, 0, 0, 0,
       CASE WHEN s.`KillCredit1` > 0 THEN s.`KillCredit1` + 3700000 ELSE 0 END,
       CASE WHEN s.`KillCredit2` > 0 THEN s.`KillCredit2` + 3700000 ELSE 0 END,
       s.`name`, s.`subname`, s.`IconName`, s.`gossip_menu_id`, s.`minlevel`, s.`maxlevel`, s.`faction`,
       COALESCE(s.`npcflag`, 0), s.`speed_walk`, s.`speed_run`, s.`rank`, s.`dmgschool`,
       s.`BaseAttackTime`, s.`RangeAttackTime`, s.`BaseVariance`, s.`RangeVariance`, s.`unit_class`,
       COALESCE(s.`unit_flags`, 0), s.`unit_flags2`, s.`family`, s.`type`, s.`type_flags`,
       0, 0, 0, s.`PetSpellDataId`, s.`VehicleId`, s.`mingold`, s.`maxgold`, '', s.`MovementType`,
       s.`HoverHeight`, s.`HealthModifier`, s.`ManaModifier`, s.`ArmorModifier`, s.`DamageModifier`,
       s.`ExperienceModifier`, s.`RacialLeader`, s.`movementId`, s.`RegenHealth`, s.`flags_extra`, '', s.`VerifiedBuild`
FROM `cata_world`.`creature_template` s
WHERE s.`entry` IN (33002, 33034, 33036, 33038, 34376, 34416);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (
  3733002, 3733034, 3733036, 3733038, 3734376, 3734416);

INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT t.`entry` + 3700000, i.idx, m.model, 1, 1, t.`VerifiedBuild`
FROM `cata_world`.`creature_template` t
JOIN (SELECT 0 AS idx UNION SELECT 1 UNION SELECT 2 UNION SELECT 3) i
JOIN LATERAL (SELECT CASE i.idx WHEN 0 THEN t.`modelid1` WHEN 1 THEN t.`modelid2`
                                WHEN 2 THEN t.`modelid3` ELSE t.`modelid4` END AS model) m
WHERE t.`entry` IN (33002, 33034, 33036, 33038, 34376, 34416)
  AND m.model > 0;

-- ---------------------------------------------------------------------------
-- B) creature_text for the controllers' speaking actors (source: nelt_world)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` IN (3734376, 3734415, 3734416, 3734422);

INSERT INTO `creature_text`
    (`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,
     `BroadcastTextId`,`TextRange`,`comment`)
SELECT t.`entry` + 3700000, t.`groupid`, t.`id`, t.`text`, t.`type`, t.`language`, t.`probability`,
       t.`emote`, t.`duration`, t.`sound`, t.`BroadcastTextID`, t.`text_range`, t.`comment`
FROM `nelt_world`.`creature_text` t
WHERE t.`entry` IN (34376, 34415, 34416, 34422);

-- ---------------------------------------------------------------------------
-- C) Wire the Coaxing the Spirits companions
-- ---------------------------------------------------------------------------
-- Ported into DC/MountHyjal/zone_darkshore_cata.cpp as one AI shared by all
-- four spirits -- they differ only in the angle they follow the player at, so
-- the original's four copy-pasted branches became a table.
--
-- TWO DEFECTS were fixed on the way in, both real rather than cosmetic:
--   * the original called me->GetOwner()->isAlive() with NO null check, every
--     second -- a summon whose owner logged out would crash the worldserver;
--   * it despawned the spirit unless GetZoneId() == 148 (Darkshore on map 1).
--     On map 750 the zone is 4929, so every spirit would have vanished one
--     second after being summoned. The port accepts BOTH ids -- the same
--     belt-and-braces the existing Hyjal port uses with DC_HYJAL_AREAID, which
--     is the established answer to this hazard class.
-- ---------------------------------------------------------------------------
UPDATE `creature_template` SET `ScriptName` = 'npc_coaxing_the_spirits_companion'
WHERE `entry` IN (3733002, 3733034, 3733036, 3733038);

-- ---------------------------------------------------------------------------
-- D) The Offering to Azshara event controller
-- ---------------------------------------------------------------------------
-- The script does NOT hang off any of the visible actors -- it lives on an
-- invisible trigger, entry 74937 "Wondi's Bunny - The Offering to Azshara -
-- Event Controller". That entry is a NELTHARION INVENTION: it does not exist in
-- cata_world at all, which is why the zone imports never brought it across.
-- Found by querying nelt_world.creature_template for the ScriptName rather than
-- guessing from the script's enum block -- the enum only names the actors it
-- summons (34415 / 34416 / 34422), none of which is the controller.
--
-- nelt_world uses the older MaNGOS column names (faction_A / faction_H instead
-- of faction, no BaseVariance, etc.), so the row is written out explicitly
-- rather than INSERT...SELECT'd. Values are nelt's verbatim: model 16480
-- (invisible), faction 35, flags_extra 128 (TRIGGER), level 85, InhabitType 4.
--
-- Its one spawn sits at (4591.88, 896.03, 41.42) -- in the middle of the four
-- priestess positions the script summons at, so the 50-yard trigger radius
-- covers the whole scene. Coordinates are copied unchanged; map 750 preserves
-- Kalimdor coordinates. Guid 15950001 (block verified empty).
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` = 3774937;

INSERT INTO `creature_template`
    (`entry`,`name`,`subname`,`minlevel`,`maxlevel`,`faction`,`npcflag`,`speed_walk`,`speed_run`,
     `unit_class`,`unit_flags`,`type`,`rank`,`RegenHealth`,`flags_extra`,`AIName`,`MovementType`,
     `ScriptName`,`VerifiedBuild`)
VALUES
(3774937, 'Wondi''s Bunny - The Offering to Azshara - Event Controller', '', 85, 85, 35, 0, 1, 1.14286,
 1, 0, 7, 0, 1, 128, '', 0, 'npc_offering_to_azshara_controller', 0);

DELETE FROM `creature_template_model` WHERE `CreatureID` = 3774937;

INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
(3774937, 0, 16480, 1, 1, 0);

DELETE FROM `creature` WHERE `guid` = 15950001;

INSERT INTO `creature`
    (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,
     `position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,
     `currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`ScriptName`,`VerifiedBuild`,`Comment`)
VALUES
(15950001, 3774937, 750, 0, 0, 1, 1, 0, 4591.88, 896.03, 41.42, 5.585, 300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Darkshore-Cata');

-- ---------------------------------------------------------------------------
-- Both controllers are now ported and wired. Neither needed the map-750 area
-- remap that 196_ documents for the vehicle: the Azshara controller has no
-- area/zone constant and casts no spells, and the Coaxing companions' zone
-- check was fixed in the port (section C).
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Verification after applying + restart:
--   SELECT entry, name FROM creature_template
--    WHERE entry IN (3733002,3733034,3733036,3733038,3734376,3734416);   -- 6 rows
--   SELECT CreatureID, COUNT(*) FROM creature_text
--    WHERE CreatureID IN (3734376,3734415,3734416,3734422) GROUP BY CreatureID;
--     -- 3734376 -> 10, 3734415 -> 1, 3734416 -> 3, 3734422 -> 3
--   -- every one of the six has a model (expect 0):
--   SELECT COUNT(*) FROM creature_template t
--    WHERE t.entry IN (3733002,3733034,3733036,3733038,3734376,3734416)
--      AND NOT EXISTS (SELECT 1 FROM creature_template_model m WHERE m.CreatureID = t.entry);
-- ---------------------------------------------------------------------------
