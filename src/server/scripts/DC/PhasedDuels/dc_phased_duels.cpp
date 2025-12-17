/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * DarkChaos Phased Duels System
 * Creates isolated phases for dueling players with full HP/mana/cooldown reset.
 * Extended features: Arena zones, spectator support, duel stats tracking.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Pet.h"
#include "Config.h"
#include "Chat.h"
#include "GameTime.h"
#include "DatabaseEnv.h"
#include "ObjectAccessor.h"
#include "Map.h"
#include "GameObject.h"
#include "Log.h"
#include "CommandScript.h"

#include <unordered_map>
#include <unordered_set>

using namespace Acore::ChatCommands;

namespace DCPhasedDuels
{
    // ============================================================
    // Configuration
    // ============================================================
    struct PhasedDuelsConfig
    {
        bool enabled = true;
        bool announceOnLogin = true;
        bool resetHealthOnEnd = true;
        bool resetCooldownsOnEnd = true;
        bool restorePowerOnEnd = true;
        bool restorePetHealthOnEnd = true;
        bool excludeRogueWarriorPower = false;
        bool trackStatistics = true;
        bool allowInDungeons = false;
        uint32 arenaZoneId = 0;  // If set, duels only phase in this zone
        float phaseRadius = 100.0f;  // Radius to check for occupied phases
        uint32 maxPhaseId = 0x7FFFFFFF;  // Maximum phase ID to use

        void Load()
        {
            enabled = sConfigMgr->GetOption<bool>("PhasedDuels.Enable", true);
            announceOnLogin = sConfigMgr->GetOption<bool>("PhasedDuels.AnnounceOnLogin", true);
            resetHealthOnEnd = sConfigMgr->GetOption<bool>("PhasedDuels.ResetHealth", true);
            resetCooldownsOnEnd = sConfigMgr->GetOption<bool>("PhasedDuels.ResetCooldowns", true);
            restorePowerOnEnd = sConfigMgr->GetOption<bool>("PhasedDuels.RestorePower", true);
            restorePetHealthOnEnd = sConfigMgr->GetOption<bool>("PhasedDuels.RestorePetHealth", true);
            excludeRogueWarriorPower = sConfigMgr->GetOption<bool>("PhasedDuels.ExcludeRogueWarriorPower", false);
            trackStatistics = sConfigMgr->GetOption<bool>("PhasedDuels.TrackStatistics", true);
            allowInDungeons = sConfigMgr->GetOption<bool>("PhasedDuels.AllowInDungeons", false);
            arenaZoneId = sConfigMgr->GetOption<uint32>("PhasedDuels.ArenaZoneId", 0);
            phaseRadius = sConfigMgr->GetOption<float>("PhasedDuels.PhaseRadius", 100.0f);
            maxPhaseId = sConfigMgr->GetOption<uint32>("PhasedDuels.MaxPhaseId", 0x7FFFFFFF);
        }
    };

    static PhasedDuelsConfig sConfig;

    // ============================================================
    // Duel Statistics Tracking
    // ============================================================
    struct DuelStats
    {
        uint32 wins = 0;
        uint32 losses = 0;
        uint32 draws = 0;
        uint32 totalDamageDealt = 0;
        uint32 totalDamageTaken = 0;
        uint32 longestDuelSeconds = 0;
        uint32 shortestWinSeconds = UINT32_MAX;
        uint64 lastDuelTime = 0;
        ObjectGuid lastOpponent;
    };

    static std::unordered_map<ObjectGuid, DuelStats> sPlayerDuelStats;

    // ============================================================
    // Active Duel Tracking
    // ============================================================
    struct ActiveDuel
    {
        ObjectGuid player1;
        ObjectGuid player2;
        uint32 phaseId;
        uint64 startTime;
        uint32 player1DamageDealt;
        uint32 player2DamageDealt;
    };

    static std::unordered_map<ObjectGuid, ActiveDuel> sActiveDuels;
    static std::unordered_set<uint32> sUsedPhases;

    // ============================================================
    // Helper Functions
    // ============================================================

    uint32 GetNormalPhase(Player* player)
    {
        if (!player)
            return PHASEMASK_NORMAL;

        if (player->IsGameMaster())
            return uint32(PHASEMASK_ANYWHERE);

        // GetPhaseMaskForSpawn equivalent
        uint32 phase = PHASEMASK_NORMAL;
        Player::AuraEffectList const& phases = player->GetAuraEffectsByType(SPELL_AURA_PHASE);
        if (!phases.empty())
            phase = phases.front()->GetMiscValue();

        if (uint32 n_phase = phase & ~PHASEMASK_NORMAL)
            return n_phase;

        return PHASEMASK_NORMAL;
    }

