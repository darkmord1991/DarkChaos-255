/*
 * Copyright (C) Project SkyFire
 * Copyright (C) 2019+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license: http://github.com/azerothcore/azerothcore-wotlk/blob/master/LICENSE-AGPL3
*/

#include "AchievementMgr.h"
#include "Battleground.h"
#include "BattlegroundBFG.h"
#include "World.h"
#include "WorldPacket.h"
#include "ObjectMgr.h"
#include "BattlegroundMgr.h"
#include "Creature.h"
#include "Language.h"
#include "Object.h"
#include "Player.h"
#include "Util.h"
#include "WorldSession.h"

#include "MiscPackets.h"

#include "GameGraveyard.h"
#include <unordered_map>

// Helper to (add/remove) graveyard links for this battleground.
// The original mod used a PopulateGraveyard helper; here we implement
// an explicit helper that maps node indices to safe-loc ids and updates
// the graveyard links for zone 5449 (Battle for Gilneas area id used by this BG).
static void UpdateGraveyardForNodeIndex(uint8 graveyardIndex, TeamId teamId, bool add)
{
    if (graveyardIndex >= GILNEAS_BG_ALL_NODES_COUNT)
        return;

    uint32 safeLocId = GILNEAS_BG_GraveyardIds[graveyardIndex];
    uint32 zoneId = 5449; // Battle for Gilneas

    if (add)
    {
        // Ensure opposing team link removed first to avoid duplicates/conflicts
        if (teamId == TEAM_ALLIANCE)
            sGraveyard->RemoveGraveyardLink(safeLocId, zoneId, TEAM_HORDE, false);
        else if (teamId == TEAM_HORDE)
            sGraveyard->RemoveGraveyardLink(safeLocId, zoneId, TEAM_ALLIANCE, false);

        sGraveyard->AddGraveyardLink(safeLocId, zoneId, teamId, false);
    }
    else
    {
        sGraveyard->RemoveGraveyardLink(safeLocId, zoneId, teamId, false);
    }
}

#include "ScriptMgr.h"
#include "Config.h"
#include <chrono>

// adding Battleground to the core battlegrounds list
BattlegroundTypeId BATTLEGROUND_BFG = BattlegroundTypeId(120); // value from BattlemasterList.dbc
BattlegroundQueueTypeId BATTLEGROUND_QUEUE_BFG = BattlegroundQueueTypeId(13);

void BattlegroundBFGScore::BuildObjectivesBlock(WorldPacket& data)
{
    data << uint32(2);
    data << uint32(BasesAssaulted);
    data << uint32(BasesDefended);
}

BattlegroundBFG::BattlegroundBFG()
{
    m_BuffChange = true;
    BgObjects.resize(GILNEAS_BG_OBJECT_MAX);
    BgCreatures.resize(GILNEAS_BG_ALL_NODES_COUNT + GILNEAS_BG_DYNAMIC_NODES_COUNT); // +GILNEAS_BG_DYNAMIC_NODES_COUNT buff triggers

    _controlledPoints[TEAM_ALLIANCE] = 0;
    _controlledPoints[TEAM_HORDE] = 0;
    _teamScores500Disadvantage[TEAM_ALLIANCE] = false;
    _teamScores500Disadvantage[TEAM_HORDE] = false;
    _honorTics = 0;
    _reputationTics = 0;

    StartMessageIds[BG_STARTING_EVENT_FIRST]  = LANG_BG_BFG_START_TWO_MINUTES;
    StartMessageIds[BG_STARTING_EVENT_SECOND] = LANG_BG_BFG_START_ONE_MINUTE;
    StartMessageIds[BG_STARTING_EVENT_THIRD]  = LANG_BG_BFG_START_HALF_MINUTE;
    StartMessageIds[BG_STARTING_EVENT_FOURTH] = LANG_BG_BFG_HAS_BEGUN;
}

BattlegroundBFG::~BattlegroundBFG() {}

