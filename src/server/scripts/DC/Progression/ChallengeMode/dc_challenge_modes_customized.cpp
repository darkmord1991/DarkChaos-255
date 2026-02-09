/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Customized for DarkChaos-255 by darkmord1991
 * Features:
 * - Level restriction removed (usable at any level, including 255)
 * - Confirmation dialogs with explanations
 * - Hardcore character locking on death
 * - Global death announcements
 * - Login prevention for dead hardcore characters
 */

#include "dc_challenge_modes.h"
#include "World.h"
#include "WorldSessionMgr.h"
#include "ObjectMgr.h"
#include "GameTime.h"
#include "SpellAuras.h"
#include "Chat.h"
#include "StringFormat.h"
#include "WorldSession.h"
#include "dc_challenge_mode_database.h"
#include "../Prestige/dc_prestige_api.h"

#include <algorithm>
#include <array>

using namespace Acore::ChatCommands;

namespace
{
    enum ChallengeGossipActions : uint32
    {
        ACTION_GOSSIP_CLOSE      = 999,
        ACTION_GOSSIP_NOOP       = 9999,
        ACTION_PRESTIGE_OVERVIEW = 1100,
        ACTION_PRESTIGE_WARNINGS = 1101,
        ACTION_PRESTIGE_CONFIRM  = 1102,
        ACTION_RANDOM_INFO       = 1200,
        ACTION_RANDOM_CONFIRM    = 1201,
        ACTION_RANDOM_ACTIVATE   = 1202,
    };
}

// Global configuration map - replaces 240 lines of duplicate switch statements
const std::map<ChallengeModeSettings, ChallengeSettingConfig> g_ChallengeSettingConfigs =
{
    { SETTING_HARDCORE, {
        SETTING_HARDCORE,
        "Hardcore",
        "Character dies permanently on any death",
        1 << SETTING_HARDCORE,
        SPELL_AURA_HARDCORE
    }},
    { SETTING_SEMI_HARDCORE, {
        SETTING_SEMI_HARDCORE,
        "Semi-Hardcore",
        "Character loses XP and items on death",
        1 << SETTING_SEMI_HARDCORE,
        SPELL_AURA_SEMI_HARDCORE
    }},
    { SETTING_SELF_CRAFTED, {
        SETTING_SELF_CRAFTED,
        "Self-Crafted",
        "Can only use items you craft yourself",
        1 << SETTING_SELF_CRAFTED,
        SPELL_AURA_SELF_CRAFTED
    }},
    { SETTING_ITEM_QUALITY_LEVEL, {
        SETTING_ITEM_QUALITY_LEVEL,
        "Item Quality Restricted",
        "Limited to white and green items only",
        1 << SETTING_ITEM_QUALITY_LEVEL,
        SPELL_AURA_ITEM_QUALITY
    }},
    { SETTING_SLOW_XP_GAIN, {
        SETTING_SLOW_XP_GAIN,
        "Slow XP Gain",
        "Experience gain reduced by 50%",
        1 << SETTING_SLOW_XP_GAIN,
        SPELL_AURA_SLOW_XP
    }},
    { SETTING_VERY_SLOW_XP_GAIN, {
        SETTING_VERY_SLOW_XP_GAIN,
        "Very Slow XP Gain",
        "Experience gain reduced by 75%",
        1 << SETTING_VERY_SLOW_XP_GAIN,
        SPELL_AURA_VERY_SLOW_XP
    }},
    { SETTING_QUEST_XP_ONLY, {
        SETTING_QUEST_XP_ONLY,
        "Quest XP Only",
        "Can only gain experience from quests",
        1 << SETTING_QUEST_XP_ONLY,
        SPELL_AURA_QUEST_XP_ONLY
    }},
    { SETTING_IRON_MAN, {
        SETTING_IRON_MAN,
        "Iron Man",
        "No deaths, no auction house, no player trading",
        1 << SETTING_IRON_MAN,
        SPELL_AURA_IRON_MAN
    }},
    { SETTING_IRON_MAN_PLUS, {
        SETTING_IRON_MAN_PLUS,
        "Iron Man+",
        "No talents, no glyphs, no grouping, no dungeons, no professions",
        1 << SETTING_IRON_MAN_PLUS,
        SPELL_AURA_IRON_MAN_PLUS
    }}
};

ChallengeModes* ChallengeModes::instance()
{
    static ChallengeModes instance;
    return &instance;
}

bool ChallengeModes::challengeEnabled(ChallengeModeSettings setting) const
{
    switch(setting)
    {
        case SETTING_HARDCORE:
            return hardcoreEnable;
        case SETTING_SEMI_HARDCORE:
            return semiHardcoreEnable;
        case SETTING_SELF_CRAFTED:
            return selfCraftedEnable;
        case SETTING_ITEM_QUALITY_LEVEL:
            return itemQualityLevelEnable;
        case SETTING_SLOW_XP_GAIN:
            return slowXpGainEnable;
        case SETTING_VERY_SLOW_XP_GAIN:
            return verySlowXpGainEnable;
        case SETTING_QUEST_XP_ONLY:
            return questXpOnlyEnable;
        case SETTING_IRON_MAN:
            return ironManEnable;
        case SETTING_IRON_MAN_PLUS:
            return ironManPlusEnable;
        default:
            return false;
    }
}

uint32 ChallengeModes::getDisableLevel(ChallengeModeSettings setting) const
{
    switch(setting)
    {
        case SETTING_HARDCORE:
            return hardcoreDisableLevel;
        case SETTING_SEMI_HARDCORE:
            return semiHardcoreDisableLevel;
        case SETTING_SELF_CRAFTED:
            return selfCraftedDisableLevel;
        case SETTING_ITEM_QUALITY_LEVEL:
            return itemQualityLevelDisableLevel;
        case SETTING_SLOW_XP_GAIN:
            return slowXpGainDisableLevel;
        case SETTING_VERY_SLOW_XP_GAIN:
            return verySlowXpGainDisableLevel;
        case SETTING_QUEST_XP_ONLY:
            return questXpOnlyDisableLevel;
        case SETTING_IRON_MAN:
            return ironManDisableLevel;
        case SETTING_IRON_MAN_PLUS:
            return ironManPlusDisableLevel;
        default:
            return 0;
    }
}

float ChallengeModes::getXpBonusForChallenge(ChallengeModeSettings setting) const
{
    switch(setting)
    {
        case SETTING_HARDCORE:
            return hardcoreXpBonus;
        case SETTING_SEMI_HARDCORE:
            return semiHardcoreXpBonus;
        case SETTING_SELF_CRAFTED:
            return selfCraftedXpBonus;
        case SETTING_ITEM_QUALITY_LEVEL:
            return itemQualityLevelXpBonus;
        case SETTING_SLOW_XP_GAIN:
            return slowXpGainBonus;
        case SETTING_VERY_SLOW_XP_GAIN:
            return verySlowXpGainBonus;
        case SETTING_QUEST_XP_ONLY:
            return questXpOnlyXpBonus;
        case SETTING_IRON_MAN:
            return ironManXpBonus;
        case SETTING_IRON_MAN_PLUS:
            return ironManPlusXpBonus;
        default:
            return 1.0f;
    }
}

