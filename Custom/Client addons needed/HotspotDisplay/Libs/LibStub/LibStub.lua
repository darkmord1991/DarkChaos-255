-- Minimal LibStub implementation (small, self-contained)
-- Provides LibStub(name, silent) -> returns registered library table or nil
if not LibStub then
    local _registry = {}
    local _versions = {}

    local function LibStub(name, silent)
        if not name then return nil end
        local lib = _registry[name]
        if lib then return lib end
        if silent then return nil end
        return nil
    end

    function LibStub:NewLibrary(name, minorVersion)
        if not name then return nil end
        local cur = _versions[name]
        if cur and tonumber(cur) >= tonumber(minorVersion or 0) then
            return nil -- existing equal/newer
        end
        local lib = {}
        _registry[name] = lib
        _versions[name] = tostring(minorVersion or 0)
        return lib
    end

    function LibStub:GetLibrary(name)
        return _registry[name]
    end

    _G.LibStub = LibStub
end
