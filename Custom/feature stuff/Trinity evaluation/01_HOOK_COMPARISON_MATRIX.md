# AzerothCore vs TrinityCore 3.3.5 - Hook Comparison Matrix

## Executive Summary
This document provides a detailed comparison of scripting hooks available in AzerothCore vs TrinityCore 3.3.5 branch.

**Finding:** AzerothCore has **significantly more hooks** than TrinityCore 3.3.5, particularly "Before" and "After" hooks that allow intercepting and modifying game actions.

---

## Hook Categories Overview

| Category | AzerothCore Hooks | TrinityCore 3.3.5 Hooks | Gap |
|----------|-------------------|-------------------------|-----|
| PlayerScript | ~100+ | ~35 | **Major** |
| WorldScript | ~15 | ~10 | Minor |
| CreatureScript | ~30+ | ~20 | Moderate |
| AllCreatureScript | ✅ Available | ❌ Not Available | **Critical** |
| AllMapScript | ✅ Available | ❌ Not Available | **Critical** |
| UnitScript | ✅ Available | ❌ Not Available | **Critical** |
| GlobalScript | ✅ Available | ❌ Not Available | **Critical** |
| MiscScript | ✅ Available | ❌ Not Available | **Critical** |
| WorldObjectScript | ✅ Available | ❌ Not Available | **Critical** |

---

## Detailed PlayerScript Comparison

### AzerothCore PlayerScript Hooks (Partial List)

| Hook | Purpose | TrinityCore 3.3.5 Equivalent |
|------|---------|------------------------------|
| `OnLogin(Player*, firstLogin)` | Player login | ✅ `OnLogin` |
| `OnLogout(Player*)` | Player logout | ✅ `OnLogout` |
| `OnPlayerLevelChanged(Player*, oldLevel)` | Level change | ✅ `OnLevelChanged` |
| `OnPlayerMapChanged(Player*)` | Map change | ✅ `OnMapChanged` |
| `OnPlayerKilledByCreature(Creature*, Player*)` | Death by creature | ✅ `OnPlayerKilledByCreature` |
| `OnPlayerPVPKill(Player*, Player*)` | PVP kill | ✅ `OnPVPKill` |
| `OnPlayerCreatureKill(Player*, Creature*)` | Player kills creature | ✅ `OnCreatureKill` |
| `OnPlayerCompleteQuest(Player*, Quest*)` | Quest complete | ⚠️ `OnQuestStatusChange(questId)` only |
| `OnPlayerUpdate(Player*, diff)` | **Player tick update** | ❌ **NOT AVAILABLE** |
| `OnPlayerUpdateZone(Player*, zone, area)` | Zone change | ✅ `OnUpdateZone` |
| `OnPlayerGiveXP(Player*, &amount, victim, source)` | **XP modification** | ✅ `OnGiveXP` |
| `OnPlayerResurrect(Player*, restorePercent, applySickness)` | Resurrection | ❌ **NOT AVAILABLE** |
| `OnPlayerDuelStart(Player*, Player*)` | Duel start | ✅ `OnDuelStart` |
| `OnPlayerDuelEnd(Player*, Player*, type)` | Duel end | ✅ `OnDuelEnd` |
| `OnPlayerJoinedGroup(Player*, Group*)` | Group join | ❌ **NOT AVAILABLE** |
| `OnPlayerTeleport(Player*, mapid, x, y, z, ori, options, target)` | **Teleport hook** | ❌ **NOT AVAILABLE** |

### AzerothCore-ONLY PlayerScript Hooks (Critical for DC)

These hooks exist **ONLY** in AzerothCore and are used by DC scripts:

| Hook | DC Usage | Impact if Missing |
|------|----------|-------------------|
| `OnPlayerUpdate(Player*, diff)` | Hotspots, MapExtension, Prestige, M+ | **CRITICAL** - Used for periodic checks |
| `OnPlayerResurrect(Player*, ...)` | Hotspots resurrection handling | **HIGH** - Need alternative |
| `OnPlayerTeleport(Player*, ...)` | Hotspots tracking | **HIGH** - Need alternative |
| `OnAfterConfigLoad(bool reload)` | Many systems initialization | **CRITICAL** - Configuration loading |
| `OnBeforeQuestComplete(Player*, Quest*)` | Custom quest logic | **MODERATE** - Can use status change |
| `OnAfterUpdateAttackPowerAndDamage` | Prestige stat modifications | **HIGH** - Combat stat hooks |

---

## WorldScript Comparison

| Hook | AzerothCore | TrinityCore 3.3.5 |
|------|-------------|-------------------|
| `OnStartup()` | ✅ | ✅ |
| `OnShutdown()` | ✅ | ✅ |
| `OnUpdate(diff)` | ✅ | ✅ |
| `OnAfterConfigLoad(bool reload)` | ✅ | ✅ `OnConfigLoad` |
| `OnOpenStateChange(bool open)` | ✅ | ✅ |
| `OnMotdChange(newMotd)` | ✅ | ✅ |
| `OnShutdownInitiate(code, mask)` | ✅ | ✅ |
| `OnShutdownCancel()` | ✅ | ✅ |

**WorldScript** hooks are largely compatible.

---

## AllCreatureScript (AzerothCore-ONLY)

