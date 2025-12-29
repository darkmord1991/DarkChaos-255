# Endless Dungeon — Comparative Analysis

> Research findings from Torghast, Hades, Diablo 3 Greater Rifts, and WoW Delves  
> Applied to our Endless Dungeon design for AzerothCore + WotLK 3.3.5a

---

## Executive Summary

After researching major roguelike/endless dungeon systems across games, we've identified **key features we're missing**, **common player pain points to avoid**, and **design patterns that work well**. This document recommends additions to our Endless Dungeon to create a more engaging experience.

### Key Additions Recommended
1. ✅ **Temporary Run Powers** (like Anima Powers / Boons)
2. ✅ **Scoring System** for competitive play
3. ✅ **Normal Difficulty Base** for solo accessibility  
4. ✅ **Run-Specific Currency** for power purchases mid-run
5. ✅ **Meta-Progression System** (permanent upgrades)
6. ✅ **Blessings/Torments** (rotating modifiers)
7. ✅ **Better Death Handling** (score penalty, not hard fail)

---

## Comparative Feature Matrix

| Feature | Torghast | Hades | D3 Greater Rifts | WoW Delves | Our Current Design | Recommendation |
|---------|----------|-------|------------------|------------|--------------------|----------------|
| **Temporary Powers** | Anima Powers (100+) | Boons (10 gods) | None | Delve Boons | ❌ Missing | ✅ Add "Runes" system |
| **Power Choices** | Pick 1 of 3 | Pick 1 of 3 | N/A | Random drops | ❌ Missing | ✅ Add choices |
| **Run Currency** | Phantasma | N/A | N/A | N/A | ❌ Missing | ✅ Add "Fragments" |
| **Mid-Run Vendor** | Broker | Charon | N/A | Brann supplies | ❌ Missing | ✅ Add at checkpoints |
| **Scoring System** | Points (9.1+) | N/A | Rift Level + Time | Tier unlocks | ❌ Missing | ✅ Add scoring |
| **Leaderboards** | No | No | Yes | No | ❌ Missing | ⚠️ Later phase |
| **Companion NPC** | No | No | No | Brann | ❌ Missing | ⚠️ Consider for solo |
| **Meta Upgrades** | Box of Many Things | Mirror upgrades | Paragon | Companion leveling | ❌ Missing | ✅ Add "Endless Talents" |
| **Rotating Modifiers** | Torments/Blessings | Pact of Punishment | None | Weekly hazards | ❌ Missing | ✅ Add weekly affixes |
| **Death Handling** | Score penalty | Lose run | Timer + respawn delay | Lives counter | 3 strikes = end | ✅ Add score penalty |
| **Solo Scaling** | Yes | N/A (solo game) | Yes | Yes + companion | ✅ Have | ✅ Improve with Normal diff |
| **Time Pressure** | Score timer | None | 15-min limit | None | ❌ None | ⚠️ Optional mode |
| **Guaranteed Rewards** | Soul Ash | Darkness | Legendary Gems | Chest + Vault | ✅ Tokens/Essence | ✅ Keep |

---

## System-by-System Analysis

### 1. Torghast (WoW Shadowlands)

**What Worked:**
- **Anima Powers** created exciting build diversity and "broken combo" moments
- **Phantasma** (run currency) added resource management decisions
- **Class-specific powers** made each run feel tailored
- **Brokers** (mid-run vendors) gave spending opportunities
- **Score system** (post-9.1) added replayability for high-score chasers

**What Failed (Player Feedback):**
- ❌ **Mandatory for legendaries** — players felt forced
- ❌ **Time investment wasted on failure** — no rewards if you can't complete
- ❌ **Class imbalance** — some specs much easier than others
- ❌ **Bosses overtuned** — frustrating difficulty spikes
- ❌ **Too long** — 30-60 min runs too much commitment
- ❌ **Traps annoying** — environmental hazards frustrating
- ❌ **Power RNG** — bad power rolls = bad run

**What We Should Adopt:**
| Feature | Our Implementation |
|---------|-------------------|
| Temporary Powers | "Endless Runes" — pick 1 of 3 after each boss |
| Run Currency | "Fragments" — dropped by elites, spent at checkpoints |
| Class-Specific Powers | Generic + class-tagged powers in same pool |
| Brokers | Checkpoint vendor every 5 floors |

**What We Should Avoid:**
| Anti-Pattern | Our Solution |
|--------------|--------------|
| Mandatory grind | Keep purely optional, no BiS locked behind it |
| No failure rewards | Always give Essence proportional to progress |
| Super long runs | Target 2-4 min per floor, checkpoints every 5 |
| Power RNG death spirals | Offer reroll option for Fragments |

---

### 2. Hades (Supergiant Games)

