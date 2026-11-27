# Glue skin — red buttons, black borders, gold letters + red loading bar

Deployed 2026-08-06 into **`Data\patch-5.MPQ`** — the UI archive, via plain `dc_mpq_deploy.py`
routing. Rollback: `patch-5.MPQ.pre-glueskin.bak`.

Staging lives with the rest of the client UI overrides in `Custom/Client patches needed/Interface/`.
An earlier round of this work sat in `patch-enGB-3.MPQ`; those 13 entries (including three `-v2`
orphans) were removed with `dc_mpq_remove.py`, so every file here has exactly one home.

**Design target:** red fill, black border, gold letters — everywhere on the glue screens, with no blue
left. The gold letters come from the stock glue fonts; nothing here touches them.

## What shipped, and what was rejected

The first attempt skinned the buttons with Legion's `-v2` panel art (retail fdid 1486740/41/42). It was
rejected in review: the v2 frame is much heavier and its corner radius much larger, so the buttons read
as oversized next to everything else. **The shipped art is the stock WotLK red/black sheet**, re-cut
(see below) but visually identical to stock — mean channel difference 3.4/255 against a true stock
render at 170x45.

The Legion art is no longer referenced. The bar went gold in the first attempt too; it is now red, to
sit with the buttons rather than fight them.

## Files

| In-archive path | Source |
|---|---|
| `Interface\Glues\Common\Glue-Panel-Button-Up.blp` | stock sheet, crop `0,0,147,47` → 256x64 |
| `Interface\Glues\Common\Glue-Panel-Button-Down.blp` | stock, same re-cut |
| `Interface\Glues\Common\Glue-Panel-Button-Disabled.blp` | stock, same re-cut |
| `Interface\Glues\Common\Glue-Panel-Button-Up-Blue.blp` | **copy of the plain sheet** — this is what kills the blue |
| `Interface\Glues\Common\Glue-Panel-Button-Down-Blue.blp` | copy of the plain sheet |
| `Interface\Glues\Common\Glue-Panel-Button-Highlight.blp` | stock highlight, crop `0,0,159,43` → 256x64 |
| `Interface\Glues\Common\Glue-Panel-Button-Highlight-Blue.blp` | copy of the plain highlight |
| `Interface\Glues\LoadingBar\Loading-BarFill.blp` | stock, palette hue-shifted to red |
| `Interface\Glues\LoadingBar\Loading-BarGlow.blp` | recoloured, but **the client never reads it** |
| `Interface\GlueXML\GlueButtons.xml` | stock `patch-enGB-2` copy, 7 texture defs → 0..1 |

Pipeline: `retroport_tools/blp_crop_fill.js --rect --size` for the sheets,
`retroport_tools/blp_palette_recolor.py --hue 355 --sat-scale 0.95 --value-gamma 0.65` for the bar,
`dc_mpq_deploy.py --archive "enGB\patch-enGB-3.MPQ"` to deploy.

Deployed values: button fill `109,0,0`, button border `0,0,0`, bar fill `180,30,42`.

## Four traps, all of which fail silently

1. **Three glue buttons are skinned from Lua, not from XML.** `GlueDialog_OnUpdate` (which runs *every
   frame*), `CharacterSelect_DeathKnightSwap` and the `CharacterCreate` equivalent all call
   `Button:SetNormalTexture("Interface\Glues\Common\Glue-Panel-Button-Up[-Blue]")` with hardcoded
   paths. Retheming `GlueButtons.xml` alone does nothing for the login-dialog buttons — they stayed
   blue through a whole deploy cycle. The only way to de-blue them without overriding three more Lua
   files is to **make the `-Blue` sheets no longer blue**, which is why they ship as copies here.

2. **`SetNormalTexture(path)` resets the texture's TexCoords to 0..1.** Stock art occupies only
   0..0.578 x 0..0.75 of its sheet, so those Lua-skinned buttons render the art shrunk into the
   button's top-left corner at exactly 57.8% x 75% — a stock 3.3.5 bug, plainly visible on the
   "Authentication Successful" dialog. Every sheet here is therefore re-cut to **fill the canvas edge
   to edge**, and every TexCoords in `GlueButtons.xml` is `0..1`. That makes the XML path and the Lua
   path agree. Do not "restore" the stock sub-rect TexCoords — it re-breaks the Lua-skinned buttons.

3. **`blp-codec.js`'s `blpMip0ToRGBA` returns a fully opaque buffer — it never decodes alpha.** Both
   `decodeDXT1` and `decodeDXT5color` fill alpha with 255, so any alpha probe run through it reads
   opaque no matter what the art holds. That is how a round shipped: the stock sheets were measured as
   "fully opaque, corners included", re-encoded as opaque DXT1, and every button gained a **black box**
   behind it. The stock sheets are in fact `alphaDepth 8 / alphaEncoding 1` (DXT3) with alpha 0 at the
   rounded corners and 238 in the body. `blp_crop_fill.js` now decodes DXT3/DXT5 alpha itself and
   re-encodes to DXT3; verify a round-trip with an independent alpha reader, never with `blp-codec`.

4. **These paths are locale-resident, but that does not mean they belong in the enGB chain.**
   `Interface\Glues\**` and `Interface\GlueXML\**` live in `locale-enGB.MPQ` — yet the custom **root**
   chain outranks the enGB chain, so `patch-5` is the correct home and `dest_for()` was right all
   along. This was mis-documented until 2026-08-06; see `CLIENT_PATCH_LAYOUT.md` for the proof
   (`CharacterSelect.lua`'s expanded character list exists only in patch-5's copy and is demonstrably
   live). A file placed only in `patch-enGB-3` *does* still work — the enGB chain beats the Blizzard
   base archives — which is what made the wrong rule look right for so long.

## Loading bar

Engine-drawn, not FrameXML. The client binary references exactly two textures in that folder —
`Loading-BarBorder` and `Loading-BarFill`. `Loading-BarGlow`, `-BarGlass`, `-BarBackground` and
`UI-LoadingBar-Spark` ship in `locale-enGB.MPQ` but are **dead files**; the recoloured Glow here is
inert and could be dropped. The border is already dark metal, so recolouring the fill is the whole job.

Both bar textures are palettized BLP2 (`colorEncoding 1`), so `blp_palette_recolor.py` rewrites only
the 1024-byte palette at header+148 and leaves the index plane and 8-bit alpha plane byte-identical.

No Blizzard archive was modified. `locale-enGB.MPQ`, `patch-enGB.MPQ` and `patch-enGB-2.MPQ` are
untouched; everything ships as an override inside DC's own `patch-enGB-3.MPQ`.
