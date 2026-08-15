/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Item Script: Mythic Keystone Items (300313-300331 for M+2-M+20)
 * Shows information about Mythic+ system when used
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Item.h"
#include "Chat.h"
#include "ScriptedGossip.h"
#include "dc_mythicplus_run_manager.h"
#include "dc_mythicplus_constants.h"
#include "dc_mythicplus_difficulty_scaling.h"
#include "Config.h"
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

uint32 GetEstimatedTokenReward(Player* player, uint8 keystoneLevel)
{
    // Same function AwardTokens uses, against this character's own level, so
    // the quoted figure is the figure they will actually be paid.
    return MythicPlusConstants::CalculateTokenReward(
        player ? player->GetLevel() : 80, keystoneLevel);
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

        // DEFAULT_GOSSIP_MESSAGE, not item->GetEntry(): this argument is an
        // npc_text id, and passing an item entry left the menu body blank.
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, item->GetGUID());
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

        // Read the real numbers from the systems that will actually apply them.
        // These used to be re-stated as literals here and had drifted badly:
        // the tooltip advertised 4.5x scaling at +10 where the real value is
        // 1.84x, and quoted a token formula nothing used.
        float hpMultiplier = 1.0f;
        float dmgMultiplier = 1.0f;
        sMythicScaling->CalculateMythicPlusMultipliers(keystoneLevel, hpMultiplier, dmgMultiplier);

        uint32 itemLevel = GetRewardItemLevel(keystoneLevel);
        uint32 estimatedTokens = GetEstimatedTokenReward(player, keystoneLevel);

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
            handler.SendSysMessage("|cffffffff   Short countdown before the timer starts|r");
            handler.SendSysMessage("|cffffffff   All players teleported to entrance|r");
            handler.SendSysMessage("|cffffffff   Defeat every boss before the timer runs out|r");
            handler.SendSysMessage("|cffffffff   Rewards are handed out at the end of the run|r");
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
            handler.SendSysMessage("|cffffd700Note:|r");
            handler.SendSysMessage("|cffffffff  This is multiplied on top of the base Mythic|r");
            handler.SendSysMessage("|cffffffff  scaling for the dungeon.|r");
            handler.SendSysMessage(" ");

            // Death budget is per dungeon (dc_dungeon_mythic_profile) and can be
            // switched off entirely, so report what is actually configured
            // rather than a hardcoded "15 deaths".
            handler.SendSysMessage("|cffffd700Death Budget:|r");
            if (sConfigMgr->GetOption<bool>("MythicPlus.DeathBudget.Enabled", false))
            {
                handler.SendSysMessage("|cffffffff  Limited - varies per dungeon|r");
                handler.SendSysMessage("|cffff0000  Exceeding it fails the run|r");
            }
            else
            {
                handler.SendSysMessage("|cffffffff  Disabled on this realm|r");
            }
            handler.SendSysMessage(" ");
            handler.SendSysMessage("|cffffd700Loot Item Level:|r");
            handler.SendSysMessage(Acore::StringFormat("|cff00ff00  Boss drops: {} ilvl gear|r", itemLevel));
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
            handler.SendSysMessage("|cffffffff  Rewards are pooled and handed out|r");
            handler.SendSysMessage("|cffffffff  to the group at the end of the run|r");
            handler.SendSysMessage("|cffffffff  Filtered by your class/spec/role|r");
            handler.SendSysMessage(" ");
            handler.SendSysMessage("|cffffd700Token Rewards:|r");
            handler.SendSysMessage(Acore::StringFormat("|cff00ff00  Estimated: ~{} tokens|r", estimatedTokens));
            handler.SendSysMessage("|cffffffff  Awarded on completion|r");
            handler.SendSysMessage("|cffffffff  Used for gear upgrades|r");
            handler.SendSysMessage(" ");
            handler.SendSysMessage("|cffffd700Keystone Upgrade (Auto):|r");
            handler.SendSysMessage("|cff00ff00  0-5 deaths: +2 levels|r");
            handler.SendSysMessage("|cffffff00  6-10 deaths: +1 level|r");
            handler.SendSysMessage("|cffffaa00  11+ deaths: Same level|r");
            handler.SendSysMessage("|cffff6600  Over the timer: no upgrade|r");
            handler.SendSysMessage("|cffff6600  Failed run: -1 level|r");
            handler.SendSysMessage(" ");
            handler.SendSysMessage("|cffffd700Weekly Vault:|r");
            handler.SendSysMessage("|cffffffff  Completion counts toward vault progress|r");
            // Thresholds are configurable (MythicPlus.Vault.ThresholdN), so ask
            // the vault rather than restating them.
            handler.SendSysMessage(Acore::StringFormat("|cffffffff  {} run(s) = Unlock slot 1|r",
                static_cast<uint32>(sMythicRuns->GetVaultThreshold(1))));
            handler.SendSysMessage(Acore::StringFormat("|cffffffff  {} runs = Unlock slot 2|r",
                static_cast<uint32>(sMythicRuns->GetVaultThreshold(2))));
            handler.SendSysMessage(Acore::StringFormat("|cffffffff  {} runs = Unlock slot 3|r",
                static_cast<uint32>(sMythicRuns->GetVaultThreshold(3))));
            handler.SendSysMessage(" ");
            handler.SendSysMessage("|cff00ff00========================================|r");
        }

        CloseGossipMenuFor(player);
    }
};

// Register keystones for M+2 through M+20 (items 300313-300331)
void AddSC_item_mythic_keystone()
{
    new item_mythic_keystone();
}
