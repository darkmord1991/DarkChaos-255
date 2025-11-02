// This file has been intentionally reduced to a stub to avoid duplicate symbol
// definitions when the customized implementation is used. The real
// implementation lives in dc_challenge_modes_customized.cpp and should be
// the single translation unit providing the ChallengeModes symbols.

// Keep a minimal include to ensure this file still compiles if present.
#include "dc_challenge_modes.h"

// No symbols defined here to prevent multiple-definition linker errors.
{
public:
    ChallengeMode_SelfCrafted() : ChallengeMode("ChallengeMode_SelfCrafted", SETTING_SELF_CRAFTED) {}

    bool OnPlayerCanEquipItem(Player* player, uint8 /*slot*/, uint16& /*dest*/, Item* pItem, bool /*swap*/, bool /*not_loading*/) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_SELF_CRAFTED, player))
        {
            return true;
        }
        if (!pItem->GetTemplate()->HasSignature())
        {
            return false;
        }
        return pItem->GetGuidValue(ITEM_FIELD_CREATOR) == player->GetGUID();
    }

    void OnPlayerGiveXP(Player* player, uint32& amount, Unit* victim, uint8 xpSource) override
    {
        ChallengeMode::OnPlayerGiveXP(player, amount, victim, xpSource);
    }

    void OnPlayerLevelChanged(Player* player, uint8 oldlevel) override
    {
        ChallengeMode::OnPlayerLevelChanged(player, oldlevel);
    }
};

class ChallengeMode_ItemQualityLevel : public ChallengeMode
{
public:
    ChallengeMode_ItemQualityLevel() : ChallengeMode("ChallengeMode_ItemQualityLevel", SETTING_ITEM_QUALITY_LEVEL) {}

    bool OnPlayerCanEquipItem(Player* player, uint8 /*slot*/, uint16& /*dest*/, Item* pItem, bool /*swap*/, bool /*not_loading*/) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_ITEM_QUALITY_LEVEL, player))
        {
            return true;
        }
        return pItem->GetTemplate()->Quality <= ITEM_QUALITY_NORMAL;
    }

    void OnPlayerGiveXP(Player* player, uint32& amount, Unit* victim, uint8 xpSource) override
    {
        ChallengeMode::OnPlayerGiveXP(player, amount, victim, xpSource);
    }

    void OnPlayerLevelChanged(Player* player, uint8 oldlevel) override
    {
        ChallengeMode::OnPlayerLevelChanged(player, oldlevel);
    }
};

class ChallengeMode_SlowXpGain : public ChallengeMode
{
public:
    ChallengeMode_SlowXpGain() : ChallengeMode("ChallengeMode_SlowXpGain", SETTING_SLOW_XP_GAIN) {}

    void OnPlayerGiveXP(Player* player, uint32& amount, Unit* victim, uint8 xpSource) override
    {
        ChallengeMode::OnPlayerGiveXP(player, amount, victim, xpSource);
    }

    void OnPlayerLevelChanged(Player* player, uint8 oldlevel) override
    {
        ChallengeMode::OnPlayerLevelChanged(player, oldlevel);
    }
};

class ChallengeMode_VerySlowXpGain : public ChallengeMode
{
public:
    ChallengeMode_VerySlowXpGain() : ChallengeMode("ChallengeMode_VerySlowXpGain", SETTING_VERY_SLOW_XP_GAIN) {}

    void OnPlayerGiveXP(Player* player, uint32& amount, Unit* victim, uint8 xpSource) override
    {
        ChallengeMode::OnPlayerGiveXP(player, amount, victim, xpSource);
    }

    void OnPlayerLevelChanged(Player* player, uint8 oldlevel) override
    {
        ChallengeMode::OnPlayerLevelChanged(player, oldlevel);
    }
};

class ChallengeMode_QuestXpOnly : public ChallengeMode
{
public:
    ChallengeMode_QuestXpOnly() : ChallengeMode("ChallengeMode_QuestXpOnly", SETTING_QUEST_XP_ONLY) {}

