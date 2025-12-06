# AzerothCore vs TrinityCore 3.3.5 - Pros and Cons Comparison

## Overview

This document provides a balanced comparison of advantages and disadvantages of each core for the Dark Chaos project.

---

## AzerothCore (Current)

### Pros ✅

| Category | Advantage | Impact for DC |
|----------|-----------|---------------|
| **Hook System** | Extensive hook system with 100+ hooks | Essential for DC scripts |
| **AllCreatureScript** | Global creature event handling | Required for M+ scaling |
| **AllMapScript** | Global map event handling | Required for M+ dungeon system |
| **UnitScript** | Damage/healing modification hooks | Required for M+ affixes |
| **PlayerScript Extensions** | OnPlayerUpdate, OnTeleport, OnResurrect | Used by Hotspots, Prestige |
| **Eluna Built-in** | Lua scripting out of the box | Used for many DC features |
| **Module System** | Official module repository | Easy feature additions |
| **Private Server Focus** | Designed for custom servers | Matches DC use case |
| **Active Community** | Discord, Forums, Wiki | Good support available |
| **Docker Support** | Official Docker images | Easy deployment |
| **Documentation** | Well-documented hooks and APIs | Faster development |
| **Mod Support** | Better mod/custom content support | Easier customization |

### Cons ❌

| Category | Disadvantage | Impact for DC |
|----------|--------------|---------------|
| **Fork Status** | Fork of TrinityCore (slightly behind) | Minor - still active |
| **Blizzlike Focus** | Less focus on pure blizzlike | N/A - DC is custom |
| **Smaller Team** | Smaller core dev team than TC | Minor - community compensates |
| **Some Bugs** | Occasional AC-specific bugs | Low impact - can contribute fixes |

---

## TrinityCore 3.3.5 Branch

### Pros ✅

| Category | Advantage | Impact for DC |
|----------|-----------|---------------|
| **Original Project** | Original WoW emulator project | Historical significance |
| **Blizzlike Quality** | Strong focus on retail accuracy | N/A - DC is heavily custom |
| **Core Stability** | Mature, stable codebase | Positive |
| **Large Team** | More core developers | More bug fixes potentially |
| **Retail Expansion Support** | TC supports modern expansions | N/A - DC is WotLK |
| **GPL License** | Same license as AC | No difference |
| **GitHub Stars** | 4.8k stars, large community | Good visibility |
| **Long History** | 36k+ commits, 550 contributors | Proven track record |

### Cons ❌

| Category | Disadvantage | Impact for DC |
|----------|--------------|---------------|
| **Limited Hook System** | Fewer hooks than AzerothCore | **CRITICAL** - Major refactoring |
| **No AllCreatureScript** | Missing global creature hooks | **CRITICAL** - M+ core broken |
| **No AllMapScript** | Missing global map hooks | **CRITICAL** - M+ system affected |
| **No UnitScript** | Missing damage/heal hooks | **CRITICAL** - Affixes broken |
| **No OnPlayerUpdate** | Missing player tick hook | **HIGH** - Many systems affected |
| **No Built-in Eluna** | Would need separate integration | **HIGH** - Lua scripts affected |
| **Less Module Support** | Smaller module ecosystem | Moderate - fewer ready solutions |
| **Private Server Focus** | Not primary focus | Moderate - less custom-friendly |
| **Retail Expansion Priority** | 3.3.5 branch lower priority | Moderate - slower fixes |
| **Core Modifications Needed** | Must add hooks to core | **CRITICAL** - Major work |

---

## Feature Comparison Matrix

