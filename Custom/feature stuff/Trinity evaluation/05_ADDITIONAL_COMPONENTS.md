# AzerothCore to TrinityCore 3.3.5 - Additional Components Analysis

## Overview

This addendum analyzes additional components that would need porting:
1. **OutdoorPvP Hinterland BG (HL)** - Custom battleground system
2. **Custom Commands** - 24 CommandScript implementations
3. **AzerothCore Modules** - 10 modules currently in use

---

## 1. OutdoorPvP Hinterland BG System

### Files to Migrate

| Location | Files | Lines (est.) |
|----------|-------|--------------|
| `src/server/scripts/OutdoorPvP/OutdoorPvPHL.*` | 2 | ~600 |
| `src/server/scripts/DC/HinterlandBG/` | 32 | ~8,000+ |
| **Total** | 34 | ~8,600 |

### HL System Components

| Component | File | Complexity |
|-----------|------|------------|
| Core BG Logic | `OutdoorPvPHL.cpp/.h` | HIGH |
| Config System | `OutdoorPvPHL_Config.cpp` | MEDIUM |
| Queue System | `OutdoorPvPHL_Queue.cpp` | HIGH |
| State Machine | `OutdoorPvPHL_StateMachine.cpp` | HIGH |
| AFK Detection | `OutdoorPvPHL_AFK.cpp` | MEDIUM |
| Rewards | `OutdoorPvPHL_Rewards.cpp` | MEDIUM |
| Groups | `OutdoorPvPHL_Groups.cpp` | MEDIUM |
| Affixes | `OutdoorPvPHL_Affixes.cpp` | HIGH |
| Admin Commands | `OutdoorPvPHL_Admin.cpp` | LOW |
| Performance | `OutdoorPvPHL_Performance.cpp` | MEDIUM |
| Integration | `HLBG_Integration_Helper.*` | MEDIUM |
| AIO Handlers | `HLBG_AIO_Handlers.cpp` | HIGH |
| Scoreboard NPC | `HL_ScoreboardNPC.cpp` | LOW |
| Battlemaster NPC | `npc_hinterlands_battlemaster.cpp` | LOW |

### OutdoorPvP API Compatibility

| Feature | AzerothCore | TrinityCore 3.3.5 | Notes |
|---------|-------------|-------------------|-------|
| `OutdoorPvP` base class | ✅ | ✅ | Compatible |
| `RegisterZone()` | ✅ | ✅ | Compatible |
| `HandlePlayerEnterZone()` | ✅ | ✅ | Compatible |
| `HandlePlayerLeaveZone()` | ✅ | ✅ | Compatible |
| `Update(diff)` | ✅ | ✅ | Compatible |
| `SetWorldState()` | ✅ | ✅ | API differs slightly |
| `BroadcastPacket()` | ✅ | ✅ | Compatible |
| `OutdoorPvPMgr` | ✅ | ✅ | Compatible |
| Map-based instantiation | ✅ | ✅ | TC uses `Map*` in constructor |

### HL-Specific Dependencies

| Dependency | AzerothCore | TrinityCore | Impact |
|------------|-------------|-------------|--------|
| `WorldSessionMgr` | Custom AC | Different/Missing | **HIGH** |
| `GameTime::GetGameTime()` | ✅ | ✅ | Compatible |
| `ChatHandler` | ✅ | ✅ | Minor differences |
| Addon messaging | Custom | Different | **MEDIUM** |
| AIO (All-In-One) | AC Module | Not available | **HIGH** |
| WorldState system | ✅ | ✅ | Compatible |

### HL Migration Effort

| Task | Effort |
|------|--------|
| Port OutdoorPvPHL base | 3 days |
| Port extension files | 5 days |
| Adapt WorldSession access | 2 days |
| Adapt AIO integration | 4 days |
| Testing & debugging | 4 days |
| **Total** | **18 days** |

---

## 2. Custom CommandScript Implementations

### Command Script Inventory (24 total)

| Category | Scripts | Commands (est.) |
|----------|---------|-----------------|
| **Mythic Plus** | 3 | ~30 |
| **Item Upgrades** | 6 | ~40 |
| **Prestige** | 3 | ~20 |
| **Seasons** | 1 | ~10 |
| **Hotspots** | 1 | ~8 |
| **AoE Loot** | 2 | ~15 |
| **Phased Duels** | 1 | ~6 |
| **Dungeon Quests** | 1 | ~8 |
| **HLBG** | 1 | ~12 |
| **Challenge Modes** | 1 | ~6 |
| **AIO Bridge** | 1 | ~5 |
| **Achievements** | 1 | ~4 |
| **Map Extension** | 1 | ~3 |
| **Flight Helper** | 1 | ~2 |
| **Total** | **24** | **~169** |

### CommandScript API Compatibility

| Feature | AzerothCore | TrinityCore 3.3.5 | Notes |
|---------|-------------|-------------------|-------|
| `CommandScript` base | ✅ | ✅ | Compatible |
| `ChatCommand` structure | ✅ | ⚠️ | Slightly different |
| `HandleXxxCommand` pattern | ✅ | ✅ | Compatible |
| `ChatHandler` | ✅ | ✅ | Minor differences |
| `GetCommands()` return | ✅ | ✅ | Compatible |
| Permission levels | ✅ | ✅ | Compatible |

### Command Migration Complexity

| Complexity | Count | Effort Each |
|------------|-------|-------------|
| LOW (simple admin) | 8 | 0.5 days |
| MEDIUM (data access) | 10 | 1 day |
| HIGH (system integration) | 6 | 2 days |
| **Total** | **24** | **26 days** |

---

