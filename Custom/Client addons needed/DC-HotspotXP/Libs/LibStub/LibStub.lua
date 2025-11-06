local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2

if not LibStub or LibStub.minor < LIBSTUB_MINOR then
    LibStub = LibStub or {}
    LibStub.libs = LibStub.libs or {}
    LibStub.minors = LibStub.minors or {}
    LibStub.minor = LIBSTUB_MINOR

    function LibStub:NewLibrary(major, minor)
        assert(type(major) == "string", "LibStub: major must be a string")
        minor = tonumber(minor) or 0

        local oldMinor = self.minors[major]
        if oldMinor and oldMinor >= minor then
            return nil
        end

        local lib = self.libs[major]
        if not lib then
            lib = {}
            self.libs[major] = lib
        end

        self.minors[major] = minor
        return lib, oldMinor
    end

    function LibStub:GetLibrary(major, silent)
        local lib = self.libs[major]
        if not lib and not silent then
            error(("Library '%s' not found"):format(tostring(major)), 2)
        end
        return lib, self.minors[major]
    end

    function LibStub:IterateLibraries()
        return pairs(self.libs)
    end

    setmetatable(LibStub, {
        __call = function(self, major, silent)
            return self:GetLibrary(major, silent)
        end
    })

    _G.LibStub = LibStub
end

