Hinterland BG (OutdoorPvPHL) — DC module guide

This folder provides the DC-specific integration for the Hinterland BG OutdoorPvP script. It wraps the canonical class in `src/server/scripts/OutdoorPvP/OutdoorPvPHL.*` via a small header (`HinterlandBG.h`) and adds config-driven behavior and helpers.

Files here
- `HinterlandBG.h` — tiny wrapper that includes the canonical `OutdoorPvP/OutdoorPvPHL.h` to avoid duplicate class definitions.
- `OutdoorPvPHL_Config.cpp` — loads module options from config (see below).
- `OutdoorPvPHL_Rewards.cpp` — team-based end-of-match rewards, world messages, and optional tokens.
- `OutdoorPvPHL_Reset.cpp` — reset/teleport helpers and zone-wide respawn logic.
- `HLMovementHandlerScript.h` — movement hook used for AFK tracking.

Configuration (example)
Place these keys in your `configs/modules/hinterlandbg.conf` (or your preferred module config). Values shown are examples; tune for your realm.

; --- Match basics ---
HinterlandBG.MatchDuration            = 3600    ; seconds (60 minutes)
HinterlandBG.Resources.Alliance       = 450
HinterlandBG.Resources.Horde          = 450

; --- AFK policy ---
HinterlandBG.AFK.WarnSeconds          = 120
HinterlandBG.AFK.TeleportSeconds      = 180

; --- Status broadcasting (zone-wide) ---
HinterlandBG.Broadcast.Enabled        = 1
HinterlandBG.Broadcast.Period         = 180     ; seconds

; --- Auto reset options ---
HinterlandBG.AutoReset.Teleport       = 1       ; teleport players to starts on auto-reset
HinterlandBG.Expiry.Tiebreaker        = 1       ; winner at expiry = higher resources

; --- World announcements ---
HinterlandBG.Announce.ExpiryWorld     = 1
HinterlandBG.Announce.DepletionWorld  = 1

; --- Base locations (defaults are reasonable; override if needed) ---
HinterlandBG.Base.Alliance.Map        = 47
HinterlandBG.Base.Alliance.X          = 0
HinterlandBG.Base.Alliance.Y          = 0
HinterlandBG.Base.Alliance.Z          = 0
HinterlandBG.Base.Alliance.O          = 0
HinterlandBG.Base.Horde.Map           = 47
HinterlandBG.Base.Horde.X             = 0
HinterlandBG.Base.Horde.Y             = 0
HinterlandBG.Base.Horde.Z             = 0
HinterlandBG.Base.Horde.O             = 0

; --- Rewards: honor (legacy + new) ---
; Legacy default (may be used in some paths)
HinterlandBG.Reward.MatchHonor            = 50
; Winner amounts by win condition
HinterlandBG.Reward.MatchHonorDepletion   = 120    ; when loser hits 0 resources
HinterlandBG.Reward.MatchHonorTiebreaker  = 70     ; when win is by expiry/tiebreaker
; Consolation honor for losing team
HinterlandBG.Reward.MatchHonorLoser       = 20

; --- Rewards: tokens (optional) ---
; If both are > 0, winners also receive this token item
HinterlandBG.Reward.NPCTokenItemId        = 0
HinterlandBG.Reward.NPCTokenItemCount     = 0

; --- Rewards: kills (optional features used by core script) ---
HinterlandBG.Reward.KillItemId            = 0
HinterlandBG.Reward.KillItemCount         = 0
; Comma-separated honor values that may be used contextually by kill logic
HinterlandBG.Reward.KillHonorValues       = 5,8,10

; --- Resource loss amounts ---
; How many resources are removed from the opposing team for each type of kill
HinterlandBG.ResourcesLoss.PlayerKill     = 5       ; player kills
HinterlandBG.ResourcesLoss.NpcNormal      = 5       ; infantry/squadleaders/healers
HinterlandBG.ResourcesLoss.NpcBoss        = 200     ; boss NPCs

; --- Per-NPC token rewards (optional) ---
; CSV lists of NPC entries per team that grant tokens when killed by the opposing team.
; Optional counts maps: "entry:count" pairs (CSV).
HinterlandBG.Reward.NPCEntriesAlliance    =
HinterlandBG.Reward.NPCEntriesHorde       =
HinterlandBG.Reward.NPCEntryCountsAlliance=
HinterlandBG.Reward.NPCEntryCountsHorde   =

Notes
- End-of-match rewards are granted via `HandleRewards(TeamId winner)`:
  - Winner gets `_rewardMatchHonorDepletion` if the loser’s resources reached 0, otherwise `_rewardMatchHonorTiebreaker`.
  - Loser gets `_rewardMatchHonorLoser`.
  - If `_rewardNpcTokenItemId` and `_rewardNpcTokenCount` are both non-zero, the winning team also receives tokens.
- Announcements respect `HinterlandBG.Announce.*` toggles.
- The DC wrapper header was renamed to `HinterlandBG.h` to avoid confusion with the canonical header in `OutdoorPvP/`.

Integration
- Registration of `OutdoorPvPHL` is handled by the canonical `AddSC_outdoorpvp_hl()` in `OutdoorPvPHL.cpp`.
- The DC wrapper only adds config/reward/AFK/reset helpers and does not change registration entry points.

If you want additional reward types (items for both teams, per-kill bonuses, etc.), share the item IDs/counts and the exact conditions; the reward helper can be extended while remaining fully config-driven.

How it works (for admins)
- Timer flow:
  - On reset/start, a new match end time is computed: `Now + HinterlandBG.MatchDuration`.
  - The HUD timer uses this absolute end time so late joiners see the correct remaining time.
  - When the timer expires, the script optionally declares a winner by higher resources if `HinterlandBG.Expiry.Tiebreaker=1`.
  - After winner determination, players may be teleported to faction bases if `HinterlandBG.AutoReset.Teleport=1`, then the zone is reset (creatures/GOs respawned), HUD refreshed, and a new match window starts.
- Win conditions:
  - Depletion: A side hits 0 resources — the opposing side is the winner. Rewards use `MatchHonorDepletion`.
  - Expiry tiebreaker: Timer ends; the side with higher resources is the winner if tiebreakers are enabled. Rewards use `MatchHonorTiebreaker`.
  - Draw: If tiebreakers are disabled and neither side depleted the other to zero at expiry, no winner is declared. You can still reset the zone via admin controls.