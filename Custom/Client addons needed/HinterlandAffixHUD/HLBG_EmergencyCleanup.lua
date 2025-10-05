-- HLBG_EmergencyCleanup.lua
-- One-time early cleanup to hide legacy HUD frames and cancel their OnUpdate handlers.
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

local function safeHide(name)
    local ok, _ = pcall(function()
        local fr = _G[name]
        if fr and type(fr) == 'table' and type(fr.Hide) == 'function' then
            fr:Hide()
        end
        if fr and type(fr.SetScript) == 'function' then
            pcall(function() fr:SetScript('OnUpdate', nil) end)
        end
        -- clear global reference if it's the legacy object
        if type(fr) == 'table' and fr.GetObjectType and fr:GetObjectType() == 'Frame' then
            -- only nil if safe to avoid breaking other addons
            _G[name] = nil
        end
    end)
    return ok
end

local function runCleanup()
    -- Common legacy names we want removed early
    local names = {
        'WorldStateAlwaysUpFrame', 'AlwaysUpFrame', 'HinterlandAffixHUD', 'HLBG_HUD', 'HLBG_AffixChip', 'HLBG_AffixHUD', 'HLAffixHUDOptionsPanel'
    }
    for _, n in ipairs(names) do safeHide(n) end
end

local f = CreateFrame('Frame')
f:RegisterEvent('ADDON_LOADED')
f:RegisterEvent('PLAYER_ENTERING_WORLD')
f:SetScript('OnEvent', function(self, event, arg1)
    -- check DB toggle (default true)
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    if HinterlandAffixHUDDB.emergencyCleanup == false then
        return
    end
    -- run immediately to catch frames created before our file in TOC
    runCleanup()
    -- schedule a short-delayed run to catch frames created during other ADDON_LOADED handlers
    if C_Timer and C_Timer.After then
        pcall(function() C_Timer.After(1, runCleanup) end)
    else
        -- fallback: create a short timer
        local t = CreateFrame('Frame')
        local acc = 0
        t:SetScript('OnUpdate', function(self, elapsed)
            acc = acc + (elapsed or 0)
            if acc > 1 then runCleanup(); self:SetScript('OnUpdate', nil) end
        end)
    end
end)

-- run once now in case file loaded after UI
pcall(function()
    if HinterlandAffixHUDDB and HinterlandAffixHUDDB.emergencyCleanup == false then return end
    runCleanup()
end)

-- Internal toggle implementation (kept local so we can reliably reference it)
local function toggleCleanupInternal(enable)
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    if enable == nil then enable = not (HinterlandAffixHUDDB.emergencyCleanup == false) end
    HinterlandAffixHUDDB.emergencyCleanup = enable and true or false
    if enable then pcall(runCleanup) end
    return HinterlandAffixHUDDB.emergencyCleanup
end

-- Expose a global convenience function so scripts calling it directly don't fail
_G.HLBG_ToggleEmergencyCleanup = _G.HLBG_ToggleEmergencyCleanup or toggleCleanupInternal

-- Ensure the HLBG table (if present) gets the toggle attached; re-run for a short window
local function ensureAttached()
    if type(_G.HLBG) == 'table' then
        pcall(function()
            if type(_G.HLBG.ToggleEmergencyCleanup) ~= 'function' then
                _G.HLBG.ToggleEmergencyCleanup = _G.HLBG_ToggleEmergencyCleanup
            end
        end)
    end
end

ensureAttached()
if C_Timer and C_Timer.NewTicker then
    -- run a few times to survive table swaps during addon init
    local t = C_Timer.NewTicker(0.5, function()
        ensureAttached()
    end)
    -- cancel after ~5 seconds
    C_Timer.After(5, function() if t and t.Cancel then pcall(t.Cancel, t) end end)
else
    -- fallback: run ensureAttached a few times by OnUpdate
    local probe = CreateFrame('Frame')
    local tries = 0
    probe:SetScript('OnUpdate', function(self, elapsed)
        tries = tries + 1
        ensureAttached()
        if tries > 10 then self:SetScript('OnUpdate', nil) end
    end)
end
