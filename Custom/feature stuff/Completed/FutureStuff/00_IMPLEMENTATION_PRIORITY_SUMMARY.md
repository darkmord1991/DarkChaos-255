# DarkChaos-255 Feature Implementation Priority Summary

**Created:** November 27, 2025  
**Version:** 3.0  
**Server Type:** WotLK 3.3.5a AzerothCore Funserver (Level 255)

---

## Executive Summary

This document provides implementation rankings for **30 proposed features** based on:
- **Player Impact** - How much players will benefit/enjoy
- **Development Effort** - Time and complexity to implement
- **Integration Fit** - How well it fits existing DarkChaos systems
- **Community Demand** - Based on private server feedback and retail trends
- **Already Implemented** - Features to skip or enhance

---

## Current System Inventory

### ✅ Existing Custom Features (ALREADY IMPLEMENTED)

| Feature | Status | Location | Notes |
|---------|--------|----------|-------|
| **Mythic+ System** | ✅ Complete | `DC/MythicPlus/` | Death budgets, affixes, keystones, timer, vault, statistics |
| **Item Upgrade System** | ✅ Complete | `DC/ItemUpgrades/` | Tiers, tokens, heirloom support, transmutation, synthesis |
| **Seasonal System** | ✅ Complete | `DC/Seasons/` | Cross-system seasons, rewards, HLBG integration |
| **HLBG (Hinterland BG)** | ✅ Complete | `DC/HinterlandBG/` | Open-world PvP zone with affixes, queue, rewards |
| **Dungeon Quest System** | ✅ Complete | `DC/DungeonQuests/` | Daily/weekly dungeon quests, master follower |
| **Prestige System** | ✅ Complete | `DC/Prestige/` | Alt bonuses, challenges, prestige spells |
| **Hotspot XP System** | ✅ Complete | `DC/Hotspot/` | Dynamic XP zones, buff system |
| **Battle for Gilneas** | ✅ Complete | `DC/Gilneas/` | Custom battleground |
| **AOE Loot** | ✅ Complete | `DC/ac_aoeloot.cpp` | Nearby corpse merging, gold auto-credit |
| **Challenge Modes** | ✅ Complete | `DC/ChallengeMode/` | Custom challenge mode auras |
| **Heirloom Scaling** | ✅ Complete | `DC/heirloom_scaling_255.cpp` | Extended to level 255 |
| **Level 255 Content** | ✅ Complete | Various | Custom scaling, stat tables |
| **LuaC Validation** | ✅ Complete | `apps/git_tools/` | Pre-push Lua syntax checking |
| **AIO Addon Framework** | ✅ Complete | `DC/AIO/` | Server-client addon sync |
| **Cross-Faction BG** | ✅ Built-in | Core | CFBG queue support in BattlegroundQueue |
| **Transmogrification** | ✅ Via Module | mod-transmog | Standard transmog |
| **Custom Achievements** | ✅ Started | `DC/Achievements/` | Custom achievement framework |
| **Custom Flightpaths** | ✅ Complete | `DC/AC/` | Extended flightmasters |
| **Jadeforest Zone** | ✅ In Progress | `DC/Jadeforest/` | Custom zone with guards, flightmaster |
| **Map Extensions** | ✅ Complete | `DC/MapExtension/` | Custom map handling |

### 🔧 Modules Available (via AzerothCore)

These modules are mentioned in README.md or confirmed integrated:
- `mod-cfbg` - Cross-faction battlegrounds (integrated into core)
- `mod-transmog` - Transmogrification (integrated)
- `mod-eluna` - Lua scripting (integrated)

---

## Features NO LONGER NEEDED (Already Implemented)

The following proposals from the original list are **already implemented**:

| Original Proposal | Status | Notes |
|-------------------|--------|-------|
| ~~AOE Loot~~ | ✅ DONE | Custom `ac_aoeloot.cpp` with full features |
| ~~Prestige System~~ | ✅ DONE | Full system in `DC/Prestige/` |
| ~~Cross-Faction BG~~ | ✅ DONE | Built into core BattlegroundQueue |
| ~~Auction House Bot~~ | Available | Can use `mod-ah-bot` if needed |

---

## Implementation Priority Rankings (30 Features)