const std::unordered_map<uint8, uint32>* ChallengeModes::getTitleMapForChallenge(ChallengeModeSettings setting) const
{
    switch(setting)
    {
        case SETTING_HARDCORE:
            return &hardcoreTitleRewards;
        case SETTING_SEMI_HARDCORE:
            return &semiHardcoreTitleRewards;
        case SETTING_SELF_CRAFTED:
            return &selfCraftedTitleRewards;
        case SETTING_ITEM_QUALITY_LEVEL:
            return &itemQualityLevelTitleRewards;
        case SETTING_SLOW_XP_GAIN:
            return &slowXpGainTitleRewards;
        case SETTING_VERY_SLOW_XP_GAIN:
            return &verySlowXpGainTitleRewards;
        case SETTING_QUEST_XP_ONLY:
            return &questXpOnlyTitleRewards;
        case SETTING_IRON_MAN:
            return &ironManTitleRewards;
        case SETTING_IRON_MAN_PLUS:
            return &ironManPlusTitleRewards;
        default:
            return nullptr;
    }
}

const std::unordered_map<uint8, uint32>* ChallengeModes::getTalentMapForChallenge(ChallengeModeSettings setting) const
{
    switch(setting)
    {
        case SETTING_HARDCORE:
            return &hardcoreTalentRewards;
        case SETTING_SEMI_HARDCORE:
            return &semiHardcoreTalentRewards;
        case SETTING_SELF_CRAFTED:
            return &selfCraftedTalentRewards;
        case SETTING_ITEM_QUALITY_LEVEL:
            return &itemQualityLevelTalentRewards;
        case SETTING_SLOW_XP_GAIN:
            return &slowXpGainTalentRewards;
        case SETTING_VERY_SLOW_XP_GAIN:
            return &verySlowXpGainTalentRewards;
        case SETTING_QUEST_XP_ONLY:
            return &questXpOnlyTalentRewards;
        case SETTING_IRON_MAN:
            return &ironManTalentRewards;
        case SETTING_IRON_MAN_PLUS:
            return &ironManPlusTalentRewards;
        default:
            return nullptr;
    }
}

const std::unordered_map<uint8, uint32>* ChallengeModes::getItemMapForChallenge(ChallengeModeSettings setting) const
{
    switch(setting)
    {
        case SETTING_HARDCORE:
            return &hardcoreItemRewards;
        case SETTING_SEMI_HARDCORE:
            return &semiHardcoreItemRewards;
        case SETTING_SELF_CRAFTED:
            return &selfCraftedItemRewards;
        case SETTING_ITEM_QUALITY_LEVEL:
            return &itemQualityLevelItemRewards;
        case SETTING_SLOW_XP_GAIN:
            return &slowXpGainItemRewards;
        case SETTING_VERY_SLOW_XP_GAIN:
            return &verySlowXpGainItemRewards;
        case SETTING_QUEST_XP_ONLY:
            return &questXpOnlyItemRewards;
        case SETTING_IRON_MAN:
            return &ironManItemRewards;
        case SETTING_IRON_MAN_PLUS:
            return &ironManPlusItemRewards;
        default:
            return nullptr;
    }
}

uint32 ChallengeModes::getItemRewardAmount(ChallengeModeSettings setting) const
{
    switch(setting)
    {
        case SETTING_HARDCORE:
            return hardcoreItemRewardAmount;
        case SETTING_SEMI_HARDCORE:
            return semiHardcoreItemRewardAmount;
        case SETTING_SELF_CRAFTED:
            return selfCraftedItemRewardAmount;
        case SETTING_ITEM_QUALITY_LEVEL:
            return itemQualityLevelItemRewardAmount;
        case SETTING_SLOW_XP_GAIN:
            return slowXpGainItemRewardAmount;
        case SETTING_VERY_SLOW_XP_GAIN:
            return verySlowXpGainItemRewardAmount;
        case SETTING_QUEST_XP_ONLY:
            return questXpOnlyItemRewardAmount;
        case SETTING_IRON_MAN:
            return ironManItemRewardAmount;
        case SETTING_IRON_MAN_PLUS:
            return ironManPlusItemRewardAmount;
        default:
            return 1;
    }
}

void ChallengeModes::RefreshChallengeAuras(Player* player)
{
    if (!player)
        return;

    size_t activeModeCount = 0;

    for (auto const& [setting, config] : g_ChallengeSettingConfigs)
    {
        bool shouldHaveAura = challengeEnabledForPlayer(setting, player);

        if (shouldHaveAura)
        {
            ++activeModeCount;
            if (!player->HasAura(config.auraId))
            {
                player->CastSpell(player, config.auraId, true);
                LOG_DEBUG("dc.challenge", "ChallengeMode: Applied aura {} ({}) to player {}",
                    config.auraId, config.name, player->GetName());
            }
        }
        else if (player->HasAura(config.auraId))
        {
            player->RemoveAura(config.auraId);
        }
    }

    if (activeModeCount > 1)
    {
        if (!player->HasAura(SPELL_AURA_COMBINATION))
            player->CastSpell(player, SPELL_AURA_COMBINATION, true);
    }
    else if (player->HasAura(SPELL_AURA_COMBINATION))
    {
        player->RemoveAura(SPELL_AURA_COMBINATION);
    }
}

const std::unordered_map<uint8, uint32>* ChallengeModes::getAchievementMapForChallenge(ChallengeModeSettings setting) const
{
    switch(setting)
    {
        case SETTING_HARDCORE:
            return &hardcoreAchievementReward;
        case SETTING_SEMI_HARDCORE:
            return &semiHardcoreAchievementReward;
        case SETTING_SELF_CRAFTED:
            return &selfCraftedAchievementReward;
        case SETTING_ITEM_QUALITY_LEVEL:
            return &itemQualityLevelAchievementReward;
        case SETTING_SLOW_XP_GAIN:
            return &slowXpGainAchievementReward;
        case SETTING_VERY_SLOW_XP_GAIN:
            return &verySlowXpGainAchievementReward;
        case SETTING_QUEST_XP_ONLY:
            return &questXpOnlyAchievementReward;
        case SETTING_IRON_MAN:
            return &ironManAchievementReward;
        case SETTING_IRON_MAN_PLUS:
            return &ironManPlusAchievementReward;
        default:
            return nullptr;
    }
}

bool ChallengeModes::challengeEnabledForPlayer(ChallengeModeSettings setting, Player* player) const
{
    if (!challengeEnabled(setting))
        return false;

    if (player->GetPlayerSetting("mod-challenge-modes", setting).value == 1)
    {
        uint32 disableLevel = getDisableLevel(setting);
        if (disableLevel > 0 && player->GetLevel() >= disableLevel)
            return false;

        return true;
    }

    return false;
}

