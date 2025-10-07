-- HLBG_SlashCommands.lua - Slash command handlers for Hinterland Battleground

-- Ensure HLBG namespace exists
HLBG = HLBG or {}

-- Unified main slash handler (parses subcommands like 'devmode')
function HLBG._MainSlashHandler(msg)
    msg = tostring(msg or ""):gsub("^%s+","")
    local sub = msg:match("^(%S+)")
    
    -- aio diagnostic command: /hlbg aio
    if sub and sub:lower() == 'aio' then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG AIO Diagnostics:|r")
        DEFAULT_CHAT_FRAME:AddMessage("AIO available: " .. (_G.AIO and "YES" or "NO"))
        if _G.AIO then
            DEFAULT_CHAT_FRAME:AddMessage("AIO.Handle: " .. (type(_G.AIO.Handle) == 'function' and "YES" or "NO"))
            DEFAULT_CHAT_FRAME:AddMessage("AIO.AddHandlers: " .. (_G.AIO.AddHandlers and "YES" or "NO"))
            DEFAULT_CHAT_FRAME:AddMessage("AIO.RegisterEvent: " .. (_G.AIO.RegisterEvent and "YES" or "NO"))
        end
        DEFAULT_CHAT_FRAME:AddMessage("HLBG._aioRegistered: " .. (HLBG._aioRegistered and "YES" or "NO"))
        DEFAULT_CHAT_FRAME:AddMessage("HLBG._aioHandlersRegistered: " .. (HLBG._aioHandlersRegistered and "YES" or "NO"))
        
        -- Test a simple AIO call
        if _G.AIO and _G.AIO.Handle then
            local ok, err = pcall(_G.AIO.Handle, 'HLBG', 'Test')
            DEFAULT_CHAT_FRAME:AddMessage("AIO test call: " .. (ok and "SUCCESS" or "FAILED: " .. tostring(err)))
        end
        return
    end
    
    -- season selector: /hlbg season <n|0>
    if sub and sub:lower() == 'season' then
        local arg = tonumber(msg:match('^%S+%s+(%S+)') or '')
        if not arg then
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG: season is %s (0 = all/current). Usage: /hlbg season <n>', tostring(HinterlandAffixHUDDB.desiredSeason or 0))) end
        else
            HinterlandAffixHUDDB.desiredSeason = arg
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG: season set to %d', arg)) end
        end
        return
    end
    
    -- devmode subcommand: /hlbg devmode on|off
    if sub and sub:lower() == "devmode" then
        local arg = msg:match("^%S+%s+(%S+)")
        if arg and arg:lower() == 'on' then
            HLBG._devMode = true
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            HinterlandAffixHUDDB.devMode = true
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('HLBG: devmode enabled') end
        elseif arg and arg:lower() == 'off' then
            HLBG._devMode = false
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            HinterlandAffixHUDDB.devMode = false
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('HLBG: devmode disabled') end
        else
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG: devmode is %s (use /hlbg devmode on|off)', HLBG._devMode and 'ON' or 'OFF')) end
        end
        return
    end

    -- status subcommand: /hlbg status (to sync HUD and command output)
    if sub and sub:lower() == 'status' then
        -- Request fresh status from server (with error handling)
        if _G.AIO and _G.AIO.Handle then
            pcall(_G.AIO.Handle, 'HLBG', 'Request', 'STATUS')
            pcall(_G.AIO.Handle, 'HLBG', 'Status')
        end
        local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
        if sendDot then sendDot('.hlbgstatus'); sendDot('.hlbg status') end
        
        -- Display current cached status
        local status = HLBG._lastStatus or {}
        local lines = {}
        table.insert(lines, "|cFF33FF99HLBG Current Status:|r")
        table.insert(lines, "Alliance: " .. (status.A or status.allianceResources or 0))
        table.insert(lines, "Horde: " .. (status.H or status.hordeResources or 0))
        table.insert(lines, "Players A/H: " .. (status.APC or status.APlayers or 0) .. "/" .. (status.HPC or status.HPlayers or 0))
        if status.DURATION or status.timeLeft then
            local timeLeft = tonumber(status.DURATION or status.timeLeft or 0) or 0
            local m = math.floor(timeLeft/60); local s = timeLeft%60
            table.insert(lines, "Time: " .. string.format("%d:%02d", m, s))
        end
        table.insert(lines, "Affix: " .. (status.AFF or status.affixName or "None"))
        table.insert(lines, "Phase: " .. (status.phase or "Unknown"))
        
        for _, line in ipairs(lines) do
            DEFAULT_CHAT_FRAME:AddMessage(line)
        end
        
        -- Force HUD update with same data to ensure sync
        if type(HLBG.UpdateModernHUD) == 'function' then
            local hudData = {
                allianceResources = status.A or status.allianceResources or 0,
                hordeResources = status.H or status.hordeResources or 0,
                alliancePlayers = status.APC or status.APlayers or 0,
                hordePlayers = status.HPC or status.HPlayers or 0,
                timeLeft = status.DURATION or status.timeLeft or 0,
                affixName = status.AFF or status.affixName or "None",
                phase = status.phase or "IDLE"
            }
            HLBG.UpdateModernHUD(hudData)
        end
        
        -- Request fresh status for next time (with error handling)
        if type(HLBG.RequestStatus) == 'function' then
            pcall(HLBG.RequestStatus)
        end
        return
    end

    -- queue subcommands: /hlbg queue join|leave
    if sub and sub:lower() == 'queue' then
        local act = (msg:match('^%S+%s+(%S+)') or ''):lower()
        if act == 'join' or act == 'leave' then
            if _G.AIO and _G.AIO.Handle then
                pcall(_G.AIO.Handle, 'HLBG', 'Request', act == 'join' and 'QUEUE_JOIN' or 'QUEUE_LEAVE')
                pcall(_G.AIO.Handle, 'HLBG', act == 'join' and 'QueueJoin' or 'QueueLeave')
                pcall(_G.AIO.Handle, 'HLBG', 'QUEUE', act:upper())
            end
            local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
            if sendDot then
                if act == 'join' then sendDot('.hlbg queue join'); sendDot('.hlbg join') else sendDot('.hlbg queue leave'); sendDot('.hlbg leave') end
            end
            if HLBG.UI and HLBG.UI.Queue and HLBG.UI.Queue.Status then HLBG.UI.Queue.Status:SetText('Queue status: requested '..act..'…') end
            return
        end
    end

    -- call helpers defensively: prefer HLBG.* then global fallback
    if type(HLBG.EnsurePvPTab) == 'function' then pcall(HLBG.EnsurePvPTab) elseif type(_G.EnsurePvPTab) == 'function' then pcall(_G.EnsurePvPTab) end
    if type(HLBG.EnsurePvPHeaderButton) == 'function' then pcall(HLBG.EnsurePvPHeaderButton) elseif type(_G.EnsurePvPHeaderButton) == 'function' then pcall(_G.EnsurePvPHeaderButton) end
    
    -- Open UI by default
    if HLBG.UI and HLBG.UI.Frame then 
        HLBG.UI.Frame:Show() 
        if type(ShowTab) == 'function' then ShowTab(1) end
    end
    
    -- Get UI state for requests
    local hist = (HLBG and HLBG.UI and HLBG.UI.History) or nil
    local p = (hist and hist.page) or 1
    local per = (hist and hist.per) or 5
    local sk = (hist and hist.sortKey) or "id"
    local sd = (hist and hist.sortDir) or "DESC"
    local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or (type(_G.HLBG_GetSeason) == 'function' and _G.HLBG_GetSeason()) or 0
    
    -- Check if data already loaded during initialization
    if HLBG.InitState and HLBG.InitState.historyDataLoaded then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Using cached data (loaded at startup)")
        end
        -- Use cached data instead of requesting again
        if HLBG.RefreshHistoryData then
            HLBG.RefreshHistoryData()
        end
        return
    end
    
    -- Only load data if not already cached (should rarely happen)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Loading fresh data...")
    end
    
    -- Trigger one-time data load
    if HLBG.LoadInitialData then
        HLBG.LoadInitialData()
    else
        -- Fallback if initialization system not loaded
        if _G.AIO and _G.AIO.Handle then
            local ok, err = pcall(_G.AIO.Handle, "HLBG", "Request", "HISTORY", p, per, sv, sk, sd)
            if ok then
                pcall(_G.AIO.Handle, "HLBG", "Request", "STATS", sv)
            end
        end
    end
    
    -- Dot commands handled in LoadInitialData function - no redundant calls needed here
