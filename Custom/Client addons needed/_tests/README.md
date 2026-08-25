# DC addon suite tests

Regression tests for the fixes made in the 2026-08 architecture review. They run
the **real addon files** against `wowsim.lua`, a stub of the parts of the WoW
3.3.5 API those files touch (frames and textures with shared method tables, a
drivable clock, `LoadAddOn`).

## Running

Needs a `lua` interpreter on PATH:

```sh
cd "Custom/Client addons needed/_tests"
sh run.sh
```

Static checks live one level up:

```sh
python ../check_addons.py            # 0 errors expected
python ../check_addons.py --strict   # also fails on warnings
```

## What each suite pins

| Suite | Guards against |
| --- | --- |
| `test_compat.lua` | `DCCompat` timer semantics, error isolation, pool reuse. Test 1 **reproduces the original bug** (a partial `C_Timer` making an all-or-nothing shim a no-op); test 2 proves DCCompat fills the gap without disturbing what is already there. |
| `test_integration.lua` | Real load order with the real files: `DCCompat.lua` then `HLBG_TimerCompat.lua`. Asserts `C_Timer.NewTicker` exists, that HinterlandBG's queue auto-refresh ticker now actually ticks, and that a missing DC-AddonProtocol fails *loudly* rather than silently. |
| `test_wishlist.lua` | `DC-Collection/Wishlist.lua` frame pooling. 25 refreshes must allocate zero new frames; a reused row's remove button must act on the entry it *currently* shows, not the one captured on first build. |
| `test_lazycache.lua` | `ItemsCache` stays unloaded at login, loads on first lookup, is not re-loaded afterwards, and degrades to a plain cache miss when `DC-JournalData` is absent. |
| `test_hubsplit.lua` | The DCAddonProtocol split. Loads the addon in TOC order and asserts the wire contract survived intact (all 24 module ids, all 12 per-module helper tables, `DC.Opcode.Core`), that transport/JSON/dispatch/`UpdateStats`/`CountTable` stayed in core, that no panel is built at login, and that `/dcpanel` and `/dcdiag` pull `DC-AddonProtocolUI` in on demand exactly once. |

## Note on the simulator

`wowsim.lua` models frames and textures behind shared metatables, the way the
real client exposes them, so metatable polyfills (`SetShown`,
`SetColorTexture`) are genuinely exercised.

Methods with behaviour a test depends on — `Show`/`Hide`, `SetScript`,
`GetChildren`, `CreateTexture`, the clock — are implemented explicitly. Any
other *method* resolves to a no-op, so bringing a new file under test does not
turn into a game of whack-a-mole. That fallback matches on a verb prefix
(`Set`, `Get`, `Is`, ...) rather than on "looks PascalCase", because several
real widget **fields** are PascalCase too (`checkbox.Text`, `button.Icon`) and
handing those back a function breaks the calling code in a way that looks like
a bug in the addon.

If a test needs real behaviour from a stubbed method, implement it explicitly
rather than weakening the assertion.
