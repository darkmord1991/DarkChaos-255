# AzerothCore to TrinityCore 3.3.5 - Migration Effort Analysis

## Overview

This document provides a detailed effort estimate for migrating the DC (Dark Chaos) custom scripts from AzerothCore to TrinityCore 3.3.5.

---

## Current DC Codebase Statistics

| Metric | Count |
|--------|-------|
| Total DC script files (.cpp/.h) | 174 |
| PlayerScript implementations | 25+ |
| WorldScript implementations | 18+ |
| CreatureScript implementations | 35+ |
| AllCreatureScript implementations | 3 |
| AllMapScript implementations | 2 |
| UnitScript implementations | 4 |
| GameObjectScript implementations | 3 |
| SpellScript/AuraScript implementations | 8+ |
| ItemScript implementations | 3 |
| CommandScript implementations | 5+ |
| Lines of Code (estimated) | 50,000+ |

---

## Migration Tasks Breakdown

### Phase 1: Core Hook Extensions (Prerequisites)
**Estimated: 3-4 weeks**

TrinityCore 3.3.5 is missing critical hook types. These must be added to the core first.

| Task | Effort | Files to Modify |
|------|--------|-----------------|
| Add AllCreatureScript base class | 3 days | ScriptMgr.h/cpp, ScriptDefines |
| Add AllMapScript base class | 2 days | ScriptMgr.h/cpp |
| Add UnitScript damage/heal hooks | 4 days | ScriptMgr.h/cpp, Unit.cpp |
| Add PlayerScript::OnPlayerUpdate | 2 days | ScriptMgr.h/cpp, Player.cpp |
| Add OnAfterConfigLoad hook | 1 day | ScriptMgr.h/cpp, World.cpp |
| Add OnPlayerResurrect hook | 1 day | ScriptMgr.h/cpp, Player.cpp |
| Add OnPlayerTeleport hook | 1 day | ScriptMgr.h/cpp, Player.cpp |
| Add GlobalScript hooks | 2 days | ScriptMgr.h/cpp |
| Add MiscScript hooks | 1 day | ScriptMgr.h/cpp |
| Testing all new hooks | 5 days | All above |

**Total Phase 1: ~22 working days (1 developer)**

---

### Phase 2: Script Adapter Layer
**Estimated: 1-2 weeks**

Create compatibility macros/wrappers to minimize per-file changes.

| Task | Effort |
|------|--------|
| Create AC-to-TC method name mappings | 2 days |
| Create compatibility header (dc_compat.h) | 1 day |
| Test compatibility layer | 2 days |
| Document migration patterns | 1 day |

**Total Phase 2: ~6 working days**

---

### Phase 3: Script-by-Script Migration

#### 3.1 High Complexity Scripts (Major Rework Required)
**Estimated: 4-6 weeks**

| Script/System | Files | Complexity | Effort | Notes |
|---------------|-------|------------|--------|-------|
| Mythic Plus Core | 10+ | **EXTREME** | 10 days | AllCreatureScript, AllMapScript, UnitScript |
| Prestige System | 5+ | **HIGH** | 5 days | OnPlayerUpdate, stat hooks |
| Hotspots System | 4+ | **HIGH** | 4 days | OnPlayerUpdate, OnTeleport, OnResurrect |
| ItemUpgrade System | 8+ | **HIGH** | 6 days | UnitScript damage hooks, token hooks |
| CrossSystem | 6+ | **HIGH** | 4 days | Multiple hook types |
| Challenge Modes | 5+ | **HIGH** | 4 days | OnPlayerUpdate, death hooks |
| Dungeon Quests | 4+ | **MEDIUM** | 3 days | Quest hooks differ |
| Seasons System | 5+ | **MEDIUM** | 3 days | Custom event system |

**Subtotal: ~39 working days**

#### 3.2 Medium Complexity Scripts (Some Refactoring)
**Estimated: 2-3 weeks**

| Script/System | Files | Complexity | Effort | Notes |
|---------------|-------|------------|--------|-------|
| Addon Extensions | 6+ | **MEDIUM** | 4 days | Addon messaging API |
| Map Extensions | 4+ | **MEDIUM** | 3 days | OnPlayerUpdate |
| Phased Duels | 3+ | **LOW-MED** | 2 days | Duel hooks compatible |
| Flightmasters (AC) | 2+ | **LOW-MED** | 2 days | Standard hooks |
| Gilneas BG | 4+ | **MEDIUM** | 3 days | BG scripts |
| Hinterland BG | 5+ | **MEDIUM** | 3 days | BG scripts |
| Jadeforest | 3+ | **LOW** | 2 days | Standard NPC scripts |

**Subtotal: ~19 working days**

#### 3.3 Low Complexity Scripts (Minor Changes)
**Estimated: 1-2 weeks**

| Script/System | Files | Complexity | Effort |
|---------------|-------|------------|--------|
| Login Announce | 1 | **LOW** | 0.5 days |
| Heirloom Cache | 1 | **LOW** | 0.5 days |
| FirstStart | 2 | **LOW** | 1 day |
| Achievement Hooks | 3 | **LOW** | 1 day |
| Various NPCs | 10+ | **LOW** | 3 days |
| Spell Scripts | 8+ | **LOW** | 2 days |
| Item Scripts | 3+ | **LOW** | 1 day |

