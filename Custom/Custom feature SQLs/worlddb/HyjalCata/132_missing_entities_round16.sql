-- ---------------------------------------------------------------------------
-- 132  Hyjal round-16 -- 6 creatures + 1 GameObject the action lists need
-- ---------------------------------------------------------------------------
-- With 122_'s action lists loaded, their own references started validating and
-- exposed a last set of never-cloned entities:
--
--   SmartAIMgr: Entry 4080301 SourceType 9 ... non-existent Creature entry
--               75034 / 75035 as target_param1
--   SmartAIMgr: Entry 4085600 SourceType 9 ... non-existent GameObject entry
--               203065   (x8 -- the Emerald Flameweaver's flame spawns)
--   Quest 29211 has `RequiredNpcOrGo1` = 52950 ... does not exist
--   Quest 29243 / 29305 = 54230, 29249 = 53084, 29297 = 53251, 29299 = 53263
--
--   75034 Arch Druid Hamuul Runetotem  (Cenarius scene stand-in)
--   75035 Malfurion Stormrage          (ditto)
--   53084 Summon Lashling Kill Credit
--   53251 Druid of the Flame - Bird Form Credit
--   53263 Ember Pool Kill Credit
--   54230 Lieutenant of Flame
--   GO 203065 "Emerald Flames"
--
-- (52950 "Solar Core Kill Credit" is already imported by 126_; the quest that
--  needs it is realigned in 133_ rather than re-imported here.)
--
-- Column maps are 29_neltharion_templates.sql's (creatures) and 127_'s
-- (gameobject), verbatim.  Idempotent.
-- ---------------------------------------------------------------------------
SET @OFF := 3600000;
SET @NIDS := '53084,53251,53263,54230,75034,75035';

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

-- --- the missing GameObject -------------------------------------------------
-- cata_world and nelt_world agree on 203065 "Emerald Flames"; cata_world is used
-- for consistency with 127_'s Harpy trap import.
INSERT IGNORE INTO acore_world.gameobject_template
(`entry`,`type`,`displayId`,`name`,`IconName`,`castBarCaption`,`unk1`,`size`,`Data0`,`Data1`,`Data2`,`Data3`,`Data4`,`Data5`,`Data6`,`Data7`,`Data8`,`Data9`,`Data10`,`Data11`,`Data12`,`Data13`,`Data14`,`Data15`,`Data16`,`Data17`,`Data18`,`Data19`,`Data20`,`Data21`,`Data22`,`Data23`,`AIName`,`ScriptName`,`VerifiedBuild`)
SELECT entry+3600000, type, displayId, name, IconName, castBarCaption, unk1, size, Data0, Data1, Data2, Data3, Data4, Data5, Data6, Data7, Data8, Data9, Data10, Data11, Data12, Data13, Data14, Data15, Data16, Data17, Data18, Data19, Data20, Data21, Data22, Data23, AIName, '', 0
FROM cata_world.gameobject_template WHERE entry = 203065;
