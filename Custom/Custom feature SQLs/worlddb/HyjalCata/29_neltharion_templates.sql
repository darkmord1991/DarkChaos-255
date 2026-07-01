-- =====================================================================
-- Mount Hyjal (map 750) -- 29  Neltharion-only template import
-- ---------------------------------------------------------------------
-- The 58 base-visible NPCs Neltharion spawns in Hyjal that the cata dc-clone lacks
-- (incl. the Molten Front 75xxx set + 22 named / 12 questgivers). Converts the old-TC
-- Neltharion schema -> acore (faction_A->faction, modelid1-4->creature_template_model,
-- exp->LEAST(exp,2), dmg_multiplier->DamageModifier, Health_mod/Mana_mod/Armor_mod->
-- *Modifier, speed_fly->speed_flight). Cloned at entry = nelt_id + 3,600,000 to match
-- the dc scheme. Run BEFORE 30 (spawn layer) so its orphan-clean keeps these. Idempotent.
-- =====================================================================
SET @OFF := 3600000;
-- 2026-07: extended with the 60 script-dependency NPCs of zone_mount_hyjal.cpp /
-- zone_molten_front.cpp (proveditor event, orb, controllers, Molten Front cast,
-- summon-spell targets 39622/39627/40434/53083/75024, turtle punter 52988,
-- flame-protection runes 52884-90/53887, fire hawks 53297/53300).
SET @NIDS := '7446,10201,13148,14348,36911,39765,39941,40031,40540,40557,40803,46925,47459,49456,50070,50079,50083,51682,52995,53493,53697,54168,54171,54172,54173,54174,54175,54176,54177,54178,54179,54180,54312,54319,55227,60461,60463,60465,60467,60469,75004,75005,75012,75013,75014,75015,75019,75020,75021,75023,75026,75027,75028,75030,75031,75032,75036,75158,38806,39431,39436,39438,39601,39622,39627,39673,40434,40461,40462,40618,40856,41406,44403,52177,52531,52552,52663,52683,52854,52884,52885,52886,52887,52888,52889,52890,52893,52953,52954,52955,52964,52965,52988,52998,52999,53012,53017,53083,53092,53217,53218,53297,53300,53328,53329,53355,53887,54252,54253,54254,54255,54256,54257,75024,75029,75181,75182,75186';

-- creature_template (old-TC nelt -> acore column map)
INSERT IGNORE INTO acore_world.creature_template
(`entry`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`speed_swim`,`speed_flight`,`rank`,`dmgschool`,`DamageModifier`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
SELECT entry+@OFF, IF(KillCredit1>0,KillCredit1+@OFF,0), IF(KillCredit2>0,KillCredit2+@OFF,0), name, subname, IconName, gossip_menu_id, minlevel, maxlevel, LEAST(exp,2), faction_A, npcflag, speed_walk, speed_run, speed_swim, speed_fly, `rank`, dmgschool, dmg_multiplier, baseattacktime, rangeattacktime, 1, 1, unit_class, unit_flags, unit_flags2, dynamicflags, family, type, type_flags, lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, MovementType, HoverHeight, Health_mod, Mana_mod, Armor_mod, RacialLeader, movementId, RegenHealth, flags_extra, '', 0
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

-- ---------------------------------------------------------------------
-- Hand-authored controller bunnies. The ported C++ references
-- NPC_GRADUATION_CONTROLLER 3675196 / NPC_BUNNY_TRIGGER 3675197, but no
-- 75196/75197 exist in nelt_world (Neltharion never shipped them), so
-- author minimal invisible trigger templates here (model 11686, faction
-- 35, not-selectable, flags_extra TRIGGER).
-- ---------------------------------------------------------------------
INSERT IGNORE INTO acore_world.creature_template
(`entry`,`name`,`subname`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`rank`,`unit_class`,`unit_flags`,`type`,`type_flags`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`RegenHealth`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
VALUES
(3675196,'DC Bunny - Graduation Speech - Controller','',80,80,2,35,0,1,1.14286,0,1,33554688,10,0,'',0,1,1,1,1,1,128,'npc_graduation_speech_controller',0),
(3675197,'DC Bunny - Graduation Speech - Trigger','',80,80,2,35,0,1,1.14286,0,1,33554688,10,0,'',0,1,1,1,1,1,128,'',0);
INSERT IGNORE INTO acore_world.creature_template_model (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`) VALUES
(3675196,0,11686,1,1,0),
(3675197,0,11686,1,1,0);

-- ---------------------------------------------------------------------
-- GameObject clones needed by the ported scripts (nelt old-TC schema has
-- faction/flags inline -> acore splits them into gameobject_template_addon;
-- data24-31/unkInt32 have no 3.3.5 equivalent and are dropped):
--   202652 Twilight Supplies (summoned by spell 73959, End of the Supply Line)
--   208427 Furnace Door      (npc_into_the_fire_end_controller, GO 3808427)
-- ---------------------------------------------------------------------
INSERT IGNORE INTO acore_world.gameobject_template (`entry`,`type`,`displayId`,`name`,`IconName`,`castBarCaption`,`unk1`,`size`,`Data0`,`Data1`,`Data2`,`Data3`,`Data4`,`Data5`,`Data6`,`Data7`,`Data8`,`Data9`,`Data10`,`Data11`,`Data12`,`Data13`,`Data14`,`Data15`,`Data16`,`Data17`,`Data18`,`Data19`,`Data20`,`Data21`,`Data22`,`Data23`,`AIName`,`ScriptName`,`VerifiedBuild`)
SELECT entry+@OFF, `type`, displayId, name, IconName, castBarCaption, unk1, size, data0, IF(entry=202652, data1+@OFF, data1), data2, data3, data4, data5, data6, data7, data8, data9, data10, data11, data12, data13, data14, data15, data16, data17, data18, data19, data20, data21, data22, data23, '', '', 0
FROM nelt_world.gameobject_template WHERE entry IN (202652, 208427);
INSERT IGNORE INTO acore_world.gameobject_template_addon (`entry`,`faction`,`flags`,`mingold`,`maxgold`,`artkit0`,`artkit1`,`artkit2`,`artkit3`)
SELECT entry+@OFF, faction, flags, 0, 0, 0, 0, 0, 0
FROM nelt_world.gameobject_template WHERE entry IN (202652, 208427);

-- Twilight Supplies chest loot (type 3, Data1 = gameobject_loot id, remapped +@OFF above).
INSERT IGNORE INTO acore_world.gameobject_loot_template (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT lt.entry+@OFF, lt.item, IF(lt.mincountOrRef<0,-lt.mincountOrRef,0), ABS(lt.ChanceOrQuestChance), IF(lt.ChanceOrQuestChance<0,1,0), lt.lootmode, lt.groupid, IF(lt.mincountOrRef<0,1,lt.mincountOrRef), lt.maxcount
FROM nelt_world.gameobject_loot_template lt WHERE lt.entry=202652;

-- Turtle Punter (52988) action-bar spells: this fork keeps creature spells in
-- creature_template_spell (spell rows authored in 47_spell_dbc_custom.sql).
DELETE FROM acore_world.creature_template_spell WHERE CreatureID=3652988;
INSERT INTO acore_world.creature_template_spell (`CreatureID`,`Index`,`Spell`,`VerifiedBuild`) VALUES
(3652988,0,93604,0),
(3652988,1,93593,0);