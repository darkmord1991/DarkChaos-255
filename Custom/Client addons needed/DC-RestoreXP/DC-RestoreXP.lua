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
if DCRestoreXPDB.forceApply == nil then DCRestoreXPDB.forceApply = false end
if DCRestoreXPDB.debug == nil then DCRestoreXPDB.debug = false end
-- Control whether debug messages are also posted to the UIErrorsFrame (on-screen announcements)
if DCRestoreXPDB.debugUiErrors == nil then DCRestoreXPDB.debugUiErrors = false end
if DCRestoreXPDB.hideText == nil then DCRestoreXPDB.hideText = false end

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
local fallbackBar = nil
local bg, text

-- Prevent the addon from initializing twice if the file is (somehow) loaded multiple times
if _G.__DCRestoreXP_Initialized then
    return
end
_G.__DCRestoreXP_Initialized = true

-- Strong hide/show helpers: perform a stronger hide that also moves the frame off-screen
-- and sets alpha to 0 so other addons that re-show textures are less likely to visually
-- overlap. These are defensive and use pcall wrappers to be safe across clients.
local function StrongHide(obj)
    if not obj then return end
    pcall(function()
        if type(obj.Hide) == "function" then obj:Hide() end
        if type(obj.SetAlpha) == "function" then obj:SetAlpha(0) end
        if type(obj.ClearAllPoints) == "function" and type(obj.SetPoint) == "function" then
            obj:ClearAllPoints()
            -- move offscreen to avoid draw-layer conflicts
            obj:SetPoint("CENTER", UIParent, "CENTER", -10000, -10000)
        end
        if type(obj.SetParent) == "function" then pcall(obj.SetParent, obj, UIParent) end
    end)
end

local function StrongShow(obj)
    if not obj then return end
    pcall(function()
        if type(obj.SetParent) == "function" then pcall(obj.SetParent, obj, UIParent) end
        if type(obj.SetAlpha) == "function" then obj:SetAlpha(1) end
        if type(obj.Show) == "function" then obj:Show() end
    end)
end

-- Debug helper
local function DBG(msg)
    if msg then DEFAULT_CHAT_FRAME:AddMessage("[DCRXP DBG] " .. tostring(msg)) end
end

local function Debug(msg)
    if not DCRestoreXPDB.debug then return end
    if type(msg) ~= "string" then msg = tostring(msg) end
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("[DC-RestoreXP] " .. msg)
    end
    -- also fallback to print() so messages show even when chat addons hide the default frame
    print("[DC-RestoreXP] " .. msg)
    -- optionally emit a UI error-frame message for prominent visibility during testing
    if DCRestoreXPDB.debugUiErrors and UIErrorsFrame and type(UIErrorsFrame.AddMessage) == "function" then
        pcall(UIErrorsFrame.AddMessage, UIErrorsFrame, "[DC-RestoreXP] " .. msg)
    end
end

-- Compatibility helper: Set a solid color on a texture across client versions.
local function SetSolidColorTexture(tex, r, g, b, a)
    if not tex then return end
    -- Prefer the modern API when available
    if type(tex.SetColorTexture) == "function" then
        pcall(tex.SetColorTexture, tex, r or 0, g or 0, b or 0, a or 1)
        return
    end
    -- Older clients often only expose SetTexture; try numeric args first
    if type(tex.SetTexture) == "function" then
        local ok = pcall(tex.SetTexture, tex, r or 0, g or 0, b or 0, a or 1)
        if ok then
            -- Some SetTexture implementations ignore alpha, so set alpha if possible
            if type(tex.SetAlpha) == "function" and a then pcall(tex.SetAlpha, tex, a) end
            return
        end
        -- Fall back to using a simple background texture and vertex color
        pcall(tex.SetTexture, tex, "Interface\\Tooltips\\UI-Tooltip-Background")
        if type(tex.SetVertexColor) == "function" then pcall(tex.SetVertexColor, tex, r or 0, g or 0, b or 0, a or 1) end
        return
    end
    -- Nothing we can do; silently return
end

-- Color constants for formatted text
local COLOR_RED = "|cFFFF4500"
local COLOR_ORANGE = "|cFFFFA500"
local COLOR_YELLOW = "|cFFFFFF00"
local COLOR_GREEN = "|cFF00FF00"
local COLOR_RESET = "|r"

-- Animation helpers: smooth value transitions for the status bar to mimic Blizzard visuals
local anim = { active = false, bar = nil, start = 0, target = 0, duration = 0.3, elapsed = 0 }
local animFrame = CreateFrame("Frame")
animFrame:Hide()
animFrame:SetScript("OnUpdate", function(self, dt)
    if not anim.active or not anim.bar then self:Hide(); return end
    anim.elapsed = anim.elapsed + dt
    local p = anim.elapsed / anim.duration
    if p >= 1 then p = 1 end
    -- use a sin-based ease-out to match Blizzard's easing (sin(p * 90deg) style)
    local eased = math.sin(p * (math.pi / 2))
    local value = anim.start + (anim.target - anim.start) * eased
    if type(anim.bar.SetValue) == "function" then anim.bar:SetValue(value) end
    -- Update text during animation so percentage changes smoothly
    local ok, minv, maxv = pcall(function()
        if type(anim.bar.GetMinMaxValues) == "function" then
            return anim.bar:GetMinMaxValues()
        end
        return nil, nil
    end)
    if ok and minv and maxv and maxv > 0 then
        local cur = value or 0
        local pct = (cur * 100) / maxv
        local pcttext = string.format("%.1f%%", pct)
        local rested = GetXPExhaustion() or 0
        -- prefer per-bar text if available
        if anim.bar == blizBar and blizBar.__dcrxp_text and type(blizBar.__dcrxp_text.SetFormattedText) == "function" then
            pcall(blizBar.__dcrxp_text.SetFormattedText, blizBar.__dcrxp_text, "Level %d XP: %d / %d %s%s%s (rested %d)", UnitLevel("player") or 0, math.floor(cur), maxv, COLOR_YELLOW, pcttext, COLOR_RESET, rested)
        elseif anim.bar.__dcrxp_text and type(anim.bar.__dcrxp_text.SetFormattedText) == "function" then
            pcall(anim.bar.__dcrxp_text.SetFormattedText, anim.bar.__dcrxp_text, "Level %d XP: %d / %d %s%s%s (rested %d)", UnitLevel("player") or 0, math.floor(cur), maxv, COLOR_YELLOW, pcttext, COLOR_RESET, rested)
        end
    end
    if p >= 1 then
        anim.active = false
        self:Hide()
    end
end)

local function AnimateBarTo(barObj, newValue, dur)
    if not barObj or type(barObj.GetValue) ~= "function" then return end
    anim.bar = barObj
    anim.start = tonumber(barObj:GetValue() or 0) or 0
    anim.target = tonumber(newValue or anim.start) or anim.start
    if DCRestoreXPDB.debug then
        Debug(string.format("AnimateBarTo: name=%s start=%s target=%s dur=%s", tostring(barObj.GetName and barObj:GetName() or "anon"), tostring(anim.start), tostring(anim.target), tostring(dur)))
    end
    anim.duration = dur or 0.3
    anim.elapsed = 0
    anim.active = true
    animFrame:Show()
