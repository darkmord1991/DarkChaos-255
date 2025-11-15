# Mythic+ System Evaluation – Mythic Difficulty 3 Refresh

**Date:** February 2026  
**Scope:** Dungeons only – Mythic baseline + Mythic+ overlay on difficulty 3  
**Author:** DungeonEnhancement Working Group

---

## 1. Executive Summary

The legacy evaluation assumed raid Mythic, timer races, four affix slots, and a 500‑hour build. That plan was retired. This document evaluates the trimmed Mythic/Mythic+ design that:

- Reuses difficulty 3 (`Epic`) for the new Mythic baseline.
- Adds a keystone-lite overlay (levels 1–8) with two affixes and death budgets instead of timers.
- Limits seasonal scope to a curated set of dungeons while keeping raids untouched.

**Assessment:** ✅ Feasible with medium effort (~180 engineering hours).  
**Launch strategy:** Short internal QA → limited beta → main realm enablement once metrics stabilize.

---

## 2. Evaluation Criteria

| Area | Pass Condition | Measurement |
|------|----------------|-------------|
| Technical stability | No instance crashes or data loss across 100 QA runs | Crash logs, keystone audit |
| Gameplay clarity | ≥80% of testers correctly describe Mythic+ rules without reading docs | Post-run survey |
| Tuning fairness | <10% of failures attributed solely to budget exhaustion after tuning pass | Telemetry: fail_reason |
| Repeat play | 70% of beta testers complete ≥2 Mythic runs/week | `dc_mplus_scores` activity |
| Safe rollback | `MythicPlus.Enable=0` restores Heroic-only state | Configuration dry run |

---

## 3. Test Plan

### Phase A – Internal QA (2 weeks)
- Populate `dc_dungeon_mythic_profile` for 12 representative dungeons (4 Vanilla, 4 TBC, 4 WotLK).
- Run each dungeon twice: Mythic baseline and Mythic+4 with affixes enabled.
- Validate: death budget triggers, loot distribution, keystone change rules, HUD packet.

### Phase B – Closed Beta (1 week)
- Invite 30 trusted players; grant premade characters with vendor gear.
- Enable full dungeon roster at Mythic baseline, featured rotation for Mythic+.
- Collect structured feedback (difficulty, clarity, reward satisfaction).

### Phase C – Public Beta (2 weeks)
- Enable on staging realm with Grafana dashboards.
- Monitor fail/success ratio, keystone churn, affix-specific incident reports.
- Schedule weekly tuning patch if any dungeon deviates by >15% success rate from median.

---

## 4. Metrics & Instrumentation

- `dc_mplus_runs` captures: map_id, level, success flag, deaths, wipes, score, affix pair, completion time (optional).
- Grafana panels:
  - Success rate by dungeon/level.
  - Average deaths vs budget (heatmap).
  - Keystone inventory vs active players (watch for dupes).
  - Score distribution per dungeon.
- Alerting thresholds:
  - Success rate <35% on any dungeon for 24h.
  - Keystone inventory delta > +20% day/day without matching completions.
  - Crash loop detection from instance server logs.

---

## 5. Risk Evaluation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Difficulty 3 conflicts with legacy scripts | Medium | Breaks unrelated custom content | Run SQL audit for existing difficulty 3 entries, migrate to difficulty 4 where needed before rollout. |
| Affix destabilizes encounter | Medium | Boss or trash becomes trivial or impossible | Maintain exclusion list per dungeon; affix controller checks list before applying. |
| Keystone duplication exploit | Low | Accelerated progression, economic imbalance | Sign each keystone with checksum; log grant and consume events; nightly diff verification. |
| Player confusion (no timer) | Medium | Negative sentiment, feature abandonment | Mythic steward NPC explains death budget mechanic; HUD packet shows remaining deaths prominently. |
| Score inflation/deflation | Medium | Leaderboard meaningless | Weekly script recalculates score curve if outliers detected; publish tuning notes. |

---

## 6. Acceptance Checklist

- [ ] All featured dungeons validated at Mythic and Mythic+ levels, including keystone upgrades/downgrades.
- [ ] Death budgets tuned per dungeon (documented in `dc_dungeon_mythic_profile`).
- [ ] Two affix pairs (boss-focused + trash-focused) validated; exclusion lists documented.
- [ ] Keystone lifecycle tested: grant, consume, upgrade, downgrade, expiration.
- [ ] Grafana/Prometheus dashboards online with alert rules enabled.
- [ ] GM tools updated (`dc mythic grant/fail/inspect`).
- [ ] Player-facing FAQ added to README.

Only after the checklist is complete and metrics hit evaluation targets for two consecutive weeks should the feature move to the primary realm.

---

## 7. Post-Launch Monitoring

- **Week 1:** Daily review of crash logs and keystone inventory. Adjust death budgets quickly if failure spikes occur.
- **Week 2:** Begin leaderboard publishing, announce first tuning wave if needed.
- **Week 4:** Decide whether to unlock Mythic+ levels 9–10 or hold steady; requires data proving score curve stability.

---

## 8. Decision

The simplified Mythic/Mythic+ design is approved for implementation. It provides a manageable scope, clear validation checkpoints, and reversible toggles. Success depends on disciplined tuning and fast mitigation when specific dungeons misbehave, but overall risk is acceptable.

**Status:** Ready for QA execution.
