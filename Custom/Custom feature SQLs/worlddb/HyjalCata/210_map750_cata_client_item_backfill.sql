-- ============================================================================
-- 210_map750_cata_client_item_backfill.sql
--
-- Closes out 208 and 209 using real values pulled from the Cataclysm 4.3.4
-- client at K:\UntouchedClients\Cata (build 15050 base MPQs).
--
-- Source files, extracted from Data\enUS\locale-enUS.MPQ:
--   DBFilesClient\Item.db2         WDB2, 64771 records, 8 fields
--   DBFilesClient\Item-sparse.db2  WDB2, 54082 records, 133 fields, 532B records
--   DBFilesClient\ItemDisplayInfo.dbc  WDBC, 55234 records, 25 fields
--
-- The wow-update-enUS-*.MPQ copies of these are PTCH deltas, not usable files.
--
-- Field layout was calibrated against 8 items that exist in BOTH the client and
-- acore_world (52983, 52986, 52325, 52537, 54905, 55136, 55189, 56176). Every
-- one matched on name, Quality, BuyPrice, SellPrice, RequiredLevel, stackable,
-- maxcount, bonding and Material, so the indices below are verified, not guessed.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. The three quest items 209 was blocked on. Real names, finally:
--      52724 = Twilight Communique   (Crate of Scrolls)
--      52725 = Hyjal Battleplans     (Hyjal Battleplans)
--      52789 = Rusted Skull Key      (Gar'gol's Personal Treasure Chest)
--
-- class/subclass/Material/displayid come from Item.db2; the rest from
-- Item-sparse.db2. Flags are deliberately set to 0 rather than carrying the
-- Cata values (65536/65536/0) - Cata and WotLK do not agree on those bits, and
-- every quest item already downported on this server has Flags = 0.
--
-- Also dropped: 52724 and 52725 carry spellid_1 = 75682 / spelltrigger_1 = 5
-- ("read"). Spell 75682 is Cata-only and does not exist on this core, so the
-- spell is left at 0 - right-clicking them does nothing. Harmless while their
-- quests are missing; revisit if the Hyjal quest layer is ever downported.
-- ----------------------------------------------------------------------------

DELETE FROM `item_template` WHERE `entry` IN (52724, 52725, 52789);
INSERT INTO `item_template`
    (`entry`, `class`, `subclass`, `SoundOverrideSubclass`, `name`, `description`, `displayid`,
     `Quality`, `Flags`, `BuyCount`, `BuyPrice`, `SellPrice`, `InventoryType`,
     `AllowableClass`, `AllowableRace`, `ItemLevel`, `RequiredLevel`, `maxcount`, `stackable`,
     `bonding`, `Material`, `sheath`, `BagFamily`, `VerifiedBuild`)
VALUES
    (52724, 0, 0, -1, 'Twilight Communique', '', 65914, 1, 0, 1, 0, 0, 0, -1, -1, 1, 1, 0, 1, 4, 4, 0, 0, 0),
    (52725, 0, 0, -1, 'Hyjal Battleplans', '', 3048, 1, 0, 1, 0, 0, 0, -1, -1, 1, 1, 0, 1, 4, 4, 0, 0, 0),
    (52789, 12, 0, -1, 'Rusted Skull Key', 'It looks like Gar\'gol periodically used this to clean his ears.', 22071, 1, 0, 1, 0, 0, 0, -1, -1, 1, 0, 1, 1, 4, 4, 0, 0, 0);

-- ----------------------------------------------------------------------------
-- 2. Correct the items created in 208 and 209.
--
-- 208 modelled the herbs on the existing Cinderbloom row, which turns out to
-- carry several downport errors of its own (see section 4). The client values
-- below supersede those guesses, and the two placeholder icons are gone:
--
--   entry  name              display   real icon
--   52984  Stormvine          75400    inv_misc_herb_stormvine
--   52985  Azshara's Veil     75396    inv_misc_herb_azsharasveil
--   52987  Twilight Jasmine   75399    inv_misc_herb_twilightjasmine
--   52988  Whiptail           75398    inv_misc_herb_whiptail
--   53063  Mountain Trout     66139    inv_misc_fish_90
--
-- Flags 536870912 = 0x20000000 = ITEM_FLAG_MILLABLE, which means the same thing
-- on WotLK (Lichbloom 36905 already carries it), so it is safe to bring across
-- and makes these herbs millable for Inscription.
--
-- Mountain Trout's real BagFamily is 32768 (bit 15 -> family 16). WotLK's
-- ItemBagFamily.dbc only has ids 0-15, so that bit does not exist here; it is
-- set to 0, matching every other fish on this server.
-- ----------------------------------------------------------------------------

UPDATE `item_template` SET `displayid` = 75400, `ItemLevel` = 82, `RequiredSkill` = 773, `RequiredSkillRank` = 425,
    `stackable` = 20, `BagFamily` = 32, `Flags` = 536870912, `BuyPrice` = 7492, `SellPrice` = 1873 WHERE `entry` = 52984;