end

-- Re-assert hide/show state a short time after we've set it. Some other addons
-- may modify visibility during initialization; this helper schedules one or
-- two deferred checks to hide the non-target bar after a tiny delay.
local function ReassertVisibility(target)
    local function doAssert()
        if target == blizBar then
            StrongHide(fallbackBar)
            StrongShow(blizBar)
        elseif target == fallbackBar then
            StrongHide(blizBar)
            StrongShow(fallbackBar)
        else
            StrongHide(blizBar)
            StrongHide(fallbackBar)
        end
    end
    -- Prefer C_Timer when available
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        -- run twice: shortly after, and again after a tiny delay to catch late inits
        C_Timer.After(0.05, doAssert)
        C_Timer.After(0.25, doAssert)
    else
        -- Fallback: lightweight OnUpdate timer that self-destructs after two runs
        local runs = 0
        local f = CreateFrame("Frame")
        f._acc = 0
        f:SetScript("OnUpdate", function(self, dt)
            self._acc = (self._acc or 0) + dt
            if self._acc >= 0.05 then
                self._acc = 0
                runs = runs + 1
                doAssert()
                if runs >= 2 then
                    self:SetScript("OnUpdate", nil)
                    -- explicit nil to allow GC
                    f = nil
                end
            end
        end)
    end
end

-- Stronger, short-lived enforcement: periodically re-hide the non-target bar
-- for a small number of iterations to catch aggressive re-shows by other addons.
local function EnforceSingleBar(target, iterations, interval)
    iterations = tonumber(iterations) or 20
    interval = tonumber(interval) or 0.05
    local count = 0
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        local function step()
            count = count + 1
            if target == blizBar then
                StrongHide(fallbackBar)
            elseif target == fallbackBar then
                StrongHide(blizBar)
            else
                StrongHide(blizBar)
                StrongHide(fallbackBar)
            end
            if count < iterations then
                C_Timer.After(interval, step)
            end
        end
        C_Timer.After(0, step)
    else
        -- OnUpdate fallback
        local f = CreateFrame("Frame")
        f._acc = 0
        f:SetScript("OnUpdate", function(self, dt)
            self._acc = (self._acc or 0) + dt
            if self._acc >= interval then
                self._acc = 0
                count = count + 1
                if target == blizBar then
                    StrongHide(fallbackBar)
                elseif target == fallbackBar then
                    StrongHide(blizBar)
                else
                    StrongHide(blizBar)
                    StrongHide(fallbackBar)
                end
                if count >= iterations then
                    self:SetScript("OnUpdate", nil)
                end
            end
        end)
    end
end

-- Temporary instrumentation: hook Show/Hide on both bars to log external callers.
local showHideHooks = { active = false, originals = {} }
local function UnhookShowHide()
    if not showHideHooks.active then return end
    for obj, funcs in pairs(showHideHooks.originals) do
        if funcs.Show and type(obj.SetScript) ~= "function" then end
        if funcs.Show and type(funcs.Show) == "function" and type(obj.Show) == "function" then
            pcall(function() obj.Show = funcs.Show end)
        end
        if funcs.Hide and type(funcs.Hide) == "function" and type(obj.Hide) == "function" then
            pcall(function() obj.Hide = funcs.Hide end)
        end
    end
    showHideHooks.originals = {}
    showHideHooks.active = false
    Debug("Show/Hide instrumentation disabled")
end

local function HookShowHideForObject(obj)
    if not obj or type(obj) ~= "table" then return end
    if showHideHooks.originals[obj] then return end
    local origShow, origHide = obj.Show, obj.Hide
    showHideHooks.originals[obj] = { Show = origShow, Hide = origHide }
    if type(origShow) == "function" then
        obj.Show = function(self, ...)
            Debug(string.format("[ShowHook] %s: Show called", tostring(self.GetName and self:GetName() or tostring(self))))
            if type(debugstack) == "function" then pcall(function() Debug(debugstack()) end) end
            return origShow(self, ...)
        end
    end
    if type(origHide) == "function" then
        obj.Hide = function(self, ...)
            Debug(string.format("[ShowHook] %s: Hide called", tostring(self.GetName and self:GetName() or tostring(self))))
            if type(debugstack) == "function" then pcall(function() Debug(debugstack()) end) end
            return origHide(self, ...)
        end
    end
end

local function StartShowHideLogging(duration)
    duration = tonumber(duration) or 10
    if showHideHooks.active then
        Debug("Show/Hide instrumentation already active")
        return
    end
    showHideHooks.active = true
    HookShowHideForObject(blizBar)
    HookShowHideForObject(fallbackBar)
    -- also hook MainMenuBar's named frames if present
    if _G["MainMenuExpBar"] then HookShowHideForObject(_G["MainMenuExpBar"]) end
    Debug(string.format("Show/Hide instrumentation enabled for %ds", duration))
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(duration, UnhookShowHide)
    else
        -- OnUpdate fallback
        local t = 0
        local f = CreateFrame("Frame")
        f:SetScript("OnUpdate", function(self, dt)
            t = t + dt
            if t >= duration then
                self:SetScript("OnUpdate", nil)
                UnhookShowHide()
            end
        end)
    end
end

