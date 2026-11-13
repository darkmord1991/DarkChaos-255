-- EffectRadiusIndex repair for Cataclysm spells in spell_dbc -- every other downported Cata spell.
--
-- Cataclysm's SpellEffect.dbc leaves EffectRadiusIndex at 0 on many area effects and stores the radius in
-- EffectRadiusMaxIndex; TrinityCore 4.3.4 (SpellEffectInfo::CalcRadius) falls back to the max entry when the
-- plain one is 0. 3.3.5 has one radius column and the downport generators (HyjalCata/194_, 112_ and the ones
-- after them) copied only EffectRadiusIndex, so these area/cone effects searched a radius of 0 and hit nobody.
--
-- Each value is the Cata EffectRadiusMaxIndex of the same spell id and effect index, read from the 4.3.4
-- client (K:/UntouchedClients/Cata/Data/enUS/locale-enUS.MPQ SpellEffect.dbc). Every spell's name was checked
-- against the Cata Spell.dbc name first. Radius ids 1-65 are identical in both clients; the two Cata-only ids
-- used are mapped to ours: 67 (30 yd) -> 10 (30 yd) and 84 (17 yd) -> 19 (18 yd, nearest).
-- Only effects whose radius is still 0 are touched, so the file is safe to re-run.
-- Generator: K:/Dark-Chaos/retailextracts/_spellradius_fix_20261109/_scripts/ (plan_radius_fix.py, write_radius_sql.py).
-- WARNING, behaviour change: this includes Blackwing Descent, Firelands and Bastion boss abilities whose
-- area effects have hit nobody so far (Sonar Pulse, Pillar of Flame, Arcane Storm, Shadowblaze...).
-- Apply it on purpose, and watch those encounters afterwards; it is separate from the Silverpine fix.
-- 232 effects in 186 spells.

-- 73133 Frightened Tadpole
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 14 WHERE `ID` = 73133 AND `EffectRadiusIndex_1` = 0;

-- 73150 Summon Worgen Infiltrator
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 9 WHERE `ID` = 73150 AND `EffectRadiusIndex_2` = 0;

-- 73309 Lilian's Death Grip
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 10 WHERE `ID` = 73309 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 10 WHERE `ID` = 73309 AND `EffectRadiusIndex_2` = 0;

-- 74729 Leafy Wail
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 13 WHERE `ID` = 74729 AND `EffectRadiusIndex_1` = 0;

-- 74934 Inspire!
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 12 WHERE `ID` = 74934 AND `EffectRadiusIndex_1` = 0;

-- 74935 Incite!
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 12 WHERE `ID` = 74935 AND `EffectRadiusIndex_1` = 0;

-- 74937 Pander!
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 12 WHERE `ID` = 74937 AND `EffectRadiusIndex_1` = 0;

-- 75072 Inferno Ping
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 9 WHERE `ID` = 75072 AND `EffectRadiusIndex_1` = 0;

-- 75073 Shadow Nova
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 13 WHERE `ID` = 75073 AND `EffectRadiusIndex_2` = 0;

-- 76312 Earthsmash
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 20 WHERE `ID` = 76312 AND `EffectRadiusIndex_1` = 0;

-- 76480 Glancing Blows
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 12 WHERE `ID` = 76480 AND `EffectRadiusIndex_1` = 0;

-- 76643 Dismiss Orb of Ascension
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 12 WHERE `ID` = 76643 AND `EffectRadiusIndex_1` = 0;

-- 77355 Dragon Transformation
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 23 WHERE `ID` = 77355 AND `EffectRadiusIndex_2` = 0;

-- 77569 Release Aberrations
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 77569 AND `EffectRadiusIndex_1` = 0;

-- 77612 Modulation
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 77612 AND `EffectRadiusIndex_1` = 0;

