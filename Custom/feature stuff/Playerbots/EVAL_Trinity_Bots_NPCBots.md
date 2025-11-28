# Trinity-Bots (NPCBots) Evaluation
## By trickerer - github.com/trickerer/Trinity-Bots

**Document Type:** Pre-Discussion Technical Analysis  
**Created:** November 2025  
**Purpose:** Detailed evaluation for DarkChaos-255 integration  
**NO CODE - Discussion Document Only**

---

## Project Overview

**Repository:** https://github.com/trickerer/Trinity-Bots  
**Version (Nov 2025):** v5.4.511a  
**License:** GPL-2.0  
**Primary Maintainer:** trickerer (single developer)

### Repository Statistics
| Metric | Value |
|--------|-------|
| Commits | 770 |
| Contributors | 7 |
| Stars | 533 |
| Forks | 172 |
| Open Issues | 18 |
| Update Schedule | Every Saturday ~05:00 AM UTC |

---

## 1. What Are NPCBots?

NPCBots are **NPC companions** (creatures) that can be hired by players to assist in gameplay. Unlike "playerbots" which simulate player characters, NPCBots are creatures with player-like abilities and gear.

### Core Concept
```
Player → Hires → NPCBot (Creature)
                   ├── Has player class abilities
                   ├── Can equip gear
                   ├── Follows player
                   ├── Has AI for combat/healing/tanking
                   └── Stored as NPC, not character
```

### Pre-Made Bots
The system includes **312 pre-made NPCBots** in a fresh install, covering all standard WoW classes plus unique extra classes.

---

## 2. Unique Features

### Warcraft 3 Extra Classes
NPCBots includes custom classes inspired by Warcraft 3 heroes:

| Class | Role | Description |
|-------|------|-------------|
| **Blademaster** | Melee DPS | WC3-style orc blademaster |
| **Obsidian Destroyer** | Caster | Mana-burning construct |
| **Archmage** | Caster | Enhanced mage abilities |
| **Dreadlord** | Tank/DPS | Vampire-like abilities |
| **Spell Breaker** | Anti-caster | Magic disruption |
| **Dark Ranger** | Ranged DPS | Undead archer |
| **Necromancer** | Caster | Pet summoner |
| **Sea Witch** | Caster | Water/frost themed |
| **Crypt Lord** | Tank | Nerubian tank |

### Other Unique Features
- **Wander System**: Bots can explore the world independently
- **Formation System**: Position bots in tactical formations
- **Vehicle Support**: Bots can use vehicles (siege, flying, etc.)
- **Transmog System**: Apply transmog to bot equipment
- **Bot Gear Window**: In-game UI for managing bot equipment
- **Role Assignment**: Set bots as Tank/DPS/Healer/Off-roles

---

## 3. Installation Process

### Requirements
1. TrinityCore or AzerothCore source code
2. Git for patch application
3. C++ compiler (Visual Studio, GCC, Clang)
4. MySQL/MariaDB database

### Installation Steps

**Step 1: Apply Patch**
- Download `NPCBots.patch` from repository
- Apply to AzerothCore source
- Patch modifies: src/server/, sql/, conf/

**Step 2: Compile**
- Full recompile of worldserver required
- No special CMake flags needed
- Patch integrates directly into build

**Step 3: Database**
- Run world database SQLs
- Run characters database SQLs
- Creates tables: `characters_npcbot*`, `creature_template_npcbot_extras`, etc.

**Step 4: Configuration**
- Edit `worldserver.conf`
- NPCBot-specific settings in dedicated section
- Optional: Install NetherBot addon for enhanced UI

### Addon Support
**NetherBot** by NetherstormX provides:
- Enhanced bot management UI
- Bot stats display
- Equipment management interface
- Accessible at: github.com/NetherstormX/NetherBot

---

## 4. Update Process

### Weekly Update Schedule
trickerer maintains a strict weekly update schedule:
- **Day:** Every Saturday
- **Time:** ~05:00 AM UTC+0
- **Content:** Merge with upstream AC/TC + bug fixes + enhancements

### Update Tracking
The README shows last update status:
```
AC: 22 Nov 2025, commit 336bc5794a
TC: [corresponding TC commit]
```

---

## 4.1 Detailed Patch Update Procedure

### ⚠️ YES, MANUAL PATCH CHECKING IS REQUIRED ⚠️

Since NPCBots uses `.patch` files rather than a module or fork, updates require manual intervention.

### Two Installation Options

#### Option A: Pre-Patched Repository (RECOMMENDED)
trickerer maintains pre-patched repositories that are ready to use:
- **AzerothCore:** `https://github.com/trickerer/AzerothCore-wotlk-with-NPCBots`
- **TrinityCore:** `https://github.com/trickerer/TrinityCore-3.3.5-with-NPCBots`

