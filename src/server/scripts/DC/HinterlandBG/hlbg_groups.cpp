// -----------------------------------------------------------------------------
// hlbg_groups.cpp
// -----------------------------------------------------------------------------
// Battleground-like raid lifecycle maintenance:
// - Track last-seen offline times for members and prune after a grace period.
// - Remove empty raids; when a raid shrinks to a single member, keep their
//   raid context by creating a new raid to avoid core auto-disband side effects.
// -----------------------------------------------------------------------------
#include "hlbg.h"
#include "GroupMgr.h"
#include "ObjectAccessor.h"

// Periodic maintenance of faction raid groups used by the Hinterland BG.
void OutdoorPvPHL::_tickRaidLifecycle()
{
    // Offline tracking & pruning: remove raid members offline for >=45s to cover disconnects
    uint32 nowSec = uint32(GameTime::GetGameTime().count());
    // Mark newly offline members & clear marks for those who returned
    for (uint8 tid = 0; tid <= TEAM_HORDE; ++tid)
    {
        for (ObjectGuid gid : _teamRaidGroups[tid])
        {
            Group* g = sGroupMgr->GetGroupByGUID(gid.GetCounter());
            if (!g || !g->isRaidGroup())
                continue;
            for (auto const& slot : g->GetMemberSlots())
            {
                Player* m = GetMap() ? ObjectAccessor::GetPlayer(GetMap(), slot.guid) : nullptr;
                if (m && m->IsInWorld())
                    _memberOfflineSince.erase(slot.guid);
                else if (_memberOfflineSince.find(slot.guid) == _memberOfflineSince.end())
                    _memberOfflineSince[slot.guid] = nowSec; // first seen offline
            }
        }
    }

    // Collect removals
    static constexpr uint32 HL_OFFLINE_GRACE_SECONDS = 45;
    std::vector<std::pair<ObjectGuid/*group*/, ObjectGuid/*member*/>> offlineRemovals;
    for (auto const& kv : _memberOfflineSince)
    {
        if (nowSec - kv.second < HL_OFFLINE_GRACE_SECONDS)
            continue;
        for (uint8 tid = 0; tid <= TEAM_HORDE; ++tid)
        {
            for (ObjectGuid gid : _teamRaidGroups[tid])
            {
                Group* g = sGroupMgr->GetGroupByGUID(gid.GetCounter());
                if (!g || !g->isRaidGroup())
                    continue;
                if (g->IsMember(kv.first))
                {
                    offlineRemovals.emplace_back(gid, kv.first);
                    break;
                }
            }
        }
    }
    for (auto const& rem : offlineRemovals)
    {
        if (Group* g = sGroupMgr->GetGroupByGUID(rem.first.GetCounter()))
            g->RemoveMember(rem.second);
        _memberOfflineSince.erase(rem.second);
    }

    // Stricter group lifecycle: remove empty raid groups promptly, but keep raids alive for a single remaining member
    for (uint8 tid = 0; tid <= TEAM_HORDE; ++tid)
    {
        auto& vec = _teamRaidGroups[tid];
        for (auto it = vec.begin(); it != vec.end();)
        {
            Group* g = sGroupMgr->GetGroupByGUID(it->GetCounter());
            if (!g || !g->isRaidGroup() || g->GetMembersCount() == 0)
            {
                if (g)
                    g->Disband(true /*hideDestroy*/);
                it = vec.erase(it);
            }
            else if (g->GetMembersCount() == 1)
            {
                ObjectGuid lastGuid;
                for (auto const& slot : g->GetMemberSlots()) { lastGuid = slot.guid; break; }
                if (!lastGuid.IsEmpty())
                {
                    if (Player* last = GetMap() ? ObjectAccessor::GetPlayer(GetMap(), lastGuid) : nullptr)
                    {
                        Group* lg = last->GetGroup();
                        if (!lg || !lg->isRaidGroup())
                        {
                            Group* ng = new Group();
                            if (ng->Create(last))
                            {
                                ng->ConvertToRaid();
                                sGroupMgr->AddGroup(ng);
                                _teamRaidGroups[tid].push_back(ng->GetGUID());
                                Whisper(last, "|cffffd700Your battleground raid remains active.|r");
                            }
                            else
                            {
                                delete ng;
                            }
                        }
                    }
                }
                it = vec.erase(it);
            }
            else
            {
                ++it;
            }
        }
    }
}
