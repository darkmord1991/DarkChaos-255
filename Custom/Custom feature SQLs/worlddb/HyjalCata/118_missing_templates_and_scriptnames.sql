-- ---------------------------------------------------------------------------
-- 118  Hyjal round-14 -- 5 never-cloned templates + the 3 dormant ScriptNames
-- ---------------------------------------------------------------------------
-- Three CreatureScripts in src/server/scripts/DC/MountHyjal/zone_mount_hyjal.cpp
-- are compiled and registered but no creature carries their name:
--     Script named 'npc_aessina_miracle_vehicle' is not assigned in the database.
--     Script named 'npc_spawn_of_smolderos_dog' is not assigned in the database.
--     Script named 'npc_wings_of_aviana_daily' is not assigned in the database.
-- The Neltharion source core left them unassigned too, so the target entries had
-- to be reverse-engineered from the Cata data rather than copied:
--
--   npc_aessina_miracle_vehicle -> 41459 "Player Float Vehicle" (VehicleId 825).
--       Summoned by exactly one spell, 77574 "Summon Float Vehicle"; the AI puts
--       the player on seat 0 and then summons Aessina (41406) onto seat 2, which
--       matches 41406's own SmartAI (cast 98914 at target_type 11 = creature
--       41459).  The clone 3641459 already exists.
--   npc_spawn_of_smolderos_dog  -> 39659 "Spawn of Smolderos", summoned by 74138
--       "Summon Spawn of Smolderos"; the AI credits 39673 "Spawn of Smolderos
--       Credit", the objective of quest 25294 "Walking the Dog".  NOT cloned yet.
--   npc_wings_of_aviana_daily   -> 52597 "Wings of Aviana" (VehicleId 1610),
--       summoned by 97241 "Quill of the Bird-Queen"; the AI gates on quest 29147
--       "Call the Flock".  NOT cloned yet.
--
-- So this file first imports the five templates that 29_'s id list missed, then
-- wires the scripts.  Column map is 29_neltharion_templates.sql's, verbatim
-- (old-TC nelt -> acore: faction_A->faction, modelid1-4->creature_template_model,
-- exp->LEAST(exp,2), dmg_multiplier->DamageModifier, Health_mod/Mana_mod/
-- Armor_mod->*Modifier, speed_fly->speed_flight).
--
--   39659  Spawn of Smolderos                              (display 31535, stock)
--   52595  Alpine Songbird      -- quest 29147 objective    (display 28215, stock)
--   52596  Forest Owl           -- quest 29147 objective    (display 10830, stock)
--   52597  Wings of Aviana                                  (displays 37989/37990/
--                                                            21832/37992 -- see
--                                                            the CDI note below)
--   75183  Wondi's Bunny - Into the Fire - Player Check     (display 16480, stock)
--
-- CLIENT PREREQUISITE for 52597: CreatureDisplayInfo 37989 / 37990 / 37992 are
-- absent from Custom/DBCs/CreatureDisplayInfo.dbc.  No asset work is needed --
-- all three are plain stock 3.3.5 models with stock textures (EAGLE.M2 model
-- 2631 tex "Eagle"; HARPY.M2 model 12 tex "HarpyPurple"; CARRIONBIRD.M2 model 61
-- tex "CarrionBirdSkinBlue"/"CarrionBirdWingBlue") -- only the three DBC rows are
-- missing.  They are added to Custom/CSV DBC/CreatureDisplayInfo.csv by this
-- round and need a recompile + deploy.
-- There is no crash window from applying this file first: 3652597 has no static
-- spawns and is reachable ONLY through spell 97241, which is itself part of the
-- same Spell.dbc rebuild -- so the NPC cannot exist in world until the DBC deploy
-- that carries its displays has happened.  (Do not spawn 3652597 by hand before
-- then: a creature with a non-existing CreatureDisplayID can crash the client.)
-- ---------------------------------------------------------------------------
SET @OFF := 3600000;
SET @NIDS := '39659,52595,52596,52597,75183';

