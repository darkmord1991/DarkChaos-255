# DC-Talents tools

Generators for the `DC-Talents` addon (the 3.3.5a port of the retail talent UI).

## convert_art.py - retail talent art to 3.3.5 BLPs + atlas table

Converts the retail 11.x talent-UI sheets to BLPs the 3.3.5a client renders and writes the Lua atlas
table the addon looks them up in.

**Inputs** (defaults, override with the flags in brackets)

- `K:\Dark-Chaos\WoW 11.2.5 PTR interface extract\` (`--src-root`): retail BLP2 files under
  lowercase folders. colorEncoding 3 (raw BGRA) and 2 (DXT1/3/5) are read; mip 0 is the source image.
- `K:\Dark-Chaos\WoW 11.2.7 FrameXML\Helix\AtlasInfo.lua` (`--atlas`): atlas coordinates.

**Outputs**

- `Custom/Client patches needed/Interface/<Folder>/<Sheet>.blp` (`--stage-root`): BLP2 type 1,
  colorEncoding 2 (byte 8), hasMips 0/1 (byte 11, never 2), zeroed 256-entry palette block. Native
  size is kept. DXT5 (alphaDepth 8, alphaType 7) when more than 0.1 % of the texels inside the atlas
  rects (plus their 1-texel filter apron) have alpha < 250, otherwise DXT1 (alphaDepth 0, alphaType 0).
  Mips mirror the source: a full chain to 1x1 when the source had one, else mip 0 only (`--mips`).
- `DC-Talents/Data/AtlasInfo.lua` (`--lua-out`): `ns.AtlasSheets` (pixel size per shipped sheet),
  `ns.AtlasInfo` (`{ file, width, height, left, right, top, bottom, tilesH, tilesV }`, retail values
  verbatim) and `ns.AtlasSourceSheet` (atlas -> retail sheet key, for coverage audits). The table covers
  every sheet recorded in the manifest, so a partial `--sheets` run never drops the others.
- `manifest.json` (`--manifest`): what the tool wrote (sha256, format, PSNR, source). This is what lets
  a rerun overwrite its own files and nothing else.
- `Custom/Client patches needed/_backup_enc3/...`: originals of the in-place sheets (see below). The
  leading underscore keeps it out of `dc_mpq_deploy.py`.

**Rerun**

```bash
cd "Custom/Client addons needed/_tools/dc-talents"
python convert_art.py --dry-run                 # plan + format decisions, writes nothing
python convert_art.py                           # convert, verify, write Lua + manifest
python convert_art.py --sheets Talents "TalentsClassBackground*"   # subset (keys or basenames, globs)
python convert_art.py --verify-only             # re-check the staged files against their sources
```

Needs Python 3 with numpy and Pillow (12.2 was used). A rerun with unchanged inputs rewrites nothing.
Deploying is a separate step (`retroport_tools/dc_mpq_deploy.py`, see `Client patches needed/README.md`).

**Encoding.** A vectorised PCA + least-squares BC1 colour fit and a BC4-style alpha fit run next to
Pillow's DDS encoder; each 4x4 block keeps the lower-error candidate. That is about 4-5 dB RGB and
15 dB alpha better than Pillow alone. DXT5 colour blocks are always written in unambiguous 4-colour form.
A source that already is DXT in the chosen format is copied block for block (MinimalCheckbox).

**Verification** (every run, from disk): header bytes and mip table, then mip 0 decoded and compared with
the source (PSNR over visible texels, all texels, alpha). The same data is also decoded by Pillow's
DDS BCn decoder and by Pillow's BLP reader as independent checks.

**Safety.** Nothing already staged is overwritten unless the manifest says this tool wrote it. The
exception is `IN_PLACE`: the three `Interface/FrameGeneral/UIFrameMetal*2x.BLP` sheets. Those are
replaced under their existing names, only if the original is colorEncoding 3, and only after a verified
copy to `_backup_enc3/`. Any other collision stops the run before anything is written (exit 3).
Exit codes: 0 ok, 2 missing source / unknown sheet, 3 collision, 4 backup mismatch, 5 conversion or
verification failure.

**Notes**

- The `UIFrameMetal*2x` sheets come from the 11.2.5 extract, not from the files that were staged
  before. Those were an older frame design at 2-8x the size, whose layout does not match the 11.2.7
  atlas. Only DC-Journal's unused `-2x` entries in `AtlasStorage.lua` described them.
- Class backgrounds and spec thumbnails are opaque inside their rects, so they are DXT1. Their
  unused sheet area turns opaque black, which no atlas samples. `--alpha-scope sheet` measures the
  whole sheet instead and makes them DXT5 (double size).
- Not shipped: `TalentsAnimations*` and `TalentsMask*` (3.3.5 has no mask textures) and the non-talent
  sheets listed in `SKIP_GLOBS`.
