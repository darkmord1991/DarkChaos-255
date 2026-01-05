# Guild + Account Housing — Expansion Ideas (UI + Teleporter Integration)

Date: 2026-01-05

This is a companion doc to `05_GUILD_HOUSING.md` focused on:
- Feature ideas players usually ask for
- AIO UI direction (moving away from NPC gossip)
- Scalability / performance optimizations
- How to integrate “Guild House” into the **general teleporter** (`eluna_teleporter`)

---

## 1) What players usually request (high signal)

### Access + convenience
- One-click **Enter House** + **Return to last location**.
- A predictable cooldown (like a hearth) or “free but longer cast” to reduce abuse.
- A “summon to house” / “invite to house” workflow that’s frictionless.

### Decorating that feels good
- Precise move/rotate controls with **snap toggles** (grid + angle).
- **Undo / redo** and “revert to last saved” (people will experiment).
- Layout presets: “save/load layout” is huge for retention.

### Social + status
- Visitor permissions (friends/guild/party/whitelist) and “Open House” toggle.
- Trophies / cosmetics that show off progression (raids, achievements, season ranks).
- Lightweight “guest book” or “likes” (optional later; it drives social loops).

### Economy + progression
- Clear GO limits per tier + meaningful upgrade path (non-linear costs to avoid spam).
- Rare “prestige” decorations gated behind achievements/seasonal content.

---

## 2) UI (AIO addon) — replace gossip with an in-game app

A good mental model: **Housing is an app with 4–5 tabs**, not a long gossip tree.

### Tab A — Home
- Buttons: `Enter`, `Leave (return)`, `Invite`, `Permissions`.
- Show: tier, GO usage (e.g. 17/50), theme, last save.

### Tab B — Catalog
- Category list + search.
- Each item: icon, name, unlock status, requirement, `Place`.
- Server sends only unlocked items (or paged lists) to keep payload small.

### Tab C — Decorate Mode
- `Preview` object (ghost/transparent) + confirm/cancel.
- Controls:
  - Move X/Y/Z (nudge buttons ±0.1 / ±1.0)
  - Rotate yaw (angle snap 5°/15°)
  - Scale (if allowed)
  - Toggles: grid snap, angle snap
- QoL: `Undo`, `Redo`, `Reset to last saved`.

### Tab D — Permissions
- Role-based permissions: GM / Officer / Member / Guest.
- Toggles: place/move/remove, invite guests, buy upgrades, change theme.
- Optional: last 50 actions audit (“X placed Y”).

### Tab E — Upgrades
- Tier list, costs, benefits.
- Purchase buttons (server validated).

---

## 3) Server ↔ UI contract (recommended message surface)

Keep the network contract small and explicit:

- `Housing.GetState()`
  - tier, limits, active map/instance, permission flags, current theme
- `Housing.GetCatalog(page, filter)`
  - returns entries + unlock metadata
- `Housing.BeginPreview(goEntry)`
- `Housing.UpdatePreview(dx, dy, dz, dYaw, scale)`
- `Housing.ConfirmPlacement()` / `Housing.CancelPreview()`
- `Housing.MoveObject(objectId, dx, dy, dz, dYaw)`
- `Housing.RemoveObject(objectId)`

Important: treat the client as untrusted.
- Validate unlocks, limits, distances, allowed GO entries on every server action.

---

## 4) Scalability / performance notes (practical)

### If you go instanced (recommended)
- Lazy-load objects on enter.
- Spawn in batches (e.g. 25–50 per tick) to avoid hitching.
- Cleanup instances on inactivity (your 30 min idea is good).

### Database + persistence
- Use strong indexing for owner lookups (e.g. `(account_id, id)` / `(guild_id, id)`).
- Consider soft limits per category (e.g. 10 trophies, 5 utilities) so a single category can’t dominate.

### Abuse prevention
- Whitelist GO entries via catalog (block doors/transports/scripted objects by default).
- Enforce per-entry `max_per_house` for spammy objects.
- Prevent placement in “protected zones” (spawn point, vendors, portals).

---

## 5) “Guild House” in the general teleporter (current status + options)

### What you have today
The Eluna teleporter scripts in:
- `Custom/Eluna scripts/Teleporter/Eluna teleporter.lua.disabled`
- `Custom/Eluna scripts/Teleporter/Eluna teleporter mobile.lua.disabled`

…load rows from `eluna_teleporter` and only support **static destinations**:
- `type == 2` → `player:Teleport(map, x, y, z, o)`

So with the current DB schema + script logic, the table can only represent:
- fixed map + fixed coordinates

It does **not** have a built-in notion of “dynamic destination per player/guild/account”.

### Option 1 (lowest effort): Teleporter entry → static “Housing Lobby”
Add one teleporter entry called “Guild House” that teleports to a fixed “Housing Lobby” map/coords.
From there:
- a housing NPC, areatrigger, or UI button can route to the correct guild instance.

Pros:
- Works with the current table.
- Minimal risk.

Cons:
- Not truly one-click-to-your-instance.

### Option 2 (medium): Extend the Eluna teleporter script with a dynamic route
Modify the Eluna teleporter script to special-case one entry (by `id` or a new `type`).
When selected:
- Look up `player:GetGuildId()`
- Route to the correct guild house

This requires one of the following to exist:
- Eluna API support to teleport to a specific instance (e.g. a 6th arg for instanceId), OR
- an exposed server-side function you can call to “teleport to guild house”, OR
- a safe “run server command” API (often not exposed, for good reasons)

Pros:
- One menu entry can truly send you “home”.

Cons:
- Depends on Eluna/core capabilities; may require C++ support.

### Option 3 (best long-term): Core-supported routing keyed off `eluna_teleporter`
Since you already query `eluna_teleporter` from C++ in:
- `src/server/scripts/DC/MythicPlus/npc_dungeon_portal_selector.cpp`

…you can implement a similar pattern for housing:
- Add a special “teleporter entry ID” reserved for `Guild House`
- In C++ (or in the housing module), interpret that ID as “route to player’s guild house”

Pros:
- Fast, secure, fully authoritative.
- Does not rely on fragile Eluna client tricks.

Cons:
- Requires a small C++ feature hook.

### Recommendation
- Near-term: Option 1 (Lobby) to get UX quickly.
- Medium/long: Option 3 (core routing) once guild housing logic is stable.

---

## 6) Suggested minimal v1 scope (UI) that players will actually use

If you want an MVP that still feels premium:
- Home tab: enter/leave/invite + basic permissions
- Catalog + Decorate: place/move/remove with snap toggles
- GO limits + 2 tiers (Basic / Standard) + 1 currency (gold or token)

Then iterate into trophies + templates + seasonal.
