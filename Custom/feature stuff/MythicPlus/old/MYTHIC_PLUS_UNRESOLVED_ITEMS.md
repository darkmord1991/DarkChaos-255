# Dungeon Enhancement System - Unresolved Items & Clarification Needed
## DarkChaos Server - Wrath 3.3.5a Edition
## (Includes: Mythic+, Mythic Raids, Heroic Legacy Dungeons/Raids)

**Document Purpose:** Track all design decisions, features, and technical details that require clarification or have not been discussed yet.

**Last Updated:** 2025-11-12  
**Status:** ✅ FINAL - Ready for Implementation

---

## 🔴 **CATEGORY 1: CRITICAL DECISIONS NEEDED**

### **1.1 Affix System Configuration**

**Question:** Should affixes be server-wide rotation OR player choice?

**✅ DECISION: Server-wide rotation**

**Final Decision:**
- **Server-wide weekly rotation** (retail-like, simpler)
- Prevents meta gaming
- Everyone on same schedule
- No player choice complexity

**Impact:** Simpler implementation, retail-accurate, prevents affix meta gaming

---

### **1.2 Seasonal Dungeon Pool Size**

**Question:** How many dungeons should be active per season?

**✅ DECISION: 8 dungeons per season**

**Final Decision:**
- **8 dungeons** (retail standard) for Season 1 launch
- **ALL Vanilla/TBC/WotLK dungeons considered** for seasonal rotation
- Mix can vary per season (not locked to 4+2+2 distribution)

**Follow-up Questions RESOLVED:**
1. ✅ Should seasonal dungeons be WotLK-only or include Vanilla/BC? **ALL expansions included**
2. ✅ Should dungeon pool change mid-season or only at season boundaries? **Only at season boundaries**

**Impact:** Maximum variety, respects retail standard, engages all content

---

### **1.3 Great Vault Reward Options**

**Question:** Should players choose between item OR tokens, or get both?

**✅ DECISION: Random item OR tokens alternative**

**Final Decision:**
- **Random item generated** that fits player class/spec/talents
- **Token alternative** if player doesn't want item
- Token amounts scale with highest M+ level reached:

**Proposed Token Rewards:**
```
Slot 1 (1 dungeon completed):
- M+2-M+4: 50 Mythic Dungeon Tokens
- M+5-M+7: 75 Mythic Dungeon Tokens
- M+8-M+10: 100 Mythic Dungeon Tokens

Slot 2 (4 dungeons completed):
- M+2-M+4: 100 Mythic Dungeon Tokens
- M+5-M+7: 150 Mythic Dungeon Tokens
- M+8-M+10: 200 Mythic Dungeon Tokens

Slot 3 (8 dungeons completed):
- M+2-M+4: 150 Mythic Dungeon Tokens
- M+5-M+7: 225 Mythic Dungeon Tokens
- M+8-M+10: 300 Mythic Dungeon Tokens
```

**Impact:** Prevents gear waste, rewards high-level progression, fair token economy

---

### **1.4 Death Penalty System**

**Question:** What is the death penalty beyond keystone downgrade?

**✅ DECISION: 15 deaths = dungeon failure (M+ DUNGEONS ONLY)**

**Final Decision:**
- **Maximum 15 deaths** before dungeon auto-fails
- **SCOPE: M+ dungeons ONLY (M+2 to M+10)**
  - ❌ **Mythic 0 dungeons:** No death limit
  - ❌ **Mythic raids:** No death limit
  - ❌ **Heroic/Normal content:** No death limit
- **Failed runs give reduced tokens** (50% of normal token reward)
- **Item drops unchanged** (still get normal loot from bosses)
- **Keystone destroyed on failure** (must get replacement from Keystone Master NPC)
- **No timer system** (death-based only)

**Upgrade Formula (M+ Dungeons Only):**
```
0-5 deaths = Upgrade +2 levels (M+5 → M+7)
6-10 deaths = Upgrade +1 level (M+5 → M+6)
11-14 deaths = No upgrade (complete at same level, M+5 → M+5)
15+ deaths = Auto-fail, keystone destroyed
```

**Impact:** Forgiving for learning groups, clear failure threshold, rewards skill, does not affect non-M+ content