**Update Process (Pre-Patched):**
```bash
cd AzerothCore-wotlk-with-NPCBots
git pull
# Recompile
# Apply new SQL updates if any
```

**Pros:** Simplest approach, maintainer handles merge conflicts  
**Cons:** You're dependent on trickerer's repo, not your own fork

#### Option B: Manual Patch Application
Apply patch to your own AC source:

```bash
# Clone fresh AC
git clone https://github.com/azerothcore/azerothcore-wotlk.git --depth 1
git clone https://github.com/trickerer/Trinity-Bots.git

# Copy and apply patch
cp Trinity-Bots/AC/NPCBots.patch azerothcore-wotlk/
cd azerothcore-wotlk
patch -p1 < NPCBots.patch
```

**⚠️ IMPORTANT:** `git apply` may not work! Use `patch -p1 < NPCBots.patch`

### What Happens on Each Update

| Week | Action Required | Difficulty |
|------|-----------------|------------|
| Normal week | Pull + recompile + SQL | LOW |
| AC changes patched files | Resolve conflicts | MEDIUM |
| Major AC restructure | Wait for trickerer's fix | NONE (wait) |
| NPCBots feature update | Apply new SQL updates | LOW |

### Checking Updates Each Week

**Recommended Workflow:**
1. **Saturday morning:** Check Trinity-Bots repo for new release
2. **Review CHANGELOG:** Look for breaking changes or new SQL
3. **Check AC commit:** Compare with your current AC version
4. **Backup before update:** Always backup before patching
5. **Test on dev server:** Verify before production

### Conflict Scenarios

**Common Conflict Types:**
```
Context mismatch in:
├── src/server/game/AI/
├── src/server/game/Entities/
├── src/server/game/Handlers/
├── src/server/scripts/
└── sql/
```

**Resolution Options:**
1. **Wait for Saturday:** trickerer usually resolves within a week
2. **Manual fix:** Adjust patch hunks for changed context
3. **Report issue:** File GitHub issue for complex conflicts

### SQL Update Tracking

NPCBot SQL files are organized in:
```
sql/Bots/
├── 1_world_bot_appearance.sql
├── 2_world_bot_extras.sql
├── 3_world_bots.sql
├── 4_world_generate_bot_equips.sql
├── 5_world_botgiver.sql
├── characters_bots.sql
└── updates/
    ├── db_auth/
    ├── db_characters/
    └── db_world/
```

**Update Application:**
- Check `updates/` folder for new files each week
- Apply in filename order
- Or use provided `merge_sqls_...` scripts

---

### Update Procedure for Server Operators

**Regular Update:**
1. `git pull` latest NPCBots
2. Re-apply patch (or use git stash/pop strategy)
3. Recompile worldserver
4. Apply any new SQL updates
5. Restart server

**Handling Merge Conflicts:**
Since NPCBots is a patch, conflicts can occur when:
- AC changes files that NPCBots modifies
- Structure changes in AC headers/classes

**Conflict Resolution:**
- Usually straightforward (context changes)
- trickerer resolves major conflicts in weekly updates
- Community can report conflicts via GitHub issues

---

## 5. Advantages

### Stability
- Single maintainer ensures consistent quality
- 770 commits = mature, well-tested codebase
- Predictable weekly updates
- Low issue count (18 open)

### Simplicity
- Patch-based = no fork dependency
- Can use standard AzerothCore
- Focused feature set (not bloated)
- Clear documentation

### Unique Content
- WC3 extra classes not available elsewhere
- Pre-made bots for immediate use
- Formation/wander systems

### AC Compatibility
- Weekly sync with upstream AC
- Max 7-day desync window
- Maintainer actively tracks AC changes

### Performance
- NPC-based = lower overhead than player simulation
- Designed for party/raid groups (1-40 bots)
- No world-scale population overhead

---

## 6. Disadvantages

### Single Point of Failure
- trickerer is sole maintainer
- If maintainer stops, project stalls
- Limited community contribution model

### Patch-Based Complexity
- Modifies core source directly
- Merge conflicts during AC updates
- Requires full recompile on every update
- Cannot use AC docker images directly

### Limited Scale
- Not designed for thousands of bots
- No "populate the world" feature
- Focused on player-hired companions only

### Feature Limitations
- Bots cannot quest independently
- No auction house trading
- No guild system for bots
- Cannot use existing alt characters as bots

### Learning Curve
- Extensive command system
- Many configuration options
- Bot management requires practice

---

## 7. Database Schema

