/*
 * Giant Isles - Temple of Atal'Hakkar (dungeon copy under the island temple)
 * ==========================================================================
 * Map 109's instance script drives the stock dungeon through InstanceScript
 * data. The copy lives on the open-world map 1405 (world = map 109 position
 * + (6767, 985, -100)), so this file ports the same rules:
 *  - while all six troll defenders are dead the forcefield is down and the
 *    Atal'ai behind it (and Jammal'an) can be attacked;
 *  - Jammal'an's death makes Eranikus attackable and brings Weaver and
 *    Dreamscythe into phase; Eranikus entering combat pulls the dragonkin;
 *  - the statue puzzle: the statues must be used in order (the Altar of
 *    Hakkar shows it), a wrong statue punishes, the sixth raises the Idol of
 *    Hakkar and wakes Atal'alarion;
 *  - the Hakkar ritual, started at the Altar of the Soulflayer (the classic
 *    Egg of Hakkar is not a level-80 item): the Shade of Hakkar's own SmartAI
 *    runs the waves and the Eternal Flames; this script closes the doors
 *    while it runs and resets the room when it ends.
 * Nothing is persisted: defender / boss state is read back from respawn
 * timers every second, so it survives grid unloads and restarts, and an empty
 * dungeon resets the puzzle and the ritual after a while.
 * ==========================================================================
 */

#include "Chat.h"
#include "Creature.h"
#include "CreatureAI.h"
#include "GameObject.h"
#include "GameTime.h"
#include "Log.h"
#include "Map.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedGossip.h"
#include "TemporarySummon.h"
#include "WorldSession.h"

#include <array>
#include <vector>

namespace
{
    constexpr uint32 MAP_ISLES_OF_GIANTS = 1405;

    enum SunkenTempleCopyCreatures : uint32
    {
        NPC_HIGH_PRIEST             = 400502,   // Risen Atal'ai Priest (5273)
        NPC_ZULKAR                  = 400510,   // defender, clone of Gasher
        NPC_MAZRA                   = 400511,   // defender, clone of Hukku
        NPC_ZOLO                    = 400512,
        NPC_MIJAN                   = 400513,
        NPC_ATALALARION             = 400520,
        NPC_JAMMALAN                = 400521,
        NPC_AVATAR_OF_HAKKAR        = 400522,
        NPC_ERANIKUS                = 400523,
        NPC_LORO                    = 400530,
        NPC_ZULLOR                  = 400531,
        NPC_DEATHWALKER             = 400535,
        NPC_SCALEBANE               = 400536,
        NPC_WYRMKIN                 = 400537,
        NPC_WANDERER                = 400538,
        NPC_OGOM                    = 400541,
        NPC_MORPHAZ                 = 400542,
        NPC_WEAVER                  = 400543,
        NPC_DREAMSCYTHE             = 400544,
        NPC_HAZZAS                  = 400545,
        NPC_NIGHTMARE_WHELP         = 400548,
        NPC_SHADE_OF_HAKKAR         = 400550,
    };

    enum SunkenTempleCopyObjects : uint32
    {
        GO_ETERNAL_FLAME_1          = 700018,   // .. 700021
        GO_ATALAI_STATUE_1          = 700022,   // .. 700027, in puzzle order
        GO_HAKKAR_DOOR_1            = 700029,
        GO_HAKKAR_DOOR_2            = 700030,
        GO_SOULFLAYER_ALTAR         = 700034,
        GO_IDOL_OF_HAKKAR           = 148838,
        GO_ATALAI_LIGHT             = 148937,
        GO_FORCEFIELD               = 149431,
    };

    enum SunkenTempleCopySpells : uint32
    {
        SPELL_ATALAI_POISON         = 18949,
        SPELL_DARK_ENERGY           = 18948,
        SPELL_FLAME_OF_HAKKAR       = 12354,
    };

    enum SunkenTempleCopyTexts : uint8
    {
        SAY_JAMMALAN_SHIELD_DOWN    = 0,
        SAY_ATALALARION_RISES       = 0,
        SAY_DREAMSCYTHE_DESCENDS    = 1,
    };