INSERT IGNORE INTO acore_world.creature_template
(`entry`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`speed_swim`,`speed_flight`,`rank`,`dmgschool`,`DamageModifier`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
SELECT entry+@OFF, IF(KillCredit1>0,KillCredit1+@OFF,0), IF(KillCredit2>0,KillCredit2+@OFF,0), name, subname, IconName, gossip_menu_id, minlevel, maxlevel, LEAST(exp,2), faction_A, npcflag, speed_walk, speed_run, speed_swim, speed_fly, `rank`, dmgschool, dmg_multiplier, baseattacktime, rangeattacktime, 1, 1, unit_class, unit_flags, unit_flags2, dynamicflags, family, type, type_flags, lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, MovementType, HoverHeight, Health_mod, Mana_mod, Armor_mod, RacialLeader, movementId, RegenHealth, flags_extra, '', 0
FROM nelt_world.creature_template
WHERE FIND_IN_SET(entry, @NIDS);

-- model slots (acore_world.creaturedisplayinfo_dbc is empty on this fork -- the
-- server reads the real DBC -- so there is nothing to validate against in SQL)
INSERT IGNORE INTO acore_world.creature_template_model (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT m.entry+@OFF, m.idx, m.mid, m.scale, 1, 0 FROM (
  SELECT entry, 0 idx, modelid1 mid, scale FROM nelt_world.creature_template WHERE FIND_IN_SET(entry,@NIDS) AND modelid1>0
  UNION ALL SELECT entry, 1, modelid2, scale FROM nelt_world.creature_template WHERE FIND_IN_SET(entry,@NIDS) AND modelid2>0
  UNION ALL SELECT entry, 2, modelid3, scale FROM nelt_world.creature_template WHERE FIND_IN_SET(entry,@NIDS) AND modelid3>0
  UNION ALL SELECT entry, 3, modelid4, scale FROM nelt_world.creature_template WHERE FIND_IN_SET(entry,@NIDS) AND modelid4>0
) m;

INSERT IGNORE INTO acore_world.creature_template_movement (`CreatureId`,`Ground`,`Swim`,`Flight`,`Rooted`,`Chase`,`Random`,`InteractionPauseTimer`)
SELECT entry+@OFF, 1, (InhabitType&2)>0, IF((InhabitType&4)>0,1,0), 0, 0, 0, 0
FROM nelt_world.creature_template WHERE FIND_IN_SET(entry,@NIDS) AND (InhabitType&4)>0;

INSERT IGNORE INTO acore_world.creature_text (`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,`BroadcastTextId`,`TextRange`,`comment`)
SELECT entry+@OFF, groupid, id, text, type, language, probability, emote, duration, sound, BroadcastTextID, text_range, comment
FROM nelt_world.creature_text WHERE FIND_IN_SET(entry,@NIDS);

INSERT IGNORE INTO acore_world.smart_scripts
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,`event_param1`,`event_param2`,`event_param3`,`event_param4`,`action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`target_type`,`target_param1`,`target_param2`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT entryorguid+@OFF, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags, event_param1, event_param2, event_param3, event_param4, action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6, target_type, target_param1, target_param2, target_x, target_y, target_z, target_o, comment
FROM nelt_world.smart_scripts WHERE source_type=0 AND entryorguid>0 AND FIND_IN_SET(entryorguid,@NIDS);

INSERT IGNORE INTO acore_world.npc_spellclick_spells (`npc_entry`,`spell_id`,`cast_flags`,`user_type`)
SELECT npc_entry+@OFF, spell_id, cast_flags, user_type
FROM nelt_world.npc_spellclick_spells WHERE FIND_IN_SET(npc_entry,@NIDS);

-- --- ScriptName wiring ------------------------------------------------------
-- NOTE ON ORDERING: FactorySelector::SelectAI resolves ScriptName BEFORE AIName,
-- so setting a ScriptName on a SmartAI creature silently disables its SmartAI.
-- For all three the C++ AI is the complete implementation and the SmartAI rows
-- are the stub the Neltharion devs left behind, so AIName is cleared explicitly
-- rather than left to shadow.
UPDATE `creature_template` SET `ScriptName` = 'npc_aessina_miracle_vehicle', `AIName` = ''
WHERE `entry` = 3641459 AND `ScriptName` = '';

UPDATE `creature_template` SET `ScriptName` = 'npc_spawn_of_smolderos_dog', `AIName` = ''
WHERE `entry` = 3639659 AND `ScriptName` = '';

UPDATE `creature_template` SET `ScriptName` = 'npc_wings_of_aviana_daily', `AIName` = ''
WHERE `entry` = 3652597 AND `ScriptName` = '';

-- --- deferred from 113_: the reference that needed 3675183 to exist first -----
UPDATE `smart_scripts` s SET s.`target_param1` = s.`target_param1` + 3600000
WHERE s.`source_type` = 0 AND s.`entryorguid` = 3653355 AND s.`id` = 5 AND s.`target_param1` = 75183
  AND EXISTS (SELECT 1 FROM `creature_template` ct WHERE ct.`entry` = 3675183);
