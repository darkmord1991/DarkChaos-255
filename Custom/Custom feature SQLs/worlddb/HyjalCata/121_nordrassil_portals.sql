-- ---------------------------------------------------------------------------
-- 121  Hyjal round-14 -- the two Nordrassil capital portals
-- ---------------------------------------------------------------------------
-- Boot log:
--     Gameobject (Entry: 3809080 GoType: 22) have data0=84505 but Spell (Entry
--     84505) not exist.                      (and 3809081 / 84506)
--
-- 3809080/3809081 are "Portal to Stormwind" / "Portal to Orgrimmar", the
-- Nordrassil hub portals, spawned on map 750 by 30_neltharion_spawn_layer.
-- GoType 22 (SPELL_CASTER) casts data0 on whoever uses the object -- but 84505
-- and 84506 do not exist in Blizzard's Spell.dbc in ANY build available here.
-- 96_ verified this with a dense-neighbour check (84501-84503 and 84507-84511
-- are all present, so it is a real gap in the source data rather than a lookup
-- bug) and left the two entries on the unresolvable tally.
--
-- Round 14 closes them instead of deferring again: 112_ ships two DC-authored
-- TELEPORT_UNITS spells, 300600 "Portal to Stormwind" and 300601 "Portal to
-- Orgrimmar" (same EFFECT_0 target shape as the Molten Front flamegates, ids
-- taken from the free 300588-300699 gap in Custom/CSV DBC/Spell.csv), with
-- spell_target_position rows pointing at this server's own `game_tele` city
-- coordinates.  Pointing the two GOs at them removes the boot error AND makes
-- the portals actually work, which they never have on this server.
--
-- REQUIRES 112_ to be applied first (and the Spell.dbc rebuild for the client
-- to name them; the teleport itself is server-side and works without it).
-- ---------------------------------------------------------------------------

UPDATE `gameobject_template` gt SET gt.`Data0` = 300600
WHERE gt.`entry` = 3809080 AND gt.`Data0` = 84505 AND gt.`type` = 22
  AND EXISTS (SELECT 1 FROM `spell_dbc` s WHERE s.`ID` = 300600);

UPDATE `gameobject_template` gt SET gt.`Data0` = 300601
WHERE gt.`entry` = 3809081 AND gt.`Data0` = 84506 AND gt.`type` = 22
  AND EXISTS (SELECT 1 FROM `spell_dbc` s WHERE s.`ID` = 300601);