// ==============================================
// DarkChaos-255: CHALLENGE EXPLANATIONS (C++)
// ==============================================
std::string GetChallengeExplanation(ChallengeModeSettings setting)
{
    switch(setting)
    {
        case SETTING_HARDCORE:
            return "|cffFF0000HARDCORE MODE|r\n\n"
                   "Your character has ONE life. If you die, your character becomes permanently unplayable and will be locked from login.\n\n"
                   "There is no resurrection, no second chances. Death is permanent.\n\n"
                   "A global announcement will be made when you fall, immortalizing your achievement and your demise.\n\n"
                   "Are you ready to face this ultimate challenge?";

        case SETTING_SEMI_HARDCORE:
            return "|cffFF8800SEMI-HARDCORE MODE|r\n\n"
                   "Death has severe consequences.\n\n"
                   "If you die, you will lose:\n"
                   "- ALL equipped items\n"
                   "- ALL gold you are carrying\n\n"
                   "Your character will survive, but the loss will be devastating.\n\n"
                   "Every death is a major setback. Fight carefully, prepare thoroughly.";

        case SETTING_SELF_CRAFTED:
            return "|cff00ffffSELF-CRAFTED MODE|r\n\n"
                   "You can ONLY wear equipment that YOU have personally crafted.\n\n"
                   "No looted gear. No quest rewards. No purchased items.\n\n"
                   "Your crafting skills will determine your power.\n\n"
                   "Master your professions or perish. Every piece of gear tells your story.";

        case SETTING_ITEM_QUALITY_LEVEL:
            return "|cffaaaaaaITEM QUALITY RESTRICTION|r\n\n"
                   "You can ONLY equip items of Normal (white) or Poor (gray) quality.\n\n"
                   "No magic items. No rare gear. No epics.\n\n"
                   "Victory through skill, not equipment.\n\n"
                   "Prove that a true warrior needs no legendary weapons.";

        case SETTING_SLOW_XP_GAIN:
            return "|cff8888ffSLOW LEVELING MODE|r\n\n"
                   "Experience gain reduced to 50% of normal rate.\n\n"
                   "The journey will be longer, more challenging, and more rewarding.\n\n"
                   "Take your time. Enjoy the world. Master your class.\n\n"
                   "Greatness cannot be rushed.";

        case SETTING_VERY_SLOW_XP_GAIN:
            return "|cff4444ffVERY SLOW LEVELING MODE|r\n\n"
                   "Experience gain reduced to 25% of normal rate.\n\n"
                   "This is the ultimate test of patience and dedication.\n\n"
                   "You will see parts of the game others rush past.\n\n"
                   "Includes all Slow XP Gain rewards.\n\n"
                   "Only the truly devoted should attempt this.";

        case SETTING_QUEST_XP_ONLY:
            return "|cff00ff88QUEST XP ONLY MODE|r\n\n"
                   "You can ONLY gain experience from completing quests.\n\n"
                   "Killing monsters gives NO experience whatsoever.\n\n"
                   "Every quest matters. Plan your leveling path carefully.\n\n"
                   "Combat is for survival and loot only.\n\n"
                   "Become a master quest strategist.";

        case SETTING_IRON_MAN:
            return "|cffFFD700IRON MAN CHALLENGE|r\n\n"
                   "The ultimate WoW challenge!\n\n"
                   "Rules:\n"
                   "- NO DEATHS (one death fails the challenge)\n"
                   "- White/Gray items ONLY\n"
                   "- NO talents\n"
                   "- NO glyphs\n"
                   "- NO professions (except First Aid)\n"
                   "- NO grouping or party play\n"
                   "- NO dungeons or raids\n"
                   "- NO PvP\n"
                   "- NO heirlooms\n\n"
                   "Pure skill and determination.\n\n"
                   "Only the most dedicated players complete this.\n\n"
                   "Do you have what it takes?";

        case SETTING_IRON_MAN_PLUS:
            return "|cffFFD700IRON MAN+ CHALLENGE|r\n\n"
                   "Iron Man+, with additional restrictions:\n\n"
                   "Rules:\n"
                   "- NO talents\n"
                   "- NO glyphs\n"
                   "- NO professions (no exceptions)\n"
                   "- NO grouping or party play\n"
                   "- NO dungeons or raids\n\n"
                   "This mode is designed for solo, skill-focused play.\n\n"
                   "Do you accept?";

        default:
            return "Unknown challenge mode.";
    }
}

std::string GetChallengeTitle(ChallengeModeSettings setting)
{
    auto it = g_ChallengeSettingConfigs.find(setting);
    return it != g_ChallengeSettingConfigs.end() ? it->second.name : "Unknown";
}

// ==============================================
// DarkChaos-255: CONFIG LOADER
// ==============================================
class ChallengeModes_WorldScript : public WorldScript
{
public:
    ChallengeModes_WorldScript() : WorldScript("ChallengeModes_WorldScript") { }