## 3. AzerothCore Modules to Port

### Module List

| Module | Repository | Purpose | TC Alternative |
|--------|------------|---------|----------------|
| **mod-ah-bot** | azerothcore/mod-ah-bot | Auction House Bot | ❌ None - must port |
| **mod-learn-spells** | azerothcore/mod-learn-spells | Auto-learn spells | ❌ Must port |
| **mod-world-chat** | azerothcore/mod-world-chat | Global chat channel | ⚠️ Similar exists |
| **mod-cfbg** | azerothcore/mod-cfbg | Cross-faction BG | ❌ Must port |
| **mod-skip-dk-starting-area** | azerothcore/mod-skip-dk-starting-area | Skip DK intro | ⚠️ Can be simplified |
| **mod-npc-services** | azerothcore/mod-npc-services | Utility NPCs | ❌ Must port |
| **mod-instance-reset** | azerothcore/mod-instance-reset | Instance reset | ❌ Must port |
| **mod-arac** | azerothcore/mod-arac | Any Race Any Class | ❌ Must port |
| **mod-ale** | azerothcore/mod-ale | Account-wide mount/pet | ❌ Must port |
| **mod-customlogin** | Brian-Aldridge/mod-customlogin | Login customization | ❌ Must port |

### Module Hook Dependencies

| Module | Required Hooks | Available in TC 3.3.5? |
|--------|----------------|------------------------|
| mod-ah-bot | WorldScript, DatabaseScript | ✅ Mostly |
| mod-learn-spells | PlayerScript::OnLevelUp | ✅ Yes |
| mod-world-chat | PlayerScript::OnChat | ✅ Yes |
| mod-cfbg | BGScript, PlayerScript | ⚠️ Partial |
| mod-skip-dk-starting-area | PlayerScript::OnLogin | ✅ Yes |
| mod-npc-services | CreatureScript | ✅ Yes |
| mod-instance-reset | PlayerScript, WorldScript | ✅ Yes |
| mod-arac | PlayerScript::OnCreate | ✅ Yes |
| mod-ale | PlayerScript, ItemScript | ✅ Mostly |
| mod-customlogin | PlayerScript::OnLogin | ✅ Yes |

### Module Porting Effort

| Module | Complexity | Effort | Notes |
|--------|------------|--------|-------|
| mod-ah-bot | HIGH | 5 days | Complex market simulation |
| mod-learn-spells | LOW | 1 day | Simple hook |
| mod-world-chat | LOW | 1 day | Chat hook |
| mod-cfbg | HIGH | 7 days | BG system integration |
| mod-skip-dk-starting-area | LOW | 0.5 days | Simple check |
| mod-npc-services | MEDIUM | 2 days | NPC menu system |
| mod-instance-reset | MEDIUM | 2 days | Instance API |
| mod-arac | MEDIUM | 3 days | Character creation |
| mod-ale | HIGH | 5 days | Account-wide storage |
| mod-customlogin | LOW | 1 day | Login hook |
| **Total** | | **27.5 days** | |

---

## 4. Updated Total Migration Effort

### Original Estimate (from previous analysis)
| Phase | Duration |
|-------|----------|
| Phase 1: Core Hook Extensions | 22 days |
| Phase 2: Adapter Layer | 6 days |
| Phase 3: DC Script Migration | 67 days |
| Phase 4: Eluna Integration | 10-17 days |
| Phase 5: Database | 5 days |
| Phase 6: Testing | 25 days |
| **Subtotal** | **135-142 days** |

### Additional Components (This Document)
| Component | Duration |
|-----------|----------|
| OutdoorPvP HL System | 18 days |
| Custom Commands (24) | 26 days |
| Module Ports (10) | 27.5 days |
| Additional Testing | 10 days |
| **Subtotal** | **81.5 days** |

### Grand Total

| Scenario | Duration | Developer-Days |
|----------|----------|----------------|
| Single Developer | 10-12 months | 216-224 |
| Small Team (3) | 4-5 months | ~75 each |
| Full Team (5) | 3-4 months | ~45 each |

---

## 5. Risk Assessment Updates

### OutdoorPvP HL Risks
- **AIO Integration** - AIO (All-In-One addon framework) is AC-specific
- **WorldSessionMgr** - Session management differs between cores
- **Queue System** - Complex state machine may have hidden dependencies

### Command Risks
- **ChatCommand Structure** - API differences may require refactoring
- **Permission System** - Security level handling may differ

### Module Risks
- **mod-cfbg** - Cross-faction BG touches many BG internals
- **mod-ah-bot** - Market simulation may behave differently
- **mod-ale** - Account-wide systems require database schema changes

---

## 6. Revised Recommendation

### ❌ STRONGLY DO NOT MIGRATE

With the additional components factored in:

| Metric | Value |
|--------|-------|
| Total Files | 250+ |
| Lines of Code | ~70,000+ |
| Duration | 10-12 months (1 dev) |
| Cost Estimate | $100,000 - $300,000 |

**The migration is not viable** unless there is a compelling business/technical requirement that cannot be achieved on AzerothCore.

### Alternative: Continue on AzerothCore

Investment of same effort on current AC platform would yield:
- Multiple new features
- Better stability
- Faster time-to-market
- No regression risk
- Community support maintained

---

## Appendix: File Counts

| Category | Files | Lines (est.) |
|----------|-------|--------------|
| DC Scripts | 174 | ~50,000 |
| OutdoorPvP HL | 34 | ~8,600 |
| Command Scripts | 24 | ~5,000 |
| Modules (10) | ~80 | ~15,000 |
| **Total** | **~312** | **~78,600** |
