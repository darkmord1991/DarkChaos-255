-- ============================================================================
-- DC FirstStart - Welcome quest chain wiring
-- Date: 2026-07-21
-- 820056 "Welcome to Azshara Crater" (Hervikus, auto-granted on first login by
-- DCFirstStart) now auto-offers 820057 "Welcome to Dark Chaos" on turn-in.
-- Hervikus starts both, so the follow-up window opens at the same NPC; 820057
-- then sends the player to Warden Stonebrook (its quest ender), who offers the
-- zone-1 quests - closing the gap where the welcome flow dead-ended.
-- ============================================================================

UPDATE `quest_template` SET `RewardNextQuest` = 820057 WHERE `ID` = 820056;