    void OnPlayerGiveXP(Player* player, uint32& amount, Unit* victim, uint8 xpSource) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_QUEST_XP_ONLY, player))
        {
            return;
        }
        if (victim)
        {
            // Still award XP to pets - they won't be able to pass the player's level
            Pet* pet = player->GetPet();
            if (pet && xpSource == XPSOURCE_KILL)
                pet->GivePetXP(player->GetGroup() ? amount / 2 : amount);
            amount = 0;
        }
        else
        {
            ChallengeMode::OnPlayerGiveXP(player, amount, victim, xpSource);
        }
    }

    void OnPlayerLevelChanged(Player* player, uint8 oldlevel) override
    {
        ChallengeMode::OnPlayerLevelChanged(player, oldlevel);
    }
};

class ChallengeMode_IronMan : public ChallengeMode
{
public:
    ChallengeMode_IronMan() : ChallengeMode("ChallengeMode_IronMan", SETTING_IRON_MAN) {}

    void OnPlayerResurrect(Player* player, float /*restore_percent*/, bool /*applySickness*/) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN, player))
        {
            return;
        }
        // A better implementation is to not allow the resurrect but this will need a new hook added first
        player->KillPlayer();
    }

    void OnPlayerGiveXP(Player* player, uint32& amount, Unit* victim, uint8 xpSource) override
    {
        ChallengeMode::OnPlayerGiveXP(player, amount, victim, xpSource);
    }

    void OnPlayerLevelChanged(Player* player, uint8 oldlevel) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN, player))
        {
            return;
        }
        player->SetFreeTalentPoints(0); // Remove all talent points
        ChallengeMode::OnPlayerLevelChanged(player, oldlevel);
    }

    void OnPlayerTalentsReset(Player* player, bool /*noCost*/) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN, player))
        {
            return;
        }
        player->SetFreeTalentPoints(0); // Remove all talent points
    }

    bool OnPlayerCanEquipItem(Player* player, uint8 /*slot*/, uint16& /*dest*/, Item* pItem, bool /*swap*/, bool /*not_loading*/) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN, player))
        {
            return true;
        }
        return pItem->GetTemplate()->Quality <= ITEM_QUALITY_NORMAL;
    }

    bool OnPlayerCanApplyEnchantment(Player* player, Item* /*item*/, EnchantmentSlot /*slot*/, bool /*apply*/, bool /*apply_dur*/, bool /*ignore_condition*/) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN, player))
        {
            return true;
        }
        // Are there any exceptions in WotLK? If so need to be added here
        return false;
    }

    void OnPlayerLearnSpell(Player* player, uint32 spellID) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN, player))
        {
            return;
        }
        // These professions are class skills so they are always acceptable
        switch (spellID)
        {
            case RUNEFORGING:
            case POISONS:
            case BEAST_TRAINING:
                return;
            default:
                break;
        }
        // Do not allow learning any trade skills
        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellID);
        if (!spellInfo)
            return;
        bool shouldForget = false;
        for (uint8 i = 0; i < 3; i++)
        {
            if (spellInfo->Effects[i].Effect == SPELL_EFFECT_TRADE_SKILL)
            {
                shouldForget = true;
            }
        }
        if (shouldForget)
        {
            player->removeSpell(spellID, SPEC_MASK_ALL, false);
        }
    }

    bool OnPlayerCanUseItem(Player* player, ItemTemplate const* proto, InventoryResult& /*result*/) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN, player))
        {
            return true;
        }
        // Do not allow using elixir, potion, or flask
        if (proto->Class == ITEM_CLASS_CONSUMABLE &&
                (proto->SubClass == ITEM_SUBCLASS_POTION ||
                proto->SubClass == ITEM_SUBCLASS_ELIXIR ||
                proto->SubClass == ITEM_SUBCLASS_FLASK))
        {
            return false;
        }
        // Do not allow food that gives food buffs
        if (proto->Class == ITEM_CLASS_CONSUMABLE && proto->SubClass == ITEM_SUBCLASS_FOOD)
        {
            for (const auto & Spell : proto->Spells)
            {
                SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(Spell.SpellId);
                if (!spellInfo)
                    continue;

                for (uint8 i = 0; i < 3; i++)
                {
                    if (spellInfo->Effects[i].ApplyAuraName == SPELL_AURA_PERIODIC_TRIGGER_SPELL)
                    {
                        return false;
                    }
                }
            }
        }
        return true;
    }

    bool OnPlayerCanGroupInvite(Player* player, std::string& /*membername*/) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN, player))
        {
            return true;
        }
        return false;
    }

    bool OnPlayerCanGroupAccept(Player* player, Group* /*group*/) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN, player))
        {
            return true;
        }
        return false;
    }

};

