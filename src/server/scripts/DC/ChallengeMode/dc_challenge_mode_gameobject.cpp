/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Customized for DarkChaos-255
 * 
 * Challenge Mode GameObject Script
 * Provides in-world access to challenge mode menu via clickable gameobject
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "GameObject.h"
#include "dc_challenge_modes.h"

class go_challenge_mode : public GameObjectScript
{
public:
    go_challenge_mode() : GameObjectScript("go_challenge_mode") { }

    bool OnGossipHello(Player* player, GameObject* /*go*/) override
    {
        if (!player)
            return false;

        // Clear existing menu
        ClearGossipMenuFor(player);

        // Add menu title
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff00ff00[Challenge Mode Manager]|r", GOSSIP_SENDER_MAIN, 0);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 0);

        // Check if player is in combat
        if (player->IsInCombat())
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffff0000You cannot access challenge modes while in combat!|r", GOSSIP_SENDER_MAIN, 0);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, player->GetGUID());
            return true;
        }

        // Get current challenge mode settings
        uint8 hardcoreSetting = player->GetPlayerSetting("dc-mod-challenge-modes", SETTING_HARDCORE).value;
        uint8 semiHardcoreSetting = player->GetPlayerSetting("dc-mod-challenge-modes", SETTING_SEMI_HARDCORE).value;
        uint8 selfCraftedSetting = player->GetPlayerSetting("dc-mod-challenge-modes", SETTING_SELF_CRAFTED).value;
        uint8 ironManSetting = player->GetPlayerSetting("dc-mod-challenge-modes", SETTING_IRON_MAN).value;
        uint8 questXPSetting = player->GetPlayerSetting("dc-mod-challenge-modes", SETTING_QUEST_XP_ONLY).value;

        // Display current active modes
        std::string statusText = "|cff00ccff[Active Modes]|r\n";
        bool hasActiveModes = false;

        if (hardcoreSetting == 1)
        {
            statusText += "|cffff0000● Hardcore Mode|r - Death is permanent\n";
            hasActiveModes = true;
        }
        if (semiHardcoreSetting == 1)
        {
            statusText += "|cffff8800● Semi-Hardcore Mode|r - XP loss on death\n";
            hasActiveModes = true;
        }
        if (selfCraftedSetting == 1)
        {
            statusText += "|cff00ff00● Self-Crafted Mode|r - No quest rewards\n";
            hasActiveModes = true;
        }
        if (ironManSetting == 1)
        {
            statusText += "|cff8800ff● Iron Man Mode|r - No trading, AH, or mail\n";
            hasActiveModes = true;
        }
        if (questXPSetting == 1)
        {
            statusText += "|cff00ffff● Quest XP Only|r - No XP from kills\n";
            hasActiveModes = true;
        }

        if (!hasActiveModes)
        {
            statusText = "|cff888888No challenge modes currently active|r\n";
        }

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, statusText, GOSSIP_SENDER_MAIN, 0);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 0);

        // Add mode toggle options
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, 
            hardcoreSetting == 1 ? "|cffff0000[ON]|r Hardcore Mode" : "|cff888888[OFF]|r Hardcore Mode",
            GOSSIP_SENDER_MAIN, SETTING_HARDCORE + 100);

        AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
            semiHardcoreSetting == 1 ? "|cffff8800[ON]|r Semi-Hardcore Mode" : "|cff888888[OFF]|r Semi-Hardcore Mode",
            GOSSIP_SENDER_MAIN, SETTING_SEMI_HARDCORE + 100);

        AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
            selfCraftedSetting == 1 ? "|cff00ff00[ON]|r Self-Crafted Mode" : "|cff888888[OFF]|r Self-Crafted Mode",
            GOSSIP_SENDER_MAIN, SETTING_SELF_CRAFTED + 100);

        AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
            ironManSetting == 1 ? "|cff8800ff[ON]|r Iron Man Mode" : "|cff888888[OFF]|r Iron Man Mode",
            GOSSIP_SENDER_MAIN, SETTING_IRON_MAN + 100);

        AddGossipItemFor(player, GOSSIP_ICON_BATTLE,
            questXPSetting == 1 ? "|cff00ffff[ON]|r Quest XP Only" : "|cff888888[OFF]|r Quest XP Only",
            GOSSIP_SENDER_MAIN, SETTING_QUEST_XP_ONLY + 100);

        // Add info and close options
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 0);
        AddGossipItemFor(player, GOSSIP_ICON_DOT, "|cffFFD700[?] Learn about Challenge Modes|r", GOSSIP_SENDER_MAIN, 999);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffff0000[Close]|r", GOSSIP_SENDER_MAIN, 1000);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, player->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, GameObject* go, uint32 /*sender*/, uint32 action) override
    {
        if (!player)
            return false;

        ClearGossipMenuFor(player);

        // Handle close
        if (action == 1000)
        {
            CloseGossipMenuFor(player);
            return true;
        }

        // Handle info page
        if (action == 999)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff00ff00Challenge Modes Information|r", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffff0000Hardcore:|r Death deletes character", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffff8800Semi-Hardcore:|r Lose XP on death", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff00ff00Self-Crafted:|r No quest item rewards", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff8800ffIron Man:|r No trading/AH/mail", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff00ffffQuest XP Only:|r No XP from kills", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[<< Back]|r", GOSSIP_SENDER_MAIN, 1001);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, player->GetGUID());
            return true;
        }

        // Handle back to main menu
        if (action == 1001)
        {
            return OnGossipHello(player, go);
        }

        // Handle mode toggles (100-199 range)
        if (action >= 100 && action < 200)
        {
            uint8 settingId = action - 100;
            uint8 currentValue = player->GetPlayerSetting("dc-mod-challenge-modes", settingId).value;
            uint8 newValue = (currentValue == 1) ? 0 : 1;

            // Toggle the setting
            player->UpdatePlayerSetting("dc-mod-challenge-modes", settingId, newValue);

            // Send confirmation message
            std::string modeName;
            switch(settingId)
            {
                case SETTING_HARDCORE:      modeName = "Hardcore Mode"; break;
                case SETTING_SEMI_HARDCORE: modeName = "Semi-Hardcore Mode"; break;
                case SETTING_SELF_CRAFTED:  modeName = "Self-Crafted Mode"; break;
                case SETTING_IRON_MAN:      modeName = "Iron Man Mode"; break;
                case SETTING_QUEST_XP_ONLY: modeName = "Quest XP Only"; break;
                default: modeName = "Unknown Mode"; break;
            }

            if (newValue == 1)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00Challenge Mode Activated:|r %s", modeName.c_str());
            }
            else
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cffff8800Challenge Mode Deactivated:|r %s", modeName.c_str());
            }

            // Return to main menu
            return OnGossipHello(player, go);
        }

        return true;
    }
};

void AddSC_dc_challenge_mode_gameobject()
{
    new go_challenge_mode();
}
