-- HLBG_AIO_Check.lua - Ensures AIO is loaded before initializing HLBG

-- Track that this file was loaded
if _G.HLBG_RecordFileLoad then
    _G.HLBG_RecordFileLoad("HLBG_AIO_Check.lua")
end

-- Create or use existing namespace
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Create a frame to monitor loading state
local aioCheckFrame = CreateFrame("Frame")
aioCheckFrame.retryCount = 0
aioCheckFrame.maxRetries = 10
aioCheckFrame.initialized = false

-- Function to check if AIO is available and initialize our addon
local function CheckAIO()
    if aioCheckFrame.initialized then
        return
    end
    
        if _G.AIO and type(_G.AIO) == "table" and type(_G.AIO.Handle) == "function" then
        -- AIO is available, we can initialize
        aioCheckFrame.initialized = true
        
        -- Log success (defensive)
        HLBG = HLBG or {}
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            if type(HLBG.SafePrint) == 'function' then
                HLBG.SafePrint("|cFF00FF00HLBG:|r AIO dependency verified, initializing addon")
            else
                DEFAULT_CHAT_FRAME:AddMessage(tostring("|cFF00FF00HLBG:|r AIO dependency verified, initializing addon"))
            end
        end
        
        -- Record in the load state
        if _G.HLBG_LoadState then
            _G.HLBG_LoadState.aioVerified = true
        end
        
        -- Unregister the update script
        aioCheckFrame:SetScript("OnUpdate", nil)
        
        -- Ensure the HLBG table has required fields
        HLBG._lastStatus = HLBG._lastStatus or {}
        HLBG._devMode = HLBG._devMode or false
        
        -- Trigger any initialization handlers
        if type(HLBG.InitializeAfterAIO) == "function" then
            pcall(HLBG.InitializeAfterAIO)
        end
        
        -- Register with AIO, but only when AIO.AddHandlers isn't present.
        -- If AddHandlers exists, another module (central binder) will attach handlers for "HLBG".
        if _G.AIO and _G.AIO.RegisterEvent and not _G.AIO.AddHandlers then
            -- Avoid double attempts from multiple files by using a shared in-progress flag
            HLBG._aioRegistered = HLBG._aioRegistered or false
            if not HLBG._aioRegistered and not HLBG._aioRegistering then
                HLBG._aioRegistering = true
                local ok, err = pcall(function()
                    _G.AIO.RegisterEvent("HLBG", function(command, args)
                        if type(command) ~= "string" then return end
                        args = args or {}
                        if type(HLBG.HandleAIOCommand) == "function" then
                            pcall(HLBG.HandleAIOCommand, command, args)
                            return
                        end

                        -- If no handler, log in dev mode
                        if HLBG._devMode and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                            HLBG = HLBG or {}
                            local c = tostring(command or '')
                            local argsStr = ''
                            if type(args) == 'table' then
                                for k,v in pairs(args) do argsStr = argsStr .. ' ' .. tostring(k) .. '=' .. tostring(v) end
                            else
                                argsStr = tostring(args or '')
                            end
                            if type(HLBG.SafePrint) == 'function' then
                                HLBG.SafePrint("|cFFFFAA00HLBG:|r AIO command handler not available: " .. c .. " Args:" .. argsStr)
                            else
                                DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00HLBG:|r AIO command handler not available: " .. c .. " Args:" .. argsStr)
                            end
                        end
                    end)
                end)
                HLBG._aioRegistering = nil
                if ok then
                    HLBG._aioRegistered = true
                    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                        HLBG = HLBG or {}
                        if type(HLBG.SafePrint) == 'function' then HLBG.SafePrint("|cFF88AA88HLBG:|r Legacy RegisterEvent hookup succeeded") else DEFAULT_CHAT_FRAME:AddMessage("|cFF88AA88HLBG:|r Legacy RegisterEvent hookup succeeded") end
                    end
                else
                    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r Failed to RegisterEvent HLBG: " .. tostring(err or '')) end
                end
            else
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cFF88AA88HLBG:|r Skipping RegisterEvent hookup (another module is registering)") end
            end
        else
            -- Modern AIO.AddHandlers method
            if _G.AIO and _G.AIO.AddHandlers then
                if not HLBG._aioHandlersRegistered then
                    local ok, handlers = pcall(function()
                        return _G.AIO.AddHandlers("HLBG", {})
                    end)
                    
                    if ok and type(handlers) == "table" then
                        -- Add our handler functions to the handlers table
                        handlers.Status = function(player, args)
                            if type(HLBG.HandleAIOCommand) == "function" then
                                pcall(HLBG.HandleAIOCommand, "Status", args)
                            end
                        end
                        
                        handlers.History = function(player, args)
                            if type(HLBG.HandleAIOCommand) == "function" then
                                pcall(HLBG.HandleAIOCommand, "History", args)
                            end
                        end
                        
                        handlers.Stats = function(player, args)
                            if type(HLBG.HandleAIOCommand) == "function" then
                                pcall(HLBG.HandleAIOCommand, "Stats", args)
                            end
                        end
                        
                        handlers.Server = function(player, args)
                            if type(HLBG.HandleAIOCommand) == "function" then
                                pcall(HLBG.HandleAIOCommand, "Server", args)
                            end
                        end
                        
                        handlers.Error = function(player, args)
                            if type(HLBG.HandleAIOCommand) == "function" then
                                pcall(HLBG.HandleAIOCommand, "Error", args)
                            end
                        end
                        
                        -- Generic handler for any command
                        handlers.Request = function(player, ...)
                            local vargs = {...}
                            if not vargs or type(vargs[1]) ~= 'string' then return end
                            local cmd = vargs[1]
                            -- Build params table from remaining varargs (positional payload)
                            local params = {}
                            for i = 2, #vargs do params[#params+1] = vargs[i] end
                            -- If the payload is a single table (legacy), use it directly
                            if #params == 1 and type(params[1]) == 'table' then params = params[1] end
                            if type(HLBG.HandleAIOCommand) == "function" then
                                pcall(HLBG.HandleAIOCommand, cmd, params)
                                -- Temp visual aid: show UI for 10s when any data arrives
                                -- Show the UI when data arrives, but do not auto-hide it (keep user in control)
                                pcall(function()
                                    if HLBG and HLBG.UI and HLBG.UI.Frame then
                                        if HLBG.UI.Frame.SetShown then HLBG.UI.Frame:SetShown(true) else HLBG.UI.Frame:Show() end
                                    end
                                end)
                            end
                        end
                        
                        HLBG._aioHandlersRegistered = true
                        HLBG._aioRegistered = true -- Mark as registered
                        
                        if DEFAULT_CHAT_FRAME then
                            DEFAULT_CHAT_FRAME:AddMessage("|cFF88AA88HLBG:|r AIO.AddHandlers registration successful")
                        end
                    else
                        if DEFAULT_CHAT_FRAME then
                            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r AIO.AddHandlers failed: " .. tostring(handlers))
                        end
                    end
                else
                    if DEFAULT_CHAT_FRAME then
                        DEFAULT_CHAT_FRAME:AddMessage("|cFF88AA88HLBG:|r AIO handlers already registered")
                    end
                end
            end
        end
        
        return true
    else
        -- AIO not available yet, increment retry counter
        aioCheckFrame.retryCount = aioCheckFrame.retryCount + 1
        
        if aioCheckFrame.retryCount >= aioCheckFrame.maxRetries then
            -- Too many retries, give up and show error
            aioCheckFrame:SetScript("OnUpdate", nil)
            
            if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r Required dependency AIO_Client not found after " .. tostring(aioCheckFrame.maxRetries) .. " attempts. Please ensure AIO_Client addon is installed and enabled.")
            end
            
            -- Record error in the load state
            if _G.HLBG_LoadState then
                _G.HLBG_LoadState.errors = _G.HLBG_LoadState.errors or {}
                table.insert(_G.HLBG_LoadState.errors, "AIO_Client dependency not found after " .. aioCheckFrame.maxRetries .. " attempts")
                _G.HLBG_LoadState.aioVerified = false
            end
            
            return false
        end
        
        -- If this is the first retry, show message
        if aioCheckFrame.retryCount == 1 and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00HLBG:|r Waiting for AIO_Client dependency to load...")
        end
        
        return false
    end
