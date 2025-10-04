-- HLBG_LoadDebug.lua - Tracks addon loading process (Emergency Version)

-- Initialize load tracking
_G.HLBG_LoadState = _G.HLBG_LoadState or {
    startTime = time(),
    errors = {},
    loadedAddons = {},
    aioLoaded = false,
    aioAvailable = false
}

-- Initialize file tracking
_G.HLBG_LoadedFiles = _G.HLBG_LoadedFiles or {}

-- Function to record file loads
_G.HLBG_RecordFileLoad = function(fileName)
    if not fileName then return end
    
    -- Record the file was loaded
    table.insert(_G.HLBG_LoadedFiles, fileName)
    
    -- Print a message if we want debug output
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAEEFFHLBG Emergency Load:|r " .. fileName)
    end
    
    -- If this is the first file loaded, set up event tracking
    if #_G.HLBG_LoadedFiles == 1 then
        -- Create a frame to track addon loading events
        local frame = CreateFrame("Frame", "HLBG_LoadDebugFrame")
        frame:RegisterEvent("ADDON_LOADED")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:RegisterEvent("PLAYER_LOGIN")
        
        frame:SetScript("OnEvent", function(self, event, addon)
            if event == "ADDON_LOADED" then
                -- Record loaded addons
                _G.HLBG_LoadState.loadedAddons[addon] = true
                
                -- Check for specific addons we care about
                if addon == "AIO_Client" then
                    _G.HLBG_LoadState.aioLoaded = true
                    
                    -- Check if AIO is actually available
                    if _G.AIO and type(_G.AIO) == "table" and type(_G.AIO.Handle) == "function" then
                        _G.HLBG_LoadState.aioAvailable = true
                    else
                        _G.HLBG_LoadState.aioAvailable = false
                        table.insert(_G.HLBG_LoadState.errors, "AIO_Client loaded but AIO global not available")
                    end
                    
                    if DEFAULT_CHAT_FRAME then
                        DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFFHLBG Emergency:|r AIO_Client loaded, AIO " .. 
                            ((_G.HLBG_LoadState.aioAvailable and "is available") or "is NOT available"))
                    end
                elseif addon == "HinterlandAffixHUD_Emergency" then
                    _G.HLBG_LoadState.addonLoaded = time()
                    
                    if DEFAULT_CHAT_FRAME then
                        DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFFHLBG Emergency:|r Addon fully loaded")
                        
                        -- Check if AIO is already loaded
                        if _G.HLBG_LoadState.aioLoaded then
                            DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFFHLBG Emergency:|r AIO_Client was loaded " .. 
                                (_G.HLBG_LoadState.aioLoaded - _G.HLBG_LoadState.startTime) .. "s ago")
                        else
                            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF6600HLBG Emergency:|r AIO_Client has not been loaded yet!")
                        end
                    end
                end
            elseif event == "PLAYER_LOGIN" then
                _G.HLBG_LoadState.playerLogin = time()
                
                if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF88EEEEHLBG Emergency:|r PLAYER_LOGIN triggered")
                    
                    -- Check AIO status again
                    if _G.AIO and type(_G.AIO) == "table" and type(_G.AIO.Handle) == "function" then
                        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG Emergency:|r AIO is available at PLAYER_LOGIN")
                        _G.HLBG_LoadState.aioAvailableAtLogin = true
                        _G.HLBG_LoadState.aioLoaded = true
                        _G.HLBG_LoadState.aioAvailable = true
                    else
                        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF6600HLBG Emergency:|r AIO is NOT available at PLAYER_LOGIN")
                        _G.HLBG_LoadState.aioAvailableAtLogin = false
                    end
                end
            elseif event == "PLAYER_ENTERING_WORLD" then
                _G.HLBG_LoadState.playerEnteringWorld = time()
                
                -- Do one final AIO check
                if _G.AIO and type(_G.AIO) == "table" and type(_G.AIO.Handle) == "function" then
                    _G.HLBG_LoadState.aioLoaded = true
                    _G.HLBG_LoadState.aioAvailable = true
                end
                
                if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF88EEEEHLBG Emergency:|r PLAYER_ENTERING_WORLD triggered")
                    
                    -- Display summary
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFFHLBG Emergency Summary:|r")
                    DEFAULT_CHAT_FRAME:AddMessage("  Files loaded: " .. #_G.HLBG_LoadedFiles)
                    DEFAULT_CHAT_FRAME:AddMessage("  Addons loaded: " .. (next(_G.HLBG_LoadState.loadedAddons) and table.maxn(_G.HLBG_LoadState.loadedAddons) or 0))
                    DEFAULT_CHAT_FRAME:AddMessage("  AIO_Client loaded: " .. tostring(_G.HLBG_LoadState.aioLoaded))
                    DEFAULT_CHAT_FRAME:AddMessage("  AIO available: " .. tostring(_G.HLBG_LoadState.aioAvailable))
                    DEFAULT_CHAT_FRAME:AddMessage("  Errors: " .. #_G.HLBG_LoadState.errors)
                    
                    -- Display errors if any
                    if #_G.HLBG_LoadState.errors > 0 then
                        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF6600HLBG Emergency Errors:|r")
                        for i, err in ipairs(_G.HLBG_LoadState.errors) do
                            DEFAULT_CHAT_FRAME:AddMessage("  " .. i .. ". " .. err)
                        end
                    end
                end
            end
        end)
    end
end

-- Record that this file was loaded (self-tracking)
_G.HLBG_RecordFileLoad("HLBG_LoadDebug.lua")

-- Notify that debugging is initialized
if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG Emergency:|r Loading diagnostics initialized")
end