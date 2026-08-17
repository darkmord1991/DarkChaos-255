/*
 * Dark Chaos - Dungeon Encounter (Boss) Tracker Addon Handler (DENC)
 * =================================================================
 *
 * Server side of the retail-style boss checklist that the DC-Journal addon
 * draws above the quest tracker ("Dungeon / The Deadmines / 1/1 X defeated").
 *
 * Everything is keyed by DungeonEncounter.dbc entry id, which is the same key
 * the core itself credits on: Map::UpdateEncounterState resolves a kill/spell
 * to a DungeonEncounter and ORs (1 << encounterIndex) into the instance's
 * completedEncounters mask. So this module never invents its own notion of
 * "boss" - it reads exactly what the core rewards, which means the checklist
 * cannot drift from the lockout, the LFG completion or the achievement path.
 *
 * Three pushes, no polling:
 *   SMSG_LIST      on instance entry / login inside an instance / on request
 *   SMSG_ENCOUNTER on a single encounter completing (OnAfterUpdateEncounterState)
 *   SMSG_CLEAR     on leaving for a map that has nothing to track
 *
 * Completion state is read from InstanceScript::GetCompletedEncounterMask(),
 * the persisted source of truth (saved to `instance`.completedEncounters), so
 * a relog or a re-entered saved instance shows the real progress rather than
 * a fresh session's. Maps with no instance script keep no mask at all - the
 * core cannot credit encounters there either - so those show no block. Today
 * that is only battlegrounds/arenas, none of which have encounter rows.
 *
 * Copyright (C) 2026 Dark Chaos Development Team
 */

#include "dc_addon_namespace.h"
#include "dc_addon_utils.h"
#include "DC/MythicPlus/dc_mythicplus_run_manager.h"
#include "Config.h"
#include "DBCStores.h"
#include "InstanceScript.h"
#include "Log.h"
#include "Map.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"

#include <algorithm>
#include <string>
#include <vector>

namespace DCAddon
{
namespace Encounters
{
    static bool IsEnabled()
    {
        return sConfigMgr->GetOption<bool>("DC.AddonProtocol.Encounters.Enable", true);
    }

    // ------------------------------------------------------------------------
    // Encounter list resolution
    // ------------------------------------------------------------------------
    // Mirrors Map::UpdateEncounterState's difficulty handling exactly, including
    // its ICC (631) / Ruby Sanctum (724) special case where the heroic modes
    // carry no encounter list of their own and borrow the normal one. Diverging
    // here would show the player a list the core will never credit against.
    static DungeonEncounterList const* GetEncountersFor(Map const* map)
    {
        if (!map)
            return nullptr;

        uint32 const mapId = map->GetId();
        Difficulty const difficulty = IsSharedDifficultyMap(mapId)
            ? Difficulty(map->GetDifficulty() % 2)
            : map->GetDifficulty();

        if ((mapId == 631 || mapId == 724) && map->IsHeroic())
        {
            return sObjectMgr->GetDungeonEncounterList(mapId,
                !map->Is25ManRaid() ? RAID_DIFFICULTY_10MAN_NORMAL : RAID_DIFFICULTY_25MAN_NORMAL);
        }

        DungeonEncounterList const* encounters = sObjectMgr->GetDungeonEncounterList(mapId, difficulty);

        // Mythic (DUNGEON_DIFFICULTY_EPIC) 5-mans borrow the heroic list, exactly like
        // Map::UpdateEncounterState does: instance_encounters only resolves to difficulty
        // 0/1 DungeonEncounter.dbc rows for non-raid dungeons, so a Mythic run would
        // otherwise get an empty list and the block would never appear at all.
        if (!encounters && !map->IsRaid() && difficulty == DUNGEON_DIFFICULTY_EPIC)
        {
            encounters = sObjectMgr->GetDungeonEncounterList(mapId, DUNGEON_DIFFICULTY_HEROIC);
            if (!encounters)
                encounters = sObjectMgr->GetDungeonEncounterList(mapId, DUNGEON_DIFFICULTY_NORMAL);
        }

        return encounters;
    }

    // A keystone run owns the objective UI: the DC-MythicPlus HUD already draws
    // its own boss checklist alongside the timer, affixes and enemy forces, and
    // two stacked trackers would just duplicate each other. DENC stands down for
    // the duration of the run and comes back when it ends.
    //
    // GetKeystoneLevel() returns 0 for any map with no active run, so this is
    // also the cheapest available "is this an M+ instance" test.
    static bool IsMythicPlusRun(Map* map)
    {
        return map && sMythicRuns->GetKeystoneLevel(map) > 0;
    }

