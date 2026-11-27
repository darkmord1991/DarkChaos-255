# DC Client Addons Deep Audit — 2026-07 Round

Full review of every DC-authored client addon under `Custom/Client addons needed/` (16 addons,
~475k lines including vendored data tables/caches — logic surface actually reviewed is
~180k lines once pure-data files like `ItemsCache.lua`, `CreaturesCache.lua`, model-path tables,
and vendored libraries (Ace3, LibStub, WeakAuras, etc.) are excluded). Companion to the
`src/server/scripts/DC` C++ audit in this same folder — this round covers the client Lua side.

Methodology: one review agent (or a small split for the largest addons — DC-Collection ×5,
DC-MythicPlus ×3, DC-ItemUpgrade ×2, DC-QOS split by module) per addon, each checking a fixed
checklist (dead/unreachable code, duplicated logic, boolean-persistence bugs, forward-reference
bugs, frame/texture pooling, WoW 3.3.5a API-signature correctness, invalid/retail-only events,
accidental global leaks, JSON/transport reimplementation vs the shared `DC-AddonProtocol`
library) against the actual file contents, with every finding grep/read-verified rather than
inferred from memory. A first review pass lost its per-addon detail to a context-compaction
event partway through the session for 7 addons (DC-Collection, DC-HinterlandBG, DC-InfoBar,
DC-ItemUpgrade, DC-MythicPlus, DC-Welcome) — those were re-run in full rather than reported from
memory, so every finding below is backed by a fresh, verified read.

## Headline numbers

- **16 addons reviewed** (15 DC-authored addons + the shared `DC-AddonProtocol` transport
  library), full logic-surface read, not sampled.
- **~150 findings**: ~30 HIGH, ~55 MEDIUM, ~45 LOW, plus a large cross-cutting duplication
  backlog (the same handful of bug *shapes* recur across many addons — see below).
- **1 critical fix already applied** during this round: a remotely-triggerable client-freeze in
  `DC-AddonProtocol`'s JSON array parser (any player could hang another player's client with a
  malformed `DC`-prefixed whisper). See Cross-cutting section.
- **Recurring bug shapes, not addon-specific mistakes** — the same defect appears independently
  in 4-8 different addons each, which is the strongest signal in this audit: these are gaps in
  shared tooling/conventions, not one-off typos. See "Cross-cutting patterns" below before
  reading the per-addon lists — fixing the *pattern* once (a shared helper, a lint rule) is
  higher-leverage than fixing each instance separately.

## Cross-cutting patterns (read this first)

