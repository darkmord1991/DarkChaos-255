/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "HostileRefMgr.h"
#include "CreatureAI.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "ThreatMgr.h"
#include "Unit.h"

HostileRefMgr::~HostileRefMgr()
{
    deleteReferences();
}

void HostileRefMgr::AddReference(HostileReference* reference)
{
    std::lock_guard<std::recursive_mutex> guard(_lock);
    insertFirst(reference);
}

void HostileRefMgr::RemoveReference(HostileReference* reference)
{
    if (!reference)
        return;

    std::lock_guard<std::recursive_mutex> guard(_lock);
    reference->delink();
}

void HostileRefMgr::UpdateOnlineStateForPhase(uint32 newPhaseMask)
{
    std::lock_guard<std::recursive_mutex> guard(_lock);
    HostileReference* ref = getFirst();
    while (ref)
    {
        HostileReference* nextRef = ref->next();
        if (Unit* unit = ref->GetSource()->GetOwner())
            if (Creature* creature = unit->ToCreature())
                ref->setOnlineOfflineState(creature->InSamePhase(newPhaseMask));

        ref = nextRef;
    }
}

//=================================================
// send threat to all my hateres for the victim
// The victim is hated than by them as well
// use for buffs and healing threat functionality

void HostileRefMgr::threatAssist(Unit* victim, float baseThreat, SpellInfo const* threatSpell)
{
    std::lock_guard<std::recursive_mutex> guard(_lock);
    if (getSize() == 0)
        return;

    HostileReference* ref = getFirst();
    float threat = ThreatCalcHelper::calcThreat(victim, baseThreat, (threatSpell ? threatSpell->GetSchoolMask() : SPELL_SCHOOL_MASK_NORMAL), threatSpell);
    threat /= getSize();
    while (ref)
    {
        Unit* refOwner = ref->GetSource()->GetOwner();
        if (ThreatCalcHelper::isValidProcess(victim, refOwner, threatSpell))
        {
            if (Creature* hatingCreature = refOwner->ToCreature())
            {
                if (hatingCreature->IsAIEnabled)
                {
                    hatingCreature->AI()->CalculateThreat(victim, threat, threatSpell);
                }
            }

            ref->GetSource()->DoAddThreat(victim, threat);
        }

        ref = ref->next();
    }
}

//=================================================

void HostileRefMgr::addTempThreat(float threat, bool apply)
{
    std::lock_guard<std::recursive_mutex> guard(_lock);
    HostileReference* ref = getFirst();

    while (ref)
    {
        if (apply)
        {
            if (ref->getTempThreatModifier() == 0.0f)
                ref->addTempThreat(threat);
        }
        else
            ref->resetTempThreat();

        ref = ref->next();
    }
}

//=================================================

void HostileRefMgr::addThreatPercent(int32 percent)
{
    std::lock_guard<std::recursive_mutex> guard(_lock);
    HostileReference* ref = getFirst();
    while (ref)
    {
        ref->addThreatPercent(percent);
        ref = ref->next();
    }
}

//=================================================
// The online / offline status is given to the method. The calculation has to be done before

void HostileRefMgr::setOnlineOfflineState(bool isOnline)
{
    std::lock_guard<std::recursive_mutex> guard(_lock);
    HostileReference* ref = getFirst();
    while (ref)
    {
        ref->setOnlineOfflineState(isOnline);
        ref = ref->next();
    }
}

//=================================================
// The online / offline status is calculated and set

void HostileRefMgr::updateThreatTables()
{
    std::lock_guard<std::recursive_mutex> guard(_lock);
    HostileReference* ref = getFirst();
    while (ref)
    {
        ref->updateOnlineStatus();
        ref = ref->next();
    }
}

//=================================================
// The references are not needed anymore
// tell the source to remove them from the list and free the mem

