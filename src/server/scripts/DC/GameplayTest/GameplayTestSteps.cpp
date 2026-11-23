/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * Gameplay test harness: scenario validation, step actions and metrics.
 * The schema is documented in apps/gameplay-test/README.md; keep the two (and
 * the offline validator in apps/gameplay-test/run.py) in step.
 *
 * World thread only (see GameplayTestRunner.h). Every unit a step touches is
 * resolved from the run's own references - an actor of the lab account or an
 * object the run spawned - so a step can never reach a real player.
 */

#include "GameplayTestRunner.h"
#include "Bag.h"
#include "Creature.h"
#include "DBCStores.h"
#include "DCItemUpgradeApi.h"
#include "GameObject.h"
#include "Item.h"
#include "ItemPackets.h"
#include "Log.h"
#include "Map.h"
#include "ObjectMgr.h"
#include "Opcodes.h"
#include "Player.h"
#include "QuestDef.h"
#include "SpellAuras.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "StringFormat.h"
#include "TemporarySummon.h"
#include "World.h"
#include "WorldPacket.h"
#include "WorldSession.h"
#include "DC/DungeonQoL/dc_dungeon_qol.h"
#include "DC/MythicPlus/dc_mythicplus_run_manager.h"
#include "DC/Progression/Prestige/dc_prestige_api.h"
#include <algorithm>
#include <cctype>
#include <cmath>
#include <set>
#include <unordered_map>

namespace DC::GameplayTest
{
    namespace
    {
        constexpr uint32 PENDING_GRACE_MS = 5000;
        constexpr uint32 DEFAULT_STEP_TIMEOUT_MS = 5000;
        constexpr uint32 TELEPORT_TIMEOUT_MS = 15000;
        constexpr uint32 UNTIL_TIMEOUT_MS = 10000;
        constexpr uint32 MAX_ITEM_COUNT = 1000;
        constexpr double DEFAULT_TOLERANCE = 0.0001;

        // What a step needs besides "action". Refs are checked separately.
        struct ActionSpec
        {
            std::vector<char const*> required;
        };

        std::unordered_map<std::string, ActionSpec> const& Actions()
        {
            static std::unordered_map<std::string, ActionSpec> const actions =
            {
                { "teleport",          { {} } },
                { "set_level",         { { "level" } } },
                { "learn",             { { "spell" } } },
                { "unlearn",           { { "spell" } } },
                { "add_item",          { { "item" } } },
                { "remove_item",       { { "item" } } },
                { "equip",             { { "item" } } },
                { "cast",              { { "spell" } } },
                { "add_aura",          { { "spell", "target" } } },
                { "remove_aura",       { { "spell", "target" } } },
                { "spawn",             { { "id", "entry" } } },
                { "spawn_object",      { { "id", "entry" } } },
                { "despawn",           { { "target" } } },
                { "kill",              { { "target" } } },
                { "revive",            { {} } },
                { "accept_resurrect",  { {} } },
                { "set_health",        { { "target" } } },
                { "set_power",         { { "target", "value" } } },
                { "set_money",         { { "copper" } } },
                { "quest_add",         { { "quest" } } },
                { "quest_complete",    { { "quest" } } },
                { "quest_remove",      { { "quest" } } },
                { "item_upgrade",      { { "slot" } } },
                { "prestige",          { {} } },
                { "wait",              { {} } },
                { "assert",            { { "metric" } } },
                { "snapshot",          { { "metric", "save_as" } } },
                { "log",               { { "message" } } },
            };
            return actions;
        }

        // Metric name -> the extra key it needs ("" for none).
        std::unordered_map<std::string, char const*> const& Metrics()
        {
            static std::unordered_map<std::string, char const*> const metrics =
            {
                { "health", "" }, { "max_health", "" }, { "health_pct", "" },
                { "power", "" }, { "max_power", "" }, { "level", "" }, { "alive", "" }, { "in_combat", "" },
                { "display_id", "" }, { "native_display_id", "" }, { "phase_mask", "" }, { "map_id", "" },
                { "zone_id", "" }, { "exists", "" }, { "creature_alive", "" },
                { "aura", "spell" }, { "aura_stacks", "spell" }, { "aura_charges", "spell" },
                { "aura_duration_ms", "spell" }, { "stat", "stat" }, { "knows_spell", "spell" },
                { "item_count", "item" }, { "equipped_item", "slot" }, { "quest_status", "quest" },
                { "quest_rewarded", "quest" }, { "money", "" }, { "distance", "target" },
                { "resurrect_requested", "" },
                { "mplus_active", "" }, { "mplus_keystone_level", "" }, { "mplus_run_deaths", "" },
                { "mplus_can_activate", "target" }, { "mplus_activation_error", "target" },
                { "battle_res_charges", "" },
                { "prestige_level", "" }, { "prestige_refusal", "" }, { "prestige_restart_level", "" },
                { "item_upgrade_level", "slot" }, { "upgrade_currency", "currency" },
            };
            return metrics;
        }

        bool IsIdentifier(std::string const& id)
        {
            if (id.empty() || id.size() > 32)
                return false;
            return std::all_of(id.begin(), id.end(), [](unsigned char c)
            {
                return std::islower(c) || std::isdigit(c) || c == '_' || c == '-';
            });
        }

        bool StatIndex(std::string const& name, Stats& out)
        {
            static std::unordered_map<std::string, Stats> const stats =
            {
                { "strength", STAT_STRENGTH }, { "agility", STAT_AGILITY }, { "stamina", STAT_STAMINA },
                { "intellect", STAT_INTELLECT }, { "spirit", STAT_SPIRIT },
            };
            auto it = stats.find(name);
            if (it == stats.end())
                return false;
            out = it->second;
            return true;
        }

        bool PowerIndex(JsonValue const& spec, Unit const* unit, Powers& out)
        {
            JsonValue const* power = spec.Find("power");
            if (!power)
            {
                out = unit->getPowerType();
                return true;
            }

            if (power->IsNumber())
            {
                if (power->AsNumber() < 0.0 || power->AsNumber() >= double(uint32(MAX_POWERS)))
                    return false;
                out = Powers(uint32(power->AsNumber()));
                return true;
            }

            static std::unordered_map<std::string, Powers> const powers =
            {
                { "mana", POWER_MANA }, { "rage", POWER_RAGE }, { "focus", POWER_FOCUS }, { "energy", POWER_ENERGY },
                { "happiness", POWER_HAPPINESS }, { "runes", POWER_RUNE }, { "runic_power", POWER_RUNIC_POWER },
            };
            auto it = power->IsString() ? powers.find(power->AsString()) : powers.end();
            if (it == powers.end())
                return false;
            out = it->second;
            return true;
        }

        bool CurrencyIndex(std::string const& name, DarkChaos::ItemUpgradeApi::Currency& out)
        {
            namespace Api = DarkChaos::ItemUpgradeApi;
            if (name == "token")
                out = Api::CURRENCY_UPGRADE_TOKEN;
            else if (name == "essence")
                out = Api::CURRENCY_ARTIFACT_ESSENCE;
            else if (name == "sap")
                out = Api::CURRENCY_FRONTIER_SAP;
            else
                return false;
            return true;
        }

        Item* FindBagItem(Player* player, uint32 entry)
        {
            for (uint8 slot = INVENTORY_SLOT_ITEM_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
                if (Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot))
                    if (item->GetEntry() == entry)
                        return item;

            for (uint8 bagSlot = INVENTORY_SLOT_BAG_START; bagSlot < INVENTORY_SLOT_BAG_END; ++bagSlot)
                if (Bag* bag = player->GetBagByPos(bagSlot))
                    for (uint32 slot = 0; slot < bag->GetBagSize(); ++slot)
                        if (Item* item = bag->GetItemByPos(uint8(slot)))
                            if (item->GetEntry() == entry)
                                return item;

            return nullptr;
        }