1. **Unpooled frame/row recreation on every refresh** (WoW/Lua 5.1 never garbage-collects
   frames — `Hide()` + `SetParent(nil)` only detaches, it doesn't free). Found independently in:
   DC-Leaderboards (3 dropdown lists), DC-MythicPlus (7 separate list views across
   GroupFinderFrame/LiveRunsTab/ScheduledTab/MythicTab/RaidTab/WorldTab), DC-Collection
   (`Wishlist.lua`), DC-Welcome (`FAQ.lua`'s search-box panel, rebuilt *per keystroke*),
   DC-Collection's `Protocol.lua` (one leaked frame per transmog-icon refresh). Several of these
   same addons *also* contain a correctly-pooled reference implementation right next to the
   broken one (e.g. DC-MythicPlus's own dropdown-button pools are fine; only its list views leak).
2. **The `x and y or z` boolean-persistence trap** — when `y` can legitimately be `false`, the
   whole expression falls through to `z` instead. Found in DC-HinterlandBG (`hudEnabled` reset
   to `true` on every login regardless of the saved value), DC-Welcome (two Settings-panel
   checkboxes — "show milestones" and "enable server communication" — are complete no-ops
   because `CheckButton:GetChecked()` returns `1`/`nil` and the read side compares `== false`),
   DC-Collection (`Protocol.lua:7710`, low-impact instance). Several other addons show the
   *correct* defensive idiom right next to instances of the bug, confirming authors know the
   trap but don't apply the fix consistently.
3. **Local function referenced before its own declaration** (resolves to a stale/nil global at
   call time, not the intended local). Confirmed live in DC-Mapupgrades (`Core.lua` — fires from
   a 1s ticker in production), and as dead-but-would-crash-if-wired-up in DC-ItemUpgrade
   (`DarkChaos_ItemUpgrade_Retail.lua`'s guild-bank tooltip path).
4. **Opcode/handler-registration collisions.** `DCAddonProtocol:RegisterHandler` *appends* to a
   list and fires every registered handler per incoming opcode — it does not replace. Two
   addons hit this hard: DC-HinterlandBG's `HLBG_LeaderboardAdapter.lua` uses stale opcodes that
   collide with the live, high-frequency BG status/resource broadcasts, corrupting its own cache
   on every match tick; DC-InfoBar's `RefreshAllPlugins()` re-fires every plugin's `OnActivate()`
   (with no `OnDeactivate`) from several ordinary Options-panel interactions, so handlers/timers/
   chat-hooks accumulate without bound the longer a session runs.
5. **Addon-local JSON/transport reimplementation instead of the shared `DC-AddonProtocol`
   decoder.** Found in DC-Collection (`Core.lua`'s structured-source parser, and `Wardrobe`'s
   5-times-copy-pasted outfit-slot string parser), DC-MythicPlus (`Core.lua`'s ~180-line
   hand-rolled JSON decoder for the HUD/timer payload path specifically, even though the same
   file correctly uses the shared decoder everywhere else), DC-ItemUpgrade (`Core.lua`'s
   `ParseJSON`, currently dead but a duplication trap for whoever wires it up next).
6. **Missing `SetLight` on preview models** (renders solid black) — DC-Collection's Wardrobe tab
   has this on its *primary* preview model plus the entire Community tab; two sibling model
   sites in the same files call `SetLight` correctly, so this is inconsistency, not ignorance of
   the fix.
7. **The same helper/table copy-pasted 2-5× per addon instead of shared once** — `GetRarityColor`
   (3 copies, 2 of them missing rarity indices 6/7 that the 3rd has), `ApplyLeaderboardsStyle` (5
   copies across DC-MythicPlus, one entirely dead), dropdown-menu widget construction (4 near-
   identical ~150-line copies in DC-MythicPlus), `ToPositiveNumber` (4 copies), armor/weapon
   type-lookup tables (2 copies in the same file), per-collection-type filter/stats logic (4
   copies across DC-Collection's Mount/Pet/Title/TransmogModule — and a real perf fix applied to
   only one of the four siblings).

## Per-addon findings

### DC-AddonProtocol (shared transport library) — 1 fix applied

- **[FIXED, HIGH/security]** JSON array parser (`DCAddonProtocol.lua` ~2408-2418): a malformed
  array token (e.g. `"[x]"`) left `_jpos` unadvanced and looped forever, freezing the client.
  Reachable by any player via a `DC`-prefixed whisper (the native decoder isn't always present,
  so `CHAT_MSG_ADDON` falls through to this parser for any sender). Fixed to bail out on an
  unexpected token instead of spinning; verified via `luac -p`.

### DC-AOESettings — 3 HIGH, 1 MEDIUM, 4 LOW

- **HIGH** `GetLootSlotInfo(i)` destructured with 9 return values (lines ~1890/1901); 3.3.5a
  only returns 5. Every field from the 4th onward is shifted — `locked` is always `nil`,
  `currencyID` actually holds the quality number. Two knock-on bugs: locked/roll-required items
  get looted regardless of lock state (line 1904), and the "no bag space, money only" filter
  loots every slot because every quality number is truthy (line 1894).
- **MEDIUM** registers `LOOT_READY` (line 1912), which doesn't exist on 3.3.5a (Cata+ only) —
  best case dead, worst case aborts the whole fast-loot block before its handlers wire up.
- **LOW ×4**: dead functions `HandleServerMessage`, `RequestSettingsViaDC`, `AddFastLootOptions`,
  unused `errorSounds` table.
- Clean: no DC-AddonProtocol duplication; transport/JSON usage correct.

### DC-DangerZone — clean, 2 LOW

- Solid nil-guards, pooled ring dots, no leaks. LOW: `OnUpdate` never torn down when idle
  (throttled ~33Hz so cheap but pointless when no zones active); up to 192 `pcall`-wrapped
  coordinate conversions per tick at max zone count — acceptable but worth noting.

### DC_DebugUtils — clean, 1 LOW

- Canonical shared copy is well-written (Lua-5.1-safe varargs, `pcall`-guarded). LOW: a
  suppressed-repeat message count can be silently lost on cache eviction instead of flushed.

### DC-GM — ~7 HIGH, ~6 MEDIUM, ~10 LOW (Core/AzerothAdmin, Frames, Commands, GOMove, Modules)

**Core/AzerothAdmin.lua**
- **HIGH** `tonumber(UnitGUID("player"), 16)` — explicit base 16 doesn't accept the `"0x"`
  prefix `UnitGUID()` returns, so this is `nil`; it's the *first statement* of `OnEnable()`,
  so the error aborts every event registration after it in that function.
- **HIGH** the addon-root `AzerothAdmin.lua` (2623 lines, separate from the loaded
  `Core/AzerothAdmin.lua`) is entirely dead — defines methods on an old `MangAdmin` table, not
  referenced by the `.toc` at all.
- **HIGH** `ToggleTransparency`/`ToggleTooltips`/`ToggleMinimenu` are each defined twice; the
  later (silently winning) definitions force a full `ReloadUI()` instead of applying live —
  the dead first definitions are the "live apply" versions that should have won.
- MEDIUM: `AddObject` right-click sends the same `value` as both chat-command arguments
  (copy/paste error). LOW: `PopupScrollUpdate`/`pairsByKeys` bare-global leaks; unused `Mang`
  local left over from the MangAdmin→AzerothAdmin rename.

**Frames/**
- MEDIUM: `Frames_SectionNpc.lua` reuses the same global texture-child names as
  `Frames_SectionChar.lua` (`ma_modelrotatelbutton_texture` etc.) — each `CreateTexture` clobbers
  the shared global, so cross-section refresh/coloring hits the wrong button.
- LOW ×5: `Frames_SectionServer.lua`'s diff-graph throttle is per-frame-counter not
  elapsed-time (spams faster at higher FPS) plus a dead no-op throttle check and dead frame
  counters; a value parsed back out of displayed text instead of stored numerically; a 5s
  cooldown `OnUpdate` block copy-pasted 3× in `Frames_PopupFrames.lua`; leftover placeholder
  text ("You should not see this text!") in two files.

**Commands/, GOMove/, Modules/, Core/Init.lua** (the slice initially missed by the review fan-out
and closed in a follow-up pass)
- **HIGH** `Commands/DC.lua`'s `UnregisterSelectedDCKey`/`UnregisterSelectedDCHandlerFunction`
  parse a registration key with `"^(.-)_(.-)(_json)?$"` — Lua patterns can't quantify a
  parenthesized group with `?`, so this always returns `nil, nil, nil`. Clicking
  "Unregister"/"Unregister All" in the DC Handlers debug window always errors and never
  unregisters anything.
- **HIGH** `Commands/Char.lua`'s `CharRename`/`CharCustomize`/`CharChangeRace`/
  `CharChangeFaction` all read the typed character name into `cname` and then never append it to
  the `.character ...` command — every one of these silently acts on the GM's current target
  instead of the typed name. `CharListDeleted` has the same bug at MEDIUM (drops the filter).
- **HIGH** `Commands/NPC.lua` + `Core/Init.lua`: the wired-up "Mov Random" button calls
  `AzerothAdminCommands.NPCUnFreeze_Random()`, which doesn't exist anywhere in the loaded file
  (only exists in the known-dead legacy `Commands_NPC.lua`) — always throws.
- MEDIUM: `Commands/Ticket.lua` has dead, never-correctly-populated `tickets.selected` state
  (an incomplete refactor — the real click handler bypasses it entirely); `Misc.lua`'s
  `ShowColorPicker` is 4 duplicated ~25-line blocks; `GOMove/GOMoveScripts.lua` has a dead
  error-handler registration block (checks a bare global `DC` that's never assigned anywhere in
  this addon — always `nil`).
- LOW: `Commands/Tele.lua`/`Core/Init.lua` share an un-`local`'d global `cont` (fragile but
  apparently deliberate cross-file state, still worth routing through the saved-variable that
  already exists for it); `Commands/GO.lua` has 4 more accidental-global leaks; `Main.lua` has
  dead empty if/else scaffolding; `Modules/Linkifier.lua` leaks several bare globals including
  `link`, and passes an undefined identifier `say` as a chat-type argument (masked today only
  because `SendChatMessage` defaults a `nil` type to `"SAY"` — coincidentally correct).
- Clean: `Commands/Server.lua`, `Commands/Confirmation.lua`, `Core/DropDownStyle.lua`,
  `GOMove/GOMoveFunctions.lua`, `GOMove/NPCMoveScripts.lua`.

### DC-Housing — 1 MEDIUM, 5 LOW

- MEDIUM: the preview model's rotate-drag has no `IsMouseButtonDown` fallback in its `OnUpdate`
  — releasing the mouse outside the frame leaves the model spinning/tracking the cursor
  indefinitely.
- LOW ×5: a full model reload on every budget push even in "placed" mode; 3 unused
  `DCHousingLocale` locals; 2 defined-but-unwired catalog opcodes; a discarded onClick closure
  immediately overridden; one unused state field.
- Clean: careful `pcall`-guarding throughout, FauxScrollFrame-recycled catalog rows, all
  `OnUpdate` tickers self-terminate, no protocol duplication.

### DC-Leaderboards — 2 HIGH, 2 MEDIUM, 4 LOW

- **HIGH** `/lb setseason`, `/lb debug`, `/lb protocol` all read/write `LB.settings.*`, which is
  never defined anywhere (real settings live in `DCLeaderboardsDB` via `GetSetting`/`SetSetting`)
  — every one of these commands throws.
- **HIGH** `/lb testtables` calls `LB:TestTables()`, which doesn't exist (`TestDatabaseTables()`
  is the real method) — always throws.
- MEDIUM: 3 dropdown-item-list builders recreate buttons every call instead of pooling (the
  now-familiar leak pattern); category-switch fires `RequestLeaderboard`/`RequestMyRank` twice
  per click (a redundant selection call in `SelectCategory` on top of `UpdateSubCategoryTabs`
  already selecting the first subcategory).
- LOW: 6 declared-but-never-read settings fields; `#Cache.data` always returns 0 (it's a
  dictionary, not an array, so the "cached entries" debug count is always wrong); stale opcode
  values printed in `/lb protocol` debug output; a border-frame `GetBackdrop()` guard that never
  matches, silently and permanently removing the season dropdown's border on first refresh.

### DC-Mapupgrades — 2 HIGH, 4 MEDIUM, 5 LOW

- **HIGH** `NormalizePossibleNormalizedPos` is called from `ImportWorldBossesFromInfoBar`/
  `HandleWorldResolveResult` ~230 lines before its own `local function` declaration — throws
  "attempt to call a nil value", and this path is auto-invoked from a 1s ticker in production
  whenever DC-InfoBar has world-boss data the player doesn't.
- **HIGH** `Pins.lua`'s `WorldMapFrame` `OnShow` hook calls `C_Timer.After` unconditionally with
  no existence guard (unlike the rest of the file, which correctly guards `C_Map`/
  `GetServerTime`) — opening the world map errors on a stock 3.3.5a client.
- MEDIUM ×4: `math.atan(dy, dx)` uses 2-arg 5.3 semantics (Lua 5.1 ignores the 2nd arg, wrong
  minimap bearing); `UI:HotspotMatchesPlayerZone` references an undeclared `zoneId` instead of
  its actual `info` parameter (dead fallback branch); `COMBAT_LOG_EVENT_UNFILTERED` allocates a
  fresh table via `{...}` on every combat-log event just to read 2 fields; a bundled copy of
  `DC_DebugUtils` unconditionally registers `/dcdebugstats`/`/dcdebugclear`, clobbering the
  standalone addon's own slash commands.
- LOW ×5: a dead unused `CopyTable`; an unreachable "restore previous map" branch; several
  ungated debug `print`s that fire in production regardless of a debug flag; a dead settings
  toggle that nothing branches on; a stale-at-load `Astrolabe` reference cached instead of
  re-fetched at use sites.
- Also carries a dead `ParseJSON` reimplementation (`Core.lua:1453`) of the shared decoder.

### DC-QOS — findings from the addon's own final consolidation pass

- MEDIUM: `Core.lua:1551`'s `FireEvent` has no `pcall` around listener dispatch — ~24 call sites
  across the addon depend on this bus, so one throwing listener silently aborts every later
  listener for that event tick.
- MEDIUM: `CLASS_COLORS` fallback table copy-pasted identically 3× (`Core.lua`,
  `Modules/CombatLog.lua`, `Modules/NameplatesPlus.lua`) instead of referencing
  `addon.CLASS_COLORS`, which is already public.
- MEDIUM/packaging: `search_results.txt` — an 1.8MB internal grep dump with local filesystem
  paths, unreferenced by any `.lua`/`.toc`/`.xml`, sitting in the addon root and shipping to
  every player who installs it. **Slated for deletion, see Fix Wave plan.**
- LOW: dead double-assignment of `addon.version` (two version strings back to back, only the
  second survives).
- Independently re-verified: `PingSystem.lua:2669`'s `CreatePingFrame()` is declared with zero
  parameters but its body reads `isWorldPoint`/`uiTextureKit` as if they were parameters —
  resolves to stale/nil globals from an unrelated same-named callback elsewhere in the file.

### DC-Collection — ~6 HIGH, ~9 MEDIUM, ~10 LOW (split across 5 review passes)

**Protocol.lua** (7746 lines) — clean on the "does it duplicate DC-AddonProtocol?" question
(no, it doesn't). MEDIUM: `_ScheduleTransmogIconRefresh` allocates a brand-new `Frame` every
call instead of reusing like every other poll frame in the file. LOW: a `x and y or z` variant
that only feeds a debug log line (low impact); a dead redundant conditional; a harmless
double-pass over the same stats data. Notably, the opcode table and capability bitmasks were
verified byte-for-byte identical to the C++ source — a rare, clean result in this audit series.

**Core.lua + Cache.lua** — MEDIUM ×5: `KNOWN_TITLES_UPDATE` is a no-op stub (unlike its
`COMPANION_LEARNED` sibling), so newly-learned titles have no reliable refresh trigger; a
hand-rolled JSON-field extractor instead of the shared decoder; a transmog-definition unpack
cache that's never invalidated when the underlying definition changes, surviving even a full
`/dcc sync`; `ClearCache` breaks a documented shared-table-reference invariant for
`itemsets`/`itemSets`/`sets` (only the `transmog` alias gets fixed up after the reset); one
cache-mutator (`CacheAddDefinition`) is the only sibling that never sets the dirty flag, so
additions through it are lost on a crash before clean logout.

**UI/MainFrame, MyCollectionFrame, PetJournalFrame, BeastmasterFrame** — clean on the primary
risk checked (frame pooling — all four correctly pool). MEDIUM ×3: `GetRarityColor` has 3
independent copies, 2 of which are missing rarity indices 6/7 (silently render as white/common);
a ~250-line 3D-model resolver duplicated between PetJournal and Beastmaster that has already
drifted (each has features the other lacks); the rotate/zoom model-control script duplicated
4×. LOW: ~45 lines of dead progress-bar code that's never wired up; a manually-built item link
missing its trailing field.

**UI/Wardrobe/* (7 files)** — **HIGH ×3**: an ambiguous outfit slot-key parser where one branch
permanently shadows the other, so numeric outfit-payload keys are always misinterpreted as
1-based when the rest of the codebase keys 0-based (appearances apply one slot off); the main
wardrobe preview model and the entire Community tab's outfit-card models never call `SetLight`
(black-preview risk — two sibling models in the same files call it correctly). MEDIUM ×5: a
reverse displayId→itemId cache invalidator that's defined but never called (appearances synced
in after the first cache build never resolve for outfit preview until a full reload);
inconsistent `C_Timer` guarding within one file (2 guarded call sites, 4 unguarded); armor/weapon
type-lookup tables duplicated verbatim as nested locals inside the same file; a JSON-ish
outfit-slot string parser copy-pasted 5× (plus a 6th, differently-shaped one in a sibling file)
with none of the 6 routed through the shared protocol JSON helpers; a hand-rolled polling-frame
retry loop duplicating an existing (but file-local, hence unreachable) helper.

**Achievements/Form/Toast/Wishlist/DebugCommands/Shop/Modules (10 files)** — **HIGH ×3**:
`Wishlist.lua` recreates every header/row from scratch on every refresh — ironically, this same
addon has an explicit code comment elsewhere warning against exactly this mistake;
`TransmogModule.lua`'s outfit-link `SERIALIZATION_ORDER` table is a corrupted mid-refactor
literal (two incompatible numbering schemes concatenated into one array, several entries alias
the wrong slot) that corrupts outfit share-links; `ShopUI.lua` routes a wanted multi-return
through `and/or`, so live currency-essence values are silently discarded every call in favor of
a stale cache. MEDIUM ×4: the shop buy button has no confirm popup and no double-submit guard;
a search-filter perf fix (cache the lowercased search term) applied to only 1 of 4 sibling
collection-type modules; the same 4 modules' filter/stats logic is independently reimplemented
rather than shared; leftover `[TitleDebug]` chat spam on every title selection. LOW ×6: minor
toast-queue/dismiss races, dead helpers, a non-defensive row-count recompute, a popup
re-registered every call instead of once.

### DC-HinterlandBG — 4 HIGH, 2 MEDIUM, 1 LOW

- **HIGH** `hudEnabled` boolean-persistence trap resets the HUD to enabled on every login
  regardless of the saved value (the correct guard exists in a different file, but runs too
  late — after the damage).
- **HIGH** `HLBG_LeaderboardAdapter.lua` uses stale opcodes (0x01-0x03, 0x10-0x12) that collide
  with the *live, high-frequency* BG status/resource broadcast opcodes the server actually uses
  for those numbers (verified against the C++ source, which explicitly renumbered the real
  leaderboard opcodes to 0x20+/0x30+ specifically to avoid this collision). Because
  `RegisterHandler` fires every registered handler per opcode, every status/resource tick during
  an active match also corrupts the adapter's leaderboard/stats cache with empty data.
- **HIGH** `GetBattlegroundInfo` destructured with a 5th return value that doesn't exist on
  3.3.5a (only 4 real values) — the custom "Hinterland BG is a 25v25…" PvP-frame description
  never displays because its guard is permanently true against `nil`.
- **HIGH** `/hlbgshow` and `/hlbgtest` are registered in two different files; the later one wins
  by load order and happens to mask a real bug in the shadowed version (`HLBG.UI.Tabs:Show()` —
  `Tabs` is a plain array, not an object, would throw if it ever ran).
- MEDIUM: duplicate opcode handlers for queue-update and status sync registered independently in
  two files, so every broadcast triggers the same UI refresh twice; a "worldstate-first" HUD data
  path (`ReadWorldstateData`/`GetAuthoritativeStatus`) branches on IDs that can't actually appear
  in `GetWorldStateUIInfo`'s first return on this client — effectively dead, silently falls back
  to the working path.
- LOW: `HLBG.LeaveQueue` defined twice, harmlessly shadowed by load order.
- Clean: `C_Timer` compat-shim discipline is good throughout; no forward-ref bugs despite the
  2560-line `HLBG_Handlers.lua`; no protocol-duplication; debug windows are properly
  singleton-guarded (no frame leaks).

### DC-InfoBar — 3 HIGH, 3 MEDIUM, 3 LOW

- **HIGH** `RefreshAllPlugins()` re-fires every plugin's `OnActivate()` with no matching
  `OnDeactivate`/idempotency guard, triggered from many ordinary Options-panel interactions.
  Concretely: `Location.lua` re-wraps `ChatFrame1.AddMessage` unguarded on every activation
  (permanently growing nested-closure chain running on *every chat message*); `Location.lua`
  also re-registers its `DC:RegisterHandler("SPOT", ...)` unguarded (appends, doesn't replace —
  confirmed against the library source — so hotspot notifications print N times after N Options
  interactions); `Keystone.lua` spins up a brand-new unguarded bag-scanning frame per activation;
  `Season.lua`/`Prestige.lua` re-register handlers and retry-poll frames the same way. One
  plugin's own code comments explicitly say "do NOT call RefreshAllPlugins here, causes
  re-entrant recursion" — proof the root cause was known but only patched locally.
- **HIGH** `GetInstanceInfo()` destructured into 8 variables; 3.3.5a only returns 7 — the
  "Map ID:" tooltip line is permanently dead (silent, no crash).
- **HIGH** the plugin-options popup rebuilds its entire widget set from scratch on every open
  without ever destroying the previous batch — repeatedly opening/switching plugin options
  stacks duplicate overlapping widgets at the same coordinates permanently.
- MEDIUM: `GetBagSlotItemInfo` isn't a real WoW API function at all (not found in any client
  version) — the "Special Bags" detection is permanently dead, always reports none equipped;
  `BAG_UPDATE_DELAYED` registered (retail-only, doesn't exist on 3.3.5a, low impact since the
  real `BAG_UPDATE` sibling covers it); an unconditional debug `Print` fires on every login for
  every player, unlike every other diagnostic call in the same file which is properly gated.
- LOW ×3: a duplicated dungeon-abbreviation algorithm instead of calling the shared one; 3
  plugins poll on a timer instead of listening to the relevant event (low-cost since throttled,
  but the addon's own `XPRep.lua` demonstrates the correct event-driven pattern already);
  a full bar-layout recompute per plugin-text-update instead of batching once per tick.
- Clean: no literal-data-table duplication (the `CLASS_COLORS`-style anti-pattern is absent
  here — colors/abbreviations/world-boss defaults are each defined exactly once and correctly
  referenced); all protocol usage correctly delegates to `DC-AddonProtocol`.

### DC-ItemUpgrade — 2 HIGH, 8 MEDIUM, 6 LOW (split across 2 review passes)

**DarkChaos_ItemUpgrade_Retail.lua** (5843 lines)
- **HIGH** the quick-settings gear-menu dropdown unconditionally calls `CreateFrame` with a
  fixed named global every click — the very next lines in the `else` branch demonstrate the
  author knows to guard this (`_G[name] or CreateFrame(...)`), but the guard is missing from the
  branch that's actually reachable (`EasyMenu` is a real 3.3.5a global). The dropdown works once,
  then throws forever after.
- MEDIUM: registers the nonexistent `GET_ITEM_INFO_RECEIVED` event (Cata+, silent no-op on
  3.3.5a — item-browser auto-refresh-on-cache-arrival never fires); a forward-reference bug
  (`GetItemTooltipInfo` called 263 lines before its own declaration) that would crash if the
  currently-dead guild-bank tooltip hook were ever wired up.
- LOW ×4: 3 defined-but-uncalled tier-browser helper functions sitting next to a hand-duplicated
  inline version of what one of them does; an un-`local`'d `ICON_TOKEN` global that's never
  read; a duplicate statement; an overcomplicated 13-capture-group item-link regex where the
  rest of the file uses a one-liner; a dead empty stub function.

**Core.lua, Heirloom.lua, Cache.lua, Transmutation.lua, Costs.lua**
- **HIGH** `DC.itemUpgradeCache` is keyed inconsistently — by item template/entry ID in the
  standard-upgrade handlers, by item GUID in the heirloom handlers, sharing one table. Two
  copies of the same base item (e.g. two trinkets at different upgrade levels) overwrite each
  other's cached state.
- MEDIUM ×6: the live-cost cache and its in-flight-request tracker are never invalidated by any
  of the addon's 3 "clear cache" entry points, nor by a server tier-config push, so costs can go
  stale for the rest of a session; the in-flight tracker also has no timeout, so one dropped
  server reply permanently blocks re-requesting that tier/level combination; standard-upgrade
  and heirloom costs reuse the same numeric tier-ID namespace across two unrelated tables (no
  live misuse found, but a latent wrong-table-lookup risk); the heirloom cost-totals function
  silently under-reports instead of flagging a missing level like its sibling does; an
  unregistered heirloom tier silently falls back to tier 3's numbers instead of erroring;
  `GetScannedItems()` never scans the bank even though the addressing-translation layer fully
  supports it (confirmed correct against the server's own translation function); a heirloom
  upgrade path re-implements bag/slot translation inline instead of calling the already-correct
  shared helper (the inline version mishandles bank addressing); a package-selection confirm
  applies optimistic client-side state before the server round-trip is confirmed to have
  succeeded, causing a lasting client/server desync if the send silently fails.
- LOW ×3: a function parameter named `type` shadowing the built-in; a dead 150-line hand-rolled
  JSON parser duplicating the shared decoder; two panel-creation functions with no
  re-entrancy guard (not verified as currently triggered, cheap to guard defensively).
- Clean: bag/slot translation math itself is correct (only the bank-scan omission and the one
  inline-duplication site are issues); no boolean-persistence bug, no forward-ref bug live, no
  retail-only globals/events, correct pooling elsewhere, correct protocol delegation.

### DC-MythicPlus — ~8 HIGH, ~5 MEDIUM, ~4 LOW (split across 3 review passes)

**Core.lua, Settings.lua, GroupFinderFrame.lua, MatchmakingQueue.lua, LiveRunsTab.lua,
ScheduledTab.lua**
- **HIGH** `COMBAT_LOG_EVENT_UNFILTERED` destructured with a fabricated `hideCaster` field that
  doesn't exist in the real 3.3.5a payload (verified against the API codex) — every field from
  `sourceGUID` onward is shifted one slot, so `destGUID` actually holds `destName`'s value.
  Death tracking, the HUD "Deaths:" line, world-map death pins, and killing-blow attribution
  never fire correctly, with no visible error.
- **HIGH ×3**: `CompactRenderRows`, `RenderMyQueues`, and `PopulateLiveRuns` all recreate their
  entire row set via `CreateFrame` on every refresh instead of pooling — each is driven by
  frequent server pushes (search results, application updates, live-run ticks), so this is the
  fastest-accumulating leak found in this audit. (`MatchmakingQueue.lua`'s own queue-status
  frame is correctly built-once-reused, for contrast.)
- MEDIUM: `ScheduledTab.lua`'s list has the identical unpooled-recreate bug, just triggered less
  often; the Group Finder's queue catalog is requested twice on the very first open of a session
  (a tail-call in the frame-construction path plus the caller's own `SelectTab(1)` both trigger
  it, and the only guard checks the final cached result rather than an in-flight flag — mirrors
  the double-request bug found independently in DC-Leaderboards); `Core.lua` carries its own
  ~180-line hand-rolled JSON parser for the HUD/timer opcode path specifically, even though the
  same file correctly uses the shared decoder for every other opcode.
- LOW: 2 dead unused helper functions; a vestigial unused table declaration.

**MythicTab.lua, KeystoneActivationRetail.lua, RaidTab.lua, WorldTab.lua,
SeasonalPortalFrame.lua**
- **HIGH** the same unpooled-recreate-on-refresh bug appears 4 more times here
  (`PopulateMythicGroups`, `RefreshApplicantPanel`, `PopulateRaidGroups`,
  `CreateWorldContentEntry`) — contrasted against 4 *correctly*-pooled dropdown/grid
  implementations in the very same files, confirming this is inconsistency rather than a lack of
  pooling know-how across the addon.
- MEDIUM: a styling helper (`ApplyLeaderboardsStyle`) copy-pasted into 3 files (5 counting the
  other two files reviewed separately), one copy entirely dead/never called; a ~150-line
  dropdown-menu widget implementation copy-pasted 4× with only the row-render callback differing.
- LOW: two icon-crop tables duplicated within one file; `GetDungeonDifficulty()` assumes a
  client-side "Mythic" (3) return value that can't occur on 3.3.5a — cosmetic display flash,
  self-corrects once server-authoritative data lands moments later.

**TokenVendorFrame.lua, GreatVaultFrame.lua**
- **HIGH** registers the nonexistent `GET_ITEM_INFO_RECEIVED` event, which throws on
  `RegisterEvent` and aborts frame construction mid-build — **the entire Token Vendor window
  fails to finish building the first time it's opened**, and since the construction function
  short-circuits on "already built," it never gets a second chance.
- **HIGH** `GetTalentTabInfo` destructured with the wrong signature — the "points spent" local
  actually binds to the tab's description text, so `tonumber(...)` always yields 0 and the
  "which spec is this player" heuristic can only ever resolve to tab 1. This silently breaks
  gear role-fit filtering for every class whose primary spec isn't tab 1 (Feral/Resto Druid,
  Prot/Ret Paladin, Frost/Unholy DK, etc.) — their real gear gets rejected as off-role.
- **HIGH** token purchases have no confirmation and no double-submit guard — a fast double-click
  can fire two purchase requests for the same currency-costed item before any response arrives.
- MEDIUM: an `IsUsableItem() == false` check is permanently dead (the API returns `1`/`nil`,
  never boolean `false`) — the intended class-restriction reject never fires; the Great Vault's
  claim-confirmation popup binds to shared mutable module state rather than the specific
  selection, so clicking "Select" on a second reward while the first confirm dialog is still
  open silently claims the wrong reward when "Yes" is clicked.
- LOW ×2: a stale choice list flashes briefly after tier/slot reselection (self-corrects); a
  dropdown built via unordered `pairs()` over what should be a numeric `for` loop.
- Clean: frame pooling correct in both files (contrast with the tabs above); weekly-reset
  boundary math is entirely server-timestamp-driven; `C_Timer` correctly polyfilled and
  load-ordered per the `.toc`.

### DC-Welcome — 3 HIGH, 4 MEDIUM, 5 LOW

- **HIGH** two Settings-panel checkboxes are complete no-ops due to the `CheckButton:GetChecked()`
  1/nil-vs-boolean quirk compared with strict `== false`/`== true`: "Show level milestone
  notifications" cannot be turned off (unchecking silently has no effect and the box
  re-displays checked every time), and "Enable server communication (DCAddonProtocol)" — the
  entire opt-out toggle for all of this addon's server traffic — is permanently a no-op; there is
  no way to disable it from the UI at all.
- **HIGH** `InitializeTitleFix()` re-wraps several *global, default-UI-wide* functions
  (`GetTitleName`, `strtrim`, etc.) on every `ADDON_LOADED` event with no addon-name filter and
  no re-entry guard — during a normal login (30-100+ addons loading), `strtrim` (used pervasively
  by the entire default UI, not just this addon) ends up wrapped dozens of layers deep, adding
  real per-call overhead for the rest of the session.
- MEDIUM: registers the nonexistent `CHARACTER_SHEET_OPEN` event (dead, intended refresh never
  fires); a fully-implemented server-sync FAQ/What's-New pipeline (with TTL caching) has zero
  call sites anywhere in the addon — users only ever see hardcoded static content, the "syncs
  from server" feature is entirely unreachable; the standalone FAQ search panel recreates ~8 UI
  objects per visible entry on *every keystroke* in the search box instead of pooling (a working
  pooled-widget pattern exists elsewhere in this same addon, in `ChallengePrestigeUI.lua`); a
  "Show Season HUD" checkbox always displays unchecked on reopen even when active (same
  `GetChecked()` type-quirk, display-only — runtime behavior is unaffected because the read site
  elsewhere uses a truthy check).
- LOW ×5: 5 separate reimplementations of the same delay-timer polyfill instead of one shared
  helper that already exists (`DCWelcome.After`); a stale comment contradicting the unconditional
  code right below it; a fragile 2-level parent-chain lookup with a silent-discard fallback; two
  independently-maintained FAQ UI implementations rendering the same underlying data; a
  namespaced `Print` helper defined twice (a local shadow in one file, the real one used by
  three other files defined later in a different file — works today only by load-order luck).
- Clean: no addon-local protocol reimplementation; no accidental globals; no forward-reference
  bugs; several `X and Y or Z` sites checked and confirmed to be the *safe* variant, not the bug.

## Fix wave plan

Mirroring the C++ audit's approach — ordered by risk, smallest-diff fixes first, one agent per
disjoint file group, `luac -p` syntax-checked after every change:

1. **Wave 1 — zero-risk cleanup**: delete `DC-QOS/search_results.txt` (packaging leak, no code
   dependency); delete the dead root `DC-GM/AzerothAdmin.lua`; delete/disable the other confirmed
   100%-dead code blocks (unused helpers, dead `ParseJSON`/`JsonDecoder` duplicates, unreachable
   branches) called out per-addon above.
2. **Wave 2 — confirmed HIGH bugs**: the ~30 HIGH findings above, grouped by addon so each fix
   agent works a disjoint file set — forward-reference fixes, boolean-persistence-trap fixes,
   opcode renumbering, missing-argument/wrong-arity API call fixes, the corrupted
   `SERIALIZATION_ORDER` table, the ambiguous outfit-slot-key parser, `SetLight` additions,
   double-registration removals.
3. **Wave 3 — the recurring frame-pooling bug**: convert every unpooled recreate-on-refresh site
   (DC-Leaderboards ×3, DC-MythicPlus ×7, DC-Collection's `Wishlist.lua` and
   `Protocol.lua`'s one leaked frame, DC-Welcome's `FAQ.lua`) to the pooled pattern already
   correctly demonstrated elsewhere in each of those same addons.
4. **Wave 4 — confirmed MEDIUM bugs** not covered by waves 2-3 (cache-invalidation gaps, missing
   confirm/debounce on purchase flows, duplicate opcode handlers, etc.).
5. **Wave 5 — duplication/dedup backlog** (report-only unless explicitly requested): the
   cross-cutting copy-pasted-helper backlog in the "Cross-cutting patterns" section — hoisting
   `GetRarityColor`, `ApplyLeaderboardsStyle`, the dropdown-menu factory, filter/stats logic,
   etc. into shared modules. Larger diffs, lower urgency than functional bugs; flagged for the
   user to decide scope rather than auto-applied.

Verification after each wave: `luac -p` on every changed file (Lua 5.4 syntax check — imperfect
proxy for 5.1 but catches the class of typo this audit is fixing); no build step exists for
client Lua, so in-game/live verification is the user's call for anything UI-visible.
