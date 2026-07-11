-- Worgoblin: upstream issue #54 - Rocket Barrage (69041) and Rocket Jump (69070)
-- were on independent cooldowns (120s / 90s). Cata behavior: both share a
-- 2-minute cooldown. Implemented via a shared spell category (69041) with
-- CategoryRecoveryTime; per-spell RecoveryTime cleared.
-- Client Spell.dbc rows carry the same values (deployed to patch-4 + enGB-3).
UPDATE `spell_dbc` SET `Category` = 69041, `RecoveryTime` = 0, `CategoryRecoveryTime` = 120000 WHERE `ID` IN (69041, 69070);
