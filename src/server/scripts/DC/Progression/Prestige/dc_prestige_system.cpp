/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Released under GNU AGPL v3 License
 *
 * DarkChaos-255 Prestige System
 *
 * Features:
 * - Reset level 255 players to level 1 with permanent stat bonuses
 * - Up to 10 prestige levels
 * - Each prestige grants 1% bonus to all stats (stacking)
 * - Exclusive titles and cosmetic rewards
 * - Prestige levels displayed via achievements/worldstates
 * - Option to keep gear or reset to starter gear
 * - Integration with Heirloom scaling system
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Config.h"
#include "Chat.h"
#include "World.h"
#include "DatabaseEnv.h"
#include "GameTime.h"
#include "ObjectAccessor.h"
#include "SpellAuras.h"
#include "SpellAuraEffects.h"
#include "SpellMgr.h"
#include "AchievementMgr.h"
#include "Item.h"
#include "Mail.h"
#include "ObjectMgr.h"
#include "QuestDef.h"
#include "WorldSession.h"
#include "WorldSessionMgr.h"
#include "DC/ItemUpgrades/ItemUpgradeManager.h"
#include "DC/CrossSystem/CrossSystemRewards.h"
#include "DC/Progression/FirstStart/dc_firststart_learnspells.h"
#include "dc_prestige_api.h"
#include "DC/AddonExtension/dc_addon_namespace.h"
#include "DC/AddonExtension/dc_addon_prestige_notify.h"
#include <functional>
#include <sstream>
#include <mutex>
#include <vector>

using namespace Acore::ChatCommands;

enum PrestigeConfig
{
    MAX_PRESTIGE_LEVEL = 10,
    REQUIRED_LEVEL = 255,
    STAT_BONUS_PER_PRESTIGE = 1,  // 1% per prestige level
};

// Prestige spell lookup table (O(1) access)
constexpr uint32 PRESTIGE_SPELLS[MAX_PRESTIGE_LEVEL] = {
    800010, 800011, 800012, 800013, 800014,
    800015, 800016, 800017, 800018, 800019
};

// Prestige title lookup table (O(1) access)
constexpr uint32 PRESTIGE_TITLES[MAX_PRESTIGE_LEVEL] = {
    178, 179, 180, 181, 182,
    183, 184, 185, 186, 187
};

// Enums removed - using arrays as single source of truth
// See PRESTIGE_SPELLS and PRESTIGE_TITLES above

struct PrestigeReward
{
    uint32 itemEntry;
    uint32 count;
};

// Why a prestige is refused. The first three are the requirements (CanPrestige); the rest are about
// the moment, because a prestige rebuilds the character and teleports it.
enum class PrestigeRefusal : uint8
{
    None,
    Disabled,
    BelowLevel,
    MaxPrestige,
    Dead,
    InCombat,
    Travelling,
    NotInOpenWorld
};

// The action bar a fresh start cleared: index 0 counts the buttons still waiting, index 1 + button
// holds that button's spell until the character knows a rank of it again.
std::string const PRESTIGE_BAR_SETTING = "dc-prestige-bar";

class PrestigeSystem
{
public:
    static PrestigeSystem* instance()
    {
        static PrestigeSystem instance;
        return &instance;
    }

    void LoadConfig()
    {
        enabled = sConfigMgr->GetOption<bool>("Prestige.Enable", true);
        debug = sConfigMgr->GetOption<bool>("Prestige.Debug", false);
        requireLevel = sConfigMgr->GetOption<uint32>("Prestige.RequiredLevel", REQUIRED_LEVEL);
        maxPrestigeLevel = sConfigMgr->GetOption<uint32>("Prestige.MaxLevel", MAX_PRESTIGE_LEVEL);
        statBonusPercent = sConfigMgr->GetOption<uint32>("Prestige.StatBonusPercent", STAT_BONUS_PER_PRESTIGE);
        resetLevel = sConfigMgr->GetOption<uint32>("Prestige.ResetLevel", 1);
        keepGear = sConfigMgr->GetOption<bool>("Prestige.KeepGear", true);
        keepProfessions = sConfigMgr->GetOption<bool>("Prestige.KeepProfessions", true);
        keepGold = sConfigMgr->GetOption<bool>("Prestige.KeepGold", true);
        freshStart = sConfigMgr->GetOption<bool>("Prestige.FreshStart", true);
        grantStarterGear = sConfigMgr->GetOption<bool>("Prestige.GrantStarterGear", false);
        announcePrestige = sConfigMgr->GetOption<bool>("Prestige.AnnounceWorld", true);
        pointsPerPrestige = sConfigMgr->GetOption<uint32>("Prestige.PointsPerPrestige", 1);
        tokenRewardPerPrestige = sConfigMgr->GetOption<uint32>("Prestige.TokenRewardPerPrestige", 0);
        essenceRewardPerPrestige = sConfigMgr->GetOption<uint32>("Prestige.EssenceRewardPerPrestige", 0);

        // Config validation with error logging
        bool configValid = true;

        if (maxPrestigeLevel == 0 || maxPrestigeLevel > MAX_PRESTIGE_LEVEL)
        {
            LOG_ERROR("scripts.dc", "Prestige: Invalid MaxLevel ({}). Must be 1-{}. Using default {}.",
                maxPrestigeLevel, MAX_PRESTIGE_LEVEL, MAX_PRESTIGE_LEVEL);
            maxPrestigeLevel = MAX_PRESTIGE_LEVEL;
            configValid = false;
        }

        // A prestige restarts below RequiredLevel and at level 1 or higher.
        if (requireLevel < 2 || requireLevel > 255)
        {
            LOG_ERROR("scripts.dc", "Prestige: Invalid RequiredLevel ({}). Must be 2-255. Using default {}.",
                requireLevel, REQUIRED_LEVEL);
            requireLevel = REQUIRED_LEVEL;
            configValid = false;
        }

        if (resetLevel == 0 || resetLevel >= requireLevel)
        {
            LOG_ERROR("scripts.dc", "Prestige: Invalid ResetLevel ({}). Must be 1-{} (less than RequiredLevel). Using default 1.",
                resetLevel, requireLevel - 1);
            resetLevel = 1;
            configValid = false;
        }

        if (statBonusPercent == 0 || statBonusPercent > 100)
        {
            LOG_WARN("scripts.dc", "Prestige: StatBonusPercent ({}) is outside recommended range 1-100. Proceeding anyway.",
                statBonusPercent);
        }

        if (tokenRewardPerPrestige > 0 && DarkChaos::ItemUpgrade::GetUpgradeTokenItemId() == 0)
        {
            LOG_ERROR("scripts.dc", "Prestige: TokenRewardPerPrestige is set but ItemUpgrade token item id resolves to 0. Disabling token rewards.");
            tokenRewardPerPrestige = 0;
            configValid = false;
        }

        if (essenceRewardPerPrestige > 0 && DarkChaos::ItemUpgrade::GetArtifactEssenceItemId() == 0)
        {
            LOG_ERROR("scripts.dc", "Prestige: EssenceRewardPerPrestige is set but ItemUpgrade essence item id resolves to 0. Disabling essence rewards.");
            essenceRewardPerPrestige = 0;
            configValid = false;
        }

        if (configValid)
        {
            LOG_INFO("scripts.dc", "Prestige: Configuration loaded successfully");
        }
        else
        {
            LOG_WARN("scripts.dc", "Prestige: Configuration loaded with errors (see above). Some values were reset to defaults.");
        }

        // Load prestige rewards
        LoadPrestigeRewards();
    }

