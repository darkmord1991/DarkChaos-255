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

#include "ObjectVisibilityContainer.h"
#include "Object.h"
#include "Player.h"

/*
* Some implementation notes:
* Non-player worldobjects do not have any concept of 'visibility', thus,
* the most important and mainly used map is 'VisibleWorldObjectsMap'
* which is only accessible for player objects. The 'VisiblePlayersMap'
* map is simply for managing the references so we can use direct pointers.
*/

ObjectVisibilityContainer::ObjectVisibilityContainer(WorldObject* selfObject) :
    _selfObject(selfObject)
{
}

ObjectVisibilityContainer::~ObjectVisibilityContainer()
{
    ASSERT(_visiblePlayersMap.empty());
    if (_visibleWorldObjectsMap)
        ASSERT((*_visibleWorldObjectsMap).empty());
}

void ObjectVisibilityContainer::InitForPlayer()
{
    std::lock_guard<std::mutex> guard(_lock);
    _visibleWorldObjectsMap = std::make_unique<VisibleWorldObjectsMap>();
}

void ObjectVisibilityContainer::CleanVisibilityReferences()
{
    std::vector<Player*> visiblePlayers;
    std::vector<WorldObject*> visibleWorldObjects;
    {
        std::lock_guard<std::mutex> guard(_lock);
        visiblePlayers.reserve(_visiblePlayersMap.size());
        for (auto const& kvPair : _visiblePlayersMap)
            visiblePlayers.push_back(kvPair.second);

        if (_visibleWorldObjectsMap)
        {
            visibleWorldObjects.reserve(_visibleWorldObjectsMap->size());
            for (auto const& kvPair : *_visibleWorldObjectsMap)
                visibleWorldObjects.push_back(kvPair.second);
            _visibleWorldObjectsMap->clear();
        }

        _visiblePlayersMap.clear();
    }

    for (Player* player : visiblePlayers)
        player->GetObjectVisibilityContainer().DirectRemoveVisibilityReference(_selfObject->GetGUID());

    for (WorldObject* worldObject : visibleWorldObjects)
        worldObject->GetObjectVisibilityContainer().DirectRemoveVisiblePlayerReference(_selfObject->GetGUID());
}

void ObjectVisibilityContainer::LinkWorldObjectVisibility(WorldObject* worldObject)
{
    // Do not link self
    if (worldObject == _selfObject)
        return;

    // Transports are special and should not be added to our visibility map
    if (worldObject->IsGameObject() && worldObject->ToGameObject()->IsTransport())
        return;

    // Only players can link visibility
    {
        std::lock_guard<std::mutex> guard(_lock);
        if (!_visibleWorldObjectsMap)
            return;

        _visibleWorldObjectsMap->insert(std::make_pair(worldObject->GetGUID(), worldObject));
    }

    worldObject->GetObjectVisibilityContainer().DirectInsertVisiblePlayerReference(_selfObject->ToPlayer());
}

void ObjectVisibilityContainer::UnlinkWorldObjectVisibility(WorldObject* worldObject)
{
    // Only players can unlink visibility
    {
        std::lock_guard<std::mutex> guard(_lock);
        if (!_visibleWorldObjectsMap)
            return;

        _visibleWorldObjectsMap->erase(worldObject->GetGUID());
    }

    worldObject->GetObjectVisibilityContainer().DirectRemoveVisiblePlayerReference(_selfObject->GetGUID());
}

VisibleWorldObjectsMap::iterator ObjectVisibilityContainer::UnlinkVisibilityFromPlayer(WorldObject* worldObject, VisibleWorldObjectsMap::iterator itr)
{
    ASSERT(_visibleWorldObjectsMap); // Ensure we aren't for some reason calling this as a non-player object
    worldObject->GetObjectVisibilityContainer().DirectRemoveVisiblePlayerReference(_selfObject->GetGUID());
    std::lock_guard<std::mutex> guard(_lock);
    return _visibleWorldObjectsMap->erase(itr);
}

