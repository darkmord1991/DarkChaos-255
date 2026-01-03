# DC System Testing Framework

**Priority:** B-Tier  
**Effort:** Low-Medium (1 week)  
**Impact:** High (Long-term)  
**Target System:** New - `src/test/DC/`

---

## Overview

Comprehensive testing framework for all DC systems, enabling automated testing, regression detection, and continuous integration.

---

## Framework Structure

```
src/test/DC/
├── DCTestFramework.h
├── DCTestFramework.cpp
├── mocks/
│   ├── MockPlayer.h
│   ├── MockCreature.h
│   ├── MockGroup.h
│   └── MockInstance.h
├── fixtures/
│   ├── TestData.sql
│   └── TestFixtures.h
├── tests/
│   ├── MythicPlusTests.cpp
│   ├── SeasonalTests.cpp
│   ├── ItemUpgradeTests.cpp
│   ├── PrestigeTests.cpp
│   ├── HotspotTests.cpp
│   ├── AOELootTests.cpp
│   ├── DungeonQuestTests.cpp
│   └── IntegrationTests.cpp
└── CMakeLists.txt
```

---

## Test Framework Core

```cpp
// DCTestFramework.h
#pragma once

#include <gtest/gtest.h>
#include <gmock/gmock.h>
#include <memory>
#include <functional>

namespace DC
{
namespace Test
{

// Test categories
enum class TestCategory
{
    UNIT,
    INTEGRATION,
    PERFORMANCE,
    REGRESSION
};

// Base test fixture for DC tests
class DCTestBase : public ::testing::Test
{
protected:
    void SetUp() override;
    void TearDown() override;
    
    // Database helpers
    void ExecuteSQL(const std::string& sql);
    QueryResult QuerySQL(const std::string& sql);
    void LoadTestFixture(const std::string& fixtureName);
    void CleanupDatabase();
    
    // Mock creation
    std::shared_ptr<MockPlayer> CreateMockPlayer(uint32 guid = 1);
    std::shared_ptr<MockCreature> CreateMockCreature(uint32 entry);
    std::shared_ptr<MockGroup> CreateMockGroup(uint8 size = 5);
    std::shared_ptr<MockInstance> CreateMockInstance(uint32 mapId);
    
    // Assertion helpers
    void AssertPlayerHasCurrency(uint32 guid, uint32 currencyId, uint32 expectedAmount);
    void AssertPlayerHasItem(uint32 guid, uint32 itemId, uint32 expectedCount);
    void AssertPlayerPrestige(uint32 guid, uint8 expectedLevel);
    void AssertMythicRating(uint32 guid, uint32 expectedRating);
    
    // Time manipulation
    void AdvanceTime(uint32 seconds);
    void SetTime(time_t timestamp);
    
    // Event simulation
    void SimulatePlayerLogin(MockPlayer* player);
    void SimulatePlayerLogout(MockPlayer* player);
    void SimulateDungeonComplete(MockInstance* instance, MockGroup* group);
    void SimulateBossKill(MockCreature* boss, MockPlayer* killer);

private:
    std::vector<std::shared_ptr<MockPlayer>> _mockPlayers;
    std::vector<std::shared_ptr<MockCreature>> _mockCreatures;
    time_t _mockTime;
};

// Performance test base
class DCPerformanceTest : public DCTestBase
{
protected:
    void StartTimer();
    uint64 StopTimer();  // Returns microseconds
    
    void BenchmarkFunction(const std::string& name, 
        std::function<void()> func, uint32 iterations = 1000);
    
    void AssertMaxDuration(uint64 maxMicroseconds);
    void AssertMaxMemory(uint64 maxBytes);

private:
    std::chrono::high_resolution_clock::time_point _startTime;
    uint64 _elapsedUs;
};

// Test registration macros
#define DC_TEST(category, name) \
    TEST_F(DCTestBase, category##_##name)

#define DC_PERF_TEST(name) \
    TEST_F(DCPerformanceTest, Perf_##name)

} // namespace Test
} // namespace DC
```

---

## Mock Objects