---

## 🟠 **CATEGORY 2: FEATURE CLARIFICATIONS**

### **2.1 Token Vendor Inventory**

**Question:** What exactly can players buy with Mythic Tokens?

**⏳ DEFERRED: To be discussed later**

**Current Status:**
- Dungeon Tokens (100020): Awarded at M+ completion
- Raid Tokens (100021): Awarded at boss kills
- Vendor inventory details postponed for post-launch design

**Impact:** Affects token value, player engagement, economy balance

---

### **2.2 Instance Lockout System**

**Question:** How do lockouts work for Mythic+ vs Raids?

**✅ DECISION: No M+ raids, separate lockouts per difficulty**

**Final Decision:**
- **NO Mythic+ for raids** - Only Normal/Heroic/Mythic fixed difficulties
- **M+ dungeons:** Unlimited runs per week (no lockouts)
- **Raids:** Separate lockout per difficulty (retail-like)
  - Can run Normal AND Heroic AND Mythic in same week
  - Each difficulty has independent lockout
  - Boss kills tracked per-difficulty

**Follow-up Questions RESOLVED:**
1. ✅ M+ dungeons: Can run same dungeon multiple times per week? **YES**
2. ✅ M+ dungeons: Can get loot multiple times from same dungeon? **YES**
3. ✅ Raids: Can run multiple difficulties per week? **YES - separate lockouts**
4. ✅ Raids: Does Normal lockout prevent Heroic/Mythic? **NO - independent**

**Impact:** Retail-accurate raid lockouts, unlimited M+ dungeon farming

---

### **2.3 Cross-Realm Support**

**Question:** Should Mythic+ work across realms (if AzerothCore supports it)?

**✅ DECISION: No cross-realm support for now**

**Final Decision:**
- **Single-realm only** for Phase 1
- Simpler implementation, no synchronization issues
- May reconsider in future phases based on population

**Impact:** Simpler architecture, faster implementation

---

### **2.4 Keystone Acquisition**

**Question:** How do players get their first keystone?

**✅ DECISION: Multiple sources defined**

**Final Decision:**

**Initial Keystone Acquisition:**
- **First-time:** Complete any Mythic 0 (M+0) dungeon → receive M+2 keystone at end
- **Weekly reset:** Great Vault gives keystone at highest level reached previous week
  - Example: Completed M+7 last week → Get M+7 keystone from vault
  - Never completed M+ before → Get M+2 keystone from vault

**Keystone Replacement (if deleted/lost):**
- Visit **Keystone Master NPC** in Mythic base (location TBD)
- Can request replacement keystone once per week
- Replacement level = highest completed that week (or M+2 if none)

**Keystone Master NPC:**
- Spawns at END of successful M+ run
- Teleports players back to base
- Also available as static NPC in Mythic base

**One keystone per player at a time** (cannot hoard multiple levels)

**Follow-up Questions RESOLVED:**
1. ✅ First keystone source? **M+0 completion OR weekly reset vault**
2. ✅ If player deletes keystone? **Visit Keystone Master NPC for replacement**
3. ✅ Multiple keystones in inventory? **NO - one at a time**

**Impact:** Clear acquisition path, prevents hoarding, retail-like progression

---

### **2.5 Seasonal Transitions**

**Question:** What happens to player progress when season ends?

**✅ DECISION: Full reset except tokens**

**Final Decision:**

**Season End Behavior:**
- **Keystones:** All keystones deleted (players start fresh at M+2)
- **Rating:** Mythic+ rating resets to 0 (archived as "Season X Rating")
- **Vault Progress:** Unclaimed vaults expire (no grace period)
- **Leaderboards:** Frozen and archived (top 100 preserved for history)
- **Tokens:** Carry over to new season (NOT reset)

**Season Start Behavior:**
- New seasonal dungeon pool activated (8 dungeons)
- New affix rotation schedule
- Leaderboards reset to empty
- All players receive M+2 keystone via mail

**Impact:** Fresh competitive season, token economy preserved, clear progression reset

---

## 🟡 **CATEGORY 3: TECHNICAL DETAILS**

### **3.1 Database Performance at Scale**

