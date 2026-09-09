-- Hinterland BG guard parity.
--
-- 31 of the 35 Alliance guards carry flags_extra 98304
-- (CREATURE_FLAG_EXTRA_GUARD 0x8000 | CREATURE_FLAG_EXTRA_IGNORE_FEIGN_DEATH
-- 0x10000); not one of the 41 Horde guards did. The GUARD bit is what makes
-- GuardAI::Permissible return PERMIT_BASE_PROACTIVE, so the Alliance camp
-- defended itself with proactive GuardAI while the Revantusk and Kor'kron camp
-- sat on the default reactive AI. Same flags for both sides now.
--
-- These entries also spawn on map 0 (the open-world Hinterlands) and map 1412
-- (the second battleground clone); the Alliance side already behaved this way
-- there, so this brings the Horde camp in line everywhere rather than only
-- inside the battleground.
UPDATE `creature_template` SET `flags_extra` = 98304
WHERE `entry` IN (810000, 810006, 810007, 810008, 810012, 810016, 810024, 810025, 810026, 810027);

-- The four Alliance guards that were missed when the rest of their camp was
-- flagged: Gryphon Herald and Banner-Bearer.
UPDATE `creature_template` SET `flags_extra` = 98304 WHERE `entry` IN (810013, 810015);