void BattlegroundBFG::PostUpdateImpl(uint32 diff)
{
    if (GetStatus() == STATUS_IN_PROGRESS)
    {
        _bgEvents.Update(diff);
        while (uint32 eventId =_bgEvents.ExecuteEvent())
            switch (eventId)
            {
                case BG_BFG_EVENT_UPDATE_BANNER_LIGHTHOUSE:
                case BG_BFG_EVENT_UPDATE_BANNER_WATERWORKS:
                case BG_BFG_EVENT_UPDATE_BANNER_MINE:
                    CreateBanner(eventId - BG_BFG_EVENT_UPDATE_BANNER_LIGHTHOUSE, false);
                    break;
                case BG_BFG_EVENT_CAPTURE_LIGHTHOUSE:
                case BG_BFG_EVENT_CAPTURE_WATERWORKS:
                case BG_BFG_EVENT_CAPTURE_MINE:
                {
                    uint8 node = eventId - BG_BFG_EVENT_CAPTURE_LIGHTHOUSE;
                    TeamId teamId = _capturePointInfo[node]._state == GILNEAS_BG_NODE_STATUS_ALLY_CONTESTED ? TEAM_ALLIANCE : TEAM_HORDE;
                    DeleteBanner(node);
                    _capturePointInfo[node]._ownerTeamId = teamId;
                    _capturePointInfo[node]._state = teamId == TEAM_ALLIANCE ? GILNEAS_BG_NODE_STATUS_ALLY_OCCUPIED : GILNEAS_BG_NODE_STATUS_HORDE_OCCUPIED;
                    CreateBanner(node, false);
                    SendNodeUpdate(node);
                    NodeOccupied(node);
                    // Message to chatlog
                    char buf[256];
                    ChatMsg type = teamId == TEAM_ALLIANCE ? CHAT_MSG_BG_SYSTEM_ALLIANCE : CHAT_MSG_BG_SYSTEM_HORDE;
                    sprintf(buf, sObjectMgr->GetAcoreString(LANG_BG_BFG_NODE_TAKEN, sWorld->GetDefaultDbcLocale()).c_str(), (teamId == TEAM_ALLIANCE) ? sObjectMgr->GetAcoreString(LANG_BG_BFG_ALLY, sWorld->GetDefaultDbcLocale()).c_str() : sObjectMgr->GetAcoreString(LANG_BG_BFG_HORDE, sWorld->GetDefaultDbcLocale()).c_str(), _GetNodeNameId(node));
                    WorldPacket data;
                    ChatHandler::BuildChatPacket(data, type, LANG_UNIVERSAL, nullptr, nullptr, buf);
                    SendPacketToAll(&data);
                    PlaySoundToAll(GILNEAS_BG_SOUND_NODE_CAPTURED_ALLIANCE + static_cast<uint32>(teamId));
                    break;
                }
                case BG_BFG_EVENT_ALLIANCE_TICK:
                case BG_BFG_EVENT_HORDE_TICK:
                {
                    TeamId teamId = eventId == BG_BFG_EVENT_ALLIANCE_TICK ? TEAM_ALLIANCE : TEAM_HORDE;
                    uint8 honorRewards = _controlledPoints[teamId];
                    // uint8 reputationRewards = _controlledPoints[teamId]; // Currently unused
                    uint8 information = _controlledPoints[teamId];
                    if (honorRewards != 0)
                    {
                        m_TeamScores[teamId] += GILNEAS_BG_TickPoints[honorRewards];
                        // update world state
                        UpdateWorldState(teamId == TEAM_ALLIANCE ? GILNEAS_BG_OP_RESOURCES_ALLY : GILNEAS_BG_OP_RESOURCES_HORDE, m_TeamScores[teamId]);
                        if (m_TeamScores[teamId] > GILNEAS_BG_MAX_TEAM_SCORE)
                            m_TeamScores[teamId] = GILNEAS_BG_MAX_TEAM_SCORE;

                        // if (honorRewards < uint8(m_TeamScores[teamId] / _honorTics))
                        //     RewardHonorToTeam(GetBonusHonorFromKill(1), teamId);
                        // if (reputationRewards < uint8(m_TeamScores[teamId] / _reputationTics))
                        //     RewardReputationToTeam(teamId == TEAM_ALLIANCE ? 509 : 510, 10, teamId);

                        if (information < uint8(m_TeamScores[teamId] / GILNEAS_BG_WARNING_NEAR_VICTORY_SCORE))
                        {
                            if (teamId == TEAM_ALLIANCE)
                                SendBroadcastText(LANG_BG_BFG_ALLY_NEAR_VICTORY, CHAT_MSG_BG_SYSTEM_NEUTRAL);
                            else
                                SendBroadcastText(LANG_BG_BFG_HORDE_NEAR_VICTORY, CHAT_MSG_BG_SYSTEM_NEUTRAL);
                            PlaySoundToAll(GILNEAS_BG_SOUND_NEAR_VICTORY);
                        }

                        if (m_TeamScores[teamId] >= GILNEAS_BG_MAX_TEAM_SCORE)
                            EndBattleground(teamId);

                        _bgEvents.ScheduleEvent(eventId, std::chrono::milliseconds(GILNEAS_BG_TickIntervals[honorRewards]));
                    }
                    break;
                }
            }
    }
}

void BattlegroundBFG::StartingEventCloseDoors()
{
    // Spawn gates
    SpawnBGObject(GILNEAS_BG_OBJECT_GATE_A_1, RESPAWN_IMMEDIATELY);
    SpawnBGObject(GILNEAS_BG_OBJECT_GATE_H_1, RESPAWN_IMMEDIATELY);
    // SpawnBGObject(GILNEAS_BG_OBJECT_GATE_H_2, RESPAWN_IMMEDIATELY);
    DoorClose(GILNEAS_BG_OBJECT_GATE_A_1);
    DoorClose(GILNEAS_BG_OBJECT_GATE_H_1);
    // DoorClose(GILNEAS_BG_OBJECT_GATE_A_2);
    // DoorClose(GILNEAS_BG_OBJECT_GATE_H_2);

    // // Starting base spirit guides
    // NodeOccupied(GILNEAS_BG_SPIRIT_ALLIANCE);
    // NodeOccupied(GILNEAS_BG_SPIRIT_HORDE);
}

void BattlegroundBFG::StartingEventOpenDoors()
{
    SpawnBGObject(GILNEAS_BG_OBJECT_GATE_A_1, RESPAWN_ONE_DAY);
    SpawnBGObject(GILNEAS_BG_OBJECT_GATE_H_1, RESPAWN_ONE_DAY);
    // SpawnBGObject(GILNEAS_BG_OBJECT_GATE_A_2, RESPAWN_ONE_DAY);
    // SpawnBGObject(GILNEAS_BG_OBJECT_GATE_H_2, RESPAWN_ONE_DAY);

    for (uint8 i = 0; i < GILNEAS_BG_DYNAMIC_NODES_COUNT; ++i)
    {
        //randomly select buff to spawn
        uint8 buff = urand(0, 2);
        SpawnBGObject(GILNEAS_BG_OBJECT_SPEEDBUFF_LIGHTHOUSE + buff + i * 3, RESPAWN_IMMEDIATELY);
    }
}

