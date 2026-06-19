#include "dc_guildhouse.h"
#include "dc_guildhouse_decorations.h"

#include "Group.h"
#include "GroupMgr.h"
#include "InstanceMapScript.h"
#include "InstanceScript.h"
#include "Player.h"

#include <unordered_map>

// Instanced guild housing (Phase B migration) - per-instance script for the
// dedicated guild-house map (GUILD_HOUSE_MAP_ID). Every guild teleports into its
// own instance (isolation via instance id, not phasing). This script:
//   - auto-joins arriving guild members into a shared house RAID group so they
//     get raid frames and can find each other easily, and removes them on leave;
//   - is the future home (Phase 4) of per-guild custom-decoration spawning.
//
// Note: shared/default styling content (Dalaran buildings, functional NPCs such
// as bank/mailbox/repair, decorative props) does NOT belong here - those are
// ordinary STATIC creature/gameobject spawns keyed to GUILD_HOUSE_MAP_ID with
// spawnMask=1 (dungeon-normal) and phaseMask=1; the core loads them into every
// instance automatically. Only the per-guild player-placed decorations are
// dynamic, because they must differ between instances.

namespace
{
    // guildId -> house raid-group GUID. The group lives while the guild's house
    // instance is occupied; the core reassigns leadership and disbands the group
    // automatically once the last member leaves.
    std::unordered_map<uint32, ObjectGuid> s_houseGroups;

    Group* FindHouseGroup(uint32 guildId)
    {
        auto it = s_houseGroups.find(guildId);
        if (it == s_houseGroups.end())
            return nullptr;

        if (Group* group = sGroupMgr->GetGroupByGUID(it->second.GetCounter()))
            return group;

        // Stale handle (group was disbanded elsewhere) - forget it.
        s_houseGroups.erase(it);
        return nullptr;
    }

    void AutoJoinHouseGroup(Player* player)
    {
        uint32 guildId = player->GetGuildId();
        if (!guildId)
            return; // GMs / guildless visitors are left ungrouped.

        // Never hijack a party/raid the player formed themselves.
        if (player->GetGroup())
            return;

        Group* group = FindHouseGroup(guildId);
        if (!group)
        {
            // First member in becomes the house group's leader. Group::Create
            // already adds the leader as the first member.
            group = new Group();
            if (!group->Create(player))
            {
                delete group;
                return;
            }

            group->ConvertToRaid();
            sGroupMgr->AddGroup(group);
            s_houseGroups[guildId] = group->GetGUID();
            return;
        }

        // Existing group: add the player unless the raid cap (40) is reached.
        // Members beyond the cap stay fully visible in the instance - they just
        // do not appear on the shared raid frames.
        if (group->IsFull())
            return;

        if (!group->IsMember(player->GetGUID()))
            group->AddMember(player);
    }

    void LeaveHouseGroup(Player* player)
    {
        uint32 guildId = player->GetGuildId();
        if (!guildId)
            return;

        Group* group = FindHouseGroup(guildId);
        if (!group)
            return;

        // Only touch the auto-managed house group, never a real party.
        if (player->GetGroup() != group || !group->IsMember(player->GetGUID()))
            return;

        ObjectGuid groupGuid = group->GetGUID();
        group->RemoveMember(player->GetGUID());

        // RemoveMember may have disbanded (and deleted) the group when it
        // emptied; drop our handle in that case.
        if (!sGroupMgr->GetGroupByGUID(groupGuid.GetCounter()))
            s_houseGroups.erase(guildId);
    }
}

class instance_guildhouse : public InstanceMapScript
{
public:
    instance_guildhouse() : InstanceMapScript("instance_guildhouse", GUILD_HOUSE_MAP_ID) { }

    struct instance_guildhouse_InstanceScript : public InstanceScript
    {
        instance_guildhouse_InstanceScript(Map* map) : InstanceScript(map) { }

        bool _contentSpawned = false;

        void OnPlayerEnter(Player* player) override
        {
            AutoJoinHouseGroup(player);

            // Spawn the owning guild's dynamic content (butler purchases, and in
            // Phase 4 player-placed decorations) once per instance load. The
            // guild is resolved from the instance id, not the entering player, so
            // it works no matter who arrives first.
            if (!_contentSpawned)
            {
                uint32 guildId = GuildHouseManager::GetGuildByInstanceId(instance->GetInstanceId());
                if (guildId)
                {
                    GuildHouseManager::LoadGuildContentIntoInstance(instance, guildId);
                    DCGuildHouseDecorations::LoadIntoInstance(instance, guildId);
                    _contentSpawned = true;
                }
            }
        }

        void OnPlayerLeave(Player* player) override
        {
            LeaveHouseGroup(player);
        }
    };

    InstanceScript* GetInstanceScript(InstanceMap* map) const override
    {
        return new instance_guildhouse_InstanceScript(map);
    }
};

void AddSC_dc_guildhouse_instance()
{
    new instance_guildhouse();
}
