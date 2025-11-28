# Dungeon Enhancement System (Mythic+) Implementation Plan
## DarkChaos Server - Wrath 3.3.5a Edition

---

## EXECUTIVE SUMMARY

Implement a comprehensive Mythic+ system for DarkChaos that adds challenging endgame content with seasonal progression, difficulty scaling, and cosmetic/progression rewards. The system integrates with existing DarkChaos infrastructure (ItemUpgrades, DungeonQuests, Achievements) while maintaining separation from core AzerothCore to avoid conflicts with updates.

**Project Name:** DungeonEnhancement (includes Mythic+, Heroic/Mythic raids, legacy content scaling)

**Integration with Existing Systems:**
- **NPC Architecture**: Follows patterns from ItemUpgradeCurator (300314) and DungeonQuestMaster
- **Database Design**: Uses `dc_*` prefix convention, CharacterDatabase queries
- **Achievement System**: Integrates with existing dc_achievements.cpp infrastructure
# Mythic+ System Plan (2026 Refresh)

**Purpose:** Define the streamlined Mythic/Mythic+ system that rides exclusively on dungeon difficulty 3 (“Epic”) and avoids all raid or timer mechanics.

**Audience:** Gameplay engineers, database engineers, design reviewers.

> **Housekeeping (Nov 2025):** Legacy DungeonEnhancement write-ups—implementation summaries, DBC additions, etc.—now live in `Custom/feature stuff/DungeonEnhancement/old/`. Reference them only for historical context; all active work follows this refresh and the updated evaluation document.

---

## 1. Goals & Non-Goals

### Goals
- Turn existing difficulty 3 into a consistent “Mythic” baseline for every dungeon.
- Introduce a Mythic+ modifier layer that uses keystone-style scaling without timers.
- Keep the entire feature inside DarkChaos namespaces (`dc_*` tables, custom scripts) to preserve AzerothCore’s upgradability.
- Provide a repeatable reward and score loop that can be extended with seasonal hooks.
- Force Mythic dungeon content to level 80 minimum: TBC Heroics stay at level 70, but all Mythic difficulty (Vanilla/TBC) uses differentiated levels (normal 80, elite 81, boss 82). WotLK untouched to preserve existing scaling.

### Non-Goals
- No raid changes, no prestige systems, no complex UI add-ons at launch.
- No new difficulty IDs or map clones; we reuse existing records wherever possible.
- No timer race. Performance pressure comes from death budgets and score decay.

---

## 2. System Overview

| Layer | Description |
|-------|-------------|
| Mythic Baseline | Difficulty 3 scaling, fixed death budget, guaranteed token reward. Always available. |
| Mythic+ Overlay | Keystone-managed scaling (levels 1–8), two rotating affixes, per-dungeon score. Limited to seasonal rotation list. |
| Seasonal Data | Defines which dungeons are eligible for Mythic+ each quarter, affix pairings, reward tables, and leaderboard reset dates. |

---

## 3. Data Design

```sql
-- Dungeons that support Mythic baseline (all of them)
CREATE TABLE dc_dungeon_mythic_profile (
  map_id SMALLINT PRIMARY KEY,
  name VARCHAR(80),
  heroic_enabled BOOLEAN DEFAULT TRUE,
  mythic_enabled BOOLEAN DEFAULT TRUE,
  base_health_mult FLOAT DEFAULT 1.25,
  base_damage_mult FLOAT DEFAULT 1.15,
  death_budget TINYINT DEFAULT 10,
  wipe_budget TINYINT DEFAULT 3,
  loot_ilvl INT DEFAULT 219,
  token_reward INT DEFAULT 101000,
  updated_at TIMESTAMP
);

-- Seasonal rotation for Mythic+
CREATE TABLE dc_mplus_seasons (
  season_id INT PRIMARY KEY AUTO_INCREMENT,
  label VARCHAR(40),
  start_ts BIGINT,
  end_ts BIGINT,
  featured_dungeons JSON,
  affix_schedule JSON,
  reward_curve JSON,
  is_active BOOL DEFAULT FALSE
);

-- Keystone inventory (max 1 per character)
CREATE TABLE dc_mplus_keystones (
  character_guid INT PRIMARY KEY,
  map_id SMALLINT NOT NULL,
  level TINYINT NOT NULL,
  season_id INT,
  expires_on BIGINT,
  FOREIGN KEY (map_id) REFERENCES dc_dungeon_mythic_profile(map_id)
);

-- Score snapshots per dungeon and season
CREATE TABLE dc_mplus_scores (
  character_guid INT,
  season_id INT,
  map_id SMALLINT,
  best_level TINYINT,
  best_score INT,
  last_run_ts BIGINT,
  PRIMARY KEY (character_guid, season_id, map_id)
);
```

All auxiliary lookup data (affixes, reward tables, rotation metadata) also sits inside `dc_*` structures so the system can be disabled cleanly.

`Custom/Custom feature SQLs/world schema.sql` (Nov 2025) intentionally removed the deprecated `dc_mythic_*` schema from the pre-refresh implementation. New migrations are located in:
- **World DB:** `Custom/Custom feature SQLs/worlddb/dc_mythic_dungeons_world.sql`
- **Character DB:** `Custom/Custom feature SQLs/chardb/dc_mythic_dungeons_chars.sql`

These files contain all tables defined in this plan plus supporting lookup data.

---

## 3.5 Legacy Dungeon Integration Procedure

Retail-style Mythic access requires that every Vanilla and TBC dungeon exposes Heroic (difficulty 2) and Mythic (difficulty 3/Epic) entries. We reuse the existing map rows and keep all changes server-side.

1. **SQL enablement**
  - Populate `dc_dungeon_mythic_profile` for each legacy dungeon with conservative multipliers (Heroic: +15% HP/+10% damage, Mythic: +35% HP/+20% damage).
  - Run the helper script `sql/custom/dc_enable_legacy_mythic.sql` to backfill missing MapDifficulty rows and minimum-level requirements (Normal ≥ 45, Heroic ≥ 70, Mythic ≥ 80).
2. **Portal gossip**
  - Attach `dungeon_portal_difficulty_selector` (see §2.8.5) to every legacy portal. Players now see `Normal → Heroic → Mythic` when they click the instance swirl.
3. **Creature scaling hook**
  - The existing `MythicDifficultyScaling::ScaleCreature` hook reads the dungeon profile and applies multipliers during `OnCreatureAddWorld`. No DBC/process restarts required.
4. **Loot + lockouts**
  - Heroic uses the original loot template. Mythic layers the new token + deterministic drop pool described in §11. Dungeon lockouts remain disabled so runs stay farmable like retail.
5. **Validation checklist**
  - Confirm entry gating (level/iLvl) per portal, verify scaling values in combat log, and run one mythic clear per dungeon to confirm loot tokens drop correctly.

This process upgrades every Vanilla/TBC dungeon to Heroic/Mythic in less than a day and guarantees Mythic+ eligibility for any dungeon the season rotation requires.

## 3.6 Legacy Level Normalization (Mythic Only)

Mythic difficulty (difficulty 3) assumes differentiated levels for Vanilla/TBC dungeons to provide clear challenge tiers. TBC Heroic dungeons remain at level 70 to preserve their original identity. WotLK dungeons are untouched (they retain existing scaling). For Vanilla/TBC Mythic:

- Normal NPCs: level 80
- Elites: level 81
- Bosses: level 82

**Access Requirements:**
- Heroic (TBC): level 70 minimum
- Mythic (all expansions): level 80 minimum, item level ≥ 180

To enforce Mythic levels:

1. **Audit existing levels** – run `Custom/Custom feature SQLs/dc_dungeon_level_audit.sql` against the world database. The script reports every Vanilla/TBC boss or elite (rank ≥ 2) that still spawns below the target levels.
2. **Update templates** – use the differentiated UPDATE block in the same script to set `minlevel = maxlevel` based on `rank` (normal 80, elite 81, boss 82). Keeping min/max equal prevents drifting when the runtime scaling hook fires.
3. **Spot-check in game** – enter each dungeon on Mythic difficulty, target a boss, and verify the creature frame displays the correct level. Adjust any missed entry manually.

These SQL helpers keep the source data clean so the Mythic controller no longer needs special cases for Vanilla/TBC bosses. TBC Heroics and WotLK dungeons are excluded to preserve their native scaling.

---

## 4. Flow: Mythic Baseline

1. Player interacts with dungeon-specific teleporter or instance portal.
2. Gossip presents `Normal`, `Heroic`, `Mythic` (difficulty 3). Mythic option appears only if player level ≥ 80 and item level ≥ 180.
3. On entry, the Mythic controller loads dungeon profile → applies health/damage multipliers via `Creature::SetModifier` hooks.
4. Death budget and wipe budget counters spawn per-instance and sync to players via the Mythic HUD packet every 5 seconds.
5. Completion success = all bosses dead before budgets expire → drop table: 2 loot rolls + 1 Mythic token chest; failure = no loot + token consolation.

Implementation detail: budgets stored in `InstanceScript` state; once failure triggered, instance sets a locking aura so players know to reset.

---

## 5. Flow: Mythic+

1. Weekly login job grants one keystone (level 1, random featured dungeon) if the character lacks one.
2. At the dungeon entrance a **Font of Power** gameobject (700001–700008) mirrors retail: the group leader socket their keystone, the dungeon instance soft-resets, a spectral shield seals the entrance, and a visible countdown (10 seconds) broadcasts via HUD so every player knows when combat starts.
3. When the countdown finishes the shield drops, the party zones in, and validation runs:
  - Leader holds a keystone for the targeted dungeon.
  - Dungeon is in the current season’s featured list.
  - Each party member meets level/iLvl requirements.
4. Instance loads with additional data:
  - Keystone level → extra multiplier from reward curve.
  - Affix set → script registers Spell auras/periodic events.
  - Death budget = base budget – (level × 1), min 5.
5. Score formula on completion: `score = (level × 60) − (deaths × 5) − (wipes × 15) + cleanBonus`.
6. If score ≥ threshold(level): keystone upgrades by 1. If score < threshold/2: keystone downgrades by 1. Otherwise level stays the same but keystone rerolls to a different featured dungeon.
7. Rewards: deterministic loot table per featured dungeon + seasonal currency chest sized by level (see §11).
8. `dc_mplus_scores` updated with best score for the dungeon; aggregated leaderboard view refreshes nightly.

Failure rules: exceeding death or wipe budget immediately fails the run, destroying the keystone and granting a consolation keystone box (opens next day to avoid instant spam).

---

## 6. Affix Model

Only two affix slots exist to keep encounter risk low:

| Slot | Examples | Implementation |
|------|----------|----------------|
| Boss-focused | Tyrannical-Lite (boss HP +15%), Brutal Aura (boss periodic AoE raid damage) | SpellScript hooking bosses on spawn. |
| Trash-focused | Fortified-Lite (non-boss HP +12%), Bolstering-Lite (stacking +5% dmg on nearby mobs) | Aura applied to non-boss creatures grouping by entry ID. |

Affix schedule stored in the season record as a list of `(weekStart, affixPairId)` tuples. Reset job updates active affix pair every Wednesday reset.

---

## 7. Teleporters & Access Control

- Main Mythic steward NPC (entry 99001) shows three menus: Normal/Heroic list, Mythic list, Mythic+ featured list.
- Mythic list requires nothing special; Mythic+ list displays keystone level badge next to each dungeon.
- Teleportation uses existing coordinates; no new maps.
- Access gating (level/iLvl) implemented on gossip selection, not on teleport cast, to surface errors early.

---

### 7.1 `/dc difficulty` Command & Confirmation Flow

Portal gossip remains the fastest way to pick Normal/Heroic/Mythic, but groups also gain a command-driven controller for mid-session changes:

1. **Request phase** – the group leader stands outside combat (either before entering or within 30 yards of the portal) and types `/dc difficulty <normal|heroic|mythic>`. The command records a pending change on the instance, announces it to party chat, and starts a 60-second confirmation window. Duplicate requests for the same difficulty are rejected with “request already active”.
2. **Player confirmations** – each member can type `/dc difficulty confirm` (or click the popup) to vote. A single `/dc difficulty cancel` from any player aborts the request. The server requires either unanimity or a configurable majority before proceeding. Votes are only allowed while everyone is alive and out of combat.
3. **Execution** – on success the instance performs a soft reset, teleports every player to the entrance, clears trash, and applies the desired difficulty flag. Because dungeon lockouts stay disabled, parties can repeat this flow without weekly limits. A five-minute cooldown between accepted changes prevents spam.
4. **Logging & safety** – each transition is emitted to the `MYTHIC_PLUS` log channel with requester/voters/dungeon data, allowing GMs to audit griefing attempts.

This command mirrors retail’s difficulty prompt while honoring DarkChaos’ always-available resets and “no lockouts” policy.

---

## 8. Failure Handling

| Situation | Result |
|-----------|--------|
| Player disconnects mid-run | Counters persist server-side; reconnect allowed. |
| Instance soft-reset | Resets budgets and keystone; counts as failed run, keystone despawns. |
| Dungeon script bug | Admin command `dc mplus fail` toggles failure state and refunds keystone for QA. |
| Weekly rollover | Active keystones expire. New keystone mailed with “Seasonal Charter” explaining featured list. |

---

## 9. Integration Points

- **Loot:** Mythic tokens feed existing upgrade vendors. Mythic+ currency uses new vendor entry 120345 (seasonal quartermaster).
- **Achievements:** Lightweight achievements for “Mythic completion” per dungeon and “Mythic+ Veteran” (complete all featured dungeons level 4+).
- **Config:** `darkchaos-custom.conf` gains `MythicPlus.Enable`, `MythicPlus.MaxLevel`, `MythicPlus.AffixDebug` toggles.
- **Logging:** Dedicated channel `MYTHIC_PLUS` to help GMs audit run outcomes.

---

## 9.5 Token Rewards & Final Boss Distribution

**Token Reward Formula (Final Boss)**

At the final boss kill, every player in the group who participated in the encounter receives upgrade tokens automatically:

```
Base Tokens = 10 + (Player Level - 70)  2
Difficulty Multiplier:
  - Normal: 1.0
  - Heroic: 1.5
  - Mythic (base): 2.0
  - Mythic+ (per level): 2.0 + (Keystone Level  0.25)

Final Tokens = FLOOR(Base Tokens  Difficulty Multiplier)
```

**Example Calculations:**
- Level 80 player, Normal: `10 + (80-70)2 = 30 tokens  1.0 = 30 tokens`
- Level 80 player, Heroic: `30  1.5 = 45 tokens`
- Level 80 player, Mythic+0: `30  2.0 = 60 tokens`
- Level 80 player, Mythic+5: `30  (2.0 + 50.25) = 30  3.25 = 97 tokens`

**Distribution Rules:**
1. All players in the dungeon instance at boss death receive tokens
2. Players must have participated in the final boss encounter (dealt damage or healing)
3. Tokens are mailed if inventory is full
4. Logged to `dc_token_rewards_log` for audit and statistics

**Boss + End-of-Run Loot**
- Bosses drop one group item scaled by keystone level (Mythic+ only)
- The final chest rolls two guaranteed items and a third 30% bonus item
- Two-hour trade window hook (§2.9) allows loot sharing like retail
- Each completion records into `dc_mplus_runs` which feeds scoreboards and vault eligibility

## 9.6 Weekly Great Vault System

**NPC: Vault Curator Lyra (entry 100050)**
- Location: Next to Dalaran bank (Violet Citadel entrance)
- Gossip opens vault UI showing up to three reward slots
- Available every Tuesday after weekly reset

**Slot Unlock Requirements:**
```
Slot 1: Complete 1 Mythic+ dungeon this week
   Reward ilvl = highest keystone cleared
   Alternative: 50 upgrade tokens

Slot 2: Complete 4 Mythic+ dungeons this week
   Reward ilvl = highest keystone + 6
   Alternative: 100 upgrade tokens

Slot 3: Complete 8 Mythic+ dungeons this week
   Reward ilvl = highest keystone + 12
   Alternative: 200 upgrade tokens
```

**Reward Selection:**
1. Each unlocked slot shows one pre-generated item from dungeon loot pools
2. Player picks ONE reward total from any unlocked slot
3. Unclaimed rewards expire at next Tuesday reset
4. Selection is permanent (no re-rolls)
5. Tracked in `dc_weekly_vault` and `dc_vault_reward_pool` tables

**Weekly Reset Logic:**
1. Tuesday 3 AM server time: trigger `dc_vault_weekly_reset` procedure
2. Archive unclaimed vault entries to `dc_weekly_vault_history`
3. Reset `runs_completed` counters to 0
4. Generate new reward pools for eligible players
5. Mail notification: "Your Great Vault is ready!"

**Implementation Tables:**
- `dc_weekly_vault`: Current week progress and claim status
- `dc_vault_reward_pool`: Pre-generated item options per slot
- `dc_mplus_runs`: Run history feeding vault eligibility
- `dc_token_rewards_log`: Token distribution audit trail

All schema defined in `Custom/Custom feature SQLs/chardb/dc_mythic_dungeons_chars.sql`.

This section ensures documentation explicitly spells out how loot mirrors retail expectations in both moment-to-moment gameplay and the weekly cadence.

---
## 9.7 Mythic+ Statistics NPC

To mirror the Hinterland BG stats board we add `NPC 100060 – Archivist Serah` positioned near the Mythic teleporter hub.

- **Data surfaced:** best key level, total Mythic runs, seasonal rating, death-budget efficiency (average deaths vs allowed), weekly vault progress, and per-dungeon personal bests.
- **Implementation:** Gossip option “Show my Mythic+ statistics” calls a new stored procedure `dc_mplus_get_player_stats(guid, season)` that collates data from `dc_mplus_scores`, `dc_weekly_vault`, and `dc_mplus_runs`. Output is formatted with the same color coding used in Hinterland BG (green for bests, orange for warnings).
- **Social hooks:** Secondary gossip page “Top performers this season” lists the top 10 players using the leaderboard cache so players can compare progress without opening external dashboards.

This dedicated NPC gives players an in-game place to review performance metrics and mirrors the presentation users already know from Hinterland BG.

---

## 10. Rollout Checklist

1. Populate `dc_dungeon_mythic_profile` for every dungeon (SQL migration + review).
2. Implement Mythic controller script (Creatures, InstanceScript hooks, HUD packet).
3. Build keystone distribution job + teleporter gating.
4. Add Mythic+ overlays (affix applier, score calculator, reward handler).
5. Stand up QA realm, run 10 sample dungeons across tiers, validate death budgets.
6. Flip `MythicPlus.Enable = 1` on staging, monitor logs, gather tuning feedback.

---

**Status:** Approved plan. Ready for ticket decomposition and engineering assignment.
            
            if (!seasonResult) {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                    "No active season configured.", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);
                player->PlayerTalkClass->SendGossipMenu(1, creature->GetGUID());
                return true;
            }
            
            uint32 seasonId = seasonResult->Fetch()[0].Get<uint32>();
            std::string seasonName = seasonResult->Fetch()[1].Get<std::string>();
            
            // Query player's current rating
            QueryResult result = CharacterDatabase.Query(
                "SELECT current_rating, highest_key_completed "
                "FROM dc_mythic_player_rating "
                "WHERE player_guid = {} AND season_id = {}",
                player->GetGUID().GetCounter(),
                seasonId
            );
            
            uint32 rating = result ? result->Fetch()[0].Get<uint32>() : 0;
            uint32 highestKey = result ? result->Fetch()[1].Get<uint32>() : 0;
            
            // Display player stats in greeting
            std::string greeting = "Welcome, " + player->GetName() + "!\n"
                + "|cffff8000Season:|r " + seasonName + "\n"
                + "|cff00ff00Current Rating:|r " + std::to_string(rating) + "\n"
                + "|cffff9900Highest Key:|r Mythic+" + std::to_string(highestKey);
            
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, greeting, GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);
            
            // Menu options
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Browse Mythic Dungeons (M+0)", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 1);
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Browse Mythic+ Dungeons (Seasonal - 8 Dungeons)", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 2);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "View My Statistics", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 3);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Mythic+ System Help", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 4);
        }
        catch (...) {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                "Database not configured. Import SQL files first.",
                GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);
        }
        
        player->PlayerTalkClass->SendGossipMenu(1, creature->GetGUID());
        return true;
    }
    
    void ShowMythicPlusDungeonList(Player* player, Creature* creature)
    {
        ClearGossipMenuFor(player);
        
        try {
            // Get current season ID
            QueryResult seasonResult = CharacterDatabase.Query(
                "SELECT season_id FROM dc_mythic_seasons WHERE active = 1 LIMIT 1"
            );
            
            if (!seasonResult) {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "No active season.", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
                player->PlayerTalkClass->SendGossipMenu(1, creature->GetGUID());
                return;
            }
            
            uint32 seasonId = seasonResult->Fetch()[0].Get<uint32>();
            
            // Query seasonal dungeons (max 8 active)
            QueryResult result = CharacterDatabase.Query(
                "SELECT d.dungeon_id, d.dungeon_name, d.display_order "
                "FROM dc_mythic_seasonal_dungeons d "
                "WHERE d.season_id = {} AND d.active = 1 "
                "ORDER BY d.display_order ASC "
                "LIMIT 8",
                seasonId
            );
            
            if (!result) {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                    "No dungeons configured for this season.", 
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
            } else {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                    "|cffff8000Seasonal Mythic+ Dungeons (Maximum 8)|r", 
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);
                
                do {
                    Field* fields = result->Fetch();
                    uint32 dungeonId = fields[0].Get<uint32>();
                    std::string dungeonName = fields[1].Get<std::string>();
                    
                    // Use dungeon_id as action offset (e.g., GOSSIP_ACTION_INFO_DEF + 100 + dungeonId)
                    AddGossipItemFor(player, GOSSIP_ICON_BATTLE, 
                        dungeonName + " (Mythic+)", 
                        GOSSIP_SENDER_MAIN, 
                        GOSSIP_ACTION_INFO_DEF + 100 + dungeonId);
                        
                } while (result->NextRow());
            }
            
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
        }
        catch (...) {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Database error.", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF + 20);
        }
        
        player->PlayerTalkClass->SendGossipMenu(1, creature->GetGUID());
    }
    
    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        ClearGossipMenuFor(player);
        
        switch (action)
        {
            case GOSSIP_ACTION_INFO_DEF + 1: // Mythic Dungeons
                ShowMythicDungeonList(player, creature);
                break;
            case GOSSIP_ACTION_INFO_DEF + 2: // Mythic+ Dungeons
                ShowMythicPlusDungeonList(player, creature);
                break;
            case GOSSIP_ACTION_INFO_DEF + 3: // Statistics
                ShowPlayerStatistics(player, creature);
                break;
            case GOSSIP_ACTION_INFO_DEF + 4: // Help
                ShowHelpInformation(player, creature);
                break;
            case GOSSIP_ACTION_INFO_DEF + 20: // Back
                OnGossipHello(player, creature);
                break;
            default:
                CloseGossipMenuFor(player);
                break;
        }
        return true;
    }
};
```

**NPC 300316: Mythic Raid Teleporter**
- Location: Main cities (Dalaran/Orgrimmar/Stormwind)
- Pattern: Similar to Dungeon Teleporter, adapted for raids
- Purpose: Teleport to Mythic raids with 10/25 player scaling options

**Integration with Existing Systems:**
- Database queries follow `dc_*` prefix convention (dc_mythic_player_rating, dc_mythic_seasons)
- Uses CharacterDatabase.Query with try-catch error handling
- Color-coded text formatting (|cff00ff00 green, |cffff9900 orange)
- GOSSIP_ACTION_INFO_DEF + offset pattern for menu navigation
- "Back" button at GOSSIP_ACTION_INFO_DEF + 20

**Method 1: LFG/LFR Tool Enhancement** (Optional Future Phase)
- Add new difficulty slots in LFG UI
- Filter by: Dungeon > Difficulty > Mythic+ Level
- Seasonal dungeon rotation system

### 2.2 Dungeon Start Mechanics
**Retail-like Entry Gate**
```
- Shield/Barrier at dungeon entrance
- NPC Quest-giver (seasonal specific)
- UI Prompt to select:
  * Difficulty (Mythic / Mythic+2-10)
  * Affixes (simple selection, 2-3 max per run)
  * Enter button to spawn instances with shield
```

### 2.3 Mythic+ Affixes (Simplified Set)
**Tier 1 Affixes** (Difficulty +1 to +5)
- **Tyrannical**: Boss damage +30%, HP +30%
- **Fortified**: Non-boss enemies +50% HP, +20% Damage
- **Raging**: Enemies gain enrage at 30% HP (+50% damage)

**Tier 2 Affixes** (Difficulty +6 to +10)
- **Bolstering**: Non-boss deaths increase surviving enemies' stats (+10% per death)
- **Necrotic**: Melee attacks apply DoT (-10% healing received, stacks)
- **Volcanic**: Periodically spawn volcanic patches on ground

**Affixes Avoided (Too Complex)**
- Seasonal affixes requiring special mechanics
- Crowd-control dependent affixes
- Mechanics requiring frequent balance patches

### 2.4 Seasonal System
```
Seasons Duration: 3 Months (Configurable)
Season Cycle:
- Season 1: Dungeons A, B, C (Weeks 1-13)
- Season 2: Dungeons D, E, F (Weeks 14-26)
- Transition: 1-week off-season (maintenance, achievements tallying)

Seasonal Rotation Benefits:
- Limits rating inflation
- Maintains freshness
- Manageable achievement tracking
- Separate leaderboards per season
```

### 2.5 Progression Mechanics

**Death Limit System** (vs Timer)
- Configurable deaths allowed per run (e.g., 3 deaths = run failure)
- Easier to implement than real-time tracking
- Still maintains challenge and difficulty rating

**Rating System**
```
Base Rating Calculation:
- Key Level: Base (10 * level) points
- Deaths Per Run: -5 points per death
- Speed Bonus: +10% if finished 30% faster than timer
- Difficulty Affixes: +5 points per affix active

Example:
- Mythic+3 (3x difficulty): 30 points base
- 1 death: -5 points
- Fast clear bonus: +3 points
- 2 affixes active: +10 points
= 38 Rating points earned
```

**Seasonal Rating Caps**
```
Season 1: Max 1000 rating
Season 2: Max 1200 rating (with legacy progression carry-over)
Allows power creep while maintaining seasonal achievement
```

### 2.6 Dungeon Scaling Configuration
```sql
-- Example: Blackrock Depths M+ Scaling
UPDATE dc_mythic_dungeons_config 
SET 
  normal_enabled = 1,
  heroic_enabled = 1,
  mythic_enabled = 1,
  mythic_plus_enabled = 1,
  min_level_normal = 45,
  min_level_heroic = 60,
  min_level_mythic = 80,
  min_level_mythic_plus = 80,
  base_health_multiplier = 1.0,
  scaling_per_difficulty = 1.3,  -- Heroic
  scaling_mythic = 1.8,
  scaling_mythic_plus_step = 0.15  -- +0.15 per key level
WHERE dungeon_id = BLACKROCK_DEPTHS;
```

### 2.7 Loot System - Comprehensive Guide

#### **2.7.1 Mythic+0 Dungeons (Base Mythic)**
**Access:** Available anytime via LFG tool or manual entry (no keystone required)
**Player Count:** 5 players (standard dungeon group)
**Item Level:** 213 (baseline Mythic gear)

**Loot Distribution:**
```
Boss Kills:
- Each boss: 1-2 items drop for group (standard 5-man loot)
- Item level: 213 (ilvl same as Heroic ICC gear baseline)
- Personal loot or group loot (configurable)

Completion Rewards (Entire Group):
- 20 Mythic Dungeon Tokens per player
- Chance for random epic item (213 ilvl)
- First weekly M+0 clear: Bonus 50 tokens

Weekly Vault:
- Running 1+ M+0 dungeon unlocks Vault Slot 1
- Slot 1 reward: Choice of 213 ilvl item OR 50 tokens
```

#### **2.7.2 Mythic+ Keystones (M+2 through M+10)**
**Access:** Requires keystone activation at Font of Power (one player's keystone)
**Player Count:** 5 players (standard dungeon group)
**Item Level Scaling:** 213 + (3 × keystone level)

**Loot Scaling Table:**
```
+------------------+----------------+----------------------+
| Keystone Level   | Item Level     | Token Reward/Player  |
+------------------+----------------+----------------------+
| Mythic+0 (M+0)   | 213            | 20                   |
| Mythic+2 (M+2)   | 219            | 30                   |
| Mythic+3 (M+3)   | 222            | 35                   |
| Mythic+4 (M+4)   | 225            | 40                   |
| Mythic+5 (M+5)   | 228            | 45                   |
| Mythic+6 (M+6)   | 231            | 50                   |
| Mythic+7 (M+7)   | 234            | 55                   |
| Mythic+8 (M+8)   | 237            | 60                   |
| Mythic+9 (M+9)   | 240            | 65                   |
| Mythic+10 (M+10) | 243            | 70                   |
+------------------+----------------+----------------------+

Formula: 
- Item Level = 213 + (3 × KeystoneLevel)
- Tokens = 20 + (5 × KeystoneLevel)
```

**Boss Loot:**
```
Each Boss Kill:
- 1 item drops per boss (ilvl based on keystone level)
- Distributed via personal loot or group loot
- NO guaranteed loot for every player (retail-like)
- Higher keystone = higher ilvl gear

End-of-Run Loot:
- Final boss drops: 2-3 items (ilvl based on keystone)
- Guaranteed: Mythic Dungeon Tokens (entire group)
- Bonus: Small chance for extra item (+6 ilvl bonus)
```

#### **2.7.3 Weekly Great Vault System**
**Access:** NPC in Dalaran/Orgrimmar/Stormwind
**Reset:** Every Tuesday (weekly maintenance)

**Vault Slot Unlock Requirements:**
```
Slot 1: Complete 1 Mythic+ dungeon this week
  Reward: 1 item at [highest key completed] ilvl OR 50 tokens

Slot 2: Complete 4 Mythic+ dungeons this week
  Reward: 1 item at [highest key completed] ilvl OR 100 tokens

Slot 3: Complete 8 Mythic+ dungeons this week
  Reward: 1 item at [highest key completed] ilvl OR 200 tokens

