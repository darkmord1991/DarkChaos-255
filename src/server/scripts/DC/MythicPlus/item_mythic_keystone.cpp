/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 * 
 * Item Script: Mythic Keystone Items (190001-190019 for M+2-M+20)
 * Shows information about Mythic+ system when used
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Item.h"
#include "Chat.h"
#include "ScriptedGossip.h"
#include "MythicPlusRunManager.h"
#include "MythicPlusConstants.h"
#include "MythicDifficultyScaling.h"
#include "StringFormat.h"

namespace
{
uint8 ResolveKeystoneLevel(uint32 itemId)
{
    uint8 level = MythicPlusConstants::GetKeystoneLevelFromItemId(itemId);
    if (!level)
        level = MythicPlusConstants::MIN_KEYSTONE_LEVEL;
    return level;
}

uint32 GetRewardItemLevel(uint8 keystoneLevel)
{
    return MythicPlusConstants::GetItemLevelForKeystoneLevel(keystoneLevel);
}

uint32 GetEstimatedTokenReward(uint8 keystoneLevel)
{
    return MythicPlusConstants::GetTokenRewardForKeystoneLevel(keystoneLevel);
}
}

enum KeystoneGossipActions
{
    GOSSIP_ACTION_INFO = 1,
    GOSSIP_ACTION_SCALING = 2,
    GOSSIP_ACTION_REWARDS = 3,
    GOSSIP_ACTION_CLOSE = 4
};

class item_mythic_keystone : public ItemScript
{
public:
    item_mythic_keystone() : ItemScript("item_mythic_keystone") { }

