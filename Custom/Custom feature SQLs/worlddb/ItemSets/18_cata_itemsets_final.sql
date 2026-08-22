-- -------------------------------------------------------------------------
-- The last 22 Cataclysm item sets, adapted to 3.3.5 -- data only, no C++
-- -------------------------------------------------------------------------
-- Every bonus here carried SPELL_AURA_DUMMY. In Cataclysm a script gives each one
-- its behaviour; several of those behaviours cannot exist on this core at all
-- (Focus, Shadow Orbs, Holy Power, Lunar Energy, Runic Empowerment, Pulverize,
-- Chakra), and the rest would need script hooks whose correctness cannot be checked
-- from here.
--
-- So each dummy is CONVERTED INTO A PLAIN MODIFIER AURA aimed at a 3.3.5 ability
-- that fills the same role. Every one of these sets therefore does something real
-- and on-theme, but these are INTERPRETATIONS, not reproductions. The per-bonus
-- reasoning is listed below so any of them can be argued with and changed -- the
-- values live in spell_dbc, so re-tuning is a DB edit and never a rebuild.
--
-- Where a bonus had two halves that collapsed into one, the second is zeroed rather
-- than left pointing at nothing.
-- -------------------------------------------------------------------------
--
--   911   Gladiator's Thunderfist
--         100956:0    +10% damage    on Lightning Shield      
--                     charge accounting is not reachable from a script hook; buff the shield instead
--
--   916   Gladiator's Investiture
--         33333:0     +10% damage    on Power Word: Shield    
--                     snare immunity needs a new mechanic; a stronger shield keeps the defensive intent
--
--   921   Gladiator's Wildhide
--         46832:0     +5% damage    on Moonfire              
--                     Solar/Lunar energy does not exist as a resource in 3.3.5
--
--   925   Magma Plated Battlegear
--         90459:0     +5% damage    on Obliterate            
--                     Death Rune generation has no clean hook; the 2pc already covers Death Coil/Frost Strike
--
--   929   Stormrider's Regalia
--         90163:0     +5% crit      on Starfire              
--                     keeps the original "+spell crit after Eclipse" intent on the Eclipse payoff spell
--
--   932   Reinforced Sapphirium Battleplate
--         90299:0     +10% duration  on Avenging Wrath        
--                     Inquisition and Holy Power do not exist; kept as a duration bonus on the cooldown
--
--   935   Mercurial Vestments
--         89911:0     +5% crit      on Penance               
--                     Chakra does not exist; Penance itself is the ability the bonus keys off
--
--   1003  Obsidian Arborweave Regalia
--         99049:0     +3% damage    on Wrath                 
--                     Lunar Energy generation has no equivalent; Wrath is the spell it fed
--
--   1010  Regalia of the Cleansing Flame
--         99157:0     +10% damage    on Mind Flay             
--                     the three-DoT check is script-only; Mind Flay is the shadow filler it empowered
--
--   1014  Volcanic Vestments
--         99195:0     +5% damage    on Chain Heal            
--                     Riptide consumption lives inside stock Chain Heal; buff Chain Heal directly
--
--   1016  Volcanic Regalia
--         99202:0     -10% cooldown  on Fire Elemental Totem  
--                     a full cooldown reset is script-only; a flat reduction is the data equivalent
--
--   1057  Necrotic Boneplate Battlegear
--         105609:0    +6% damage    on Death Coil            
--                     Sudden Doom charge granting is script-only; Death Coil is what Sudden Doom feeds
--         105609:1    zeroed -- second half folded into effect 1
--         105646:0    +5% damage    on Frost Strike          
--                     Runic Empowerment and Runic Corruption are Cataclysm-only mechanics
--         105646:1    zeroed -- second half folded into effect 1
--
--   1058  Deep Earth Battlegarb
--         105725:0    +10% damage    on Mangle (Bear)         
--                     Pulverize does not exist; Mangle (Bear) is the ability the bonus keyed off
--         105725:1    zeroed -- second half folded into effect 1
--         105735:0    +15% duration  on Frenzied Regeneration 
--                     raid-wide Frenzied Regeneration needs a spell that does not exist
--         105735:1    zeroed -- second half folded into effect 1
--
--   1060  Deep Earth Vestments
--         105770:0    +10% duration  on Rejuvenation          
--                     keeps the "longer HoT" intent; doubling was rescaled to +10% for 3.3.5 scaling
--
--   1061  Wyrmstalker Battlegear
--         105732:0    -35% cost      on Steady Shot           
--                     FOCUS DOES NOT EXIST -- 3.3.5 hunters use mana, so doubled focus becomes cheaper shots
--
--   1062  Time Lord's Regalia
--         105790:0    +5% damage    on Arcane Blast          
--                     Stolen Time stacking is script-only and Arcane Power carries no class mask
--
--   1066  Vestments of Dying Light
--         105832:0    +10% damage    on Power Word: Shield    
--                     the chance-to-absorb-more roll is script-only; a flat stronger shield replaces it
--         105832:1    zeroed -- Rapture interaction dropped
--
--   1067  Regalia of Dying Light
--         105843:1    zeroed -- self-damage-reduction half dropped; 2pc effect 1 is data and kept
--         105844:0    +5% damage    on Shadow Word: Death    
--                     SHADOW ORBS DO NOT EXIST; Shadow Word: Death is what the orbs empowered
--         105844:1    zeroed -- orb granting dropped
--
--   1070  Spiritwalker's Regalia
--         105816:0    +5% crit      on Lightning Bolt        
--                     Elemental Overload is the Cataclysm mastery; Lightning Bolt is what it procced from
--
--   1071  Spiritwalker's Battlegear
--         105866:0    +5% damage    on Lightning Bolt        
--                     the Maelstrom-stack condition cannot be expressed; RESCALED 20% -> 5% because it is now unconditional
--         105872:0    +5% damage    on Chain Lightning       
--                     Feral Spirit proc granting is script-only; kept on the other Maelstrom spender
--
--   1072  Vestments of the Faceless Shroud
--         105888:0    +5% damage    on Haunt                 
--                     Doomguard and Infernal carry no class mask, so their duration cannot be modified
--         105888:1    zeroed -- second duration half dropped
--
--   1074  Colossal Dragonplate Armor
--         105908:0    +20% damage    on Revenge               
--                     the absorb shield needs a spell that does not exist; kept as Revenge damage
--         105911:0    +20% duration  on Shield Wall           
--                     raid-wide Shield Wall needs a spell that does not exist; RESCALED 50% -> 20% duration
-- -------------------------------------------------------------------------

