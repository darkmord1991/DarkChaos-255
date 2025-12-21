# Advanced Features Evaluation & DC Exclusive Extensions

**Document Version:** 1.0  
**Last Updated:** Based on research of retail WoW, Aldori15/azerothcore-eluna-accountwide, and 3.3.5a client capabilities  
**Purpose:** Deep evaluation of additional collectables, battle pets feasibility, and DC-exclusive features

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Aldori15 Account-Wide Pattern Analysis](#aldori15-account-wide-pattern-analysis)
3. [3.3.5a Client Limitations](#335a-client-limitations)
4. [Collectable Types Evaluation](#collectable-types-evaluation)
5. [Battle Pet System Feasibility](#battle-pet-system-feasibility)
6. [DC Exclusive Features](#dc-exclusive-features)
7. [Implementation Priority Matrix](#implementation-priority-matrix)

---

## Executive Summary

### Key Findings

| Category | Feasibility | Effort | Impact |
|----------|-------------|--------|--------|
| **Mounts** | ✅ Native | Low | High |
| **Companion Pets** | ✅ Native | Low | High |
| **Appearances/Transmog** | ✅ Custom (existing) | Done | High |
| **Titles** | ✅ Native | Low | Medium |
| **Achievements** | ✅ Native | Medium | High |
| **Toys** | ⚠️ Custom | Medium | Medium |
| **Heirlooms** | ⚠️ Custom | Medium | Medium |
| **Taxi Paths** | ✅ Native | Low | Low |
| **Currency** | ✅ Native | Low | Medium |
| **Reputation** | ⚠️ Semi-Custom | Medium | Medium |
| **Battle Pets (Combat)** | ❌ Full Custom | Very High | High |
| **Wardrobe Sets** | ⚠️ Custom | Medium | Medium |
| **Recipe Collection** | ⚠️ Custom | Medium | Low |

### Bottom Line

- **Battle Pets (MoP-style turn-based combat)** requires a **complete custom implementation** - the 3.3.5a client has zero support for this
- **Toy Box** can be implemented via custom items + addon UI
- **Account-Wide features** are well-documented via Aldori15 patterns and can be adapted
- **DC-exclusive features** offer significant differentiation opportunities

---

## Aldori15 Account-Wide Pattern Analysis

### Repository: `Aldori15/azerothcore-eluna-accountwide`

This repository provides production-ready Eluna/ALE scripts for account-wide sharing of various character features.

### Systems Covered

| System | Script | Database Table | Key Pattern |
|--------|--------|----------------|-------------|
| Mounts | `AccountMounts.lua` | `accountwide_mounts` | Spell ID list (~400+), login sync |
| Pets | `AccountPets.lua` | `accountwide_pets` | Spell ID list (~150+), login sync |
| Achievements | `AccountAchievements.lua` | `accountwide_achievements` | Achievement ID tracking |
| Currency | `AccountCurrency.lua` | `accountwide_currency` | Item ID based currency |
| Money | `AccountMoney.lua` | N/A | Shared gold pool |
| Reputation | `AccountReputation.lua` | `accountwide_reputation` | Faction-aware (H/A split) |
| Taxi Paths | `AccountTaxiPaths.lua` | `accountwide_taxi` | Node ID tracking |
| Titles | `AccountTitles.lua` | `accountwide_titles` | CharTitles.dbc IDs |

### Core Implementation Pattern

```lua
-- Hook: Player Login (PLAYER_EVENT_ON_LOGIN = 3)
-- On login, query account-level table and apply all learned items

-- Hook: Learning New Spell (PLAYER_EVENT_ON_LEARN_SPELL = 44)
-- When player learns a spell, check if it's a mount/pet spell
-- If yes, save to account-level table

-- Database Pattern:
-- account_id (from auth.account)
-- spell_id / item_id / achievement_id
-- learned_at timestamp
-- source_character guid (optional)
```

### Key Takeaways for DC Integration

1. **Modular Enable/Disable** - Each system can be toggled independently
2. **Login Sync** - Apply all account-wide features at login
3. **Learning Hook** - Capture new acquisitions in real-time
4. **Spell ID Based** - Mounts/pets are internally spells, easy to track
5. **Bot Account Handling** - Utils include `isPlayerBotAccount()` to skip bots

### Recommended Integration Points

- Use Aldori15 patterns as **server-side foundation**
- Extend with **DCAddonProtocol** for rich UI updates
- Add **statistics tracking** (collection %, rarity breakdown)
- Implement **favorites system** per-character

---

## 3.3.5a Client Limitations

### Native Client Support (Interface 30300)

| Feature | Client Support | Notes |
|---------|---------------|-------|
| **Mounts Tab** | ❌ None | Added in MoP 5.0.4 |
| **Pet Journal** | ❌ None | Added in MoP 5.0.4 |
| **Toy Box** | ❌ None | Added in WoD 6.0.2 |
| **Heirloom Tab** | ❌ None | Added in WoD 6.1.0 |
| **Appearances Tab** | ❌ None | Added in Legion 7.0.3 |
| **Achievement UI** | ✅ Full | Native in 3.3.5 |
| **Pet Window** | ✅ Limited | SpellBookFrame companion tab |
| **Mount Macro** | ✅ Yes | `/cast [spell name]` works |
| **Character Titles** | ✅ Full | Native dropdown |
| **Reputation Panel** | ✅ Full | Native UI |
| **Currency Tab** | ⚠️ Limited | Token frame exists |

### Client API Availability (3.3.5a)

#### ✅ Available for Collection Systems
```lua
-- Companion Pets
GetNumCompanions("CRITTER")          -- Count owned pets
GetCompanionInfo("CRITTER", index)   -- Get pet info
CallCompanion("CRITTER", index)      -- Summon pet
DismissCompanion("CRITTER")          -- Dismiss pet

-- Mounts
GetNumCompanions("MOUNT")
GetCompanionInfo("MOUNT", index)
CallCompanion("MOUNT", index)

-- Achievements
GetAchievementInfo(achievementID)
GetAchievementCriteriaInfo(achievementID, criteriaNum)

-- Items (for toys/heirlooms)
GetItemInfo(itemID)
PlayerHasItem(itemID)
UseContainerItem(bag, slot)
```

#### ❌ NOT Available in 3.3.5a
```lua
-- These do NOT exist:
C_MountJournal.*              -- All MoP+ mount journal API
C_PetJournal.*                -- All MoP+ pet journal API
C_ToyBox.*                    -- All WoD+ toy box API
C_Heirloom.*                  -- All WoD+ heirloom API
C_TransmogCollection.*        -- All Legion+ transmog API
C_PetBattles.*                -- All MoP+ pet battle API
```

### Workaround Strategy

Since the client lacks native collection APIs, we use:

1. **Server Communication** - Send collection data via addon messages (DCAddonProtocol)
2. **Custom UI Frames** - Build collection browser entirely in addon Lua
3. **Cached Data** - Store server-sent collection data in SavedVariables
4. **Spell/Item Hooks** - Use existing APIs to summon/use collected items

---

## Collectable Types Evaluation

### 1. Mounts ✅

**Native 3.3.5a Support:** Partial (SpellBook companion tab)

**What 3.3.5a Has:**
- ~170 mounts exist in WOTLK
- Stored as learned spells
- `GetCompanionInfo("MOUNT", i)` works
- Random mount macro: `/run CallCompanion("MOUNT", random(GetNumCompanions("MOUNT")))`

**What We Add:**
- Rich UI (grid view, filtering, sorting)
- Account-wide sync (Aldori15 pattern)
- Favorites system
- Collection statistics
- Source tracking

**Implementation Effort:** ⭐⭐ (Low-Medium)

---

### 2. Companion Pets ✅

**Native 3.3.5a Support:** Partial (SpellBook companion tab)

**What 3.3.5a Has:**
- ~150 companion pets
- Stored as learned spells
- `GetCompanionInfo("CRITTER", i)` works
- Can summon/dismiss via API

**What We Add:**
- Journal-style UI
- Account-wide sync
- Pet naming (via server-side storage)
- Pet stats display (if we implement battle pets)
- Favorites and filtering

**Implementation Effort:** ⭐⭐ (Low-Medium)

---

### 3. Toys ⚠️ (Custom Implementation Required)

**Native 3.3.5a Support:** ❌ None

**Retail Toy Box (WoD 6.0.2+):**
- Account-wide vanity items
- Removes items from bags after learning
- Shared cooldowns
- 400+ toys

**3.3.5a Approach:**
- Define custom item list (fun items, transformation items, etc.)
- Track via `account_toys` database table
- Create addon UI for browsing
- "Use" via server command that creates temporary item or casts spell

**Candidate Toys in 3.3.5a:**
| Category | Examples |
|----------|----------|
| Transformation | Orb of Deception, Orb of Sin'dorei, Iron Boot Flask |
| Fun Effects | Piccolo of the Flaming Fire, Noggenfogger Elixir |
| Teleports | Argent Tournament tabards, Dalaran rings |
| Utility | Engineer gadgets, Archaeology rewards |
| Cosmetic | Dartol's Rod, Deviate Delight |

**Implementation Effort:** ⭐⭐⭐ (Medium)

---

### 4. Heirlooms ⚠️ (Custom Implementation Required)

**Native 3.3.5a Support:** ❌ None (Heirloom items exist, but no collection tab)

**Retail Heirloom Tab (WoD 6.1.0+):**
- Account-wide scaling gear
- Learn once, create copies anywhere
- Upgrade tokens

**3.3.5a Approach:**
- Track owned heirlooms in `account_heirlooms` table
- Create addon UI showing all available heirlooms
- "Create Copy" sends server command to mail/create item
- Integrate with existing DC leveling system

**3.3.5a Heirlooms Available:**
| Slot | Item Examples | Source |
|------|---------------|--------|
| Shoulder | Tattered Dreadmist Mantle, Champion Herod's Shoulder | Emblems, Champion's Seal |
| Chest | Tattered Dreadmist Robe | Emblems |
| Weapon | Bloodied Arcanite Reaper, Venerable Mass of McGowan | Emblems |
| Trinket | Swift Hand of Justice, Discerning Eye of the Beast | Emblems |

**Implementation Effort:** ⭐⭐⭐ (Medium)

---

### 5. Titles ✅

**Native 3.3.5a Support:** ✅ Full

**What 3.3.5a Has:**
- ~100+ titles
- Native dropdown in character panel
- Stored in CharTitles.dbc

**What We Add:**
- Account-wide sync (Aldori15 pattern)
- Collection view showing all available titles
- Source/requirement display
- Title preview

**Implementation Effort:** ⭐ (Low)

---

### 6. Achievements ✅

**Native 3.3.5a Support:** ✅ Full (Achievement UI is native)

**What 3.3.5a Has:**
- Complete achievement system
- Native UI for browsing
- Criteria tracking

**What We Add:**
- Account-wide sync for achievement credit
- "Accountable" achievements (using Aldori15 pattern)
- Cross-character progress sharing
- DC-specific achievements

**Implementation Effort:** ⭐⭐ (Low-Medium)

---

### 7. Recipes/Patterns 📚 (New Collection Type)

**Concept:** Track learned crafting recipes account-wide

**What 3.3.5a Has:**
- Recipes stored per-character profession
- No account-wide visibility

**What We Add:**
- Account-wide recipe collection tracking
- "Which character knows this?" lookup
- Recipe source database
- Crafting planner integration

**Implementation Effort:** ⭐⭐⭐ (Medium)

---

### 8. Wardrobe Sets 👗 (New Collection Type)

**Concept:** Pre-defined transmog sets that can be saved/applied

**What 3.3.5a Has:**
- Existing transmog system (custom)
- Individual item appearances

**What We Add:**
- Named outfit sets
- Quick-swap presets
- Class/role themed sets
- Community-shared set templates

**Implementation Effort:** ⭐⭐ (Low-Medium)

---

## Battle Pet System Feasibility

### The Hard Truth

**Battle Pets (turn-based combat system) were introduced in MoP Patch 5.0.4 (August 2012).**

The 3.3.5a client has **ZERO** native support for:
- Pet Battle combat system
- Wild pet encounters
- Pet leveling (1-25)
- Pet abilities/moves
- Pet breeding/quality
- PvP pet battles
- Pet Battle quest types

### What Would Full Implementation Require?

#### Server-Side (C++ Core Changes)

```cpp
// New systems needed:
class PetBattleSystem {
    // Turn-based combat state machine
    // Pet ability definitions
    // Damage/healing calculations
    // Pet experience/leveling
    // Wild pet spawn system
    // Pet capture mechanics
    // Battle queue system (PvP)
};

// Database tables:
character_battle_pets     -- Owned battle pets with stats
battle_pet_abilities      -- Ability definitions
battle_pet_species        -- Species base stats/types
wild_pet_spawns           -- World spawn points
character_pet_battles     -- Battle history/stats
```

#### Client-Side (Custom Addon)

```lua
-- Custom combat UI
-- Pet selection frame
-- Ability bar
-- Turn timer
-- Combat log
-- Pet capture animations
-- Wild pet targeting
-- PvP queue interface
```

#### Content Requirements

| Requirement | Scope |
|-------------|-------|
| Pet Species | 500+ unique species |
| Abilities | 600+ unique abilities |
| Wild Spawns | Thousands of spawn points |
| Trainers | 50+ NPC pet tamers |
| Quests | Tutorial + progression chain |
| Achievements | ~50 battle pet achievements |

### Effort Estimation

| Component | Time | Difficulty |
|-----------|------|------------|
| Core Combat System | 4-6 weeks | Very High |
| Pet Ability Framework | 2-3 weeks | High |
| Wild Pet Spawning | 2 weeks | Medium |
| Client UI | 3-4 weeks | High |
| Content Population | 6-8 weeks | Medium |
| Testing/Balance | 4+ weeks | Medium |
| **Total** | **21-27 weeks** | **Extreme** |

### Recommendation: Alternative Approaches

Instead of full Battle Pet implementation, consider these DC-exclusive alternatives:

#### Option A: Pet Gladiator Arena (Simplified)
- 1v1 pet dueling (simpler mechanics)
- 3 abilities per pet (not 6)
- No wild capture (curated pet list)
- PvP focused
- **Effort: 8-10 weeks**

#### Option B: Pet Companion System (Enhancement)
- Pets provide minor passive buffs
- Pet "happiness" system
- Pet equipment/accessories
- Cosmetic evolution/stages
- **Effort: 4-6 weeks**

#### Option C: Pet Collection Focus (UI Only)
- Rich collection UI
- Pet statistics and lore
- Rarity tiers
- Collection achievements
- No combat system
- **Effort: 2-3 weeks**

---

## DC Exclusive Features

### Tier 1: High Impact, Achievable

#### 1. Collection Compendium
**Description:** Unified UI showing all collection progress

```
╔══════════════════════════════════════════════╗
║          DARK CHAOS COMPENDIUM               ║
╠══════════════════════════════════════════════╣
║  Mounts:      127/175 (73%)  ████████░░      ║
║  Pets:         89/156 (57%)  █████░░░░░      ║
║  Appearances: 312/850 (37%)  ███░░░░░░░      ║
║  Titles:       23/108 (21%)  ██░░░░░░░░      ║
║  Toys:         45/120 (38%)  ███░░░░░░░      ║
║  Achievements: 890/1200      ███████░░░      ║
╠══════════════════════════════════════════════╣
║  TOTAL: 42% Complete                         ║
╚══════════════════════════════════════════════╝
```

**Effort:** 1 week

#### 2. Collector Ranks & Rewards
**Description:** Achievement tiers for collection milestones

| Rank | Requirement | Reward |
|------|-------------|--------|
| Novice Collector | 10% total | Title + Tabard |
| Journeyman Collector | 25% total | Unique Mount |
| Expert Collector | 50% total | Transmog Set |
| Master Collector | 75% total | Special Pet |
| Grandmaster Collector | 90% total | Legendary Title + Effects |

**Effort:** 1-2 weeks

#### 3. Collection Sharing
**Description:** Link collections in chat, share with friends

```
/share mount Invincible
[Dark Chaos] Playerx shares: [Invincible's Reins] - Source: ICC 25HC
```

**Effort:** 3-4 days

#### 4. Wishlist System
**Description:** Track desired collectables, get notifications

- Add items to wishlist
- Get notifications when source is available
- Party members can see your wishlist
- Gift system integration

**Effort:** 1 week

### Tier 2: Medium Impact, Moderate Effort

#### 5. Collection Leaderboards
**Description:** Server-wide collection rankings

- Top collectors by category
- Weekly/monthly competitions
- Guild collection totals
- Seasonal collection events

**Effort:** 1-2 weeks

#### 6. Pet Companion Buffs
**Description:** Summoned companion pets provide minor buffs

| Pet Type | Buff | Effect |
|----------|------|--------|
| Cats | Luck | +1% drop chance |
| Dogs | Loyalty | +1% reputation gains |
| Mechanical | Efficiency | -1% repair costs |
| Magical | Insight | +1% experience |

**Effort:** 2-3 weeks

#### 7. Mount Equipment (Custom)
**Description:** Cosmetic additions to mounts

- Saddle variants
- Mount armor
- Glowing effects
- Trail effects

**Effort:** 2-3 weeks

#### 8. Collection Dailies
**Description:** Daily quests for collection progress

- "Capture a critter in [zone]"
- "Use 3 toys today"
- "Ride 5 different mounts"
- Rewards: collection tokens, cosmetics

**Effort:** 2 weeks

### Tier 3: High Impact, High Effort

#### 9. Pet Arena (Simplified Battle System)
**Description:** Streamlined pet combat for PvP

- 3 abilities per pet (Attack, Defend, Special)
- Simple type advantages
- Quick 1v1 battles
- Ranking system
- Seasonal rewards

**Effort:** 6-8 weeks

#### 10. Appearance Fusion
**Description:** Combine transmog effects

- Overlay particle effects on weapons
- Combine set bonuses visually
- Unique DC-only visual modifications

**Effort:** 4-6 weeks (requires client patch potentially)

#### 11. Collection Contracts
**Description:** Long-term collection goals with milestones

```
CONTRACT: Master of Mounts
├── Stage 1: Collect 25 mounts → Reward: Mount Speed +5%
├── Stage 2: Collect 50 mounts → Reward: Random Mount Button
├── Stage 3: Collect 100 mounts → Reward: Rare Mount Egg
└── Stage 4: Collect 150 mounts → Reward: Unique "Stable Master" Title
```

**Effort:** 2-3 weeks

---

## Implementation Priority Matrix

### Phase 1: Foundation (Weeks 1-4)
| Feature | Priority | Depends On |
|---------|----------|------------|
| Account-Wide Mounts | P1 | Aldori15 port |
| Account-Wide Pets | P1 | Aldori15 port |
| Collection Manager Core | P1 | DCAddonProtocol |
| Basic Mount Journal UI | P1 | - |
| Basic Pet Collection UI | P1 | - |

### Phase 2: Expansion (Weeks 5-8)
| Feature | Priority | Depends On |
|---------|----------|------------|
| Transmog Integration | P2 | Phase 1 |
| Titles Collection | P2 | Phase 1 |
| Collection Compendium | P2 | Phase 1 |
| Favorites System | P2 | Phase 1 |
| Statistics Tracking | P2 | Phase 1 |

### Phase 3: Enhancement (Weeks 9-12)
| Feature | Priority | Depends On |
|---------|----------|------------|
| Toy Box | P3 | Phase 1 |
| Heirlooms Tab | P3 | Phase 1 |
| Collector Ranks | P3 | Phase 2 |
| Wishlist System | P3 | Phase 2 |
| Collection Sharing | P3 | Phase 2 |

### Phase 4: DC Exclusive (Weeks 13+)
| Feature | Priority | Depends On |
|---------|----------|------------|
| Pet Companion Buffs | P4 | Phase 2 |
| Collection Leaderboards | P4 | Phase 3 |
| Collection Dailies | P4 | Phase 3 |
| Pet Arena (if approved) | P5 | Phase 2 |

---

## Technical Integration Notes

### Aldori15 → DC Migration Path

1. **Port Scripts**
   - Copy AccountMounts.lua, AccountPets.lua, etc.
   - Replace `CharDBQuery` with DC's database abstraction
   - Add DCAddonProtocol message handlers

2. **Extend with UI Sync**
   ```lua
   -- After Aldori15 login sync, send data to client
   DC.Module.COLL:Send("MOUNT_LIST", player:GetGUID(), mountData)
   ```

3. **Add Statistics Layer**
   ```sql
   ALTER TABLE accountwide_mounts ADD COLUMN source VARCHAR(64);
   ALTER TABLE accountwide_mounts ADD COLUMN first_learned_char INT;
   ALTER TABLE accountwide_mounts ADD COLUMN is_favorite TINYINT DEFAULT 0;
   ```

### Database Schema Additions

```sql
-- DC Collection Extensions
CREATE TABLE dc_collection_stats (
    account_id INT,
    collection_type ENUM('mount','pet','toy','transmog','title','achievement'),
    collected_count INT,
    total_available INT,
    last_updated TIMESTAMP,
    PRIMARY KEY (account_id, collection_type)
);

CREATE TABLE dc_collection_wishlist (
    account_id INT,
    item_type ENUM('mount','pet','toy','transmog'),
    item_id INT,
    added_at TIMESTAMP,
    note VARCHAR(255),
    PRIMARY KEY (account_id, item_type, item_id)
);

CREATE TABLE dc_collection_favorites (
    account_id INT,
    character_guid INT,  -- Per-character favorites
    item_type ENUM('mount','pet','toy'),
    item_id INT,
    slot INT,  -- Favorite slot 1-10
    PRIMARY KEY (character_guid, item_type, slot)
);
```

---

## Conclusion

### Recommended Path Forward

1. **Do:** Implement unified collection system with Mounts, Pets, Transmog, Titles
2. **Do:** Port Aldori15 account-wide patterns for server-side foundation
3. **Do:** Add DC-exclusive features (Compendium, Ranks, Wishlist, Sharing)
4. **Consider:** Toy Box and Heirlooms Tab as Phase 3
5. **Defer:** Full Battle Pet combat system (too complex for ROI)
6. **Alternative:** Simplified Pet Arena if pet combat is desired

### Final Recommendation

Focus development resources on **collection breadth and quality** rather than implementing the complex MoP Battle Pet system. The turn-based combat system alone would require 20+ weeks of development, while comprehensive collection UI with DC-exclusive features can be completed in 8-12 weeks and provide more immediate player value.

---

## References

- [Aldori15/azerothcore-eluna-accountwide](https://github.com/Aldori15/azerothcore-eluna-accountwide)
- [Wowpedia: Pet Battle System](https://wowpedia.fandom.com/wiki/Pet_Battle_System)
- [Wowpedia: Collections](https://wowpedia.fandom.com/wiki/Collections)
- [Wowpedia: Toy Box](https://wowpedia.fandom.com/wiki/Toy_Box)
- [Wowpedia: Heirloom](https://wowpedia.fandom.com/wiki/Heirloom)
- Internal: 00_COLLECTION_SYSTEM_OVERVIEW.md
- Internal: 05_PROTOCOL_INTEGRATION.md
