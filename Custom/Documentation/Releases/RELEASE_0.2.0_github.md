The largest content release Dark Chaos has shipped: **19 new maps**, five new dungeons, four new raids, two new levelling continents, a guild-housing overhaul and a rebuilt collections stack.

## 🔗 Links

| | |
|---|---|
| 💬 **Discord** — questions, feedback, criticism or help | https://discord.gg/pNddMEMbb2 |
| 📦 **MPQ patch files** | [OneDrive](https://1drv.ms/f/c/d9368532fb96da3d/IgDWzxIEoSw5QJtxZbkKoJiyATJsWKfaVaHGfGsm-B2MOLs?e=McS0Co) |

## ⚙️ Installation

> [!NOTE]
> You have to compile the server yourself — follow the [AzerothCore installation guide](https://www.azerothcore.org/wiki/installation). The database structure is unchanged from AzerothCore, so all of their tooling works as-is.

Two accounts plus an AH bot (id 1) are created for you:

| Account | Password | Role |
|---|---|---|
| `testtest` | `test` | Admin in-game |
| `test` | `test` | Player |

Drop the MPQ files from the link above into your client's `Data/` folder.

---

## ✨ Highlights

- **Cataclysm's Hyjal (80–130)**, the **Molten Front**, **Deepholm** and a rebuilt **Plaguelands** open as levelling ground.
- **Blackwing Descent**, **Castle Nathria** and a **40-man Naxxramas** open at the top.
- **Mythic+** got a proper in-game panel, keystone tracking and a reworked end-of-run.
- **1,526 mounts** and **1,898 pets** collectible, now account-wide alongside achievements and reputation.
- **Guild houses** are instanced, with a full decoration system.

---

## 🗺️ New Zones

| Zone | Levels | What it is |
|---|---|---|
| **Mount Hyjal** | 80–130 | The full Cataclysm Hyjal downport — Nordrassil, the Sanctuary of Malorne, the Firelands Forgeworks and the Hyjal Frontier. Flight masters, taxi routes, escort quests, world map and skybox all wired up. |
| **The Molten Front** | 85+ | The Firelands daily hub, with its quest chain, curated spawns and a portal from Hyjal. |
| **Plaguelands** | 60–80 | A rebuilt Eastern and Western Plaguelands with the Blackhowl garrison, cauldron quest support and flight masters. |
| **Deepholm** | 82+ | Cataclysm's elemental plane, with its vendor and quest layers. |
| **Azshara (Cataclysm)** | levelling | The revamped terrain with the goblin choreography events, plus breadcrumbs and portals through to Azshara Crater. |
| **Darkshore & Felwood (Cataclysm)** | levelling | Post-Shattering versions of both zones, with escort quests and restored NPCs. |
| **Giant Isles** | endgame | The War Economy quartermaster, invasion events, the Primal Cook fish exchange and the Hydra Drum summon. |

---

## ⚔️ New Dungeons & Raids

### Raids

- **Blackwing Descent** — all six encounters: Magmaw, the Omnotron Defense System, Maloriak, Atramedes, Chimaeron and Nefarian's End.
- **Castle Nathria** — the full ten-boss Shadowlands raid, from Shriekwing through to Sire Denathrius, including Sun King's Salvation and the Council of Blood. Trash loot, readable page texts and missing item entries all filled in.
- **Timbermaw Hold** — a new custom raid.
- **Naxxramas (40-man)** — the classic raid restored on its own map, gated behind an attunement.

### Dungeons

- **Shadowfang Keep (Cataclysm)** — the revamped version, with Lupine Spectres and walk-through portal triggers.
- **Stratholme** and **Scholomance** — reworked DarkChaos versions on dedicated maps, with portal triggers between wings.
- **Blackfathom Deeps (Ashenvale)** — the revamped Blackfathom, with its own quest and NPC layers.
- **Crescent Grove** and **Emerald Sanctum** — imported custom dungeons. The Emerald Sanctum entrance sits at the moon gate.
- **Karazhan Crypts** — registered with a teleport entry, but not yet populated.

---

## 📈 Progression & Endgame

- **Mythic+ overhaul** — a dedicated in-game panel with keystone info, per-boss checklists, live session tracking and a HUD. Difficulty is now selectable directly in the dungeon queue, runs open with a ready-check countdown, and end-of-run loot and summary were reworked.
- **Great Vault** — weekly vault rewards are now claimed through the addon UI.
- **Item Upgrades** — reworked from top to bottom:
  - Tiers 1–10, with per-tier stat-bonus caps read from the database instead of hardcoded values.
  - **Emberwood Sap**, a new Hyjal Frontier zone currency, now pays for tier 4 and tier 5. It is *not* affected by the seasonal-currency switch.
  - Refunds return the currency that was actually paid for that tier.
  - Upgrading is blocked in combat.
- **Heirlooms** — upgrade system and costs reworked, plus new heirloom bag tiers that scale properly.
- **Item set bonuses** — Cataclysm-era item sets now grant their set bonuses.
- **World bosses** — per-player loot lockouts with a grace period, and phase-on-engage so a boss belongs to the group fighting it.
- **Rest areas** — health and mana regenerate faster while rested.
- **Seasons** — a weekly token cap is now enforced, and the seasonal stat and reward queries were optimised.

---

## 🐉 Collections & Cosmetics

- **Mounts** — batches 3 through 8 downported from retail, bringing the catalogue to **1,526 collectible mounts**. Multi-seat mounts now carry passengers, dedicated mount vendors were added, and the catalogue got a cleanup pass: duplicates removed, the missing Acherus mount restored, stock display IDs corrected.
- **Pets** — the companion roster was rebuilt from retail's species data to **1,898 pets**, with colour variants, 1,847 backfilled icons, and rarity re-derived from retail cage quality. Pets can now be dragged onto the action bar, the same as mounts.
- **Shapeshift form customisation** — a catalogue of druid, shaman and warlock forms and totem skins, with a 3D preview.
- **Weapon enchant visuals** — a wardrobe for weapon illusions.
- **Beastmaster catalogue** — a browsable hunter pet catalogue, including secret pets with their own models and stats.
- **Account-wide collections** — collectibles, achievements and reputation now pool across your whole account.

---

## 🏰 Guild Housing

- **Instanced guild houses** — guild houses now run as dynamically managed instances rather than shared world space.
- A second Dalaran guild house map, rebuilt with exact NPC placements, working well teleporters and Underbelly fix-ups.
- **Decorations** — per-decoration scaling, a placement range limit, a refund policy on removal, and a reset-everything command.

---

## 🧭 World & Quality of Life

- **Rare spawns** — rares are pooled and tracked, and the server announces one when it appears.
- **Hotspots** — the dynamic hotspot system now keeps per-player state and can be scoped to specific maps and zones.
- **New-player onboarding** — a welcome quest chain, a systems primer, a Hyjal call-to-adventure, a newcomer chat channel, starter tokens, a mobile teleporter and automatic starter-guild placement. Intro quests now walk you through Mythic+, item upgrades, heirloom upgrades, guild housing and the teleporters.
- **Quest flow** — automatic offer and completion popups, quest-navigation sync, and clearer reward text.
- **Map POIs** — flight masters and other server-fed points of interest now appear on the world map and the minimap.
- **Death markers** — your corpse is marked on the map, and there's a retail-style Return to Graveyard button.
- **Lootable sparkles** — lootable objects sparkle the way they do on retail.
- **Boss tracker** — a retail-style objective tracker for dungeon and raid bosses, with a per-boss checklist during Mythic+ runs.
- **DC-Journal** — a new in-game journal addon.
- **Tooltips** — item comparison in tooltips, with optional inline colouring of values.
- **Login screen** — Legion-styled main menu art, with Discord and bug tracker buttons.
- **Spectating** — one unified spectator core now backs both arenas and Hinterland BG.

---

## 🧬 Races & Characters

- **Allied races** — Vulpera, Zandalari and Kul Tiran have their racial spells; Kul Tiran and Vulpera have their languages.
- **Worgen and Goblin** are playable, with character-creation models and ambience.
- **Pandaren** character data groundwork is in place.
- Custom-race display IDs were widened so high-ID custom models render correctly.

---

## 🔧 Fixes

- The looter pet now returns to its owner after a loot walk, and no longer breaks under concurrent map updates.
- Corrected the kill credit on Noxious Assassin (Plaguelands) and the loot table on Flamewaker Shaman (Castle Nathria).
- Removed a duplicate mount and restored the missing Acherus mount.
- Hyjal: resolved script-name conflicts, restored missing action lists, creature texts and graduation spells, and fixed out-of-bounds objects and flight master defects.
- Fixed broken quest chain references, and added missing quest reward items and vendor stock for Deepholm and Legion Dalaran.
- Model loading now validates file headers, and collision extraction no longer writes invalid bounds for geometry-less models.
- Addon message flooding is now throttled, with anti-flood policies on the custom opcodes.

---

## 🚧 Registered but not finished

These maps exist and are reachable, but are not content-complete yet — expect empty space.

| Map | State |
|---|---|
| **Pandaria** | Map and world-map art registered, essentially unpopulated. |
| **Undermine** | Groundwork only. |
| **Karazhan Crypts**, **Level Zones** | Registered, no content behind them. |
| **Timbermaw Hold**, **Crescent Grove**, **Emerald Sanctum** | Encounters are scripted, but the spawn layers are still near-empty. |

---

## ⬆️ Upgrading from 0.1.5

> [!IMPORTANT]
> A **full rebuild** is required — DBC layout, the script loader and shared headers all changed.

1. Apply the world and character SQL, then rebuild and deploy the DBCs.
2. Install the new MPQ patch files (the chain now runs through `patch-H.MPQ`).
3. Restart the world server **before** handing out the updated client addons — collection definitions carry a data revision, and clients will hold stale data otherwise.
4. Merge the **94 new options** from `darkchaos-custom.conf.dist` into your live config.
5. Re-run map/vmap/mmap extraction. The extractor was fixed this cycle; pre-0.1.5 output will not contain the new maps.

**Client addons** — new: `DC-Journal`, `DC-JournalData`, `DC-Housing`, `DC-DangerZone`, `DC-AddonProtocolUI`, `DC-PortraitCapture`, `DC_DebugUtils`, `AzerothAdmin_Models`. Removed: `AIO_Client`, `Mapster`, `WDM`, `Transmogrification`.

---

Synced with AzerothCore master through 28 August 2026, including **ACDB 16.0.0**.

**Full changelog:** https://github.com/darkmord1991/DarkChaos-255/compare/0.1.5...0.2.0