end

-- Register slash commands for Hinterland BG

-- Primary unique token to avoid collisions with other addons
SlashCmdList = SlashCmdList or {}
SLASH_HLBGHUD1 = "/hlbg"; _G.SLASH_HLBGHUD1 = SLASH_HLBGHUD1
SLASH_HLBGHUD2 = "/hinterland"; _G.SLASH_HLBGHUD2 = SLASH_HLBGHUD2
SLASH_HLBGHUD3 = "/hbg"; _G.SLASH_HLBGHUD3 = SLASH_HLBGHUD3
SlashCmdList["HLBGHUD"] = HLBG._MainSlashHandler

-- Backup aliases under a different key to avoid any table-key collisions
SLASH_ZHLBG1 = "/hlbghud"; _G.SLASH_ZHLBG1 = SLASH_ZHLBG1
SLASH_ZHLBG2 = "/zhlbg"; _G.SLASH_ZHLBG2 = SLASH_ZHLBG2
SlashCmdList["ZHLBG"] = HLBG._MainSlashHandler

-- Also try our safeRegisterSlash for redundancy (won't overwrite existing)
pcall(function() if not SlashCmdList['HLBGHUD'] then HLBG.safeRegisterSlash('HLBGHUD', '/hlbg', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['HINTERLAND'] then HLBG.safeRegisterSlash('HINTERLAND', '/hinterland', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['HBG'] then HLBG.safeRegisterSlash('HBG', '/hbg', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['ZHLBG'] then HLBG.safeRegisterSlash('ZHLBG', '/hlbghud', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['ZZHLBG'] then HLBG.safeRegisterSlash('ZZHLBG', '/zhlbg', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['HLBGHUD'] then HLBG.safeRegisterSlash('HLBGHUD', '/hlbghud', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['ZHLBG'] then HLBG.safeRegisterSlash('ZHLBG', '/zhlbg', HLBG._MainSlashHandler) end end)

-- Round-trip ping test
function HLBG.PONG()
    DEFAULT_CHAT_FRAME:AddMessage("HLBG: PONG from server")
end

-- Register some additional utility commands
HLBG.safeRegisterSlash('HLBGPING', '/hlbgping', function()
    if _G.AIO and _G.AIO.Handle then _G.AIO.Handle("HLBG", "Request", "PING") else DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO client not available") end
end)

HLBG.safeRegisterSlash('HLBGUI', '/hlbgui', function(msg) 
    if SlashCmdList and SlashCmdList['HLBG'] then 
        SlashCmdList['HLBG'](msg) 
    else 
        HLBG._MainSlashHandler(msg) 
    end 
end)

-- Request queue status/join/leave
function HLBG.RequestQueue(action)
    action = tostring(action or 'STATUS'):upper()
    if _G.AIO and _G.AIO.Handle then
        if action == 'JOIN' then _G.AIO.Handle('HLBG','Request','QUEUE','join')
        elseif action == 'LEAVE' then _G.AIO.Handle('HLBG','Request','QUEUE','leave')
        else _G.AIO.Handle('HLBG','Request','QUEUE','status') end
    end
end

-- Request affixes list from server
function HLBG.RequestAffixes()
    local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
    local search = HinterlandAffixHUDDB and HinterlandAffixHUDDB.affixSearch or ''
    if _G.AIO and _G.AIO.Handle then _G.AIO.Handle('HLBG','Request','AFFIXES', sv, search) end
end