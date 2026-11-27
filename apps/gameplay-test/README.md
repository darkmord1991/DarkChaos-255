# DarkChaos gameplay test harness (v1)

Repeatable gameplay scenarios executed **inside the running worldserver**, with its real DBCs,
database, scripts, maps and updates. A scenario is a JSON file: it names characters of one lab
account, a list of steps (teleport, cast, spawn, add items, ...) and assertions on what the game
then reports (health, auras, stats, item upgrade level, Mythic+ state, ...). Every run writes a
JSON report.

- Server side: `src/server/scripts/DC/GameplayTest/` (`.dca test ...`, registered by
  `AddSC_dc_gameplay_test()`).
- This directory: `run.py` (SOAP runner and offline validator) and `scenarios/` (examples).

It complements the protocol-level suite in `e2e/` (AzerothGhost clients against a live stack, stock
behaviour): this harness needs no client or authserver, runs DC systems through their own C++ APIs,
and observes state directly instead of through packets.

## Safety rules

1. **Off by default.** Nothing happens unless `DC.GameplayTest.Enable = 1`.
2. **Lab account only.** Actors must be characters of `DC.GameplayTest.Account`; a character of any
   other account is refused before anything touches it. Accounts named like random-bot accounts
   (`Playerbots.RandomBotAccountPrefix`) are refused, since the bot rotation would log them out.
3. **Administrators only.** All `.dca test` commands are `SEC_ADMINISTRATOR`. Console and SOAP are
   allowed; in game the commands are accepted only from the lab account itself.
4. **Private phase.** Actors are put in `DC.GameplayTest.PhaseMask` through an exclusive phase layer
   (id 100), and everything the run spawns gets the same mask, so real players neither see nor
   touch the run. A mask containing the normal phase (bit 1) is refused. An online actor in GM mode
   is refused (GM mode sees every phase); if anything moves an actor out of the mask mid-run the
   report carries a warning.
5. **References only.** Steps act on actors and on objects the run spawned, nothing else.
6. **Destructive needs two keys.** Steps that change persistent progression (`prestige`) need
   `"destructive": true` in the scenario **and** `DC.GameplayTest.AllowDestructive = 1`.
7. **Cleanup always runs**, also after a failure, an abort, a timeout or a server shutdown: spawns are
   despawned (and carry a timed despawn as a safety net), actors are revived and restored as the
   `cleanup` policy says, headless actors are parked back at the lab location, logged out (saved) and
   their sessions deleted.

## Setup

1. Create a lab account (not a bot account), e.g. `account create gptlab <password>`. Its security
   level does not matter: headless test sessions always run as `SEC_PLAYER`.
2. Add the config block to the worldserver config (`darkchaos-custom.conf`):

   ```ini
   DC.GameplayTest.Enable = 1
   DC.GameplayTest.Account = "gptlab"
   DC.GameplayTest.ScenarioDir = "gameplay-tests/scenarios"
   DC.GameplayTest.OutputDir = "gameplay-tests/reports"
   DC.GameplayTest.PhaseMask = 2147483648
   DC.GameplayTest.MaxRunMs = 600000
   DC.GameplayTest.MaxActors = 5
   DC.GameplayTest.MaxSpawns = 50
   DC.GameplayTest.AllowCreateCharacters = 1
   DC.GameplayTest.AllowDestructive = 0
   ```

   Relative directories resolve against the worldserver's working directory.
3. Copy scenarios into the scenario directory (`run.py run --sync-to <dir>` does it per run).
4. For the runner: `SOAP.Enabled = 1` in `worldserver.conf`, and an administrator account in the
   environment as `DC_SOAP_USER` / `DC_SOAP_PASSWORD`. The runner never prints them.
5. Command help text: `rev_1795298469743500000.sql` (now archived in `Custom/Custom feature SQLs/worlddb/`).
   Without it the server only warns that the `command` rows are missing.

## Commands

| Command | Does |
| --- | --- |
| `.dca test run <file.json>` | Validates and starts a run (one at a time). Prints `GAMEPLAYTEST run_id=<id> state=started`. |
| `.dca test validate <file.json>` | Parses and validates only (also checks spell, item, quest, creature, gameobject and map ids). |
| `.dca test status [run_id]` | Active run (`state=preparing/running/cleanup`, current step), or a finished run's result, per-step lines and report path. |
| `.dca test abort` | Stops the active run; cleanup and the report still happen. |
| `.dca test list` | Scenario files the server can see. |

