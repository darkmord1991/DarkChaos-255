/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Guild House Decorations
 * Player-facing decoration placement for guild houses: a curated catalog
 * (worlddb dc_guildhouse_decorations) of retroported housing objects that
 * guild members with the right rank permissions can buy and place inside
 * their guild house phase. Placement reuses the GOMove spawn/move/delete
 * primitives but never exposes raw GM commands; every operation validates
 * guild ownership, rank permission, house bounds, and the per-house-level
 * decoration budget (dc_guildhouse_decoration_budgets).
 */

#ifndef DC_GUILDHOUSE_DECORATIONS_H
#define DC_GUILDHOUSE_DECORATIONS_H

#include "Define.h"

#include <string>
#include <vector>

class Map;
class Player;

namespace DCGuildHouseDecorations
{
    struct CatalogEntry
    {
        uint32 entry = 0;          // gameobject_template entry
        std::string name;
        std::string category;
        uint32 costCopper = 0;
        uint8 minHouseLevel = 1;
        uint16 budgetWeight = 1;
        bool enabled = true;
    };

    // Catalog access (loaded once at startup, reloadable).
    void LoadCatalog();

    // Summon (and register for the editor) every decoration owned by the guild
    // into its freshly-loaded instance map. Called once per instance load by the
    // guild-house InstanceMapScript. Decorations are non-persistent in-world and
    // re-created from dc_guild_house_instance_spawns (source=DECORATION) each load.
    void LoadIntoInstance(Map* map, uint32 guildId);

    // Resolve a tracked decoration (by its stable row id) to its live in-world
    // GameObject's raw GUID, for addon gizmo re-targeting. False if not loaded.
    bool GetLiveGuidRaw(Player* player, uint32 lowguid, uint64& outRaw);

    // Forget all in-memory decoration state (metadata, live refs, budget) for a
    // guild, used when its house is reset/removed. The DB rows are deleted by
    // GuildHouseManager::ClearGuildContent; any live in-world objects clear on
    // the next instance reload.
    void ForgetGuild(uint32 guildId);
    CatalogEntry const* FindCatalogEntry(uint32 entry);
    std::vector<std::string> const& GetCategories();
    std::vector<CatalogEntry const*> GetCatalogPage(
        std::string const& category, uint32 offset, uint32 limit);
    uint32 GetCatalogSize(std::string const& category);

    // Budget queries.
    uint32 GetBudgetCap(uint8 houseLevel);
    uint32 GetUsedBudget(uint32 guildId);

    // Operations. All validate: guild membership, presence in own guild
    // house phase, rank permission, bounds, budget, and funds. On failure
    // `error` carries a player-facing message.
    bool Place(Player* player, uint32 entry, std::string& error,
        uint32* outLowguid = nullptr, uint64* outGuidRaw = nullptr);
    bool PlaceAt(Player* player, uint32 entry, float x, float y, float z,
        float orientation, std::string& error, uint32* outLowguid = nullptr,
        uint64* outGuidRaw = nullptr);
    // Moves go through GOMove, which deletes and respawns the gameobject with
    // a fresh ObjectGuid (to defeat the client's deleted-object cache). The
    // new full GUID is returned via outGuidRaw so the addon can re-target its
    // in-world gizmo, which would otherwise point at the now-dead old GUID.
    bool MoveHere(Player* player, uint32 lowguid, std::string& error,
        uint64* outGuidRaw = nullptr);
    bool Rotate(Player* player, uint32 lowguid, std::string& error,
        uint64* outGuidRaw = nullptr);
    bool MoveTo(Player* player, uint32 lowguid, float x, float y, float z,
        float orientation, std::string& error, uint64* outGuidRaw = nullptr);
    bool Nudge(Player* player, uint32 lowguid, float dx, float dy, float dz,
        float dOrientation, std::string& error, uint64* outGuidRaw = nullptr);
    bool Remove(Player* player, uint32 lowguid, std::string& error,
        uint32* outRefundCopper = nullptr);

    // Set a decoration's visual scale (1.0 = unscaled). Server-authoritative:
    // updates OBJECT_FIELD_SCALE_X (replicated to every nearby player) and
    // persists the value so it survives a restart. Clamped to a sane range.
    bool SetScale(Player* player, uint32 lowguid, float scale,
        std::string& error);
    // Persisted scale for a tracked decoration, or 1.0 if none/unknown.
    float GetDecorationScale(uint32 lowguid);

    // Cached transform (position/orientation/scale) of a tracked decoration.
    // False if the row id is unknown.
    bool GetDecorationTransform(uint32 lowguid, float& x, float& y, float& z,
        float& orientation, float& scale);

    // True when lowguid is a tracked decoration of the player's guild.
    bool IsOwnGuildDecoration(Player* player, uint32 lowguid);

    // Resolve a cursor-picked gameobject GUID to a decoration owned by the
    // player's guild. Fills lowguid/entry on success.
    bool ResolveSelection(Player* player, uint64 rawGuid, uint32& outLowguid,
        uint32& outEntry, uint32& outPaidCopper, std::string& error);

    struct PlacedDecoration
    {
        uint32 lowguid = 0;
        uint32 entry = 0;
        std::string name;
        float x = 0.f;
        float y = 0.f;
        float z = 0.f;
        float orientation = 0.f;
        float scale = 1.f;
        uint32 mapId = 0;
    };

    // All decorations placed by the player's guild (saved spawn data).
    void ListDecorations(Player* player,
        std::vector<PlacedDecoration>& out);

    // Remove every decoration belonging to the player's guild and refund each
    // at the configured refund percent. Requires GH_PERM_DELETE permission.
    bool RemoveAll(Player* player, std::string& error,
        uint32* outRemovedCount = nullptr, uint32* outTotalRefund = nullptr);
}

#endif // DC_GUILDHOUSE_DECORATIONS_H
