#include "ScriptMgr.h"
#include "Chat.h"
#include "CommandScript.h"
#include "Player.h"
#include "GameTime.h"
#include "StringConvert.h"
#include "../Hotspot/HotspotMgr.h"
#include "../Hotspot/HotspotDefines.h"
#include "../Hotspot/HotspotGrid.h"

class HotspotsCommandScript : public CommandScript
{
public:
    HotspotsCommandScript() : CommandScript("HotspotsCommandScript") { }

    Acore::ChatCommands::ChatCommandTable GetCommands() const override
    {
        using namespace Acore::ChatCommands;
        static ChatCommandTable hotspotsCommandTable =
        {
            ChatCommandBuilder("list",      HandleHotspotsListCommand,      SEC_GAMEMASTER,    Acore::ChatCommands::Console::No),
            ChatCommandBuilder("spawn",     HandleHotspotsSpawnCommand,     SEC_ADMINISTRATOR, Acore::ChatCommands::Console::No),
            ChatCommandBuilder("spawnhere", HandleHotspotsSpawnHereCommand, SEC_ADMINISTRATOR, Acore::ChatCommands::Console::No),
            ChatCommandBuilder("dump",      HandleHotspotsDumpCommand,      SEC_ADMINISTRATOR, Acore::ChatCommands::Console::No),
            ChatCommandBuilder("clear",     HandleHotspotsClearCommand,     SEC_ADMINISTRATOR, Acore::ChatCommands::Console::No),
            ChatCommandBuilder("reload",    HandleHotspotsReloadCommand,    SEC_ADMINISTRATOR, Acore::ChatCommands::Console::No),
            ChatCommandBuilder("tp",        HandleHotspotsTeleportCommand,  SEC_GAMEMASTER,    Acore::ChatCommands::Console::No),
            ChatCommandBuilder("status",    HandleHotspotsStatusCommand,    SEC_PLAYER,        Acore::ChatCommands::Console::No)
        };

        static ChatCommandTable commandTable =
        {
            ChatCommandBuilder("hotspots", hotspotsCommandTable),
            ChatCommandBuilder("hotspot", hotspotsCommandTable)
        };

        return commandTable;
    }

    static bool HandleHotspotsListCommand(ChatHandler* handler, char const* /*args*/)
    {
        auto const& grid = sHotspotMgr->GetGrid();
        if (grid.Count() == 0)
        {
            handler->SendSysMessage("No active hotspots.");
            return true;
        }

        handler->PSendSysMessage("Active Hotspots: {}", grid.Count());
        std::vector<Hotspot> all = grid.GetAll();
        for (Hotspot const& hotspot : all)
        {
            time_t remaining = hotspot.expireTime - GameTime::GetGameTime().count();
            std::string zoneName = sHotspotMgr->GetZoneName(hotspot.zoneId);

            handler->PSendSysMessage(
                "  ID: {} | Map: {} | Zone: {} ({}) | Pos: ({:.1f}, {:.1f}, {:.1f}) | Time Left: {}m",
                hotspot.id, hotspot.mapId, zoneName, hotspot.zoneId,
                hotspot.x, hotspot.y, hotspot.z,
                remaining / 60
            );
        }

        return true;
    }

    static bool HandleHotspotsSpawnCommand(ChatHandler* handler, char const* /*args*/)
    {
        // Spawning draws from the pre-validated spawn-point pool. On a cold pool
        // (fresh DB before background discovery has run) prime it on demand so a
        // manual GM spawn still works; a brief stall here is acceptable.
        if (!sHotspotMgr->SpawnHotspot())
        {
            sHotspotMgr->RefillSpawnPool();
            if (!sHotspotMgr->SpawnHotspot())
            {
                handler->SendSysMessage("Failed to spawn a new hotspot (limit reached or no valid pos).");
                return true;
            }
        }

        handler->SendSysMessage("Spawned a new hotspot.");
        return true;
    }