local function SetBarMinMaxAndAnimate(barObj, minv, maxv, value)
    if not barObj then return end
    if type(barObj.SetMinMaxValues) == "function" then barObj:SetMinMaxValues(minv or 0, maxv or 1) end
    if DCRestoreXPDB.debug then
        local ok, a, b = pcall(function()
            if type(barObj.GetMinMaxValues) == "function" then return barObj:GetMinMaxValues() end
            return nil, nil
        end)
        local cur = nil
        pcall(function() cur = (type(barObj.GetValue) == "function" and barObj:GetValue()) end)
        Debug(string.format("SetBarMinMaxAndAnimate: bar=%s minv=%s maxv=%s value=%s curValue=%s", tostring(barObj.GetName and barObj:GetName() or "anon"), tostring(minv), tostring(maxv), tostring(value), tostring(cur)))
    end
    -- update text immediately
    local rested = (GetXPExhaustion() or 0)
        if barObj == blizBar then
            -- ensure a compact centered text + background for readability on dense HUDs
            if not DCRestoreXPDB.hideText then
                if not blizBar.__dcrxp_text then
                    blizBar.__dcrxp_text = blizBar:CreateFontString(nil, "OVERLAY")
                    local fName, fSize, fFlags = GameFontNormalSmall:GetFont()
                    blizBar.__dcrxp_text:SetFont(fName, math.max((fSize or 10) + 1, 10), fFlags)
                    if not blizBar.__dcrxp_textBg then
                        blizBar.__dcrxp_textBg = blizBar:CreateTexture(nil, "OVERLAY")
                        SetSolidColorTexture(blizBar.__dcrxp_textBg, 0, 0, 0, 0.65)
                        blizBar.__dcrxp_textBg:SetPoint("CENTER", blizBar, "CENTER", 0, 0)
                        blizBar.__dcrxp_textBg:SetSize(320, blizBar:GetHeight() or 14)
                    end
                    blizBar.__dcrxp_text:SetPoint("CENTER", blizBar.__dcrxp_textBg, "CENTER", 0, 0)
                end
            else
                if blizBar.__dcrxp_text then pcall(blizBar.__dcrxp_text.Hide, blizBar.__dcrxp_text) end
                if blizBar.__dcrxp_textBg then pcall(blizBar.__dcrxp_textBg.Hide, blizBar.__dcrxp_textBg) end
            end
            -- color main bar blue when rested, otherwise violet
            if rested and rested > 0 then
                if type(barObj.SetStatusBarColor) == "function" then barObj:SetStatusBarColor(0.0, 0.5, 1.0) end
            else
                if type(barObj.SetStatusBarColor) == "function" then barObj:SetStatusBarColor(0.64, 0.27, 0.86) end
            end
            if type(blizBar.__dcrxp_text.SetFormattedText) == "function" then
                -- Blizzard bar text is updated elsewhere; nothing to change here. Keep the block balanced.
            end
    else
        -- ensure a small background box for the fallback bar text
        if not DCRestoreXPDB.hideText then
            if not barObj.__dcrxp_textBg then
                local tb = barObj:CreateTexture(nil, "OVERLAY")
                SetSolidColorTexture(tb, 0, 0, 0, 0.65)
                tb:SetPoint("CENTER", barObj, "CENTER", 0, 0)
                tb:SetSize(math.min((barObj:GetWidth() or 512) * 0.75, 600), barObj:GetHeight() or 13)
                barObj.__dcrxp_textBg = tb
            end
            if not barObj.__dcrxp_text and barObj.CreateFontString then
                barObj.__dcrxp_text = barObj:CreateFontString(nil, "OVERLAY")
                local fName, fSize, fFlags = GameFontNormalSmall:GetFont()
                barObj.__dcrxp_text:SetFont(fName, math.max((fSize or 10) + 1, 10), fFlags)
                barObj.__dcrxp_text:SetPoint("CENTER", barObj.__dcrxp_textBg, "CENTER", 0, 0)
                if type(barObj.__dcrxp_text.SetShadowOffset) == "function" then barObj.__dcrxp_text:SetShadowOffset(1, -1) end
                if type(barObj.__dcrxp_text.SetShadowColor) == "function" then barObj.__dcrxp_text:SetShadowColor(0,0,0,0.8) end
                if type(barObj.__dcrxp_text.SetJustifyH) == "function" then barObj.__dcrxp_text:SetJustifyH("CENTER") end
            end
        else
            if barObj.__dcrxp_text then pcall(barObj.__dcrxp_text.Hide, barObj.__dcrxp_text) end
            if barObj.__dcrxp_textBg then pcall(barObj.__dcrxp_textBg.Hide, barObj.__dcrxp_textBg) end
        end
        -- color main bar blue when rested, otherwise violet
        if rested and rested > 0 then
            if type(barObj.SetStatusBarColor) == "function" then barObj:SetStatusBarColor(0.0, 0.5, 1.0) end
        else
            if type(barObj.SetStatusBarColor) == "function" then barObj:SetStatusBarColor(0.64, 0.27, 0.86) end
        end
    if not DCRestoreXPDB.hideText and barObj.__dcrxp_text and type(barObj.__dcrxp_text.SetFormattedText) == "function" then
            local pctf = 0
            if maxv and maxv > 0 then pctf = ((value or 0) * 100) / maxv end
            local color = COLOR_RED
            if pctf >= 100 then color = COLOR_GREEN elseif pctf >= 50 then color = COLOR_YELLOW elseif pctf >= 25 then color = COLOR_ORANGE end
            local pcttext = string.format("%.1f%%", pctf)
            -- center the fallback text on the bar and center-justify it
            barObj.__dcrxp_text:ClearAllPoints()
            -- anchor to the bar object itself (not the global 'bar' variable)
            barObj.__dcrxp_text:SetPoint("CENTER", barObj, "CENTER", 0, 0)
            if type(barObj.__dcrxp_text.SetJustifyH) == "function" then barObj.__dcrxp_text:SetJustifyH("CENTER") end
            barObj.__dcrxp_text:SetFormattedText("Level %d  XP: %d / %d  %s%s%s  (rested %d)", UnitLevel("player") or 0, value or 0, maxv or 0, color, pcttext, COLOR_RESET, rested)
        end
    end
    -- animate value change (use Blizzard-like timing)
    AnimateBarTo(barObj, value or 0, 0.3)
    if type(barObj.Show) == "function" then barObj:Show() end

    -- Exhaustion/rested visuals for our fallback bar (mimic MainMenuBar behavior)
    if barObj.exhaustionTick and maxv and maxv > 0 then
        local exhaustionThreshold = GetXPExhaustion()
        local tick = barObj.exhaustionTick
        local fill = barObj.exhaustionFill
        if not exhaustionThreshold then
            tick:Hide()
            if fill then fill:Hide() end
        else
            local exhaustionTickSet = math.max((((value or 0) + exhaustionThreshold) / maxv) * (barObj:GetWidth() or 1), 0)
            if exhaustionTickSet > (barObj:GetWidth() or 0) or (_G["MainMenuBarMaxLevelBar"] and _G["MainMenuBarMaxLevelBar"]:IsShown()) then
                tick:Hide()
                if fill then fill:Hide() end
            else
                tick:Show()
                tick:ClearAllPoints()
                tick:SetPoint("CENTER", barObj, "LEFT", exhaustionTickSet, 0)
                if type(tick.SetFrameLevel) == "function" and type(barObj.GetFrameLevel) == "function" then
                    pcall(tick.SetFrameLevel, tick, (barObj:GetFrameLevel() or 0) + 3)
                end
                if fill then
                    fill:Show()
                    fill:ClearAllPoints()
                    fill:SetPoint("TOPLEFT", barObj, "TOPLEFT")
                    fill:SetPoint("BOTTOMLEFT", barObj, "BOTTOMLEFT")
                    if exhaustionTickSet and exhaustionTickSet > 0 then
                        fill:SetWidth(exhaustionTickSet)
                    end
                    local restStateID = GetRestState()
                    if restStateID == 1 then
                        SetSolidColorTexture(fill, 0.0, 0.39, 0.88, 0.15)
                    elseif restStateID == 2 then
                        SetSolidColorTexture(fill, 0.58, 0.0, 0.55, 0.15)
                    else
                        SetSolidColorTexture(fill, 1.0, 1.0, 1.0, 0.15)
                    end
                end
            end
        end
    end
    -- adjust text color for contrast when bar is filled
    local pct = 0
    if maxv and maxv > 0 then pct = ((value or 0) * 100) / maxv end
    local fgColor = {1, 1, 1}
    if pct >= 50 then
        -- when bar is more filled, use dark text for contrast
        fgColor = {0, 0, 0}
    end
    -- apply color to whichever text exists on this bar
    if barObj == blizBar and blizBar.__dcrxp_text and type(blizBar.__dcrxp_text.SetTextColor) == "function" then
        pcall(blizBar.__dcrxp_text.SetTextColor, blizBar.__dcrxp_text, fgColor[1], fgColor[2], fgColor[3])
    elseif not DCRestoreXPDB.hideText and text and type(text.SetTextColor) == "function" and barObj == fallbackBar then
        pcall(text.SetTextColor, text, fgColor[1], fgColor[2], fgColor[3])
    end
