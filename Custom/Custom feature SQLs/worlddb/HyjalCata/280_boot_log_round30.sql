-- ---------------------------------------------------------------------------
-- 280  Boot-log round 30 -- the map-750 half of a fresh Errors.log
-- ---------------------------------------------------------------------------
-- Every class below was checked against the live log AND re-derived from the
-- DB, and everything here resolves in `cata_world` or in this DB's own raw
-- twin -- nothing is invented.
--
-- 🔴 SCOPE NOTE, so this is not mistaken for a full clear. The log's biggest
-- blocks are NOT maps 750/861 and are deliberately untouched:
--   * 18 `pickpocketing_loot_template` + 7 `skinning_loot_template` misses are
--     all on **map 820** (the BFD/Ashenvale clone) and **2296** (Castle
--     Nathria).
--   * the `35001xx` SmartAI text ids are Legion Dalaran (map 1413).
--   * `gossip_menu_option` 20506/20515 belong to 3500161-3500589, also Legion
--     Dalaran.
-- Confirmed by joining each id back to `creature.map`, not by eyeballing the
-- entry band.
--
-- Also left alone on purpose, all previously investigated:
--   * WaypointPath 16256 / 17238 / 5391200 -- exist in NO source DB; the base
--     creatures warn identically. Upstream gap.
--   * `npc_darkshore_wisp_circling` unassigned -- 269_ decided this
--     deliberately: FactorySelector checks ScriptName BEFORE AIName, so binding
--     it would kill the wisps' existing SmartAI sparkle.
--   * `reference_loot_template` 24161 >100% and entries 24103/24737 "useless" --
--     24161 matches cata_world exactly and AC treats >100% as a warning.