### Tier S - Critical (Immediate Impact, Low Effort)
| Rank | Feature | Effort | Impact | File |
|------|---------|--------|--------|------|
| S1 | Daily Login Rewards | Very Low | High | `16_DAILY_LOGIN.md` |
| S2 | Duel Reset System | Very Low | Medium | `17_DUEL_RESET.md` |
| S3 | Talent Loadouts | Low | High | `11_TALENT_LOADOUTS.md` |
| S4 | Phased Dueling Arenas | Low | Medium | `04_PHASED_DUELS.md` |
| S5 | AutoBalance Enhancement | Low | High | `05_AUTOBALANCE_ENHANCEMENT.md` |

### Tier A - High Priority (Strong Value)
| Rank | Feature | Effort | Impact | File |
|------|---------|--------|--------|------|
| A1 | Guild Housing System | High | Very High | `01_GUILD_HOUSING.md` |
| A2 | Weekend Events System | Low | High | `06_WEEKEND_EVENTS.md` |
| A3 | Collection Achievement System | Medium | High | `03_COLLECTION_SYSTEM.md` |
| A4 | World Boss System | Medium | High | `08_WORLD_BOSSES.md` |
| A5 | Raid Finder System | Medium | High | `15_RAID_FINDER.md` |
| A6 | Mentor/Apprentice System | Medium | High | `18_MENTOR_SYSTEM.md` |
| A7 | Dynamic World Events | Low | High | `19_DYNAMIC_EVENTS.md` |
| A8 | Achievement Points Shop | Low | Medium | `20_ACHIEVEMENT_SHOP.md` |

### Tier B - Medium Priority (Good Value)
| Rank | Feature | Effort | Impact | File |
|------|---------|--------|--------|------|
| B1 | Profession Overhaul | High | High | `07_PROFESSION_OVERHAUL.md` |
| B2 | Transmog Wardrobe System | Medium | Medium-High | `09_TRANSMOG_WARDROBE.md` |
| B3 | Timewalking Dungeons | Medium | Medium | `14_TIMEWALKING.md` |
| B4 | Bounty/Contract System | Medium | Medium | `21_BOUNTY_SYSTEM.md` |
| B5 | Reputation Overhaul | Medium | Medium | `22_REPUTATION_OVERHAUL.md` |
| B6 | Smart Loot System | High | Medium | `23_SMART_LOOT.md` |
| B7 | Mount Collection Journal | Medium | Medium | `24_MOUNT_JOURNAL.md` |
| B8 | Pet Collection System | Medium | Low-Medium | `25_PET_COLLECTION.md` |

### Tier C - Long-term (Nice to Have)
| Rank | Feature | Effort | Impact | File |
|------|---------|--------|--------|------|
| C1 | Player Housing (Solo) | Very High | Medium | `12_PLAYER_HOUSING.md` |
| C2 | Scalable Raid System | High | High | `26_SCALABLE_RAIDS.md` |
| C3 | Custom Dungeon Creation | Very High | High | `27_CUSTOM_DUNGEON.md` |
| C4 | Tournament System | High | Medium | `28_TOURNAMENT_SYSTEM.md` |
| C5 | Seasonal Leaderboards | Medium | Medium | `29_LEADERBOARDS.md` |
| C6 | Advanced Token Economy | Medium | High | `30_TOKEN_ECONOMY.md` |

### Tier D - Deferred (Complex/Low Priority)
| Rank | Feature | Effort | Impact | Notes |
|------|---------|--------|--------|-------|
| D1 | Custom Class Specs | Very High | Very High | NOT RECOMMENDED |
| D2 | Pet Battles Full | Very High | Low | NOT RECOMMENDED |
| D3 | Archaeology System | High | Low | NOT RECOMMENDED |

---

## Quick Implementation Wins (< 1 Week Each)

| Feature | Source | Effort | Notes |
|---------|--------|--------|-------|
| **Daily Login Rewards** | Custom Eluna | 2-3 days | Simple reward tracking |
| **Duel Reset** | `mod-duel-reset` | 1 day | Plug-and-play module |
| **Weekend XP Bonus** | `mod-weekendbonus` | 1 day | Simple config |
| **Phased Duels** | Custom Eluna | 2 days | Phase management |
| **Talent Loadouts** | Custom Eluna | 1 week | Save/load talents |
| **Dynamic Events** | Extend existing | 1 week | Bonus multipliers |
| **Achievement Shop** | Custom NPC | 3 days | Spend achievement points |

