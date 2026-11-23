-- ============================================================
-- DC-LabProbe: answers the server's read-only lab probes
-- ============================================================
-- Server side: src/server/scripts/DC/LabTools/dc_lab_probe.cpp
-- (`.dca probe send <character> <request-json>`, also over SOAP).
--
-- Wire (DC addon protocol, module LABP):
--   S2C LABP|16|J|{"id":"<10 hex>","req":{"cmd":"frame","names":["PlayerFrame"]}}
--   C2S LABP|1|J|{"id":"<10 hex>","i":<1..n>,"n":<1..128>,"d":"<base64 slice>"}
-- The answer is one JSON document,
--   {"id":..,"ok":true,"cmd":..,"loadId":..,"character":..,"t":<time()>,"data":{..}}
-- or {"id":..,"ok":false,"error":".."}, cut into 135-byte slices, each sent
-- base64-encoded in its own addon frame and paced behind the protocol's send
-- throttle so a large answer never overflows its queue.
--
-- Every command is a read of UI state; nothing here runs code, changes a
-- setting or touches the game world. The server sends requests only to
-- accounts listed in DC.LabProbe.Accounts; `/labprobe off` stops this
-- character from answering at all.
-- ============================================================

local LabProbe = {}
_G.DCLabProbe = LabProbe

local MODULE = "LABP"
local CMSG_ANSWER_CHUNK = 0x01
local SMSG_REQUEST = 0x10

local CHUNK_BYTES = 135           -- raw bytes per slice (180 base64 chars)
local MAX_CHUNKS = 128
local MAX_ANSWER_BYTES = CHUNK_BYTES * MAX_CHUNKS
local MAX_LIST = 32               -- names per frame/cvars request
local MAX_TEXT = 400              -- characters kept of any one text
local MAX_REGIONS = 16            -- font strings read per frame
local MAX_AURAS = 40
local MAX_ERRORS = 20
local QUEUE_HIGH_WATER = 8        -- wait while the protocol queue holds this many
local SENDS_PER_TICK = 2

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

-- CVars that name the account; never reported.
local CVAR_DENY = { accountname = true, accountlist = true }

local TOOLTIP_LINK_TYPES = { item = true, spell = true, quest = true, achievement = true, enchant = true,
    talent = true }

local outbox = {}                 -- { { id, chunks, next } } in send order
local stats = { requests = 0, answered = 0, refused = 0, lastId = nil, lastCmd = nil }

LabProbe.loadId = string.format("%08x", math.random(0, 2147483646))
LabProbe.stats = stats

local function Protocol()
    return rawget(_G, "DCAddonProtocol")
end

local function Enabled()
    local db = rawget(_G, "DCLabProbeDB")
    return not (type(db) == "table" and db.enabled == false)
end

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[LabProbe]|r " .. tostring(msg))
    end
end

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------

