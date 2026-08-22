-- =====================================================================================
-- Cataclysm Shadowfang Keep -- map 825 clone, step 13: GameObject SmartAI
--
-- Fixes this boot spam:
--     Gameobject entry (5400001) has SmartGameobjectAI enabled but no SmartAI entries
--     in the database.
--   (and 5400002, 5400003, 5400018, 5400019)
--
-- 03_templates.sql carried `gameobject_template.AIName` across verbatim, so five GOs
-- declare SmartGameObjectAI -- but 08_smartai.sql only imported `smart_scripts` rows with
-- source_type = 0 (creature). The GameObject half is source_type = 1 and was missed, so
-- those five announce an AI that has no script behind it.
--
-- Same shape as the two earlier misses in this import: creature_template without
-- creature_template_model, gameobject_template without gameobject_template_addon. The
-- parent row comes across and the table that gives it behaviour is a separate one.
--
-- REQUIRES 03_templates.sql (dc_sfk825_gomap).
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- smart_scripts, source_type 1 (gameobject). entryorguid goes through the same dense GO
-- map the templates and spawns used -- NOT a flat offset.
--
-- Column list matches 08: the two AzerothCore columns cata_world lacks (event_param6,
-- target_param4) are omitted and take their defaults.
-- -------------------------------------------------------------------------------------
DELETE FROM `smart_scripts` WHERE `source_type` = 1 AND `entryorguid` BETWEEN 5400000 AND 5409999;
INSERT INTO `smart_scripts`
    (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`,
     `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`,
     `event_param4`, `event_param5`, `action_type`, `action_param1`, `action_param2`,
     `action_param3`, `action_param4`, `action_param5`, `action_param6`,
     `target_type`, `target_param1`, `target_param2`, `target_param3`,
     `target_x`, `target_y`, `target_z`, `target_o`, `comment`)
SELECT
     m.new_entry, s.source_type, s.id, s.link, s.event_type, s.event_phase_mask,
     s.event_chance, s.event_flags, s.event_param1, s.event_param2, s.event_param3,
     s.event_param4, s.event_param5, s.action_type, s.action_param1, s.action_param2,
     s.action_param3, s.action_param4, s.action_param5, s.action_param6,
     s.target_type, s.target_param1, s.target_param2, s.target_param3,
     s.target_x, s.target_y, s.target_z, s.target_o, s.comment
FROM `cata_world`.`smart_scripts` s
JOIN `dc_sfk825_gomap` m ON m.src_entry = s.entryorguid
WHERE s.source_type = 1;

-- -------------------------------------------------------------------------------------
-- Report -- all branches numeric; see the note in 12 about collation in UNION reports.
-- -------------------------------------------------------------------------------------
SELECT 'GO smart_scripts rows (want 5)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `smart_scripts` WHERE `source_type` = 1 AND `entryorguid` BETWEEN 5400000 AND 5409999
UNION ALL SELECT 'GO entries covered (want 5)', CAST(COUNT(DISTINCT `entryorguid`) AS CHAR)
    FROM `smart_scripts` WHERE `source_type` = 1 AND `entryorguid` BETWEEN 5400000 AND 5409999
-- This is the check that silences the boot spam.
UNION ALL SELECT 'GO templates claiming SmartAI with no rows (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template` t
    WHERE t.entry BETWEEN 5400000 AND 5409999 AND t.AIName <> ''
      AND NOT EXISTS (SELECT 1 FROM `smart_scripts` s
                      WHERE s.source_type = 1 AND s.entryorguid = t.entry)
UNION ALL SELECT 'STOCK GO smart_scripts untouched (want 0 in our band)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` WHERE `source_type` = 1 AND `entryorguid` IN (18895, 18971, 18972)
      AND `entryorguid` BETWEEN 5400000 AND 5409999;