VisiblePlayersMap::iterator ObjectVisibilityContainer::UnlinkVisibilityFromWorldObject(Player* player, VisiblePlayersMap::iterator itr)
{
    player->GetObjectVisibilityContainer().DirectRemoveVisibilityReference(_selfObject->GetGUID());
    std::lock_guard<std::mutex> guard(_lock);
    return _visiblePlayersMap.erase(itr);
}

void ObjectVisibilityContainer::UnlinkVisibilityFromWorldObject(Player* player)
{
    if (!player)
        return;

    player->GetObjectVisibilityContainer().DirectRemoveVisibilityReference(_selfObject->GetGUID());
    std::lock_guard<std::mutex> guard(_lock);
    _visiblePlayersMap.erase(player->GetGUID());
}

void ObjectVisibilityContainer::DirectRemoveVisibilityReference(ObjectGuid guid)
{
    std::lock_guard<std::mutex> guard(_lock);
    ASSERT(_visibleWorldObjectsMap);
    _visibleWorldObjectsMap->erase(guid);
}

void ObjectVisibilityContainer::DirectInsertVisiblePlayerReference(Player* player)
{
    std::lock_guard<std::mutex> guard(_lock);
    _visiblePlayersMap.insert(std::make_pair(player->GetGUID(), player));
}

void ObjectVisibilityContainer::DirectRemoveVisiblePlayerReference(ObjectGuid guid)
{
    std::lock_guard<std::mutex> guard(_lock);
    _visiblePlayersMap.erase(guid);
}

bool ObjectVisibilityContainer::VisiblePlayersEmpty() const
{
    std::lock_guard<std::mutex> guard(_lock);
    return _visiblePlayersMap.empty();
}

size_t ObjectVisibilityContainer::VisiblePlayersCount() const
{
    std::lock_guard<std::mutex> guard(_lock);
    return _visiblePlayersMap.size();
}

void ObjectVisibilityContainer::GetVisiblePlayersSnapshot(std::vector<Player*>& out) const
{
    std::lock_guard<std::mutex> guard(_lock);
    out.reserve(out.size() + _visiblePlayersMap.size());
    for (auto const& kvPair : _visiblePlayersMap)
        out.push_back(kvPair.second);
}

void ObjectVisibilityContainer::GetVisiblePlayerGuids(std::vector<ObjectGuid>& out) const
{
    std::lock_guard<std::mutex> guard(_lock);
    out.reserve(out.size() + _visiblePlayersMap.size());
    for (auto const& kvPair : _visiblePlayersMap)
        out.push_back(kvPair.first);
}

void ObjectVisibilityContainer::EraseVisiblePlayerByGuid(ObjectGuid const& guid) const
{
    std::lock_guard<std::mutex> guard(_lock);
    _visiblePlayersMap.erase(guid);
}

bool ObjectVisibilityContainer::VisibleWorldObjectsEmpty() const
{
    std::lock_guard<std::mutex> guard(_lock);
    if (!_visibleWorldObjectsMap)
        return true;

    return _visibleWorldObjectsMap->empty();
}

bool ObjectVisibilityContainer::HasVisibleWorldObject(ObjectGuid const& guid) const
{
    std::lock_guard<std::mutex> guard(_lock);
    if (!_visibleWorldObjectsMap)
        return false;

    return _visibleWorldObjectsMap->find(guid) != _visibleWorldObjectsMap->end();
}

void ObjectVisibilityContainer::GetVisibleWorldObjectGuids(std::vector<ObjectGuid>& out) const
{
    std::lock_guard<std::mutex> guard(_lock);
    if (!_visibleWorldObjectsMap)
        return;

    out.reserve(out.size() + _visibleWorldObjectsMap->size());
    for (auto const& kvPair : *_visibleWorldObjectsMap)
        out.push_back(kvPair.first);
}

void ObjectVisibilityContainer::EraseVisibleWorldObjectByGuid(ObjectGuid const& guid) const
{
    std::lock_guard<std::mutex> guard(_lock);
    if (!_visibleWorldObjectsMap)
        return;

    _visibleWorldObjectsMap->erase(guid);
}
