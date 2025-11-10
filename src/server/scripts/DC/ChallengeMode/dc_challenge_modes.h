#ifndef AZEROTHCORE_DC_CHALLENGEMODES_H
#define AZEROTHCORE_DC_CHALLENGEMODES_H

#include "ScriptMgr.h"
#include "Player.h"
#include "Config.h"
#include "Chat.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "SpellMgr.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "GameObjectAI.h"
#include "Pet.h"
#include <map>
#include <sstream>


enum ChallengeModeSettings
{
    SETTING_HARDCORE           = 0,
    SETTING_SEMI_HARDCORE      = 1,
    SETTING_SELF_CRAFTED       = 2,
    SETTING_ITEM_QUALITY_LEVEL = 3,
    SETTING_SLOW_XP_GAIN       = 4,
    SETTING_VERY_SLOW_XP_GAIN  = 5,
    SETTING_QUEST_XP_ONLY      = 6,
    SETTING_IRON_MAN           = 7,
    HARDCORE_DEAD              = 8
};

enum AllowedProfessions
{
    RUNEFORGING    = 53428,
    POISONS        = 2842,
    BEAST_TRAINING = 5149
};

enum ChallengeAuraSpells : uint32
{
    SPELL_AURA_HARDCORE          = 800020,
    SPELL_AURA_SEMI_HARDCORE     = 800021,
    SPELL_AURA_SELF_CRAFTED      = 800022,
    SPELL_AURA_ITEM_QUALITY      = 800023,
    SPELL_AURA_SLOW_XP           = 800024,
    SPELL_AURA_VERY_SLOW_XP      = 800025,
    SPELL_AURA_QUEST_XP_ONLY     = 800026,
    SPELL_AURA_IRON_MAN          = 800027,
    SPELL_AURA_COMBINATION       = 800028
};

// Configuration structure for challenge mode settings
struct ChallengeSettingConfig
{
    ChallengeModeSettings setting;
    std::string name;
    std::string description;
    uint32 bitFlag;
    uint32 auraId;
};

// Global config map - eliminates 240 lines of duplicate switch statements
extern const std::map<ChallengeModeSettings, ChallengeSettingConfig> g_ChallengeSettingConfigs;


class ChallengeModes
{
public:
    static ChallengeModes* instance();

    bool challengesEnabled, hardcoreEnable, semiHardcoreEnable, selfCraftedEnable, itemQualityLevelEnable, slowXpGainEnable, verySlowXpGainEnable, questXpOnlyEnable, ironManEnable;
    uint32 hardcoreDisableLevel, semiHardcoreDisableLevel, selfCraftedDisableLevel, itemQualityLevelDisableLevel, slowXpGainDisableLevel, verySlowXpGainDisableLevel, questXpOnlyDisableLevel, ironManDisableLevel, hardcoreItemRewardAmount, semiHardcoreItemRewardAmount, selfCraftedItemRewardAmount, itemQualityLevelItemRewardAmount, slowXpGainItemRewardAmount, verySlowXpGainItemRewardAmount, questXpOnlyItemRewardAmount, ironManItemRewardAmount;
    float hardcoreXpBonus, semiHardcoreXpBonus, selfCraftedXpBonus, itemQualityLevelXpBonus, questXpOnlyXpBonus, slowXpGainBonus, verySlowXpGainBonus, ironManXpBonus;
    std::unordered_map<uint8, uint32> hardcoreTitleRewards, semiHardcoreTitleRewards, selfCraftedTitleRewards, itemQualityLevelTitleRewards, slowXpGainTitleRewards, verySlowXpGainTitleRewards, questXpOnlyTitleRewards, ironManTitleRewards;
    std::unordered_map<uint8, uint32> hardcoreItemRewards, semiHardcoreItemRewards, selfCraftedItemRewards, itemQualityLevelItemRewards, slowXpGainItemRewards, verySlowXpGainItemRewards, questXpOnlyItemRewards, ironManItemRewards;
    std::unordered_map<uint8, uint32> hardcoreTalentRewards, semiHardcoreTalentRewards, selfCraftedTalentRewards, itemQualityLevelTalentRewards, slowXpGainTalentRewards, verySlowXpGainTalentRewards, questXpOnlyTalentRewards, ironManTalentRewards;
    std::unordered_map<uint8, uint32> hardcoreAchievementReward, semiHardcoreAchievementReward, selfCraftedAchievementReward, itemQualityLevelAchievementReward, slowXpGainAchievementReward, verySlowXpGainAchievementReward, questXpOnlyAchievementReward, ironManAchievementReward;