    bool OnUse(Player* player, Item* item, SpellCastTargets const& /*targets*/) override
    {
        if (!player || !item)
            return false;

        uint8 keystoneLevel = ResolveKeystoneLevel(item->GetEntry());

        ClearGossipMenuFor(player);
        
        // Header with keystone level
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
            "|cffff8000=== MYTHIC KEYSTONE +" + std::to_string(keystoneLevel) + " ===",
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_CLOSE);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", 
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_CLOSE);
        
        // How to use section
        AddGossipItemFor(player, GOSSIP_ICON_TALK,
            "|cffffd700How to Use This Keystone|r",
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO);
        
        // Scaling information section
        std::string scalingText = "|cffffd700Difficulty Scaling (M+" + std::to_string(keystoneLevel) + ")|r";
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
            scalingText,
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_SCALING);
        
        // Rewards section
        AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG,
            "|cffffd700Rewards & Upgrades|r",
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_REWARDS);
        
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", 
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_CLOSE);
        
        // Close button
        AddGossipItemFor(player, GOSSIP_ICON_CHAT,
            "|cffaaaaaa[Close]|r",
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_CLOSE);
        
        SendGossipMenuFor(player, item->GetEntry(), item->GetGUID());
        return false; // Return false to prevent item consumption
    }
    
    void OnGossipSelect(Player* player, Item* item, uint32 /*sender*/, uint32 action) override
    {
        if (!player || !item)
            return;
        
        // Calculate keystone level
        uint8 keystoneLevel = ResolveKeystoneLevel(item->GetEntry());
        
        ChatHandler handler(player->GetSession());
        
        if (action == GOSSIP_ACTION_CLOSE)
        {
            CloseGossipMenuFor(player);
            return;
        }
        
        // Calculate values
        float hpMultiplier = 2.0f + (keystoneLevel * 0.25f);
        float dmgMultiplier = 2.0f + (keystoneLevel * 0.25f);
        uint32 itemLevel = GetRewardItemLevel(keystoneLevel);
        uint32 estimatedTokens = GetEstimatedTokenReward(keystoneLevel);
        
        if (action == GOSSIP_ACTION_INFO)
        {
            handler.SendSysMessage("|cff00ff00========================================|r");
            handler.SendSysMessage(Acore::StringFormat("|cffff8000    HOW TO USE KEYSTONE +{}|r", keystoneLevel));
            handler.SendSysMessage("|cff00ff00========================================|r");
            handler.SendSysMessage(" ");
            handler.SendSysMessage("|cffffd7001. Enter a Dungeon|r");
            handler.SendSysMessage("|cffffffff   Set difficulty to Mythic before entering|r");
            handler.SendSysMessage("|cffffffff   Enter with your group (or solo)|r");
            handler.SendSysMessage(" ");
            handler.SendSysMessage("|cffffd7002. Find the Font of Power|r");
            handler.SendSysMessage("|cffffffff   Located at the dungeon entrance|r");
            handler.SendSysMessage("|cffffffff   Look for a glowing pedestal/font|r");
            handler.SendSysMessage(" ");
            handler.SendSysMessage("|cffffd7003. Activate Your Keystone|r");
            handler.SendSysMessage("|cffffffff   Click the Font of Power|r");
            handler.SendSysMessage("|cffffffff   Confirm keystone activation|r");
            handler.SendSysMessage("|cffffffff   Keystone will be consumed|r");
            handler.SendSysMessage(" ");
            handler.SendSysMessage("|cffffd7004. Complete the Dungeon|r");
            handler.SendSysMessage("|cffffffff   10-second countdown before timer starts|r");
            handler.SendSysMessage("|cffffffff   All players teleported to entrance|r");
            handler.SendSysMessage("|cffffffff   Defeat all bosses before 15 deaths|r");
            handler.SendSysMessage("|cffffffff   Only final boss drops loot|r");
            handler.SendSysMessage(" ");
            handler.SendSysMessage("|cffaaaaaa[Keystone is consumed when activated at Font of Power]|r");
            handler.SendSysMessage("|cff00ff00========================================|r");
        }
        else if (action == GOSSIP_ACTION_SCALING)
        {
            handler.SendSysMessage("|cff00ff00========================================|r");
            handler.SendSysMessage(Acore::StringFormat("|cffff8000    MYTHIC+ SCALING (Level +{})|r", keystoneLevel));
            handler.SendSysMessage("|cff00ff00========================================|r");
            handler.SendSysMessage(" ");
            handler.SendSysMessage("|cffffd700Enemy Difficulty:|r");
            handler.SendSysMessage(Acore::StringFormat("|cffffffff  Health: |cffff8000+{:.0f}%|r ({:.1f}x multiplier)", 
                (hpMultiplier - 1.0f) * 100.0f, hpMultiplier));
            handler.SendSysMessage(Acore::StringFormat("|cffffffff  Damage: |cffff8000+{:.0f}%|r ({:.1f}x multiplier)", 
                (dmgMultiplier - 1.0f) * 100.0f, dmgMultiplier));
            handler.SendSysMessage(" ");
            handler.SendSysMessage("|cffffd700Scaling Formula:|r");
            handler.SendSysMessage("|cffffffff  Base Mythic: 2.0x multiplier|r");
            handler.SendSysMessage("|cffffffff  Each +1 level: +0.25x multiplier|r");
            handler.SendSysMessage(Acore::StringFormat("|cffffffff  Your M+{}: 2.0 + ({} × 0.25) = {:.1f}x|r",
                keystoneLevel, keystoneLevel, hpMultiplier));
            handler.SendSysMessage(" ");
            handler.SendSysMessage("|cffffd700Death Budget:|r");
            handler.SendSysMessage("|cffff0000  Maximum: 15 deaths|r");
            handler.SendSysMessage("|cffffffff  Each death counts toward limit|r");
            handler.SendSysMessage("|cffffffff  15th death = instant run failure|r");
            handler.SendSysMessage(" ");
            handler.SendSysMessage("|cffffd700Loot Item Level:|r");
            handler.SendSysMessage(Acore::StringFormat("|cff00ff00  Boss drops: {} ilvl gear|r", itemLevel));
            handler.SendSysMessage("|cffffffff  Formula: Base + (Level × 3) up to +10|r");
            handler.SendSysMessage("|cffffffff  Then: Base + 30 + ((Level-10) × 4)|r");
            handler.SendSysMessage(" ");
            handler.SendSysMessage("|cff00ff00========================================|r");
        }
        else if (action == GOSSIP_ACTION_REWARDS)
        {
            handler.SendSysMessage("|cff00ff00========================================|r");
            handler.SendSysMessage(Acore::StringFormat("|cffff8000    REWARDS & UPGRADES (M+{})|r", keystoneLevel));
            handler.SendSysMessage("|cff00ff00========================================|r");
            handler.SendSysMessage(" ");
            handler.SendSysMessage("|cffffd700Boss Loot (Spec-Based):|r");
            handler.SendSysMessage(Acore::StringFormat("|cff00ff00  Item Level: {}|r", itemLevel));
            handler.SendSysMessage("|cffffffff  1 item per normal boss|r");
            handler.SendSysMessage("|cffffffff  2 items from final boss|r");
            handler.SendSysMessage("|cffffffff  Filtered by your class/spec/role|r");
            handler.SendSysMessage(" ");
            handler.SendSysMessage("|cffffd700Token Rewards:|r");
            handler.SendSysMessage(Acore::StringFormat("|cff00ff00  Estimated: ~{} tokens|r", estimatedTokens));
            handler.SendSysMessage("|cffffffff  Awarded at final boss kill|r");
            handler.SendSysMessage("|cffffffff  Used for gear upgrades|r");
            handler.SendSysMessage(" ");
            handler.SendSysMessage("|cffffd700Keystone Upgrade (Auto):|r");
            handler.SendSysMessage("|cff00ff00  0-5 deaths: +2 levels|r");
            handler.SendSysMessage("|cffffff00  6-10 deaths: +1 level|r");
            handler.SendSysMessage("|cffffaa00  11-14 deaths: Same level|r");
            handler.SendSysMessage("|cffff6600  15+ deaths: Run failed (-1 level)|r");
            handler.SendSysMessage(" ");
            handler.SendSysMessage("|cffffd700Weekly Vault:|r");
            handler.SendSysMessage("|cffffffff  Completion counts toward vault progress|r");
            handler.SendSysMessage("|cffffffff  1 run = Unlock slot 1 (50 tokens)|r");
            handler.SendSysMessage("|cffffffff  4 runs = Unlock slot 2 (100 tokens)|r");
            handler.SendSysMessage("|cffffffff  10 runs = Unlock slot 3 (150 tokens)|r");
            handler.SendSysMessage(" ");
            handler.SendSysMessage("|cff00ff00========================================|r");
        }
        
        CloseGossipMenuFor(player);
    }
};

// Register keystones for M+2 through M+20 (items 190001-190019)
void AddSC_item_mythic_keystone()
{
    new item_mythic_keystone();
}
