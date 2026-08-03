-- Dark Chaos - built-in vendor NPCs for the passenger-capable downported mounts (2026-08-03)
--
-- Requires 2026_08_03_00_dc_mount_passenger_seats.sql (Vehicle 1700-1703) to be applied first.
--
-- These ride the mount exactly the way Hakmud of Argus / Gnimo ride the stock
-- Traveler's Tundra Mammoth: ordinary creature_templates seated through
-- vehicle_template_accessory. Vehicle::InstallAllAccessories() is called straight
-- from Unit::Mount(), so they appear the moment the mount is summoned and are
-- removed on dismount by the stock npc_traveler_mammoth_vendor AI (which is fully
-- generic -- it hardcodes no entries, handles the cross-faction SetFaction and the
-- graceful dismount despawn).
--
-- NOTE: travelersyakvendor1/2.m2 and travelersyakseat1/2.m2 in patch-F are NOT these
-- NPCs -- they are decorative cart/howdah geometry and have no CreatureModelData row
-- in retail either. The vendors are normal NPCs with normal displays, as below.
--
-- Seat map (seat_id is the 0-based Vehicle.dbc slot):
--   Grand Expedition Yak      1700  seats 0,1 = players | seats 2,3 = vendors
--   Mighty Caravan Brutosaur  1701  seat  0   = player  | seat  1   = auctioneer
--   Trader's Gilded Brutosaur 1702  seat  0   = player  | seat  1   = auctioneer
--
-- displayid values are stock NPC displays and are safe to swap for flavour.

-- 1) the vendor NPCs
DELETE FROM `creature_template` WHERE `entry` BETWEEN 3463500 AND 3463503;
INSERT INTO `creature_template`
  (`entry`,`name`,`subname`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,
   `unit_class`,`unit_flags`,`unit_flags2`,`type`,`flags_extra`,`AIName`,`ScriptName`,`MovementType`,
   `HoverHeight`,`RegenHealth`,`VerifiedBuild`)
VALUES
(3463500,'Cousin Slowhands','Traveling Trader',80,80,2,1732,896,1,1.14286,1,33536,2048,7,2,'','npc_traveler_mammoth_vendor',0,1,1,0),
(3463501,'Ku-Mo','Expedition Outfitter',80,80,2,1732,7296,1,0.99206,1,33536,2048,7,2,'','npc_traveler_mammoth_vendor',0,1,1,0),
(3463502,'Tally Bigpocket','Caravan Auctioneer',80,80,2,1732,2101377,1,1.14286,1,33536,2048,7,2,'','npc_traveler_mammoth_vendor',0,1,1,0),
(3463503,'Gilda Goldstring','Gilded Caravan Auctioneer',80,80,2,1732,2101377,1,1.14286,1,33536,2048,7,2,'','npc_traveler_mammoth_vendor',0,1,1,0);

-- npcflag: 896 = VENDOR|VENDOR_AMMO|VENDOR_FOOD (clone of Hakmud 32638)
--         7296 = VENDOR|VENDOR_POISON|VENDOR_REAGENT|REPAIR (clone of Gnimo 32639)
--      2101377 = GOSSIP|VENDOR|REPAIR|AUCTIONEER -- one NPC covers the Brutosaur's
--                whole selling point, since the model only exposes two seats.

-- 2) displays (stock displays; creature_model_info already exists for them)
DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 3463500 AND 3463503;
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
(3463500,0,28111,1,1,0),
(3463501,0,28282,1,1,0),
(3463502,0,28282,1,1,0),
(3463503,0,28111,1,1,0);

-- 3) vendor stock -- cloned from the stock mammoth vendors so the item lists stay
--    in sync with whatever those already sell (26 and 61 items respectively).
DELETE FROM `npc_vendor` WHERE `entry` BETWEEN 3463500 AND 3463503;
INSERT INTO `npc_vendor` (`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
SELECT 3463500,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,0 FROM `npc_vendor` WHERE `entry`=32638;
INSERT INTO `npc_vendor` (`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
SELECT 3463501,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,0 FROM `npc_vendor` WHERE `entry`=32639;
INSERT INTO `npc_vendor` (`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
SELECT 3463502,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,0 FROM `npc_vendor` WHERE `entry`=32639;
INSERT INTO `npc_vendor` (`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
SELECT 3463503,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,0 FROM `npc_vendor` WHERE `entry`=32639;

-- 4) dismount lines. npc_traveler_mammoth_vendor calls Talk(SAY_DISMISS) with
--    SAY_DISMISS = GroupID 0; without a row the core logs a creature_text error
--    on every dismount. Type 12 / TextRange 0 matches the stock mammoth vendors.
DELETE FROM `creature_text` WHERE `CreatureID` BETWEEN 3463500 AND 3463503;
INSERT INTO `creature_text`
  (`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,`BroadcastTextId`,`TextRange`,`comment`)
VALUES
(3463500,0,0,'Packing up the stall! Safe travels, friend.',12,0,100,0,0,0,0,0,'Cousin Slowhands <Traveling Trader>'),
(3463500,0,1,'You are putting me down HERE? Fine, fine...',12,0,100,0,0,0,0,0,'Cousin Slowhands <Traveling Trader>'),
(3463501,0,0,'Shutting down the workbench. Come back soon!',12,0,100,0,0,0,0,0,'Ku-Mo <Expedition Outfitter>'),
(3463501,0,1,'Careful with the cargo! ...and with me!',12,0,100,0,0,0,0,0,'Ku-Mo <Expedition Outfitter>'),
(3463502,0,0,'Closing the ledger. Your bids are safe with me.',12,0,100,0,0,0,0,0,'Tally Bigpocket <Caravan Auctioneer>'),
(3463503,0,0,'The gilded books are closed. Do come again.',12,0,100,0,0,0,0,0,'Gilda Goldstring <Gilded Caravan Auctioneer>');

-- 5) seat them on the mounts
DELETE FROM `vehicle_template_accessory` WHERE `entry` IN (3461287,3462402,3462403);
INSERT INTO `vehicle_template_accessory`
  (`entry`,`accessory_entry`,`seat_id`,`minion`,`description`,`summontype`,`summontimer`)
VALUES
(3461287,3463500,2,0,'Grand Expedition Yak - Trader',6,30000),
(3461287,3463501,3,0,'Grand Expedition Yak - Outfitter & Repairer',6,30000),
(3462402,3463502,1,0,'Mighty Caravan Brutosaur - Auctioneer',6,30000),
(3462403,3463503,1,0,'Trader''s Gilded Brutosaur - Auctioneer',6,30000);