void BattlegroundBFG::AddPlayer(Player* player)
{
    Battleground::AddPlayer(player);
    BattlegroundBFGScore* sc = new BattlegroundBFGScore(player->GetGUID());
    PlayerScores.emplace(player->GetGUID().GetCounter(), sc);
    // Start the PVP mirror timer: (timerType, currentValue, maxValue, scale/regen, paused, spellID)
    // Use FATIGUE_TIMER (engine's MirrorTimerType) for PvP mirror bar since MIRROR_TYPE_PVP is not defined in this tree
    player->SendDirectMessage(WorldPackets::Misc::StartMirrorTimer(FATIGUE_TIMER, BG_EVENT_START_BATTLE, 0, 0, false, 0).Write());
}

void BattlegroundBFG::RemovePlayer(Player* /*player*/) {
    // Implement any cleanup needed when a player leaves
}

void BattlegroundBFG::HandleAreaTrigger(Player* player, uint32 trigger)
{
    if (GetStatus() != STATUS_IN_PROGRESS)
        return;

    switch (trigger) {
        case 6447:                                          // Alliance start
            // if (player->GetTeamId() != TEAM_ALLIANCE)
            //     player->GetSession()->SendNotification("Only The Alliance can use that portal");
            // else
            //     player->LeaveBattleground();
            // break;
        case 6448:                                          // Horde start
            // if (player->GetTeamId() != TEAM_HORDE)
            //     player->GetSession()->SendNotification("Only The Horde can use that portal");
            // else
            //     player->LeaveBattleground();
            // break;
        case 6265:                                          // Waterworks heal
        case 6266:                                          // Mine speed
        case 6267:                                          // Waterworks speed
        case 6268:                                          // Mine berserk
        case 6269:                                          // Lighthouse heal
            // handle buff pickup
            break;
        default:
            Battleground::HandleAreaTrigger(player, trigger);
            break;
    }
}

void BattlegroundBFG::CreateBanner(uint8 node, bool delay)
{
    // Just put it into the queue
    if (delay)
    {
        _bgEvents.RescheduleEvent(BG_BFG_EVENT_UPDATE_BANNER_LIGHTHOUSE+node, std::chrono::milliseconds(BG_BFG_BANNER_UPDATE_TIME));
        return;
    }

    SpawnBGObject(node*GILNEAS_BG_OBJECT_PER_NODE + _capturePointInfo[node]._state, RESPAWN_IMMEDIATELY);
    SpawnBGObject(node*GILNEAS_BG_OBJECT_PER_NODE + GILNEAS_BG_OBJECT_AURA_ALLY + _capturePointInfo[node]._ownerTeamId, RESPAWN_IMMEDIATELY);
}

void BattlegroundBFG::DeleteBanner(uint8 node)
{
    SpawnBGObject(node*GILNEAS_BG_OBJECT_PER_NODE + _capturePointInfo[node]._state, RESPAWN_ONE_DAY);
    SpawnBGObject(node*GILNEAS_BG_OBJECT_PER_NODE + GILNEAS_BG_OBJECT_AURA_ALLY + _capturePointInfo[node]._ownerTeamId, RESPAWN_ONE_DAY);
}

void BattlegroundBFG::FillInitialWorldStates(WorldPackets::WorldState::InitWorldStates& packet)
{
    const uint8 plusArray[] = { 0, 2, 3, 0, 1 };

    packet.Worldstates.reserve(10);

    // Node icons
    for (uint8 node = 0; node < GILNEAS_BG_DYNAMIC_NODES_COUNT; ++node)
        packet.Worldstates.emplace_back(_capturePointInfo[node]._iconNone, (_capturePointInfo[node]._state == GILNEAS_BG_NODE_TYPE_NEUTRAL) ? 1 : 0);

    // Node occupied states
    for (uint8 node = 0; node < GILNEAS_BG_DYNAMIC_NODES_COUNT; ++node)
        for (uint8 i = 1; i < GILNEAS_BG_DYNAMIC_NODES_COUNT; ++i)
            packet.Worldstates.emplace_back(_capturePointInfo[node]._iconCapture + plusArray[i], (_capturePointInfo[node]._state == i) ? 1 : 0);

    // How many bases each team owns (currently tracked but not used in worldstates)
    // uint8 ally = 0, horde = 0;
    // for (uint8 node = 0; node < GILNEAS_BG_DYNAMIC_NODES_COUNT; ++node)
    // {
    //     if (_capturePointInfo[node]._ownerTeamId == TEAM_ALLIANCE)
    //         ++ally;
    //     else if (_capturePointInfo[node]._ownerTeamId == TEAM_HORDE)
    //         ++horde;
    // }

    packet.Worldstates.emplace_back(GILNEAS_BG_OP_RESOURCES_MAX, GILNEAS_BG_MAX_TEAM_SCORE);
    packet.Worldstates.emplace_back(GILNEAS_BG_OP_RESOURCES_WARNING, GILNEAS_BG_WARNING_NEAR_VICTORY_SCORE);
    packet.Worldstates.emplace_back(GILNEAS_BG_OP_RESOURCES_ALLY, m_TeamScores[TEAM_ALLIANCE]);
    packet.Worldstates.emplace_back(GILNEAS_BG_OP_RESOURCES_HORDE, m_TeamScores[TEAM_HORDE]);
    packet.Worldstates.emplace_back(0x745, 0x2); // unk
}

