# Endless Dungeon (WotLK / AzerothCore) — Concept v2

> Inspired by Project Ascension's **Manastorm** system, adapted for AzerothCore + WotLK 3.3.5a client.

---

## High-Level Pitch
A fast-paced, **endless floor-based dungeon** where a solo player or party of up to 5 pushes through consecutive floors of increasing difficulty. Each floor is a compact encounter: a small trash pack followed by a boss. Rewards scale with **floor depth**, **player level**, and **party size**.

Key features (adapted from Manastorm):
| Feature | Description |
|---------|-------------|
| **Checkpoint every 5 floors** | Save your progress; resume later without starting over |
| **Dynamic loot scaling** | Caches drop items matching content tier for current floor range |
| **Cumulative XP bonus** | +1 % XP per floor completed (stacks for the run) |
| **Dual currency** | *Tokens* (one-time per new floor) + *Essence* (repeatable per floor) |
| **No affixes** | Difficulty grows via stat scaling and boss mechanics, not random modifiers |
| **Greedy Goblin** | Rare spawn that drops bonus gold/loot if killed quickly |

Built for:
- **WotLK client** (addon UI + server messages; no modern UI framework)
- **AzerothCore** scripting (instances, DB-driven spawns, Eluna/C++ scripts)

---

## Core Goals
1. **Repeatable** content using existing dungeon assets
2. **Short sessions** with "one more floor" momentum
3. **Mid-level entry** – available from level 25+ (player has talents, gear, and skills)
4. **Fair scaling** for 1–5 players
5. **Clear progression** per run (floor depth) and across runs (currency, unlocks)

---

## Player Experience

### Entry
1. Player talks to **Endless Dungeon Gatekeeper** NPC (or uses addon button).
2. System detects:
   - Party size (1–5)
   - Lowest / average level in party → **Target Level**
3. Options presented:
   - **Continue Run** (if checkpoint exists)
   - **New Run** (starts at floor 1)

### Floor Loop
Each floor takes ~2–4 minutes:
1. **Trash pack** spawns (scaled to party size & depth).
2. After trash cleared, **boss** spawns.
3. Boss defeated → floor complete → short pause (5–10 s) → next floor begins.

Every **5 floors** the run auto-saves (checkpoint).

### Fail / Wipe Rules
- Party wipe = **1 strike**.
- After **3 strikes**, run ends.
- On run end: summary screen shows depth, rewards earned, currencies.

---

## Checkpoints (Save Points)
- Unlocked at floors **5, 10, 15, 20, …**
- Stored per-character (solo) and per-group-leader (group).
- Resuming a checkpoint:
  - Enemies scale to **current** party size/level (not original).
  - One-time Token rewards already collected are **not** re-granted.
  - Essence is still earned normally.

---

## Difficulty & Scaling

### Stat Scaling per Floor
Scaling is purely **numerical** (no random affixes).

| Floor Range | HP Multiplier | Damage Multiplier | Notes |
|-------------|---------------|-------------------|-------|
| 1–10 | 1.00 + 0.05×(F-1) | 1.00 + 0.03×(F-1) | Warm-up |
| 11–25 | base + 0.06/floor | base + 0.04/floor | Mid-tier |
| 26–50 | base + 0.07/floor | base + 0.05/floor | Challenging |
| 51+ | base + 0.08/floor | base + 0.06/floor | Endgame push |

### Party Size Scaling
| Party Size | HP Multiplier | Damage Multiplier | Add Count Modifier |
|------------|---------------|-------------------|--------------------|
| 1 | ×0.40 | ×0.50 | −2 adds |
| 2 | ×0.60 | ×0.65 | −1 add |
| 3 | ×0.80 | ×0.80 | base |
| 4 | ×0.95 | ×0.90 | +1 add |
| 5 | ×1.00 | ×1.00 | +2 adds |

### Level Scaling
- Creatures spawn at **Target Level** (party average or lowest, configurable).
- Item rewards from caches match Target Level bracket.

---

## Rewards

### 1. Currencies

#### Tokens (one-time milestone)
Awarded **once per new floor reached** (first-time only).

| Floor | Tokens Earned | Cumulative |
|-------|---------------|------------|
| 1 | 1 | 1 |
| 2 | 1 | 2 |
| 3 | 1 | 3 |
| 4 | 1 | 4 |
| 5 | 3 | 7 |
| 6 | 1 | 8 |
| … | … | … |
| 10 | 3 | 16 |
| 15 | 5 | 26 |
| 20 | 5 | 36 |
| 25 | 7 | 50 |

