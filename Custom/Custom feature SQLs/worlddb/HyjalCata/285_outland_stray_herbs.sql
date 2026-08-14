-- ---------------------------------------------------------------------------
-- 285  Delete the 5 DC herb nodes spawned in Outland -- and repair 284_
-- ---------------------------------------------------------------------------
-- 284_ reported these but deliberately left them: 5 gameobjects with +3,600,000
-- DC entries spawned on **map 530 (Outland)**, at coordinates far outside the
-- playable area and with `zoneId = 0, areaId = 0` (the extractor could not
-- resolve an area for them either):
--
--   15050060  3601617 Silverleaf     (7779, -6567, 23)
--   15050061  3601617 Silverleaf     (7951, -6569, 54)
--   15050064  3601618 Peacebloom     (-2282, -11741, 19)
--   15050081  3601622 Bruiseweed     (6301, -6317, 80)
--   15050355  3602045 Stranglekelp   (7498, -6013, -1)
--
-- Checked before removing: no `gameobject_addon`, no `game_event_gameobject`,
-- no `linked_respawn` rows reference any of them, so `gameobject` and
-- `pool_gameobject` are the only tables involved.
--
-- REVERSIBLE. Every row is copied into `dc_stray_go_backup_530` first and the
-- DELETE joins against that table rather than re-deriving the set, so what is
-- removed is exactly what was saved. To undo:
--     INSERT INTO `gameobject` SELECT * FROM `dc_stray_go_backup_530`;
--
-- 🔴 AND IT REPAIRS A MISTAKE IN 284_. That file made every pool single-map by
-- dropping minority-map members, choosing the keeper by majority and breaking
-- ties on the LOWEST map id. Two pools had a 3-way split (530/750/751), so the
-- tie went to **530** -- it kept the Outland junk and dropped the legitimate
-- herb nodes:
--     131011137  kept 15050081 @530, dropped 15050919 @751 and 15051087 @750
--     131013413  kept 15050060 + 15050064 @530, dropped 15050109 @751
-- The pools still load (single-map) and nothing broke, but they now pool only
-- unreachable Outland nodes while three real ones sit unpooled. The tie-break
-- should have preferred the pool's BAND map (130,xxx,xxx -> 750,
-- 131,xxx,xxx -> 751), which is what section 2 restores.

-- ---- 1. back the 5 rows up -------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_stray_go_backup_530` LIKE `gameobject`;

INSERT IGNORE INTO `dc_stray_go_backup_530`
SELECT * FROM `gameobject` WHERE `guid` IN (15050060,15050061,15050064,15050081,15050355);

-- ---- 2. put back the two members 284_ should have kept ---------------------
-- Only the members matching each pool's band map are restored. 15051087 is
-- Plaguebloom on **750** in a 131 (Plaguelands) pool -- restoring it would make
-- the pool cross-map again, and no 130-band counterpart pool exists (checked:
-- counterpart_exists = 0 for all 47 in 284_), so it stays unpooled and simply
-- spawns permanently. That is the pre-existing state, not a new loss.
--
-- `description` is documentation only -- the core never reads it -- so these
-- say what they are rather than imitating the importer's source string.
-- Keyed on `guid` alone, not (pool_entry, guid): `guid` IS the primary key of
-- pool_gameobject, so an object can only ever be in one pool. Deleting by the
-- pair would leave a row behind if the guid had drifted into a different pool,
-- and the INSERT below would then fail on a duplicate key.
DELETE FROM acore_world.`pool_gameobject` WHERE `guid` IN (15050919,15050109);
INSERT INTO acore_world.`pool_gameobject` (`pool_entry`,`guid`,`chance`,`description`) VALUES
(131011137,15050919,0,'restored by 285_ - 284_ tie-break wrongly dropped this map-751 member'),
(131013413,15050109,0,'restored by 285_ - 284_ tie-break wrongly dropped this map-751 member');

-- ---- 3. drop the strays' remaining pool rows, then the spawns --------------
-- The pool rows MUST go first: deleting a gameobject that is still referenced
-- by `pool_gameobject` just converts it into the "non existing gameobject
-- spawn" error 284_ section 1 cleared. 2 of the 5 (15050061, 15050355) already
-- lost their pool rows in 284_; the other 3 are removed here.
DELETE FROM acore_world.`pool_gameobject`
WHERE `guid` IN (15050060,15050061,15050064,15050081,15050355);

DELETE g FROM acore_world.`gameobject` g
JOIN `dc_stray_go_backup_530` b ON b.`guid` = g.`guid`;

-- Verify after apply:
--   SELECT COUNT(*) FROM dc_stray_go_backup_530;                          -> 5
--   SELECT COUNT(*) FROM gameobject WHERE guid IN
--     (15050060,15050061,15050064,15050081,15050355);                     -> 0
--   SELECT COUNT(*) FROM gameobject WHERE id BETWEEN 3600000 AND 3999999
--     AND map NOT IN (750,751,861);                                       -> 2
--        (the 2 survivors are 3809082/3809083, the Lor'danel and Bilgewater
--         portals on map 37 = DC's Azshara Crater. Intentional.)
--   SELECT pool_entry, COUNT(*) FROM pool_gameobject
--    WHERE pool_entry IN (131011137,131013413) GROUP BY pool_entry;
--        -> 1 member each, both on map 751
--   SELECT COUNT(*) FROM pool_gameobject pg
--    WHERE NOT EXISTS (SELECT 1 FROM gameobject g WHERE g.guid=pg.guid);  -> 0
--   SELECT COUNT(*) FROM pool_gameobject;                            -> 34,708
-- Boot log must stay clean on `pool_gameobject` -- no new lines.
