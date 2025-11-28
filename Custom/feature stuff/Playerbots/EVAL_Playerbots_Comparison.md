# Playerbot Solutions Comparison
## Trinity-Bots (NPCBots) vs mod-playerbots

**Document Type:** Pre-Discussion Technical Analysis  
**Created:** November 2025  
**Updated:** November 28, 2025  
**Purpose:** Comparative evaluation for DarkChaos-255 integration  
**NO CODE - Discussion Document Only**

---

## Related Documents

- **[EVAL_Trinity_Bots_NPCBots.md](./EVAL_Trinity_Bots_NPCBots.md)** - Detailed Trinity-Bots evaluation
- **[EVAL_Mod_Playerbots.md](./EVAL_Mod_Playerbots.md)** - Detailed mod-playerbots evaluation
- **[EVAL_Additional_Bot_Systems.md](./EVAL_Additional_Bot_Systems.md)** - Other bot systems researched

---

## Executive Summary

This document compares two playerbot solutions for potential integration with DarkChaos-255:
1. **Trinity-Bots (NPCBots)** by trickerer - Patch-based NPC companion system
2. **mod-playerbots** - Module-based AI player simulation system

Both are fundamentally different approaches to "bots" in WoW private servers.

### Additional Systems Researched (See EVAL_Additional_Bot_Systems.md)

| System | Status | Viable for DC-255? |
|--------|--------|-------------------|
| cmangos/playerbots | Active | ❌ CMaNGOS only |
| celguar/mangosbot-bots | Moved to cmangos | ❌ MaNGOS only |
| ike3/mangosbot | Archived | ❌ Vanilla only |
| ZhengPeiRu21/mod-playerbots | Deprecated | ❌ Use mod-playerbots/mod-playerbots |
| eyeofstorm/mod-npc-bots | Archived | ❌ Incomplete (1 bot only) |
| mod-ollama-chat | Active | ✅ Enhancement for mod-playerbots |
| mod-player-bot-level-brackets | Active | ✅ Enhancement for mod-playerbots |
| MultiBot addon | Active | ✅ UI addon for mod-playerbots |
| NetherBot addon | Active | ✅ UI addon for Trinity-Bots |

**Conclusion from expanded research:** Only Trinity-Bots and mod-playerbots are viable for DarkChaos-255. All other systems are either for different cores, deprecated, or incomplete.

---

## 1. Fundamental Architecture Difference

### Trinity-Bots (NPCBots)
| Aspect | Details |
|--------|---------|
| **Type** | NPC-based companions |
| **Installation** | Patch applied to core source code |
| **Bots Are** | Creatures (NPCs) that follow players |
| **Character DB** | Uses creature tables, not character tables |
| **Persistence** | Stored in custom `characters_npcbot*` tables |

### mod-playerbots
| Aspect | Details |
|--------|---------|
| **Type** | Simulated player characters |
| **Installation** | Module + custom AzerothCore fork required |
| **Bots Are** | Actual player characters with AI |
| **Character DB** | Uses regular character tables + ai_playerbot tables |
| **Persistence** | Alt characters in standard character DB format |

### Key Distinction
- **NPCBots**: Bots are *creatures* with player-like abilities
- **Playerbots**: Bots are *characters* controlled by AI instead of a human

---

## 2. Installation Complexity Comparison

### Trinity-Bots
```
Complexity: MODERATE
├── Apply NPCBots.patch to AzerothCore source
├── Recompile entire core
├── Apply SQL to world/characters databases
├── Optional: Install NetherBot addon
└── Configure via worldserver.conf
```

**Pros:**
- Self-contained patch file
- No fork dependency
- Single maintainer ensures consistency

**Cons:**
- Modifies core source directly
- Patch conflicts during AC updates
- Requires full recompile on updates

### mod-playerbots
```
Complexity: HIGH
├── Clone mod-playerbots/azerothcore-wotlk (Playerbot branch)
│   └── NOT regular azerothcore/azerothcore-wotlk!
├── Add mod-playerbots to modules folder
├── Build with custom AC fork
├── Run extensive SQL scripts
├── Configure via playerbots.conf (hundreds of options)
└── Docker option available (experimental)
```

