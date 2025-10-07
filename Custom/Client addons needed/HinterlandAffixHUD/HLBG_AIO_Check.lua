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
                            local args = {...}
                            if args[1] then
                                if type(HLBG.HandleAIOCommand) == "function" then
                                    pcall(HLBG.HandleAIOCommand, args[1], args[2])
                                end
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
    
    -- Handle different command types
    if command == "Status" or command == "status" then
        -- Status update (live match data)
        if type(HLBG.Status) == "function" then pcall(HLBG.Status, args) end
        return
    end
    
    if command == "History" or command == "history" then
        -- History data for UI
        if type(args) == "table" and type(args.rows) == "table" then
            if type(HLBG.History) == "function" then
                pcall(HLBG.History, args.rows, args.page or 1, args.perpage or 5, args.total or #args.rows, args.sort or "id", args.order or "DESC")
            elseif type(HLBG._pushHistoryRow) == "function" and args.rows[1] then
                -- If no history handler, push first row to buffer
                pcall(HLBG._pushHistoryRow, args.rows[1])
            end
        elseif type(args) == "table" and type(args.tsv) == "string" then
            -- Alternative format: TSV string
            if type(HLBG.HistoryStr) == "function" then
                pcall(HLBG.HistoryStr, args.tsv, args.page or 1, args.perpage or 5, args.total or 0, args.sort or "id", args.order or "DESC")
            end
        end
        return
    end
    
    if command == "Stats" or command == "stats" then
        -- Statistics summary
        if type(HLBG.Stats) == "function" then pcall(HLBG.Stats, args) end
        return
    end
    
    if command == "Server" or command == "server" then
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
    
    if command == "Error" or command == "error" then
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