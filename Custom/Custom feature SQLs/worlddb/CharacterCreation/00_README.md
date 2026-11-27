# Character creation — cross-race gaps

Race-specific ports live in their own folders (`Worgoblin/`, `Pandaren/`, `AlliedRaces/`,
`Tier1Reskins/`). This folder holds the things that are **not** one race's problem: tables
every port forgot, and one shape mismatch between the two starting-gear mechanisms.

Apply with `mysql acore_world < apply_all.sql`. Both files are idempotent.

## Audit state (2026-09-01), races 9, 12, 22–27

| Area | State |
|---|---|
| `playercreateinfo` / `_action` / `player_race_stats` | complete, 10 classes each, all at Azshara Crater (map 37, zone 268) |
| `playercreateinfo_spell_custom` | complete; every race carries its faction language spell at `classmask` 0 |
| `playercreateinfo_skills` | complete; Common `102763597`, Orcish `29361074` |
| `charstartoutfit_dbc` + `Custom/DBCs/CharStartOutfit.dbc` | complete — race 27 was the last gap, closed by `Tier1Reskins/02_darkiron_startoutfit.sql` |
| `item_template.AllowableRace`, `quest_template.AllowableRaces`, `skillraceclassinfo_dbc`, `skilllineability_dbc` | swept, zero faction-wide rows missing a custom bit |
| `Custom/DBCs/SkillLineAbility.dbc`, `Custom/DBCs/SkillRaceClassInfo.dbc` | the **client** halves of those two sweeps — fixed 2026-09-05, see "Chat languages" below |
| starting-outfit item ids | all resolve in `item_template`, all pass `AllowableRace` for their race |
| **starting-outfit armour class** | **races 9 and 12 shipped Cata outfits the class cannot equip at level 1** — fixed 2026-09-09, see "Starting-gear armour class" below |
| **`spell_area.racemask`** | **43 faction-wide rows never swept** → `01_` |
| **`conditions` CONDITION_RACE (16)** | **14 faction-wide rows never swept** → `01_` |
| **`playercreateinfo_item`** | **193 of 201 rows duplicate a CharStartOutfit grant** → `02_` |

## Starting-gear armour class

`AllowableRace` was swept; **armour class never was**. Goblin (9) and Worgen (12) took the
Cataclysm starting outfits verbatim, and Cata moved armour proficiency down a tier at level 1:
warriors/paladins get Plate, hunters/shamans get Mail. On 3.3.5 both arrive at 40 —
`SkillRaceClassInfo` rows **21** (293 Plate, warrior+paladin) and **145** (413 Mail,
hunter+shaman) both carry `MinLevel 40`, and `playercreateinfo_skills` grants neither at
creation. `Player::CanUseItem` then rejects the piece (`Item::GetSkill()` ->
`GetSkillValue(itemSkill) == 0`), so `StoreNewItemInBestSlots` drops it in the backpack: the
character starts with a weapon and no armour at all. Confirmed live on four characters
(e.g. goblin warrior guid 15084 — skills 413/414/415/433, no 293; all four plate pieces in
backpack slots 23-27 with legs/feet/hands empty).

Fixed 2026-09-09 in `Custom/CSV DBC/CharStartOutfit.csv` -> `Custom/DBCs/CharStartOutfit.dbc`,
outfit rows 1/2, 127/128, 223/224, 225/226, 233/234. No `charstartoutfit_dbc` overlay rows were
involved — that table only covers ids 243-362 (races 22-27), so no SQL was needed.

| Outfit rows | Race / class | Was | Now |
|---|---|---|---|
| 1, 2 | Worgen Warrior | 49576/49578/49577 plate, 49579 plate boots | 49580/49581/49583 **mail**, 49582 **leather** boots |
| 127, 128 | Worgen Hunter | 49568/49569/49570/49571 mail | 49584/49587/49586/49585 **leather** |
| 223, 224 | Goblin Warrior | 49524/49527/49528/49529 plate | 49526 Goblin Brawler's Undergarment (cloth) + stock 139/140 Brawler's; gloves slot cleared |
| 225, 226 | Goblin Hunter | 49502/49503/49504 mail | stock Trapper's 127/6126/6127 |
| 233, 234 | Goblin Shaman | 52550/52551/52552 mail | 49517 + 49534 Goblin Primitive's (leather) + stock 153 Primitive Kilt |

