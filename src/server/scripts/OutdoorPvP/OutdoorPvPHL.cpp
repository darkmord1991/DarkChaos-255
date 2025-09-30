/*
        .__      .___.                
        [__)  .    |   _ ._ _ ._ _   .
        [__)\_|    |  (_)[ | )[ | )\_|
                        ._|                    ._|

                Hinterland BG (OutdoorPvP HL)
                ------------------------------
                Feature summary
                - Participation gate: under-max players are teleported to capitals with a whisper.
                - Join UX: colored welcome + current standing as whispers; no zone broadcast on join.
                - HUD: Wintergrasp-like worldstates (SHOW/context/timer/resources) with periodic refresh so
                    clients always show timer and resource bars in Hinterlands.
                - Match timer: 60-minute window; when the clock reaches 0:00 the battleground auto-resets and
                    restarts (players teleported to faction graveyards, NPCs/GOs respawn, HUD refreshed).
                - Broadcasts: optional zone-wide status every N seconds, branded with a clickable item-link
                    prefix for easy recognition.
                - AFK/deserter policy: deserters get no rewards. AFK warn at 120s, action at 180s; any AFK
                    infraction denies rewards. First AFK teleports to start GY, repeated AFK teleports to capital.
                    GMs are exempt from AFK.
                - Groups: per-faction BG-like raids; prune empties/offline. When raids shrink 2→1, keep the
                    remaining player in a new raid so they don’t lose context.
                - Resets: admin reset and timer-expiry auto-reset respawn GOs/NPCs, refresh HUD/timer, and by
                    default teleport players in-zone to their faction start graveyards.
                - Diagnostics: logs around a ~60s empty-zone period to help verify NPC presence post-emptiness.

                Quick reference
                - Commands (see cs_hl_bg.cpp):
                        .hlbg status  -> show time/resources + raid groups
                        .hlbg get <alliance|horde>
                        .hlbg set <team> <amount>  (GM; audit-logged)
                        .hlbg reset                 (GM; audit-logged)
                - Configuration keys (worldserver.conf or modules configs), with defaults:
                        HinterlandBG.MatchDuration           = 3600
                        HinterlandBG.AFK.WarnSeconds         = 120
                        HinterlandBG.AFK.TeleportSeconds     = 180
                        HinterlandBG.Broadcast.Enabled       = 1
                        HinterlandBG.Broadcast.Period        = 180
                        HinterlandBG.Resources.Alliance      = 450
                        HinterlandBG.Resources.Horde         = 450
                        HinterlandBG.Reward.MatchHonor       = 1500
                        HinterlandBG.Reward.KillItemId       = 40752
                        HinterlandBG.Reward.KillItemCount    = 1
                        HinterlandBG.Reward.NPCTokenItemId   = 40752
                        HinterlandBG.Reward.NPCTokenItemCount= 1
                        HinterlandBG.Reward.KillHonorValues  = "17,11,19,22"
                        HinterlandBG.Reward.NPCEntriesAlliance = ""        # CSV of entry IDs
                        HinterlandBG.Reward.NPCEntriesHorde    = ""
                        HinterlandBG.Reward.NPCEntryCountsAlliance = ""     # CSV of entry:count
                        HinterlandBG.Reward.NPCEntryCountsHorde    = ""
                    Note: if desired, a future toggle could control teleport-on-auto-reset.
*/

/*
        Developer map (split implementation)
        ------------------------------------
        This file holds the core orchestration for Hinterland BG. Many helper
        implementations are split into DC files for clarity and modularity:
            - Config loader:           src/server/scripts/DC/HinterlandBG/OutdoorPvPHL_Config.cpp
            - Rewards & combat:        src/server/scripts/DC/HinterlandBG/OutdoorPvPHL_Rewards.cpp
                                                                    (includes Randomizer and HandleKill)
            - Resets & teleports:      src/server/scripts/DC/HinterlandBG/OutdoorPvPHL_Reset.cpp
            - AFK tracking helper:     src/server/scripts/DC/HinterlandBG/OutdoorPvPHL_AFK.cpp
            - Announcements:           src/server/scripts/DC/HinterlandBG/OutdoorPvPHL_Announce.cpp
            - Raid lifecycle:          src/server/scripts/DC/HinterlandBG/OutdoorPvPHL_Groups.cpp
            - Threshold announcements:  src/server/scripts/DC/HinterlandBG/OutdoorPvPHL_Thresholds.cpp
            - WG-style HUD worldstates: src/server/scripts/DC/HinterlandBG/OutdoorPvPHL_Worldstates.cpp
            - Admin/inspection helpers: src/server/scripts/DC/HinterlandBG/OutdoorPvPHL_Admin.cpp
            - Join/Leave handlers:      src/server/scripts/DC/HinterlandBG/OutdoorPvPHL_JoinLeave.cpp
            - Movement hook (AFK):      src/server/scripts/DC/HinterlandBG/HLMovementHandlerScript.h
            - DC registration wrapper:  src/server/scripts/DC/HinterlandBG/outdoorpvp_hl_registration.cpp

        Tip: Search this file for lines beginning with "moved to DC/HinterlandBG" to
        jump to the corresponding split source.
*/
    #include "OutdoorPvPHL.h"
    #include "Player.h"
    #include "OutdoorPvP.h"
    #include "OutdoorPvPMgr.h"
    #include "World.h"
    #include "WorldPacket.h"
    #include "OutdoorPvPScript.h"
    #include "CreatureScript.h"
    #include "Creature.h"
    #include <unordered_map>
    #include "WorldSession.h"
    #include "WorldSessionMgr.h"
    #include "Chat.h"
    #include "ObjectMgr.h"
    #include "ObjectAccessor.h"
        #include "GameObject.h"
    #include "DBCStores.h"
    #include "Misc/GameGraveyard.h"
    #include "Time/GameTime.h"
    #include "Config.h"
    #include "WorldState.h"
    #include "WeatherMgr.h"
    
    #include "GroupMgr.h"
    #include "MapMgr.h"
    #include "CellImpl.h" // for TypeContainerVisitor over MapStoredObjectTypesContainer
    #include "ScriptDefines/MovementHandlerScript.h"
    #include <algorithm>
    #include <cmath>
    #include <cstdio>
    #include "DC/HinterlandBG/OutdoorPvPHLResetWorker.h"
    #include "DC/HinterlandBG/HLMovementHandlerScript.h"

