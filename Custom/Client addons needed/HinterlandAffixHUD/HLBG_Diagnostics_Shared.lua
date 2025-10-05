-- HLBG_Diagnostics_Shared.lua
-- Guarantee a diagnostic PrintStartupHistory function exists even if AIO swaps HLBG

_G.HLBG = _G.HLBG or {}

local function printHistory(n)
    n = tonumber(n) or 1
    local hist = HinterlandAffixHUDDB and HinterlandAffixHUDDB.startupHistory
    if not hist or #hist == 0 then
        if type(_G.HLBG.SafePrint) == 'function' then _G.HLBG.SafePrint('HLBG: no startup history saved') else print('HLBG: no startup history saved') end
        return
    end
    if n < 1 then n = 1 end
    if n > #hist then n = #hist end
    local e = hist[n]
    if not e then return end
    local msg = string.format('HLBG startup @ %s: AIO=%s handlers=%s ui=%s', date('%Y-%m-%d %H:%M:%S', e.ts), tostring(e.aio), tostring(e.handlers), tostring(e.ui))
    if type(_G.HLBG.SafePrint) == 'function' then _G.HLBG.SafePrint(msg) else print(msg) end
end

-- Attach to HLBG table if not present
if type(_G.HLBG.PrintStartupHistory) ~= 'function' then
    _G.HLBG.PrintStartupHistory = printHistory
end

-- Provide a global fallback function too (callable via /run HLBG_PrintStartupHistory(1))
if type(_G.HLBG_PrintStartupHistory) ~= 'function' then
    _G.HLBG_PrintStartupHistory = function(n) return printHistory(n) end
end

-- Register a reliable slash command to print the history
if type(SLASH_HLBGPSH1) == 'nil' then
    SLASH_HLBGPSH1 = '/hlbgpsh'
    SlashCmdList['HLBGPSH'] = function(msg)
        local n = tonumber((msg or ''):match('^(%d+)') or 1)
        printHistory(n)
    end
end
