# Executive Summary: AzerothCore to TrinityCore 3.3.5 Migration Evaluation

## Purpose
This evaluation analyzes the effort, advantages, and disadvantages of migrating the Dark Chaos (DC) custom scripts from AzerothCore to TrinityCore 3.3.5.

---

## Quick Answer

**❌ DO NOT MIGRATE**

The migration is technically possible but **not recommended** due to:
- Significant missing functionality in TrinityCore 3.3.5
- 4-8 months of development time required
- High risk of regression bugs
- No clear benefit over current AzerothCore implementation

---

## Key Findings

### 1. Critical Missing Features in TrinityCore 3.3.5

TrinityCore 3.3.5 lacks several hook systems that DC scripts heavily depend on:

| Missing Feature | DC Systems Affected |
|-----------------|---------------------|
| `AllCreatureScript` | Mythic Plus creature scaling |
| `AllMapScript` | Mythic Plus dungeon system |
| `UnitScript` | M+ affixes, Item Upgrade damage |
| `OnPlayerUpdate` | Hotspots, Prestige, Challenge Modes |
| Built-in Eluna | All Lua scripts |

### 2. Migration Effort

| Metric | Value |
|--------|-------|
| DC Script Files | 174 |
| OutdoorPvP HL Files | 34 |
| Custom Commands | 24 |
| AC Modules to Port | 10 (~80 files) |
| **Total Files** | **~312** |
| Lines of Code (estimated) | ~78,600+ |
| Estimated Duration | **9-11 months** |
| Developer-Days | 194-199 |
| Cost Estimate | $90,000 - $250,000 |

### 3. TrinityCore Built-in Features

Good news: Some AC modules have TC equivalents:

| Feature | AzerothCore | TrinityCore 3.3.5 |
|---------|-------------|-------------------|
| AuctionHouseBot | mod-ah-bot required | ✅ **BUILT-IN** |
| Cross-faction chat | Config option | ✅ **BUILT-IN** |
| Chat logging | Module | ✅ **BUILT-IN** |
| Eluna (Lua) | mod-eluna | ✅ ElunaTrinityWotlk (same API) |

This reduces module porting from 27.5 to 22 days.

### 4. Core Modifications Required

Before any script migration, TrinityCore 3.3.5 would need:
- 15-20 new hook types added to core
- ~22 days of core development work
- Ongoing maintenance of a custom TC fork

### 5. Additional Components

**OutdoorPvP Hinterland BG:**
- 32 extension files + 2 core files
- Custom queue system, state machine, AFK detection
- AIO (All-In-One) addon integration - AC-specific

**Custom Commands:**
- 24 CommandScript implementations (~169 commands)
- M+, Item Upgrades, Prestige, Seasons, HLBG, etc.

**AzerothCore Modules (9 need porting, 1 built-in):**
- mod-cfbg, mod-arac - HIGH complexity
- mod-ale, mod-npc-services - MEDIUM complexity
- mod-learn-spells, mod-world-chat, mod-customlogin - LOW complexity
- ~~mod-ah-bot~~ - **Built into TrinityCore!**

---

## Comparison Summary

| Criteria | AzerothCore | TrinityCore 3.3.5 |
|----------|-------------|-------------------|
| Hook Availability | ✅ Complete | ❌ Missing critical hooks |
| Eluna (Lua) Support | ✅ Built-in | ✅ ElunaTrinityWotlk fork |
| AuctionHouseBot | ⚠️ Module | ✅ Built-in |
| DC Compatibility | ✅ Works now | ❌ Requires major rework |
| Private Server Focus | ✅ Primary | ⚠️ Secondary |
| Module Ecosystem | ✅ Large (100+) | ⚠️ Small (~20) |
| 3.3.5 Priority | ✅ Main branch | ⚠️ Legacy branch |
| Community Support | ✅ Strong | ✅ Strong |

---

## Risk Summary

### Migration Risks (HIGH)
- Core modifications may introduce instability
- 4-8 month development freeze on features
- Regression bugs in critical systems (M+, Prestige, etc.)
- Maintenance burden of custom TC fork

### Staying on AzerothCore Risks (LOW)
- Project is active and maintained
- ChromieCraft backing ensures continued development
- No immediate concerns

---

## Recommendation

### ✅ STAY ON AZEROTHCORE

**Rationale:**
1. AzerothCore has all features DC needs
2. Migration offers no clear benefit
3. Effort far exceeds any potential gains
4. Risk of breaking working systems is high

### Alternative Actions
Instead of migrating, consider:
- Continue improving current AC implementation
- Contribute fixes back to AzerothCore
- Document current architecture for future reference
- Consider TC only if specific features become essential

---

## Decision Matrix

| If Goal Is... | Recommended Action |
|---------------|-------------------|
| Continue DC development | Stay on AzerothCore |
| Improve stability | Fix bugs on AC, contribute upstream |
| Support newer expansions | Fork to newer AC version when needed |
| Reduce technical debt | Refactor on current AC platform |
| Comply with TC mandate | Budget 4-8 months, accept risks |

---

## Supporting Documents

1. **01_HOOK_COMPARISON_MATRIX.md** - Detailed hook-by-hook comparison
2. **02_API_DIFFERENCES.md** - Code-level API differences
3. **03_MIGRATION_EFFORT_ANALYSIS.md** - Detailed effort breakdown
4. **04_PROS_AND_CONS.md** - Full advantages/disadvantages analysis
5. **05_ADDITIONAL_COMPONENTS.md** - OutdoorPvP HL, Commands, and Modules analysis
6. **06_BUILTIN_FEATURES_AND_COMPARISON.md** - TC built-in features, player experience comparison, Eluna availability

---

## Updated Totals (Including Additional Components)

| Component | Files | Effort |
|-----------|-------|--------|
| DC Scripts | 174 | 4-6 months |
| OutdoorPvP Hinterland BG | 34 | 18 days |
| Custom Commands (24) | 24 | 26 days |
| AzerothCore Modules (10) | ~80 | 22 days* |
| **Grand Total** | **~312 files** | **9-11 months** |

*Reduced from 27.5 days due to TrinityCore built-in features

### TrinityCore Built-in Features (No Porting Needed)
- ✅ **AuctionHouseBot** - Full buyer/seller implementation built into TC
- ✅ **Cross-faction chat** - CONFIG_ALLOW_TWO_SIDE_INTERACTION_CHANNEL
- ✅ **Chat logging** - ChatLogScript built-in
- ✅ **Eluna** - Available via ElunaTrinityWotlk fork (same API as AC)

### Modules Still Requiring Port
- mod-learn-spells (Auto-learn spells) - 1 day
- mod-world-chat (Global chat channel) - 0.5 days
- mod-cfbg (Cross-faction BG) - 7 days
- mod-skip-dk-starting-area - 0.5 days
- mod-npc-services - 2 days
- mod-instance-reset - 2 days
- mod-arac (Any Race Any Class) - 3 days
- mod-ale (Account-wide mounts/pets) - 5 days
- mod-customlogin - 1 day

---

## Prepared By
GitHub Copilot Analysis
Date: December 2025

## Files Analyzed
- `src/server/scripts/DC/` - 174 script files
- `src/server/game/Scripting/ScriptMgr.*` - Hook definitions
- TrinityCore 3.3.5 branch - GitHub repository analysis
