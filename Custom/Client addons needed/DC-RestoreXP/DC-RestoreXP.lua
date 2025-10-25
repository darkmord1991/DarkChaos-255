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
    if anim.bar.__dcrxp_text and type(anim.bar.__dcrxp_text.SetFormattedText) == "function" then
        -- keep text updated during animation (min/max should be set by caller)
        -- no-op here; text is updated when min/max/value are set externally
    end
    if p >= 1 then
        anim.active = false
        self:Hide()
    end
end)

local function AnimateBarTo(barObj, newValue, dur)
    if not barObj or type(barObj.GetValue) ~= "function" then return end
    anim.bar = barObj
    anim.start = barObj:GetValue() or 0
    anim.target = newValue or anim.start
    anim.duration = dur or 0.3
    anim.elapsed = 0
    anim.active = true
    animFrame:Show()
end

local function SetBarMinMaxAndAnimate(barObj, minv, maxv, value)
    if not barObj then return end
    if type(barObj.SetMinMaxValues) == "function" then barObj:SetMinMaxValues(minv or 0, maxv or 1) end
    -- update text immediately
    local rested = (GetXPExhaustion() or 0)
    if barObj == blizBar then
        if not blizBar.__dcrxp_text then
            blizBar.__dcrxp_text = blizBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        -- place text above the Blizzard bar to avoid overlap with action buttons
        blizBar.__dcrxp_text:SetPoint("BOTTOM", blizBar, "TOP", 0, 2)
        end
        if type(blizBar.__dcrxp_text.SetFormattedText) == "function" then
            local pct = 0
            if maxv and maxv > 0 then pct = math.floor((value or 0) * 100 / maxv) end
            blizBar.__dcrxp_text:SetFormattedText("Level %d  XP: %d / %d  (%d%%)  (rested %d)", UnitLevel("player") or 0, value or 0, maxv or 0, pct, rested)
        end
    else
        if not text and barObj.CreateFontString then
            text = barObj:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("CENTER", barObj, "CENTER")
        end
        if text and type(text.SetFormattedText) == "function" then
            local pct = 0
            if maxv and maxv > 0 then pct = math.floor((value or 0) * 100 / maxv) end
            text:SetFormattedText("Level %d  XP: %d / %d  (%d%%)  (rested %d)", UnitLevel("player") or 0, value or 0, maxv or 0, pct, rested)
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
                        fill:SetVertexColor(0.0, 0.39, 0.88, 0.15)
                    elseif restStateID == 2 then
                        fill:SetVertexColor(0.58, 0.0, 0.55, 0.15)
                    else
                        fill:SetVertexColor(1.0, 1.0, 1.0, 0.15)
                    end
                end
            end
        end
    end
end

-- Create our own bar styled to match Blizzard when no blizBar is available or user disabled reuse
local function CreateFallbackBar()
    -- Create a fallback XP status bar that mirrors MainMenuBar's layout and textures
    local b = CreateFrame("StatusBar", "DCRestoreXPBar", UIParent)
    -- Prefer a compact width so the bar is readable on most HUD layouts. If Blizzard's bar exists
    -- mirror its height, otherwise use a sensible default width/height that won't be clipped.
    local defaultW, defaultH = 512, 16
    if blizBar then
        local w = blizBar:GetWidth() or defaultW
        local h = blizBar:GetHeight() or defaultH
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
    -- Use a slightly larger font for readability on dense UIs
    local fontName, fontSize, fontFlags = GameFontNormalSmall:GetFont()
    text:SetFont(fontName, (fontSize or 10) + 2, fontFlags)
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

    -- Rested/exhaustion visuals
    local rested = b:CreateTexture(nil, "ARTWORK")
    rested:SetAllPoints(b)
    rested:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    rested:Hide()
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
    local exhaustionFill = b:CreateTexture(nil, "BORDER")
    exhaustionFill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    exhaustionFill:Hide()
    b.exhaustionFill = exhaustionFill
    -- Expose the Blizzard global name used in FrameXML for the exhaustion/rested fill
    if not _G["ExhaustionLevelFillBar"] then _G["ExhaustionLevelFillBar"] = exhaustionFill end

    return b
end