**Pattern**: +1 per floor; bonus **+2** every 5 floors; bonus **+2** extra at floors 15, 25, 35, …

#### Essence (repeatable)
Awarded **every floor**, every run.

| Floor | Essence Earned |
|-------|----------------|
| 1 | 2 |
| 2 | 2 |
| 3 | 3 |
| 4 | 3 |
| 5 | 5 |
| 6 | 3 |
| 7 | 3 |
| 8 | 4 |
| 9 | 4 |
| 10 | 6 |

**Pattern**: base 2–4 per floor; **+3** bonus on checkpoint floors (5, 10, 15, …).

### 2. Loot Caches (Tiered by Floor)
At end of **each floor**, a cache spawns containing level-appropriate gear.

| Floor Range | Loot Source (Level 80 example) |
|-------------|-------------------------------|
| 1–10 | Normal dungeon blues |
| 11–20 | Heroic dungeon blues |
| 21–30 | 10-man Naxx / OS / EoE |
| 31–40 | 25-man Naxx / OS / EoE |
| 41–50 | Ulduar 10 |
| 51–60 | Ulduar 25 |
| 61–70 | ToC 10 |
| 71–80 | ToC 25 |
| 81–90 | ICC 10 Normal |
| 91–100 | ICC 10 Heroic |
| 101–110 | ICC 25 Normal |
| 111+ | ICC 25 Heroic / Ruby Sanctum |

For **non-80 players**, caches draw from level-appropriate dungeon loot tables.

### 3. Cumulative XP Bonus
- Each floor grants **+1 % XP** (additive).
- At floor 50, you have +50 % XP from all sources.
- Resets when run ends (wipe-out or voluntary exit).

### 4. Greedy Goblin (Random Spawn)
- ~5 % chance per floor to spawn alongside trash.
- Drops large gold pouch + small chance for rare cosmetic.
- Despawns quickly if not killed (10 s).

---

## Currency Vendor (Endless Emporium)

### Token Shop (Milestone Currency)
| Item | Token Cost | Notes |
|------|-----------|-------|
| Endless Dungeon Consumable Pack | 5 | Health/mana pots, food |
| Heirloom Token (random slot) | 50 | Binds to account |
| Cosmetic Tabard | 30 | |
| Cosmetic Mount | 200 | Unique recolor |
| Curated Raid Piece (T7/T8/T9/T10) | 80–150 | Choose slot, tier based on highest floor |

### Essence Shop (Repeatable Currency)
| Item | Essence Cost | Notes |
|------|-------------|-------|
| Repair Bot | 10 | Summons vendor in dungeon |
| Endless Potion (infinite use, run-only) | 25 | |
| XP Boost Scroll (+10 % for 1 hr) | 15 | |
| Appearance Unlock Token | 40 | Unlock transmog for any owned item |

---

## Dungeon Pool: TBC 5-Player Dungeons (Recommended)

### Why TBC Dungeons?
- **Compact and linear** – ideal for quick floors
- **Level 60–70 baseline** – easy to scale to any target level
- **Not competing with WotLK endgame** – WotLK dungeons stay available for M+ and normal runs
- **Familiar to players** – nostalgic content with good art
- **15 dungeons = ~50 floor segments** – enough variety for deep runs

### TBC Dungeon Pool

| Dungeon | Map ID | Segments | Theme |
|---------|--------|----------|-------|
| **Hellfire Ramparts** | 543 | 3 | Fel Orc fortress |
| **The Blood Furnace** | 542 | 3 | Industrial fel factory |
| **The Slave Pens** | 547 | 3 | Naga underwater |
| **The Underbog** | 546 | 3 | Fungal swamp |
| **Mana-Tombs** | 557 | 3 | Ethereal crypts |
| **Auchenai Crypts** | 558 | 2 | Draenei undead |
| **Sethekk Halls** | 556 | 2 | Arakkoa temple |
| **Shadow Labyrinth** | 555 | 4 | Shadow Council |
| **The Mechanar** | 554 | 3 | Blood Elf tech |
| **The Botanica** | 553 | 5 | Blood Elf gardens |
| **The Arcatraz** | 552 | 3 | Naaru prison |
| **The Shattered Halls** | 540 | 3 | Fel Horde gauntlet |
| **Magister's Terrace** | 585 | 4 | Sunwell prelude |
| **Old Hillsbrad Foothills** | 560 | 3 | CoT – Escape |
| **The Black Morass** | 269 | 3 | CoT – Portal waves |

