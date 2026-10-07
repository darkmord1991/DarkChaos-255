/*
 * Dark Chaos - Prestige System Addon Handler
 * ============================================
 *
 * Server-side handler for the DC-Prestige addon module.
 * Provides prestige level information, stat bonuses, and progress data via DCAddonProtocol.
 *
 * Features:
 * - Player prestige level and progress info
 * - Stat bonus breakdown per prestige level
 * - Requirements to prestige
 * - Prestige level-up notifications
 *
 * Message Format:
 * - JSON format: PRES|OPCODE|J|{json}
 *
 * Opcodes (from DCAddonNamespace.h):
 * - CMSG: 0x01 (GET_INFO), 0x02 (GET_BONUSES), 0x03 (GET_TALENTS), 0x04 (LEARN_TALENT {id}),
 *         0x05 (RESET_TALENTS), 0x06 (GET_CHALLENGES), 0x07 (GET_REWARDS),
 *         0x08 (CLAIM_REWARD {threshold}), 0x09 (APPLY_TALENTS {ranks:[{id,rank}]})
 * - SMSG: 0x10 (INFO), 0x11 (BONUSES), 0x12 (LEVEL_UP), 0x13 (TALENTS), 0x14 (TALENT_RESULT),
 *         0x15 (CHALLENGES), 0x16 (REWARDS), 0x17 (CHALLENGE_EARNED)
 *
 * Integrates with dc_prestige_system.cpp for prestige data.
 *
 * Copyright (C) 2025 DarkChaos Development Team
 */

#include "dc_addon_namespace.h"
#include "ScriptMgr.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "WorldSession.h"
#include "WorldPacket.h"
#include "Opcodes.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Config.h"
#include "World.h"
#include "DC/Progression/Prestige/dc_prestige_api.h"
#include "ObjectMgr.h"
#include <unordered_set>

namespace DCPrestigeAddon
{
    // Module id + opcodes are sourced from the canonical registry in
    // dc_addon_namespace.h so the two can never drift (previously these were
    // hand-copied literal constants kept in sync by comment).
    constexpr char const* MODULE = DCAddon::Module::PRESTIGE;

    namespace Opcode
    {
        // Client -> Server
        constexpr uint8 CMSG_GET_INFO              = DCAddon::Opcode::Prestige::CMSG_GET_INFO;
        constexpr uint8 CMSG_GET_BONUSES           = DCAddon::Opcode::Prestige::CMSG_GET_BONUSES;
        constexpr uint8 CMSG_GET_TALENTS           = DCAddon::Opcode::Prestige::CMSG_GET_TALENTS;
        constexpr uint8 CMSG_LEARN_TALENT          = DCAddon::Opcode::Prestige::CMSG_LEARN_TALENT;
        constexpr uint8 CMSG_RESET_TALENTS         = DCAddon::Opcode::Prestige::CMSG_RESET_TALENTS;
        constexpr uint8 CMSG_GET_CHALLENGES        = DCAddon::Opcode::Prestige::CMSG_GET_CHALLENGES;
        constexpr uint8 CMSG_GET_REWARDS           = DCAddon::Opcode::Prestige::CMSG_GET_REWARDS;
        constexpr uint8 CMSG_CLAIM_REWARD          = DCAddon::Opcode::Prestige::CMSG_CLAIM_REWARD;
        constexpr uint8 CMSG_APPLY_TALENTS         = DCAddon::Opcode::Prestige::CMSG_APPLY_TALENTS;

        // Server -> Client
        constexpr uint8 SMSG_INFO                  = DCAddon::Opcode::Prestige::SMSG_INFO;
        constexpr uint8 SMSG_BONUSES               = DCAddon::Opcode::Prestige::SMSG_BONUSES;
        constexpr uint8 SMSG_LEVEL_UP              = DCAddon::Opcode::Prestige::SMSG_LEVEL_UP;
        constexpr uint8 SMSG_TALENTS               = DCAddon::Opcode::Prestige::SMSG_TALENTS;
        constexpr uint8 SMSG_TALENT_RESULT         = DCAddon::Opcode::Prestige::SMSG_TALENT_RESULT;
        constexpr uint8 SMSG_CHALLENGES            = DCAddon::Opcode::Prestige::SMSG_CHALLENGES;
        constexpr uint8 SMSG_REWARDS               = DCAddon::Opcode::Prestige::SMSG_REWARDS;
        constexpr uint8 SMSG_CHALLENGE_EARNED      = DCAddon::Opcode::Prestige::SMSG_CHALLENGE_EARNED;
    }

