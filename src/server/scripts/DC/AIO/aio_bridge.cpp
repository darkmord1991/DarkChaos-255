/*
 * DC/AIO: Safe stub bridge for Rochet2/AIO client solutions
 *
 * What this file does:
 * - Provides a minimal CommandScript and PlayerScript to demonstrate sending
 *   messages to a WoW client addon via Rochet2/AIO.
 * - Compiles even when AIO is not installed; features are disabled with a
 *   helpful message. When AIO is installed, define HAS_AIO and add include
 *   paths to enable real messaging.
 *
 * Integration overview:
 * - Server: install Rochet2/AIO server library and define HAS_AIO in build flags;
 *   add include path so "AIO.h" resolves. Replace the stub send call with the
 *   actual AIO API you use (see AIO docs).
 * - Client: install the Rochet2 AIO addon and the provided DC_HLBG_HUD addon
 *   (Custom/Client/AddOns/DC_HLBG_HUD). The addon listens for HUD updates.
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Chat.h"
#include "CommandScript.h"

// If Rochet2/AIO is installed server-side, define HAS_AIO in your CMake/toolchain
// and ensure the include directory is set so the header below resolves.
#ifdef HAS_AIO
#  include "AIO.h" // Adjust include path according to your AIO installation
#endif

namespace DC_AIO
{
    // Server-side send helper: returns true if a message was sent via AIO
    static bool SendHudMessage(Player* player, std::string const& opcode, std::string const& payload)
    {
#ifdef HAS_AIO
        // TODO: Replace this with the real AIO server-side API. The following
        // is pseudocode to show the intent.
        // Example (adjust to match AIO version):
        // AIO::Server::Send(player, "DC_HLBG_HUD", opcode, payload);
        (void)player; (void)opcode; (void)payload;
        return false; // Replace with "true" when the real call succeeds
#else
        (void)player; (void)opcode; (void)payload;
        return false;
#endif
    }
}

// Optional: greet players with a client handshake on login (if AIO present)
class DC_AIO_PlayerScript : public PlayerScript
{
public:
    DC_AIO_PlayerScript() : PlayerScript("DC_AIO_PlayerScript") { }

    void OnPlayerLogin(Player* player) override
    {
        if (!player)
            return;
        // Try to notify the client addon (no-op if AIO is not installed)
        DC_AIO::SendHudMessage(player, "HELLO", "Welcome");
    }
};

// Small command: .aio ping -> try to send a message to the client addon
class DC_AIO_CommandScript : public CommandScript
{
public:
    DC_AIO_CommandScript() : CommandScript("DC_AIO_CommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable sub =
        {
            { "ping", [this](ChatHandler* handler, char const* /*args*/)
                {
                    if (!handler || !handler->GetSession())
                        return false;
                    Player* player = handler->GetSession()->GetPlayer();
                    if (!player)
                        return false;
                    bool sent = DC_AIO::SendHudMessage(player, "PING", "Test");
#ifdef HAS_AIO
                    if (sent)
                        handler->PSendSysMessage("AIO: ping sent to addon.");
                    else
                        handler->PSendSysMessage("AIO: ping attempted, check server AIO API wiring.");
#else
                    handler->PSendSysMessage("AIO not enabled server-side. Install Rochet2/AIO and define HAS_AIO.");
#endif
                    return true;
                }, SEC_PLAYER, Console::No }
        };

        static ChatCommandTable cmds =
        {
            { "aio", sub }
        };
        return cmds;
    }
};

void AddSC_aio_bridge()
{
    new DC_AIO_PlayerScript();
    new DC_AIO_CommandScript();
}
