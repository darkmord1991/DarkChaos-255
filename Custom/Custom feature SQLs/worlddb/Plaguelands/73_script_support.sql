-- 73_script_support.sql — map 751 Lordaeron extension, DB step 12.
--
-- The DB half of the C++ pass. THIS FILE only clears a dangling ScriptName;
-- the Scourge Cauldron fix lives in
--   src/server/scripts/DC/Plaguelands/zone_western_plaguelands_dc.cpp
-- and is wired up by 74_cauldron_lords.sql. Stock
-- EasternKingdoms/zone_western_plaguelands.cpp is deliberately NOT modified.
--
-- `npc_oox09hl` (4107806 Homing Robot OOX-09/HL, 1 spawn in the Hinterlands) is
-- **not implemented anywhere in this fork** — grepping src/ for "oox" returns
-- nothing at all, so the name is dead on stock content too, not just on our clone.
-- A ScriptName with no registered script is a load-time complaint and leaves the
-- creature with no AI. Clearing it costs nothing that is not already lost: the
-- escort quest "Rescue OOX-09/HL!" cannot complete either way until someone writes
-- the escort. Keeping the dangling name would only hide that fact behind an error.

UPDATE `creature_template`
SET `ScriptName` = ''
WHERE `entry` BETWEEN 4100000 AND 4199999
  AND `ScriptName` = 'npc_oox09hl';

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'imported templates with a ScriptName' AS what, COUNT(*) AS n
FROM `creature_template` WHERE `entry` BETWEEN 4100000 AND 4199999 AND `ScriptName` <> ''
UNION ALL SELECT '  still dangling on npc_oox09hl', COUNT(*)
FROM `creature_template` WHERE `entry` BETWEEN 4100000 AND 4199999 AND `ScriptName` = 'npc_oox09hl';

-- every remaining ScriptName on our imports, to eyeball against the core
SELECT `ScriptName`, COUNT(*) AS templates
FROM `creature_template`
WHERE `entry` BETWEEN 4100000 AND 4199999 AND `ScriptName` <> ''
GROUP BY `ScriptName` ORDER BY templates DESC;
