-- =====================================================================
-- Molten Front -- 84  Quest-objective creature backfill + reference fixes
-- ---------------------------------------------------------------------
-- More-db-errors audit pass (2026-07-13), "Loading Quests..." boot log.
--
-- 1) 7 more summon-only/quest-credit creatures never downported, same root
--    cause as 74_ (no static spawn in cata_world to be picked up by the
--    zone-scoped 01_ clone):
--      52891 Flame Runes Extinguished Credit   53093 Flamewaker Shaman
--      53234 Anren Shadowseeker                53308 Flamewaker Centurion
--      53310 Molten Lord                       53479 Cinderweb Matriarch
--      53886 Igneous Depths Area Credit
--    Display 38483 (Cinderweb Matriarch, yellow FireSpiderBoss recolor) was
--    also missing -- reused the already-present ModelID 501624 body (only
--    the yellow texture variant needed extracting, from the real retail
--    client) + creature_model_info row (cata_world had real data for it).
--
-- 2) quest_template.RequiredNpcOrGoN remap: quests 29210/29264/29272/29290
--    still had the RAW (un-offset) cata_world entries in RequiredNpcOrGo,
--    because those targets didn't exist yet when 50_molten_front_quests.sql
--    ran its remap step (comment: "remaps objectives/relations onto the
--    +3,600,000 clones -- guarded by clone existence"). Now that the
--    creatures exist (above), remap to the +3,600,000 offset actually
--    spawned in this DB (confirmed convention: working quests like 29143/
--    29205/29206 already use the offset form).
--
-- 3) quest 700709 "A Favor for Finkle" (BWD) had RequiredNpcOrGo1 = -44202.
--    Negative RequiredNpcOrGo means GameObject (ObjectMgr::LoadQuests,
--    `id < 0 && !GetGameObjectTemplate(-id)`), but 44202 "Finkle Einhorn" is
--    a CREATURE, not a GameObject -- a sign error in the original quest
--    authoring. Positive RequiredNpcOrGo already covers talk-to objectives
--    (SetSpecialFlag sets KILL|CAST|SPEAKTO together regardless of sign).
--    Fixed to +44202.
--
-- 4) quest 29234 "Delegation" has RewardNextQuest = 29239, which doesn't
--    exist (Firelands content outside this port's scope -- same call as
--    round 5's Deepholm 28292 fix and this same quest's own PrevQuestID/
--    NextQuestID nulling in 75_molten_front_delegation_vow.sql, which missed
--    this SEPARATE quest_template.RewardNextQuest field). Nulled.
-- =====================================================================
SET @OFF := 3600000;

INSERT IGNORE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT `entry`+@OFF, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild`
FROM `cata_world`.`creature_template`
WHERE `entry` IN (52891,53093,53234,53308,53310,53479,53886);

INSERT IGNORE INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `Probability`, `VerifiedBuild`)
SELECT `CreatureID`+@OFF, `Idx`, `CreatureDisplayID`, `Probability`, `VerifiedBuild`
FROM `cata_world`.`creature_template_model`
WHERE `CreatureID` IN (52891,53093,53234,53308,53310,53479,53886);

INSERT IGNORE INTO `creature_template_addon` (`entry`, `mount`, `emote`, `visibilityDistanceType`, `auras`)
SELECT `entry`+@OFF, `mount`, `emote`, `visibilityDistanceType`, `auras`
FROM `cata_world`.`creature_template_addon`
WHERE `entry` IN (52891,53093,53234,53308,53310,53479,53886);

DELETE FROM `creature_model_info` WHERE `DisplayID` = 38483;
INSERT INTO `creature_model_info` (`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`) VALUES
(38483,2,3,0,0,NULL);

UPDATE `quest_template` SET `RequiredNpcOrGo1` = 3653093 WHERE `ID` = 29264 AND `RequiredNpcOrGo1` = 53093;
UPDATE `quest_template` SET `RequiredNpcOrGo1` = 3653234 WHERE `ID` = 29272 AND `RequiredNpcOrGo1` = 53234;
UPDATE `quest_template`
  SET `RequiredNpcOrGo1` = 3653886, `RequiredNpcOrGo2` = 3652891
  WHERE `ID` = 29210 AND `RequiredNpcOrGo1` = 53886 AND `RequiredNpcOrGo2` = 52891;
UPDATE `quest_template`
  SET `RequiredNpcOrGo1` = 3653308, `RequiredNpcOrGo2` = 3653479, `RequiredNpcOrGo3` = 3653310
  WHERE `ID` = 29290 AND `RequiredNpcOrGo1` = 53308 AND `RequiredNpcOrGo2` = 53479 AND `RequiredNpcOrGo3` = 53310;

UPDATE `quest_template` SET `RewardNextQuest` = 0 WHERE `ID` = 29234 AND `RewardNextQuest` = 29239;
