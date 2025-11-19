/*
 * Great Vault NPC script - Updated with token/ilvl display
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "MythicPlusRunManager.h"
#include "MythicPlusRewards.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "ObjectGuid.h"

class npc_mythic_plus_great_vault : public CreatureScript
{
public:
    npc_mythic_plus_great_vault() : CreatureScript("npc_mythic_plus_great_vault") { }

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

        // Fetch reward pool info
        auto rewards = sMythicRuns->GetVaultRewardPool(guidLow, seasonId, weekStart);
        uint32 itemLevel = 0;
        
        if (!rewards.empty())
        {
            itemLevel = rewards[0].second;  // Item level
        }
        else if (highestLevel > 0)
        {
            // Generate if not exists
            itemLevel = GetItemLevelForKeystoneLevel(highestLevel);
        }

        // Calculate token count based on ilvl
        uint32 tokenCount = itemLevel > 0 ? (10 + std::max(0, static_cast<int32>((itemLevel - 190) / 10))) : 0;

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

        // Display slots with token/ilvl info OR gear choices
        for (uint8 slot = 1; slot <= 3; ++slot)
        {
            uint8 threshold = sMythicRuns->GetVaultThreshold(slot);
            
            if (claimed && claimedSlot == slot)
            {
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                    "|cff00ff00[Slot " + std::to_string(slot) + "]|r Already Claimed", 
                    GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);
            }
            else if (unlocked[slot] && !claimed)
            {
                // Group rewards by slot (0-2=slot1, 3-5=slot2, 6-8=slot3)
                std::vector<std::pair<uint32, uint32>> slotRewards;
                uint8 slotStartIdx = (slot - 1) * 3;
                uint8 slotEndIdx = slot * 3;
                
                for (size_t i = slotStartIdx; i < rewards.size() && i < slotEndIdx; ++i)
                {
                    slotRewards.push_back(rewards[i]);
                }

                if (!slotRewards.empty())
                {
                    // Check if first reward is token (MYTHIC_VAULT_TOKEN = 101000)
                    if (slotRewards[0].first == 101000)
                    {
                        // Token mode display (backward compatible)
                        std::string rewardText = "|cff00ff00[Slot " + std::to_string(slot) + "]|r Claim |cffffffff" + 
                                                std::to_string(tokenCount) + " Tokens|r |cffff8000(ilvl " + 
                                                std::to_string(itemLevel) + " equivalent)|r";
                        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, rewardText, GOSSIP_SENDER_MAIN, 1000 + slotStartIdx);
                    }
                    else
                    {
                        // Gear mode display (Blizzlike)
                        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                            "|cff00ff00[Slot " + std::to_string(slot) + "]|r Choose Your Reward:", 
                            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_DEF);

                        for (size_t i = 0; i < slotRewards.size(); ++i)
                        {
                            ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(slotRewards[i].first);
                            if (itemTemplate)
                            {
                                std::string itemText = "  |cff0070dd→ " + std::string(itemTemplate->Name1) + 
                                                      "|r |cffaaaaaa(ilvl " + std::to_string(slotRewards[i].second) + ")|r";
                                AddGossipItemFor(player, GOSSIP_ICON_VENDOR, itemText,
                                               GOSSIP_SENDER_MAIN, 1000 + slotStartIdx + i);
                            }
                        }
                    }
                }
                else
                {
                    // Fallback if no rewards generated (should not happen with TokenFallback=1)
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

        // Claim slot (action 1000-1029 for gear choices, or legacy GOSSIP_ACTION_INFO_DEF+slot for tokens)
        if (action >= 1000 && action < 1030)
        {
            // New action range: 1000-1029 (3 slots × 3 choices × 3 max + buffer)
            // slot_index encoding: 0-2=slot1, 3-5=slot2, 6-8=slot3
            uint8 rewardIndex = action - 1000;
            uint8 slot = (rewardIndex / 3) + 1;  // Which vault slot (1-3)
            
            // Get reward info
            uint32 seasonId = sMythicRuns->GetCurrentSeasonId();
            uint32 weekStart = sMythicRuns->GetWeekStartTimestamp();
            uint32 guidLow = player->GetGUID().GetCounter();
            
            auto rewards = sMythicRuns->GetVaultRewardPool(guidLow, seasonId, weekStart);
            if (rewardIndex < rewards.size())
            {
                uint32 itemId = rewards[rewardIndex].first;
                if (sMythicRuns->ClaimVaultItemReward(player, slot, itemId))
                {
                    ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
                    std::string itemName = itemTemplate ? std::string(itemTemplate->Name1) : "Item";
                    std::string message = "|cff00ff00Great Vault:|r Claimed " + itemName + " successfully!";
                    ChatHandler(player->GetSession()).SendSysMessage(message.c_str());
                }
            }
            else
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cffff0000Error:|r Invalid reward selection.");
            }
            
            CloseGossipMenuFor(player);
            return true;
        }
        
        // Legacy claim action for backward compatibility
        if (action >= GOSSIP_ACTION_INFO_DEF + 1 && action <= GOSSIP_ACTION_INFO_DEF + 3)
        {
            uint8 slot = action - GOSSIP_ACTION_INFO_DEF;
            
            // Get reward info
            uint32 seasonId = sMythicRuns->GetCurrentSeasonId();
            uint32 weekStart = sMythicRuns->GetWeekStartTimestamp();
            uint32 guidLow = player->GetGUID().GetCounter();
            
            auto rewards = sMythicRuns->GetVaultRewardPool(guidLow, seasonId, weekStart);
            if (!rewards.empty())
            {
                uint32 tokenItemId = rewards[0].first;
                if (sMythicRuns->ClaimVaultItemReward(player, slot, tokenItemId))
                {
                    ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00Great Vault:|r Reward claimed successfully!");
                }
            }
            else
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cffff0000Error:|r No rewards available.");
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

void AddSC_npc_mythic_plus_great_vault()
{
    new npc_mythic_plus_great_vault();
}