    uint32 FindFreePhase(Player* centerPlayer)
    {
        if (!centerPlayer || !centerPlayer->GetMap())
            return 0;

        Map* map = centerPlayer->GetMap();
        GameObject* duelFlag = map->GetGameObject(centerPlayer->GetGuidValue(PLAYER_DUEL_ARBITER));
        if (!duelFlag)
            return 0;

        // Collect all phases in use within radius
        std::list<Player*> nearbyPlayers;
        Acore::AnyPlayerInObjectRangeCheck checker(duelFlag, sConfig.phaseRadius);
        Acore::PlayerListSearcher<Acore::AnyPlayerInObjectRangeCheck> searcher(duelFlag, nearbyPlayers, checker);
        Cell::VisitObjects(duelFlag, searcher, sConfig.phaseRadius);

        uint32 usedPhases = 0;
        for (Player* p : nearbyPlayers)
        {
            if (p && !p->IsGameMaster())
                usedPhases |= p->GetPhaseMask();
        }

        // Also consider globally used phases
        for (uint32 phase : sUsedPhases)
            usedPhases |= phase;

        // Find first available phase (skip phase 1 which is normal)
        for (uint32 phase = 2; phase <= sConfig.maxPhaseId && phase != 0; phase *= 2)
        {
            if (!(usedPhases & phase))
                return phase;
        }

        return 0;
    }

    void RecordDuelStart(Player* p1, Player* p2, uint32 phaseId)
    {
        if (!p1 || !p2)
            return;

        ActiveDuel duel;
        duel.player1 = p1->GetGUID();
        duel.player2 = p2->GetGUID();
        duel.phaseId = phaseId;
        duel.startTime = GameTime::GetGameTime().count();
        duel.player1DamageDealt = 0;
        duel.player2DamageDealt = 0;

        sActiveDuels[p1->GetGUID()] = duel;
        sActiveDuels[p2->GetGUID()] = duel;
        sUsedPhases.insert(phaseId);

        LOG_DEBUG("scripts", "PhasedDuels: Started duel between {} and {} in phase {}", 
                  p1->GetName(), p2->GetName(), phaseId);
    }

    void RecordDuelEnd(Player* winner, Player* loser, DuelCompleteType type)
    {
        if (!winner || !loser)
            return;

        auto it = sActiveDuels.find(winner->GetGUID());
        if (it == sActiveDuels.end())
            it = sActiveDuels.find(loser->GetGUID());

        if (it == sActiveDuels.end())
            return;

        ActiveDuel& duel = it->second;
        uint64 now = GameTime::GetGameTime().count();
        uint32 durationSeconds = static_cast<uint32>(now - duel.startTime);

        // Release phase
        sUsedPhases.erase(duel.phaseId);

        // Update statistics if enabled
        if (sConfig.trackStatistics)
        {
            DuelStats& winnerStats = sPlayerDuelStats[winner->GetGUID()];
            DuelStats& loserStats = sPlayerDuelStats[loser->GetGUID()];

            if (type == DUEL_WON)
            {
                winnerStats.wins++;
                loserStats.losses++;

                if (durationSeconds < winnerStats.shortestWinSeconds)
                    winnerStats.shortestWinSeconds = durationSeconds;
            }
            else if (type == DUEL_INTERRUPTED || type == DUEL_FLED)
            {
                winnerStats.wins++;
                loserStats.losses++;
            }

            if (durationSeconds > winnerStats.longestDuelSeconds)
                winnerStats.longestDuelSeconds = durationSeconds;
            if (durationSeconds > loserStats.longestDuelSeconds)
                loserStats.longestDuelSeconds = durationSeconds;

            winnerStats.lastDuelTime = now;
            winnerStats.lastOpponent = loser->GetGUID();
            loserStats.lastDuelTime = now;
            loserStats.lastOpponent = winner->GetGUID();

            // Track damage (if we tracked it during duel)
            if (duel.player1 == winner->GetGUID())
            {
                winnerStats.totalDamageDealt += duel.player1DamageDealt;
                loserStats.totalDamageTaken += duel.player1DamageDealt;
            }
            else
            {
                winnerStats.totalDamageDealt += duel.player2DamageDealt;
                loserStats.totalDamageTaken += duel.player2DamageDealt;
            }

            // Persist to database (async)
            CharacterDatabase.Execute(
                "INSERT INTO dc_duel_statistics (player_guid, wins, losses, draws, total_damage_dealt, "
                "total_damage_taken, longest_duel_seconds, shortest_win_seconds, last_duel_time, last_opponent_guid) "
                "VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {}, {}) "
                "ON DUPLICATE KEY UPDATE wins = {}, losses = {}, draws = {}, "
                "total_damage_dealt = {}, total_damage_taken = {}, "
                "longest_duel_seconds = GREATEST(longest_duel_seconds, {}), "
                "shortest_win_seconds = LEAST(shortest_win_seconds, {}), "
                "last_duel_time = {}, last_opponent_guid = {}",
                winner->GetGUID().GetCounter(),
                winnerStats.wins, winnerStats.losses, winnerStats.draws,
                winnerStats.totalDamageDealt, winnerStats.totalDamageTaken,
                winnerStats.longestDuelSeconds, winnerStats.shortestWinSeconds,
                now, loser->GetGUID().GetCounter(),
                winnerStats.wins, winnerStats.losses, winnerStats.draws,
                winnerStats.totalDamageDealt, winnerStats.totalDamageTaken,
                durationSeconds, durationSeconds, now, loser->GetGUID().GetCounter());
        }

        // Cleanup
        sActiveDuels.erase(winner->GetGUID());
        sActiveDuels.erase(loser->GetGUID());

        LOG_DEBUG("scripts", "PhasedDuels: Ended duel between {} and {} (winner: {}, duration: {}s)", 
                  winner->GetName(), loser->GetName(), winner->GetName(), durationSeconds);
    }