-- ---- 1. 6 reference loot templates -- 34 map-750 loot tables ---------------
--     Table 'reference_loot_template' Entry 24155 does not exist but it is
--     used by creature_loot_template 1
--
-- The single biggest map-750 item in the log: 6 references pulled in by **34
-- creature loot tables, every one of them a map-750 creature** (verified by
-- joining creature_template.lootid -> creature.map). Until now every drop
-- behind them was silently absent -- `LootTemplate` skips an unresolvable
-- reference, so these creatures have been dropping a short table.
--
-- Imported wholesale from cata_world (46 rows). Checked BEFORE writing, because
-- importing a reference whose contents are missing just moves the error:
--   * 0 of the referenced items are absent from `item_template`
--   * 0 nested references are unresolvable
-- Note the count trap from an earlier round -- `LootStoreItem::IsValid` only
-- validates `Item` when `Reference = 0`, so the item check has to carry that
-- same condition or it reports nonsense.
DELETE FROM acore_world.`reference_loot_template` WHERE `Entry` IN (24072,24108,24151,24152,24155,45000);
INSERT INTO acore_world.`reference_loot_template`
(`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT r.`Entry`, r.`Item`, r.`Reference`, r.`Chance`, r.`QuestRequired`, r.`LootMode`,
       r.`GroupId`, r.`MinCount`, r.`MaxCount`, r.`Comment`
FROM cata_world.`reference_loot_template` r
WHERE r.`Entry` IN (24072,24108,24151,24152,24155,45000);

-- ---- 2. Lurah Wrathvine's last 5 ExtendedCosts -----------------------------
--     Table `(game_event_)npc_vendor` have Item (Entry: 71567) with wrong
--     ExtendedCost (3642) for vendor (3654402), ignore
--
-- 3654402 "Lurah Wrathvine" (map 750) is the Firelands heroic upgrade vendor.
-- 87_ imported 16 of her costs (3629-3641, 3647-3649); **3642-3646 are exactly
-- the gap in the middle** and have been dropping 5 of her 21 items every boot.
--
-- Decoded from the Cata 4.3.4 `ItemExtendedCost.db2` (31 fields vs this fork's
-- 17), taken from the base `enUS/locale-enUS.MPQ` -- the `wow-update-enUS-*`
-- copies are PTCH deltas, not tables. Field positions were CALIBRATED against
-- three rows 87_ already imported (3629/3641/3649) rather than assumed; all
-- three re-read identically, so the two item slots are word 4 and word 5.
-- Every one is the same shape as the existing 16: 1x trade-in + 1x 71617
-- Crystallized Firestone, no honor/arena/currency component.
--
-- 🔴 THE CLIENT NEEDS THESE TOO, and 87_ never shipped them. `ItemHandler.cpp`
-- :965 sends `uint32(item->ExtendedCost)` -- only the ID -- so the client
-- resolves the requirement in its OWN ItemExtendedCost.dbc. With no row it
-- draws the item as costing nothing, the player clicks buy, and the server
-- (which does have the row, via this overlay table) refuses. Server-correct,
-- client-illegible.
--
-- All 21 rows (87_'s 16 AND these 5) were missing from the client DBC -- it was
-- still the stock 982-row file -- so the client half was done for the whole
-- set, not just the new five: ItemExtendedCost.csv/.dbc 982 -> 1,003, 0 ids
-- lost, 0 pre-existing rows changed, deployed to patch-4 + enGB/patch-enGB-3 +
-- the three WarcraftXLHost checkouts + staging, md5 identical across all five.
-- 87_'s 16 items should become legible at the vendor as a side effect.
DELETE FROM acore_world.`itemextendedcost_dbc` WHERE `ID` IN (3642,3643,3644,3645,3646);
INSERT INTO acore_world.`itemextendedcost_dbc`
(`ID`,`HonorPoints`,`ArenaPoints`,`ArenaBracket`,`ItemID_1`,`ItemID_2`,`ItemID_3`,`ItemID_4`,`ItemID_5`,`ItemCount_1`,`ItemCount_2`,`ItemCount_3`,`ItemCount_4`,`ItemCount_5`,`RequiredArenaRating`,`ItemPurchaseGroup`) VALUES
(3642,0,0,0,71146,71617,0,0,0,1,1,0,0,0,0,0),
(3643,0,0,0,71149,71617,0,0,0,1,1,0,0,0,0,0),
(3644,0,0,0,71148,71617,0,0,0,1,1,0,0,0,0,0),
(3645,0,0,0,71147,71617,0,0,0,1,1,0,0,0,0,0),
(3646,0,0,0,70939,71617,0,0,0,1,1,0,0,0,0,0);

-- ---- 3. the 5 trade-in items those costs demand ----------------------------
-- Adding section 2 alone would clear the log line and leave the 5 items
-- unbuyable, so the chain is finished here. **All 16 of 87_'s trade-in tokens
-- exist as item_template rows -- these 5 were the only ones that did not**,
-- which is what made them worth importing rather than writing off as unfinished
-- economy.
--
-- They are the normal-mode Firelands trinkets you hand in for the heroic
-- version: 71146 "Covenant of the Flame" buys 71567 "Covenant of the Flame",
-- and so on for all five. Sourced from the Cata `Item.db2` + `Item-sparse.db2`
-- with the Name field again calibrated on known controls (71361 / 71150 / 71154
-- all re-read correctly).
--
-- 🔴 displayid is taken from each item's HEROIC TWIN, not from Cata. 4 of the 5
-- Cata display ids (100868/100870/100872/100873) are absent from our
-- ItemDisplayInfo, while all 5 twins' displays are present -- and in retail the
-- normal and heroic trinket share an icon, so the twin's display is exact, not
-- a compromise. Shaped like the rest of the downported catalog: appearance
-- shells, stat-less.
--
-- 🔴 THESE 5 DO NEED AN `Item.dbc` ROW -- unlike 275_'s lock keys, which
-- correctly got none. The rule is not "items never need one", it is what the
-- peer group does: all 16 of 87_'s trade-in tokens and all 5 heroic twins have
-- Item.csv/Item.dbc rows, and these are equippable (cls 4 / sub 11 / inv 28)
-- rather than non-equippable quest/key items. More importantly the row must
-- AGREE with the values above: `LoadItemTemplates` cross-checks Class/SubClass/
-- SoundOverrideSubclass/Material/DisplayInfoID/InventoryType/Sheath and, on a
-- mismatch, silently OVERWRITES item_template in memory from Item.dbc on every
-- boot -- so a wrong row is worse than no row.
--
-- ALREADY COMPILED AND DEPLOYED: Item.csv/Item.dbc 153,365 -> 153,370, 0 ids
-- lost, 0 pre-existing rows changed, and the 5 new records byte-match the
-- values in this INSERT. Written to patch-4 + enGB/patch-enGB-3, the three
-- WarcraftXLHost checkouts and staging (md5 identical across all five). All 5
-- DisplayInfoIDs were confirmed present in ItemDisplayInfo.csv first -- an
-- unresolved one renders as a question mark.
DELETE FROM acore_world.`item_template` WHERE `entry` IN (70939,71146,71147,71148,71149);
INSERT INTO acore_world.`item_template`
(`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,`displayid`,`Quality`,`Flags`,`FlagsExtra`,`BuyCount`,`BuyPrice`,`SellPrice`,`InventoryType`,`AllowableClass`,`AllowableRace`,`ItemLevel`,`RequiredLevel`,`maxcount`,`stackable`,`Material`,`sheath`,`bonding`,`VerifiedBuild`) VALUES
(71146,4,11,-1,'Covenant of the Flame',8237450,4,528384,8192,1,0,0,28,-1,-1,378,85,0,1,2,0,1,15595),
(71149,4,11,-1,'Singed Plume of Aviana',8132919,4,528384,8192,1,0,0,28,-1,-1,378,85,0,1,2,0,1,15595),
(71148,4,11,-1,'Soulflame Vial',8443371,4,528384,8192,1,0,0,28,-1,-1,378,85,0,1,2,0,1,15595),
(71147,4,11,-1,'Relic of the Elemental Lords',8135824,4,528384,8192,1,0,0,28,-1,-1,378,85,0,1,2,0,1,15595),
(70939,4,11,-1,'Deathclutch Figurine',8134451,4,528384,8192,1,0,0,28,-1,-1,378,85,0,1,2,0,1,15595);

