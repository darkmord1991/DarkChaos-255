# DarkChaos Custom Commands
*Last Updated: January 2026*

This document provides a comprehensive list of custom commands available on the DarkChaos server.

[TOC]

## Player Commands

These commands are available to all players to manage various custom systems.

### System: Jade Forest Training Grounds
*Location:* Jade Forest (Map 745) – Talk to the **Training Master** NPC (entry 800029)

The Training Master provides a gossip menu (no chat command) to spawn configurable boss-training dummies for practice.

| Gossip Option | Description |
| :--- | :--- |
| **Spawn boss-training dummy** | Spawn one or more training dummies at the configured location. |
| **Despawn my training dummies** | Despawn all dummies you previously spawned. |
| **Profile: None / Cleave / Void / Stack / Add / Mixed** | Select the mechanic profile the dummy will use (frontal cleave, targeted void zones, stacking debuff, add-before-totem, or random mix). |
| **Armor: Normal / Low / Bossy** | Adjust the dummy's armor multiplier for damage testing. |
| **Movement: Stationary / Moving** | Toggle whether the dummy moves around during combat. |
| **Targets: 1 / 2 / 3 / 5** | Set how many dummies to spawn at once. |
| **Level: Match player / 80 / 255** | Set the dummy's level (default matches your level). |
| **Visual: Random boss / Dummy model** | Toggle random boss appearance from the expansion display pool. |
| **Spawn location: Anchor / Near master / Near player / Nearest pad** | Choose where dummies spawn (default: Anchor = fixed training area). |

*Note: Training dummies are temporary, phased per-player, and auto-despawn after 5 minutes of inactivity.*

---

### System: AoE Loot
*Command:* `.aoeloot` (Alias: `.lp`)

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `toggle` | | Toggle AoE looting on or off. |
| `enable` | | Enable AoE looting. |
| `disable` | | Disable AoE looting. |
| `messages` | | Toggle chat messages for loot summaries. |
| `quality` | `<0-6>` | Set minimum loot quality to collect (0=Poor, 1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5/6=Legendary/Artifact). |
| `skin` | | Toggle auto-skinning of corpses. |
| `stats` | | View your personal looting statistics (items, gold, etc.). |
| `info` | | View system configuration (range, limits). |

### System: Dueling
*Command:* `.duel`

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `stats` | `[player]` | View duel statistics (wins/losses/damage) for yourself or a target. |
| `top` | `[count]` | View the top duelists on the server (default top 10). |

### System: Mythic+ Spectator
*Command:* `.spectate` (Alias: `.mspec`)

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `list` | | List active Mythic+ runs available for spectating. |
| `join` | `<runID>` | Join a specific run as a spectator using its ID. |
| `leave` | | Stop spectating and return to your previous location. |
| `watch` | `<player>` | Switch your camera view to follow a specific player in the dungeon. |
| `player` | `<name>` | Direct join: Spectate a specific player's run. |
| `code` | `<code>` | Join a run using a private invite code. |
| `invite` | `[mins] [uses]` | Generate an invite code for your own run (Leader only). |
| `guild` | | Broadcast a spectator invite link to your guild chat. |
| `replays` | `[limit]` | List recent run replays. |
| `replay` | `<id>` | Watch a replay (plays recorded events in chat; no teleport). |

### System: Item Upgrades
*Command:* `.upgrade`

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `info` | `<item_link>` | View detailed upgrade information for a linked item. |
| `list` | | List all upgrade tiers, costs, and benefits. |
| `status` | | View the status of the upgrade system. |
| `mech procs` | | View your current proc scaling information. |
| `adv respec` | `[item|all]` | Respec upgrades on an item (or all items). Check cooldowns first. |
| `adv achievements` | | View your upgrade-related achievements. |
| `adv guild` | | View guild-wide upgrade statistics. |
| `prog mastery` | | View your Artifact Mastery progress. |
| `prog weekcap` | | View your weekly upgrade currency caps. |
| `season info` | | View information about the current upgrade season. |
| `season leaderboard` | | View the seasonal upgrade leaderboard. |
| `season history` | | View your personal seasonal history. |

