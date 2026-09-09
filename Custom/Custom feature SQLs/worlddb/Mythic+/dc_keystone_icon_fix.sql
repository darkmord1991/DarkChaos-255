/*
 * Mythic+ Keystone icon fix
 *
 * The 19 keystone items (300313-300331) were sitting on displayid 32837, whose
 * ItemDisplayInfo row is the Polearm_2H_PVPAlliance_A_01 entry with inventory icon
 * INV_Sword_20 - hence the "it looks like a sword" report. (The original
 * dc_keystone_items.sql shipped 68750 = inv_staff_2h_plunderkey_c_02_gold, a
 * key-headed staff; something later overwrote it with 32837. Neither is right.)
 *
 * Correct icon: retail's Mythic Keystone (item 158923) points at
 * IconFileDataID 525134 = interface/icons/inv_relics_hourglass.blp. That icon is
 * already shipped in the client (patch-F.MPQ), and ItemDisplayInfo row 8525134
 * already carries it (present in ItemDisplayInfo.dbc on the server and in
 * patch-4 / patch-enGB-3 / patch-enGB-4), so no new client art is needed.
 *
 * Client-side Item.dbc carried the same 32837 and has been repointed to 8525134
 * as well (Custom/CSV DBC/Item.csv + Custom/DBCs/Item.dbc).
 */

UPDATE `item_template` SET `displayid` = 8525134 WHERE `entry` BETWEEN 300313 AND 300331;

-- item_template edits are invisible to any client that already cached the entry in
-- Cache\WDB\<locale>\itemcache.wdb; bump cache_id so clients drop their WDB at next login.
UPDATE `version` SET `cache_id` = `cache_id` + 1;
