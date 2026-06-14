/*
 * Dark Chaos - Shapeshift Form Customization Addon Integration
 * ============================================================
 *
 * FORMS feature (part of the COLL / DC-Collection module): lets druids (and,
 * later, shaman ghost wolf) pick an alternate creature display for each of
 * their shapeshift forms - retail "barbershop forms" style.
 *
 * Data model:
 *   - Catalog ......... world table `dc_shapeshift_form_skins` (form, race,
 *                       model, name). The "standard" client models are seeded
 *                       here; custom/unlockable skins can be added later.
 *   - Player choice ... characters table `dc_character_shapeshift_form`
 *                       (guid, form, model). One pick per form.
 *
 * The engine consults the picks via a provider callback registered on
 * ObjectMgr (see ObjectMgr::GetModelForShapeshift). The picks are cached in
 * memory per logged-in character so the hot display-resolution path never
 * touches the DB.
 *
 * Opcodes (Module::COLLECTION):
 *   CMSG_GET_FORMS  -> SMSG_FORMS_DATA
 *   CMSG_SET_FORM   -> SMSG_FORM_RESULT (+ SMSG_FORMS_DATA)
 *   CMSG_RESET_FORM -> SMSG_FORM_RESULT (+ SMSG_FORMS_DATA)
 *
 * Copyright (C) 2025 Dark Chaos Development Team
 */

#include "dc_addon_namespace.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SharedDefines.h"
#include "UnitDefines.h"

#include <map>
#include <mutex>
#include <shared_mutex>
#include <unordered_map>
#include <vector>

namespace DCAddon
{
namespace Forms
{
    using ObjectGuidLow = uint32;

    // --- Catalog (world, read-only after load) ------------------------------
    struct SkinRow
    {
        uint32 model = 0;
        std::string name;
    };

    using FormRaceKey = std::pair<uint8 /*form*/, uint8 /*race*/>;

    static std::map<FormRaceKey, std::vector<SkinRow>> s_catalog;
    static std::map<FormRaceKey, uint32> s_catalogDefault; // is_default model per (form,race)

    // --- Per-character picks (mutable, guarded) -----------------------------
    static std::unordered_map<ObjectGuidLow, std::map<uint8, uint32>> s_picks;
    static std::shared_mutex s_picksMutex;

    // ------------------------------------------------------------------------
    // Form -> class gating. Tauren can be both druid and shaman, so we cannot
    // rely on race alone to decide which forms to offer.
    // ------------------------------------------------------------------------
    static uint8 ClassForForm(uint8 form)
    {
        switch (form)
        {
            case FORM_TREE:
            case FORM_CAT:
            case FORM_TRAVEL:
            case FORM_AQUA:
            case FORM_BEAR:
            case FORM_DIREBEAR:
            case FORM_FLIGHT_EPIC:
            case FORM_FLIGHT:
            case FORM_MOONKIN:
                return CLASS_DRUID;
            case FORM_GHOSTWOLF:
                return CLASS_SHAMAN;
            default:
                return 0;
        }
    }

    static char const* DefaultFormName(uint8 form)
    {
        switch (form)
        {
            case FORM_TREE:        return "Tree of Life";
            case FORM_CAT:         return "Cat Form";
            case FORM_TRAVEL:      return "Travel Form";
            case FORM_AQUA:        return "Aquatic Form";
            case FORM_BEAR:        return "Bear Form";
            case FORM_DIREBEAR:    return "Dire Bear Form";
            case FORM_FLIGHT_EPIC: return "Flight Form";
            case FORM_FLIGHT:      return "Flight Form";
            case FORM_MOONKIN:     return "Moonkin Form";
            case FORM_GHOSTWOLF:   return "Ghost Wolf";
            default:               return "Form";
        }
    }

    static bool ClassHasForms(uint8 playerClass)
    {
        return playerClass == CLASS_DRUID || playerClass == CLASS_SHAMAN;
    }

