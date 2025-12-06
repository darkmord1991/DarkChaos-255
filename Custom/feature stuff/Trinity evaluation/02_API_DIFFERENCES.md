# AzerothCore vs TrinityCore 3.3.5 - API Differences

## Overview
This document details the API-level differences between AzerothCore and TrinityCore 3.3.5 that would require code changes during migration.

---

## 1. Script Registration Patterns

### AzerothCore
```cpp
// Uses CALL_ENABLED_HOOKS macro with hook enums
#define CALL_ENABLED_HOOKS(ScriptType, HookEnum, call) \
    for (auto& script : sScriptMgr->Get##ScriptType##Scripts()) \
        if (script->Is##HookEnum##Enabled()) \
            script->call;

// Script registration in AddSC functions
void AddSC_dc_mythic_plus()
{
    new MythicPlusWorldScript();
    new MythicPlusCreatureScript();
    new MythicPlusAllMapScript();
}
```

### TrinityCore 3.3.5
```cpp
// Uses FOREACH_SCRIPT macro with ScriptRegistry
#define FOREACH_SCRIPT(ScriptType) \
    for (auto& [id, script] : ScriptRegistry<ScriptType>::Instance()->GetScripts()) \
        script

// Script registration via ScriptRegistry
PlayerScript::PlayerScript(char const* name) noexcept
    : ScriptObject(name)
{
    ScriptRegistry<PlayerScript>::Instance()->AddScript(this);
}
```

**Migration Impact:** Script registration pattern change required for all ~100 scripts.

---

## 2. Singleton Access Patterns

### AzerothCore
```cpp
// Many use Instance() pattern
sWorld->getIntConfig(CONFIG_XXX)
sObjectMgr->GetCreatureTemplate(entry)
GameTime::GetGameTime()  // Static class methods
GameTime::GetUptime()

// Eluna integration
sEluna->OnXxx()
```

### TrinityCore 3.3.5
```cpp
// Similar patterns but different class names sometimes
sWorld->getIntConfig(CONFIG_XXX)
sObjectMgr->GetCreatureTemplate(entry)
GameTime::GetGameTime()  // Compatible

// No built-in Eluna
// Would need Eluna-TrinityCore module
```

**Migration Impact:** GameTime and most singletons are compatible. Eluna would need separate integration.

---

## 3. Database Wrapper Differences

### AzerothCore
```cpp
// Prepared statements
CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_XXX);
stmt->setUInt32(0, guid);
PreparedQueryResult result = CharacterDatabase.Query(stmt);

// Async queries
CharacterDatabase.AsyncQuery(stmt);

// Transaction support
CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
trans->Append(stmt);
CharacterDatabase.CommitTransaction(trans);
```

### TrinityCore 3.3.5
```cpp
// Same pattern - COMPATIBLE
CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_XXX);
stmt->SetData(0, guid);  // Note: SetData vs setUInt32 in some versions
PreparedQueryResult result = CharacterDatabase.Query(stmt);

// Async queries - COMPATIBLE
CharacterDatabase.AsyncQuery(stmt);

// Transaction - COMPATIBLE
CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
trans->Append(stmt);
CharacterDatabase.CommitTransaction(trans);
```

**Migration Impact:** Database API is largely compatible. Some method name differences possible.

---

## 4. Player/Unit API Differences

### Health/Power Access
```cpp
// AzerothCore
player->GetHealth()
player->GetMaxHealth()
player->SetHealth(value)
player->ModifyHealth(diff)

// TrinityCore 3.3.5 - COMPATIBLE
player->GetHealth()
player->GetMaxHealth()
player->SetHealth(value)
// Note: Some helper methods may differ
```

### Item Access
```cpp
// AzerothCore
Item* item = player->GetItemByGuid(itemGuid);
player->AddItem(entry, count);
player->DestroyItem(bag, slot, update);

// TrinityCore 3.3.5 - COMPATIBLE
// Same methods available
```

### Aura/Spell
```cpp
// AzerothCore
player->AddAura(spellId, target);
player->RemoveAura(spellId);
player->HasAura(spellId);
player->CastSpell(target, spellId, triggered);

// TrinityCore 3.3.5 - COMPATIBLE
// Same methods available
```

**Migration Impact:** Most Player/Unit API is compatible.

---

## 5. Map/Instance Access

### AzerothCore
```cpp
Map* map = player->GetMap();
uint32 mapId = map->GetId();
Difficulty diff = map->GetDifficulty();
InstanceMap* instance = map->ToInstanceMap();

// Instance data
InstanceScript* script = instance->GetInstanceScript();
script->SetData(DATA_XXX, value);
```

### TrinityCore 3.3.5
```cpp
// Same patterns - COMPATIBLE
Map* map = player->GetMap();
uint32 mapId = map->GetId();
Difficulty diff = map->GetDifficulty();
InstanceMap* instance = map->ToInstanceMap();

InstanceScript* script = instance->GetInstanceScript();
script->SetData(DATA_XXX, value);
```

**Migration Impact:** Map API is compatible.

---

## 6. Creature/NPC AI Differences

### AzerothCore CreatureScript
```cpp
class npc_example : public CreatureScript
{
public:
    npc_example() : CreatureScript("npc_example") { }

    struct npc_exampleAI : public ScriptedAI
    {
        npc_exampleAI(Creature* creature) : ScriptedAI(creature) { }

        void Reset() override { }
        void JustEngagedWith(Unit* who) override { }
        void JustDied(Unit* killer) override { }
        void UpdateAI(uint32 diff) override { }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_exampleAI(creature);
    }
};
```

### TrinityCore 3.3.5
```cpp
// Same pattern - COMPATIBLE
class npc_example : public CreatureScript
{
public:
    npc_example() : CreatureScript("npc_example") { }

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_exampleAI(creature);
    }
};
```

