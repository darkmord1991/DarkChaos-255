/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * DarkChaos Mythic+ Spectator System
 * Extends ArenaSpectator framework for Mythic+ dungeon spectating.
 * Features: Live run watching, leaderboard view, stream mode, invite links, replays.
 */

#ifndef DC_MYTHIC_SPECTATOR_H
#define DC_MYTHIC_SPECTATOR_H

#include "Player.h"
#include "ObjectGuid.h"
#include "Map.h"

#include <unordered_map>
#include <unordered_set>
#include <string>
#include <vector>
#include <deque>

namespace DCMythicSpectator
{
    // ============================================================
    // Spectator Protocol Constants
    // ============================================================
    constexpr const char* ADDON_PREFIX = "DCM+S\x09";  // DarkChaos Mythic+ Spectator
    constexpr uint32 SPECTATOR_VERSION = 2;
    constexpr uint32 MAX_SPECTATORS_PER_RUN = 50;
    constexpr uint32 SPECTATOR_UPDATE_INTERVAL_MS = 1000;
    constexpr uint32 SPECTATOR_BINDSIGHT_SPELL = 6277;
    constexpr uint32 INVITE_CODE_LENGTH = 8;
    constexpr uint32 REPLAY_MAX_EVENTS = 10000;

    // Stream Mode - Hide player identities for public broadcasts
    constexpr uint32 STREAM_MODE_NONE = 0;
    constexpr uint32 STREAM_MODE_NAMES_HIDDEN = 1;
    constexpr uint32 STREAM_MODE_FULL_ANONYMOUS = 2;

    // ============================================================
    // Replay Event Types
    // ============================================================
    enum class ReplayEventType : uint8
    {
        RUN_START = 0,
        BOSS_PULL = 1,
        BOSS_KILL = 2,
        PLAYER_DEATH = 3,
        WIPE = 4,
        HUD_UPDATE = 5,
        PLAYER_POSITION = 6,
        COMBAT_LOG = 7,
        RUN_COMPLETE = 8,
        RUN_FAIL = 9
    };

    // ============================================================
    // Replay Event Structure
    // ============================================================
    struct ReplayEvent
    {
        uint64 timestamp;           // Milliseconds from run start
        ReplayEventType type;
        std::string data;           // JSON payload
    };

    // ============================================================
    // Run Replay Data
    // ============================================================
    struct RunReplay
    {
        uint32 replayId;
        uint32 instanceId;
        uint32 mapId;
        uint8 keystoneLevel;
        uint64 startTime;
        uint64 endTime;
        bool completed;
        std::string leaderName;
        std::vector<std::string> participants;
        std::deque<ReplayEvent> events;

        void AddEvent(ReplayEventType type, std::string const& data);
        std::string Serialize() const;
        bool Deserialize(std::string const& data);
    };

    // ============================================================
    // Spectator Configuration
    // ============================================================
    struct MythicSpectatorConfig
    {
        bool enabled = true;
        bool allowWhileInProgress = true;
        bool requireSameRealm = false;
        bool announceNewSpectators = true;
        uint32 maxSpectatorsPerRun = 50;
        uint32 updateIntervalMs = 1000;
        uint32 minKeystoneLevel = 2;
        bool allowPublicListing = true;
        bool streamModeEnabled = true;
        uint32 defaultStreamMode = 0;

        // Invite system
        bool inviteLinksEnabled = true;
        uint32 inviteLinkExpireSeconds = 3600;

        // Replay system
        bool replayEnabled = true;
        uint32 replayMaxStoredRuns = 100;
        bool replayRecordPositions = false;  // High bandwidth, disabled by default
        bool replayRecordCombatLog = false;  // Very high storage, disabled by default

        // HUD sync
        bool syncHudToSpectators = true;

        void Load();
    };

    // ============================================================
    // Active Run Info (for listing available runs to spectate)
    // ============================================================
    struct SpectateableRun
    {
        uint32 instanceId;
        uint32 mapId;
        uint8 keystoneLevel;
        uint32 startedAt;
        uint32 timerRemaining;
        uint8 bossesKilled;
        uint8 bossesTotal;
        uint8 deaths;
        std::string leaderName;
        std::vector<std::string> participantNames;
        bool allowsSpectators;
        uint32 streamMode;
        std::unordered_set<ObjectGuid> spectators;

        // Invite system
        std::string inviteCode;
        uint64 inviteCodeExpires;

        // Replay recording
        RunReplay* activeReplay;
    };

    // ============================================================
    // Invite Link Structure
    // ============================================================
    struct SpectatorInvite
    {
        std::string code;
        uint32 instanceId;
        ObjectGuid inviterGuid;
        uint64 createdAt;
        uint64 expiresAt;
        uint32 usesRemaining;  // 0 = unlimited
    };