-- 77615 Debilitating Slime
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 77615 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 28 WHERE `ID` = 77615 AND `EffectRadiusIndex_2` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_3` = 28 WHERE `ID` = 77615 AND `EffectRadiusIndex_3` = 0;

-- 77627 Summon Fiery Minion
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 31 WHERE `ID` = 77627 AND `EffectRadiusIndex_2` = 0;

-- 77672 Sonar Pulse
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 77672 AND `EffectRadiusIndex_1` = 0;

-- 77675 Sonar Pulse
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 8 WHERE `ID` = 77675 AND `EffectRadiusIndex_1` = 0;

-- 77699 Flash Freeze
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 8 WHERE `ID` = 77699 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 8 WHERE `ID` = 77699 AND `EffectRadiusIndex_2` = 0;

-- 77709 Resonating Clash
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 28 WHERE `ID` = 77709 AND `EffectRadiusIndex_2` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_3` = 28 WHERE `ID` = 77709 AND `EffectRadiusIndex_3` = 0;

-- 77715 Shatter
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 8 WHERE `ID` = 77715 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 8 WHERE `ID` = 77715 AND `EffectRadiusIndex_2` = 0;

-- 77716 Flash Freeze
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 77716 AND `EffectRadiusIndex_1` = 0;

-- 77760 Biting Chill
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 15 WHERE `ID` = 77760 AND `EffectRadiusIndex_1` = 0;

-- 77763 Biting Chill
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 15 WHERE `ID` = 77763 AND `EffectRadiusIndex_1` = 0;

-- 77770 Tortolla's Shell
UPDATE `spell_dbc` SET `EffectRadiusIndex_3` = 12 WHERE `ID` = 77770 AND `EffectRadiusIndex_3` = 0;

-- 77777 Molten Fury
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 23 WHERE `ID` = 77777 AND `EffectRadiusIndex_1` = 0;

-- 77828 Cue Fandral to Despawn
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 12 WHERE `ID` = 77828 AND `EffectRadiusIndex_1` = 0;

-- 77908 Arcane Storm
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 31 WHERE `ID` = 77908 AND `EffectRadiusIndex_1` = 0;

-- 77929 Chain Visual
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 77929 AND `EffectRadiusIndex_1` = 0;

-- 77940 Chain Visual
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 77940 AND `EffectRadiusIndex_1` = 0;

-- 77943 Lightning Discharge
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 48 WHERE `ID` = 77943 AND `EffectRadiusIndex_1` = 0;

