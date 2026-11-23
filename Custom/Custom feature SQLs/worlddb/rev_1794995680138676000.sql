--
-- Throttle gossip and quest accept/abandon floods (2026-11-18 security sweep).
-- CMSG_GOSSIP_HELLO (0x17B) and CMSG_GOSSIP_SELECT_OPTION (0x17C) had no row: several scripts summon creatures per
-- select, so an unthrottled client could flood a map. Excess packets are dropped (Policy 5 = DropPacket).
-- CMSG_QUESTGIVER_ACCEPT_QUEST (0x189) and CMSG_QUESTLOG_REMOVE_QUEST (0x194) kicked only above 200/s, which let
-- accept/abandon loops spawn quest scenes; 30/s is far above any legitimate use. Policy 1 = Kick stays.
DELETE FROM `antidos_opcode_policies` WHERE `Opcode` IN (379, 380, 393, 404);
INSERT INTO `antidos_opcode_policies` (`Opcode`, `Policy`, `MaxAllowedCount`) VALUES
(379, 5, 10),
(380, 5, 10),
(393, 1, 30),
(404, 1, 30);
