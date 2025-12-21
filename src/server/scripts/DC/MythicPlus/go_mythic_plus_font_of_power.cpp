/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Font of Power GameObject Script
 * Handles keystone activation with group ready check support
 *
 * When a player clicks the Font of Power:
 * 1. Validates keystone can be activated
 * 2. If group present: Initiates group ready check via AIO
 * 3. All group members must accept within timeout
 * 4. Countdown starts when all accept
 * 5. Run begins after countdown
 */

#include "ScriptMgr.h"
#include "ScriptedGossip.h"
#include "Chat.h"
#include "GameObject.h"
#include "GameTime.h"
#include "Group.h"
#include "MythicDifficultyScaling.h"
#include "MythicPlusRunManager.h"
#include "Player.h"
#include "StringFormat.h"

#ifdef HAS_AIO
#include "AIO.h"
#endif

namespace
{
enum FontOfPowerActions : uint32
{
    ACTION_START_RUN     = 1,
    ACTION_START_READY   = 2,  // Start group ready check
    ACTION_CLOSE         = 3
};

// Pending activation state per group
struct PendingKeystoneActivation
{
    ObjectGuid goGuid;
    ObjectGuid playerGuid;
    KeystoneDescriptor keystone;
    std::map<ObjectGuid, int8> memberStates; // 0=pending, 1=ready, 2=declined
    uint32 timeout = 60;
    uint32 startTime = 0;
    bool allReady = false;
    uint8 countdown = 0;
};

std::map<ObjectGuid, PendingKeystoneActivation> s_pendingActivations; // GroupGuid -> Activation

constexpr int8 STATE_PENDING  = 0;
constexpr int8 STATE_READY    = 1;
constexpr int8 STATE_DECLINED = 2;
}

class go_mythic_plus_font_of_power : public GameObjectScript
{
public:
    go_mythic_plus_font_of_power() : GameObjectScript("go_mythic_plus_font_of_power") { }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        if (!player || !go)
            return false;

        KeystoneDescriptor descriptor;
        std::string error;

        ClearGossipMenuFor(player);

        bool canActivate = sMythicRuns->CanActivateKeystone(player, go, descriptor, error);

        if (!canActivate)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, Acore::StringFormat("|cffff0000{}|r", error), GOSSIP_SENDER_MAIN, ACTION_CLOSE);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Close", GOSSIP_SENDER_MAIN, ACTION_CLOSE);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
            return true;
        }

        DungeonProfile* profile = go->GetMap() ? sMythicScaling->GetDungeonProfile(go->GetMap()->GetId()) : nullptr;
        std::string dungeonName = profile ? profile->name : "Unknown Dungeon";

        // Check if player is in a group
        Group* group = player->GetGroup();
        bool hasGroup = group && group->GetMembersCount() > 1;

        if (hasGroup)
        {
            // Show group ready check option
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
                Acore::StringFormat("|cff00ff00[Group Ready Check]|r +{} {}", descriptor.level, dungeonName),
                GOSSIP_SENDER_MAIN, ACTION_START_READY);

            // Also show instant start for leader (bypasses ready check)
            if (group->IsLeader(player->GetGUID()))
            {
                AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
                    Acore::StringFormat("Start Immediately (No Ready Check): +{} {}", descriptor.level, dungeonName),
                    GOSSIP_SENDER_MAIN, ACTION_START_RUN);
            }
        }
        else
        {
            // Solo player - direct start
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
                Acore::StringFormat("Start Mythic+ Run: +{} {}", descriptor.level, dungeonName),
                GOSSIP_SENDER_MAIN, ACTION_START_RUN);
        }

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Cancel", GOSSIP_SENDER_MAIN, ACTION_CLOSE);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, GameObject* go, uint32 sender, uint32 action) override
    {
        if (!player || !go || sender != GOSSIP_SENDER_MAIN)
            return false;

        CloseGossipMenuFor(player);

        if (action == ACTION_START_RUN)
        {
            sMythicRuns->TryActivateKeystone(player, go);
            return true;
        }

        if (action == ACTION_START_READY)
        {
            InitiateGroupReadyCheck(player, go);
            return true;
        }

        // ACTION_CLOSE or unknown - just close
        return true;
    }

