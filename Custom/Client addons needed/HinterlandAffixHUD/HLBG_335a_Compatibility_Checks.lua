-- HLBG_335a_Compatibility_Checks.lua
-- This file checks for and fixes compatibility issues with WoW 3.3.5a client

-- Ensure HLBG namespace exists
HLBG = HLBG or {}
HLBG.Compat = HLBG.Compat or {}

-- Run compatibility checks for WoW 3.3.5a
HLBG.Compat.RunChecks = function()
    print("|cFF33FF99Hinterland BG:|r Running WoW 3.3.5a compatibility checks...")
    
    -- Check 1: Verify all dropdowns have names
    local fixedDropdowns = 0
    for _, object in pairs(_G) do
        if type(object) == "table" and object.IsObjectType then
            if (object:IsObjectType("Frame") and (object.dropdown or (object.Initialize and object.CreateBackdrop))) or
               (object:IsObjectType("Button") and (object:GetName() and object:GetName():find("DropDown"))) or
               (object:GetObjectType and object:GetObjectType() == "Button" and object.Left and object.Middle and object.Right) then
                -- This looks like a dropdown menu
                local name = object:GetName()
                if not name or name == "" then
                    -- Generate a unique name for the dropdown
                    local uniqueName = "HLBG_DropDown_" .. tostring(math.floor(GetTime() * 1000))
                    object:SetName(uniqueName)
                    print("|cFF33FF99Hinterland BG:|r Fixed unnamed dropdown: " .. uniqueName)
                    fixedDropdowns = fixedDropdowns + 1
                end
            end
        end
    end
    
    -- Check 2: Verify CloseDropDownMenus is available or provide fallback
    if not CloseDropDownMenus then
        _G.CloseDropDownMenus = function()
            if DropDownList1 and DropDownList1:IsShown() then DropDownList1:Hide() end
            if DropDownList2 and DropDownList2:IsShown() then DropDownList2:Hide() end
        end
        print("|cFF33FF99Hinterland BG:|r Added CloseDropDownMenus fallback function")
    end
    
    -- Check 3: Hook ToggleDropDownMenu if not already done
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
                dropDownFrame:SetName(uniqueName)
                print("|cFF33FF99Hinterland BG:|r Named dropdown menu on toggle: " .. uniqueName)
            end
            
            return HLBG.Compat.originalToggleDropDownMenu(level or 1, value, dropDownFrame, anchorName, xOffset or 0, yOffset or 0, menuList, button, autoHideDelay)
        end
        print("|cFF33FF99Hinterland BG:|r Hooked ToggleDropDownMenu for safety")
    end
    
    -- Check 4: Make sure UIDropDownMenu_* functions exist
    local uiDropDownFuncs = {
        "UIDropDownMenu_Initialize",
        "UIDropDownMenu_SetWidth",
        "UIDropDownMenu_SetText",
        "UIDropDownMenu_AddButton",
        "UIDropDownMenu_CreateInfo"
    }
    
    local missingFuncs = 0
    for _, funcName in ipairs(uiDropDownFuncs) do
        if not _G[funcName] then
            missingFuncs = missingFuncs + 1
            print("|cFFFF0000HLBG Error:|r Missing dropdown function: " .. funcName)
        end
    end
    
    if missingFuncs > 0 then
        print("|cFFFF0000HLBG Error:|r " .. missingFuncs .. " dropdown functions missing! UI may not work correctly.")
    end
    
    -- Check 5: Ensure C_Timer is implemented
    if not C_Timer then
        print("|cFF33FF99Hinterland BG:|r Implementing C_Timer compatibility layer")
        C_Timer = {}
        C_Timer.timers = {}
        
        function C_Timer.After(seconds, callback)
            if type(callback) ~= "function" then return end
            local timer = {}
            timer.callback = callback
            timer.expireAt = GetTime() + seconds
            table.insert(C_Timer.timers, timer)
            
            if not C_Timer.frame then
                C_Timer.frame = CreateFrame("Frame")
                C_Timer.frame:SetScript("OnUpdate", function()
                    local now = GetTime()
                    local i = 1
                    while i <= #C_Timer.timers do
                        local t = C_Timer.timers[i]
                        if t.expireAt and t.expireAt <= now then
                            table.remove(C_Timer.timers, i)
                            pcall(t.callback)
                        else
                            i = i + 1
                        end
                    end
                end)
            end
            
            return timer
        end
    end
    
    -- Report results
    print(string.format("|cFF33FF99Hinterland BG:|r Compatibility check complete. Fixed %d dropdowns.", fixedDropdowns))
    return true
end

-- Run compatibility checks when this file loads
C_Timer.After(0.5, function()
    if HLBG.Compat.RunChecks then
        HLBG.Compat.RunChecks()
    end
end)

-- Register a slash command to run the checks manually
SLASH_HLBGCOMPAT1 = "/hlbgcompat"
SlashCmdList["HLBGCOMPAT"] = function(msg)
    if HLBG.Compat.RunChecks then
        HLBG.Compat.RunChecks()
    end
end