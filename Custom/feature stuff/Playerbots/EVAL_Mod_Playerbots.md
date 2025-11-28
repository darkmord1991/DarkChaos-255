# mod-playerbots Evaluation
## By mod-playerbots organization - github.com/mod-playerbots/mod-playerbots

**Document Type:** Pre-Discussion Technical Analysis  
**Created:** November 2025  
**Purpose:** Detailed evaluation for DarkChaos-255 integration  
**NO CODE - Discussion Document Only**

---

## Project Overview

**Repository:** https://github.com/mod-playerbots/mod-playerbots  
**Requires:** https://github.com/mod-playerbots/azerothcore-wotlk (Playerbot branch)  
**License:** AGPL-3.0  
**Maintainers:** Community-driven (multiple core contributors)

### Repository Statistics
| Metric | Value |
|--------|-------|
| Commits | 2,340 |
| Contributors | 65 |
| Stars | 563 |
| Forks | 295 |
| Open Issues | 150 |
| Open Pull Requests | 28 |
| Custom AC Fork Stars | 251 |
| Custom AC Fork Commits | 17,155 |

---

## 1. What Are Playerbots?

Playerbots are **AI-controlled player characters** that simulate real players. Unlike NPCBots (creatures), playerbots use actual character data and can perform most actions a human player could.

### Core Concept
```
Alt Character → AI System → Playerbot
                   ├── Full character with gear/talents
                   ├── Can quest, trade, join groups
                   ├── Appears as real player to others
                   ├── Uses character DB tables
                   └── Can be commanded or autonomous
```

### Bot Types
1. **Alt Bots:** Player's own alt characters controlled by AI
2. **Random Bots:** Server-generated AI players that populate the world

---

## 2. Key Features

### Player Simulation
| Feature | Details |
|---------|---------|
| Alt Characters | Use your own alts as party members |
| Random Bots | Auto-generated bots populate the world |
| Combat AI | Class-specific strategies for all situations |
| Raid Strategies | Boss-specific behaviors (Gruul, Magtheridon, etc.) |
| PvP/BGs | Bots participate in battlegrounds |
| Arena | Arena team support |

### Economy & World Interaction
| Feature | Details |
|---------|---------|
| Auction House | Bots can buy/sell on AH |
| Professions | Full profession support |
| Questing | Bots can complete quests |
| Guild System | Bots can form/join guilds |
| Trading | Trade items with other players/bots |
| Mail | Can send/receive mail |

### Scale & Performance
- Claims "excellent performance with thousands of bots"
- Thread safety improvements (Nov 2025)
- Designed for world population
- Configurable bot counts and behaviors

---

## 3. Critical Requirement: Custom AC Fork

### ⚠️ THIS IS THE MOST IMPORTANT CONSIDERATION ⚠️

mod-playerbots **DOES NOT WORK** with standard AzerothCore. It requires:

**Repository:** `mod-playerbots/azerothcore-wotlk` (Playerbot branch)

### Why Custom Fork Required?
- Core modifications for playerbot hooks
- Custom player update loops
- Modified group/party handling
- Extended character handling
- AI system integration points

### Fork Statistics
| Metric | Value |
|--------|-------|
| Commits | 17,155 |
| Stars | 251 |
| Forks | 216 |
| Open Issues | 4 |
| Open PRs | 2 |

---

## 3.1 Deep Dive: What Changes Does the Fork Contain?

### Analysis of Fork Modifications (November 2025)

Based on commit history analysis, the fork contains these types of changes:

#### Type 1: Standard AC Upstream Merges (LOW CRITICALITY)
These are regular AzerothCore fixes merged into the fork:
- `fix(DB/Gameobject): Set Everfrost Chip respawn timer`
- `fix(Core/Movement): Handle player-controlled vehicles on transports`
- `fix(Scripts/HoS): Remove custom Dark Matter speed calculation`
- `fix(Core/Handler): player can reclaim corpse regardless of phase`

**Assessment:** These are NOT blocking changes - they're just AC staying current.

