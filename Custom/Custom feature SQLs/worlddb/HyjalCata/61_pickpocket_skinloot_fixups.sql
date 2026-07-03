-- The neltharion retroport clone generator blindly copied lootid into pickpocketloot/skinloot
-- for every clone, even where the source creature had 0 (no pickpocket/skin loot authored).
-- Verified against every clone whose original entry still exists standalone
-- (1837, 1847, 44448-44450, 45209, 46092-46095: all pickpocketloot=0/skinloot=0 on the original).
-- creature_loot_template for these entries holds 150-280 rows (generic world-loot reference
-- groups + per-item world drop chances) -- NOT a curated pickpocket/skin list, so mirroring it
-- would be wrong; zeroing out matches verified original design intent instead.

UPDATE `creature_template` SET `pickpocketloot` = 0
    WHERE `entry` IN (3601837, 3601847, 3639436, 3639438, 3644448, 3644449, 3644450, 3645047,
                       3645209, 3645240, 3645241, 3645242, 3645243, 3646092, 3646093, 3646094,
                       3646095, 3653328);

UPDATE `creature_template` SET `skinloot` = 0
    WHERE `entry` IN (3601851, 3646925, 3652552);
