-- HLBG_AIO_Shim.lua
-- Defensive shim: ensure HLBG._ensureUI exists to avoid nil-call errors during startup testing.
-- This file intentionally provides a no-op implementation that will be safe until the
-- real UI initializer loads. It's safe for testing and will prevent "attempt to call
-- field '_ensureUI' (a nil value)" errors.

if type(HLBG) ~= 'table' then
    HLBG = HLBG or {}
end

if type(HLBG._ensureUI) ~= 'function' then
    HLBG._ensureUI = function(...)
        -- no-op during early startup; return nil to indicate nothing happened
        return nil
    end
end

-- also defensively ensure other optional helpers used by AIO are safe
if type(HLBG.GetAffixName) ~= 'function' then
    HLBG.GetAffixName = function(x) return tostring(x or '') end
end
