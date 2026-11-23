/*
 * DarkChaos-255 Account-Wide Flight Paths
 *
 * When any character discovers a flight path, every character of the same
 * account and the same team knows it from its next login on.
 *
 * Pool rows are keyed (account_id, team, node_id) in the characters table
 * `dc_account_taxi_nodes` (pending_db_characters). The team key keeps Horde
 * and Alliance networks apart; a second check at grant time refuses nodes
 * that only the other faction's flight masters serve, and Death Knight nodes
 * (Acherus, Shadow Vault) for anyone but a Death Knight.
 *
 * Nodes a character gets for free (PlayerTaxi::InitTaxiNodesForLevel: racial
 * capitals, the Death Knight's whole old-world network, Shattered Sun at 68)
 * are never pooled, so creating a Death Knight does not unlock Kalimdor and
 * the Eastern Kingdoms for every alt.
 *
 * Unlike the reputation/achievement pools this keeps no in-memory cache:
 * OnPlayerLearnTaxiNode runs on map threads, so it only issues an async
 * insert, and the login sync reads the pool once and diffs it against the
 * character. The login continuation runs on the world thread, outside map
 * updates, through DCAddon::EnqueueQueryCallback.
 *
 * One session per account means no other (non-bot) character of the account
 * can be online when a node is learned, so there is nothing to push live.
 * Playerbots neither feed nor receive the pool.
 */

#include "Chat.h"
#include "Config.h"
#include "DBCStores.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SharedDefines.h"
#include "StringFormat.h"
#include "dc_accountwide_pool.h"

namespace
{
    constexpr char const* CONFIG_ENABLE = "DC.AccountWide.TaxiNodes";
    constexpr char const* TABLE_NAME = "dc_account_taxi_nodes";

    constexpr uint32 MAX_TAXI_NODE = uint32(TaxiMaskSize) * 32;

    // DBCStores patches these two nodes to the Death Knight gryphon only after
    // it has built the faction masks, so they are named explicitly.
    constexpr uint32 NODE_ACHERUS_EBON_HOLD = 315;
    constexpr uint32 NODE_SHADOW_VAULT = 333;

    bool IsEnabled()
    {
        return sConfigMgr->GetOption<bool>(CONFIG_ENABLE, true);
    }

    bool InMask(TaxiMask const& mask, uint32 node)
    {
        if (!node || node > MAX_TAXI_NODE)
            return false;

        uint32 const field = (node - 1) / 32;
        uint32 const submask = 1u << ((node - 1) % 32);
        return (mask[field] & submask) != 0;
    }

    void AddToMask(TaxiMask& mask, uint32 node)
    {
        if (!node || node > MAX_TAXI_NODE)
            return;

        mask[(node - 1) / 32] |= 1u << ((node - 1) % 32);
    }

    bool IsDeathKnightNode(uint32 node)
    {
        return node == NODE_ACHERUS_EBON_HOLD || node == NODE_SHADOW_VAULT
            || InMask(sDeathKnightTaxiNodesMask, node);
    }

    // Real players only; playerbots are ordinary Players on an IsBot() session.
    bool IsEligible(Player const* player)
    {
        return player && player->GetSession() && !player->GetSession()->IsBot();
    }

    // The original team: a character in a cross-faction battleground still
    // owns its own faction's flight network.
    uint8 TeamOf(Player const* player)
    {
        return uint8(player->GetTeamId(true));
    }

    // Whether a pooled node may be granted to this character.
    bool CanGrant(uint32 node, uint8 team, bool isDeathKnight)
    {
        // Gone from TaxiNodes.dbc since it was pooled.
        if (!InMask(sTaxiNodesMask, node))
            return false;

        if (IsDeathKnightNode(node))
            return isDeathKnight;

        TaxiMask const& own = team == TEAM_HORDE ? sHordeTaxiNodesMask : sAllianceTaxiNodesMask;
        TaxiMask const& other = team == TEAM_HORDE ? sAllianceTaxiNodesMask : sHordeTaxiNodesMask;

        // A node only the other faction's flight master serves stays there.
        // Nodes with no faction mount at all (some DC custom nodes) count as
        // neutral; the team key already keeps them on the side that found them.
        return !(InMask(other, node) && !InMask(own, node));
    }