#### Type 2: Playerbot-Specific Core Hooks (HIGH CRITICALITY)
These are the actual modifications that make playerbots work:
- `Core merge: Replace OnPlayerChat with OnPlayerCanUseChat` (Nov 23)
- Custom player update loop modifications
- Group/party handling extensions
- Character session hooks

**Assessment:** These are the BLOCKING changes - they modify core AC behavior.

#### Type 3: Merge Conflict Resolutions (MEDIUM CRITICALITY)
Evidence of ongoing maintenance challenges:
- `merge_conflict_fix` (Nov 24)
- `fix` commits after merges (Nov 23, Nov 24)
- `Revert "Core merge 17112025"` - Had to revert and redo a merge

**Assessment:** Shows the fork requires active maintenance to stay synced.

### Criticality Rating: 🔴 HIGH

The fork is **essential** for mod-playerbots to function. The changes are:

| Change Category | Quantity | Reversibility |
|-----------------|----------|---------------|
| Core hook modifications | ~10-20 files | Cannot be avoided |
| Script loader changes | ~5 files | Required for AI system |
| Player class extensions | ~15-20 files | Deep integration |
| Group/Party modifications | ~5-10 files | Required for bot parties |

### Alternative Modules That COULD Work Without Fork

| Module | Fork Required? | Functionality |
|--------|----------------|---------------|
| mod-eluna | NO (standard module) | Lua scripting engine |
| mod-transmog | NO | Transmogrification |
| mod-individual-progression | NO | Custom progression |
| mod-autobalance | NO | Instance scaling |
| **Trinity-Bots (NPCBots)** | NO (patch-based) | NPC companions |

### Conclusion on Fork Criticality
The custom fork is **non-negotiable** for mod-playerbots. There is no way to use this module with standard AzerothCore. The ~50+ modified core files cannot be backported as a simple module.

---

### Implications for DarkChaos-255
1. **Cannot use standard AC** - Must switch to custom fork
2. **AC Updates** - Depend on fork maintainers to merge upstream
3. **Build Process** - Modified build requirements
4. **Other Modules** - Must be compatible with modified core
5. **Custom Changes** - DC customizations must be ported to fork
6. **Eluna Scripts** - Should work, but needs verification
7. **Custom C++ Scripts** - May need adaptation for modified hooks

---

## 4. Installation Process

### Prerequisites
- Linux (Ubuntu recommended) or Windows or macOS
- Git
- C++ compiler
- MySQL/MariaDB
- **NOT standard AzerothCore**

### Installation Steps

**Step 1: Clone Custom AC Fork**
```
Clone: mod-playerbots/azerothcore-wotlk
Branch: Playerbot (NOT master)
```
This is fundamentally different from regular AC.

**Step 2: Add Module**
```
Clone mod-playerbots/mod-playerbots to modules/mod-playerbots
```

**Step 3: Build**
- CMake configuration
- Compile with module
- Extended compile time due to playerbot code

**Step 4: Database**
- Character database tables (ai_playerbot_*)
- World database additions
- Extensive schema changes

**Step 5: Configuration**
- `playerbots.conf.dist` → `playerbots.conf`
- Hundreds of configuration options
- Random bot generation settings
- Strategy configurations

### Docker Option
**Experimental** Docker support available:
- Pre-built images
- Docker Compose setup
- May simplify deployment

---

## 5. Update Process

### Community-Driven Updates
Unlike Trinity-Bots' predictable weekly schedule:

**Update Pattern:**
- Multiple commits per week
- Variable frequency
- Depends on community PRs
- No fixed schedule

### Recent Update Activity (Nov 2025)
| Date | Notable Updates |
|------|-----------------|
| Nov 24 | Hotfix: prevent crash on whisper 'logout' |
| Nov 23 | Core merge: Replace OnPlayerChat with OnPlayerCanUseChat |
| Nov 21 | Thread safety for group operations |
| Nov 21 | Fix movement flags while rooted |
| Nov 21 | Improved language detection |
| Nov 16 | Fly/follow improvements, water walking |
| Nov 15 | Eye of the Storm flag pickup fix |

