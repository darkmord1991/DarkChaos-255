-- Path-less waypoint (MovementType=2) clones on maps 750/751 have no creature_addon.path_id (the nelt
-- source had no path either), so they freeze + spam "creature has no waypoint path assigned". Demote to
-- idle (0) — same visual (standing at spawn) but no warning. Idempotent.
UPDATE acore_world.creature SET MovementType=0, wander_distance=0
WHERE map IN (750,751) AND MovementType=2
  AND guid NOT IN (SELECT guid FROM acore_world.creature_addon WHERE path_id>0);
