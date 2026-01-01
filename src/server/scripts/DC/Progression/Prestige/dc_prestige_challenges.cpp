/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Released under GNU AGPL v3 License
 *
 * DarkChaos-255 Prestige Challenges
 *
 * Optional hard mode challenges for each prestige:
 * - Iron Prestige: No deaths while leveling 1-255
 * - Speed Prestige: Reach 255 in <100 hours played
 * - Solo Prestige: No grouping while leveling
 *
 * Rewards: Special titles, bonus stats, cosmetics
 */

#include "Chat.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "GameTime.h"
#include "Group.h"
#include "GroupScript.h"
#include "Log.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "dc_prestige_api.h"
#include "../../AddonExtension/dc_addon_death_markers.h"
#include <sstream>

namespace
{
    // Challenge types
    enum PrestigeChallenge : uint8
    {
        CHALLENGE_IRON  = 1,  // No deaths
        CHALLENGE_SPEED = 2,  // <100 hours
        CHALLENGE_SOLO  = 3,  // No grouping
    };

    // Challenge rewards
    constexpr uint32 TITLE_IRON_PRESTIGE = 188;   // Title ID for Iron Prestige
    constexpr uint32 TITLE_SPEED_PRESTIGE = 189;  // Title ID for Speed Prestige
    constexpr uint32 TITLE_SOLO_PRESTIGE = 190;   // Title ID for Solo Prestige

    constexpr uint32 BONUS_STAT_PERCENT_IRON = 2;   // +2% all stats
    constexpr uint32 BONUS_STAT_PERCENT_SPEED = 2;  // +2% all stats
    constexpr uint32 BONUS_STAT_PERCENT_SOLO = 2;   // +2% all stats

    constexpr uint32 SPEED_CHALLENGE_TIME_LIMIT = 100 * 3600; // 100 hours in seconds

    struct ChallengeProgress
    {
        uint32 guid;
        uint32 prestigeLevel;
        uint8 challengeType;
        bool active;
        bool completed;
        uint32 startTime;
        uint32 startPlayTime;
        uint32 deathCount;
        uint32 groupCount;
    };

    // Cache active challenges per player
    std::unordered_map<uint32, std::vector<ChallengeProgress>> g_ActiveChallenges;

    class PrestigeChallengeSystem
    {
    public:
        static PrestigeChallengeSystem* instance()
        {
            static PrestigeChallengeSystem instance;
            return &instance;
        }

        void LoadConfig()
        {
            enabled = sConfigMgr->GetOption<bool>("Prestige.Challenges.Enable", true);
            ironEnabled = sConfigMgr->GetOption<bool>("Prestige.Challenges.Iron.Enable", true);
            speedEnabled = sConfigMgr->GetOption<bool>("Prestige.Challenges.Speed.Enable", true);
            soloEnabled = sConfigMgr->GetOption<bool>("Prestige.Challenges.Solo.Enable", true);
            speedTimeLimit = sConfigMgr->GetOption<uint32>("Prestige.Challenges.Speed.TimeLimit", SPEED_CHALLENGE_TIME_LIMIT);

            LOG_INFO("scripts", "Prestige Challenges: Loaded (Iron: {}, Speed: {}h, Solo: {})",
                ironEnabled ? "ON" : "OFF",
                speedEnabled ? speedTimeLimit / 3600 : 0,
                soloEnabled ? "ON" : "OFF");
        }

        bool IsEnabled() const { return enabled; }
        bool IsIronEnabled() const { return ironEnabled; }
        bool IsSpeedEnabled() const { return speedEnabled; }
        bool IsSoloEnabled() const { return soloEnabled; }
        uint32 GetSpeedTimeLimit() const { return speedTimeLimit; }

