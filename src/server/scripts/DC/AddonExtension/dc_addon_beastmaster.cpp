/*
 * Dark Chaos - Beastmaster Pet Catalog Addon Handler (BEAST)
 * ==========================================================
 *
 * Server side of the DC-Collection "Beastmaster" tab: a curated catalog of
 * tameable hunter pets that a hunter can browse (with a live 3D model preview
 * on the client) and instantly "adopt".
 *
 * The catalog is data-driven from the `dc_beastmaster_pets` world table joined
 * against `creature_template` (for display id, family and exotic flag). Adopting
 * reuses the core's real tamed-pet path via Player::CreatePet(), so the result
 * is a genuine hunter pet (saved to the DB, family abilities learned, scales
 * with the owner) rather than a cosmetic summon.
 *
 * Only hunters may use it; exotic-family pets additionally require the Beast
 * Mastery talent, matching retail taming rules (Player::CanTameExoticPets()).
 *
 * Copyright (C) 2026 Dark Chaos Development Team
 */

#include "dc_addon_namespace.h"
#include "Config.h"
#include "DBCStores.h"
#include "DatabaseEnv.h"
#include "GameTime.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Pet.h"
#include "Player.h"
#include "SharedDefines.h"

#include <mutex>
#include <unordered_set>
#include <vector>

namespace DCAddon
{
namespace Beastmaster
{
    constexpr const char* MODULE_BEAST = Module::BEASTMASTER;

    // The roster is read-mostly (changes only on SQL reload), so we cache the
    // encoded payload + the set of adoptable creature ids and rebuild lazily on
    // a TTL, mirroring the World module's content cache.
    constexpr uint64 CATALOG_CACHE_TTL_MS = 30000;

    struct CachedCatalog
    {
        std::string payloadJson;                 // {"pets":[...],"count":N}
        std::unordered_set<uint32> adoptableIds; // curated + valid-for-adopt
        uint64 expiresAtMs = 0;
        bool built = false;
    };

    static std::mutex sCatalogLock;
    static CachedCatalog sCatalog;

    // Build the catalog payload from dc_beastmaster_pets + creature_template.
    static CachedCatalog BuildCatalog()
    {
        CachedCatalog cache;

        JsonValue pets;
        pets.SetArray();

        QueryResult result = WorldDatabase.Query(
            "SELECT creature_id, category, rarity, source_text, sort_order "
            "FROM dc_beastmaster_pets WHERE enabled = 1 ORDER BY sort_order, creature_id");

        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                uint32 creatureId     = fields[0].Get<uint32>();
                std::string category  = fields[1].Get<std::string>();
                uint32 rarity         = fields[2].Get<uint32>();
                std::string source    = fields[3].Get<std::string>();

                CreatureTemplate const* ct = sObjectMgr->GetCreatureTemplate(creatureId);
                if (!ct)
                {
                    LOG_WARN("dc.addon", "[Beastmaster] roster creature_id {} has no creature_template; skipping", creatureId);
                    continue;
                }

                // family 0 would crash Player::CreatePet(); never expose it.
                if (ct->family == 0)
                {
                    LOG_WARN("dc.addon", "[Beastmaster] roster creature_id {} has family 0 (not a valid pet); skipping", creatureId);
                    continue;
                }

                uint32 displayId = 0;
                if (CreatureModel const* model = ct->GetModelByIdx(0))
                    displayId = model->CreatureDisplayID;

                std::string familyName;
                if (CreatureFamilyEntry const* famEntry = sCreatureFamilyStore.LookupEntry(ct->family))
                {
                    if (famEntry->Name[0] && famEntry->Name[0][0])
                        familyName = famEntry->Name[0];
                }

                bool const exotic = ct->IsExotic();

                JsonValue pet;
                pet.SetObject();
                pet.Set("creatureId", JsonValue(creatureId));
                pet.Set("displayId", JsonValue(displayId));
                pet.Set("name", JsonValue(ct->Name));
                pet.Set("family", JsonValue(ct->family));
                pet.Set("familyName", JsonValue(familyName));
                pet.Set("rarity", JsonValue(rarity));
                pet.Set("category", JsonValue(category));
                pet.Set("source", JsonValue(source));
                pet.Set("exotic", JsonValue(exotic));
                pets.Push(pet);

                cache.adoptableIds.insert(creatureId);
            } while (result->NextRow());
        }

        JsonValue root;
        root.SetObject();
        root.Set("count", JsonValue(static_cast<uint32>(cache.adoptableIds.size())));
        root.Set("pets", pets);