-- 77948 Debilitating Slime
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 10 WHERE `ID` = 77948 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 10 WHERE `ID` = 77948 AND `EffectRadiusIndex_2` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_3` = 10 WHERE `ID` = 77948 AND `EffectRadiusIndex_3` = 0;

-- 77971 Pillar of Flame
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 8 WHERE `ID` = 77971 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 8 WHERE `ID` = 77971 AND `EffectRadiusIndex_2` = 0;

-- 77982 Searing Flame
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 77982 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 28 WHERE `ID` = 77982 AND `EffectRadiusIndex_2` = 0;

-- 77991 Release All Minions
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 77991 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 28 WHERE `ID` = 77991 AND `EffectRadiusIndex_2` = 0;

-- 77998 Pillar of Flame
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 22 WHERE `ID` = 77998 AND `EffectRadiusIndex_1` = 0;

-- 78010 Pillar of Flame
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 22 WHERE `ID` = 78010 AND `EffectRadiusIndex_1` = 0;

-- 78017 Pillar of Flame
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 28 WHERE `ID` = 78017 AND `EffectRadiusIndex_2` = 0;

-- 78068 Magma Spit
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 26 WHERE `ID` = 78068 AND `EffectRadiusIndex_1` = 0;

-- 78075 Sonic Breath
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 78075 AND `EffectRadiusIndex_1` = 0;

-- 78095 Magma Jets
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 15 WHERE `ID` = 78095 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 15 WHERE `ID` = 78095 AND `EffectRadiusIndex_2` = 0;

-- 78121 Twilight Blast
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 29 WHERE `ID` = 78121 AND `EffectRadiusIndex_1` = 0;

-- 78124 Magma Jets
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 15 WHERE `ID` = 78124 AND `EffectRadiusIndex_1` = 0;

-- 78206 Absolute Zero
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 15 WHERE `ID` = 78206 AND `EffectRadiusIndex_1` = 0;

-- 78207 Roaring Flame Breath
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 78207 AND `EffectRadiusIndex_1` = 0;

-- 78208 Absolute Zero
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 8 WHERE `ID` = 78208 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 8 WHERE `ID` = 78208 AND `EffectRadiusIndex_2` = 0;

-- 78225 Acid Nova
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 78225 AND `EffectRadiusIndex_1` = 0;

-- 78359 Magma Spit
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 26 WHERE `ID` = 78359 AND `EffectRadiusIndex_1` = 0;

-- 78360 Ride Vehicle
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 22 WHERE `ID` = 78360 AND `EffectRadiusIndex_1` = 0;

-- 78431 Roaring Flame Breath Fire Periodic
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 7 WHERE `ID` = 78431 AND `EffectRadiusIndex_1` = 0;

-- 78614 Test Filling
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 8 WHERE `ID` = 78614 AND `EffectRadiusIndex_1` = 0;

-- 78621 Shadowflame Barrage
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 78621 AND `EffectRadiusIndex_1` = 0;

-- 78643 Eject Passenger
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 23 WHERE `ID` = 78643 AND `EffectRadiusIndex_1` = 0;

-- 78696 Controller Recharge
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 78696 AND `EffectRadiusIndex_1` = 0;

-- 78827 Bladestorm
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 14 WHERE `ID` = 78827 AND `EffectRadiusIndex_1` = 0;

-- 78868 Devastation
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 78868 AND `EffectRadiusIndex_1` = 0;

-- 78945 Sonic Flames
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 26 WHERE `ID` = 78945 AND `EffectRadiusIndex_1` = 0;

-- 79035 Incineration Security Measure
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 79035 AND `EffectRadiusIndex_1` = 0;

-- 79318 Dominion
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 33 WHERE `ID` = 79318 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 33 WHERE `ID` = 79318 AND `EffectRadiusIndex_2` = 0;

-- 79339 Explosive Cinders
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 79339 AND `EffectRadiusIndex_1` = 0;

-- 79347 Explosive Cinders
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 13 WHERE `ID` = 79347 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 13 WHERE `ID` = 79347 AND `EffectRadiusIndex_2` = 0;

-- 79461 Emote - Magmaw Lava Splash
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 56 WHERE `ID` = 79461 AND `EffectRadiusIndex_2` = 0;

-- 79499 Acquiring Target
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 79499 AND `EffectRadiusIndex_1` = 0;

-- 79589 Constricting Chains
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 27 WHERE `ID` = 79589 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 27 WHERE `ID` = 79589 AND `EffectRadiusIndex_2` = 0;

-- 79617 Backdraft
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 79617 AND `EffectRadiusIndex_1` = 0;

-- 79624 Power Generator
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 79624 AND `EffectRadiusIndex_1` = 0;

-- 79629 Power Generator
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 8 WHERE `ID` = 79629 AND `EffectRadiusIndex_2` = 0;

-- 79813 Brushfire Start
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 79813 AND `EffectRadiusIndex_1` = 0;

-- 79889 Lightning Conductor
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 14 WHERE `ID` = 79889 AND `EffectRadiusIndex_1` = 0;

-- 79904 Charge
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 23 WHERE `ID` = 79904 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 23 WHERE `ID` = 79904 AND `EffectRadiusIndex_2` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_3` = 23 WHERE `ID` = 79904 AND `EffectRadiusIndex_3` = 0;

-- 79912 Static Shock
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 29 WHERE `ID` = 79912 AND `EffectRadiusIndex_1` = 0;

-- 79920 Shared Health
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 79920 AND `EffectRadiusIndex_1` = 0;

-- 80092 Poison Bomb
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 29 WHERE `ID` = 80092 AND `EffectRadiusIndex_1` = 0;