void HostileRefMgr::deleteReferences(bool removeFromMap /*= false*/)
{
    std::vector<HostileReference*> refsToRemove;
    {
        std::lock_guard<std::recursive_mutex> guard(_lock);
        HostileReference* ref = getFirst();
        while (ref)
        {
            HostileReference* nextRef = ref->next();
            ref->delink();
            refsToRemove.push_back(ref);
            ref = nextRef;
        }
    }

    std::vector<Creature*> creaturesToEvade;

    for (HostileReference* ref : refsToRemove)
    {
        if (!ref)
            continue;

        ref->removeReference();

        if (removeFromMap)
        {
            if (ThreatMgr const* threatMgr = ref->GetSource())
            {
                if (threatMgr->areThreatListsEmpty())
                {
                    if (Creature* creature = threatMgr->GetOwner()->ToCreature())
                    {
                        creaturesToEvade.push_back(creature);
                    }
                }
            }
        }

        delete ref;
    }

    for (Creature* creature : creaturesToEvade)
    {
        creature->AI()->EnterEvadeMode();
    }
}

//=================================================
// delete one reference, defined by faction

void HostileRefMgr::deleteReferencesForFaction(uint32 faction)
{
    std::vector<HostileReference*> refsToRemove;
    {
        std::lock_guard<std::recursive_mutex> guard(_lock);
        HostileReference* ref = getFirst();
        while (ref)
        {
            HostileReference* nextRef = ref->next();
            if (ref->GetSource()->GetOwner()->GetFactionTemplateEntry()->faction == faction)
            {
                ref->delink();
                refsToRemove.push_back(ref);
            }
            ref = nextRef;
        }
    }

    for (HostileReference* ref : refsToRemove)
    {
        if (!ref)
            continue;

        ref->removeReference();
        delete ref;
    }
}

//=================================================
// delete one reference, defined by Unit

void HostileRefMgr::deleteReference(Unit* creature)
{
    HostileReference* refToRemove = nullptr;
    {
        std::lock_guard<std::recursive_mutex> guard(_lock);
        HostileReference* ref = getFirst();
        while (ref)
        {
            HostileReference* nextRef = ref->next();
            if (ref->GetSource()->GetOwner() == creature)
            {
                ref->delink();
                refToRemove = ref;
                break;
            }
            ref = nextRef;
        }
    }

    if (refToRemove)
    {
        refToRemove->removeReference();
        delete refToRemove;
    }
}

//=================================================
// delete all references out of specified range

void HostileRefMgr::deleteReferencesOutOfRange(float range)
{
    std::vector<HostileReference*> refsToRemove;

    range = range * range;
    {
        std::lock_guard<std::recursive_mutex> guard(_lock);
        HostileReference* ref = getFirst();
        while (ref)
        {
            HostileReference* nextRef = ref->next();
            Unit* owner = ref->GetSource()->GetOwner();
            if (!owner->isActiveObject() && owner->GetExactDist2dSq(GetOwner()) > range)
            {
                ref->delink();
                refsToRemove.push_back(ref);
            }
            ref = nextRef;
        }
    }

    for (HostileReference* ref : refsToRemove)
    {
        if (!ref)
            continue;

        ref->removeReference();
        delete ref;
    }
}

//=================================================
// set state for one reference, defined by Unit

void HostileRefMgr::setOnlineOfflineState(Unit* creature, bool isOnline)
{
    std::lock_guard<std::recursive_mutex> guard(_lock);
    HostileReference* ref = getFirst();
    while (ref)
    {
        HostileReference* nextRef = ref->next();
        if (ref->GetSource()->GetOwner() == creature)
        {
            ref->setOnlineOfflineState(isOnline);
            break;
        }
        ref = nextRef;
    }
}

//=================================================

void HostileRefMgr::UpdateVisibility(bool checkThreat)
{
    std::lock_guard<std::recursive_mutex> guard(_lock);
    HostileReference* ref = getFirst();
    while (ref)
    {
        HostileReference* nextRef = ref->next();
        if ((!checkThreat || ref->GetSource()->GetThreatListSize() <= 1))
        {
            nextRef = ref->next();
            ref->removeReference();
            delete ref;
        }
        ref = nextRef;
    }
}