void BattlegroundBFG::SendNodeUpdate(uint8 node)
{
    // Send node owner state update to refresh map icons on client
    const uint8 plusArray[] = { 0, 2, 3, 0, 1 };

    if (_capturePointInfo[node]._state == GILNEAS_BG_NODE_TYPE_NEUTRAL)
    {
        UpdateWorldState(_capturePointInfo[node]._iconNone, 1);
    }
    else
    {
        UpdateWorldState(_capturePointInfo[node]._iconNone, 0);
        UpdateWorldState(_capturePointInfo[node]._iconCapture + plusArray[_capturePointInfo[node]._state], 1);
    }
}

void BattlegroundBFG::NodeOccupied(uint8 node)
{
    ApplyPhaseMask();
    AddSpiritGuide(node, GILNEAS_BG_SpiritGuidePos[node][0], GILNEAS_BG_SpiritGuidePos[node][1], GILNEAS_BG_SpiritGuidePos[node][2], GILNEAS_BG_SpiritGuidePos[node][3], _capturePointInfo[node]._ownerTeamId);

    ++_controlledPoints[_capturePointInfo[node]._ownerTeamId];
    // if (_controlledPoints[_capturePointInfo[node]._ownerTeamId] >= 5)
    //     CastSpellOnTeam(SPELL_AB_QUEST_REWARD_5_BASES, _capturePointInfo[node]._ownerTeamId);
    // if (_controlledPoints[_capturePointInfo[node]._ownerTeamId] >= 4)
    //     CastSpellOnTeam(SPELL_AB_QUEST_REWARD_4_BASES, _capturePointInfo[node]._ownerTeamId);

    if (_controlledPoints[_capturePointInfo[node]._ownerTeamId] == 1)
        _bgEvents.ScheduleEvent((_capturePointInfo[node]._ownerTeamId == TEAM_ALLIANCE) ? BG_BFG_EVENT_ALLIANCE_TICK : BG_BFG_EVENT_HORDE_TICK, std::chrono::milliseconds(GILNEAS_BG_TickIntervals[_controlledPoints[_capturePointInfo[node]._ownerTeamId]]));

    Creature* trigger = GetBgMap()->GetCreature(BgCreatures[GILNEAS_BG_ALL_NODES_COUNT + node]);
    if (!trigger)
        trigger = AddCreature(WORLD_TRIGGER, GILNEAS_BG_ALL_NODES_COUNT + node, GILNEAS_BG_NodePositions[node][0], GILNEAS_BG_NodePositions[node][1], GILNEAS_BG_NodePositions[node][2], GILNEAS_BG_NodePositions[node][3]);

    if (trigger)
    {
        trigger->SetFaction(_capturePointInfo[node]._ownerTeamId == TEAM_ALLIANCE ? FACTION_ALLIANCE_GENERIC : FACTION_HORDE_GENERIC);
        trigger->CastSpell(trigger, SPELL_HONORABLE_DEFENDER_25Y, false);
    }
    // Ensure graveyard links reflect ownership of this node
    if (_capturePointInfo[node]._ownerTeamId == TEAM_ALLIANCE || _capturePointInfo[node]._ownerTeamId == TEAM_HORDE)
        UpdateGraveyardForNodeIndex(node, _capturePointInfo[node]._ownerTeamId, true);
}

void BattlegroundBFG::NodeDeoccupied(uint8 node)
{
    if (_capturePointInfo[node]._ownerTeamId != TEAM_NEUTRAL)
    {
        TeamId prevOwner = _capturePointInfo[node]._ownerTeamId;
        --_controlledPoints[prevOwner];

        // If any of the node-related creatures were removed, remove the graveyard link
        if (DelCreature(GILNEAS_BG_ALL_NODES_COUNT + node) || DelCreature(node))
            UpdateGraveyardForNodeIndex(node, prevOwner, false);

        // Mark node neutral
        _capturePointInfo[node]._ownerTeamId = TEAM_NEUTRAL;
        _capturePointInfo[node]._state = GILNEAS_BG_NODE_TYPE_NEUTRAL;

        ApplyPhaseMask();
    }
}

/* Invoked if a player used a banner as a gameobject */
void BattlegroundBFG::EventPlayerClickedOnFlag(Player* player, GameObject* gameObject)
{
    if (GetStatus() != STATUS_IN_PROGRESS || !player->IsWithinDistInMap(gameObject, 10.0f))
        return;

    uint8 node = GILNEAS_BG_NODE_LIGHTHOUSE;
    for (; node < GILNEAS_BG_DYNAMIC_NODES_COUNT; ++node)
        if (player->GetDistance2d(GILNEAS_BG_NodePositions[node][0], GILNEAS_BG_NodePositions[node][1]) < 10.0f)
            break;

    if (node == GILNEAS_BG_DYNAMIC_NODES_COUNT || _capturePointInfo[node]._ownerTeamId == player->GetTeamId() ||
        (_capturePointInfo[node]._state == GILNEAS_BG_NODE_STATUS_ALLY_CONTESTED && player->GetTeamId() == TEAM_ALLIANCE) ||
        (_capturePointInfo[node]._state == GILNEAS_BG_NODE_STATUS_HORDE_CONTESTED && player->GetTeamId() == TEAM_HORDE))
        return;

    player->RemoveAurasWithInterruptFlags(AURA_INTERRUPT_FLAG_ENTER_PVP_COMBAT);

    uint32 sound = 0;
    // uint32 message = 0;
    // uint32 message2 = 0;
    DeleteBanner(node);
    CreateBanner(node, true);

    if (_capturePointInfo[node]._state == GILNEAS_BG_NODE_TYPE_NEUTRAL)
    {
        UpdatePlayerScore(player, SCORE_BASES_ASSAULTED, 1);
    _capturePointInfo[node]._state = static_cast<uint8>(GILNEAS_BG_NODE_STATUS_ALLY_CONTESTED) + static_cast<uint8>(player->GetTeamId());
        // message = LANG_BG_AB_NODE_CLAIMED;
        sound = GILNEAS_BG_SOUND_NODE_CLAIMED;
    }
    else
    {
        if (_capturePointInfo[node]._ownerTeamId == TEAM_ALLIANCE)
            UpdatePlayerScore(player, SCORE_BASES_DEFENDED, 1);
        else
            UpdatePlayerScore(player, SCORE_BASES_ASSAULTED, 1);
        _capturePointInfo[node]._ownerTeamId = TEAM_NEUTRAL;
    _capturePointInfo[node]._state = static_cast<uint8>(GILNEAS_BG_NODE_STATUS_ALLY_CONTESTED) + static_cast<uint8>(player->GetTeamId());
        // message = LANG_BG_AB_NODE_ASSAULTED;
    }

    // Cancel previous capture events
    _bgEvents.CancelEvent(BG_BFG_EVENT_CAPTURE_LIGHTHOUSE + node);
    // Schedule new capture event
    _bgEvents.ScheduleEvent(BG_BFG_EVENT_CAPTURE_LIGHTHOUSE + node, std::chrono::milliseconds(GILNEAS_BG_FLAG_CAPTURING_TIME));

    SendNodeUpdate(node);
    SendBroadcastText(LANG_BG_BFG_NODE_CLAIMED, CHAT_MSG_BG_SYSTEM_NEUTRAL, player);

    PlaySoundToAll(sound);
}

