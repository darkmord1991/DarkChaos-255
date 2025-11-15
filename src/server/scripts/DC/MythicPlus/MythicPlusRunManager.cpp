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
    state->startedAt = GameTime::GetGameTime().count();
    state->deaths = 0;
    state->wipes = 0;
    state->failed = false;
    state->completed = false;
    state->tokensGranted = false;
    state->participants.clear();
    RegisterGroupMembers(player, state);

    // Seasonal validation - check if dungeon is featured this season
    if (sConfigMgr->GetOption<bool>("MythicPlus.FeaturedOnly", true))
    {
        if (!IsDungeonFeaturedThisSeason(map->GetId(), state->seasonId))
        {
            SendGenericError(player, "This dungeon is not featured in the current Mythic+ season.");
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
    ChatHandler(player->GetSession()).PSendSysMessage("Your weekly vault progress was reset.");
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
        ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00Mythic+|r: Inventory full, tokens mailed.");
    }

    // Mark the weekly vault as claimed
    CharacterDatabase.DirectExecute("UPDATE dc_weekly_vault SET reward_claimed = 1, claimed_slot = {}, claimed_tokens = {}, claimed_at = UNIX_TIMESTAMP() WHERE character_guid = {} AND season_id = {} AND week_start = {}",
                                    slot, tokenCount, guidLow, seasonId, weekStart);

    InsertTokenLog(guidLow, 0, DUNGEON_DIFFICULTY_EPIC, 0, player->GetLevel(), 0, tokenCount);
    ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00Mythic+|r: You claimed Slot %u and received %u tokens.", slot, tokenCount);
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
            ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00Mythic+|r: Inventory full, tokens mailed.");
        }

        InsertTokenLog(player->GetGUID().GetCounter(), state->mapId, state->difficulty, state->keystoneLevel, player->GetLevel(), bossEntry, tokenCount);
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
    auto itr = _finalBossEntries.find(mapId);
    if (itr == _finalBossEntries.end())
        return false;

    return itr->second.find(bossEntry) != itr->second.end();
}

bool MythicPlusRunManager::IsDungeonFeaturedThisSeason(uint32 mapId, uint32 seasonId) const
{
    QueryResult result = WorldDatabase.Query(
        "SELECT 1 FROM dc_mplus_featured_dungeons WHERE season_id = {} AND map_id = {}",
        seasonId, mapId);
    
    return result != nullptr;
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
        "SELECT affix_name FROM dc_mplus_affixes WHERE affix_id = {}", affixId);
    
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
    
    return 2;  // Default to M+2
}

bool MythicPlusRunManager::GiveKeystoneToPlayer(Player* player, uint8 keystoneLevel)
{
    if (!player || keystoneLevel < 2 || keystoneLevel > 10)
        return false;

    // Keystone item IDs: 190001-190009 for M+2-M+10
    uint32 keystoneItemId = 190000 + keystoneLevel - 1;

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
    uint8 newLevel = std::min(static_cast<uint8>(10), static_cast<uint8>(currentLevel + 1));

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
    uint8 newLevel = std::max(static_cast<uint8>(2), static_cast<uint8>(currentLevel - 1));

    // Update database
    CharacterDatabase.Execute(
        "UPDATE dc_player_keystones SET current_keystone_level = {} WHERE player_guid = {}", 
        newLevel, playerGuid);

    // Generate new keystone item
    GenerateNewKeystone(playerGuid, newLevel);
}

void MythicPlusRunManager::GenerateNewKeystone(ObjectGuid::LowType playerGuid, uint8 level)
{
    if (level < 2 || level > 10)
        return;

    // Keystone item IDs: 190001-190009 for M+2-M+10
    uint32 keystoneItemId = 190000 + level - 1;

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
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cff00ff00Mythic+:|r New keystone generated (M+%d)", level);
            }
        }
    }
}