    constexpr uint8 STATUE_COUNT = 6;
    constexpr uint8 FLAME_COUNT = 4;
    constexpr uint32 PHASE_DORMANT = 2;                   // spawn phase of Atal'alarion, Weaver and Dreamscythe
    constexpr uint32 POLL_INTERVAL_MS = 1000;
    constexpr uint32 EMPTY_RESET_MS = 10 * MINUTE * IN_MILLISECONDS;
    constexpr uint32 RITUAL_REARM_MS = 10 * MINUTE * IN_MILLISECONDS;
    constexpr float AVATAR_SEARCH_RANGE = 120.0f;
    constexpr float DRAGONKIN_PULL_RANGE = 300.0f;

    // Wrong statue: the stock spell of that statue; the damage ones are scaled to level 80
    struct StatuePunishment
    {
        uint32 spellId;
        int32 basePoints;                                 // 0 = cast unchanged
    };

    std::array<StatuePunishment, STATUE_COUNT> const StatuePunishments =
    { {
        { SPELL_ATALAI_POISON, 800 },
        { SPELL_DARK_ENERGY, 0 },
        { SPELL_FLAME_OF_HAKKAR, 5000 },
        { SPELL_ATALAI_POISON, 800 },
        { SPELL_DARK_ENERGY, 0 },
        { SPELL_FLAME_OF_HAKKAR, 5000 },
    } };

    // Map 109 positions + (6767, 985, -100)
    Position const ShadeOfHakkarPos = { 6300.205f, 1257.863f, -190.447f, 1.57f };
    Position const IdolOfHakkarPos = { 6290.7307f, 1079.4120f, -289.72966f, 1.5882487f };
    std::array<float, 4> const IdolOfHakkarRotation = { 0.0f, 0.0f, 0.71325016f, 0.70090955f };

    // Footprint of the copy (the island surface above is far higher than the max Z)
    bool IsInsideTemple(WorldObject const* obj)
    {
        return obj->GetPositionX() > 6058.0f && obj->GetPositionX() < 6522.5f
            && obj->GetPositionY() > 851.0f && obj->GetPositionY() < 1309.5f
            && obj->GetPositionZ() > -295.0f && obj->GetPositionZ() < -105.0f;
    }

    bool IsDefender(uint32 entry)
    {
        switch (entry)
        {
            case NPC_ZULKAR:
            case NPC_MAZRA:
            case NPC_ZOLO:
            case NPC_MIJAN:
            case NPC_LORO:
            case NPC_ZULLOR:
                return true;
            default:
                return false;
        }
    }

    // Behind the forcefield: immune to players until every defender is dead
    bool IsWarded(uint32 entry)
    {
        return entry == NPC_HIGH_PRIEST || entry == NPC_DEATHWALKER || entry == NPC_OGOM || entry == NPC_JAMMALAN;
    }

    bool IsDragonkin(uint32 entry)
    {
        switch (entry)
        {
            case NPC_SCALEBANE:
            case NPC_WYRMKIN:
            case NPC_WANDERER:
            case NPC_MORPHAZ:
            case NPC_WEAVER:
            case NPC_DREAMSCYTHE:
            case NPC_HAZZAS:
            case NPC_NIGHTMARE_WHELP:
                return true;
            default:
                return false;
        }
    }

    enum class HakkarRitual : uint8
    {
        Idle,
        ShadeAwake,
        AvatarAwake,
        Defeated
    };

    class giant_isles_sunken_temple : public WorldMapScript
    {
    public:
        giant_isles_sunken_temple() : WorldMapScript("giant_isles_sunken_temple", MAP_ISLES_OF_GIANTS)
        {
            _instance = this;
        }

        ~giant_isles_sunken_temple() override
        {
            if (_instance == this)
                _instance = nullptr;
        }

        static giant_isles_sunken_temple* Get() { return _instance; }

        void OnCreate(Map* /*map*/) override
        {
            ResetRuntime();
        }

        void OnDestroy(Map* /*map*/) override
        {
            ResetRuntime();
        }