    bool IsEnabled() const { return enabled; }
    uint32 GetRequiredLevel() const { return requireLevel; }
    uint32 GetMaxPrestigeLevel() const { return maxPrestigeLevel; }
    uint32 GetStatBonusPercent() const { return statBonusPercent; }
    uint32 GetResetLevel() const { return resetLevel; }
    bool IsFreshStartEnabled() const { return freshStart; }

    uint32 GetPrestigeLevel(Player* player)
    {
        if (!player)
            return 0;

        uint32 guid = player->GetGUID().GetCounter();
        {
            std::lock_guard<std::mutex> lock(cacheMutex);
            auto it = prestigeCache.find(guid);
            if (it != prestigeCache.end())
                return it->second.level;
        }

        // Query from database - guid is uint32 so SQL injection is not possible
        std::string sql = Acore::StringFormat(
            "SELECT prestige_level, prestige_points FROM dc_character_prestige WHERE guid = {}", guid);
        QueryResult result = CharacterDatabase.Query(sql.c_str());
        CachedPrestige cached;
        if (result)
        {
            Field* fields = result->Fetch();
            cached.level = fields[0].Get<uint32>();
            cached.points = fields[1].Get<uint32>();
        }

        {
            std::lock_guard<std::mutex> lock(cacheMutex);
            prestigeCache[guid] = cached;
        }
        return cached.level;
    }

    // Cache-only read: never touches the database. Returns 0 until the cache
    // has been warmed (WarmPrestigeCacheAsync / first GetPrestigeLevel call).
    // Use on hot paths like per-tick updates.
    uint32 GetCachedPrestigeLevel(ObjectGuid playerGuid)
    {
        std::lock_guard<std::mutex> lock(cacheMutex);
        auto it = prestigeCache.find(playerGuid.GetCounter());
        return it != prestigeCache.end() ? it->second.level : 0;
    }

