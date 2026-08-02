-- ---------------------------------------------------------------------------
-- 216  Map 750 -- the 33 spells the Ashenvale/Winterspring SmartAI casts
-- ---------------------------------------------------------------------------
-- Stage 1 of giving the 190 creatures 212_ imported their scripted behaviour.
-- 212_ deliberately cleared AIName because importing scripts without the spells
-- they cast just trades silence for a stream of "uses non-existent Spell entry"
-- rejections. So the spells go first, exactly as 203_ did before 204_.
--
-- THE COUNT LOOKED FOUR TIMES WORSE THAN IT IS. Checking the CAST actions
-- against `spell_dbc` alone reports 136 missing out of 143. That table is an
-- OVERLAY -- a spell exists if it is in the overlay OR the binary Spell.dbc --
-- and testing the live server's Spell.dbc (53,154 records) shows 103 of those
-- 136 are already there. The real gap is 33. This is the same trap that once
-- turned 10 genuinely missing spells into 742 false ones.
--
-- All 33 were confirmed present in the Cata client before generating.
--
-- SOURCE and conversion identical to 203_: K:\UntouchedClients\Cata,
-- Data\enUS\locale-enUS.MPQ, Spell.dbc (48 fields) + SpellEffect.dbc (27,
-- SpellID at 24 / EffectIndex at 25). 3.3.5 computes an effect as
-- BasePoints + rand(1..DieSides) and Cata dropped DieSides, so DieSides is
-- written as 1 and BasePoints as (cata - 1) to reproduce the same amount.
-- Effect 28 (SUMMON) carries a creature entry in EffectMiscValue and is moved
-- into the +3,700,000 clone band, or the spell summons nothing.
--
DELETE FROM `spell_dbc` WHERE `ID` IN (
  62804, 62975, 75529, 77558, 78542, 78702, 78703, 78705, 78710, 78732, 78751, 78754, 78770, 79846, 79850, 79858, 79859, 79860, 79868, 79880, 81119, 81161, 82828, 83669, 84867, 85424, 90798, 91667, 91671, 91827, 93655, 93661, 93711);

INSERT INTO `spell_dbc`
    (`ID`,
     `Attributes`,
     `AttributesEx`,
     `AttributesEx2`,
     `AttributesEx3`,
     `AttributesEx4`,
     `AttributesEx5`,
     `AttributesEx6`,
     `AttributesEx7`,
     `CastingTimeIndex`,
     `DurationIndex`,
     `PowerType`,
     `RangeIndex`,
     `Speed`,
     `SpellVisualID_1`,
     `SpellVisualID_2`,
     `SpellIconID`,
     `ActiveIconID`,
     `SchoolMask`,
     `ProcChance`,
     `EquippedItemClass`,
     `Name_Lang_enUS`,
     `Description_Lang_enUS`,
     `Effect_1`,`EffectAura_1`,`EffectBasePoints_1`,`EffectDieSides_1`,`EffectAuraPeriod_1`,`EffectMiscValue_1`,`EffectMiscValueB_1`,`EffectRadiusIndex_1`,`EffectTriggerSpell_1`,`ImplicitTargetA_1`,`ImplicitTargetB_1`,`Effect_2`,`EffectAura_2`,`EffectBasePoints_2`,`EffectDieSides_2`,`EffectAuraPeriod_2`,`EffectMiscValue_2`,`EffectMiscValueB_2`,`EffectRadiusIndex_2`,`EffectTriggerSpell_2`,`ImplicitTargetA_2`,`ImplicitTargetB_2`,`Effect_3`,`EffectAura_3`,`EffectBasePoints_3`,`EffectDieSides_3`,`EffectAuraPeriod_3`,`EffectMiscValue_3`,`EffectMiscValueB_3`,`EffectRadiusIndex_3`,`EffectTriggerSpell_3`,`ImplicitTargetA_3`,`ImplicitTargetB_3`)
