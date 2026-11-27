# DC-Collection — Textured creature previews (`SetCreatureDisplay` native)

Spec + offset-hunting guide for a WotLK-Extensions client native that makes the
**pet / form 3D previews render textured** (today they show as flat white
silhouettes). Companion to the diagnosis in the pet-preview work.

---

## 1. Why this is needed (confirmed diagnosis)

On the 3.3.5a client a creature's skin lives in `CreatureDisplayInfo.TextureVariation`
and is bound **only** by the client's *creature-display* model pipeline:

| Lua call | Binds the monster-skin texture? | Works for an un-cached creature? |
|---|---|---|
| `Model:SetCreature(entry)` | ✅ yes (full pipeline) | ❌ only if the creature is already in the client cache (common world creatures + **mounts** → why mounts look right; obscure pets/forms → not cached) |
| `Model:SetDisplayInfo(id)` | ✅ would | ❌ effectively a **no-op** on the 3.3.5a `Model` widget (retail-era method) |
| `Model:SetModel(path)` | ❌ geometry only → **white** | ✅ always (but untextured) |

The pet/form previews fall back to `SetModel(path)` because the other two can't
render an un-cached creature → correct shape, no skin. This affects **stock**
models (Night Elf Cat, the Dun Morogh Cub wolf, snakes) as well as Wraith-backported
modern models, so it is **not** a Wraith bug — Wraith rebuilds modern-model
*materials* in the normal draw path (mounts, which use that path, are textured).

**The fix:** expose the skin-binding load path to Lua keyed by a *display id*
(not a cached creature entry), so the preview can render any pet/form textured.

---

## 1a. CSV verification results & cheapest-first ladder — READ BEFORE BUILDING

A multi-agent audit of `Custom/CSV DBC/CreatureDisplayInfo.csv` +
`CreatureModelData.csv` (parsed with a real CSV reader — the files use a
**comma decimal separator inside quoted fields**, e.g. `"0,15"`, so `awk -F','`
mis-parses them) established:

- **Data is sound.** 153/154 pet displays and 225/225 form displays exist, every
  one with a non-zero `ModelID` resolving to a non-empty `.mdx`/`.m2` path. The
  binary row is **16 dwords** matching the CSV header order; `TextureVariation_1/2/3`
  are string-table offsets at field indices 6/7/8 — the spec struct in §2 is correct.