        void OnUpdate(Map* map, uint32 diff) override
        {
            if (!map || map->GetId() != MAP_ISLES_OF_GIANTS)
                return;

            _pollTimer += diff;
            if (_pollTimer < POLL_INTERVAL_MS)
                return;

            uint32 const elapsed = _pollTimer;
            _pollTimer = 0;

            if (!_indexed)
                IndexSpawns();

            UpdateOccupancy(map, elapsed);
            UpdateForcefield(map);
            UpdateProphet(map);
            UpdateEranikusPull(map);
            UpdatePuzzle(map);
            UpdateRitual(map, elapsed);
        }

        void OnStatueUsed(Player* player, GameObject* statue)
        {
            uint8 const index = uint8(statue->GetEntry() - GO_ATALAI_STATUE_1);
            if (index >= STATUE_COUNT || index < _statuePhase)
                return;

            if (index != _statuePhase)
            {
                Punish(player, statue, StatuePunishments[index]);
                return;
            }

            statue->UseDoorOrButton(0, false, player);
            statue->SetGameObjectFlag(GO_FLAG_INTERACT_COND);
            LightStatue(statue);
            ++_statuePhase;

            if (_statuePhase == STATUE_COUNT)
            {
                RaiseIdol(statue->GetMap());
                LOG_INFO("scripts.dc", "Giant Isles Sunken Temple: statue puzzle solved by {}", player->GetName());
            }
        }

        void OnRitualAltarUsed(Player* player, GameObject* altar)
        {
            ChatHandler handler(player->GetSession());
            switch (_ritual)
            {
                case HakkarRitual::ShadeAwake:
                case HakkarRitual::AvatarAwake:
                    handler.SendSysMessage("The ritual is already underway.");
                    return;
                case HakkarRitual::Defeated:
                    handler.SendSysMessage("The Soulflayer's essence is still scattered. The altar lies dormant.");
                    return;
                default:
                    break;
            }

            TempSummon* shade = altar->GetMap()->SummonCreature(NPC_SHADE_OF_HAKKAR, ShadeOfHakkarPos);
            if (!shade)
            {
                LOG_ERROR("scripts.dc", "Giant Isles Sunken Temple: Shade of Hakkar {} could not be summoned",
                    static_cast<uint32>(NPC_SHADE_OF_HAKKAR));
                return;
            }

            shade->SetTempSummonType(TEMPSUMMON_MANUAL_DESPAWN);
            _shadeGuid = shade->GetGUID();
            _avatarGuid.Clear();
            _ritual = HakkarRitual::ShadeAwake;
            SetRitualRoom(altar->GetMap(), true);
            LOG_INFO("scripts.dc", "Giant Isles Sunken Temple: Hakkar ritual started by {}", player->GetName());
        }

    private:
        static inline giant_isles_sunken_temple* _instance = nullptr;