### Key Tables
```
characters_npcbot
├── owner (player GUID)
├── entry (creature template entry)
├── roles (tank/dps/healer flags)
├── spec (talent specialization)
├── faction (bot faction)
└── [equipment slots]

characters_npcbot_group_member
├── group_id
└── member entry

characters_npcbot_transmog
├── entry
└── [slot-to-item mappings]

creature_template_npcbot_extras
├── entry
├── class
├── race
└── [visual options]
```

### DB Size Impact
- Minimal compared to playerbots
- No full character simulation
- Efficient creature-based storage

---

## 8. DarkChaos-255 Specific Considerations

### Level 255 Compatibility
**UNKNOWN - Requires Testing**

Concerns:
- Bot damage/health scaling formulas
- WC3 extra classes may have hardcoded stats
- Level cap assumptions in bot AI

Recommendations:
- Test bot combat at level 255
- Verify stat scaling works correctly
- Check if custom stat formulas apply

### Custom Content Integration
**Potential Issues:**
- Custom spells may not be recognized by bot AI
- WC3 classes may conflict with custom class entries
- Custom items may need bot equip logic

### DC System Interactions

| DC System | Compatibility | Notes |
|-----------|---------------|-------|
| Phased Duels | ✅ SAFE | NPCs don't initiate duels |
| M+ Spectator | ✅ SAFE | NPCs in instance work normally |
| AoE Loot | ⚠️ TEST | May need verification for loot credit |
| Custom Spells | ⚠️ TEST | Bot AI may not use custom abilities |
| Custom Instances | ⚠️ TEST | Boss scripts may need awareness |

### Creature Template Conflicts
NPCBots uses creature entries in the 70000+ range:
- Check for conflicts with DC custom creatures
- Reserve entry range if needed
- Document used entry IDs

---

## 9. Command Reference Summary

### Essential Commands
| Command | Description |
|---------|-------------|
| `.npcbot hire` | Hire targeted npcbot |
| `.npcbot dismiss` | Dismiss a bot |
| `.npcbot spawn` | Spawn a bot for hiring |
| `.npcbot info` | Show bot information |
| `.npcbot set role` | Set bot role (tank/dps/heal) |
| `.npcbot command follow` | Set follow mode |
| `.npcbot command stay` | Set stay mode |
| `.npcbot equipment show` | Open gear window |

### Management Commands
| Command | Description |
|---------|-------------|
| `.npcbot summon` | Summon all owned bots |
| `.npcbot unsummon` | Unsummon all bots |
| `.npcbot recall` | Teleport bots to player |
| `.npcbot revive` | Revive dead bots |

### Configuration Commands
| Command | Description |
|---------|-------------|
| `.npcbot formation` | Set bot formation |
| `.npcbot distance` | Set follow distance |
| `.npcbot vehicle` | Vehicle-related commands |
| `.npcbot wander` | Wander mode settings |

---

## 10. Risk Assessment

### Integration Risks

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Patch conflicts with AC updates | Medium | Medium | Wait for Saturday sync |
| Level 255 scaling issues | Medium | Unknown | Test environment |
| Single maintainer abandonment | High | Low | Monitor project activity |
| WC3 class entry conflicts | Low | Low | Document entry ranges |
| Performance at scale | Low | Low | Not designed for scale |

### Long-term Maintenance
- **Positive:** Consistent weekly updates for years
- **Risk:** Single maintainer dependency
- **Mitigation:** Fork if needed, code is GPL-2.0

---

## 11. Verdict for DarkChaos-255

### Suitability Score: 7.5/10

**Good Fit For:**
- Party/raid companion system
- Unique WC3 class experience
- Stable, predictable updates
- Staying close to upstream AC

**Not Good Fit For:**
- Populating world with thousands of bots
- Using existing alt characters as bots
- Fully autonomous bot questing/trading

### Recommendation
**Conditionally Recommended** for DarkChaos-255 with the following caveats:
1. Test level 255 compatibility thoroughly
2. Document creature entry usage
3. Verify custom content interaction
4. Plan for AC update merge process

### Testing Priority
1. Level 255 stat scaling
2. Combat with DC custom content
3. Instance behavior
4. Performance with target bot count

---

## 12. Resources

- **Repository:** https://github.com/trickerer/Trinity-Bots
- **README/Manual:** Extensive documentation in repository
- **Issues:** https://github.com/trickerer/Trinity-Bots/issues
- **Discussions:** https://github.com/trickerer/Trinity-Bots/discussions
- **Addon (NetherBot):** https://github.com/NetherstormX/NetherBot

---

*This is a pre-discussion document. Hands-on testing in a DarkChaos-255 test environment is required before implementation decisions.*
