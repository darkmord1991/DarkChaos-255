-- ---------------------------------------------------------------------------
-- item_template: Mastery Rating (stat_type 49) + 2 stale InventoryType values
-- ---------------------------------------------------------------------------
-- "Loading Items..." boot log audit (2026-07-14). ObjectMgr::LoadItemTemplates
-- validates item_template.stat_typeN against MAX_ITEM_MOD (=49, i.e. valid
-- range 0-48). 34 real Firelands/BWD loot items (incl. "Andoros, Fist of the
-- Dragon King") carry stat_type=49 -- WotLK's ItemModType enum tops out at
-- ITEM_MOD_BLOCK_VALUE=48; Mastery Rating was introduced in Cataclysm and has
-- ZERO support in this engine (no UI, no combat-rating conversion). Left
-- alone, the engine's own auto-fix silently RETYPES the stat to
-- ITEM_MOD_MANA=0 (value untouched) on every boot -- i.e. these items were
-- actively granting unintended bonus Mana instead of Mastery.
--
-- User's call (2026-07-14): substitute with Haste Rating (36) to preserve the
-- item's full power budget, rather than removing the stat outright. 2 of the
-- 34 items (Quickstep Galoshes 59234, Incineratus 59341) already carry Haste
-- Rating in another stat slot -- substituted Crit Rating (32) for just those
-- two instead, to avoid a duplicate "Haste Rating" tooltip line.
--
-- Also fixed while in this data: Incineratus (59341) and Andoros, Fist of the
-- Dragon King (59459) -- both real Cata one-hand fist weapons -- had
-- item_template.InventoryType=21 (stale/wrong), while Item.dbc already
-- correctly has 13 (INVTYPE_WEAPON); confirmed via the same "Item (Entry: N)
-- has wrong InventoryType value (21), must be 13" boot-log check.
-- ---------------------------------------------------------------------------
UPDATE `item_template` SET `stat_type3` = 36 WHERE `entry` = 59117 AND `stat_type3` = 49;  -- Jumbotron Power Belt
UPDATE `item_template` SET `stat_type3` = 36 WHERE `entry` = 59120 AND `stat_type3` = 49;  -- Poison Protocol Pauldrons
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59122 AND `stat_type4` = 49;  -- Organic Lifeform Inverter
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59216 AND `stat_type4` = 49;  -- Life Force Chargers
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59219 AND `stat_type4` = 49;  -- Power Generator Hood
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59221 AND `stat_type4` = 49;  -- Massacre Treads
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59222 AND `stat_type4` = 49;  -- Spaulders of the Scarred Lady
UPDATE `item_template` SET `stat_type3` = 36 WHERE `entry` = 59223 AND `stat_type3` = 49;  -- Double Attack Handguards
UPDATE `item_template` SET `stat_type4` = 32 WHERE `entry` = 59234 AND `stat_type4` = 49;  -- Quickstep Galoshes (already has Haste in slot3 -> Crit)
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59310 AND `stat_type4` = 49;  -- Chaos Beast Bracers
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59311 AND `stat_type4` = 49;  -- Burden of Mortality
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59314 AND `stat_type4` = 49;  -- Pip's Solution Agitator
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59318 AND `stat_type4` = 49;  -- Sark of the Unwatched
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59320 AND `stat_type4` = 49;  -- Themios the Darkbringer
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59328 AND `stat_type4` = 49;  -- Molten Tantrum Boots
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59329 AND `stat_type4` = 49;  -- Parasitic Bands
UPDATE `item_template` SET `stat_type3` = 36 WHERE `entry` = 59331 AND `stat_type3` = 49;  -- Leggings of Lethal Force
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59335 AND `stat_type4` = 49;  -- Scorched Wormling Vest
UPDATE `item_template` SET `stat_type3` = 32 WHERE `entry` = 59341 AND `stat_type3` = 49;  -- Incineratus (already has Haste in slot4 -> Crit)
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59344 AND `stat_type4` = 49;  -- Dragon Bone Warhelm
UPDATE `item_template` SET `stat_type3` = 36 WHERE `entry` = 59346 AND `stat_type3` = 49;  -- Tunic of Failed Experiments
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59347 AND `stat_type4` = 49;  -- Mace of Acrid Death
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59348 AND `stat_type4` = 49;  -- Cloak of Biting Chill
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59350 AND `stat_type4` = 49;  -- Treads of Flawless Creation
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59353 AND `stat_type4` = 49;  -- Leggings of Consuming Flames
UPDATE `item_template` SET `stat_type3` = 36 WHERE `entry` = 59442 AND `stat_type3` = 49;  -- Rage of Ages
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59444 AND `stat_type4` = 49;  -- Akmin-Kurai, Dominion's Shield
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59451 AND `stat_type4` = 49;  -- Manacles of the Sleeping Beast
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59452 AND `stat_type4` = 49;  -- Crown of Burning Waters
UPDATE `item_template` SET `stat_type3` = 36 WHERE `entry` = 59454 AND `stat_type3` = 49;  -- Shadowblaze Robes
UPDATE `item_template` SET `stat_type3` = 36 WHERE `entry` = 59457 AND `stat_type3` = 49;  -- Shadow of Dread
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 59459 AND `stat_type4` = 49;  -- Andoros, Fist of the Dragon King
UPDATE `item_template` SET `stat_type3` = 36 WHERE `entry` = 59492 AND `stat_type3` = 49;  -- Akirus the Worm-Breaker
UPDATE `item_template` SET `stat_type4` = 36 WHERE `entry` = 63540 AND `stat_type4` = 49;  -- Circuit Design Breastplate

UPDATE `item_template` SET `InventoryType` = 13 WHERE `entry` = 59341 AND `InventoryType` = 21;  -- Incineratus
UPDATE `item_template` SET `InventoryType` = 13 WHERE `entry` = 59459 AND `InventoryType` = 21;  -- Andoros, Fist of the Dragon King