**What Worked:**
- **Boon System** — simple but deep: one god per slot, clear synergies
- **Rarity progression** — Common→Rare→Epic→Heroic feels rewarding
- **Duo Boons** — combining gods creates exciting moments
- **Keepsakes** — force specific god offerings (reduces RNG frustration)
- **Additive damage** — prevents exponential power scaling
- **Short runs** — 20-30 min feel respectable
- **Meta progression** — Mirror upgrades give permanent power

**What We Should Adopt:**
| Feature | Our Implementation |
|---------|-------------------|
| Boon slots | Limit: 5 active Runes (can replace when full) |
| Rarity tiers | Common/Uncommon/Rare/Epic Runes |
| Synergy tags | Runes with matching tags = bonus effect |
| Keepsake equivalent | "Focus Stone" — guarantees category of next Rune |
| Additive scaling | Runes add flat %, not multiplicative |

---

### 3. Diablo 3 Greater Rifts

**What Worked:**
- **Infinite scaling** — no level cap, always a challenge
- **15-minute timer** — creates urgency without feeling rushed
- **Progress orbs from elites** — focus on valuable targets
- **Legendary Gems** — unique progression system with upgrade chances
- **Leaderboards** — competitive endgame
- **Empowered Rifts** — spend gold for bonus attempts

**What Failed:**
- ❌ **Gear locked during run** — can't adapt
- ❌ **Death snowball** — increasing respawn timer hurts further
- ❌ **All rewards at end** — nothing dropped during run

**What We Should Adopt:**
| Feature | Our Implementation |
|---------|-------------------|
| Infinite scaling | Already have — floors go forever |
| Progress tracking | Show % toward next floor completion |
| Elite focus | Elites drop Fragments + guaranteed Rune choice |
| Leaderboards | Later phase — track highest floor per class/spec |

---

### 4. WoW Delves (The War Within)

**What Worked:**
- **NPC Companion (Brann)** — helps solo players with healing/tanking
- **Companion customization** — Curios modify companion behavior
- **Short runs** — 10-20 minutes
- **Tier system** — clear difficulty progression
- **Great Vault integration** — connects to weekly rewards
- **Boons from exploration** — rewards thorough play
- **Story variants** — same delve, different scenarios

**What We Should Adopt:**
| Feature | Our Implementation |
|---------|-------------------|
| Companion NPC | Consider for solo: "Spirit Guide" healer/tank |
| Curios | Companion gear drops from Endless cache |
| Tier unlocks | Run Levels 1-6+ work similarly |
| Story variants | Random dungeon selection provides variety |

---

## Recommended New Systems

### 1. Endless Runes (Temporary Powers)

**Concept:** After each boss kill, player picks 1 of 3 Runes. Runes last until run ends.

```
┌─────────────────────────────────────────────────────────────┐
│                    CHOOSE YOUR RUNE                          │
│                                                              │
│  [1] Rune of Fury          [2] Rune of Recovery             │
│      +15% Attack Speed          Heal 3% HP on kill          │
│      (Common)                   (Common)                     │
│                                                              │
│  [3] Rune of the Juggernaut                                 │
│      +25% HP, −10% Speed                                    │
│      (Uncommon)                                              │
└─────────────────────────────────────────────────────────────┘
```

**Rune Slots:** Maximum 5 active. After 5, must replace one.

**Rune Categories:**
| Category | Examples |
|----------|----------|
| Offense | +% damage, +attack speed, +crit |
| Defense | +% HP, +armor, damage reduction |
| Utility | +movement speed, +resource regen |
| Class | Enhance specific abilities |
| Synergy | Bonus when paired with other Runes |

**Rune Rarity:**
| Rarity | Drop Rate | Power Level | Floor Requirement |
|--------|-----------|-------------|-------------------|
| Common | 60% | Low | Any |
| Uncommon | 25% | Medium | Floor 5+ |
| Rare | 12% | High | Floor 15+ |
| Epic | 3% | Very High | Floor 30+ |

---

### 2. Fragments (Run Currency)

**Concept:** Dropped by elites and in caches. Spent at checkpoint vendors.

**Sources:**
| Source | Fragments |
|--------|-----------|
| Elite mob | 5-10 |
| Boss kill | 10-20 |
| Cache loot | 3-8 |
| Greedy Goblin | 50+ |

**Spending (at Checkpoint Vendor):**
| Item | Cost | Effect |
|------|------|--------|
| Rune Reroll | 15 | Get new Rune choices |
| Health Potion (3) | 10 | Consumables |
| Upgrade Rune | 30 | Common→Uncommon |
| Focus Stone | 25 | Choose next Rune category |
| Repair | 5 | Fix gear durability |

---

### 3. Endless Talents (Meta Progression)

**Concept:** Permanent upgrades purchased with Tokens/Essence between runs.

**Talent Tree:**
```
                    [Starting Rune]
                          │
            ┌─────────────┼─────────────┐
            ▼             ▼             ▼
       [+5% HP]     [+5% Damage]   [+5% Speed]
            │             │             │
            └─────────────┼─────────────┘
                          ▼
                  [+1 Fragment Drop]
                          │
            ┌─────────────┼─────────────┐
            ▼             ▼             ▼
    [Checkpoint      [Extra Rune     [Vendor
     Heal 100%]       Choice]         Discount]
```