        void LoadPlayerChallenges(Player* player)
        {
            if (!player)
                return;

            uint32 guid = player->GetGUID().GetCounter();
            g_ActiveChallenges[guid].clear();

            QueryResult result = CharacterDatabase.Query(
                "SELECT guid, prestige_level, challenge_type, active, completed, start_time, start_playtime, death_count, group_count "
                "FROM dc_prestige_challenges WHERE guid = {} AND active = 1",
                guid
            );

            if (result)
            {
                do
                {
                    Field* fields = result->Fetch();
                    ChallengeProgress progress;
                    progress.guid = fields[0].Get<uint32>();
                    progress.prestigeLevel = fields[1].Get<uint32>();
                    progress.challengeType = fields[2].Get<uint8>();
                    progress.active = fields[3].Get<bool>();
                    progress.completed = fields[4].Get<bool>();
                    progress.startTime = fields[5].Get<uint32>();
                    progress.startPlayTime = fields[6].Get<uint32>();
                    progress.deathCount = fields[7].Get<uint32>();
                    progress.groupCount = fields[8].Get<uint32>();

                    g_ActiveChallenges[guid].push_back(progress);
                } while (result->NextRow());

                LOG_INFO("scripts", "Prestige Challenges: Loaded {} active challenge(s) for player {}",
                    g_ActiveChallenges[guid].size(), player->GetName());
            }
        }

        bool HasActiveChallenge(Player* player, PrestigeChallenge challengeType)
        {
            if (!player)
                return false;

            uint32 guid = player->GetGUID().GetCounter();
            auto it = g_ActiveChallenges.find(guid);
            if (it == g_ActiveChallenges.end())
                return false;

            for (auto const& challenge : it->second)
            {
                if (challenge.challengeType == challengeType && challenge.active)
                    return true;
            }

            return false;
        }

        bool StartChallenge(Player* player, PrestigeChallenge challengeType, uint32 prestigeLevel)
        {
            if (!player || !enabled)
                return false;

            // Check if challenge type is enabled
            if ((challengeType == CHALLENGE_IRON && !ironEnabled) ||
                (challengeType == CHALLENGE_SPEED && !speedEnabled) ||
                (challengeType == CHALLENGE_SOLO && !soloEnabled))
            {
                return false;
            }

            // Check if player already has this challenge active
            if (HasActiveChallenge(player, challengeType))
                return false;

            uint32 guid = player->GetGUID().GetCounter();
            uint32 currentTime = GameTime::GetGameTime().count();
            uint32 currentPlayTime = player->GetTotalPlayedTime();

            // Insert into database
            CharacterDatabase.Execute(
                "INSERT INTO dc_prestige_challenges (guid, prestige_level, challenge_type, active, completed, start_time, start_playtime, death_count, group_count) "
                "VALUES ({}, {}, {}, 1, 0, {}, {}, 0, 0)",
                guid, prestigeLevel, static_cast<uint32>(challengeType), currentTime, currentPlayTime
            );

            // Add to cache
            ChallengeProgress progress;
            progress.guid = guid;
            progress.prestigeLevel = prestigeLevel;
            progress.challengeType = challengeType;
            progress.active = true;
            progress.completed = false;
            progress.startTime = currentTime;
            progress.startPlayTime = currentPlayTime;
            progress.deathCount = 0;
            progress.groupCount = 0;

            g_ActiveChallenges[guid].push_back(progress);

            LOG_INFO("scripts", "Prestige Challenges: Player {} started challenge {} for prestige {}",
                player->GetName(), static_cast<uint32>(challengeType), prestigeLevel);

            return true;
        }

        void FailChallenge(Player* player, PrestigeChallenge challengeType, const std::string& reason)
        {
            if (!player)
                return;

            uint32 guid = player->GetGUID().GetCounter();

            // Update database
            CharacterDatabase.Execute(
                "UPDATE dc_prestige_challenges SET active = 0, completed = 0 "
                "WHERE guid = {} AND challenge_type = {} AND active = 1",
                guid, static_cast<uint32>(challengeType)
            );

            // Remove from cache
            auto it = g_ActiveChallenges.find(guid);
            if (it != g_ActiveChallenges.end())
            {
                auto& challenges = it->second;
                challenges.erase(
                    std::remove_if(challenges.begin(), challenges.end(),
                        [challengeType](const ChallengeProgress& c) { return c.challengeType == challengeType; }),
                    challenges.end()
                );
            }

            // Notify player
            std::string challengeName = GetChallengeName(challengeType);
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000[Challenge Failed]|r {} failed: {}",
                challengeName, reason
            );

