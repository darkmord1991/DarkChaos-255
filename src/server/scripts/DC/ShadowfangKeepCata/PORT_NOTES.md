# Cataclysm Shadowfang Keep — C++ port notes

**Status: compiles and links clean** into `scripts.lib` / `worldserver.exe` (RelWithDebInfo),
0 errors, 0 warnings, `codestyle-cpp.py` clean for this directory.

Source: CataTC (TrinityCore 4.3.4) `src/server/scripts/EasternKingdoms/ShadowfangKeep/`.

## Map separation — this does NOT touch stock Shadowfang Keep

The port runs on **clone map 825**. Stock SFK on map 33 is untouched: it keeps its own
`instance_shadowfang_keep` script, its own `shadowfang_keep.h`, and its own SmartAI on the
shared entries 3887 (Silverlaine) / 4278 (Springvale).

Everything that could collide in one binary was renamed:

| CataTC | here | why |
|---|---|---|
| `shadowfang_keep.h` | `sfk_cata.h` | AC has a file of that name |
| `DEF_SHADOWFANG_H` | `DEF_DC_SFK_CATA_H` | **identical** guard in AC's header — including both would silently blank one |
| `namespace ShadowfangKeep` | `namespace ShadowfangKeepCata` | |
| `SKScriptName` = `"instance_shadowfang_keep"` | `SKCataScriptName` = `"instance_sfk_cata"` | ScriptName clash → `ScriptMgr` silently deletes the loser |
| `AddSC_instance_shadowfang_keep()` | `AddSC_instance_sfk_cata()` | duplicate symbol at link |
| `DataHeader "SK"` | `"SKC"` | |
| `RegisterShadowfangKeepCreatureAI` | `RegisterShadowfangKeepCataCreatureAI` | |
| `InstanceMapScript(..., 33)` | `InstanceMapScript(..., MapShadowfangKeepCata /* 825 */)` | **the map bind** |

Checked: the other 5 `AddSC_*` names and all 18 ScriptName strings have **no** counterpart
anywhere else in the tree.

## TC 4.3.4 → AC 3.3.5 conversions applied

| TC | AC | count |
|---|---|---|
| `Hook.Register(&C::fn, …)` | `Hook += SpellEffectFn/AuraEffectPeriodicFn/… (C::fn, …)` | 18 |
| script class body | needs `PrepareSpellScript(C)` / `PrepareAuraScript(C)` first | 16 |
| `SELECT_TARGET_RANDOM` | `SelectTargetMethod::Random` (now a scoped enum) | 8 |
| `me->MakeInterruptable(b)` | **dropped** — no AC equivalent; spell-focus polish only | 8 |
| `IsAIEnabled()` | `IsAIEnabled` (member bool, not a getter) | 6 |
| `_DespawnAtEvade()` | dropped — AC 3.3.5 `BossAI` resets in place | 5 |
| `Trinity::` | `Acore::` | 3 |
| `DamageTaken(Unit*, uint32&)` | `DamageTaken(Unit*, uint32&, DamageEffectType, SpellSchoolMask)` | 3 |
| `JustAppeared()` | `JustRespawned()` | 2 |
| `CastSpellExtraArgs(…).AddSpellBP0(v)` | `CastCustomSpell(…)` | 2 |
| `instance->instance->GetWorldStateValue(x)` | not in AC — see below | 2 |
| `CastSpell(Position{x,y,z}, id, true)` | `CastSpell(x, y, z, id, true)` | 1 |
| `MovePoint(id, x,y,z, true)` | `MovePoint(id, x,y,z)` — slot 5 is `ForcedMovement` in this fork, and `generatePath` already defaults true | 1 |
| `Player::GetTeam()` | `GetTeamId()` | 1 |
| `GetTimeUntilEvent(e) > 15 * IN_MILLISECONDS` | `> 15s` — AC returns `Milliseconds` | 1 |
| `RAID_MODE<uint32>(normal, heroic)` | `DUNGEON_MODE<uint32>(normal, heroic)` | 2 |

