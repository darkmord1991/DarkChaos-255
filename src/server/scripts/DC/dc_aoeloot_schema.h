/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * dc_aoeloot_schema.h - single source of truth for the optional columns of
 * `dc_aoeloot_preferences`.
 *
 * Two systems read and write this table: the gameplay path
 * (QOL/dc_aoeloot_unified.cpp) and the addon protocol path
 * (AddonExtension/dc_addon_aoeloot.cpp). Each used to run its own
 * information_schema probe into its own private struct, and the two had already
 * drifted - the gameplay copy knew about six optional columns, the addon copy
 * about four.
 *
 * Both now share this descriptor, so drift is impossible by construction.
 *
 * Lives at the DC root, next to dc_constants.h, rather than under QOL/ or
 * AddonExtension/: those two already form a dependency cycle, and a shared
 * header owned by either side would deepen it.
 *
 * Two properties callers depend on:
 *
 *   1. The probe runs ONCE per server run and latches. Callers build a dynamic
 *      SELECT column list from these flags and then read the result set by
 *      POSITION. If the answer could change between building the list and
 *      reading the row, every field after the changed column would be read out
 *      of the wrong slot. DC::DbSchema re-probes negative answers after a TTL,
 *      so the latch here is what makes the positional reads safe.
 *
 *   2. On probe failure every flag stays false, which degrades to the four
 *      base columns (aoe_enabled, min_quality, auto_skin, smart_loot) that are
 *      always present. That is the same fallback both copies had.
 */

#ifndef DC_AOELOOT_SCHEMA_H
#define DC_AOELOOT_SCHEMA_H

#include "DC/CrossSystem/CrossSystemDbSchema.h"
#include "Log.h"

namespace DCAoELoot
{
    constexpr char const* PREFERENCES_TABLE = "dc_aoeloot_preferences";

    // Which optional columns this deployment's `dc_aoeloot_preferences` has.
    // The four base columns are not represented: they are always present, and
    // a caller that cannot read them has nothing to degrade to.
    struct PreferenceSchemaInfo
    {
        bool initialized = false;
        bool hasShowMessages = false;
        bool hasAutoVendorPoor = false;
        bool hasIgnoredItems = false;
        bool hasGoldOnly = false;
        bool hasLootRange = false;
        bool hasActivePreset = false;
    };

    // Probed once, then latched for the rest of the server run - see (1) above.
    inline PreferenceSchemaInfo const& GetPreferenceSchema()
    {
        static PreferenceSchemaInfo schema;

        if (schema.initialized)
            return schema;

        schema.initialized = true;

        auto const has = [](char const* column)
        {
            return DC::DbSchema::CharacterColumnExists(PREFERENCES_TABLE, column);
        };

        schema.hasShowMessages   = has("show_messages");
        schema.hasAutoVendorPoor = has("auto_vendor_poor");
        schema.hasIgnoredItems   = has("ignored_items");
        schema.hasGoldOnly       = has("gold_only");
        schema.hasLootRange      = has("loot_range");
        schema.hasActivePreset   = has("active_preset");

        LOG_INFO("scripts.dc",
            "AoELoot preferences schema: show_messages={}, auto_vendor_poor={}, "
            "ignored_items={}, gold_only={}, loot_range={}, active_preset={}",
            schema.hasShowMessages   ? "yes" : "no",
            schema.hasAutoVendorPoor ? "yes" : "no",
            schema.hasIgnoredItems   ? "yes" : "no",
            schema.hasGoldOnly       ? "yes" : "no",
            schema.hasLootRange      ? "yes" : "no",
            schema.hasActivePreset   ? "yes" : "no");

        return schema;
    }
}

#endif // DC_AOELOOT_SCHEMA_H
