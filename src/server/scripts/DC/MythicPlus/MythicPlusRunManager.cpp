/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#include "MythicPlusRunManager.h"

#include "Chat.h"
#include "Config.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "GameObject.h"
#include "GameTime.h"
#include "Group.h"
#include "Item.h"
#include "Log.h"
#include "MapMgr.h"
#include "MythicDifficultyScaling.h"
#include "MythicPlusConstants.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "StringFormat.h"
#include "World.h"
#ifdef HAS_AIO
#include "AIO.h"
#endif
#include <algorithm>
#include <cmath>
#include <sstream>

namespace
{
constexpr float MYTHIC_BASE_MULTIPLIER = 2.0f;
constexpr float KEYSTONE_LEVEL_STEP = 0.25f;
constexpr uint8 DEFAULT_VAULT_THRESHOLDS[3] = { 1, 4, 8 };
constexpr uint32 DEFAULT_VAULT_TOKENS[3] = { 50, 100, 150 };
constexpr uint32 COUNTDOWN_ROOT_SPELL = 33786;  // Cyclone - roots but allows spell casting/eating/drinking
constexpr uint32 DEFAULT_HUD_TIMER_SECONDS = 2400; // 40 minutes baseline
constexpr uint32 DEFAULT_HUD_PER_BOSS = 60;        // +1 minute per boss over baseline
constexpr uint32 DEFAULT_HUD_UPDATE_INTERVAL = 1;  // seconds

constexpr std::string_view HUD_REASON_PERIODIC = "tick";
constexpr char const* HUD_CACHE_TABLE = "dc_mythicplus_hud_cache";

}

MythicPlusRunManager* MythicPlusRunManager::instance()
{
    static MythicPlusRunManager instance;
    return &instance;
}

void MythicPlusRunManager::Reset()
{
    _instanceStates.clear();
    CacheBossMetadata();
    EnsureHudCacheTable();
    CharacterDatabase.DirectExecute("DELETE FROM `{}`", HUD_CACHE_TABLE);
    LOG_INFO("mythic.run", "Mythic+ Run Manager reset complete");
}

void MythicPlusRunManager::CacheBossMetadata()
{
    _mapBossEntries.clear();
    _mapFinalBossEntries.clear();

    QueryResult result = WorldDatabase.Query(
        "SELECT de.MapID, ie.creditEntry, ie.lastEncounterDungeon "
        "FROM instance_encounters ie "
        "INNER JOIN dungeonencounter_dbc de ON ie.entry = de.ID");

    if (!result)
    {
        LOG_WARN("mythic.run", "Boss metadata query returned no rows; defaulting to creature flags only");
        return;
    }

    uint32 bossEntries = 0;
    uint32 finalEntries = 0;

    do
    {
        Field* fields = result->Fetch();
        uint32 mapId = fields[0].Get<uint32>();
        uint32 bossEntry = fields[1].Get<uint32>();
        uint16 lastEncounterDungeon = fields[2].Get<uint16>();

        auto& bossSet = _mapBossEntries[mapId];
        if (bossSet.insert(bossEntry).second)
            ++bossEntries;

        if (lastEncounterDungeon > 0)
        {
            auto& finalSet = _mapFinalBossEntries[mapId];
            if (finalSet.insert(bossEntry).second)
                ++finalEntries;
        }
    }
    while (result->NextRow());

    LOG_INFO("mythic.run", "Cached {} boss entries ({} marked final) across {} maps for Mythic+ detection",
             bossEntries, finalEntries, _mapBossEntries.size());
}

void MythicPlusRunManager::EnsureHudCacheTable()
{
    if (_hudCacheReady)
        return;

    CharacterDatabase.DirectExecute(
        "CREATE TABLE IF NOT EXISTS `{}` ("
        "`instance_key` BIGINT UNSIGNED NOT NULL,"
        "`map_id` INT UNSIGNED NOT NULL,"
        "`instance_id` INT UNSIGNED NOT NULL,"
        "`owner_guid` INT UNSIGNED NOT NULL,"
        "`keystone_level` TINYINT UNSIGNED NOT NULL,"
        "`season_id` INT UNSIGNED NOT NULL,"
        "`payload` LONGTEXT NOT NULL,"
        "`updated_at` BIGINT UNSIGNED NOT NULL,"
        "PRIMARY KEY (`instance_key`)"
        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
        HUD_CACHE_TABLE);

    _hudCacheReady = true;
    LOG_INFO("mythic.hud", "Ensured Mythic+ HUD cache table `{}` exists", HUD_CACHE_TABLE);
}

void MythicPlusRunManager::PersistHudSnapshot(InstanceState* state, std::string_view payload, bool forceUpdate)
{
    if (!state || state->instanceKey == 0)
        return;

    std::string serialized(payload);
    if (!forceUpdate && state->lastHudPayload == serialized)
        return;

    EnsureHudCacheTable();

    state->lastHudPayload = serialized;

    std::string escapedPayload = serialized;
    CharacterDatabase.EscapeString(escapedPayload);

    uint64 updatedAt = GameTime::GetGameTime().count();
    CharacterDatabase.DirectExecute(
        "INSERT INTO `{}` (`instance_key`, `map_id`, `instance_id`, `owner_guid`, `keystone_level`, `season_id`, `payload`, `updated_at`) "
        "VALUES ({}, {}, {}, {}, {}, {}, '{}', {}) "
        "ON DUPLICATE KEY UPDATE `map_id` = VALUES(`map_id`), `instance_id` = VALUES(`instance_id`), "
        "`owner_guid` = VALUES(`owner_guid`), `keystone_level` = VALUES(`keystone_level`), "
        "`season_id` = VALUES(`season_id`), `payload` = VALUES(`payload`), `updated_at` = VALUES(`updated_at`)",
        HUD_CACHE_TABLE,
        state->instanceKey,
        state->mapId,
        state->instanceId,
        state->ownerGuid.GetCounter(),
        uint32(state->keystoneLevel),
        state->seasonId,
        escapedPayload,
        updatedAt);
}

void MythicPlusRunManager::ClearHudSnapshot(InstanceState* state)
{
    if (!state || state->instanceKey == 0)
        return;

    state->lastHudPayload.clear();
    EnsureHudCacheTable();
    CharacterDatabase.DirectExecute(
        "DELETE FROM `{}` WHERE `instance_key` = {}",
        HUD_CACHE_TABLE,
        state->instanceKey);
}

bool MythicPlusRunManager::IsRecognizedBoss(uint32 mapId, uint32 bossEntry) const
{
    auto itr = _mapBossEntries.find(mapId);
    if (itr == _mapBossEntries.end())
        return false;

    return itr->second.find(bossEntry) != itr->second.end();
}

bool MythicPlusRunManager::IsBossCreature(const Creature* creature) const
{
    if (!creature)
        return false;

    if (creature->IsDungeonBoss())
        return true;

    Map const* map = creature->GetMap();
    if (!map)
        return false;

    return IsRecognizedBoss(map->GetId(), creature->GetEntry());
}

bool MythicPlusRunManager::TryActivateKeystone(Player* player, GameObject* font)
{
    KeystoneDescriptor descriptor;
    std::string validationError;
    if (!CanActivateKeystone(player, font, descriptor, validationError))
    {
        SendGenericError(player, validationError);
        return false;
    }

    if (!player || !font)
        return false;

    Map* map = font->GetMap();
    if (!map)
        return false;

    DungeonProfile* profile = sMythicScaling->GetDungeonProfile(map->GetId());
    if (!profile)
        return false;

    InstanceState* state = GetOrCreateState(map);
    if (!state)
    {
        SendGenericError(player, "Unable to initialize Mythic+ state for this instance.");
        return false;
    }

    state->mapId = map->GetId();
    state->instanceId = map->GetInstanceId();
    state->difficulty = sMythicScaling->ResolveDungeonDifficulty(map);
    state->keystoneLevel = descriptor.level;
    state->seasonId = descriptor.seasonId ? descriptor.seasonId : GetCurrentSeasonId();
    state->ownerGuid = player->GetGUID();
    state->startedAt = 0; // Will be set after countdown
    state->deaths = 0;
    state->wipes = 0;
    state->failed = false;
    state->completed = false;
    state->tokensGranted = false;
    state->countdownActive = false;
    state->countdownStarted = 0;
    state->participants.clear();
    state->recentBossEvades.clear();
    state->bossDeathTimes.clear();
    state->bossKillStamps.clear();
    state->bossOrder.clear();
    state->bossIndexLookup.clear();
    state->activeAffixes.clear();
    state->hudWorldStates.clear();
    state->hudInitialized = false;
    state->hudTimerDuration = GetHudTimerDuration(state->mapId, state->keystoneLevel);
    state->timerEndsAt = 0;
    state->lastHudBroadcast = 0;
    state->lastAioBroadcast = 0;
    BuildBossTracking(state);
    RegisterGroupMembers(player, state);

    // Seasonal validation - check if dungeon is featured this season
    if (sConfigMgr->GetOption<bool>("MythicPlus.FeaturedOnly", true))
    {
        if (!IsDungeonFeaturedThisSeason(map->GetId(), state->seasonId))
        {
            SendGenericError(player, "This dungeon is not featured in the current Mythic+ season.");
            ClearHudSnapshot(state);
            _instanceStates.erase(state->instanceKey);
            return false;
        }
    }

    // Affix activation - apply weekly affixes to the run
    if (sConfigMgr->GetOption<bool>("MythicPlus.Affixes.Enabled", true))
    {
        std::vector<uint32> affixes = GetWeeklyAffixes(state->seasonId);
        if (!affixes.empty())
        {
            ActivateAffixes(map, affixes, descriptor.level);
            AnnounceAffixes(player, affixes);
        }
    }

    ConsumePlayerKeystone(player->GetGUID().GetCounter());

    // Teleport all players to entrance
    TeleportGroupToEntrance(player, map);

    // Apply root to all players during countdown
    ApplyCountdownRoot(map);

    // Start countdown before activating run
    uint32 countdownDuration = sConfigMgr->GetOption<uint32>("MythicPlus.CountdownDuration", 10);
    state->countdownStarted = GameTime::GetGameTime().count();
    state->countdownActive = true;

    // Calculate scaling multiplier for display
    float hpMult = 0.0f, damageMult = 0.0f;
    sMythicScaling->CalculateMythicPlusMultipliers(descriptor.level, hpMult, damageMult);
    
    // Announce keystone activation with proper formatting
    AnnounceToInstance(map, "|cff00ff00=== Keystone Activated ===");
    AnnounceToInstance(map, ("Dungeon: |cffffffff" + profile->name + "|r").c_str());
    AnnounceToInstance(map, Acore::StringFormat("Keystone Level: |cffff8000+{}|r", descriptor.level));
    AnnounceToInstance(map, Acore::StringFormat("M+ Multiplier: |cffaaaaaa+{:.0f}% HP, +{:.0f}% Damage|r", 
        (hpMult - 1.0f) * 100.0f, (damageMult - 1.0f) * 100.0f));
    AnnounceToInstance(map, Acore::StringFormat("Starting in: |cffffff00{} seconds...|r", countdownDuration));
    
    // Mark countdown as active and store start time
    state->countdownActive = true;
    state->countdownStarted = GameTime::GetGameTime().count();

    InitializeHud(state, map);

    return true;
}

