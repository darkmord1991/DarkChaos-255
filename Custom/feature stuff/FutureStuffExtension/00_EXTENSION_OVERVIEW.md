# DarkChaos-255 System Extensions Overview

**Analysis Date:** November 27, 2025  
**Scope:** Deep evaluation of existing DC systems for potential improvements  
**Reference:** `src/server/scripts/DC/` codebase analysis + AzerothCore ecosystem research

---

## Existing Systems Analyzed

| System | Files | Current State | Extension Potential |
|--------|-------|---------------|---------------------|
| **Mythic+** | 23 files | Full M+ with affixes, runs, vault | High |
| **Seasons** | 8 files | Generic season framework | High |
| **Item Upgrades** | 23 files | 3-tier heirloom progression | High |
| **Prestige** | 6 files | Alt bonuses, challenges | Medium |
| **AoE Loot** | 1 file (550+ lines) | Complete with leaderboard | Medium |
| **Hotspot XP** | 3 files (3200+ lines) | Zone-based XP bonus | Medium |
| **Dungeon Quests** | 8 files | Daily/weekly dungeons | Medium |
| **HinterlandBG** | 26+ files | Custom battleground | Low |
| **Gilneas BG** | 2 files | Standard BG port | Low |
| **Achievements** | 1 file | DC achievement hooks | Medium |
| **Challenge Mode** | 5 files | Time-based challenges | High |

---

## Extension Categories

### Category A: System Enhancements (High Priority)
Extensions that improve core gameplay loop

1. **Mythic+ Extensions** - New affixes, scoring, tournaments
2. **Seasonal Rewards Enhancement** - Exclusive cosmetics, titles, mounts
3. **Item Upgrade Specialization** - Stat customization, proc systems
4. **Cross-System Integration** - Better interop between systems

### Category B: Quality of Life (Medium Priority)
Improvements to user experience

5. **AoE Loot Enhancement** - Pet/mount auto-loot, smart filtering
6. **Hotspot Improvements** - Events, stacking, zone chains
7. **Dungeon Quest Expansion** - Weekly objectives, bonus modes
8. **Prestige Path Diversification** - Multiple prestige trees

### Category C: Data & Analytics (Supporting)
Backend improvements for future features

9. **Seasonal Analytics Dashboard** - Player statistics tracking
10. **Leaderboard Framework** - Cross-system leaderboards
11. **Achievement Tracking Improvements** - Comprehensive tracking

---

## Extension Files Index

| File | System | Title | Priority |
|------|--------|-------|----------|
| 01 | Mythic+ | New Affixes System | S |
| 02 | Mythic+ | Tournament/Competitive Mode | A |
| 03 | Mythic+ | Scoring & Rating System | A |
| 04 | Seasons | Enhanced Rewards Framework | S |
| 05 | Seasons | Season Pass Implementation | A |
| 06 | Item Upgrades | Stat Customization | A |
| 07 | Item Upgrades | Proc & Effect System | A |
| 08 | Item Upgrades | Set Bonus Integration | B |
| 09 | Prestige | Multiple Prestige Paths | B |
| 10 | Prestige | Prestige Challenges Expansion | B |
| 11 | AoE Loot | Smart Filtering & Auto-Store | B |
| 12 | Hotspot | Event Integration | B |
| 13 | Hotspot | Zone Chains & Stacking | C |
| 14 | Dungeon Quests | Weekly Objective System | B |
| 15 | Cross-System | Unified Token Economy | A |

---

## Technical Observations

### Mythic+ System Strengths
- Well-architected affix handler interface (`IAffixHandler`)
- Comprehensive run manager with state tracking
- Vault reward generation with spec-based loot
- Death/wipe budget system
- HUD/AIO integration prepared

### Mythic+ System Gaps
- Only 8 affix types defined (retail has 20+)
- No score/rating system (raider.io-style)
- No dungeon-specific modifiers
- No seasonal affix rotation config
- No tournament/competitive mode

### Seasonal System Strengths
- Generic `SeasonalParticipant` interface
- Multi-system registration
- Player data isolation per system
- Event-driven transitions
- Carryover support

### Seasonal System Gaps
- No season pass/battle pass logic
- No visual theme support beyond banners
- Limited reward tier definitions
- No seasonal exclusive content flagging

### Item Upgrade System Strengths
- 3-tier progression (Leveling → Heroic → Heirloom)
- Dual currency (Tokens + Essence)
- 80-level heirloom scaling
- Season-aware upgrades
- Stat multiplier system

### Item Upgrade System Gaps
- Fixed stat increases (no customization)
- No proc/effect system
- No set bonus interaction
- No transmog integration
- No specialization paths

---

## Implementation Priority Matrix

| Priority | Extensions | Effort | Impact |
|----------|------------|--------|--------|
| **S-Tier** | Affixes, Seasonal Rewards | Medium | Very High |
| **A-Tier** | Scoring, Season Pass, Stat Custom | High | High |
| **B-Tier** | Proc System, Prestige Paths, Smart Loot | Medium | Medium |
| **C-Tier** | Analytics, Zone Chains | Low | Low |

---

## Cross-System Integration Opportunities

1. **M+ → Seasons**: Seasonal affix pools, exclusive M+ achievements per season
2. **M+ → Item Upgrades**: M+ completion tokens, dungeon-specific upgrade materials
3. **Seasons → Prestige**: Season-exclusive prestige paths or bonuses
4. **Hotspot → Seasons**: Seasonal hotspot themes with unique rewards
5. **AoE Loot → Item Upgrades**: Auto-pickup of upgrade materials
6. **Dungeon Quests → M+**: M+ completion counts for weekly objectives

---

## AzerothCore Module Ecosystem Research

### Available Community Modules (Integration Potential)
- `mod-transmog` - Already integrated, extend with wardrobe
- `mod-duel-reset` - Can integrate for PvP zones
- `mod-learn-spells` - Talent loadout support
- `mod-anticheat` - Security layer for competitive modes
- `mod-cfbg` - Already in core, cross-faction enabled

### Module Patterns to Apply
- Config-driven enable/disable
- Database persistence patterns
- Eluna hook compatibility
- AIO addon communication

---

## Next Steps

1. Review each extension file (01-15)
2. Identify quick wins (< 1 week implementation)
3. Plan phased rollout aligned with seasons
4. Create technical design docs for S-tier items