    // Load + cache the prestige level asynchronously (the cache is cold after
    // every relog), then run the continuation on the world thread with the
    // player re-resolved by guid. The continuation is skipped if the player
    // logged out meanwhile.
    void WarmPrestigeCacheAsync(ObjectGuid playerGuid, std::function<void(Player*, uint32)> continuation)
    {
        DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(Acore::StringFormat(
            "SELECT prestige_level, prestige_points FROM dc_character_prestige WHERE guid = {}",
            playerGuid.GetCounter()))
            .WithCallback([this, playerGuid, continuation = std::move(continuation)](QueryResult result)
        {
            Player* player = ObjectAccessor::FindPlayer(playerGuid);
            if (!player || !player->GetSession())
                return;

            CachedPrestige cached;
            if (result)
            {
                Field* fields = result->Fetch();
                cached.level = fields[0].Get<uint32>();
                cached.points = fields[1].Get<uint32>();
            }

            {
                std::lock_guard<std::mutex> lock(cacheMutex);
                prestigeCache[playerGuid.GetCounter()] = cached;
            }

            if (continuation)
                continuation(player, cached.level);
        }));
    }

    void SetPrestigeLevel(Player* player, uint32 level)
    {
        if (!player)
            return;

        uint32 currentPoints = GetPrestigePoints(player);
        SetPrestigeProgress(player, level, currentPoints);
    }

    // The points come from the same row as the level, cached alongside it.
    uint32 GetPrestigePoints(Player* player)
    {
        if (!player)
            return 0;

        GetPrestigeLevel(player); // fills the cache when it is cold

        std::lock_guard<std::mutex> lock(cacheMutex);
        auto it = prestigeCache.find(player->GetGUID().GetCounter());
        return it != prestigeCache.end() ? it->second.points : 0;
    }

    void SetPrestigeProgress(Player* player, uint32 level, uint32 points)
    {
        if (!player)
            return;

        CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
        AppendPrestigeProgress(trans, player, level, points);
        CharacterDatabase.CommitTransaction(trans);
    }

    // Writes the prestige row as part of `trans`, so it commits together with the character save.
    void AppendPrestigeProgress(CharacterDatabaseTransaction trans, Player* player, uint32 level, uint32 points)
    {
        uint32 guid = player->GetGUID().GetCounter();

        // All parameters are uint32 so SQL injection is not possible with StringFormat
        trans->Append(
            "INSERT INTO dc_character_prestige (guid, prestige_level, total_prestiges, last_prestige_time, prestige_points) "
            "VALUES ({}, {}, {}, UNIX_TIMESTAMP(), {}) "
            "ON DUPLICATE KEY UPDATE prestige_level = VALUES(prestige_level), total_prestiges = VALUES(total_prestiges), "
            "last_prestige_time = VALUES(last_prestige_time), prestige_points = VALUES(prestige_points)",
            guid, level, level, points);

        std::lock_guard<std::mutex> lock(cacheMutex);
        prestigeCache[guid] = { level, points };
    }

    void ClearPrestigeCache(ObjectGuid guid)
    {
        std::lock_guard<std::mutex> lock(cacheMutex);
        auto it = prestigeCache.find(guid.GetCounter());
        if (it != prestigeCache.end())
        {
            prestigeCache.erase(it);
        }
    }

    bool CanPrestige(Player* player)
    {
        if (!enabled || !player)
            return false;

        if (player->GetLevel() < requireLevel)
            return false;

        uint32 currentPrestige = GetPrestigeLevel(player);
        if (currentPrestige >= maxPrestigeLevel)
            return false;

        return true;
    }

    // CanPrestige plus the moment itself: the character is rebuilt and teleported, so not while
    // dead, fighting, travelling or inside an instance.
    PrestigeRefusal CheckPrestige(Player* player)
    {
        if (!enabled)
            return PrestigeRefusal::Disabled;
        if (player->GetLevel() < requireLevel)
            return PrestigeRefusal::BelowLevel;
        if (GetPrestigeLevel(player) >= maxPrestigeLevel)
            return PrestigeRefusal::MaxPrestige;
        if (!player->IsAlive())
            return PrestigeRefusal::Dead;
        if (player->IsInCombat())
            return PrestigeRefusal::InCombat;
        if (player->IsInFlight() || player->GetVehicle() || player->GetTransport())
            return PrestigeRefusal::Travelling;
        if (player->GetMap()->Instanceable())
            return PrestigeRefusal::NotInOpenWorld;
        return PrestigeRefusal::None;
    }

    std::string GetRefusalText(PrestigeRefusal refusal) const
    {
        switch (refusal)
        {
            case PrestigeRefusal::None:
                return {};
            case PrestigeRefusal::Disabled:
                return "The prestige system is currently disabled.";
            case PrestigeRefusal::BelowLevel:
                return Acore::StringFormat("You must be level {} to prestige.", requireLevel);
            case PrestigeRefusal::MaxPrestige:
                return "You have already reached the maximum prestige level.";
            case PrestigeRefusal::Dead:
                return "You cannot prestige while dead.";
            case PrestigeRefusal::InCombat:
                return "You cannot prestige while in combat.";
            case PrestigeRefusal::Travelling:
                return "You cannot prestige while on a flight path, a vehicle or a transport.";
            case PrestigeRefusal::NotInOpenWorld:
                return "You can only prestige in the open world, not in a dungeon, raid, battleground or arena.";
        }
        return {};
    }

    // Where a prestige restarts this character: Prestige.ResetLevel plus the Head Start talent,
    // always below RequiredLevel.
    uint32 GetRestartLevel(Player* player) const
    {
        uint32 talentLevels = static_cast<uint32>(
            PrestigeAPI::GetTalentEffect(player, PrestigeAPI::PRESTIGE_EFFECT_RESET_LEVEL_BONUS));
        return std::min(resetLevel + talentLevels, requireLevel - 1);
    }

    bool PerformPrestige(Player* player)
    {
        if (!player)
            return false;

        ChatHandler chat(player->GetSession());
        if (PrestigeRefusal refusal = CheckPrestige(player); refusal != PrestigeRefusal::None)
        {
            chat.SendSysMessage(GetRefusalText(refusal));
            return false;
        }

        // Resolved before anything changes, so a character without one is refused untouched.
        PlayerInfo const* start = sObjectMgr->GetPlayerInfo(player->getRace(true), player->getClass());
        if (!start)
        {
            LOG_ERROR("scripts.dc", "Prestige: No starting location for race {} class {}: {} cannot prestige.",
                uint32(player->getRace(true)), uint32(player->getClass()), player->GetName());
            chat.SendSysMessage("|cFFFF0000ERROR: Could not determine your starting location. Please contact a GM.|r");
            return false;
        }

        uint32 currentPrestige = GetPrestigeLevel(player);
        uint32 newPrestige = currentPrestige + 1;
        uint32 tokenItemId = DarkChaos::ItemUpgrade::GetUpgradeTokenItemId();
        uint32 essenceItemId = DarkChaos::ItemUpgrade::GetArtifactEssenceItemId();
        uint32 awardedPoints = pointsPerPrestige;
        uint32 awardedTokens = 0;
        uint32 awardedEssence = 0;

        uint32 requiredStacks = CountRequiredRewardStacks(newPrestige);
        if (!keepGear && grantStarterGear)
            requiredStacks += CountRequiredStarterGearStacks(player);

        if (tokenRewardPerPrestige > 0 && tokenItemId > 0)
            requiredStacks += CountStacksForItem(tokenItemId, tokenRewardPerPrestige);

        if (essenceRewardPerPrestige > 0 && essenceItemId > 0)
            requiredStacks += CountStacksForItem(essenceItemId, essenceRewardPerPrestige);

        if (requiredStacks)
        {
            uint32 freeSlots = keepGear ? player->GetFreeInventorySpace() : GetBackpackFreeSlots(player);

            if (freeSlots < requiredStacks)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF0000Not enough bag space to prestige.|r");

                if (keepGear)
                {
                    ChatHandler(player->GetSession()).PSendSysMessage("Free slots: {}. Needed: {}.", freeSlots, requiredStacks);
                    return false;
                }
                else
                {
                    ChatHandler(player->GetSession()).PSendSysMessage("Backpack free slots: {}. Needed: {}.", freeSlots, requiredStacks);
                    return false;
                }

                if (debug)
                    LOG_DEBUG("scripts.dc", "Prestige: Blocked prestige for {} due to bag space (free={}, required={})", player->GetName(), freeSlots, requiredStacks);
                return false;
            }
        }

        // Save current state for logging
        std::string playerName = player->GetName();
        uint32 oldLevel = player->GetLevel();

        LOG_INFO("scripts.dc", "Prestige: Player {} (GUID: {}) starting prestige {} -> {}",
            playerName, player->GetGUID().ToString(), currentPrestige, newPrestige);

        uint32 newLevel = GetRestartLevel(player);

        // Remove old prestige buffs
        RemovePrestigeBuffs(player);

        ResetQuests(player);

        if (freshStart)
            RememberActionBar(player);

        // GiveLevel is the core's own level change, the one .character level also takes downwards:
        // it resets the talents to the new level's points, locks glyph slots, rescales level-scaled
        // items, resyncs the pet and fires OnPlayerLevelChanged.
        player->GiveLevel(newLevel);
        player->SetUInt32Value(PLAYER_XP, 0);

        // Clear player flags using helper function
        ClearPrestigePlayerFlags(player);

        if (freshStart)
        {
            uint32 forgotten = DCFirstStart::LearnSpells::ForgetClassSpellsAbove(player, newLevel, debug);
            ClearForgottenActionButtons(player);
            RestoreRememberedButtons(player, 0);
            player->SendInitialActionButtons();
            StripTemporaryAuras(player);

            if (debug)
                LOG_DEBUG("scripts.dc", "Prestige: {} unlearned {} class spell(s) above level {}",
                    playerName, forgotten, newLevel);
        }

        // What the prestige writes commits together with the character save below, so a crash can
        // never leave the prestige row and the character out of step.
        CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();

        // Handle gear
        if (!keepGear)
        {
            RemoveAllGear(player);
            if (grantStarterGear)
                GrantStarterGear(player);
        }

        // Handle gold
        if (!keepGold)
            player->SetMoney(0);

        // Handle professions
        if (!keepProfessions)
            ResetProfessions(player);

        // Update prestige points and level
        uint32 newTotalPoints = GetPrestigePoints(player) + awardedPoints;
        AppendPrestigeProgress(trans, player, newPrestige, newTotalPoints);

        // Every prestige level adds to the account-wide prestige talent pool
        PrestigeAPI::OnPrestigeLevelChanged(player, currentPrestige, newPrestige);

        // Grant title
        GrantPrestigeTitle(player, newPrestige);

        // Grant prestige rewards
        GrantPrestigeRewards(player, newPrestige);

        // Grant item upgrade currencies for future prestige systems
        if (tokenRewardPerPrestige > 0 && tokenItemId > 0)
        {
            if (DarkChaos::CrossSystem::Rewards::AwardItemOrSeasonalCurrency(
                    player, tokenItemId, tokenRewardPerPrestige,
                    DarkChaos::CrossSystem::SystemId::Prestige,
                    DarkChaos::CrossSystem::EventType::PlayerPrestige,
                    "prestige_levelup"))
                awardedTokens = tokenRewardPerPrestige;
            else
                LOG_WARN("scripts.dc", "Prestige: Failed to award token reward item {} x{} to player {}",
                    tokenItemId, tokenRewardPerPrestige, player->GetName());
        }

        if (essenceRewardPerPrestige > 0 && essenceItemId > 0)
        {
            if (DarkChaos::CrossSystem::Rewards::AwardItemOrSeasonalCurrency(
                    player, essenceItemId, essenceRewardPerPrestige,
                    DarkChaos::CrossSystem::SystemId::Prestige,
                    DarkChaos::CrossSystem::EventType::PlayerPrestige,
                    "prestige_levelup"))
                awardedEssence = essenceRewardPerPrestige;
            else
                LOG_WARN("scripts.dc", "Prestige: Failed to award essence reward item {} x{} to player {}",
                    essenceItemId, essenceRewardPerPrestige, player->GetName());
        }

        // Update achievements/statistics
        UpdatePrestigeAchievements(player, newPrestige);

        // After the rewards, which the bag space check above counted on: what no longer fits is mailed.
        std::vector<Item*> mailed;
        if (freshStart)
        {
            if (keepGear)
                UnequipUnusableItems(player, mailed, trans);

            player->SetHomebind(WorldLocation(start->mapId, start->positionX, start->positionY, start->positionZ,
                start->orientation), start->areaId);
        }

        // Apply new prestige buffs
        ApplyPrestigeBuffs(player);

        // Force update player stats and restore health/mana
        player->UpdateAllStats();
        player->SetFullHealth();
        if (player->getPowerType() == POWER_MANA)
            player->SetPower(POWER_MANA, player->GetMaxPower(POWER_MANA));

        trans->Append(
            "INSERT INTO dc_character_prestige_log (guid, prestige_level, prestige_time, from_level, kept_gear, "
            "awarded_points, awarded_tokens, awarded_essence) VALUES ({}, {}, UNIX_TIMESTAMP(), {}, {}, {}, {}, {})",
            player->GetGUID().GetCounter(), newPrestige, oldLevel, keepGear ? 1 : 0, awardedPoints, awardedTokens,
            awardedEssence);

        MailItems(player, mailed, trans);
        player->SaveToDB(trans, false, false);
        CharacterDatabase.CommitTransaction(trans);

        // Announce to world
        if (announcePrestige)
        {
            std::string announcement = Acore::StringFormat(
                "|cFFFFD700[Prestige]|r Player {} has achieved Prestige Level {}!",
                playerName, newPrestige);
            sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING, announcement);
        }

        // Notify player
        ChatHandler(player->GetSession()).PSendSysMessage("Congratulations! You have reached Prestige Level {}!", newPrestige);
        ChatHandler(player->GetSession()).PSendSysMessage("You now have {}% bonus to all stats!", newPrestige * statBonusPercent);
        if (awardedPoints > 0)
            ChatHandler(player->GetSession()).PSendSysMessage("You gained {} prestige points (total: {}).", awardedPoints, newTotalPoints);
        if (awardedTokens > 0)
            ChatHandler(player->GetSession()).PSendSysMessage("You gained {} upgrade tokens.", awardedTokens);
        if (awardedEssence > 0)
            ChatHandler(player->GetSession()).PSendSysMessage("You gained {} artifact essence.", awardedEssence);
        if (!mailed.empty())
            chat.SendSysMessage("Equipment you can no longer use did not fit in your bags and was mailed to you.");

        // Notify client addon (if installed/enabled) so UI can refresh immediately
        DCPrestigeAddon::NotifyPrestigeLevelUp(player, newPrestige, newPrestige * statBonusPercent);

        LOG_INFO("scripts.dc", "Prestige: Player {} completed prestige to level {}", playerName, newPrestige);

        if (!player->TeleportTo(start->mapId, start->positionX, start->positionY, start->positionZ, start->orientation))
            LOG_ERROR("scripts.dc", "Prestige: {} prestiged but could not be sent to the starting location (map {}).",
                playerName, start->mapId);

        return true;
    }

    // A quest finished but not turned in pays its full experience at turn-in however far below its
    // level the character has dropped (Quest::XPValue never scales a higher quest down), so the quest
    // log is always emptied. A fresh start also hands the ordinary zone quests of the climb back.
    void ResetQuests(Player* player)
    {
        bool pvpQuestRemoved = false;
        for (uint16 slot = 0; slot < MAX_QUEST_LOG_SIZE; ++slot)
        {
            uint32 questId = player->GetQuestSlotQuestId(slot);
            if (!questId)
                continue;

            // The steps of abandoning it from the quest log (WorldSession::HandleQuestLogRemoveQuest).
            if (Quest const* quest = sObjectMgr->GetQuestTemplate(questId))
            {
                if (quest->HasSpecialFlag(QUEST_SPECIAL_FLAGS_TIMED))
                    player->RemoveTimedQuest(questId);

                if (quest->HasFlag(QUEST_FLAGS_FLAGS_PVP))
                    pvpQuestRemoved = true;
            }

            player->TakeQuestSourceItem(questId, false);
            player->AbandonQuest(questId);
            player->RemoveActiveQuest(questId);
            player->RemoveTimedAchievement(ACHIEVEMENT_TIMED_TYPE_QUEST, questId);
            sScriptMgr->OnPlayerQuestAbandon(player, questId);
            player->SetQuestSlot(slot, 0);
        }

        if (pvpQuestRemoved)
        {
            player->pvpInfo.IsHostile = player->pvpInfo.IsInHostileArea || player->HasPvPForcingQuest();
            player->UpdatePvPState();
        }

        if (!freshStart)
            return;

        std::vector<uint32> replayable;
        for (uint32 questId : player->getRewardedQuests())
            if (Quest const* quest = sObjectMgr->GetQuestTemplate(questId))
                if (IsReplayableQuest(quest))
                    replayable.push_back(questId);

        // No per-quest update: the teleport that ends the prestige refreshes the quest-driven auras
        // and phases of the starting area.
        for (uint32 questId : replayable)
            player->RemoveRewardedQuest(questId, false);

        if (debug)
            LOG_DEBUG("scripts.dc", "Prestige: {} can do {} completed zone quest(s) again",
                player->GetName(), replayable.size());
    }

    // The quests a new character meets on the way up: ordinary open-world quests of a zone, at a fixed
    // level of the climb, done once. Class and profession quests (negative QuestSortID or a class
    // restriction), dungeon, raid, PvP and event quests, and daily, weekly, monthly, seasonal,
    // repeatable and dungeon finder quests stay done. Conquest of Azeroth's mod-coa-prestige replays
    // the same set.
    bool IsReplayableQuest(Quest const* quest) const
    {
        switch (quest->GetType())
        {
            case 0: // QuestInfoID none: a normal quest
            case QUEST_TYPE_ELITE:
            case QUEST_TYPE_LIFE:
            case QUEST_TYPE_ESCORT:
                break;
            default:
                return false;
        }

        if (quest->IsRepeatable() || quest->IsDailyOrWeekly() || quest->IsMonthly() || quest->IsSeasonal() ||
            quest->IsDFQuest() || quest->GetRequiredClasses())
            return false;

        return quest->GetZoneOrSort() > 0 && quest->GetQuestLevel() >= 1 &&
            uint32(quest->GetQuestLevel()) <= requireLevel;
    }

    // The spell buttons of the action bar, kept so each spell returns to its button once the
    // character knows a rank of it again (RestoreRememberedButtons).
    void RememberActionBar(Player* player)
    {
        uint32 remembered = 0;
        for (uint8 button = 0; button < MAX_ACTION_BUTTONS; ++button)
        {
            uint32 spellId = 0;
            if (ActionButton const* action = player->GetActionButton(button))
                if (action->GetType() == ACTION_BUTTON_SPELL)
                    spellId = action->GetAction();

            player->UpdatePlayerSetting(PRESTIGE_BAR_SETTING, 1 + button, spellId);
            if (spellId)
                ++remembered;
        }

        player->UpdatePlayerSetting(PRESTIGE_BAR_SETTING, 0, remembered);
    }

    // Spell buttons whose spell the prestige took away go, as the next login would drop them.
    void ClearForgottenActionButtons(Player* player)
    {
        for (uint8 button = 0; button < MAX_ACTION_BUTTONS; ++button)
            if (ActionButton const* action = player->GetActionButton(button))
                if (action->GetType() == ACTION_BUTTON_SPELL && !player->HasSpell(action->GetAction()))
                    player->removeActionButton(button);
    }

    static uint32 HighestKnownRank(Player* player, uint32 firstRank)
    {
        uint32 highest = 0;
        for (uint32 rank = firstRank; rank; rank = sSpellMgr->GetNextSpellInChain(rank))
            if (player->HasSpell(rank))
                highest = rank;
        return highest;
    }

    // Puts remembered spells back on their buttons: the ones of `learnedSpell`'s rank chain, or with 0
    // every one the character knows a rank of. A button filled with something else since keeps it.
    // Returns whether a button changed.
    bool RestoreRememberedButtons(Player* player, uint32 learnedSpell)
    {
        uint32 waiting = player->GetPlayerSetting(PRESTIGE_BAR_SETTING, 0).value;
        if (!waiting)
            return false;

        uint32 learnedChain = learnedSpell ? sSpellMgr->GetFirstSpellInChain(learnedSpell) : 0;
        bool placed = false;
        for (uint8 button = 0; button < MAX_ACTION_BUTTONS && waiting; ++button)
        {
            uint32 remembered = player->GetPlayerSetting(PRESTIGE_BAR_SETTING, 1 + button).value;
            if (!remembered)
                continue;

            uint32 chain = sSpellMgr->GetFirstSpellInChain(remembered);
            uint32 spellId = 0;
            if (!learnedSpell)
                spellId = HighestKnownRank(player, chain);
            else if (chain == learnedChain)
                spellId = learnedSpell;

            if (!spellId)
                continue;

            player->UpdatePlayerSetting(PRESTIGE_BAR_SETTING, 1 + button, 0);
            --waiting;

            ActionButton const* current = player->GetActionButton(button);
            bool isFree = !current ||
                (current->GetType() == ACTION_BUTTON_SPELL && !player->HasSpell(current->GetAction()));
            if (isFree && player->addActionButton(button, spellId, ACTION_BUTTON_SPELL))
                placed = true;
        }

        player->UpdatePlayerSetting(PRESTIGE_BAR_SETTING, 0, waiting);
        return placed;
    }

    // Buffs from before the prestige (flasks, food, raid buffs at their old strength) and the mount
    // go. Debuffs stay: Deserter, Resurrection Sickness and dungeon cooldowns are penalties.
    void StripTemporaryAuras(Player* player)
    {
        player->RemoveAurasByType(SPELL_AURA_MOUNTED);
        player->RemoveOwnedAuras([](Aura const* aura)
        {
            return !aura->IsPassive() && !aura->IsPermanent() && aura->GetSpellInfo()->IsPositive();
        });
    }

    // Equipment the character can no longer use at its new level (level, proficiency, skill or
    // reputation requirement) goes to the bags, or to the mailbox when they are full.
    void UnequipUnusableItems(Player* player, std::vector<Item*>& mailed, CharacterDatabaseTransaction trans)
    {
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (!item || player->CanUseItem(item, false) == EQUIP_ERR_OK)
                continue;

            ItemPosCountVec destination;
            if (player->CanStoreItem(NULL_BAG, NULL_SLOT, destination, item, false) == EQUIP_ERR_OK)
            {
                player->RemoveItem(INVENTORY_SLOT_BAG_0, slot, true);
                player->StoreItem(destination, item, true);
                continue;
            }

            player->MoveItemFromInventory(INVENTORY_SLOT_BAG_0, slot, true);
            item->DeleteFromInventoryDB(trans);
            item->SaveToDB(trans);
            mailed.push_back(item);
        }

        // The off-hand rules (Dual Wield, Titan's Grip) against what the character still knows.
        player->AutoUnequipOffhandIfNeed();
    }

    void MailItems(Player* player, std::vector<Item*> const& items, CharacterDatabaseTransaction trans)
    {
        for (size_t first = 0; first < items.size(); first += MAX_MAIL_ITEMS)
        {
            MailDraft draft("Prestige", "Your bags were full, so the equipment you can no longer use was sent here.");
            for (size_t index = first; index < std::min<size_t>(items.size(), first + MAX_MAIL_ITEMS); ++index)
                draft.AddItem(items[index]);

            draft.SendMailTo(trans, MailReceiver(player), MailSender(MAIL_NORMAL, 0, MAIL_STATIONERY_GM),
                MAIL_CHECK_MASK_COPIED);
        }
    }

    void ApplyPrestigeBuffs(Player* player)
    {
        if (!player)
            return;

        uint32 prestigeLevel = GetPrestigeLevel(player);
        if (prestigeLevel == 0)
            return;

        uint32 spellId = GetPrestigeSpell(prestigeLevel);
        if (!spellId)
            return;

        // Validate spell exists in DBC
        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
        if (!spellInfo)
        {
            LOG_ERROR("scripts.dc", "Prestige: Spell {} not found in DBC for prestige level {}", spellId, prestigeLevel);
            ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF0000ERROR: Prestige spell not found!|r");
            return;
        }

        // Remove any existing prestige buffs first
        RemovePrestigeBuffs(player);

        // Cast prestige aura with triggered flags to ensure it sticks
        player->CastSpell(player, spellId, TriggerCastFlags(TRIGGERED_CAST_DIRECTLY | TRIGGERED_IGNORE_GCD));

        // Verify aura application
        if (!player->HasAura(spellId))
        {
            LOG_WARN("scripts.dc", "Prestige: Aura {} may not have applied to player {}", spellId, player->GetName());
        }

        LOG_INFO("scripts.dc", "Prestige: Applied prestige buff (spell {}) to player {}", spellId, player->GetName());
    }

    void RemovePrestigeBuffs(Player* player)
    {
        if (!player)
            return;

        // Remove all prestige auras (do not assume contiguous spell IDs)
        for (uint32 spellId : PRESTIGE_SPELLS)
            player->RemoveAura(spellId);
    }

    // The prestige aura works out its amount, challenge bonus included, when it is applied
    // (dc_prestige_spells.cpp); a change to that bonus only shows once it is recalculated.
    void RecalculatePrestigeBuffs(Player* player)
    {
        if (!player)
            return;

        for (uint32 spellId : PRESTIGE_SPELLS)
            if (Aura* aura = player->GetAura(spellId))
                aura->RecalculateAmountOfEffects();
    }

    uint32 GetPrestigeSpell(uint32 prestigeLevel)
    {
        if (prestigeLevel == 0 || prestigeLevel > MAX_PRESTIGE_LEVEL)
            return 0;
        return PRESTIGE_SPELLS[prestigeLevel - 1]; // Array index is 0-based
    }

    uint32 GetPrestigeTitle(uint32 prestigeLevel)
    {
        if (prestigeLevel == 0 || prestigeLevel > MAX_PRESTIGE_LEVEL)
            return 0;
        return PRESTIGE_TITLES[prestigeLevel - 1]; // Array index is 0-based
    }

    // Helper: clear the flags left from the level the character prestiged from; at max level the
    // core sets NO_XP_GAIN, which would stop it from levelling again. Only at the moment of a
    // prestige (the character is alive, CheckPrestige makes sure): run at login it undid every
    // XP lock (Experience Eliminator, playerbots) and resurrected anyone who logged in dead.
    void ClearPrestigePlayerFlags(Player* player)
    {
        if (!player)
            return;

        if (player->HasPlayerFlag(PLAYER_FLAGS_IS_OUT_OF_BOUNDS))
        {
            player->RemovePlayerFlag(PLAYER_FLAGS_IS_OUT_OF_BOUNDS);
            if (debug)
                LOG_DEBUG("scripts.dc", "Prestige: Removed OUT_OF_BOUNDS flag from {}", player->GetName());
        }

        // CRITICAL: Clear NO_XP_GAIN flag - allows player to gain experience
        if (player->HasPlayerFlag(PLAYER_FLAGS_NO_XP_GAIN))
        {
            player->RemovePlayerFlag(PLAYER_FLAGS_NO_XP_GAIN);
            if (debug)
                LOG_DEBUG("scripts.dc", "Prestige: Removed NO_XP_GAIN flag from {}", player->GetName());
        }
    }

    void UpdatePrestigeAchievements(Player* player, uint32 prestigeLevel)
    {
        if (!player)
            return;

        // Grant prestige achievement (IDs 10300-10309 from dc_achievements.sql)
        uint32 achievementId = 10300 + (prestigeLevel - 1); // 10300 = Prestige Level 1, etc.

        if (debug && player->IsGameMaster())
            ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Attempting to grant achievement ID: {}", achievementId);
        AchievementEntry const* achievementEntry = sAchievementStore.LookupEntry(achievementId);
        if (achievementEntry)
        {
            player->CompletedAchievement(achievementEntry);
            if (debug && player->IsGameMaster())
                ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00Prestige achievement granted!|r");
        }
        else
        {
            ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF0000WARNING: Prestige achievement ID {} not found!|r", achievementId);
            ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFFF00Run the SQL: Custom/Custom feature SQLs/Achievements/dc_achievements.sql|r");
        }
    }

