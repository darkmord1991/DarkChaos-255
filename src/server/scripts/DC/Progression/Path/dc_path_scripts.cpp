/*
 * DarkChaos Path of Chaos - where progress comes from.
 *
 * DC systems report over the CrossSystem bus; everything the core already announces comes
 * through its ordinary hooks. Tasks never read client claims, so a task is only as honest as
 * the event behind it: each one here fires on the success itself, not on the attempt.
 */

#include "DCPath.h"

#include "AllBattlegroundScript.h"
#include "Battleground.h"
#include "Creature.h"
#include "CreatureData.h"
#include "DBCStructure.h"
#include "GlobalScript.h"
#include "KillRewarder.h"
#include "Log.h"
#include "Map.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "PlayerScript.h"
#include "QuestDef.h"
#include "ScriptMgr.h"
#include "SharedDefines.h"
#include "WorldScript.h"
#include "WorldSession.h"
#include "DC/CrossSystem/CrossSystemWorldBossMgr.h"
#include "DC/CrossSystem/EventBus.h"
#include "DC/MythicPlus/dc_mythicplus_run_manager.h"

#include <memory>

using namespace DarkChaos::CrossSystem;
using DarkChaos::Path::ObjectiveType;

namespace
{
    // The bus publishes on the caller's thread, which is a map thread for a Mythic+ run, so
    // this may run concurrently with itself. PathMgr holds the only shared state.
    class PathEventHandler : public IEventHandler
    {
    public:
        SystemId GetSystemId() const override
        {
            return SystemId::None;
        }

        char const* GetSystemName() const override
        {
            return "PathOfChaos";
        }

        std::vector<EventType> GetSubscribedEvents() const override
        {
            return {
                EventType::MythicPlusComplete,
                EventType::VaultClaimed,
                EventType::ItemUpgraded,
                EventType::PlayerPrestige,
                EventType::FeatureUsed
            };
        }

        void OnEvent(EventData const& event) override
        {
            if (auto const* run = dynamic_cast<DungeonCompleteEvent const*>(&event))
            {
                for (ObjectGuid const& guid : run->participants)
                {
                    Player* player = ObjectAccessor::FindConnectedPlayer(guid);
                    if (!player)
                        continue;

                    sPathMgr->Record(player, ObjectiveType::MythicPlusRun, run->keystoneLevel);
                    if (run->timedSuccess)
                        sPathMgr->Record(player, ObjectiveType::MythicPlusTimed, run->keystoneLevel);
                }
                return;
            }

            Player* player = ObjectAccessor::FindConnectedPlayer(event.playerGuid);
            if (!player)
                return;

            if (auto const* upgrade = dynamic_cast<ItemUpgradeEvent const*>(&event))
                sPathMgr->Record(player, ObjectiveType::ItemUpgrade, upgrade->toLevel);
            else if (dynamic_cast<VaultClaimEvent const*>(&event))
                sPathMgr->Record(player, ObjectiveType::VaultClaim);
            else if (dynamic_cast<PrestigeEvent const*>(&event))
                sPathMgr->RefreshMilestones(player);
            else if (auto const* feature = dynamic_cast<FeatureUsedEvent const*>(&event))
                RecordFeature(player, *feature);
        }

    private:
        static void RecordFeature(Player* player, FeatureUsedEvent const& feature)
        {
            switch (feature.kind)
            {
                case FeatureKind::ShopPurchase:
                    sPathMgr->Record(player, ObjectiveType::ShopPurchase, feature.value);
                    break;
                case FeatureKind::EnchantReroll:
                    sPathMgr->Record(player, ObjectiveType::EnchantReroll, feature.value);
                    break;
                case FeatureKind::Transmutation:
                    sPathMgr->Record(player, ObjectiveType::Transmutation, feature.value);
                    break;
                case FeatureKind::HotspotVisit:
                    sPathMgr->Record(player, ObjectiveType::HotspotVisit, feature.value);
                    break;
                case FeatureKind::Transmog:
                    sPathMgr->Record(player, ObjectiveType::Transmog, feature.value);
                    break;
                case FeatureKind::GroupFinder:
                    sPathMgr->Record(player, ObjectiveType::GroupFinder, feature.value);
                    break;
                case FeatureKind::PrestigeChallenge:
                    sPathMgr->Record(player, ObjectiveType::PrestigeChallenge, feature.value);
                    break;
                case FeatureKind::SeasonChest:
                    sPathMgr->Record(player, ObjectiveType::SeasonChest, feature.value);
                    break;
                case FeatureKind::WorldforgedPickup:
                    sPathMgr->Record(player, ObjectiveType::WorldforgedPickup, feature.value);
                    break;
                case FeatureKind::Spectate:
                    sPathMgr->Record(player, ObjectiveType::Spectate, feature.value);
                    break;
                default:
                    break;
            }
        }
    };