    // ============================================================
    // Spectator State (per spectating player)
    // ============================================================
    struct SpectatorState
    {
        ObjectGuid spectatorGuid;
        uint32 targetInstanceId;
        uint32 targetMapId;
        ObjectGuid watchingPlayer;
        uint64 joinedAt;
        uint32 streamMode;
        bool isStreamer;
        Position savedPosition;
        uint32 savedMapId;
    };

    // ============================================================
    // Manager Singleton
    // ============================================================
    class MythicSpectatorManager
    {
    public:
        static MythicSpectatorManager& Get();

        // Configuration
        void LoadConfig();
        MythicSpectatorConfig const& GetConfig() const { return _config; }

        // Run Management
        void RegisterActiveRun(uint32 instanceId, uint32 mapId, uint8 keystoneLevel,
                               std::string const& leaderName, bool allowSpectators = true);
        void UnregisterActiveRun(uint32 instanceId);
        void UpdateRunStatus(uint32 instanceId, uint32 timerRemaining, uint8 bossesKilled,
                             uint8 bossesTotal, uint8 deaths);
        void SetRunStreamMode(uint32 instanceId, uint32 mode);

        std::vector<SpectateableRun> GetSpectateableRuns() const;
        SpectateableRun const* GetRun(uint32 instanceId) const;
        SpectateableRun* GetRunMutable(uint32 instanceId);

        // Spectator Control
        bool CanSpectate(Player* player, uint32 instanceId, std::string& error) const;
        bool StartSpectating(Player* player, uint32 instanceId);
        bool StartSpectatingPlayer(Player* spectator, std::string const& targetName);
        bool StartSpectatingByCode(Player* player, std::string const& inviteCode);
        void StopSpectating(Player* player);
        bool IsSpectating(Player* player) const;
        bool WatchPlayer(Player* spectator, Player* target);

        SpectatorState* GetSpectatorState(ObjectGuid guid);
        std::vector<Player*> GetSpectatorsForInstance(uint32 instanceId) const;

        // Invite System
        std::string GenerateInviteCode(Player* player, uint32 instanceId, uint32 uses = 0);
        bool ValidateInviteCode(std::string const& code, uint32& outInstanceId) const;
        void SendInviteLink(Player* sender, Player* recipient, uint32 instanceId);
        void BroadcastInviteToGuild(Player* sender, uint32 instanceId);

        // HUD Sync for Spectators
        void SyncHudToSpectator(Player* spectator, uint32 instanceId);
        void BroadcastHudUpdate(uint32 instanceId, std::unordered_map<uint32, uint32> const& worldStates);

        // Replay System
        void StartRecording(uint32 instanceId);
        void StopRecording(uint32 instanceId, bool save = true);
        void RecordEvent(uint32 instanceId, ReplayEventType type, std::string const& data);
        bool SaveReplay(uint32 instanceId);
        bool LoadReplay(uint32 replayId, RunReplay& outReplay);
        std::vector<std::pair<uint32, std::string>> GetRecentReplays(uint32 limit = 20);
        bool StartReplayPlayback(Player* player, uint32 replayId);
        void StopReplayPlayback(Player* player);

        // Broadcasting
        void BroadcastToSpectators(uint32 instanceId, std::string const& message);
        void BroadcastRunUpdate(uint32 instanceId);
        void SendRunSnapshot(Player* spectator, uint32 instanceId);

        // Protocol helpers
        static void CreatePacket(WorldPacket& data, std::string const& message);
        static std::string FormatRunData(SpectateableRun const& run, uint32 streamMode);
        static std::string GenerateRandomCode(uint32 length);

        // Periodic updates
        void Update(uint32 diff);

    private:
        MythicSpectatorManager() = default;

        void SaveSpectatorPosition(Player* player, SpectatorState& state);
        void RestoreSpectatorPosition(Player* player, SpectatorState const& state);
        void UpdateSpectatorViewpoint(Player* spectator);
        void CleanupExpiredInvites();

        MythicSpectatorConfig _config;
        std::unordered_map<uint32, SpectateableRun> _activeRuns;       // instanceId -> run
        std::unordered_map<ObjectGuid, SpectatorState> _spectators;    // spectator guid -> state
        std::unordered_map<std::string, SpectatorInvite> _inviteCodes; // code -> invite
        std::unordered_map<uint32, RunReplay> _activeReplays;          // instanceId -> recording
        uint32 _updateTimer = 0;
        uint32 _inviteCleanupTimer = 0;
    };

    #define sMythicSpectator DCMythicSpectator::MythicSpectatorManager::Get()

} // namespace DCMythicSpectator

#endif // DC_MYTHIC_SPECTATOR_H