-- 80127 Flame Buffet
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 12 WHERE `ID` = 80127 AND `EffectRadiusIndex_2` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_3` = 12 WHERE `ID` = 80127 AND `EffectRadiusIndex_3` = 0;

-- 80336 Frost Burn
UPDATE `spell_dbc` SET `EffectRadiusIndex_3` = 12 WHERE `ID` = 80336 AND `EffectRadiusIndex_3` = 0;

-- 80550 Gout of Flame
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 8 WHERE `ID` = 80550 AND `EffectRadiusIndex_1` = 0;

-- 80600 Flame Stomp
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 13 WHERE `ID` = 80600 AND `EffectRadiusIndex_1` = 0;

-- 80607 Flamestep
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 15 WHERE `ID` = 80607 AND `EffectRadiusIndex_2` = 0;

-- 80648 Stormbolt
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 14 WHERE `ID` = 80648 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 14 WHERE `ID` = 80648 AND `EffectRadiusIndex_2` = 0;

-- 80835 Thundering Stomp
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 13 WHERE `ID` = 80835 AND `EffectRadiusIndex_1` = 0;

-- 80871 Bestowal of Thaurissan
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 80871 AND `EffectRadiusIndex_1` = 0;

-- 80872 Bestowal of Burningeye
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 80872 AND `EffectRadiusIndex_1` = 0;

-- 80873 Bestowal of Shadowforge
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 80873 AND `EffectRadiusIndex_1` = 0;

-- 80874 Bestowal of Anvilrage
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 80874 AND `EffectRadiusIndex_1` = 0;

-- 80875 Bestowal of Ironstar
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 80875 AND `EffectRadiusIndex_1` = 0;

-- 80876 Bestowal of Moltenfist
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 80876 AND `EffectRadiusIndex_1` = 0;

-- 80877 Bestowal of Corehammer
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 80877 AND `EffectRadiusIndex_1` = 0;

-- 80878 Bestowal of Angerforge
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 80878 AND `EffectRadiusIndex_1` = 0;

-- 80963 Shadow of Cowardice
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 80963 AND `EffectRadiusIndex_1` = 0;

-- 81007 Shadowblaze
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 26 WHERE `ID` = 81007 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 26 WHERE `ID` = 81007 AND `EffectRadiusIndex_2` = 0;

-- 81026 Sea Splash
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 13 WHERE `ID` = 81026 AND `EffectRadiusIndex_1` = 0;

-- 81140 Thunderclap
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 29 WHERE `ID` = 81140 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 29 WHERE `ID` = 81140 AND `EffectRadiusIndex_2` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_3` = 29 WHERE `ID` = 81140 AND `EffectRadiusIndex_3` = 0;

-- 81198 Electrocute
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 81198 AND `EffectRadiusIndex_1` = 0;

-- 81272 Electrocute
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 81272 AND `EffectRadiusIndex_1` = 0;

-- 81517 Onyxia Start Fight 2 Effect
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 33 WHERE `ID` = 81517 AND `EffectRadiusIndex_1` = 0;

-- 81573 Roaring Breath
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 27 WHERE `ID` = 81573 AND `EffectRadiusIndex_2` = 0;

-- 82848 Massacre
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 82848 AND `EffectRadiusIndex_1` = 0;

-- 82871 Caustic Slime Targeting
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 82871 AND `EffectRadiusIndex_1` = 0;

-- 83865 Sea Pup Trigger
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 33 WHERE `ID` = 83865 AND `EffectRadiusIndex_1` = 0;

-- 83935 Despawn All Summons
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 33 WHERE `ID` = 83935 AND `EffectRadiusIndex_1` = 0;

-- 84153 Petrified Delicacies Complete Trigger
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 27 WHERE `ID` = 84153 AND `EffectRadiusIndex_1` = 0;

-- 84709 Stomp
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 13 WHERE `ID` = 84709 AND `EffectRadiusIndex_1` = 0;

-- 85176 Execution Sentence
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 85176 AND `EffectRadiusIndex_1` = 0;

-- 85419 Bellowing Roar
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 8 WHERE `ID` = 85419 AND `EffectRadiusIndex_1` = 0;

