-- ===========================================================================
-- DC heirloom WEAPONS - the second mis-assigned display block
-- ===========================================================================
--
-- SYMPTOM: "Heirloom Zephyr Bow" (300337) renders a blue-and-white checkered
-- box (ErrorCube) instead of a bow. "Heirloom Frostbite Axe" (300334) renders
-- a floating orb. The other six heirloom weapons render NOTHING AT ALL - the
-- character swings an invisible weapon.
--
-- ROOT CAUSE: identical to FIX_HEIRLOOM_DISPLAY_BLOCK.sql, one block lower and
-- missed by it. The eight DC heirloom weapons 300332-300339 were assigned
-- ItemDisplayInfo ids 45001-45008 as a straight sequential block. Those ids
-- were never free - they are pre-existing STOCK display rows built for
-- unrelated slots, and three are still referenced by live stock items:
--
--   45003 -> Manaforged Sphere    (32520)  ModelName Misc_1H_Orb_A_02.mdx
--   45006 -> Demonic Bulwark      (32522)  ModelName Shield_Round_A_01.mdx
--   45008 -> Heretic's Gauntlets  (32529)  ModelName (empty, gauntlet icon)
--
-- So the display rows CANNOT be edited; the items must be repointed.
--
-- WHY ONLY THE BOW CUBED: a component model name is only valid for the folder
-- its InventoryType selects. 300337 is InventoryType 15 (ranged), so the
-- client asks for Item\ObjectComponents\Weapon\Shield_Round_A_01.m2 - shields
-- live in Shield\, so the open fails and the client substitutes
-- Spells\ErrorCube.m2. 300334 got away with an orb because Misc_1H_Orb_A_02
-- really does live in Weapon\ - wrong art, but it opens. The remaining six
-- point at display rows with an EMPTY ModelName (belt / gauntlet / chest
-- rows), so nothing is drawn.
--
-- THE FIX: repoint each weapon to a real, slot-correct stock display. Where
-- Blizzard shipped a WotLK heirloom of the same subclass its display is
-- reused, so the set reads as a coherent heirloom family:
--
--   300332 Flamefury Blade   -> 25646 Venerable Dal'Rend's Sacred Charge
--   300333 Stormfury         -> 29769 Battleworn Thrash Blade
--   300334 Frostbite Axe     -> 60603 Frostblade Hatchet          (no heirloom 1H axe exists)
--   300335 Shadow Dagger     -> 23248 Balanced Heartseeker
--   300336 Arcane Staff      -> 20298 Grand Staff of Jordan
--   300337 Zephyr Bow        -> 30926 Charmed Ancient Bone Bow
--   300338 Arcane Wand       -> 59389 Quartz Crystal Wand         (no heirloom wand exists)
--   300339 Earthshaker Mace  -> 28799 Venerable Mass of McGowan
--
-- Every one of those eight ModelNames and its texture was verified present in
-- the client archives before the ids were chosen.
--
-- ALSO CORRECTED: sheath and material. The block carried SheatheType 1 on all
-- eight; the stock originals use 3 for one-handers, 2 for a staff and 0 for a
-- bow / wand, and 300336 carried SheatheType 7, which is outside the valid
-- 0-6 range. Material for the mace is 2 (metal) to match its new display.
--
-- IMPORTANT - THIS SQL ALONE IS NOT ENOUGH. ObjectMgr::LoadItemTemplates ->
-- enforceDBCAttributes (ObjectMgr.cpp:3534) overwrites item_template.displayid
-- (and class/subclass/Material/InventoryType/sheath) from Item.dbc at load, so
-- a DB-only change is a runtime no-op. The matching Item.dbc rows are already
-- repointed in Custom/CSV DBC/Item.csv, compiled to Custom/DBCs/Item.dbc and
-- deployed to the client (patch-4, patch-enGB-3, patch-enGB-4). The same file
-- must reach the worldserver's data/dbc/ or this script will be stomped back
-- to 45001-45008 at the next start. Keep the two in lockstep.
-- ===========================================================================

UPDATE `item_template` SET `displayid` = 25646, `sheath` = 3                   WHERE `entry` = 300332;
UPDATE `item_template` SET `displayid` = 29769, `sheath` = 3                   WHERE `entry` = 300333;
UPDATE `item_template` SET `displayid` = 60603, `sheath` = 3                   WHERE `entry` = 300334;
UPDATE `item_template` SET `displayid` = 23248, `sheath` = 3                   WHERE `entry` = 300335;
UPDATE `item_template` SET `displayid` = 20298, `sheath` = 2                   WHERE `entry` = 300336;
UPDATE `item_template` SET `displayid` = 30926, `sheath` = 0                   WHERE `entry` = 300337;
UPDATE `item_template` SET `displayid` = 59389, `sheath` = 0                   WHERE `entry` = 300338;
UPDATE `item_template` SET `displayid` = 28799, `sheath` = 3, `Material` = 2   WHERE `entry` = 300339;
