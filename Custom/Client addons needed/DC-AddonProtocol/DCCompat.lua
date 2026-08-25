-- DCCompat.lua - Canonical compatibility + shared primitives for all DC addons.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- Five DC addons each ship their own private C_Timer polyfill:
--     DC-Collection/Core.lua            After, NewTimer
--     DC-HinterlandBG/HLBG_TimerCompat  After, NewTimer, NewTicker
--     DC-InfoBar/Utils.lua              After
--     DC-Journal/.../C_TimerAugment     After, NewTimer, NewTicker
--     DC-MythicPlus/Core.lua            After
--
-- Because addons load in alphabetical folder order, DC-Collection wins the race
-- and installs a C_Timer that has no NewTicker. DC-HinterlandBG's shim is then
-- skipped wholesale by its `if not C_Timer then` guard, so C_Timer.NewTicker
-- stays nil for the rest of the session and HLBG_Queue_Client's auto-refresh
-- ticker -- which has no fallback branch -- silently never runs.
--
-- The rule this file establishes: a compat shim must COMPLETE the API surface,
-- never claim it all-or-nothing. Each function is installed independently, so a
-- partial C_Timer left behind by any load order still ends up whole.
--
-- DC-AddonProtocol is the one addon every other DC addon already loads before
-- itself (hard Dependency or OptionalDeps), which makes it the correct home for
-- shared primitives. This file must be the FIRST entry in DC-AddonProtocol.toc.
--
-- This file changes no behaviour that currently works. It only fills gaps that
-- are currently left nil, and provides pooling helpers that callers opt into.

local _G = _G

_G.DCCompat = _G.DCCompat or {}
local DCCompat = _G.DCCompat

DCCompat.VERSION = 1

-- ============================================================================
-- Error reporting
-- ============================================================================

-- Callback errors must never abort the pump that is driving every other DC
-- addon's timers. Report and carry on.
local function ReportError(context, err)
    if _G.geterrorhandler then
        local handler = _G.geterrorhandler()
        if handler then
            handler(string.format("[DCCompat:%s] %s", context, tostring(err)))
            return
        end
    end
    if _G.DEFAULT_CHAT_FRAME then
        _G.DEFAULT_CHAT_FRAME:AddMessage(
            string.format("|cffff4444[DCCompat:%s]|r %s", context, tostring(err)))
    end
end

DCCompat.ReportError = ReportError

