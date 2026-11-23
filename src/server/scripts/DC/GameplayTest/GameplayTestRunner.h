/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * In-process gameplay scenario harness (.dca test ...), version 1.
 *
 * A run loads a JSON scenario, brings characters of ONE configured lab account
 * into the world (headless sessions built the way mod-playerbots builds them, or
 * a lab character that is already online with a client), puts them in a private
 * phase, executes the steps and writes a JSON report. Off unless
 * DC.GameplayTest.Enable = 1. Apps side: apps/gameplay-test/ (runner + README).
 *
 * Threading: every entry point here runs on the world thread - the command
 * handlers (chat commands are PROCESS_THREADUNSAFE, console/SOAP commands go
 * through World::ProcessCliCommands) and WorldScript::OnUpdate/OnShutdown. The
 * world thread only does this work outside MapMgr::Update, while the map
 * workers are parked, so touching players, creatures and maps from here is the
 * same as any GM command doing it. No locks; nothing here may be called from a
 * map thread. Nothing stores a Player/Creature pointer across ticks: actors and
 * spawns are kept as guids and resolved every time.
 */

#ifndef DC_GAMEPLAY_TEST_RUNNER_H
#define DC_GAMEPLAY_TEST_RUNNER_H

#include "AsyncCallbackProcessor.h"
#include "DatabaseEnvFwd.h"
#include "GameplayTestJson.h"
#include "ObjectGuid.h"
#include "QueryCallback.h"
#include <chrono>
#include <ctime>
#include <deque>
#include <map>
#include <memory>
#include <set>
#include <string>
#include <vector>

class GameObject;
class Player;
class Unit;
class WorldObject;
class WorldSession;

namespace DC::GameplayTest
{
    constexpr char const* LOG_CATEGORY = "scripts.dc.test";

    // Player::SetPhaseLayer id owned by the harness. DC systems use ids 1-5
    // (DC/CrossSystem/PhaseLayers.h); 100 stays clear of that range.
    constexpr uint32 PHASE_LAYER_GAMEPLAY_TEST = 100;

    constexpr uint32 SCENARIO_SCHEMA = 1;
    constexpr uint32 REPORT_SCHEMA = 1;
    constexpr uint32 MAX_STEPS = 500;
    constexpr uint32 MAX_HISTORY = 10;

    struct Config
    {
        bool enabled = false;
        std::string account;
        std::string scenarioDir;
        std::string outputDir;
        uint32 phaseMask = 0x80000000;
        uint32 maxRunMs = 600000;
        uint32 maxActors = 5;
        uint32 maxSpawns = 50;
        bool allowCreateCharacters = true;
        bool allowDestructive = false;

        // Read on every command: sConfigMgr lookups are cheap and commands are rare.
        static Config Load();
    };

    struct Value
    {
        enum class Kind : uint8
        {
            None,
            Number,
            Text
        };

        Kind kind = Kind::None;
        double number = 0.0;
        std::string text;

        static Value Number(double v);
        static Value Text(std::string v);
        [[nodiscard]] JsonValue ToJson() const;
        [[nodiscard]] std::string ToString() const;
    };

    enum class Eval : uint8
    {
        Ok,
        Pending,        // not known yet (cold cache, unit mid-teleport): retry
        Error           // bad spec: never retried
    };

    struct MetricResult
    {
        Eval status = Eval::Error;
        Value value;
        std::string detail;     // error text, or extra context (e.g. an activation refusal)
    };

    enum class Outcome : uint8
    {
        Running,
        Pass,
        Fail,
        Error
    };

    enum class RunState : uint8
    {
        Preparing,
        Running,
        CleaningUp,
        Finished
    };

    enum class SessionMode : uint8
    {
        Auto,
        Headless,
        Online
    };

    enum class ActorStage : uint8
    {
        Resolve,
        AwaitFlush,
        LoggingIn,
        Normalize,
        Arriving,
        Ready,
        Failed
    };

    struct Location
    {
        uint32 mapId = 0;
        float x = 0.0f;
        float y = 0.0f;
        float z = 0.0f;
        float o = 0.0f;
    };

    struct ActorState
    {
        std::string id;
        std::string name;
        JsonValue def;
        SessionMode mode = SessionMode::Auto;
        ObjectGuid guid;
        WorldSession* session = nullptr;    // owned (created by the run) when headless
        bool headless = false;
        bool created = false;
        ActorStage stage = ActorStage::Resolve;
        bool loginCallbackDone = false;
        bool flushProbeInFlight = false;
        bool flushLanded = false;
        uint64 nextFlushProbeMs = 0;
        uint64 flushDeadlineMs = 0;
        bool teleportIssued = false;
        uint64 stageStartMs = 0;
        std::string failure;

