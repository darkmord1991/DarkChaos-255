# Playerbot Cosmetics

Visual variety for mod-playerbots bots: mounts, companions, shapeshift forms and
pet skins. Nothing here touches bot stats, spells or behaviour.

## Where the code lives

The feature is split along the library boundary, not by preference: `modules.lib`
and `scripts.lib` do not link each other (see the note at the top of
`DCGroupFinderBots.cpp`).

| Part | File | Why there |
| --- | --- | --- |
| Mounts, companions, pet skins | `modules/mod-playerbots/src/Script/DCBotCosmetics.cpp` | Bot behaviour, bot data. Registered from `Playerbots.cpp` next to `AddSC_dc_groupfinder_bots()`. |
| Shapeshift form skins | `src/server/scripts/DC/AddonExtension/dc_addon_forms.cpp` | The form catalog and the `ObjectMgr::GetModelForShapeshift` provider live in scripts.lib; the module cannot reach them. The bot roll is ~60 lines in the file that already owns the data. |

## What each bot gets

| Feature | Source data | How it is applied |
| --- | --- | --- |
| Mounts | `acore_world.dc_mount_definitions` (1526 rows) | Bots *learn* the spells, so `CheckMountStateAction` picks among them unchanged. |
| Companion pet | `acore_world.dc_pet_definitions` (1898 rows) | Cast on login, re-cast on zone change if the critter slot went empty. |
| Shapeshift forms | `acore_world.dc_shapeshift_form_skins` | Fed into the existing display provider — in memory only, no row in `dc_character_shapeshift_form`. |
| Warlock minions | `acore_playerbots.playerbots_demon_skins` (173 rows, new) | `PetScript::OnPetAddToWorld` → `SetDisplayId`. Entry, family, stats and abilities are untouched. |
| Hunter pets | `acore_world.dc_beastmaster_pets` joined to `creature_template_model` | Same hook; re-skinned to another model **of the same beast family**. |

Only the bot-specific table is new, and it sits in the module's own database next
to `playerbots_preferred_mounts`. The mount / pet / form catalogs are shared with
players and stay in `acore_world`.

## Stable identity

Every pick comes from a splitmix64 finalizer over the character GUID. A bot
therefore keeps the same mounts, the same companion, the same cat skin and the
same imp for its whole life — across logins and worldserver restarts — with no
per-bot table, no cache to invalidate and no DB writes beyond the mount spells
themselves.

Hunter pet skins additionally salt on the tamed creature entry, so a bot that
re-tames gets a new look while a given pet keeps its own across summons.

## Mount tiers

The four tiers mirror `CheckMountStateAction`'s own mount slots, derived at load
time from the spell itself (not `dc_mount_definitions.speed`, which is a display
value), and gated by the module's existing level thresholds:

| Tier | Condition | Gate |
| --- | --- | --- |
| Slow ground | aura 78, no flight aura, speed < 99 | `AiPlayerbot.UseGroundMountAtMinLevel` (20) |
| Fast ground | aura 78, no flight aura, speed >= 99 | `AiPlayerbot.UseFastGroundMountAtMinLevel` (40) |
| Slow flying | aura 207 present, speed < 279 | `AiPlayerbot.UseFlyMountAtMinLevel` (60) |
| Fast flying | aura 207 present, speed >= 279 | `AiPlayerbot.UseFastFlyMountAtMinLevel` (70) |

Note on the catalog's shape: the ~1250 DC retroported mounts are all epic ground
(99) or 310% flyers, so they land in the two *fast* tiers. The slow tiers are
stock 3.3.5 mounts only. `dc_mount_definitions.class_mask` is 0 for every row, so
the handful of genuinely class-locked mounts (Acherus Deathcharger, Winged Steed,
Argent Charger, paladin/warlock steeds) are gated by a small table in the script.

`AiPlayerbot.DCCosmetics.Mounts.MaxSpellId = 299999` keeps bots on stock mounts
and leaves the 300000+ retroport band as a player-only flex.

## Warlock demon skin pool

`playerbots_demon_skins` is seeded from the `CreatureDisplayInfo` →
`CreatureModelData` master CSVs under `Custom/CSV DBC/`, matched by demon model
directory (`Creature/Imp/`, `Creature/VoidWalker/`, `Creature/Succubus/`,
`Creature/Felhound/`, `Creature/FelGuard/`, `Creature/DoomGuard/` and their
Outland/retroport siblings), then gated twice:

1. the display must have a `creature_model_info` row, and
2. it must already be worn by a creature in `creature_template_model`, which
   proves the M2 resolves in the deployed client MPQ chain.

Result: 28 imp / 38 voidwalker / 20 succubus / 13 felhunter / 40 felguard /
34 doomguard.

Oversized models are counter-scaled through `SetDisplayId(id, scale)` against
`AiPlayerbot.DCCosmetics.PetSkins.MaxScale`, so a downported boss-sized demon does
not tower over its owner.

## Config

| Key | File |
| --- | --- |
| `AiPlayerbot.DCCosmetics.*` (9 keys) | `modules/mod-playerbots/conf/playerbots.conf.dist` |
| `DC.AddonProtocol.Forms.BotSkins` | `Custom/Config files/darkchaos-custom.conf.dist` |

`.reload config` re-reads the module keys *and* rebuilds the pools, so catalog
edits do not need a restart.

## Deploying

1. Apply
   `modules/mod-playerbots/data/sql/playerbots/updates/2026_09_06_00_playerbots_demon_skins.sql`
   to `acore_playerbots` (or let the DB updater pick it up).
2. Re-run CMake configure — `DCBotCosmetics.cpp` is a new file and the module
   source glob is cached.
3. Rebuild worldserver.
4. Copy the new config keys into the live `playerbots.conf` and
   `darkchaos-custom.conf`.