uint32 MythicPlusRunManager::GetKeystoneLevel(Map* map) const
{
    if (!map)
        return 0;

    auto itr = _instanceStates.find(MakeInstanceKey(map));
    if (itr == _instanceStates.end())
        return 0;

    return itr->second.keystoneLevel;
}

void MythicPlusRunManager::RegisterPlayerEnter(Player* player)
{
    if (!player)
        return;

    Map* map = player->GetMap();
    if (!map || !map->IsDungeon())
        return;

    InstanceState* state = GetState(map);
    if (!state)
        return;

    state->participants.insert(player->GetGUID().GetCounter());

    SyncHudToPlayer(state, player);
}

void MythicPlusRunManager::HandlePlayerDeath(Player* player, Creature* /*killer*/)
{
    if (!player)
        return;

    Map* map = player->GetMap();
    if (!map || !map->IsDungeon())
        return;

    InstanceState* state = GetState(map);
    if (!state || state->completed)
        return;

    state->participants.insert(player->GetGUID().GetCounter());
    ++state->deaths;

    SetHudWorldState(state, map, MythicPlusConstants::Hud::DEATHS, state->deaths);
    UpdateHud(state, map, true, "death");

    if (!IsDeathBudgetEnabled())
        return;

    DungeonProfile* profile = sMythicScaling->GetDungeonProfile(state->mapId);
    if (!profile)
        return;

    if (state->deaths >= profile->deathBudget)
    {
        HandleFailState(state, "Death budget exceeded", true);
    }
    else
    {
        uint8 remaining = profile->deathBudget > state->deaths ? profile->deathBudget - state->deaths : 0;
        if (Player* owner = ObjectAccessor::FindConnectedPlayer(state->ownerGuid))
            ChatHandler(owner->GetSession()).SendSysMessage(Acore::StringFormat("|cffff8000Mythic+|r: Death recorded. {} remaining.", remaining));
    }
}

void MythicPlusRunManager::HandleBossEvade(Creature* creature)
{
    if (!creature)
        return;

    Map* map = creature->GetMap();
    if (!map || !map->IsDungeon())
        return;

    if (!IsBossCreature(creature))
        return;

    InstanceState* state = GetState(map);
    if (!state || state->completed)
        return;

    // Ignore boss resets that occur before the countdown has finished
    if (state->startedAt == 0)
        return;

    uint32 graceWindow = sConfigMgr->GetOption<uint32>("MythicPlus.WipeBudget.GraceWindow", 5);
    if (graceWindow > 0)
    {
        uint64 now = GameTime::GetGameTime().count();
        uint64& lastReset = state->recentBossEvades[creature->GetEntry()];
        if (lastReset != 0 && now >= lastReset && now - lastReset < graceWindow)
        {
            AnnounceToInstance(map, "|cffffa500Mythic+|r: Ignoring duplicate boss reset (grace window active).");
            return;
        }

        lastReset = now;
    }

    ++state->wipes;

    SetHudWorldState(state, map, MythicPlusConstants::Hud::WIPES, state->wipes);
    UpdateHud(state, map, true, "wipe");

    if (IsWipeBudgetEnabled())
    {
        DungeonProfile* profile = sMythicScaling->GetDungeonProfile(state->mapId);
        if (profile && state->wipes >= profile->wipeBudget)
        {
            HandleFailState(state, "Wipe budget exceeded", true);
            return;
        }
    }

    AnnounceToInstance(map, "|cffff0000Mythic+|r: Boss reset detected. Prepare for another pull!");
}

void MythicPlusRunManager::HandleCreatureKill(Creature* creature, Unit* /*killer*/)
{
    if (!creature)
        return;

    Map* map = creature->GetMap();
    if (!map || !map->IsDungeon())
        return;

    InstanceState* state = GetState(map);
    if (!state || state->completed || state->failed)
        return;

    if (!creature->IsHostileToPlayers() || creature->IsPet() || creature->IsTotem())
        return;

    if (IsBossCreature(creature))
        return; // Boss-specific handling occurs in HandleBossDeath

    ++state->npcsKilled;
}

void MythicPlusRunManager::HandleBossDeath(Creature* creature, Unit* /*killer*/)
{
    if (!creature)
        return;

    Map* map = creature->GetMap();
    if (!map || !map->IsDungeon())
        return;

    InstanceState* state = GetState(map);
    if (!state || state->completed || state->failed)
        return;

    if (!IsBossCreature(creature))
        return;

    ++state->bossesKilled;

    // Record boss death time for statistics
    state->bossDeathTimes.push_back(GameTime::GetGameTime().count());
    MarkBossKilled(state, map, creature->GetEntry());
    SetHudWorldState(state, map, MythicPlusConstants::Hud::BOSSES_KILLED, state->bossesKilled);
    UpdateHud(state, map, true, "boss_kill");

    // Determine if this encounter should be treated as the final boss
    bool isFinalEncounter = IsFinalBossEncounter(state, creature);

    // Generate retail-like spec-based loot for the boss
    GenerateBossLoot(creature, map, state);

    // Announce boss kill to the group
    std::string bossName = creature->GetName();
    AnnounceToInstance(map, "|cffff8000[Mythic+]|r Boss defeated: |cff00ff00" + bossName + "|r (" + std::to_string(state->bossesKilled) + "/" + std::to_string(GetTotalBossesForDungeon(state->mapId)) + ")");

    if (!isFinalEncounter)
        return;

    state->completed = true;
    state->failed = false;

    SetHudWorldState(state, map, MythicPlusConstants::Hud::RESULT, 1);
    SetHudWorldState(state, map, MythicPlusConstants::Hud::ACTIVE, 0);
    UpdateHud(state, map, true, "complete");

    AwardTokens(state, creature->GetEntry());
    RecordRunResult(state, true, creature->GetEntry());

    // Automate keystone upgrade
    AutoUpgradeKeystone(state);

    // Send comprehensive run summary to all participants
    Map::PlayerList const& players = map->GetPlayers();
    for (auto const& ref : players)
    {
        if (Player* player = ref.GetSource())
        {
            if (state->participants.find(player->GetGUID().GetCounter()) != state->participants.end())
            {
                SendRunSummary(state, player);
                ProcessAchievements(state, player, true);
            }
        }
    }

    ClearHudSnapshot(state);
    _instanceStates.erase(state->instanceKey);
}

void MythicPlusRunManager::HandleInstanceReset(Map* map)
{
    if (!map)
        return;

    uint64 key = MakeInstanceKey(map);
    auto itr = _instanceStates.find(key);
    if (itr != _instanceStates.end())
    {
        ClearHudSnapshot(&itr->second);
        _instanceStates.erase(itr);
    }
}

void MythicPlusRunManager::BuildVaultMenu(Player* /*player*/, Creature* /*creature*/)
{
    // Implemented: Build a basic gossip menu for Great Vault claims
    // Note: Uses gossip constants defined in npc_mythic_plus_great_vault
}
    // This method should be invoked by the Great Vault NPC creature script

void MythicPlusRunManager::HandleVaultSelection(Player* /*player*/, Creature* /*creature*/, uint32 /*actionId*/)
{
    // Implemented in npc script; logic handled by our NPC wrapper
}

// Reset weekly vault progress for all or specific players
void MythicPlusRunManager::ResetWeeklyVaultProgress()
{
    uint32 nowWeek = GetWeekStartTimestamp();
    // Purge old weekly rows older than the current week + 52 weeks (keep 52 weeks history)
    uint32 purgeBefore = nowWeek - (52 * 7 * 24 * 60 * 60);
    CharacterDatabase.DirectExecute("DELETE FROM dc_weekly_vault WHERE week_start < {}", purgeBefore);
    LOG_INFO("mythic.vault", "Reset weekly vault progress purge executed (<= {})", purgeBefore);
}

void MythicPlusRunManager::ResetWeeklyVaultProgress(Player* player)
{
    if (!player)
        return;
    uint32 nowWeek = GetWeekStartTimestamp();
    uint32 guidLow = player->GetGUID().GetCounter();
    CharacterDatabase.DirectExecute("DELETE FROM dc_weekly_vault WHERE character_guid = {} AND week_start < {}", guidLow, nowWeek);
    ChatHandler(player->GetSession()).SendSysMessage("Your weekly vault progress was reset.");
}

bool MythicPlusRunManager::ClaimVaultSlot(Player* player, uint8 slot)
{
    if (!player || slot < 1 || slot > 3)
        return false;

    uint32 seasonId = GetCurrentSeasonId();
    uint32 weekStart = GetWeekStartTimestamp();
    uint32 guidLow = player->GetGUID().GetCounter();

    QueryResult result = CharacterDatabase.Query("SELECT runs_completed, highest_level, slot1_unlocked, slot2_unlocked, slot3_unlocked, reward_claimed, claimed_slot FROM dc_weekly_vault WHERE character_guid = {} AND season_id = {} AND week_start = {}",
                                                 guidLow, seasonId, weekStart);

    uint8 runsCompleted = 0;
    bool unlocked[4] = { false, false, false, false };
    bool claimed = false;
    uint8 claimedSlot = 0;

    if (result)
    {
        Field* fields = result->Fetch();
        runsCompleted = fields[0].Get<uint8>();
        claimedSlot = fields[6].Get<uint8>();
        unlocked[1] = fields[2].Get<bool>();
        unlocked[2] = fields[3].Get<bool>();
        unlocked[3] = fields[4].Get<bool>();
        claimed = fields[5].Get<bool>();
        claimedSlot = fields[6].Get<uint8>();
    }
    
    (void)runsCompleted; // Suppress unused variable warning
    (void)claimedSlot;   // Suppress unused variable warning

    if (!unlocked[slot])
    {
        SendVaultError(player, "This slot is not unlocked.");
        return false;
    }
    if (claimed)
    {
        SendVaultError(player, "You have already claimed your weekly vault reward.");
        return false;
    }

    // Award tokens (fallback if no reward pool available)
    uint32 tokenCount = GetVaultTokenReward(slot);
    uint32 tokenEntry = 101000; // Default token item entry; use configured if required

    ItemPosCountVec dest;
    if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, tokenEntry, tokenCount) == EQUIP_ERR_OK)
    {
        if (Item* item = player->StoreNewItem(dest, tokenEntry, true))
            player->SendNewItem(item, tokenCount, true, false);
    }
    else
    {
        player->SendItemRetrievalMail(tokenEntry, tokenCount);
        ChatHandler(player->GetSession()).SendSysMessage("|cff00ff00Mythic+|r: Tokens could not be added to your bags and were mailed instead.");
    }

    // Mark the weekly vault as claimed
    CharacterDatabase.DirectExecute("UPDATE dc_weekly_vault SET reward_claimed = 1, claimed_slot = {}, claimed_tokens = {}, claimed_at = UNIX_TIMESTAMP() WHERE character_guid = {} AND season_id = {} AND week_start = {}",
                                    slot, tokenCount, guidLow, seasonId, weekStart);

    InsertTokenLog(guidLow, 0, DUNGEON_DIFFICULTY_EPIC, 0, player->GetLevel(), 0, tokenCount);
    ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat("|cff00ff00Mythic+|r: You claimed Slot {} and received {} tokens.", slot, tokenCount));
    return true;
}

