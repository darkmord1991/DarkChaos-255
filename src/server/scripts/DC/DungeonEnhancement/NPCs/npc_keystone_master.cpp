/*
 * ============================================================================
 * Dungeon Enhancement System - Keystone Master NPC
 * ============================================================================
 * Purpose: Provide keystone management services
 * NPC ID: 190006
 * Location: Stormwind, Orgrimmar, Dalaran
 * ============================================================================
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "DungeonEnhancementManager.h"
#include "../Core/DungeonEnhancementConstants.h"

using namespace DungeonEnhancement;

class npc_keystone_master : public CreatureScript
{
public:
    npc_keystone_master() : CreatureScript("npc_keystone_master") { }

    struct npc_keystone_masterAI : public ScriptedAI
    {
        npc_keystone_masterAI(Creature* creature) : ScriptedAI(creature) { }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_keystone_masterAI(creature);
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!sDungeonEnhancementMgr->IsEnabled())
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Dungeon Enhancement system is currently disabled.");
            return true;
        }

        bool hasKeystone = sDungeonEnhancementMgr->PlayerHasKeystone(player);

        if (hasKeystone)
        {
            uint8 keystoneLevel = sDungeonEnhancementMgr->GetPlayerKeystoneLevel(player);
            
            AddGossipItemFor(player, GOSSIP_ICON_TALK, 
                             "|cFF00FF00Current Keystone: Mythic+|r " + std::to_string(keystoneLevel), 
                             GOSSIP_SENDER_MAIN, GOSSIP_ACTION_INFO_KEYSTONE);
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Destroy Keystone", 
                             GOSSIP_SENDER_MAIN, GOSSIP_ACTION_DESTROY_KEYSTONE);
        }
        else
        {
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Request Starting Keystone (M+2)", 
                             GOSSIP_SENDER_MAIN, GOSSIP_ACTION_REQUEST_KEYSTONE);
        }

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "View Current Week's Affixes", 
                         GOSSIP_SENDER_MAIN, GOSSIP_ACTION_VIEW_AFFIXES);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "View My Seasonal Rating", 
                         GOSSIP_SENDER_MAIN, GOSSIP_ACTION_VIEW_RATING);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "How do Keystones work?", 
                         GOSSIP_SENDER_MAIN, GOSSIP_ACTION_KEYSTONE_INFO);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        player->PlayerTalkClass->ClearMenus();

        switch (action)
        {
            case GOSSIP_ACTION_REQUEST_KEYSTONE:
                HandleRequestKeystone(player, creature);
                break;

            case GOSSIP_ACTION_DESTROY_KEYSTONE:
                HandleDestroyKeystone(player, creature);
                break;

            case GOSSIP_ACTION_INFO_KEYSTONE:
                HandleKeystoneInfo(player, creature);
                break;

            case GOSSIP_ACTION_VIEW_AFFIXES:
                HandleViewAffixes(player, creature);
                break;

            case GOSSIP_ACTION_VIEW_RATING:
                HandleViewRating(player, creature);
                break;

            case GOSSIP_ACTION_KEYSTONE_INFO:
                HandleKeystoneHowTo(player, creature);
                break;

            case GOSSIP_ACTION_CONFIRM_DESTROY:
                ConfirmDestroyKeystone(player, creature);
                break;

            case GOSSIP_ACTION_BACK:
                OnGossipHello(player, creature);
                break;

            default:
                CloseGossipMenuFor(player);
                break;
        }

        return true;
    }

private:
    // ========================================================================
    // KEYSTONE MANAGEMENT
    // ========================================================================

    void HandleRequestKeystone(Player* player, Creature* creature)
    {
        CloseGossipMenuFor(player);

        // Check if player already has keystone
        if (sDungeonEnhancementMgr->PlayerHasKeystone(player))
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000You already have a Mythic+ Keystone. Destroy it first if you want a replacement.|r"
            );
            return;
        }

        // Check bag space
        if (player->GetFreeInventorySlots() == 0)
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000Your bags are full. Make space and try again.|r"
            );
            return;
        }

        // Give starting keystone (M+2)
        uint8 startLevel = MYTHIC_PLUS_MIN_LEVEL;
        sDungeonEnhancementMgr->GivePlayerKeystone(player, startLevel);

        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFF00FF00You have received a Mythic+%u Keystone!|r", startLevel
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Activate it at the Font of Power inside any Mythic+ dungeon to begin your run."
        );

        LOG_INFO(LogCategory::MYTHIC_PLUS, 
                 "Player %s requested starting keystone (M+%u) from Keystone Master",
                 player->GetName().c_str(), startLevel);
    }

    void HandleDestroyKeystone(Player* player, Creature* creature)
    {
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, 
                         "|cFFFF0000Confirm: Destroy Keystone (This cannot be undone!)|r", 
                         GOSSIP_SENDER_MAIN, GOSSIP_ACTION_CONFIRM_DESTROY);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "<- Cancel", 
                         GOSSIP_SENDER_MAIN, GOSSIP_ACTION_BACK);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    void ConfirmDestroyKeystone(Player* player, Creature* creature)
    {
        CloseGossipMenuFor(player);

        if (!sDungeonEnhancementMgr->PlayerHasKeystone(player))
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000You don't have a keystone to destroy.|r"
            );
            return;
        }

        uint8 keystoneLevel = sDungeonEnhancementMgr->GetPlayerKeystoneLevel(player);
        sDungeonEnhancementMgr->RemovePlayerKeystone(player);

        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFFAA00Your Mythic+%u Keystone has been destroyed.|r", keystoneLevel
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "You can request a new M+2 keystone from the Keystone Master."
        );

        LOG_INFO(LogCategory::MYTHIC_PLUS, 
                 "Player %s destroyed their M+%u keystone",
                 player->GetName().c_str(), keystoneLevel);
    }

    void HandleKeystoneInfo(Player* player, Creature* creature)
    {
        CloseGossipMenuFor(player);

        if (!sDungeonEnhancementMgr->PlayerHasKeystone(player))
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000You don't have a keystone.|r"
            );
            return;
        }

        uint8 keystoneLevel = sDungeonEnhancementMgr->GetPlayerKeystoneLevel(player);

        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFF00FF00=== Your Mythic+ Keystone ===|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Level: |cFFFFAA00Mythic+%u|r", keystoneLevel
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Max Level: |cFFFFAA00Mythic+%u|r", MYTHIC_PLUS_MAX_LEVEL
        );
        ChatHandler(player->GetSession()).PSendSysMessage(" ");
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFFFF00Upgrade Tiers:|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - |cFF00FF000-5 deaths:|r +2 keystone levels"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - |cFF00FF006-10 deaths:|r +1 keystone level"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - |cFFFFAA0011-14 deaths:|r Same level (no upgrade)"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - |cFFFF000015 deaths:|r Keystone destroyed (auto-fail)"
        );
    }

    // ========================================================================
    // INFO DISPLAYS
    // ========================================================================

    void HandleViewAffixes(Player* player, Creature* creature)
    {
        CloseGossipMenuFor(player);

        SeasonData* season = sDungeonEnhancementMgr->GetCurrentSeason();
        if (!season)
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000No active Mythic+ season.|r"
            );
            return;
        }

        AffixRotation* rotation = sDungeonEnhancementMgr->GetCurrentAffixRotation();
        if (!rotation)
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000No affix rotation active.|r"
            );
            return;
        }

        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFF00FF00=== Current Week's Affixes (Season %u, Week %u) ===|r",
            season->seasonId, rotation->weekNumber
        );

        // Show tier 1 affix (M+2)
        if (rotation->tier1AffixId > 0)
        {
            AffixData* affix = sDungeonEnhancementMgr->GetAffixById(rotation->tier1AffixId);
            if (affix)
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cFFFFAA00[M+2+]|r %s (%s)", 
                    affix->affixName.c_str(), affix->affixType.c_str()
                );
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "  %s", affix->description.c_str()
                );
            }
        }

        // Show tier 2 affix (M+4)
        if (rotation->tier2AffixId > 0)
        {
            AffixData* affix = sDungeonEnhancementMgr->GetAffixById(rotation->tier2AffixId);
            if (affix)
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cFFFFAA00[M+4+]|r %s (%s)", 
                    affix->affixName.c_str(), affix->affixType.c_str()
                );
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "  %s", affix->description.c_str()
                );
            }
        }

        // Show tier 3 affix (M+7)
        if (rotation->tier3AffixId > 0)
        {
            AffixData* affix = sDungeonEnhancementMgr->GetAffixById(rotation->tier3AffixId);
            if (affix)
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cFFFFAA00[M+7+]|r %s (%s)", 
                    affix->affixName.c_str(), affix->affixType.c_str()
                );
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "  %s", affix->description.c_str()
                );
            }
        }

        ChatHandler(player->GetSession()).PSendSysMessage(" ");
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFF888888Affixes rotate weekly on Tuesday.|r"
        );
    }

    void HandleViewRating(Player* player, Creature* creature)
    {
        CloseGossipMenuFor(player);

        SeasonData* season = sDungeonEnhancementMgr->GetCurrentSeason();
        if (!season)
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000No active Mythic+ season.|r"
            );
            return;
        }

        uint32 rating = sDungeonEnhancementMgr->GetPlayerRating(player);

        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFF00FF00=== Your Mythic+ Rating (Season %u) ===|r", season->seasonId
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Current Rating: |cFFFFAA00%u|r", rating
        );

        // Determine rank tier
        std::string rankName = "Unranked";
        if (rating >= 2000)
            rankName = "Mythic";
        else if (rating >= 1500)
            rankName = "Heroic";
        else if (rating >= 1000)
            rankName = "Advanced";
        else if (rating >= 500)
            rankName = "Novice";

        ChatHandler(player->GetSession()).PSendSysMessage(
            "Rank Tier: |cFFFFAA00%s|r", rankName.c_str()
        );
        ChatHandler(player->GetSession()).PSendSysMessage(" ");
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFF888888Complete Mythic+ dungeons to increase your rating.|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFF888888Higher keystone levels and fewer deaths grant more rating.|r"
        );
    }

    void HandleKeystoneHowTo(Player* player, Creature* creature)
    {
        CloseGossipMenuFor(player);

        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFF00FF00=== How Keystones Work ===|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(" ");
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFFFF001. Getting Started|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Request a starting keystone (M+2) from the Keystone Master."
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Each player can have ONE keystone at a time."
        );
        ChatHandler(player->GetSession()).PSendSysMessage(" ");
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFFFF002. Activating Your Keystone|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Teleport to any Mythic+ dungeon using the Dungeon Teleporter."
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Use the Font of Power at the entrance to activate your keystone."
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Only ONE player needs to activate their keystone for the group."
        );
        ChatHandler(player->GetSession()).PSendSysMessage(" ");
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFFFF003. Completing the Run|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Defeat all bosses before reaching 15 total deaths."
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Each death counts toward the group total."
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "The 15th death instantly fails the run and destroys the keystone."
        );
        ChatHandler(player->GetSession()).PSendSysMessage(" ");
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFFFF004. Rewards & Upgrades|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Success: Your keystone upgrades by +1 or +2 levels (based on deaths)."
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Failure: Your keystone is destroyed (request a new M+2)."
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "All players receive Mythic+ Tokens for vendor rewards."
        );
        ChatHandler(player->GetSession()).PSendSysMessage(" ");
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFFFF005. Weekly Vault|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Complete 1/4/8 dungeons per week to unlock Great Vault slots."
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Choose between high-level gear or bonus Mythic+ Tokens."
        );
    }
};

void AddSC_npc_keystone_master()
{
    new npc_keystone_master();
}
