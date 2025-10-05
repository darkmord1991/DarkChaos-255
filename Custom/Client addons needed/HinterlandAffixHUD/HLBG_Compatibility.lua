-- HLBG_Compatibility.lua
-- Provides compatibility functions for different WoW versions

-- Ensure HLBG namespace exists
HLBG = HLBG or {}
HLBG.Compat = {}

-- Detect the client version
local _, _, _, tocversion = GetBuildInfo()
HLBG.Compat.clientVersion = tocversion
HLBG.Compat.isWotLK = (tocversion <= 30300)

-- Print version info
print(string.format("|cFF33FF99Hinterland BG:|r Detected WoW client version %s", HLBG.Compat.clientVersion))

-- Implement C_Timer for versions that don't have it (WotLK and earlier)
if not C_Timer then
    print("|cFF33FF99Hinterland BG:|r Adding C_Timer compatibility layer")
    C_Timer = {}
    C_Timer.timers = {}
    
    -- After function implementation for WoW 3.3.5
    function C_Timer.After(seconds, callback)
        if type(callback) ~= "function" then return end
        
        local timer = {}
        timer.callback = callback
        timer.expireAt = GetTime() + seconds
        
        table.insert(C_Timer.timers, timer)
        
        -- Create the update frame if it doesn't exist
        if not C_Timer.frame then
            C_Timer.frame = CreateFrame("Frame")
            C_Timer.frame:SetScript("OnUpdate", function()
                local now = GetTime()
                local i = 1
                while i <= #C_Timer.timers do
                    local timer = C_Timer.timers[i]
                    if timer.expireAt <= now then
                        -- Remove timer before calling the callback to avoid issues if the callback adds new timers
                        table.remove(C_Timer.timers, i)
                        pcall(timer.callback)
                    else
                        i = i + 1
                    end
                end
            end)
        end
        
        return timer
    end
    
    -- Cancel function implementation for completeness
    function C_Timer.Cancel(timer)
        for i = #C_Timer.timers, 1, -1 do
            if C_Timer.timers[i] == timer then
                table.remove(C_Timer.timers, i)
                return true
            end
        end
        return false
    end
    
    -- NewTicker function implementation
    function C_Timer.NewTicker(seconds, callback, iterations)
        if type(callback) ~= "function" then return end
        
        local ticker = {}
        ticker.callback = callback
        ticker.seconds = seconds
        ticker.iterations = iterations
        ticker.iterationsLeft = iterations
        ticker.expireAt = GetTime() + seconds
        ticker.cancelled = false
        
        function ticker:Cancel()
            self.cancelled = true
        end
        
        table.insert(C_Timer.timers, ticker)
        
        -- Create the update frame if it doesn't exist
        if not C_Timer.frame then
            C_Timer.frame = CreateFrame("Frame")
            C_Timer.frame:SetScript("OnUpdate", function()
                local now = GetTime()
                local i = 1
                while i <= #C_Timer.timers do
                    local t = C_Timer.timers[i]
                    if t.cancelled then
                        table.remove(C_Timer.timers, i)
                    elseif t.expireAt and t.expireAt <= now then
                        if t.iterationsLeft then
                            -- This is a ticker
                            pcall(t.callback, t)
                            t.iterationsLeft = t.iterationsLeft - 1
                            if t.iterationsLeft <= 0 then
                                table.remove(C_Timer.timers, i)
                            else
                                t.expireAt = now + t.seconds
                                i = i + 1
                            end
                        else
                            -- This is a one-shot timer
                            table.remove(C_Timer.timers, i)
                            pcall(t.callback)
                        end
                    else
                        i = i + 1
                    end
                end
            end)
        end
        
        return ticker
    end
end

