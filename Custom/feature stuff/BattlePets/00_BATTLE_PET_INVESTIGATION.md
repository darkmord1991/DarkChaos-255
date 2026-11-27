# Battle Pets: what a full implementation needs

Investigation of 2026-11-09. Nothing was implemented. This replaces the battle pet part of
[06_ADVANCED_FEATURES_EVALUATION.md](../CollectionSystem/06_ADVANCED_FEATURES_EVALUATION.md). That
document estimated 21-27 weeks and advised deferring, because it assumed there was no engine, no data
and no UI source to start from. All three now exist on this machine.

**Data kit:** `K:\Dark-Chaos\retailextracts\_battlepets_20261109\`. It holds every decoded table, the
species-to-DC mapping, the server-only data dumps and the scripts that made them (see the appendix).

## Bottom line

- **The PetBattleSystem-AzerothCore module is not a starting point.** It is a custom "Pokémon-style"
  minigame with invented rules, not the retail system (section 1).
- **A retail-faithful system can be built from local sources:**
  - all battle pet DB2 tables up to retail 12.1.5;
  - most of the server-only data (breeds, tamer teams, wild pools) in donor databases on our MySQL server;
  - the MoP Classic UI source;
  - the pet battle art;
  - a complete reference engine.
- **The engine choice is mainly a licensing question (section 7).** The only complete engine
  (SylvaniaCore / LegionCore / HavenCore, all one lineage) is Millenium-studio code. Its original header
  says "All Rights Reserved"; the GPL headers on the newer copies are relabels.
- **Two parts have no shortcut:**
  - how battles look in the world on 3.3.5 (pet ability visuals, camera);
  - the 618 collectible species DC does not have at all yet.
- **Compatibility:** the whole thing fits the old client, with no new opcodes and no update-field changes.
  It runs over a new DC addon-protocol module, with optional extras for the native client.

## 1. The PetBattleSystem-AzerothCore module

Repo: `K:\Dark-Chaos\PetBattleSystem-AzerothCore` (Faris-Kai). C++ about 6,800 LOC
(`PetBattleMgr.cpp` 6,056); addon `PetBattleUI` about 8,800 LOC. UniverseEmu's
`src/server/scripts/BattlePets` is a copy of the same module.

**What it does:**
- 3-pet teams.
- A die roll decides who acts first.
- 3 attacks per pet, each just a damage number plus a cooldown.
- Two invented elemental triangles: Water>Fire>Earth and Darkness>Basic>Light, each ×2.
- Health, element and damage are random per player and per pet.
- XP is player XP.
- Winning a wild duel hands out the companion item whose summon has the same DisplayID.

**Why it does not fit:**
- No species, breeds, quality, levels 1-25, abilities, auras, states, weather or family passives. It
  shares nothing with the retail data.
- Per-character data lives in the world DB (`bp_pet_team`, `bp_pet_info`). Columns are Spanish
  (`vida`, `tipo`, `cant_daño_1`).
- 23 raw `WorldDatabase.Query/Execute` format-string calls.
- Pets are summoned at the player's Z with no ground check.
- Damage feedback goes to chat only.
- The addon is low quality: one argument per line, about 47 globals, ties to DragonUI and other addons,
  no data model. The one reusable piece is its right-anchored HP bar fill.

**Worth keeping:** only the idea of staging the fight with summoned creatures in the world.

## 2. What DarkChaos has today

- **Companion catalog:**
  - `dc_pet_definitions`: 2,065 rows, all with `pet_spell_id`.
  - DCCollectionSource.cdbc: CollectionType 2 has the same 2,065 rows.
  - Only 163 use 3.3.5 spell ids. The other 1,902 are ported pets on custom ids (spells 30xxxx-35xxxx,
    creatures 346xxxx).
- **Ownership:**
  - `dc_collection_items` (characters DB) is account-wide, with **one row per pet** and no level,
    quality, breed or health.
  - Live: 13 pet rows across 2 accounts, so migration is trivial.
  - `dc_pet_collection` is empty.
- **Client journal:**
  - `DC-Collection/UI/PetJournalFrame.lua` (1,538) and `Modules/PetModule.lua` (785): a paged list, a
    DressUpModel preview, and Summon / Dismiss / Random.
  - Data comes from the local CDBC natives (`GetDCCollectionSources`), the `COLL` protocol module and
    `GetCompanionInfo("CRITTER")`.
  - Previews of unowned pets work through the creature-cache pre-warm (see memory
    `pet-preview-unknown-pets`).
- **Transport:**
  - The DC addon protocol, with JSON, chunking and the native bridge for darkclient335.
  - No pet battle module exists. Proposed module id: `PETB`.
- **Model natives on both clients:**
  - Old client DLL (`WotLK-Extensions/src/Client/CustomLua.cpp`): `SetCreatureDisplay`
    (`DC_NATIVE_SETCREATUREDISPLAY 1`) and `SetModelAnimation` / `GetModelAnimations`
    (`DC_NATIVE_MODELANIMATION 1`).
  - Native client: the same names in `darkclient335/WoW/Source/Ui/DarkChaos_Scripts.cpp`.
- **Static data:** CDBC natives are per table (`GetDCCollection*`); there is no generic accessor. New
  static data is cheapest as generated Lua files in the addon, which need no native work on either
  client.

## 3. Client data (DB2)

Decoded with `wow.export-main/tools/db2-decode.js`. CSVs are in the kit.

| Table | MoP 5.5.4 | 9.2.7 | 12.0.7 | **12.1.5** |
|---|---|---|---|---|
| BattlePetSpecies | not local, CDN 404 | 2,216 | 2,960 | **3,005** (+4 encrypted) |
| SpeciesState | 2,176 | 5,996 | 8,006 | 8,098 |
| SpeciesXAbility | 4,514 | 11,184 | 14,864 | 14,999 |
| Ability | 855 | 1,341 | 1,393 | 1,404 |
| AbilityTurn | 1,002 | 1,572 | 1,639 | 1,650 |
| AbilityEffect | 1,610 | 2,667 | 2,791 | 2,829 |
| EffectProperties | 98 | 133 | 133 | 136 |
| AbilityState | 313 | 454 | 460 | 460 |
| State | 105 | 123 | 123 | 123 |
| BreedState / BreedQuality | 80 / 6 | 83 / 6 | 83 / 6 | 83 / 6 |
| Visual | 773 | 1,012 | 1,051 | 1,051 |
| DisplayOverride | 0 | 292 | 292 | 292 |
| NPCTeamMember | 0 | 0 | 0 | 0 (ID + Name only, no team data in any client) |

- **Game tables:** they exist only as `gametables/battlepettypedamagemod.txt` (10×10 family matrix,
  identical in every build) and `battlepetxp.txt`.
- **Species has no name column.** Names come from `Creature.db2`, decoded to `retail_1215/aux/`.
- **Encryption:** in 12.x one section of Species / SpeciesState / SpeciesXAbility is under an unknown key
  (`bbd411bea4522afe`). That loses 4 species, 12 state rows and 24 ability links.
- **Target 12.1.5.**
  - Breed rules and BreedQuality (rolls 40/60/80/96/99/100, multipliers 0.50-0.75) are identical across
    builds.
  - The full collectible set needs only 11 effect types more than MoP.
  - The MoP install lacks the species table altogether.

## 4. Pets: coverage against DC

**12.1.5 has 2,185 collectible species** (no HideFromJournal) and 820 NPC-only.
- Families: Beast 456, Flying 315, Critter 293, Aquatic 260, Magic 206, Elemental 192, Mechanical 128,
  Humanoid 125, Undead 110, Dragonkin 100.
- 646 are Capturable; 116 are CantBattle (companion only).
- 1,626 have a SummonSpellID. Most of those without one are caught in the wild, where the battle pet itself
  is the collectible.

**Cross-reference with DCCollectionSource** (file `species_to_dc.csv`, column `DCStatus`):

| Status | Count | Notes |
|---|---|---|
| In the DC catalog | 1,547 | 153 by spell/creature id, **1,394 by name only, which needs review** |
| Spell present, not in catalog | 20 | e.g. Egbert, Peanut, Tiny Snowman |
| Missing entirely | 618 | 316 wild captures, 137 drops, 53 vendor, 22 quest, 20 world event, 17 profession, 17 discovery, 16 achievement, 20 other; 22 are CantBattle |
| DC pets with no species | 225 | Turtle Egg variants, Baby Devilsaur, Aether Serpent, Ascension pets… (`dc_pets_without_species.csv`) |

**What this means:**
- **The mapping must be a table.** DC's ported pets use their own ids, so species↔DC pet cannot be
  computed at runtime. It needs a reviewed table (species id → DC pet entry, spell, creature).
- **Retail summon spell ids can't be imported unchanged.** 50 of them collide with unrelated DC custom
  spells (e.g. 301015 is Zanj'ir Poker in retail and "Hand of Hrestimorak" in DC).
- **What the 618 missing species need:**
  - creature_template and display rows;
  - the model, where DC lacks it (the pet roster downport pipeline);
  - a way to summon. That is either a summon spell each, or **one generic "summon battle pet" spell whose
    creature a SpellScript picks from the journal pet**. The generic spell avoids about 600 new Spell.dbc
    rows.
- **The 225 DC-only pets** either get species data assigned (family, 6 abilities, base stats, copied
  from a similar species) or are marked companion-only.

## 5. Abilities (the "spells")

- **Counts (12.1.5):** 1,404 abilities, 1,650 turns, 2,829 effects, 136 effect property types and 123
  states.
- **What collectible species use:** 758 abilities, or 1,072 counting the aura abilities they apply.
  - Effects reference **104 distinct effect property types**; the collectible set needs **79**.
  - MoP lacks 11 of those 79: 112, 223, 226, 229, 230, 246, 249, 254, 370, 384, 385.
- **Usage is very concentrated** (full list with param labels in `retail_1215/_effect_property_usage.csv`):
  - 24 (Points/Accuracy/IsPeriodic, the standard hit): 945 uses;
  - 26: 241; 50 (aura apply): 194; 49: 138; 23: 115; 222: 90; 31 (set state): 86; 54: 77.
  - After those it falls off fast.
- **Tooltips:**
  - Ability descriptions use Blizzard's formula language (`[StandardDamage(1,1)]`…).
  - The parser is `Blizzard_FrameXML/SharedPetBattleTemplates.lua` (575 LOC, MoP Classic). It relies on
    `loadstring` + `setfenv`, which Lua 5.1 has, so it ports as-is and gives exact numbers per pet power.
  - It also documents how damage and healing scale, which is a free spec for the engine.
- **Visuals:**
  - BattlePetVisual: 1,051 rows → **927 distinct modern SpellVisualIDs**, 231 of them SceneScript-driven.
  - None has a 3.3.5 equivalent, and there is no visual-kit downport pipeline.
  - v1 has to map abilities onto a curated set of about 60-100 visual-only 3.3.5 spells (bite, claw,
    fire bolt, frost, shadow, heal, shield, weather…), chosen by family and keywords, with per-ability
    overrides later.
- **Icons:** 2,466 distinct icons (1,790 species, 831 abilities), **all resolvable** to
  `interface/icons/` paths (`retail_1215/_icon_paths.csv`). 30,682 retail icons are already extracted under
  `K:\Dark-Chaos\WoW 11.2.5 PTR interface extract\icons`. The work left is the usual pass: which ones are
  missing from the client patch.

## 6. Server-only data (no client carries it)

**Live on the ACMCP MySQL server:**

| Source | Table | Rows | Coverage |
|---|---|---|---|
| `bfa_world` (HavenCore; the same set is in LegionCore, SylvaniaCore, shadowcore and 9.2.7 repacks) | `battlepet_npc_team_member` | 8,823 | 1,509 NPCs. The 834 with 1-3 pets are tamer teams (~70 named tamers: Julia Stevens, Old MacDonald, Pandaren Spirits, Aki…); the 675 with 4+ are wild-add pools. Covers 405 of the 820 NPC-only species |
| | `battlepet_info` | 1,405 | per-creature species, levels, minimum quality, breed mask, 3 abilities |
| | `battlepet_wild_zone_pool` | 1,082 | 98 zones, 640 species (316 of the 630 collectible wild ones); max alive, respawn, levels |
| | `battlepet_spawn_relation` | 265 | critter entry → battle pet entry |
| `skyfire_world` (MoP 5.4.8) | `battle_pet_breed` / `_quality` / `_wild_pool` / `_item_to_species` | 1,610 / 1,549 / 378 / 363 | breeds for 814 species (breeds 3-12 only) |
| `TC_Cata_world` | `battle_pet_breeds` / `_quality` | 397 / 223 | 223 species |

**On disk:**
- `K:\Dark-Chaos\tc master\TDB_full_world_1200.26021_2026_02_06.sql`: `battle_pet_breeds` 2,884 rows /
  998 species (breeds 3-22) and `battle_pet_quality` 998. Identical to TDB 927, so TC added nothing after
  9.2.7.
- SylvaniaCore `sql/updates/world/2025_08_08_00_world.sql`: the same Firestorm set, plus
  `battlepet_template` (breed mask and minimum quality for 1,312 species).

**All sources combined** (collectible battle species = 2,079):
- breeds 954; quality 900;
- wild pools 321 of 630 wild species;
- NPC teams 405 of 820 NPC-only species.
- Nothing covers the 782 species added after 9.2.7.

**Gaps need defaults:**
- **Breeds:** use the family-typical breed set, or the community BattlePetBreedID dataset (external
  download, not on disk).
- **Quality:** Rare for anything that isn't caught in the wild.
- **Wild pools:** zone placement is DC content design anyway, because half the retail zones don't exist
  here.

## 7. Engine: donor survey and the provenance problem

| | LegionCore 7.3.5 | **SylvaniaCore 7.3.5** | BFA-HavenCore | shadowcore | SkyFire 5.4.8 | UWoW WoD |
|---|---|---|---|---|---|---|
| Lineage | Millenium/Firestorm original | LegionCore via DestinyCore + 2026 fixes | same engine, BfA port + 2026 fixes | ≈ HavenCore | independent (Jul-Oct 2026) | independent (2015) |
| Engine LOC | 6,218 | 6,256 | 6,088 | 6,033 | 4,660 (+2,630 tests) | 2,665 |
| Effect handlers | 73 / 235 | 73 / 235 | 73 / 235 | 73 / 235 | ~15 | none (all damage) |
| Family passives, type matrix, hit/crit | yes | yes | yes | yes | no | no |
| NPC tamers | yes | yes | no | no | no | no |
| Wild battles with adds | disabled | disabled | disabled | disabled | 1 enemy | no |
| PvP duel + queue | yes | yes | yes | yes | plumbing | skeleton |
| Header | **"Millenium-studio SARL, All Rights Reserved"** | GPL-2+ (relabel) | GPL-3+ (relabel) | GPL-2+ (relabel) | GPL-3 | GPL-2+ |

**Coverage of the Legion lineage:**
- **Handler table:** 73 real handlers (65 functions) and 155 `HandleNull`. Checked by counting the table in
  SylvaniaCore `PetBattleAbilityEffect.cpp`.
- **Against 9.2.7 data:** 74 of the 108 effect ids used are handled, which is 95.8% of effect rows. 801
  of 830 learnable abilities are fully handled.
- **Legion-era species:** 623 of 637 abilities are fully handled.
- **Missing:** 159 "select next target", 144 "select dead target", 229/230/223/233/234, and the
  post-Legion ids above 234.
- **For full 12.1.5:** about 30 more handlers to cover every effect type, fewer for the collectible set
  alone.

**Bugs present in every copy** (SylvaniaCore line numbers), to fix in any port:
- Crit is rolled on the target's crit chance instead of the caster's (`PetBattleAbilityEffect.cpp:499`).
- Whole-team targeting stops after the first pet (:735, :806). As a result, split damage (effect 141) hits
  one pet.
- The effect-id bound check uses `>` and does not return (:779).
- Mechanical/Undead revive likely never fires. `Kill` sets CATCH_OR_KILL first (`PetBattle.cpp:1754`
  → :1574), and the revive is cast by the killer.
- The forfeit penalty is applied only when the client asks to skip it (`PetBattle.cpp:1256`).
- The wild-adds search is commented out (`BattlePetHandler.cpp:255`).
- Smaller issues: every cast does full table scans; it keeps raw `Creature*` pointers in the wild pools;
  it uses `rand()`.

**Porting SylvaniaCore means:**
- **Keep and adapt (~6,260 LOC):**
  - `PetBattleAbilityEffect.cpp/.h` (1,892): nearly as-is, no packets;
  - `PetBattle.cpp/.h` (2,438): 14 packet sends, 11 achievement and 5 quest calls to replace;
  - `PetBattleSystem.cpp/.h` (773): duel and queue;
  - `WildBattlePet.cpp/.h` (471);
  - `BattlePetDataStore.cpp/.h` (416);
  - `PetBattleTrainer.cpp` (266).
- **Rewrite as the DC protocol module:** `BattlePetHandler.cpp` (1,426). Drop
  `BattlePetPackets.cpp/.h` (1,213).
- **Rebuild:** about 300 LOC of Player/Map/World integration.
- **Keep** the engine single-threaded on the world thread; addon messages are already handled there.

**Options (decision needed):**

| | A. Port SylvaniaCore | B. Own engine |
|---|---|---|
| Effect coverage at start | ~96-98% of rows on day one | built up handler by handler, most-used first (the top 8 types cover two thirds of all effect rows) |
| Spec | the code | DB2 param labels + every ability description per effect type + Blizzard's tooltip parser (damage/heal scaling) + public mechanics (Warcraft Wiki) |
| Size | ~6.3k LOC to adapt + bug fixes | ~5-7k LOC new, tests from the start |
| Provenance | Millenium code; "All Rights Reserved"; GPL relabels don't change that | clean |
| Fit | TC-7.3.5 style, raw pointers, `rand()` | written to AC conventions (`ObjectGuid`, `urand`, EventMap/TaskScheduler) |

**My recommendation is B,** and it is your call. The fork is a GPL-2 repo, and you have already chosen to
reimplement rather than copy when licensing was in doubt (the WXL staged-model finalize in darkclient335).
If you take A, isolate it in its own directory so it can be swapped out later.

**SkyFire 5.4.8 (GPL-3):** the engine is too shallow to use, but its test style and XP helpers are worth
reading.

## 8. World presence on 3.3.5

**Wild pets:**
- **Almost none of retail's wild battle-pet creature entries exist in our world DB:** 0 of the 264 in
  `battlepet_spawn_relation`, and 115 of the 641 in the zone pool (24 of those spawned). That doesn't
  matter, because the 3.3.5 critters are already spawned everywhere:
  - Rat (4075): 841 spawns; Snake (2914): 695; Rabbit (721): 586; Squirrel (1412): 561;
  - Toad: 369; Frog: 368; Spider: 335; Roach: 210; Adder: 200; Black Rat: 190; Arctic Hare: 172; …
- `battlepet_spawn_relation` maps 58 critter entries that exist in our DB.
- **Approach, which is retail's own:** turn a share of the critter spawns in each zone into wild battle
  pets at runtime:
  - species, level, quality and breed are rolled per spawn and kept in memory, keyed by spawn guid;
  - the zone pool table sets how many per zone;
  - the creature's level field is set to the pet level, so the stock target frame shows "Level 5 Rat";
  - a per-instance gossip npc flag is added.
- **Interaction:** right-clicking sends CMSG_GOSSIP_HELLO, and the server starts the battle instead of
  showing a menu. That works on both clients. 3.3.5 has no wild-battle-pet NPC flag or creature type.
- **Indicators:** paw icon and family on target frames, plus map/minimap pins, all from the addon (the
  MPOI infrastructure exists).

**Tamers:**
- 156 of the 1,509 team NPCs exist in our world DB, and only 23 are spawned.
- They need importing: creature_template from `skyfire_world`/`bfa_world` adapted to AC (see memory
  `creature-template-schema-drift`), spawns and gossip.
- Or DC places its own tamers in its hubs and custom zones and reuses the team rows.
- Quest credit through `KilledMonsterCredit`.

**Staging a battle:**
- **Field selection:** pick a centre at the wild pet, or between player and tamer. Place two pet spots
  about 8 yd apart and the two owners behind them. Check ground height with vmaps (`GetHeight`) and LoS;
  rotate the axis in 30° steps until it fits, or refuse ("not enough room").
- **Players and pets:**
  - NearTeleport the player to their spot, root them, and make them unattackable and evade-proof;
  - battles can't start in combat; logout, teleport or death forfeits;
  - the active pets are TempSummons visible to everyone, and benched pets are not shown, as in retail.
- **Animation:**
  - creature emotes for attack, wound, cast and death, plus a dead stand state;
  - abilities show as visual-only dummy spells cast pet → pet (the section 5 mapping).
- **Weather:** send SMSG_WEATHER to the participants only, so retail's Blizzard, Mudslide/Cleansing Rain
  and Sandstorm become snow, rain and sandstorm.
- **Timing:** the server plays each round as a timeline (EventMap/TaskScheduler), then opens input with
  the turn timer.

## 9. Client

**Battle HUD:**
- Port MoP Classic `Blizzard_PetBattleUI` (wow-ui-source `origin/classic` = 5.5.4 build 70631;
  Shared/Blizzard_PetBattleUI.lua 1,959, .xml 1,668, Patchwerks.xml 152).
- In retail this is only a HUD: unit frames, auras, weather, ability bar, Switch / Catch / Forfeit, timer,
  XP, pet select. The engine does the arena and the camera, which is why section 8 exists.
- Build it on the **DC-Talents retail runtime**, which already runs verbatim retail Lua and converted XML
  on 3.3.5:
  - `Templates.lua` XML interpreter, `Animations.lua` (retail AnimationGroup behaviour, which covers the
    27 child-key animations and the fromAlpha/toAlpha cases the HUD uses), `Engine.lua`, pools, atlases,
    `RetailAPI.lua`, `DC/Standins.lua`;
  - tools `xml2lua.py`, `sync_retail.py`, `convert_art.py`, `lua51_check.py`, plus a strict 3.3.5
    simulator in `_tests/`.

**API to emulate** in Lua, from protocol state:
- **55 `C_PetBattles` functions;** about 15 `PET_BATTLE_*` events drive the HUD, and about 20 more cover
  queue, capture and loot.
- **62 `C_PetJournal` functions,** only if the Blizzard journal is ported (see Journal below).
- Full lists are in the appendix "API surface". The core is GetActivePet,
  GetHealth/MaxHealth/Power/Speed, GetAbilityInfo/State, GetAuraInfo, UseAbility, ChangePet, UseTrap,
  ForfeitGame, SkipTurn and GetTurnTimeInfo.

**Tooltips:** port `SharedPetBattleTemplates.lua/.xml` (575/115), `FloatingPetBattleTooltip` (174/151) and
`BattlePetTooltip` (54/9).

**Journal:**
- **Extend DC-Collection rather than port `Blizzard_PetCollection`.** The Blizzard journal (1,769 lua /
  1,714 xml) leans on ModelScene, ScrollBox, MenuUtil and 29 atlases.
- **What to add:**
  - level and quality on the list rows (`CreatePetButton`, ~line 578);
  - stats, breed, family and the 3×2 ability picker in the `SelectPet` header (~line 940);
  - a new 3-slot loadout panel;
  - rename, release and cage.

**Art:**
- 49 `Interface/PetBattles` BLPs already extracted in `K:\Dark-Chaos\WoW 11.2.5 PTR interface
  extract\petbattles` (PNG copies in `wow-ui-textures/PetBattles`).
- `DC-Journal/Interface/SharedXML/AtlasStorage.lua` already defines 63 pet battle atlases, but **the
  textures ship nowhere, so those atlases draw blank today.**
- Run them through DC-Talents `convert_art.py` and pack them into a client patch, together with the
  Icon_PetFamily_* icons and the missing ability and species icons.

**Static data:** generated Lua files in the addon (species, abilities with turn/effect params for the
tooltip parser, states, breed tables, damage matrix, XP), roughly 1-2 MB. This works on both clients
without new natives. Move it to CDBC later only if load time hurts.

**3.3.5 model limits:**
- PlayerModel and DressUpModel snap any non-Stand animation back every frame; `SetSequence` refuses ids
  above 505.
- Use `SetModelAnimation` (both clients) for the pet cards.
- 3.3.5 has no ModelScene or camera control in widgets.

**Native client extras** (optional, capability-gated):
- **Battle camera:** a new native on `WoW/Source/UIUtil/Camera.cpp`, which already has SetTarget,
  MakeRelativeTo, ZoomToDistance and SetDesiredPitch/Yaw.
- **Floating numbers over the pets:** `ConvertCoordsToScreenSpace` + `ResolveEntityPositionByGUID` in
  `DarkChaos_World.cpp`.
- **On the old client:** numbers centre-screen or anchored to nameplates, and an addon-side SetView preset.

## 10. Proposed architecture

**Server, under `src/server/scripts/DC/PetBattles/`:**
- **Data store:** loads `dc_battle_pet_*` world tables, which are generated from the kit's CSVs.
- **Pet instance math:** stats from SpeciesState + BreedState + quality multipliers + level.
- **Battle:** 2 teams × 3 pets, rounds, speed order, multi-turn abilities, auras and states, weather/pad,
  swap, trap, forfeit, XP.
- **Effect handlers.**
- **Wild pet manager:** critter conversion, zone pools, respawn; spawn guids only, no raw pointers.
- **Tamers, PvP duel + queue.**
- **Staging** (section 8).
- **Protocol module** `AddonExtension/dc_addon_petbattle.cpp` (`PETB`).
- **Registration:** a single `AddPetBattleScripts()` in `dc_script_loader.cpp`.
- **Tests:** engine classes free of Player and Map wherever possible, with Google tests in `src/test`
  using a seeded RNG.

**Databases:**
- **World:** the 11 DB2 tables + 2 game tables, `dc_battle_pet_breeds`, `_quality`, `_npc_team`,
  `_wild_pool`, `_critter_map`, and `dc_battle_pet_species_map` (species ↔ DC pet entry, spell,
  creature).
- **Characters:**
  - `dc_battle_pets`: uint64 id, account, species, breed, quality, level, xp, health, name, flags,
    3 ability choices;
  - `dc_battle_pet_slots`: account, slot 0-2, pet id, locked.
- **Account-wide, as in retail.** Up to 3 pets per species unless the species is unique.
- **Create through the grant path:** learning a companion → `OnPlayerLearnSpell` /
  `DCCollection::GrantCollectible` → create a battle pet. The existing 13 `dc_collection_items` pet rows
  become level 1 pets.

**Protocol (`PETB`, JSON):**

| Direction | Messages |
|---|---|
| Client → server | REQUEST_WILD, REQUEST_PVP (duel), QUEUE_JOIN/LEAVE, INPUT (ability / swap / trap / skip / forfeit), SET_LOADOUT, SET_ABILITY, RENAME, RELEASE, CAGE, HEAL |
| Server → client | JOURNAL (pets + slots), INIT (full battle state), ROUND (ordered event list: health, aura apply/change/cancel, state set, swap, weather, ability use, miss/dodge/crit, death), FINAL, FINISHED (xp, levels, capture), ERROR, QUEUE_STATUS, DUEL_REQUEST |

- One round is about 0.5-1.5 KB, or 2-6 chunks on the old client.
- Mirroring retail's round events keeps the C_PetBattles emulation thin.

## 11. Phases

| Phase | Work |
|---|---|
| 0. Decide | engine route (A/B), data target (12.1.5), v1 scope (PvE first, PvP later), breed-gap default |
| 1. Data | generator: kit CSVs → world SQL + addon Lua; reviewed species↔DC map (the 1,394 name matches); merge breeds, quality and teams from TDB 1200 + SkyFire + the Firestorm set; icon and art packaging |
| 2. Journal | characters tables, grant/learn hooks, migration of the 13 rows, loadout/abilities/rename/release, DC-Collection UI changes, summon through the mapped companion spell |
| 3. Engine | battle loop + the most-used effect types first; tests; GM commands (`.bpet add/level/heal/battle <npc>`); PETB INIT/ROUND/INPUT; a bare HUD |
| 4. World | staging, visual-spell mapping (Spell.dbc rows for both clients), weather, wild conversion + capture/traps, tamer battles |
| 5. UI | full Blizzard HUD port on DC-Talents' runtime, tooltip parser, target-frame paw and pins, native camera and floating numbers |
| 6. Content | tamers for DC zones, dailies, achievements, rewards and items (bandages, stones, treats), stable-master healing, PvP duel + queue |
| 7. Completion | the 618 missing species (creature/display/model downport + generic summon), species data for the 225 DC-only pets, remaining effect types up to all 104 |

## 12. Open decisions

1. Engine: port SylvaniaCore, or write our own (section 7).
2. Data target: retail 12.1.5 (recommended) or MoP only.
3. Journal UI: extend DC-Collection (recommended) or port Blizzard_PetCollection.
4. Breed gap for 1,125 collectible species: family defaults, or fetch the BattlePetBreedID dataset.
5. The 225 DC-only pets: give them battle data, or keep them companion-only.
6. Levels: retail 1-25 (recommended; independent of character level 255).

## 13. Special arenas and instanced pet battle content

**Normal battles (wild, tamer, PvP duel) have no arena.** They are fought where they start. The donor
engine computes a centre and two team spots around the opponent and checks them for collisions with
`getObjectHitPos`.

**PvP queue (donor engine):**
- Both players are moved to one of 7 fixed open-world spots: 4 Alliance spots on map 0 and 3 Horde spots
  on map 1, plus one commented out. See SylvaniaCore `PetBattleSystem.cpp:338`.
- Not verified against retail.

**Retail instanced pet battle maps** (`Map.db2`, 12.1.5):

| Map | Name | InstanceType |
|---|---|---|
| 1161 | Celestial Tournament (MoP) | 5 (scenario) |
| 1687 | Wailing Caverns pet battle dungeon | 5 |
| 1688 | Deadmines pet battle dungeon | 5 |
| 1694 | Gnomeregan pet battle dungeon | 5 |
| 2179 | Stratholme Pet Dungeon | 5 |
| 2282 | Blackrock Depths - Pet Dungeon | 5 |
| 1032 | "Pet Battle - Jade Forest" (MoP) | 1. No content anywhere; looks unused or a test map |

**No local source has content for them:**
- Zero creature spawns on all seven maps in `bfa_world` and `skyfire_world`.
- LegionCore's `scripts/Scenario/BattlePetInstance/*` and `CelestialTournament/*` are empty instance
  shells, 301 LOC in total.
- Team rows exist for only 52 of the 192 Boss-flagged species; most pet-dungeon bosses have none.

**For DC:**
- None of this is needed for the core system.
- The five pet dungeons are copies of dungeons we already have as 3.3.5 maps (43, 36, 90, 329, 230). They
  can be rebuilt there as a separate instance mode or phase without porting a map, but the boss teams have
  to be designed.
- The Celestial Tournament can be a DC event anywhere.
- PvP can use fixed spots in DC hubs, or one dedicated arena.

## Appendix: kit contents (`K:\Dark-Chaos\retailextracts\_battlepets_20261109\`)

- **Decoded tables:** `mop_554\`, `sl_927\`, `retail_1207\`, `retail_1215\` (one CSV per table +
  `_manifest.json` with encryption info).
- **retail_1215 extras:** `_effect_property_usage.csv`, `_icon_paths.csv`, the two game tables, and
  `aux\Creature.csv` / `SpellName.csv`.
- **Mapping:** `species_to_dc.csv` (3,005 species, `DCStatus` column) and `dc_pets_without_species.csv`.
- **Server-only dumps:** `server_sql\`, one CSV per source table (HavenCore, LegionCore, shadowcore,
  SylvaniaCore, SkyFire, two TC 9.2.7 repacks) plus the TDB 1200 breed/quality tuples; coverage numbers
  in `_server_sql_coverage.txt`.
- **Analysis:** `_analysis_steps1-5.txt`, `_xref_dc.txt`.
- **Scripts:** `_scripts\` (bp-batch.js, analyze.py, xref_dc.py, sqlscan.py, server_cov.py).
- **Engine coverage:** `engine_coverage\` (coverage.py, coverage_legion.py + the 9.2.7 DB2 decode they
  read).

**Sources:**
- MoP Classic 5.5.4 and retail 12.0.7 = `K:\UntouchedClients\World of Warcraft 12.07` (`wow_classic` /
  `wow`);
- retail 12.1.5 = `I:\World of Warcraft`;
- 9.2.7 = `K:\Dark-Chaos\SL stuff\[9.2.7] DekkCore Donor Repack 9.2.7\Clientdata`.

## Appendix: API surface (MoP Classic 5.5.4 UI, wow-ui-source `origin/classic`)

The union of what Blizzard_PetBattleUI, the shared pet battle templates and Blizzard_PetCollection call.
This is what an emulation layer has to provide.

**C_PetBattles (55):** AcceptPVPDuel, AcceptQueuedPVPMatch, CanAcceptQueuedPVPMatch,
CanActivePetSwapOut, CanPetSwapIn, CancelPVPDuel, ChangePet, DeclineQueuedPVPMatch, ForfeitGame,
GetAbilityEffectInfo, GetAbilityInfo, GetAbilityInfoByID, GetAbilityProcTurnIndex, GetAbilityState,
GetAbilityStateModification, GetActivePet, GetAllEffectNames, GetAllStates, GetAttackModifier,
GetAuraInfo, GetBattleState, GetBreedQuality, GetDisplayID, GetForfeitPenalty, GetHealth, GetIcon,
GetLevel, GetMaxHealth, GetName, GetNumAuras, GetNumPets, GetPVPMatchmakingInfo, GetPetSpeciesID,
GetPetType, GetPlayerTrapAbility, GetPower, GetSelectedAction, GetSpeed, GetStateValue,
GetTurnTimeInfo, GetXP, IsInBattle, IsPlayerNPC, IsSkipAvailable, IsTrapAvailable, IsWaitingOnOpponent,
IsWildBattle, SetPendingReportBattlePetTarget, ShouldShowPetSelect, SkipTurn, StartPVPDuel,
StartPVPMatchmaking, StopPVPMatchmaking, UseAbility, UseTrap.

**C_PetJournal (62, only if the Blizzard journal is ported):** CagePetByID, ClearFanfare,
ClearHoveredBattlePet, ClearRecentFanfares, FindPetIDByName, GetBattlePetLink, GetNumCollectedInfo,
GetNumPetSources, GetNumPetTypes, GetNumPets, GetNumPetsNeedingFanfare, GetOwnedBattlePetString,
GetPetAbilityInfo, GetPetAbilityList, GetPetAbilityListTable, GetPetCooldownByGUID, GetPetInfoByIndex,
GetPetInfoByPetID, GetPetInfoBySpeciesID, GetPetLoadOutInfo, GetPetModelSceneInfoBySpeciesID,
GetPetSortParameter, GetPetStats, GetPetSummonInfo, GetPetTeamAverageLevel, GetSummonBattlePetCooldown,
GetSummonedPetGUID, HasFavoritePets, IsFilterChecked, IsFindBattleEnabled, IsJournalUnlocked,
IsPetSourceChecked, IsPetTypeChecked, IsUsingDefaultFilters, PetCanBeReleased, PetIsFavorite,
PetIsHurt, PetIsLockedForConvert, PetIsRevoked, PetIsSlotted, PetIsSummonable, PetIsTradable,
PetNeedsFanfare, PickupPet, PickupSummonRandomPet, ReleasePetByID, SetAbility,
SetAllPetSourcesChecked, SetAllPetTypesChecked, SetCustomName, SetDefaultFilters, SetFavorite,
SetFilterChecked, SetHoveredBattlePet, SetPetLoadOutInfo, SetPetSortParameter, SetPetSourceChecked,
SetPetTypeFilter, SetSearchFilter, SpellTargetBattlePet, SummonPetByGUID, SummonRandomPet.

**Events that drive the HUD (all `PET_BATTLE_*`):** OPENING_START, OPENING_DONE, PET_CHANGED,
PET_TYPE_CHANGED, ACTION_SELECTED, HEALTH_CHANGED, MAX_HEALTH_CHANGED, XP_CHANGED, AURA_APPLIED,
AURA_CHANGED, AURA_CANCELED, OVERRIDE_ABILITY, PET_ROUND_PLAYBACK_COMPLETE, OVER, CLOSE.

**Events for the rest of the UI:**
- `PET_BATTLE_*`: FINAL_ROUND, CAPTURED, LOOT_RECEIVED, LEVEL_CHANGED, PVP_DUEL_REQUESTED,
  PVP_DUEL_REQUEST_CANCEL, QUEUE_PROPOSE_MATCH, QUEUE_PROPOSAL_ACCEPTED, QUEUE_PROPOSAL_DECLINED,
  QUEUE_STATUS.
- `PET_JOURNAL_*`: TRAP_LEVEL_SET, NEW_BATTLE_SLOT, LIST_UPDATE, PET_DELETED, PETS_HEALED, CAGE_FAILED.
- Other: BATTLE_PET_CURSOR_CLEAR, COMPANION_UPDATE, UI_MODEL_SCENE_INFO_UPDATED,
  CHAT_MSG_PET_BATTLE_COMBAT_LOG, CHAT_MSG_PET_BATTLE_INFO, UPDATE_SUMMONPETS_ACTION.

**Enums:** BattlePetOwner, BattlePetAction, PetbattleState, BattlePetSources, PetJournalError.
