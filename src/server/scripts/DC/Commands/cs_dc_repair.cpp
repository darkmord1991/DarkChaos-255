/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * .rep command - free self-service repair of all equipped and bagged gear,
 * removal of resurrection sickness, and a reset of short spell cooldowns
 * (players: under 10 minutes, open world only; GMs: everything).
 */

#include "Chat.h"
#include "CommandScript.h"
#include "Map.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WorldSession.h"

using namespace Acore::ChatCommands;

// Spell cast on the player when resurrected by a spirit healer (the death
// penalty): reduces all stats and durability while active.
constexpr uint32 SPELL_RESURRECTION_SICKNESS = 15007;

class dc_repair_commandscript : public CommandScript
{
public:
    dc_repair_commandscript() : CommandScript("dc_repair_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandTable =
        {
            { "rep", HandleRepairCommand, SEC_PLAYER, Console::No }
        };

        return commandTable;
    }

    static bool HandleRepairCommand(ChatHandler* handler)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player)
        {
            return false;
        }

        // Block in combat so the cooldown reset can't be abused mid-fight.
        if (player->IsInCombat())
        {
            handler->SendSysMessage("|cffff0000You cannot use .rep while in combat.|r");
            handler->SetSentErrorMessage(true);
            return false;
        }

        // false = no cost (free), 0 = no discount, false = not guild bank.
        player->DurabilityRepairAll(false, 0, false);

        // Remove the spirit-healer death penalty if the player has it.
        player->RemoveAurasDueToSpell(SPELL_RESURRECTION_SICKNESS);

        // Cooldowns: staff get a full reset. Players get the stock arena rule (only spells under
        // 10 minutes, so no profession/item/long cooldowns) and nothing inside battlegrounds,
        // arenas, dungeons or raids, where it would be a reset between pulls or rounds.
        if (handler->GetSession()->GetSecurity() >= SEC_GAMEMASTER)
        {
            player->RemoveAllSpellCooldown();
            handler->SendSysMessage("|cff00ff00Gear repaired, resurrection sickness removed, and cooldowns reset.|r");
            return true;
        }

        Map* map = player->GetMap();
        if (player->InBattleground() || (map && map->IsDungeon()))
        {
            handler->SendSysMessage("|cff00ff00Gear repaired and resurrection sickness removed.|r "
                "Cooldowns are not reset inside instances, battlegrounds or arenas.");
            return true;
        }

        player->RemoveArenaSpellCooldowns(true);
        handler->SendSysMessage("|cff00ff00Gear repaired, resurrection sickness removed, "
            "and cooldowns under 10 minutes reset.|r");

        return true;
    }
};

void AddSC_dc_repair_commandscript()
{
    new dc_repair_commandscript();
}
