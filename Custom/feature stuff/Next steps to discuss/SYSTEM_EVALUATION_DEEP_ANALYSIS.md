# Deep System Evaluation & Feasibility Analysis
## AzerothCore 3.3.5a Custom Systems for DarkChaos-255

**Document Date:** November 27, 2025
**Evaluation Scope:** Server-side (C++/Eluna), Client-side (Addon/MPQ), Database changes

---

## Executive Summary

This document provides a comprehensive analysis of 12 proposed systems, evaluating their:
- **Effort**: Development time, complexity, resources needed
- **Impact**: Player experience, server performance, community value
- **Relations**: Dependencies, synergies with existing systems
- **Benefits/Disadvantages**: Pros and cons
- **3.3.5a Feasibility**: What's possible without client modification

---

## 1. Performance Optimization

### Overview
Server-side optimizations to reduce lag, improve response times, and handle higher player counts.

### Effects
- Reduced server tick time
- Lower memory footprint
- Better database query performance
- Improved pathfinding efficiency

### Effort Analysis
| Component | Effort | Complexity |
|-----------|--------|------------|
| Database query optimization | 1-2 weeks | Medium |
| Spell/aura tick batching | 2-3 weeks | High |
| Grid loading optimization | 2-4 weeks | Very High |
| Memory pool improvements | 1-2 weeks | Medium |
| Config-based tuning | 1-3 days | Low |

**Total Estimated Effort:** 6-12 weeks

### Impact Assessment
| Metric | Current | Potential |
|--------|---------|-----------|
| Server tick | ~50-100ms | ~20-40ms |
| Player capacity | ~500 | ~1000+ |
| Database load | High | Medium |
| Memory usage | Variable | Optimized |

### Relations
- **Dependencies:** None (standalone improvement)
- **Synergies:** Benefits ALL other systems
- **Conflicts:** None

### Benefits
✅ Better player experience (less lag)
✅ Higher concurrent player capacity
✅ Lower hosting costs (less hardware needed)
✅ Foundation for all future systems
✅ Existing AzerothCore PRs can be cherry-picked

### Disadvantages
❌ Requires deep C++ knowledge
❌ Risk of introducing bugs
❌ Extensive testing required
❌ Some optimizations may conflict with custom scripts

### 3.3.5a Compatibility
**✅ FULLY COMPATIBLE** - Server-side only, no client changes

### Server/Client Changes
| Layer | Changes Required |
|-------|------------------|
| Server C++ | Core modifications |
| Database | Index optimization, query restructuring |
| Eluna | None |
| Client | None |
| Addon | None |

### Rating: ⭐⭐⭐⭐⭐ (5/5)
**Priority: CRITICAL** - Should be done first, enables everything else

---

## 2. Addon Protocol System

### Overview
Formalized bidirectional communication between server (Eluna/C++) and client (addon) using structured messages over addon channels.

### Current State
We already have **AIO (Addon Interface for elunaOrb)** implemented:
- `Custom/Eluna scripts/AIO.lua` - Server-side
- `Custom/Client addons needed/AIO_Client/AIO.lua` - Client-side
- Uses `SendAddonMessage` with prefix-based routing
- Supports message fragmentation (>255 bytes)
- Has compression (LZW) and obfuscation options

### Effects
- Enables complex UI addons
- Real-time data sync (timers, scores, states)
- Custom auction house, mail, guild features
- Live dungeon/raid information display

### Effort Analysis
| Component | Effort | Complexity |
|-----------|--------|------------|
| Protocol standardization | 3-5 days | Low |
| Message versioning | 1-2 days | Low |
| Error handling | 2-3 days | Medium |
| Documentation | 2-3 days | Low |
| Additional handlers | 1-2 weeks | Medium |

**Total Estimated Effort:** 2-4 weeks (mostly documentation/standardization)

### Impact Assessment
- **Already functional** via AIO
- Enables: Item Upgrade UI, Mythic+ timers, Hotspot notifications, Season info