    std::string MakeRow(uint32 accountId, uint8 team, uint32 node)
    {
        return Acore::StringFormat("({}, {}, {})", accountId, uint32(team), node);
    }

    void SyncCharacter(Player* player, uint32 accountId, uint8 team, QueryResult const& result)
    {
        TaxiMask pooled;
        pooled.fill(0);

        if (result)
        {
            do
            {
                AddToMask(pooled, result->Fetch()[0].Get<uint32>());
            } while (result->NextRow());
        }

        // What this race/class/level is handed for free; never pooled.
        PlayerTaxi starting;
        starting.InitTaxiNodesForLevel(player->getRace(), player->getClass(), player->GetLevel());

        bool const isDeathKnight = player->getClass() == CLASS_DEATH_KNIGHT;

        DCAccountWide::BatchUpsert upsert(TABLE_NAME, "`account_id`, `team`, `node_id`",
            "`node_id` = `node_id`");

        uint32 seeded = 0;
        uint32 granted = 0;

        for (uint32 node = 1; node <= MAX_TAXI_NODE; ++node)
        {
            if (!InMask(sTaxiNodesMask, node))
                continue;

            bool const known = player->m_taxi.IsTaximaskNodeKnown(node);
            bool const inPool = InMask(pooled, node);

            if (known && !inPool)
            {
                // Learned before the pool existed (or while it was disabled).
                if (!starting.IsTaximaskNodeKnown(node))
                {
                    upsert.AddRow(MakeRow(accountId, team, node));
                    ++seeded;
                }
            }
            else if (!known && inPool && CanGrant(node, team, isDeathKnight))
            {
                player->m_taxi.SetTaximaskNode(node);
                ++granted;
            }
        }

        upsert.Execute();

        if (granted)
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cff00ccff[Flight Paths]|r You know {} flight path(s) discovered by your other characters.",
                granted);
        }

        LOG_DEBUG("module.dc", "[DCTaxi] {} (account {}, team {}): {} node(s) pooled, {} granted",
            player->GetName(), accountId, uint32(team), seeded, granted);
    }

    class DCAccountWideTaxiPlayerScript : public PlayerScript
    {
    public:
        DCAccountWideTaxiPlayerScript() : PlayerScript("DCAccountWideTaxiPlayerScript",
        {
            PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LEARN_TAXI_NODE
        }) { }

        void OnPlayerLogin(Player* player) override
        {
            if (!IsEnabled() || !IsEligible(player))
                return;

            uint32 const accountId = player->GetSession()->GetAccountId();
            uint8 const team = TeamOf(player);
            ObjectGuid const guid = player->GetGUID();

            DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(Acore::StringFormat(
                "SELECT `node_id` FROM `{}` WHERE `account_id` = {} AND `team` = {}",
                TABLE_NAME, accountId, uint32(team)))
                .WithCallback([guid, accountId, team](QueryResult result)
            {
                Player* target = ObjectAccessor::FindPlayer(guid);
                if (!target || !target->IsInWorld() || !target->GetSession())
                    return;

                SyncCharacter(target, accountId, team, result);
            }));
        }

        // Map thread: fire-and-forget insert, no shared state touched.
        void OnPlayerLearnTaxiNode(Player const* player, uint32 nodeId) override
        {
            if (!IsEnabled() || !IsEligible(player) || !InMask(sTaxiNodesMask, nodeId))
                return;

            CharacterDatabase.Execute(
                "INSERT IGNORE INTO `dc_account_taxi_nodes` (`account_id`, `team`, `node_id`) VALUES ({}, {}, {})",
                player->GetSession()->GetAccountId(), uint32(TeamOf(player)), nodeId);
        }
    };

    class DCAccountWideTaxiAccountScript : public AccountScript
    {
    public:
        DCAccountWideTaxiAccountScript() : AccountScript("DCAccountWideTaxiAccountScript",
            { ACCOUNTHOOK_ON_BEFORE_ACCOUNT_DELETE }) { }

        void OnBeforeAccountDelete(uint32 accountId) override
        {
            CharacterDatabase.Execute("DELETE FROM `dc_account_taxi_nodes` WHERE `account_id` = {}", accountId);
        }
    };
}

void AddSC_dc_accountwide_taxi()
{
    new DCAccountWideTaxiPlayerScript();
    new DCAccountWideTaxiAccountScript();
}
