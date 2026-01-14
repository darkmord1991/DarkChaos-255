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
| `replay` | `<id>` | Watch a replay (Note: requires being in the instance). |

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

### System: Guild Housing
*Command:* `.guildhouse` (Alias: `.gh`)

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `teleport` | | Teleport to your customized Guild House instance. |
| `butler` | | Spawn your Guild House Butler (requires Master). |
| `info` | | View instance information (Phase, Map, Coordinates). |
| `members` | | List all guild members currently inside the Guild House. |

### System: Hotspots
*Command:* `.hotspot` (Alias: `.hotspots`)

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `status` | | Check if you are currently standing in an active XP Hotspot. |

---

## GM / Administrator Commands

These commands require GM or Administrator access levels.

### General: Addons & XP (`.dc`)
*Command:* `.dc`

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `send` | `<player>` | Send data snapshot to player (Addon sync). |
| `sendforce` | `<player>` | Force send snapshot, bypassing throttles. |
| `grant` | `<player> <amount>` | Grant custom XP to a player. |
| `grantself` | `<amount>` | Grant custom XP to self. |
| `difficulty` | `<mode>` | Manage/Set dungeon difficulty manually. |
| `reload` | `mythic` | Reload Mythic+ configuration. |
| `info` | `[player]` | Show detailed XP/Addon info for a player. |
| `dedupe` | `[player]` | Show DCRXP deduplication state. |
| `clearflag` | `[player]` | Clear the `PLAYER_FLAGS_NO_XP_GAIN` flag. |

### System: Dungeon Quests (`.dcquests`)
*Command:* `.dcquests`

| Subcommand | Arguments | Description |
| :--- | :--- | :--- |
| `list` | `[type]` | List loaded quests (types: daily, weekly, dungeon, all). |
| `info` | `<id>` | Show detailed information for a specific quest. |
| `give-token` | `<player> <id> <cnt>` | Give quest tokens to a player. |
| `reward` | `<player> <id>` | Test the reward system for a specific quest. |
| `progress` | `<player> [id]` | Check a player's progress on a quest. |
| `reset` | `<player> [id]` | Reset quest data for a player. |
| `achievement` | `<player> <id>` | Award a custom achievement. |
| `title` | `<player> <id>` | Award a custom title. |

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
| `prog tiercap` | `<tier> <level>` | View or set the global tier cap. |
| `prog testset` | | Run the upgrade test set suite. |
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
| `affix` | | Manage battle affixes. |
| `warmup` | | Show warmup phase info. |
| `results` | | Get JSON-formatted results (for testing). |

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
| `stress` | | Run general stress tests. |
| `dbasync` | `[iterations]` | Test async database query throughput. |
| `path` | `[iterations]` | Test pathfinding performance (requires player context). |
| `cpu` | | Run CPU benchmark tests. |
| `loop` | `<seconds>` | Start a loop test that runs for the specified duration. |
| `loopreport` | | Print the results of the last loop test. |
| `mysql` | | Print MySQL connection and performance status. |
| `full` | | Run all stress tests in sequence. |
| `report` | `[file]` | Generate and optionally save a full performance report. |