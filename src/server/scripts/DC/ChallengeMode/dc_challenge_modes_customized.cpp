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

using namespace Acore::ChatCommands;

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
        default:
            return 1;
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

        default:
            return "Unknown challenge mode.";
    }
}

std::string GetChallengeTitle(ChallengeModeSettings setting)
{
    switch(setting)
    {
        case SETTING_HARDCORE:           return "Hardcore";
        case SETTING_SEMI_HARDCORE:      return "Semi-Hardcore";
        case SETTING_SELF_CRAFTED:       return "Self-Crafted";
        case SETTING_ITEM_QUALITY_LEVEL: return "Item Quality Restriction";
        case SETTING_SLOW_XP_GAIN:       return "Slow XP Gain";
        case SETTING_VERY_SLOW_XP_GAIN:  return "Very Slow XP Gain";
        case SETTING_QUEST_XP_ONLY:      return "Quest XP Only";
        case SETTING_IRON_MAN:           return "Iron Man";
        default:                         return "Unknown";
    }
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

    bool OnGossipHello(Player* player, GameObject* /*go*/) override
    {
        if (!sChallengeModes->enabled())
            return false;

        // DarkChaos-255: LEVEL CHECK REMOVED - Usable at any level including 255
        // Original had: if (player->getLevel() > 5) return false;

        ClearGossipMenuFor(player);

        // Title and instructions
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700=== Challenge Mode Manager ===|r", GOSSIP_SENDER_MAIN, 9999);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFFFFFSelect a mode to view details:|r", GOSSIP_SENDER_MAIN, 9999);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);

        // Show challenge mode selection menu
        if (sChallengeModes->challengeEnabled(SETTING_HARDCORE))
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cffFF0000[Hardcore Mode]|r - Death is permanent", GOSSIP_SENDER_MAIN, SETTING_HARDCORE);

        if (sChallengeModes->challengeEnabled(SETTING_SEMI_HARDCORE))
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cffFF8800[Semi-Hardcore Mode]|r - Severe death penalty", GOSSIP_SENDER_MAIN, SETTING_SEMI_HARDCORE);

        if (sChallengeModes->challengeEnabled(SETTING_SELF_CRAFTED))
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cff00ffff[Self-Crafted Mode]|r - Only use crafted gear", GOSSIP_SENDER_MAIN, SETTING_SELF_CRAFTED);

        if (sChallengeModes->challengeEnabled(SETTING_ITEM_QUALITY_LEVEL))
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "|cffaaaaaa[Item Quality Restriction]|r - White/gray items only", GOSSIP_SENDER_MAIN, SETTING_ITEM_QUALITY_LEVEL);

        if (sChallengeModes->challengeEnabled(SETTING_SLOW_XP_GAIN))
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff8888ff[Slow XP Gain]|r - 50% XP rate", GOSSIP_SENDER_MAIN, SETTING_SLOW_XP_GAIN);

        if (sChallengeModes->challengeEnabled(SETTING_VERY_SLOW_XP_GAIN))
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff4444ff[Very Slow XP Gain]|r - 25% XP rate", GOSSIP_SENDER_MAIN, SETTING_VERY_SLOW_XP_GAIN);

        if (sChallengeModes->challengeEnabled(SETTING_QUEST_XP_ONLY))
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff00ff88[Quest XP Only]|r - No XP from kills", GOSSIP_SENDER_MAIN, SETTING_QUEST_XP_ONLY);

        if (sChallengeModes->challengeEnabled(SETTING_IRON_MAN))
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cffFFD700[Iron Man Mode]|r - Ultimate challenge", GOSSIP_SENDER_MAIN, SETTING_IRON_MAN);

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, 999);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, player->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, GameObject* go, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);

        // DarkChaos-255: THREE-STEP FLOW
        // Action codes:
        // 0-7: Show information page
        // 100-107: Show confirmation page
        // 200-207: Confirmed - activate mode
        // 999: Close
        // 9999: Do nothing (non-clickable items)

        if (action == 999) // Close
        {
            CloseGossipMenuFor(player);
            return true;
        }

        if (action == 9999) // Non-clickable items
        {
            return OnGossipHello(player, go);
        }

        if (action < 100) // Step 1: Show detailed information
        {
            ChallengeModeSettings setting = static_cast<ChallengeModeSettings>(action);
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
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, 999);
            
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
            
            // Check if already enabled
            if (sChallengeModes->challengeEnabledForPlayer(setting, player))
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF8800WARNING: Mode Already Active!|r", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "You already have this challenge mode active!", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[<< Back] Return to mode selection|r", GOSSIP_SENDER_MAIN, 998);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, 999);
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
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, 999);
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
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, 999);
                SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
                return true;
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
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, 999);
            
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
            return true;
        }
        
        if (action >= 200 && action < 300) // Step 3: Activate challenge mode
        {
            uint32 challengeId = action - 200;
            ChallengeModeSettings setting = static_cast<ChallengeModeSettings>(challengeId);
            
            // Activate challenge mode
            player->UpdatePlayerSetting("mod-challenge-modes", setting, 1);
            
            std::string title = GetChallengeTitle(setting);
            
            // Success message
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff00ff00=== CHALLENGE ACTIVATED ===|r", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, title + " is now ACTIVE!", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700Good luck on your journey!|r", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700May the odds be ever in your favor!|r", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 9999);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFF0000[Close]|r", GOSSIP_SENDER_MAIN, 999);
            
            ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00Challenge Mode Activated:|r %s", title.c_str());
            
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
            return true;
        }

        return false;
    }
};