        // What cleanup puts back.
        bool captured = false;
        uint8 originalLevel = 0;
        uint32 originalMoney = 0;
        Location originalLocation;
        bool prestigeTouched = false;
        uint32 originalPrestige = 0;
        std::map<uint32, uint32> addedItems;    // entry -> count the run added
        std::set<uint32> learnedSpells;         // learned by the run, unknown before
        std::set<uint32> unlearnedSpells;       // known before, unlearned by the run
        std::set<uint32> addedAuras;            // auras the run put on this actor
        std::set<uint32> addedQuests;           // quests the run added, completed or rewarded
    };

    struct SpawnRecord
    {
        std::string id;
        bool gameObject = false;
        uint32 entry = 0;
        ObjectGuid guid;
        uint32 mapId = 0;
        uint32 instanceId = 0;
    };

    struct StepRecord
    {
        uint32 index = 0;
        std::string action;
        std::string label;
        std::string result = "pending";     // pending, pass, fail, error, skipped
        uint64 startedMs = 0;               // since run start
        uint64 durationMs = 0;
        JsonValue values = JsonValue::MakeObject();
        std::string message;
    };

    // Per-step scratch, reset before each step.
    struct StepScratch
    {
        bool started = false;
        uint64 startMs = 0;
        uint64 deadlineMs = 0;
        bool issued = false;
        Location destination;
        uint32 attempts = 0;
        uint64 nextAttemptMs = 0;
    };

    struct CleanupPolicy
    {
        bool removeItems = true;
        bool removeAuras = true;
        bool removeQuests = true;
        bool restoreSpells = true;
        bool restoreLevel = false;
        bool restoreMoney = true;
        bool restorePrestige = true;
        bool restorePosition = true;        // online: back where they were; headless: parked at the run location
    };

    struct Run
    {
        Config config;
        std::string runId;
        std::string file;
        std::string path;
        std::string name;
        JsonValue scenario;
        ObjectGuid issuer;
        uint32 accountId = 0;
        std::string accountName;

        RunState state = RunState::Preparing;
        std::chrono::steady_clock::time_point started;
        std::time_t startedWall = 0;
        uint64 setupDoneMs = 0;
        uint64 stepsDoneMs = 0;
        uint32 timeoutMs = 0;
        uint32 setupTimeoutMs = 0;
        bool stopOnFailure = true;
        bool destructive = false;
        Location location;
        CleanupPolicy cleanup;

        std::vector<ActorState> actors;
        std::vector<SpawnRecord> spawns;
        std::vector<StepRecord> steps;
        std::size_t current = 0;
        StepScratch scratch;
        std::map<std::string, Value> vars;

        JsonValue cleanupLog = JsonValue::MakeArray();
        JsonValue warnings = JsonValue::MakeArray();
        std::string result;             // pass, fail, error, aborted
        std::string error;
        bool abortRequested = false;
        std::string abortReason;
        uint32 cleanupStage = 0;
        uint64 cleanupStageMs = 0;
        std::string reportPath;
        bool phaseWarned = false;

        QueryCallbackProcessor queries;

        [[nodiscard]] uint64 NowMs() const;
    };

    struct RunSummary
    {
        std::string runId;
        std::string name;
        std::string result;
        std::string error;
        std::string reportPath;
        uint32 passed = 0;
        uint32 failed = 0;
        uint32 errors = 0;
        uint32 skipped = 0;
        uint64 durationMs = 0;
        std::vector<std::string> stepLines;
    };

    // Scenario validation shared by `.dca test validate` and `.dca test run`.
    bool ValidateScenario(JsonValue const& scenario, Config const& config, std::string& error);

    // The core's `.quest remove` sequence, shared by the quest_remove step and cleanup.
    void RemoveQuestFromPlayer(Player* player, uint32 questId);

    class Runner
    {
    public:
        static Runner& Instance();

        bool Validate(Config const& config, std::string const& file, std::string& outName, uint32& outSteps,
            std::string& error) const;
        bool Start(Config const& config, std::string const& file, ObjectGuid issuer, std::string& outRunId,
            std::string& error);
        bool Abort(std::string const& reason);
        [[nodiscard]] bool IsActive() const { return _run != nullptr; }
        // True while the active run drives this character through a headless session.
        [[nodiscard]] bool HoldsHeadless(ObjectGuid guid) const;
        [[nodiscard]] std::vector<std::string> Status(std::string const& runId) const;
        [[nodiscard]] std::vector<std::string> ListScenarios(Config const& config, std::string& error) const;

