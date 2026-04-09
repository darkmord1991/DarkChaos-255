local HLBG = _G.HLBG or {}; _G.HLBG = HLBG
HLBG.VERSION = '1.5.8-refactor'
HLBG.BUILD_TS = '2025-10-07'
if not HLBG.PrintVersion then
    function HLBG.PrintVersion(prefix)
        prefix = prefix or '|cFF33FF99HLBG|r'
        local line = string.format('%s addon version %s (%s)', prefix, tostring(HLBG.VERSION), tostring(HLBG.BUILD_TS))
        local qos = rawget(_G, 'DCQOS')
        local tabName = 'DCDebug'

        local function GetChatFrameByWindowName(windowName)
            if not windowName or windowName == '' then return nil end
            for i = 1, NUM_CHAT_WINDOWS do
                local tab = _G['ChatFrame' .. i .. 'Tab']
                local frame = _G['ChatFrame' .. i]
                if tab and frame and tab.GetText and tab:GetText() == windowName then
                    return frame
                end
            end
            return nil
        end

        if qos then
            local routeToDebug = true
            if qos.settings and qos.settings.communication and qos.settings.communication.routeDcDebugToTab == false then
                routeToDebug = false
            end

            if qos.settings and qos.settings.communication and qos.settings.communication.dcDebugTabName then
                tabName = qos.settings.communication.dcDebugTabName
            end

            if routeToDebug then
                local target = nil

                if type(qos.GetDcDebugChatFrame) == 'function' then
                    local ok, frame = pcall(qos.GetDcDebugChatFrame, qos)
                    if ok then
                        target = frame
                    end
                end

                if (not target) and type(qos.EnsureChatWindow) == 'function' then
                    local ok, frame = pcall(qos.EnsureChatWindow, qos, tabName)
                    if ok then
                        target = frame
                    end
                end

                if target and target.AddMessage then
                    target:AddMessage(line)
                    return
                end
            end
        end

        local fallbackTarget = GetChatFrameByWindowName(tabName)
        if (not fallbackTarget) and type(FCF_OpenNewWindow) == 'function' then
            pcall(FCF_OpenNewWindow, tabName)
            fallbackTarget = GetChatFrameByWindowName(tabName)
        end

        if fallbackTarget and fallbackTarget.AddMessage then
            fallbackTarget:AddMessage(line)
            return
        end

        print(line)
    end
end
if not HLBG._versionPrinted then
    HLBG._versionPrinted = true
    C_Timer.After(2, function() if HLBG.PrintVersion then HLBG.PrintVersion() end end)
end

