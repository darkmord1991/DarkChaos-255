/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Gameplay test harness: run lifecycle, test characters, cleanup and reports.
 * Steps and metrics live in GameplayTestSteps.cpp. Threading rules: see the
 * header - world thread only.
 */

#include "GameplayTestRunner.h"
#include "AccountMgr.h"
#include "CharacterCache.h"
#include "Chat.h"
#include "Config.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "GameObject.h"
#include "GitRevision.h"
#include "Log.h"
#include "Map.h"
#include "MapMgr.h"
#include "MotionMaster.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Opcodes.h"
#include "Player.h"
#include "QuestDef.h"
#include "StringFormat.h"
#include "Timer.h"
#include "World.h"
#include "WorldPacket.h"
#include "WorldSession.h"
#include "DC/Progression/FirstStart/dc_firststart_learnspells.h"
#include "DC/Progression/Prestige/dc_prestige_api.h"
#include <algorithm>
#include <cctype>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <system_error>

namespace DC::GameplayTest
{
    namespace
    {
        // GM Island: a lab spot nobody plays in, on a continent that is always loaded.
        constexpr Location DEFAULT_LOCATION = { 1, 16222.1f, 16252.1f, 12.5872f, 0.0f };
        constexpr uint32 DEFAULT_TIMEOUT_MS = 120000;
        constexpr uint32 DEFAULT_SETUP_TIMEOUT_MS = 45000;
        constexpr uint32 FLUSH_TIMEOUT_MS = 20000;
        constexpr uint32 FLUSH_PROBE_INTERVAL_MS = 500;
        constexpr uint32 CLEANUP_SETTLE_MS = 10000;
        constexpr std::size_t MAX_SCENARIO_BYTES = 1024 * 1024;

        std::string ToLower(std::string text)
        {
            std::transform(text.begin(), text.end(), text.begin(),
                [](unsigned char c) { return char(std::tolower(c)); });
            return text;
        }

        // Scenario names are relative paths inside the scenario directory. Only a
        // conservative character set gets through, so ".." or an absolute path can
        // never reach the filesystem.
        bool IsSafeScenarioName(std::string const& file)
        {
            if (file.size() < 6 || file.size() > 160)
                return false;
            if (file.front() == '/' || file.front() == '.')
                return false;
            if (file.find("..") != std::string::npos || file.find("//") != std::string::npos)
                return false;
            if (file.compare(file.size() - 5, 5, ".json") != 0)
                return false;

            return std::all_of(file.begin(), file.end(), [](unsigned char c)
            {
                return std::isalnum(c) || c == '-' || c == '_' || c == '.' || c == '/';
            });
        }

        std::string StemOf(std::string const& file)
        {
            std::string stem = std::filesystem::path(file).stem().string();
            for (char& c : stem)
                if (!std::isalnum(static_cast<unsigned char>(c)) && c != '-' && c != '_')
                    c = '_';
            if (stem.size() > 48)
                stem.resize(48);
            return stem.empty() ? std::string("scenario") : stem;
        }

        std::string LocalTimestamp(std::time_t when, bool compact)
        {
            std::tm const tm = Acore::Time::TimeBreakdown(when);
            if (compact)
                return Acore::StringFormat("{:04}{:02}{:02}-{:02}{:02}{:02}", tm.tm_year + 1900, tm.tm_mon + 1,
                    tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec);
            return Acore::StringFormat("{:04}-{:02}-{:02} {:02}:{:02}:{:02}", tm.tm_year + 1900, tm.tm_mon + 1,
                tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec);
        }

        char const* StateName(RunState state)
        {
            switch (state)
            {
                case RunState::Preparing: return "preparing";
                case RunState::Running: return "running";
                case RunState::CleaningUp: return "cleanup";
                case RunState::Finished: return "finished";
            }
            return "unknown";
        }

        char const* StageName(ActorStage stage)
        {
            switch (stage)
            {
                case ActorStage::Resolve: return "resolve";
                case ActorStage::AwaitFlush: return "await-save";
                case ActorStage::LoggingIn: return "logging-in";
                case ActorStage::Normalize: return "normalize";
                case ActorStage::Arriving: return "teleporting";
                case ActorStage::Ready: return "ready";
                case ActorStage::Failed: return "failed";
            }
            return "unknown";
        }

        Location ReadLocation(JsonValue const& value, Location fallback)
        {
            if (!value.IsObject())
                return fallback;

            Location location;
            location.mapId = value.GetUInt("map", fallback.mapId);
            location.x = float(value.GetNumber("x", fallback.x));
            location.y = float(value.GetNumber("y", fallback.y));
            location.z = float(value.GetNumber("z", fallback.z));
            location.o = float(value.GetNumber("o", 0.0));
            return location;
        }
    }

    void RemoveQuestFromPlayer(Player* player, uint32 questId)
    {
        Quest const* quest = sObjectMgr->GetQuestTemplate(questId);
        if (!quest)
            return;

        for (uint8 slot = 0; slot < MAX_QUEST_LOG_SIZE; ++slot)
        {
            if (player->GetQuestSlotQuestId(slot) != questId)
                continue;

            player->SetQuestSlot(slot, 0);
            player->TakeQuestSourceItem(questId, false);
            if (quest->HasFlag(QUEST_FLAGS_FLAGS_PVP))
            {
                player->pvpInfo.IsHostile = player->pvpInfo.IsInHostileArea || player->HasPvPForcingQuest();
                player->UpdatePvPState();
            }
        }

        player->RemoveRewardedQuest(questId);
        player->RemoveActiveQuest(questId, false);
    }

    namespace
    {
        void ApplyLevel(Player* player, uint8 level)
        {
            if (player->GetLevel() == level)
                return;
            player->GiveLevel(level);
            player->InitTalentForLevel();
            player->SetUInt32Value(PLAYER_XP, 0);
        }
    }

    // ------------------------------------------------------------------
    // Config and values
    // ------------------------------------------------------------------