private:
    bool enabled;
    bool debug;
    uint32 requireLevel;
    uint32 maxPrestigeLevel;
    uint32 statBonusPercent;
    uint32 resetLevel;
    bool keepGear;
    bool keepProfessions;
    bool keepGold;
    bool freshStart;
    bool grantStarterGear;
    bool announcePrestige;
    uint32 pointsPerPrestige;
    uint32 tokenRewardPerPrestige;
    uint32 essenceRewardPerPrestige;
    std::unordered_map<uint32, std::vector<PrestigeReward>> prestigeRewards;

    // dc_character_prestige, per character guid
    struct CachedPrestige
    {
        uint32 level = 0;
        uint32 points = 0;
    };

    std::mutex cacheMutex;
    std::unordered_map<uint32, CachedPrestige> prestigeCache;

    static uint32 CountStacksForItem(uint32 itemEntry, uint32 count)
    {
        if (!count)
            return 0;

        uint32 maxStack = 1;
        if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(itemEntry))
        {
            maxStack = proto->GetMaxStackSize();
            if (!maxStack)
                maxStack = 1;
        }

        return (count + maxStack - 1) / maxStack;
    }

    static uint32 GetBackpackFreeSlots(Player* player)
    {
        if (!player)
            return 0;

        uint32 freeSlots = 0;
        for (uint8 slot = INVENTORY_SLOT_ITEM_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
        {
            if (!player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot))
                ++freeSlots;
        }
        return freeSlots;
    }

    uint32 CountRequiredRewardStacks(uint32 prestigeLevel) const
    {
        auto it = prestigeRewards.find(prestigeLevel);
        if (it == prestigeRewards.end())
            return 0;

        uint32 requiredStacks = 0;
        for (PrestigeReward const& reward : it->second)
            requiredStacks += CountStacksForItem(reward.itemEntry, reward.count);

        return requiredStacks;
    }

    uint32 CountRequiredStarterGearStacks(Player* player) const
    {
        if (!player)
            return 0;

        std::string starterGearList = sConfigMgr->GetOption<std::string>("Prestige.StarterGear." + std::to_string(player->getClass()), "");
        if (starterGearList.empty())
            return 0;

        uint32 requiredStacks = 0;
        std::stringstream ss(starterGearList);
        std::string itemStr;
        while (std::getline(ss, itemStr, ','))
        {
            if (Optional<uint32> itemEntry = Acore::StringTo<uint32>(itemStr))
                requiredStacks += CountStacksForItem(*itemEntry, 1);
        }
        return requiredStacks;
    }

    void LoadPrestigeRewards()
    {
        prestigeRewards.clear();

        // Load from config - format: "prestigeLevel:itemEntry:count;prestigeLevel:itemEntry:count"
        std::string rewardsStr = sConfigMgr->GetOption<std::string>("Prestige.Rewards", "");
        if (rewardsStr.empty())
            return;

        std::stringstream ss(rewardsStr);
        std::string token;
        while (std::getline(ss, token, ';'))
        {
            std::stringstream tokenSS(token);
            std::string part;
            std::vector<std::string> parts;
            while (std::getline(tokenSS, part, ':'))
                parts.push_back(part);

            if (parts.size() == 3)
            {
                if (Optional<uint32> prestigeLevel = Acore::StringTo<uint32>(parts[0]))
                if (Optional<uint32> itemEntry = Acore::StringTo<uint32>(parts[1]))
                if (Optional<uint32> count = Acore::StringTo<uint32>(parts[2]))
                {
                    prestigeRewards[*prestigeLevel].push_back({*itemEntry, *count});
                }
            }
        }
    }

    void GrantPrestigeRewards(Player* player, uint32 prestigeLevel)
    {
        auto it = prestigeRewards.find(prestigeLevel);
        if (it == prestigeRewards.end())
            return;

        for (PrestigeReward const& reward : it->second)
        {
            player->AddItem(reward.itemEntry, reward.count);
        }
    }

    void GrantPrestigeTitle(Player* player, uint32 prestigeLevel)
    {
        uint32 titleId = GetPrestigeTitle(prestigeLevel);
        if (titleId)
        {
            if (debug && player->IsGameMaster())
                ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Attempting to grant title ID: {}", titleId);
            CharTitlesEntry const* titleEntry = sCharTitlesStore.LookupEntry(titleId);
            if (titleEntry)
            {
                player->SetTitle(titleEntry);
                if (debug && player->IsGameMaster())
                    ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00Title granted!|r");
            }
            else
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF0000ERROR: Title ID {} not found in CharTitles.dbc!|r", titleId);
                ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFFF00Titles need to be added to CharTitles.dbc for 3.3.5a|r");
            }
        }
    }

    void RemoveAllGear(Player* player)
    {
        // 1. Remove Equipment
        for (uint8 i = EQUIPMENT_SLOT_START; i < EQUIPMENT_SLOT_END; ++i)
        {
            if (player->GetItemByPos(INVENTORY_SLOT_BAG_0, i))
            {
                player->DestroyItem(INVENTORY_SLOT_BAG_0, i, true);
            }
        }

        // 2. Remove Backpack Items
        for (uint8 i = INVENTORY_SLOT_ITEM_START; i < INVENTORY_SLOT_ITEM_END; ++i)
        {
            if (player->GetItemByPos(INVENTORY_SLOT_BAG_0, i))
            {
                player->DestroyItem(INVENTORY_SLOT_BAG_0, i, true);
            }
        }

        // 3. Remove Bags and their contents
        for (uint8 i = INVENTORY_SLOT_BAG_START; i < INVENTORY_SLOT_BAG_END; ++i)
        {
            if (Bag* bag = player->GetBagByPos(i))
            {
                for (uint32 j = 0; j < bag->GetBagSize(); ++j)
                {
                    if (bag->GetItemByPos(j))
                    {
                        player->DestroyItem(i, j, true);
                    }
                }
                player->DestroyItem(INVENTORY_SLOT_BAG_0, i, true);
            }
        }

        // 4. Remove Bank Items (Configurable)
        if (sConfigMgr->GetOption<bool>("Prestige.ClearBank", false))
        {
            // Main Bank Slots
            for (uint8 i = BANK_SLOT_ITEM_START; i < BANK_SLOT_ITEM_END; ++i)
            {
                if (player->GetItemByPos(INVENTORY_SLOT_BAG_0, i))
                {
                    player->DestroyItem(INVENTORY_SLOT_BAG_0, i, true);
                }
            }

            // Bank Bags and their contents
            for (uint8 i = BANK_SLOT_BAG_START; i < BANK_SLOT_BAG_END; ++i)
            {
                if (Bag* bag = player->GetBagByPos(i))
                {
                     for (uint32 j = 0; j < bag->GetBagSize(); ++j)
                     {
                         if (bag->GetItemByPos(j))
                             player->DestroyItem(i, j, true);
                     }
                     // Destroy the bank bag itself? Usually bank bags are items in generic inventory slots
                     // Wait, BANK_SLOT_BAG_START indices refer to the slots in the bank that HOLD bags.
                     // IMPORTANT: GetBagByPos(i) works for bank bag slots too.
                     player->DestroyItem(INVENTORY_SLOT_BAG_0, i, true);
                }
            }
        }
    }

    void GrantStarterGear(Player* player)
    {
        // Grant basic starter gear based on class
        // This would need to be configured via database or config
        std::string starterGearList = sConfigMgr->GetOption<std::string>("Prestige.StarterGear." + std::to_string(player->getClass()), "");
        if (starterGearList.empty())
            return;

        std::stringstream ss(starterGearList);
        std::string itemStr;
        while (std::getline(ss, itemStr, ','))
        {
            if (Optional<uint32> itemEntry = Acore::StringTo<uint32>(itemStr))
            {
                player->AddItem(*itemEntry, 1);
            }
        }
    }

    void ResetProfessions(Player* player)
    {
        // 0 = Reset All, 1 = Keep Main, 2 = Keep All
        uint32 professionMode = sConfigMgr->GetOption<uint32>("Prestige.ProfessionResetMode", 0);

        if (professionMode == 2)
            return; // Keep all

        // Secondary skills (Fishing, Cooking, First Aid) - always reset if mode is 0 (Reset All)
        // If mode is 1 (Keep Main), we still reset secondaries? Usually "Keep Main" implies keeping primary professions only.
        // Let's assume mode 1 keeps primary, resets secondary.

        // Helper to reset a specific skill
        auto ResetSkill = [&](uint32 skillId) {
            if (player->HasSkill(skillId))
            {
                player->SetSkill(skillId, 0, 0, 0);
                player->removeSpell(GetSpellIdForSkill(skillId), 0xFF /*SPEC_MASK_ALL*/, false);
                // Actually SetSkill 0/0/0 effectively unlearns it in most cores or sets it to 0/0.
                // For a true reset, we often need to remove the spells.
                // For simplicity here, we stick to the existing SetSkill logic but applied conditionally.
            }
        };

        // Primary Professions
        std::vector<uint32> primarySkills = {
            SKILL_ALCHEMY, SKILL_BLACKSMITHING, SKILL_ENCHANTING, SKILL_ENGINEERING,
            SKILL_HERBALISM, SKILL_INSCRIPTION, SKILL_JEWELCRAFTING, SKILL_LEATHERWORKING,
            SKILL_MINING, SKILL_SKINNING, SKILL_TAILORING
        };

        // Secondary Professions
        std::vector<uint32> secondarySkills = {
            SKILL_COOKING, SKILL_FIRST_AID, SKILL_FISHING
        };

        if (professionMode == 0) // Reset All
        {
            for (uint32 skill : primarySkills) ResetSkill(skill);
            for (uint32 skill : secondarySkills) ResetSkill(skill);
        }
        else if (professionMode == 1) // Keep Main (Primary), Reset Secondary
        {
            for (uint32 skill : secondarySkills) ResetSkill(skill);
        }
    }

    uint32 GetSpellIdForSkill(uint32 /*skill*/)
    {
        // This is tricky without a full lookup table.
        // For now, SetSkill(skill, 0, 0, 0) is the best we can do without massive switch cases.
        return 0;
    }
};