-- -------------------------------------------------------------------------
-- 1. Spells (49)
-- -------------------------------------------------------------------------

DELETE FROM `spell_dbc` WHERE `ID` IN (
  89910, 89911, 90160, 90163, 90298, 90299, 90457, 90459, 99019, 99035,
  99049, 99154, 99157, 99189, 99190, 99195, 99202, 99204, 99206, 100956,
  105609, 105646, 105713, 105715, 105725, 105732, 105735, 105770, 105779, 105780,
  105785, 105786, 105787, 105788, 105790, 105816, 105826, 105827, 105832, 105843,
  105844, 105866, 105872, 105888, 105908, 105911, 105919, 105921, 108687);

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
     `ProcTypeMask`,
     `ProcChance`,
     `ProcCharges`,
     `CumulativeAura`,
     `SpellVisualID_1`,
     `SpellVisualID_2`,
     `SpellIconID`,
     `ActiveIconID`,
     `SchoolMask`,
     `EquippedItemClass`,
     `SpellClassSet`,
     `SpellClassMask_1`,
     `SpellClassMask_2`,
     `SpellClassMask_3`,
     `Name_Lang_enUS`,
     `Description_Lang_enUS`,
     `Effect_1`,
     `EffectAura_1`,
     `EffectBasePoints_1`,
     `EffectDieSides_1`,
     `EffectAuraPeriod_1`,
     `EffectMiscValue_1`,
     `EffectMiscValueB_1`,
     `EffectRadiusIndex_1`,
     `EffectTriggerSpell_1`,
     `ImplicitTargetA_1`,
     `ImplicitTargetB_1`,
     `EffectMechanic_1`,
     `EffectChainTargets_1`,
     `EffectItemType_1`,
     `EffectSpellClassMaskA_1`,
     `EffectSpellClassMaskB_1`,
     `EffectSpellClassMaskC_1`,
     `Effect_2`,
     `EffectAura_2`,
     `EffectBasePoints_2`,
     `EffectDieSides_2`,
     `EffectAuraPeriod_2`,
     `EffectMiscValue_2`,
     `EffectMiscValueB_2`,
     `EffectRadiusIndex_2`,
     `EffectTriggerSpell_2`,
     `ImplicitTargetA_2`,
     `ImplicitTargetB_2`,
     `EffectMechanic_2`,
     `EffectChainTargets_2`,
     `EffectItemType_2`,
     `EffectSpellClassMaskA_2`,
     `EffectSpellClassMaskB_2`,
     `EffectSpellClassMaskC_2`,
     `Effect_3`,
     `EffectAura_3`,
     `EffectBasePoints_3`,
     `EffectDieSides_3`,
     `EffectAuraPeriod_3`,
     `EffectMiscValue_3`,
     `EffectMiscValueB_3`,
     `EffectRadiusIndex_3`,
     `EffectTriggerSpell_3`,
     `ImplicitTargetA_3`,
     `ImplicitTargetB_3`,
     `EffectMechanic_3`,
     `EffectChainTargets_3`,
     `EffectItemType_3`,
     `EffectSpellClassMaskA_3`,
     `EffectSpellClassMaskB_3`,
     `EffectSpellClassMaskC_3`)
