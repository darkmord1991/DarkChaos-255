/*
 * This source code is part of the DarkChaos Custom Content project
 * Copyright (C) DarkChaos-255 Custom WoW Server
 * 
 * ItemUpgrade - Quest Reward Hook
 * Purpose: Award artifact essence when artifact quest completes
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Quest.h"
#include "ObjectAccessor.h"
#include "ItemUpgrade/ItemUpgradeManager.h"
#include "Log.h"

// Forward declarations
class UpgradeManager;

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        class ItemUpgradeArtifactQuestHook : public PlayerScript
        {
        public:
            ItemUpgradeArtifactQuestHook() : PlayerScript("ItemUpgradeArtifactQuestHook") {}

            /**
             * Hook triggered when player completes any quest
             * Awards essence if quest is an artifact quest
             */
            void OnQuestComplete(Player* player, Quest const* quest) override
            {
                if (!player || !quest)
                    return;

                // Quest IDs that grant artifact items
                static const uint32 ARTIFACT_QUEST_ID = 12340;  // Artifact Accessories quest
                static const uint32 ARTIFACT_QUEST_SEASON = 1;  // Current season
                static const uint32 STARTING_ESSENCE_AMOUNT = 500;  // Starting essence

                // Check if this is an artifact quest
                if (quest->GetQuestId() != ARTIFACT_QUEST_ID)
                    return;

                // Safety check: Verify quest actually exists
                if (quest->GetTitle() != "Artifact Accessories")
                {
                    LOG_ERROR("scripts.darkchaos", "ItemUpgradeArtifactQuestHook: Quest ID %u does not match expected artifact quest title", ARTIFACT_QUEST_ID);
                    return;
                }

                // Get the upgrade manager
                UpgradeManager* mgr = GetUpgradeManager();
                if (!mgr)
                {
                    LOG_ERROR("scripts.darkchaos", "ItemUpgradeArtifactQuestHook: Failed to get UpgradeManager for player %u", player->GetGUID().GetCounter());
                    return;
                }

                uint32 playerGuid = player->GetGUID().GetCounter();

                // Award starting essence (500)
                if (mgr->AddCurrency(playerGuid, CURRENCY_ARTIFACT_ESSENCE, STARTING_ESSENCE_AMOUNT, ARTIFACT_QUEST_SEASON))
                {
                    LOG_INFO("scripts.darkchaos", "ItemUpgradeArtifactQuestHook: Awarded %u essence to player %u on quest completion (quest %u)",
                        STARTING_ESSENCE_AMOUNT, playerGuid, ARTIFACT_QUEST_ID);

                    // Notify player
                    ChatHandler(player->GetSession()).PSendSysMessage("You have received %u Artifact Essence!", STARTING_ESSENCE_AMOUNT);
                }
                else
                {
                    LOG_WARN("scripts.darkchaos", "ItemUpgradeArtifactQuestHook: Failed to award essence to player %u (quest %u)", playerGuid, ARTIFACT_QUEST_ID);
                }
            }

            /**
             * Alternative hook: OnQuestReward
             * Fires when player receives quest rewards from quest giver
             * Can be used as backup to OnQuestComplete
             */
            void OnQuestReward(Player* player, Quest const* quest, uint32 /*opt*/) override
            {
                // This is a backup - same logic as OnQuestComplete
                // Uncomment if OnQuestComplete doesn't fire
                // OnQuestComplete(player, quest);
            }
        };

        /**
         * Script Load Hook - Register the player script
         */
        class ItemUpgradeQuestRewardLoader : public ScriptMgr
        {
        public:
            void OnScriptLoad() override
            {
                new ItemUpgradeArtifactQuestHook();
            }
        };
    }
}

/**
 * AddSC_ItemUpgradeQuestRewardHook
 * Entry point for script compilation
 */
void AddSC_ItemUpgradeQuestRewardHook()
{
    new DarkChaos::ItemUpgrade::ItemUpgradeArtifactQuestHook();
}

// ============================================================================
// IMPLEMENTATION NOTES
// ============================================================================
/*
 * 1. LOCATION: Place this file in:
 *    src/server/scripts/DC/ItemUpgrades/ItemUpgradeQuestRewardHook.cpp
 *
 * 2. COMPILATION: Add to CMakeLists.txt in scripts directory:
 *    src/server/scripts/DC/ItemUpgrades/ItemUpgradeQuestRewardHook.cpp
 *
 * 3. QUEST ID: 12340 is hardcoded
 *    Change ARTIFACT_QUEST_ID if using different quest ID
 *
 * 4. ESSENCE AMOUNT: 500 essence per quest completion
 *    Change STARTING_ESSENCE_AMOUNT to modify reward
 *
 * 5. CURRENCY TYPE: CURRENCY_ARTIFACT_ESSENCE (value 2)
 *    Defined in ItemUpgradeManager.h
 *
 * 6. SEASON: Currently set to season 1
 *    Change ARTIFACT_QUEST_SEASON if using different season
 *
 * 7. DEPENDENCIES:
 *    - ItemUpgradeManager.h (for UpgradeManager class)
 *    - Player.h (for Player class)
 *    - Quest.h (for Quest class)
 *    - ScriptMgr.h (for PlayerScript base class)
 *
 * 8. LOGGING: Uses LOG_INFO, LOG_ERROR, LOG_WARN
 *    Output goes to console and log files
 *
 * 9. TESTING:
 *    - Complete quest 12340 as level 255 player
 *    - Check console for "Awarded 500 essence to player X"
 *    - Check player essence currency in ItemUpgrade menu
 *
 * 10. TROUBLESHOOTING:
 *     - If hook doesn't fire: Check quest ID matches (12340)
 *     - If essence not awarded: Check UpgradeManager is initialized
 *     - If crash occurs: Check null pointer checks in code
 *     - If wrong amount: Check STARTING_ESSENCE_AMOUNT constant
 *
 * 11. ALTERNATIVE IMPLEMENTATION:
 *     If this hook approach doesn't work, can use:
 *     - Quest reward script (custom_script_id in quest_template)
 *     - Command reward script
 *     - Console command `.essence add Playername 500`
 *
 * 12. REPEATABLE QUESTS:
 *     If quest is set as repeatable, essence will be awarded
 *     on each completion. Modify logic if only-once reward needed:
 *
 *     ```cpp
 *     // Check if player already completed quest
 *     if (player->HasQuestCompleted(ARTIFACT_QUEST_ID))
 *     {
 *         LOG_DEBUG("scripts.darkchaos", "Player %u already received essence", playerGuid);
 *         return;
 *     }
 *     ```
 */
// ============================================================================