### System: Prestige
*Command:* `.prestige`

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `info` | | View your current prestige level, XP, and active bonuses. |
| `reset` | | Initiate a prestige reset (requires max level). |
| `confirm` | | Confirm a pending prestige reset. |
| `challenge start` | `<iron\|speed\|solo>` | Start a specific prestige challenge. |
| `challenge status` | | View the status of your active challenge. |
| `challenge list` | | List all available prestige challenges. |
| `altbonus info` | | View bonuses applied to this alt from your main's prestige. |

### System: Mythic+ Dungeons
*Command:* `.mplus`

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `info` | | Show information about the current Mythic+ run (timer, affix, etc). |
| `cancel` | | Cancel the current Mythic+ run (Leader only). |

### System: Seasonal Rewards
*Command:* `.season`

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `chest` | | Check for and claim your seasonal reward chest. |

### System: Challenges (Hardcore/Ironman)
*Command:* `.challenge`

Displays all active challenge modes on your character. To start challenges, visit a **Challenge Shrine** in the starting area.

| Mode | Effect |
| :--- | :--- |
| **Hardcore** | One life only – permanent death locks the character. |
| **Semi-Hardcore** | Death causes gear loss. |
| **Self-Crafted** | Can only equip self-crafted gear. |
| **Item Quality** | Restricted to white/gray quality items. |
| **Slow XP** | 50% XP gain rate. |
| **Very Slow XP** | 25% XP gain rate. |
| **Quest XP Only** | XP only from quests (no mob kills). |
| **Iron Man** | Ultimate challenge – combines multiple restrictions. |

### System: Hinterland Battleground
*Command:* `.hlbg`

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `live` | | Get live battle status (Intended for Addon usage). |
| `queue join` | | Join the Hinterland Battleground queue. |
| `queue leave` | | Leave the queue. |
| `queue status` | | Check your current queue status. |
| `queue qstatus` | | Alias for queue status. |

### System: GPS Position Info
*Command:* `.gps`

Shows detailed position information including:
- Map ID, Zone ID, Area ID
- X/Y/Z coordinates and orientation
- Grid and cell coordinates
- Phase mask and instance ID
- **Partition ID** (when map partitioning is enabled)
- **Layer ID** (when layering is enabled)

*Note: This command is available to all players for debugging their position.*

### System: Map Partitioning & Layering
*Command:* `.dcpartition` (Alias: `.dc partition`)

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `status` | | View partition and layer info for your current map. |
| `layer` | `<id>` | Switch to a specific layer (bypasses cooldown if GM). |
| `diag` | `<on\|off\|status>` | Toggle runtime diagnostics for debugging. |
| `config` | | Display partition and layer configuration settings. |
| `tiles` | | Print ADT tile counts per map and computed partition totals. |

*Note: Layer switching has a cooldown that escalates with frequent use (1-10 minutes).*

### System: Guild Housing
*Command:* `.guildhouse` (Alias: `.gh`)

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `teleport` | | Teleport to your customized Guild House instance. |
| `butler` | | Spawn your Guild House Butler (requires Master). |
| `info` | | View instance information (Phase, Map, Coordinates). |
| `members` | | List all guild members currently inside the Guild House. |
| `rank` | `<rank>` | Set guild house rank permissions. |
| `move` | `<x> <y> <z> [o]` | Move your guild house entry point (GM Island/guild house only). |
| `undo` | | Undo last move/placement (if supported by your guild house build). |

### System: Hotspots
*Command:* `.hotspot` (Alias: `.hotspots`)

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `status` | | Check if you are currently standing in an active XP Hotspot. |

### Addon: DC-QoS
*Command:* `/dcqos` (Alias: `/qos`)

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| *(none)* | | Open the DC-QoS settings panel. |
| `debug` | | Toggle DC-QoS debug mode. |
| `reset` | | Reset current profile to defaults and reload UI. |
| `bind` | | Toggle keybind mode. |
| `reload` | | Reload UI. |
| `profile list` | | List available profiles. |
| `profile set` | `<name>` | Switch to profile for this character. |
| `profile setglobal` | `<name>` | Switch global profile for all characters. |
| `profile new` | `<name> [copyFrom]` | Create a new profile (optional copy source). |
| `profile delete` | `<name>` | Delete a profile. |
| `profile export` | `<name>` | Print export string for a profile. |
| `profile import` | `<name> <data>` | Import profile data. |
| `help` | | Show DC-QoS help. |