class gobject_challenge_modes : public GameObjectScript
{
private:
    static bool playerSettingEnabled(Player* player, uint8 settingIndex)
    {
        return player->GetPlayerSetting("mod-challenge-modes", settingIndex).value;
    }

public:
    gobject_challenge_modes() : GameObjectScript("gobject_challenge_modes") { }

    struct gobject_challenge_modesAI: GameObjectAI
    {
        explicit gobject_challenge_modesAI(GameObject* object) : GameObjectAI(object) { };

        bool CanBeSeen(Player const* player) override
        {
            if ((player->GetLevel() > 1 && player->getClass() != CLASS_DEATH_KNIGHT) || (player->GetLevel() > 55))
            {
                return false;
            }
            return sChallengeModes->enabled();
        }
    };

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        ClearGossipMenuFor(player);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "What are Challenge Modes?", 0, 999); // Info option
        
        if (sChallengeModes->challengeEnabled(SETTING_HARDCORE) && !playerSettingEnabled(player, SETTING_HARDCORE) && !playerSettingEnabled(player, SETTING_SEMI_HARDCORE))
        {
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Hardcore Mode", 0, SETTING_HARDCORE);
        }
        if (sChallengeModes->challengeEnabled(SETTING_SEMI_HARDCORE) && !playerSettingEnabled(player, SETTING_HARDCORE) && !playerSettingEnabled(player, SETTING_SEMI_HARDCORE))
        {
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Semi-Hardcore Mode", 0, SETTING_SEMI_HARDCORE);
        }
        if (sChallengeModes->challengeEnabled(SETTING_SELF_CRAFTED) && !playerSettingEnabled(player, SETTING_SELF_CRAFTED) && !playerSettingEnabled(player, SETTING_IRON_MAN))
        {
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Self-Crafted Mode", 0, SETTING_SELF_CRAFTED);
        }
        if (sChallengeModes->challengeEnabled(SETTING_ITEM_QUALITY_LEVEL) && !playerSettingEnabled(player, SETTING_ITEM_QUALITY_LEVEL))
        {
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Low Quality Item Mode", 0, SETTING_ITEM_QUALITY_LEVEL);
        }
        if (sChallengeModes->challengeEnabled(SETTING_SLOW_XP_GAIN) && !playerSettingEnabled(player, SETTING_SLOW_XP_GAIN) && !playerSettingEnabled(player, SETTING_VERY_SLOW_XP_GAIN))
        {
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Slow XP Mode", 0, SETTING_SLOW_XP_GAIN);
        }
        if (sChallengeModes->challengeEnabled(SETTING_VERY_SLOW_XP_GAIN) && !playerSettingEnabled(player, SETTING_SLOW_XP_GAIN) && !playerSettingEnabled(player, SETTING_VERY_SLOW_XP_GAIN))
        {
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Very Slow XP Mode", 0, SETTING_VERY_SLOW_XP_GAIN);
        }
        if (sChallengeModes->challengeEnabled(SETTING_QUEST_XP_ONLY) && !playerSettingEnabled(player, SETTING_QUEST_XP_ONLY))
        {
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Quest XP Only Mode", 0, SETTING_QUEST_XP_ONLY);
        }
        if (sChallengeModes->challengeEnabled(SETTING_IRON_MAN) && !playerSettingEnabled(player, SETTING_IRON_MAN) && !playerSettingEnabled(player, SETTING_SELF_CRAFTED))
        {
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Iron Man Mode", 0, SETTING_IRON_MAN);
        }
        SendGossipMenuFor(player, 12669, go->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, GameObject* go, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        
        // General info
        if (action == 999)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "<- Back to Challenge Modes", 0, 1000);
            player->PlayerTalkClass->SendGossipMenu(100001, go->GetGUID());
            return true;
        }
        
        // Back to main menu
        if (action == 1000)
        {
            return OnGossipHello(player, go);
        }
        
        // Show mode information (action 100-199 range)
        if (action >= 100 && action < 200)
        {
            uint32 modeId = action - 100;
            ShowModeInfo(player, go, modeId);
            return true;
        }
        
        // Confirm mode (action 200-299 range)
        if (action >= 200 && action < 300)
        {
            uint32 modeId = action - 200;
            player->UpdatePlayerSetting("mod-challenge-modes", modeId, 1);
            sChallengeModes->RefreshChallengeAuras(player);
            
            std::string modeName = GetModeName(modeId);
            ChatHandler(player->GetSession()).PSendSysMessage("|cFFFFD700Challenge Mode Enabled: {}|r", modeName);
            ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF0000This mode is now PERMANENT for this character!|r");
            
            CloseGossipMenuFor(player);
            return true;
        }
        
        // Show info for selected mode
        ShowModeInfo(player, go, action);
        return true;
    }

