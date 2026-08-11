-- =============================================================================
-- Legion Dalaran (map 1413) -- Phase A: reuse OUR OWN stock 3.3.5 data
-- =============================================================================
-- The 2026-06-27 import shipped creature_template/spawns/vendors/trainers/
-- creature_text but NO gossip at all: 207 of 217 gossip-flagged NPCs on map 1413
-- have gossip_menu_id = 0 and there is not one npc_text row in the 3500000+ band,
-- so clicking them does nothing.
--
-- Dalaran was a WotLK city too, so 252 of these NPCs are name-identical to NPCs
-- we ALREADY have working data for. This file repoints the unambiguous ones
-- (match on BOTH name and subname, and exactly ONE distinct stock menu / stock
-- vendor) at that existing data. Nothing is copied or duplicated: gossip menus
-- are shared by design, and vendor rows are cloned by SELECT so item ids,
-- maxcount, incrtime and ExtendedCost stay in sync with the stock row.
--
-- Ambiguous names are deliberately NOT touched (e.g. "Thrall" has 12 stock
-- entries with different menus). Nor are NPCs whose stock twin has no menu.
-- No quests are wired up (guild-house content does not need them).
--
-- Safe to re-run. Requires a worldserver restart (creature_template is cached).
-- =============================================================================

-- ---------- 1. Gossip menus (44 NPCs) ----------
-- Deliberately EXCLUDED: 3500513 Lieutenant Sinclari -> menu 9997. That menu's
-- options drive the Violet Hold instance event ("send me in now!") and would be
-- a dead or erroring option inside a guild house.
--
-- Menu 10043 is the WotLK Dalaran city-guide ("Points of Interest", Bank, Inn,
-- Trainers ...). Its 17 citizens below get real conversations immediately, BUT
-- its sub-menus point at points_of_interest rows whose coordinates are map-571
-- Dalaran, so the map arrow will land in the wrong place until Phase B replaces
-- them with 1413-space POIs. Text is correct meanwhile.