            LOG_INFO("scripts", "Prestige Challenges: Player {} failed challenge {} - {}",
                player->GetName(), static_cast<uint32>(challengeType), reason);
        }

        void CompleteChallenge(Player* player, PrestigeChallenge challengeType)
        {
            if (!player)
                return;

            uint32 guid = player->GetGUID().GetCounter();

            // Update database
            CharacterDatabase.Execute(
                "UPDATE dc_prestige_challenges SET active = 0, completed = 1, completion_time = UNIX_TIMESTAMP() "
                "WHERE guid = {} AND challenge_type = {} AND active = 1",
                guid, static_cast<uint32>(challengeType)
            );

            // Remove from active cache
            auto it = g_ActiveChallenges.find(guid);
            if (it != g_ActiveChallenges.end())
            {
                auto& challenges = it->second;
                challenges.erase(
                    std::remove_if(challenges.begin(), challenges.end(),
                        [challengeType](const ChallengeProgress& c) { return c.challengeType == challengeType; }),
                    challenges.end()
                );
            }

            // Grant rewards
            GrantChallengeRewards(player, challengeType);

            std::string challengeName = GetChallengeName(challengeType);
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFFD700[Challenge Complete]|r Congratulations! You completed {}!",
                challengeName
            );

            LOG_INFO("scripts", "Prestige Challenges: Player {} completed challenge {}",
                player->GetName(), static_cast<uint32>(challengeType));
        }

        void OnDeath(Player* player, Unit* killer)
        {
            if (!player || !ironEnabled)
                return;

            if (HasActiveChallenge(player, CHALLENGE_IRON))
            {
                // Emit a death marker for Iron Prestige (hardcore-style).
                DCAddon::DeathMarkers::RecordChallengeDeath(player, killer, "iron_prestige", "Iron Prestige");
                FailChallenge(player, CHALLENGE_IRON, "You died");
            }
        }

        void OnJoinGroup(Player* player)
        {
            if (!player || !soloEnabled)
                return;

            if (HasActiveChallenge(player, CHALLENGE_SOLO))
            {
                FailChallenge(player, CHALLENGE_SOLO, "You joined a group");
            }
        }

        void CheckSpeedChallenge(Player* player)
        {
            if (!player || !speedEnabled)
                return;

            if (!HasActiveChallenge(player, CHALLENGE_SPEED))
                return;

            // Check if player reached max level
            if (player->GetLevel() < 255)
                return;

            uint32 guid = player->GetGUID().GetCounter();
            auto it = g_ActiveChallenges.find(guid);
            if (it == g_ActiveChallenges.end())
                return;

            for (auto const& challenge : it->second)
            {
                if (challenge.challengeType == CHALLENGE_SPEED && challenge.active)
                {
                    uint32 totalPlayed = player->GetTotalPlayedTime();
                    uint32 playedTime = (totalPlayed >= challenge.startPlayTime) ? (totalPlayed - challenge.startPlayTime) : 0;

                    if (playedTime <= speedTimeLimit)
                    {
                        CompleteChallenge(player, CHALLENGE_SPEED);
                    }
                    else
                    {
                        FailChallenge(player, CHALLENGE_SPEED,
                            Acore::StringFormat("Took too long ({}h > {}h)",
                                playedTime / 3600, speedTimeLimit / 3600));
                    }
                    break;
                }
            }
        }

        void CheckChallengeCompletion(Player* player)
        {
            if (!player)
                return;

            // Check if player reached max level
            if (player->GetLevel() < 255)
                return;

            uint32 guid = player->GetGUID().GetCounter();
            auto it = g_ActiveChallenges.find(guid);
            if (it == g_ActiveChallenges.end())
                return;

            // Check Iron and Solo challenges (they complete at max level if still active)
            std::vector<PrestigeChallenge> toComplete;

            for (auto const& challenge : it->second)
            {
                if (!challenge.active)
                    continue;

                if (challenge.challengeType == CHALLENGE_IRON || challenge.challengeType == CHALLENGE_SOLO)
                {
                    toComplete.push_back(static_cast<PrestigeChallenge>(challenge.challengeType));
                }
            }

            for (auto challengeType : toComplete)
            {
                CompleteChallenge(player, challengeType);
            }

            // Speed challenge is checked separately
            CheckSpeedChallenge(player);
        }

        std::string GetChallengeName(PrestigeChallenge challengeType)
        {
            switch (challengeType)
            {
                case CHALLENGE_IRON:  return "Iron Prestige";
                case CHALLENGE_SPEED: return "Speed Prestige";
                case CHALLENGE_SOLO:  return "Solo Prestige";
                default: return "Unknown Challenge";
            }
        }

        void GrantChallengeRewards(Player* player, PrestigeChallenge challengeType)
        {
            if (!player)
                return;

            uint32 titleId = 0;
            uint32 statBonus = 0;

            switch (challengeType)
            {
                case CHALLENGE_IRON:
                    titleId = TITLE_IRON_PRESTIGE;
                    statBonus = BONUS_STAT_PERCENT_IRON;
                    break;
                case CHALLENGE_SPEED:
                    titleId = TITLE_SPEED_PRESTIGE;
                    statBonus = BONUS_STAT_PERCENT_SPEED;
                    break;
                case CHALLENGE_SOLO:
                    titleId = TITLE_SOLO_PRESTIGE;
                    statBonus = BONUS_STAT_PERCENT_SOLO;
                    break;
                default:
                    return;
            }

            // Grant title
            if (titleId > 0)
            {
                CharTitlesEntry const* titleInfo = sCharTitlesStore.LookupEntry(titleId);
                if (titleInfo)
                {
                    player->SetTitle(titleInfo);
                    char const* titleName = player->getGender() == GENDER_MALE ? titleInfo->nameMale[sWorld->GetDefaultDbcLocale()] : titleInfo->nameFemale[sWorld->GetDefaultDbcLocale()];
                    ChatHandler(player->GetSession()).PSendSysMessage(
                        "|cFFFFD700You have earned the title: {}|r", titleName);
                }
            }

            // Grant permanent stat bonus (stored in database)
            CharacterDatabase.Execute(
                "INSERT INTO dc_prestige_challenge_rewards (guid, challenge_type, stat_bonus_percent, granted_time) "
                "VALUES ({}, {}, {}, UNIX_TIMESTAMP())",
                player->GetGUID().GetCounter(), static_cast<uint32>(challengeType), statBonus
            );

            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFFD700You gained +{}% permanent stat bonus!|r", statBonus);
        }

        uint32 GetTotalChallengeStatBonus(Player* player)
        {
            if (!player)
                return 0;

            QueryResult result = CharacterDatabase.Query(
                "SELECT SUM(stat_bonus_percent) FROM dc_prestige_challenge_rewards WHERE guid = {}",
                player->GetGUID().GetCounter()
            );

            if (result)
            {
                Field* fields = result->Fetch();
                return fields[0].Get<uint32>();
            }

            return 0;
        }

    private:
        bool enabled;
        bool ironEnabled;
        bool speedEnabled;
        bool soloEnabled;
        uint32 speedTimeLimit;
    };

    class PrestigeChallengePlayerScript : public PlayerScript
    {
    public:
        PrestigeChallengePlayerScript() : PlayerScript("PrestigeChallengePlayerScript") { }

        void OnPlayerLogin(Player* player) override
        {
            if (!PrestigeChallengeSystem::instance()->IsEnabled())
                return;

            PrestigeChallengeSystem::instance()->LoadPlayerChallenges(player);

            // Show active challenges
            uint32 guid = player->GetGUID().GetCounter();
            auto it = g_ActiveChallenges.find(guid);
            if (it != g_ActiveChallenges.end() && !it->second.empty())
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cFFFFD700You have {} active prestige challenge(s)!|r", it->second.size());
            }
        }

        void OnPlayerKilledByCreature(Creature* killer, Player* player) override
        {
            PrestigeChallengeSystem::instance()->OnDeath(player, killer);
        }

        void OnPlayerPVPKill(Player* killer, Player* victim) override
        {
            PrestigeChallengeSystem::instance()->OnDeath(victim, killer);
        }

        void OnPlayerJoinedGroup(Player* player, Group* /*group*/)
        {
            PrestigeChallengeSystem::instance()->OnJoinGroup(player);
        }

        void OnPlayerLevelChanged(Player* player, uint8 /*oldLevel*/) override
        {
            // Check if challenges are completed when reaching max level
            PrestigeChallengeSystem::instance()->CheckChallengeCompletion(player);
        }
    };

    class PrestigeChallengeGroupScript : public GroupScript
    {
    public:
        PrestigeChallengeGroupScript() : GroupScript("PrestigeChallengeGroupScript", { GROUPHOOK_ON_ADD_MEMBER }) { }

        void OnAddMember(Group* group, ObjectGuid guid) override
        {
            if (!group || !PrestigeChallengeSystem::instance()->IsEnabled())
                return;

            Player* player = ObjectAccessor::FindConnectedPlayer(guid);
            if (!player)
                return;

            PrestigeChallengeSystem::instance()->OnJoinGroup(player);
        }
    };

    class PrestigeChallengeWorldScript : public WorldScript
    {
    public:
        PrestigeChallengeWorldScript() : WorldScript("PrestigeChallengeWorldScript") { }

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            PrestigeChallengeSystem::instance()->LoadConfig();
        }

        void OnStartup() override
        {
            LOG_INFO("scripts", "Prestige Challenges: System initialized");
        }
    };

} // namespace

