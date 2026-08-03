-- ---------------------------------------------------------------------------
-- 229  Summon spells still pointing at RAW Cata creature entries
-- ---------------------------------------------------------------------------
-- Found by applying 228_'s lesson to my own work: an import that remaps `entry`
-- is not finished, because ids EMBEDDED IN OTHER COLUMNS keep pointing at the
-- source. 228_ was linked traps in gameobject_template.data12. This is the same
-- bug in the spells the earlier rounds MINTED -- `EffectMiscValue` on a summon
-- effect is the creature entry to spawn, and it was copied from Cataclysm
-- verbatim.
--
-- SYMPTOM (and it was in the log all along, misread by me once):
--   Creature::Create(): creature template (guidlow: 5586, entry: 35835) does not exist.
-- I first wrote that off as stock content on map 0 because `creature` guid 5586
-- is a Kalimdor spawn. It is not a spawn guid at all -- like 228_'s gameobject
-- guids, it is a RUNTIME guid from Map::GenerateLowGuid. Exactly the same red
-- herring, twice in one round. **A guid in a "Create()" failure is a runtime
-- guid; never look it up in the spawn table.**
--
-- All four casters are live, so all four summons fail today:
--   68129 Spitelash Seacaller   x14 (map 750) -> 35835 Shipwrecker
--   85243 Skullmage             x7  (map 751) -> 45683 Chattering Swarm
--   68990 Lorekeeper Amberwind  x1  (map 750) -> 36601 Amberwind's Construct
--   79893 Omasum Blighthoof     x1  (map 751) -> 42850 Bloodworm
--
-- 45683 already exists here as 3645683, so that one is a pure remap. The other
-- three summon creatures no import ever brought across, so they are imported
-- below. All three are cheap: no vehicle, no script, no gossip, and their
-- display ids (4606, 19702, 15983) are ordinary WotLK-era ones already present
-- in the live CreatureDisplayInfo.dbc AND in creature_model_info -- verified,
-- not assumed, because the display layer has been the recurring trap. So this
-- file needs NO DBC work at all.
--
-- OFFSET IS +3,600,000 for all three, taken from each caster's own band
-- (3635832, 3636594, 3645867 are all raw+3,600,000) rather than assumed.
--
-- Column-scoped INSERT ... SELECT for the same reason as 227_: our
-- creature_template has 55 columns to cata's 84, and every non-shared column
-- of ours has a DEFAULT.
--
-- 223_ HAS ALSO BEEN CORRECTED AT SOURCE so a fresh apply mints 85243 with the
-- right value; the UPDATE below is guarded on the old value, so it is a no-op
-- if 223_ was applied after that correction, and safe to run either way.
-- ---------------------------------------------------------------------------

-- --- the 3 summon targets that were never imported -------------------------
DELETE FROM `creature_template` WHERE `entry` IN (3635835, 3636601, 3642850);
INSERT INTO `creature_template`
 (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`,
  `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`,
  `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `dmgschool`, `DamageModifier`,
  `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`,
  `unit_flags`, `unit_flags2`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`,
  `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`,
  `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`,
  `RacialLeader`, `movementId`, `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT m.dst, ct.`difficulty_entry_1`, ct.`difficulty_entry_2`, ct.`difficulty_entry_3`,
  ct.`KillCredit1`, ct.`KillCredit2`, ct.`name`, ct.`subname`, ct.`IconName`,
  ct.`gossip_menu_id`, ct.`minlevel`, ct.`maxlevel`, ct.`faction`, ct.`npcflag`,
  ct.`speed_walk`, ct.`speed_run`, ct.`rank`, ct.`dmgschool`, ct.`DamageModifier`,
  ct.`BaseAttackTime`, ct.`RangeAttackTime`, ct.`BaseVariance`, ct.`RangeVariance`,
  ct.`unit_class`, ct.`unit_flags`, ct.`unit_flags2`, ct.`family`, ct.`type`, ct.`type_flags`,
  ct.`lootid`, ct.`pickpocketloot`, ct.`skinloot`, ct.`PetSpellDataId`, ct.`VehicleId`,
  ct.`mingold`, ct.`maxgold`, ct.`AIName`, ct.`MovementType`, ct.`HoverHeight`,
  ct.`HealthModifier`, ct.`ManaModifier`, ct.`ArmorModifier`, ct.`ExperienceModifier`,
  ct.`RacialLeader`, ct.`movementId`, ct.`RegenHealth`, ct.`flags_extra`, ct.`ScriptName`,
  ct.`VerifiedBuild`
FROM cata_world.`creature_template` ct
JOIN (SELECT 35835 src, 3635835 dst
      UNION ALL SELECT 36601, 3636601
      UNION ALL SELECT 42850, 3642850) m ON m.src = ct.`entry`;

-- --- their models ----------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (3635835, 3636601, 3642850);
INSERT INTO `creature_template_model`
 (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`) VALUES
(3635835, 0, 4606, 1, 1),
(3636601, 0, 19702, 1, 1),
(3642850, 0, 15983, 1, 1);

-- --- point the four summon spells at the clones ----------------------------
UPDATE `spell_dbc` SET `EffectMiscValue_1` = 3635835 WHERE `ID` = 68129 AND `EffectMiscValue_1` = 35835;
UPDATE `spell_dbc` SET `EffectMiscValue_1` = 3636601 WHERE `ID` = 68990 AND `EffectMiscValue_1` = 36601;
UPDATE `spell_dbc` SET `EffectMiscValue_1` = 3642850 WHERE `ID` = 79893 AND `EffectMiscValue_1` = 42850;
UPDATE `spell_dbc` SET `EffectMiscValue_1` = 3645683 WHERE `ID` = 85243 AND `EffectMiscValue_1` = 45683;

-- Verify -- expect 3, 3, and 0 remaining raw targets:
--   SELECT COUNT(*) FROM `creature_template` WHERE entry IN (3635835,3636601,3642850);
--   SELECT COUNT(*) FROM `creature_template_model` WHERE CreatureID IN (3635835,3636601,3642850);
--   SELECT ID, EffectMiscValue_1 FROM `spell_dbc`
--    WHERE ID IN (68129,68990,79893,85243)
--      AND EffectMiscValue_1 NOT IN (SELECT entry FROM `creature_template`);
-- and the boot log must lose its "Creature::Create(): creature template
-- (guidlow: N, entry: 35835) does not exist" lines.
--
-- NOTE spell_dbc IS an additive overlay the server DOES read for spells (unlike
-- the *_dbc mirror tables for CreatureDisplayInfo/Vehicle), because these four
-- spells exist ONLY in spell_dbc -- they were minted there by 192_/200_/223_
-- and are absent from the client's Spell.dbc. So this file needs no DBC deploy.