UPDATE `item_template` SET `displayid` = 75396, `ItemLevel` = 82, `RequiredSkill` = 773, `RequiredSkillRank` = 450,
    `stackable` = 20, `BagFamily` = 32, `Flags` = 536870912, `BuyPrice` = 8311, `SellPrice` = 2077 WHERE `entry` = 52985;
UPDATE `item_template` SET `displayid` = 75399, `ItemLevel` = 85, `RequiredSkill` = 773, `RequiredSkillRank` = 475,
    `stackable` = 20, `BagFamily` = 32, `Flags` = 536870912, `BuyPrice` = 9448, `SellPrice` = 2362 WHERE `entry` = 52987;
UPDATE `item_template` SET `displayid` = 75398, `ItemLevel` = 84, `RequiredSkill` = 773, `RequiredSkillRank` = 475,
    `stackable` = 20, `BagFamily` = 32, `Flags` = 536870912, `BuyPrice` = 9231, `SellPrice` = 2307 WHERE `entry` = 52988;
UPDATE `item_template` SET `displayid` = 66139, `ItemLevel` = 81, `stackable` = 20, `BagFamily` = 0,
    `BuyPrice` = 1500, `SellPrice` = 375 WHERE `entry` = 53063;

-- ----------------------------------------------------------------------------
-- 3. Wire the last three objects.
-- ----------------------------------------------------------------------------

DELETE FROM `gameobject_loot_template` WHERE `Entry` IN (28483, 28705, 28706);
INSERT INTO `gameobject_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
VALUES
    (28483, 52789, 0, 100, 1, 1, 0, 1, 1, 'Rusted Skull Key'),
    (28705, 52724, 0, 100, 1, 1, 0, 1, 1, 'Twilight Communique'),
    (28706, 52725, 0, 100, 1, 1, 0, 1, 1, 'Hyjal Battleplans');

UPDATE `gameobject_template` SET `Data1` = 28483 WHERE `entry` = 3804580;  -- Gar'gol's Personal Treasure Chest
UPDATE `gameobject_template` SET `Data1` = 28705 WHERE `entry` = 3802968;  -- Crate of Scrolls
UPDATE `gameobject_template` SET `Data1` = 28706 WHERE `entry` = 3802969;  -- Hyjal Battleplans

-- ----------------------------------------------------------------------------
-- 4. OPTIONAL - fix the two Cata herbs that were already here.
--
-- The client says Cinderbloom and Heartblossom should be ItemLevel 81/83,
-- Herbalism 425/450, stack 20, BagFamily 32 (herb bags) and millable. The rows
-- on this server have ItemLevel 25, no skill requirement, stack 1000, BagFamily
-- 0 and no millable flag - the same downport bug in both.
--
-- Without this block Cinderbloom stacks to 1000 while Stormvine next to it
-- stacks to 20, and only the new herbs go in herb bags. Skip this section if
-- you would rather keep the existing behaviour; nothing else depends on it.
-- ----------------------------------------------------------------------------

UPDATE `item_template` SET `ItemLevel` = 81, `RequiredSkill` = 773, `RequiredSkillRank` = 425,
    `stackable` = 20, `BagFamily` = 32, `Flags` = 536870912 WHERE `entry` = 52983;  -- Cinderbloom
UPDATE `item_template` SET `ItemLevel` = 83, `RequiredSkill` = 773, `RequiredSkillRank` = 450,
    `stackable` = 20, `BagFamily` = 32, `Flags` = 536870912 WHERE `entry` = 52986;  -- Heartblossom

-- ============================================================================
-- CLIENT SIDE - ALREADY DONE, STILL NEEDS DEPLOYING
--
--   Custom/CSV DBC/ItemDisplayInfo.csv gained 6 rows (65914, 66139, 75396,
--   75398, 75399, 75400), copied field-for-field from the Cata DBC. The Cata
--   and 3.3.5 layouts are both 25 fields / 100-byte records, and Cata's 75397
--   is byte-identical to the row already in our CSV, so no translation needed.
--   Display ids 3048 and 22071 were already present - nothing to add for them.
--
--   4 icon BLPs were extracted from Data\enUS\locale-enUS.MPQ and staged into
--   K:\Dark-Chaos\retailextracts\_items_iconfix\interface\icons\ :
--     inv_misc_herb_azsharasveil.blp   inv_misc_herb_whiptail.blp
--     inv_misc_fish_90.blp             inv_letter_22.blp
--   inv_misc_herb_stormvine.blp was already staged there;
--   inv_misc_herb_twilightjasmine.blp is already staged in mpq_patches\patch-E.
--   All are BLP2 with byte 11 = 0x11, so the hasMips=2 green-texture trap does
--   not apply.
--
--   REMAINING STEP: recompile ItemDisplayInfo.csv (csv2wdbc.py) and pack it
--   plus the staged icons into the client patch (mpq_stormlib_patch.py -> patch-4
--   for the DBC, the icon patch for the BLPs). Until that ships, the five items
--   above will show a red question mark on the client even though the server
--   side is correct.
-- ============================================================================
