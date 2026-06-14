/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Font of Power GameObject Script
 * Handles keystone activation with ready check support
 *
 * When a player clicks the Font of Power:
 * 1. Validates keystone can be activated
 * 2. Opens the keystone activation flow
 * 3. All required players must accept within timeout
 * 4. Countdown starts when all accept
 * 5. Run begins after countdown
 */

#include "ScriptMgr.h"
#include "ScriptedGossip.h"
#include "Chat.h"
#include "Config.h"
#include "GameObject.h"
#include "GameTime.h"
#include "Group.h"
#include "MapMgr.h"
#include "ObjectAccessor.h"
#include "dc_mythicplus_difficulty_scaling.h"
#include "dc_mythicplus_run_manager.h"
#include "DC/CrossSystem/CrossSystemUtilities.h"
#include "../AddonExtension/dc_addon_namespace.h"
#include "../AddonExtension/dc_addon_mythicplus.h"
#include "Player.h"
#include "StringFormat.h"

#ifdef HAS_AIO
#include "AIO.h"
#endif

#include <cmath>
#include <sstream>

namespace
{
enum FontOfPowerActions : uint32
{
    ACTION_START_RUN     = 1,
    ACTION_START_READY   = 2,  // Start group ready check
    ACTION_CLOSE         = 3,
    ACTION_GM_LEVEL_BASE = 1000
};

// Pending activation state per group, or per solo player when no group exists.
struct PendingKeystoneActivation
{
    ObjectGuid goGuid;
    ObjectGuid playerGuid;
    uint32 mapId = 0;
    uint32 instanceId = 0;
    KeystoneDescriptor keystone;
    std::map<ObjectGuid, int8> memberStates; // 0=pending, 1=ready, 2=declined
    uint32 timeout = 60;
    uint32 startTime = 0;
    bool allReady = false;
    uint8 countdown = 0;
    uint64 countdownStartedMs = 0;
};

std::map<ObjectGuid, PendingKeystoneActivation> s_pendingActivations; // GroupGuid or PlayerGuid -> Activation

constexpr int8 STATE_PENDING  = 0;
constexpr int8 STATE_READY    = 1;
constexpr int8 STATE_DECLINED = 2;

struct ReadyMemberInfo
{
    std::string name;
    std::string role;
    std::string guid;
    bool ready = false;
    bool declined = false;
    bool leader = false;
};

struct DungeonUiInfo
{
    std::string shortName;
    std::string iconPath;
    uint32 baseTimer = 0;
};

bool IsAddonProtocolEnabled()
{
    return sConfigMgr->GetOption<bool>("DC.AddonProtocol.MythicPlus.Enable", true);
}

bool HasKeystoneReadyCheckUiTransport()
{
#ifdef HAS_AIO
    return true;
#else
    return IsAddonProtocolEnabled();
#endif
}

std::string EscapeJson(std::string_view input)
{
    return DarkChaos::CrossSystem::Utils::EscapeJson(input);
}

ObjectGuid GetPendingActivationKey(Player* player)
{
    if (!player)
        return ObjectGuid();

    if (Group* group = player->GetGroup())
        return group->GetGUID();

    return player->GetGUID();
}

std::string GetAffixIconTexture(uint32 affixId)
{
    switch (affixId)
    {
        case 1: return "Interface\\Icons\\Spell_Fire_Immolation";
        case 2: return "Interface\\Icons\\Spell_Frost_ChillingBlast";
        case 3: return "Interface\\Icons\\Spell_Nature_NatureGuardian";
        case 4: return "Interface\\Icons\\Ability_Warrior_BattleShout";
        case 5: return "Interface\\Icons\\Spell_Nature_Earthquake";
        case 6: return "Interface\\Icons\\Spell_Shadow_SoulGem";
        case 7: return "Interface\\Icons\\Spell_Nature_Thorns";
        case 8: return "Interface\\Icons\\Inv_Misc_Volatilefire";
        default: return "Interface\\Icons\\INV_Misc_QuestionMark";
    }
}

std::string GetRoleForPlayer(Player* member)
{
    if (!member)
        return "DPS";

    if (member->HasTankSpec())
        return "TANK";
    if (member->HasHealSpec())
        return "HEALER";

    return "DPS";
}

DungeonUiInfo LoadDungeonUiInfo(uint32 mapId)
{
    DungeonUiInfo info;

    if (QueryResult result = WorldDatabase.Query(
        "SELECT COALESCE(short_name, ''), COALESCE(icon_path, ''), base_timer "
        "FROM dc_mplus_dungeons WHERE dungeon_id = {}",
        mapId))
    {
        Field* fields = result->Fetch();
        info.shortName = fields[0].Get<std::string>();
        info.iconPath = fields[1].Get<std::string>();
        info.baseTimer = fields[2].Get<uint32>();
    }

    return info;
}

uint32 CountReadyMembers(PendingKeystoneActivation const& pending)
{
    uint32 readyCount = 0;
    for (auto const& [_, state] : pending.memberStates)
        if (state == STATE_READY)
            ++readyCount;

    return readyCount;
}

std::vector<ReadyMemberInfo> BuildReadyMembers(Player* activator, Group* group,
    PendingKeystoneActivation const& pending)
{
    std::vector<ReadyMemberInfo> members;
    if (!activator)
        return members;

    if (!group)
    {
        ReadyMemberInfo info;
        info.name = activator->GetName();
        info.role = GetRoleForPlayer(activator);
        info.guid = activator->GetGUID().ToString();
        info.leader = true;

        if (auto itr = pending.memberStates.find(activator->GetGUID());
            itr != pending.memberStates.end())
        {
            info.ready = itr->second == STATE_READY;
            info.declined = itr->second == STATE_DECLINED;
        }

        members.push_back(std::move(info));
        return members;
    }

    members.reserve(pending.memberStates.size());

    for (GroupReference* ref = group->GetFirstMember(); ref != nullptr; ref = ref->next())
    {
        Player* member = ref->GetSource();
        if (!member)
            continue;

        ReadyMemberInfo info;
        info.name = member->GetName();
        info.role = GetRoleForPlayer(member);
        info.guid = member->GetGUID().ToString();
        info.leader = group->IsLeader(member->GetGUID());

        if (auto itr = pending.memberStates.find(member->GetGUID());
            itr != pending.memberStates.end())
        {
            info.ready = itr->second == STATE_READY;
            info.declined = itr->second == STATE_DECLINED;
        }

        members.push_back(std::move(info));
    }

    return members;
}

std::string BuildAffixesJson(
    std::vector<MythicPlusRunManager::WeeklyAffixInfo> const& affixes)
{
    std::ostringstream stream;
    stream << "[";

    for (size_t index = 0; index < affixes.size(); ++index)
    {
        MythicPlusRunManager::WeeklyAffixInfo const& affix = affixes[index];
        if (index)
            stream << ",";

        stream << "{"
            << "\"id\":" << affix.affixId
            << ",\"name\":\"" << EscapeJson(affix.name) << "\""
            << ",\"description\":\"" << EscapeJson(affix.description)
            << "\""
            << ",\"icon\":\"" << EscapeJson(GetAffixIconTexture(affix.affixId))
            << "\""
            << "}";
    }

    stream << "]";
    return stream.str();
}

std::string BuildPartyMembersJson(std::vector<ReadyMemberInfo> const& members)
{
    std::ostringstream stream;
    stream << "[";

    for (size_t index = 0; index < members.size(); ++index)
    {
        ReadyMemberInfo const& member = members[index];
        if (index)
            stream << ",";

        stream << "{"
            << "\"name\":\"" << EscapeJson(member.name) << "\""
            << ",\"role\":\"" << EscapeJson(member.role) << "\""
            << ",\"guid\":\"" << EscapeJson(member.guid) << "\""
            << ",\"ready\":" << (member.ready ? "true" : "false")
            << ",\"declined\":" << (member.declined ? "true" : "false")
            << ",\"leader\":" << (member.leader ? "true" : "false")
            << "}";
    }

    stream << "]";
    return stream.str();
}

#ifdef HAS_AIO
std::string BuildReadyCheckPayload(std::string const& dungeonName, uint32 mapId,
    std::string const& shortName, std::string const& iconPath, uint32 level,
    uint32 timeLimit, uint32 countdown, uint32 healthPct, uint32 damagePct,
    std::string const& affixesJson, std::string const& membersJson,
    uint32 readyCount, uint32 totalCount, bool isLeader, bool allReady)
{
    std::ostringstream stream;
    stream << "{"
        << "\"dungeonName\":\"" << EscapeJson(dungeonName) << "\""
        << ",\"mapId\":" << mapId
        << ",\"level\":" << level
        << ",\"timeLimit\":" << timeLimit
        << ",\"countdown\":" << countdown
        << ",\"healthPct\":" << healthPct
        << ",\"damagePct\":" << damagePct
        << ",\"readyCount\":" << readyCount
        << ",\"totalCount\":" << totalCount
        << ",\"isLeader\":" << (isLeader ? "true" : "false")
        << ",\"allReady\":" << (allReady ? "true" : "false")
        << ",\"affixes\":" << affixesJson
        << ",\"partyMembers\":" << membersJson;

    if (!shortName.empty())
        stream << ",\"shortName\":\"" << EscapeJson(shortName) << "\"";
    if (!iconPath.empty())
        stream << ",\"iconPath\":\"" << EscapeJson(iconPath) << "\"";

    stream << "}";
    return stream.str();
}
#endif

void SendReadyCheckPayload(Player* member, std::string const& dungeonName,
    uint32 mapId, DungeonUiInfo const& uiInfo, uint32 level, uint32 timeLimit,
    uint32 countdown, uint32 healthPct, uint32 damagePct,
    std::string const& affixesJson, std::string const& membersJson,
    uint32 readyCount, uint32 totalCount, bool allReady)
{
    if (!member)
        return;

    bool const isLeader = !member->GetGroup() ||
        member->GetGroup()->IsLeader(member->GetGUID());

#ifdef HAS_AIO
    AIO().Handle(member, "MPLUS", "KEYSTONE_ACTIVATE",
        BuildReadyCheckPayload(dungeonName, mapId, uiInfo.shortName,
            uiInfo.iconPath, level, timeLimit, countdown, healthPct,
            damagePct, affixesJson, membersJson, readyCount, totalCount,
            isLeader, allReady));
#endif

    if (!IsAddonProtocolEnabled())
        return;

    DCAddon::JsonMessage json(DCAddon::Module::MYTHIC_PLUS,
        DCAddon::Opcode::MPlus::SMSG_KEYSTONE_ACTIVATE);
    json.Set("dungeonName", dungeonName);
    json.Set("mapId", static_cast<int32>(mapId));
    json.Set("level", static_cast<int32>(level));
    json.Set("timeLimit", static_cast<int32>(timeLimit));
    json.Set("countdown", static_cast<int32>(countdown));
    json.Set("healthPct", static_cast<int32>(healthPct));
    json.Set("damagePct", static_cast<int32>(damagePct));
    json.Set("readyCount", static_cast<int32>(readyCount));
    json.Set("totalCount", static_cast<int32>(totalCount));
    json.Set("isLeader", isLeader);
    json.Set("allReady", allReady);
    json.Set("affixes", affixesJson);
    json.Set("partyMembers", membersJson);
    if (!uiInfo.shortName.empty())
        json.Set("shortName", uiInfo.shortName);
    if (!uiInfo.iconPath.empty())
        json.Set("iconPath", uiInfo.iconPath);
    json.Send(member);
}

void SendReadyStatusUpdate(PendingKeystoneActivation const& pending,
    Player* actor, bool accepted)
{
    if (!actor)
        return;

    uint32 readyCount = CountReadyMembers(pending);
    uint32 totalCount = static_cast<uint32>(pending.memberStates.size());

    for (auto const& [memberGuid, _] : pending.memberStates)
    {
        if (Player* member = ObjectAccessor::FindConnectedPlayer(memberGuid))
        {
#ifdef HAS_AIO
            AIO().Handle(member, "MPLUS", "KEYSTONE_STATUS", Acore::StringFormat(
                "{{\"playerGuid\":\"{}\",\"playerName\":\"{}\",\"state\":{},\"ready\":{},\"declined\":{},\"allReady\":{},\"readyCount\":{},\"totalCount\":{}}}",
                EscapeJson(actor->GetGUID().ToString()),
                EscapeJson(actor->GetName()),
                accepted ? 1 : 2,
                accepted ? "true" : "false",
                accepted ? "false" : "true",
                pending.allReady ? "true" : "false",
                readyCount,
                totalCount));
#endif

            if (!IsAddonProtocolEnabled())
                continue;

            DCAddon::JsonMessage json(DCAddon::Module::MYTHIC_PLUS,
                DCAddon::Opcode::MPlus::SMSG_KEYSTONE_STATUS);
            json.Set("playerGuid", actor->GetGUID().ToString());
            json.Set("playerName", actor->GetName());
            json.Set("state", static_cast<int32>(accepted ? 1 : 2));
            json.Set("ready", accepted);
            json.Set("declined", !accepted);
            json.Set("allReady", pending.allReady);
            json.Set("readyCount", static_cast<int32>(readyCount));
            json.Set("totalCount", static_cast<int32>(totalCount));
            json.Send(member);
        }
    }
}

void SendCountdownStarted(PendingKeystoneActivation const& pending,
    uint32 seconds)
{
    for (auto const& [memberGuid, _] : pending.memberStates)
    {
        if (Player* member = ObjectAccessor::FindConnectedPlayer(memberGuid))
        {
#ifdef HAS_AIO
            AIO().Handle(member, "MPLUS", "KEYSTONE_COUNTDOWN", Acore::StringFormat(
                "{{\"seconds\":{}}}", seconds));
#endif

            if (!IsAddonProtocolEnabled())
                continue;

            DCAddon::JsonMessage(DCAddon::Module::MYTHIC_PLUS,
                DCAddon::Opcode::MPlus::SMSG_KEYSTONE_COUNTDOWN)
                .Set("seconds", static_cast<int32>(seconds))
                .Send(member);
        }
    }
}

void NotifyPendingCancellation(PendingKeystoneActivation const& pending,
    std::string const& reason)
{
    for (auto const& [memberGuid, _] : pending.memberStates)
    {
        if (Player* member = ObjectAccessor::FindConnectedPlayer(memberGuid))
        {
#ifdef HAS_AIO
            AIO().Handle(member, "MPLUS", "KEYSTONE_CANCEL", Acore::StringFormat(
                "{{\"reason\":\"{}\"}}", EscapeJson(reason)));
#endif

            if (IsAddonProtocolEnabled())
            {
                DCAddon::JsonMessage(DCAddon::Module::MYTHIC_PLUS,
                    DCAddon::Opcode::MPlus::SMSG_KEYSTONE_CANCEL)
                    .Set("reason", reason)
                    .Send(member);
            }

            ChatHandler(member->GetSession()).PSendSysMessage(
                "|cffff0000[Mythic+ Cancelled]|r {}", reason);
        }
    }
}

void CleanupExpiredPendingActivations()
{
    if (s_pendingActivations.empty())
        return;

    uint64 now = GameTime::GetGameTime().count();
    std::vector<ObjectGuid> expiredGroups;
    expiredGroups.reserve(s_pendingActivations.size());

    for (auto const& [groupGuid, pending] : s_pendingActivations)
    {
        if (!pending.startTime)
            continue;

        if (pending.countdownStartedMs)
            continue;

        if (now >= (pending.startTime + pending.timeout))
            expiredGroups.push_back(groupGuid);
    }

    for (ObjectGuid const& groupGuid : expiredGroups)
    {
        auto it = s_pendingActivations.find(groupGuid);
        if (it == s_pendingActivations.end())
            continue;

        NotifyPendingCancellation(it->second, "Keystone ready check timed out.");
        s_pendingActivations.erase(it);

        LOG_INFO("mythic.run", "Ready check timed out for group {}", groupGuid.ToString());
    }
}
}

