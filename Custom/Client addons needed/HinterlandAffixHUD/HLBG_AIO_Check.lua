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
        
        -- Log success
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG:|r AIO dependency verified, initializing addon")
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
        
        -- Register with AIO
        if _G.AIO and _G.AIO.RegisterEvent then
            _G.AIO.RegisterEvent("HLBG", function(command, args)
                if type(command) ~= "string" then return end
                if type(HLBG.HandleAIOCommand) == "function" then
                    pcall(HLBG.HandleAIOCommand, command, args or {})
                elseif DEFAULT_CHAT_FRAME and HLBG._devMode then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00HLBG:|r AIO command handler not available: " .. command)
                end
            end)
        end
        
        return true
    else
        -- AIO not available yet, increment retry counter
        aioCheckFrame.retryCount = aioCheckFrame.retryCount + 1
        
        if aioCheckFrame.retryCount >= aioCheckFrame.maxRetries then
            -- Too many retries, give up and show error
            aioCheckFrame:SetScript("OnUpdate", nil)
            
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r Required dependency AIO_Client not found after " .. 
                    aioCheckFrame.maxRetries .. " attempts. Please ensure AIO_Client addon is installed and enabled.")
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
                DEFAULT_CHAT_FRAME:AddMessage("|cFF88EEEEHLBG Server:|r " .. args.motd)
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
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Error:|r " .. args.message)
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
        DEFAULT_CHAT_FRAME:AddMessage("|cFF88AA88HLBG:|r Unknown command: " .. command .. " Args: " .. argsStr)
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