    // Configuration
    namespace Config
    {
        constexpr char const* CANONICAL_ENABLED = "DC.AddonProtocol.Prestige.Enable";
    }

    // =======================================================================
    // Native transport bridge (CMSG_REQUEST_PRESTIGE / SMSG_PRESTIGE). Falls
    // back to the addon (chat) protocol when PRESTIGE_NATIVE is not negotiated.
    // =======================================================================
    namespace BridgeOpcode
    {
        enum : uint16
        {
            CMSG_REQUEST_PRESTIGE = ::CMSG_REQUEST_PRESTIGE,
            SMSG_PRESTIGE         = ::SMSG_PRESTIGE,
        };
    }

    static DCAddon::TransportPolicyDecision ResolvePrestigeTransport(Player* player)
    {
        DCAddon::TransportPolicyRequest request;
        request.featureName = "prestige";
        request.nativeCapability =
            DCAddon::ProtocolVersion::Capability::PRESTIGE_NATIVE;
        return DCAddon::ResolveTransportPolicy(player, request);
    }

    static void SendNativePrestigePayload(Player* player, uint8 logicalOpcode,
        std::string const& payload)
    {
        if (!player || !player->GetSession() || payload.empty())
            return;

        WorldPacket data(BridgeOpcode::SMSG_PRESTIGE,
            sizeof(uint32) + payload.size() + 1);
        data << uint32(logicalOpcode);
        data << payload;
        player->GetSession()->SendPacket(&data);

        std::string preview = "logical="
            + std::to_string(static_cast<uint32>(logicalOpcode))
            + "|bytes=" + std::to_string(payload.size());
        DCAddon::LogNativeS2CMessage(player, MODULE, logicalOpcode,
            BridgeOpcode::SMSG_PRESTIGE, data.size(), preview, true, 0);
    }

    // Transport-aware send: native dedicated opcode when negotiated and the
    // payload fits the client's reader, else addon.
    static void SendPrestigeMessage(Player* player,
        DCAddon::JsonMessage const& msg)
    {
        if (ResolvePrestigeTransport(player).UsesNative())
        {
            std::string const payload = msg.Encode();
            if (DCAddon::NativePayloadFits(player, payload.size(),
                    DCAddon::LegacyNativePayloadMax::PRESTIGE))
            {
                SendNativePrestigePayload(player, msg.GetOpcode(), payload);
                return;
            }
        }

        msg.Send(player);
    }

    // =======================================================================
    // Handler Functions
    // =======================================================================

