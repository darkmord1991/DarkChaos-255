# Dungeon Enhancement Roadmap
## DarkChaos-255 – Mythic/M+ anchored to Dungeon Difficulty 3

**Document Version:** 2.0  
**Date:** February 2026  
**Scope:** Dungeons only – raids remain untouched  
**Target Patch:** Wrath of the Lich King 3.3.5a

> **Archival note (Nov 2025):** All pre-refresh DungeonEnhancement implementation write-ups now live in `Custom/feature stuff/DungeonEnhancement/old/`. Only the streamlined Mythic/Mythic+ plan remains in this root directory.

---

## 1. Vision At A Glance

- **Difficulty 3 (Epic) becomes “Mythic”** for every dungeon. We use the existing difficulty slot instead of inventing new ones, which keeps DBC edits and encounter scripts manageable.
- **Mythic+ is a lightweight modifier layer** that rides on top of difficulty 3. It introduces seasonal scaling, keystone-style progression, and two rotating affixes without changing the baseline dungeon script.
- **Only dungeons change.** Heroic/Normal raids, prestige systems, and open-world mechanics are removed from this roadmap to reduce risk.
- **Vanilla and TBC dungeons receive optional Heroic difficulty (difficulty 2) plus the new Mythic difficulty 3** so that all legacy content can be reused for level 80–255 progression.
- **Season cadence is quarterly.** Each season highlights 6 “feature” dungeons (2 Vanilla, 2 TBC, 2 WotLK) for Mythic+. All other dungeons remain available as static Mythic runs.
- **Death budgets replace timers.** Mythic runs fail when a party hits the configured death cap or wipes too many times. Mythic+ adds score pressure (score loss per death) but still avoids timer anxiety.

---

## 2. Design Pillars

| Pillar | Description |
|--------|-------------|
| Dungeon-first | Every feature is scoped to 5-player instances. Raids, world bosses, and PvP remain untouched. |
| Reuse difficulty 3 | No new map difficulty IDs. “Epic” difficulty (ID 3) now equals Mythic baseline. |
| Minimal DBC churn | Only MapDifficulty and a handful of Spell entries change. All logic lives in world scripts + SQL. |
| Observable progression | Two clear steps: Mythic (static) ➝ Mythic+ (seasonal). Each has its own reward loop. |
| Safe rollback | Season data, keystones, and rewards live in `dc_*` tables so they can be disabled without impacting AzerothCore tables. |

---

## 3. Server-Only Initiatives

### 3.1 Epic Difficulty Scaffolding (P1 – 3 weeks)
- MapDifficulty: ensure every dungeon has difficulty 2 (Heroic) and difficulty 3 (Epic/Mythic) rows.
- Creature scaling: data-driven multipliers per dungeon & per difficulty with fallbacks.
- Loot: difficulty 3 reuses heroic loot tables initially; scaling table adds bonus item level and currency rewards.

### 3.2 Legacy Heroic Coverage (P1 – 2 weeks)
- Backfill Heroic (difficulty 2) entries for Vanilla/TBC dungeons to create a smooth path into Mythic.
- Hook into the teleporter NPC to expose “Heroic (Legacy)” options for quick testing.
- Use the same reward currency (Justice) so players can immediately see value.

### 3.3 Mythic Baseline (P1 – 4 weeks)
- Label difficulty 3 as “Mythic” in gossip menus, LFG text, and NPC copy.
- Implement per-dungeon death budgets (e.g., 12 deaths for Nexus, 8 for Halls of Lightning) with wipe penalties.
- Rewards: Mythic tokens (item 101000) + deterministic loot upgrade chance.

### 3.4 Mythic+ Seasonal Overlay (P2 – 6 weeks)
- Keystone-lite: one per player, levels 1–8, no downgrades. Upgrades happen on clean clears (≤ death threshold).
- Affixes: two slots only – one boss-focused (Tyrannical-lite) and one trash-focused (Fortified/Bolstering variants). Configured per season.
- Score: difficulty level × baseline score – death penalty × deaths. Ratings stored per-dungeon to encourage variety.
- Leaderboard SQL view for later UI work.

### 3.5 Seasonal Structure (P2 – 3 weeks)
- Tables: `dc_dungeon_seasons`, `dc_dungeon_rotation`, `dc_mythic_keystones`, `dc_mythic_scores`.
- Weekly reset job: rotates affixes, refreshes keystone supply, archives previous week’s scores.
- Teleporter state machine: only show featured dungeons for Mythic+, show full list for Mythic.

---

## 4. Server + Client Enhancements

| Feature | Server Effort | Client Effort | Notes |
|---------|---------------|---------------|-------|
| Dungeon difficulty selector UI refresh | 1 week | 1 week | Gossip strings + iconography to denote Heroic/Mythic/Mythic+. |
| Mythic HUD packet | 3 days | 1 week | Shows current difficulty, keystone level, deaths remaining, affixes. |
| Lightweight leaderboard export | 4 days | 3 days | JSON-style cache that addons can read via custom opcode. |

No new standalone addons are required for launch; optional Workbench tasks can add them later.

---

## 5. Client-Only Follow-Ups (Optional)

1. **Dungeon Atlas overlay (2 weeks):** highlight which version of each dungeon a player has cleared on Heroic/Mythic/Mythic+ during the season.
2. **Season tracker widget (1 week):** countdown, featured dungeons, best keystone score.
3. **HUD skin (1 week):** reskin the Mythic HUD to match DarkChaos branding once the packet stabilizes.

---

## 6. Effort & Phasing Summary

| Phase | Contents | Effort (single engineer) | Notes |
|-------|----------|--------------------------|-------|
| 0 | Difficulty 3 scaffolding, legacy heroic coverage | 5 weeks | Enables immediate Mythic testing. |
| 1 | Mythic baseline (death budgets, rewards, teleporter) | 4 weeks | Unlocks full dungeon roster at Mythic difficulty. |
| 2 | Mythic+ overlay + season tables | 6 weeks | Adds keystones, affixes, score. |
| 3 | HUD packet + minimal leaderboard feed | 2 weeks | Optional polish; can slip to later release. |

Parallelization: Database prep (Phase 0) can run while Mythic baseline scripting starts, reducing total calendar time by ~2 weeks.

---

## 7. Key Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Difficulty 3 already used sporadically in custom content | Mythic flag collides with existing scripts | Inventory current difficulty-3 usage; migrate any conflicting entries to difficulty 4 before rollout. |
| Heroic scaling for Vanilla/TBC might overstat enemies | Players perceive “impossible” fights | Start with +10% HP/+5% damage, gather telemetry, expose per-dungeon overrides in SQL. |
| Affix fatigue | Two affixes still too punishing if poorly paired | Pre-select pairings (e.g., Tyrannical-lite never combined with Bolstering-lite) and publish schedule at season start. |
| Keystone hoarding | Players stockpile Mythic+ attempts | Limit keystone slots to one per character, expire unused keystones weekly. |

---

## 8. Immediate Next Steps

1. **Approve Difficulty 3 remapping** – confirm no other system depends on current “Epic” label.
2. **Build SQL migration draft** – add Heroic/Mythic rows for all dungeons in a staging script.
3. **Stand up Mythic sandbox realm** – small isolated realm to test death budgets without disrupting main realm.
4. **Author engineering tickets** – one per phase with acceptance criteria matching this roadmap.

---

**Status:** Ready for implementation sign-off. This roadmap supersedes all previous DungeonEnhancement plans that referenced raids, prestige systems, or timer-based Mythic+.*** End Patch
