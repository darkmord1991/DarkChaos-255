# DC Journal (Adventure Guide)

A backport of retail World of Warcraft's **Encounter Journal / Adventure Guide**
to 3.3.5a (WotLK), translated from the original Russian release into English.

It adds an in-game journal of dungeons & raids with per-boss abilities, loot,
3D models, lore, and an item-set (loot journal) browser, plus a micro-button on
the main menu bar (the "EJ" book icon) and the `/` binding
*Toggle Encounter Journal*.

---

## Layout & deployment

This started life as a **FrameXML override patch** (it replaced parts of the
client UI). It has been converted into a standalone AddOn:

```
dc-journal/
  dc-journal.toc            <- addon manifest (load order)
  README.md
  Interface/
    SharedXML/              <- retail "SharedXML" backport library (LayoutFrame,
                               ScrollList, Pools, NineSlice, CallbackRegistry,
                               ItemsCache, CreaturesCache, ...)
    FrameXML/
      EncounterJournal_*.lua/.xml
      NavigationBar.lua/.xml
      Custom_EncounterJournal/    <- the journal UI + content DATA (see below)
      Utils/                       <- C_Item / C_Creature shims
```

The original `Interface/` directory tree is **mirrored inside the addon** on
purpose: the XML files use relative `..\SharedXML\...` includes, and keeping the
tree intact means none of those include paths had to change. The `.toc` simply
lists the files (with the stock 3.3.5 client files removed — they are already
loaded before any addon).

### Textures are NOT in this addon

Every texture is referenced by a **root client path**
(`Interface\EncounterJournal\...`, `Interface\PORTRAITS\...`,
`Interface\LFGFRAME\...`, etc.), not an addon-relative path. The ~2,600 `.blp`
files therefore ship via the **DC client patch**, not here:

```
Custom/Client patches needed/Interface/    <- EncounterJournal, PORTRAITS,
                                               LFGFRAME, BUTTONS, Common,
                                               FrameGeneral, GuildFrame,
                                               HelpFrame, TalentFrame
```

That folder is built into the Patch-4 MPQ. If the journal shows missing
(green/black) textures, the patch isn't being loaded.

---

## Translation status

* **UI strings / chrome** — fully English (`EncounterJournal_Strings.lua`,
  `SharedConstants.lua` spec names & descriptions, `ModelFrames.xml` tooltips,
  micro-button text, code comments).
* **All content data** — fully English: instance names & lore, boss names &
  lore, ability names & descriptions, item-set names & descriptions, tier names.
  Canonical Blizzard English names were used where known
  (e.g. *The Deadmines*, *Shadowfang Keep*, *Plagueheart Raiment*, *Scorched
  Earth*).
* **`SharedStrings.lua`** is a bilingual table (`enGB` + `ruRU`); it already
  serves English on a non-ruRU client, so its Russian half was left intact.
* **`ItemsCache.lua`** is a fallback name cache that stores *both* an English
  (field 1) and a Russian (field 2) name and auto-selects by client locale, and
  is only consulted when the live server `GetItemInfo` fails — so it is already
  English-correct and was not modified. **`CreaturesCache.lua`** is only read
  for its display-id (field 1); the name field is never shown, so its Russian
  names were left as-is.

---

## Filling in more zones & loot later

All journal content lives in two plain-Lua data tables. The safest way to add an
entry is to **copy an existing row and edit it** — the field order matters.

### `Interface/FrameXML/Custom_EncounterJournal/Custom_EncounterJournal_Data.lua`

| Table | Keyed by | Row shape (by position) |
|---|---|---|
| `JOURNALINSTANCE` | instanceID | `{ name, loreText, dungeonButtonTex, lfgIconTex, backgroundTex, loreBgTex, mapID, areaID, …, instanceID, … }` |
| `JOURNALENCOUNTER` | instanceID | list of `{ encounterID, bossName, loreText }` |
| `JOURNALENCOUNTERCREATURE` | encounterID | list of `{ name, "", creatureID, bossImageTex, encounterID, … }` |
| `JOURNALENCOUNTERITEM` | encounterID | list of `{ itemID, encounterID, …numbers… }` (pure IDs — no text) |
| `JOURNALENCOUNTERSECTION` | sectionID | `{ sectionID, abilityName, abilityDescription, …flags / parent ids / spellID / icon… }` |
| `JOURNALTIER` | — | list of `{ tierID, tierName }` (e.g. Classic Dungeons / Burning Crusade / Wrath of the Lich King) |
| `JOURNALTIERXINSTANCE` | instanceID | `tierID` (maps each instance to its expansion tier) |