// PlayerScript for applying prestige bonuses on login
class PrestigePlayerScript : public PlayerScript
{
private:
    std::mutex auraCheckMutex;
    // Throttle aura checking to once per 30 seconds instead of every frame
    std::unordered_map<uint32, uint32> lastAuraCheckTime;

public:
    PrestigePlayerScript() : PlayerScript("PrestigePlayerScript",
        { PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LOGOUT, PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_LEARN_SPELL,
          PLAYERHOOK_CAN_GIVE_MAIL_REWARD_AT_GIVE_LEVEL }) { }

    // mail_level_reward keeps no record of who already had a letter, so a prestiged character
    // climbing back up would be sent the same ones every cycle.
    bool OnPlayerCanGiveMailRewardAtGiveLevel(Player* player, uint8 /*level*/) override
    {
        PrestigeSystem* prestige = PrestigeSystem::instance();
        return !prestige->IsEnabled() || !prestige->GetCachedPrestigeLevel(player->GetGUID());
    }

    // A fresh start cleared the action bar: each spell returns to its button when learned again.
    void OnPlayerLearnSpell(Player* player, uint32 spellId) override
    {
        PrestigeSystem* prestige = PrestigeSystem::instance();
        if (!prestige->IsEnabled() || !prestige->IsFreshStartEnabled())
            return;

        // Cache-only: only a prestiged character can have a remembered bar.
        if (!prestige->GetCachedPrestigeLevel(player->GetGUID()))
            return;

        if (prestige->RestoreRememberedButtons(player, spellId))
            player->SendInitialActionButtons();
    }