---

## Complete Feature List (30 Proposals)

| # | Feature | File | Effort | Priority | Status |
|---|---------|------|--------|----------|--------|
| 01 | Guild Housing System | `01_GUILD_HOUSING.md` | High | A1 | Update |
| 02 | ~~AOE Loot System~~ | - | - | - | ✅ DONE |
| 03 | Collection Achievement System | `03_COLLECTION_SYSTEM.md` | Medium | A3 | Update |
| 04 | Phased Dueling Arenas | `04_PHASED_DUELS.md` | Low | S4 | Update |
| 05 | AutoBalance Enhancement | `05_AUTOBALANCE_ENHANCEMENT.md` | Low | S5 | Update |
| 06 | Weekend Events System | `06_WEEKEND_EVENTS.md` | Low | A2 | Update |
| 07 | Profession Overhaul | `07_PROFESSION_OVERHAUL.md` | High | B1 | Update |
| 08 | World Boss System | `08_WORLD_BOSSES.md` | Medium | A4 | Update |
| 09 | Transmog Wardrobe System | `09_TRANSMOG_WARDROBE.md` | Medium | B2 | Update |
| 10 | ~~Cross-Faction Grouping~~ | - | - | - | ✅ DONE |
| 11 | Talent Loadouts | `11_TALENT_LOADOUTS.md` | Low | S3 | Update |
| 12 | Player Housing (Solo) | `12_PLAYER_HOUSING.md` | Very High | C1 | Update |
| 13 | ~~Auction House Bot~~ | - | - | - | Module Available |
| 14 | Timewalking Dungeons | `14_TIMEWALKING.md` | Medium | B3 | Update |
| 15 | Raid Finder System | `15_RAID_FINDER.md` | Medium | A5 | Update |
| 16 | Daily Login Rewards | `16_DAILY_LOGIN.md` | Very Low | S1 | **NEW** |
| 17 | Duel Reset System | `17_DUEL_RESET.md` | Very Low | S2 | **NEW** |
| 18 | Mentor/Apprentice System | `18_MENTOR_SYSTEM.md` | Medium | A6 | **NEW** |
| 19 | Dynamic World Events | `19_DYNAMIC_EVENTS.md` | Low | A7 | **NEW** |
| 20 | Achievement Points Shop | `20_ACHIEVEMENT_SHOP.md` | Low | A8 | **NEW** |
| 21 | Bounty/Contract System | `21_BOUNTY_SYSTEM.md` | Medium | B4 | **NEW** |
| 22 | Reputation Overhaul | `22_REPUTATION_OVERHAUL.md` | Medium | B5 | **NEW** |
| 23 | Smart Loot System | `23_SMART_LOOT.md` | High | B6 | **NEW** |
| 24 | Mount Collection Journal | `24_MOUNT_JOURNAL.md` | Medium | B7 | **NEW** |
| 25 | Pet Collection System | `25_PET_COLLECTION.md` | Medium | B8 | **NEW** |
| 26 | Scalable Raid System | `26_SCALABLE_RAIDS.md` | High | C2 | **NEW** |
| 27 | Custom Dungeon Creation | `27_CUSTOM_DUNGEON.md` | Very High | C3 | **NEW** |
| 28 | Tournament System | `28_TOURNAMENT_SYSTEM.md` | High | C4 | **NEW** |
| 29 | Seasonal Leaderboards | `29_LEADERBOARDS.md` | Medium | C5 | **NEW** |
| 30 | Advanced Token Economy | `30_TOKEN_ECONOMY.md` | Medium | C6 | **NEW** |

---

## Synergy Matrix

### Best Integration Candidates

| New Feature | Integrates With | Synergy Notes |
|-------------|-----------------|---------------|
| Guild Housing | Seasonal System | Season-exclusive decorations |
| World Bosses | Mythic+ System | M+ tokens from world bosses |
| Collection System | Item Upgrade | Track upgraded items |
| Wardrobe | Transmogrification | Extend existing system |
| Daily Login | Seasonal System | Seasonal daily bonuses |
| Timewalking | Mythic+ | Timewalking keystones |
| Mentor System | Prestige System | Prestige players as mentors |
| Token Economy | Item Upgrades | Unified currency |
| Leaderboards | HLBG, Mythic+ | Track rankings |
| Dynamic Events | Hotspots | Event-based hotspots |