    std::unordered_map<std::string, std::unordered_map<uint8, uint32>*> rewardConfigMap =
            {
                    { "Hardcore.TitleRewards",                &hardcoreTitleRewards                 },
                    { "SemiHardcore.TitleRewards",            &semiHardcoreTitleRewards             },
                    { "SelfCrafted.TitleRewards",             &selfCraftedTitleRewards              },
                    { "ItemQualityLevel.TitleRewards",        &itemQualityLevelTitleRewards         },
                    { "SlowXpGain.TitleRewards",              &slowXpGainTitleRewards               },
                    { "VerySlowXpGain.TitleRewards",          &verySlowXpGainTitleRewards           },
                    { "QuestXpOnly.TitleRewards",             &questXpOnlyTitleRewards              },
                    { "IronMan.TitleRewards",                 &ironManTitleRewards                  },

                    { "Hardcore.TalentRewards",               &hardcoreTalentRewards                },
                    { "SemiHardcore.TalentRewards",           &semiHardcoreTalentRewards            },
                    { "SelfCrafted.TalentRewards",            &selfCraftedTalentRewards             },
                    { "ItemQualityLevel.TalentRewards",       &itemQualityLevelTalentRewards        },
                    { "SlowXpGain.TalentRewards",             &slowXpGainTalentRewards              },
                    { "VerySlowXpGain.TalentRewards",         &verySlowXpGainTalentRewards          },
                    { "QuestXpOnly.TalentRewards",            &questXpOnlyTalentRewards             },
                    { "IronMan.TalentRewards",                &ironManTalentRewards                 },

                    { "Hardcore.ItemRewards",                 &hardcoreItemRewards                  },
                    { "SemiHardcore.ItemRewards",             &semiHardcoreItemRewards              },
                    { "SelfCrafted.ItemRewards",              &selfCraftedItemRewards               }, 
                    { "ItemQualityLevel.ItemRewards",         &itemQualityLevelItemRewards          },
                    { "SlowXpGain.ItemRewards",               &slowXpGainItemRewards                },
                    { "VerySlowXpGain.ItemRewards",           &verySlowXpGainItemRewards            },
                    { "QuestXpOnly.ItemRewards",              &questXpOnlyItemRewards               },
                    { "IronMan.ItemRewards",                  &ironManItemRewards                   },

                    { "Hardcore.AchievementReward",           &hardcoreAchievementReward            },
                    { "SemiHardcore.AchievementReward",       &semiHardcoreAchievementReward        },
                    { "SelfCrafted.AchievementReward",        &selfCraftedAchievementReward         },
                    { "ItemQualityLevel.AchievementReward",   &itemQualityLevelAchievementReward    },
                    { "SlowXpGain.AchievementReward",         &slowXpGainAchievementReward          },
                    { "VerySlowXpGain.AchievementReward",     &verySlowXpGainAchievementReward      },
                    { "QuestXpOnly.AchievementReward",        &questXpOnlyAchievementReward         },
                    { "IronMan.AchievementReward",            &ironManAchievementReward             }
            };

    [[nodiscard]] bool enabled() const { return challengesEnabled; }
    [[nodiscard]] bool challengeEnabled(ChallengeModeSettings setting) const;
    [[nodiscard]] uint32 getDisableLevel(ChallengeModeSettings setting) const;
    [[nodiscard]] float getXpBonusForChallenge(ChallengeModeSettings setting) const;
    bool challengeEnabledForPlayer(ChallengeModeSettings setting, Player* player) const;
    [[nodiscard]] const std::unordered_map<uint8, uint32> *getTitleMapForChallenge(ChallengeModeSettings setting) const;
    [[nodiscard]] const std::unordered_map<uint8, uint32> *getTalentMapForChallenge(ChallengeModeSettings setting) const;
    [[nodiscard]] const std::unordered_map<uint8, uint32> *getItemMapForChallenge(ChallengeModeSettings setting) const;
    [[nodiscard]] const std::unordered_map<uint8, uint32> *getAchievementMapForChallenge(ChallengeModeSettings setting) const;
    [[nodiscard]] uint32 getItemRewardAmount(ChallengeModeSettings setting) const;

    void RefreshChallengeAuras(Player* player);
};

#define sChallengeModes ChallengeModes::instance()

#endif //AZEROTHCORE_DC_CHALLENGEMODES_H