// ==============================================
// DarkChaos-255: HARDCORE CHARACTER LOCKING
// ==============================================
void HandleHardcoreDeath(Player* victim, std::string killerName)
{
    // Mark character as permanently dead
    victim->UpdatePlayerSetting("mod-challenge-modes", HARDCORE_DEAD, 1);
    
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
    ChatHandler(victim->GetSession()).PSendSysMessage("Final Level: %u", (uint32)victim->GetLevel());
    ChatHandler(victim->GetSession()).PSendSysMessage("Killed by: %s", killerName.c_str());
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFF0000This character is now PERMANENTLY LOCKED.|r");
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFF0000You will not be able to log in with this character anymore.|r");
    ChatHandler(victim->GetSession()).PSendSysMessage("|cffFF0000========================================|r");
}

// Hardcore mode player script
class ChallengeMode_Hardcore : public PlayerScript
{
public:
    ChallengeMode_Hardcore() : PlayerScript("ChallengeMode_Hardcore") { }

    void OnPlayerKilledByCreature(Creature* killer, Player* victim) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_HARDCORE, victim))
            return;

        HandleHardcoreDeath(victim, killer->GetName());
        
        // Make player a permanent ghost (original functionality)
        victim->SetPvPDeath(true);
    }

    void OnPlayerPVPKill(Player* killer, Player* victim) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_HARDCORE, victim))
            return;

        HandleHardcoreDeath(victim, killer->GetName());
        
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
    ChallengeModes_LoginPrevention() : PlayerScript("ChallengeModes_LoginPrevention") { }

    void OnPlayerLogin(Player* player) override
    {
        // Check if character died in hardcore mode
        if (player->GetPlayerSetting("mod-challenge-modes", HARDCORE_DEAD).value == 1)
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
            return;
        }
    }
};

// ==============================================
// DarkChaos-255: .CHALLENGE INFO COMMAND
// ==============================================
class ChallengeModes_CommandScript : public CommandScript
{
public:
    ChallengeModes_CommandScript() : CommandScript("ChallengeModes_CommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandTable =
        {
            { "challenge", HandleChallengeInfoCommand, SEC_PLAYER, Console::No }
        };
        return commandTable;
    }

    static bool HandleChallengeInfoCommand(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetSession()->GetPlayer();
        
        handler->PSendSysMessage("|cff00ff00========================================|r");
        handler->PSendSysMessage("|cff00ff00   ACTIVE CHALLENGE MODES|r");
        handler->PSendSysMessage("|cff00ff00========================================|r");
        
        bool hasAnyChallenges = false;
        
        // Check each challenge type
        if (sChallengeModes->challengeEnabledForPlayer(SETTING_HARDCORE, player))
        {
            handler->PSendSysMessage("|cffFF0000[HARDCORE]|r Active - One life only!");
            hasAnyChallenges = true;
        }
        
        if (sChallengeModes->challengeEnabledForPlayer(SETTING_SEMI_HARDCORE, player))
        {
            handler->PSendSysMessage("|cffFF8800[SEMI-HARDCORE]|r Active - Death = Gear loss");
            hasAnyChallenges = true;
        }
        
        if (sChallengeModes->challengeEnabledForPlayer(SETTING_SELF_CRAFTED, player))
        {
            handler->PSendSysMessage("|cff00ffff[SELF-CRAFTED]|r Active - Crafted gear only");
            hasAnyChallenges = true;
        }
        
        if (sChallengeModes->challengeEnabledForPlayer(SETTING_ITEM_QUALITY_LEVEL, player))
        {
            handler->PSendSysMessage("|cffaaaaaa[ITEM QUALITY]|r Active - White/gray only");
            hasAnyChallenges = true;
        }
        
        if (sChallengeModes->challengeEnabledForPlayer(SETTING_SLOW_XP_GAIN, player))
        {
            handler->PSendSysMessage("|cff8888ff[SLOW XP]|r Active - 50%% XP rate");
            hasAnyChallenges = true;
        }
        
        if (sChallengeModes->challengeEnabledForPlayer(SETTING_VERY_SLOW_XP_GAIN, player))
        {
            handler->PSendSysMessage("|cff4444ff[VERY SLOW XP]|r Active - 25%% XP rate");
            hasAnyChallenges = true;
        }
        
        if (sChallengeModes->challengeEnabledForPlayer(SETTING_QUEST_XP_ONLY, player))
        {
            handler->PSendSysMessage("|cff00ff88[QUEST XP ONLY]|r Active - Quests only");
            hasAnyChallenges = true;
        }
        
        if (sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN, player))
        {
            handler->PSendSysMessage("|cffFFD700[IRON MAN]|r Active - Ultimate challenge!");
            hasAnyChallenges = true;
        }
        
        if (!hasAnyChallenges)
        {
            handler->PSendSysMessage("No active challenge modes.");
            handler->PSendSysMessage("Visit a Challenge Shrine to begin your journey!");
        }
        
        handler->PSendSysMessage("|cff00ff00========================================|r");
        
        return true;
    }
};

// ==============================================
// DarkChaos-255: SCRIPT REGISTRATION
// ==============================================
void AddSC_dc_challenge_modes()
{
    new ChallengeModes_WorldScript();
    new gobject_challenge_modes();
    new ChallengeMode_Hardcore();
    new ChallengeModes_LoginPrevention();
    new ChallengeModes_CommandScript();
}
