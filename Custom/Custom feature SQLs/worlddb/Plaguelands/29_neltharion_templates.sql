-- =====================================================================
-- Plaguelands (map 751) -- 29  Neltharion-only template import
-- ---------------------------------------------------------------------
-- The 143 base-visible NPCs Neltharion spawns in Plaguelands that the cata dc-clone lacks. Converts the old-TC
-- Neltharion schema -> acore (faction_A->faction, modelid1-4->creature_template_model,
-- exp->LEAST(exp,2), dmg_multiplier->DamageModifier, Health_mod/Mana_mod/Armor_mod->
-- *Modifier, speed_fly->speed_flight). Cloned at entry = nelt_id + 3,600,000 to match
-- the dc scheme. Run BEFORE 30 (spawn layer) so its orphan-clean keeps these. Idempotent.
-- =====================================================================
SET @OFF := 3600000;
SET @NIDS := '1056,1609,1783,1784,1794,1837,1841,1844,1847,1850,1851,1855,1884,4076,8477,8607,10304,10698,10739,10778,10816,10818,10824,10825,10827,10828,10902,10903,10904,10905,10936,10940,10976,11023,11064,11216,11217,11286,11610,11613,11614,11704,11710,11878,11885,11898,12202,12244,12247,12249,12251,12252,12253,12254,12255,12256,12261,12322,15162,15566,15592,15602,16131,16132,16184,16361,16431,16494,16781,16786,17689,17690,17696,17698,17795,25909,26401,28512,29210,29231,32820,43803,44329,44331,44332,44448,44449,44450,44458,44487,44488,44489,44552,44555,44944,44946,44955,45047,45048,45049,45050,45058,45060,45061,45085,45098,45101,45209,45235,45239,45240,45241,45242,45243,45416,45574,45579,45683,45698,45707,45729,45730,45738,46092,46093,46094,46095,46096,46558,48718,51535,51604,54344,56049,60217,60219,60221,60247,60249,60251,60615,60617,1337016';

-- creature_template (old-TC nelt -> acore column map)
INSERT IGNORE INTO acore_world.creature_template
(`entry`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`speed_swim`,`speed_flight`,`rank`,`dmgschool`,`DamageModifier`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
SELECT entry+@OFF, IF(KillCredit1>0,KillCredit1+@OFF,0), IF(KillCredit2>0,KillCredit2+@OFF,0), name, subname, IconName, gossip_menu_id, minlevel, maxlevel, LEAST(exp,2), faction_A, npcflag, speed_walk, speed_run, speed_swim, speed_fly, rank, dmgschool, dmg_multiplier, baseattacktime, rangeattacktime, 1, 1, unit_class, unit_flags, unit_flags2, dynamicflags, family, type, type_flags, lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, MovementType, HoverHeight, Health_mod, Mana_mod, Armor_mod, RacialLeader, movementId, RegenHealth, flags_extra, '', 0
FROM nelt_world.creature_template
WHERE FIND_IN_SET(entry, @NIDS);

-- creature_template_model: one row per non-zero modelid slot (DisplayScale=scale, Probability=1)
INSERT IGNORE INTO acore_world.creature_template_model (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT entry+@OFF, idx, mid, scale, 1, 0 FROM (
  SELECT entry, 0 idx, modelid1 mid, scale FROM nelt_world.creature_template WHERE FIND_IN_SET(entry,@NIDS) AND modelid1>0
  UNION ALL SELECT entry, 1, modelid2, scale FROM nelt_world.creature_template WHERE FIND_IN_SET(entry,@NIDS) AND modelid2>0
  UNION ALL SELECT entry, 2, modelid3, scale FROM nelt_world.creature_template WHERE FIND_IN_SET(entry,@NIDS) AND modelid3>0
  UNION ALL SELECT entry, 3, modelid4, scale FROM nelt_world.creature_template WHERE FIND_IN_SET(entry,@NIDS) AND modelid4>0
) m;

-- creature_template_movement: Flight for airborne (InhabitType bit 0x4 = air/both) so flyers don't sink
INSERT IGNORE INTO acore_world.creature_template_movement (`CreatureId`,`Ground`,`Swim`,`Flight`,`Rooted`,`Chase`,`Random`,`InteractionPauseTimer`)
SELECT entry+@OFF, 1, (InhabitType&2)>0, IF((InhabitType&4)>0,1,0), 0, 0, 0, 0
FROM nelt_world.creature_template WHERE FIND_IN_SET(entry,@NIDS) AND (InhabitType&4)>0;

-- loot (keyed by lootid; INSERT IGNORE dedupes). nelt loot: entry,item,ChanceOrQuestChance,lootmode,groupid,mincountOrRef,maxcount
INSERT IGNORE INTO acore_world.creature_loot_template (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT lt.entry, lt.item, IF(lt.mincountOrRef<0,-lt.mincountOrRef,0), ABS(lt.ChanceOrQuestChance), IF(lt.ChanceOrQuestChance<0,1,0), lt.lootmode, lt.groupid, IF(lt.mincountOrRef<0,1,lt.mincountOrRef), lt.maxcount
FROM nelt_world.creature_loot_template lt
WHERE lt.entry IN (SELECT lootid FROM nelt_world.creature_template WHERE FIND_IN_SET(entry,@NIDS) AND lootid>0);

-- creature_text (nelt: entry -> CreatureID; lowercase cols)
INSERT IGNORE INTO acore_world.creature_text (`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,`BroadcastTextId`,`TextRange`,`comment`)
SELECT entry+@OFF, groupid, id, text, type, language, probability, emote, duration, sound, BroadcastTextID, text_range, comment
FROM nelt_world.creature_text WHERE FIND_IN_SET(entry,@NIDS);

-- smart_scripts (entry-based, +@OFF). nelt 29-col -> acore (has event_param6/target_param4 defaults)
INSERT IGNORE INTO acore_world.smart_scripts
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,`event_param1`,`event_param2`,`event_param3`,`event_param4`,`action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`target_type`,`target_param1`,`target_param2`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT entryorguid+@OFF, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags, event_param1, event_param2, event_param3, event_param4, action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6, target_type, target_param1, target_param2, target_x, target_y, target_z, target_o, comment
FROM nelt_world.smart_scripts WHERE source_type=0 AND entryorguid>0 AND FIND_IN_SET(entryorguid,@NIDS);