TeamId BattlegroundBFG::GetPrematureWinner()
{
    // How many bases each team owns
    uint8 ally = _controlledPoints[TEAM_ALLIANCE];
    uint8 horde = _controlledPoints[TEAM_HORDE];

    if (ally > horde)
        return TEAM_ALLIANCE;
    else if (horde > ally)
        return TEAM_HORDE;

    // If the values are equal, fall back to score
    return Battleground::GetPrematureWinner();
}

bool BattlegroundBFG::SetupBattleground() {

    AddObject(GILNEAS_BG_OBJECT_GATE_A_1, GILNEAS_BG_OBJECTID_GATE_A_1, GILNEAS_BG_DoorPositions[0][0], GILNEAS_BG_DoorPositions[0][1], GILNEAS_BG_DoorPositions[0][2], GILNEAS_BG_DoorPositions[0][3], GILNEAS_BG_DoorPositions[0][4], GILNEAS_BG_DoorPositions[0][5], GILNEAS_BG_DoorPositions[0][6], GILNEAS_BG_DoorPositions[0][7], RESPAWN_IMMEDIATELY);
    // AddObject(GILNEAS_BG_OBJECT_GATE_A_2, GILNEAS_BG_OBJECTID_GATE_A_2, GILNEAS_BG_DoorPositions[1][0], GILNEAS_BG_DoorPositions[1][1], GILNEAS_BG_DoorPositions[1][2], GILNEAS_BG_DoorPositions[1][3], GILNEAS_BG_DoorPositions[1][4], GILNEAS_BG_DoorPositions[1][5], GILNEAS_BG_DoorPositions[1][6], GILNEAS_BG_DoorPositions[1][7], RESPAWN_IMMEDIATELY);
    AddObject(GILNEAS_BG_OBJECT_GATE_H_1, GILNEAS_BG_OBJECTID_GATE_H_1, GILNEAS_BG_DoorPositions[2][0], GILNEAS_BG_DoorPositions[2][1], GILNEAS_BG_DoorPositions[2][2], GILNEAS_BG_DoorPositions[2][3], GILNEAS_BG_DoorPositions[2][4], GILNEAS_BG_DoorPositions[2][5], GILNEAS_BG_DoorPositions[2][6], GILNEAS_BG_DoorPositions[2][7], RESPAWN_IMMEDIATELY);
    // AddObject(GILNEAS_BG_OBJECT_GATE_H_2, GILNEAS_BG_OBJECTID_GATE_H_2, GILNEAS_BG_DoorPositions[3][0], GILNEAS_BG_DoorPositions[3][1], GILNEAS_BG_DoorPositions[3][2], GILNEAS_BG_DoorPositions[3][3], GILNEAS_BG_DoorPositions[3][4], GILNEAS_BG_DoorPositions[3][5], GILNEAS_BG_DoorPositions[3][6], GILNEAS_BG_DoorPositions[3][7], RESPAWN_IMMEDIATELY);

    // Buffs
    for (uint32 i = 0; i < GILNEAS_BG_DYNAMIC_NODES_COUNT; ++i)
    {
        AddObject(GILNEAS_BG_OBJECT_SPEEDBUFF_LIGHTHOUSE + 3 * i,     Buff_Entries[0], GILNEAS_BG_BuffPositions[i][0], GILNEAS_BG_BuffPositions[i][1], GILNEAS_BG_BuffPositions[i][2], GILNEAS_BG_BuffPositions[i][3], 0, 0, sin(GILNEAS_BG_BuffPositions[i][3] / 2), cos(GILNEAS_BG_BuffPositions[i][3] / 2), RESPAWN_ONE_DAY);
        AddObject(GILNEAS_BG_OBJECT_SPEEDBUFF_LIGHTHOUSE + 3 * i + 1, Buff_Entries[1], GILNEAS_BG_BuffPositions[i][0], GILNEAS_BG_BuffPositions[i][1], GILNEAS_BG_BuffPositions[i][2], GILNEAS_BG_BuffPositions[i][3], 0, 0, sin(GILNEAS_BG_BuffPositions[i][3] / 2), cos(GILNEAS_BG_BuffPositions[i][3] / 2), RESPAWN_ONE_DAY);
        AddObject(GILNEAS_BG_OBJECT_SPEEDBUFF_LIGHTHOUSE + 3 * i + 2, Buff_Entries[2], GILNEAS_BG_BuffPositions[i][0], GILNEAS_BG_BuffPositions[i][1], GILNEAS_BG_BuffPositions[i][2], GILNEAS_BG_BuffPositions[i][3], 0, 0, sin(GILNEAS_BG_BuffPositions[i][3] / 2), cos(GILNEAS_BG_BuffPositions[i][3] / 2), RESPAWN_ONE_DAY);
    }

    // Banners
    for (uint32 i = 0; i < GILNEAS_BG_DYNAMIC_NODES_COUNT; ++i)
    {
        AddObject(GILNEAS_BG_OBJECT_BANNER_NEUTRAL  + GILNEAS_BG_OBJECT_PER_NODE * i, GILNEAS_BG_OBJECTID_BANNER_A,          GILNEAS_BG_NodePositions[i][0], GILNEAS_BG_NodePositions[i][1], GILNEAS_BG_NodePositions[i][2], GILNEAS_BG_NodePositions[i][3], 0, 0, sin(GILNEAS_BG_NodePositions[i][3] / 2), cos(GILNEAS_BG_NodePositions[i][3] / 2), RESPAWN_ONE_DAY);
        AddObject(GILNEAS_BG_OBJECT_BANNER_CONT_A   + GILNEAS_BG_OBJECT_PER_NODE * i, GILNEAS_BG_OBJECTID_BANNER_CONT_A,     GILNEAS_BG_NodePositions[i][0], GILNEAS_BG_NodePositions[i][1], GILNEAS_BG_NodePositions[i][2], GILNEAS_BG_NodePositions[i][3], 0, 0, sin(GILNEAS_BG_NodePositions[i][3] / 2), cos(GILNEAS_BG_NodePositions[i][3] / 2), RESPAWN_ONE_DAY);
        AddObject(GILNEAS_BG_OBJECT_BANNER_CONT_H   + GILNEAS_BG_OBJECT_PER_NODE * i, GILNEAS_BG_OBJECTID_BANNER_CONT_H,     GILNEAS_BG_NodePositions[i][0], GILNEAS_BG_NodePositions[i][1], GILNEAS_BG_NodePositions[i][2], GILNEAS_BG_NodePositions[i][3], 0, 0, sin(GILNEAS_BG_NodePositions[i][3] / 2), cos(GILNEAS_BG_NodePositions[i][3] / 2), RESPAWN_ONE_DAY);
        AddObject(GILNEAS_BG_OBJECT_BANNER_ALLY     + GILNEAS_BG_OBJECT_PER_NODE * i, GILNEAS_BG_OBJECTID_BANNER_A,          GILNEAS_BG_NodePositions[i][0], GILNEAS_BG_NodePositions[i][1], GILNEAS_BG_NodePositions[i][2], GILNEAS_BG_NodePositions[i][3], 0, 0, sin(GILNEAS_BG_NodePositions[i][3] / 2), cos(GILNEAS_BG_NodePositions[i][3] / 2), RESPAWN_ONE_DAY);
        AddObject(GILNEAS_BG_OBJECT_BANNER_HORDE    + GILNEAS_BG_OBJECT_PER_NODE * i, GILNEAS_BG_OBJECTID_BANNER_H,          GILNEAS_BG_NodePositions[i][0], GILNEAS_BG_NodePositions[i][1], GILNEAS_BG_NodePositions[i][2], GILNEAS_BG_NodePositions[i][3], 0, 0, sin(GILNEAS_BG_NodePositions[i][3] / 2), cos(GILNEAS_BG_NodePositions[i][3] / 2), RESPAWN_ONE_DAY);
        AddObject(GILNEAS_BG_OBJECT_AURA_ALLY       + GILNEAS_BG_OBJECT_PER_NODE * i, GILNEAS_BG_OBJECTID_AURA_A,            GILNEAS_BG_NodePositions[i][0], GILNEAS_BG_NodePositions[i][1], GILNEAS_BG_NodePositions[i][2], GILNEAS_BG_NodePositions[i][3], 0, 0, sin(GILNEAS_BG_NodePositions[i][3] / 2), cos(GILNEAS_BG_NodePositions[i][3] / 2), RESPAWN_ONE_DAY);
        AddObject(GILNEAS_BG_OBJECT_AURA_HORDE      + GILNEAS_BG_OBJECT_PER_NODE * i, GILNEAS_BG_OBJECTID_AURA_H,            GILNEAS_BG_NodePositions[i][0], GILNEAS_BG_NodePositions[i][1], GILNEAS_BG_NodePositions[i][2], GILNEAS_BG_NodePositions[i][3], 0, 0, sin(GILNEAS_BG_NodePositions[i][3] / 2), cos(GILNEAS_BG_NodePositions[i][3] / 2), RESPAWN_ONE_DAY);
        AddObject(GILNEAS_BG_OBJECT_AURA_CONTESTED  + GILNEAS_BG_OBJECT_PER_NODE * i, GILNEAS_BG_OBJECTID_AURA_C,            GILNEAS_BG_NodePositions[i][0], GILNEAS_BG_NodePositions[i][1], GILNEAS_BG_NodePositions[i][2], GILNEAS_BG_NodePositions[i][3], 0, 0, sin(GILNEAS_BG_NodePositions[i][3] / 2), cos(GILNEAS_BG_NodePositions[i][3] / 2), RESPAWN_ONE_DAY);
    }

    AddSpiritGuide(GILNEAS_BG_SPIRIT_ALLIANCE, GILNEAS_BG_SpiritGuidePos[GILNEAS_BG_SPIRIT_ALLIANCE][0], GILNEAS_BG_SpiritGuidePos[GILNEAS_BG_SPIRIT_ALLIANCE][1], GILNEAS_BG_SpiritGuidePos[GILNEAS_BG_SPIRIT_ALLIANCE][2], GILNEAS_BG_SpiritGuidePos[GILNEAS_BG_SPIRIT_ALLIANCE][3], TEAM_ALLIANCE);
    AddSpiritGuide(GILNEAS_BG_SPIRIT_HORDE, GILNEAS_BG_SpiritGuidePos[GILNEAS_BG_SPIRIT_HORDE][0], GILNEAS_BG_SpiritGuidePos[GILNEAS_BG_SPIRIT_HORDE][1], GILNEAS_BG_SpiritGuidePos[GILNEAS_BG_SPIRIT_HORDE][2], GILNEAS_BG_SpiritGuidePos[GILNEAS_BG_SPIRIT_HORDE][3], TEAM_HORDE);

    return true;
}