    void OnBeforeConfigLoad(bool /*reload*/) override
    {
        sChallengeModes->challengesEnabled = sConfigMgr->GetOption<bool>("ChallengeModes.Enable", false);

        if (!sChallengeModes->enabled())
            return;

        // Hardcore
        sChallengeModes->hardcoreEnable = sConfigMgr->GetOption<bool>("Hardcore.Enable", true);
        sChallengeModes->hardcoreXpBonus = sConfigMgr->GetOption<float>("Hardcore.XPMultiplier", 1.0f);
        sChallengeModes->hardcoreDisableLevel = sConfigMgr->GetOption<uint32>("Hardcore.DisableLevel", 0);
        sChallengeModes->hardcoreItemRewardAmount = sConfigMgr->GetOption<uint32>("Hardcore.ItemRewardAmount", 1);

        // Semi-Hardcore
        sChallengeModes->semiHardcoreEnable = sConfigMgr->GetOption<bool>("SemiHardcore.Enable", true);
        sChallengeModes->semiHardcoreXpBonus = sConfigMgr->GetOption<float>("SemiHardcore.XPMultiplier", 1.0f);
        sChallengeModes->semiHardcoreDisableLevel = sConfigMgr->GetOption<uint32>("SemiHardcore.DisableLevel", 0);
        sChallengeModes->semiHardcoreItemRewardAmount = sConfigMgr->GetOption<uint32>("SemiHardcore.ItemRewardAmount", 1);

        // Self-Crafted
        sChallengeModes->selfCraftedEnable = sConfigMgr->GetOption<bool>("SelfCrafted.Enable", true);
        sChallengeModes->selfCraftedXpBonus = sConfigMgr->GetOption<float>("SelfCrafted.XPMultiplier", 1.0f);
        sChallengeModes->selfCraftedDisableLevel = sConfigMgr->GetOption<uint32>("SelfCrafted.DisableLevel", 0);
        sChallengeModes->selfCraftedItemRewardAmount = sConfigMgr->GetOption<uint32>("SelfCrafted.ItemRewardAmount", 1);

        // Item Quality Level
        sChallengeModes->itemQualityLevelEnable = sConfigMgr->GetOption<bool>("ItemQualityLevel.Enable", true);
        sChallengeModes->itemQualityLevelXpBonus = sConfigMgr->GetOption<float>("ItemQualityLevel.XPMultiplier", 1.0f);
        sChallengeModes->itemQualityLevelDisableLevel = sConfigMgr->GetOption<uint32>("ItemQualityLevel.DisableLevel", 0);
        sChallengeModes->itemQualityLevelItemRewardAmount = sConfigMgr->GetOption<uint32>("ItemQualityLevel.ItemRewardAmount", 1);

        // Slow XP Gain
        sChallengeModes->slowXpGainEnable = sConfigMgr->GetOption<bool>("SlowXpGain.Enable", true);
        sChallengeModes->slowXpGainBonus = sConfigMgr->GetOption<float>("SlowXpGain.XPMultiplier", 0.5f);
        sChallengeModes->slowXpGainDisableLevel = sConfigMgr->GetOption<uint32>("SlowXpGain.DisableLevel", 0);
        sChallengeModes->slowXpGainItemRewardAmount = sConfigMgr->GetOption<uint32>("SlowXpGain.ItemRewardAmount", 1);

        // Very Slow XP Gain
        sChallengeModes->verySlowXpGainEnable = sConfigMgr->GetOption<bool>("VerySlowXpGain.Enable", true);
        sChallengeModes->verySlowXpGainBonus = sConfigMgr->GetOption<float>("VerySlowXpGain.XPMultiplier", 0.25f);
        sChallengeModes->verySlowXpGainDisableLevel = sConfigMgr->GetOption<uint32>("VerySlowXpGain.DisableLevel", 0);
        sChallengeModes->verySlowXpGainItemRewardAmount = sConfigMgr->GetOption<uint32>("VerySlowXpGain.ItemRewardAmount", 1);

        // Quest XP Only
        sChallengeModes->questXpOnlyEnable = sConfigMgr->GetOption<bool>("QuestXpOnly.Enable", true);
        sChallengeModes->questXpOnlyXpBonus = sConfigMgr->GetOption<float>("QuestXpOnly.XPMultiplier", 1.0f);
        sChallengeModes->questXpOnlyDisableLevel = sConfigMgr->GetOption<uint32>("QuestXpOnly.DisableLevel", 0);
        sChallengeModes->questXpOnlyItemRewardAmount = sConfigMgr->GetOption<uint32>("QuestXpOnly.ItemRewardAmount", 1);

        // Iron Man
        sChallengeModes->ironManEnable = sConfigMgr->GetOption<bool>("IronMan.Enable", true);
        sChallengeModes->ironManXpBonus = sConfigMgr->GetOption<float>("IronMan.XPMultiplier", 1.0f);
        sChallengeModes->ironManDisableLevel = sConfigMgr->GetOption<uint32>("IronMan.DisableLevel", 0);
        sChallengeModes->ironManItemRewardAmount = sConfigMgr->GetOption<uint32>("IronMan.ItemRewardAmount", 1);

        // Iron Man+
        sChallengeModes->ironManPlusEnable = sConfigMgr->GetOption<bool>("IronManPlus.Enable", true);
        sChallengeModes->ironManPlusXpBonus = sConfigMgr->GetOption<float>("IronManPlus.XPMultiplier", 1.0f);
        sChallengeModes->ironManPlusDisableLevel = sConfigMgr->GetOption<uint32>("IronManPlus.DisableLevel", 0);
        sChallengeModes->ironManPlusItemRewardAmount = sConfigMgr->GetOption<uint32>("IronManPlus.ItemRewardAmount", 1);

        // Load reward maps
        for (auto const& [key, map] : sChallengeModes->rewardConfigMap)
        {
            std::string rewardString = sConfigMgr->GetOption<std::string>(key, "");
            if (rewardString.empty())
                continue;

            std::istringstream ss(rewardString);
            std::string pair;
            while (std::getline(ss, pair, ','))
            {
                std::istringstream pairStream(pair);
                uint8 level;
                uint32 reward;
                if (pairStream >> level >> reward)
                    (*map)[level] = reward;
            }
        }
    }
};

// ==============================================
// DarkChaos-255: SHRINE GAMEOBJECT (LEVEL RESTRICTION REMOVED)
// ==============================================
class gobject_challenge_modes : public GameObjectScript
{
public:
    gobject_challenge_modes() : GameObjectScript("gobject_challenge_modes") { }

    static bool IsBotPlayer(Player* player)
    {
        if (!player)
            return false;

        WorldSession* session = player->GetSession();
        return session && session->IsBot();
    }

