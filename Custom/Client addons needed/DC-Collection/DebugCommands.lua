--[[
    Debug Commands for DC-Collection
    Add /dcc defcount command to check transmog definitions
]]

local DC = DCCollection

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
    else
        -- Call original handler for all other commands
        if originalHandler then
            originalHandler(msg)
        end
    end
end
