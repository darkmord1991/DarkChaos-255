/*
 * Mythic+ Keystone NPC Script
 * Allows players to interact with keystone NPCs to begin M+ runs
 * Keystones exist for M+2 through M+10 difficulty
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "MythicPlusRunManager.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "ObjectGuid.h"

// Keystone difficulty mappings
enum KeystoneDifficulty : uint8
{
    KEYSTONE_M_PLUS_2 = 2,
    KEYSTONE_M_PLUS_3 = 3,
    KEYSTONE_M_PLUS_4 = 4,
    KEYSTONE_M_PLUS_5 = 5,
    KEYSTONE_M_PLUS_6 = 6,
    KEYSTONE_M_PLUS_7 = 7,
    KEYSTONE_M_PLUS_8 = 8,
    KEYSTONE_M_PLUS_9 = 9,
    KEYSTONE_M_PLUS_10 = 10
};

// Gossip option IDs
enum KeystoneGossipActions
{
    GOSSIP_ACTION_KEYSTONE_INFO = 1,
    GOSSIP_ACTION_START_KEYSTONE = 2,
    GOSSIP_ACTION_CLOSE = 3
};

/**
 * Get reward info for keystone level
 */
struct KeystoneRewardInfo
{
    uint8 level;
    uint32 itemLevel;
    uint32 baseTokens;
    std::string difficultyName;
};

KeystoneRewardInfo GetKeystoneRewardInfo(uint8 keystoneLevel)
{
    KeystoneRewardInfo info;
    info.level = keystoneLevel;
    
    // Item level (capped at M+10: 248 ilvl)
    if (keystoneLevel < 2)
        info.itemLevel = 226;
    else if (keystoneLevel <= 10)
        info.itemLevel = 232 + ((keystoneLevel - 2) * 2);  // M+2: 232, M+10: 248
    else
        info.itemLevel = 248;
    
    // Base tokens: 10 + (ilvl - 190) / 10
    info.baseTokens = 10 + std::max(0, static_cast<int32>((info.itemLevel - 190) / 10));
    
    // Difficulty name
    switch (keystoneLevel)
    {
        case 2: info.difficultyName = "|cff0070dd[Mythic +2]|r"; break;
        case 3: info.difficultyName = "|cff0070dd[Mythic +3]|r"; break;
        case 4: info.difficultyName = "|cff0070dd[Mythic +4]|r"; break;
        case 5: info.difficultyName = "|cff1eff00[Mythic +5]|r"; break;
        case 6: info.difficultyName = "|cff1eff00[Mythic +6]|r"; break;
        case 7: info.difficultyName = "|cff1eff00[Mythic +7]|r"; break;
        case 8: info.difficultyName = "|cffff8000[Mythic +8]|r"; break;
        case 9: info.difficultyName = "|cffff8000[Mythic +9]|r"; break;
        case 10: info.difficultyName = "|cffff8000[Mythic +10]|r"; break;
        default: info.difficultyName = "|cffaaaaaa[Unknown]|r"; break;
    }
    
    return info;
}

class npc_keystone : public CreatureScript
{
public:
    npc_keystone() : CreatureScript("npc_keystone") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!player || !creature)
            return false;

        ClearGossipMenuFor(player);
        
        // Get keystone level from creature entry (stored as 100 + keystone level)
        // Entry 100200 = M+2, 100300 = M+3, etc.
        uint8 keystoneLevel = (creature->GetEntry() - 100000) / 100;
        
        if (keystoneLevel < 2 || keystoneLevel > 10)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("|cffff0000Error:|r Invalid keystone level.");
            return false;
        }

        KeystoneRewardInfo rewardInfo = GetKeystoneRewardInfo(keystoneLevel);

        // Display header
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
            "|cffff8000=== Mythic+ Keystone ===|r", 
            GOSSIP_SENDER_MAIN, GOSSIP_ACTION_KEYSTONE_INFO);

        // Display difficulty and rewards
        std::string rewardText = rewardInfo.difficultyName + 
            " |cffffffffIlvl:|r " + std::to_string(rewardInfo.itemLevel) + 
            " |cffffffffTokens:|r " + std::to_string(rewardInfo.baseTokens);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, rewardText, GOSSIP_SENDER_MAIN, GOSSIP_ACTION_KEYSTONE_INFO);

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_KEYSTONE_INFO);

        // Check if player is in party
        if (player->GetGroup())
        {
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, 
                "|cff00ff00Start Mythic+ Keystone|r", 
                GOSSIP_SENDER_MAIN, GOSSIP_ACTION_START_KEYSTONE);
        }
        else
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                "|cffaaaaaa[You must be in a party to start]|r", 
                GOSSIP_SENDER_MAIN, GOSSIP_ACTION_KEYSTONE_INFO);
        }

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, " ", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_KEYSTONE_INFO);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "Close", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_CLOSE);
        
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        if (!player || !creature)
            return false;

        uint8 keystoneLevel = (creature->GetEntry() - 100000) / 100;

        if (action == GOSSIP_ACTION_START_KEYSTONE)
        {
            // Verify player is party leader
            if (player->GetGroup() && player->GetGroup()->GetLeaderGUID() != player->GetGUID())
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cffff0000Error:|r Only the party leader can start the keystone.");
                CloseGossipMenuFor(player);
                return false;
            }

            // Start the M+ run
            if (sMythicRuns->StartRun(player, keystoneLevel))
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cff00ff00Mythic+:|r Starting Mythic +%d dungeon!", keystoneLevel);
            }
            else
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cffff0000Error:|r Failed to start keystone. Check if keystone is already active.");
            }
        }

        CloseGossipMenuFor(player);
        return true;
    }
};

// Register all keystone NPCs (M+2 through M+10)
void AddSC_keystone_npcs()
{
    for (uint8 level = 2; level <= 10; ++level)
    {
        // Entry format: 100000 + (level * 100)
        // M+2 = 100200, M+3 = 100300, etc.
        new npc_keystone();
    }
}

// Add to script registry
void AddSCKeystoneNPCs(ScriptMgr* scriptMgr)
{
    scriptMgr->RegisterCreatureScript("npc_keystone", new npc_keystone());
}