    /**
     * Send player's prestige information
     * JSON Response:
     * {
     *   "enabled": bool,
     *   "prestigeLevel": uint32,
     *   "maxPrestigeLevel": uint32,
     *   "requiredLevel": uint32,
     *   "currentLevel": uint32,
     *   "canPrestige": bool,
     *   "statBonusPercent": uint32,
     *   "totalBonusPercent": uint32,
     *   "totalPrestiges": uint32,
     *   "lastPrestigeTime": uint32
     * }
     */
    void SendPrestigeInfo(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        // Async: prestige counters must not block the world thread on panel open.
        ObjectGuid const playerGuid = player->GetGUID();
        DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(Acore::StringFormat(
            "SELECT total_prestiges, last_prestige_time FROM dc_character_prestige WHERE guid = {}",
            playerGuid.GetCounter()))
            .WithCallback([playerGuid](QueryResult result)
        {
            Player* player = ObjectAccessor::FindPlayer(playerGuid);
            if (!player || !player->GetSession())
                return;

            uint32 totalPrestiges = 0;
            uint64 lastPrestigeTime = 0;
            if (result)
            {
                Field* fields = result->Fetch();
                totalPrestiges = fields[0].Get<uint32>();
                lastPrestigeTime = fields[1].Get<uint64>();
            }

            uint32 prestigeLevel = PrestigeAPI::GetPrestigeLevel(player);
            uint32 statBonusPercent = PrestigeAPI::GetStatBonusPercent();

            DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_INFO);
            msg.Set("enabled", PrestigeAPI::IsEnabled());
            msg.Set("prestigeLevel", prestigeLevel);
            msg.Set("maxPrestigeLevel", PrestigeAPI::GetMaxPrestigeLevel());
            msg.Set("requiredLevel", PrestigeAPI::GetRequiredLevel());
            msg.Set("currentLevel", player->GetLevel());
            msg.Set("canPrestige", PrestigeAPI::CanPrestige(player));
            msg.Set("statBonusPercent", statBonusPercent);
            msg.Set("totalBonusPercent", prestigeLevel * statBonusPercent);
            msg.Set("totalPrestiges", totalPrestiges);
            msg.Set("lastPrestigeTime", static_cast<uint32>(lastPrestigeTime));

            PrestigeAPI::PrestigeTalentSnapshot talents = PrestigeAPI::GetTalentSnapshot(player);
            msg.Set("talentsEnabled", PrestigeAPI::IsTalentsEnabled());
            msg.Set("talentPoints", talents.accountPoints);
            msg.Set("talentUnspent", talents.spendCap - talents.spent);

            SendPrestigeMessage(player, msg);
        }));
    }

    /**
     * Send stat bonuses breakdown
     * JSON Response:
     * {
     *   "prestigeLevel": uint32,
     *   "bonusPerLevel": uint32,
     *   "totalBonus": uint32,
     *   "bonuses": [
     *     { "level": 1, "bonus": 1, "cumulative": 1 },
     *     { "level": 2, "bonus": 1, "cumulative": 2 },
     *     ...
     *   ],
     *   "nextLevelBonus": uint32 (0 if at max)
     * }
     */
    void SendBonusesBreakdown(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        uint32 prestigeLevel = PrestigeAPI::GetPrestigeLevel(player);
        uint32 maxPrestigeLevel = PrestigeAPI::GetMaxPrestigeLevel();
        uint32 bonusPerLevel = PrestigeAPI::GetStatBonusPercent();
        uint32 totalBonus = prestigeLevel * bonusPerLevel;

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_BONUSES);
        msg.Set("prestigeLevel", prestigeLevel);
        msg.Set("bonusPerLevel", bonusPerLevel);
        msg.Set("totalBonus", totalBonus);

        // Build bonuses array as a real JSON array. Passing a pre-built string
        // through Set(key, std::string) delivered it to clients as a quoted string.
        DCAddon::JsonValue bonuses;
        bonuses.SetArray(maxPrestigeLevel);
        for (uint32 i = 1; i <= maxPrestigeLevel; ++i)
        {
            DCAddon::JsonValue bonus;
            bonus.SetObject();
            bonus.Set("level", DCAddon::JsonValue(i));
            bonus.Set("bonus", DCAddon::JsonValue(bonusPerLevel));
            bonus.Set("cumulative", DCAddon::JsonValue(i * bonusPerLevel));
            bonus.Set("unlocked", DCAddon::JsonValue(i <= prestigeLevel));
            bonuses.Push(std::move(bonus));
        }

        msg.Set("bonuses", std::move(bonuses));
        msg.Set("nextLevelBonus", prestigeLevel < maxPrestigeLevel ? (prestigeLevel + 1) * bonusPerLevel : 0);
        msg.Set("atMaxPrestige", prestigeLevel >= maxPrestigeLevel);

        SendPrestigeMessage(player, msg);
    }

    /**
     * Send the prestige talent panel: tree + talent definitions and this
     * character's allocation.
     * JSON Response:
     * {
     *   "enabled": bool, "loaded": bool,
     *   "prestigePoints": uint32, "challengePoints": uint32, "accountPoints": uint32,
     *   "spendCap": uint32, "spent": uint32, "unspent": uint32,
     *   "resetCost": uint32 (copper),
     *   "trees": [ { "id", "name", "icon", "spent" } ],
     *   "talents": [ { "id", "tree", "row", "col", "maxRank", "rank", "prereqs": [id...],
     *                  "name", "desc", "value", "icon" } ]
     * }
     */
    void SendTalents(Player* player)
    {
        if (!player || !player->GetSession())
            return;

        PrestigeAPI::PrestigeTalentSnapshot snapshot = PrestigeAPI::GetTalentSnapshot(player);

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_TALENTS);
        msg.Set("enabled", PrestigeAPI::IsTalentsEnabled());
        msg.Set("loaded", snapshot.loaded);
        msg.Set("prestigePoints", snapshot.prestigePoints);
        msg.Set("challengePoints", snapshot.challengePoints);
        msg.Set("accountPoints", snapshot.accountPoints);
        msg.Set("spendCap", snapshot.spendCap);
        msg.Set("spent", snapshot.spent);
        msg.Set("unspent", snapshot.spendCap - snapshot.spent);
        msg.Set("resetCost", PrestigeAPI::GetTalentResetCost());

        DCAddon::JsonValue trees;
        trees.SetArray(PrestigeAPI::MAX_PRESTIGE_TREES);
        for (uint8 tree = 0; tree < PrestigeAPI::MAX_PRESTIGE_TREES; ++tree)
        {
            DCAddon::JsonValue entry;
            entry.SetObject();
            entry.Set("id", DCAddon::JsonValue(uint32(tree)));
            entry.Set("name", DCAddon::JsonValue(PrestigeAPI::GetTalentTreeName(tree)));
            entry.Set("icon", DCAddon::JsonValue(PrestigeAPI::GetTalentTreeIcon(tree)));
            entry.Set("spent", DCAddon::JsonValue(snapshot.treeSpent[tree]));
            trees.Push(std::move(entry));
        }
        msg.Set("trees", std::move(trees));

        auto const& definitions = PrestigeAPI::GetTalentDefinitions();
        DCAddon::JsonValue talents;
        talents.SetArray(definitions.size());
        for (PrestigeAPI::PrestigeTalentDef const& def : definitions)
        {
            uint32 rank = 0;
            for (auto const& [id, r] : snapshot.ranks)
                if (id == def.id)
                    rank = r;

            DCAddon::JsonValue entry;
            entry.SetObject();
            entry.Set("id", DCAddon::JsonValue(uint32(def.id)));
            entry.Set("tree", DCAddon::JsonValue(uint32(def.tree)));
            entry.Set("row", DCAddon::JsonValue(uint32(def.row)));
            entry.Set("col", DCAddon::JsonValue(uint32(def.column)));
            entry.Set("maxRank", DCAddon::JsonValue(uint32(def.maxRank)));
            entry.Set("rank", DCAddon::JsonValue(rank));
            DCAddon::JsonValue prereqs;
            prereqs.SetArray(PrestigeAPI::MAX_PRESTIGE_TALENT_PREREQS);
            for (uint16 prereq : def.prereqs)
                if (prereq)
                    prereqs.Push(DCAddon::JsonValue(uint32(prereq)));
            entry.Set("prereqs", std::move(prereqs));
            entry.Set("name", DCAddon::JsonValue(def.name));
            entry.Set("desc", DCAddon::JsonValue(def.description));
            entry.Set("value", DCAddon::JsonValue(double(def.valuePerRank)));
            entry.Set("icon", DCAddon::JsonValue(def.icon));
            talents.Push(std::move(entry));
        }
        msg.Set("talents", std::move(talents));

        SendPrestigeMessage(player, msg);
    }

    /**
     * Challenges: achievements that add points to the account pool.
     * { "loaded", "prestigePoints", "challengePoints", "accountPoints",
     *   "challenges": [ { "id", "points", "category", "completed" } ] }
     */
    static void SendChallenges(Player* player)
    {
        PrestigeAPI::PrestigeTalentSnapshot snapshot = PrestigeAPI::GetTalentSnapshot(player);
        std::unordered_set<uint32> const completed(snapshot.completedChallenges.begin(), snapshot.completedChallenges.end());

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_CHALLENGES);
        msg.Set("loaded", snapshot.loaded);
        msg.Set("prestigePoints", snapshot.prestigePoints);
        msg.Set("challengePoints", snapshot.challengePoints);
        msg.Set("accountPoints", snapshot.accountPoints);

        auto const& definitions = PrestigeAPI::GetChallengeDefinitions();
        DCAddon::JsonValue challenges;
        challenges.SetArray(definitions.size());
        for (PrestigeAPI::PrestigeChallengeDef const& def : definitions)
        {
            DCAddon::JsonValue entry;
            entry.SetObject();
            entry.Set("id", DCAddon::JsonValue(def.achievementId));
            entry.Set("points", DCAddon::JsonValue(def.points));
            entry.Set("category", DCAddon::JsonValue(def.category));
            entry.Set("completed", DCAddon::JsonValue(completed.count(def.achievementId) > 0));
            challenges.Push(std::move(entry));
        }
        msg.Set("challenges", std::move(challenges));

        SendPrestigeMessage(player, msg);
    }

    /**
     * Reward track: cosmetic rewards unlocked by the account point total.
     * { "loaded", "accountPoints",
     *   "rewards": [ { "threshold", "item", "count", "type", "name", "quality", "claimed" } ] }
     */
    static void SendRewards(Player* player)
    {
        PrestigeAPI::PrestigeTalentSnapshot snapshot = PrestigeAPI::GetTalentSnapshot(player);
        std::unordered_set<uint32> const claimed(snapshot.claimedRewards.begin(), snapshot.claimedRewards.end());

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_REWARDS);
        msg.Set("loaded", snapshot.loaded);
        msg.Set("accountPoints", snapshot.accountPoints);

        auto const& definitions = PrestigeAPI::GetRewardDefinitions();
        DCAddon::JsonValue rewards;
        rewards.SetArray(definitions.size());
        for (PrestigeAPI::PrestigeRewardDef const& def : definitions)
        {
            ItemTemplate const* proto = sObjectMgr->GetItemTemplate(def.itemEntry);

            DCAddon::JsonValue entry;
            entry.SetObject();
            entry.Set("threshold", DCAddon::JsonValue(def.threshold));
            entry.Set("item", DCAddon::JsonValue(def.itemEntry));
            entry.Set("count", DCAddon::JsonValue(def.itemCount));
            entry.Set("type", DCAddon::JsonValue(def.rewardType));
            entry.Set("name", DCAddon::JsonValue(proto ? proto->Name1 : std::string()));
            entry.Set("quality", DCAddon::JsonValue(proto ? proto->Quality : 1u));
            entry.Set("claimed", DCAddon::JsonValue(claimed.count(def.threshold) > 0));
            rewards.Push(std::move(entry));
        }
        msg.Set("rewards", std::move(rewards));

        SendPrestigeMessage(player, msg);
    }

    void NotifyChallengeEarned(Player* player, uint32 achievementId, uint32 points, uint32 accountPoints)
    {
        if (!player || !player->GetSession())
            return;

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_CHALLENGE_EARNED);
        msg.Set("id", achievementId);
        msg.Set("points", points);
        msg.Set("accountPoints", accountPoints);
        SendPrestigeMessage(player, msg);
    }

    static void SendTalentResult(Player* player, char const* action, PrestigeAPI::PrestigeTalentResult result)
    {
        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_TALENT_RESULT);
        msg.Set("ok", result == PrestigeAPI::PrestigeTalentResult::Ok);
        msg.Set("action", action);
        msg.Set("error", PrestigeAPI::GetTalentResultText(result));
        SendPrestigeMessage(player, msg);
    }

    // =======================================================================
    // Message Handlers
    // =======================================================================

    void HandleGetInfo(Player* player, DCAddon::ParsedMessage const& /*msg*/)
    {
        if (!player)
            return;

        SendPrestigeInfo(player);
    }

    void HandleGetBonuses(Player* player, DCAddon::ParsedMessage const& /*msg*/)
    {
        if (!player)
            return;

        SendBonusesBreakdown(player);
    }

    void HandleGetTalents(Player* player, DCAddon::ParsedMessage const& /*msg*/)
    {
        if (!player)
            return;

        // Login loads talents asynchronously; if the panel opens first, the
        // talents script pushes SMSG_TALENTS as soon as the data arrives.
        if (!PrestigeAPI::GetTalentSnapshot(player).loaded)
            PrestigeAPI::QueueTalentPush(player);

        SendTalents(player);
    }

    void HandleLearnTalent(Player* player, DCAddon::ParsedMessage const& msg)
    {
        if (!player)
            return;

        uint32 talentId = 0;
        if (DCAddon::IsJsonMessage(msg))
        {
            DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
            if (json["id"].IsNumber())
                talentId = json["id"].AsUInt32();
        }

        PrestigeAPI::PrestigeTalentResult result = talentId <= 0xFFFF
            ? PrestigeAPI::LearnTalent(player, static_cast<uint16>(talentId))
            : PrestigeAPI::PrestigeTalentResult::UnknownTalent;

        SendTalentResult(player, "learn", result);
        if (result == PrestigeAPI::PrestigeTalentResult::Ok)
            SendTalents(player);
    }

    void HandleApplyTalents(Player* player, DCAddon::ParsedMessage const& msg)
    {
        if (!player)
            return;

        std::vector<std::pair<uint16, uint8>> target;
        if (DCAddon::IsJsonMessage(msg))
        {
            DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
            if (json["ranks"].IsArray())
            {
                for (DCAddon::JsonValue const& entry : json["ranks"].AsArray())
                {
                    if (!entry["id"].IsNumber() || !entry["rank"].IsNumber())
                        continue;

                    uint32 id = entry["id"].AsUInt32();
                    uint32 rank = entry["rank"].AsUInt32();
                    if (id > 0xFFFF || rank > 0xFF)
                    {
                        SendTalentResult(player, "apply", PrestigeAPI::PrestigeTalentResult::UnknownTalent);
                        return;
                    }
                    target.emplace_back(static_cast<uint16>(id), static_cast<uint8>(rank));
                }
            }
        }

        PrestigeAPI::PrestigeTalentResult result = PrestigeAPI::ApplyTalents(player, target);
        SendTalentResult(player, "apply", result);
        // Always resend: on failure the client drops its staged changes and re-syncs.
        SendTalents(player);
    }

    void HandleGetChallenges(Player* player, DCAddon::ParsedMessage const& /*msg*/)
    {
        if (player)
            SendChallenges(player);
    }

    void HandleGetRewards(Player* player, DCAddon::ParsedMessage const& /*msg*/)
    {
        if (player)
            SendRewards(player);
    }

    void HandleClaimReward(Player* player, DCAddon::ParsedMessage const& msg)
    {
        if (!player)
            return;

        uint32 threshold = 0;
        if (DCAddon::IsJsonMessage(msg))
        {
            DCAddon::JsonValue json = DCAddon::GetJsonData(msg);
            if (json["threshold"].IsNumber())
                threshold = json["threshold"].AsUInt32();
        }

        PrestigeAPI::PrestigeTalentResult result = PrestigeAPI::ClaimReward(player, threshold);
        SendTalentResult(player, "claim", result);
        SendRewards(player);
    }

    void HandleResetTalents(Player* player, DCAddon::ParsedMessage const& /*msg*/)
    {
        if (!player)
            return;

        PrestigeAPI::PrestigeTalentResult result = PrestigeAPI::ResetTalents(player);
        SendTalentResult(player, "reset", result);
        if (result == PrestigeAPI::PrestigeTalentResult::Ok)
            SendTalents(player);
    }

    // =======================================================================
    // Notification Helpers (can be called from prestige system)
    // =======================================================================

    /**
     * Notify addon client about a prestige level-up
     * Called from PrestigeSystem::PerformPrestige
     */
    void NotifyPrestigeLevelUp(Player* player, uint32 newLevel, uint32 totalBonus)
    {
        if (!player || !player->GetSession())
            return;

        DCAddon::JsonMessage msg(MODULE, Opcode::SMSG_LEVEL_UP);
        msg.Set("newLevel", newLevel);
        msg.Set("maxLevel", PrestigeAPI::GetMaxPrestigeLevel());
        msg.Set("totalBonus", totalBonus);
        msg.Set("bonusPerLevel", PrestigeAPI::GetStatBonusPercent());
        msg.Set("atMaxPrestige", newLevel >= PrestigeAPI::GetMaxPrestigeLevel());

        msg.Send(player);

        LOG_DEBUG("dc.addon", "DCPrestigeAddon: Sent prestige level-up notification to {} (level {})",
            player->GetName(), newLevel);
    }

} // namespace DCPrestigeAddon

