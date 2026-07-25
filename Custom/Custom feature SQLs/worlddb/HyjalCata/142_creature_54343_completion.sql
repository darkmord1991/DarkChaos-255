-- ---------------------------------------------------------------------------
-- 142  Hyjal round-20 -- finish the 3654343 import that 139_ started
-- ---------------------------------------------------------------------------
--     Table 'creature_loot_template' Entry 54343 does not exist but it is used
--     by Creature 3654343
--     Creature entry (3654343) has SmartAI enabled but no SmartAI entries in
--     the database.
--
-- Self-inflicted by 139_: it imported "Druid of the Flame" (54343) to satisfy
-- the KillCredit1 on 3652661/3652871, but only brought the template, its models
-- and its model_info -- not the loot table its `lootid` points at, nor the
-- SmartAI rows its `AIName` promises.  nelt_world has both (2 loot rows, 3
-- smart_scripts rows), so this completes the import rather than papering over
-- the two warnings.
--
-- The lootid stays RAW (54343, not offset): that is the convention the whole
-- clone block uses -- creature_template.lootid points at the source table id and
-- the loot rows are imported under it (see 124_ for the same shape).
--
-- Idempotent.
-- ---------------------------------------------------------------------------

INSERT IGNORE INTO acore_world.creature_loot_template
(`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT lt.entry, lt.item, IF(lt.mincountOrRef<0,-lt.mincountOrRef,0), ABS(lt.ChanceOrQuestChance), IF(lt.ChanceOrQuestChance<0,1,0), lt.lootmode, lt.groupid, IF(lt.mincountOrRef<0,1,lt.mincountOrRef), lt.maxcount
FROM nelt_world.creature_loot_template lt
WHERE lt.entry = 54343;

INSERT IGNORE INTO acore_world.smart_scripts
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,`event_param1`,`event_param2`,`event_param3`,`event_param4`,`action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`target_type`,`target_param1`,`target_param2`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT entryorguid+3600000, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags, event_param1, event_param2, event_param3, event_param4, action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6, target_type, target_param1, target_param2, target_x, target_y, target_z, target_o, comment
FROM nelt_world.smart_scripts
WHERE source_type = 0 AND entryorguid = 54343;

-- Apply the standard offset correction to whatever those rows reference, using
-- the same "raw id resolves to nothing but the clone exists" rule as 113_/122_.
UPDATE `smart_scripts` s SET s.`action_param1` = s.`action_param1` + 3600000
WHERE s.`source_type` = 0 AND s.`entryorguid` = 3654343
  AND s.`action_type` IN (12,33)
  AND s.`action_param1` BETWEEN 1 AND 3599999
  AND NOT EXISTS (SELECT 1 FROM `creature_template` a WHERE a.`entry` = s.`action_param1`)
  AND EXISTS (SELECT 1 FROM `creature_template` b WHERE b.`entry` = s.`action_param1` + 3600000);

UPDATE `smart_scripts` s SET s.`target_param1` = s.`target_param1` + 3600000
WHERE s.`source_type` = 0 AND s.`entryorguid` = 3654343
  AND s.`target_type` IN (11,19)
  AND s.`target_param1` BETWEEN 1 AND 3599999
  AND NOT EXISTS (SELECT 1 FROM `creature_template` a WHERE a.`entry` = s.`target_param1`)
  AND EXISTS (SELECT 1 FROM `creature_template` b WHERE b.`entry` = s.`target_param1` + 3600000);

-- ---------------------------------------------------------------------------
-- LESSON (worth applying to any future clone): importing a creature_template
-- alone is never enough.  It drags in, at minimum, creature_template_model +
-- creature_model_info (128_), VehicleId -> vehicle_dbc (137_), display ids ->
-- CreatureDisplayInfo (138_), lootid/pickpocketloot/skinloot -> the loot tables
-- (this file), AIName -> smart_scripts (this file), npcflag SPELLCLICK ->
-- npc_spellclick_spells (139_) and KillCredit -> another template (139_).
-- Every one of those has bitten this downport at least once.
-- ---------------------------------------------------------------------------