// HLZoneResetWorker moved to DC/HinterlandBG/OutdoorPvPHLResetWorker.h

    OutdoorPvPHL::OutdoorPvPHL()
    {
        _typeId = OUTDOOR_PVP_HL;
        // Set defaults for configurable values (can be overridden by LoadConfig)
        _matchDurationSeconds = HL_MATCH_DURATION_SECONDS;
        _afkWarnSeconds = 120;
        _afkTeleportSeconds = 180;
    _statusBroadcastEnabled = true;
    _statusBroadcastPeriodMs = 180 * IN_MILLISECONDS;
    _autoResetTeleport = true;
    _expiryUseTiebreaker = true;
        _initialResourcesAlliance = HL_RESOURCES_A;
        _initialResourcesHorde = HL_RESOURCES_H;
        // Default base coordinates
        _baseAlliance = { /*map*/0u, /*x*/62.083f, /*y*/-4714.99f, /*z*/11.7937f, /*o*/2.50765f };
    _baseHorde    = { /*map*/0u, /*x*/-628.484f, /*y*/-4684.51f, /*z*/5.14442f, /*o*/1.12528f };
        _rewardMatchHonor = 1500;
        _rewardMatchHonorDepletion = 1500;
        _rewardMatchHonorTiebreaker = 750;
    _worldAnnounceOnExpiry = true;
    _worldAnnounceOnDepletion = true;
        _killHonorValues = { 17, 11, 19, 22 };
    _rewardKillItemId = 40752;
    _rewardKillItemCount = 1;
    _rewardNpcTokenItemId = 40752; // default to same token as kill item
    _rewardNpcTokenCount = 1;
    _npcRewardEntriesAlliance.clear();
    _npcRewardEntriesHorde.clear();
    _npcRewardCountsAlliance.clear();
    _npcRewardCountsHorde.clear();
    // Default NPC classifications (can be overridden by config)
    _npcBossEntriesAlliance = { Alliance_Boss };
    _npcBossEntriesHorde    = { Horde_Boss };
    _npcNormalEntriesAlliance = { Alliance_Healer, Alliance_Infantry, Alliance_Squadleader };
    _npcNormalEntriesHorde    = { Horde_Heal, Horde_Infantry, Horde_Squadleader };
    // Resource loss defaults
    _resourcesLossPlayerKill = PointsLoseOnPvPKill; // 5
    _resourcesLossNpcNormal = 5;
    _resourcesLossNpcBoss = 200;
        // Load overrides from config if available
        LoadConfig();

        _ally_gathered = _initialResourcesAlliance;
        _horde_gathered = _initialResourcesHorde;
        _LastWin = 0;
        _matchEndTime = 0;
        // Persistence and lock defaults
        _persistenceEnabled = true;
        _lockEnabled = false;
        _lockDurationSeconds = 0;
        _isLocked = false;
        _lockUntilEpoch = 0;
        // Per-kill spell feedback defaults
        _killSpellOnPlayerKillAlliance = 0;
        _killSpellOnPlayerKillHorde = 0;
        _killSpellOnNpcKill = 0;
        // Affix defaults
        _affixEnabled = false;
        _affixWeatherEnabled = false;
        _affixPeriodSec = 0;
        _affixTimerMs = 0;
        _activeAffix = AFFIX_NONE;
    _affixNextChangeEpoch = 0;
        _affixSpellHaste = 0;
        _affixSpellSlow = 0;
        _affixSpellReducedHealing = 0;
        _affixSpellReducedArmor = 0;
        _affixSpellBossEnrage = 0;

        IS_ABLE_TO_SHOW_MESSAGE = false;
        IS_RESOURCE_MESSAGE_A = false;
        IS_RESOURCE_MESSAGE_H = false;

        _FirstLoad = false;

        limit_A = 0;
        limit_H = 0;
        limit_resources_message_A = 0;
        limit_resources_message_H = 0;

        _playersInZone = 0;
        _npcCheckTimerMs = 0;
        _afkCheckTimerMs = 0;
    _hudRefreshTimerMs = 0;
        _statusBroadcastTimerMs = 0;
    _memberOfflineSince.clear();
    _zoneWasEmpty = false;

    }

    OutdoorPvPHL::~OutdoorPvPHL() = default;

    // Basic OutdoorPvP setup: register managed zones and derive the map id from the zone
    bool OutdoorPvPHL::SetupOutdoorPvP()
    {
        for (uint8 i = 0; i < OutdoorPvPHLBuffZonesNum; ++i)
            RegisterZone(OutdoorPvPHLBuffZones[i]);
        SetMapFromZone(OutdoorPvPHLBuffZones[0]);
        // Re-load configuration on setup and restore persisted state if enabled
        LoadConfig();
    if (_persistenceEnabled)
        {
            // Restore state similar to TF: read worldstate keys if present
            uint32 savedAlly = uint32(sWorldState->getWorldState(0xDD0001));
            uint32 savedHorde = uint32(sWorldState->getWorldState(0xDD0002));
            uint32 savedEnd   = uint32(sWorldState->getWorldState(0xDD0003));
            uint32 savedWin   = uint32(sWorldState->getWorldState(0xDD0004));
            uint32 savedLock  = uint32(sWorldState->getWorldState(0xDD0005));
            uint32 savedLockUntil = uint32(sWorldState->getWorldState(0xDD0006));
            uint32 savedAffix      = uint32(sWorldState->getWorldState(0xDD0007));
            uint32 savedAffixEpoch = uint32(sWorldState->getWorldState(0xDD0008));
            if (savedAlly && savedHorde && savedEnd)
            {
                _ally_gathered = savedAlly;
                _horde_gathered = savedHorde;
                _matchEndTime = savedEnd;
                _LastWin = savedWin;
            }
            if (_lockEnabled && savedLockUntil)
            {
                _isLocked = savedLock != 0;
                _lockUntilEpoch = savedLockUntil;
                if (_isLocked && NowSec() >= _lockUntilEpoch)
                {
                    _isLocked = false;
                    _lockUntilEpoch = 0;
                }
            }
            // Restore affix state
            if (_affixEnabled && savedAffix)
            {
                _activeAffix = static_cast<AffixType>(savedAffix);
                _affixNextChangeEpoch = savedAffixEpoch;
                // Set a remaining timer based on epoch
                uint32 now = NowSec();
                if (_affixNextChangeEpoch > now)
                    _affixTimerMs = (_affixNextChangeEpoch - now) * IN_MILLISECONDS;
                else
                    _affixTimerMs = 0; // trigger immediate rotation
            }
        }
        return true;
    }

    // moved to DC/HinterlandBG/OutdoorPvPHL_Worldstates.cpp

    // moved to DC/HinterlandBG/OutdoorPvPHL_Worldstates.cpp

    // moved to DC/HinterlandBG/OutdoorPvPHL_Worldstates.cpp

    // small helper impls
    bool OutdoorPvPHL::IsMaxLevel(Player* player) const
    {
        if (!player)
            return false;
        return player->GetLevel() >= sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL);
    }

    bool OutdoorPvPHL::IsEligibleForRewards(Player* player) const
    {
        if (!player)
            return false;
        // Deserters do not get rewards. AFK denial is handled in reward sites (kills/end) to allow GM exemptions.
        static constexpr uint32 BG_DESERTER_SPELL = 26013; // "Deserter"
        if (player->HasAura(BG_DESERTER_SPELL))
            return false;
        // AFK denial handled separately so we can consider GM mode.
        return true;
    }

    void OutdoorPvPHL::Whisper(Player* player, std::string const& msg) const
    {
        if (!player)
            return;
        if (WorldSession* session = player->GetSession())
        {
            ChatHandler(session).SendSysMessage(msg.c_str());
        }
    }

    uint8 OutdoorPvPHL::GetAfkCount(Player* player) const
    {
        if (!player)
            return 0;
        uint32 low = player->GetGUID().GetCounter();
        auto it = _afkInfractions.find(low);
        if (it == _afkInfractions.end())
            return 0;
        return it->second;
    }

    void OutdoorPvPHL::IncrementAfk(Player* player)
    {
        if (!player)
            return;
        uint32 low = player->GetGUID().GetCounter();
        _afkInfractions[low] = std::min<uint8>(255, GetAfkCount(player) + 1);
    }

    void OutdoorPvPHL::ClearAfkState(Player* player)
    {
        if (!player)
            return;
        uint32 low = player->GetGUID().GetCounter();
        _afkInfractions.erase(low);
        _afkFlagged.erase(low);
    }

    void OutdoorPvPHL::TeleportToCapital(Player* player) const
    {
        if (!player)
            return;
        // Default to Stormwind/Orgrimmar
        if (player->GetTeamId() == TEAM_ALLIANCE)
        {
            // Stormwind: Map 0, approx coords
            player->TeleportTo(0, -8833.38f, 628.628f, 94.0066f, 1.0f);
        }
        else
        {
            // Orgrimmar: Map 1 or 0 depending on core version; use EK map 1 classic ORG? For WotLK: Map 1 -> Kalimdor, coords below
            player->TeleportTo(1, 1633.33f, -4373.33f, 16.0f, 3.1f);
        }
    }

    // --- Admin/inspection helpers moved to DC/HinterlandBG/OutdoorPvPHL_Admin.cpp ---

    

    bool OutdoorPvPHL::AddOrSetPlayerToCorrectBfGroup(Player* plr)
    {
        if (!plr)
            return false;
        if (plr->GetZoneId() != OutdoorPvPHLBuffZones[0])
            return false;
        // If player already in a raid group, nothing to do
        if (Group* g = plr->GetGroup())
        {
            if (g->isRaidGroup())
                return true;
        }
        // Maintain our own list of BG raids per team and enforce capacity
        TeamId tid = plr->GetTeamId();
        // Clean dead groups
        auto& vec = _teamRaidGroups[tid];
        vec.erase(std::remove_if(vec.begin(), vec.end(), [](ObjectGuid gguid)
        {
            Group* g = sGroupMgr->GetGroupByGUID(gguid.GetCounter());
            return !g || !g->isRaidGroup();
        }), vec.end());
        // Find non-full group
        Group* target = nullptr;
        for (ObjectGuid gid : vec)
        {
            Group* g = sGroupMgr->GetGroupByGUID(gid.GetCounter());
            if (g && g->isRaidGroup() && g->GetMembersCount() < MAXRAIDSIZE)
            {
                target = g;
                break;
            }
        }
        if (!target)
        {
            Group* g = new Group();
            if (!g->Create(plr))
            {
                delete g;
                return false;
            }
            g->ConvertToRaid();
                        _rewardKillItemId = 40752; // default to same token as kill item
            _teamRaidGroups[tid].push_back(g->GetGUID());
            return true;
        }
        target->AddMember(plr);
        return true;
    }

    // moved to DC/HinterlandBG/OutdoorPvPHL_JoinLeave.cpp

    // moved to DC/HinterlandBG/OutdoorPvPHL_JoinLeave.cpp

    

    // moved to DC/HinterlandBG/OutdoorPvPHL_Announce.cpp

    void OutdoorPvPHL::PlaySounds(bool side)
    {
        WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
        for (WorldSessionMgr::SessionMap::const_iterator itr = sessionMap.begin(); itr != sessionMap.end(); ++itr)
        {
            for (uint8 i = 0; i < OutdoorPvPHLBuffZonesNum; ++i)
            {
                if(!itr->second || !itr->second->GetPlayer() || !itr->second->GetPlayer()->IsInWorld() || itr->second->GetPlayer()->GetZoneId() != OutdoorPvPHLBuffZones[i])
                    continue;

                if(itr->second->GetPlayer()->GetZoneId() == OutdoorPvPHLBuffZones[i])
                {
                    if(itr->second->GetPlayer()->GetTeamId() == TEAM_ALLIANCE && side == true)
                        itr->second->GetPlayer()->PlayDirectSound(HL_SOUND_ALLIANCE_GOOD, itr->second->GetPlayer());
                    else
                        itr->second->GetPlayer()->PlayDirectSound(HL_SOUND_HORDE_GOOD, itr->second->GetPlayer());
                }
            }
        }
    }

    // Cosmetic: provide a Battleground-like item link prefix for chat/notifications
    // Example: |cff0070dd|Hitem:47241:0:0:0:0:0:0:0:0|h[Hinterland Defence]|h|r
    // Note: Using a harmless vanity item ID for link formatting. Only the text is shown; clicking opens an item tooltip.
    // moved to DC/HinterlandBG/OutdoorPvPHL_Announce.cpp

    

    

    

    // AFK thresholds are configurable via LoadConfig()

    bool OutdoorPvPHL::Update(uint32 diff)
    {
        OutdoorPvP::Update(diff);
        if(_FirstLoad == false)
        {
            if(_LastWin == ALLIANCE) 
                LOG_INFO("misc", "[OutdoorPvPHL]: The battle of Hinterland has started! Last winner: Alliance");
            else if(_LastWin == HORDE) 
                LOG_INFO("misc", "[OutdoorPvPHL]: The battle of Hinterland has started! Last winner: Horde ");
            else if(_LastWin == 0) 
                LOG_INFO("misc", "[OutdoorPvPHL]: The battle of Hinterland has started! There was no winner last time!");

            if (_matchEndTime == 0)
                _matchEndTime = uint32(GameTime::GetGameTime().count()) + _matchDurationSeconds;
            _FirstLoad = true;
            _persistState();
        }

        // 0) While locked, hold interactions except HUD/status; exit early
        if (_tickLock(diff))
            return false;

        // 1) Timer expiry (may reset and consume the tick)
        if (_tickTimerExpiry())
            return false;

        // 2) Housekeeping/diagnostics while running
        _tickEmptyZoneDiagnostics(diff);
        _tickRaidLifecycle();
        _tickAFK(diff);
        _tickHudRefresh(diff);
        _tickStatusBroadcast(diff);
        _tickThresholdAnnouncements();
        // If depletion win scheduled a lock/reset, handle it before affix tick
        if (_pendingLockFromDepletion)
        {
            _pendingLockFromDepletion = false;
            if (_lockEnabled)
            {
                _isLocked = true;
                uint32 dur = _lockDurationDepletionSec ? _lockDurationDepletionSec : (_lockDurationSeconds ? _lockDurationSeconds : 0);
                if (dur > 0)
                    _lockUntilEpoch = NowSec() + dur;
                else
                {
                    // if zero duration configured, clear lock flags
                    _isLocked = false;
                    _lockUntilEpoch = 0;
                }
            }
            if (_autoResetTeleport)
                TeleportPlayersToStart();
            HandleReset();
            if (_isLocked)
                _matchEndTime = 0;
            // Optionally pick a fresh affix for the next battle immediately when not locked
            if (!_isLocked)
            {
                _tickAffix(0);
                UpdateAffixWorldstateAll();
                ApplyAffixWeather();
            }
            _persistState();
            return false;
        }
        _tickAffix(diff);
        _persistState();
        return false;
    }

    bool OutdoorPvPHL::_tickTimerExpiry()
    {
        if (_matchEndTime == 0 || NowSec() < _matchEndTime)
            return false;

        LOG_INFO("misc", "[OutdoorPvPHL]: Match timer expired - resetting Hinterland BG");
        // Optional tiebreaker: declare winner by higher resources (equal => draw) and reward/buff accordingly
        if (_expiryUseTiebreaker)
        {
            TeamId winner = TEAM_NEUTRAL;
            if (_ally_gathered > _horde_gathered)
                winner = TEAM_ALLIANCE;
            else if (_horde_gathered > _ally_gathered)
                winner = TEAM_HORDE;

            if (winner == TEAM_ALLIANCE)
            {
                HandleWinMessage("|cff1e90ffFor the Alliance!|r");
                PlaySounds(true);
            }
            else if (winner == TEAM_HORDE)
            {
                HandleWinMessage("|cffff0000For the HORDE!|r");
                PlaySounds(false);
            }
            else
            {
                if (Map* m = GetMap())
                    m->SendZoneText(OutdoorPvPHLBuffZones[0], (GetBgChatPrefix() + "Time's up — it's a draw!").c_str());
            }

            // Optional global announcement with final scores
            if (_worldAnnounceOnExpiry)
            {
                char announce[200];
                snprintf(announce, sizeof(announce), "[Hinterland BG] Time's up! Final score: Alliance %u — Horde %u%s", (unsigned)_ally_gathered, (unsigned)_horde_gathered, winner==TEAM_ALLIANCE?" (Alliance win)":winner==TEAM_HORDE?" (Horde win)":" (Draw)");
                ChatHandler(nullptr).SendGlobalSysMessage(announce);
            }

            if (winner == TEAM_ALLIANCE || winner == TEAM_HORDE)
            {
                // Reward winning team members in-zone and apply win/lose buffs
                WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
                for (auto const& it : sessionMap)
                {
                    Player* p = it.second ? it.second->GetPlayer() : nullptr;
                    if (!p || !p->IsInWorld() || p->GetZoneId() != OutdoorPvPHLBuffZones[0])
                        continue;
                    bool isWinner = (p->GetTeamId() == winner);
                    // Buffs: winners get WinBuffs, losers get LoseBuffs
                    HandleBuffs(p, !isWinner);
                    // Rewards: only winners and not AFK/Deserter unless GM
                    if (isWinner)
                    {
                        if (IsEligibleForRewards(p))
                        {
                            if (!p->IsGameMaster() && GetAfkCount(p) >= 1)
                                Whisper(p, "|cffff0000AFK penalty: you receive no rewards.|r");
                            else
                                HandleRewards(p, _rewardMatchHonorTiebreaker, true, false, false);
                        }
                    }
                }
            }
        }

        // If lock is enabled, set a lock window now
        if (_lockEnabled)
        {
            _isLocked = true;
            uint32 dur = _lockDurationExpirySec ? _lockDurationExpirySec : _lockDurationSeconds;
            _lockUntilEpoch = NowSec() + dur;
        }

        // Optionally move everyone to start points before respawning NPCs/GOs
        if (_autoResetTeleport)
            TeleportPlayersToStart();
        HandleReset();
        // While locked, freeze the match timer so expiry logic pauses until lock ends
        if (_isLocked)
            _matchEndTime = 0;
        _persistState();
        return true; // consumed this tick
    }

    bool OutdoorPvPHL::_tickLock(uint32 /*diff*/)
    {
        if (!_lockEnabled || !_isLocked)
            return false; // not locked, proceed normally
        uint32 now = NowSec();
        if (_lockUntilEpoch > 0 && now >= _lockUntilEpoch)
        {
            // Lock expired: open the battleground and start a fresh window
            _isLocked = false;
            _lockUntilEpoch = 0;
            // Seed a fresh match timer and refresh HUD; actors were already reset at lock start
            _matchEndTime = NowSec() + _matchDurationSeconds;
            UpdateWorldStatesAllPlayers();
            _persistState();
            return false; // proceed after reset on next tick
        }
        // While locked, keep HUD refreshed and status broadcast running, but do not run other progression ticks
        _tickHudRefresh(1000);
        _tickStatusBroadcast(1000);
        _persistState();
        return true; // signal Update() to early-return while locked
    }

    void OutdoorPvPHL::_tickEmptyZoneDiagnostics(uint32 diff)
    {
        if (_playersInZone == 0 && _npcCheckTimerMs > 0)
        {
            if (diff >= _npcCheckTimerMs)
            {
                _npcCheckTimerMs = 0;
                LOG_INFO("misc", "[OutdoorPvPHL]: Zone empty for ~60s. Check NPC presence on next join (possible 1 min despawn window).");
            }
            else
            {
                _npcCheckTimerMs -= diff;
            }
        }
    }

    // moved to DC/HinterlandBG/OutdoorPvPHL_Groups.cpp

    void OutdoorPvPHL::_tickAFK(uint32 diff)
    {
        // AFK tracking (movement-based + chat /afk): detect transitions and apply policy
        if (_afkCheckTimerMs > diff)
        {
            _afkCheckTimerMs -= diff;
            return;
        }

        _afkCheckTimerMs = 2000;
        WorldSessionMgr::SessionMap const& sessionMap = sWorldSessionMgr->GetAllSessions();
        for (auto const& it : sessionMap)
        {
            Player* p = it.second ? it.second->GetPlayer() : nullptr;
            if (!p || !p->IsInWorld() || p->GetZoneId() != 47)
                continue;
            // Exempt GMs from AFK tracking entirely
            if (p->IsGameMaster())
            {
                ClearAfkState(p);
                continue;
            }
            uint32 low = p->GetGUID().GetCounter();
            bool wasAfk = _afkFlagged.count(low) > 0;
            // movement-based check
            uint32 nowSec = uint32(GameTime::GetGameTime().count());
            auto itLast = _playerLastMove.find(p->GetGUID());
            if (itLast == _playerLastMove.end())
            {
                _playerLastMove[p->GetGUID()] = nowSec;
                _playerWarnedBeforeTeleport[p->GetGUID()] = false;
                _playerLastPos[p->GetGUID()] = p->GetPosition();
            }
            uint32 idleSec = nowSec - _playerLastMove[p->GetGUID()];
            if (idleSec >= _afkTeleportSeconds)
            {
                if (!wasAfk)
                {
                    _afkFlagged.insert(low);
                    IncrementAfk(p);
                    uint8 count = GetAfkCount(p);
                    if (count == 1)
                    {
                        Whisper(p, "|cffff0000AFK detected due to inactivity. You will not receive rewards.|r You'll be moved back to your base.");
                        TeleportToTeamBase(p);
                    }
                    else if (count >= 2)
                    {
                        Whisper(p, "|cffff0000Repeated AFK detected. You will be teleported to your capital and will not receive rewards.|r");
                        TeleportToCapital(p);
                    }
                }
            }
            else if (idleSec >= _afkWarnSeconds)
            {
                if (!_playerWarnedBeforeTeleport[p->GetGUID()])
                {
                    uint32 secondsLeft = (_afkTeleportSeconds > idleSec) ? (_afkTeleportSeconds - idleSec) : 0u;
                    Whisper(p, "You seem AFK. Move now or you'll be teleported in " + std::to_string(secondsLeft) + "s.");
                    _playerWarnedBeforeTeleport[p->GetGUID()] = true;
                }
            }

            // chat-based /afk edge tracking for those who manually toggle (kept for parity)
            bool nowAfkChat = p->isAFK();
            if (nowAfkChat && !wasAfk)
            {
                _afkFlagged.insert(low);
                IncrementAfk(p);
                uint8 count = GetAfkCount(p);
                if (count == 1)
                    Whisper(p, "|cffff0000AFK detected. You will not receive rewards.|r A second AFK will teleport you to your capital.");
                else if (count >= 2)
                {
                    Whisper(p, "|cffff0000Repeated AFK detected. You will be teleported to your capital and will not receive rewards.|r");
                    TeleportToCapital(p);
                }
            }
            else if (!nowAfkChat && wasAfk)
            {
                _afkFlagged.erase(low);
            }
        }
    }

    void OutdoorPvPHL::_tickHudRefresh(uint32 diff)
    {
        if (_playersInZone <= 0)
            return;
        if (_hudRefreshTimerMs <= diff)
        {
            UpdateWorldStatesAllPlayers();
            _hudRefreshTimerMs = 10 * IN_MILLISECONDS;
        }
        else
        {
            _hudRefreshTimerMs -= diff;
        }
    }

    void OutdoorPvPHL::_tickStatusBroadcast(uint32 diff)
    {
        if (_playersInZone <= 0 || !_statusBroadcastEnabled)
            return;
        if (_statusBroadcastTimerMs <= diff)
        {
            BroadcastStatusToZone();
            _statusBroadcastTimerMs = _statusBroadcastPeriodMs;
        }
        else
        {
            _statusBroadcastTimerMs -= diff;
        }
    }

    // moved to DC/HinterlandBG/OutdoorPvPHL_Thresholds.cpp

    // moved to DC/HinterlandBG/OutdoorPvPHL_Announce.cpp
    

    // moved to DC/HinterlandBG/OutdoorPvPHL_Rewards.cpp

    // moved to DC/HinterlandBG/OutdoorPvPHL_Rewards.cpp
    
    class OutdoorPvP_hinterland : public OutdoorPvPScript
    {
        public:
     
        OutdoorPvP_hinterland()
            : OutdoorPvPScript("outdoorpvp_hl") {}
     
        OutdoorPvP* GetOutdoorPvP() const
        {
            return new OutdoorPvPHL();
        }
    };

    // LoadConfig moved to DC/HinterlandBG/OutdoorPvPHL_Config.cpp

    // HLMovementHandlerScript moved to DC/HinterlandBG/HLMovementHandlerScript.h

    void AddSC_outdoorpvp_hl()
    {
        new OutdoorPvP_hinterland;
        new HLMovementHandlerScript();
	}

    // --- Persistence ---
    void OutdoorPvPHL::SaveRequiredWorldStates() const
    {
        // Choose reserved worldstate keys for HLBG persistence (unlikely to collide)
        // 0xDD0001..0xDD0006 are arbitrary private keys.
        sWorldState->setWorldState(0xDD0001, _ally_gathered);
        sWorldState->setWorldState(0xDD0002, _horde_gathered);
        sWorldState->setWorldState(0xDD0003, _matchEndTime);
        sWorldState->setWorldState(0xDD0004, _LastWin);
        sWorldState->setWorldState(0xDD0005, _isLocked ? 1u : 0u);
        sWorldState->setWorldState(0xDD0006, _lockUntilEpoch);
        // Affix persistence
        sWorldState->setWorldState(0xDD0007, static_cast<uint32>(_activeAffix));
        sWorldState->setWorldState(0xDD0008, _affixNextChangeEpoch);
    }

    void OutdoorPvPHL::_persistState() const
    {
        if (_persistenceEnabled)
            SaveRequiredWorldStates();
    }

    // --- Affix system (scaffolding) ---
    void OutdoorPvPHL::_tickAffix(uint32 diff)
    {
        if (!_affixEnabled)
            return;
        if (_lockEnabled && _isLocked)
            return; // pause affix rotation during lock
        if (_affixTimerMs > diff)
        {
            _affixTimerMs -= diff;
            return;
        }
    _affixTimerMs = std::max<uint32>(10, _affixPeriodSec) * IN_MILLISECONDS;
    _affixNextChangeEpoch = NowSec() + std::max<uint32>(10, _affixPeriodSec);
        // Rotate affix randomly
        _clearAffixEffects();
        uint32 roll = urand(1, 5);
        _activeAffix = static_cast<AffixType>(roll);
        _applyAffixEffects();
        ApplyAffixWeather();
        UpdateAffixWorldstateAll();
    }

    // Worker structs for map object traversal (must be non-local to allow member templates)
    namespace {
        struct HL_NpcAuraWorker
        {
            uint32 zone; uint32 spell;
            void Visit(std::unordered_map<ObjectGuid, Creature*>& cmap)
            {
                for (auto const& pr : cmap)
                {
                    Creature* c = pr.second;
                    if (!c || !c->IsInWorld() || c->GetZoneId() != zone)
                        continue;
                    if (c->IsPlayer() || c->IsPet() || c->IsGuardian() || c->IsSummon() || c->IsTotem())
                        continue;
                    c->CastSpell(c, spell, true);
                }
            }
            template<class T>
            void Visit(std::unordered_map<ObjectGuid, T*>&) {}
        };

        struct HL_EnrageWorker
        {
            OutdoorPvPHL* self; uint32 zone;
            void Visit(std::unordered_map<ObjectGuid, Creature*>& cmap)
            {
                for (auto const& p : cmap)
                {
                    Creature* c = p.second;
                    if (!c || !c->IsInWorld() || c->GetZoneId() != zone)
                        continue;
                    uint32 entry = c->GetEntry();
                    if (self->_npcBossEntriesAlliance.count(entry) || self->_npcBossEntriesHorde.count(entry))
                        c->CastSpell(c, self->_affixSpellBossEnrage, true);
                }
            }
            template<class T>
            void Visit(std::unordered_map<ObjectGuid, T*>&) {}
        };

        struct HL_ClearEnrageWorker
        {
            OutdoorPvPHL* self; uint32 zone;
            void Visit(std::unordered_map<ObjectGuid, Creature*>& cmap)
            {
                for (auto const& p : cmap)
                {
                    Creature* c = p.second;
                    if (!c || !c->IsInWorld() || c->GetZoneId() != zone)
                        continue;
                    uint32 entry = c->GetEntry();
                    if (self->_npcBossEntriesAlliance.count(entry) || self->_npcBossEntriesHorde.count(entry))
                        c->RemoveAurasDueToSpell(self->_affixSpellBossEnrage);
                }
            }
            template<class T>
            void Visit(std::unordered_map<ObjectGuid, T*>&) {}
        };

        struct HL_ClearNpcBuffWorker
        {
            OutdoorPvPHL* self; uint32 zone;
            void Visit(std::unordered_map<ObjectGuid, Creature*>& cmap)
            {
                for (auto const& p : cmap)
                {
                    Creature* c = p.second;
                    if (!c || !c->IsInWorld() || c->GetZoneId() != zone)
                        continue;
                    if (c->IsPlayer() || c->IsPet() || c->IsGuardian() || c->IsSummon() || c->IsTotem())
                        continue;
                    c->RemoveAurasDueToSpell(self->_affixSpellBadWeatherNpcBuff);
                }
            }
            template<class T>
            void Visit(std::unordered_map<ObjectGuid, T*>&) {}
        };
    }

    void OutdoorPvPHL::_applyAffixEffects()
    {
        // Apply team-wide aura effects depending on affix
        auto applyAuraAll = [&](uint32 spellId)
        {
            if (!spellId)
                return;
            ForEachPlayerInZone([&](Player* p){ p->CastSpell(p, spellId, true); });
        };
        auto applyNpcAuraAll = [&](uint32 spellId)
        {
            if (!spellId)
                return;
            uint32 const zoneId = OutdoorPvPHLBuffZones[0];
            if (Map* map = GetMap())
            {
                uint32 mapId = map->GetId();
                HL_NpcAuraWorker worker{ zoneId, spellId };
                sMapMgr->DoForAllMapsWithMapId(mapId, [&worker](Map* m)
                {
                    TypeContainerVisitor<HL_NpcAuraWorker, MapStoredObjectTypesContainer> v(worker);
                    v.Visit(m->GetObjectsStore());
                });
            }
        };
        auto enrageBosses = [&]()
        {
            if (_affixSpellBossEnrage == 0)
                return;
            uint32 const zoneId = OutdoorPvPHLBuffZones[0];
            if (Map* map = GetMap())
            {
                uint32 mapId = map->GetId();
                HL_EnrageWorker worker{ this, zoneId };
                sMapMgr->DoForAllMapsWithMapId(mapId, [&worker](Map* m)
                {
                    TypeContainerVisitor<HL_EnrageWorker, MapStoredObjectTypesContainer> v(worker);
                    v.Visit(m->GetObjectsStore());
                });
            }
        };
        // Player auras
        if (uint32 pspell = GetPlayerSpellForAffix(_activeAffix))
            applyAuraAll(pspell);
        // NPC auras
        if (uint32 nspell = GetNpcSpellForAffix(_activeAffix))
        {
            if (_activeAffix == AFFIX_BOSS_ENRAGE)
                enrageBosses();
            else
                applyNpcAuraAll(nspell);
        }
        // For "bad" affixes, give NPCs a buff (or debuff players handled above). This keeps it in sync with weather.
        // Optional: zone announce affix
        if (_affixAnnounce)
        {
            const char* aff = "Unknown"; // label only for text
            switch (_activeAffix) { case AFFIX_HASTE_BUFF: aff = "Haste"; break; case AFFIX_SLOW: aff = "Slow"; break; case AFFIX_REDUCED_HEALING: aff = "Reduced Healing"; break; case AFFIX_REDUCED_ARMOR: aff = "Reduced Armor"; break; case AFFIX_BOSS_ENRAGE: aff = "Boss Enrage"; break; default: break; }
            char line[128];
            snprintf(line, sizeof(line), "[Hinterland BG] Affix active: %s", aff);
            if (Map* m = GetMap())
                m->SendZoneText(OutdoorPvPHLBuffZones[0], line);
        }
    }

    void OutdoorPvPHL::_clearAffixEffects()
    {
        auto removeAuraAll = [&](uint32 spellId)
        {
            if (!spellId)
                return;
            ForEachPlayerInZone([&](Player* p){ p->RemoveAurasDueToSpell(spellId); });
        };
        removeAuraAll(_affixSpellHaste);
        removeAuraAll(_affixSpellSlow);
        removeAuraAll(_affixSpellReducedHealing);
        removeAuraAll(_affixSpellReducedArmor);
        // Clear enrage from boss NPCs if any: iterate zone creatures
        if (_affixSpellBossEnrage)
        {
            uint32 const zoneId = OutdoorPvPHLBuffZones[0];
            if (Map* map = GetMap())
            {
                uint32 mapId = map->GetId();
                HL_ClearEnrageWorker worker{ this, zoneId };
                sMapMgr->DoForAllMapsWithMapId(mapId, [&worker](Map* m)
                {
                    TypeContainerVisitor<HL_ClearEnrageWorker, MapStoredObjectTypesContainer> v(worker);
                    v.Visit(m->GetObjectsStore());
                });
            }
        }
        // Clear NPC bad-weather buff
        if (_affixSpellBadWeatherNpcBuff)
        {
            uint32 const zoneId = OutdoorPvPHLBuffZones[0];
            if (Map* map = GetMap())
            {
                uint32 mapId = map->GetId();
                HL_ClearNpcBuffWorker worker{ this, zoneId };
                sMapMgr->DoForAllMapsWithMapId(mapId, [&worker](Map* m)
                {
                    TypeContainerVisitor<HL_ClearNpcBuffWorker, MapStoredObjectTypesContainer> v(worker);
                    v.Visit(m->GetObjectsStore());
                });
            }
        }
    }

    void OutdoorPvPHL::_setAffixWeather()
    {
        // Simple weather mapping per affix for ambience (optional)
        // Note: Weather API availability may vary; keep minimal.
        // 0: Fine, 1: Rain, 2: Snow, 3: Storm (example codes)
        uint32 weather = 0;
        switch (_activeAffix)
        {
            case AFFIX_HASTE_BUFF: weather = 0; break;
            case AFFIX_SLOW: weather = 1; break;
            case AFFIX_REDUCED_HEALING: weather = 3; break;
            case AFFIX_REDUCED_ARMOR: weather = 2; break;
            case AFFIX_BOSS_ENRAGE: weather = 3; break;
            default: weather = 0; break;
        }
        uint32 const zoneId = OutdoorPvPHLBuffZones[0];
        ForEachPlayerInZone([&](Player* p)
        {
            if (Map* m = p->GetMap())
                if (Weather* w = m->GetOrGenerateZoneDefaultWeather(zoneId))
                    w->SetWeather(static_cast<WeatherType>(weather), 0.5f);
        });
    }