**Talent Costs:**
| Tier | Token Cost | Cumulative |
|------|------------|------------|
| 1 | 10 | 10 |
| 2 | 25 | 35 |
| 3 | 50 | 85 |
| 4 | 100 | 185 |
| 5 | 200 | 385 |

---

### 4. Weekly Blessings & Torments

**Concept:** Rotating modifiers that add variety week-to-week.

**Blessings (buffs):**
| Blessing | Effect |
|----------|--------|
| Bloodlust | +10% damage, +10% damage taken |
| Fortified | +20% HP |
| Swift | +15% movement and attack speed |
| Abundant | +25% Fragment drops |
| Lucky | +1 Rune rarity tier chance |

**Torments (debuffs for higher rewards):**
| Torment | Effect | Bonus Rewards |
|---------|--------|---------------|
| Frail | −15% HP | +20% Tokens |
| Starving | No health regen | +15% Essence |
| Cursed | Random debuff each floor | +25% Loot quality |
| Marathon | No checkpoints | +50% all rewards |

---

### 5. Normal Difficulty Base

**Issue:** Current design uses Mythic difficulty as base. For solo players at level 25+, this may be too punishing.

**Solution:** Three difficulty tiers:

| Difficulty | Base | Solo Modifier | Rewards |
|------------|------|---------------|---------|
| **Normal** | 1.0x HP/DMG | 0.30x HP, 0.40x DMG | 100% |
| **Heroic** | 1.3x HP/DMG | 0.40x HP, 0.50x DMG | 130% |
| **Mythic** | 1.6x HP/DMG | 0.50x HP, 0.60x DMG | 175% |

**Selection:** Player chooses at run start. Checkpoints are per-difficulty.

**Scaling Formulas (Solo Normal):**
```
HP = BaseHP × FloorMult × 0.30
DMG = BaseDMG × FloorMult × 0.40
```

This ensures a solo player at level 25 in quest greens can clear early floors.

---

### 6. Scoring System

**Concept:** Optional competitive layer for players who want to push.

**Score Components:**
| Factor | Points | Description |
|--------|--------|-------------|
| Floor Cleared | 100 × floor | Base progress |
| Time Bonus | varies | Faster = more points |
| Death Penalty | −500 | Per death/strike |
| Rune Synergy Bonus | +50-500 | For matching Rune sets |
| Perfect Clear | +1000 | No deaths on floor |
| Torment Bonus | ×1.2-1.5 | For running with Torments |

**Leaderboard Categories:**
- Solo (per class)
- 2-player
- 3-player
- 4-player
- 5-player (full party)

---

## Player Feedback Summary: What to Avoid

Based on extensive community feedback from Torghast/Delves:

| Pain Point | Frequency | Our Mitigation |
|------------|-----------|----------------|
| "Feels mandatory" | Very High | Keep entirely optional, no BiS gear |
| "Too long" | High | 2-4 min floors, checkpoints every 5 |
| "No reward on failure" | High | Essence always earned proportionally |
| "Bad RNG ruins run" | Medium | Rune reroll, Focus Stones |
| "Class imbalance" | Medium | Tune powers carefully, test all specs |
| "Repetitive" | Medium | 53 segments from 15 dungeons, weekly affixes |
| "Can't play with friends" | Medium | Full 1-5 scaling support |
| "Bosses unfair" | Medium | Clear telegraphs, fair mechanics |

---

## Implementation Priority

### Phase 1 (MVP)
- [x] Basic floor progression
- [x] Checkpoints every 5 floors
- [x] Token/Essence currencies
- [x] 3-strike system
- [ ] **Normal/Heroic/Mythic difficulty selection**
- [ ] **Basic Rune system (30-50 Runes)**

### Phase 2 (Enhancement)
- [ ] Fragments + checkpoint vendor
- [ ] Rune rarity tiers
- [ ] Focus Stones
- [ ] Scoring system

### Phase 3 (Meta)
- [ ] Endless Talents tree
- [ ] Weekly Blessings/Torments
- [ ] Leaderboards

### Phase 4 (Polish)
- [ ] Class-specific Runes
- [ ] Rune synergy system
- [ ] Companion NPC for solo

---

## Conclusion

Our current Endless Dungeon design has a **solid foundation** with floors, checkpoints, currencies, and scaling. However, we're missing the **moment-to-moment excitement** that temporary powers provide, and we lack the **long-term meta-progression** that keeps players coming back.

**Top 3 Additions for Best ROI:**
1. **Endless Runes** — Creates exciting choices and build diversity
2. **Normal Difficulty** — Makes solo accessible and fun
3. **Endless Talents** — Provides long-term progression goals

These changes align with what works in Torghast/Hades/Delves while avoiding the pitfalls that caused player frustration.
