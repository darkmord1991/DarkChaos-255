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
#include "Chat.h"
#include "StringFormat.h"
#include "dc_challenge_modes.h"
#include "dc_prestige_api.h"
#include <sstream>

namespace
{
    enum GossipActions : uint32
    {
        ACTION_OPEN_INFO           = 999,
        ACTION_CLOSE_MENU          = 1000,
        ACTION_BACK_TO_MAIN        = 1001,
        ACTION_PRESTIGE_OVERVIEW   = 1200,
        ACTION_PRESTIGE_WARNINGS   = 1201,
        ACTION_PRESTIGE_CONFIRM    = 1202,
    };
}

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

        // Get current challenge mode settings
        uint8 hardcoreSetting = player->GetPlayerSetting("mod-challenge-modes", SETTING_HARDCORE).value;
        uint8 semiHardcoreSetting = player->GetPlayerSetting("mod-challenge-modes", SETTING_SEMI_HARDCORE).value;
        uint8 selfCraftedSetting = player->GetPlayerSetting("mod-challenge-modes", SETTING_SELF_CRAFTED).value;
        uint8 ironManSetting = player->GetPlayerSetting("mod-challenge-modes", SETTING_IRON_MAN).value;
        uint8 questXPSetting = player->GetPlayerSetting("mod-challenge-modes", SETTING_QUEST_XP_ONLY).value;

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

        // Prestige overview snippet
        if (PrestigeAPI::IsEnabled())
        {
            uint32 prestigeLevel = PrestigeAPI::GetPrestigeLevel(player);
            uint32 maxPrestige = PrestigeAPI::GetMaxPrestigeLevel();
            uint32 statBonusPercent = PrestigeAPI::GetStatBonusPercent();
            uint32 totalBonus = prestigeLevel * statBonusPercent;
            uint32 requiredLevel = PrestigeAPI::GetRequiredLevel();
            bool canPrestige = PrestigeAPI::CanPrestige(player);

            std::ostringstream prestigeStatus;
            prestigeStatus << "|cffffd700[Prestige]|r Level " << prestigeLevel << "/" << maxPrestige;
            prestigeStatus << " (" << totalBonus << "% bonus stats)\n";

            if (canPrestige)
            {
                prestigeStatus << "|cff00ff00You can prestige now.|r\n";
            }
            else if (prestigeLevel >= maxPrestige)
            {
                prestigeStatus << "|cffFFD700Maximum prestige reached.|r\n";
            }
            else if (player->GetLevel() < requiredLevel)
            {
                prestigeStatus << "|cff888888Reach level " << requiredLevel << " to prestige (current: " << player->GetLevel() << ").|r\n";
            }
            else
            {
                prestigeStatus << "|cff888888Prestige requirements not met.|r\n";
            }

            AddGossipItemFor(player, GOSSIP_ICON_CHAT, prestigeStatus.str(), GOSSIP_SENDER_MAIN, 0);
        }
        else
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff888888Prestige system currently disabled.|r", GOSSIP_SENDER_MAIN, 0);
        }

        AddGossipItemFor(player, GOSSIP_ICON_DOT, "|cffFFD700[Prestige Overview]|r", GOSSIP_SENDER_MAIN, ACTION_PRESTIGE_OVERVIEW);
        if (PrestigeAPI::IsEnabled() && PrestigeAPI::CanPrestige(player))
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cffFF4500[Prestige Reset]|r Begin your next prestige", GOSSIP_SENDER_MAIN, ACTION_PRESTIGE_WARNINGS);
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
    AddGossipItemFor(player, GOSSIP_ICON_DOT, "|cffFFD700[?] Learn about Challenge Modes|r", GOSSIP_SENDER_MAIN, ACTION_OPEN_INFO);
    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffff0000[Close]|r", GOSSIP_SENDER_MAIN, ACTION_CLOSE_MENU);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, player->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, GameObject* go, uint32 /*sender*/, uint32 action) override
    {
        if (!player)
            return false;

        ClearGossipMenuFor(player);

        // Handle close
        if (action == ACTION_CLOSE_MENU)
        {
            CloseGossipMenuFor(player);
            return true;
        }

        // Handle info page
        if (action == ACTION_OPEN_INFO)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff00ff00Challenge Modes Information|r", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffff0000Hardcore:|r Death deletes character", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffff8800Semi-Hardcore:|r Lose XP on death", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff00ff00Self-Crafted:|r No quest item rewards", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff8800ffIron Man:|r No trading/AH/mail", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff00ffffQuest XP Only:|r No XP from kills", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[<< Back]|r", GOSSIP_SENDER_MAIN, ACTION_BACK_TO_MAIN);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, player->GetGUID());
            return true;
        }

        // Handle back to main menu
        if (action == ACTION_BACK_TO_MAIN)
        {
            return OnGossipHello(player, go);
        }

        if (action == ACTION_PRESTIGE_OVERVIEW)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffffd700Prestige Overview|r", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 0);

            if (!PrestigeAPI::IsEnabled())
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff888888The prestige system is currently disabled.|r", GOSSIP_SENDER_MAIN, 0);
            }
            else
            {
                uint32 prestigeLevel = PrestigeAPI::GetPrestigeLevel(player);
                uint32 maxPrestige = PrestigeAPI::GetMaxPrestigeLevel();
                uint32 statBonusPercent = PrestigeAPI::GetStatBonusPercent();
                uint32 requiredLevel = PrestigeAPI::GetRequiredLevel();
                uint32 nextPrestige = prestigeLevel + 1;
                uint32 nextBonus = nextPrestige * statBonusPercent;

                AddGossipItemFor(player, GOSSIP_ICON_CHAT, Acore::StringFormat("Current Prestige Level: {}/{}", prestigeLevel, maxPrestige), GOSSIP_SENDER_MAIN, 0);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, Acore::StringFormat("Current Bonus: {}% all stats", prestigeLevel * statBonusPercent), GOSSIP_SENDER_MAIN, 0);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, Acore::StringFormat("Required Level to Prestige: {}", requiredLevel), GOSSIP_SENDER_MAIN, 0);

                if (PrestigeAPI::CanPrestige(player))
                {
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, Acore::StringFormat("|cff00ff00Prestige {} available: {}% bonus after reset|r", nextPrestige, nextBonus), GOSSIP_SENDER_MAIN, 0);
                }
                else if (prestigeLevel >= maxPrestige)
                {
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700You have reached the maximum prestige level.|r", GOSSIP_SENDER_MAIN, 0);
                }
                else
                {
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cff888888Requirements not yet met for the next prestige.|r", GOSSIP_SENDER_MAIN, 0);
                }
            }

            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[<< Back]|r", GOSSIP_SENDER_MAIN, ACTION_BACK_TO_MAIN);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, player->GetGUID());
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

            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffff4500Prestige Warning|r", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, Acore::StringFormat("You are about to begin Prestige {}.", nextPrestige), GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffff0000This will reset you to level 1.|r", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, Acore::StringFormat("|cffffd700You will gain a total of {}% bonus to all stats.|r", nextBonus), GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffff8800You will retain configured prestige rewards.|r", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "-----------------------------------", GOSSIP_SENDER_MAIN, 0);
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "|cff00ff00[Confirm Prestige]|r", GOSSIP_SENDER_MAIN, ACTION_PRESTIGE_CONFIRM);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffFFD700[<< Back]|r", GOSSIP_SENDER_MAIN, ACTION_BACK_TO_MAIN);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, player->GetGUID());
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

        // Handle mode toggles (100-199 range)
        if (action >= 100 && action < 200)
        {
            uint8 settingId = action - 100;
            uint8 currentValue = player->GetPlayerSetting("mod-challenge-modes", settingId).value;
            uint8 newValue = (currentValue == 1) ? 0 : 1;

            // Toggle the setting
            player->UpdatePlayerSetting("mod-challenge-modes", settingId, newValue);

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
