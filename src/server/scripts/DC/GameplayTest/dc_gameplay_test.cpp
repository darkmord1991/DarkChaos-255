/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Gameplay test harness entry points:
 *   .dca test run <scenario.json>     start a run (one at a time)
 *   .dca test validate <scenario.json> parse and validate only, touches nothing
 *   .dca test status [run_id]         active run, or a finished run's result lines
 *   .dca test abort                   stop the active run (cleanup still runs)
 *   .dca test list                    scenario files in DC.GameplayTest.ScenarioDir
 *
 * Administrator commands, console and SOAP allowed. In game they are accepted
 * only from the lab account itself (DC.GameplayTest.Account). Output lines start
 * with GAMEPLAYTEST so apps/gameplay-test/run.py can parse them over SOAP.
 *
 * Registered from AddSC_dc_gameplay_test(); see GameplayTestRunner.h for the
 * design and threading rules.
 */

#include "AccountMgr.h"
#include "Chat.h"
#include "CommandScript.h"
#include "GameplayTestRunner.h"
#include "Opcodes.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WorldPacket.h"
#include "WorldSession.h"

using namespace Acore::ChatCommands;

namespace
{
    using DC::GameplayTest::Config;
    using DC::GameplayTest::Runner;

    bool Refuse(ChatHandler* handler, std::string const& message)
    {
        // SendSysMessage, not SendErrorMessage: the formatting overload prints nothing on the console.
        handler->SendSysMessage("GAMEPLAYTEST error=" + message);
        handler->SetSentErrorMessage(true);
        return false;
    }

    // Console and SOAP have no session and are already administrator-only. In game the
    // harness answers only the lab account, whose characters are the ones it drives.
    bool CheckAccess(ChatHandler* handler, Config const& config)
    {
        if (!config.enabled)
            return Refuse(handler, "the gameplay test harness is off (DC.GameplayTest.Enable = 0)");

        WorldSession* session = handler->GetSession();
        if (!session)
            return true;

        // Synchronous login-database read; world thread, only on a typed command.
        if (config.account.empty() || AccountMgr::GetId(config.account) != session->GetAccountId())
            return Refuse(handler, "in game, .dca test is only accepted from the lab account "
                "(DC.GameplayTest.Account)");
        return true;
    }
}

class dc_gameplay_test_commandscript : public CommandScript
{
public:
    dc_gameplay_test_commandscript() : CommandScript("dc_gameplay_test_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable testTable =
        {
            { "run",      HandleRun,      SEC_ADMINISTRATOR, Console::Yes },
            { "validate", HandleValidate, SEC_ADMINISTRATOR, Console::Yes },
            { "status",   HandleStatus,   SEC_ADMINISTRATOR, Console::Yes },
            { "abort",    HandleAbort,    SEC_ADMINISTRATOR, Console::Yes },
            { "list",     HandleList,     SEC_ADMINISTRATOR, Console::Yes }
        };
        static ChatCommandTable dcaTable =
        {
            { "test", testTable }
        };
        static ChatCommandTable commandTable =
        {
            { "dca", dcaTable }
        };
        return commandTable;
    }

    static bool HandleRun(ChatHandler* handler, std::string_view file)
    {
        Config const config = Config::Load();
        if (!CheckAccess(handler, config))
            return false;

        ObjectGuid issuer;
        if (WorldSession* session = handler->GetSession())
            if (Player* player = session->GetPlayer())
                issuer = player->GetGUID();

        std::string runId;
        std::string error;
        if (!Runner::Instance().Start(config, std::string(file), issuer, runId, error))
            return Refuse(handler, error);

        handler->SendSysMessage("GAMEPLAYTEST run_id=" + runId + " state=started");
        return true;
    }

    static bool HandleValidate(ChatHandler* handler, std::string_view file)
    {
        Config const config = Config::Load();
        if (!CheckAccess(handler, config))
            return false;

        std::string name;
        std::string error;
        uint32 steps = 0;
        if (!Runner::Instance().Validate(config, std::string(file), name, steps, error))
            return Refuse(handler, error);

        handler->SendSysMessage(Acore::StringFormat("GAMEPLAYTEST valid=1 steps={} name=\"{}\"", steps, name));
        return true;
    }

    static bool HandleStatus(ChatHandler* handler, Optional<std::string_view> runId)
    {
        Config const config = Config::Load();
        if (!CheckAccess(handler, config))
            return false;

        for (std::string const& line : Runner::Instance().Status(runId ? std::string(*runId) : std::string()))
            handler->SendSysMessage(line);
        return true;
    }

    static bool HandleAbort(ChatHandler* handler)
    {
        Config const config = Config::Load();
        if (!CheckAccess(handler, config))
            return false;

        if (!Runner::Instance().Abort(handler->GetSession() ? "aborted in game" : "aborted from the console"))
            return Refuse(handler, "no run is active (or it is already cleaning up)");

        handler->SendSysMessage("GAMEPLAYTEST state=aborting");
        return true;
    }

    static bool HandleList(ChatHandler* handler)
    {
        Config const config = Config::Load();
        if (!CheckAccess(handler, config))
            return false;

        std::string error;
        std::vector<std::string> const names = Runner::Instance().ListScenarios(config, error);
        if (!error.empty())
            return Refuse(handler, error);

        handler->SendSysMessage(Acore::StringFormat("GAMEPLAYTEST scenarios={} dir={}", names.size(),
            config.scenarioDir));
        for (std::string const& name : names)
            handler->SendSysMessage("  " + name);
        return true;
    }
};

class dc_gameplay_test_worldscript : public WorldScript
{
public:
    dc_gameplay_test_worldscript()
        : WorldScript("dc_gameplay_test_worldscript", { WORLDHOOK_ON_UPDATE, WORLDHOOK_ON_SHUTDOWN }) { }

    void OnUpdate(uint32 /*diff*/) override
    {
        Runner::Instance().Update();
    }

    // Runs before the sessions are kicked and the maps unloaded.
    void OnShutdown() override
    {
        Runner::Instance().Shutdown();
    }
};

// A client logging into a character the harness holds headless would load a second
// Player for the same guid: the core's takeover path only knows sessions registered
// with the session manager, and test sessions are not. Refuse it instead.
class dc_gameplay_test_serverscript : public ServerScript
{
public:
    dc_gameplay_test_serverscript()
        : ServerScript("dc_gameplay_test_serverscript", { SERVERHOOK_CAN_PACKET_RECEIVE }) { }

    bool CanPacketReceive(WorldSession* session, WorldPacket const& packet) override
    {
        // Called for every packet on every thread; only the opcode test is done before
        // knowing it is CMSG_PLAYER_LOGIN, which is PROCESS_THREADUNSAFE (world thread).
        if (packet.GetOpcode() != CMSG_PLAYER_LOGIN || !session || session->IsHeadless())
            return true;

        Runner const& runner = Runner::Instance();
        if (!runner.IsActive() || packet.size() < sizeof(uint64))
            return true;

        ObjectGuid const guid(packet.read<uint64>(0));
        if (!runner.HoldsHeadless(guid))
            return true;

        session->SendCharLoginFailed(LoginFailureReason::DuplicateCharacter);
        return false;
    }
};

void AddSC_dc_gameplay_test()
{
    new dc_gameplay_test_commandscript();
    new dc_gameplay_test_worldscript();
    new dc_gameplay_test_serverscript();
}