### Relations
- **Dependencies:** None (already implemented)
- **Synergies:** 
  - Mythic+ Spectator Mode (live data)
  - AOE Loot filtering preferences
  - Housing furniture placement UI
  - Pet/Mount collection display
- **Conflicts:** None

### Benefits
✅ Already implemented (AIO)
✅ Well-tested solution
✅ Supports complex data structures
✅ Works with 3.3.5a client limitations

### Disadvantages
❌ 255 byte client→server limit (requires chunking)
❌ Addon installation required
❌ Can be disrupted by addon conflicts
❌ No built-in encryption (security concern)

### 3.3.5a Compatibility
**✅ FULLY COMPATIBLE** - Uses native addon message system

### Server/Client Changes
| Layer | Changes Required |
|-------|------------------|
| Server C++ | None (hooks exist) |
| Database | Message queue table (optional) |
| Eluna | Handler registration |
| Client | None |
| Addon | Required for each feature |

### Rating: ⭐⭐⭐⭐⭐ (5/5)
**Priority: ALREADY DONE** - Just needs standardization

---

## 3. Cross-System Integration

### Overview
Unified framework connecting all custom systems (Mythic+, Seasons, Hotspots, Item Upgrade, etc.) with shared data and events.

### Effects
- Season changes affect Mythic+ pools automatically
- Item upgrades sync with Great Vault
- Hotspot rewards respect season multipliers
- Unified player progression tracking

### Effort Analysis
| Component | Effort | Complexity |
|-----------|--------|------------|
| Event bus system | 1-2 weeks | Medium |
| Shared state manager | 2-3 weeks | High |
| Cross-system hooks | 1-2 weeks | Medium |
| Integration testing | 2-3 weeks | High |
| Documentation | 1 week | Low |

**Total Estimated Effort:** 7-11 weeks

### Impact Assessment
- Reduces duplicate code
- Ensures consistent behavior
- Simplifies future development
- Better maintainability

### Relations
- **Dependencies:** All existing systems
- **Synergies:** Everything
- **Conflicts:** May require refactoring existing code

### Benefits
✅ Cleaner architecture
✅ Easier debugging
✅ Consistent player experience
✅ Faster feature development

### Disadvantages
❌ Large refactoring effort
❌ Risk of breaking existing features
❌ Requires careful planning
❌ Testing overhead

### 3.3.5a Compatibility
**✅ FULLY COMPATIBLE** - Server-side architecture

### Server/Client Changes
| Layer | Changes Required |
|-------|------------------|
| Server C++ | Event system, managers |
| Database | Unified tables |
| Eluna | Wrapper scripts |
| Client | None |
| Addon | Updated handlers |

### Rating: ⭐⭐⭐⭐ (4/5)
**Priority: HIGH** - Long-term investment, best done incrementally

---

## 4. Mythic+ Spectator Mode

### Overview
Allow players to watch ongoing Mythic+ runs in real-time without participating.

### Current State
AzerothCore has **ArenaSpectator** system:
- `src/server/game/ArenaSpectator/ArenaSpectator.h`
- Sends real-time data via addon messages
- Supports: HP, power, auras, casts, positions

### Effects
- Esports/streaming potential
- Learn dungeon strategies
- Verify completion claims
- Community engagement

### Effort Analysis
| Component | Effort | Complexity |
|-----------|--------|------------|
| Dungeon spectator hooks | 3-4 weeks | High |
| Phased viewing system | 2-3 weeks | High |
| UI addon | 3-4 weeks | Medium |
| Anti-cheat measures | 1-2 weeks | Medium |
| Recording/replay | 4-6 weeks | Very High |

**Total Estimated Effort:** 13-19 weeks

### Impact Assessment
- Community building
- Competitive scene enabler
- Content creator friendly
- Prestige system integration

### Relations
- **Dependencies:** Mythic+ system, Addon Protocol
- **Synergies:** 
  - Leaderboards
  - Achievement verification
  - Tournament system
- **Conflicts:** Performance concerns with many spectators

### Benefits
✅ Unique selling point
✅ Community engagement
✅ Skill improvement for players
✅ Streaming-friendly