    Config Config::Load()
    {
        Config config;
        config.enabled = sConfigMgr->GetOption<bool>("DC.GameplayTest.Enable", false, false);
        config.account = sConfigMgr->GetOption<std::string>("DC.GameplayTest.Account", "", false);
        config.scenarioDir = sConfigMgr->GetOption<std::string>("DC.GameplayTest.ScenarioDir",
            "gameplay-tests/scenarios", false);
        config.outputDir = sConfigMgr->GetOption<std::string>("DC.GameplayTest.OutputDir",
            "gameplay-tests/reports", false);
        config.phaseMask = sConfigMgr->GetOption<uint32>("DC.GameplayTest.PhaseMask", 0x80000000u, false);
        config.maxRunMs = std::clamp<uint32>(sConfigMgr->GetOption<uint32>("DC.GameplayTest.MaxRunMs", 600000, false),
            10000, 3600000);
        config.maxActors = std::clamp<uint32>(sConfigMgr->GetOption<uint32>("DC.GameplayTest.MaxActors", 5, false), 1,
            10);
        config.maxSpawns = std::clamp<uint32>(sConfigMgr->GetOption<uint32>("DC.GameplayTest.MaxSpawns", 50, false), 0,
            200);
        config.allowCreateCharacters = sConfigMgr->GetOption<bool>("DC.GameplayTest.AllowCreateCharacters", true,
            false);
        config.allowDestructive = sConfigMgr->GetOption<bool>("DC.GameplayTest.AllowDestructive", false, false);
        return config;
    }

    Value Value::Number(double v)
    {
        Value value;
        value.kind = Kind::Number;
        value.number = v;
        return value;
    }

    Value Value::Text(std::string v)
    {
        Value value;
        value.kind = Kind::Text;
        value.text = std::move(v);
        return value;
    }

    JsonValue Value::ToJson() const
    {
        switch (kind)
        {
            case Kind::Number: return JsonValue(number);
            case Kind::Text: return JsonValue(text);
            default: return JsonValue();
        }
    }

    std::string Value::ToString() const
    {
        switch (kind)
        {
            case Kind::Number: return JsonValue(number).Dump(false);
            case Kind::Text: return JsonValue(text).Dump(false);
            default: return "none";
        }
    }