* Texture paths are root client paths (`interface\\encounterjournal\\...`) — add
  the matching `.blp` to the client patch folder above.
* `JOURNALENCOUNTERSECTION` rows nest via parent/child id fields to build the
  ability tree under a boss; copy a sibling row to keep the wiring correct.
* Strings may be `"double-quoted"` (names) or `[[ long-bracket ]]` (lore/ability
  text). Long-bracket text can span multiple lines and needs no escaping.

### `Interface/FrameXML/Custom_EncounterJournal/Custom_EncounterJournal_Loot_Data.lua`

`EJ_LOOTJOURNAL_DATA` is a flat list; each row is one armor set:

```
{ setName, itemLevel, tierLabel, sourceDescription, classID,
  specFlags, 0, { itemID, itemID, ... }, factionConst }
```

* `classID` is the WoW class id; `specFlags` use the
  `S_SPECIALIZATION_FLAG_SPEC1/2/3` constants (combine with `bit.bor(...)`).
* `factionConst` is one of `LOOTJOURNAL_FACTION_NEUTRAL / _ALLIANCE / _HORDE`.

---

## Dark Chaos modules

The Adventure Guide gains two extra top-level content tabs next to **Instance**
and **Raids**: **Open World** and **Mythic+** (tab buttons are in
`Custom_EncounterJournal.xml`; labels in `EncounterJournal_Strings.lua`). Two
DC-owned files drive them (loaded after the data, so they never touch upstream):

* **`Custom_EncounterJournal/DarkChaos_Content.lua`** — DC custom journal content
  via the `DCJournal.*` helper API (see the file header). Currently registers the
  **Giant Isles** open-world entry holding the world bosses (Oondasta, Thok the
  Bloodthirsty, Nalak the Storm Lord, Ancient Terror, Vorath the Drowned, General
  Rak'zor, Reawakened Avatar of Hakkar — creature/display/loot ids from the live
  DC world DB). Pass `openWorld = true` to `AddInstance` to list an instance under
  the **Open World** tab (instead of `tier = <id>` for a normal expansion). A
  copy-and-adapt template is at the bottom of the file.

* **`Custom_EncounterJournal/DarkChaos_MythicPlus.lua`** — wires the **Open World**
  and **Mythic+** tabs. Open World lists the `openWorld` instances; Mythic+
  dynamically lists the current seasonal M+ dungeons (resolved from the
  `GetDCMythicPlusDungeons()` client native by mapId/name). Selecting any entry
  opens its normal journal page. No new textures — it reuses the existing dungeon
  grid by wrapping `EJ_ContentTab_Select` / `EJ_GetInstanceByIndex` /
  `EncounterJournal_ListInstances`.

* **`Custom_EncounterJournal/DarkChaos_CurrentInstance.lua`** — opens the journal
  straight onto the dungeon or raid the player is standing in (see below).

* **`Custom_EncounterJournal/DarkChaos_Fixups.lua`** — three runtime repairs that
  only surface once custom content is in the journal (see below).

* **`Custom_EncounterJournal/DarkChaos_Difficulty.lua`** — raid/party sizes
  outside the stock 5/10/25 layout, and Mythic (see below).

### DC content currently in the journal

| Instance | Map | Kind | Tier | Source |
|---|---|---|---|---|
| Giant Isles (world bosses) | — | open world | Open World tab | authored |
| Blackwing Descent | 669 | 10/25 raid | Dark Chaos | authored |
| Timbermaw Hold | 819 | 20 raid | Dark Chaos | authored |
| Emerald Sanctum | 824 | 20 raid | Dark Chaos | authored |
| Castle Nathria | 2296 | 10/25 raid | Dark Chaos | authored |
| Naxxramas 40 (SoD) | 2921 | 40 raid | Dark Chaos | cloned from Naxxramas (754) |
| Blackfathom Deeps (Ashenvale) | 820 | 5 dungeon | Dark Chaos | authored |
| Crescent Grove | 823 | 5 dungeon | Dark Chaos | authored |
| Shadowfang Keep (Cataclysm) | 825 | 5 dungeon | Dark Chaos | authored |
| Stratholme (DC) | 821 | 5 dungeon | Dark Chaos | cloned from Stratholme (236) |
| Scholomance (DC) | 822 | 5 dungeon | Dark Chaos | cloned from Scholomance (767) |