namespace PrestigeAPI
{
    bool IsChallengesEnabled()
    {
        return PrestigeChallengeSystem::instance()->IsEnabled();
    }

    bool StartChallenge(Player* player, uint8 challengeType, uint32 prestigeLevel)
    {
        return PrestigeChallengeSystem::instance()->StartChallenge(player, static_cast<PrestigeChallenge>(challengeType), prestigeLevel);
    }

    std::string GetChallengeName(uint8 challengeType)
    {
        return PrestigeChallengeSystem::instance()->GetChallengeName(static_cast<PrestigeChallenge>(challengeType));
    }

    std::vector<ActiveChallengeInfo> GetActiveChallenges(Player* player)
    {
        std::vector<ActiveChallengeInfo> result;
        if (!player) return result;

        uint32 guid = player->GetGUID().GetCounter();
        auto it = g_ActiveChallenges.find(guid);

        if (it != g_ActiveChallenges.end())
        {
            for (auto const& challenge : it->second)
            {
                result.push_back({ static_cast<uint8>(challenge.challengeType), challenge.prestigeLevel });
            }
        }
        return result;
    }

    uint32 GetTotalChallengeStatBonus(Player* player)
    {
        return PrestigeChallengeSystem::instance()->GetTotalChallengeStatBonus(player);
    }

    bool IsIronEnabled() { return PrestigeChallengeSystem::instance()->IsIronEnabled(); }
    bool IsSpeedEnabled() { return PrestigeChallengeSystem::instance()->IsSpeedEnabled(); }
    bool IsSoloEnabled() { return PrestigeChallengeSystem::instance()->IsSoloEnabled(); }
}

void AddSC_dc_prestige_challenges()
{
    new PrestigeChallengePlayerScript();
    new PrestigeChallengeGroupScript();
    new PrestigeChallengeWorldScript();
}