class go_mythic_plus_font_of_power : public GameObjectScript
{
public:
    go_mythic_plus_font_of_power() : GameObjectScript("go_mythic_plus_font_of_power") { }

    static void CleanupExpiredActivations()
    {
        CleanupExpiredPendingActivations();
    }

    static void ProcessCountdowns()
    {
        if (s_pendingActivations.empty())
            return;

        uint64 nowMs = GameTime::GetGameTimeMS().count();
        std::vector<ObjectGuid> readyToFinalize;

        for (auto const& [groupGuid, pending] : s_pendingActivations)
        {
            if (!pending.countdownStartedMs || pending.countdown == 0)
                continue;

            uint64 durationMs = static_cast<uint64>(pending.countdown) * 1000;
            if (nowMs >= pending.countdownStartedMs + durationMs)
                readyToFinalize.push_back(groupGuid);
        }

        for (ObjectGuid const& groupGuid : readyToFinalize)
            FinalizePendingActivation(groupGuid);
    }

    static void HandlePlayerCancellation(Player* player)
    {
        if (!player)
            return;

        Group* group = player->GetGroup();
        if (group)
        {
            if (group->IsLeader(player->GetGUID()) ||
                group->IsAssistant(player->GetGUID()))
            {
                CancelPendingActivation(group->GetGUID(), Acore::StringFormat(
                    "{} cancelled the keystone.", player->GetName()));
                return;
            }

            HandlePlayerResponse(player, false);
            return;
        }

        CancelPendingActivation(player->GetGUID(), Acore::StringFormat(
            "{} cancelled the keystone.", player->GetName()));
    }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        if (!player || !go)
            return false;

