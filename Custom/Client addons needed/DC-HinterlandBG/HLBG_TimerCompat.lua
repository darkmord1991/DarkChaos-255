-- HLBG_TimerCompat.lua - C_Timer availability check.
--
-- WHY THIS FILE IS NOW A STUB
-- ---------------------------
-- It used to carry a full C_Timer polyfill guarded by `if not C_Timer then`.
-- That all-or-nothing guard was the bug. DC-Collection loads earlier
-- (addons load in alphabetical folder order) and installed a C_Timer with
-- After and NewTimer but no NewTicker, so the table existed, this entire
-- block was skipped, and C_Timer.NewTicker stayed nil for the whole session.
--
-- Every NewTicker call site in this addon is type-guarded, so nothing ever
-- errored. The HUD timer (HLBG_HUD_Modern.lua:318) and telemetry ticker
-- (:610) silently fell back to the per-frame OnUpdate they were explicitly
-- written to avoid, and HLBG_Queue_Client.lua:553 -- which has no fallback
-- branch -- silently never ran, so the queue never auto-refreshed.
--
-- C_Timer now comes from DC-AddonProtocol/DCCompat.lua, which installs each
-- function independently so a partial table from any source still ends up
-- complete. DC-AddonProtocol is a hard dependency of this addon, so it is
-- always loaded before this file runs.

if _G.HLBG_RecordFileLoad then
    _G.HLBG_RecordFileLoad("HLBG_TimerCompat.lua")
end

-- If the shared layer somehow did not load, say so loudly. Failing silently is
-- exactly what made the original bug survive in production.
if type(_G.C_Timer) ~= "table" or type(_G.C_Timer.NewTicker) ~= "function" then
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cFFFF4444HLBG:|r C_Timer.NewTicker unavailable - "
            .. "DC-AddonProtocol/DCCompat.lua did not load. "
            .. "Queue auto-refresh and HUD tickers will not run.")
    end
end
-- Alert that the compatibility layer is in place
do
    local dev = (_G.DCHLBGDB and _G.DCHLBGDB.devMode) or (_G.HLBG and _G.HLBG._devMode)
    if dev and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG:|r C_Timer compatibility layer loaded")
    end
end

