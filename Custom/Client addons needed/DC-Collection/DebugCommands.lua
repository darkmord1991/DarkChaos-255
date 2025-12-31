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
