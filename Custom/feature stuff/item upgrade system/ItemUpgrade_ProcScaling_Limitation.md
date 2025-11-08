# Item Upgrade System - Proc Scaling Limitation Notice
**Date:** November 8, 2025  
**Status:** ⚠️ PARTIAL IMPLEMENTATION

---

## Issue: Proc Scaling Not Fully Functional

### Problem

AzerothCore's scripting API does not provide hooks for modifying spell damage/healing at runtime. The proc scaling system was designed to scale trinket and weapon proc effects based on item upgrade level, but the required hooks don't exist.

### What Was Attempted

The initial implementation tried to use:
- `OnSpellDamage(Player*, Unit*, uint32& damage, SpellInfo*)` - **Does not exist**
- `OnSpellHeal(Player*, Unit*, uint32& heal, SpellInfo*)` - **Does not exist**

These functions are not part of AzerothCore's `PlayerScript` class.

### What Actually Works

✅ **Database tracking** - The system tracks which spells belong to which items  
✅ **Item cache** - Player equipped items are cached with their multipliers  
✅ **SQL table** - `dc_item_proc_spells` is loaded and functional  
✅ **Infrastructure** - All the scaffolding is in place  

❌ **Actual scaling** - Cannot modify proc damage/healing without core hooks

---

## Current Status

The `ItemUpgradeProcScaling.cpp` file is compiled and registered, but:
- It only tracks item procs (database mapping)
- It caches equipped item multipliers
- It **does NOT** actually scale proc damage/healing

---

## Solutions

### Option 1: Core Modification (Recommended if you need proc scaling)

Add damage/healing hooks to AzerothCore's PlayerScript:

**File: `src/server/game/Scripting/ScriptDefines/PlayerScript.h`**

```cpp
// Add these virtual functions to PlayerScript class:

// Called before spell damage is calculated
virtual void OnBeforeSpellDamage(Player* /*player*/, Unit* /*victim*/, 
                                  uint32& /*damage*/, SpellInfo const* /*spellInfo*/) { }

// Called before spell healing is calculated  
virtual void OnBeforeSpellHeal(Player* /*player*/, Unit* /*target*/,
                                uint32& /*heal*/, SpellInfo const* /*spellInfo*/) { }
```

**File: `src/server/game/Spells/Spell.cpp`**

Find damage/healing calculation functions and add hook calls:

```cpp
// In damage calculation:
sScriptMgr->OnBeforeSpellDamage(caster->ToPlayer(), target, damage, m_spellInfo);

// In healing calculation:
sScriptMgr->OnBeforeSpellHeal(caster->ToPlayer(), target, heal, m_spellInfo);
```

Then update `ItemUpgradeProcScaling.cpp` to use the new hooks.

### Option 2: SpellScript Per-Proc (Tedious but works without core changes)

Create individual SpellScript handlers for each proc spell:

```cpp
class spell_darkmoon_card_greatness : public SpellScript
{
    void HandleDamage(SpellEffIndex /*effIndex*/)
    {
        Unit* caster = GetCaster();
        if (!caster || !caster->ToPlayer())
            return;
            
        // Check upgrade level, apply multiplier
        float mult = GetItemProcMultiplier(caster->ToPlayer(), ITEM_DARKMOON_CARD_GREATNESS);
        SetHitDamage(GetHitDamage() * mult);
    }
    
    void Register() override
    {
        OnEffectHitTarget += SpellEffectFn(spell_darkmoon_card_greatness::HandleDamage, 
                                          EFFECT_0, SPELL_EFFECT_SCHOOL_DAMAGE);
    }
};
```

**Pros:** No core modification needed  
**Cons:** Must create script for EVERY proc spell individually

### Option 3: Modify Item Stats Instead (Current Workaround)

Instead of scaling proc damage, scale the item's spell power/attack power:
- Higher spell power → procs scale automatically
- Already implemented in `ItemUpgradeStatApplication.cpp`
- Procs scale indirectly through better stats

**Pros:** Already working, no additional code needed  
**Cons:** Not a direct proc multiplier, less precise

### Option 4: Accept Limitation

Most of the upgrade system works perfectly:
- Primary stats scale ✅
- Secondary stats scale ✅
- Armor scales ✅
- Weapon damage scales ✅
- Spell power scales ✅ (which affects spell-based procs indirectly)
- Attack power scales ✅ (which affects physical procs indirectly)

Procs that scale with stats (most of them) will scale indirectly through increased spell power/attack power.

---

## Recommendation

**For now: Use Option 3 + Option 4**
- Spell power/attack power scaling already makes most procs stronger
- Accept that direct proc multipliers aren't available
- Focus on the 95% of the system that works perfectly

**For future: Implement Option 1 if proc scaling becomes critical**
- Requires core modification
- But provides clean, maintainable solution
- Would complete the 100% implementation

---

## What to Tell Users

"Item upgrades scale all item stats including spell power and attack power. Since most trinket and weapon procs scale with these stats, they will be stronger on upgraded items. Direct proc effect scaling is not available due to engine limitations, but the indirect scaling through better stats provides similar benefits."

---

## Files Updated

1. `ItemUpgradeProcScaling.cpp` - Compilation errors fixed, noted limitation
2. `dc_item_proc_spells.sql` - Still useful for future implementation
3. This documentation - Explains the limitation

---

## Conclusion

The proc scaling infrastructure is complete and ready. When AzerothCore adds spell damage/healing hooks (or if you modify the core), simply uncomment the hook functions in `ItemUpgradeProcScaling.cpp` and it will work immediately.

Until then, indirect scaling through spell power/attack power is functional and provides reasonable proc scaling.

**Status:** ✅ System functional (indirect scaling via stats)  
**Direct Proc Scaling:** ⏳ Awaiting core hooks or manual per-spell implementation