-- Additional compatibility functions for WotLK
if HLBG.Compat.isWotLK then
    -- Add missing string.split function
    if not string.split then
        function string.split(str, delimiter)
            if delimiter == nil then
                delimiter = "%s"
            end
            local t = {}
            for substr in string.gmatch(str, "[^" .. delimiter .. "]+") do
                table.insert(t, substr)
            end
            return unpack(t)
        end
    end
    
    -- Missing string functions
    if not string.trim then
        function string.trim(s)
            return string.gsub(s, "^%s*(.-)%s*$", "%1")
        end
    end
    
    -- Add table.wipe (renamed to ClearTable in WotLK)
    if not table.wipe and table.ClearTable then
        table.wipe = table.ClearTable
    end
end

-- Fix for UIDropDownMenu issue in WoW 3.3.5a
HLBG.Compat.fixDropdownMenus = function()
    -- Find all dropdown menus in the UI
    for _, object in pairs(_G) do
        -- Check if it's a dropdown menu frame
        if type(object) == "table" and object.IsObjectType then
            if (object:IsObjectType("Frame") and (object.dropdown or (object.Initialize and object.CreateBackdrop))) or
               (object:IsObjectType("Button") and (object:GetName() and object:GetName():find("DropDown"))) or
               (object.GetObjectType and object:GetObjectType() == "Button" and object.Left and object.Middle and object.Right) then
                -- This looks like a dropdown menu
                local name = object:GetName()
                if not name or name == "" then
                    -- Generate a unique name for the dropdown
                    local uniqueName = "HLBG_DropDown_" .. tostring(math.floor(GetTime() * 1000))
                    print("|cFF33FF99Hinterland BG:|r Named dropdown menu: " .. uniqueName)
                    object:SetName(uniqueName)
                end
            end
        end
    end
    
    -- Also hook the toggle function to ensure proper parameters
    if not HLBG.Compat.originalToggleDropDownMenu then
        HLBG.Compat.originalToggleDropDownMenu = ToggleDropDownMenu
        _G.ToggleDropDownMenu = function(level, value, dropDownFrame, anchorName, xOffset, yOffset, menuList, button, autoHideDelay)
            if not dropDownFrame then
                print("|cFFFF0000HLBG Error:|r Attempt to toggle dropdown menu with nil frame")
                return
            end
            
            -- Ensure the frame has a name
            if not dropDownFrame:GetName() or dropDownFrame:GetName() == "" then
                local uniqueName = "HLBG_DropDown_" .. tostring(math.floor(GetTime() * 1000))
                print("|cFF33FF99Hinterland BG:|r Named dropdown menu on toggle: " .. uniqueName)
                dropDownFrame:SetName(uniqueName)
            end
            
            return HLBG.Compat.originalToggleDropDownMenu(level or 1, value, dropDownFrame, anchorName, xOffset or 0, yOffset or 0, menuList, button, autoHideDelay)
        end
    end
end

-- Safe way to handle UI errors
HLBG.Compat.safeCall = function(func, ...)
    if not func then return end
    
    local success, result = pcall(func, ...)
    if not success then
        print("|cFFFF0000HLBG Error:|r " .. (result or "Unknown error"))
    end
    return result
end

-- Run the dropdown fix when the compatibility layer loads
if C_Timer and C_Timer.After then
    C_Timer.After(1, function()
        HLBG.Compat.safeCall(HLBG.Compat.fixDropdownMenus)
        print("|cFF33FF99Hinterland BG:|r Fixed dropdown menus")
    end)
else
    -- Fallback if C_Timer not available yet
    local fallbackFrame = CreateFrame("Frame")
    local elapsed = 0
    fallbackFrame:SetScript("OnUpdate", function(self, e)
        elapsed = elapsed + e
        if elapsed >= 1 then
            HLBG.Compat.safeCall(HLBG.Compat.fixDropdownMenus)
            print("|cFF33FF99Hinterland BG:|r Fixed dropdown menus (fallback)")
            self:SetScript("OnUpdate", nil)
        end
    end)
end

print("|cFF33FF99Hinterland BG:|r Compatibility layer loaded")