private:
    void ShowModeInfo(Player* player, GameObject* go, uint32 modeId)
    {
        ClearGossipMenuFor(player);
        
        std::string description;
        std::string rewards;
        float xpBonus = sChallengeModes->getXpBonusForChallenge((ChallengeModeSettings)modeId);
        
        switch (modeId)
        {
            case SETTING_HARDCORE:
                description = "|cFFFF0000HARDCORE MODE|r\n"
                             "Death is PERMANENT! If you die, your character will be deleted.\n"
                             "No second chances, no resurrections.\n"
                             "\n"
                             "|cFFFFD700Rewards:|r\n"
                             "- " + std::to_string((int)((xpBonus - 1) * 100)) + "% bonus XP\n"
                             "- Exclusive titles at certain levels\n"
                             "- Special rewards for reaching milestones";
                break;
                
            case SETTING_SEMI_HARDCORE:
                description = "|cFFFF6600SEMI-HARDCORE MODE|r\n"
                             "Death has consequences! When you die to a creature:\n"
                             "- You lose ALL equipped items\n"
                             "- Your gear is destroyed permanently\n"
                             "\n"
                             "|cFFFFD700Rewards:|r\n"
                             "- " + std::to_string((int)((xpBonus - 1) * 100)) + "% bonus XP\n"
                             "- Exclusive titles\n"
                             "- Item rewards at milestones";
                break;
                
            case SETTING_SELF_CRAFTED:
                description = "|cFF00FF00SELF-CRAFTED MODE|r\n"
                             "True craftsmanship! You can only use:\n"
                             "- Items YOU have crafted\n"
                             "- Quest rewards\n"
                             "- Starting gear\n"
                             "\n"
                             "|cFFFFD700Rewards:|r\n"
                             "- " + std::to_string((int)((xpBonus - 1) * 100)) + "% bonus XP\n"
                             "- Exclusive titles\n"
                             "- Profession bonuses";
                break;
                
            case SETTING_ITEM_QUALITY_LEVEL:
                description = "|cFF9D9D9DLOW QUALITY ITEM MODE|r\n"
                             "Scavenger challenge! You can only equip:\n"
                             "- Common (white) quality items\n"
                             "- Starting gear\n"
                             "\n"
                             "|cFFFFD700Rewards:|r\n"
                             "- " + std::to_string((int)((xpBonus - 1) * 100)) + "% bonus XP\n"
                             "- Exclusive titles\n"
                             "- Special item rewards";
                break;
                
            case SETTING_SLOW_XP_GAIN:
                description = "|cFF00FFFFSSLOW XP MODE|r\n"
                             "The long road to glory!\n"
                             "- XP gain reduced by 50%\n"
                             "- Experience the content longer\n"
                             "\n"
                             "|cFFFFD700Rewards:|r\n"
                             "- " + std::to_string((int)((xpBonus - 1) * 100)) + "% EXTRA bonus XP (net effect)\n"
                             "- Exclusive titles\n"
                             "- Bonus rewards";
                break;
                
            case SETTING_VERY_SLOW_XP_GAIN:
                description = "|cFF00FFFFVERY SLOW XP MODE|r\n"
                             "The ultimate endurance test!\n"
                             "- XP gain reduced by 75%\n"
                             "- Master every zone\n"
                             "\n"
                             "|cFFFFD700Rewards:|r\n"
                             "- " + std::to_string((int)((xpBonus - 1) * 100)) + "% EXTRA bonus XP (net effect)\n"
                             "- Exclusive titles\n"
                             "- Premium rewards";
                break;
                
            case SETTING_QUEST_XP_ONLY:
                description = "|cFFFFFF00QUEST XP ONLY MODE|r\n"
                             "Story-driven progression!\n"
                             "- You can ONLY gain XP from quests\n"
                             "- No grinding, pure questing\n"
                             "\n"
                             "|cFFFFD700Rewards:|r\n"
                             "- " + std::to_string((int)((xpBonus - 1) * 100)) + "% bonus XP\n"
                             "- Exclusive titles\n"
                             "- Loremaster rewards";
                break;
                
            case SETTING_IRON_MAN:
                description = "|cFFFF0000IRON MAN MODE|r\n"
                             "The ultimate challenge! Combines:\n"
                             "- Death is permanent (Hardcore)\n"
                             "- Can only use white quality items\n"
                             "- Can only use quest rewards and self-crafted items\n"
                             "- No trading, no auction house\n"
                             "\n"
                             "|cFFFFD700Rewards:|r\n"
                             "- " + std::to_string((int)((xpBonus - 1) * 100)) + "% bonus XP\n"
                             "- Legendary exclusive titles\n"
                             "- Ultimate prestige rewards";
                break;
                
            default:
                description = "Mode information not available.";
                break;
        }
        
        // Send description to chat since gossip text would require database entries
        std::istringstream stream(description);
        std::string line;
        while (std::getline(stream, line))
        {
            ChatHandler(player->GetSession()).PSendSysMessage(line.c_str());
        }
        
        // Add confirmation option
        std::string modeName = GetModeName(modeId);
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cFFFF0000[CONFIRM] Enable " + modeName + "|r", 0, 200 + modeId, 
                        "Are you ABSOLUTELY SURE you want to enable this mode? This decision is PERMANENT and cannot be reversed!", 0, false);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "<- Back to Challenge Modes", 0, 1000);
        
        // Send gossip menu
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
    }
    
    std::string GetModeName(uint32 modeId)
    {
        switch (modeId)
        {
            case SETTING_HARDCORE: return "Hardcore Mode";
            case SETTING_SEMI_HARDCORE: return "Semi-Hardcore Mode";
            case SETTING_SELF_CRAFTED: return "Self-Crafted Mode";
            case SETTING_ITEM_QUALITY_LEVEL: return "Low Quality Item Mode";
            case SETTING_SLOW_XP_GAIN: return "Slow XP Mode";
            case SETTING_VERY_SLOW_XP_GAIN: return "Very Slow XP Mode";
            case SETTING_QUEST_XP_ONLY: return "Quest XP Only Mode";
            case SETTING_IRON_MAN: return "Iron Man Mode";
            default: return "Unknown Mode";
        }
    }

    GameObjectAI* GetAI(GameObject* object) const override
    {
        return new gobject_challenge_modesAI(object);
    }
};

class ChallengeModeAuraManager : public PlayerScript
{
public:
    ChallengeModeAuraManager() : PlayerScript("ChallengeModeAuraManager") { }

    void OnPlayerLogin(Player* player) override
    {
        sChallengeModes->RefreshChallengeAuras(player);
    }
};

// Add all scripts in one
void AddSC_dc_challenge_modes()
{
    new ChallengeModes_WorldScript();
    new gobject_challenge_modes();
    new ChallengeMode_Hardcore();
    new ChallengeMode_SemiHardcore();
    new ChallengeMode_SelfCrafted();
    new ChallengeMode_ItemQualityLevel();
    new ChallengeMode_SlowXpGain();
    new ChallengeMode_VerySlowXpGain();
    new ChallengeMode_QuestXpOnly();
    new ChallengeMode_IronMan();
    new ChallengeModeAuraManager();
}
