/*
 * ============================================================================
 * Dungeon Enhancement System - Dungeon Teleporter NPC
 * ============================================================================
 * Purpose: Provide gossip menu to teleport players to Mythic+ dungeons
 * NPC ID: 190003
 * Location: Stormwind, Orgrimmar, Dalaran
 * ============================================================================
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "../Core/DungeonEnhancementManager.h"
#include "../Core/DungeonEnhancementConstants.h"

using namespace DungeonEnhancement;

class npc_mythic_plus_dungeon_teleporter : public CreatureScript
{
public:
    npc_mythic_plus_dungeon_teleporter() : CreatureScript("npc_mythic_plus_dungeon_teleporter") { }

    struct npc_mythic_plus_dungeon_teleporterAI : public ScriptedAI
    {
        npc_mythic_plus_dungeon_teleporterAI(Creature* creature) : ScriptedAI(creature) { }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_mythic_plus_dungeon_teleporterAI(creature);
    }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!sDungeonEnhancementMgr->IsEnabled())
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Dungeon Enhancement system is currently disabled.");
            return true;
        }

        // Main menu
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Wrath of the Lich King Dungeons", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_WOTLK_DUNGEONS);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Burning Crusade Dungeons", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_TBC_DUNGEONS);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Classic Dungeons", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_CLASSIC_DUNGEONS);
    uint8 preferredLevel = sDungeonEnhancementMgr->GetPlayerPreferredMythicLevel(player);
    AddGossipItemFor(player, GOSSIP_ICON_CHAT,
             "Set Preferred Mythic+ Level (Current: M+" + std::to_string(preferredLevel) + ")",
             GOSSIP_SENDER_MAIN, GOSSIP_ACTION_SET_MYTHIC_LEVEL_MENU);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "View Current Affixes", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_VIEW_AFFIXES);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "About Mythic+ System", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_ABOUT_SYSTEM);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
    {
        player->PlayerTalkClass->ClearMenus();

        if (action >= GOSSIP_ACTION_SET_MYTHIC_LEVEL_BASE && action < GOSSIP_ACTION_SET_MYTHIC_LEVEL_BASE + 100)
        {
            uint8 level = static_cast<uint8>(action - GOSSIP_ACTION_SET_MYTHIC_LEVEL_BASE);
            HandleSetPreferredMythicLevel(player, creature, level);
            return true;
        }

        switch (action)
        {
            // ========================================
            // EXPANSION MENUS
            // ========================================
            case GOSSIP_ACTION_WOTLK_DUNGEONS:
                ShowWotLKDungeons(player, creature);
                break;

            case GOSSIP_ACTION_TBC_DUNGEONS:
                ShowTBCDungeons(player, creature);
                break;

            case GOSSIP_ACTION_CLASSIC_DUNGEONS:
                ShowClassicDungeons(player, creature);
                break;

            case GOSSIP_ACTION_SET_MYTHIC_LEVEL_MENU:
                ShowMythicPlusLevelMenu(player, creature);
                break;

            // ========================================
            // SPECIFIC DUNGEON TELEPORTS
            // ========================================
            case GOSSIP_ACTION_TELEPORT_UTGARDE_KEEP:
                TeleportToDungeon(player, 574, 148.0f, -223.0f, 16.0f, 3.2f);  // Utgarde Keep
                break;

            case GOSSIP_ACTION_TELEPORT_UTGARDE_PINNACLE:
                TeleportToDungeon(player, 575, 1245.0f, -835.0f, 195.0f, 0.0f);  // Utgarde Pinnacle
                break;

            case GOSSIP_ACTION_TELEPORT_HALLS_OF_LIGHTNING:
                TeleportToDungeon(player, 602, 1329.0f, 237.0f, 53.0f, 3.1f);  // Halls of Lightning
                break;

            case GOSSIP_ACTION_TELEPORT_HALLS_OF_STONE:
                TeleportToDungeon(player, 599, 853.0f, 1011.0f, 84.0f, 3.5f);  // Halls of Stone
                break;

            case GOSSIP_ACTION_TELEPORT_SLAVE_PENS:
                TeleportToDungeon(player, 547, 6.0f, -105.0f, -17.0f, 0.0f);  // The Slave Pens
                break;

            case GOSSIP_ACTION_TELEPORT_UNDERBOG:
                TeleportToDungeon(player, 546, 34.0f, 0.0f, -3.0f, 1.6f);  // The Underbog
                break;

            case GOSSIP_ACTION_TELEPORT_STRATHOLME:
                TeleportToDungeon(player, 329, 3392.0f, -3379.0f, 142.0f, 0.0f);  // Stratholme
                break;

            case GOSSIP_ACTION_TELEPORT_SCHOLOMANCE:
                TeleportToDungeon(player, 289, 190.0f, 127.0f, 137.0f, 6.3f);  // Scholomance
                break;

            // ========================================
            // INFO ACTIONS
            // ========================================
            case GOSSIP_ACTION_VIEW_AFFIXES:
                ShowCurrentAffixes(player, creature);
                break;

            case GOSSIP_ACTION_ABOUT_SYSTEM:
                ShowAboutSystem(player, creature);
                break;

            // ========================================
            // BACK BUTTON
            // ========================================
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
    // EXPANSION DUNGEON MENUS
    // ========================================================================

    void ShowWotLKDungeons(Player* player, Creature* creature)
    {
        AddGossipItemFor(player, GOSSIP_ICON_TAXI, "[Level 80] Utgarde Keep", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_TELEPORT_UTGARDE_KEEP);
        AddGossipItemFor(player, GOSSIP_ICON_TAXI, "[Level 80] Utgarde Pinnacle", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_TELEPORT_UTGARDE_PINNACLE);
        AddGossipItemFor(player, GOSSIP_ICON_TAXI, "[Level 80] Halls of Lightning", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_TELEPORT_HALLS_OF_LIGHTNING);
        AddGossipItemFor(player, GOSSIP_ICON_TAXI, "[Level 80] Halls of Stone", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_TELEPORT_HALLS_OF_STONE);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "<- Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_BACK);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    void ShowTBCDungeons(Player* player, Creature* creature)
    {
        AddGossipItemFor(player, GOSSIP_ICON_TAXI, "[Level 70] The Slave Pens", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_TELEPORT_SLAVE_PENS);
        AddGossipItemFor(player, GOSSIP_ICON_TAXI, "[Level 70] The Underbog", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_TELEPORT_UNDERBOG);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "<- Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_BACK);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    void ShowClassicDungeons(Player* player, Creature* creature)
    {
        AddGossipItemFor(player, GOSSIP_ICON_TAXI, "[Level 60] Stratholme", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_TELEPORT_STRATHOLME);
        AddGossipItemFor(player, GOSSIP_ICON_TAXI, "[Level 60] Scholomance", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_TELEPORT_SCHOLOMANCE);
        AddGossipItemFor(player, GOSSIP_ICON_TALK, "<- Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_BACK);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    void ShowMythicPlusLevelMenu(Player* player, Creature* creature)
    {
        if (!player)
            return;

        player->PlayerTalkClass->ClearMenus();

        uint8 currentLevel = sDungeonEnhancementMgr->GetPlayerPreferredMythicLevel(player);

        for (uint8 level = MYTHIC_PLUS_MIN_LEVEL; level <= MYTHIC_PLUS_MAX_LEVEL; ++level)
        {
            std::string label = "Set preference to Mythic+" + std::to_string(level);
            if (level == currentLevel)
                label += " (current)";

            AddGossipItemFor(player, GOSSIP_ICON_CHAT, label,
                             GOSSIP_SENDER_MAIN, GOSSIP_ACTION_SET_MYTHIC_LEVEL_BASE + level);
        }

        AddGossipItemFor(player, GOSSIP_ICON_TALK, "<- Back", GOSSIP_SENDER_MAIN, GOSSIP_ACTION_BACK);

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    void HandleSetPreferredMythicLevel(Player* player, Creature* creature, uint8 level)
    {
        if (!player)
            return;

        sDungeonEnhancementMgr->SetPlayerPreferredMythicLevel(player, level);
        ShowMythicPlusLevelMenu(player, creature);
    }

    // ========================================================================
    // TELEPORT HANDLER
    // ========================================================================

    void TeleportToDungeon(Player* player, uint16 mapId, float x, float y, float z, float o)
    {
        CloseGossipMenuFor(player);

        // Check if dungeon is in seasonal rotation
        if (!sDungeonEnhancementMgr->IsDungeonMythicPlusEnabled(mapId))
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000This dungeon is not available in the current Mythic+ season.|r"
            );
            return;
        }

        // Check if player has keystone (optional requirement)
        if (!sDungeonEnhancementMgr->PlayerHasKeystone(player))
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFFFF00Warning: You do not have a Mythic+ Keystone. Speak to the Keystone Master to obtain one.|r"
            );
            // Continue with teleport anyway (they might be joining a group)
        }

        // Teleport player
        player->TeleportTo(mapId, x, y, z, o);

        LOG_INFO(LogCategory::MYTHIC_PLUS, 
                 "Player %s teleported to dungeon map %u via Dungeon Teleporter NPC",
                 player->GetName().c_str(), mapId);
    }

    // ========================================================================
    // INFO MENUS
    // ========================================================================

    void ShowCurrentAffixes(Player* player, Creature* creature)
    {
        CloseGossipMenuFor(player);

        // Get current season
        SeasonData* season = sDungeonEnhancementMgr->GetCurrentSeason();
        if (!season)
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000No active Mythic+ season.|r"
            );
            return;
        }

        // Get current week's affixes
        AffixRotation* rotation = sDungeonEnhancementMgr->GetCurrentAffixRotation();
        if (!rotation)
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "|cFFFF0000No affix rotation active.|r"
            );
            return;
        }

        // Display affixes
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFF00FF00=== Current Week's Affixes (Season %u, Week %u) ===|r",
            season->seasonId, rotation->weekNumber
        );

        // Tier 1 (M+2)
        if (rotation->tier1AffixId > 0)
        {
            AffixData* affix = sDungeonEnhancementMgr->GetAffixById(rotation->tier1AffixId);
            if (affix)
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cFFFFAA00[M+2+]|r %s - %s",
                    affix->affixName.c_str(), affix->affixDescription.c_str()
                );
            }
        }

        // Tier 2 (M+4)
        if (rotation->tier2AffixId > 0)
        {
            AffixData* affix = sDungeonEnhancementMgr->GetAffixById(rotation->tier2AffixId);
            if (affix)
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cFFFFAA00[M+4+]|r %s - %s",
                    affix->affixName.c_str(), affix->affixDescription.c_str()
                );
            }
        }

        // Tier 3 (M+7)
        if (rotation->tier3AffixId > 0)
        {
            AffixData* affix = sDungeonEnhancementMgr->GetAffixById(rotation->tier3AffixId);
            if (affix)
            {
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cFFFFAA00[M+7+]|r %s - %s",
                    affix->affixName.c_str(), affix->affixDescription.c_str()
                );
            }
        }

        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFF00FF00Affixes rotate weekly on Tuesday.|r"
        );
    }

    void ShowAboutSystem(Player* player, Creature* creature)
    {
        CloseGossipMenuFor(player);

        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFF00FF00=== Mythic+ Dungeon System ===|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "Mythic+ is a challenging end-game dungeon system with:"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - Progressive difficulty (M+2 to M+10)"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - Weekly rotating affixes that modify gameplay"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - Death limit of 15 before auto-fail"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - Keystone upgrades based on performance"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - Great Vault weekly rewards (3 slots)"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            " - Seasonal achievements and titles"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(" ");
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cFFFFFF00How to start:|r"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "1. Obtain a Mythic+ Keystone from the Keystone Master"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "2. Form a group and teleport to a dungeon"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "3. Use the Font of Power at the entrance to activate your keystone"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "4. Complete all bosses before reaching 15 deaths"
        );
        ChatHandler(player->GetSession()).PSendSysMessage(
            "5. Collect rewards and upgrade your keystone!"
        );
    }
};

void AddSC_npc_mythic_plus_dungeon_teleporter()
{
    new npc_mythic_plus_dungeon_teleporter();
}
