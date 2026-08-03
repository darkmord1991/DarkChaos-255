-- ---------------------------------------------------------------------------
-- 200  Plaguelands (map 751) -- the SmartAI spells it genuinely lacks
-- ---------------------------------------------------------------------------
-- Companion to 201_, which imports 50 SmartAI rows cata_world defines for map
-- 751 creatures we spawn but never scripted.  Those rows cast 43 distinct
-- spells; 16 already resolve from the client Spell.dbc and 27 do not.
--
-- The 27 are minted here so 201_ does not arrive casting spells that do not
-- exist.  Every one was verified ABSENT against the LIVE server dbc, not
-- against spell_dbc -- that table is only the additive override, and checking
-- it alone is the false-positive trap that has bitten this project repeatedly
-- (the same 43-spell check on map 750 flagged 411 candidates, of which 368
-- resolved fine).
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

DELETE FROM `spell_dbc` WHERE `ID` IN (79721,79887,79893,79894,79895,79897,79899,80132,81236,83019,83021,85415,85419,85424,85524,85525,85681,85690,85691,85710,85800,85842,86002,86070,86071,86079,86085);
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`, `AttributesEx4`, `AttributesEx5`, `AttributesEx6`, `AttributesEx7`, `CastingTimeIndex`, `DurationIndex`, `PowerType`, `RangeIndex`, `Speed`, `SpellVisualID_1`, `SpellVisualID_2`, `SpellIconID`, `ActiveIconID`, `SchoolMask`, `ProcChance`, `EquippedItemClass`, `Name_Lang_enUS`, `Description_Lang_enUS`, `Effect_1`, `EffectAura_1`, `EffectAuraPeriod_1`, `EffectBasePoints_1`, `EffectDieSides_1`, `EffectMiscValue_1`, `EffectMiscValueB_1`, `EffectRadiusIndex_1`, `EffectTriggerSpell_1`, `ImplicitTargetA_1`, `ImplicitTargetB_1`, `Effect_2`, `EffectAura_2`, `EffectAuraPeriod_2`, `EffectBasePoints_2`, `EffectDieSides_2`, `EffectMiscValue_2`, `EffectMiscValueB_2`, `EffectRadiusIndex_2`, `EffectTriggerSpell_2`, `ImplicitTargetA_2`, `ImplicitTargetB_2`, `Effect_3`, `EffectAura_3`, `EffectAuraPeriod_3`, `EffectBasePoints_3`, `EffectDieSides_3`, `EffectMiscValue_3`, `EffectMiscValueB_3`, `EffectRadiusIndex_3`, `EffectTriggerSpell_3`, `ImplicitTargetA_3`, `ImplicitTargetB_3`) VALUES
(79721, 524306, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 54, 25.0, 794, 0, 184, 0, 4, 101, -1, 'Explosive Shot', 'Inflicts weapon damage and additional Fire damage to an enemy and any of its nearby allies.', 58, 0, 0, 13, 1, 0, 0, 13, 0, 53, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(79887, 524288, 33556616, 0, 0, 0, 512, 0, 0, 1, 1, 0, 4, 0.0, 9735, 0, 118, 0, 32, 101, -1, 'Death and Decay', 'Shadow damage inflicted every $t1 sec to all targets in the affected area for $d.', 27, 3, 1000, 0, 1, 0, 0, 8, 0, 28, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(79893, 262144, 268435456, 0, 0, 0, 0, 0, 0, 1, 31, 0, 4, 0.0, 8208, 0, 2296, 0, 32, 101, -1, 'Bloodworm', 'Creates a Bloodworm to attack nearby targets.  Lasts $d.', 28, 0, 0, 0, 1, 42850, 2974, 0, 0, 53, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(79894, 0, 524288, 1048640, 256, 0, 0, 276824064, 0, 1, 0, 1, 4, 0.0, 10906, 0, 2723, 0, 1, 101, -1, 'Death Grip', 'Harness the unholy energy that surrounds and binds all matter, drawing the target toward the death knight and forcing the enemy to attack the death knight for $49560d.', 3, 0, 0, -1, 1, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(79895, 262160, 512, 0, 0, 0, 0, 0, 0, 1, 0, 5, 2, 0.0, 11612, 0, 2740, 0, 16, 101, -1, 'Frost Strike', 'Instantly strike the enemy, causing $s1% weapon damage as Frost damage.', 31, 0, 0, 109, 1, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(79897, 524288, 0, 0, 0, 0, 0, 0, 0, 1, 31, 0, 3, 0.0, 11152, 0, 2721, 0, 16, 101, -1, 'Icy Touch', 'Deals Frost damage and reduces the target\'s ranged, melee attack, and casting speed by $s2% for $d.', 2, 0, 0, 22, 1, 0, 0, 0, 0, 6, 0, 6, 193, 0, -16, 1, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(79899, 0, 134217728, 0, 256, 0, 32, 8388608, 0, 1, 1, 6, 34, 0.0, 12328, 0, 180, 0, 16, 101, -1, 'Chains of Ice', 'Shackles the target with frozen chains, reducing their movement to 5% of normal. The target regains 10% of their movement each second for $d.', 6, 33, 0, -96, 1, 0, 0, 0, 0, 6, 0, 6, 226, 1000, 9, 1, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(80132, 524288, 18436, 0, 0, 0, 0, 0, 0, 1, 28, 0, 3, 0.0, 16967, 0, 1942, 0, 32, 101, -1, 'Unbound Darkness', 'Inflicts Shadow damage to an enemy.', 6, 3, 1000, 14, 1, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(81236, 589824, 0, 0, 0, 0, 0, 0, 0, 14, 1, 0, 5, 24.0, 4879, 0, 1468, 0, 8, 101, -1, 'Diseased Spit', 'Spits at an enemy, inflicting Nature damage and reducing its Stamina for $d.', 2, 0, 0, 47, 1, 0, 0, 0, 0, 6, 0, 6, 29, 0, -11, 1, 2, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(83019, 8388608, 0, 1, 0, 0, 1073741824, 0, 0, 1, 1, 0, 5, 12.0, 14724, 0, 636, 0, 8, 101, -1, 'Toxic Waste', 'Deals Nature damage to all enemies within the acid. Lasts $d.', 27, 89, 2000, 2, 1, 0, 0, 26, 0, 53, 28, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(83021, 786448, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 1, 0.0, 963, 0, 37, 0, 4, 101, -1, 'Blight Bomb', 'Sacrifices the caster\'s life in order to inflict Fire damage to nearby enemies.', 2, 0, 0, 81, 1, 0, 0, 9, 0, 22, 15, 1, 0, 0, -1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(85415, 524288, 2048, 0, 0, 0, 0, 0, 0, 1, 31, 0, 2, 0.0, 18056, 0, 494, 0, 1, 101, -1, 'Mangle', 'Mangle the target, dealing Physical damage and additional damage over $d.', 2, 0, 0, 22, 1, 0, 0, 0, 0, 6, 0, 6, 3, 3000, 3, 1, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(85419, 524288, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 2, 0.0, 18057, 0, 960, 0, 1, 101, -1, 'Bellowing Roar', 'Lets loose a bellowing roar, dealing physical damage to enemies within $A1 yards.', 2, 0, 0, 22, 1, 0, 0, 0, 0, 22, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(85424, 524288, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 2, 15.0, 18239, 0, 9, 0, 32, 101, -1, 'Spirit Burst', 'Releases a burst of spectral energy at the enemy, dealing Shadow damage.', 2, 0, 0, 22, 1, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(85524, 0, 0, 0, 0, 0, 0, 0, 0, 1, 31, 0, 4, 0.0, 18087, 0, 4422, 0, 8, 101, -1, 'Might of the Forsaken', 'Increases attack speed by $s1% for $d.', 6, 193, 0, 29, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(85525, 0, 0, 0, 0, 0, 0, 0, 0, 1, 31, 0, 4, 0.0, 18088, 0, 3248, 0, 8, 101, -1, 'Lordaeron\'s Call', 'Increases attack speed by $s1% for $d.', 6, 193, 0, 29, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(85681, 524288, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 5, 5.0, 18124, 0, 2394, 0, 1, 101, -1, 'Boot Toss', 'Throws a boot at the enemy, dealing Physical damage.', 2, 0, 0, 22, 1, 0, 0, 0, 0, 25, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(85690, 0, 0, 0, 0, 0, 0, 0, 0, 1, 28, 0, 1, 0.0, 72, 0, 2250, 0, 1, 101, -1, 'Fox\'s Cunning', 'Increases the caster\'s chance to dodge by $s1%.', 6, 49, 0, 24, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(85691, 0, 0, 0, 0, 0, 0, 0, 0, 1, 35, 0, 1, 0.0, 18126, 0, 1741, 0, 1, 101, -1, 'Piercing Howl', 'Causes an enemy target to become dazed for $d.', 6, 33, 0, -51, 1, 0, 0, 13, 0, 22, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(85710, 2, 0, 0, 32768, 16777216, 0, 16384, 0, 16, 0, 0, 36, 40.0, 0, 0, 126, 0, 1, 101, -1, 'Shoot', 'Shoots at an enemy, inflicting Physical damage.', 58, 0, 0, -1, 1, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(85800, 589824, 2184, 0, 0, 0, 524288, 0, 0, 1, 28, 0, 7, 0.0, 18165, 0, 1988, 0, 4, 101, -1, 'Shadowflame', 'Targets in a cone in front of the caster take Fire damage and additional Fire damage every 3 seconds for $t3 seconds.', 3, 0, 0, -1, 1, 0, 0, 0, 0, 0, 0, 2, 0, 0, 22, 1, 0, 0, 13, 0, 104, 0, 6, 3, 3000, 3, 1, 0, 0, 13, 0, 104, 0),
(85842, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 7, 0.0, 18172, 0, 2239, 0, 1, 101, -1, 'Survival Instincts', 'Your survival instincts release a rush of adrenaline that courses through your body! Remember, become as big as possible and whatever you do, don\'t run!', 6, 61, 0, 49, 1, 0, 0, 0, 0, 6, 0, 6, 193, 0, 99, 1, 4, 0, 0, 0, 6, 0, 64, 0, 0, -1, 1, 0, 0, 0, 85847, 6, 0),
(86002, 262160, 2048, 0, 0, 0, 0, 0, 0, 1, 28, 0, 1, 0.0, 18190, 0, 1737, 0, 1, 101, -1, 'Fetid Absorption', 'Protected by a cloud of disease. Absorbs $s1 damage.', 6, 69, 0, 119, 1, 127, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(86070, 262160, 0, 0, 0, 0, 0, 0, 0, 1, 32, 0, 2, 0.0, 843, 0, 147, 0, 1, 101, -1, 'Pierce Armor', 'Reduces an enemy\'s armor by $s1% for $d.', 6, 101, 0, -51, 1, 1, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(86071, 524288, 2048, 0, 0, 0, 1073741824, 0, 0, 1, 31, 0, 14, 15.0, 11753, 0, 263, 0, 8, 101, -1, 'Acid Cloud', 'Sprays acid at the location of the target, creating a cloud that deals Nature damage per second to enemies inside of it. Lasts $d.', 27, 3, 1000, 0, 1, 0, 0, 8, 0, 53, 28, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(86079, 2949136, 0, 0, 0, 0, 0, 0, 0, 16, 39, 1, 2, 0.0, 18205, 0, 129, 0, 1, 101, -1, 'Ground Slash', 'Sends a wave of force in front of the caster, causing damage and stunning all enemy targets within $a1 yards in a frontal cone for $d.', 2, 0, 0, 22, 1, 0, 0, 37, 0, 104, 0, 6, 12, 0, -1, 1, 0, 0, 37, 0, 104, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(86085, 327696, 134218240, 0, 16778240, 0, 0, 0, 0, 1, 0, 0, 2, 0.0, 18254, 0, 533, 0, 1, 101, -1, 'Mutilate', 'Instantly attacks with both weapons.  Awards 2 combo points.', 3, 0, 0, -1, 1, 0, 0, 0, 0, 6, 0, 64, 0, 0, -1, 1, 0, 0, 0, 80587, 6, 0, 64, 0, 0, -1, 1, 0, 0, 0, 80589, 6, 0);

-- Verify -- expect 0 (every map-750 SmartAI spell now resolves somewhere):
--   SELECT COUNT(DISTINCT s.action_param1) FROM `smart_scripts` s
--     JOIN `creature` c ON c.id = s.entryorguid AND c.map = 750 AND s.source_type = 0
--    WHERE s.action_type = 11 AND s.action_param1 NOT IN (SELECT ID FROM `spell_dbc`);
--   (a non-zero result here is EXPECTED and fine -- those are the 368 that live
--    in the client Spell.dbc; re-test them with read_server_dbc, not this query)