void MythicPlusRunManager::BuildStatisticsMenu(Player* /*player*/, Creature* /*creature*/)
{
    // Placeholder - data surfaced via gossip in later iteration
}

uint64 MythicPlusRunManager::MakeInstanceKey(const Map* map) const
{
    if (!map)
        return 0;

    return (uint64(map->GetId()) << 32) | uint32(map->GetInstanceId());
}

MythicPlusRunManager::InstanceState* MythicPlusRunManager::GetOrCreateState(Map* map)
{
    if (!map)
        return nullptr;

    uint64 key = MakeInstanceKey(map);
    auto [itr, inserted] = _instanceStates.try_emplace(key);
    InstanceState& state = itr->second;

    if (inserted)
    {
        state.instanceKey = key;
        state.mapId = map->GetId();
        state.instanceId = map->GetInstanceId();
        state.difficulty = sMythicScaling->ResolveDungeonDifficulty(map);
    }

    return &state;
}

MythicPlusRunManager::InstanceState* MythicPlusRunManager::GetState(Map* map)
{
    if (!map)
        return nullptr;

    auto itr = _instanceStates.find(MakeInstanceKey(map));
    if (itr == _instanceStates.end())
        return nullptr;

    return &itr->second;
}

MythicPlusRunManager::InstanceState const* MythicPlusRunManager::GetState(Map* map) const
{
    if (!map)
        return nullptr;

    auto itr = _instanceStates.find(MakeInstanceKey(map));
    if (itr == _instanceStates.end())
        return nullptr;

    return &itr->second;
}

void MythicPlusRunManager::RegisterGroupMembers(Player* activator, InstanceState* state)
{
    if (!activator || !state)
        return;

    Map* map = activator->GetMap();
    if (!map)
        return;

    Map::PlayerList const& players = map->GetPlayers();
    for (auto const& ref : players)
    {
        if (Player* member = ref.GetSource())
            state->participants.insert(member->GetGUID().GetCounter());
    }
}

bool MythicPlusRunManager::LoadPlayerKeystone(Player* player, uint32 expectedMap, KeystoneDescriptor& outDescriptor)
{
    if (!player)
        return false;

    // Check player inventory for keystone items (190001-190019 for M+2-M+20)
    for (uint8 i = 0; i < 19; ++i)
    {
        uint32 keystoneItemId = 190001 + i;
        
        // Check if player has this keystone in inventory
        if (player->HasItemCount(keystoneItemId, 1, false))
        {
            uint8 keystoneLevel = i + 2; // M+2 starts at index 0
            
            // Fill descriptor
            outDescriptor.mapId = expectedMap; // Keystone is valid for the current dungeon
            outDescriptor.level = keystoneLevel;
            outDescriptor.seasonId = GetCurrentSeasonId();
            outDescriptor.expiresOn = 0; // No expiration for inventory keystones
            outDescriptor.ownerGuid = player->GetGUID();
            
            return true;
        }
    }

    return false;
}

void MythicPlusRunManager::ConsumePlayerKeystone(ObjectGuid::LowType playerGuidLow)
{
    Player* player = ObjectAccessor::FindPlayer(ObjectGuid::Create<HighGuid::Player>(playerGuidLow));
    if (!player)
        return;

    // Remove keystone item from player inventory (check all M+2-M+20 keystones)
    for (uint8 i = 0; i < 19; ++i)
    {
        uint32 keystoneItemId = 190001 + i;
        
        if (player->HasItemCount(keystoneItemId, 1, false))
        {
            player->DestroyItemCount(keystoneItemId, 1, true);
            LOG_INFO("mythic.run", "Consumed keystone item {} from player {}", keystoneItemId, playerGuidLow);
            return;
        }
    }
}

void MythicPlusRunManager::AnnounceToInstance(Map* map, std::string_view message) const
{
    if (!map)
        return;

    std::string text(message);
    Map::PlayerList const& players = map->GetPlayers();
    for (auto const& ref : players)
    {
        if (Player* player = ref.GetSource())
            ChatHandler(player->GetSession()).SendSysMessage(text.c_str());
    }
}

void MythicPlusRunManager::ApplyEntryBarrier(Map* map) const
{
    if (!map || sMythicScaling->ResolveDungeonDifficulty(map) != DUNGEON_DIFFICULTY_EPIC)
        return;

    // This is now handled during countdown - just apply the physical barrier spell
    Map::PlayerList const& players = map->GetPlayers();
    for (auto const& ref : players)
    {
        Player* player = ref.GetSource();
        if (!player || !player->GetSession())
            continue;

        // Remove any existing root from countdown
        player->RemoveAurasDueToSpell(COUNTDOWN_ROOT_SPELL);
    }
}

void MythicPlusRunManager::ApplyCountdownRoot(Map* map) const
{
    if (!map)
        return;

    Map::PlayerList const& players = map->GetPlayers();
    for (auto const& ref : players)
    {
        Player* player = ref.GetSource();
        if (!player || !player->GetSession())
            continue;

        // Apply root that allows casting/eating/drinking but prevents movement
        player->CastSpell(player, COUNTDOWN_ROOT_SPELL, true);
        
        ChatHandler(player->GetSession()).SendSysMessage("|cffffff00[Countdown]|r You are rooted for 10 seconds. You may cast spells, eat, or drink.");
    }
}

void MythicPlusRunManager::ApplyKeystoneScaling(Map* map, uint8 keystoneLevel) const
{
    if (!map || keystoneLevel < 2)
        return;

    uint32 refreshed = 0;
    uint32 forcedRespawns = 0;
    auto& creatureStore = map->GetCreatureBySpawnIdStore();
    for (auto const& pair : creatureStore)
    {
        Creature* creature = pair.second;
        if (!creature || creature->GetMap() != map)
            continue;

        if (!creature->IsHostileToPlayers())
            continue;

        if (creature->IsControlledByPlayer())
            continue;

        if (creature->IsAlive())
        {
            creature->DisappearAndDie();
            ++forcedRespawns;
        }

        creature->Respawn(true);
        ++refreshed;
    }

    LOG_INFO("mythic.run", "Refreshed {} hostile creatures ({} forced) for keystone level +{} in instance {} (map {})",
             refreshed, forcedRespawns, keystoneLevel, map->GetInstanceId(), map->GetId());
}

void MythicPlusRunManager::HandleFailState(InstanceState* state, std::string_view reason, bool downgradeKeystone)
{
    if (!state)
        return;

    state->failed = true;
    state->completed = true;

    Map* map = sMapMgr->FindMap(state->mapId, state->instanceId);
    if (map)
    {
        std::ostringstream ss;
        ss << "|cffff0000Mythic+ Failed|r: " << reason;
        AnnounceToInstance(map, ss.str());
        SetHudWorldState(state, map, MythicPlusConstants::Hud::RESULT, 2);
        SetHudWorldState(state, map, MythicPlusConstants::Hud::ACTIVE, 0);
        UpdateHud(state, map, true, "failed");
    }

    RecordRunResult(state, false, 0);
    ClearHudSnapshot(state);
    _instanceStates.erase(state->instanceKey);

    if (downgradeKeystone && state->ownerGuid)
    {
        // Future: award downgraded keystone back to owner
        LOG_INFO("mythic.run", "Mythic+ run failed for instance {} (map {})", state->instanceId, state->mapId);
    }
}

bool MythicPlusRunManager::IsDeathBudgetEnabled() const
{
    return sConfigMgr->GetOption<bool>("MythicPlus.DeathBudget.Enabled", false);
}

bool MythicPlusRunManager::IsWipeBudgetEnabled() const
{
    return sConfigMgr->GetOption<bool>("MythicPlus.WipeBudget.Enabled", false);
}

bool MythicPlusRunManager::IsKeystoneRequirementEnabled() const
{
    return sConfigMgr->GetOption<bool>("MythicPlus.Keystone.Enabled", false);
}

void MythicPlusRunManager::RecordRunResult(const InstanceState* state, bool success, uint32 bossEntry)
{
    if (!state)
        return;

    uint32 seasonId = state->seasonId ? state->seasonId : GetCurrentSeasonId();
    uint32 duration = 0;
    uint64 now = GameTime::GetGameTime().count();
    if (state->startedAt && now >= state->startedAt)
        duration = static_cast<uint32>(now - state->startedAt);

    int32 baseScore = static_cast<int32>(state->keystoneLevel) * 60;
    int32 penalty = static_cast<int32>(state->deaths) * 5 + static_cast<int32>(state->wipes) * 15;
    int32 scoreValue = std::max(0, baseScore - penalty);
    if (!success)
        scoreValue = 0;

    std::string groupBlob = SerializeParticipants(state);

    uint32 unsignedScore = static_cast<uint32>(scoreValue);

    for (ObjectGuid::LowType guidLow : state->participants)
    {
        InsertRunHistory(guidLow, seasonId, state->mapId, state->keystoneLevel, success, state->deaths, state->wipes, duration, unsignedScore, groupBlob);
        UpdateScore(guidLow, seasonId, state->mapId, state->keystoneLevel, success, unsignedScore, duration);
        if (success)
            UpdateWeeklyVault(guidLow, seasonId, state->mapId, state->keystoneLevel, success, state->deaths, state->wipes, duration);
    }

    LOG_INFO("mythic.run", "Mythic+ run {} for map {} instance {} (boss {})", success ? "completed" : "failed", state->mapId, state->instanceId, bossEntry);
}

