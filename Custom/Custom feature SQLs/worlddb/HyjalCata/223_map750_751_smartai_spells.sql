-- ---------------------------------------------------------------------------
-- 223  The last 9 "non-existent Spell entry" warnings in the boot log
-- ---------------------------------------------------------------------------
-- Cleanup pass after 200_/201_.  Nine SmartAI cast actions in the clone band
-- still reference spells this server has nowhere, one warning each per boot:
--
--   77722 Void Whip              3644443 (21 spawns)
--   79847 Blast Wave             3644315 (19 spawns)
--   85243 Summon Chattering Swarm 3645691 (7 spawns, on aggro)
--   86042 Unleash Earth          3644479 (17 spawns)
--   86064 Wandering Shadows      3645154 (6 spawns)
--   86087 Burning Blaze          3617878 (18 spawns)
--   86088 Throw Dynamite         3617878 (18 spawns)
--   90908 Mandible Crush         3645744 (1 spawn)
--   91335 Slam                   3644484 (2 spawns)
--
-- ALL NINE ARE MINTED, unlike 74723 in 199_ which was deleted instead.  That
-- is the same test applied and answered the other way: 74723 was a SPELLHIT
-- TRIGGER (an event waiting to be hit by a spell nothing on the map casts), so
-- minting it could not have made the row work.  These nine are CAST ACTIONS on
-- creatures with live spawns -- the mob tries to cast every combat, and the
-- spell simply is not there.  Minting is what makes them work.
--
-- Every one verified ABSENT against the LIVE server dbc
-- (/home/wowcore/azeroth-server/data/dbc/Spell.dbc, 53,154 rows) AND absent
-- from spell_dbc.  Checking spell_dbc alone is the false-positive trap that has
-- bitten this project repeatedly -- that table is only the additive override,
-- and the same style of check once flagged 411 map-750 candidates of which 368
-- resolved fine from the client dbc.
--
-- METHOD (recorded from the earlier 10-spell batch): Cataclysm split spell data
-- out of Spell.dbc into per-aspect tables, so the base row comes from
-- Spell.dbc (73,232 x 48) and the effects from SpellEffect.dbc (97,356 x 27),
-- both in the Cata client's LOCALE archive.  Column layout is the empirically
-- calibrated one -- re-verified here: spell 46598 reads DurationIndex 21 and
-- RangeIndex 152, the distinctive pair that pins those columns.
--
-- THE TRANSFORM THAT MATTERS: 3.3.5 computes an effect as
--   BasePoints + rand(1..DieSides)
-- and Cataclysm dropped DieSides.  So every effect is written with
-- DieSides = 1 and BasePoints = (cata value - 1), which reproduces the same
-- amount.  Copying Cata's value straight across with DieSides = 0 is off by one.
--
-- EFFECT RANGE: this core defines TOTAL_SPELL_EFFECTS = 165, so effect ids
-- 165+ (Cataclysm-only) are an out-of-bounds index into SpellMgr's fixed array
-- and the worldserver ASSERTS AND SEGFAULTS while loading the spell store.
-- Spells carrying such an effect are skipped rather than minted; their SmartAI
-- cast simply logs "non-existent Spell entry", which is harmless.
--
-- Only spells VERIFIED ABSENT from the live Spell.dbc are minted here.  An
-- overlay row wins over the client dbc, so minting one for a spell that already
-- resolves would silently override a correct stock spell globally.
--
-- spell_dbc is SERVER-SIDE ONLY: the server resolves these immediately, but the
-- client shows no icon or tooltip until Spell.dbc itself is rebuilt and
-- deployed.  For SmartAI cast actions that is acceptable -- the cast works.
-- ---------------------------------------------------------------------------