| Feature | AzerothCore | TrinityCore 3.3.5 | Winner |
|---------|-------------|-------------------|--------|
| PlayerScript hooks | 100+ | ~35 | **AzerothCore** |
| Global creature hooks | ✅ | ❌ | **AzerothCore** |
| Global map hooks | ✅ | ❌ | **AzerothCore** |
| Unit damage/heal hooks | ✅ | ❌ | **AzerothCore** |
| Built-in Lua (Eluna) | ✅ | ❌ | **AzerothCore** |
| Module ecosystem | Large | Small | **AzerothCore** |
| Docker support | ✅ | ✅ | Tie |
| Database compatibility | Full | Full | Tie |
| 3.3.5 client support | ✅ | ✅ | Tie |
| Core stability | Good | Excellent | **TrinityCore** |
| Blizzlike accuracy | Good | Excellent | **TrinityCore** |
| Modern expansion support | ❌ | ✅ | **TrinityCore** |
| Community size | Medium | Large | **TrinityCore** |
| Private server friendly | ✅ | ❌ | **AzerothCore** |
| Custom content support | Excellent | Good | **AzerothCore** |

---

## DC-Specific Impact Analysis

### Systems That Would Break on TrinityCore 3.3.5

| System | Why It Breaks | Effort to Fix |
|--------|---------------|---------------|
| **Mythic Plus Core** | Needs AllCreatureScript, UnitScript | 15+ days |
| **Affix System** | Needs UnitScript damage hooks | 8+ days |
| **Hotspots** | Needs OnPlayerUpdate, OnTeleport | 6+ days |
| **Prestige System** | Needs OnPlayerUpdate, stat hooks | 7+ days |
| **Item Upgrade Scaling** | Needs UnitScript damage hooks | 6+ days |
| **Challenge Modes** | Needs OnPlayerUpdate | 4+ days |
| **Map Extension** | Needs OnPlayerUpdate | 3+ days |

### Systems That Would Work (With Minor Changes)

| System | Changes Needed | Effort |
|--------|----------------|--------|
| Login Announce | Method name changes | 0.5 days |
| Phased Duels | Duel hook names | 1 day |
| Gossip NPCs | Enum changes | 2 days |
| Spell Scripts | Minor API diffs | 2 days |
| BG Scripts | Some hook changes | 3 days |

---

## Risk Assessment

### Staying on AzerothCore
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| AC project discontinued | Very Low | High | Fork or migrate then |
| Major breaking changes | Low | Medium | Pin to version |
| Hook API changes | Low | Low | Compatibility layer |

### Migrating to TrinityCore
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Missing hooks cause issues | **Certain** | **High** | Add to core |
| Core modifications rejected | Medium | High | Maintain fork |
| Longer development time | **High** | **High** | Budget more time |
| Regression bugs | Medium | Medium | Extensive testing |
| Team unfamiliarity | Medium | Medium | Training time |

---

## Strategic Considerations

### When to Stay on AzerothCore
- ✅ Project is working well
- ✅ Custom features are the priority
- ✅ Development speed matters
- ✅ Lua scripting is used
- ✅ No compelling reason to switch

### When to Consider TrinityCore
- Organization mandates TC
- Need features specific to TC
- Planning to support newer expansions
- Blizzlike accuracy is critical
- Have resources for extended migration

---

## Community & Support Comparison

| Aspect | AzerothCore | TrinityCore |
|--------|-------------|-------------|
| Discord | Active, helpful | Active, larger |
| Forums | ChromieCraft/AC forums | Larger forum base |
| Wiki | Comprehensive | Comprehensive |
| Issue Response | Fast | Fast |
| Module Contrib | Encouraged | Less common |
| Private Server Acceptance | High | Lower |

---

## Long-term Outlook

### AzerothCore
- Continues active development
- Growing module ecosystem
- Strong private server community
- ChromieCraft backing (funded development)
- Regular releases and updates

### TrinityCore 3.3.5
- Maintained but lower priority than retail
- Focus shifting to newer expansions
- Still gets bug fixes
- Large legacy codebase
- Stable but less innovation

---

## Conclusion Summary

| Metric | AzerothCore | TrinityCore 3.3.5 |
|--------|-------------|-------------------|
| **Suitability for DC** | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| **Migration Effort** | N/A | ⭐ (High effort) |
| **Feature Completeness** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Hook Availability** | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| **Custom Content Support** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Community Support** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Stability** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

**Recommendation: STAY ON AZEROTHCORE**

The DC project relies heavily on AzerothCore-specific features that don't exist in TrinityCore 3.3.5. Migration would require extensive core modifications, significant development time, and introduce regression risks with no clear benefit.