Bosses, ability text and loot for the **authored** entries are taken from the live
encounter scripts under `src/server/scripts/DC/` and the applied world DB, not from
retail trivia. The **cloned** entries are covered under "Cloning a Blizzard instance"
below. Things worth knowing when editing them:

* **Castle Nathria's spell ids are Shadowlands ids.** They are carried through
  verbatim from the port and mostly have no `Spell.dbc` row on 3.3.5, so those
  ability icons stay blank until a downport lands — the text is what carries the
  entry. Retail mythic is absent throughout; mythic-only mechanics were cut or
  folded onto heroic, and the descriptions follow the port.
* **Instance backgrounds borrow a thematically close stock set** (Darkheart
  Thicket for Timbermaw Hold and Crescent Grove, The Emerald Nightmare for
  Emerald Sanctum, Black Rook Hold for Castle Nathria). A texture path with no
  matching `.blp` renders as a green/black block.
* **Shadowfang Keep (Cataclysm) has no loot list on purpose.** All five boss
  templates (5046962, 5003887, 5004278, 5046963, 5046964) carry `lootid` 0 on the
  live DB, so any item list would be invented. Its spell ids come from
  `src/server/scripts/DC/ShadowfangKeepCata/`, and heroic-only mechanics are
  labelled as such because the instance ships Normal/Heroic/Mythic.

### Cloning a Blizzard instance — `DCJournal.CloneInstance`

Maps 821, 822 and 2921 are *copies* of dungeons the base data already documents in
full, running on private map ids. Retyping ~41 bosses by hand would produce strictly
worse data, so `DCJournal.CloneInstance(sourceInstanceID, opts)` deep-copies the
source's encounters, sections, creature models and item lists under fresh ids in the
DC band and repoints every cross-reference. The base instance is never modified —
only new keys are written.

```lua
local NAXX40 = DCJournal.CloneInstance(754, {
    id = 908000, tier = 80, isRaid = true, name = "Naxxramas 40 (SoD)",
    mapID = 2921, order = 5, hideDifficulty = true, copyLoot = false,
})
DCJournal.AddClonedLoot(NAXX40, "Anub'Rekhan", { 22726, 22355, --[[ ... ]] })
```

Rules that are not optional:

* **`mapID` and `name` must be overridden.** Two entries called "Stratholme" in one
  tier is a coin flip for the player, and the map id is the entire point.
* **`worldMapAreaID` defaults to 0** (no boss pins). The source's value points at the
  *stock* map's world map, so copying it would draw the pins on the wrong zone.
* **Icons and backgrounds ARE copied** — the clone loads the same WMO, so it is
  literally the same building.
* **`copyLoot = false` when the clone has its own loot tables.** 821 and 822 inherited
  stock's verbatim (every cloned `creature_template` kept the source entry in
  `lootid`), so the base item lists are correct — spot-checked, all 16 of Baron
  Rivendare's journal items are in `creature_loot_template` 10440. Naxxramas-40 did
  *not*: it carries its own templates 351000-351036 (the classic 40-man set —
  Desecrated tokens, Splinter of Atiesh), so its loot is copied off and rebuilt from
  the DB. `AddClonedLoot` looks the boss up by name and warns to chat instead of
  erroring if upstream ever renames one.
* **Do not clone a remake.** The base "Shadowfang Keep" (64, map 33) is the *classic*
  keep — Rethilgore, Fenrus, Arugal. Map 825 is the Cataclysm remake and shares only
  two bosses with it, which is why 825 is authored rather than cloned.

`CloneInstance` returns a `{ ["Boss Name"] = newEncounterID }` map, or `nil` (plus a
loud chat line) when the base data does not have the source instance.