### Addon: DC-QoS Combat Log
*Command:* `/dccombat` (Alias: `/dcqoscombat`)

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| *(none)* / `toggle` | | Toggle combat log window. |
| `show` | | Show combat log window. |
| `hide` | | Hide combat log window. |
| `lock` | | Lock/unlock window position. |
| `d` | | Damage mode. |
| `h` | | Healing mode. |
| `s` | | Spell breakdown for your character. |
| `spells` | `<name>` | Spell breakdown for a player. |
| `dispels` | | Show dispel summary. |
| `absorbs` | | Show absorb summary. |
| `activity` | | Show activity/uptime. |
| `kb` | | Show killing blows. |
| `cc` | | Show crowd control. |
| `power` | | Show power gains. |
| `ff` | | Show friendly fire. |
| `consumables` | | Show potion/healthstone usage. |
| `reset` | | Reset combat stats. |
| `death` | | Show death recap. |

### Addon: DC-QoS Frame Mover
*Command:* `/dcmove` (Alias: `/dcm`)

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| *(none)* / `toggle` | | Toggle frame unlock. |
| `editor` | | Toggle editor mode. |
| `grid` | | Toggle grid overlay. |
| `snap` | | Toggle snap to grid. |
| `lock` | | Lock all frames. |
| `unlock` | | Unlock all frames. |
| `reset` | | Reset all frames to defaults. |
| `save` | `<name>` | Save current layout. |
| `load` | `<name>` | Load saved layout. |

### Addon: DC-QoS Nameplates
*Command:* `/dcnameplate` (Alias: `/dcnp`)

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `tank` | | Tank threat mode. |
| `dps` | | DPS/Healer threat mode. |
| `blacklist` | `<aura>` | Add aura to blacklist. |
| `whitelist` | `<aura>` | Add aura to whitelist. |
| `help` | | Show nameplate command help. |

### Addon: DC-QoS Social
*Command:* `/dcfriend`

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| *(none)* | `<playername>` | Add a friend (if empty, uses current player target). |

---

## GM / Administrator Commands

These commands require GM or Administrator access levels.

### General: Addons & XP (`.dc`)
*Command:* `.dc`

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `send` | `<player>` | Send data snapshot to player (Addon sync). |
| `sendforce` | `<player>` | Force send snapshot, bypassing throttles. |
| `sendforce-self` | | Force send snapshot to yourself (bypass throttles). |
| `grant` | `<player> <amount>` | Grant custom XP to a player. |
| `grantself` | `<amount>` | Grant custom XP to self. |
| `givexp` | `<player\|self> <amount>` | Alias for XP granting (same as `grant`/`grantself`). |
| `difficulty` | `<mode>` | Manage/Set dungeon difficulty manually. |
| `reload` | `mythic` | Reload Mythic+ configuration. |
| `info` | `[player]` | Show detailed XP/Addon info for a player. |
| `dedupe` | `[player]` | Show DCRXP deduplication state. |
| `clearflag` | `[player]` | Clear the `PLAYER_FLAGS_NO_XP_GAIN` flag. |
| `partition status` | | Show partition system status and per-partition stats for your current map. Includes per-layer NPC counts by zone. |
| `partition diag` | `[on\|off\|status]` | Toggle or query runtime diagnostics for layer/partition assignment logging. |
| `partition config` | | Display current partition and layer configuration settings. |
| `partition tiles` | | Print ADT tile counts per map and computed partition totals. |
| `layer status` | | Show layer info for your current map/zone (player counts per layer, NPC counts if enabled). |
| `layer` | `<layerId>` | Move yourself to a specific layer ID (requires layering enabled). |
| `layer join` | `<player>` | Join a friend's, guildmate's, or groupmate's layer (WoW-style, with cooldown). |

