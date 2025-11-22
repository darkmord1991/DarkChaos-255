## DarkChaos Commands

### Mythic+ System Commands

#### `.dc` - Main DarkChaos Command Hub (GM-only)
Main command for managing various DC systems. Subcommands include:

- **`.dc send <playername>`** - Send XP addon message to a player
- **`.dc sendforce <playername>`** - Force send XP addon message bypassing checks
- **`.dc sendforce-self`** - Force send XP addon to yourself
- **`.dc grant <playername> <amount>`** - Grant XP to a player (tracked/limited by dedupe system)
- **`.dc grantself <amount>`** - Grant XP to yourself
- **`.dc givexp <playername|self> <amount>`** - Give XP to player or yourself
- **`.dc difficulty <normal|heroic|mythic|info>`** - Check/set dungeon difficulty for your group
  - `normal` - Set to Normal difficulty
  - `heroic` - Set to Heroic difficulty
  - `mythic` - Set to Mythic/Mythic+ difficulty
  - `info` - Show current difficulty, group status, and available commands
- **`.dc reload mythic`** - Reload Mythic+ configuration from config files

#### `.dcrxp` - Legacy Mythic+ XP System (GM-only)
Alias/legacy commands for managing XP. Supports same subcommands as `.dc`:
- `.dcrxp send <playername>`
- `.dcrxp sendforce <playername>`
- `.dcrxp grant <playername> <amount>`
- `.dcrxp grantself <amount>`

**Note:** `.dcxrp` is also accepted as a common typo alias.

---

### Dungeon Quest System Commands

#### `.dcquests` - Dungeon Quest Management (GM-only)
Comprehensive command for managing dungeon quests, tokens, achievements, and debug operations.

**Help & Information:**
- **`.dcquests help`** - Show all available subcommands
- **`.dcquests list [type]`** - List quests by type:
  - `daily` - Daily dungeon quests
  - `weekly` - Weekly raid/challenge quests
  - `dungeon` - Dungeon-specific quests
  - `all` - All quest types (default if no type specified)
- **`.dcquests info <quest_id>`** - Show detailed quest information from database

**Quest Management:**
- **`.dcquests give-token <player> <token_id> [count]`** - Give quest tokens to a player
  - Token IDs: 700001-700005 (Explorer, Specialist, Legendary, Challenge, SpeedRunner)
  - Optional: specify count (default: 1)
- **`.dcquests reward <player> <quest_id>`** - Test/trigger quest reward for a player
- **`.dcquests progress <player> [quest_id]`** - Check quest progress for a player
  - Optional: check specific quest if quest_id provided
- **`.dcquests reset <player> [quest_id]`** - Reset quest progress for a player
  - Optional: reset specific quest if quest_id provided

**Admin & Debug:**
- **`.dcquests debug [on|off]`** - Enable/disable debug logging for all quest events
- **`.dcquests achievement <player> <achievement_id>`** - Award achievement to a player
- **`.dcquests title <player> <title_id>`** - Award title to a player

---

### Hinterland Battleground Commands

#### `.hlbg` - Hinterland Open-World PvP Battleground
Commands for managing the Hinterland (Zone 47) outdoor PvP zone. All administrative actions are logged to `admin.hlbg` category.

**Status & Information:**
- **`.hlbg status`** - Show current timer, resources, and raid group status for both factions
- **`.hlbg get <alliance|horde>`** - Show current resources for a specific faction
- **`.hlbg history [count]`** - Show recent battle history (default: 10 entries)

**Administration (GM-only):**
- **`.hlbg set <alliance|horde> <amount>`** - Manually set resources for a faction (audited)
  - Example: `.hlbg set alliance 500` - Set Alliance resources to 500
- **`.hlbg reset`** - Force-reset the current Hinterland battle, teleporting players and restarting (audited)
- **`.hlbg statsui [season]`** - Get compact stats JSON for UI display (includes per-player stats)
- **`.hlbg statsmanual [on|off]`** - Toggle manual stats refresh mode

**Addon/UI Communication (Player-accessible):**
- **`.hlbg live [players]`** - Get live battle status as compact JSON
- **`.hlbg warmup [text]`** - Get warmup phase information
- **`.hlbg results`** - Get battle results as JSON
- **`.hlbg historyui [page] [per] [season] [sort] [dir]`** - Paginated history for UI display
- **`.hlbg queue join`** - Join the Hinterland battle queue (warmup-only)
- **`.hlbg queue leave`** - Leave the Hinterland battle queue
- **`.hlbg queue status [text]`** - Get queue status and eligibility info

---

### Item Upgrade System Commands

#### `.dcupgrade` - Item Upgrade System (Player-accessible)
Manages item upgrades using the DarkChaos custom item upgrade system.

**Subcommands:**
- **`.dcupgrade init`** - Initialize/sync your item upgrade state
- **`.dcupgrade query`** - Query available upgrades for your current items
- **`.dcupgrade upgrade <item_id>`** - Upgrade a specific item (if available)
- **`.dcupgrade batch <upgrade_type>`** - Batch upgrade multiple items of same type

**Note:** This command communicates between your addon and the server for real-time item upgrade availability and management.

---

### Challenge Mode Commands

#### `.challenge` - Active Challenge Mode Status (Player-accessible)
View your currently active challenge modes and their restrictions.

**Usage:**
- **`.challenge`** - Display all active challenge modes:
  - Hardcore Mode (One Death = Death)
  - Semi-Hardcore Mode (Multiple Lives Allowed)
  - Self-Crafted Mode (Craft Your Own Gear)
  - Item Quality Restrictions (Limited to Green or Better)
  - Slow XP Mode (Reduced Experience)
  - Very Slow XP Mode (Minimal Experience)
  - Quest XP Only Mode (No Mob Experience)
  - Iron Man Mode (Combined restrictions)

Shows colorized status for each active mode with restrictions/details.

---

### Additional Commands

#### `.givexp` - Direct XP Grant (GM-only)
Quick command to grant XP to yourself or another player.

- **`.givexp <playername> <amount>`** - Give XP to a specific player
- **`.givexp self <amount>`** - Give XP to yourself

---