**Known upstream defect, not cloned:** base instance 64's sections 2107, 2118, 2138
and 2156 each have a `nextSectionID` pointing at a row that does not exist. Base 767
also has one cross-encounter link (20352 → 20353). The Scholomance clone reproduces
that one faithfully — it behaves exactly as the base entry does.

### Boss banner art

The boss list draws each entry from a 128×64 `UI-EJ-BOSS-<Name>.blp`. Where that
exists it is used; where it does not, the journal falls back to a live 3D model
(see the fixups section below). Current coverage:

| Source | Bosses |
|---|---|
| already shipped in the patch | all of Blackfathom Deeps (Ashenvale), Blackwing Descent, Giant Isles; Timbermaw's Ursoc |
| **extracted from retail** (12.1.0, via `wow.export-main/tools/casc-extract.js`) | all ten Castle Nathria encounters |
| already shipped, reused | Emerald Sanctum's Wakener uses Legion's `Dragons of Nightmare` banner — which *is* Ysondre / Lethon / Emeriss / Taerar |
| **no art anywhere** — 3D model fallback | Timbermaw's six non-Ursoc bosses, all five of Crescent Grove, Erennius |

The retail files needed no conversion: they are already 128×64 DXT5 with
`hasMips=0`, not the `hasMips=2` that renders green on 3.3.5, and 60 of the 850
banners already shipping are single-mip too.

The last row is original Dark Chaos / Turtle content, so it has to be rendered
rather than extracted. `Custom/Client addons needed/DC-PortraitCapture/` is a dev
tool that does exactly that — it renders each display id through the client's own
portrait camera, screenshots it, and composites the result into a banner. See its
README.

---

## "Where am I" — opening on the current instance

`DarkChaos_CurrentInstance.lua` (loaded last) makes the Adventure Guide open on
the dungeon/raid the player is inside, and follow them if they zone while it is
already open.

3.3.5a has **no client API that returns the player's instance map id** —
`GetInstanceInfo()` gives the `Map.dbc` *name*, and `GetCurrentMapAreaID()` gives
a world-map index that is only correct while the world map happens to be pointed
at the player's own zone (which is what the stock `EJ_GetCurrentInstance()`
relied on, and why it mostly did not fire). So the primary key is the **map
name**, matched against the journal's own instance names:

1. a numeric map id, if a client build ever starts returning one (retail returns
   it as the 8th value of `GetInstanceInfo`) → map-id index
2. `GetInstanceInfo()` name → name index — the normal path
3. `GetRealZoneText()` / `GetZoneText()` → name index
4. the stock `EJ_GetCurrentInstance()` world-map-area scan, as a last resort

Matching ignores case, spaces, punctuation and a leading *"The"*, and retries on
the part after a colon — which is what makes *"Coilfang: The Steamvault"* find
*"The Steamvault"*. The handful of instances whose `Map.dbc` name shares nothing
with its journal name are listed explicitly in `MAP_NAME_ALIASES`. **Add an entry
there** if you add an instance whose journal name differs from its map name.

That resolves **73 of the 87 instance maps in `Map.dbc`**; the rest are instances
the journal simply has no page for (Black Temple, The Sunwell, Magister's
Terrace, Culling of Stratholme, Trial of the Crusader, Battle for Mount Hyjal,
the two Caverns of Time dungeons), plus the guild-house maps and Karazhan Crypts.
One known quirk: the SoD evaluation map 2921 is also called *"Naxxramas"*, so it
resolves to the WotLK Naxxramas page.

The file also replaces `EncounterJournal_ResetDisplay`, which stock-side always
selected the **Instance** tab — a raid landed on its page with the Dungeon tab
lit, and in a tier holding no dungeons that tripped the empty-tier auto-correct
and grayed a tab out. The replacement picks the tab that matches the instance and
switches the expansion dropdown to the tier that owns it.

---

## Boss portraits and late-arriving loot

`DarkChaos_Fixups.lua` carries three repairs. All three are invisible on stock
content and only bite once custom instances are in the journal.

**1. Boss portraits.** `Texture:SetPortrait(displayID)`
(`SharedXML/SharedExtendedMethods.lua`) is just
`SetTexture("Interface\PORTRAITS\Portrait_model_<id>")`. Two problems:

