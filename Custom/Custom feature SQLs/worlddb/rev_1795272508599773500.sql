-- CMSG_MESSAGECHAT (0x095): chat, whispers, channel and addon messages and every dot command use this opcode, and
-- commands run before the chat mute is checked. Policy 4 = BlockingThrottle: past 40 in one second the session's
-- packets wait for the next second instead of being dropped, so an addon burst is only delayed. The DC client sends
-- at most 20 addon frames at once and 10 a second after that (security audit 2026-11-18, sized 2026-11-21).
DELETE FROM `antidos_opcode_policies` WHERE `Opcode` = 149;
INSERT INTO `antidos_opcode_policies` (`Opcode`, `Policy`, `MaxAllowedCount`) VALUES
(149, 4, 40);
