# Blackwing Descent C++ port — status & rework notes

**Status: compiles clean** into `scripts.lib` (RelWithDebInfo). Ported from CataTC; ~15 categories of
TC→AC-3.3.5 divergence resolved (Register→+=Fn+PrepareSpellScript, IsAIEnabled member, typed flag
helpers, `SelectTargetMethod`, `GetThreatMgr`, `GetSummonerUnit`, `CastCustomSpell`, `JustRespawned`,
`MovePoint/MovePath` args, `CastSpell(x,y,z)`, `SetTitle`, `AuraRemoveMode ==`, etc.).

## Cata mechanics NEUTRALIZED to compile — need rework (bosses otherwise functional)
These were stubbed because the 3.3.5 fork lacks the subsystem. Core boss mechanics work; these are
polish / edge features to restore.

| Mechanic | Status | Impact |
|---|---|---|
| **Finkle gossip** | ✅ **FIXED** | Reimplemented as `void sGossipSelect(Player*, uint32 menuId, uint32) override` (the real 3.3.5 creature hook; CataTC's `bool GossipSelect` was dead). Menu-id constant aligned to the DC SQL's **11812**. Selecting "needing a key" now activates Bile-O-Tron + wakes Chimaeron. |
| **OnSpellCastFinished hooks** (5) | ⚠ **1/5 FIXED, 4 still dead** | The fork has no such CreatureAI hook — despite the earlier claim in this row, the logic was **not** actually relocated anywhere for any of these. **Chimaeron's Massacre aftermath (melee/Double Attack reset, Bile-O-Tron knock-out roll, Feud cast) was genuinely dead and has now been fixed**: moved into a `spell_chimaeron_massacre` `SpellScript` (`AfterCast` hook on SPELL_MASSACRE) that calls `DoAction(ACTION_MASSACRE_AFTERMATH)` on the boss AI; the dead `OnSpellCastFinished` override was deleted from `boss_chimaeron.cpp`. The remaining 4 (`blackwing_descent.cpp` ×1, `boss_maloriak.cpp` ×1, `boss_nefarians_end.cpp` ×2) are still unreachable dead code and need the same treatment — not yet done. The `SpellFinishReason` stub enum in `blackwing_descent.h` must stay until all of them are converted. |
| **Onyxia lava-elevator transport** (boss_nefarians_end) | 🟡 **PARTIALLY FIXED** — encounter progresses; true ride-up still absent | Fixed the encounter-progression bugs that were trapped in the always-false `if ((TransportBase*)nullptr)` dead branches: **(1)** `SetupTransportSpawns` rewritten — the `#if 0` block replaced with a real `me->SummonCreature` loop at authored world coords, lifted by the elevator travel (`ELEVATOR_LOWERED_CENTER_Z` → raised center 6.488) so the adds land on the raised elevator, not the lava; **(2)** the chromatic-prototype `DoCastAOE(SPELL_JUMP_DOWN_TO_PLATFORM)` was trapped in dead code (prototypes never engaged) → hoisted to fire unconditionally; **(3)** the jump destination now transforms the transport-relative `ChromaticPrototypeJumpPositions` into world space via `TransportBase::CalculatePassengerPosition(...)` using the elevator's frame. **Still missing (needs the GO-transport passenger subsystem):** the visual "ride up" (adds/Onyxia rendered moving with the elevator) and the two visual-only passenger binds at Nefarian-land / bone-warrior-respawn (they use absolute coords, so the encounter still works). Validate positions/timing live. |
| **Atramedes sound bar** | ⚠ **NEEDS REWORK** (functional-but-imperfect) | Sound mapped to `POWER_ENERGY`. Works as a hidden counter for most classes but **collides with rogue/feral-druid energy** and shows no bar. **Proper fix = aura-stack tracking** (a `SPELL_SOUND` aura, 1 stack/point; swap `GetPower(POWER_ENERGY)`→`GetAuraCount`, `SetPower(0)`→`RemoveAura` on the gong). Multi-touchpoint (sonar-add scripts + Noisy check + gong reset) — do with live testing. |
| **Worldstate feat tracking** | ⚪ accepted degradation | Negative-tracking checks neutralized to `if (!0)` (always true) → feats (Silence is Golden, Arcane Annihilator…) always achievable. To restore: track per-attempt failure via an `InstanceScript` member bool instead of a worldstate. Low priority. |
| **Spell-focus lock** | ⚪ minor | `MakeInterruptable`/`ReleaseSpellFocus` removed — bosses can turn during casts they shouldn't. Cosmetic; low priority. |
| **Spline flourishes** | ⚪ cosmetic | `MoveAlongSplineChain`/`MoveCirclePath`/`MoveCyclicPath` neutralized — bosses use plain movement. Cosmetic. |
| **UNIT_FLAG2_INTERACT_WHILE_HOSTILE** | ⚠ tied to vehicle | → `0`; Magmaw not clickable-while-hostile for the harpoon. Restore alongside the vehicle rework. |

## Also note
- **Vehicle bosses** (Magmaw pin/ride, Atramedes air): the **Vehicle/VehicleSeat DBC rows are now DONE**
  (Vehicle.csv 420 rows, VehicleSeat.csv 737 rows + compiled .dbc — see EXTRACTED_DBC_VALUES.md) and
  `npc_spellclick_spells` is in 08_bindings.sql. What REMAINS is the C++ side: the transport/vehicle
  passenger logic above was neutralized to compile, so the ride still won't function until that C++
  rework lands. (DBC = ready; C++ = the blocker.)
- Boss **spell ids (161)** need `spell_dbc`/Spell.dbc rows or the abilities do nothing.
- These files register their ScriptNames; a boot will log "ScriptName not found" for any add whose
  creature_template.ScriptName isn't yet applied — expected until the SQL is applied.
