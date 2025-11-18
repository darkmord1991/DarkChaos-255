/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 * 
 * Item Script: Mythic Keystone Items (190001-190009 for M+2-M+10)
 * Shows information about Mythic+ system when used
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Item.h"
#include "Chat.h"
#include "MythicPlusRunManager.h"
#include "MythicDifficultyScaling.h"

class item_mythic_keystone : public ItemScript
{
public:
    item_mythic_keystone() : ItemScript("item_mythic_keystone") { }

    bool OnUse(Player* player, Item* item, SpellCastTargets const& /*targets*/) override
    {
        if (!player || !item)
            return false;

        // Calculate keystone level from item ID (190001 = M+2, 190002 = M+3, etc.)
        uint32 itemId = item->GetEntry();
        uint8 keystoneLevel = 0;
        
        if (itemId >= 190001 && itemId <= 190009)
            keystoneLevel = (itemId - 190001) + 2;
        else
            keystoneLevel = 2; // Default fallback

        ChatHandler handler(player->GetSession());
        
        // Header
        handler.SendSysMessage("|cff00ff00========================================|r");
        handler.PSendSysMessage("|cffff8000    MYTHIC KEYSTONE +%u|r", keystoneLevel);
        handler.SendSysMessage("|cff00ff00========================================|r");
        handler.SendSysMessage(" ");
        
        // How to use
        handler.SendSysMessage("|cffffd700How to Use:|r");
        handler.SendSysMessage("|cffffffff1. Enter a dungeon with your group|r");
        handler.SendSysMessage("|cffffffff2. Find the Font of Power (at start)|r");
        handler.SendSysMessage("|cffffffff3. Click the Font to activate keystone|r");
        handler.SendSysMessage("|cffffffff4. Complete before death limit (15)|r");
        handler.SendSysMessage(" ");
        
        // Scaling information
        handler.SendSysMessage("|cffffd700Mythic+ Scaling:|r");
        
        // Get scaling values from the profile
        float hpMultiplier = 1.0f;
        float dmgMultiplier = 1.0f;
        
        // Base Mythic is 2.0x, each keystone level adds 0.25x
        hpMultiplier = 2.0f + (keystoneLevel * 0.25f);
        dmgMultiplier = 2.0f + (keystoneLevel * 0.25f);
        
        handler.PSendSysMessage("|cffffffff  Enemy Health: |cffff8000+%.0f%%|r", (hpMultiplier - 1.0f) * 100.0f);
        handler.PSendSysMessage("|cffffffff  Enemy Damage: |cffff8000+%.0f%%|r", (dmgMultiplier - 1.0f) * 100.0f);
        handler.PSendSysMessage("|cffffffff  Death Budget: |cffff000015 deaths|r");
        handler.SendSysMessage(" ");
        
        // Rewards
        handler.SendSysMessage("|cffffd700Rewards:|r");
        
        // Token calculation
        uint32 baseTokens = 10 + (player->GetLevel() - 70) * 2;
        float tokenMultiplier = 2.0f + (keystoneLevel * 0.25f);
        uint32 estimatedTokens = static_cast<uint32>(baseTokens * tokenMultiplier);
        
        handler.PSendSysMessage("|cffffffff  Tokens (estimated): |cff00ff00~%u|r", estimatedTokens);
        handler.SendSysMessage("|cffffffff  Weekly Vault Progress: +1 run|r");
        handler.SendSysMessage(" ");
        
        // Upgrade information
        handler.SendSysMessage("|cffffd700Keystone Upgrade:|r");
        handler.SendSysMessage("|cff00ff00  0-5 deaths:|r +2 levels");
        handler.SendSysMessage("|cffffff00  6-10 deaths:|r +1 level");
        handler.SendSysMessage("|cffffaa00  11-14 deaths:|r Same level");
        handler.SendSysMessage("|cffff6600  15+ deaths:|r Run failed");
        handler.SendSysMessage(" ");
        
        // Affixes (if any are active this season)
        uint32 seasonId = sMythicRuns->GetCurrentSeasonId();
        auto affixes = sMythicRuns->GetWeeklyAffixes(seasonId);
        
        if (!affixes.empty())
        {
            handler.SendSysMessage("|cffffd700Weekly Affixes:|r");
            for (uint32 affixId : affixes)
            {
                std::string affixName = sMythicRuns->GetAffixName(affixId);
                handler.PSendSysMessage("|cffff8000  • %s|r", affixName.c_str());
            }
            handler.SendSysMessage(" ");
        }
        
        // Footer
        handler.SendSysMessage("|cffaaaaaa[This keystone is consumed when used at Font of Power]|r");
        handler.SendSysMessage("|cff00ff00========================================|r");
        
        // Prevent the item from being consumed
        return true;
    }
};

// Register keystones for M+2 through M+20 (items 190001-190019)
void AddSC_item_mythic_keystone()
{
    new item_mythic_keystone();
}
