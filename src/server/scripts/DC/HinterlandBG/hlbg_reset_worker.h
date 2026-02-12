#pragma once

#include "Creature.h"
#include "GameObject.h"
#include <unordered_map>

// HLZoneResetWorker: traverses object stores to respawn/reset creatures and gameobjects in the battle area
struct HLZoneResetWorker
{
    uint32 areaId;
    uint32 creatureCount = 0;
    uint32 goCount = 0;

    void Visit(std::unordered_map<ObjectGuid, Creature*>& creatureMap)
    {
        for (auto const& p : creatureMap)
        {
            Creature* c = p.second;
            if (!c || !c->IsInWorld())
                continue;
            if (c->GetAreaId() != areaId)
                continue;
            // Skip non-world NPCs
            if (c->IsPlayer() || c->IsPet() || c->IsTotem() || c->IsGuardian() || c->IsSummon())
                continue;

            c->CombatStop(true);
            c->GetThreatMgr().ClearAllThreat();
            c->RemoveAllAuras();
            float x, y, z, o;
            c->GetRespawnPosition(x, y, z, &o);
            c->NearTeleportTo(x, y, z, o, false);
            if (!c->IsAlive())
                c->Respawn(true);
            c->SetFullHealth();
            ++creatureCount;
        }
    }

    void Visit(std::unordered_map<ObjectGuid, GameObject*>& goMap)
    {
        for (auto const& p : goMap)
        {
            GameObject* go = p.second;
            if (!go || !go->IsInWorld())
                continue;
            if (go->GetAreaId() != areaId)
                continue;
            go->Respawn();
            ++goCount;
        }
    }

    template<class T>
    void Visit(std::unordered_map<ObjectGuid, T*>&) { /* ignore other object types */ }
};