**Pros:**
- Module architecture (cleaner separation)
- Docker support for easier deployment
- More extensive configuration options

**Cons:**
- REQUIRES custom AzerothCore fork
- Cannot use standard AzerothCore
- More complex merge process for AC updates

---

## 3. Update Frequency & Maintenance

### Trinity-Bots
| Metric | Value |
|--------|-------|
| Update Schedule | Every Saturday ~05:00 AM UTC |
| Commits | 770 total |
| Contributors | 7 |
| Stars | 533 |
| Open Issues | 18 |
| Last Update (Nov 2025) | v5.4.511a |
| Update Pattern | Weekly merge with AC upstream |

**Update Predictability:** ⭐⭐⭐⭐⭐ (Highly predictable, weekly Saturday updates)

### mod-playerbots
| Metric | Value |
|--------|-------|
| Update Schedule | Continuous (multiple per week) |
| Commits | 2,340 total |
| Contributors | 65 |
| Stars | 563 |
| Open Issues | 150 |
| Open PRs | 28 |
| Update Pattern | Frequent, community-driven |

**Update Predictability:** ⭐⭐⭐ (Unpredictable, depends on community PRs)

---

## 4. Comprehensive Feature Sets

### 4.1 Trinity-Bots (NPCBots) - Full Feature List

#### Core Features
| Feature | Description |
|---------|-------------|
| **312 Pre-made NPCBots** | Fully configured bots ready to hire, all classes/races |
| **9 Extra WC3 Classes** | Blademaster, Archmage, Dreadlord, Spell Breaker, Dark Ranger, Necromancer, Sea Witch, Crypt Lord, Obsidian Destroyer |
| **Bot Hiring System** | Talk to bots in world or use Botgiver NPC (entry 70000) |
| **Follow System** | Stay, Follow, Walk, Hold Position with emote controls |
| **Combat AI** | Class-specific rotations, threat management, CC |
| **Role System** | Tank, Off-Tank, DPS, Heal, Ranged roles |
| **Formation System** | Tanks front, melee sides, ranged back; customizable distance |
| **Equipment System** | Equip player gear to bots, auto-equip, gear bank storage |
| **Talent System** | 30 specs per class, auto-progression |
| **Vehicle Support** | Bots use vehicles (Malygos, Oculus, ToC, ICC Gunship) |
| **Dungeon Support** | Full dungeon finder compatibility |
| **Raid Support** | Raid grouping, role assignment, target icons |
| **PvP Support** | Faction-based, BG support |
| **Gathering Roles** | Mining, Herbalism, Skinning (skill based on bot level) |
| **Looting Roles** | Auto-loot corpses for party |
| **Wander System** | Bots roam world autonomously when not owned |
| **Transmog Support** | Bots can display transmogged gear |
| **Console Commands** | Extensive `.npcbot` command system |
| **Target Icons** | Tank/DPS/Heal priority via raid icons |
| **Gossip Menu** | Right-click bot for full control menu |

#### Extra Classes Details (WC3-Inspired)
| Class | Rank | Level Bonus | Min Player Level | Unique Abilities |
|-------|------|-------------|------------------|------------------|
| Blademaster | Rare | +1 | 1 | Netherwalk, Mirror Image, Critical Strike, Bladestorm |
| Archmage | Rare | +1 | 20 | Blizzard, Water Elemental, Brilliance Aura |
| Dreadlord | Rareelite | +3 | 60 | Carrion Swarm, Sleep, Vampiric Aura, Infernal |
| Spell Breaker | Rare | +1 | 20 | Steal Magic, Feedback, Control Magic |
| Dark Ranger | Rareelite | +3 | 40 | Silence, Black Arrow, Drain Life, Charm |
| Necromancer | Elite | +2 | 20 | Raise Dead, Unholy Frenzy, Corpse Explosion, Cripple |
| Sea Witch | Rareelite | +3 | 1 | Forked Lightning, Frost Arrows, Mana Shield, Tornado |
| Crypt Lord | Rareelite | +3 | 1 | Impale, Spiked Carapace, Carrion Beetles, Locust Swarm |
| Obsidian Destroyer | Rareelite | +3 | 60 | Devour Magic, Shadow Blast, Drain/Replenish Mana |