        void ApplyLevel(Player* player, uint8 level)
        {
            if (player->GetLevel() == level)
                return;
            player->GiveLevel(level);
            player->InitTalentForLevel();
            player->SetUInt32Value(PLAYER_XP, 0);
        }

        Outcome StepError(StepRecord& record, std::string message)
        {
            record.message = std::move(message);
            return Outcome::Error;
        }

        Outcome StepFail(StepRecord& record, std::string message)
        {
            record.message = std::move(message);
            return Outcome::Fail;
        }

        MetricResult MetricOk(double number, std::string detail = {})
        {
            return { Eval::Ok, Value::Number(number), std::move(detail) };
        }

        MetricResult MetricText(std::string text)
        {
            return { Eval::Ok, Value::Text(std::move(text)), {} };
        }

        MetricResult MetricPending(std::string why)
        {
            return { Eval::Pending, Value(), std::move(why) };
        }

        MetricResult MetricError(std::string why)
        {
            return { Eval::Error, Value(), std::move(why) };
        }

        // All comparators present must hold. Returns the first one that does not.
        bool Compare(Value const& value, JsonValue const& spec, std::string& why)
        {
            double const tolerance = spec.GetNumber("tolerance", DEFAULT_TOLERANCE);
            auto numberOf = [](JsonValue const& expected, double& out)
            {
                if (expected.IsNumber())
                    out = expected.AsNumber();
                else if (expected.IsBool())
                    out = expected.AsBool() ? 1.0 : 0.0;
                else
                    return false;
                return true;
            };

            auto equalsExpected = [&](JsonValue const& expected) -> bool
            {
                if (expected.IsString())
                    return value.kind == Value::Kind::Text && value.text == expected.AsString();

                double number = 0.0;
                return numberOf(expected, number) && value.kind == Value::Kind::Number &&
                    std::fabs(value.number - number) <= tolerance;
            };

            if (JsonValue const* expected = spec.Find("equals"))
            {
                if (!equalsExpected(*expected))
                {
                    why = "expected " + expected->Dump(false) + ", got " + value.ToString();
                    return false;
                }
            }

            if (JsonValue const* expected = spec.Find("not_equals"))
            {
                if (equalsExpected(*expected))
                {
                    why = "expected anything but " + expected->Dump(false);
                    return false;
                }
            }

            if (JsonValue const* bound = spec.Find("min"))
            {
                if (value.kind != Value::Kind::Number || value.number < bound->AsNumber() - tolerance)
                {
                    why = "expected at least " + bound->Dump(false) + ", got " + value.ToString();
                    return false;
                }
            }

            if (JsonValue const* bound = spec.Find("max"))
            {
                if (value.kind != Value::Kind::Number || value.number > bound->AsNumber() + tolerance)
                {
                    why = "expected at most " + bound->Dump(false) + ", got " + value.ToString();
                    return false;
                }
            }

            if (JsonValue const* needle = spec.Find("contains"))
            {
                if (value.kind != Value::Kind::Text || value.text.find(needle->AsString()) == std::string::npos)
                {
                    why = "expected text containing " + needle->Dump(false) + ", got " + value.ToString();
                    return false;
                }
            }

            if (JsonValue const* needle = spec.Find("not_contains"))
            {
                if (value.kind != Value::Kind::Text || value.text.find(needle->AsString()) != std::string::npos)
                {
                    why = "expected text without " + needle->Dump(false) + ", got " + value.ToString();
                    return false;
                }
            }

            return true;
        }

        // ------------------------------------------------------------------
        // Validation
        // ------------------------------------------------------------------

        struct ValidationContext
        {
            Config const& config;
            std::set<std::string> actors;
            std::set<std::string> spawns;
            std::set<std::string> vars;
            bool destructive = false;
            uint32 spawnCount = 0;
        };

        bool CheckUnitRef(ValidationContext const& ctx, JsonValue const& step, char const* key, bool actorOnly,
            std::string& error)
        {
            JsonValue const* ref = step.Find(key);
            if (!ref)
                return true;

            if (!ref->IsString())
            {
                error = Acore::StringFormat("\"{}\" must be a string reference", key);
                return false;
            }

            std::string const& id = ref->AsString();
            if (ctx.actors.count(id) || (!actorOnly && ctx.spawns.count(id)))
                return true;

            error = Acore::StringFormat("\"{}\": unknown {} '{}'{}", key, actorOnly ? "actor" : "reference", id,
                actorOnly ? "" : " (actors and objects spawned by an earlier step)");
            return false;
        }

        bool CheckGameData(JsonValue const& step, std::string& error)
        {
            if (JsonValue const* spell = step.Find("spell"))
            {
                if (!spell->IsNumber() || !sSpellMgr->GetSpellInfo(uint32(spell->AsNumber())))
                {
                    error = "unknown spell " + spell->Dump(false);
                    return false;
                }
            }

            if (JsonValue const* item = step.Find("item"))
            {
                if (!item->IsNumber() || !sObjectMgr->GetItemTemplate(uint32(item->AsNumber())))
                {
                    error = "unknown item " + item->Dump(false);
                    return false;
                }
            }

            if (JsonValue const* quest = step.Find("quest"))
            {
                if (!quest->IsNumber() || !sObjectMgr->GetQuestTemplate(uint32(quest->AsNumber())))
                {
                    error = "unknown quest " + quest->Dump(false);
                    return false;
                }
            }

            if (JsonValue const* slot = step.Find("slot"))
            {
                double const last = double(uint32(EQUIPMENT_SLOT_END));
                if (!slot->IsNumber() || slot->AsNumber() < 0.0 || slot->AsNumber() >= last)
                {
                    error = Acore::StringFormat("slot must be an equipment slot 0-{}", EQUIPMENT_SLOT_END - 1);
                    return false;
                }
            }

            return true;
        }

        bool ValidateMetricSpec(ValidationContext const& ctx, JsonValue const& spec, bool assertion, std::string& error)
        {
            std::string const metric = spec.GetString("metric");
            auto it = Metrics().find(metric);
            if (it == Metrics().end())
            {
                error = "unknown metric '" + metric + "'";
                return false;
            }

            if (*it->second && !spec.Has(it->second))
            {
                error = Acore::StringFormat("metric '{}' needs \"{}\"", metric, it->second);
                return false;
            }

            if (metric == "stat")
            {
                Stats stat = STAT_STRENGTH;
                if (!StatIndex(spec.GetString("stat"), stat))
                {
                    error = "\"stat\" must be strength, agility, stamina, intellect or spirit";
                    return false;
                }
            }

            if (metric == "upgrade_currency")
            {
                DarkChaos::ItemUpgradeApi::Currency currency = DarkChaos::ItemUpgradeApi::CURRENCY_NONE;
                if (!CurrencyIndex(spec.GetString("currency"), currency))
                {
                    error = "\"currency\" must be token, essence or sap";
                    return false;
                }
            }

            if (!CheckUnitRef(ctx, spec, "unit", false, error) || !CheckUnitRef(ctx, spec, "target", false, error) ||
                !CheckUnitRef(ctx, spec, "caster", false, error) || !CheckGameData(spec, error))
                return false;

            if (JsonValue const* relative = spec.Find("relative_to"))
            {
                if (!relative->IsString() || !ctx.vars.count(relative->AsString()))
                {
                    error = "\"relative_to\" must name a value saved by an earlier snapshot";
                    return false;
                }
            }

            if (!assertion)
                return true;

            static char const* const comparators[] =
            {
                "equals", "not_equals", "min", "max", "contains", "not_contains"
            };
            bool any = false;
            for (char const* key : comparators)
            {
                JsonValue const* value = spec.Find(key);
                if (!value)
                    continue;
                any = true;

                bool const textual = std::string_view(key).find("contains") != std::string_view::npos;
                bool const numeric = std::string_view(key) == "min" || std::string_view(key) == "max";
                if ((textual && !value->IsString()) || (numeric && !value->IsNumber()) ||
                    (!textual && !numeric && !value->IsNumber() && !value->IsString() && !value->IsBool()))
                {
                    error = Acore::StringFormat("\"{}\" has the wrong type", key);
                    return false;
                }
            }

            if (!any)
            {
                error = "an assertion needs equals, not_equals, min, max, contains or not_contains";
                return false;
            }

            return true;
        }

