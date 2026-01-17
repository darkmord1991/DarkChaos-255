import csv

f = open('CSV DBC/Spell.csv', 'r', encoding='utf-8')
rows = list(csv.reader(f))
f.close()
h = rows[0]

# Find important column indices
cols = {
    'ID': h.index('ID'),
    'Attr': h.index('Attributes'),
    'AttrEx': h.index('AttributesEx'),
    'AttrExB': h.index('AttributesExB'),
    'AttrExC': h.index('AttributesExC'),
    'AttrExD': h.index('AttributesExD'),
    'AttrExE': h.index('AttributesExE'),
    'Effect1': h.index('Effect_1'),
    'Effect2': h.index('Effect_2'),
    'Effect3': h.index('Effect_3'),
    'Aura1': h.index('EffectAura_1'),
    'Aura2': h.index('EffectAura_2'),
    'Aura3': h.index('EffectAura_3'),
    'TgtA1': h.index('ImplicitTargetA_1'),
    'TgtB1': h.index('ImplicitTargetB_1'),
    'DurIdx': h.index('DurationIndex'),
    'Icon': h.index('SpellIconID'),
    'ActiveIcon': h.index('ActiveIconID'),
    'DispelType': h.index('DispelType'),
    'BasePoints1': h.index('EffectBasePoints_1'),
    'CumAura': h.index('CumulativeAura'),
    'MiscVal1': h.index('EffectMiscValue_1'),
    'AuraDesc': h.index('AuraDescription_Lang_enUS'),
    'AuraInterrupt': h.index('AuraInterruptFlags'),
}

# Spells to check
spell_ids = [800001, 800002, 800003, 800004, 800005, 800010, 800011, 800012, 800013, 800014, 800015]

# Also compare with a known working buff like Mark of the Wild (1126) or Arcane Intellect (1459)
reference_spells = [1126, 1459, 23028]  # MotW, AI, Arcane Brilliance

print("=== REFERENCE SPELLS (known working buffs) ===")
for r in rows[1:]:
    try:
        spell_id = int(r[cols['ID']])
        if spell_id in reference_spells:
            attr = int(r[cols['Attr']])
            attrEx = int(r[cols['AttrEx']])
            print(f"\nSpell {spell_id}:")
            print(f"  Attributes: {attr} (0x{attr:08X})")
            print(f"  AttributesEx: {attrEx} (0x{attrEx:08X})")
            print(f"  AttributesExB: {r[cols['AttrExB']]}")
            print(f"  Effect_1: {r[cols['Effect1']]}, EffectAura_1: {r[cols['Aura1']]}")
            print(f"  ImplicitTargetA_1: {r[cols['TgtA1']]}, ImplicitTargetB_1: {r[cols['TgtB1']]}")
            print(f"  DurationIndex: {r[cols['DurIdx']]}")
            print(f"  SpellIconID: {r[cols['Icon']]}, ActiveIconID: {r[cols['ActiveIcon']]}")
            print(f"  DispelType: {r[cols['DispelType']]}")
            print(f"  EffectMiscValue_1: {r[cols['MiscVal1']]}")
            print(f"  CumulativeAura: {r[cols['CumAura']]}")
    except:
        pass

print("\n\n=== CUSTOM SPELLS (800xxx) ===")
for r in rows[1:]:
    try:
        spell_id = int(r[cols['ID']])
        if spell_id in spell_ids or (800000 <= spell_id <= 800100):
            attr = int(r[cols['Attr']])
            attrEx = int(r[cols['AttrEx']])
            print(f"\nSpell {spell_id}:")
            print(f"  Attributes: {attr} (0x{attr:08X})")
            print(f"  AttributesEx: {attrEx} (0x{attrEx:08X})")
            print(f"  AttributesExB: {r[cols['AttrExB']]}")
            print(f"  AttributesExC: {r[cols['AttrExC']]}")
            print(f"  Effect_1: {r[cols['Effect1']]}, EffectAura_1: {r[cols['Aura1']]}")
            print(f"  Effect_2: {r[cols['Effect2']]}, EffectAura_2: {r[cols['Aura2']]}")
            print(f"  ImplicitTargetA_1: {r[cols['TgtA1']]}, ImplicitTargetB_1: {r[cols['TgtB1']]}")
            print(f"  DurationIndex: {r[cols['DurIdx']]}")
            print(f"  SpellIconID: {r[cols['Icon']]}, ActiveIconID: {r[cols['ActiveIcon']]}")
            print(f"  DispelType: {r[cols['DispelType']]}")
            print(f"  EffectBasePoints_1: {r[cols['BasePoints1']]}")
            print(f"  EffectMiscValue_1: {r[cols['MiscVal1']]}")
            print(f"  CumulativeAura: {r[cols['CumAura']]}")
            print(f"  AuraInterruptFlags: {r[cols['AuraInterrupt']]}")
            if r[cols['AuraDesc']]:
                print(f"  AuraDescription: {r[cols['AuraDesc']][:50]}...")
    except:
        pass

# Check attribute flags
print("\n\n=== ATTRIBUTE FLAG ANALYSIS ===")
print("Key Attribute flags that affect buff display:")
print("  SPELL_ATTR0_HIDDEN_CLIENTSIDE (0x00000100) = 256 - Hides spell from client")
print("  SPELL_ATTR0_PASSIVE (0x00000040) = 64 - Passive spell (no icon)")
print("  SPELL_ATTR0_DO_NOT_DISPLAY (0x80000000) = 2147483648 - Don't display in buff bar")
print("  SPELL_ATTR1_DONT_DISPLAY_IN_AURA_BAR (0x04000000) = 67108864 - AttrEx flag to hide from aura bar")
print("  SPELL_ATTR5_HIDE_DURATION (0x00002000) = 8192 - Hides duration")