    // The completed-encounter bitmask for the instance the player stands in, or
    // nullptr-equivalent (false) when this map cannot track encounters at all.
    static bool TryGetCompletedMask(Map* map, uint32& mask)
    {
        mask = 0;

        if (!map)
            return false;

        InstanceMap* instanceMap = map->ToInstanceMap();
        if (!instanceMap)
            return false;

        InstanceScript* instanceScript = instanceMap->GetInstanceScript();
        if (!instanceScript)
            return false;

        mask = instanceScript->GetCompletedEncounterMask();
        return true;
    }

    // Player-facing instance name. dc_dungeon_setup carries the curated names
    // (including the DC custom dungeons); Map.dbc is the fallback so a map that
    // was never added to that table still gets a real title instead of blank.
    static std::string GetInstanceName(uint32 mapId)
    {
        std::string name = Utils::GetDungeonNameByMapId(mapId);
        if (!name.empty())
            return name;

        if (MapEntry const* mapEntry = sMapStore.LookupEntry(mapId))
            if (mapEntry->name[0])
                return mapEntry->name[0];

        return std::string();
    }

    // DungeonEncounter.dbc orderIndex is the intended display order and is NOT
    // the same as encounterIndex (the mask bit): Blackwing Descent runs
    // orderIndex -1000..4000 over bits 5,2,0,1,3,4, and Sartharion's drakes are
    // likewise shuffled. Sorting by the bit would list several instances wrong.
    //
    // orderIndex is SIGNED. Blizzard front-loads encounters with negative
    // values (BWD's Omnotron is -1000, Ruby Sanctum runs -1000/-500/-250), so
    // reading it unsigned would sort exactly those bosses to the bottom.
    struct SortedEncounter
    {
        uint32 id;
        int32 orderIndex;
        uint32 bit;
        char const* name;
    };

    static std::vector<SortedEncounter> BuildSortedList(DungeonEncounterList const* encounters)
    {
        std::vector<SortedEncounter> sorted;
        if (!encounters)
            return sorted;

        sorted.reserve(encounters->size());
        for (DungeonEncounter const* encounter : *encounters)
        {
            if (!encounter || !encounter->dbcEntry)
                continue;

            DungeonEncounterEntry const* entry = encounter->dbcEntry;
            sorted.push_back({ entry->id, entry->orderIndex, entry->encounterIndex, entry->encounterName[0] });
        }

        std::sort(sorted.begin(), sorted.end(), [](SortedEncounter const& a, SortedEncounter const& b)
        {
            if (a.orderIndex != b.orderIndex)
                return a.orderIndex < b.orderIndex;
            return a.id < b.id;
        });

        return sorted;
    }

    // ------------------------------------------------------------------------
    // Outbound
    // ------------------------------------------------------------------------
    static void SendClear(Player* player)
    {
        if (!player)
            return;

        JsonMessage(Module::ENCOUNTERS, Opcode::Encounters::SMSG_CLEAR).Send(player);
    }

    static void SendList(Player* player)
    {
        if (!player || !IsEnabled())
            return;

        Map* map = player->FindMap();
        uint32 completedMask = 0;
        if (IsMythicPlusRun(map) || !TryGetCompletedMask(map, completedMask))
        {
            SendClear(player);
            return;
        }

        std::vector<SortedEncounter> const encounters = BuildSortedList(GetEncountersFor(map));
        if (encounters.empty())
        {
            SendClear(player);
            return;
        }

        JsonValue bosses;
        bosses.SetArray(encounters.size());
        for (SortedEncounter const& encounter : encounters)
        {
            JsonValue boss;
            boss.SetObject();
            boss.Set("e", JsonValue(encounter.id));
            boss.Set("t", JsonValue(encounter.name ? encounter.name : ""));
            boss.Set("k", JsonValue((completedMask & (1u << encounter.bit)) != 0));
            bosses.Push(std::move(boss));
        }

        JsonMessage msg(Module::ENCOUNTERS, Opcode::Encounters::SMSG_LIST);
        msg.Set("m", map->GetId());
        msg.Set("d", static_cast<uint32>(map->GetDifficulty()));
        // Raid flag: difficulty ids overlap between dungeons and raids (1 =
        // Heroic 5-man but 25-Normal raid), so the client cannot label the
        // difficulty without knowing which enum it is looking at.
        msg.Set("r", map->IsRaid());
        // Player cap from MapDifficulty.dbc - the authoritative source. Custom
        // raids do not follow the stock 10/25 pattern (Timbermaw Hold is 20),
        // so the client must never derive this from the difficulty id.
        MapDifficulty const* mapDiff = GetMapDifficultyData(map->GetId(), map->GetDifficulty());
        msg.Set("p", mapDiff ? mapDiff->maxPlayers : 0u);
        msg.Set("n", GetInstanceName(map->GetId()));
        msg.Set("b", std::move(bosses));
        msg.Send(player);
    }

