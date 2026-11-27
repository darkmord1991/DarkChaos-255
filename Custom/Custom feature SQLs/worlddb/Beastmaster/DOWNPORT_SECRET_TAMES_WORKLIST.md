# Secret Hunter Pet Tames — Beastmaster work-list

Source: Wowhead "Secret Hunter Pets Guide" (Moofzy, updated 2025-12-13). Cross-checked
against the DarkChaos world DB 2026-07-14. Goal: get every pet the guide names into the
DC-Collection Beastmaster catalog.

## ✅ Already available (no work)

**In roster already** (stock 3.3.5 WotLK-era tames): Loque'nahak, Skoll, Arcturis,
Terrorpene, Aotona, Broken Tooth, Humar the Pridelord, King Krush, The Rake,
Old Cliff Jumper, Sian-Rotam, Bjarn.

**Enabled 2026-07-14** (`02_dc_beastmaster_enable_existing_secret_tames.sql`) — existing
DB entries that were just missing from the roster:
- Ankha (3654318), Magria (3654319), Ban'thalos (3654320) — Molten Front spirit beasts
- Spirit of Atha (29033) — spirit serpent
- Thok the Bloodthirsty (400101) — devilsaur (display is a raptor stand-in; verify)

## ❌ Need downport (model NOT in 3.3.5)

Every pet below was named in the guide but has **no matching creature in the 3.3.5 world
DB** — they are Cata/MoP/Legion/BfA models. Each needs the proven downport pipeline
(see [[beastmaster-pet-catalog]] memory + `tools/downport-creature.js`). The one manual
step that cannot be automated: **visually select each pet's model in wow.export to read
its retail CreatureDisplayInfo id** (name→id auto-resolution is blocked by encrypted
retail DB2s). Fill the ids below, then run the pipeline.

### Skill families (whole families — pick a few notable models each)
- **Blood Beasts** (BfA 8.1)
- **Feathermanes** (Legion, exotic) — Whirlwing, Mavarnir, Netherbeak, Lalathin
- **Direhorns** (MoP) — incl. Horridon
- **Mechanicals** (Legion) — Haywire Battle-Chicken, A-Me 02, Silver Arachnodrone, Rush,
  War-Iron Axebeak, Mechanical Bunny, N.U.T.Z., Iron Juggernaut, Tekton
- **Sabertrons** (BfA mechanical tiger) — 5 colors: copper/gold/green/orange/red

### Challenge tames
- Skarr & Karkin (Molten Front; Skarr recolor: Jade Guardian)
- Lightning Paw (spirit beast fox, Duskwood)
- Gara (void spirit wolf, Draenor)
- Fenryr (wolf, Halls of Valor)
- Deth'tilac (spider, Molten Front) + recolors Kirix, Solix, Skitterflame, Anthriss
- Iron Juggernaut / Grey Juggernaut (+ Blue/Green/Teal recolors) — mechanical
- Portent (quilen, Vale) + other trackables: Glimmer, Savage, Patrannache, Bloodtooth,
  Stompy, Bristlespine, Rockhide the Immovable, Hexapos
- Felbound Wolf (Tanaan)

### Unique / interesting models
- Oondasta (devilsaur), Horridon (direhorn), Bulvinkel (spirit moose), Chimaeron (hydra),
  Plague Toad, Somber Dawn (stag), Lost Spectral Gryphon, Gon, Lowland Manashell (turtle),
  Degu (spirit porcupine) + recolors Gumi, Hutia, Ghostcrawler (spirit crab), Hati

### SQL template (per downported pet, after the model is baked + deployed)
```sql
-- creature_template CLONE from a donor of the right family (see pipeline doc), then:
INSERT INTO `dc_beastmaster_pets`
    (`creature_id`, `category`, `rarity`, `source_text`, `sort_order`, `enabled`) VALUES
    (<new_entry>, '<Family>', 4, '<zone / how obtained>', <sort>, 1);
```

## Regenerating the preview model-path table
`tools/beastmaster_display_ids.csv` holds every display id in the roster. Re-derive it with:
```sql
SELECT DISTINCT ctm.CreatureDisplayID AS displayId
FROM dc_beastmaster_pets p
JOIN creature_template_model ctm ON ctm.CreatureID=p.creature_id AND ctm.Idx=0
WHERE p.enabled=1 ORDER BY displayId;
```
then `python tools/generate_beastmaster_model_paths.py --ids tools/beastmaster_display_ids.csv`.