function LabProbe.Base64(data)
    local out = {}
    for i = 1, #data, 3 do
        local a, b, c = string.byte(data, i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        out[#out + 1] = string.sub(B64, c1 + 1, c1 + 1) .. string.sub(B64, c2 + 1, c2 + 1)
            .. (b and string.sub(B64, c3 + 1, c3 + 1) or "=")
            .. (c and string.sub(B64, c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

local function Text(value)
    if type(value) ~= "string" then
        return nil
    end
    if #value > MAX_TEXT then
        return string.sub(value, 1, MAX_TEXT) .. "..."
    end
    return value
end

-- obj:method(...) without letting one odd widget fail the whole answer.
local function Try(obj, method, ...)
    if type(obj) ~= "table" or type(obj[method]) ~= "function" then
        return nil
    end
    local ok, a, b, c, d, e = pcall(obj[method], obj, ...)
    if ok then
        return a, b, c, d, e
    end
    return nil
end

local function NameList(req)
    local names = {}
    if type(req.names) == "table" then
        for _, name in ipairs(req.names) do
            if type(name) == "string" and #names < MAX_LIST then
                names[#names + 1] = name
            end
        end
    elseif type(req.name) == "string" then
        names[1] = req.name
    end
    return names
end

local function Count(req, default, maximum)
    local n = tonumber(req.max) or default
    n = math.floor(n)
    if n < 1 then
        n = 1
    end
    if n > maximum then
        n = maximum
    end
    return n
end

local function IsUnitToken(unit)
    if type(unit) ~= "string" then
        return false
    end
    if unit == "player" or unit == "target" or unit == "focus" or unit == "pet" or unit == "mouseover"
        or unit == "targettarget" or unit == "vehicle" then
        return true
    end
    return string.match(unit, "^party[1-4]$") ~= nil or string.match(unit, "^partypet[1-4]$") ~= nil
        or string.match(unit, "^raid%d%d?$") ~= nil or string.match(unit, "^arena[1-5]$") ~= nil
end

local function TooltipLines(tooltip)
    local lines = {}
    local name = Try(tooltip, "GetName")
    local count = Try(tooltip, "NumLines") or 0
    for i = 1, math.min(count, 40) do
        local left = name and _G[name .. "TextLeft" .. i]
        local right = name and _G[name .. "TextRight" .. i]
        local l = Text(Try(left, "GetText"))
        local r = Text(Try(right, "GetText"))
        if l or r then
            lines[#lines + 1] = { l = l, r = r }
        end
    end
    return lines
end

-- ------------------------------------------------------------
-- Commands (read-only)
-- ------------------------------------------------------------

local Commands = {}

function Commands.ping()
    return { pong = true, time = time and time() or 0, uptime = GetTime and GetTime() or 0 }
end

function Commands.state()
    local DC = Protocol()
    local version, build = "?", "?"
    if GetBuildInfo then
        version, build = GetBuildInfo()
    end
    local x, y = 0, 0
    if GetPlayerMapPosition then
        x, y = GetPlayerMapPosition("player")
    end
    local instanceName, instanceType, difficulty
    if GetInstanceInfo then
        instanceName, instanceType, difficulty = GetInstanceInfo()
    end
    local latency
    if GetNetStats then
        latency = select(3, GetNetStats())
    end
    -- `f and f()` keeps only the first return, so these two are unpacked explicitly.
    local class, race
    if UnitClass then
        class = select(2, UnitClass("player"))
    end
    if UnitRace then
        race = select(2, UnitRace("player"))
    end
    return {
        level = UnitLevel and UnitLevel("player"),
        class = class,
        race = race,
        zone = GetRealZoneText and GetRealZoneText(),
        subZone = GetSubZoneText and GetSubZoneText(),
        mapAreaId = GetCurrentMapAreaID and GetCurrentMapAreaID(),
        x = x,
        y = y,
        instance = instanceName,
        instanceType = instanceType,
        difficulty = difficulty,
        combat = (UnitAffectingCombat and UnitAffectingCombat("player")) and true or false,
        dead = (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) and true or false,
        build = tostring(version) .. " (" .. tostring(build) .. ")",
        locale = GetLocale and GetLocale(),
        fps = GetFramerate and math.floor(GetFramerate() + 0.5),
        latency = latency,
        fingerprint = DC and Try(DC, "GetNativeExtensionBuildFingerprint"),
        nativeCaps = DC and Try(DC, "GetNativeExtensionCapabilities"),
        dcConnected = DC and DC._connected and true or false,
        serverCaps = DC and tonumber(DC._serverCaps),
    }
end

local function DescribeFrame(name)
    local f = _G[name]
    if type(f) ~= "table" then
        return { name = name, exists = false }
    end
    if type(f.GetObjectType) ~= "function" then
        return { name = name, exists = true, type = "table" }
    end

    local entry = {
        name = name,
        exists = true,
        type = Try(f, "GetObjectType"),
        shown = Try(f, "IsShown") and true or false,
        visible = Try(f, "IsVisible") and true or false,
        alpha = Try(f, "GetAlpha"),
        width = Try(f, "GetWidth"),
        height = Try(f, "GetHeight"),
        left = Try(f, "GetLeft"),
        top = Try(f, "GetTop"),
        strata = Try(f, "GetFrameStrata"),
        children = Try(f, "GetNumChildren"),
    }

    local text = Try(f, "GetText")
    if type(text) == "string" then
        entry.text = Text(text)
    end

    if type(f.GetRegions) == "function" then
        local regions = { Try(f, "GetRegions") }
        local texts = {}
        for _, region in ipairs(regions) do
            if #texts >= MAX_REGIONS then
                break
            end
            if Try(region, "GetObjectType") == "FontString" then
                local value = Text(Try(region, "GetText"))
                if value and value ~= "" then
                    texts[#texts + 1] = value
                end
            end
        end
        if #texts > 0 then
            entry.texts = texts
        end
    end

    return entry
end

function Commands.frame(req)
    local names = NameList(req)
    if #names == 0 then
        return nil, "frame needs name or names"
    end
    local frames = {}
    for _, name in ipairs(names) do
        frames[#frames + 1] = DescribeFrame(name)
    end
    return { frames = frames }
end

function Commands.tooltip(req)
    if req.link ~= nil then
        local link = req.link
        local kind = type(link) == "string" and string.match(link, "^(%a+):[%d:%-]+$")
        if not kind or not TOOLTIP_LINK_TYPES[kind] then
            return nil, "link must look like item:6948 (item spell quest achievement enchant talent)"
        end
        local DC = Protocol()
        local tooltip = DC and Try(DC, "GetScanTooltip")
        if not tooltip then
            return nil, "no scan tooltip available"
        end
        Try(tooltip, "SetOwner", WorldFrame, "ANCHOR_NONE")
        Try(tooltip, "ClearLines")
        Try(tooltip, "SetHyperlink", link)
        local lines = TooltipLines(tooltip)
        -- An item the client has not cached yet comes back empty; asking
        -- again a moment later reads the filled tooltip.
        return { link = link, lines = lines, cached = #lines > 0 }
    end

    local tooltip = rawget(_G, "GameTooltip")
    local shown = Try(tooltip, "IsShown") and true or false
    local owner = Try(tooltip, "GetOwner")
    return {
        shown = shown,
        owner = owner and Try(owner, "GetName") or nil,
        lines = shown and TooltipLines(tooltip) or {},
    }
end

function Commands.auras(req)
    local unit = req.unit or "player"
    if not IsUnitToken(unit) then
        return nil, "unit must be a unit token (player target focus pet partyN raidN ...)"
    end
    if not UnitAura then
        return nil, "UnitAura unavailable"
    end
    local result = { unit = unit, exists = UnitExists and UnitExists(unit) and true or false }
    local now = GetTime and GetTime() or 0
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
        local list = {}
        for i = 1, MAX_AURAS do
            local name, rank, _, count, dispel, duration, expires, caster, stealable, _, spellId =
                UnitAura(unit, i, filter)
            if not name then
                break
            end
            list[#list + 1] = {
                n = name,
                id = spellId,
                rank = (rank ~= "" and rank) or nil,
                c = (count and count > 1) and count or nil,
                dispel = dispel,
                d = (duration and duration > 0) and duration or nil,
                r = (expires and expires > 0) and math.floor((expires - now) * 10 + 0.5) / 10 or nil,
                src = caster,
                steal = stealable and true or nil,
            }
        end
        result[filter == "HELPFUL" and "buffs" or "debuffs"] = list
    end
    return result
end

function Commands.target(req)
    local unit = req.unit or "target"
    if not IsUnitToken(unit) then
        return nil, "unit must be a unit token"
    end
    if not (UnitExists and UnitExists(unit)) then
        return { unit = unit, exists = false }
    end
    local power, powerMax, powerType
    if UnitPower then
        power, powerMax, powerType = UnitPower(unit), UnitPowerMax(unit), UnitPowerType(unit)
    end
    local casting = UnitCastingInfo and UnitCastingInfo(unit)
    local channel = UnitChannelInfo and UnitChannelInfo(unit)
    return {
        unit = unit,
        exists = true,
        name = UnitName and UnitName(unit),
        guid = UnitGUID and UnitGUID(unit),
        level = UnitLevel and UnitLevel(unit),
        classification = UnitClassification and UnitClassification(unit),
        player = (UnitIsPlayer and UnitIsPlayer(unit)) and true or false,
        reaction = UnitReaction and UnitReaction("player", unit),
        creatureType = UnitCreatureType and UnitCreatureType(unit),
        health = UnitHealth and UnitHealth(unit),
        healthMax = UnitHealthMax and UnitHealthMax(unit),
        power = power,
        powerMax = powerMax,
        powerType = powerType,
        dead = (UnitIsDead and UnitIsDead(unit)) and true or false,
        casting = casting,
        channel = channel,
    }
end

function Commands.cvars(req)
    local names = NameList(req)
    if #names == 0 then
        return nil, "cvars needs name or names"
    end
    local list = {}
    for _, name in ipairs(names) do
        if CVAR_DENY[string.lower(name)] then
            list[#list + 1] = { n = name, denied = true }
        else
            local ok, value = pcall(GetCVar, name)
            list[#list + 1] = { n = name, v = ok and value or nil }
        end
    end
    return { cvars = list }
end

function Commands.addons(req)
    if not GetNumAddOns then
        return nil, "GetNumAddOns unavailable"
    end
    local list = {}
    local total = GetNumAddOns()
    local limit = Count(req, 200, 200)
    for i = 1, math.min(total, limit) do
        local name, _, _, enabled = GetAddOnInfo(i)
        list[#list + 1] = {
            n = name,
            v = GetAddOnMetadata and Text(GetAddOnMetadata(i, "Version")) or nil,
            on = enabled and true or false,
            loaded = (IsAddOnLoaded and IsAddOnLoaded(i)) and true or false,
        }
    end
    return { total = total, addons = list }
end

function Commands.errors(req)
    local grabber = rawget(_G, "BugGrabber")
    if type(grabber) ~= "table" or type(grabber.GetDB) ~= "function" then
        return { available = false, errors = {} }
    end
    local ok, db = pcall(grabber.GetDB, grabber)
    if not ok or type(db) ~= "table" then
        return { available = false, errors = {} }
    end
    local session = Try(grabber, "GetSessionId")
    local limit = Count(req, 10, MAX_ERRORS)
    local list = {}
    for i = #db, 1, -1 do
        if #list >= limit then
            break
        end
        local err = db[i]
        if type(err) == "table" then
            local message = err.message
            if type(message) == "table" then
                message = table.concat(message, "")
            end
            list[#list + 1] = {
                m = Text(tostring(message or "")),
                c = tonumber(err.counter),
                t = err.time,
                current = (session ~= nil and err.session == session) or nil,
            }
        end
    end
    return { available = true, session = session, total = #db, errors = list }
end

LabProbe.Commands = Commands

-- ------------------------------------------------------------
-- Answering
-- ------------------------------------------------------------

local function Encode(value)
    local DC = Protocol()
    return DC and DC:EncodeJSON(value)
end

-- One answer JSON string for a request; never raises.
function LabProbe.BuildAnswer(id, req)
    local cmd = type(req) == "table" and req.cmd or nil
    local handler = type(cmd) == "string" and Commands[cmd] or nil
    local answer
    if not handler then
        answer = { id = id, ok = false, error = "unknown command" }
    else
        local ok, data, err = pcall(handler, req)
        if not ok then
            answer = { id = id, ok = false, cmd = cmd, error = "probe failed: " .. Text(tostring(data)) }
        elseif data == nil then
            answer = { id = id, ok = false, cmd = cmd, error = tostring(err or "no data") }
        else
            answer = {
                id = id,
                ok = true,
                cmd = cmd,
                loadId = LabProbe.loadId,
                character = UnitName and UnitName("player"),
                t = time and time() or 0,
                data = data,
            }
        end
    end

    local json = Encode(answer)
    if type(json) ~= "string" then
        json = Encode({ id = id, ok = false, cmd = cmd, error = "answer could not be encoded" })
    elseif #json > MAX_ANSWER_BYTES then
        json = Encode({ id = id, ok = false, cmd = cmd, error = "answer too large", bytes = #json })
    end
    return json
end

function LabProbe.Slice(json)
    local chunks = {}
    for i = 1, #json, CHUNK_BYTES do
        chunks[#chunks + 1] = string.sub(json, i, i + CHUNK_BYTES - 1)
    end
    if #chunks == 0 then
        chunks[1] = ""
    end
    return chunks
end

local function QueueFull(DC)
    local throttle = DC._throttle
    return type(throttle) == "table" and type(throttle.queue) == "table" and #throttle.queue >= QUEUE_HIGH_WATER
end

-- Sends what the protocol's queue has room for; called from OnUpdate.
function LabProbe.Pump()
    local DC = Protocol()
    if not DC or #outbox == 0 then
        return
    end
    for _ = 1, SENDS_PER_TICK do
        local job = outbox[1]
        if not job or QueueFull(DC) then
            return
        end
        local index = job.next
        local frame = Encode({ id = job.id, i = index, n = #job.chunks, d = LabProbe.Base64(job.chunks[index]) })
        if type(frame) == "string" then
            DC:SendChunked(MODULE .. "|" .. CMSG_ANSWER_CHUNK .. "|J|" .. frame)
        end
        job.next = index + 1
        if job.next > #job.chunks then
            table.remove(outbox, 1)
        end
    end
end

function LabProbe.OnRequest(data)
    if type(data) ~= "table" then
        return
    end
    local id = data.id
    if type(id) ~= "string" or not string.match(id, "^%x%x%x%x%x%x%x%x%x%x$") then
        return
    end
    stats.requests = stats.requests + 1
    stats.lastId = id
    stats.lastCmd = type(data.req) == "table" and data.req.cmd or nil

    local json
    if not Enabled() then
        stats.refused = stats.refused + 1
        json = Encode({ id = id, ok = false, error = "probing switched off on this character (/labprobe on)" })
    else
        json = LabProbe.BuildAnswer(id, data.req)
        stats.answered = stats.answered + 1
    end
    if type(json) ~= "string" then
        return
    end
    outbox[#outbox + 1] = { id = id, chunks = LabProbe.Slice(json), next = 1 }
    LabProbe.Pump()
end

LabProbe._outbox = outbox

-- ------------------------------------------------------------
-- Wiring
-- ------------------------------------------------------------

local pump = CreateFrame("Frame")
pump:Show()
pump:SetScript("OnUpdate", function()
    if #outbox > 0 then
        LabProbe.Pump()
    end
end)

do
    local DC = Protocol()
    if DC and type(DC.RegisterJSONHandler) == "function" then
        DC:RegisterJSONHandler(MODULE, SMSG_REQUEST, LabProbe.OnRequest)
    end
end

SLASH_DCLABPROBE1 = "/labprobe"
SlashCmdList["DCLABPROBE"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "off" or msg == "on" then
        DCLabProbeDB = type(DCLabProbeDB) == "table" and DCLabProbeDB or {}
        DCLabProbeDB.enabled = (msg == "on")
    end
    Print(string.format("%s; %d request(s), %d answered, %d refused, last %s (%s), %d queued",
        Enabled() and "answering" or "switched off", stats.requests, stats.answered, stats.refused,
        tostring(stats.lastId), tostring(stats.lastCmd), #outbox))
end