    // Place a hotspot at the GM's exact position (bypasses pool/eligibility/cap).
    static bool HandleHotspotsSpawnHereCommand(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return false;

        if (!sHotspotMgr->SpawnHotspotAt(player->GetMapId(), player->GetZoneId(),
                player->GetPositionX(), player->GetPositionY(), player->GetPositionZ()))
        {
            handler->SendSysMessage("Failed to spawn a hotspot here (system disabled or map not hostable).");
            return true;
        }

        handler->SendSysMessage("Spawned a hotspot at your location.");
        return true;
    }

    static bool HandleHotspotsDumpCommand(ChatHandler* handler, char const* /*args*/)
    {
        handler->PSendSysMessage("Hotspots: Enabled={}, Count={}", sHotspotsConfig.enabled, sHotspotMgr->GetGrid().Count());
        return true;
    }

    static bool HandleHotspotsClearCommand(ChatHandler* handler, char const* /*args*/)
    {
        handler->SendSysMessage("Clearing all hotspots...");
        sHotspotMgr->ClearAll();

        // CleanupExpiredHotspots also refills toward minActive when configured.
        if (sHotspotsConfig.minActive > 0)
        {
            handler->SendSysMessage("Respawning minimum active hotspots...");
            sHotspotMgr->CleanupExpiredHotspots();
        }

        handler->SendSysMessage("Done.");
        return true;
    }

    static bool HandleHotspotsReloadCommand(ChatHandler* handler, char const* /*args*/)
    {
        sHotspotMgr->LoadConfig();
        // Re-read the pool too: a config change to EnabledMaps/EnabledZones
        // changes which cached points are usable and how they band-resolve.
        sHotspotMgr->LoadSpawnPointsFromDB();
        handler->SendSysMessage("Reloaded config and spawn-point pool.");
        return true;
    }

    // ".hotspot tp [id]" - teleport to a specific hotspot, or the first active one.
    static bool HandleHotspotsTeleportCommand(ChatHandler* handler, char const* args)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return false;

        std::vector<Hotspot> all = sHotspotMgr->GetGrid().GetAll();
        if (all.empty())
        {
            handler->SendSysMessage("No active hotspots.");
            return true;
        }

        Hotspot const* target = nullptr;

        if (args)
            while (*args == ' ' || *args == '\t')
                ++args;

        if (args && *args)
        {
            if (Optional<uint32> id = Acore::StringTo<uint32>(args))
            {
                for (Hotspot const& h : all)
                    if (h.id == *id)
                    {
                        target = &h;
                        break;
                    }

                if (!target)
                {
                    handler->PSendSysMessage("No active hotspot with id {}.", *id);
                    return true;
                }
            }
            else
            {
                handler->SendSysMessage("Usage: .hotspot tp [id]");
                return true;
            }
        }

        if (!target)
            target = &all.front();

        player->TeleportTo(target->mapId, target->x, target->y, target->z, player->GetOrientation());
        handler->PSendSysMessage("Teleporting to hotspot #{}.", target->id);
        return true;
    }

    // ".hotspot status" - player-facing summary of the current hotspot state.
    static bool HandleHotspotsStatusCommand(ChatHandler* handler, char const* /*args*/)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return false;

        handler->PSendSysMessage("Hotspots: {} | Active: {}",
            sHotspotsConfig.enabled ? "enabled" : "disabled",
            sHotspotMgr->GetGrid().Count());

        if (Hotspot const* here = sHotspotMgr->GetPlayerHotspot(player))
        {
            time_t remaining = here->expireTime - GameTime::GetGameTime().count();
            handler->PSendSysMessage("You are inside hotspot #{} ({}) - {}m left, +{}% XP.",
                here->id, sHotspotMgr->GetZoneName(here->zoneId),
                remaining / 60, sHotspotsConfig.experienceBonus);
        }
        else
        {
            handler->SendSysMessage("You are not currently inside a hotspot.");
        }

        bool buffed = (sHotspotsConfig.auraSpell && player->HasAura(sHotspotsConfig.auraSpell)) ||
                      (sHotspotsConfig.buffSpell && player->HasAura(sHotspotsConfig.buffSpell));
        handler->PSendSysMessage("XP buff: {}", buffed ? "active" : "inactive");
        return true;
    }
};

void AddSC_dc_hotspot_commandscript()
{
    new HotspotsCommandScript();
}