        CleanupExpiredPendingActivations();

        KeystoneDescriptor descriptor;
        std::string error;

        ClearGossipMenuFor(player);

        bool isGameMaster = player->IsGameMaster();

        bool canActivate = sMythicRuns->CanActivateKeystone(player, go,
            descriptor, error);

        bool canActivateForced = false;
        if (isGameMaster)
        {
            KeystoneDescriptor gmDescriptor;
            std::string gmError;
            canActivateForced = sMythicRuns->CanActivateKeystone(player, go,
                gmDescriptor, gmError,
                MythicPlusConstants::MIN_KEYSTONE_LEVEL);

            if (!canActivate && !canActivateForced)
                error = gmError;
        }

        if (!canActivate && !canActivateForced)
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
        bool canLeadActivation = !hasGroup ||
            group->IsLeader(player->GetGUID()) ||
            group->IsAssistant(player->GetGUID());

        // Default path: use the Mythic+ activation flow directly instead of
        // surfacing the legacy gossip menu. Keep the forced GM level gossip
        // only as a fallback when no real activation is available.
        if (canActivate && HasKeystoneReadyCheckUiTransport())
        {
            if (!canLeadActivation)
            {
                ChatHandler(player->GetSession()).SendSysMessage(
                    "Only the group leader or assistant can start a ready check.");
                return true;
            }

            CloseGossipMenuFor(player);

            InitiateGroupReadyCheck(player, go);
            return true;
        }

