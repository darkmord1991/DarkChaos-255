--
-- DC native request opcodes (CMSG 0x521-0x541): Policy 3 (Log) -> 5 (DropPacket).
--
-- Policy 3 only logged a flood and still processed every packet, and the native
-- transports have no client-side throttle, so the only cap was 150 packets per
-- session update. DropPacket discards what exceeds MaxAllowedCount within one
-- world second before any script hook sees it, and never kicks: a guessed limit
-- that turns out too tight costs a dropped request, not a disconnect.
--
-- Peaks per account and second in dc_addon_protocol_log (2026-10-28/29):
-- 0x541 28, 0x524 18, 0x537 12, 0x534 6, 0x526 5, 0x539 4, 0x52A 2, others 1.
-- Every limit keeps at least 1.6x headroom; 0x541 carries most modules' requests
-- and is raised from 40 to 60. dc_addon_protocol.cpp additionally caps the sum of
-- all of them per account (DcNativeRequestBudgetServerScript).
--
-- Policy values (WorldSession.h, DosProtection::Policy):
--   0 = Process, 1 = Kick, 2 = Ban, 3 = Log, 4 = BlockingThrottle, 5 = DropPacket
-- Apply with .reload antidos_opcode_policies or a restart.
--

-- Tooltip enrichment: bursty by nature (mouse sweeping a bag / spellbook).
DELETE FROM `antidos_opcode_policies` WHERE `Opcode` IN (1313, 1316, 1318, 1335);
INSERT INTO `antidos_opcode_policies` (`Opcode`, `Policy`, `MaxAllowedCount`) VALUES
(1313, 5, 30),  -- 0x521 CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT
(1316, 5, 30),  -- 0x524 CMSG_REQUEST_ITEM_UPGRADE_TOOLTIP
(1318, 5, 30),  -- 0x526 CMSG_REQUEST_NPC_TOOLTIP_INFO
(1335, 5, 30);  -- 0x537 CMSG_REQUEST_ITEM_TOOLTIP_SNAPSHOT

-- Live/periodic snapshots: low steady rate, burst when a frame opens.
DELETE FROM `antidos_opcode_policies` WHERE `Opcode` IN (1320, 1326, 1328, 1330);
INSERT INTO `antidos_opcode_policies` (`Opcode`, `Policy`, `MaxAllowedCount`) VALUES
(1320, 5, 20),  -- 0x528 CMSG_REQUEST_MPLUS_HUD_SNAPSHOT
(1326, 5, 20),  -- 0x52E CMSG_REQUEST_QOS_PING_RELAY
(1328, 5, 20),  -- 0x530 CMSG_REQUEST_HLBG_LIVE_SNAPSHOT
(1330, 5, 20);  -- 0x532 CMSG_REQUEST_SPECTATOR_LIVE_SNAPSHOT

-- Collection bulk sync: bursty at login / on opening the collection UI.
DELETE FROM `antidos_opcode_policies` WHERE `Opcode` IN (1322, 1324, 1332);
INSERT INTO `antidos_opcode_policies` (`Opcode`, `Policy`, `MaxAllowedCount`) VALUES
(1322, 5, 20),  -- 0x52A CMSG_REQUEST_COLLECTION_TRANSMOG_STATE
(1324, 5, 20),  -- 0x52C CMSG_REQUEST_COLLECTION_ITEM_SETS
(1332, 5, 20);  -- 0x534 CMSG_REQUEST_COLLECTION_WAVE1

-- Periodic content feeds.
DELETE FROM `antidos_opcode_policies` WHERE `Opcode` IN (1337, 1339, 1341, 1343);
INSERT INTO `antidos_opcode_policies` (`Opcode`, `Policy`, `MaxAllowedCount`) VALUES
(1337, 5, 10),  -- 0x539 CMSG_REQUEST_SEASONAL
(1339, 5, 10),  -- 0x53B CMSG_REQUEST_HOTSPOT
(1341, 5, 10),  -- 0x53D CMSG_REQUEST_PRESTIGE
(1343, 5, 10);  -- 0x53F CMSG_REQUEST_WORLD_CONTENT

-- The generic native bridge carries most modules' requests over one opcode.
DELETE FROM `antidos_opcode_policies` WHERE `Opcode` IN (1345);
INSERT INTO `antidos_opcode_policies` (`Opcode`, `Policy`, `MaxAllowedCount`) VALUES
(1345, 5, 60);  -- 0x541 CMSG_DC_NATIVE_REQUEST
