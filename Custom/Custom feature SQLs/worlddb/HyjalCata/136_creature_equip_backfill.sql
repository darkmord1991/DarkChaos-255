-- ---------------------------------------------------------------------------
-- 136  Hyjal round-17 -- creature_equip_template: the last big log class
-- ---------------------------------------------------------------------------
-- With the model_info fix in, this is now **1,212 of the 1,612 lines** in
-- Errors.log:
--     Table `creature` have creature (Entry: 3653753) with equipment_id -1 not
--     found in table `creature_equip_template`, set to no equipment.
--
-- `equipment_id = -1` means "pick a random row from creature_equip_template for
-- this entry" (ObjectMgr::GetEquipmentInfo).  The clone pipeline copied the -1
-- onto 1,123 spawns across 106 entries in the 3,600,000 block but never cloned
-- the equipment rows themselves, so every one of them logs on load.
--
-- Cosmetically the core already recovers (it just equips nothing), but this is
-- not only noise: 416 of those spawns are humanoids that SHOULD be visibly
-- armed -- Molten Front druids, flamewakers, sentinels, Twilight casters -- and
-- they have been running around bare-handed.
--
-- Two halves:
--   (a) 247 real equipment rows exist in cata_world for these entries (26 more
--       only in nelt_world).  Imported at the +3,600,000 id.  All 247 rows were
--       checked against item_template first: every ItemID1/2/3 already resolves,
--       so no "not found in `item_template`" follow-on errors.
--   (b) the remainder genuinely never had equipment in ANY source (non-humanoid
--       trash, triggers, critters).  For those the -1 is meaningless, so the
--       spawn is set to equipment_id = 0 -- which is what the core silently does
--       at runtime anyway, minus the log line.
--
-- Both halves are self-deriving over the clone block rather than hardcoded id
-- lists, so a later re-import of 29_/01_mf_templates cannot re-open the gap.
-- Idempotent.
--
-- nelt column names differ (entry / itemEntry1..3) and it has no ID column, so
-- its rows come in as ID = 1 (the first variant).
-- ---------------------------------------------------------------------------

-- --- (a1) real equipment from cata_world (preferred -- supports multi-variant)
INSERT IGNORE INTO acore_world.creature_equip_template
(`CreatureID`,`ID`,`ItemID1`,`ItemID2`,`ItemID3`,`VerifiedBuild`)
SELECT e.CreatureID + 3600000, e.ID, e.ItemID1, e.ItemID2, e.ItemID3, 0
FROM cata_world.creature_equip_template e
WHERE e.CreatureID + 3600000 IN (
        SELECT DISTINCT c.id FROM acore_world.creature c
        WHERE c.equipment_id = -1 AND c.id BETWEEN 3600000 AND 3699999)
  AND NOT EXISTS (SELECT 1 FROM acore_world.creature_equip_template t
                  WHERE t.CreatureID = e.CreatureID + 3600000);

-- --- (a2) nelt_world for the entries cata_world does not cover ---------------
INSERT IGNORE INTO acore_world.creature_equip_template
(`CreatureID`,`ID`,`ItemID1`,`ItemID2`,`ItemID3`,`VerifiedBuild`)
SELECT n.entry + 3600000, 1, n.itemEntry1, n.itemEntry2, n.itemEntry3, 0
FROM nelt_world.creature_equip_template n
WHERE n.entry + 3600000 IN (
        SELECT DISTINCT c.id FROM acore_world.creature c
        WHERE c.equipment_id = -1 AND c.id BETWEEN 3600000 AND 3699999)
  AND NOT EXISTS (SELECT 1 FROM acore_world.creature_equip_template t
                  WHERE t.CreatureID = n.entry + 3600000);

-- --- (b) no equipment data anywhere -> stop asking for a random one ----------
UPDATE `creature` c SET c.`equipment_id` = 0
WHERE c.`equipment_id` = -1
  AND c.`id` BETWEEN 3600000 AND 3699999
  AND NOT EXISTS (SELECT 1 FROM `creature_equip_template` t WHERE t.`CreatureID` = c.`id`);

-- ---------------------------------------------------------------------------
-- NOTE: the same class exists OUTSIDE the 3,600,000 block (~4,500 more spawns
-- across unrelated custom content).  Left alone deliberately -- that is not
-- Hyjal's data and would need its own source-of-truth decision.
-- ---------------------------------------------------------------------------
