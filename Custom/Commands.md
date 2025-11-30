# DarkChaos Commands Reference

A comprehensive reference for all DarkChaos (DC) custom commands available in the server.

---

## Table of Contents

1. [Player Commands](#player-commands)
   - [Challenge Mode](#challenge-mode-commands)
   - [Prestige System](#prestige-system-commands)
   - [Item Upgrades](#item-upgrade-commands-player)
   - [Loot Preferences](#loot-preference-commands)
   - [Dueling](#duel-commands)
   - [M+ Spectator](#mythic-spectator-commands-player)
   - [Dungeon Quests](#dungeon-quest-commands)
   - [AoE Loot](#aoe-loot-commands)
   - [Hotspots](#hotspot-commands-player)
   - [Seasons](#season-commands-player)
   - [Hinterland BG](#hinterland-bg-commands-player)
2. [GM/Admin Commands](#gmadmin-commands)
   - [Mythic+ Administration](#mythic-commands)
   - [Item Upgrade Administration](#item-upgrade-commands-admin)
   - [Hotspots Administration](#hotspot-commands-admin)
   - [Season Administration](#season-commands-admin)
   - [Prestige Administration](#prestige-commands-admin)
   - [Hinterland BG Administration](#hinterland-bg-commands-admin)
   - [Debug/Utility Commands](#debug-and-utility-commands)

---

## Player Commands

### Challenge Mode Commands

#### `.challenge` - View Active Challenge Modes
Shows all currently active challenge modes for your character.

**Access Level:** Player  
**Aliases:** None

**Output includes:**
- **Hardcore Mode** - One life only (death = deletion)
- **Semi-Hardcore Mode** - Death = gear loss
- **Self-Crafted Mode** - Can only use crafted gear
- **Item Quality Restrictions** - Limited to certain quality items
- **Slow XP Mode** - Reduced experience gain
- **Very Slow XP Mode** - Minimal experience gain
- **Quest XP Only Mode** - No experience from mob kills
- **Iron Man Mode** - Combined restrictions

---

### Prestige System Commands

#### `.prestige` - Prestige System Hub

| Command | Description | Access |
|---------|-------------|--------|
| `.prestige info` | Show your current prestige level, XP, and benefits | Player |
| `.prestige reset` | Initiate prestige reset (requires confirmation) | Player |
| `.prestige confirm` | Confirm pending prestige reset | Player |
| `.prestige challenge start <name>` | Start a prestige challenge | Player |
| `.prestige challenge status` | View active challenge progress | Player |
| `.prestige challenge list` | List available challenges | Player |
| `.prestige altbonus info` | View alt character bonuses from main's prestige | Player |

**Prestige Benefits:**
- Bonus XP rates
- Special titles
- Cosmetic rewards
- Alt character bonuses

---

### Item Upgrade Commands (Player)

#### `.dcupgrade` - Item Upgrade System
Addon-integrated command for managing item upgrades.

| Command | Description | Access |
|---------|-------------|--------|
| `.dcupgrade init` | Initialize/sync upgrade state with addon | Player |
| `.dcupgrade query` | Query available upgrades for equipped items | Player |
| `.dcupgrade upgrade <item_id>` | Upgrade a specific item | Player |
| `.dcupgrade batch <upgrade_type>` | Batch upgrade multiple items | Player |

**Note:** These commands communicate with the DC-ItemUpgrade addon for real-time upgrade availability.

#### `.upgradeprog` - Upgrade Progression

| Command | Description | Access |
|---------|-------------|--------|
| `.upgradeprog mastery` | View artifact mastery progress | Player |
| `.upgradeprog weekcap` | View weekly upgrade cap status | Player |

#### `.upgradeadv` - Advanced Upgrades

| Command | Description | Access |
|---------|-------------|--------|
| `.upgradeadv respec` | View respec cooldown or initiate respec | Player |
| `.upgradeadv achievements` | View upgrade-related achievements | Player |
| `.upgradeadv guild` | View guild upgrade statistics | Player |

#### `.upgradeseason` - Seasonal Upgrades

| Command | Description | Access |
|---------|-------------|--------|
| `.upgradeseason info` | View current season information | Player |
| `.upgradeseason leaderboard` | View upgrade leaderboards | Player |
| `.upgradeseason history` | View your seasonal upgrade history | Player |

---

### Loot Preference Commands

#### `.lootpref` / `.lp` - Loot Preferences
Manage your AoE loot preferences and smart looting settings.

| Command | Description | Access |
|---------|-------------|--------|
| `.lootpref toggle` or `.lp toggle` | Toggle AoE loot on/off | Player |
| `.lootpref enable` | Enable AoE loot | Player |
| `.lootpref disable` | Disable AoE loot | Player |
| `.lootpref messages` or `.lp msg` | Toggle loot messages | Player |
| `.lootpref quality` | Set minimum quality filter (0-6) | Player |
| `.lootpref skin` | Toggle auto-skinning | Player |
| `.lootpref skinset <0/1>` | Set skinning preference | Player |
| `.lootpref smart` | Toggle smart vendor trash handling | Player |
| `.lootpref smartset <0/1>` | Set smart loot preference | Player |
| `.lootpref ignore` | Add target item to ignore list | Player |
| `.lootpref unignore` | Remove item from ignore list | Player |
| `.lootpref stats` | View your loot statistics | Player |

**Quality Levels:**
- 0 = Poor (Gray)
- 1 = Common (White)
- 2 = Uncommon (Green)
- 3 = Rare (Blue)
- 4 = Epic (Purple)
- 5 = Legendary (Orange)
- 6 = Artifact (Red)

---

### Duel Commands

#### `.duel` - Phased Duel System
View duel statistics and rankings.

| Command | Description | Access |
|---------|-------------|--------|
| `.duel stats [player]` | View duel statistics for yourself or target | Player |
| `.duel top` | View top duelists leaderboard | Player |

---

### Mythic+ Spectator Commands (Player)

#### `.spectate` / `.mspec` - M+ Spectator Mode
Watch ongoing Mythic+ dungeon runs.

| Command | Description | Access |
|---------|-------------|--------|
| `.spectate list` | List available M+ runs to spectate | Player |
| `.spectate join <run_id>` | Join spectating a run by ID | Player |
| `.spectate code <access_code>` | Join with private access code | Player |
| `.spectate player <name>` | Spectate a specific player's run | Player |
| `.spectate watch <name>` | Switch to watching another player in the run | Player |
| `.spectate leave` | Leave spectator mode | Player |
| `.spectate invite <player>` | Invite a player to spectate your run | Player |
| `.spectate guild` | Toggle guild-only spectating for your run | Player |
| `.spectate replays` | List available replay recordings | Player |
| `.spectate replay <id>` | Watch a saved replay | Player |

---

### Dungeon Quest Commands

#### `.dcquest` - Dungeon Quest Master
Summon or dismiss the mobile quest master NPC.

| Command | Description | Access |
|---------|-------------|--------|
| `.dcquest summon` | Summon the quest master NPC to your location | Player |
| `.dcquest dismiss` | Dismiss the quest master NPC | Player |

**Note:** Cannot be used while in combat.

---

### AoE Loot Commands

#### `.aoeloot` - AoE Loot Base System
Core AoE loot system commands.

| Command | Description | Access |
|---------|-------------|--------|
| `.aoeloot info` | Show current AoE loot settings | Player |
| `.aoeloot messages` | Toggle loot summary messages | Player |
| `.aoeloot top` | View top AoE looters | Player |

---

### Hotspot Commands (Player)

#### `.hotspots` / `.hotspot` - XP Bonus Hotspots

| Command | Description | Access |
|---------|-------------|--------|
| `.hotspots status` | Show if you're in an active hotspot | Player |
| `.hotspots bonus` | Show your current hotspot XP bonus | Player |

---

### Season Commands (Player)

#### `.season chest` - Seasonal Reward Chest
Claim your seasonal reward chest (if eligible).

| Command | Description | Access |
|---------|-------------|--------|
| `.season chest` | Check/claim your seasonal reward chest | Player |

---

### Hinterland BG Commands (Player)

#### `.hlbg queue` - Hinterland Queue
Join or manage your Hinterland Battleground queue.

| Command | Description | Access |
|---------|-------------|--------|
| `.hlbg queue join` | Join the Hinterland battle queue | Player |
| `.hlbg queue leave` | Leave the queue | Player |
| `.hlbg queue status` | Check your queue status | Player |
| `.hlbg live [players]` | Get live battle status (JSON for addon) | Player |
| `.hlbg historyui [page]` | Get paginated battle history (for addon) | Player |
| `.hlbg statsui [season]` | Get compact stats JSON (for addon) | Player |

**Queue Requirements:**
- Must be max level
- Must be alive and out of combat
- Cannot have Deserter debuff
- Cannot be in dungeon/raid/BG
- Queue only available during warmup phase

---

## GM/Admin Commands

### Mythic+ Commands

#### `.mplus` - Mythic+ Management

| Command | Description | Access |
|---------|-------------|--------|
| `.mplus info` | View current M+ run information | Player |
| `.mplus cancel` | Cancel current M+ run | Player |
| `.mplus keystone [level]` | Give yourself a keystone (2-30) | GM |
| `.mplus give <player> [level]` | Give a player a keystone | GM |
| `.mplus vault` | Open the Great Vault UI | GM |
| `.mplus affix` | View current weekly affixes | GM |
| `.mplus scaling` | View M+ scaling information | GM |
| `.mplus season` | View current M+ season | GM |

#### `.keystone` - Keystone Admin (Separate Command Tree)

| Command | Description | Access |
|---------|-------------|--------|
| `.keystone spawn <level>` | Spawn a keystone NPC at your location | GM |
| `.keystone info` | View keystone debug information | GM |
| `.keystone reward` | Test keystone reward distribution | GM |
| `.keystone start` | Force start a keystone run | GM |

#### `.spectate` - Spectator Admin

| Command | Description | Access |
|---------|-------------|--------|
| `.spectate stream` | Toggle streaming mode for broadcasts | Moderator |
| `.spectate reload` | Reload spectator configuration | Admin |

---

### Item Upgrade Commands (Admin)

#### `.upgrade` - Upgrade Token Management

| Command | Description | Access |
|---------|-------------|--------|
| `.upgrade status` | View upgrade system status | GM |
| `.upgrade list` | List all upgrade tiers and costs | GM |
| `.upgrade info` | View detailed upgrade information | GM |
| `.upgrade token add <player> <amount> [type]` | Add tokens to player | GM |
| `.upgrade token remove <player> <amount> [type]` | Remove tokens from player | GM |
| `.upgrade token set <player> <amount> [type]` | Set player token count | GM |
| `.upgrade token info <player>` | View player token information | GM |
| `.upgrade mech cost <tier> <level>` | View upgrade costs | Admin |
| `.upgrade mech stats <tier> <level>` | View stat bonuses | Admin |
| `.upgrade mech ilvl <tier> <level>` | View iLvl bonuses | Admin |
| `.upgrade mech reset [player]` | Reset a player's upgrades | Admin |

**Token Types:**
- `upgrade_token` - Standard upgrade tokens
- `artifact_essence` - Artifact essence currency

#### `.upgradeprog` - Progression Admin

| Command | Description | Access |
|---------|-------------|--------|
| `.upgradeprog unlocktier <player> <tier>` | Unlock upgrade tier for player | GM |
| `.upgradeprog tiercap <tier> <level>` | View/set tier cap | GM |
| `.upgradeprog testset` | Run upgrade test set | GM |

#### `.upgradeseason` - Season Admin

| Command | Description | Access |
|---------|-------------|--------|
| `.upgradeseason reset <player>` | Reset player's seasonal progress | Admin |

---

### Hotspot Commands (Admin)

#### `.hotspots` / `.hotspot` - Hotspot Management

| Command | Description | Access |
|---------|-------------|--------|
| `.hotspots list` | List all active hotspots | GM |
| `.hotspots spawn` | Spawn a hotspot | Admin |
| `.hotspots spawnhere` | Spawn hotspot at your location | Admin |
| `.hotspots spawnworld` | Spawn a world-wide hotspot | Admin |
| `.hotspots testmsg` | Test hotspot messaging | GM |
| `.hotspots testpayload` | Test addon payload | GM |
| `.hotspots testxp` | Test XP bonus calculation | GM |
| `.hotspots setbonus <zone> <bonus>` | Set zone XP bonus | Admin |
| `.hotspots addonpackets` | Toggle addon debug packets | Admin |
| `.hotspots dump` | Dump hotspot data | Admin |
| `.hotspots clear` | Clear all active hotspots | Admin |
| `.hotspots reload` | Reload hotspot configuration | Admin |
| `.hotspots tp <hotspot_id>` | Teleport to a hotspot | GM |
| `.hotspots forcebuff` | Force apply hotspot buff | Admin |

---

### Season Commands (Admin)

#### `.season` - Seasonal Rewards Administration

| Command | Description | Access |
|---------|-------------|--------|
| `.season info` | View current season information | GM |
| `.season stats [player]` | View player seasonal statistics | GM |
| `.season reload` | Reload seasonal configuration | Admin |
| `.season award <player> <type> <amount>` | Award seasonal currency | Admin |
| `.season reset <player>` | Reset player's seasonal progress | Admin |
| `.season setseason <id>` | Change active season | Admin |
| `.season multiplier <type> <value>` | Set reward multipliers | Admin |

---

### Prestige Commands (Admin)

#### `.prestige` - Prestige Administration

| Command | Description | Access |
|---------|-------------|--------|
| `.prestige disable <player>` | Disable prestige for a player | Admin |
| `.prestige admin <subcommand>` | Administrative prestige commands | Admin |

---

### Hinterland BG Commands (Admin)

#### `.hlbg` - Hinterland BG Administration

| Command | Description | Access |
|---------|-------------|--------|
| `.hlbg status` | Show timer, resources, raid group status | GM |
| `.hlbg get <alliance\|horde>` | Show faction resources | GM |
| `.hlbg set <alliance\|horde> <amount>` | Set faction resources (audited) | GM |
| `.hlbg reset` | Force-reset the current battle (audited) | GM |
| `.hlbg history [count]` | Show recent battle history | GM |
| `.hlbg statsmanual [on\|off]` | Toggle manual stats refresh | GM |
| `.hlbg affix` | View/manage battle affixes | GM |
| `.hlbg warmup` | Get warmup phase information | GM |
| `.hlbg results` | Get battle results (JSON) | GM |
| `.hlbglive native` | Get native broadcast data | GM |

**Audit Logging:** All `.hlbg set` and `.hlbg reset` commands are logged to `admin.hlbg` with GM name and GUID.

---

### Debug and Utility Commands

#### `.gpstest` - GPS Diagnostic
Test GPS and location diagnostics.

| Command | Description | Access |
|---------|-------------|--------|
| `.gpstest` | Show detailed position, map, zone, area info | Moderator |

#### `.flighthelper` - Flight Path Helper

| Command | Description | Access |
|---------|-------------|--------|
| `.flighthelper path <x> <y> <z>` | Create flight path to coordinates | GM |

#### `.aio` - AIO Bridge

| Command | Description | Access |
|---------|-------------|--------|
| `.aio ping` | Test AIO addon bridge connection | Player |

#### `.checkachievements` - Achievement Debug

| Command | Description | Access |
|---------|-------------|--------|
| `.checkachievements` | Debug achievement store entries | Admin |

---

## Legacy/Alias Commands

### `.dc` - Main DarkChaos Command Hub (GM-only)
Main command for managing various DC systems.

| Command | Description | Access |
|---------|-------------|--------|
| `.dc send <player>` | Send XP addon message to a player | GM |
| `.dc sendforce <player>` | Force send XP addon message | GM |
| `.dc sendforce-self` | Force send XP addon to yourself | GM |
| `.dc grant <player> <amount>` | Grant XP to a player | GM |
| `.dc grantself <amount>` | Grant XP to yourself | GM |
| `.dc givexp <player\|self> <amount>` | Give XP to player or yourself | GM |
| `.dc difficulty <mode>` | Check/set dungeon difficulty | GM |
| `.dc reload mythic` | Reload Mythic+ configuration | GM |

**Difficulty modes:** `normal`, `heroic`, `mythic`, `info`

### `.dcrxp` / `.dcxrp` - Legacy XP System
Alias/legacy commands for XP management. Same subcommands as `.dc`.

### `.givexp` - Direct XP Grant
| Command | Description | Access |
|---------|-------------|--------|
| `.givexp <player> <amount>` | Give XP to a specific player | GM |
| `.givexp self <amount>` | Give XP to yourself | GM |

### `.dcquests` - Dungeon Quest Management (GM-only)

| Command | Description | Access |
|---------|-------------|--------|
| `.dcquests help` | Show all available subcommands | GM |
| `.dcquests list [type]` | List quests (daily/weekly/dungeon/all) | GM |
| `.dcquests info <quest_id>` | Show detailed quest information | GM |
| `.dcquests give-token <player> <token_id> [count]` | Give quest tokens | GM |
| `.dcquests reward <player> <quest_id>` | Test/trigger quest reward | GM |
| `.dcquests progress <player> [quest_id]` | Check quest progress | GM |
| `.dcquests reset <player> [quest_id]` | Reset quest progress | GM |
| `.dcquests debug [on\|off]` | Toggle debug logging | GM |
| `.dcquests achievement <player> <id>` | Award achievement | GM |
| `.dcquests title <player> <id>` | Award title | GM |

---

## Addon Integration Notes

### DC-ItemUpgrade Addon
Commands prefixed with `.dcupgrade` communicate via addon messages using the `DCUPGRADE_*` protocol.

**Responses:**
- `DCUPGRADE_INIT:<tokens>:<essence>:<tokenId>:<essenceId>`
- `DCUPGRADE_QUERY:<itemGUID>:<level>:<tier>:<baseIlvl>:<cost>:<name>`
- `DCUPGRADE_ERROR:<message>`

### Hinterland BG Addon (HLBG)
Commands under `.hlbg` use `[HLBG_*]` prefixed messages for addon communication.

**Protocol Prefixes:**
- `[HLBG_LIVE_JSON]` - Live battle data
- `[HLBG_HISTORY_TSV]` - Battle history
- `[HLBG_STATS_JSON]` - Statistics
- `[HLBG_QUEUE]` - Queue status

### Mythic+ Spectator
Uses `DCSPEC*` prefixed messages for spectator addon integration.

---

## Security Levels Reference

| Level | Name | Description |
|-------|------|-------------|
| 0 | Player | Normal players |
| 1 | Moderator | Community moderators |
| 2 | GM | Game Masters |
| 3 | Admin | Server Administrators |

---

## Quick Reference Card

### Most Common Player Commands
```
.challenge              - View active challenge modes
.prestige info          - View prestige status
.dcupgrade init         - Sync item upgrade addon
.lp toggle              - Toggle AoE loot
.lp quality 2           - Set minimum loot quality to Uncommon
.duel stats             - View your duel statistics
.spectate list          - List M+ runs to watch
.dcquest summon         - Summon quest master NPC
.hlbg queue join        - Join Hinterland BG queue
.aoeloot info           - View AoE loot settings
.hotspots status        - Check if in a hotspot
```

### Most Common GM Commands
```
.mplus keystone 10      - Give yourself a +10 key
.hlbg status            - View Hinterland BG status
.hotspots list          - List active hotspots
.season info            - View season information
.upgrade token add X 100 - Give player 100 tokens
```

---

*Last Updated: 2025*  
*DarkChaos WoW 3.3.5a Server*