    // Push a single completed encounter to everyone still in the instance.
    // Sending only the delta (rather than the whole list again) keeps a raid
    // clear at one small message per boss instead of one per boss per member.
    static void BroadcastEncounter(Map* map, uint32 encounterId)
    {
        if (!map || !IsEnabled() || IsMythicPlusRun(map))
            return;

        JsonMessage msg(Module::ENCOUNTERS, Opcode::Encounters::SMSG_ENCOUNTER);
        msg.Set("m", map->GetId());
        msg.Set("d", static_cast<uint32>(map->GetDifficulty()));
        msg.Set("e", encounterId);
        msg.Set("k", true);

        // Sent per player rather than once: JsonMessage::Send negotiates the
        // native-opcode transport per session, so a shared encode would break
        // for anyone on the other transport.
        Map::PlayerList const& players = map->GetPlayers();
        for (Map::PlayerList::const_iterator itr = players.begin(); itr != players.end(); ++itr)
            if (Player* player = itr->GetSource())
                msg.Send(player);
    }

    // Re-evaluate the block for everyone in an instance. Called by the Mythic+
    // run manager when a keystone run starts or ends: a run can be activated
    // long after the group walked in, so the list has to be withdrawn (and
    // restored on completion/failure) rather than only decided on entry.
    // SendList already applies the M+ suppression, so this is direction-agnostic.
    void RefreshForMap(Map* map)
    {
        if (!map || !IsEnabled())
            return;

        Map::PlayerList const& players = map->GetPlayers();
        for (Map::PlayerList::const_iterator itr = players.begin(); itr != players.end(); ++itr)
            if (Player* player = itr->GetSource())
                SendList(player);
    }

    // ------------------------------------------------------------------------
    // Inbound
    // ------------------------------------------------------------------------
    static void HandleRequest(Player* player, ParsedMessage const& /*msg*/)
    {
        SendList(player);
    }

    void RegisterEncounterHandlers()
    {
        // DENC is intentionally not part of the central module table in
        // dc_addon_protocol.cpp, so it enables itself with the router here
        // (same self-contained pattern as DC-Graveyard/DC-QuestNav).
        bool const enabled = IsEnabled();

        MessageRouter::Instance().SetModuleEnabled(Module::ENCOUNTERS, enabled);
        if (!enabled)
            return;

        DC_REGISTER_HANDLER(Module::ENCOUNTERS, Opcode::Encounters::CMSG_REQUEST, HandleRequest);
    }
} // namespace Encounters
} // namespace DCAddon

// Instance entry / exit: the client has no way to know it crossed into an
// instance boundary before the addon's own zone events settle, so the list is
// pushed rather than polled. OnPlayerMapChanged covers both directions - a map
// with nothing to track answers with SMSG_CLEAR, which hides the block.
class DCEncounterTrackerPlayerScript : public PlayerScript
{
public:
    // The hook list is mandatory: ScriptRegistry::AddScript only files a script
    // under the hooks it names, and CALL_ENABLED_HOOKS iterates that list only.
    // A PlayerScript constructed without one is registered but never invoked.
    DCEncounterTrackerPlayerScript() : PlayerScript("DCEncounterTrackerPlayerScript", {
        PLAYERHOOK_ON_LOGIN,
        PLAYERHOOK_ON_MAP_CHANGED
    }) { }

    void OnPlayerLogin(Player* player) override
    {
        DCAddon::Encounters::SendList(player);
    }

    void OnPlayerMapChanged(Player* player) override
    {
        DCAddon::Encounters::SendList(player);
    }
};

// Live updates. OnAfterUpdateEncounterState fires from Map::UpdateEncounterState
// for every credit attempt; `updated` is true only when an encounter bit that
// was previously unset actually flipped, so re-killing a boss in an already
// cleared instance does not re-announce it.
class DCEncounterTrackerGlobalScript : public GlobalScript
{
public:
    DCEncounterTrackerGlobalScript() : GlobalScript("DCEncounterTrackerGlobalScript", {
        GLOBALHOOK_ON_AFTER_UPDATE_ENCOUNTER_STATE
    }) { }

    void OnAfterUpdateEncounterState(Map* map, EncounterCreditType type, uint32 creditEntry,
        Unit* /*source*/, Difficulty /*difficulty_fixed*/, DungeonEncounterList const* encounters,
        uint32 /*dungeonCompleted*/, bool updated) override
    {
        if (!updated || !map || !encounters)
            return;

        // Resolve which DungeonEncounter this credit belonged to. The core has
        // already applied it to the mask; we only need its dbc id for the push.
        for (DungeonEncounter const* encounter : *encounters)
        {
            if (!encounter || !encounter->dbcEntry)
                continue;

            if (encounter->creditType == type && encounter->creditEntry == creditEntry)
            {
                DCAddon::Encounters::BroadcastEncounter(map, encounter->dbcEntry->id);
                return;
            }
        }
    }
};

void AddSC_dc_addon_encounters()
{
    DCAddon::Encounters::RegisterEncounterHandlers();

    new DCEncounterTrackerPlayerScript();
    new DCEncounterTrackerGlobalScript();
}
