-- DC-RestoreXP.lua
-- Simple addon to show an XP bar when the client reports XP (useful for servers with higher max level)

-- SavedSettings
if not DCRestoreXPDB then DCRestoreXPDB = {} end
if DCRestoreXPDB.x == nil then DCRestoreXPDB.x = 0 end
if DCRestoreXPDB.y == nil then DCRestoreXPDB.y = 60 end
if DCRestoreXPDB.anchor == nil then DCRestoreXPDB.anchor = "BOTTOM" end
if DCRestoreXPDB.point == nil then DCRestoreXPDB.point = "BOTTOM" end
if DCRestoreXPDB.locked == nil then DCRestoreXPDB.locked = true end
if DCRestoreXPDB.useBlizzard == nil then DCRestoreXPDB.useBlizzard = true end

-- Try to find Blizzard's XP bar frame (several legacy names exist)
local function FindBlizzardXPBar()
    local names = { "MainMenuExpBar", "MainMenuXPBar", "MainMenuBarExpBar" }
    for _, n in ipairs(names) do
        local f = _G[n]
        if f and type(f.GetStatusBarTexture) == "function" then
            return f
        end
    end
    return nil
end

local blizBar = FindBlizzardXPBar()
local bar = nil
local bg, text

-- Create our own bar styled to match Blizzard when no blizBar is available or user disabled reuse
local function CreateFallbackBar()
    local b = CreateFrame("StatusBar", "DCRestoreXPBar", UIParent)
    b:SetSize(512, 16)
    b:SetPoint(DCRestoreXPDB.point, UIParent, DCRestoreXPDB.anchor, DCRestoreXPDB.x, DCRestoreXPDB.y)
    local tex = "Interface\\TargetingFrame\\UI-StatusBar"
    if blizBar then
        local st = blizBar:GetStatusBarTexture()
        if st and type(st.GetTexture) == "function" then
            local p = st:GetTexture()
            if p then tex = p end
        end
    end
    b:SetStatusBarTexture(tex)
    if b:GetStatusBarTexture() and type(b:GetStatusBarTexture().SetHorizTile) == "function" then
        b:GetStatusBarTexture():SetHorizTile(false)
    end
    b:SetMinMaxValues(0, 1)
    b:SetValue(0)
    b:Hide()

    bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(b)
    bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    bg:SetVertexColor(0,0,0,0.6)

    text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", b, "CENTER")
    return b
end

-- If possible and configured, reuse Blizzard's bar frame; otherwise create fallback
if blizBar and DCRestoreXPDB.useBlizzard then
    bar = blizBar
    -- ensure it's anchored to saved position by creating a small anchor frame the user can move
    -- but we will not reparent the blizBar; instead we mirror its position when using custom placement
    if DCRestoreXPDB.x ~= 0 or DCRestoreXPDB.y ~= 60 then
        bar:ClearAllPoints()
        bar:SetPoint(DCRestoreXPDB.point, UIParent, DCRestoreXPDB.anchor, DCRestoreXPDB.x, DCRestoreXPDB.y)
    end
    -- try to find a text overlay if Blizzard has one; otherwise create our own text anchored to the bar
    text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", bar, "CENTER")
else
    bar = CreateFallbackBar()
end