    std::unique_ptr<PathEventHandler> sPathEventHandler;

    // Same rule the core applies to kill credit: a grouped player must not be lying dead with
    // a corpse in the world.
    bool EarnsKillCredit(Player const* player)
    {
        return player->IsAlive() || !player->GetCorpse();
    }
}

class DCPathWorldScript : public WorldScript
{
public:
    DCPathWorldScript() : WorldScript("DCPathWorldScript", { WORLDHOOK_ON_STARTUP, WORLDHOOK_ON_SHUTDOWN }) { }

    void OnStartup() override
    {
        sPathMgr->LoadCatalog();

        sPathEventHandler = std::make_unique<PathEventHandler>();
        EventBus::instance()->SubscribeHandler(sPathEventHandler.get());
    }

    void OnShutdown() override
    {
        if (!sPathEventHandler)
            return;

        EventBus::instance()->UnsubscribeHandler(sPathEventHandler.get());
        sPathEventHandler.reset();
    }
};

class DCPathPlayerScript : public PlayerScript
{
public:
    DCPathPlayerScript() : PlayerScript("DCPathPlayerScript", {
        PLAYERHOOK_ON_LOGIN,
        PLAYERHOOK_ON_LEVEL_CHANGED,
        PLAYERHOOK_ON_EQUIP,
        PLAYERHOOK_ON_PLAYER_COMPLETE_QUEST,
        PLAYERHOOK_ON_REWARD_KILL_REWARDER,
        PLAYERHOOK_ON_ACHI_COMPLETE,
        PLAYERHOOK_ON_DUEL_END,
        PLAYERHOOK_ON_UPDATE_ZONE,
        PLAYERHOOK_ON_MAP_CHANGED
    }) { }

    void OnPlayerLogin(Player* player) override
    {
        sPathMgr->HandleLogin(player);
    }

    void OnPlayerLevelChanged(Player* player, uint8 /*oldLevel*/) override
    {
        sPathMgr->Raise(player, ObjectiveType::Level, player->GetLevel());
    }

    void OnPlayerEquip(Player* player, Item* /*item*/, uint8 /*bag*/, uint8 /*slot*/, bool /*update*/) override
    {
        if (!player->GetSession()->IsBot())
            sPathMgr->Raise(player, ObjectiveType::ItemLevel, uint32(player->GetAverageItemLevel()));
    }

    // Fires at the end of Player::RewardQuest: the turn-in, not the objectives finishing. So
    // does a hidden tracking quest rewarding itself and the reward for a finished LFG dungeon,
    // and neither is a quest the player turned in.
    void OnPlayerCompleteQuest(Player* player, Quest const* quest) override
    {
        if (!quest || quest->HasFlag(QUEST_FLAGS_TRACKING) || quest->IsDFQuest())
            return;

        sPathMgr->Record(player, ObjectiveType::QuestTurnIn, quest->GetQuestId());

        if (quest->IsDaily())
            sPathMgr->Record(player, ObjectiveType::DailyQuest);
        else if (quest->IsWeekly())
            sPathMgr->Record(player, ObjectiveType::WeeklyQuest);
    }

    // Once per rewarded group member, where OnPlayerCreatureKill only names the killer.
    void OnPlayerRewardKillRewarder(Player* player, KillRewarder* rewarder, bool /*isDungeon*/,
        float& /*rate*/) override
    {
        // Every kill of every bot lands here, so they leave first.
        if (player->GetSession()->IsBot())
            return;

        Creature* creature = rewarder->GetVictim() ? rewarder->GetVictim()->ToCreature() : nullptr;
        if (!creature || !EarnsKillCredit(player))
            return;

        uint32 const entry = creature->GetEntry();
        sPathMgr->Record(player, ObjectiveType::CreatureKill, entry);

        // Creature::isWorldBoss() is only the boss-mob type flag, which raid bosses carry too.
        uint32 const rank = creature->GetCreatureTemplate()->rank;
        if (sWorldBossMgr->GetBossInfo(entry))
            sPathMgr->Record(player, ObjectiveType::WorldBossKill, entry);
        else if (rank == CREATURE_ELITE_RARE || rank == CREATURE_ELITE_RAREELITE)
            sPathMgr->Record(player, ObjectiveType::RareKill, entry);
    }