        // ---- spawn index (static DB spawns; looked up by spawn id every poll) ------------------
        void IndexSpawns()
        {
            _defenders.clear();
            _warded.clear();
            _dragonkin.clear();
            for (auto const& [spawnId, data] : sObjectMgr->GetAllCreatureData())
            {
                if (data.mapid != MAP_ISLES_OF_GIANTS)
                    continue;

                if (IsDefender(data.id))
                    _defenders.push_back(spawnId);
                if (IsWarded(data.id))
                    _warded.push_back(spawnId);
                if (IsDragonkin(data.id))
                    _dragonkin.push_back(spawnId);

                switch (data.id)
                {
                    case NPC_ATALALARION:
                        _atalalarion = spawnId;
                        break;
                    case NPC_JAMMALAN:
                        _jammalan = spawnId;
                        break;
                    case NPC_ERANIKUS:
                        _eranikus = spawnId;
                        break;
                    case NPC_WEAVER:
                        _weaver = spawnId;
                        break;
                    case NPC_DREAMSCYTHE:
                        _dreamscythe = spawnId;
                        break;
                    default:
                        break;
                }
            }

            for (auto const& [spawnId, data] : sObjectMgr->GetAllGOData())
            {
                if (data.mapid != MAP_ISLES_OF_GIANTS)
                    continue;

                if (data.id >= GO_ATALAI_STATUE_1 && data.id < GO_ATALAI_STATUE_1 + STATUE_COUNT)
                    _statues[data.id - GO_ATALAI_STATUE_1] = spawnId;
                else if (data.id >= GO_ETERNAL_FLAME_1 && data.id < GO_ETERNAL_FLAME_1 + FLAME_COUNT)
                    _flames[data.id - GO_ETERNAL_FLAME_1] = spawnId;
                else if (data.id == GO_HAKKAR_DOOR_1)
                    _doors[0] = spawnId;
                else if (data.id == GO_HAKKAR_DOOR_2)
                    _doors[1] = spawnId;
                else if (data.id == GO_SOULFLAYER_ALTAR)
                    _ritualAltar = spawnId;
                else if (data.id == GO_FORCEFIELD)
                    _forcefield = spawnId;
            }

            _indexed = true;
            LOG_INFO("scripts.dc", "Giant Isles Sunken Temple: {} defenders, {} warded, {} dragonkin, prophet {}, "
                "eranikus {}, atal'alarion {}, forcefield {}, ritual altar {}", _defenders.size(), _warded.size(),
                _dragonkin.size(), _jammalan, _eranikus, _atalalarion, _forcefield, _ritualAltar);
        }

        static Creature* FindCreature(Map* map, ObjectGuid::LowType spawnId)
        {
            if (!spawnId)
                return nullptr;

            auto const bounds = map->GetCreatureBySpawnIdStore().equal_range(spawnId);
            for (auto itr = bounds.first; itr != bounds.second; ++itr)
                if (itr->second->IsInWorld())
                    return itr->second;

            return nullptr;
        }

        static GameObject* FindGameObject(Map* map, ObjectGuid::LowType spawnId)
        {
            if (!spawnId)
                return nullptr;

            auto const bounds = map->GetGameObjectBySpawnIdStore().equal_range(spawnId);
            for (auto itr = bounds.first; itr != bounds.second; ++itr)
                if (itr->second->IsInWorld())
                    return itr->second;

            return nullptr;
        }

        // Dead = loaded corpse, or not loaded and waiting for its respawn timer
        static bool IsSpawnDead(Map* map, ObjectGuid::LowType spawnId)
        {
            if (Creature* creature = FindCreature(map, spawnId))
                return !creature->IsAlive();

            return map->GetCreatureRespawnTime(spawnId) > GameTime::GetGameTime().count();
        }

        static void SetGoState(GameObject* go, GOState state)
        {
            if (go && go->GetGoState() != state)
                go->SetGoState(state);
        }

        // ---- occupancy -------------------------------------------------------------------------------
        void UpdateOccupancy(Map* map, uint32 elapsed)
        {
            Map::PlayerList const& players = map->GetPlayers();
            for (Map::PlayerList::const_iterator itr = players.begin(); itr != players.end(); ++itr)
            {
                if (Player* player = itr->GetSource())
                {
                    if (IsInsideTemple(player))
                    {
                        _emptyMs = 0;
                        return;
                    }
                }
            }

            _emptyMs += elapsed;
            if (_emptyMs < EMPTY_RESET_MS)
                return;

            _emptyMs = 0;
            if (_statuePhase)
                ResetPuzzle(map);
            if (_ritual == HakkarRitual::ShadeAwake || _ritual == HakkarRitual::AvatarAwake)
                EndRitual(map, HakkarRitual::Idle);
        }