**Question:** How to handle database performance with thousands of M+ runs?

**✅ DECISION: Performance targets defined**

**Expected Load:**
- **Concurrent M+ runs:** 20
- **Runs per week:** 250
- **Total players:** 250
- **Database size:** ~5-10 GB (1 year of data)

**Database Optimization:**
- ✅ **Partition `dc_mythic_run_history` by season** - YES
- ✅ **Archive old runs** - Keep indefinitely (don't delete)
- ✅ **Use materialized views for leaderboards** - Need clarification on what this means
  - **Answer:** Materialized view = pre-calculated leaderboard table that updates after each run
  - **Implemented as:** `dc_mythic_leaderboard_cache` table (Section 4.5.2)

**Caching Strategy:**
- ✅ **Cache dungeon configs in memory** - YES (reload every 5 minutes)
- ✅ **Cache affix rotations** - YES (reload every week)
- ✅ **Cache leaderboards** - YES (refresh every 10 minutes)

**Impact:** Server handles 250 players, 20 concurrent runs comfortably with caching

---

### **3.2 NPC Placement & Accessibility**

**Question:** Where should Mythic+ NPCs be placed in the world?

**✅ DECISION: Major cities + manual placement**

**Final Decision:**

**Mythic+ Dungeon Teleporter (NPC 100000):**
- **Stormwind** (Alliance hub)
- **Orgrimmar** (Horde hub)
- **Dalaran** (neutral hub)
- **Additional locations:** Manual placement by GMs as needed

**Great Vault:**
- **GameObject** (not NPC) - can be placed multiple times
- **GameObject ID:** 700000
- Locations: Stormwind, Orgrimmar, Dalaran, more as needed

**Font of Power (Keystone Activation):**
- **GameObject** - placed at dungeon entrances
- **GameObject IDs:** 700001-700008 (one per seasonal dungeon)
- Players interact to start M+ run

**Token Vendors:**
- Same locations as Teleporter NPC

**Phasing:**
- ✅ **NOT phased** - Visible to all players regardless of level

**Impact:** Accessible from major cities, flexible manual placement

---

### **3.3 Addon Integration Requirements**

**Question:** What addons are REQUIRED vs OPTIONAL for Mythic+ system?

**⏳ DEFERRED: Too complex for now, to be discussed later**

**Current Status:**
- System works without any addons (pure server-side)
- Addon enhancements postponed for post-launch

**Potential Future Addons:**
- Enhanced keystone tooltips
- Mythic+ HUD (similar to Hinterlands BG addon)
- GearScore display
- Group finder UI

**Impact:** Clean Phase 1 launch, addon features can be added incrementally

---

### **3.4 DBC Editing Workflow**

**Question:** What is the exact process for distributing DBC changes to players?

**✅ DECISION: Single large client patch**

**Final Decision:**
- **One big client patch** containing all DBC edits
- Not excessively large in size
- Distributed via website/Discord
- Players install in `World of Warcraft/Data/` folder

**DBC Files Included:**
- Item.dbc (keystones 100000-100008, tokens 100020-100021)
- LFGDungeons.dbc (M+ dungeon entries 10000-10207)
- MapDifficulty.dbc (level 80 scaling for Vanilla/BC)
- Spell.dbc (affix debuffs 70000-70010)
- Creature.dbc (custom NPCs/bosses 100000+)

**Impact:** Simple distribution model, single patch file

---

## 🟢 **CATEGORY 4: QUALITY OF LIFE FEATURES**

### **4.1 Keystone Tooltip Enhancements**

**Question:** What information should keystone tooltips show?

**✅ DECISION: Enhanced tooltips with dungeon/affixes**

**Final Decision - Enhanced Tooltip:**
```
Mythic Keystone +5
Dungeon: Utgarde Pinnacle
Affixes: Fortified, Raging, Necrotic

This keystone is soulbound and cannot be traded.
```

**Design Notes:**
- **Show dungeon name** - Requires separate item per dungeon per season
- **Show current affixes** - Display server-wide weekly affixes
- **NO GearScore requirement** - Not shown on tooltip
- **NO success rate** - Deferred to potential addon later

**Implementation:**
- Multiple keystone items per season (8 dungeons × 9 levels = 72 items)
- Or: Dynamic tooltip via server → client addon message (simpler)

**Impact:** Clear keystone information, requires multiple items or addon support

---

### **4.2 In-Dungeon UI Enhancements**

**Question:** What UI elements should be visible during M+ run?

**✅ DECISION: HUD similar to Hinterlands BG addon**

**Final Decision:**
- **HUD addon** (like Hinterlands BG implementation)
- **Short and clear information:**
  - Death counter (top-right)
  - Keystone level (top-left)
  - Boss progress (e.g., "2/4 bosses killed")
  - Current affixes (hover tooltip)

**NOT included (Phase 1):**
- Timer (death-based system, no timer needed)
- DPS/HPS meter (use existing addons like Recount/Skada)
- Interrupt tracker (too complex)

**Impact:** Clear M+ progress visibility, familiar addon pattern

---

### **4.3 Group Finder Filters**

**Question:** What filters should the group finder NPC have?

**✅ DECISION: Simple filters by content type**

**Final Decision:**
- **Filter: Mythic Dungeons** - Show all M+ dungeon groups
- **Filter: Mythic Raids** - Show all Mythic raid groups
- **No advanced filters** for Phase 1 (level, role, GearScore, language, etc.)

**Rationale:**
- Simple implementation
- Most important distinction: dungeons vs raids
- Advanced filters can be added post-launch if needed

**Impact:** Clean group finder, easy to navigate

---

### **4.4 Achievement Tracking**

**Question:** What Mythic+ achievements should exist?

**✅ DECISION: Seasonal-based achievements**

**Proposed Seasonal Achievement System:**

**Season 1 Achievements (Example):**

**Completion Tiers:**
- [ ] **"Mythic Initiate"** (10 pts) - Complete any M+2 dungeon
- [ ] **"Mythic Challenger"** (15 pts) - Complete all 8 seasonal dungeons at M+2
- [ ] **"Mythic Contender"** (25 pts) - Complete all 8 seasonal dungeons at M+5
- [ ] **"Keystone Master: Season 1"** (50 pts, title: "S1 Keystone Master") - Complete all 8 seasonal dungeons at M+10

**Challenge Achievements:**
- [ ] **"Flawless Victory"** (25 pts) - Complete any M+5 with 0 deaths
- [ ] **"Deathless Ascent"** (50 pts, title: "the Deathless") - Complete M+10 with 0 deaths
- [ ] **"Speed Demon"** (25 pts) - Complete 10 M+ dungeons in one day
- [ ] **"Century Club"** (10 pts) - Complete 100 M+ dungeons total (any level)
- [ ] **"Mythic Veteran"** (25 pts, mount reward) - Complete 500 M+ dungeons total

**Seasonal-Specific:**
- [ ] **"Season 1 Conqueror"** (50 pts) - Reach top 100 on any dungeon leaderboard
- [ ] **"Season 1 Champion"** (100 pts, title: "S1 Champion", unique mount) - Finish Season 1 in top 10 overall rating

**Dungeon-Specific (repeatable per dungeon):**
- [ ] **"Utgarde Pinnacle Master"** (15 pts) - Complete UP at M+10
- [ ] **"Halls of Lightning Master"** (15 pts) - Complete HoL at M+10
- [ ] (One per seasonal dungeon)

**Hidden Achievements (Feat of Strength):**
- [ ] **"Solo Mythic+"** - Complete any M+2 solo (no group)
- [ ] **"Mythic Marathon"** - Complete all 8 seasonal dungeons in one day at M+5+
- [ ] **"Perfectly Balanced"** - Complete M+10 with exactly 5 deaths (upgrade threshold)

**Season 2+ Achievements:**
- New "Season 2 Keystone Master" achievement
- New seasonal leaderboard achievements
- Previous season achievements become Feats of Strength (no longer obtainable)

**Impact:** Clear progression goals, seasonal competition, long-term engagement

---

## 🔵 **CATEGORY 5: ANTI-EXPLOIT & SECURITY**

### **5.1 Rating/Leaderboard Manipulation**

**Question:** How to prevent leaderboard exploits?

**✅ Lower Priority** - Focus on Phase 1 core functionality first

**Potential Exploits:**
- Account sharing (Player A completes M+10, Player B claims rewards)
- Boosting services (high-rated players carry for gold)
- Rating inflation (farm easy dungeons)
- Collusion (intentional fails to manipulate leaderboards)

**Proposed Mitigations (Post-Launch):**
- IP tracking for suspicious activity
- Rating decay (no runs in 2 weeks)
- Diminishing returns (same dungeon repeatedly)
- Group diversity requirement (must complete variety)
- Manual review by GMs

**Impact:** Can be addressed post-launch based on actual abuse patterns

---

### **5.2 Keystone Selling/Buying**

**Question:** Should players be allowed to sell keystone runs for gold?

**✅ DECISION: NO keystone selling - Destroy only**

**Final Decision:**
- **No "selling" mechanics** - Keystones cannot be transferred or traded
- **Only destroy option** - Player can destroy unwanted keystone via right-click
- **No carry tags** in group finder (Phase 1)
- **Server policy enforcement** - Selling for real money is already banned by ToS

**Rationale:**
- Low population server (250 players) means selling would dominate
- Leaderboard integrity requires legitimate progression
- Player can still GROUP with friends (not "sell")
- If demand arises post-launch, can add "Carry Mode" flag later

**Implementation:**
- Keystones remain SOULBOUND
- Right-click → "Destroy Keystone" option only
- No trade, no AH, no mail

**Impact:** Preserves competitive integrity, cleaner economy

---

### **5.3 Addon-Based Exploits**

**Question:** How to prevent malicious addons from exploiting M+ system?

**✅ Lower Priority** - Server-side validation is sufficient

**Potential Risks:**
- Keystone duplication via packet injection
- Death counter manipulation
- GearScore spoofing
- Affix removal attempts

**Existing Mitigations:**
- **Server-side validation** - ALL critical data stored server-side (never trust client)
- **Opcode filtering** - Block suspicious packets
- AzerothCore's built-in anti-cheat systems

**Future Considerations (Post-Launch):**
- Checksum validation for client files
- Addon whitelist for M+ interactions
- Specific client version enforcement

**Impact:** Core security handled by existing AzerothCore systems

**Recommendation:** **Server-side validation only** - Assume all client data is hostile

---

## 📊 **CATEGORY 6: METRICS & ANALYTICS**

### **6.1 Success Rate Tracking**

**Question:** What metrics should be tracked for system balancing?

**⏳ DEFERRED - Post-launch based on actual usage**

**Proposed Metrics (Phase 2):**
- Overall M+ completion rate (% of started runs that complete)
- Completion rate by keystone level (M+2 vs M+10 success rates)
- Completion rate by dungeon (which dungeons are hardest?)
- Average deaths per run (overall and per keystone level)
- Average run duration (how long do M+5 runs take?)
- Player retention (% of players who run M+ weekly vs one-time)

**Use Cases:**
- Identify overtuned dungeons → nerf boss HP
- Identify undertuned keystones → buff affixes
- Identify unpopular dungeons → remove from seasonal pool
- Identify player pain points → improve tutorials

**Rationale:** Need actual usage data before building metrics dashboard

**Impact:** Can build analytics after system is live

---

### **6.2 Player Feedback Collection**

**Question:** How should players provide feedback on M+ system?

**⏳ DEFERRED - Use existing channels**

**Phase 1 Feedback Methods:**
- **Discord channel:** Dedicated #mythic-plus-feedback
- **GM reports:** Players can open tickets for bugs/issues
- **Forum threads:** Community discussion

**Phase 2 (Post-Launch):**
- In-game survey (post-run popup "Rate this dungeon (1-5 stars)")
- Website form (structured feedback with categories)
- Community council (select players invited to test new features)

**Rationale:** Don't build complex feedback system before launch

**Impact:** Use existing community channels first

---

## 🎯 **SUMMARY: DECISIONS STATUS**

### **✅ RESOLVED (High Priority - Phase 1 Blockers):**
1. ✅ **Edge case handling** - COMPLETED (Section 2.12, 9 subsections)
2. ✅ **Item/NPC ID standardization** - COMPLETED (100000 range throughout)
3. ✅ **Affix system mode** - Server-wide weekly rotation (not player choice)
4. ✅ **Death penalty specifics** - 15 deaths = fail, upgrade formula: 0-5=+2, 6-10=+1, 11-14=same, 15+=fail
5. ✅ **Great Vault reward options** - Token scaling system (50-300 per slot based on M+ level)
6. ✅ **Seasonal dungeon pool size** - 8 dungeons per season from all Vanilla/TBC/WotLK content

### **✅ RESOLVED (Medium Priority - Phase 1 Deliverables):**
7. ⏳ **Token vendor inventory** - DEFERRED to Phase 2
8. ✅ **Raid lockout clarification** - No M+ for raids (only Normal/Heroic/Mythic), separate lockouts per difficulty
9. ✅ **Keystone acquisition method** - M+0 completion OR weekly vault (highest reached), Keystone Master NPC for replacements
10. ✅ **Seasonal transition behavior** - Full reset (keystones, leaderboards, affixes) except tokens carry over
11. ✅ **NPC placement locations** - Stormwind, Orgrimmar, Dalaran (Great Vault = GameObject)
12. ✅ **Database performance targets** - 250 players, 250 runs/week, 20 concurrent runs, partition by season, cache all configs

### **✅ RESOLVED (Low Priority - Phase 1 Features):**
13. ✅ **Cross-realm support** - NO for Phase 1 (can add later if needed)
14. ⏳ **Addon integration requirements** - DEFERRED (HUD addon like Hinterlands BG, optional for Phase 1)
15. ✅ **DBC distribution workflow** - Single large client patch with all custom content
16. ✅ **Achievement system** - Seasonal-based achievements (see Section 4.4 proposals)
17. ✅ **Keystone tooltip enhancements** - Enhanced tooltips (dungeon name, affixes, soulbound warning)
18. ✅ **Group finder filter options** - Simple filters (Mythic Dungeons vs Mythic Raids)
19. ✅ **In-dungeon UI enhancements** - HUD addon similar to Hinterlands BG (death counter, keystone level, boss progress, affixes)
20. ✅ **Boosting/carry policy** - NO keystone selling (destroy only), no carry tags in group finder
21. ⏳ **Metrics tracking dashboard** - DEFERRED to Phase 2 (post-launch analytics)
22. ⏳ **Player feedback collection methods** - DEFERRED (use Discord/GM tickets/forums for Phase 1)

### **📋 COMPLETION STATUS:**
- **Category 1 (Critical):** 4/4 resolved ✅ (100%)
- **Category 2 (Features):** 4/5 resolved ✅ (80%, 1 deferred)
- **Category 3 (Technical):** 3/4 resolved ✅ (75%, 1 deferred)
- **Category 4 (QoL):** 4/4 resolved ✅ (100%)
- **Category 5 (Security):** 1/3 resolved ✅ (33%, 2 lower priority)
- **Category 6 (Metrics):** 0/2 resolved (100% deferred)

**Overall:** 16/22 resolved (73%), 4 deferred (18%), 2 lower priority (9%)

### **🔄 NEXT STEPS:**
1. ✅ Update UNRESOLVED_ITEMS.md with user decisions - **COMPLETE**
2. ⏳ Update MYTHIC_PLUS_SYSTEM_PLAN.md with:
   - Vault token scaling table (Section 8)
   - Death penalty formula (Section 2.12.1)
   - Keystone acquisition flow (Section 2.5)
   - Keystone Master NPC details (Section 11)
   - Configuration updates (Section 6)
3. ⏳ Add achievement proposals to main plan (new Section 14 or expand 4.4)
4. ⏳ Final document review for consistency and remaining gaps

---

## � **FILE STRUCTURE DECISIONS (✅ FINALIZED)**

### **System Name: DungeonEnhancement**
Broader scope than just Mythic+ - includes Mythic raids, Heroic legacy content upgrades, and difficulty scaling for all Vanilla/TBC/WotLK dungeons/raids.

### **Directory Organization:**

**C++ Scripts Location:**
```
src/server/scripts/DC/DungeonEnhancement/
├─ Core/
│  ├─ DungeonEnhancementConstants.h       // Enums, IDs, action offsets
│  ├─ DungeonEnhancementManager.cpp/.h    // Singleton manager class
│  ├─ MythicDifficultyScaling.cpp/.h      // HP/Damage scaling logic
│  ├─ MythicRunTracker.cpp/.h             // Run state, timer, deaths (M+ only)
│  └─ MythicSeasonManager.cpp/.h          // Season start/end logic
├─ NPCs/
│  ├─ npc_mythic_plus_dungeon_teleporter.cpp  // NPC 100000
│  ├─ npc_mythic_raid_teleporter.cpp          // NPC 100001
│  ├─ npc_mythic_token_vendor.cpp             // NPC 100002
│  └─ npc_keystone_master.cpp                 // NPC 100003
├─ Affixes/
│  ├─ MythicAffixHandler.cpp/.h           // Base affix class (M+ only)
│  ├─ Affix_Tyrannical.cpp
│  ├─ Affix_Fortified.cpp
│  ├─ Affix_Bolstering.cpp
│  ├─ Affix_Necrotic.cpp
│  └─ Affix_Volcanic.cpp
└─ Rewards/
   ├─ MythicVaultManager.cpp/.h           // Weekly vault logic (M+ only)
   ├─ MythicLootGenerator.cpp/.h          // Token/item generation
   └─ MythicAchievementHandler.cpp/.h     // Achievement tracking
```

**SQL Scripts Location:**
```
Custom/Custom feature SQLs/
├─ characters/
│  ├─ de_mythic_player_rating.sql          (Player M+ rating, seasonal data)
│  ├─ de_mythic_keystones.sql              (Active keystone tracking)
│  ├─ de_mythic_run_history.sql            (Completed runs per player)
│  ├─ de_mythic_vault_progress.sql         (Weekly vault progress)
│  └─ de_mythic_achievement_progress.sql   (Player achievement tracking)
└─ world/
   ├─ de_mythic_seasons.sql                (Season definitions)
   ├─ de_mythic_dungeons_config.sql        (Dungeon configs per season)
   ├─ de_mythic_raid_config.sql            (Raid difficulty configs)
   ├─ de_mythic_affixes.sql                (Affix definitions & weekly rotation)
   ├─ de_mythic_vault_rewards.sql          (Vault loot tables)
   ├─ de_mythic_achievement_defs.sql       (Achievement definitions)
   ├─ de_mythic_tokens_loot.sql            (Token drop rates)
   ├─ de_mythic_npc_spawns.sql             (NPC creature spawns)
   └─ de_mythic_gameobjects.sql            (GameObject spawns: Vault, Font of Power)
```

**Naming Convention:**
- Table prefix: `de_*` (DungeonEnhancement)
- Config prefix: `DungeonEnhancement.*` OR `MythicPlus.*` (both supported)
- C++ namespace: `DungeonEnhancement::`

**GameObject ID Ranges:**
- **700000:** Great Vault (main GameObject)
- **700001-700008:** Font of Power (8 seasonal dungeons)
- **700009-700099:** Reserved for future M+ GameObjects
- **700100-700199:** Reserved for Mythic raid-specific objects

**Death Penalty Scope (CRITICAL):**
- ✅ **Mythic+ Dungeons (M+2 to M+10):** 15 death maximum enforced, upgrade formula applies
- ❌ **Mythic 0 Dungeons:** No death limit, no keystone, normal loot rules
- ❌ **Mythic Raids:** No death limit, normal lockout rules apply
- ❌ **Heroic/Normal content:** No death limit, existing mechanics unchanged

**Schema References:**
- Existing schema files located in: `Custom/Custom feature SQLs/`
- New tables follow existing `dc_*` naming convention (OR use new `de_*` prefix)
- Foreign keys reference existing AzerothCore tables where applicable

**Impact:** 
- Clear separation of character vs world database tables
- Organized C++ script structure by functionality
- GameObject IDs in 700000 range (no conflicts with existing content)
- Death penalty correctly scoped to M+ dungeons only
- Broader system name reflects full feature set (M+, Mythic raids, legacy upgrades)
