# EndlessDungeon

Design package for an **Endless Dungeon** system inspired by Project Ascension's *Manastorm*, adapted for **AzerothCore + WotLK 3.3.5a**.

---

## Documents

| File | Description |
|------|-------------|
| [CONCEPT_EndlessDungeon.md](CONCEPT_EndlessDungeon.md) | Gameplay concept, floor loop, checkpoints, dual-currency (Tokens + Essence), loot tiers, TBC dungeon pool, replayability |
| [ARCH_Tech_Architecture.md](ARCH_Tech_Architecture.md) | Technical architecture: DB schema, scaling engine, spawn isolation (difficulty-based), creature level scaling, TBC dungeon pool implementation |
| [ADDON_UI_Design.md](ADDON_UI_Design.md) | Addon design: HUD, Group Finder integration (DC-MythicPlus), Leaderboard extension (DC-Leaderboards), Spectator mode, DC-AddonProtocol messages |
| [COMPARATIVE_ANALYSIS.md](COMPARATIVE_ANALYSIS.md) | Research from Torghast, Hades, D3 Greater Rifts, WoW Delves; recommended additions (Runes, Fragments, Talents, Scoring) |
| [PROPOSAL_Group_Level_Scaling.md](PROPOSAL_Group_Level_Scaling.md) | **NEW** — Proposal for group level scaling: Target Level selection, level gap limits, overlevel debuffs, XP/loot distribution |

---

## Key Features
- **Checkpoint every 5 floors** – save progress, resume later
- **Dynamic loot scaling** – caches match floor tier and player level
- **Dual currency** – Tokens (one-time milestone) + Essence (repeatable)
- **No affixes** – difficulty via stat scaling only
- **TBC dungeon pool** – 15 dungeons (53 segments = 53 unique floors), isolated from normal runs
- **Creature level scaling** – spawn mobs at any target level (25–80)
- **1–5 player scaling** – solo-friendly and group-friendly
- **Entry at level 25+** – players have talents, gear, and skills ready
- **Addon integration** – HUD, Group Finder tab, Leaderboard category, Spectator mode

### New Features (from Comparative Analysis)
- **Endless Runes** – Temporary powers picked after each boss (like Torghast Anima Powers / Hades Boons)
- **Fragments** – Run currency dropped by elites, spent at checkpoint vendors
- **Endless Talents** – Permanent meta-progression upgrades
- **Difficulty Selection** – Normal/Heroic/Mythic for solo accessibility
- **Scoring System** – Competitive layer with leaderboards
- **Weekly Modifiers** – Blessings (buffs) and Torments (debuffs for bonus rewards)

---

## Technical Highlights
- **Spawn Isolation**: Endless runs use a custom difficulty ID; creatures are runtime-spawned, not DB-spawned
- **Level Scaling**: `Creature::SetLevel()` + `CreatureBaseStats` for HP/damage at any target level
- **Addon Protocol**: Extends DC-AddonProtocol with `EDNG` module for state sync
- **Leaderboard**: New `endless` category in DC-Leaderboards
- **No Dungeon Cloning**: Reuses existing M+ infrastructure (Difficulty=2) with runtime scaling
- **Run Levels**: Player progression system (Level 1-6+) with increasing scaling and rewards

---

## Run Flow Summary

1. **Start**: Talk to Gatekeeper → Select Run Level → Choose New/Continue
2. **Floor Loop**: Trash → Boss → Rewards → Next Floor (2-3 min each)
3. **Checkpoint**: Every 5 floors auto-saves progress
4. **Wipe**: 3 strikes = run ends; options: Retry Floor, Reset to Checkpoint, End Run
5. **End Run**: Summary → Retry / Level Up / Continue from Checkpoint / Exit

### Run Level Progression

| Run Level | Scaling | Rewards | Unlock |
|-----------|---------|---------|--------|
| 1 Apprentice | ×1.00 | ×1.00 | Default |
| 2 Journeyman | ×1.15 | ×1.10 | Floor 10 @ L1 |
| 3 Expert | ×1.30 | ×1.20 | Floor 15 @ L2 |
| 4 Master | ×1.50 | ×1.30 | Floor 20 @ L3 |
| 5+ | +0.25 | +0.15 | Floor 25 @ prev |

---

## CrossSystem Integration

Endless Dungeon is fully integrated with the DarkChaos CrossSystem infrastructure:

| Component | Integration |
|-----------|-------------|
| **SystemId** | `EndlessDungeon = 12` added to `CrossSystemCore.h` |
| **ContentType** | `EndlessDungeon = 8` for session tracking |
| **EventTypes** | `EndlessDungeonStart/FloorComplete/Checkpoint/Wipe/End/Resume` (1000-1005) |
| **Rewards** | Uses `RewardDistributor` for Token/Essence with prestige/seasonal multipliers |
| **Session** | Updates `SessionContext.activeContent` on run start/end |
| **Great Vault** | Floor progress can contribute to dungeon vault slots |

### Database Tables (dc_ prefix)

All Endless Dungeon tables use the `dc_` prefix for consistency:

| Table | Purpose |
|-------|---------|
| `dc_endless_runs` | Active and historical run tracking |
| `dc_endless_checkpoints` | Saved progress at floor 5/10/15/... |
| `dc_endless_floors` | Floor template definitions |
| `dc_endless_trash_groups` | Trash pack group definitions |
| `dc_endless_trash_spawns` | Individual spawn positions |
| `dc_endless_loot_tiers` | Loot template mappings by floor range |
| `dc_endless_currency_log` | Reward audit trail |
| `dc_endless_player_unlocks` | Hard/Nightmare mode unlocks |

---

## Client Patch Approach

Two options for handling the Endless difficulty:

1. **Reuse Mythic (Recommended)**: Leverage existing Difficulty=2 entries for TBC dungeons. Server detects Endless mode via instance flag.
2. **New Difficulty ID**: Add Difficulty=3 entries to MapDifficulty.dbc. Clean separation but requires client patch.

See [ARCH_Tech_Architecture.md](ARCH_Tech_Architecture.md#client-patch-approach) for details.

---

## Quick Links
- Manastorm inspiration: https://project-ascension.fandom.com/wiki/Manastorm
- DC-AddonProtocol: `Custom/Client addons needed/DC-AddonProtocol`
- DC-MythicPlus: `Custom/Client addons needed/DC-MythicPlus`
- DC-Leaderboards: `Custom/Client addons needed/DC-Leaderboards`
- CrossSystem: `src/server/scripts/DC/CrossSystem`
