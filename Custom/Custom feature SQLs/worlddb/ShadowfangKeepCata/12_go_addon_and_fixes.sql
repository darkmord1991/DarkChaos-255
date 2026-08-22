-- =====================================================================================
-- Cataclysm Shadowfang Keep -- map 825 clone, step 12: gameobject_template_addon
--
-- THIS IS THE FIX FOR "the courtyard door is open by itself and all cell doors are open".
--
-- GameObject FLAGS do not live in gameobject_template on this fork -- they live in
-- `gameobject_template_addon`. 03_templates.sql imported the templates and not the addon
-- rows, so every door came across with flags 0 instead of 34
-- (GO_FLAG_LOCKED 0x02 | GO_FLAG_NODESPAWN 0x20) and therefore renders unlocked and open.
--
-- Same shape of miss as `creature_template_model` in step 11: the parent table imported
-- fine and the thing that actually governs behaviour sits in a side table.
--
-- REQUIRES 03_templates.sql (dc_sfk825_gomap).
--
-- ---------------------------------------------------------------------------------
-- THE OTHER HALF OF THIS BUG IS IN C++, AND IS ALREADY FIXED
-- ---------------------------------------------------------------------------------
-- `sfk_cata.h` declared the door and creature ids as the CATACLYSM SOURCE values
-- (GO_COURTYARD_DOOR = 18895, BOSS_BARON_ASHBURY = 46962, ...). The clone's objects are
-- 5,400,000+ / +5,000,000, so `creature->GetEntry()` and `OnGameObjectCreate` matched
-- nothing: no boss was tracked, no door was bound to an encounter, and every
-- SummonCreature asked for an entry that does not exist in this database. The header now
-- carries the clone ids and the worldserver has been rebuilt -- deploy that binary along
-- with this file or the doors will still not respond to encounter progress.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- gameobject_template_addon -- 43 rows, entry remapped through the same dense map the
-- templates used. Schema is a clean 1:1.
--
-- `flags` is the field that matters here; `faction`, `mingold`/`maxgold` and the
-- artkit/WorldEffect columns come across untouched.
-- -------------------------------------------------------------------------------------
DELETE FROM `gameobject_template_addon` WHERE `entry` BETWEEN 5400000 AND 5409999;
INSERT INTO `gameobject_template_addon`
    (`entry`, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`)
SELECT m.new_entry, a.faction, a.flags, a.mingold, a.maxgold,
       a.artkit0, a.artkit1, a.artkit2, a.artkit3
FROM `cata_world`.`gameobject_template_addon` a
JOIN `dc_sfk825_gomap` m ON m.src_entry = a.entry;

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
-- NOTE: every branch returns CAST(<number> AS CHAR). Do NOT pull a value out of a text
-- column here -- gameobject_template.name is utf8mb4_unicode_ci while a string literal
-- takes the connection collation, and mixing them in one UNION fails outright with
-- SQL error 1271 "Illegal mix of collations", taking the whole report block down with it.
-- (An earlier revision of this file listed the door names and did exactly that; the INSERT
-- above had already succeeded, so only the report was lost.)
SELECT 'gameobject_template_addon rows (want 43)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `gameobject_template_addon` WHERE `entry` BETWEEN 5400000 AND 5409999
UNION ALL SELECT 'GO templates with NO addon row (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template` t WHERE t.entry BETWEEN 5400000 AND 5409999
      AND NOT EXISTS (SELECT 1 FROM `gameobject_template_addon` a WHERE a.entry = t.entry)
-- The doors and the gate must all carry GO_FLAG_LOCKED (0x02) -- this is the check that
-- actually says whether the "doors are open by themselves" bug is gone.
UNION ALL SELECT 'doors/gates missing GO_FLAG_LOCKED (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template` t
    LEFT JOIN `gameobject_template_addon` a ON a.entry = t.entry
    WHERE t.entry BETWEEN 5400000 AND 5409999 AND t.type = 0
      AND (a.entry IS NULL OR (a.flags & 0x02) = 0)
UNION ALL SELECT 'doors/gates carrying flags 34 (want 6)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template` t
    JOIN `gameobject_template_addon` a ON a.entry = t.entry
    WHERE t.entry BETWEEN 5400000 AND 5409999 AND t.type = 0 AND a.flags = 34
-- Stock must be untouched.
UNION ALL SELECT 'STOCK 18895 courtyard door flags (want 34)',
    CAST((SELECT `flags` FROM `gameobject_template_addon` WHERE `entry` = 18895) AS CHAR);
