-- ---------------------------------------------------------------------------
-- 182  Hyjal round-45 -- remove double-cloned flight-master spawns
-- ---------------------------------------------------------------------------
-- Ships with the round-45 taxi expansion (16 -> 27 nodes on map 750).
--
-- Two flight masters stand on top of themselves: an earlier pass applied the
-- +3,600,000 Hyjal offset to entries that ALREADY carried the +3,700,000
-- border-zone offset, producing a second template at id+3.6M and a second spawn
-- at the identical position.
--
--   Maethrya  3711138  +  7311138   (6801, -4742)  Everlook
--   Yugrek    3711139  +  7311139   (6815, -4610)  Everlook
--
-- Two flight masters at one spot means two pins on the flight map and two
-- gossip NPCs in the same square metre.  The 7.3M copy goes; the 3.7M entry is
-- the one the taxi network binds to.
--
-- SCOPE IS DELIBERATELY NARROW.  The 7.3M band holds 12 entries / 23 spawns on
-- this map, but only these 2 are provable duplicates -- same entry at id-3.6M,
-- same map, within 5 yards.  The other 10 (Faustron, Sindrayl, Mishellena,
-- Kroum and friends) are the ONLY spawn of their flight master and must stay.
-- Do not widen this to "delete the 7.3M band".
--
-- Friz Groundspin is NOT touched here: its two spawns (3650367 and 3637005) are
-- different entries 48 yards apart, not a clone pair.  The taxi node binds to
-- 3637005, which sits 3.3 yds from Cata's Southern Rocketway node; 3650367 is
-- left in place pending a look at whether it is a distinct NPC.
-- ---------------------------------------------------------------------------

DELETE FROM `creature_addon`
WHERE `guid` IN (SELECT `guid` FROM (
  SELECT a.`guid` FROM `creature` a
  JOIN `creature` b ON b.`id` = a.`id` - 3600000 AND b.`map` = 750
                   AND ABS(b.`position_x` - a.`position_x`) < 5
                   AND ABS(b.`position_y` - a.`position_y`) < 5
  WHERE a.`map` = 750 AND a.`id` BETWEEN 7300000 AND 7399999) t);

DELETE a FROM `creature` a
JOIN `creature` b ON b.`id` = a.`id` - 3600000 AND b.`map` = 750
                 AND ABS(b.`position_x` - a.`position_x`) < 5
                 AND ABS(b.`position_y` - a.`position_y`) < 5
WHERE a.`map` = 750 AND a.`id` BETWEEN 7300000 AND 7399999;

-- Verify -- expect 0 rows (no flight master sharing a spot with its own clone):
--   SELECT a.id, b.id, t.name FROM `creature` a
--     JOIN `creature` b ON b.id = a.id - 3600000 AND b.map = 750
--     JOIN `creature_template` t ON t.entry = a.id
--    WHERE a.map = 750 AND ABS(b.position_x - a.position_x) < 5;