### `RAID_MODE` → `DUNGEON_MODE` (worth knowing)
CataTC's 2-arg `RAID_MODE` means *(normal, heroic)*. AC's 2-arg `RAID_MODE` means
*(normal10, normal25)* and switches on the **raid** difficulty enums. On a 5-man it still
returns the right value **only because** `DUNGEON_DIFFICULTY_NORMAL`/`HEROIC` happen to share
the values 0/1 with `RAID_DIFFICULTY_10MAN_NORMAL`/`25MAN_NORMAL`. `DUNGEON_MODE(normal5,
heroic10)` says what is actually meant and does not depend on that coincidence.

### `OnSpellCastFinished` — properly rehomed, not stubbed
AC has no `OnSpellCastFinished(spell, reason)`, but it splits the same signal in two:
`OnChannelFinished` (a channel really ended) and `OnSpellCast` (an ordinary cast completed).
CataTC's hook was hand-filtering exactly that distinction (`if (IsChanneled() && reason ==
SUCCESSFUL_CAST) return;`), so routing both AC hooks into one handler reproduces it exactly.

- **Ashbury** — carried real progression (post–Stay of Execution: `REACT_AGGRESSIVE`,
  `resetAttackTimer()`, schedule Pain and Suffering at 500ms). Rehomed. Had this been dropped,
  Ashbury would have stayed passive after Stay of Execution and never resumed attacking.
- **Godfrey** — did nothing but clear `MakeInterruptable`; collapsed to a no-op and was removed.

### `GetWorldStateValue`
`InstanceMap::GetWorldStateValue` does not exist in AC. Both call sites are the achievement
guard `if (!GetWorldStateValue(X)) DoUpdateWorldState(X, 1)`, where the guard only suppresses
a duplicate packet — the written value is identical either way. So the **update is kept**
(feats still track; not degraded like the Blackwing Descent port's `if (!0)` neutralisation):
- Ashbury (`WORLD_STATE_ID_PARDON_DENIED`) — guard moved to an AI member `_pardonDenied`.
- Springvale (`WORLD_STATE_ID_TO_THE_GROUND`) — sits in a spell script with no instance-side
  state to hang a flag on, so it just writes; the `stack == 3` test above already makes it rare.

## Upstream bug found and fixed

`boss_commander_springvale.cpp`, both Unholy Power handlers:

```cpp
aura = target->GetAura(SPELL_UNHOLY_POWER_HC);
if (!aura)
    target->GetAura(SPELL_UNHOLY_POWER);   // <-- CataTC discarded the result
```

`aura` stayed null whenever the **non-heroic** Unholy Power was the applied one, so the
stack-of-3 `ACTION_UNHOLY_POWER` trigger never fired on Normal difficulty. MSVC's
`[[nodiscard]]` warning surfaced it. Fixed to assign. Present in CataTC upstream.

## Still required before this does anything in game

1. **Map 825 must exist** — `Map.dbc` row (share `Directory = "Shadowfang"`, so no client art),
   `instance_template`, `MapDifficulty`, and a rename-copy of map 33's `maps`/`vmaps`/`mmaps`
   files (the id lives only in the filename). See the BFD-820 clone recipe.
2. **Spawns** — 505 creatures / 190 GOs / 47 creature entries / 43 GO entries from `cata_world`
   map 33, offset onto 825.
3. **ScriptName bindings** — 18 ScriptNames are registered here (5 bosses + 4 adds + the
   instance + 13 spell scripts). Until `creature_template.ScriptName` /
   `spell_script_names` carry them, boot logs "ScriptName not found" for each. Expected.
4. **Spells** — `01_sfk_cata_spells.sql` (56 rows) covers the downported ids; the client shows
   no icon/tooltip until `Spell.dbc` itself is rebuilt with `tools/spell-dbc-append.py`.