fallbackBar = CreateFallbackBar()
bar = fallbackBar
Debug("Created fallback bar and using it by default")

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
    -- keep using fallbackBar as 'bar'
    bar = fallbackBar
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
    -- Determine whether this is a server-side high-level player (where client UI can't represent levels)
    local highLevel = (slevel and type(slevel) == "number" and slevel > 79)
    if not DCRestoreXPDB.forceApply then
        if clientMax ~= 0 and (not sxpMax or sxpMax <= clientMax) then
            if clientXP > 0 then
                if highLevel then
                    -- For high-level servers prefer the fallback bar even if the client reports a valid XP
                    Debug(string.format("High-level player (slevel=%d): overriding client-skip logic and applying server values to fallback bar", slevel))
                else
                    Debug(string.format("Client reports valid XPMax=%d and server sxpMax=%s <= clientMax; clientXP=%d -> skipping apply", clientMax, tostring(sxpMax), clientXP))
                    return
                end
            else
                Debug(string.format("Client reports XPMax=%d but clientXP=%d -> applying server values to restore bar", clientMax, clientXP))
            end
        end
    else
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
    -- If the server reports a player level above 79 (i.e. level 80+ on server-side),
    -- prefer the fallback bar so that high-level servers always display using our bar.
    if slevel and type(slevel) == "number" and slevel > 79 then
        if not fallbackBar then fallbackBar = CreateFallbackBar() end
        target = fallbackBar
        Debug(string.format("slevel=%d >79: forcing application to fallback bar for high-level player", slevel))
    end
    if sxpMax and sxpMax > 0 then
        SetBarMinMaxAndAnimate(target, 0, sxpMax, sxp)
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
    else
        if type(target.Hide) == "function" then target:Hide() end
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
        if type(bar.Hide) == "function" then bar:Hide() end
        return
    end
    local xp = UnitXP("player") or 0
    local xpMax = UnitXPMax("player") or 0
    local level = UnitLevel("player") or 0
    Debug(string.format("Player XP=%d XPMax=%d Level=%d", xp, xpMax, level))
    if xpMax and xpMax > 0 then
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
            if type(bar.Show) == "function" then bar:Show() end
        else
            Debug("Bar hidden (no client XP and not high-level)")
            if type(bar.Hide) == "function" then bar:Hide() end
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
        -- Send a small client->server handshake request so the server can reply with
        -- current XP values when the client is ready. This avoids race conditions
        -- where the server sends its initial snapshot before the addon is ready.
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
                -- simple dedupe: ignore identical messages received within 1 second
                local now = GetTime and GetTime() or (time and time())
                if not now then now = 0 end
                if message == (ev.__lastPayload or "") and ev.__lastPayloadTime and (now - ev.__lastPayloadTime) < 1.0 then
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
        print("DC-RestoreXP: will use fallback bar instead of Blizzard bar")
    elseif cmd == "force on" then
        DCRestoreXPDB.forceApply = true
        Debug("forceApply enabled: server XP will be applied even if client reports XPMax")
        print("DC-RestoreXP: forceApply enabled")
    elseif cmd == "force off" then
        DCRestoreXPDB.forceApply = false
        Debug("forceApply disabled")
        print("DC-RestoreXP: forceApply disabled")
    elseif cmd == "debug on" then
        DCRestoreXPDB.debug = true
        Debug("debug messages enabled")
        print("DC-RestoreXP: debug messages enabled")
    elseif cmd == "debug off" then
        DCRestoreXPDB.debug = false
        print("DC-RestoreXP: debug messages disabled")
    elseif cmd == "uimsg on" then
        DCRestoreXPDB.debugUiErrors = true
        Debug("UIErrorsFrame messages enabled")
        print("DC-RestoreXP: UIErrorsFrame messages enabled")
    elseif cmd == "uimsg off" then
        DCRestoreXPDB.debugUiErrors = false
        print("DC-RestoreXP: UIErrorsFrame messages disabled")
    elseif cmd == "status" then
        print(string.format("DC-RestoreXP status: useBlizzard=%s x=%d y=%d anchor=%s point=%s", tostring(DCRestoreXPDB.useBlizzard), DCRestoreXPDB.x, DCRestoreXPDB.y, DCRestoreXPDB.anchor, DCRestoreXPDB.point))
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
    else
        print("DC-RestoreXP commands: reset|usebliz on|usebliz off")
    end
end