#### Command Examples
```
.npcbot lookup 1              -- List all warrior bots
.npcbot spawn 70003           -- Spawn bot by ID
.npcbot add                   -- Hire targeted bot
.npcbot command follow        -- All bots follow
.npcbot command standstill    -- All bots stay
.npcbot distance 30           -- Set follow distance
.npcbot set spec 2            -- Change bot spec
.npcbot order cast Javad Lesser_Healing_Wave me
```

---

### 4.2 mod-playerbots - Full Feature List

#### Core Features
| Feature | Description |
|---------|-------------|
| **Alt Character Bots** | Use YOUR characters as AI-controlled bots |
| **Random Bots (Rndbots)** | Auto-generated bots that populate world |
| **Account-wide Bots** | Cross-account bot control with linking |
| **World Population** | Thousands of bots simulating MMO activity |
| **Strategy System** | Combat/Non-combat strategies, raid-specific |
| **RTSC System** | Real-time spatial control via aedm spell |
| **RTI System** | Raid target icon priority system |
| **Altbot Management** | `.playerbots bot add/remove` commands |
| **Autogear System** | Bots auto-equip best available gear |
| **Talent System** | Whisper `talents spec [name]` to change |
| **Glyph System** | Full glyph support |
| **Quest System** | Bots can accept/complete/turn-in quests |
| **Profession System** | All professions supported |
| **Bank/Guild Bank** | Deposit/withdraw items |
| **Gold Transfer** | Bots can give you gold |
| **Loot Management** | Configurable loot lists (gray, quest, skill, all) |
| **Pet Commands** | Hunter pet management, warlock demon selection |
| **Account Linking** | Link accounts for cross-account bot control |
| **Performance Scaling** | Smart activity scaling based on player proximity |

#### Combat Strategies
| Strategy | Description |
|----------|-------------|
| `tank` | Use threat-generating abilities |
| `tank assist` | Tanks pull mobs off others |
| `dps` | Use damage abilities |
| `cc` | Use crowd control (requires RTI target) |
| `assist` | Focus one target at a time |
| `aoe` | Target multiple enemies |
| `boost` | Use big cooldowns |
| `threat` | DPS avoids grabbing threat |
| `heal` | Focus on party healing |
| `save mana` | Healers prioritize efficiency |
| `avoid aoe` | Auto-dodge harmful ground effects |
| `behind` | Position behind target |

#### Raid-Specific Strategies (Auto-Applied on Entry)
| Strategy | Raids Covered |
|----------|---------------|
| `mc` | Molten Core (Baron Geddon) |
| `bwl` | Blackwing Lair (Onyxia cloak, suppression devices, Chromaggus debuff) |
| `aq20` | Ruins of Ahn'Qiraj (Ossirian) |
| `naxx` | Naxxramas (various bosses) |
| `voa` | Vault of Archavon (up to Emalon) |
| `wotlk-os` | Obsidian Sanctum (up to OS+2) |
| `wotlk-eoe` | Eye of Eternity (Malygos) |
| `uld` | Ulduar (up to Yogg-Saron) |
| `onyxia` | Onyxia's Lair |
| `icc` | Icecrown Citadel (all normal mode) |

#### Raid Completion Status
| Raid | Status | Notes |
|------|--------|-------|
| **Molten Core** | ✅ Completable | Baron Geddon strategy |
| **Blackwing Lair** | ✅ Completable | Auto-cloak buff, suppression disable |
| **Zul'Gurub** | ✅ Completable | No strategies needed |
| **AQ20** | ✅ Completable | Ossirian strategy |
| **AQ40** | ⚠️ WIP | Up to Twin Emperors |
| **Naxx 40** | ❌ Not Supported | - |
| **Karazhan** | ✅ Completable | Most bosses have strategies |
| **Gruul/Mag** | ✅ Completable | Strategies implemented |
| **SSC** | ⚠️ Partial | Lady Vashj needs work |
| **TK** | ❌ Not Completable | A'lar blocks progress |
| **Hyjal** | ⚠️ Partial | Up to Archimonde |
| **Black Temple** | ⚠️ Partial | Council/Illidan need work |
| **Naxx 10/25** | ✅ Completable | Most strategies done |
| **VoA** | ⚠️ WIP | Up to Emalon |
| **OS** | ✅ Completable | Up to OS+2 |
| **EoE** | ✅ Completable | Malygos strategy |
| **Ulduar** | ⚠️ WIP | Up to Yogg-Saron |
| **ToC** | ⚠️ WIP | Needs strategies |
| **Onyxia** | ✅ Completable | Strategy implemented |
| **ICC** | ✅ Completable | All normal; HC WIP |