```cpp
// MockPlayer.h
#pragma once

#include <gmock/gmock.h>

namespace DC
{
namespace Test
{

class MockPlayer
{
public:
    MockPlayer(uint32 guid = 1) : _guid(guid) {}
    
    // Basic accessors
    ObjectGuid GetGUID() const { return ObjectGuid(HighGuid::Player, _guid); }
    uint32 GetGUIDLow() const { return _guid; }
    uint32 GetAccountId() const { return _accountId; }
    uint8 GetLevel() const { return _level; }
    uint32 GetMapId() const { return _mapId; }
    uint32 GetZoneId() const { return _zoneId; }
    
    // Setters for test setup
    void SetLevel(uint8 level) { _level = level; }
    void SetMap(uint32 mapId) { _mapId = mapId; }
    void SetZone(uint32 zoneId) { _zoneId = zoneId; }
    void SetAccountId(uint32 accountId) { _accountId = accountId; }
    
    // Mock methods
    MOCK_METHOD(void, SendAreaTriggerMessage, (const char* message));
    MOCK_METHOD(void, ModifyMoney, (int64 amount));
    MOCK_METHOD(int64, GetMoney, (), (const));
    MOCK_METHOD(bool, AddItem, (uint32 itemId, uint32 count));
    MOCK_METHOD(uint32, GetItemCount, (uint32 itemId), (const));
    MOCK_METHOD(void, GiveXP, (uint32 xp, Unit* victim));
    MOCK_METHOD(WorldSession*, GetSession, ());
    MOCK_METHOD(Group*, GetGroup, ());
    MOCK_METHOD(Map*, GetMap, ());

private:
    uint32 _guid;
    uint32 _accountId = 1;
    uint8 _level = 80;
    uint32 _mapId = 0;
    uint32 _zoneId = 0;
};

// MockCreature.h
class MockCreature
{
public:
    MockCreature(uint32 entry) : _entry(entry) {}
    
    uint32 GetEntry() const { return _entry; }
    
    MOCK_METHOD(bool, IsDungeonBoss, (), (const));
    MOCK_METHOD(bool, IsWorldBoss, (), (const));
    MOCK_METHOD(uint32, GetMaxHealth, (), (const));
    MOCK_METHOD(uint32, GetHealth, (), (const));
    MOCK_METHOD(void, SetHealth, (uint32 health));

private:
    uint32 _entry;
};

// MockGroup.h
class MockGroup
{
public:
    MockGroup(uint8 size = 5)
    {
        for (uint8 i = 0; i < size; ++i)
            _members.push_back(std::make_shared<MockPlayer>(i + 1));
    }
    
    uint8 GetMemberCount() const { return _members.size(); }
    std::vector<std::shared_ptr<MockPlayer>>& GetMembers() { return _members; }
    
    MOCK_METHOD(ObjectGuid, GetLeaderGUID, (), (const));

private:
    std::vector<std::shared_ptr<MockPlayer>> _members;
};

} // namespace Test
} // namespace DC
```

---

## Unit Tests

### Mythic+ Tests