### Disadvantages
❌ Complex implementation
❌ Performance overhead per spectator
❌ Potential for abuse (call-outs)
❌ UI addon development required
❌ No native spectator support in 3.3.5a

### 3.3.5a Compatibility
**⚠️ PARTIALLY COMPATIBLE** - Requires creative workarounds
- Can use invisible player clones or phasing
- Arena spectator code can be adapted
- No native "watch" interface

### Server/Client Changes
| Layer | Changes Required |
|-------|------------------|
| Server C++ | Spectator manager, phase handling |
| Database | Spectator tracking |
| Eluna | Event forwarding |
| Client | None (vanilla client) |
| Addon | **Custom spectator UI** (required) |

### Rating: ⭐⭐⭐ (3/5)
**Priority: LOW** - Nice to have, but complex

---

## 5. AOE Loot Extension - Smart Filtering

### Overview
Extend existing AOE loot to include:
- Quality filtering (only loot epics+)
- Type filtering (skip cloth as plate wearer)
- Auto-vendor trash
- Custom item rules

### Effects
- Faster loot processing
- Less inventory management
- Customizable per player

### Effort Analysis
| Component | Effort | Complexity |
|-----------|--------|------------|
| Server-side filtering | 1-2 weeks | Medium |
| Preference storage | 2-3 days | Low |
| Addon UI for settings | 1-2 weeks | Medium |
| Auto-vendor integration | 1 week | Medium |

**Total Estimated Effort:** 4-6 weeks

### Impact Assessment
- QoL improvement
- Faster dungeon clears
- Less "loot anxiety"

### Relations
- **Dependencies:** Addon Protocol (for UI)
- **Synergies:** 
  - Mythic+ (faster runs)
  - Hotspots (auto-loot)
- **Conflicts:** May bypass intended loot limits

### Benefits
✅ Significant QoL improvement
✅ Customizable
✅ Reduces server load (less item processing)
✅ Player retention

### Disadvantages
❌ Addon required for full feature set
❌ Can miss valuable items if misconfigured
❌ Balance concerns (too easy?)

### 3.3.5a Compatibility
**✅ FULLY COMPATIBLE**
- AOE loot already exists in retail via server-side implementation
- Filtering is server-side logic
- Settings can be stored in `characters.character_settings`

### Server/Client Changes
| Layer | Changes Required |
|-------|------------------|
| Server C++ | Loot filtering hooks |
| Database | Player preferences table |
| Eluna | Filter rule scripts |
| Client | None |
| Addon | **Optional** settings UI |

### Rating: ⭐⭐⭐⭐ (4/5)
**Priority: MEDIUM** - Good QoL, moderate effort

---

## 6. Mythic+ Rating System

### Current State: **ALREADY IMPLEMENTED ✅**

Our Mythic+ system already includes:
```cpp
// From MythicPlusRunManager.cpp
CREATE TABLE dc_mythic_player_rating (
  id INT PRIMARY KEY AUTO_INCREMENT,
  player_guid BIGINT,
  season_id INT,
  current_rating INT,
  best_run_rating INT,
  highest_key_completed INT DEFAULT 0,
  total_runs INT,
  updated_at DATETIME,
);
```

### Rating Formula (Current)
```cpp
// Base rating per keystone level
uint32 baseRating = keystoneLevel * 10;

// Death multiplier
float deathMult = 1.0f;
if (deaths <= 2) deathMult = 1.5f;       // +50% bonus
else if (deaths <= 5) deathMult = 1.25f;  // +25% bonus
else if (deaths >= 10) deathMult = 0.75f; // -25% penalty

uint32 ratingGain = baseRating * deathMult;
```

### Death/Upgrade System
| Deaths | Result |
|--------|--------|
| 0-5 | +2 keystone levels |
| 6-10 | +1 keystone level |
| 11-14 | Same level |
| 15+ | Keystone destroyed |