`<file>` is a relative path inside `DC.GameplayTest.ScenarioDir` (letters, digits, `- _ . /`, no `..`).

## Runner

```sh
# Offline schema check, no server needed
python apps/gameplay-test/run.py validate apps/gameplay-test/scenarios/*.json

# Run on the server, copy the scenarios there first, collect the reports
python apps/gameplay-test/run.py run apps/gameplay-test/scenarios/harness-smoke.json \
    apps/gameplay-test/scenarios/dc-item-upgrade-stats.json \
    --sync-to K:/Dark-Chaos/Server/gameplay-tests/scenarios \
    --report-dir K:/Dark-Chaos/Server/gameplay-tests/reports

python apps/gameplay-test/run.py status
python apps/gameplay-test/run.py abort
```

The SOAP host and port come from `--config` (default `K:/Dark-Chaos/Server/configs/worldserver.conf`,
or `DC_WORLDSERVER_CONF`), overridable with `--host` / `--port`. Runs are sequential. Reports and a
`summary.json` land in `apps/gameplay-test/results/<stamp>/` (git-ignored). Exit code: `0` all passed,
`1` a run failed or errored, `2` infrastructure (SOAP, invalid scenario, timeout).

## How a run works

1. **Preparing.** For each actor: find the character by name. If it is missing and the actor has a
   `create` block, create it on the lab account (the `RandomPlayerbotFactory` recipe:
   `Player::Create`, `SaveToDB`, character cache entry) and wait until the row is readable (async
   probe). If the character is online with a client, use it (`session` `auto`/`online`); otherwise log
   it in **headless**: a socketless `WorldSession` plus a `LoginQueryHolder`, exactly as mod-playerbots
   logs in its bots. Then apply the phase layer, revive, set `level`, fill health/mana, reset
   cooldowns, and teleport to the scenario `location` (default GM Island).
2. **Running.** One step per world tick at most, so effects get a map update before the next step.
   Assertions with `within_ms` poll until they hold or the window closes.
3. **Cleanup** (see safety rule 7), then the report.

Everything runs on the world thread (`WorldScript::OnUpdate`, command handlers), between map
updates, like any GM command. Headless teleports are acknowledged by the harness (a real client sends
the acks), and a client trying to log into a character the harness holds headless is refused
(`CMSG_PLAYER_LOGIN` guard) instead of loading a second copy of the character.

## Scenario schema (version 1)

```json
{
  "schema": 1,
  "name": "What is checked, in one line",
  "description": "Optional: requirements, config assumptions",
  "timeout_ms": 120000,
  "setup_timeout_ms": 45000,
  "stop_on_failure": true,
  "destructive": false,
  "location": { "map": 1, "x": 16222.1, "y": 16252.1, "z": 12.5872, "o": 0 },
  "cleanup": { "remove_items": true },
  "actors": [ { "id": "hero", "name": "Gtwarrior", "create": { "race": 1, "class": 1 }, "level": 80 } ],
  "steps": [ { "action": "assert", "metric": "level", "equals": 80 } ]
}
```

| Top-level key | Meaning |
| --- | --- |
| `schema` | Must be `1`. |
| `name` | Required. |
| `timeout_ms` | Whole run (default 120000, capped by `DC.GameplayTest.MaxRunMs`). |
| `setup_timeout_ms` | Logins, creation and the first teleport (default 45000). |
| `stop_on_failure` | Default `true`: the first failed or errored step skips the rest. |
| `destructive` | Allows `prestige`; needs `DC.GameplayTest.AllowDestructive = 1`. |
| `location` | Where actors are placed at setup (default GM Island, map 1). |
| `cleanup` | `remove_items`, `remove_auras`, `remove_quests`, `restore_spells`, `restore_money`, `restore_prestige`, `restore_position` default `true`; `restore_level` default `false`. They only undo what the run did (items it added, spells it learned or unlearned, auras it added, quests it touched). `restore_position` sends online actors back where they were and parks headless actors at `location` before they log out. |

**Actors** (1 to `MaxActors`): `id` (lower-case, used by steps), `name` (character name, capitalised),
`session` (`auto` default, `headless`, `online`), `create` (`race`, `class`, optional `gender`; only
used when the character does not exist), `level`, `reset` (default `true`: revive, full
health/mana, cooldowns). The first actor is the default `actor`/`unit` of every step.