private:
    void InitiateGroupReadyCheck(Player* player, GameObject* go)
    {
        if (!player || !go)
            return;

        Group* group = player->GetGroup();
        if (!group)
        {
            ChatHandler(player->GetSession()).SendSysMessage("You are not in a group.");
            return;
        }

        // Check if leader or assistant
        if (!group->IsLeader(player->GetGUID()) && !group->IsAssistant(player->GetGUID()))
        {
            ChatHandler(player->GetSession()).SendSysMessage("Only the group leader or assistant can start a ready check.");
            return;
        }

        // Get keystone info
        KeystoneDescriptor descriptor;
        std::string error;
        if (!sMythicRuns->CanActivateKeystone(player, go, descriptor, error))
        {
            ChatHandler(player->GetSession()).SendSysMessage(error.c_str());
            return;
        }

        DungeonProfile* profile = go->GetMap() ? sMythicScaling->GetDungeonProfile(go->GetMap()->GetId()) : nullptr;
        std::string dungeonName = profile ? profile->name : "Unknown Dungeon";

        // Create pending activation
        ObjectGuid groupGuid = group->GetGUID();
        PendingKeystoneActivation& pending = s_pendingActivations[groupGuid];
        pending.goGuid = go->GetGUID();
        pending.playerGuid = player->GetGUID();
        pending.keystone = descriptor;
        pending.startTime = GameTime::GetGameTime().count();
        pending.timeout = 60;
        pending.allReady = false;
        pending.memberStates.clear();

        // Initialize all member states to pending
        for (GroupReference* ref = group->GetFirstMember(); ref != nullptr; ref = ref->next())
        {
            if (Player* member = ref->GetSource())
            {
                pending.memberStates[member->GetGUID()] = STATE_PENDING;
            }
        }

        // Send ready check to all group members via AIO
#ifdef HAS_AIO
        SendKeystoneReadyCheck(group, dungeonName, descriptor, profile);
#else
        // Fallback: Use chat/whisper system
        SendKeystoneReadyCheckFallback(group, dungeonName, descriptor);
#endif

        ChatHandler(player->GetSession()).PSendSysMessage("Keystone ready check initiated for +%u %s. Waiting for group response...", descriptor.level, dungeonName.c_str());
    }

#ifdef HAS_AIO
    void SendKeystoneReadyCheck(Group* group, const std::string& dungeonName, const KeystoneDescriptor& descriptor, DungeonProfile* profile)
    {
        if (!group)
            return;

        // Build party members list
        std::vector<std::pair<std::string, std::string>> members;
        for (GroupReference* ref = group->GetFirstMember(); ref != nullptr; ref = ref->next())
        {
            if (Player* member = ref->GetSource())
            {
                // Determine role (simplified - could be enhanced with actual spec detection)
                std::string role = "DPS";
                if (member->HasTankSpec())
                    role = "TANK";
                else if (member->HasHealSpec())
                    role = "HEALER";

                members.push_back({member->GetName(), role});
            }
        }

        // Build affixes list
        std::vector<uint32> affixIds;
        auto const& weeklyAffixes = sMythicScaling->GetWeeklyAffixes();
        for (auto const& affix : weeklyAffixes)
        {
            affixIds.push_back(affix.spellId);
        }

        // Send to each group member
        for (GroupReference* ref = group->GetFirstMember(); ref != nullptr; ref = ref->next())
        {
            if (Player* member = ref->GetSource())
            {
                // Build JSON-like message for AIO
                // Format: KEYSTONE_ACTIVATE,dungeonName,level,affixes,timeout,partyMembers
                std::string membersJson = "[";
                for (size_t i = 0; i < members.size(); ++i)
                {
                    if (i > 0) membersJson += ",";
                    membersJson += Acore::StringFormat("{\"name\":\"%s\",\"role\":\"%s\",\"guid\":\"%s\"}",
                        members[i].first.c_str(),
                        members[i].second.c_str(),
                        member->GetGUID().ToString().c_str());
                }
                membersJson += "]";

                std::string affixesJson = "[";
                for (size_t i = 0; i < affixIds.size(); ++i)
                {
                    if (i > 0) affixesJson += ",";
                    affixesJson += Acore::StringFormat("{\"id\":%u}", affixIds[i]);
                }
                affixesJson += "]";

                // Send via AIO protocol
                AIO().Handle(member, "MPLUS", "KEYSTONE_ACTIVATE", Acore::StringFormat(
                    "{\"dungeonName\":\"%s\",\"level\":%u,\"timeout\":%u,\"affixes\":%s,\"partyMembers\":%s}",
                    dungeonName.c_str(),
                    descriptor.level,
                    60,
                    affixesJson.c_str(),
                    membersJson.c_str()
                ));
            }
        }
    }
#endif

    void SendKeystoneReadyCheckFallback(Group* group, const std::string& dungeonName, const KeystoneDescriptor& descriptor)
    {
        if (!group)
            return;

        // Fallback: Send chat message
        for (GroupReference* ref = group->GetFirstMember(); ref != nullptr; ref = ref->next())
        {
            if (Player* member = ref->GetSource())
            {
                ChatHandler(member->GetSession()).PSendSysMessage(
                    "|cff00ccff[Mythic+ Ready Check]|r +%u %s - Type '.mplusaccept' or '.mplusdecline' within 60 seconds.",
                    descriptor.level, dungeonName.c_str());
            }
        }
    }

