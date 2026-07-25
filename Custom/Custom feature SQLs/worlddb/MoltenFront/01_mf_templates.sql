-- =====================================================================
-- Molten Front (map 750) -- 01  Template import (curated fully-unlocked set)
-- ---------------------------------------------------------------------
-- Clones every creature/GO template referenced by the curated Molten Front
-- spawn snapshot (nelt_world map 861, phaseMask IN (2047,8,16,128) -- see
-- 00_README.md). Self-deriving: the WHERE picks exactly the entries that the
-- curated spawns use, so it stays in sync with 02. dc_entry = nelt_id+3,600,000.
-- Column map = HyjalCata/29 (faction_A->faction, dmg_multiplier->DamageModifier,
-- Health_mod/Mana_mod/Armor_mod->*Modifier, speed_fly->speed_flight, LEAST(exp,2)).
-- INSERT IGNORE, so the ~24 creature + 1 GO templates already cloned are skipped.
-- Idempotent. Run on acore_world AFTER ../HyjalCata/apply_all.sql.
-- =====================================================================
SET @OFF := 3600000;

-- ---- reusable curated-entry predicates (creature / gameobject) ----
-- creature:   id IN (SELECT DISTINCT id FROM nelt_world.creature   WHERE map=861 AND phaseMask IN (2047,8,16,128))
-- gameobject: id IN (SELECT DISTINCT id FROM nelt_world.gameobject WHERE map=861 AND phaseMask IN (2047,8,16,128))

-- =========================== CREATURES ===============================
INSERT IGNORE INTO acore_world.creature_template
(`entry`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`speed_swim`,`speed_flight`,`rank`,`dmgschool`,`DamageModifier`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
SELECT entry+@OFF, IF(KillCredit1>0,KillCredit1+@OFF,0), IF(KillCredit2>0,KillCredit2+@OFF,0), name, subname, IconName, gossip_menu_id, minlevel, maxlevel, LEAST(exp,2), faction_A, npcflag, speed_walk, speed_run, speed_swim, speed_fly, `rank`, dmgschool, dmg_multiplier, baseattacktime, rangeattacktime, 1, 1, unit_class, unit_flags, unit_flags2, dynamicflags, family, type, type_flags, lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, MovementType, HoverHeight, Health_mod, Mana_mod, Armor_mod, RacialLeader, movementId, RegenHealth, flags_extra, '', 0
FROM nelt_world.creature_template
WHERE entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask IN (2047,8,16,128));

-- creature_template_model: one row per non-zero modelid slot
INSERT IGNORE INTO acore_world.creature_template_model (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT entry+@OFF, idx, mid, scale, 1, 0 FROM (
  SELECT entry, 0 idx, modelid1 mid, scale FROM nelt_world.creature_template WHERE entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask IN (2047,8,16,128)) AND modelid1>0
  UNION ALL SELECT entry, 1, modelid2, scale FROM nelt_world.creature_template WHERE entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask IN (2047,8,16,128)) AND modelid2>0
  UNION ALL SELECT entry, 2, modelid3, scale FROM nelt_world.creature_template WHERE entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask IN (2047,8,16,128)) AND modelid3>0
  UNION ALL SELECT entry, 3, modelid4, scale FROM nelt_world.creature_template WHERE entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask IN (2047,8,16,128)) AND modelid4>0
) m;

-- creature_template_movement: Flight for airborne (InhabitType bit 0x4) so flyers don't sink
INSERT IGNORE INTO acore_world.creature_template_movement (`CreatureId`,`Ground`,`Swim`,`Flight`,`Rooted`,`Chase`,`Random`,`InteractionPauseTimer`)
SELECT entry+@OFF, 1, (InhabitType&2)>0, IF((InhabitType&4)>0,1,0), 0, 0, 0, 0
FROM nelt_world.creature_template
WHERE entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask IN (2047,8,16,128)) AND (InhabitType&4)>0;

-- creature_template_spell: nelt inline spell1-8 -> this fork's creature_template_spell
-- (spell_dbc rows for Cata ids may be missing -> audit after apply, see 00_README follow-ups)
INSERT IGNORE INTO acore_world.creature_template_spell (`CreatureID`,`Index`,`Spell`,`VerifiedBuild`)
SELECT entry+@OFF, idx, sp, 0 FROM (
  SELECT entry, 0 idx, spell1 sp FROM nelt_world.creature_template WHERE entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask IN (2047,8,16,128)) AND spell1>0
  UNION ALL SELECT entry, 1, spell2 FROM nelt_world.creature_template WHERE entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask IN (2047,8,16,128)) AND spell2>0
  UNION ALL SELECT entry, 2, spell3 FROM nelt_world.creature_template WHERE entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask IN (2047,8,16,128)) AND spell3>0
  UNION ALL SELECT entry, 3, spell4 FROM nelt_world.creature_template WHERE entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask IN (2047,8,16,128)) AND spell4>0
  UNION ALL SELECT entry, 4, spell5 FROM nelt_world.creature_template WHERE entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask IN (2047,8,16,128)) AND spell5>0
  UNION ALL SELECT entry, 5, spell6 FROM nelt_world.creature_template WHERE entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask IN (2047,8,16,128)) AND spell6>0
  UNION ALL SELECT entry, 6, spell7 FROM nelt_world.creature_template WHERE entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask IN (2047,8,16,128)) AND spell7>0
  UNION ALL SELECT entry, 7, spell8 FROM nelt_world.creature_template WHERE entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask IN (2047,8,16,128)) AND spell8>0
) s;