        // ---- six defenders -> forcefield ---------------------------------------------------------------
        void UpdateForcefield(Map* map)
        {
            if (_defenders.empty())
                return;

            std::size_t dead = 0;
            for (ObjectGuid::LowType spawnId : _defenders)
                if (IsSpawnDead(map, spawnId))
                    ++dead;

            if (dead == _defenders.size() && !_forcefieldOpen)
            {
                _forcefieldOpen = true;
                if (Creature* jammalan = FindCreature(map, _jammalan))
                    if (jammalan->IsAlive() && jammalan->IsAIEnabled)
                        jammalan->AI()->Talk(SAY_JAMMALAN_SHIELD_DOWN);
            }
            else if (dead == 0 && _forcefieldOpen)        // only when every defender is back, so nobody is shut in
                _forcefieldOpen = false;

            SetGoState(FindGameObject(map, _forcefield), _forcefieldOpen ? GO_STATE_ACTIVE : GO_STATE_READY);

            for (ObjectGuid::LowType spawnId : _warded)
            {
                Creature* creature = FindCreature(map, spawnId);
                if (!creature || !creature->IsAlive())
                    continue;

                if (_forcefieldOpen)
                {
                    if (creature->HasUnitFlag(UNIT_FLAG_IMMUNE_TO_PC))
                        creature->RemoveUnitFlag(UNIT_FLAG_IMMUNE_TO_PC);
                }
                else if (!creature->IsInCombat() && !creature->HasUnitFlag(UNIT_FLAG_IMMUNE_TO_PC))
                    creature->SetUnitFlag(UNIT_FLAG_IMMUNE_TO_PC);
            }
        }

        // ---- Jammal'an -> Eranikus, Weaver, Dreamscythe -------------------------------------------------
        void UpdateProphet(Map* map)
        {
            bool const prophetDead = _jammalan && IsSpawnDead(map, _jammalan);
            UnitFlags const shadeFlags = UNIT_FLAG_NOT_SELECTABLE | UNIT_FLAG_IMMUNE_TO_PC | UNIT_FLAG_IMMUNE_TO_NPC;

            if (Creature* eranikus = FindCreature(map, _eranikus))
            {
                if (eranikus->IsAlive())
                {
                    if (prophetDead)
                    {
                        if (eranikus->HasUnitFlag(UNIT_FLAG_NOT_SELECTABLE))
                            eranikus->RemoveUnitFlag(shadeFlags);
                    }
                    else if (!eranikus->IsInCombat() && !eranikus->HasUnitFlag(UNIT_FLAG_NOT_SELECTABLE))
                        eranikus->SetUnitFlag(shadeFlags);
                }
            }

            for (ObjectGuid::LowType spawnId : { _weaver, _dreamscythe })
            {
                Creature* dragon = FindCreature(map, spawnId);
                if (!dragon || !dragon->IsAlive())
                    continue;

                if (prophetDead && dragon->GetPhaseMask() != PHASEMASK_NORMAL)
                {
                    dragon->SetPhaseMask(PHASEMASK_NORMAL, true);
                    if (spawnId == _dreamscythe && dragon->IsAIEnabled)
                        dragon->AI()->Talk(SAY_DREAMSCYTHE_DESCENDS);
                }
                else if (!prophetDead && !dragon->IsInCombat() && dragon->GetPhaseMask() == PHASEMASK_NORMAL)
                    dragon->SetPhaseMask(PHASE_DORMANT, true);
            }
        }

        // ---- Eranikus calls his children (DoZoneInCombat is dungeon-only) --------------------------------
        void UpdateEranikusPull(Map* map)
        {
            Creature* eranikus = FindCreature(map, _eranikus);
            if (!eranikus || !eranikus->IsAlive() || !eranikus->IsInCombat())
            {
                _eranikusEngaged = false;
                return;
            }

            if (_eranikusEngaged)
                return;

            Unit* target = eranikus->GetVictim();
            if (!target || !target->IsPlayer())
                return;

            _eranikusEngaged = true;
            for (ObjectGuid::LowType spawnId : _dragonkin)
            {
                Creature* dragonkin = FindCreature(map, spawnId);
                if (!dragonkin || !dragonkin->IsAlive() || dragonkin->IsInCombat() || !dragonkin->IsAIEnabled)
                    continue;

                if (!dragonkin->InSamePhase(target) || !dragonkin->IsWithinDist(eranikus, DRAGONKIN_PULL_RANGE))
                    continue;

                dragonkin->EngageWithTarget(target);
                dragonkin->AI()->AttackStart(target);
            }
        }