        cache.payloadJson = root.Encode();
        cache.expiresAtMs = static_cast<uint64>(GameTime::GetGameTimeMS().count()) + CATALOG_CACHE_TTL_MS;
        cache.built = true;
        return cache;
    }

    static CachedCatalog GetCatalog()
    {
        uint64 const nowMs = static_cast<uint64>(GameTime::GetGameTimeMS().count());

        {
            std::lock_guard<std::mutex> lock(sCatalogLock);
            if (sCatalog.built && sCatalog.expiresAtMs > nowMs)
                return sCatalog;
        }

        CachedCatalog fresh = BuildCatalog();

        std::lock_guard<std::mutex> lock(sCatalogLock);
        sCatalog = fresh;
        return sCatalog;
    }

    // Handler: client requests the adoptable pet catalog.
    static void HandleGetCatalog(Player* player, const ParsedMessage& /*msg*/)
    {
        if (!player)
            return;

        CachedCatalog catalog = GetCatalog();

        JsonMessage response(Module::BEASTMASTER, Opcode::Beastmaster::SMSG_CATALOG);
        response.SetPreEncodedJson(catalog.payloadJson);
        response.Send(player);
    }

    // Reply helper for adopt outcomes.
    static void SendAdoptResult(Player* player, bool success, const std::string& reason, uint32 creatureId, const std::string& petName)
    {
        JsonMessage reply(Module::BEASTMASTER, Opcode::Beastmaster::SMSG_ADOPT_RESULT);
        reply.Set("success", JsonValue(success));
        reply.Set("creatureId", JsonValue(creatureId));
        if (!success)
            reply.Set("error", JsonValue(reason));
        else
            reply.Set("petName", JsonValue(petName));
        reply.Send(player);
    }

    // Handler: client adopts a pet by creatureId.
    static void HandleAdopt(Player* player, const ParsedMessage& msg)
    {
        if (!player)
            return;

        JsonValue req = GetJsonData(msg);
        uint32 creatureId = req.IsObject() && req.HasKey("creatureId") ? req["creatureId"].AsUInt32() : 0;
        if (creatureId == 0)
        {
            SendAdoptResult(player, false, "bad_request", 0, "");
            return;
        }

        // Hunters only. The core enforces this in the tame spell, but
        // Player::CreatePet() does not, so gate it here.
        if (!player->IsClass(CLASS_HUNTER))
        {
            SendAdoptResult(player, false, "not_a_hunter", creatureId, "");
            return;
        }

        // Only curated, catalog-listed creatures may be adopted.
        CachedCatalog catalog = GetCatalog();
        if (catalog.adoptableIds.find(creatureId) == catalog.adoptableIds.end())
        {
            SendAdoptResult(player, false, "not_in_catalog", creatureId, "");
            return;
        }

        CreatureTemplate const* ct = sObjectMgr->GetCreatureTemplate(creatureId);
        if (!ct || ct->family == 0)
        {
            // Should not happen (catalog filters these), but CreatePet() would crash.
            SendAdoptResult(player, false, "invalid_pet", creatureId, "");
            return;
        }

        // Exotic families require the Beast Mastery talent, matching retail.
        if (ct->IsExotic() && !player->CanTameExoticPets())
        {
            SendAdoptResult(player, false, "requires_beast_mastery", creatureId, "");
            return;
        }

        if (player->IsExistPet())
        {
            SendAdoptResult(player, false, "already_have_pet", creatureId, "");
            return;
        }

        if (player->IsInCombat())
        {
            SendAdoptResult(player, false, "in_combat", creatureId, "");
            return;
        }

        Pet* pet = player->CreatePet(creatureId);
        if (!pet)
        {
            SendAdoptResult(player, false, "create_failed", creatureId, "");
            return;
        }

        LOG_INFO("dc.addon", "[Beastmaster] {} adopted pet creatureId {} ({})",
            player->GetName(), creatureId, ct->Name);

        SendAdoptResult(player, true, "", creatureId, pet->GetName());
    }

    void RegisterHandlers()
    {
        bool const enabled = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Beastmaster.Enable", true);

        MessageRouter::Instance().SetModuleEnabled(Module::BEASTMASTER, enabled);
        if (!enabled)
            return;

        DC_REGISTER_HANDLER(Module::BEASTMASTER, Opcode::Beastmaster::CMSG_GET_CATALOG, HandleGetCatalog);
        DC_REGISTER_HANDLER(Module::BEASTMASTER, Opcode::Beastmaster::CMSG_ADOPT, HandleAdopt);
        LOG_INFO("dc.addon", "Beastmaster (BEAST) module handlers registered");
    }

} // namespace Beastmaster
} // namespace DCAddon

void AddSC_dc_addon_beastmaster()
{
    DCAddon::Beastmaster::RegisterHandlers();
}