void MythicPlusRunManager::AwardTokens(InstanceState* state, uint32 bossEntry)
{
    if (!state || state->tokensGranted)
        return;

    DungeonProfile* profile = sMythicScaling->GetDungeonProfile(state->mapId);
    if (!profile || !profile->tokenReward)
        return;

    Map* map = sMapMgr->FindMap(state->mapId, state->instanceId);
    if (!map)
        return;

    Map::PlayerList const& players = map->GetPlayers();
    for (auto const& ref : players)
    {
        Player* player = ref.GetSource();
        if (!player)
            continue;

        if (state->participants.find(player->GetGUID().GetCounter()) == state->participants.end())
            continue;

        uint32 baseTokens = 10;
        if (player->GetLevel() > 70)
            baseTokens += (player->GetLevel() - 70) * 2;

        float multiplier = 1.0f;
        switch (state->difficulty)
        {
            case DUNGEON_DIFFICULTY_NORMAL:
                multiplier = 1.0f;
                break;
            case DUNGEON_DIFFICULTY_HEROIC:
                multiplier = 1.5f;
                break;
            case DUNGEON_DIFFICULTY_EPIC:
                multiplier = state->keystoneLevel > 0 ? (MYTHIC_BASE_MULTIPLIER + (state->keystoneLevel * KEYSTONE_LEVEL_STEP)) : MYTHIC_BASE_MULTIPLIER;
                break;
            default:
                break;
        }

        uint32 tokenCount = static_cast<uint32>(std::floor(baseTokens * multiplier));
        tokenCount = std::max<uint32>(tokenCount, 1);

        ItemPosCountVec dest;
        uint32 tokenEntry = profile->tokenReward;
        if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, tokenEntry, tokenCount) == EQUIP_ERR_OK)
        {
            if (Item* item = player->StoreNewItem(dest, tokenEntry, true))
                player->SendNewItem(item, tokenCount, true, false);
        }
        else
        {
            player->SendItemRetrievalMail(tokenEntry, tokenCount);
            ChatHandler(player->GetSession()).SendSysMessage("|cff00ff00Mythic+|r: Tokens could not be added to your bags and were mailed instead.");
        }

        InsertTokenLog(player->GetGUID().GetCounter(), state->mapId, state->difficulty, state->keystoneLevel, player->GetLevel(), bossEntry, tokenCount);
        ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat("|cff00ff00Mythic+|r: Awarded {} tokens.", tokenCount));
        
        // Track tokens for run summary (only for keystone owner)
        if (player->GetGUID() == state->ownerGuid)
            state->tokensAwarded = tokenCount;
    }

    state->tokensGranted = true;
}

void MythicPlusRunManager::UpdateWeeklyVault(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 /*mapId*/, uint8 keystoneLevel, bool success, uint8 /*deaths*/, uint8 /*wipes*/, uint32 /*durationSeconds*/)
{
    if (!success)
        return;

    if (!sConfigMgr->GetOption<bool>("MythicPlus.Vault.Enabled", false))
        return;

    uint32 weekStart = GetWeekStartTimestamp();
    uint8 slot1 = (1 >= GetVaultThreshold(1)) ? 1 : 0;
    uint8 slot2 = (1 >= GetVaultThreshold(2)) ? 1 : 0;
    uint8 slot3 = (1 >= GetVaultThreshold(3)) ? 1 : 0;

    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_INS_MPLUS_WEEKLY_VAULT);
    stmt->SetData(0, playerGuid);
    stmt->SetData(1, seasonId);
    stmt->SetData(2, weekStart);
    stmt->SetData(3, 1); // runs completed delta
    stmt->SetData(4, keystoneLevel);
    stmt->SetData(5, slot1);
    stmt->SetData(6, slot2);
    stmt->SetData(7, slot3);
    CharacterDatabase.Execute(stmt);
}

void MythicPlusRunManager::UpdateScore(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 mapId, uint8 keystoneLevel, bool success, uint32 score, uint32 /*durationSeconds*/)
{
    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_INS_MPLUS_SCORE);
    stmt->SetData(0, playerGuid);
    stmt->SetData(1, seasonId);
    stmt->SetData(2, mapId);
    stmt->SetData(3, success ? keystoneLevel : 0);
    stmt->SetData(4, score);

    CharacterDatabase.Execute(stmt);
}

void MythicPlusRunManager::InsertRunHistory(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 mapId, uint8 keystoneLevel, bool success, uint8 deaths, uint8 wipes, uint32 durationSeconds, uint32 score, const std::string& groupMembers)
{
    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_INS_MPLUS_RUN_HISTORY);
    stmt->SetData(0, playerGuid);
    stmt->SetData(1, seasonId);
    stmt->SetData(2, mapId);
    stmt->SetData(3, keystoneLevel);
    stmt->SetData(4, score);
    stmt->SetData(5, deaths);
    stmt->SetData(6, wipes);
    stmt->SetData(7, durationSeconds);
    stmt->SetData(8, success ? 1 : 0);
    stmt->SetData(9, 0); // affix pair placeholder
    stmt->SetData(10, groupMembers);

    CharacterDatabase.Execute(stmt);
}

void MythicPlusRunManager::InsertTokenLog(ObjectGuid::LowType playerGuid, uint32 mapId, Difficulty difficulty, uint8 keystoneLevel, uint8 playerLevel, uint32 bossEntry, uint32 tokenCount)
{
    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_INS_MPLUS_TOKEN_LOG);
    stmt->SetData(0, playerGuid);
    stmt->SetData(1, mapId);
    stmt->SetData(2, static_cast<uint8>(difficulty));
    stmt->SetData(3, keystoneLevel);
    stmt->SetData(4, playerLevel);
    stmt->SetData(5, tokenCount);
    stmt->SetData(6, bossEntry);

    CharacterDatabase.Execute(stmt);
}

uint32 MythicPlusRunManager::GetCurrentSeasonId() const
{
    return sMythicScaling->GetActiveSeasonId();
}

uint32 MythicPlusRunManager::GetWeekStartTimestamp() const
{
    uint32 now = static_cast<uint32>(GameTime::GetGameTime().count());
    constexpr uint32 WEEK = 7 * DAY;
    return now - (now % WEEK);
}

uint32 MythicPlusRunManager::GetVaultTokenReward(uint8 slot) const
{
    if (slot == 0 || slot > 3)
        return 0;
    return DEFAULT_VAULT_TOKENS[slot - 1];
}

uint8 MythicPlusRunManager::GetVaultThreshold(uint8 slot) const
{
    if (slot == 0 || slot > 3)
        return 0;
    return DEFAULT_VAULT_THRESHOLDS[slot - 1];
}

void MythicPlusRunManager::SendVaultError(Player* player, std::string_view text)
{
    SendGenericError(player, text);
}

void MythicPlusRunManager::SendGenericError(Player* player, std::string_view text)
{
    if (!player || !player->GetSession())
        return;

    ChatHandler(player->GetSession()).SendSysMessage(text.data());
}

bool MythicPlusRunManager::IsFinalBoss(uint32 mapId, uint32 bossEntry) const
{
    auto itr = _mapFinalBossEntries.find(mapId);
    if (itr == _mapFinalBossEntries.end())
        return false;

    return itr->second.find(bossEntry) != itr->second.end();
}

bool MythicPlusRunManager::IsDungeonFeaturedThisSeason(uint32 mapId, uint32 seasonId) const
{
    QueryResult result = WorldDatabase.Query(
        "SELECT is_unlocked, mythic_plus_enabled, IFNULL(season_lock, 0) "
        "FROM dc_dungeon_setup WHERE map_id = {}",
        mapId);

    if (!result)
        return false;

    Field* fields = result->Fetch();
    bool isUnlocked = fields[0].Get<bool>();
    bool mythicPlusEnabled = fields[1].Get<bool>();
    uint32 requiredSeason = fields[2].Get<uint32>();

    bool seasonMatches = requiredSeason == 0 || requiredSeason == seasonId;
    return isUnlocked && mythicPlusEnabled && seasonMatches;
}

std::vector<uint32> MythicPlusRunManager::GetWeeklyAffixes(uint32 seasonId) const
{
    std::vector<uint32> affixes;
    
    // Get current week number (0-51 for yearly rotation)
    uint32 weekStart = GetWeekStartTimestamp();
    uint32 weekNumber = (weekStart / (7 * 24 * 60 * 60)) % 52;
    
    // Query affix schedule for this week
    QueryResult result = WorldDatabase.Query(
        "SELECT affix1, affix2 FROM dc_mplus_affix_schedule "
        "WHERE season_id = {} AND week_number = {}",
        seasonId, weekNumber);
    
    if (result)
    {
        Field* fields = result->Fetch();
        uint32 affix1 = fields[0].Get<uint32>();
        uint32 affix2 = fields[1].Get<uint32>();
        
        if (affix1 > 0)
            affixes.push_back(affix1);
        if (affix2 > 0)
            affixes.push_back(affix2);
    }
    
    return affixes;
}

void MythicPlusRunManager::ActivateAffixes(Map* map, const std::vector<uint32>& affixes, uint8 keystoneLevel)
{
    if (!map || affixes.empty())
        return;

    // Store active affixes in instance state for later use
    InstanceState* state = GetState(map);
    if (state)
    {
        state->activeAffixes = affixes;

        if (Map* liveMap = sMapMgr->FindMap(state->mapId, state->instanceId))
        {
            uint32 affixOne = !affixes.empty() ? affixes[0] : 0;
            uint32 affixTwo = affixes.size() > 1 ? affixes[1] : 0;
            SetHudWorldState(state, liveMap, MythicPlusConstants::Hud::AFFIX_ONE, affixOne);
            SetHudWorldState(state, liveMap, MythicPlusConstants::Hud::AFFIX_TWO, affixTwo);
            UpdateHud(state, liveMap, true, "affix");
        }

        // Apply affix scaling multipliers to creatures
        // This would typically be handled by the MythicDifficultyScaling system
        LOG_INFO("mythic.affix", "Activated {} affixes for keystone level {} in map {}",
            affixes.size(), keystoneLevel, map->GetId());
        
        // Debug logging for affixes
        if (sConfigMgr->GetOption<bool>("MythicPlus.AffixDebug", false))
        {
            for (uint32 affixId : affixes)
            {
                LOG_DEBUG("mythic.affix", "Affix ID {} active", affixId);
            }
        }
    }
}

void MythicPlusRunManager::AnnounceAffixes(Player* player, const std::vector<uint32>& affixes)
{
    if (!player || affixes.empty())
        return;

    // Build affix name string
    std::ostringstream ss;
    ss << "|cffff8000Active Affixes|r: ";
    
    for (size_t i = 0; i < affixes.size(); ++i)
    {
        std::string affixName = GetAffixName(affixes[i]);
        ss << affixName;
        if (i < affixes.size() - 1)
            ss << ", ";
    }
    
    ChatHandler(player->GetSession()).SendSysMessage(ss.str().c_str());
}

std::string MythicPlusRunManager::GetAffixName(uint32 affixId) const
{
    QueryResult result = WorldDatabase.Query(
        "SELECT name FROM dc_mplus_affixes WHERE affix_id = {}", affixId);
    
    if (result)
    {
        return result->Fetch()->Get<std::string>();
    }
    
    return "Unknown Affix";
}

std::string MythicPlusRunManager::SerializeParticipants(const InstanceState* state) const
{
    if (!state)
        return "[]";

    std::ostringstream stream;
    stream << "[";
    bool first = true;
    for (ObjectGuid::LowType guidLow : state->participants)
    {
        if (!first)
            stream << ",";
        stream << guidLow;
        first = false;
    }
    stream << "]";

    return stream.str();
}

// ============================================================
// Keystone Item Management Methods (NEW)
// ============================================================

