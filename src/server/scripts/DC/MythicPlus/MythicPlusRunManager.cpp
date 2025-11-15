/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#include "MythicPlusRunManager.h"

#include "Chat.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "GameObject.h"
#include "GameTime.h"
#include "Group.h"
#include "Item.h"
#include "Log.h"
#include "MapMgr.h"
#include "MythicDifficultyScaling.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "StringFormat.h"
#include "World.h"
#include <algorithm>
#include <cmath>
#include <sstream>

namespace
{
constexpr float MYTHIC_BASE_MULTIPLIER = 2.0f;
constexpr float KEYSTONE_LEVEL_STEP = 0.25f;
constexpr uint8 DEFAULT_VAULT_THRESHOLDS[3] = { 1, 4, 8 };
constexpr uint32 DEFAULT_VAULT_TOKENS[3] = { 50, 100, 150 };
}

MythicPlusRunManager* MythicPlusRunManager::instance()
{
    static MythicPlusRunManager instance;
    return &instance;
}

void MythicPlusRunManager::Reset()
{
    _instanceStates.clear();
    _finalBossEntries.clear();

    uint32 count = 0;
    if (QueryResult result = WorldDatabase.Query("SELECT map_id, boss_entry FROM dc_mplus_final_bosses"))
    {
        do
        {
            Field* fields = result->Fetch();
            uint32 mapId = fields[0].Get<uint32>();
            uint32 bossEntry = fields[1].Get<uint32>();
            _finalBossEntries[mapId].insert(bossEntry);
            ++count;
        } while (result->NextRow());
    }

    LOG_INFO("mythic.run", "Loaded {} Mythic+ final boss records", count);
}

bool MythicPlusRunManager::TryActivateKeystone(Player* player, GameObject* font)
{
    if (!player || !font)
        return false;

    if (!IsKeystoneRequirementEnabled())
    {
        SendGenericError(player, "Mythic+ keystones are currently disabled.");
        return false;
    }

    Map* map = font->GetMap();
    if (!map || !map->IsDungeon())
    {
        SendGenericError(player, "The Font of Power must be used inside a dungeon instance.");
        return false;
    }

    if (map->GetDifficulty() != DUNGEON_DIFFICULTY_EPIC)
    {
        SendGenericError(player, "Set the instance to Mythic difficulty before activating a keystone.");
        return false;
    }

    DungeonProfile* profile = sMythicScaling->GetDungeonProfile(map->GetId());
    if (!profile || !profile->mythicEnabled)
    {
        SendGenericError(player, "This dungeon is not configured for Mythic+ runs yet.");
        return false;
    }

    KeystoneDescriptor descriptor;
    if (!LoadPlayerKeystone(player, map->GetId(), descriptor))
    {
        SendGenericError(player, "You do not possess a valid keystone for this dungeon.");
        return false;
    }

    if (descriptor.level == 0)
    {
        SendGenericError(player, "Keystone data is invalid. Please relog or contact a GM.");
        return false;
    }

    InstanceState* state = GetOrCreateState(map);
    if (!state)
    {
        SendGenericError(player, "Unable to initialize Mythic+ state for this instance.");
        return false;
    }

    if (state->keystoneLevel > 0 && !state->failed && !state->completed)
    {
        SendGenericError(player, "A keystone is already active in this instance.");
        return false;
    }

    state->mapId = map->GetId();
    state->instanceId = map->GetInstanceId();
    state->difficulty = map->GetDifficulty();
    state->keystoneLevel = descriptor.level;
    state->seasonId = descriptor.seasonId ? descriptor.seasonId : GetCurrentSeasonId();
    state->ownerGuid = player->GetGUID();
    state->startedAt = GameTime::GetGameTime();
    state->deaths = 0;
    state->wipes = 0;
    state->failed = false;
    state->completed = false;
    state->tokensGranted = false;
    state->participants.clear();
    RegisterGroupMembers(player, state);

    ConsumePlayerKeystone(player->GetGUID().GetCounter());

    AnnounceToInstance(map, Acore::StringFormat("|cffff8000Keystone Activated|r: +{} {}", descriptor.level, profile->name));

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
}

void MythicPlusRunManager::HandlePlayerDeath(Player* player, Creature* killer)
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
            ChatHandler(owner->GetSession()).PSendSysMessage("|cffff8000Mythic+|r: Death recorded. {} remaining.", remaining);
    }
}