        if (canActivate)
        {
            if (hasGroup)
            {
                if (canLeadActivation)
                {
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
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                        "|cffff0000Only the group leader or assistant can start the keystone.|r",
                        GOSSIP_SENDER_MAIN, ACTION_CLOSE);
                }
            }
            else
            {
                AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
                    Acore::StringFormat("Open Keystone Activation: +{} {}", descriptor.level, dungeonName),
                    GOSSIP_SENDER_MAIN, ACTION_START_READY);
            }
        }

        if (isGameMaster && canActivateForced && !canActivate)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                "|cffff00ffGM override active: forced key level, inventory key not consumed.|r",
                GOSSIP_SENDER_MAIN, ACTION_CLOSE);

            for (uint8 level = MythicPlusConstants::MIN_KEYSTONE_LEVEL;
                 level <= MythicPlusConstants::MAX_KEYSTONE_LEVEL;
                 ++level)
            {
                AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
                    Acore::StringFormat("|cffff00ff[GM]|r Start {}",
                        MythicPlusConstants::GetKeystoneColoredName(level)),
                    GOSSIP_SENDER_MAIN,
                    ACTION_GM_LEVEL_BASE + level);
            }
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

        if (action >= ACTION_GM_LEVEL_BASE)
        {
            if (!player->IsGameMaster())
                return true;

            uint8 level = static_cast<uint8>(action - ACTION_GM_LEVEL_BASE);
            constexpr uint8 MAX_FORCED_KEYSTONE_LEVEL = 30;

            if (level < MythicPlusConstants::MIN_KEYSTONE_LEVEL ||
                level > MAX_FORCED_KEYSTONE_LEVEL)
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "Invalid key level {}. Allowed range is {} to {}.",
                    static_cast<uint32>(level),
                    MythicPlusConstants::MIN_KEYSTONE_LEVEL,
                    MAX_FORCED_KEYSTONE_LEVEL);
                return true;
            }

            LOG_INFO("mythic.run", "GM {} selected forced keystone level +{} at Font of Power",
                     player->GetGUID().GetCounter(), uint32(level));
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cff66ccff[M+ Debug]|r GM forced key selected: +{} (inventory ignored)",
                uint32(level));

            sMythicRuns->TryActivateKeystone(player, go, level);
            return true;
        }

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

        CleanupExpiredPendingActivations();

        Group* group = player->GetGroup();

        // Check if leader or assistant
        if (group && !group->IsLeader(player->GetGUID()) &&
            !group->IsAssistant(player->GetGUID()))
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
        ObjectGuid activationKey = GetPendingActivationKey(player);
        PendingKeystoneActivation& pending = s_pendingActivations[activationKey];
        pending.goGuid = go->GetGUID();
        pending.playerGuid = player->GetGUID();
        pending.mapId = go->GetMapId();
        pending.instanceId = go->GetInstanceId();
        pending.keystone = descriptor;
        pending.startTime = GameTime::GetGameTime().count();
        pending.timeout = 60;
        pending.allReady = false;
        pending.countdown = 0;
        pending.countdownStartedMs = 0;
        pending.memberStates.clear();

        // Initialize all member states to pending.
        if (!group)
        {
            pending.memberStates[player->GetGUID()] = STATE_PENDING;
        }
        else
        {
            for (GroupReference* ref = group->GetFirstMember(); ref != nullptr; ref = ref->next())
            {
                if (Player* member = ref->GetSource())
                {
                    pending.memberStates[member->GetGUID()] =
                        member->GetGUID() == player->GetGUID() ?
                        STATE_READY : STATE_PENDING;
                }
            }
        }

        if (HasKeystoneReadyCheckUiTransport())
            SendKeystoneReadyCheck(player, group, dungeonName, descriptor);
        else
            SendKeystoneReadyCheckFallback(player, group, dungeonName,
                descriptor);

        if (group)
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "Keystone ready check initiated for +{} {}. Waiting for group response...",
                descriptor.level, dungeonName);
        }
        else
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "Keystone activation opened for +{} {}.",
                descriptor.level, dungeonName);
        }
    }

    void SendKeystoneReadyCheck(Player* activator, Group* group,
        const std::string& dungeonName, const KeystoneDescriptor& descriptor)
    {
        if (!activator)
            return;

        auto pendingItr = s_pendingActivations.find(
            GetPendingActivationKey(activator));
        if (pendingItr == s_pendingActivations.end())
            return;

        PendingKeystoneActivation const& pending = pendingItr->second;

        std::vector<ReadyMemberInfo> members = BuildReadyMembers(activator,
            group, pending);

        // Build affixes list from the same resolver the run manager uses.
        uint32 seasonId = descriptor.seasonId ? descriptor.seasonId : sMythicRuns->GetCurrentSeasonId();
        std::vector<MythicPlusRunManager::WeeklyAffixInfo> affixes;
        if (sConfigMgr->GetOption<bool>("MythicPlus.Affixes.Enabled", false))
            affixes = sMythicRuns->GetWeeklyAffixInfo(seasonId);

        DungeonUiInfo uiInfo = LoadDungeonUiInfo(descriptor.mapId);
        uint32 countdownDuration = sConfigMgr->GetOption<uint32>("MythicPlus.CountdownDuration", 10);
        uint32 timeLimit = uiInfo.baseTimer ? uiInfo.baseTimer : 1800;

        float hpMult = 1.0f;
        float damageMult = 1.0f;
        sMythicScaling->CalculateMythicPlusMultipliers(descriptor.level, hpMult, damageMult);
        uint32 healthPct = static_cast<uint32>(std::max<int32>(0,
            static_cast<int32>(std::lround((hpMult - 1.0f) * 100.0f))));
        uint32 damagePct = static_cast<uint32>(std::max<int32>(0,
            static_cast<int32>(std::lround((damageMult - 1.0f) * 100.0f))));

        std::string membersJson = BuildPartyMembersJson(members);
        std::string affixesJson = BuildAffixesJson(affixes);
        uint32 readyCount = CountReadyMembers(pending);
        uint32 totalCount = static_cast<uint32>(pending.memberStates.size());

        if (!group)
        {
            SendReadyCheckPayload(activator, dungeonName, descriptor.mapId,
                uiInfo, descriptor.level, timeLimit, countdownDuration,
                healthPct, damagePct, affixesJson, membersJson,
                readyCount, totalCount, pending.allReady);
            return;
        }

        // Send to each group member
        for (GroupReference* ref = group->GetFirstMember(); ref != nullptr; ref = ref->next())
        {
            if (Player* member = ref->GetSource())
            {
                SendReadyCheckPayload(member, dungeonName, descriptor.mapId,
                    uiInfo, descriptor.level, timeLimit, countdownDuration,
                    healthPct, damagePct, affixesJson, membersJson,
                    readyCount, totalCount, pending.allReady);
            }
        }
    }

    void SendKeystoneReadyCheckFallback(Player* activator, Group* group,
        const std::string& dungeonName, const KeystoneDescriptor& descriptor)
    {
        if (!activator)
            return;

        if (!group)
        {
            ChatHandler(activator->GetSession()).PSendSysMessage(
                "|cff00ccff[Mythic+ Ready Check]|r +{} {} - Type '.mplusaccept' or '.mplusdecline' within 60 seconds.",
                descriptor.level, dungeonName);
            return;
        }

        // Fallback: Send chat message
        for (GroupReference* ref = group->GetFirstMember(); ref != nullptr; ref = ref->next())
        {
            if (Player* member = ref->GetSource())
            {
                ChatHandler(member->GetSession()).PSendSysMessage(
                    "|cff00ccff[Mythic+ Ready Check]|r +{} {} - Type '.mplusaccept' or '.mplusdecline' within 60 seconds.",
                    descriptor.level, dungeonName);
            }
        }
    }

