-- Fuller DongleStub compatibility shim
-- Provides RegisterLibrary, Register, IsNewerVersion, GetLibrary, Embed and simple version bookkeeping
if not DongleStub then DongleStub = {} end

DongleStub._registry = DongleStub._registry or {}
DongleStub._versions = DongleStub._versions or {}

-- Check if provided minor represents a newer version than what we have
function DongleStub:IsNewerVersion(name, minor)
    if not name then return true end
    local cur = self._versions[name]
    if not cur then return true end
    return (tonumber(minor) or 0) > (tonumber(cur) or 0)
end

-- Register a named library; expose Astrolabe globally when present
function DongleStub:RegisterLibrary(name, lib, minor)
    if not name or type(lib) ~= "table" then return false end
    self._registry[name] = lib
    if minor then self._versions[name] = tostring(minor) end
    if type(name) == "string" and name:lower():find("astrolabe") then
        _G["Astrolabe"] = lib
    end
    return true
end

-- Backwards-compatible Register(lib, activateFunc)
function DongleStub:Register(lib, activate)
    if type(lib) ~= "table" then return false end
    local name = lib.libraryName or lib.name or "donglelib"
    local minor
    if type(lib.GetVersion) == "function" then
        local ok, a, b = pcall(lib.GetVersion, lib)
        if ok and a then
            name = name or a
            minor = b
        end
    end
    DongleStub:RegisterLibrary(name, lib, minor)
    if type(activate) == "function" then pcall(activate, lib) end
    return true
end

function DongleStub:GetLibrary(name)
    return self._registry[name]
end

-- Simple embed: copy functions into target table if missing
function DongleStub:Embed(target)
    if type(target) ~= "table" then return end
    for k,v in pairs(self) do
        if type(v) == "function" and not target[k] then target[k] = v end
    end
end

-- Factory returning a simple constructor for creating tiny libs
function DongleStub:New()
    return function(libName, minor)
        local lib = { libraryName = libName }
        if minor then lib._minor = minor end
        return lib
    end
end