        // ---- statue puzzle -> Idol of Hakkar + Atal'alarion ---------------------------------------------
        void Punish(Player* player, GameObject* statue, StatuePunishment const& punishment)
        {
            if (!punishment.basePoints)
            {
                statue->CastSpell(player, punishment.spellId);
                return;
            }

            Creature* trigger = statue->SummonTrigger(statue->GetPositionX(), statue->GetPositionY(),
                statue->GetPositionZ(), 0.0f, 3000);
            if (!trigger)
                return;

            trigger->SetLevel(player->GetLevel(), false);
            trigger->SetFaction(FACTION_MONSTER);
            trigger->CastCustomSpell(player, punishment.spellId, &punishment.basePoints, nullptr, nullptr, true);
        }

        void LightStatue(GameObject* statue)
        {
            uint8 const index = uint8(statue->GetEntry() - GO_ATALAI_STATUE_1);
            if (index >= STATUE_COUNT)
                return;

            if (GameObject* light = statue->GetMap()->SummonGameObject(GO_ATALAI_LIGHT, statue->GetPositionX(),
                statue->GetPositionY(), statue->GetPositionZ(), 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0))
                _lights[index] = light->GetGUID();
        }

        void RaiseIdol(Map* map)
        {
            // never load a grid from here; an unloaded pit gets its idol back when someone returns
            if (map->GetGameObject(_idolGuid)
                || !map->IsGridLoaded(IdolOfHakkarPos.GetPositionX(), IdolOfHakkarPos.GetPositionY()))
                return;

            if (GameObject* idol = map->SummonGameObject(GO_IDOL_OF_HAKKAR, IdolOfHakkarPos.GetPositionX(),
                IdolOfHakkarPos.GetPositionY(), IdolOfHakkarPos.GetPositionZ(), IdolOfHakkarPos.GetOrientation(),
                IdolOfHakkarRotation[0], IdolOfHakkarRotation[1], IdolOfHakkarRotation[2], IdolOfHakkarRotation[3], 0))
            {
                _idolGuid = idol->GetGUID();
                // stays untouchable until Atal'alarion is slain (his SmartAI clears the flag on death)
                if (_atalalarionSlain)
                    idol->RemoveGameObjectFlag(GO_FLAG_INTERACT_COND);
            }
        }

        void ResetPuzzle(Map* map)
        {
            _statuePhase = 0;
            _atalalarionSlain = false;
            for (ObjectGuid& lightGuid : _lights)
            {
                if (GameObject* light = map->GetGameObject(lightGuid))
                    light->DespawnOrUnsummon();
                lightGuid.Clear();
            }

            if (GameObject* idol = map->GetGameObject(_idolGuid))
                idol->DespawnOrUnsummon();
            _idolGuid.Clear();

            for (ObjectGuid::LowType spawnId : _statues)
                if (GameObject* statue = FindGameObject(map, spawnId))
                    statue->RemoveGameObjectFlag(GO_FLAG_INTERACT_COND);

            LOG_DEBUG("scripts.dc", "Giant Isles Sunken Temple: statue puzzle reset");
        }

        void UpdatePuzzle(Map* map)
        {
            Creature* atalalarion = FindCreature(map, _atalalarion);
            if (_statuePhase >= STATUE_COUNT)
            {
                if (atalalarion)
                {
                    if (!atalalarion->IsAlive())
                        _atalalarionSlain = true;
                    else if (_atalalarionSlain)
                    {
                        ResetPuzzle(map);                 // he respawned: the next group starts over
                        return;
                    }
                    else if (atalalarion->GetPhaseMask() != PHASEMASK_NORMAL)
                    {
                        atalalarion->SetPhaseMask(PHASEMASK_NORMAL, true);
                        if (atalalarion->IsAIEnabled)
                            atalalarion->AI()->Talk(SAY_ATALALARION_RISES);
                    }
                }
                else if (_atalalarion && IsSpawnDead(map, _atalalarion))
                    _atalalarionSlain = true;

                RaiseIdol(map);                           // a grid reload removes summoned objects
            }
            else if (atalalarion && atalalarion->IsAlive() && !atalalarion->IsInCombat()
                && atalalarion->GetPhaseMask() == PHASEMASK_NORMAL)
                atalalarion->SetPhaseMask(PHASE_DORMANT, true);

            for (uint8 i = 0; i < STATUE_COUNT; ++i)
            {
                GameObject* statue = FindGameObject(map, _statues[i]);
                if (!statue)
                    continue;

                bool const lit = i < _statuePhase;
                if (lit && !statue->HasGameObjectFlag(GO_FLAG_INTERACT_COND))
                    statue->SetGameObjectFlag(GO_FLAG_INTERACT_COND);
                else if (!lit && statue->HasGameObjectFlag(GO_FLAG_INTERACT_COND))
                    statue->RemoveGameObjectFlag(GO_FLAG_INTERACT_COND);

                if (lit && !map->GetGameObject(_lights[i]))
                    LightStatue(statue);
            }
        }

