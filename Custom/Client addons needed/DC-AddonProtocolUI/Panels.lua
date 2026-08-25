-- Panels.lua - Settings, testing and diagnostics panels for DC-AddonProtocol.
--
-- Lifted verbatim out of DCAddonProtocol.lua. These three panels register
-- themselves with InterfaceOptions at load; because this addon is
-- LoadOnDemand, that now happens the first time a player actually opens one
-- (via /dcpanel, /dcdiag or `/dc panel`) rather than at every login.

local DC = DCAddonProtocol
if not DC then
    return
end

-- ============================================================
-- Settings Panel with Debug/Testing Interface
-- ============================================================

local function CreateSettingsPanel()
    DC:_InitDB()

    local panel = CreateFrame("Frame", "DCProtocolSettingsPanel", UIParent)
    panel.name = "DC Protocol"
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00ff00DC Addon Protocol|r - Settings")
    
    -- Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(560)
    desc:SetJustifyH("LEFT")
    desc:SetText("Protocol status and logging/alert settings. Use the 'Testing' subpanel for JSON message testing.")
    
    local yPos = -70
    
    -- Status Section
    local statusHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    statusHeader:SetPoint("TOPLEFT", 16, yPos)
    statusHeader:SetText("|cffffd700Protocol Status|r")
    yPos = yPos - 20
    
    local statusText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    statusText:SetPoint("TOPLEFT", 16, yPos)
    statusText:SetWidth(300)
    statusText:SetJustifyH("LEFT")
    DC._statusText = statusText
    yPos = yPos - 50
    
    local function UpdateStatus()
        local connected = DC._connected and "|cff00ff00Connected|r" or "|cffff0000Disconnected|r"
        local version = DC._serverVersion or "Unknown"
        local handlers = DC:CountHandlers()
        local debug = DC._debug and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        statusText:SetText(
            "Status: " .. connected .. "\n" ..
            "Client Version: |cff00ccff" .. DC.VERSION .. "|r\n" ..
            "Server Version: |cff00ccff" .. version .. "|r\n" ..
            "Handlers: |cffffff00" .. handlers .. "|r\n" ..
            "Debug Mode: " .. debug
        )
    end

    -- Settings Section
    local settingsHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    settingsHeader:SetPoint("TOPLEFT", 330, yPos + 45)
    settingsHeader:SetText("|cffffd700Logging & Alerts|r")

    local function CreateCheckbox(text, tooltip, x, y, getFn, setFn)
        local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", x, y)

        -- 3.3.5a compatibility: InterfaceOptionsCheckButtonTemplate may not provide a .Text region.
        local label = cb.Text
        if not label and cb.GetName and cb:GetName() then
            label = _G[cb:GetName() .. "Text"]
        end
        if not label then
            label = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            label:SetPoint("LEFT", cb, "RIGHT", 0, 1)
            cb._label = label
        end
        label:SetText(text)

        cb.tooltipText = tooltip
        cb:SetScript("OnClick", function(self)
            local checked = self:GetChecked() and true or false
            if setFn then setFn(checked) end
        end)
        cb.Refresh = function()
            if getFn then
                cb:SetChecked(getFn() and true or false)
            end
        end
        cb:Refresh()
        return cb
    end

    local function CreateNumberInput(labelText, tooltip, x, y, width, getFn, setFn)
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("TOPLEFT", x, y)
        label:SetText(labelText)

        local input = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        input:SetPoint("LEFT", label, "RIGHT", 8, 0)
        local finalWidth = width or 50
        if finalWidth < 80 then
            finalWidth = 80
        end
        input:SetWidth(finalWidth)
        input:SetHeight(20)
        input:SetAutoFocus(false)
        input:SetMaxLetters(6)
        if input.SetTextInsets then
            input:SetTextInsets(6, 6, 0, 0)
        end
        input.tooltipText = tooltip

        local function refresh()
            local v = getFn and getFn() or nil
            input:SetText(tostring(v or ""))
        end

        local function apply()
            local v = tonumber(input:GetText())
            if v and setFn then
                setFn(v)
            end
            refresh()
        end

        input:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            apply()
        end)
        input:SetScript("OnEditFocusLost", function()
            apply()
        end)
        input.Refresh = refresh
        refresh()
        return input
    end

    local cbLogging = CreateCheckbox(
        "Detailed logging",
        "Enables request/response logging (may reduce performance)",
        330,
        yPos + 25,
        function() return DC:GetSetting("loggingEnabled") end,
        function(v) DC:EnableLogging(v) end
    )

    local cbNetLog = CreateCheckbox(
        "NetLog enabled",
        "Stores recent protocol events (timeouts/errors) for debugging",
        330,
        yPos + 5,
        function() return DC:GetSetting("netLogEnabled") end,
        function(v) DC:SetSetting("netLogEnabled", v) end
    )

    local cbChatError = CreateCheckbox(
        "Chat on server error",
        "Prints server error messages to chat",
        330,
        yPos - 15,
        function() return DC:GetSetting("chatOnError") end,
        function(v) DC:SetSetting("chatOnError", v) end
    )

    local cbChatReqTO = CreateCheckbox(
        "Chat on request timeout",
        "Prints request timeouts to chat",
        330,
        yPos - 35,
        function() return DC:GetSetting("chatOnRequestTimeout") end,
        function(v) DC:SetSetting("chatOnRequestTimeout", v) end
    )

    local cbChatChunkTO = CreateCheckbox(
        "Chat on chunk timeout",
        "Prints chunk reassembly timeouts to chat",
        330,
        yPos - 55,
        function() return DC:GetSetting("chatOnChunkTimeout") end,
        function(v) DC:SetSetting("chatOnChunkTimeout", v) end
    )

    local inputReqTO = CreateNumberInput(
        "Req timeout (s):",
        "Seconds before a pending request is considered timed out",
        330,
        yPos - 80,
        40,
        function() return tonumber(DC:GetSetting("requestTimeoutSec")) or 30 end,
        function(v)
            if v < 3 then v = 3 end
            DC:SetSetting("requestTimeoutSec", v)
        end
    )

    local inputChunkTO = CreateNumberInput(
        "Chunk timeout (s):",
        "Seconds before an incomplete chunked message is dropped",
        330,
        yPos - 105,
        40,
        function() return tonumber(DC:GetSetting("chunkTimeoutSec")) or 10 end,
        function(v)
            if v < 2 then v = 2 end
            DC:SetSetting("chunkTimeoutSec", v)
        end
    )

    local inputNetLogMax = CreateNumberInput(
        "NetLog max:",
        "Maximum number of NetLog entries to keep",
        330,
        yPos - 130,
        50,
        function() return tonumber(DC:GetSetting("netLogMaxEntries")) or 200 end,
        function(v)
            if v < 10 then v = 10 end
            DC:SetSetting("netLogMaxEntries", v)
        end
    )
    
    -- Refresh status on show
    panel:SetScript("OnShow", function()
        cbLogging:Refresh()
        cbNetLog:Refresh()
        cbChatError:Refresh()
        cbChatReqTO:Refresh()
        cbChatChunkTO:Refresh()
        inputReqTO:Refresh()
        inputChunkTO:Refresh()
        inputNetLogMax:Refresh()
        UpdateStatus()
    end)
    
    -- Initial status update
    UpdateStatus()
    
    -- Register with interface options
    InterfaceOptions_AddCategory(panel)
    
    return panel
