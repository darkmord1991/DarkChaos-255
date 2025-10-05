-- HLBG_AIO_Client.lua - AIO client integration for HinterlandAffixHUD
-- Cleaned up version without duplicate functions

local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Developer mode flag: when true, extra test slash commands will be registered.
HLBG._devMode = HLBG._devMode or false
-- If user saved a persistent devMode, honor it on load
HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
if HinterlandAffixHUDDB.devMode ~= nil then HLBG._devMode = HinterlandAffixHUDDB.devMode and true or false end
-- Default to 0 (current/all). User can change via "/hlbg season <n>"
HinterlandAffixHUDDB.desiredSeason = HinterlandAffixHUDDB.desiredSeason or 0
-- Disable periodic chat updates by default (user can re-enable in options)
if HinterlandAffixHUDDB.disableChatUpdates == nil then HinterlandAffixHUDDB.disableChatUpdates = true end
function HLBG._getSeason()
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    local s = tonumber(HinterlandAffixHUDDB.desiredSeason or 0) or 0
    if s < 0 then s = 0 end
    return s
end

-- Flexible chat-history parser and rolling buffer (used when servers broadcast single-line rows)
HLBG._histBuf = HLBG._histBuf or {}

-- _parseHistLineFlexible is used to parse history lines
function HLBG._parseHistLineFlexible(line)
    if type(line) ~= 'string' or line == '' then return nil end
    local s = line
    -- Strip leading TOTAL=...|| if present
    s = s:gsub('^TOTAL=%d+%s*%|%|', '')
    -- Try TSV first
    if s:find('\t') then return nil, 'tsv' end
    -- id
    local id, rest = s:match('^(%d+)%s*(.*)$')
    if not id then return nil end
    -- optional literal word 'season <n>'
    local sea
    local rest2 = rest:match('^season%s+(%d+)%s*(.*)$')
    if rest2 then
        sea = rest:match('^season%s+(%d+)')
        rest = rest:sub(#('season '..sea) + 1):gsub('^%s+','')
    end
    -- timestamp yyyy-mm-dd HH:MM:SS
    local d, t, after = rest:match('^(%d%d%d%d%-%d%d%-%d%d)%s+(%d%d:%d%d:%d%d)%s*(.*)$')
    if not d then return nil end
    local ts = d .. ' ' .. t
    -- winner
    local win, after2 = after:match('^(Alliance|Horde|Draw|DRAW)%s*(.*)$')
    if not win then return nil end
    if win == 'Draw' then win = 'DRAW' end
    -- affix id (number)
    local aff, after3 = after2:match('^(%d+)%s*(.*)$')
    aff = aff or '0'
    local reason = after3 and after3:gsub('^%s+','') or '-' 
    return { id = id, season = sea and tonumber(sea) or nil, ts = ts, winner = win, affix = aff, reason = reason }
end

function HLBG._recomputeStatsFromBuf()
    local buf = HLBG._histBuf or {}
    local a,h,d = 0,0,0
    for i=1,#buf do
        local w = tostring(buf[i].winner or ''):upper()
        if w == 'ALLIANCE' then a=a+1 elseif w == 'HORDE' then h=h+1 else d=d+1 end
    end
    local stats = { counts = { Alliance = a, Horde = h }, draws = d, avgDuration = 0 }
    if type(HLBG.Stats) == 'function' then pcall(HLBG.Stats, stats) end
end

function HLBG._pushHistoryRow(row)
    if type(row) ~= 'table' then return end
    local per = (HLBG.UI and HLBG.UI.History and HLBG.UI.History.per) or 5
    table.insert(HLBG._histBuf, 1, row)
    while #HLBG._histBuf > per do table.remove(HLBG._histBuf) end
    if type(HLBG.History) == 'function' then pcall(HLBG.History, HLBG._histBuf, 1, per, #HLBG._histBuf, 'id', 'DESC') end
    HLBG._recomputeStatsFromBuf()
end

-- System-chat fallback: parse server broadcast lines like [HLBG_STATUS], [HLBG_HISTORY_TSV], etc.
do
    local function parseHLBG(msg)
        if type(msg) ~= 'string' then return end
        -- STATUS
        local b = msg:match('%[HLBG_STATUS%]%s*(.*)')
        if b then
            local A = tonumber(b:match('%f[%w]A=(%d+)'))
            local H = tonumber(b:match('%f[%w]H=(%d+)'))
            local ENDTS = tonumber(b:match('%f[%w]END=(%d+)'))
            local LOCK = tonumber(b:match('%f[%w]LOCK=(%d+)'))
            local AFF = b:match('%f[%w]AFF=([^|]+)') or b:match('%f[%w]AFFIX=([^|]+)')
            local DUR = tonumber(b:match('%f[%w]DURATION=(%d+)')) or tonumber(b:match('%f[%w]MATCH_TOTAL=(%d+)'))
            local AP = tonumber(b:match('%f[%w]APLAYERs=(%d+)')) or tonumber(b:match('%f[%w]APLAYER%(s%)=(%d+)')) or tonumber(b:match('%f[%w]APLAYER=(%d+)')) or tonumber(b:match('%f[%w]APC=(%d+)'))
            local HP = tonumber(b:match('%f[%w]HPLAYERS=(%d+)')) or tonumber(b:match('%f[%w]HPLAYERs=(%d+)')) or tonumber(b:match('%f[%w]HPC=(%d+)'))
            HLBG._lastStatus = HLBG._lastStatus or {}
            if A then HLBG._lastStatus.A = A end
            if H then HLBG._lastStatus.H = H end
            if ENDTS then HLBG._lastStatus.ENDTS = ENDTS end
            if LOCK ~= nil then HLBG._lastStatus.LOCK = LOCK end
            if AFF then HLBG._lastStatus.AFF = AFF end
            if DUR then HLBG._lastStatus.DURATION = DUR end
            if AP then HLBG._lastStatus.APlayers = AP; HLBG._lastStatus.APC = AP end
            if HP then HLBG._lastStatus.HPlayers = HP; HLBG._lastStatus.HPC = HP end
            if type(HLBG.UpdateLiveFromStatus) == 'function' then pcall(HLBG.UpdateLiveFromStatus) end
            return
        end
        
        -- HISTORY TSV fallback
        local htsv = msg:match('%[HLBG_HISTORY_TSV%]%s*(.*)') or msg:match('%[HLBG_DUMP%]%s*(.*)') or msg:match('%[HLBG_DBG_TSV%]%s*(.*)')
        if htsv then
            local per = (HLBG.UI and HLBG.UI.History and HLBG.UI.History.per) or 5
            -- Extract TOTAL meta if present then convert row separator '||' to newlines for HistoryStr
            local total = tonumber((htsv:match('^TOTAL=(%d+)%s*%|%|') or 0)) or 0
            if total and total > 0 then htsv = htsv:gsub('^TOTAL=%d+%s*%|%|','') end
            if htsv:find('%|%|') then htsv = htsv:gsub('%|%|','\n') end
            if htsv:find('\t') then
                if type(HLBG.HistoryStr) == 'function' then pcall(HLBG.HistoryStr, htsv, 1, per, total, 'id', 'DESC') end
            else
                -- No tabs present (some servers strip them). Parse each line flexibly.
                local rows = {}
                for line in htsv:gmatch('[^\n]+') do
                    if line and line ~= '' and type(HLBG._parseHistLineFlexible) == 'function' then
                        local r = HLBG._parseHistLineFlexible(line)
                        if r then table.insert(rows, r) end
                    end
                end
                if #rows > 0 then
                    if type(HLBG.History) == 'function' then
                        pcall(HLBG.History, rows, 1, per, total, 'id', 'DESC')
                    else
                        -- fallback: push first row
                        pcall(HLBG._pushHistoryRow, rows[1])
                    end
                end
            end
            return
        end
        
        -- AFFIX broadcast
        local aff = msg:match('%[HLBG_AFFIX%]%s*(.+)')
        if aff then
            HLBG._lastStatus = HLBG._lastStatus or {}
            HLBG._lastStatus.AFF = aff
            if type(HLBG.UpdateLiveFromStatus) == 'function' then pcall(HLBG.UpdateLiveFromStatus) end
            return
        end
        
        -- WARMUP
        local warm = msg:match('%[HLBG_WARMUP%]%s*(.*)')
        if warm then
            local ts = tonumber(warm:match('%f[%w]START=(%d+)'))
            local dur = tonumber(warm:match('%f[%w]DURATION=(%d+)'))
            HLBG._lastStatus = HLBG._lastStatus or {}
            if ts then HLBG._lastStatus.START = ts end
            if dur then HLBG._lastStatus.WARMUP = dur end
            if type(HLBG.UpdateLiveFromStatus) == 'function' then pcall(HLBG.UpdateLiveFromStatus) end
            return
        end
        
        -- Return false to indicate no match
        return false
    end
    
    -- Hook the chat frame addmessage to watch for system broadcasts
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        local old = DEFAULT_CHAT_FRAME.AddMessage
        DEFAULT_CHAT_FRAME.AddMessage = function(self, msg, r, g, b, id, ...)
            if type(msg) == 'string' then
                local handled = parseHLBG(msg)
                if not handled then return old(self, msg, r, g, b, id, ...) end
            else
                return old(self, msg, r, g, b, id, ...)
            end
        end
    end
end

-- Safe slash command registration helper
function HLBG.safeRegisterSlash(key, prefix, handler)
    if type(key) ~= 'string' or type(prefix) ~= 'string' or type(handler) ~= 'function' then return end
    if type(SlashCmdList) == 'table' and SlashCmdList[key] then
        -- already registered
        return
    end
    
    -- Convert /command to just 'command'
    local cmd = prefix:match('^/([%w_]+)') or prefix
    
    -- Register in global table
    _G['SLASH_'..key..'1'] = '/'..cmd
    SlashCmdList[key] = handler
end

-- Try to execute a slash command by name
function HLBG.trySlash(cmd, args)
    if type(cmd) ~= 'string' then return false end
    local verb = cmd:match('^/*([^%s/]+)')
    local rest = cmd:match('^/+[^%s/]+%s+(.+)$') or args or ''
    local key = verb:upper()
    if SlashCmdList and type(SlashCmdList[key]) == 'function' then pcall(SlashCmdList[key], rest or '') ; return true end
    
    -- Special handling for our main command - try aliases
    if verb:lower() == 'hlbghud' then
        if SlashCmdList and type(SlashCmdList['HLBGHUD']) == 'function' then
            pcall(SlashCmdList['HLBGHUD'], rest or '') ; return true
        end
    end
    if verb:lower() == 'hlbg' and SlashCmdList and type(SlashCmdList['HLBG']) == 'function' then pcall(SlashCmdList['HLBG'], rest or '') ; return true end
    return false
end

-- AIO Integration
if AIO then
    -- AIO has loaded, set up event handlers
    
    -- Send commands to server and receive responses
    function HLBG.SendCommand(command, args)
        if type(command) ~= 'string' then return end
        args = args or {}
        if type(args) ~= 'table' then args = { value = tostring(args) } end
        
        -- Verify AIO is loaded and ready
        if not AIO or not AIO.Handle then 
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cFFFF0000HLBG Error:|r AIO not ready') end
            return
        end
        
        -- Add current desired season if needed
        if not args.season then args.season = HLBG._getSeason() end
        
        -- Send command via AIO
        AIO.Handle("HLBG", command, args)
    end
    
    -- Events from server that we handle
    -- Guard against duplicate registration which can cause 'an event is already registered' errors
    HLBG._aioRegistered = HLBG._aioRegistered or false
    if not HLBG._aioRegistered and AIO.RegisterEvent then
        local ok, err = pcall(function()
            AIO.RegisterEvent("HLBG", function(command, args)
                if type(command) ~= 'string' then return end
                args = args or {}
                
                -- Handle different command types
                if command == "Status" or command == "status" then
                    -- Status update (live match data)
                    if type(HLBG.Status) == 'function' then pcall(HLBG.Status, args) end
                    return
                end

                if command == "History" or command == "history" then
                    -- History data for UI
                    if type(args) == 'table' and type(args.rows) == 'table' then
                        if type(HLBG.History) == 'function' then
                            pcall(HLBG.History, args.rows, args.page or 1, args.perpage or 5, args.total or #args.rows, args.sort or 'id', args.order or 'DESC')
                        else
                            -- If no history handler, push first row to buffer
                            if args.rows[1] then pcall(HLBG._pushHistoryRow, args.rows[1]) end
                        end
                    elseif type(args) == 'table' and type(args.tsv) == 'string' then
                        -- Alternative format: TSV string
                        if type(HLBG.HistoryStr) == 'function' then
                            pcall(HLBG.HistoryStr, args.tsv, args.page or 1, args.perpage or 5, args.total or 0, args.sort or 'id', args.order or 'DESC')
                        end
                    end
                    return
                end

                if command == "Stats" or command == "stats" then
                    -- Statistics summary
                    if type(HLBG.Stats) == 'function' then pcall(HLBG.Stats, args) end
                    return
                end

                if command == "Server" or command == "server" then
                    -- Server info/welcome
                    if type(args) == 'table' and type(args.motd) == 'string' and args.motd ~= '' then
                        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                            DEFAULT_CHAT_FRAME:AddMessage('|cFF88EEEEHLBG:|r ' .. args.motd)
                        end
                    end
                    if type(args) == 'table' and args.season and type(HLBG.SetCurrentSeason) == 'function' then
                        pcall(HLBG.SetCurrentSeason, tonumber(args.season) or 0)
                    end
                    return
                end

                if command == "Error" or command == "error" then
                    -- Error message from server
                    if type(args) == 'table' and type(args.message) == 'string' then
                        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                            DEFAULT_CHAT_FRAME:AddMessage('|cFFFF0000HLBG Error:|r ' .. args.message)
                        end
                    end
                    return
                end

                -- Unknown command, log if in dev mode
                if HLBG._devMode and DEFAULT_CHAT_FRAME then
                    local argsStr = ''
                    if type(args) == 'table' then
                        for k,v in pairs(args) do argsStr = argsStr .. ' ' .. tostring(k) .. '=' .. tostring(v) end
                    else
                        argsStr = tostring(args)
                    end
                    DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88HLBG:|r Unknown command: ' .. command .. ' Args: ' .. argsStr)
                end
            end)
        end)
        if ok then
            HLBG._aioRegistered = true
        else
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cFFFF0000HLBG Error:|r Failed to register AIO event: ' .. tostring(err)) end
        end
    end
        if type(command) ~= 'string' then return end
        args = args or {}
        
        -- Handle different command types
        if command == "Status" or command == "status" then
            -- Status update (live match data)
            if type(HLBG.Status) == 'function' then pcall(HLBG.Status, args) end
            return
        end
        
        if command == "History" or command == "history" then
            -- History data for UI
            if type(args) == 'table' and type(args.rows) == 'table' then
                if type(HLBG.History) == 'function' then
                    pcall(HLBG.History, args.rows, args.page or 1, args.perpage or 5, args.total or #args.rows, args.sort or 'id', args.order or 'DESC')
                else
                    -- If no history handler, push first row to buffer
                    if args.rows[1] then pcall(HLBG._pushHistoryRow, args.rows[1]) end
                end
            elseif type(args) == 'table' and type(args.tsv) == 'string' then
                -- Alternative format: TSV string
                if type(HLBG.HistoryStr) == 'function' then
                    pcall(HLBG.HistoryStr, args.tsv, args.page or 1, args.perpage or 5, args.total or 0, args.sort or 'id', args.order or 'DESC')
                end
            end
            return
        end
        
        if command == "Stats" or command == "stats" then
            -- Statistics summary
            if type(HLBG.Stats) == 'function' then pcall(HLBG.Stats, args) end
            return
        end
        
        if command == "Server" or command == "server" then
            -- Server info/welcome
            if type(args) == 'table' and type(args.motd) == 'string' and args.motd ~= '' then
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    DEFAULT_CHAT_FRAME:AddMessage('|cFF88EEEEHLBG Server:|r ' .. args.motd)
                end
            end
            if type(args) == 'table' and args.season and type(HLBG.SetCurrentSeason) == 'function' then
                pcall(HLBG.SetCurrentSeason, tonumber(args.season) or 0)
            end
            return
        end
        
        if command == "Error" or command == "error" then
            -- Error message from server
            if type(args) == 'table' and type(args.message) == 'string' then
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    DEFAULT_CHAT_FRAME:AddMessage('|cFFFF0000HLBG Error:|r ' .. args.message)
                end
            end
            return
        end
        
        -- Unknown command, log if in dev mode
        if HLBG._devMode and DEFAULT_CHAT_FRAME then
            local argsStr = ''
            if type(args) == 'table' then
                for k,v in pairs(args) do argsStr = argsStr .. ' ' .. tostring(k) .. '=' .. tostring(v) end
            else
                argsStr = tostring(args)
            end
            DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88HLBG:|r Unknown command: ' .. command .. ' Args: ' .. argsStr)
        end
    end)
    
    -- Inform user that AIO integration is working
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88HLBG:|r AIO integration active')
    end
    
    -- Main slash command handler (only need one version of this)
    function HLBG._MainSlashHandler(msg)
        if type(msg) ~= 'string' then msg = '' end
        -- Check for subcommands
        local cmd, args = msg:match('^(%S+)%s*(.*)$')
        if not cmd then 
            -- No command given, show UI or help
            if type(HLBG.ShowUI) == 'function' then
                return pcall(HLBG.ShowUI)
            else
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88HLBG:|r Missing ShowUI handler') end
                return
            end
        end
        
        -- Handle common commands
        cmd = cmd:lower()
        if cmd == 'help' or cmd == '?' then
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88Hinterland Battleground HUD Commands:|r')
                DEFAULT_CHAT_FRAME:AddMessage('/hlbg - Show the UI')
                DEFAULT_CHAT_FRAME:AddMessage('/hlbg history - Show the battle history')
                DEFAULT_CHAT_FRAME:AddMessage('/hlbg stats - Show statistics')
                DEFAULT_CHAT_FRAME:AddMessage('/hlbg status - Show current match status')
                DEFAULT_CHAT_FRAME:AddMessage('/hlbg season <n> - Show data for season <n> (0=all)')
                DEFAULT_CHAT_FRAME:AddMessage('/hlbg reload - Reload all data')
                DEFAULT_CHAT_FRAME:AddMessage('/hlbg options - Show options')
                DEFAULT_CHAT_FRAME:AddMessage('/hlbg affix - Show today\'s affix')
                DEFAULT_CHAT_FRAME:AddMessage('/hlbg test - Test HUD')
            end
            return
        elseif cmd == 'stats' then
            HLBG.SendCommand('RequestStats')
            if type(HLBG.ShowUI) == 'function' and type(HLBG.UI) == 'table' then
                pcall(HLBG.ShowUI, HLBG.UI.TAB_STATS)
            end
            return
        elseif cmd == 'status' or cmd == 'live' then
            HLBG.SendCommand('RequestStatus')
            if type(HLBG.ShowUI) == 'function' and type(HLBG.UI) == 'table' then
                pcall(HLBG.ShowUI, HLBG.UI.TAB_LIVE)
            end
            return
        elseif cmd == 'history' or cmd == 'matches' then
            HLBG.SendCommand('RequestHistory')
            if type(HLBG.ShowUI) == 'function' and type(HLBG.UI) == 'table' then
                pcall(HLBG.ShowUI, HLBG.UI.TAB_HISTORY)
            end
            return
        elseif cmd == 'season' then
            local s = tonumber(args) or 0
            if s < 0 then s = 0 end
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            HinterlandAffixHUDDB.desiredSeason = s
            if DEFAULT_CHAT_FRAME then
                if s == 0 then
                    DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88HLBG:|r Now showing data for all seasons')
                else
                    DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF88AA88HLBG:|r Now showing data for season %d', s))
                end
            end
            -- Request reload of data for new season
            HLBG.SendCommand('RequestStats')
            HLBG.SendCommand('RequestHistory')
            HLBG.SendCommand('RequestStatus')
            return
        elseif cmd == 'reload' or cmd == 'refresh' then
            HLBG.SendCommand('RequestStats')
            HLBG.SendCommand('RequestHistory')
            HLBG.SendCommand('RequestStatus')
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88HLBG:|r Reloading data')
            end
            return
        elseif cmd == 'options' or cmd == 'settings' or cmd == 'config' then
            if type(HLBG.ShowUI) == 'function' and type(HLBG.UI) == 'table' then
                pcall(HLBG.ShowUI, HLBG.UI.TAB_SETTINGS)
            end
            return
        elseif cmd == 'affix' or cmd == 'affixes' then
            HLBG.SendCommand('RequestStatus')
            if type(HLBG.ShowAffix) == 'function' then
                pcall(HLBG.ShowAffix)
            end
            return
        elseif cmd == 'test' then
            if type(HLBG.Test) == 'function' then
                pcall(HLBG.Test)
            else
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88HLBG:|r Test mode not available') end
            end
            return
        elseif cmd == 'testjson' or cmd == 'jsontest' then
            -- Use the function from HLBG_JSON.lua
            if type(HLBG.RunJsonDecodeTests) == 'function' then
                pcall(HLBG.RunJsonDecodeTests)
            else
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88HLBG:|r JSON test not available') end
            end
            return
        elseif cmd == 'dev' then
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            if args == 'on' then
                HLBG._devMode = true
                HinterlandAffixHUDDB.devMode = true
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88HLBG:|r Developer mode enabled') end
            elseif args == 'off' then
                HLBG._devMode = false
                HinterlandAffixHUDDB.devMode = false
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88HLBG:|r Developer mode disabled') end
            else
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88HLBG:|r Developer mode is ' .. (HLBG._devMode and 'ON' or 'OFF')) end
            end
            return
        end
        
        -- No valid command given, show UI
        if type(HLBG.ShowUI) == 'function' then
            return pcall(HLBG.ShowUI)
        end
    end
    
    -- Register slash commands (only once)
    -- Main command
    SlashCmdList["HLBGHUD"] = HLBG._MainSlashHandler
    _G["SLASH_HLBGHUD1"] = "/hlbg"
    -- Alternative command 
    SlashCmdList["ZHLBG"] = HLBG._MainSlashHandler
    _G["SLASH_ZHLBG1"] = "/hlbghud"
    
    -- Register more aliases for convenience
    pcall(function() if not SlashCmdList['HLBGHUD'] then safeRegisterSlash('HLBGHUD', '/hlbg', HLBG._MainSlashHandler) end end)
    pcall(function() if not SlashCmdList['HINTERLAND'] then safeRegisterSlash('HINTERLAND', '/hinterland', HLBG._MainSlashHandler) end end)
    pcall(function() if not SlashCmdList['HBG'] then safeRegisterSlash('HBG', '/hbg', HLBG._MainSlashHandler) end end)
    pcall(function() if not SlashCmdList['ZHLBG'] then safeRegisterSlash('ZHLBG', '/hlbghud', HLBG._MainSlashHandler) end end)
    pcall(function() if not SlashCmdList['ZZHLBG'] then safeRegisterSlash('ZZHLBG', '/zhlbg', HLBG._MainSlashHandler) end end)
    pcall(function() if not SlashCmdList['HLBGHUD'] then safeRegisterSlash('HLBGHUD', '/hlbghud', HLBG._MainSlashHandler) end end)
    pcall(function() if not SlashCmdList['ZHLBG'] then safeRegisterSlash('ZHLBG', '/zhlbg', HLBG._MainSlashHandler) end end)
    
    -- When client first loads, request data
    C_Timer.After(2, function()
        HLBG.SendCommand('RequestStats')
        HLBG.SendCommand('RequestHistory')
        HLBG.SendCommand('RequestStatus')
        HLBG.SendCommand('ClientHello', { version = '1.5.4' })
    end)
    
    -- Add a slash command to forward the /hlbgui to /hlbg for compatibility
    safeRegisterSlash('HLBGUI', '/hlbgui', function(msg) if SlashCmdList and SlashCmdList['HLBG'] then SlashCmdList['HLBG'](msg) else HLBG._MainSlashHandler(msg) end end)
end

-- At login, register the main slash commands if not done already
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- Register the main command handlers if they weren't already registered
        if not SlashCmdList["HLBGHUD"] then
            SlashCmdList["HLBGHUD"] = HLBG._MainSlashHandler
            _G["SLASH_HLBGHUD1"] = "/hlbg"
        end
        
        if not SlashCmdList["ZHLBG"] then
            SlashCmdList["ZHLBG"] = HLBG._MainSlashHandler
            _G["SLASH_ZHLBG1"] = "/hlbghud"
        end
        
        -- Check debug functionality
        if type(HLBG.Debug) ~= 'function' then
            -- Add a basic Debug function if missing
            function HLBG.Debug(...)
                if not HLBG._devMode then return end
                if DEFAULT_CHAT_FRAME then
                    local args = {...}
                    local str = "|cFF88AA88HLBG Debug:|r "
                    for i,v in ipairs(args) do
                        str = str .. tostring(v) .. " "
                    end
                    DEFAULT_CHAT_FRAME:AddMessage(str)
                end
            end
        end
    end
end)