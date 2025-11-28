# Additional Bot Systems Evaluation for DarkChaos-255

**Document Type:** Pre-Discussion Evaluation  
**Created:** November 28, 2025  
**Purpose:** Comprehensive evaluation of bot/playerbot systems beyond Trinity-Bots and mod-playerbots

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [CMaNGOS Playerbots](#2-cmangos-playerbots)
3. [celguar/mangosbot-bots (IKE3 Continuation)](#3-celguarmangosbot-bots)
4. [Original IKE3 Mangosbot](#4-original-ike3-mangosbot)
5. [ZhengPeiRu21/mod-playerbots (Legacy)](#5-zhengpeiru21mod-playerbots-legacy)
6. [eyeofstorm/mod-npc-bots (Archived)](#6-eyeofstormmod-npc-bots-archived)
7. [Bot Enhancement Modules](#7-bot-enhancement-modules)
8. [Client Addons for Bot Control](#8-client-addons-for-bot-control)
9. [Lineage & Fork Relationships](#9-lineage--fork-relationships)
10. [Comparison Matrix](#10-comparison-matrix)
11. [Recommendations for DarkChaos-255](#11-recommendations-for-darkchaos-255)

---

## 1. Executive Summary

### Bot System Ecosystem Overview

The WoW emulator bot ecosystem has a complex lineage:

```
IKE3 Mangosbot (Original - MaNGOS Zero/Vanilla)
       │
       ├──> celguar/mangosbot-bots (MaNGOS/CMaNGOS continuation)
       │           │
       │           └──> cmangos/playerbots (Official CMaNGOS integration)
       │
       └──> ZhengPeiRu21/mod-playerbots (AzerothCore port)
                   │
                   └──> liyunfan1223/mod-playerbots (Current AC version)
                               │
                               └──> mod-playerbots/mod-playerbots (Organization)

Trinity-Bots/NPCBots (trickerer) - Independent development for TC/AC
```

### Key Findings

| System | Compatible with AC? | Active Development | Complexity | World Population |
|--------|---------------------|-------------------|------------|------------------|
| cmangos/playerbots | ❌ CMaNGOS only | ✅ Yes (5,580 commits) | Medium | ✅ Yes |
| celguar/mangosbot-bots | ❌ MaNGOS only | ⚠️ Moved to cmangos | Medium | ✅ Yes |
| IKE3 Mangosbot | ❌ MaNGOS Zero only | ❌ Archived | High | ✅ Yes |
| ZhengPeiRu21/mod-playerbots | ✅ AC (outdated) | ❌ Deprecated | Medium | ✅ Yes |
| eyeofstorm/mod-npc-bots | ✅ AC Module | ❌ Archived (2022) | Low | ❌ Limited |
| mod-ollama-chat | ✅ Requires mod-playerbots | ✅ Active | Medium | N/A (Enhancement) |
| mod-player-bot-level-brackets | ✅ Requires mod-playerbots | ✅ Active | Low | N/A (Enhancement) |

---

## 2. CMaNGOS Playerbots

**Repository:** https://github.com/cmangos/playerbots  
**Commits:** 5,580  
**Contributors:** 27  
**Status:** ✅ Actively Maintained

### Overview

This is the **official** CMaNGOS playerbots integration, forked from celguar's work. It's the IKE3 bot system adapted for CMaNGOS (Classic, TBC, and WotLK).

### Features

- Populate open world with playerbots
- Populate BGs and Arenas with playerbots
- Use alt characters as playerbots
- Full PvE content capability (with guidance on complex mechanics)
- Very detailed configuration options
- Multiple commands for bot control

### Installation Requirements

- **Core:** CMaNGOS (NOT AzerothCore)
- **CMake Flag:** `BUILD_PLAYERBOTS = ON`
- **Database:** Characters + World SQL modifications

### For DarkChaos-255

| Factor | Assessment |
|--------|------------|
| **AC Compatibility** | ❌ NOT COMPATIBLE - CMaNGOS only |
| **Port Feasibility** | ⚠️ Significant work - different core APIs |
| **Feature Parity** | Comparable to mod-playerbots (same lineage) |

### Verdict

**NOT VIABLE** for DarkChaos-255 without major porting effort. This is the CMaNGOS ecosystem equivalent of mod-playerbots.

---

## 3. celguar/mangosbot-bots

**Repository:** https://github.com/celguar/mangosbot-bots  
**Commits:** 4,251  
**Stars:** 93  
**Releases:** 933 (!)  
**Status:** ⚠️ Development moved to cmangos/playerbots

### Overview

This was the primary development hub for IKE3-based bots for MaNGOS/CMaNGOS. Development has now officially moved to `cmangos/playerbots`.

### Current Status

- Redirects to cmangos/playerbots for active development
- Still receives automated Windows builds (latest: Nov 23, 2025)
- Supports Classic/TBC/WotLK MaNGOS variants

### For DarkChaos-255

| Factor | Assessment |
|--------|------------|
| **AC Compatibility** | ❌ NOT COMPATIBLE - MaNGOS only |
| **Historical Value** | This is the upstream source that mod-playerbots derived from |
| **Active Development** | ❌ Moved to cmangos |

### Verdict

**NOT VIABLE** - This is the historical source for mod-playerbots but targets MaNGOS, not AzerothCore.

---

## 4. Original IKE3 Mangosbot

**Repository:** https://github.com/ike3/mangosbot  
**Commits:** 1,504  
**Stars:** 204  
**Forks:** 78  
**Status:** ❌ Historical/Archived

### Overview

The **original** mangosbot implementation by IKE3. This is the ancestor of ALL playerbot systems currently in use (mod-playerbots, cmangos/playerbots, etc.).

### Key Information

- Targets **MaNGOS Zero** (Vanilla WoW 1.12.x)
- Branch: `mangos-zero-ai`
- Documentation: http://ike3.github.io/mangosbot-docs/
- Forked from TrinityCore originally

### Features (Original)

- Brings bots online and available for any player
- Use account/guild characters as bots
- Random bot spawning
- BG/Arena support
- Quest completion AI

### For DarkChaos-255

| Factor | Assessment |
|--------|------------|
| **AC Compatibility** | ❌ NOT COMPATIBLE - MaNGOS Zero (Vanilla) |
| **WotLK Support** | ❌ Only Vanilla (1.12.x) |
| **Historical Value** | This is THE origin of all playerbot systems |

### Verdict

**NOT VIABLE** - Historical significance only. This is Vanilla-only and the codebase has been superseded by derivatives.

---

## 5. ZhengPeiRu21/mod-playerbots (Legacy)

**Repository:** https://github.com/ZhengPeiRu21/mod-playerbots  
**Commits:** 485  
**Stars:** 196  
**Contributors:** 10  
**Status:** ❌ DEPRECATED - Directs to liyunfan1223

### Overview

This was the **first port** of IKE3 playerbots to AzerothCore. The author (ZhengPeiRu21) now directs users to liyunfan1223's continuation.

### Important Notice from README

> "This module is out of date. Please use the excellent continuation of this module developed by liyunfan1223"

### Historical Context

- First successful AC port of IKE3 bots
- Required custom AC branch: `ZhengPeiRu21/azerothcore-wotlk/tree/Playerbot`
- Work was continued by liyunfan1223, which became mod-playerbots/mod-playerbots

### For DarkChaos-255

| Factor | Assessment |
|--------|------------|
| **AC Compatibility** | ⚠️ Outdated AC fork required |
| **Maintenance** | ❌ Abandoned (Last update: June 2024) |
| **Recommendation** | Use mod-playerbots/mod-playerbots instead |

### Verdict

**NOT VIABLE** - Deprecated in favor of mod-playerbots. Using this would mean using outdated code with known bugs that have been fixed in the continuation.

---

## 6. eyeofstorm/mod-npc-bots (Archived)

**Repository:** https://github.com/eyeofstorm/mod-npc-bots  
**Commits:** 44  
**Stars:** 15  
**Status:** ❌ ARCHIVED (Oct 24, 2022)

### Overview

An early attempt to port trickerer's NPCBots to AzerothCore as a **module** (not patches). This was abandoned in early development.

### Key Information

- Based on TrinityCore-3.3.5-with-NPCBots
- Only had **ONE bot implemented**: Dreadlord
- Proof-of-concept only
- Standard AC module architecture

### Why It's Interesting

This was an attempt to achieve what many want: NPCBots as a drop-in module for standard AC. Unfortunately, it was abandoned very early.

### For DarkChaos-255

| Factor | Assessment |
|--------|------------|
| **AC Compatibility** | ✅ Was designed as AC module |
| **Completeness** | ❌ Only 1 bot class implemented |
| **Maintenance** | ❌ Archived 2022, no activity |
| **Viability** | ❌ Proof-of-concept only |

### Verdict

**NOT VIABLE** - Incomplete proof-of-concept. Only useful if someone wanted to restart the effort to modularize NPCBots.

---

## 7. Bot Enhancement Modules

These modules **enhance** existing bot systems (primarily mod-playerbots):

### 7.1 mod-ollama-chat (LLM Integration)

**Repository:** https://github.com/DustinHendrickson/mod-ollama-chat  
**Stars:** 57  
**Status:** ✅ Actively Maintained (v0.1.2)

#### Features

- **LLM-Powered Chat:** Bots generate dynamic responses using Ollama API
- **Personality System:** Gamer, Roleplayer, Trickster, etc.
- **Context-Aware:** Uses class, race, faction, guild, zone for prompts
- **Chat Memory:** Bots remember recent conversations
- **Event-Based Chatter:** Bots comment on quest completion, loot, deaths, PvP kills
- **Sentiment Tracking:** Bots develop relationships with players
- **Party-Only Mode:** Reduce chat spam
- **Live Reload:** Change settings without restart

#### Requirements

- **mod-playerbots** (liyunfan1223/mod-playerbots fork)
- **Ollama** running locally or on network
- **fmtlib** dependency

#### DC-255 Considerations

| Factor | Assessment |
|--------|------------|
| **Requires mod-playerbots** | ✅ Yes (fork dependency inherited) |
| **Performance Impact** | ⚠️ Can bog down server (LLM overhead) |
| **Immersion Value** | 🌟 HIGH - Bots feel like real players |
| **Level 255 Compatibility** | ⚠️ Unknown - may reference level-specific content |

#### Verdict

**EXCELLENT ENHANCEMENT** if using mod-playerbots. Significantly increases immersion. Consider running Ollama on separate hardware.

---

### 7.2 mod-player-bot-level-brackets

**Repository:** https://github.com/DustinHendrickson/mod-player-bot-level-brackets  
**Stars:** 33  
**Status:** ✅ Actively Maintained (v1.0.8)

#### Features

- **Level Distribution Control:** Even spread of bots across level ranges
- **Faction-Specific Brackets:** Different ranges for Alliance/Horde
- **Dynamic Distribution:** Bots follow where real players are
- **Death Knight Safeguard:** DKs never assigned below level 55
- **Guild Bot Exclusion:** Bots in guilds with real players excluded
- **Friend List Exclusion:** Bots on friend lists excluded from adjustments

#### Requirements

- **mod-playerbots** (liyunfan1223/mod-playerbots fork)

#### DC-255 Considerations

| Factor | Assessment |
|--------|------------|
| **Level 255 Compatibility** | ⚠️ Needs configuration for expanded level range |
| **Custom Brackets** | ✅ Fully configurable |
| **DarkChaos Use Case** | Could ensure bots spread across 1-255 range |

#### Verdict

**USEFUL ENHANCEMENT** for maintaining diverse bot population. Would need configuration for level 255 cap.

---

## 8. Client Addons for Bot Control

### 8.1 MultiBot (for mod-playerbots)

**Repository:** https://github.com/Macx-Lio/MultiBot  
**Stars:** 94  
**Languages:** English, German, French, Russian, Spanish, Korean, Chinese  
**Status:** ✅ Active (Last update: 5 months ago)

#### Features

- Full UI for playerbot control
- Character selection from account
- Friend bot management
- Inventory management (Sell/Equip/Use/Destroy modes)
- Combat behavior controls
- Formation controls
- Raid composer
- Beastmaster module support
- Multi-language support (7 languages)

#### For DarkChaos-255

**RECOMMENDED** if using mod-playerbots. This is the most comprehensive UI addon for controlling bots.

---

### 8.2 NetherBot (for Trinity-Bots/NPCBots)

**Repository:** https://github.com/NetherstormX/NetherBot  
**Stars:** 87  
**Status:** ⚠️ Last update: Jan 2024

#### Features

- UI for trickerer's NPCBots
- Bot hiring/dismissal
- Combat role assignment
- Formation controls

#### For DarkChaos-255

**RECOMMENDED** if using Trinity-Bots.

---

### 8.3 PlayerbotsPanel

**Repository:** https://github.com/azcguy/PlayerbotsPanel  
**Stars:** 13  
**Status:** ⚠️ Last update: June 2024

#### Features

- Alternative UI for mod-playerbots
- Simpler interface than MultiBot

---

### 8.4 whipowill/wow-addon-playerbots

**Repository:** https://github.com/whipowill/wow-addon-playerbots  
**Stars:** 67  
**Status:** ⚠️ Last update: May 2023

#### Features

- Legacy addon for early AzerothCore playerbots
- May not be compatible with current mod-playerbots

---

## 9. Lineage & Fork Relationships

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        BOT SYSTEM LINEAGE                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  IKE3/mangosbot (Vanilla - MaNGOS Zero)                                  │
│         │                                                                │
│         ├───────────────────────────┐                                    │
│         │                           │                                    │
│         ▼                           ▼                                    │
│  celguar/mangosbot-bots      ZhengPeiRu21/mod-playerbots                │
│  (MaNGOS Classic/TBC/WotLK)        (First AC Port)                       │
│         │                           │                                    │
│         ▼                           ▼                                    │
│  cmangos/playerbots          liyunfan1223/mod-playerbots                │
│  (Official CMaNGOS)                 │                                    │
│         ▲                           ▼                                    │
│         │                    mod-playerbots/mod-playerbots              │
│    (Active Dev)              (Organization - Current Active)             │
│                                     │                                    │
│                     ┌───────────────┼───────────────┐                    │
│                     │               │               │                    │
│                     ▼               ▼               ▼                    │
│              mod-ollama-chat   mod-level-brackets  MultiBot Addon        │
│              (LLM Enhancement)  (Distribution)    (Client UI)            │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  INDEPENDENT DEVELOPMENT:                                                │
│                                                                          │
│  trickerer/Trinity-Bots (NPCBots)                                       │
│         │                                                                │
│         ├──> Pre-patched AC repo (trickerer/AzerothCore-wotlk-with-NPCBots)
│         │                                                                │
│         └──> NetherBot Addon (Client UI)                                │
│                                                                          │
│  eyeofstorm/mod-npc-bots (Archived - incomplete AC module attempt)      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 10. Comparison Matrix

### Core Bot Systems

| System | Platform | World Pop | Fork Req | Active | Stars | Commits |
|--------|----------|-----------|----------|--------|-------|---------|
| **mod-playerbots/mod-playerbots** | AzerothCore | ✅ | ✅ | ✅ | 563 | 2,340 |
| **Trinity-Bots (NPCBots)** | AC/TC | ❌ | ❌ | ✅ | 533 | 770 |
| cmangos/playerbots | CMaNGOS | ✅ | ❌ | ✅ | 84 | 5,580 |
| celguar/mangosbot-bots | MaNGOS | ✅ | ❌ | ⚠️ | 93 | 4,251 |
| ike3/mangosbot | MaNGOS Zero | ✅ | ❌ | ❌ | 204 | 1,504 |
| ZhengPeiRu21/mod-playerbots | AC (old) | ✅ | ✅ | ❌ | 196 | 485 |
| eyeofstorm/mod-npc-bots | AC Module | ❌ | ❌ | ❌ | 15 | 44 |

### Enhancement Modules (AC-Compatible)

| Module | Purpose | Requires | Active | Stars |
|--------|---------|----------|--------|-------|
| mod-ollama-chat | LLM Chat | mod-playerbots | ✅ | 57 |
| mod-player-bot-level-brackets | Level Distribution | mod-playerbots | ✅ | 33 |

### Client Addons

| Addon | For System | Languages | Active | Stars |
|-------|------------|-----------|--------|-------|
| MultiBot | mod-playerbots | 7 | ✅ | 94 |
| NetherBot | Trinity-Bots | 1 | ⚠️ | 87 |
| PlayerbotsPanel | mod-playerbots | 1 | ⚠️ | 13 |

---

## 11. Recommendations for DarkChaos-255

### Viable Options (AzerothCore Compatible)

Only **TWO** bot systems are viable for DarkChaos-255:

| Rank | System | Why |
|------|--------|-----|
| 1️⃣ | **Trinity-Bots (NPCBots)** | Simpler maintenance, no fork needed, pre-patched repo available |
| 2️⃣ | **mod-playerbots/mod-playerbots** | World population, richer features, requires fork |

### Enhancement Recommendations

If choosing **mod-playerbots**:

| Priority | Module | Reason |
|----------|--------|--------|
| 🔴 HIGH | MultiBot addon | Essential for controlling bots via UI |
| 🟡 MEDIUM | mod-player-bot-level-brackets | Useful for DC's level 255 range |
| 🟢 LOW | mod-ollama-chat | High immersion but resource-intensive |

If choosing **Trinity-Bots**:

| Priority | Module | Reason |
|----------|--------|--------|
| 🔴 HIGH | NetherBot addon | Essential for controlling bots via UI |

### Not Viable

| System | Why Not Viable |
|--------|----------------|
| cmangos/playerbots | CMaNGOS only, not AzerothCore |
| celguar/mangosbot-bots | MaNGOS only, development moved |
| ike3/mangosbot | Vanilla only, historical |
| ZhengPeiRu21/mod-playerbots | Deprecated, use mod-playerbots org version |
| eyeofstorm/mod-npc-bots | Archived, only 1 bot implemented |

### Final Summary

**For simplest maintenance:** Trinity-Bots with pre-patched repo  
**For richest features + world population:** mod-playerbots with MultiBot addon

Both are legitimate choices. The "other" repositories researched are either:
- For different cores (MaNGOS/CMaNGOS)
- Deprecated/archived
- Enhancement modules that work WITH the main two options

---

*This is a pre-discussion document. No implementation decisions should be made without hands-on testing in a DarkChaos-255 test environment.*