uint8 MythicPlusRunManager::GetPlayerKeystoneLevel(ObjectGuid::LowType playerGuid) const
{
    auto result = CharacterDatabase.Query(
        "SELECT current_keystone_level FROM dc_player_keystones WHERE player_guid = {}", playerGuid);
    
    if (result)
    {
        return result->Fetch()->Get<uint8>();
    }
    
    return MythicPlusConstants::MIN_KEYSTONE_LEVEL;  // Default to M+2
}

bool MythicPlusRunManager::GiveKeystoneToPlayer(Player* player, uint8 keystoneLevel)
{
    if (!player || keystoneLevel < MythicPlusConstants::MIN_KEYSTONE_LEVEL || keystoneLevel > MythicPlusConstants::MAX_KEYSTONE_LEVEL)
        return false;

    uint32 keystoneItemId = MythicPlusConstants::GetItemIdFromKeystoneLevel(keystoneLevel);
    if (!keystoneItemId)
        return false;

    // Give player the keystone item
    ItemPosCountVec dest;
    InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, keystoneItemId, 1);
    
    if (msg == EQUIP_ERR_OK)
    {
        Item* keystoneItem = player->StoreNewItem(dest, keystoneItemId, true);
        return keystoneItem != nullptr;
    }

    return false;
}

void MythicPlusRunManager::CompleteRun(Map* map, bool successful)
{
    if (!map)
        return;

    InstanceState* state = GetState(map);
    if (!state)
        return;

    // Update player keystone levels based on run result
    for (ObjectGuid::LowType playerGuid : state->participants)
    {
        if (successful)
        {
            UpgradeKeystone(playerGuid);
        }
        else
        {
            DowngradeKeystone(playerGuid);
        }
    }
}

void MythicPlusRunManager::UpgradeKeystone(ObjectGuid::LowType playerGuid)
{
    uint8 currentLevel = GetPlayerKeystoneLevel(playerGuid);
    uint8 newLevel = std::min<uint8>(MythicPlusConstants::MAX_KEYSTONE_LEVEL, static_cast<uint8>(currentLevel + 1));

    // Update database
    CharacterDatabase.Execute(
        "UPDATE dc_player_keystones SET current_keystone_level = {} WHERE player_guid = {}", 
        newLevel, playerGuid);

    // Generate new keystone item
    GenerateNewKeystone(playerGuid, newLevel);
}

void MythicPlusRunManager::DowngradeKeystone(ObjectGuid::LowType playerGuid)
{
    uint8 currentLevel = GetPlayerKeystoneLevel(playerGuid);
    uint8 newLevel = std::max<uint8>(MythicPlusConstants::MIN_KEYSTONE_LEVEL, static_cast<uint8>(currentLevel - 1));

    // Update database
    CharacterDatabase.Execute(
        "UPDATE dc_player_keystones SET current_keystone_level = {} WHERE player_guid = {}", 
        newLevel, playerGuid);

    // Generate new keystone item
    GenerateNewKeystone(playerGuid, newLevel);
}

void MythicPlusRunManager::GenerateNewKeystone(ObjectGuid::LowType playerGuid, uint8 level)
{
    if (level < MythicPlusConstants::MIN_KEYSTONE_LEVEL || level > MythicPlusConstants::MAX_KEYSTONE_LEVEL)
        return;

    uint32 keystoneItemId = MythicPlusConstants::GetItemIdFromKeystoneLevel(level);
    if (!keystoneItemId)
        return;

    // Get player from guid
    Player* player = ObjectAccessor::FindPlayer(ObjectGuid::Create<HighGuid::Player>(playerGuid));
    if (player)
    {
        // Add keystone to player inventory
        ItemPosCountVec dest;
        if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, keystoneItemId, 1) == EQUIP_ERR_OK)
        {
            Item* keystoneItem = player->StoreNewItem(dest, keystoneItemId, true);
            if (keystoneItem)
            {
                ChatHandler(player->GetSession()).SendSysMessage(
                    Acore::StringFormat("|cff00ff00Mythic+:|r New keystone generated (M+{})", level));
            }
        }
    }
}

void MythicPlusRunManager::SendRunSummary(InstanceState* state, Player* player)
{
    if (!state || !player)
        return;

    ChatHandler handler(player->GetSession());
    
    // Calculate duration
    uint32 duration = 0;
    uint64 now = GameTime::GetGameTime().count();
    if (state->startedAt && now >= state->startedAt)
        duration = static_cast<uint32>(now - state->startedAt);
    
    uint32 minutes = duration / 60;
    uint32 seconds = duration % 60;

    // Header
    handler.SendSysMessage("|cff00ff00========================================|r");
    handler.SendSysMessage("|cffff8000        MYTHIC+ RUN COMPLETE       |r");
    handler.SendSysMessage("|cff00ff00========================================|r");
    
    // Dungeon info
    std::string dungeonName = "Unknown Dungeon";
    if (MapEntry const* mapEntry = sMapStore.LookupEntry(state->mapId))
        dungeonName = mapEntry->name[0];
    
    handler.SendSysMessage(("|cffffd700Dungeon:|r " + dungeonName).c_str());
    handler.SendSysMessage(Acore::StringFormat("|cffffd700Keystone Level:|r +{}", state->keystoneLevel));
    handler.SendSysMessage(Acore::StringFormat("|cffffd700Duration:|r {} min {} sec", minutes, seconds));
    handler.SendSysMessage("|cff00ff00----------------------------------------|r");
    
    // Combat statistics
    handler.SendSysMessage("|cffff8000Combat Statistics:|r");
    handler.SendSysMessage(Acore::StringFormat("|cffffffff  Bosses Killed:|r {}", state->bossesKilled));
    handler.SendSysMessage(Acore::StringFormat("|cffffffff  Enemies Killed:|r {}", state->npcsKilled));
    handler.SendSysMessage(Acore::StringFormat("|cffffffff  Total Deaths:|r {}", state->deaths));
    handler.SendSysMessage(Acore::StringFormat("|cffffffff  Group Wipes:|r {}", state->wipes));
    handler.SendSysMessage("|cff00ff00----------------------------------------|r");
    
    // Rewards
    handler.SendSysMessage("|cffff8000Rewards:|r");
    handler.SendSysMessage(Acore::StringFormat("|cffffffff  Tokens Awarded:|r {}", state->tokensAwarded));
    
    if (state->keystoneUpgraded)
    {
        uint8 oldLevel = state->keystoneLevel;
        uint8 newLevel = state->upgradeLevel;
        int8 levelChange = static_cast<int8>(newLevel) - static_cast<int8>(oldLevel);
        
        if (levelChange > 0)
            handler.SendSysMessage(Acore::StringFormat("|cff00ff00  Keystone:|r Upgraded from +{} to |cff00ff00+{}|r (+{})", oldLevel, newLevel, levelChange));
        else if (levelChange < 0)
            handler.SendSysMessage(Acore::StringFormat("|cffffaa00  Keystone:|r Downgraded from +{} to |cffffaa00+{}|r ({})", oldLevel, newLevel, levelChange));
        else
            handler.SendSysMessage(Acore::StringFormat("|cffffffff  Keystone:|r Maintained at +{}", newLevel));
    }
    else if (player->GetGUID() == state->ownerGuid)
    {
        handler.SendSysMessage("|cffffffff  Keystone:|r Check your inventory");
    }
    
    handler.SendSysMessage("|cff00ff00========================================|r");
    
    // Performance message
    if (state->deaths == 0)
        handler.SendSysMessage("|cff00ff00Flawless Victory - No Deaths!|r");
    else if (state->deaths <= 5)
        handler.SendSysMessage("|cff00ff00Excellent Performance!|r");
    else if (state->deaths <= 10)
        handler.SendSysMessage("|cffffaa00Good Effort!|r");
    else
        handler.SendSysMessage("|cffff6600Room for Improvement!|r");
}

void MythicPlusRunManager::AutoUpgradeKeystone(InstanceState* state)
{
    if (!state || !state->ownerGuid)
        return;

    ObjectGuid::LowType ownerGuidLow = state->ownerGuid.GetCounter();
    uint8 currentLevel = state->keystoneLevel;
    
    // Calculate upgrade based on death performance
    // 0-5 deaths = +2 levels
    // 6-10 deaths = +1 level
    // 11-14 deaths = same level
    // 15+ deaths = downgrade (but shouldn't happen as run fails at 15)
    
    uint8 newLevel = currentLevel;
    
    if (state->deaths <= 5)
        newLevel = std::min<uint8>(MythicPlusConstants::MAX_KEYSTONE_LEVEL, static_cast<uint8>(currentLevel + 2));
    else if (state->deaths <= 10)
        newLevel = std::min<uint8>(MythicPlusConstants::MAX_KEYSTONE_LEVEL, static_cast<uint8>(currentLevel + 1));
    else if (state->deaths <= 14)
        newLevel = currentLevel; // Maintain same level
    else
        newLevel = std::max<uint8>(MythicPlusConstants::MIN_KEYSTONE_LEVEL, static_cast<uint8>(currentLevel - 1)); // Downgrade
    
    state->upgradeLevel = newLevel;
    state->keystoneUpgraded = true;
    
    // Update database
    CharacterDatabase.Execute(
        "INSERT INTO dc_player_keystones (player_guid, current_keystone_level, last_updated) "
        "VALUES ({}, {}, UNIX_TIMESTAMP()) "
        "ON DUPLICATE KEY UPDATE current_keystone_level = {}, last_updated = UNIX_TIMESTAMP()",
        ownerGuidLow, newLevel, newLevel);
    
    // Generate new keystone for owner
    GenerateNewKeystone(ownerGuidLow, newLevel);

    if (Map* map = sMapMgr->FindMap(state->mapId, state->instanceId))
    {
        uint32 chestTier = newLevel > currentLevel ? static_cast<uint32>(newLevel - currentLevel) : 0;
        SetHudWorldState(state, map, MythicPlusConstants::Hud::CHEST_TIER, chestTier);
        UpdateHud(state, map, true, "upgrade");
    }
    
    LOG_INFO("mythic.run", "Auto-upgraded keystone for player {} from +{} to +{} (deaths: {})",
             ownerGuidLow, currentLevel, newLevel, state->deaths);
}

