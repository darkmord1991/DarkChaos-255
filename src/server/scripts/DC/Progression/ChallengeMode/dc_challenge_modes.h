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
    HARDCORE_DEAD              = 8,
    // NOTE: value 8 is reserved for HARDCORE_DEAD (player state). Do not renumber existing settings.
    SETTING_IRON_MAN_PLUS      = 9
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
    SPELL_AURA_COMBINATION       = 800028,
    SPELL_AURA_IRON_MAN_PLUS     = 800029
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

    bool challengesEnabled, hardcoreEnable, semiHardcoreEnable, selfCraftedEnable, itemQualityLevelEnable, slowXpGainEnable, verySlowXpGainEnable, questXpOnlyEnable, ironManEnable, ironManPlusEnable;
    uint32 hardcoreDisableLevel, semiHardcoreDisableLevel, selfCraftedDisableLevel, itemQualityLevelDisableLevel, slowXpGainDisableLevel, verySlowXpGainDisableLevel, questXpOnlyDisableLevel, ironManDisableLevel, ironManPlusDisableLevel;
    float hardcoreXpBonus, semiHardcoreXpBonus, selfCraftedXpBonus, itemQualityLevelXpBonus, questXpOnlyXpBonus, slowXpGainBonus, verySlowXpGainBonus, ironManXpBonus, ironManPlusXpBonus;

    [[nodiscard]] bool enabled() const { return challengesEnabled; }
    [[nodiscard]] bool challengeEnabled(ChallengeModeSettings setting) const;
    [[nodiscard]] uint32 getDisableLevel(ChallengeModeSettings setting) const;
    [[nodiscard]] float getXpBonusForChallenge(ChallengeModeSettings setting) const;
    bool challengeEnabledForPlayer(ChallengeModeSettings setting, Player* player) const;

    void RefreshChallengeAuras(Player* player);
};

#define sChallengeModes ChallengeModes::instance()

// Shared utility functions (implemented in dc_challenge_modes_customized.cpp)
std::string GetChallengeExplanation(ChallengeModeSettings setting);
std::string GetChallengeTitle(ChallengeModeSettings setting);

// Script registration
void AddSC_dc_challenge_modes();

#endif //AZEROTHCORE_DC_CHALLENGEMODES_H