// =======================================================================
// Script Registration
// =======================================================================

class DCPrestigeAddonWorldScript : public WorldScript
{
public:
    DCPrestigeAddonWorldScript() : WorldScript("DCPrestigeAddonWorldScript") { }

    void OnStartup() override
    {
        bool enabled = sConfigMgr->GetOption<bool>(DCPrestigeAddon::Config::CANONICAL_ENABLED, true);

        if (enabled)
        {
            // Register message handlers
            auto& router = DCAddon::MessageRouter::Instance();

            router.RegisterHandler(DCPrestigeAddon::MODULE, DCPrestigeAddon::Opcode::CMSG_GET_INFO,
                DCPrestigeAddon::HandleGetInfo);

            router.RegisterHandler(DCPrestigeAddon::MODULE, DCPrestigeAddon::Opcode::CMSG_GET_BONUSES,
                DCPrestigeAddon::HandleGetBonuses);

            router.RegisterHandler(DCPrestigeAddon::MODULE, DCPrestigeAddon::Opcode::CMSG_GET_TALENTS,
                DCPrestigeAddon::HandleGetTalents);

            router.RegisterHandler(DCPrestigeAddon::MODULE, DCPrestigeAddon::Opcode::CMSG_LEARN_TALENT,
                DCPrestigeAddon::HandleLearnTalent);

            router.RegisterHandler(DCPrestigeAddon::MODULE, DCPrestigeAddon::Opcode::CMSG_RESET_TALENTS,
                DCPrestigeAddon::HandleResetTalents);

            router.RegisterHandler(DCPrestigeAddon::MODULE, DCPrestigeAddon::Opcode::CMSG_GET_CHALLENGES,
                DCPrestigeAddon::HandleGetChallenges);

            router.RegisterHandler(DCPrestigeAddon::MODULE, DCPrestigeAddon::Opcode::CMSG_GET_REWARDS,
                DCPrestigeAddon::HandleGetRewards);

            router.RegisterHandler(DCPrestigeAddon::MODULE, DCPrestigeAddon::Opcode::CMSG_CLAIM_REWARD,
                DCPrestigeAddon::HandleClaimReward);

            router.RegisterHandler(DCPrestigeAddon::MODULE, DCPrestigeAddon::Opcode::CMSG_APPLY_TALENTS,
                DCPrestigeAddon::HandleApplyTalents);

            LOG_INFO("dc.addon", "DCPrestigeAddon: Prestige addon handler initialized");
        }
        else
        {
            LOG_INFO("dc.addon", "DCPrestigeAddon: Prestige addon handler disabled in config");
        }
    }
};

// Native transport receive hook: decodes CMSG_REQUEST_PRESTIGE and routes it
// through the shared MessageRouter so native and addon clients hit the same
// handlers. Responses pick their transport in SendPrestigeMessage().
class PrestigeNativeServerScript : public ServerScript
{
public:
    PrestigeNativeServerScript()
        : ServerScript("PrestigeNativeServerScript",
            { SERVERHOOK_CAN_PACKET_RECEIVE })
    {
    }

private:
    bool CanPacketReceive(WorldSession* session,
        WorldPacket const& packet) override
    {
        if (packet.GetOpcode()
            != DCPrestigeAddon::BridgeOpcode::CMSG_REQUEST_PRESTIGE)
        {
            return true;
        }

        return DCAddon::HandleNativeModuleRequest(session, packet,
            DCPrestigeAddon::BridgeOpcode::CMSG_REQUEST_PRESTIGE,
            DCPrestigeAddon::MODULE);
    }
};

void AddSC_dc_addon_prestige()
{
    new DCPrestigeAddonWorldScript();
    new PrestigeNativeServerScript();
}