        // ---- Hakkar ritual ------------------------------------------------------------------------------
        // Doors shut while the Shade or the Avatar is up; flames burn while idle, die out once Hakkar falls
        void SetRitualRoom(Map* map, bool sealed)
        {
            for (ObjectGuid::LowType spawnId : _doors)
                SetGoState(FindGameObject(map, spawnId), sealed ? GO_STATE_READY : GO_STATE_ACTIVE);
        }

        void SetFlames(Map* map, bool extinguished)
        {
            for (ObjectGuid::LowType spawnId : _flames)
            {
                GameObject* flame = FindGameObject(map, spawnId);
                if (!flame)
                    continue;

                if (extinguished)
                    SetGoState(flame, GO_STATE_ACTIVE);
                else if (flame->GetGoState() != GO_STATE_READY)
                    flame->ResetDoorOrButton();
            }
        }

        void EndRitual(Map* map, HakkarRitual result)
        {
            if (Creature* shade = map->GetCreature(_shadeGuid))
                shade->DespawnOrUnsummon();
            if (result != HakkarRitual::Defeated)
                if (Creature* avatar = map->GetCreature(_avatarGuid))
                    avatar->DespawnOrUnsummon();

            _shadeGuid.Clear();
            _avatarGuid.Clear();
            _ritual = result;
            _ritualRearmMs = RITUAL_REARM_MS;
            SetRitualRoom(map, false);
            SetFlames(map, result == HakkarRitual::Defeated);
        }

        void UpdateRitual(Map* map, uint32 elapsed)
        {
            switch (_ritual)
            {
                case HakkarRitual::Idle:
                    SetRitualRoom(map, false);
                    SetFlames(map, false);
                    break;
                case HakkarRitual::ShadeAwake:
                {
                    if (GameObject* altar = FindGameObject(map, _ritualAltar))
                        if (Creature* avatar = altar->FindNearestCreature(NPC_AVATAR_OF_HAKKAR, AVATAR_SEARCH_RANGE))
                            _avatarGuid = avatar->GetGUID();

                    if (_avatarGuid)
                    {
                        _ritual = HakkarRitual::AvatarAwake;
                        break;
                    }

                    Creature* shade = map->GetCreature(_shadeGuid);
                    if (!shade || !shade->IsAlive())          // the Suppressors won, or the grid unloaded
                        EndRitual(map, HakkarRitual::Idle);
                    else
                        SetRitualRoom(map, true);
                    break;
                }
                case HakkarRitual::AvatarAwake:
                {
                    Creature* avatar = map->GetCreature(_avatarGuid);
                    if (!avatar)                              // left alone out of combat: its SmartAI despawns it
                        EndRitual(map, HakkarRitual::Idle);
                    else if (!avatar->IsAlive())
                    {
                        EndRitual(map, HakkarRitual::Defeated);
                        LOG_INFO("scripts.dc", "Giant Isles Sunken Temple: the Avatar of Hakkar has been defeated");
                    }
                    else
                        SetRitualRoom(map, true);
                    break;
                }
                case HakkarRitual::Defeated:
                    SetRitualRoom(map, false);
                    SetFlames(map, true);
                    if (_ritualRearmMs <= elapsed)
                    {
                        _ritual = HakkarRitual::Idle;
                        SetFlames(map, false);
                    }
                    else
                        _ritualRearmMs -= elapsed;
                    break;
            }
        }

