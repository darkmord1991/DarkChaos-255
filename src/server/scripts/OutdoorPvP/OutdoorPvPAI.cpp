/*
    ----
    ---- OUTDOOR PVP - AUTOINVITE v1
    
  
*/

#include "OutdoorPvPAI.h"
#include "OutdoorPvPMgr.h"
#include "OutdoorPvP.h"
#include "Group.h"
#include "GroupMgr.h"
#include "Log.h"
#include "WorldPacket.h"
#include "Player.h"
#include "OutdoorPvPScript.h"
#include "CreatureScript.h"

OutdoorPvPAI::OutdoorPvPAI()
{
    _typeId = OUTDOOR_PVP_AI; // also defined in OutdoorPvP.h
}

bool OutdoorPvPAI::SetupOutdoorPvP()
{
    //RegisterZone(HL_ZONE);
    //SetMapFromZone(HL_ZONE);

    for (int i = 0; i < OutdoorPvPHPBuffZonesNum; ++i)
    RegisterZone(OutdoorPvPHPBuffZones[i]);

    SetMapFromZone(OutdoorPvPHPBuffZones[0]);  

    LOG_INFO("misc", "Autoinvite works!");
    return true;        
}

Group* OutdoorPvPAI::GetFreeBfRaid(TeamId TeamId)
{
    for (GuidSet::const_iterator itr = _Groups[TeamId].begin(); itr != _Groups[TeamId].end(); ++itr)
        if (Group* group = sGroupMgr->GetGroupByGUID(itr->GetCounter()))
            if (!group->IsFull())
                return group;

    return nullptr;
}

bool OutdoorPvPAI::AddOrSetPlayerToCorrectBfGroup(Player* plr)
{
    if (!plr->IsInWorld())
        return false;

    // If player is already in a BG/BF group, do not re-invite
    if (plr->GetGroup() && (plr->GetGroup()->isBGGroup() || plr->GetGroup()->isBFGroup()))
    {
        LOG_INFO("misc", "Battlefield::AddOrSetPlayerToCorrectBfGroup - player is already in {} group! AutoGroup HL");
        return false;
    }

    // Find existing raid group for this team in zone 47
    Group* group = GetFreeBfRaid(plr->GetTeamId());
    if (group)
    {
        // If player is not a member, add them
        if (!group->IsMember(plr->GetGUID()))
        {
            group->AddMember(plr);
            if (Group* originalGroup = plr->GetOriginalGroup())
                if (originalGroup->IsLeader(plr->GetGUID()))
                    group->ChangeLeader(plr->GetGUID());
        }
        else
        {
            uint8 subgroup = group->GetMemberGroup(plr->GetGUID());
            plr->SetBattlegroundOrBattlefieldRaid(group, subgroup);
        }
    }
    else
    {
        // No group exists, create a new one
        group = new Group;
        Battleground *bg = (Battleground*)sOutdoorPvPMgr->GetOutdoorPvPToZoneId(47);
        group->SetBattlegroundGroup(bg);
        group->Create(plr);
        sGroupMgr->AddGroup(group);
        _Groups[plr->GetTeamId()].insert(group->GetGUID());
    }
    return true;
}

void OutdoorPvPAI::HandlePlayerEnterZone(Player* player, uint32 zone)
{
    if(AddOrSetPlayerToCorrectBfGroup(player))
    {
        player->GetSession()->SendBfEntered(_BattleId);
        _PlayersInWar[player->GetTeamId()].insert(player->GetGUID());
        
        if (player->isAFK())
            player->ToggleAFK();

        OnPlayerJoinWar(player);  
    }

    // Faction buffs from Wintergrasp
    if (player->GetTeamId() == TEAM_ALLIANCE)
    {
        player->CastSpell(player, AllianceBuff, true);
    }
    else
    {
        player->CastSpell(player, HordeBuff, true);
    }

    // Start OutdoorPvPHL logic for zone 47
    if (zone == 47)
    {
        if (OutdoorPvP* pvpHL = sOutdoorPvPMgr->GetOutdoorPvPToZoneId(47))
        {
            // Only call if it's actually an OutdoorPvPHL instance
            if (pvpHL->GetTypeId() == OUTDOOR_PVP_HL)
                pvpHL->HandlePlayerEnterZone(player, zone);
        }
    }

    OutdoorPvP::HandlePlayerEnterZone(player, zone);
}

Group* OutdoorPvPAI::GetGroupPlayer(ObjectGuid guid, TeamId TeamId)
{
    for (GuidSet::const_iterator itr = _Groups[TeamId].begin(); itr != _Groups[TeamId].end(); ++itr)
        if (Group* group = sGroupMgr->GetGroupByGUID(itr->GetCounter()))
            if (group->IsMember(guid))
                return group;

    return nullptr;
}

void OutdoorPvPAI::HandlePlayerLeaveZone(Player *plr, uint32 zone)
{
    if(Group* group = GetGroupPlayer(plr->GetGUID(), plr->GetTeamId()))
    {
        if (!group->RemoveMember(plr->GetGUID()))       
        {
            _Groups[plr->GetTeamId()].erase(group->GetGUID());
            group->SetBattlegroundGroup(NULL);
        }
    }

    OutdoorPvP::HandlePlayerLeaveZone(plr, zone);
}

class OutdoorPvP_autogroup : public OutdoorPvPScript
{
    public:

        OutdoorPvP_autogroup()
            : OutdoorPvPScript("outdoorpvp_ai")
        {
        }

        OutdoorPvP* GetOutdoorPvP() const
        {
            return new OutdoorPvPAI();
        }
};

void AddSC_outdoorpvp_autogroup()
{
    new OutdoorPvP_autogroup();
}
