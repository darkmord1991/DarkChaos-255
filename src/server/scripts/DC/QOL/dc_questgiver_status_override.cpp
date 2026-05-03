#include "dc_questgiver_status_override.h"

#include "ConditionMgr.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "QuestDef.h"
#include "ScriptMgr.h"
#include "World.h"

#include <unordered_map>

namespace DCQuestgiverStatusOverride
{
    namespace
    {
        struct OverrideConfig
        {
            bool promoteDaily = false;
            bool promoteWeekly = false;
            bool promoteMonthly = false;
        };

        std::unordered_map<uint32, OverrideConfig> sOverrideConfigs;
        bool sConfigLoaded = false;

        bool ShouldPromoteRepeatableAvailable(Quest const* quest,
                                              OverrideConfig const& config)
        {
            if (!quest)
                return false;

            return (config.promoteDaily && quest->IsDaily()) ||
                (config.promoteWeekly && quest->IsWeekly()) ||
                (config.promoteMonthly && quest->IsMonthly());
        }

        QuestGiverStatus BuildStatus(Player* player, Creature* creature,
                                     OverrideConfig const& config)
        {
            QuestRelationBounds qr =
                sObjectMgr->GetCreatureQuestRelationBounds(creature->GetEntry());
            QuestRelationBounds qir =
                sObjectMgr->GetCreatureQuestInvolvedRelationBounds(
                    creature->GetEntry());
            QuestGiverStatus result = DIALOG_STATUS_NONE;

            for (QuestRelations::const_iterator i = qir.first;
                 i != qir.second; ++i)
            {
                QuestGiverStatus result2 = DIALOG_STATUS_NONE;
                uint32 questId = i->second;
                Quest const* quest = sObjectMgr->GetQuestTemplate(questId);
                if (!quest)
                    continue;

                ConditionList conditions =
                    sConditionMgr->GetConditionsForNotGroupedEntry(
                        CONDITION_SOURCE_TYPE_QUEST_AVAILABLE,
                        quest->GetQuestId());
                if (!sConditionMgr->IsObjectMeetToConditions(player,
                                                             conditions))
                {
                    continue;
                }

                QuestStatus status = player->GetQuestStatus(questId);
                if (status == QUEST_STATUS_COMPLETE &&
                    !player->GetQuestRewardStatus(questId))
                {
                    result2 = DIALOG_STATUS_REWARD;
                }
                else if (status == QUEST_STATUS_INCOMPLETE)
                {
                    result2 = DIALOG_STATUS_INCOMPLETE;
                }

                if (quest->IsAutoComplete() &&
                    player->CanTakeQuest(quest, false) &&
                    quest->IsRepeatable() &&
                    !quest->IsDailyOrWeekly())
                {
                    result2 = DIALOG_STATUS_REWARD_REP;
                }

                if (result2 > result)
                    result = result2;
            }

            for (QuestRelations::const_iterator i = qr.first;
                 i != qr.second; ++i)
            {
                QuestGiverStatus result2 = DIALOG_STATUS_NONE;
                uint32 questId = i->second;
                Quest const* quest = sObjectMgr->GetQuestTemplate(questId);
                if (!quest)
                    continue;

                ConditionList conditions =
                    sConditionMgr->GetConditionsForNotGroupedEntry(
                        CONDITION_SOURCE_TYPE_QUEST_AVAILABLE,
                        quest->GetQuestId());
                if (!sConditionMgr->IsObjectMeetToConditions(player,
                                                             conditions))
                {
                    continue;
                }

                QuestStatus status = player->GetQuestStatus(questId);
                if (status != QUEST_STATUS_NONE)
                    continue;

                if (!player->CanSeeStartQuest(quest))
                    continue;

                if (player->SatisfyQuestLevel(quest, false))
                {
                    bool isNotLowLevelQuest =
                        player->GetLevel() <=
                        (player->GetQuestLevel(quest) +
                         sWorld->getIntConfig(
                             CONFIG_QUEST_LOW_LEVEL_HIDE_DIFF));

                    if (quest->IsRepeatable())
                    {
                        if (ShouldPromoteRepeatableAvailable(quest, config))
                        {
                            result2 = isNotLowLevelQuest ?
                                DIALOG_STATUS_AVAILABLE_REP :
                                DIALOG_STATUS_LOW_LEVEL_AVAILABLE_REP;
                        }
                        else if (quest->IsDaily())
                        {
                            result2 = isNotLowLevelQuest ?
                                DIALOG_STATUS_AVAILABLE_REP :
                                DIALOG_STATUS_LOW_LEVEL_AVAILABLE_REP;
                        }
                        else if (quest->IsWeekly() || quest->IsMonthly())
                        {
                            result2 = isNotLowLevelQuest ?
                                DIALOG_STATUS_AVAILABLE :
                                DIALOG_STATUS_LOW_LEVEL_AVAILABLE;
                        }
                        else if (quest->IsAutoComplete())
                        {
                            result2 = isNotLowLevelQuest ?
                                DIALOG_STATUS_REWARD_REP :
                                DIALOG_STATUS_LOW_LEVEL_REWARD_REP;
                        }
                        else
                        {
                            result2 = isNotLowLevelQuest ?
                                DIALOG_STATUS_REWARD_REP :
                                DIALOG_STATUS_LOW_LEVEL_REWARD_REP;
                        }
                    }
                    else
                    {
                        result2 = isNotLowLevelQuest ?
                            DIALOG_STATUS_AVAILABLE :
                            DIALOG_STATUS_LOW_LEVEL_AVAILABLE;
                    }
                }
                else
                {
                    result2 = DIALOG_STATUS_UNAVAILABLE;
                }

                if (result2 > result)
                    result = result2;
            }

            return result;
        }
    }