-- 85873 Flow of Gratitude
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 13 WHERE `ID` = 85873 AND `EffectRadiusIndex_1` = 0;

-- 86180 Dark Plague
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 14 WHERE `ID` = 86180 AND `EffectRadiusIndex_1` = 0;

-- 88200 Captured
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 88200 AND `EffectRadiusIndex_1` = 0;

-- 88763 Despawn All Summons
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 33 WHERE `ID` = 88763 AND `EffectRadiusIndex_1` = 0;

-- 88794 Despawn All Summons
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 33 WHERE `ID` = 88794 AND `EffectRadiusIndex_1` = 0;

-- 88824 Sound Bar
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 88824 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 28 WHERE `ID` = 88824 AND `EffectRadiusIndex_2` = 0;

-- 89515 Xaravan's Transformation
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 13 WHERE `ID` = 89515 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 13 WHERE `ID` = 89515 AND `EffectRadiusIndex_2` = 0;

-- 89743 Ride Vehicle
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 10 WHERE `ID` = 89743 AND `EffectRadiusIndex_1` = 0;

-- 89798 Master Adventurer Award
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 89798 AND `EffectRadiusIndex_1` = 0;

-- 90414 Despawn All Summons
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 33 WHERE `ID` = 90414 AND `EffectRadiusIndex_1` = 0;

-- 90686 Fawnplode
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 32 WHERE `ID` = 90686 AND `EffectRadiusIndex_2` = 0;

-- 91213 Smash
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 13 WHERE `ID` = 91213 AND `EffectRadiusIndex_1` = 0;

-- 91220 Cowering Roar
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 27 WHERE `ID` = 91220 AND `EffectRadiusIndex_1` = 0;

-- 91325 Shadow Vortex
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 64 WHERE `ID` = 91325 AND `EffectRadiusIndex_2` = 0;

-- 91849 Grip of Death
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 12 WHERE `ID` = 91849 AND `EffectRadiusIndex_1` = 0;

-- 91858 Overcharged Power Generator
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 12 WHERE `ID` = 91858 AND `EffectRadiusIndex_2` = 0;

-- 91880 Arcane Blowback
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 19 WHERE `ID` = 91880 AND `EffectRadiusIndex_1` = 0;

-- 91896 Frost Burn
UPDATE `spell_dbc` SET `EffectRadiusIndex_3` = 12 WHERE `ID` = 91896 AND `EffectRadiusIndex_3` = 0;

-- 91902 Flame Buffet
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 12 WHERE `ID` = 91902 AND `EffectRadiusIndex_2` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_3` = 12 WHERE `ID` = 91902 AND `EffectRadiusIndex_3` = 0;

-- 91904 Charge
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 23 WHERE `ID` = 91904 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 23 WHERE `ID` = 91904 AND `EffectRadiusIndex_2` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_3` = 23 WHERE `ID` = 91904 AND `EffectRadiusIndex_3` = 0;

-- 92023 Encasing Shadows
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 92023 AND `EffectRadiusIndex_1` = 0;

-- 92048 Shadow Infusion
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 92048 AND `EffectRadiusIndex_1` = 0;

-- 92051 Shadow Conductor
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 12 WHERE `ID` = 92051 AND `EffectRadiusIndex_1` = 0;

-- 92119 Ignition
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 16 WHERE `ID` = 92119 AND `EffectRadiusIndex_1` = 0;

-- 92135 Shadow Conductor
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 12 WHERE `ID` = 92135 AND `EffectRadiusIndex_1` = 0;

-- 92154 Blazing Inferno
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 26 WHERE `ID` = 92154 AND `EffectRadiusIndex_2` = 0;

-- 92173 Shadow Breath
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 8 WHERE `ID` = 92173 AND `EffectRadiusIndex_1` = 0;

-- 92452 Modulation
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 92452 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 28 WHERE `ID` = 92452 AND `EffectRadiusIndex_2` = 0;

-- 92453 Modulation
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 92453 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 28 WHERE `ID` = 92453 AND `EffectRadiusIndex_2` = 0;