**Migration Impact:** CreatureScript/AI is compatible.

---

## 7. Gossip Menu Differences

### AzerothCore
```cpp
bool OnGossipHello(Player* player, Creature* creature) override
{
    ClearGossipMenuFor(player);
    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Option 1", GOSSIP_SENDER_MAIN, 1);
    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Option 2", GOSSIP_SENDER_MAIN, 2);
    SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    return true;
}

bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
{
    CloseGossipMenuFor(player);
    // Handle action
    return true;
}
```

### TrinityCore 3.3.5
```cpp
// Different method signatures in some cases
bool OnGossipHello(Player* player, Creature* creature) override
{
    ClearGossipMenuFor(player);
    AddGossipItemFor(player, GossipOptionNpc::None, "Option 1", GOSSIP_SENDER_MAIN, 1);
    SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    return true;
}
```

**Migration Impact:** Gossip API has differences - GossipOptionNpc enum vs GOSSIP_ICON_*.

---

## 8. Configuration Access

### AzerothCore
```cpp
// World config
bool enabled = sWorld->getBoolConfig(CONFIG_XXX);
uint32 value = sWorld->getIntConfig(CONFIG_YYY);
float rate = sWorld->getRate(RATE_ZZZ);

// Custom config via WorldScript
void OnAfterConfigLoad(bool reload) override
{
    sWorld->setIntConfig(CONFIG_CUSTOM, value);
}
```

### TrinityCore 3.3.5
```cpp
// Same pattern - COMPATIBLE
bool enabled = sWorld->getBoolConfig(CONFIG_XXX);
uint32 value = sWorld->getIntConfig(CONFIG_YYY);
float rate = sWorld->getRate(RATE_ZZZ);

// Config load via WorldScript
void OnConfigLoad(bool reload) override
{
    // Custom config loading
}
```

**Migration Impact:** Compatible, method name `OnAfterConfigLoad` → `OnConfigLoad`.

---

## 9. JSON/Communication Handling

### AzerothCore (DC Custom)
```cpp
// DC uses custom Eluna-based addon communication
// Plus custom JSON handling

#include "JSON/JsonTcpSession.h"  // Custom DC
#include <nlohmann/json.hpp>      // External lib

// Addon messages
player->SendAddonMessageToPlayer("DC_ADDON", data, player);
```

### TrinityCore 3.3.5
```cpp
// No built-in JSON library
// Would need external library integration

// Addon messages - method differs
player->SendAddonMessage(...);  // Check exact signature
```

**Migration Impact:** JSON handling needs to be ported/added. Addon messaging API may differ.

---

## 10. Event System Differences

### AzerothCore
```cpp
// Basic event system
class BasicEvent
{
public:
    virtual bool Execute(uint64 e_time, uint32 p_time) = 0;
    virtual void Abort(uint64 e_time) { }
};

// Usage
player->m_Events.AddEvent(new MyEvent(), 5000);
```

### TrinityCore 3.3.5
```cpp
// Similar event system - COMPATIBLE
class BasicEvent
{
public:
    virtual bool Execute(uint64 e_time, uint32 p_time) = 0;
};

// Usage
player->m_Events.AddEvent(new MyEvent(), Milliseconds(5000));
```

**Migration Impact:** Event system compatible, some time parameter differences.

---

## 11. Enum/Constant Differences

### Power Types
```cpp
// AzerothCore
POWER_MANA, POWER_RAGE, POWER_FOCUS, POWER_ENERGY, POWER_HAPPINESS, POWER_RUNE, POWER_RUNIC_POWER

// TrinityCore 3.3.5 - COMPATIBLE
POWER_MANA, POWER_RAGE, POWER_FOCUS, POWER_ENERGY, POWER_HAPPINESS, POWER_RUNE, POWER_RUNIC_POWER
```

### Difficulty
```cpp
// AzerothCore
DUNGEON_DIFFICULTY_NORMAL, DUNGEON_DIFFICULTY_HEROIC
RAID_DIFFICULTY_10MAN_NORMAL, RAID_DIFFICULTY_10MAN_HEROIC
RAID_DIFFICULTY_25MAN_NORMAL, RAID_DIFFICULTY_25MAN_HEROIC

// TrinityCore 3.3.5 - COMPATIBLE (same values)
```

**Migration Impact:** Most enums are compatible (same WoW version).

---

## 12. String/Localization

### AzerothCore
```cpp
// Broadcast text
player->SendBroadcastMessage("Hello");
// Localized strings
sObjectMgr->GetNpcTextLocale(textId, locale);
```

### TrinityCore 3.3.5
```cpp
// Similar - COMPATIBLE
player->SendBroadcastMessage("Hello");
```

**Migration Impact:** String handling is compatible.

---

## Summary of API Changes Required

| Category | Compatibility | Changes Needed |
|----------|---------------|----------------|
| Script Registration | 🟡 Moderate | Pattern changes in all scripts |
| Database API | 🟢 High | Minor method name changes |
| Player/Unit API | 🟢 High | Minimal changes |
| Map/Instance API | 🟢 High | Minimal changes |
| CreatureScript/AI | 🟢 High | Minimal changes |
| Gossip Menu | 🟡 Moderate | Enum/method changes |
| Configuration | 🟢 High | Hook name changes |
| JSON/Addon Comms | 🔴 Low | Major rework needed |
| Event System | 🟢 High | Time parameter format |
| Enums/Constants | 🟢 High | Same WoW version |

**Legend:**
- 🟢 High compatibility (minor changes)
- 🟡 Moderate compatibility (some refactoring)
- 🔴 Low compatibility (significant rework)
