# Map 750 — manual placement guide (portals + hub NPCs)

Everything here is placed **in-game**, so the ground height is exact — that is
why these are not in the SQL. Apply the SQL first (both `apply_all.sql`
runners), restart, then walk the list.

Commands used:

```
.go xyz <x> <y> <z> <map>     travel to a coordinate
.gps                          read GroundZ / FloorZ — they must MATCH
.gobject add <entry>          spawn a gameobject at your feet (permanent)
.npc add <entry>              spawn a creature at your feet (permanent)
.npc del                      remove the selected creature
.gobject delete <guid>        remove a gameobject
```

Face the direction you want the NPC to face **before** typing the command —
spawns inherit your orientation.

---

## 1. The two portals — Azshara Crater (map 37)

Level gate is **78+**, enforced server-side (an under-level player gets a
"you are not high enough level" message). Place them side by side near
**Archmage Thadeus** (creature 300070 @ `-54.99 50.32 297.86`), who ends AC's
level-80 quest 300803.

At level 78 the player is **automatically** handed their faction's quest
(81300 Alliance / 81301 Horde) pointing at these portals — so they must be
findable from Thadeus' camp. The quest text says "near Archmage Thadeus'
camp"; if you place them somewhere else, update the two `QuestDescription`
strings in `43_breadcrumbs.sql` to match.

```
.go xyz -54.99 50.32 297.86 37
.gobject add 3809082      -- Portal to Lor'danel        (blue,  Alliance start)
.gobject add 3809083      -- Portal to Bilgewater Harbor (red,  Horde start)
```

| Portal | Entry | Destination | Zone / band |
|---|---|---|---|
| Portal to Lor'danel | **3809082** | 7462.24, −326.55, 8.21 | Darkshore 80-90 |
| Portal to Bilgewater Harbor | **3809083** | 3527.24, −6518.98, 43.59 | Azshara 80-90 |

Either portal works for either faction by default; `44_azshara_crater_portals.sql`
has commented-out rows to lock them per team if you want that.

---

## 2. Lor'danel — Alliance start hub (Darkshore, 80-90)

`.tele dclordanel` — or `.go xyz 7462.24 -326.55 8.21 750`

**Already there natively** (do not duplicate): Innkeeper Kyteran, Teldira
Moonfeather (flight master), Ayriala (General Goods), Gorbold Steelhand (Trade
Supplies), Harlon Thornguard (Armorer + repair), Nyrisse (Leather Armor),
Jaelysia (Stable Master), and class trainers for warrior, rogue, hunter, mage,
warlock and priest, plus Blacksmithing (Taryel Firestrike) and Mining
(Periale) trainers.

**Place these — the real gaps:**

| Entry | NPC | Why |
|---|---|---|
| **830135** | Encampment Banker | no banker anywhere in Darkshore |
| **830136** | Encampment Auctioneer | no auction house |
| **830024** | Emberwood Sap Quartermaster | spends the zone token on gear |
| 830144 | Encampment Tabard Vendor | optional |
| 830139 | Encampment Cook (Food & Drink) | optional — carries the 80-130 food line |

All are faction 12 (Stormwind) and come with their vendor stock already wired.

---

## 3. Bilgewater Harbor — Horde start hub (Azshara, 80-90)

`.tele dcbilgewater` — or `.go xyz 3527.24 -6518.98 43.59 750`

**Already there natively:** Innkeeper Mixi + Grimy Greasefingers, Kroum (Wind
Rider Master, ~230 yd north at the dock), Zizo Seasizzle (Fishing Supplies),
Stek Orespazz (Blacksmithing Supplies + repair).

This hub is much thinner than Lor'danel — **place the full Horde service
roster** (all faction 29, all with vendor stock already wired):

| Entry | NPC | Provides |
|---|---|---|
| **830148** | Vanguard Banker | bank |
| **830149** | Vanguard Auctioneer | auction house |
| **830156** | Vanguard Stable Master | hunter pet stabling |
| **830150** | Vanguard Provisioner | General Goods |
| **830151** | Vanguard Trader | Trade Supplies |
| **830152** | Vanguard Cook | Food & Drink (80-130 line) |
| **830153** | Vanguard Shaman Supplier | Reagents |
| **830154** | Vanguard Weaponsmith | weapons + repair |
| **830155** | Vanguard Armorer | armor + repair |
| **830157** | Vanguard Tabard Vendor | tabards |
| **830147** | Emberwood Sap Quartermaster | zone token gear |

Skip 830146 (Innkeeper Garruka) — Mixi already covers the inn.

Guards, if you want the camp to feel defended: **830022** Vanguard Grunt,
**830162** Hyjal Vanguard Warrior (Alliance equivalents: 830021, 830161).

---

## 4. Optional — token quartermasters at the later band hubs

The Emberwood Sap token drops in every zone, so a quartermaster at each hub
saves a long trip back. Use **830163** (neutral clone, faction 35) anywhere
that is not an Alliance-only town:

| Hub | Tele | Band |
|---|---|---|
| Astranaar (Ashenvale, Alliance) | `.tele dcastranaar` | 88-98 |
| Splintertree Post (Ashenvale, Horde) | `.tele dcsplintertree` | 88-98 |
| Emerald Sanctuary (Felwood) | `.tele dcemerald` | 96-106 |
| Everlook (Winterspring) | `.tele dceverlook` | 104-115 |
| Nighthaven (Moonglade) | `.tele dcnighthaven` | sanctuary |
| Nordrassil (Hyjal) | `.tele Nordrassil` | 113-130 |
| Jaina's Encampment (Hyjal, Alliance) | `.tele JainasEncampment` | 113-130 |

---

## 5. Profession trainers — two options, pick ONE

Class trainers are **not needed** (the learn-spells scripts teach class
abilities automatically). Profession trainers still matter, because recipes
and skill ranks are not auto-learned.

- **Option A — automatic:** apply `41_start_services.sql`. It spawns a ring of
  profession/secondary trainers at both start hubs (guids 9020050-9020241)
  using coordinates derived from the hub anchors. Fast, but the ring z is
  provisional — check a few with `.gps` afterwards.
- **Option B — manual:** skip that file (or
  `DELETE FROM creature WHERE guid BETWEEN 9020050 AND 9020241;`) and place
  them yourself. The entry list is in
  `Custom/Documentation/scripts/gen_map750_start_services.py` (`CAMPS` →
  `outer`): Alliance roster for Lor'danel, Horde roster for Bilgewater.

Do **not** do both — you would get duplicate trainers.

---

## 6. After placing

```
.reload gameobject_template     -- if the portals were applied while up
.reload creature_template
```

Then verify:

- level 77 character → portal refuses with a level message; 78 → teleports;
- both arrivals put you on solid ground (`.gps`, GroundZ == FloorZ);
- hearthstone binds at each start hub;
- die once at each hub → you resurrect at the right graveyard with a spirit
  healer present.