void BattlegroundBFG::Init()
{

      //call parent's class reset
    Battleground::Init();

    _bgEvents.Reset();

    // _honorTics = BattlegroundMgr::IsBGWeekend(GetBgTypeID()) ? BG_AB_HONOR_TICK_WEEKEND : BG_AB_HONOR_TICK_NORMAL;
    // _reputationTics = BattlegroundMgr::IsBGWeekend(GetBgTypeID()) ? BG_AB_REP_TICK_WEEKEND : BG_AB_REP_TICK_NORMAL;

    _capturePointInfo[GILNEAS_BG_NODE_LIGHTHOUSE]._iconNone    = GILNEAS_BG_OP_LIGHTHOUSE_ICON;
    _capturePointInfo[GILNEAS_BG_NODE_WATERWORKS]._iconNone    = GILNEAS_BG_OP_WATERWORKS_ICON;
    _capturePointInfo[GILNEAS_BG_NODE_MINE]._iconNone          = GILNEAS_BG_OP_MINE_ICON;
    _capturePointInfo[GILNEAS_BG_NODE_LIGHTHOUSE]._iconCapture = GILNEAS_BG_OP_LIGHTHOUSE_STATE_ALLIANCE;
    _capturePointInfo[GILNEAS_BG_NODE_WATERWORKS]._iconCapture = GILNEAS_BG_OP_WATERWORKS_STATE_ALLIANCE;
    _capturePointInfo[GILNEAS_BG_NODE_MINE]._iconCapture       = GILNEAS_BG_OP_MINE_STATE_ALLIANCE;

    for (uint8 i = 0; i < GILNEAS_BG_DYNAMIC_NODES_COUNT; ++i) {
        _capturePointInfo[i]._ownerTeamId = TEAM_NEUTRAL;
        _capturePointInfo[i]._state = GILNEAS_BG_NODE_TYPE_NEUTRAL;
    }

    _controlledPoints[TEAM_ALLIANCE] = 0;
    _controlledPoints[TEAM_HORDE] = 0;
    _teamScores500Disadvantage[TEAM_ALLIANCE] = false;
    _teamScores500Disadvantage[TEAM_HORDE] = false;

    m_TeamScores[TEAM_ALLIANCE] = 0;
    m_TeamScores[TEAM_HORDE] = 0;
}