#### Command Examples
```
.playerbots bot add Myalt           -- Log in alt as bot
.playerbots bot addaccount myacc    -- Log in entire account
summon                              -- Summon bot to you
follow / stay / flee                -- Movement commands
co +tank,-dps,~aoe                  -- Modify combat strategies
nc +loot                            -- Enable looting
rtsc save 1                         -- Save position marker
@tank attack                        -- Command tank group
talents spec fury                   -- Change spec
autogear                            -- Auto-equip best gear
```

---

### 4.3 Feature Comparison Matrix

| Feature | Trinity-Bots | mod-playerbots |
|---------|:------------:|:--------------:|
| **Pre-made bots included** | ✅ 312 bots | ❌ Must create |
| **Use alt characters** | ❌ | ✅ |
| **World population** | ⚠️ Wander only | ✅ Thousands |
| **Extra WC3 classes** | ✅ 9 classes | ❌ |
| **Raid strategies** | ❌ Manual | ✅ Auto-applied |
| **Dungeon Finder** | ✅ | ✅ |
| **Vehicle support** | ✅ Full | ⚠️ Limited |
| **Quest AI** | ⚠️ Limited | ✅ Full |
| **Profession support** | ⚠️ Gathering only | ✅ All |
| **AH/Trading** | ❌ | ✅ |
| **Guild support** | ⚠️ Limited | ✅ Full |
| **Formation system** | ✅ Advanced | ⚠️ Basic |
| **Target icons** | ✅ | ✅ |
| **Transmog** | ✅ | ❌ |
| **LLM Chat (with mod)** | ❌ | ✅ mod-ollama-chat |
| **Level brackets** | ❌ | ✅ mod-level-brackets |
| **Performance at scale** | ⚠️ Party/raid | ✅ Thousands |
| **Memory per bot** | Lower (NPC) | Higher (Character) |
| **Client addon** | NetherBot | MultiBot |

---

## 5. Limitations & Constraints

### 5.1 Trinity-Bots (NPCBots) - Limitations

#### Architectural Constraints
| Limitation | Description | Impact |
|------------|-------------|--------|
| **NPC-based** | Bots are NPCs, not player characters | No guild membership, no arena teams, no character progression |
| **Party-sized focus** | Designed for 1-40 bots per player | Not suitable for "world population" scenarios |
| **No alt character support** | Cannot use your own characters as bots | Must use pre-made or spawned NPCBots |
| **Single-maintainer** | trickerer is sole developer | Bus factor risk, development pace limited |
| **Patch-based updates** | Requires patch application on AC updates | Merge conflicts possible with custom core changes |

#### Feature Gaps
| Missing Feature | Workaround |
|-----------------|------------|
| **Quest AI** | Limited - bots won't independently quest |
| **AH/Trading** | None - bots cannot use Auction House |
| **Crafting** | Limited - gathering only (mining, herbalism, skinning) |
| **Guild system** | Limited - no full guild interaction |
| **Random world population** | Wander system only - not true population simulation |
| **Character persistence** | Bots don't persist progression like player alts |
| **Raid boss strategies** | None auto-applied - must manually command bots |

#### Scaling Constraints
| Metric | Limit | Notes |
|--------|-------|-------|
| **Bots per player** | ~40 recommended | Party + raid group sized |
| **Total server bots** | Hundreds (not thousands) | NPC limits may apply |
| **Memory per bot** | Lower than character | But still NPC creature overhead |
| **Wander bot density** | Limited by zone spawns | Not world-filling like mod-playerbots |

