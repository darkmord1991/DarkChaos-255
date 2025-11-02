# 🔍 Hotspot Folder Analysis - Duplicate Scripts Investigation

## Files in `src/server/scripts/DC/Hotspot/`

### 1. **ac_hotspots.cpp** ✅ KEEP
**Purpose:** Main hotspot system implementation
- ~2600 lines
- Complete hotspot spawning, tracking, and management system
- Configuration loading and command handlers
- Player join/leave detection and buff application
- XP multiplier logic in `OnPlayerGiveXP`
- **This is the core system file - DO NOT REMOVE**

---

### 2. **spell_hotspot_xp_buff.cpp** ⚠️ CONFLICTING
**Purpose:** Incomplete hotspot XP buff spell script (old/unused)
- Only 26 lines
- Extends `SpellScript` (NOT `AuraScript`)
- Has no spell registration function (`AddSC_spell_hotspot_xp_buff()` is broken)
- Just has `new` call instead of proper registration
- **Status: BROKEN - Do not use**

```cpp
void AddSC_spell_hotspot_xp_buff()
{
    new spell_hotspot_xp_buff();  // ❌ WRONG - just creates instance, doesn't register!
}
```

---

### 3. **spell_hotspot_aura_800001.cpp** ✅ CORRECT PATTERN
**Purpose:** Working hotspot XP buff aura script (spell 800001)
- ~75 lines
- Extends `AuraScript` (correct for aura effects)
- Class: `spell_hotspot_xp_buff_aura : public AuraScript`
- Macro: `PrepareAuraScript(spell_hotspot_xp_buff_aura)`
- **Proper Registration:** `RegisterAuraScript(spell_hotspot_xp_buff_aura)` ✅
- Implements OnApply/OnRemove hooks
- Uses `SPELL_AURA_DUMMY` type (4)

```cpp
void AddSC_spell_hotspot_xp_buff_aura()
{
    RegisterAuraScript(spell_hotspot_xp_buff_aura);  // ✅ CORRECT
}
```

---

### 4. **spell_hotspot_buff_800001.cpp** ✅ FUNCTIONAL
**Purpose:** User-provided hotspot buff aura script (spell 800001)
- ~51 lines
- Extends `AuraScript` (correct)
- Class: `spell_hotspot_buff_800001_aura : public AuraScript`
- Macro: `PrepareAuraScript(spell_hotspot_buff_800001_aura)`
- **Registration:** `RegisterSpellScript(spell_hotspot_buff_800001_aura)` 
- Implements OnApply/OnRemove hooks
- **Note:** Uses RegisterSpellScript but class is AuraScript (inconsistent but may work)
- Similar functionality to spell_hotspot_aura_800001.cpp

```cpp
void AddSC_spell_hotspot_buff_800001_aura()
{
    RegisterSpellScript(spell_hotspot_buff_800001_aura);  // ⚠️ Inconsistent
}
```

---

## 📊 Comparison Table

| File | Class Type | Registration | Status | Role |
|------|-----------|--------------|--------|------|
| **ac_hotspots.cpp** | WorldScript, PlayerScript, CommandScript | World/Player/Command scripts | ✅ KEEP | Core system |
| **spell_hotspot_xp_buff.cpp** | SpellScript | Broken (new) | ⚠️ BROKEN | Legacy/unused |
| **spell_hotspot_aura_800001.cpp** | AuraScript | RegisterAuraScript() | ✅ CORRECT | Working aura pattern |
| **spell_hotspot_buff_800001.cpp** | AuraScript | RegisterSpellScript() | ⚠️ FUNCTIONAL | Works but inconsistent |

---

## 🎯 Recommendation

### **Which one to use? USE SPELL_HOTSPOT_AURA_800001.CPP**

**Reasons:**
1. ✅ **Correct registration method** - Uses `RegisterAuraScript()` for AuraScript class
2. ✅ **Matches AzerothCore conventions** - Proper pattern for aura scripts
3. ✅ **Proven to work** - This is why hotspot buff works (spell 800001 displays correctly)
4. ✅ **Consistent code style** - Follows the pattern used by prestige spells (after fix)

---

## 🔧 What to Do

### **Option 1: Delete Redundant Files** (Recommended)
```
DELETE: spell_hotspot_xp_buff.cpp
DELETE: spell_hotspot_buff_800001.cpp (it's a duplicate)
KEEP:   ac_hotspots.cpp (core system)
KEEP:   spell_hotspot_aura_800001.cpp (correct pattern)
```

### **Option 2: Use Both If Needed**
If you want to keep `spell_hotspot_buff_800001.cpp`:
- Change registration from `RegisterSpellScript()` to `RegisterAuraScript()`
- Make it identical to spell_hotspot_aura_800001.cpp for consistency
- OR use one as a backup/variant

### **Option 3: Keep Everything (Not Recommended)**
- ac_hotspots.cpp ✅ (required)
- spell_hotspot_aura_800001.cpp ✅ (primary, correct pattern)
- spell_hotspot_xp_buff.cpp ❌ (delete - it's broken)
- spell_hotspot_buff_800001.cpp ⚠️ (optional - duplicate of #3)

---

## ⚠️ Critical Finding

**spell_hotspot_buff_800001.cpp uses `RegisterSpellScript()` on an AuraScript class:**

```cpp
class spell_hotspot_buff_800001_aura : public AuraScript  // ← AuraScript!
{
    // ...
};

void AddSC_spell_hotspot_buff_800001_aura()
{
    RegisterSpellScript(spell_hotspot_buff_800001_aura);  // ← Wrong function!
}
```

This is the **EXACT BUG** we just fixed in prestige spells!

---

## 📝 Recommendation Summary

### **Keep These:**
- ✅ **ac_hotspots.cpp** - Core hotspot system (2600 lines, required)
- ✅ **spell_hotspot_aura_800001.cpp** - Correct aura script pattern

### **Delete These:**
- ❌ **spell_hotspot_xp_buff.cpp** - Broken registration, completely unused
- ❌ **spell_hotspot_buff_800001.cpp** - Duplicate with wrong registration method

### **Why?**
1. Eliminates duplicate script registration (spell 800001 registered twice = conflicts)
2. Ensures correct AuraScript registration pattern throughout codebase
3. Follows AzerothCore conventions
4. Matches the fix we just applied to prestige spells

---

## 🚀 Next Steps

1. **Delete duplicates:**
   ```bash
   rm spell_hotspot_xp_buff.cpp
   rm spell_hotspot_buff_800001.cpp
   ```

2. **Keep working versions:**
   - Keep ac_hotspots.cpp (core system)
   - Keep spell_hotspot_aura_800001.cpp (correct pattern)

3. **Rebuild server:**
   ```bash
   ./acore.sh compiler build
   ```

4. **Test:**
   - Verify hotspot buffs still work
   - Check prestige auras display correctly
   - Confirm no script loading errors

---

**This analysis ensures you have a clean, consistent hotspot implementation without duplicate or broken scripts!**
