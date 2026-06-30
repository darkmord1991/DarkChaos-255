-- ==============================================================================
-- Legion Dalaran (map 1413) post-deployment cleanup patches
-- 1. HoverHeight: all 3500xxx templates were generated with HoverHeight=1 (bug in
--    build_legion_dalaran_sql.py, now fixed to 0). Ground NPCs must not hover.
-- 2. Vault guard (guid 9500578): MovementType=1/wander was set instead of
--    MovementType=2/waypoint; the path_id is already correct in creature_addon.
-- 3. Non-functional Legion portal spawns on map 1413 deleted. WotLK portals in
--    2026_06_27_08_dc_dalaran_portals.sql cover the portal room.
-- 4. Door knockers (type-10 Goober, Data0=2173 Legion anim, no WotLK script).
-- ==============================================================================

-- 1. Zero HoverHeight for all Legion Dalaran creature templates
UPDATE `creature_template` SET `HoverHeight` = 0
WHERE `entry` BETWEEN 3500000 AND 3500999 AND `HoverHeight` != 0;

-- 2. Fix vault guard patrol movement
UPDATE `creature` SET `MovementType` = 2, `wander_distance` = 0 WHERE `guid` = 9500578;

-- 3. Remove non-functional Legion portal spawns
DELETE FROM `gameobject` WHERE `map` = 1413 AND `id` IN (
    4100134, 4100135,                                               -- Dark Lady's Fleet / Skyfire
    4100156, 4100157, 4100158, 4100159, 4100160, 4100161,
    4100162, 4100163, 4100164, 4100165, 4100166, 4100167, 4100168, 4100169, -- portal room (WotLK in file 08)
    4100228, 4100230, 4100233,                                      -- Ice Throne / Consortium Portal / generic Portal
    4100467,                                                         -- Portal out of the Vault (no script)
    4100472, 4100473, 4100474, 4100475, 4100476, 4100477,
    4100497, 4100502, 4100505, 4100668                              -- class-hall / instance / demonic portals
);

-- 4. Remove door knockers
DELETE FROM `gameobject` WHERE `map` = 1413 AND `id` IN (
    4100262, 4100263, 4100278, 4100279
);