### What's Missing vs Retail
| Feature | Status |
|---------|--------|
| Death penalty | ✅ Implemented (level-based) |
| Key level tracking | ✅ Implemented |
| Timer system | ⚠️ Partial (tracked, not enforced) |
| Per-dungeon rating | ⚠️ Planned, not active |
| Seasonal reset | ✅ Implemented |
| Affixes | ⚠️ Partial |

### Rating: ⭐⭐⭐⭐⭐ (5/5)
**Priority: DONE** - Just needs timer enforcement refinement

---

## 7. Scalable Raid System

### Overview
Raids that scale difficulty/rewards based on group size (10-40 players) or selected difficulty tier.

### Effects
- Same raid content for various group sizes
- Progressive difficulty (Flex-like)
- Better gear for harder modes

### Effort Analysis
| Component | Effort | Complexity |
|-----------|--------|------------|
| Scaling formulas | 2-3 weeks | High |
| Per-raid configuration | 3-4 weeks | High |
| Boss script modifications | 4-8 weeks | Very High |
| Loot scaling | 2-3 weeks | Medium |
| Testing all combinations | 4-6 weeks | Very High |

**Total Estimated Effort:** 15-24 weeks

### Impact Assessment
- Huge content value
- Better for small guilds
- Replayability boost

### Relations
- **Dependencies:** None
- **Synergies:** 
  - Season system (rotating raids)
  - Item upgrade system (raid tokens)
- **Conflicts:** Balance complexity

### Benefits
✅ Flexible content for all guild sizes
✅ Massive replay value
✅ Uses existing raid content
✅ Progressive challenge system

### Disadvantages
❌ Extremely complex tuning
❌ Every boss needs individual attention
❌ Testing burden is enormous
❌ Balance will never be "perfect"
❌ Client has no native flex raid UI

### 3.3.5a Compatibility
**⚠️ PARTIALLY COMPATIBLE**
- Server-side scaling: ✅ Possible
- Dynamic difficulty UI: ❌ Not native
- Workaround: Use difficulty selection NPC or chat command

### Server/Client Changes
| Layer | Changes Required |
|-------|------------------|
| Server C++ | Scaling manager, boss modifiers |
| Database | Raid configs per size |
| Eluna | Scaling hooks |
| Client | None |
| Addon | Difficulty selector UI |

### Rating: ⭐⭐⭐ (3/5)
**Priority: LOW** - High value but enormous effort

---

## 8. Pet Collection System / Mount Collection Journal

### Overview
Retail-style collection UI showing all obtainable pets/mounts, their sources, and unlock status.

### Current 3.3.5a State
- Mounts: In spellbook (Companions tab)
- Pets: In spellbook (Companions tab)
- No "collection journal" with sources
- No account-wide collections

### Effects
- Collectible motivation
- Discovery/exploration drive
- Achievement integration

### Effort Analysis
| Component | Effort | Complexity |
|-----------|--------|------------|
| Collection database | 1-2 weeks | Medium |
| Account-wide unlock sync | 2-3 weeks | High |
| Addon UI (Journal) | 3-4 weeks | Medium |
| Source tooltips | 1-2 weeks | Medium |
| Missing collection tracking | 1-2 weeks | Medium |

**Total Estimated Effort:** 8-13 weeks

### Impact Assessment
- Strong collector motivation
- Progression visibility
- Social features (compare collections)

### Relations
- **Dependencies:** Addon Protocol
- **Synergies:** 
  - Achievement system
  - Season rewards (exclusive mounts)
  - Dungeon/Raid drops
- **Conflicts:** None

### Benefits
✅ Major QoL improvement
✅ Collection motivation
✅ Modern feel
✅ Account-wide value

### Disadvantages
❌ Addon required
❌ Database of all sources needed
❌ Account-wide sync complexity
❌ No native UI (must fake everything)

### 3.3.5a Compatibility
**⚠️ PARTIALLY COMPATIBLE**
- Collection tracking: ✅ Server-side
- Journal UI: ❌ Addon only
- Source tooltips: ⚠️ Addon modification
- Account-wide: ✅ Server-side (custom)