        bool ValidateStep(ValidationContext& ctx, JsonValue const& step, std::string& error)
        {
            if (!step.IsObject())
            {
                error = "a step must be an object";
                return false;
            }

            std::string const action = step.GetString("action");
            auto it = Actions().find(action);
            if (it == Actions().end())
            {
                error = "unknown action '" + action + "'";
                return false;
            }

            for (char const* key : it->second.required)
            {
                if (!step.Has(key))
                {
                    error = Acore::StringFormat("action '{}' needs \"{}\"", action, key);
                    return false;
                }
            }

            if (JsonValue const* timeout = step.Find("timeout_ms"))
            {
                if (!timeout->IsNumber() || timeout->AsNumber() < 0)
                {
                    error = "\"timeout_ms\" must be a non-negative number";
                    return false;
                }
            }

            if (!CheckUnitRef(ctx, step, "actor", true, error))
                return false;

            if (action == "assert" || action == "snapshot")
            {
                if (!ValidateMetricSpec(ctx, step, action == "assert", error))
                    return false;
                if (action == "snapshot")
                {
                    std::string const name = step.GetString("save_as");
                    if (!IsIdentifier(name))
                    {
                        error = "\"save_as\" must be a lower-case identifier";
                        return false;
                    }
                    ctx.vars.insert(name);
                }
                return true;
            }

            if (action == "wait")
            {
                JsonValue const* until = step.Find("until");
                if (!step.Has("ms") && !until)
                {
                    error = "wait needs \"ms\" or \"until\"";
                    return false;
                }
                if (until)
                {
                    if (!until->IsObject())
                    {
                        error = "\"until\" must be an assertion object";
                        return false;
                    }
                    if (!ValidateMetricSpec(ctx, *until, true, error))
                    {
                        error = "until: " + error;
                        return false;
                    }
                }
                return true;
            }

            if (!CheckUnitRef(ctx, step, "target", false, error) || !CheckUnitRef(ctx, step, "caster", false, error) ||
                !CheckGameData(step, error))
                return false;

            if (action == "teleport")
            {
                bool const coordinates = step.Has("map") && step.Has("x") && step.Has("y") && step.Has("z");
                if (!coordinates && !step.Has("to"))
                {
                    error = "teleport needs map/x/y/z or \"to\"";
                    return false;
                }
                if (!CheckUnitRef(ctx, step, "to", false, error))
                    return false;
                if (coordinates && !sMapStore.LookupEntry(step.GetUInt("map")))
                {
                    error = "unknown map " + std::to_string(step.GetUInt("map"));
                    return false;
                }
            }
            else if (action == "set_level")
            {
                uint32 const level = step.GetUInt("level");
                if (!level || level > sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL))
                {
                    error = Acore::StringFormat("level must be 1-{}", sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL));
                    return false;
                }
            }
            else if (action == "spawn" || action == "spawn_object")
            {
                std::string const id = step.GetString("id");
                if (!IsIdentifier(id) || ctx.actors.count(id) || ctx.spawns.count(id))
                {
                    error = "\"id\" must be a new lower-case identifier, not used by an actor or another spawn";
                    return false;
                }

                uint32 const entry = step.GetUInt("entry");
                bool const known = action == "spawn" ? sObjectMgr->GetCreatureTemplate(entry) != nullptr :
                    sObjectMgr->GetGameObjectTemplate(entry) != nullptr;
                if (!known)
                {
                    error = Acore::StringFormat("unknown {} entry {}", action == "spawn" ? "creature" : "gameobject",
                        entry);
                    return false;
                }

                if (++ctx.spawnCount > ctx.config.maxSpawns)
                {
                    error = Acore::StringFormat("more spawns than DC.GameplayTest.MaxSpawns ({})",
                        ctx.config.maxSpawns);
                    return false;
                }
                ctx.spawns.insert(id);
            }
            else if (action == "add_item" || action == "remove_item")
            {
                if (step.GetUInt("count", 1) == 0 || step.GetUInt("count", 1) > MAX_ITEM_COUNT)
                {
                    error = Acore::StringFormat("count must be 1-{}", MAX_ITEM_COUNT);
                    return false;
                }
            }
            else if (action == "item_upgrade")
            {
                if (!DarkChaos::ItemUpgradeApi::GetProvider())
                {
                    error = "item_upgrade needs the DC item upgrade scripts, which are not loaded";
                    return false;
                }
            }
            else if (action == "prestige")
            {
                if (!ctx.destructive)
                {
                    error = "prestige changes persistent progression; mark the scenario \"destructive\": true";
                    return false;
                }
            }
            else if (action == "set_health")
            {
                if (!step.Has("pct") && !step.Has("value"))
                {
                    error = "set_health needs \"pct\" or \"value\"";
                    return false;
                }
            }

