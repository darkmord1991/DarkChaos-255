/*
 * ============================================================================
 * Dungeon Enhancement System - Great Vault GameObject
 * ============================================================================
 * Purpose: Provide weekly reward chest with 3 slots (gear or tokens)
 * GameObject ID: 700000
 * Location: Stormwind, Orgrimmar, Dalaran
 * ============================================================================
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "GameObject.h"
#include "../Core/DungeonEnhancementManager.h"
#include "../Core/DungeonEnhancementConstants.h"

using namespace DungeonEnhancement;

class go_mythic_plus_great_vault : public GameObjectScript
{
public:
    go_mythic_plus_great_vault() : GameObjectScript("go_mythic_plus_great_vault") { }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        if (!sDungeonEnhancementMgr->IsEnabled())
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Dungeon Enhancement system is currently disabled.");
            return true;
        }

        // Check if vault is enabled
        SeasonData* season = sDungeonEnhancementMgr->GetCurrentSeason();
        if (!season || !season->vaultEnabled)
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000The Great Vault is not available this season.|r"
            );
            return true;
        }

        // Get player's vault progress
        uint8 completedDungeons = sDungeonEnhancementMgr->GetPlayerVaultProgress(player);

        // Display vault header
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                         "|cFF00FF00=== Great Vault Weekly Rewards ===|r", 
                         GOSSIP_SENDER_MAIN, GOSSIP_ACTION_VAULT_INFO);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                         "Completed Dungeons This Week: " + std::to_string(completedDungeons), 
                         GOSSIP_SENDER_MAIN, GOSSIP_ACTION_VAULT_INFO);
        
        AddGossipItemFor(player, GOSSIP_ICON_DOT, "----------------------------------------", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_VAULT_INFO);

        // Slot 1: Requires 1 dungeon
        ShowVaultSlot(player, 1, VAULT_SLOT_1_REQUIREMENT, completedDungeons);

        // Slot 2: Requires 4 dungeons
        ShowVaultSlot(player, 2, VAULT_SLOT_2_REQUIREMENT, completedDungeons);

        // Slot 3: Requires 8 dungeons
        ShowVaultSlot(player, 3, VAULT_SLOT_3_REQUIREMENT, completedDungeons);

        AddGossipItemFor(player, GOSSIP_ICON_DOT, "----------------------------------------", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_VAULT_INFO);

        // Info option
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "How does the Great Vault work?", 
                         GOSSIP_SENDER_MAIN, GOSSIP_ACTION_VAULT_INFO);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, GameObject* go, [[maybe_unused]] uint32 sender, uint32 action) override
    {
        player->PlayerTalkClass->ClearMenus();

        switch (action)
        {
            case GOSSIP_ACTION_CLAIM_SLOT_1:
                HandleClaimSlot(player, go, 1);
                break;

            case GOSSIP_ACTION_CLAIM_SLOT_2:
                HandleClaimSlot(player, go, 2);
                break;

            case GOSSIP_ACTION_CLAIM_SLOT_3:
                HandleClaimSlot(player, go, 3);
                break;

            case GOSSIP_ACTION_VAULT_INFO:
                ShowVaultInfo(player, go);
                break;

            case GOSSIP_ACTION_BACK:
                OnGossipHello(player, go);
                break;

            case GOSSIP_ACTION_CLAIM_GEAR_BASE + 1:
            case GOSSIP_ACTION_CLAIM_GEAR_BASE + 2:
            case GOSSIP_ACTION_CLAIM_GEAR_BASE + 3:
                HandleClaimGear(player, go, action - GOSSIP_ACTION_CLAIM_GEAR_BASE);
                break;

            case GOSSIP_ACTION_CLAIM_TOKENS_BASE + 1:
            case GOSSIP_ACTION_CLAIM_TOKENS_BASE + 2:
            case GOSSIP_ACTION_CLAIM_TOKENS_BASE + 3:
                HandleClaimTokens(player, go, action - GOSSIP_ACTION_CLAIM_TOKENS_BASE);
                break;

            default:
                CloseGossipMenuFor(player);
                break;
        }

        return true;
    }

private:
    // ========================================================================
    // VAULT SLOT DISPLAY
    // ========================================================================

    void ShowVaultSlot(Player* player, uint8 slotNumber, uint8 requirement, uint8 completedDungeons)
    {
        bool canClaim = completedDungeons >= requirement;
        bool alreadyClaimed = sDungeonEnhancementMgr->CanClaimVaultSlot(player, slotNumber);

        std::string slotText = "|cFFFFAA00Slot " + std::to_string(slotNumber) + "|r (Requires " + 
                               std::to_string(requirement) + " dungeons)";

        if (alreadyClaimed)
        {
            // Already claimed this week
            AddGossipItemFor(player, GOSSIP_ICON_DOT, 
                             slotText + " - |cFF888888Already Claimed|r", 
                             GOSSIP_SENDER_MAIN, GOSSIP_ACTION_VAULT_INFO);
        }
        else if (canClaim)
        {
            // Can claim - show options
            uint32 tokens = GetVaultTokenReward(slotNumber, player);
            
            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, 
                             slotText + " - |cFF00FF00[READY] Choose Reward|r", 
                             GOSSIP_SENDER_MAIN, GOSSIP_ACTION_CLAIM_SLOT_1 + (slotNumber - 1));
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                             "  Option 1: High-level Gear (Item Level based on highest M+)", 
                             GOSSIP_SENDER_MAIN, GOSSIP_ACTION_VAULT_INFO);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                             "  Option 2: " + std::to_string(tokens) + " Mythic+ Tokens", 
                             GOSSIP_SENDER_MAIN, GOSSIP_ACTION_VAULT_INFO);
        }
        else
        {
            // Not unlocked yet
            uint8 remaining = requirement - completedDungeons;
            AddGossipItemFor(player, GOSSIP_ICON_DOT, 
                             slotText + " - |cFFFF0000Locked (" + std::to_string(remaining) + " more needed)|r", 
                             GOSSIP_SENDER_MAIN, GOSSIP_ACTION_VAULT_INFO);
        }
    }

    // ========================================================================
    // VAULT CLAIM HANDLER
    // ========================================================================

    void HandleClaimSlot(Player* player, GameObject* go, uint8 slotNumber)
    {
        CloseGossipMenuFor(player);

        // Validate slot can be claimed
        if (!sDungeonEnhancementMgr->CanClaimVaultSlot(player, slotNumber))
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000You cannot claim this vault slot.|r"
            );
            return;
        }

        // Check requirements
        uint8 requirement = GetSlotRequirement(slotNumber);
        uint8 completedDungeons = sDungeonEnhancementMgr->GetPlayerVaultProgress(player);

        if (completedDungeons < requirement)
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000You need to complete %u more dungeons to unlock this slot.|r",
                requirement - completedDungeons
            );
            return;
        }

        // Offer choice: Gear or Tokens
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, 
                         "|cFF00FF00Claim High-Level Gear|r", 
                         GOSSIP_SENDER_MAIN, GOSSIP_ACTION_CLAIM_GEAR_BASE + slotNumber);
        
        uint32 tokens = GetVaultTokenReward(slotNumber, player);
        AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, 
                         "|cFF00FF00Claim " + std::to_string(tokens) + " Mythic+ Tokens|r", 
                         GOSSIP_SENDER_MAIN, GOSSIP_ACTION_CLAIM_TOKENS_BASE + slotNumber);
        
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "<- Back", 
                         GOSSIP_SENDER_MAIN, GOSSIP_ACTION_BACK);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, go->GetGUID());
    }

    // ========================================================================
    // REWARD CALCULATION
    // ========================================================================

    uint8 GetSlotRequirement(uint8 slotNumber)
    {
        switch (slotNumber)
        {
            case 1: return VAULT_SLOT_1_REQUIREMENT;
            case 2: return VAULT_SLOT_2_REQUIREMENT;
            case 3: return VAULT_SLOT_3_REQUIREMENT;
            default: return 0;
        }
    }

    uint32 GetVaultTokenReward(uint8 slotNumber, Player* player)
    {
        uint8 highestLevel = GetHighestKeystoneThisWeek(player);

        // Determine tier
        uint8 tier = 1;  // Tier 1: M+2-4
        if (highestLevel >= 8)
            tier = 3;  // Tier 3: M+8-10
        else if (highestLevel >= 5)
            tier = 2;  // Tier 2: M+5-7

        // Get token amount from configuration
        // Slot 1: 50/75/100 tokens (Tier 1/2/3)
        // Slot 2: 100/150/200 tokens
        // Slot 3: 150/225/300 tokens
        if (slotNumber == 1)
        {
            switch (tier)
            {
                case 3: return 100;
                case 2: return 75;
                default: return 50;
            }
        }
        else if (slotNumber == 2)
        {
            switch (tier)
            {
                case 3: return 200;
                case 2: return 150;
                default: return 100;
            }
        }
        else if (slotNumber == 3)
        {
            switch (tier)
            {
                case 3: return 300;
                case 2: return 225;
                default: return 150;
            }
        }

        return 0;
    }

    uint8 GetHighestKeystoneThisWeek(Player* player)
    {
        // Query highest keystone level from dc_mythic_run_history this week
        SeasonData* season = sDungeonEnhancementMgr->GetCurrentSeason();
        if (!season)
            return 2;

        uint32 weekStart = time(nullptr) - (7 * 24 * 60 * 60);  // Last 7 days

        QueryResult result = CharacterDatabase.Query(
            "SELECT MAX(keystoneLevel) FROM dc_mythic_run_history "
            "WHERE playerGUID = {} AND seasonId = {} AND completionTime >= {}",
            player->GetGUID().GetCounter(), season->seasonId, weekStart
        );

        if (result)
        {
            Field* fields = result->Fetch();
            return fields[0].Get<uint8>();
        }

        return 2;  // Default to M+2
    }

    void HandleClaimGear(Player* player, GameObject* go, uint8 slotNumber)
    {
        CloseGossipMenuFor(player);

        uint8 highestLevel = GetHighestKeystoneThisWeek(player);
        uint32 itemLevel = 200 + (highestLevel * 5);  // Base iLvl 200, +5 per M+ level

        // Create gear based on player's class and spec
        // For simplicity, we'll give Mythic+ tokens instead which can be traded for gear
        uint16 tokenAmount = GetVaultTokenReward(slotNumber, player);
        
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFF00FF00You would receive item level %u gear (Slot %u)|r",
            itemLevel, slotNumber
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFFFF00This feature will award high-level gear items in a future update.|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFFFF00For now, claim the %u Mythic+ Tokens instead.|r",
            tokenAmount
        );

        // Re-open claim menu
        HandleClaimSlot(player, go, slotNumber);
    }

    void HandleClaimTokens(Player* player, GameObject* go, uint8 slotNumber)
    {
        CloseGossipMenuFor(player);

        uint16 tokenAmount = GetVaultTokenReward(slotNumber, player);

        // Award tokens
        sDungeonEnhancementMgr->AwardDungeonTokens(player, tokenAmount);

        // Mark slot as claimed
        SeasonData* season = sDungeonEnhancementMgr->GetCurrentSeason();
        if (!season)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("|cFFFF0000No active season.|r");
            return;
        }

        std::string slotColumn = "slot" + std::to_string(slotNumber) + "Claimed";
        CharacterDatabase.Execute(
            "UPDATE dc_mythic_vault_progress SET {} = 1 WHERE playerGUID = {} AND seasonId = {}",
            slotColumn, player->GetGUID().GetCounter(), season->seasonId
        );

        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFF00FF00You claimed %u Mythic+ Tokens from Vault Slot %u!|r",
            tokenAmount, slotNumber
        );

        // Reopen vault menu
        OnGossipHello(player, go);
    }

    // ========================================================================
    // INFO DISPLAY
    // ========================================================================

    void ShowVaultInfo(Player* player, [[maybe_unused]] GameObject* go)
    {
        CloseGossipMenuFor(player);

        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFF00FF00=== Great Vault Guide ===|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(" ");
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFFFF00What is the Great Vault?|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "The Great Vault provides weekly rewards for completing Mythic+ dungeons."
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Complete dungeons to unlock up to 3 reward slots each week."
        );
        ChatHandler(player->GetSession()).PSendSysMessage(" ");
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFFFF00Unlocking Slots:|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - Slot 1: Complete 1 Mythic+ dungeon"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - Slot 2: Complete 4 Mythic+ dungeons"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - Slot 3: Complete 8 Mythic+ dungeons"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(" ");
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFFFF00Reward Options:|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Each unlocked slot offers a choice between:"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " 1. High-level gear (item level based on your highest M+ completed)"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " 2. Mythic+ Tokens (amount scales with slot and highest M+ level)"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(" ");
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFFFF00Token Scaling:|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - Tier 1 (M+2-4): 50/100/150 tokens (Slots 1/2/3)"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - Tier 2 (M+5-7): 75/150/225 tokens"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - Tier 3 (M+8-10): 100/200/300 tokens"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(" ");
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFFFF00Weekly Reset:|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "The Great Vault resets every Tuesday at server reset time."
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Progress and unclaimed rewards are lost - claim before reset!"
        );
    }
};

void AddSC_go_mythic_plus_great_vault()
{
    new go_mythic_plus_great_vault();
}
