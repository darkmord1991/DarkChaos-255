-- ---------------------------------------------------------------------------
-- 203  Map 750 -- the 45 spells the imported SmartAI scripts cast
-- ---------------------------------------------------------------------------
-- Stage 1 of restoring the SmartAI behaviour that 204_ imports. 102 creature
-- templates on map 750 carry AIName = 'SmartAI' with no script rows (the
-- imports copied the column, not the tables). Those scripts contain 156 CAST
-- actions across 117 distinct spells, and 45 of them exist in NEITHER the
-- binary Spell.dbc NOR the spell_dbc overlay.
--
-- Spells go FIRST deliberately: importing the scripts before the spells would
-- just trade "no SmartAI entries" for a stream of "unknown spell" errors every
-- time a creature tried to cast.
--
--   62164  Three Hammers to Break: Villain Au effects: E0=6/aura 4
--   62238  Unstable Lightning Blast           effects: E0=27/aura 3
--   62294  Heal                               effects: E0=10/aura 0
--   63843  Script Cast Summon Vile Spray      effects: E0=77/aura 0
--   64041  Throw Spear                        effects: E0=2/aura 0
--   64437  Flame Arrow Aura                   effects: E0=6/aura 23
--   64954  Water Bolt                         effects: E0=2/aura 0
--   65060  Twilight Bolt                      effects: E0=2/aura 0
--   65127  Darkshore Wisp Sparkle             effects: E0=3/aura 0
--   74972  Greymist                           effects: E0=6/aura 54
--   74975  Purse Snatch                       effects: E0=31/aura 0, E1=6/aura 4
--   75002  Leaping Rush                       effects: E0=41/aura 0, E1=31/aura 0
--   75004  Pinch                              effects: E0=31/aura 0, E1=6/aura 4
--   75008  Pounce                             effects: E0=31/aura 0, E1=6/aura 12
--   75011  Lunar Blessing                     effects: E0=10/aura 0, E1=6/aura 8
--   75014  Howl of Madness                    effects: E0=6/aura 99
--   75015  Curse of Shadows                   effects: E0=6/aura 22, E1=6/aura 87
--   75016  Defiled Ground                     effects: E0=27/aura 3
--   75017  Curse of Doom                      effects: E0=6/aura 3
--   75019  Twilight's Wrath                   effects: E0=2/aura 0, E1=64/aura 0
--   75021  Prismatic Gaze                     effects: E0=6/aura 22, E1=6/aura 87
--   75023  Boulder Toss                       effects: E0=2/aura 0
--   75025  Rush of Flame                      effects: E0=149/aura 0, E1=77/aura 0
--   75059  Shatter Armor                      effects: E0=6/aura 101, E1=6/aura 79
--   75060  Critical Focus                     effects: E0=6/aura 290
--   75061  Taste of Corruption                effects: E0=6/aura 3
--   75062  Frost Nova                         effects: E0=2/aura 0, E1=6/aura 26
--   75068  Lava Burst                         effects: E0=2/aura 0
--   75079  Blast of Air                       effects: E0=98/aura 0
--   75097  Summon Tamed Crab                  effects: E0=28/aura 0
--   78744  Bubblebeam                         effects: E0=6/aura 23
--   79444  Impale                             effects: E0=31/aura 0, E1=6/aura 3
--   79607  Venom Splash                       effects: E0=27/aura 3
--   81109  Poison Bolt                        effects: E0=2/aura 0
--   81253  Glaive                             effects: E0=2/aura 0, E1=77/aura 0, E2=98/aura 0
--   86073  Flamethrower                       effects: E0=6/aura 23
--   86249  Throw                              effects: E0=31/aura 0
--   87187  Feral Charge                       effects: E0=96/aura 0
--   88330  Enchanted Imp Sack                 effects: E0=6/aura 296
--   89515  Xaravan's Transformation           effects: E0=2/aura 0, E1=98/aura 0
--   89829  Oiled Up                           effects: E0=6/aura 4
--   90106  Chain                              effects: E0=6/aura 4
--   90126  Taxi: Whisperwind Grove to Irontre effects: E0=123/aura 0
--   90155  Taxi: Whisperwind Grove to Talonbr effects: E0=123/aura 0
--   95826  Shoot                              effects: E0=31/aura 0
--
-- SOURCE and METHOD are exactly as documented in 194_ -- Spell.dbc +
-- SpellEffect.dbc from K:\UntouchedClients\Cata (Data\enUS\locale-enUS.MPQ),
-- with the 4.3.4 column layout calibrated against spells present in both
-- versions, and DieSides = 1 / BasePoints = (cata value - 1) to reproduce
-- 3.3.5's BasePoints + rand(1..DieSides) arithmetic.
--
-- ONE ID REMAP: spell 75097 "Script Cast Summon Tamed Crawler" has Effect 28
-- (SUMMON) with EffectMiscValue 40271. That is a creature entry, so it is
-- rewritten to 3740271 -- the map-750 clone band -- or the spell would summon
-- a creature that does not exist here. 204_ imports that template. No other
-- spell in this batch references a creature, item or quest id.
--
-- Apply against acore_world BEFORE 204_, then restart worldserver. spell_dbc is
-- a server-side overlay, so no client update is needed for the server to
-- resolve these. Idempotent.
-- ---------------------------------------------------------------------------

