-- SummonProperties rows for every downported Cata summon spell in spell_dbc.
--
-- The server SummonProperties.dbc ends at id 2976 and summonproperties_dbc was empty, so 43 spell_dbc spells
-- whose summon effect names a Cataclysm SummonProperties id summoned nothing ("EffectSummonType: Unhandled
-- summon type"): among them the Silverpine port's Agatha 83982, the guardians 84941/84944/85517-85519, the
-- Cities in Dust actors 85864-85927, the bush chicken 83902 and the webbed victim's sea dog 83927.
-- Found by the Silverpine port on 2026-11-09 and swept server-wide (every Effect 28 in spell_dbc whose
-- EffectMiscValueB is above 2976 and has no row).
--
-- Rows come from the 4.3.4 client (K:/UntouchedClients/Cata, SummonProperties.dbc), with two mappings:
--   Flags are cut to the low 16 bits: 3.3.5 defines SummonPropFlags up to 0x8000 (DBCEnums.h), and the Cata-only
--   bits (0x10000+, mostly 0x20000) mean nothing here.
--   Faction 10608 on 3026/3028 is not a 3.3.5 FactionTemplate; 0 keeps the summoned creature's own faction.
-- Control, Title and Slot values are all valid 3.3.5 SummonCategory / SummonType / slot values as they are.
-- This file owns these rows; the Silverpine slice files do not repeat them.

DELETE FROM `summonproperties_dbc` WHERE `ID` IN (2987, 2995, 3009, 3016, 3024, 3026, 3027, 3028, 3030, 3031, 3035, 3038, 3045, 3048, 3050, 3051, 3055, 3077, 3117, 3135, 3147, 3162);
INSERT INTO `summonproperties_dbc` (`ID`, `Control`, `Faction`, `Title`, `Slot`, `Flags`) VALUES
(2987, 0, 0, 0, 0, 320), -- spells 98183
(2995, 0, 0, 0, 6, 1304), -- spells 84069
(3009, 1, 0, 5, 0, 2826), -- spells 98590
(3016, 0, 0, 0, 6, 3352), -- spells 91085
(3024, 1, 0, 0, 6, 3352), -- spells 83751
(3026, 1, 0, 0, 6, 3336), -- spells 83839
(3027, 1, 0, 0, 6, 1280), -- spells 83902
(3028, 1, 0, 0, 0, 2826), -- spells 83927
(3030, 1, 0, 0, 6, 3850), -- spells 83982
(3031, 1, 0, 0, 0, 3352), -- spells 90133
(3035, 4, 0, 0, 0, 272), -- spells 91683
(3038, 4, 0, 0, 0, 272), -- spells 92064
(3045, 1, 0, 0, 0, 3850), -- spells 84941 84944 85517 85518 85519
(3048, 0, 0, 0, 0, 2328), -- spells 92229 151014
(3050, 1, 0, 0, 0, 3866), -- spells 85864 85868 85869 85870 85871
(3051, 0, 0, 0, 0, 3352), -- spells 85877 85878 85925 85926 85927
(3055, 1, 0, 5, 6, 3352), -- spells 100168
(3077, 0, 0, 0, 0, 16), -- spells 91768
(3117, 1, 0, 5, 5, 2056), -- spells 92395 92396 92397 92398
(3135, 0, 0, 0, 0, 2312), -- spells 98294
(3147, 1, 0, 0, 0, 10520), -- spells 100807
(3162, 1, 0, 0, 2, 4096); -- spells 99136