            return true;
        }
    }

    bool ValidateScenario(JsonValue const& scenario, Config const& config, std::string& error)
    {
        if (!scenario.IsObject())
        {
            error = "the scenario must be a JSON object";
            return false;
        }

        if (scenario.GetUInt("schema") != SCENARIO_SCHEMA)
        {
            error = Acore::StringFormat("\"schema\" must be {}", SCENARIO_SCHEMA);
            return false;
        }

        if (scenario.GetString("name").empty())
        {
            error = "\"name\" is required";
            return false;
        }

        if (JsonValue const* location = scenario.Find("location"))
        {
            if (!location->IsObject() || !location->Has("map") || !location->Has("x") || !location->Has("y") ||
                !location->Has("z"))
            {
                error = "\"location\" needs map, x, y and z";
                return false;
            }
            if (!sMapStore.LookupEntry(location->GetUInt("map")))
            {
                error = "\"location\": unknown map " + std::to_string(location->GetUInt("map"));
                return false;
            }
        }

        ValidationContext ctx{ config, {}, {}, {}, scenario.GetBool("destructive", false), 0 };

        JsonValue const* actors = scenario.Find("actors");
        if (!actors || !actors->IsArray() || actors->Items().empty())
        {
            error = "\"actors\" must be a non-empty array";
            return false;
        }

        if (actors->Items().size() > config.maxActors)
        {
            error = Acore::StringFormat("more actors than DC.GameplayTest.MaxActors ({})", config.maxActors);
            return false;
        }

        std::set<std::string> names;
        for (JsonValue const& actor : actors->Items())
        {
            std::string const id = actor.GetString("id");
            std::string const name = actor.GetString("name");
            if (!IsIdentifier(id) || ctx.actors.count(id))
            {
                error = "every actor needs a unique lower-case \"id\"";
                return false;
            }
            if (name.empty() || !names.insert(name).second)
            {
                error = "actor " + id + ": every actor needs a unique character \"name\"";
                return false;
            }

            std::string const session = actor.GetString("session", "auto");
            if (session != "auto" && session != "headless" && session != "online")
            {
                error = "actor " + id + ": \"session\" must be auto, headless or online";
                return false;
            }

            if (JsonValue const* create = actor.Find("create"))
            {
                if (!create->IsObject() || !create->Has("race") || !create->Has("class"))
                {
                    error = "actor " + id + ": \"create\" needs race and class";
                    return false;
                }
            }

            if (uint32 const level = actor.GetUInt("level"))
            {
                if (level > sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL))
                {
                    error = "actor " + id + ": level above the server's MaxPlayerLevel";
                    return false;
                }
            }

            ctx.actors.insert(id);
        }

        JsonValue const* steps = scenario.Find("steps");
        if (!steps || !steps->IsArray() || steps->Items().empty() || steps->Items().size() > MAX_STEPS)
        {
            error = Acore::StringFormat("\"steps\" must be an array of 1-{} steps", MAX_STEPS);
            return false;
        }

        for (std::size_t i = 0; i < steps->Items().size(); ++i)
        {
            std::string stepError;
            if (!ValidateStep(ctx, steps->Items()[i], stepError))
            {
                error = Acore::StringFormat("step {} ({}): {}", i, steps->Items()[i].GetString("action", "?"),
                    stepError);
                return false;
            }
        }

        return true;
    }

    // ------------------------------------------------------------------
    // Metrics
    // ------------------------------------------------------------------

    MetricResult Runner::EvaluateMetric(Run& run, JsonValue const& spec)
    {
        std::string const metric = spec.GetString("metric");
        std::string const unitRef = spec.GetString("unit", DefaultActorId(run));

        // These two answer "no" for a unit that is gone instead of waiting for it.
        if (metric == "exists")
            return MetricOk(ResolveObject(run, unitRef) ? 1.0 : 0.0);
        if (metric == "creature_alive")
        {
            Unit* unit = ResolveUnit(run, unitRef);
            return MetricOk(unit && unit->IsAlive() ? 1.0 : 0.0);
        }

        WorldObject* object = ResolveObject(run, unitRef);
        if (!object)
            return MetricPending("'" + unitRef + "' is not in the world");

        if (metric == "phase_mask")
            return MetricOk(object->GetPhaseMask());
        if (metric == "map_id")
            return MetricOk(object->GetMapId());
        if (metric == "zone_id")
            return MetricOk(object->GetZoneId());
        if (metric == "distance")
        {
            WorldObject* other = ResolveObject(run, spec.GetString("target"));
            if (!other)
                return MetricPending("'" + spec.GetString("target") + "' is not in the world");
            if (other->GetMapId() != object->GetMapId() || other->GetInstanceId() != object->GetInstanceId())
                return MetricPending("the two objects are on different maps");
            return MetricOk(object->GetExactDist(other));
        }

        Map* map = object->GetMap();
        if (metric == "mplus_active")
            return MetricOk(sMythicRuns->IsMythicPlusActive(map) ? 1.0 : 0.0);
        if (metric == "mplus_keystone_level")
            return MetricOk(sMythicRuns->GetKeystoneLevel(map));
        if (metric == "mplus_run_deaths")
        {
            // Read within this call only: the state belongs to the run manager.
            MythicPlusRunManager::InstanceState const* state = sMythicRuns->GetRunState(map);
            return MetricOk(state ? double(state->deaths) : -1.0);
        }
        if (metric == "battle_res_charges")
        {
            uint32 remaining = 0;
            uint32 total = 0;
            if (!DC::DungeonQoL::GetBattleResCharges(map, remaining, total))
                return MetricOk(-1.0, "no battle resurrection limit applies here");
            return MetricOk(remaining, Acore::StringFormat("{} of {} left", remaining, total));
        }

        Unit* unit = object->ToUnit();
        if (!unit)
            return MetricError("metric '" + metric + "' needs a unit, '" + unitRef + "' is a gameobject");

        if (metric == "health")
            return MetricOk(unit->GetHealth());
        if (metric == "max_health")
            return MetricOk(unit->GetMaxHealth());
        if (metric == "health_pct")
            return MetricOk(unit->GetHealthPct());
        if (metric == "level")
            return MetricOk(unit->GetLevel());
        if (metric == "alive")
            return MetricOk(unit->IsAlive() ? 1.0 : 0.0);
        if (metric == "in_combat")
            return MetricOk(unit->IsInCombat() ? 1.0 : 0.0);
        if (metric == "display_id")
            return MetricOk(unit->GetDisplayId());
        if (metric == "native_display_id")
            return MetricOk(unit->GetNativeDisplayId());
        if (metric == "power" || metric == "max_power")
        {
            Powers power = POWER_MANA;
            if (!PowerIndex(spec, unit, power))
                return MetricError("\"power\" must be mana, rage, focus, energy, happiness, runes, runic_power or 0-6");
            return MetricOk(metric == "power" ? unit->GetPower(power) : unit->GetMaxPower(power));
        }
        if (metric == "stat")
        {
            Stats stat = STAT_STRENGTH;
            if (!StatIndex(spec.GetString("stat"), stat))
                return MetricError("unknown stat");
            return MetricOk(unit->GetStat(stat));
        }
        if (metric.rfind("aura", 0) == 0)
        {
            ObjectGuid casterGuid;
            if (spec.Has("caster"))
            {
                Unit* caster = ResolveUnit(run, spec.GetString("caster"));
                if (!caster)
                    return MetricPending("caster '" + spec.GetString("caster") + "' is not in the world");
                casterGuid = caster->GetGUID();
            }

            Aura const* aura = unit->GetAura(spec.GetUInt("spell"), casterGuid);
            if (metric == "aura")
                return MetricOk(aura ? 1.0 : 0.0);
            if (metric == "aura_stacks")
                return MetricOk(aura ? aura->GetStackAmount() : 0);
            if (metric == "aura_charges")
                return MetricOk(aura ? aura->GetCharges() : 0);
            return MetricOk(aura ? aura->GetDuration() : 0);
        }

        Player* player = unit->ToPlayer();
        if (!player)
            return MetricError("metric '" + metric + "' needs a player actor, '" + unitRef + "' is a creature");

        if (metric == "knows_spell")
            return MetricOk(player->HasSpell(spec.GetUInt("spell")) ? 1.0 : 0.0);
        if (metric == "item_count")
            return MetricOk(player->GetItemCount(spec.GetUInt("item"), spec.GetBool("bank", false)));
        if (metric == "equipped_item")
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, uint8(spec.GetUInt("slot")));
            return MetricOk(item ? item->GetEntry() : 0);
        }
        if (metric == "quest_status")
            return MetricOk(uint32(player->GetQuestStatus(spec.GetUInt("quest"))));
        if (metric == "quest_rewarded")
            return MetricOk(player->GetQuestRewardStatus(spec.GetUInt("quest")) ? 1.0 : 0.0);
        if (metric == "money")
            return MetricOk(player->GetMoney());
        if (metric == "resurrect_requested")
            return MetricOk(player->isResurrectRequested() ? 1.0 : 0.0);

        if (metric == "mplus_can_activate" || metric == "mplus_activation_error")
        {
            GameObject* font = ResolveGameObject(run, spec.GetString("target"));
            if (!font)
                return MetricPending("font '" + spec.GetString("target") + "' is not in the world");

            KeystoneDescriptor descriptor;
            std::string refusal;
            bool const allowed = sMythicRuns->CanActivateKeystone(player, font, descriptor, refusal,
                uint8(spec.GetUInt("forced_level", 0)));
            if (metric == "mplus_activation_error")
                return MetricText(refusal);
            return MetricOk(allowed ? 1.0 : 0.0, refusal);
        }

        if (metric == "prestige_level")
            return MetricOk(PrestigeAPI::GetPrestigeLevel(player));
        if (metric == "prestige_refusal")
            return MetricText(PrestigeAPI::GetPrestigeRefusal(player));
        if (metric == "prestige_restart_level")
            return MetricOk(PrestigeAPI::GetRestartLevel(player));

        if (metric == "item_upgrade_level" || metric == "upgrade_currency")
        {
            DarkChaos::ItemUpgradeApi::Provider* provider = DarkChaos::ItemUpgradeApi::GetProvider();
            if (!provider)
                return MetricError("the DC item upgrade scripts are not loaded");

            if (metric == "upgrade_currency")
            {
                DarkChaos::ItemUpgradeApi::Currency currency = DarkChaos::ItemUpgradeApi::CURRENCY_NONE;
                if (!CurrencyIndex(spec.GetString("currency"), currency))
                    return MetricError("unknown currency");
                return MetricOk(provider->GetCurrencyAmount(player, currency));
            }

            DarkChaos::ItemUpgradeApi::SlotUpgradeInfo info;
            if (!provider->DescribeEquippedSlot(player, uint8(spec.GetUInt("slot")), info))
                return MetricError(Acore::StringFormat("slot {} holds nothing the upgrade system handles",
                    spec.GetUInt("slot")));

            if (!info.stateKnown)
            {
                // The provider never blocks on the database: warm the cache, ask again.
                if (run.NowMs() >= run.scratch.nextAttemptMs)
                {
                    provider->WarmItemStates(player, { info.itemGuid });
                    run.scratch.nextAttemptMs = run.NowMs() + 1000;
                }
                return MetricPending("the item's upgrade state is loading");
            }

            return MetricOk(info.level, Acore::StringFormat("tier {}, max {}, next cost {}", info.tier,
                info.tierMaxLevel, info.nextCost));
        }

        return MetricError("unknown metric '" + metric + "'");
    }

    Outcome Runner::EvaluateAssertion(Run& run, JsonValue const& spec, StepRecord& record, bool lastChance)
    {
        MetricResult const result = EvaluateMetric(run, spec);
        record.values.Set("metric", spec.GetString("metric"));
        if (result.status == Eval::Error)
            return StepError(record, result.detail);

        if (result.status == Eval::Pending)
        {
            if (!lastChance || run.NowMs() < run.scratch.startMs + PENDING_GRACE_MS)
                return Outcome::Running;
            return StepFail(record, "not available: " + result.detail);
        }

        Value value = result.value;
        if (!result.detail.empty())
            record.values.Set("detail", result.detail);

        if (JsonValue const* relative = spec.Find("relative_to"))
        {
            auto it = run.vars.find(relative->AsString());
            if (it == run.vars.end())
                return StepError(record, "snapshot '" + relative->AsString() + "' was never saved");
            if (it->second.kind != Value::Kind::Number || value.kind != Value::Kind::Number)
                return StepError(record, "relative_to only works with numeric metrics");

            record.values.Set("baseline", it->second.number);
            record.values.Set("absolute", value.number);
            value.number -= it->second.number;
        }

        record.values.Set("value", value.ToJson());

        std::string why;
        if (Compare(value, spec, why))
        {
            record.message.clear();
            return Outcome::Pass;
        }

        record.message = why;
        return lastChance ? Outcome::Fail : Outcome::Running;
    }

    // ------------------------------------------------------------------
    // Dispatch
    // ------------------------------------------------------------------

    Outcome Runner::ExecuteStep(Run& run, JsonValue const& step, StepRecord& record)
    {
        std::string const& action = record.action;

        if (!run.scratch.deadlineMs)
        {
            uint32 timeout = DEFAULT_STEP_TIMEOUT_MS;
            if (action == "teleport" || action == "prestige")
                timeout = TELEPORT_TIMEOUT_MS;
            else if (action == "item_upgrade")
                timeout = 10000;
            else if (action == "wait")
                timeout = step.Has("until") ? UNTIL_TIMEOUT_MS : step.GetUInt("ms") + 2000;
            else if (action == "assert")
                timeout = std::max(step.GetUInt("within_ms"), PENDING_GRACE_MS) + 1000;

            timeout = step.GetUInt("timeout_ms", timeout);
            run.scratch.deadlineMs = run.scratch.startMs + std::max<uint32>(timeout, 1);
        }

        if (action == "assert")
        {
            bool const lastChance = run.NowMs() >= run.scratch.startMs + step.GetUInt("within_ms", 0);
            return EvaluateAssertion(run, step, record, lastChance);
        }
        if (action == "snapshot")
            return StepSnapshot(run, step, record);
        if (action == "wait")
            return StepWait(run, step, record);
        if (action == "log")
        {
            record.message = step.GetString("message");
            LOG_INFO(LOG_CATEGORY, "GameplayTest: run {} log: {}", run.runId, record.message);
            return Outcome::Pass;
        }
        if (action == "teleport")
            return StepTeleport(run, step, record);
        if (action == "set_level")
            return StepSetLevel(run, step, record);
        if (action == "learn" || action == "unlearn")
            return StepLearn(run, step, record, action == "learn");
        if (action == "add_item")
            return StepAddItem(run, step, record);
        if (action == "remove_item")
            return StepRemoveItem(run, step, record);
        if (action == "equip")
            return StepEquip(run, step, record);
        if (action == "cast")
            return StepCast(run, step, record);
        if (action == "add_aura")
            return StepAddAura(run, step, record);
        if (action == "remove_aura")
            return StepRemoveAura(run, step, record);
        if (action == "spawn" || action == "spawn_object")
            return StepSpawn(run, step, record, action == "spawn_object");
        if (action == "despawn")
            return StepDespawn(run, step, record);
        if (action == "kill")
            return StepKill(run, step, record);
        if (action == "revive")
            return StepRevive(run, step, record);
        if (action == "accept_resurrect")
            return StepAcceptResurrect(run, step, record);
        if (action == "set_health")
            return StepSetHealth(run, step, record);
        if (action == "set_power")
            return StepSetPower(run, step, record);
        if (action == "set_money")
            return StepSetMoney(run, step, record);
        if (action.rfind("quest_", 0) == 0)
            return StepQuest(run, step, record, action);
        if (action == "item_upgrade")
            return StepItemUpgrade(run, step, record);
        if (action == "prestige")
            return StepPrestige(run, step, record);

        return StepError(record, "unknown action '" + action + "'");
    }

    // ------------------------------------------------------------------
    // Steps
    // ------------------------------------------------------------------

    Outcome Runner::StepSnapshot(Run& run, JsonValue const& step, StepRecord& record)
    {
        MetricResult const result = EvaluateMetric(run, step);
        record.values.Set("metric", step.GetString("metric"));
        if (result.status == Eval::Error)
            return StepError(record, result.detail);
        if (result.status == Eval::Pending)
            return Outcome::Running;

        run.vars[step.GetString("save_as")] = result.value;
        record.values.Set("value", result.value.ToJson());
        if (!result.detail.empty())
            record.values.Set("detail", result.detail);
        return Outcome::Pass;
    }

    Outcome Runner::StepWait(Run& run, JsonValue const& step, StepRecord& record)
    {
        if (JsonValue const* until = step.Find("until"))
        {
            uint32 const window = step.GetUInt("timeout_ms", UNTIL_TIMEOUT_MS);
            bool const lastChance = run.NowMs() + 50 >= run.scratch.startMs + window;
            return EvaluateAssertion(run, *until, record, lastChance);
        }

        return run.NowMs() >= run.scratch.startMs + step.GetUInt("ms") ? Outcome::Pass : Outcome::Running;
    }

    Outcome Runner::StepTeleport(Run& run, JsonValue const& step, StepRecord& record)
    {
        std::string const actorId = step.GetString("actor", DefaultActorId(run));
        ActorState* actor = FindActor(run, actorId);
        if (!actor)
            return StepError(record, "unknown actor '" + actorId + "'");

        if (!run.scratch.issued)
        {
            Player* player = ResolvePlayer(run, actorId);
            if (!player)
                return StepError(record, "actor '" + actorId + "' is not in the world");

            Location destination;
            if (step.Has("to"))
            {
                WorldObject* anchor = ResolveObject(run, step.GetString("to"));
                if (!anchor)
                    return StepError(record, "'" + step.GetString("to") + "' is not in the world");

                Position const spot = anchor->GetNearPosition(float(step.GetNumber("distance", 2.0)),
                    float(step.GetNumber("angle", 0.0)));
                destination = { anchor->GetMapId(), spot.GetPositionX(), spot.GetPositionY(), spot.GetPositionZ(),
                    spot.GetAngle(anchor) };
            }
            else
                destination = { step.GetUInt("map"), float(step.GetNumber("x")), float(step.GetNumber("y")),
                    float(step.GetNumber("z")), float(step.GetNumber("o")) };

            uint32 const options = step.GetBool("force", false) ? TELE_TO_GM_MODE : 0;
            if (!player->TeleportTo(destination.mapId, destination.x, destination.y, destination.z, destination.o,
                options))
                return StepFail(record, Acore::StringFormat("teleport to map {} was refused", destination.mapId));

            run.scratch.issued = true;
            run.scratch.destination = destination;
            record.values.Set("map", destination.mapId);
            record.values.Set("x", destination.x);
            record.values.Set("y", destination.y);
            record.values.Set("z", destination.z);
            return Outcome::Running;
        }

        Player* player = ActorPlayer(*actor);
        if (!player)
            return StepError(record, "actor '" + actorId + "' logged out during the teleport");

        if (!player->IsInWorld() || player->IsBeingTeleported() || player->GetMapId() != run.scratch.destination.mapId)
            return Outcome::Running;

        EnforcePhase(run, player);
        Location const& destination = run.scratch.destination;
        record.values.Set("arrived_distance", player->GetDistance(destination.x, destination.y, destination.z));
        return Outcome::Pass;
    }

    Outcome Runner::StepSetLevel(Run& run, JsonValue const& step, StepRecord& record)
    {
        Player* player = ResolvePlayer(run, step.GetString("actor", DefaultActorId(run)));
        if (!player)
            return StepError(record, "actor is not in the world");

        ApplyLevel(player, uint8(step.GetUInt("level")));
        record.values.Set("level", player->GetLevel());
        return player->GetLevel() == step.GetUInt("level") ? Outcome::Pass :
            StepFail(record, "the level did not change");
    }

    Outcome Runner::StepLearn(Run& run, JsonValue const& step, StepRecord& record, bool learn)
    {
        std::string const actorId = step.GetString("actor", DefaultActorId(run));
        Player* player = ResolvePlayer(run, actorId);
        ActorState* actor = FindActor(run, actorId);
        if (!player || !actor)
            return StepError(record, "actor is not in the world");

        uint32 const spell = step.GetUInt("spell");
        bool const knew = player->HasSpell(spell);
        record.values.Set("known_before", knew);

        if (learn && !knew)
        {
            player->learnSpell(spell);
            if (!actor->unlearnedSpells.erase(spell))
                actor->learnedSpells.insert(spell);
        }
        else if (!learn && knew)
        {
            player->removeSpell(spell, SPEC_MASK_ALL, false);
            if (!actor->learnedSpells.erase(spell))
                actor->unlearnedSpells.insert(spell);
        }

        bool const knows = player->HasSpell(spell);
        record.values.Set("known_after", knows);
        return knows == learn ? Outcome::Pass : StepFail(record, learn ? "the spell was not learned" :
            "the spell is still known");
    }

    Outcome Runner::StepAddItem(Run& run, JsonValue const& step, StepRecord& record)
    {
        std::string const actorId = step.GetString("actor", DefaultActorId(run));
        Player* player = ResolvePlayer(run, actorId);
        ActorState* actor = FindActor(run, actorId);
        if (!player || !actor)
            return StepError(record, "actor is not in the world");

        uint32 const entry = step.GetUInt("item");
        uint32 const count = step.GetUInt("count", 1);
        if (!player->AddItem(entry, count))
            return StepFail(record, "the item could not be added (bag space, unique limit)");

        actor->addedItems[entry] += count;
        record.values.Set("count_after", player->GetItemCount(entry, false));
        return Outcome::Pass;
    }

    Outcome Runner::StepRemoveItem(Run& run, JsonValue const& step, StepRecord& record)
    {
        std::string const actorId = step.GetString("actor", DefaultActorId(run));
        Player* player = ResolvePlayer(run, actorId);
        ActorState* actor = FindActor(run, actorId);
        if (!player || !actor)
            return StepError(record, "actor is not in the world");

        uint32 const entry = step.GetUInt("item");
        uint32 const count = step.GetUInt("count", 1);
        if (player->GetItemCount(entry, false) < count)
            return StepFail(record, Acore::StringFormat("the actor holds fewer than {}", count));

        player->DestroyItemCount(entry, count, true, false);
        uint32& added = actor->addedItems[entry];
        added = added > count ? added - count : 0;
        record.values.Set("count_after", player->GetItemCount(entry, false));
        return Outcome::Pass;
    }

    Outcome Runner::StepEquip(Run& run, JsonValue const& step, StepRecord& record)
    {
        std::string const actorId = step.GetString("actor", DefaultActorId(run));
        Player* player = ResolvePlayer(run, actorId);
        ActorState* actor = FindActor(run, actorId);
        if (!player || !actor)
            return StepError(record, "actor is not in the world");

        uint32 const entry = step.GetUInt("item");
        Item* item = FindBagItem(player, entry);
        if (!item)
        {
            if (!player->AddItem(entry, 1))
                return StepFail(record, "the item could not be added to the bags");
            actor->addedItems[entry] += 1;
            item = FindBagItem(player, entry);
            if (!item)
                return StepError(record, "the added item is not in the bags");
        }

        uint16 destination = 0;
        InventoryResult const result = player->CanEquipItem(NULL_SLOT, destination, item, true);
        record.values.Set("equip_result", uint32(result));
        if (result != EQUIP_ERR_OK)
            return StepFail(record, Acore::StringFormat("the item cannot be equipped (inventory result {})",
                uint32(result)));

        // The client's own request, so swapping out whatever is worn follows the core's rules.
        WorldPacket packet(CMSG_AUTOEQUIP_ITEM, 2);
        packet << uint8(item->GetBagSlot());
        packet << uint8(item->GetSlot());
        WorldPackets::Item::AutoEquipItem request(std::move(packet));
        request.Read();
        player->GetSession()->HandleAutoEquipItemOpcode(request);

        uint8 const slot = uint8(destination & 0xFF);
        Item* worn = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
        record.values.Set("slot", slot);
        if (!worn || worn->GetEntry() != entry)
            return StepFail(record, Acore::StringFormat("slot {} does not hold the item after equipping", slot));
        return Outcome::Pass;
    }

    Outcome Runner::StepCast(Run& run, JsonValue const& step, StepRecord& record)
    {
        Player* caster = ResolvePlayer(run, step.GetString("actor", DefaultActorId(run)));
        if (!caster)
            return StepError(record, "actor is not in the world");

        Unit* target = nullptr;
        if (step.Has("target"))
        {
            target = ResolveUnit(run, step.GetString("target"));
            if (!target)
                return StepError(record, "target '" + step.GetString("target") + "' is not in the world");
        }

        uint32 const spell = step.GetUInt("spell");
        bool const triggered = step.GetBool("triggered", false);
        // A client can only cast what is in its spellbook; Unit::CastSpell does not check that.
        bool const requireKnown = step.GetBool("require_known", !triggered);
        bool const known = caster->HasSpell(spell);
        record.values.Set("known", known);

        bool castOk = false;
        if (requireKnown && !known)
            record.values.Set("cast_result", "not_known");
        else
        {
            if (target)
                caster->SetSelection(target->GetGUID());
            SpellCastResult const result = caster->CastSpell(target, spell,
                triggered ? TRIGGERED_FULL_MASK : TRIGGERED_NONE);
            record.values.Set("cast_result", uint32(result));
            castOk = result == SPELL_CAST_OK;
        }

        JsonValue const* expect = step.Find("expect");
        if (expect && expect->IsNumber())
        {
            JsonValue const& got = *record.values.Find("cast_result");
            return got.IsNumber() && got.AsNumber() == expect->AsNumber() ? Outcome::Pass :
                StepFail(record, "cast result " + got.Dump(false) + ", expected " + expect->Dump(false));
        }

        bool const wantOk = !expect || !expect->IsString() || expect->AsString() != "fail";
        if (castOk == wantOk)
            return Outcome::Pass;
        return StepFail(record, wantOk ? "the cast was refused" : "the cast went through, a refusal was expected");
    }

    Outcome Runner::StepAddAura(Run& run, JsonValue const& step, StepRecord& record)
    {
        Unit* target = ResolveUnit(run, step.GetString("target"));
        if (!target)
            return StepError(record, "target '" + step.GetString("target") + "' is not in the world");

        Unit* caster = step.Has("caster") ? ResolveUnit(run, step.GetString("caster")) : target;
        if (!caster)
            return StepError(record, "caster '" + step.GetString("caster") + "' is not in the world");

        uint32 const spell = step.GetUInt("spell");
        Aura* aura = caster->AddAura(spell, target);
        if (!aura)
            return StepFail(record, "the aura was not applied (immune, invalid target or a stronger aura)");

        if (uint32 const stacks = step.GetUInt("stacks"))
            aura->SetStackAmount(uint8(std::min<uint32>(stacks, 255)));
        if (JsonValue const* duration = step.Find("duration_ms"))
        {
            aura->SetMaxDuration(int32(duration->AsNumber()));
            aura->SetDuration(int32(duration->AsNumber()));
        }

        for (ActorState& actor : run.actors)
            if (actor.guid == target->GetGUID())
                actor.addedAuras.insert(spell);

        record.values.Set("stacks", aura->GetStackAmount());
        record.values.Set("duration_ms", aura->GetDuration());
        return Outcome::Pass;
    }

    Outcome Runner::StepRemoveAura(Run& run, JsonValue const& step, StepRecord& record)
    {
        Unit* target = ResolveUnit(run, step.GetString("target"));
        if (!target)
            return StepError(record, "target '" + step.GetString("target") + "' is not in the world");

        uint32 const spell = step.GetUInt("spell");
        record.values.Set("had_aura", target->HasAura(spell));
        target->RemoveAurasDueToSpell(spell);
        return target->HasAura(spell) ? StepFail(record, "the aura is still there") : Outcome::Pass;
    }

    Outcome Runner::StepSpawn(Run& run, JsonValue const& step, StepRecord& record, bool gameObject)
    {
        if (run.spawns.size() >= run.config.maxSpawns)
            return StepError(record, "DC.GameplayTest.MaxSpawns reached");

        Player* anchor = ResolvePlayer(run, step.GetString("actor", DefaultActorId(run)));
        if (!anchor)
            return StepError(record, "anchor actor is not in the world");

        uint32 const entry = step.GetUInt("entry");
        Position position = anchor->GetNearPosition(float(step.GetNumber("distance", 5.0)),
            float(step.GetNumber("angle", 0.0)));
        position.SetOrientation(position.GetAngle(anchor));

        // A timed despawn as the safety net: even if cleanup never runs, nothing the
        // harness spawned outlives the run by more than a minute.
        uint32 const lifetimeMs = step.GetUInt("duration_ms", run.timeoutMs + 60000);

        SpawnRecord spawn;
        spawn.id = step.GetString("id");
        spawn.entry = entry;
        spawn.gameObject = gameObject;

        if (gameObject)
        {
            GameObject* object = anchor->SummonGameObject(entry, position.GetPositionX(), position.GetPositionY(),
                position.GetPositionZ(), position.GetOrientation(), 0.0f, 0.0f, 0.0f, 0.0f,
                std::max<uint32>(lifetimeMs / IN_MILLISECONDS, 1), false, GO_SUMMON_TIMED_DESPAWN);
            if (!object)
                return StepFail(record, "the gameobject could not be spawned");

            object->SetPhaseMask(run.config.phaseMask, true);
            spawn.guid = object->GetGUID();
            spawn.mapId = object->GetMapId();
            spawn.instanceId = object->GetInstanceId();
        }
        else
        {
            TempSummon* summon = anchor->SummonCreature(entry, position, TEMPSUMMON_TIMED_DESPAWN, lifetimeMs);
            if (!summon)
                return StepFail(record, "the creature could not be spawned");

            summon->SetPhaseMask(run.config.phaseMask, true);
            if (uint32 const level = step.GetUInt("level"))
                summon->SetLevel(uint8(std::min<uint32>(level, 255)));
            if (uint32 const faction = step.GetUInt("faction"))
                summon->SetFaction(faction);
            if (uint32 const health = step.GetUInt("health"))
            {
                summon->SetCreateHealth(health);
                summon->SetMaxHealth(health);
                summon->SetHealth(health);
            }
            if (step.GetBool("passive", false))
                summon->SetReactState(REACT_PASSIVE);

            spawn.guid = summon->GetGUID();
            spawn.mapId = summon->GetMapId();
            spawn.instanceId = summon->GetInstanceId();
        }

        record.values.Set("guid", spawn.guid.ToString());
        record.values.Set("x", position.GetPositionX());
        record.values.Set("y", position.GetPositionY());
        record.values.Set("z", position.GetPositionZ());
        run.spawns.push_back(std::move(spawn));
        return Outcome::Pass;
    }

    Outcome Runner::StepDespawn(Run& run, JsonValue const& step, StepRecord& record)
    {
        std::string const ref = step.GetString("target");
        if (!FindSpawn(run, ref))
            return StepError(record, "despawn only takes objects the run spawned");

        if (GameObject* object = ResolveGameObject(run, ref))
        {
            object->SetRespawnTime(0);
            object->Delete();
        }
        else if (Unit* unit = ResolveUnit(run, ref))
            if (Creature* creature = unit->ToCreature())
                creature->DespawnOrUnsummon();

        return Outcome::Pass;
    }

    Outcome Runner::StepKill(Run& run, JsonValue const& step, StepRecord& record)
    {
        Unit* victim = ResolveUnit(run, step.GetString("target"));
        if (!victim)
            return StepError(record, "target '" + step.GetString("target") + "' is not in the world");
        if (!victim->IsAlive())
            return StepFail(record, "the target is already dead");

        Unit* killer = step.Has("actor") ? ResolveUnit(run, step.GetString("actor")) : nullptr;
        if (Creature* creature = victim->ToCreature())
            creature->LowerPlayerDamageReq(creature->GetMaxHealth());

        Unit::Kill(killer, victim, false);
        return victim->IsAlive() ? StepFail(record, "the target survived") : Outcome::Pass;
    }

    Outcome Runner::StepRevive(Run& run, JsonValue const& step, StepRecord& record)
    {
        Player* player = ResolvePlayer(run, step.GetString("target", step.GetString("actor", DefaultActorId(run))));
        if (!player)
            return StepError(record, "revive takes a player actor that is in the world");

        if (!player->IsAlive())
        {
            player->ResurrectPlayer(float(std::clamp(step.GetNumber("pct", 100.0), 1.0, 100.0) / 100.0));
            player->SpawnCorpseBones();
        }
        return player->IsAlive() ? Outcome::Pass : StepFail(record, "the actor is still dead");
    }

    Outcome Runner::StepAcceptResurrect(Run& run, JsonValue const& step, StepRecord& record)
    {
        Player* player = ResolvePlayer(run, step.GetString("actor", DefaultActorId(run)));
        if (!player)
            return StepError(record, "actor is not in the world");

        if (!run.scratch.issued)
        {
            if (player->IsAlive())
                return StepFail(record, "the actor is alive");
            if (!player->isResurrectRequested())
                return StepFail(record, "no resurrection request is pending");
            if (player->HasPreventResurectionAura())
                return StepFail(record, "an aura prevents resurrection");

            // What CMSG_RESURRECT_RESPONSE does on "accept". The resurrection itself can be
            // delayed until the short teleport to the caster is acknowledged.
            player->ResurectUsingRequestData();
            run.scratch.issued = true;
        }

        return player->IsAlive() ? Outcome::Pass : Outcome::Running;
    }

    Outcome Runner::StepSetHealth(Run& run, JsonValue const& step, StepRecord& record)
    {
        Unit* target = ResolveUnit(run, step.GetString("target"));
        if (!target || !target->IsAlive())
            return StepError(record, "target is not in the world or dead");

        uint32 health = step.Has("pct") ?
            uint32(std::clamp(step.GetNumber("pct"), 0.0, 100.0) * target->GetMaxHealth() / 100.0) :
            std::min(step.GetUInt("value"), target->GetMaxHealth());
        health = std::max<uint32>(health, 1);
        target->SetHealth(health);
        record.values.Set("health", target->GetHealth());
        return Outcome::Pass;
    }

    Outcome Runner::StepSetPower(Run& run, JsonValue const& step, StepRecord& record)
    {
        Unit* target = ResolveUnit(run, step.GetString("target"));
        if (!target)
            return StepError(record, "target is not in the world");

        Powers power = POWER_MANA;
        if (!PowerIndex(step, target, power))
            return StepError(record, "unknown power type");

        target->SetPower(power, std::min(step.GetUInt("value"), target->GetMaxPower(power)));
        record.values.Set("power", target->GetPower(power));
        return Outcome::Pass;
    }

    Outcome Runner::StepSetMoney(Run& run, JsonValue const& step, StepRecord& record)
    {
        Player* player = ResolvePlayer(run, step.GetString("actor", DefaultActorId(run)));
        if (!player)
            return StepError(record, "actor is not in the world");

        player->SetMoney(std::min<uint32>(step.GetUInt("copper"), MAX_MONEY_AMOUNT));
        record.values.Set("money", player->GetMoney());
        return Outcome::Pass;
    }

    Outcome Runner::StepQuest(Run& run, JsonValue const& step, StepRecord& record, std::string const& action)
    {
        std::string const actorId = step.GetString("actor", DefaultActorId(run));
        Player* player = ResolvePlayer(run, actorId);
        ActorState* actor = FindActor(run, actorId);
        if (!player || !actor)
            return StepError(record, "actor is not in the world");

        uint32 const questId = step.GetUInt("quest");
        Quest const* quest = sObjectMgr->GetQuestTemplate(questId);
        if (!quest)
            return StepError(record, "unknown quest");

        if (action == "quest_add")
        {
            if (!player->CanAddQuest(quest, false))
                return StepFail(record, "CanAddQuest refused (log full, already taken or done)");
            player->AddQuestAndCheckCompletion(quest, nullptr);
            actor->addedQuests.insert(questId);
        }
        else if (action == "quest_complete")
        {
            if (player->GetQuestStatus(questId) == QUEST_STATUS_NONE)
                return StepFail(record, "the quest is not in the log");
            player->CompleteQuest(questId);
            actor->addedQuests.insert(questId);
        }
        else
        {
            RemoveQuestFromPlayer(player, questId);
            actor->addedQuests.erase(questId);
        }

        record.values.Set("status", uint32(player->GetQuestStatus(questId)));
        return Outcome::Pass;
    }

    Outcome Runner::StepItemUpgrade(Run& run, JsonValue const& step, StepRecord& record)
    {
        Player* player = ResolvePlayer(run, step.GetString("actor", DefaultActorId(run)));
        if (!player)
            return StepError(record, "actor is not in the world");

        DarkChaos::ItemUpgradeApi::Provider* provider = DarkChaos::ItemUpgradeApi::GetProvider();
        if (!provider)
            return StepError(record, "the DC item upgrade scripts are not loaded");

        uint8 const slot = uint8(step.GetUInt("slot"));
        DarkChaos::ItemUpgradeApi::SlotUpgradeInfo info;
        if (!provider->DescribeEquippedSlot(player, slot, info))
            return StepFail(record, Acore::StringFormat("slot {} holds nothing the upgrade system handles", slot));

        if (!info.stateKnown)
        {
            if (run.NowMs() >= run.scratch.nextAttemptMs)
            {
                provider->WarmItemStates(player, { info.itemGuid });
                run.scratch.nextAttemptMs = run.NowMs() + 1000;
            }
            return Outcome::Running;
        }

        record.values.Set("level_before", info.level);
        record.values.Set("tier", info.tier);
        record.values.Set("cost", info.nextCost);
        record.values.Set("currency", uint32(info.currency));
        record.values.Set("balance", provider->GetCurrencyAmount(player, info.currency));

        // UpgradeOnce spends the currency, persists, and re-applies the stats.
        bool const upgraded = provider->UpgradeOnce(player, info.itemGuid);
        bool const wantOk = step.GetString("expect", "ok") != "fail";
        record.values.Set("upgraded", upgraded);
        if (upgraded == wantOk)
            return Outcome::Pass;
        return StepFail(record, wantOk ? "the upgrade was refused (currency, max level, ownership or combat)" :
            "the upgrade went through, a refusal was expected");
    }

    Outcome Runner::StepPrestige(Run& run, JsonValue const& step, StepRecord& record)
    {
        std::string const actorId = step.GetString("actor", DefaultActorId(run));
        ActorState* actor = FindActor(run, actorId);
        if (!actor)
            return StepError(record, "unknown actor");

        if (!run.scratch.issued)
        {
            Player* player = ResolvePlayer(run, actorId);
            if (!player)
                return StepError(record, "actor is not in the world");

            if (!actor->prestigeTouched)
            {
                actor->prestigeTouched = true;
                actor->originalPrestige = PrestigeAPI::GetPrestigeLevel(player);
            }

            record.values.Set("prestige_before", PrestigeAPI::GetPrestigeLevel(player));
            record.values.Set("level_before", player->GetLevel());
            std::string const refusal = PrestigeAPI::GetPrestigeRefusal(player);
            if (!refusal.empty())
                record.values.Set("refusal", refusal);

            bool const performed = PrestigeAPI::PerformPrestige(player);
            bool const wantOk = step.GetString("expect", "ok") != "refused";
            record.values.Set("performed", performed);
            run.scratch.issued = true;
            if (performed != wantOk)
                return StepFail(record, wantOk ? "the prestige was refused: " + refusal :
                    "the prestige went through, a refusal was expected");
            if (!performed)
                return Outcome::Pass;
        }

        // A prestige rebuilds the character and sends it to its starting zone.
        Player* player = ActorPlayer(*actor);
        if (!player)
            return StepError(record, "actor logged out during the prestige");
        if (!player->IsInWorld() || player->IsBeingTeleported())
            return Outcome::Running;

        EnforcePhase(run, player);
        record.values.Set("level_after", player->GetLevel());
        record.values.Set("prestige_after", PrestigeAPI::GetPrestigeLevel(player));
        return Outcome::Pass;
    }
}