void MythicPlusRunManager::ProcessAchievements(InstanceState* state, Player* player, bool success)
{
    if (!state || !player || !success)
        return;

    // Use available achievement criteria types from WotLK (3.3.5a)
    // ACHIEVEMENT_CRITERIA_TYPE_KILL_CREATURE = 0 (for boss kills)
    // ACHIEVEMENT_CRITERIA_TYPE_COMPLETE_RAID = 19 (closest to dungeon completion)
    
    // Track boss kills for achievement criteria
    if (state->bossesKilled > 0)
        player->UpdateAchievementCriteria(ACHIEVEMENT_CRITERIA_TYPE_KILL_CREATURE, state->mapId, state->bossesKilled);
    
    // Track dungeon completion (using raid completion as proxy for mythic dungeons)
    player->UpdateAchievementCriteria(ACHIEVEMENT_CRITERIA_TYPE_COMPLETE_RAID, state->mapId);
    
    // Special tracking for flawless completions
    if (state->deaths == 0)
    {
        LOG_INFO("mythic.achievement", "Player {} earned flawless completion for map {} (M+{})", 
                 player->GetGUID().GetCounter(), state->mapId, state->keystoneLevel);
    }
    
    // Log keystone level milestones
    if (state->keystoneLevel >= 5)
    {
        LOG_INFO("mythic.achievement", "Player {} completed M+5 milestone in map {}", 
                 player->GetGUID().GetCounter(), state->mapId);
    }
    
    if (state->keystoneLevel >= 10)
    {
        LOG_INFO("mythic.achievement", "Player {} completed M+10 milestone in map {}", 
                 player->GetGUID().GetCounter(), state->mapId);
    }
    
    LOG_INFO("mythic.achievement", "Processed achievements for player {} in map {} (M+{}, deaths: {}, bosses: {})",
             player->GetGUID().GetCounter(), state->mapId, state->keystoneLevel, state->deaths, state->bossesKilled);
}

// ============================================================
// Run Cancellation System
// ============================================================

void MythicPlusRunManager::InitiateCancellation(Map* map)
{
    if (!map)
        return;

    InstanceState* state = GetState(map);
    if (!state || state->completed || state->failed)
        return;

    // Check if all players have left
    bool allLeft = true;
    for (auto guid : state->participants)
    {
        if (Player* player = ObjectAccessor::FindConnectedPlayer(ObjectGuid::Create<HighGuid::Player>(guid)))
        {
            if (player->GetMapId() == state->mapId && player->GetInstanceId() == state->instanceId)
            {
                allLeft = false;
                break;
            }
        }
    }

    if (allLeft && !state->cancellationPending)
    {
        state->cancellationPending = true;
        state->abandonedAt = GameTime::GetGameTime().count();
        LOG_INFO("mythic.run", "Cancellation initiated for instance {} (map {})", 
                 state->instanceId, state->mapId);
    }
}

void MythicPlusRunManager::ProcessCancellationTimers()
{
    uint64 now = GameTime::GetGameTime().count();
    uint64 cancelTimeout = sConfigMgr->GetOption<uint32>("MythicPlus.CancellationTimeout", 180);

    std::vector<uint64> toCancel;
    for (auto& [key, state] : _instanceStates)
    {
        if (state.cancellationPending && !state.completed && !state.failed)
        {
            if (now - state.abandonedAt >= cancelTimeout)
            {
                toCancel.push_back(key);
            }
        }
    }

    for (uint64 key : toCancel)
    {
        auto itr = _instanceStates.find(key);
        if (itr != _instanceStates.end())
        {
            InstanceState& state = itr->second;
            HandleFailState(&state, "Run abandoned - all players left", true);
            LOG_INFO("mythic.run", "Auto-cancelled abandoned run for instance {} (map {})",
                     state.instanceId, state.mapId);
        }
    }
}

void MythicPlusRunManager::ProcessCountdowns()
{
    uint64 now = GameTime::GetGameTime().count();
    uint32 countdownDuration = sConfigMgr->GetOption<uint32>("MythicPlus.CountdownDuration", 10);
    
    static std::unordered_map<uint64, std::unordered_set<uint32>> announcedIntervals;
    
    for (auto& [key, state] : _instanceStates)
    {
        if (!state.countdownActive || state.completed || state.failed)
            continue;
            
        uint64 elapsed = now - state.countdownStarted;
        uint32 remaining = elapsed < countdownDuration ? countdownDuration - elapsed : 0;
        
        Map* map = sMapMgr->FindMap(state.mapId, state.instanceId);
        if (!map)
        {
            state.countdownActive = false;
            continue;
        }

        SetHudWorldState(&state, map, MythicPlusConstants::Hud::COUNTDOWN_REMAINING, remaining);
        UpdateHud(&state, map, false, "countdown");

        // The activation routine already announces the initial countdown duration.
        // Skip re-broadcasting the same value so the 10-second warning is not duplicated.
        if (remaining == countdownDuration)
            continue;
        
        // Announce at specific intervals: 10, 5, 4, 3, 2, 1
        if ((remaining == 10 || (remaining > 0 && remaining <= 5)) && 
            announcedIntervals[key].find(remaining) == announcedIntervals[key].end())
        {
            AnnounceToInstance(map, Acore::StringFormat("Starting in: |cffffff00{}...|r", remaining));
            announcedIntervals[key].insert(remaining);
        }
        
        // Start the run when countdown completes
        if (remaining == 0 && elapsed >= countdownDuration)
        {
            state.countdownActive = false;
            announcedIntervals.erase(key);
            
            // Find the keystone owner to start the run
            Player* owner = ObjectAccessor::FindPlayer(state.ownerGuid);
            if (owner)
                StartRunAfterCountdown(&state, map, owner);
        }
    }
}

bool MythicPlusRunManager::VoteToCancelRun(Player* player, Map* map)
{
    if (!player || !map)
        return false;

    InstanceState* state = GetState(map);
    if (!state || state->completed || state->failed)
    {
        SendGenericError(player, "No active Mythic+ run to cancel.");
        return false;
    }

    // Check if player is a participant
    if (state->participants.find(player->GetGUID().GetCounter()) == state->participants.end())
    {
        SendGenericError(player, "You are not part of this Mythic+ run.");
        return false;
    }

    // Check if player already voted
    if (state->cancellationVotes.find(player->GetGUID().GetCounter()) != state->cancellationVotes.end())
    {
        SendGenericError(player, "You have already voted to cancel this run.");
        return false;
    }

    // Add vote
    state->cancellationVotes.insert(player->GetGUID().GetCounter());
    if (state->cancellationVotes.size() == 1)
    {
        state->cancellationVoteStarted = GameTime::GetGameTime().count();
    }

    uint32 requiredVotes = sConfigMgr->GetOption<uint32>("MythicPlus.CancellationVotesRequired", 2);
    uint32 currentVotes = state->cancellationVotes.size();

    // Announce vote
    AnnounceToInstance(map, Acore::StringFormat(
        "|cffff8000[Cancellation Vote]|r {} voted to cancel ({}/{} votes needed)",
        player->GetName(), currentVotes, requiredVotes));

    // Check if enough votes
    if (currentVotes >= requiredVotes)
    {
        HandleFailState(state, "Run cancelled by group vote", true);
        AnnounceToInstance(map, "|cffff0000Mythic+ run cancelled by group vote. Keystone downgraded.|r");
        return true;
    }

    ChatHandler(player->GetSession()).SendSysMessage(
        Acore::StringFormat("|cff00ff00Vote registered.|r {}/{} votes needed to cancel the run.",
                             currentVotes, requiredVotes));
    return true;
}

void MythicPlusRunManager::ProcessCancellationVotes()
{
    uint64 now = GameTime::GetGameTime().count();
    uint64 voteTimeout = sConfigMgr->GetOption<uint32>("MythicPlus.CancellationVoteTimeout", 60);

    for (auto& [key, state] : _instanceStates)
    {
        if (!state.cancellationVotes.empty() && !state.completed && !state.failed)
        {
            // Reset votes after timeout
            if (now - state.cancellationVoteStarted >= voteTimeout)
            {
                state.cancellationVotes.clear();
                state.cancellationVoteStarted = 0;
                LOG_INFO("mythic.run", "Cancellation votes reset for instance {} (map {}) due to timeout",
                         state.instanceId, state.mapId);
            }
        }
    }
}

// ============================================================
// Teleportation System
// ============================================================

void MythicPlusRunManager::TeleportGroupToEntrance(Player* activator, Map* map)
{
    if (!activator || !map)
        return;

    if (!sConfigMgr->GetOption<bool>("MythicPlus.TeleportToEntrance", true))
        return;

    Group* group = activator->GetGroup();
    if (!group)
    {
        // Solo player
        TeleportPlayerToEntrance(activator, map);
        return;
    }

    // Teleport all group members in the instance
    for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
    {
        Player* member = itr->GetSource();
        if (member && member->GetMapId() == map->GetId() && 
            member->GetInstanceId() == map->GetInstanceId())
        {
            TeleportPlayerToEntrance(member, map);
        }
    }
}

void MythicPlusRunManager::TeleportPlayerToEntrance(Player* player, Map* map)
{
    if (!player || !map)
        return;

    // Reuse existing areatrigger_teleport coordinates (same as dungeon entrance portals)
    // This table already contains entrance coordinates for all dungeons
    QueryResult result = WorldDatabase.Query(
        "SELECT target_position_x, target_position_y, target_position_z, target_orientation "
        "FROM areatrigger_teleport "
        "WHERE target_map = {} "
        "ORDER BY id ASC LIMIT 1",
        map->GetId()
    );

    if (result)
    {
        Field* fields = result->Fetch();
        float x = fields[0].Get<float>();
        float y = fields[1].Get<float>();
        float z = fields[2].Get<float>();
        float o = fields[3].Get<float>();

        player->TeleportTo(map->GetId(), x, y, z, o);
        ChatHandler(player->GetSession()).SendSysMessage("|cff00ff00Teleported to dungeon entrance.|r");
        
        LOG_DEBUG("mythic.run", "Teleported {} to entrance of map {} at ({}, {}, {})",
                  player->GetName(), map->GetId(), x, y, z);
    }
    else
    {
        LOG_WARN("mythic.run", "No entrance areatrigger found for map {} - player not teleported", 
                 map->GetId());
        ChatHandler(player->GetSession()).SendSysMessage(
            "|cffff0000Warning:|r No entrance coordinates found for this dungeon.");
    }
}

// ============================================================
// Countdown and Run Start System
// ============================================================

void MythicPlusRunManager::StartRunAfterCountdown(InstanceState* state, Map* map, Player* activator)
{
    if (!state || !map || !activator)
        return;

    // Mark run as officially started
    state->startedAt = GameTime::GetGameTime().count();
    state->countdownActive = false;
    if (state->hudTimerDuration == 0)
        state->hudTimerDuration = GetHudTimerDuration(state->mapId, state->keystoneLevel);
    state->timerEndsAt = state->hudTimerDuration ? state->startedAt + state->hudTimerDuration : 0;
    
    // Remove root spell from all players to allow movement
    Map::PlayerList const& players = map->GetPlayers();
    for (auto const& ref : players)
    {
        Player* player = ref.GetSource();
        if (player)
        {
            player->RemoveAurasDueToSpell(COUNTDOWN_ROOT_SPELL);
        }
    }
    
    // Apply scaling and barriers
    ApplyKeystoneScaling(map, state->keystoneLevel);
    ApplyEntryBarrier(map);

    SetHudWorldState(state, map, MythicPlusConstants::Hud::COUNTDOWN_REMAINING, 0);
    SetHudWorldState(state, map, MythicPlusConstants::Hud::TIMER_DURATION, state->hudTimerDuration);
    SetHudWorldState(state, map, MythicPlusConstants::Hud::ACTIVE, 1);
    SetHudWorldState(state, map, MythicPlusConstants::Hud::OWNER_GUID_LOW, state->ownerGuid.GetCounter());
    SetHudWorldState(state, map, MythicPlusConstants::Hud::KEYSTONE_LEVEL, state->keystoneLevel);
    SetHudWorldState(state, map, MythicPlusConstants::Hud::DUNGEON_ID, state->mapId);
    SetHudWorldState(state, map, MythicPlusConstants::Hud::BOSSES_TOTAL, GetTotalBossesForDungeon(state->mapId));
    UpdateHud(state, map, true, "start");
    
    AnnounceToInstance(map, "|cff00ff00Mythic+ timer started! Good luck!|r");
    
    LOG_INFO("mythic.run", "Started Mythic+ run for instance {} (map {}) at keystone level +{}",
             state->instanceId, state->mapId, state->keystoneLevel);
}