*Notes:* Layer assignment happens on map entry and zone change. When NPC layering is enabled (`MapPartitions.Layers.IncludeNPCs = 1`), each layer is a completely independent world copy. NPCs are distributed across layers, and pets/guardians/charmed creatures follow the owner's layer.
*Dynamic layering:* New layers are only created when a player is assigned and all existing layers are at capacity, up to `MapPartitions.Layers.Max`.
*Layer switching:* The `.dc layer join` command has escalating cooldowns (1min → 2min → 5min → 10min) to prevent exploit abuse.
*Diagnostics:* When `.dc partition diag` is enabled, per-grid clone spawn summaries are logged. Per-layer clone metrics are controlled by `MapPartitions.Layers.EmitPerLayerCloneMetrics`.
*Relay overflow logging:* All cross-partition relay queues (threat, taunt, proc, aura, path, point, assist, etc.) now emit `LOG_WARN("maps.partition")` when a relay is dropped due to queue capacity (1024). Check server logs for `"relay queue full"` messages to diagnose lost cross-partition events.
*Performance:* Clone spawns for layers > 0 can be skipped in empty zones with `MapPartitions.Layers.SkipClonesIfNoPlayers`.

### System: Dungeon Quests (`.dcquests`)
*Command:* `.dcquests`

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `list` | `[type]` | List loaded quests (types: daily, weekly, dungeon, all). |
| `info` | `<id>` | Show detailed information for a specific quest. |
| `help` | | Show DC dungeon quest command help. |
| `give-token` | `<player> <id> <cnt>` | Give quest tokens to a player. |
| `reward` | `<player> <id>` | Test the reward system for a specific quest. |
| `progress` | `<player> [id]` | Check a player's progress on a quest. |
| `reset` | `<player> [id]` | Reset quest data for a player. |
| `debug` | | Toggle or print debug info for dungeon quest system. |
| `audit` | | Log missing quest mappings and quest_template gaps. |
| `achievement` | `<player> <id>` | Award a custom achievement. |
| `title` | `<player> <id>` | Award a custom title. |

### System: Dungeon Quests (Reload)
*Command:* `.reload dc_dungeon_quests`

Reloads the Universal Quest Master cache (quest mappings, display IDs, daily/weekly lists).

### System: Item Upgrades (`.upgrade`)
*Command:* `.upgrade`

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `mech cost` | `<tier> <level>` | View upgrade costs for specific tier/level. |
| `mech stats` | `<tier> <level>` | View stat bonuses for specific tier/level. |
| `mech ilvl` | `<tier> <level>` | View item level bonuses. |
| `mech reset` | `[player]` | Reset all upgrades for a player. |
| `token add` | `<player> <amt> <type>` | Add upgrade tokens/essence to a player. |
| `token remove` | `<player> <amt> <type>` | Remove tokens from a player. |
| `token set` | `<player> <amt> <type>` | Set a player's token count. |
| `prog unlocktier`| `<player> <tier>` | Force unlock a specific tier for a player. |
| `prog tiercap` | `<tier> <level>` | Set tier cap for the selected player (or self if none selected). |
| `prog testset` | | Grant class test gear + upgrade currency to yourself. |
| `season reset` | `<player>` | Reset a player's seasonal progress. |

### System: Mythic+ (`.mplus`)
*Command:* `.mplus`

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `keystone` | `[level]` | Give yourself a Keystone at the specified level. |
| `give` | `<player> [level]` | Give a player a Keystone. |
| `vault` | `generate/addrun/reset` | Manage Weekly Vault (debug/test). |
| `ks` | `spawn/npcinfo/reward/start` | Manage Keystone NPCs and test runs. |
| `affix` | `[type]` | Test specific affixes on yourself/target. |
| `scaling` | `[level]` | View scaling multipliers for a key level. |
| `season` | `[id]` | Change the active M+ Season. |

### System: Spectator (`.spectate`)
*Command:* `.spectate` (Alias: `.mspec`)

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `stream` | `[mode]` | Set stream privacy mode (0=Normal, 1=Hide Names, 2=Anon). |
| `reload` | | Reload Spectator configuration. |

### System: Hinterland BG (`.hlbg`)
*Command:* `.hlbg`

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `status` | | Show debug status (timers, resources). |
| `get` | `<faction>` | Get resource count for a faction. |
| `set` | `<team> <amt>` | Set resource count (Audited). |
| `reset` | | Force reset the current battle (Audited). |
| `history` | | Show recent battle history/logs. |
| `statsmanual` | `on\|off` | Include/exclude manual resets in stats tracking. |
| `affix` | | Manage battle affixes. |
| `warmup` | | Show warmup phase info. |
| `results` | | Get JSON-formatted results (for testing). |