    void OnPlayerLogin(Player* player) override
    {
        if (!PrestigeSystem::instance()->IsEnabled())
            return;

        // The prestige level is loaded asynchronously so login never blocks
        // the world thread; buffs and welcome messages apply moments later in
        // the continuation (which also warms the cache for OnPlayerUpdate).
        PrestigeSystem::instance()->WarmPrestigeCacheAsync(player->GetGUID(),
            [](Player* player, uint32 prestigeLevel)
        {
            if (prestigeLevel > 0)
            {
                PrestigeSystem::instance()->ApplyPrestigeBuffs(player);

                // Notify player of their prestige level
                ChatHandler(player->GetSession()).PSendSysMessage("Welcome back! You are Prestige Level {} with {}% bonus stats.",
                    prestigeLevel, prestigeLevel * PrestigeSystem::instance()->GetStatBonusPercent());
            }

            // Check if player can prestige (cache is warm, so no DB hit)
            if (PrestigeSystem::instance()->CanPrestige(player) &&
                prestigeLevel < PrestigeSystem::instance()->GetMaxPrestigeLevel())
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFD700You have reached the required level! Type .prestige confirm to ascend!|r");
            }
        });
    }

    void OnPlayerLogout(Player* player) override
    {
        if (!PrestigeSystem::instance()->IsEnabled())
            return;

        // Clear cached prestige level to prevent memory leak
        PrestigeSystem::instance()->ClearPrestigeCache(player->GetGUID());

        // Clean up throttle map
        uint32 guid = player->GetGUID().GetCounter();
        std::lock_guard<std::mutex> lock(auraCheckMutex);
        auto it = lastAuraCheckTime.find(guid);
        if (it != lastAuraCheckTime.end())
        {
            lastAuraCheckTime.erase(it);
        }
    }

    void OnPlayerUpdate(Player* player, uint32 /*p_time*/) override
    {
        if (!PrestigeSystem::instance()->IsEnabled())
            return;

        // Cache-only read: this runs every tick and must never block on the
        // database (login warms the cache asynchronously).
        uint32 prestigeLevel = PrestigeSystem::instance()->GetCachedPrestigeLevel(player->GetGUID());
        if (prestigeLevel == 0)
            return;

        // Throttle aura check to once per 30 seconds (30000ms)
        uint32 guid = player->GetGUID().GetCounter();
        uint32 currentTime = GameTime::GetGameTimeMS().count();

        {
            std::lock_guard<std::mutex> lock(auraCheckMutex);
            auto it = lastAuraCheckTime.find(guid);
            if (it != lastAuraCheckTime.end())
            {
                if (currentTime - it->second < 30000)
                    return; // Too soon, skip this check
            }

            lastAuraCheckTime[guid] = currentTime;
        }

        // Check if prestige aura is missing and reapply it
        uint32 spellId = PrestigeSystem::instance()->GetPrestigeSpell(prestigeLevel);
        if (spellId && !player->HasAura(spellId))
        {
            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
            if (spellInfo)
            {
                player->AddAura(spellId, player);
                LOG_INFO("scripts.dc", "Prestige: Reapplied missing prestige aura {} to player {}",
                    spellId, player->GetName());
            }
        }
    }
};