end

-- Set up OnUpdate to check for AIO
aioCheckFrame:SetScript("OnUpdate", function(self, elapsed)
    -- Only check every 0.5 seconds
    if not self.timeSinceLastCheck then self.timeSinceLastCheck = 0 end
    self.timeSinceLastCheck = self.timeSinceLastCheck + elapsed
    
    if self.timeSinceLastCheck >= 0.5 then
        self.timeSinceLastCheck = 0
        CheckAIO()
    end
end)

-- Also register for ADDON_LOADED event for AIO_Client
aioCheckFrame:RegisterEvent("ADDON_LOADED")
aioCheckFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "AIO_Client" then
        -- AIO_Client loaded, check if it's ready
        CheckAIO()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Store the check function globally for use by other files
_G.HLBG_CheckAIO = CheckAIO

-- Do an initial check immediately
CheckAIO()

-- Set up a helper function for AIO commands
function HLBG.HandleAIOCommand(command, args)
    if type(command) ~= "string" then return end
    args = args or {}
    -- normalize command to lower-case for case-insensitive handling
    local cmd = tostring(command or ''):lower()
    if HLBG._devMode and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        local t = type(args)
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF33FF99HLBG:|r Received AIO command '%s' (type %s)", tostring(cmd), tostring(t)))
    end
    
    -- Handle different command types
    if cmd == "status" then
        -- Status update (live match data)
        if type(HLBG.Status) == "function" then pcall(HLBG.Status, args) end
        return
    end
    
    if cmd == "history" then
        -- History data for UI - support multiple shapes from server
        local function dbg(msg)
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r '..tostring(msg)) end
        end
        if type(args) ~= 'table' then
            dbg('History: received non-table payload; ignoring')
            return
        end

        -- Case A: args.rows = { ... } (preferred)
        if type(args.rows) == 'table' then
            dbg(string.format('History: rows=%d total=%s (via args.rows)', #args.rows, tostring(args.total)))
            if type(HLBG.History) == 'function' then
                pcall(HLBG.History, args.rows, args.page or 1, args.perpage or args.per or 15, args.total or #args.rows, args.sort or args.order or 'id', args.order or args.sort or 'DESC')
                -- Quick visual fallback: ensure main UI is visible when data arrives, but only if frame exists
                pcall(function()
                    if HLBG and HLBG.UI and HLBG.UI.Frame then
                        if HLBG.UI.Frame.SetShown then HLBG.UI.Frame:SetShown(true) else HLBG.UI.Frame:Show() end
                    end
                end)
                return
            end
        end

        -- Case B: args.tsv provided
        if type(args.tsv) == 'string' and args.tsv ~= '' then
            dbg('History: received TSV payload')
            -- Pre-sanitize TSV to remove high bytes, normalize CRLF, and convert '||' markers
            local function strip_high_bytes(s)
                if type(s) ~= 'string' then return s end
                local out = {}
                for i=1,#s do local b = string.byte(s,i); if b and b < 128 then table.insert(out, string.char(b)) end end
                return table.concat(out)
            end
            local function sanitize(s)
                if type(s) ~= 'string' then return s end
                s = s:gsub('\r\n','\n'):gsub('\r','\n')
                s = s:gsub('%|%|','\n')
                -- Protect tabs/newlines
                local pTab, pNL = '\1','\2'
                s = s:gsub('\t', pTab):gsub('\n', pNL)
                s = s:gsub('%c', ' ')
                s = s:gsub(pTab, '\t'):gsub(pNL, '\n')
                s = strip_high_bytes(s)
                return s
            end
            local tsv = sanitize(args.tsv)
            if type(HLBG.HistoryStr) == 'function' then
                pcall(HLBG.HistoryStr, tsv, args.page or 1, args.perpage or args.per or 15, args.total or 0, args.sort or args.order or 'id', args.order or args.sort or 'DESC')
                pcall(function() if HLBG and HLBG.UI and HLBG.UI.Frame and HLBG.UI.Frame.Show then HLBG.UI.Frame:Show() end end)
                return
            end
        end

        -- Case C: positional-style table (e.g., { {row1}, {row2}, total=.. } ) or rows passed directly
        -- Detect array-like table where first element is a row table
        if #args > 0 and type(args[1]) == 'table' then
            dbg('History: array-like payload detected, using args as rows')
            local rows = {}
            for i=1,#args do if type(args[i])=='table' then rows[#rows+1]=args[i] end end
            if #rows>0 and type(HLBG.History) == 'function' then
                pcall(HLBG.History, rows, args.page or args[2] or 1, args.per or args.perpage or args[3] or 15, args.total or #rows, args.sort or 'id', args.order or 'DESC')
                pcall(function() if HLBG and HLBG.UI and HLBG.UI.Frame and HLBG.UI.Frame.Show then HLBG.UI.Frame:Show() end end)
                return
            end
        end

        -- Case D: legacy single-row table
        if (args.id or args.ts or args.winner) and type(HLBG.History) == 'function' then
            dbg('History: single-row payload detected; wrapping in array')
            pcall(HLBG.History, {args}, args.page or 1, args.perpage or 15, args.total or 1, args.sort or 'id', args.order or 'DESC')
            pcall(function() if HLBG and HLBG.UI and HLBG.UI.Frame and HLBG.UI.Frame.Show then HLBG.UI.Frame:Show() end end)
            return
        end

        dbg('History: no handler matched for payload')
        return
    end
    
    if cmd == "stats" then
        -- Statistics summary (support table or positional)
        if type(args) ~= 'table' then
            if type(HLBG.OnServerStats) == 'function' then pcall(HLBG.OnServerStats, { totalBattles = tonumber(args) or 0 }) end
            return
        end
        if type(HLBG.OnServerStats) == 'function' then
            pcall(HLBG.OnServerStats, args)
            return
        elseif #args > 0 then
            -- Positional: total, alliance, horde, draws...
            pcall(function()
                local s = {
                    totalBattles = tonumber(args[1]) or 0,
                    allianceWins = tonumber(args[2]) or 0,
                    hordeWins = tonumber(args[3]) or 0,
                    draws = tonumber(args[4]) or 0,
                }
                if type(HLBG.OnServerStats) == 'function' then HLBG.OnServerStats(s) elseif type(HLBG.Stats) == 'function' then HLBG.Stats(s) end
            end)
            return
        else
            if type(HLBG.Stats) == 'function' then pcall(HLBG.Stats, args) end
            return
        end
    end
    
    if cmd == "server" then
        -- Server info/welcome
        if type(args) == "table" and type(args.motd) == "string" and args.motd ~= "" then
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                HLBG = HLBG or {}
                local m = tostring(args.motd or '')
                if type(HLBG.SafePrint) == 'function' then HLBG.SafePrint("|cFF88EEEEHLBG Server:|r " .. m) else DEFAULT_CHAT_FRAME:AddMessage("|cFF88EEEEHLBG Server:|r " .. m) end
            end
        end
        if type(args) == "table" and args.season and type(HLBG.SetCurrentSeason) == "function" then
            pcall(HLBG.SetCurrentSeason, tonumber(args.season) or 0)
        end
        return
    end
    
    if cmd == "error" then
        -- Error message from server
        if type(args) == "table" and type(args.message) == "string" then
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                HLBG = HLBG or {}
                local m = tostring(args.message or '')
                if type(HLBG.SafePrint) == 'function' then HLBG.SafePrint("|cFFFF0000HLBG Error:|r " .. m) else DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r " .. m) end
            end
        end
        return
    end
    
    -- Unknown command, log if in dev mode
    if HLBG._devMode and DEFAULT_CHAT_FRAME then
        local argsStr = ""
        if type(args) == "table" then
            for k,v in pairs(args) do argsStr = argsStr .. " " .. tostring(k) .. "=" .. tostring(v) end
        else
            argsStr = tostring(args)
        end
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            HLBG = HLBG or {}
            local c = tostring(command or '')
            if type(HLBG.SafePrint) == 'function' then HLBG.SafePrint("|cFF88AA88HLBG:|r Unknown command: " .. c .. " Args: " .. tostring(argsStr or '')) else DEFAULT_CHAT_FRAME:AddMessage("|cFF88AA88HLBG:|r Unknown command: " .. c .. " Args: " .. tostring(argsStr or '')) end
        end
    end
end

-- Function to safely send commands to server via AIO
function HLBG.SendCommand(command, args)
    if type(command) ~= "string" then return end
    args = args or {}
    if type(args) ~= "table" then args = { value = tostring(args) } end
    
    -- Verify AIO is loaded and ready
    if not _G.AIO or not _G.AIO.Handle then 
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r AIO not ready") end
        return
    end
    
    -- Add current desired season if needed
    if not args.season and type(HLBG._getSeason) == "function" then 
        args.season = HLBG._getSeason() 
    end
    
    -- Send command via AIO
    _G.AIO.Handle("HLBG", command, args)
end
