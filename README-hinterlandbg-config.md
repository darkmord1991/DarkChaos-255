Hinterland BG configuration

Primary location (recommended):
- The source template lives at `src/server/scripts/DC/HinterlandBG/hinterlandbg.conf.dist` and is installed to `configs/modules/hinterlandbg.conf.dist` by the build.
- To customize, copy `configs/modules/hinterlandbg.conf.dist` to `configs/modules/hinterlandbg.conf` and edit your values.
- The server automatically loads module configs from `configs/modules` at startup; no manual loader calls are needed.

Alternative:
- You can also set any of these keys directly in `worldserver.conf`.

Available keys (with defaults):

- HinterlandBG.MatchDuration = 3600
- HinterlandBG.AFK.WarnSeconds = 120
- HinterlandBG.AFK.TeleportSeconds = 180
- HinterlandBG.Broadcast.Enabled = 1
- HinterlandBG.Broadcast.Period = 60
- HinterlandBG.AutoReset.Teleport = 1
- HinterlandBG.Expiry.Tiebreaker = 1
- HinterlandBG.Resources.Alliance = 450
- HinterlandBG.Resources.Horde = 450
- HinterlandBG.Reward.MatchHonor = 1500
- HinterlandBG.Reward.MatchHonorDepletion = 1500
- HinterlandBG.Reward.MatchHonorTiebreaker = 750
- HinterlandBG.Reward.KillItemId = 40752
- HinterlandBG.Reward.KillItemCount = 1
- HinterlandBG.Reward.KillHonorValues = 17,11,19,22
 - HinterlandBG.Reward.NPCTokenItemId = 40752
 - HinterlandBG.Reward.NPCTokenItemCount = 1
 - HinterlandBG.Reward.NPCEntriesAlliance = 600005,810003,810000,600011
 - HinterlandBG.Reward.NPCEntriesHorde = 600004,600008,810001,810002
	- HinterlandBG.Reward.NPCEntryCountsAlliance = 600005:2,810003:3
	- HinterlandBG.Reward.NPCEntryCountsHorde = 600004:2,810001:3

Notes:
- Broadcast.Enabled can be set to 0 to silence periodic zone status.
- Broadcast.Period is in seconds.
- AutoReset.Teleport controls whether players in-zone are teleported to faction start graveyards during auto-reset when the timer expires.
- Expiry.Tiebreaker determines behavior at 0:00: when enabled, the side with higher resources is announced winner and rewarded; if disabled, it’s treated as a draw (no rewards/buffs).
- Reward.MatchHonorDepletion applies when victory happens by bringing the enemy to 0 resources before the timer ends.
- Reward.MatchHonorTiebreaker applies when victory happens via timer-expiry tiebreaker.
- Announce.ExpiryWorld (1/0) controls a global announcement when the timer expires, including final scores.
 - Announce.DepletionWorld (1/0) controls a global announcement when a side reaches 0 resources, including final scores.
- If KillItemId is set to 0 the item reward for player kills is disabled.
- KillHonorValues is a CSV string; the first 4 values are used (fallbacks: 17,11,19,22).
- NPCEntriesAlliance/Horde are CSV creature entry IDs; when killed by the opposite team, the killer receives NPCTokenItem.
- NPCEntryCountsAlliance/Horde let you override the token amount for specific entries (entry:count). If not set, NPCTokenItemCount is used.
- The killer receives a brief whisper indicating the number of tokens awarded for configured NPC kills.
