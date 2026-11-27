# DC-Talents

The retail talent window (11.2.7, `Blizzard_PlayerSpells` + `Blizzard_SharedTalentUI`) running on the
3.3.5a client, with Dark Chaos changes layered on top. Tabs: **Specialization** (the two talent
groups), **Talents** (the three WotLK trees side by side), **Pet** (hunters with a pet) and **Glyphs**
(the stock glyph frame, hosted in the window).

What players get over the stock frame: staged changes with Apply / Undo, **free refunds** of learned
talents (through the `TLNT` server module), saved loadouts per class with import/export strings,
and the retail look. `N` and the micro button open it; **Shift+N** opens the stock frame; `/talents`
(`spec`, `glyphs`, `classic`, `scale <0.5-1|auto>`, `replace`, `server`, `debug`).

## How it is built

The retail code is **vendored unchanged**. Every DC change lives in `DC/` as an override or a stand-in,
so a new retail build is a resync, not a merge.

| Folder | What |
| --- | --- |
| `Retail/` | Retail Lua, copied verbatim (one prelude on line 1 so line numbers match Blizzard's), and retail XML converted to Lua tables (`*.xml.lua`). **Generated, never edit.** |
| `Core/` | The runtime that makes retail code run on 3.3.5: a private environment (`Env`), an XML interpreter (`Templates`), per-object retail widget methods (`Engine`), atlases, rotated line textures for arrows (`Line`), a Lua animation engine, retail pools, and retail C API emulation (`RetailAPI`). |
| `DC/` | The Dark Chaos layer. `Traits` emulates `C_Traits` / `C_ClassTalents` / the spec API over WotLK talents; `Layout` places three trees on the retail canvas and maps each tree to its retail spec; `Loadouts` stores loadouts in saved variables; `Server` speaks to the `TLNT` module; `Standins` replaces retail systems that are not ported (hero talents, PvP talents, the menu system, scroll boxes); `Overrides` changes retail mixins (tooltips, headers, loadout menu, tabs); `PetTalents` is the pet tab; `Frame` builds and opens the window. |
| `Data/` | Generated: retail enums/strings/colours (`RetailData`), atlases (`AtlasInfo`, `AtlasExtra`), and `TalentData` from the server's Talent.dbc. |
| `Textures/` | Arrow line and arrow-head textures for 3.3.5's rotation. |

Rules the runtime keeps:

- **Nothing reaches `_G`.** Every file starts with `setfenv(1, ns.env)`; lookups go env →
  `ns.compat` (DC implementations that must win) → `_G`. Only named frames and the saved variables
  are real globals. Retail strings the stock client has with the same text are *not* shadowed, so
  localized clients keep their translations.
- **Methods go on objects, never on shared metatables.** Retail widget methods are added per object
  only where missing, except the ones whose meaning is ours: `SetAtlas` / `GetAtlas` /
  `SetColorTexture` and the button `Set<State>Atlas`, which are always set. DC-Journal's Sirus
  SharedXML patches `SetAtlas` onto the shared texture metatable (it asserts on unknown atlases), and
  DCCompat patches a `SetColorTexture` that leaves a vertex colour behind.
- **Frame levels** are compressed in order (`Engine.MapFrameLevel`): a 3.3.5 `SetFrameLevel` raises
  a frame by at most 128 per call (and moves its children with it), so retail's levels of up to
  5510 cannot be set directly.
- **Regions retail leaves unanchored are placed the retail way** (`Core/Templates.lua`): the 3.3.5
  loader gives them no points, so a texture fills its parent and a font string is centred on it.
- **No mask textures** on 3.3.5: effects retail clips with a mask (the node border sheen) stay off.
- **Built on first open.** `PlayerSpellsFrame` and the loadout dialogs are deferred (`DC/Early.lua`).

WotLK on the retail model (details in `DC/Traits.lua`): talent id = node = entry = definition;
trees `1000 + classID` / `2000 + pet tab`; configs 1 and 2 are the talent groups, 50 the pet,
`1000 + id` the saved loadouts; one gate per tree and tier (points in *lower* tiers of that tree);
the talent groups are the "specializations", reporting the retail spec of their primary tree.

## Server

`src/server/scripts/DC/AddonExtension/dc_addon_talents.cpp` (module `TLNT`): HELLO, APPLY_BUILD,
APPLY_PET_BUILD. A build that only adds ranks is learned as is; a build that removes any is applied
as a free reset of the active spec plus a relearn, validated first so it cannot stop half-way.
Config: `DC.AddonProtocol.Talents.Enable`, `DC.Talents.FreeRespec`. Without the module the addon
still works, but only for additions, through the stock preview-talent packet.

## Resync with a newer retail build

```sh
cd "Custom/Client addons needed/_tools/dc-talents"
python sync_retail.py --retail "K:/Dark-Chaos/WoW <version> FrameXML"   # vendors Lua, converts XML, regenerates Data/RetailData.lua and the TOC
python gen_talent_data.py        # only when the server's Talent.dbc / TalentTab.dbc / Spell.dbc change
python atlas_audit.py            # atlases the new code references that Data/AtlasInfo.lua lacks
python lua51_check.py            # no Lua 5.2+ syntax (the client is 5.1, the tests run 5.4)
cd ../../_tests && lua test_talents.lua && lua test_talents_pet.lua
```

The TOC is generated (`TOC_LAYOUT` in `sync_retail.py`); edit the layout there, not the `.toc`.

## Tests

`_tests/test_talents.lua` (warrior) and `_tests/test_talents_pet.lua` (hunter with a pet) run the real
addon on `talents_sim.lua` + `talents_client.lua`, a strict 3.3.5a client whose widget API, script
handlers, events, native templates and fonts come from `wow335_api.lua`
(`_tools/dc-talents/extract_widget_api.py`: the WoW Programming 3.x reference + the real 3.3.5a
FrameXML). `-v` prints each check and the warnings. Visibility and frame levels follow the 3.3.5
client as reconstructed by the [whoa](https://github.com/whoahq/whoa) project: children's `OnShow`
run before their parent's, and `SetFrameLevel` raises by at most 128 and moves the children along.

`/talents debug` prints, in game, the window's layering, the gates and the points counter.

## Deploy

- The addon folder goes to the client's `Interface/AddOns` (needs DC-AddonProtocol).
- The retail art is staged under `Custom/Client patches needed/Interface/` (`TalentFrame`,
  `Common`, `FrameGeneral`, `HUD`) and has to be packed into the client patch MPQ.
- The server module needs a CMake re-configure (new source file) and a worldserver build.
