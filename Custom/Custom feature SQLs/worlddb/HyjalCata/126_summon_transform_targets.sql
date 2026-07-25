-- ---------------------------------------------------------------------------
-- 126  Hyjal round-15 -- creatures that spells summon or transform into
-- ---------------------------------------------------------------------------
-- Seen live while flying map 750:
--     Auras: unknown creature id = 53845 (only need its modelid)
--            From Spell Aura Transform in Spell ID = 100200
-- (repeated every time the aura ticks).  Spell 100200 "Tauren Form" is an
-- Elemental Bonds cutscene aura whose EffectMiscValue is the creature whose
-- MODEL the player is transformed into -- 53845 "Gart Mistrunner".  That id
-- was carried over raw from Cata and the creature was never cloned, so the
-- transform silently does nothing and spams the log.
--
-- A sweep of spell_dbc for the same shape -- EffectMiscValue holding a creature
-- id on SUMMON(28) / KILL_CREDIT(90) / KILL_CREDIT2(134) / aura TRANSFORM(56) /
-- aura MOUNTED(78) -- found two families:
--
--  (a) 5 spells whose clone ALREADY exists, so only the misc value is stale:
--        97773 Flame Protection Runes Extinguished Credit  52891
--        98186 Portal Closed Credit                        52531
--        98757 Summon Trained Fire Hawk                    53300
--        98826 Furnace Assault Credit                      53218
--        151014 Summon Ashbearer                           46925
--      (Stock spells that legitimately reference stock creatures -- 17310
--      Darrowshire, 28190 Naxxramas Mutate, 83409-83411 Plaguelands -- were
--      excluded by hand; the rule "raw id has no template but +3.6M does"
--      separates them cleanly.)
--
--  (b) 17 creatures that do not exist at ALL, raw or cloned, so their spells
--      are inert.  All 17 are in nelt_world and are imported here:
--        41092 Vision of Aviana's Egg      41624 Lavaman Stalker target
--        41807 Roaring Flame               41901 Magma Jet
--        42596 Shadowblaze                 49413 Cenarius Event Camera
--        52705 / 52990 Captured Hyjal Druid   52804 Shadow Warden
--        52950 Solar Core Kill Credit      53163 Rope (Furnace rappel)
--        53234 Anren Shadowseeker          53354 Escape Winds
--        53845 Gart Mistrunner             54025 Elderlimb
--        54034 Ricket's Rocket             54070 Tenaron Stormgrip
--        54181 Elemental Bonds Event Controller (The Vow)
--
-- 123_ already emits its own spells with the misc value remapped, so this file
-- only has to fix the rows that were downported in EARLIER rounds -- but it
-- must run BEFORE/with 123_ so those summon targets exist.
--
-- Column map is 29_neltharion_templates.sql's, verbatim.  Idempotent.
-- ---------------------------------------------------------------------------
SET @OFF := 3600000;
SET @NIDS := '41092,41624,41807,41901,42596,49413,52705,52804,52950,52990,53163,53234,53354,53845,54025,54034,54070,54181';

INSERT IGNORE INTO acore_world.creature_template
(`entry`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`speed_swim`,`speed_flight`,`rank`,`dmgschool`,`DamageModifier`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
SELECT entry+@OFF, IF(KillCredit1>0,KillCredit1+@OFF,0), IF(KillCredit2>0,KillCredit2+@OFF,0), name, subname, IconName, gossip_menu_id, minlevel, maxlevel, LEAST(exp,2), faction_A, npcflag, speed_walk, speed_run, speed_swim, speed_fly, `rank`, dmgschool, dmg_multiplier, baseattacktime, rangeattacktime, 1, 1, unit_class, unit_flags, unit_flags2, dynamicflags, family, type, type_flags, lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, MovementType, HoverHeight, Health_mod, Mana_mod, Armor_mod, RacialLeader, movementId, RegenHealth, flags_extra, '', 0
FROM nelt_world.creature_template
WHERE FIND_IN_SET(entry, @NIDS);

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

-- --- (a) stale EffectMiscValue on spells downported in earlier rounds --------
-- Guarded on the exact current value and on the clone existing, so re-running
-- is a no-op and it can never point a spell at a missing creature.
UPDATE `spell_dbc` s SET s.`EffectMiscValue_1` = s.`EffectMiscValue_1` + 3600000
WHERE s.`ID` IN (97773,98186,98757,98826,151014,100200)
  AND s.`EffectMiscValue_1` IN (52891,52531,53300,53218,46925,53845)
  AND EXISTS (SELECT 1 FROM `creature_template` c WHERE c.`entry` = s.`EffectMiscValue_1` + 3600000);