**TrinityCore 3.3.5 does NOT have this script type.**

DC Usage in `mythic_plus_core_scripts.cpp`:

```cpp
class MythicPlusCreatureScript : public AllCreatureScript
{
    void OnAllCreatureUpdate(Creature* creature, uint32 diff) override;
    void OnCreatureSelectLevel(Creature* creature) override;
    // ... damage scaling, health scaling
}
```

**Impact:** The entire Mythic+ creature scaling system depends on this.

### TrinityCore Alternative
- Would need to modify core `Creature.cpp` directly
- Or use spell/aura hooks for scaling (less clean)
- Or create custom hook system (significant work)

---

## AllMapScript (AzerothCore-ONLY)

**TrinityCore 3.3.5 does NOT have this script type.**

DC Usage:
```cpp
class MythicPlusAllMapScript : public AllMapScript
{
    void OnAfterPlayerEnterMap(Player* player, Map* map) override;
    void OnAfterPlayerLeaveMap(Player* player, Map* map) override;
}
```

**Impact:** Map-wide event handling for M+ dungeons.

---

## UnitScript (AzerothCore-ONLY in this form)

DC Usage:
```cpp
class MythicPlusUnitScript : public UnitScript
{
    void OnDamage(Unit* attacker, Unit* victim, uint32& damage) override;
    void OnHeal(Unit* healer, Unit* target, uint32& heal) override;
}
```

**Impact:** Critical for M+ damage/healing scaling per affix.

---

## Script Type Availability Summary

| Script Type | AzerothCore | TrinityCore 3.3.5 | DC Files Using It |
|-------------|-------------|-------------------|-------------------|
| PlayerScript | ✅ Extended | ✅ Basic | 25+ |
| WorldScript | ✅ Extended | ✅ Basic | 18+ |
| CreatureScript | ✅ | ✅ | 15+ |
| GameObjectScript | ✅ | ✅ | 3+ |
| AllCreatureScript | ✅ | ❌ | 3+ (M+ core) |
| AllMapScript | ✅ | ❌ | 2+ (M+ core) |
| UnitScript | ✅ | ❌ | 4+ (M+, ItemUpgrade) |
| GlobalScript | ✅ | ❌ | 1+ |
| MiscScript | ✅ | ❌ | 2+ |
| WorldObjectScript | ✅ | ❌ | 1+ |
| ItemScript | ✅ | ✅ | 3+ |
| SpellScript | ✅ | ✅ | 5+ |
| AuraScript | ✅ | ✅ | 3+ |
| InstanceMapScript | ✅ | ✅ | 0 |
| BattlegroundScript | ✅ | ✅ | 2+ (Gilneas, Hinterland) |

---

## Hook Signature Differences

### OnLogin
```cpp
// AzerothCore
void OnPlayerLogin(Player* player) override;

// TrinityCore 3.3.5
void OnLogin(Player* player, bool firstLogin) override;
```
**Note:** TrinityCore includes `firstLogin` parameter by default.

### Quest Completion
```cpp
// AzerothCore - Full quest object access
void OnPlayerCompleteQuest(Player* player, Quest const* quest) override;

// TrinityCore 3.3.5 - Only quest ID
void OnQuestStatusChange(Player* player, uint32 questId) override;
```
**Impact:** DC needs quest object access for DungeonQuestSystem.

### Level Change
```cpp
// AzerothCore
void OnPlayerLevelChanged(Player* player, uint8 oldLevel) override;

// TrinityCore 3.3.5
void OnLevelChanged(Player* player, uint8 oldLevel) override;
```
**Compatible** - just method name difference.

---

## Critical Gaps for DC Scripts

### 1. Missing `OnPlayerUpdate` - 8+ DC files use this
Files affected:
- `ac_hotspots.cpp`
- `PlayerScript_MapExtension.cpp`
- `dc_prestige_system.cpp`
- `affix_handlers.cpp` (M+ affixes)
- Multiple others

**Workaround:** Would need scheduled world update ticks + player iteration

### 2. Missing `AllCreatureScript` - M+ core depends on this
Files affected:
- `mythic_plus_core_scripts.cpp`

**Workaround:** Core modification or creature AI base class override

### 3. Missing `UnitScript` for damage hooks
Files affected:
- `mythic_plus_core_scripts.cpp`
- `ItemUpgradeTokenHooks.cpp`
- `ItemUpgradeProcScaling.cpp`

**Workaround:** SpellScript damage modifiers (limited)

### 4. Missing `OnAfterConfigLoad` distinction
TrinityCore has `OnConfigLoad(bool reload)` which is similar but timing may differ.

---

## Conclusion

**Migration Complexity: HIGH**

TrinityCore 3.3.5 lacks several hook types that AzerothCore has:
- `AllCreatureScript` - Used by M+ core
- `AllMapScript` - Used by M+ core
- `UnitScript` - Used by damage/healing modifications
- Extended PlayerScript hooks (`OnPlayerUpdate`, `OnPlayerResurrect`, `OnTeleport`)

Many DC systems would require:
1. Core modifications to add missing hooks
2. Complete redesign of hook-dependent systems
3. Alternative implementation patterns

**Estimated additional core modifications needed: 15-20 hook additions**