#### DC-255 Specific Concerns
- **Level 255 scaling:** Extra WC3 classes may not scale correctly at 255
- **Custom talents:** NPCBot talent system separate from player talents
- **Custom spells:** Bots use creature spell lists, may need custom additions
- **Vehicle scaling:** Vehicle mechanics may not work at level 255

---

### 5.2 mod-playerbots - Limitations

#### Architectural Constraints
| Limitation | Description | Impact |
|------------|-------------|--------|
| **REQUIRES CUSTOM FORK** | Cannot use standard AzerothCore | Lock-in to mod-playerbots fork |
| **Core hook modifications** | `OnPlayerCanUseChat` and others | Core changes create merge conflicts |
| **Higher memory per bot** | Full character simulation | 16GB+ RAM required for reasonable scale |
| **Complex configuration** | Many config options to tune | Steep learning curve for optimal setup |
| **Fork lag** | Typically 1-2 weeks behind upstream AC | May miss critical AC fixes |

#### Feature Gaps
| Missing Feature | Status |
|-----------------|--------|
| **Some raids incomplete** | AQ40 (partial), TK (blocked at A'lar), BT (partial), ToC (WIP), Vanilla Naxx |
| **ICC Heroic** | Work in progress |
| **Vehicle support** | Limited compared to Trinity-Bots |
| **Transmog on bots** | Not supported |
| **Extra WC3 classes** | Not available |
| **Bot formation system** | Basic compared to Trinity-Bots |

#### Hardware Requirements
| Tier | RAM | CPU | Bot Capacity |
|------|-----|-----|--------------|
| **Minimum** | 16 GB | 4 cores @ 3000 MHz | ~1000 bots |
| **Recommended** | 32+ GB | 6+ cores @ 4400+ MHz | ~5000 bots |
| **Tested Max** | 20 GB | AMD 5700x | 5000 bots stable |

#### MySQL Requirements (High Bot Counts)
```
innodb_buffer_pool_size = 2G+
innodb_log_file_size = 512M+
innodb_flush_log_at_trx_commit = 2
```

#### Raid Incompleteness Details
| Raid | Blocking Issue |
|------|----------------|
| **AQ40** | Twin Emperors strategy incomplete |
| **Naxx 40 (Vanilla)** | No strategies implemented |
| **Tempest Keep** | A'lar encounter blocks progression |
| **Black Temple** | Council and Illidan need work |
| **Trial of Crusader** | Strategies not implemented |

#### DC-255 Specific Concerns
- **Fork synchronization:** DC customizations must be merged INTO playerbots fork OR vice versa
- **`OnPlayerCanUseChat` conflict:** If DC uses `OnPlayerChat`, requires migration
- **Character data bloat:** Random bots create thousands of character rows in DB
- **Level 255 bot gear:** Autogear system may not handle custom items
- **Custom spell IDs:** Bot strategy code references hardcoded spell IDs

---

### 5.3 Limitation Comparison Summary

| Limitation Area | Trinity-Bots | mod-playerbots |
|-----------------|--------------|----------------|
| **Fork lock-in** | ❌ None | ⚠️ YES - mandatory |
| **World population** | ❌ Not designed for | ✅ Primary use case |
| **Alt character bots** | ❌ Not possible | ✅ Core feature |
| **Raid strategies** | ❌ Manual only | ⚠️ Incomplete for some |
| **WC3 extra classes** | ✅ Available | ❌ Not available |
| **Memory efficiency** | ✅ Better | ⚠️ Character overhead |
| **Upstream sync** | ✅ Weekly/predictable | ⚠️ Lag behind |
| **Vehicle AI** | ✅ Full support | ⚠️ Limited |
| **Merge conflict risk** | ⚠️ Moderate | ⛔ High |

---

## 6. Performance Considerations

### Trinity-Bots
- Designed for smaller bot counts (party/raid sized groups)
- NPC-based = lighter memory footprint per bot
- Focused on quality over quantity
- Typical use: 1-40 bots per player

### mod-playerbots
- Tested with 5000 bots on AMD 5700x / 20GB RAM
- Full character simulation = higher memory per bot
- Designed for world population
- Thread safety improvements (Nov 2025)
- Typical use: 100-10,000+ random bots server-wide
- Smart scaling: bots reduce activity when no players nearby

---

## 6. DarkChaos-255 Integration Concerns

### Potential Conflicts with DC Systems

| DC System | Trinity-Bots Risk | mod-playerbots Risk |
|-----------|-------------------|---------------------|
| **Phased Duels** | LOW - NPCs don't duel | MEDIUM - Bot players might trigger duel logic |
| **M+ Spectator** | LOW | LOW |
| **AoE Loot** | LOW | MEDIUM - Bots might affect loot distribution |
| **Level 255 Scaling** | UNKNOWN | UNKNOWN - Both need testing |
| **Custom Spells** | Needs adaptation | Needs adaptation |

### AzerothCore Sync Issues

**Trinity-Bots:**
- Weekly Saturday sync means max 1-week desync with upstream
- Patch-based = merge conflicts when AC changes patched files
- Single maintainer = consistent merge strategy

**mod-playerbots:**
- Custom fork may lag behind upstream AC
- Fork currently at 17,155 commits (need to check commit delta)
- Community-driven = less predictable merge timeline
- **Critical:** Cannot use standard AzerothCore with mod-playerbots

---

## 7. Support & Community

### Trinity-Bots
- GitHub Issues (18 open)
- GitHub Discussions
- Comprehensive README/Manual
- NetherBot addon by NetherstormX
- Single authoritative source

### mod-playerbots
- GitHub Issues (150 open)
- GitHub Discussions
- **Discord Server** (discord.gg/NQm5QShwf9)
- Extensive Wiki documentation
- Large contributor base

---

## 8. Decision Matrix

| Criterion | Weight | Trinity-Bots | mod-playerbots |
|-----------|--------|--------------|----------------|
| Installation Simplicity | 15% | 8/10 | 5/10 |
| AC Sync Reliability | 20% | 9/10 | 6/10 |
| Feature Richness | 15% | 7/10 | 9/10 |
| Performance at Scale | 10% | 6/10 | 9/10 |
| Community Support | 10% | 6/10 | 9/10 |
| DC Compatibility Risk | 15% | 8/10 | 6/10 |
| Documentation | 10% | 8/10 | 8/10 |
| Long-term Maintenance | 5% | 7/10 | 8/10 |

### Weighted Scores
- **Trinity-Bots:** 7.55/10
- **mod-playerbots:** 7.15/10

---

## 9. Recommendation Summary

### Choose Trinity-Bots (NPCBots) If:
- You want predictable weekly updates
- You need to stay close to upstream AzerothCore
- You want simpler installation/maintenance
- Party/raid-sized bot groups are sufficient
- The Warcraft 3 extra classes are appealing
- You prefer a single-maintainer stability

### Choose mod-playerbots If:
- You want a populated world with random bot players
- You need bots to use existing alt characters
- You want bots that can quest, trade AH, etc.
- You're comfortable with a custom AC fork
- You have resources for complex setup
- You want more community support options

### For DarkChaos-255 Specifically:
**Trinity-Bots appears to be the safer choice** due to:
1. Simpler integration with standard AC
2. Lower risk of conflicts with custom DC systems
3. Predictable update schedule
4. Patch-based approach easier to adapt for custom content

**However**, if the goal is world population with thousands of AI players making the server feel alive, **mod-playerbots is the only realistic option**.

---

## 10. Patch vs Fork: Critical Maintenance Analysis

### Trinity-Bots: Patch-Based Approach

**Do you need to manually review every patch update?**

**NO - if using the pre-patched repository option:**
- `trickerer/AzerothCore-wotlk-with-NPCBots` is maintained by the author
- This repo is kept in sync with upstream AC AND includes NPCBots patches
- Simply pull from this repo instead of standard AC

**YES - if using manual patch application:**
- Download `NPCBots.patch` and apply with `patch -p1 < NPCBots.patch`
- May require conflict resolution if DC has modified same files
- Need to review conflicts during `git am` or `patch` application

**Key Insight:** Pre-patched repo reduces maintenance to nearly zero, but you're dependent on trickerer's sync schedule.

### mod-playerbots: Fork-Based Approach

**How critical are the fork changes?**

**HIGH CRITICALITY - Core hook modifications required:**
- `OnPlayerChat` → `OnPlayerCanUseChat` replacement (fundamental event handler change)
- PlayerUpdate loop modifications for bot performance
- Group handling and party system patches
- Movement handler integrations

**These cannot be worked around** - the module will not function without the forked core.

**Fork Lag Reality:**
- Nov 2025: Fork was ~1 week behind upstream AC
- Regular merge conflict resolution visible in commits
- AC commits need manual integration

---

## 11. Alternative Modules & Repositories

### Companion/Bot Systems Researched

| Module | Status | Notes |
|--------|--------|-------|
| **mod-eluna-lua-engine** | ⚠️ DEPRECATED | Was being integrated into AC core directly; Eluna scripting still possible |
| **mod-npc-bots** | ❌ Not found | Different from Trinity-Bots NPCBots |
| **mod-autobalance** | ✅ Active | Scales instance difficulty - could complement bot systems |
| **mod-individual-progression** | ✅ Active | Content gating - may conflict with both bot systems |

### Complementary Modules for Bot Integration

1. **mod-autobalance** (github.com/azerothcore/mod-autobalance)
   - Auto-scales instance difficulty based on party size/composition
   - Would help balance encounters when using bots
   - Standard AC module, no fork required

2. **mod-transmog** (github.com/azerothcore/mod-transmog)
   - Could allow bot appearance customization
   - Standard AC module

3. **mod-cfbg** (Cross-Faction Battlegrounds)
   - If using bots in BG/Arena scenarios
   - May have implications for Phased Duels system

### NOT Recommended

- **Random bot spawn modules** - Both Trinity-Bots and mod-playerbots handle this internally
- **Generic companion mods** - Would conflict with either bot system
- **Creature AI mods** - Both systems have their own AI implementations

---

## 12. Direct Answer: Which is Easier to Maintain?

### For DarkChaos-255 Context:

| Factor | Trinity-Bots | mod-playerbots |
|--------|--------------|----------------|
| **Can use standard AC?** | ✅ YES (patches or pre-patched repo) | ❌ NO (requires fork) |
| **Update frequency** | Weekly (Saturdays) | As-needed (community driven) |
| **Update complexity** | LOW (pull pre-patched OR resolve patches) | HIGH (merge fork + module update) |
| **AC sync lag** | ~1 day (author maintains pre-patched) | ~1-2 weeks typical |
| **Fork lock-in** | ❌ None | ⚠️ YES - locked to mod-playerbots fork |
| **DC custom conflicts** | LOW (patches touch fewer files) | MEDIUM-HIGH (fork affects core hooks) |

### Bottom Line:

**Trinity-Bots using the pre-patched repo** = Simplest maintenance path
- Pull from `trickerer/AzerothCore-wotlk-with-NPCBots` instead of standard AC
- Apply DC customizations on top
- Weekly updates are predictable and automated by author

**mod-playerbots** = Higher maintenance, more features
- Must use their AC fork as base
- Merge DC changes into their fork (or vice versa)
- Core hook changes mean merge conflicts are likely with any custom work
- `OnPlayerCanUseChat` modification could conflict with DC chat systems

---

## 13. Next Steps for Evaluation

1. **Test Environment:**
   - Set up isolated test server for each solution
   - Test with DC's level 255 scaling active
   
2. **Compatibility Testing:**
   - Verify bot behavior with Phased Duels
   - Test AoE Loot with bot parties
   - Check M+ instance compatibility

3. **Performance Benchmarking:**
   - Measure server load with target bot count
   - Monitor memory usage patterns

4. **Update Procedure Testing:**
   - Simulate AC update + bot system update
   - Document merge conflict resolution

5. **Fork Integration Test (if mod-playerbots):**
   - Test merging DC changes into mod-playerbots fork
   - Identify specific file conflicts
   - Document resolution procedures

---

*This is a pre-discussion document. No implementation decisions should be made without hands-on testing of both solutions in a DarkChaos-255 test environment.*