### Server/Client Changes
| Layer | Changes Required |
|-------|------------------|
| Server C++ | Collection manager |
| Database | `account_mounts`, `account_pets` tables |
| Eluna | Collection queries |
| Client | None |
| Addon | **Collection Journal UI** (required) |

### Rating: ⭐⭐⭐⭐ (4/5)
**Priority: MEDIUM** - High player value, moderate effort

---

## 9. Dynamic World Events System + World Boss System

### Overview
Time-based or triggered world events with:
- Rotating world bosses
- Invasion events
- Holiday enhancements
- Server-wide objectives

### Current State
AzerothCore has:
- `src/server/game/World/WorldState.cpp` - Server-wide state tracking
- `OutdoorPvP` system - Zone control
- Seasonal events (Brewfest, etc.)

### Effects
- Living world feel
- Community cooperation
- Time-limited rewards

### Effort Analysis
| Component | Effort | Complexity |
|-----------|--------|------------|
| Event scheduler | 2-3 weeks | Medium |
| World boss spawning | 1-2 weeks | Medium |
| Event announcement system | 1 week | Low |
| Phased event content | 3-4 weeks | High |
| Reward distribution | 1-2 weeks | Medium |

**Total Estimated Effort:** 8-12 weeks

### Impact Assessment
- Serverwide engagement
- Scheduled play incentive
- Community moments

### Relations
- **Dependencies:** None
- **Synergies:** 
  - Season system (seasonal events)
  - Hotspots (event hotspots)
  - Raid finder (world boss groups)
- **Conflicts:** Balance with scheduled content

### Benefits
✅ Living world experience
✅ Community engagement
✅ Scheduled play incentive
✅ FOMO/engagement driver

### Disadvantages
❌ Requires ongoing content
❌ Time zone fairness issues
❌ Performance during large events
❌ Balance concerns

### 3.3.5a Compatibility
**✅ FULLY COMPATIBLE**
- All server-side
- Can use existing creature/GO systems
- WorldState already exists

### Server/Client Changes
| Layer | Changes Required |
|-------|------------------|
| Server C++ | Event manager, scheduler |
| Database | Event definitions, schedules |
| Eluna | Event scripts |
| Client | None |
| Addon | **Optional** event tracker |

### Rating: ⭐⭐⭐⭐ (4/5)
**Priority: MEDIUM-HIGH** - Good engagement driver

---

## 10. Raid Finder System + Mythic Dungeon Finder Extension

### Overview
Extend existing LFG/LFR systems:
- Raid finder for older/current raids
- Mythic dungeon queuing
- Mythic+ group finder

### Current State
AzerothCore has complete LFG system:
- `src/server/game/DungeonFinding/LFGMgr.cpp`
- Supports 5-man dungeons
- Has raid browser (not queue-based)

### Effects
- Easier group finding
- Faster dungeon/raid access
- Cross-guild cooperation

### Effort Analysis
| Component | Effort | Complexity |
|-----------|--------|------------|
| Raid finder queue | 3-4 weeks | High |
| Mythic dungeon LFG | 2-3 weeks | Medium |
| M+ group finder | 3-4 weeks | High |
| Difficulty requirements | 1-2 weeks | Medium |
| Gear check integration | 1 week | Low |

**Total Estimated Effort:** 10-14 weeks

### Impact Assessment
- Dramatically easier grouping
- Higher dungeon/raid participation
- Better for casual players

### Relations
- **Dependencies:** Mythic+ system
- **Synergies:** 
  - Scalable raids
  - Mythic+ rating (matchmaking)
- **Conflicts:** Traditional guild raiding

### Benefits
✅ Accessibility improvement
✅ Higher participation rates
✅ Uses existing LFG framework
✅ Retail-like experience

### Disadvantages
❌ Complex queuing logic
❌ Balance concerns (gear checks)
❌ May reduce guild value
❌ Potential for toxic behavior

### 3.3.5a Compatibility
**✅ FULLY COMPATIBLE**
- LFG system exists
- Can extend existing code
- UI works natively