### Syncing with Upstream AC
The custom fork must merge upstream AzerothCore changes:
1. mod-playerbots org merges AC master → Playerbot branch
2. Users pull updated fork
3. Rebuild with updated module

**Sync Lag Risk:** Unknown delay between AC update and fork sync

---

## 6. Advantages

### Feature Richness
- Most comprehensive playerbot solution
- Full player simulation
- Economic participation (AH, trading)
- World population capability

### Scale
- Designed for thousands of bots
- Performance optimizations
- Thread safety focus
- Can populate entire server

### Community
- 65 contributors = diverse expertise
- Active Discord server (discord.gg/NQm5QShwf9)
- Extensive wiki documentation
- 28 open PRs = active development

### Alt Character Use
- Use your own alts as party members
- No need to hire/manage NPCs
- Characters retain progression

### Raid/Dungeon Strategies
- Boss-specific AI behaviors
- Recent: Gruul's Lair, Magtheridon strategies
- Continuous improvement of encounters

---

## 7. Disadvantages

### Custom Fork Dependency
**This is the primary concern:**
- Cannot use standard AzerothCore
- All DC customizations must work with fork
- Fork sync with upstream is community-dependent
- Additional maintenance burden

### Complexity
- Hundreds of configuration options
- Complex installation process
- Steep learning curve
- Extensive database changes

### Issue Count
- 150 open issues (vs 18 for Trinity-Bots)
- 28 open PRs (backlog)
- Active but fragmented development

### Stability Concerns
- Hotfixes for crashes (Nov 24: whisper crash)
- Reverts of features (Nov 18: mount behavior reverted)
- More moving parts = more potential issues

### No Unique Classes
- Only standard WoW classes
- No WC3 extra classes like NPCBots

### Resource Requirements
- Higher memory per bot (full character simulation)
- More database queries
- CPU overhead for AI systems

---

## 8. Database Schema

### Key Tables (ai_playerbot_*)
```
ai_playerbot_names
├── Random bot name pool
└── Used for bot generation

ai_playerbot_texts
├── Bot chat/emote responses
└── Localization support

ai_playerbot_random_bots
├── Random bot tracking
└── Bot state persistence

ai_playerbot_equip_cache
├── Equipment caching
└── Performance optimization

ai_playerbot_rnd_pets
├── Random pet assignments
└── Hunter/warlock bots

ai_playerbot_[language]_texts
├── German, etc.
└── Localization
```

### Standard Character Tables
Playerbots use regular character tables:
- `characters`
- `character_inventory`
- `character_spell`
- `character_talent`
- etc.

### DB Size Impact
- Significant if running thousands of random bots
- Each bot = full character record
- Equipment, spells, talents all stored

---

## 9. DarkChaos-255 Specific Considerations

### Custom Fork Integration Challenge
**This is the critical blocker:**

Current DC setup uses standard AzerothCore. To use mod-playerbots:

1. **Fork Assessment:**
   - Compare mod-playerbots/azerothcore-wotlk with current DC base
   - Identify all DC custom modifications
   - Determine compatibility

2. **Migration Options:**
   - Option A: Port DC changes to playerbot fork
   - Option B: Port playerbot changes to DC fork
   - Option C: Maintain merged fork (complex)

3. **Ongoing Maintenance:**
   - Track both upstream AC AND playerbot fork
   - Merge changes from both sources
   - Significantly increased maintenance

### Level 255 Compatibility
**UNKNOWN - Requires Testing**

Concerns:
- Bot damage/health scaling
- Stat calculations for AI decisions
- Equipment evaluation algorithms
- Random bot generation at level 255

### DC System Interactions