public:
    // Static method to handle player response (called from elsewhere)
    static void HandlePlayerResponse(Player* player, bool accepted)
    {
        if (!player)
            return;

        CleanupExpiredPendingActivations();

        ObjectGuid activationKey = GetPendingActivationKey(player);
        auto it = s_pendingActivations.find(activationKey);
        if (it == s_pendingActivations.end())
        {
            ChatHandler(player->GetSession()).SendSysMessage(
                "No pending keystone activation was found.");
            return;
        }

        PendingKeystoneActivation& pending = it->second;

        // Update player state
        auto memberIt = pending.memberStates.find(player->GetGUID());
        if (memberIt == pending.memberStates.end())
        {
            ChatHandler(player->GetSession()).SendSysMessage(
                "You are not part of this ready check.");
            return;
        }

        memberIt->second = accepted ? STATE_READY : STATE_DECLINED;

        // Notify group of state change
        SendReadyStatusUpdate(pending, player, accepted);

        if (!accepted)
        {
            // Someone declined - cancel activation
            CancelPendingActivation(activationKey, Acore::StringFormat(
                "{} declined the keystone.", player->GetName()));
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
            SendReadyStatusUpdate(pending, player, true);
            FinalizePendingActivation(activationKey);
        }
    }

    static void StartCountdown(ObjectGuid const& activationKey)
    {
        auto it = s_pendingActivations.find(activationKey);
        if (it == s_pendingActivations.end())
            return;

        PendingKeystoneActivation& pending = it->second;

        // Start 10-second countdown
        pending.countdown = static_cast<uint8>(sConfigMgr->GetOption<uint32>(
            "MythicPlus.CountdownDuration", 10));
        pending.countdownStartedMs = GameTime::GetGameTimeMS().count();
        pending.startTime = 0;

        SendCountdownStarted(pending, pending.countdown);
    }

    static void CancelPendingActivation(ObjectGuid const& activationKey,
        const std::string& reason)
    {
        auto it = s_pendingActivations.find(activationKey);
        if (it == s_pendingActivations.end())
            return;

        NotifyPendingCancellation(it->second, reason);

        s_pendingActivations.erase(it);
    }

    static void FinalizePendingActivation(Group* group)
    {
        if (!group)
            return;

        FinalizePendingActivation(group->GetGUID());
    }

    static void FinalizePendingActivation(ObjectGuid const& groupGuid)
    {
        auto it = s_pendingActivations.find(groupGuid);
        if (it == s_pendingActivations.end())
            return;

        PendingKeystoneActivation& pending = it->second;

        // Find the player and GO to activate
        Map* map = pending.mapId ? sMapMgr->FindMap(pending.mapId, pending.instanceId) : nullptr;
        Player* player = map ? ObjectAccessor::GetPlayer(map, pending.playerGuid) : nullptr;
        GameObject* go = map ? map->GetGameObject(pending.goGuid) : (player ? player->GetMap()->GetGameObject(pending.goGuid) : nullptr);

        if (player && go)
        {
            if (pending.keystone.level >= MythicPlusConstants::MIN_KEYSTONE_LEVEL)
                sMythicRuns->TryActivateKeystone(player, go, 0, pending.keystone.level);
            else
                sMythicRuns->TryActivateKeystone(player, go);
        }

        s_pendingActivations.erase(it);
    }
};