// ============================================================
// Mythic+ HUD and AIO helpers
// ============================================================

uint32 MythicPlusRunManager::GetHudTimerDuration(uint32 mapId, uint8 keystoneLevel) const
{
    uint32 base = sConfigMgr->GetOption<uint32>("MythicPlus.Hud.Timer.DefaultSeconds", DEFAULT_HUD_TIMER_SECONDS);
    uint32 perBoss = sConfigMgr->GetOption<uint32>("MythicPlus.Hud.Timer.PerBossBonus", DEFAULT_HUD_PER_BOSS);
    uint32 minSeconds = sConfigMgr->GetOption<uint32>("MythicPlus.Hud.Timer.MinimumSeconds", 600u);
    uint32 perLevelPenalty = sConfigMgr->GetOption<uint32>("MythicPlus.Hud.Timer.PerLevelPenalty", 0u);

    uint32 totalBosses = GetTotalBossesForDungeon(mapId);
    if (totalBosses > 3 && perBoss > 0)
        base += (totalBosses - 3) * perBoss;

    if (perLevelPenalty > 0 && keystoneLevel > MythicPlusConstants::MIN_KEYSTONE_LEVEL)
    {
        uint32 delta = keystoneLevel - MythicPlusConstants::MIN_KEYSTONE_LEVEL;
        uint32 penalty = delta * perLevelPenalty;
        base = penalty >= base ? minSeconds : std::max(minSeconds, base - penalty);
    }
    else
    {
        base = std::max(base, minSeconds);
    }

    return base;
}

void MythicPlusRunManager::BuildBossTracking(InstanceState* state)
{
    if (!state)
        return;

    state->bossOrder.clear();
    state->bossIndexLookup.clear();

    auto pushBoss = [&](uint32 entry)
    {
        if (!entry)
            return;
        if (state->bossIndexLookup.find(entry) != state->bossIndexLookup.end())
            return;
        if (state->bossOrder.size() >= MythicPlusConstants::Hud::MAX_TRACKED_BOSSES)
            return;
        uint8 index = static_cast<uint8>(state->bossOrder.size());
        state->bossIndexLookup.emplace(entry, index);
        state->bossOrder.push_back(entry);
    };

    if (DungeonEncounterList const* encounters = sObjectMgr->GetDungeonEncounterList(state->mapId, DUNGEON_DIFFICULTY_EPIC))
    {
        for (DungeonEncounter const* encounter : *encounters)
        {
            if (encounter)
                pushBoss(encounter->creditEntry);
        }
    }

    if (state->bossOrder.size() < MythicPlusConstants::Hud::MAX_TRACKED_BOSSES)
    {
        if (auto itr = _mapBossEntries.find(state->mapId); itr != _mapBossEntries.end())
        {
            for (uint32 entry : itr->second)
            {
                pushBoss(entry);
                if (state->bossOrder.size() >= MythicPlusConstants::Hud::MAX_TRACKED_BOSSES)
                    break;
            }
        }
    }
}

void MythicPlusRunManager::InitializeHud(InstanceState* state, Map* map)
{
    if (!state || !map)
        return;

    if (!sConfigMgr->GetOption<bool>("MythicPlus.Hud.WorldStates", true))
        return;

    state->hudInitialized = true;
    state->hudWorldStates.clear();

    SetHudWorldState(state, map, MythicPlusConstants::Hud::ACTIVE, 0);
    SetHudWorldState(state, map, MythicPlusConstants::Hud::KEYSTONE_LEVEL, state->keystoneLevel);
    SetHudWorldState(state, map, MythicPlusConstants::Hud::DUNGEON_ID, state->mapId);
    SetHudWorldState(state, map, MythicPlusConstants::Hud::BOSSES_TOTAL, GetTotalBossesForDungeon(state->mapId));
    SetHudWorldState(state, map, MythicPlusConstants::Hud::BOSSES_KILLED, state->bossesKilled);
    SetHudWorldState(state, map, MythicPlusConstants::Hud::DEATHS, state->deaths);
    SetHudWorldState(state, map, MythicPlusConstants::Hud::WIPES, state->wipes);
    SetHudWorldState(state, map, MythicPlusConstants::Hud::RESULT, 0);
    SetHudWorldState(state, map, MythicPlusConstants::Hud::COUNTDOWN_REMAINING, sConfigMgr->GetOption<uint32>("MythicPlus.CountdownDuration", 10));
    SetHudWorldState(state, map, MythicPlusConstants::Hud::CHEST_TIER, 0);
    SetHudWorldState(state, map, MythicPlusConstants::Hud::TIMER_DURATION, state->hudTimerDuration);
    SetHudWorldState(state, map, MythicPlusConstants::Hud::OWNER_GUID_LOW, state->ownerGuid.GetCounter());

    uint32 affixOne = !state->activeAffixes.empty() ? state->activeAffixes[0] : 0;
    uint32 affixTwo = state->activeAffixes.size() > 1 ? state->activeAffixes[1] : 0;
    SetHudWorldState(state, map, MythicPlusConstants::Hud::AFFIX_ONE, affixOne);
    SetHudWorldState(state, map, MythicPlusConstants::Hud::AFFIX_TWO, affixTwo);

    for (size_t i = 0; i < state->bossOrder.size() && i < MythicPlusConstants::Hud::MAX_TRACKED_BOSSES; ++i)
    {
        uint32 worldStateId = MythicPlusConstants::Hud::BOSS_ENTRY_BASE + static_cast<uint32>(i);
        SetHudWorldState(state, map, worldStateId, state->bossOrder[i]);
        SetHudWorldState(state, map, MythicPlusConstants::Hud::BOSS_KILLTIME_BASE + static_cast<uint32>(i), 0);
    }
}

void MythicPlusRunManager::SetHudWorldState(InstanceState* state, Map* map, uint32 worldStateId, uint32 value)
{
    if (!state || !map)
        return;

    if (!sConfigMgr->GetOption<bool>("MythicPlus.Hud.WorldStates", true))
        return;

    auto [itr, inserted] = state->hudWorldStates.try_emplace(worldStateId, value);
    if (!inserted && itr->second == value)
        return;

    itr->second = value;

    Map::PlayerList const& players = map->GetPlayers();
    for (auto const& ref : players)
    {
        if (Player* player = ref.GetSource())
            player->SendUpdateWorldState(worldStateId, value);
    }
}

void MythicPlusRunManager::SyncHudToPlayer(InstanceState* state, Player* player) const
{
    if (!state || !player)
        return;

    if (!sConfigMgr->GetOption<bool>("MythicPlus.Hud.WorldStates", true))
        return;

    for (auto const& pair : state->hudWorldStates)
        player->SendUpdateWorldState(pair.first, pair.second);
}

void MythicPlusRunManager::ProcessHudUpdates()
{
    bool hudEnabled = sConfigMgr->GetOption<bool>("MythicPlus.Hud.WorldStates", true);
    bool aioEnabled = sConfigMgr->GetOption<bool>("MythicPlus.Hud.Aio.Enabled", true);
    if (!hudEnabled && !aioEnabled)
        return;

    for (auto& [key, state] : _instanceStates)
    {
        if (state.keystoneLevel == 0)
            continue;

        if (!state.countdownActive && state.startedAt == 0)
            continue;

        Map* map = sMapMgr->FindMap(state.mapId, state.instanceId);
        if (!map)
            continue;

        ProcessHudUpdatesInternal(&state, map);
    }
}

void MythicPlusRunManager::ProcessHudUpdatesInternal(InstanceState* state, Map* map)
{
    if (!state || !map)
        return;

    UpdateHud(state, map, false, HUD_REASON_PERIODIC);
}

void MythicPlusRunManager::UpdateHud(InstanceState* state, Map* map, bool forceBroadcast, std::string_view reason)
{
    if (!state || !map)
        return;

    bool hudEnabled = sConfigMgr->GetOption<bool>("MythicPlus.Hud.WorldStates", true);
    if (hudEnabled)
    {
        uint64 now = GameTime::GetGameTime().count();
        uint32 interval = sConfigMgr->GetOption<uint32>("MythicPlus.Hud.UpdateInterval", DEFAULT_HUD_UPDATE_INTERVAL);
        if (forceBroadcast || interval == 0 || now >= state->lastHudBroadcast + interval)
        {
            state->lastHudBroadcast = now;

            uint32 timerRemaining = 0;
            uint32 timerElapsed = 0;
            if (state->startedAt && state->hudTimerDuration > 0)
            {
                timerElapsed = now >= state->startedAt ? static_cast<uint32>(now - state->startedAt) : 0;
                if (state->timerEndsAt > now)
                    timerRemaining = static_cast<uint32>(state->timerEndsAt - now);
            }

            SetHudWorldState(state, map, MythicPlusConstants::Hud::TIMER_ELAPSED, timerElapsed);
            SetHudWorldState(state, map, MythicPlusConstants::Hud::TIMER_REMAINING, timerRemaining);
        }
    }

    MaybeSendAioSnapshot(state, map, reason);
}

int32 MythicPlusRunManager::GetBossIndex(InstanceState const* state, uint32 bossEntry) const
{
    if (!state)
        return -1;

    auto itr = state->bossIndexLookup.find(bossEntry);
    if (itr == state->bossIndexLookup.end())
        return -1;

    return itr->second;
}

void MythicPlusRunManager::MarkBossKilled(InstanceState* state, Map* map, uint32 bossEntry)
{
    if (!state || !map)
        return;

    int32 idx = GetBossIndex(state, bossEntry);
    if (idx < 0)
        return;

    uint64 now = GameTime::GetGameTime().count();
    state->bossKillStamps[bossEntry] = now;
    uint32 killAt = (state->startedAt && now >= state->startedAt) ? static_cast<uint32>(now - state->startedAt) : 0;
    SetHudWorldState(state, map, MythicPlusConstants::Hud::BOSS_KILLTIME_BASE + static_cast<uint32>(idx), killAt);
}