**Subtotal: ~9 working days**

---

### Phase 4: Eluna Integration
**Estimated: 2-3 weeks**

DC uses Eluna Lua scripting extensively. TrinityCore 3.3.5 doesn't have built-in Eluna.

| Task | Effort |
|------|--------|
| Port Eluna module to TrinityCore 3.3.5 | 7 days |
| OR: Use existing Eluna-TrinityCore fork | 3 days |
| Test all Lua scripts | 5 days |
| Fix Lua compatibility issues | 5 days |

**Total Phase 4: ~10-17 working days**

---

### Phase 5: Database & SQL
**Estimated: 1 week**

| Task | Effort |
|------|--------|
| Audit prepared statement differences | 2 days |
| Migrate custom tables | 1 day |
| Test database operations | 2 days |

**Total Phase 5: ~5 working days**

---

### Phase 6: Testing & Stabilization
**Estimated: 3-4 weeks**

| Task | Effort |
|------|--------|
| Unit testing per system | 10 days |
| Integration testing | 5 days |
| Performance testing | 3 days |
| Bug fixes | 7 days |

**Total Phase 6: ~25 working days**

---

## Total Effort Summary

| Phase | Duration | Developer-Days |
|-------|----------|----------------|
| Phase 1: Core Hook Extensions | 3-4 weeks | 22 |
| Phase 2: Adapter Layer | 1-2 weeks | 6 |
| Phase 3: Script Migration | 7-9 weeks | 67 |
| Phase 4: Eluna Integration | 2-3 weeks | 10-17 |
| Phase 5: Database | 1 week | 5 |
| Phase 6: Testing | 3-4 weeks | 25 |
| **TOTAL** | **17-23 weeks** | **135-142 days** |

---

## Risk Factors

### High Risk
1. **Hidden Hook Dependencies** - Scripts may depend on hooks not documented
2. **Core Instability** - Adding hooks to TrinityCore core may introduce bugs
3. **Eluna Compatibility** - Lua scripts may have subtle differences
4. **Performance Differences** - TC may handle some operations differently

### Medium Risk
1. **Database Timing** - Async query behavior may differ
2. **Thread Safety** - AC and TC may have different threading models
3. **Memory Management** - Different smart pointer usage

### Low Risk
1. **API Naming** - Easy to address with compatibility header
2. **Enum Values** - Same WoW version = same values
3. **Map/Instance API** - Well standardized

---

## Resource Requirements

### Minimum Team
| Role | Count | Duration |
|------|-------|----------|
| Senior C++ Developer (Core) | 1 | Full duration |
| C++ Developer (Scripts) | 1-2 | Phase 3 onwards |
| QA/Tester | 1 | Phase 5-6 |

### Recommended Team
| Role | Count | Duration |
|------|-------|----------|
| Lead Developer (Architecture) | 1 | Full duration |
| Senior C++ Developer (Core) | 1 | Phases 1-2 |
| C++ Developers (Scripts) | 2 | Phases 3-6 |
| Lua Developer | 1 | Phase 4 |
| QA Engineers | 2 | Phases 5-6 |

---

## Cost Estimate (Rough)

Assuming average developer rate of $50-100/hour:

| Scenario | Hours | Cost Range |
|----------|-------|------------|
| Single Developer | 1,070-1,136 | $53,500 - $113,600 |
| Small Team (3) | ~400-500 per dev | $60,000 - $150,000 |
| Full Team (5-6) | Faster delivery | $80,000 - $180,000 |

*Note: These are rough estimates. Actual costs depend on developer rates, location, and unforeseen complications.*

---

## Timeline Options

### Option A: Single Developer
- Duration: 6-8 months
- Risk: High (single point of failure)
- Cost: Lowest

### Option B: Small Team (3 developers)
- Duration: 3-4 months
- Risk: Medium
- Cost: Medium

### Option C: Full Team (5-6 developers)
- Duration: 2-3 months
- Risk: Lower
- Cost: Highest

---

## Recommendation

### DO NOT MIGRATE - Reasons:

1. **Significant Effort** - 4-6 months minimum, even with team
2. **Core Modifications Required** - TrinityCore lacks essential hooks
3. **Maintenance Burden** - Would need to maintain custom TC fork
4. **Feature Parity** - AzerothCore is more feature-complete for custom servers
5. **Community Support** - AC has stronger private server community
6. **Ongoing Development** - Both cores are active, but AC modules ecosystem is larger

### ALTERNATIVE: Stay on AzerothCore

The current AzerothCore implementation is:
- Working and stable
- Has all required hooks
- Has Eluna built-in
- Has active community support
- Has module ecosystem

**Investment in improving current AC setup is more cost-effective than migration.**

---

## If Migration Is Still Required

Only migrate if there are compelling reasons such as:
- Licensing requirements
- Specific TC-only features needed
- Organizational mandate
- Long-term strategic decision

In that case, recommend:
1. Start with Phase 1 (hook additions) as proof-of-concept
2. Evaluate complexity after Phase 1
3. Consider hybrid approach (some features on TC, keep others on AC)
4. Budget for 150-200% of estimated time for unforeseen issues