-- ---- 4. Su'ura Swiftarrow's battlemaster row -------------------------------
--     CreatureTemplate (Entry: 3619908) has UNIT_NPC_FLAG_BATTLEMASTER but no
--     data in `battlemaster_entry` table. Removing flag!
--
-- 3619908 (map 750) is the Silverwing Grove Warsong Gulch battlemaster. Both
-- source DBs give raw 19908 `bg_template = 2`, and **raw 19908 already carries
-- that row here** -- only the clone was missed. Derived, not guessed.
DELETE FROM acore_world.`battlemaster_entry` WHERE `entry` = 3619908;
INSERT INTO acore_world.`battlemaster_entry` (`entry`,`bg_template`)
SELECT 3619908, `bg_template` FROM acore_world.`battlemaster_entry` WHERE `entry` = 19908;

-- ---- 5. Spitelash Siren's dropped heal ------------------------------------
--     SmartAIMgr: Entry 3606195 SourceType 0 Event 7 Action 11 Parameter can
--     not be nullptr, skipped.
--
-- Row id 7 is event 74 FRIENDLY_HEALTH_PCT casting 11640 Renew. `NotNULL` is
-- checking `friendlyHealthPct.radius`, and in THIS fork that struct is
-- (min, max, repeatMin, repeatMax, hpPct, **radius**) -- so the radius is
-- **event_param6**, not param2 as upstream. Ours is 0, so the whole row is
-- dropped at load and the Siren has never healed anything.
--
-- The value is not invented: **raw 6195 exists in this same DB** with the
-- identical row and radius 40, and every other live event-74 row uses 30-40.
-- Copied from its own twin.
UPDATE acore_world.`smart_scripts` s
SET s.`event_param6` = 40
WHERE s.`entryorguid` = 3606195 AND s.`source_type` = 0 AND s.`id` = 7
  AND s.`event_type` = 74 AND s.`event_param6` = 0;