The Worgen swaps are **visually identical** — Blizzard shipped Gilnean Recruit's and Gilnean
Trapper's as pure armour-class variants sharing one `item_template.displayid` per slot
(49576/49580 -> 696964, 49578/49581 -> 696961, 49568/49584 -> 62706, ...), so only equippability
changed and the `DisplayItemID` column was left alone. The Goblin sets have no same-set variant
(`Goblin Brawler's` exists in plate + one cloth chest only; `Goblin Trapper's` and `Primal` are
mail-only), so those rows took the closest legal goblin piece and fell back to the same-named
stock WotLK set, with `DisplayItemID`/`InventoryType` updated to match.

Deployed to `patch-4.MPQ`, `patch-enGB-3.MPQ`, `patch-enGB-4.MPQ` (the three archives that held
the winning copy, all md5-identical beforehand) and synced to the three `Custom/DBCs` candidate
dirs. **Still needs copying to the Linux worldserver's `data/dbc`.** The client half matters
because `CharStartOutfit.dbc` also drives the create-screen gear preview.

**Re-run this check after any starting-gear change.** `AllowableRace`/`AllowableClass` passing is
not sufficient — armour subclass must be in the class's level-1 set:
cloth 1 = every class, leather 2 = classMask 1135, mail 3 = 35, plate 4 = 32 (DK only),
shield 6 = 67, per `playercreateinfo_skills`.

Note in passing: the `CharStartOutfit` `DisplayItemID` column is maintained independently of
`item_template.displayid` and the two already disagree on several rows (e.g. worgen warrior legs
preview 68130 vs worn 696964). That is a cosmetic create-screen/reality mismatch that predates
this fix and was deliberately left alone.

## Chat languages — how a custom race talks to everyone else

Audited end-to-end 2026-09-05 for races 9, 12 and 22–27, across say/yell, whisper, channels,
party/raid and guild/officer.

Chat gates on the language **skill**, never on the "Language: Common/Orcish" spell (668/669) —
`WorldSession::HandleMessagechatOpcode` rejects the packet with `LANG_NOT_LEARNED_LANGUAGE`
before any per-type handling, so a missing skill blocks guild chat too. Note that
`PlayerStart.CustomSpells = 0` on this realm, so `Player::LearnCustomSpells` returns early and
**nobody** — stock races included — actually holds spell 668/669; the `playercreateinfo_spell_custom`
rows are inert. The skill is the whole mechanism.

Four things must line up, and all four are now correct:

1. **`playercreateinfo_skills`** grants it at creation — Common `102763597`, Orcish `29361074`.
   Those masks equal the full per-faction race sets, custom races included.
2. **`SkillRaceClassInfo`** must admit (skill, race, class) or `Player::LearnDefaultSkill` skips
   the grant *and* `Player::_LoadSkills` **deletes** the skill on every login. Rows 40/41/48/49.
3. **`ChrRaces` field 7** (`TeamID` server-side, `BaseLanguage` client-side) picks the default
   language in the chat box: 7 = Common, 1 = Orcish. Verified per race —
   12/22/26/27 → 7, 9/23/24/25 → 1, each matching field 13 (0 Alliance / 1 Horde).
4. **`SkillLineAbility`** rows 590/592 link skill 98/109 to spells 668/669 for the race.

(2) and (4) live in DBCs, which the worldserver reads from `data/dbc` **and then overrides** from
the `*_dbc` world-DB tables (`DBCStores.cpp` `LoadDBC` → `storage.LoadFromDB`), but which the
client reads **only** from the MPQ chain. The overlay tables were swept for all custom races; the
compiled DBCs were not, so client and server disagreed:

| DBC row | client had | now |
|---|---|---|
| `SkillLineAbility` 590 (Common) | `3149` — races 1,3,4,7,11,12 | `102763597` — +22, 26, 27 |
| `SkillLineAbility` 592 (Orcish) | `946` — races 2,5,6,8,9,10 | `29361074` — +23, 24, 25 |
| `SkillRaceClassInfo` 40/41/48/49 | race 27 absent from all four | Dark Iron added |

Fixed in `Custom/DBCs/` and deployed to `patch-4.MPQ`, `patch-enGB-3.MPQ` and `patch-enGB-4.MPQ`
(the enGB chain outranks the numbered patches, so all three must carry it). **The same two files
still need copying to the Linux worldserver's `data/dbc`** — until then race 27's language depends
entirely on the `skillraceclassinfo_dbc` overlay rows surviving, and a world-DB reimport without
`Tier1Reskins/01_darkiron_server.sql` would strip every Dark Iron character's Common on next login.