DELETE FROM `spell_dbc` WHERE `ID` IN (
  62164, 62238, 62294, 63843, 64041, 64437, 64954, 65060, 65127, 74972, 74975, 75002, 75004, 75008, 75011, 75014, 75015, 75016, 75017, 75019, 75021, 75023, 75025, 75059, 75060, 75061, 75062, 75068, 75079, 75097, 78744, 79444, 79607, 81109, 81253, 86073, 86249, 87187, 88330, 89515, 89829, 90106, 90126, 90155, 95826);

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
  (62164, 134217984, 268435520, 0, 1048576, 192, 8, 0, 0, 1, 21, 0, 1, 0.0000, 13110, 0, 197, 197, 1, 101, -1, 'Three Hammers to Break: Villain Aura', '', 6, 4, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (62238, 589824, 268437640, 0, 0, 32, 0, 0, 0, 19, 31, 0, 5, 10.0000, 13120, 0, 1749, 0, 8, 101, -1, 'Unstable Lightning Blast', 'Shoots a bolt of lightning, inflicting nature damage on all enemies in a selected area every $t1 sec. for $d.', 27, 3, 2, 1, 2000, 0, 0, 8, 0, 28, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (62294, 0, 0, 0, 0, 0, 0, 0, 0, 14, 0, 0, 169, 0.0000, 135, 0, 104, 0, 2, 101, -1, 'Heal', 'Heal your target for $s1.', 10, 0, 293, 1, 0, 0, 0, 0, 0, 38, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (63843, 536871168, 1024, 4, 1048576, 128, 8, 0, 0, 1, 0, 0, 7, 10.0000, 13497, 0, 1, 0, 1, 101, -1, 'Script Cast Summon Vile Spray', '', 77, 0, 0, 0, 0, 0, 0, 20, 0, 18, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (64041, 4194320, 1024, 4, 268435456, 0, 0, 8, 0, 3, 0, 0, 37, 35.0000, 13524, 0, 370, 0, 1, 101, -1, 'Throw Spear', 'Hurls a harpoon at the target, inflicting $s1 damage.', 2, 0, 51, 1, 0, 0, 0, 27, 0, 22, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (64437, 16777216, 301989888, 0, 0, 128, 0, 4096, 0, 1, 21, 0, 1, 0.0000, 0, 0, 2128, 0, 1, 101, -1, 'Flame Arrow Aura', 'Fires an arrow of frost that does massive damage and slows movement speed.', 6, 23, 0, 0, 3000, 0, 0, 0, 64439, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (64954, 524288, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 36, 28.0000, 13765, 0, 176, 0, 16, 101, -1, 'Water Bolt', 'Hurls a watery bolt at an enemy, inflicting $s1 Frost damage.', 2, 0, 31, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (65060, 589824, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 152, 35.0000, 64, 0, 213, 0, 32, 101, -1, 'Twilight Bolt', 'Hurls a bolt of dark magic at an enemy, inflicting Shadow damage.', 2, 0, 22, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (65127, 0, 1024, 0, 0, 0, 0, 0, 0, 1, 0, 0, 34, 0.0000, 13814, 0, 1, 0, 8, 101, -1, 'Darkshore Wisp Sparkle', '', 3, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (74972, 262160, 0, 0, 0, 0, 0, 0, 0, 4, 1, 0, 7, 10.0000, 70, 0, 1751, 0, 1, 101, -1, 'Greymist', 'Tosses dirt into an enemy''s eyes, reducing its chance to hit by $s1% for $d.', 6, 54, -41, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (74975, 0, 0, 0, 0, 0, 0, 0, 0, 1, 8, 0, 2, 0.0000, 208, 0, 3210, 0, 1, 101, -1, 'Purse Snatch', 'Attempts to steal the target''s money... if it fails, deals $s1% weapon damage and embarrasses the target for $d.', 31, 0, 114, 1, 0, 0, 0, 0, 0, 6, 0, 6, 4, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (75002, 0, 0, 4, 0, 0, 0, 65536, 0, 1, 0, 0, 151, 20.0000, 17939, 0, 457, 0, 1, 101, -1, 'Leaping Rush', 'Jumps at the target, inflicting $s2% weapon damage.', 41, 0, 0, 0, 0, 0, 30, 0, 0, 6, 0, 31, 0, 99, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (75004, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 2, 0.0000, 8048, 0, 1580, 0, 1, 101, -1, 'Pinch', 'Deals $s1% weapon damage, leaving the target sore for $d.', 31, 0, 114, 1, 0, 0, 0, 0, 0, 6, 0, 6, 4, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (75008, 16, 136, 4, 256, 0, 0, 0, 0, 1, 27, 0, 7, 0.0000, 3942, 0, 262, 0, 1, 101, -1, 'Pounce', 'Inflicts normal damage and stuns an enemy.', 31, 0, 99, 1, 0, 0, 0, 0, 0, 6, 0, 6, 12, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (75011, 589824, 0, 0, 0, 0, 0, 0, 0, 5, 86, 0, 5, 0.0000, 3884, 0, 197, 0, 8, 101, -1, 'Lunar Blessing', 'Heals an ally for a fixed amount, then heals additional damage every $t2 sec. for $d.', 10, 0, 74, 1, 0, 0, 0, 0, 0, 21, 0, 6, 8, 19, 1, 3000, 0, 0, 0, 0, 21, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (75014, 327696, 0, 0, 0, 0, 0, 0, 0, 1, 9, 1, 1, 0.0000, 210, 0, 282, 0, 1, 101, -1, 'Howl of Madness', 'Reduces the melee attack power of nearby enemies for $d.', 6, 99, -11, 1, 0, 0, 0, 13, 0, 22, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (75015, 65536, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 4, 0.0000, 346, 0, 542, 0, 32, 101, -1, 'Curse of Shadows', 'Curses the target for $d, reducing Shadow and Arcane resistances by $s1 and increasing Shadow and Arcane damage taken by $s2%.', 6, 22, -51, 1, 0, 96, 0, 0, 0, 6, 0, 6, 87, 99, 1, 0, 96, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (75016, 589824, 2176, 0, 0, 0, 0, 0, 0, 1, 8, 0, 1, 0.0000, 15752, 0, 2384, 0, 32, 101, -1, 'Defiled Ground', 'Desecrates the land beneath caster, doing $o1 Shadow damage over $d to enemies who enter the area.', 27, 3, 0, 1, 1000, 0, 0, 15, 0, 18, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (75017, 524288, 2184, 0, 0, 0, 0, 0, 0, 16, 29, 0, 13, 0.0000, 5019, 0, 91, 0, 32, 101, -1, 'Curse of Doom', 'Dooms the target, inflicting Shadow damage after $d.', 6, 3, 17, 1, 12000, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (75019, 589824, 0, 0, 0, 0, 0, 0, 0, 14, 0, 0, 5, 24.0000, 15753, 0, 213, 0, 34, 101, -1, 'Twilight''s Wrath', 'Hurls a bolt of twisted magic at an enemy, inflicting Twilight damage.', 2, 0, 47, 1, 0, 0, 0, 0, 0, 6, 0, 64, 0, 0, 0, 0, 0, 0, 0, 75020, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (75021, 65536, 0, 0, 0, 0, 0, 0, 0, 1, 9, 0, 4, 0.0000, 785, 0, 55, 0, 60, 101, -1, 'Prismatic Gaze', 'Curses the target for $d, reducing Fire, Frost and Nature resistances by $s1 and increasing Fire, Frost and Nature damage taken by $s2%.  Only one Curse per Warlock can be active on any one target.', 6, 22, -51, 1, 0, 28, 0, 0, 0, 6, 0, 6, 87, 9, 1, 0, 28, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (75023, 4784144, 0, 4, 256, 0, 0, 0, 0, 4, 0, 0, 37, 16.0000, 11447, 0, 2450, 0, 1, 101, -1, 'Boulder Toss', 'Hurls a boulder at an enemy, inflicting Physical damage.', 2, 0, 22, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (75025, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0000, 7779, 0, 2127, 0, 1, 101, -1, 'Rush of Flame', 'The fire elemental rushes forward, leaving a blazing train behind.', 149, 0, 0, 0, 0, 0, 0, 9, 0, 47, 0, 77, 0, 75023, 1, 0, 5, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (75059, 0, 0, 0, 0, 0, 0, 0, 0, 5, 8, 0, 4, 0.0000, 3444, 0, 559, 0, 8, 101, -1, 'Shatter Armor', 'Reduces an enemy''s armor by $s1% for $d.
Reduces an enemy''s damage by $s2% for $d.', 6, 101, -51, 1, 0, 1, 0, 0, 0, 6, 0, 6, 79, -36, 1, 0, 1, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (75060, 0, 0, 0, 0, 0, 0, 0, 0, 5, 9, 0, 1, 0.0000, 254, 0, 2112, 0, 1, 101, -1, 'Critical Focus', 'Causes the caster''s next melee attack to be a critical strike.', 6, 290, 99, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (75061, 589824, 2048, 0, 0, 0, 0, 0, 0, 5, 8, 0, 4, 0.0000, 8629, 0, 313, 0, 32, 101, -1, 'Taste of Corruption', 'Corrupts an enemy, inflicting Shadow damage every $t1 sec. over $d.', 6, 3, 3, 1, 3000, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (75062, 1074331648, 136, 4, 0, 0, 0, 0, 0, 5, 31, 0, 1, 0.0000, 17, 0, 193, 0, 16, 101, -1, 'Frost Nova', 'Inflicts Frost damage to nearby enemies, immobilizing them for up to $d.', 2, 0, 25, 1, 0, 0, 0, 13, 0, 22, 15, 6, 26, 0, 0, 0, 0, 0, 13, 0, 22, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (75068, 589824, 0, 0, 1048576, 0, 0, 0, 0, 5, 0, 0, 4, 24.0000, 11565, 0, 3064, 0, 4, 101, -1, 'Lava Burst', 'You hurl molten lava at the target, dealing Fire damage. If your Flame Shock is on the target, Lava Burst will deal a critical strike.', 2, 0, 31, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (75079, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0000, 12183, 0, 1931, 0, 1, 101, -1, 'Blast of Air', 'A might gust of wind knocks away all opponents.', 98, 0, 74, 1, 0, 75, 0, 27, 0, 18, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (75097, 268435456, 0, 0, 0, 0, 0, 0, 0, 1, 21, 0, 1, 0.0000, 0, 0, 271, 0, 1, 101, -1, 'Summon Tamed Crab', 'Summons Tamed Crawler to fight for the caster.', 28, 0, 0, 1, 0, 3740271, 67, 0, 0, 18, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (78744, 524288, 16388, 0, 0, 0, 0, 0, 0, 1, 27, 1, 3, 0.0000, 16646, 0, 2379, 0, 16, 101, -1, 'Bubblebeam', 'Inflicts Frost damage to an enemy.', 6, 23, 0, 0, 500, 0, 0, 0, 78743, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (79444, 524288, 2048, 0, 0, 0, 0, 0, 0, 1, 105, 0, 14, 30.0000, 8855, 0, 370, 0, 1, 101, -1, 'Impale', 'Throws a spear at a target, dealing $s1% damage and an additional damage every $t2 sec. for $d.', 31, 0, 186, 1, 0, 0, 0, 0, 0, 6, 0, 6, 3, 3, 1, 3000, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (79607, 524288, 2184, 0, 0, 0, 0, 0, 0, 5, 1, 0, 5, 12.0000, 16863, 0, 636, 0, 8, 101, -1, 'Venom Splash', 'Deals Nature damage to all enemies within the venom. Lasts $d.', 27, 3, 3, 1, 3000, 0, 0, 26, 0, 53, 28, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (81109, 524288, 0, 0, 0, 0, 0, 0, 0, 19, 0, 0, 4, 40.0000, 5923, 0, 68, 0, 8, 101, -1, 'Poison Bolt', 'Shoots poison at an enemy, inflicting Nature damage.', 2, 0, 39, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (81253, 4784144, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 38, 20.0000, 8512, 0, 2320, 0, 1, 101, -1, 'Glaive', 'Throws a glaive at an enemy, inflicting Physical damage.', 2, 0, 22, 1, 0, 0, 0, 0, 0, 6, 0, 77, 0, 36506, 1, 0, 0, 0, 0, 0, 6, 0, 98, 0, 59, 1, 0, 60, 0, 0, 0, 6, 0),
  (86073, 262144, 268435520, 0, 0, 0, 0, 0, 0, 1, 21, 0, 1, 0.0000, 18201, 0, 1923, 0, 4, 101, -1, 'Flamethrower', 'Deals Fire damage to all enemies in a cone in front of the caster for $d.', 6, 23, 0, 0, 1000, 0, 0, 0, 86074, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (86249, 327680, 0, 0, 0, 0, 0, 0, 0, 16, 0, 0, 35, 12.0000, 8855, 0, 2376, 0, 1, 101, -1, 'Throw', 'Throws your weapon, inflicting its $s1% of its damage on the target.', 31, 0, 149, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (87187, 537133072, 1024, 0, 0, 0, 0, 8388608, 264192, 1, 0, 1, 95, 0.0000, 5162, 0, 1559, 0, 1, 101, -1, 'Feral Charge', 'Causes you to charge an enemy.', 96, 0, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (88330, 0, 0, 0, 0, 0, 0, 0, 0, 1, 21, 0, 4, 0.0000, 18705, 0, 4751, 0, 1, 101, -1, 'Enchanted Imp Sack', '', 6, 296, 0, 0, 0, 1264, 0, 0, 0, 25, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (89515, 0, 524288, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0000, 19050, 0, 2366, 0, 36, 101, -1, 'Xaravan''s Transformation', 'Xaravan reveals his true form, dealing $s1 shadow damage and knocking the target back.', 2, 0, 99, 1, 0, 0, 0, 0, 0, 22, 7, 98, 0, 99, 1, 0, 200, 0, 0, 0, 22, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (89829, 0, 0, 0, 0, 0, 0, 0, 0, 1, 9, 0, 1, 0.0000, 10249, 0, 3770, 0, 1, 101, -1, 'Oiled Up', 'This shredder''s been oiled up! Find one that needs it more!', 6, 4, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90106, 696254848, 268436512, 273170437, 269943296, 8388736, 393224, 4608, 0, 1, 21, 0, 13, 12.0000, 19149, 0, 1958, 0, 1, 101, -1, 'Chain', '', 6, 4, 0, 0, 0, 0, 0, 0, 0, 25, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90126, 384, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 4, 0.0000, 0, 0, 1, 0, 1, 101, -1, 'Taxi: Whisperwind Grove to Irontree Clearing', '', 123, 0, 0, 0, 0, 2549, 0, 0, 0, 25, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90155, 384, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 4, 0.0000, 0, 0, 1, 0, 1, 101, -1, 'Taxi: Whisperwind Grove to Talonbranch Glade', '', 123, 0, 0, 0, 0, 2248, 0, 0, 0, 25, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (95826, 4718610, 0, 4, 0, 0, 0, 16384, 0, 1, 0, 0, 155, 40.0000, 0, 0, 126, 0, 1, 101, -1, 'Shoot', 'Shoots at an enemy, inflicting Physical damage.', 31, 0, 99, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

-- ---------------------------------------------------------------------------
-- Verification after applying + restart:
--   SELECT COUNT(*) FROM spell_dbc WHERE ID IN
--     (62164,62238,74972,75097,88330,95826);                                -- 6
--   SELECT ID, Name_Lang_enUS, Effect_1, EffectMiscValue_1 FROM spell_dbc
--    WHERE ID = 75097;   -- EffectMiscValue_1 must be 3740271, NOT 40271
-- ---------------------------------------------------------------------------
