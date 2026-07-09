-- =====================================================================
-- Mount Hyjal / Molten Front Downport  --  65  creature_addon orphan cleanup
-- ---------------------------------------------------------------------
-- 3 creature_addon rows (guids 9010847/9010870/9010872, in Hyjal's
-- 9010000+ guid range) reference a `creature` spawn that no longer exists
-- (deleted or renumbered at some point without cleaning up its addon row),
-- logging at boot:
--   Creature (GUID: N) does not exist but has a record in `creature_addon`
-- Pure data hygiene -- nothing to recreate, just drop the dangling rows.
-- =====================================================================

DELETE FROM `creature_addon` WHERE `guid` IN (9010847,9010870,9010872) AND `guid` NOT IN (SELECT `guid` FROM `creature`);
