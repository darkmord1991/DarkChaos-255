-- Summon spells whose SummonProperties id exists in neither the server SummonProperties.dbc (ids end at 2976 with
-- gaps) nor summonproperties_dbc, so each cast logged "EffectSummonType: Unhandled summon type N" and summoned
-- nothing. Seen live on 2026-11-20: Summon Moonwell (100623, via 100612) and Summon Splashing Waters Visual (101495,
-- via 101492) in the Molten Front, both 2971. Rows from the Cata 4.3.4 client SummonProperties.dbc
-- (locale-enUS.MPQ), Flags cut to the low 16 bits as in rev_1794230771559692400 (3027): only 2919 changes
-- (0x2031A -> 0x31A). Server-side only, like that row. Spells covered:
--   2241 Summon Arcane Charge 67922; 2841 Summon Spirit of Lo'Gosh 74077, Summon Spirit of Goldrinn 74078,
--   Summon Elderlimb 100571, Summon Ricket's Rocket 100602, Summon Tenaron Stormgrip 100629; 2918 Summon Shadow of
--   Agamand 73180; 2919 Summon Darnell 91576, 91938; 2930 Summon Pack of Rockcandy 81535; 2971 Summon Moonwell
--   100623, Summon Splashing Waters Visual 101495; 2974 Bloodworm 79893.
-- Not covered: Summon Hellfire Imp 31253 names id 0 in spell_dbc.
DELETE FROM `summonproperties_dbc` WHERE `ID` IN (2241, 2841, 2918, 2919, 2930, 2971, 2974);
INSERT INTO `summonproperties_dbc` (`ID`, `Control`, `Faction`, `Title`, `Slot`, `Flags`) VALUES
(2241, 1, 0, 2, 6, 1034),
(2841, 1, 0, 0, 0, 2064),
(2918, 0, 0, 0, 0, 5),
(2919, 1, 0, 0, 6, 794),
(2930, 1, 0, 0, 0, 264),
(2971, 1, 0, 2, 0, 2304),
(2974, 1, 0, 2, 0, 4614);
