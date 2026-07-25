-- ---------------------------------------------------------------------------
-- 139  Hyjal round-18 -- the remaining small stuff
-- ---------------------------------------------------------------------------

-- --- (1) KillCredit1 pointing at a creature nobody imported ------------------
--     Creature (Entry: 3652661) lists non-existing creature entry 3654343 in
--     `KillCredit1`.                              (+ 3652871, Druid of the Flame)
-- The offset is correct -- 54343 simply was never cloned.  It exists in
-- nelt_world, so import it rather than blank the credit (blanking would break
-- whatever quest counts these kills).
SET @OFF := 3600000;
SET @NIDS := '54343';

INSERT IGNORE INTO acore_world.creature_template
(`entry`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`speed_swim`,`speed_flight`,`rank`,`dmgschool`,`DamageModifier`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
SELECT entry+@OFF, IF(KillCredit1>0,KillCredit1+@OFF,0), IF(KillCredit2>0,KillCredit2+@OFF,0), name, subname, IconName, gossip_menu_id, minlevel, maxlevel, LEAST(exp,2), faction_A, npcflag, speed_walk, speed_run, speed_swim, speed_fly, `rank`, dmgschool, dmg_multiplier, baseattacktime, rangeattacktime, 1, 1, unit_class, unit_flags, unit_flags2, dynamicflags, family, type, type_flags, lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, MovementType, HoverHeight, Health_mod, Mana_mod, Armor_mod, RacialLeader, movementId, RegenHealth, flags_extra, '', 0
FROM nelt_world.creature_template WHERE FIND_IN_SET(entry, @NIDS);

INSERT IGNORE INTO acore_world.creature_template_model (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT m.entry+@OFF, m.idx, m.mid, m.scale, 1, 0 FROM (
  SELECT entry, 0 idx, modelid1 mid, scale FROM nelt_world.creature_template WHERE FIND_IN_SET(entry,@NIDS) AND modelid1>0
  UNION ALL SELECT entry, 1, modelid2, scale FROM nelt_world.creature_template WHERE FIND_IN_SET(entry,@NIDS) AND modelid2>0
) m
WHERE EXISTS (SELECT 1 FROM acore_world.creature_model_info i WHERE i.DisplayID = m.mid);

INSERT IGNORE INTO acore_world.creature_model_info
(`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
SELECT n.modelid, n.bounding_radius, n.combat_reach, n.gender, n.modelid_other_gender, 0
FROM nelt_world.creature_model_info n
WHERE n.modelid IN (SELECT modelid1 FROM nelt_world.creature_template WHERE FIND_IN_SET(entry,@NIDS) AND modelid1>0);

-- --- (2) spellclick flag with no rows ---------------------------------------
--     npc_spellclick_spells: Creature template 3653163 / 3653354 has
--     UNIT_NPC_FLAG_SPELLCLICK but no data in spellclick table! Removing flag
-- Both were imported by 126_ with the flag but without their spellclick rows.
-- Both exist in nelt_world ("Rope" = the Furnace rappel, "Escape Winds" = the
-- Thermal Jump exit), and dropping the flag would break the interaction.
INSERT IGNORE INTO acore_world.npc_spellclick_spells (`npc_entry`,`spell_id`,`cast_flags`,`user_type`)
SELECT npc_entry+3600000, spell_id, cast_flags, user_type
FROM nelt_world.npc_spellclick_spells WHERE npc_entry IN (53163,53354);

-- --- (3) two entries that really have no SmartAI anywhere --------------------
--     Creature entry (3641092 / 3652444) has SmartAI enabled but no SmartAI
--     entries in the database.
-- Same treatment as 114_/127_: neither has rows in any source DB, so the
-- declaration is just noise.  Guarded, so if rows ever appear this is a no-op.
UPDATE `creature_template` ct SET ct.`AIName` = ''
WHERE ct.`entry` IN (3641092,3652444)
  AND ct.`AIName` = 'SmartAI' AND ct.`ScriptName` = ''
  AND NOT EXISTS (SELECT 1 FROM `smart_scripts` s WHERE s.`entryorguid` = ct.`entry` AND s.`source_type` = 0);
