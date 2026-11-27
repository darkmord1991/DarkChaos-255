-- DarkChaos: trim Destruction warlocks above level 80 through the custom Immolate ranks (12-25, levels 81-159).
-- 18 h of meter data (11-25/26): Destruction deals ~38% more than the median damage spec at 131-160 (+25% at 81-100),
-- and Conflagrate alone is 36% of it (avg hit 14,553 -> 18,742 after the ratings change). AzerothCore computes
-- Conflagrate as 60% of the target's whole Immolate (ticks including their spell power bonus), so halving the spell
-- power coefficient of the custom ranks' ticks (0.2 -> 0.1) cuts Immolate's ticks and Conflagrate by ~18% at 146-160
-- (about 8% of Destruction damage, more at lower levels where spell power is a larger share of the tick). Immolate's
-- direct hit keeps 0.2. Stock ranks 1-11 (levels 1-80) are untouched. Each UPDATE checks the old value (as a range: the
-- column is a FLOAT, so a plain `= 0.2` never matches).
UPDATE `spell_bonus_data` SET `dot_bonus` = 0.1
    WHERE `entry` IN (929011, 929012, 929013, 929014, 929015, 929016, 929017, 929018, 929019)
    AND `dot_bonus` > 0.19 AND `dot_bonus` < 0.21;
UPDATE `spell_bonus_data` SET `dot_bonus` = 0.1
    WHERE `entry` IN (929511, 929512, 929513, 929514, 929515) AND `dot_bonus` > 0.19 AND `dot_bonus` < 0.21;