### Server/Client Changes
| Layer | Changes Required |
|-------|------------------|
| Server C++ | LFGMgr extensions |
| Database | Queue data, requirements |
| Eluna | Queue event hooks |
| Client | None (uses native UI) |
| Addon | **Optional** enhanced UI |

### Rating: ⭐⭐⭐⭐ (4/5)
**Priority: MEDIUM** - Good QoL, uses existing systems

---

## 11. Player and Guild Housing

### Overview
Personal/guild phased areas where players can:
- Place furniture/decorations
- Display achievements/trophies
- Host events
- Store items (guild bank extension)

### Effects
- Personal progression display
- Gold sink
- Social gathering spaces

### Effort Analysis
| Component | Effort | Complexity |
|-----------|--------|------------|
| Phased instancing | 4-6 weeks | Very High |
| Furniture placement system | 4-6 weeks | Very High |
| Housing zones/maps | 2-4 weeks | High |
| Permission system | 2-3 weeks | Medium |
| Furniture items | 2-3 weeks | Medium |
| Addon UI | 4-6 weeks | High |

**Total Estimated Effort:** 18-28 weeks

### Impact Assessment
- Major feature addition
- Strong gold sink
- Player retention driver

### Relations
- **Dependencies:** Addon Protocol
- **Synergies:** 
  - Achievement display
  - Guild features
  - Gold economy
- **Conflicts:** Performance concerns

### Benefits
✅ Unique feature
✅ Strong player retention
✅ Gold sink
✅ Social space
✅ Creative outlet

### Disadvantages
❌ Massive development effort
❌ Needs custom zones/models (client patches)
❌ Performance overhead
❌ Furniture asset creation
❌ Complex permission system

### 3.3.5a Compatibility
**⚠️ PARTIALLY COMPATIBLE**
- Phasing: ✅ Supported
- Furniture spawning: ✅ GameObjects
- Custom zones: ❌ Requires client patches
- Placement UI: ❌ Addon only
- Object storage: ✅ Server-side

### Server/Client Changes
| Layer | Changes Required |
|-------|------------------|
| Server C++ | Housing manager, phase system |
| Database | Housing data, furniture positions |
| Eluna | Placement scripts |
| Client | **MPQ patches** for zones/models |
| Addon | **Placement UI** (required) |

### Rating: ⭐⭐ (2/5)
**Priority: LOW** - Massive effort, client patches needed

---

## 12. Phased Dueling Arenas System

### Overview
Private, phased arenas for:
- 1v1 duels
- Practice matches
- Tournament fights
- Custom rulesets

### Effects
- Fair dueling environment
- No world interference
- Custom match settings

### Effort Analysis
| Component | Effort | Complexity |
|-----------|--------|------------|
| Arena instancing | 2-3 weeks | Medium |
| Matchmaking | 2-3 weeks | Medium |
| Custom rules engine | 2-3 weeks | High |
| Spectator integration | 1-2 weeks | Medium |
| Rating/ranking | 1-2 weeks | Medium |

**Total Estimated Effort:** 8-13 weeks

### Impact Assessment
- PvP engagement
- Fair competition
- Tournament hosting

### Relations
- **Dependencies:** Arena Spectator (for watching)
- **Synergies:** 
  - Season rankings
  - PvP gear rewards
  - Tournament system
- **Conflicts:** None

### Benefits
✅ Fair dueling
✅ No world interference
✅ Tournament ready
✅ Spectator support possible

### Disadvantages
❌ May split world PvP population
❌ Queue times for matches
❌ Ruleset complexity

### 3.3.5a Compatibility
**✅ FULLY COMPATIBLE**
- Can use existing arena infrastructure
- Phasing is server-side
- No client changes needed

### Server/Client Changes
| Layer | Changes Required |
|-------|------------------|
| Server C++ | Arena manager extensions |
| Database | Match history, ratings |
| Eluna | Rule scripts |
| Client | None |
| Addon | **Optional** match finder |

### Rating: ⭐⭐⭐⭐ (4/5)
**Priority: MEDIUM** - Good PvP feature, reasonable effort

---

## Final Priority Rankings