Once the skill is in place, cross-race chat needs nothing further:

- **Guild / officer** — `HandleMessagechatOpcode` rewrites the language to `LANG_UNIVERSAL`
  unconditionally before broadcasting, so guild chat is readable by every race by construction.
- **Party / raid / battleground** — carries the sender's language, and every race of a faction
  shares Common or Orcish, so it is readable within a group. Cross-*faction* groups and guilds are
  off (`AllowTwoSide.Interaction.Group` / `.Guild` = 0); if either is ever turned on, that same
  switch also rewrites the language to universal, so it stays readable.
- Existing characters that lost the skill before the fix are repaired by
  `chardb/restore_custom_race_languages.sql` (idempotent, safe to re-run).

## Still open, deliberately not in these files

- **Dark Iron Dwarf has no racials.** Every other race, custom ones included, has its set
  (`AlliedRaces/12_racial_spells.sql`, `AlliedRaces/00_RACIALS.md`). `01_darkiron_server.sql`
  excludes the dwarf's five (`672`, `2481`, `20594`, `20595`, `20596`) and says Dark Iron
  "gets its own later" — it never did. The retail set is Fireblood, Dungeon Delver,
  Mass Production, Mole Machine; the first two are pure data in 3.3.5.
- **The dwarf has 22 CharStartOutfit rows, not 20.** Class 8 is duplicated: stock ids 39/40
  vs DC-added 143/144. `DBCStores.cpp` fills `sCharStartOutfitMap` in id order and the last
  write wins, so 143/144 are live and 39/40 are dead weight (they carry two extra items,
  `159` Refreshing Spring Water and `4540` Tough Hunk of Bread). Harmless, but if you ever
  want the stock dwarf-mage outfit back, that is why it does not apply.
- **Race 27 has no `chrraces_dbc` overlay row.** `01_darkiron_server.sql` writes one but it
  is absent from the live DB, yet the race works — the server's own `ChrRaces.dbc` already
  carries all 27 rows (verified with `read_server_dbc`). Nothing to fix; noted so the next
  audit does not chase it.

## C++ that needed the same treatment (worldserver rebuild required)

- `src/server/game/Spells/SpellMgr.h` — `ICC_RACEMASK_HORDE` / `ICC_RACEMASK_ALLIANCE` were
  the stock `690` / `1101`, so no custom-race character received the ICC raid buff when it is
  driven by the `ICC.Buff.*` config rather than by the `spell_area` rows.
- `src/server/game/Entities/Player/Player.cpp` — the Collector's Edition gift-voucher switch
  had no case for races 9, 12 or 22–27, so those characters got nothing on a CE account. Now
  mapped per race, with a faction fallback for any race added later.

## Custom racials were never granted (fixed 2026-09-26: `03_custom_racials_skilllineability.sql`)

Every custom racial (Pandaren, Vulpera, Zandalari, Kul Tiran) was granted only by a
`playercreateinfo_spell_custom` row. `Player::LearnCustomSpells()` reads that table only with
`PlayerStart.CustomSpells = 1`, and the live server runs `0`. It has to: the same table carries
the ~700-row "start with every class spell" set for every race, custom ones included, which
that switch would push onto every character at every login. So no custom racial was ever learned.

Stock racials go through `SkillLineAbility` instead (Stoneform = row 11727: skill line 101,
RaceMask 4, AcquireMethod 2), re-taught at every login by `learnSkillRewardedSpells`. `03_` does
the same for the custom races, on their faction language skill (Common 98 / Orcish 109, which
every one of them has), masked to the race's own bit, through the `skilllineability_dbc`
overlay. No DBC deploy, no rebuild. Goblin and worgen are not affected: their racials have native
rows on skill lines 790 / 789.

Dark Iron (27) racials ship in the same file; their spell rows are
`../Tier1Reskins/03_darkiron_spell_dbc.sql` (generator `../Tier1Reskins/tools/gen_darkiron_racials.py`),
and Dungeon Delver's indoor speed is `src/server/scripts/DC/Races/dc_dark_iron.cpp`.

Do not "verify" a racial by looking in `character_spell`: skill-taught spells are never saved
there, stock ones included (0 of 677 dwarves list Stoneform).
