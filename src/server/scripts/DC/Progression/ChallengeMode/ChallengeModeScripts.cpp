/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Customized for DarkChaos-255 by darkmord1991
 *
 * ChallengeModeScripts.cpp - Player scripts for Challenge Mode system
 * Split from dc_challenge_modes_customized.cpp
 */

#include "dc_challenge_modes.h"
#include "dc_challenge_mode_database.h"
#include "DC/AddonExtension/dc_addon_death_markers.h"
#include "DC/AddonExtension/dc_addon_namespace.h"
#include "ObjectAccessor.h"
#include "World.h"
#include "WorldSessionMgr.h"
#include "Chat.h"

using namespace Acore::ChatCommands;

namespace
{
    // Single source of truth for "who/what killed this player", so the hardcore chat broadcast
    // and the death marker (DCAddon::DeathMarkers::RecordChallengeDeath) can never disagree.
    std::string DescribeKillerForChat(DCAddon::DeathMarkers::DeathContext const& ctx)
    {
        if (ctx.killerType == "environment")
            return ctx.environmentType.empty() ? "Environment" : ctx.environmentType;
        if (ctx.killerType == "player" || ctx.killerType == "creature")
            return ctx.killerName.empty() ? "Unknown" : ctx.killerName;
        return "Unknown";
    }
} // namespace

// ==============================================
// DarkChaos-255: HARDCORE CHARACTER LOCKING
// ==============================================
void HandleHardcoreDeath(Player* victim, uint32 killerEntry, std::string const& killerName)
{
    if (!victim)
        return;

    // Mark character as permanently dead
    victim->UpdatePlayerSetting("mod-challenge-modes", HARDCORE_DEAD, 1);
    sChallengeModes->RefreshChallengeAuras(victim);

    // Persist in challenge mode DB tracking (authoritative lock)
    ChallengeModeDatabase::InitializeTracking(victim->GetGUID());
    uint32 const activeModes = ChallengeModeDatabase::ComputeActiveModesFromSettings(victim);
    ChallengeModeDatabase::UpdateActiveModes(victim->GetGUID(), activeModes);
    ChallengeModeDatabase::RecordHardcoreDeath(victim->GetGUID(), victim, killerEntry, killerName, activeModes);
    ChallengeModeDatabase::LockCharacter(victim->GetGUID(), activeModes);

    // Global announcement
    std::ostringstream ss;
    ss << "|cffFF0000[HARDCORE DEATH]|r " << victim->GetName()
       << " has fallen at level " << (uint32)victim->GetLevel() << "! "
       << "Killed by " << killerName << ". "
       << "RIP - May they rest in peace.";
    sWorldSessionMgr->SendServerMessage(SERVER_MSG_STRING, ss.str());

    // Show final stats to player
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFF0000========================================|r");
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFF0000   HARDCORE CHARACTER - DECEASED   |r");
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFF0000========================================|r");
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFFFF00Final Level: |cffFF0000{}", static_cast<uint32>(victim->GetLevel()));
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFFFF00Killed by: |cffFF0000{}", killerName);
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFF0000This character is now PERMANENTLY LOCKED.|r");
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFF0000You will not be able to log in with this character anymore.|r");
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFF0000========================================|r");
}

// Hardcore mode player script
class ChallengeMode_Hardcore : public PlayerScript
{
public:
    ChallengeMode_Hardcore() : PlayerScript("ChallengeMode_Hardcore",
    {
        PLAYERHOOK_ON_PLAYER_JUST_DIED, PLAYERHOOK_ON_PLAYER_KILLED_BY_CREATURE, PLAYERHOOK_ON_PVP_KILL
    }) { }