using namespace Acore::ChatCommands;

namespace DCAddon::MythicPlus
{
void HandleKeystoneActivationResponse(Player* player, bool accepted)
{
    go_mythic_plus_font_of_power::HandlePlayerResponse(player, accepted);
}

void HandleKeystoneActivationCancel(Player* player)
{
    go_mythic_plus_font_of_power::HandlePlayerCancellation(player);
}
}

class mythic_plus_readycheck_commandscript : public CommandScript
{
public:
    mythic_plus_readycheck_commandscript() : CommandScript("mythic_plus_readycheck_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandTable =
        {
            { "mplusaccept", HandleMPlusAcceptCommand, SEC_PLAYER, Console::No },
            { "mplusdecline", HandleMPlusDeclineCommand, SEC_PLAYER, Console::No }
        };

        return commandTable;
    }

    static bool HandleMPlusAcceptCommand(ChatHandler* handler)
    {
        Player* player = handler ? handler->GetPlayer() : nullptr;
        if (!player)
            return false;

        go_mythic_plus_font_of_power::HandlePlayerResponse(player, true);
        return true;
    }

    static bool HandleMPlusDeclineCommand(ChatHandler* handler)
    {
        Player* player = handler ? handler->GetPlayer() : nullptr;
        if (!player)
            return false;

        go_mythic_plus_font_of_power::HandlePlayerResponse(player, false);
        return true;
    }
};

class mythic_plus_readycheck_worldscript : public WorldScript
{
public:
    mythic_plus_readycheck_worldscript() : WorldScript("mythic_plus_readycheck_worldscript") { }

    void OnUpdate(uint32 diff) override
    {
        _timeoutSweepTimer += diff;
        if (_timeoutSweepTimer < 1000)
            return;

        _timeoutSweepTimer = 0;
        go_mythic_plus_font_of_power::CleanupExpiredActivations();
        go_mythic_plus_font_of_power::ProcessCountdowns();
    }

private:
    uint32 _timeoutSweepTimer = 0;
};

void AddSC_go_mythic_plus_font_of_power()
{
    new go_mythic_plus_font_of_power();
    new mythic_plus_readycheck_commandscript();
    new mythic_plus_readycheck_worldscript();
}