// World script for loading config
class PrestigeWorldScript : public WorldScript
{
public:
    PrestigeWorldScript() : WorldScript("PrestigeWorldScript") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        PrestigeSystem::instance()->LoadConfig();
    }

    void OnStartup() override
    {
        // Validate that all prestige spells exist in DBC
        LOG_INFO("scripts.dc", "Prestige: Validating prestige spells in DBC...");
        bool allSpellsValid = true;

        for (uint32 i = 1; i <= MAX_PRESTIGE_LEVEL; ++i)
        {
            uint32 spellId = PrestigeSystem::instance()->GetPrestigeSpell(i);
            if (!sSpellMgr->GetSpellInfo(spellId))
            {
                LOG_ERROR("scripts.dc", "Prestige: CRITICAL - Spell {} for prestige level {} not found in DBC!", spellId, i);
                allSpellsValid = false;
            }
        }

        if (allSpellsValid)
        {
            LOG_INFO("scripts.dc", "Prestige: All {} prestige spells validated successfully", MAX_PRESTIGE_LEVEL);
        }
        else
        {
            LOG_ERROR("scripts.dc", "Prestige: CRITICAL - Some prestige spells are missing! System may not work correctly.");
        }

        // Validate that all prestige titles exist in DBC
        LOG_INFO("scripts.dc", "Prestige: Validating prestige titles in DBC...");
        bool allTitlesValid = true;

        for (uint32 i = 1; i <= MAX_PRESTIGE_LEVEL; ++i)
        {
            uint32 titleId = PrestigeSystem::instance()->GetPrestigeTitle(i);
            if (!sCharTitlesStore.LookupEntry(titleId))
            {
                LOG_ERROR("scripts.dc", "Prestige: CRITICAL - Title {} for prestige level {} not found in DBC!", titleId, i);
                allTitlesValid = false;
            }
        }

        if (allTitlesValid)
        {
            LOG_INFO("scripts.dc", "Prestige: All {} prestige titles validated successfully", MAX_PRESTIGE_LEVEL);
        }
        else
        {
            LOG_ERROR("scripts.dc", "Prestige: CRITICAL - Some prestige titles are missing! Players may not receive titles.");
        }
    }
};