DELETE FROM `spell_dbc` WHERE `ID` IN (77722,79847,85243,86042,86064,86087,86088,90908,91335);
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`, `AttributesEx4`, `AttributesEx5`, `AttributesEx6`, `AttributesEx7`, `CastingTimeIndex`, `DurationIndex`, `PowerType`, `RangeIndex`, `Speed`, `SpellVisualID_1`, `SpellVisualID_2`, `SpellIconID`, `ActiveIconID`, `SchoolMask`, `ProcChance`, `EquippedItemClass`, `Name_Lang_enUS`, `Description_Lang_enUS`, `Effect_1`, `EffectAura_1`, `EffectAuraPeriod_1`, `EffectBasePoints_1`, `EffectDieSides_1`, `EffectMiscValue_1`, `EffectMiscValueB_1`, `EffectRadiusIndex_1`, `EffectTriggerSpell_1`, `ImplicitTargetA_1`, `ImplicitTargetB_1`, `Effect_2`, `EffectAura_2`, `EffectAuraPeriod_2`, `EffectBasePoints_2`, `EffectDieSides_2`, `EffectMiscValue_2`, `EffectMiscValueB_2`, `EffectRadiusIndex_2`, `EffectTriggerSpell_2`, `ImplicitTargetA_2`, `ImplicitTargetB_2`, `Effect_3`, `EffectAura_3`, `EffectAuraPeriod_3`, `EffectBasePoints_3`, `EffectDieSides_3`, `EffectMiscValue_3`, `EffectMiscValueB_3`, `EffectRadiusIndex_3`, `EffectTriggerSpell_3`, `ImplicitTargetA_3`, `ImplicitTargetB_3`) VALUES
(77722, 589824, 0, 0, 0, 0, 0, 0, 0, 14, 0, 0, 5, 0.0, 16447, 0, 1942, 0, 32, 101, -1, 'Void Whip', 'Sends a shadowy tendril towards the enemy, dealing Shadow damage.', 2, 0, 0, 47, 1, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(79847, 589824, 136, 0, 0, 0, 0, 0, 0, 14, 32, 0, 1, 0.0, 963, 0, 292, 0, 4, 101, -1, 'Blast Wave', 'Unleashes a wave of flame, inflicting Fire damage to nearby enemies and reducing their movement speed for $d.', 2, 0, 0, 47, 1, 0, 0, 13, 0, 22, 15, 6, 33, 0, -51, 1, 0, 0, 13, 0, 22, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(85243, 268500992, 1, 0, 0, 0, 0, 0, 0, 1, 21, 0, 1, 0.0, 74, 0, 1611, 0, 32, 101, -1, 'Summon Chattering Swarm', 'Summon a Chattering Swarm to fight by your side.', 28, 0, 0, -1, 1, 3645683, 67, 15, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(86042, 786432, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 4, 0.0, 18196, 0, 689, 0, 8, 101, -1, 'Unleash Earth', 'Unleashes the power of earth, causing Nature damage.', 2, 0, 0, 22, 1, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(86064, 524288, 2184, 0, 0, 0, 0, 0, 0, 1, 32, 0, 5, 12.0, 18198, 0, 2959, 0, 32, 101, -1, 'Wandering Shadows', 'Deals Shadow damage to all enemies within the blaze.  Lasts $d.', 27, 3, 1000, 0, 1, 0, 0, 26, 0, 53, 28, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(86087, 524288, 2184, 0, 0, 0, 0, 0, 0, 1, 8, 0, 5, 12.0, 18157, 0, 1923, 0, 4, 101, -1, 'Burning Blaze', 'Deals Fire damage to all enemies within the blaze.  Lasts $d.', 27, 3, 3000, 3, 1, 0, 0, 8, 0, 28, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(86088, 524288, 136, 4, 0, 0, 0, 16384, 0, 14, 0, 0, 14, 10.0, 18210, 0, 2499, 0, 4, 101, -1, 'Throw Dynamite', 'Hurls a stick of dynamite at an enemy, inflicting Fire damage and creating a burning blaze beneath the target\'s feet.', 2, 0, 0, 11, 1, 0, 0, 8, 0, 74, 16, 32, 0, 0, -1, 1, 0, 0, 8, 86087, 74, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(90908, 1040, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 5559, 0, 102, 0, 1, 101, -1, 'Mandible Crush', 'Crushes your target, inflicting $s1% melee damage.', 31, 0, 0, 149, 1, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(91335, 327696, 512, 0, 1536, 0, 0, 0, 0, 16, 0, 1, 2, 0.0, 0, 0, 559, 0, 1, 101, -1, 'Slam', 'Slams the opponent, causing weapon damage plus an additional amount.', 31, 0, 0, 149, 1, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

-- All nine cleared the effect-range guard (no Cataclysm-only effect id 165+),
-- so this batch cannot reproduce the 198_ boot crash.  Confirm before starting:
--   SELECT COUNT(*) FROM `spell_dbc`
--    WHERE Effect_1 >= 165 OR Effect_2 >= 165 OR Effect_3 >= 165;   -- must be 0
--
-- Verify -- expect 9, then a boot log with no "non-existent Spell entry" lines
-- for the clone band:
--   SELECT COUNT(*) FROM `spell_dbc`
--    WHERE ID IN (77722,79847,85243,86042,86064,86087,86088,90908,91335);
--
-- Do NOT "verify" by counting cast actions whose spell is absent from
-- spell_dbc -- a large non-zero result there is EXPECTED and correct, because
-- most spells resolve from the client Spell.dbc, which that query cannot see.
-- Re-test individual ids with read_server_dbc instead.
