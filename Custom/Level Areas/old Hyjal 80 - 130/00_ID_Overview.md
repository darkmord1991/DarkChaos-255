# Hyjal Frontier (80–130) — ID Overview

Authoritative, granular map of every ID the Hyjal Frontier SQL set
allocates, grouped by table. Use this as the single source of truth when
adding new content so ranges don't collide. The high-level locked ranges
live in [README.md](README.md); this file expands them to the individual
row level and records the schema-validation status.

Map: **1410** (`Hyjal130`, continent, InstanceType=0). Zone root **6100**
`Hyjal Frontier`; sub-zones **6101–6106**.

> Validation status (2026-05-31): every table and column used below was
> checked against the AzerothCore base schema in
> `data/sql/base/db_world/` — **all 17 tables and all referenced columns
> exist** (see [§12](#12-schema-validation)). Live-database checks were
> run against `acore_world` via the `acmcp` MCP server and are recorded in
> [§13](#13-live-check-results-via-acmcp) — all cloned source rows resolve
> fully, **but a critical spawn-GUID collision was found and fixed** (the
> spawn block moved from `9001700+` to the free `9010000+` block).

---

## 1. Map / zone / instance

| ID | Kind | Name | Source |
|---|---|---|---|
| 1410 | Map | `Hyjal130` / Hyjal Frontier | `01_Instance_template.sql` |
| 1408 | Map | `Sunwell130` (event map, populated later) | (external) |
| 6100 | Zone | Hyjal Frontier (root) | DBC `AreaTable.csv` |
| 6101 | Sub-zone | Foothills | DBC |
| 6102 | Sub-zone | Scorched Groves | DBC |
| 6103 | Sub-zone | The Summit | DBC |
| 6104 | Sub-zone | Nordrassil Roots | DBC |
| 6105 | Sub-zone | Jaina's Encampment (Alliance base) | DBC |
| 6106 | Sub-zone | Thrall's Vanguard (Horde base) | DBC |

`instance_template`: one row — `map=1410, parent=0, script='', allowMount=1`.

---

## 2. World locations

### game_graveyard (`02_Graveyards.sql`) — IDs 15000–15003
| ID | Map | Serves | Comment |
|---|---|---|---|
| 15000 | 1410 | Foothills (6101), Jaina's Encampment (6105) | Jaina's Encampment |
| 15001 | 1410 | Foothills Horde (6101, faction 67), Thrall's Vanguard (6106) | Thrall's Vanguard |
| 15002 | 1410 | Scorched Groves (6102) | Groves outpost |
| 15003 | 1410 | Summit (6103), Nordrassil Roots (6104) | Nordrassil Roots |

`graveyard_zone` reuses graveyard IDs 15000/15001 across multiple
`GhostZone`s — valid; the PK is `(ID, GhostZone)`.

### game_tele (`03_Game_tele.sql`) — IDs 1495–1500 (1497 unused)
| ID | Name | Map |
|---|---|---|
| 1495 | HyjalFrontier | 1410 |
| 1496 | HyjalFoothillsAlliance | 1410 |
| 1498 | HyjalScorchedGroves | 1410 |
| 1499 | HyjalTheSummit | 1410 |
| 1500 | HyjalNordrassil | 1410 |

> Note: `1497` is skipped (gap). `HyjalFrontier` (1495) z-coord was a typo
> (`9425.0`) — **fixed to `942.5`** in `03_Game_tele.sql` (matches the
> entry-portal target z≈942). The live row was already applied with the
> bad value; re-apply `03` or run
> `UPDATE game_tele SET position_z=942.5 WHERE id=1495;` to correct it live.

### areatrigger_teleport (`04_Areatriggers.sql`) — IDs 15000–15001
| ID | Direction | Target map |
|---|---|---|
| 15000 | Entry portal from Dalaran | 1410 |
| 15001 | Exit portal to Dalaran | 571 |

Requires matching `AreaTrigger.dbc` rows 15000/15001 (client side).

### Taxi nodes
Reserved **350–359** (one per hub) — not yet inserted in these SQL files
(handled by the flightmaster script / DBC).

---

## 3. Creature templates (`creature_template`)

Entry block **830000–830999**. Allocated so far: 830000–830162 (with internal gaps).

### Legacy ambient decor — 830000–830017 (pre-existing, not created by these files)

Not created by these files. Referenced by `10_NPCs_Quests.sql` as ambient
decor: **830008, 830010** (Horde camp) and **830014, 830016** (Alliance
camp). Still forced to `minlevel=maxlevel=130`, factions `1716/1718/1719`
— rebalance pending (see README caveats). Script issues for 830003/830005
noted in [§8](#8-scriptnames--source).

### Flight masters (`05`, `05b`, `05f`)

All use script `npc_hyjal_flightmaster`. Outpost FMs use neutral faction 35
so both factions can interact; base-camp FMs use the strict faction of their
camp. Equipment: sword 40345 + shield 49976. Outpost entries have no spawn
rows — placements are a manual Noggit pass.

| Entry | Name | Faction | NPC flags | Camp / location |
|---|---|---|---|---|
| 830020 | Hyjal Flight Master | 35 | 8193 | Jaina's Encampment (base) |
| 830145 | Flight Master | 36 H | 8193 | Thrall's Vanguard (base) |
| 830158 | Foothills Pathfinder | 35 | 8193 | Foothills outpost (no spawn yet) |
| 830159 | Scorched Groves Pathfinder | 35 | 8193 | Scorched Groves outpost (no spawn yet) |
| 830160 | Nordrassil Guide | 35 | 8193 | Nordrassil outpost (no spawn yet) |

### Alliance town NPCs — Jaina's Encampment (`05`, `05b`, `05f`, `10`)

Service NPCs use faction **12 (Stormwind)**; ambient/guard NPCs use faction 35.
Alliance reuses the initial service set (830020–830024) and adds vendors via `05b`.

| Entry | Role (npcflag) | Faction | Source | Note |
|---|---|---|---|---|
| 830021 | Encampment Guard | 12 | `05` | `npc_hyjal_guard_alliance`; sword 40345 + shield 49976 |
| 830023 | Innkeeper Cerelina | 12 | `05` | 65537 (gossip+innkeeper) |
| 830024 | Emberwood Sap Quartermaster | 12 | `05` | 129 (gossip+vendor); `npc_hyjal_emberwood_vendor` |
| 830135 | Banker | 12 | `05b` | 131073 |
| 830136 | Auctioneer | 12 | `05b` | 2097153 |
| 830137 | General Goods | 12 | `05b` | 129 |
| 830138 | Trade Supplies | 12 | `05b` | 129 |
| 830139 | Food & Drink | 12 | `05b` | 641 |
| 830140 | Reagents | 12 | `05b` | 2177 |
| 830141 | Weaponsmith + repair | 12 | `05b` | 4225 |
| 830142 | Armorer + repair | 12 | `05b` | 4225 |
| 830143 | Stable Master | 12 | `05b` | 4194305 |
| 830144 | Tabard Designer | 12 | `05b` | 524289; sells tabard 400908 |
| 830161 | Hyjal Frontier Soldier | 12 | `05f` | 0; perimeter infantry; displays 2705/3661/3233 (human/NE/dwarf); sword 40345 |
| 830080 | Encampment Refugee | 35 | `10` | ambient; lvl 80–82; spawned |
| 830089 | Alliance Field Priest | 35 | `10` | ambient; lvl 80–82; spawned |
| 830083 | Kaldorei Ranger | 35 | `10` | ambient; lvl 82–84; spawned |
| 830085 | Talon Druid Scout | 35 | `10` | ambient; lvl 88–90; spawned |
| 830099 | Talon Veteran | 35 | `10` | ambient; lvl 104–106; **manual** |
| 830082 | Nordrassil Dryad | 35 | `10` | ambient; lvl 110–112; spawned |
| 830086 | Claw Druid Guardian | 35 | `10` | ambient; lvl 112–114; spawned |
| 830087 | Ancient of War Sentinel | 35 | `10` | ambient; lvl 120–122; spawned |
| 830088 | Ancient of Lore Keeper | 35 | `10` | ambient; lvl 120–122; spawned |

### Horde town NPCs — Thrall's Vanguard (`05`, `05b`, `05f`, `10`)

Horde gets a full independent service + vendor set. Service NPCs use faction **29
(Orgrimmar)**; ambient/guard NPCs use faction 36.

| Entry | Role (npcflag) | Faction | Source | Note |
|---|---|---|---|---|
| 830022 | Vanguard Grunt | 29 | `05` | `npc_hyjal_guard_horde`; axe 40402 |
| 830146 | Innkeeper Garruka | 29 | `05b` | 65537 |
| 830147 | Emberwood Sap Quartermaster | 29 | `05b` | 129; `npc_hyjal_emberwood_vendor`; mirrors 830024 |
| 830148 | Banker | 29 | `05b` | 131073 |
| 830149 | Auctioneer | 29 | `05b` | 2097153 |
| 830150 | General Goods | 29 | `05b` | 129 |
| 830151 | Trade Supplies | 29 | `05b` | 129 |
| 830152 | Food & Drink | 29 | `05b` | 641 |
| 830153 | Reagents | 29 | `05b` | 2177 |
| 830154 | Weaponsmith + repair | 29 | `05b` | 4225 |
| 830155 | Armorer + repair | 29 | `05b` | 4225 |
| 830156 | Stable Master | 29 | `05b` | 4194305 |
| 830157 | Tabard Designer | 29 | `05b` | 524289; sells tabard 400908 |
| 830162 | Hyjal Vanguard Warrior | 29 | `05f` | 0; perimeter infantry; displays 4290/3735/17335 (troll/tauren/orc); axe 40402 |
| 830081 | Vanguard Refugee | 36 | `10` | ambient; lvl 80–82; spawned |
| 830090 | Vanguard Witch Doctor | 36 | `10` | ambient; lvl 80–82; spawned |
| 830084 | Flamebound Shaman | 36 | `10` | ambient; lvl 82–84; spawned |
| 830100 | Vanguard Battlemender | 36 | `10` | ambient; lvl 118–120; **manual** |

Horde quartermaster 830147 sells the same Emberwood token page as 830024
(wired in `07`). Food/General Goods/Trade Supplies/Reagents vendors are
stocked by `05c` (both factions). Weaponsmith/Armorer are repair-only;
Tabard NPCs are guild tabard designers; Banker/Auctioneer/Stable Master
need no stock.

> **Faction note:** all town + service NPCs use strict factions — **12 (Stormwind)**
> for Alliance, **29 (Orgrimmar)** for Horde — so each camp is usable only by its own
> faction. Quest givers in `10` (830030–830039) use the same strict pair; see faction-fix
> note in the Quest givers section below.

### Quest givers (`10_NPCs_Quests.sql`) — 830030–830039

> **Faction fix (2026-06-04):** quest givers were `35`/`36`. Template **36
> is friendly to no player group** (`friendMask=0`), so Horde players could
> not open their gossip/quest window. Switched to the strict pair already
> used by the town/service NPCs — **12 (Alliance)** / **29 (Horde)** — which
> are friendly to their own faction. Quests are race-locked
> (`AllowableRaces` 1101/690) so cross-faction interaction was never useful.
> Live fix if `10` is already applied:
> `UPDATE creature_template SET faction=12 WHERE entry BETWEEN 830030 AND 830034;`
> `UPDATE creature_template SET faction=29 WHERE entry BETWEEN 830035 AND 830039;`
> then `.reload creature_template` (or restart).

#### Alliance quest givers (faction 12)

| Entry | Name | Lvl | Role |
|---|---|---|---|
| 830030 | Commander Elowen | 80 | Alliance chain start |
| 830031 | Sentinel Aelaris | 88 | Foothills hub |
| 830032 | Keeper Elunor | 97 | Scorched hub |
| 830033 | Warden Starfall | 112 | Summit hub |
| 830034 | Archdruid Rhydel | 127 | Nordrassil hub |

#### Horde quest givers (faction 29)

| Entry | Name | Lvl | Role |
|---|---|---|---|
| 830035 | Warmaster Kargra | 80 | Horde chain start |
| 830036 | Scout Mavak | 88 | Foothills hub |
| 830037 | Spiritcaller Zorok | 97 | Scorched hub |
| 830038 | Battlelord Gromtar | 112 | Summit hub |
| 830039 | Earthwarden Toran | 127 | Nordrassil hub |

### Enemies (`10_NPCs_Quests.sql`)

#### Progression bands — 830040–830073

Auto-spawned unless marked **manual** (quest-exclusive spawn).

| Entry | Name | Lvl | Tier | Spawned? |
|---|---|---|---|---|
| 830040 | Charred Ghoul | 80–82 | Foothills | yes |
| 830041 | Ashen Banshee | 82–84 | Foothills | yes |
| 830042 | Blightbone Necromancer | 84–86 | Foothills | **manual** (quest 81205) |
| 830050 | Felfire Stalker | 95–97 | Scorched | yes |
| 830051 | Searing Doomguard | 97–99 | Scorched | yes |
| 830052 | Infernal Siegebreaker | 99–101 | Scorched | **manual** (quest 81206) |
| 830060 | Summit Gargoyle | 110–112 | Summit | yes |
| 830061 | Shadow Crypt Fiend | 112–114 | Summit | yes |
| 830062 | Frostgrave Lich | 114–116 | Summit | **manual** (quests 81207/81209) |
| 830070 | Rotmaw Abomination | 125–127 | Nordrassil | yes |
| 830071 | Frostbone Wyrm | 127–129 | Nordrassil | yes |
| 830072 | Hyjal Doomlord | 130 | Nordrassil (elite boss) | yes |
| 830073 | Rootfire Infernal | 129–130 | Nordrassil | **manual** (quests 81208/81209) |

#### Side-quest hostile variants — 830091–830098 (faction 14, all manual)

| Entry | Name | Lvl | Quest |
|---|---|---|---|
| 830091 | Foothills Bone Reaver | 86–88 | 81215 |
| 830092 | Foothills Deathcaller | 88–90 | 81216 |
| 830093 | Scorched Felmaw | 100–102 | 81217 |
| 830094 | Scorched Doomflayer | 103–105 | 81218 |
| 830095 | Summit Boneweaver | 116–118 | 81219 |
| 830096 | Summit Gravewing | 118–120 | 81220 |
| 830097 | Rootbound Colossus | 122–124 | 81221/81223 |
| 830098 | Rootflame Devastator | 126–128 | 81222/81223 |

### Mini-dungeon NPCs (`11_Mini_Dungeons.sql`) — 830110–830134, all manual-spawn

Bosses carry a `lootid` equal to their own entry; pools in [§6](#6-loot-pools).

| Dungeon (level) | Trash | Boss (lootid) |
|---|---|---|
| Ashvein Warrens (90) | 830110–830113 | 830114 Foreman Droth |
| Cindervault (100) | 830115–830118 | 830119 Forgemaster Salhar |
| Gravebloom Den (110) | 830120–830123 | 830124 Matron Vhalra |
| Rootshadow Hollow (120) | 830125–830128 | 830129 Hollow Warden Azhul |
| The Gilded Depths (125) | 830130–830133 | 830134 High Excavator Auriclash |

`creature_template_model` rows exist for every entry above (Idx 0).

---

## 4. Creature spawns (`creature` — `10_NPCs_Quests.sql`)

GUID block **9010000–9010199** (used: 9010000–9010120). All on map 1410.
- 9010000–9010019 — Alliance base (6105) + Horde encampment (6106) hub NPCs.
- 9010020–9010031 — progression quest hubs (Foothills→Nordrassil).
- 9010040–9010120 — hostile spawns by tier.
Cleanup deletes `map=1410 AND id1 BETWEEN 830030 AND 830090` **or**
`guid BETWEEN 9010000 AND 9010199`.

> ⚠️ **Relocated 2026-05-31.** The original block `9001700–9001899`
> collided with **153 live spawns on map 1411 (Hinterland BG)** plus maps
> 745/1412 — file 10's range-DELETE would have wiped them. Moved to the
> verified-free `9010000+` block. See [§13](#13-live-check-results-via-acmcp).

> Mini-dungeon creatures (830110–830134) and "manual" variants above have
> **no spawn rows** by design.

Town NPCs (830135–830157) are spawned by `05b_Town_NPCs.sql` in GUID block
**9010200–9010232** — Alliance vendors 9010200–9010209 (6105), Horde
service+vendors 9010220–9010232 (6106). Cleanup deletes
`guid BETWEEN 9010200 AND 9010260`.

---

## 5. Item entries (`item_template`)

Entry block **400000–400999**. Allocated: 400000–400447 and 400500–400707.

| Range | Count | Block | ilvl | Req | Source |
|---|---|---|---|---|---|
| 400000 | 1 | Emberwood Sap token (currency) | 80 | 1 | `07` |
| 400001–400010 | 10 | Emberwood Quartermaster vendor page | 300 | 80 | `07` |
| 400011–400015 | 5 | Foothills quest rewards (rings) | 300 | 80 | `06` |
| 400016–400020 | 5 | Foothills elite loot (cloaks) | 316 | 88 | `06` |
| 400021–400025 | 5 | Scorched quest rewards (pendants) | 332 | 95 | `06` |
| 400026–400030 | 5 | Scorched elite loot (rings) | 352 | 103 | `06` |
| 400031–400035 | 5 | Summit quest rewards (cloaks) | 372 | 110 | `06` |
| 400036–400040 | 5 | Nordrassil elite loot (pendants) | 398 | 125 | `06` |
| 400041–400055 | 15 | Foothills expansion | 300 | 82 | `07` |
| 400056–400070 | 15 | Scorched expansion | 332 | 97 | `07` |
| 400071–400082 | 12 | Summit chests | 372 | 110 | `07` |
| 400083–400097 | 15 | Summit expansion | 372 | 112 | `07` |
| 400098–400109 | 12 | Nordrassil helms | 398 | 125 | `07` |
| 400110–400124 | 15 | Nordrassil expansion | 398 | 127 | `07` |
| 400125–400149 | 25 | Mini-dungeon signature rewards (5×5) | 324–404 | 90–125 | `11` |
| 400200–400229 | 30 | Endgame signature (one per talent tree) | **338** | 130 | `08` |
| 400230–400324 | 95 | Ascendant ICC tier-set analogues | 412 | 130 | `08` |
| 400325–400447 | 123 | ICC raid-drop analogues + Shadowmourne | 412 | 130 | `08` |
| 400500–400707 | 208 | Wrathful Gladiator PvP analogues | 412 | 130 | `09` |
| 400800–400805 | 6 | Emberwood town consumables T1 (food/drink/pots) | — | 80 | `05c` |
| 400806–400811 | 6 | Scorched town consumables T2 | — | 95 | `05c` |
| 400812–400817 | 6 | Summit town consumables T3 | — | 110 | `05c` |
| 400818–400823 | 6 | Nordrassil town consumables T4 | — | 125 | `05c` |
| 400824–400838 | 15 | Emberwood weapons (T1, ilvl 300, req 80) | — | 80 | `07b` |
| 400839–400853 | 15 | Skyfire weapons (T2, ilvl 332, req 95) | — | 95 | `07b` |
| 400854–400868 | 15 | Summit weapons (T3, ilvl 372, req 110) | — | 110 | `07b` |
| 400869–400883 | 15 | Nordrassil weapons (T4, ilvl 398, req 125) | — | 125 | `07b` |
| 400884–400889 | 6 | Emberwood trinkets (T1) | — | 80 | `07b` |
| 400890–400895 | 6 | Skyfire trinkets (T2) | — | 95 | `07b` |
| 400896–400901 | 6 | Summit trinkets (T3) | — | 110 | `07b` |
| 400902–400907 | 6 | Nordrassil trinkets (T4) | — | 125 | `07b` |
| 400908 | 1 | Hyjal Frontier Tabard | — | 1 | `07b` |
| 400909–400916 | 8 | Emberwood Mage's cloth set (head→feet) | 300 | 80 | `07c` |
| 400917–400924 | 8 | Emberwood Scout's leather set (head→feet) | 300 | 80 | `07c` |
| 400925–400932 | 8 | Emberwood Ranger's mail set (head→feet) | 300 | 80 | `07c` |
| 400933–400940 | 8 | Rootplate Warbear plate set (head→feet) | 300 | 80 | `07c` |

> **Resolved 2026-05-31:** the signature items (400200–400229) are
> `InventoryType=12` trinkets at **ilvl 338** — an intentionally lower
> entry tier than the 412 sets/raid drops. The README and `08` header
> (which previously said 412) were corrected to match the data.

### Dynamically-cloned blocks (depend on live source rows)
- **400230–400324** (Ascendant): `INSERT…SELECT` from hard-coded Sanctified
  ICC source entries **51220–51314**, stats ×1.45, name `Sanctified `→`Ascendant `.
- **400325–400447** (ICC): prepared-statement copy of the deduped ICC
  (map 631) loot catalog, normalized to ilvl 412, plus fixed source entries
  **50398, 50400, 50402, 50404, 52572** (Ashen Verdict Endless rings) and
  **49623, 50730–50738** (Lich King weapons + Shadowmourne).
- **400500–400707** (PvP): copy of every `item_template` whose name is
  `LIKE 'Wrathful Gladiator%'`, `entry < 200000`, `entry <> 50435`,
  normalized to ilvl 412.

Because these use JOINs against the live `item_template`, **any missing
source row is silently dropped** and the destination count shrinks — this
is exactly what the live `acmcp` check must verify (see §13).

---

## 6. Loot pools

### reference_loot_template
| Entry | Contents | Source |
|---|---|---|
| 14110 | Foothills elite cloaks (400016–400020) | `06` |
| 14111 | Scorched elite rings (400026–400030) | `06` |
| 14112 | Nordrassil elite pendants (400036–400040) | `06` |
| 14120 | Ashvein pool (400125–400129) | `11` |
| 14121 | Cindervault pool (400130–400134) | `11` |
| 14122 | Gravebloom pool (400135–400139) | `11` |
| 14123 | Rootshadow pool (400140–400144) | `11` |
| 14124 | Gilded Depths pool (400145–400149) | `11` |

### creature_loot_template (`11`)
Mini-dungeon bosses → their reference pool: 830114→14120, 830119→14121,
830124→14122, 830129→14123, 830134→14124 (Chance 100).

### itemextendedcost_dbc (`07`)
| ID | Cost | Used by |
|---|---|---|
| 14100 | 12 × Emberwood Sap (400000) | vendor slots 1–4 |
| 14101 | 16 × Emberwood Sap (400000) | vendor slots 5–10 |

### npc_vendor (`07`, `07b`, `07c`)
Vendor **830024** and Horde mirror **830147** sell 400001–400010 (token page).
Food/General/Trade/Reagent vendors stocked in `05c`. Tabard vendors 830144/830157
sell the Hyjal Frontier Tabard (400908) added in `07b`.
Weaponsmith **830141** (A) / **830154** (H): sells T1 weapons 400824–400838 + T1 trinkets 400884–400889 (wired in `07c`; items created in `07b`).
Armorer **830142** (A) / **830155** (H): sells starter armour sets 400909–400940 — cloth/leather/mail/plate, 8 slots each, ilvl 300 req 80 (`07c`).

---

## 6a. Gossip menus and NPC text (`05d`)

| ID range | Table | Content |
|---|---|---|
| 83000–83015 | `npc_text` | Greeting text for quest givers (×10) + service NPCs (×6) |
| 83000–83015 | `gossip_menu` | MenuID→TextID one-to-one wiring |
| 83011–83015 | `gossip_menu_option` | Inn bind + vendor browse options for service NPCs |

`creature_template.gossip_menu_id` updated for entries 830020, 830023–830024, 830030–830039, 830137, 830139, 830145–830147, 830150, 830152.

---

## 6b. NPC equipment (`05e`)

`creature_equip_template.ID=1` rows added for 18 entries. `equipment_id=1` set on
the same entries. Visual weapon assignments:

| Entry | NPC | Main hand | Off hand |
|---|---|---|---|
| 830020/830145 | Flight Masters (base camps) | sword 40345 | shield 49976 |
| 830021 | Encampment Guard | sword 40345 | shield 49976 |
| 830022 | Vanguard Grunt | axe 40402 | — |
| 830030/830035 | Alliance/Horde chain starts | sword/2H mace | shield/— |
| 830031/830036 | Foothills hub | sword / dagger | — |
| 830032/830037 | Scorched hub | staff / healer mace | — |
| 830033/830038 | Summit hub | sword / axe | shield |
| 830034/830039 | Nordrassil hub | staff | — |
| 830023/830024/830146/830147 | Innkeepers/Quartermasters | — | — |
| 830158/830159/830160 | Outpost Flight Masters | sword 40345 | shield 49976 |
| 830161 | Alliance Soldier | sword 40345 | — |
| 830162 | Horde Soldier | axe 40402 | — |

---

## 7. Quest IDs (`quest_template` + addon/request/offer)

Block **81000–81500**. Allocated: 81200–81234.

### Alliance main chain (`10`) — 81200→81201→81202→81203→81204
| ID | Lvl | Title | Objective |
|---|---|---|---|
| 81200 | 80 | Into the Foothills | talk 830031 |
| 81201 | 82 | Cinders in the Brush | 8× 830040, 4× 830041 |
| 81202 | 95 | Through the Scorched Pass | talk 830032 |
| 81203 | 97 | Break the Felfire Pack | 9× 830050, 5× 830051 |
| 81204 | 127 | Root-Rot Extermination | 4× 830070, 1× 830072 |

### Horde main chain (`10`) — 81210→81211→81212→81213→81214
| ID | Lvl | Title | Objective |
|---|---|---|---|
| 81210 | 80 | Vanguard Forward | talk 830036 |
| 81211 | 82 | Burn Out the Dead | 8× 830040, 4× 830041 |
| 81212 | 95 | Flamebound Circle | talk 830037 |
| 81213 | 112 | Silence the Summit | 9× 830060, 5× 830061 |
| 81214 | 127 | Cut Off the Corruptor | 4× 830071, 1× 830072 |

### Optional side quests (`10`)
- **81205–81209** — standalone (no prev/next): target the manual-spawn
  variants 830042 / 830052 / 830062 / 830073.
- **81215–81223** — chained side line (81215→…→81223): target manual-spawn
  variants 830091–830098.

### Mini-dungeon quests (`11`) — 81230–81234 (standalone, 5 reward choices each)
| ID | Lvl | Dungeon | Kill / boss | Reward choices |
|---|---|---|---|---|
| 81230 | 90 | Ashvein Warrens | 10× 830110, 830114 | 400125–400129 |
| 81231 | 100 | Cindervault | 12× 830115, 830119 | 400130–400134 |
| 81232 | 110 | Gravebloom Den | 14× 830120, 830124 | 400135–400139 |
| 81233 | 120 | Rootshadow Hollow | 16× 830125, 830129 | 400140–400144 |
| 81234 | 125 | The Gilded Depths | 18× 830130, 830134 | 400145–400149 |

Mini-dungeon quests are offered/ended by **both** faction hub NPCs at the
matching tier (e.g. 830031 + 830036 for 81230).

---

## 8. ScriptNames / source

C++ scripts under `src/server/scripts/DC/HyjalFrontier/` (wired into
`dc_script_loader.cpp`). Referenced scriptnames:
`npc_hyjal_flightmaster`, `npc_hyjal_guard_alliance`,
`npc_hyjal_guard_horde`, `npc_hyjal_emberwood_vendor`.

> Outstanding: legacy reskins 830003/830005 reference
> `npc_ancient_wisp` / `npc_tyrande_whisperwind`, which do **not** exist in
> the core (README caveat). Not touched by these files.

---

## 9. Reserved-but-unused ranges

| Range | Purpose | Status |
|---|---|---|
| Gameobject 830000–830999 | GOs | none inserted yet |
| Gossip menu 83000–83099 | custom gossip | none inserted yet |
| Graveyard 15004–15019 | spare | free |
| game_tele 1497, 1501–1510 | spare | free |
| areatrigger 15002–15020 | spare | free |
| Quest 81000–81199, 81235–81500 | spare | free |
| Item 400448–400499, 400708–400799, 400941–400999 | spare | free |
| Creature 830018–830019, 830163–830999 | spare | free |
| Creature GUID 9010121–9010199, 9010233–9010260 | spawn spare | free |

---

## 10. Apply order

Per README §"Build order": 01 → 02 → 03 → 04 → 05 → 05b → 05c → 05d → 05e → 05f →
06 → 07 → 07b → 07c → 08 → 09 → 10 → 11. (08, 09 must run after the live DB already contains the
ICC/Sanctified/Wrathful source rows they clone. `05b` town NPCs need `07`
applied for the Horde quartermaster's vendor page to resolve; `05c` stocks
the `05b` vendors and creates the branded consumables.)

> **Live deploy note (05/05b faction switch):** files 01–05 are already
> applied with the old neutral factions. After updating, either re-apply
> `05`/`05b` or run:
> `UPDATE creature_template SET faction=12 WHERE entry IN (830020,830021,830023,830024);`
> `UPDATE creature_template SET faction=29 WHERE entry=830022;`
> then reload (`.reload creature_template` or restart) so cached templates refresh.

---

## 11. Cross-file consistency notes

- Every `INSERT` is preceded by a matching range `DELETE` (idempotent /
  re-runnable) — confirmed in all 11 files.
- Quest starter/ender NPCs (830030–830039) match `creature_template`
  entries; quest kill targets match the hostile/variant entries.
- Mini-dungeon reward-choice item IDs (400125–400149) match the items
  created in `11` and the reference pools 14120–14124.
- `09` and `08` §2/§3 are data-driven; their live source rows were verified
  present and the blocks fill their ranges exactly (95 / 123 / 208 — see §13).

---

## 12. Schema validation

Checked column-by-column against `data/sql/base/db_world/*.sql`
(authoritative AzerothCore world schema). **Result: PASS** — every table
exists and every column written by the Hyjal SQL is a real column.

Tables touched: `instance_template`, `game_graveyard`, `graveyard_zone`,
`game_tele`, `areatrigger_teleport`, `creature_template`,
`creature_template_model`, `creature`, `creature_queststarter`,
`creature_questender`, `quest_template`, `quest_template_addon`,
`quest_request_items`, `quest_offer_reward`, `item_template`,
`reference_loot_template`, `creature_loot_template`, `npc_vendor`,
`itemextendedcost_dbc`.

Notable column facts confirmed:
- `itemextendedcost_dbc` has exactly the 16 columns used by `07`.
- `creature` has `id1/id2/id3`, `zoneId`, `areaId` (the modern multi-id
  layout the spawns rely on).
- `item_template` has `ContainerSlots`, `BagFamily`, `socketColor_1..3`,
  `socketBonus`, `itemset` — all used by the item blocks.
- `quest_template` has `RewardChoiceItemID1..6` (the mini-dungeon file uses
  1..5) and `RequiredNpcOrGo1..4`.

---

## 13. Live-check results (via acmcp)

Run 2026-05-31 against `acore_world` through the `acmcp` MCP server
(`http://192.168.178.175:8080`).

### Cloned source rows — all resolve fully ✅
| Block | Needs | Found | Result |
|---|---|---|---|
| `08` §2 Ascendant (400230–400324) | Sanctified 51220–51314 | 95 / 95 (all named `Sanctified %`) | fills 95 |
| `08` §3 ICC catalog | map-631 dedup ilvl 251–284 | 108 distinct | — |
| `08` §3 Ashen Verdict | 50398/50400/50402/50404/52572 | 5 / 5 | — |
| `08` §3 LK weapons | 49623, 50730–50738 | 10 / 10 | — |
| `08` §3 total | 108 + 5 + 10 | **123** | **exactly fills 400325–400447** |
| `09` PvP (400500–400707) | `Wrathful Gladiator%`, `<200000`, `<>50435` | **208** | **exactly fills 400500–400707** |

### Applied-state of this SQL set (live)
Files **01–05 are already applied** (instance 1410, graveyards 15000–15003,
game_tele 1495–1500, areatriggers 15000–15001, creature_template
830020–830024). Files **06–11 are not yet applied** (item 400xxx, quests
81200–81234, creatures 830030+, map-1410 spawns all absent).

### ID-collision scan
Clear (no foreign occupants): item 400000–400447 / 400500–400707, quests
81200–81234, `itemextendedcost_dbc` 14100–14101, reference-loot pools.
The hits in creature_template 830020–830024, game_graveyard, game_tele and
areatrigger_teleport are **this set's own already-applied rows**, not
third-party collisions.

> 🔴 **GUID collision — found & fixed.** The original spawn block
> `9001700–9001899` (file 10) held **153 live spawns**: 148 on **map 1411
> (Hinterland BG)** — King Varian, Thrall, Revantusk/Wildhammer NPCs,
> vendors, teleporters — plus 4 on map 745 and 1 on map 1412. File 10's
> `DELETE … OR guid BETWEEN 9001700 AND 9001899` would have **destroyed all
> 153**. Relocated the Hyjal spawns to the verified-empty **9010000–9010199**
> block (DELETE range updated to match). No C++/other-SQL references to the
> old GUIDs existed, so the move is self-contained.

### FK / reference sanity
- `creaturedisplayinfo_dbc` is **empty server-side** (0 rows) — display-ID
  validity is enforced client-side from the extracted DBC, not the world
  DB. The new creatures reuse the same display family as the 18 working
  legacy reskins (830000–830017), so risk is low; confirm visually in-game.
- `npc_vendor.item` (400001–400010) and quest reward items (400125–400149)
  are created by `06`/`07`/`11` — internal, satisfied once those files apply.
- Factions 35 / 36 / 14 are standard core factions.

### Map readiness
`instance_template` map 1410 present; the graveyard/teleport rows for zones
6100–6106 are this set's own Hyjal rows — no conflicting third-party data.

### Follow-ups not blocking apply
- `game_tele` id 1495 z was fixed to `942.5` in `03`; the **live row still
  has the old `9425.0`** (03 was already applied) — re-apply `03` or run
  `UPDATE game_tele SET position_z=942.5 WHERE id=1495;`.
- Signature trinkets 400200–400229 are ilvl 338 by design (docs corrected).