UPDATE `creature_template` SET `gossip_menu_id` = 10656 WHERE `entry` = 3500030; -- Reginald Arcfire (Steam-Powered Auctioneer)
UPDATE `creature_template` SET `gossip_menu_id` = 10180 WHERE `entry` = 3500102; -- Jepetto Joybuzz (Toymaker)
UPDATE `creature_template` SET `gossip_menu_id` = 9821  WHERE `entry` = 3500104; -- Tassia Whisperglen (Stable Master)
UPDATE `creature_template` SET `gossip_menu_id` = 9781  WHERE `entry` = 3500123; -- Kizi Copperclip (Barber)
UPDATE `creature_template` SET `gossip_menu_id` = 9777  WHERE `entry` = 3500127; -- Archmage Celindra (Portal Trainer)
UPDATE `creature_template` SET `gossip_menu_id` = 9733  WHERE `entry` = 3500129; -- Isirami Fairwind (Innkeeper)
UPDATE `creature_template` SET `gossip_menu_id` = 10139 WHERE `entry` = 3500135; -- Uda the Beast (Innkeeper)
UPDATE `creature_template` SET `gossip_menu_id` = 10201 WHERE `entry` = 3500144; -- Amisi Azuregaze (Innkeeper)
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500148; -- Archivist Betha (City Historian)
UPDATE `creature_template` SET `gossip_menu_id` = 9838  WHERE `entry` = 3500149; -- Andrew Matthews (Guild Master)
UPDATE `creature_template` SET `gossip_menu_id` = 9832  WHERE `entry` = 3500150; -- Elizabeth Ross (Tabard Vendor)
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500161; -- Adorean Lew
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500162; -- Bitty Frostflinger
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500163; -- Arcanist Alec
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500164; -- Linda Ann Kastinglow
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500165; -- Crafticus Mindbender
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500166; -- Grezla the Hag
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500167; -- Fabioso the Fabulous
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500168; -- Grindle Firespark
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500169; -- Magus Fansy Goodbringer
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500171; -- Kitz Proudbreeze
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500172; -- The Magnificent Merleaux
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500173; -- Sabriana Sorrowgaze
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500174; -- Emeline Fizzlefry
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500175; -- Archmage Tenaj
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500176; -- Darthalia Ebonscorch
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500177; -- Whirt the All-Knowing
UPDATE `creature_template` SET `gossip_menu_id` = 9825  WHERE `entry` = 3500194; -- High Arcanist Savor
UPDATE `creature_template` SET `gossip_menu_id` = 10854 WHERE `entry` = 3500195; -- Shandy Glossgleam
UPDATE `creature_template` SET `gossip_menu_id` = 7414  WHERE `entry` = 3500287; -- Prophet Velen
UPDATE `creature_template` SET `gossip_menu_id` = 7947  WHERE `entry` = 3500333; -- Griftah (Amazing Amulets)
UPDATE `creature_template` SET `gossip_menu_id` = 10775 WHERE `entry` = 3500335; -- Master Apothecary Faranell
UPDATE `creature_template` SET `gossip_menu_id` = 7465  WHERE `entry` = 3500357; -- Vindicator Boros
UPDATE `creature_template` SET `gossip_menu_id` = 9542  WHERE `entry` = 3500359; -- Orik Trueheart
UPDATE `creature_template` SET `gossip_menu_id` = 7465  WHERE `entry` = 3500363; -- Vindicator Boros
UPDATE `creature_template` SET `gossip_menu_id` = 8541  WHERE `entry` = 3500376; -- Lonika Stillblade (Rogue Academy Proprietor)
UPDATE `creature_template` SET `gossip_menu_id` = 4577  WHERE `entry` = 3500379; -- Erion Shadewhisper (Rogue Trainer)
UPDATE `creature_template` SET `gossip_menu_id` = 411   WHERE `entry` = 3500382; -- Hulfdan Blackbeard (Rogue Trainer)
UPDATE `creature_template` SET `gossip_menu_id` = 4561  WHERE `entry` = 3500383; -- Fenthwick (Rogue Trainer)
UPDATE `creature_template` SET `gossip_menu_id` = 6650  WHERE `entry` = 3500386; -- Zelanis (Rogue Trainer)
UPDATE `creature_template` SET `gossip_menu_id` = 4690  WHERE `entry` = 3500391; -- Frahun Shadewhisper (Rogue Trainer)
UPDATE `creature_template` SET `gossip_menu_id` = 9542  WHERE `entry` = 3500447; -- Orik Trueheart
UPDATE `creature_template` SET `gossip_menu_id` = 10096 WHERE `entry` = 3500479; -- Archmage Timear
UPDATE `creature_template` SET `gossip_menu_id` = 7414  WHERE `entry` = 3500533; -- Prophet Velen

-- ---------- 2. Vendor inventories (10 NPCs, 102 item rows) ----------
-- Cloned by SELECT from the stock twin so item/maxcount/incrtime/ExtendedCost
-- and VerifiedBuild stay identical. These NPCs already carry the vendor npcflag
-- and currently open an EMPTY shop window.

DELETE FROM `npc_vendor` WHERE `entry` IN
 (3500129, 3500130, 3500131, 3500133, 3500134, 3500135, 3500143, 3500144, 3500146, 3500147);

INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, `VerifiedBuild`)
SELECT m.dst, v.`slot`, v.`item`, v.`maxcount`, v.`incrtime`, v.`ExtendedCost`, v.`VerifiedBuild`
FROM `npc_vendor` v
JOIN (
  SELECT 3500129 AS dst, 32413 AS src UNION ALL  -- Isirami Fairwind (Innkeeper)
  SELECT 3500130, 32421 UNION ALL                -- Marcella Bloom (Barmaid)
  SELECT 3500131, 28682 UNION ALL                -- Inzi Charmlight (Barmaid)
  SELECT 3500133, 32424 UNION ALL                -- Laire Brewgold (Brewmaiden)
  SELECT 3500134, 32426 UNION ALL                -- Coira Longrifle (Brewmaiden)
  SELECT 3500135, 31557 UNION ALL                -- Uda the Beast (Innkeeper)
  SELECT 3500143, 32412 UNION ALL                -- Mato (Food & Drink)
  SELECT 3500144, 28687 UNION ALL                -- Amisi Azuregaze (Innkeeper)
  SELECT 3500146, 32403 UNION ALL                -- Sandra Bartan (Barmaid)
  SELECT 3500147, 29049                          -- Arille Azuregaze (Bartender)
) m ON m.src = v.`entry`;
