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

local function FormatTransportAge(timestamp)
    timestamp = tonumber(timestamp) or 0
    if timestamp <= 0 or type(time) ~= "function" then
        return "never"
    end

    local age = time() - timestamp
    if age < 0 then
        age = 0
    end

    return string.format("%ds ago", age)
end

local function PrintCollectionTransportStatus()
    if type(DC.GetCollectionTransportDiagnostics) ~= "function" then
        DC:Print("Collection transport diagnostics: unavailable")
        return
    end

    local diagnostics = DC:GetCollectionTransportDiagnostics()
    if type(DC.GetCollectionTransportSummary) == "function" then
        DC:Print(DC:GetCollectionTransportSummary())
    end

    local function FormatState(channel)
        local key = channel.statusKey or "idle"
        if key == "pending" then
            return "awaiting_reply"
        end
        if key == "observed" then
            return "observed_reply"
        end
        if key == "cached" then
            return "cached_snapshot"
        end
        if key == "reply" then
            return "reply_received"
        end
        return "not_requested"
    end

    local function FormatRequest(channel)
        if not channel.hasRequest then
            return "not requested"
        end

        return string.format("%s via %s (%s)",
            tostring(channel.lastRequestLabel or "-"),
            tostring(channel.lastRequestTransport or "-"),
            FormatTransportAge(channel.lastRequestAt))
    end

    local function FormatReply(channel)
        local key = channel.statusKey or "idle"
        if key == "pending" then
            return "awaiting reply"
        end

        if channel.hasReply then
            return string.format("%s via %s (%s)",
                tostring(channel.lastReplyLabel or "-"),
                tostring(channel.lastReplyTransport or "-"),
                FormatTransportAge(channel.lastReplyAt))
        end

        if key == "cached" then
            return "cached snapshot present"
        end

        return "no reply yet"
    end

    local function PrintChannel(label, channel)
        channel = type(channel) == "table" and channel or {}
        local revision = tonumber(channel.revision) or tonumber(channel.lastReplyRevision)
            or tonumber(channel.lastRevision) or 0
        local snapshotState = (channel.hasCachedSnapshot or channel.hasReply
            or revision > 0) and "present" or "none"

        DC:Print(string.format(
            "  %s: available=%s negotiated=%s state=%s req=%s reply=%s snapshot=%s rev=%s",
            label,
            tostring(channel.available == true),
            tostring(channel.negotiated == true),
            FormatState(channel),
            FormatRequest(channel),
            FormatReply(channel),
            snapshotState,
            revision > 0 and tostring(revision) or "-"))

        if type(channel.lastError) == "string" and channel.lastError ~= "" then
            DC:Print("    lastError=" .. channel.lastError)
        end
    end

    PrintChannel("wave1", diagnostics.collectionWave1)
    PrintChannel("shop", diagnostics.shop)
    PrintChannel("currencies", diagnostics.currencies)
    PrintChannel("shop_history", diagnostics.shopHistory)
    PrintChannel("wishlist", diagnostics.wishlist)
    PrintChannel("purchase", diagnostics.purchaseResult)
    PrintChannel("saved_outfits", diagnostics.savedOutfits)
    PrintChannel("community", diagnostics.community)
    PrintChannel("transmog_state", diagnostics.transmogState)
    PrintChannel("item_sets", diagnostics.itemSets)
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

        -- Repopulate the local CDBC catalog (mounts/pets/heirlooms/titles/transmog
        -- are authoritative local-CDBC types). Without this, wiping DC.definitions
        -- above leaves the stale "_localCollectionCDBC authoritative" flags set, so
        -- RequestDefinitions short-circuits ("using local CDBC metadata") and never
        -- refills the empty tables -- the Mounts tab then hangs on "Loading...".
        if type(DC.BootstrapLocalCollectionCDBC) == "function" then
            DC:BootstrapLocalCollectionCDBC(true)
        end

        DC:Print("|cff00ff00Cache cleared!|r Local catalog rebuilt; use /reload to also refetch owned-state from server.")
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
    elseif cmd == "transport" or cmd == "bridge" then
        local subcmd = string.lower((rest or ""):match("^%s*(.-)%s*$") or "")
        if subcmd == "refresh" then
            if type(DC.RefreshCollectionTransport) ~= "function" then
                DC:Print("Collection transport refresh: unavailable")
                return
            end

            local results = DC:RefreshCollectionTransport() or {}
            DC:Print(string.format(
                "Collection transport refresh queued: wave1=%s shop=%s currencies=%s shop_history=%s wishlist=%s community=%s transmog_state=%s item_sets=%s",
                tostring(results.collectionWave1 == true),
                tostring(results.shop == true),
                tostring(results.currencies == true),
                tostring(results.shopHistory == true),
                tostring(results.wishlist == true),
                tostring(results.community == true),
                tostring(results.transmogState == true),
                tostring(results.itemSets == true)))
        end

        PrintCollectionTransportStatus()
    elseif cmd == "cdbcprobe" or cmd == "staticprobe" then
        PrintNativeCollectionProbe()
    else
        -- Call original handler for all other commands
        if originalHandler then
            originalHandler(msg)
        end
    end
end
