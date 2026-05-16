--[[
    Debug Commands for DC-Collection
    Add /dcc defcount command to check transmog definitions
]]

local DC = DCCollection

local PROBE_FUNCTIONS = {
    { name = "GetDCCollectionCategories", key = "id", label = "categories" },
    { name = "GetDCCollectionSources", key = "entryId", label = "sources" },
    { name = "GetDCCollectionSets", key = "id", label = "sets" },
    { name = "GetDCCollectionShop", key = "shopId", label = "shop" },
    { name = "GetDCCollectionTransmog", key = "displayId", label = "transmog" },
}

local MANIFEST_TYPES = {
    "mounts",
    "pets",
    "heirlooms",
    "titles",
    "transmog",
    "itemsets",
}

local function PrintStaticManifestSummary()
    local manifest = type(DC.GetLocalCollectionStaticManifest) == "function" and
        DC:GetLocalCollectionStaticManifest() or nil

    if type(manifest) ~= "table" or type(manifest.types) ~= "table" then
        DC:Print("Static manifest: unavailable")
        return
    end

    DC:Print(string.format(
        "Static manifest v%s",
        tostring(manifest.version or "?")))

    for _, typeName in ipairs(MANIFEST_TYPES) do
        local entry = manifest.types[typeName]
        if type(entry) == "table" then
            DC:Print(string.format(
                "  %s: requestSkip=%s defs=%d expected=%d source=%s",
                typeName,
                tostring(entry.requestSkip == true),
                tonumber(entry.definitionCount) or 0,
                tonumber(entry.expectedCount) or 0,
                tostring(entry.serverSource or "?")))
        end
    end

    if type(manifest.shop) == "table" then
        DC:Print(string.format(
            "  shop: authoritative=%s resolved=%d/%d",
            tostring(manifest.shop.authoritative == true),
            tonumber(manifest.shop.resolvedRowCount) or 0,
            tonumber(manifest.shop.enabledRowCount) or 0))
    end
end

local function PrintNativeCollectionProbe()
    if type(DC.BootstrapLocalCollectionCDBC) == "function" then
        DC:BootstrapLocalCollectionCDBC(true)
    end

    PrintStaticManifestSummary()

    for _, probe in ipairs(PROBE_FUNCTIONS) do
        local fn = _G[probe.name]
        if type(fn) ~= "function" then
            DC:Print(string.format("%s: missing export", probe.name))
        else
            local ok, rows = pcall(fn)
            if not ok then
                DC:Print(string.format("%s: error=%s", probe.name, tostring(rows)))
            elseif type(rows) ~= "table" then
                DC:Print(string.format(
                    "%s: unexpected return type=%s",
                    probe.name,
                    type(rows)))
            else
                local count = #rows
                local first = rows[1]
                local preview = "none"

                if type(first) == "table" then
                    local keyValue = first[probe.key] or first.id or first.entryId
                    preview = string.format(
                        "%s=%s name=%s",
                        probe.key,
                        tostring(keyValue),
                        tostring(first.name or first.key or "?"))
                end

                DC:Print(string.format(
                    "%s: rows=%d first=%s",
                    probe.name,
                    count,
                    preview))
            end
        end
    end
end

-- Add to existing slash command handler
local originalHandler = SlashCmdList["DCCOLLECTION"]

SlashCmdList["DCCOLLECTION"] = function(msg)
    msg = msg or ""
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = string.lower(cmd or "")
    
    if cmd == "defcount" or cmd == "count" then
        local tmogCount = 0
        if DC.definitions and DC.definitions.transmog then
            for _ in pairs(DC.definitions.transmog) do
                tmogCount = tmogCount + 1
            end
        end
        DC:Print(string.format("Transmog Definitions Loaded: %d", tmogCount))
        DC:Print(string.format("Pages Fetched: %d", DC._transmogDefPagesFetched or 0))
        if DC.stats and DC.stats.transmog then
            DC:Print(string.format("Total on Server: %d", DC.stats.transmog.total or 0))
        end
    elseif cmd == "clearcache" or cmd == "cc" then
        -- Force-clear all cached data to trigger fresh downloads
        DC.definitions = {}
        DC.collections = {}
        DC._transmogDefLoading = nil
        DC._transmogDefPagesFetched = 0
        DC._transmogDefsForcedFullDownload = nil
        DC._transmogDefLastRequestedOffset = nil
        DC._transmogDefTotal = nil
        DC._transmogDefinitionAliasLookup = nil
        DC._handshakeAcked = nil
        DC._handshakeRequested = nil
        DC._initialDataRequested = nil
        DC._lastInitialDataRequest = nil
        
        -- Clear Wardrobe's itemId->displayId cache
        if DC.Wardrobe and type(DC.Wardrobe.ClearItemIdToDisplayIdCache) == "function" then
            DC.Wardrobe:ClearItemIdToDisplayIdCache()
        end
        
        -- Clear saved variables cache markers
        if DCCollectionDB then
            DCCollectionDB.definitions = nil
            DCCollectionDB.definitionCache = nil
            DCCollectionDB.collectionCache = nil
            DCCollectionDB.transmogSyncVersion = nil
            DCCollectionDB.syncVersion = 0
            DCCollectionDB.syncVersions = nil
            DCCollectionDB.lastSaveTime = nil
            DCCollectionDB.lastSyncTime = 0  -- Critical: forces IsCacheFresh() to return false
        end
        
        DC:Print("|cff00ff00Cache cleared!|r Use /reload to fetch fresh data from server.")
    elseif cmd == "forcerefresh" or cmd == "fr" then
        -- Force a full re-request of definitions
        DC._transmogDefsForcedFullDownload = nil
        DC._transmogDefLoading = nil
        DC._initialDataRequested = false
        DC:RequestInitialData(true)
        DC:Print("Forcing full data refresh...")
    elseif cmd == "netlog" then
        local n = tonumber(rest) or 20
        if type(DC.DumpNetEventLog) == "function" then
            DC:DumpNetEventLog(n)
        else
            DC:Print("[NetLog] Not available")
        end
    elseif cmd == "netlogclear" then
        if type(DC.ClearNetEventLog) == "function" then
            DC:ClearNetEventLog()
            DC:Print("[NetLog] Cleared")
        else
            DC:Print("[NetLog] Not available")
        end
    elseif cmd == "cdbcprobe" or cmd == "staticprobe" then
        PrintNativeCollectionProbe()
    else
        -- Call original handler for all other commands
        if originalHandler then
            originalHandler(msg)
        end
    end
end
