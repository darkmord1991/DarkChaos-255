--[[
    DC-InfoBar Utils
    Helper functions and 3.3.5a compatibility polyfills
]]

local addonName = "DC-InfoBar"
DCInfoBar = DCInfoBar or {}
local DCInfoBar = DCInfoBar

-- ============================================================================
-- 3.3.5a Compatibility Polyfills
-- ============================================================================
-- C_Timer, SetShown and SetColorTexture now come from
-- DC-AddonProtocol/DCCompat.lua, which this addon hard-depends on
-- (## Dependencies: DC-AddonProtocol) and which therefore always loads first.
-- The implementations there are the ones that used to be inlined here.

-- ============================================================================
-- Utility Functions
-- ============================================================================

function DCInfoBar:Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff32c4ff[DC-InfoBar]|r " .. (msg or ""))
    end
end

function DCInfoBar:PrintToDcDebug(msg)
    local line = "|cff32c4ff[DC-InfoBar]|r " .. (msg or "")
    local qos = rawget(_G, "DCQOS")
    local tabName = "DCDebug"

    local function GetChatFrameByWindowName(windowName)
        if not windowName or windowName == "" then return nil end
        for i = 1, NUM_CHAT_WINDOWS do
            local tab = _G["ChatFrame" .. i .. "Tab"]
            local frame = _G["ChatFrame" .. i]
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

            if type(qos.GetDcDebugChatFrame) == "function" then
                local ok, frame = pcall(qos.GetDcDebugChatFrame, qos)
                if ok then
                    target = frame
                end
            end

            if (not target) and type(qos.EnsureChatWindow) == "function" then
                local ok, frame = pcall(qos.EnsureChatWindow, qos, tabName)
                if ok then
                    target = frame
                end
            end

            if target and target.AddMessage then
                target:AddMessage(line)
                return true
            end
        end
    end

    local fallbackTarget = GetChatFrameByWindowName(tabName)
    if (not fallbackTarget) and type(FCF_OpenNewWindow) == "function" then
        pcall(FCF_OpenNewWindow, tabName)
        fallbackTarget = GetChatFrameByWindowName(tabName)
        -- A new tab gets stock's default chat set (Say, Guild, Party, ...); a debug
        -- tab must not duplicate that chat.
        if fallbackTarget and ChatFrame_RemoveAllMessageGroups and ChatFrame_RemoveAllChannels then
            pcall(ChatFrame_RemoveAllMessageGroups, fallbackTarget)
            pcall(ChatFrame_RemoveAllChannels, fallbackTarget)
        end
    end

    if fallbackTarget and fallbackTarget.AddMessage then
        fallbackTarget:AddMessage(line)
        return true
    end

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(line)
    end

    return false
end

function DCInfoBar:Debug(msg)
    if self.db and self.db.debug and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[DC-InfoBar Debug]|r " .. (msg or ""))
    end
end

function DCInfoBar:FormatNumber(num)
    if not num then return "0" end
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 10000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(num)
    end
end

function DCInfoBar:FormatTime(seconds)
    if not seconds or seconds <= 0 then
        return "00:00"
    end
    local s = math.floor(seconds)
    local hours = math.floor(s / 3600)
    local minutes = math.floor((s % 3600) / 60)
    local secs = s % 60
    
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, secs)
    else
        return string.format("%02d:%02d", minutes, secs)
    end
end

function DCInfoBar:FormatTimeShort(seconds)
    if not seconds or seconds <= 0 then
        return "0s"
    end
    
    local s = math.floor(seconds)
    local days = math.floor(s / 86400)
    local hours = math.floor((s % 86400) / 3600)
    local minutes = math.floor((s % 3600) / 60)
    
    if days > 0 then
        return string.format("%dd %dh", days, hours)
    elseif hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    elseif minutes > 0 then
        return string.format("%dm", minutes)
    else
        return string.format("%ds", s)
    end
end

function DCInfoBar:FormatGold(copper)
    copper = tonumber(copper) or 0
    local sign = copper < 0 and "-" or ""
    copper = math.abs(copper)

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperRem = copper % 100

    if self:GetPluginSetting("DCInfoBar_Gold", "showSilverCopper") then
        return string.format("%s%dg %ds %dc", sign, gold, silver, copperRem)
    end

    if gold >= 1000000 then
        return string.format("%s%.1fM", sign, gold / 1000000)
    elseif gold >= 10000 then
        return string.format("%s%.1fK", sign, gold / 1000)
    end
    return string.format("%s%dg", sign, gold)
end

-- Three-stop gradient: perc 0 -> color1, 0.5 -> color2, 1 -> color3.
function DCInfoBar:ColorGradient(perc, r1, g1, b1, r2, g2, b2, r3, g3, b3)
    if perc >= 1 then
        return r3, g3, b3
    elseif perc <= 0 then
        return r1, g1, b1
    end

    local fromR, fromG, fromB, toR, toG, toB, t
    if perc < 0.5 then
        fromR, fromG, fromB, toR, toG, toB, t = r1, g1, b1, r2, g2, b2, perc * 2
    else
        fromR, fromG, fromB, toR, toG, toB, t = r2, g2, b2, r3, g3, b3, (perc - 0.5) * 2
    end

    return fromR + (toR - fromR) * t,
           fromG + (toG - fromG) * t,
           fromB + (toB - fromB) * t
end

function DCInfoBar:GetColorHex(r, g, b)
    return string.format("%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

-- Color codes
DCInfoBar.Colors = {
    white = "ffffff",
    gray = "888888",
    lightGray = "cccccc",
    cyan = "32c4ff",
    yellow = "ffd100",
    green = "50ff7a",
    red = "ff5050",
    orange = "ff8c00",
    purple = "a335ee",
    blue = "0070dd",
}

function DCInfoBar:WrapColor(text, color)
    if not text then return "" end
    if not color then return text end
    
    local hex = self.Colors[color] or color
    return "|cff" .. hex .. text .. "|r"
end

-- Truncate to maxChars characters without splitting a UTF-8 sequence
-- (zone names on non-English clients contain multi-byte characters).
function DCInfoBar:TruncateText(text, maxChars)
    text = tostring(text or "")
    local count, cut = 0, nil
    for pos in string.gmatch(text, "()[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count == maxChars - 2 then
            cut = pos
        end
        if count > maxChars then
            -- cut is the start of character maxChars-2; keep everything before
            -- the following character and append the ellipsis.
            local nextStart = string.match(text, "^[%z\1-\127\194-\244][\128-\191]*()", cut)
            return string.sub(text, 1, (nextStart or cut) - 1) .. "..."
        end
    end
    return text
end