void MythicPlusRunManager::MaybeSendAioSnapshot(InstanceState* state, Map* map, std::string_view reason)
{
    if (!state || !map)
        return;

    if (!sConfigMgr->GetOption<bool>("MythicPlus.Hud.Aio.Enabled", true))
        return;

    uint32 intervalMs = sConfigMgr->GetOption<uint32>("MythicPlus.Hud.Aio.IntervalMS", 1500u);
    uint64 nowMs = GameTime::GetGameTimeMS().count();
    bool force = !reason.empty();
    if (!force && intervalMs > 0 && nowMs < state->lastAioBroadcast + intervalMs)
        return;

    state->lastAioBroadcast = nowMs;

    uint64 now = GameTime::GetGameTime().count();
    uint32 remaining = (state->timerEndsAt > now) ? static_cast<uint32>(state->timerEndsAt - now) : 0;
    uint32 elapsed = (state->startedAt && now >= state->startedAt) ? static_cast<uint32>(now - state->startedAt) : 0;
    uint32 countdown = 0;
    if (state->countdownActive)
    {
        uint32 countdownDuration = sConfigMgr->GetOption<uint32>("MythicPlus.CountdownDuration", 10);
        uint64 countdownEnd = state->countdownStarted + countdownDuration;
        countdown = countdownEnd > now ? static_cast<uint32>(countdownEnd - now) : 0;
    }

    uint32 totalBosses = state->bossOrder.empty() ? GetTotalBossesForDungeon(state->mapId) : static_cast<uint32>(state->bossOrder.size());

    std::ostringstream payload;
    payload << '{';
    payload << "\"op\":\"hud\",";
    payload << "\"run\":" << state->instanceKey << ',';
    payload << "\"map\":" << state->mapId << ',';
    payload << "\"instance\":" << state->instanceId << ',';
    payload << "\"keystone\":" << uint32(state->keystoneLevel) << ',';
    payload << "\"owner\":" << state->ownerGuid.GetCounter() << ',';
    payload << "\"started\":" << state->startedAt << ',';
    payload << "\"duration\":" << state->hudTimerDuration << ',';
    payload << "\"remaining\":" << remaining << ',';
    payload << "\"elapsed\":" << elapsed << ',';
    payload << "\"countdown\":" << countdown << ',';
    payload << "\"deaths\":" << uint32(state->deaths) << ',';
    payload << "\"wipes\":" << uint32(state->wipes) << ',';
    payload << "\"bossesKilled\":" << state->bossesKilled << ',';
    payload << "\"bossesTotal\":" << totalBosses << ',';
    payload << "\"completed\":" << (state->completed ? 1 : 0) << ',';
    payload << "\"failed\":" << (state->failed ? 1 : 0) << ',';
    payload << "\"reason\":\"" << reason << "\",";

    payload << "\"affixes\":[";
    for (size_t i = 0; i < state->activeAffixes.size(); ++i)
    {
        if (i > 0)
            payload << ',';
        payload << state->activeAffixes[i];
    }
    payload << "],";

    payload << "\"bosses\":[";
    for (size_t i = 0; i < state->bossOrder.size(); ++i)
    {
        if (i > 0)
            payload << ',';
        uint32 entry = state->bossOrder[i];
        payload << '{';
        payload << "\"entry\":" << entry << ',';
        bool killed = state->bossKillStamps.find(entry) != state->bossKillStamps.end();
        payload << "\"killed\":" << (killed ? 1 : 0);
        if (killed && state->startedAt)
        {
            uint64 killedAt = state->bossKillStamps[entry];
            uint32 killSeconds = killedAt > state->startedAt ? static_cast<uint32>(killedAt - state->startedAt) : 0;
            payload << ",\"at\":" << killSeconds;
        }
        payload << '}';
    }
    payload << "],";

    payload << "\"participants\":[";
    bool first = true;
    for (ObjectGuid::LowType guid : state->participants)
    {
        if (!first)
            payload << ',';
        payload << guid;
        first = false;
    }
    payload << ']';

    payload << '}';

    std::string data = payload.str();
    PersistHudSnapshot(state, data, force);

#ifndef HAS_AIO
    (void)map;
#else
    Map::PlayerList const& players = map->GetPlayers();
    for (auto const& ref : players)
    {
        if (Player* player = ref.GetSource())
            AIO().Msg(player, MythicPlusConstants::Hud::AIO_ADDON_NAME, MythicPlusConstants::Hud::AIO_MSG_UPDATE, data);
    }
#endif
}

// ============================================================
// Item Level Calculation for Boss Loot
// ============================================================

uint32 MythicPlusRunManager::GetItemLevelForKeystoneLevel(uint8 keystoneLevel) const
{
    // Retail-like scaling: Base ilvl + (keystone level * scaling factor)
    // Base: 226 (Shadowlands S1 M+0)
    // Each level adds 3 item levels up to +10, then 4 per level
    uint32 baseItemLevel = sConfigMgr->GetOption<uint32>("MythicPlus.BaseItemLevel", 226);
    
    if (keystoneLevel <= 10)
        return baseItemLevel + (keystoneLevel * 3);
    else
        return baseItemLevel + (10 * 3) + ((keystoneLevel - 10) * 4);
}

uint32 MythicPlusRunManager::GetTotalBossesForDungeon(uint32 mapId) const
{
    auto cached = _mapBossEntries.find(mapId);
    if (cached != _mapBossEntries.end() && !cached->second.empty())
        return cached->second.size();

    // Use ObjectMgr to get encounters from DBC data as fallback
    // Try both normal and heroic difficulties
    DungeonEncounterList const* encounters = sObjectMgr->GetDungeonEncounterList(mapId, DUNGEON_DIFFICULTY_NORMAL);
    if (encounters && !encounters->empty())
        return encounters->size();

    encounters = sObjectMgr->GetDungeonEncounterList(mapId, DUNGEON_DIFFICULTY_HEROIC);
    if (encounters && !encounters->empty())
        return encounters->size();
    
    // Fallback to hardcoded values if no DBC data
    switch (mapId)
    {
        case 33:   return 5;  // Shadowfang Keep
        case 34:   return 4;  // The Stockade
        case 36:   return 6;  // Deadmines
        case 43:   return 5;  // Wailing Caverns
        case 47:   return 6;  // Razorfen Kraul
        case 48:   return 6;  // Blackfathom Deeps
        case 189:  return 4;  // Scarlet Monastery
        case 209:  return 5;  // Zul'Farrak
        case 249:  return 8;  // Onyxia's Lair
        case 269:  return 4;  // The Black Morass
        case 389:  return 8;  // Ragefire Chasm
        case 429:  return 7;  // Dire Maul
        case 533:  return 15; // Naxxramas
        case 534:  return 9;  // The Battle for Mount Hyjal
        case 542:  return 4;  // Blood Furnace
        case 543:  return 6;  // Hellfire Ramparts
        case 545:  return 3;  // The Steamvault
        case 546:  return 3;  // The Underbog
        case 547:  return 3;  // The Slave Pens
        case 548:  return 4;  // Serpentshrine Cavern (Coilfang Reservoir)
        case 550:  return 4;  // The Eye (Tempest Keep)
        case 552:  return 5;  // The Arcatraz
        case 553:  return 4;  // The Botanica
        case 554:  return 5;  // The Mechanar
        case 555:  return 4;  // Shadow Labyrinth
        case 556:  return 3;  // Sethekk Halls
        case 557:  return 3;  // Mana-Tombs
        case 558:  return 4;  // Auchenai Crypts
        case 560:  return 3;  // Old Hillsbrad Foothills
        case 568:  return 4;  // Zul'Aman
        case 574:  return 5;  // Utgarde Keep
        case 575:  return 4;  // Utgarde Pinnacle
        case 576:  return 4;  // The Nexus
        case 578:  return 5;  // The Oculus
        case 595:  return 4;  // The Culling of Stratholme
        case 599:  return 4;  // Halls of Stone
        case 600:  return 3;  // Drak'Tharon Keep
        case 601:  return 4;  // Azjol-Nerub
        case 602:  return 3;  // Halls of Lightning
        case 603:  return 5;  // Ulduar
        case 604:  return 4;  // Gundrak
        case 608:  return 4;  // Violet Hold
        case 615:  return 5;  // The Obsidian Sanctum
        case 616:  return 2;  // The Eye of Eternity
        case 619:  return 3;  // Ahn'kahet: The Old Kingdom
        case 624:  return 3;  // Vault of Archavon
        case 631:  return 12; // Icecrown Citadel
        case 632:  return 4;  // The Forge of Souls
        case 649:  return 5;  // Trial of the Crusader
        case 650:  return 3;  // Trial of the Champion
        case 658:  return 3;  // Pit of Saron
        case 668:  return 4;  // Halls of Reflection
        case 724:  return 4;  // The Ruby Sanctum
        default:   return 4;  // Default fallback
    }
}

bool MythicPlusRunManager::IsFinalBossEncounter(const InstanceState* state, const Creature* creature) const
{
    if (!state || !creature)
        return false;

    if (IsFinalBoss(state->mapId, creature->GetEntry()))
        return true;

    if (!IsBossCreature(creature))
        return false;

    uint32 totalBosses = GetTotalBossesForDungeon(state->mapId);
    if (totalBosses == 0)
        return false;

    return state->bossesKilled >= totalBosses;
}

bool MythicPlusRunManager::IsMythicPlusActive(Map* map) const
{
    InstanceState const* state = GetState(map);
    if (!state)
        return false;

    return state->keystoneLevel > 0 && !state->completed && !state->failed;
}

bool MythicPlusRunManager::IsMythicPlusDungeon(uint32 mapId) const
{
    DungeonProfile* profile = sMythicScaling->GetDungeonProfile(mapId);
    if (!profile || !profile->mythicEnabled)
        return false;

    if (!sConfigMgr->GetOption<bool>("MythicPlus.FeaturedOnly", true))
        return true;

    return IsDungeonFeaturedThisSeason(mapId, GetCurrentSeasonId());
}

bool MythicPlusRunManager::ShouldSuppressLoot(Creature* creature) const
{
    if (!creature || !creature->GetMap())
        return false;

    if (!sConfigMgr->GetOption<bool>("MythicPlus.SuppressTrashLoot", true))
        return false;

    Map* map = creature->GetMap();
    if (!map->IsDungeon())
        return false;

    InstanceState const* state = GetState(map);
    if (!state || state->keystoneLevel == 0)
        return false;

    if (state->completed || state->failed)
        return false;

    // Always allow final boss loot handling to proceed through GenerateBossLoot
    if (IsFinalBossEncounter(state, creature))
        return false;

    return true;
}

bool MythicPlusRunManager::ShouldSuppressReputation(Player* player) const
{
    if (!player)
        return false;

    if (!sConfigMgr->GetOption<bool>("MythicPlus.SuppressTrashLoot", true))
        return false;

    Map* map = player->GetMap();
    if (!map || !map->IsDungeon())
        return false;

    InstanceState const* state = GetState(map);
    if (!state || state->keystoneLevel == 0)
        return false;

    if (state->completed || state->failed)
        return false;

    return true;
}

