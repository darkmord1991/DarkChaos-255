/*
 * Great Vault NPC script
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "GreatVault.h"
#include "MythicPlusRunManager.h" // For Season/Week info
#include "MythicPlusRewards.h" // For constants if needed
#include "Chat.h"
#include "DatabaseEnv.h"
#include "ObjectGuid.h"
#include "ObjectMgr.h"
#include "ItemTemplate.h"

#include <unordered_map>

class npc_great_vault : public CreatureScript
{
public:
    npc_great_vault() : CreatureScript("npc_great_vault") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!player || !creature)
            return false;

        ClearGossipMenuFor(player);
        
        uint32 seasonId = sMythicRuns->GetCurrentSeasonId();
        uint32 weekStart = sMythicRuns->GetWeekStartTimestamp();
        uint32 guidLow = player->GetGUID().GetCounter();

        // Fetch vault state
        QueryResult vaultResult = CharacterDatabase.Query(
            "SELECT runs_completed, highest_level, slot1_unlocked, slot2_unlocked, slot3_unlocked, reward_claimed, claimed_slot "
            "FROM dc_weekly_vault WHERE character_guid = {} AND season_id = {} AND week_start = {}",
            guidLow, seasonId, weekStart);

        uint8 runsCompleted = 0;
        uint8 highestLevel = 0;
        bool unlocked[4] = { false, false, false, false };
        bool claimed = false;
        uint8 claimedSlot = 0;

        if (vaultResult)
        {
            Field* fields = vaultResult->Fetch();
            runsCompleted = fields[0].Get<uint8>();
            highestLevel = fields[1].Get<uint8>();
            unlocked[1] = fields[2].Get<bool>();
            unlocked[2] = fields[3].Get<bool>();
            unlocked[3] = fields[4].Get<bool>();
            claimed = fields[5].Get<bool>();
            claimedSlot = fields[6].Get<uint8>();
        }

        // Fetch reward pool info (global slot index -> reward)
        auto rewards = sGreatVault->GetVaultRewardPool(guidLow, seasonId, weekStart);
        std::unordered_map<uint8, std::pair<uint32, uint32>> rewardBySlot;
        for (auto const& [slotIndex, itemId, itemLevel] : rewards)
            rewardBySlot[slotIndex] = { itemId, itemLevel };

        // Display header
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffff8000=== Great Vault ===|r", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);
        
        if (runsCompleted > 0)
        {
            std::string statsText = "|cffffffffRuns This Week:|r " + std::to_string(runsCompleted) + 
                                   " | |cffffffffHighest:|r M+" + std::to_string(highestLevel);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, statsText, GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);
        }
        else
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "|cffaaaaaaNo runs completed this week|r", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);
        }

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);

        // Display Mythic+ track slots (global slots 4-6)
        for (uint8 slot = 1; slot <= 3; ++slot)
        {
            uint8 threshold = sGreatVault->GetVaultThreshold(slot);
            uint8 globalSlot = static_cast<uint8>(3 + slot); // Track 1 (Mythic+)
            
            if (claimed && claimedSlot == globalSlot)
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                    "|cff00ff00[Slot " + std::to_string(slot) + "]|r Already Claimed", 
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);
            }
            else if (unlocked[slot] && !claimed)
            {
                auto itr = rewardBySlot.find(globalSlot);
                if (itr == rewardBySlot.end())
                {
                    // Try generating pool if missing
                    sGreatVault->GenerateVaultRewardPool(guidLow, seasonId, weekStart);
                    rewards = sGreatVault->GetVaultRewardPool(guidLow, seasonId, weekStart);
                    rewardBySlot.clear();
                    for (auto const& [slotIndex, itemId, itemLevel] : rewards)
                        rewardBySlot[slotIndex] = { itemId, itemLevel };
                    itr = rewardBySlot.find(globalSlot);
                }

                if (itr != rewardBySlot.end())
                {
                    uint32 itemId = itr->second.first;
                    uint32 itemLevel = itr->second.second;
                    uint32 tokenCount = itemLevel > 0 ? (10 + std::max(0, static_cast<int32>((itemLevel - 190) / 10))) : 0;

                    ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
                    std::string name = itemTemplate ? std::string(itemTemplate->Name1) : ("Item " + std::to_string(itemId));

                    std::string rewardText;
                    // Check if it's a token (assuming 300311 is the token ID)
                    if (itemId == 300311)
                    {
                        rewardText = "|cff00ff00[Slot " + std::to_string(slot) + "]|r Claim |cffffffff" +
                            std::to_string(tokenCount) + " Tokens|r |cffff8000(ilvl " + std::to_string(itemLevel) + " equivalent)|r";
                    }
                    else
                    {
                        rewardText = "|cff00ff00[Slot " + std::to_string(slot) + "]|r Claim |cff0070dd" + name +
                            "|r |cffff8000(ilvl " + std::to_string(itemLevel) + ")|r";
                    }

                    AddGossipItemFor(player, GOSSIP_ICON_VENDOR, rewardText, GOSSIP_SENDER_MAIN, 2000 + slot);
                }
                else
                {
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT,
                        "|cffaaaaaa[Slot " + std::to_string(slot) + "]|r No rewards available",
                        GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);
                }
            }
            else if (unlocked[slot] && claimed)
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                    "|cffaaaaaa[Slot " + std::to_string(slot) + "]|r Available (already claimed another)", 
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);
            }
            else
            {
                std::string lockText = "|cffaaaaaa[Slot " + std::to_string(slot) + "]|r Locked - Complete " + 
                                      std::to_string(threshold) + " M+ runs (" + std::to_string(runsCompleted) + 
                                      "/" + std::to_string(threshold) + ")";
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, lockText, GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);
            }
        }

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "|cff00ff00Visit Token Vendor|r", GOSSIP_SENDER_MAIN, 100);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Close", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);
        
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        if (!player || !creature)
            return false;

        ClearGossipMenuFor(player);

        // Claim Mythic+ track slot (UI shows 1-3, but vault pool uses global slots 4-6)
        if (action >= 2001 && action <= 2003)
        {
            uint8 slotInTrack = static_cast<uint8>(action - 2000); // 1..3
            uint8 globalSlot = static_cast<uint8>(3 + slotInTrack);
            
            // Get reward info
            uint32 seasonId = sMythicRuns->GetCurrentSeasonId();
            uint32 weekStart = sMythicRuns->GetWeekStartTimestamp();
            uint32 guidLow = player->GetGUID().GetCounter();
            
            auto rewards = sGreatVault->GetVaultRewardPool(guidLow, seasonId, weekStart);

            uint32 itemId = 0;
            for (auto const& [slotIndex, rewardItemId, /*ilvl*/ _] : rewards)
            {
                if (slotIndex == globalSlot)
                {
                    itemId = rewardItemId;
                    break;
                }
            }

            if (!itemId)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cffff0000Error:|r No reward available for this slot.");
                CloseGossipMenuFor(player);
                return true;
            }

            if (sGreatVault->ClaimVaultItemReward(player, globalSlot, itemId))
            {
                ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
                std::string itemName = itemTemplate ? std::string(itemTemplate->Name1) : "Item";
                std::string message = "|cff00ff00Great Vault:|r Claimed " + itemName + " successfully!";
                ChatHandler(player->GetSession()).SendSysMessage(message.c_str());
            }
            
            CloseGossipMenuFor(player);
            return true;
        }
        
        // Token vendor redirect
        if (action == 100)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00Great Vault:|r Find the Token Vendor nearby to exchange your tokens for gear!");
            CloseGossipMenuFor(player);
            return true;
        }

        CloseGossipMenuFor(player);
        return true;
    }
};

void AddSC_npc_great_vault()
{
    new npc_great_vault();
}