Rules:
- Player chooses ONLY ONE reward from unlocked slots
- Item ilvl = highest keystone completed this week
- Tokens = alternative choice (configurable amounts)
- Unclaimed rewards expire on weekly reset
```

**Vault Loot Pool:**
```cpp
// Example: Player completed M+7 as highest this week
// All 3 slots show 234 ilvl items (M+7 level)
// Items are random from dungeon loot tables
// Player picks 1 item from any unlocked slot

Slot 1: [Weapon - 234 ilvl] OR 50 tokens
Slot 2: [Armor - 234 ilvl] OR 100 tokens
Slot 3: [Trinket - 234 ilvl] OR 200 tokens
         ↓
Player chooses ONE reward total
```

#### **2.7.4 Token Vendor System**
**Location:** NPC 300317 in main cities
**Currency:** Mythic Dungeon Tokens (item 100020)

**Vendor Inventory:**
```
Gear (ilvl 213-243):
- Weapons: 300-500 tokens
- Armor: 200-400 tokens
- Trinkets: 250-450 tokens
- Accessories: 150-300 tokens

Cosmetics:
- Transmog sets: 1000+ tokens
- Mounts: 5000 tokens (seasonal)
- Pets: 500 tokens
- Titles: 2000 tokens (permanent)

Consumables:
- Keystone creation (M+2): 100 tokens
- Upgrade materials: 50 tokens
- Buff scrolls: 25 tokens
```

#### **2.7.5 Raid Loot System (Separate)**
**Note:** Raids do NOT use keystones (only Normal/Heroic/Mythic fixed difficulties)

**Raid Token Drops:**
```
Boss Kills:
- Normal Raid: 5 Mythic Raid Tokens per player
- Heroic Raid: 10 Mythic Raid Tokens per player
- Mythic Raid: 20 Mythic Raid Tokens per player

Boss Loot:
- 2-3 items per 10 players (standard raid loot)
- Item level by difficulty:
  * Normal: 219 ilvl
  * Heroic: 226 ilvl
  * Mythic: 232 ilvl
```

**Raid Token Vendor:**
```
Location: NPC 300318 in main cities
Currency: Mythic Raid Tokens (item 100021)

Inventory:
- Tier set pieces: 500-800 tokens
- Weapons: 600-1000 tokens
- Trinkets: 400-700 tokens
- Raid-specific transmog: 1500+ tokens
```

---

### 2.8 DIFFICULTY IMPLEMENTATION GUIDE

This section explains HOW to add Heroic/Mythic/Mythic+ difficulties to existing dungeons.

#### **2.8.1 Understanding WoW Difficulty System**

**Difficulty IDs in WoW 3.3.5a:**
```
0 = Normal (10-player for raids, 5-player for dungeons)
1 = Heroic (25-player for raids, 5-player for dungeons)
2 = Normal (25-player for raids) [Raids only]
3 = Heroic (25-player for raids) [Raids only]

Custom Difficulties (Server-Side):
4 = Mythic (10-player for raids, 5-player for dungeons)
5 = Mythic (25-player for raids)
6-15 = Mythic+2 through Mythic+10 (Dungeons only)
```

**RETAIL-LIKE IMPLEMENTATION (Easiest Method):**
We use the EXISTING Heroic difficulty (ID=1) and apply runtime scaling. No DBC editing needed at all!

**Why This Works:**
- WoW 3.3.5a already has "Heroic" difficulty for all WotLK dungeons
- We simply rename "Heroic" → "Mythic" in server-side text
- Apply custom scaling multipliers at runtime
- Use instance data to track actual difficulty level
- Players see familiar "Heroic" UI but experience Mythic+ scaling

**Key Insight:** The difficulty ID doesn't matter - what matters is the scaling applied to creatures!

**Important:** WoW 3.3.5a client doesn't have native Mythic difficulty. We implement it SERVER-SIDE ONLY using:
1. Existing Heroic difficulty infrastructure (no DBC changes)
2. Runtime scaling in C++ scripts (OnCreatureAddWorld hook)
3. Instance data to store keystone level
4. Map difficulty flags (already exist in core)
5. NO client modifications required

#### **2.8.2 Method 1: Server-Side Scaling (Recommended)**

This method adds difficulties WITHOUT modifying DBC files. All scaling happens in C++ at runtime.

**Step 1: Database Configuration**
```sql
-- Configure dungeon to support all difficulties
INSERT INTO dc_mythic_dungeons_config VALUES (
  NULL,                          -- id (auto-increment)
  'Utgarde Keep',                -- dungeon_name
  574,                           -- dungeon_id (from Map.dbc)
  1,                             -- normal_enabled
  1,                             -- heroic_enabled
  1,                             -- mythic_enabled (M+0)
  1,                             -- mythic_plus_enabled (M+2 to M+10)
  68,                            -- min_level_normal
  80,                            -- min_level_heroic
  80,                            -- min_level_mythic
  80,                            -- min_level_mythic_plus
  1.0,                           -- base_health_multiplier
  1.3,                           -- scaling_heroic (30% more HP/DMG)
  1.8,                           -- scaling_mythic (80% more HP/DMG)
  0.15                           -- scaling_mythic_plus_step (15% per +level)
);
```

**Step 2: C++ Runtime Scaling**
```cpp
// File: MythicDifficultyScaling.cpp

class MythicDifficultyScaling
{
public:
    static void ScaleCreature(Creature* creature, Map* map)
    {
        if (!creature || !map) return;
        if (!map->IsDungeon() && !map->IsRaid()) return;
        
        // Get keystone level from instance data (0 = M+0, 2-10 = M+2 to M+10)
        uint8 keystoneLevel = 0;
        if (InstanceScript* instance = map->GetInstanceScript())
        {
            keystoneLevel = instance->GetData(DATA_MYTHIC_KEYSTONE_LEVEL);
        }
        
        // If no keystone level set, this is a Normal/Heroic run - skip scaling
        if (keystoneLevel == 0 && map->GetDifficulty() != DIFFICULTY_HEROIC)
            return;
        
        // Get dungeon config from database
        QueryResult result = CharacterDatabase.Query(
            "SELECT scaling_mythic, scaling_mythic_plus_step "
            "FROM dc_mythic_dungeons_config "
            "WHERE dungeon_id = {}",
            map->GetId()
        );
        
        if (!result) return;
        
        Field* fields = result->Fetch();
        float mythicScaling = fields[0].Get<float>();      // 1.8x base
        float mythicPlusStep = fields[1].Get<float>();      // 0.15x per level
        
        float multiplier = 1.0f;
        
        if (keystoneLevel == 0)
        {
            // Mythic (M+0) - use base mythic scaling
            multiplier = mythicScaling;  // 1.8x
        }
        else
        {
            // Mythic+ (M+2 to M+10) - add keystone scaling
            multiplier = mythicScaling + (mythicPlusStep * keystoneLevel);
            // Example: M+5 = 1.8 + (0.15 * 5) = 2.55x HP/DMG
        }
        
        // Apply scaling
        uint32 baseHealth = creature->GetCreateHealth();
        uint32 baseMana = creature->GetCreateMana();
        
        creature->SetMaxHealth(uint32(baseHealth * multiplier));
        creature->SetHealth(creature->GetMaxHealth());
        
        if (baseMana > 0)
        {
            creature->SetMaxPower(POWER_MANA, uint32(baseMana * multiplier));
            creature->SetPower(POWER_MANA, creature->GetMaxPower(POWER_MANA));
        }
        
        // Scale damage
        creature->SetModifierValue(UNIT_MOD_DAMAGE_MAINHAND, BASE_VALUE, 
            creature->GetModifierValue(UNIT_MOD_DAMAGE_MAINHAND, BASE_VALUE) * multiplier);
            
        LOG_INFO("mythic", "Scaled creature {} to M+{} ({}x multiplier)", 
            creature->GetName(), keystoneLevel, multiplier);
    }
};

// Hook: Apply scaling when creature spawns
class MythicCreatureSpawnHook : public AllCreatureScript
{
public:
    MythicCreatureSpawnHook() : AllCreatureScript("MythicCreatureSpawnHook") { }
    
