--
-- AntiDos policies for the DC custom (native bridge) client->server opcodes.
--
-- WorldSession::DosProtection::EvaluateOpcode counts inbound opcodes per world
-- second and applies `Policy` once `MaxAllowedCount` is exceeded. Policy values
-- (WorldSession.h, enum class DosProtection::Policy):
--   0 = Process, 1 = Kick, 2 = Ban, 3 = Log, 4 = BlockingThrottle, 5 = DropPacket
--
-- Every row below uses Policy 3 (Log) ON PURPOSE. These limits are estimates,
-- not measurements: nobody has profiled the real peak rate of a login-time
-- Collection wave1 sync or a player sweeping the mouse across a full bag of
-- items. Arming Kick on a guess risks kicking legitimate players mid-sync, and
-- a kick is a far worse outcome than a log line. Run with Log, watch for
-- "AntiDOS: ... flooding packet (opc: ...)" in the network log, then tighten
-- MaxAllowedCount to the observed peak and switch Policy to 1 (Kick) for the
-- opcodes that have proven headroom.
--
-- Only DC-custom opcodes (>= 0x520) are listed. Deliberately NOT included:
-- CMSG_MESSAGECHAT (0x095), which carries the addon-message transport. That
-- opcode also carries every /say, /whisper and /party message, and both share a
-- single counter -- a limit tight enough to catch an addon flood would kick
-- players for chatting quickly in a raid. Addon whispers additionally bypass
-- Player::CanSpeak(), so no chat-flood interplay exists to lean on. Rate control
-- for that transport lives client-side in the DC-AddonProtocol token bucket
-- (DC:_SendAddonWhisper, /dc throttle).
--

-- User-initiated, rare.
DELETE FROM `antidos_opcode_policies` WHERE `Opcode` IN (1312);
INSERT INTO `antidos_opcode_policies` (`Opcode`, `Policy`, `MaxAllowedCount`) VALUES
(1312, 3, 5);    -- 0x520 CMSG_TELEPORT_GRAVEYARD_REQUEST

-- Tooltip enrichment: bursty by nature (mouse sweeping a bag / spellbook).
-- Historically the single largest share of DC protocol volume, so keep headroom.
DELETE FROM `antidos_opcode_policies` WHERE `Opcode` IN (1313, 1316, 1318, 1335);
INSERT INTO `antidos_opcode_policies` (`Opcode`, `Policy`, `MaxAllowedCount`) VALUES
(1313, 3, 30),   -- 0x521 CMSG_REQUEST_SPELL_TOOLTIP_ENRICHMENT
(1316, 3, 30),   -- 0x524 CMSG_REQUEST_ITEM_UPGRADE_TOOLTIP
(1318, 3, 30),   -- 0x526 CMSG_REQUEST_NPC_TOOLTIP_INFO
(1335, 3, 30);   -- 0x537 CMSG_REQUEST_ITEM_TOOLTIP_SNAPSHOT

-- Live/periodic snapshots: low steady rate, burst when a frame opens.
DELETE FROM `antidos_opcode_policies` WHERE `Opcode` IN (1320, 1326, 1328, 1330);
INSERT INTO `antidos_opcode_policies` (`Opcode`, `Policy`, `MaxAllowedCount`) VALUES
(1320, 3, 20),   -- 0x528 CMSG_REQUEST_MPLUS_HUD_SNAPSHOT
(1326, 3, 20),   -- 0x52E CMSG_REQUEST_QOS_PING_RELAY
(1328, 3, 20),   -- 0x530 CMSG_REQUEST_HLBG_LIVE_SNAPSHOT
(1330, 3, 20);   -- 0x532 CMSG_REQUEST_SPECTATOR_LIVE_SNAPSHOT

-- Collection bulk sync: bursty at login / on opening the collection UI.
DELETE FROM `antidos_opcode_policies` WHERE `Opcode` IN (1322, 1324, 1332);
INSERT INTO `antidos_opcode_policies` (`Opcode`, `Policy`, `MaxAllowedCount`) VALUES
(1322, 3, 20),   -- 0x52A CMSG_REQUEST_COLLECTION_TRANSMOG_STATE
(1324, 3, 20),   -- 0x52C CMSG_REQUEST_COLLECTION_ITEM_SETS
(1332, 3, 20);   -- 0x534 CMSG_REQUEST_COLLECTION_WAVE1

-- Periodic content feeds.
DELETE FROM `antidos_opcode_policies` WHERE `Opcode` IN (1337, 1339, 1341, 1343);
INSERT INTO `antidos_opcode_policies` (`Opcode`, `Policy`, `MaxAllowedCount`) VALUES
(1337, 3, 10),   -- 0x539 CMSG_REQUEST_SEASONAL
(1339, 3, 10),   -- 0x53B CMSG_REQUEST_HOTSPOT
(1341, 3, 10),   -- 0x53D CMSG_REQUEST_PRESTIGE
(1343, 3, 10);   -- 0x53F CMSG_REQUEST_WORLD_CONTENT

-- The generic native bridge carries MOST modules' requests over one opcode, so
-- it legitimately sees the highest rate of anything here. It is also the one DC
-- transport the client-side token bucket does NOT cover (that bucket sits on the
-- addon-whisper path only), which makes this row the real guard for it.
DELETE FROM `antidos_opcode_policies` WHERE `Opcode` IN (1345);
INSERT INTO `antidos_opcode_policies` (`Opcode`, `Policy`, `MaxAllowedCount`) VALUES
(1345, 3, 40);   -- 0x541 CMSG_DC_NATIVE_REQUEST
