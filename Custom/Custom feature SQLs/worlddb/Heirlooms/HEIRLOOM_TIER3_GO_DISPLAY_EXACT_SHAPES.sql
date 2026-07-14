-- ====================================================================================
-- HEIRLOOM TIER 3 CACHES - EXACT ITEM SHAPES (PART B)
-- ====================================================================================
-- Upgrades the 7 "INTERIM" caches from HEIRLOOM_TIER3_GO_DISPLAY_ITEMSHAPES.sql to
-- purpose-made GameObjectDisplayInfo rows (4595001-4595007) that render the exact
-- weapon/armor shape (real axe, bow, dagger, wand, polearm; legplate; bracer).
--
-- !!! DEPENDENCY: these displayIds live in Custom/CSV DBC/GameObjectDisplayInfo.csv and
-- only exist client-side AFTER the patch-4 DBC has been rebuilt and deployed
-- (csv2wdbc.py -> mpq_stormlib_patch.py -> sync-dbc-deploy.js) and the server dbc copy
-- refreshed. Do NOT apply this file until that deploy is done, or these caches will be
-- invisible until then. Part A already gives every cache a working stock-model prop.
-- ====================================================================================

UPDATE `gameobject_template` SET `displayId`=4595001 WHERE `entry`=1991003; -- Frostbite Axe -> HumanAxe01
UPDATE `gameobject_template` SET `displayId`=4595006 WHERE `entry`=1991004; -- Shadow Dagger -> Knife_1H_Northrend_C_03
UPDATE `gameobject_template` SET `displayId`=4595002 WHERE `entry`=1991006; -- Zephyr Bow    -> HumanBow01
UPDATE `gameobject_template` SET `displayId`=4595007 WHERE `entry`=1991007; -- Arcane Wand   -> Wand_1H_IcecrownRaid_D_02
UPDATE `gameobject_template` SET `displayId`=4595003 WHERE `entry`=1991009; -- Polearm       -> HumanSpear01

-- Wrist / bracers -> ArmorBracerTrim
UPDATE `gameobject_template` SET `displayId`=4595005 WHERE `entry`=1991019; -- Vambraces of Might
UPDATE `gameobject_template` SET `displayId`=4595005 WHERE `entry`=1991020; -- Bracers of Battle
UPDATE `gameobject_template` SET `displayId`=4595005 WHERE `entry`=1991021; -- Cuffs of the Magi

-- Legs -> ArmorLegPlateTrim
UPDATE `gameobject_template` SET `displayId`=4595004 WHERE `entry`=1991028; -- Legplates of the Conqueror
UPDATE `gameobject_template` SET `displayId`=4595004 WHERE `entry`=1991029; -- Leggings of Swiftness
UPDATE `gameobject_template` SET `displayId`=4595004 WHERE `entry`=1991030; -- Pants of the Arcane