### Tier 1: Do First (Foundational)
| System | Rating | Effort | Why |
|--------|--------|--------|-----|
| Performance Optimization | ⭐⭐⭐⭐⭐ | 6-12w | Enables everything else |
| Addon Protocol (standardize) | ⭐⭐⭐⭐⭐ | 2-4w | Already done, needs docs |
| Mythic+ Rating | ⭐⭐⭐⭐⭐ | Done | Already implemented |

### Tier 2: High Value, Moderate Effort
| System | Rating | Effort | Why |
|--------|--------|--------|-----|
| Dynamic World Events | ⭐⭐⭐⭐ | 8-12w | Community engagement |
| Raid/Mythic Finder | ⭐⭐⭐⭐ | 10-14w | Accessibility |
| Pet/Mount Collection | ⭐⭐⭐⭐ | 8-13w | Collector motivation |
| Phased Dueling Arenas | ⭐⭐⭐⭐ | 8-13w | PvP scene |

### Tier 3: Good Features, Consider Later
| System | Rating | Effort | Why |
|--------|--------|--------|-----|
| AOE Loot Smart Filtering | ⭐⭐⭐⭐ | 4-6w | Nice QoL |
| Cross-System Integration | ⭐⭐⭐⭐ | 7-11w | Long-term investment |

### Tier 4: Complex, Consider Carefully
| System | Rating | Effort | Why |
|--------|--------|--------|-----|
| Mythic+ Spectator | ⭐⭐⭐ | 13-19w | Complex, niche audience |
| Scalable Raid System | ⭐⭐⭐ | 15-24w | Enormous testing burden |
| Player/Guild Housing | ⭐⭐ | 18-28w | Client patches needed |

---

## Recommended Implementation Order

1. **Performance Optimization** (Foundation)
2. **Dynamic World Events** (Engagement)
3. **Raid/Mythic Finder** (Accessibility)
4. **AOE Loot Smart Filtering** (QoL)
5. **Phased Dueling Arenas** (PvP)
6. **Pet/Mount Collection** (Collectors)
7. **Cross-System Integration** (Technical debt)
8. **Mythic+ Spectator** (Community)
9. **Scalable Raid System** (Long-term)
10. **Player Housing** (If resources permit)

---

## Quick Reference: Client Addon Requirements

| System | Addon Required? | Addon Complexity |
|--------|-----------------|------------------|
| Performance Optimization | ❌ No | N/A |
| Addon Protocol | ✅ AIO (exists) | Low |
| Cross-System Integration | ⚠️ Optional | Low |
| Mythic+ Spectator | ✅ Yes | High |
| AOE Loot Filtering | ⚠️ Optional | Medium |
| Mythic+ Rating | ⚠️ Optional | Low |
| Scalable Raid System | ⚠️ Optional | Medium |
| Pet/Mount Collection | ✅ Yes | Medium |
| Dynamic World Events | ⚠️ Optional | Low |
| Raid/Mythic Finder | ❌ No (native UI) | N/A |
| Player Housing | ✅ Yes | Very High |
| Phased Dueling | ⚠️ Optional | Low |

---

## Appendix: Existing Code References

### AIO Addon Protocol
- Server: `Custom/Eluna scripts/AIO.lua`
- Client: `Custom/Client addons needed/AIO_Client/AIO.lua`
- Example usage: DC-ItemUpgrade addon

### Mythic+ System
- Core: `src/server/scripts/DC/MythicPlus/`
- Manager: `MythicPlusRunManager.cpp`
- Constants: `MythicPlusConstants.h`

### LFG/Dungeon Finder
- Core: `src/server/game/DungeonFinding/`
- Manager: `LFGMgr.cpp`
- Queue: `LFGQueue.cpp`

### Arena Spectator (Base for Mythic+ Spectator)
- Header: `src/server/game/ArenaSpectator/ArenaSpectator.h`
- Uses addon messages with structured data

### World State (Base for Events)
- Core: `src/server/game/World/WorldState.cpp`
- Example: Sun's Reach Reclamation progression

---

*Document prepared for DarkChaos-255 development planning*
