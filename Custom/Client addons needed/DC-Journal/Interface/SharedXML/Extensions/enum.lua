enum = {}
local mt   = {}
local mt2  = {}

function mt.__call(...)
    local args = {...}
    local nm = args[1][1]

    _G[nm] = {}
    setmetatable(_G[nm], mt2)

    for k,v in pairs(args[3]) do
        if type(k) == "number" then
            _G[nm][v] = k
            _G[nm][k] = v

            if not _G[nm.."_"..v] then
                _G[nm.."_"..v] = k
            else
                printc(string.format("enum: variable %s already exists!", nm, v))
            end
        else
            _G[nm][k] = v
            if not _G[nm.."_"..k] then
                _G[nm.."_"..k] = v
            else
                printc(string.format("enum: %s variable %s already exists!", nm, k))
            end
        end
    end

    args[2][nm] = nil
end

function mt.__index( t, k )
    t[k] = {k}
    setmetatable(t[k], mt)
    return t[k]
end

setmetatable(enum, mt)

function mt2.__call( t, k, v )
    if t[k] then
        return t[k]
    else
        return nil
    end
end

Enum = {}