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
