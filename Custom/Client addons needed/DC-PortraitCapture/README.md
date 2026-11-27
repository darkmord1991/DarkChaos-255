# DC Portrait Capture

A **dev tool**, not player-facing content. Do not ship it in the player addon
set — it exists to generate Encounter Journal boss art for Dark Chaos bosses
that no client anywhere has art for.

## Why this exists

The Adventure Guide draws a boss list entry from a **128×64 `UI-EJ-BOSS-<Name>.blp`
banner** (creature render inside a torn medallion). Where that art exists,
everything is easy:

* **Castle Nathria** — all ten encounters are real retail Encounter Journal
  encounters, so their banners were extracted straight out of the retail client
  with `wow.export-main/tools/casc-extract.js` and dropped into the patch.
* **Ursoc** and the **Dragons of Nightmare** (which *is* Ysondre / Lethon /
  Emeriss / Taerar, i.e. Emerald Sanctum's Wakener) already shipped in the patch
  from Legion.

Twelve bosses are original Dark Chaos / Turtle content, so no client has them:

| Instance | Bosses |
|---|---|
| Timbermaw Hold (819) | Gatewarden Mor'thak, The Sundered Chieftain, Den Mother Ursara, Xanthir the Defiler, The Nightmare Given Root, Ursol |
| Crescent Grove (823) | Keeper Ranathos, Grovetender Engryss, High Priestess A'lathea, Fenektis the Deceiver, Master Raxxieth |
| Emerald Sanctum (824) | Erennius |

Those have to be **rendered**. Rather than exporting each M2 and framing a camera
by hand in Blender, this captures them in the game itself: the client's own
portrait camera (`SetCamera(0)`) already knows how to frame a head for any
display id, which is the same framing Blizzard's own portraits use.

Without art, the journal falls back to a live 3D model in the medallion
(`DC-Journal/.../DarkChaos_Fixups.lua`), so this is polish, not a blocker.

## How to run it

1. Copy this folder into `Interface\AddOns\` and enable it.
2. `/dcp list` — check the queue (12 entries).
3. `/dcp show 1` … `/dcp show 12` — preview the framing. If a boss is badly
   framed, note it; `MODEL` framing is per-display and some models sit oddly.
4. `/dcp start` — captures all twelve, ~2s each, into `<WoW>\Screenshots`.
   Don't touch the camera while it runs. It switches `screenshotFormat` to TGA
   (lossless) and restores your setting afterwards.
5. Run the companion script:

   ```
   python make-portraits.py --dry-run      # check the pairing first
   python make-portraits.py                # write the BLPs
   ```

6. Rebuild + deploy the MPQ patch.
7. Set `icon = "Interface\\EncounterJournal\\UI-EJ-BOSS-<Name>"` on each boss in
   `DC-Journal/.../DarkChaos_Content.lua` (names match the `QUEUE` entries).

## What the script does

`make-portraits.py` pairs the newest *N* screenshots — oldest first — against
`QUEUE`, then for each one writes:

* `Interface\EncounterJournal\UI-EJ-BOSS-<Name>.blp` — 128×64 banner
* `Interface\PORTRAITS\Portrait_model_<display>.blp` — 64×64 square icon

The banner silhouette is lifted from the **alpha channel** of an existing banner
(`UI-EJ-BOSS-Ursoc.blp` by default, `--mask` to change it) so the result has the
same torn-medallion shape as Blizzard's art. Only the mask is borrowed, never
pixels.

Output is **uncompressed BLP2 BGRA** (`type=1, encoding=3, alphaDepth=8,
hasMips=0`) — the same shape as the 28 uncompressed BLPs already shipping in the
client patch, so no DXT encoder or external converter is involved. At 33 KB a
banner, compression buys nothing. Note that BLP2 keeps a 1024-byte palette block
after the 148-byte header regardless of encoding, so pixel data starts at 1172.

`python make-portraits.py --selftest` verifies the DXT decoder against a real
banner and round-trips the BLP writer.

## Gotchas

* **`CAPTURE_FRACTION` must match** between `Capture.lua` and
  `make-portraits.py`. The capture frame is a centred square that is that
  fraction of the screen *height*; because both the frame and the screenshot
  scale with the screen, the script needs no UI-scale or resolution maths — but
  only while the two constants agree.
* **`QUEUE` order must match** between the two files. Pairing is positional.
* The script refuses to overwrite existing art unless you pass `--force`.
* Two entries (The Sundered Chieftain and Grovetender Engryss) share display id
  `503737` in the world DB, so their renders are identical by design.
* `--shots` defaults to `K:\WoW_3.3.5a_ 255 Fun\Screenshots`; pass it explicitly
  if your client lives elsewhere.
