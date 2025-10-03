-- HLBG_UI_Settings.lua - Settings interface for Hinterland Battleground

-- Ensure HLBG namespace exists
HLBG = HLBG or {}

-- Settings page handler
function HLBG.ShowSettings()
    HLBG._ensureUI('Settings')
    local s = HLBG.UI and HLBG.UI.SettingsPane
    if not s then return end
    
    -- Initialize UI components if needed
    if not s.initialized then
        -- Create scrollable frame for settings
        s.ScrollFrame = CreateFrame("ScrollFrame", "HLBG_SettingsScrollFrame", s, "UIPanelScrollFrameTemplate")
        s.ScrollFrame:SetPoint("TOPLEFT", s, "TOPLEFT", 10, -10)
        s.ScrollFrame:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -30, 10)
        
        s.Content = CreateFrame("Frame", "HLBG_SettingsScrollContent", s.ScrollFrame)
        s.Content:SetSize(s:GetWidth() - 40, 600)  -- Make it tall enough for all settings
        s.ScrollFrame:SetScrollChild(s.Content)
        
        -- Title
        s.Title = s.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        s.Title:SetPoint("TOPLEFT", s.Content, "TOPLEFT", 5, -5)
        s.Title:SetPoint("RIGHT", s.Content, "RIGHT", -5, 0)
        s.Title:SetJustifyH("CENTER")
        s.Title:SetText("Hinterland Battleground Settings")
        
        -- Local function to create section headers
        local function CreateHeader(text, anchor, yOffset)
            local header = s.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
            header:SetText(text)
            header:SetTextColor(1, 0.82, 0)
            return header
        end
        
        -- Local function to create checkboxes
        local function CreateCheckbox(text, anchor, yOffset, savedVarName, defaultValue, callback)
            local checkbox = CreateFrame("CheckButton", nil, s.Content, "UICheckButtonTemplate")
            checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 5, yOffset)
            checkbox.text:SetText(text)
            
            -- Set initial state from saved variable
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            checkbox:SetChecked(HinterlandAffixHUDDB[savedVarName] ~= nil and HinterlandAffixHUDDB[savedVarName] or defaultValue)
            
            -- OnClick handler
            checkbox:SetScript("OnClick", function(self)
                HinterlandAffixHUDDB[savedVarName] = self:GetChecked()
                if type(callback) == "function" then
                    callback(self:GetChecked())
                end
            end)
            
            return checkbox
        end
        
        -- Local function to create sliders
        local function CreateSlider(text, anchor, yOffset, min, max, step, savedVarName, defaultValue, formatter, callback)
            local sliderText = s.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            sliderText:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 10, yOffset)
            sliderText:SetText(text)
            
            local slider = CreateFrame("Slider", nil, s.Content, "OptionsSliderTemplate")
            slider:SetPoint("TOPLEFT", sliderText, "BOTTOMLEFT", 5, -5)
            slider:SetWidth(200)
            slider:SetMinMaxValues(min, max)
            slider:SetValueStep(step)
            
            -- Set initial value from saved variable
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            local value = HinterlandAffixHUDDB[savedVarName] ~= nil and HinterlandAffixHUDDB[savedVarName] or defaultValue
            slider:SetValue(value)
            
            -- Set slider labels
            getglobal(slider:GetName().."Low"):SetText(formatter(min))
            getglobal(slider:GetName().."High"):SetText(formatter(max))
            getglobal(slider:GetName().."Text"):SetText(formatter(value))
            
            -- OnValueChanged handler
            slider:SetScript("OnValueChanged", function(self, value)
                -- Round to step precision if needed
                if step == math.floor(step) then
                    value = math.floor(value + 0.5)
                else
                    -- Round to nearest step
                    value = math.floor((value / step) + 0.5) * step
                end
                
                getglobal(self:GetName().."Text"):SetText(formatter(value))
                HinterlandAffixHUDDB[savedVarName] = value
                
                if type(callback) == "function" then
                    callback(value)
                end
            end)
            
            return slider, sliderText
        end
        
        -- Local function to create input boxes
        local function CreateInputBox(text, anchor, yOffset, width, savedVarName, defaultValue, isNumeric, callback)
            local boxText = s.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            boxText:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 10, yOffset)
            boxText:SetText(text)
            
            local inputBox = CreateFrame("EditBox", nil, s.Content, "InputBoxTemplate")
            inputBox:SetPoint("LEFT", boxText, "RIGHT", 10, 0)
            inputBox:SetSize(width, 20)
            inputBox:SetAutoFocus(false)
            
            if isNumeric then
                inputBox:SetNumeric(true)
            end
            
            -- Set initial value from saved variable
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            local value = HinterlandAffixHUDDB[savedVarName] ~= nil and HinterlandAffixHUDDB[savedVarName] or defaultValue
            inputBox:SetText(tostring(value))
            
            -- Set script handlers
            inputBox:SetScript("OnEnterPressed", function(self)
                local newValue = isNumeric and tonumber(self:GetText()) or self:GetText()
                HinterlandAffixHUDDB[savedVarName] = newValue
                self:ClearFocus()
                
                if type(callback) == "function" then
                    callback(newValue)
                end
            end)
            
            inputBox:SetScript("OnEscapePressed", function(self)
                self:SetText(tostring(HinterlandAffixHUDDB[savedVarName]))
                self:ClearFocus()
            end)
            
            return inputBox, boxText
        end
        
        -- Local function to create buttons
        local function CreateButton(text, anchor, yOffset, width, height, callback)
            local button = CreateFrame("Button", nil, s.Content, "UIPanelButtonTemplate")
            button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 10, yOffset)
            button:SetSize(width, height)
            button:SetText(text)
            
            button:SetScript("OnClick", callback)
            
            return button
        end
        
        -- Display Settings Section
        s.DisplayHeader = CreateHeader("Display Settings", s.Title, -30)
        
        -- HUD Scale slider
        s.ScaleSlider, s.ScaleText = CreateSlider(
            "HUD Scale:", 
            s.DisplayHeader, 
            -10, 
            0.5, 2.0, 0.05, 
            "scale", 1.0, 
            function(val) return string.format("%.2f", val) end,
            function(val) 
                -- Apply scale to HUD frame
                local hudFrame = _G["HinterlandAffixHUD"]
                if hudFrame then hudFrame:SetScale(val) end
            end
        )
        
        -- Lock HUD Position
        s.LockHUD = CreateCheckbox(
            "Lock HUD Position", 
            s.ScaleSlider, 
            -25, 
            "locked", 
            true,
            function(checked)
                -- Apply lock to HUD frame
                local hudFrame = _G["HinterlandAffixHUD"]
                if hudFrame then 
                    if checked then
                        hudFrame:SetMovable(false)
                    else
                        hudFrame:SetMovable(true)
                    end
                end
            end
        )
        
        -- Hide Default UI
        s.HideDefault = CreateCheckbox(
            "Hide Default Blizzard HUD Elements", 
            s.LockHUD, 
            -10, 
            "hideDefault", 
            false,
            function(checked)
                -- Apply the setting
                if _G.applyHideHUD then _G.applyHideHUD() end
            end
        )
        
        -- Anchor Under Default UI
        s.AnchorUnder = CreateCheckbox(
            "Anchor Under Default HUD Elements", 
            s.HideDefault, 
            -10, 
            "anchorUnder", 
            false,
            function(checked)
                -- Apply the anchor setting
                if checked and _G.AnchorUnderAlwaysUp then
                    _G.AnchorUnderAlwaysUp()
                elseif not checked and _G.ApplySavedPositionAndScale then
                    _G.ApplySavedPositionAndScale()
                end
            end
        )
        
        -- Reset Position Button
        s.ResetButton = CreateButton(
            "Reset HUD Position", 
            s.AnchorUnder, 
            -15, 
            150, 22,
            function()
                HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
                HinterlandAffixHUDDB.pos = nil
                if _G.ApplySavedPositionAndScale then _G.ApplySavedPositionAndScale() end
            end
        )
        
        -- Notification Settings Section
        s.NotifyHeader = CreateHeader("Notification Settings", s.ResetButton, -30)
        
        -- Play Sound on Queue Pop
        s.QueueSound = CreateCheckbox(
            "Play Sound on Queue Pop", 
            s.NotifyHeader, 
            -10, 
            "queuePopSound", 
            true,
            nil
        )
        
        -- Play Sound on Match Start
        s.MatchSound = CreateCheckbox(
            "Play Sound on Match Start", 
            s.QueueSound, 
            -10, 
            "matchStartSound", 
            true,
            nil
        )
        
        -- Show Messages in Chat
        s.ChatMessages = CreateCheckbox(
            "Show Messages in Chat Frame", 
            s.MatchSound, 
            -10, 
            "chatMessages", 
            true,
            nil
        )
        
        -- Queue Settings Section
        s.QueueHeader = CreateHeader("Queue Settings", s.ChatMessages, -30)
        
        -- Auto-teleport
        s.AutoTeleport = CreateCheckbox(
            "Auto-Teleport When Match Starts", 
            s.QueueHeader, 
            -10, 
            "autoTeleport", 
            true,
            function(checked)
                -- Send preference to server if AIO is available
                if _G.AIO and _G.AIO.Handle then
                    _G.AIO.Handle("HLBG", "SetPreference", "autoTeleport", checked and "1" or "0")
                end
            end
        )
        
        -- AFK Warning
        s.AFKWarning = CreateCheckbox(
            "Enable AFK Warning", 
            s.AutoTeleport, 
            -10, 
            "enableAFKWarning", 
            true,
            nil
        )
        
        -- AFK Warning Time Slider
        s.AFKSlider, s.AFKText = CreateSlider(
            "AFK Warning After:", 
            s.AFKWarning, 
            -10, 
            30, 300, 10, 
            "afkWarnSeconds", 120, 
            function(val) return string.format("%d seconds", val) end,
            nil
        )
        
        -- Advanced Settings Section
        s.AdvancedHeader = CreateHeader("Advanced Settings", s.AFKSlider, -30)
        
        -- Developer Mode
        s.DevMode = CreateCheckbox(
            "Developer Mode", 
            s.AdvancedHeader, 
            -10, 
            "devMode", 
            false,
            function(checked)
                HLBG._devMode = checked
            end
        )
        
        -- Season Filter
        s.SeasonBox, s.SeasonText = CreateInputBox(
            "Season Filter:", 
            s.DevMode, 
            -15, 
            50, 
            "desiredSeason", 
            0, 
            true,
            nil
        )
        
        -- Season Note
        s.SeasonNote = s.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        s.SeasonNote:SetPoint("LEFT", s.SeasonBox, "RIGHT", 10, 0)
        s.SeasonNote:SetText("(0 = All/Current)")
        
        -- Worldstate ID
        s.WorldstateBox, s.WorldstateText = CreateInputBox(
            "Worldstate ID:", 
            s.SeasonBox, 
            -15, 
            100, 
            "worldstateId", 
            0xDD1010, 
            false,
            function(value)
                -- Convert hex string to number if needed
                if type(value) == "string" and value:match("^0x") then
                    HinterlandAffixHUDDB.worldstateId = tonumber(value)
                end
                
                -- Update display if possible
                if _G.update then _G.update() end
            end
        )
        
        -- Debug Level
        s.DebugBox, s.DebugText = CreateInputBox(
            "Debug Level:", 
            s.WorldstateBox, 
            -15, 
            50, 
            "debugLevel", 
            0, 
            true,
            nil
        )
        
        -- Version information
        s.VersionText = s.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        s.VersionText:SetPoint("BOTTOMRIGHT", s.Content, "BOTTOMRIGHT", -10, 10)
        s.VersionText:SetText("HinterlandAffixHUD v" .. (HLAFFIXHUD_VERSION or "1.5.0"))
        
        -- Calculate total height needed for scrolling
        local function updateHeight()
            -- Get position of the last element
            local lastY = s.DebugText:GetBottom() or 0
            local contentTop = s.Content:GetTop() or 0
            local totalHeight = contentTop - lastY + 50 -- Add padding
            
            s.Content:SetHeight(math.max(400, totalHeight))
        end
        
        -- Update height after all elements have rendered
        C_Timer.After(0.1, updateHeight)
        
        s.initialized = true
    end
    
    -- Show the UI
    if HLBG.UI and HLBG.UI.Frame and type(ShowTab) == "function" then
        HLBG.UI.Frame:Show()
        ShowTab(6)  -- Show Settings tab
    end
end

-- Register this function to be called when Settings tab is selected
if not HLBG._tabHandlers then HLBG._tabHandlers = {} end
HLBG._tabHandlers[6] = HLBG.ShowSettings