end

local function CreateTestingPanel()
    local panel = CreateFrame("Frame", "DCProtocolTestingPanel", UIParent)
    panel.name = "Testing"
    panel.parent = "DC Protocol"

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00ff00DC Addon Protocol|r - Debug & Testing")

    -- Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(560)
    desc:SetJustifyH("LEFT")
    desc:SetText("Test server communication, send custom JSON messages, and debug protocol handlers. Item Upgrade presets use server bag/slot values; equipped items use bag 255 with zero-based slots.")

    local yPos = -70

    -- Status Section
    local statusHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    statusHeader:SetPoint("TOPLEFT", 16, yPos)
    statusHeader:SetText("|cffffd700Protocol Status|r")
    yPos = yPos - 20

    local statusText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    statusText:SetPoint("TOPLEFT", 16, yPos)
    statusText:SetWidth(300)
    statusText:SetJustifyH("LEFT")
    yPos = yPos - 50

    local function UpdateStatus()
        local connected = DC._connected and "|cff00ff00Connected|r" or "|cffff0000Disconnected|r"
        local version = DC._serverVersion or "Unknown"
        local handlers = DC:CountHandlers()
        local debug = DC._debug and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        statusText:SetText(
            "Status: " .. connected .. "\n" ..
            "Client Version: |cff00ccff" .. DC.VERSION .. "|r\n" ..
            "Server Version: |cff00ccff" .. version .. "|r\n" ..
            "Handlers: |cffffff00" .. handlers .. "|r\n" ..
            "Debug Mode: " .. debug
        )
    end

    -- Quick Actions Row
    local actionHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    actionHeader:SetPoint("TOPLEFT", 16, yPos)
    actionHeader:SetText("|cffffd700Quick Actions|r")
    yPos = yPos - 25

    local function CreateButton(text, tooltip, onClick, xOffset)
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetWidth(120)
        btn:SetHeight(22)
        btn:SetPoint("TOPLEFT", 16 + xOffset, yPos)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return btn
    end

    CreateButton("Reconnect", "Send handshake to server", function()
        DC._connected = false
        DC._handshakeSent = false
        DC:SendHandshake("settings-panel")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Handshake sent")
        UpdateStatus()
    end, 0)

    CreateButton("Toggle Debug", "Enable/disable debug output", function()
        DC._debug = not DC._debug
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Debug: " .. (DC._debug and "ON" or "OFF"))
        UpdateStatus()
    end, 130)

    CreateButton("List Handlers", "Show all registered handlers", function()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Registered handlers:")
        for key, _ in pairs(DC._handlers) do
            DEFAULT_CHAT_FRAME:AddMessage("  - " .. key)
        end
    end, 260)

    CreateButton("Test JSON", "Test JSON encode/decode", function()
        local t = {name = "Test", level = 80, nested = {a = 1, b = 2}}
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Encode: " .. DC:EncodeJSON(t))
        local decoded = DC:DecodeJSON('{"name":"Player","level":80}')
        if decoded then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Decode OK: name=" .. tostring(decoded.name))
        end
    end, 390)

    yPos = yPos - 40

    -- JSON Editor Section
    local editorHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    editorHeader:SetPoint("TOPLEFT", 16, yPos)
    editorHeader:SetText("|cffffd700Send Custom JSON Message|r")
    yPos = yPos - 20

    -- Module dropdown
    local moduleLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    moduleLabel:SetPoint("TOPLEFT", 16, yPos)
    moduleLabel:SetText("Module:")

    local moduleInput = CreateFrame("EditBox", "DCProtocolModuleInput", panel, "InputBoxTemplate")
    moduleInput:SetPoint("LEFT", moduleLabel, "RIGHT", 10, 0)
    moduleInput:SetWidth(60)
    moduleInput:SetHeight(20)
    moduleInput:SetAutoFocus(false)
    moduleInput:SetText("CORE")
    moduleInput:SetMaxLetters(10)

    -- Opcode input
    local opcodeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    opcodeLabel:SetPoint("LEFT", moduleInput, "RIGHT", 20, 0)
    opcodeLabel:SetText("Opcode:")

    local opcodeInput = CreateFrame("EditBox", "DCProtocolOpcodeInput", panel, "InputBoxTemplate")
    opcodeInput:SetPoint("LEFT", opcodeLabel, "RIGHT", 10, 0)
    opcodeInput:SetWidth(50)
    opcodeInput:SetHeight(20)
    opcodeInput:SetAutoFocus(false)
    opcodeInput:SetText("99")
    opcodeInput:SetMaxLetters(5)

    yPos = yPos - 30

    -- JSON text area label
    local jsonLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    jsonLabel:SetPoint("TOPLEFT", 16, yPos)
    jsonLabel:SetText("JSON Data (enter valid JSON object):")
    yPos = yPos - 18

    -- JSON text area with scrollframe
    local scrollFrame = CreateFrame("ScrollFrame", "DCProtocolJSONScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, yPos)
    scrollFrame:SetWidth(540)
    scrollFrame:SetHeight(80)

    local jsonBg = scrollFrame:CreateTexture(nil, "BACKGROUND")
    jsonBg:SetAllPoints()
    jsonBg:SetTexture(0, 0, 0, 0.5)

    local jsonEditBox = CreateFrame("EditBox", "DCProtocolJSONInput", scrollFrame)
    jsonEditBox:SetMultiLine(true)
    jsonEditBox:SetFontObject(ChatFontNormal)
    jsonEditBox:SetWidth(520)
    jsonEditBox:SetAutoFocus(false)
    jsonEditBox:SetText('{"action":"test","timestamp":0}')
    jsonEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scrollFrame:SetScrollChild(jsonEditBox)

    yPos = yPos - 90

    -- Send buttons
    local sendJsonBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    sendJsonBtn:SetWidth(150)
    sendJsonBtn:SetHeight(24)
    sendJsonBtn:SetPoint("TOPLEFT", 16, yPos)
    sendJsonBtn:SetText("Send JSON Request")
    sendJsonBtn:SetScript("OnClick", function()
        local module = moduleInput:GetText() or "CORE"
        local opcode = tonumber(opcodeInput:GetText()) or 99
        local jsonText = jsonEditBox:GetText() or "{}"

        local data = DC:DecodeJSON(jsonText)
        if data then
            DC:Request(module, opcode, data)
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Sent JSON to " .. module .. "|" .. opcode)
            DEFAULT_CHAT_FRAME:AddMessage("|cff888888[DC]|r " .. jsonText)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[DC]|r Invalid JSON! Check syntax.")
        end
    end)

    local sendRawBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    sendRawBtn:SetWidth(150)
    sendRawBtn:SetHeight(24)
    sendRawBtn:SetPoint("LEFT", sendJsonBtn, "RIGHT", 10, 0)
    sendRawBtn:SetText("Send Raw (pipe fmt)")
    sendRawBtn:SetScript("OnClick", function()
        local module = moduleInput:GetText() or "CORE"
        local opcode = tonumber(opcodeInput:GetText()) or 99
        local rawData = jsonEditBox:GetText() or ""

        DC:Send(module, opcode, rawData)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Sent raw to " .. module .. "|" .. opcode .. "|" .. rawData)
    end)

    local validateBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    validateBtn:SetWidth(120)
    validateBtn:SetHeight(24)
    validateBtn:SetPoint("LEFT", sendRawBtn, "RIGHT", 10, 0)
    validateBtn:SetText("Validate JSON")
    validateBtn:SetScript("OnClick", function()
        local jsonText = jsonEditBox:GetText() or ""
        local data = DC:DecodeJSON(jsonText)
        if data then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r JSON is valid!")
            local keys = {}
            for k, v in pairs(data) do
                table.insert(keys, k .. "=" .. tostring(v))
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cff888888[DC]|r Keys: " .. table.concat(keys, ", "))
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[DC]|r Invalid JSON syntax!")
        end
    end)

    yPos = yPos - 40

    -- Preset buttons
    local presetHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    presetHeader:SetPoint("TOPLEFT", 16, yPos)
    presetHeader:SetText("|cffffd700Quick Presets|r")
    yPos = yPos - 25

    local presets = {
        { label = "Handshake", module = "CORE", opcode = 1, json = '{"version":"' .. DC.VERSION .. '"}' },
        { label = "Get AOE Settings", module = "AOE", opcode = 6, json = '{"action":"get_settings"}' },
        { label = "Get Hotspot List", module = "SPOT", opcode = 1, json = '{"action":"list"}' },
        { label = "Get Season Info", module = "SEAS", opcode = 1, json = '{}' },
        { label = "Get M+ Key", module = "MPLUS", opcode = 1, json = '{}' },
        { label = "UPG Currency", module = "UPG", opcode = 4, json = '{}' },
        { label = "UPG List", module = "UPG", opcode = 3, json = '{}' },
        { label = "UPG ItemInfo", module = "UPG", opcode = 1, json = '{"bag":255,"slot":15}' },
        { label = "UPG Upgrade", module = "UPG", opcode = 2, json = '{"bag":255,"slot":15,"targetLevel":1}' },
    }

    local xOffset = 0
    for _, preset in ipairs(presets) do
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetWidth(100)
        btn:SetHeight(20)
        btn:SetPoint("TOPLEFT", 16 + xOffset, yPos)
        btn:SetText(preset.label)
        btn:SetScript("OnClick", function()
            moduleInput:SetText(preset.module)
            opcodeInput:SetText(tostring(preset.opcode))
            jsonEditBox:SetText(preset.json)
        end)
        xOffset = xOffset + 105
        if xOffset >= 525 then
            xOffset = 0
            yPos = yPos - 25
        end
    end

    yPos = yPos - 40

    -- Message Log Section
    local logHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    logHeader:SetPoint("TOPLEFT", 16, yPos)
    logHeader:SetText("|cffffd700Recent Messages|r (check chat for full log)")
    yPos = yPos - 18

    local logInfo = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    logInfo:SetPoint("TOPLEFT", 16, yPos)
    logInfo:SetWidth(560)
    logInfo:SetJustifyH("LEFT")
    logInfo:SetText("Enable debug mode (/dc debug) to see all incoming/outgoing messages in chat.\n" ..
        "Use /dc handlers to list all registered message handlers.\n" ..
        "Use /dc status for quick protocol status check.")

    panel:SetScript("OnShow", function()
        UpdateStatus()
    end)
    UpdateStatus()

    InterfaceOptions_AddCategory(panel)
    return panel
end

-- ============================================================================
-- DIAGNOSTICS PANEL - Protocol Health & Testing Suite
-- ============================================================================

local function CreateDiagnosticsPanel()
    local panel = CreateFrame("Frame", "DCProtocolDiagnosticsPanel", UIParent)
    panel.name = "Diagnostics"
    panel.parent = "DC Protocol"

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00ff00DC Addon Protocol|r - Diagnostics & Health")

    -- Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(560)
    desc:SetJustifyH("LEFT")
    desc:SetText("Run protocol tests, check connection health, and diagnose communication issues.")

    local yPos = -70

    -- Test Results Area
    local resultsFrame = CreateFrame("Frame", nil, panel)
    resultsFrame:SetWidth(560)
    resultsFrame:SetHeight(200)
    resultsFrame:SetPoint("TOPLEFT", 16, yPos)
    
    local resultsBg = resultsFrame:CreateTexture(nil, "BACKGROUND")
    resultsBg:SetAllPoints()
    resultsBg:SetTexture(0, 0, 0, 0.8)
    
    local resultsTitle = resultsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resultsTitle:SetPoint("TOP", 0, -5)
    resultsTitle:SetText("|cffffd700Test Results|r")
    
    local resultsText = resultsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    resultsText:SetPoint("TOPLEFT", 10, -25)
    resultsText:SetWidth(540)
    resultsText:SetJustifyH("LEFT")
    resultsText:SetJustifyV("TOP")
    resultsText:SetText("|cff888888No tests run yet. Click a test button below.|r")
    panel.resultsText = resultsText
    
    yPos = yPos - 210

    -- Test Buttons
    local testsHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    testsHeader:SetPoint("TOPLEFT", 16, yPos)
    testsHeader:SetText("|cffffd700Diagnostic Tests|r")
    yPos = yPos - 25

    local testResults = {}
    
    local function RunAllTests()
        testResults = {}
        local startTime = debugprofilestop and debugprofilestop() or 0
        
        -- Test 1: JSON Encode/Decode
        local test1Pass = false
        local test1Msg = ""
        local testData = { name = "Test", level = 255, nested = { a = 1, b = "str", c = true }, arr = {1, 2, 3} }
        local encoded = DC:EncodeJSON(testData)
        if encoded and #encoded > 0 then
            local decoded = DC:DecodeJSON(encoded)
            if decoded and decoded.name == "Test" and decoded.level == 255 and decoded.nested and decoded.nested.a == 1 and decoded.arr and #decoded.arr == 3 then
                test1Pass = true
                test1Msg = "OK - Encoded " .. #encoded .. " bytes"
            else
                test1Msg = "FAIL - Decode mismatch"
            end
        else
            test1Msg = "FAIL - Encode returned empty"
        end
        table.insert(testResults, { name = "JSON Encode/Decode", pass = test1Pass, msg = test1Msg })
        
        -- Test 2: Large JSON (stress test)
        local test2Pass = false
        local test2Msg = ""
        local largeData = { items = {} }
        for i = 1, 100 do
            largeData.items[i] = { id = i, name = "Item" .. i, value = math.random(1, 10000) }
        end
        local largeEncoded = DC:EncodeJSON(largeData)
        if largeEncoded and #largeEncoded > 1000 then
            local largeDecoded = DC:DecodeJSON(largeEncoded)
            if largeDecoded and largeDecoded.items and #largeDecoded.items == 100 then
                test2Pass = true
                test2Msg = "OK - " .. #largeEncoded .. " bytes, 100 items"
            else
                test2Msg = "FAIL - Large decode failed"
            end
        else
            test2Msg = "FAIL - Large encode failed"
        end
        table.insert(testResults, { name = "Large JSON (100 items)", pass = test2Pass, msg = test2Msg })
        
        -- Test 3: Connection Status
        local test3Pass = DC._connected == true
        local test3Msg = test3Pass and ("OK - Server v" .. (DC._serverVersion or "?")) or "FAIL - Not connected"
        table.insert(testResults, { name = "Server Connection", pass = test3Pass, msg = test3Msg })
        
        -- Test 4: Handshake State
        local test4Pass = not DC._handshakePending and DC._reconnectAttempts == 0
        local test4Msg = ""
        if test4Pass then
            test4Msg = "OK - No pending handshakes"
        else
            test4Msg = "WARN - Reconnect attempts: " .. (DC._reconnectAttempts or 0)
        end
        table.insert(testResults, { name = "Handshake State", pass = test4Pass, msg = test4Msg })
        
        -- Test 5: Handler Registration
        local handlerCount = DC:CountHandlers()
        local test5Pass = handlerCount >= 5  -- Should have at least core handlers
        local test5Msg = test5Pass and ("OK - " .. handlerCount .. " handlers registered") or ("WARN - Only " .. handlerCount .. " handlers")
        table.insert(testResults, { name = "Handler Registration", pass = test5Pass, msg = test5Msg })
        
        -- Test 6: Stats System
        local test6Pass = type(DC._stats) == "table" and DC._stats.sessionStart and DC._stats.sessionStart > 0
        local test6Msg = test6Pass and ("OK - Session " .. (time() - DC._stats.sessionStart) .. "s") or "FAIL - Stats not initialized"
        table.insert(testResults, { name = "Statistics System", pass = test6Pass, msg = test6Msg })
        
        -- Test 7: Settings/DB
        local test7Pass = type(DC._settings) == "table"
        local test7Msg = test7Pass and "OK - Settings loaded" or "FAIL - Settings not initialized"
        table.insert(testResults, { name = "SavedVariables", pass = test7Pass, msg = test7Msg })
        
        -- Test 8: Request ID Generator
        local rid1 = DC:NextRequestId()
        local rid2 = DC:NextRequestId()
        local test8Pass = rid1 ~= rid2 and #rid1 > 5
        local test8Msg = test8Pass and ("OK - IDs unique: " .. rid1:sub(1, 20)) or "FAIL - Request ID collision"
        table.insert(testResults, { name = "Request ID Generator", pass = test8Pass, msg = test8Msg })
        
        -- Calculate elapsed time
        local endTime = debugprofilestop and debugprofilestop() or 0
        local elapsedMs = endTime - startTime
        
        -- Format results
        local passCount = 0
        local failCount = 0
        local lines = {}
        for _, result in ipairs(testResults) do
            local icon = result.pass and "|cff00ff00[OK]|r" or "|cffff0000[FAIL]|r"
            local color = result.pass and "|cff00ff00" or "|cffff4444"
            table.insert(lines, icon .. " " .. color .. result.name .. "|r: " .. result.msg)
            if result.pass then passCount = passCount + 1 else failCount = failCount + 1 end
        end
        
        local summary = string.format("\n|cffffd700Summary:|r %d/%d passed", passCount, #testResults)
        if elapsedMs > 0 then
            summary = summary .. string.format(" (%.1fms)", elapsedMs)
        end
        table.insert(lines, summary)
        
        panel.resultsText:SetText(table.concat(lines, "\n"))
        
        -- Log to chat
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC Diagnostics]|r " .. passCount .. "/" .. #testResults .. " tests passed")
    end

    local function CreateTestButton(text, tooltip, onClick, xOffset)
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetWidth(130)
        btn:SetHeight(24)
        btn:SetPoint("TOPLEFT", 16 + xOffset, yPos)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return btn
    end

    CreateTestButton("Run All Tests", "Execute all diagnostic tests", RunAllTests, 0)
    
    CreateTestButton("Test Handshake", "Send handshake and measure response", function()
        local startTime = time()
        DC._handshakePending = true
        DC._lastHandshakeTime = startTime
        DC:SendHandshake("diagnostics-test")
        panel.resultsText:SetText("|cffffff00Testing handshake...|r\n\nWaiting for server response.\nCheck chat for result.")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC Diagnostics]|r Handshake test sent at " .. date("%H:%M:%S"))
    end, 140)
    
    CreateTestButton("Ping Server", "Send test request (opcode 0x63)", function()
        local testData = { action = "ping", timestamp = time(), client = DC.VERSION }
        DC:Request("CORE", 0x63, testData)
        panel.resultsText:SetText("|cffffff00Ping sent...|r\n\nRequest: CORE|0x63 (test opcode)\nPayload: " .. DC:EncodeJSON(testData) .. "\n\nCheck chat for server response.")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC Diagnostics]|r Ping sent to CORE|0x63")
    end, 280)
    
    CreateTestButton("Clear NetLog", "Clear saved network event log", function()
        DC:ClearNetLog()
        panel.resultsText:SetText("|cff00ff00NetLog cleared.|r\n\nNetwork event log has been reset.")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC Diagnostics]|r NetLog cleared")
    end, 420)

    yPos = yPos - 35

    CreateTestButton("Stress Test JSON", "Encode/decode 1000 objects", function()
        local startTime = debugprofilestop and debugprofilestop() or 0
        local errors = 0
        for i = 1, 1000 do
            local data = { id = i, value = math.random(1, 99999), name = "Object" .. i }
            local enc = DC:EncodeJSON(data)
            local dec = DC:DecodeJSON(enc)
            if not dec or dec.id ~= i then
                errors = errors + 1
            end
        end
        local endTime = debugprofilestop and debugprofilestop() or 0
        local elapsed = endTime - startTime
        local result = errors == 0 and "|cff00ff00PASSED|r" or "|cffff0000FAILED (" .. errors .. " errors)|r"
        panel.resultsText:SetText("|cffffd700JSON Stress Test|r\n\n" ..
            "Iterations: 1000\n" ..
            "Errors: " .. errors .. "\n" ..
            "Time: " .. string.format("%.1fms", elapsed) .. "\n" ..
            "Result: " .. result)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC Diagnostics]|r JSON stress test: " .. (errors == 0 and "PASSED" or "FAILED"))
    end, 0)
    
    CreateTestButton("Check Memory", "Show addon memory usage", function()
        UpdateAddOnMemoryUsage()
        local mem = GetAddOnMemoryUsage("DC-AddonProtocol") or 0
        local lines = {
            "|cffffd700Memory Usage|r\n",
            "DC-AddonProtocol: " .. string.format("%.1f KB", mem),
            "",
            "Internal Structures:",
            "  Handlers: " .. DC:CountTable(DC._handlers),
            "  Request Log: " .. DC:GetRequestLogCount(),
            "  Response Log: " .. DC:GetResponseLogCount(),
            "  Pending Requests: " .. DC:CountTable(DC._pendingRequests),
            "  Chunk Buffers: " .. DC:CountTable(DC._chunkBuffers or {}),
            "  Module Stats: " .. DC:CountTable(DC._stats and DC._stats.moduleStats or {}),
        }
        panel.resultsText:SetText(table.concat(lines, "\n"))
    end, 140)
    
    CreateTestButton("Dump NetLog", "Show recent network events", function()
        DC:DumpNetLog(15)
        panel.resultsText:SetText("|cffffd700NetLog dumped to chat|r\n\nCheck your chat window for recent network events (timeouts, errors, reconnects).")
    end, 280)
    
    CreateTestButton("Force Reconnect", "Reset connection and reconnect", function()
        DC._connected = false
        DC._handshakePending = false
        DC._reconnectAttempts = 0
        DC._lastHandshakeTime = 0
        DC:_AttemptReconnect()
        panel.resultsText:SetText("|cffffff00Reconnecting...|r\n\nConnection reset and handshake sent.\nCheck chat for connection status.")
    end, 420)

    yPos = yPos - 50

    -- Connection Health Section
    local healthHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    healthHeader:SetPoint("TOPLEFT", 16, yPos)
    healthHeader:SetText("|cffffd700Connection Health|r")
    yPos = yPos - 20
    
    local healthText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    healthText:SetPoint("TOPLEFT", 16, yPos)
    healthText:SetWidth(560)
    healthText:SetJustifyH("LEFT")
    panel.healthText = healthText
    
    local function UpdateHealth()
        local lines = {}
        local clientCaps = DC:GetClientCapabilities()
        
        -- Connection status
        local connStatus = DC._connected and "|cff00ff00Connected|r" or "|cffff0000Disconnected|r"
        table.insert(lines, "Status: " .. connStatus)
        
        -- Version info
        if DC._serverVersion then
            table.insert(lines, "Server: v" .. DC._serverVersion .. " | Client: v" .. DC.VERSION)
        end
        table.insert(lines, "Client Caps: " .. DC:DescribeCapabilities(clientCaps))
        
        -- Capabilities
        if DC._serverCaps and DC._serverCaps > 0 then
            table.insert(lines,
                "Negotiated Caps: " .. DC:DescribeCapabilities(DC._serverCaps)
                .. " (0x" .. string.format("%X", DC._serverCaps) .. ")")
        end
        
        -- Reconnect state
        if DC._reconnectAttempts > 0 then
            table.insert(lines, "|cffffff00Reconnect Attempts: " .. DC._reconnectAttempts .. "/" .. (DC._maxReconnectAttempts or 5) .. "|r")
        end
        
        -- Session stats (responses can exceed requests due to server-push messages)
        if DC._stats then
            local requests = DC._stats.totalRequests or 0
            local responses = DC._stats.totalResponses or 0
            local timeouts = DC._stats.totalTimeouts or 0
            
            -- Calculate response rate (responses to our requests, capped at 100%)
            local responseRate = 0
            if requests > 0 then
                responseRate = math.min(100, math.floor((responses / requests) * 100))
            end
            local rateColor = responseRate >= 90 and "|cff00ff00" or (responseRate >= 70 and "|cffffff00" or "|cffff0000")
            table.insert(lines, "Msgs Sent/Recv: " .. requests .. "/" .. responses)
            table.insert(lines, "Response Rate: " .. rateColor .. responseRate .. "%|r")
            
            if timeouts > 0 then
                table.insert(lines, "|cffff4444Timeouts: " .. timeouts .. "|r")
            end
        end
        
        healthText:SetText(table.concat(lines, "\n"))
    end
    
    panel:SetScript("OnShow", function()
        UpdateHealth()
        -- Auto-run tests on first show
        if not panel._ranTests then
            panel._ranTests = true
            RunAllTests()
        end
    end)
    
    UpdateHealth()
    InterfaceOptions_AddCategory(panel)
    return panel
end

-- Create settings panel on load
DC.SettingsPanel = CreateSettingsPanel()
DC.TestingPanel = CreateTestingPanel()
DC.DiagnosticsPanel = CreateDiagnosticsPanel()

-- Make InterfaceOptionsFrame movable (3.3.5a doesn't do this by default)
if InterfaceOptionsFrame and not InterfaceOptionsFrame.__dcMovable then
    InterfaceOptionsFrame.__dcMovable = true
    InterfaceOptionsFrame:SetMovable(true)
    InterfaceOptionsFrame:EnableMouse(true)
    InterfaceOptionsFrame:RegisterForDrag("LeftButton")
    InterfaceOptionsFrame:SetScript("OnDragStart", InterfaceOptionsFrame.StartMoving)
    InterfaceOptionsFrame:SetScript("OnDragStop", InterfaceOptionsFrame.StopMovingOrSizing)
end