        void Update();
        void Shutdown();

    private:
        Runner() = default;

        // Lifecycle (GameplayTestRunner.cpp)
        bool LoadScenario(Config const& config, std::string const& file, JsonValue& out, std::string& path,
            std::string& error) const;
        void UpdatePreparing(Run& run);
        void UpdateRunning(Run& run);
        void UpdateCleanup(Run& run);
        void AdvanceActor(Run& run, std::size_t index);
        bool CreateCharacter(Run& run, ActorState& actor, std::string& error);
        void IssueLogin(Run& run, std::size_t index);
        void NormalizeActor(Run& run, ActorState& actor, Player* player);
        void PumpHeadless(ActorState& actor);
        void EnforcePhase(Run& run, Player* player);
        void CleanupWorldState(Run& run);
        void LogoutActors(Run& run);
        void Finish(Run& run);
        void WriteReport(Run& run);
        void Fail(Run& run, std::string const& error);
        void CleanupNote(Run& run, std::string const& what, bool ok, std::string const& detail = {});
        static std::string StepLine(StepRecord const& record);

        // References (GameplayTestRunner.cpp)
        ActorState* FindActor(Run& run, std::string const& id);
        SpawnRecord* FindSpawn(Run& run, std::string const& id);
        Player* ActorPlayer(ActorState const& actor) const;
        Player* ResolvePlayer(Run& run, std::string const& ref);
        Unit* ResolveUnit(Run& run, std::string const& ref);
        GameObject* ResolveGameObject(Run& run, std::string const& ref);
        WorldObject* ResolveObject(Run& run, std::string const& ref);
        std::string DefaultActorId(Run const& run) const;

        // Steps and metrics (GameplayTestSteps.cpp)
        Outcome ExecuteStep(Run& run, JsonValue const& step, StepRecord& record);
        MetricResult EvaluateMetric(Run& run, JsonValue const& spec);
        Outcome EvaluateAssertion(Run& run, JsonValue const& spec, StepRecord& record, bool lastChance);

        Outcome StepTeleport(Run& run, JsonValue const& step, StepRecord& record);
        Outcome StepSetLevel(Run& run, JsonValue const& step, StepRecord& record);
        Outcome StepLearn(Run& run, JsonValue const& step, StepRecord& record, bool learn);
        Outcome StepAddItem(Run& run, JsonValue const& step, StepRecord& record);
        Outcome StepRemoveItem(Run& run, JsonValue const& step, StepRecord& record);
        Outcome StepEquip(Run& run, JsonValue const& step, StepRecord& record);
        Outcome StepCast(Run& run, JsonValue const& step, StepRecord& record);
        Outcome StepAddAura(Run& run, JsonValue const& step, StepRecord& record);
        Outcome StepRemoveAura(Run& run, JsonValue const& step, StepRecord& record);
        Outcome StepSpawn(Run& run, JsonValue const& step, StepRecord& record, bool gameObject);
        Outcome StepDespawn(Run& run, JsonValue const& step, StepRecord& record);
        Outcome StepKill(Run& run, JsonValue const& step, StepRecord& record);
        Outcome StepRevive(Run& run, JsonValue const& step, StepRecord& record);
        Outcome StepAcceptResurrect(Run& run, JsonValue const& step, StepRecord& record);
        Outcome StepSetHealth(Run& run, JsonValue const& step, StepRecord& record);
        Outcome StepSetPower(Run& run, JsonValue const& step, StepRecord& record);
        Outcome StepSetMoney(Run& run, JsonValue const& step, StepRecord& record);
        Outcome StepQuest(Run& run, JsonValue const& step, StepRecord& record, std::string const& action);
        Outcome StepItemUpgrade(Run& run, JsonValue const& step, StepRecord& record);
        Outcome StepPrestige(Run& run, JsonValue const& step, StepRecord& record);
        Outcome StepWait(Run& run, JsonValue const& step, StepRecord& record);
        Outcome StepSnapshot(Run& run, JsonValue const& step, StepRecord& record);

        std::unique_ptr<Run> _run;
        std::deque<RunSummary> _history;
        uint32 _runCounter = 0;
    };
}

#endif // DC_GAMEPLAY_TEST_RUNNER_H