    void LoadConfig(bool reload)
    {
        sOverrideConfigs.clear();

        QueryResult result = WorldDatabase.Query(
            "SELECT creature_entry, promote_daily, promote_weekly, "
            "promote_monthly FROM dc_questgiver_status_overrides "
            "WHERE enabled = 1 ORDER BY creature_entry");

        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                OverrideConfig config;
                config.promoteDaily = fields[1].Get<bool>();
                config.promoteWeekly = fields[2].Get<bool>();
                config.promoteMonthly = fields[3].Get<bool>();
                sOverrideConfigs[fields[0].Get<uint32>()] = config;
            } while (result->NextRow());
        }

        sConfigLoaded = true;
        LOG_INFO("scripts.dc",
                 "DC Questgiver Status Override: {} {} loaded",
                 reload ? "reloaded," : "loaded,",
                 static_cast<uint32>(sOverrideConfigs.size()));
    }

    QuestGiverStatus GetDialogStatus(Player* player, Creature* creature)
    {
        if (!sConfigLoaded)
            LoadConfig(false);

        if (!player || !creature)
            return DIALOG_STATUS_SCRIPTED_NO_STATUS;

        auto const itr = sOverrideConfigs.find(creature->GetEntry());
        if (itr == sOverrideConfigs.end())
            return DIALOG_STATUS_SCRIPTED_NO_STATUS;

        return BuildStatus(player, creature, itr->second);
    }
}

namespace
{
    class DCQuestgiverStatusOverrideWorldScript : public WorldScript
    {
    public:
        DCQuestgiverStatusOverrideWorldScript()
            : WorldScript("DCQuestgiverStatusOverrideWorldScript")
        {
        }

        void OnStartup() override
        {
            DCQuestgiverStatusOverride::LoadConfig(false);
        }

        void OnAfterConfigLoad(bool reload) override
        {
            DCQuestgiverStatusOverride::LoadConfig(reload);
        }
    };
}

void AddSC_dc_questgiver_status_override_qol()
{
    new DCQuestgiverStatusOverrideWorldScript();
}