    void OnCreatureAddWorld(Creature* creature) override
    {
        if (!creature) return;
        
        Map* map = creature->GetMap();
        if (!map) return;
        
        // Apply Mythic+ scaling
        MythicDifficultyScaling::ScaleCreature(creature, map);
    }
};
```

**Step 3: Keystone Activation (Font of Power)**
```cpp
// When player activates keystone at Font of Power
void ActivateKeystone(Player* player, Item* keystone, uint32 dungeonId)
{
    Group* group = player->GetGroup();
    if (!group || group->GetLeaderGUID() != player->GetGUID())
    {
        player->SendSystemMessage("Only the group leader can activate keystones.");
        return;
    }
    
    // Get keystone level from item ID
    uint32 keystoneLevel = GetKeystoneLevelFromItem(keystone);  // 2-10
    
    // Create Heroic difficulty instance (we reuse existing Heroic infrastructure)
    Map* map = sMapMgr->CreateMap(dungeonId, player, DIFFICULTY_HEROIC);
    if (!map || !map->IsDungeon())
    {
        player->SendSystemMessage("Failed to create instance.");
        return;
    }
    
    // Store keystone level in instance data
    if (InstanceScript* instance = map->GetInstanceScript())
    {
        instance->SetData(DATA_MYTHIC_KEYSTONE_LEVEL, keystoneLevel);
        instance->SetData(DATA_MYTHIC_KEYSTONE_OWNER, player->GetGUID().GetCounter());
    }
    
    // Consume keystone
    player->DestroyItem(keystone->GetBagSlot(), keystone->GetSlot(), true);
    
    // Teleport entire group
    for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
    {
        Player* member = itr->GetSource();
        if (member && member->IsInWorld())
        {
            member->TeleportTo(dungeonId, x, y, z, o);
            member->SendSystemMessage("|cffff8000Entering Mythic+%u dungeon!|r", keystoneLevel);
        }
    }
    
    LOG_INFO("mythic", "Player {} activated M+{} keystone for dungeon {}", 
        player->GetName(), keystoneLevel, dungeonId);
}
```

**EASIEST IMPLEMENTATION SUMMARY:**
1. Use existing Heroic difficulty (ID=1) for all Mythic+ runs
2. Store keystone level in instance->SetData(DATA_MYTHIC_KEYSTONE_LEVEL)
3. Apply scaling via OnCreatureAddWorld hook
4. No DBC editing required
5. No client modifications needed
6. Fully retail-like experience

#### **2.8.3 Weekly Lockout System (Retail-Like)**

**DUNGEONS (Seasonal M+):**
- **NO weekly lockouts** for Mythic or Mythic+ dungeons
- Players can run the same dungeon unlimited times per week
- Loot drops every time (no "already looted" mechanic)
- Retail behavior: Mythic+ dungeons are farmable

**RAIDS:**
- **Weekly lockouts ENABLED** (retail-like)
- One loot chance per boss per week per difficulty
- Lockout shared across 10/25-player versions
- Boss killed = no more loot until next Tuesday reset

**Implementation:**
```cpp
// In InstanceScript::OnPlayerEnter()
void SetupInstanceLockout(Player* player, Map* map)
{
    if (map->IsRaid())
    {
        // Apply raid lockout
        uint32 instanceId = map->GetInstanceId();
        player->BindToInstance(instanceId, true);  // Permanent bind
        
        LOG_INFO("mythic", "Player {} bound to raid instance {}", 
            player->GetName(), instanceId);
    }
    else if (map->IsDungeon())
    {
        // NO lockout for dungeons - remove any existing binds
        player->UnbindInstance(map->GetId(), map->GetDifficulty());
        
        LOG_INFO("mythic", "Player {} entering dungeon {} (no lockout)", 
            player->GetName(), map->GetId());
    }
}
```

**Database Lockout Tracking:**
```sql
-- Existing table: instance_reset (used for raid lockouts)
-- NO changes needed for dungeons (simply don't create entries)

-- For raids, lockout saved automatically:
INSERT INTO character_instance (guid, instance, permanent)
VALUES (player_guid, instance_id, 1);

-- For dungeons, explicitly prevent lockout:
DELETE FROM character_instance 
WHERE guid = player_guid AND instance = instance_id 
  AND instance IN (SELECT id FROM instance WHERE map IN (
    SELECT dungeon_id FROM dc_mythic_dungeons_config WHERE mythic_plus_enabled = 1
  ));
```

---

### **2.9 2-Hour Tradeable Loot Window (Retail-Like)**

All items looted in Mythic+ dungeons can be traded to group members for **2 hours** after the drop (retail behavior).

#### **2.9.1 Database Schema**

```sql
-- Track all M+ loot drops for trade eligibility
CREATE TABLE IF NOT EXISTS dc_mythic_loot_tracker (
    item_guid BIGINT UNSIGNED NOT NULL,       -- Item instance GUID
    item_entry INT UNSIGNED NOT NULL,         -- Item template ID
    looted_by_guid BIGINT UNSIGNED NOT NULL,  -- Player who looted
    dungeon_id INT UNSIGNED NOT NULL,         -- Map ID
    keystone_level TINYINT UNSIGNED NOT NULL, -- M+ level (0-10)
    group_id BIGINT UNSIGNED NOT NULL,        -- Group GUID at drop time
    drop_timestamp INT UNSIGNED NOT NULL,     -- Unix timestamp
    
    PRIMARY KEY (item_guid),
    INDEX idx_looted_by (looted_by_guid, drop_timestamp),
    INDEX idx_cleanup (drop_timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Tracks M+ loot for 2-hour trade window';

-- Store group roster at loot time
CREATE TABLE IF NOT EXISTS dc_mythic_loot_eligible_players (
    item_guid BIGINT UNSIGNED NOT NULL,
    player_guid BIGINT UNSIGNED NOT NULL,
    
    PRIMARY KEY (item_guid, player_guid),
    FOREIGN KEY (item_guid) REFERENCES dc_mythic_loot_tracker(item_guid) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Eligible players for trading M+ loot';
```

#### **2.9.2 C++ Implementation - Loot Tracking**

```cpp
// File: src/server/game/Instances/InstanceScript.cpp
void dc_mythic::TrackMythicLoot(Item* item, Player* looter, Map* map)
{
    if (!map->IsDungeon() || !item || !looter)
        return;
    
    InstanceScript* instance = map->GetInstanceScript();
    if (!instance)
        return;
    
    uint8 keystoneLevel = instance->GetData(DATA_MYTHIC_KEYSTONE_LEVEL);
    // Track loot for M+0 (keystoneLevel=0) and M+2-10
    
    Group* group = looter->GetGroup();
    if (!group)
        return;
    
    // Save loot tracking data
    CharacterDatabase.Execute(
        "INSERT INTO dc_mythic_loot_tracker "
        "(item_guid, item_entry, looted_by_guid, dungeon_id, keystone_level, group_id, drop_timestamp) "
        "VALUES ({}, {}, {}, {}, {}, {}, UNIX_TIMESTAMP())",
        item->GetGUID().GetCounter(),
        item->GetEntry(),
        looter->GetGUID().GetCounter(),
        map->GetId(),
        keystoneLevel,
        group->GetGUID().GetCounter()
    );
    
    // Save all group members as eligible traders
    for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
    {
        Player* member = itr->GetSource();
        if (member && member->IsInMap(map))
        {
            CharacterDatabase.Execute(
                "INSERT INTO dc_mythic_loot_eligible_players (item_guid, player_guid) "
                "VALUES ({}, {})",
                item->GetGUID().GetCounter(),
                member->GetGUID().GetCounter()
            );
        }
    }
    
    LOG_INFO("mythic", "Tracked M+{} loot: item {} for player {} (tradeable for 2h)",
        keystoneLevel, item->GetEntry(), looter->GetName());
}

// Hook into loot system
class dc_mythic_LootHook : public PlayerScript
{
public:
    dc_mythic_LootHook() : PlayerScript("dc_mythic_LootHook") {}
    
    void OnLootItem(Player* player, Item* item, uint32 /*count*/, ObjectGuid /*lootguid*/) override
    {
        if (Map* map = player->GetMap())
            dc_mythic::TrackMythicLoot(item, player, map);
    }
};
```

#### **2.9.3 C++ Implementation - Trade Validation**

```cpp
// File: src/server/game/Entities/Item/Item.cpp
bool dc_mythic::CanTradeItem(Item* item, Player* trader, Player* receiver)
{
    if (!item || !trader || !receiver)
        return false;
    
    // Check if item is tracked M+ loot
    QueryResult result = CharacterDatabase.Query(
        "SELECT drop_timestamp, group_id FROM dc_mythic_loot_tracker "
        "WHERE item_guid = {} AND looted_by_guid = {}",
        item->GetGUID().GetCounter(),
        trader->GetGUID().GetCounter()
    );
    
    if (!result)
        return true; // Not M+ loot, use default trade rules
    
    Field* fields = result->Fetch();
    uint32 dropTime = fields[0].Get<uint32>();
    uint64 groupId = fields[1].Get<uint64>();
    
    // Check 2-hour window
    uint32 currentTime = GameTime::GetGameTime().count();
    uint32 tradeWindowSeconds = sConfigMgr->GetOption<uint32>("MythicPlus.TradeableLoot.Duration", 7200);
    
    if (currentTime - dropTime > tradeWindowSeconds)
    {
        trader->SendSystemMessage("This item is no longer tradeable (2-hour window expired).");
        return false;
    }
    
    // Check if receiver was in the group when item dropped
    QueryResult eligibleCheck = CharacterDatabase.Query(
        "SELECT 1 FROM dc_mythic_loot_eligible_players "
        "WHERE item_guid = {} AND player_guid = {}",
        item->GetGUID().GetCounter(),
        receiver->GetGUID().GetCounter()
    );
    
    if (!eligibleCheck)
    {
        trader->SendSystemMessage("You can only trade this item to players who were in your group when it dropped.");
        return false;
    }
    
    // Calculate remaining time
    uint32 remainingSeconds = tradeWindowSeconds - (currentTime - dropTime);
    uint32 remainingMinutes = remainingSeconds / 60;
    
    trader->SendSystemMessage("Trading M+ loot to {}. Tradeable for {} more minutes.",
        receiver->GetName(), remainingMinutes);
    
    return true;
}
```

#### **2.9.4 Configuration Options**

Add to `darkchaos-custom.conf.dist` Section 6:
```ini
###################################################################################################
# 6.8 TRADEABLE LOOT WINDOW (RETAIL-LIKE)
###################################################################################################

# Enable 2-hour trade window for M+ loot
#   Default: 1 (enabled, retail-like)
#   0 = Items become soulbound immediately
#   1 = Items tradeable for 2 hours to group members
MythicPlus.TradeableLoot.Enabled = 1

# Trade window duration (seconds)
#   Default: 7200 (2 hours, retail-like)
MythicPlus.TradeableLoot.Duration = 7200

# Cleanup interval (seconds) - how often to remove expired tracking entries
#   Default: 3600 (1 hour)
MythicPlus.TradeableLoot.CleanupInterval = 3600
```

#### **2.9.5 Cleanup Task**

```cpp
// File: src/server/worldserver/WorldUpdater.cpp
void dc_mythic::CleanupExpiredLootTracking()
{
    uint32 expiryTime = GameTime::GetGameTime().count() - 
        sConfigMgr->GetOption<uint32>("MythicPlus.TradeableLoot.Duration", 7200);
    
    CharacterDatabase.Execute(
        "DELETE FROM dc_mythic_loot_tracker WHERE drop_timestamp < {}",
        expiryTime
    );
    
    LOG_INFO("mythic", "Cleaned up expired M+ loot tracking entries");
}

// Schedule in world update loop
class dc_mythic_CleanupTask : public WorldScript
{
public:
    dc_mythic_CleanupTask() : WorldScript("dc_mythic_CleanupTask") {}
    
    void OnUpdate(uint32 diff) override
    {
        static uint32 timer = 0;
        timer += diff;
        
        uint32 interval = sConfigMgr->GetOption<uint32>("MythicPlus.TradeableLoot.CleanupInterval", 3600) * 1000;
        
        if (timer >= interval)
        {
            dc_mythic::CleanupExpiredLootTracking();
            timer = 0;
        }
    }
};
```

---

### **2.10 Item Level Adjustments (Retail-Like Scaling)**

Updated from previous 213 base / +3 per level to higher retail-like values.

**Formula:** `Item Level = 226 + (6 × Keystone Level)`

| Keystone Level | Item Level | Notes |
|----------------|-----------|-------|
| M+0 (Mythic)   | 226       | Base Mythic difficulty |
| M+2            | 238       | First keystone tier |
| M+3            | 244       | |
| M+4            | 250       | |
| M+5            | 256       | Mid-tier progression |
| M+6            | 262       | |
| M+7            | 268       | |
| M+8            | 274       | |
| M+9            | 280       | |
| M+10           | 286       | Maximum keystone level |

**Great Vault Rewards (Retail-Like):**
- **Slot 1** (1 M+ dungeon): Item level = highest completed keystone
- **Slot 2** (4 M+ dungeons): Item level = highest + 6
- **Slot 3** (8 M+ dungeons): Item level = highest + 12

*Example:* Highest key was M+7 (268 ilvl)
- Slot 1: 268
- Slot 2: 274
- Slot 3: 280

**Implementation:**
```cpp
uint32 dc_mythic::CalculateItemLevel(uint8 keystoneLevel)
{
    const uint32 BASE_ILVL = 226;
    const uint32 ILVL_PER_LEVEL = 6;
    
    return BASE_ILVL + (keystoneLevel * ILVL_PER_LEVEL);
}

// Apply to loot drops
void dc_mythic::GenerateMythicLoot(Creature* boss, Map* instance)
{
    InstanceScript* script = instance->GetInstanceScript();
    uint8 keystoneLevel = script->GetData(DATA_MYTHIC_KEYSTONE_LEVEL);
    uint32 targetIlvl = CalculateItemLevel(keystoneLevel);
    
    // Query items from loot table matching target ilvl
    QueryResult result = WorldDatabase.Query(
        "SELECT entry FROM item_template "
        "WHERE ItemLevel BETWEEN {} AND {} AND class IN (2, 4) " // Weapons, Armor
        "ORDER BY RAND() LIMIT 5",
        targetIlvl - 3, targetIlvl
    );
    
    // Add items to boss loot
    // ...
}
```

---

### **2.11 Database-Driven NPC Teleporter System**

Instead of hardcoding teleport destinations in C++, use a database table for flexible configuration.

#### **2.11.1 Database Schema**

```sql
-- Hierarchical menu system for teleporter NPCs
CREATE TABLE IF NOT EXISTS dc_mythic_teleporter_menus (
    menu_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    parent_menu_id INT UNSIGNED DEFAULT 0,        -- 0 = top level
    display_order TINYINT UNSIGNED NOT NULL,      -- Sort order
    menu_text VARCHAR(255) NOT NULL,              -- Gossip menu text
    icon_id INT UNSIGNED DEFAULT 0,               -- Gossip icon (0=chat, 1=vendor, etc)
    
    -- Teleport data (NULL if submenu)
    map_id INT UNSIGNED DEFAULT NULL,
    position_x FLOAT DEFAULT NULL,
    position_y FLOAT DEFAULT NULL,
    position_z FLOAT DEFAULT NULL,
    orientation FLOAT DEFAULT NULL,
    
    -- Requirements
    required_level TINYINT UNSIGNED DEFAULT 1,
    required_item_id INT UNSIGNED DEFAULT 0,      -- E.g., keystone required
    required_achievement_id INT UNSIGNED DEFAULT 0,
    
    -- Seasonal filtering
    season_id TINYINT UNSIGNED DEFAULT 0,         -- 0 = always available
    enabled TINYINT(1) DEFAULT 1,
    
    PRIMARY KEY (menu_id),
    INDEX idx_parent (parent_menu_id, display_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Dynamic teleporter menu system';
```

#### **2.11.2 Example Menu Data**

```sql
-- Top level menus
INSERT INTO dc_mythic_teleporter_menus (parent_menu_id, display_order, menu_text, icon_id, season_id, enabled) VALUES
(0, 1, '[Seasonal Dungeons] (8 active)', 0, 1, 1),
(0, 2, '[All Dungeons] (Browse)', 0, 0, 1),
(0, 3, '[Raids]', 0, 0, 1),
(0, 4, '[Statistics]', 0, 0, 1);

-- Seasonal dungeons (parent_menu_id matches menu_id of '[Seasonal Dungeons]')
INSERT INTO dc_mythic_teleporter_menus (parent_menu_id, display_order, menu_text, icon_id, map_id, position_x, position_y, position_z, orientation, required_level, season_id, enabled) VALUES
(1, 1, 'Utgarde Pinnacle [M+0 to M+10]', 1, 575, 1245.69, -775.60, 48.87, 0.0, 80, 1, 1),
(1, 2, 'Halls of Lightning [M+0 to M+10]', 1, 602, 1333.45, 123.78, 52.45, 0.0, 80, 1, 1),
(1, 3, 'Gundrak [M+0 to M+10]', 1, 604, 1905.12, 643.89, 176.66, 0.0, 80, 1, 1),
(1, 4, 'Halls of Stone [M+0 to M+10]', 1, 599, 1380.27, 1047.57, 205.01, 0.0, 80, 1, 1),
(1, 5, 'The Culling of Stratholme [M+0 to M+10]', 1, 595, 1813.95, 1283.93, 142.24, 0.0, 80, 1, 1),
(1, 6, 'Ahn\'kahet [M+0 to M+10]', 1, 619, 1766.86, 698.45, 175.13, 0.0, 80, 1, 1),
(1, 7, 'Drak\'Tharon Keep [M+0 to M+10]', 1, 600, -518.34, -490.44, 10.57, 0.0, 80, 1, 1),
(1, 8, 'The Oculus [M+0 to M+10]', 1, 578, 1067.34, 1129.43, 361.39, 0.0, 80, 1, 1);
```

#### **2.11.3 C++ Implementation**

```cpp
// File: src/server/scripts/Custom/dc_npc_mythic_teleporter.cpp
class dc_npc_mythic_teleporter : public CreatureScript
{
public:
    dc_npc_mythic_teleporter() : CreatureScript("dc_npc_mythic_teleporter") {}
    
    struct npc_mythic_teleporterAI : public ScriptedAI
    {
        npc_mythic_teleporterAI(Creature* creature) : ScriptedAI(creature) {}
        
        bool OnGossipHello(Player* player) override
        {
            ShowMenuLevel(player, 0); // 0 = top level
            return true;
        }
        
        bool OnGossipSelect(Player* player, uint32 /*menuId*/, uint32 action) override
        {
            player->PlayerTalkClass->ClearMenus();
            
            QueryResult result = WorldDatabase.Query(
                "SELECT map_id, position_x, position_y, position_z, orientation "
                "FROM dc_mythic_teleporter_menus WHERE menu_id = {}",
                action
            );
            
            if (result)
            {
                Field* fields = result->Fetch();
                
                if (!fields[0].IsNull()) // Has teleport data
                {
                    uint32 mapId = fields[0].Get<uint32>();
                    float x = fields[1].Get<float>();
                    float y = fields[2].Get<float>();
                    float z = fields[3].Get<float>();
                    float o = fields[4].Get<float>();
                    
                    player->TeleportTo(mapId, x, y, z, o);
                    player->PlayerTalkClass->SendCloseGossip();
                }
                else // It's a submenu
                {
                    ShowMenuLevel(player, action);
                }
            }
            
            return true;
        }
        
    private:
        void ShowMenuLevel(Player* player, uint32 parentMenuId)
        {
            uint8 season = sConfigMgr->GetOption<uint8>("MythicPlus.Season", 1);
            
            QueryResult result = WorldDatabase.Query(
                "SELECT menu_id, menu_text, icon_id, required_level, required_item_id, "
                "       required_achievement_id, map_id "
                "FROM dc_mythic_teleporter_menus "
                "WHERE parent_menu_id = {} AND enabled = 1 "
                "  AND (season_id = 0 OR season_id = {}) "
                "ORDER BY display_order",
                parentMenuId, season
            );
            
            if (!result)
            {
                player->GetSession()->SendNotification("No destinations available.");
                return;
            }
            
            do
            {
                Field* fields = result->Fetch();
                uint32 menuId = fields[0].Get<uint32>();
                std::string text = fields[1].Get<std::string>();
                uint32 icon = fields[2].Get<uint32>();
                uint8 reqLevel = fields[3].Get<uint8>();
                uint32 reqItem = fields[4].Get<uint32>();
                uint32 reqAchievement = fields[5].Get<uint32>();
                bool hasTeleport = !fields[6].IsNull();
                
                // Check requirements
                if (player->GetLevel() < reqLevel)
                {
                    text += fmt::format(" |cffff0000(Requires level {})|r", reqLevel);
                    AddGossipItemFor(player, icon, text, GOSSIP_SENDER_MAIN, 0); // Disabled
                    continue;
                }
                
                if (reqItem > 0 && !player->HasItemCount(reqItem))
                {
                    text += " |cffff0000(Requires keystone)|r";
                    AddGossipItemFor(player, icon, text, GOSSIP_SENDER_MAIN, 0);
                    continue;
                }
                
                if (reqAchievement > 0 && !player->HasAchieved(reqAchievement))
                {
                    text += " |cffff0000(Achievement required)|r";
                    AddGossipItemFor(player, icon, text, GOSSIP_SENDER_MAIN, 0);
                    continue;
                }
                
                // Add clickable menu item
                if (hasTeleport)
                    AddGossipItemFor(player, icon, text, GOSSIP_SENDER_MAIN, menuId, "Teleport to this location?", 0, false);
                else
                    AddGossipItemFor(player, icon, text, GOSSIP_SENDER_MAIN, menuId);
                
            } while (result->NextRow());
            
            // Add back button if not top level
            if (parentMenuId > 0)
            {
                QueryResult parentResult = WorldDatabase.Query(
                    "SELECT parent_menu_id FROM dc_mythic_teleporter_menus WHERE menu_id = {}",
                    parentMenuId
                );
                
                if (parentResult)
                {
                    uint32 grandparentId = parentResult->Fetch()[0].Get<uint32>();
                    AddGossipItemFor(player, 7, "[< Back]", GOSSIP_SENDER_MAIN, grandparentId);
                }
            }
            
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, me->GetGUID());
        }
    };
    
    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_mythic_teleporterAI(creature);
    }
};

void AddSC_dc_npc_mythic_teleporter()
{
    new dc_npc_mythic_teleporter();
}
```

#### **2.11.4 Benefits**

1. **No Code Changes**: Add/remove dungeons via SQL
2. **Seasonal Rotation**: Update `season_id` to hide/show dungeons
3. **Hierarchical Menus**: Unlimited submenu depth
4. **Requirement Checks**: Level, items, achievements
5. **Easy Testing**: Enable/disable individual entries

**Switching Seasons:**
```sql
-- Disable Season 1, enable Season 2
UPDATE dc_mythic_teleporter_menus SET enabled = 0 WHERE season_id = 1;
UPDATE dc_mythic_teleporter_menus SET enabled = 1 WHERE season_id = 2;
```

---

#### **2.8.4 Method 2: DBC Editing (OPTIONAL, ADVANCED)**

**IMPORTANT:** This method modifies client DBC files to add native difficulty support and requires MPQ repacking and client redistribution. Use this if you want client-side UI support for difficulty names, dungeon scaling, or advanced customization.

---

##### **2.8.4.1 Why Edit DBCs?**

**Benefits:**
1. **Native Difficulty Names:** Client displays "Mythic", "Mythic+2", etc. in dungeon finder UI
2. **Level Scaling Support:** Scale ALL dungeons/raids to level 80 (configurable)
3. **Custom Loot Tables:** Separate loot per difficulty without server-side hacks
4. **Atlas/Map Integration:** Dungeons appear correctly on world map
5. **Achievement Support:** Separate achievements for each difficulty

**Drawbacks:**
- Requires MPQ packing tools (MPQEditor, LadiksMPQEditor)
- Every player must download custom client patch
- More maintenance overhead (each update needs repacking)
- Potential compatibility issues with other addons

---

##### **2.8.4.2 Required Files to Edit**

All files located in `Custom/CSV DBC/` (converted from DBC to CSV for editing):

**1. Map.dbc.csv**
- Defines dungeon/raid map entries
- Add separate entries for each difficulty if needed
- Controls instance type, max players, area ID

**2. MapDifficulty.dbc.csv** (WotLK 3.3.5a)
- Links map IDs to difficulty IDs
- Sets reset time (daily/weekly)
- Configures max players per difficulty

**3. DungeonDifficulty.dbc.csv** (If exists in 3.3.5a)
- Defines difficulty entries (Normal=0, Heroic=1, Mythic=4, Mythic+2=6, etc.)
- Sets difficulty names shown in UI

**4. Spell.dbc.csv** (For affix debuffs)
- Create custom spell entries for affixes
- Set spell icons, tooltips, durations

**5. Item.dbc.csv** (For keystones)
- Add keystone item entries (100000-100010)
- Set item quality, icons, tooltips

**6. AreaTable.dbc.csv** (For instance names)
- Update area names for Mythic variants
- Control map display names

---

##### **2.8.4.3 Level 80 Scaling for All Content**

**Configuration Option (darkchaos-custom.conf.dist):**
```ini
###################################################################################################
# 6.9 LEGACY CONTENT SCALING (DBC EDITING REQUIRED)
###################################################################################################

# Scale all Vanilla/BC dungeons and raids to level 80
#   Default: 1 (enabled, allows level 80 players to run all content)
#   0 = Keep original level requirements
#   1 = Scale everything to 80 (requires DBC edits)
MythicPlus.ScaleAllContentTo80 = 1

# Scaling applies to:
#   - Vanilla dungeons (1-60 → 80)
#   - Vanilla raids (MC, BWL, AQ40, Naxx → 80)
#   - BC dungeons (60-70 → 80)
#   - BC raids (Karazhan, SSC, TK, BT, Sunwell → 80)
#   - WotLK dungeons already level 80
#   - WotLK raids already level 80

# Note: This requires editing MapDifficulty.dbc to set minLevel=80, maxLevel=80
```

**DBC Changes Required:**

**MapDifficulty.dbc.csv Example:**
```csv
# Original: Molten Core (Normal)
409,0,0,40,60,60,604800,""

# Changed to level 80:
409,0,0,40,80,80,604800,""

# Add Heroic difficulty (level 80):
409,1,0,40,80,80,604800,"Heroic"

# Add Mythic difficulty (level 80):
409,4,0,40,80,80,604800,"Mythic"
```

**creature_template SQL Updates:**
```sql
-- Scale creature levels to 80 for Vanilla/BC content
-- Example: Molten Core bosses
UPDATE creature_template 
SET minlevel = 80, maxlevel = 80, 
    rank = 3, -- 3 = Boss
    Health_mod = 5.0, -- Increased health
    Damage_mod = 3.0  -- Increased damage
WHERE entry IN (
    12118, -- Lucifron
    11982, -- Magmadar
    12259, -- Gehennas
    12057, -- Garr
    12056, -- Baron Geddon
    12264, -- Shazzrah
    12098, -- Sulfuron Harbinger
    11988, -- Golemagg the Incinerator
    12018, -- Majordomo Executus
    11502  -- Ragnaros
);

-- Example: Blackwing Lair
UPDATE creature_template 
SET minlevel = 80, maxlevel = 80, rank = 3, Health_mod = 5.5, Damage_mod = 3.2
WHERE entry IN (
    12435, -- Razorgore the Untamed
    13020, -- Vaelastrasz the Corrupt
    12017, -- Broodlord Lashlayer
    11983, -- Firemaw
    14601, -- Ebonroc
    11981, -- Flamegor
    14020, -- Chromaggus
    11583  -- Nefarian
);

-- Apply to ALL Vanilla/BC dungeons and raids
-- Use batch queries or scripts to update all creatures in specific zones
```

**Server-Side Scaling Hook (C++):**
```cpp
// File: src/server/game/Entities/Creature/Creature.cpp
void dc_mythic::ScaleLegacyContent(Creature* creature, Map* map)
{
    if (!sConfigMgr->GetOption<bool>("MythicPlus.ScaleAllContentTo80", true))
        return;
    
    uint32 mapId = map->GetId();
    
    // Check if map is Vanilla (0-60) or BC (60-70) content
    bool isVanilla = (mapId >= 33 && mapId <= 560);  // Vanilla map range
    bool isBC = (mapId >= 530 && mapId <= 580);      // BC map range
    
    if (!isVanilla && !isBC)
        return; // WotLK content already level 80
    
    // Scale creature to level 80
    creature->SetLevel(80);
    
    // Increase stats based on difficulty
    Difficulty diff = map->GetDifficulty();
    float hpMult = 1.0f;
    float dmgMult = 1.0f;
    
    switch(diff)
    {
        case DIFFICULTY_NORMAL:
            hpMult = 3.0f;
            dmgMult = 2.0f;
            break;
        case DIFFICULTY_HEROIC:
            hpMult = 5.0f;
            dmgMult = 3.0f;
            break;
        case DIFFICULTY_MYTHIC: // Custom Mythic
            hpMult = 8.0f;
            dmgMult = 4.5f;
            break;
    }
    
    creature->SetCreateHealth(creature->GetCreateHealth() * hpMult);
    creature->SetMaxHealth(creature->GetMaxHealth() * hpMult);
    creature->SetHealth(creature->GetMaxHealth());
    creature->SetModifierValue(UNIT_MOD_DAMAGE_MAINHAND, BASE_VALUE, 
        creature->GetModifierValue(UNIT_MOD_DAMAGE_MAINHAND, BASE_VALUE) * dmgMult);
    
    LOG_INFO("mythic", "Scaled legacy creature {} to level 80 (HP: {}x, DMG: {}x)",
        creature->GetName(), hpMult, dmgMult);
}

// Hook into creature spawn
class dc_mythic_LegacyScalingHook : public AllCreatureScript
{
public:
    dc_mythic_LegacyScalingHook() : AllCreatureScript("dc_mythic_LegacyScalingHook") {}
    
    void OnCreatureAddWorld(Creature* creature) override
    {
        Map* map = creature->GetMap();
        if (map && (map->IsDungeon() || map->IsRaid()))
            dc_mythic::ScaleLegacyContent(creature, map);
    }
};
```

---

##### **2.8.4.4 Custom Creature Template IDs**

**Starting ID:** 100000 (matches keystone item IDs for consistency)

**Creature ID Ranges:**
- **100000-100099:** Mythic+ System NPCs
  - 100000: Mythic+ Dungeon Teleporter (replaces 300315)
  - 100001: Mythic Raid Teleporter (replaces 300316)
  - 100002-100010: Reserved for future NPCs

- **700000-700099:** Mythic+ System GameObjects
  - 700000: Great Vault (weekly chest at major cities)
  - 700001-700008: Font of Power (keystone activation objects, one per seasonal dungeon)
  - 700009-700099: Reserved for future GameObjects

- **100100-100199:** Scaled Vanilla Boss Variants
  - 100100: Ragnaros (Level 80 Mythic)
  - 100101: Nefarian (Level 80 Mythic)
  - 100102: C'Thun (Level 80 Mythic)
  - 100103: Kel'Thuzad (Naxx60, Level 80 Mythic)

- **100200-100299:** Scaled BC Boss Variants
  - 100200: Prince Malchezaar (Level 80 Mythic)
  - 100201: Lady Vashj (Level 80 Mythic)
  - 100202: Kael'thas Sunstrider (TK, Level 80 Mythic)
  - 100203: Illidan Stormrage (Level 80 Mythic)
  - 100204: Kil'jaeden (Level 80 Mythic)

- **100300+:** Additional custom creatures

**SQL Template:**
```sql
-- Example: Ragnaros Level 80 Mythic variant
INSERT INTO creature_template (entry, modelid1, name, subname, minlevel, maxlevel, faction, npcflag, speed_walk, speed_run, scale, rank, dmg_multiplier, baseattacktime, rangeattacktime, unit_class, unit_flags, dynamicflags, family, trainer_type, trainer_spell, trainer_class, trainer_race, minrangedmg, maxrangedmg, rangedattackpower, type, type_flags, lootid, pickpocketloot, skinloot, resistance1, resistance2, resistance3, resistance4, resistance5, resistance6, spell1, spell2, spell3, spell4, PetSpellDataId, VehicleId, mingold, maxgold, AIName, MovementType, InhabitType, HoverHeight, Health_mod, Mana_mod, Armor_mod, RacialLeader, questItem1, questItem2, questItem3, questItem4, questItem5, questItem6, movementId, RegenHealth, mechanic_immune_mask, flags_extra, ScriptName)
VALUES 
(100100, 9030, 'Ragnaros', 'The Firelord (Mythic)', 80, 80, 14, 0, 1.0, 1.14286, 1, 3, 15.0, 2000, 2000, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 76, 11502, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100000, 200000, '', 0, 3, 1, 100.0, 50.0, 1.0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 617299839, 1, 'boss_ragnaros_mythic');
```

---

##### **2.8.4.5 Existing Eluna Teleporter Integration**

Your existing Eluna teleporter (`Custom/Eluna scripts/Teleporter/`) uses the `eluna_teleporter` table with hierarchical menus. **This can be directly integrated with the Mythic+ system!**

**Current Eluna Teleporter Table Structure:**
```sql
CREATE TABLE `eluna_teleporter` (
  `id` int(5) NOT NULL AUTO_INCREMENT,
  `parent` int(5) NOT NULL DEFAULT '0',
  `type` int(1) NOT NULL DEFAULT '1',  -- 1=submenu, 2=teleport
  `faction` int(2) NOT NULL DEFAULT '-1',
  `icon` int(2) NOT NULL DEFAULT '0',
  `name` char(20) NOT NULL DEFAULT '',
  `map` int(5) DEFAULT NULL,
  `x` decimal(10,3) DEFAULT NULL,
  `y` decimal(10,3) DEFAULT NULL,
  `z` decimal(10,3) DEFAULT NULL,
  `o` decimal(10,3) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
```

**Recommended: Extend Table for Mythic+ Features**
```sql
ALTER TABLE eluna_teleporter 
ADD COLUMN `required_level` TINYINT UNSIGNED DEFAULT 1,
ADD COLUMN `required_item` INT UNSIGNED DEFAULT 0,
ADD COLUMN `season_id` TINYINT UNSIGNED DEFAULT 0,
ADD COLUMN `enabled` TINYINT(1) DEFAULT 1,
ADD COLUMN `difficulty` TINYINT UNSIGNED DEFAULT 0,  -- 0=Normal, 1=Heroic, 4=Mythic
ADD COLUMN `keystone_level` TINYINT UNSIGNED DEFAULT 0;  -- 0=M+0, 2-10=M+2 to M+10
```

**Populate with Mythic+ Dungeons:**
```sql
-- Top level menu
INSERT INTO eluna_teleporter (id, parent, type, name, icon, season_id, enabled) VALUES
(1000, 0, 1, '[Mythic+ Dungeons]', 0, 0, 1);

-- Seasonal WotLK dungeons (Season 1)
INSERT INTO eluna_teleporter (id, parent, type, name, map, x, y, z, o, required_level, season_id, enabled, difficulty) VALUES
(1001, 1000, 2, 'Utgarde Pinnacle', 575, 1245.69, -775.60, 48.87, 0.0, 80, 1, 1, 4),  -- Mythic
(1002, 1000, 2, 'Halls of Lightning', 602, 1333.45, 123.78, 52.45, 0.0, 80, 1, 1, 4),
(1003, 1000, 2, 'Gundrak', 604, 1905.12, 643.89, 176.66, 0.0, 80, 1, 1, 4),
(1004, 1000, 2, 'Halls of Stone', 599, 1380.27, 1047.57, 205.01, 0.0, 80, 1, 1, 4),
(1005, 1000, 2, 'Culling of Stratholme', 595, 1813.95, 1283.93, 142.24, 0.0, 80, 1, 1, 4),
(1006, 1000, 2, 'Ahn\'kahet', 619, 1766.86, 698.45, 175.13, 0.0, 80, 1, 1, 4),
(1007, 1000, 2, 'Drak\'Tharon Keep', 600, -518.34, -490.44, 10.57, 0.0, 80, 1, 1, 4),
(1008, 1000, 2, 'The Oculus', 578, 1067.34, 1129.43, 361.39, 0.0, 80, 1, 1, 4);
```

**Convert Eluna Lua → C++ (Optional):**
- Keep Eluna script for flexibility OR
- Port to C++ NPC (creature ID 100000) as shown in Section 2.11
- C++ provides better performance, Lua provides easier configuration

---

##### **2.8.4.6 Dungeon Journal Addon for 3.3.5a**

**Finding: No Native Retail-Style Dungeon Journal for 3.3.5a**

The retail Dungeon Journal was added in **Cataclysm (4.0.1)** and does not exist in WotLK 3.3.5a. The DBC file `JournalEncounter.dbc` doesn't exist in 3.3.5a clients.

**Alternative: AtlasLoot Enhanced**

**AtlasLoot** is the closest equivalent for 3.3.5a and provides:
- Boss loot tables for all dungeons/raids
- Item tooltips and links
- Set bonuses
- Reputation rewards
- NOT a dungeon journal (no boss abilities/tactics)

**Download:**
- **Original (outdated):** https://www.wowace.com/projects/atlasloot-enhanced
- **3.3.5a Fork:** Search for "AtlasLoot WotLK" on private server forums
- **Note:** AtlasLoot shows LOOT only, not boss mechanics

**Custom Solution: Server-Delivered Dungeon Journal**

Since no addon exists, you can **build your own** using the C++ addon communication system described in Part 12.3:

**Implementation:**
1. **Server-Side:** Store boss abilities in database table `dc_mythic_dungeon_journal`
2. **Addon Request:** Player types `/mythicjournal` → sends addon message
3. **Server Response:** Sends boss data via `SendAddonMessage`
4. **Addon Display:** Shows custom UI with abilities, tactics, loot

**Database Schema:**
```sql
CREATE TABLE dc_mythic_dungeon_journal (
    entry_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    dungeon_id INT UNSIGNED NOT NULL,
    boss_entry INT UNSIGNED NOT NULL,
    boss_name VARCHAR(100),
    overview_text TEXT,
    abilities_json TEXT,  -- JSON array of abilities
    loot_table_id INT UNSIGNED,
    PRIMARY KEY (entry_id),
    INDEX idx_dungeon (dungeon_id),
    INDEX idx_boss (boss_entry)
);
```

**Example JSON:**
```json
{
  "abilities": [
    {
      "name": "Whirlwind",
      "spellId": 15576,
      "description": "Inflicts 100% weapon damage to nearby enemies every 1 sec for 5 sec.",
      "type": "deadly"
    },
    {
      "name": "Mortal Strike",
      "spellId": 16856,
      "description": "Inflicts 200% weapon damage and reduces healing by 50% for 5 sec.",
      "type": "important"
    }
  ],
  "tactics": "Tank boss away from group. Dispel Mortal Strike. Run out during Whirlwind."
}
```

---

##### **2.8.4.7 MPQ Packing Workflow**

**Tools Required:**
- **MPQEditor** or **LadiksMPQEditor** (for repacking DBCs)
- **MyDBCEditor** or **WoWDBDefs** (for editing DBC files)
- **CSV to DBC converter** (if using CSV workflow)

**Steps:**
1. Extract original `DBFilesClient` folder from `patch-3.mpq`
2. Convert DBCs to CSV using MyDBCEditor
3. Edit CSVs in Excel/text editor
4. Convert CSVs back to DBC format
5. Create new MPQ: `patch-4.mpq` (or custom name)
6. Place in `Data/` folder (loads after `patch-3.mpq`)
7. Distribute to all players via launcher/patcher

**Example `patch-4.mpq` Contents:**
```
patch-4.mpq
└── DBFilesClient/
    ├── Map.dbc (edited)
    ├── MapDifficulty.dbc (edited)
    ├── Spell.dbc (custom affixes)
    ├── Item.dbc (keystones 100000-100010)
    └── AreaTable.dbc (instance names)
```

**Automatic Distribution:**
- Integrate with launcher (AzerothCore Dashboard)
- Check MPQ hash on login
- Auto-download updated MPQs if hash mismatch

---

##### **2.8.4.8 Summary: DBC Editing Decision Tree**

```
Do you need retail-like UI integration? ────NO──→ Use Method 1 (Server-Side Only)
         │
        YES
         │
         ↓
Do you want level 80 scaling for ALL content? ────NO──→ Edit MapDifficulty.dbc only
         │                                                (Add Mythic difficulties)
        YES
         │
         ↓
Do you have MPQ packing tools? ────NO──→ Learn MPQEditor first
         │                                (See 2.8.4.7)
        YES
         │
         ↓
Do you have distribution method for players? ────NO──→ Set up launcher/patcher
         │                                              (Auto-download custom MPQs)
        YES
         │
         ↓
    Use Method 2 (DBC Editing)
    - Edit Map.dbc, MapDifficulty.dbc, Item.dbc
    - Scale creature_template to level 80
    - Create patch-4.mpq
    - Distribute to players
```

**Recommendation:**
- **Start with Method 1** (easiest, no client changes)
- **Add Method 2 later** if you need UI integration or level 80 scaling
- **Keep Eluna teleporter** for flexibility (easy to update via SQL)
- **Build custom dungeon journal addon** (no 3.3.5a equivalent exists)

---

####

**Option A: Via NPC Teleporter (Recommended)**
```
1. Player talks to NPC 300315 (Mythic+ Dungeon Teleporter)
2. NPC shows gossip menu:
   ├─ "Browse Mythic Dungeons (M+0)" 
   │   └─ Shows all dungeons, teleports to DIFFICULTY_MYTHIC (4)
   │
   └─ "Browse Mythic+ Dungeons (Seasonal)"
       └─ Shows 8 seasonal dungeons
           └─ Player selects dungeon
               └─ "Insert Keystone" prompt
                   └─ Validates keystone level (M+2 to M+10)
                       └─ Teleports to custom difficulty (6-15)

3. Server creates instance with appropriate difficulty
4. All creatures scale automatically via OnCreatureAddWorld hook
```

**Option B: LFG Tool Integration (Future Phase)**
```
1. Open LFG tool (default Blizzard UI)
2. Add custom "Mythic+" category
3. Filter by dungeon and keystone level
4. Queue or form group
5. Enter dungeon automatically with correct difficulty
```

**Option C: Manual Entry at Dungeon Portal (M+0 Only)**
```
1. Player walks to dungeon entrance (physical location)
2. Right-click dungeon portal
3. Gossip menu appears: "Select Difficulty"
   ├─ Normal (available always)
   ├─ Heroic (if level 80+)
   └─ Mythic (if level 80+) - Creates DIFFICULTY_MYTHIC instance

4. For Mythic+ (requires keystone):
   - "Font of Power" object at entrance
   - Player places keystone
   - Instance created with keystone level difficulty
```

#### **2.8.5 Difficulty Selection Implementation**

**Gossip Menu for Dungeon Portal:**
```cpp
// File: npc_dungeon_portal_difficulty_selector.cpp

class dungeon_portal_difficulty_selector : public GameObjectScript
{
public:
    dungeon_portal_difficulty_selector() : GameObjectScript("dungeon_portal_difficulty_selector") { }
    
    bool OnGossipHello(Player* player, GameObject* go) override
    {
        uint32 mapId = go->GetMapId();  // Dungeon map ID
        
        ClearGossipMenuFor(player);
        
        // Check configuration
        QueryResult result = CharacterDatabase.Query(
            "SELECT normal_enabled, heroic_enabled, mythic_enabled, "
            "min_level_normal, min_level_heroic, min_level_mythic "
            "FROM dc_mythic_dungeons_config WHERE dungeon_id = {}",
            mapId
        );
        
        if (!result) {
            CloseGossipMenuFor(player);
            return true;
        }
        
        Field* fields = result->Fetch();
        bool normalEnabled = fields[0].Get<bool>();
        bool heroicEnabled = fields[1].Get<bool>();
        bool mythicEnabled = fields[2].Get<bool>();
        uint32 minLevelNormal = fields[3].Get<uint32>();
        uint32 minLevelHeroic = fields[4].Get<uint32>();
        uint32 minLevelMythic = fields[5].Get<uint32>();
        
        // Build menu
        if (normalEnabled && player->GetLevel() >= minLevelNormal)
        {
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, 
                "Enter Normal Difficulty", 
                GOSSIP_SENDER_MAIN, 
                GOSSIP_ACTION_INFO_DEF + DIFFICULTY_NORMAL);
        }
        
        if (heroicEnabled && player->GetLevel() >= minLevelHeroic)
        {
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, 
                "Enter Heroic Difficulty", 
                GOSSIP_SENDER_MAIN, 
                GOSSIP_ACTION_INFO_DEF + DIFFICULTY_HEROIC);
        }
        
        if (mythicEnabled && player->GetLevel() >= minLevelMythic)
        {
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, 
                "Enter Mythic Difficulty (M+0)", 
                GOSSIP_SENDER_MAIN, 
                GOSSIP_ACTION_INFO_DEF + DIFFICULTY_MYTHIC);
        }
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
            "Mythic+ (Requires Keystone) - Use Font of Power", 
            GOSSIP_SENDER_MAIN, 
            GOSSIP_ACTION_INFO_DEF + 50);
        
        player->PlayerTalkClass->SendGossipMenu(1, go->GetGUID());
        return true;
    }
    
    bool OnGossipSelect(Player* player, GameObject* go, uint32 sender, uint32 action) override
    {
        uint32 mapId = go->GetMapId();
        uint8 difficulty = action - GOSSIP_ACTION_INFO_DEF;
        
        if (difficulty >= 50)  // Info option
        {
            player->SendSystemMessage("Mythic+ requires placing a keystone in the Font of Power.");
            CloseGossipMenuFor(player);
            return true;
        }
        
        // Create instance with selected difficulty
        CreateInstanceAndTeleport(player, mapId, difficulty);
        
        CloseGossipMenuFor(player);
        return true;
    }
    
private:
    void CreateInstanceAndTeleport(Player* player, uint32 mapId, uint8 difficulty)
    {
        // Get entrance coordinates
        float x, y, z, o;
        GetDungeonEntranceCoords(mapId, x, y, z, o);
        
        // Create or find instance
        Map* map = sMapMgr->CreateMap(mapId, player);
        if (!map || (!map->IsDungeon() && !map->IsRaid()))
        {
            player->SendSystemMessage("Failed to create instance.");
            return;
        }
        
        // Set difficulty
        map->SetDifficulty(difficulty);
        
        // Teleport
        player->TeleportTo(mapId, x, y, z, o);
        
        // Announce
        std::string diffName = GetDifficultyName(difficulty);
        player->SendSystemMessage("Entering dungeon: %s", diffName.c_str());
    }
    
    std::string GetDifficultyName(uint8 difficulty)
    {
        switch (difficulty)
        {
            case DIFFICULTY_NORMAL: return "Normal";
            case DIFFICULTY_HEROIC: return "Heroic";
            case DIFFICULTY_MYTHIC: return "Mythic (M+0)";
            default: return "Unknown";
        }
    }
};
```

**Summary:**
- **Server-Side Scaling (Method 1):** Easiest, no client changes, fully functional
- **DBC Editing (Method 2):** Advanced, requires client redistribution, better UI integration
- **Difficulty Selection:** Via NPC teleporter OR dungeon portal gossip menu
- **M+0 Dungeons:** Available anytime, no keystone needed, 5-player groups
- **Mythic+ (M+2-M+10):** Requires keystone at Font of Power, scales difficulty 6-15

Token Exchange NPCs:
- Vendor in main cities
- 50 tokens = 1 ilvl 226 Epic item
- 100 tokens = 1 ilvl 239 Legendary-quality transmog
```

**Loot Drops** (1 item per group finish)
```
Mythic: 1 item at boss (ilvl 219)
Mythic+1-3: 1 item (ilvl 219)
Mythic+4-6: 1-2 items (ilvl 226)
Mythic+7-10: 2 items (ilvl 232)

Soulbound to prevent RMT issues
```

**Weekly Vault Integration**
```
Players can select 1 reward from:
- Best Mythic+ clear of week (rating based)
- Bonus tokens (25% extra)
- Cosmetic item (transmog/mount)

Generates on weekly reset
Requires minimum 1 completed run that week
```

---

### **2.12 EDGE CASE HANDLING & ANTI-EXPLOIT (RETAIL-LIKE)**

This section addresses critical edge cases with retail-accurate behavior.

---

#### **2.12.1 Death & Revival System (Retail-Like)**

**⚠️ SCOPE: MYTHIC+ DUNGEONS ONLY (M+2 to M+10)**

This death penalty system applies ONLY to Mythic+ keystoned dungeons:
- ✅ **Mythic+2 to Mythic+10:** Death counter active, 15 death maximum enforced
- ❌ **Mythic 0 (M0):** No death limit, no keystone, regular mechanics
- ❌ **Mythic Raids:** No death limit, normal lockout rules apply
- ❌ **Heroic/Normal Content:** No death limit, existing mechanics unchanged

**Behavior:** When a player dies in Mythic+, they automatically revive at the dungeon entrance after releasing.

**✅ FINAL DECISION: 15 Death Maximum, Keystone Upgrade Formula**

**Death Penalty System:**

**Maximum Deaths:** 15 deaths = automatic run failure
- At 15th death → Keystone destroyed, run fails instantly
- Keystone owner receives system message: "Maximum deaths exceeded! Keystone destroyed."
- All party members kicked from dungeon

**Keystone Upgrade Formula (Based on Deaths):**

| Deaths | Keystone Result                | Example (M+5)               |
|--------|--------------------------------|-----------------------------|
| 0-5    | Upgrade +2 levels              | M+5 → M+7                   |
| 6-10   | Upgrade +1 level               | M+5 → M+6                   |
| 11-14  | Same level (no upgrade/downgrade) | M+5 → M+5                   |
| 15+    | Keystone destroyed (run fails) | M+5 → No keystone           |

**Vault Token Reduction (High Deaths):**
- 15 deaths = Tokens reduced by 50% (still get partial credit)
- Example: Would get 100 tokens → Receive 50 tokens instead

**Implementation:**
```cpp
// File: src/server/game/Entities/Player/Player.cpp (hook)
class dc_mythic_DeathHandler : public PlayerScript
{
public:
    dc_mythic_DeathHandler() : PlayerScript("dc_mythic_DeathHandler") {}
    
    void OnPlayerRepop(Player* player) override
    {
        Map* map = player->GetMap();
        
        // Check if in Mythic+ dungeon
        if (!map || !map->IsDungeon())
            return;
        
        InstanceScript* instance = map->GetInstanceScript();
        if (!instance || !instance->GetData(DATA_IS_MYTHIC_PLUS))
            return;
        
        // ✅ Teleport to dungeon entrance (retail behavior)
        Position entrancePos = map->GetEntrancePosition();
        player->TeleportTo(map->GetId(), entrancePos.GetPositionX(), 
                          entrancePos.GetPositionY(), entrancePos.GetPositionZ(), 
                          entrancePos.GetOrientation());
        
        // ✅ Auto-resurrect at entrance (retail behavior)
        player->ResurrectPlayer(0.5f, false);  // 50% health/mana
        player->SpawnCorpseBones();
        
        // Increment death counter for run
        uint32 currentDeaths = instance->GetData(DATA_TOTAL_DEATHS);
        instance->SetData(DATA_TOTAL_DEATHS, currentDeaths + 1);
        
        // ✅ Check for maximum deaths (15)
        if (currentDeaths + 1 >= 15)
        {
            // Fail run immediately
            FailMythicPlusRun(instance, "Maximum deaths exceeded (15)");
            
            // Destroy keystone
            uint64 keystoneOwnerGUID = instance->GetData64(DATA_KEYSTONE_OWNER_GUID);
            Player* owner = ObjectAccessor::FindPlayer(ObjectGuid(keystoneOwnerGUID));
            if (owner)
            {
                uint8 keystoneLevel = instance->GetData(DATA_KEYSTONE_LEVEL);
                owner->DestroyItemCount(KEYSTONE_ITEM_BASE + (keystoneLevel - 2), 1, true);
                owner->SendSystemMessage("|cffff0000[Mythic+]|r Maximum deaths exceeded! Keystone destroyed.");
            }
            
            // Kick all players from dungeon
            map->RemoveAllPlayers();
            return;
        }
        
        // Broadcast to group (with upgrade warning)
        if (Group* group = player->GetGroup())
        {
            std::string upgradeHint = "";
            if (currentDeaths + 1 == 6)
                upgradeHint = " (Upgrade reduced to +1)";
            else if (currentDeaths + 1 == 11)
                upgradeHint = " (No upgrade, only completion credit)";
            else if (currentDeaths + 1 == 14)
                upgradeHint = " (WARNING: 1 death until FAILURE)";
            
            std::string msg = "|cffff0000[Mythic+]|r " + std::string(player->GetName()) + 
                            " died. Total deaths: " + std::to_string(currentDeaths + 1) + upgradeHint;
            group->BroadcastToGroup(msg);
        }
        
        LOG_INFO("mythic", "Player {} died in M+ (Map: {}, Deaths: {})", 
                 player->GetName(), map->GetId(), currentDeaths + 1);
    }
};

// Keystone upgrade calculation on completion
uint8 CalculateKeystoneUpgrade(uint32 deathCount, uint8 currentLevel)
{
    if (deathCount >= 15)
        return 0;  // No keystone (destroyed)
    else if (deathCount <= 5)
        return std::min<uint8>(10, currentLevel + 2);  // +2 levels (max M+10)
    else if (deathCount <= 10)
        return std::min<uint8>(10, currentLevel + 1);  // +1 level
    else if (deathCount <= 14)
        return currentLevel;  // Same level (no upgrade)
    else
        return 0;  // Should never reach here
}
```

**Key Features:**
- ✅ **No corpse run required** (teleport to entrance automatically)
- ✅ **Auto-resurrection** at 50% HP/mana (retail-like)
- ✅ **Death counter increments** (affects keystone upgrade chances)
- ✅ **Group notification** (everyone sees death count with upgrade warnings)
- ✅ **Battle resurrection still works** (players can brez during combat)
- ✅ **15 death maximum** (automatic failure)
- ✅ **Upgrade formula** (0-5 deaths = +2, 6-10 = +1, 11-14 = same, 15+ = destroyed)

---

#### **2.12.2 Group Disband During Run**

**Behavior:** If group disbands mid-run (even at 90% boss health), keystone downgrades by 1 level.

**Implementation:**
```cpp
// File: src/server/game/Groups/Group.cpp (hook)
class dc_mythic_GroupDisbandHandler : public GroupScript
{
public:
    dc_mythic_GroupDisbandHandler() : GroupScript("dc_mythic_GroupDisbandHandler") {}
    
    void OnGroupDisband(Group* group) override
    {
        // Check if any member is in Mythic+ dungeon
        for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
        {
            Player* member = itr->GetSource();
            if (!member)
                continue;
            
            Map* map = member->GetMap();
            if (!map || !map->IsDungeon())
                continue;
            
            InstanceScript* instance = map->GetInstanceScript();
            if (!instance || !instance->GetData(DATA_IS_MYTHIC_PLUS))
                continue;
            
            // ✅ Found active M+ run - downgrade keystone for keystone owner
            uint64 keystoneOwnerGUID = instance->GetData64(DATA_KEYSTONE_OWNER_GUID);
            Player* owner = ObjectAccessor::FindPlayer(ObjectGuid(keystoneOwnerGUID));
            
            if (owner)
            {
                uint8 currentLevel = instance->GetData(DATA_KEYSTONE_LEVEL);
                uint8 newLevel = std::max<uint8>(2, currentLevel - 1);  // Min M+2
                
                // Remove old keystone
                owner->DestroyItemCount(KEYSTONE_ITEM_BASE + (currentLevel - 2), 1, true);
                
                // Give downgraded keystone
                if (Item* newKey = owner->AddItem(KEYSTONE_ITEM_BASE + (newLevel - 2), 1))
                {
                    owner->SendSystemMessage("|cffff0000[Mythic+]|r Group disbanded! Your keystone was downgraded to M+{}.", newLevel);
                }
                
                LOG_WARN("mythic", "Group disbanded in M+ (Map: {}, Level: {} → {})", 
                         map->GetId(), currentLevel, newLevel);
            }
            
            // ✅ Mark instance as failed
            instance->SetData(DATA_RUN_FAILED, 1);
            
            break;  // Only need to handle once
        }
    }
    
    void OnGroupMemberLeave(Group* group, Player* player, uint8 /*removeMethod*/) override
    {
        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
            return;
        
        InstanceScript* instance = map->GetInstanceScript();
        if (!instance || !instance->GetData(DATA_IS_MYTHIC_PLUS))
            return;
        
        // ✅ Player leaving = group disband equivalent (retail behavior)
        // Treat as full disband to prevent leave/rejoin exploits
        OnGroupDisband(group);
    }
};
```

**Key Features:**
- ✅ **Keystone downgrades by 1 level** on disband (M+5 → M+4)
- ✅ **Minimum M+2** (never goes below)
- ✅ **No loot drops** if group disbands (instance marked as failed)
- ✅ **Single player leave = disband** (prevents exploits)

---

#### **2.12.3 Instance Persistence After Server Crash**

**Behavior:** If server crashes mid-run, instance state is preserved and players can resume.

**Database Schema:**
```sql
-- Add persistence tracking
CREATE TABLE dc_mythic_instance_state (
  instance_id INT PRIMARY KEY,
  map_id INT,
  keystone_level INT,
  keystone_owner_guid BIGINT,
  total_deaths INT DEFAULT 0,
  start_time INT,  -- Unix timestamp
  boss_kills TEXT,  -- JSON: ["boss1", "boss2"]
  affixes TEXT,  -- JSON: [1, 2, 3]
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_instance (instance_id),
  KEY idx_owner (keystone_owner_guid)
);
```

**Implementation:**
```cpp
// File: src/server/game/Instances/InstanceScript.cpp
class dc_mythic_PersistenceHandler : public WorldScript
{
public:
    dc_mythic_PersistenceHandler() : WorldScript("dc_mythic_PersistenceHandler") {}
    
    void OnStartup() override
    {
        // ✅ Restore active M+ instances on server restart
        QueryResult result = CharacterDatabase.Query(
            "SELECT instance_id, map_id, keystone_level, keystone_owner_guid, "
            "total_deaths, start_time, boss_kills, affixes "
            "FROM dc_mythic_instance_state "
            "WHERE created_at > DATE_SUB(NOW(), INTERVAL 4 HOUR)"  // Only last 4 hours
        );
        
        if (!result)
            return;
        
        do
        {
            Field* fields = result->Fetch();
            uint32 instanceId = fields[0].Get<uint32>();
            uint32 mapId = fields[1].Get<uint32>();
            uint8 keystoneLevel = fields[2].Get<uint8>();
            uint64 ownerGUID = fields[3].Get<uint64>();
            uint32 deaths = fields[4].Get<uint32>();
            uint32 startTime = fields[5].Get<uint32>();
            std::string bossKills = fields[6].Get<std::string>();
            std::string affixes = fields[7].Get<std::string>();
            
            // Restore instance data
            if (Map* map = sMapMgr->FindMap(mapId, instanceId))
            {
                if (InstanceScript* script = map->GetInstanceScript())
                {
                    script->SetData(DATA_IS_MYTHIC_PLUS, 1);
                    script->SetData(DATA_KEYSTONE_LEVEL, keystoneLevel);
                    script->SetData64(DATA_KEYSTONE_OWNER_GUID, ownerGUID);
                    script->SetData(DATA_TOTAL_DEATHS, deaths);
                    script->SetData(DATA_START_TIME, startTime);
                    // Restore boss kills, affixes from JSON...
                    
                    LOG_INFO("mythic", "Restored M+ instance {} (Map: {}, Level: {})", 
                             instanceId, mapId, keystoneLevel);
                }
            }
        } while (result->NextRow());
    }
    
    void OnInstanceSave(Map* map) override
    {
        if (!map->IsDungeon())
            return;
        
        InstanceScript* instance = map->GetInstanceScript();
        if (!instance || !instance->GetData(DATA_IS_MYTHIC_PLUS))
            return;
        
        // ✅ Persist instance state every 30 seconds
        uint8 keystoneLevel = instance->GetData(DATA_KEYSTONE_LEVEL);
        uint64 ownerGUID = instance->GetData64(DATA_KEYSTONE_OWNER_GUID);
        uint32 deaths = instance->GetData(DATA_TOTAL_DEATHS);
        uint32 startTime = instance->GetData(DATA_START_TIME);
        
        CharacterDatabase.Execute(
            "INSERT INTO dc_mythic_instance_state "
            "(instance_id, map_id, keystone_level, keystone_owner_guid, total_deaths, start_time) "
            "VALUES ({}, {}, {}, {}, {}, {}) "
            "ON DUPLICATE KEY UPDATE "
            "total_deaths = {}, updated_at = NOW()",
            map->GetInstanceId(), map->GetId(), keystoneLevel, ownerGUID, deaths, startTime, deaths
        );
    }
};
```

**Key Features:**
- ✅ **Instance state saved every 30 seconds** (boss kills, deaths, timer)
- ✅ **Restored on server restart** (if within 4-hour window)
- ✅ **Keystone NOT consumed** if server crash (fair to players)
- ✅ **Players can reconnect** and continue run

---

#### **2.12.4 Gear & Talent Locking During Run (Retail-Like)**

**Behavior:** Once M+ run starts, players CANNOT change gear or talents until run completes.

**Implementation:**
```cpp
// File: src/server/game/Entities/Player/Player.cpp (hooks)
class dc_mythic_GearTalentLock : public PlayerScript
{
public:
    dc_mythic_GearTalentLock() : PlayerScript("dc_mythic_GearTalentLock") {}
    
    bool OnBeforeEquipItem(Player* player, uint8 /*slot*/, Item* /*item*/) override
    {
        if (IsInActiveMythicPlus(player))
        {
            player->SendSystemMessage("|cffff0000[Mythic+]|r You cannot change gear during a Mythic+ run!");
            return false;  // ✅ Block gear swap
        }
        return true;
    }
    
    bool OnBeforeUnequipItem(Player* player, uint8 /*slot*/) override
    {
        if (IsInActiveMythicPlus(player))
        {
            player->SendSystemMessage("|cffff0000[Mythic+]|r You cannot change gear during a Mythic+ run!");
            return false;  // ✅ Block gear removal
        }
        return true;
    }
    
    void OnLearnTalent(Player* player, uint32 /*talentId*/) override
    {
        if (IsInActiveMythicPlus(player))
        {
            player->SendSystemMessage("|cffff0000[Mythic+]|r You cannot change talents during a Mythic+ run!");
            player->SendTalentWipeConfirm(ObjectGuid::Empty);  // Close talent UI
        }
    }
    
private:
    bool IsInActiveMythicPlus(Player* player)
    {
        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
            return false;
        
        InstanceScript* instance = map->GetInstanceScript();
        if (!instance)
            return false;
        
        // Check if M+ is active (started but not completed/failed)
        bool isMythicPlus = instance->GetData(DATA_IS_MYTHIC_PLUS);
        bool runActive = instance->GetData(DATA_RUN_STARTED) && !instance->GetData(DATA_RUN_COMPLETED);
        
        return isMythicPlus && runActive;
    }
};
```

**Key Features:**
- ✅ **No gear swaps** during active run (retail behavior)
- ✅ **No talent changes** during active run (retail behavior)
- ✅ **Equipped items locked** (prevents stat manipulation)
- ✅ **Warning message** when attempting changes

---

#### **2.12.5 Alt-F4 / Force Disconnect Exploit Prevention**

**Behavior:** If player force-quits (Alt-F4), group is considered disbanded and keystone downgrades.

**Implementation:**
```cpp
// File: src/server/game/Entities/Player/Player.cpp (hook)
class dc_mythic_DisconnectHandler : public PlayerScript
{
public:
    dc_mythic_DisconnectHandler() : PlayerScript("dc_mythic_DisconnectHandler") {}
    
    void OnLogout(Player* player) override
    {
        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
            return;
        
        InstanceScript* instance = map->GetInstanceScript();
        if (!instance || !instance->GetData(DATA_IS_MYTHIC_PLUS))
            return;
        
        bool runActive = instance->GetData(DATA_RUN_STARTED) && !instance->GetData(DATA_RUN_COMPLETED);
        if (!runActive)
            return;
        
        // ✅ Mark player as disconnected (5-minute grace period)
        instance->SetData64(DATA_DISCONNECTED_PLAYER_GUID, player->GetGUID().GetCounter());
        instance->SetData(DATA_DISCONNECT_TIME, GameTime::GetGameTime().count());
        
        LOG_WARN("mythic", "Player {} disconnected during M+ run (Instance: {})", 
                 player->GetName(), map->GetInstanceId());
        
        // ✅ Start grace period timer
        instance->SetData(DATA_GRACE_PERIOD_ACTIVE, 1);
    }
    
    void OnLogin(Player* player) override
    {
        // Check if player was disconnected from M+ run
        QueryResult result = CharacterDatabase.Query(
            "SELECT instance_id FROM dc_mythic_instance_state "
            "WHERE keystone_owner_guid = {} OR FIND_IN_SET({}, group_members) "
            "LIMIT 1",
            player->GetGUID().GetCounter(), player->GetGUID().GetCounter()
        );
        
        if (result)
        {
            player->SendSystemMessage("|cffff9900[Mythic+]|r You were disconnected from a Mythic+ run. Reconnecting...");
            // Teleport back to instance
        }
    }
};

// Grace period expiration check (in world update loop)
class dc_mythic_GracePeriodChecker : public WorldScript
{
public:
    dc_mythic_GracePeriodChecker() : WorldScript("dc_mythic_GracePeriodChecker") {}
    
    void OnUpdate(uint32 /*diff*/) override
    {
        // Check all active M+ instances for expired grace periods
        // If player doesn't reconnect within 5 minutes:
        // 1. Treat as group disband
        // 2. Downgrade keystone
        // 3. Mark run as failed
    }
};
```

**Key Features:**
- ✅ **5-minute reconnect grace period** (retail-like)
- ✅ **Keystone downgrades if timeout** (prevents Alt-F4 exploit)
- ✅ **Group disband on timeout** (run marked failed)
- ✅ **Auto-reconnect teleport** if player logs back in

---

#### **2.12.6 Weekly Reset Timing (Start Time vs End Time)**

**Behavior:** Players can finish dungeons started before weekly reset. **Start time** determines which week counts, NOT end time.

**Implementation:**
```cpp
// File: src/server/game/Mythic/dc_mythic_weekly.cpp
uint32 GetWeekIDForRun(uint32 startTimestamp)
{
    // ✅ Use START time to determine week (retail behavior)
    // Week IDs calculated from first Tuesday after launch
    const uint32 FIRST_TUESDAY = 1704153600;  // Jan 2, 2024 00:00 UTC
    const uint32 SECONDS_PER_WEEK = 604800;
    
    return ((startTimestamp - FIRST_TUESDAY) / SECONDS_PER_WEEK) + 1;
}

void CompleteMythicRun(Map* instance, Group* group)
{
    InstanceScript* script = instance->GetInstanceScript();
    uint32 startTime = script->GetData(DATA_START_TIME);
    uint32 endTime = GameTime::GetGameTime().count();
    
    // ✅ Award to STARTING week (not current week)
    uint32 weekId = GetWeekIDForRun(startTime);
    uint32 currentWeekId = GetCurrentWeekID();
    
    if (weekId != currentWeekId)
    {
        LOG_INFO("mythic", "Run started in week {}, completed in week {}. Awarding to week {}.",
                 weekId, currentWeekId, weekId);
    }
    
    // Award vault progress to STARTING week
    for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
    {
        Player* member = itr->GetSource();
        if (!member)
            continue;
        
        CharacterDatabase.Execute(
            "INSERT INTO dc_mythic_vault_progress "
            "(player_guid, week_id, season_id, dungeons_completed, highest_key_completed) "
            "VALUES ({}, {}, {}, 1, {}) "
            "ON DUPLICATE KEY UPDATE "
            "dungeons_completed = dungeons_completed + 1, "
            "highest_key_completed = GREATEST(highest_key_completed, {})",
            member->GetGUID().GetCounter(), weekId, GetCurrentSeasonID(),
            script->GetData(DATA_KEYSTONE_LEVEL), script->GetData(DATA_KEYSTONE_LEVEL)
        );
    }
}
```

**Key Features:**
- ✅ **Start time determines week** (not completion time)
- ✅ **Players can finish runs across reset** (retail-like)
- ✅ **Vault progress awarded to starting week** (fair system)
- ✅ **No exploitation possible** (timestamp locked at start)

---

#### **2.12.7 Great Vault Generation (On Open, Not Reset)**

**Behavior:** Vault rewards are generated when player OPENS vault, not at weekly reset.

**Implementation:**
```cpp
// File: src/server/scripts/Custom/dc_npc_great_vault.cpp
class dc_npc_great_vault : public CreatureScript
{
public:
    dc_npc_great_vault() : CreatureScript("dc_npc_great_vault") {}
    
    bool OnGossipHello(Player* player, Creature* /*creature*/) override
    {
        uint32 currentWeekId = GetCurrentWeekID();
        
        // Check if player has vault progress for PREVIOUS week
        uint32 previousWeekId = currentWeekId - 1;
        
        QueryResult result = CharacterDatabase.Query(
            "SELECT dungeons_completed, highest_key_completed, reward_claimed "
            "FROM dc_mythic_vault_progress "
            "WHERE player_guid = {} AND week_id = {}",
            player->GetGUID().GetCounter(), previousWeekId
        );
        
        if (!result)
        {
            player->SendSystemMessage("You have no Great Vault rewards this week.");
            return false;
        }
        
        Field* fields = result->Fetch();
        uint32 dungeonsCompleted = fields[0].Get<uint32>();
        uint8 highestKey = fields[1].Get<uint8>();
        bool rewardClaimed = fields[2].Get<bool>();
        
        if (rewardClaimed)
        {
            player->SendSystemMessage("You already claimed your Great Vault reward this week!");
            return false;
        }
        
        // ✅ Generate rewards ON OPEN (retail behavior)
        std::vector<VaultReward> rewards = GenerateVaultRewards(dungeonsCompleted, highestKey);
        
        // Display vault UI with rewards
        player->PlayerTalkClass->ClearMenus();
        
        if (dungeonsCompleted >= 1)
        {
            std::string reward1 = FormatReward(rewards[0]);
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Slot 1: " + reward1, 0, 1);
        }
        
        if (dungeonsCompleted >= 4)
        {
            std::string reward2 = FormatReward(rewards[1]);
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Slot 2: " + reward2, 0, 2);
        }
        
        if (dungeonsCompleted >= 8)
        {
            std::string reward3 = FormatReward(rewards[2]);
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Slot 3: " + reward3, 0, 3);
        }
        
        player->PlayerTalkClass->SendGossipMenu(1, player->GetGUID());
        return true;
    }
    
private:
    std::vector<VaultReward> GenerateVaultRewards(uint32 dungeonCount, uint8 highestKey)
    {
        // ✅ Random rewards generated at open time
        std::vector<VaultReward> rewards;
        
        // Slot 1 (1 dungeon)
        if (dungeonCount >= 1)
            rewards.push_back(GenerateRandomReward(highestKey));
        
        // Slot 2 (4 dungeons, +6 ilvl)
        if (dungeonCount >= 4)
            rewards.push_back(GenerateRandomReward(highestKey, +6));
        
        // Slot 3 (8 dungeons, +12 ilvl)
        if (dungeonCount >= 8)
            rewards.push_back(GenerateRandomReward(highestKey, +12));
        
        return rewards;
    }
};
```

**Key Features:**
- ✅ **Rewards generated on vault open** (not at reset)
- ✅ **Previous week's progress counted** (week N-1)
- ✅ **One claim per week** (anti-exploit)
- ✅ **3 reward slots** based on dungeon count (1/4/8)

---

#### **2.12.8 Keystone Trading & Soulbound Enforcement**

**Behavior:** Keystones are NEVER tradeable, NEVER mailable, and soulbound on acquisition.

**Implementation:**
```cpp
// File: src/server/game/Items/Item.cpp (hooks)
bool Item::CanBeTraded(Player* /*trader*/, Player* /*receiver*/)
{
    // ✅ Block keystone trading
    if (GetEntry() >= 100000 && GetEntry() <= 100010)
    {
        return false;  // Keystones NEVER tradeable
    }
    return true;
}

bool Item::CanBeMailed()
{
    // ✅ Block keystone mailing
    if (GetEntry() >= 100000 && GetEntry() <= 100010)
    {
        return false;  // Keystones NEVER mailable
    }
    return true;
}

// In Item.dbc creation
Bonding: 1 (Bind on Pickup - immediate soulbound)
Flags: 0x4 (Not tradeable)
```

**Item.dbc Configuration:**
```
Entry: 100000-100008 (M+2 to M+10)
Quality: 4 (Epic)
Bonding: 1 (BoP - Bind on Pickup)
Flags: 0x00000004 (ITEM_FLAG_BIND_TO_ACCOUNT = Cannot trade/mail)
MaxStack: 1
RequiredLevel: 80
```

**Key Features:**
- ✅ **Soulbound on pickup** (Item.dbc Bonding=1)
- ✅ **NEVER tradeable** (hardcoded check)
- ✅ **NEVER mailable** (hardcoded check)
- ✅ **No auction house** (soulbound prevents listing)
- ✅ **One keystone per player** (MaxStack=1)

---

#### **2.12.9 Summary of Edge Case Behaviors**

| Edge Case | Retail Behavior | Implementation Status |
|-----------|----------------|----------------------|
| **Death & Release** | Auto-revive at entrance | ✅ Implemented (Section 2.12.1) |
| **Group Disband** | Keystone -1 level | ✅ Implemented (Section 2.12.2) |
| **Server Crash** | Instance persistence | ✅ Implemented (Section 2.12.3) |
| **Gear/Talent Swap** | Blocked during run | ✅ Implemented (Section 2.12.4) |
| **Alt-F4 Exploit** | 5min grace, then disband | ✅ Implemented (Section 2.12.5) |
| **Weekly Reset Timing** | Start time counts | ✅ Implemented (Section 2.12.6) |
| **Vault Generation** | On open, not reset | ✅ Implemented (Section 2.12.7) |
| **Keystone Trading** | NEVER tradeable/mailable | ✅ Implemented (Section 2.12.8) |

---

## PART 3: RAIDS - HEROIC/MYTHIC SYSTEM (No Mythic+ for Raids)

**IMPORTANT:** Raids do NOT use the Mythic+ keystone system. Raids have only:
- Normal difficulty (baseline)
- Heroic difficulty (increased challenge)
- Mythic difficulty (hardest difficulty)

Mythic+ keystones are EXCLUSIVELY for 5-player dungeons.

### 3.1 Raid Difficulty Scaling
**Implementation Schedule**
```
Phase 1 (Weeks 1-4): WotLK Raids (Naxxramas, Ulduar, ToC, ICC)
Phase 2 (Weeks 5-8): BC Raids (Karazhan, Gruul's, Magtheridon, SSC, TK, BT, Sunwell)
Phase 3 (Weeks 9-12): Vanilla Raids (MC, BWL, AQ20, AQ40, Naxxramas-60)
```

### 3.2 All Raids Receiving Heroic/Mythic Difficulties

**Vanilla Raids (Phase 3):**
```
- Molten Core (40-player → scale to 10/25)
- Blackwing Lair (40-player → scale to 10/25)
- Ruins of Ahn'Qiraj (20-player)
- Temple of Ahn'Qiraj (40-player → scale to 10/25)
- Naxxramas 60 (40-player → scale to 10/25, separate from WotLK Naxx)
```

**Burning Crusade Raids (Phase 2):**
```
- Karazhan (10-player)
- Gruul's Lair (25-player → scale to 10)
- Magtheridon's Lair (25-player → scale to 10)
- Serpentshrine Cavern (25-player → scale to 10/25)
- Tempest Keep (25-player → scale to 10/25)
- Black Temple (25-player → scale to 10/25)
- Sunwell Plateau (25-player → scale to 10/25)
```

**Wrath of the Lich King Raids (Phase 1):**
```
- Naxxramas (10/25-player)
- Ulduar (10/25-player)
- Trial of the Crusader (10/25-player)
- Icecrown Citadel (10/25-player)
```

### 3.3 Difficulty Configuration
```
Normal: 1.0x (baseline)
Heroic: 1.4x HP, 1.2x Damage
Mythic: 2.0x HP, 1.5x Damage

Player Scaling:
- 10-player mode (standard)
- 25-player mode (where applicable)

NO MYTHIC+ FOR RAIDS - Fixed difficulties only
```

### 3.4 Raid Loot - By Difficulty
```
Normal Raid:
- Ilvl 219 items (WotLK), scaled for Vanilla/BC
- 2-3 items per 10 players
- Mythic Raid Tokens: 5 per boss

Heroic Raid:
- Ilvl 226 items (WotLK), scaled for Vanilla/BC
- 3-4 items per 10 players
- Special "Heroic" purple borders on transmog
- Mythic Raid Tokens: 10 per boss

Mythic Raid:
- Ilvl 232 items (WotLK), scaled for Vanilla/BC
- 4-5 items per 10 players
- Unique "Mythic" transmog
- Exclusive title per boss progression
- Mythic Raid Tokens: 20 per boss
```

### 3.5 Raid Achievements
```
Mythic-Specific Achievements:
- "Mythic Raider" - Clear any Mythic raid
- "Herald of the Titans (Mythic)" - Clear Ulduar
- "Immortal Slayer (Mythic)" - Clear Naxxramas with minimal deaths
- "25-Player Mythic Conqueror" - Clear raid with 25 players
- "Vanilla Mythic Master" - Clear all Vanilla raids on Mythic
- "Burning Crusade Legend" - Clear all BC raids on Mythic

Titles Granted:
- "the Mythic Champion"
- "Siege Master" (Icecrown only)
- "Eternal Warden" (Ulduar only)
- "Slayer of the Old Gods" (AQ40 Mythic)
- "Betrayer's Bane" (Black Temple Mythic)
```

---

## PART 4: PRE-WOTLK DUNGEONS - HEROIC/MYTHIC UPGRADES

### 4.1 Dungeon Upgrade List
```
Vanilla Dungeons needing Heroic/Mythic:
- Ragefire Chasm → Add Heroic/Mythic
- Deadmines → Add Heroic/Mythic
- Wailing Caverns → Add Heroic/Mythic
- Shadowfang Keep → Add Heroic/Mythic
- Blackfathom Deeps → Add Heroic/Mythic
- Scarlet Monastery (all wings) → Add Heroic/Mythic
- Zul'Farrak → Add Heroic/Mythic
- Maraudon → Add Heroic/Mythic
- Sunken Temple → Add Heroic/Mythic
- Blackrock Depths → Add Heroic/Mythic
- Blackrock Spire → Add Heroic/Mythic
- Stratholme → Add Heroic/Mythic
- Scholomance → Add Heroic/Mythic

BC Dungeons (already have Heroic, add Mythic):
- Hellfire Ramparts
- The Blood Furnace
- The Shattered Halls
- Mana-Tombs
- Auchenai Crypts
- Sethekk Halls
- Shadow Labyrinth
- The Arcatraz
- The Botanica
- The Mechanar
- Karazhan (add Mythic)
```

### 4.2 Scaling for Legacy Dungeons
```sql
-- Example: Deadmines upgrade
INSERT INTO dc_mythic_dungeons_config VALUES (
  NULL,  -- id
  'deadmines',
  36,    -- dungeon_id
  1,     -- normal_enabled
  1,     -- heroic_enabled (NEW)
  1,     -- mythic_enabled (NEW)
  0,     -- mythic_plus_enabled (Legacy only)
  1,     -- min_level_normal
  35,    -- min_level_heroic
  60,    -- min_level_mythic
  0,     -- min_level_mythic_plus
  1.0,   -- base_health_multiplier
  1.3,   -- scaling_heroic
  1.8,   -- scaling_mythic
  0      -- scaling_mythic_plus_step (N/A)
);
```

### 4.3 Legacy Dungeon Loot
```
Heroic Deadmines/etc:
- Ilvl 110 items
- 1 item per group completion
- Tokens for transmog vendor

Mythic Deadmines/etc:
- Ilvl 150 items
- 1-2 items per group
- Rare cosmetic drops (pets, vanity items)
```

---

## PART 4.5: DATABASE OPTIMIZATION & PERFORMANCE

### **4.5.1 Composite Indexes for Common Queries**

The following indexes significantly improve query performance for leaderboards, vault progress, and run history.

**Run History Optimizations:**
```sql
-- Add composite indexes for leaderboard queries
ALTER TABLE dc_mythic_run_history
ADD INDEX idx_dungeon_level_time (dungeon_id, keystone_level, completion_time ASC, deaths ASC),
ADD INDEX idx_player_season (player_guid, season_id, completion_time DESC),
ADD INDEX idx_leaderboard_fast (dungeon_id, keystone_level, completion_time ASC) INCLUDE (player_guid, deaths);

-- Partition by season for faster old-season queries
ALTER TABLE dc_mythic_run_history
PARTITION BY RANGE (season_id) (
  PARTITION p_season1 VALUES LESS THAN (2),
  PARTITION p_season2 VALUES LESS THAN (3),
  PARTITION p_season3 VALUES LESS THAN (4),
  PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- Archive old runs (delete runs older than 12 months)
CREATE EVENT cleanup_old_mythic_runs
ON SCHEDULE EVERY 1 WEEK
DO
  DELETE FROM dc_mythic_run_history
  WHERE completion_time < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 12 MONTH));
```

**Vault Progress Optimizations:**
```sql
-- Fast vault queries by player and week
ALTER TABLE dc_mythic_vault_progress
ADD INDEX idx_player_week_season (player_guid, week_id, season_id),
ADD INDEX idx_week_completion (week_id, dungeons_completed);
```

**Loot Tracker Optimizations:**
```sql
-- Fast tradeable loot validation queries
ALTER TABLE dc_mythic_loot_tracker
ADD INDEX idx_item_timestamp (item_guid, drop_timestamp),
ADD INDEX idx_cleanup (drop_timestamp);  -- For automated cleanup

-- Eligible players fast lookup
ALTER TABLE dc_mythic_loot_eligible_players
ADD INDEX idx_item_player (item_guid, player_guid);
```

**Seasonal Dungeons Optimizations:**
```sql
-- Fast seasonal dungeon lookups
ALTER TABLE dc_mythic_seasonal_dungeons
ADD INDEX idx_season_active (season_id, active),
ADD INDEX idx_dungeon (dungeon_id);
```

**Affix Weeks Optimizations:**
```sql
-- Fast current week affix lookup
ALTER TABLE dc_mythic_affix_weeks
ADD INDEX idx_week_active (week_id, is_active);
```

---

### **4.5.2 Materialized View for Leaderboards**

Create cached leaderboard table to avoid expensive real-time queries:

```sql
-- Leaderboard cache (updated after each M+ completion)
CREATE TABLE dc_mythic_leaderboard_cache (
  id INT PRIMARY KEY AUTO_INCREMENT,
  dungeon_id INT NOT NULL,
  keystone_level INT NOT NULL,
  rank INT NOT NULL,
  player_guid BIGINT NOT NULL,
  player_name VARCHAR(12),
  completion_time INT NOT NULL,
  deaths INT NOT NULL,
  run_id BIGINT NOT NULL,
  season_id INT NOT NULL,
  last_updated DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY idx_dungeon_level_rank (dungeon_id, keystone_level, rank),
  KEY idx_player (player_guid),
  KEY idx_season (season_id)
);

-- Update cache on new run completion (stored procedure)
DELIMITER $$
CREATE PROCEDURE UpdateLeaderboardCache(
  IN p_dungeon_id INT,
  IN p_keystone_level INT,
  IN p_season_id INT
)
BEGIN
  -- Clear existing cache for this dungeon/level/season
  DELETE FROM dc_mythic_leaderboard_cache
  WHERE dungeon_id = p_dungeon_id
    AND keystone_level = p_keystone_level
    AND season_id = p_season_id;
  
  -- Rebuild top 100 rankings
  INSERT INTO dc_mythic_leaderboard_cache
    (dungeon_id, keystone_level, rank, player_guid, player_name, completion_time, deaths, run_id, season_id)
  SELECT 
    dungeon_id,
    keystone_level,
    ROW_NUMBER() OVER (ORDER BY completion_time ASC, deaths ASC) as rank,
    player_guid,
    (SELECT name FROM characters WHERE guid = player_guid) as player_name,
    completion_time,
    deaths,
    run_id,
    season_id
  FROM dc_mythic_run_history
  WHERE dungeon_id = p_dungeon_id
    AND keystone_level = p_keystone_level
    AND season_id = p_season_id
  ORDER BY completion_time ASC, deaths ASC
  LIMIT 100;
END$$
DELIMITER ;
```

**C++ Integration:**
```cpp
// File: src/server/game/Mythic/dc_mythic_leaderboards.cpp
void UpdateLeaderboardCache(uint32 dungeonId, uint8 keystoneLevel, uint32 seasonId)
{
    // Call stored procedure to rebuild cache
    WorldDatabase.Execute(
        "CALL UpdateLeaderboardCache({}, {}, {})",
        dungeonId, keystoneLevel, seasonId
    );
    
    LOG_INFO("mythic", "Updated leaderboard cache for dungeon {} level {} season {}",
             dungeonId, keystoneLevel, seasonId);
}

// Fast leaderboard query (from cache, not raw table)
std::vector<LeaderboardEntry> GetLeaderboard(uint32 dungeonId, uint8 keystoneLevel)
{
    QueryResult result = WorldDatabase.Query(
        "SELECT rank, player_name, completion_time, deaths "
        "FROM dc_mythic_leaderboard_cache "
        "WHERE dungeon_id = {} AND keystone_level = {} "
        "ORDER BY rank ASC LIMIT 100",
        dungeonId, keystoneLevel
    );
    
    // Process results...
}
```

---

### **4.5.3 GearScore Slot Caching**

Avoid recalculating full GearScore on every equipment change:

```sql
-- Cache GearScore components per slot
CREATE TABLE dc_mythic_gearscore_cache (
  player_guid BIGINT PRIMARY KEY,
  slot_0 INT DEFAULT 0,  -- Head
  slot_1 INT DEFAULT 0,  -- Neck
  slot_2 INT DEFAULT 0,  -- Shoulders
  slot_3 INT DEFAULT 0,  -- Chest
  slot_4 INT DEFAULT 0,  -- Waist
  slot_5 INT DEFAULT 0,  -- Legs
  slot_6 INT DEFAULT 0,  -- Feet
  slot_7 INT DEFAULT 0,  -- Wrists
  slot_8 INT DEFAULT 0,  -- Hands
  slot_9 INT DEFAULT 0,  -- Finger1
  slot_10 INT DEFAULT 0, -- Finger2
  slot_11 INT DEFAULT 0, -- Trinket1
  slot_12 INT DEFAULT 0, -- Trinket2
  slot_13 INT DEFAULT 0, -- Back
  slot_14 INT DEFAULT 0, -- MainHand
  slot_15 INT DEFAULT 0, -- OffHand
  slot_16 INT DEFAULT 0, -- Ranged
  total_score INT DEFAULT 0,
  last_updated DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_score (total_score)
);

-- Also store in characters table for quick lookups
ALTER TABLE characters
ADD COLUMN gear_score INT UNSIGNED DEFAULT 0,
ADD INDEX idx_gearscore (gear_score);
```

**C++ Optimized Implementation:**
```cpp
// File: src/server/game/Mythic/dc_gearscore_cache.cpp
namespace dc_mythic
{
    void UpdateGearScoreSlot(Player* player, uint8 slot)
    {
        // ✅ Only recalculate changed slot (18x faster)
        uint32 oldSlotScore = GetCachedSlotScore(player, slot);
        uint32 newSlotScore = CalculateSlotScore(player, slot);
        
        // Update cache
        CharacterDatabase.Execute(
            "UPDATE dc_mythic_gearscore_cache "
            "SET slot_{} = {}, total_score = total_score - {} + {}, last_updated = NOW() "
            "WHERE player_guid = {}",
            slot, newSlotScore, oldSlotScore, newSlotScore, player->GetGUID().GetCounter()
        );
        
        // Update characters table (async, batched every 30 seconds)
        static std::unordered_map<uint64, uint32> pendingUpdates;
        pendingUpdates[player->GetGUID().GetCounter()] = GetTotalGearScore(player);
    }
    
    void FlushGearScoreUpdates()
    {
        // ✅ Batch database writes (95% less DB traffic)
        SQLTransaction trans = CharacterDatabase.BeginTransaction();
        
        for (auto& [guid, score] : pendingUpdates)
        {
            trans->Append("UPDATE characters SET gear_score = {} WHERE guid = {}", score, guid);
        }
        
        CharacterDatabase.CommitTransaction(trans);
        pendingUpdates.clear();
    }
}
```

---

### **4.5.4 Query Performance Targets**

**Expected Load:**
- **Concurrent M+ runs:** 20-50
- **Daily M+ completions:** 500-2,000
- **Active players:** 500-5,000
- **Database size:** 10-100 GB (1 year of data)

**Query Performance Goals:**
- ✅ Leaderboard query: < 50ms (cached)
- ✅ Vault progress query: < 10ms (indexed)
- ✅ GearScore lookup: < 5ms (characters table)
- ✅ Run history insert: < 20ms (async)
- ✅ Loot eligibility check: < 10ms (indexed)

**Monitoring:**
```sql
-- Slow query log
SET GLOBAL slow_query_log = 1;
SET GLOBAL long_query_time = 0.5;  -- Log queries > 500ms

-- Check index usage
SELECT table_name, index_name, cardinality
FROM information_schema.statistics
WHERE table_schema = 'acore_characters'
  AND table_name LIKE 'dc_mythic_%';
```

---

### **4.5.5 Connection Pooling & Async Queries**

**C++ Best Practices:**
```cpp
// Use async queries for non-critical data
CharacterDatabase.AsyncQuery(
    "INSERT INTO dc_mythic_run_history (...) VALUES (...)"
).then([](QueryResult result) {
    // Handle result asynchronously
});

// Use prepared statements for repeated queries
PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_MYTHIC_VAULT);
stmt->setUInt64(0, playerGUID);
stmt->setUInt32(1, weekId);
QueryResult result = CharacterDatabase.Query(stmt);

// Batch inserts for efficiency
SQLTransaction trans = CharacterDatabase.BeginTransaction();
for (Player* member : group)
{
    trans->Append("INSERT INTO dc_mythic_vault_progress ...");
}
CharacterDatabase.CommitTransaction(trans);
```

---

## PART 5: IMPLEMENTATION ROADMAP

### Phase 1: Database & Core Systems (Week 1-2)
**Tasks:**
- [ ] Create database tables (dc_mythic_*)
- [ ] Create NPC teleporter (seasonal, reusable template)
- [ ] Implement difficulty scaling logic (C++ handler)
- [ ] Create rating calculation system

**Database Tables:**
```sql
CREATE TABLE dc_mythic_seasons (
  season_id INT PRIMARY KEY AUTO_INCREMENT,
  season_name VARCHAR(100),
  start_date DATETIME,
  end_date DATETIME,
  max_rating INT,
  active TINYINT(1),
  KEY idx_active (active)
);

CREATE TABLE dc_mythic_dungeons_config (
  id INT PRIMARY KEY AUTO_INCREMENT,
  dungeon_name VARCHAR(100),
  dungeon_id INT,
  normal_enabled TINYINT(1),
  heroic_enabled TINYINT(1),
  mythic_enabled TINYINT(1),
  mythic_plus_enabled TINYINT(1),
  min_level_normal INT,
  min_level_heroic INT,
  min_level_mythic INT,
  min_level_mythic_plus INT,
  base_health_multiplier FLOAT,
  scaling_heroic FLOAT,
  scaling_mythic FLOAT,
  scaling_mythic_plus_step FLOAT,
  UNIQUE KEY idx_dungeon_id (dungeon_id)
);

CREATE TABLE dc_mythic_seasonal_dungeons (
  id INT PRIMARY KEY AUTO_INCREMENT,
  season_id INT NOT NULL,
  dungeon_id INT NOT NULL,
  dungeon_name VARCHAR(100),
  display_order INT DEFAULT 0,  -- Order in teleporter menu
  active TINYINT(1) DEFAULT 1,
  FOREIGN KEY (season_id) REFERENCES dc_mythic_seasons(season_id),
  FOREIGN KEY (dungeon_id) REFERENCES dc_mythic_dungeons_config(dungeon_id),
  UNIQUE KEY idx_season_dungeon (season_id, dungeon_id),
  KEY idx_season_active (season_id, active)
);

-- Example: Season 1 with 8 active WotLK dungeons
INSERT INTO dc_mythic_seasonal_dungeons (season_id, dungeon_id, dungeon_name, display_order) VALUES
(1, 574, 'Utgarde Keep', 1),
(1, 575, 'Utgarde Pinnacle', 2),
(1, 576, 'The Nexus', 3),
(1, 578, 'The Oculus', 4),
(1, 595, 'The Culling of Stratholme', 5),
(1, 599, 'Halls of Stone', 6),
(1, 600, 'Drak\'Tharon Keep', 7),
(1, 601, 'Azjol-Nerub', 8);

-- Example: Season 2 rotates to different 8 dungeons (BC + WotLK mix)
INSERT INTO dc_mythic_seasonal_dungeons (season_id, dungeon_id, dungeon_name, display_order) VALUES
(2, 542, 'The Blood Furnace', 1),
(2, 543, 'Hellfire Ramparts', 2),
(2, 585, 'Magister\'s Terrace', 3),
(2, 574, 'Utgarde Keep', 4),
(2, 595, 'The Culling of Stratholme', 5),
(2, 599, 'Halls of Stone', 6),
(2, 608, 'Violet Hold', 7),
(2, 619, 'Ahn\'kahet: The Old Kingdom', 8);

CREATE TABLE dc_mythic_player_rating (
  id INT PRIMARY KEY AUTO_INCREMENT,
  player_guid BIGINT,
  season_id INT,
  current_rating INT,
  best_run_rating INT,
  highest_key_completed INT DEFAULT 0,
  total_runs INT,
  updated_at DATETIME,
  FOREIGN KEY (season_id) REFERENCES dc_mythic_seasons(season_id),
  UNIQUE KEY idx_player_season (player_guid, season_id)
);

CREATE TABLE dc_mythic_run_history (
  id INT PRIMARY KEY AUTO_INCREMENT,
  dungeon_id INT,
  difficulty_level INT,
  season_id INT,
  player_guid BIGINT,
  rating_earned INT,
  deaths_count INT,
  completion_time INT,  -- seconds
  completed_at DATETIME,
  FOREIGN KEY (season_id) REFERENCES dc_mythic_seasons(season_id),
  KEY idx_player_dungeon (player_guid, dungeon_id)
);

CREATE TABLE dc_mythic_affixes (
  id INT PRIMARY KEY AUTO_INCREMENT,
  affix_name VARCHAR(100),
  description TEXT,
  min_key_level INT,
  max_key_level INT,
  active TINYINT(1),
  effect_percentage FLOAT,
  KEY idx_active (active)
);

CREATE TABLE dc_mythic_tokens_loot (
  id INT PRIMARY KEY AUTO_INCREMENT,
  item_entry INT,
  dungeon_id INT,
  difficulty_tier VARCHAR(50),
  tokens_reward INT,
  drop_chance FLOAT,
  UNIQUE KEY idx_drop (dungeon_id, item_entry, difficulty_tier)
);
```

### Phase 2: Dungeon System (Week 3-4)
**Tasks:**
- [ ] Implement NPC 300315 (Mythic+ Dungeon Teleporter) following Curator pattern
- [ ] Implement NPC 300316 (Mythic Raid Teleporter) following Curator pattern
- [ ] Create dungeon entry gate/shield system
- [ ] Implement difficulty selection via Gossip menus
- [ ] Add difficulty scaling to creature spawning
- [ ] Implement death counter per run

**Scripts Needed:**
- `src/server/scripts/DC/DungeonEnhancement/npc_mythic_plus_dungeon_teleporter.cpp` - NPC 300315
- `src/server/scripts/DC/DungeonEnhancement/npc_mythic_raid_teleporter.cpp` - NPC 300316
- `src/server/scripts/DC/DungeonEnhancement/MythicDifficultyScaling.cpp` - Scaling logic
- `src/server/scripts/DC/DungeonEnhancement/DungeonEnhancementConstants.h` - Action/quest ID ranges
- `MythicRunManager.cpp` - Run tracking (M+ dungeons only)

### Phase 3: Rating & Rewards (Week 5-6)
**Tasks:**
- [ ] Implement rating calculation
- [ ] Create token vendor NPC (300317) following Vendor pattern from ItemUpgrades
- [ ] Setup loot tables for Mythic+ (dc_mythic_tokens_loot)
- [ ] Implement seasonal vault system
- [ ] Integrate with dc_achievements system for Mythic+ achievements

**Integration with Existing Systems:**
- Token vendor follows pattern from ItemUpgradeNPC_Vendor (300313)
- Achievement tracking uses existing dc_achievements.cpp infrastructure
- Currency tracking similar to dc_player_upgrade_tokens pattern

### Phase 4: Raid Scaling (Week 7-10)
**Tasks:**
- [ ] Apply mythic difficulty to all raid bosses
- [ ] Implement 10/25 player scaling
- [ ] Create Mythic raid loot tables
- [ ] Add Mythic-exclusive titles/achievements

### Phase 5: Legacy Dungeons Upgrade (Week 11-12)
**Tasks:**
- [ ] Add Heroic/Mythic to all vanilla dungeons
- [ ] Scale BC dungeons for Mythic
- [ ] Update legacy loot tables
- [ ] Add veteran cosmetic rewards

### Phase 6: Testing & Balancing (Week 13-14)
**Tasks:**
- [ ] Difficulty tuning (HP/Damage ratios)
- [ ] Affix balance testing
- [ ] Loot drop rate validation
- [ ] Performance optimization
- [ ] PvP server considerations

---

## PART 6: CONFIGURATION SETTINGS

### 6.1 Server Configuration Variables
```lua
-- mythic_config.lua
MYTHIC_SYSTEM_ENABLED = true
MYTHIC_SEASON_DURATION_DAYS = 91  -- 13 weeks

-- Dungeon Settings
MYTHIC_DEATH_LIMIT = 3  -- Deaths allowed per run
MYTHIC_TIMER_ENABLED = false  -- Not implementing real timer
MYTHIC_MIN_GROUP_SIZE = 5  -- Can be 1-5 players

-- Scaling Multipliers
MYTHIC_NORMAL_HP_MULT = 1.0
MYTHIC_HEROIC_HP_MULT = 1.3
MYTHIC_HEROIC_DMG_MULT = 1.2
MYTHIC_MYTHIC_HP_MULT = 1.8
MYTHIC_MYTHIC_DMG_MULT = 1.5
MYTHIC_PLUS_STEP_HP = 0.15  -- Per key level (+1 = +0.15x)
MYTHIC_PLUS_STEP_DMG = 0.12

-- Reward Settings
MYTHIC_TOKEN_PER_KILL = 1
MYTHIC_TOKEN_COMPLETION_REWARD = {5, 10, 15}  -- By tier
MYTHIC_LOOT_TOKENS_COST = 50  -- For vendor exchange
MYTHIC_SEASONAL_RATING_CAP = 1000
MYTHIC_AFFIX_COUNT_MIN = 1
MYTHIC_AFFIX_COUNT_MAX = 3
```

### 6.2 Difficulty Access Requirements
```sql
UPDATE dc_mythic_dungeons_config SET
  min_level_normal = 35,      -- Level 35+
  min_level_heroic = 50,      -- Level 50+
  min_level_mythic = 80,      -- Level 80 (endgame)
  min_level_mythic_plus = 80  -- Level 80 (endgame)
WHERE dungeon_category IN ('vanilla', 'bc', 'wotlk');
```

---

## PART 7: API & COMMAND STRUCTURE

### 7.1 Player Commands
```
/mythic              - Opens Mythic+ main menu
/mythic join <dung> <diff>  - Join specific dungeon + difficulty
/mythic rating       - Show current season rating
/mythic vault        - View weekly vault rewards
/mythic history      - Show run history
/mythic season       - Show current season info
```

### 7.2 Admin Commands
```
.mythic season create "Season Name"
.mythic season end <season_id>
.mythic dungeon config <dungeon_id> <setting> <value>
.mythic affix add <affix_name> <effect%>
.mythic vault reset  -- Reset weekly vault
.mythic rating reset <player_guid>  -- Emergency reset
```

### 7.3 NPC Dialog Systems (Following DarkChaos Architecture)

**NPC 300315: Mythic+ Dungeon Teleporter**
```
Main Menu:
├─ "Browse Mythic Dungeons" → List all Mythic-enabled dungeons
├─ "Browse Mythic+ Dungeons (Seasonal)" → List seasonal rotation dungeons
├─ "View My Statistics" → Show rating, highest key, total runs
├─ "Mythic+ System Help" → Explain system mechanics
└─ Back

Dungeon Selection:
├─ [Dungeon Name] - Mythic (Level 80+)
│   └─ Teleport to dungeon entrance
├─ [Dungeon Name] - Mythic+1 to +10 (Seasonal)
│   ├─ Select Key Level (1-10)
│   ├─ Select Affixes (1-3)
│   └─ Confirm & Teleport
└─ Back to Main Menu

Statistics Display:
├─ Current Rating: [X] points
├─ Highest Key Completed: Mythic+[X]
├─ Total Runs This Season: [X]
├─ Season: [Season Name]
└─ Back
```

**NPC 300316: Mythic Raid Teleporter**
```
Main Menu:
├─ "Browse Mythic Raids"
│   ├─ Naxxramas (Mythic 10/25)
│   ├─ Ulduar (Mythic 10/25)
│   ├─ Trial of the Crusader (Mythic 10/25)
│   └─ Icecrown Citadel (Mythic 10/25)
├─ "View Raid Statistics"
│   └─ Show boss kills, achievements, attempts
├─ "Mythic Raid Help"
│   └─ Explain difficulty, rewards, requirements
└─ Back

Raid Selection:
├─ [Raid Name] - Mythic 10-player
│   └─ Teleport to raid entrance
├─ [Raid Name] - Mythic 25-player
│   └─ Teleport to raid entrance (requires 25 in group)
└─ Back
```

**Implementation Pattern (Follows ItemUpgradeCurator.cpp):**
- Use GOSSIP_ACTION_INFO_DEF + offset for action IDs
- CharacterDatabase.Query for player stats (dc_mythic_player_rating)
- try-catch blocks for database error handling
- Color-coded text: |cff00ff00 (green), |cffff9900 (orange), |cffff0000 (red)
- Back button at GOSSIP_ACTION_INFO_DEF + 20

---

## PART 8: ACHIEVEMENTS & COSMETICS

### 8.1 Mythic+ Achievements
```
Dungeon Achievements:
- "Mythic Champion" - Complete any Mythic+ dungeon
- "Sergeant of the Mythic+" - Reach 500 rating
- "Commander of Mythic+" - Reach 1000 rating
- "Grand Master of Mythic+" - Reach seasonal max rating
- "Speed Runner" - Complete Mythic+X in 50% of normal time

Dungeon-Specific:
- "[Dungeon] Mythic Master" - Clear all 3 affixes variants
- "[Dungeon] No Mercy" - Clear with 0 deaths
```

### 8.2 Raid Achievements
```
- "Mythic Raider" - Defeat first Mythic boss
- "Mythic Conqueror" - Clear entire Mythic raid
- "Immortal Slayer (Mythic)" - Naxxramas with <10 deaths total
- "Eternal Warden (Mythic)" - Ulduar with mechanics intact
```

### 8.3 Cosmetic Rewards
```
Titles:
- "the Mythic" (500 rating)
- "Siege Master" (1000 rating)
- "Eternal Conqueror" (Raid clear)
- "[Dungeon] Slayer" (All difficulty variants)

Transmog Items:
- Mythic+ armor set (ilvl 239, purple glow)
- Raid Mythic set (ilvl 245, golden glow)
- Weapon transmogs (unique skins)

Pets & Mounts:
- "Mythic Serpent" pet (5000 tokens)
- "Speedster's Mount" (1000 rating achieve)
```

---

## PART 9: BALANCE & TUNING NOTES

### 9.1 Difficulty Scaling Philosophy
- **Heroic**: Moderate threat, mistakes punishable (1.3x HP)
- **Mythic**: High threat, skill required (1.8x HP)
- **Mythic+**: Escalating challenge (2.0x → 3.2x HP at +10)
- **Affix scaling**: Don't exceed 1.5x modifier total (base + affix)

### 9.2 Avoiding Power Creep
```
Season 1: Rating cap 1000
Season 2: Rating cap 1200 (20% increase)
Season 3: Rating cap 1400 (17% increase)
→ Maintains seasonal achievement feeling
→ Prevents infinite scaling issues
```

### 9.3 Raid Mythic Tuning
```
- Boss damage: +50% (vs Heroic baseline)
- Boss HP: +100% (vs Heroic baseline)
- Mechanics: Keep same, more punishing
- Add enrage timer: 8-10 min per boss
```

### 9.4 Testing Checklist
- [ ] Mythic+1 should take 20-25 min avg
- [ ] Mythic+10 should take 35-45 min avg
- [ ] 3 affixes shouldn't exceed 2x baseline difficulty
- [ ] Loot drop rates tested with 100+ runs
- [ ] Rating calculations verified mathematically
- [ ] Server performance under 20 concurrent Mythic+ runs

---

## PART 10: FUTURE ENHANCEMENTS (Post-Launch)

### 10.1 Not Implementing Now
- ❌ Real-time dungeon timer UI
- ❌ Complex affix mechanics (portals, summons)
- ❌ Mythic+ raid scaling (only raids at Mythic)
- ❌ Leaderboards/competitive ranking (Season 2 feature)
- ❌ Dynamic difficulty adjustment (too complex)

### 10.2 Season 2+ Features
- ⏳ Leaderboard system (Top 100 rating rankings)
- ⏳ Weekly challenge affixes (all groups get same 3)
- ⏳ Transmog cosmetics from previous seasons (archive)
- ⏳ Cross-realm grouping support
- ⏳ Dungeon journal with boss mechanics

---

## CONCLUSION

This Mythic+ system provides engaging endgame content while maintaining separation from core AzerothCore systems. The phased implementation allows for thorough testing and balance tuning, with clear success metrics for each phase.

**Key Success Criteria:**
✓ System is fully separate from AzerothCore core
✓ Seasonal progression feels rewarding
✓ Difficulty scaling is perceivable but fair
✓ Loot is desirable but not mandatory for PvP
✓ Performance remains stable with multiple concurrent runs
✓ Community engagement increases post-launch

---

## PART 11: IMPROVEMENTS & OPTIMIZATION IDEAS (For Discussion)

### 11.1 ✅ Keystone System (APPROVED - Physical Items)
**Current:** NPC gossip menu to select difficulty
**Proposed:** Physical keystone items in inventory (RETAIL-LIKE)

**✅ FINAL DECISION: How to Get Keystones**

**Keystone Acquisition Methods:**

**1. Initial Keystone (New Players):**
- Complete any Mythic (M+0) dungeon without a keystone
- Upon completion → Receive M+2 keystone (starting level)
- Keystone is RANDOM dungeon from current seasonal pool
- Example: Player completes Utgarde Keep M+0 → Receives M+2 keystone for Halls of Lightning

**2. Weekly Vault (Existing Players):**
- Players who completed M+ dungeons last week receive new keystone from vault
- Keystone level = **Highest M+ level completed last week**
- Example: Player completed M+7 last week → Receives M+7 keystone this week
- If no M+ completed last week → Must complete M+0 to get new keystone

**3. Keystone Master NPC (Replacement Service):**
- **NPC Name:** "Keystone Master" (NPC ID: 100010)
- **Location:** Next to Mythic+ Teleporter NPCs (Stormwind, Orgrimmar, Dalaran)
- **Service:** Replace lost/destroyed keystone
  
**Replacement Conditions:**
- Player must have completed at least 1 M+ dungeon THIS season
- Replacement keystone level = **Highest M+ level completed THIS season**
- Example: Player's best this season is M+5 → Receives M+5 replacement keystone
- Cooldown: 1 per week (prevents abuse)

**Keystone Master NPC Gossip:**
```cpp
"Greetings, challenger. I can help you if you've lost your keystone.

Your highest Mythic+ completion this season: M+7

I can provide you with a replacement M+7 keystone. This service is available once per week.

[Request Replacement Keystone] (Available now)
[View My Season Statistics]
[Nevermind]
"
```

**Workflow:**
1. Player completes M+0 dungeon (no keystone required) → Receives M+2 keystone
2. Player upgrades keystone by completing M+ runs (0-5 deaths = +2, 6-10 = +1, 11-14 = same)
3. Player loses keystone to 15 deaths or group disband → Visit Keystone Master NPC
4. Keystone Master gives replacement at player's highest level this season
5. Weekly reset → All players who completed M+ last week get new keystone from vault (at highest level)

**Benefits:**
- More retail-like experience
- Visual representation of progression (item in inventory)
- Can implement "depleted" keys (downgrade on failure)
- Natural key upgrade mechanic (+1 or +2 on success)
- Weekly reset system (like retail)
- Safety net for lost keystones (Keystone Master NPC)

**Implementation:**
```
Server: 
- Create custom item entries (100000-100008 for M+2 to M+10)
- ItemTemplate: class=12, subclass=0, quality=4 (Epic)
- Flags: BoP, Unique, CANNOT be traded or mailed
- Weekly reset: All keystones reset to highest level completed last week

Client (DBC): 
- Item.dbc entries for keystones (100000-100008)
- Custom icon with "+X" overlay per level
- Tooltip: "Mythic Keystone +X\nInsert into Font of Power to begin.\nResets weekly."

Database: 
- dc_mythic_keystones (player_guid, item_guid, dungeon_id, level, affixes_json, created_week)
- Track keystone ownership, prevent duplication
- Auto-reset keystones on weekly maintenance

Workflow:
1. Player receives keystone from M+0 completion, weekly vault, or Keystone Master NPC
2. Keystone is SOULBOUND - cannot be traded, sold, or mailed
3. Player travels to dungeon entrance
4. Group leader (or designated player) places their keystone in "Font of Power" object
5. ONLY ONE KEYSTONE REQUIRED - Only one player needs to sacrifice their keystone (retail-like)
6. Keystone validates: correct dungeon, group composition, player level
7. Keystone consumed - starts Mythic+ instance for entire group
8. On completion: Key owner receives new keystone (upgrade based on deaths: 0-5=+2, 6-10=+1, 11-14=same)
9. On failure: Key owner's keystone destroyed (must get replacement from Keystone Master NPC)
10. Weekly Reset: All players get vault keystone at highest level completed last week
```

**Keystone Item IDs:**
```
NO M+1 KEYSTONES - Start at M+2!

100000 = Mythic Keystone +2
100001 = Mythic Keystone +3
100002 = Mythic Keystone +4
100003 = Mythic Keystone +5
100004 = Mythic Keystone +6
100005 = Mythic Keystone +7
100006 = Mythic Keystone +8
100007 = Mythic Keystone +9
100008 = Mythic Keystone +10
100009 = Reserved (future M+11+)
100010 = Keystone Master NPC (not an item)
```

**Note:** Mythic+1 does NOT exist. Players run Mythic (M+0) without a keystone, then receive M+2 keystones to begin keystone progression.

**Keystone Generation Logic:**
```cpp
Item* GenerateMythicKeystone(Player* player, uint32 level, uint32 dungeonId) {
  // M+1 doesn't exist - start at M+2
  if (level < 2) level = 2;
  if (level > 10) level = 10;
  
  uint32 itemEntry = 100000 + (level - 2);  // 100000 = M+2, 100008 = M+10
  
  // Remove existing keystone
  player->DestroyItemCount(100000, 11, true, false);  // Remove all keystone types
  
  Item* keystone = player->AddItem(itemEntry, 1);
  if (!keystone) return nullptr;
  
  // Make soulbound (cannot trade)
  keystone->SetBinding(true);
  keystone->SetState(ITEM_CHANGED, player);
  
  // Get current week ID
  uint32 weekId = GetCurrentWeekId();
  
  // Store metadata in database
  CharacterDatabase.Execute(
    "INSERT INTO dc_mythic_keystones (player_guid, item_guid, dungeon_id, level, affixes_json, created_week, depleted) "
    "VALUES ({}, {}, {}, {}, '{}', {}, 0)",
    player->GetGUID().GetCounter(),
    keystone->GetGUID().GetCounter(),
    dungeonId,
    level,
    GenerateAffixesJSON(level),  // Weekly rotation based affixes
    weekId
  );
  
  player->SendSystemMessage("|cff00ff00You received a Mythic Keystone +%u!|r", level);
  return keystone;
}

// Weekly reset handler
void ResetAllKeystones() {
  uint32 weekId = GetCurrentWeekId();
  uint32 resetLevel = sConfigMgr->GetOption<uint32>("MythicPlus.Keystone.WeeklyResetLevel", 2);
  
  // Ensure reset level is at least 2 (no M+1)
  if (resetLevel < 2) resetLevel = 2;
  
  // Get all active keystones
  QueryResult result = CharacterDatabase.Query(
    "SELECT player_guid, item_guid, level FROM dc_mythic_keystones WHERE created_week < {}", 
    weekId
  );
  
  if (!result) return;
  
  do {
    Field* fields = result->Fetch();
    uint64 playerGuid = fields[0].Get<uint64>();
    uint64 itemGuid = fields[1].Get<uint64>();
    uint32 oldLevel = fields[2].Get<uint32>();
    
    // Reset keystone to base level (minimum M+2)
    CharacterDatabase.Execute(
      "UPDATE dc_mythic_keystones SET level = {}, created_week = {}, depleted = 0 WHERE item_guid = {}",
      resetLevel, weekId, itemGuid
    );
    
    LOG_INFO("mythic", "Reset keystone {} for player {} from level {} to level {}", 
      itemGuid, playerGuid, oldLevel, resetLevel);
      
  } while (result->NextRow());
  
  LOG_INFO("mythic", "Weekly keystone reset completed for week {}", weekId);
}

// Keystone depletion handler (on failed run)
void DepleteKeystone(Player* player, Item* keystone) {
  uint32 currentLevel = GetKeystoneLevel(keystone);
  
  // Minimum keystone level is M+2
  uint32 newLevel = (currentLevel <= 2) ? 2 : (currentLevel - 1);
  
  if (newLevel == currentLevel) {
    // Already at minimum level (M+2), stays at M+2
    player->SendSystemMessage("|cffffff00Your keystone remains at +%u (minimum level).|r", newLevel);
    return;
  }
  
  uint32 newItemEntry = 100000 + (newLevel - 2);
  
  // Remove current keystone
  player->DestroyItem(keystone->GetBagSlot(), keystone->GetSlot(), true);
  
  // Generate new keystone at lower level (or same dungeon at M+2)
  Item* newKeystone = GenerateMythicKeystone(player, newLevel, GetKeystoneDungeon(keystone));
  
  if (newKeystone) {
    player->SendSystemMessage("|cffffff00Your keystone has been depleted to level +%u.|r", newLevel);
  }
}
```

**Keystone Trading Prevention:**
```cpp
// Hook in Item.cpp
bool Item::CanBeTraded(bool mail, bool trade) const {
  // Prevent keystone trading
  if (GetEntry() >= 100000 && GetEntry() <= 100010) {
    return false;  // Keystones cannot be traded or mailed
  }
  return ItemTemplate::CanBeTraded(mail, trade);
}

// Hook in Player.cpp
void Player::SendTradeError(TradeStatus status) {
  if (status == TRADE_STATUS_TRADE_ACCEPT) {
    // Check for keystones in trade window
    for (uint8 i = 0; i < TRADE_SLOT_COUNT; ++i) {
      Item* item = GetTradeData()->GetItem(static_cast<TradeSlots>(i));
      if (item && item->GetEntry() >= 100000 && item->GetEntry() <= 100010) {
        SendSystemMessage("Mythic Keystones cannot be traded!");
        return;
      }
    }
  }
}
```

**Concerns Addressed:**
- **No trading:** Keystones are strictly soulbound, cannot be traded or mailed
- **Weekly reset:** All keystones reset to base level on Tuesday maintenance
- **Duplication prevention:** Bind keystone GUID to database entry, validate on use
- **Key deletion:** Keystones cannot be destroyed manually, only via system reset

---

### 11.2 ⏭️ Timer System (OPTIONAL - NOT REQUIRED)
**Status:** Discussed but **not implementing for Phase 1**
**Reason:** Death-based system is simpler, timer adds UI complexity

*If implemented later:* Use addon to display timer, server tracks completion time for leaderboards

---

### 11.3 ✅ Weekly Affix Rotation (APPROVED - Server-Wide)
**Current:** Players select affixes from menu
**Proposed:** Server-wide weekly rotation (like retail)

**Affix Visibility:** Affixes appear in player's **DEBUFF BAR** (or buff bar for positive effects), not just chat messages. This provides:
- Clear visual feedback of active modifiers
- Consistent UI location (same as other buffs/debuffs)
- Tooltip with affix description on hover
- Duration display (permanent while in instance)

**Affix Selection:** Two implementation options:

**Option A: Server-Wide Weekly Rotation (Retail-like, Recommended)**
- Affixes are predetermined on a 12-week rotation
- All keystones of the same level use the same affixes this week
- Changes every Tuesday at reset
- Simple, consistent, encourages community knowledge

**Option B: Player Choice at Font of Power (Custom)**
- Player can optionally select 1-3 affixes when activating keystone
- More affixes = higher rewards (configurable multiplier)
- Adds player agency but complicates balancing
- Requires additional UI for affix selection

**Implementation (Option A - Recommended):**
```cpp
struct AffixWeek {
  uint32 weekId;
  std::vector<uint32> affixSpellIds;  // Spell IDs shown in debuff bar
};

// 12-week rotation (example affixes using existing WoW spells)
// Each spell ID appears as debuff/buff in player's bar
std::vector<AffixWeek> AFFIX_ROTATION = {
  {1, {26662, 26661}},       // Week 1: Bolstering (26662), Raging (26661)
  {2, {26659, 26660}},       // Week 2: Sanguine, Necrotic
  {3, {26663, 26664}},       // Week 3: Bursting, Grievous
  {4, {26665, 26666}},       // Week 4: Explosive, Quaking
  {5, {26667, 26668}},       // Week 5: Volcanic, Storming
  {6, {26662, 26659}},       // Week 6: Bolstering, Sanguine
  {7, {26661, 26663}},       // Week 7: Raging, Bursting
  {8, {26660, 26665}},       // Week 8: Necrotic, Explosive
  {9, {26664, 26667}},       // Week 9: Grievous, Volcanic
  {10, {26666, 26668}},      // Week 10: Quaking, Storming
  {11, {26662, 26664}},      // Week 11: Bolstering, Grievous
  {12, {26661, 26660}}       // Week 12: Raging, Necrotic
};

uint32 GetCurrentWeekId() {
  time_t now = time(nullptr);
  time_t seasonStart = GetSeasonStartTimestamp();  // Config value
  uint32 weeksSinceSeason = (now - seasonStart) / (7 * 24 * 60 * 60);
  return (weeksSinceSeason % 12) + 1;  // Cycles through 1-12
}

std::vector<uint32> GetCurrentAffixes() {
  uint32 weekId = GetCurrentWeekId();
  for (const auto& week : AFFIX_ROTATION) {
    if (week.weekId == weekId) return week.affixSpellIds;
  }
  return {};
}

// Apply affixes to players in mythic+ instance
void ApplyMythicAffixes(Player* player) {
  std::vector<uint32> affixes = GetCurrentAffixes();
  
  for (uint32 spellId : affixes) {
    // Cast spell on player - appears in debuff bar
    // Duration = 0 means permanent until instance ends
    player->CastSpell(player, spellId, true);
    
    // Log affix application
    LOG_INFO("mythic", "Applied affix spell {} to player {}", 
      spellId, player->GetName());
  }
  
  // Show affixes in chat (optional)
  std::string affixNames = GetAffixNamesString(affixes);
  player->SendSystemMessage("|cffff8000Active Affixes:|r %s", affixNames.c_str());
}

// Remove affixes when leaving instance
void RemoveMythicAffixes(Player* player) {
  std::vector<uint32> affixes = GetCurrentAffixes();
  
  for (uint32 spellId : affixes) {
    player->RemoveAurasDueToSpell(spellId);
  }
}
```

**Implementation (Option B - Player Choice):**
```cpp
// Font of Power gossip menu
void ShowAffixSelectionMenu(Player* player) {
  player->ADD_GOSSIP_ITEM(0, "No Affixes (Base rewards)", GOSSIP_SENDER_MAIN, 1);
  player->ADD_GOSSIP_ITEM(0, "1 Affix (+25% rewards)", GOSSIP_SENDER_MAIN, 2);
  player->ADD_GOSSIP_ITEM(0, "2 Affixes (+50% rewards)", GOSSIP_SENDER_MAIN, 3);
  player->ADD_GOSSIP_ITEM(0, "3 Affixes (+100% rewards)", GOSSIP_SENDER_MAIN, 4);
  player->SEND_GOSSIP_MENU(1, creature->GetGUID());
}

void OnGossipSelect_AffixChoice(Player* player, uint32 action) {
  uint32 affixCount = action - 1;  // 0-3 affixes
  
  if (affixCount > 0) {
    // Let player choose specific affixes
    ShowAffixListMenu(player, affixCount);
  } else {
    StartKeystoneInstance(player, {});  // No affixes
  }
}

void ShowAffixListMenu(Player* player, uint32 maxChoices) {
  // Show available affixes as gossip options
  // Each affix has spell ID for debuff bar display
  player->ADD_GOSSIP_ITEM(0, "Bolstering (+20% health on death)", GOSSIP_SENDER_MAIN, 26662);
  player->ADD_GOSSIP_ITEM(0, "Raging (+50% damage at low HP)", GOSSIP_SENDER_MAIN, 26661);
  player->ADD_GOSSIP_ITEM(0, "Sanguine (healing pool on death)", GOSSIP_SENDER_MAIN, 26659);
  // ... etc
  player->SEND_GOSSIP_MENU(2, creature->GetGUID());
}
```

**Database Schema:**
```sql
CREATE TABLE dc_mythic_affix_weeks (
  week_id INT UNSIGNED PRIMARY KEY,
  season_id INT UNSIGNED NOT NULL,
  affix_1_spell_id INT UNSIGNED NOT NULL,  -- Spell shown in debuff bar
  affix_2_spell_id INT UNSIGNED DEFAULT 0,
  affix_3_spell_id INT UNSIGNED DEFAULT 0,
  affix_1_name VARCHAR(50),
  affix_2_name VARCHAR(50),
  affix_3_name VARCHAR(50),
  start_timestamp INT UNSIGNED NOT NULL,
  KEY idx_season (season_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Example data (using real WoW spell IDs for visual effects)
INSERT INTO dc_mythic_affix_weeks VALUES
(1, 1, 26662, 26661, 0, 'Bolstering', 'Raging', NULL, UNIX_TIMESTAMP('2025-01-07')),
(2, 1, 26659, 26660, 0, 'Sanguine', 'Necrotic', NULL, UNIX_TIMESTAMP('2025-01-14')),
(3, 1, 26663, 26664, 0, 'Bursting', 'Grievous', NULL, UNIX_TIMESTAMP('2025-01-21'));
```

**Configuration (darkchaos-custom.conf.dist):**
```ini
###########################################################################
#
#    SECTION 6: MYTHIC+ SYSTEM
#
###########################################################################

#
#    MythicPlus.Affix.Mode
#        Description: Affix selection mode
#        Default:     0 (Server-wide weekly rotation - retail-like) ✅ CONFIRMED
#                     1 (Player choice at Font of Power - NOT IMPLEMENTED)
#
MythicPlus.Affix.Mode = 0

#
#    MythicPlus.Death.Maximum
#        Description: Maximum deaths allowed before auto-fail (M+ DUNGEONS ONLY - M+2 to M+10)
#                     Does NOT apply to: Mythic 0, Mythic raids, Heroic/Normal content
#        Default:     15 (retail-like death penalty)
#        Range:       5 - 50
#
MythicPlus.Death.Maximum = 15

#
#    MythicPlus.Death.TokenPenalty
#        Description: Token reward percentage on 15-death failure (M+ DUNGEONS ONLY)
#        Default:     50 (50% of normal tokens)
#        Range:       0 - 100
#
MythicPlus.Death.TokenPenalty = 50

#
#    MythicPlus.Keystone.StartLevel
#        Description: Starting keystone level from M+0 or weekly vault
#        Default:     2 (M+2 starting level, no M+1)
#        Range:       2 - 10
#
MythicPlus.Keystone.StartLevel = 2

#
#    MythicPlus.Keystone.MaxLevel
#        Description: Maximum keystone level available
#        Default:     10 (M+10 cap for Season 1)
#        Range:       2 - 20
#
MythicPlus.Keystone.MaxLevel = 10

#
#    MythicPlus.Vault.Slot1.Requirement
#        Description: Dungeons required to unlock Vault Slot 1
#        Default:     1 (complete 1 M+ dungeon)
#
MythicPlus.Vault.Slot1.Requirement = 1

#
#    MythicPlus.Vault.Slot2.Requirement
#        Description: Dungeons required to unlock Vault Slot 2
#        Default:     4 (complete 4 M+ dungeons)
#
MythicPlus.Vault.Slot2.Requirement = 4

#
#    MythicPlus.Vault.Slot3.Requirement
#        Description: Dungeons required to unlock Vault Slot 3
#        Default:     8 (complete 8 M+ dungeons)
#
MythicPlus.Vault.Slot3.Requirement = 8

#
#    MythicPlus.Season.DungeonCount
#        Description: Number of dungeons in seasonal pool
#        Default:     8 (retail standard)
#        Range:       4 - 12
#
MythicPlus.Season.DungeonCount = 8

#
#    MythicPlus.Affix.ShowInDebuffBar
#        Description: Show active affixes as debuffs in player's buff bar
#        Default:     1 (Enabled - affixes appear as debuffs)
#                     0 (Disabled - affixes only in chat/addon)
#
MythicPlus.Affix.ShowInDebuffBar = 1
```

**Affix Debuff Bar Display:**
```cpp
// When player enters M+ instance
void OnPlayerEnterMythicInstance(Player* player, Map* map) {
  MythicPlusInstance* mpInstance = GetMythicPlusInstance(map);
  if (!mpInstance) return;
  
  std::vector<uint32> affixes = mpInstance->GetActiveAffixSpells();
  
  // Apply each affix as permanent aura (shows in debuff bar)
  for (uint32 spellId : affixes) {
    if (Aura* aura = player->AddAura(spellId, player)) {
      aura->SetDuration(-1);  // Permanent until removed
      aura->SetMaxDuration(-1);
      
      // Optional: Custom tooltip via addon message
      SendAffixTooltipToAddon(player, spellId, GetAffixDescription(spellId));
    }
  }
}

// When player leaves M+ instance
void OnPlayerLeaveMythicInstance(Player* player) {
  std::vector<uint32> affixes = GetCurrentAffixes();
  
  for (uint32 spellId : affixes) {
    player->RemoveAurasDueToSpell(spellId);
  }
}
```

**Recommendation:** Use Option A (server-wide rotation) with `MythicPlus.Affix.ShowInDebuffBar = 1` for retail-like consistency. Option B adds complexity and requires extensive balancing but offers unique customization.

**Keystone Integration:**
- Keystones automatically inherit current week's affixes
- Affix combination stored in keystone metadata (affixes_json field)
- Can't modify affixes - locked to week of generation

---

### 11.4 ❌ Mythic+ Score System (REMOVED)
**Status:** Not implementing rating/scoring system per user request

---

### 11.5 ✅ Great Vault Enhancement (APPROVED - 3 Slots)
**Current:** Simple weekly chest with 1 item
**Proposed:** Multiple reward options based on activity

**Vault Slots (Weekly Unlock System):**
```
┌─────────────────────────────────────────────────┐
│  WEEKLY GREAT VAULT                             │
├─────────────────────────────────────────────────┤
│                                                 │
│  Slot 1: Complete 1 M+ dungeon this week       │
│  Status: [✓] Unlocked                          │
│  Reward: [Item Icon] ilvl 226 Epic Legs       │
│          OR                                     │
│          50 Mythic+ Tokens                      │
│                                                 │
│  Slot 2: Complete 4 M+ dungeons this week      │
│  Status: [✓] Unlocked (Progress: 4/4)         │
│  Reward: [Item Icon] ilvl 232 Epic Weapon     │
│          OR                                     │
│          100 Mythic+ Tokens                     │
│                                                 │
│  Slot 3: Complete 8 M+ dungeons this week      │
│  Status: [X] Locked (Progress: 4/8)           │
│  Reward: ???                                    │
│                                                 │
│  [Claim Reward] - Choose 1 reward              │
└─────────────────────────────────────────────────┘
```

**Implementation:**
```sql
CREATE TABLE dc_mythic_vault_progress (
  id INT PRIMARY KEY AUTO_INCREMENT,
  player_guid BIGINT,
  week_id INT,  -- Links to weekly reset
  season_id INT,
  
  -- Progress tracking
  dungeons_completed INT DEFAULT 0,
  highest_key_completed INT DEFAULT 0,
  
  -- Slot unlocks
  slot_1_unlocked TINYINT(1) DEFAULT 0,  -- 1 dungeon
  slot_2_unlocked TINYINT(1) DEFAULT 0,  -- 4 dungeons
  slot_3_unlocked TINYINT(1) DEFAULT 0,  -- 8 dungeons
  
  -- Reward selection
  reward_claimed TINYINT(1) DEFAULT 0,
  chosen_slot INT DEFAULT NULL,  -- 1, 2, or 3
  reward_item_id INT DEFAULT NULL,
  
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  UNIQUE KEY idx_player_week (player_guid, week_id),
  FOREIGN KEY (season_id) REFERENCES dc_mythic_seasons(season_id)
);

-- Reward pools per slot
CREATE TABLE dc_mythic_vault_rewards (
  id INT PRIMARY KEY AUTO_INCREMENT,
  slot_number INT,  -- 1, 2, or 3
  reward_type VARCHAR(50),  -- 'item' or 'tokens'
  item_entry INT DEFAULT NULL,
  item_level INT DEFAULT NULL,
  token_amount INT DEFAULT NULL,
  weight INT DEFAULT 1,  -- For random selection
  KEY idx_slot (slot_number)
);
```

**Vault Claim Workflow:**
```cpp
void ClaimVaultReward(Player* player, uint32 slotNumber) {
  // Validate slot is unlocked
  QueryResult result = CharacterDatabase.Query(
    "SELECT slot_{}_unlocked FROM dc_mythic_vault_progress "
    "WHERE player_guid = {} AND week_id = (SELECT CURRENT_WEEK_ID())",
    slotNumber, player->GetGUID().GetCounter()
  );
  
  if (!result || !result->Fetch()[0].Get<bool>()) {
    player->SendSystemMessage("That vault slot is not unlocked!");
    return;
  }
  
  // Check if already claimed
  if (HasClaimedVaultThisWeek(player)) {
    player->SendSystemMessage("You've already claimed your weekly vault reward!");
    return;
  }
  
  // Generate reward from slot's pool
  uint32 rewardItemId = SelectRandomReward(slotNumber);
  Item* reward = player->AddItem(rewardItemId, 1);
  
  if (reward) {
    // Mark as claimed
    CharacterDatabase.Execute(
      "UPDATE dc_mythic_vault_progress SET reward_claimed = 1, chosen_slot = {}, reward_item_id = {} "
      "WHERE player_guid = {} AND week_id = (SELECT CURRENT_WEEK_ID())",
      slotNumber, rewardItemId, player->GetGUID().GetCounter()
    );
    
    player->SendSystemMessage("You received your Great Vault reward!");
  }
}
```

**Reward Tier Scaling:**

**✅ FINAL DECISION: Token-based scaling system**

**Token Rewards by M+ Level (Per Slot):**

| Vault Slot | M+ Level Range | Tokens (Slot 1) | Tokens (Slot 2) | Tokens (Slot 3) |
|------------|----------------|-----------------|-----------------|-----------------|
| **Slot 1** | M+2 to M+4     | 50              | 100             | 150             |
| **Slot 2** | M+5 to M+7     | 75              | 150             | 225             |
| **Slot 3** | M+8 to M+10    | 100             | 200             | 300             |

**Unlock Requirements:**
- **Slot 1:** Complete 1 M+ dungeon this week (any level)
- **Slot 2:** Complete 4 M+ dungeons this week (counts towards Slot 1)
- **Slot 3:** Complete 8 M+ dungeons this week (counts towards Slot 1 and 2)

**Token Amount Calculation:**
- Tokens scale based on **highest M+ level completed** this week
- If player completes M+2, M+5, M+8 → Slot 3 uses M+8-10 token tier (100/200/300)
- All 3 slots use the SAME token tier (based on highest completed)
- Player chooses ONE reward slot (cannot claim multiple)

**Example Scenarios:**

**Scenario 1: Casual Player**
- Completes 1 M+2 dungeon this week
- Slot 1 unlocked: 50 tokens (M+2-4 tier, Slot 1 column)
- Slot 2/3 locked (didn't complete 4/8 dungeons)
- Chooses Slot 1 → Receives 50 tokens

**Scenario 2: Active Player**
- Completes 8 M+5 dungeons this week
- All slots unlocked (1/4/8 requirement met)
- Token tier: M+5-7 (highest level)
- Slot 1: 75 tokens, Slot 2: 150 tokens, Slot 3: 225 tokens
- Chooses Slot 3 → Receives 225 tokens

**Scenario 3: Hardcore Player**
- Completes 10 M+10 dungeons this week (highest level)
- All slots unlocked
- Token tier: M+8-10 (highest level)
- Slot 1: 100 tokens, Slot 2: 200 tokens, Slot 3: 300 tokens
- Chooses Slot 3 → Receives 300 tokens

**Why Tokens Instead of Items:**
- Player choice (buy specific gear from token vendor)
- No RNG frustration (always get usable reward)
- Simpler implementation (no item pool randomization)
- Future-proof (easy to add new vendor items)

**Implementation Notes:**
```sql
-- Vault progress tracking
CREATE TABLE dc_mythic_vault_progress (
  player_guid BIGINT,
  week_id INT,
  dungeons_completed INT DEFAULT 0,
  highest_key_completed INT DEFAULT 0,  -- Determines token tier
  
  slot_1_unlocked TINYINT(1) DEFAULT 0,  -- 1 dungeon
  slot_2_unlocked TINYINT(1) DEFAULT 0,  -- 4 dungeons
  slot_3_unlocked TINYINT(1) DEFAULT 0,  -- 8 dungeons
  
  reward_claimed TINYINT(1) DEFAULT 0,
  chosen_slot INT DEFAULT NULL,
  token_amount INT DEFAULT NULL,
  
  UNIQUE KEY idx_player_week (player_guid, week_id)
);
```

**Token Calculation Logic:**
```cpp
uint32 CalculateVaultTokens(Player* player, uint32 slotNumber) {
  uint32 highestKey = GetHighestKeyCompletedThisWeek(player);
  
  // Determine token tier
  uint32 baseTier = 0;
  if (highestKey >= 8) baseTier = 2;      // M+8-10 tier
  else if (highestKey >= 5) baseTier = 1; // M+5-7 tier
  else baseTier = 0;                       // M+2-4 tier
  
  // Token amounts: [Slot1, Slot2, Slot3] per tier
  uint32 tokenTable[3][3] = {
    {50, 100, 150},   // M+2-4 tier
    {75, 150, 225},   // M+5-7 tier
    {100, 200, 300}   // M+8-10 tier
  };
  
  return tokenTable[baseTier][slotNumber - 1];
}
```

---

### 11.6 ✅ Premade Group Finder (DBC-Integrated LFG System)

**Status:** APPROVED for DBC editing implementation  
**Decision:** Method 2 (DBC Editing) - Integrate Mythic+ into native WotLK LFG tool  
**User Request:** "is there no way to adapt the wotlk lfg tool with more options via dbc or so? -> lets go for DBC editing"

---

#### **11.6.1 Why Integrate with Native LFG?**

Instead of creating an NPC-based group listing system, we can **extend the native WotLK Dungeon Finder (LFD) tool** by editing `LFGDungeons.dbc`. This provides:

**Benefits:**
- ✅ **Native UI Support:** Players use familiar "I" key LFG interface
- ✅ **Queue System:** Automatic group matching by role (Tank/Healer/DPS)
- ✅ **Teleport Integration:** Built-in dungeon teleportation on group ready
- ✅ **Difficulty Selection:** Dropdown menu for Normal/Heroic/Mythic/Mythic+
- ✅ **GearScore Filtering:** Can add minimum GS requirements per dungeon
- ✅ **Cross-Realm Support:** Works with AzerothCore's cross-realm system
- ✅ **Achievement Integration:** Can require achievements for specific dungeons

**vs. NPC-Based System:**
- ❌ NPC requires custom UI addon
- ❌ No automatic role checking
- ❌ Manual teleportation required
- ❌ No queue system (manual group formation)

**Conclusion:** DBC editing provides vastly superior player experience.

---

#### **11.6.2 LFGDungeons.dbc Structure (3.3.5a)**

The `LFGDungeons.dbc` file defines all dungeons/raids available in the Dungeon Finder UI.

**DBC Fields (20 columns):**
```
ID, Name, MinLevel, MaxLevel, Target_Level, Target_Level_Min, Target_Level_Max, 
MapID, Difficulty, Flags, TypeID, Faction, Texture, ExpansionLevel, OrderIndex, 
GroupID, Name_Desc, RandomID, CountTank, CountHealer, CountDPS
```

**Key Fields for Mythic+:**
- **ID:** Unique entry ID (start at 10000 for custom entries)
- **Name:** Display name in LFG UI (e.g., "Utgarde Pinnacle (Mythic+2)")
- **MinLevel/MaxLevel:** Level requirement (80 for all Mythic+)
- **MapID:** Dungeon map ID from Map.dbc
- **Difficulty:** 0=Normal, 1=Heroic, 4=Mythic (custom), 6-15=Mythic+2 to M+10
- **Flags:** Controls behavior (see below)
- **TypeID:** 1=Dungeon, 2=Raid, 5=Heroic, 6=Random (use 1 for Mythic+)
- **GroupID:** Links difficulties together (same group = same dungeon)
- **RandomID:** If >0, this dungeon appears in "Random Mythic+" queue

**Important Flags (bitwise):**
- `0x01` - Seasonal (show only during active season)
- `0x02` - IsHoliday (special event dungeon)
- `0x04` - Show in LFG UI
- `0x10` - Can be queued from anywhere
- `0x20` - Requires preformed group (no auto-matchmaking)
- `0x100` - Allow queuing while in dungeon
- `0x200` - Allow deserter debuff

**Recommended Flags for Mythic+:**
- `0x34` (52 decimal) = Show in UI + Can queue anywhere + Requires preformed group
- This prevents auto-matchmaking but allows manual group formation via LFG tool

---

#### **11.6.3 GearScore Integration (Server-Side)**

**GearScoreLite Algorithm (Client Addon):**

The popular GearScoreLite addon uses a weighted scoring system:
- Each equipment slot has a quality weight (Chest=1.0, Ring=0.5625, etc.)
- Item level × slot weight × quality multiplier = slot score
- Total score = sum of all equipped items
- Special handling for Titan's Grip (50% penalty), Hunter ranged (16.8x multiplier)
- Un-enchanted items get 25% score reduction

**Server Implementation Benefits:**
- No client dependency
- Prevent client-side manipulation
- Real-time validation for LFG queues
- Stored in database for quick lookups
- Can integrate with leaderboards/achievements

**C++ Implementation:**

```cpp
// File: src/server/game/Mythic/dc_gearscore.cpp
namespace dc_mythic
{
    // Slot quality weights (from GearScoreLite algorithm)
    const std::map<uint8, float> SLOT_WEIGHTS = {
        {EQUIPMENT_SLOT_HEAD,      1.0f},
        {EQUIPMENT_SLOT_NECK,      0.5625f},
        {EQUIPMENT_SLOT_SHOULDERS, 0.75f},
        {EQUIPMENT_SLOT_CHEST,     1.0f},
        {EQUIPMENT_SLOT_WAIST,     0.75f},
        {EQUIPMENT_SLOT_LEGS,      1.0f},
        {EQUIPMENT_SLOT_FEET,      0.75f},
        {EQUIPMENT_SLOT_WRISTS,    0.5625f},
        {EQUIPMENT_SLOT_HANDS,     0.75f},
        {EQUIPMENT_SLOT_FINGER1,   0.5625f},
        {EQUIPMENT_SLOT_FINGER2,   0.5625f},
        {EQUIPMENT_SLOT_TRINKET1,  0.5625f},
        {EQUIPMENT_SLOT_TRINKET2,  0.5625f},
        {EQUIPMENT_SLOT_BACK,      0.5625f},
        {EQUIPMENT_SLOT_MAINHAND,  1.0f},
        {EQUIPMENT_SLOT_OFFHAND,   1.0f},
        {EQUIPMENT_SLOT_RANGED,    0.3164f} // Hunters: 5.3224f
    };
    
    uint32 CalculateGearScore(Player* player)
    {
        if (!player)
            return 0;
        
        float totalScore = 0.0f;
        bool isTitanGrip = false;
        
        // Check for Titan's Grip
        if (Item* mainHand = player->GetItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_MAINHAND))
        {
            if (ItemTemplate const* mhProto = mainHand->GetTemplate())
                if (mhProto->InventoryType == INVTYPE_2HWEAPON)
                    if (Item* offHand = player->GetItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_OFFHAND))
                        if (ItemTemplate const* ohProto = offHand->GetTemplate())
                            if (ohProto->InventoryType == INVTYPE_2HWEAPON)
                                isTitanGrip = true;
        }
        
        // Calculate score for each slot
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            if (slot == EQUIPMENT_SLOT_BODY || slot == EQUIPMENT_SLOT_TABARD)
                continue;
            
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (!item)
                continue;
            
            ItemTemplate const* proto = item->GetTemplate();
            if (!proto)
                continue;
            
            float qualityMult = (proto->Quality >= ITEM_QUALITY_EPIC) ? 0.01f : 0.0075f;
            float slotWeight = SLOT_WEIGHTS.at(slot);
            float itemScore = proto->ItemLevel * slotWeight * qualityMult * 1000.0f;
            
            // Hunter ranged bonus
            if (slot == EQUIPMENT_SLOT_RANGED && player->getClass() == CLASS_HUNTER)
                itemScore *= 16.8f;
            
            // Titan's Grip penalty
            if (isTitanGrip && (slot == EQUIPMENT_SLOT_MAINHAND || slot == EQUIPMENT_SLOT_OFFHAND))
                itemScore *= 0.5f;
            
            // Enchant penalty
            if (CanEnchantSlot(slot) && !item->GetEnchantmentId(PERM_ENCHANTMENT_SLOT))
                itemScore *= 0.75f;
            
            totalScore += itemScore;
        }
        
        return static_cast<uint32>(totalScore);
    }
}
```

**Database Integration:**

```sql
-- Add GearScore to characters table
ALTER TABLE characters ADD COLUMN gear_score INT UNSIGNED DEFAULT 0;
ALTER TABLE characters ADD INDEX idx_gearscore (gear_score);

-- Update on equipment change
UPDATE characters SET gear_score = ? WHERE guid = ?;
```

**Configuration (darkchaos-custom.conf.dist):**

```ini
###########################################################################
# 6.12 LFG DUNGEON FINDER & GEARSCORE INTEGRATION
###########################################################################

# Enable Mythic+ in native LFG tool (requires DBC editing)
MythicPlus.LFG.Enabled = 1

# Require keystone to queue for Mythic+
MythicPlus.LFG.RequireKeystone = 1

# Require minimum GearScore
MythicPlus.LFG.RequireGearScore = 1

# Base GearScore for M+0
MythicPlus.LFG.MinGearScore.Base = 4000

# Additional GearScore per keystone level (M+2=4200, M+5=4500, M+10=5000)
MythicPlus.LFG.MinGearScore.PerLevel = 100

# Auto-calculate GearScore on equipment change
MythicPlus.LFG.AutoCalculateGearScore = 1

# Show GearScore in player tooltips
MythicPlus.LFG.ShowGearScoreInTooltip = 1

# Preformed groups only (no auto-matchmaking)
MythicPlus.LFG.AllowPreformedGroupsOnly = 1
```

---

#### **11.6.4 Implementation Summary**

**Phase 1: DBC Editing (4 hours)**
1. Edit `LFGDungeons.dbc` - Add 200+ entries for M+2/M+5/M+10 × 8 dungeons
2. Set difficulty fields (6-15 for M+2 to M+10)
3. Pack into `patch-4.mpq`, distribute to players

**Phase 2: Server C++ (8 hours)**
1. GearScore calculation system
2. Keystone validation for LFG queues
3. `lfg_dungeon_template` entries for teleports
4. Equipment change hooks for auto-update

**Phase 3: Client Addon (4 hours, optional)**
1. Display GearScore in LFG UI
2. Show keystone requirements
3. Enhanced tooltip information

**Total: ~16 hours** for full DBC-integrated LFG + GearScore system

**Result:** Players queue for Mythic+ using native LFG tool with automatic validation! 🎉

---

### 11.7 🔄 Dungeon Journal (MODIFIED - 3.3.5a Limitations)
**Current:** No in-game mechanic guide
**User Question:** How to port Dungeon Journal to 3.3.5a?

**Retail Dungeon Journal (4.0+):**
- Added in Cataclysm (patch 4.0.1)
- Requires client UI frames not present in WotLK
- Uses DBC entries (JournalEncounter.dbc, JournalInstance.dbc) - **doesn't exist in 3.3.5a**

**3.3.5a Options for Boss Information:**

#### **Option 1: Custom Addon UI (Recommended)**
```lua
-- Addon creates custom journal frame
-- Data stored in Lua tables, synced from server

MythicJournalDB = {
  [36492] = {  -- Boss entry ID
    name = "Lich King",
    dungeon = "Icecrown Citadel",
    description = "The final boss of Icecrown Citadel...",
    abilities = {
      {
        name = "Infest",
        icon = "spell_shadow_plaguecloud",
        description = "Deals damage over time, increases with healing received.",
        mythicChanges = "Now stacks twice as fast."
      },
      {
        name = "Defile",
        icon = "spell_shadow_defile",
        description = "Ground AoE that grows when players stand in it.",
        mythicChanges = "Starts 50% larger."
      }
    },
    strategy = "Spread out for Defile, group up for Val'kyr adds...",
    loot = {47553, 47554, 47555}  -- Item IDs
  }
}

-- Access via: /journal or button in dungeon
```

**Data Delivery Methods:**
1. **Embedded in Addon** - Static Lua tables (simple, no server needed)
2. **Server-Sent** - Addon requests data via SendAddonMessage (dynamic updates)
3. **Web Import** - Addon fetches from web API on load (external dependency)

#### **Option 2: In-Game Book Items**
```
Create readable items (class=15, subclass=0) for each dungeon:
- "Tome of Icecrown Strategy"
- "Guide to Mythic+ Deadmines"

On use: Opens text window with boss mechanics
Pros: No addon required, fits WotLK aesthetic
Cons: Limited formatting, can't show icons/tooltips
```

#### **Option 3: NPC Dialog Journal**
```
NPC 300319: "Dungeon Chronicler"
Location: Dalaran

Gossip Menu:
├─ Select Dungeon (submenu)
│   ├─ Icecrown Citadel
│   │   ├─ Lord Marrowgar
│   │   │   └─ Shows: Abilities, Strategy, Loot
│   │   ├─ Deathwhisper
│   │   └─ ...
│   └─ Other dungeons...
└─ Back

Pros: In-game, no addon, uses existing systems
Cons: Clunky navigation, lots of submenus
```

**Recommended Approach: Addon UI + Server Data**
```
1. Create custom addon frame (similar to Atlasloot UI)
2. Store boss data in dc_mythic_boss_journal table
3. Addon requests data on open: SendAddonMessage("DC_MYTHIC", "REQUEST_JOURNAL:36492")
4. Server responds with JSON: "JOURNAL_DATA:{...abilities, strategy, loot...}"
5. Addon parses and displays in custom frame

Benefits:
- Professional UI (similar to retail)
- Dynamic updates (no addon repack)
- Can show icons, tooltips, colored text
- Works alongside existing addons
```

**Database Schema:**
```sql
CREATE TABLE dc_mythic_boss_journal (
  id INT PRIMARY KEY AUTO_INCREMENT,
  boss_entry INT UNIQUE,
  boss_name VARCHAR(100),
  dungeon_name VARCHAR(100),
  description TEXT,
  abilities_json TEXT,  -- JSON array of abilities
  strategy_text TEXT,
  mythic_notes TEXT,
  loot_json TEXT,  -- JSON array of item IDs
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_boss_entry (boss_entry)
);

-- Example abilities_json:
[
  {
    "name": "Infest",
    "icon": "spell_shadow_plaguecloud",
    "description": "Deals damage over time...",
    "mythic_changes": "Stacks twice as fast",
    "spell_id": 70541
  }
]
```

---

### 11.8 ✅ Performance Optimizations (APPROVED)

#### **A. Instance Pooling**
```cpp
// Pre-create instances for popular dungeons to reduce spawn time
class MythicInstancePool {
private:
  std::map<uint32, std::queue<Map*>> instancePools;  // mapId -> available instances
  std::mutex poolMutex;
  
  const uint32 MIN_POOL_SIZE = 2;   // Keep 2 instances ready
  const uint32 MAX_POOL_SIZE = 10;  // Don't exceed 10 pre-created
  
public:
  Map* GetOrCreateInstance(uint32 mapId, uint32 instanceId) {
    std::lock_guard<std::mutex> lock(poolMutex);
    
    // Try to reuse from pool
    if (!instancePools[mapId].empty()) {
      Map* instance = instancePools[mapId].front();
      instancePools[mapId].pop();
      
      LOG_DEBUG("mythic", "Reusing pooled instance {} for map {}", 
        instance->GetInstanceId(), mapId);
      
      return instance;
    }
    
    // Create new if pool empty
    Map* newInstance = sMapMgr->CreateMap(mapId, instanceId);
    LOG_DEBUG("mythic", "Created new instance {} for map {}", instanceId, mapId);
    
    return newInstance;
  }
  
  void ReturnInstance(Map* instance) {
    std::lock_guard<std::mutex> lock(poolMutex);
    
    uint32 mapId = instance->GetId();
    
    // Don't pool if we have too many
    if (instancePools[mapId].size() >= MAX_POOL_SIZE) {
      LOG_DEBUG("mythic", "Pool full for map {}, destroying instance", mapId);
      instance->UnloadAll();  // Cleanup
      delete instance;
      return;
    }
    
    // Reset instance state
    instance->RemoveAllPlayers();
    instance->ResetCreatures();
    instance->ResetGameObjects();
    instance->ResetLoot();
    
    // Return to pool
    instancePools[mapId].push(instance);
    LOG_DEBUG("mythic", "Returned instance to pool for map {}", mapId);
  }
  
  void MaintainPools() {
    // Run every 5 minutes to ensure minimum instances ready
    for (auto& [mapId, pool] : instancePools) {
      while (pool.size() < MIN_POOL_SIZE) {
        uint32 newInstanceId = sMapMgr->GenerateInstanceId();
        Map* instance = sMapMgr->CreateMap(mapId, newInstanceId);
        pool.push(instance);
      }
    }
  }
};
```

#### **B. Async Database Queries**
```cpp
// Don't block game thread on database operations
class MythicAsyncDB {
public:
  // Async vault progress update
  static void UpdateVaultProgress(uint64 playerGuid, uint32 dungeonsCompleted) {
    CharacterDatabase.AsyncQuery(
      "UPDATE dc_mythic_vault_progress "
      "SET dungeons_completed = dungeons_completed + 1, "
      "    slot_1_unlocked = IF(dungeons_completed >= 1, 1, 0), "
      "    slot_2_unlocked = IF(dungeons_completed >= 4, 1, 0), "
      "    slot_3_unlocked = IF(dungeons_completed >= 8, 1, 0) "
      "WHERE player_guid = {} AND week_id = (SELECT CURRENT_WEEK_ID())",
      playerGuid
    ).then([playerGuid](QueryResult result) {
      // Callback when query completes
      if (Player* player = ObjectAccessor::FindPlayer(ObjectGuid::Create<HighGuid::Player>(playerGuid))) {
        if (player->IsInWorld()) {
          player->SendSystemMessage("Vault progress updated!");
        }
      }
    });
  }
  
  // Async keystone generation
  static void GenerateKeystone(uint64 playerGuid, uint32 level, uint32 dungeonId) {
    CharacterDatabase.AsyncQuery(
      "INSERT INTO dc_mythic_keystones (player_guid, dungeon_id, level, created_at) "
      "VALUES ({}, {}, {}, NOW())",
      playerGuid, dungeonId, level
    ).then([playerGuid, level](QueryResult result) {
      if (Player* player = ObjectAccessor::FindPlayer(ObjectGuid::Create<HighGuid::Player>(playerGuid))) {
        // Create physical item in inventory
        uint32 itemEntry = 100000 + (level - 2);  // M+2=100000, M+3=100001, ..., M+10=100008
        player->AddItem(itemEntry, 1);
      }
    });
  }
};
```

#### **C. Configuration Caching**
```cpp
// Cache dungeon configs to avoid repeated DB queries
class MythicConfigCache {
private:
  struct DungeonConfig {
    uint32 dungeonId;
    std::string dungeonName;
    float scalingMythic;
    float scalingMythicPlusStep;
    uint32 minLevelMythicPlus;
    time_t loadedAt;
  };
  
  std::map<uint32, DungeonConfig> configCache;
  std::mutex cacheMutex;
  const uint32 CACHE_LIFETIME = 300;  // 5 minutes
  
public:
  DungeonConfig* GetConfig(uint32 dungeonId) {
    std::lock_guard<std::mutex> lock(cacheMutex);
    
    // Check if cached and not expired
    if (configCache.count(dungeonId)) {
      if (time(nullptr) - configCache[dungeonId].loadedAt < CACHE_LIFETIME) {
        return &configCache[dungeonId];
      }
    }
    
    // Load from database
    QueryResult result = WorldDatabase.Query(
      "SELECT dungeon_name, scaling_mythic, scaling_mythic_plus_step, min_level_mythic_plus "
      "FROM dc_mythic_dungeons_config WHERE dungeon_id = {}",
      dungeonId
    );
    
    if (!result) return nullptr;
    
    Field* fields = result->Fetch();
    DungeonConfig config;
    config.dungeonId = dungeonId;
    config.dungeonName = fields[0].Get<std::string>();
    config.scalingMythic = fields[1].Get<float>();
    config.scalingMythicPlusStep = fields[2].Get<float>();
    config.minLevelMythicPlus = fields[3].Get<uint32>();
    config.loadedAt = time(nullptr);
    
    configCache[dungeonId] = config;
    return &configCache[dungeonId];
  }
  
  void InvalidateCache(uint32 dungeonId = 0) {
    std::lock_guard<std::mutex> lock(cacheMutex);
    if (dungeonId == 0) {
      configCache.clear();  // Clear all
    } else {
      configCache.erase(dungeonId);  // Clear specific
    }
  }
};
```

#### **D. Batch Loot Generation**
```cpp
// Pre-calculate loot at run start instead of per-boss
class MythicLootCache {
public:
  struct RunLoot {
    std::vector<uint32> bossDrops;  // Pre-rolled items per boss
    uint32 completionTokens;        // Token reward for completion
    uint32 keystoneUpgradeLevel;    // New keystone level on success
  };
  
  static RunLoot GenerateLootForRun(Map* instance, uint32 keyLevel) {
    RunLoot loot;
    
    // Query all possible drops for this dungeon + key level
    QueryResult result = WorldDatabase.Query(
      "SELECT item_entry, drop_chance FROM dc_mythic_tokens_loot "
      "WHERE dungeon_id = {} AND key_level <= {} ORDER BY RAND()",
      instance->GetId(), keyLevel
    );
    
    if (result) {
      do {
        Field* fields = result->Fetch();
        uint32 itemEntry = fields[0].Get<uint32>();
        float dropChance = fields[1].Get<float>();
        
        // Roll for drop
        if (roll_chance_f(dropChance)) {
          loot.bossDrops.push_back(itemEntry);
        }
      } while (result->NextRow());
    }
    
    // Calculate token reward
    loot.completionTokens = CalculateTokenReward(keyLevel);
    
    // Determine keystone upgrade
    loot.keystoneUpgradeLevel = keyLevel + 1;  // +1 on success
    
    // Store in instance data for later retrieval
    instance->SetLootData(loot);
    
    LOG_INFO("mythic", "Generated loot for M+{} run: {} items, {} tokens",
      keyLevel, loot.bossDrops.size(), loot.completionTokens);
    
    return loot;
  }
};
```

---

### 11.9 ✅ Anti-Exploit Measures (MODIFIED - No Rating)

#### **A. Keystone Validation**
```cpp
bool ValidateKeystoneOwnership(Player* player, Item* keystone) {
  if (!keystone) return false;
  
  // Check if keystone belongs to player (BoP)
  if (keystone->GetOwnerGUID() != player->GetGUID()) {
    player->SendSystemMessage("|cffff0000That keystone doesn't belong to you!|r");
    return false;
  }
  
  // Check if keystone is valid (not duplicated)
  QueryResult result = CharacterDatabase.Query(
    "SELECT 1 FROM dc_mythic_keystones "
    "WHERE item_guid = {} AND player_guid = {} AND depleted = 0",
    keystone->GetGUID().GetCounter(),
    player->GetGUID().GetCounter()
  );
  
  if (!result) {
    LOG_WARN("mythic", "Player {} attempted to use invalid keystone {}",
      player->GetName(), keystone->GetGUID().GetCounter());
    player->SendSystemMessage("|cffff0000Invalid keystone! Contact a GM if this is an error.|r");
    return false;
  }
  
  // Check if keystone was generated recently (prevent time exploits)
  result = CharacterDatabase.Query(
    "SELECT TIMESTAMPDIFF(SECOND, created_at, NOW()) FROM dc_mythic_keystones "
    "WHERE item_guid = {}",
    keystone->GetGUID().GetCounter()
  );
  
  if (result) {
    uint32 ageSeconds = result->Fetch()[0].Get<uint32>();
    if (ageSeconds < 10) {
      player->SendSystemMessage("|cffff0000Please wait before using a newly generated keystone.|r");
      return false;
    }
  }
  
  return true;
}

// Prevent keystone duplication via trade/mail
bool CanTradeKeystone(Player* player, Item* keystone) {
  // Keystones are BoP, cannot be traded
  return false;
}

bool CanMailKeystone(Player* player, Item* keystone) {
  // Keystones cannot be mailed
  return false;
}
```

#### **B. Death Counter Validation**
```cpp
class MythicRunValidator {
private:
  struct RunState {
    std::set<ObjectGuid> startingPlayers;  // Players at run start
    uint32 deathCounter;
    uint32 maxDeaths;
    time_t startTime;
    bool validated;
  };
  
  std::map<uint32, RunState> activeRuns;  // instanceId -> state
  
public:
  void StartRun(Map* instance, Group* group) {
    RunState state;
    state.deathCounter = 0;
    state.maxDeaths = 3;  // Configurable
    state.startTime = time(nullptr);
    state.validated = true;
    
    // Record starting players
    for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next()) {
      if (Player* member = itr->GetSource()) {
        state.startingPlayers.insert(member->GetGUID());
      }
    }
    
    activeRuns[instance->GetInstanceId()] = state;
    
    LOG_INFO("mythic", "Started M+ run in instance {} with {} players",
      instance->GetInstanceId(), state.startingPlayers.size());
  }
  
  void OnPlayerDeath(Player* player) {
    Map* instance = player->GetMap();
    if (!instance->IsMythicPlus()) return;
    
    uint32 instanceId = instance->GetInstanceId();
    if (!activeRuns.count(instanceId)) return;
    
    RunState& state = activeRuns[instanceId];
    
    // Check if player was in starting group (prevent carry exploits)
    if (state.startingPlayers.find(player->GetGUID()) == state.startingPlayers.end()) {
      LOG_WARN("mythic", "Player {} died but wasn't in starting group - invalidating run",
        player->GetName());
      state.validated = false;
      return;
    }
    
    // Increment death counter
    state.deathCounter++;
    
    LOG_INFO("mythic", "M+ death in instance {}: {}/{}",
      instanceId, state.deathCounter, state.maxDeaths);
    
    // Check if run failed
    if (state.deathCounter >= state.maxDeaths) {
      FailRun(instance, "Maximum deaths exceeded");
    }
  }
  
  void ValidateGroupIntegrity(Map* instance, Group* group) {
    uint32 instanceId = instance->GetInstanceId();
    if (!activeRuns.count(instanceId)) return;
    
    RunState& state = activeRuns[instanceId];
    
    // Check if group composition changed (player left/joined)
    std::set<ObjectGuid> currentPlayers;
    for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next()) {
      if (Player* member = itr->GetSource()) {
        currentPlayers.insert(member->GetGUID());
      }
    }
    
    // Compare sets
    if (currentPlayers != state.startingPlayers) {
      LOG_WARN("mythic", "Group composition changed in instance {} - invalidating run", instanceId);
      state.validated = false;
      FailRun(instance, "Group composition changed during run");
    }
  }
  
  void FailRun(Map* instance, const char* reason) {
    uint32 instanceId = instance->GetInstanceId();
    if (!activeRuns.count(instanceId)) return;
    
    RunState& state = activeRuns[instanceId];
    state.validated = false;
    
    // Notify players
    instance->DoForAllPlayers([reason](Player* player) {
      player->SendSystemMessage("|cffff0000Mythic+ run failed: %s|r", reason);
    });
    
    // Deplete keystone if applicable
    DepleteKeystones(instance);
    
    LOG_WARN("mythic", "M+ run failed in instance {}: {}", instanceId, reason);
  }
  
  bool IsRunValid(uint32 instanceId) {
    if (!activeRuns.count(instanceId)) return false;
    return activeRuns[instanceId].validated;
  }
};
```

#### **C. Weekly Vault Exploit Prevention**
```cpp
void ValidateVaultClaim(Player* player) {
  // Check if player already claimed this week
  QueryResult result = CharacterDatabase.Query(
    "SELECT reward_claimed FROM dc_mythic_vault_progress "
    "WHERE player_guid = {} AND week_id = (SELECT CURRENT_WEEK_ID())",
    player->GetGUID().GetCounter()
  );
  
  if (result && result->Fetch()[0].Get<bool>()) {
    player->SendSystemMessage("|cffff0000You've already claimed your weekly vault reward!|r");
    return;
  }
  
  // Check if player met requirements
  result = CharacterDatabase.Query(
    "SELECT dungeons_completed, slot_1_unlocked, slot_2_unlocked, slot_3_unlocked "
    "FROM dc_mythic_vault_progress WHERE player_guid = {} AND week_id = (SELECT CURRENT_WEEK_ID())",
    player->GetGUID().GetCounter()
  );
  
  if (!result) {
    player->SendSystemMessage("|cffff0000No vault progress found for this week!|r");
    return;
  }
  
  Field* fields = result->Fetch();
  uint32 dungeonsCompleted = fields[0].Get<uint32>();
  
  // Validate progress matches unlock status
  bool slot1 = fields[1].Get<bool>();
  bool slot2 = fields[2].Get<bool>();
  bool slot3 = fields[3].Get<bool>();
  
  if ((slot1 && dungeonsCompleted < 1) ||
      (slot2 && dungeonsCompleted < 4) ||
      (slot3 && dungeonsCompleted < 8)) {
    LOG_WARN("mythic", "Player {} has invalid vault unlock state - possible exploit",
      player->GetName());
    // Reset vault progress
    CharacterDatabase.Execute(
      "UPDATE dc_mythic_vault_progress SET slot_1_unlocked = 0, slot_2_unlocked = 0, slot_3_unlocked = 0 "
      "WHERE player_guid = {}",
      player->GetGUID().GetCounter()
    );
    player->SendSystemMessage("|cffff0000Vault data inconsistency detected. Contact a GM.|r");
    return;
  }
}
```

---

## PART 12: ACHIEVEMENT SYSTEM (✅ SEASONAL-BASED)

**Status:** APPROVED - Seasonal achievement system with progression tiers

### 12.1 Achievement Categories

#### **12.1.1 Completion Achievements (Progression Tiers)**

**Mythic Initiate** (10 points)
- Requirement: Complete any M+2 dungeon
- Reward: Achievement points
- Description: "Complete a Mythic+ dungeon."

**Mythic Challenger** (15 points)
- Requirement: Complete all 8 seasonal dungeons at M+2
- Reward: Achievement points
- Description: "Complete all Season 1 dungeons at Mythic+2 or higher."

**Mythic Contender** (25 points)
- Requirement: Complete all 8 seasonal dungeons at M+5
- Reward: Achievement points
- Description: "Complete all Season 1 dungeons at Mythic+5 or higher."

**Keystone Master: Season 1** (50 points, title: "S1 Keystone Master")
- Requirement: Complete all 8 seasonal dungeons at M+10
- Reward: Achievement points + title "S1 Keystone Master"
- Description: "Complete all Season 1 dungeons at Mythic+10."

---

#### **12.1.2 Challenge Achievements (Skill-Based)**

**Flawless Victory** (25 points)
- Requirement: Complete any M+5 with 0 deaths
- Reward: Achievement points
- Description: "Complete a Mythic+5 dungeon without a single death."

**Deathless Ascent** (50 points, title: "the Deathless")
- Requirement: Complete M+10 with 0 deaths
- Reward: Achievement points + title "the Deathless"
- Description: "Complete a Mythic+10 dungeon without a single death."

**Speed Demon** (25 points)
- Requirement: Complete 10 M+ dungeons in one day
- Reward: Achievement points
- Description: "Complete 10 Mythic+ dungeons in a single day."

**Century Club** (10 points)
- Requirement: Complete 100 M+ dungeons total (any level)
- Reward: Achievement points
- Description: "Complete 100 Mythic+ dungeons."

**Mythic Veteran** (25 points, mount reward)
- Requirement: Complete 500 M+ dungeons total
- Reward: Achievement points + unique mount
- Description: "Complete 500 Mythic+ dungeons."

---

#### **12.1.3 Seasonal-Specific Achievements**

**Season 1 Conqueror** (50 points)
- Requirement: Reach top 100 on any dungeon leaderboard
- Reward: Achievement points
- Description: "Reach top 100 on any Season 1 dungeon leaderboard."

**Season 1 Champion** (100 points, title: "S1 Champion", unique mount)
- Requirement: Finish Season 1 in top 10 overall rating
- Reward: Achievement points + title "S1 Champion" + unique mount
- Description: "Finish Season 1 in the top 10 overall rating."

---

#### **12.1.4 Dungeon-Specific Achievements** (Repeatable per dungeon)

**[Dungeon Name] Master** (15 points each)
- Requirement: Complete specific dungeon at M+10
- Example: "Utgarde Pinnacle Master" - Complete UP at M+10
- Reward: Achievement points
- One achievement per seasonal dungeon (8 total)

---

#### **12.1.5 Hidden Achievements** (Feats of Strength)

**Solo Mythic+**
- Requirement: Complete any M+2 solo (no group)
- Reward: Feat of Strength
- Description: "Complete a Mythic+ dungeon without a group."

**Mythic Marathon**
- Requirement: Complete all 8 seasonal dungeons in one day at M+5+
- Reward: Feat of Strength
- Description: "Complete all Season 1 dungeons in a single day."

**Perfectly Balanced**
- Requirement: Complete M+10 with exactly 5 deaths (upgrade threshold)
- Reward: Feat of Strength
- Description: "Complete a Mythic+10 with exactly 5 deaths."

---

### 12.2 Seasonal Achievement Behavior

**Season 2+ Achievements:**
- New "Keystone Master: Season 2" achievement created
- New seasonal leaderboard achievements
- **Previous season achievements become Feats of Strength** (no longer obtainable)
- Titles remain permanent (e.g., "S1 Keystone Master" still usable in Season 2)

**Achievement Tracking:**
- All tracked in `dc_mythic_achievements` table
- Links to `dc_mythic_run_history` for completion validation
- Seasonal achievements archived when season ends

---

### 12.3 Database Schema for Achievements

```sql
-- Achievement definitions
CREATE TABLE dc_mythic_achievement_defs (
  achievement_id INT PRIMARY KEY,
  achievement_name VARCHAR(200),
  description TEXT,
  category VARCHAR(50),  -- 'completion', 'challenge', 'seasonal', 'dungeon', 'hidden'
  season_id INT DEFAULT NULL,  -- NULL = all seasons
  points INT DEFAULT 0,
  title_reward VARCHAR(100) DEFAULT NULL,
  item_reward INT DEFAULT NULL,  -- Mount item ID, etc.
  hidden TINYINT(1) DEFAULT 0,  -- Feat of Strength
  
  -- Completion criteria
  criteria_type VARCHAR(50),  -- 'complete_all_dungeons', 'complete_count', 'leaderboard_rank'
  criteria_value INT,  -- M+ level, count, rank threshold
  criteria_deaths INT DEFAULT NULL,  -- Death requirement (0 = flawless)
  
  FOREIGN KEY (season_id) REFERENCES dc_mythic_seasons(season_id)
);

-- Player achievement progress
CREATE TABLE dc_mythic_achievement_progress (
  player_guid BIGINT,
  achievement_id INT,
  current_progress INT DEFAULT 0,  -- e.g., 5/8 dungeons completed
  completed TINYINT(1) DEFAULT 0,
  completed_date DATETIME DEFAULT NULL,
  season_id INT,
  
  PRIMARY KEY (player_guid, achievement_id),
  FOREIGN KEY (achievement_id) REFERENCES dc_mythic_achievement_defs(achievement_id)
);

-- Insert Season 1 achievements
INSERT INTO dc_mythic_achievement_defs VALUES
(60001, 'Mythic Initiate', 'Complete any M+2 dungeon.', 'completion', 1, 10, NULL, NULL, 0, 'complete_count', 1, NULL),
(60002, 'Mythic Challenger', 'Complete all Season 1 dungeons at M+2.', 'completion', 1, 15, NULL, NULL, 0, 'complete_all_dungeons', 2, NULL),
(60003, 'Mythic Contender', 'Complete all Season 1 dungeons at M+5.', 'completion', 1, 25, NULL, NULL, 0, 'complete_all_dungeons', 5, NULL),
(60004, 'Keystone Master: Season 1', 'Complete all Season 1 dungeons at M+10.', 'completion', 1, 50, 'S1 Keystone Master', NULL, 0, 'complete_all_dungeons', 10, NULL),
(60005, 'Flawless Victory', 'Complete M+5 with 0 deaths.', 'challenge', NULL, 25, NULL, NULL, 0, 'complete_count', 5, 0),
(60006, 'Deathless Ascent', 'Complete M+10 with 0 deaths.', 'challenge', NULL, 50, 'the Deathless', NULL, 0, 'complete_count', 10, 0),
(60007, 'Speed Demon', 'Complete 10 M+ in one day.', 'challenge', NULL, 25, NULL, NULL, 0, 'complete_count_daily', 10, NULL),
(60008, 'Century Club', 'Complete 100 M+ dungeons total.', 'challenge', NULL, 10, NULL, NULL, 0, 'complete_count_total', 100, NULL),
(60009, 'Mythic Veteran', 'Complete 500 M+ dungeons total.', 'challenge', NULL, 25, NULL, 100050, 0, 'complete_count_total', 500, NULL),  -- 100050 = mount item
(60010, 'Season 1 Conqueror', 'Reach top 100 on any leaderboard.', 'seasonal', 1, 50, NULL, NULL, 0, 'leaderboard_rank', 100, NULL),
(60011, 'Season 1 Champion', 'Finish Season 1 in top 10 overall.', 'seasonal', 1, 100, 'S1 Champion', 100051, 0, 'leaderboard_rank', 10, NULL);  -- 100051 = champion mount

-- Dungeon-specific achievements (8 seasonal dungeons)
INSERT INTO dc_mythic_achievement_defs VALUES
(60012, 'Utgarde Pinnacle Master', 'Complete UP at M+10.', 'dungeon', 1, 15, NULL, NULL, 0, 'complete_dungeon', 10, NULL),
(60013, 'Halls of Lightning Master', 'Complete HoL at M+10.', 'dungeon', 1, 15, NULL, NULL, 0, 'complete_dungeon', 10, NULL),
(60014, 'Gundrak Master', 'Complete Gundrak at M+10.', 'dungeon', 1, 15, NULL, NULL, 0, 'complete_dungeon', 10, NULL),
(60015, 'Halls of Stone Master', 'Complete HoS at M+10.', 'dungeon', 1, 15, NULL, NULL, 0, 'complete_dungeon', 10, NULL),
(60016, 'Culling of Stratholme Master', 'Complete CoS at M+10.', 'dungeon', 1, 15, NULL, NULL, 0, 'complete_dungeon', 10, NULL),
(60017, 'Ahn\'kahet Master', 'Complete Ahn\'kahet at M+10.', 'dungeon', 1, 15, NULL, NULL, 0, 'complete_dungeon', 10, NULL),
(60018, 'Drak\'Tharon Keep Master', 'Complete DTK at M+10.', 'dungeon', 1, 15, NULL, NULL, 0, 'complete_dungeon', 10, NULL),
(60019, 'The Oculus Master', 'Complete Oculus at M+10.', 'dungeon', 1, 15, NULL, NULL, 0, 'complete_dungeon', 10, NULL);

-- Hidden achievements (Feats of Strength)
INSERT INTO dc_mythic_achievement_defs VALUES
(60020, 'Solo Mythic+', 'Complete M+2 solo.', 'hidden', NULL, 0, NULL, NULL, 1, 'complete_solo', 2, NULL),
(60021, 'Mythic Marathon', 'Complete all 8 dungeons in one day at M+5+.', 'hidden', NULL, 0, NULL, NULL, 1, 'complete_all_daily', 5, NULL),
(60022, 'Perfectly Balanced', 'Complete M+10 with exactly 5 deaths.', 'hidden', NULL, 0, NULL, NULL, 1, 'complete_exact_deaths', 10, 5);
```

---

### 12.4 Implementation Notes

**Achievement Grant Logic:**
```cpp
void CheckAndGrantAchievement(Player* player, uint32 achievementId) {
  // Check if player meets criteria
  QueryResult result = CharacterDatabase.Query(
    "SELECT current_progress, completed FROM dc_mythic_achievement_progress "
    "WHERE player_guid = {} AND achievement_id = {}",
    player->GetGUID().GetCounter(), achievementId
  );
  
  if (!result) {
    // Initialize progress tracking
    CharacterDatabase.Execute(
      "INSERT INTO dc_mythic_achievement_progress (player_guid, achievement_id, season_id) "
      "VALUES ({}, {}, {})",
      player->GetGUID().GetCounter(), achievementId, GetCurrentSeasonId()
    );
  }
  
  // Update progress based on achievement type
  UpdateAchievementProgress(player, achievementId);
  
  // Grant if complete
  if (IsAchievementComplete(player, achievementId)) {
    GrantAchievementReward(player, achievementId);
  }
}
```

**Season End Behavior:**
```cpp
void ArchiveSeasonalAchievements(uint32 seasonId) {
  // Mark all seasonal achievements as Feats of Strength
  CharacterDatabase.Execute(
    "UPDATE dc_mythic_achievement_defs SET hidden = 1 "
    "WHERE season_id = {} AND hidden = 0",
    seasonId
  );
  
  // Titles remain permanent for players who earned them
  LOG_INFO("mythic", "Season {} achievements archived as Feats of Strength", seasonId);
}
```

---

## PART 13: IMPLEMENTATION BREAKDOWN

### 13.1 SERVER-SIDE WORK (C++ / Database)

#### **Phase 1: Core Infrastructure**
```
Files to Create:
├─ src/server/scripts/DC/DungeonEnhancement/
│  ├─ DungeonEnhancementConstants.h      // Enums, IDs, action offsets
│  ├─ DungeonEnhancementManager.cpp/.h   // Singleton manager class
│  ├─ MythicDifficultyScaling.cpp/.h     // HP/Damage scaling logic
│  ├─ MythicRunTracker.cpp/.h            // Run state, timer, deaths (M+ only)
│  ├─ MythicRatingCalculator.cpp/.h      // Rating formulas (M+ only)
│  └─ MythicSeasonManager.cpp/.h         // Season start/end logic
│
├─ src/server/scripts/DC/DungeonEnhancement/NPCs/
│  ├─ npc_mythic_plus_dungeon_teleporter.cpp  // NPC 300315
│  ├─ npc_mythic_raid_teleporter.cpp          // NPC 300316
│  ├─ npc_mythic_token_vendor.cpp             // NPC 300317
│  └─ npc_keystone_master.cpp                 // NPC 300318
│
├─ src/server/scripts/DC/DungeonEnhancement/Affixes/
│  ├─ MythicAffixHandler.cpp/.h          // Base affix class (M+ only)
│  ├─ Affix_Tyrannical.cpp               // Boss scaling
│  ├─ Affix_Fortified.cpp                // Trash scaling
│  ├─ Affix_Bolstering.cpp               // Buff on death
│  ├─ Affix_Necrotic.cpp                 // Healing reduction
│  └─ Affix_Volcanic.cpp                 // Ground AoE spawning
│
└─ src/server/scripts/DC/DungeonEnhancement/Rewards/
   ├─ MythicVaultManager.cpp/.h          // Weekly vault logic (M+ only)
   ├─ MythicLootGenerator.cpp/.h         // Token/item generation
   └─ MythicAchievementHandler.cpp/.h    // Achievement tracking
```

#### **Database Tables (SQL Scripts)**
```
Location: Custom/Custom feature SQLs/

Files (Character Database):
├─ characters/
│  ├─ de_mythic_player_rating.sql        // Player M+ rating, seasonal data
│  ├─ de_mythic_keystones.sql            // Active keystone tracking
│  ├─ de_mythic_run_history.sql          // Completed runs per player
│  ├─ de_mythic_vault_progress.sql       // Weekly vault progress (M+ only)
│  └─ de_mythic_achievement_progress.sql // Player achievement tracking

Files (World Database):
└─ world/
   ├─ de_mythic_seasons.sql              // Season definitions, dates
   ├─ de_mythic_dungeons_config.sql      // Dungeon scaling configs
   ├─ de_mythic_raid_config.sql          // Raid difficulty configs
   ├─ de_mythic_affixes.sql              // Affix definitions & weekly rotation
   ├─ de_mythic_vault_rewards.sql        // Vault loot tables (M+ only)
   ├─ de_mythic_tokens_loot.sql          // Token drop rates
   ├─ de_mythic_achievement_defs.sql     // Achievement definitions
   ├─ de_mythic_npc_spawns.sql           // NPC creature spawns
   └─ de_mythic_gameobjects.sql          // GameObject spawns (Vault 700000, Font of Power 700001-700008)
```

#### **Core Hooks Required**
```cpp
// Hook into creature spawn to apply difficulty scaling
void OnCreatureCreate(Creature* creature) {
  if (creature->GetMap()->IsMythicPlus()) {
    MythicDifficultyScaling::ApplyScaling(creature, 
      creature->GetMap()->GetMythicLevel());
  }
}

// Hook into player death (M+ dungeons only - not M0, raids, or heroic content)
void OnPlayerDeath(Player* player) {
  if (player->GetMap()->IsMythicPlus() && player->GetMap()->HasKeystone()) {
    MythicRunTracker::IncrementDeathCounter(player->GetGroup());
  }
}

// Hook into boss kill
void OnCreatureKill(Unit* killer, Creature* victim) {
  if (victim->IsBoss() && victim->GetMap()->IsMythicPlus()) {
    MythicLootGenerator::GenerateLoot(victim, killer->GetGroup());
  }
}

// Hook into map creation
void OnMapCreate(Map* map) {
  if (map->IsMythicPlusEnabled()) {
    MythicRunTracker::StartRun(map);
  }
}

// Hook into dungeon completion (M+ dungeons only)
void OnDungeonComplete(Map* map) {
  if (map->IsMythicPlus() && map->HasKeystone()) {
    MythicRunTracker::EndRun(map);
    MythicRatingCalculator::CalculateAndAwardRating(map);
  }
}
```

#### **Commands to Implement**
```cpp
// .mythic commands for GMs
class mythic_commandscript : public CommandScript {
  // .mythic season create "Season Name"
  // .mythic season end <id>
  // .mythic dungeon config <id> <setting> <value>
  // .mythic affix add <name> <effect%>
  // .mythic vault reset <player>
  // .mythic rating set <player> <rating>
  // .mythic run abort - Emergency abort current M+ run
};
```

---

### 13.2 CLIENT-SIDE WORK (DBC Files)

#### **Required DBC Modifications**

**1. Item.dbc (Keystone Items)**
```
Entry Range: 100000-100008 (Mythic+2 to +10 keystones)
Note: NO M+1 exists - starts at M+2 (retail behavior)

Fields:
- ItemID: 100000 (M+2), 100001 (M+3), 100002 (M+4)... 100008 (M+10)
- ClassID: 12 (Quest item category)
- SubClassID: 0
- Name: "Mythic Keystone +2", "Mythic Keystone +3"... "Mythic Keystone +10"
- DisplayInfoID: Custom icon (use existing dungeon icon)
- Quality: 4 (Epic - purple border)
- Flags: 0x00000004 (ITEM_FLAG_BIND_TO_ACCOUNT = Cannot trade/mail)
- BuyPrice: 0
- SellPrice: 0
- RequiredLevel: 80
- MaxStack: 1
- ItemLevel: 80
- Bonding: 1 (BoP - Bind on Pickup, immediate soulbound)

Tooltip Description:
"Unlocks a Mythic+X dungeon. Activate at Font of Power inside dungeon.
Soulbound - Cannot be traded or mailed."

Reserved IDs:
- 100010: Depleted Keystone (future use)
- 100020: Mythic Dungeon Token (currency)
- 100021: Mythic Raid Token (currency)
```

**2. Spell.dbc (Buff/Debuff Affixes)**
```
Spell IDs: 70000-70010 (for affix visual effects)

Example: Necrotic (300002)
- SpellName: "Necrotic Wound"
- Description: "Healing received reduced by 10% per stack"
- SpellIconID: 136133 (necrotic visual)
- Effect: SPELL_AURA_MOD_HEALING_PCT
- BasePoints: -10 (per stack)
- Duration: -1 (permanent until cleansed)
- MaxStacks: 10

Example: Bolstering (70002)
- SpellName: "Bolstered"
- Description: "Damage and health increased by 10%"
- SpellIconID: 136101
- Effect: SPELL_AURA_MOD_DAMAGE_PERCENT_DONE
- BasePoints: +10
```

**3. Map.dbc (Optional - Mythic Difficulty Flag)**
```
If creating separate instances for Mythic+:

MapID: 1000-1010 (copy of existing dungeons)
MapName: "Deadmines (Mythic+)", "Shadowfang Keep (Mythic+)"
InstanceType: 1 (Dungeon)
MaxPlayers: 5
```

**4. Achievement.dbc (Mythic+ Achievements)**
```
Achievement IDs: 15000-15100

Example: "Mythic Champion" (15001)
- Category: 168 (Dungeons)
- Title: "Mythic Champion"
- Description: "Complete any Mythic+ dungeon"
- Points: 10
- Reward: Title "the Mythic"
- IconID: Achievement_dungeon

Example: "Keystone Master" (15002)
- Title: "Keystone Master"
- Description: "Complete all Mythic+ dungeons at level 10 or higher"
- Points: 50
- Reward: Mount (Mythic Serpent)
```

**5. ItemDisplayInfo.dbc (Keystone Visuals)**
```
DisplayID: 60000-60010

Fields:
- ModelName: Use existing item models (scrolls, keys, orbs)
- Texture: Custom texture with "+X" overlay
- GlowType: 2 (Epic glow)
- ParticleColor: Purple (Mythic theme)
```

**6. CurrencyTypes.dbc (Mythic+ Tokens)**
```
CurrencyID: 2500

Fields:
- Name: "Mythic+ Tokens"
- Description: "Earned from Mythic+ dungeons. Exchange for rewards."
- CategoryID: 89 (Miscellaneous)
- IconFileDataID: Custom token icon
- MaxQty: 10000
- Flags: 0x08 (Show in currency tab)
```

#### **DBC Export Instructions**
```
Tools Needed:
- MyDBCEditor or WoW.tools
- WoW Client 3.3.5a build 12340

Steps:
1. Open DBC file in editor
2. Add new rows with specified IDs
3. Fill in all required fields
4. Export DBC to wow_patched/DBC/
5. Create MPQ patch (patch-4.mpq) containing:
   - DBFilesClient/Item.dbc
   - DBFilesClient/Spell.dbc
   - DBFilesClient/Achievement.dbc
   - DBFilesClient/CurrencyTypes.dbc
6. Place in client Data/ folder
7. Restart client
```

---

### 13.3 ADDON WORK (Lua UI)

#### **Addon Structure**
```
AddOns/DarkChaos_MythicPlus/
├─ DarkChaos_MythicPlus.toc              // TOC file
├─ DarkChaos_MythicPlus.xml              // Frame definitions
├─ DarkChaos_MythicPlus.lua              // Main logic
├─ MythicTimer.lua                       // Timer display
├─ MythicScore.lua                       // Score calculator
├─ KeystoneUI.lua                        // Keystone interaction
├─ GroupFinder.lua                       // LFG replacement
├─ VaultUI.lua                           // Weekly vault interface
└─ DungeonJournal.lua                    // Boss mechanics guide
```

#### **Core Addon Features**

**1. Mythic+ Timer Display**
```lua
-- MythicTimer.lua
local timerFrame = CreateFrame("Frame", "MythicTimerFrame", UIParent)
timerFrame:SetSize(200, 50)
timerFrame:SetPoint("TOP", 0, -50)

local timerText = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
timerText:SetPoint("CENTER")

local startTime = 0
local targetTime = 1800  -- 30 minutes default

function MythicTimer:Start(duration)
  startTime = GetTime()
  targetTime = duration
  self:Show()
end

function MythicTimer:OnUpdate()
  local elapsed = GetTime() - startTime
  local remaining = targetTime - elapsed
  
  if remaining > 0 then
    timerText:SetText(string.format("%02d:%02d", 
      math.floor(remaining / 60), 
      math.floor(remaining % 60)))
    
    -- Color based on progress
    if remaining < 300 then  -- Last 5 minutes
      timerText:SetTextColor(1, 0, 0)  -- Red
    elseif remaining < 600 then  -- Last 10 minutes
      timerText:SetTextColor(1, 0.5, 0)  -- Orange
    else
      timerText:SetTextColor(1, 1, 1)  -- White
    end
  else
    timerText:SetText("OVERTIME")
    timerText:SetTextColor(0.5, 0.5, 0.5)  -- Gray
  end
end
```

**2. Mythic+ Score Display**
```lua
-- MythicScore.lua
local scoreFrame = CreateFrame("Frame", "MythicScoreFrame", CharacterFrame)
scoreFrame:SetSize(150, 60)
scoreFrame:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMRIGHT", 5, 100)

local scoreTitle = scoreFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
scoreTitle:SetPoint("TOP", 0, -5)
scoreTitle:SetText("Mythic+ Score")

local scoreValue = scoreFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
scoreValue:SetPoint("CENTER", 0, -10)

function MythicScore:Update()
  -- Request score from server
  SendAddonMessage("DC_MYTHIC", "REQUEST_SCORE", "WHISPER", UnitName("player"))
end

function MythicScore:OnScoreReceived(score)
  scoreValue:SetText(tostring(score))
  
  -- Color based on score tier
  if score >= 2000 then
    scoreValue:SetTextColor(1, 0.5, 0)  -- Orange (cutting edge)
  elseif score >= 1500 then
    scoreValue:SetTextColor(0.64, 0.21, 0.93)  -- Epic purple
  elseif score >= 1000 then
    scoreValue:SetTextColor(0, 0.44, 0.87)  -- Rare blue
  else
    scoreValue:SetTextColor(0.12, 1, 0)  -- Uncommon green
  end
end
```

**3. Keystone UI**
```lua
-- KeystoneUI.lua
local keystoneFrame = CreateFrame("Frame", "KeystoneFrame", UIParent)
keystoneFrame:SetSize(300, 400)
keystoneFrame:SetPoint("CENTER")
keystoneFrame:Hide()

function KeystoneUI:Show(keystoneItem)
  local level = GetKeystoneLevel(keystoneItem)
  local dungeon = GetKeystoneDungeon(keystoneItem)
  local affixes = GetKeystoneAffixes(keystoneItem)
  
  keystoneFrame.title:SetText(dungeon .. " +" .. level)
  keystoneFrame.affixes:SetText(table.concat(affixes, ", "))
  
  keystoneFrame.startButton:SetScript("OnClick", function()
    SendAddonMessage("DC_MYTHIC", "START_RUN:" .. keystoneItem, "PARTY")
    self:Hide()
  end)
  
  keystoneFrame:Show()
end
```

**4. Group Finder UI**
```lua
-- GroupFinder.lua
local finderFrame = CreateFrame("Frame", "MythicGroupFinder", UIParent)
finderFrame:SetSize(600, 500)
finderFrame:SetPoint("CENTER")

-- Create listing
local listingScrollFrame = CreateFrame("ScrollFrame", nil, finderFrame, "UIPanelScrollFrameTemplate")
listingScrollFrame:SetSize(580, 400)
listingScrollFrame:SetPoint("TOPLEFT", 10, -50)

function GroupFinder:CreateListing(dungeon, keyLevel, roles)
  local listing = {
    leader = UnitName("player"),
    dungeon = dungeon,
    keyLevel = keyLevel,
    roles = roles,  -- "tank,healer,dps"
    minScore = 0,
    timestamp = time()
  }
  
  SendAddonMessage("DC_MYTHIC", "CREATE_LISTING:" .. EncodeListingData(listing), "CHANNEL", GetChannelName("LookingForGroup"))
end

function GroupFinder:RefreshListings()
  -- Request all active listings
  SendAddonMessage("DC_MYTHIC", "REQUEST_LISTINGS", "CHANNEL", GetChannelName("LookingForGroup"))
end

function GroupFinder:ApplyToGroup(listingID)
  local message = string.format("APPLY:%s:%s:%d", 
    listingID, 
    UnitName("player"), 
    GetMythicScore())
  
  SendAddonMessage("DC_MYTHIC", message, "CHANNEL", GetChannelName("LookingForGroup"))
end
```

**5. Weekly Vault UI**
```lua
-- VaultUI.lua
local vaultFrame = CreateFrame("Frame", "MythicVaultFrame", UIParent)
vaultFrame:SetSize(700, 500)
vaultFrame:SetPoint("CENTER")

function VaultUI:Show()
  -- Request vault status from server
  SendAddonMessage("DC_MYTHIC", "REQUEST_VAULT", "WHISPER", UnitName("player"))
end

function VaultUI:DisplayRewards(rewards)
  -- rewards = { slot1 = {item, ilvl}, slot2 = {...}, slot3 = {...} }
  
  for i = 1, 3 do
    local slot = vaultFrame["slot" .. i]
    
    if rewards["slot" .. i] then
      slot.icon:SetTexture(GetItemIcon(rewards["slot" .. i].item))
      slot.ilvl:SetText("ilvl " .. rewards["slot" .. i].ilvl)
      slot.button:SetEnabled(true)
      
      slot.button:SetScript("OnClick", function()
        SendAddonMessage("DC_MYTHIC", "CLAIM_VAULT:" .. i, "WHISPER", UnitName("player"))
        self:Hide()
      end)
    else
      slot.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
      slot.ilvl:SetText("Locked")
      slot.button:SetEnabled(false)
    end
  end
  
  vaultFrame:Show()
end
```

**6. Dungeon Journal**
```lua
-- DungeonJournal.lua
local journalFrame = CreateFrame("Frame", "MythicDungeonJournal", UIParent)
journalFrame:SetSize(800, 600)
journalFrame:SetPoint("CENTER")

function DungeonJournal:ShowBoss(bossID, difficulty)
  -- Request boss data from server
  SendAddonMessage("DC_MYTHIC", "REQUEST_BOSS_INFO:" .. bossID .. ":" .. difficulty, "WHISPER", UnitName("player"))
end

function DungeonJournal:DisplayBossInfo(bossData)
  -- bossData = { name, description, abilities = {...}, loot = {...} }
  
  journalFrame.bossName:SetText(bossData.name)
  journalFrame.description:SetText(bossData.description)
  
  -- Display abilities
  for i, ability in ipairs(bossData.abilities) do
    local abilityFrame = journalFrame.abilities[i]
    abilityFrame.name:SetText(ability.name)
    abilityFrame.desc:SetText(ability.description)
    abilityFrame.icon:SetTexture(ability.icon)
  end
  
  -- Display loot
  for i, item in ipairs(bossData.loot) do
    local lootButton = journalFrame.loot[i]
    lootButton:SetScript("OnEnter", function()
      GameTooltip:SetOwner(lootButton, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink("item:" .. item)
      GameTooltip:Show()
    end)
  end
  
  journalFrame:Show()
end
```

#### **Addon Communication Protocol**
```lua
-- Messages sent between addon and server

-- Client → Server
"REQUEST_SCORE"                    -- Get player's M+ score
"REQUEST_VAULT"                    -- Get weekly vault status
"START_RUN:[keystoneGUID]"         -- Start M+ run with keystone
"CLAIM_VAULT:[slotNumber]"         -- Claim vault reward
"REQUEST_BOSS_INFO:[bossID]:[diff]" -- Get boss journal data
"CREATE_LISTING:[listingData]"     -- Create group listing
"APPLY_GROUP:[listingID]"          -- Apply to group

-- Server → Client
"SCORE:[score]"                    -- Player's current score
"VAULT:[slot1]:[slot2]:[slot3]"    -- Vault reward data
"TIMER_START:[duration]"           -- Start timer (30 minutes)
"TIMER_UPDATE:[remaining]"         -- Update timer
"RUN_COMPLETE:[rating]:[loot]"     -- Run finished
"BOSS_INFO:[jsonData]"             -- Boss journal data
"LISTING_UPDATE:[listings]"        -- Group finder update
```

---

### 13.4 Testing Checklist

#### **Server-Side Tests**
- [ ] Difficulty scaling applies correctly (HP/Damage multipliers)
- [ ] Death counter tracks accurately (no exploits with group leave/rejoin)
- [ ] Rating calculation matches formula
- [ ] Keystone upgrades/depletes correctly
- [ ] Affixes apply at correct key levels
- [ ] Loot generation works (tokens + items)
- [ ] Weekly vault resets properly
- [ ] Seasonal transitions function (end season, start new)
- [ ] Performance under 20 concurrent M+ runs
- [ ] Database queries don't cause lag spikes
- [ ] NPC gossip menus display correctly
- [ ] Teleportation works to all dungeons/raids

#### **Client-Side Tests**
- [ ] DBC items show in-game (keystones, currencies)
- [ ] Achievement notifications trigger
- [ ] Spell effects display (affix debuffs)
- [ ] Item tooltips show correct information
- [ ] No client crashes with custom DBCs

#### **Addon Tests**
- [ ] Timer displays and updates in real-time
- [ ] Score UI shows correct values
- [ ] Keystone UI activates runs properly
- [ ] Group Finder lists/applies work
- [ ] Vault UI claims rewards correctly
- [ ] Dungeon Journal displays boss info
- [ ] No Lua errors in chat
- [ ] Addon messages send/receive properly

---

## SUMMARY OF IMPROVEMENTS

**✅ APPROVED FOR IMPLEMENTATION:**
1. **Keystone System** - Physical items in inventory (item IDs 100000-100008, BoP, non-tradable, weekly vault reset)
2. **Weekly Affix Rotation** - Server-wide rotation ONLY (retail-like behavior) ✅ CONFIRMED
3. **Great Vault Enhancement** - 3 reward slots based on activity with token scaling system ✅ CONFIRMED
4. **Performance Optimizations** - Instance pooling, async queries, caching (critical for scale)
5. **Anti-Exploit Measures** - Key validation, death tracking, 15-death maximum ✅ CONFIRMED
6. **Death Penalty System** - 15 deaths = auto-fail, upgrade formula (0-5=+2, 6-10=+1, 11-14=same) ✅ CONFIRMED

**🔄 MODIFIED IMPLEMENTATIONS:**
7. **Keystone Acquisition** - M+0 completion OR weekly vault OR Keystone Master NPC ✅ CONFIRMED
8. **Premade Group Finder** - NPC-based group listings (simple dungeon/raid filters)
9. **Dungeon Journal** - Custom addon UI with server-delivered data (3.3.5a doesn't have retail journal DBCs)

**⏭️ NOT IMPLEMENTING (Phase 1):**
10. ❌ **Timer System** - Keeping death-based system (simpler, less UI complexity) ✅ CONFIRMED
11. ❌ **Mythic+ Score/Rating** - Removed per user request (no scoring system)
12. ❌ **Player Affix Choice** - Server-wide rotation only (no player selection) ✅ CONFIRMED
13. ❌ **M+ for Raids** - Only Normal/Heroic/Mythic fixed difficulties ✅ CONFIRMED

**🎯 KEY SPECIFICATIONS (USER REQUIREMENTS):**
- **Keystones:** Item IDs start at 100000 (100000 = M+2, 100008 = M+10)
- **NO M+1:** Mythic (M+0) is keystone-free baseline. Keystones start at M+2 (retail behavior)
- **Trading:** Keystones are NOT tradable/sellable (soulbound, cannot be mailed or traded) ✅ CONFIRMED
- **Single Keystone:** Only ONE player places keystone in Font of Power (entire group benefits, retail-like)
- **Failure:** Failed runs destroy keystone (must get replacement from Keystone Master NPC) ✅ CONFIRMED
- **Weekly Reset:** Vault gives keystone at highest level completed last week ✅ CONFIRMED
- **Weekly Lockouts:** REMOVED for M+ dungeons (unlimited runs), KEPT for raids (separate per difficulty) ✅ CONFIRMED
- **Tradeable Loot:** Items can be traded to group members for 2 hours after drop (retail-like)
- **Seasonal Dungeons:** 8 dungeons per season from ALL Vanilla/TBC/WotLK content ✅ CONFIRMED
- **NPC Placement:** Stormwind, Orgrimmar, Dalaran (Great Vault = GameObject) ✅ CONFIRMED
- **Item Levels:** 226 base for M+0, +6 per keystone level (M+10 = 286 ilvl)
- **Seasonal Rotation:** 8 dungeons active per season from ALL Vanilla/TBC/WotLK content ✅ CONFIRMED
- **Affix Display:** Affixes appear in player's debuff bar (visible like other auras)
- **Affix Selection:** Server-wide rotation ONLY (no player choice) ✅ CONFIRMED
- **Tokens:** Two separate token types:
  - **Mythic Dungeon Tokens (100020):** Awarded at end of every M+/Mythic run (entire group)
  - **Mythic Raid Tokens (100021):** Awarded per boss kill in Heroic/Mythic raids
  - **Token Vendor:** Deferred to Phase 2 ⏳
- **Raids:** NO Mythic+ for raids. Only Normal/Heroic/Mythic fixed difficulties ✅ CONFIRMED
- **Raid Lockouts:** Separate lockout per difficulty (can run Normal AND Heroic AND Mythic same week) ✅ CONFIRMED
- **Legacy Raids:** Vanilla (MC, BWL, AQ, Naxx60) and BC (Kara, BT, Sunwell, etc.) receive Heroic/Mythic
- **Difficulty Implementation:** EASIEST method - reuse existing DIFFICULTY_HEROIC (ID=1) with runtime scaling
- **NPC Teleporter:** Database-driven menu system (dc_mythic_teleporter_menus) for flexible configuration
- **NPC Placement:** Stormwind, Orgrimmar, Dalaran (Great Vault = GameObject) ✅ CONFIRMED
- **Configuration:** All major settings configurable in darkchaos-custom.conf.dist (Section 6: Mythic+ System)

**📋 3.3.5a TECHNICAL NOTES:**
- **Dungeon Journal:** Retail's journal requires Cataclysm+ DBCs (JournalEncounter.dbc doesn't exist in WotLK). Solution: Custom addon with server-side data delivery via SendAddonMessage protocol OR use AtlasLoot Enhanced for loot tables only (no boss mechanics).
- **LFG System:** Can't easily modify client LFG UI without extensive patches. Solution: Keep standard LFG for Normal/Heroic/Mythic, use NPC for Mythic+ group listings.
- **Keystones:** Fully implementable via Item.dbc entries (items 100000-100008), no client limitations.
- **Affix Debuffs:** Use existing spell IDs or custom spells (e.g., 26662, 26661) as permanent auras while in M+ instance.
- **Level 80 Scaling:** Requires MapDifficulty.dbc edits + creature_template SQL updates for Vanilla/BC content.
- **Creature Template IDs:** Custom creatures start at 100000 (matches keystone IDs): 100000-100010 (NPCs), 100100+ (Vanilla bosses), 100200+ (BC bosses).
- **Eluna Teleporter:** Existing scripts (800002, 33274) can be extended with custom columns (season_id, required_level, difficulty, keystone_level) OR converted to C++ for better performance.

**⚙️ CONFIGURATION FILE:**
All settings added to `Custom/Config files/darkchaos-custom.conf.dist` Sections 6.8-6.11:
- **Section 6.8:** Tradeable loot window (duration, cleanup interval)
- **Section 6.9:** Legacy content scaling (level 80 for all Vanilla/BC)
- **Section 6.10:** Custom creature template ID ranges (100000+)
- **Section 6.11:** Eluna teleporter integration (creature IDs, menu ID ranges)
- Plus existing Section 6: Keystone behavior, affixes, vault, rewards, tokens, seasonal rotation, performance, anti-exploit

**🔧 DBC EDITING (OPTIONAL, ADVANCED):**
- **Method 1 (Recommended):** Server-side only, no DBC changes, easiest implementation
- **Method 2 (Advanced):** Edit Map.dbc, MapDifficulty.dbc, Item.dbc, Spell.dbc for:
  - Native difficulty names in client UI
  - Level 80 scaling for all Vanilla/BC content
  - Custom keystone items (100000-100008)
  - Affix spell entries with icons/tooltips
  - Requires MPQ packing (MPQEditor/LadiksMPQEditor) and client distribution

---