```cpp
// MythicPlusTests.cpp
#include "DCTestFramework.h"
#include "MythicPlusRunManager.h"
#include "MythicPlusAffixManager.h"

namespace DC
{
namespace Test
{

class MythicPlusTests : public DCTestBase
{
protected:
    void SetUp() override
    {
        DCTestBase::SetUp();
        LoadTestFixture("mythicplus_base");
    }
};

DC_TEST(MythicPlus, KeystoneCreation)
{
    auto player = CreateMockPlayer(1);
    
    // Create keystone
    bool success = sMythicPlusRunMgr->CreateKeystone(player->GetGUIDLow(), 619, 10);
    
    ASSERT_TRUE(success);
    
    // Verify keystone
    auto keystone = sMythicPlusRunMgr->GetKeystone(player->GetGUIDLow());
    ASSERT_NE(keystone, nullptr);
    EXPECT_EQ(keystone->dungeonId, 619);
    EXPECT_EQ(keystone->level, 10);
}

DC_TEST(MythicPlus, RunCompletion_InTime)
{
    auto group = CreateMockGroup(5);
    auto instance = CreateMockInstance(619);
    
    // Setup run
    sMythicPlusRunMgr->StartRun(instance.get(), group.get(), 10);
    
    // Simulate completion within time
    AdvanceTime(1200);  // 20 minutes
    sMythicPlusRunMgr->CompleteRun(instance.get(), true);
    
    // Verify rewards
    for (auto& player : group->GetMembers())
    {
        auto rating = sMythicPlusRunMgr->GetRating(player->GetGUIDLow());
        EXPECT_GT(rating, 0);
        
        // Keystone should be upgraded
        auto keystone = sMythicPlusRunMgr->GetKeystone(player->GetGUIDLow());
        EXPECT_EQ(keystone->level, 11);  // +1 level
    }
}

DC_TEST(MythicPlus, RunCompletion_OverTime)
{
    auto group = CreateMockGroup(5);
    auto instance = CreateMockInstance(619);
    
    // Setup run
    sMythicPlusRunMgr->StartRun(instance.get(), group.get(), 10);
    
    // Simulate overtime completion
    AdvanceTime(2400);  // 40 minutes (over par time)
    sMythicPlusRunMgr->CompleteRun(instance.get(), true);
    
    // Verify reduced rewards
    for (auto& player : group->GetMembers())
    {
        auto rating = sMythicPlusRunMgr->GetRating(player->GetGUIDLow());
        EXPECT_GT(rating, 0);  // Still gets rating
        
        // Keystone downgraded
        auto keystone = sMythicPlusRunMgr->GetKeystone(player->GetGUIDLow());
        EXPECT_EQ(keystone->level, 9);  // -1 level
    }
}

DC_TEST(MythicPlus, AffixApplication)
{
    auto creature = CreateMockCreature(12345);
    
    // Apply Bolstering affix
    auto affix = sMythicAffixMgr->GetAffix(AFFIX_BOLSTERING);
    ASSERT_NE(affix, nullptr);
    
    affix->OnCreatureDeath(creature.get(), nullptr);
    
    // Verify nearby creatures are bolstered
    // (would need additional mock setup for nearby creatures)
}

DC_TEST(MythicPlus, VaultRewards)
{
    auto player = CreateMockPlayer(1);
    
    // Complete multiple runs
    for (int i = 0; i < 10; ++i)
    {
        sMythicPlusRunMgr->RecordRun(player->GetGUIDLow(), 619, 15, 1200, true);
    }
    
    // Check vault slots
    auto vault = sMythicPlusRunMgr->GetVaultRewards(player->GetGUIDLow());
    
    EXPECT_EQ(vault.slot1Level, 15);  // Best key
    EXPECT_EQ(vault.slot2Level, 15);  // 4+ runs
    EXPECT_EQ(vault.slot3Level, 15);  // 8+ runs
}

} // namespace Test
} // namespace DC
```

### Item Upgrade Tests

```cpp
// ItemUpgradeTests.cpp
#include "DCTestFramework.h"
#include "ItemUpgradeManager.h"

namespace DC
{
namespace Test
{

class ItemUpgradeTests : public DCTestBase
{
protected:
    void SetUp() override
    {
        DCTestBase::SetUp();
        LoadTestFixture("itemupgrade_base");
    }
};

DC_TEST(ItemUpgrade, BasicUpgrade)
{
    auto player = CreateMockPlayer(1);
    
    // Give player some tokens
    sCurrencyMgr->AddCurrency(player->GetGUIDLow(), CURRENCY_UPGRADE_TOKEN, 1000);
    
    // Simulate item (would need item mock)
    uint32 itemGuid = 12345;
    
    bool success = sItemUpgrade->UpgradeItem(player->GetGUIDLow(), itemGuid);
    
    EXPECT_TRUE(success);
    
    // Verify cost was deducted
    uint32 remaining = sCurrencyMgr->GetCurrency(player->GetGUIDLow(), CURRENCY_UPGRADE_TOKEN);
    EXPECT_LT(remaining, 1000);
}

DC_TEST(ItemUpgrade, MaxLevelReached)
{
    auto player = CreateMockPlayer(1);
    uint32 itemGuid = 12345;
    
    // Set item to max level
    sItemUpgrade->SetItemLevel(itemGuid, 80);  // MAX_UPGRADE_LEVEL
    
    // Try to upgrade
    bool success = sItemUpgrade->UpgradeItem(player->GetGUIDLow(), itemGuid);
    
    EXPECT_FALSE(success);
}

DC_TEST(ItemUpgrade, InsufficientCurrency)
{
    auto player = CreateMockPlayer(1);
    uint32 itemGuid = 12345;
    
    // No currency given
    
    bool success = sItemUpgrade->UpgradeItem(player->GetGUIDLow(), itemGuid);
    
    EXPECT_FALSE(success);
}

DC_TEST(ItemUpgrade, TierProgression)
{
    auto player = CreateMockPlayer(1);
    uint32 itemGuid = 12345;
    
    // Give enough currency for full tier
    sCurrencyMgr->AddCurrency(player->GetGUIDLow(), CURRENCY_UPGRADE_TOKEN, 100000);
    
    // Upgrade through tiers
    for (int i = 0; i < 30; ++i)  // First tier is 30 levels
    {
        sItemUpgrade->UpgradeItem(player->GetGUIDLow(), itemGuid);
    }
    
    auto state = sItemUpgrade->GetItemState(itemGuid);
    EXPECT_EQ(state.tier, UPGRADE_TIER_HEROIC);
}

} // namespace Test
} // namespace DC
```