VALUES
  (89910, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 6, 0, 0, 0, 'Item - Priest T11 Healer 2P Bonus', 'Increases the critical strike chance of your Heal spell by $s1%.', 6, 107, 4, 1, 0, 7, 0, 0, 0, 1, 0, 0, 0, 0, 1024, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (89911, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 6, 0, 0, 0, 'Item - Priest T11 Healer 4P Bonus', 'When your Penance spell heals a target you gain $89913s1 Spirit for $89913d, and being in a Chakra state grants you $89912s1 Spirit for the duration of the Chakra.', 6, 108, 4, 1, 0, 7, 0, 0, 0, 1, 0, 0, 0, 0, 0, 8421376, 128, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90160, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Druid T11 Balance 2P Bonus', 'Increases the critical strike chance of your Insect Swarm and Moonfire spells by $s1%.', 6, 107, 4, 1, 0, 7, 0, 0, 0, 1, 0, 0, 0, 0, 2097154, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90163, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Druid T11 Balance 4P Bonus', 'Whenever Eclipse triggers, your critical strike chance with spells is increased by ${$90164m1*3}% for $90164d.  Each critical strike you achieve reduces that bonus by $90164s1%.', 6, 108, 4, 1, 0, 7, 0, 0, 0, 1, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90298, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 10, 0, 0, 0, 'Item - Paladin T11 Retribution 2P Bonus', 'Increases the damage done by your Templar''s Verdict ability by $s1%.', 6, 108, 9, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90299, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 10, 0, 0, 0, 'Item - Paladin T11 Retribution 4P Bonus', 'Your Inquisition ability''s duration is calculated as if you had one additional Holy Power.', 6, 108, 9, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 8192, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90457, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 15, 0, 0, 0, 'Item - Death Knight T11 DPS 2P Bonus', 'Increases the critical strike chance of your Death Coil and Frost Strike abilities by $s1%.', 6, 107, 4, 1, 0, 7, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (90459, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 15, 0, 0, 0, 'Item - Death Knight T11 DPS 4P Bonus', 'Each time you gain a Death Rune or trigger your Killing Machine talent, you also gain $90507s1% increased attack power for $90507d.  Stacks up to $90507u times.', 6, 108, 4, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 131072, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99019, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 65536, 20, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Druid T12 Balance 2P Bonus', 'You have a chance to summon a Burning Treant to assist you in battle for $99035d when you cast Wrath or Starfire.', 6, 42, 2, 1, 0, 0, 0, 0, 99035, 1, 0, 0, 0, 0, 8388608, 0, 2097152, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99035, 0, 0, 0, 0, 65536, 0, 0, 0, 1, 8, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 2258, 0, 1, -1, 0, 0, 0, 0, 'Burning Treant', 'Summons a Burning Treant to assist you in battle.', 28, 0, 0, 1, 0, 53432, 2909, 15, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99049, 64, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 0, 0, 0, 0, 'Item - Druid T12 Balance 4P Bonus', 'While not in an Eclipse state, your Wrath generates 3 additional Lunar Energy and your Starfire generates 5 additional Solar Energy.', 6, 108, 2, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99154, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 6, 0, 0, 0, 'Item - Priest T12 Shadow 2P Bonus', 'While you are in Shadowform, your Shadowfiend deals $99155s1% additional damage as Fire damage and its cooldown is reduced by ${$m1/-1000} sec.', 6, 107, -75001, 1, 0, 11, 0, 0, 0, 1, 0, 0, 0, 0, 0, 256, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99157, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 65536, 100, 0, 0, 0, 0, 1, 0, 1, -1, 6, 0, 0, 0, 'Item - Priest T12 Shadow 4P Bonus', 'While you have Shadow Word: Pain, Devouring Plague, and Vampiric Touch active on the same target you gain Dark Flames, which increases the damage done by Mind Blast by $99158s1%.', 6, 108, 9, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99189, 0, 0, 0, 262144, 32768, 0, 0, 0, 1, 0, 0, 6, 0.0, 0, 101, 0, 0, 0, 0, 2130, 0, 1, -1, 0, 0, 0, 0, 'Flametide', 'Grants you $s1% of your base mana.', 30, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99190, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 262144, 40, 0, 0, 0, 0, 1, 0, 1, -1, 11, 0, 0, 0, 'Item - Shaman T12 Restoration 2P Bonus', 'Your periodic healing from Riptide has a $h% chance to restore $99189s1% of your base mana each time it heals a target.', 6, 42, 0, 1, 0, 8, 0, 0, 99189, 1, 0, 0, 0, 0, 4096, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99195, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 11, 0, 0, 0, 'Item - Shaman T12 Restoration 4P Bonus', 'Your Chain Heal spell no longer consumes your Riptide effect on the primary target.', 6, 108, 4, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 256, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99202, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 969, 0, 678, 0, 1, -1, 11, 0, 0, 0, 'Taming the Flames', 'Resets the cooldown on your Fire Elemental Totem.', 6, 108, -11, 1, 0, 11, 0, 0, 0, 1, 0, 0, 0, 0, 0, 8388608, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99204, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 327680, 30, 0, 0, 0, 0, 1, 0, 1, -1, 11, 0, 0, 0, 'Item - Shaman T12 Elemental 2P Bonus', 'Your Lightning Bolt has a $h% chance to reduce the remaining cooldown on your Fire Elemental Totem by $s1 sec.', 6, 42, 3, 1, 0, 0, 0, 0, 99202, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (99206, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Shaman T12 Elemental 4P Bonus', 'Your Lava Surge talent also makes Lava Burst instant when it triggers.', 6, 42, 2, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 8388608, 0, 2097152, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (100956, 464, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 19, 0, 1, -1, 11, 0, 0, 0, 'Improved Lightning Shield', 'When your Lightning Shield is triggered by receiving damage, a charge will be generated rather than consumed, up to a maximum of $?s88756[9]?s88764[9][3].', 6, 108, 9, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1024, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105609, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 15, 0, 0, 0, 'Item - Death Knight T13 DPS 2P Bonus', 'Sudden Doom has a $s1% chance and Rime has a $s2% chance to grant 2 charges when triggered instead of 1.', 6, 108, 5, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 8192, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105646, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 15, 0, 0, 0, 'Item - Death Knight T13 DPS 4P Bonus', 'Runic Empowerment has a $s1% chance and Runic Corruption has a $s2% chance to also grant $105647s1 mastery rating for $105647d when activated.', 6, 108, 4, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105713, 262144, 1024, 0, 0, 0, 0, 0, 0, 1, 8, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 2152, 0, 8, -1, 7, 0, 0, 0, 'Natural Harmony', 'Reduces the mana cost of all healing spells by $s1% for $d.', 6, 108, -26, 1, 0, 14, 1, 0, 0, 1, 0, 0, 0, 0, 240, 102760466, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105715, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 17408, 100, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Druid T13 Restoration 2P Bonus (Innervate)', 'After using Innervate, the mana cost of your healing spells is reduced by $105713s1% for $105713d.', 6, 42, 34, 1, 0, 0, 0, 0, 105713, 1, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105725, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Druid T13 Feral 2P Bonus (Savage Defense and Blood In The Water)', 'While you have Pulverize active, your Mangle (Bear) critical strikes have a $s1% chance to trigger Savage Defense, and your Blood in the Water talent now causes Ferocious Bite to refresh the duration of your Rip on targets with $s2% or less health.', 6, 108, 9, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105732, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 9, 0, 0, 0, 'Item - Hunter T13 2P Bonus (Steady Shot and Cobra Shot)', 'Steady Shot and Cobra Shot generate double the amount of focus.', 6, 108, -36, 1, 0, 14, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105735, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 87376, 100, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Druid T13 Feral 4P Bonus (Frenzied Regeneration and Stampede)', 'Frenzied Regeneration also affects all raid and party members.  This effect cannot be triggered if you have been in Bear Form for less than $s2 sec.  In addition, using Tiger''s Fury will also trigger your Stampede talent as if you used Feral Charge (Cat).', 6, 108, 14, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1073741824, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105770, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Druid T13 Restoration 4P Bonus (Rejuvenation)', 'Your Rejuvenation and Regrowth spells have a $s1% chance to Timeslip and have double the normal duration.', 6, 108, 9, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105779, 16, 0, 0, 0, 0, 0, 0, 0, 1, 8, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 5670, 0, 8, -1, 11, 0, 0, 0, 'Fury of the Ancestors', 'Increases your mastery rating by $s1 for $d.', 6, 189, 1999, 1, 0, 33554432, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105780, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 52224, 100, 0, 0, 0, 0, 1, 0, 1, -1, 11, 0, 0, 0, 'Item - Shaman T13 Elemental 2P Bonus (Elemental Mastery)', 'Elemental Mastery also grants you $105779s1 mastery rating $105779d.', 6, 42, -1, 1, 0, 0, 0, 0, 105779, 1, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105785, 0, 0, 0, 0, 0, 0, 0, 0, 1, 9, 0, 1, 0.0, 0, 101, 0, 10, 0, 0, 2899, 0, 1, -1, 0, 0, 0, 0, 'Stolen Time', 'Haste rating increased by $s1 for $d.  Stacks up to $u times.', 6, 189, 49, 1, 0, 917504, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105786, 0, 1024, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 2729, 0, 32, -1, 5, 0, 0, 0, 'Temporal Ruin', 'Soulburn increases your spell power by $s1% for $d.', 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105787, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 16384, 101, 0, 0, 0, 0, 1, 0, 1, -1, 5, 0, 0, 0, 'Item - Warlock T13 4P Bonus (Soulburn)', 'Soulburn grants a $105786s1% increase to your spell power for $105786d, and Soul Fire cast with Soulburn active now grants a Soul Shard.', 6, 42, -1, 1, 0, 0, 0, 0, 105786, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105788, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 65536, 100, 0, 0, 0, 0, 1, 0, 1, -1, 3, 0, 0, 0, 'Item - Mage T13 2P Bonus (Haste Rating)', 'Your Arcane Blast has a $h% chance and your Fireball, Pyroblast, Frostfire Bolt, and Frostbolt spells have a $s1% chance to grant Stolen Time, increasing your haste rating by $105785s1 for $105785d and stacking up to $105785u times.  When Arcane Power, Combustion, or Icy Veins expires, all stacks of Stolen Time are lost.', 6, 42, 49, 1, 0, 0, 0, 0, 105785, 1, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105790, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 7, 0, 0, 0, 'Item - Mage T13 4P Bonus (Arcane Power, Combustion, and Icy Veins)', 'Each stack of Stolen Time also reduces the cooldown of Arcane Power by ${$105791m1/-1000} sec, Combustion by ${$105791m2/-1000} sec, and Icy Veins by ${$105791m3/-1000} sec.', 6, 108, 4, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 536870912, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105816, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 11, 0, 0, 0, 'Item - Shaman T13 Elemental 4P Bonus (Elemental Overload)', 'Each time Elemental Overload triggers, you gain $105821s1 haste rating for $105821d, stacking up to $105821u times.', 6, 108, 4, 1, 0, 7, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105826, 262144, 1024, 0, 0, 0, 0, 0, 0, 1, 618, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 2152, 0, 8, -1, 6, 0, 0, 0, 'Temporal Boon', 'Reduces the mana cost of all healing spells by $s1%.', 6, 108, -26, 1, 0, 14, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105827, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 87312, 100, 0, 0, 0, 0, 1, 0, 1, -1, 6, 0, 0, 0, 'Item - Priest T13 Healer 2P Bonus (Power Infusion and Lightwell)', 'After using Power Infusion or Divine Hymn, the mana cost of your healing spells is reduced by $105826s1% for $?s10060[10 sec][$105826d].', 6, 42, 34, 1, 0, 0, 0, 0, 105826, 1, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105832, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 6, 0, 0, 0, 'Item - Priest T13 Healer 4P Bonus (Holy Word and Power Word: Shield)', 'Your Power Word: Shield has a $s1% chance to absorb $s2% additional damage and increase the mana granted by Rapture by $s2%, and the duration of your Holy Word abilities is increased by $s3%.', 6, 108, 9, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 6, 108, 32, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
  (105843, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 6, 0, 0, 0, 'Item - Priest T13 Shadow 2P Bonus (Shadow Word: Death)', 'Shadow Word: Death deals an additional $s1% damage, and reduces the damage you take from your own Shadow Word: Death when the target fails to die by $s2%.', 6, 108, 54, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105844, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 6, 0, 0, 0, 'Item - Priest T13 Shadow 4P Bonus (Shadowfiend and Shadowy Apparition)', 'Your Shadowfiend and Shadowy Apparitions have a $s1% chance to grant you $m2 $lShadow Orb:Shadow Orbs; each time they deal damage.', 6, 108, 4, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 8194, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105866, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 8, 0, 0, 0, 'Item - Shaman T13 Enhancement 2P Bonus (Maelstrom Weapon)', 'While you have any stacks of Maelstrom Weapon, your Lightning Bolt, Chain Lightning, and healing spells deal $105869s1% more healing or damage.', 6, 108, 4, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105872, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 8, 0, 0, 0, 'Item - Shaman T13 Enhancement 4P Bonus (Feral Spirits)', 'Your Feral Spirits have a $105873h% chance to grant you a charge of Maelstrom Weapon each time they deal damage.', 6, 108, 4, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105888, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 5, 0, 0, 0, 'Item - Warlock T13 2P Bonus (Doomguard and Infernal)', 'The duration of your Doomguard and Infernal summons is increased by $?s30146[$m1 sec][$m2 sec] and the cooldown of those spells is reduced by ${$m3/-60000} min.', 6, 108, 4, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 262144, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 6, 107, -240001, 1, 0, 11, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
  (105908, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 16, 100, 0, 0, 0, 0, 1, 0, 1, -1, 4, 0, 0, 0, 'Item - Warrior T13 Protection 2P Bonus (Revenge)', 'Your Revenge ability now also grants a physical absorption shield equal to $s1% of the damage done by Revenge to its primary target.', 6, 108, 19, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1024, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105911, 192, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 101, 0, 0, 0, 0, 1, 0, 1, -1, 4, 0, 0, 0, 'Item - Warrior T13 Protection 4P Bonus (Shield Wall)', 'Your Shield Wall ability now grants $s1% of its effect to all party and raid members.', 6, 108, 19, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 8192, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105919, 262160, 0, 0, 0, 0, 0, 0, 0, 1, 8, 0, 6, 0.0, 0, 101, 0, 0, 13245, 0, 2238, 0, 1, -1, 0, 0, 0, 33554432, 'Chronohunter', 'Increases your haste and your pet''s haste by $s1% for $d.', 6, 193, 29, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 64, 0, 24, 1, 0, 0, 0, 0, 108687, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (105921, 192, 0, 0, 67108864, 0, 0, 0, 0, 1, 0, 0, 1, 0.0, 256, 40, 0, 0, 0, 0, 1, 0, 1, -1, 9, 0, 0, 0, 'Item - Hunter T13 4P Bonus (Arcane Shot)', 'Your Arcane Shot ability has a chance to grant $105919s1% haste to you and your pet for $105919d.', 6, 42, 2, 1, 0, 0, 0, 0, 105919, 1, 0, 0, 0, 0, 8388608, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (108687, 262160, 0, 0, 0, 8192, 0, 0, 0, 1, 8, 0, 6, 0.0, 0, 101, 0, 0, 13245, 0, 2238, 0, 1, -1, 0, 0, 0, 33554432, 'Chronohunter', 'Increases your haste and your pet''s haste by $s1% for $d.', 6, 193, 29, 1, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

-- -------------------------------------------------------------------------
-- 2. The 22 sets
-- -------------------------------------------------------------------------

DELETE FROM `itemset_dbc` WHERE `ID` IN (
  911, 916, 921, 925, 929, 932, 935, 1003, 1010, 1014, 1016, 1057,
  1058, 1060, 1061, 1062, 1066, 1067, 1070, 1071, 1072, 1074);

INSERT INTO `itemset_dbc`
    (`ID`, `Name_Lang_enUS`, `Name_Lang_enGB`, `Name_Lang_koKR`, `Name_Lang_frFR`, `Name_Lang_deDE`, `Name_Lang_enCN`, `Name_Lang_zhCN`, `Name_Lang_enTW`, `Name_Lang_zhTW`, `Name_Lang_esES`, `Name_Lang_esMX`, `Name_Lang_ruRU`, `Name_Lang_ptPT`, `Name_Lang_ptBR`, `Name_Lang_itIT`, `Name_Lang_Unk`, `Name_Lang_Mask`, `ItemID_1`, `ItemID_2`, `ItemID_3`, `ItemID_4`, `ItemID_5`, `ItemID_6`, `ItemID_7`, `ItemID_8`, `ItemID_9`, `ItemID_10`, `ItemID_11`, `ItemID_12`, `ItemID_13`, `ItemID_14`, `ItemID_15`, `ItemID_16`, `ItemID_17`, `SetSpellID_1`, `SetSpellID_2`, `SetSpellID_3`, `SetSpellID_4`, `SetSpellID_5`, `SetSpellID_6`, `SetSpellID_7`, `SetSpellID_8`, `SetThreshold_1`, `SetThreshold_2`, `SetThreshold_3`, `SetThreshold_4`, `SetThreshold_5`, `SetThreshold_6`, `SetThreshold_7`, `SetThreshold_8`, `RequiredSkill`, `RequiredSkillRank`)
VALUES
  (911, 'Gladiator''s Thunderfist', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 65156, 65155, 65154, 65153, 65152, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 92261, 100956, 92260, 0, 0, 0, 0, 2, 2, 4, 4, 0, 0, 0, 0, 0, 0),
  (916, 'Gladiator''s Investiture', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 64957, 64956, 64955, 64954, 64953, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 92256, 33333, 92255, 0, 0, 0, 0, 2, 2, 4, 4, 0, 0, 0, 0, 0, 0),
  (921, 'Gladiator''s Wildhide', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 64927, 64926, 64925, 64924, 64923, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92254, 92261, 46832, 92260, 0, 0, 0, 0, 2, 2, 4, 4, 0, 0, 0, 0, 0, 0),
  (925, 'Magma Plated Battlegear', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 60339, 60340, 60341, 60342, 60343, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 90457, 90459, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (929, 'Stormrider''s Regalia', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 60284, 60281, 60283, 60282, 60285, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 90160, 90163, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (932, 'Reinforced Sapphirium Battleplate', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 60348, 60347, 60346, 60345, 60344, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 90298, 90299, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (935, 'Mercurial Vestments', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 60262, 60259, 60261, 60258, 60275, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 89910, 89911, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1003, 'Obsidian Arborweave Regalia', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 71107, 71108, 71109, 71110, 71111, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 99019, 99049, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1010, 'Regalia of the Cleansing Flame', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 71280, 71279, 71278, 71277, 71276, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 99154, 99157, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1014, 'Volcanic Vestments', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 71300, 71299, 71298, 71297, 71296, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 99190, 99195, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1016, 'Volcanic Regalia', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 71295, 71294, 71293, 71292, 71291, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 99204, 99206, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1057, 'Necrotic Boneplate Battlegear', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 76974, 76975, 76976, 76977, 76978, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 105609, 105646, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1058, 'Deep Earth Battlegarb', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 77013, 77014, 77015, 77016, 77017, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 105725, 105735, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1060, 'Deep Earth Vestments', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 76749, 76750, 76751, 76752, 76753, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 105715, 105770, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1061, 'Wyrmstalker Battlegear', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 77028, 77029, 77030, 77031, 77032, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 105732, 105921, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1062, 'Time Lord''s Regalia', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 76212, 76213, 76214, 76215, 76216, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 105788, 105790, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1066, 'Vestments of Dying Light', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 76357, 76358, 76359, 76360, 76361, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 105827, 105832, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1067, 'Regalia of Dying Light', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 76348, 76347, 76346, 76345, 76344, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 105843, 105844, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1070, 'Spiritwalker''s Regalia', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 77039, 77038, 77037, 77036, 77035, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 105780, 105816, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1071, 'Spiritwalker''s Battlegear', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 77040, 77041, 77042, 77043, 77044, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 105866, 105872, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1072, 'Vestments of the Faceless Shroud', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 76343, 76342, 76341, 76340, 76339, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 105888, 105787, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0),
  (1074, 'Colossal Dragonplate Armor', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 76988, 76989, 76990, 76991, 76992, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 105908, 105911, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0);

-- -------------------------------------------------------------------------
-- 3. Wire the item shells
-- -------------------------------------------------------------------------

-- Gladiator's Thunderfist
UPDATE `item_template` SET `itemset` = 911 WHERE `entry` IN (65152, 65153, 65154, 65155, 65156);
-- Gladiator's Investiture
UPDATE `item_template` SET `itemset` = 916 WHERE `entry` IN (64953, 64954, 64955, 64956, 64957);
-- Gladiator's Wildhide
UPDATE `item_template` SET `itemset` = 921 WHERE `entry` IN (64923, 64924, 64925, 64926, 64927);
-- Magma Plated Battlegear
UPDATE `item_template` SET `itemset` = 925 WHERE `entry` IN (60339, 60340, 60341, 60342, 60343);
-- Stormrider's Regalia
UPDATE `item_template` SET `itemset` = 929 WHERE `entry` IN (60281, 60282, 60283, 60284, 60285);
-- Reinforced Sapphirium Battleplate
UPDATE `item_template` SET `itemset` = 932 WHERE `entry` IN (60344, 60345, 60346, 60347, 60348);
-- Mercurial Vestments
UPDATE `item_template` SET `itemset` = 935 WHERE `entry` IN (60258, 60259, 60261, 60262, 60275);
-- Obsidian Arborweave Regalia
UPDATE `item_template` SET `itemset` = 1003 WHERE `entry` IN (71107, 71108, 71109, 71110, 71111);
-- Regalia of the Cleansing Flame
UPDATE `item_template` SET `itemset` = 1010 WHERE `entry` IN (71276, 71277, 71278, 71279, 71280);
-- Volcanic Vestments
UPDATE `item_template` SET `itemset` = 1014 WHERE `entry` IN (71296, 71297, 71298, 71299, 71300);
-- Volcanic Regalia
UPDATE `item_template` SET `itemset` = 1016 WHERE `entry` IN (71291, 71292, 71293, 71294, 71295);
-- Necrotic Boneplate Battlegear
UPDATE `item_template` SET `itemset` = 1057 WHERE `entry` IN (76974, 76975, 76976, 76977, 76978);
-- Deep Earth Battlegarb
UPDATE `item_template` SET `itemset` = 1058 WHERE `entry` IN (77013, 77014, 77015, 77016, 77017);
-- Deep Earth Vestments
UPDATE `item_template` SET `itemset` = 1060 WHERE `entry` IN (76749, 76750, 76751, 76752, 76753);
-- Wyrmstalker Battlegear
UPDATE `item_template` SET `itemset` = 1061 WHERE `entry` IN (77028, 77029, 77030, 77031, 77032);
-- Time Lord's Regalia
UPDATE `item_template` SET `itemset` = 1062 WHERE `entry` IN (76212, 76213, 76214, 76215, 76216);
-- Vestments of Dying Light
UPDATE `item_template` SET `itemset` = 1066 WHERE `entry` IN (76357, 76358, 76359, 76360, 76361);
-- Regalia of Dying Light
UPDATE `item_template` SET `itemset` = 1067 WHERE `entry` IN (76344, 76345, 76346, 76347, 76348);
-- Spiritwalker's Regalia
UPDATE `item_template` SET `itemset` = 1070 WHERE `entry` IN (77035, 77036, 77037, 77038, 77039);
-- Spiritwalker's Battlegear
UPDATE `item_template` SET `itemset` = 1071 WHERE `entry` IN (77040, 77041, 77042, 77043, 77044);
-- Vestments of the Faceless Shroud
UPDATE `item_template` SET `itemset` = 1072 WHERE `entry` IN (76339, 76340, 76341, 76342, 76343);
-- Colossal Dragonplate Armor
UPDATE `item_template` SET `itemset` = 1074 WHERE `entry` IN (76988, 76989, 76990, 76991, 76992);

-- -------------------------------------------------------------------------
-- Verification
-- -------------------------------------------------------------------------
--   SELECT COUNT(*) FROM itemset_dbc;   -- 90, the whole Cataclysm catalogue
--
--   -- nothing out of range (a bad aura ASSERTS and segfaults at boot):
--   SELECT ID FROM spell_dbc WHERE EffectAura_1 >= 317 OR EffectAura_2 >= 317
--      OR EffectAura_3 >= 317 OR Effect_1 >= 165 OR Effect_2 >= 165 OR Effect_3 >= 165;
--
--   -- no negative damage modifiers (would weaken the wearer):
--   SELECT ID FROM spell_dbc WHERE EffectAura_1 = 108 AND EffectMiscValue_1 = 0
--     AND EffectBasePoints_1 < 0;
-- -------------------------------------------------------------------------