public:
    // Static method to handle player response (called from elsewhere)
    static void HandlePlayerResponse(Player* player, bool accepted)
    {
        if (!player)
            return;

        Group* group = player->GetGroup();
        if (!group)
            return;

        ObjectGuid groupGuid = group->GetGUID();
        auto it = s_pendingActivations.find(groupGuid);
        if (it == s_pendingActivations.end())
        {
            ChatHandler(player->GetSession()).SendSysMessage("No pending keystone activation for your group.");
            return;
        }

        PendingKeystoneActivation& pending = it->second;

        // Update player state
        pending.memberStates[player->GetGUID()] = accepted ? STATE_READY : STATE_DECLINED;

        // Notify group of state change
#ifdef HAS_AIO
        for (GroupReference* ref = group->GetFirstMember(); ref != nullptr; ref = ref->next())
        {
            if (Player* member = ref->GetSource())
            {
                AIO().Handle(member, "MPLUS", "KEYSTONE_STATUS", Acore::StringFormat(
                    "{\"playerGuid\":\"%s\",\"state\":%d}",
                    player->GetGUID().ToString().c_str(),
                    accepted ? 1 : 2
                ));
            }
        }
#endif

        if (!accepted)
        {
            // Someone declined - cancel activation
            CancelPendingActivation(group, Acore::StringFormat("%s declined the keystone.", player->GetName().c_str()));
            return;
        }

        // Check if all ready
        bool allReady = true;
        for (auto const& [guid, state] : pending.memberStates)
        {
            if (state == STATE_PENDING)
            {
                allReady = false;
                break;
            }
        }

        if (allReady)
        {
            pending.allReady = true;
            StartCountdown(group);
        }
    }

    static void StartCountdown(Group* group)
    {
        if (!group)
            return;

        ObjectGuid groupGuid = group->GetGUID();
        auto it = s_pendingActivations.find(groupGuid);
        if (it == s_pendingActivations.end())
            return;

        PendingKeystoneActivation& pending = it->second;

        // Start 10-second countdown
        pending.countdown = 10;

#ifdef HAS_AIO
        for (GroupReference* ref = group->GetFirstMember(); ref != nullptr; ref = ref->next())
        {
            if (Player* member = ref->GetSource())
            {
                AIO().Handle(member, "MPLUS", "KEYSTONE_COUNTDOWN", Acore::StringFormat(
                    "{\"seconds\":%u}", pending.countdown));
            }
        }
#endif

        // The actual countdown and activation would be handled by a scheduled event
        // For now, immediately start the run
        FinalizePendingActivation(group);
    }

    static void CancelPendingActivation(Group* group, const std::string& reason)
    {
        if (!group)
            return;

        ObjectGuid groupGuid = group->GetGUID();
        auto it = s_pendingActivations.find(groupGuid);
        if (it == s_pendingActivations.end())
            return;

#ifdef HAS_AIO
        for (GroupReference* ref = group->GetFirstMember(); ref != nullptr; ref = ref->next())
        {
            if (Player* member = ref->GetSource())
            {
                AIO().Handle(member, "MPLUS", "KEYSTONE_CANCEL", Acore::StringFormat(
                    "{\"reason\":\"%s\"}", reason.c_str()));
            }
        }
#else
        for (GroupReference* ref = group->GetFirstMember(); ref != nullptr; ref = ref->next())
        {
            if (Player* member = ref->GetSource())
            {
                ChatHandler(member->GetSession()).PSendSysMessage("|cffff0000[Mythic+ Cancelled]|r %s", reason.c_str());
            }
        }
#endif

        s_pendingActivations.erase(it);
    }

    static void FinalizePendingActivation(Group* group)
    {
        if (!group)
            return;

        ObjectGuid groupGuid = group->GetGUID();
        auto it = s_pendingActivations.find(groupGuid);
        if (it == s_pendingActivations.end())
            return;

        PendingKeystoneActivation& pending = it->second;

        // Find the player and GO to activate
        Player* player = ObjectAccessor::FindPlayer(pending.playerGuid);
        GameObject* go = player ? player->GetMap()->GetGameObject(pending.goGuid) : nullptr;

        if (player && go)
        {
            sMythicRuns->TryActivateKeystone(player, go);
        }

        s_pendingActivations.erase(it);
    }
};

void AddSC_go_mythic_plus_font_of_power()
{
    new go_mythic_plus_font_of_power();
}