-- 92526 Sonar Pulse
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 22 WHERE `ID` = 92526 AND `EffectRadiusIndex_1` = 0;

-- 92553 Sonar Bomb
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 29 WHERE `ID` = 92553 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 29 WHERE `ID` = 92553 AND `EffectRadiusIndex_2` = 0;

-- 92607 Destroy Shield
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 12 WHERE `ID` = 92607 AND `EffectRadiusIndex_1` = 0;

-- 93369 Tesseract Arc
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 21 WHERE `ID` = 93369 AND `EffectRadiusIndex_1` = 0;

-- 93423 Asphyxiate
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 48 WHERE `ID` = 93423 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 48 WHERE `ID` = 93423 AND `EffectRadiusIndex_2` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_3` = 48 WHERE `ID` = 93423 AND `EffectRadiusIndex_3` = 0;

-- 93468 Stay of Execution
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 48 WHERE `ID` = 93468 AND `EffectRadiusIndex_1` = 0;

-- 93505 Conjure Frost Mixture
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 8 WHERE `ID` = 93505 AND `EffectRadiusIndex_2` = 0;

-- 93553 Twilight Zone
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 8 WHERE `ID` = 93553 AND `EffectRadiusIndex_1` = 0;

-- 93556 Unleashed Magic
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 48 WHERE `ID` = 93556 AND `EffectRadiusIndex_1` = 0;

-- 93689 Toxic Catalyst
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 48 WHERE `ID` = 93689 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 48 WHERE `ID` = 93689 AND `EffectRadiusIndex_2` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_3` = 48 WHERE `ID` = 93689 AND `EffectRadiusIndex_3` = 0;

-- 93697 Conjure Poisonous Mixture
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 26 WHERE `ID` = 93697 AND `EffectRadiusIndex_2` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_3` = 26 WHERE `ID` = 93697 AND `EffectRadiusIndex_3` = 0;

-- 93720 Wracking Pain
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 48 WHERE `ID` = 93720 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 48 WHERE `ID` = 93720 AND `EffectRadiusIndex_2` = 0;

-- 93956 Cursed Veil
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 23 WHERE `ID` = 93956 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 48 WHERE `ID` = 93956 AND `EffectRadiusIndex_2` = 0;

-- 94085 Shadowblaze
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 26 WHERE `ID` = 94085 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 26 WHERE `ID` = 94085 AND `EffectRadiusIndex_2` = 0;

-- 94086 Shadowblaze
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 26 WHERE `ID` = 94086 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 26 WHERE `ID` = 94086 AND `EffectRadiusIndex_2` = 0;

-- 94087 Shadowblaze
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 26 WHERE `ID` = 94087 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 26 WHERE `ID` = 94087 AND `EffectRadiusIndex_2` = 0;

-- 94113 Lightning Discharge
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 48 WHERE `ID` = 94113 AND `EffectRadiusIndex_1` = 0;

-- 94114 Lightning Discharge
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 48 WHERE `ID` = 94114 AND `EffectRadiusIndex_1` = 0;

-- 94115 Lightning Discharge
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 48 WHERE `ID` = 94115 AND `EffectRadiusIndex_1` = 0;

-- 94211 Dominion
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 33 WHERE `ID` = 94211 AND `EffectRadiusIndex_1` = 0;

-- 94947 Despawn Spawn of Smolderos [INTERNAL]
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 27 WHERE `ID` = 94947 AND `EffectRadiusIndex_1` = 0;

-- 94996 Ride Vehicle
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 10 WHERE `ID` = 94996 AND `EffectRadiusIndex_1` = 0;

-- 95038 Wind Shear
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 9 WHERE `ID` = 95038 AND `EffectRadiusIndex_1` = 0;

-- 95499 Electrical Discharge Trigger
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 22 WHERE `ID` = 95499 AND `EffectRadiusIndex_1` = 0;

-- 95929 Bullet Time Credit (Achievement)
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 95929 AND `EffectRadiusIndex_1` = 0;

-- 95930 Bullet Time Reset (Achievement)
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 95930 AND `EffectRadiusIndex_1` = 0;

-- 96344 Pistol Barrage
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 96344 AND `EffectRadiusIndex_1` = 0;

-- 97240 Call the Flock
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 10 WHERE `ID` = 97240 AND `EffectRadiusIndex_1` = 0;

-- 97246 Fiery Boulder
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 26 WHERE `ID` = 97246 AND `EffectRadiusIndex_1` = 0;

-- 97693 Flash Freeze Targeting
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 28 WHERE `ID` = 97693 AND `EffectRadiusIndex_1` = 0;

-- 97773 Flame Protection Runes Extinguished Credit
UPDATE `spell_dbc` SET `EffectRadiusIndex_3` = 12 WHERE `ID` = 97773 AND `EffectRadiusIndex_3` = 0;

-- 98187 Small Threat Towards Hyjal Wisp
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 18 WHERE `ID` = 98187 AND `EffectRadiusIndex_1` = 0;

-- 98826 Furnace Assault Credit
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 48 WHERE `ID` = 98826 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 12 WHERE `ID` = 98826 AND `EffectRadiusIndex_2` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_3` = 48 WHERE `ID` = 98826 AND `EffectRadiusIndex_3` = 0;