    static bool IsIronManOrPlusActive(Player* player)
    {
        return player && (sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN, player) ||
            sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN_PLUS, player));
    }

    static void ApplyIronManOrPlusImmediateRestrictions(Player* player)
    {
        if (!player)
            return;

        // Remove talent points & talents
        player->resetTalents(true);
        player->SetFreeTalentPoints(0);

        // Clear glyphs
        for (uint8 slot = 0; slot < MAX_GLYPH_SLOT_INDEX; ++slot)
            player->SetGlyph(slot, 0, true);

        // Leave group if currently grouped
        if (Group* group = player->GetGroup())
            group->RemoveMember(player->GetGUID(), GROUP_REMOVEMETHOD_LEAVE, player->GetGUID());

        // If in an instance map, teleport to its entrance.
        if (MapEntry const* mapEntry = sMapStore.LookupEntry(player->GetMapId()))
        {
            if (mapEntry->IsDungeon())
            {
                int32 entranceMapId;
                float x;
                float y;
                if (mapEntry->GetEntrancePos(entranceMapId, x, y))
                    player->TeleportTo(static_cast<uint32>(entranceMapId), x, y, player->GetPositionZ(), player->GetOrientation());
            }
        }
    }

    static bool PlayerHasAnyActiveChallengeMode(Player* player)
    {
        if (!player)
            return false;

        for (auto const& [setting, config] : g_ChallengeSettingConfigs)
        {
            (void)config;
            if (player->GetPlayerSetting("mod-challenge-modes", setting).value == 1)
                return true;
        }

        return false;
    }

    static std::vector<ChallengeModeSettings> GetEligibleRandomChallengeModes(Player* player)
    {
        std::vector<ChallengeModeSettings> eligible;
        if (!player)
            return eligible;

        if (!sChallengeModes->enabled())
            return eligible;

        // Random mode is meant to pick exactly ONE mode.
        // Keep conflict logic simple and consistent with the existing UI:
        // - If any mode is already active, random selection is not allowed.
        if (PlayerHasAnyActiveChallengeMode(player))
            return eligible;

        for (auto const& [setting, config] : g_ChallengeSettingConfigs)
        {
            // Only pick modes that are enabled in config.
            if (!sChallengeModes->challengeEnabled(setting))
                continue;

            // Skip modes that are effectively disabled for the player's current level.
            uint32 disableLevel = sChallengeModes->getDisableLevel(setting);
            if (disableLevel > 0 && player->GetLevel() >= disableLevel)
                continue;

            // Ensure selectable (defensive; map already represents selectable settings).
            if (config.setting != setting)
                continue;

            eligible.push_back(setting);
        }

        return eligible;
    }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        if (!sChallengeModes->enabled())
            return false;

        // DarkChaos-255: LEVEL CHECK REMOVED - Usable at any level including 255
        // Original had: if (player->getLevel() > 5) return false;

        ClearGossipMenuFor(player);

        // Title and instructions
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700=== Challenge Mode Manager ===|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFFFFFSelect a mode to view details:|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);

        if (PrestigeAPI::IsEnabled())
        {
            uint32 prestigeLevel = PrestigeAPI::GetPrestigeLevel(player);
            uint32 maxPrestige = PrestigeAPI::GetMaxPrestigeLevel();
            uint32 statBonusPercent = PrestigeAPI::GetStatBonusPercent();
            uint32 requiredLevel = PrestigeAPI::GetRequiredLevel();
            uint32 totalBonus = prestigeLevel * statBonusPercent;
            bool canPrestige = PrestigeAPI::CanPrestige(player);

            AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                Acore::StringFormat("|cffffd700Prestige Level:|r {}/{} ({}% bonus)", prestigeLevel, maxPrestige, totalBonus),
                GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);

            if (canPrestige)
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff00ff00You meet all requirements to prestige.|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            }
            else if (prestigeLevel >= maxPrestige)
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700You have reached the maximum prestige level.|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            }
            else if (player->GetLevel() < requiredLevel)
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                    Acore::StringFormat("|cff888888Reach level {} to prestige (current: {}).|r", requiredLevel, player->GetLevel()),
                    GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            }
            else
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff888888Prestige requirements not yet met.|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            }
        }
        else
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff888888Prestige system currently disabled.|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
        }

        AddGossipItemFor(player, GOSSIP_ICON_DOT, "|cffFFD700[Prestige Overview]|r", GOSSIP_SENDER_MAIN, ACTION_PRESTIGE_OVERVIEW);
        if (PrestigeAPI::IsEnabled() && PrestigeAPI::CanPrestige(player))
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cffFF4500[Prestige Reset]|r Begin your next prestige", GOSSIP_SENDER_MAIN, ACTION_PRESTIGE_WARNINGS);

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);

        // Check which challenge modes are already active for this player
        bool hasHardcore = sChallengeModes->challengeEnabledForPlayer(SETTING_HARDCORE, player);
        bool hasSemiHardcore = sChallengeModes->challengeEnabledForPlayer(SETTING_SEMI_HARDCORE, player);
        bool hasSelfCrafted = sChallengeModes->challengeEnabledForPlayer(SETTING_SELF_CRAFTED, player);
        bool hasItemQuality = sChallengeModes->challengeEnabledForPlayer(SETTING_ITEM_QUALITY_LEVEL, player);
        bool hasSlowXP = sChallengeModes->challengeEnabledForPlayer(SETTING_SLOW_XP_GAIN, player);
        bool hasVerySlowXP = sChallengeModes->challengeEnabledForPlayer(SETTING_VERY_SLOW_XP_GAIN, player);
        bool hasQuestXPOnly = sChallengeModes->challengeEnabledForPlayer(SETTING_QUEST_XP_ONLY, player);
        bool hasIronMan = sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN, player);
        bool hasIronManPlus = sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN_PLUS, player);

        // XP modes are mutually exclusive
        [[maybe_unused]] bool hasAnyXPMode = hasSlowXP || hasVerySlowXP || hasQuestXPOnly;

        // Iron Man includes Hardcore, Self-Crafted, and Item Quality - blocks those individually
        // Hardcore and Semi-Hardcore are mutually exclusive

        // Show challenge mode selection menu with mutual exclusivity
        if (sChallengeModes->challengeEnabled(SETTING_HARDCORE))
        {
            if (hasHardcore)
                AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cff00FF00[Hardcore Mode]|r |cffFFD700(ACTIVE)|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            else if (hasSemiHardcore || hasIronMan)
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff666666[Hardcore Mode]|r - Unavailable (conflicts with active mode)", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            else
                AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cffFF0000[Hardcore Mode]|r - Death is permanent", GOSSIP_SENDER_MAIN, SETTING_HARDCORE);
        }

        if (sChallengeModes->challengeEnabled(SETTING_SEMI_HARDCORE))
        {
            if (hasSemiHardcore)
                AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cff00FF00[Semi-Hardcore Mode]|r |cffFFD700(ACTIVE)|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            else if (hasHardcore || hasIronMan)
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff666666[Semi-Hardcore Mode]|r - Unavailable (conflicts with active mode)", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            else
                AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cffFF8800[Semi-Hardcore Mode]|r - Severe death penalty", GOSSIP_SENDER_MAIN, SETTING_SEMI_HARDCORE);
        }

        if (sChallengeModes->challengeEnabled(SETTING_SELF_CRAFTED))
        {
            if (hasSelfCrafted)
                AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cff00FF00[Self-Crafted Mode]|r |cffFFD700(ACTIVE)|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            else if (hasIronMan)
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff666666[Self-Crafted Mode]|r - Included in Iron Man", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            else
                AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cff00ffff[Self-Crafted Mode]|r - Only use crafted gear", GOSSIP_SENDER_MAIN, SETTING_SELF_CRAFTED);
        }

        if (sChallengeModes->challengeEnabled(SETTING_ITEM_QUALITY_LEVEL))
        {
            if (hasItemQuality)
                AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cff00FF00[Item Quality Restriction]|r |cffFFD700(ACTIVE)|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            else if (hasIronMan)
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff666666[Item Quality Restriction]|r - Included in Iron Man", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            else
                AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cffaaaaaa[Item Quality Restriction]|r - White/gray items only", GOSSIP_SENDER_MAIN, SETTING_ITEM_QUALITY_LEVEL);
        }

        // XP modes - only one can be active
        if (sChallengeModes->challengeEnabled(SETTING_SLOW_XP_GAIN))
        {
            if (hasSlowXP)
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff00FF00[Slow XP Gain]|r |cffFFD700(ACTIVE)|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            else if (hasVerySlowXP || hasQuestXPOnly)
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff666666[Slow XP Gain]|r - Another XP mode is active", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            else
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff8888ff[Slow XP Gain]|r - 50% XP rate", GOSSIP_SENDER_MAIN, SETTING_SLOW_XP_GAIN);
        }

        if (sChallengeModes->challengeEnabled(SETTING_VERY_SLOW_XP_GAIN))
        {
            if (hasVerySlowXP)
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff00FF00[Very Slow XP Gain]|r |cffFFD700(ACTIVE)|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            else if (hasSlowXP || hasQuestXPOnly)
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff666666[Very Slow XP Gain]|r - Another XP mode is active", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            else
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff4444ff[Very Slow XP Gain]|r - 25% XP rate", GOSSIP_SENDER_MAIN, SETTING_VERY_SLOW_XP_GAIN);
        }

        if (sChallengeModes->challengeEnabled(SETTING_QUEST_XP_ONLY))
        {
            if (hasQuestXPOnly)
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff00FF00[Quest XP Only]|r |cffFFD700(ACTIVE)|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            else if (hasSlowXP || hasVerySlowXP)
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff666666[Quest XP Only]|r - Another XP mode is active", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            else
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff00ff88[Quest XP Only]|r - No XP from kills", GOSSIP_SENDER_MAIN, SETTING_QUEST_XP_ONLY);
        }

        if (sChallengeModes->challengeEnabled(SETTING_IRON_MAN))
        {
            if (hasIronMan)
                AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cff00FF00[Iron Man Mode]|r |cffFFD700(ACTIVE)|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            else if (hasIronManPlus || hasHardcore || hasSemiHardcore || hasSelfCrafted || hasItemQuality)
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff666666[Iron Man Mode]|r - Conflicts with active challenge modes", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            else
                AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cffFFD700[Iron Man Mode]|r - Ultimate challenge", GOSSIP_SENDER_MAIN, SETTING_IRON_MAN);
        }

        if (sChallengeModes->challengeEnabled(SETTING_IRON_MAN_PLUS))
        {
            if (hasIronManPlus)
                AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cff00FF00[Iron Man+ Mode]|r |cffFFD700(ACTIVE)|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            else if (hasIronMan || hasHardcore || hasSemiHardcore || hasSelfCrafted || hasItemQuality || hasSlowXP || hasVerySlowXP || hasQuestXPOnly)
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff666666[Iron Man+ Mode]|r - Conflicts with active challenge modes", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            else
                AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cffFFD700[Iron Man+ Mode]|r - No talents/glyphs/groups/dungeons/professions", GOSSIP_SENDER_MAIN, SETTING_IRON_MAN_PLUS);
        }

        // Random picker (chooses ONE mode).
        if (sChallengeModes->enabled())
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[Random Challenge Mode]|r - Pick one at random", GOSSIP_SENDER_MAIN, ACTION_RANDOM_INFO);

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_CLOSE);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, GameObject* go, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);

        // DarkChaos-255: THREE-STEP FLOW
        // Action codes:
        // 0-99: Show information page for a specific setting (by enum id)
        // 100-199: Show confirmation page
        // 200-299: Confirmed - activate mode
        // 999: Close
        // 9999: Do nothing (non-clickable items)

        if (action == ACTION_GOSSIP_CLOSE) // Close
        {
            CloseGossipMenuFor(player);
            return true;
        }

        if (action == ACTION_RANDOM_INFO)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700=== RANDOM CHALLENGE MODE ===|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "This will randomly choose ONE challenge mode", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "from the currently enabled modes.", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000This decision is PERMANENT!|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cff00ff00[Continue] Roll a random mode|r", GOSSIP_SENDER_MAIN, ACTION_RANDOM_CONFIRM);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[<< Back] Return to mode selection|r", GOSSIP_SENDER_MAIN, 998);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_CLOSE);

            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
            return true;
        }

        if (action == ACTION_RANDOM_CONFIRM)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700=== FINAL CONFIRMATION ===|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "You are about to activate a randomly selected", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "challenge mode.", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000This decision is PERMANENT!|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cff00ff00[CONFIRM] Yes, pick for me!|r", GOSSIP_SENDER_MAIN, ACTION_RANDOM_ACTIVATE);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[<< Back] Let me reconsider...|r", GOSSIP_SENDER_MAIN, ACTION_RANDOM_INFO);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_CLOSE);

            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
            return true;
        }

        if (action == ACTION_RANDOM_ACTIVATE)
        {
            // Random should never stack with existing modes.
            if (PlayerHasAnyActiveChallengeMode(player))
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000CONFLICT DETECTED!|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "A challenge mode is already active.", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Random selection only works when none are active.", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[<< Back] Return to mode selection|r", GOSSIP_SENDER_MAIN, 998);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_CLOSE);
                SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
                return true;
            }

            std::vector<ChallengeModeSettings> eligible = GetEligibleRandomChallengeModes(player);
            if (eligible.empty())
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF8800No eligible challenge modes available.|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Either ChallengeModes are disabled, or all modes", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "are disabled by config / level restrictions.", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[<< Back] Return to mode selection|r", GOSSIP_SENDER_MAIN, 998);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_CLOSE);
                SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
                return true;
            }

            ChallengeModeSettings picked = eligible[urand(0, eligible.size() - 1)];

            // Activate the picked mode.
            player->UpdatePlayerSetting("mod-challenge-modes", picked, 1);
            sChallengeModes->RefreshChallengeAuras(player);

            if (picked == SETTING_IRON_MAN || picked == SETTING_IRON_MAN_PLUS)
                ApplyIronManOrPlusImmediateRestrictions(player);

            ChallengeModeDatabase::InitializeTracking(player->GetGUID());
            ChallengeModeDatabase::SyncActiveModesFromSettings(player);

            std::string title = GetChallengeTitle(picked);
            std::string activationMsg = "|cff00ff00Challenge Mode Activated (Random):|r " + title;

            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff00ff00=== CHALLENGE ACTIVATED ===|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Random pick result:", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, title, GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700Good luck on your journey!|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_CLOSE);

            if (player->GetSession())
                ChatHandler(player->GetSession()).PSendSysMessage("%s", activationMsg.c_str());

            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
            return true;
        }

        if (action == ACTION_GOSSIP_NOOP) // Non-clickable items
        {
            return OnGossipHello(player, go);
        }

        if (action == ACTION_PRESTIGE_OVERVIEW)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffffd700Prestige Overview|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);

            if (!PrestigeAPI::IsEnabled())
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff888888The prestige system is currently disabled.|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            }
            else
            {
                uint32 prestigeLevel = PrestigeAPI::GetPrestigeLevel(player);
                uint32 maxPrestige = PrestigeAPI::GetMaxPrestigeLevel();
                uint32 statBonusPercent = PrestigeAPI::GetStatBonusPercent();
                uint32 requiredLevel = PrestigeAPI::GetRequiredLevel();
                uint32 nextPrestige = prestigeLevel + 1;
                uint32 nextBonus = nextPrestige * statBonusPercent;

                // Alt Bonus Info
                uint32 altBonus = PrestigeAPI::GetAltBonusPercent(player);
                uint32 maxLevelChars = PrestigeAPI::GetAccountMaxLevelCount(player->GetSession()->GetAccountId());
                uint32 currentStatBonus = prestigeLevel * statBonusPercent;

                AddGossipItemFor(player, GOSSIP_ICON_DOT, Acore::StringFormat("Prestige Level: {} / {}", prestigeLevel, maxPrestige), GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
                AddGossipItemFor(player, GOSSIP_ICON_DOT, Acore::StringFormat("Current Bonus: {}% (Stats)", currentStatBonus), GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);

                if (altBonus > 0)
                {
                    AddGossipItemFor(player, GOSSIP_ICON_DOT, Acore::StringFormat("Alt Bonus: {}% XP ({} Max-Level Chars)", altBonus, maxLevelChars), GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
                }
                else
                {
                     AddGossipItemFor(player, GOSSIP_ICON_DOT, "Alt Bonus: 0% XP (No Max-Level Chars)", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
                }

                AddGossipItemFor(player, GOSSIP_ICON_DOT, Acore::StringFormat("Required Level to Prestige: {}", requiredLevel), GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);

                if (PrestigeAPI::CanPrestige(player))
                {
                    AddGossipItemFor(player, GOSSIP_ICON_BATTLE, Acore::StringFormat("|cff00ff00[Prestige Now ({}% Bonus)]|r", nextBonus), GOSSIP_SENDER_MAIN, ACTION_PRESTIGE_WARNINGS);
                }
                else if (prestigeLevel >= maxPrestige)
                {
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700You have reached the maximum prestige level.|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
                }
                else
                {
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff888888Requirements not yet met.|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
                }
            }

            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[<< Back]|r", GOSSIP_SENDER_MAIN, 998);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_CLOSE);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
            return true;
        }

        if (action == ACTION_PRESTIGE_WARNINGS)
        {
            if (!PrestigeAPI::IsEnabled())
            {
                ChatHandler(player->GetSession()).PSendSysMessage("Prestige system is currently disabled.");
                return OnGossipHello(player, go);
            }

            if (!PrestigeAPI::CanPrestige(player))
            {
                ChatHandler(player->GetSession()).PSendSysMessage("You cannot prestige at this time.");
                return OnGossipHello(player, go);
            }

            uint32 nextPrestige = PrestigeAPI::GetPrestigeLevel(player) + 1;
            uint32 nextBonus = nextPrestige * PrestigeAPI::GetStatBonusPercent();

            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffff4500Prestige Warning|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, Acore::StringFormat("You are about to begin Prestige {}.", nextPrestige), GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffff0000This will reset you to level 1.|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, Acore::StringFormat("|cffffd700You will gain a total of {}% bonus to all stats.|r", nextBonus), GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffff8800You will retain configured prestige rewards.|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_NOOP);
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cff00ff00[Confirm Prestige]|r", GOSSIP_SENDER_MAIN, ACTION_PRESTIGE_CONFIRM);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[<< Back]|r", GOSSIP_SENDER_MAIN, 998);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_CLOSE);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
            return true;
        }

        if (action == ACTION_PRESTIGE_CONFIRM)
        {
            if (!PrestigeAPI::IsEnabled() || !PrestigeAPI::CanPrestige(player))
            {
                ChatHandler(player->GetSession()).PSendSysMessage("You cannot prestige at this time.");
                return OnGossipHello(player, go);
            }

            PrestigeAPI::PerformPrestige(player);
            CloseGossipMenuFor(player);
            return true;
        }

        if (action < 100) // Step 1: Show detailed information
        {
            ChallengeModeSettings setting = static_cast<ChallengeModeSettings>(action);

            if (g_ChallengeSettingConfigs.find(setting) == g_ChallengeSettingConfigs.end())
                return OnGossipHello(player, go);

            std::string explanation = GetChallengeExplanation(setting);
            std::string title = GetChallengeTitle(setting);

            // Display information in gossip
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, title, GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);

            // Split explanation into lines for better display
            size_t pos = 0;
            size_t lastPos = 0;
            while ((pos = explanation.find("\n", lastPos)) != std::string::npos)
            {
                std::string line = explanation.substr(lastPos, pos - lastPos);
                if (!line.empty())
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, 9999);
                lastPos = pos + 1;
            }
            // Add last line
            if (lastPos < explanation.length())
            {
                std::string line = explanation.substr(lastPos);
                if (!line.empty())
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, line, GOSSIP_SENDER_MAIN, 9999);
            }

            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cff00ff00[Continue] I want to activate this mode|r", GOSSIP_SENDER_MAIN, action + 100);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[<< Back] Return to mode selection|r", GOSSIP_SENDER_MAIN, 998);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_CLOSE);

            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
            return true;
        }

        if (action == 998) // Back to main menu
        {
            return OnGossipHello(player, go);
        }

        if (action >= 100 && action < 200) // Step 2: Show confirmation
        {
            uint32 challengeId = action - 100;
            ChallengeModeSettings setting = static_cast<ChallengeModeSettings>(challengeId);
            std::string title = GetChallengeTitle(setting);

            if (g_ChallengeSettingConfigs.find(setting) == g_ChallengeSettingConfigs.end())
                return OnGossipHello(player, go);

            // Check if already enabled
            if (sChallengeModes->challengeEnabledForPlayer(setting, player))
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF8800WARNING: Mode Already Active!|r", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "You already have this challenge mode active!", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[<< Back] Return to mode selection|r", GOSSIP_SENDER_MAIN, 998);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_CLOSE);
                SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
                return true;
            }

            // Conflict checks
            if (setting == SETTING_HARDCORE && sChallengeModes->challengeEnabledForPlayer(SETTING_SEMI_HARDCORE, player))
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000CONFLICT DETECTED!|r", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Cannot enable Hardcore while", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Semi-Hardcore is active!", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[<< Back] Return to mode selection|r", GOSSIP_SENDER_MAIN, 998);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_CLOSE);
                SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
                return true;
            }

            if (setting == SETTING_SEMI_HARDCORE && sChallengeModes->challengeEnabledForPlayer(SETTING_HARDCORE, player))
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000CONFLICT DETECTED!|r", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Cannot enable Semi-Hardcore while", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Hardcore is active!", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[<< Back] Return to mode selection|r", GOSSIP_SENDER_MAIN, 998);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_CLOSE);
                SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
                return true;
            }

            // Iron Man conflicts with Hardcore, Semi-Hardcore, Self-Crafted, and Item Quality (it includes these)
            if (setting == SETTING_IRON_MAN)
            {
                bool hasConflict = sChallengeModes->challengeEnabledForPlayer(SETTING_HARDCORE, player) ||
                                   sChallengeModes->challengeEnabledForPlayer(SETTING_SEMI_HARDCORE, player) ||
                                   sChallengeModes->challengeEnabledForPlayer(SETTING_SELF_CRAFTED, player) ||
                                   sChallengeModes->challengeEnabledForPlayer(SETTING_ITEM_QUALITY_LEVEL, player) ||
                                   sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN_PLUS, player);
                if (hasConflict)
                {
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000CONFLICT DETECTED!|r", GOSSIP_SENDER_MAIN, 9999);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Iron Man includes Hardcore, Self-Crafted,", GOSSIP_SENDER_MAIN, 9999);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "and Item Quality restrictions.", GOSSIP_SENDER_MAIN, 9999);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "You already have one of these active!", GOSSIP_SENDER_MAIN, 9999);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[<< Back] Return to mode selection|r", GOSSIP_SENDER_MAIN, 998);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_CLOSE);
                    SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
                    return true;
                }
            }

            // Iron Man+ conflicts with ALL other modes (it includes restrictions that overlap).
            if (setting == SETTING_IRON_MAN_PLUS)
            {
                bool hasConflict = sChallengeModes->challengeEnabledForPlayer(SETTING_HARDCORE, player) ||
                                   sChallengeModes->challengeEnabledForPlayer(SETTING_SEMI_HARDCORE, player) ||
                                   sChallengeModes->challengeEnabledForPlayer(SETTING_SELF_CRAFTED, player) ||
                                   sChallengeModes->challengeEnabledForPlayer(SETTING_ITEM_QUALITY_LEVEL, player) ||
                                   sChallengeModes->challengeEnabledForPlayer(SETTING_SLOW_XP_GAIN, player) ||
                                   sChallengeModes->challengeEnabledForPlayer(SETTING_VERY_SLOW_XP_GAIN, player) ||
                                   sChallengeModes->challengeEnabledForPlayer(SETTING_QUEST_XP_ONLY, player) ||
                                   sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN, player);
                if (hasConflict)
                {
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000CONFLICT DETECTED!|r", GOSSIP_SENDER_MAIN, 9999);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Iron Man+ cannot be enabled with any other", GOSSIP_SENDER_MAIN, 9999);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "challenge mode already active.", GOSSIP_SENDER_MAIN, 9999);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[<< Back] Return to mode selection|r", GOSSIP_SENDER_MAIN, 998);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_CLOSE);
                    SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
                    return true;
                }
            }

            // Cannot enable individual modes if Iron Man is active
            if ((setting == SETTING_HARDCORE || setting == SETTING_SEMI_HARDCORE ||
                 setting == SETTING_SELF_CRAFTED || setting == SETTING_ITEM_QUALITY_LEVEL) &&
                IsIronManOrPlusActive(player))
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000CONFLICT DETECTED!|r", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Iron Man mode is already active!", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "It includes this challenge mode.", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[<< Back] Return to mode selection|r", GOSSIP_SENDER_MAIN, 998);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_CLOSE);
                SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
                return true;
            }

            // XP modes are mutually exclusive
            if (setting == SETTING_SLOW_XP_GAIN || setting == SETTING_VERY_SLOW_XP_GAIN || setting == SETTING_QUEST_XP_ONLY)
            {
                bool hasOtherXPMode = false;
                std::string conflictName;
                if (setting != SETTING_SLOW_XP_GAIN && sChallengeModes->challengeEnabledForPlayer(SETTING_SLOW_XP_GAIN, player))
                {
                    hasOtherXPMode = true;
                    conflictName = "Slow XP Gain";
                }
                else if (setting != SETTING_VERY_SLOW_XP_GAIN && sChallengeModes->challengeEnabledForPlayer(SETTING_VERY_SLOW_XP_GAIN, player))
                {
                    hasOtherXPMode = true;
                    conflictName = "Very Slow XP Gain";
                }
                else if (setting != SETTING_QUEST_XP_ONLY && sChallengeModes->challengeEnabledForPlayer(SETTING_QUEST_XP_ONLY, player))
                {
                    hasOtherXPMode = true;
                    conflictName = "Quest XP Only";
                }

                if (hasOtherXPMode)
                {
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000CONFLICT DETECTED!|r", GOSSIP_SENDER_MAIN, 9999);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Only one XP modification mode can be active.", GOSSIP_SENDER_MAIN, 9999);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, conflictName + " is already enabled!", GOSSIP_SENDER_MAIN, 9999);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[<< Back] Return to mode selection|r", GOSSIP_SENDER_MAIN, 998);
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_CLOSE);
                    SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
                    return true;
                }
            }

            // Show confirmation dialog
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700=== FINAL CONFIRMATION ===|r", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "You are about to activate:", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, title, GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000This decision is PERMANENT!|r", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Once activated, this mode cannot be disabled.", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cff00ff00[CONFIRM] Yes, I accept the challenge!|r", GOSSIP_SENDER_MAIN, action + 100);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[<< Back] Let me reconsider...|r", GOSSIP_SENDER_MAIN, 998);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_CLOSE);

            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
            return true;
        }

        if (action >= 200 && action < 300) // Step 3: Activate challenge mode
        {
            uint32 challengeId = action - 200;
            ChallengeModeSettings setting = static_cast<ChallengeModeSettings>(challengeId);

            // Validate that this is a real, selectable setting (prevents out-of-range / reserved writes)
            if (g_ChallengeSettingConfigs.find(setting) == g_ChallengeSettingConfigs.end())
            {
                ChatHandler(player->GetSession()).SendSysMessage("Invalid challenge mode selection.");
                CloseGossipMenuFor(player);
                return true;
            }

            // Activate challenge mode
            player->UpdatePlayerSetting("mod-challenge-modes", setting, 1);
            sChallengeModes->RefreshChallengeAuras(player);

            // Apply immediate restrictions for Iron Man / Iron Man+ (so the player can't keep talents/glyphs/groups).
            if (setting == SETTING_IRON_MAN || setting == SETTING_IRON_MAN_PLUS)
                ApplyIronManOrPlusImmediateRestrictions(player);

            // Persist active modes to tracking DB (optional analytics / admin tooling)
            ChallengeModeDatabase::InitializeTracking(player->GetGUID());
            ChallengeModeDatabase::SyncActiveModesFromSettings(player);

            std::string title = GetChallengeTitle(setting);
            std::string activationMsg = "|cff00ff00Challenge Mode Activated:|r " + title;

            // Success message
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff00ff00=== CHALLENGE ACTIVATED ===|r", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, title + " is now ACTIVE!", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700Good luck on your journey!|r", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700May the odds be ever in your favor!|r", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, ACTION_GOSSIP_CLOSE);

            ChatHandler(player->GetSession()).PSendSysMessage("%s", activationMsg.c_str());

            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
            return true;
        }

        return false;
    }
};