void BattlegroundBFG::EndBattleground(TeamId winnerTeamId)
{
    // Win reward
    if (winnerTeamId == TEAM_ALLIANCE)
        RewardHonorToTeam(GetBonusHonorFromKill(1), TEAM_ALLIANCE);
    if (winnerTeamId == TEAM_HORDE)
        RewardHonorToTeam(GetBonusHonorFromKill(1), TEAM_HORDE);
    // Complete map_end rewards (honor reward)
    RewardHonorToTeam(GetBonusHonorFromKill(2), TEAM_ALLIANCE);
    RewardHonorToTeam(GetBonusHonorFromKill(2), TEAM_HORDE);

    Battleground::EndBattleground(winnerTeamId);
}

GraveyardStruct const* BattlegroundBFG::GetClosestGraveyard(Player* player)
{
    GraveyardStruct const* entry = sGraveyard->GetGraveyard(GILNEAS_BG_GraveyardIds[static_cast<uint8>(GILNEAS_BG_SPIRIT_ALLIANCE) + static_cast<uint8>(player->GetTeamId())]);
    GraveyardStruct const* nearestEntry = entry;

    float pX = player->GetPositionX();
    float pY = player->GetPositionY();
    float dist = (entry->x - pX)*(entry->x - pX)+(entry->y - pY)*(entry->y - pY);
    float minDist = dist;

    for (uint8 i = GILNEAS_BG_NODE_LIGHTHOUSE; i < GILNEAS_BG_DYNAMIC_NODES_COUNT; ++i)
        if (_capturePointInfo[i]._ownerTeamId == player->GetTeamId())
        {
            entry = sGraveyard->GetGraveyard(GILNEAS_BG_GraveyardIds[i]);
            dist = (entry->x - pX)*(entry->x - pX)+(entry->y - pY)*(entry->y - pY);
            if (dist < minDist)
            {
                minDist = dist;
                nearestEntry = entry;
            }
        }

    return nearestEntry;
}

