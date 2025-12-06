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

-- Polyfill SetColorTexture (added in WoD+)
local TextureMeta = getmetatable(CreateFrame("Frame"):CreateTexture()).__index
if not TextureMeta.SetColorTexture then
    TextureMeta.SetColorTexture = function(self, r, g, b, a)
        self:SetTexture("Interface\\Buttons\\WHITE8x8")
        self:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
    end
end

-- Polyfill C_Timer (added in WoD+)
if not C_Timer then
    C_Timer = {}
    local timerFrame = CreateFrame("Frame")
    local timers = {}
    timerFrame:SetScript("OnUpdate", function(self, elapsed)
        local now = GetTime()
        local i = 1
        while i <= #timers do
            local t = timers[i]
            if now >= t.expires then
                local callback = t.callback
                table.remove(timers, i)
                callback()
            else
                i = i + 1
            end
        end
        if #timers == 0 then
            self:Hide()
        end
    end)
    timerFrame:Hide()
    
    function C_Timer.After(delay, callback)
        table.insert(timers, {
            expires = GetTime() + delay,
            callback = callback
        })
        timerFrame:Show()
    end
end

-- Polyfill SetShown (added in MoP+)
local FrameMeta = getmetatable(CreateFrame("Frame")).__index
if not FrameMeta.SetShown then
    FrameMeta.SetShown = function(self, shown)
        if shown then
            self:Show()
        else
            self:Hide()
        end
    end
end

-- ============================================================================
-- Utility Functions
-- ============================================================================

function DCInfoBar:Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff32c4ff[DC-InfoBar]|r " .. (msg or ""))
    end
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
    if not copper then return "0g" end
    
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperRem = copper % 100
    
    if self.db and self.db.plugins and self.db.plugins["DCInfoBar_Gold"] then
        local goldSettings = self.db.plugins["DCInfoBar_Gold"]
        if goldSettings.showSilverCopper and gold < 10000 then
            return string.format("%dg %ds %dc", gold, silver, copperRem)
        end
    end
    
    -- Abbreviated format
    if gold >= 1000000 then
        return string.format("%.1fM", gold / 1000000)
    elseif gold >= 10000 then
        return string.format("%.1fK", gold / 1000)
    else
        return string.format("%d", gold) .. "g"
    end
end

function DCInfoBar:ColorGradient(perc, r1, g1, b1, r2, g2, b2, r3, g3, b3)
    if perc >= 1 then
        return r3, g3, b3
    elseif perc <= 0 then
        return r1, g1, b1
    end
    
    local segment, relperc
    if perc >= 0.5 then
        segment = 2
        relperc = (perc - 0.5) * 2
        r1, g1, b1 = r2, g2, b2
    else
        segment = 1
        relperc = perc * 2
    end
    
    return r1 + (r3 - r1) * relperc,
           g1 + (g3 - g1) * relperc,
           b1 + (b3 - b1) * relperc
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