---

## Integration Tests

```cpp
// IntegrationTests.cpp
#include "DCTestFramework.h"

namespace DC
{
namespace Test
{

class IntegrationTests : public DCTestBase
{
protected:
    void SetUp() override
    {
        DCTestBase::SetUp();
        LoadTestFixture("integration_full");
    }
};

DC_TEST(Integration, MythicPlusSeasonPass)
{
    auto player = CreateMockPlayer(1);
    auto group = CreateMockGroup(5);
    auto instance = CreateMockInstance(619);
    
    // Setup season pass
    sSeasonPass->SetPlayerActive(player->GetGUIDLow(), true);
    uint8 initialLevel = sSeasonPass->GetLevel(player->GetGUIDLow());
    
    // Complete M+ run
    sMythicPlusRunMgr->StartRun(instance.get(), group.get(), 15);
    AdvanceTime(1200);
    sMythicPlusRunMgr->CompleteRun(instance.get(), true);
    
    // Verify season pass XP was gained
    uint8 newLevel = sSeasonPass->GetLevel(player->GetGUIDLow());
    EXPECT_GT(newLevel, initialLevel);
}

DC_TEST(Integration, PrestigeItemUpgradeDiscount)
{
    auto player = CreateMockPlayer(1);
    
    // Set prestige level
    sPrestige->SetPrestige(player->GetGUIDLow(), 10);
    
    // Check upgrade cost (should be discounted)
    uint32 normalCost = sItemUpgrade->GetUpgradeCost(1);  // Level 1 upgrade
    uint32 discountedCost = sItemUpgrade->GetUpgradeCostForPlayer(player->GetGUIDLow(), 1);
    
    EXPECT_LT(discountedCost, normalCost);
}

DC_TEST(Integration, HotspotMythicPlusXP)
{
    auto player = CreateMockPlayer(1);
    
    // Place player in hotspot
    player->SetMap(619);  // M+ dungeon
    player->SetZone(1234);  // Hotspot zone
    
    // Start tracking
    uint32 initialXP = sHotspot->GetPlayerXP(player->GetGUIDLow(), 1);
    
    // Kill creatures
    for (int i = 0; i < 10; ++i)
    {
        auto creature = CreateMockCreature(12345);
        SimulateBossKill(creature.get(), player.get());
    }
    
    // Verify hotspot XP gained
    uint32 newXP = sHotspot->GetPlayerXP(player->GetGUIDLow(), 1);
    EXPECT_GT(newXP, initialXP);
}

DC_TEST(Integration, CrossSystemEventBus)
{
    auto player = CreateMockPlayer(1);
    
    // Track events received
    std::vector<DC::EventType> receivedEvents;
    
    sEventBus->Subscribe(DC::EventType::MYTHIC_RUN_COMPLETE, 
        [&](const DC::Event& e) { receivedEvents.push_back(e.type); });
    
    sEventBus->Subscribe(DC::EventType::CURRENCY_GAINED,
        [&](const DC::Event& e) { receivedEvents.push_back(e.type); });
    
    // Trigger M+ completion
    auto instance = CreateMockInstance(619);
    auto group = CreateMockGroup(5);
    sMythicPlusRunMgr->StartRun(instance.get(), group.get(), 10);
    sMythicPlusRunMgr->CompleteRun(instance.get(), true);
    
    // Verify events were fired
    EXPECT_TRUE(std::find(receivedEvents.begin(), receivedEvents.end(), 
        DC::EventType::MYTHIC_RUN_COMPLETE) != receivedEvents.end());
    EXPECT_TRUE(std::find(receivedEvents.begin(), receivedEvents.end(),
        DC::EventType::CURRENCY_GAINED) != receivedEvents.end());
}

} // namespace Test
} // namespace DC
```