bool BattlegroundBFG::UpdatePlayerScore(Player* player, uint32 type, uint32 value, bool doAddHonor)
{
    if (!Battleground::UpdatePlayerScore(player, type, value, doAddHonor))
        return false;

    switch (type)
    {
        case SCORE_BASES_ASSAULTED:
            {
                auto itr = PlayerScores.find(player->GetGUID().GetCounter());
                if (itr != PlayerScores.end())
                    ((BattlegroundBFGScore*)itr->second)->BasesAssaulted += value;
            }
            player->UpdateAchievementCriteria(ACHIEVEMENT_CRITERIA_TYPE_BG_OBJECTIVE_CAPTURE, GILNEAS_BG_OBJECTIVE_ASSAULT_BASE);
            break;
        case SCORE_BASES_DEFENDED:
            {
                auto itr = PlayerScores.find(player->GetGUID().GetCounter());
                if (itr != PlayerScores.end())
                    ((BattlegroundBFGScore*)itr->second)->BasesDefended += value;
            }
            player->UpdateAchievementCriteria(ACHIEVEMENT_CRITERIA_TYPE_BG_OBJECTIVE_CAPTURE, GILNEAS_BG_OBJECTIVE_DEFEND_BASE);
            break;
        default:
            break;
    }
    return true;
}

bool BattlegroundBFG::AllNodesConrolledByTeam(TeamId teamId) const
{
    for (uint8 i = 0; i < GILNEAS_BG_DYNAMIC_NODES_COUNT; ++i)
        if (_capturePointInfo[i]._ownerTeamId != teamId)
            return false;

    return true;
}

// bool BattlegroundBFG::CheckAchievementCriteriaMeet(uint32 criteriaId, Player const* player, Unit const* target, uint32 miscvalue)
// {
//     switch (criteriaId)
//     {
//         case BG_CRITERIA_CHECK_RESILIENT_VICTORY:
//             return m_TeamScores500Disadvantage[player->GetTeamId()];
//     }

//     //return CheckAchievementCriteriaMeet(criteriaId, player, target, miscvalue);
//     return false;
// }

void BattlegroundBFG::ApplyPhaseMask()
{
    uint32 phaseMask = 1;
    for (uint32 i = GILNEAS_BG_NODE_LIGHTHOUSE; i < GILNEAS_BG_DYNAMIC_NODES_COUNT; ++i)
        if (_capturePointInfo[i]._ownerTeamId != TEAM_NEUTRAL)
            phaseMask |= 1u << (i*2+1 + static_cast<uint32>(_capturePointInfo[i]._ownerTeamId));

    const BattlegroundPlayerMap& bgPlayerMap = GetPlayers();
    for (BattlegroundPlayerMap::const_iterator itr = bgPlayerMap.begin(); itr != bgPlayerMap.end(); ++itr)
    {
        itr->second->SetPhaseMask(phaseMask, false);
        itr->second->UpdateObjectVisibility(true, false);
    }
}

int32 BattlegroundBFG::_GetNodeNameId(uint8 node)
{
    switch (node)
    {
        case GILNEAS_BG_NODE_LIGHTHOUSE:  return LANG_BG_BFG_NODE_LIGHTHOUSE;
        case GILNEAS_BG_NODE_WATERWORKS:  return LANG_BG_BFG_NODE_WATERWORKS;
        case GILNEAS_BG_NODE_MINE:        return LANG_BG_BFG_NODE_MINE;
        default:
            return 0;
    }
}

class BattleForGilneasWorld : public WorldScript
{
    public:
    	BattleForGilneasWorld() : WorldScript("BattleForGilneasWorld") { }
};

void AddBattleForGilneasScripts() {
    new BattleForGilneasWorld();

    // Add Battle for Gilneas to battleground list
    BattlegroundMgr::queueToBg[BATTLEGROUND_QUEUE_BFG] = BATTLEGROUND_BFG;
    BattlegroundMgr::bgToQueue[BATTLEGROUND_BFG] = BATTLEGROUND_QUEUE_BFG;
    BattlegroundMgr::bgtypeToBattleground[BATTLEGROUND_BFG] = new BattlegroundBFG;

    BattlegroundMgr::bgTypeToTemplate[BATTLEGROUND_BFG] = [](Battleground *bg_t) -> Battleground * { return new BattlegroundBFG(*(BattlegroundBFG *) bg_t); };

    // BattlegroundMgr::getBgFromTypeID[BATTLEGROUND_BFG] = [](WorldPacket* data, Battleground::BattlegroundScoreMap::const_iterator itr2, Battleground* /* bg */) {
    //     *data << uint32(0x00000002);            // count of next fields
    //     *data << uint32(((BattlegroundBFGScore*)itr2->second)->BasesAssaulted);      // bases asssaulted
    //     *data << uint32(((BattlegroundBFGScore*)itr2->second)->BasesDefended);       // bases defended
    // };

    // BattlegroundMgr::getBgFromMap[761] = [](WorldPacket* data, Battleground::BattlegroundScoreMap::const_iterator itr2) {
    //     *data << uint32(0x00000002);            // count of next fields
    //     *data << uint32(((BattlegroundBFGScore*)itr2->second)->BasesAssaulted);      // bases asssaulted
    //     *data << uint32(((BattlegroundBFGScore*)itr2->second)->BasesDefended);       // bases defended
    // };

    Player::bgZoneIdToFillWorldStates[5449] = [](Battleground* bg, WorldPackets::WorldState::InitWorldStates& packet)
    {
        if (bg && bg->GetBgTypeID(true) == BATTLEGROUND_BFG)
        {
            bg->FillInitialWorldStates(packet);
        }
    };
}
