-- ---------------------------------------------------------------------------
-- 201  Plaguelands (map 751) -- SmartAI the source has that we never imported
-- ---------------------------------------------------------------------------
-- Same treatment map 750 got in 196_, applied to the other Cata-derived map.
-- 27 creature entries spawned on map 751 have NO smart_scripts here while
-- cata_world defines behaviour for them: 50 rows.
--
-- WHY 751 IS SAFE TO DO THIS TO, and stock maps are not.  Every one of the 27
-- matches its source ONLY through the +3,600,000 / +3,700,000 clone offset --
-- zero of them match by raw id (the map's whole id range is 3600721..3651986).
-- So this is finishing an import that was already made, not changing WotLK
-- content into Cata content.  See the note at the bottom about maps 0/1/530/571,
-- where that distinction reverses.
--
-- SIMPLER THAN 196_: verified zero rows use action lists (80/87/88), zero carry
-- a creature entry in an action param (12/33/36/45/49/66), and zero target a
-- creature by entry (target types 9/11/19).  So entryorguid is the ONLY id that
-- needs remapping -- there is no second or third id class hiding here.
--
-- SPELLS: the 50 rows cast 43 distinct spells.  16 already resolve from the
-- client Spell.dbc; the other 27 are minted by 200_, which MUST RUN FIRST.
-- Checked against the live server dbc, not spell_dbc -- that table is only the
-- additive override and checking it alone reports false positives.
--
-- VALIDATION RULES APPLIED ON THE WAY IN.  199_ had to repair 13 map-750 rows
-- that SmartAIMgr rejects outright ("has unused ..., skipped" -- the row simply
-- never runs).  Rather than import the same defects and clean them up after,
-- the three rules are enforced here as the rows land:
--   SMART_EVENT_LINK (61)           -> takes NO params: all four zeroed
--   SMART_EVENT_VICTIM_CASTING (13) -> uses params 1-3: param4 zeroed
--   SMART_TARGET_VICTIM (2)         -> takes no params: target_param1 zeroed
-- ---------------------------------------------------------------------------

DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (
  SELECT e FROM (SELECT DISTINCT c.`id` AS e FROM `creature` c WHERE c.`map` = 751) x
  WHERE e IN (SELECT CAST(cs.`entryorguid` AS SIGNED) + 3600000 FROM cata_world.smart_scripts cs WHERE cs.`source_type` = 0
              UNION SELECT CAST(cs2.`entryorguid` AS SIGNED) + 3700000 FROM cata_world.smart_scripts cs2 WHERE cs2.`source_type` = 0));

INSERT INTO `smart_scripts`
 (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
  `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,
  `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
  `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,
  `target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT m.our_id, 0, cs.`id`, cs.`link`, cs.`event_type`, cs.`event_phase_mask`, cs.`event_chance`, cs.`event_flags`,
       CASE WHEN cs.`event_type` = 61 THEN 0 ELSE cs.`event_param1` END,
       CASE WHEN cs.`event_type` = 61 THEN 0 ELSE cs.`event_param2` END,
       CASE WHEN cs.`event_type` = 61 THEN 0 ELSE cs.`event_param3` END,
       CASE WHEN cs.`event_type` IN (61, 13) THEN 0 ELSE cs.`event_param4` END,
       0, 0,
       cs.`action_type`, cs.`action_param1`, cs.`action_param2`, cs.`action_param3`,
       cs.`action_param4`, cs.`action_param5`, cs.`action_param6`,
       cs.`target_type`,
       CASE WHEN cs.`target_type` = 2 THEN 0 ELSE cs.`target_param1` END,
       cs.`target_param2`, cs.`target_param3`, 0,
       cs.`target_x`, cs.`target_y`, cs.`target_z`, cs.`target_o`, cs.`comment`
FROM cata_world.smart_scripts cs
JOIN (SELECT DISTINCT c.`id` AS our_id FROM acore_world.creature c WHERE c.`map` = 751) m
  ON cs.`entryorguid` IN (CAST(m.our_id AS SIGNED) - 3600000, CAST(m.our_id AS SIGNED) - 3700000)
WHERE cs.`source_type` = 0
  AND NOT EXISTS (SELECT 1 FROM acore_world.smart_scripts ex
                  WHERE ex.`entryorguid` = m.our_id AND ex.`source_type` = 0);

-- Verify -- expect 0 map-751 entries left with source SmartAI we lack, and no
-- newly-rejected rows in the boot log:
--   SELECT COUNT(DISTINCT c.id) FROM (SELECT DISTINCT id FROM `creature` WHERE map=751) c
--    WHERE NOT EXISTS (SELECT 1 FROM `smart_scripts` s WHERE s.entryorguid=c.id AND s.source_type=0)
--      AND EXISTS (SELECT 1 FROM cata_world.smart_scripts cs WHERE cs.source_type=0
--                  AND cs.entryorguid IN (CAST(c.id AS SIGNED)-3600000, CAST(c.id AS SIGNED)-3700000));
--   SELECT COUNT(*) FROM `smart_scripts` s WHERE s.source_type=0 AND s.action_type=11
--     AND s.entryorguid IN (SELECT DISTINCT id FROM `creature` WHERE map=751)
--     AND s.action_param1 NOT IN (SELECT ID FROM `spell_dbc`);   -- residual = stock spells, fine
--
-- ---------------------------------------------------------------------------
-- NOT DONE, and deliberately so: the same query across the STOCK maps finds
-- 278 entries on Kalimdor, 208 on Eastern Kingdoms, 119 in Outland and 109 in
-- Northrend.  Those match by RAW ID -- they are the SAME creature in both
-- games, and importing Cata's rows would replace live WotLK behaviour with
-- Cataclysm behaviour.  That is a design decision, not a data repair, and it
-- carries two concrete hazards: 43 of them already have a C++ ScriptName (which
-- wins over AIName on this core, so the SmartAI would be dead weight or fight
-- it) and 15 already declare a different AIName.  Left alone pending an
-- explicit call.
-- ---------------------------------------------------------------------------
