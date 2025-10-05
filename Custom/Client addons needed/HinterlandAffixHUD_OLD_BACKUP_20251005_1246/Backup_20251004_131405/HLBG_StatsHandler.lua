-- HLBG_StatsHandler.lua - Special handlers for Stats data

-- Ensure HLBG namespace exists
HLBG = HLBG or {}

-- Special handler for the HLBG_STATS_JSON format is now handled by the main chat filter
-- We don't need to install another one here, just provide the processing function

-- Store the stats handler for reference
HLBG._processStatsJSON = function(text)
    if type(text) == "string" and text:match("^%[HLBG_STATS_JSON%]") then
        -- Extract the JSON part
        local jsonPart = text:gsub("^%[HLBG_STATS_JSON%]%s*", "")
        
        -- Store the raw JSON for debugging
        HLBG._lastRawStats = jsonPart
        
        -- Process it directly with our Stats function
        if type(HLBG.Stats) == 'function' then
            if HLBG._devMode then
                print("HLBG StatsHandler: Processing STATS_JSON message, length:", #jsonPart)
            end
            
            HLBG.Stats(jsonPart)
            
            -- Mark any pending stats requests as complete
            if HLBG.CompleteRequest then
                HLBG.CompleteRequest("STATS")
            end
            
            return true -- Successfully processed
        end
    end
    
    return false -- Not processed
end

-- Process raw stats JSON string
function HLBG.ProcessStatsJSON(jsonStr)
    if type(jsonStr) ~= 'string' then return end
    
    -- Check if this looks like our JSON format
    if not (jsonStr:match('"total"') or jsonStr:match('"avgDuration"')) then return end
    
    print("HLBG StatsHandler: Processing stats JSON, length:", #jsonStr)
    
    -- Try to parse the JSON
    local stats = nil
    
    -- Method 1: Use our JSON parser
    if HLBG.ParseJSON then
        local success, parsed = pcall(HLBG.ParseJSON, jsonStr)
        if success and parsed then
            stats = parsed
        end
    end
    
    -- Method 2: Direct extraction of values if parsing failed
    if not stats then
        stats = {}
        -- Extract basic statistics
        stats.total = tonumber(jsonStr:match('"total"%s*:%s*(%d+)') or "0") or 0
        stats.draws = tonumber(jsonStr:match('"draws"%s*:%s*(%d+)') or "0") or 0 
        stats.manual = tonumber(jsonStr:match('"manual"%s*:%s*(%d+)') or "0") or 0
        stats.avgDuration = tonumber(jsonStr:match('"avgDuration"%s*:%s*([%d%.]+)') or "0") or 0
        
        -- Extract win counts if available
        local countsStr = jsonStr:match('"counts"%s*:%s*{([^}]+)}')
        if countsStr then
            stats.counts = {}
            stats.counts.Alliance = tonumber(countsStr:match('"Alliance"%s*:%s*(%d+)') or "0") or 0
            stats.counts.Horde = tonumber(countsStr:match('"Horde"%s*:%s*(%d+)') or "0") or 0
        else
            -- If no explicit counts, calculate from total and draws
            local remaining = stats.total - stats.draws
            stats.counts = {
                Alliance = math.floor(remaining / 2),
                Horde = math.ceil(remaining / 2)
            }
        end
    end
    
    -- Send to stats display
    if HLBG.Stats then
        HLBG.Stats(stats)
    end
end

-- Register our handler for AIO Stats message
if _G.AIO and _G.AIO.AddHandlers then
    local handler = _G.AIO.AddHandlers('HLBG', {}) or {}
    handler.StatsJSON = HLBG.ProcessStatsJSON
end