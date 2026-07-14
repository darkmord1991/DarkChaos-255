-- ---------------------------------------------------------------------------
-- quest_template.RewardSpell -- null out confirmed-unresolvable spell ids
-- ---------------------------------------------------------------------------
-- Quest N has `RewardSpell` = S but spell S does not exist, quest will not
-- have a spell reward. Spells 84192, 84205, 94998 are already on this
-- session's confirmed "genuinely unresolvable" list (see
-- [[db-errors-quest-loading-2026-07-13]] / [[db-errors-creaturetext-sound-quest-swap-2026-07-14]]
-- -- absent from stock WotLK, the full Cata 4.3.4 dump, AND dense-neighbor-
-- checked). RewardSpell already silently no-ops when the spell is missing
-- (LOG_ERROR only, quest just skips that reward), so this is purely a
-- boot-log-silencing cleanup at the user's explicit request rather than a
-- functional fix -- these quests never had a working spell reward on this
-- fork and still won't after this change.
-- ---------------------------------------------------------------------------
UPDATE `quest_template` SET `RewardSpell` = 0 WHERE `ID` = 26938 AND `RewardSpell` = 84192;
UPDATE `quest_template` SET `RewardSpell` = 0 WHERE `ID` = 27089 AND `RewardSpell` = 84205;
UPDATE `quest_template` SET `RewardSpell` = 0 WHERE `ID` = 27090 AND `RewardSpell` = 84205;
UPDATE `quest_template` SET `RewardSpell` = 0 WHERE `ID` = 27369 AND `RewardSpell` = 94998;
UPDATE `quest_template` SET `RewardSpell` = 0 WHERE `ID` = 27372 AND `RewardSpell` = 94998;