end

-- Send a small client->server handshake request so the server can reply with
-- current XP values when the client is ready. This helper is used on login
-- and also after level changes to avoid flicker from client-side updates.
local function SendDCRXPRequest()
    if type(SendAddonMessage) ~= "function" then
        Debug("SendAddonMessage not available; cannot request server XP snapshot")
        return
    end
    local target = UnitName("player") or ""
    local ok, err = pcall(SendAddonMessage, "DCRXP_REQ", "REQ", "WHISPER", target)
    if ok then
        Debug("Sent DCRXP_REQ handshake to server (whisper to self)")
    else
        Debug("Failed to SendAddonMessage DCRXP_REQ: " .. tostring(err))
    end
end

-- Create our own bar styled to match Blizzard when no blizBar is available or user disabled reuse
local function CreateFallbackBar()
    -- Create a fallback XP status bar that mirrors MainMenuBar's layout and textures
    local b = CreateFrame("StatusBar", "DCRestoreXPBar", UIParent)
    -- Prefer a compact width so the bar is readable on most HUD layouts. If Blizzard's bar exists
    -- mirror its height, otherwise use a sensible default width/height that won't be clipped.
    -- slightly shorter height to avoid clipping on compact HUDs
    local defaultW, defaultH = 512, 13
    if blizBar then
        local w = blizBar:GetWidth() or defaultW
        -- cap the reused bar height so our fallback/overlay doesn't extend off-screen
        local h = math.min((blizBar:GetHeight() or defaultH), defaultH)
        b:SetSize(math.min(w, 1024), h)
        b:SetPoint("CENTER", blizBar, "CENTER")
    else
        b:SetSize(defaultW, defaultH)
        b:SetPoint(DCRestoreXPDB.point, UIParent, DCRestoreXPDB.anchor, DCRestoreXPDB.x, DCRestoreXPDB.y)
    end
    -- Make sure the bar is on top of most UI elements and clamped so it remains visible
    b:SetFrameStrata("HIGH")
    b:SetFrameLevel(200)
    b:SetClampedToScreen(true)

    -- Base statusbar texture (matches MainMenuBar's BarTexture)
    local barTex = "Interface\\TargetingFrame\\UI-StatusBar"
    b:SetStatusBarTexture(barTex)
    -- Use Blizzard-like XP color (purple) for the fallback bar so it visually matches the client
    -- RGB chosen to be close to the default MainMenuBar XP tint
    if type(b.SetStatusBarColor) == "function" then
        b:SetStatusBarColor(0.64, 0.27, 0.86)
    end
    if b:GetStatusBarTexture() and type(b:GetStatusBarTexture().SetHorizTile) == "function" then
        b:GetStatusBarTexture():SetHorizTile(false)
    end
    b:SetMinMaxValues(0, 1)
    b:SetValue(0)
    b:Hide()

    -- Background
    bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(b)
    bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    bg:SetVertexColor(0,0,0,0.6)

    -- Center text
    text = b:CreateFontString(nil, "OVERLAY")
    -- Use a slightly smaller font to avoid clipping; keep a sensible minimum
    local fontName, fontSize, fontFlags = GameFontNormalSmall:GetFont()
    local chosenSize = math.max((fontSize or 10) - 1, 8)
    text:SetFont(fontName, chosenSize, fontFlags)
    text:SetPoint("CENTER", b, "CENTER")

    -- Add the four decorative bar slices from UI-MainMenuBar-Dwarf to mimic Blizzard art
    local sliceFile = "Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf"
    local sliceInfo = {
        { offset = -384, top = 0.79296875, bottom = 0.83203125 },
        { offset = -128, top = 0.54296875, bottom = 0.58203125 },
        { offset = 128,  top = 0.29296875, bottom = 0.33203125 },
        { offset = 384,  top = 0.04296875, bottom = 0.08203125 },
    }
    for i, si in ipairs(sliceInfo) do
        local tex = b:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(sliceFile)
        tex:SetSize(256, 10)
        tex:SetPoint("BOTTOM", b, "BOTTOM", si.offset, 3)
        tex:SetTexCoord(0, 1.0, si.top, si.bottom)
    end

    -- Rested/exhaustion visuals (overlay uses the Blizzard rested-blue by default)
    local rested = b:CreateTexture(nil, "OVERLAY")
    rested:SetAllPoints(b)
    rested:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    rested:Hide()
    SetSolidColorTexture(rested, 0.0, 0.5, 1.0, 0.25)
    if type(rested.SetDrawLayer) == "function" then pcall(rested.SetDrawLayer, rested, "OVERLAY", 2) end
    b.restedOverlay = rested

    -- Exhaustion tick (small button with textures) positioned relative to the bar
    local tick = CreateFrame("Button", "DCRestore_ExhaustionTick", b)
    tick:SetSize(24, 24)
    tick:SetPoint("CENTER", b, "LEFT", 0, 0)
    local nt = tick:CreateTexture(nil, "ARTWORK")
    nt:SetTexture("Interface\\MainMenuBar\\UI-ExhaustionTickNormal")
    nt:SetAllPoints(tick)
    local ht = tick:CreateTexture(nil, "HIGHLIGHT")
    ht:SetTexture("Interface\\MainMenuBar\\UI-ExhaustionTickHighlight")
    ht:SetAllPoints(tick)
    tick:Hide()
    b.exhaustionTick = tick

    -- Expose Blizzard global names if they don't already exist so other FrameXML can reference them
    if not _G["ExhaustionTick"] then _G["ExhaustionTick"] = tick end
    if not _G["ExhaustionTickNormal"] then _G["ExhaustionTickNormal"] = nt end
    if not _G["ExhaustionTickHighlight"] then _G["ExhaustionTickHighlight"] = ht end

    -- Exhaustion fill (the area that shows rested XP)
    local exhaustionFill = b:CreateTexture(nil, "ARTWORK")
    exhaustionFill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    exhaustionFill:Hide()
    if type(exhaustionFill.SetDrawLayer) == "function" then pcall(exhaustionFill.SetDrawLayer, exhaustionFill, "ARTWORK", 1) end
    b.exhaustionFill = exhaustionFill
    -- Expose the Blizzard global name used in FrameXML for the exhaustion/rested fill
    if not _G["ExhaustionLevelFillBar"] then _G["ExhaustionLevelFillBar"] = exhaustionFill end

    return b
end

-- Defer creating the fallback bar until it's actually needed. Creating it
-- eagerly causes overlay artifacts when the Blizzard bar is present and
-- other addons interact with the HUD. We'll create it lazily below.
fallbackBar = nil
bar = nil

-- If possible and configured, we may still let Blizzard render the native XP bar for client-driven
-- XP updates; however we will not create or attach text/widgets to Blizzard's frames so we don't
-- modify Blizzard UI. The fallbackBar contains our text and will be used for server-sent values.
    if blizBar and DCRestoreXPDB.useBlizzard then
        bar = blizBar
        Debug("Found Blizzard XP bar; reusing it")
        -- ensure Blizzard bar is anchored to saved position only (we will not attach text to it)
        if DCRestoreXPDB.x ~= 0 or DCRestoreXPDB.y ~= 60 then
            bar:ClearAllPoints()
            bar:SetPoint(DCRestoreXPDB.point, UIParent, DCRestoreXPDB.anchor, DCRestoreXPDB.x, DCRestoreXPDB.y)
        end
    else
        -- don't create or use fallback unless forced or high-level; keep bar=nil so UpdateXP
        -- will prefer Blizzard whenever possible
        bar = nil
    end

-- If configured to reuse Blizzard's bar we still need a fallback for servers that push XP
-- when the client reports no XP max (for example at or above the client's native max level).
-- We'll create the fallback lazily when needed and prefer it for server-provided values.

-- Helper: apply server-provided XP values to our fallback bar. Extracted so the test button
-- and CHAT_MSG_ADDON handler can reuse the same logic.
local function ApplyServerXP(sxp, sxpMax, slevel)
    local clientMax = (UnitXPMax("player") or 0)
    Debug(string.format("ApplyServerXP called: sxp=%s sxpMax=%s slevel=%s clientMax=%s", tostring(sxp), tostring(sxpMax), tostring(slevel), tostring(clientMax)))
    -- Only override client values when client reports no xpMax, or when server-reported max is larger.
    -- However, if the client currently has zero XP (UnitXP == 0) we should still apply server values
    -- because some clients report a valid XPMax but reset current XP to 0 at login.
    local clientXP = (UnitXP("player") or 0)
    -- Only apply server-provided values to the fallback bar when explicitly requested
    -- by server/high-level mode or when the admin has enabled forceApply.
    if not DCRestoreXPDB.forceApply and not (slevel and type(slevel) == "number" and slevel >= 80) then
        Debug(string.format("Server reports slevel=%s and forceApply is false: not showing addon bar for <80 clients", tostring(slevel)))
        StrongHide(fallbackBar)
        if blizBar then bar = blizBar end
        return
    end
    if DCRestoreXPDB.forceApply then
        Debug("forceApply is enabled; applying server values regardless of client XPMax")
    end
    if not fallbackBar then
        fallbackBar = CreateFallbackBar()
    end
    -- choose target: prefer Blizzard bar if configured, otherwise fallback
    local target = nil
    if DCRestoreXPDB.useBlizzard and blizBar and type(blizBar.SetMinMaxValues) == "function" then
        target = blizBar
        Debug("Applying to Blizzard bar (useBlizzard=true)")
    else
        target = fallbackBar
        Debug("Applying to fallback bar")
    end
    -- Ensure global 'bar' points at the selected target and hide the other bar so
    -- only a single XP bar is visible at any time. This prevents duplicate bars
    -- being shown when switching modes or when both bar objects exist.
    bar = target
    if target == blizBar then
        StrongHide(fallbackBar)
        StrongShow(blizBar)
    else
        StrongHide(blizBar)
        StrongShow(fallbackBar)
    end
    -- Schedule deferred re-assert to handle other addons/FrameXML that may toggle
    -- visibility shortly after we set it (helps avoid race conditions during init)
    pcall(ReassertVisibility, target)
    -- Also run a short aggressive enforcement to catch noisy re-shows
    pcall(EnforceSingleBar, target, 30, 0.03)
    -- If the server reports a player level above 79 (i.e. level 80+ on server-side),
    -- prefer the fallback bar so that high-level servers always display using our bar.
    if slevel and type(slevel) == "number" and slevel > 79 then
        if not fallbackBar then fallbackBar = CreateFallbackBar() end
        target = fallbackBar
        Debug(string.format("slevel=%d >79: forcing application to fallback bar for high-level player", slevel))
    end
    if sxpMax and sxpMax > 0 then
    SetBarMinMaxAndAnimate(target, 0, sxpMax, sxp)
    -- Make sure global 'bar' is consistent with the visual target
    bar = target
        -- Ensure the target bar is visible and anchored correctly
        if type(target.Show) == "function" then target:Show() end
        if type(target.SetAlpha) == "function" then target:SetAlpha(1) end
        if type(target.SetFrameStrata) == "function" then target:SetFrameStrata("HIGH") end
        if type(target.SetFrameLevel) == "function" then pcall(target.SetFrameLevel, target, 200) end
        -- Log visibility and anchor info for debugging
        local vis = (type(target.IsShown) == "function" and target:IsShown()) or false
        local px, py, panchor = nil, nil, nil
        local p = { target:GetPoint() }
        if #p >= 4 then
            panchor = tostring(p[1])
            px = tostring(p[3])
            py = tostring(p[4])
        end
        Debug(string.format("FallbackVisible=%s name=%s point=%s x=%s y=%s width=%s height=%s", tostring(vis), tostring(target:GetName() or "anon"), tostring(panchor or "nil"), tostring(px or "nil"), tostring(py or "nil"), tostring(target:GetWidth() or "nil"), tostring(target:GetHeight() or "nil")))
        -- record last server-driven apply so UpdateXP (client-driven) won't immediately override
        if ev then
            local now = GetTime and GetTime() or (time and time()) or 0
            ev.__lastServerApplyTime = now
            ev.__serverForced = true
        end
    else
        StrongHide(target)
        -- Also ensure the other bar is hidden when we hide this target
        if target == blizBar then StrongHide(fallbackBar) end
        if target == fallbackBar then StrongHide(blizBar) end
    end
end

-- Small test button (hidden by default). Toggle with "/dcrxp test" - useful for client-only checks.
local testBtn = CreateFrame("Button", "DCRXPTestButton", UIParent, "UIPanelButtonTemplate")
testBtn:SetSize(90, 22)
testBtn:SetPoint("TOP", UIParent, "TOP", -100, -50)
testBtn:SetText("DCRXP Test")
testBtn:SetScript("OnClick", function()
    local lvl = UnitLevel("player") or 80
    local max = 1000000
    local xp = math.floor(max * 0.3)
    Debug(string.format("Test button pressed: applying sxp=%d sxpMax=%d level=%d", xp, max, lvl))
    ApplyServerXP(xp, max, lvl)
end)
testBtn:Hide()

local function UpdateXP()
    Debug("UpdateXP called")
    if not UnitExists("player") then
        Debug("No player unit; hiding bar")
        StrongHide(bar)
        return
    end
    local xp = UnitXP("player") or 0
    local xpMax = UnitXPMax("player") or 0
    local level = UnitLevel("player") or 0
    Debug(string.format("Player XP=%d XPMax=%d Level=%d", xp, xpMax, level))
    -- By default prefer Blizzard's native bar for normal clients (level < 80)
    if level and level < 80 and not DCRestoreXPDB.forceApply then
        if blizBar then
            bar = blizBar
            StrongHide(fallbackBar)
        else
            -- no Blizzard bar (unlikely) - don't create fallback unless forced
            bar = nil
        end
    else
        -- For level >=80 or when forceApply is enabled we will use/create the fallback
        if not fallbackBar then fallbackBar = CreateFallbackBar() end
        bar = fallbackBar
    end
    -- Keep visibility consistent: hide the non-selected bar so only one is shown
    if bar == blizBar then
        StrongHide(fallbackBar)
        StrongShow(blizBar)
    elseif bar == fallbackBar then
        StrongHide(blizBar)
        StrongShow(fallbackBar)
    elseif not bar then
        -- ensure both hidden if we intentionally prefer no bar
        StrongHide(blizBar)
        StrongHide(fallbackBar)
    end
    -- schedule deferred reassert to catch late re-shows by other addons
    pcall(ReassertVisibility, bar)
    if xpMax and xpMax > 0 then
        -- If the client reports a valid XPMax and the player is below level 80 we
        -- should prefer the client's native bar and hide our fallback overlay.
        -- Only use fallback for level>=80 or when forceApply is set (handled above).
        if bar == fallbackBar and level and level < 80 then
            if blizBar and DCRestoreXPDB.useBlizzard then
                Debug("Player below level 80: preferring Blizzard bar and hiding fallback")
                StrongHide(fallbackBar)
                bar = blizBar
            else
                -- user opted out of using Blizzard and fallback exists; keep fallback hidden unless forced
                if not DCRestoreXPDB.forceApply then
                    StrongHide(fallbackBar)
                    bar = blizBar
                end
            end
        end
        -- Ensure the non-target bar is hidden immediately to avoid flicker/duplication
        if bar == blizBar then
            StrongHide(fallbackBar)
            StrongShow(blizBar)
        elseif bar == fallbackBar then
            StrongHide(blizBar)
            StrongShow(fallbackBar)
        end
        -- Enforce single-bar visibility aggressively for a short window to catch other addons
        pcall(EnforceSingleBar, bar, 15, 0.04)
        -- animate client-driven updates as well so behavior matches Blizzard
        SetBarMinMaxAndAnimate(bar, 0, xpMax, xp)
        Debug("Bar shown (client XP)")
        -- If reusing Blizzard's bar there may be a separate 'rested' overlay texture; try to keep it visible
        if blizBar and blizBar.restedOverlay and type(blizBar.restedOverlay.Show) == "function" then
            if GetXPExhaustion() then blizBar.restedOverlay:Show() else blizBar.restedOverlay:Hide() end
        end
    else
        Debug("No client XP reported (xpMax==0)")
        -- If server-side levels exceed client limits (80+ etc.) prefer showing the fallback bar
        if (level and level > 79) or DCRestoreXPDB.forceApply then
            Debug("Level >79 or forceApply: ensure fallback bar visible on login/enter")
            if not fallbackBar then fallbackBar = CreateFallbackBar() end
            bar = fallbackBar
            -- show a placeholder until server sends values
            if type(bar.SetMinMaxValues) == "function" then bar:SetMinMaxValues(0, 1) end
            if type(bar.SetValue) == "function" then bar:SetValue(0) end
            if text and type(text.SetFormattedText) == "function" then
                -- show 0% until server snapshot arrives
                text:SetFormattedText("Level %d  XP: %d / %s  (%d%%)  (waiting for server)", level, 0, "?", 0)
            end
            StrongShow(bar)
        else
            Debug("Bar hidden (no client XP and not high-level)")
            StrongHide(bar)
        end
    end
end

local ev = CreateFrame("Frame")
-- Register our addon prefix if the API exists (safe on newer clients, no-op on 3.3.5a)
if type(RegisterAddonMessagePrefix) == "function" then
    pcall(RegisterAddonMessagePrefix, "DCRXP")
end
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_XP_UPDATE")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("UNIT_LEVEL")
ev:RegisterEvent("UPDATE_EXHAUSTION")
ev:RegisterEvent("PLAYER_UPDATE_RESTING")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:SetScript("OnEvent", function(self, event, arg1, ...)
    Debug("Event fired: " .. tostring(event))
    if event == "UNIT_LEVEL" and arg1 ~= "player" then return end
    -- When the player levels up ask the server for a fresh snapshot so we display
    -- server-authored XP values (prevents client-side flicker when grants/levels occur)
    if event == "PLAYER_LEVEL_UP" or (event == "UNIT_LEVEL" and arg1 == "player") then
        local now = GetTime and GetTime() or (time and time()) or 0
        ev.__lastServerApplyTime = now
        ev.__serverForced = true
        -- ask the server for an updated snapshot; the CHAT_MSG_ADDON handler will apply it
        SendDCRXPRequest()
        -- continue to UpdateXP() below (we still want the local UI to update if needed)
    end
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
        -- Create a small retry loop to call UpdateXP several times after login in case unit data
        -- or other addons (that affect the HUD) are still initializing. This helps ensure
        -- the fallback bar shows up reliably on login for high-level characters.
        local retries = 0
        local maxRetries = 6
        local retryFrame = CreateFrame("Frame")
        retryFrame:SetScript("OnUpdate", function(self, dt)
            if retries >= maxRetries then
                self:SetScript("OnUpdate", nil)
                return
            end
            retries = retries + 1
            Debug(string.format("Login retry %d/%d running UpdateXP", retries, maxRetries))
            UpdateXP()
            -- run every 0.5s
            local sleep = 0.5
            local acc = 0
            self:SetScript("OnUpdate", function(self2, dt2)
                acc = acc + dt2
                if acc >= sleep then
                    acc = 0
                    retries = retries + 1
                    Debug(string.format("Login retry %d/%d running UpdateXP", retries, maxRetries))
                    UpdateXP()
                    if retries >= maxRetries then
                        self2:SetScript("OnUpdate", nil)
                    end
                end
            end)
        end)
        -- Request server snapshot helper (defined at top-level so we can reuse it)

        -- Send the handshake immediately and a few times afterwards until we receive
        -- a DCRXP response. We'll stop retrying once we receive any DCRXP payload
        -- to avoid duplicate server replies. The retry frame is stored so it can
        -- be cancelled from the CHAT_MSG_ADDON handler.
        do
            local attempts = 0
            local maxAttempts = 6
            local interval = 0.5
            -- immediate send
            SendDCRXPRequest()
            reqFrame = CreateFrame("Frame")
            reqFrame._acc = 0
            reqFrame:SetScript("OnUpdate", function(self, dt)
                if attempts >= maxAttempts then
                    self:SetScript("OnUpdate", nil)
                    return
                end
                self._acc = (self._acc or 0) + dt
                if self._acc >= interval then
                    self._acc = 0
                    attempts = attempts + 1
                    Debug(string.format("DCRXP_REQ retry %d/%d", attempts, maxAttempts))
                    SendDCRXPRequest()
                end
            end)
        end
    elseif event == "CHAT_MSG_ADDON" then
        -- For 3.3.5a the handler receives (prefix, message, channel, sender) as varargs
        local prefix = arg1
        local message = select(1, ...)
        Debug("CHAT_MSG_ADDON received: prefix=" .. tostring(prefix) .. " message=" .. tostring(message))
        -- also print to chat for normal debug visibility (only when debug is enabled)
        if DCRestoreXPDB.debug then
            if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
                DEFAULT_CHAT_FRAME:AddMessage("[DCRXP RX] " .. tostring(prefix) .. " " .. tostring(message))
            else
                print("[DCRXP RX] " .. tostring(prefix) .. " " .. tostring(message))
            end
        end
        -- optionally make this visible in the UI for quick verification (toggle via /dcrxp uimsg on/off)
        if DCRestoreXPDB.debugUiErrors and UIErrorsFrame and type(UIErrorsFrame.AddMessage) == "function" then
            pcall(UIErrorsFrame.AddMessage, UIErrorsFrame, "[DCRXP RX] " .. tostring(prefix) .. " " .. tostring(message))
        end
            -- Deduplicate identical payloads and stop the handshake retries once we've
            -- received at least one server snapshot.
            if prefix == "DCRXP" and message then
                -- cancel request retries on first valid server reply
                if reqFrame and type(reqFrame.SetScript) == "function" then
                    reqFrame:SetScript("OnUpdate", nil)
                    Debug("Cancelled DCRXP_REQ retry frame after receiving server snapshot")
                end
                -- simple dedupe: ignore identical messages received within 2 seconds
                local now = GetTime and GetTime() or (time and time())
                if not now then now = 0 end
                if message == (ev.__lastPayload or "") and ev.__lastPayloadTime and (now - ev.__lastPayloadTime) < 2.0 then
                    Debug("Ignored duplicate DCRXP payload")
                    return
                end
                ev.__lastPayload = message
                ev.__lastPayloadTime = now
                -- proceed
            
            -- expected payload: "XP|<xp>|<xpMax>|<level>"
            local parts = {}
            for p in string.gmatch(message, "([^|]+)") do table.insert(parts, p) end
            if parts[1] == "XP" then
                local sxp = tonumber(parts[2]) or 0
                local sxpMax = tonumber(parts[3]) or 0
                local slevel = tonumber(parts[4]) or UnitLevel("player")
                Debug(string.format("DCRXP payload parsed: sxp=%d sxpMax=%d slevel=%d", sxp, sxpMax, slevel))
                -- Mark that we've received a server snapshot so the retry loop can stop
                ev.__gotSnapshot = true
                -- Delegate server-provided XP to a helper so we can reuse it for the test button
                Debug("Applying server-provided XP (if client reports no XPMax or server prefers)")
                ApplyServerXP(sxp, sxpMax, slevel)
                Debug("ApplyServerXP() completed")
            end
        end
    elseif event == "PLAYER_XP_UPDATE" then
        -- If we recently applied a server snapshot, skip the next client XP update
        -- to avoid immediate override/flicker. Use a small debounce window (~2.2s)
        local now = GetTime and GetTime() or (time and time()) or 0
        if ev.__lastServerApplyTime and ev.__serverForced and (now - ev.__lastServerApplyTime) < 2.2 then
            Debug("Skipped PLAYER_XP_UPDATE because a recent server snapshot was applied")
            -- Clear the forced marker so subsequent client updates run normally
            ev.__serverForced = nil
            return
        end
        UpdateXP()
    else
        UpdateXP()
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
        DCRestoreXPDB.useBlizzard = true
        -- try to switch immediately
        blizBar = FindBlizzardXPBar()
        if blizBar then
            bar = blizBar
            Debug("Switched to Blizzard XP bar immediately")
        else
            Debug("Blizzard XP bar not found; will attempt on next reload")
        end
        print("DC-RestoreXP: will attempt to reuse Blizzard XP bar now or on next reload")
    elseif cmd == "usebliz off" then
        DCRestoreXPDB.useBlizzard = false
        -- switch to fallback immediately
        if bar == blizBar then
            if not fallbackBar then fallbackBar = CreateFallbackBar() end
            bar = fallbackBar
            Debug("Switched to fallback XP bar immediately")
        end
        -- hide Blizzard when disabling reuse and show fallback only if appropriate
    StrongHide(blizBar)
    StrongShow(fallbackBar)
        -- schedule deferred reassert in case other addons toggle visibility
        pcall(ReassertVisibility, bar)
        print("DC-RestoreXP: will use fallback bar instead of Blizzard bar")
    elseif cmd == "force on" then
        DCRestoreXPDB.forceApply = true
        Debug("forceApply enabled: server XP will be applied even if client reports XPMax")
        print("DC-RestoreXP: forceApply enabled")
    elseif cmd == "force off" then
        DCRestoreXPDB.forceApply = false
        Debug("forceApply disabled")
        print("DC-RestoreXP: forceApply disabled")
        -- Re-evaluate visibility immediately after disabling forceApply
        UpdateXP()
    elseif cmd == "debug on" then
        DCRestoreXPDB.debug = true
        Debug("debug messages enabled")
        print("DC-RestoreXP: debug messages enabled")
    elseif cmd == "debug off" then
        DCRestoreXPDB.debug = false
        print("DC-RestoreXP: debug messages disabled")
    elseif cmd == "hidetext on" then
        DCRestoreXPDB.hideText = true
        Debug("hideText enabled: addon-created text will be hidden")
        print("DC-RestoreXP: addon bar text hidden")
        -- hide any already-created text objects
        if blizBar and blizBar.__dcrxp_text then pcall(blizBar.__dcrxp_text.Hide, blizBar.__dcrxp_text) end
        if blizBar and blizBar.__dcrxp_textBg then pcall(blizBar.__dcrxp_textBg.Hide, blizBar.__dcrxp_textBg) end
        if fallbackBar and fallbackBar.__dcrxp_text then pcall(fallbackBar.__dcrxp_text.Hide, fallbackBar.__dcrxp_text) end
        if fallbackBar and fallbackBar.__dcrxp_textBg then pcall(fallbackBar.__dcrxp_textBg.Hide, fallbackBar.__dcrxp_textBg) end
    elseif cmd == "hidetext off" then
        DCRestoreXPDB.hideText = false
        Debug("hideText disabled: addon-created text will be shown/updated")
        print("DC-RestoreXP: addon bar text will be displayed when available")
        -- force an update so text is re-created if needed
        UpdateXP()
    elseif cmd == "uimsg on" then
        DCRestoreXPDB.debugUiErrors = true
        Debug("UIErrorsFrame messages enabled")
        print("DC-RestoreXP: UIErrorsFrame messages enabled")
    elseif cmd == "uimsg off" then
        DCRestoreXPDB.debugUiErrors = false
        print("DC-RestoreXP: UIErrorsFrame messages disabled")
    elseif cmd == "status" then
        print(string.format("DC-RestoreXP status: useBlizzard=%s x=%d y=%d anchor=%s point=%s", tostring(DCRestoreXPDB.useBlizzard), DCRestoreXPDB.x, DCRestoreXPDB.y, DCRestoreXPDB.anchor, DCRestoreXPDB.point))
    elseif cmd == "dump" then
        -- Print raw GetMinMaxValues/GetValue for current bars
        local function safeGet(fn) if not fn then return nil end local ok, res = pcall(fn); if ok then return res end return nil end
        local t = bar or fallbackBar or blizBar
        print("DC-RestoreXP dump:")
        print(" blizBar exists=" .. tostring(blizBar ~= nil))
        print(" usingBliz=" .. tostring(bar == blizBar))
        if t then
            local name = safeGet(function() return t:GetName() end) or tostring(t)
            local cur = safeGet(function() if type(t.GetValue) == "function" then return t:GetValue() end end)
            local minv, maxv = safeGet(function() if type(t.GetMinMaxValues) == "function" then return t:GetMinMaxValues() end end)
            print(string.format(" name=%s cur=%s min=%s max=%s shown=%s", tostring(name), tostring(cur), tostring(minv), tostring(maxv), tostring(safeGet(function() if type(t.IsShown) == "function" then return t:IsShown() end end))))
        else
            print(" no bar object found")
        end
    elseif cmd == "bar" or cmd == "debugbar" or cmd == "showbar" then
        -- Dedicated debug command: print current bar object info and blizBar presence
        local function safeGet(fn, errval)
            if not fn then return errval end
            local ok, res = pcall(fn)
            if ok then return res else return errval end
        end
        local target = bar or fallbackBar or blizBar
        local targetName = safeGet(function() return (target and target.GetName and target:GetName()) end, tostring(target))
        local isShown = safeGet(function() return (target and type(target.IsShown) == "function" and target:IsShown()) end, false)
        local width = safeGet(function() return (target and type(target.GetWidth) == "function" and target:GetWidth()) end, nil)
        local height = safeGet(function() return (target and type(target.GetHeight) == "function" and target:GetHeight()) end, nil)
        local blizFound = (blizBar ~= nil)
        local usingBliz = (bar == blizBar)
        local fbExists = (fallbackBar ~= nil)
        print(string.format("DC-RestoreXP bar info: name=%s shown=%s width=%s height=%s blizFound=%s usingBliz=%s fallbackExists=%s", tostring(targetName), tostring(isShown), tostring(width), tostring(height), tostring(blizFound), tostring(usingBliz), tostring(fbExists)))
        if fbExists then
            local fwidth = safeGet(function() return (fallbackBar and type(fallbackBar.GetWidth) == "function" and fallbackBar:GetWidth()) end, nil)
            local fheight = safeGet(function() return (fallbackBar and type(fallbackBar.GetHeight) == "function" and fallbackBar:GetHeight()) end, nil)
            print(string.format("Fallback bar metrics: name=%s width=%s height=%s shown=%s", tostring(safeGet(function() return fallbackBar:GetName() end, tostring(fallbackBar))), tostring(fwidth), tostring(fheight), tostring(safeGet(function() return fallbackBar:IsShown() end, false))))
        end
    elseif cmd == "test" then
        DCRestoreXPDB.showTest = not DCRestoreXPDB.showTest
        if DCRestoreXPDB.showTest then
            testBtn:Show()
            Debug("Test button shown; click it to apply server XP values")
        else
            testBtn:Hide()
            Debug("Test button hidden")
        end
    elseif cmd == "runtests" then
        -- run a small suite of local unit tests that exercise ApplyServerXP and the addon handler
        local function safePrint(...) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(table.concat({...}, " ")) end print(table.concat({...}, " ")) end
        safePrint("DC-RestoreXP: running local unit tests...")
        -- Save originals
        local oldUnitXP = UnitXP
        local oldUnitXPMax = UnitXPMax
        local oldUnitLevel = UnitLevel
        -- Helper to restore
        local function restore()
            UnitXP = oldUnitXP
            UnitXPMax = oldUnitXPMax
            UnitLevel = oldUnitLevel
            safePrint("DC-RestoreXP: restored global Unit* functions")
        end
        -- Test 1: client reports no XP -> server values should be applied to fallback
        UnitXPMax = function() return 0 end
        UnitXP = function() return 0 end
        UnitLevel = function() return 85 end
        safePrint("Test1: client XPMax=0 -> ApplyServerXP should show fallback")
        ApplyServerXP(12345, 100000, 85)
        -- Test 2: client reports higher XPMax -> without forceApply should skip
        UnitXPMax = function() return 200000 end
        safePrint("Test2: client XPMax=200000 -> ApplyServerXP with smaller sxpMax should skip")
        DCRestoreXPDB.forceApply = false
        ApplyServerXP(5000, 100000, 85)
        -- Test 3: forceApply should override
        safePrint("Test3: forceApply on -> ApplyServerXP should apply despite client XPMax")
        DCRestoreXPDB.forceApply = true
        ApplyServerXP(5000, 100000, 85)
        -- Test 4: handler path - simulate CHAT_MSG_ADDON handler invocation
        safePrint("Test4: simulate CHAT_MSG_ADDON handler")
        if ev and type(ev.GetScript) == "function" then
            local h = ev:GetScript("OnEvent")
            if h then
                h(ev, "CHAT_MSG_ADDON", "DCRXP", "XP|900|10000|85")
            end
        end
        -- Cleanup
        restore()
        DCRestoreXPDB.forceApply = false
        safePrint("DC-RestoreXP: unit tests completed")
    elseif cmd:match("^showhide") then
        -- Accept: showhide on [seconds]  OR  showhide off
        local sub, rawSeconds = string.match(msg, "^%s*showhide%s*(%S*)%s*(%d*)")
        sub = sub or ""
        sub = tostring(sub):lower()
        if sub == "on" then
            local secs = tonumber(rawSeconds) or 10
            StartShowHideLogging(secs)
            print(string.format("DC-RestoreXP: show/hide instrumentation enabled (%ds) — check chat for logged calls", secs))
        elseif sub == "off" then
            UnhookShowHide()
            print("DC-RestoreXP: show/hide instrumentation disabled")
        else
            print("Usage: /dcrxp showhide on [seconds]  |  /dcrxp showhide off")
        end
    else
        print("DC-RestoreXP commands: reset|usebliz on|usebliz off")
    end
end