-- ---- 6. gossip text + the 6 map POIs ---------------------------------------
--     Table gossip_menu entry 12726 are using non-existing TextID 17861
--     Table `gossip_menu_option` for menu 1951, id 0 use non-existing
--     ActionPoiID 458, ignoring
--
-- Menu 1951 belongs to "Orgrimmar Grunt" and menu 12726 to "Gorbold Steelhand".
-- The 6 POIs are the Orgrimmar direction pins (Flight Master, Battlemasters,
-- Portals, Stable Master, Hall of Legends, Ethereals) -- the grunt's "Where is
-- ...?" answers. Without them the options render and then do nothing.
--
-- 🔴 THIS IS NOT MAP-750-ONLY. Both menus are shared with the map-1 originals
-- (3296 Orgrimmar Grunt, **82 spawns on map 1**, and 6301 Gorbold Steelhand),
-- which have been equally broken -- the clones 3603296 / 3732979 just made it
-- visible in a map-750 sweep. Gossip menus are global, so the fix lands on
-- stock Orgrimmar as well as the clone; worth knowing before assuming the blast
-- radius is 4 spawns.
--
-- 🔴 nelt_world is NOT usable for the POIs: its `points_of_interest` is MaNGOS-
-- named (`entry,x,y,icon,flags,data,icon_name`) and only has 2 of the 6.
-- cata_world matches this fork's column names and has all six.
DELETE FROM acore_world.`points_of_interest` WHERE `ID` IN (458,459,507,509,510,511);
INSERT INTO acore_world.`points_of_interest` (`ID`,`PositionX`,`PositionY`,`Icon`,`Flags`,`Importance`,`Name`)
SELECT p.`ID`, p.`PositionX`, p.`PositionY`, p.`Icon`, p.`Flags`, p.`Importance`, p.`Name`
FROM cata_world.`points_of_interest` p WHERE p.`ID` IN (458,459,507,509,510,511);

-- npc_text: cata names the emote columns EmoteDelay{i}_{j}/Emote{i}_{j} where
-- this fork uses em{i}_0..em{i}_5. They are POSITIONALLY identical -- verified
-- in ObjectMgr.cpp:6760-6761, which reads `_Delay` then `_Emote` per pair -- so
-- the mapping below is 1:1 and not a reordering.
DELETE FROM acore_world.`npc_text` WHERE `ID` = 17861;
INSERT INTO acore_world.`npc_text`
(`ID`,`text0_0`,`text0_1`,`BroadcastTextID0`,`lang0`,`Probability0`,`em0_0`,`em0_1`,`em0_2`,`em0_3`,`em0_4`,`em0_5`)
SELECT n.`ID`, n.`text0_0`, n.`text0_1`, n.`BroadcastTextID0`, n.`lang0`, n.`Probability0`,
       n.`EmoteDelay0_0`, n.`Emote0_0`, n.`EmoteDelay0_1`, n.`Emote0_1`, n.`EmoteDelay0_2`, n.`Emote0_2`
FROM cata_world.`npc_text` n WHERE n.`ID` = 17861;

-- Verify after apply (all should return 0 rows / the stated counts):
--   SELECT COUNT(*) FROM reference_loot_template
--    WHERE Entry IN (24072,24108,24151,24152,24155,45000);              -> 46
--   SELECT COUNT(*) FROM npc_vendor v WHERE v.entry=3654402
--     AND v.ExtendedCost>0 AND v.ExtendedCost NOT IN
--         (SELECT ID FROM itemextendedcost_dbc);                        -> 0
--   SELECT COUNT(*) FROM itemextendedcost_dbc iec WHERE iec.ID BETWEEN 3629
--     AND 3649 AND NOT EXISTS (SELECT 1 FROM item_template i
--        WHERE i.entry = iec.ItemID_1);                                 -> 0
--   SELECT COUNT(*) FROM battlemaster_entry WHERE entry=3619908;        -> 1
--   SELECT event_param6 FROM smart_scripts
--    WHERE entryorguid=3606195 AND id=7;                                -> 40
--   SELECT COUNT(*) FROM points_of_interest WHERE ID IN
--        (458,459,507,509,510,511);                                     -> 6
--   SELECT COUNT(*) FROM npc_text WHERE ID=17861;                       -> 1