    void OnPlayerAchievementComplete(Player* player, AchievementEntry const* achievement) override
    {
        sPathMgr->Raise(player, ObjectiveType::Achievement, 1, achievement->ID);
    }

    void OnPlayerDuelEnd(Player* winner, Player* /*loser*/, DuelCompleteType type) override
    {
        if (type == DUEL_WON)
            sPathMgr->Record(winner, ObjectiveType::DuelWin);
    }

    void OnPlayerUpdateZone(Player* player, uint32 /*newZone*/, uint32 /*newArea*/) override
    {
        sPathMgr->RefreshLocation(player);
    }

    void OnPlayerMapChanged(Player* player) override
    {
        sPathMgr->RefreshLocation(player);
    }
};

class DCPathBattlegroundScript : public AllBattlegroundScript
{
public:
    DCPathBattlegroundScript() : AllBattlegroundScript("DCPathBattlegroundScript", {
        ALLBATTLEGROUNDHOOK_ON_BATTLEGROUND_END_REWARD
    }) { }

    void OnBattlegroundEndReward(Battleground* bg, Player* player, TeamId winnerTeamId) override
    {
        if (!bg || !player)
            return;

        bool const won = player->GetBgTeamId() == winnerTeamId;
        if (bg->isArena())
        {
            if (won && bg->isRated())
                sPathMgr->Record(player, ObjectiveType::ArenaWin);
            return;
        }

        // The real type: the plain getter answers with the queue's, which random BGs change.
        uint32 const typeId = bg->GetBgTypeID(true);
        sPathMgr->Record(player, ObjectiveType::BattlegroundEnd, typeId);
        if (won)
            sPathMgr->Record(player, ObjectiveType::BattlegroundWin, typeId);
    }
};

// The core reports a dungeon finished through `dungeonCompleted`, an LFG id, which it leaves at 0
// on Mythic difficulty because that borrows the heroic encounter list. Those are matched on the
// final boss instead. Custom dungeons have no LFG entry at all: see ObjectiveType::DungeonClear.
class DCPathDungeonScript : public GlobalScript
{
public:
    DCPathDungeonScript() : GlobalScript("DCPathDungeonScript", { GLOBALHOOK_ON_AFTER_UPDATE_ENCOUNTER_STATE }) { }

    void OnAfterUpdateEncounterState(Map* map, EncounterCreditType type, uint32 creditEntry, Unit* source,
        Difficulty /*difficulty*/, DungeonEncounterList const* /*encounters*/, uint32 dungeonCompleted,
        bool updated) override
    {
        if (!updated || !map || !map->IsNonRaidDungeon())
            return;

        // A keystone run reaches the Mythic+ tasks through the run manager.
        if (sMythicRuns->GetKeystoneLevel(map) > 0)
            return;

        // Read from the map: the hook's own difficulty is rewritten for Mythic.
        Difficulty const difficulty = map->GetDifficulty();
        bool const finished = dungeonCompleted || (difficulty == DUNGEON_DIFFICULTY_EPIC
            && type == ENCOUNTER_CREDIT_KILL_CREATURE && sMythicRuns->IsFinalBoss(map->GetId(), creditEntry));

        if (!finished)
            return;

        Map::PlayerList const& players = map->GetPlayers();
        for (Map::PlayerList::const_iterator itr = players.begin(); itr != players.end(); ++itr)
        {
            Player* player = itr->GetSource();
            if (player && (!source || player->IsAtGroupRewardDistance(source)))
                sPathMgr->Record(player, ObjectiveType::DungeonClear, uint32(difficulty) + 1);
        }
    }
};

void AddSC_dc_path()
{
    new DCPathWorldScript();
    new DCPathPlayerScript();
    new DCPathBattlegroundScript();
    new DCPathDungeonScript();
}