---

## Recommended Implementation Order

### Phase 1: Quick Wins (Weeks 1-2)
1. ✅ AOE Loot - **ALREADY DONE**
2. Implement Daily Login Rewards (`16_DAILY_LOGIN.md`)
3. Deploy `mod-duel-reset` (`17_DUEL_RESET.md`)
4. Create Achievement Points Shop (`20_ACHIEVEMENT_SHOP.md`)
5. Add Dynamic World Events (`19_DYNAMIC_EVENTS.md`)

### Phase 2: Core Features (Weeks 3-6)
1. Implement Talent Loadouts (`11_TALENT_LOADOUTS.md`)
2. Begin Guild Housing development (`01_GUILD_HOUSING.md`)
3. Implement World Boss System (`08_WORLD_BOSSES.md`)
4. Create Collection Achievement framework (`03_COLLECTION_SYSTEM.md`)

### Phase 3: Enhancement (Weeks 7-10)
1. Complete Guild Housing
2. Extend Wardrobe/Transmog system (`09_TRANSMOG_WARDROBE.md`)
3. Implement Timewalking (2 dungeons initially) (`14_TIMEWALKING.md`)
4. Mentor/Apprentice System (`18_MENTOR_SYSTEM.md`)

### Phase 4: Advanced (Weeks 11-16)
1. Profession Overhaul (`07_PROFESSION_OVERHAUL.md`)
2. Scalable Raid System (`26_SCALABLE_RAIDS.md`)
3. Tournament System (`28_TOURNAMENT_SYSTEM.md`)
4. Advanced Token Economy (`30_TOKEN_ECONOMY.md`)

---

## Resource Requirements

### Development Skills Needed
- C++ (AzerothCore module development)
- Lua (Eluna scripting)
- SQL (Database schema)
- Lua (Client addon development via AIO)
- DBC/DB2 editing (some features)

### Estimated Team Allocation
| Phase | Backend Dev | Addon Dev | QA/Testing |
|-------|-------------|-----------|------------|
| Phase 1 | 1 week | 0 | 2 days |
| Phase 2 | 4 weeks | 1 week | 1 week |
| Phase 3 | 3 weeks | 2 weeks | 1 week |
| Phase 4 | 4 weeks | 2 weeks | 2 weeks |

---

## Risk Assessment

### ❌ Features to AVOID (Low ROI)
| Feature | Reason |
|---------|--------|
| Custom Class Specs | Extremely complex, balance nightmare |
| Pet Battles Full | Requires extensive client modifications |
| Archaeology System | High effort, low player demand |

### ⚠️ High Risk Features
| Feature | Risk | Mitigation |
|---------|------|------------|
| Player Housing | Performance, DB size | Phase implementation |
| Custom Dungeons | Content creation time | Reuse existing ADTs |
| Scalable Raids | Balance testing | Gradual rollout |

### ✅ Low Risk Features
| Feature | Reason |
|---------|--------|
| Daily Login | Simple, proven pattern |
| Duel Reset | Existing module |
| Talent Loadouts | Database + UI only |
| Achievement Shop | Simple NPC vendor |

---

## Community Feedback Sources

Based on research from:
- ChromieCraft community discussions
- WoW-Mania forums
- Warmane player feedback
- r/wowservers community
- AC Discord feature requests
- StygianCore solo/LAN community

### Top Player Requests (Private Server Meta)

1. **Quality of Life** - Daily rewards, talent saves, fast leveling
2. **Progression Clarity** - Clear goals, visible progress, achievements
3. **Social Features** - Guild perks, housing, group content
4. **Endgame Variety** - World bosses, M+, multiple paths to gear
5. **Customization** - Appearances, titles, mounts, pets
6. **Seasonal Content** - Fresh experiences, limited rewards

---

## Next Steps

1. ✅ Review this priority summary
2. Start with Phase 1 Quick Wins (1-2 weeks)
3. Create detailed designs for Phase 2 features
4. Set up development/testing branch
5. Schedule bi-weekly progress reviews

---

**Document Maintainer:** Development Team  
**Last Updated:** November 27, 2025
**Version:** 3.0 - Updated with 30 features, marked already-implemented systems
