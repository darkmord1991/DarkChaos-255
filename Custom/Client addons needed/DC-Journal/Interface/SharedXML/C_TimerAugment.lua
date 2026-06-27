-- C_TimerAugment.lua
-- Retail-style C_Timer polyfill for WotLK 3.3.5a.
--
-- IMPORTANT: this is non-clobbering. The original Sirus version did
-- "C_Timer = {}" unconditionally and defined the API with COLON syntax
-- (C_Timer:After), which both wiped any C_Timer already provided by the client
-- or another addon AND broke every retail-style dot call C_Timer.After(sec, cb)
-- ("attempt to compare number with function"). We now only fill in functions
-- that are missing, using the standard retail (dot) signatures, matching the
-- other DC addons (DC-InfoBar, DC-HinterlandBG, DC-MythicPlus).

C_Timer = C_Timer or {}

local frame              -- created lazily, only if our implementation is used
local pending = {}

local TickerPrototype = {}
TickerPrototype.__index = TickerPrototype
function TickerPrototype:Cancel() self._cancelled = true end
function TickerPrototype:IsCancelled() return self._cancelled == true end

local function onUpdate(self)
    local now = GetTime()
    local i = 1
    while i <= #pending do
        local tk = pending[i]
        if tk._cancelled then
            table.remove(pending, i)
        elseif now >= tk._at then
            table.remove(pending, i)
            tk._callback(tk)
            if (not tk._cancelled) and (tk._iterations == nil or tk._iterations > 1) then
                if tk._iterations then
                    tk._iterations = tk._iterations - 1
                end
                tk._at = GetTime() + tk._duration
                pending[#pending + 1] = tk
            end
        else
            i = i + 1
        end
    end
    if #pending == 0 then
        self:Hide()
    end
end

local function schedule(tk)
    if not frame then
        frame = CreateFrame("Frame", "DCJournalTimerFrame", UIParent)
        frame:SetScript("OnUpdate", onUpdate)
    end
    tk._at = GetTime() + tk._duration
    pending[#pending + 1] = tk
    frame:Show()
end

local function NewTicker(duration, callback, iterations)
    local tk = setmetatable({}, TickerPrototype)
    tk._duration = tonumber(duration) or 0
    tk._callback = callback or function() end
    tk._iterations = iterations   -- nil => repeats forever
    schedule(tk)
    return tk
end

if not C_Timer.NewTicker then
    function C_Timer.NewTicker(duration, callback, iterations)
        return NewTicker(duration, callback, iterations)
    end
end

if not C_Timer.NewTimer then
    function C_Timer.NewTimer(duration, callback)
        return NewTicker(duration, callback, 1)
    end
end

if not C_Timer.After then
    function C_Timer.After(duration, callback)
        NewTicker(duration, callback, 1)
    end
end
