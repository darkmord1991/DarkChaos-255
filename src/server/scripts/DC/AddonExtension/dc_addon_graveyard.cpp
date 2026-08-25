/*
 * Dark Chaos - Return to Graveyard Addon Handler
 * ==============================================
 *
 * Server side of the retail-style "Return to Graveyard" button.
 *
 * When a player has died AND released their spirit (i.e. is a ghost), the
 * client may send GRVY|CMSG_RETURN. The core's normal spirit-release path
 * (CMSG_REPOP_REQUEST) refuses a second release once PLAYER_FLAGS_GHOST is
 * set, so a lost/stuck ghost has no built-in way back to a graveyard. This
 * handler closes that gap by calling Player::RepopAtGraveyard() directly,
 * which performs the same closest-graveyard lookup + teleport + spirit-healer
 * minimap blip the core uses on release. No cooldown, matching retail.
 *
 * Copyright (C) 2026 Dark Chaos Development Team
 */

#include "dc_addon_namespace.h"
#include "Config.h"
#include "Corpse.h"
#include "Log.h"
#include "Player.h"
#include "ScriptMgr.h"

namespace DCAddon
{
    // Corpse location push (SMSG_CORPSE): lets the DC-QOS navigation module
    // supertrack the corpse with a 3D world marker while the player is a
    // ghost (the stock client only shows the minimap blip). Sent on spirit
    // release, cleared on resurrect, and answerable on demand for the
    // login/reload-while-ghost case.
    static void SendCorpseLocation(Player* player)
    {
        if (!player)
            return;

        JsonMessage msg(Module::GRAVEYARD, Opcode::Graveyard::SMSG_CORPSE);

        Corpse* corpse = player->GetCorpse();
        if (corpse)
        {
            msg.Set("m", corpse->GetMapId());
            msg.Set("x", static_cast<double>(corpse->GetPositionX()));
            msg.Set("y", static_cast<double>(corpse->GetPositionY()));
            msg.Set("z", static_cast<double>(corpse->GetPositionZ()));
        }
        else
            msg.Set("clear", true);

        msg.Send(player);
    }

    static void HandleRequestCorpse(Player* player, ParsedMessage const& /*msg*/)
    {
        SendCorpseLocation(player);
    }

    // Teleport a released ghost to the nearest graveyard.
    static void HandleReturnToGraveyard(Player* player, ParsedMessage const& /*msg*/)
    {
        if (!player)
            return;

        // Only valid for a player who has died and released their spirit.
        if (player->IsAlive() || !player->HasPlayerFlag(PLAYER_FLAGS_GHOST))
        {
            SendError(player, Module::GRAVEYARD, "You must release your spirit first.");
            return;
        }

        // Reuse the core graveyard logic: closest BG / battlefield / world
        // graveyard, teleport, and the SMSG_DEATH_RELEASE_LOC minimap blip.
        player->RepopAtGraveyard();

        LOG_DEBUG("module.dc", "[Graveyard] {} returned to nearest graveyard via addon button", player->GetName());
    }

    // GRVY is intentionally not part of the central module table in
    // dc_addon_protocol.cpp, so it enables itself with the router here
    // (same self-contained pattern as DC-Welcome).
    void RegisterGraveyardHandlers()
    {
        bool const enabled = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Graveyard.Enable", true);

        MessageRouter::Instance().SetModuleEnabled(Module::GRAVEYARD, enabled);
        if (!enabled)
            return;

        DC_REGISTER_HANDLER(Module::GRAVEYARD, Opcode::Graveyard::CMSG_RETURN, HandleReturnToGraveyard);
        DC_REGISTER_HANDLER(Module::GRAVEYARD, Opcode::Graveyard::CMSG_REQUEST_CORPSE, HandleRequestCorpse);
    }
}

// Corpse-location push: released ghosts get the corpse position for the
// navigation marker; resurrection clears it.
class DCGraveyardPlayerScript : public PlayerScript
{
public:
    DCGraveyardPlayerScript() : PlayerScript("DCGraveyardPlayerScript", { PLAYERHOOK_ON_PLAYER_RELEASED_GHOST, PLAYERHOOK_ON_PLAYER_RESURRECT }) { }

    void OnPlayerReleasedGhost(Player* player) override
    {
        DCAddon::SendCorpseLocation(player);
    }

    void OnPlayerResurrect(Player* player, float /*restorePercent*/, bool& /*applySickness*/) override
    {
        // The corpse object may still exist at hook time, so send an explicit
        // clear instead of re-querying it.
        if (!player)
            return;

        DCAddon::JsonMessage msg(DCAddon::Module::GRAVEYARD, DCAddon::Opcode::Graveyard::SMSG_CORPSE);
        msg.Set("clear", true);
        msg.Send(player);
    }
};

// Register the handler(s) during script load.
void AddSC_dc_addon_graveyard()
{
    DCAddon::RegisterGraveyardHandlers();
    new DCGraveyardPlayerScript();
}