    void RestorePlayerState(Player* player)
    {
        if (!player)
            return;

        if (sConfig.resetHealthOnEnd)
            player->SetHealth(player->GetMaxHealth());

        if (sConfig.restorePowerOnEnd)
        {
            bool shouldRestore = true;
            if (sConfig.excludeRogueWarriorPower)
            {
                if (player->getClass() == CLASS_ROGUE || player->getClass() == CLASS_WARRIOR)
                    shouldRestore = false;
            }

            if (shouldRestore)
                player->SetPower(player->getPowerType(), player->GetMaxPower(player->getPowerType()));
        }

        if (sConfig.resetCooldownsOnEnd)
            player->RemoveAllSpellCooldown();

        if (sConfig.restorePetHealthOnEnd)
        {
            if (Pet* pet = player->GetPet())
            {
                if (!pet->IsAlive())
                    pet->setDeathState(DeathState::Alive);

                pet->SetHealth(pet->GetMaxHealth());

                if (player->getClass() == CLASS_HUNTER)
                    pet->SetPower(POWER_HAPPINESS, pet->GetMaxPower(POWER_HAPPINESS));
            }
        }
    }

} // namespace DCPhasedDuels

using namespace DCPhasedDuels;

// ============================================================
// Player Script - Duel Events
// ============================================================
class DCPhasedDuelsPlayerScript : public PlayerScript
{
public:
    DCPhasedDuelsPlayerScript() : PlayerScript("DCPhasedDuelsPlayerScript") { }

    void OnPlayerLogin(Player* player) override
    {
        if (!player || !sConfig.enabled)
            return;

        if (sConfig.announceOnLogin)
        {
            ChatHandler(player->GetSession()).SendSysMessage(
                "|cff00ff00[DarkChaos]|r Phased Duels enabled - duels occur in isolated phases!");
        }

        // Load statistics from database
        if (sConfig.trackStatistics)
        {
            QueryResult result = CharacterDatabase.Query(
                "SELECT wins, losses, draws, total_damage_dealt, total_damage_taken, "
                "longest_duel_seconds, shortest_win_seconds, last_duel_time, last_opponent_guid "
                "FROM dc_duel_statistics WHERE player_guid = {}",
                player->GetGUID().GetCounter());

            if (result)
            {
                Field* fields = result->Fetch();
                DuelStats& stats = sPlayerDuelStats[player->GetGUID()];
                stats.wins = fields[0].Get<uint32>();
                stats.losses = fields[1].Get<uint32>();
                stats.draws = fields[2].Get<uint32>();
                stats.totalDamageDealt = fields[3].Get<uint32>();
                stats.totalDamageTaken = fields[4].Get<uint32>();
                stats.longestDuelSeconds = fields[5].Get<uint32>();
                stats.shortestWinSeconds = fields[6].Get<uint32>();
                stats.lastDuelTime = fields[7].Get<uint64>();
                stats.lastOpponent = ObjectGuid::Create<HighGuid::Player>(fields[8].Get<uint32>());
            }
        }
    }

