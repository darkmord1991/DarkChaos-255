# Timbermaw Hold (map 819) — Turtle's raid, ported from tortoise-wow

This replaces the earlier hand-made Timbermaw Hold (seven invented encounters) with **Turtle WoW's
own raid**, using the data that [tortoise-wow](https://github.com/tortoise-wow/tortoise-wow)
restored for Turtle 1.18.1. The source is commit `33d0131a5f0f`, from 2026-10-27, with `sql/base` and every
`sql/database_updates/world` file applied in order.

Turtle shipped the creatures, spawns, patrols, loot and quests **but no AI at all**. Every creature
was `EventAI` with zero events and no spell lists. The encounter scripts here are new.

## What is in this folder

| File | What |
|---|---|
| `tortoise_timbermaw_export.json` | The Turtle rows: 282 spawns, 781 patrol points, 11 GOs, 50 templates, 35 quests, loot, 138 items and 122 item spells. These are trimmed from a scratch MySQL that loaded the whole tortoise world DB. |
| `client_asset_plan.json` | Turtle display id → our display id, the new DBC rows, and the 445 asset files. |
| `gen_timbermaw_sql.py` | Writes the three pending world SQL files. **Tuning knobs are at the top.** |
| `apply_client_dbc_rows.py` | Idempotently adds the CSV/DBC rows. Re-running it is a no-op. |
| `client_assets_manifest.txt` | The 445 staged client files, with sizes and md5. |
| `verify_after_apply.sql` | Read-only checks to run after the SQL is applied. |
| `generated_report.txt` | Every creature's resulting HP and swing, and every item's old/new stats. |

## The raid

There are nine encounters. The data id equals the DungeonEncounter bit, see `timbermaw_hold.h`:

| # | Encounter | Entry | Notes |
|---|---|---|---|
| 0 | Karrsh the Sentinel | 4010001 | Brazier of Corruption |
| 1 | Rotgrowl and Kodiak | 4010002 / 4010003 | Brazier of Defilement. The encounter is done when both are dead. |
| 2 | Loktanag the Vile | 4010005 | optional |
| 3 | Ormanos the Cracked | 4010004 | optional |
| 4 | Chieftain Partath | 4010011 | Brazier of Putrification. Pulls his two Illuminators. |
| 5 | Archdruid Kronn | 4010009 | Brazier of Decay |
| 6 | Selenaxx Foulheart | 4010006 + Geode 4010008 | optional. The Geode cuts her damage taken to 25%. |
| 7 | Trioch the Devourer | 4010010 | optional, patrols |
| 8 | Ursol | **4010007** | final boss, behind the Barrier of Ursol |

The four brazier guardians gate Ursol. When all four are dead, the barrier opens and Ursol becomes
attackable. This matches Turtle's layout, where the braziers stand beside exactly those four
bosses. Ursol was never spawned by Turtle. He is placed in `UrsocRoom` on the navmesh floor
(Z 375.9). Ursol keeps entry 4010007 because `Achievement_Criteria` 13511 already points there.

Trash is 18 Turtle types in 4010101–4010118 plus four adds in 4010012–4010015. Each runs a SmartAI
kit that uses `SMART_ACTION_CUSTOM_CAST` (218) with level-130 basepoints.

## Scaling

Turtle's level-60 numbers are multiplied, keeping Turtle's *relative* design:

- HP ×30, so a 600k Turtle boss becomes about 18M.
- Melee ×5, so a 3,000 Turtle swing becomes about 15k. Ursol gets an extra ×1.3 HP and ×1.15 damage.
- The Geode is at 40% of Turtle's value.

Read the result per creature in `generated_report.txt`. The old raid's numbers were **3× HP / 5×
damage above what its own comments said**, because the global level ramp (315_) landed after it.

Boss spells that do fixed damage are cast with basepoints set to a fraction of the boss's **own
current melee** (`TimbermawScaledDamage`). Retuning `DamageModifier`, an enrage, or a Mythic damage
aura therefore moves the spells with it.

## Items

The 136 items cover all Turtle boss drops, the quest rewards (including all five 6-piece "Nature"
sets) and the quest items. They use entries 410200–410335.

- **Item level and requirement:** ilvl = 450 + 2 × (Turtle ilvl − 76), Required Level 130. All of
  them land in upgrade tier 5 (412+).
- **Stats:** each item keeps Turtle's stat *mix*. The budget per slot comes from our existing
  ilvl-450 epics.
- **Equip spells:** vanilla equip spells became 3.3.5 stats — crit/hit/haste/defense/dodge/parry
  /block ratings, spell power, AP, mp5 and block value.
- **Dropped:** procs, relic class-modifiers and Turtle-only auras (Luck, run speed and similar).
  The report lists what was dropped per item.
- **Kept but not dropping:** the old items 410000–410053 stay in `item_template`, because players
  may own them. They no longer drop and are no longer offered by the Vault.

## Quests

There are 15 quests (700769–700783), all at the Timbermaw camp on map 750, next to Gorn One Eye:

- **Narkogg the Dark:** a 5-step raid chain.
- **Kathor the Brave:** "Hide of a Wild God" plus the six "…of Nature" set exchanges. Each takes a
  Ritualistic token and 100 upgrade tokens instead of Turtle's vanilla mats.
- **Nathok:** "Draenethyst Recovery" and "Loktanag the Pure".
- **Great Bear Spirit (3711956, Moonglade):** "Nightmare's End".

Not ported: Turtle's chain through Itharius (Swamp of Sorrows), Insom'ni, Zul'Gurub and Fangorn,
Peroth'arn, and the Moonwhisper Coast quests. Three quest items that dropped from outdoor rares
now drop from raid bosses. The old quests 700760–768 are no longer offered but can still be
turned in at the Timbermaw Gatekeeper.

## Client assets — how the displays were found

Turtle's custom creature displays reuse ids that are **stock TBC displays in 3.3.5**. For example,
21161 (Ursol) is a naga here. The twow upport pack (`K:\UntouchedClients\twow upport`) carries
3.3.5-native copies:

- **Creatures, Turtle 1.18.0 range:** these sit at Turtle id + 13802.
- **Creatures, later Turtle displays:** tortoise ids run **9 above** the upport's. The tortoise
  data is newer: 21488 Loktanag ↔ upport 21479 (BogBeastFlower), 21486 Ormanos ↔ 21477
  (MountainGiantBoss), 21487 Trioch ↔ 21478 (HydraMulti).
- **Items:** upport ids match tortoise's directly. **But** the upport stores Turtle-custom
  ItemDisplayInfo rows in **1.12 field positions**:
  - GeosetGroup_1 is decoded back from the remapped string.
  - Texture_1 (ArmUpper) is lost and was rebuilt from the listfile.

There are 13 new models and 21 displays at 4010001+, plus 110 item displays at 4102000+. The 445
files are staged under `Custom/Client patches needed/`, all checked as M2 v264, BLP2 and with a
00.skin. Gameobjects needed nothing new.

**Click bounds (fixed 2026-11-11).** The upport's furbolg models (all 8), Ursol, BogBeastFlower,
HydraMulti and MountainGiantBoss carry a bounds radius of 0 on every animation. The client skips a
model for mouse picking while its current animation's radius is 0, so the Withermaw and the other
Timbermaw NPCs could only be clicked through their nameplates, and not at all while walking. Both
clients now hold repaired copies (`retroport_tools/dc_m2_sequence_bounds_repair.py`, header box per
animation). The md5s in `client_assets_manifest.txt` are the unrepaired upport files: anyone who stages
these models again must run that tool with `--stage` before deploying.

**Scale.** Turtle's `creature_template.scale` is the final size, because the 1.12 client ignores the
display's own scale. Our client multiplies `DisplayScale` by `CreatureModelScale`, so
`display_scale()` divides that factor back out. New `creature_model_info` rows also take the display's
scale. Gameobject sizes copy 1:1, with Turtle's per-spawn `object_scaling` folded in.

**Foulheart Imp.** Turtle's display 12190 is FireImp.mdx, which our client lacks. The imp uses our
stock 12190 instead: Imp.mdx with the same ImpSkinRed texture. The upport puts FireImp at 32986, but
our 32986 is a female goblin.

## Deploy order

The server half and client half both have to land, in this order:

1. **Server DBCs.** Copy these from `Custom/DBCs/` to the worldserver `data/dbc`, then sync the
   candidate dirs with `node sync-dbc-deploy.js --files <same list>`:
   `CreatureModelData.dbc`, `CreatureDisplayInfo.dbc`, `ItemDisplayInfo.dbc`, `Item.dbc`,
   `DungeonEncounter.dbc`, `Achievement.dbc`.
   - Without the CreatureDisplayInfo rows, every Turtle-model creature refuses to load.
   - Without the Item rows, every new item is silently dropped.
2. **Client.**
   - Stage only the files in `client_assets_manifest.txt` and run
     `dc_mpq_deploy.py --stage <that tree> --data <client Data>`.
   - Deploy the same five client DBCs (all of the above except DungeonEncounter, which the 3.3.5
     client never reads) to patch-4 **and** the enGB chain. See the enGB-shadow note in memory.
3. **SQL.** Apply `rev_1793212190166823600.sql`, then `…601`, then `…602`, in that order. Then run
   `verify_after_apply.sql`. These three were applied on 2026-10-28 and now live in
   `Custom/Custom feature SQLs/worlddb/TimbermawHold/`. After them comes the scale fix,
   `data/sql/updates/pending_db_world/rev_1793215071368598300.sql`. A fresh regeneration already
   contains it.
4. **Rebuild the worldserver.** The scripts in `src/server/scripts/DC/TimbermawHold/` changed.
5. Redeploy **DC-Journal** and **DC-PortraitCapture**.

**Do not re-apply** the archived `Custom/Custom feature SQLs/worlddb/TimbermawHold/05_*`–`17_*`.
For example, `05_templates.sql` DELETEs and re-inserts the whole 4010001–4010199 band with the old
design. `09_` puts the old bosses back into `instance_encounters`, and `10_` re-adds the
quest-master follower. Only `01`–`04` are safe.

## Regenerating

```
python gen_timbermaw_sql.py --stamp <rev number>
python apply_client_dbc_rows.py
```

Then recompile only the changed tables. Use `csv2wdbc.py` for CreatureModelData, CreatureDisplayInfo
and Achievement, and `dbc-compile.py --only Item|ItemDisplayInfo`. DungeonEncounter.dbc is patched
in place, because its CSV is stale.