**References.** `actor` names a player actor; `target`, `unit`, `caster`, `to` name an actor or an
`id` an earlier `spawn`/`spawn_object` step created.

### Actions

Common keys: `action`, `label` (shown in reports), `timeout_ms` (per step).

| Action | Keys | Notes |
| --- | --- | --- |
| `teleport` | `actor`, `map` `x` `y` `z` [`o`] or `to` [`distance`, `angle`], `force` | Waits until the actor arrived (headless acks included). `force` = `TELE_TO_GM_MODE`. |
| `set_level` | `actor`, `level` | `GiveLevel` + talents, like `.character level`. |
| `learn` / `unlearn` | `actor`, `spell` | Tracked for `restore_spells`. Unlearning a ranked spell also drops its higher ranks (core behaviour). |
| `add_item` / `remove_item` | `actor`, `item`, `count` (1-1000) | |
| `equip` | `actor`, `item` | Takes it from the bags or adds one, then the client's auto-equip request. |
| `cast` | `actor`, `spell`, [`target`], `triggered`, `require_known`, `expect` | `require_known` (default `!triggered`) refuses spells not in the spellbook, as a client would. `expect`: `"ok"` (default), `"fail"`, or a `SpellCastResult` number. |
| `add_aura` / `remove_aura` | `target`, `spell`, [`caster`, `stacks`, `duration_ms`] | |
| `spawn` | `id`, `entry`, [`actor` anchor, `distance` 5, `angle` 0, `level`, `health`, `faction`, `passive`, `duration_ms`] | Temporary creature in the run's phase, facing the anchor. |
| `spawn_object` | `id`, `entry`, [`actor`, `distance`, `angle`, `duration_ms`] | Temporary gameobject in the run's phase. |
| `despawn` | `target` | Spawned objects only. |
| `kill` | `target`, [`actor` as killer] | `Unit::Kill`, no durability loss. |
| `revive` | [`target` or `actor`], `pct` | |
| `accept_resurrect` | `actor` | Accepts a pending resurrection request (what `CMSG_RESURRECT_RESPONSE` does). |
| `set_health` | `target`, `pct` or `value` | |
| `set_power` | `target`, `value`, [`power`] | |
| `set_money` | `actor`, `copper` | |
| `quest_add` / `quest_complete` / `quest_remove` | `actor`, `quest` | `.quest add/complete/remove` semantics. |
| `item_upgrade` | `actor`, `slot`, [`expect` `"fail"`] | One level through `DarkChaos::ItemUpgradeApi` (spends currency, persists, re-applies stats). |
| `prestige` | `actor`, [`expect` `"refused"`] | Destructive. Waits for the teleport to the starting zone. |
| `wait` | `ms`, or `until` (an assertion object) with `timeout_ms` (default 10000) | |
| `snapshot` | metric keys + `save_as` | Saves a value for `relative_to`. |
| `assert` | metric keys + comparators, [`within_ms`] | |
| `log` | `message` | Written to the log and the report. |

### Metrics and comparators

Metric keys: `metric`, `unit` (measured object, default first actor), plus what the metric needs.

| Metrics | Extra keys |
| --- | --- |
| `health`, `max_health`, `health_pct`, `level`, `alive`, `in_combat`, `display_id`, `native_display_id` | |
| `power`, `max_power` | [`power`: `mana`, `rage`, `focus`, `energy`, `happiness`, `runes`, `runic_power` or 0-6] |
| `stat` | `stat`: `strength`, `agility`, `stamina`, `intellect`, `spirit` |
| `aura`, `aura_stacks`, `aura_charges`, `aura_duration_ms` | `spell`, [`caster`] |
| `phase_mask`, `map_id`, `zone_id` | (gameobjects too) |
| `distance` | `target` (centre to centre) |
| `exists`, `creature_alive` | 0 instead of waiting when the object is gone |
| `knows_spell` | `spell` |
| `item_count` | `item`, [`bank`] |
| `equipped_item` | `slot` (0-18, `EQUIPMENT_SLOT_*`; returns the item entry) |
| `quest_status` (0 none, 1 complete, 3 incomplete, 5 failed, 6 rewarded), `quest_rewarded` | `quest` |
| `money`, `resurrect_requested` | |
| `mplus_active`, `mplus_keystone_level`, `mplus_run_deaths` (-1 without a run) | unit's map |
| `mplus_can_activate` (0/1, refusal text in `values.detail`), `mplus_activation_error` (text) | `target`: a spawned Font of Power, [`forced_level`] |
| `battle_res_charges` | remaining charges, `-1` where no limit applies |
| `prestige_level`, `prestige_restart_level`, `prestige_refusal` (text, empty when allowed) | |
| `item_upgrade_level` | `slot` (waits for the upgrade cache) |
| `upgrade_currency` | `currency`: `token`, `essence`, `sap` |