        void ResetRuntime()
        {
            _indexed = false;
            _pollTimer = 0;
            _emptyMs = 0;
            _forcefieldOpen = false;
            _eranikusEngaged = false;
            _statuePhase = 0;
            _atalalarionSlain = false;
            _idolGuid.Clear();
            for (ObjectGuid& lightGuid : _lights)
                lightGuid.Clear();
            _ritual = HakkarRitual::Idle;
            _ritualRearmMs = 0;
            _shadeGuid.Clear();
            _avatarGuid.Clear();
        }

        bool _indexed = false;
        uint32 _pollTimer = 0;
        uint32 _emptyMs = 0;

        std::vector<ObjectGuid::LowType> _defenders;
        std::vector<ObjectGuid::LowType> _warded;
        std::vector<ObjectGuid::LowType> _dragonkin;
        ObjectGuid::LowType _atalalarion = 0;
        ObjectGuid::LowType _jammalan = 0;
        ObjectGuid::LowType _eranikus = 0;
        ObjectGuid::LowType _weaver = 0;
        ObjectGuid::LowType _dreamscythe = 0;
        ObjectGuid::LowType _forcefield = 0;
        ObjectGuid::LowType _ritualAltar = 0;
        std::array<ObjectGuid::LowType, STATUE_COUNT> _statues = { };
        std::array<ObjectGuid::LowType, FLAME_COUNT> _flames = { };
        std::array<ObjectGuid::LowType, 2> _doors = { };

        bool _forcefieldOpen = false;
        bool _eranikusEngaged = false;

        uint8 _statuePhase = 0;
        bool _atalalarionSlain = false;
        ObjectGuid _idolGuid;
        std::array<ObjectGuid, STATUE_COUNT> _lights;

        HakkarRitual _ritual = HakkarRitual::Idle;
        uint32 _ritualRearmMs = 0;
        ObjectGuid _shadeGuid;
        ObjectGuid _avatarGuid;
    };

    class go_giant_isles_atalai_statue : public GameObjectScript
    {
    public:
        go_giant_isles_atalai_statue() : GameObjectScript("go_giant_isles_atalai_statue") { }

        bool OnGossipHello(Player* player, GameObject* go) override
        {
            if (giant_isles_sunken_temple* temple = giant_isles_sunken_temple::Get())
                temple->OnStatueUsed(player, go);

            CloseGossipMenuFor(player);
            return true;
        }
    };

    class go_giant_isles_soulflayer_altar : public GameObjectScript
    {
    public:
        go_giant_isles_soulflayer_altar() : GameObjectScript("go_giant_isles_soulflayer_altar") { }

        bool OnGossipHello(Player* player, GameObject* go) override
        {
            if (giant_isles_sunken_temple* temple = giant_isles_sunken_temple::Get())
                temple->OnRitualAltarUsed(player, go);

            CloseGossipMenuFor(player);
            return true;
        }
    };

    // The cavern floors under the island temple (area triggers 6965-6984) are out of bounds: their
    // areatrigger_teleport rows send the player back to the entrance landing. This only says why, so it
    // returns false and the teleport goes ahead (GMs skip trigger scripts and are teleported silently).
    class at_iog_temple_cavern_return : public AreaTriggerScript
    {
    public:
        at_iog_temple_cavern_return() : AreaTriggerScript("at_iog_temple_cavern_return") { }

        bool OnTrigger(Player* player, AreaTrigger const* /*trigger*/) override
        {
            player->GetSession()->SendAreaTriggerMessage("You slipped into the depths beneath the temple. "
                "The spirits of the Atal'ai return you to its entrance.");
            return false;
        }
    };
}

void AddSC_giant_isles_sunken_temple()
{
    new giant_isles_sunken_temple();
    new go_giant_isles_atalai_statue();
    new go_giant_isles_soulflayer_altar();
    new at_iog_temple_cavern_return();
}
