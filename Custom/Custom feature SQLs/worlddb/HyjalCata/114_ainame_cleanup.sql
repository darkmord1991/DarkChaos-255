-- ---------------------------------------------------------------------------
-- 114  Hyjal round-14 -- AIName boot warnings on the clone block
-- ---------------------------------------------------------------------------
-- Two separate boot complaints, same root cause: AIName values that survived
-- the clone but have nothing behind them on this core.
--
-- (a) "Creature (Entry: N) has non-registered `AIName` 'EventAI' set, removing"
--     13 entries carry the old-MaNGOS/TC 'EventAI' string.  AzerothCore has no
--     EventAI registry item, so it strips the value at load and the creature
--     silently falls back to the default AI -- exactly what clearing the column
--     does, minus the error line.  These are all Plaguelands-side clones that
--     came through the same +3,600,000 pipeline (Scarlet Judge, Tirion
--     Fordring, Weldon Barov, ...); their behaviour is unchanged either way
--     because no eventai script rows were ever cloned with them.
--
-- (b) "Creature entry (N) has SmartAI enabled but no SmartAI entries in the
--     database."  Five map-750 entries declare SmartAI with zero smart_scripts
--     rows.  (The other five that used to appear in this list -- 3640031,
--     3675014, 3675026, 3675027, 3675158 -- do have rows; those rows were being
--     skipped wholesale by the un-offset references that 113_ repairs, so they
--     drop off the list once 113_ is applied.  Run 113_ first.)
--
-- Both are cosmetic at runtime; this just stops ~18 lines of boot noise per
-- restart and makes the remaining warnings meaningful again.
-- ---------------------------------------------------------------------------

-- (a) EventAI -> empty (self-deriving over the whole clone block, so it also
--     catches any entry a later import re-introduces)
UPDATE `creature_template` SET `AIName` = ''
WHERE `entry` BETWEEN 3600000 AND 3899999 AND `AIName` = 'EventAI';

-- (b) SmartAI declared with no rows behind it
UPDATE `creature_template` ct SET ct.`AIName` = ''
WHERE ct.`entry` IN (3644403,3675020,3675023,3675031)
  AND ct.`AIName` = 'SmartAI'
  AND ct.`ScriptName` = ''
  AND NOT EXISTS (SELECT 1 FROM `smart_scripts` s WHERE s.`entryorguid` = ct.`entry` AND s.`source_type` = 0);

-- Skarr (990036) is a DC custom entry, not part of the Hyjal clone block, but
-- it produces the identical warning and has no rows either.
UPDATE `creature_template` ct SET ct.`AIName` = ''
WHERE ct.`entry` = 990036 AND ct.`AIName` = 'SmartAI' AND ct.`ScriptName` = ''
  AND NOT EXISTS (SELECT 1 FROM `smart_scripts` s WHERE s.`entryorguid` = ct.`entry` AND s.`source_type` = 0);