-- ============================================================================
-- C_Timer -- single shared pump
-- ============================================================================
--
-- One OnUpdate frame drives every timer in every DC addon. The frame hides
-- itself whenever the queue drains, so an idle session costs nothing.
--
-- Semantics match retail (and DC-Journal's shim, the most complete of the five):
--   C_Timer.After(seconds, callback)              -> nil
--   C_Timer.NewTimer(seconds, callback)           -> ticker (fires once)
--   C_Timer.NewTicker(seconds, callback, iters)   -> ticker (repeats)
-- The callback receives the ticker as its first argument; ticker:Cancel() and
-- ticker:IsCancelled() are both available. Passing the ticker is additive --
-- existing DC callbacks all ignore their arguments.

_G.C_Timer = _G.C_Timer or {}
local C_Timer = _G.C_Timer

local pump                  -- created lazily; a client that never sets a timer
local queue = {}            -- never pays for the frame
local queueCount = 0

local TickerMeta = {}
TickerMeta.__index = TickerMeta

function TickerMeta:Cancel()
    self._cancelled = true
end

function TickerMeta:IsCancelled()
    return self._cancelled == true
end

local function OnPumpUpdate(self)
    local now = _G.GetTime()

    -- Iterate backwards: table.remove during a forward walk skips entries, a
    -- bug that has bitten at least two of the shims this file replaces.
    for i = queueCount, 1, -1 do
        local ticker = queue[i]

        if ticker._cancelled then
            table.remove(queue, i)
            queueCount = queueCount - 1

        elseif now >= ticker._at then
            local repeating = false

            if ticker._iterations == nil then
                repeating = true
            elseif ticker._iterations > 1 then
                ticker._iterations = ticker._iterations - 1
                repeating = true
            end

            if repeating then
                ticker._at = now + ticker._duration
            else
                table.remove(queue, i)
                queueCount = queueCount - 1
            end

            local ok, err = pcall(ticker._callback, ticker)
            if not ok then
                -- A repeating ticker whose callback throws would otherwise
                -- spam an error every period forever. Stop it at the source.
                if repeating then
                    ticker._cancelled = true
                end
                ReportError("C_Timer", err)
            end
        end
    end

    if queueCount == 0 then
        self:Hide()
    end
end

local function Schedule(seconds, callback, iterations)
    if type(seconds) ~= "number" or type(callback) ~= "function" then
        return nil
    end
    if seconds < 0 then
        seconds = 0
    end

    if not pump then
        pump = _G.CreateFrame("Frame")
        pump:Hide()
        pump:SetScript("OnUpdate", OnPumpUpdate)
    end

    local ticker = setmetatable({
        _at         = _G.GetTime() + seconds,
        _duration   = seconds,
        _callback   = callback,
        _iterations = iterations,
        _cancelled  = false,
    }, TickerMeta)

    queueCount = queueCount + 1
    queue[queueCount] = ticker
    pump:Show()

    return ticker
end

DCCompat.Schedule = Schedule

-- Install only what is missing. Never overwrite a working implementation --
-- another addon may already hold handles created by it.
if type(C_Timer.After) ~= "function" then
    C_Timer.After = function(seconds, callback)
        Schedule(seconds, callback, 1)
    end
end

if type(C_Timer.NewTimer) ~= "function" then
    C_Timer.NewTimer = function(seconds, callback)
        return Schedule(seconds, callback, 1)
    end
end

if type(C_Timer.NewTicker) ~= "function" then
    C_Timer.NewTicker = function(seconds, callback, iterations)
        -- nil iterations means "forever", matching retail.
        return Schedule(seconds, callback, iterations)
    end
end

-- ============================================================================
-- Widget pools
-- ============================================================================
--
-- WoW never garbage-collects a Frame. `child:Hide(); child:SetParent(nil)` in a
-- refresh path -- the pattern in DC-Collection/Wishlist.lua:168 -- orphans the
-- old widgets but leaks them permanently; every refresh allocates a fresh set.
--
-- DC-Journal already carries Blizzard's CreateFramePool, but it publishes it as
-- a bare global from inside a 190k-line addon that most installs load late (and
-- some players disable). This is the dependency-free equivalent that any DC
-- addon can rely on.
--
--   local pool = DCCompat.CreateFramePool("Frame", parent, "MyTemplate")
--   pool:ReleaseAll()
--   local f = pool:Acquire()

local PoolMeta = {}
PoolMeta.__index = PoolMeta

function PoolMeta:Acquire()
    local widget = table.remove(self._inactive)

    if not widget then
        self._created = self._created + 1
        widget = self._factory(self, self._created)
    end

    self._active[widget] = true

    if self._reset then
        local ok, err = pcall(self._reset, self, widget, false)
        if not ok then
            ReportError("FramePool.Reset", err)
        end
    end

    widget:Show()
    return widget
end

function PoolMeta:Release(widget)
    if not widget or not self._active[widget] then
        return false
    end

    self._active[widget] = nil

    if self._reset then
        local ok, err = pcall(self._reset, self, widget, true)
        if not ok then
            ReportError("FramePool.Reset", err)
        end
    end

    widget:Hide()
    -- Deliberately NOT SetParent(nil): re-parenting is what makes the widget
    -- unreachable and therefore leaked. Keep it parented and hidden so the
    -- next Acquire() can hand it straight back out.
    self._inactive[#self._inactive + 1] = widget
    return true
end

function PoolMeta:ReleaseAll()
    for widget in pairs(self._active) do
        self:Release(widget)
    end
end

-- Number of widgets this pool has ever created. A pool whose count keeps
-- climbing across refreshes means a caller is skipping Release.
function PoolMeta:GetNumCreated()
    return self._created
end

function PoolMeta:EnumerateActive()
    return pairs(self._active)
end

-- factory(pool, index) -> widget
-- reset(pool, widget, isRelease) -- optional
function DCCompat.CreatePool(factory, reset)
    if type(factory) ~= "function" then
        return nil
    end

    return setmetatable({
        _factory  = factory,
        _reset    = reset,
        _active   = {},
        _inactive = {},
        _created  = 0,
    }, PoolMeta)
end

function DCCompat.CreateFramePool(frameType, parent, template, reset)
    frameType = frameType or "Frame"

    return DCCompat.CreatePool(function()
        return _G.CreateFrame(frameType, nil, parent, template)
    end, reset)
end

function DCCompat.CreateTexturePool(parent, layer, sublayer, reset)
    return DCCompat.CreatePool(function()
        return parent:CreateTexture(nil, layer or "ARTWORK", nil, sublayer)
    end, reset)
end

function DCCompat.CreateFontStringPool(parent, layer, template, reset)
    return DCCompat.CreatePool(function()
        return parent:CreateFontString(nil, layer or "OVERLAY",
            template or "GameFontNormalSmall")
    end, reset)
end

-- ============================================================================
-- Widget method polyfills
-- ============================================================================
--
-- Retail widget methods that 3.3.5 lacks. These were previously copy-pasted
-- verbatim into DC-InfoBar/Utils.lua, DC-MythicPlus/Core.lua and
-- DC-MythicPlus/Settings.lua; the implementations below are those, unchanged.
--
-- Both patch a shared metatable, so whichever addon ran first already decided
-- the behaviour for every addon on the client. Doing it once, here, at least
-- makes that single owner explicit.

-- Resolve a widget's shared method table. The originals indexed
-- getmetatable(w).__index directly, which throws if the metatable is absent --
-- true under any harness that stubs CreateFrame, and not worth an error at
-- login for a cosmetic polyfill.
local function SharedMethods(widget)
    if not widget then
        return nil
    end
    local meta = getmetatable(widget)
    local index = meta and meta.__index
    if type(index) == "table" then
        return index
    end
    return nil
end

do
    local ok, probe = pcall(_G.CreateFrame, "Frame")
    if ok and probe then
        local FrameMethods = SharedMethods(probe)
        if FrameMethods and not FrameMethods.SetShown then
            FrameMethods.SetShown = function(self, shown)
                if shown then
                    self:Show()
                else
                    self:Hide()
                end
            end
        end

        local okTex, tex = pcall(probe.CreateTexture, probe)
        local TextureMethods = okTex and SharedMethods(tex) or nil
        if TextureMethods and not TextureMethods.SetColorTexture then
            TextureMethods.SetColorTexture = function(self, r, g, b, a)
                self:SetTexture("Interface\\Buttons\\WHITE8x8")
                self:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
            end
        end
    end
end

return DCCompat