### System: Guild Housing (Admin) (`.guildhouse` / `.gh`)

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `admin teleport` | `<player>` | Teleport to a player's guild house instance. |
| `admin delete` | `<guild>` | Delete a guild house (GM only). |
| `admin buy` | `<guild>` | Force-buy a guild house for a guild. |
| `admin reset` | `<guild>` | Reset a guild house to defaults. |
| `admin level` | `<guild> [1-4]` | Get or set a guild house level for spawn gating. |

### System: Hotspots (`.hotspot`)
*Command:* `.hotspots` (Alias: `.hotspot`)

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `list` | | List all active hotspots and locations. |
| `spawn` | | Force spawn a new hotspot randomly. |
| `spawnhere` | | Spawn a hotspot at your current location. |
| `dump` | | Dump hotspot data to logs. |
| `clear` | | Clear all active hotspots. |
| `reload` | | Reload hotspot configuration. |
| `tp` | `<id>` | Teleport to a specific hotspot ID. |

### System: Seasonal Rewards (`.season`)
*Command:* `.season`

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `reload` | | Reload seasonal configuration. |
| `info` | | View system configuration info. |
| `stats` | `[player]` | View a player's seasonal stats. |
| `award` | `<pl> <tok> <ess>` | Manually award seasonal currency. |
| `reset` | `<player>` | Reset a player's seasonal data. |
| `setseason` | `<id>` | Manually set the active season ID. |
| `multiplier` | `<type> <val>` | Set global reward multipliers. |

### System: Prestiges (`.prestige`)
*Command:* `.prestige`

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `disable` | `<player>` | Disable prestige Aura/Bonuses on a player. |
| `admin set` | `<player> <lvl>` | Set a player's prestige level. |

### System: AoE Loot (`.aoeloot`)
*Command:* `.aoeloot` (Alias: `.lp`)

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `reload` | | Reload AoE Loot configuration. |

### System: Duels (`.duel`)
*Command:* `.duel`

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `reset` | `<player>` | Reset duel statistics for a player. |
| `reload` | | Reload Phased Duels configuration. |

### System: Stress Testing (`.stresstest`)
*Command:* `.stresstest`

Performance and stress testing tools for diagnosing server performance issues. Most subcommands can be run from console.

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `sql` | | Run SQL stress tests (bulk select, repeated queries, transaction batches). |
| `cache` | | Test ObjectMgr and ItemTemplate cache performance. |
| `systems` | | Run subsystem tests (SpellMgr, WorldPacket, etc.). |
| `coredb` | `[iterations]` | Test core character/world DB query performance. |
| `playersim` | `[playerCount] [includeCore=1|0] [includeVault=1|0]` | Simulate player counts with optional core/vault queries. |
| `stress` | `[baseCount]` | Run heavy load simulations. |
| `dbasync` | `[queries] [concurrency]` | Test async DB burst throughput. |
| `partition` | `[iterations] [detailed] [persist|db] [filters...]` | Layer/partition microbenchmarks. Filters: partition, mixed, relocation, layering, boundary, density, migration, overflow, npc, lookup, layercache, boundarygrid, preload. `persist` enables DB-backed layer persistence during the test (off by default). |
| `path` | `[iterations]` | Test pathfinding performance (requires in-game player). |
| `cpu` | `[iterations]` | Run CPU hot-path benchmark. |
| `mysql` | | Print MySQL connection and performance status. |
| `full` | | Run all stress tests in sequence. |
| `report` | `[suite=full] [topN=10] [details=0|1] [format=chat|json|csv] [suiteArgs...]` | Generate a consolidated report (optionally write JSON/CSV). |
| `loop` | `<suite> [loops=10] [sleepMs=1000] [suiteArgs...]` | Repeat a suite and summarize timings (use `quiet` or `q` to suppress per-loop output). |
| `loopreport` | `<suite> [loops=0] [sleepMs=1000] [topN=10] [details=0|1] [format=json|csv] [suiteArgs...]` | Run repeated suite and write a JSON/CSV loop report (loops=0 means infinite). |

*Suite aliases:* `stress` also accepts `big` in loop/report suites.
*Partition examples:* `.stresstest partition 200000 layer lookup`, `.stresstest partition detailed relocation`, `.stresstest partition 50000 persist`.