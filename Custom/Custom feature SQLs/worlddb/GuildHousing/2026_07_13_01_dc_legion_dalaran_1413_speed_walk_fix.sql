-- ---------------------------------------------------------------------------
-- speed_walk fix (Legion Dalaran, map 1413)
-- ---------------------------------------------------------------------------
-- More-db-errors audit pass (2026-07-13): 3 entries have speed_walk=0
-- ("has wrong value (0) in speed_walk, set to 1" boot warning). The server
-- already auto-corrects this in memory at boot, but leaving it 0 in the DB
-- means the warning repeats every restart -- Arena Spectator (3500569),
-- Creature 220011 (3500570), Death Match Maker (3500576).
-- ---------------------------------------------------------------------------
UPDATE `creature_template` SET `speed_walk` = 1 WHERE `entry` IN (3500569,3500570,3500576) AND `speed_walk` = 0;
