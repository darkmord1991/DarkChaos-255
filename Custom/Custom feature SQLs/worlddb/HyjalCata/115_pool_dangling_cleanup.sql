-- ---------------------------------------------------------------------------
-- 115  Hyjal round-14 -- dangling pool_creature links in the rare pool
-- ---------------------------------------------------------------------------
-- Boot log:
--     `pool_creature` has a non existing creature spawn (GUID: 15000011)
--     defined for pool id (130060017), skipped.   (and the same for 15000013)
--
-- Pool 130060017 is the DC clone of nelt_world pool 60017 -- the world-rare
-- rotation that picks ONE of six spawns.  The backfill reserved a guid per
-- member, but two of the six could not be placed:
--     nelt guid 246248 = Mobus    (50009) at map 0  -5751.31 / 5702.26 / -749.23
--     nelt guid 246397 = Akma'hat (50063) at map 1 -10517.60 /   69.08 /  12.20
-- Those coordinates are Vashj'ir and Uldum respectively -- Cata zones that this
-- server does not host, so there is nowhere to put them.  (The other four --
-- Twilight Firebird on 750, Xariona on 646, and Julak-Doom x2 on 751 -- all
-- landed fine.)
--
-- PoolGroup::CheckPool fails the whole pool if ANY weighted member is missing,
-- so leaving the two orphan links in place risks the rare rotation never
-- spawning at all.  Dropping the two links leaves a coherent 1-of-4 rotation.
-- The Mobus / Akma'hat creature_templates (3650009 / 3650063) are intentionally
-- left in place -- they cost nothing and become spawnable the moment either
-- zone is downported.
-- ---------------------------------------------------------------------------

DELETE pc FROM `pool_creature` pc
LEFT JOIN `creature` c ON c.`guid` = pc.`guid`
WHERE pc.`pool_entry` = 130060017 AND c.`guid` IS NULL;

-- Same class, whole-DB sweep: any other pool link pointing at a spawn row that
-- no longer exists (none known at authoring time; guarded so it is a no-op if
-- the DB is already clean).
DELETE pg FROM `pool_gameobject` pg
LEFT JOIN `gameobject` g ON g.`guid` = pg.`guid`
WHERE pg.`pool_entry` BETWEEN 130000000 AND 130999999 AND g.`guid` IS NULL;