local function UpdateXP()
    if UnitExists("player") == nil then
        bar:Hide()
        return
    end
    local xp = UnitXP("player") or 0
    local xpMax = UnitXPMax("player") or 0
    local level = UnitLevel("player") or 0
    if xpMax and xpMax > 0 then
        bar:SetMinMaxValues(0, xpMax)
        bar:SetValue(xp)
        local rested = GetXPExhaustion() or 0
        text:SetFormattedText("Level %d  XP: %d / %d  (rested %d)", level, xp, xpMax, rested)
        bar:Show()
            -- If reusing Blizzard's bar there may be a separate 'rested' overlay texture; try to keep it visible
            if blizBar and blizBar.restedOverlay and type(blizBar.restedOverlay.Show) == "function" then
                if GetXPExhaustion() then blizBar.restedOverlay:Show() else blizBar.restedOverlay:Hide() end
            end
    else
        bar:Hide()
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_XP_UPDATE")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("UNIT_LEVEL")
ev:RegisterEvent("UPDATE_EXHAUSTION")
ev:RegisterEvent("PLAYER_UPDATE_RESTING")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "UNIT_LEVEL" and arg1 ~= "player" then return end
    -- Slight delay on login to ensure unit data is available
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        -- C_Timer was introduced after 3.3.5; provide a local fallback for older clients
        if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
            C_Timer.After(0.1, UpdateXP)
        else
            -- simple OnUpdate-based delay
            local t = 0
            local f = CreateFrame("Frame")
            f:SetScript("OnUpdate", function(self, dt)
                t = t + dt
                if t >= 0.1 then
                    self:SetScript("OnUpdate", nil)
                    UpdateXP()
                end
            end)
        end
    else
        UpdateXP()
    end
    elseif event == "CHAT_MSG_ADDON" then
        -- For 3.3.5a the handler receives (prefix, message, channel, sender) as varargs
        local prefix = arg1
        local message = select(1, ...)
        if prefix == "DCRXP" and message then
            -- expected payload: "XP|<xp>|<xpMax>|<level>"
            local parts = {}
            for p in string.gmatch(message, "([^|]+)") do table.insert(parts, p) end
            if parts[1] == "XP" then
                local sxp = tonumber(parts[2]) or 0
                local sxpMax = tonumber(parts[3]) or 0
                local slevel = tonumber(parts[4]) or UnitLevel("player")
                -- Only apply server-provided XP if client reports no xpMax (legacy clients)
                if (UnitXPMax("player") or 0) == 0 then
                    -- apply values directly to our bar (do not change server-side unit data)
                    if sxpMax and sxpMax > 0 then
                        if type(bar.SetMinMaxValues) == "function" then
                            bar:SetMinMaxValues(0, sxpMax)
                        end
                        if type(bar.SetValue) == "function" then
                            bar:SetValue(sxp)
                        end
                        local rested = sxpMax > 0 and GetXPExhaustion() or 0
                        if type(text.SetFormattedText) == "function" then
                            text:SetFormattedText("Level %d  XP: %d / %d  (rested %d)", slevel, sxp, sxpMax, rested)
                        end
                        if type(bar.Show) == "function" then bar:Show() end
                    else
                        if type(bar.Hide) == "function" then bar:Hide() end
                    end
                end
            end
        end
end)

-- Ensure initial state if loaded after login
if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
    C_Timer.After(1.0, UpdateXP)
else
    local t = 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self, dt)
        t = t + dt
        if t >= 1.0 then
            self:SetScript("OnUpdate", nil)
            UpdateXP()
        end
    end)
end

-- Minimal slash commands: allow toggling reuse of Blizzard bar and resetting position for fallback
SLASH_DCRXP1 = "/dcrxp"
SlashCmdList["DCRXP"] = function(msg)
    local cmd = msg:lower()
    if cmd == "reset" or cmd == "r" then
        DCRestoreXPDB.x = 0; DCRestoreXPDB.y = 60; DCRestoreXPDB.point = "BOTTOM"; DCRestoreXPDB.anchor = "BOTTOM"
        if type(bar.ClearAllPoints) == "function" and type(bar.SetPoint) == "function" then
            bar:ClearAllPoints(); bar:SetPoint(DCRestoreXPDB.point, UIParent, DCRestoreXPDB.anchor, DCRestoreXPDB.x, DCRestoreXPDB.y)
        end
        print("DC-RestoreXP: position reset")
    elseif cmd == "usebliz on" then
        DCRestoreXPDB.useBlizzard = true; print("DC-RestoreXP: will attempt to reuse Blizzard XP bar when available on next reload")
    elseif cmd == "usebliz off" then
        DCRestoreXPDB.useBlizzard = false; print("DC-RestoreXP: will use fallback bar instead of Blizzard bar on next reload")
    else
        print("DC-RestoreXP commands: reset|usebliz on|usebliz off")
    end
end