class ChallengeMode_BotAutoAssign : public PlayerScript
{
public:
    ChallengeMode_BotAutoAssign() : PlayerScript("ChallengeMode_BotAutoAssign") { }

    void OnPlayerLogin(Player* player) override
    {
        if (!gobject_challenge_modes::IsBotPlayer(player))
            return;

        if (!sChallengeModes->enabled())
            return;

        if (gobject_challenge_modes::PlayerHasAnyActiveChallengeMode(player))
            return;

        static constexpr uint8 kBotChallengeOptInChance = 30;
        if (urand(1, 100) > kBotChallengeOptInChance)
            return;

        std::vector<ChallengeModeSettings> eligible = gobject_challenge_modes::GetEligibleRandomChallengeModes(player);
        if (eligible.empty())
            return;

        eligible.erase(std::remove_if(eligible.begin(), eligible.end(), [](ChallengeModeSettings setting)
        {
            return setting == SETTING_IRON_MAN || setting == SETTING_IRON_MAN_PLUS;
        }), eligible.end());

        if (eligible.empty())
            return;

        ChallengeModeSettings picked = eligible[urand(0, eligible.size() - 1)];

        player->UpdatePlayerSetting("mod-challenge-modes", picked, 1);
        sChallengeModes->RefreshChallengeAuras(player);

        if (picked == SETTING_IRON_MAN || picked == SETTING_IRON_MAN_PLUS)
            gobject_challenge_modes::ApplyIronManOrPlusImmediateRestrictions(player);

        ChallengeModeDatabase::InitializeTracking(player->GetGUID());
        ChallengeModeDatabase::SyncActiveModesFromSettings(player);
    }
};

// ==============================================
// DarkChaos-255: SCRIPT REGISTRATION
// ==============================================

// Scripts moved to ChallengeModeScripts.cpp
extern void AddSC_challenge_mode_scripts();

void AddSC_dc_challenge_modes()
{
    new ChallengeModes_WorldScript();
    new gobject_challenge_modes();
    new ChallengeMode_BotAutoAssign();

    // Register scripts from ChallengeModeScripts.cpp
    AddSC_challenge_mode_scripts();
}