-- creature loot (keyed by lootid, kept un-offset per HyjalCata/29). Drop drops whose
-- item does not exist in item_template (18 such refs) to avoid load-time errors;
-- reference-loot rows (mincountOrRef<0) are always kept.
INSERT IGNORE INTO acore_world.creature_loot_template (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT lt.entry, lt.item, IF(lt.mincountOrRef<0,-lt.mincountOrRef,0), ABS(lt.ChanceOrQuestChance), IF(lt.ChanceOrQuestChance<0,1,0), lt.lootmode, lt.groupid, IF(lt.mincountOrRef<0,1,lt.mincountOrRef), lt.maxcount
FROM nelt_world.creature_loot_template lt
WHERE lt.entry IN (SELECT lootid FROM nelt_world.creature_template WHERE lootid>0 AND entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask IN (2047,8,16,128)))
  AND (lt.mincountOrRef<0 OR lt.item IN (SELECT entry FROM acore_world.item_template));

-- creature_text (nelt: entry -> CreatureID+@OFF; lowercase cols)
INSERT IGNORE INTO acore_world.creature_text (`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,`BroadcastTextId`,`TextRange`,`comment`)
SELECT entry+@OFF, groupid, id, text, type, language, probability, emote, duration, sound, BroadcastTextID, text_range, comment
FROM nelt_world.creature_text
WHERE entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask IN (2047,8,16,128));

-- smart_scripts (entry-based source_type=0, +@OFF). Spells/targets referenced may need
-- their own backfill -> audit after apply.
INSERT IGNORE INTO acore_world.smart_scripts
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,`event_param1`,`event_param2`,`event_param3`,`event_param4`,`action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`target_type`,`target_param1`,`target_param2`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT entryorguid+@OFF, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags, event_param1, event_param2, event_param3, event_param4, action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6, target_type, target_param1, target_param2, target_x, target_y, target_z, target_o, comment
FROM nelt_world.smart_scripts
WHERE source_type=0 AND entryorguid>0 AND entryorguid IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask IN (2047,8,16,128));

-- ========================== GAMEOBJECTS ==============================
-- nelt old-TC GO schema has faction/flags inline -> acore splits into
-- gameobject_template_addon. data24-31/unkInt32 have no 3.3.5 equivalent (dropped).
INSERT IGNORE INTO acore_world.gameobject_template
(`entry`,`type`,`displayId`,`name`,`IconName`,`castBarCaption`,`unk1`,`size`,`Data0`,`Data1`,`Data2`,`Data3`,`Data4`,`Data5`,`Data6`,`Data7`,`Data8`,`Data9`,`Data10`,`Data11`,`Data12`,`Data13`,`Data14`,`Data15`,`Data16`,`Data17`,`Data18`,`Data19`,`Data20`,`Data21`,`Data22`,`Data23`,`AIName`,`ScriptName`,`VerifiedBuild`)
SELECT entry+@OFF, `type`, displayId, name, IconName, castBarCaption, unk1, size, data0, data1, data2, data3, data4, data5, data6, data7, data8, data9, data10, data11, data12, data13, data14, data15, data16, data17, data18, data19, data20, data21, data22, data23, '', '', 0
FROM nelt_world.gameobject_template
WHERE entry IN (SELECT DISTINCT id FROM nelt_world.gameobject WHERE map=861 AND phaseMask IN (2047,8,16,128));

INSERT IGNORE INTO acore_world.gameobject_template_addon (`entry`,`faction`,`flags`,`mingold`,`maxgold`,`artkit0`,`artkit1`,`artkit2`,`artkit3`)
SELECT entry+@OFF, faction, flags, 0, 0, 0, 0, 0, 0
FROM nelt_world.gameobject_template
WHERE entry IN (SELECT DISTINCT id FROM nelt_world.gameobject WHERE map=861 AND phaseMask IN (2047,8,16,128));

-- gameobject loot for chest-type GOs (type=3, Data1 = gameobject_loot id, kept un-offset).
INSERT IGNORE INTO acore_world.gameobject_loot_template (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT lt.entry, lt.item, IF(lt.mincountOrRef<0,-lt.mincountOrRef,0), ABS(lt.ChanceOrQuestChance), IF(lt.ChanceOrQuestChance<0,1,0), lt.lootmode, lt.groupid, IF(lt.mincountOrRef<0,1,lt.mincountOrRef), lt.maxcount
FROM nelt_world.gameobject_loot_template lt
WHERE lt.entry IN (SELECT data1 FROM nelt_world.gameobject_template WHERE `type`=3 AND entry IN (SELECT DISTINCT id FROM nelt_world.gameobject WHERE map=861 AND phaseMask IN (2047,8,16,128)))
  AND (lt.mincountOrRef<0 OR lt.item IN (SELECT entry FROM acore_world.item_template));
