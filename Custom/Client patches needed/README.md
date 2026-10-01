# Client patches needed

Every modified client file, staged under **its real in-archive path**.

```
Interface/        Interface\...        all UI: FrameXML, GlueXML, Glues, art  -> patch-5
Textures/         Textures\...         loose textures                         -> patch-6
Sound/            Sound\...            audio                                  -> patch-6
_docs/            (never deployed)     notes, incl. CLIENT_PATCH_LAYOUT.md
_hd_models/       (own stage root)     tools/build_hd_models.py owns this
```

**DBCs do not live here.** `Custom/DBCs/` (`.dbc`) and `Custom/CDBCs/` (`.cdbc`) are their only
home, and they go to **patch-4**. This tree briefly carried a `DBFilesClient/` mirror; all four
files were byte-identical duplicates of the canonical copies, which is exactly how a mirror drifts
into two sources of truth. Compile and deploy them from the canonical folder:

```bash
python "K:/Dark-Chaos/wow.export-main/tools/csv2wdbc.py" \
    --csv "Custom/CSV DBC/<Table>.csv" --out "Custom/DBCs/<Table>.dbc" --table <Table>
python "K:/Dark-Chaos/wow.export-main/tools/mpq_stormlib_patch.py" \
    --mpq "K:/WoW_3.3.5a_ 255 Fun/Data/patch-4.MPQ" \
    --set "Custom/DBCs/<Table>.dbc=DBFilesClient\<Table>.dbc"
```

Locale-resident tables need the enGB copy too (`enGB/patch-enGB-3.MPQ`), then
`node sync-dbc-deploy.js --files <Table>.dbc` so the host's candidate dirs do not serve stale ones.

## The rule

**Folder names mirror the path inside the MPQ, never the archive they end up in.**
`dc_mpq_layout.dest_for()` decides the archive from the leading path segment, so a folder named
after an archive breaks it silently: `patch-4\DBFilesClient\TaxiPath.dbc` is not a path the router
recognises, so it fell through to patch-6 (MISC) and would have been written into the archive under
that literal name. This tree used to have `patch-4/`, `patch-5/` and `patch-enGB-3/` folders; only
`Interface/` routed correctly. Consolidated 2026-08-08.

Never spell an archive letter in a path. If you think you need to, the answer is in
`_docs/CLIENT_PATCH_LAYOUT.md` or `retroport_tools/dc_mpq_layout.py`.

## Deploying

The whole tree is one command - the router sends each file to the right archive:

```bash
python K:/Dark-Chaos/retroport_tools/dc_mpq_deploy.py \
    --stage "Custom/Client patches needed" --data "K:/WoW_3.3.5a_ 255 Fun/Data"        # dry run
```

Add `--apply` to write. Close the client first: a running client holds the archives open and the
writes fail. Two things to know:

- **Leading-underscore folders are skipped** (`_docs/`, `_hd_models/`), which is what keeps notes
  and other pipelines' staging areas out of the archives.
- **The root chain outranks the enGB chain** for `.lua`/`.xml` too, so `dest_for()` is correct even
  for locale-resident paths - do not hand-route those to `patch-enGB-N`. Where a file must exist in
  both chains (the locale DBCs), push the second copy explicitly with `mpq_stormlib_patch.py`.

Deploying an archive-sized batch? `dc_mpq_deploy.py` now refuses when the target's hash table cannot
fit the write - that table is fixed at creation, and StormLib reports success while dropping files
once it is full. Growing past it means a repack with `mpq_stormlib_pack.py`, not a retry.
