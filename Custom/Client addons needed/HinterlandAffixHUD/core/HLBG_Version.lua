local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Keep this in sync with the .toc Version field. If build tooling injects a git hash,
-- append it here dynamically (e.g., 1.5.8-refactor+g<hash>).
HLBG.VERSION = '1.5.8-refactor'
HLBG.BUILD_TS = '2025-10-07'

if not HLBG.PrintVersion then
    function HLBG.PrintVersion(prefix)
        prefix = prefix or '|cFF33FF99HLBG|r'
        print(string.format('%s addon version %s (%s)', prefix, tostring(HLBG.VERSION), tostring(HLBG.BUILD_TS)))
    end
end

-- Auto-print once on load (guard against multiple loads on /reload)
if not HLBG._versionPrinted then
    HLBG._versionPrinted = true
    C_Timer.After(2, function() if HLBG.PrintVersion then HLBG.PrintVersion() end end)
end