    uint64 Run::NowMs() const
    {
        return uint64(std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now() - started).count());
    }

    // ------------------------------------------------------------------
    // Entry points
    // ------------------------------------------------------------------

    Runner& Runner::Instance()
    {
        static Runner instance;
        return instance;
    }

    bool Runner::LoadScenario(Config const& config, std::string const& file, JsonValue& out, std::string& path,
        std::string& error) const
    {
        if (config.scenarioDir.empty())
        {
            error = "DC.GameplayTest.ScenarioDir is empty";
            return false;
        }

        if (!IsSafeScenarioName(file))
        {
            error = "scenario names are relative .json paths inside DC.GameplayTest.ScenarioDir "
                "(letters, digits, - _ . / only, no ..)";
            return false;
        }

        std::filesystem::path const full = std::filesystem::path(config.scenarioDir) / file;
        path = full.generic_string();

        std::error_code ec;
        if (!std::filesystem::is_regular_file(full, ec))
        {
            error = "scenario not found: " + path;
            return false;
        }

        if (std::filesystem::file_size(full, ec) > MAX_SCENARIO_BYTES)
        {
            error = "scenario is larger than 1 MB: " + path;
            return false;
        }

        std::ifstream in(full, std::ios::binary);
        if (!in)
        {
            error = "cannot read " + path;
            return false;
        }

        std::string const text((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
        std::string parseError;
        if (!ParseJson(text, out, parseError))
        {
            error = file + ": " + parseError;
            return false;
        }

        std::string validationError;
        if (!ValidateScenario(out, config, validationError))
        {
            error = file + ": " + validationError;
            return false;
        }

        return true;
    }

    bool Runner::Validate(Config const& config, std::string const& file, std::string& outName, uint32& outSteps,
        std::string& error) const
    {
        JsonValue scenario;
        std::string path;
        if (!LoadScenario(config, file, scenario, path, error))
            return false;

        outName = scenario.GetString("name");
        JsonValue const* steps = scenario.Find("steps");
        outSteps = steps ? uint32(steps->Items().size()) : 0;
        return true;
    }

    bool Runner::Start(Config const& config, std::string const& file, ObjectGuid issuer, std::string& outRunId,
        std::string& error)
    {
        if (!config.enabled)
        {
            error = "the gameplay test harness is off (DC.GameplayTest.Enable = 0)";
            return false;
        }

        if (_run)
        {
            error = "run " + _run->runId + " is still active; wait for it or use .dca test abort";
            return false;
        }

        if (config.account.empty())
        {
            error = "DC.GameplayTest.Account is empty: name the lab account whose characters the harness may use";
            return false;
        }

        // A private phase: no normal-phase bit (real players live there) and never "every phase".
        if (!config.phaseMask || (config.phaseMask & PHASEMASK_NORMAL) || config.phaseMask == PHASEMASK_ANYWHERE)
        {
            error = "DC.GameplayTest.PhaseMask must be a non-zero mask without bit 1 (the normal phase)";
            return false;
        }

        std::string const prefix = ToLower(sConfigMgr->GetOption<std::string>("Playerbots.RandomBotAccountPrefix",
            "rndbot", false));
        if (!prefix.empty() && ToLower(config.account).rfind(prefix, 0) == 0)
        {
            error = "DC.GameplayTest.Account looks like a random-bot account (" + prefix + "*); the bot rotation "
                "would log test characters out mid-run. Use a dedicated lab account";
            return false;
        }

        auto run = std::make_unique<Run>();
        if (!LoadScenario(config, file, run->scenario, run->path, error))
            return false;

        // Synchronous login-database read; world thread, once per run.
        uint32 const accountId = AccountMgr::GetId(config.account);
        if (!accountId)
        {
            error = "lab account '" + config.account + "' does not exist";
            return false;
        }

        run->destructive = run->scenario.GetBool("destructive", false);
        if (run->destructive && !config.allowDestructive)
        {
            error = "the scenario is marked destructive (it changes persistent progression); set "
                "DC.GameplayTest.AllowDestructive = 1 on the lab server to allow it";
            return false;
        }

        run->config = config;
        run->file = file;
        run->name = run->scenario.GetString("name");
        run->issuer = issuer;
        run->accountId = accountId;
        run->accountName = config.account;
        std::transform(run->accountName.begin(), run->accountName.end(), run->accountName.begin(),
            [](unsigned char c) { return char(std::toupper(c)); });
        run->started = std::chrono::steady_clock::now();
        run->startedWall = std::time(nullptr);
        run->timeoutMs = std::min(run->scenario.GetUInt("timeout_ms", DEFAULT_TIMEOUT_MS), config.maxRunMs);
        run->setupTimeoutMs = std::min(run->scenario.GetUInt("setup_timeout_ms", DEFAULT_SETUP_TIMEOUT_MS),
            run->timeoutMs);
        run->stopOnFailure = run->scenario.GetBool("stop_on_failure", true);
        run->location = DEFAULT_LOCATION;
        if (JsonValue const* location = run->scenario.Find("location"))
            run->location = ReadLocation(*location, DEFAULT_LOCATION);

        if (JsonValue const* cleanup = run->scenario.Find("cleanup"))
        {
            run->cleanup.removeItems = cleanup->GetBool("remove_items", true);
            run->cleanup.removeAuras = cleanup->GetBool("remove_auras", true);
            run->cleanup.removeQuests = cleanup->GetBool("remove_quests", true);
            run->cleanup.restoreSpells = cleanup->GetBool("restore_spells", true);
            run->cleanup.restoreLevel = cleanup->GetBool("restore_level", false);
            run->cleanup.restoreMoney = cleanup->GetBool("restore_money", true);
            run->cleanup.restorePrestige = cleanup->GetBool("restore_prestige", true);
            run->cleanup.restorePosition = cleanup->GetBool("restore_position", true);
        }

        for (JsonValue const& def : run->scenario.Find("actors")->Items())
        {
            ActorState actor;
            actor.id = def.GetString("id");
            actor.name = def.GetString("name");
            actor.def = def;
            std::string const session = def.GetString("session", "auto");
            actor.mode = session == "headless" ? SessionMode::Headless :
                session == "online" ? SessionMode::Online : SessionMode::Auto;
            run->actors.push_back(std::move(actor));
        }

        std::vector<JsonValue> const& steps = run->scenario.Find("steps")->Items();
        run->steps.reserve(steps.size());
        for (std::size_t i = 0; i < steps.size(); ++i)
        {
            StepRecord record;
            record.index = uint32(i);
            record.action = steps[i].GetString("action");
            record.label = steps[i].GetString("label");
            run->steps.push_back(std::move(record));
        }

        ++_runCounter;
        run->runId = Acore::StringFormat("{}-{}-{}", LocalTimestamp(run->startedWall, true), _runCounter,
            StemOf(file));
        outRunId = run->runId;

        LOG_INFO(LOG_CATEGORY, "GameplayTest: run {} started: '{}' ({}), {} actor(s), {} step(s), phase mask {:#x}",
            run->runId, run->name, run->path, run->actors.size(), run->steps.size(), config.phaseMask);

        _run = std::move(run);
        return true;
    }

    bool Runner::HoldsHeadless(ObjectGuid guid) const
    {
        if (!_run || !guid)
            return false;

        for (ActorState const& actor : _run->actors)
            if (actor.guid == guid && (actor.session || actor.stage == ActorStage::AwaitFlush))
                return true;
        return false;
    }

    bool Runner::Abort(std::string const& reason)
    {
        if (!_run || _run->state == RunState::CleaningUp || _run->state == RunState::Finished)
            return false;

        _run->abortRequested = true;
        _run->abortReason = reason;
        return true;
    }

    std::vector<std::string> Runner::ListScenarios(Config const& config, std::string& error) const
    {
        std::vector<std::string> names;
        std::error_code ec;
        std::filesystem::path const root(config.scenarioDir);
        if (config.scenarioDir.empty() || !std::filesystem::is_directory(root, ec))
        {
            error = "scenario directory not found: " + config.scenarioDir;
            return names;
        }

        for (auto it = std::filesystem::recursive_directory_iterator(root, ec);
            !ec && it != std::filesystem::recursive_directory_iterator(); it.increment(ec))
        {
            if (!it->is_regular_file(ec) || it->path().extension() != ".json")
                continue;

            std::string const relative = std::filesystem::relative(it->path(), root, ec).generic_string();
            if (!ec && IsSafeScenarioName(relative))
                names.push_back(relative);
            if (names.size() >= 200)
                break;
        }

        std::sort(names.begin(), names.end());
        return names;
    }

    std::string Runner::StepLine(StepRecord const& record)
    {
        std::string line = Acore::StringFormat("  [{}] {}", record.index, record.action);
        if (!record.label.empty())
            line += " \"" + record.label + "\"";
        line += ": " + record.result;
        if (record.result != "pending" && record.result != "skipped")
            line += Acore::StringFormat(" ({} ms)", record.durationMs);
        if (!record.message.empty())
            line += " - " + record.message;
        return line;
    }

    std::vector<std::string> Runner::Status(std::string const& runId) const
    {
        std::vector<std::string> lines;
        if (_run && (runId.empty() || runId == _run->runId))
        {
            Run const& run = *_run;
            lines.push_back(Acore::StringFormat("GAMEPLAYTEST run_id={} state={} step={}/{} elapsed_ms={} name=\"{}\"",
                run.runId, StateName(run.state), std::min(run.current + 1, run.steps.size()), run.steps.size(),
                run.NowMs(), run.name));
            if (run.state == RunState::Preparing)
                for (ActorState const& actor : run.actors)
                    lines.push_back(Acore::StringFormat("  actor {} ({}): {}", actor.id, actor.name,
                        StageName(actor.stage)));
            return lines;
        }

        RunSummary const* summary = nullptr;
        if (runId.empty() && !_history.empty())
            summary = &_history.back();
        else
            for (RunSummary const& entry : _history)
                if (entry.runId == runId)
                    summary = &entry;

        if (!summary)
        {
            lines.push_back(Acore::StringFormat("GAMEPLAYTEST run_id={} state=unknown",
                runId.empty() ? std::string("none") : runId));
            return lines;
        }

        lines.push_back(Acore::StringFormat("GAMEPLAYTEST run_id={} state=finished result={} passed={} failed={} "
            "errors={} skipped={} duration_ms={} report={}", summary->runId, summary->result, summary->passed,
            summary->failed, summary->errors, summary->skipped, summary->durationMs,
            summary->reportPath.empty() ? std::string("none") : summary->reportPath));
        if (!summary->error.empty())
            lines.push_back("  error: " + summary->error);
        lines.insert(lines.end(), summary->stepLines.begin(), summary->stepLines.end());
        return lines;
    }

    // ------------------------------------------------------------------
    // World update
    // ------------------------------------------------------------------

    void Runner::Update()
    {
        if (!_run)
            return;

        Run& run = *_run;
        run.queries.ProcessReadyCallbacks();
        for (ActorState& actor : run.actors)
            PumpHeadless(actor);

        if ((run.state == RunState::Preparing || run.state == RunState::Running) && run.abortRequested)
        {
            run.result = "aborted";
            run.error = "aborted: " + run.abortReason;
            LOG_INFO(LOG_CATEGORY, "GameplayTest: run {} aborted ({})", run.runId, run.abortReason);
            run.state = RunState::CleaningUp;
        }

        if (run.state == RunState::Preparing && run.NowMs() > run.setupTimeoutMs)
        {
            std::string stages;
            for (ActorState const& actor : run.actors)
                stages += Acore::StringFormat(" {}={}", actor.id, StageName(actor.stage));
            Fail(run, Acore::StringFormat("setup did not finish within {} ms:{}", run.setupTimeoutMs, stages));
        }
        else if (run.state == RunState::Running && run.NowMs() > run.timeoutMs)
            Fail(run, Acore::StringFormat("run timed out after {} ms", run.timeoutMs));

        switch (run.state)
        {
            case RunState::Preparing:
                UpdatePreparing(run);
                break;
            case RunState::Running:
                UpdateRunning(run);
                break;
            case RunState::CleaningUp:
                UpdateCleanup(run);
                break;
            case RunState::Finished:
                break;
        }

        if (run.state == RunState::Finished)
        {
            Finish(run);
            _run.reset();
        }
    }

    void Runner::Shutdown()
    {
        if (!_run)
            return;

        LOG_INFO(LOG_CATEGORY, "GameplayTest: server shutdown, cleaning up run {}", _run->runId);
        Run& run = *_run;
        if (run.result.empty())
        {
            run.result = "aborted";
            run.error = "server shutdown";
        }

        // No more world updates will come: do the whole cleanup in one go. Pending
        // teleports are acknowledged first so nobody is logged out between maps.
        if (run.cleanupStage == 0)
            CleanupWorldState(run);
        for (ActorState& actor : run.actors)
            PumpHeadless(actor);
        LogoutActors(run);
        Finish(run);
        _run.reset();
    }

    void Runner::Fail(Run& run, std::string const& error)
    {
        if (run.result.empty())
        {
            run.result = "error";
            run.error = error;
        }

        LOG_WARN(LOG_CATEGORY, "GameplayTest: run {}: {}", run.runId, error);
        if (run.state == RunState::Preparing || run.state == RunState::Running)
            run.state = RunState::CleaningUp;
    }

    void Runner::CleanupNote(Run& run, std::string const& what, bool ok, std::string const& detail)
    {
        JsonValue entry = JsonValue::MakeObject();
        entry.Set("what", what);
        entry.Set("result", ok ? "ok" : "failed");
        if (!detail.empty())
            entry.Set("detail", detail);
        run.cleanupLog.Push(std::move(entry));
        if (!ok)
            LOG_WARN(LOG_CATEGORY, "GameplayTest: run {} cleanup: {} failed {}", run.runId, what, detail);
    }

    // ------------------------------------------------------------------
    // Test characters
    // ------------------------------------------------------------------

    void Runner::PumpHeadless(ActorState& actor)
    {
        if (!actor.session)
            return;

        // Nothing else drives a socketless session that is not in a map yet (its
        // login holder), and nothing at all acknowledges its teleports: a real
        // client answers SMSG_NEW_WORLD / MSG_MOVE_TELEPORT with an ack packet.
        // mod-playerbots does the same for its bots (PlayerbotAI::HandleTeleportAck).
        actor.session->ProcessQueryCallbacks();

        Player* player = actor.session->GetPlayer();
        if (!player || actor.session->PlayerLoading())
            return;

        if (player->IsBeingTeleportedFar())
            actor.session->HandleMoveWorldportAck();
        else if (player->IsBeingTeleportedNear() && player->IsInWorld())
        {
            WorldPacket ack(MSG_MOVE_TELEPORT_ACK, 20);
            ack << player->GetPackGUID();
            ack << uint32(0);
            ack << uint32(0);
            actor.session->HandleMoveTeleportAck(ack);
        }
    }

    void Runner::EnforcePhase(Run& run, Player* player)
    {
        uint32 const mask = run.config.phaseMask;
        if (player->GetPhaseMask() == mask)
            return;

        player->SetPhaseLayer(PHASE_LAYER_GAMEPLAY_TEST, mask, true);
        if (player->GetPhaseMask() != mask && !run.phaseWarned)
        {
            run.phaseWarned = true;
            run.warnings.Push(JsonValue(Acore::StringFormat("{} is in phase mask {:#x} instead of the run's {:#x} "
                "(GM mode or a newer exclusive phase layer); isolation is not guaranteed", player->GetName(),
                player->GetPhaseMask(), mask)));
        }
    }

    bool Runner::CreateCharacter(Run& run, ActorState& actor, std::string& error)
    {
        JsonValue const* create = actor.def.Find("create");
        uint8 const race = uint8(create->GetUInt("race"));
        uint8 const playerClass = uint8(create->GetUInt("class"));
        uint8 const gender = uint8(create->GetUInt("gender", GENDER_MALE));

        // Player::Create does not check names; a name the cache lookup can never
        // find again would create one orphan character per run.
        std::string normalized = actor.name;
        if (!normalizePlayerName(normalized) || normalized != actor.name ||
            ObjectMgr::CheckPlayerName(actor.name, true) != CHAR_NAME_SUCCESS)
        {
            error = "'" + actor.name + "' is not a valid new character name (capitalised, letters only)";
            return false;
        }

        if (!sObjectMgr->GetPlayerInfo(race, playerClass))
        {
            error = Acore::StringFormat("race {} / class {} is not a playable combination", race, playerClass);
            return false;
        }

        // The recipe of RandomPlayerbotFactory and mod-dungeon-clear's test driver:
        // a detached session, Player::Create, SaveToDB, then the cache entry that
        // makes the name resolvable.
        WorldSession* session = new WorldSession(run.accountId, std::string(run.accountName), 0, nullptr, SEC_PLAYER,
            EXPANSION_WRATH_OF_THE_LICH_KING, time_t(0), LOCALE_enUS, 0, false, false, 0);
        CharacterCreateInfo createInfo(actor.name, race, playerClass, gender, 0, 0, 0, 0, 0);
        Player* player = new Player(session);
        player->GetMotionMaster()->Initialize();
        if (!player->Create(sObjectMgr->GetGenerator<HighGuid::Player>().Generate(), &createInfo))
        {
            player->CleanupsBeforeDelete();
            delete player;
            delete session;
            error = "Player::Create refused '" + actor.name + "'";
            return false;
        }

        player->setCinematic(2);
        player->SetAtLoginFlag(AT_LOGIN_NONE);
        player->SaveToDB(true, false);
        sCharacterCache->AddCharacterCacheEntry(player->GetGUID(), run.accountId, player->GetName(),
            player->getGender(), player->getRace(), player->getClass(), player->GetLevel());

        actor.guid = player->GetGUID();
        actor.created = true;
        player->CleanupsBeforeDelete();
        delete player;
        delete session;

        LOG_INFO(LOG_CATEGORY, "GameplayTest: run {} created lab character '{}' ({}) on account {}", run.runId,
            actor.name, actor.guid.ToString(), run.accountName);
        return true;
    }

    void Runner::IssueLogin(Run& run, std::size_t index)
    {
        ActorState& actor = run.actors[index];
        auto holder = std::make_shared<LoginQueryHolder>(run.accountId, actor.guid);
        if (!holder->Initialize())
        {
            actor.stage = ActorStage::Failed;
            actor.failure = "could not prepare the login query holder";
            return;
        }

        // Socketless: WorldSession treats a null socket as headless (no account
        // online flag, no packets sent). Security stays SEC_PLAYER whatever the
        // account's level, so the character never enters GM mode on login.
        WorldSession* session = new WorldSession(run.accountId, std::string(run.accountName), 0, nullptr, SEC_PLAYER,
            EXPANSION_WRATH_OF_THE_LICH_KING, time_t(0), LOCALE_enUS, 0, false, false, 0);
        actor.session = session;
        actor.headless = true;
        actor.stage = ActorStage::LoggingIn;
        actor.stageStartMs = run.NowMs();

        Run* runPtr = &run;
        session->AddQueryHolderCallback(CharacterDatabase.DelayQueryHolder(holder)).AfterComplete(
            [session, runPtr, index](SQLQueryHolderBase const& result)
            {
                // Runs inside session->ProcessQueryCallbacks(), which only PumpHeadless calls
                // (world thread) until the player is on a map.
                session->HandlePlayerLoginFromDB(static_cast<LoginQueryHolder const&>(result));
                runPtr->actors[index].loginCallbackDone = true;
            });

        LOG_INFO(LOG_CATEGORY, "GameplayTest: run {} logging in '{}' ({}) headless", run.runId, actor.name,
            actor.guid.ToString());
    }

    void Runner::NormalizeActor(Run& run, ActorState& actor, Player* player)
    {
        if (!actor.captured)
        {
            actor.captured = true;
            actor.originalLevel = player->GetLevel();
            actor.originalMoney = player->GetMoney();
            actor.originalLocation = { player->GetMapId(), player->GetPositionX(), player->GetPositionY(),
                player->GetPositionZ(), player->GetOrientation() };
        }

        player->SetPhaseLayer(PHASE_LAYER_GAMEPLAY_TEST, run.config.phaseMask, true);

        bool const reset = actor.def.GetBool("reset", true);
        if (reset)
        {
            if (!player->IsAlive())
            {
                player->ResurrectPlayer(1.0f);
                player->SpawnCorpseBones();
            }
            player->CombatStop(true);
            player->RemoveAllSpellCooldown();
        }

        if (uint32 const level = actor.def.GetUInt("level"))
            ApplyLevel(player, uint8(level));

        if (reset)
        {
            player->SetFullHealth();
            Powers const power = player->getPowerType();
            if (power == POWER_MANA || power == POWER_ENERGY)
                player->SetPower(power, player->GetMaxPower(power));
        }
    }

    void Runner::AdvanceActor(Run& run, std::size_t index)
    {
        ActorState& actor = run.actors[index];
        auto fail = [&actor](std::string reason)
        {
            actor.stage = ActorStage::Failed;
            actor.failure = std::move(reason);
        };

        switch (actor.stage)
        {
            case ActorStage::Resolve:
            {
                ObjectGuid const guid = sCharacterCache->GetCharacterGuidByName(actor.name);
                if (!guid)
                {
                    if (!actor.def.Has("create"))
                        return fail("character '" + actor.name + "' does not exist; add a \"create\" block or "
                            "make it on the lab account by hand");
                    if (!run.config.allowCreateCharacters)
                        return fail("character '" + actor.name + "' does not exist and "
                            "DC.GameplayTest.AllowCreateCharacters = 0");
                    if (actor.mode == SessionMode::Online)
                        return fail("character '" + actor.name + "' does not exist, so it cannot be online");

                    std::string error;
                    if (!CreateCharacter(run, actor, error))
                        return fail(error);

                    actor.stage = ActorStage::AwaitFlush;
                    actor.stageStartMs = run.NowMs();
                    actor.flushDeadlineMs = run.NowMs() + FLUSH_TIMEOUT_MS;
                    return;
                }

                // The one hard safety rule: only characters of the lab account.
                if (sCharacterCache->GetCharacterAccountIdByGuid(guid) != run.accountId)
                    return fail("character '" + actor.name + "' is not on the lab account " + run.accountName +
                        "; the harness never drives other accounts' characters");

                actor.guid = guid;
                if (Player* online = ObjectAccessor::FindConnectedPlayer(guid))
                {
                    WorldSession* session = online->GetSession();
                    if (!session || session->IsHeadless())
                        return fail("'" + actor.name + "' is already online through a headless (bot) session");
                    if (actor.mode == SessionMode::Headless)
                        return fail("'" + actor.name + "' is online with a client; use \"session\": \"auto\" or "
                            "\"online\"");
                    if (online->IsGameMaster())
                        return fail("'" + actor.name + "' has GM mode on (GM mode sees every phase, so the run "
                            "would not be isolated); turn it off with .gm off");

                    actor.headless = false;
                    actor.stage = ActorStage::Normalize;
                    actor.stageStartMs = run.NowMs();
                    return;
                }

                if (actor.mode == SessionMode::Online)
                    return fail("'" + actor.name + "' is not online with a client");

                IssueLogin(run, index);
                return;
            }
            case ActorStage::AwaitFlush:
            {
                // The login reads the character back from the database, so it waits
                // until the queued INSERT is readable. Asked asynchronously: polling
                // the write queue instead would never read zero on a busy realm.
                if (actor.flushLanded)
                {
                    IssueLogin(run, index);
                    return;
                }

                if (run.NowMs() > actor.flushDeadlineMs)
                    return fail("the new character's save did not land within 20 s");

                if (actor.flushProbeInFlight || run.NowMs() < actor.nextFlushProbeMs)
                    return;

                actor.flushProbeInFlight = true;
                CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_CHECK_NAME);
                stmt->SetData(0, actor.name);
                Run* runPtr = &run;
                run.queries.AddCallback(CharacterDatabase.AsyncQuery(stmt).WithPreparedCallback(
                    [runPtr, index](PreparedQueryResult result)
                    {
                        ActorState& probed = runPtr->actors[index];
                        probed.flushProbeInFlight = false;
                        probed.nextFlushProbeMs = runPtr->NowMs() + FLUSH_PROBE_INTERVAL_MS;
                        if (result)
                            probed.flushLanded = true;
                    }));
                return;
            }
            case ActorStage::LoggingIn:
            {
                Player* player = actor.session ? actor.session->GetPlayer() : nullptr;
                if (player && player->IsInWorld() && !actor.session->PlayerLoading())
                {
                    actor.stage = ActorStage::Normalize;
                    actor.stageStartMs = run.NowMs();
                    return;
                }

                if (actor.loginCallbackDone && !player)
                    return fail("login of '" + actor.name + "' failed (Player::LoadFromDB refused the character)");
                return;
            }
            case ActorStage::Normalize:
            {
                Player* player = ActorPlayer(actor);
                if (!player || !player->IsInWorld())
                    return fail("'" + actor.name + "' left the world during setup");

                NormalizeActor(run, actor, player);

                Location const& destination = run.location;
                if (player->GetMapId() == destination.mapId &&
                    player->GetDistance(destination.x, destination.y, destination.z) < 5.0f)
                {
                    actor.stage = ActorStage::Ready;
                    return;
                }

                if (!player->TeleportTo(destination.mapId, destination.x, destination.y, destination.z,
                    destination.o))
                    return fail(Acore::StringFormat("teleport of '{}' to map {} was refused", actor.name,
                        destination.mapId));

                actor.teleportIssued = true;
                actor.stage = ActorStage::Arriving;
                actor.stageStartMs = run.NowMs();
                return;
            }
            case ActorStage::Arriving:
            {
                Player* player = ActorPlayer(actor);
                if (!player)
                    return fail("'" + actor.name + "' logged out during setup");

                if (player->IsInWorld() && !player->IsBeingTeleported() && player->GetMapId() == run.location.mapId)
                {
                    EnforcePhase(run, player);
                    actor.stage = ActorStage::Ready;
                }
                return;
            }
            case ActorStage::Ready:
            case ActorStage::Failed:
                return;
        }
    }

    void Runner::UpdatePreparing(Run& run)
    {
        bool allReady = true;
        for (std::size_t i = 0; i < run.actors.size(); ++i)
        {
            AdvanceActor(run, i);
            ActorState const& actor = run.actors[i];
            if (actor.stage == ActorStage::Failed)
            {
                Fail(run, "actor " + actor.id + ": " + actor.failure);
                return;
            }
            if (actor.stage != ActorStage::Ready)
                allReady = false;
        }

        if (!allReady)
            return;

        run.setupDoneMs = run.NowMs();
        run.state = RunState::Running;
        LOG_INFO(LOG_CATEGORY, "GameplayTest: run {} setup done in {} ms", run.runId, run.setupDoneMs);
    }

    void Runner::UpdateRunning(Run& run)
    {
        for (ActorState& actor : run.actors)
        {
            Player* player = ActorPlayer(actor);
            if (!player || (actor.session && actor.session->IsKicked()))
            {
                Fail(run, "actor " + actor.id + " (" + actor.name + ") left the world");
                return;
            }
            if (player->IsInWorld() && !player->IsBeingTeleported())
                EnforcePhase(run, player);
        }

        std::vector<JsonValue> const& steps = run.scenario.Find("steps")->Items();
        if (run.current >= steps.size())
        {
            run.stepsDoneMs = run.NowMs();
            run.state = RunState::CleaningUp;
            return;
        }

        JsonValue const& step = steps[run.current];
        StepRecord& record = run.steps[run.current];
        if (!run.scratch.started)
        {
            run.scratch = StepScratch();
            run.scratch.started = true;
            run.scratch.startMs = run.NowMs();
            record.startedMs = run.scratch.startMs;
        }

        Outcome outcome = ExecuteStep(run, step, record);
        if (outcome == Outcome::Running)
        {
            if (run.scratch.deadlineMs && run.NowMs() > run.scratch.deadlineMs)
            {
                outcome = Outcome::Fail;
                if (record.message.empty())
                    record.message = Acore::StringFormat("timed out after {} ms",
                        run.scratch.deadlineMs - run.scratch.startMs);
            }
            else
                return;
        }

        record.durationMs = run.NowMs() - run.scratch.startMs;
        record.result = outcome == Outcome::Pass ? "pass" : outcome == Outcome::Fail ? "fail" : "error";
        run.scratch.started = false;
        ++run.current;

        LOG_INFO(LOG_CATEGORY, "GameplayTest: run {}{}", run.runId, StepLine(record));

        if (outcome != Outcome::Pass && run.stopOnFailure)
        {
            for (std::size_t i = run.current; i < run.steps.size(); ++i)
                run.steps[i].result = "skipped";
            run.current = run.steps.size();
        }
    }

    // ------------------------------------------------------------------
    // Cleanup
    // ------------------------------------------------------------------

    void Runner::CleanupWorldState(Run& run)
    {
        run.cleanupStage = 1;
        run.cleanupStageMs = run.NowMs();

        for (SpawnRecord const& spawn : run.spawns)
        {
            Map* map = sMapMgr->FindMap(spawn.mapId, spawn.instanceId);
            if (!map)
            {
                CleanupNote(run, "despawn " + spawn.id, true, "map already unloaded");
                continue;
            }

            if (spawn.gameObject)
            {
                if (GameObject* object = map->GetGameObject(spawn.guid))
                {
                    object->SetRespawnTime(0);
                    object->Delete();
                }
            }
            else if (Creature* creature = map->GetCreature(spawn.guid))
                creature->DespawnOrUnsummon();

            CleanupNote(run, "despawn " + spawn.id, true);
        }

        for (ActorState& actor : run.actors)
        {
            // Only characters the run actually took over (setup reached them); one refused at
            // setup, e.g. an online character in GM mode, is left exactly as it was.
            if (!actor.captured)
                continue;

            Player* player = ActorPlayer(actor);
            if (!player || !player->IsInWorld())
            {
                CleanupNote(run, "restore " + actor.id, false, "not in the world");
                continue;
            }

            if (!player->IsAlive())
            {
                player->ResurrectPlayer(1.0f);
                player->SpawnCorpseBones();
            }
            player->CombatStop(true);

            if (run.cleanup.removeAuras)
                for (uint32 spell : actor.addedAuras)
                    player->RemoveAurasDueToSpell(spell);

            if (run.cleanup.removeQuests)
                for (uint32 questId : actor.addedQuests)
                    RemoveQuestFromPlayer(player, questId);

            if (run.cleanup.restoreSpells)
            {
                for (uint32 spell : actor.learnedSpells)
                    player->removeSpell(spell, SPEC_MASK_ALL, false);
                for (uint32 spell : actor.unlearnedSpells)
                    player->learnSpell(spell);
            }

            if (run.cleanup.removeItems)
                for (auto const& [entry, count] : actor.addedItems)
                    if (count)
                        player->DestroyItemCount(entry, count, true, false);

            if (run.cleanup.restoreMoney && actor.captured)
                player->SetMoney(actor.originalMoney);

            if (run.cleanup.restorePrestige && actor.prestigeTouched)
                PrestigeAPI::SetPrestigeLevel(player, actor.originalPrestige);

            if (run.cleanup.restoreLevel && actor.captured && player->GetLevel() != actor.originalLevel)
            {
                ApplyLevel(player, actor.originalLevel);
                // A prestige fresh start unlearns class spells; levelling back up does not teach them again.
                if (actor.prestigeTouched)
                    DCFirstStart::LearnSpells::CatchUpClassSpells(player, false);
            }

            if (!actor.headless)
            {
                player->ClearPhaseLayer(PHASE_LAYER_GAMEPLAY_TEST);
                if (run.cleanup.restorePosition && actor.captured)
                {
                    Location const& home = actor.originalLocation;
                    player->TeleportTo(home.mapId, home.x, home.y, home.z, home.o);
                }
            }
            else if (run.cleanup.restorePosition)
            {
                // Park headless actors back at the lab spot before they log out: the next
                // login shows them for a moment at the saved position, before the phase
                // layer applies, and that should not be a starting zone or a dungeon.
                Location const& lab = run.location;
                if (player->GetMapId() != lab.mapId || player->GetDistance(lab.x, lab.y, lab.z) > 30.0f)
                    player->TeleportTo(lab.mapId, lab.x, lab.y, lab.z, lab.o);
            }

            CleanupNote(run, "restore " + actor.id, true);
        }
    }

    void Runner::LogoutActors(Run& run)
    {
        for (ActorState& actor : run.actors)
        {
            if (!actor.session)
                continue;

            if (Player* player = actor.session->GetPlayer())
                if (player->IsInWorld())
                    player->ClearPhaseLayer(PHASE_LAYER_GAMEPLAY_TEST);

            // The core's own logout: saves the character, removes it from its map and
            // runs the logout hooks. Then the session goes, as mod-playerbots does it.
            actor.session->LogoutPlayer(true);
            delete actor.session;
            actor.session = nullptr;
            CleanupNote(run, "logout " + actor.id, true);
        }
    }

    void Runner::UpdateCleanup(Run& run)
    {
        if (run.cleanupStage == 0)
        {
            if (!run.stepsDoneMs)
                run.stepsDoneMs = run.NowMs();

            // An actor between maps cannot be restored; give its teleport a moment to land.
            bool moving = false;
            for (ActorState const& actor : run.actors)
                if (Player* player = ActorPlayer(actor))
                    if (player->IsBeingTeleported())
                        moving = true;

            if (moving && run.NowMs() < run.stepsDoneMs + CLEANUP_SETTLE_MS)
                return;

            CleanupWorldState(run);
            return;
        }

        if (run.cleanupStage == 1)
        {
            // Let teleports settle (the acks are pumped every tick) before anyone logs out.
            bool settled = true;
            for (ActorState const& actor : run.actors)
                if (Player* player = ActorPlayer(actor))
                    if (player->IsBeingTeleported())
                        settled = false;

            if (!settled && run.NowMs() < run.cleanupStageMs + CLEANUP_SETTLE_MS)
                return;

            LogoutActors(run);
            run.state = RunState::Finished;
        }
    }

    // ------------------------------------------------------------------
    // Report
    // ------------------------------------------------------------------

    void Runner::WriteReport(Run& run)
    {
        uint32 passed = 0;
        uint32 failed = 0;
        uint32 errors = 0;
        uint32 skipped = 0;
        JsonValue steps = JsonValue::MakeArray();
        for (StepRecord const& record : run.steps)
        {
            if (record.result == "pass")
                ++passed;
            else if (record.result == "fail")
                ++failed;
            else if (record.result == "error")
                ++errors;
            else
                ++skipped;

            JsonValue entry = JsonValue::MakeObject();
            entry.Set("index", record.index);
            entry.Set("action", record.action);
            if (!record.label.empty())
                entry.Set("label", record.label);
            entry.Set("result", record.result == "pending" ? std::string("skipped") : record.result);
            entry.Set("started_ms", record.startedMs);
            entry.Set("duration_ms", record.durationMs);
            if (!record.values.Members().empty())
                entry.Set("values", record.values);
            if (!record.message.empty())
                entry.Set("message", record.message);
            steps.Push(std::move(entry));
        }

        JsonValue actors = JsonValue::MakeArray();
        for (ActorState const& actor : run.actors)
        {
            JsonValue entry = JsonValue::MakeObject();
            entry.Set("id", actor.id);
            entry.Set("name", actor.name);
            entry.Set("guid", actor.guid.ToString());
            entry.Set("session", actor.headless ? "headless" : "online");
            entry.Set("created", actor.created);
            entry.Set("setup_stage", StageName(actor.stage));
            if (!actor.failure.empty())
                entry.Set("failure", actor.failure);
            actors.Push(std::move(entry));
        }

        JsonValue summary = JsonValue::MakeObject();
        summary.Set("total", uint32(run.steps.size()));
        summary.Set("passed", passed);
        summary.Set("failed", failed);
        summary.Set("errors", errors);
        summary.Set("skipped", skipped);

        JsonValue report = JsonValue::MakeObject();
        report.Set("schema", REPORT_SCHEMA);
        report.Set("run_id", run.runId);
        report.Set("scenario", run.file);
        report.Set("name", run.name);
        report.Set("result", run.result);
        if (!run.error.empty())
            report.Set("error", run.error);
        report.Set("started_at", LocalTimestamp(run.startedWall, false));
        report.Set("started_unix", int64(run.startedWall));
        report.Set("setup_ms", run.setupDoneMs);
        report.Set("duration_ms", run.NowMs());
        report.Set("phase_mask", run.config.phaseMask);
        report.Set("destructive", run.destructive);
        report.Set("server_revision", GitRevision::GetFullVersion());
        report.Set("actors", std::move(actors));
        report.Set("summary", std::move(summary));
        report.Set("steps", std::move(steps));
        report.Set("cleanup", run.cleanupLog);
        if (!run.warnings.Items().empty())
            report.Set("warnings", run.warnings);

        if (run.config.outputDir.empty())
            return;

        std::error_code ec;
        std::filesystem::path const dir(run.config.outputDir);
        std::filesystem::create_directories(dir, ec);
        std::filesystem::path const target = dir / (run.runId + ".json");
        std::filesystem::path const temporary = dir / (run.runId + ".json.tmp");
        {
            std::ofstream out(temporary, std::ios::binary | std::ios::trunc);
            if (!out)
            {
                LOG_ERROR(LOG_CATEGORY, "GameplayTest: cannot write report {}", temporary.generic_string());
                return;
            }
            out << report.Dump(true);
        }

        std::filesystem::rename(temporary, target, ec);
        if (ec)
        {
            LOG_ERROR(LOG_CATEGORY, "GameplayTest: cannot move report into place {}: {}", target.generic_string(),
                ec.message());
            return;
        }

        run.reportPath = target.generic_string();
    }

    void Runner::Finish(Run& run)
    {
        uint32 failed = 0;
        uint32 errors = 0;
        uint32 passed = 0;
        uint32 skipped = 0;
        for (StepRecord& record : run.steps)
        {
            if (record.result == "pending")
                record.result = "skipped";
            if (record.result == "pass")
                ++passed;
            else if (record.result == "fail")
                ++failed;
            else if (record.result == "error")
                ++errors;
            else
                ++skipped;
        }

        if (run.result.empty())
            run.result = errors ? "error" : failed ? "fail" : skipped ? "error" : "pass";

        WriteReport(run);

        RunSummary summary;
        summary.runId = run.runId;
        summary.name = run.name;
        summary.result = run.result;
        summary.error = run.error;
        summary.reportPath = run.reportPath;
        summary.passed = passed;
        summary.failed = failed;
        summary.errors = errors;
        summary.skipped = skipped;
        summary.durationMs = run.NowMs();
        for (StepRecord const& record : run.steps)
            summary.stepLines.push_back(StepLine(record));

        std::string const line = Acore::StringFormat("GameplayTest: run {} '{}' finished: {} ({} passed, {} failed, "
            "{} errors, {} skipped) in {} ms, report {}", run.runId, run.name, run.result, passed, failed, errors,
            skipped, summary.durationMs, run.reportPath.empty() ? std::string("not written") : run.reportPath);
        LOG_INFO(LOG_CATEGORY, "{}", line);
        if (!run.error.empty())
            LOG_INFO(LOG_CATEGORY, "GameplayTest: run {} error: {}", run.runId, run.error);

        if (run.issuer)
            if (Player* issuer = ObjectAccessor::FindConnectedPlayer(run.issuer))
                if (WorldSession* session = issuer->GetSession())
                    ChatHandler(session).SendSysMessage(line);

        _history.push_back(std::move(summary));
        while (_history.size() > MAX_HISTORY)
            _history.pop_front();
    }

    // ------------------------------------------------------------------
    // References
    // ------------------------------------------------------------------

    std::string Runner::DefaultActorId(Run const& run) const
    {
        return run.actors.empty() ? std::string() : run.actors.front().id;
    }

    ActorState* Runner::FindActor(Run& run, std::string const& id)
    {
        for (ActorState& actor : run.actors)
            if (actor.id == id)
                return &actor;
        return nullptr;
    }

    SpawnRecord* Runner::FindSpawn(Run& run, std::string const& id)
    {
        for (SpawnRecord& spawn : run.spawns)
            if (spawn.id == id)
                return &spawn;
        return nullptr;
    }

    Player* Runner::ActorPlayer(ActorState const& actor) const
    {
        if (actor.session)
            return actor.session->GetPlayer();

        if (!actor.guid || actor.headless)
            return nullptr;

        // An online actor counts only while it is still the client session we took over.
        Player* player = ObjectAccessor::FindConnectedPlayer(actor.guid);
        if (player && player->GetSession() && player->GetSession()->IsHeadless())
            return nullptr;
        return player;
    }

    Player* Runner::ResolvePlayer(Run& run, std::string const& ref)
    {
        ActorState* actor = FindActor(run, ref);
        if (!actor)
            return nullptr;

        Player* player = ActorPlayer(*actor);
        return player && player->IsInWorld() ? player : nullptr;
    }

    Unit* Runner::ResolveUnit(Run& run, std::string const& ref)
    {
        if (Player* player = ResolvePlayer(run, ref))
            return player;

        SpawnRecord* spawn = FindSpawn(run, ref);
        if (!spawn || spawn->gameObject)
            return nullptr;

        Map* map = sMapMgr->FindMap(spawn->mapId, spawn->instanceId);
        return map ? map->GetCreature(spawn->guid) : nullptr;
    }

    GameObject* Runner::ResolveGameObject(Run& run, std::string const& ref)
    {
        SpawnRecord* spawn = FindSpawn(run, ref);
        if (!spawn || !spawn->gameObject)
            return nullptr;

        Map* map = sMapMgr->FindMap(spawn->mapId, spawn->instanceId);
        return map ? map->GetGameObject(spawn->guid) : nullptr;
    }

    WorldObject* Runner::ResolveObject(Run& run, std::string const& ref)
    {
        if (Unit* unit = ResolveUnit(run, ref))
            return unit;
        return ResolveGameObject(run, ref);
    }
}