void AddSC_dc_prestige_system()
{
    new PrestigePlayerScript();
    new PrestigeWorldScript();
}

namespace PrestigeAPI
{
    bool IsEnabled()
    {
        return PrestigeSystem::instance()->IsEnabled();
    }

    uint32 GetPrestigeLevel(Player* player)
    {
        return PrestigeSystem::instance()->GetPrestigeLevel(player);
    }

    uint32 GetMaxPrestigeLevel()
    {
        return PrestigeSystem::instance()->GetMaxPrestigeLevel();
    }

    uint32 GetRequiredLevel()
    {
        return PrestigeSystem::instance()->GetRequiredLevel();
    }

    uint32 GetStatBonusPercent()
    {
        return PrestigeSystem::instance()->GetStatBonusPercent();
    }

    bool CanPrestige(Player* player)
    {
        return PrestigeSystem::instance()->CanPrestige(player);
    }

    void ApplyPrestigeBuffs(Player* player)
    {
        PrestigeSystem::instance()->ApplyPrestigeBuffs(player);
    }

    void RemovePrestigeBuffs(Player* player)
    {
        PrestigeSystem::instance()->RemovePrestigeBuffs(player);
    }

    void RecalculatePrestigeBuffs(Player* player)
    {
        PrestigeSystem::instance()->RecalculatePrestigeBuffs(player);
    }

    void SetPrestigeLevel(Player* player, uint32 level)
    {
        uint32 oldLevel = PrestigeSystem::instance()->GetPrestigeLevel(player);
        PrestigeSystem::instance()->SetPrestigeLevel(player, level);
        PrestigeSystem::instance()->RemovePrestigeBuffs(player);
        PrestigeSystem::instance()->ApplyPrestigeBuffs(player);
        OnPrestigeLevelChanged(player, oldLevel, level);
    }

    bool PerformPrestige(Player* player)
    {
        return PrestigeSystem::instance()->PerformPrestige(player);
    }

    std::string GetPrestigeRefusal(Player* player)
    {
        if (!player)
            return {};

        PrestigeSystem* prestige = PrestigeSystem::instance();
        return prestige->GetRefusalText(prestige->CheckPrestige(player));
    }

    uint32 GetRestartLevel(Player* player)
    {
        return PrestigeSystem::instance()->GetRestartLevel(player);
    }

    bool IsFreshStartEnabled()
    {
        return PrestigeSystem::instance()->IsFreshStartEnabled();
    }
}