- **Only gap:** pet display **`37541`** (Lil' Ragnaros) has **no** `CreatureDisplayInfo`
  row at all → any renderer no-ops on it. Add a row / fallback regardless of approach.
- **The white is confirmed MISSING-TEXTURE, not over-lighting.** The reported white
  cases all have a **populated** `TextureVariation` (Albino Snake `2955`=`SnakeSkinWhite`,
  Dun Morogh Cub `28489`=`BearSkinBlack`, every Cat Form populated). A *black* bear
  skin rendering flat featureless white = the skin is **not bound**, not blown out;
  same-geometry/different-skin pairs (white vs black snake share `snake.m2`, differ
  only in `TextureVariation`) prove `SetModel(path)` drops the skin. Over-lighting
  would wash a textured model but still show it. **The `SetLight` call is already in
  the shipping code and the whites persist**, so the lighting avenue is effectively
  already disproven.
- **The native only helps a subset.** It fixes the **138/153 pets + 220/225 forms**
  with a populated `TextureVariation` *whose skin BLP + model actually ship in the
  client patch*. It will **not** fix: `37541` (no row); the **15 pets + 5 forms with
  empty `TextureVariation`** (incl. Lil' K.T. `30507` — texture embedded in the m2, so
  `SetModel` should already show it; white there is a model-absent/other cause the
  native can't touch); or any display whose `.blp`/`.m2` is missing client-side.

**Adversarial conclusion: the native is the architecturally correct fix for the
dominant populated-`TextureVariation` cases, but it is the LAST resort, not the
first step — and a `SetCreatureDisplay` that merely does `SetModel(path)` renders
*identically white*. It is only worth building if it genuinely binds `TextureVariation`
(TARGET 2 below). Run this ladder first:**

0. **Rule out lighting (≈5 min, no DLL).** The shipping `SetLight` is over-bright
   (ambient `1.0` + directional `1.0`); the *working* DC-Housing preview uses
   `0.7`/`0.8` (`DC-Housing/UI/CatalogFrame.lua:128`). Lower `PetJournalFrame.lua`
   /`FormFrame.lua` `SetLight` to match and reload. Prediction: still white →
   positively confirms missing-texture. (Do it anyway — the over-bright values are
   wrong regardless.)
1. **Verify the client ASSETS exist.** Stock skins (`SnakeSkinWhite.blp`, …) ship
   with every 3.3.5a client, so the stock pets are safe; **confirm the custom 500000+
   `.m2`/`.blp` are in the deployed patch** and that the compiled binary DBCs match
   these CSVs. A missing asset renders white through *any* renderer.
2. **Live re-test `SetCreature(<creature ENTRY>)` with the creature cached** (mounts
   already render textured this way). If the pet/form definition can supply a real
   creature_template entry and a creature-query round-trip caches it, the *existing*
   fallback chain may texture them with **zero DLL work**. (Also re-test
   `SetCreature(displayId)` per the TARGET 2 note in §3.)
3. **For the custom 500000+ retroport models we own, bake the skin into the `.m2`**
   at retroport time so `SetModel(path)` shows it — a content-pipeline fix, no DLL.
4. **Only if 0–3 fail for the stock cases, build the native (§2/§3)** — and only after
   confirming TARGET 2 (the real `TextureVariation`-bind routine) actually exists.

This matches the live-tested known limitation already recorded in
`memory/model-preview-widget-conventions.md` (native = future option a, bake-into-m2
= option b).

---

## 2. The native

### Lua surface

```
-- Returns true if the model was driven through the creature-display load path.
-- model     : a Model/DressUpModel/PlayerModel frame (the preview widget)
-- displayId : a CreatureDisplayInfo id (the value the DC server already sends
--             as previewDisplayId / displayId / creatureDisplayId)
local ok = SetCreatureDisplay(model, displayId)
```

It must do, in C++, what `Model:SetCreature` does *after* its creature-cache
lookup: take a `CreatureDisplayInfo` record and load the M2 **and bind its
`TextureVariation` skins** onto the widget's model. Because we feed the display
record directly, it never needs the creature entry to be cached.

### Registration (matches the existing pattern)

`CustomLua.cpp` registers globals in `CustomLua::RegisterFunctions()` via
`AddToFunctionMap("Name", &Fn)` (see the long list there, e.g. `GetShapeshiftFormID`,
`SetGobPositionByGUID`). Add:

```cpp
AddToFunctionMap("SetCreatureDisplay", &SetCreatureDisplay);
```

and declare `static int32_t SetCreatureDisplay(lua_State* L);` in `CustomLua.hpp`.

### Implementation sketch

Uses the DLL's established conventions: raw-address `__thiscall` wrappers (see
`CSimpleFrame::Show/Hide` → `CGTooltip.cpp:2459`, calling `0x48F620`/`0x48F660`),
the `DBClient` row API (`DBClient.hpp`), the already-mapped
`g_creatureDisplayInfoDB` (`DBCAddresses.hpp`, `0xAD34B8`), and the address-constant
header style (`MiscAddresses.hpp`).

```cpp
// --- addresses to resolve by RE (see section 3) -----------------------------
namespace addr
{
    // CSimpleModel method that loads an M2 + binds monster-skin textures from a
    // CreatureDisplayInfo record (the routine Model:SetCreature reaches after its
    // creature-cache lookup). __thiscall(CSimpleModel* model, uint32_t displayId).
    constexpr uintptr_t kModelSetCreatureDisplay = 0x000000; // TARGET 2

    // OPTIONAL decomposed fallback if TARGET 2 turns out inlined:
    //   CSimpleModel::SetModel(path)               -> already exposed as Lua SetModel
    //   CSimpleModel::SetMonsterSkinTexture(slot, blpPath/fileId)  // TARGET 3
}

// CreatureDisplayInfo row layout (verify field offsets against the client DBC;
// stock 3.3.5a creaturedisplayinfo is 16 dwords: ID, ModelID, SoundID,
// ExtendedDisplayInfoID, CreatureModelScale, CreatureModelAlpha,
// TextureVariation[3] (string-table offsets), PortraitTextureName, ...).
struct CreatureDisplayInfoRec
{
    uint32_t id;
    uint32_t modelId;
    uint32_t soundId;
    uint32_t extendedDisplayInfoId;
    float    modelScale;
    uint32_t modelAlpha;
    uint32_t textureVariation[3]; // offsets into DBClient::m_stringTable
    // ... remaining fields not needed here
};

int32_t CustomLua::SetCreatureDisplay(lua_State* L)
{
    // 1) Resolve the CSimpleModel* backing the Lua frame in arg 1.
    void* model = ResolveModelWidget(L, 1);            // TARGET 1
    uint32_t displayId =
        static_cast<uint32_t>(FrameScript::GetParam(L, 2, 0)); // existing helper

    if (!model || !displayId)
    {
        FrameScript::PushNumber(L, 0);
        return 1;
    }

    // 2) Confirm the display id exists in the client DBC (so we fail cleanly
    //    rather than driving the loader with garbage).
    if (!DBClient::IsValidIndex(g_creatureDisplayInfoDB, displayId))
    {
        FrameScript::PushNumber(L, 0);
        return 1;
    }

    // 3) Drive the skin-binding creature-display loader.
    reinterpret_cast<void(__thiscall*)(void*, uint32_t)>(
        addr::kModelSetCreatureDisplay)(model, displayId);

    FrameScript::PushNumber(L, 1);
    return 1;
}
```

`ResolveModelWidget(L, idx)` returns the C++ widget object for a Lua frame on the
stack — TARGET 1 below. If TARGET 2 is inlined inside `SetCreature` and can't be
called standalone, use the decomposed path: call the existing `SetModel` with the
resolved `CreatureModelData` path, then call TARGET 3 once per non-empty
`TextureVariation` slot (resolve the BLP via the model's directory + the
string-table name, the same way the engine builds monster-skin paths).

### Addon integration (after the native ships)

In `PetJournalFrame.lua` (and identically in `FormFrame.lua`), make the native the
**preferred** attempt and keep `SetModel(path)` as the white fallback:

```lua
local function TrySetCreatureDisplay(displayInfoId)
    if not displayInfoId or displayInfoId <= 0
        or type(SetCreatureDisplay) ~= "function" then
        return false
    end
    return SetCreatureDisplay(model, displayInfoId) == true
        or SetCreatureDisplay(model, displayInfoId) == 1
end
```

Order for uncollected pets: `creature-display (native, textured)` →
`SetModel(path) (white)` → `SetCreature/SetDisplayInfo`. Gate everything on
`type(SetCreatureDisplay) == "function"` so the addon still works on a client
without the rebuilt DLL (falls back to today's white shapes).

---

## 3. Offset-hunting guide

The client is **32-bit, image base `0x400000`**; the DLL uses **absolute VAs**
(e.g. `0x48F620`). Use IDA/Ghidra/x64dbg, or `objdump -d` (the toolchain at
`C:\Strawberry\c\bin` was used for prior offset work). Three things to locate.

**Verified facts that narrow the hunt (ACMCP codex + DLL scout, 2026-06-18):**
- `SetCreature` / `SetDisplayInfo` are **NOT** on the base `Model` widget (codex book
  page 1237 lists only SetModel/SetCamera/SetLight/SetSequence/GetModel/... ). They
  are added by the **`PlayerModel` / `DressUpModel`** subtypes — so the preview frame
  must be a `DressUpModel` (it now is) and the method table to scan is the
  PlayerModel/DressUpModel one, not Model's.
- `Model:GetModel()` returns a **string** filename (confirms the addon's load check:
  a non-string/table return == nothing loaded).
- `Model:SetLight(enabled, omni, dirX, dirY, dirZ, ambIntensity, ambR, ambG, ambB,
  dirIntensity, dirR, dirG, dirB)` — 13 args (matches the working housing/preview call).
- Wraith maps the **M2 file loader** (`wraith::offsets::game::m2::kInit 0x0083CF00`,
  `kLoadSkinProfile 0x0083CB40`, `kFinalizeSkin 0x00837A40`) but those are the model-file
  `.skin`-profile path, **not** the CreatureDisplayInfo `TextureVariation` monster-skin
  bind. Do not confuse them with TARGET 2 — they operate one layer below it.
- Neither WotLK-Extensions nor Wraith currently registers any `SetCreature`/
  `SetDisplayInfo`/model-widget native, so there is nothing to reuse — TARGET 1/2 are
  new finds.

### TARGET 1 — Lua frame → C++ widget pointer (`ResolveModelWidget`)

Every stock `Model:*` Lua method already does this; reuse the mechanism.

1. Find the **Model widget method table**: search the binary for the C-strings
   `"SetModel"`, `"SetCreature"`, `"SetDisplayInfo"`, `"SetModelScale"`. They sit
   in a contiguous array of `{ const char* name, int(*fn)(lua_State*) }` pairs —
   the `FrameScript_Object` method registration for the Model widget.
2. Open the glue for `"SetModel"` (`Model_C_SetModel(lua_State*)`). Its prologue
   fetches the widget `this` from the Lua state before reading args — typically a
   call like `GetWidgetFromLua(L, 1, <typeTag>)` / a `lua_touserdata`+offset, or a
   shared `FrameScript_GetObjectThis`. That call **is** `ResolveModelWidget`.
3. Record its address + calling convention. Verify: from the glue, the returned
   pointer is the `this` passed to the C++ `CSimpleModel::SetModel`.

> Sanity check: the returned object's vtable should match across `SetModel` /
> `SetCreature` glues (same widget class, `CSimpleModelFFX`).

### TARGET 2 — the skin-binding creature-display loader (primary)

1. From the `"SetCreature"` glue → step into the C++ `CSimpleModel::SetCreature`.
2. Inside it, look for:
   - a read of the **creature cache** (resolves entry → display), then
   - a DBC access to **`creaturedisplayinfo`** — i.e. an xref to `0xAD34B8`
     (`g_creatureDisplayInfoDB`) or a `DBClient::GetRow` call on it, then
   - a call that takes the resulting display id / record and loads the model +
     **iterates `TextureVariation` binding monster-skin textures**.
3. That final call is TARGET 2. The ideal signature is
   `__thiscall(CSimpleModel*, uint32_t displayId)` (it re-reads the DBC) or
   `__thiscall(CSimpleModel*, CreatureDisplayInfoRec*)`. Note which — the native's
   cast must match.
4. Distinguish it from `SetModel`: TARGET 2 contains the **texture-variation loop**
   (multiple texture-set calls / string-table reads of the `TextureVariation`
   columns); `SetModel` has none.

> If `Model:SetCreature` is found to read `creaturedisplayinfo` with the **passed
> argument directly** (no creature-cache lookup), then `SetCreature` already takes
> a *display id* — in that case the texture failure is elsewhere (e.g. the display
> rows missing from the **client** `CreatureDisplayInfo.dbc`); re-test
> `SetCreature(displayId)` and verify the client DBC contains those ids before
> building the native.

### TARGET 3 — monster-skin texture setter (only if TARGET 2 is inlined)

If TARGET 2 can't be called standalone, find the per-slot skin setter the loop
uses: a `__thiscall(CSimpleModel*, int slot, <BLP path or fileId>)` that assigns a
texture into the model's monster-skin slot (texture types 1/2/11). Then the native
becomes: `SetModel(CreatureModelData path)` + that call once per `TextureVariation`
entry (BLP path = model directory + string-table name + `.blp`).

### Resolving the data the native needs (already available in the DLL)

- `displayId → CreatureDisplayInfo row`: `DBClient::GetRow(g_creatureDisplayInfoDB,
  displayId, sizeof(CreatureDisplayInfoRec))`; `TextureVariation[i]` are offsets
  into `g_creatureDisplayInfoDB->m_stringTable`.
- `row.modelId → CreatureModelData → .m2 path`: the DLL also loads
  `creaturemodeldata` (`DataContainer.cpp`, id 268, `g_creatureModelDataDB`); same
  `GetRow` + string-table pattern (this mirrors the addon-side `DC.PetModelPaths`
  generation from `Custom/CSV DBC/`).

---

## 3a. Step-by-step IDA/Ghidra walkthrough

The scaffold (`CustomLua::SetCreatureDisplay`, gated by `#define
DC_NATIVE_SETCREATUREDISPLAY 0`) is already in `dc-wotlkextensions
Client/CustomLua.cpp`/`.hpp`, and `FormFrame.lua` already calls it. You only need to
fill two addresses, set the macro to 1, and rebuild.

**Tooling:** IDA (Free works) or **Ghidra** (free, built-in decompiler — recommended).
Load a clean `Wow.exe` build 12340; let auto-analysis finish. Sanity-check the image:
`0x0083CF00` must be a function start (Wraith M2 `kInit`) and `0xAD34B8` a data address
(the `creaturedisplayinfo` DBClient) — then everything is on base `0x400000`.

**TARGET 2 (the payload — do first):**
1. Strings window (IDA `Shift+F12`) → filter `SetCreature` → `X` (xrefs). It is
   referenced from a `{char* name, func*}` method table; the pointer after the string
   is the glue `sub_XXXXXX`. Open it, decompile (`F5`).
2. The glue extracts the model object from arg 1 (= TARGET 1, note it), reads arg 2
   (creatureID), and calls `CSimpleModel::SetCreature`. Step into that.
3. Inside: find the `creaturedisplayinfo` read fast by going to `0xAD34B8` → `X` →
   the xref that lands inside this function. Just after it, the call that loads the
   model AND loops over `TextureVariation` (2-3 repeated texture-set calls) is
   **TARGET 2**. (Plain `SetModel` has no such loop — that's how you tell them apart.)
4. Note its signature: small-int arg → `__thiscall(model, uint32 displayId)`; pointer
   arg → `__thiscall(model, CreatureDisplayInfoRec*)`.

**TARGET 1 (free — already visible):**
1. Strings → `SetModel` → its glue → decompile. The first lines convert arg 1 (Lua
   frame) to the C++ model pointer (a `GetObject(L,1,...)` call or `lua_touserdata`
   + cast). That is TARGET 1 (the `SetCreature` glue does the same). Note address +
   calling convention.

**Fill in:** set `kAddrResolveModelWidget` / `kAddrLoadCreatureDisplay`, adjust the
two `using …Fn` typedefs to the observed conventions, flip
`DC_NATIVE_SETCREATUREDISPLAY` to 1, rebuild. The `static_assert` catches a still-zero
address.

**Shortcut to check:** if `CSimpleModel::SetCreature` reads `creaturedisplayinfo` with
arg 2 **directly** (no creature-cache lookup), `SetCreature` already takes a display id
→ the native may be unnecessary; re-test `model:SetCreature(displayId)` live first.

**Fastest:** paste the decompiled `SetCreature` glue + `CSimpleModel::SetCreature` +
`SetModel` glue to the assistant; it will pin the two addresses and finalize the
typedefs.

---

## 4. Validation

1. Build Win32, deploy `WotLKExtensions.dll`, `/console reloadui`.
2. `/run DCPetJournalModel:ClearModel(); print(SetCreatureDisplay(DCPetJournalModel, 2955))`
   → Albino Snake display; expect a **textured** snake and a `1` return.
3. Browse uncollected pets: textured models, no white silhouettes; the debug line
   `Pet preview model loaded: id=… path=…` should stop firing for them (native
   path wins before the `SetModel` fallback).
4. Apply the same `TrySetCreatureDisplay` lead to `FormFrame.lua` and confirm the
   cat/bear forms render textured.
5. Regression: a client **without** the rebuilt DLL must still show today's white
   shapes (the `type(SetCreatureDisplay) == "function"` gate).

---

## 5. Notes / risks

- **Wraith interaction:** TARGET 2 is the same load path mounts/in-world creatures
  use, so Wraith's M2/material hooks apply to modern models automatically — no
  Wraith change needed.
- **Native-safety:** guard on `IsValidIndex` before calling the loader; a bad
  display id must early-out (the `GetCombatRatingScalar` crash — see project memory
  — was exactly an unchecked `DBClient::GetRow` deref; do not repeat it).
- **Custom display ids ≥ 500000** (e.g. the Devilsaur pets, custom forms) only
  render if their rows exist in the deployed client `CreatureDisplayInfo.dbc` /
  the model file ships in the client patch — same constraint as today.
- **Texture variants:** with the real display record bound, colour variants
  (cat tabby colours, snake skins) now render their *correct* skin, which the
  `SetModel`-by-path map could not do.