Comparators (all present must hold): `equals` / `not_equals` (number, string or boolean),
`min` / `max` (numbers), `contains` / `not_contains` (text). `tolerance` (default 0.0001) applies to
numbers. `relative_to: "<snapshot>"` compares the difference to a saved value. A metric that is not
available yet (unit mid-teleport, cold cache) is retried for up to 5 s before the step fails.

## Report

`<OutputDir>/<run_id>.json`:

```json
{
  "schema": 1, "run_id": "20261121-221500-1-harness-smoke", "scenario": "harness-smoke.json",
  "name": "...", "result": "pass", "started_at": "2026-11-21 22:15:00", "setup_ms": 2100,
  "duration_ms": 4800, "phase_mask": 2147483648, "server_revision": "...",
  "actors": [ { "id": "hero", "name": "Gtwarrior", "guid": "...", "session": "headless", "created": false } ],
  "summary": { "total": 24, "passed": 24, "failed": 0, "errors": 0, "skipped": 0 },
  "steps": [ { "index": 4, "action": "assert", "result": "pass", "started_ms": 2200, "duration_ms": 0,
               "values": { "metric": "money", "value": 123456 } } ],
  "cleanup": [ { "what": "despawn dummy", "result": "ok" } ]
}
```

`result` is `pass`, `fail` (an assertion or game refusal), `error` (scenario or harness problem,
setup failure, timeout) or `aborted`.

## Example scenarios

| File | Checks |
| --- | --- |
| `harness-smoke.json` | The harness itself: phase, level, money, items, spawn, aura, kill, despawn. |
| `mage-spellbook-and-frostbolt.json` | Spellbook gate (unknown spell refused), Frostbolt damage, slow and mana cost, Slow after learning. |
| `dc-prestige-aura.json` | DC custom spell 800010 (prestige aura) raises stamina and gives it back exactly. |
| `dc-item-upgrade-stats.json` | Item upgrade: one level on a tier 1 robe spends tokens and raises stamina. |
| `dc-mythicplus-keystone-preconditions.json` | Font of Power refuses in the open world and in a normal-difficulty dungeon; no battle-res limit without a run. |
| `dc-battle-res-open-world.json` | Battle-res limit is off in the open world; Rebirth requests a resurrection that can be accepted. |
| `dc-prestige-level-drop.json` | Destructive: prestige refused below the required level, then drops to the restart level and adds a prestige level. |

The examples use the lab characters `Gtwarrior`, `Gtmage`, `Gtdruid` and `Gtprestige`, created on
first use.

## Known limits (v1)

- **Headless actors count as bots.** Core `WorldSession::IsBot()` is `_isBot || _headless`, so DC
  code that skips bots (addon messages, collection grants, Mythic+ "bot run" rules, ...) treats
  headless actors as bots. For those paths use `"session": "online"` with the lab character logged in
  through a client.
- **Real clock only.** No simulated or accelerated clock; waits take real time.
- **One run at a time**, steps strictly sequential, no parallel lanes.
- **Private phase only.** Actors cannot see or use phase-1 world objects (NPCs, quest givers,
  stock Fonts of Power); scenarios spawn what they need.
- Brief visibility at login: a headless actor appears at its saved position for one tick before the
  phase layer applies (normally the lab location, where cleanup parked it).
- No packet observation (combat log, client messages) and no SmartAI/encounter timeline capture.
- Actors on the same lab account share account-wide DC state (accountwide pools, prestige talent
  points); destructive scenarios may leave account-wide rewards behind.
- Battle-res charge refusal and Mythic+ activation inside a running keystone need a listed raid with
  an encounter in progress or a Mythic dungeon: not covered yet.

Follow-ups: accelerated clock, packet/combat-log observers, multi-lane parallel runs in separate
phases, a `command` step restricted to actor sessions, encounter/boss scenarios.