* Only ~845 of those `.blp` files exist, all for stock display ids — **no custom
  DC display id has one**. A failed `SetTexture` leaves the texture showing
  whatever it had before, and the boss buttons are *global frames recycled
  between instances*, so Crescent Grove rendered Blackfathom Deeps' boss art and
  the first instance opened in a session rendered the template's red `?`.
* `Portrait_model_*.blp` are **64×64**, but the boss-button texture is **128×64**
  (the size of the `UI-EJ-BOSS-*` banners). Even when the portrait exists it gets
  stretched to twice its width — that is why Old Serra'kis rendered as a smeared
  green blur.

The replacement resets to `UI-EJ-BOSS-Default` *before* attempting the portrait,
so a miss can never inherit stale art, then:

| Texture shape | Behaviour |
|---|---|
| wide (w/h > 1.5) — a boss-button banner | always render a live 3D model over the medallion; a square `.blp` can never fit here |
| square — search results, creature list, ability headers | use the `.blp` when it loads, 3D model when it does not |

Bosses that have hand-made `UI-EJ-BOSS-*` art never reach this path at all —
`EJ_GetCreatureInfo` hands back the real icon and the journal calls `SetTexture`,
not `SetPortrait`. The model framing knobs (`MODEL_CAMERA`, `BANNER_INSET`) are
grouped at the top of the file; `SetCamera(0)` is the head close-up on this
client.

**2. Loot that arrives late.** `EJ_BuildLootData` silently drops any item whose
`GetItemInfo()` is still `nil`, and custom items are not in the 3.3.5 client's
item DB — the client has to ask the server, which does not answer before the loot
list is built. Nothing rebuilt the list afterwards, so a fresh session showed an
empty Loot tab for every custom instance. The fix primes every loot id of the
instance being opened, fills the journal's own row cache as each answer lands
(`GET_ITEM_INFO_RECEIVED` plus a short retry ladder for clients that do not fire
it), and forces the buffer to rebuild. It also writes `equipSlot`, which
`EJ_BuildLootData` omits when it resolves an item lazily even though everything
downstream reads it — without that, a late item lists with no slot label.

**3. The class filter.** `EJ_GetLootFilter` was already patched to default to
`NO_CLASS_FILTER`, with a comment that filtering by the player's class made
dungeons look like they were missing loot — but `EJ_ResetLootFilter` set it
straight back to the player's class, and it runs from
`EncounterJournal_DisplayInstance`, so every instance page re-applied the filter
and defeated that fix. Reset now means reset; the class dropdown still filters on
demand.

`/dcjournal` (or `/dcj`) prints whether each hook installed, the current loot
filter, the resolved instance, and how many of the open boss's loot rows have
been answered by the server — which is how you tell "the addon was not reloaded"
from "the server never answered", instead of guessing from a screenshot.

---

## Difficulties beyond 5/10/25

`Custom_EncounterJournal.lua` holds a hardcoded **local** table:

```lua
EJ_DIFFICULTIES = { 5 Normal, 5 Heroic, 10 Normal, 25 Normal, 10 Heroic, 25 Heroic }
```

Several DC instances do not fit it (sizes and modes from `Custom/CSV DBC/MapDifficulty.csv`):

| Instance | Map | Difficulties |
|---|---|---|
| Blackwing Descent, Castle Nathria | 669, 2296 | 10N / 25N / 10H / 25H — stock covers these |
| Timbermaw Hold, Emerald Sanctum | 819, 824 | **20**-player Normal / Heroic / **Mythic** |
| Blackfathom Deeps (Ashenvale), Crescent Grove | 820, 823 | 5-player Normal / Heroic / **Mythic** |

A 20-player raid rendered as *"(10) Normal"* or *"(25) Normal"* — whichever
hardcoded lie was nearest — and Mythic could not be selected at all, since no
entry in that table is a third difficulty.

The table is a local and cannot be extended from outside, so
`DarkChaos_Difficulty.lua` replaces the five globals that read it
(`EJ_GetDifficultyInfo`, `EJ_IsValidInstanceDifficulty`,
`EJ_GetValidationDifficulty`, `EncounterJournal_UpdateDifficulty`,
`EncounterJournal_DifficultyInit`) with versions that first look for a
**per-instance set**. Anything without one — Blackwing Descent, Castle Nathria,
every Blizzard instance — falls through to the original untouched.