void MythicPlusRunManager::HandleBossEvade(Creature* creature)
{
    if (!creature)
        return;

    Map* map = creature->GetMap();
    if (!map || !map->IsDungeon())
        return;

    InstanceState* state = GetState(map);
    if (!state || state->completed)
        return;

    ++state->wipes;

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

void MythicPlusRunManager::HandleBossDeath(Creature* creature, Unit* /*killer*/)
{
    if (!creature)
        return;

    Map* map = creature->GetMap();
    if (!map || !map->IsDungeon())
        return;

    InstanceState* state = GetState(map);
    if (!state || state->completed)
        return;

    if (!IsFinalBoss(state->mapId, creature->GetEntry()))
        return;

    state->completed = true;
    state->failed = false;

    AwardTokens(state, creature->GetEntry());
    RecordRunResult(state, true, creature->GetEntry());

    _instanceStates.erase(state->instanceKey);
}

void MythicPlusRunManager::HandleInstanceReset(Map* map)
{
    if (!map)
        return;

    uint64 key = MakeInstanceKey(map);
    _instanceStates.erase(key);
}

void MythicPlusRunManager::BuildVaultMenu(Player* /*player*/, Creature* /*creature*/)
{
    // Placeholder - UI work handled in upcoming patch
}

void MythicPlusRunManager::HandleVaultSelection(Player* /*player*/, Creature* /*creature*/, uint32 /*actionId*/)
{
    // Placeholder - reward claim path implemented later
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
        state.difficulty = map->GetDifficulty();
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

    PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_MPLUS_KEYSTONE);
    stmt->SetUInt32(0, player->GetGUID().GetCounter());

    if (PreparedQueryResult result = CharacterDatabase.Query(stmt))
    {
        Field* fields = result->Fetch();
        outDescriptor.mapId = fields[0].Get<uint32>();
        outDescriptor.level = fields[1].Get<uint8>();
        outDescriptor.seasonId = fields[2].Get<uint32>();
        outDescriptor.expiresOn = fields[3].Get<uint64>();
        outDescriptor.ownerGuid = player->GetGUID();

        uint64 now = GameTime::GetGameTime();
        if (outDescriptor.expiresOn && outDescriptor.expiresOn < now)
        {
            ConsumePlayerKeystone(player->GetGUID().GetCounter());
            SendGenericError(player, "Your keystone has expired.");
            return false;
        }

        if (expectedMap && outDescriptor.mapId != expectedMap)
        {
            SendGenericError(player, "This keystone belongs to another dungeon.");
            return false;
        }

        return true;
    }

    return false;
}

void MythicPlusRunManager::ConsumePlayerKeystone(ObjectGuid::LowType playerGuidLow)
{
    PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_DEL_MPLUS_KEYSTONE);
    stmt->SetUInt32(0, playerGuidLow);
    CharacterDatabase.Execute(stmt);
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
    }

    RecordRunResult(state, false, 0);
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
    uint64 now = GameTime::GetGameTime();
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
        if (player->getLevel() > 70)
            baseTokens += (player->getLevel() - 70) * 2;

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
            ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00Mythic+|r: Inventory full, tokens mailed.");
        }

        InsertTokenLog(player->GetGUID().GetCounter(), state->mapId, state->difficulty, state->keystoneLevel, player->getLevel(), bossEntry, tokenCount);
        ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00Mythic+|r: Awarded %u tokens.", tokenCount);
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

    PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_INS_MPLUS_WEEKLY_VAULT);
    stmt->SetUInt32(0, playerGuid);
    stmt->SetUInt32(1, seasonId);
    stmt->SetUInt32(2, weekStart);
    stmt->SetUInt8(3, 1); // runs completed delta
    stmt->SetUInt8(4, keystoneLevel);
    stmt->SetUInt8(5, slot1);
    stmt->SetUInt8(6, slot2);
    stmt->SetUInt8(7, slot3);
    CharacterDatabase.Execute(stmt);
}

void MythicPlusRunManager::UpdateScore(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 mapId, uint8 keystoneLevel, bool success, uint32 score, uint32 /*durationSeconds*/)
{
    PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_INS_MPLUS_SCORE);
    stmt->SetUInt32(0, playerGuid);
    stmt->SetUInt32(1, seasonId);
    stmt->SetUInt32(2, mapId);
    stmt->SetUInt8(3, success ? keystoneLevel : 0);
    stmt->SetUInt32(4, score);

    CharacterDatabase.Execute(stmt);
}

void MythicPlusRunManager::InsertRunHistory(ObjectGuid::LowType playerGuid, uint32 seasonId, uint32 mapId, uint8 keystoneLevel, bool success, uint8 deaths, uint8 wipes, uint32 durationSeconds, uint32 score, const std::string& groupMembers)
{
    PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_INS_MPLUS_RUN_HISTORY);
    stmt->SetUInt32(0, playerGuid);
    stmt->SetUInt32(1, seasonId);
    stmt->SetUInt32(2, mapId);
    stmt->SetUInt8(3, keystoneLevel);
    stmt->SetUInt32(4, score);
    stmt->SetUInt8(5, deaths);
    stmt->SetUInt8(6, wipes);
    stmt->SetUInt32(7, durationSeconds);
    stmt->SetUInt8(8, success ? 1 : 0);
    stmt->SetUInt32(9, 0); // affix pair placeholder
    stmt->SetString(10, groupMembers);

    CharacterDatabase.Execute(stmt);
}

void MythicPlusRunManager::InsertTokenLog(ObjectGuid::LowType playerGuid, uint32 mapId, Difficulty difficulty, uint8 keystoneLevel, uint8 playerLevel, uint32 bossEntry, uint32 tokenCount)
{
    PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_INS_MPLUS_TOKEN_LOG);
    stmt->SetUInt32(0, playerGuid);
    stmt->SetUInt32(1, mapId);
    stmt->SetUInt8(2, static_cast<uint8>(difficulty));
    stmt->SetUInt8(3, keystoneLevel);
    stmt->SetUInt8(4, playerLevel);
    stmt->SetUInt32(5, tokenCount);
    stmt->SetUInt32(6, bossEntry);

    CharacterDatabase.Execute(stmt);
}

uint32 MythicPlusRunManager::GetCurrentSeasonId() const
{
    return sMythicScaling->GetActiveSeasonId();
}

uint32 MythicPlusRunManager::GetWeekStartTimestamp() const
{
    uint32 now = static_cast<uint32>(GameTime::GetGameTime());
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
    auto itr = _finalBossEntries.find(mapId);
    if (itr == _finalBossEntries.end())
        return false;

    return itr->second.find(bossEntry) != itr->second.end();
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
