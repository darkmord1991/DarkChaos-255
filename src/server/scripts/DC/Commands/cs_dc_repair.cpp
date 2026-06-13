/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * .rep command - free self-service repair of all equipped and bagged gear,
 * removal of resurrection sickness, and reset of all spell cooldowns.
 */

#include "Chat.h"
#include "CommandScript.h"
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

        // false = no cost (free), 0 = no discount, false = not guild bank.
        player->DurabilityRepairAll(false, 0, false);

        // Remove the spirit-healer death penalty if the player has it.
        player->RemoveAurasDueToSpell(SPELL_RESURRECTION_SICKNESS);

        // Reset all spell cooldowns.
        player->RemoveAllSpellCooldown();

        handler->SendSysMessage("|cff00ff00Gear repaired, resurrection sickness removed, and cooldowns reset.|r");

        return true;
    }
};

void AddSC_dc_repair_commandscript()
{
    new dc_repair_commandscript();
}