Register a set on the instance itself:

```lua
DCJournal.AddInstance({
    ...
    difficulties = { players = 20, modes = { "Normal", "Heroic", "Mythic" } },
})
```

* `modes` is in **MapDifficulty order**, so `modes[i]` is the mode the server
  calls `Difficulty` `i-1` — which the client reports as `difficultyID` `i`. That
  positional identity is what makes auto-selecting the difficulty you actually
  zoned into work.
* Difficulty masks are positional (1, 2, 4, …). Every DC encounter and loot row
  carries `difficultyMask = -1` ("all difficulties"), so the masks only need to be
  distinct — they never have to match a Blizzard value.
* Raids get a `"(20) Heroic"` label, 5-player instances a bare `"Heroic"`,
  matching stock behaviour.
* Walking in from a 25-Heroic raid leaves `difficultyID` 4 selected, which a
  3-mode instance does not define; `EncounterJournal_DisplayInstance` is wrapped
  to clamp it to the instance's first difficulty rather than leave the previous
  instance's label on screen.

---

## Notes

* `Custom_EncounterJournal.lua` contains a `gsub` pattern written as
  `"\|cffffffff(.-)\|r"`. The `\|` is a WoW-tolerated escape (the client drops
  the backslash, giving `|cffffffff...|r`). It is original upstream code and
  works on the 3.3.5 client; standalone Lua 5.2+ linters will flag it.
* `EncounterJournal_Bootstrap.lua` / `EncounterJournal_OfflineStubs.lua` /
  `EJ_Compat*.lua` are defensive shims that wire up frame references and define
  helpers the retail EJ expects but vanilla 3.3.5 lacks (e.g. `GetClassInfo`,
  `GetSpecializationIndex`). They are safe no-ops where the client already
  provides the API.

---

## It replaces 19 stock FrameXML globals (audited 2026-08-25)

Because this is a backport of retail's shared FrameXML, it ships newer versions
of `SharedXML/Util.lua`, `SharedXML/SharedUIPanelTemplates.lua` and friends. Those
files assign **globals that stock 3.3.5 already defines**, so loading this addon
replaces Blizzard's implementations for the entire UI, for every addon, for the
whole session — silently, and with nothing declaring that it happens.

That is not a bug today. All 19 were diffed against a 3.3.5a client extract:

* **10 are byte-identical** to stock (`CopyTable`, `tDeleteItem`,
  `SecondsToTimeAbbrev`, `FauxScrollFrame_GetOffset` / `_SetOffset` /
  `_OnVerticalScroll`, `ScrollFrameTemplate_OnMouseWheel`, `ScrollingEdit_*`),
  plus `ROTATIONS_PER_SECOND`.
* **7 are backward-compatible supersets** — extra optional parameters or extra
  branches that stock callers never trigger. `FauxScrollFrame_Update` adds a
  trailing `heightOnDisplay`; `ScrollFrame_OnLoad` /
  `ScrollFrame_OnScrollRangeChanged` add a `self.scrollBarHideable` branch;
  `MAX_PLAYER_LEVEL_TABLE` keeps `[0]=60 [1]=70 [2]=80` and appends later
  expansions.
* **2 diverge, but unreachably.** `tContains` returns `true`/`false` where stock
  returns `1`/`nil` — truthiness-equivalent, and no caller in stock FrameXML or
  any installed addon compares the result by identity. `SecondsToTime` is the
  retail version, which fixes a stock bug where `maxCount` was ignored for the
  first two units; a differential test over 460 argument combinations found it
  diverges **only** at `maxCount == 1`, and nothing passes `maxCount == 1`.

**If you edit any of these files, re-diff against stock before shipping.** The
danger is not the current code, it is an innocent-looking edit that turns a
superset into a replacement and changes scrolling or time formatting everywhere.

`../check_addons.py` enforces this: any collision with a stock 3.3.5 global that
is not recorded in `../framexml_overrides.txt` fails the check, with the verdict
required in writing.