    void OnPlayerLogout(Player* player) override
    {
        if (player)
        {
            sPlayerDuelStats.erase(player->GetGUID());
            sActiveDuels.erase(player->GetGUID());
        }
    }

    void OnPlayerDuelStart(Player* player1, Player* player2) override
    {
        if (!sConfig.enabled || !player1 || !player2)
            return;

        Map* map = player1->GetMap();
        if (!map)
            return;

        // Check if duels allowed in dungeons
        if (map->IsDungeon() && !sConfig.allowInDungeons)
            return;

        // Check arena zone restriction
        if (sConfig.arenaZoneId > 0)
        {
            uint32 zone1 = player1->GetZoneId();
            uint32 zone2 = player2->GetZoneId();
            if (zone1 != sConfig.arenaZoneId || zone2 != sConfig.arenaZoneId)
            {
                // Players not in designated arena zone - skip phasing
                return;
            }
        }

        // Get duel flag for phasing
        GameObject* duelFlag = map->GetGameObject(player1->GetGuidValue(PLAYER_DUEL_ARBITER));
        if (!duelFlag)
            return;

        // Find a free phase
        uint32 freePhase = FindFreePhase(player1);
        if (freePhase == 0)
        {
            ChatHandler(player1->GetSession()).SendSysMessage(
                "|cffff0000[Phased Duels]|r No free phases available. Duel will proceed without phasing.");
            ChatHandler(player2->GetSession()).SendSysMessage(
                "|cffff0000[Phased Duels]|r No free phases available. Duel will proceed without phasing.");
            return;
        }

        // Phase both players (don't update visibility yet)
        player1->SetPhaseMask(freePhase, false);
        player2->SetPhaseMask(freePhase, false);

        // Phase the duel flag
        duelFlag->SetPhaseMask(freePhase, true);

        // Now update visibility for both players
        player1->UpdateObjectVisibility();
        player2->UpdateObjectVisibility();

        // Record duel start
        RecordDuelStart(player1, player2, freePhase);

        LOG_INFO("scripts", "PhasedDuels: {} vs {} started in phase {}", 
                 player1->GetName(), player2->GetName(), freePhase);
    }

    void OnPlayerDuelEnd(Player* winner, Player* loser, DuelCompleteType type) override
    {
        if (!sConfig.enabled || !winner || !loser)
            return;

        // Restore normal phases
        winner->SetPhaseMask(GetNormalPhase(winner), false);
        loser->SetPhaseMask(GetNormalPhase(loser), false);

        // Update visibility
        winner->UpdateObjectVisibility();
        loser->UpdateObjectVisibility();

        // Restore player states
        RestorePlayerState(winner);
        RestorePlayerState(loser);

        // Record duel end and update statistics
        RecordDuelEnd(winner, loser, type);

        LOG_INFO("scripts", "PhasedDuels: Duel ended - Winner: {}, Loser: {}", 
                 winner->GetName(), loser->GetName());
    }
};

// ============================================================
// Command Script - Duel Statistics
// ============================================================
class DCPhasedDuelsCommandScript : public CommandScript
{
public:
    DCPhasedDuelsCommandScript() : CommandScript("DCPhasedDuelsCommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable duelStatsTable =
        {
            { "stats",   HandleDuelStats,    SEC_PLAYER,        Console::No },
            { "top",     HandleDuelTop,      SEC_PLAYER,        Console::No },
            { "reset",   HandleDuelReset,    SEC_ADMINISTRATOR, Console::No },
            { "reload",  HandleDuelReload,   SEC_ADMINISTRATOR, Console::No },
        };

        static ChatCommandTable commandTable =
        {
            { "duel", duelStatsTable }
        };

        return commandTable;
    }