VALUES
  (62804, 589824, 0, 0, 0, 0, 0, 0, 0, 5, 29, 0, 4, 0.0000, 32, 0, 64, 0, 8, 101, -1, 'Rejuvenation', 'Heals an ally every $t1 sec. for $d.', 6, 8, 19, 1, 3000, 0, 0, 0, 0, 21, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (62975, 589824, 0, 0, 256, 0, 0, 0, 0, 4, 0, 0, 5, 24.0000, 13302, 0, 213, 0, 32, 101, -1, 'Shadow Bolt', 'Hurls a bolt of dark magic at an enemy, inflicting Shadow damage.', 2, 0, 22, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (75529, 0, 0, 0, 0, 0, 0, 0, 0, 16, 1, 0, 1, 0.0000, 0, 0, 2865, 0, 1, 101, -1, 'Agile Focus', 'Focusing intensely, the caster will dodge the next $n attacks.', 6, 49, 99, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (77558, 262144, 0, 0, 0, 0, 0, 0, 0, 1, 8, 0, 2, 0.0000, 16384, 0, 541, 0, 1, 101, -1, 'Bloody Strike', 'An instant attack that deals $s1% weapon damage.  Increases attack damage by $s2%, but reduces chance to hit by $s3%. Lasts $d.', 31, 0, 109, 1, 0, 0, 0, 0, 0, 6, 0, 6, 79, 4, 1, 0, 127, 0, 0, 0, 1, 0, 6, 54, -6, 1, 0, 0, 0, 0, 0, 1, 0),
  (78542, 524288, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 1, 0.0000, 16607, 0, 94, 0, 16, 101, -1, 'Splash', 'A splash of water drenches all nearby enemies, dealing Frost damage and knocking them back a short distance.', 2, 0, 31, 1, 0, 0, 0, 18, 0, 22, 15, 98, 0, 49, 1, 0, 50, 0, 18, 0, 22, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (78702, 589824, 136, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0000, 16635, 0, 122, 0, 64, 101, -1, 'Arcane Explosion', 'Sends out a blast wave of magic, inflicting Arcane damage to nearby enemies.', 2, 0, 22, 1, 0, 0, 0, 13, 0, 22, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (78703, 0, 0, 0, 0, 0, 0, 0, 0, 1, 21, 1, 1, 0.0000, 7199, 0, 3081, 0, 64, 101, -1, 'Ghostform', 'Transform into a Ghost Wolf, unlocking a set of special abilities.', 6, 56, 0, 0, 0, 42193, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (78705, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 4, 15.0000, 16636, 0, 518, 0, 8, 101, -1, 'Poison Bottle', 'Throw a poison bottle, dealing Nature damage every 3 seconds.', 32, 0, 0, 0, 0, 0, 0, 0, 78704, 53, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (78710, 151322624, 2048, 0, 0, 0, 0, 0, 0, 1, 9, 1, 1, 0.0000, 246, 0, 1962, 122, 1, 101, -1, 'Threatening Shout', 'Increase the melee attack speed of the caster and nearby allies by $s1% for $d.', 128, 138, 19, 1, 0, 1, 0, 9, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (78732, 327696, 84, 0, 1024, 0, 512, 0, 0, 1, 32, 1, 1, 0.0000, 16641, 0, 94, 0, 17, 101, -1, 'Whirlpool', 'Instantly Whirlwind up to $50622i nearby targets and for the next $d you will perform an icy whirlwind attack every $t1 sec.  While under the effects of Whirlpool, you can move but cannot perform any other abilities but you do not feel pity or remorse or fear and you cannot be stopped unless killed.', 6, 23, 0, 0, 1000, 0, 0, 0, 78733, 1, 0, 6, 147, 0, 0, 0, 1733, 0, 0, 0, 1, 0, 6, 263, 0, 0, 0, 0, 0, 0, 0, 1, 0),
  (78751, 524288, 18436, 0, 0, 0, 0, 0, 0, 1, 27, 0, 3, 0.0000, 16649, 0, 548, 0, 32, 101, -1, 'Mind Flay', 'Inflicts Shadow damage to an enemy and reduces its movement speed for $d.', 6, 3, 17, 1, 1000, 0, 0, 0, 0, 6, 0, 6, 33, -51, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (78754, 589826, 0, 131072, 0, 0, 0, 0, 0, 1, 0, 0, 114, 40.0000, 3299, 0, 218, 0, 64, 101, -1, 'Arcane Shot', 'Shoots an enemy, inflicting Arcane damage.', 2, 0, 22, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (78770, 589824, 0, 0, 0, 0, 0, 0, 32, 1, 86, 0, 1, 0.0000, 369, 0, 37, 0, 1, 101, -1, 'Magma Totem', 'Summons a Magma Totem with $s1 health at the feet of the caster for ${$d-1} sec that causes  Fire damage to creatures within $8187a1 yards every $8188t1 seconds.', 28, 0, 4, 1, 0, 3742211, 63, 0, 0, 44, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (79846, 589824, 2184, 0, 0, 32, 0, 0, 0, 14, 31, 0, 4, 0.0000, 10383, 0, 37, 0, 4, 101, -1, 'Flamestrike', 'Calls down a pillar of flame, burning all enemies in a selected area and inflicting additional damage every $t2 sec. for $d.', 2, 0, 47, 1, 0, 0, 0, 8, 0, 16, 0, 27, 3, 2, 1, 2000, 0, 0, 8, 0, 28, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (79850, 1074331648, 136, 4, 0, 0, 0, 0, 0, 5, 35, 0, 1, 0.0000, 17, 0, 193, 0, 16, 101, -1, 'Frost Nova', 'Inflicts Frost damage to nearby enemies, immobilizing them for up to $d.', 2, 0, 25, 1, 0, 0, 0, 13, 0, 22, 15, 6, 26, 0, 0, 0, 0, 0, 13, 0, 22, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (79858, 589824, 0, 0, 0, 0, 0, 0, 0, 14, 35, 0, 5, 24.0000, 13, 0, 188, 0, 16, 101, -1, 'Frostbolt', 'Inflicts Frost damage to an enemy and reduces its movement speed for $d.', 2, 0, 47, 1, 0, 0, 0, 0, 0, 6, 0, 6, 33, -51, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (79859, 786432, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 35, 38.0000, 7906, 0, 186, 0, 16, 101, -1, 'Ice Lance', 'Deals Frost damage to an enemy target.  Causes double damage against Frozen targets.', 2, 0, 21, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (79860, 589824, 268437644, 0, 0, 0, 0, 0, 0, 5, 31, 0, 4, 0.0000, 10386, 0, 285, 0, 16, 101, -1, 'Blizzard', 'Calls down a blizzard that lasts $d., inflicting Frost damage every $t1 sec. to all enemies in a selected area.', 27, 3, 24, 1, 2000, 0, 0, 14, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (79868, 786432, 0, 0, 0, 0, 0, 0, 0, 19, 0, 0, 4, 0.0000, 7749, 0, 2294, 0, 64, 101, -1, 'Arcane Blast', 'Blasts the target with energy, dealing Arcane damage.  Each time you cast Arcane Blast, the damage of all Arcane spells is increased by $36032s1% and mana cost of Arcane Blast is increased by $36032s2%.  Effect stacks up to $36032u times and lasts $36032d or until any Arcane damage spell except Arcane Blast is cast.', 2, 0, 39, 1, 0, 0, 0, 0, 0, 6, 0, 64, 0, 0, 0, 0, 0, 0, 0, 36032, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (79880, 65536, 0, 0, 0, 0, 0, 0, 0, 1, 32, 0, 4, 0.0000, 68, 0, 27, 0, 64, 101, -1, 'Slow', 'Increases the time between an enemy''s attacks by $s1%, casting time increased by $s2% and slows its movement by $s2% for $d.', 6, 33, -26, 1, 0, 0, 0, 0, 0, 6, 0, 6, 193, -26, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (81119, 16, 0, 0, 0, 0, 0, 0, 0, 1, 32, 0, 1, 0.0000, 8263, 0, 4432, 0, 32, 101, -1, 'Howling Screech', 'Movement speed of nearby enemies is reduced by $s1% for $d.
Reduces the attack power of nearby enemies by $s2.', 6, 33, -26, 1, 0, 0, 0, 13, 0, 22, 15, 6, 166, -11, 1, 0, 0, 0, 13, 0, 22, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (81161, 696254464, 1056, 268976133, 1245184, 8388736, 393224, 12292, 0, 1, 21, 0, 1, 0.0000, 0, 0, 1, 0, 1, 101, -1, 'Baker Team Broadcast Master', 'Summons the Redridge Team.', 6, 23, 0, 0, 60000, 0, 0, 0, 81155, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (82828, 541327376, 1056, 268435456, 65536, 0, 1024, 8388612, 0, 1, 0, 3, 95, 0.0000, 11039, 0, 3930, 0, 1, 101, -1, 'Feral Leap', 'Causes you to leap to an enemy.', 42, 0, 0, 0, 0, 5, 100, 15, 0, 64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (83669, 524288, 0, 0, 0, 0, 0, 0, 0, 20, 0, 0, 36, 28.0000, 7774, 0, 176, 0, 16, 101, -1, 'Water Bolt', 'Hurls a watery bolt at an enemy, inflicting moderate Frost damage.', 2, 0, 39, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (84867, 327696, 0, 0, 0, 0, 0, 0, 0, 1, 18, 1, 2, 0.0000, 189, 0, 565, 0, 1, 101, -1, 'Sundering Swipe', 'Swipes at an enemy, dealing weapon damage and reducing the target''s armor by $s2% per Sundering Swipe. Can be applied up to 5 times. Lasts $d.', 31, 0, 99, 1, 0, 0, 0, 0, 0, 6, 0, 6, 101, -6, 1, 0, 1, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (85424, 524288, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 2, 15.0000, 18239, 0, 9, 0, 32, 101, -1, 'Spirit Burst', 'Releases a burst of spectral energy at the enemy, dealing Shadow damage.', 2, 0, 22, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90798, 696254848, 1056, 273170437, 269681152, 8388736, 393224, 4608, 0, 1, 9, 0, 1, 0.0000, 0, 0, 1, 0, 1, 101, -1, 'Released Highborne', '', 28, 0, 0, 0, 0, 3748727, 64, 0, 0, 18, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (91667, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 7, 0.0000, 19354, 0, 1, 0, 1, 101, -1, 'Lilith''s Demonstration', '', 3, 0, 0, 0, 0, 0, 0, 0, 0, 38, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (91671, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 7, 0.0000, 19355, 0, 1, 0, 1, 101, -1, 'Lilith''s Demonstration (Final Blow)', '', 3, 0, 0, 0, 0, 0, 0, 0, 0, 38, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (91827, 696254848, 1056, 273170437, 269681152, 8388736, 393224, 4608, 0, 1, 0, 0, 7, 0.0000, 19369, 0, 1, 0, 1, 101, -1, 'Kilram''s Chop', '', 3, 0, 0, 0, 0, 0, 0, 0, 0, 25, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (93655, 524288, 0, 0, 0, 0, 0, 0, 0, 16, 0, 0, 7, 0.0000, 11064, 0, 1197, 0, 4, 101, -1, 'Steam Blast', 'Deals $s1 Fire damage to an enemy, knocking it back.', 2, 0, 19, 1, 0, 0, 0, 0, 0, 6, 0, 98, 0, 79, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (93661, 524288, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 4, 18.0000, 19626, 0, 1485, 0, 64, 101, -1, 'Arcane Barrage', 'Launches several missiles at the enemy target, inflicting Arcane damage.', 2, 0, 22, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (93711, 589824, 0, 0, 0, 0, 0, 0, 0, 20, 0, 0, 5, 24.0000, 8826, 0, 1485, 0, 64, 101, -1, 'Arcane Bolt', 'Hurls a magical bolt at an enemy, inflicting Arcane damage.', 2, 0, 12, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

-- ---------------------------------------------------------------------------
-- Verification after applying + restart:
--   SELECT COUNT(*) FROM spell_dbc WHERE ID IN (62804,75529,93711);   -- 3
--
-- Nothing changes in game from this file alone -- it is the prerequisite for
-- 217_, which turns AIName back on and imports the scripts that cast them.
-- ---------------------------------------------------------------------------