-- 98839 Backdraft
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 48 WHERE `ID` = 98839 AND `EffectRadiusIndex_2` = 0;

-- 99589 Flame Seed
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 13 WHERE `ID` = 99589 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 13 WHERE `ID` = 99589 AND `EffectRadiusIndex_2` = 0;

-- 100052 Clean Up Stink Bomb
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 26 WHERE `ID` = 100052 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 26 WHERE `ID` = 100052 AND `EffectRadiusIndex_2` = 0;

-- 100378 Flame Spout
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 48 WHERE `ID` = 100378 AND `EffectRadiusIndex_1` = 0;

-- 100659 Crushing Flame
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 27 WHERE `ID` = 100659 AND `EffectRadiusIndex_1` = 0;
UPDATE `spell_dbc` SET `EffectRadiusIndex_2` = 27 WHERE `ID` = 100659 AND `EffectRadiusIndex_2` = 0;

-- 100700 Parasitic Injection
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 9 WHERE `ID` = 100700 AND `EffectRadiusIndex_1` = 0;

-- 107831 Blast of Corruption
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 13 WHERE `ID` = 107831 AND `EffectRadiusIndex_1` = 0;

-- 107997 Whirling Maw
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 13 WHERE `ID` = 107997 AND `EffectRadiusIndex_1` = 0;

-- 108000 Nick of Time
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 23 WHERE `ID` = 108000 AND `EffectRadiusIndex_1` = 0;

-- 108005 Shadowbolt Volley
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 13 WHERE `ID` = 108005 AND `EffectRadiusIndex_1` = 0;

-- 109752 Whirling Maw
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 13 WHERE `ID` = 109752 AND `EffectRadiusIndex_1` = 0;

-- 109754 Whirling Maw
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 13 WHERE `ID` = 109754 AND `EffectRadiusIndex_1` = 0;

-- 109798 Shadowbolt Volley
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 13 WHERE `ID` = 109798 AND `EffectRadiusIndex_1` = 0;

-- 109800 Shadowbolt Volley
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 13 WHERE `ID` = 109800 AND `EffectRadiusIndex_1` = 0;

-- 109822 Nick of Time
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 23 WHERE `ID` = 109822 AND `EffectRadiusIndex_1` = 0;

-- 109825 Nick of Time
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 23 WHERE `ID` = 109825 AND `EffectRadiusIndex_1` = 0;

-- 109851 Blast of Corruption
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 13 WHERE `ID` = 109851 AND `EffectRadiusIndex_1` = 0;

-- 109854 Blast of Corruption
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 13 WHERE `ID` = 109854 AND `EffectRadiusIndex_1` = 0;

-- 109907 Fel Immolation
UPDATE `spell_dbc` SET `EffectRadiusIndex_1` = 14 WHERE `ID` = 109907 AND `EffectRadiusIndex_1` = 0;