---

## Performance Tests

```cpp
// PerformanceTests.cpp
#include "DCTestFramework.h"

namespace DC
{
namespace Test
{

DC_PERF_TEST(PlayerProfileLoad)
{
    BenchmarkFunction("Profile Load", []()
    {
        for (uint32 i = 1; i <= 1000; ++i)
        {
            sPlayerProfile->GetProfile(i);
        }
    }, 100);
    
    AssertMaxDuration(50000);  // 50ms max for 100k loads
}

DC_PERF_TEST(MythicRatingCalculation)
{
    BenchmarkFunction("Rating Calculation", []()
    {
        for (int i = 0; i < 1000; ++i)
        {
            sMythicPlusRunMgr->CalculateRating(619, 15, 1200, true);
        }
    }, 1000);
    
    AssertMaxDuration(10000);  // 10ms max for 1M calculations
}

DC_PERF_TEST(HotspotPlayerCheck)
{
    auto player = CreateMockPlayer(1);
    
    BenchmarkFunction("Hotspot Check", [&]()
    {
        for (int i = 0; i < 1000; ++i)
        {
            sHotspot->IsPlayerInHotspot(player->GetGUIDLow());
        }
    }, 1000);
    
    AssertMaxDuration(5000);  // 5ms max for 1M checks
}

DC_PERF_TEST(CacheHitRate)
{
    // Warm up cache
    for (uint32 i = 1; i <= 100; ++i)
    {
        sCache->PlayerProfiles().Set(i, CreateTestProfile(i));
    }
    
    StartTimer();
    
    // Test cache hits
    for (int iteration = 0; iteration < 10000; ++iteration)
    {
        for (uint32 i = 1; i <= 100; ++i)
        {
            PlayerProfile profile;
            sCache->PlayerProfiles().Get(i, profile);
        }
    }
    
    auto elapsed = StopTimer();
    
    EXPECT_GT(sCache->PlayerProfiles().HitRate(), 99.0f);
    AssertMaxDuration(100000);  // 100ms max for 1M lookups
}

} // namespace Test
} // namespace DC
```

---

## CI Integration

```yaml
# .github/workflows/dc-tests.yml
name: DC System Tests

on:
  push:
    paths:
      - 'src/server/scripts/DC/**'
      - 'src/test/DC/**'
  pull_request:
    paths:
      - 'src/server/scripts/DC/**'
      - 'src/test/DC/**'

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: test
          MYSQL_DATABASE: acore_test
        ports:
          - 3306:3306
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Build
        run: |
          mkdir build
          cd build
          cmake .. -DBUILD_TESTING=ON -DDC_TESTS=ON
          
      - name: Build
        run: |
          cd build
          make -j$(nproc)
          
      - name: Run Unit Tests
        run: |
          cd build
          ctest --output-on-failure -L DC_Unit
          
      - name: Run Integration Tests
        run: |
          cd build
          ctest --output-on-failure -L DC_Integration
          
      - name: Run Performance Tests
        run: |
          cd build
          ctest --output-on-failure -L DC_Performance
```

---

## Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| Framework | 2 days | Core test infrastructure |
| Mocks | 1 day | Mock objects |
| Unit Tests | 2 days | Per-system tests |
| Integration | 1 day | Cross-system tests |
| Performance | 1 day | Benchmark tests |
| CI Setup | 1 day | GitHub Actions |
| **Total** | **~1.5 weeks** | |

---

## Benefits

1. **Regression Prevention** - Catch bugs before production
2. **Refactoring Safety** - Confident code changes
3. **Documentation** - Tests document expected behavior
4. **Performance Tracking** - Detect slowdowns early
5. **CI/CD Ready** - Automated validation