    // ------------------------------------------------------------------------
    // Table bootstrap (self-creating, mirrors the wardrobe's transmog tables).
    // ------------------------------------------------------------------------
    static void EnsureCharacterTable()
    {
        CharacterDatabase.Execute(
            "CREATE TABLE IF NOT EXISTS `dc_character_shapeshift_form` ("
            "`guid` INT UNSIGNED NOT NULL, "
            "`form` TINYINT UNSIGNED NOT NULL, "
            "`model` INT UNSIGNED NOT NULL, "
            "PRIMARY KEY (`guid`, `form`)) "
            "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    }

    static void EnsureCatalogTable()
    {
        WorldDatabase.Execute(
            "CREATE TABLE IF NOT EXISTS `dc_shapeshift_form_skins` ("
            "`form` TINYINT UNSIGNED NOT NULL, "
            "`race` TINYINT UNSIGNED NOT NULL, "
            "`model` INT UNSIGNED NOT NULL, "
            "`name` VARCHAR(64) NOT NULL DEFAULT '', "
            "`sort_order` INT NOT NULL DEFAULT 0, "
            "`is_default` TINYINT UNSIGNED NOT NULL DEFAULT 0, "
            "PRIMARY KEY (`form`, `race`, `model`)) "
            "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    }

    static void LoadCatalog()
    {
        s_catalog.clear();
        s_catalogDefault.clear();

        QueryResult result = WorldDatabase.Query(
            "SELECT form, race, model, name, is_default FROM dc_shapeshift_form_skins "
            "ORDER BY form, race, sort_order, model");

        uint32 count = 0;
        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                uint8 form = fields[0].Get<uint8>();
                uint8 race = fields[1].Get<uint8>();
                uint32 model = fields[2].Get<uint32>();
                std::string name = fields[3].Get<std::string>();
                bool isDefault = fields[4].Get<uint8>() != 0;

                if (name.empty())
                    name = "Model " + std::to_string(model);

                FormRaceKey key(form, race);
                s_catalog[key].push_back({ model, name });
                if (isDefault)
                    s_catalogDefault[key] = model;
                ++count;
            } while (result->NextRow());
        }

        LOG_INFO("server.loading", ">> Loaded {} DC shapeshift form skins", count);
    }

    static bool CatalogHasSkin(uint8 form, uint8 race, uint32 model)
    {
        // race 0 rows are universal (offered to any druid/shaman).
        for (uint8 r : { race, uint8(0) })
        {
            auto it = s_catalog.find(FormRaceKey(form, r));
            if (it == s_catalog.end())
                continue;
            for (SkinRow const& s : it->second)
                if (s.model == model)
                    return true;
        }
        return false;
    }

    // ------------------------------------------------------------------------
    // Pick cache helpers
    // ------------------------------------------------------------------------
    static uint32 GetPick(ObjectGuidLow guid, uint8 form)
    {
        std::shared_lock<std::shared_mutex> lock(s_picksMutex);
        auto it = s_picks.find(guid);
        if (it == s_picks.end())
            return 0;
        auto f = it->second.find(form);
        return f != it->second.end() ? f->second : 0;
    }

    static void SetPick(ObjectGuidLow guid, uint8 form, uint32 model)
    {
        std::unique_lock<std::shared_mutex> lock(s_picksMutex);
        if (model)
            s_picks[guid][form] = model;
        else
        {
            auto it = s_picks.find(guid);
            if (it != s_picks.end())
                it->second.erase(form);
        }
    }

    static void LoadPicksFor(ObjectGuidLow guid)
    {
        std::map<uint8, uint32> picks;
        if (QueryResult result = CharacterDatabase.Query(
            "SELECT form, model FROM dc_character_shapeshift_form WHERE guid = {}", guid))
        {
            do
            {
                Field* fields = result->Fetch();
                picks[fields[0].Get<uint8>()] = fields[1].Get<uint32>();
            } while (result->NextRow());
        }

        std::unique_lock<std::shared_mutex> lock(s_picksMutex);
        if (picks.empty())
            s_picks.erase(guid);
        else
            s_picks[guid] = std::move(picks);
    }

    static void UnloadPicksFor(ObjectGuidLow guid)
    {
        std::unique_lock<std::shared_mutex> lock(s_picksMutex);
        s_picks.erase(guid);
    }

    // ------------------------------------------------------------------------
    // Outgoing payloads
    // ------------------------------------------------------------------------
    static void SendFormsData(Player* player)
    {
        if (!player)
            return;

        uint8 playerClass = player->getClass();
        uint8 race = player->getRace();
        ObjectGuidLow guid = player->GetGUID().GetCounter();

        JsonValue forms;
        forms.SetArray();

        bool available = false;
        if (ClassHasForms(playerClass))
        {
            // Merge this race's skins with the universal race-0 catalog so a
            // player sees their own race skins plus all cross-race options.
            std::map<uint8, std::vector<SkinRow>> byForm;
            for (auto const& [key, skins] : s_catalog)
            {
                if (key.second != race && key.second != 0)
                    continue;
                if (ClassForForm(key.first) != playerClass)
                    continue;
                auto& dst = byForm[key.first];
                dst.insert(dst.end(), skins.begin(), skins.end());
            }

            for (auto const& [form, skins] : byForm)
            {
                if (skins.empty())
                    continue;

                available = true;

                JsonValue entry;
                entry.SetObject();
                entry.Set("form", JsonValue(static_cast<int32>(form)));
                entry.Set("name", JsonValue(std::string(DefaultFormName(form))));

                uint32 def = 0;
                auto defIt = s_catalogDefault.find(FormRaceKey(form, race));
                if (defIt == s_catalogDefault.end())
                    defIt = s_catalogDefault.find(FormRaceKey(form, 0));
                if (defIt != s_catalogDefault.end())
                    def = defIt->second;
                entry.Set("default", JsonValue(static_cast<int32>(def)));
                entry.Set("current", JsonValue(static_cast<int32>(GetPick(guid, form))));

                JsonValue skinArr;
                skinArr.SetArray();
                for (SkinRow const& s : skins)
                {
                    JsonValue skin;
                    skin.SetObject();
                    skin.Set("model", JsonValue(static_cast<int32>(s.model)));
                    skin.Set("name", JsonValue(s.name));
                    skin.Set("source", JsonValue(std::string("standard")));
                    skinArr.Push(skin);
                }
                entry.Set("skins", skinArr);

                forms.Push(entry);
            }
        }

        JsonMessage msg(Module::COLLECTION, Opcode::Collection::SMSG_FORMS_DATA);
        msg.Set("available", available);
        msg.Set("class", static_cast<uint32>(playerClass));
        msg.Set("forms", forms);
        msg.Send(player);
    }

    static void SendFormResult(Player* player, uint8 form, uint32 model,
        bool success, std::string const& error = std::string())
    {
        JsonMessage msg(Module::COLLECTION, Opcode::Collection::SMSG_FORM_RESULT);
        msg.Set("form", static_cast<uint32>(form));
        msg.Set("model", model);
        msg.Set("success", success);
        if (!success && !error.empty())
            msg.Set("error", error);
        msg.Send(player);
    }

    // Re-apply the active form display if the player is currently shifted into
    // the form whose appearance just changed.
    static void RefreshActiveForm(Player* player, uint8 form)
    {
        if (player->GetShapeshiftForm() == ShapeshiftForm(form))
            player->RestoreDisplayId();
    }

    // ------------------------------------------------------------------------
    // Handlers
    // ------------------------------------------------------------------------
    static void HandleGetForms(Player* player, ParsedMessage const& /*msg*/)
    {
        if (!player)
            return;
        SendFormsData(player);
    }

    static void HandleSetForm(Player* player, ParsedMessage const& msg)
    {
        if (!player)
            return;

        JsonValue json = GetJsonData(msg);
        uint8 form = static_cast<uint8>(json["form"].AsUInt32());
        uint32 model = json["model"].AsUInt32();

        if (!ClassHasForms(player->getClass())
            || ClassForForm(form) != player->getClass())
        {
            SendFormResult(player, form, model, false, "form_not_available");
            return;
        }

        if (!CatalogHasSkin(form, player->getRace(), model))
        {
            SendFormResult(player, form, model, false, "skin_not_unlocked");
            return;
        }

        ObjectGuidLow guid = player->GetGUID().GetCounter();
        CharacterDatabase.Execute(
            "REPLACE INTO dc_character_shapeshift_form (guid, form, model) VALUES ({}, {}, {})",
            guid, static_cast<uint32>(form), model);

        SetPick(guid, form, model);
        RefreshActiveForm(player, form);

        SendFormResult(player, form, model, true);
        SendFormsData(player);
    }

    static void HandleResetForm(Player* player, ParsedMessage const& msg)
    {
        if (!player)
            return;

        JsonValue json = GetJsonData(msg);
        uint8 form = static_cast<uint8>(json["form"].AsUInt32());

        ObjectGuidLow guid = player->GetGUID().GetCounter();
        CharacterDatabase.Execute(
            "DELETE FROM dc_character_shapeshift_form WHERE guid = {} AND form = {}",
            guid, static_cast<uint32>(form));

        SetPick(guid, form, 0);
        RefreshActiveForm(player, form);

        SendFormResult(player, form, 0, true);
        SendFormsData(player);
    }

    // ------------------------------------------------------------------------
    // Player lifecycle: load/unload the in-memory pick cache.
    // ------------------------------------------------------------------------
    class FormsPlayerScript : public PlayerScript
    {
    public:
        FormsPlayerScript() : PlayerScript("dc_forms_player") {}

        void OnPlayerLogin(Player* player) override
        {
            if (player)
                LoadPicksFor(player->GetGUID().GetCounter());
        }

        void OnPlayerLogout(Player* player) override
        {
            if (player)
                UnloadPicksFor(player->GetGUID().GetCounter());
        }
    };

    static void RegisterHandlers()
    {
        if (!sConfigMgr->GetOption<bool>("DC.AddonProtocol.Forms.Enable", true))
            return;

        EnsureCharacterTable();
        EnsureCatalogTable();
        LoadCatalog();

        DC_REGISTER_HANDLER(Module::COLLECTION,
            Opcode::Collection::CMSG_GET_FORMS, HandleGetForms);
        DC_REGISTER_HANDLER(Module::COLLECTION,
            Opcode::Collection::CMSG_SET_FORM, HandleSetForm);
        DC_REGISTER_HANDLER(Module::COLLECTION,
            Opcode::Collection::CMSG_RESET_FORM, HandleResetForm);

        // Provider callback consulted by ObjectMgr::GetModelForShapeshift.
        sObjectMgr->SetShapeshiftFormModelOverride(
            [](Player const* p, uint8 form) -> uint32
            {
                if (!p)
                    return 0;
                return GetPick(p->GetGUID().GetCounter(), form);
            });

        new FormsPlayerScript();
    }
}
}

void AddSC_dc_addon_forms()
{
    DCAddon::Forms::RegisterHandlers();
}