    void OnPlayerJustDied(Player* player) override
    {
        if (!player)
            return;

        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_HARDCORE, player))
            return;

        // If we already processed the death (e.g., creature/PvP callbacks), don't run twice.
        if (player->GetPlayerSetting("mod-challenge-modes", HARDCORE_DEAD).value == 1)
            return;

        DCAddon::DeathMarkers::DeathContext ctx = DCAddon::DeathMarkers::ResolveDeathContext(player, nullptr);
        HandleHardcoreDeath(player, 0, DescribeKillerForChat(ctx));
        DCAddon::DeathMarkers::RecordChallengeDeath(player, nullptr, "hardcore", "Hardcore");
        player->SetPvPDeath(true);
    }

    void OnPlayerKilledByCreature(Creature* killer, Player* victim) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_HARDCORE, victim))
            return;

        // If we already processed the death (e.g., OnPlayerJustDied/PvP callbacks), don't run twice.
        if (victim->GetPlayerSetting("mod-challenge-modes", HARDCORE_DEAD).value == 1)
            return;

        HandleHardcoreDeath(victim, killer ? killer->GetEntry() : 0, killer ? killer->GetName() : "Unknown");
        DCAddon::DeathMarkers::RecordChallengeDeath(victim, killer, "hardcore", "Hardcore");

        // Make player a permanent ghost (original functionality)
        victim->SetPvPDeath(true);
    }

    void OnPlayerPVPKill(Player* killer, Player* victim) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_HARDCORE, victim))
            return;

        // If we already processed the death (e.g., OnPlayerJustDied/creature callbacks), don't run twice.
        if (victim->GetPlayerSetting("mod-challenge-modes", HARDCORE_DEAD).value == 1)
            return;

        // A self-inflicted death (e.g. falling) also fires this hook with killer == victim;
        // ResolveDeathContext() recognizes that and reports the real environmental cause instead.
        DCAddon::DeathMarkers::DeathContext ctx = DCAddon::DeathMarkers::ResolveDeathContext(victim, killer);
        HandleHardcoreDeath(victim, 0, DescribeKillerForChat(ctx));
        DCAddon::DeathMarkers::RecordChallengeDeath(victim, killer, "hardcore", "Hardcore");

        // Make player a permanent ghost (original functionality)
        victim->SetPvPDeath(true);
    }
};

// ==============================================
// DarkChaos-255: LOGIN PREVENTION
// ==============================================
class ChallengeModes_LoginPrevention : public PlayerScript
{
public:
    ChallengeModes_LoginPrevention() : PlayerScript("ChallengeModes_LoginPrevention", { PLAYERHOOK_ON_LOGIN }) { }

    static void NotifyAndKickDeceased(Player* player)
    {
        // Show death information
        ChatHandler(player->GetSession()).SendSysMessage("|cffFF0000========================================|r");
        ChatHandler(player->GetSession()).SendSysMessage("|cffFF0000   HARDCORE CHARACTER - DECEASED   |r");
        ChatHandler(player->GetSession()).SendSysMessage("|cffFF0000========================================|r");
        ChatHandler(player->GetSession()).PSendSysMessage("This character died in Hardcore mode and is permanently locked.");
        ChatHandler(player->GetSession()).PSendSysMessage("You cannot log in with this character anymore.");
        ChatHandler(player->GetSession()).PSendSysMessage("Please create a new character or choose another one.");
        ChatHandler(player->GetSession()).SendSysMessage("|cffFF0000========================================|r");

        // Kick player after showing message
        player->GetSession()->KickPlayer("Hardcore character is deceased");
    }

    void OnPlayerLogin(Player* player) override
    {
        if (!player)
            return;

        // The legacy player-setting flag lives in memory and is synced from the
        // DB lock below, so once set it kicks with no DB round-trip.
        if (player->GetPlayerSetting("mod-challenge-modes", HARDCORE_DEAD).value == 1)
        {
            NotifyAndKickDeceased(player);
            return;
        }

        // The authoritative DB lock is checked asynchronously so login never
        // blocks the world thread. A locked character is kicked moments later,
        // and the flag sync above makes every later attempt kick instantly.
        ObjectGuid const playerGuid = player->GetGUID();
        DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(Acore::StringFormat(
            "SELECT character_locked FROM dc_character_challenge_modes WHERE guid = {}",
            playerGuid.GetCounter()))
            .WithCallback([playerGuid](QueryResult result)
        {
            if (!result || result->Fetch()[0].Get<uint8>() != 1)
                return;

            Player* player = ObjectAccessor::FindPlayer(playerGuid);
            if (!player || !player->GetSession())
                return;

            player->UpdatePlayerSetting("mod-challenge-modes", HARDCORE_DEAD, 1);
            NotifyAndKickDeceased(player);
        }));
    }
};

class ChallengeModeAuraManager : public PlayerScript
{
public:
    ChallengeModeAuraManager() : PlayerScript("ChallengeModeAuraManager", { PLAYERHOOK_ON_LOGIN }) { }

    void OnPlayerLogin(Player* player) override
    {
        sChallengeModes->RefreshChallengeAuras(player);
    }
};

// ==============================================
// DarkChaos-255: SCRIPT REGISTRATION
// ==============================================
void AddSC_challenge_mode_scripts()
{
    new ChallengeMode_Hardcore();
    new ChallengeModes_LoginPrevention();
    new ChallengeModeAuraManager();
}