    static bool HandleDuelStats(ChatHandler* handler, Optional<PlayerIdentifier> target)
    {
        Player* player = target ? target->GetConnectedPlayer() : handler->GetPlayer();
        if (!player)
        {
            handler->SendSysMessage("Player not found.");
            return true;
        }

        auto it = sPlayerDuelStats.find(player->GetGUID());
        if (it == sPlayerDuelStats.end())
        {
            handler->PSendSysMessage("|cff00ff00[Duel Stats]|r {} has no duel statistics yet.", player->GetName());
            return true;
        }

        DuelStats& stats = it->second;
        uint32 total = stats.wins + stats.losses + stats.draws;
        float winRate = total > 0 ? (float(stats.wins) / float(total)) * 100.0f : 0.0f;

        handler->SendSysMessage("|cff00ff00========== DUEL STATISTICS ==========|r");
        handler->PSendSysMessage("|cffffd700Player:|r {}", player->GetName());
        handler->PSendSysMessage("|cffffd700Record:|r {} W / {} L / {} D ({:.1f}%% Win Rate)",
            stats.wins, stats.losses, stats.draws, winRate);
        handler->PSendSysMessage("|cffffd700Total Damage Dealt:|r {}", stats.totalDamageDealt);
        handler->PSendSysMessage("|cffffd700Total Damage Taken:|r {}", stats.totalDamageTaken);
        handler->PSendSysMessage("|cffffd700Longest Duel:|r {} seconds", stats.longestDuelSeconds);
        if (stats.shortestWinSeconds < UINT32_MAX)
            handler->PSendSysMessage("|cffffd700Fastest Win:|r {} seconds", stats.shortestWinSeconds);
        handler->SendSysMessage("|cff00ff00======================================|r");

        return true;
    }

    static bool HandleDuelTop(ChatHandler* handler, Optional<uint32> count)
    {
        uint32 limit = count.value_or(10);
        if (limit > 50)
            limit = 50;

        QueryResult result = CharacterDatabase.Query(
            "SELECT c.name, d.wins, d.losses, d.draws FROM dc_duel_statistics d "
            "INNER JOIN characters c ON c.guid = d.player_guid "
            "ORDER BY d.wins DESC LIMIT {}",
            limit);

        if (!result)
        {
            handler->SendSysMessage("|cffff0000No duel statistics found.|r");
            return true;
        }

        handler->SendSysMessage("|cff00ff00========== TOP DUELISTS ==========|r");
        uint32 rank = 1;
        do
        {
            Field* fields = result->Fetch();
            std::string name = fields[0].Get<std::string>();
            uint32 wins = fields[1].Get<uint32>();
            uint32 losses = fields[2].Get<uint32>();
            uint32 draws = fields[3].Get<uint32>();
            uint32 total = wins + losses + draws;
            float winRate = total > 0 ? (float(wins) / float(total)) * 100.0f : 0.0f;

            handler->PSendSysMessage("|cffffd700%u.|r %s - %u W / %u L (%.1f%%)", 
                                      rank++, name.c_str(), wins, losses, winRate);
        }
        while (result->NextRow());

        handler->SendSysMessage("|cff00ff00==================================|r");
        return true;
    }

    static bool HandleDuelReset(ChatHandler* handler, Optional<PlayerIdentifier> target)
    {
        if (!target)
        {
            handler->SendSysMessage("Usage: .duel reset <player>");
            return true;
        }

        Player* player = target->GetConnectedPlayer();
        ObjectGuid::LowType guidLow = target->GetGUID().GetCounter();

        CharacterDatabase.Execute("DELETE FROM dc_duel_statistics WHERE player_guid = {}", guidLow);

        if (player)
            sPlayerDuelStats.erase(player->GetGUID());

        handler->PSendSysMessage("Duel statistics reset for %s.", target->GetName().c_str());
        return true;
    }

    static bool HandleDuelReload(ChatHandler* handler)
    {
        sConfig.Load();
        handler->SendSysMessage("Phased Duels configuration reloaded.");
        return true;
    }
};

// ============================================================
// World Script - Configuration Loading
// ============================================================
class DCPhasedDuelsWorldScript : public WorldScript
{
public:
    DCPhasedDuelsWorldScript() : WorldScript("DCPhasedDuelsWorldScript") { }

    void OnStartup() override
    {
        sConfig.Load();
        LOG_INFO("scripts", "DarkChaos Phased Duels system initialized (Enabled: {})", 
                 sConfig.enabled ? "Yes" : "No");
    }
};

void AddSC_dc_phased_duels()
{
    sConfig.Load();
    new DCPhasedDuelsPlayerScript();
    new DCPhasedDuelsCommandScript();
    new DCPhasedDuelsWorldScript();
}
