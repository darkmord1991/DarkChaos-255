-- CI path shim for the addon suite, loaded through LUA_INIT before every test file:
--   LUA_INIT=@<repo>/Custom/Client addons needed/_tests/ci_pathmap.lua
--   DC_REPO_ROOT=<repo checkout>        (required; the shim does nothing without it)
--   SIM_FRAMEXML=<stock 3.3.5 FrameXML>/  (optional; talents_client.lua reads the global SIM_FRAMEXML)
--
-- Most tests name their files by the workstation path K:\Dark-Chaos\DarkChaos-255-Master\... .
-- On a Linux runner that path does not exist and its backslashes are ordinary file name
-- characters, so dofile/loadfile/io.open/io.lines get that prefix replaced by DC_REPO_ROOT and
-- the rest of the path turned into forward slashes. Locally, without DC_REPO_ROOT, nothing changes.

local framexml = os.getenv("SIM_FRAMEXML")
if framexml and framexml ~= "" and rawget(_G, "SIM_FRAMEXML") == nil then
    SIM_FRAMEXML = framexml
end

local root = os.getenv("DC_REPO_ROOT")
if not root or root == "" then
    return
end
root = string.gsub(string.gsub(root, "\\", "/"), "/+$", "") .. "/"

local PREFIXES = {
    "k:\\dark-chaos\\darkchaos-255-master\\",
    "k:/dark-chaos/darkchaos-255-master/",
}

local function map(path)
    if type(path) ~= "string" then
        return path
    end
    local lower = string.lower(path)
    for _, prefix in ipairs(PREFIXES) do
        if string.sub(lower, 1, #prefix) == prefix then
            local rest = string.gsub(string.sub(path, #prefix + 1), "\\", "/")
            return root .. rest
        end
    end
    return path
end

local rawDofile, rawLoadfile, rawOpen, rawLines = dofile, loadfile, io.open, io.lines

dofile = function(path, ...)
    return rawDofile(map(path), ...)
end

loadfile = function(path, ...)
    return rawLoadfile(map(path), ...)
end

io.open = function(path, ...)
    return rawOpen(map(path), ...)
end

io.lines = function(path, ...)
    if path == nil then
        return rawLines()
    end
    return rawLines(map(path), ...)
end