| DC System | Compatibility | Notes |
|-----------|---------------|-------|
| Phased Duels | ⚠️ MEDIUM RISK | Bots are players, may trigger duel logic |
| M+ Spectator | ⚠️ TEST | Bot behavior in instanced content |
| AoE Loot | ⚠️ MEDIUM RISK | Loot distribution with bot party members |
| Custom Spells | ⚠️ TEST | Bot AI spell recognition |
| Custom Instances | ⚠️ TEST | Strategy system integration |

### Performance Concerns
- Thousands of full character simulations
- Additional DB queries per bot
- Memory footprint at scale
- CPU for AI decision-making

---

## 10. Configuration Highlights

### Bot Population
```
AiPlayerbot.MinRandomBots = number
AiPlayerbot.MaxRandomBots = number
AiPlayerbot.RandomBotMinLevel = 1
AiPlayerbot.RandomBotMaxLevel = 80 (or 255?)
```

### Behavior Settings
```
AiPlayerbot.RandomBotAutologin = 1
AiPlayerbot.BotActiveAlone = 0
AiPlayerbot.RandomBotAccounts = number
```

### Performance Tuning
```
AiPlayerbot.RandomBotUpdateInterval = ms
AiPlayerbot.MapWorkerThreads = number
AiPlayerbot.PlayerbotsPerUpdate = number
```

### Many More Options
- Guild settings
- PvP settings
- Dungeon/raid settings
- Economic settings
- Chat settings

---

## 11. Risk Assessment

### Integration Risks

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Custom fork incompatibility | HIGH | HIGH | Thorough pre-testing |
| DC customization porting | HIGH | CERTAIN | Budget significant time |
| Upstream sync delays | MEDIUM | MEDIUM | Monitor fork activity |
| Level 255 scaling | MEDIUM | UNKNOWN | Test environment |
| Performance at scale | MEDIUM | MEDIUM | Benchmarking |
| DC system conflicts | MEDIUM | MEDIUM | Systematic testing |

### Long-term Maintenance
- **Positive:** Active community, 65 contributors
- **Positive:** Regular commits and fixes
- **Risk:** Fragmented development (28 open PRs)
- **Risk:** Custom fork adds maintenance layer
- **Risk:** Community-driven = less predictable

---

## 12. Verdict for DarkChaos-255

### Suitability Score: 5.5/10

**Score lowered primarily due to custom fork requirement**

**Good Fit For:**
- World population with thousands of AI players
- Using alt characters as party members
- Full economic simulation
- Long-term investment in bot ecosystem

**Not Good Fit For:**
- Projects needing standard AC compatibility
- Simple companion systems
- Low-maintenance requirements
- Quick implementation

### Recommendation
**Not Recommended** for DarkChaos-255 without significant preparation:

1. **Custom fork is a major commitment**
   - All DC customizations must be validated
   - Ongoing dual-maintenance burden
   - Risk of incompatibility with future AC updates

2. **If world population is the goal:**
   - The feature set is unmatched
   - But the cost is substantial

3. **Alternative consideration:**
   - Trinity-Bots for companion functionality
   - mod-playerbots only if world population is essential

### Testing Requirements (If Proceeding)
1. Set up isolated test with mod-playerbots fork
2. Port DC customizations to test fork
3. Verify ALL DC systems work correctly
4. Benchmark performance with target bot count
5. Test level 255 compatibility thoroughly
6. Evaluate maintenance burden over time

---

## 13. Resources

- **Module Repository:** https://github.com/mod-playerbots/mod-playerbots
- **Custom AC Fork:** https://github.com/mod-playerbots/azerothcore-wotlk
- **Discord:** discord.gg/NQm5QShwf9
- **Wiki:** Available on GitHub
- **Issues:** https://github.com/mod-playerbots/mod-playerbots/issues

### Key Contributors to Watch
- Celandriel (hotfixes)
- hermensbas (core improvements)
- nl-saw (battleground fixes)
- kadeshar (codestyle, merges)
- noisiver (maintenance)

---

*This is a pre-discussion document. The custom fork requirement makes mod-playerbots a significant undertaking. Thorough evaluation and testing in an isolated environment is essential before any implementation decisions.*