**Total: ~50 floor segments.**

### How Dungeon Reuse Works
1. **Separate Instance Difficulty** – Endless runs use a custom "Endless" difficulty ID.
2. **Runtime Spawning** – All Endless creatures are spawned at runtime (not DB-spawned).
3. **Normal/Heroic Unaffected** – Original dungeon runs work exactly as before.
4. **Level Scaling** – Creatures spawn at Target Level with scaled HP/damage.

See [ARCH_Tech_Architecture.md](ARCH_Tech_Architecture.md) for full technical details.

### Segment Example: Hellfire Ramparts

| Segment | Area | Trash Packs | Boss |
|---------|------|-------------|------|
| 1 | Entrance → First platform | 3 packs | Watchkeeper Gargolmar |
| 2 | Bridge → Second platform | 2 packs | Omor the Unscarred |
| 3 | Final ramp → End | 2 packs | Vazruden the Herald |

---

## Spawn Approach

### Option A – Dedicated Map with Spawn Points
- Use a single unused map (e.g., GM Island, or a custom map).
- Define 20–40 **anchor points** (positions).
- Each floor randomly selects an anchor and spawns a **spawn template** (trash pack definition + boss entry).

### Option B – Reuse Existing Dungeon Instances
- Create a **pool of dungeon instance IDs** (one per dungeon).
- Each floor selects a dungeon + segment.
- Teleport party to segment; spawn scaled creatures at predefined positions.
- On floor end, teleport to next dungeon/segment.

**Recommendation**: Start with **Option B** for faster content; migrate to dedicated map later for polish.

### Spawn Template Schema (DB)
```
endless_floor_templates
  floor_id, dungeon_map_id, segment_id, anchor_x, anchor_y, anchor_z
  trash_group_id, boss_entry, boss_x, boss_y, boss_z
```

Trash groups reference `endless_trash_groups` → list of creature entries + relative positions.

---

## Difficulty Modes (Optional)

If you want to add a separate difficulty layer **without affixes**:

| Mode | HP/Dmg Multiplier | Reward Multiplier | Notes |
|------|-------------------|-------------------|-------|
| Normal | ×1.0 | ×1.0 | Default |
| Hard | ×1.3 | ×1.5 | Unlocks at floor 25 reached once |
| Nightmare | ×1.6 | ×2.0 | Unlocks at floor 50 reached once |

Harder modes = faster currency gain but higher skill floor.

---

## Replayability Mechanisms

1. **Leaderboard** – Track highest floor per week/season (solo & group).
2. **Daily Bonus** – First 10 floors each day grant double Essence.
3. **Weekly Cap Reset** – Token rewards reset weekly (new milestone progress).
4. **Rotating Dungeon Pool** – Each week, only a subset of dungeons are active → variety.
5. **Seasonal Cosmetics** – Limited-time mounts/titles for reaching floor thresholds.
6. **Greedy Goblin Hunt** – Track goblin kills; reward at milestones.
7. **Challenge Modes** (optional) – Timed runs for bonus rewards.

---

## Addon / UI

Lightweight addon that displays:
- Current floor, checkpoint status
- Strikes remaining
- Cumulative XP bonus
- Token / Essence totals
- Timer (optional)

Server sends state via addon messages or world-state updates.

---

## MVP Scope

| Component | MVP Target |
|-----------|------------|
| Dungeons | 5 (Deadmines, SM Cath, Stockade, UK, Nexus) |
| Floors | 25 (5 per dungeon) |
| Bosses | Reuse existing, add scaling script |
| Currencies | Token + Essence |
| Vendor | Basic consumables + 1 cosmetic mount |
| Checkpoints | Every 5 floors |
| Leaderboard | Simple DB table, addon display |

---

## Summary of Changes from v1
- **Removed** affixes/mutations system entirely.
- **Added** checkpoint system every 5 floors.
- **Added** dual currency (Token + Essence) with progression tables.
- **Added** tiered loot cache system matching Manastorm.
- **Added** cumulative XP bonus per floor.
- **Added** Greedy Goblin random spawn.
- **Added** candidate dungeon list for floor reuse.
- **Added** spawn approach options (dedicated map vs. reuse).
- **Added** optional difficulty modes (no affixes, just multipliers).
- **Added** replayability mechanisms (leaderboard, daily bonus, rotating pool, etc.).
